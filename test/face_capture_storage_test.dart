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

  test('cleans only pinned Android/iOS camera-plugin temporary still names',
      () async {
    final androidStale = File('${root.path}/CAPabc12.jpg');
    final androidUnknown = File('${root.path}/CAPnot-a-camera.jpg');
    final iosDirectory = Directory('${root.path}/camera/pictures')
      ..createSync(recursive: true);
    final iosStale = File(
      '${iosDirectory.path}/CAP_1DBD4A72-BFDE-4330-8A21-5F01D9BE4E61.jpg',
    );
    final iosUnknown = File('${iosDirectory.path}/CAP_custom.jpg');
    for (final file in [androidStale, androidUnknown, iosStale, iosUnknown]) {
      await file.writeAsBytes([1, 2, 3]);
    }

    final deleted = await deleteAbandonedCameraCaptureFiles(
      temporaryRoot: root,
      androidLayout: true,
      iosLayout: true,
    );

    expect(deleted, 2);
    expect(await androidStale.exists(), isFalse);
    expect(await iosStale.exists(), isFalse);
    expect(await androidUnknown.exists(), isTrue);
    expect(await iosUnknown.exists(), isTrue);
  });

  test('removes only file-picker copies inside its known platform cache layout',
      () async {
    final androidCopy = File(
      '${root.path}/file_picker/1730723400000/face.jpg',
    );
    await androidCopy.parent.create(recursive: true);
    await androidCopy.writeAsBytes([1, 2, 3]);
    final darwinCopy = File(
      '${root.path}/1DBD4A72-BFDE-4330-8A21-5F01D9BE4E61/face.jpg',
    );
    await darwinCopy.parent.create(recursive: true);
    await darwinCopy.writeAsBytes([4, 5, 6]);
    final unrelated = File('${root.path}/user-owned/face.jpg');
    await unrelated.parent.create(recursive: true);
    await unrelated.writeAsBytes([7, 8, 9]);

    expect(
      await deletePickerCacheCopyIfOwned(
        selectedFile: androidCopy,
        temporaryRoot: root,
        androidLayout: true,
        darwinLayout: false,
      ),
      isTrue,
    );
    expect(
      await deletePickerCacheCopyIfOwned(
        selectedFile: darwinCopy,
        temporaryRoot: root,
        androidLayout: false,
        darwinLayout: true,
      ),
      isTrue,
    );
    expect(
      await deletePickerCacheCopyIfOwned(
        selectedFile: unrelated,
        temporaryRoot: root,
        androidLayout: true,
        darwinLayout: true,
      ),
      isFalse,
    );
    expect(await androidCopy.exists(), isFalse);
    expect(await darwinCopy.exists(), isFalse);
    expect(await unrelated.exists(), isTrue);
  });
}
