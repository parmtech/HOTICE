import 'package:flutter/material.dart';

import 'account_api.dart';

import 'package:file_picker/file_picker.dart';

import 'smart_references.dart';
import 'state.dart';
import 'video_models.dart';
import 'model_compatibility_page.dart';
import 'model_registry.dart';
import 'api_model_preview_panel.dart';
import 'avatar_identity.dart';
import 'design.dart';
import 'dialogs.dart';
import 'inspiration_catalog.dart';
import 'scene_controls.dart';

class ProjectsPage extends StatelessWidget {
  final HotIceStore store;
  final ValueChanged<String> onOpen;
  const ProjectsPage({super.key, required this.store, required this.onOpen});

  Future<void> add(BuildContext context) async {
    final title = await showHotIceTextDialog(
      context,
      title: 'New film project',
      label: 'Project title',
      confirmLabel: 'Create',
      maxLength: 60,
    );
    if (!context.mounted) return;
    if (title != null && title.trim().isNotEmpty) {
      onOpen(store.addProject(title));
    }
  }

  Future<void> rename(BuildContext context, HotProject project) async {
    final title = await showHotIceTextDialog(
      context,
      title: 'Rename project',
      label: 'Project title',
      confirmLabel: 'Save name',
      initialValue: project.title,
      maxLength: 60,
    );
    if (!context.mounted || title == null) return;
    if (!store.renameProject(project.id, title)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project could not be renamed.')),
      );
    }
  }

  Future<void> delete(BuildContext context, HotProject project) async {
    if (store.pendingMockSubmissionsFor(project.id).isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Resolve the pending mock request before deleting this project.',
          ),
        ),
      );
      return;
    }
    final draftCount =
        store.drafts.where((draft) => draft.projectId == project.id).length;
    final planCount =
        store.musicPlans.where((plan) => plan.projectId == project.id).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete project?'),
        content: Text(
          'Delete "${project.title}" and its $draftCount saved scene drafts '
          'and $planCount storyboards from this device? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete project'),
          ),
        ],
      ),
    );
    if (!context.mounted || confirmed != true) return;
    if (!store.deleteProject(project.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project no longer exists.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageTitle(
            eyebrow: 'Your workspace',
            title: 'Projects',
            subtitle: 'Every great film begins with an idea. Shape yours here.',
          ),
          PrimaryButton(
            label: 'New project',
            icon: Icons.add,
            onPressed: () => add(context),
          ),
          const SizedBox(height: 16),
          const DemoNotice(
            'Projects and scene plans are kept in encrypted device storage. '
            'Optional cloud copies need sign-in and your consent. Source media '
            'stays on this device unless a separate upload flow is offered.',
          ),
          const SizedBox(height: 22),
          if (store.projects.isEmpty)
            StudioPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.movie_creation_outlined,
                    size: 36,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your next film starts here',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Create a project to plan scenes or a music video.',
                  ),
                ],
              ),
            ),
          LayoutBuilder(
            builder: (context, box) {
              final columns = box.maxWidth > 810
                  ? 3
                  : box.maxWidth > 520
                      ? 2
                      : 1;
              final width = ((box.maxWidth - (columns - 1) * 14) / columns)
                  .clamp(0.0, 1160.0);
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (final project in store.projects)
                    SizedBox(
                      width: width,
                      child: StudioPanel(
                        padding: EdgeInsets.zero,
                        // InkWell must be INSIDE the StudioPanel Material surface
                        // for visible feedback and correct Material ancestry.
                        child: InkWell(
                          onTap: () => onOpen(project.id),
                          borderRadius: BorderRadius.circular(23),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                FilmPreview(title: project.title),
                                const SizedBox(height: 12),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final title = Text(
                                      project.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    );
                                    final menu = PopupMenuButton<String>(
                                      key: ValueKey(
                                        'project-options-${project.id}',
                                      ),
                                      tooltip: 'Project options',
                                      icon: const Icon(Icons.more_vert_rounded),
                                      onSelected: (action) async {
                                        if (action == 'rename')
                                          await rename(context, project);
                                        if (action == 'delete')
                                          await delete(context, project);
                                      },
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(
                                          value: 'rename',
                                          child: Text('Rename'),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Delete'),
                                        ),
                                      ],
                                    );
                                    if (constraints.maxWidth < 64) {
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [title, menu],
                                      );
                                    }
                                    return Row(
                                      children: [
                                        Expanded(child: title),
                                        menu,
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${store.drafts.where((item) => item.projectId == project.id).length} '
                                  'scene drafts · ${store.musicPlans.where((item) => item.projectId == project.id).length} '
                                  'storyboards',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Open project →',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class GenerationPage extends StatefulWidget {
  final HotIceStore store;
  final AccountApi? accountApi;
  final String? authenticatedEmail;
  final String? authenticatedUserId;
  final String? initialProjectId;
  final InspirationTemplate? initialTemplate;
  final int templateRevision;
  const GenerationPage({
    super.key,
    required this.store,
    this.accountApi,
    this.authenticatedEmail,
    this.authenticatedUserId,
    this.initialProjectId,
    this.initialTemplate,
    this.templateRevision = 0,
  });
  @override
  State<GenerationPage> createState() => _GenerationPageState();
}

class _GenerationPageState extends State<GenerationPage> {
  final prompt = TextEditingController();
  // Each in-progress scene belongs to one film project in this demo session.
  final Map<String, String> _unsavedPrompts = {};
  final Map<String, String> _unsavedModels = {};
  final Map<String, String> _unsavedRatios = {};
  final Map<String, int> _unsavedDurations = {};
  final Map<String, String> _unsavedAvatars = {};
  final Map<String, List<SceneActor>> _unsavedActors = {};
  final Map<String, List<SceneReference>> _unsavedReferences = {};
  final Map<String, String> _unsavedNegativePrompts = {};
  final Map<String, String> _unsavedSeeds = {};
  final Map<String, bool> _unsavedSounds = {};
  final Map<String, bool> _manualReferencesByProject = {};
  final Map<String, Set<String>> _pinnedReferencesByProject = {};
  final Map<String, FaceView?> _preferredViewsByProject = {};
  String? project;
  String model = 'cinematic_demo';
  String avatarName = 'None';

  VideoModelProfile get profile => demoModelById(model);
  String ratio = '16:9';
  int seconds = 8;
  final List<SceneActor> sceneActors = [];
  final List<SceneReference> references = [];
  final negativePrompt = TextEditingController();
  final seedText = TextEditingController();
  bool soundEnabled = false;
  bool advancedOpen = false;
  InspirationTemplate? selectedTemplate;
  MockGenerationAvailability? _mockAvailability;
  MockGenerationQuote? _mockQuote;
  String? _quotedPrompt;
  String? _quotedIntentKey;
  String? _mockStatus;
  bool _checkingMockAvailability = false;
  bool _loadingMockJobs = false;
  bool _submittingMockJob = false;
  List<MockGenerationJob> _mockJobs = const [];

  @override
  void initState() {
    super.initState();
    project = widget.initialProjectId ??
        (widget.store.projects.isEmpty ? null : widget.store.projects.first.id);
    if (widget.initialTemplate != null) _applyTemplate(widget.initialTemplate!);
    prompt.addListener(_invalidateStaleMockQuote);
  }

  void _invalidateMockQuote() {
    if (_mockQuote == null && _quotedPrompt == null) return;
    _mockQuote = null;
    _quotedPrompt = null;
    _quotedIntentKey = null;
  }

  void _invalidateStaleMockQuote() {
    if (_mockQuote != null &&
        _quotedIntentKey == null &&
        _quotedPrompt != prompt.text.trim()) {
      setState(_invalidateMockQuote);
    }
  }

  Future<void> _checkMockGenerationAvailability() async {
    final api = widget.accountApi;
    if (api == null || !api.isConfigured || widget.authenticatedEmail == null) {
      setState(
        () => _mockStatus =
            'Sign in to a configured HOTICE server to check dry-run availability.',
      );
      return;
    }
    setState(() {
      _checkingMockAvailability = true;
      _mockStatus = 'Checking whether this HOTICE server allows mock dry runs…';
    });
    try {
      final availability = await api.getMockGenerationAvailability();
      if (!mounted) return;
      setState(() {
        _mockAvailability = availability;
        _mockStatus = availability.enabled
            ? 'Server mock queue is available. It creates job metadata only; no video or provider call.'
            : 'Mock generation is disabled on this server. Your local project is unchanged.';
      });
    } on AccountApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _mockAvailability = null;
        _mockStatus = error.statusCode == 401 || error.statusCode == 403
            ? 'Your secure account session is unavailable. Sign in again to check the mock queue.'
            : 'Could not check the server. Your prompt and local project remain on this device.';
      });
    } finally {
      if (mounted) setState(() => _checkingMockAvailability = false);
    }
  }

  Future<void> _requestMockQuote({PendingMockSubmission? pending}) async {
    final api = widget.accountApi;
    final userId = widget.authenticatedUserId;
    if (api == null || widget.authenticatedEmail == null || userId == null) {
      return;
    }
    if (pending != null && pending.accountUserId != userId) {
      setState(
        () => _mockStatus =
            'This safe retry belongs to another HOTICE account. Sign in to that account before resuming it.',
      );
      return;
    }
    final text = pending?.prompt ?? prompt.text.trim();
    final projectId = pending?.projectId ?? project;
    if (projectId == null || !isCloudProjectId(projectId)) {
      setState(
        () => _mockStatus =
            'Create a personal project before starting a server dry run.',
      );
      return;
    }
    if (text.isEmpty || text.length > 2000) {
      setState(
        () => _mockStatus =
            'Enter a scene prompt between 1 and 2,000 characters.',
      );
      return;
    }
    setState(() {
      _mockQuote = null;
      _quotedPrompt = null;
      _quotedIntentKey = null;
      _checkingMockAvailability = true;
      _mockStatus =
          'Requesting a simulated-credit quote. Only this scene text is sent.';
    });
    try {
      final availability =
          _mockAvailability ?? await api.getMockGenerationAvailability();
      if (!mounted) return;
      if (!availability.enabled) {
        setState(() {
          _mockAvailability = availability;
          _mockStatus =
              'Mock generation is disabled on this server. No job was submitted.';
        });
        return;
      }
      final quote = await api.quoteMockGeneration(text);
      if (!mounted) return;
      setState(() {
        _mockAvailability = availability;
        _mockQuote = quote;
        _quotedPrompt = text;
        _quotedIntentKey = pending?.idempotencyKey;
        _mockStatus =
            'Quote: ${quote.credits} simulated credits. No money is charged and no video is rendered.';
      });
    } on AccountApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _mockStatus = error.statusCode == 503
            ? 'Mock generation is disabled on this server.'
            : 'Could not get a quote. Your scene remains local; check the connection and try again.';
      });
    } finally {
      if (mounted) setState(() => _checkingMockAvailability = false);
    }
  }

  Future<void> _startMockJob() async {
    final api = widget.accountApi;
    final quote = _mockQuote;
    final text = _quotedPrompt;
    if (api == null || quote == null || text == null || _submittingMockJob)
      return;
    if (_quotedIntentKey == null &&
        (project == null || text != prompt.text.trim())) {
      setState(() {
        _invalidateMockQuote();
        _mockStatus =
            'The scene text or selected project changed. Request a fresh quote.';
      });
      return;
    }
    if (!quote.expiresAt.isAfter(DateTime.now())) {
      setState(() {
        _invalidateMockQuote();
        _mockStatus =
            'This quote expired. Request a fresh quote before submitting.';
      });
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Start this mock dry run?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Only the scene text below will be sent to the HOTICE server. '
                'Actor identity notes, reference files, media, model preview settings, '
                'duration and aspect ratio are excluded.',
              ),
              const SizedBox(height: 12),
              SelectableText(text),
              const SizedBox(height: 12),
              Text(
                '${quote.credits} simulated credits. No money is charged; no video is created.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep local'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm mock dry run'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    PendingMockSubmission? intent;
    try {
      if (widget.authenticatedUserId == null) {
        setState(
          () => _mockStatus =
              'The authenticated account could not be verified. Sign in again before submitting.',
        );
        return;
      }
      if (_quotedIntentKey != null) {
        final pending = widget.store.pendingMockSubmissions.where(
          (item) => item.idempotencyKey == _quotedIntentKey,
        );
        intent = pending.isEmpty ? null : pending.first;
        if (intent == null) {
          setState(
            () => _mockStatus =
                'The saved retry intent is no longer available. Keep this project and refresh its state.',
          );
          return;
        }
        if (intent.accountUserId != widget.authenticatedUserId) {
          setState(
            () => _mockStatus =
                'This safe retry belongs to another HOTICE account. Sign in to that account before resuming it.',
          );
          return;
        }
      } else {
        final projectId = project;
        if (projectId == null) return;
        intent = PendingMockSubmission(
          idempotencyKey: createLocalProjectId(),
          accountUserId: widget.authenticatedUserId!,
          projectId: projectId,
          prompt: text,
          createdAt: DateTime.now().toUtc(),
        );
        // Persist the stable idempotency key before the network call. A timeout
        // can then be safely retried after app restart without double reserve.
        widget.store.savePendingMockSubmission(intent);
      }
    } on StateError catch (error) {
      setState(() => _mockStatus = error.message);
      return;
    }

    setState(() {
      _submittingMockJob = true;
      _mockStatus =
          'Submitting the confirmed mock job. The server will not call a video provider.';
    });
    try {
      final job = await api.submitMockGeneration(
        quoteToken: quote.token,
        prompt: intent.prompt,
        idempotencyKey: intent.idempotencyKey,
      );
      widget.store.removePendingMockSubmission(intent.idempotencyKey);
      if (!mounted) return;
      setState(() {
        _invalidateMockQuote();
        _mockStatus =
            'Mock job ${job.status}. It is queue metadata only; no media was created.';
        _mockAvailability = _mockAvailability == null
            ? null
            : MockGenerationAvailability(
                enabled: _mockAvailability!.enabled,
                credits: _mockAvailability!.credits == null
                    ? null
                    : (_mockAvailability!.credits! - job.reservedCredits).clamp(
                        0,
                        1 << 30,
                      ),
              );
      });
      await _refreshMockJobs(silent: true);
    } on AccountApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _mockStatus = error.statusCode == 402
            ? 'Not enough simulated credits. No money was charged. The safe retry is saved on this device.'
            : error.statusCode == 409
                ? 'The server rejected this quote or found a conflict. Your retry intent is retained; request a fresh quote to retry safely.'
                : 'The server could not confirm the request. The same retry ID is saved locally to prevent a duplicate reservation.';
      });
    } finally {
      if (mounted) setState(() => _submittingMockJob = false);
    }
  }

  Future<void> _refreshMockJobs({bool silent = false}) async {
    final api = widget.accountApi;
    if (api == null || widget.authenticatedEmail == null || _loadingMockJobs)
      return;
    setState(() {
      _loadingMockJobs = true;
      if (!silent) _mockStatus = 'Refreshing your server job history…';
    });
    try {
      final jobs = await api.listMockGenerationJobs();
      if (!mounted) return;
      setState(() {
        _mockJobs = jobs;
        if (!silent)
          _mockStatus =
              'Job history refreshed. Results are mock metadata; no video was generated.';
      });
    } on AccountApiException {
      if (!mounted) return;
      if (!silent) {
        setState(
          () => _mockStatus =
              'Could not refresh jobs. Your local project and pending retry intents are unchanged.',
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMockJobs = false);
    }
  }

  Future<void> _cancelMockJob(MockGenerationJob job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel queued mock job?'),
        content: Text(
          'This cancels only a queued dry-run record and returns its ${job.reservedCredits} simulated credits. No video or provider request exists.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep job'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel queued job'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || widget.accountApi == null) return;
    try {
      final updated = await widget.accountApi!.cancelMockGenerationJob(job.id);
      if (!mounted) return;
      setState(() {
        _mockJobs = [
          for (final current in _mockJobs)
            current.id == updated.id ? updated : current,
        ];
        _mockStatus = updated.status == 'cancelled'
            ? 'Queued mock job cancelled; simulated credits were returned.'
            : 'The server did not cancel this job. Refresh its status.';
      });
    } on AccountApiException catch (error) {
      if (mounted) {
        setState(
          () => _mockStatus = error.statusCode == 409
              ? 'This job is no longer queued and cannot be cancelled.'
              : 'Could not cancel the job. Refresh its status.',
        );
      }
    }
  }

  Widget _mockGenerationPanel() {
    final api = widget.accountApi;
    final signedIn =
        widget.authenticatedEmail != null && widget.authenticatedUserId != null;
    final configured = api?.isConfigured == true;
    final projectId = project;
    final personalProject = projectId != null && isCloudProjectId(projectId);
    final allPending = personalProject
        ? widget.store.pendingMockSubmissionsFor(projectId)
        : const <PendingMockSubmission>[];
    final pending = allPending
        .where((item) => item.accountUserId == widget.authenticatedUserId)
        .toList(growable: false);
    final hasOtherAccountIntent = allPending.any(
      (item) => item.accountUserId != widget.authenticatedUserId,
    );
    final canQuote = signedIn &&
        configured &&
        personalProject &&
        !hasOtherAccountIntent &&
        _mockAvailability?.enabled == true &&
        prompt.text.trim().isNotEmpty &&
        !_checkingMockAvailability &&
        !_submittingMockJob;

    return StudioPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Backend dry-run workflow',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          const Text(
            'Mock queue only. It does not generate video or call a paid AI provider. '
            'A quote request sends only the scene text below; Actor details, reference files, '
            'media, selected model preview, duration and aspect ratio are excluded.',
          ),
          const SizedBox(height: 10),
          if (!signedIn)
            const Text(
              'Sign in to a HOTICE account to check this server workflow.',
            ),
          if (signedIn && !configured)
            const Text(
              'This build has no secure HOTICE service URL configured.',
            ),
          if (hasOtherAccountIntent)
            const Text(
              'A pending safe retry is tied to another HOTICE account. Sign in as that account to resolve it before starting a new request.',
            ),
          if (signedIn && configured) ...[
            OutlinedButton.icon(
              onPressed: _checkingMockAvailability || _submittingMockJob
                  ? null
                  : _checkMockGenerationAvailability,
              icon: _checkingMockAvailability
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_done_outlined),
              label: const Text('Check mock queue availability'),
            ),
            if (_mockAvailability?.enabled == true &&
                _mockAvailability?.credits != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Simulated credit balance: ${_mockAvailability!.credits}. This has no cash value.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: canQuote ? () => _requestMockQuote() : null,
              icon: const Icon(Icons.request_quote_outlined),
              label: const Text('Request simulated-credit quote'),
            ),
            if (_mockQuote != null) ...[
              const SizedBox(height: 8),
              Text(
                '${_mockQuote!.credits} simulated credits · expires ${_mockQuote!.expiresAt.toLocal()}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              FilledButton.icon(
                onPressed: _submittingMockJob ? null : _startMockJob,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Review and start mock dry run'),
              ),
            ],
            if (pending.isNotEmpty) ...[
              const Divider(height: 24),
              Text(
                'Safe retries waiting on this device',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              const Text(
                'An earlier request may have reached the server before the connection ended. '
                'Retry keeps the same encrypted local request ID, so the server can return the '
                'existing job instead of reserving simulated credits twice.',
              ),
              for (final intent in pending.take(3))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    intent.prompt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text('Saved ${intent.createdAt.toLocal()}'),
                  trailing: TextButton(
                    onPressed: _checkingMockAvailability || _submittingMockJob
                        ? null
                        : () => _requestMockQuote(pending: intent),
                    child: const Text('Quote & retry'),
                  ),
                ),
            ],
            const Divider(height: 24),
            OutlinedButton.icon(
              onPressed: _loadingMockJobs || _submittingMockJob
                  ? null
                  : () => _refreshMockJobs(),
              icon: _loadingMockJobs
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
              label: const Text('Refresh my mock jobs'),
            ),
            for (final job in _mockJobs.take(10)) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  job.status == 'succeeded'
                      ? Icons.check_circle_outline
                      : job.status == 'failed'
                          ? Icons.error_outline
                          : job.status == 'cancelled'
                              ? Icons.cancel_outlined
                              : Icons.pending_outlined,
                ),
                title: Text('Mock job · ${job.status}'),
                subtitle: Text(
                  job.result != null
                      ? 'Mock result metadata only. No video was created.'
                      : job.errorCode == 'provider_outcome_unknown'
                          ? 'Outcome needs server reconciliation; reserved simulated credits stay protected.'
                          : '${job.reservedCredits} simulated credits reserved · no video is created.',
                ),
                trailing: job.status == 'queued'
                    ? IconButton(
                        tooltip: 'Cancel queued mock job',
                        onPressed: _submittingMockJob
                            ? null
                            : () => _cancelMockJob(job),
                        icon: const Icon(Icons.close_rounded),
                      )
                    : null,
              ),
            ],
          ],
          if (_mockStatus != null) ...[
            const SizedBox(height: 6),
            Semantics(liveRegion: true, child: Text(_mockStatus!)),
          ],
        ],
      ),
    );
  }

  void _applyTemplate(InspirationTemplate entry) {
    selectedTemplate = entry;
    prompt.text = entry.prompt;
    model = entry.modelId;
    // Switching template replaces the previous cast/settings rather than
    // silently carrying unsupported references to the next model.
    sceneActors.clear();
    references.clear();
    avatarName = 'None';
    negativePrompt.clear();
    seedText.clear();
    soundEnabled = false;
    final capabilities = demoModelById(model);
    if (!capabilities.durations.contains(seconds)) {
      seconds = capabilities.durations.first;
    }
    if (!capabilities.ratiosFor(seconds).contains(ratio)) {
      ratio = capabilities.ratiosFor(seconds).first;
    }
  }

  void _selectProject(String? next) {
    if (project == next) return;
    if (project != null) {
      final current = project!;
      _unsavedPrompts[current] = prompt.text;
      _unsavedModels[current] = model;
      _unsavedRatios[current] = ratio;
      _unsavedDurations[current] = seconds;
      _unsavedAvatars[current] = avatarName;
      _unsavedActors[current] = List<SceneActor>.of(sceneActors);
      _unsavedReferences[current] = List<SceneReference>.of(references);
      _unsavedNegativePrompts[current] = negativePrompt.text;
      _unsavedSeeds[current] = seedText.text;
      _unsavedSounds[current] = soundEnabled;
    }
    _invalidateMockQuote();
    project = next;
    prompt.text = next == null ? '' : (_unsavedPrompts[next] ?? '');
    final savedModel = next == null ? null : _unsavedModels[next];
    model = demoVideoModels.any((candidate) => candidate.id == savedModel)
        ? savedModel!
        : 'cinematic_demo';
    final chosen = demoModelById(model);
    final savedDuration = next == null ? null : _unsavedDurations[next];
    seconds = savedDuration != null && chosen.durations.contains(savedDuration)
        ? savedDuration
        : (chosen.durations.contains(8) ? 8 : chosen.durations.first);
    final savedRatio = next == null ? null : _unsavedRatios[next];
    ratio = savedRatio != null && chosen.ratiosFor(seconds).contains(savedRatio)
        ? savedRatio
        : chosen.ratiosFor(seconds).first;
    avatarName = next == null ? 'None' : (_unsavedAvatars[next] ?? 'None');
    if (avatarName != 'None' &&
        !widget.store.avatars.any((actor) => actor.name == avatarName)) {
      avatarName = 'None';
    }
    sceneActors
      ..clear()
      ..addAll(
        next == null
            ? const <SceneActor>[]
            : (_unsavedActors[next] ?? const <SceneActor>[]),
      );
    references
      ..clear()
      ..addAll(
        next == null
            ? const <SceneReference>[]
            : (_unsavedReferences[next] ?? const <SceneReference>[]),
      );
    sceneActors.removeWhere(
      (cast) =>
          !widget.store.avatars.any((actor) => actor.name == cast.avatarName),
    );
    references.removeWhere(
      (reference) => chosen.maximumFor(reference.type) == 0,
    );
    negativePrompt.text =
        next == null ? '' : (_unsavedNegativePrompts[next] ?? '');
    seedText.text = next == null ? '' : (_unsavedSeeds[next] ?? '');
    soundEnabled = next == null ? false : (_unsavedSounds[next] ?? false);
    selectedTemplate = null;
  }

  @override
  void didUpdateWidget(covariant GenerationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialProjectId != null &&
        widget.initialProjectId != oldWidget.initialProjectId) {
      _selectProject(widget.initialProjectId);
    }
    if (widget.initialTemplate != null &&
        widget.templateRevision != oldWidget.templateRevision) {
      _applyTemplate(widget.initialTemplate!);
    }
  }

  @override
  void dispose() {
    prompt.removeListener(_invalidateStaleMockQuote);
    prompt.dispose();
    negativePrompt.dispose();
    seedText.dispose();
    super.dispose();
  }

  void changeModel(String nextId) {
    final next = demoModelById(nextId);
    setState(() {
      model = next.id;
      if (!next.durations.contains(seconds)) seconds = next.durations.first;
      if (!next.ratiosFor(seconds).contains(ratio)) {
        ratio = next.ratiosFor(seconds).first;
      }
      sceneActors.removeRange(
        sceneActors.length > next.maxActors
            ? next.maxActors
            : sceneActors.length,
        sceneActors.length,
      );
      references.removeWhere((ref) => next.maximumFor(ref.type) == 0);
      for (final type in VideoAttachment.values) {
        var used = 0;
        references.removeWhere((ref) {
          if (ref.type != type) return false;
          used++;
          return used > next.maximumFor(type);
        });
      }
      if (!next.supportsNegativePrompt) negativePrompt.clear();
      if (!next.supportsSeed) seedText.clear();
      if (!next.supportsSound) soundEnabled = false;
    });
  }

  void changeDuration(int value) {
    setState(() {
      seconds = value;
      if (!profile.ratiosFor(seconds).contains(ratio)) {
        ratio = profile.ratiosFor(seconds).first;
      }
    });
  }

  ReferenceSelection _referenceSelection() {
    final avatarPack = avatarName == 'None' ||
            !widget.store.avatars.any((a) => a.name == avatarName)
        ? null
        : widget.store.avatarPackFor(avatarName);
    final projectId = project;
    return SmartReferencePlanner.plan(
      avatarPack: avatarPack,
      sceneAssets: projectId == null
          ? const <AvatarReference>[]
          : widget.store.sceneReferencesFor(projectId),
      model: ReferenceModelCapability.demo(profile),
      scenePrompt: prompt.text,
      preferredView:
          projectId == null ? null : _preferredViewsByProject[projectId],
      autoSelect: projectId == null ||
          !(_manualReferencesByProject[projectId] ?? false),
      lockedIds: projectId == null
          ? const <String>[]
          : (_pinnedReferencesByProject[projectId] ?? const <String>{}),
    );
  }

  Future<void> importScenePhoto(ReferenceRole role) async {
    final owner = project;
    if (owner == null) return;
    try {
      final file = await FilePicker.pickFile(type: FileType.image);
      if (!mounted || file == null) return;
      final fileBytes = file.lengthSync() ?? await file.length();
      if (!mounted) return;
      final ext = (file.extension ?? '').toLowerCase();
      final mime = switch (ext) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => null,
      };
      if (mime == null ||
          file.path == null ||
          file.path!.isEmpty ||
          fileBytes == null ||
          fileBytes <= 0 ||
          fileBytes > 15 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Choose a JPG/PNG/WebP photo under 15 MB.'),
          ),
        );
        return;
      }
      final saved = widget.store.addSceneReference(
        owner,
        AvatarReference(
          id: createLocalProjectId(),
          ownerName: owner,
          role: role,
          format: ReferenceFormat.image,
          mimeType: mime,
          localPath: file.path!,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved
                ? '${role.name} reference added to this project session.'
                : 'Reference was not added (project or limit changed).',
          ),
        ),
      );
      setState(() {});
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image picker was cancelled or failed.')),
      );
    }
  }

  void save() {
    if (prompt.text.trim().isEmpty || project == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose a project and describe your scene.'),
        ),
      );
      return;
    }
    final matches = widget.store.projects.where((p) => p.id == project);
    if (matches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project not found. Choose another.')),
      );
      return;
    }
    final types = references.map((f) => f.type);
    if (!profile.accepts(seconds: seconds, ratio: ratio, inputs: types) ||
        sceneActors.length > profile.maxActors) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your actors or reference files exceed this model limit.',
          ),
        ),
      );
      return;
    }

    int? seed;
    if (seedText.text.trim().isNotEmpty) {
      seed = int.tryParse(seedText.text.trim());
      if (seed == null || seed < 0 || !profile.supportsSeed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter a valid non-negative seed for this model.'),
          ),
        );
        return;
      }
    }
    if (negativePrompt.text.trim().isNotEmpty &&
        !profile.supportsNegativePrompt) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Negative prompting is unavailable for this model.'),
        ),
      );
      return;
    }
    if (selectedTemplate != null &&
        selectedTemplate!.prompt == prompt.text &&
        sceneActors.length < selectedTemplate!.actorSlots.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Assign ${selectedTemplate!.actorSlots.length} named actors to use this template.',
          ),
        ),
      );
      return;
    }
    try {
      var source = prompt.text.trim();
      if (selectedTemplate != null && selectedTemplate!.prompt == source) {
        source = InspirationPromptBuilder.compile(
          selectedTemplate!,
          sceneActors,
        );
      }
      // Detect unresolved placeholders even when the user has edited the text.
      final roleTokens =
          RegExp(r'\{\{Actor[0-9]+\}\}').allMatches(source).toList();
      if (roleTokens.isNotEmpty) {
        if (sceneActors.length < roleTokens.length) {
          throw StateError('Assign the named actors before saving.');
        }
        final seen = <String>{};
        source = source.replaceAllMapped(RegExp(r'\{\{Actor[0-9]+\}\}'), (
          match,
        ) {
          final token = match.group(0)!;
          if (!seen.contains(token)) {
            seen.add(token);
          }
          final index = seen.toList().indexOf(token);
          return sceneActors[index].sceneName;
        });
      }
      final referencePlan = _referenceSelection();
      if (referencePlan.errors.isNotEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(referencePlan.errors.first)));
        return;
      }
      final selected = matches.first;
      final primaryActor = widget.store.avatars.where(
        (actor) => actor.name == avatarName,
      );
      final preparedPrompt = sceneActors.isNotEmpty
          ? AvatarPromptComposer.composeActors(
              scenePrompt: source,
              cast: List<SceneActor>.unmodifiable(sceneActors),
              library: widget.store.avatars,
              model: profile,
            )
          : AvatarPromptComposer.compose(
              scenePrompt: source,
              avatar: primaryActor.isEmpty ? null : primaryActor.first,
              model: profile,
            );
      widget.store.queueDraft(
        GenerationDraft(
          projectId: selected.id,
          modelId: profile.id,
          project: selected.title,
          prompt: preparedPrompt,
          model: profile.label,
          aspectRatio: ratio,
          durationSeconds: seconds,
          avatarName: avatarName,
          actors: List<SceneActor>.unmodifiable(sceneActors),
          referenceFiles: List<SceneReference>.unmodifiable(references),
          negativePrompt: negativePrompt.text.trim(),
          seed: seed,
          soundEnabled: soundEnabled,
          selectedReferenceIds: [
            for (final asset in referencePlan.selected) asset.id,
          ],
          requestedAttachments: referencePlan.imageCount > 0
              ? const [VideoAttachment.image]
              : const <VideoAttachment>[],
          createdAt: DateTime.now(),
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scene draft saved. No AI request sent.')),
      );
    } on StateError catch (error) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final validProjects = widget.store.projects;
    if (!validProjects.any((item) => item.id == project)) {
      _selectProject(validProjects.isEmpty ? null : validProjects.first.id);
    }

    // Remove stale cast entries if an actor preset was deleted.
    sceneActors.removeWhere(
      (cast) =>
          !widget.store.avatars.any((actor) => actor.name == cast.avatarName),
    );

    final avatars = [
      'None',
      for (final item in widget.store.avatars) item.name,
    ];
    if (!avatars.contains(avatarName)) avatarName = 'None';
    final currentPlan = _referenceSelection();
    final avatarAssets = avatarName == 'None'
        ? const <AvatarReference>[]
        : widget.store.avatarPackFor(avatarName).assets;
    final sceneAssets = project == null
        ? const <AvatarReference>[]
        : widget.store.sceneReferencesFor(project!);
    final allAssets = [...avatarAssets, ...sceneAssets];
    final manualMode =
        project != null && (_manualReferencesByProject[project!] ?? false);
    final pinned = project == null
        ? <String>{}
        : (_pinnedReferencesByProject[project!] ?? <String>{});

    final editor = StudioPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Scene composer', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 15),
          DropdownButtonFormField<String>(
            key: ValueKey(project),
            initialValue: project,
            decoration: const InputDecoration(labelText: 'Project'),
            isExpanded: true,
            items: widget.store.projects
                .map(
                  (item) => DropdownMenuItem(
                    value: item.id,
                    child: Text(item.title, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _selectProject(v)),
          ),
          const SizedBox(height: 13),
          TextField(
            controller: prompt,
            onChanged: (_) => setState(() {}),
            minLines: 4,
            maxLines: 7,
            decoration: const InputDecoration(
              labelText: 'Describe your shot',
              alignLabelWithHint: true,
              hintText: 'A cinematic night scene, dramatic lighting...',
            ),
          ),
          const SizedBox(height: 13),
          DropdownButtonFormField<String>(
            key: ValueKey('normal-model-$project'),
            initialValue: model,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Model preview'),
            items: [
              for (final item in demoVideoModels)
                DropdownMenuItem(value: item.id, child: Text(item.label)),
            ],
            onChanged: (v) {
              if (v != null) changeModel(v);
            },
          ),
          const SizedBox(height: 9),
          const Text(
            'These are demo capability profiles, not connected AI providers.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 9),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ModelCompatibilityPage()),
            ),
            icon: const Icon(Icons.hub_outlined),
            label: Text(
              'Explore ' +
                  HoticeAiCatalog.entries
                      .where((entry) => entry.status != AiStatus.retired)
                      .length
                      .toString() +
                  ' real API model research profiles',
            ),
          ),
          ApiVideoPreviewPanel(prompt: prompt.text),
          const SizedBox(height: 6),
          const Text(
            'Production model controls are separate from this offline demo. '
            'Real provider options, reference roles and duration constraints '
            'must come from a tested backend model catalog.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 13),
          DropdownButtonFormField<String>(
            key: ValueKey('normal-avatar-$project'),
            initialValue: avatarName,
            decoration: const InputDecoration(labelText: 'Avatar'),
            items: [
              const DropdownMenuItem(value: 'None', child: Text('None')),
              for (final actor in widget.store.avatars)
                DropdownMenuItem(value: actor.name, child: Text(actor.name)),
            ],
            onChanged: (value) {
              if (value != null) setState(() => avatarName = value);
            },
          ),
          const SizedBox(height: 13),
          if (selectedTemplate != null) ...[
            const SizedBox(height: 9),
            Text(
              'Template selected: ${selectedTemplate!.title}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (selectedTemplate!.actorSlots.isNotEmpty)
              Text(
                'Add ${selectedTemplate!.actorSlots.length} named actors in order '
                'to replace template role placeholders.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
          const SizedBox(height: 16),
          SceneCastAndReferences(
            profile: profile,
            actors: widget.store.avatars,
            cast: sceneActors,
            references: references,
            onCastChanged: (items) => setState(() {
              sceneActors
                ..clear()
                ..addAll(items);
            }),
            onReferencesChanged: (items) => setState(() {
              references
                ..clear()
                ..addAll(items);
            }),
          ),
          const SizedBox(height: 14),
          Text(
            'Smart reference manager',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 5),
          const Text(
            'Offline four-image limit is a simulation, not a verified provider capability. No media is uploaded or generated.',
            style: TextStyle(fontSize: 12),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Manual selection'),
            subtitle: const Text('Off = automatic camera-angle matching'),
            value: manualMode,
            onChanged: project == null
                ? null
                : (value) => setState(() {
                      _manualReferencesByProject[project!] = value;
                    }),
          ),
          if (!manualMode && avatarName != 'None') ...[
            DropdownButtonFormField<String>(
              key: ValueKey('ref-angle-$project-$avatarName'),
              initialValue: _preferredViewsByProject[project]?.name ?? 'auto',
              decoration: const InputDecoration(labelText: 'Reference angle'),
              items: [
                const DropdownMenuItem(
                  value: 'auto',
                  child: Text('Auto — read scene prompt'),
                ),
                for (final view in FaceView.values)
                  DropdownMenuItem(value: view.name, child: Text(view.label)),
              ],
              onChanged: (name) => setState(() {
                if (project == null) return;
                _preferredViewsByProject[project!] =
                    name == null || name == 'auto'
                        ? null
                        : FaceView.values.firstWhere((v) => v.name == name);
              }),
            ),
            const SizedBox(height: 7),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 5,
            children: [
              PopupMenuButton<ReferenceRole>(
                tooltip: 'Add scene reference',
                onSelected: importScenePhoto,
                itemBuilder: (ctx) => const [
                  PopupMenuItem(
                    value: ReferenceRole.location,
                    child: Text('Import location photo'),
                  ),
                  PopupMenuItem(
                    value: ReferenceRole.object,
                    child: Text('Import object / vehicle photo'),
                  ),
                  PopupMenuItem(
                    value: ReferenceRole.style,
                    child: Text('Import style reference'),
                  ),
                ],
                child: const Chip(
                  avatar: Icon(Icons.add_photo_alternate_outlined, size: 18),
                  label: Text('Add scene image'),
                ),
              ),
              Chip(label: Text('Selected ${currentPlan.imageCount}/4 (demo)')),
            ],
          ),
          if (pinned.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: project == null
                    ? null
                    : () => setState(() {
                          _pinnedReferencesByProject[project!]?.clear();
                        }),
                icon: const Icon(Icons.restart_alt),
                label: const Text('Clear locked / manual references'),
              ),
            ),
          if (allAssets.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No reference photos yet. Add face views in Avatar Studio or add scene images here.',
              ),
            ),
          for (final asset in allAssets)
            CheckboxListTile(
              key: ValueKey('reference-pin-${asset.id}'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                asset.role == ReferenceRole.avatar
                    ? 'Avatar · ${asset.view?.label ?? 'Face'}'
                    : '${asset.role.name} image',
              ),
              subtitle: Text(
                manualMode ? 'Include this image' : 'Lock this image',
              ),
              value: pinned.contains(asset.id),
              secondary: asset.role == ReferenceRole.avatar
                  ? null
                  : IconButton(
                      tooltip: 'Remove scene reference',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => setState(() {
                        if (project != null) {
                          widget.store.removeSceneReference(project!, asset.id);
                          _pinnedReferencesByProject[project!]?.remove(
                            asset.id,
                          );
                        }
                      }),
                    ),
              onChanged: (checked) => setState(() {
                final refs = _pinnedReferencesByProject.putIfAbsent(
                  project!,
                  () => <String>{},
                );
                if (checked == true) {
                  refs.add(asset.id);
                } else {
                  refs.remove(asset.id);
                }
              }),
            ),
          for (final message in currentPlan.errors)
            Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          if (currentPlan.selected.isNotEmpty)
            Text(
              'Planned: ${currentPlan.selected.map((a) => a.role == ReferenceRole.avatar ? a.view?.label ?? 'Face' : a.role.name).join(' + ')}',
              style: const TextStyle(fontSize: 12),
            ),
          for (final message in currentPlan.warnings.take(2))
            Text(message, style: const TextStyle(fontSize: 11)),
          const SizedBox(height: 17),
          Text('Aspect ratio', style: Theme.of(context).textTheme.titleSmall),
          Wrap(
            spacing: 8,
            children: [
              for (final item in profile.ratiosFor(seconds))
                ChoiceChip(
                  label: Text(item),
                  selected: ratio == item,
                  onSelected: (_) => setState(() => ratio = item),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Duration', style: Theme.of(context).textTheme.titleSmall),
          Wrap(
            spacing: 8,
            children: [
              for (final item in profile.durations)
                ChoiceChip(
                  label: Text('$item seconds'),
                  selected: seconds == item,
                  onSelected: (_) => changeDuration(item),
                ),
            ],
          ),
          const SizedBox(height: 15),
          ExpansionTile(
            initiallyExpanded: false,
            title: const Text('Advanced settings'),
            subtitle: Text('${profile.label} · ${profile.priceBand}'),
            childrenPadding: const EdgeInsets.only(bottom: 15),
            children: [
              Text(
                'Model selection is currently illustrative. Real provider '
                'capabilities and actual prices will come from the secure admin catalog.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 11),
              if (profile.supportsNegativePrompt)
                TextField(
                  controller: negativePrompt,
                  maxLength: 350,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Negative prompt (optional)',
                  ),
                ),
              if (profile.supportsSeed)
                TextField(
                  controller: seedText,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Seed (optional)',
                  ),
                ),
              if (profile.supportsSound)
                SwitchListTile(
                  title: const Text('Sound generation preview'),
                  subtitle: const Text('No audio will be generated yet.'),
                  value: soundEnabled,
                  onChanged: (value) => setState(() => soundEnabled = value),
                ),
              const SizedBox(height: 9),
              Text(
                'Supports ${profile.maxActors} actors; '
                '${profile.attachments.length} reference media types.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Builder(
            builder: (context) {
              final quote = profile.quoteCredits(seconds, ratio);
              return Text(
                quote == null
                    ? 'Generation cost: not configured. No charge will be made.'
                    : 'Estimated cost: $quote HOTICE Credits (demo only)',
                style: Theme.of(context).textTheme.bodyMedium,
              );
            },
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Save generation draft',
            icon: Icons.auto_awesome,
            onPressed: save,
          ),
        ],
      ),
    );
    final preview = Column(
      children: [
        StudioPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Scene preview',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 13),
              const FilmPreview(title: 'THE NEXT FRAME'),
              const SizedBox(height: 12),
              const Text(
                'No video rendered — placeholder preview.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        StudioPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Saved drafts',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (!widget.store.drafts.any((item) => item.projectId == project))
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('Your draft history will appear here.'),
                ),
              for (final draft in widget.store.drafts
                  .where((item) => item.projectId == project)
                  .take(4))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.movie_creation_outlined),
                  title: Text(draft.project),
                  subtitle: Text(
                    draft.avatarName == 'None'
                        ? draft.prompt
                        : '${draft.prompt}\nAvatar: ${draft.avatarName}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(draft.durationSeconds.toString() + 's'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        _mockGenerationPanel(),
      ],
    );
    return PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageTitle(
            eyebrow: 'Creative engine',
            title: 'Video generation',
            subtitle: 'Direct your shots with powerful cinematic controls.',
          ),
          const DemoNotice(
            'AI video rendering is not connected. The optional server workflow below '
            'is a mock dry run that creates job metadata only and uses simulated credits.',
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 760) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: editor),
                    const SizedBox(width: 18),
                    Expanded(flex: 5, child: preview),
                  ],
                );
              }
              return Column(
                children: [editor, const SizedBox(height: 16), preview],
              );
            },
          ),
        ],
      ),
    );
  }
}
