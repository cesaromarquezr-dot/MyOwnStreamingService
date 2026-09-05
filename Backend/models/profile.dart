// backend/models/profile.dart

class Profile {
  final String id;

  String name;
  String? avatarUrl;

  // Media owned by this profile.
  //
  // These are media IDs, not full Media objects.
  // The actual media information comes from the media model/database.
  final List<String> ownedMediaIds;

  // Media this profile has watched.
  final List<String> watchedMediaIds;

  // Media this profile has explicitly liked.
  final List<String> likedMediaIds;

  // Media this profile has explicitly disliked.
  final List<String> dislikedMediaIds;

  // Watch progress for this profile.
  //
  // Key   = media ID
  // Value = progress from 0.0 to 1.0
  final Map<String, double> watchProgress;

  // Most recently watched media IDs.
  //
  // The first item is the most recently watched.
  final List<String> watchHistory;

  // When each media item was most recently watched.
  //
  // Key   = media ID
  // Value = timestamp of the most recent watch activity
  //
  // This is used by the recommendation engine to give more weight
  // to recently watched titles.
  final Map<String, DateTime> watchHistoryTimestamps;

  Profile({
    required this.id,
    required this.name,
    this.avatarUrl,
    List<String>? ownedMediaIds,
    List<String>? watchedMediaIds,
    List<String>? likedMediaIds,
    List<String>? dislikedMediaIds,
    Map<String, double>? watchProgress,
    List<String>? watchHistory,
    Map<String, DateTime>? watchHistoryTimestamps,
  })  : ownedMediaIds = ownedMediaIds ?? [],
        watchedMediaIds = watchedMediaIds ?? [],
        likedMediaIds = likedMediaIds ?? [],
        dislikedMediaIds = dislikedMediaIds ?? [],
        watchProgress = watchProgress ?? {},
        watchHistory = watchHistory ?? [],
        watchHistoryTimestamps =
            watchHistoryTimestamps ?? {};

  // ------------------------------------------------------------
  // OWNERSHIP
  // ------------------------------------------------------------

  bool ownsMedia(String mediaId) {
    return ownedMediaIds.contains(mediaId);
  }

  void addOwnedMedia(String mediaId) {
    if (mediaId.trim().isEmpty) {
      return;
    }

    if (!ownedMediaIds.contains(mediaId)) {
      ownedMediaIds.add(mediaId);
    }
  }

  void removeOwnedMedia(String mediaId) {
    ownedMediaIds.remove(mediaId);
  }

  // ------------------------------------------------------------
  // WATCH HISTORY
  // ------------------------------------------------------------

  bool hasWatched(String mediaId) {
    return watchedMediaIds.contains(mediaId);
  }

  void markAsWatched(
    String mediaId, {
    DateTime? watchedAt,
  }) {
    if (mediaId.trim().isEmpty) {
      return;
    }

    if (!watchedMediaIds.contains(mediaId)) {
      watchedMediaIds.add(mediaId);
    }

    // Put the newest item at the beginning.
    watchHistory.remove(mediaId);
    watchHistory.insert(0, mediaId);

    // Store the most recent watch timestamp.
    watchHistoryTimestamps[mediaId] =
        watchedAt ?? DateTime.now();
  }

  // ------------------------------------------------------------
  // LIKES
  // ------------------------------------------------------------

  bool hasLiked(String mediaId) {
    return likedMediaIds.contains(mediaId);
  }

  void likeMedia(String mediaId) {
    if (mediaId.trim().isEmpty) {
      return;
    }

    // A title cannot be both liked and disliked.
    dislikedMediaIds.remove(mediaId);

    if (!likedMediaIds.contains(mediaId)) {
      likedMediaIds.add(mediaId);
    }
  }

  void unlikeMedia(String mediaId) {
    likedMediaIds.remove(mediaId);
  }

  // ------------------------------------------------------------
  // DISLIKES
  // ------------------------------------------------------------

  bool hasDisliked(String mediaId) {
    return dislikedMediaIds.contains(mediaId);
  }

  void dislikeMedia(String mediaId) {
    if (mediaId.trim().isEmpty) {
      return;
    }

    // A title cannot be both disliked and liked.
    likedMediaIds.remove(mediaId);

    if (!dislikedMediaIds.contains(mediaId)) {
      dislikedMediaIds.add(mediaId);
    }
  }

  void undislikeMedia(String mediaId) {
    dislikedMediaIds.remove(mediaId);
  }

  // ------------------------------------------------------------
  // WATCH PROGRESS
  // ------------------------------------------------------------

