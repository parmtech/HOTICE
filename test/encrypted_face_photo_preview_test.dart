import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotice/src/encrypted_face_photo_preview.dart';

void main() {
  test('preview decode width follows display density and stays bounded', () {
    expect(
      facePhotoPreviewCacheWidth(
        width: 56,
        height: 68,
        devicePixelRatio: 3,
      ),
      204,
    );
    expect(
      facePhotoPreviewCacheWidth(
        width: 96,
        height: 108,
        devicePixelRatio: 4,
      ),
      432,
    );
    expect(
      facePhotoPreviewCacheWidth(
        width: 600,
        height: 900,
        devicePixelRatio: 4,
      ),
      2048,
    );
    expect(
      facePhotoPreviewCacheWidth(
        width: 0,
        height: 0,
        devicePixelRatio: 0,
      ),
      1,
    );
  });

  testWidgets(
      'keeps encrypted preview private when device vault is unavailable',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EncryptedFacePhotoPreview(
            path: '/private/encrypted/reference.bin',
            accountScope: 'workspace-test',
            width: 56,
            height: 68,
            semanticLabel: 'Front saved face reference',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    final semantics = tester.getSemantics(find.byIcon(Icons.lock_outline));
    expect(semantics.label, 'Front saved face reference, unavailable');
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('does not retain a decrypted image across workspace changes',
      (tester) async {
    final nextWorkspacePhoto = Completer<Uint8List>();
    final imageBytes = Uint8List.fromList(base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
    ));
    Future<Uint8List> loadPhoto(String path, String workspace) =>
        workspace == 'workspace-a'
            ? Future<Uint8List>.value(imageBytes)
            : nextWorkspacePhoto.future;

    Widget preview(String workspace) => MaterialApp(
          home: Scaffold(
            body: EncryptedFacePhotoPreview(
              path: '/private/reference.aes',
              accountScope: workspace,
              width: 56,
              height: 68,
              semanticLabel: 'Front saved face reference',
              photoLoader: loadPhoto,
            ),
          ),
        );

    await tester.pumpWidget(preview('workspace-a'));
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);

    await tester.pumpWidget(preview('workspace-b'));
    await tester.pump();
    expect(find.byType(Image), findsNothing,
        reason: 'the prior workspace image must disappear while the new key loads');

    nextWorkspacePhoto.complete(imageBytes);
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
  });
}
