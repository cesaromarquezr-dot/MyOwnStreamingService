import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_core.dart';
import '../offline_sync_queue.dart';
import '../platform_capability_registry.dart';

/// Read-only, in-app diagnostics for the current runtime and loaded catalog.
/// Flutter analyzer/tests/builds remain CLI/CI jobs and are never claimed to
/// have been run by this screen.
class DeveloperTestingStudioScreen extends StatefulWidget {
  const DeveloperTestingStudioScreen({super.key});

  @override
  State<DeveloperTestingStudioScreen> createState() =>
      _DeveloperTestingStudioScreenState();
}

enum _CheckState { passed, attention, info, unavailable }

class _LocalCheck {
  const _LocalCheck({
    required this.title,
    required this.detail,
    required this.state,
    this.recommendation,
  });

  final String title;
  final String detail;
  final _CheckState state;
  final String? recommendation;
}

class _DeveloperTestingStudioScreenState
    extends State<DeveloperTestingStudioScreen> {
  List<_LocalCheck> _checks = const <_LocalCheck>[];
  DateTime? _lastRun;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    unawaited(_runChecks());
  }

  Future<void> _runChecks() async {
    if (_running) return;
    setState(() {
      _running = true;
    });

    final app = AppController.instance;
    final library = app.library;
    final missingArtwork = library
        .where((item) => item.imageUrl == null || item.imageUrl!.trim().isEmpty)
        .length;
    final missingDescriptions = library
        .where((item) => item.description == null || item.description!.trim().isEmpty)
        .length;
    final emptyTitles = library.where((item) => item.title.trim().isEmpty).length;

    List<PendingSyncAction> pending = const <PendingSyncAction>[];
    var syncReadable = true;
    try {
      pending = await OfflineSyncQueue(
        scopeId: app.currentAccount?.id ?? 'local',
      ).list();
    } catch (_) {
      syncReadable = false;
    }

    var preferenceKeyCount = 0;
    var preferencesReadable = true;
    try {
      final preferences = await SharedPreferences.getInstance();
      preferenceKeyCount = preferences.getKeys().length;
    } catch (_) {
      preferencesReadable = false;
    }

    final capabilities = PlatformCapabilityCatalog.all;
    final foundational = capabilities
        .where((item) => item.readiness == CapabilityReadiness.foundationExists)
        .length;
    final verifyLocally = capabilities
        .where((item) => item.readiness == CapabilityReadiness.verifyLocally)
        .length;
    final configured = capabilities
        .where((item) => item.readiness == CapabilityReadiness.setupRequired ||
            item.readiness == CapabilityReadiness.providerOrHardware)
        .length;
    final roadmap = capabilities
        .where((item) => item.readiness == CapabilityReadiness.roadmap)
        .length;

    final platformName = kIsWeb ? 'Web browser' : defaultTargetPlatform.name;
    final checks = <_LocalCheck>[
      _LocalCheck(
        title: 'Runtime platform',
        detail: '$platformName runtime detected. Platform-specific features must still verify their own adapter and permissions.',
        state: _CheckState.info,
      ),
      _LocalCheck(
        title: 'Active profile',
        detail: app.currentProfile == null
            ? 'No active profile is selected.'
            : 'An active profile is selected (${app.currentProfile!.name}).',
        state: app.currentProfile == null ? _CheckState.attention : _CheckState.passed,
        recommendation: app.currentProfile == null
            ? 'Select a profile before testing profile-specific playback, privacy, and synchronization.'
            : null,
      ),
      _LocalCheck(
        title: 'Backend session',
        detail: app.backendApi.isAuthenticated
            ? 'The current client has an authenticated backend session. This is not a server reachability or authorization audit.'
            : 'The app is in local or signed-out mode. Backend-only features may be unavailable.',
        state: _CheckState.info,
      ),
      _LocalCheck(
        title: 'Media catalog',
        detail: '${library.length} media record(s) are currently loaded in AppController.',
        state: library.isEmpty ? _CheckState.attention : _CheckState.passed,
        recommendation: library.isEmpty
            ? 'Load or import a small test library before testing search, recommendations, or interface modes.'
            : null,
      ),
      _LocalCheck(
        title: 'Artwork coverage',
        detail: '$missingArtwork of ${library.length} loaded records have no artwork URL.',
        state: missingArtwork == 0 ? _CheckState.passed : _CheckState.attention,
        recommendation: missingArtwork == 0
            ? null
            : 'Review artwork matches in Library Health; preserve manually curated artwork when repairing metadata.',
      ),
      _LocalCheck(
        title: 'Description coverage',
        detail: '$missingDescriptions of ${library.length} loaded records have no description.',
        state: missingDescriptions == 0 ? _CheckState.passed : _CheckState.attention,
        recommendation: missingDescriptions == 0
            ? null
            : 'Refresh or manually curate descriptions for records where plot/context discovery is important.',
      ),
      _LocalCheck(
        title: 'Required title values',
        detail: '$emptyTitles record(s) have an empty title field.',
        state: emptyTitles == 0 ? _CheckState.passed : _CheckState.attention,
        recommendation: emptyTitles == 0
            ? null
            : 'Review these records before relying on title matching or search indexing.',
      ),
      _LocalCheck(
        title: 'Offline synchronization queue',
        detail: syncReadable
            ? '${pending.length} pending synchronization action(s) are stored for the current account scope.'
            : 'The synchronization queue could not be read.',
        state: !syncReadable
            ? _CheckState.attention
            : pending.isEmpty
                ? _CheckState.passed
                : _CheckState.attention,
        recommendation: pending.isEmpty || !syncReadable
            ? null
            : 'Open Offline & Sync Center and review queued playback-progress changes before retrying synchronization.',
      ),
      _LocalCheck(
        title: 'Local preferences storage',
        detail: preferencesReadable
            ? 'SharedPreferences is readable; $preferenceKeyCount key(s) are present. Values are not included in this report.'
            : 'SharedPreferences could not be opened in this runtime.',
        state: preferencesReadable ? _CheckState.passed : _CheckState.attention,
      ),
      _LocalCheck(
        title: 'Capability roadmap snapshot',
        detail: '${capabilities.length} registered capabilities: $foundational foundation(s), $verifyLocally requiring local verification, $configured requiring provider/setup work, and $roadmap roadmap item(s). These are authored status labels, not live tests.',
        state: _CheckState.info,
      ),
      _LocalCheck(
        title: 'Local MakeMKV support',
        detail: kIsWeb
            ? 'Unavailable in a browser: MakeMKV process execution requires a supported desktop host.'
            : 'Desktop process support depends on the running operating system, MakeMKV installation, optical drive, and destination permissions.',
        state: kIsWeb ? _CheckState.unavailable : _CheckState.info,
        recommendation: kIsWeb
            ? 'Use the Windows, macOS, or Linux desktop build for local optical-drive ingestion.'
            : 'Verify the executable and output destination in Disc Ingestion Center before starting a rip.',
      ),
    ];

    if (!mounted) return;
    setState(() {
      _checks = checks;
      _lastRun = DateTime.now();
      _running = false;
    });
  }

  String _formatCheck(_LocalCheck check) {
    final lines = <String>[
      '[${check.state.name.toUpperCase()}] ${check.title}',
      check.detail,
    ];
    final recommendation = check.recommendation;
    if (recommendation != null) {
      lines.add('Recommendation: $recommendation');
    }
    return lines.join('\n');
  }

  Future<void> _copyReport() async {
    final generatedAt = _lastRun?.toIso8601String() ?? 'not run';
    final platform = kIsWeb ? 'Web' : defaultTargetPlatform.name;
    final report = <String>[
      'MyOwnStreamingService local diagnostic report',
      'Generated: $generatedAt',
      'Platform: $platform',
      '',
      ..._checks.map(_formatCheck),
      '',
      'This report contains local counts and statuses only. It excludes account identifiers, profile identifiers, credentials, local file paths, playback URLs, and media bytes.',
    ].join('\n\n');
    await Clipboard.setData(ClipboardData(text: report));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sanitized diagnostic report copied.')),
      );
    }
  }

  void _openCapabilityRegistry() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const PlatformCapabilityRegistryScreen(),
      ),
    );
  }

  int get _passed => _checks.where((item) => item.state == _CheckState.passed).length;
  int get _attention => _checks.where((item) => item.state == _CheckState.attention).length;
  int get _info => _checks.where((item) =>
      item.state == _CheckState.info || item.state == _CheckState.unavailable).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer & Testing Studio'),
        actions: [
          IconButton(
            tooltip: 'Run local checks again',
            onPressed: _running ? null : _runChecks,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.developer_mode_rounded, size: 34),
                  const SizedBox(height: 8),
                  Text(
                    'Inspect the running app before changing it',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'These checks read the current client runtime, local catalog summary, preferences availability, and queued sync count. They do not run Flutter tests, contact every provider, or certify server security.',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _SummaryChip(label: 'Passed $_passed', state: _CheckState.passed),
                      _SummaryChip(label: 'Attention $_attention', state: _CheckState.attention),
                      _SummaryChip(label: 'Info $_info', state: _CheckState.info),
                    ],
                  ),
                  if (_lastRun != null) ...[
                    const SizedBox(height: 8),
                    Text('Last run: ${_lastRun!.toLocal()}'),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _running ? null : _runChecks,
                          icon: _running
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.play_arrow_rounded),
                          label: Text(_running ? 'Running checks…' : 'Run local diagnostics'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: 'Copy sanitized report',
                        onPressed: _checks.isEmpty ? null : _copyReport,
                        icon: const Icon(Icons.copy_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Runtime checks', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (_running && _checks.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else
            for (final check in _checks) _DiagnosticCheckCard(check: check),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Local Flutter verification', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  const Text('Run these commands from the MyOwnStreamingService project root. The in-app diagnostic screen cannot execute the Flutter toolchain.'),
                  const SizedBox(height: 10),
                  const SelectableText('flutter analyze\nflutter test\nflutter build web\nflutter build windows'),
                ],
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.fact_check_outlined),
              title: const Text('Capability Registry & Master Roadmap'),
              subtitle: const Text('Review implementation foundations, setup requirements, dependencies and acceptance criteria.'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _openCapabilityRegistry,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagnosticCheckCard extends StatelessWidget {
  const _DiagnosticCheckCard({required this.check});
  final _LocalCheck check;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (icon, color, label) = switch (check.state) {
      _CheckState.passed => (Icons.check_circle_outline, Colors.green, 'Passed'),
      _CheckState.attention => (Icons.warning_amber_rounded, colors.error, 'Attention'),
      _CheckState.info => (Icons.info_outline_rounded, colors.primary, 'Info'),
      _CheckState.unavailable => (Icons.block_outlined, colors.outline, 'Unavailable'),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Expanded(child: Text(check.title, style: const TextStyle(fontWeight: FontWeight.w800))),
                Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 7),
            Text(check.detail),
            if (check.recommendation != null) ...[
              const SizedBox(height: 8),
              Text('Next step: ${check.recommendation}', style: const TextStyle(color: Colors.white70)),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.state});
  final String label;
  final _CheckState state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = switch (state) {
      _CheckState.passed => Colors.green,
      _CheckState.attention => colors.error,
      _CheckState.info => colors.primary,
      _CheckState.unavailable => colors.outline,
    };
    return Chip(
      avatar: Icon(Icons.circle, size: 10, color: color),
      label: Text(label),
    );
  }
}
