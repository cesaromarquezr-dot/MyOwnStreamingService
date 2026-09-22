// FILE: `Backend/models/rating.dart`.
// Purpose: Defines provider, critic, community, and profile rating models.
// Ratings from different providers are stored independently and are never
// silently merged into a single public score.
//
// Architecture notes:
// - ExternalRating represents one provider's published rating.
// - MediaRatings is a container for independently stored provider ratings.
// - UserMediaRating represents a profile's separate personal rating.
// - No model in this file calculates a cross-provider "master" score.
// - Provider ratings and personal profile ratings remain separate data domains.

enum RatingProvider {
  tmdb,
  imdb,
  rottenTomatoes,
  musicBrainz,
  user,
}

enum RatingKind {
  audience,
  critic,
  community,
  personal,
}

class ExternalRating {
  final RatingProvider provider;
  final RatingKind kind;
  final double value;
  final double scale;
  final int? voteCount;
  final DateTime? updatedAt;
  final String? url;

  const ExternalRating({
    required this.provider,
    required this.kind,
    required this.value,
    required this.scale,
    this.voteCount,
    this.updatedAt,
    this.url,
  });

  /// Rating expressed as a percentage of its provider-specific scale.
  ///
  /// This is a mathematical normalization only. It must not be interpreted
  /// as a cross-provider aggregate score.
  double get normalizedPercent {
    if (scale <= 0 || !scale.isFinite || !value.isFinite) {
      return 0;
    }

    return ((value / scale) * 100).clamp(0.0, 100.0).toDouble();
  }

  /// Whether the rating contains a usable provider score.
  bool get isValid {
    if (!value.isFinite || !scale.isFinite || scale <= 0) {
      return false;
    }

    if (value < 0 || value > scale) {
      return false;
    }

    if (voteCount != null && voteCount! < 0) {
      return false;
    }

    return true;
  }

  /// Whether the provider supplied a source URL.
  bool get hasUrl => url?.trim().isNotEmpty ?? false;

  /// Whether the provider supplied a vote/review count.
  bool get hasVoteCount => voteCount != null && voteCount! >= 0;

  /// Normalized provider-specific value without changing its scale.
  double get normalizedValue => value.clamp(0.0, scale).toDouble();

  ExternalRating copyWith({
    RatingProvider? provider,
    RatingKind? kind,
    double? value,
    double? scale,
    int? voteCount,
    DateTime? updatedAt,
    String? url,
    bool clearVoteCount = false,
    bool clearUpdatedAt = false,
    bool clearUrl = false,
  }) {
    return ExternalRating(
      provider: provider ?? this.provider,
      kind: kind ?? this.kind,
      value: value ?? this.value,
      scale: scale ?? this.scale,
      voteCount: clearVoteCount ? null : (voteCount ?? this.voteCount),
      updatedAt:
          clearUpdatedAt ? null : (updatedAt ?? this.updatedAt),
      url: clearUrl ? null : (url ?? this.url),
    );
  }

  Map<String, dynamic> toJson() => {
        'provider': provider.name,
        'kind': kind.name,
        'value': value,
        'scale': scale,
        'voteCount': voteCount,
        'updatedAt': updatedAt?.toIso8601String(),
        'url': url,
      };

  factory ExternalRating.fromJson(Map<String, dynamic> json) {
    final provider = _provider(json['provider']);
    final kind = _kind(json['kind']);
    final value = _double(json['value']);
    final scale = _double(json['scale']);

    if (value == null || scale == null) {
      throw const FormatException(
        'Invalid external rating: value and scale are required.',
      );
    }

    final rating = ExternalRating(
      provider: provider,
      kind: kind,
      value: value,
      scale: scale,
      voteCount: _int(json['voteCount']),
      updatedAt: _dateTime(json['updatedAt']),
      url: _nullableString(json['url']),
    );

    if (!rating.isValid) {
      throw const FormatException(
        'Invalid external rating: value is outside the provider scale.',
      );
    }

    return rating;
  }

