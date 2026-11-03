import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

import 'local_archive_contract.dart';
import 'video_models.dart';
import 'smart_references.dart';
import 'face_reference_vault.dart';

/// Pricing is in whole US cents to avoid floating point billing errors.
const int creditsPerUsd = 100;
const int minimumPurchaseUsd = 10;

/// This validates only the local UI demo. It is not authentication.
bool isValidDemoEmail(String value) {
  final email = value.trim();
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
}

String _demoWorkspaceId(String email) => 'demo:${email.trim().toLowerCase()}';

bool _isValidStableAccountId(String value) =>
    value.isNotEmpty &&
    value.trim() == value &&
    value.length <= 128 &&
    !RegExp(r'[\x00-\x1f\x7f]').hasMatch(value);

String _accountWorkspaceId(String accountId) =>
    'account:${base64Url.encode(utf8.encode(accountId)).replaceAll('=', '')}';

String? _accountIdFromWorkspaceId(String workspaceId) {
  if (!workspaceId.startsWith('account:')) return null;
  final encoded = workspaceId.substring('account:'.length);
  try {
    final accountId =
        utf8.decode(base64Url.decode(base64Url.normalize(encoded)));
    return _isValidStableAccountId(accountId) &&
            _accountWorkspaceId(accountId) == workspaceId
        ? accountId
        : null;
  } on FormatException {
    return null;
  }
}

/// New device projects use UUIDv4 IDs suitable for a future opt-in cloud API.
/// Older seeded demo project IDs remain legacy examples; never upload those
/// without an explicit migration to UUIDs and ownership verification.
String createLocalProjectId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex =
      bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20, 32)}';
}

Map<String, Object?> _referenceJson(AvatarReference asset) => {
      'id': asset.id,
      'ownerName': asset.ownerName,
      'role': asset.role.name,
      'format': asset.format.name,
      'mimeType': asset.mimeType,
      'localPath': asset.localPath,
      'view': asset.view?.name,
      'isScanVerified': asset.isScanVerified,
      'ownedTemporaryFile': asset.ownedTemporaryFile,
    };

bool isCloudProjectId(String value) => RegExp(
      r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
      caseSensitive: false,
    ).hasMatch(value);

class HotProject {
  final String id;
  final String title;
  final DateTime createdAt;
  const HotProject(this.id, this.title, this.createdAt);
}

class LocalProjectTransferCandidate {
  const LocalProjectTransferCandidate({
    required this.sourceProfileEmail,
    required this.project,
  });

  final String sourceProfileEmail;
  final HotProject project;
}

class LocalProjectTransferResult {
  const LocalProjectTransferResult({
    required this.project,
    required this.draftCount,
    required this.storyboardCount,
    required this.avatarCount,
  });

  final HotProject project;
  final int draftCount;
  final int storyboardCount;
  final int avatarCount;
}

class PendingMockSubmission {
  const PendingMockSubmission({
    required this.idempotencyKey,
    required this.accountUserId,
    required this.projectId,
    required this.prompt,
    required this.createdAt,
  });

  final String idempotencyKey;
  final String accountUserId;
  final String projectId;
  final String prompt;
  final DateTime createdAt;
}

class StudioAvatar {
  final String name;
  final String style;
  final String identityNotes;
  const StudioAvatar(this.name, this.style, {this.identityNotes = ''});
}

class StoryboardShot {
  final String title;
  final String description;
  final int estimatedSeconds;
  const StoryboardShot(this.title, this.description, this.estimatedSeconds);
}

/// A text-only offline planning draft. There is no audio or AI analysis.
class MusicVideoPlan {
  final String projectId;
  final String storyBrief;
  final String visualStyle;
  final String avatarName;
  final List<StoryboardShot> shots;
  final DateTime createdAt;
  const MusicVideoPlan({
    required this.projectId,
    required this.storyBrief,
    required this.visualStyle,
    required this.avatarName,
    required this.shots,
    required this.createdAt,
  });
}

class SceneActor {
  final String avatarName;
  final String sceneName;
  const SceneActor({required this.avatarName, required this.sceneName});
}

class SceneReference {
  final VideoAttachment type;
  final String fileName;
  final int bytes;
  const SceneReference({
    required this.type,
    required this.fileName,
    required this.bytes,
  });
}

class GenerationDraft {
  final String project;
  final String prompt;
  final String model;
  final String aspectRatio;
  final int durationSeconds;
  final DateTime createdAt;
  final String projectId;
  final String avatarName;
  final String modelId;
  final List<VideoAttachment> requestedAttachments;
  final List<SceneActor> actors;
  final List<SceneReference> referenceFiles;
  final String negativePrompt;
  final int? seed;
  final bool soundEnabled;
  final List<String> selectedReferenceIds;

  const GenerationDraft({
    required this.project,
    required this.prompt,
    required this.model,
    required this.aspectRatio,
    required this.durationSeconds,
    required this.createdAt,
    this.projectId = '',
    this.avatarName = 'None',
    this.modelId = '',
    this.requestedAttachments = const <VideoAttachment>[],
    this.actors = const <SceneActor>[],
    this.referenceFiles = const <SceneReference>[],
    this.negativePrompt = '',
    this.seed,
    this.soundEnabled = false,
    this.selectedReferenceIds = const <String>[],
  });
}

enum StudioAccent {
  electric('Electric', Color(0xFF8F72FF)),
  ocean('Ocean', Color(0xFF2CB9C7)),
  ember('Ember', Color(0xFFF47A6C)),
  glacier('Glacier', Color(0xFF589CF7)),
  moss('Moss', Color(0xFF65B986));

  const StudioAccent(this.label, this.color);
  final String label;
  final Color color;
}

enum StudioFont {
  modern('Modern', null),
  editorial('Editorial', 'serif'),
  technical('Technical', 'monospace');

  const StudioFont(this.label, this.family);
  final String label;
  final String? family;
}

/// Ephemeral demo data for one profile. Never treat this as cloud security.
class _DemoWorkspace {
  _DemoWorkspace({bool seed = false}) {
    if (seed) {
      projects.addAll([
        HotProject(
          'demo-film',
          'Untitled cinematic film',
          DateTime(2026, 10, 25),
        ),
        HotProject('demo-social', 'Social teaser', DateTime(2026, 10, 24)),
      ]);
      avatars.add(const StudioAvatar('Nova', 'Cinematic'));
    }
  }

  final List<HotProject> projects = [];
  final List<StudioAvatar> avatars = [];
  final Map<String, List<AvatarReference>> avatarReferences = {};
  final Map<String, List<AvatarReference>> sceneReferences = {};
  final List<GenerationDraft> drafts = [];
  final List<MusicVideoPlan> musicPlans = [];
  final List<PendingMockSubmission> pendingMockSubmissions = [];
  final Map<String, int> cloudRevisions = {};
  int demoCredits = 1000;
}

