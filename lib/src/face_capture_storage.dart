import 'dart:io';

/// Removes abandoned HOTICE camera-capture batches from the app cache.
///
/// Only the scanner's exact generated directory/file names are eligible. A
/// batch still referenced by the in-memory avatar store is retained. Unknown
/// files, nested directories and links are deliberately left untouched.
Future<int> deleteOrphanedFaceCaptureBatches({
  required Directory temporaryRoot,
  required Iterable<String> retainedPhotoPaths,
}) async {
  if (!await temporaryRoot.exists()) return 0;

  String key(String path) {
    final normalized =
        path.replaceAll(RegExp(r'[/\\]+'), Platform.pathSeparator);
    return Platform.isWindows ? normalized.toLowerCase() : normalized;
  }

  String basename(String path) => path
      .replaceAll('\\', '/')
      .split('/')
      .where((part) => part.isNotEmpty)
      .last;
  final retained =
      retainedPhotoPaths.map((path) => key(File(path).absolute.path)).toSet();
  final eligiblePhotoNames = <String>{
    for (final pose in ['front', 'left45', 'right45', 'left90', 'right90'])
      '$pose.jpg',
  };
  var deleted = 0;

  await for (final entity in temporaryRoot.list(followLinks: false)) {
    if (entity is! Directory ||
        !RegExp(r'^hotice-scans-[0-9]+$').hasMatch(basename(entity.path))) {
      continue;
    }

    final photos = <File>[];
    var safeBatch = true;
    var inUse = false;
    await for (final child in entity.list(followLinks: false)) {
      if (child is! File) {
        safeBatch = false;
        break;
      }
      final name = basename(child.path);
      if (!eligiblePhotoNames.contains(name)) {
        safeBatch = false;
        break;
      }
      if (retained.contains(key(child.absolute.path))) inUse = true;
      photos.add(child);
    }
    if (!safeBatch || inUse) continue;

    for (final photo in photos) {
      await photo.delete();
      deleted++;
    }
    await entity.delete();
  }
  return deleted;
}

/// Removes abandoned stills emitted by the pinned Flutter camera plugin.
/// Android writes `CAPxxxxx.jpg` directly in cache; iOS writes
/// `camera/pictures/CAP_<uuid>.jpg`. Only those exact generated forms qualify.
Future<int> deleteAbandonedCameraCaptureFiles({
  required Directory temporaryRoot,
  required bool androidLayout,
  required bool iosLayout,
}) async {
  var deleted = 0;
  final targets = <({Directory directory, RegExp filename})>[
    if (androidLayout)
      (
        directory: temporaryRoot,
        filename: RegExp(r'^CAP[A-Za-z0-9]{5}\.jpg$'),
      ),
    if (iosLayout)
      (
        directory: Directory('${temporaryRoot.path}/camera/pictures'),
        filename: RegExp(
          r'^CAP_[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\.jpg$',
        ),
      ),
  ];
  for (final target in targets) {
    if (await FileSystemEntity.type(target.directory.path,
            followLinks: false) !=
        FileSystemEntityType.directory) {
      continue;
    }
    await for (final entity in target.directory.list(followLinks: false)) {
      if (entity is File && target.filename.hasMatch(_basename(entity.path))) {
        await entity.delete();
        deleted++;
      }
    }
  }
  return deleted;
}

/// Deletes only the known temporary copy created by the pinned file_picker.
/// The Android plugin uses cache/file_picker/<timestamp>/<name>; Darwin uses
/// NSTemporaryDirectory/<uuid>/<name>. Source-library files are never removed.
Future<bool> deletePickerCacheCopyIfOwned({
  required File selectedFile,
  required Directory temporaryRoot,
  required bool androidLayout,
  required bool darwinLayout,
}) async {
  if (await FileSystemEntity.type(selectedFile.path, followLinks: false) !=
      FileSystemEntityType.file) {
    return false;
  }
  final parent = selectedFile.parent;
  final rootPath = _normalizedAbsolutePath(temporaryRoot.path);
  final parentName = _basename(parent.path);
  final parentParent = parent.parent;
  final parentParentName = _basename(parentParent.path);
  if (await FileSystemEntity.type(parent.path, followLinks: false) !=
      FileSystemEntityType.directory) {
    return false;
  }
  final isAndroidCopy = androidLayout &&
      RegExp(r'^[0-9]+$').hasMatch(parentName) &&
      parentParentName == 'file_picker' &&
      _normalizedAbsolutePath(parentParent.parent.path) == rootPath &&
      await FileSystemEntity.type(parentParent.path, followLinks: false) ==
          FileSystemEntityType.directory &&
      await FileSystemEntity.type(
            parentParent.parent.path,
            followLinks: false,
          ) ==
          FileSystemEntityType.directory;
  final isDarwinCopy = darwinLayout &&
      RegExp(
        r'^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$',
      ).hasMatch(parentName) &&
      _normalizedAbsolutePath(parent.parent.path) == rootPath &&
      await FileSystemEntity.type(parent.parent.path, followLinks: false) ==
          FileSystemEntityType.directory;
  if (!isAndroidCopy && !isDarwinCopy) return false;

  await selectedFile.delete();
  final remaining = await parent.list(followLinks: false).isEmpty;
  if (remaining) await parent.delete();
  return true;
}

String _normalizedAbsolutePath(String path) {
  final absolute = Directory(path).absolute.path;
  final normalized =
      absolute.replaceAll(RegExp(r'[/\\]+'), Platform.pathSeparator);
  return Platform.isWindows ? normalized.toLowerCase() : normalized;
}

String _basename(String path) =>
    path.replaceAll('\\', '/').split('/').where((part) => part.isNotEmpty).last;
