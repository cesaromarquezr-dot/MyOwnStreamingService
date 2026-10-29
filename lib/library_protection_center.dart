import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

import 'app_core.dart';
import 'core/services/automatic_backup_service.dart';
import 'core/services/library_protection_service.dart';
import 'core/services/library_metadata_snapshot_service.dart';
import 'details.dart';
import 'library_membership_store.dart';

/// A non-destructive control center for backups, duplicate review, and repair.
/// It deliberately offers no bulk-delete or automatic-merge operation.
class LibraryProtectionCenterScreen extends StatefulWidget {
  final int initialTabIndex;

  const LibraryProtectionCenterScreen({super.key, this.initialTabIndex = 0});

  @override
  State<LibraryProtectionCenterScreen> createState() =>
      _LibraryProtectionCenterScreenState();
}

class _LibraryProtectionCenterScreenState
    extends State<LibraryProtectionCenterScreen> {
  final AutomaticBackupService _backup = AutomaticBackupService.instance;
  List<AutomaticBackupRecord> _backups = const <AutomaticBackupRecord>[];
  List<PotentialDuplicateGroup> _duplicates = const <PotentialDuplicateGroup>[];
  Set<String> _reviewedDuplicates = <String>{};
  Set<String> _reviewedFindings = <String>{};
  List<Map<String, dynamic>> _events = const <Map<String, dynamic>>[];
  Set<String> _hiddenIds = <String>{};
  Map<String, bool> _pendingMembership = <String, bool>{};
  bool _loading = true;
  bool _busy = false;
  String? _error;

  String get _profileId => AppController.instance.currentProfile?.id ?? 'default';
  String get _reviewedDuplicateKey => 'moss_duplicate_reviewed_v1_$_profileId';
  String get _reviewedFindingKey => 'moss_repair_reviewed_v1_$_profileId';
  String get _eventKey => 'moss_library_protection_events_v1_$_profileId';
  LibraryMembershipStore get _membership =>
      LibraryMembershipStore(scopeId: _profileId);

  @override
  void initState() {
    super.initState();
    _backup.status.addListener(_backupStatusChanged);
    unawaited(_load());
  }

  @override
  void dispose() {
    _backup.status.removeListener(_backupStatusChanged);
    super.dispose();
  }

  void _backupStatusChanged() {
    if (mounted) unawaited(_reloadBackups());
  }

  Future<void> _load() async {
    try {
      await _backup.initialize();
      final prefs = await SharedPreferences.getInstance();
      final membership = _membership;
      final records = await _backup.listBackups();
      final duplicates = LibraryProtectionService.findPotentialDuplicates(
        AppController.instance.library,
      );
      final hidden = await membership.loadHiddenMediaIds();
      final pending = await membership.loadPendingOverrides();
      final reviewedDuplicates = (prefs.getStringList(_reviewedDuplicateKey) ??
              const <String>[])
          .toSet();
      final reviewedFindings = (prefs.getStringList(_reviewedFindingKey) ??
              const <String>[])
          .toSet();
      final rawEvents = prefs.getString(_eventKey);
      final events = <Map<String, dynamic>>[];
      if (rawEvents != null && rawEvents.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawEvents);
          if (decoded is List) {
            events.addAll(decoded.whereType<Map>().map(
                (row) => Map<String, dynamic>.from(row)));
          }
        } catch (_) {
          // Corrupt audit history should not block access to the collection.
        }
      }
      if (!mounted) return;
      setState(() {
        _backups = records;
        _duplicates = duplicates;
        _hiddenIds = hidden;
        _pendingMembership = pending;
        _reviewedDuplicates = reviewedDuplicates;
        _reviewedFindings = reviewedFindings;
        _events = events.reversed.take(30).toList(growable: false);
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'The protection dashboard could not load: $error';
      });
    }
  }

  Future<void> _reloadBackups() async {
    try {
      final records = await _backup.listBackups();
      if (mounted) setState(() => _backups = records);
    } catch (_) {}
  }

  Future<void> _recordEvent(String action, String detail) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entries = <Map<String, dynamic>>[];
      final raw = prefs.getString(_eventKey);
      if (raw != null) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) {
            entries.addAll(decoded.whereType<Map>().map(
                (row) => Map<String, dynamic>.from(row)));
          }
        } catch (_) {}
      }
      entries.add(<String, dynamic>{
        'action': action,
        'detail': detail,
        'at': DateTime.now().toUtc().toIso8601String(),
      });
      if (entries.length > 100) {
        entries.removeRange(0, entries.length - 100);
      }
      await prefs.setString(_eventKey, jsonEncode(entries));
      if (mounted) {
        setState(() => _events = entries.reversed.take(30).toList());
      }
    } catch (_) {}
  }

  Future<void> _createBackup() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _backup.backupNow();
      await _recordEvent('backup_created', 'Manual local settings checkpoint');
      await _reloadBackups();
      _message('Local settings backup created.');
    } catch (error) {
      _message('Backup failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportLibrarySnapshot() async {
    if (_busy) return;
    final accepted = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Export a library snapshot?'),
            content: const Text(
              'The JSON export contains media metadata, watched/liked item IDs, playback progress, collections, playlists, and listening counts/timestamps. '
              'Playback URLs, signed URL parameters, local paths, credentials, account IDs, and profile IDs are excluded. '
              'The file does not contain movie/music files and cannot restore remote database rows on its own. '
              'Choose where to save or share the exported file.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Create export'),
              ),
            ],
          ),
        ) ??
        false;
    if (!accepted || !mounted) return;
    setState(() => _busy = true);
    File? createdFile;
    try {
      final file = await const LibraryMetadataSnapshotService().createSnapshot();
      createdFile = file;
      await SharePlus.instance.share(ShareParams(
        title: 'MyOwnStreamingService library snapshot',
        text: 'Sanitized metadata export for the active library. It includes media metadata, progress IDs, collections, and music playlists/listening counts; it excludes media files, credentials, filesystem paths, and playback URLs. It does not restore remote database rows by itself.',
        files: <XFile>[XFile(file.path, mimeType: 'application/json')],
      ));
      await _recordEvent(
        'library_snapshot_exported',
        'Created a sanitized snapshot of ${AppController.instance.library.length} library item(s).',
      );
      _message('Library snapshot created. Save a copy away from this device for off-device recovery.');
    } catch (error) {
      if (createdFile != null) {
        _message('Snapshot was created at ${createdFile.path}, but sharing failed: $error');
      } else {
        _message('Library snapshot export failed: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore(AutomaticBackupRecord record) async {
    final accepted = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Restore this recovery point?'),
            content: const Text(
              'This replaces restorable local preferences with the selected snapshot. '
              'Create a fresh backup first if you need to preserve newer settings. '
              'Credentials are excluded. This does not restore video/music files or remote database rows.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Restore settings'),
              ),
            ],
          ),
        ) ??
        false;
    if (!accepted || _busy) return;
    setState(() => _busy = true);
    try {
      await _backup.restoreBackup(record.filePath);
      await _recordEvent('backup_restored',
          'Restored checkpoint from ${record.createdAt.toLocal().toIso8601String()}');
      await _reloadBackups();
      _message('Settings restored. Restart the app to reload open screens.');
    } catch (error) {
      _message('Restore failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reviewDuplicate(PotentialDuplicateGroup group) async {
    final updated = <String>{..._reviewedDuplicates, group.key};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_reviewedDuplicateKey, updated.toList()..sort());
    if (!mounted) return;
    setState(() => _reviewedDuplicates = updated);
    await _recordEvent('duplicate_reviewed',
        '${group.items.length} candidates: ${group.items.first.title}');
  }

  Future<void> _reviewFinding(LibraryAuditFinding finding) async {
    final updated = <String>{..._reviewedFindings, finding.id};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_reviewedFindingKey, updated.toList()..sort());
    if (!mounted) return;
    setState(() => _reviewedFindings = updated);
    await _recordEvent('repair_finding_reviewed',
        '${finding.category}: ${finding.title}');
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  String _timestamp(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final findings = LibraryProtectionService.audit(AppController.instance.library)
        .where((finding) => !_reviewedFindings.contains(finding.id))
        .toList(growable: false);
    final unreviewedDuplicates = _duplicates
        .where((group) => !_reviewedDuplicates.contains(group.key))
        .length;
    return DefaultTabController(
      length: 4,
      initialIndex: widget.initialTabIndex < 0
          ? 0
          : (widget.initialTabIndex > 3 ? 3 : widget.initialTabIndex),
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.initialTabIndex == 2 ? 'Library Repair Queue' : 'Library Protection & Recovery'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Duplicates'),
              Tab(text: 'Repair'),
              Tab(text: 'History'),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Refresh library audit',
              onPressed: _loading ? null : () => unawaited(_load()),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _load, child: const Text('Retry')),
                      ]),
                    ),
                  )
                : TabBarView(children: [
                    _overviewTab(findings.length, unreviewedDuplicates),
                    _duplicatesTab(),
                    _repairTab(findings),
                    _historyTab(),
                  ]),
      ),
    );
  }

  Widget _overviewTab(int findingCount, int unreviewedDuplicates) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _metricCard(
            icon: Icons.shield_outlined,
            title: 'Collection protection',
            detail: 'Potential duplicates are flagged for review only. Nothing in this center automatically deletes or merges media.',
            color: Colors.greenAccent,
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _metricChip('Titles', '${AppController.instance.library.length}'),
            _metricChip('Duplicate groups to review', '$unreviewedDuplicates'),
            _metricChip('Data-quality findings', '$findingCount'),
            _metricChip('Hidden from library', '${_hiddenIds.length}'),
            _metricChip('Pending sync overrides', '${_pendingMembership.length}'),
            _metricChip('Recovery points', '${_backups.length}'),
          ]),
          const SizedBox(height: 14),
          AnimatedBuilder(
            animation: _backup.status,
            builder: (context, _) {
              final status = _backup.status.value;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(status.enabled ? Icons.check_circle_outline : Icons.pause_circle_outline,
                          color: status.enabled ? Colors.greenAccent : Colors.orangeAccent),
                      const SizedBox(width: 8),
                      Expanded(child: Text(status.enabled ? 'Automatic local backups enabled' : 'Automatic local backups paused', style: const TextStyle(fontWeight: FontWeight.w800))),
                    ]),
                    const SizedBox(height: 6),
                    Text(status.message, style: const TextStyle(color: Colors.white70, height: 1.35)),
                    if (status.directoryPath != null) ...[
                      const SizedBox(height: 8),
                      SelectableText('Local folder: ${status.directoryPath}', style: const TextStyle(fontSize: 11, color: Colors.white54)),
                    ],
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      FilledButton.icon(
                        onPressed: _busy ? null : _createBackup,
                        icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.backup_rounded),
                        label: Text(_busy ? 'Working…' : 'Back up now'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _backup.setEnabled(!status.enabled),
                        icon: Icon(status.enabled ? Icons.pause_rounded : Icons.play_arrow_rounded),
                        label: Text(status.enabled ? 'Pause auto-backup' : 'Enable auto-backup'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _exportLibrarySnapshot,
                        icon: const Icon(Icons.ios_share_rounded),
                        label: const Text('Export library snapshot'),
                      ),
                    ]),
                  ]),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _metricCard(
            icon: Icons.file_download_outlined,
            title: 'Two-layer recovery',
            detail: 'Automatic checkpoints restore local app preferences. Export library snapshot creates a separate metadata/progress JSON that you can save off-device. Neither artifact restores remote database rows or copies media files; keep an independent server/database backup and media backup.',
            color: Colors.deepPurpleAccent,
          ),
          const SizedBox(height: 10),
          _metricCard(
            icon: Icons.sync_problem_outlined,
            title: 'Rescan and membership protection',
            detail: '${_hiddenIds.length} media item(s) are hidden from this profile. ${_pendingMembership.length} change(s) are queued for server sync. Pending overrides stay local until the server confirms them; hidden markers do not delete the underlying media file.',
            color: Colors.lightBlueAccent,
          ),
          const SizedBox(height: 10),
          _metricCard(
            icon: Icons.warning_amber_rounded,
            title: 'Database migration guardrail',
            detail: 'Before applying schema or database migrations, create a backup of the server database and verify a restore plan. This client-side settings backup is not a substitute for a backend/Supabase backup or an independent media-file copy.',
            color: Colors.orangeAccent,
          ),
          const SizedBox(height: 10),
          _metricCard(
            icon: Icons.lock_outline_rounded,
            title: 'Keep credentials separate',
            detail: 'Local recovery snapshots exclude credentials and tokens. Store server database backups separately and use access-controlled storage.',
            color: Colors.blueAccent,
          ),
        ],
      );

  Widget _duplicatesTab() {
    if (_duplicates.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No exact title/type/year duplicate candidates were found in the currently loaded library. This is a heuristic, not a file-hash scan.')));
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 2, 4, 10),
          child: Text('Review candidates before making any changes. Different editions, encodes, and cuts may be intentional.', style: TextStyle(color: Colors.white60, height: 1.4)),
        ),
        for (final group in _duplicates)
          Card(
            child: ExpansionTile(
              leading: Icon(group.containsDifferentEditions ? Icons.collections_bookmark_outlined : Icons.content_copy_rounded),
              title: Text('${group.items.first.title} (${group.items.length})', maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text('${group.mediaType} · ${group.releaseYear?.toString() ?? 'year unknown'}${_reviewedDuplicates.contains(group.key) ? ' · reviewed' : ''}'),
              children: [
                for (final item in group.items)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.movie_outlined),
                    title: Text(item.title),
                    subtitle: Text([item.type, if (item.editionName?.isNotEmpty == true) item.editionName!, if (item.editionType?.isNotEmpty == true) item.editionType!, 'ID: ${item.id}'].join(' · ')),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MediaDetailsScreen(media: item))),
                  ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _reviewedDuplicates.contains(group.key) ? null : () => _reviewDuplicate(group),
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(_reviewedDuplicates.contains(group.key) ? 'Reviewed' : 'Mark reviewed'),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _repairTab(List<LibraryAuditFinding> findings) {
    if (findings.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No unreviewed artwork, description, playback-source, or release-date findings were detected.')));
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 2, 4, 10),
          child: Text('These checks identify missing fields; they do not guess a replacement match. Open the title to inspect it, then correct the metadata at the authoritative source.', style: TextStyle(color: Colors.white60, height: 1.4)),
        ),
        for (final finding in findings)
          Card(
            child: ListTile(
              leading: Icon(_findingIcon(finding.category)),
              title: Text(finding.title, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text('${finding.category} — ${finding.description}'),
              isThreeLine: true,
              onTap: () {
                final matches = AppController.instance.library.where((item) => item.id == finding.mediaId);
                if (matches.isNotEmpty) {
                  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MediaDetailsScreen(media: matches.first)));
                }
              },
              trailing: PopupMenuButton<String>(
                tooltip: 'Review finding',
                onSelected: (value) {
                  if (value == 'review') unawaited(_reviewFinding(finding));
                },
                itemBuilder: (_) => const [PopupMenuItem(value: 'review', child: Text('Mark reviewed'))],
              ),
            ),
          ),
      ],
    );
  }

  Widget _historyTab() {
    final rows = <Widget>[];
    rows.add(const Card(
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Text('This is a local protection-center action log plus automatic settings backup checkpoints. It does not yet provide field-by-field undo for metadata edited elsewhere or remote database rows.', style: TextStyle(color: Colors.white60, height: 1.4)),
      ),
    ));
    for (final record in _backups) {
      rows.add(Card(
        child: ListTile(
          leading: Icon(record.isLatest ? Icons.history_toggle_off_rounded : Icons.restore_rounded),
          title: Text('${record.isLatest ? 'Latest checkpoint' : 'Recovery point'} · ${_timestamp(record.createdAt)}'),
          subtitle: Text('${record.preferenceCount} setting(s) · ${record.reason.replaceAll('_', ' ')}'),
          trailing: TextButton(
            onPressed: _busy ? null : () => _restore(record),
            child: const Text('Restore'),
          ),
        ),
      ));
    }
    rows.add(const Padding(
      padding: EdgeInsets.fromLTRB(4, 12, 4, 6),
      child: Text('Recent protection-center actions', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
    ));
    if (_events.isEmpty) {
      rows.add(const Card(child: Padding(padding: EdgeInsets.all(14), child: Text('No actions recorded in this center yet.'))));
    }
    for (final event in _events) {
      final at = DateTime.tryParse(event['at']?.toString() ?? '');
      rows.add(Card(
        child: ListTile(
          leading: const Icon(Icons.receipt_long_outlined),
          title: Text((event['action']?.toString() ?? 'action').replaceAll('_', ' ')),
          subtitle: Text('${event['detail'] ?? ''}${at == null ? '' : '\n${_timestamp(at)}'}'),
          isThreeLine: true,
        ),
      ));
    }
    return ListView(padding: const EdgeInsets.all(12), children: rows);
  }

  IconData _findingIcon(String category) => switch (category) {
        'Missing artwork' => Icons.image_not_supported_outlined,
        'Missing description' => Icons.description_outlined,
        'No playback source' => Icons.link_off_rounded,
        'Missing release date' => Icons.event_busy_outlined,
        _ => Icons.info_outline_rounded,
      };

  Widget _metricChip(String label, String value) => Chip(
        avatar: const Icon(Icons.circle, size: 8),
        label: Text('$label: $value'),
      );

  Widget _metricCard({required IconData icon, required String title, required String detail, required Color color}) => Card(
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: color, size: 25),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              const SizedBox(height: 5),
              Text(detail, style: const TextStyle(color: Colors.white60, height: 1.4, fontSize: 12)),
            ])),
          ]),
        ),
      );
}

/// Dedicated repair queue that can also be opened from the Library tab.
class LibraryRepairCenterScreen extends StatelessWidget {
  const LibraryRepairCenterScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const LibraryProtectionCenterScreen(initialTabIndex: 2);
}
