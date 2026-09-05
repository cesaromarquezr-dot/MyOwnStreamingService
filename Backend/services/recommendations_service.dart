// backend/services/recommendations_service.dart

// Recommendation engine.
//
// This service intentionally does NOT know anything about HTTP,
// authentication, or the database.
//
// The route/controller layer should load the user's data and available
// media, convert that information into RecommendationMedia objects,
// and pass it into this service.
//
// This keeps the recommendation algorithm independent from the rest
// of the backend and makes it easier to test and expand later.

enum RecommendationReasonType {
  actor,
  multipleActors,
  reference,
  franchise,
  character,
  director,
  writer,
  music,
  similar,
  genre,
  theme,
  tag,
  preference,
  recentInterest,
}

/// Where the user can watch a title.
class WatchOption {
  final String provider;
  final String type;
  final String? url;

  const WatchOption({
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
}

/// Where the user can purchase a title.
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
}

/// Explains why a recommendation was made.
class RecommendationReason {
  final RecommendationReasonType type;
  final String title;
  final String description;

  /// IDs of related media that caused this recommendation.
  final List<String> relatedMediaIds;

  final List<WatchOption> watchOptions;
  final List<PurchaseOption> purchaseOptions;

  const RecommendationReason({
    required this.type,
    required this.title,
    required this.description,
    this.relatedMediaIds = const [],
    this.watchOptions = const [],
    this.purchaseOptions = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'title': title,
      'description': description,
      'relatedMediaIds': relatedMediaIds,
      'watchOptions':
          watchOptions.map((item) => item.toJson()).toList(),
      'purchaseOptions':
          purchaseOptions.map((item) => item.toJson()).toList(),
    };
  }
}

/// A normalized media object used by the recommendation engine.
///
/// The database/service layer converts the real database Media model
/// into this object.
///
/// This prevents the recommendation engine from becoming tightly
/// coupled to the database schema.
class RecommendationMedia {
  final String id;
  final String title;

  final int? year;

  /// movie / tvShow / episode / special, etc.
  final String mediaType;

  final String? seriesId;
  final String? franchiseId;

  final List<String> actors;
  final List<String> characters;
  final List<String> franchises;
  final List<String> genres;
  final List<String> themes;
  final List<String> tags;
  final List<String> directors;
  final List<String> writers;
  final List<String> music;
  final List<String> references;

  /// Optional provider availability.
  final List<WatchOption> watchOptions;
  final List<PurchaseOption> purchaseOptions;

  const RecommendationMedia({
    required this.id,
    required this.title,
    this.year,
    this.mediaType = 'movie',
    this.seriesId,
    this.franchiseId,
    this.actors = const [],
    this.characters = const [],
    this.franchises = const [],
    this.genres = const [],
    this.themes = const [],
    this.tags = const [],
    this.directors = const [],
    this.writers = const [],
    this.music = const [],
    this.references = const [],
    this.watchOptions = const [],
    this.purchaseOptions = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'year': year,
      'mediaType': mediaType,
      'seriesId': seriesId,
      'franchiseId': franchiseId,
      'actors': actors,
      'characters': characters,
      'franchises': franchises,
      'genres': genres,
      'themes': themes,
      'tags': tags,
      'directors': directors,
      'writers': writers,
      'music': music,
      'references': references,
      'watchOptions':
          watchOptions.map((item) => item.toJson()).toList(),
      'purchaseOptions':
          purchaseOptions.map((item) => item.toJson()).toList(),
    };
  }
}

/// Information about something the user watched.
class RecommendationHistoryItem {
  final String mediaId;

  /// When the user watched it.
  final DateTime? watchedAt;

  /// 0.0 - 1.0.
  ///
  /// 1.0 means the user completed it.
  final double completion;

