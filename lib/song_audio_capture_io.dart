import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'song_audio_sample.dart';

final AudioRecorder _recorder = AudioRecorder();
String? _recordPath;

Future<void> start() async {
  if (!await _recorder.hasPermission()) {
    throw StateError('Microphone permission is required to identify a song.');
  }
  final temp = await getTemporaryDirectory();
  _recordPath = '${temp.path}${Platform.pathSeparator}moss-song-id-${DateTime.now().millisecondsSinceEpoch}.m4a';
  await _recorder.start(
    const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 96000, sampleRate: 44100),
    path: _recordPath!,
  );
}

Future<SongAudioSample> stop() async {
  final path = await _recorder.stop() ?? _recordPath;
  _recordPath = null;
  if (path == null) throw StateError('No microphone sample was saved.');
  final file = File(path);
  if (!await file.exists()) throw StateError('No microphone sample was saved.');
  try {
    return SongAudioSample(bytes: await file.readAsBytes(), mimeType: 'audio/mp4');
  } finally {
    try { await file.delete(); } catch (_) {}
  }
}

Future<void> dispose() async {
  try { await _recorder.stop(); } catch (_) {}
  await _recorder.dispose();
  final path = _recordPath;
  _recordPath = null;
  if (path != null) { try { await File(path).delete(); } catch (_) {} }
}
