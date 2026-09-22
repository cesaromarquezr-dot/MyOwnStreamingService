// FILE: `Backend/models/media.dart`.
// Purpose: Implements the media portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.
//
// Media is the application-facing playable/catalog representation of a
// movie or TV item. Physical releases, discs and disc contents remain
// separate provenance entities and can be associated with this model through
// their IDs.
//
// This model intentionally remains compatible with the existing JSON
// contract. New physical-media fields are additive.

enum MediaType {
  movie,
  tvShow,
}

class Media {
  final String id;
  final String title;
  final MediaType type;

  final int? year;
  final String? posterUrl;
  final String? description;
  final double? rating;
  final String? ratingReason;

  // Trailer / preview video.
  //
  // This can contain a YouTube trailer URL or another supported
  // trailer source. It is optional because not every media item
  // will have a trailer.
  final String? trailerUrl;

  // International/adaptation graph metadata.
  final String? countryOfOrigin;
  final String? language;
  final String? adaptationGroupId;
  final String? adaptationGroupName;
  final List<String> relationshipTypes;

  // Discovery / recommendation metadata.
  final List<String> genres;
  final List<String> tags;
  final List<String> themes;

  // People involved with the media.
  final List<String> actors;
  final List<String> characters;
  final List<String> directors;
  final List<String> writers;

  // Franchises / connected media.
  final List<String> franchises;
  final List<String> references;

  // Music associated with the media.
  final List<String> music;

  // TV information.
  final String? seriesId;
  final int? seasonNumber;
  final int? episodeNumber;
  final int? totalEpisodesInSeason;

  // Release information.
  final DateTime? releaseDate;

  // Physical-disc/archive metadata.
  //
  // These identify the physical provenance of the imported/playable item.
  // They do not replace the canonical media ID.
  final String? discType;
  final String? discRegion;
  final String? discCollectionId;
  final String? discCollectionTitle;
  final int? discNumber;
  final String? discTitleId;
  final List<String> chapters;
  final List<String> audioTracks;
  final List<String> languages;
  final List<String> subtitles;
  final List<String> extras;

  // ARM / physical-media provenance.
  //
  // These fields are optional so existing catalog records remain valid.
  // A bonus feature, deleted scene, commentary, trailer or other disc
  // content can retain its physical source without becoming a fake movie.
  final String? physicalReleaseId;
  final String? physicalDiscId;
  final String? discContentId;
  final bool isBonusContent;

  // Canonical music identity.
  //
  // For music imports, this can point at the canonical recording rather than
  // creating a duplicate song for every soundtrack/album release.
  final String? canonicalRecordingId;

  // Availability.
  //
  // These describe where the title can be streamed or purchased.
  // Profile ownership is intentionally NOT stored here because
  // ownership belongs to an individual Profile.
  final List<WatchOption> watchOptions;
  final List<PurchaseOption> purchaseOptions;

  // Optional profile-level allow-list. Empty means the account's legacy
  // ownership model applies; populated means explicit profile access.
  final List<String> accessibleProfileIds;

  Media({
    required this.id,
    required this.title,
    required this.type,
    this.year,
    this.posterUrl,
    this.description,
    this.rating,
    this.ratingReason,
    this.trailerUrl,
    this.countryOfOrigin,
    this.language,
    this.adaptationGroupId,
    this.adaptationGroupName,
    this.relationshipTypes = const [],
    this.genres = const [],
    this.tags = const [],
    this.themes = const [],
    this.actors = const [],
    this.characters = const [],
    this.directors = const [],
    this.writers = const [],
    this.franchises = const [],
    this.references = const [],
    this.music = const [],
    this.seriesId,
    this.seasonNumber,
    this.episodeNumber,
    this.totalEpisodesInSeason,
    this.releaseDate,
    this.discType,
    this.discRegion,
    this.discCollectionId,
    this.discCollectionTitle,
    this.discNumber,
    this.discTitleId,
    this.chapters = const [],
    this.audioTracks = const [],
    this.languages = const [],
    this.subtitles = const [],
    this.extras = const [],
    this.physicalReleaseId,
    this.physicalDiscId,
    this.discContentId,
    this.isBonusContent = false,
    this.canonicalRecordingId,
    this.watchOptions = const [],
    this.purchaseOptions = const [],
    this.accessibleProfileIds = const [],
  });

