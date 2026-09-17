// FILE: Backend/models/playback_profile.dart.
// Purpose: Represents the server's playback decision for one media request.

class PlaybackProfile {
  final String mode; // directPlay, remux, audioTranscode, transcode
  final String videoCodec;
  final String audioCodec;
  final String container;
  final int? width;
  final int? height;
  final int? bitrateKbps;
  final String? reason;

  const PlaybackProfile({
    required this.mode,
    required this.videoCodec,
    required this.audioCodec,
    required this.container,
    this.width,
    this.height,
    this.bitrateKbps,
    this.reason,
  });

  Map<String, dynamic> toJson() => {
        'mode': mode,
        'videoCodec': videoCodec,
        'audioCodec': audioCodec,
        'container': container,
        'width': width,
        'height': height,
        'bitrateKbps': bitrateKbps,
        'reason': reason,
      };
}
