import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hotice/src/face_capture_storage.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('hotice-storage-test-');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<Directory> batch(String name) async {
    final directory = Directory('${root.path}/hotice-scans-$name');
    await directory.create(recursive: true);
    return directory;
  }

  test('deletes only abandoned scanner photos and their empty batch', () async {
    final capture = await batch('123456');
    for (final name in ['front.jpg', 'left45.jpg', 'right45.jpg']) {
      await File('${capture.path}/$name').writeAsBytes([1, 2, 3]);
    }
    final unrelated = Directory('${root.path}/other-cache')..createSync();
    await File('${unrelated.path}/keep.jpg').writeAsBytes([4, 5, 6]);

    final deleted = await deleteOrphanedFaceCaptureBatches(
      temporaryRoot: root,
      retainedPhotoPaths: const [],
    );

    expect(deleted, 3);
    expect(await capture.exists(), isFalse);
    expect(await File('${unrelated.path}/keep.jpg').exists(), isTrue);
  });

  test(
    'keeps a batch referenced by the active in-memory avatar store',
    () async {
      final capture = await batch('123457');
      final retained = File('${capture.path}/front.jpg');
      await retained.writeAsBytes([1, 2, 3]);
      final orphan = File('${capture.path}/left45.jpg');
      await orphan.writeAsBytes([4, 5, 6]);

      final deleted = await deleteOrphanedFaceCaptureBatches(
        temporaryRoot: root,
        retainedPhotoPaths: [retained.path],
      );

      expect(deleted, 0);
      expect(await retained.exists(), isTrue);
      expect(await orphan.exists(), isTrue);
    },
  );

  test(
    'leaves unexpected files untouched instead of recursively deleting',
    () async {
      final capture = await batch('123458');
      final photo = File('${capture.path}/front.jpg');
      await photo.writeAsBytes([1, 2, 3]);
      final unknown = File('${capture.path}/notes.txt');
      await unknown.writeAsString('preserve unknown data');

      final deleted = await deleteOrphanedFaceCaptureBatches(
        temporaryRoot: root,
        retainedPhotoPaths: const [],
      );

      expect(deleted, 0);
      expect(await photo.exists(), isTrue);
      expect(await unknown.exists(), isTrue);
    },
  );

  test(
    'ignores directories that do not match the scanner naming scheme',
    () async {
      final lookalike = Directory('${root.path}/hotice-scans-backup')
        ..createSync();
      final photo = File('${lookalike.path}/front.jpg');
      await photo.writeAsBytes([1, 2, 3]);

      final deleted = await deleteOrphanedFaceCaptureBatches(
        temporaryRoot: root,
        retainedPhotoPaths: const [],
      );

      expect(deleted, 0);
      expect(await photo.exists(), isTrue);
    },
  );
}