class HotIceStore extends ChangeNotifier {
  bool signedIn = false;
  ThemeMode themeMode = ThemeMode.dark;
  StudioAccent accent = StudioAccent.electric;
  StudioFont font = StudioFont.modern;
  String selectedAccount = 'creator@hotice.demo';

  /// Local selection may outlive a session; it is never itself authentication.
  String selectedWorkspaceId = 'demo:creator@hotice.demo';
  String? authenticatedUserId;
  final List<String> accounts = ['creator@hotice.demo'];

  final Map<String, _DemoWorkspace> _workspaces = {
    'demo:creator@hotice.demo': _DemoWorkspace(seed: true),
  };

  _DemoWorkspace get _workspace =>
      _workspaces.putIfAbsent(selectedWorkspaceId, () => _DemoWorkspace());

  int get demoCredits => _workspace.demoCredits;
  List<HotProject> get projects => _workspace.projects;
  List<StudioAvatar> get avatars => _workspace.avatars;

  /// Metadata for explicitly imported, session-only files. No biometric scan.
  AvatarAssetPack avatarPackFor(String avatarName) => AvatarAssetPack(
        avatarName: avatarName,
        version: 1,
        assets: _workspace.avatarReferences[avatarName] ?? const [],
        consented: avatars.any((a) => a.name == avatarName),
      );

  List<AvatarReference> sceneReferencesFor(String projectId) =>
      List<AvatarReference>.unmodifiable(
        _workspace.sceneReferences[projectId] ?? const [],
      );

  bool addAvatarReference(String avatarName, AvatarReference asset) {
    if (!avatars.any((a) => a.name == avatarName) ||
        asset.ownerName != avatarName ||
        asset.role != ReferenceRole.avatar ||
        asset.format != ReferenceFormat.image ||
        asset.localPath.isEmpty ||
        asset.id.isEmpty ||
        !const ['image/jpeg', 'image/png', 'image/webp']
            .contains(asset.mimeType)) return false;
    final items = _workspace.avatarReferences.putIfAbsent(avatarName, () => []);
    if (items.length >= 16 || items.any((a) => a.id == asset.id)) return false;
    items.add(asset);
    notifyListeners();
    return true;
  }

  /// Adds a restored actor and all of its references as one visible store
  /// change. Callers must finish validating/encrypting media before this point.
  bool addAvatarWithReferences(
    StudioAvatar avatar,
    Iterable<AvatarReference> references,
  ) {
    final items = references.toList(growable: false);
    if (avatar.name.trim().isEmpty ||
        avatars.any((a) => a.name == avatar.name) ||
        items.isEmpty ||
        items.length > 16 ||
        items.any((asset) =>
            asset.ownerName != avatar.name ||
            asset.role != ReferenceRole.avatar ||
            asset.format != ReferenceFormat.image ||
            !asset.ownedTemporaryFile ||
            asset.localPath.isEmpty ||
            !const ['image/jpeg', 'image/png', 'image/webp']
                .contains(asset.mimeType)) ||
        items.map((asset) => asset.id).toSet().length != items.length) {
      return false;
    }
    avatars.add(avatar);
    _workspace.avatarReferences[avatar.name] = items;
    notifyListeners();
    return true;
  }

  void _deleteOwnedPhotos(Iterable<AvatarReference> photos) {
    final owned = photos.where((photo) => photo.ownedTemporaryFile).toList();
    if (owned.isEmpty || (!Platform.isAndroid && !Platform.isIOS)) return;
    unawaited(FaceReferenceVault.openOnDevice().then((vault) async {
      for (final photo in owned) {
        try {
          await vault.deletePhoto(photo.localPath);
        } on FaceReferenceVaultException {
          // Retain data when its path cannot be validated by the vault.
        }
      }
    }).catchError((Object _) {}));
  }

  bool removeAvatarReference(String avatarName, String assetId) {
    final assets = _workspace.avatarReferences[avatarName];
    if (assets == null) return false;
    final previous = assets.length;
    _deleteOwnedPhotos(assets.where((a) => a.id == assetId));
    assets.removeWhere((a) => a.id == assetId);
    if (assets.length == previous) return false;
    notifyListeners();
    return true;
  }

  bool addSceneReference(String projectId, AvatarReference asset) {
    if (!projects.any((p) => p.id == projectId) ||
        asset.ownerName != projectId ||
        asset.role == ReferenceRole.avatar ||
        asset.format != ReferenceFormat.image ||
        asset.localPath.isEmpty ||
        asset.id.isEmpty ||
        !const ['image/jpeg', 'image/png', 'image/webp']
            .contains(asset.mimeType)) return false;
    final items = _workspace.sceneReferences.putIfAbsent(projectId, () => []);
    if (items.length >= 12 || items.any((a) => a.id == asset.id)) return false;
    items.add(asset);
    notifyListeners();
    return true;
  }

  bool removeSceneReference(String projectId, String assetId) {
    final assets = _workspace.sceneReferences[projectId];
    if (assets == null) return false;
    final count = assets.length;
    assets.removeWhere((a) => a.id == assetId);
    if (assets.length == count) return false;
    notifyListeners();
    return true;
  }

  List<GenerationDraft> get drafts => _workspace.drafts;
  List<MusicVideoPlan> get musicPlans => _workspace.musicPlans;
  List<PendingMockSubmission> get pendingMockSubmissions =>
      List.unmodifiable(_workspace.pendingMockSubmissions);

  /// User-owned projects in local demo profiles that can be copied into the
  /// active authenticated account. Seeded examples are deliberately excluded.
  List<LocalProjectTransferCandidate> get localProjectTransferCandidates {
    if (authenticatedUserId == null ||
        _accountWorkspaceId(authenticatedUserId!) != selectedWorkspaceId) {
      return const [];
    }
    return List.unmodifiable([
      for (final email in accounts.toSet())
        for (final project in (_workspaces[_demoWorkspaceId(email)]?.projects ??
            const <HotProject>[]))
          if (isCloudProjectId(project.id))
            LocalProjectTransferCandidate(
              sourceProfileEmail: email,
              project: project,
            ),
    ]);
  }

  List<PendingMockSubmission> pendingMockSubmissionsFor(String projectId) =>
      List.unmodifiable(_workspace.pendingMockSubmissions.where(
        (submission) => submission.projectId == projectId,
      ));

  void savePendingMockSubmission(PendingMockSubmission submission) {
    if (!isCloudProjectId(submission.projectId) ||
        !projects.any((item) => item.id == submission.projectId) ||
        submission.accountUserId.trim().isEmpty ||
        submission.accountUserId.length > 128 ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(submission.accountUserId) ||
        !RegExp(r'^[A-Za-z0-9._~:-]{16,128}$')
            .hasMatch(submission.idempotencyKey) ||
        submission.prompt.trim().isEmpty ||
        submission.prompt.trim().length > 2000) {
      throw StateError('The pending generation request is invalid.');
    }
    final index = _workspace.pendingMockSubmissions.indexWhere(
      (item) => item.idempotencyKey == submission.idempotencyKey,
    );
    if (index >= 0) {
      final previous = _workspace.pendingMockSubmissions[index];
      if (previous.projectId != submission.projectId ||
          previous.accountUserId != submission.accountUserId ||
          previous.prompt != submission.prompt) {
        throw StateError('A generation request identifier cannot be reused.');
      }
      return;
    }
    _workspace.pendingMockSubmissions.add(submission);
    notifyListeners();
  }