  const RecommendationHistoryItem({
    required this.mediaId,
    this.watchedAt,
    this.completion = 1.0,
  });
}

/// User information consumed by the recommendation engine.
class RecommendationProfile {
  final List<String> ownedMediaIds;
  final List<String> likedMediaIds;
  final List<String> dislikedMediaIds;

  final List<RecommendationHistoryItem> history;

  const RecommendationProfile({
    this.ownedMediaIds = const [],
    this.likedMediaIds = const [],
    this.dislikedMediaIds = const [],
    this.history = const [],
  });
}

/// Configuration for the recommendation algorithm.
class RecommendationWeights {
  /// Strongest positive signal.
  final double franchise;

  final double character;

  final double multipleActors;

  final double actor;

  final double director;

  final double writer;

  final double music;

  final double genre;

  final double theme;

  final double tag;

  final double reference;

  final double similarity;

  /// Penalties.
  final double dislikedPenalty;
  final double alreadyWatchedPenalty;
  final double recentlyWatchedPenalty;

  const RecommendationWeights({
    this.franchise = 50,
    this.character = 40,
    this.multipleActors = 35,
    this.actor = 20,
    this.director = 25,
    this.writer = 20,
    this.music = 15,
    this.genre = 8,
    this.theme = 10,
    this.tag = 5,
    this.reference = 20,
    this.similarity = 15,
    this.dislikedPenalty = 1000,
    this.alreadyWatchedPenalty = 20,
    this.recentlyWatchedPenalty = 25,
  });
}

/// Final recommendation returned by the algorithm.
class RecommendationResult {
  final RecommendationMedia media;

  /// Raw algorithm score.
  final double score;

  /// 0 - 100 normalized confidence-like score.
  final double matchPercentage;

  final List<RecommendationReason> reasons;

  const RecommendationResult({
    required this.media,
    required this.score,
    required this.matchPercentage,
    required this.reasons,
  });

  Map<String, dynamic> toJson() {
    return {
      'media': media.toJson(),
      'score': score,
      'matchPercentage': matchPercentage,
      'reasons':
          reasons.map((reason) => reason.toJson()).toList(),
    };
  }
}

/// The main recommendation service.
class RecommendationsService {
  final RecommendationWeights weights;

  final int defaultLimit;

  /// Maximum number of recommendations from the same franchise.
  final int maxPerFranchise;

  /// Maximum number of recommendations from the same series.
  final int maxPerSeries;

  const RecommendationsService({
    this.weights = const RecommendationWeights(),
    this.defaultLimit = 20,
    this.maxPerFranchise = 3,
    this.maxPerSeries = 3,
  });

  /// Main recommendation method.
  ///
  /// This method is kept as a lightweight compatibility wrapper.
  ///
  /// For the actual backend recommendation flow, use
  /// [getRecommendationsFromMedia] because that method has access
  /// to the complete catalog and can compare the user's liked and
  /// watched titles against candidates.
  List<RecommendationResult> getRecommendations({
    required RecommendationProfile profile,
    required List<RecommendationMedia> availableMedia,
    int? limit,
  }) {
    return getRecommendationsFromMedia(
      profile: profile,
      catalog: availableMedia,
      limit: limit,
    );
  }

