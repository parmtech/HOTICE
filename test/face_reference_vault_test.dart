import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotice/src/face_reference_vault.dart';

const idA = '1dbd4a72-bfde-4330-8a21-5f01d9be4e61';
const idB = 'dc229677-8930-45ad-b589-87f6083d2dbb';

void main() {
  late Directory root;
  late FaceReferenceVault vault;
  final key = List<int>.filled(32, 37);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('hotice-face-vault-test-');
    vault = FaceReferenceVault(
      directory: root,
      keyLoader: () async => key,
      accountScope: 'workspace-a',
    );
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('encrypts image bytes at rest and decrypts the exact image', () async {
    final plain = Uint8List.fromList([
      0xff,
      0xd8,
      0xff,
      ...'private face reference test bytes'.codeUnits,
    ]);
    final source = File('${root.path}/source.jpg');
    await source.writeAsBytes(plain);

    final stored = await vault.encryptPhoto(source, referenceId: idA);
    final encrypted = await File(stored.path).readAsBytes();
    final encoded = String.fromCharCodes(encrypted);

    expect(stored.mimeType, 'image/jpeg');
    expect(stored.clearBytes, plain.length);
    expect(encoded, isNot(contains('private face reference')));
    expect(await vault.decryptPhoto(stored.path), plain);
    expect(
      await source.exists(),
      isTrue,
      reason: 'source ownership stays with user',
    );
  });

  test('encrypts restored in-memory photo bytes without plaintext staging',
      () async {
    final plain = Uint8List.fromList([0xff, 0xd8, 0xff, 9, 8, 7]);
    final stored = await vault.encryptPhotoBytes(plain, referenceId: idA);
    expect(stored.mimeType, 'image/jpeg');
    expect(await vault.decryptPhoto(stored.path), plain);
    expect(
        await root
            .list()
            .where((entity) => entity.path.endsWith('.jpg'))
            .isEmpty,
        isTrue);
  });

  test('rejects bad image signatures and unsafe reference IDs', () async {
    final source = File('${root.path}/not-an-image.bin');
    await source.writeAsString('not an image');

    await expectLater(
      vault.encryptPhoto(source, referenceId: idA),
      throwsA(isA<FaceReferenceVaultException>()),
    );
    await expectLater(
      vault.encryptPhoto(source, referenceId: '../../outside'),
      throwsA(isA<FaceReferenceVaultException>()),
    );
  });

  test('does not replace an existing encrypted reference ID', () async {
    final source = File('${root.path}/source.jpg');
    await source.writeAsBytes([0xff, 0xd8, 0xff, 1, 2, 3]);
    final existing = await vault.encryptPhoto(source, referenceId: idA);
    final originalCiphertext = await File(existing.path).readAsBytes();

    await expectLater(
      vault.encryptPhoto(source, referenceId: idA),
      throwsA(isA<FaceReferenceVaultException>()),
    );
    expect(await File(existing.path).readAsBytes(), originalCiphertext);
  });

  test('tampered ciphertext and wrong key fail authentication', () async {
    final source = File('${root.path}/source.jpg');
    await source.writeAsBytes([0xff, 0xd8, 0xff, 1, 2, 3, 4]);
    final stored = await vault.encryptPhoto(source, referenceId: idA);
    final encryptedFile = File(stored.path);
    final encrypted = await encryptedFile.readAsBytes();
    encrypted[encrypted.length - 1] ^= 1;
    await encryptedFile.writeAsBytes(encrypted, flush: true);

    await expectLater(
      vault.decryptPhoto(stored.path),
      throwsA(isA<FaceReferenceVaultException>()),
    );

    final fresh = await vault.encryptPhoto(source, referenceId: idB);
    final wrongKey = FaceReferenceVault(
      directory: root,
      keyLoader: () async => List<int>.filled(32, 38),
      accountScope: 'workspace-a',
    );
    await expectLater(
      wrongKey.decryptPhoto(fresh.path),
      throwsA(isA<FaceReferenceVaultException>()),
    );
  });

  test('workspace key derivation prevents cross-workspace decryption',
      () async {
    final stored = await vault.encryptPhotoBytes(
      [0xff, 0xd8, 0xff, 1, 2, 3],
      referenceId: idA,
    );
    final otherWorkspace = FaceReferenceVault(
      directory: root,
      keyLoader: () async => key,
      accountScope: 'workspace-b',
    );
    await expectLater(
      otherWorkspace.decryptPhoto(stored.path),
      throwsA(isA<FaceReferenceVaultException>()),
    );
    expect(await vault.decryptPhoto(stored.path), [0xff, 0xd8, 0xff, 1, 2, 3]);
  });

  test('v2 photo lazily migrates to v3 under its workspace key', () async {
    final plain = [0xff, 0xd8, 0xff, 8, 7, 6];
    final cipher = AesGcm.with256bits();
    final legacyHeader = [...'HOTICE-FACE-REF'.codeUnits, 2, 0];
    final aad = [...legacyHeader, ...idA.codeUnits];
    final box = await cipher.encrypt(
      plain,
      secretKey: SecretKey(key),
      nonce: cipher.newNonce(),
      aad: aad,
    );
    final bytes = <int>[
      ...legacyHeader,
      ...box.nonce,
      ...box.mac.bytes,
      ...box.cipherText
    ];
    final path = '${root.path}/$idA.aes';
    await File(path).writeAsBytes(bytes, flush: true);

    expect(await vault.decryptPhoto(path), plain);
    final migrated = await File(path).readAsBytes();
    expect(migrated.take(17).toList(), [...'HOTICE-FACE-REF'.codeUnits, 3, 0]);
    final otherWorkspace = FaceReferenceVault(
      directory: root,
      keyLoader: () async => key,
      accountScope: 'workspace-b',
    );
    await expectLater(
      otherWorkspace.decryptPhoto(path),
      throwsA(isA<FaceReferenceVaultException>()),
    );
  });

  test('deletion removes interrupted migration artifacts without primary file',
      () async {
    final pending = File('${root.path}/$idA.aes.tmp');
    final backup = File('${root.path}/$idA.aes.migration-backup');
    await pending.writeAsBytes([1, 2, 3]);
    await backup.writeAsBytes([4, 5, 6]);

    expect(await vault.deletePhoto('${root.path}/$idA.aes'), isTrue);
    expect(await pending.exists(), isFalse);
    expect(await backup.exists(), isFalse);
    expect(await vault.deletePhoto('${root.path}/$idA.aes'), isFalse);
  });

  test('orphan cleanup restores retained backup if primary was interrupted',
      () async {
    final backup = File('${root.path}/$idA.aes.migration-backup');
    final pending = File('${root.path}/$idA.aes.tmp');
    await backup.writeAsBytes([4, 5, 6]);
    await pending.writeAsBytes([1, 2, 3]);

    expect(
      await vault.deleteOrphanedFiles(
        retainedPaths: ['${root.path}/$idA.aes'],
      ),
      1,
    );
    expect(await File('${root.path}/$idA.aes').readAsBytes(), [4, 5, 6]);
    expect(await backup.exists(), isFalse);
    expect(await pending.exists(), isFalse);
  });

  test('encrypted photo cannot be moved to another reference ID', () async {
    final source = File('${root.path}/source.jpg');
    await source.writeAsBytes([0xff, 0xd8, 0xff, 1, 2, 3]);
    final stored = await vault.encryptPhoto(source, referenceId: idA);
    await File(stored.path).copy('${root.path}/$idB.aes');

    await expectLater(
      vault.decryptPhoto('${root.path}/$idB.aes'),
      throwsA(isA<FaceReferenceVaultException>()),
    );
    expect(await vault.decryptPhoto(stored.path), [0xff, 0xd8, 0xff, 1, 2, 3]);
  });

  test(
    'deletes only unreferenced generated encrypted blobs and temp files',
    () async {
      final source = File('${root.path}/source.jpg');
      await source.writeAsBytes([0xff, 0xd8, 0xff, 1, 2, 3]);
      final retained = await vault.encryptPhoto(source, referenceId: idA);
      final orphan = await vault.encryptPhoto(source, referenceId: idB);
      final pending = File('${root.path}/$idB.tmp');
      await pending.writeAsBytes([1, 2, 3]);
      final unknown = File('${root.path}/notes.txt');
      await unknown.writeAsString('leave this file alone');

      final deleted = await vault.deleteOrphanedFiles(
        retainedPaths: [retained.path],
      );

      expect(deleted, 2);
      expect(await File(retained.path).exists(), isTrue);
      expect(await File(orphan.path).exists(), isFalse);
      expect(await pending.exists(), isFalse);
      expect(await unknown.exists(), isTrue);
    },
  );

  test(
    'rejects paths outside the vault without deleting their target',
    () async {
      final outside = File('${root.parent.path}/face-reference.aes');
      await outside.writeAsBytes([1, 2, 3]);
      addTearDown(() async {
        if (await outside.exists()) await outside.delete();
      });

      await expectLater(
        vault.deletePhoto(outside.path),
        throwsA(isA<FaceReferenceVaultException>()),
      );
      expect(await outside.exists(), isTrue);
    },
  );

  test('key loss never replaces the key for existing encrypted media',
      () async {
    final existing = File('${root.path}/$idA.aes');
    await existing.writeAsBytes([1, 2, 3]);
    var writes = 0;

    await expectLater(
      FaceReferenceVault.loadOrCreateDeviceKey(
        directory: root,
        readEncodedKey: () async => null,
        writeEncodedKey: (_) async => writes++,
      ),
      throwsA(isA<FaceReferenceVaultException>()),
    );
    expect(writes, 0);
    expect(await existing.readAsBytes(), [1, 2, 3]);
  });

  test('key loss detects an in-progress encrypted staging file', () async {
    final staging = File('${root.path}/$idA.aes.tmp');
    await staging.writeAsBytes([1, 2, 3]);
    var writes = 0;

    await expectLater(
      FaceReferenceVault.loadOrCreateDeviceKey(
        directory: root,
        readEncodedKey: () async => null,
        writeEncodedKey: (_) async => writes++,
      ),
      throwsA(isA<FaceReferenceVaultException>()),
    );
    expect(writes, 0);
    expect(await staging.readAsBytes(), [1, 2, 3]);
  });

  test('orphan cleanup deletes an unreferenced encrypted staging filename',
      () async {
    final staging = File('${root.path}/$idA.aes.tmp');
    await staging.writeAsBytes([1, 2, 3]);

    expect(await vault.deleteOrphanedFiles(retainedPaths: []), 1);
    expect(await staging.exists(), isFalse);
  });

  test('creates and verifies a device key only when the vault is empty',
      () async {
    String? savedKey;
    final key = await FaceReferenceVault.loadOrCreateDeviceKey(
      directory: root,
      readEncodedKey: () async => savedKey,
      writeEncodedKey: (value) async => savedKey = value,
    );

    expect(key, hasLength(32));
    expect(savedKey, isNotNull);
    expect(savedKey, matches(RegExp(r'^[A-Za-z0-9+/]{43}=$')));
  });
}
