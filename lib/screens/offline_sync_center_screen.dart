import 'package:material_ui/material_ui.dart';

import '../accessibility_offline_settings.dart';
import '../app_core.dart';
import '../offline_downloads.dart';
import '../offline_metadata_cache.dart';
import '../offline_sync_queue.dart';

/// One view of local metadata availability, queued account changes, and
/// authorized offline media files. It keeps metadata cache separate from media.
class OfflineSyncCenterScreen extends StatefulWidget {
  const OfflineSyncCenterScreen({super.key});

  @override
  State<OfflineSyncCenterScreen> createState() =>
      _OfflineSyncCenterScreenState();
}

class _OfflineSyncCenterScreenState extends State<OfflineSyncCenterScreen> {
  List<PendingSyncAction> _pending = const <PendingSyncAction>[];
  int _cachedItems = 0;
  bool _loading = true;
  bool _syncing = false;
  String? _error;

  String get _profileId =>
      AppController.instance.currentProfile?.id ?? 'default';
  String get _accountId => AppController.instance.currentAccount?.id ?? 'local';
  OfflineSyncQueue get _queue => OfflineSyncQueue(scopeId: _accountId);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await Future.wait<dynamic>([
        _queue.list(),
        OfflineMetadataCache(profileId: _profileId).load(),
      ]);
      if (!mounted) return;
      setState(() {
        _pending = values[0] as List<PendingSyncAction>;
        _cachedItems = (values[1] as List<Map<String, dynamic>>).length;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _syncNow() async {
    final app = AppController.instance;
    if (!app.backendApi.isAuthenticated || app.currentAccount == null) {
      setState(() => _error =
          'Sign in to synchronize account changes. Local playback and queued changes remain on this device.');
      return;
    }
    setState(() {
      _syncing = true;
      _error = null;
    });
    try {
      await app.syncCurrentAccountToSupabase();
      // Clear only after the authenticated account snapshot completed.
      await _queue.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account snapshot synchronized.')));
      await _load();
    } catch (error) {
      if (mounted) {
        setState(
            () => _error = error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _open(Widget screen) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final app = AppController.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Offline & Sync Center'), actions: [
        IconButton(
            tooltip: 'Refresh status',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded))
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              if (_error != null)
                Card(
                    child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(_error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)))),
              Card(
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Connection status',
                                style: TextStyle(
                                    fontSize: 19, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 6),
                            Row(children: [
                              Icon(
                                  app.backendApi.isAuthenticated
                                      ? Icons.cloud_done_rounded
                                      : Icons.cloud_off_rounded,
                                  color: app.backendApi.isAuthenticated
                                      ? Colors.green
                                      : Colors.orange),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(app.backendApi.isAuthenticated
                                      ? 'Authenticated account connection'
                                      : 'Local / signed-out mode'))
                            ]),
                            const SizedBox(height: 12),
                            Wrap(spacing: 9, runSpacing: 9, children: [
                              _Metric(
                                  label: 'Queued changes',
                                  value: '${_pending.length}',
                                  icon: Icons.sync_rounded),
                              _Metric(
                                  label: 'Cached metadata',
                                  value: '$_cachedItems',
                                  icon: Icons.image_outlined),
                              _Metric(
                                  label: 'Current profile',
                                  value: app.currentProfile?.name ?? 'None',
                                  icon: Icons.person_outline_rounded),
                            ]),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                                onPressed: _syncing ? null : _syncNow,
                                icon: const Icon(Icons.cloud_sync_rounded),
                                label: Text(_syncing
                                    ? 'Synchronizing…'
                                    : 'Synchronize account snapshot')),
                          ]))),
              const SizedBox(height: 8),
              const ListTile(
                  title: Text('Pending changes'),
                  subtitle: Text(
                      'Playback progress changes are queued locally while offline. The queue is retained if synchronization fails.')),
              if (_pending.isEmpty)
                const Card(
                    child: ListTile(
                        leading: Icon(Icons.check_circle_outline_rounded),
                        title: Text('No pending changes')))
              else
                ..._pending.map((item) => Card(
                    child: ListTile(
                        leading: const Icon(Icons.pending_actions_rounded),
                        title: Text(item.type.replaceAll('_', ' ')),
                        subtitle: Text(
                            '${item.profileId} · ${item.resourceId} · ${item.queuedAt.toLocal()}')))),
              const SizedBox(height: 12),
              Card(
                  child: Column(children: [
                ListTile(
                    leading: const Icon(Icons.download_for_offline_rounded),
                    title: const Text('Offline media downloads'),
                    subtitle: const Text(
                        'Manage authorized local media files stored on this device.'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _open(const OfflineDownloadsScreen())),
                const Divider(height: 1),
                ListTile(
                    leading: const Icon(Icons.tune_rounded),
                    title: const Text('Offline metadata & privacy settings'),
                    subtitle: const Text(
                        'Control metadata caching, privacy and retryable sync settings.'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () =>
                        _open(const AccessibilityOfflineSettingsScreen())),
              ])),
              const SizedBox(height: 12),
              const Card(
                  child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Text(
                          'Important: cached posters and catalog descriptions are not offline media files. Offline video/audio playback is available only for files successfully downloaded or stored locally and supported by the player. This screen does not copy your entire media library to the cloud.'))),
            ]),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 17),
        const SizedBox(width: 7),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(label, style: Theme.of(context).textTheme.bodySmall)
        ])
      ]));
}
