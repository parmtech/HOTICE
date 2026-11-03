import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hotice/src/local_store.dart';
import 'package:hotice/src/state.dart';
import 'package:hotice/src/smart_references.dart';
import 'package:hotice/src/video_models.dart';

void main() {
  test('archive write failure is visible and latest snapshot can be retried',
      () async {
    final dir = await Directory.systemTemp.createTemp('hotice-save-status-');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    var failWrites = true;
    final archive = HotIceLocalArchive(
      directory: dir,
      keyLoader: () async {
        if (failWrites) {
          throw const HotIceLocalArchiveException('test failure');
        }
        return List<int>.filled(32, 17);
      },
    );
    addTearDown(archive.dispose);
    final store = HotIceStore();
    addTearDown(store.dispose);
    store.addProject('Recoverable local work');

    archive.enqueue(store.exportLocalSnapshot());
    expect(archive.writeState, LocalArchiveWriteState.saving);
    await archive.flush();
    expect(archive.writeState, LocalArchiveWriteState.failed);

    failWrites = false;
    archive.retryLastWrite();
    await archive.flush();
    expect(archive.writeState, LocalArchiveWriteState.saved);
    expect((await archive.restore())?['workspaces'], isNotNull);
  });

  test('archive status never claims a prior save before one exists', () async {
    final dir = await Directory.systemTemp.createTemp('hotice-first-save-');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    var failWrites = false;
    final archive = HotIceLocalArchive(
      directory: dir,
      keyLoader: () async {
        if (failWrites) {
          throw const HotIceLocalArchiveException('test failure');
        }
        return List<int>.filled(32, 21);
      },
    );
    addTearDown(archive.dispose);
    final store = HotIceStore();
    addTearDown(store.dispose);

    expect(archive.writeState, LocalArchiveWriteState.unsaved);
    expect(archive.hasSavedSnapshot, isFalse);
    store.addProject('First local work');
    archive.enqueue(store.exportLocalSnapshot());
    await archive.flush();
    expect(archive.writeState, LocalArchiveWriteState.saved);
    expect(archive.hasSavedSnapshot, isTrue);

    failWrites = true;
    store.addProject('Later local work');
    archive.enqueue(store.exportLocalSnapshot());
    await archive.flush();
    expect(archive.writeState, LocalArchiveWriteState.failed);
    expect(archive.hasSavedSnapshot, isTrue);
  });

  test('encrypted schema 1 archive remains readable during migration',
      () async {
    final dir = await Directory.systemTemp.createTemp('hotice-legacy-archive-');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    final archive = HotIceLocalArchive(
      directory: dir,
      keyLoader: () async => List<int>.filled(32, 31),
    );
    archive.enqueue({
      'schema': 1,
      'selectedAccount': 'legacy@example.com',
      'workspaces': {
        'legacy@example.com': {
          'projects': [
            {
              'id': 'legacy-project-id',
              'title': 'Keep my old project',
              'createdAt': '2026-10-01T00:00:00.000',
            },
          ],
        },
      },
    });
    await archive.flush();
    final snapshot = await archive.restore();
    expect(snapshot?['schema'], 1);
    final store = HotIceStore()..restoreLocalSnapshot(snapshot!);
    expect(store.projects.single.id, 'legacy-project-id');
    expect(store.exportLocalSnapshot()['schema'], 2);
    store.dispose();
  });

  test('encrypted archive follows a stable account ID after email change',
      () async {
    final dir = await Directory.systemTemp.createTemp('hotice-account-id-');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    final archive = HotIceLocalArchive(
      directory: dir,
      keyLoader: () async => List<int>.filled(32, 73),
    );
    final first = HotIceStore()
      ..signInAuthenticated('immutable-subject-7', 'old@example.com');
    final id = first.addProject('Survives email change');
    archive.enqueue(first.exportLocalSnapshot());
    await archive.flush();

    final restoredData = await archive.restore();
    expect(restoredData, isNotNull);
    final restored = HotIceStore()..restoreLocalSnapshot(restoredData!);
    expect(restored.signedIn, isFalse);
    restored.signInAuthenticated('immutable-subject-7', 'new@example.com');
    expect(restored.projects.single.id, id);
    restored.signInAuthenticated('another-subject', 'new@example.com');
    expect(restored.projects, isEmpty);
    first.dispose();
    restored.dispose();
  });

  test(
      'encrypted archive persists projects and draft workspaces across restarts',
      () async {
    final dir = await Directory.systemTemp.createTemp('hotice-local-test-');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    final archive = HotIceLocalArchive(
      directory: dir,
      keyLoader: () async => List<int>.filled(32, 41),
    );
    final first = HotIceStore();
    final id = first.addProject('Private sunset project');
    first.addAvatar('Local Hero', 'Cinematic', identityNotes: 'Brown eyes');
    first.queueDraft(GenerationDraft(
      projectId: id,
      project: 'Private sunset project',
      prompt: 'At sunrise, a red kite flies over water.',
      model: 'Cinematic Draft',
      aspectRatio: '16:9',
      durationSeconds: 8,
      createdAt: DateTime(2026, 10, 27),
      avatarName: 'Local Hero',
      requestedAttachments: const [VideoAttachment.image],
      actors: const [
        SceneActor(avatarName: 'Local Hero', sceneName: 'Rooftop')
      ],
      referenceFiles: const [
        SceneReference(
            type: VideoAttachment.image, fileName: 'ref.png', bytes: 4096)
      ],
      negativePrompt: 'No text overlays',
      seed: 4242,
      soundEnabled: true,
    ));
    first.addAccount('second@example.com');
    final secondId = first.addProject('Second device profile');
    first.signInDemo('second@example.com');
    archive.enqueue(first.exportLocalSnapshot());
    await archive.flush();

    final dataFile = File('${dir.path}/hotice-projects-v1.aes');
    expect(await dataFile.exists(), isTrue);
    final raw = await dataFile.readAsString();
    expect(raw, isNot(contains('Private sunset project')));
    expect(raw, isNot(contains('Brown eyes')));
    expect(raw, isNot(contains('second@example.com')));

    final restored = await archive.restore();
    expect(restored, isNotNull);
    final afterRestart = HotIceStore();
    afterRestart.restoreLocalSnapshot(restored!);
    expect(afterRestart.signedIn, isFalse);
    expect(afterRestart.selectedAccount, 'second@example.com');
    expect(afterRestart.projects.any((p) => p.id == secondId), isTrue);
    afterRestart.switchAccount('creator@hotice.demo');
    expect(afterRestart.projects.any((p) => p.id == id), isTrue);
    expect(afterRestart.drafts.single.prompt, contains('red kite'));
    expect(afterRestart.drafts.single.negativePrompt, 'No text overlays');
    expect(afterRestart.drafts.single.seed, 4242);
    expect(afterRestart.drafts.single.soundEnabled, isTrue);
    expect(afterRestart.drafts.single.actors.single.sceneName, 'Rooftop');
    expect(
        afterRestart.drafts.single.referenceFiles.single.fileName, 'ref.png');
    expect(afterRestart.drafts.single.requestedAttachments,
        [VideoAttachment.image]);
    expect(afterRestart.avatars.any((a) => a.name == 'Local Hero'), isTrue);
    expect(afterRestart.projects.any((p) => p.id == secondId), isFalse);
    first.dispose();
    afterRestart.dispose();
  });

  test(
      'reference metadata and draft selection survive encrypted archive restart',
      () async {
    final dir = await Directory.systemTemp.createTemp('hotice-ref-roundtrip-');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    final archive = HotIceLocalArchive(
        directory: dir, keyLoader: () async => List<int>.filled(32, 61));
    final original = HotIceStore()..signInDemo('refs@example.com');
    final project = original.addProject('Reference scene');
    original.addAvatar('Hero', 'Film');
    final avatarId = createLocalProjectId();
    final sceneId = createLocalProjectId();
    expect(
        original.addAvatarReference(
            'Hero',
            AvatarReference(
                id: avatarId,
                ownerName: 'Hero',
                role: ReferenceRole.avatar,
                format: ReferenceFormat.image,
                mimeType: 'image/jpeg',
                localPath: '/vault/$avatarId.aes',
                view: FaceView.front)),
        isTrue);
    expect(
        original.addSceneReference(
            project,
            AvatarReference(
                id: sceneId,
                ownerName: project,
                role: ReferenceRole.location,
                format: ReferenceFormat.image,
                mimeType: 'image/png',
                localPath: '/vault/$sceneId.aes')),
        isTrue);
    original.queueDraft(GenerationDraft(
        projectId: project,
        project: 'Reference scene',
        prompt: 'Shot',
        model: 'Cinematic Draft',
        modelId: 'cinematic_demo',
        aspectRatio: '16:9',
        durationSeconds: 8,
        avatarName: 'Hero',
        selectedReferenceIds: [avatarId, sceneId],
        createdAt: DateTime(2026, 11, 4)));
    archive.enqueue(original.exportLocalSnapshot());
    await archive.flush();
    final ciphertext =
        await File('${dir.path}/hotice-projects-v1.aes').readAsString();
    expect(ciphertext, isNot(contains(avatarId)));
    final restored = HotIceStore()
      ..restoreLocalSnapshot((await archive.restore())!);
    restored.signInDemo('refs@example.com');
    expect(restored.avatarPackFor('Hero').assets.single.view, FaceView.front);
    expect(restored.sceneReferencesFor(project).single.role,
        ReferenceRole.location);
    expect(restored.drafts.single.selectedReferenceIds, [avatarId, sceneId]);
    original.dispose();
    restored.dispose();
    archive.dispose();
  });

  test('reference restore rejects mismatched owners and arbitrary paths', () {
    final store = HotIceStore();
    final id = createLocalProjectId();
    store.restoreLocalSnapshot({
      'schema': 2,
      'selectedAccount': 'refs@example.com',
      'workspaces': {
        'demo:refs@example.com': {
          'projects': [],
          'avatars': [
            {'name': 'Hero', 'style': 'Film'}
          ],
          'avatarReferences': [
            {
              'avatarName': 'Hero',
              'assets': [
                {
                  'id': id,
                  'ownerName': 'Other',
                  'role': 'avatar',
                  'format': 'image',
                  'mimeType': 'image/jpeg',
                  'localPath': '/vault/$id.aes'
                }
              ]
            }
          ]
        }
      }
    });
    expect(store.avatarPackFor('Hero').assets, isEmpty);
    store.restoreLocalSnapshot({
      'schema': 2,
      'selectedAccount': 'refs@example.com',
      'workspaces': {
        'demo:refs@example.com': {
          'projects': [],
          'avatars': [
            {'name': 'Hero', 'style': 'Film'}
          ],
          'avatarReferences': [
            {
              'avatarName': 'Hero',
              'assets': [
                {
                  'id': id,
                  'ownerName': 'Hero',
                  'role': 'avatar',
                  'format': 'image',
                  'mimeType': 'image/jpeg',
                  'localPath': 'C:/outside/$id.jpg'
                }
              ]
            }
          ]
        }
      }
    });
    expect(store.avatarPackFor('Hero').assets, isEmpty);
    store.dispose();
  });

  test('restored actor metadata and references enter the store as one event',
      () {
    final store = HotIceStore();
    addTearDown(store.dispose);
    var notifications = 0;
    store.addListener(() => notifications++);
    final ref = AvatarReference(
      id: '1dbd4a72-bfde-4330-8a21-5f01d9be4e61',
      ownerName: 'Recovered',
      role: ReferenceRole.avatar,
      format: ReferenceFormat.image,
      mimeType: 'image/jpeg',
      localPath: '/vault/photo.aes',
      view: FaceView.left90,
      ownedTemporaryFile: true,
    );

    expect(
      store.addAvatarWithReferences(
        const StudioAvatar('Recovered', 'Cinematic',
            identityNotes: 'Blue coat'),
        [ref],
      ),
      isTrue,
    );
    expect(notifications, 1);
    expect(
      store.avatars
          .firstWhere((avatar) => avatar.name == 'Recovered')
          .identityNotes,
      'Blue coat',
    );
    expect(
        store.avatarPackFor('Recovered').assets.single.view, FaceView.left90);
    expect(
      store.addAvatarWithReferences(
        const StudioAvatar('Recovered', 'Cinematic'),
        [ref],
      ),
      isFalse,
    );
    expect(notifications, 1);
    expect(store.avatars.where((avatar) => avatar.name == 'Recovered'),
        hasLength(1));
  });

  test('restore rollback targets the captured account after an account switch',
      () {
    final store = HotIceStore()..signInDemo('restore@example.com');
    addTearDown(store.dispose);
    final capturedWorkspace = store.selectedWorkspaceId;
    final ref = AvatarReference(
      id: 'dc229677-8930-45ad-b589-87f6083d2dbb',
      ownerName: 'Recover Me',
      role: ReferenceRole.avatar,
      format: ReferenceFormat.image,
      mimeType: 'image/jpeg',
      localPath: '/vault/photo.aes',
      view: FaceView.front,
      ownedTemporaryFile: true,
    );
    expect(
      store.addAvatarWithReferences(
        const StudioAvatar('Recover Me', 'Cinematic'),
        [ref],
      ),
      isTrue,
    );
    store.switchAccount('creator@hotice.demo');
    expect(
        store.rollbackAvatarRestore(capturedWorkspace, 'Recover Me'), isTrue);
    final workspaces = store.exportLocalSnapshot()['workspaces'] as Map;
    final restoredWorkspace = workspaces[capturedWorkspace] as Map;
    expect(restoredWorkspace['avatars'], isEmpty);
    expect(restoredWorkspace['avatarReferences'], isEmpty);
    expect(store.avatars.single.name, 'Nova');
  });

  test('corrupt primary falls back to previous authenticated backup', () async {
    final dir = await Directory.systemTemp.createTemp('hotice-recovery-');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    final archive = HotIceLocalArchive(
      directory: dir,
      keyLoader: () async => List<int>.filled(32, 23),
    );
    final store = HotIceStore();
    store.addProject('Original preserved project');
    archive.enqueue(store.exportLocalSnapshot());
    await archive.flush();
    store.addProject('Newest not yet durable');
    archive.enqueue(store.exportLocalSnapshot());
    await archive.flush();
    await File('${dir.path}/hotice-projects-v1.aes')
        .writeAsString('corrupted-primary');
    final restored = await archive.restore();
    final copy = HotIceStore();
    copy.restoreLocalSnapshot(restored!);
    expect(copy.projects.any((p) => p.title == 'Original preserved project'),
        isTrue);
    expect(
        copy.projects.any((p) => p.title == 'Newest not yet durable'), isFalse);
    store.dispose();
    copy.dispose();
  });

  test('wrong device key fails closed without resetting local files', () async {
    final dir = await Directory.systemTemp.createTemp('hotice-key-test-');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    final archive = HotIceLocalArchive(
      directory: dir,
      keyLoader: () async => List<int>.filled(32, 4),
    );
    final store = HotIceStore();
    archive.enqueue(store.exportLocalSnapshot());
    await archive.flush();
    final file = File('${dir.path}/hotice-projects-v1.aes');
    final before = await file.readAsBytes();
    final wrongDevice = HotIceLocalArchive(
      directory: dir,
      keyLoader: () async => List<int>.filled(32, 5),
    );
    await expectLater(
        wrongDevice.restore(), throwsA(isA<HotIceLocalArchiveException>()));
    expect(await file.readAsBytes(), before);
    store.dispose();
  });
}
