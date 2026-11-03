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
