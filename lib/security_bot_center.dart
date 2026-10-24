import 'package:flutter/material.dart';

import 'core/services/ai_bot_activity_service.dart';
import 'app_core.dart';

/// Administrator-facing, on-demand security diagnostics. The screen never
/// treats a bot recommendation as authorization to perform a mutation.
class ServerSecurityBotCenterScreen extends StatefulWidget {
  const ServerSecurityBotCenterScreen({super.key});

  @override
  State<ServerSecurityBotCenterScreen> createState() =>
      _ServerSecurityBotCenterScreenState();
}

class _ServerSecurityBotCenterScreenState
    extends State<ServerSecurityBotCenterScreen> {
  bool _loading = true;
  bool _running = false;
  String? _error;
  Map<String, dynamic> _status = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Map<String, dynamic>> _maps(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Map<String, dynamic>? _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : null;

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading && mounted) setState(() => _loading = true);
    try {
      final result =
          await AppController.instance.backendApi.getSecurityBotsStatus();
      if (!mounted) return;
      setState(() {
        _status = result;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _runChecks() async {
    setState(() => _running = true);
    final watch = Stopwatch()..start();
    final activity = AiBotActivityService.instance;
    final taskId = activity.startTask(
      botId: 'security',
      botName: 'Security Bot',
      title: 'Run read-only security diagnostics',
      details: 'Started an explicitly requested, administrator-authorized backend check.',
    );
    activity.recordStep(
      botId: 'security',
      botName: 'Security Bot',
      title: 'Calling backend diagnostics',
      details: 'Requesting the configured security-bot check endpoint; no account or network changes are authorized by this task.',
      taskId: taskId,
    );
    try {
      await AppController.instance.backendApi.runSecurityBotChecks();
      watch.stop();
      activity.completeTask(
        botId: 'security',
        botName: 'Security Bot',
        taskId: taskId,
        title: 'Security diagnostics completed',
        details: 'The backend accepted and completed the on-demand check request. Review the returned report for individual findings.',
        success: true,
        durationMs: watch.elapsedMilliseconds,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Read-only security checks completed.')),
        );
      }
      await _load(showLoading: false);
    } catch (error) {
      watch.stop();
      activity.completeTask(
        botId: 'security',
        botName: 'Security Bot',
        taskId: taskId,
        title: 'Security diagnostics failed',
        details: 'The check did not complete: ${error.runtimeType}. Details are shown in the security screen; sensitive error text is not copied into the general activity log.',
        success: false,
        durationMs: watch.elapsedMilliseconds,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bots = _maps(_status['bots']);
    final report = _map(_status['latestReport']);
    final findings = _maps(report?['findings']);
    final history = _maps(_status['auditEvents']);
    final storage = _map(_status['auditStorage']) ?? const <String, dynamic>{};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Bot Control Center'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading || _running ? null : () => _load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading && _status.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _load(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _introCard(context),
                  const SizedBox(height: 12),
                  if (_error != null) ...[
                    _messageCard(
                      context,
                      icon: Icons.lock_outline_rounded,
                      title: 'Control center unavailable',
                      message:
                          '$_error\n\nAccess is fail-closed. Configure SECURITY_BOT_ADMIN_ACCOUNT_IDS on the backend with the exact authorized account IDs. This screen does not grant administrator access.',
                      severity: 'warning',
                    ),
                    const SizedBox(height: 12),
                  ],
                  FilledButton.icon(
                    onPressed: _running || _error != null ? null : _runChecks,
                    icon: _running
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow_rounded),
                    label: Text(_running
                        ? 'Running read-only checks…'
                        : 'Run security checks now'),
                  ),
                  const SizedBox(height: 8),
                  if (report != null) _reportSummary(context, report),
                  const SizedBox(height: 16),
                  Text('Bot network',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  if (bots.isEmpty && _error == null)
                    const Text(
                        'The backend has not returned a bot catalog yet.')
                  else
                    for (final bot in bots) _botCard(context, bot),
                  if (findings.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('Latest findings',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    for (final finding in findings)
                      _findingCard(context, finding),
                  ],
                  const SizedBox(height: 16),
                  Text('Audit history',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  _messageCard(
                    context,
                    icon: storage['durable'] == true
                        ? Icons.verified_user_rounded
                        : Icons.info_outline_rounded,
                    title: storage['durable'] == true
                        ? 'Audit history is durable'
                        : 'Audit history is temporary',
                    message: (storage['message'] ??
                            'No scan has been recorded in this session.')
                        .toString(),
                    severity: storage['durable'] == true ? 'ok' : 'warning',
                  ),
                  const SizedBox(height: 8),
                  if (history.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                            'No previous security-bot scans are available.'),
                      ),
                    )
                  else
                    for (final event in history.take(20))
                      _auditCard(context, event),
                  const SizedBox(height: 16),
                  _messageCard(
                    context,
                    icon: Icons.gpp_good_outlined,
                    title: 'Safety boundary',
                    message:
                        'These bots observe and recommend. They do not automatically revoke sessions, ban IPs, change database policies, rotate keys, modify records, restore backups, or delete files. Backend authorization and database policies remain the security boundary.',
                    severity: 'info',
                  ),
                ],
              ),
            ),
    );
  }

  Widget _introCard(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF142B35), Color(0xFF191B29)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.security_rounded, size: 34, color: Color(0xFF8CE0C7)),
            SizedBox(height: 10),
            Text('Security & Reliability Bot Network',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            SizedBox(height: 6),
            Text(
              'Run an on-demand read-only check of authentication signals, database reachability, backup readiness, transport configuration, and scanner integration. This first release does not run continuously in the background.',
              style: TextStyle(color: Colors.white70, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reportSummary(BuildContext context, Map<String, dynamic> report) {
    final summary = _map(report['summary']) ?? const <String, dynamic>{};
    final status = report['status']?.toString() ?? 'unknown';
    final completed = report['completedAt']?.toString() ?? 'Unknown time';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _statusIcon(status),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Last scan: ${status.toUpperCase()}',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
          ]),
          const SizedBox(height: 6),
          Text('Completed: $completed',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _countChip('Checks', summary['total']),
            _countChip('Critical', summary['critical']),
            _countChip('Errors', summary['error']),
            _countChip('Warnings', summary['warning']),
            _countChip('Info', summary['info']),
          ]),
        ]),
      ),
    );
  }

  Widget _botCard(BuildContext context, Map<String, dynamic> bot) {
    final mode = (bot['mode'] ?? '').toString().replaceAll('_', ' ');
    final permission =
        (bot['permissionLevel'] ?? 'observe').toString().toUpperCase();
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading:
            CircleAvatar(child: Icon(_botIcon(bot['id']?.toString() ?? ''))),
        title: Text((bot['name'] ?? 'Security bot').toString(),
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text((bot['description'] ?? '').toString()),
            const SizedBox(height: 6),
            Text('$permission · $mode',
                style: Theme.of(context).textTheme.labelSmall),
          ]),
        ),
      ),
    );
  }

  Widget _findingCard(BuildContext context, Map<String, dynamic> finding) {
    final severity = (finding['severity'] ?? 'info').toString();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _statusIcon(severity),
            const SizedBox(width: 10),
            Expanded(
              child: Text((finding['title'] ?? 'Finding').toString(),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
            Text(severity.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall),
          ]),
          const SizedBox(height: 8),
          Text((finding['summary'] ?? '').toString()),
          const SizedBox(height: 8),
          Text('Recommendation', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 3),
          Text((finding['recommendation'] ?? '').toString()),
        ]),
      ),
    );
  }

  Widget _auditCard(BuildContext context, Map<String, dynamic> event) {
    final metadata = _map(event['metadata']) ?? const <String, dynamic>{};
    final report = _map(metadata['report']) ?? const <String, dynamic>{};
    final summary = _map(report['summary']) ?? const <String, dynamic>{};
    final at = (event['created_at'] ?? event['createdAt'] ?? 'Unknown time')
        .toString();
    return Card(
      child: ListTile(
        leading: _statusIcon((report['status'] ?? 'info').toString()),
        title: Text(
            'Security scan · ${(report['status'] ?? 'unknown').toString()}'),
        subtitle: Text(
            '$at\n${summary['total'] ?? 0} findings · ${summary['warning'] ?? 0} warnings'),
        isThreeLine: true,
      ),
    );
  }

  Widget _messageCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    required String severity,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _statusIcon(severity, fallback: icon),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(message),
              ])),
        ]),
      ),
    );
  }

  Widget _countChip(String label, dynamic value) => Chip(
        label: Text('$label: ${value ?? 0}'),
        visualDensity: VisualDensity.compact,
      );

  Widget _statusIcon(String status, {IconData? fallback}) {
    final critical = {
      'critical',
      'error',
      'failed',
      'unreachable',
      'capacity_critical'
    }.contains(status.toLowerCase());
    final warning = {
      'warning',
      'attention',
      'review_required',
      'stale',
      'not_configured',
      'unknown',
      'manual_review',
      'unavailable',
      'capacity_warning'
    }.contains(status.toLowerCase());
    return Icon(
      fallback ??
          (critical
              ? Icons.error_rounded
              : warning
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_outline_rounded),
      color: critical
          ? Theme.of(context).colorScheme.error
          : warning
              ? Colors.orange.shade700
              : Theme.of(context).colorScheme.primary,
    );
  }

  IconData _botIcon(String id) => switch (id) {
        'sentinel' => Icons.radar_rounded,
        'database_guardian' => Icons.storage_rounded,
        'backup_verifier' => Icons.backup_rounded,
        'transport_guardian' => Icons.router_rounded,
        'vulnerability_watch' => Icons.bug_report_outlined,
        'permission_auditor' => Icons.policy_outlined,
        'ai_safety_guardian' => Icons.smart_toy_outlined,
        _ => Icons.shield_outlined,
      };
}
