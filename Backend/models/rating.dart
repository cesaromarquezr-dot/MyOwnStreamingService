// FILE: `Backend/models/rating.dart`.
// Purpose: Defines provider, critic, community, and profile rating models.
// Ratings from different providers are stored independently and are never
// silently merged into a single public score.

enum RatingProvider { tmdb, imdb, rottenTomatoes, musicBrainz, user }
enum RatingKind { audience, critic, community, personal }

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

  double get normalizedPercent => scale <= 0 ? 0 : (value / scale) * 100;

  Map<String, dynamic> toJson() => {
        'provider': provider.name,
        'kind': kind.name,
        'value': value,
        'scale': scale,
        'voteCount': voteCount,
        'updatedAt': updatedAt?.toIso8601String(),
        'url': url,
      };

  factory ExternalRating.fromJson(Map<String, dynamic> json) => ExternalRating(
        provider: _provider(json['provider']),
        kind: _kind(json['kind']),
        value: _double(json['value']) ?? 0,
        scale: _double(json['scale']) ?? 10,
        voteCount: _int(json['voteCount']),
        updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
        url: json['url']?.toString(),
      );

  static RatingProvider _provider(dynamic value) => RatingProvider.values.firstWhere(
        (item) => item.name == value?.toString(),
        orElse: () => RatingProvider.tmdb,
      );

  static RatingKind _kind(dynamic value) => RatingKind.values.firstWhere(
        (item) => item.name == value?.toString(),
        orElse: () => RatingKind.audience,
      );

  static double? _double(dynamic value) => value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');
  static int? _int(dynamic value) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
}

class MediaRatings {
  final String mediaId;
  final List<ExternalRating> ratings;

  const MediaRatings({required this.mediaId, this.ratings = const []});

  ExternalRating? get tmdb => _find(RatingProvider.tmdb);
  ExternalRating? get imdb => _find(RatingProvider.imdb);
  List<ExternalRating> get rottenTomatoes => ratings.where((r) => r.provider == RatingProvider.rottenTomatoes).toList(growable: false);
  ExternalRating? get musicBrainz => _find(RatingProvider.musicBrainz);
  ExternalRating? get user => _find(RatingProvider.user);

  ExternalRating? _find(RatingProvider provider) {
    for (final rating in ratings) {
      if (rating.provider == provider) return rating;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'mediaId': mediaId,
        'ratings': ratings.map((rating) => rating.toJson()).toList(),
      };

  factory MediaRatings.fromJson(Map<String, dynamic> json) => MediaRatings(
        mediaId: json['mediaId']?.toString() ?? '',
        ratings: json['ratings'] is List
            ? (json['ratings'] as List).whereType<Map>().map((item) => ExternalRating.fromJson(Map<String, dynamic>.from(item))).toList()
            : const [],
      );
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

  Map<String, dynamic> toJson() => {
        'mediaId': mediaId,
        'profileId': profileId,
        'stars': stars,
        'updatedAt': updatedAt.toIso8601String(),
      };
}
