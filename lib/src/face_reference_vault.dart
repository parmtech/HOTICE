import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

enum FaceReferenceVaultFailure { deviceKeyUnavailable, other }

class FaceReferenceVaultException implements Exception {
  const FaceReferenceVaultException(
    this.message, {
    this.failure = FaceReferenceVaultFailure.other,
  });
  final String message;
  final FaceReferenceVaultFailure failure;

  @override
  String toString() => 'Face reference vault unavailable: $message';
}

class StoredFaceReference {
  const StoredFaceReference({
    required this.id,
    required this.path,
    required this.mimeType,
    required this.clearBytes,
  });

  final String id;
  final String path;
  final String mimeType;

  /// Byte count is metadata only; clear image bytes are never returned.
  final int clearBytes;
}

/// AES-GCM encrypted, app-private storage for consented face-reference images.
/// Reference metadata and ownership live in the separate encrypted local
/// project archive; image bytes never live in that JSON archive.
class FaceReferenceVault {
  FaceReferenceVault({
    required this.directory,
    required this.keyLoader,
    this.accountScope,
  });

  final Directory directory;
  final Future<List<int>> Function() keyLoader;

  /// Stable workspace ID (demo ID or server subject ID), never an email.
  /// Null is allowed only for path-validated deletion and orphan cleanup.
  final String? accountScope;
  final AesGcm _cipher = AesGcm.with256bits();