  bool removePendingMockSubmission(String idempotencyKey) {
    final before = _workspace.pendingMockSubmissions.length;
    _workspace.pendingMockSubmissions
        .removeWhere((item) => item.idempotencyKey == idempotencyKey);
    final removed = before != _workspace.pendingMockSubmissions.length;
    if (removed) notifyListeners();
    return removed;
  }

  /// Build the explicit, selected-project cloud payload. Device media bytes,
  /// local source filenames, reference metadata and private identity notes are
  /// deliberately excluded. No other local workspace is included.
  Map<String, dynamic> exportCloudProject(String projectId) {
    if (!isCloudProjectId(projectId)) {
      throw StateError(
        'This example project cannot be uploaded to cloud storage.',
      );
    }
    final snapshot = exportLocalSnapshot();
    final workspaces = snapshot['workspaces'] as Map<String, dynamic>;
    final source = workspaces[selectedWorkspaceId] as Map<String, dynamic>?;
    if (source == null)
      throw StateError('The signed-in account has no local workspace.');
    final projects = (source['projects'] as List).cast<Map<String, dynamic>>();
    final matches = projects.where((row) => row['id'] == projectId);
    final project = matches.isEmpty ? null : matches.first;
    if (project == null)
      throw StateError('Select a project in the signed-in workspace.');
    List<Map<String, dynamic>> rows(String key) =>
        (source[key] as List).cast<Map<String, dynamic>>();
    final drafts = rows('drafts')
        .where((row) => row['projectId'] == projectId)
        .map((row) => <String, dynamic>{...row, 'referenceFiles': <Object>[]})
        .toList();
    final names = <String>{
      for (final draft in drafts)
        if (draft['avatarName'] is String && draft['avatarName'] != 'None')
          draft['avatarName'] as String,
      for (final draft in drafts)
        for (final actor in (draft['actors'] as List? ?? const []))
          if (actor is Map && actor['avatarName'] is String)
            actor['avatarName'] as String,
      for (final plan in rows(
        'musicPlans',
      ).where((row) => row['projectId'] == projectId))
        if (plan['avatarName'] is String && plan['avatarName'] != 'None')
          plan['avatarName'] as String,
    };
    final avatars = rows('avatars')
        .where((row) => names.contains(row['name']))
        .map(
          (row) => <String, dynamic>{
            'name': row['name'],
            'style': row['style'],
          },
        )
        .toList();
    return {
      'schema': 1,
      'project': Map<String, dynamic>.from(project),
      'avatars': avatars,
      'drafts': drafts,
      'musicPlans': rows('musicPlans')
          .where((row) => row['projectId'] == projectId)
          .toList(),
    };
  }

  int cloudRevision(String projectId) =>
      _workspace.cloudRevisions[projectId] ?? 0;

  void markCloudRevision(String projectId, int revision) {
    if (!isCloudProjectId(projectId) ||
        revision < 1 ||
        !projects.any((project) => project.id == projectId)) {
      throw StateError('Cloud sync state does not match a local project.');
    }
    _workspace.cloudRevisions[projectId] = revision;
    notifyListeners();
  }

  void forgetCloudRevision(String projectId) {
    if (_workspace.cloudRevisions.remove(projectId) != null) {
      notifyListeners();
    }
  }

  /// Explicitly import or replace one cloud project after the UI confirms the
  /// operation. Other projects and local workspaces are retained.
  void importCloudProject(
    Map<String, dynamic> document, {
    bool replace = false,
  }) {
    if (document['schema'] != 1 ||
        document['project'] is! Map<String, dynamic>) {
      throw const FormatException('Unsupported cloud project document.');
    }
    final project = document['project'] as Map<String, dynamic>;
    final id = project['id'];
    final title = project['title'];
    if (id is! String ||
        !isCloudProjectId(id) ||
        title is! String ||
        title.trim().isEmpty ||
        title.length > 120) {
      throw const FormatException('Cloud project details are invalid.');
    }
    final existing = projects.indexWhere((item) => item.id == id);
    if (existing >= 0 && !replace)
      throw StateError('This project already exists on this device.');
    final workspace = _workspace;
    if (existing >= 0) {
      workspace.projects.removeAt(existing);
      workspace.drafts.removeWhere((draft) => draft.projectId == id);
      workspace.musicPlans.removeWhere((plan) => plan.projectId == id);
    }
    workspace.projects.insert(
      0,
      HotProject(
        id,
        title.trim(),
        DateTime.tryParse('${project['createdAt'] ?? ''}') ?? DateTime.now(),
      ),
    );
    final avatarRows = document['avatars'];
    if (avatarRows is List) {
      for (final row in avatarRows.take(100)) {
        if (row is Map &&
            row['name'] is String &&
            row['style'] is String &&
            !workspace.avatars.any((item) =>
                item.name.toLowerCase() ==
                (row['name'] as String).toLowerCase())) {
          workspace.avatars.add(
            StudioAvatar(row['name'] as String, row['style'] as String),
          );
        }
      }
    }
    final drafts = document['drafts'];
    if (drafts is List) {
      for (final row in drafts.take(1000)) {
        if (row is! Map || row['prompt'] is! String || row['model'] is! String)
          continue;
        final requested = row['requestedAttachments'] is List
            ? row['requestedAttachments'] as List
            : const <Object>[];
        final actors =
            row['actors'] is List ? row['actors'] as List : const <Object>[];
        workspace.drafts.add(
          GenerationDraft(
            projectId: id,
            project: title.trim(),
            prompt: row['prompt'] as String,
            model: row['model'] as String,
            modelId: row['modelId'] is String ? row['modelId'] as String : '',
            aspectRatio: row['aspectRatio'] is String
                ? row['aspectRatio'] as String
                : '16:9',
            durationSeconds: row['durationSeconds'] is int
                ? (row['durationSeconds'] as int).clamp(1, 600)
                : 8,
            createdAt: DateTime.tryParse('${row['createdAt'] ?? ''}') ??
                DateTime.now(),
            avatarName: row['avatarName'] is String
                ? row['avatarName'] as String
                : 'None',
            requestedAttachments: VideoAttachment.values
                .where((type) => requested.contains(type.name))
                .toList(),
            actors: [
              for (final actor in actors)
                if (actor is Map &&
                    actor['avatarName'] is String &&
                    actor['sceneName'] is String &&
                    workspace.avatars
                        .any((avatar) => avatar.name == actor['avatarName']))
                  SceneActor(
                    avatarName: actor['avatarName'] as String,
                    sceneName: actor['sceneName'] as String,
                  ),
            ],
            negativePrompt: row['negativePrompt'] is String
                ? row['negativePrompt'] as String
                : '',
            seed: row['seed'] is int ? row['seed'] as int : null,
            soundEnabled: row['soundEnabled'] == true,
          ),
        );
      }
    }
    final plans = document['musicPlans'];
    if (plans is List) {
      for (final row in plans.take(500)) {
        if (row is! Map || row['storyBrief'] is! String) continue;
        final shots = <StoryboardShot>[];
        final sourceShots = row['shots'];
        if (sourceShots is List)
          for (final shot in sourceShots.take(250)) {
            if (shot is Map &&
                shot['description'] is String &&
                shot['estimatedSeconds'] is int) {
              shots.add(
                StoryboardShot(
                  shot['title'] is String ? shot['title'] as String : 'Shot',
                  shot['description'] as String,
                  (shot['estimatedSeconds'] as int).clamp(1, 600),
                ),
              );
            }
          }
        if (shots.isNotEmpty)
          workspace.musicPlans.add(
            MusicVideoPlan(
              projectId: id,
              storyBrief: row['storyBrief'] as String,
              visualStyle: row['visualStyle'] is String
                  ? row['visualStyle'] as String
                  : 'Cinematic realism',
              avatarName: row['avatarName'] is String
                  ? row['avatarName'] as String
                  : 'None',
              shots: shots,
              createdAt: DateTime.tryParse('${row['createdAt'] ?? ''}') ??
                  DateTime.now(),
            ),
          );
      }
    }
    notifyListeners();
  }