  /// Full recommendation method.
  ///
  /// This is the method the backend route/service layer should use.
  ///
  /// It:
  ///
  /// - removes owned media
  /// - removes disliked media
  /// - removes duplicate media IDs
  /// - compares candidates against liked media
  /// - compares candidates against watch history
  /// - rewards recent interests
  /// - rewards continuing a series
  /// - ranks candidates
  /// - applies franchise/series diversity
  List<RecommendationResult> getRecommendationsFromMedia({
    required RecommendationProfile profile,
    required List<RecommendationMedia> catalog,
    int? limit,
  }) {
    final targetLimit = _safeLimit(
      limit ?? defaultLimit,
    );

    if (catalog.isEmpty || targetLimit <= 0) {
      return [];
    }

    final mediaById = <String, RecommendationMedia>{};

    for (final media in catalog) {
      final id = _normalize(media.id);

      if (id.isEmpty) {
        continue;
      }

      mediaById.putIfAbsent(id, () => media);
    }

    final ownedIds = profile.ownedMediaIds
        .map(_normalize)
        .where((id) => id.isNotEmpty)
        .toSet();

    final dislikedIds = profile.dislikedMediaIds
        .map(_normalize)
        .where((id) => id.isNotEmpty)
        .toSet();

    final watchedIds = profile.history
        .map((item) => _normalize(item.mediaId))
        .where((id) => id.isNotEmpty)
        .toSet();

    final likedIds = profile.likedMediaIds
        .map(_normalize)
        .where((id) => id.isNotEmpty)
        .toSet();

    final likedMedia = <RecommendationMedia>[];

    for (final likedId in likedIds) {
      final media = mediaById[likedId];

      if (media != null) {
        likedMedia.add(media);
      }
    }

    final watchedMedia = <RecommendationMedia>[];

    for (final historyItem in profile.history) {
      final mediaId = _normalize(historyItem.mediaId);

      if (mediaId.isEmpty) {
        continue;
      }

      final media = mediaById[mediaId];

      if (media != null) {
        watchedMedia.add(media);
      }
    }

    final results = <RecommendationResult>[];
    final seenIds = <String>{};

    for (final candidate in mediaById.values) {
      final candidateId = _normalize(candidate.id);

      if (candidateId.isEmpty) {
        continue;
      }

      if (!seenIds.add(candidateId)) {
        continue;
      }

      // Never recommend something the user already owns.
      if (ownedIds.contains(candidateId)) {
        continue;
      }

      // Explicit dislikes are completely excluded.
      if (dislikedIds.contains(candidateId)) {
        continue;
      }

      final result = _scoreAgainstUser(
        candidate: candidate,
        likedMedia: likedMedia,
        watchedMedia: watchedMedia,
        history: profile.history,
        watchedIds: watchedIds,
      );

      if (result == null) {
        continue;
      }

      results.add(result);
    }

    // Highest score first.
    results.sort(_compareRecommendationResults);

    // Prevent the results from being overly repetitive.
    final diversified = _applyDiversity(results);

    if (diversified.length <= targetLimit) {
      return diversified;
    }

    return diversified.take(targetLimit).toList();
  }

