import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Size;
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:source_shelf/main.dart';

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
        await tester.pumpWidget(SourceShelfApp(platform: platform));
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
