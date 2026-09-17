// FILE: `Backend/models/media_work.dart`.
// Purpose: Canonical global media-work model shared by movies, shows, music,
// music videos, extras, trailers and future media types.

class MediaWork {
  final String id;
  final String title;
  final String type;
  final int? releaseYear;
  final String? originalLanguage;
  final List<String> genres;
  final List<String> themes;
  final List<String> tags;
  final List<String> productionCountries;
  final List<String> settingCountries;
  final List<String> culturalAssociationCountries;
  final List<String> creatorOriginCountries;
  final List<String> sourceOriginCountries;
  final List<String> artistIds;
  final List<String> personIds;
  final List<String> franchiseIds;
  final List<String> albumIds;
  final List<String> songIds;
  final List<String> extraIds;
  final List<String> trailerIds;
  final List<String> musicVideoIds;
  final bool hasLyrics;

  const MediaWork({
    required this.id,
    required this.title,
    required this.type,
    this.releaseYear,
    this.originalLanguage,
    this.genres = const [],
    this.themes = const [],
    this.tags = const [],
    this.productionCountries = const [],
    this.settingCountries = const [],
    this.culturalAssociationCountries = const [],
    this.creatorOriginCountries = const [],
    this.sourceOriginCountries = const [],
    this.artistIds = const [],
    this.personIds = const [],
    this.franchiseIds = const [],
    this.albumIds = const [],
    this.songIds = const [],
    this.extraIds = const [],
    this.trailerIds = const [],
    this.musicVideoIds = const [],
    this.hasLyrics = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type,
        'releaseYear': releaseYear,
        'originalLanguage': originalLanguage,
        'genres': genres,
        'themes': themes,
        'tags': tags,
        'productionCountries': productionCountries,
        'settingCountries': settingCountries,
        'culturalAssociationCountries': culturalAssociationCountries,
        'creatorOriginCountries': creatorOriginCountries,
        'sourceOriginCountries': sourceOriginCountries,
        'artistIds': artistIds,
        'personIds': personIds,
        'franchiseIds': franchiseIds,
        'albumIds': albumIds,
        'songIds': songIds,
        'extraIds': extraIds,
        'trailerIds': trailerIds,
        'musicVideoIds': musicVideoIds,
        'hasLyrics': hasLyrics,
      };
}