  static RatingProvider _provider(dynamic value) {
    final raw = value?.toString().trim().toLowerCase();

    for (final item in RatingProvider.values) {
      if (item.name.toLowerCase() == raw) {
        return item;
      }
    }

    // Preserves compatibility with the original parser.
    return RatingProvider.tmdb;
  }

  static RatingKind _kind(dynamic value) {
    final raw = value?.toString().trim().toLowerCase();

    for (final item in RatingKind.values) {
      if (item.name.toLowerCase() == raw) {
        return item;
      }
    }

    // Preserves compatibility with the original parser.
    return RatingKind.audience;
  }

  static double? _double(dynamic value) {
    if (value is num) {
      final result = value.toDouble();
      return result.isFinite ? result : null;
    }

    if (value is String) {
      final result = double.tryParse(value.trim());
      return result?.isFinite == true ? result : null;
    }

    return null;
  }

  static int? _int(dynamic value) {
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

  static DateTime? _dateTime(dynamic value) {
    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value.trim());
    }

    return null;
  }

  static String? _nullableString(dynamic value) {
    if (value == null) {
      return null;
    }

    final result = value.toString().trim();
    return result.isEmpty ? null : result;
  }

  @override
  String toString() {
    return 'ExternalRating('
        'provider: ${provider.name}, '
        'kind: ${kind.name}, '
        'value: $value/$scale, '
        'voteCount: $voteCount'
        ')';
  }
}

class MediaRatings {
  final String mediaId;
  final List<ExternalRating> ratings;

  const MediaRatings({
    required this.mediaId,
    this.ratings = const [],
  });

  /// TMDB's independently stored rating, if present.
  ExternalRating? get tmdb => _find(RatingProvider.tmdb);

  /// IMDb's independently stored rating, if present.
  ExternalRating? get imdb => _find(RatingProvider.imdb);

  /// All independently stored Rotten Tomatoes ratings.
  ///
  /// Multiple entries are retained because critic and audience ratings may
  /// legitimately exist for the same provider.
  List<ExternalRating> get rottenTomatoes => ratings
      .where(
        (rating) => rating.provider == RatingProvider.rottenTomatoes,
      )
      .toList(growable: false);

  /// MusicBrainz-associated rating, if one exists.
  ExternalRating? get musicBrainz => _find(RatingProvider.musicBrainz);

  /// User-provider rating, if one exists.
  ///
  /// This is retained for compatibility. Profile-specific ratings should use
  /// UserMediaRating and remain separate from provider ratings.
  ExternalRating? get user => _find(RatingProvider.user);

  /// Returns all ratings belonging to one provider without aggregation.
  List<ExternalRating> forProvider(
    RatingProvider provider,
  ) {
    return ratings
        .where((rating) => rating.provider == provider)
        .toList(growable: false);
  }

  /// Returns all ratings of a particular kind without aggregating them.
  List<ExternalRating> forKind(
    RatingKind kind,
  ) {
    return ratings
        .where((rating) => rating.kind == kind)
        .toList(growable: false);
  }

  /// Returns the first rating matching both provider and kind.
  ExternalRating? find({
    required RatingProvider provider,
    required RatingKind kind,
  }) {
    for (final rating in ratings) {
      if (rating.provider == provider && rating.kind == kind) {
        return rating;
      }
    }

    return null;
  }

  /// Whether this container has any provider ratings.
  bool get hasRatings => ratings.isNotEmpty;

  /// Number of stored provider rating records.
  int get ratingCount => ratings.length;

  /// Whether the model contains a usable media ID.
  bool get isValid => mediaId.trim().isNotEmpty;

  ExternalRating? _find(RatingProvider provider) {
    for (final rating in ratings) {
      if (rating.provider == provider) {
        return rating;
      }
    }

    return null;
  }

  MediaRatings copyWith({
    String? mediaId,
    List<ExternalRating>? ratings,
  }) {
    return MediaRatings(
      mediaId: mediaId ?? this.mediaId,
      ratings: ratings ?? List<ExternalRating>.from(this.ratings),
    );
  }

  Map<String, dynamic> toJson() => {
        'mediaId': mediaId,
        'ratings': ratings
            .map((rating) => rating.toJson())
            .toList(growable: false),
      };