  RecommendationResult? _scoreAgainstUser({
    required RecommendationMedia candidate,
    required List<RecommendationMedia> likedMedia,
    required List<RecommendationMedia> watchedMedia,
    required List<RecommendationHistoryItem> history,
    required Set<String> watchedIds,
  }) {
    double score = 0;

    final reasons = <RecommendationReason>[];

    // ------------------------------------------------------------
    // COMPARE AGAINST LIKES
    // ------------------------------------------------------------

    for (final liked in likedMedia) {
      if (_normalize(liked.id) == _normalize(candidate.id)) {
        continue;
      }

      final comparison = _compare(
        candidate: candidate,
        source: liked,
      );

      score += comparison.score;
      reasons.addAll(comparison.reasons);
    }

    // ------------------------------------------------------------
    // COMPARE AGAINST WATCH HISTORY
    // ------------------------------------------------------------

    for (final watched in watchedMedia) {
      if (_normalize(watched.id) == _normalize(candidate.id)) {
        continue;
      }

      final historyItems = history
          .where(
            (item) =>
                _normalize(item.mediaId) ==
                _normalize(watched.id),
          )
          .toList();

      if (historyItems.isEmpty) {
        continue;
      }

      // Use the strongest/recent history entry for this title.
      final historyItem = _bestHistoryItem(historyItems);

      var historyMultiplier = 0.35;

      // Completing a title is a stronger indication of interest.
      if (historyItem.completion >= 0.90) {
        historyMultiplier = 0.55;
      }

      final recencyMultiplier =
          _recencyMultiplier(historyItem.watchedAt);

      final comparison = _compare(
        candidate: candidate,
        source: watched,
      );

      score +=
          comparison.score *
          historyMultiplier *
          recencyMultiplier;

      reasons.addAll(comparison.reasons);
    }

    // ------------------------------------------------------------
    // RECENT INTEREST
    // ------------------------------------------------------------

    final recentHistory = history
        .where((item) => item.watchedAt != null)
        .where(
          (item) =>
              DateTime.now()
                  .difference(item.watchedAt!)
                  .inDays <=
              30,
        )
        .toList();

    if (recentHistory.isNotEmpty) {
      score += 2;

      reasons.add(
        const RecommendationReason(
          type: RecommendationReasonType.recentInterest,
          title: 'Based on your recent watching',
          description:
              'This recommendation matches patterns from '
              'something you watched recently.',
        ),
      );
    }

    // ------------------------------------------------------------
    // RECENTLY WATCHED / ALREADY WATCHED
    // ------------------------------------------------------------

    final candidateId = _normalize(candidate.id);

    if (watchedIds.contains(candidateId)) {
      score -= weights.alreadyWatchedPenalty;
    }

    // ------------------------------------------------------------
    // SERIES CONTINUATION BONUS
    // ------------------------------------------------------------

    if (candidate.seriesId != null &&
        candidate.seriesId!.trim().isNotEmpty) {
      final seriesId = _normalize(candidate.seriesId!);

      final sameSeriesMedia = watchedMedia
          .where(
            (media) =>
                media.seriesId != null &&
                _normalize(media.seriesId!) == seriesId,
          )
          .toList();

      if (sameSeriesMedia.isNotEmpty) {
        score += 45;

        reasons.add(
          RecommendationReason(
            type: RecommendationReasonType.reference,
            title: 'Continue this series',
            description:
                'You have watched another entry in this series.',
            relatedMediaIds: sameSeriesMedia
                .map((media) => media.id)
                .toList(),
          ),
        );
      }
    }

    // ------------------------------------------------------------
    // NO MATCH
    // ------------------------------------------------------------

    if (score <= 0) {
      return null;
    }

    return RecommendationResult(
      media: candidate,
      score: score,
      matchPercentage: _percentage(score),
      reasons: _deduplicateReasons(reasons),
    );
  }

