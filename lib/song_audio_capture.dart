import 'song_audio_capture_io.dart'
    if (dart.library.html) 'song_audio_capture_web.dart' as platform;

export 'song_audio_sample.dart';
import 'song_audio_sample.dart';

class SongAudioCapture {
  Future<void> start() => platform.start();
  Future<SongAudioSample> stop() => platform.stop();
  Future<void> dispose() => platform.dispose();
}