  bool get isMovie {
    return type == MediaType.movie;
  }

  bool get isTvShow {
    return type == MediaType.tvShow;
  }

  bool get hasPhysicalProvenance {
    return physicalReleaseId != null ||
        physicalDiscId != null ||
        discContentId != null ||
        discCollectionId != null;
  }

  bool get hasCanonicalRecording {
    return canonicalRecordingId?.trim().isNotEmpty == true;
  }

  bool get hasTrailer {
    return trailerUrl?.trim().isNotEmpty == true;
  }

  bool get hasAvailability =>
      watchOptions.isNotEmpty || purchaseOptions.isNotEmpty;

  bool get hasEpisodePosition =>
      seasonNumber != null || episodeNumber != null;

  bool get isEpisode =>
      type == MediaType.tvShow &&
      (episodeNumber != null || seasonNumber != null);

  /// Basic identity validation.
  ///
  /// This deliberately does not reject a media item merely because optional
  /// metadata is missing. Metadata enrichment can happen later.
  bool get isValid =>
      id.trim().isNotEmpty &&
      title.trim().isNotEmpty;

  /// Performs `toJson` for this feature. Update this documentation when its
  /// contract changes.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'type': type.name,
      'year': year,
      'posterUrl': posterUrl,
      'description': description,
      'rating': rating,
      'ratingReason': ratingReason,
      'trailerUrl': trailerUrl,
      'countryOfOrigin': countryOfOrigin,
      'language': language,
      'adaptationGroupId': adaptationGroupId,
      'adaptationGroupName': adaptationGroupName,
      'relationshipTypes': List<String>.from(relationshipTypes),

      'genres': List<String>.from(genres),
      'tags': List<String>.from(tags),
      'themes': List<String>.from(themes),

      'actors': List<String>.from(actors),
      'characters': List<String>.from(characters),
      'directors': List<String>.from(directors),
      'writers': List<String>.from(writers),

      'franchises': List<String>.from(franchises),
      'references': List<String>.from(references),

      'music': List<String>.from(music),

      'seriesId': seriesId,
      'seasonNumber': seasonNumber,
      'episodeNumber': episodeNumber,
      'totalEpisodesInSeason': totalEpisodesInSeason,

      'releaseDate': releaseDate?.toIso8601String(),

      'discType': discType,
      'discRegion': discRegion,
      'discCollectionId': discCollectionId,
      'discCollectionTitle': discCollectionTitle,
      'discNumber': discNumber,
      'discTitleId': discTitleId,
      'chapters': List<String>.from(chapters),
      'audioTracks': List<String>.from(audioTracks),
      'languages': List<String>.from(languages),
      'subtitles': List<String>.from(subtitles),
      'extras': List<String>.from(extras),

      'physicalReleaseId': physicalReleaseId,
      'physicalDiscId': physicalDiscId,
      'discContentId': discContentId,
      'isBonusContent': isBonusContent,
      'canonicalRecordingId': canonicalRecordingId,

      'watchOptions':
          watchOptions.map((option) => option.toJson()).toList(),

      'purchaseOptions':
          purchaseOptions.map((option) => option.toJson()).toList(),

