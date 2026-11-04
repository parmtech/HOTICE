import 'package:flutter/material.dart';
import 'avatar_identity.dart';
import 'design.dart';
import 'state.dart';
import 'dialogs.dart';
import 'music_audio.dart';

/// Offline storyboard templates are deliberately NOT AI outputs or transcriptions.
class MusicStoryboardTemplates {
  static List<StoryboardShot> fromBrief(String brief) {
    final story = brief.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (story.isEmpty) return const [];
    return [
      StoryboardShot('Opening', 'Establish the world and mood of: ' + story, 6),
      StoryboardShot('Introduce', 'Reveal the main character and their motivation.', 6),
      StoryboardShot('Emotion', 'Move into a striking close-up and emotional shift.', 8),
      StoryboardShot('Finale', 'Conclude with a visual payoff that reflects the opening.', 6),
    ];
  }
}

/// A locally edited shot schedule, not audio-derived timestamps.
class MusicTimelineCue {
  const MusicTimelineCue(this.startSeconds, this.endSeconds);
  final int startSeconds;
  final int endSeconds;
}

class MusicStoryboardTimeline {
  static List<MusicTimelineCue> arrange(List<StoryboardShot> shots) {
    var cursor = 0;
    return [
      for (final shot in shots)
        MusicTimelineCue(cursor, cursor += shot.estimatedSeconds < 0
            ? 0 : shot.estimatedSeconds),
    ];
  }

  /// Match user-timed cues to the estimated scene windows they overlap.
  /// Windows use [start, end) boundaries; cues spanning a cut appear on both
  /// scenes. This never infers beats or lyric timing.
  static List<List<ManualMusicCue>> matchManualCues(
    List<StoryboardShot> shots,
    List<ManualMusicCue> manualCues,
  ) {
    final schedule = arrange(shots);
    return [
      for (final scene in schedule)
        List<ManualMusicCue>.unmodifiable(manualCues.where((cue) =>
            cue.startMilliseconds < scene.endSeconds * 1000 &&
            cue.endMilliseconds > scene.startSeconds * 1000)),
    ];
  }

  static String clock(int seconds) {
    final safe = seconds < 0 ? 0 : seconds;
    return '${(safe ~/ 60).toString().padLeft(2, '0')}:${(safe % 60).toString().padLeft(2, '0')}';
  }
}

class MusicVideoStudioPage extends StatefulWidget {
  final HotIceStore store;
  final String? initialProjectId;
  final bool audioActive;
  const MusicVideoStudioPage({super.key, required this.store, this.initialProjectId, this.audioActive = true});

  @override
  State<MusicVideoStudioPage> createState() => _MusicVideoStudioPageState();
}

class _MusicVideoStudioPageState extends State<MusicVideoStudioPage> {
  final story = TextEditingController();
  final Map<String, String> _unsavedStories = {};
  final Map<String, List<StoryboardShot>> _unsavedShots = {};
  final Map<String, List<ManualMusicCue>> _unsavedCues = {};
  final Map<String, String> _unsavedStyles = {};
  final Map<String, String> _unsavedAvatars = {};
  String? projectId;
  String selectedStyle = 'Cinematic realism';
  String selectedAvatar = 'None';
  List<StoryboardShot> shots = [];
  List<ManualMusicCue> manualCues = [];
  Duration? _songDuration;

  static const styles = [
    'Cinematic realism',
    'Photorealistic',
    'Anime',
    '2D animation',
    'Stylized 3D',
    'Fantasy',
    'Illustration',
    'Creature-focused',
  ];

  @override
  void initState() {
    super.initState();
    projectId = widget.initialProjectId ??
        (widget.store.projects.isEmpty ? null : widget.store.projects.first.id);
  }

