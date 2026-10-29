import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/widgets.dart';

void main() => runApp(const SourceShelfApp());

/// Platform override is for deterministic widget tests; production uses host.
class SourceShelfApp extends StatelessWidget {
  const SourceShelfApp({super.key, this.platform});

  final TargetPlatform? platform;

  @override
  Widget build(BuildContext context) {
    final target = platform ?? defaultTargetPlatform;
    final home = AdaptiveScaffold(platform: target);
    if (target == TargetPlatform.iOS) {
      return cupertino.CupertinoApp(title: 'Source Shelf', home: home);
    }
    if (target == TargetPlatform.windows) {
      return fluent.FluentApp(title: 'Source Shelf', home: home);
    }
    return material.MaterialApp(
      title: 'Source Shelf',
      theme: material.ThemeData(useMaterial3: true),
      home: home,
    );
  }
}

class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({super.key, required this.platform});

  final TargetPlatform platform;

  @override
  Widget build(BuildContext context) {
    // ponytail: skeleton only; issue #3 adds real catalog, search and capture.
    final empty = Center(
      child: Semantics(
        label: 'No sources yet',
        child: Text('No sources yet. Your research stays on this device.'),
      ),
    );
    if (platform == TargetPlatform.iOS) {
      return cupertino.CupertinoPageScaffold(
        navigationBar: const cupertino.CupertinoNavigationBar(
          middle: Text('Source Shelf'),
        ),
        child: SafeArea(child: empty),
      );
    }
    if (platform == TargetPlatform.windows) {
      return fluent.NavigationView(
        titleBar: fluent.TitleBar(title: const Text('Source Shelf')),
        pane: fluent.NavigationPane(
          displayMode: fluent.PaneDisplayMode.auto,
          items: [
            fluent.PaneItem(
              icon: const fluent.Icon(fluent.FluentIcons.library),
              title: const Text('Sources'),
              body: empty,
            ),
          ],
          selected: 0,
        ),
      );
    }
    return material.Scaffold(
      appBar: material.AppBar(title: const Text('Source Shelf')),
      body: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth >= 600
            ? Row(
                children: [
                  material.NavigationRail(
                    selectedIndex: 0,
                    destinations: [
                      material.NavigationRailDestination(
                        icon: material.Icon(
                          material.Icons.library_books_outlined,
                        ),
                        label: Text('Sources'),
                      ),
                    ],
                  ),
                  Expanded(child: empty),
                ],
              )
            : empty,
      ),
    );
  }
}

class AdaptiveButton extends StatelessWidget {
  const AdaptiveButton({
    super.key,
    required this.platform,
    required this.label,
    required this.onPressed,
  });

  final TargetPlatform platform;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (platform == TargetPlatform.iOS) {
      return cupertino.CupertinoButton(
        onPressed: onPressed,
        child: Text(label),
      );
    }
    if (platform == TargetPlatform.windows) {
      return fluent.Button(onPressed: onPressed, child: Text(label));
    }
    return material.FilledButton(onPressed: onPressed, child: Text(label));
  }
}

class AdaptiveDialog extends StatelessWidget {
  const AdaptiveDialog({
    super.key,
    required this.platform,
    required this.title,
    required this.message,
  });

  final TargetPlatform platform;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    if (platform == TargetPlatform.iOS) {
      return cupertino.CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
      );
    }
    if (platform == TargetPlatform.windows) {
      return fluent.ContentDialog(title: Text(title), content: Text(message));
    }
    return material.AlertDialog(title: Text(title), content: Text(message));
  }
}
