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

  // Availability.
  //
  // These describe where the title can be streamed or purchased.
  // Profile ownership is intentionally NOT stored here because
  // ownership belongs to an individual Profile.
  final List<WatchOption> watchOptions;
  final List<PurchaseOption> purchaseOptions;

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
    this.watchOptions = const [],
    this.purchaseOptions = const [],
  });

  bool get isMovie {
    return type == MediaType.movie;
  }

  bool get isTvShow {
    return type == MediaType.tvShow;
  }

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

      'watchOptions': watchOptions
          .map((option) => option.toJson())
          .toList(),

      'purchaseOptions': purchaseOptions
          .map((option) => option.toJson())
          .toList(),
    };
  }

  factory Media.fromJson(Map<String, dynamic> json) {
    return Media(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      type: _parseMediaType(json['type']),

      year: _parseInt(json['year']),
      posterUrl: json['posterUrl']?.toString(),
      description: json['description']?.toString(),
      rating: json['rating'] is num ? (json['rating'] as num).toDouble() : double.tryParse(json['rating']?.toString() ?? ''),
      ratingReason: json['ratingReason']?.toString(),
      trailerUrl: _nullableString(json['trailerUrl']),

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

      watchOptions:
          _watchOptions(json['watchOptions']),

      purchaseOptions:
          _purchaseOptions(json['purchaseOptions']),
    );
  }

  static MediaType _parseMediaType(dynamic value) {
    final type = value?.toString().trim();

    switch (type) {
      case 'tvShow':
      case 'tv_show':
      case 'tvshow':
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

    return int.tryParse(
      value.toString().trim(),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }

    final text = value.toString().trim();

    if (text.isEmpty) {
      return null;
    }

    return DateTime.tryParse(text);
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
    if (value is! List) {
      return [];
    }

    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static List<WatchOption> _watchOptions(
    dynamic value,
  ) {
    if (value is! List) {
      return [];
    }

    return value
        .whereType<Map>()
        .map((item) {
          return WatchOption.fromJson(
            Map<String, dynamic>.from(item),
          );
        })
        .where((option) => option.provider.isNotEmpty)
        .toList();
  }

  static List<PurchaseOption> _purchaseOptions(
    dynamic value,
  ) {
    if (value is! List) {
      return [];
    }

    return value
        .whereType<Map>()
        .map((item) {
          return PurchaseOption.fromJson(
            Map<String, dynamic>.from(item),
          );
        })
        .where((option) => option.retailer.isNotEmpty)
        .toList();
  }
}

class WatchOption {
  final String provider;
  final String type;
  final String? url;

  WatchOption({
    required this.provider,
    required this.type,
    this.url,
  });

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
      provider: json['provider']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      url: _nullableString(json['url']),
    );
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

  PurchaseOption({
    required this.retailer,
    required this.title,
    required this.price,
    required this.currency,
    required this.url,
    required this.format,
  });

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
      retailer: json['retailer']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      price: _parsePrice(json['price']),
      currency:
          json['currency']?.toString().trim().isNotEmpty == true
              ? json['currency'].toString().trim()
              : 'USD',
      url: json['url']?.toString() ?? '',
      format: json['format']?.toString() ?? '',
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
}