import 'package:flutter_test/flutter_test.dart';
import 'package:hotice/src/state.dart';
import 'package:hotice/src/video_models.dart';

void main() {
  test('local profile copy remaps identities and omits cloud retry state', () {
    final store = HotIceStore();
    addTearDown(store.dispose);
    store.signInDemo('legacy@example.com');
    final id = store.addProject('Local story');
    store.addAvatar('Nova', 'Cinematic', identityNotes: 'blue scarf');
    store.queueDraft(GenerationDraft(
      projectId: id,
      project: 'Local story',
      prompt: 'A quiet arrival',
      model: 'Preview model',
      aspectRatio: '16:9',
      durationSeconds: 8,
      createdAt: DateTime.utc(2026, 10, 30),
      avatarName: 'Nova',
      actors: const [SceneActor(avatarName: 'Nova', sceneName: 'Lead')],
      referenceFiles: const [
        SceneReference(
          type: VideoAttachment.image,
          fileName: 'face.png',
          bytes: 120,
        ),
      ],
      negativePrompt: 'blur',
      seed: 42,
      soundEnabled: true,
    ));
    store.saveMusicPlan(MusicVideoPlan(
      projectId: id,
      storyBrief: 'A full local story',
      visualStyle: 'Ink wash',
      avatarName: 'Nova',
      shots: const [StoryboardShot('Arrival', 'A train door opens', 5)],
      createdAt: DateTime.utc(2026, 10, 30),
    ));
    store.markCloudRevision(id, 4);
    store.signInAuthenticated('stable-user-001', 'owner@example.com');
    expect(store.addAvatar('Nova', 'Different style'), isTrue);

    final result = store.copyLocalProjectFromProfile('legacy@example.com', id);
    expect(isCloudProjectId(result.project.id), isTrue);
    expect(result.project.id, isNot(id));
    expect(result.draftCount, 1);
    expect(result.storyboardCount, 1);
    expect(result.avatarCount, 1);
    expect(store.drafts.single.projectId, result.project.id);
    expect(store.drafts.single.avatarName, 'Nova (copy 2)');
    expect(store.drafts.single.actors.single.avatarName, 'Nova (copy 2)');
    expect(store.drafts.single.referenceFiles.single.fileName, 'face.png');
    expect(store.drafts.single.seed, 42);
    expect(store.musicPlans.single.projectId, result.project.id);
    expect(store.musicPlans.single.avatarName, 'Nova (copy 2)');
    expect(store.cloudRevision(result.project.id), 0);
    expect(store.pendingMockSubmissions, isEmpty);
    expect(store.projects.single.id, result.project.id);

    store.switchAccount('legacy@example.com');
    expect(store.projects.single.id, id);
    expect(store.drafts.single.projectId, id);
    expect(store.cloudRevision(id), 4);
  });

  test(
      'local profile copy requires authenticated destination and eligible source',
      () {
    final store = HotIceStore();
    addTearDown(store.dispose);
    store.signInDemo('legacy@example.com');
    final userProjectId = store.addProject('Local story');
    expect(
      () => store.copyLocalProjectFromProfile(
          'legacy@example.com', userProjectId),
      throwsStateError,
    );
    store.signInAuthenticated('stable-user-001', 'owner@example.com');
    expect(
      () =>
          store.copyLocalProjectFromProfile('owner@example.com', userProjectId),
      throwsStateError,
    );
    expect(
      () =>
          store.copyLocalProjectFromProfile('legacy@example.com', 'demo-film'),
      throwsStateError,
    );
  });

  test(
      'local profile copy rolls back when encrypted archive size would overflow',
      () {
    final store = HotIceStore();
    addTearDown(store.dispose);
    store.signInDemo('legacy@example.com');
    final sourceId = store.addProject('Large local story');
    final largePrompt = List.filled(2000, 'x').join();
    for (var index = 0; index < 700; index++) {
      store.queueDraft(GenerationDraft(
        projectId: sourceId,
        project: 'Large local story',
        prompt: '$index $largePrompt',
        model: 'Preview model',
        aspectRatio: '16:9',
        durationSeconds: 8,
        createdAt: DateTime.utc(2026, 10, 30),
      ));
    }
    final sourceDraftsBeforeCopy = store.drafts.toList();
    store.signInAuthenticated('stable-user-001', 'owner@example.com');
    final projectsBeforeCopy = store.projects.toList();
    expect(
      () => store.copyLocalProjectFromProfile('legacy@example.com', sourceId),
      throwsStateError,
    );
    expect(store.projects, projectsBeforeCopy);
    expect(store.drafts, isEmpty);
    expect(store.musicPlans, isEmpty);
    expect(store.avatars, isEmpty);
    store.switchAccount('legacy@example.com');
    expect(store.projects.single.id, sourceId);
    expect(store.drafts, sourceDraftsBeforeCopy);
  });
}
