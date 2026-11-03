// FILE: `Backend/services/rating_service.dart`.
import 'dart:convert';
import 'dart:io';

import 'external_rating_service.dart';
// Purpose: Stores profile-specific 0–100 personal scores (with legacy star
// compatibility) and keeps them separate from provider ratings.

class UserMediaRating {
  static const double minimumStars = 0.5;
  static const double maximumStars = 5.0;

  final String mediaId;
  final String profileId;
  final double stars;
  final double score;
  final DateTime updatedAt;

  UserMediaRating({
    required this.mediaId,
    required this.profileId,
    required this.stars,
    double? score,
    DateTime? updatedAt,
  })  : score = score ?? (stars * 20),
        updatedAt = (updatedAt ?? DateTime.now()).toUtc();

  Map<String, dynamic> toJson() => {
        'mediaId': mediaId,
        'profileId': profileId,
        'stars': stars,
        'score': score,
        'updatedAt': updatedAt.toIso8601String(),
      };

  static UserMediaRating fromJson(Map<String, dynamic> json) {
    final mediaId = (json['mediaId'] as String?)?.trim() ?? '';
    final profileId = (json['profileId'] as String?)?.trim() ?? '';
    final starsValue = json['stars'];
    final scoreValue = json['score'];
    final updatedAtValue = json['updatedAt'];

    if (mediaId.isEmpty) {
      throw FormatException('Media ID is required.');
    }

    if (profileId.isEmpty) {
      throw FormatException('Profile ID is required.');
    }

    final legacyStars = starsValue is num
        ? starsValue.toDouble()
        : double.tryParse(starsValue?.toString() ?? '');
    final parsedScore = scoreValue is num
        ? scoreValue.toDouble()
        : double.tryParse(scoreValue?.toString() ?? '');
    final score = parsedScore ?? (legacyStars == null ? null : legacyStars * 20);
    if (score == null || !RatingService.isValidScore(score)) {
      throw FormatException('Personal score must be between 0 and 100.');
    }

    DateTime? updatedAt;
    if (updatedAtValue is String && updatedAtValue.trim().isNotEmpty) {
      updatedAt = DateTime.tryParse(updatedAtValue)?.toUtc();
    }

    return UserMediaRating(
      mediaId: mediaId,
      profileId: profileId,
      stars: score / 20,
      score: score,
      updatedAt: updatedAt,
    );
  }
}

class RatingService {
  final ExternalRatingService externalRatings;
  final Map<String, UserMediaRating> _ratings =
      <String, UserMediaRating>{};

  final File persistenceFile;
  Future<void> _writeQueue = Future<void>.value();

  RatingService({
    ExternalRatingService? externalRatings,
    File? persistenceFile,
  })  : externalRatings = externalRatings ?? ExternalRatingService(),
        persistenceFile = persistenceFile ??
            File((Platform.environment['RATINGS_STORE_PATH'] ?? '').trim().isNotEmpty
                ? Platform.environment['RATINGS_STORE_PATH']!.trim()
                : '${File.fromUri(Platform.script).parent.path}${Platform.pathSeparator}data${Platform.pathSeparator}profile_media_ratings.json');

  /// Restores profile ratings from the backend's local durable data store.
  /// The file contains only media/profile IDs, personal scores, and timestamps—never credentials.
  Future<void> initialize() async {
    try {
      if (!await persistenceFile.exists()) return;
      final decoded = jsonDecode(await persistenceFile.readAsString());
      if (decoded is! List) return;
      for (final row in decoded.whereType<Map>()) {
        try {
          final rating = UserMediaRating.fromJson(
            Map<String, dynamic>.from(row),
          );
          _ratings[_key(rating.profileId, rating.mediaId)] = rating;
        } catch (_) {
          // Ignore a malformed record without discarding the other ratings.
        }
      }
    } catch (_) {
      // Keep the service usable; a later successful write will recreate the file.
    }
  }

  Future<void> _persist() {
    final snapshot = _ratings.values.map((rating) => rating.toJson()).toList();
    _writeQueue = _writeQueue.catchError((Object _) {}).then((_) async {
      await persistenceFile.parent.create(recursive: true);
      final temporary = File('${persistenceFile.path}.tmp');
      await temporary.writeAsString(jsonEncode(snapshot), flush: true);
      if (await persistenceFile.exists()) {
        await persistenceFile.delete();
      }
      await temporary.rename(persistenceFile.path);
    });
    return _writeQueue;
  }

  static bool isValidScore(double score) =>
      score.isFinite && score >= 0 && score <= 100;

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
  Future<List<Map<String, dynamic>>> providerRatings({
    required String mediaId,
    required String title,
    int? year,
    required String mediaType,
    String? tmdbId,
    String? imdbId,
    String? musicBrainzId,
    bool refresh = false,
  }) async {
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

    final ratings = await externalRatings.getRatings(
      title: title,
      year: year,
      imdbId: imdbId,
      tmdbId: tmdbId,
      mediaType: mediaType,
      refresh: refresh,
    );

    // Provider scores remain independent. No cross-provider master score is
    // calculated here.
    return ratings.map((rating) => rating.toJson()).toList(growable: false);
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
  Future<UserMediaRating> saveUserRating({
    required String mediaId,
    required String profileId,
    required double stars,
  }) {
    if (!isValidStars(stars)) {
      throw Exception(
        'Legacy star rating must be between 0.5 and 5.0 in 0.5-star increments.',
      );
    }
    return saveUserScore(
      mediaId: mediaId,
      profileId: profileId,
      score: stars * 20,
    );
  }

  /// Saves an exact profile score on a 0–100 scale.
  Future<UserMediaRating> saveUserScore({
    required String mediaId,
    required String profileId,
    required double score,
  }) async {
    final normalizedMediaId = mediaId.trim();
    final normalizedProfileId = profileId.trim();
    if (normalizedMediaId.isEmpty) throw Exception('Media ID is required.');
    if (normalizedProfileId.isEmpty) throw Exception('Profile ID is required.');
    if (normalizedMediaId.length > 200) throw Exception('Media ID is too long.');
    if (normalizedProfileId.length > 200) throw Exception('Profile ID is too long.');
    if (!isValidScore(score)) throw Exception('Personal score must be between 0 and 100.');

    final rating = UserMediaRating(
      mediaId: normalizedMediaId,
      profileId: normalizedProfileId,
      stars: score / 20,
      score: score,
      updatedAt: DateTime.now().toUtc(),
    );
    _ratings[_key(normalizedProfileId, normalizedMediaId)] = rating;
    await _persist();
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