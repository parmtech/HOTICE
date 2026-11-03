import 'package:flutter_test/flutter_test.dart';
import 'package:hotice/src/state.dart';
import 'package:hotice/src/video_models.dart';
import 'package:hotice/src/smart_references.dart';

void main() {
  test(
      'cloud export contains one selected project and excludes local media and identity notes',
      () {
    final store = HotIceStore()..signInDemo('creator@example.com');
    final selected = store.addProject('Cloud story');
    store.addProject('Keep device only');
    store.addAvatar(
      'Nova',
      'Cinematic',
      identityNotes: 'private identity detail',
    );
    store.addAvatarReference(
      'Nova',
      AvatarReference(
        id: '11111111-1111-4111-8111-111111111111',
        ownerName: 'Nova',
        role: ReferenceRole.avatar,
        format: ReferenceFormat.image,
        mimeType: 'image/jpeg',
        localPath: 'device-only-private-face-photo.aes',
        view: FaceView.front,
        ownedTemporaryFile: true,
      ),
    );
    store.queueDraft(
      GenerationDraft(
        projectId: selected,
        project: 'Cloud story',
        prompt: 'A moonlit city',
        model: 'Demo video',
        aspectRatio: '16:9',
        durationSeconds: 8,
        createdAt: DateTime.utc(2026),
        avatarName: 'Nova',
        requestedAttachments: const [VideoAttachment.image],
        referenceFiles: const [
          SceneReference(
            type: VideoAttachment.image,
            fileName: 'private-name.png',
            bytes: 42,
          ),
        ],
      ),
    );

    final cloud = store.exportCloudProject(selected);
    expect((cloud['project'] as Map)['id'], selected);
    expect(cloud['drafts'], hasLength(1));
    final draft = (cloud['drafts'] as List).single as Map;
    expect(draft['prompt'], 'A moonlit city');
    expect(draft['requestedAttachments'], ['image']);
    expect(draft['referenceFiles'], isEmpty);
    expect(cloud['avatars'], [
      {'name': 'Nova', 'style': 'Cinematic'},
    ]);
    expect(cloud.toString(), isNot(contains('private identity detail')));
    expect(cloud.toString(), isNot(contains('private-name.png')));
    expect(cloud.toString(), isNot(contains('avatarReferences')));
    expect(cloud.toString(), isNot(contains('device-only-private-face-photo')));
    expect(cloud.toString(), isNot(contains('Unspecified view')));
    store.dispose();
  });

  test(
      'cloud import and revision metadata preserve unrelated projects across local restore',
      () {
    final store = HotIceStore()..signInDemo('creator@example.com');
    final existing = store.addProject('Local only');
    final id = '12345678-1234-4234-8234-123456789abc';
    store.importCloudProject({
      'schema': 1,
      'project': {
        'id': id,
        'title': 'Restored film',
        'createdAt': '2026-11-01T00:00:00Z',
      },
      'avatars': [
        {'name': 'Nova', 'style': 'Cinematic'},
      ],
      'drafts': [
        {
          'prompt': 'Aurora over water',
          'model': 'Model',
          'createdAt': '2026-11-01T00:00:00Z',
        },
      ],
      'musicPlans': [],
    });
    store.markCloudRevision(id, 4);
    expect(
      store.projects.map((project) => project.id),
      containsAll([existing, id]),
    );
    expect(store.cloudRevision(id), 4);

    final snapshot = store.exportLocalSnapshot();
    final restored = HotIceStore()..restoreLocalSnapshot(snapshot);
    expect(
      restored.projects.map((project) => project.id),
      containsAll([existing, id]),
    );
    expect(restored.cloudRevision(id), 4);
    expect(restored.drafts.single.prompt, 'Aurora over water');
    expect(
      () => restored.importCloudProject({
        'schema': 1,
        'project': {'id': id, 'title': 'Restored film'},
      }),
      throwsStateError,
    );
    store.dispose();
    restored.dispose();
  });

  test(
    'cloud project export rejects sample projects without real UUID ownership',
    () {
      final store = HotIceStore();
      expect(() => store.exportCloudProject('demo-film'), throwsStateError);
      store.dispose();
    },
  );

  test('forgetting a cloud copy clears only its revision binding', () {
    final store = HotIceStore()..signInDemo('creator@example.com');
    final id = store.addProject('Keep this local project');
    store.markCloudRevision(id, 2);
    store.forgetCloudRevision(id);
    expect(store.cloudRevision(id), 0);
    expect(store.projects.single.id, id);
    store.dispose();
  });

  test(
      'uncertain mock submissions persist locally and never enter cloud copies',
      () {
    final store = HotIceStore()..signInDemo('creator@example.com');
    final id = store.addProject('Retry-safe film');
    const key = 'intent-1234567890abcdef';
    store.savePendingMockSubmission(
      PendingMockSubmission(
        idempotencyKey: key,
        accountUserId: 'creator-user-123',
        projectId: id,
        prompt: 'A private scene prompt',
        createdAt: DateTime.utc(2026, 11, 3),
      ),
    );

    expect(store.deleteProject(id), isFalse);
    final local = store.exportLocalSnapshot();
    final restored = HotIceStore()..restoreLocalSnapshot(local);
    final pending = restored.pendingMockSubmissionsFor(id).single;
    expect(pending.idempotencyKey, key);
    expect(pending.accountUserId, 'creator-user-123');
    expect(pending.prompt, 'A private scene prompt');

    final cloud = store.exportCloudProject(id);
    expect(cloud.toString(), isNot(contains('intent-1234567890abcdef')));
    expect(cloud.toString(), isNot(contains('creator-user-123')));
    expect(cloud.toString(), isNot(contains('pendingMockSubmissions')));

    expect(restored.removePendingMockSubmission(key), isTrue);
    expect(restored.deleteProject(id), isTrue);
    store.dispose();
    restored.dispose();
  });
}
