// Home server and ARM administration screen for the Flutter client.
import 'package:flutter/material.dart';
import 'app_core.dart';
import 'storage_dashboard.dart';
import 'music.dart';

class HomeServerScreen extends StatefulWidget {
  const HomeServerScreen({super.key});
  @override State<HomeServerScreen> createState() => _HomeServerScreenState();
}

class _HomeServerScreenState extends State<HomeServerScreen> {
  bool loading = true;
  String? error;
  Map<String, dynamic>? storage;
  Map<String, dynamic>? arm;

  /// Loads both server-storage and ARM connection status from the backend.
  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (!AppController.instance.backendApi.isAuthenticated) {
      setState(() { loading = false; error = 'Sign in to connect to the home server.'; });
      return;
    }
    setState(() { loading = true; error = null; });
    try {
      final api = AppController.instance.backendApi;
      final values = await Future.wait([api.getHomeServerStorage(), api.getHomeServerArm()]);
      if (!mounted) return;
      setState(() { storage = values[0]; arm = values[1]; loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { loading = false; error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  /// Builds the server dashboard and explains the physical ARM-to-library pipeline.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home Server & ARM'), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))]),
      body: loading ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(20), children: [
        if (error != null) Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(error!, style: const TextStyle(color: Colors.orangeAccent)))),
        _infoCard('Architecture', 'Optical drive → ARM → completed media → server importer → database → Flutter. ARM performs ripping; the home server owns storage and library metadata.', Icons.account_tree_rounded),
        _statusCard('ARM connection', arm?['connected'] == true, '${arm?['armServerUrl'] ?? 'Not configured'}\nMedia root: ${arm?['mediaRoot'] ?? 'Unknown'}'),
        _statusCard('Server storage', storage != null, storage == null ? 'Unavailable' : '${storage!['root']}'),
        if (storage != null) ...[
          const SizedBox(height: 8),
          for (final c in (storage!['categories'] as List? ?? const [])) _category(c),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: _syncLibrary, icon: const Icon(Icons.sync_rounded), label: const Text('Scan & sync server library')),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StorageDashboardScreen())), icon: const Icon(Icons.storage_rounded), label: const Text('Open storage manager')),
        ],
        const SizedBox(height: 20),
        _infoCard('Physical setup', 'Connect a DVD/Blu-ray/UHD-capable optical drive to the ARM host. Configure the exact drive/firmware for UHD support, then point ARM at the server media directories. Do not assume every Blu-ray drive supports UHD ripping.', Icons.album_rounded),
      ]),
    );
  }

  /// Scans ARM's completed-media directories and loads discovered titles into Flutter.
  Future<void> _syncLibrary() async {
    try {
      final data = await AppController.instance.backendApi.scanServerLibrary();
      final raw = data['media'];
      if (raw is! List) return;
      final serverApi = AppController.instance.backendApi;
      final media = raw.whereType<Map>().where((m) => m['type']?.toString() != 'music').map((m) => MediaItem(
        id: m['id']?.toString() ?? '',
        title: m['title']?.toString() ?? 'Imported Media',
        type: m['type']?.toString() ?? 'movie',
        description: 'Imported from the home server media library.',
      )).toList();
      final music = raw.whereType<Map>().where((m) => m['type']?.toString() == 'music').map((m) => MusicTrack(
        id: m['id']?.toString() ?? '',
        title: m['title']?.toString() ?? 'Imported Song',
        artist: 'Imported Artist',
        album: 'Server Library',
        audioUrl: '${serverApi.baseUrl}/library/stream?path=${Uri.encodeComponent(m['id']?.toString() ?? '')}',
      )).toList();
      MusicLibraryStore.instance.tracks
        ..clear()
        ..addAll(music);
      AppController.instance.replaceLibraryFromServer(media);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Synced ${media.length} server media files.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Widget _infoCard(String title, String body, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(body, style: const TextStyle(color: Colors.white70, height: 1.45)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusCard(String title, bool ok, String body) {
    return Card(
      child: ListTile(
        leading: Icon(ok ? Icons.check_circle : Icons.error_outline, color: ok ? Colors.greenAccent : Colors.orangeAccent),
        title: Text(title),
        subtitle: Text(body),
      ),
    );
  }

  Widget _category(dynamic raw) {
    final c = Map<String, dynamic>.from(raw as Map);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.folder_rounded),
        title: Text(c['name']?.toString() ?? 'Media'),
        subtitle: Text(c['path']?.toString() ?? ''),
        trailing: Text(StorageDashboardScreen.formatBytes((c['usedBytes'] as num?)?.toInt() ?? 0)),
      ),
    );
  }
}
