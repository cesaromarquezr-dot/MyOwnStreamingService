import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import 'app_core.dart';
import 'core/services/self_driving_network_engine.dart';

/// Downloads a single authorized media file for offline playback.
/// HLS/DASH manifests are deliberately refused; DRM-protected playback requires a licensed, format-aware vendor SDK. This downloader is for unencrypted single-file media that the signed-in user is authorized to save.
class OfflineDownloadsScreen extends StatefulWidget {
  const OfflineDownloadsScreen({super.key});

  @override
  State<OfflineDownloadsScreen> createState() => _OfflineDownloadsScreenState();
}

class _OfflineDownloadsScreenState extends State<OfflineDownloadsScreen> {
  static const int _maxFileBytes = 8 * 1024 * 1024 * 1024;
  final _titleController = TextEditingController();
  final _urlController = TextEditingController();
  final _client = SelfDrivingHttpClient(
    monitor: SelfDrivingNetworkMonitor.instance,
    allowSafeReadAutomation: false,
  );
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _downloading = false;
  double? _progress;
  String? _status;
  String? _error;

  String get _prefsKey {
    final profileId = AppController.instance.currentProfile?.id ?? 'default-profile';
    final encoded = base64Url.encode(utf8.encode(profileId)).replaceAll('=', '');
    return 'moss_offline_downloads_v1_$encoded';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    _client.close();
    super.dispose();
  }

  Future<Directory> _directory() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}offline_media');
    await dir.create(recursive: true);
    return dir;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      final list = raw == null ? const [] : jsonDecode(raw);
      final loaded = <Map<String, dynamic>>[];
      if (list is List) {
        for (final item in list.whereType<Map>()) {
          final map = Map<String, dynamic>.from(item);
          final path = map['path']?.toString() ?? '';
          if (path.isNotEmpty && await File(path).exists()) loaded.add(map);
        }
      }
      if (mounted) setState(() { _items = loaded; _loading = false; });
      await _saveMetadata();
    } catch (error) {
      if (mounted) setState(() { _error = 'Could not read offline downloads: $error'; _loading = false; });
    }
  }

  Future<void> _saveMetadata() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_items));
  }

  Uri _validateUrl(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.host.isEmpty || uri.userInfo.isNotEmpty ||
        !(uri.scheme == 'https' ||
          ((uri.scheme == 'http') && const {'localhost', '127.0.0.1', '::1'}.contains(uri.host)))) {
      throw const FormatException('Use a valid HTTPS media URL (HTTP is allowed only for localhost).');
    }
    final path = uri.path.toLowerCase();
    if (path.endsWith('.m3u8') || path.endsWith('.mpd') ||
        path.contains('master.m3u8') || path.contains('manifest.mpd')) {
      throw const FormatException('Offline download currently requires a direct single-file URL, not HLS/DASH.');
    }
    return uri;
  }

  Future<void> _download() async {
    if (_downloading) return;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Enter a title for this download.');
      return;
    }
    late final Uri uri;
    try {
      uri = _validateUrl(_urlController.text);
    } catch (error) {
      setState(() => _error = error.toString().replaceFirst('FormatException: ', ''));
      return;
    }
    final lowerPath = uri.path.toLowerCase();
    final ext = lowerPath.contains('.') ? lowerPath.substring(lowerPath.lastIndexOf('.') + 1) : '';
    const allowedExtensions = {'mp4', 'm4v', 'mkv', 'webm', 'mov', 'mp3', 'm4a', 'aac', 'wav', 'ogg', 'flac'};
    if (!allowedExtensions.contains(ext)) {
      setState(() => _error = 'Use a direct MP4/M4V/MKV/WebM/MOV or supported audio-file URL.');
      return;
    }

    setState(() { _downloading = true; _progress = null; _status = 'Connecting to the authorized media URL…'; _error = null; });
    File? partial;
    IOSink? sink;
    try {
      var requestUri = uri;
      late http.StreamedResponse response;
      for (var hop = 0; ; hop++) {
        final request = http.Request('GET', requestUri)..followRedirects = false;
        response = await _client.send(request).timeout(const Duration(seconds: 30));
        if (![301, 302, 303, 307, 308].contains(response.statusCode)) break;
        if (hop >= 5) {
          await response.stream.drain<void>();
          throw HttpException('The media URL redirected too many times.');
        }
        final location = response.headers['location'];
        if (location == null || location.trim().isEmpty) {
          await response.stream.drain<void>();
          throw HttpException('The media server returned a redirect without a Location header.');
        }
        final nextUri = requestUri.resolve(location);
        _validateUrl(nextUri.toString());
        if (requestUri.scheme == 'https' && nextUri.scheme != 'https') {
          await response.stream.drain<void>();
          throw const FormatException('Refusing a redirect that downgrades HTTPS to HTTP.');
        }
        await response.stream.drain<void>();
        requestUri = nextUri;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Media server returned HTTP ${response.statusCode}. Refresh any expired signed URL and retry.');
      }
      final contentType = (response.headers['content-type'] ?? '').toLowerCase();
      if (contentType.contains('text/html') || contentType.contains('application/json')) {
        throw const FormatException('The server returned a web page or API response, not media bytes.');
      }
      final total = response.contentLength;
      if (total != null && total > _maxFileBytes) {
        throw const FormatException('Files larger than 8 GiB are not supported by this offline downloader.');
      }
      final dir = await _directory();
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      final safeExtension = ext.replaceAll(RegExp(r'[^a-z0-9]'), '');
      partial = File('${dir.path}${Platform.pathSeparator}.$id.part');
      final destination = File('${dir.path}${Platform.pathSeparator}$id.$safeExtension');
      sink = partial.openWrite();
      var received = 0;
      var lastUpdate = 0;
      await for (final chunk in response.stream.timeout(const Duration(seconds: 45))) {
        received += chunk.length;
        if (received > _maxFileBytes) throw const FormatException('Download exceeded the 8 GiB limit.');
        sink.add(chunk);
        if (received - lastUpdate > 512 * 1024) {
          lastUpdate = received;
          if (mounted) {
            setState(() {
            _progress = total == null || total <= 0 ? null : received / total;
            _status = 'Downloaded ${_formatBytes(received)}${total == null ? '' : ' of ${_formatBytes(total)}'}';
          });
          }
        }
      }
      await sink.flush();
      await sink.close();
      sink = null;
      if (received < 1024) throw const FormatException('The returned file is too small to be valid media.');
      await partial.rename(destination.path);
      partial = null;
      if (!mounted) {
        try { await destination.delete(); } catch (_) {}
        return;
      }
      setState(() {
        _items.insert(0, {
          'id': id,
          'title': title,
          'path': destination.path,
          'bytes': received,
          'savedAt': DateTime.now().toUtc().toIso8601String(),
          'extension': safeExtension,
        });
        _status = 'Saved for offline playback.';
        _progress = 1;
        _titleController.clear();
        _urlController.clear();
      });
      await _saveMetadata();
    } catch (error) {
      try { await sink?.close(); } catch (_) {}
      try { if (partial != null && await partial.exists()) await partial.delete(); } catch (_) {}
      if (mounted) setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final path = item['path']?.toString() ?? '';
    try { if (path.isNotEmpty) await File(path).delete(); } catch (_) {}
    setState(() => _items.removeWhere((entry) => entry['id'] == item['id']));
    await _saveMetadata();
  }

  String _formatBytes(Object? raw) {
    final bytes = raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '') ?? 0;
    if (bytes >= 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GiB';
    if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KiB';
    return '$bytes B';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Offline downloads')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Save an authorized, unencrypted direct media file on this device. HLS/DASH manifests and DRM-managed offline playback need a format-aware licensed SDK and are not provided by this screen. Only download files you have rights to save; app-private storage may use substantial disk space.',
                  style: TextStyle(color: Colors.white70, height: 1.4),
                ),
                const SizedBox(height: 16),
                TextField(controller: _titleController, enabled: !_downloading, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: _urlController, enabled: !_downloading, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Authorized direct media URL', hintText: 'https://media.example/title.mp4', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                FilledButton.icon(onPressed: _downloading ? null : _download, icon: const Icon(Icons.download_rounded), label: Text(_downloading ? 'Downloading…' : 'Download for offline use')),
                if (_downloading) ...[
                  const SizedBox(height: 10),
                  LinearProgressIndicator(value: _progress),
                ],
                if (_status != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_status!, style: const TextStyle(color: Colors.lightGreenAccent))),
                if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
                const SizedBox(height: 20),
                Text('Saved files (${_items.length})', style: Theme.of(context).textTheme.titleLarge),
                if (_items.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 26), child: Text('No offline downloads yet.')),
                ..._items.map((item) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.offline_pin_rounded),
                    title: Text(item['title']?.toString() ?? 'Media file'),
                    subtitle: Text('${_formatBytes(item['bytes'])} • ${item['extension']?.toString().toUpperCase() ?? 'MEDIA'}'),
                    onTap: () => Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => _OfflineMediaPlayer(item: item))),
                    trailing: IconButton(tooltip: 'Delete download', onPressed: () => _delete(item), icon: const Icon(Icons.delete_outline_rounded)),
                  ),
                )),
              ],
            ),
    );
  }
}

