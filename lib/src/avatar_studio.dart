import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'smart_references.dart';
import 'live_face_capture.dart';
import 'face_capture_quality.dart';
import 'face_capture_storage.dart';
import 'face_reference_vault.dart';
import 'avatar_reference_backup.dart';
import 'dart:io';
import 'avatar_identity.dart';
import 'design.dart';
import 'state.dart';

/// Local character workshop with separate guided live 2D camera capture.
/// The five-pose illustration remains a design preview, not a mesh scanner.
class AvatarsPage extends StatefulWidget {
  final HotIceStore store;
  const AvatarsPage({super.key, required this.store});

  @override
  State<AvatarsPage> createState() => _AvatarsPageState();
}

class _AvatarsPageState extends State<AvatarsPage> {
  final name = TextEditingController();
  final identityNotes = TextEditingController();
  String style = 'Photorealistic';
  String? editingName;
  bool showScanGuide = false;
  bool showLiveCapture = false;
  String? captureTarget;
  int poseIndex = 0;

  Future<String?> _askBackupPassword({bool confirmation = false}) async {
    final first = TextEditingController();
    final second = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
              confirmation ? 'Protect actor backup' : 'Unlock actor backup'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: first,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'Backup password (12+ characters)'),
              ),
              if (confirmation)
                TextField(
                  controller: second,
                  obscureText: true,
                  decoration:
                      const InputDecoration(labelText: 'Confirm password'),
                ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (first.text.length < 12 ||
                    first.text.length > 1024 ||
                    (confirmation && first.text != second.text)) return;
                Navigator.pop(ctx, first.text);
              },
              child: Text(confirmation ? 'Create backup' : 'Unlock'),
            ),
          ],
        ),
      );
    } finally {
      first.dispose();
      second.dispose();
    }
  }

  void _backupMessage(String message) {
    if (mounted)
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> exportActorBackup(StudioAvatar avatar) async {
    final workspace = widget.store.selectedWorkspaceId;
    final password = await _askBackupPassword(confirmation: true);
    if (!mounted || password == null) return;
    try {
      if (workspace != widget.store.selectedWorkspaceId) {
        throw const AvatarReferenceBackupException(
            'The active account changed. Start again from the intended account.');
      }
      final pack = widget.store.avatarPackFor(avatar.name);
      if (pack.assets.isEmpty) {
        throw const AvatarReferenceBackupException(
            'Add at least one face photo before creating a portable backup.');
      }
      if (!Platform.isAndroid && !Platform.isIOS) {
        throw const AvatarReferenceBackupException(
            'Encrypted face-photo storage is currently available on Android and iOS.');
      }
      final vault = await FaceReferenceVault.openOnDevice();
      final photos = <AvatarBackupPhoto>[];
      for (final reference in pack.assets) {
        if (reference.view == null) {
          throw const AvatarReferenceBackupException(
              'Every photo needs a face-view label before backup.');
        }
        photos.add(AvatarBackupPhoto(
          view: reference.view!,
          mimeType: reference.mimeType,
          bytes: await vault.decryptPhoto(reference.localPath),
        ));
      }
      if (workspace != widget.store.selectedWorkspaceId) {
        throw const AvatarReferenceBackupException(
            'The active account changed during backup. Start again.');
      }
      final bytes = await AvatarReferenceBackupCodec().encode(
        AvatarReferenceBackup(
          name: avatar.name,
          style: avatar.style,
          identityNotes: avatar.identityNotes,
          photos: photos,
        ),
        password: password,
      );
      final saved = await FilePicker.saveFile(
        fileName:
            '${avatar.name.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}.hoticeactor',
        bytes: bytes,
        mimeType: 'application/vnd.hotice.actor-backup',
        dialogTitle: 'Save encrypted HOTICE actor backup',
      );
      if (saved != null)
        _backupMessage(
            'Encrypted actor backup saved. Keep the password separately; HOTICE cannot recover it.');
    } catch (error) {
      _backupMessage(error is AvatarReferenceBackupException
          ? error.message
          : 'Actor backup could not be created. Check the encrypted photo vault and try again.');
    }
  }

  Future<void> importActorBackup() async {
    final workspace = widget.store.selectedWorkspaceId;
    final consent = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore an actor backup?'),
        content: const Text(
            'The password-protected file contains sensitive face photos. HOTICE will decrypt it locally, encrypt each photo with this device key, and add the actor to the active local workspace. Nothing is uploaded. The backup password is not saved.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Choose backup')),
        ],
      ),
    );
    if (!mounted || consent != true) return;
    try {
      final selected = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['hoticeactor'],
        dialogTitle: 'Choose encrypted HOTICE actor backup',
      );
      if (selected == null) return;
      final length = selected.lengthSync() ?? await selected.length();
      if (length == null ||
          length >
              AvatarReferenceBackupCodec.maxTotalPhotoBytes * 2 + 1024 * 1024) {
        throw const AvatarReferenceBackupException(
            'The backup file exceeds the supported size.');
      }
      final password = await _askBackupPassword();
      if (!mounted || password == null) return;
      final decoded = await AvatarReferenceBackupCodec().decode(
        await selected.readAsBytes(),
        password: password,
      );
      if (workspace != widget.store.selectedWorkspaceId) {
        throw const AvatarReferenceBackupException(
            'The active account changed. Start again from the intended account.');
      }
      if (widget.store.avatars.any((avatar) => avatar.name == decoded.name)) {
        throw const AvatarReferenceBackupException(
            'An actor with this name already exists in the active workspace. Rename or remove it before restoring.');
      }
      if (!Platform.isAndroid && !Platform.isIOS) {
        throw const AvatarReferenceBackupException(
            'Encrypted face-photo storage is currently available on Android and iOS.');
      }
      final vault = await FaceReferenceVault.openOnDevice();
      final createdPaths = <String>[];
      final references = <AvatarReference>[];
      try {
        for (final photo in decoded.photos) {
          if (workspace != widget.store.selectedWorkspaceId) {
            throw const AvatarReferenceBackupException(
                'The active account changed during restore.');
          }
          final id = createLocalProjectId();
          final stored = await vault.encryptPhotoBytes(
            photo.bytes,
            referenceId: id,
          );
          createdPaths.add(stored.path);
          references.add(AvatarReference(
            id: stored.id,
            ownerName: decoded.name,
            role: ReferenceRole.avatar,
            format: ReferenceFormat.image,
            mimeType: stored.mimeType,
            localPath: stored.path,
            view: photo.view,
            ownedTemporaryFile: true,
          ));
        }
        if (workspace != widget.store.selectedWorkspaceId ||
            !widget.store.addAvatarWithReferences(
              StudioAvatar(decoded.name, decoded.style,
                  identityNotes: decoded.identityNotes),
              references,
            )) {
          throw const AvatarReferenceBackupException(
              'The actor could not be added to the active workspace.');
        }
      } catch (_) {
        for (final path in createdPaths) {
          try {
            await vault.deletePhoto(path);
          } catch (_) {}
        }
        rethrow;
      }
      _backupMessage(
          'Actor restored to this device. Face photos are encrypted locally; no 3D scan is claimed.');
    } catch (error) {
      _backupMessage(error is AvatarReferenceBackupException
          ? error.message
          : 'Actor backup could not be restored. Check the file and password, then try again.');
    }
  }



  @override
  void initState() {
    super.initState();
    unawaited(_cleanAbandonedFaceCaptures());
  }

  Future<void> _cleanAbandonedFaceCaptures() async {
    try {
      final temporaryRoot = await getTemporaryDirectory();
      final retainedPaths = widget.store.avatars
          .expand((avatar) => widget.store.avatarPackFor(avatar.name).assets)
          .where((asset) => asset.ownedTemporaryFile)
          .map((asset) => asset.localPath)
          .toList();
      await deleteOrphanedFaceCaptureBatches(
        temporaryRoot: temporaryRoot,
        retainedPhotoPaths: retainedPaths,
      );
      await deleteAbandonedCameraCaptureFiles(
        temporaryRoot: temporaryRoot,
        androidLayout: Platform.isAndroid,
        iosLayout: Platform.isIOS,
      );
      final vault = await FaceReferenceVault.openOnDevice();
      await vault.deleteOrphanedFiles(retainedPaths: retainedPaths);
    } catch (_) {
      // Cleanup is best-effort; never block the user's Avatar Studio workflow.
    }
  }

  Future<void> _removePickerCacheCopy(String path) async {
    try {
      await deletePickerCacheCopyIfOwned(
        selectedFile: File(path),
        temporaryRoot: await getTemporaryDirectory(),
        androidLayout: Platform.isAndroid,
        darwinLayout: Platform.isIOS,
      );
    } catch (_) {
      // The OS may already have reclaimed a temporary picker copy.
    }
  }

  static const poses = <({String title, String hint, IconData icon})>[
    (title: 'Front portrait', hint: 'Even lighting, neutral expression and no face filters.', icon: Icons.face_outlined),
    (title: 'Left profile', hint: 'Turn about 45 degrees. Keep the camera at eye level.', icon: Icons.rotate_left_rounded),
    (title: 'Right profile', hint: 'Turn about 45 degrees to the other side.', icon: Icons.rotate_right_rounded),
    (title: 'Expression', hint: 'Keep lighting consistent; capture a natural smile later.', icon: Icons.sentiment_satisfied_alt_outlined),
    (title: 'Full-body reference', hint: 'Use a clear outfit and consistent body proportions.', icon: Icons.accessibility_new_rounded),
  ];

  @override
  void dispose() {
    name.dispose();
    identityNotes.dispose();
    super.dispose();
  }

  void saveAvatar() {
    if (name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give your character a name first.')),
      );
      return;
    }
    final created = editingName == null
        ? widget.store.addAvatar(name.text, style,
            identityNotes: identityNotes.text)
        : widget.store.editAvatar(editingName!, name.text, style,
            identityNotes: identityNotes.text);
    if (created) {
      name.clear();
      identityNotes.clear();
      setState(() => editingName = null);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(created
          ? 'Character profile saved in this demo workspace.'
          : 'That character name is already used. Try another name.')),
    );
  }

  void startEditing(StudioAvatar avatar) {
    setState(() {
      editingName = avatar.name;
      name.text = avatar.name;
      style = avatar.style;
      identityNotes.text = avatar.identityNotes;
      showScanGuide = false;
      showLiveCapture = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit the character in the form above.')),
    );
  }

  Future<void> deleteAvatar(StudioAvatar avatar) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ' + avatar.name + '?'),
        content: const Text('This removes the local character preset. Previous scene drafts remain historical snapshots.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep character')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    widget.store.removeAvatar(avatar.name);
    if (editingName == avatar.name) {
      setState(() {
        editingName = null;
        name.clear();
        identityNotes.clear();
      });
    }
  }

  Future<void> startRealCapture(StudioAvatar avatar) async {
    if (widget.store.avatarPackFor(avatar.name).assets.length > 11) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Remove some previous photos before adding five more.'),
      ));
      return;
    }
    final photos = await Navigator.of(context).push<List<CapturedFacePhoto>>(
      MaterialPageRoute(builder: (_) => const LiveFaceScanPage()),
    );
    if (photos == null || photos.isEmpty) return;
    if (!mounted) {
      for (final photo in photos) {
        try { await File(photo.path).delete(); } catch (_) {}
      }
      return;
    }
    const viewByPose = <CapturePose, FaceView>{
      CapturePose.front: FaceView.front,
      CapturePose.left45: FaceView.left45,
      CapturePose.right45: FaceView.right45,
      CapturePose.left90: FaceView.left90,
      CapturePose.right90: FaceView.right90,
    };
    var saved = 0;
    for (final shot in photos) {
      final success = widget.store.addAvatarReference(
        avatar.name,
        AvatarReference(
          id: shot.id,
          ownerName: avatar.name,
          role: ReferenceRole.avatar,
          format: ReferenceFormat.image,
          mimeType: shot.mimeType,
          localPath: shot.path,
          view: viewByPose[shot.pose],
          ownedTemporaryFile: true,
          // These are 2D photos, never claim a verified 3D mesh.
          isScanVerified: false,
        ),
      );
      if (success) {
        saved++;
      } else {
        try { await (await FaceReferenceVault.openOnDevice()).deletePhoto(shot.path); } catch (_) {}
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(saved.toString() +
          ' guided 2D face references saved on this device. Not a 3D mesh.'),
    ));
  }

  Future<void> importFacePhoto(StudioAvatar avatar) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Encrypted face-photo storage is currently available on Android and iOS.'),
      ));
      return;
    }
    final view = await showModalBottomSheet<FaceView>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Label this face view'),
                subtitle: Text('Choose the angle shown in your actual photo.')),
            for (final angle in FaceView.values)
              ListTile(
                title: Text(angle.label),
                onTap: () => Navigator.pop(ctx, angle),
              ),
          ],
        ),
      ),
    );
    if (!mounted || view == null) return;
    final consent = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import face reference?'),
        content: const Text(
          'This photo contains sensitive likeness data. HOTICE will retain '
          'an encrypted copy in private storage on this device. The reference '
          'records persist with this device local project archive and remain '
          'linked to this Actor after restart. Media is not uploaded, backed up, '
          'or recoverable on another device. This is not a verified 3D scan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Choose photo')),
        ],
      ),
    );
    if (!mounted || consent != true) return;
    String? selectedPickerPath;
    try {
      final file = await FilePicker.pickFile(type: FileType.image);
      if (file == null) return;
      selectedPickerPath = file.path;
      if (!mounted) {
        if (selectedPickerPath != null) {
          await _removePickerCacheCopy(selectedPickerPath);
        }
        return;
      }
      final fileBytes = file.lengthSync() ?? await file.length();
      if (!mounted) {
        if (selectedPickerPath != null) {
          await _removePickerCacheCopy(selectedPickerPath);
        }
        return;
      }
      final ext = (file.extension ?? '').toLowerCase();
      final mime = switch (ext) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => null,
      };
      final path = file.path;
      if (mime == null || path == null || path.isEmpty ||
          fileBytes == null || fileBytes <= 0 || fileBytes > 15 * 1024 * 1024) {
        if (path != null && path.isNotEmpty) {
          await _removePickerCacheCopy(path);
        }
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Choose a JPG/PNG/WebP photo under 15 MB.'),
        ));
        return;
      }
      final id = createLocalProjectId();
      late final StoredFaceReference encrypted;
      try {
        encrypted = await (await FaceReferenceVault.openOnDevice())
            .encryptPhoto(File(path), referenceId: id);
      } finally {
        await _removePickerCacheCopy(path);
      }
      final saved = widget.store.addAvatarReference(avatar.name, AvatarReference(
        id: encrypted.id,
        ownerName: avatar.name,
        role: ReferenceRole.avatar,
        format: ReferenceFormat.image,
        mimeType: encrypted.mimeType,
        localPath: encrypted.path,
        view: view,
        ownedTemporaryFile: true,
      ));
      if (!saved) {
        await (await FaceReferenceVault.openOnDevice())
            .deletePhoto(encrypted.path);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(saved
          ? '${view.label} reference added to this device encrypted Actor library.'
          : 'Could not add reference. Check avatar and limit (16).')));
    } catch (_) {
      if (selectedPickerPath != null) {
        await _removePickerCacheCopy(selectedPickerPath);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Image selection failed or was cancelled.'),
      ));
    }
  }

  void openProfile(StudioAvatar avatar) {
    final card = AvatarPromptComposer.identityCard(avatar);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(avatar.name, style: Theme.of(ctx).textTheme.headlineMedium),
                const SizedBox(height: 8),
                const Text('Reusable character identity card · Text-only demo'),
                const SizedBox(height: 16),
                SelectableText(card),
                const SizedBox(height: 16),
                const DemoNotice(
                  'HOTICE can add these notes to demo video prompts. Real 3D scanning, facial matching and provider-specific references are not active.',
                ),
                const SizedBox(height: 14),
                Text('Saved face references: '
                    '${widget.store.avatarPackFor(avatar.name).assets.length} '
                    '(encrypted on this device)'),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => exportActorBackup(avatar),
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('Create encrypted portable backup'),
                ),
                for (final photo in widget.store.avatarPackFor(avatar.name).assets)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.photo_outlined),
                    title: Text(photo.view?.label ?? 'Reference'),
                    subtitle: const Text('Unverified face photo'),
                    trailing: IconButton(
                      tooltip: 'Remove this reference',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        widget.store.removeAvatarReference(avatar.name, photo.id);
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: card));
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy identity notes'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageTitle(
            eyebrow: 'Actor identity',
            title: 'Actors Studio',
            subtitle: 'Create once. Reuse the same character description across your shots.',
          ),
          const DemoNotice(
            'Beta: live guided multi-angle 2D capture is available on Android/iOS with consent. Accepted face photos use device-key AES-GCM encryption; reference records persist in the encrypted device-local project archive. Media is not backed up or synced. No 3D reconstruction or identity verification.'
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: importActorBackup,
              icon: const Icon(Icons.restore_rounded),
              label: const Text('Restore actor backup'),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ChoiceChip(
                avatar: const Icon(Icons.edit_note_rounded, size: 18),
                label: const Text('Quick character'),
                selected: !showScanGuide && !showLiveCapture,
                onSelected: (_) => setState(() {
                  showScanGuide = false;
                  showLiveCapture = false;
                }),
              ),
              ChoiceChip(
                avatar: const Icon(Icons.face_retouching_natural_rounded, size: 18),
                label: const Text('3D face-scan guide'),
                selected: showScanGuide,
                onSelected: (_) => setState(() {
                  showScanGuide = true;
                  showLiveCapture = false;
                }),
              ),
              ChoiceChip(
                avatar: const Icon(Icons.camera_front_outlined, size: 18),
                label: const Text('Live face capture'),
                selected: showLiveCapture,
                onSelected: (_) => setState(() {
                  showLiveCapture = true;
                  showScanGuide = false;
                }),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (showLiveCapture) StudioPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('On-device guided capture',
                  style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 9),
                const Text('Capture five face views with camera framing, head angles and eyes-open checks. This creates real 2D reference photos, not a 3D model. Temporary cache only.'),
                const SizedBox(height: 16),
                if (widget.store.avatars.isEmpty)
                  const Text('Save a character below before scanning its face.'),
                if (widget.store.avatars.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    key: const ValueKey('scan-avatar-selector'),
                    initialValue: widget.store.avatars.any((a) => a.name == captureTarget)
                        ? captureTarget : widget.store.avatars.first.name,
                    decoration: const InputDecoration(labelText: 'Attach to character'),
                    items: [for (final avatar in widget.store.avatars)
                      DropdownMenuItem(value: avatar.name, child: Text(avatar.name))],
                    onChanged: (value) => setState(() => captureTarget = value),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () {
                      final chosen = widget.store.avatars.firstWhere(
                        (a) => a.name == captureTarget,
                        orElse: () => widget.store.avatars.first,
                      );
                      startRealCapture(chosen);
                    },
                    icon: const Icon(Icons.face_retouching_natural),
                    label: const Text('Start live scanner'),
                  ),
                ],
              ],
            ),
          ),
          if (showScanGuide) ...[
            StudioPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Face capture preparation',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 7),
                  const Text(
                    'Preview the planned multi-angle capture process. Camera capture, depth reconstruction and facial embeddings will be built and tested in a later phase.',
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: Container(
                      width: 244,
                      height: 220,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF182B50), Color(0xFF47306F), Color(0xFF112D43)],
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 165,
                            height: 185,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(70),
                              border: Border.all(color: const Color(0xFF84E8F7), width: 2),
                            ),
                          ),
                          Icon(poses[poseIndex].icon, color: Colors.white, size: 118),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Text(
                              'GUIDE ' + (poseIndex + 1).toString() + '/5',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold, color: Colors.white, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(poses[poseIndex].title,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(poses[poseIndex].hint),
                  const SizedBox(height: 17),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: poseIndex == 0
                            ? null
                            : () => setState(() => poseIndex--),
                        icon: const Icon(Icons.chevron_left),
                        label: const Text('Back'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: poseIndex == poses.length - 1
                              ? () => setState(() => poseIndex = 0)
                              : () => setState(() => poseIndex++),
                          icon: Icon(poseIndex == poses.length - 1
                              ? Icons.replay_rounded : Icons.chevron_right),
                          label: Text(poseIndex == poses.length - 1
                              ? 'Review again' : 'Next angle'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No images are being captured. This walkthrough is a design preview, not a completed scan.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          StudioPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(editingName == null ? 'New actor' : 'Edit ' + editingName!,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 7),
                const Text('A few details now make it easier to describe the same person in every scene.'),
                const SizedBox(height: 17),
                TextField(
                  controller: name,
                  maxLength: 60,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Actor name',
                    hintText: 'e.g. The Explorer',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: style,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Look and feel'),
                  items: const [
                    DropdownMenuItem(value: 'Photorealistic',
                        child: Text('Photorealistic')),
                    DropdownMenuItem(value: 'Cinematic',
                        child: Text('Cinematic')),
                    DropdownMenuItem(value: 'Animated',
                        child: Text('Animated')),
                    DropdownMenuItem(value: 'Stylized',
                        child: Text('Stylized 3D')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => style = v);
                  },
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: identityNotes,
                  maxLength: 350,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Appearance notes (optional)',
                    alignLabelWithHint: true,
                    hintText: 'Hair, beard, eye colour, clothing, distinctive features...',
                  ),
                ),
                const SizedBox(height: 13),
                PrimaryButton(
                  label: editingName == null ? 'Save actor' : 'Save changes',
                  icon: Icons.person_add_alt_1_rounded,
                  onPressed: saveAvatar,
                ),
                if (editingName != null)
                  TextButton(
                    onPressed: () => setState(() {
                      editingName = null;
                      name.clear();
                      identityNotes.clear();
                    }),
                    child: const Text('Cancel editing'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          Row(
            children: [
              Icon(Icons.collections_bookmark_outlined, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Actors library',
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.store.avatars.isEmpty)
            const StudioPanel(
              child: Text('No characters yet. Create one above to start your library.'),
            ),
          for (final avatar in widget.store.avatars)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: StudioPanel(
                padding: const EdgeInsets.all(8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: accent.withValues(alpha: .14),
                    child: Text(avatar.name[0].toUpperCase()),
                  ),
                  title: Text(avatar.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(avatar.style +
                      ' · ${widget.store.avatarPackFor(avatar.name).assets.length} photos · ' +
                      (avatar.identityNotes.isEmpty
                          ? 'Add identity notes later'
                          : 'Identity notes ready')),

                  isThreeLine: false,
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Character options',
                    onSelected: (action) {
                      if (action == 'scan') {
                        startRealCapture(avatar);
                      } else if (action == 'import') {
                        importFacePhoto(avatar);
                      } else if (action == 'edit') {
                        startEditing(avatar);
                      } else if (action == 'delete') {
                        deleteAvatar(avatar);
                      }
                    },
                    itemBuilder: (ctx) => const [
                      PopupMenuItem(value: 'scan', child: Text('Start live guided face capture')),
                      PopupMenuItem(value: 'import', child: Text('Add face reference photo')),
                      PopupMenuItem(value: 'edit', child: Text('Edit character')),
                      PopupMenuItem(value: 'delete', child: Text('Delete character')),
                    ],
                  ),
                  onTap: () => openProfile(avatar),
                ),
              ),
            ),
        ],
      ),
    );
  }
}