  _ComparisonResult _compare({
    required RecommendationMedia candidate,
    required RecommendationMedia source,
  }) {
    double score = 0;

    final reasons = <RecommendationReason>[];

    // ------------------------------------------------------------
    // FRANCHISE
    // ------------------------------------------------------------

    final sharedFranchises = _intersection(
      candidate.franchises,
      source.franchises,
    );

    if (sharedFranchises.isNotEmpty) {
      score += weights.franchise;

      reasons.add(
        RecommendationReason(
          type: RecommendationReasonType.franchise,
          title: 'Same franchise',
          description:
              'This is connected to "${source.title}" '
              'through the same franchise.',
          relatedMediaIds: [source.id],
        ),
      );
    }

    // ------------------------------------------------------------
    // CHARACTER
    // ------------------------------------------------------------

    final sharedCharacters = _intersection(
      candidate.characters,
      source.characters,
    );

    if (sharedCharacters.isNotEmpty) {
      score += weights.character;

      reasons.add(
        RecommendationReason(
          type: RecommendationReasonType.character,
          title: 'Same character',
          description:
              'This recommendation shares a character '
              'with "${source.title}".',
          relatedMediaIds: [source.id],
        ),
      );
    }

    // ------------------------------------------------------------
    // ACTORS
    // ------------------------------------------------------------

    final sharedActors = _intersection(
      candidate.actors,
      source.actors,
    );

    if (sharedActors.length >= 2) {
      score += weights.multipleActors;

      reasons.add(
        RecommendationReason(
          type: RecommendationReasonType.multipleActors,
          title: 'Multiple familiar actors',
          description:
              'This recommendation shares multiple actors '
              'with "${source.title}".',
          relatedMediaIds: [source.id],
        ),
      );
    } else if (sharedActors.length == 1) {
      score += weights.actor;

      reasons.add(
        RecommendationReason(
          type: RecommendationReasonType.actor,
          title: 'Same actor',
          description:
              'This recommendation shares an actor '
              'with "${source.title}".',
          relatedMediaIds: [source.id],
        ),
      );
    }

    // ------------------------------------------------------------
    // DIRECTOR
    // ------------------------------------------------------------

    final sharedDirectors = _intersection(
      candidate.directors,
      source.directors,
    );

    if (sharedDirectors.isNotEmpty) {
      score += weights.director;

      reasons.add(
        RecommendationReason(
          type: RecommendationReasonType.director,
          title: 'Same director',
          description:
              'This recommendation shares a director '
              'with "${source.title}".',
          relatedMediaIds: [source.id],
        ),
      );
    }

    // ------------------------------------------------------------
    // WRITER
    // ------------------------------------------------------------

    final sharedWriters = _intersection(
      candidate.writers,
      source.writers,
    );

    if (sharedWriters.isNotEmpty) {
      score += weights.writer;

      reasons.add(
        RecommendationReason(
          type: RecommendationReasonType.writer,
          title: 'Same writer',
          description:
              'This recommendation shares a writer '
              'with "${source.title}".',
          relatedMediaIds: [source.id],
        ),
      );
    }

    // ------------------------------------------------------------
    // MUSIC
    // ------------------------------------------------------------

    final sharedMusic = _intersection(
      candidate.music,
      source.music,
    );

    if (sharedMusic.isNotEmpty) {
      score += weights.music;

      reasons.add(
        RecommendationReason(
          type: RecommendationReasonType.music,
          title: 'Music connection',
          description:
              'This recommendation shares a composer, '
              'score, soundtrack or music connection '
              'with "${source.title}".',
          relatedMediaIds: [source.id],
        ),
      );
    }

    // ------------------------------------------------------------
    // GENRES
    // ------------------------------------------------------------

    final sharedGenres = _intersection(
      candidate.genres,
      source.genres,
    );

    if (sharedGenres.isNotEmpty) {
      score += weights.genre * sharedGenres.length;

      reasons.add(
        RecommendationReason(
          type: RecommendationReasonType.genre,
          title: 'Similar genre',
          description:
              'This recommendation shares genre '
              'characteristics with "${source.title}".',
          relatedMediaIds: [source.id],
        ),
      );
    }

    // ------------------------------------------------------------
    // THEMES
    // ------------------------------------------------------------

    final sharedThemes = _intersection(
      candidate.themes,
      source.themes,
    );

    if (sharedThemes.isNotEmpty) {
      score += weights.theme * sharedThemes.length;

      reasons.add(
        RecommendationReason(
          type: RecommendationReasonType.theme,
          title: 'Similar themes',
          description:
              'This recommendation shares themes '
              'with "${source.title}".',
          relatedMediaIds: [source.id],
        ),
      );
    }

    // ------------------------------------------------------------
    // TAGS
    // ------------------------------------------------------------

    final sharedTags = _intersection(
      candidate.tags,
      source.tags,
    );

    if (sharedTags.isNotEmpty) {
      score += weights.tag * sharedTags.length;

      reasons.add(
        RecommendationReason(
          type: RecommendationReasonType.tag,
          title: 'Similar interests',
          description:
              'This recommendation shares tags '
              'with "${source.title}".',
          relatedMediaIds: [source.id],
        ),
      );
    }

    // ------------------------------------------------------------
    // REFERENCES
    // ------------------------------------------------------------

    final sharedReferences = _intersection(
      candidate.references,
      source.references,
    );

    if (sharedReferences.isNotEmpty) {
      score += weights.reference;

      reasons.add(
        RecommendationReason(
          type: RecommendationReasonType.reference,
          title: 'Related reference',
          description:
              'This recommendation has a reference or '
              'connection to "${source.title}".',
          relatedMediaIds: [source.id],
        ),
      );
    }

    // ------------------------------------------------------------
    // TITLE / REFERENCE CONNECTION
    // ------------------------------------------------------------

    final titleReferenceConnection =
        _hasReferenceConnection(
      candidate: candidate,
      source: source,
    );

    if (titleReferenceConnection) {
      score += weights.reference;

      reasons.add(
        RecommendationReason(
          type: RecommendationReasonType.reference,
          title: 'Related title reference',
          description:
              'This recommendation is connected to '
              '"${source.title}" through its catalog references.',
          relatedMediaIds: [source.id],
        ),
      );
    }

    // ------------------------------------------------------------
    // SIMILARITY BONUS
    // ------------------------------------------------------------

    final totalSignals =
        sharedActors.length +
        sharedCharacters.length +
        sharedFranchises.length +
        sharedGenres.length +
        sharedThemes.length +
        sharedTags.length +
        sharedDirectors.length +
        sharedWriters.length +
        sharedMusic.length +
        sharedReferences.length;

    if (totalSignals >= 3) {
      score += weights.similarity;

      reasons.add(
        RecommendationReason(
          type: RecommendationReasonType.similar,
          title: 'Very similar to something you like',
          description:
              'This recommendation shares several '
              'characteristics with "${source.title}".',
          relatedMediaIds: [source.id],
        ),
      );
    }

    return _ComparisonResult(
      score: score,
      reasons: reasons,
    );
  }

