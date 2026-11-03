import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotice/src/avatar_studio.dart';
import 'package:hotice/src/encrypted_face_photo_preview.dart';
import 'package:hotice/src/smart_references.dart';
import 'package:hotice/src/state.dart';

void main() {
  testWidgets('reference deletion requires confirmation and keeps profile open',
      (tester) async {
    final store = HotIceStore()..signInDemo('creator@example.com');
    addTearDown(store.dispose);
    store.addAvatar('Nova', 'Cinematic');
    store.addAvatarReference(
      'Nova',
      const AvatarReference(
        id: '11111111-1111-4111-8111-111111111111',
        ownerName: 'Nova',
        role: ReferenceRole.avatar,
        format: ReferenceFormat.image,
        mimeType: 'image/jpeg',
        localPath: '/private/11111111-1111-4111-8111-111111111111.aes',
        view: FaceView.front,
        ownedTemporaryFile: true,
      ),
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AvatarsPage(store: store)),
    ));
    await tester.ensureVisible(find.widgetWithText(ListTile, 'Nova'));
    await tester.tap(find.widgetWithText(ListTile, 'Nova'));
    await tester.pumpAndSettle();
    expect(find.text('Saved face references: 1 (encrypted on this device)'),
        findsOneWidget);
    expect(find.text('Reusable character identity card · Text-only demo'),
        findsOneWidget);

    await tester.tap(find.byTooltip('Remove this reference'));
    await tester.pumpAndSettle();
    expect(find.text('Remove this face reference?'), findsOneWidget);
    await tester.tap(find.text('Keep reference'));
    await tester.pumpAndSettle();
    expect(find.text('Saved face references: 1 (encrypted on this device)'),
        findsOneWidget);
    expect(store.avatarPackFor('Nova').assets, hasLength(1));

    await tester.tap(find.byTooltip('Remove this reference'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove reference'));
    await tester.pumpAndSettle();

    expect(find.text('Saved face references: 0 (encrypted on this device)'),
        findsOneWidget);
    expect(find.text('Reusable character identity card · Text-only demo'),
        findsOneWidget);
    expect(find.byTooltip('Remove this reference'), findsNothing);
    expect(store.avatarPackFor('Nova').assets, isEmpty);
  });

  testWidgets('Actor profile lazily builds encrypted photo previews',
      (tester) async {
    final store = HotIceStore()..signInDemo('creator@example.com');
    addTearDown(store.dispose);
    store.addAvatar('Nova', 'Cinematic');
    for (var index = 1; index <= 16; index++) {
      final id =
          '00000000-0000-4000-8000-${index.toString().padLeft(12, '0')}';
      expect(
        store.addAvatarReference(
          'Nova',
          AvatarReference(
            id: id,
            ownerName: 'Nova',
            role: ReferenceRole.avatar,
            format: ReferenceFormat.image,
            mimeType: 'image/jpeg',
            localPath: '/private/$id.aes',
            view: FaceView.front,
            ownedTemporaryFile: true,
          ),
        ),
        isTrue,
      );
    }

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AvatarsPage(store: store)),
    ));
    await tester.ensureVisible(find.widgetWithText(ListTile, 'Nova'));
    await tester.tap(find.widgetWithText(ListTile, 'Nova'));
    await tester.pumpAndSettle();

    expect(find.text('Saved face references: 16 (encrypted on this device)'),
        findsOneWidget);
    expect(find.byType(EncryptedFacePhotoPreview).evaluate().length, lessThan(16));
  });

  testWidgets('saved face reference opens an enlarged locked-safe viewer',
      (tester) async {
    final store = HotIceStore()..signInDemo('creator@example.com');
    addTearDown(store.dispose);
    store.addAvatar('Nova', 'Cinematic');
    store.addAvatarReference(
      'Nova',
      const AvatarReference(
        id: '11111111-1111-4111-8111-111111111111',
        ownerName: 'Nova',
        role: ReferenceRole.avatar,
        format: ReferenceFormat.image,
        mimeType: 'image/jpeg',
        localPath: '/private/11111111-1111-4111-8111-111111111111.aes',
        view: FaceView.front,
        ownedTemporaryFile: true,
      ),
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AvatarsPage(store: store)),
    ));
    await tester.ensureVisible(find.widgetWithText(ListTile, 'Nova'));
    await tester.tap(find.widgetWithText(ListTile, 'Nova'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('View Front face reference'));
    await tester.pumpAndSettle();

    expect(find.text('Face reference · Front'), findsOneWidget);
    expect(find.text('Unverified reference · pinch or scroll to zoom'),
        findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsAtLeastNWidgets(1));
    expect(find.byTooltip('Close photo preview'), findsOneWidget);

    await tester.tap(find.byTooltip('Close photo preview'));
    await tester.pumpAndSettle();
    expect(find.text('Reusable character identity card · Text-only demo'),
        findsOneWidget);
  });
}
