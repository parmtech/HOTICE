import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'smart_references.dart';

/// A portable, password-encrypted backup of one actor's typed 2D references.
/// It contains no device paths, vault keys, account IDs, or provider secrets.
class AvatarBackupPhoto {
  const AvatarBackupPhoto({
    required this.view,
    required this.mimeType,
    required this.bytes,
  });

  final FaceView view;
  final String mimeType;
  final Uint8List bytes;
}

class AvatarReferenceBackup {
  const AvatarReferenceBackup({
    required this.name,
    required this.style,
    required this.identityNotes,
    required this.photos,
  });

  final String name;
  final String style;
  final String identityNotes;
  final List<AvatarBackupPhoto> photos;
}

class AvatarReferenceBackupException implements Exception {
  const AvatarReferenceBackupException(this.message);
  final String message;

  @override
  String toString() => 'Actor backup unavailable: $message';
}

/// Versioned AES-256-GCM envelope. PBKDF2 is used because portable archives
/// must survive device changes; the password is required for every operation.
class AvatarReferenceBackupCodec {
  static const iterations = 180000;
  static const maxPhotoBytes = 15 * 1024 * 1024;
  static const maxTotalPhotoBytes = 48 * 1024 * 1024;
  static const _magic = <int>[72, 79, 84, 73, 67, 69, 65, 66]; // HOTICEAB
  static const _version = 1;
  static const _saltLength = 16;
  static const _nonceLength = 12;
  static const _macLength = 16;

