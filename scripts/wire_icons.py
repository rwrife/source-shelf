"""Derive platform icons from the checked-in OpenAI-generated AppStore/icon.png.

Requires Pillow: uv run --with pillow python scripts/wire_icons.py
"""

import json
from pathlib import Path

from PIL import Image

root = Path(__file__).resolve().parents[1]
source = Image.open(root / "AppStore/icon.png")
if source.size != (1024, 1024) or source.mode != "RGB":
    raise ValueError("AppStore/icon.png must be opaque RGB 1024x1024")

android = root / "android/app/src/main/res"
for name, size in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
    source.resize((size, size), Image.Resampling.LANCZOS).save(
        android / f"mipmap-{name}/ic_launcher.png"
    )

catalog = root / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
manifest = json.loads((catalog / "Contents.json").read_text())
for item in manifest["images"]:
    point_size = float(item["size"].split("x")[0])
    size = round(point_size * int(item["scale"].removesuffix("x")))
    source.resize((size, size), Image.Resampling.LANCZOS).save(catalog / item["filename"])

icon = root / "windows/runner/resources/app_icon.ico"
source.save(
    icon,
    format="ICO",
    sizes=[(size, size) for size in (16, 24, 32, 48, 64, 128, 256)],
)
assert Image.open(icon).size == (256, 256)
for item in manifest["images"]:
    point_size = float(item["size"].split("x")[0])
    size = round(point_size * int(item["scale"].removesuffix("x")))
    assert Image.open(catalog / item["filename"]).size == (size, size)
for name, size in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
    assert Image.open(android / f"mipmap-{name}/ic_launcher.png").size == (size, size)
print("Wired and checked Android, iOS/iPad and Windows icons from AppStore/icon.png")
# ponytail: raster dimensions and opacity are checked; visual subject/text/contrast need human review.
