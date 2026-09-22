// FILE: `Backend/models/media_work.dart`.
// Purpose: Canonical global media-work model shared by movies, shows, music,
// music videos, extras, trailers and future media types.
//
// A MediaWork represents the canonical creative work, not a physical release,
// disc, file, edition, or individual playback session.
//
// Physical media and imported files should retain their provenance separately
// and may reference a MediaWork through the persistence/knowledge-graph layer.
//
// For music, a canonical work should not be confused with a physical album,
// soundtrack release, medium/disc, or audio file. Those entities can point to
// the same canonical song/recording through their own relationships.

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

  /// Whether this object has the minimum canonical identity required for
  /// persistence.
  bool get isValid =>
      id.trim().isNotEmpty &&
      title.trim().isNotEmpty &&
      type.trim().isNotEmpty;

  /// A normalized title useful for matching/search display logic.
  ///
  /// This does not establish canonical identity. Matching and deduplication
  /// should use stronger metadata and explicit identifiers where available.
  String get normalizedTitle => title.trim().toLowerCase();

  /// Whether this work represents a music-oriented entity.
  ///
  /// The type vocabulary remains extensible rather than being represented by
  /// a closed enum.
  bool get isMusic {
    final normalizedType = type.trim().toLowerCase();

    return normalizedType == 'music' ||
        normalizedType == 'song' ||
        normalizedType == 'recording' ||
        normalizedType == 'track' ||
        normalizedType == 'album' ||
        normalizedType == 'soundtrack';
  }

  /// Whether this work has any associated canonical song IDs.
  bool get hasSongs => songIds.isNotEmpty;

  /// Whether this work has any associated extras.
  bool get hasExtras => extraIds.isNotEmpty;

  /// Whether this work has trailers associated with it.
  bool get hasTrailers => trailerIds.isNotEmpty;

  /// Whether this work has associated music videos.
  bool get hasMusicVideos => musicVideoIds.isNotEmpty;

  /// Creates a modified copy without changing the original object.
  MediaWork copyWith({
    String? id,
    String? title,
    String? type,
    int? releaseYear,
    String? originalLanguage,
    List<String>? genres,
    List<String>? themes,
    List<String>? tags,
    List<String>? productionCountries,
    List<String>? settingCountries,
    List<String>? culturalAssociationCountries,
    List<String>? creatorOriginCountries,
    List<String>? sourceOriginCountries,
    List<String>? artistIds,
    List<String>? personIds,
    List<String>? franchiseIds,
    List<String>? albumIds,
    List<String>? songIds,
    List<String>? extraIds,
    List<String>? trailerIds,
    List<String>? musicVideoIds,
    bool? hasLyrics,
    bool clearReleaseYear = false,
    bool clearOriginalLanguage = false,
  }) {
    return MediaWork(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      releaseYear: clearReleaseYear ? null : (releaseYear ?? this.releaseYear),
      originalLanguage: clearOriginalLanguage
          ? null
          : (originalLanguage ?? this.originalLanguage),
      genres: genres ?? this.genres,
      themes: themes ?? this.themes,
      tags: tags ?? this.tags,
      productionCountries:
          productionCountries ?? this.productionCountries,
      settingCountries: settingCountries ?? this.settingCountries,
      culturalAssociationCountries:
          culturalAssociationCountries ?? this.culturalAssociationCountries,
      creatorOriginCountries:
          creatorOriginCountries ?? this.creatorOriginCountries,
      sourceOriginCountries:
          sourceOriginCountries ?? this.sourceOriginCountries,
      artistIds: artistIds ?? this.artistIds,
      personIds: personIds ?? this.personIds,
      franchiseIds: franchiseIds ?? this.franchiseIds,
      albumIds: albumIds ?? this.albumIds,
      songIds: songIds ?? this.songIds,
      extraIds: extraIds ?? this.extraIds,
      trailerIds: trailerIds ?? this.trailerIds,
      musicVideoIds: musicVideoIds ?? this.musicVideoIds,
      hasLyrics: hasLyrics ?? this.hasLyrics,
    );
  }

  factory MediaWork.fromJson(Map<String, dynamic> json) {
    return MediaWork(
      id: _stringValue(json['id']),
      title: _stringValue(json['title']),
      type: _stringValue(json['type']),
      releaseYear: _nullableInt(json['releaseYear']),
      originalLanguage: _nullableString(json['originalLanguage']),
      genres: _stringList(json['genres']),
      themes: _stringList(json['themes']),
      tags: _stringList(json['tags']),
      productionCountries: _stringList(json['productionCountries']),
      settingCountries: _stringList(json['settingCountries']),
      culturalAssociationCountries:
          _stringList(json['culturalAssociationCountries']),
      creatorOriginCountries:
          _stringList(json['creatorOriginCountries']),
      sourceOriginCountries:
          _stringList(json['sourceOriginCountries']),
      artistIds: _stringList(json['artistIds']),
      personIds: _stringList(json['personIds']),
      franchiseIds: _stringList(json['franchiseIds']),
      albumIds: _stringList(json['albumIds']),
      songIds: _stringList(json['songIds']),
      extraIds: _stringList(json['extraIds']),
      trailerIds: _stringList(json['trailerIds']),
      musicVideoIds: _stringList(json['musicVideoIds']),
      hasLyrics: _boolValue(json['hasLyrics']),
    );
  }

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

  @override
  String toString() {
    return 'MediaWork('
        'id: $id, '
        'title: $title, '
        'type: $type, '
        'releaseYear: $releaseYear'
        ')';
  }
}

String _stringValue(
  Object? value, {
  String fallback = '',
}) {
  if (value == null) {
    return fallback;
  }

  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

String? _nullableString(Object? value) {
  if (value == null) {
    return null;
  }

  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int? _nullableInt(Object? value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  if (value is String) {
    return int.tryParse(value.trim());
  }

  return null;
}

bool _boolValue(Object? value) {
  if (value is bool) {
    return value;
  }

  if (value is num) {
    return value != 0;
  }

  if (value is String) {
    switch (value.trim().toLowerCase()) {
      case 'true':
      case '1':
      case 'yes':
      case 'on':
        return true;
      case 'false':
      case '0':
      case 'no':
      case 'off':
        return false;
    }
  }

  return false;
}

List<String> _stringList(Object? value) {
  if (value is List) {
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  if (value is String) {
    final text = value.trim();

    if (text.isEmpty) {
      return const [];
    }

    return [text];
  }

  return const [];
}