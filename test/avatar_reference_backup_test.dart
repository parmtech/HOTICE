import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hotice/src/avatar_reference_backup.dart';
import 'package:hotice/src/smart_references.dart';

AvatarReferenceBackup sample() => AvatarReferenceBackup(
      name: 'Nova',
      style: 'Cinematic',
      identityNotes: 'Blue coat',
      photos: [
        AvatarBackupPhoto(
          view: FaceView.front,
          mimeType: 'image/jpeg',
          bytes: Uint8List.fromList([0xff, 0xd8, 0xff, 1, 2, 3]),
        ),
        AvatarBackupPhoto(
          view: FaceView.right90,
          mimeType: 'image/png',
          bytes: Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 1]),
        ),
      ],
    );

void main() {
  final codec = AvatarReferenceBackupCodec();

  test('encrypted typed backup round-trips actor and face view metadata',
      () async {
    final input = sample();
    final envelope =
        await codec.encode(input, password: 'long safe passphrase');
    final restored =
        await codec.decode(envelope, password: 'long safe passphrase');

    expect(restored.name, input.name);
    expect(restored.style, input.style);
    expect(restored.identityNotes, input.identityNotes);
    expect(
        restored.photos.map((p) => p.view), [FaceView.front, FaceView.right90]);
    expect(restored.photos.map((p) => p.mimeType), ['image/jpeg', 'image/png']);
    expect(
        restored.photos.map((p) => p.bytes), input.photos.map((p) => p.bytes));
  });

  test('backup uses fresh salt and does not expose actor text in cleartext',
      () async {
    final one = await codec.encode(sample(), password: 'long safe passphrase');
    final two = await codec.encode(sample(), password: 'long safe passphrase');
    expect(one, isNot(two));
    expect(utf8.decode(one, allowMalformed: true), isNot(contains('Nova')));
    expect(
        utf8.decode(one, allowMalformed: true), isNot(contains('Blue coat')));
  });

  test('wrong password, tampering, truncation and unknown version are rejected',
      () async {
    final envelope =
        await codec.encode(sample(), password: 'long safe passphrase');
    await expectLater(
      codec.decode(envelope, password: 'another safe passphrase'),
      throwsA(isA<AvatarReferenceBackupException>()),
    );
    final changed = Uint8List.fromList(envelope)..[envelope.length - 1] ^= 1;
    await expectLater(
      codec.decode(changed, password: 'long safe passphrase'),
      throwsA(isA<AvatarReferenceBackupException>()),
    );
    await expectLater(
      codec.decode(envelope.sublist(0, 20), password: 'long safe passphrase'),
      throwsA(isA<AvatarReferenceBackupException>()),
    );
    final future = Uint8List.fromList(envelope)..[8] = 99;
    await expectLater(
      codec.decode(future, password: 'long safe passphrase'),
      throwsA(isA<AvatarReferenceBackupException>()),
    );
  });

  test('rejects short passwords and image MIME/signature mismatches', () async {
    await expectLater(
      codec.encode(sample(), password: 'short'),
      throwsA(isA<AvatarReferenceBackupException>()),
    );
    final invalid = AvatarReferenceBackup(
      name: 'Nova',
      style: 'Cinematic',
      identityNotes: '',
      photos: [
        AvatarBackupPhoto(
          view: FaceView.front,
          mimeType: 'image/png',
          bytes: Uint8List.fromList([0xff, 0xd8, 0xff, 1]),
        ),
      ],
    );
    await expectLater(
      codec.encode(invalid, password: 'long safe passphrase'),
      throwsA(isA<AvatarReferenceBackupException>()),
    );
  });
}