  /// Checks whether either title is referenced by the other.
  ///
  /// This is useful for cross-title relationships such as:
  ///
  /// - actors appearing in another title
  /// - movies/shows referencing another title
  /// - franchise or universe references
  /// - Easter eggs and related works
  bool _hasReferenceConnection({
    required RecommendationMedia candidate,
    required RecommendationMedia source,
  }) {
    final candidateId = _normalize(candidate.id);
    final sourceId = _normalize(source.id);

    final candidateTitle = _normalize(candidate.title);
    final sourceTitle = _normalize(source.title);

    final candidateReferences = candidate.references
        .map(_normalize)
        .where((value) => value.isNotEmpty)
        .toSet();

    final sourceReferences = source.references
        .map(_normalize)
        .where((value) => value.isNotEmpty)
        .toSet();

    if (candidateReferences.contains(sourceId) ||
        candidateReferences.contains(sourceTitle)) {
      return true;
    }

    if (sourceReferences.contains(candidateId) ||
        sourceReferences.contains(candidateTitle)) {
      return true;
    }

    return false;
  }

  /// Prevents the recommendation list from becoming repetitive.
  List<RecommendationResult> _applyDiversity(
    List<RecommendationResult> results,
  ) {
    final franchiseCounts = <String, int>{};
    final seriesCounts = <String, int>{};

    final output = <RecommendationResult>[];

    for (final result in results) {
      final media = result.media;

      final franchise = media.franchiseId != null
          ? _normalize(media.franchiseId!)
          : '';

      final series = media.seriesId != null
          ? _normalize(media.seriesId!)
          : '';

      if (franchise.isNotEmpty) {
        final count =
            franchiseCounts[franchise] ?? 0;

        if (count >= maxPerFranchise) {
          continue;
        }
      }

      if (series.isNotEmpty) {
        final count =
            seriesCounts[series] ?? 0;

        if (count >= maxPerSeries) {
          continue;
        }
      }

      output.add(result);

      if (franchise.isNotEmpty) {
        franchiseCounts[franchise] =
            (franchiseCounts[franchise] ?? 0) + 1;
      }

      if (series.isNotEmpty) {
        seriesCounts[series] =
            (seriesCounts[series] ?? 0) + 1;
      }
    }

    return output;
  }