  static const _keyName = 'hotice-face-reference-key-v1';
  static const _maxPhotoBytes = 15 * 1024 * 1024;
  static final _idPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );
  static final _legacyHeader = <int>[...ascii.encode('HOTICE-FACE-REF'), 2, 0];
  static final _header = <int>[...ascii.encode('HOTICE-FACE-REF'), 3, 0];

  static Future<FaceReferenceVault> openOnDevice({String? accountScope}) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw const FaceReferenceVaultException(
        'Encrypted face-photo storage is currently available on Android and iOS.',
      );
    }
    final support = await getApplicationSupportDirectory();
    final directory = Directory('${support.path}/hotice-face-reference-vault');
    await directory.create(recursive: true);
    const storage = FlutterSecureStorage();
    return FaceReferenceVault(
      directory: directory,
      accountScope: accountScope,
      keyLoader: () => loadOrCreateDeviceKey(
        directory: directory,
        readEncodedKey: () => storage.read(key: _keyName),
        writeEncodedKey: (value) => storage.write(key: _keyName, value: value),
      ),
    );
  }

  /// Loads the OS-held key or creates one only when no encrypted media exists.
  /// Injected callbacks keep key-loss and failed-persistence behavior testable.
  static Future<List<int>> loadOrCreateDeviceKey({
    required Directory directory,
    required Future<String?> Function() readEncodedKey,
    required Future<void> Function(String encodedKey) writeEncodedKey,
  }) async {
    final encoded = await readEncodedKey();
    if (encoded != null) {
      final key = _decodeKey(encoded);
      if (key.length != 32) {
        throw const FaceReferenceVaultException(
          'The device encryption key is invalid.',
        );
      }
      return key;
    }
    if (await _containsEncryptedData(directory)) {
      throw const FaceReferenceVaultException(
        'The device key is unavailable for existing encrypted face photos.',
        failure: FaceReferenceVaultFailure.deviceKeyUnavailable,
      );
    }
    final entropy = Random.secure();
    final key = List<int>.generate(32, (_) => entropy.nextInt(256));
    await writeEncodedKey(base64Encode(key));
    final persisted = await readEncodedKey();
    if (persisted == null || !_sameKey(key, _decodeKey(persisted))) {
      throw const FaceReferenceVaultException(
        'The device could not safely save the face-photo key.',
      );
    }
    return key;
  }

  static List<int> _decodeKey(String encoded) {
    if (encoded.length != 44) {
      throw const FaceReferenceVaultException(
        'The device encryption key has an invalid size.',
      );
    }
    try {
      return base64Decode(encoded);
    } on FormatException {
      throw const FaceReferenceVaultException(
        'The device encryption key is malformed.',
      );
    }
  }

  static bool _sameKey(List<int> first, List<int> second) {
    if (first.length != second.length) return false;
    var different = 0;
    for (var i = 0; i < first.length; i++) {
      different |= first[i] ^ second[i];
    }
    return different == 0;
  }

  static Future<bool> _containsEncryptedData(Directory root) async {
    if (!await root.exists()) return false;
    await for (final entity in root.list(followLinks: false)) {
      if (entity is File &&
          RegExp(r'^[0-9a-f-]{36}\.(?:aes|aes\.tmp|tmp|aes\.migration-backup)$')
              .hasMatch(_basename(entity.path))) {
        return true;
      }
    }
    return false;
  }

  static String _basename(String path) => path
      .replaceAll('\\', '/')
      .split('/')
      .where((part) => part.isNotEmpty)
      .last;

  File _fileFor(String id) {
    if (!_idPattern.hasMatch(id)) {
      throw const FaceReferenceVaultException('Invalid media reference ID.');
    }
    return File('${directory.path}/$id.aes');
  }

  Future<List<int>> _rootKey() async {
    final key = await keyLoader();
    if (key.length != 32 || key.any((byte) => byte < 0 || byte > 255)) {
      throw const FaceReferenceVaultException('Invalid encryption key length.');
    }
    return key;
  }

  Future<List<int>> _workspaceKey() async {
    final scope = accountScope;
    if (scope == null ||
        scope.isEmpty ||
        scope.trim() != scope ||
        scope.length > 256 ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(scope)) {
      throw const FaceReferenceVaultException(
        'A valid local workspace identity is required to access face photos.',
      );
    }
    final derived = await Hmac.sha256().calculateMac(
      utf8.encode('HOTICE-FACE-REFERENCE-WORKSPACE-V1\u0000$scope'),
      secretKey: SecretKey(await _rootKey()),
    );
    return derived.bytes;
  }

  Future<StoredFaceReference> encryptPhoto(
    File source, {
    required String referenceId,
  }) async {
    final sourceLength = await source.length();
    if (sourceLength <= 0 || sourceLength > _maxPhotoBytes) {
      throw const FaceReferenceVaultException(
        'Choose a non-empty image no larger than 15 MiB.',
      );
    }
    final clear = await source.readAsBytes();
    if (clear.isEmpty || clear.length != sourceLength) {
      throw const FaceReferenceVaultException(
        'Choose a non-empty image no larger than 15 MiB.',
      );
    }
    return encryptPhotoBytes(clear, referenceId: referenceId);
  }

  /// Encrypts validated in-memory bytes without writing a plaintext staging
  /// file. Portable actor recovery uses this path for decrypted archive data.
  Future<StoredFaceReference> encryptPhotoBytes(
    List<int> clear, {
    required String referenceId,
  }) async {
    final destination = _fileFor(referenceId);
    if (await FileSystemEntity.type(destination.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw const FaceReferenceVaultException(
        'A face photo already exists for this reference ID.',
      );
    }
    if (clear.isEmpty || clear.length > _maxPhotoBytes) {
      throw const FaceReferenceVaultException(
        'Choose a non-empty image no larger than 15 MiB.',
      );
    }
    final mimeType = _detectImageMime(clear);
    if (mimeType == null) {
      throw const FaceReferenceVaultException(
        'The selected file is not a supported JPEG, PNG, or WebP image.',
      );
    }

    try {
      final bytes = await _sealedPhoto(clear, referenceId);
      await _writeNewPhoto(destination, bytes);
    } catch (_) {
      throw const FaceReferenceVaultException(
        'The encrypted face photo could not be saved.',
      );
    }
    return StoredFaceReference(
      id: referenceId,
      path: destination.path,
      mimeType: mimeType,
      clearBytes: clear.length,
    );
  }

  Future<List<int>> _sealedPhoto(List<int> clear, String id) async {
    final secretBox = await _cipher.encrypt(
      clear,
      secretKey: SecretKey(await _workspaceKey()),
      nonce: _cipher.newNonce(),
      aad: _authenticatedMetadata(id, legacy: false),
    );
    final output = BytesBuilder(copy: false)
      ..add(_header)
      ..add(secretBox.nonce)
      ..add(secretBox.mac.bytes)
      ..add(secretBox.cipherText);
    return output.takeBytes();
  }

  Future<void> _writeNewPhoto(File destination, List<int> bytes) async {
    final pending = File('${destination.path}.tmp');
    try {
      if (await pending.exists()) await pending.delete();
      await pending.writeAsBytes(bytes, flush: true);
      if (await FileSystemEntity.type(destination.path, followLinks: false) !=
          FileSystemEntityType.notFound) {
        throw const FileSystemException('A photo already exists.');
      }
      await pending.rename(destination.path);
    } catch (_) {
      try {
        if (await pending.exists()) await pending.delete();
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> _replacePhotoWithMigratedVersion(
    File destination,
    List<int> bytes,
  ) async {
    final pending = File('${destination.path}.tmp');
    final backup = File('${destination.path}.migration-backup');
    try {
      if (await pending.exists()) await pending.delete();
      await pending.writeAsBytes(bytes, flush: true);
      if (await backup.exists()) {
        throw const FileSystemException(
            'An earlier photo migration needs recovery.');
      }
      if (await destination.exists()) await destination.rename(backup.path);
      try {
        await pending.rename(destination.path);
      } catch (_) {
        if (!await destination.exists() && await backup.exists()) {
          await backup.rename(destination.path);
        }
        rethrow;
      }
      if (await backup.exists()) {
        try {
          await backup.delete();
        } catch (_) {
          // The current file is already authenticated v3. Orphan cleanup
          // removes the old ciphertext after confirming the retained file.
        }
      }
    } catch (_) {
      try {
        if (await pending.exists()) await pending.delete();
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> _recoverInterruptedReplacement(File destination) async {
    final backup = File('${destination.path}.migration-backup');
    if (!await destination.exists() && await backup.exists()) {
      await backup.rename(destination.path);
    }
  }

  static bool _hasHeader(List<int> bytes, List<int> header) {
    if (bytes.length < header.length) return false;
    for (var i = 0; i < header.length; i++) {
      if (bytes[i] != header[i]) return false;
    }
    return true;
  }

  Future<Uint8List> decryptPhoto(String path) async {
    final id = _idFromPath(path);
    final file = _fileFor(id);
    await _recoverInterruptedReplacement(file);
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const FaceReferenceVaultException(
        'Encrypted photo is unavailable.',
      );
    }
    final data = await file.readAsBytes();
    final encryptedLength = data.length;
    final legacy = _hasHeader(data, _legacyHeader);
    final current = !legacy && _hasHeader(data, _header);
    if (!legacy && !current) {
      throw const FaceReferenceVaultException(
        'Unsupported photo vault format.',
      );
    }
    if (legacy && accountScope == null) {
      throw const FaceReferenceVaultException(
        'Choose the original workspace to migrate this face photo.',
      );
    }
    final prefixLength = legacy ? _legacyHeader.length : _header.length;
    const nonceLength = 12;
    const macLength = 16;
    if (encryptedLength <= prefixLength + nonceLength + macLength ||
        encryptedLength >
            _maxPhotoBytes + prefixLength + nonceLength + macLength) {
      throw const FaceReferenceVaultException('Encrypted photo is malformed.');
    }
    final nonce = data.sublist(prefixLength, prefixLength + nonceLength);
    final mac = data.sublist(
      prefixLength + nonceLength,
      prefixLength + nonceLength + macLength,
    );
    final cipherText = data.sublist(prefixLength + nonceLength + macLength);
    try {
      final clear = await _cipher.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: SecretKey(
          legacy ? await _rootKey() : await _workspaceKey(),
        ),
        aad: _authenticatedMetadata(id, legacy: legacy),
      );
      if (_detectImageMime(clear) == null) {
        throw const FaceReferenceVaultException('Decrypted photo is invalid.');
      }
      if (legacy) {
        await _replacePhotoWithMigratedVersion(
          file,
          await _sealedPhoto(clear, id),
        );
      } else {
        final backup = File('${file.path}.migration-backup');
        if (await backup.exists()) {
          try {
            await backup.delete();
          } catch (_) {}
        }
      }
      return Uint8List.fromList(clear);
    } on SecretBoxAuthenticationError {
      throw const FaceReferenceVaultException(
        'The photo cannot be authenticated for the active workspace.',
      );
    }
  }

  Future<bool> deletePhoto(String path) async {
    final id = _idFromPath(path);
    final file = _fileFor(id);
    var deleted = false;
    for (final candidate in [
      file,
      File('${file.path}.tmp'),
      File('${file.path}.migration-backup'),
    ]) {
      if (await FileSystemEntity.type(candidate.path, followLinks: false) ==
          FileSystemEntityType.file) {
        await candidate.delete();
        deleted = true;
      }
    }
    return deleted;
  }

  Future<int> deleteOrphanedFiles({
    required Iterable<String> retainedPaths,
  }) async {
    // Unlock first. A transient secure-storage failure must never purge files
    // that may still be recoverable after the OS key store becomes available.
    await _rootKey();
    final retained = retainedPaths.map(_normalizedPath).toSet();
    var deleted = 0;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      final basename = _basename(entity.path);
      final match = RegExp(
        r'^([0-9a-f-]{36})\.(aes|aes\.tmp|tmp|aes\.migration-backup)$',
      ).firstMatch(basename);
      if (match == null) continue;
      final id = match.group(1)!;
      if (!_idPattern.hasMatch(id)) continue;
      final kind = match.group(2)!;
      final main = _fileFor(id);
      final backup = File('${main.path}.migration-backup');
      if (kind == 'aes.migration-backup') {
        if (retained.contains(_normalizedPath(main.path))) {
          if (await main.exists()) {
            await entity.delete();
            deleted++;
          } else {
            await entity.rename(main.path);
          }
          continue;
        }
        await entity.delete();
        deleted++;
        continue;
      }
      if (kind == 'aes' && retained.contains(_normalizedPath(entity.path))) {
        // A completed replacement wins; its old ciphertext is disposable.
        if (await backup.exists()) {
          await backup.delete();
          deleted++;
        }
        continue;
      }
      await entity.delete();
      deleted++;
    }
    return deleted;
  }

  String _idFromPath(String path) {
    final name = _basename(path);
    if (!name.endsWith('.aes')) {
      throw const FaceReferenceVaultException('Invalid vault photo path.');
    }
    final id = name.substring(0, name.length - 4);
    final expected = _fileFor(id);
    if (_normalizedPath(path) != _normalizedPath(expected.path)) {
      throw const FaceReferenceVaultException(
        'Photo path is outside the vault.',
      );
    }
    return id;
  }

  String _normalizedPath(String path) {
    final normalized = path.replaceAll(
      RegExp(r'[/\\]+'),
      Platform.pathSeparator,
    );
    return Platform.isWindows ? normalized.toLowerCase() : normalized;
  }

  List<int> _authenticatedMetadata(String id, {required bool legacy}) {
    if (legacy) {
      return List<int>.unmodifiable([..._legacyHeader, ...ascii.encode(id)]);
    }
    final scope = accountScope;
    if (scope == null) {
      throw const FaceReferenceVaultException(
        'A valid local workspace identity is required to access face photos.',
      );
    }
    return List<int>.unmodifiable([
      ..._header,
      ...utf8.encode(scope),
      0,
      ...ascii.encode(id),
    ]);
  }

  static String? _detectImageMime(List<int> bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      return 'image/jpeg';
    }
    const png = [137, 80, 78, 71, 13, 10, 26, 10];
    if (bytes.length >= png.length) {
      var isPng = true;
      for (var i = 0; i < png.length; i++) {
        if (bytes[i] != png[i]) {
          isPng = false;
          break;
        }
      }
      if (isPng) return 'image/png';
    }
    if (bytes.length >= 12 &&
        ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
        ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP') {
      return 'image/webp';
    }
    return null;
  }
}