  double getWatchProgress(String mediaId) {
    return watchProgress[mediaId] ?? 0.0;
  }

  void setWatchProgress(
    String mediaId,
    double progress, {
    DateTime? watchedAt,
  }) {
    if (mediaId.trim().isEmpty) {
      return;
    }

    // Keep progress safely between 0 and 1.
    final clampedProgress =
        progress.clamp(0.0, 1.0).toDouble();

    watchProgress[mediaId] = clampedProgress;

    final timestamp =
        watchedAt ?? DateTime.now();

    // Any playback activity updates the history order.
    watchHistory.remove(mediaId);
    watchHistory.insert(0, mediaId);

    watchHistoryTimestamps[mediaId] = timestamp;

    // Treat 90%+ as watched.
    if (clampedProgress >= 0.90) {
      if (!watchedMediaIds.contains(mediaId)) {
        watchedMediaIds.add(mediaId);
      }
    }
  }

  void removeWatchProgress(String mediaId) {
    watchProgress.remove(mediaId);
  }

  // ------------------------------------------------------------
  // WATCH HISTORY DETAILS
  // ------------------------------------------------------------

  DateTime? getLastWatchedAt(String mediaId) {
    return watchHistoryTimestamps[mediaId];
  }

  /// Returns the completion value used by recommendations.
  ///
  /// A progress value of 0.0 means the title has not started.
  /// A value of 1.0 means it is completely watched.
  double getCompletion(String mediaId) {
    return getWatchProgress(mediaId);
  }

  // ------------------------------------------------------------
  // RECOMMENDATION HELPERS
  // ------------------------------------------------------------

  bool shouldRecommend(String mediaId) {
    // Never recommend something the profile disliked.
    if (hasDisliked(mediaId)) {
      return false;
    }

    // Don't recommend something already owned.
    if (ownsMedia(mediaId)) {
      return false;
    }

    // Don't recommend something already watched.
    if (hasWatched(mediaId)) {
      return false;
    }

    return true;
  }

  // ------------------------------------------------------------
  // JSON
  // ------------------------------------------------------------

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatarUrl': avatarUrl,

      'ownedMediaIds': ownedMediaIds,
      'watchedMediaIds': watchedMediaIds,
      'likedMediaIds': likedMediaIds,
      'dislikedMediaIds': dislikedMediaIds,

      'watchProgress': watchProgress,

      'watchHistory': watchHistory,

      'watchHistoryTimestamps':
          watchHistoryTimestamps.map(
        (key, value) => MapEntry(
          key,
          value.toIso8601String(),
        ),
      ),
    };
  }

  factory Profile.fromJson(
    Map<String, dynamic> json,
  ) {
    return Profile(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      avatarUrl: json['avatarUrl']?.toString(),

      ownedMediaIds: _stringList(
        json['ownedMediaIds'],
      ),

      watchedMediaIds: _stringList(
        json['watchedMediaIds'],
      ),

      likedMediaIds: _stringList(
        json['likedMediaIds'],
      ),

      dislikedMediaIds: _stringList(
        json['dislikedMediaIds'],
      ),

      watchProgress: _doubleMap(
        json['watchProgress'],
      ),

      watchHistory: _stringList(
        json['watchHistory'],
      ),

      watchHistoryTimestamps:
          _dateTimeMap(
        json['watchHistoryTimestamps'],
      ),
    );
  }

  // ------------------------------------------------------------
  // JSON HELPERS
  // ------------------------------------------------------------

  static List<String> _stringList(
    dynamic value,
  ) {
    if (value is! List) {
      return [];
    }

    return value
        .map((item) => item.toString())
        .where(
          (item) => item.trim().isNotEmpty,
        )
        .toList();
  }

  static Map<String, double> _doubleMap(
    dynamic value,
  ) {
    if (value is! Map) {
      return {};
    }

    final result = <String, double>{};

    value.forEach((key, value) {
      final number = value is num
          ? value.toDouble()
          : double.tryParse(
              value.toString(),
            );

      if (number != null) {
        result[key.toString()] =
            number.clamp(0.0, 1.0).toDouble();
      }
    });

    return result;
  }

  static Map<String, DateTime> _dateTimeMap(
    dynamic value,
  ) {
    if (value is! Map) {
      return {};
    }

    final result = <String, DateTime>{};

    value.forEach((key, value) {
      final parsed =
          DateTime.tryParse(
        value.toString(),
      );

      if (parsed != null) {
        result[key.toString()] = parsed;
      }
    });

    return result;
  }
}