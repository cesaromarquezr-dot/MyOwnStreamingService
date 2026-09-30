/// A season belongs to one television production. Season numbers are scoped
/// to that production, so a sequel series can begin again at season 1.
class MediaSeason {
  final String id;
  final String seriesId;
  final int seasonNumber;
  final String? title;
  final int? startYear;
  final int? endYear;
  final int? episodeCount;

  const MediaSeason({
    required this.id,
    required this.seriesId,
    required this.seasonNumber,
    this.title,
    this.startYear,
    this.endYear,
    this.episodeCount,
  });

  bool get isValid => id.trim().isNotEmpty && seriesId.trim().isNotEmpty && seasonNumber >= 0;

  factory MediaSeason.fromJson(Map<String, dynamic> json) => MediaSeason(
        id: (json['id'] ?? '').toString(),
        seriesId: (json['seriesId'] ?? '').toString(),
        seasonNumber: _intValue(json['seasonNumber']) ?? -1,
        title: json['title']?.toString(),
        startYear: _intValue(json['startYear']),
        endYear: _intValue(json['endYear']),
        episodeCount: _intValue(json['episodeCount']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'seriesId': seriesId,
        'seasonNumber': seasonNumber,
        'title': title,
        'startYear': startYear,
        'endYear': endYear,
        'episodeCount': episodeCount,
      };
}

int? _intValue(dynamic value) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
