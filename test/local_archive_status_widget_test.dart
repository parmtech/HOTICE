import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotice/main.dart';
import 'package:hotice/src/local_store.dart';

void main() {
  testWidgets('local archive status shows saved and recoverable failure states',
      (tester) async {
    final archive = HotIceLocalArchive(
      directory: Directory.systemTemp,
      keyLoader: () async => List<int>.filled(32, 29),
    );
    addTearDown(archive.dispose);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: LocalArchiveStatusStrip(archive: archive)),
    ));
    expect(find.text('Saved on this device'), findsOneWidget);

    archive.writeState = LocalArchiveWriteState.failed;
    archive.notifyListeners();
    await tester.pump();
    expect(
      find.textContaining('Couldn’t save this device copy'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
  });
}
