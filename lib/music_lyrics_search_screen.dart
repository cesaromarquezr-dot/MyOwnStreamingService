// FILE: `lib/music_lyrics_search_screen.dart`.
// Purpose: User-initiated lyrics search and short-sample song recognition.
// Only provider metadata is displayed; full copyrighted lyric text is not stored.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_core.dart';

class MusicLyricsSearchScreen extends StatefulWidget {
  const MusicLyricsSearchScreen({super.key});

  @override
  State<MusicLyricsSearchScreen> createState() => _MusicLyricsSearchScreenState();
}

class _MusicLyricsSearchScreenState extends State<MusicLyricsSearchScreen> {
  final TextEditingController _lyricsController = TextEditingController();
  final AudioRecorder _recorder = AudioRecorder();
  Timer? _timer;
  int _secondsLeft = 10;
  bool _recording = false;
  bool _loading = false;
  bool _recognizing = false;
  String? _error;
  String? _message;
  List<Map<String, dynamic>> _matches = <Map<String, dynamic>>[];
  Map<String, dynamic>? _identified;
  String? _recordPath;
  int _requestId = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _lyricsController.dispose();
    // Stop capture before removing the temporary sample so leaving this screen
    // never leaves the microphone recording in the background.
    unawaited(_cleanupTemporaryRecording());
    super.dispose();
  }

  Future<void> _cleanupTemporaryRecording() async {
    final path = _recordPath;
    try {
      if (_recording) await _recorder.stop();
    } catch (_) {}
    try {
      await _recorder.dispose();
    } catch (_) {}
    if (path != null) {
      try { await File(path).delete(); } catch (_) {}
    }
  }

  Future<void> _searchLyrics() async {
    final phrase = _lyricsController.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (phrase.length < 3) {
      setState(() {
        _error = 'Enter at least three characters from a lyric you remember.';
        _message = null;
        _matches = <Map<String, dynamic>>[];
      });
      return;
    }
    if (!AppController.instance.isBackendAuthenticated) {
      setState(() => _error = 'Sign in to your MyOwnStreamingService backend first.');
      return;
    }
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
      _message = null;
      _identified = null;
    });
    try {
      final payload = await AppController.instance.backendApi.searchMusicByLyrics(phrase);
      if (!mounted || requestId != _requestId) return;
      final rows = payload['items'];
      setState(() {
        _matches = rows is List
            ? rows.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList()
            : <Map<String, dynamic>>[];
        _message = payload['message']?.toString();
        _error = null;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _matches = <Map<String, dynamic>>[];
        _error = error.toString().replaceFirst('BackendApiException: ', '');
      });
    } finally {
      if (mounted && requestId == _requestId) setState(() => _loading = false);
    }
  }

  Future<void> _startRecognition() async {
    if (_recording || _recognizing) return;
    if (!AppController.instance.isBackendAuthenticated) {
      setState(() => _error = 'Sign in to your MyOwnStreamingService backend first.');
      return;
    }
    try {
      final permitted = await _recorder.hasPermission();
      if (!permitted) {
        setState(() => _error = 'Microphone permission is required to identify a song.');
        return;
      }
      final temp = await getTemporaryDirectory();
      final path = '${temp.path}${Platform.pathSeparator}moss-song-id-${DateTime.now().millisecondsSinceEpoch}.m4a';
      _recordPath = path;
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 96000, sampleRate: 44100),
        path: path,
      );
      if (!mounted) {
        await _recorder.stop();
        return;
      }
      setState(() {
        _recording = true;
        _secondsLeft = 10;
        _error = null;
        _message = 'Listening for up to 10 seconds. Keep the music audible near your microphone.';
        _identified = null;
        _matches = <Map<String, dynamic>>[];
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() => _secondsLeft = (10 - timer.tick).clamp(0, 10).toInt());
        if (timer.tick >= 10) unawaited(_finishRecognition());
      });
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not start microphone recording: $error');
    }
  }

  Future<void> _finishRecognition() async {
    if (_recognizing) return;
    _timer?.cancel();
    _timer = null;
    setState(() {
      _recording = false;
      _recognizing = true;
      _loading = true;
      _error = null;
      _message = 'Checking the audio sample against the song-recognition provider…';
    });
    try {
      final stoppedPath = await _recorder.stop();
      final path = stoppedPath ?? _recordPath;
      if (path == null || !await File(path).exists()) {
        throw StateError('No microphone sample was saved.');
      }
      final bytes = await File(path).readAsBytes();
      final payload = await AppController.instance.backendApi.identifySongFromAudio(bytes, mimeType: 'audio/mp4');
      if (!mounted) return;
      setState(() {
        _identified = payload['matched'] == true ? Map<String, dynamic>.from(payload) : null;
        _message = payload['message']?.toString();
        _error = payload['success'] == false ? (payload['message']?.toString() ?? 'Song identification is not configured.') : null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('BackendApiException: ', ''));
    } finally {
      final path = _recordPath;
      _recordPath = null;
      if (path != null) {
        try { await File(path).delete(); } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _recognizing = false;
          _loading = false;
        });
      }
    }
  }

  Future<void> _openProvider(String? raw) async {
    final value = raw?.trim() ?? '';
    final uri = Uri.tryParse(value);
    if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final matched = _identified;
    return Scaffold(
      appBar: AppBar(title: const Text('Find a Song')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          const Text('Remember a lyric? Search a short phrase. Or record a few seconds of music to identify the song.',
              style: TextStyle(color: Colors.white70, height: 1.45)),
          const SizedBox(height: 18),
          const Text('SEARCH BY LYRICS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.1)),
          const SizedBox(height: 8),
          TextField(
            controller: _lyricsController,
            minLines: 1,
            maxLines: 3,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _searchLyrics(),
            decoration: const InputDecoration(
              hintText: 'Type a lyric phrase you remember…',
              prefixIcon: Icon(Icons.lyrics_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _loading ? null : _searchLyrics,
            icon: const Icon(Icons.search_rounded),
            label: const Text('Find songs with these lyrics'),
          ),
          const Divider(height: 32),
          const Text('IDENTIFY BY LISTENING', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.1)),
          const SizedBox(height: 6),
          const Text('Record a short sample; it is sent securely to the configured recognition provider for this request only.',
              style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4)),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _loading ? null : (_recording ? _finishRecognition : _startRecognition),
            icon: Icon(_recording ? Icons.stop_rounded : Icons.mic_rounded),
            label: Text(_recording ? 'Identify now · ${_secondsLeft}s left' : 'Listen and identify a song'),
          ),
          if (_recording) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: (10 - _secondsLeft) / 10),
          ],
          if (_loading && !_recording) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: const TextStyle(color: Colors.orangeAccent, height: 1.4)),
          ],
          if ((_message ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(_message!, style: const TextStyle(color: Colors.white60, height: 1.4)),
          ],
          if (matched != null) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.music_note_rounded)),
                title: Text(matched['title']?.toString() ?? 'Unknown title', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(<String>[
                  matched['artist']?.toString() ?? '',
                  if ((matched['album']?.toString() ?? '').trim().isNotEmpty) matched['album'].toString(),
                  if ((matched['releaseDate']?.toString() ?? '').trim().isNotEmpty) matched['releaseDate'].toString(),
                ].where((s) => s.trim().isNotEmpty).join(' · ')),
                trailing: IconButton(
                  tooltip: 'Open song source',
                  onPressed: () => _openProvider(matched['spotifyUrl']?.toString().isNotEmpty == true ? matched['spotifyUrl']?.toString() : matched['songLink']?.toString()),
                  icon: const Icon(Icons.open_in_new_rounded),
                ),
              ),
            ),
          ],
          if (_matches.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('MATCHES (${_matches.length})', style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.1)),
            for (final row in _matches)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.music_note_rounded),
                title: Text(row['title']?.toString() ?? 'Unknown title', maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(<String>[row['artist']?.toString() ?? '', row['album']?.toString() ?? ''].where((v) => v.trim().isNotEmpty).join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  tooltip: 'Open provider result',
                  onPressed: () => _openProvider(row['providerUrl']?.toString()),
                  icon: const Icon(Icons.open_in_new_rounded),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