      'accessibleProfileIds':
          List<String>.from(accessibleProfileIds),
    };
  }

  factory Media.fromJson(Map<String, dynamic> json) {
    return Media(
      id: _stringValue(json['id']),
      title: _stringValue(json['title']),
      type: _parseMediaType(json['type']),

      year: _parseInt(json['year']),
      posterUrl: _nullableString(json['posterUrl']),
      description: _nullableString(json['description']),
      rating: _parseDouble(json['rating']),
      ratingReason: _nullableString(json['ratingReason']),
      trailerUrl: _nullableString(json['trailerUrl']),

      countryOfOrigin: _nullableString(json['countryOfOrigin']),
      language: _nullableString(json['language']),
      adaptationGroupId: _nullableString(json['adaptationGroupId']),
      adaptationGroupName: _nullableString(json['adaptationGroupName']),
      relationshipTypes: _stringList(json['relationshipTypes']),

      genres: _stringList(json['genres']),
      tags: _stringList(json['tags']),
      themes: _stringList(json['themes']),

      actors: _stringList(json['actors']),
      characters: _stringList(json['characters']),
      directors: _stringList(json['directors']),
      writers: _stringList(json['writers']),

      franchises: _stringList(json['franchises']),
      references: _stringList(json['references']),

      music: _stringList(json['music']),

      seriesId: _nullableString(json['seriesId']),
      seasonNumber: _parseInt(json['seasonNumber']),
      episodeNumber: _parseInt(json['episodeNumber']),
      totalEpisodesInSeason:
          _parseInt(json['totalEpisodesInSeason']),

      releaseDate: _parseDate(json['releaseDate']),

      discType: _nullableString(json['discType']),
      discRegion: _nullableString(json['discRegion']),
      discCollectionId: _nullableString(json['discCollectionId']),
      discCollectionTitle:
          _nullableString(json['discCollectionTitle']),
      discNumber: _parseInt(json['discNumber']),
      discTitleId: _nullableString(json['discTitleId']),
      chapters: _stringList(json['chapters']),
      audioTracks: _stringList(json['audioTracks']),
      languages: _stringList(json['languages']),
      subtitles: _stringList(json['subtitles']),
      extras: _stringList(json['extras']),

      physicalReleaseId:
          _nullableString(json['physicalReleaseId']),
      physicalDiscId:
          _nullableString(json['physicalDiscId']),
      discContentId:
          _nullableString(json['discContentId']),
      isBonusContent:
          _parseBool(json['isBonusContent']),
      canonicalRecordingId:
          _nullableString(json['canonicalRecordingId']),

      watchOptions:
          _watchOptions(json['watchOptions']),

      purchaseOptions:
          _purchaseOptions(json['purchaseOptions']),

      accessibleProfileIds:
          _stringList(json['accessibleProfileIds']),
    );
  }

  /// Creates an immutable-style updated copy.
  Media copyWith({
    String? id,
    String? title,
    MediaType? type,
    int? year,
    String? posterUrl,
    String? description,
    double? rating,
    String? ratingReason,
    String? trailerUrl,
    String? countryOfOrigin,
    String? language,
    String? adaptationGroupId,
    String? adaptationGroupName,
    List<String>? relationshipTypes,
    List<String>? genres,
    List<String>? tags,
    List<String>? themes,
    List<String>? actors,
    List<String>? characters,
    List<String>? directors,
    List<String>? writers,
    List<String>? franchises,
    List<String>? references,
    List<String>? music,
    String? seriesId,
    int? seasonNumber,
    int? episodeNumber,
    int? totalEpisodesInSeason,
    DateTime? releaseDate,
    String? discType,
    String? discRegion,
    String? discCollectionId,
    String? discCollectionTitle,
    int? discNumber,
    String? discTitleId,
    List<String>? chapters,
    List<String>? audioTracks,
    List<String>? languages,
    List<String>? subtitles,
    List<String>? extras,
    String? physicalReleaseId,
    String? physicalDiscId,
    String? discContentId,
    bool? isBonusContent,
    String? canonicalRecordingId,
    List<WatchOption>? watchOptions,
    List<PurchaseOption>? purchaseOptions,
    List<String>? accessibleProfileIds,
    bool clearYear = false,
    bool clearPosterUrl = false,
    bool clearDescription = false,
    bool clearRating = false,
    bool clearRatingReason = false,
    bool clearTrailerUrl = false,
    bool clearCountryOfOrigin = false,
    bool clearLanguage = false,
    bool clearAdaptationGroupId = false,
    bool clearAdaptationGroupName = false,
    bool clearSeriesId = false,
    bool clearReleaseDate = false,
    bool clearPhysicalReleaseId = false,
    bool clearPhysicalDiscId = false,
    bool clearDiscContentId = false,
    bool clearCanonicalRecordingId = false,
  }) {
    return Media(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,

      year: clearYear ? null : (year ?? this.year),
      posterUrl: clearPosterUrl ? null : (posterUrl ?? this.posterUrl),
      description:
          clearDescription ? null : (description ?? this.description),
      rating: clearRating ? null : (rating ?? this.rating),
      ratingReason:
          clearRatingReason ? null : (ratingReason ?? this.ratingReason),
      trailerUrl:
          clearTrailerUrl ? null : (trailerUrl ?? this.trailerUrl),

      countryOfOrigin: clearCountryOfOrigin
          ? null
          : (countryOfOrigin ?? this.countryOfOrigin),
      language:
          clearLanguage ? null : (language ?? this.language),
      adaptationGroupId: clearAdaptationGroupId
          ? null
          : (adaptationGroupId ?? this.adaptationGroupId),
      adaptationGroupName: clearAdaptationGroupName
          ? null
          : (adaptationGroupName ?? this.adaptationGroupName),

      relationshipTypes:
          relationshipTypes ?? this.relationshipTypes,
      genres: genres ?? this.genres,
      tags: tags ?? this.tags,
      themes: themes ?? this.themes,

      actors: actors ?? this.actors,
      characters: characters ?? this.characters,
      directors: directors ?? this.directors,
      writers: writers ?? this.writers,

      franchises: franchises ?? this.franchises,
      references: references ?? this.references,
      music: music ?? this.music,

      seriesId: clearSeriesId ? null : (seriesId ?? this.seriesId),
      seasonNumber: seasonNumber ?? this.seasonNumber,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      totalEpisodesInSeason:
          totalEpisodesInSeason ?? this.totalEpisodesInSeason,

      releaseDate:
          clearReleaseDate ? null : (releaseDate ?? this.releaseDate),

      discType: discType ?? this.discType,
      discRegion: discRegion ?? this.discRegion,
      discCollectionId: discCollectionId ?? this.discCollectionId,
      discCollectionTitle:
          discCollectionTitle ?? this.discCollectionTitle,
      discNumber: discNumber ?? this.discNumber,
      discTitleId: discTitleId ?? this.discTitleId,
      chapters: chapters ?? this.chapters,
      audioTracks: audioTracks ?? this.audioTracks,
      languages: languages ?? this.languages,
      subtitles: subtitles ?? this.subtitles,
      extras: extras ?? this.extras,

      physicalReleaseId: clearPhysicalReleaseId
          ? null
          : (physicalReleaseId ?? this.physicalReleaseId),
      physicalDiscId: clearPhysicalDiscId
          ? null
          : (physicalDiscId ?? this.physicalDiscId),
      discContentId: clearDiscContentId
          ? null
          : (discContentId ?? this.discContentId),
      isBonusContent: isBonusContent ?? this.isBonusContent,
      canonicalRecordingId: clearCanonicalRecordingId
          ? null
          : (canonicalRecordingId ?? this.canonicalRecordingId),

      watchOptions: watchOptions ?? this.watchOptions,
      purchaseOptions: purchaseOptions ?? this.purchaseOptions,
      accessibleProfileIds:
          accessibleProfileIds ?? this.accessibleProfileIds,
    );
  }

  static MediaType _parseMediaType(dynamic value) {
    final type = value?.toString().trim().toLowerCase();

    switch (type) {
      case 'tvshow':
      case 'tv_show':
      case 'tv show':
      case 'series':
        return MediaType.tvShow;

      case 'movie':
      default:
        return MediaType.movie;
    }
  }

  static int? _parseInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString().trim());
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString().trim());
  }

  static bool _parseBool(dynamic value) {
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

  static DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    final text = value.toString().trim();

    if (text.isEmpty) {
      return null;
    }

    return DateTime.tryParse(text);
  }

  static String _stringValue(
    dynamic value, {
    String fallback = '',
  }) {
    if (value == null) {
      return fallback;
    }

    final text = value.toString().trim();

    return text.isEmpty ? fallback : text;
  }

  static String? _nullableString(dynamic value) {
    if (value == null) {
      return null;
    }

    final text = value.toString().trim();

    if (text.isEmpty) {
      return null;
    }

    return text;
  }

  static List<String> _stringList(dynamic value) {
    if (value is String) {
      final text = value.trim();

      return text.isEmpty ? const [] : [text];
    }

    if (value is! List) {
      return const [];
    }

    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static List<WatchOption> _watchOptions(
    dynamic value,
  ) {
    if (value is! List) {
      return const [];
    }

    return value
        .whereType<Map>()
        .map(
          (item) => WatchOption.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .where(
          (option) =>
              option.provider.trim().isNotEmpty &&
              option.type.trim().isNotEmpty,
        )
        .toList();
  }

  static List<PurchaseOption> _purchaseOptions(
    dynamic value,
  ) {
    if (value is! List) {
      return const [];
    }

    return value
        .whereType<Map>()
        .map(
          (item) => PurchaseOption.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .where(
          (option) =>
              option.retailer.trim().isNotEmpty &&
              option.title.trim().isNotEmpty,
        )
        .toList();
  }
}

class WatchOption {
  final String provider;
  final String type;
  final String? url;

  const WatchOption({
    required this.provider,
    required this.type,
    this.url,
  });

  bool get isValid =>
      provider.trim().isNotEmpty &&
      type.trim().isNotEmpty;

  bool get hasUrl => url?.trim().isNotEmpty == true;

  Map<String, dynamic> toJson() {
    return {
      'provider': provider,
      'type': type,
      'url': url,
    };
  }

  factory WatchOption.fromJson(
    Map<String, dynamic> json,
  ) {
    return WatchOption(
      provider: _stringValue(json['provider']),
      type: _stringValue(json['type']),
      url: _nullableString(json['url']),
    );
  }

  WatchOption copyWith({
    String? provider,
    String? type,
    String? url,
    bool clearUrl = false,
  }) {
    return WatchOption(
      provider: provider ?? this.provider,
      type: type ?? this.type,
      url: clearUrl ? null : (url ?? this.url),
    );
  }

  static String _stringValue(
    dynamic value, {
    String fallback = '',
  }) {
    if (value == null) {
      return fallback;
    }

    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static String? _nullableString(dynamic value) {
    if (value == null) {
      return null;
    }

    final text = value.toString().trim();

    if (text.isEmpty) {
      return null;
    }

    return text;
  }
}

class PurchaseOption {
  final String retailer;
  final String title;
  final double price;
  final String currency;
  final String url;
  final String format;

  const PurchaseOption({
    required this.retailer,
    required this.title,
    required this.price,
    required this.currency,
    required this.url,
    required this.format,
  });

  bool get isValid =>
      retailer.trim().isNotEmpty &&
      title.trim().isNotEmpty &&
      price >= 0 &&
      currency.trim().isNotEmpty &&
      url.trim().isNotEmpty &&
      format.trim().isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'retailer': retailer,
      'title': title,
      'price': price,
      'currency': currency,
      'url': url,
      'format': format,
    };
  }

  factory PurchaseOption.fromJson(
    Map<String, dynamic> json,
  ) {
    return PurchaseOption(
      retailer: _stringValue(json['retailer']),
      title: _stringValue(json['title']),
      price: _parsePrice(json['price']),
      currency: _currency(json['currency']),
      url: _stringValue(json['url']),
      format: _stringValue(json['format']),
    );
  }

  PurchaseOption copyWith({
    String? retailer,
    String? title,
    double? price,
    String? currency,
    String? url,
    String? format,
  }) {
    return PurchaseOption(
      retailer: retailer ?? this.retailer,
      title: title ?? this.title,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      url: url ?? this.url,
      format: format ?? this.format,
    );
  }

  static double _parsePrice(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString().trim() ?? '',
        ) ??
        0.0;
  }

  static String _currency(dynamic value) {
    final text = value?.toString().trim() ?? '';

    return text.isEmpty ? 'USD' : text;
  }

  static String _stringValue(
    dynamic value, {
    String fallback = '',
  }) {
    if (value == null) {
      return fallback;
    }

    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }
}