  void signInDemo(String email) {
    final normalized = email.trim().toLowerCase();
    if (!isValidDemoEmail(normalized)) return;
    if (!accounts.contains(normalized)) accounts.add(normalized);
    selectedWorkspaceId = _demoWorkspaceId(normalized);
    _workspaces.putIfAbsent(selectedWorkspaceId, () => _DemoWorkspace());
    selectedAccount = normalized;
    authenticatedUserId = null;
    signedIn = true;
    notifyListeners();
  }

  /// Select local project data by immutable server subject, never by email.
  /// The email remains presentation metadata and can change independently.
  void signInAuthenticated(String accountId, String email) {
    final normalized = email.trim().toLowerCase();
    if (!_isValidStableAccountId(accountId) || !isValidDemoEmail(normalized)) {
      throw ArgumentError('The authenticated account identity is invalid.');
    }
    authenticatedUserId = accountId;
    selectedAccount = normalized;
    selectedWorkspaceId = _accountWorkspaceId(accountId);
    _workspaces.putIfAbsent(selectedWorkspaceId, () => _DemoWorkspace());
    signedIn = true;
    notifyListeners();
  }

  void signOut() {
    signedIn = false;
    authenticatedUserId = null;
    notifyListeners();
  }

  void addAccount(String email) {
    final normalized = email.trim().toLowerCase();
    if (!isValidDemoEmail(normalized)) return;
    if (!accounts.contains(normalized)) accounts.add(normalized);
    selectedWorkspaceId = _demoWorkspaceId(normalized);
    _workspaces.putIfAbsent(selectedWorkspaceId, () => _DemoWorkspace());
    selectedAccount = normalized;
    authenticatedUserId = null;
    notifyListeners();
  }

  void switchAccount(String email) {
    final normalized = email.trim().toLowerCase();
    if (!accounts.contains(normalized)) return;
    selectedAccount = normalized;
    selectedWorkspaceId = _demoWorkspaceId(normalized);
    authenticatedUserId = null;
    notifyListeners();
  }

  /// Make a local-only copy from a demo/legacy profile into the authenticated
  /// account workspace. The source is never modified. Cloud revisions and
  /// pending requests are intentionally not copied; those remain bound to the
  /// source profile and any cloud save requires a separate explicit action.
  LocalProjectTransferResult copyLocalProjectFromProfile(
    String sourceProfileEmail,
    String sourceProjectId,
  ) {
    final accountId = authenticatedUserId;
    if (accountId == null ||
        _accountWorkspaceId(accountId) != selectedWorkspaceId) {
      throw StateError(
          'Sign in to the account that should receive this local copy.');
    }
    final email = sourceProfileEmail.trim().toLowerCase();
    if (!isValidDemoEmail(email) || !accounts.contains(email)) {
      throw StateError('Choose a saved local profile.');
    }
    final sourceWorkspaceId = _demoWorkspaceId(email);
    if (sourceWorkspaceId == selectedWorkspaceId) {
      throw StateError('Choose a different local profile.');
    }
    final source = _workspaces[sourceWorkspaceId];
    if (source == null) throw StateError('That local profile is unavailable.');
    final sourceProject = source.projects.where((p) => p.id == sourceProjectId);
    if (sourceProject.isEmpty || !isCloudProjectId(sourceProjectId)) {
      throw StateError('That project is not an eligible user-created project.');
    }

    final original = sourceProject.first;
    final sourceDrafts = source.drafts
        .where((draft) => draft.projectId == sourceProjectId)
        .toList(growable: false);
    final sourcePlans = source.musicPlans
        .where((plan) => plan.projectId == sourceProjectId)
        .toList(growable: false);
    final avatarNames = <String>{
      for (final draft in sourceDrafts)
        if (draft.avatarName != 'None') draft.avatarName,
      for (final draft in sourceDrafts)
        for (final actor in draft.actors) actor.avatarName,
      for (final plan in sourcePlans)
        if (plan.avatarName != 'None') plan.avatarName,
    };
    final referencedAvatars = source.avatars
        .where((avatar) => avatarNames.contains(avatar.name))
        .toList(growable: false);

    final target = _workspace;
    if (target.projects.length >= 500 ||
        target.drafts.length + sourceDrafts.length > 1000 ||
        target.musicPlans.length + sourcePlans.length > 500) {
      throw StateError('This account workspace is at its local project limit.');
    }

    final copiedAvatarNames = <String, String>{};
    final addedAvatars = <StudioAvatar>[];
    final usedNames = target.avatars.map((a) => a.name.toLowerCase()).toSet();
    for (final avatar in referencedAvatars) {
      final identical = target.avatars.where((existing) =>
          existing.name.toLowerCase() == avatar.name.toLowerCase() &&
          existing.style == avatar.style &&
          existing.identityNotes == avatar.identityNotes);
      if (identical.isNotEmpty) {
        copiedAvatarNames[avatar.name] = identical.first.name;
        continue;
      }
      var newName = avatar.name;
      var suffix = 2;
      while (usedNames.contains(newName.toLowerCase())) {
        newName = '${avatar.name} (copy $suffix)';
        suffix++;
      }
      usedNames.add(newName.toLowerCase());
      copiedAvatarNames[avatar.name] = newName;
      addedAvatars.add(StudioAvatar(
        newName,
        avatar.style,
        identityNotes: avatar.identityNotes,
      ));
    }
    String avatarName(String value) => copiedAvatarNames[value] ?? value;

    var copiedId = createLocalProjectId();
    while (target.projects.any((project) => project.id == copiedId)) {
      copiedId = createLocalProjectId();
    }
    final copiedProject =
        HotProject(copiedId, original.title, original.createdAt);
    final copiedDrafts = <GenerationDraft>[
      for (final draft in sourceDrafts)
        GenerationDraft(
          project: original.title,
          prompt: draft.prompt,
          model: draft.model,
          aspectRatio: draft.aspectRatio,
          durationSeconds: draft.durationSeconds,
          createdAt: draft.createdAt,
          projectId: copiedId,
          avatarName: avatarName(draft.avatarName),
          modelId: draft.modelId,
          requestedAttachments: List.unmodifiable(draft.requestedAttachments),
          actors: List.unmodifiable([
            for (final actor in draft.actors)
              SceneActor(
                avatarName: avatarName(actor.avatarName),
                sceneName: actor.sceneName,
              ),
          ]),
          referenceFiles: List.unmodifiable([
            for (final reference in draft.referenceFiles)
              SceneReference(
                type: reference.type,
                fileName: reference.fileName,
                bytes: reference.bytes,
              ),
          ]),
          negativePrompt: draft.negativePrompt,
          seed: draft.seed,
          soundEnabled: draft.soundEnabled,
          selectedReferenceIds:
              List<String>.unmodifiable(draft.selectedReferenceIds),
        ),
    ];
    final copiedPlans = <MusicVideoPlan>[
      for (final plan in sourcePlans)
        MusicVideoPlan(
          projectId: copiedId,
          storyBrief: plan.storyBrief,
          visualStyle: plan.visualStyle,
          avatarName: avatarName(plan.avatarName),
          shots: List.unmodifiable([
            for (final shot in plan.shots)
              StoryboardShot(
                shot.title,
                shot.description,
                shot.estimatedSeconds,
              ),
          ]),
          createdAt: plan.createdAt,
        ),
    ];
    if (target.avatars.length + addedAvatars.length > 100) {
      throw StateError(
          'This account workspace has reached its Actor profile limit.');
    }

    target.projects.add(copiedProject);
    target.drafts.addAll(copiedDrafts);
    target.musicPlans.addAll(copiedPlans);
    target.avatars.addAll(addedAvatars);
    try {
      final snapshotBytes =
          utf8.encode(jsonEncode(exportLocalSnapshot())).length;
      if (snapshotBytes > hotIceLocalArchiveMaxJsonBytes) {
        throw StateError(
          'This copy would exceed the 2 MiB encrypted local archive limit. '
          'The original project has not changed.',
        );
      }
    } catch (_) {
      target.projects.remove(copiedProject);
      target.drafts.removeWhere(copiedDrafts.contains);
      target.musicPlans.removeWhere(copiedPlans.contains);
      target.avatars.removeWhere(addedAvatars.contains);
      rethrow;
    }
    notifyListeners();
    return LocalProjectTransferResult(
      project: copiedProject,
      draftCount: copiedDrafts.length,
      storyboardCount: copiedPlans.length,
      avatarCount: addedAvatars.length,
    );
  }

