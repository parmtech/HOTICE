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
}
