import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:source_shelf/main.dart';
import 'package:source_shelf/library.dart';
import 'package:source_shelf/catalog.dart';

extension on Finder {
  Finder findChildTextField() =>
      find.descendant(of: this, matching: find.byType(EditableText));
}

void main() {
  for (final platform in [
    TargetPlatform.iOS,
    TargetPlatform.android,
    TargetPlatform.windows,
  ]) {
    for (final size in [
      const Size(390, 844),
      const Size(900, 1100),
      const Size(1440, 900),
    ]) {
      testWidgets('$platform ${size.width}x${size.height}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          SourceShelfApp(platform: platform, library: SourceLibrary.memory()),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('No sources yet. Your research stays on this device.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        if (platform == TargetPlatform.iOS) {
          expect(find.byType(cupertino.CupertinoApp), findsOneWidget);
          expect(find.byType(material.MaterialApp), findsNothing);
        } else if (platform == TargetPlatform.windows) {
          expect(find.byType(fluent.FluentApp), findsOneWidget);
          expect(find.byType(material.MaterialApp), findsNothing);
        } else {
          expect(find.byType(material.MaterialApp), findsOneWidget);
          expect(find.byType(cupertino.CupertinoApp), findsNothing);
          expect(
            find.byType(material.NavigationRail),
            size.width >= 600 ? findsOneWidget : findsNothing,
          );
        }
      });
    }
  }

  for (final platform in [
    TargetPlatform.iOS,
    TargetPlatform.android,
    TargetPlatform.windows,
  ]) {
    testWidgets('$platform create source, capture excerpt, filter and edit', (
      tester,
    ) async {
      final library = SourceLibrary.memory();
      addTearDown(library.dispose);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        SourceShelfApp(platform: platform, library: library),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('New source'));
      await tester.pumpAndSettle();
      expect(find.text('New source'), findsWidgets);
      expect(find.byType(PlatformField), findsWidgets);
      await tester.enterText(
        find.byType(PlatformField).at(1).findChildTextField(),
        'Evidence Atlas',
      );
      await tester.enterText(
        find.byType(PlatformField).at(2).findChildTextField(),
        'Ada; Bea',
      );
      await tester.ensureVisible(find.text('Save source'));
      await tester.tap(find.text('Save source'));
      await tester.pumpAndSettle();
      expect(library.sources().single.creators, ['Ada', 'Bea']);
      await tester.tap(find.textContaining('Evidence Atlas').first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Capture excerpt'));
      await tester.tap(find.text('Capture excerpt'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(PlatformField).at(0).findChildTextField(),
        'p. 12',
      );
      await tester.enterText(
        find.byType(PlatformField).at(1).findChildTextField(),
        'Exact quote',
      );
      await tester.ensureVisible(find.text('Save excerpt'));
      await tester.tap(find.text('Save excerpt'));
      await tester.pumpAndSettle();
      expect(
        library.excerpts(library.sources().single.id).single.locator,
        'p. 12',
      );
      expect(find.text('Exact quote'), findsOneWidget);
      expect(find.text('Copy APA draft'), findsOneWidget);
      await tester.tap(find.text('Back to sources'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(PlatformField).first.findChildTextField(),
        'Missing',
      );
      await tester.pumpAndSettle();
      expect(find.text('No matching sources.'), findsOneWidget);
    });
  }

  testWidgets('export requires explicit privacy confirmation before picker', (
    tester,
  ) async {
    final library = SourceLibrary.memory();
    addTearDown(library.dispose);
    await tester.pumpWidget(
      SourceShelfApp(platform: TargetPlatform.android, library: library),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export md'));
    await tester.pumpAndSettle();
    expect(find.textContaining('private research notes'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.textContaining('private research notes'), findsNothing);
  });

  testWidgets('large text keeps essential actions usable with keyboard focus', (
    tester,
  ) async {
    for (final platform in [
      TargetPlatform.iOS,
      TargetPlatform.android,
      TargetPlatform.windows,
    ]) {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.binding.platformDispatcher.textScaleFactorTestValue = 2;
      await tester.pumpWidget(
        SourceShelfApp(platform: platform, library: SourceLibrary.memory()),
      );
      expect(
        MediaQuery.textScalerOf(tester.element(find.byType(Catalog))),
        isA<TextScaler>().having((value) => value.scale(10), 'scaled 10px', 20),
      );
      await tester.pumpAndSettle();
      expect(find.text('New source'), findsOneWidget);
      expect(find.text('Import JSON'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('New source'));
      await tester.tap(find.text('New source'));
      await tester.pumpAndSettle();
      expect(find.text('Save source'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
  });

  testWidgets('keyboard search and tab focus on each platform', (tester) async {
    for (final platform in [
      TargetPlatform.iOS,
      TargetPlatform.android,
      TargetPlatform.windows,
    ]) {
      final library = SourceLibrary.memory();
      addTearDown(library.dispose);
      await tester.pumpWidget(
        SourceShelfApp(platform: platform, library: library),
      );
      await tester.pumpAndSettle();
      final semantics = tester.ensureSemantics();
      final searchField = find.byType(PlatformField).first.findChildTextField();
      expect(searchField, findsOneWidget);
      expect(
        tester
            .widget<Semantics>(
              find
                  .descendant(
                    of: find.byType(PlatformField).first,
                    matching: find.byType(Semantics),
                  )
                  .first,
            )
            .properties
            .label,
        'Search source titles',
      );
      semantics.dispose();
      await tester.tap(searchField);
      await tester.pumpAndSettle();
      await tester.enterText(searchField, 'Missing');
      await tester.pumpAndSettle();
      expect(find.text('No matching sources.'), findsOneWidget);
      final searchFocus = FocusManager.instance.primaryFocus;
      expect(searchFocus, isNotNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, isNot(searchFocus));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('adaptive controls use platform-specific widgets', (
    tester,
  ) async {
    for (final platform in [
      TargetPlatform.iOS,
      TargetPlatform.android,
      TargetPlatform.windows,
    ]) {
      await tester.pumpWidget(SourceShelfApp(platform: platform));
      await tester.pumpWidget(
        platform == TargetPlatform.iOS
            ? cupertino.CupertinoApp(
                home: AdaptiveButton(
                  platform: platform,
                  label: 'Add',
                  onPressed: () {},
                ),
              )
            : platform == TargetPlatform.windows
            ? fluent.FluentApp(
                home: AdaptiveButton(
                  platform: platform,
                  label: 'Add',
                  onPressed: () {},
                ),
              )
            : material.MaterialApp(
                home: AdaptiveButton(
                  platform: platform,
                  label: 'Add',
                  onPressed: () {},
                ),
              ),
      );
      expect(
        find.byType(
          platform == TargetPlatform.iOS
              ? cupertino.CupertinoButton
              : platform == TargetPlatform.windows
              ? fluent.Button
              : material.FilledButton,
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(
        platform == TargetPlatform.iOS
            ? cupertino.CupertinoApp(
                home: AdaptiveDialog(
                  platform: platform,
                  title: 'Title',
                  message: 'Message',
                ),
              )
            : platform == TargetPlatform.windows
            ? fluent.FluentApp(
                home: AdaptiveDialog(
                  platform: platform,
                  title: 'Title',
                  message: 'Message',
                ),
              )
            : material.MaterialApp(
                home: AdaptiveDialog(
                  platform: platform,
                  title: 'Title',
                  message: 'Message',
                ),
              ),
      );
      expect(
        find.byType(
          platform == TargetPlatform.iOS
              ? cupertino.CupertinoAlertDialog
              : platform == TargetPlatform.windows
              ? fluent.ContentDialog
              : material.AlertDialog,
        ),
        findsOneWidget,
      );
    }
  });
}
