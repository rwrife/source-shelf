# Source Shelf — Plan

## Status
Flutter 3.47.7 skeleton generated with Android/iOS/Windows targets and adaptive empty state; source capture, storage, exports, release and icon wiring remain pending. ASC bundle registration blocked by `FORBIDDEN_ERROR.PLA_NOT_ACCEPTED` until account owner accepts Apple Program License Agreement; bundle ID `com.infinityball.sourceshelf` remains unregistered.

## Product slice
Capture source metadata (book/article/chapter/web document/interview), add quote cards with exact page/section locator and user commentary, search/tag collections, and export deterministic citation snippets and portable JSON/BibTeX/Markdown. Metadata is user-entered; never claim DOI/ISBN verified by a service. On import, reject malformed data without mutating existing library. For interview citations, require user-entered consent context; avoid publishing private quotes by default.

## Technology & UX
Flutter stable (pin exact version in `toolchain.json` once scaffold generator is exercised), Dart pure domain/formatting logic, local SQLite via existing supported Flutter dependency when needed. Windows, Android and iOS platform folders must be generated together; phones, tablets and resizable desktop windows supported. Windows CI/release primary; Android APK CI; iOS compile on macOS runner when available. No native Swift-only app, React Native, Expo, Kotlin Multiplatform, Unity or .NET MAUI.

Choose strategy A, platform-native adaptive: a thin `AdaptiveScaffold`, `AdaptiveButton`, `AdaptiveDialog` seam; Cupertino on iOS/iPad, Material 3 on Android, Fluent on Windows. Native picker/share behavior; safe areas, text scaling, selection, keyboard shortcuts, hover/focus, context menus. No Material on iOS, Cupertino on Android, or phone shell on Windows. Screen-reader labels and contrast are acceptance criteria. Verify key screens under `TargetPlatform.iOS`, `TargetPlatform.android`, `TargetPlatform.windows` with widgets/goldens; test phone, tablet and desktop widths. Mobile iPad and Android tablets enabled.

## Local data & boundaries
Source(id, type, title, ordered creators, publication fields, identifiers); Excerpt(id, sourceId, locator, quote, note, createdAt); Collection and tag join records. Versioned JSON export/import with validation and atomic replacement, optional `.bib` and Markdown exports. Local-only; no automatic sync, tracking, ads or network permission. File picker only upon explicit import/export. Backup files contain private notes; disclose before sharing. Format engine must mark unsupported/missing fields visibly, never invent publisher, page or date. Tests use style-manual fixtures and treat citation output as draft for human proofreading.

## Milestones (issues in dependency order)
1. Flutter skeleton, platform targets, identifiers, CI compile/test gates.
2. Source/excerpt domain model, local persistence, validation and migration tests.
3. Adaptive source catalog, excerpt capture and search with platform goldens.
4. Deterministic citation formatter and fixtures (APA 7 and BibTeX first; Chicago/MLA later).
5. Full JSON import/export, Markdown/BibTeX export and privacy controls.
6. Icon integration, store listing accuracy and accessibility/input audit.
7. Release workflow `v*`/manual dispatch on `windows-latest`: zipped `flutter build windows --release` attached to GitHub release; Android build continues in Linux Docker CI. TestFlight/Play opt-in later, using ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8, ASC_TEAM_ID (names only). Never log secrets. Record MSIX mapping from `com.infinityball.sourceshelf` when packaging requires transformed identity.

## Risks & non-goals
Citation formats have nuanced edge cases; bounded first-pass formatter plus clear missing-field warnings, tests and export for review. No paywall crawling, live DOI lookup, account sync, automated fact checking, AI-invented citations or cloud storage. Generated `AppStore/icon.png` uses OpenAI Images; wire into Windows `.ico`, Android launcher mipmaps and iOS asset catalogs in issue #6. Treat icon visually as draft until inspected. README/AppStore copy must not claim incomplete features work.
