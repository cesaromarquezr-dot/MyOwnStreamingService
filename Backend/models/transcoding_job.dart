// FILE: Backend/models/transcoding_job.dart.
// Purpose: Tracks a cached server-side transcode prepared for playback.

class TranscodingJob {
  final String id;
  final String inputPath;
  final String outputRelativePath;
  final String status;
  final PlaybackJobProfile profile;
  final String? error;

  const TranscodingJob({
    required this.id,
    required this.inputPath,
    required this.outputRelativePath,
    required this.status,
    required this.profile,
    this.error,
  });
}

class PlaybackJobProfile {
  final String videoCodec;
  final String audioCodec;
  final String container;
  final int width;
  final int height;
  final int bitrateKbps;

  const PlaybackJobProfile({
    this.videoCodec = 'h264',
    this.audioCodec = 'aac',
    this.container = 'mp4',
    this.width = 1920,
    this.height = 1080,
    this.bitrateKbps = 6000,
  });
}
