import 'package:flutter/material.dart';

import 'state.dart';
import 'model_compatibility_page.dart';
import 'design.dart';
import 'account_api.dart';

export 'avatar_studio.dart' show AvatarsPage;

class CreditsPage extends StatefulWidget {
  final HotIceStore store;
  const CreditsPage({super.key, required this.store});
  @override
  State<CreditsPage> createState() => _CreditsPageState();
}

class _CreditsPageState extends State<CreditsPage> {
  int selectedUsd = minimumPurchaseUsd;
  String selectedPayment = 'Stripe';

  void preview() {
    final creditCount = selectedUsd * creditsPerUsd;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Checkout preview'),
        content: Text(
          'Selected: US' +
              r'$' +
              selectedUsd.toString() +
              ' = ' +
              creditCount.toString() +
              ' HOTICE Credits.\n' +
              'Payment option: ' +
              selectedPayment +
              '.\n\n' +
              'This is a demo only. No payment is taken and no credits are issued.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageTitle(
            eyebrow: 'Studio wallet',
            title: 'HOTICE Credits',
            subtitle: 'Transparent pricing and flexible payment options.',
          ),
          const DemoNotice(
            'Payment options are previews. Stripe, PayPal, card processing and secure credit ledger are not connected.',
          ),
          const SizedBox(height: 18),
          StudioPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '1 HOTICE Credit = US' + r'$' + '0.01',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text('Minimum purchase: US' + r'$' + '10'),
                const SizedBox(height: 8),
                Text(
                  'Demo-only balance: ' +
                      widget.store.demoCredits.toString() +
                      ' Credits',
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 13,
                  runSpacing: 13,
                  children: [
                    for (final price in [10, 20, 50])
                      SizedBox(
                        width: 195,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => setState(() => selectedUsd = price),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.all(19),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              color: selectedUsd == price
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: .13)
                                  : Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHigh,
                              border: Border.all(
                                color: selectedUsd == price
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).dividerColor,
                                width: selectedUsd == price ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'US' + r'$' + price.toString(),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  (price * creditsPerUsd).toString() +
                                      ' Credits',
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  price == 10 ? 'MINIMUM PACK' : 'CREDIT PACK',
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 19),
                Text(
                  'Payment method',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: [
                    for (final method in [
                      'Stripe',
                      'PayPal',
                      'Credit / debit card',
                    ])
                      ChoiceChip(
                        label: Text(method),
                        selected: selectedPayment == method,
                        onSelected: (_) =>
                            setState(() => selectedPayment = method),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: 'Preview checkout',
                  icon: Icons.lock_outline,
                  onPressed: preview,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  final HotIceStore store;
  const SettingsPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) => PageFrame(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const PageTitle(
              eyebrow: 'Personalise your space',
              title: 'Appearance & settings',
              subtitle: 'Make HOTICE feel like your own professional studio.'),
          const DemoNotice(
              'Theme preferences and security controls are demo previews.'),
          StudioPanel(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Display mode',
                    style: Theme.of(context).textTheme.titleMedium),
                Wrap(spacing: 8, children: [
                  for (final mode in ThemeMode.values)
                    ChoiceChip(
                        label: Text(switch (mode) {
                          ThemeMode.system => 'System',
                          ThemeMode.light => 'Light',
                          ThemeMode.dark => 'Dark',
                        }),
                        selected: store.themeMode == mode,
                        onSelected: (_) => store.updateTheme(mode))
                ]),
                const SizedBox(height: 12),
                Text('Accent', style: Theme.of(context).textTheme.titleMedium),
                Wrap(spacing: 8, children: [
                  for (final accent in StudioAccent.values)
                    ChoiceChip(
                        label: Text(accent.label),
                        selected: store.accent == accent,
                        onSelected: (_) => store.updateAccent(accent))
                ]),
                const SizedBox(height: 12),
                Text('Typography',
                    style: Theme.of(context).textTheme.titleMedium),
                Wrap(spacing: 8, children: [
                  for (final font in StudioFont.values)
                    ChoiceChip(
                        label: Text(font.label),
                        selected: store.font == font,
                        onSelected: (_) => store.updateFont(font))
                ]),
              ])),
          const SizedBox(height: 17),
          StudioPanel(
              child: ListTile(
                  key: const ValueKey('model-compatibility-open'),
                  leading: const Icon(Icons.hub_outlined),
                  title: const Text('AI model compatibility'),
                  subtitle: const Text(
                      'Official API model profiles, limits and retired versions.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const ModelCompatibilityPage())))),
          const SizedBox(height: 17),
          const StudioPanel(
              child: ListTile(
                  leading: Icon(Icons.security_outlined),
                  title: Text('Security & privacy'),
                  subtitle: Text(
                      'Authentication, privacy controls and durable settings are still on the production roadmap.'))),
        ]),
      );
}

class AccountsPage extends StatefulWidget {
  final HotIceStore store;
  final AccountApi? accountApi;
  final String? authenticatedEmail;
  final Future<void> Function()? onSignOut;
  const AccountsPage({
    super.key,
    required this.store,
    this.accountApi,
    this.authenticatedEmail,
    this.onSignOut,
  });
  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  final email = TextEditingController();
  String? selectedProjectId;
  String? localCopySourceEmail;
  String? localCopyProjectId;
  List<CloudProjectSummary> cloudProjects = const [];
  bool cloudBusy = false;

  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  void add() {
    if (!isValidDemoEmail(email.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid demo email address.')),
      );
      return;
    }
    widget.store.addAccount(email.text);
    email.clear();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Demo profile selected.')));
  }

  List<HotProject> get _shareableProjects => widget.store.projects
      .where((project) => isCloudProjectId(project.id))
      .toList(growable: false);

  Future<void> _loadCloudProjects() async {
    final api = widget.accountApi;
    if (api == null || !api.isConfigured) {
      _showMessage(
        'Cloud service is not configured for this installation. Your local projects are unchanged.',
      );
      return;
    }
    setState(() => cloudBusy = true);
    try {
      final results = await api.listCloudProjects();
      if (mounted)
        setState(() {
          cloudProjects = results;
          cloudBusy = false;
        });
    } on AccountApiException catch (error) {
      if (mounted) setState(() => cloudBusy = false);
      _showMessage(error.message);
    }
  }

  Future<bool> _confirmShare(HotProject project) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Save this project to HOTICE cloud?'),
          content: Text(
            'Only “${project.title}” will be sent to the HOTICE account service. It includes the project title, scene prompts and settings, storyboard text, and Actor display labels. Source files, media bytes, reference filenames, private Actor identity notes, other projects, and other device workspaces stay on this device. Cloud storage requires an active account entitlement. This action is explicit; background sync stays off.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep on this device'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Save selected project'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _syncSelectedProject() async {
    final api = widget.accountApi;
    final projects = _shareableProjects;
    final id = projects.any((item) => item.id == selectedProjectId)
        ? selectedProjectId
        : (projects.isEmpty ? null : projects.first.id);
    final projectMatches = _shareableProjects.where((item) => item.id == id);
    if (api == null || id == null || projectMatches.isEmpty) return;
    final project = projectMatches.first;
    if (!await _confirmShare(project) || !mounted) return;
    setState(() => cloudBusy = true);
    try {
      final remote = await api.listCloudProjects();
      if (!mounted) return;
      final matching = remote.where((item) => item.id == id);
      final savedRevision = widget.store.cloudRevision(id);
      var expectedRevision = savedRevision;
      if (matching.isNotEmpty && matching.first.revision != savedRevision) {
        throw const AccountApiException(
          'This cloud project changed elsewhere. Restore the cloud version first, then review your local edits before saving again.',
        );
      }
      if (matching.isEmpty && savedRevision != 0) {
        final recreate = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Create a new cloud copy?'),
                content: const Text(
                  'The previous cloud copy has been deleted. Create a fresh copy from this device’s current project? HOTICE will not overwrite an existing copy; a concurrent recreation is rejected by the server.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Keep local only'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Create new cloud copy'),
                  ),
                ],
              ),
            ) ??
            false;
        if (!recreate || !mounted) {
          if (mounted) setState(() => cloudBusy = false);
          return;
        }
        expectedRevision = 0;
      }
      final revision = await api.saveCloudProject(
        id: id,
        title: project.title,
        expectedRevision: expectedRevision,
        document: widget.store.exportCloudProject(id),
      );
      widget.store.markCloudRevision(id, revision);
      await _loadCloudProjects();
      _showMessage(
        'Cloud copy saved. Your device project remains available offline.',
      );
    } on AccountApiException catch (error) {
      if (mounted) setState(() => cloudBusy = false);
      _showMessage(error.message);
    } on StateError catch (error) {
      if (mounted) setState(() => cloudBusy = false);
      _showMessage(error.message.toString());
    }
  }

  Future<void> _restoreCloudProject(CloudProjectSummary summary) async {
    final api = widget.accountApi;
    if (api == null) return;
    final alreadyLocal = widget.store.projects.any(
      (item) => item.id == summary.id,
    );
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              alreadyLocal
                  ? 'Replace this device’s project?'
                  : 'Restore cloud project?',
            ),
            content: Text(
              alreadyLocal
                  ? 'The local project “${summary.title}” and its drafts will be replaced with cloud revision ${summary.revision}. This cannot be undone from the cloud screen. Export a local backup first if you need the current edits.'
                  : '“${summary.title}” will be copied to this device. Project text and settings will be restored; source files and media bytes are not part of this cloud copy.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  alreadyLocal
                      ? 'Replace local project'
                      : 'Restore to this device',
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    setState(() => cloudBusy = true);
    try {
      final snapshot = await api.getCloudProject(summary.id);
      widget.store.importCloudProject(snapshot.document, replace: alreadyLocal);
      widget.store.markCloudRevision(summary.id, snapshot.revision);
      if (mounted) setState(() => cloudBusy = false);
      _showMessage(
        'Cloud revision ${snapshot.revision} restored. Local media remains on this device.',
      );
    } on AccountApiException catch (error) {
      if (mounted) setState(() => cloudBusy = false);
      _showMessage(error.message);
    } on (StateError, FormatException) catch (error) {
      if (mounted) setState(() => cloudBusy = false);
      _showMessage(error.toString());
    }
  }

  Future<void> _deleteCloudProject(CloudProjectSummary summary) async {
    final api = widget.accountApi;
    if (api == null) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete cloud copy?'),
            content: Text(
              '“${summary.title}” will be permanently removed from HOTICE cloud storage. Any local copy on this device stays as it is.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete cloud copy'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    setState(() => cloudBusy = true);
    try {
      await api.deleteCloudProject(summary.id);
      cloudProjects =
          cloudProjects.where((item) => item.id != summary.id).toList();
      widget.store.forgetCloudRevision(summary.id);
      if (mounted) setState(() => cloudBusy = false);
      _showMessage('Cloud copy deleted. This device’s local project was kept.');
    } on AccountApiException catch (error) {
      if (mounted) setState(() => cloudBusy = false);
      _showMessage(error.message);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _localProjectCopyPanel() {
    final candidates = widget.store.localProjectTransferCandidates;
    if (candidates.isEmpty) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bring a local project into this account'),
          SizedBox(height: 6),
          Text(
            'There are no eligible user-created projects in another local profile. Sample projects stay examples.',
          ),
        ],
      );
    }
    final profiles = candidates
        .map((candidate) => candidate.sourceProfileEmail)
        .toSet()
        .toList(growable: false);
    final profile = profiles.contains(localCopySourceEmail)
        ? localCopySourceEmail!
        : profiles.first;
    final projects = candidates
        .where((candidate) => candidate.sourceProfileEmail == profile)
        .toList(growable: false);
    final projectId = projects.any(
      (candidate) => candidate.project.id == localCopyProjectId,
    )
        ? localCopyProjectId!
        : projects.first.project.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bring a local project into this account',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        const Text(
          'Copy one user-created project from another saved local profile. The original stays unchanged. This creates a local copy only; cloud saving is a separate choice below.',
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: const ValueKey('local-copy-source-profile'),
          initialValue: profile,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Local profile'),
          items: [
            for (final item in profiles)
              DropdownMenuItem(value: item, child: Text(item)),
          ],
          onChanged: (value) => setState(() {
            localCopySourceEmail = value;
            localCopyProjectId = null;
          }),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          key: ValueKey('local-copy-project-$profile'),
          initialValue: projectId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Local project'),
          items: [
            for (final candidate in projects)
              DropdownMenuItem(
                value: candidate.project.id,
                child: Text(
                  candidate.project.title,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) => setState(() => localCopyProjectId = value),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _confirmAndCopyLocalProject(profile, projectId),
            icon: const Icon(Icons.copy_all_outlined),
            label: const Text('Review local copy'),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmAndCopyLocalProject(
    String profileEmail,
    String projectId,
  ) async {
    final candidate = widget.store.localProjectTransferCandidates.where(
      (item) =>
          item.sourceProfileEmail == profileEmail &&
          item.project.id == projectId,
    );
    if (candidate.isEmpty) return;
    final project = candidate.first.project;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Copy “${project.title}” to this device account?'),
            content: const Text(
              'This creates a separate local copy with a new project ID. It includes scene prompts and settings, storyboard text, Actor names and notes, and reference-file metadata. Media bytes and pending generation attempts are not copied. The original remains unchanged. Nothing is uploaded; use the separate cloud control below only if you want a cloud copy.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.copy_all_outlined),
                label: const Text('Copy on this device'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    try {
      final result = widget.store.copyLocalProjectFromProfile(
        profileEmail,
        projectId,
      );
      setState(() => selectedProjectId = result.project.id);
      _showMessage(
        'Local copy created. The original stays in “$profileEmail”; nothing was uploaded.',
      );
    } on StateError catch (error) {
      _showMessage(error.message.toString());
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
        child: widget.authenticatedEmail != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PageTitle(
                    eyebrow: 'HOTICE account',
                    title: 'Your account',
                    subtitle:
                        'This device is signed in to your HOTICE account.',
                  ),
                  StudioPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.verified_user_outlined),
                          title: const Text('Signed in'),
                          subtitle: Text(widget.authenticatedEmail!),
                        ),
                        const Text(
                          'Projects and creative drafts remain local on this device. Cloud sync and paid generation require separate explicit controls.',
                        ),
                        const SizedBox(height: 18),
                        _localProjectCopyPanel(),
                        const SizedBox(height: 18),
                        _cloudSyncPanel(),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: widget.onSignOut,
                          icon: const Icon(Icons.logout),
                          label: const Text('Sign out of HOTICE'),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PageTitle(
                    eyebrow: 'Identity',
                    title: 'Accounts',
                    subtitle: 'Add and switch between studio profiles.',
                  ),
                  const DemoNotice(
                    'Profiles are local UI examples with separate in-memory projects and avatars; no real registration, identity verification or cloud storage exists yet.',
                  ),
                  const SizedBox(height: 19),
                  StudioPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your profiles',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 10),
                        for (final profile in widget.store.accounts)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(
                              child: Icon(Icons.person_outline),
                            ),
                            title: Text(profile),
                            subtitle: Text(
                              profile == widget.store.selectedAccount
                                  ? 'Active profile'
                                  : 'Tap to switch',
                            ),
                            trailing: Icon(
                              profile == widget.store.selectedAccount
                                  ? Icons.check_circle
                                  : Icons.chevron_right,
                            ),
                            onTap: () => widget.store.switchAccount(profile),
                          ),
                        const Divider(height: 28),
                        TextField(
                          controller: email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Add demo email',
                            prefixIcon: Icon(Icons.alternate_email),
                          ),
                        ),
                        const SizedBox(height: 14),
                        PrimaryButton(
                          label: 'Add / switch account',
                          icon: Icons.person_add_alt,
                          onPressed: add,
                        ),
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: widget.store.signOut,
                          icon: const Icon(Icons.logout),
                          label: const Text('Sign out'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      );

  Widget _cloudSyncPanel() {
    final projects = _shareableProjects;
    final selectedId =
        projects.any((project) => project.id == selectedProjectId)
            ? selectedProjectId
            : (projects.isEmpty ? null : projects.first.id);
    return StudioPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_sync_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Optional project cloud copy',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                onPressed: cloudBusy ? null : _loadCloudProjects,
                tooltip: 'Refresh cloud projects',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Local-first: nothing uploads automatically. Choose one project, review exactly what is shared, then confirm. Media files and Actor identity notes stay on this device.',
          ),
          if (projects.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Create a project to enable cloud copy. Example/demo projects cannot be uploaded.',
              ),
            )
          else ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey(selectedId),
              initialValue: selectedId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Project on this device',
              ),
              items: [
                for (final project in projects)
                  DropdownMenuItem(
                    value: project.id,
                    child: Text(project.title, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: cloudBusy
                  ? null
                  : (value) => setState(() => selectedProjectId = value),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: cloudBusy ? null : _syncSelectedProject,
                icon: cloudBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(
                  cloudBusy ? 'Working…' : 'Review and save this project',
                ),
              ),
            ),
          ],
          if (cloudProjects.isNotEmpty) ...[
            const Divider(height: 24),
            Text(
              'Cloud projects (${cloudProjects.length})',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            for (final item in cloudProjects)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cloud_done_outlined),
                title: Text(item.title),
                subtitle: Text(
                  'Revision ${item.revision}${item.updatedAt == null ? '' : ' · ${item.updatedAt!.toLocal()}'}',
                ),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    TextButton(
                      onPressed:
                          cloudBusy ? null : () => _restoreCloudProject(item),
                      child: Text(
                        projects.any((project) => project.id == item.id)
                            ? 'Review restore'
                            : 'Restore',
                      ),
                    ),
                    IconButton(
                      tooltip: 'Delete cloud copy',
                      onPressed:
                          cloudBusy ? null : () => _deleteCloudProject(item),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
          ] else if (!cloudBusy)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Cloud project list has not been loaded. Use refresh to view copies for this account.',
              ),
            ),
        ],
      ),
    );
  }
}
