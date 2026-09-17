// FILE: Backend/models/media_capabilities.dart.
// Purpose: Describes the codecs, containers, audio formats, and display limits a playback device can handle.

class MediaCapabilities {
  final List<String> videoCodecs;
  final List<String> audioCodecs;
  final List<String> containers;
  final int maxWidth;
  final int maxHeight;
  final bool hdr;

  const MediaCapabilities({
    this.videoCodecs = const ['h264'],
    this.audioCodecs = const ['aac'],
    this.containers = const ['mp4'],
    this.maxWidth = 1920,
    this.maxHeight = 1080,
    this.hdr = false,
  });

  factory MediaCapabilities.fromJson(Map<String, dynamic> json) {
    List<String> list(dynamic value, List<String> fallback) {
      if (value is List) {
        return value.map((e) => e.toString().toLowerCase()).toSet().toList();
      }
      return fallback;
    }

    return MediaCapabilities(
      videoCodecs: list(json['videoCodecs'], const ['h264']),
      audioCodecs: list(json['audioCodecs'], const ['aac']),
      containers: list(json['containers'], const ['mp4']),
      maxWidth: int.tryParse('${json['maxWidth'] ?? 1920}') ?? 1920,
      maxHeight: int.tryParse('${json['maxHeight'] ?? 1080}') ?? 1080,
      hdr: json['hdr'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'videoCodecs': videoCodecs,
        'audioCodecs': audioCodecs,
        'containers': containers,
        'maxWidth': maxWidth,
        'maxHeight': maxHeight,
        'hdr': hdr,
      };
}
