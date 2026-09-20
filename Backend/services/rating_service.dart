// FILE: `Backend/services/rating_service.dart`.
// Purpose: Stores profile-specific 0.5-5 star ratings and returns provider
// ratings without combining provider scores with personal ratings.

class UserMediaRating {
  final String mediaId;
  final String profileId;
  final double stars;
  final DateTime updatedAt;

  UserMediaRating({
    required this.mediaId,
    required this.profileId,
    required this.stars,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'mediaId': mediaId,
        'profileId': profileId,
        'stars': stars,
        'updatedAt': updatedAt.toIso8601String(),
      };
}

class RatingService {
  final Map<String, UserMediaRating> _ratings = {};

  /// Returns external/provider scores supplied by configured integrations.
  /// This service deliberately returns no fabricated provider score.
  List<Map<String, dynamic>> providerRatings({
    required String mediaId,
    required String title,
    int? year,
    required String mediaType,
    String? tmdbId,
    String? musicBrainzId,
    bool refresh = false,
  }) {
    return <Map<String, dynamic>>[];
  }

  /// Returns the current profile's private rating for a media item.
  UserMediaRating? userRating({
    required String mediaId,
    required String profileId,
  }) =>
      _ratings['${profileId}_$mediaId'];

  /// Saves a profile-specific rating in 0.5-star increments.
  UserMediaRating saveUserRating({
    required String mediaId,
    required String profileId,
    required double stars,
  }) {
    if (mediaId.trim().isEmpty) throw Exception('Media ID is required.');
    if (profileId.trim().isEmpty) throw Exception('Profile ID is required.');
    if (stars < 0.5 || stars > 5 || ((stars * 2) - (stars * 2).round()).abs() > 0.000001) {
      throw Exception('Rating must be between 0.5 and 5 stars in 0.5-star increments.');
    }
    final rating = UserMediaRating(
      mediaId: mediaId.trim(),
      profileId: profileId.trim(),
      stars: stars,
    );
    _ratings['${profileId.trim()}_${mediaId.trim()}'] = rating;
    return rating;
  }
}