  String addProject(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty || trimmed.length > 60) {
      throw ArgumentError.value(
        title,
        'title',
        'Project title must be 1–60 characters.',
      );
    }
    final id = createLocalProjectId();
    projects.insert(0, HotProject(id, trimmed, DateTime.now()));
    notifyListeners();
    return id;
  }

  /// Rename only a project owned by the currently selected demo workspace.
  /// Keep its stable ID and refresh labels captured in existing scene drafts.
  bool renameProject(String projectId, String newTitle) {
    final title = newTitle.trim();
    final index = projects.indexWhere((p) => p.id == projectId);
    if (index < 0 || title.isEmpty || title.length > 60) return false;
    final current = projects[index];
    if (current.title == title) return true;
    projects[index] = HotProject(current.id, title, current.createdAt);
    for (var i = 0; i < drafts.length; i++) {
      final old = drafts[i];
      if (old.projectId != projectId) continue;
      drafts[i] = GenerationDraft(
        project: title,
        prompt: old.prompt,
        model: old.model,
        aspectRatio: old.aspectRatio,
        durationSeconds: old.durationSeconds,
        createdAt: old.createdAt,
        projectId: old.projectId,
        avatarName: old.avatarName,
        modelId: old.modelId,
        requestedAttachments: old.requestedAttachments,
        actors: old.actors,
        referenceFiles: old.referenceFiles,
        negativePrompt: old.negativePrompt,
        seed: old.seed,
        soundEnabled: old.soundEnabled,
      );
    }
    notifyListeners();
    return true;
  }

  /// Permanently remove the in-memory project and all associated draft data
  /// in this one demo profile. A UI confirmation is required before calling.
  /// This is not a cloud-delete or biometric Actor vault operation.
  bool deleteProject(String projectId) {
    final index = projects.indexWhere((p) => p.id == projectId);
    if (index < 0) return false;
    if (_workspace.pendingMockSubmissions.any(
      (submission) => submission.projectId == projectId,
    )) {
      return false;
    }
    projects.removeAt(index);
    _workspace.cloudRevisions.remove(projectId);
    drafts.removeWhere((draft) => draft.projectId == projectId);
    musicPlans.removeWhere((plan) => plan.projectId == projectId);
    _deleteOwnedPhotos(_workspace.sceneReferences.remove(projectId) ??
        const <AvatarReference>[]);
    notifyListeners();
    return true;
  }

  /// Avoid duplicate values in the avatar dropdown.
  bool addAvatar(String name, String style, {String identityNotes = ''}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty ||
        trimmed.toLowerCase() == 'none' ||
        avatars.any((a) => a.name.toLowerCase() == trimmed.toLowerCase())) {
      return false;
    }
    avatars.insert(
      0,
      StudioAvatar(trimmed, style, identityNotes: identityNotes.trim()),
    );
    notifyListeners();
    return true;
  }

  bool editAvatar(
    String originalName,
    String newName,
    String style, {
    String identityNotes = '',
  }) {
    final index = avatars.indexWhere((a) => a.name == originalName);
    final name = newName.trim();
    if (index < 0 ||
        name.isEmpty ||
        name.toLowerCase() == 'none' ||
        avatars.any(
          (a) =>
              a.name != originalName &&
              a.name.toLowerCase() == name.toLowerCase(),
        )) {
      return false;
    }
    avatars[index] = StudioAvatar(
      name,
      style,
      identityNotes: identityNotes.trim(),
    );
    if (name != originalName) {
      final previous = _workspace.avatarReferences.remove(originalName);
      if (previous != null) {
        _workspace.avatarReferences[name] = [
          for (final asset in previous) asset.withOwner(name)
        ];
      }
    }
    notifyListeners();
    return true;
  }

  bool removeAvatar(String name) {
    final oldLength = avatars.length;
    avatars.removeWhere((a) => a.name == name);
    if (avatars.length == oldLength) return false;
    _deleteOwnedPhotos(
        _workspace.avatarReferences.remove(name) ?? const <AvatarReference>[]);
    // Existing scene drafts remain historical snapshots of their creation.
    notifyListeners();
    return true;
  }

  void queueDraft(GenerationDraft draft) {
    // Prevent a stale project selection from being saved to another profile.
    if (draft.projectId.isNotEmpty &&
        !projects.any((p) => p.id == draft.projectId)) {
      throw StateError('The selected project is not in this demo workspace.');
    }
    if (draft.actors
                .map((a) => a.sceneName.trim().toLowerCase())
                .toSet()
                .length !=
            draft.actors.length ||
        draft.actors.any(
          (a) =>
              a.sceneName.trim().isEmpty ||
              !avatars.any((av) => av.name == a.avatarName),
        )) {
      throw StateError(
        'Scene actor names must be unique and refer to an existing actor.',
      );
    }
    if (draft.avatarName != 'None' &&
        !avatars.any((avatar) => avatar.name == draft.avatarName)) {
      throw StateError('Selected Actor is not in this demo workspace.');
    }
    if (draft.referenceFiles.any(
      (file) => file.fileName.trim().isEmpty || file.bytes < 0,
    )) {
      throw StateError('Invalid reference file metadata.');
    }
    if (draft.modelId.isNotEmpty) {
      final matches = demoVideoModels.where((m) => m.id == draft.modelId);
      if (matches.isEmpty) {
        throw StateError('Unknown model preview.');
      }
      final model = matches.single;
      final attachments = [
        ...draft.requestedAttachments,
        ...draft.referenceFiles.map((f) => f.type),
      ];
      if (!model.accepts(
            seconds: draft.durationSeconds,
            ratio: draft.aspectRatio,
            inputs: attachments,
          ) ||
          draft.actors.length > model.maxActors ||
          (draft.seed != null && !model.supportsSeed) ||
          (draft.negativePrompt.trim().isNotEmpty &&
              !model.supportsNegativePrompt) ||
          (draft.soundEnabled && !model.supportsSound)) {
        throw StateError('Unsupported model settings, actors, or attachments.');
      }
    }
    final ownedAssetIds = <String>{
      for (final a in _workspace.avatarReferences[draft.avatarName] ??
          const <AvatarReference>[])
        a.id,
      for (final a in _workspace.sceneReferences[draft.projectId] ??
          const <AvatarReference>[])
        a.id,
    };
    if (draft.selectedReferenceIds.toSet().length !=
            draft.selectedReferenceIds.length ||
        draft.selectedReferenceIds.any((id) => !ownedAssetIds.contains(id))) {
      throw StateError('Selected references are not in this workspace.');
    }
    // Capture a stable, detached job snapshot after validation.
    final canonicalProject = projects.where((p) => p.id == draft.projectId);
    drafts.insert(
      0,
      GenerationDraft(
        project: canonicalProject.isEmpty
            ? draft.project
            : canonicalProject.first.title,
        prompt: draft.prompt,
        model: draft.model,
        aspectRatio: draft.aspectRatio,
        durationSeconds: draft.durationSeconds,
        createdAt: draft.createdAt,
        projectId: draft.projectId,
        avatarName: draft.avatarName,
        modelId: draft.modelId,
        requestedAttachments: List<VideoAttachment>.unmodifiable(
          draft.requestedAttachments,
        ),
        actors: List<SceneActor>.unmodifiable(draft.actors),
        referenceFiles: List<SceneReference>.unmodifiable(draft.referenceFiles),
        negativePrompt: draft.negativePrompt,
        seed: draft.seed,
        soundEnabled: draft.soundEnabled,
        selectedReferenceIds:
            List<String>.unmodifiable(draft.selectedReferenceIds),
      ),
    );
    notifyListeners();
  }

  void saveMusicPlan(MusicVideoPlan plan) {
    if (!projects.any((p) => p.id == plan.projectId)) {
      throw StateError('The selected project is not in this demo workspace.');
    }
    if (plan.storyBrief.trim().isEmpty || plan.shots.isEmpty) {
      throw StateError('A story and storyboard shots are required.');
    }
    if (plan.avatarName != 'None' &&
        !avatars.any((avatar) => avatar.name == plan.avatarName)) {
      throw StateError('Avatar belongs to a different workspace.');
    }
    if (plan.shots.any(
      (shot) =>
          shot.estimatedSeconds <= 0 ||
          shot.estimatedSeconds > 600 ||
          shot.description.trim().isEmpty,
    )) {
      throw StateError(
        'Storyboard shots require a description and a valid duration.',
      );
    }
    musicPlans.insert(
      0,
      MusicVideoPlan(
        projectId: plan.projectId,
        storyBrief: plan.storyBrief.trim(),
        visualStyle: plan.visualStyle,
        avatarName: plan.avatarName,
        shots: List<StoryboardShot>.unmodifiable(plan.shots),
        createdAt: plan.createdAt,
      ),
    );
    notifyListeners();
  }

  /// Versioned local snapshot for the encrypted device archive. It contains
  /// project text and metadata only; never auth tokens, billing state, or raw
  /// camera/media bytes. Every user-authored draft field is round-tripped.
  Map<String, dynamic> exportLocalSnapshot() => {
        'schema': 2,
        'selectedAccount': selectedAccount,
        'selectedWorkspaceId': selectedWorkspaceId,
        'theme': themeMode.name,
        'accent': accent.name,
        'font': font.name,
        'workspaces': {
          for (final entry in _workspaces.entries)
            entry.key: {
              'projects': [
                for (final p in entry.value.projects)
                  {
                    'id': p.id,
                    'title': p.title,
                    'createdAt': p.createdAt.toIso8601String(),
                  },
              ],
              'avatars': [
                for (final a in entry.value.avatars)
                  {
                    'name': a.name,
                    'style': a.style,
                    'identityNotes': a.identityNotes,
                  },
              ],
              'avatarReferences': [
                for (final owner in entry.value.avatarReferences.entries)
                  {
                    'avatarName': owner.key,
                    'assets': [
                      for (final asset in owner.value) _referenceJson(asset)
                    ],
                  },
              ],
              'sceneReferences': [
                for (final owner in entry.value.sceneReferences.entries)
                  {
                    'projectId': owner.key,
                    'assets': [
                      for (final asset in owner.value) _referenceJson(asset)
                    ],
                  },
              ],
              'drafts': [
                for (final d in entry.value.drafts)
                  {
                    'projectId': d.projectId,
                    'project': d.project,
                    'prompt': d.prompt,
                    'model': d.model,
                    'modelId': d.modelId,
                    'aspectRatio': d.aspectRatio,
                    'durationSeconds': d.durationSeconds,
                    'createdAt': d.createdAt.toIso8601String(),
                    'avatarName': d.avatarName,
                    'requestedAttachments': [
                      for (final a in d.requestedAttachments) a.name,
                    ],
                    'selectedReferenceIds': d.selectedReferenceIds,
                    'actors': [
                      for (final a in d.actors)
                        {'avatarName': a.avatarName, 'sceneName': a.sceneName},
                    ],
                    'referenceFiles': [
                      for (final f in d.referenceFiles)
                        {
                          'type': f.type.name,
                          'fileName': f.fileName,
                          'bytes': f.bytes,
                        },
                    ],
                    'negativePrompt': d.negativePrompt,
                    'seed': d.seed,
                    'soundEnabled': d.soundEnabled,
                  },
              ],
              'musicPlans': [
                for (final m in entry.value.musicPlans)
                  {
                    'projectId': m.projectId,
                    'storyBrief': m.storyBrief,
                    'visualStyle': m.visualStyle,
                    'avatarName': m.avatarName,
                    'createdAt': m.createdAt.toIso8601String(),
                    'shots': [
                      for (final shot in m.shots)
                        {
                          'title': shot.title,
                          'description': shot.description,
                          'estimatedSeconds': shot.estimatedSeconds,
                        },
                    ],
                  },
              ],
              'pendingMockSubmissions': [
                for (final submission in entry.value.pendingMockSubmissions)
                  {
                    'idempotencyKey': submission.idempotencyKey,
                    'accountUserId': submission.accountUserId,
                    'projectId': submission.projectId,
                    'prompt': submission.prompt,
                    'createdAt': submission.createdAt.toIso8601String(),
                  },
              ],
              'cloudRevisions': entry.value.cloudRevisions,
            },
        },
      };

  /// Restore validated local archive content. This never restores a server
  /// session or grants cloud access.
  void restoreLocalSnapshot(Map<String, dynamic> data) {
    final schema = data['schema'];
    if ((schema != 1 && schema != 2) || data['workspaces'] is! Map) {
      throw const FormatException('Unsupported HOTICE local project snapshot.');
    }
    Iterable<Map<String, dynamic>> rows(Object? value) sync* {
      if (value is! List) return;
      for (final row in value) {
        if (row is Map<String, dynamic>) yield row;
      }
    }

    DateTime stamp(Object? value) =>
        DateTime.tryParse(value is String ? value : '') ?? DateTime.now();
    List<VideoAttachment> attachmentTypes(Object? value) {
      if (value is! List) return const [];
      return VideoAttachment.values
          .where((type) => value.contains(type.name))
          .toList(growable: false);
    }

    AvatarReference? restoreReference(Map<String, dynamic> row, String owner,
        {bool avatar = false}) {
      final id = row['id'];
      final localPath = row['localPath'];
      final role =
          ReferenceRole.values.where((value) => value.name == row['role']);
      final format =
          ReferenceFormat.values.where((value) => value.name == row['format']);
      final mime = row['mimeType'];
      if (id is! String ||
          !isCloudProjectId(id) ||
          row['ownerName'] != owner ||
          role.isEmpty ||
          format.length != 1 ||
          format.single != ReferenceFormat.image ||
          (avatar && role.single != ReferenceRole.avatar) ||
          (!avatar && role.single == ReferenceRole.avatar) ||
          mime is! String ||
          !const ['image/jpeg', 'image/png', 'image/webp'].contains(mime) ||
          localPath is! String ||
          localPath.length > 4096 ||
          !localPath.replaceAll('\\', '/').endsWith('/$id.aes')) return null;
      final view = FaceView.values.where((value) => value.name == row['view']);
      return AvatarReference(
          id: id,
          ownerName: owner,
          role: role.single,
          format: format.single,
          mimeType: mime,
          localPath: localPath,
          view: view.isEmpty ? null : view.single,
          isScanVerified: row['isScanVerified'] == true,
          ownedTemporaryFile: row['ownedTemporaryFile'] == true);
    }

    final replacement = <String, _DemoWorkspace>{};
    final replacementDemoAccounts = <String>[];
    final sources = data['workspaces'] as Map;
    if (sources.length > 30)
      throw const FormatException('Too many local workspaces.');
    for (final entry in sources.entries) {
      if (entry.key is! String || entry.value is! Map<String, dynamic>)
        continue;
      final storedKey = entry.key as String;
      final email = schema == 1
          ? storedKey.toLowerCase()
          : storedKey.startsWith('demo:')
              ? storedKey.substring('demo:'.length).toLowerCase()
              : null;
      final accountId =
          schema == 2 ? _accountIdFromWorkspaceId(storedKey) : null;
      if (email == null && accountId == null) continue;
      if (email != null && !isValidDemoEmail(email)) continue;
      if (schema == 2 &&
          storedKey.startsWith('account:') &&
          accountId == null) {
        continue;
      }
      final workspaceId = accountId == null
          ? _demoWorkspaceId(email!)
          : _accountWorkspaceId(accountId);
      final source = entry.value as Map<String, dynamic>;
      final target = _DemoWorkspace();
      final revisions = source['cloudRevisions'];
      if (revisions is Map) {
        for (final entry in revisions.entries.take(500)) {
          if (entry.key is String &&
              entry.value is int &&
              (entry.value as int) > 0) {
            target.cloudRevisions[entry.key as String] = entry.value as int;
          }
        }
      }
      for (final row in rows(source['projects']).take(500)) {
        final id = row['id'];
        final title = row['title'];
        if (id is String &&
            id.isNotEmpty &&
            title is String &&
            title.trim().isNotEmpty &&
            !target.projects.any((item) => item.id == id)) {
          target.projects.add(HotProject(id, title, stamp(row['createdAt'])));
        }
      }
      target.cloudRevisions.removeWhere(
        (id, _) => !target.projects.any((item) => item.id == id),
      );
      for (final row in rows(source['pendingMockSubmissions']).take(100)) {
        final key = row['idempotencyKey'];
        final userId = row['accountUserId'];
        final projectId = row['projectId'];
        final prompt = row['prompt'];
        if (key is String &&
            RegExp(r'^[A-Za-z0-9._~:-]{16,128}$').hasMatch(key) &&
            userId is String &&
            userId.trim().isNotEmpty &&
            userId.length <= 128 &&
            !RegExp(r'[\x00-\x1f\x7f]').hasMatch(userId) &&
            projectId is String &&
            isCloudProjectId(projectId) &&
            target.projects.any((project) => project.id == projectId) &&
            prompt is String &&
            prompt.trim().isNotEmpty &&
            prompt.trim().length <= 2000 &&
            !target.pendingMockSubmissions.any(
              (item) => item.idempotencyKey == key,
            )) {
          target.pendingMockSubmissions.add(
            PendingMockSubmission(
              idempotencyKey: key,
              accountUserId: userId,
              projectId: projectId,
              prompt: prompt,
              createdAt: stamp(row['createdAt']),
            ),
          );
        }
      }
      for (final row in rows(source['avatars']).take(100)) {
        final name = row['name'];
        final style = row['style'];
        if (name is String &&
            name.trim().isNotEmpty &&
            style is String &&
            !target.avatars.any(
              (item) => item.name.toLowerCase() == name.toLowerCase(),
            )) {
          target.avatars.add(
            StudioAvatar(
              name,
              style,
              identityNotes: row['identityNotes'] is String
                  ? row['identityNotes'] as String
                  : '',
            ),
          );
        }
      }
      for (final owner in rows(source['avatarReferences']).take(100)) {
        final name = owner['avatarName'];
        if (name is! String ||
            !target.avatars.any((avatar) => avatar.name == name)) continue;
        final assets = <AvatarReference>[];
        for (final row in rows(owner['assets']).take(16)) {
          final asset = restoreReference(row, name, avatar: true);
          if (asset != null && !assets.any((item) => item.id == asset.id))
            assets.add(asset);
        }
        if (assets.isNotEmpty) target.avatarReferences[name] = assets;
      }
      for (final owner in rows(source['sceneReferences']).take(500)) {
        final projectId = owner['projectId'];
        if (projectId is! String ||
            !target.projects.any((project) => project.id == projectId))
          continue;
        final assets = <AvatarReference>[];
        for (final row in rows(owner['assets']).take(12)) {
          final asset = restoreReference(row, projectId);
          if (asset != null &&
              !target.avatarReferences.values
                  .expand((items) => items)
                  .any((item) => item.id == asset.id) &&
              !assets.any((item) => item.id == asset.id)) assets.add(asset);
        }
        if (assets.isNotEmpty) target.sceneReferences[projectId] = assets;
      }
      final restoredReferenceIds = <String>{
        for (final assets in target.avatarReferences.values)
          for (final asset in assets) asset.id,
        for (final assets in target.sceneReferences.values)
          for (final asset in assets) asset.id,
      };
      for (final row in rows(source['drafts']).take(1000)) {
        final projectId = row['projectId'];
        if (projectId is! String ||
            !target.projects.any((p) => p.id == projectId)) continue;
        final actors = <SceneActor>[];
        for (final actor in rows(row['actors']).take(100)) {
          if (actor['avatarName'] is String &&
              actor['sceneName'] is String &&
              target.avatars.any((a) => a.name == actor['avatarName'])) {
            actors.add(
              SceneActor(
                avatarName: actor['avatarName'] as String,
                sceneName: actor['sceneName'] as String,
              ),
            );
          }
        }
        final refs = <SceneReference>[];
        for (final ref in rows(row['referenceFiles']).take(100)) {
          final type = VideoAttachment.values.where(
            (v) => v.name == ref['type'],
          );
          if (type.isNotEmpty &&
              ref['fileName'] is String &&
              ref['bytes'] is int &&
              (ref['bytes'] as int) >= 0) {
            refs.add(
              SceneReference(
                type: type.first,
                fileName: ref['fileName'] as String,
                bytes: ref['bytes'] as int,
              ),
            );
          }
        }
        final title =
            target.projects.firstWhere((p) => p.id == projectId).title;
        target.drafts.add(
          GenerationDraft(
            projectId: projectId,
            project: title,
            prompt: row['prompt'] is String ? row['prompt'] as String : '',
            model: row['model'] is String ? row['model'] as String : '',
            modelId: row['modelId'] is String ? row['modelId'] as String : '',
            aspectRatio: row['aspectRatio'] is String
                ? row['aspectRatio'] as String
                : '16:9',
            durationSeconds: row['durationSeconds'] is int
                ? row['durationSeconds'] as int
                : 8,
            createdAt: stamp(row['createdAt']),
            avatarName: row['avatarName'] is String
                ? row['avatarName'] as String
                : 'None',
            requestedAttachments: attachmentTypes(row['requestedAttachments']),
            actors: actors,
            referenceFiles: refs,
            negativePrompt: row['negativePrompt'] is String
                ? row['negativePrompt'] as String
                : '',
            seed: row['seed'] is int ? row['seed'] as int : null,
            soundEnabled: row['soundEnabled'] == true,
            selectedReferenceIds: [
              for (final id in row['selectedReferenceIds'] is List
                  ? (row['selectedReferenceIds'] as List).take(16)
                  : const <Object>[])
                if (id is String && restoredReferenceIds.contains(id)) id,
            ],
          ),
        );
      }
      for (final row in rows(source['musicPlans']).take(500)) {
        final projectId = row['projectId'];
        if (projectId is! String ||
            !target.projects.any((p) => p.id == projectId)) continue;
        final shots = <StoryboardShot>[];
        for (final shot in rows(row['shots']).take(250)) {
          final duration = shot['estimatedSeconds'];
          final description = shot['description'];
          if (duration is int &&
              duration > 0 &&
              duration <= 600 &&
              description is String &&
              description.trim().isNotEmpty) {
            shots.add(
              StoryboardShot(
                shot['title'] is String ? shot['title'] as String : 'Shot',
                description,
                duration,
              ),
            );
          }
        }
        if (shots.isNotEmpty) {
          target.musicPlans.add(
            MusicVideoPlan(
              projectId: projectId,
              storyBrief: row['storyBrief'] is String
                  ? row['storyBrief'] as String
                  : '',
              visualStyle: row['visualStyle'] is String
                  ? row['visualStyle'] as String
                  : 'Cinematic realism',
              avatarName: row['avatarName'] is String
                  ? row['avatarName'] as String
                  : 'None',
              shots: shots,
              createdAt: stamp(row['createdAt']),
            ),
          );
        }
      }
      if (!replacement.containsKey(workspaceId)) {
        replacement[workspaceId] = target;
        if (email != null) replacementDemoAccounts.add(email);
      }
    }
    if (replacement.isEmpty)
      throw const FormatException('Encrypted archive has no valid workspaces.');
    _workspaces
      ..clear()
      ..addAll(replacement);
    accounts
      ..clear()
      ..addAll(replacementDemoAccounts.toSet());
    final selected = data['selectedAccount'];
    final selectedWorkspace = data['selectedWorkspaceId'];
    final legacySelected = selected is String && isValidDemoEmail(selected)
        ? _demoWorkspaceId(selected)
        : null;
    selectedWorkspaceId = selectedWorkspace is String &&
            replacement.containsKey(selectedWorkspace)
        ? selectedWorkspace
        : legacySelected != null && replacement.containsKey(legacySelected)
            ? legacySelected
            : replacement.keys.first;
    selectedAccount = selected is String && isValidDemoEmail(selected)
        ? selected.trim().toLowerCase()
        : accounts.isNotEmpty
            ? accounts.first
            : '';
    themeMode = ThemeMode.values.firstWhere(
      (v) => v.name == data['theme'],
      orElse: () => ThemeMode.dark,
    );
    accent = StudioAccent.values.firstWhere(
      (v) => v.name == data['accent'],
      orElse: () => StudioAccent.electric,
    );
    font = StudioFont.values.firstWhere(
      (v) => v.name == data['font'],
      orElse: () => StudioFont.modern,
    );
    signedIn = false;
    authenticatedUserId = null;
    notifyListeners();
  }

  void updateTheme(ThemeMode value) {
    themeMode = value;
    notifyListeners();
  }

  void updateAccent(StudioAccent value) {
    accent = value;
    notifyListeners();
  }

  void updateFont(StudioFont value) {
    font = value;
    notifyListeners();
  }
}
