import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:hotice/main.dart';

/// Runs as a genuine Flutter Android application on a booted Android emulator.
/// It checks navigation with real Android view metrics, not just fake test size.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('HOTICE Android guest demo smoke: navigate, create, edit and switch',
      (tester) async {
    await tester.pumpWidget(const HotIceApp());
    await tester.pumpAndSettle();
    expect(find.text('Explore demo studio'), findsOneWidget);

    await tester.tap(find.text('Explore demo studio'));
    await tester.pumpAndSettle();
    expect(find.text('Projects'), findsWidgets);
    expect(tester.takeException(), isNull);

    // Bundled concept previews start only on user intent. The emulator checks
    // the actual Android player surface and controls, not just the poster.
    await tester.tap(find.byTooltip('Inspiration Library'));
    await tester.pumpAndSettle();
    for (var tries = 0;
        tries < 30 &&
            find.text('Play concept preview · not AI output').evaluate().isEmpty;
        tries++) {
      await tester.runAsync(() => Future<void>.delayed(
            const Duration(milliseconds: 30),
          ));
      await tester.pump(const Duration(milliseconds: 50));
    }
    final preview = find.text('Play concept preview · not AI output').first;
    expect(preview, findsOneWidget);
    await tester.ensureVisible(preview);
    await tester.tap(preview);
    await tester.pump();
    for (var tries = 0;
        tries < 60 && find.byTooltip('Play preview').evaluate().isEmpty;
        tries++) {
      await tester.runAsync(() => Future<void>.delayed(
            const Duration(milliseconds: 50),
          ));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Silent concept visual · original HOTICE study · not AI output'),
        findsOneWidget);
    expect(find.byTooltip('Play preview'), findsOneWidget,
        reason: 'the video must not autoplay');
    await tester.tap(find.byTooltip('Play preview'));
    for (var tries = 0;
        tries < 20 && find.byTooltip('Pause preview').evaluate().isEmpty;
        tries++) {
      await tester.runAsync(() => Future<void>.delayed(
            const Duration(milliseconds: 50),
          ));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byTooltip('Pause preview'), findsOneWidget);
    await tester.tap(find.byTooltip('Pause preview'));
    for (var tries = 0;
        tries < 20 && find.byTooltip('Play preview').evaluate().isEmpty;
        tries++) {
      await tester.runAsync(() => Future<void>.delayed(
            const Duration(milliseconds: 50),
          ));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byTooltip('Play preview'), findsOneWidget);
    await tester.tap(find.byTooltip('Close preview'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Return to Projects before continuing the creator journey.
    await tester.tap(find.byIcon(Icons.grid_view_rounded).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('New project'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Android smoke project');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Scene composer'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Switch between the two generation modes.
    await tester.tap(find.text('Music video studio'));
    await tester.pumpAndSettle();
    expect(find.text('Music Video Studio'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Normal video'));
    await tester.pumpAndSettle();

    // Navigate across the same tabs as an ordinary phone user.
    await tester.tap(find.text('Actors').last);
    await tester.pumpAndSettle();
    expect(find.text('Actors Studio'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Credits').last);
    await tester.pumpAndSettle();
    expect(find.text('HOTICE Credits'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings & appearance'));
    await tester.pumpAndSettle();
    expect(find.text('Appearance & settings'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accounts'));
    await tester.pumpAndSettle();
    expect(find.text('Accounts'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
