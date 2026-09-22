// FILE: `Backend/models/profile.dart`.
// Purpose: Implements the profile portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.
//
// A Profile contains per-profile media state. Media itself remains stored in
// the media/catalog layer; this model stores only profile-specific references
// and activity.
//
// Important:
// - IDs stored here are media IDs, not complete Media objects.
// - Ownership, watch state, likes, dislikes, progress, and history are
//   profile-scoped.
// - Recommendation eligibility is derived from this profile state.
// - A profile must never be treated as an account-wide authorization boundary.
//   Account/member authorization belongs to the backend account/session layer.

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
  })  : ownedMediaIds = _normalizeStringList(ownedMediaIds),
        watchedMediaIds = _normalizeStringList(watchedMediaIds),
        likedMediaIds = _normalizeStringList(likedMediaIds),
        dislikedMediaIds = _normalizeStringList(dislikedMediaIds),
        watchProgress = _normalizeProgressMap(watchProgress),
        watchHistory = _normalizeStringList(watchHistory),
        watchHistoryTimestamps =
            _normalizeDateTimeMap(watchHistoryTimestamps);

  // ------------------------------------------------------------
  // STATE / IDENTITY
  // ------------------------------------------------------------

  /// Whether this profile has a usable identifier and name.
  bool get isValid => id.trim().isNotEmpty && name.trim().isNotEmpty;

  /// Whether the profile has an avatar URL.
  bool get hasAvatar => avatarUrl?.trim().isNotEmpty ?? false;

  /// Number of titles currently owned by this profile.
  int get ownedMediaCount => ownedMediaIds.length;

  /// Number of titles this profile has marked as watched.
  int get watchedMediaCount => watchedMediaIds.length;

  /// Number of explicitly liked titles.
  int get likedMediaCount => likedMediaIds.length;

  /// Number of explicitly disliked titles.
  int get dislikedMediaCount => dislikedMediaIds.length;

  /// Number of entries currently retained in watch history.
  int get watchHistoryCount => watchHistory.length;

  // ------------------------------------------------------------
  // OWNERSHIP
  // ------------------------------------------------------------

  /// Returns whether this profile owns the specified media.
  bool ownsMedia(String mediaId) {
    final normalizedId = _normalizeId(mediaId);
    if (normalizedId == null) {
      return false;
    }

    return ownedMediaIds.contains(normalizedId);
  }

  /// Adds media to this profile's owned library.
  void addOwnedMedia(String mediaId) {
    final normalizedId = _normalizeId(mediaId);
    if (normalizedId == null) {
      return;
    }

    if (!ownedMediaIds.contains(normalizedId)) {
      ownedMediaIds.add(normalizedId);
    }
  }

  /// Removes media from this profile's owned library.
  void removeOwnedMedia(String mediaId) {
    final normalizedId = _normalizeId(mediaId);
    if (normalizedId == null) {
      return;
    }

    ownedMediaIds.remove(normalizedId);
  }

  // ------------------------------------------------------------
  // WATCH HISTORY
  // ------------------------------------------------------------

  /// Returns whether this profile has watched the specified media.
  bool hasWatched(String mediaId) {
    final normalizedId = _normalizeId(mediaId);
    if (normalizedId == null) {
      return false;
    }

    return watchedMediaIds.contains(normalizedId);
  }

  /// Marks media as watched and moves it to the front of watch history.
  ///
  /// A timestamp supplied by a trusted backend service may be used to
  /// preserve the original event time. Otherwise the current server/runtime
  /// time is used.
  void markAsWatched(
    String mediaId, {
    DateTime? watchedAt,
  }) {
    final normalizedId = _normalizeId(mediaId);
    if (normalizedId == null) {
      return;
    }

    if (!watchedMediaIds.contains(normalizedId)) {
      watchedMediaIds.add(normalizedId);
    }

    _touchWatchHistory(
      normalizedId,
      watchedAt: watchedAt,
    );
  }

  /// Removes a title from the explicit watched list.
  ///
  /// This does not erase its watch progress or historical activity.
  void removeWatched(String mediaId) {
    final normalizedId = _normalizeId(mediaId);
    if (normalizedId == null) {
      return;
    }

    watchedMediaIds.remove(normalizedId);
  }

  /// Returns the most recently watched media IDs.
  ///
  /// [limit] must be positive. A null limit returns the complete history.
  List<String> recentWatchHistory({int? limit}) {
    if (limit == null) {
      return List<String>.from(watchHistory);
    }

    if (limit <= 0) {
      return const [];
    }

    return watchHistory.take(limit).toList();
  }

  /// Removes a title from watch history while preserving its watched state,
  /// progress, and timestamp.
  void removeFromWatchHistory(String mediaId) {
    final normalizedId = _normalizeId(mediaId);
    if (normalizedId == null) {
      return;
    }

    watchHistory.remove(normalizedId);
  }

  /// Keeps only the newest [maxEntries] history items.
  void trimWatchHistory(int maxEntries) {
    if (maxEntries < 0) {
      return;
    }

    if (watchHistory.length <= maxEntries) {
      return;
    }

    watchHistory.removeRange(
      maxEntries,
      watchHistory.length,
    );
  }

  void _touchWatchHistory(
    String mediaId, {
    DateTime? watchedAt,
  }) {
    watchHistory.remove(mediaId);
    watchHistory.insert(0, mediaId);

    watchHistoryTimestamps[mediaId] =
        watchedAt ?? DateTime.now();
  }

  // ------------------------------------------------------------
  // LIKES
  // ------------------------------------------------------------

  /// Returns whether this profile explicitly likes the specified media.
  bool hasLiked(String mediaId) {
    final normalizedId = _normalizeId(mediaId);
    if (normalizedId == null) {
      return false;
    }

    return likedMediaIds.contains(normalizedId);
  }

  /// Likes media and removes any existing dislike.
  void likeMedia(String mediaId) {
    final normalizedId = _normalizeId(mediaId);
    if (normalizedId == null) {
      return;
    }

    // A title cannot be both liked and disliked.
    dislikedMediaIds.remove(normalizedId);

    if (!likedMediaIds.contains(normalizedId)) {
      likedMediaIds.add(normalizedId);
    }
  }

  /// Removes an explicit like.
  void unlikeMedia(String mediaId) {
    final normalizedId = _normalizeId(mediaId);
    if (normalizedId == null) {
      return;
    }

    likedMediaIds.remove(normalizedId);
  }

  // ------------------------------------------------------------
  // DISLIKES
  // ------------------------------------------------------------

  /// Returns whether this profile explicitly dislikes the specified media.
  bool hasDisliked(String mediaId) {
    final normalizedId = _normalizeId(mediaId);
    if (normalizedId == null) {
      return false;
    }

    return dislikedMediaIds.contains(normalizedId);
  }

  /// Dislikes media and removes any existing like.
  void dislikeMedia(String mediaId) {
    final normalizedId = _normalizeId(mediaId);
    if (normalizedId == null) {
      return;
    }

    // A title cannot be both disliked and liked.
    likedMediaIds.remove(normalizedId);

    if (!dislikedMediaIds.contains(normalizedId)) {
      dislikedMediaIds.add(normalizedId);
    }
  }

  /// Removes an explicit dislike.
  void undislikeMedia(String mediaId) {
    final normalizedId = _normalizeId(mediaId);
    if (normalizedId == null) {
      return;
    }

    dislikedMediaIds.remove(normalizedId);
  }

  // ------------------------------------------------------------
  // WATCH PROGRESS
  // ------------------------------------------------------------

  /// Returns the stored watch progress for media.
  double getWatchProgress(String mediaId) {
    final normalizedId = _normalizeId(mediaId);
    if (normalizedId == null) {
      return 0.0;
    }

    return watchProgress[normalizedId] ?? 0.0;
  }

  /// Updates watch progress.
  ///
  /// Progress is clamped to 0.0–1.0.
  ///
  /// The existing application behavior treats progress of 90% or greater as
  /// watched, so that threshold is intentionally preserved here.
  void setWatchProgress(
    String mediaId,
    double progress, {
    DateTime? watchedAt,
  }) {
    final normalizedId = _normalizeId(mediaId);
    if (normalizedId == null || !progress.isFinite) {
      return;
    }

    final clampedProgress =
        progress.clamp(0.0, 1.0).toDouble();

    watchProgress[normalizedId] = clampedProgress;

    final timestamp =
        watchedAt ?? DateTime.now();

    // Any playback activity updates history order.
    _touchWatchHistory(
      normalizedId,
      watchedAt: timestamp,
    );

    // Treat 90%+ as watched.
    if (clampedProgress >= 0.90) {
      if (!watchedMediaIds.contains(normalizedId)) {
        watchedMediaIds.add(normalizedId);
      }
    }
  }

  /// Removes stored progress for media.
  void removeWatchProgress(String mediaId) {
    final normalizedId = _normalizeId(mediaId);
    if (normalizedId == null) {
      return;
    }

    watchProgress.remove(normalizedId);
  }

  /// Clears all progress for media and optionally removes its history entry.
  void clearPlaybackState(
    String mediaId, {
    bool removeFromHistory = false,
  }) {
    final normalizedId = _normalizeId(mediaId);
    if (normalizedId == null) {
      return;
    }

    watchProgress.remove(normalizedId);

    if (removeFromHistory) {
      watchHistory.remove(normalizedId);
      watchHistoryTimestamps.remove(normalizedId);
    }
  }

  // ------------------------------------------------------------
  // WATCH HISTORY DETAILS
  // ------------------------------------------------------------

  /// Returns the most recent watch timestamp for media.
  DateTime? getLastWatchedAt(String mediaId) {
    final normalizedId = _normalizeId(mediaId);
    if (normalizedId == null) {
      return null;
    }

    return watchHistoryTimestamps[normalizedId];
  }

  /// Returns the completion value used by recommendations.
  ///
  /// A progress value of 0.0 means the title has not started.
  /// A value of 1.0 means it is completely watched.
  double getCompletion(String mediaId) {
    return getWatchProgress(mediaId);
  }

  /// Returns whether playback has reached the existing watched threshold.
  bool isCompleted(String mediaId) {
    return getWatchProgress(mediaId) >= 0.90;
  }

  // ------------------------------------------------------------
  // RECOMMENDATION HELPERS
  // ------------------------------------------------------------

  /// Determines whether a title is eligible for recommendation.
  ///
  /// A profile should not be recommended:
  /// - something it disliked;
  /// - something it already owns;
  /// - something it has already watched.
  bool shouldRecommend(String mediaId) {
    final normalizedId = _normalizeId(mediaId);
    if (normalizedId == null) {
      return false;
    }

    if (hasDisliked(normalizedId)) {
      return false;
    }

    if (ownsMedia(normalizedId)) {
      return false;
    }

    if (hasWatched(normalizedId)) {
      return false;
    }

    return true;
  }

  /// Returns the explicit interaction state for a title.
  ///
  /// Possible values are:
  /// - `owned`
  /// - `watched`
  /// - `liked`
  /// - `disliked`
  /// - `inProgress`
  /// - `none`
  ///
  /// The ordering intentionally prioritizes stronger state relationships.
  String interactionState(String mediaId) {
    final normalizedId = _normalizeId(mediaId);
    if (normalizedId == null) {
      return 'none';
    }

    if (ownsMedia(normalizedId)) {
      return 'owned';
    }

    if (hasDisliked(normalizedId)) {
      return 'disliked';
    }

    if (hasLiked(normalizedId)) {
      return 'liked';
    }

    if (hasWatched(normalizedId)) {
      return 'watched';
    }

    if (getWatchProgress(normalizedId) > 0.0) {
      return 'inProgress';
    }

    return 'none';
  }

  // ------------------------------------------------------------
  // COPY
  // ------------------------------------------------------------

  /// Creates a profile copy while preserving profile state unless a field is
  /// explicitly replaced.
  Profile copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    List<String>? ownedMediaIds,
    List<String>? watchedMediaIds,
    List<String>? likedMediaIds,
    List<String>? dislikedMediaIds,
    Map<String, double>? watchProgress,
    List<String>? watchHistory,
    Map<String, DateTime>? watchHistoryTimestamps,
    bool clearAvatarUrl = false,
  }) {
    return Profile(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl:
          clearAvatarUrl ? null : (avatarUrl ?? this.avatarUrl),
      ownedMediaIds:
          ownedMediaIds ?? List<String>.from(this.ownedMediaIds),
      watchedMediaIds:
          watchedMediaIds ?? List<String>.from(this.watchedMediaIds),
      likedMediaIds:
          likedMediaIds ?? List<String>.from(this.likedMediaIds),
      dislikedMediaIds:
          dislikedMediaIds ?? List<String>.from(this.dislikedMediaIds),
      watchProgress:
          watchProgress ?? Map<String, double>.from(this.watchProgress),
      watchHistory:
          watchHistory ?? List<String>.from(this.watchHistory),
      watchHistoryTimestamps: watchHistoryTimestamps ??
          Map<String, DateTime>.from(
            this.watchHistoryTimestamps,
          ),
    );
  }

  // ------------------------------------------------------------
  // JSON
  // ------------------------------------------------------------

  /// Serializes the profile for backend persistence/API transport.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatarUrl': avatarUrl,
      'ownedMediaIds': List<String>.from(ownedMediaIds),
      'watchedMediaIds': List<String>.from(watchedMediaIds),
      'likedMediaIds': List<String>.from(likedMediaIds),
      'dislikedMediaIds': List<String>.from(dislikedMediaIds),
      'watchProgress': Map<String, double>.from(watchProgress),
      'watchHistory': List<String>.from(watchHistory),
      'watchHistoryTimestamps': watchHistoryTimestamps.map(
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
      id: json['id']?.toString().trim() ?? '',
      name: json['name']?.toString() ?? '',
      avatarUrl: _nullableString(json['avatarUrl']),
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
      watchHistoryTimestamps: _dateTimeMap(
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

    return _normalizeStringList(
      value.map((item) => item.toString()).toList(),
    );
  }

  static Map<String, double> _doubleMap(
    dynamic value,
  ) {
    if (value is! Map) {
      return {};
    }

    final result = <String, double>{};

    value.forEach((key, value) {
      final normalizedKey = _normalizeId(key.toString());
      if (normalizedKey == null) {
        return;
      }

      final number = value is num
          ? value.toDouble()
          : double.tryParse(
              value.toString().trim(),
            );

      if (number != null && number.isFinite) {
        result[normalizedKey] =
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
      final normalizedKey = _normalizeId(key.toString());
      if (normalizedKey == null) {
        return;
      }

      final parsed = value is DateTime
          ? value
          : DateTime.tryParse(
              value.toString().trim(),
            );

      if (parsed != null) {
        result[normalizedKey] = parsed;
      }
    });

    return result;
  }

  // ------------------------------------------------------------
  // NORMALIZATION
  // ------------------------------------------------------------

  static String? _normalizeId(String? value) {
    if (value == null) {
      return null;
    }

    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  static String? _nullableString(dynamic value) {
    if (value == null) {
      return null;
    }

    final normalized = value.toString().trim();
    return normalized.isEmpty ? null : normalized;
  }

  static List<String> _normalizeStringList(
    Iterable<String>? values,
  ) {
    if (values == null) {
      return [];
    }

    final result = <String>[];
    final seen = <String>{};

    for (final value in values) {
      final normalized = _normalizeId(value);
      if (normalized == null || !seen.add(normalized)) {
        continue;
      }

      result.add(normalized);
    }

    return result;
  }

  static Map<String, double> _normalizeProgressMap(
    Map<String, double>? values,
  ) {
    if (values == null) {
      return {};
    }

    final result = <String, double>{};

    values.forEach((key, value) {
      final normalizedKey = _normalizeId(key);
      if (normalizedKey == null || !value.isFinite) {
        return;
      }

      result[normalizedKey] =
          value.clamp(0.0, 1.0).toDouble();
    });

    return result;
  }

  static Map<String, DateTime> _normalizeDateTimeMap(
    Map<String, DateTime>? values,
  ) {
    if (values == null) {
      return {};
    }

    final result = <String, DateTime>{};

    values.forEach((key, value) {
      final normalizedKey = _normalizeId(key);
      if (normalizedKey == null) {
        return;
      }

      result[normalizedKey] = value;
    });

    return result;
  }

  @override
  String toString() {
    return 'Profile('
        'id: $id, '
        'name: $name, '
        'ownedMediaCount: $ownedMediaCount, '
        'watchedMediaCount: $watchedMediaCount, '
        'likedMediaCount: $likedMediaCount, '
        'dislikedMediaCount: $dislikedMediaCount, '
        'watchHistoryCount: $watchHistoryCount'
        ')';
  }
}