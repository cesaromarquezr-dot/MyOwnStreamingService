import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';

import '../app_core.dart';
import '../core/services/automatic_backup_service.dart';
import '../core/services/disc_ingestion_service.dart';
import '../disc_ingestion_center.dart';
import '../offline_sync_queue.dart';
import 'offline_sync_center_screen.dart';

/// A unified read view over the operations that already have durable state.
///
/// The center intentionally adapts existing services instead of creating a
/// second queue that could disagree with the source of truth. Current sources:
/// MakeMKV disc jobs, local backup snapshots, offline sync actions, and the
/// profile activity feed.
class BackgroundTaskCenterScreen extends StatefulWidget {
  const BackgroundTaskCenterScreen({super.key});

  @override
  State<BackgroundTaskCenterScreen> createState() =>
      _BackgroundTaskCenterScreenState();
}

class _BackgroundTaskCenterScreenState
    extends State<BackgroundTaskCenterScreen> {
  final DiscIngestionService _disc = DiscIngestionService.instance;
  final AutomaticBackupService _backup = AutomaticBackupService.instance;

  List<DiscRipJob> _jobs = const <DiscRipJob>[];
  List<AutomaticBackupRecord> _backups = const <AutomaticBackupRecord>[];
  List<PendingSyncAction> _pendingSync = const <PendingSyncAction>[];
  bool _loading = true;
  bool _working = false;
  String? _error;

  String get _accountScope =>
      AppController.instance.currentAccount?.id ?? 'local';

  @override
  void initState() {
    super.initState();
    _disc.addListener(_sourceChanged);
    _backup.status.addListener(_sourceChanged);
    AppController.instance.addListener(_appChanged);
    unawaited(_refresh());
  }

  @override
  void dispose() {
    _disc.removeListener(_sourceChanged);
    _backup.status.removeListener(_sourceChanged);
    AppController.instance.removeListener(_appChanged);
    super.dispose();
  }

  void _sourceChanged() {
    if (!mounted) return;
    setState(() {
      _jobs = List<DiscRipJob>.unmodifiable(_disc.jobs);
    });
  }

  void _appChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final app = AppController.instance;
      await app.loadActivity();

      // MakeMKV process discovery is a desktop-only integration. Avoid
      // initializing its dart:io process adapter in browsers.
      if (!kIsWeb) {
        await _disc.initialize();
      }
      final backupFuture = kIsWeb
          ? Future<List<AutomaticBackupRecord>>.value(
              const <AutomaticBackupRecord>[],
            )
          : _backup.listBackups();
      final values = await Future.wait<dynamic>([
        backupFuture,
        OfflineSyncQueue(scopeId: _accountScope).list(),
      ]);
      if (!mounted) return;
      setState(() {
        _jobs = kIsWeb
            ? const <DiscRipJob>[]
            : List<DiscRipJob>.unmodifiable(_disc.jobs);
        _backups = values[0] as List<AutomaticBackupRecord>;
        _pendingSync = values[1] as List<PendingSyncAction>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Some task sources could not be loaded: $error';
      });
    }
  }

  Future<void> _createBackup() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await _backup.backupNow();
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A local settings backup was created.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _cancelRip(DiscRipJob job) async {
    final accepted = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Cancel this disc job?'),
            content: const Text(
              'MakeMKV will be stopped. The destination may contain partial files; inspect the output before using or deleting them.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Keep running'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Cancel job'),
              ),
            ],
          ),
        ) ??
        false;
    if (!accepted) return;
    try {
      await _disc.cancelRip(job.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cancellation requested.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not cancel the job: $error')),
        );
      }
    }
  }

  void _open(Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  String _ripStatus(DiscRipStatus status) => switch (status) {
        DiscRipStatus.running => 'Running',
        DiscRipStatus.succeeded => 'Completed',
        DiscRipStatus.failed => 'Failed',
        DiscRipStatus.cancelled => 'Cancelled',
      };

  Color _ripColor(DiscRipStatus status, ColorScheme colors) => switch (status) {
        DiscRipStatus.running => colors.primary,
        DiscRipStatus.succeeded => Colors.green,
        DiscRipStatus.failed => colors.error,
        DiscRipStatus.cancelled => colors.outline,
      };

  @override
  Widget build(BuildContext context) {
    final app = AppController.instance;
    final activeJobs = _jobs.where((job) => job.status == DiscRipStatus.running);
    final activity = app.activity.take(12).toList(growable: false);
    final backupStatus = _backup.status.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Background Tasks & Activity'),
        actions: [
          IconButton(
            tooltip: 'Refresh task sources',
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          _error!,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      ),
                    ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _MetricCard(
                        label: 'Active disc jobs',
                        value: '${activeJobs.length}',
                        icon: Icons.album_outlined,
                      ),
                      _MetricCard(
                        label: 'Pending sync updates',
                        value: '${_pendingSync.length}',
                        icon: Icons.sync_rounded,
                      ),
                      _MetricCard(
                        label: 'Local backups',
                        value: '${_backups.length}',
                        icon: Icons.backup_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _SectionHeader(
                    title: 'Media import & ripping',
                    action: TextButton.icon(
                      onPressed: () => _open(const DiscIngestionCenterScreen()),
                      icon: const Icon(Icons.open_in_new_rounded, size: 17),
                      label: const Text('Open intake'),
                    ),
                  ),
                  if (kIsWeb)
                    const _InfoCard(
                      icon: Icons.desktop_windows_outlined,
                      text:
                          'Local MakeMKV process jobs are available in supported Windows, macOS and Linux desktop builds, not in the browser.',
                    )
                  else if (_jobs.isEmpty)
                    const _EmptyCard(text: 'No disc-ingestion jobs are recorded yet.')
                  else
                    for (final job in _jobs.take(8))
                      _DiscJobCard(
                        job: job,
                        statusText: _ripStatus(job.status),
                        statusColor: _ripColor(job.status, Theme.of(context).colorScheme),
                        onCancel: job.status == DiscRipStatus.running && _disc.hasActiveRip
                            ? () => _cancelRip(job)
                            : null,
                      ),
                  const SizedBox(height: 18),
                  _SectionHeader(
                    title: 'Backup & recovery',
                    action: FilledButton.tonalIcon(
                      onPressed: kIsWeb || _working || backupStatus.isBusy
                          ? null
                          : _createBackup,
                      icon: _working || backupStatus.isBusy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.backup_rounded, size: 18),
                      label: const Text('Back up now'),
                    ),
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                kIsWeb
                                    ? Icons.info_outline_rounded
                                    : backupStatus.enabled
                                        ? Icons.shield_outlined
                                        : Icons.pause_circle_outline,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  kIsWeb
                                      ? 'File-based backups unavailable in the browser'
                                      : backupStatus.enabled
                                          ? 'Automatic local backups enabled'
                                          : 'Automatic local backups paused',
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(kIsWeb
                              ? 'Use a supported desktop or mobile build for local file snapshots. Browser preferences remain separate from this file-based backup service.'
                              : backupStatus.message),
                          if (_backups.isNotEmpty) ...[
                            const Divider(height: 22),
                            for (final backup in _backups.take(3))
                              ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  backup.isLatest
                                      ? Icons.verified_outlined
                                      : Icons.history_rounded,
                                ),
                                title: Text(backup.isLatest ? 'Latest snapshot' : 'Recovery snapshot'),
                                subtitle: Text(
                                  '${backup.createdAt.toLocal()} · ${backup.preferenceCount} preference groups · ${backup.reason}',
                                ),
                              ),
                          ] else
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text('No backup snapshots are available yet.'),
                            ),
                          const Text(
                            'These local snapshots protect supported app settings and preferences. They do not contain media files or remote database rows.',
                            style: TextStyle(fontSize: 12, color: Colors.white60),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SectionHeader(
                    title: 'Offline synchronization queue',
                    action: TextButton(
                      onPressed: () => _open(const OfflineSyncCenterScreen()),
                      child: const Text('Manage sync'),
                    ),
                  ),
                  if (_pendingSync.isEmpty)
                    const _EmptyCard(text: 'No pending account updates are queued.')
                  else
                    Card(
                      child: Column(
                        children: [
                          for (final action in _pendingSync.take(8))
                            ListTile(
                              leading: const Icon(Icons.cloud_upload_outlined),
                              title: Text(_syncLabel(action.type)),
                              subtitle: Text(
                                'Queued ${action.queuedAt.toLocal()} · ${action.resourceId}',
                              ),
                              trailing: const Icon(Icons.schedule_rounded),
                            ),
                          if (_pendingSync.length > 8)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: Text('${_pendingSync.length - 8} more queued update(s)'),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 18),
                  _SectionHeader(title: 'Recent profile activity'),
                  if (activity.isEmpty)
                    const _EmptyCard(text: 'No recent profile activity is recorded.')
                  else
                    Card(
                      child: Column(
                        children: [
                          for (final item in activity)
                            ListTile(
                              leading: Icon(
                                item.read ? Icons.check_circle_outline : Icons.notifications_active_outlined,
                                color: item.read ? null : Theme.of(context).colorScheme.primary,
                              ),
                              title: Text(item.action, maxLines: 2, overflow: TextOverflow.ellipsis),
                              subtitle: Text('${item.title} · ${item.timestamp.toLocal()}'),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  const Text(
                    'This page combines records from the existing import, backup, synchronization and activity services. It does not invent a task status when a source service has not reported one.',
                    style: TextStyle(fontSize: 12, color: Colors.white60, height: 1.4),
                  ),
                ],
              ),
            ),
    );
  }

  String _syncLabel(String type) => switch (type) {
        'playback_progress' => 'Playback progress update',
        _ => type.replaceAll('_', ' '),
      };
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 160,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 8),
                Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action});
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          if (action != null) action!,
        ],
      );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon),
              const SizedBox(width: 10),
              Expanded(child: Text(text)),
            ],
          ),
        ),
      );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(text, style: const TextStyle(color: Colors.white60)),
        ),
      );
}

class _DiscJobCard extends StatelessWidget {
  const _DiscJobCard({
    required this.job,
    required this.statusText,
    required this.statusColor,
    this.onCancel,
  });
  final DiscRipJob job;
  final String statusText;
  final Color statusColor;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'MakeMKV · ${job.driveName}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Chip(
                    label: Text(statusText),
                    visualDensity: VisualDensity.compact,
                    side: BorderSide(color: statusColor.withValues(alpha: .45)),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(job.phase),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: job.status == DiscRipStatus.succeeded
                    ? 1
                    : job.progress.clamp(0.0, 1.0).toDouble(),
              ),
              const SizedBox(height: 6),
              Text('${(job.progress.clamp(0.0, 1.0) * 100).round()}% · ${job.createdAt.toLocal()}'),
              if (job.error != null && job.error!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(job.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              if (onCancel != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancel job'),
                  ),
                ),
            ],
          ),
        ),
      );
}