class _OfflineMediaPlayer extends StatefulWidget {
  const _OfflineMediaPlayer({required this.item});
  final Map<String, dynamic> item;
  @override
  State<_OfflineMediaPlayer> createState() => _OfflineMediaPlayerState();
}

class _OfflineMediaPlayerState extends State<_OfflineMediaPlayer> {
  VideoPlayerController? _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final file = File(widget.item['path'].toString());
    final player = VideoPlayerController.file(file);
    try {
      await player.initialize();
      await player.setLooping(false);
      if (!mounted) { await player.dispose(); return; }
      setState(() => _controller = player);
    } catch (error) {
      await player.dispose();
      if (mounted) setState(() => _error = 'This device cannot play this file format: $error');
    }
  }

  @override
  void dispose() {
    final player = _controller;
    if (player != null) player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = _controller;
    return Scaffold(
      appBar: AppBar(title: Text(widget.item['title']?.toString() ?? 'Offline media')),
      body: Center(
        child: _error != null
            ? Padding(padding: const EdgeInsets.all(24), child: Text(_error!))
            : player == null || !player.value.isInitialized
                ? const CircularProgressIndicator()
                : Column(mainAxisSize: MainAxisSize.min, children: [
                    AspectRatio(aspectRatio: player.value.aspectRatio == 0 ? 16 / 9 : player.value.aspectRatio, child: VideoPlayer(player)),
                    VideoProgressIndicator(player, allowScrubbing: true),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      IconButton(iconSize: 40, onPressed: () => setState(() => player.value.isPlaying ? player.pause() : player.play()), icon: Icon(player.value.isPlaying ? Icons.pause_circle : Icons.play_circle)),
                    ]),
                  ]),
      ),
    );
  }
}