  final Pbkdf2 _kdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
    bits: 256,
  );
  final AesGcm _cipher = AesGcm.with256bits();

  Future<Uint8List> encode(
    AvatarReferenceBackup backup, {
    required String password,
  }) async {
    _validatePassword(password);
    _validateActor(backup);
    final document = <String, Object>{
      'schema': 1,
      'actor': {
        'name': backup.name,
        'style': backup.style,
        'identityNotes': backup.identityNotes,
      },
      'photos': [
        for (final photo in backup.photos)
          {
            'view': photo.view.name,
            'mimeType': photo.mimeType,
            'bytes': base64Encode(photo.bytes),
          },
      ],
    };
    final clear = utf8.encode(jsonEncode(document));
    final entropy = Random.secure();
    final salt = List<int>.generate(_saltLength, (_) => entropy.nextInt(256));
    final nonce = List<int>.generate(_nonceLength, (_) => entropy.nextInt(256));
    final secretKey = await _kdf.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    final sealed = await _cipher.encrypt(
      clear,
      secretKey: secretKey,
      nonce: nonce,
      aad: [..._magic, _version],
    );
    return Uint8List.fromList([
      ..._magic,
      _version,
      ...salt,
      ...sealed.nonce,
      ...sealed.mac.bytes,
      ...sealed.cipherText,
    ]);
  }

  Future<AvatarReferenceBackup> decode(
    List<int> envelope, {
    required String password,
  }) async {
    _validatePassword(password);
    final minimum =
        _magic.length + 1 + _saltLength + _nonceLength + _macLength + 2;
    if (envelope.length < minimum ||
        envelope.length > maxTotalPhotoBytes * 2 + 1024 * 1024) {
      throw const AvatarReferenceBackupException('The backup size is invalid.');
    }
    for (var i = 0; i < _magic.length; i++) {
      if (envelope[i] != _magic[i]) {
        throw const AvatarReferenceBackupException(
            'This is not a HOTICE actor backup.');
      }
    }
    if (envelope[_magic.length] != _version) {
      throw const AvatarReferenceBackupException(
          'This actor backup version is not supported.');
    }
    var offset = _magic.length + 1;
    final salt = envelope.sublist(offset, offset += _saltLength);
    final nonce = envelope.sublist(offset, offset += _nonceLength);
    final mac = envelope.sublist(offset, offset += _macLength);
    final cipherText = envelope.sublist(offset);
    try {
      final secretKey = await _kdf.deriveKey(
        secretKey: SecretKey(utf8.encode(password)),
        nonce: salt,
      );
      final clear = await _cipher.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: secretKey,
        aad: [..._magic, _version],
      );
      final decoded = jsonDecode(utf8.decode(clear));
      if (decoded is! Map<String, dynamic> ||
          decoded['schema'] != 1 ||
          decoded['actor'] is! Map<String, dynamic> ||
          decoded['photos'] is! List) {
        throw const FormatException('Invalid backup document.');
      }
      final actor = decoded['actor'] as Map<String, dynamic>;
      final rows = decoded['photos'] as List;
      if (rows.isEmpty || rows.length > 16) {
        throw const FormatException('Invalid photo count.');
      }
      final photos = <AvatarBackupPhoto>[];
      for (final row in rows) {
        if (row is! Map<String, dynamic>)
          throw const FormatException('Invalid photo row.');
        final viewName = row['view'];
        final mime = row['mimeType'];
        final encoded = row['bytes'];
        final view = FaceView.values
            .where((value) => value.name == viewName)
            .firstOrNull;
        if (view == null || mime is! String || encoded is! String) {
          throw const FormatException('Invalid photo metadata.');
        }
        if (encoded.length > (maxPhotoBytes * 4 / 3).ceil() + 4) {
          throw const FormatException('Photo exceeds the per-image limit.');
        }
        final bytes = base64Decode(encoded);
        photos.add(AvatarBackupPhoto(
            view: view, mimeType: mime, bytes: Uint8List.fromList(bytes)));
      }
      final result = AvatarReferenceBackup(
        name: actor['name'] as String,
        style: actor['style'] as String,
        identityNotes: actor['identityNotes'] as String,
        photos: List.unmodifiable(photos),
      );
      _validateActor(result);
      return result;
    } on SecretBoxAuthenticationError {
      throw const AvatarReferenceBackupException(
          'Password is incorrect or the backup was changed.');
    } on FormatException {
      throw const AvatarReferenceBackupException(
          'The encrypted backup contents are invalid.');
    } on TypeError {
      throw const AvatarReferenceBackupException(
          'The encrypted backup contents are invalid.');
    }
  }

  static void _validatePassword(String password) {
    if (password.length < 12 || password.length > 1024) {
      throw const AvatarReferenceBackupException(
          'Use a backup password between 12 and 1024 characters.');
    }
  }

  static void _validateActor(AvatarReferenceBackup backup) {
    if (backup.name.trim().isEmpty ||
        backup.name.length > 60 ||
        backup.style.trim().isEmpty ||
        backup.style.length > 80 ||
        backup.identityNotes.length > 350 ||
        backup.photos.isEmpty ||
        backup.photos.length > 16) {
      throw const AvatarReferenceBackupException(
          'Actor details or photo count exceed backup limits.');
    }
    var total = 0;
    for (final photo in backup.photos) {
      if (!const ['image/jpeg', 'image/png', 'image/webp']
              .contains(photo.mimeType) ||
          !_matchesMime(photo.bytes, photo.mimeType) ||
          photo.bytes.isEmpty ||
          photo.bytes.length > maxPhotoBytes) {
        throw const AvatarReferenceBackupException(
            'A photo is not a valid supported image.');
      }
      total += photo.bytes.length;
      if (total > maxTotalPhotoBytes) {
        throw const AvatarReferenceBackupException(
            'Actor photos exceed the 48 MiB backup limit.');
      }
    }
  }

  static bool _matchesMime(List<int> bytes, String mime) {
    if (mime == 'image/jpeg') {
      return bytes.length >= 3 &&
          bytes[0] == 0xff &&
          bytes[1] == 0xd8 &&
          bytes[2] == 0xff;
    }
    if (mime == 'image/png') {
      const signature = [137, 80, 78, 71, 13, 10, 26, 10];
      return bytes.length >= signature.length &&
          List.generate(signature.length, (i) => bytes[i] == signature[i])
              .every((v) => v);
    }
    return bytes.length >= 12 &&
        ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
        ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP';
  }
}
