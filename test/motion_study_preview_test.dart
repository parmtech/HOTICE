import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotice/src/inspiration_catalog.dart';
import 'package:hotice/src/motion_study_preview.dart';

void main() {
  testWidgets('preview card exposes a user-started accessible action', (
    tester,
  ) async {
    final template = (await InspirationCatalog.load()).first;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: MotionStudyPreviewButton(template: template)),
        ),
      ),
    );

    expect(find.text('Play concept preview · not AI output'), findsOneWidget);
    expect(
      find.byType(MotionStudyPlaybackDialog),
      findsNothing,
      reason: 'the card must not open or start playback before a tap',
    );
  });
}
