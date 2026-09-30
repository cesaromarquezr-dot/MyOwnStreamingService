// FILE: Backend/models/tv_intro.dart
// Purpose: Version-bound TV opening/intro metadata for the TV Intro Library.
//
// The backend stores safe media/version identifiers and offsets. It never
// exposes a private home-server filesystem path to Flutter.

class TvIntro {
  final String id;
  final String seriesId;
  final String seriesTitle;
  final String mediaVersionId;
  final int startMs;
  final int endMs;
  final String? seasonLabel;
  final String? episodeLabel;
  final String source;

  const TvIntro({
    required this.id,
    required this.seriesId,
    required this.seriesTitle,
    required this.mediaVersionId,
    required this.startMs,
    required this.endMs,
    this.seasonLabel,
    this.episodeLabel,
    this.source = 'home_server_index',
  });

  bool get isValid =>
      id.isNotEmpty &&
      seriesId.isNotEmpty &&
      mediaVersionId.isNotEmpty &&
      startMs >= 0 &&
      endMs > startMs;

  Map<String, dynamic> toJson() => {
        'id': id,
        'seriesId': seriesId,
        'seriesTitle': seriesTitle,
        'mediaVersionId': mediaVersionId,
        'startMs': startMs,
        'endMs': endMs,
        'seasonLabel': seasonLabel,
        'episodeLabel': episodeLabel,
        'source': source,
      };
}
