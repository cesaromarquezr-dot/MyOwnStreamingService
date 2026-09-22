// FILE: `Backend/services/rating_service.dart`.
// Purpose: Stores profile-specific 0.5-5 star ratings and returns provider
// ratings without combining provider scores with personal ratings.

class UserMediaRating {
  static const double minimumStars = 0.5;
  static const double maximumStars = 5.0;

  final String mediaId;
  final String profileId;
  final double stars;
  final DateTime updatedAt;

  UserMediaRating({
    required this.mediaId,
    required this.profileId,
    required this.stars,
    DateTime? updatedAt,
  }) : updatedAt = (updatedAt ?? DateTime.now()).toUtc();

  Map<String, dynamic> toJson() => {
        'mediaId': mediaId,
        'profileId': profileId,
        'stars': stars,
        'updatedAt': updatedAt.toIso8601String(),
      };

  static UserMediaRating fromJson(Map<String, dynamic> json) {
    final mediaId = (json['mediaId'] as String?)?.trim() ?? '';
    final profileId = (json['profileId'] as String?)?.trim() ?? '';
    final starsValue = json['stars'];
    final updatedAtValue = json['updatedAt'];

    if (mediaId.isEmpty) {
      throw FormatException('Media ID is required.');
    }

    if (profileId.isEmpty) {
      throw FormatException('Profile ID is required.');
    }

    final stars = starsValue is num
        ? starsValue.toDouble()
        : double.tryParse(starsValue?.toString() ?? '');

    if (stars == null || !RatingService.isValidStars(stars)) {
      throw FormatException(
        'Rating must be between 0.5 and 5 stars in 0.5-star increments.',
      );
    }

    DateTime? updatedAt;
    if (updatedAtValue is String && updatedAtValue.trim().isNotEmpty) {
      updatedAt = DateTime.tryParse(updatedAtValue)?.toUtc();
    }

    return UserMediaRating(
      mediaId: mediaId,
      profileId: profileId,
      stars: stars,
      updatedAt: updatedAt,
    );
  }
}

class RatingService {
  final Map<String, UserMediaRating> _ratings =
      <String, UserMediaRating>{};

  static bool isValidStars(double stars) {
    if (!stars.isFinite) {
      return false;
    }

    if (stars < UserMediaRating.minimumStars ||
        stars > UserMediaRating.maximumStars) {
      return false;
    }

    final doubled = stars * 2;
    return (doubled - doubled.round()).abs() <= 0.000001;
  }

  /// Returns external/provider scores supplied by configured integrations.
  ///
  /// Provider scores are deliberately not generated, averaged, or combined
  /// with profile-specific ratings by this service.
  List<Map<String, dynamic>> providerRatings({
    required String mediaId,
    required String title,
    int? year,
    required String mediaType,
    String? tmdbId,
    String? musicBrainzId,
    bool refresh = false,
  }) {
    final normalizedMediaId = mediaId.trim();

    if (normalizedMediaId.isEmpty) {
      throw Exception('Media ID is required.');
    }

    if (title.trim().isEmpty) {
      throw Exception('Title is required.');
    }

    if (mediaType.trim().isEmpty) {
      throw Exception('Media type is required.');
    }

    if (year != null && (year < 1800 || year > 3000)) {
      throw Exception('Year must be between 1800 and 3000.');
    }

    // Provider integrations can populate this result in a future
    // implementation. This service must never fabricate provider scores.
    return <Map<String, dynamic>>[];
  }

  /// Returns the current profile's private rating for a media item.
  UserMediaRating? userRating({
    required String mediaId,
    required String profileId,
  }) {
    final normalizedMediaId = mediaId.trim();
    final normalizedProfileId = profileId.trim();

    if (normalizedMediaId.isEmpty || normalizedProfileId.isEmpty) {
      return null;
    }

    return _ratings[_key(normalizedProfileId, normalizedMediaId)];
  }

  /// Returns all ratings belonging to a profile.
  ///
  /// Returned objects are immutable, so callers cannot modify the service's
  /// stored references.
  List<UserMediaRating> ratingsForProfile(String profileId) {
    final normalizedProfileId = profileId.trim();

    if (normalizedProfileId.isEmpty) {
      return <UserMediaRating>[];
    }

    return _ratings.values
        .where((rating) => rating.profileId == normalizedProfileId)
        .toList(growable: false);
  }

  /// Returns all ratings stored for a specific media item.
  List<UserMediaRating> ratingsForMedia(String mediaId) {
    final normalizedMediaId = mediaId.trim();

    if (normalizedMediaId.isEmpty) {
      return <UserMediaRating>[];
    }

    return _ratings.values
        .where((rating) => rating.mediaId == normalizedMediaId)
        .toList(growable: false);
  }

  /// Saves or replaces a profile-specific rating.
  ///
  /// Ratings are intentionally keyed by both profile and media ID. This
  /// prevents one profile's rating from overwriting another profile's rating
  /// for the same media item.
  UserMediaRating saveUserRating({
    required String mediaId,
    required String profileId,
    required double stars,
  }) {
    final normalizedMediaId = mediaId.trim();
    final normalizedProfileId = profileId.trim();

    if (normalizedMediaId.isEmpty) {
      throw Exception('Media ID is required.');
    }

    if (normalizedProfileId.isEmpty) {
      throw Exception('Profile ID is required.');
    }

    if (normalizedMediaId.length > 200) {
      throw Exception('Media ID is too long.');
    }

    if (normalizedProfileId.length > 200) {
      throw Exception('Profile ID is too long.');
    }

    if (!isValidStars(stars)) {
      throw Exception(
        'Rating must be between 0.5 and 5 stars in 0.5-star increments.',
      );
    }

    final rating = UserMediaRating(
      mediaId: normalizedMediaId,
      profileId: normalizedProfileId,
      stars: stars,
      updatedAt: DateTime.now().toUtc(),
    );

    _ratings[_key(normalizedProfileId, normalizedMediaId)] = rating;
    return rating;
  }

  /// Removes a profile-specific rating.
  bool deleteUserRating({
    required String mediaId,
    required String profileId,
  }) {
    final normalizedMediaId = mediaId.trim();
    final normalizedProfileId = profileId.trim();

    if (normalizedMediaId.isEmpty || normalizedProfileId.isEmpty) {
      return false;
    }

    return _ratings
        .remove(_key(normalizedProfileId, normalizedMediaId)) != null;
  }

  /// Number of stored profile/media rating records.
  int get count => _ratings.length;

  /// Removes all in-memory ratings.
  ///
  /// This service is currently process-local. Durable persistence should be
  /// implemented by the database layer rather than exposing the internal map.
  void clear() {
    _ratings.clear();
  }

  static String _key(String profileId, String mediaId) {
    return '$profileId::$mediaId';
  }
}