  /// Gives more weight to recent viewing.
  double _recencyMultiplier(DateTime? watchedAt) {
    if (watchedAt == null) {
      return 0.75;
    }

    final now = DateTime.now();

    final difference = now.difference(watchedAt);

    // Future timestamps should not receive an exaggerated boost.
    if (difference.isNegative) {
      return 1.00;
    }

    final days = difference.inDays;

    if (days <= 7) {
      return 1.50;
    }

    if (days <= 30) {
      return 1.25;
    }

    if (days <= 90) {
      return 1.00;
    }

    if (days <= 365) {
      return 0.85;
    }

    return 0.70;
  }

  /// Chooses the strongest history entry for a title.
  ///
  /// Completion is prioritized, then the most recent watch date.
  RecommendationHistoryItem _bestHistoryItem(
    List<RecommendationHistoryItem> items,
  ) {
    var best = items.first;

    for (final item in items.skip(1)) {
      if (item.completion > best.completion) {
        best = item;
        continue;
      }

      if (item.completion == best.completion) {
        final bestDate = best.watchedAt;
        final itemDate = item.watchedAt;

        if (bestDate == null && itemDate != null) {
          best = item;
          continue;
        }

        if (bestDate != null &&
            itemDate != null &&
            itemDate.isAfter(bestDate)) {
          best = item;
        }
      }
    }

    return best;
  }

  /// Converts a raw score into a 0-100 match percentage.
  double _percentage(double score) {
    // 150 is treated as an extremely strong recommendation.
    final percentage =
        (score / 150.0) * 100.0;

    if (percentage < 0) {
      return 0;
    }

    if (percentage > 100) {
      return 100;
    }

    return double.parse(
      percentage.toStringAsFixed(1),
    );
  }

  /// Safely constrains the requested recommendation count.
  int _safeLimit(int value) {
    if (value < 1) {
      return 1;
    }

    if (value > 100) {
      return 100;
    }

    return value;
  }

  int _compareRecommendationResults(
    RecommendationResult a,
    RecommendationResult b,
  ) {
    final scoreComparison =
        b.score.compareTo(a.score);

    if (scoreComparison != 0) {
      return scoreComparison;
    }

    final percentageComparison =
        b.matchPercentage.compareTo(
      a.matchPercentage,
    );

    if (percentageComparison != 0) {
      return percentageComparison;
    }

    final yearA = a.media.year ?? 0;
    final yearB = b.media.year ?? 0;

    final yearComparison =
        yearB.compareTo(yearA);

    if (yearComparison != 0) {
      return yearComparison;
    }

    return a.media.title
        .toLowerCase()
        .compareTo(
          b.media.title.toLowerCase(),
        );
  }

  List<String> _intersection(
    List<String> first,
    List<String> second,
  ) {
    final a = first
        .map(_normalize)
        .where((value) => value.isNotEmpty)
        .toSet();

    final b = second
        .map(_normalize)
        .where((value) => value.isNotEmpty)
        .toSet();

    return a.intersection(b).toList();
  }

  String _normalize(String value) {
    return value.trim().toLowerCase();
  }

  List<RecommendationReason> _deduplicateReasons(
    List<RecommendationReason> reasons,
  ) {
    final seen = <String>{};
    final output = <RecommendationReason>[];

    for (final reason in reasons) {
      final normalizedRelatedIds = reason.relatedMediaIds
          .map(_normalize)
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      final key =
          '${reason.type.name}|'
          '${_normalize(reason.title)}|'
          '${normalizedRelatedIds.join(",")}';

      if (seen.add(key)) {
        output.add(
          reason,
        );
      }
    }

    return output;
  }
}

/// Internal comparison result.
class _ComparisonResult {
  final double score;
  final List<RecommendationReason> reasons;

  const _ComparisonResult({
    required this.score,
    required this.reasons,
  });
}