  factory MediaRatings.fromJson(
    Map<String, dynamic> json,
  ) {
    final parsedRatings = <ExternalRating>[];
    final rawRatings = json['ratings'];

    if (rawRatings is List) {
      for (final item in rawRatings) {
        if (item is! Map) {
          continue;
        }

        try {
          parsedRatings.add(
            ExternalRating.fromJson(
              Map<String, dynamic>.from(item),
            ),
          );
        } on FormatException {
          // Ignore malformed individual provider records while retaining
          // valid ratings from the same media item.
        }
      }
    }

    return MediaRatings(
      mediaId: json['mediaId']?.toString().trim() ?? '',
      ratings: List<ExternalRating>.unmodifiable(parsedRatings),
    );
  }

  @override
  String toString() {
    return 'MediaRatings('
        'mediaId: $mediaId, '
        'ratingCount: $ratingCount'
        ')';
  }
}

class UserMediaRating {
  final String mediaId;
  final String profileId;
  final double stars;
  final DateTime updatedAt;

  const UserMediaRating({
    required this.mediaId,
    required this.profileId,
    required this.stars,
    required this.updatedAt,
  });

  /// The application's allowed personal-rating range.
  static const double minimumStars = 0.5;
  static const double maximumStars = 5.0;

  /// Personal ratings use half-star increments.
  bool get isHalfStarIncrement =>
      (stars * 2).roundToDouble() == stars * 2;

  /// Whether the profile rating satisfies the application's rating rules.
  bool get isValid {
    if (mediaId.trim().isEmpty || profileId.trim().isEmpty) {
      return false;
    }

    if (!stars.isFinite ||
        stars < minimumStars ||
        stars > maximumStars) {
      return false;
    }

    return isHalfStarIncrement;
  }

  /// Returns the rating as a percentage of the personal five-star scale.
  ///
  /// This is only a representation of the user's own rating. It must not be
  /// combined with external provider ratings.
  double get normalizedPercent =>
      ((stars / maximumStars) * 100).clamp(0.0, 100.0).toDouble();

  UserMediaRating copyWith({
    String? mediaId,
    String? profileId,
    double? stars,
    DateTime? updatedAt,
  }) {
    return UserMediaRating(
      mediaId: mediaId ?? this.mediaId,
      profileId: profileId ?? this.profileId,
      stars: stars ?? this.stars,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'mediaId': mediaId,
        'profileId': profileId,
        'stars': stars,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory UserMediaRating.fromJson(
    Map<String, dynamic> json,
  ) {
    final mediaId = _stringValue(json['mediaId']);
    final profileId = _stringValue(json['profileId']);
    final stars = _doubleValue(json['stars']);
    final updatedAt = _dateTimeValue(json['updatedAt']);

    if (mediaId == null ||
        profileId == null ||
        stars == null ||
        updatedAt == null) {
      throw const FormatException(
        'Invalid user media rating: required fields are missing.',
      );
    }

    final rating = UserMediaRating(
      mediaId: mediaId,
      profileId: profileId,
      stars: stars,
      updatedAt: updatedAt,
    );

    if (!rating.isValid) {
      throw const FormatException(
        'Invalid user media rating: stars must be 0.5 through 5.0 '
        'in half-star increments.',
      );
    }

    return rating;
  }

  @override
  String toString() {
    return 'UserMediaRating('
        'mediaId: $mediaId, '
        'profileId: $profileId, '
        'stars: $stars, '
        'updatedAt: $updatedAt'
        ')';
  }
}

String? _stringValue(dynamic value) {
  if (value == null) {
    return null;
  }

  final result = value.toString().trim();
  return result.isEmpty ? null : result;
}

double? _doubleValue(dynamic value) {
  if (value is num) {
    final result = value.toDouble();
    return result.isFinite ? result : null;
  }

  if (value is String) {
    final result = double.tryParse(value.trim());
    return result?.isFinite == true ? result : null;
  }

  return null;
}

DateTime? _dateTimeValue(dynamic value) {
  if (value is DateTime) {
    return value;
  }

  if (value is String) {
    return DateTime.tryParse(value.trim());
  }

  return null;
}