  void _selectProject(String? next) {
    if (projectId == next) return;
    if (projectId != null) {
      _unsavedStories[projectId!] = story.text;
      _unsavedShots[projectId!] = List<StoryboardShot>.of(shots);
      _unsavedCues[projectId!] = List<ManualMusicCue>.of(manualCues);
      _unsavedStyles[projectId!] = selectedStyle;
      _unsavedAvatars[projectId!] = selectedAvatar;
    }
    projectId = next;
    _songDuration = null;
    // Visual style and recurring Actor belong to the project just like its
    // story. Never carry a different film's creative settings across tabs.
    selectedStyle = next == null ? styles.first : (_unsavedStyles[next] ?? styles.first);
    selectedAvatar = next == null ? 'None' : (_unsavedAvatars[next] ?? 'None');
    story.text = next == null ? '' : (_unsavedStories[next] ?? '');
    shots = next == null
        ? <StoryboardShot>[]
        : List<StoryboardShot>.of(
            _unsavedShots[next] ?? const <StoryboardShot>[],
          );
    manualCues = next == null
        ? <ManualMusicCue>[]
        : List<ManualMusicCue>.of(
            _unsavedCues[next] ?? const <ManualMusicCue>[],
          );
  }

  @override
  void didUpdateWidget(covariant MusicVideoStudioPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialProjectId != null &&
        oldWidget.initialProjectId != widget.initialProjectId) {
      _selectProject(widget.initialProjectId);
    }
  }

  @override
  void dispose() {
    story.dispose();
    super.dispose();
  }

  void draftStoryboard() {
    if (story.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Describe your music video story first.')),
      );
      return;
    }
    setState(() => shots = MusicStoryboardTemplates.fromBrief(story.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Offline storyboard outline created. No AI or audio analysis used.')),
    );
  }

  Future<void> editShot(int index) async {
    final current = shots[index];
    final updated = await showHotIceTextDialog(
      context,
      title: 'Edit ${current.title}',
      label: 'Shot description',
      confirmLabel: 'Save shot',
      initialValue: current.description,
      maxLength: 500,
      minLines: 3,
      maxLines: 6,
    );
    if (!mounted || updated == null || updated.isEmpty) return;
    setState(() {
      final original = shots[index];
      shots[index] = StoryboardShot(original.title, updated, original.estimatedSeconds);
    });
  }

  void setShotDuration(int index, int seconds) {
    if (index < 0 || index >= shots.length || seconds < 4 || seconds > 10) {
      return;
    }
    setState(() {
      final original = shots[index];
      shots[index] = StoryboardShot(original.title, original.description, seconds);
    });
  }

  void moveShot(int index, int direction) {
    final next = index + direction;
    if (next < 0 || next >= shots.length) return;
    setState(() {
      final shot = shots.removeAt(index);
      shots.insert(next, shot);
    });
  }

  void loadSavedPlan(MusicVideoPlan plan) {
    if (!widget.store.projects.any((p) => p.id == plan.projectId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The saved project is no longer available.')),
      );
      return;
    }
    setState(() {
      _selectProject(plan.projectId);
      selectedStyle = styles.contains(plan.visualStyle)
          ? plan.visualStyle
          : styles.first;
      selectedAvatar = widget.store.avatars.any(
        (a) => a.name == plan.avatarName,
      ) ? plan.avatarName : 'None';
      story.text = plan.storyBrief;
      // Copy instead of mutating the previously saved snapshot.
      shots = List<StoryboardShot>.of(plan.shots);
      manualCues = List<ManualMusicCue>.of(plan.manualCues);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Storyboard loaded. Scroll up to edit and save a new draft.')),
    );
  }

  void savePlan() {
    if (shots.isEmpty || story.text.trim().isEmpty || projectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a project and preview a storyboard first.')),
      );
      return;
    }
    if (!widget.store.projects.any((item) => item.id == projectId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose an existing project first.')),
      );
      return;
    }
    final avatars = widget.store.avatars;
    final avatar = selectedAvatar == 'None'
        ? 'None'
        : avatars.any((item) => item.name == selectedAvatar)
            ? selectedAvatar
            : 'None';
    widget.store.saveMusicPlan(MusicVideoPlan(
      projectId: projectId!,
      storyBrief: story.text.trim(),
      visualStyle: selectedStyle,
      avatarName: avatar,
      shots: List.unmodifiable(shots),
      createdAt: DateTime.now(),
      manualCues: List.unmodifiable(manualCues),
    ));
    // The editor can be embedded on its own during testing or future routing.
    // Do not rely solely on an AnimatedBuilder in the parent to refresh the
    // saved-storyboards list.
    if (mounted) setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Storyboard saved for this session. No render job or credits used.')),
    );
  }

  Future<void> editManualCue({int? index}) async {
    final existing = index == null ? null : manualCues[index];
    final text = TextEditingController(text: existing?.text ?? '');
    final start = TextEditingController(
      text: existing == null ? '0' : _seconds(existing.startMilliseconds),
    );
    final defaultEnd = _songDuration == null
        ? 5000
        : _songDuration!.inMilliseconds.clamp(1, 5000);
    final end = TextEditingController(
      text: existing == null ? _seconds(defaultEnd) : _seconds(existing.endMilliseconds),
    );
    String? error;
    ManualMusicCue? result;
    try {
      result = await showDialog<ManualMusicCue>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(existing == null ? 'Add manual music cue' : 'Edit music cue'),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: text,
                  autofocus: true,
                  maxLength: 1000,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Lyrics or section note',
                    hintText: 'Type the words or name an instrumental section',
                  ),
                ),
                Row(children: [
                  Expanded(child: TextField(
                    controller: start,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Start (seconds)'),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(
                    controller: end,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'End (seconds)'),
                  )),
                ]),
                if (_songDuration != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Loaded song length: ${_cueClock(_songDuration!.inMilliseconds)}'),
                  ),
                if (error != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  final startMs = _milliseconds(start.text);
                  final endMs = _milliseconds(end.text);
                  if (startMs == null || endMs == null || endMs <= startMs) {
                    setDialogState(() => error = 'Enter a start and a later end time in seconds.');
                    return;
                  }
                  if (_songDuration != null && endMs > _songDuration!.inMilliseconds) {
                    setDialogState(() => error = 'The cue must end within the loaded song.');
                    return;
                  }
                  final cueText = text.text.trim();
                  if (cueText.isEmpty || cueText.length > 1000) {
                    setDialogState(() => error = 'Add a short lyric or section note.');
                    return;
                  }
                  Navigator.pop(dialogContext, ManualMusicCue(
                    startMilliseconds: startMs,
                    endMilliseconds: endMs,
                    text: cueText,
                  ));
                },
                child: Text(existing == null ? 'Add cue' : 'Save cue'),
              ),
            ],
          ),
        ),
      );
    } finally {
      // The dialog route is removed on a later frame than Navigator.pop.
      await WidgetsBinding.instance.endOfFrame;
      text.dispose();
      start.dispose();
      end.dispose();
    }
    if (result == null || !mounted) return;
    setState(() {
      if (index == null) {
        manualCues = [...manualCues, result!]
          ..sort((a, b) => a.startMilliseconds.compareTo(b.startMilliseconds));
      } else if (index >= 0 && index < manualCues.length) {
        manualCues[index] = result!;
        manualCues.sort((a, b) => a.startMilliseconds.compareTo(b.startMilliseconds));
      }
    });
  }

  void removeManualCue(int index) {
    if (index < 0 || index >= manualCues.length) return;
    setState(() => manualCues.removeAt(index));
  }

  static int? _milliseconds(String value) {
    final seconds = double.tryParse(value.trim());
    if (seconds == null || !seconds.isFinite || seconds < 0 || seconds > 86400) return null;
    return (seconds * 1000).round();
  }

  static String _seconds(int milliseconds) => (milliseconds / 1000)
      .toStringAsFixed(3)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');

  static String _cueClock(int milliseconds) {
    final seconds = milliseconds ~/ 1000;
    final remainder = (milliseconds % 1000).toString().padLeft(3, '0');
    return '${MusicStoryboardTimeline.clock(seconds)}.$remainder';
  }

  @override
  Widget build(BuildContext context) {
    final projects = widget.store.projects;
    if (!projects.any((p) => p.id == projectId)) {
      _selectProject(projects.isEmpty ? null : projects.first.id);
    }
    final avatars = ['None', ...widget.store.avatars.map((a) => a.name)];
    if (!avatars.contains(selectedAvatar)) selectedAvatar = 'None';
    final matches = widget.store.avatars.where((a) => a.name == selectedAvatar);
    final avatar = matches.isEmpty ? null : matches.first;
    final cues = MusicStoryboardTimeline.arrange(shots);
    final sceneCues = MusicStoryboardTimeline.matchManualCues(shots, manualCues);
    final totalSeconds = cues.isEmpty ? 0 : cues.last.endSeconds;
    return PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageTitle(
            eyebrow: 'Music video workflow',
            title: 'Music Video Studio',
            subtitle: 'Plan the story, arrange shots, and shape the visual direction.',
          ),
          const DemoNotice(
            'Offline UI preview. You can listen to a song on this device and add manual cues. Cloud upload, automatic lyric timing, beat detection, script AI, lip-sync and final video export require later integrations.',
          ),
          const SizedBox(height: 17),
          LayoutBuilder(builder: (context, size) {
            final wide = size.maxWidth > 820;
            final setup = StudioPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Start a music video', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 7),
                  const Text('Only your story description is needed for this preview.'),
                  const SizedBox(height: 17),
                  DropdownButtonFormField<String>(
                    key: ValueKey(projectId),
                    initialValue: projectId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Project'),
                    items: [
                      for (final item in projects)
                        DropdownMenuItem(value: item.id,
                            child: Text(item.title, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (value) => setState(() => _selectProject(value)),
                  ),
                  const SizedBox(height: 13),
                  TextField(
                    controller: story,
                    minLines: 4,
                    maxLines: 7,
                    maxLength: 1200,
                    decoration: const InputDecoration(
                      labelText: 'Describe your music video',
                      hintText: 'A mysterious journey through a rainy city, with a recurring hero...',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Visual direction', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final item in styles)
                        ChoiceChip(
                          label: Text(item),
                          selected: selectedStyle == item,
                          onSelected: (_) => setState(() => selectedStyle = item),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey('music-avatar-$projectId'),
                    initialValue: selectedAvatar,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Recurring character (optional)',
                    ),
                    items: [
                      for (final name in avatars)
                        DropdownMenuItem(value: name,
                            child: Text(name, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => selectedAvatar = value);
                    },
                  ),
                  if (avatar != null) ...[
                    const SizedBox(height: 7),
                    Text('Character guide: ' + AvatarPromptComposer.identityCard(avatar),
                        maxLines: 3, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12)),
                  ],
                  const SizedBox(height: 17),
                  PrimaryButton(
                    label: 'Preview storyboard',
                    icon: Icons.auto_stories_rounded,
                    onPressed: draftStoryboard,
                  ),
                ],
              ),
            );
            final audio = MusicSongPreviewPanel(
              key: ValueKey('song-preview-$projectId'),
              active: widget.audioActive,
              onDurationChanged: (duration) {
                if (mounted) setState(() => _songDuration = duration);
              },
            );
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: setup),
                  const SizedBox(width: 16),
                  Expanded(flex: 4, child: audio),
                ],
              );
            }
            return Column(children: [setup, const SizedBox(height: 14), audio]);
          }),
          const SizedBox(height: 24),
          Text('Storyboard timeline', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 7),
          const Text('Edit scene durations (4–10 s). Positions are manual estimates, not beat or lyric sync.'),
          const SizedBox(height: 6),
          Text('Estimated runtime: ${MusicStoryboardTimeline.clock(totalSeconds)}',
              style: Theme.of(context).textTheme.titleSmall),
          if (shots.isNotEmpty && manualCues.any((cue) =>
              cue.endMilliseconds > totalSeconds * 1000))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Some manual cues fall outside the current estimated scene timeline.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 14),
          if (shots.isEmpty)
            const StudioPanel(
              child: Text('Your shot list appears here after you preview a story.'),
            ),
          for (var i = 0; i < shots.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: StudioPanel(
                padding: const EdgeInsets.all(13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 17,
                          child: Text((i + 1).toString()),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(shots[i].title,
                              style: Theme.of(context).textTheme.titleMedium),
                        ),
                        Text(
                          '${MusicStoryboardTimeline.clock(cues[i].startSeconds)}–${MusicStoryboardTimeline.clock(cues[i].endSeconds)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(shots[i].description),
                    if (sceneCues[i].isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Manual cue overlap', style: Theme.of(context).textTheme.labelMedium),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final cue in sceneCues[i])
                            Chip(
                              avatar: const Icon(Icons.lyrics_outlined, size: 16),
                              label: Text(
                                '${_cueClock(cue.startMilliseconds)} · '
                                '${cue.text}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      children: [
                        const Icon(Icons.timer_outlined, size: 17),
                        const Text('Scene seconds:'),
                        DropdownButton<int>(
                          key: ValueKey('music-shot-duration-$i'),
                          value: const [4, 5, 6, 7, 8, 9, 10]
                                  .contains(shots[i].estimatedSeconds)
                              ? shots[i].estimatedSeconds
                              : null,
                          hint: Text('${shots[i].estimatedSeconds}'),
                          items: [
                            for (var seconds = 4; seconds <= 10; seconds++)
                              DropdownMenuItem(value: seconds, child: Text('$seconds')),
                          ],
                          onChanged: (value) {
                            if (value != null) setShotDuration(i, value);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 5,
                      children: [
                        TextButton.icon(
                          onPressed: () => editShot(i),
                          icon: const Icon(Icons.edit_outlined, size: 17),
                          label: const Text('Edit'),
                        ),
                        IconButton(
                          tooltip: 'Move earlier',
                          onPressed: i == 0 ? null : () => moveShot(i, -1),
                          icon: const Icon(Icons.arrow_upward_rounded),
                        ),
                        IconButton(
                          tooltip: 'Move later',
                          onPressed: i == shots.length - 1
                              ? null : () => moveShot(i, 1),
                          icon: const Icon(Icons.arrow_downward_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (shots.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Manual lyric & section cues',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text('Set timestamps yourself while listening. HOTICE has not transcribed the song or detected its beats.'),
            if (_songDuration != null && manualCues.any((cue) =>
                cue.endMilliseconds > _songDuration!.inMilliseconds))
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Some cues extend beyond this song. Edit their times or choose a longer track.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const ValueKey('add-manual-music-cue'),
              onPressed: manualCues.length >= 500 ? null : () => editManualCue(),
              icon: const Icon(Icons.add_rounded),
              label: Text(manualCues.length >= 500 ? 'Cue limit reached' : 'Add timed cue'),
            ),
            if (manualCues.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('No manual lyric or section cues yet.'),
              ),
            for (var cueIndex = 0; cueIndex < manualCues.length; cueIndex++)
              StudioPanel(
                key: ValueKey('manual-music-cue-$cueIndex'),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(manualCues[cueIndex].text),
                  subtitle: Text(
                    '${_cueClock(manualCues[cueIndex].startMilliseconds)}–'
                    '${_cueClock(manualCues[cueIndex].endMilliseconds)} · manual timing',
                  ),
                  trailing: Wrap(spacing: 0, children: [
                    IconButton(
                      tooltip: 'Edit cue ${cueIndex + 1}',
                      onPressed: () => editManualCue(index: cueIndex),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Remove cue ${cueIndex + 1}',
                      onPressed: () => removeManualCue(cueIndex),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ]),
                ),
              ),
            const SizedBox(height: 10),
            PrimaryButton(
              label: 'Save storyboard draft',
              icon: Icons.save_alt_rounded,
              onPressed: savePlan,
            ),
          ],
          const SizedBox(height: 22),
          Text('Saved music storyboards · this session', style: Theme.of(context).textTheme.titleLarge),
          if (!widget.store.musicPlans.any((plan) => plan.projectId == projectId))
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('No saved music video plans yet.'),
            ),
          for (final plan in widget.store.musicPlans
              .where((plan) => plan.projectId == projectId).take(5))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.queue_music_rounded),
              title: Text(plan.storyBrief, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(plan.visualStyle + ' · ' +
                  plan.shots.length.toString() + ' editable scene ideas'),
              trailing: const Icon(Icons.edit_note_outlined),
              onTap: () => loadSavedPlan(plan),
            ),
        ],
      ),
    );
  }
}
