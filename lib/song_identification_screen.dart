import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_core.dart';

class SongIdentificationScreen extends StatefulWidget {
  const SongIdentificationScreen({super.key});

  @override
  State<SongIdentificationScreen> createState() =>
      _SongIdentificationScreenState();
}

class _SongIdentificationScreenState extends State<SongIdentificationScreen> {
  final AudioRecorder _recorder = AudioRecorder();
  Timer? _timer;
  int _secondsLeft = 10;
  bool _recording = false;
  bool _loading = false;
  String? _error;
  String? _message;
  String? _recordPath;
  Map<String, dynamic>? _identified;

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_cleanupRecording());
    super.dispose();
  }

  Future<void> _cleanupRecording() async {
    final path = _recordPath;
    try {
      if (_recording) await _recorder.stop();
    } catch (_) {}
    try {
      await _recorder.dispose();
    } catch (_) {}
    if (path != null) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
  }

  Future<void> _startRecognition() async {
    if (_recording || _loading) return;
    if (!AppController.instance.isBackendAuthenticated) {
      setState(() {
        _error = 'Sign in to your MyOwnStreamingService backend first.';
      });
      return;
    }
    try {
      final permitted = await _recorder.hasPermission();
      if (!mounted) return;
      if (!permitted) {
        setState(() {
          _error = 'Microphone permission is required to identify a song.';
        });
        return;
      }
      final temp = await getTemporaryDirectory();
      final path =
          '${temp.path}${Platform.pathSeparator}moss-song-id-${DateTime.now().millisecondsSinceEpoch}.m4a';
      _recordPath = path;
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 96000,
          sampleRate: 44100,
        ),
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
        _message =
            'Listening for up to 10 seconds. Keep the music audible near your microphone.';
        _identified = null;
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
      if (mounted) {
        setState(() => _error = 'Could not start microphone recording: $error');
      }
    }
  }

  Future<void> _finishRecognition() async {
    if (!_recording || _loading) return;
    _timer?.cancel();
    _timer = null;
    setState(() {
      _recording = false;
      _loading = true;
      _error = null;
      _message =
          'Checking the audio sample against the song-recognition provider…';
    });
    try {
      final stoppedPath = await _recorder.stop();
      final path = stoppedPath ?? _recordPath;
      if (path == null || !await File(path).exists()) {
        throw StateError('No microphone sample was saved.');
      }
      final bytes = await File(path).readAsBytes();
      final payload = await AppController.instance.backendApi
          .identifySongFromAudio(bytes, mimeType: 'audio/mp4');
      if (!mounted) return;
      setState(() {
        _identified = payload['matched'] == true
            ? Map<String, dynamic>.from(payload)
            : null;
        _message = payload['message']?.toString();
        _error = payload['success'] == false
            ? (payload['message']?.toString() ??
                'Song identification is not configured.')
            : null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString().replaceFirst('BackendApiException: ', '');
        });
      }
    } finally {
      final path = _recordPath;
      _recordPath = null;
      if (path != null) {
        try {
          await File(path).delete();
        } catch (_) {}
      }
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openProvider(String? raw) async {
    final uri = Uri.tryParse(raw?.trim() ?? '');
    if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final matched = _identified;
    final providerUrl = matched == null
        ? null
        : (matched['spotifyUrl']?.toString().trim().isNotEmpty == true
            ? matched['spotifyUrl']?.toString()
            : matched['songLink']?.toString());
    return Scaffold(
      appBar: AppBar(title: const Text('Identify Song by Audio')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          const Text(
            'Record a short sample to identify music playing nearby. The sample is sent securely to the configured recognition provider for this request only.',
            style: TextStyle(color: Colors.white70, height: 1.45),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _loading
                ? null
                : (_recording ? _finishRecognition : _startRecognition),
            icon: Icon(_recording ? Icons.stop_rounded : Icons.mic_rounded),
            label: Text(_recording
                ? 'Identify now · ${_secondsLeft}s left'
                : 'Listen and identify a song'),
          ),
          if (_recording) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: (10 - _secondsLeft) / 10),
          ],
          if (_loading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(
              _error!,
              style: const TextStyle(
                color: Colors.orangeAccent,
                height: 1.4,
              ),
            ),
          ],
          if ((_message ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              _message!,
              style: const TextStyle(color: Colors.white60, height: 1.4),
            ),
          ],
          if (matched != null) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.music_note_rounded),
                ),
                title: Text(
                  matched['title']?.toString() ?? 'Unknown title',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  <String>[
                    matched['artist']?.toString() ?? '',
                    if ((matched['album']?.toString() ?? '').trim().isNotEmpty)
                      matched['album'].toString(),
                    if ((matched['releaseDate']?.toString() ?? '')
                        .trim()
                        .isNotEmpty)
                      matched['releaseDate'].toString(),
                  ].where((value) => value.trim().isNotEmpty).join(' · '),
                ),
                trailing: IconButton(
                  tooltip: 'Open song source',
                  onPressed: () => _openProvider(providerUrl),
                  icon: const Icon(Icons.open_in_new_rounded),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
