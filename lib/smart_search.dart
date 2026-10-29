// FILE: `lib/smart_search.dart`.
// Purpose: Implements the smart search portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'backend_api.dart';
import 'app_core.dart';
import 'cinematic_title_fonts.dart';
import 'privacy_preferences.dart';
import 'profile_content_safety.dart';
import 'details.dart';
import 'localization.dart';
import 'music.dart';
import 'music_catalog_screen.dart';
import 'music_soundtrack_index.dart';
import 'music_favorites.dart';
import 'shop.dart';
import 'hollywood.dart';
import 'social_detail_pages.dart';
import 'home_streaming_discovery.dart';
import 'character_discovery.dart';
import 'smart_search_intelligence.dart';
import 'recommendation_ownership.dart';
import 'core/services/tv_programming_service.dart';

class SmartSearch {
  static List<MediaItem> search(
    String query,
    List<MediaItem> library,
  ) {
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.isEmpty) return <MediaItem>[];

    final app = AppController.instance;
    final profile = app.currentProfile;
    final recommendationIds = <String, int>{
      for (var i = 0; i < app.recommendations.length; i++)
        app.recommendations[i].id: (50 - i).clamp(5, 50).toInt(),
    };

    // Search both locally owned titles and catalog candidates already supplied
    // by discovery/recommendation services. Prefer the user's local record when
    // duplicate IDs exist, but don't falsely label catalog-only results as owned.
    final candidatesById = <String, MediaItem>{};
    for (final media in <MediaItem>[...library, ...app.recommendations]) {
      final id = media.id.trim();
      if (id.isEmpty || _isExcludedContentType(media.type)) continue;
      if (profile != null &&
          (!media.isAccessibleTo(profile) ||
              !TvProgrammingService.eligibleForProfile(media, profile))) {
        continue;
      }
      candidatesById.putIfAbsent(id, () => media);
    }

    final typeQueries = <String>{'movie', 'movies', 'film', 'films'};
    final tvQueries = <String>{
      'tv',
      'tv show',
      'tv shows',
      'series',
      'show',
      'shows',
      'television',
    };
    final isMovieQuery = typeQueries.contains(normalizedQuery);
    final isTvQuery = tvQueries.contains(normalizedQuery);
    final relatedTerms = SmartSearchIntelligence.relatedTerms(normalizedQuery);
    final plotRelatedTitles = SmartSearchIntelligence.plotRelatedTitles(query);
    final scored = <_SearchMatch>[];

    for (final media in candidatesById.values) {
      final title = media.title.toLowerCase();
      final normalizedTitle = _normalize(title);
      final compactQuery = _compactTitleKey(normalizedQuery);
      final compactTitle = _compactTitleKey(normalizedTitle);
      final alternateTitles = <String>[
        media.originalTitle ?? '',
        media.canonicalTitle ?? '',
      ].where((value) => value.trim().isNotEmpty).toList(growable: false);
      final alternateKeys =
          alternateTitles.map(_normalize).toList(growable: false);
      final alternateCompactKeys = alternateTitles
          .map(_compactTitleKey)
          .where((value) => value.isNotEmpty)
          .toList(growable: false);

      final description = (media.description ?? '').toLowerCase();
      final normalizedDescription = _normalize(description);
      final type = media.type.toLowerCase();
      final year =
          (media.displayYearLabel ?? media.releaseYear?.toString() ?? '')
              .toLowerCase();
      final rating = media.rating.toString();
      var score = 0;

      final matchesExactTitle = normalizedTitle == normalizedQuery ||
          alternateKeys.contains(normalizedQuery) ||
          (compactQuery.isNotEmpty &&
              (compactTitle == compactQuery ||
                  alternateCompactKeys.contains(compactQuery)));
      final matchesTitle = normalizedTitle.contains(normalizedQuery) ||
          alternateKeys.any((value) => value.contains(normalizedQuery)) ||
          (compactQuery.isNotEmpty &&
              (compactTitle.contains(compactQuery) ||
                  alternateCompactKeys
                      .any((value) => value.contains(compactQuery))));
      final matchesDescription = normalizedDescription
              .contains(normalizedQuery) ||
          (compactQuery.length >= 4 &&
              _compactTitleKey(normalizedDescription).contains(compactQuery));
      final plotMetadata = <String>[
        description,
        ...media.genres,
        ...media.tags,
        ...media.characters,
        ...media.franchiseNames,
        ...media.actors,
      ].join(' ');
      final semanticPlotScore = SmartSearchIntelligence.semanticPlotScore(
        query,
        plotMetadata,
      );
      final matchesPlotRelatedTitle = plotRelatedTitles.any((relatedTitle) {
        final related = _normalize(relatedTitle);
        final compactRelated = _compactTitleKey(related);
        return normalizedTitle == related ||
            alternateKeys.contains(related) ||
            (compactRelated.isNotEmpty &&
                (_compactTitleKey(normalizedTitle) == compactRelated ||
                    alternateCompactKeys.contains(compactRelated)));
      });
      final matchesType = type.contains(normalizedQuery);
      final normalizedYearQuery = normalizedQuery.replaceAll('-', '–');
      final matchesYear = year == normalizedYearQuery ||
          year.split(RegExp(r'[-–]')).contains(normalizedQuery);
      final matchesRating = rating == normalizedQuery;

      if (matchesExactTitle) {
        score += 150;
      } else if (matchesTitle) {
        score += 85;
      } else if (normalizedQuery.length >= 4) {
        // Bounded typo tolerance keeps a one-letter typo useful without making
        // short and ambiguous queries explode into unrelated results.
        final titleTokens = <String>{
          ...normalizedTitle.split(' ').where((part) => part.isNotEmpty),
          for (final value in alternateKeys)
            ...value.split(' ').where((part) => part.isNotEmpty),
        };
        final queryTokens = normalizedQuery
            .split(' ')
            .where((part) => part.isNotEmpty)
            .toList();
        if (queryTokens.length == 1) {
          var bestDistance = 99;
          for (final token in titleTokens) {
            if ((token.length - normalizedQuery.length).abs() > 2) continue;
            final distance =
                _editDistance(token, normalizedQuery, maxDistance: 2);
            if (distance < bestDistance) bestDistance = distance;
          }
          if (bestDistance <= (normalizedQuery.length >= 8 ? 2 : 1)) {
            score += bestDistance == 0
                ? 65
                : bestDistance == 1
                    ? 38
                    : 24;
          }
        } else if (queryTokens.every((queryToken) => titleTokens.any(
            (titleToken) =>
                (titleToken.length - queryToken.length).abs() <= 1 &&
                _editDistance(titleToken, queryToken, maxDistance: 1) <= 1))) {
          score += 35;
        }
      }

      final metadataFields = <String>[
        ...media.actors,
        ...media.characters,
        ...media.directors,
        ...media.writers,
        ...media.genres,
        ...media.tags,
        ...media.music,
        ...media.studios,
        ...media.companies,
        ...media.franchiseNames,
        ...media.cinematicUniverseNames,
        ...media.cinematicUniverseIds,
        ...media.relationshipTypes,
        if (media.franchiseName != null) media.franchiseName!,
        if (media.continuityName != null) media.continuityName!,
        if (media.adaptationGroupName != null) media.adaptationGroupName!,
        for (final membership in media.universeMemberships)
          membership.values.map((value) => value?.toString() ?? '').join(' '),
      ];
      final matchesMetadata = _matchesMetadata(normalizedQuery, metadataFields);
      if (matchesMetadata) score += 35;
      if (matchesDescription) score += 15;
      if (matchesPlotRelatedTitle) score += 72;
      if (semanticPlotScore > 0) score += semanticPlotScore;
      if (matchesType) score += 15;
      if (matchesYear) score += 45;
      if (matchesRating) score += 25;
      if (isMovieQuery && _isMovie(type)) score += 70;
      if (isTvQuery && _isTvShow(type)) score += 70;

      // Cross-entity terms are deliberately lower-ranked than direct matches.
      // This connects character/franchise searches to known films, shows and
      // performer credits without pretending a connection that isn't in metadata.
      if (score == 0 && relatedTerms.isNotEmpty) {
        var relatedScore = 0;
        for (final term in relatedTerms) {
          final normalizedTerm = _normalize(term);
          final compactTerm = _compactTitleKey(normalizedTerm);
          if (normalizedTerm.isEmpty || compactTerm == compactQuery) continue;
          if (normalizedTitle.contains(normalizedTerm) ||
              _compactTitleKey(normalizedTitle).contains(compactTerm) ||
              alternateKeys.any((value) => value.contains(normalizedTerm)) ||
              alternateCompactKeys
                  .any((value) => value.contains(compactTerm))) {
            relatedScore = relatedScore < 72 ? 72 : relatedScore;
          } else if (_matchesMetadata(normalizedTerm, media.characters) ||
              _matchesMetadata(normalizedTerm, <String>[
                ...media.franchiseNames,
                ...media.cinematicUniverseNames,
                if (media.franchiseName != null) media.franchiseName!,
                if (media.continuityName != null) media.continuityName!,
              ])) {
            relatedScore = relatedScore < 55 ? 55 : relatedScore;
          } else if (_matchesMetadata(normalizedTerm, media.actors) &&
              relatedScore < 22) {
            relatedScore = 22;
          }
        }
        score = relatedScore;
      }

      if (score > 0) {
        score += recommendationIds[media.id] ?? 0;
        final ownedMatch =
            RecommendationOwnershipMatcher.findOwnedMediaForMedia(
          media: media,
          controller: app,
        );
        // Direct results from the user's own library are a modest, transparent
        // tie-breaker, never a substitute for matching the search intent.
        if (ownedMatch != null) score += 4;
        scored.add(_SearchMatch(media: media, score: score));
      }
    }

    scored.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;
      return a.media.title.toLowerCase().compareTo(b.media.title.toLowerCase());
    });
    return scored.map((match) => match.media).toList(growable: false);
  }

  /// Ranks the account's own library using backend recommendations when present,
  /// plus a transparent local fallback based on likes, watch history and metadata.
  /// This is a lightweight personal relevance model, not a claim of ML training.
  static List<MediaItem> recommendations(List<MediaItem> library,
      {int limit = 12}) {
    if (limit <= 0) return <MediaItem>[];
    final controller = AppController.instance;
    final profile = controller.currentProfile;
    final profileId = profile?.id;
    final personalized =
        PrivacyPreferencesStore.cached(profileId).personalizedRecommendations;

    // When personalization is disabled, only show generic picks from the
    // profile's local library. Do not consume backend suggestions that may have
    // been ranked from account activity. With personalization enabled, combine
    // local library entries and the full-catalog backend recommendations so
    // titles the user does not own can be discovered too.
    if (!personalized) {
      if (library.isEmpty) return <MediaItem>[];
      final excluded = <String>{
        ...controller.disliked.map((item) => item.id),
        ...controller.watched.map((item) => item.id),
      };
      final generic = library
          .where((item) =>
              !_isExcludedContentType(item.type) &&
              item.isAccessibleTo(profile) &&
              !excluded.contains(item.id) &&
              controller.getPlaybackProgress(item.id) < 0.95)
          .toList()
        ..sort((a, b) {
          final added = b.addedAt.compareTo(a.addedAt);
          return added != 0
              ? added
              : a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
      return generic.take(limit).toList(growable: false);
    }

    final poolById = <String, MediaItem>{};
    for (final media in <MediaItem>[
      ...library,
      ...controller.recommendations
    ]) {
      final id = media.id.trim();
      if (id.isEmpty ||
          _isExcludedContentType(media.type) ||
          !media.isAccessibleTo(profile)) {
        continue;
      }
      // Prefer the user's local record when the ID exists in both sources.
      poolById.putIfAbsent(id, () => media);
    }
    final candidatePool = poolById.values.toList(growable: false);
    if (candidatePool.isEmpty) return <MediaItem>[];

    final explicitRank = <String, int>{
      for (var i = 0; i < controller.recommendations.length; i++)
        controller.recommendations[i].id: (100 - i).clamp(20, 100).toInt(),
    };
    final dislikedIds = controller.disliked.map((media) => media.id).toSet();
    final completedIds = controller.watched.map((media) => media.id).toSet();
    final likedSeeds = controller.liked.toList(growable: false);
    final watchedSeeds = <MediaItem>[
      ...controller.watched,
      ...library.where((media) {
        final progress = controller.getPlaybackProgress(media.id);
        return progress >= 0.15 && progress < 0.95;
      }),
    ];

    final candidates = candidatePool
        .where((media) =>
            !dislikedIds.contains(media.id) &&
            !completedIds.contains(media.id) &&
            controller.getPlaybackProgress(media.id) < 0.95)
        .toList();

    int overlap(List<String> left, List<String> right) {
      final rightValues =
          right.map(_normalize).where((value) => value.isNotEmpty).toSet();
      return left
          .map(_normalize)
          .where((value) => value.isNotEmpty && rightValues.contains(value))
          .toSet()
          .length;
    }

    double similarity(MediaItem candidate, MediaItem seed) {
      var value = 0.0;
      value += overlap(candidate.genres, seed.genres) * 7;
      value += overlap(candidate.actors, seed.actors) * 5;
      value += overlap(candidate.directors, seed.directors) * 6;
      value += overlap(candidate.writers, seed.writers) * 2.5;
      value += overlap(candidate.tags, seed.tags) * 3.5;
      value += overlap(candidate.music, seed.music) * 2;
      value += overlap(candidate.studios, seed.studios) * 2;
      value += overlap(candidate.companies, seed.companies) * 1.5;
      final candidateFranchise = _normalize(candidate.franchiseName ?? '');
      final seedFranchise = _normalize(seed.franchiseName ?? '');
      if (candidateFranchise.isNotEmpty &&
          candidateFranchise == seedFranchise) {
        value += 9;
      }
      if (_normalize(candidate.type) == _normalize(seed.type)) value += 1.5;
      return value;
    }

    final scores = <String, double>{};
    for (final candidate in candidates) {
      var score = (explicitRank[candidate.id] ?? 0).toDouble();
      for (final seed in likedSeeds) {
        if (seed.id != candidate.id) score += similarity(candidate, seed) * 1.8;
      }
      for (final seed in watchedSeeds) {
        if (seed.id != candidate.id) score += similarity(candidate, seed);
      }
      final criticRating = (candidate.rating ?? 0).clamp(0, 10).toDouble();
      score += criticRating * 0.25;
      score += ((candidate.userRatingStars ?? 0).clamp(0, 5).toDouble()) * 0.5;
      final ageDays = DateTime.now().difference(candidate.addedAt).inDays;
      if (ageDays >= 0) score += (5 - ageDays / 30).clamp(0, 5).toDouble();
      scores[candidate.id] = score;
    }

    candidates.sort((a, b) {
      final scoreCompare = (scores[b.id] ?? 0).compareTo(scores[a.id] ?? 0);
      if (scoreCompare != 0) return scoreCompare;
      final dateCompare = b.addedAt.compareTo(a.addedAt);
      if (dateCompare != 0) return dateCompare;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return candidates.take(limit).toList(growable: false);
  }

  static bool _matchesMetadata(String query, Iterable<String> fields) {
    final queryTokens =
        query.split(' ').where((part) => part.isNotEmpty).toList();
    for (final field in fields) {
      final normalized = _normalize(field);
      if (normalized.contains(query) ||
          _compactTitleKey(normalized).contains(_compactTitleKey(query))) {
        return true;
      }
      if (query.length < 4) continue;
      final fieldTokens =
          normalized.split(' ').where((part) => part.isNotEmpty);
      if (queryTokens.every((queryToken) => fieldTokens.any((token) =>
          (token.length - queryToken.length).abs() <= 1 &&
          _editDistance(token, queryToken, maxDistance: 1) <= 1))) {
        return true;
      }
    }
    return false;
  }

  static int _editDistance(String left, String right,
      {required int maxDistance}) {
    if ((left.length - right.length).abs() > maxDistance) {
      return maxDistance + 1;
    }
    if (left == right) return 0;
    if (left.isEmpty) return right.length;
    if (right.isEmpty) return left.length;

    var previous = List<int>.generate(right.length + 1, (index) => index);
    for (var i = 1; i <= left.length; i++) {
      final current = List<int>.filled(right.length + 1, maxDistance + 1);
      current[0] = i;
      var rowMinimum = current[0];
      for (var j = 1; j <= right.length; j++) {
        final substitutionCost =
            left.codeUnitAt(i - 1) == right.codeUnitAt(j - 1) ? 0 : 1;
        current[j] = <int>[
          current[j - 1] + 1,
          previous[j] + 1,
          previous[j - 1] + substitutionCost,
        ].reduce((a, b) => a < b ? a : b);
        if (current[j] < rowMinimum) rowMinimum = current[j];
      }
      if (rowMinimum > maxDistance) return maxDistance + 1;
      previous = current;
    }
    return previous[right.length];
  }

  static bool _isExcludedContentType(String rawType) =>
      isExcludedEntertainmentType(rawType);

  static String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Creates a punctuation/spacing-insensitive key for title searches.
  /// For example, `Spider-Man`, `Spider Man`, and `SpiderMan` all become
  /// `spiderman`. This key is never used as a display title.
  static String _compactTitleKey(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static bool _isMovie(String type) {
    final normalized = _normalize(type);

    return normalized == 'movie' ||
        normalized == 'movies' ||
        normalized == 'film' ||
        normalized == 'films';
  }

  static bool _isTvShow(String type) {
    final normalized = _normalize(type);

    return normalized == 'tvshow' ||
        normalized == 'tv show' ||
        normalized == 'tv shows' ||
        normalized == 'series' ||
        normalized == 'show' ||
        normalized == 'shows';
  }
}

class _SearchMatch {
  final MediaItem media;
  final int score;

  const _SearchMatch({
    required this.media,
    required this.score,
  });
}

class SmartSearchScreen extends StatefulWidget {
  final String initialQuery;

  const SmartSearchScreen({
    super.key,
    this.initialQuery = '',
  });

  @override
  State<SmartSearchScreen> createState() => _SmartSearchScreenState();
}

class _SmartSearchScreenState extends State<SmartSearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController controller = TextEditingController();

  final FocusNode searchFocusNode = FocusNode();

  List<MediaItem> results = [];
  List<MusicTrack> musicResults = [];
  List<Map<String, dynamic>> albumResults = <Map<String, dynamic>>[];
  String selectedSearchCategory = 'All';
  List<ShopProduct> productResults = <ShopProduct>[];
  List<Map<String, dynamic>> peopleResults = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> characterResults = <Map<String, dynamic>>[];
  List<SmartSearchEpisodeHit> episodeResults = <SmartSearchEpisodeHit>[];
  List<Map<String, dynamic>> socialResults = <Map<String, dynamic>>[];
  bool remoteSearchLoading = false;
  Timer? _searchDebounce;
  int _remoteSearchGeneration = 0;
  static final Map<String, List<Map<String, dynamic>>> _tmdbPersonSearchCache =
      <String, List<Map<String, dynamic>>>{};
  static final Map<String, Map<String, dynamic>> _tmdbMultiSearchCache =
      <String, Map<String, dynamic>>{};

  late AnimationController animationController;

  @override

  /// Performs `initState` for this feature. Update this documentation when its contract changes.
  void initState() {
    super.initState();

    controller.text = widget.initialQuery;
    unawaited(_initializeMusicSearch());
    if (widget.initialQuery.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) performSearch(widget.initialQuery);
      });
    }

    searchFocusNode.addListener(_focusChanged);

    animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    animationController.forward();
  }

  /// Loads the active profile music catalog before searching across media types.
  Future<void> _initializeMusicSearch() async {
    final profileId = AppController.instance.currentProfile?.id;
    await Future.wait<void>([
      _ignoreOptionalInitialization(
          () => MusicLibraryStore.instance.initializeForProfile(profileId)),
      _ignoreOptionalInitialization(
          () => MusicFavoritesBridge.initializeForProfile(profileId)),
      _ignoreOptionalInitialization(() => ShopCatalog.instance.initialize()),
    ]);
    if (mounted && controller.text.trim().isNotEmpty) {
      performSearch(controller.text);
    }
  }

  Future<void> _ignoreOptionalInitialization(
      Future<void> Function() initialize) async {
    try {
      await initialize();
    } catch (_) {
      // One unavailable optional catalog must not disable the remaining search.
    }
  }

  void _focusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override

  /// Performs `dispose` for this feature. Update this documentation when its contract changes.
  void dispose() {
    _searchDebounce?.cancel();
    _remoteSearchGeneration++;
    controller.dispose();

    searchFocusNode
      ..removeListener(_focusChanged)
      ..dispose();

    animationController.dispose();

    super.dispose();
  }

  /// Performs `performSearch` for this feature. Update this documentation when its contract changes.
  void performSearch([String? value]) {
    final query = value ?? controller.text;
    final library = AppController.instance.library;
    final normalized = query.trim().toLowerCase();
    final activeProfile = AppController.instance.currentProfile;
    final musicMatches = normalized.isEmpty
        ? <MusicTrack>[]
        : <MusicTrack>{
            ...MusicLibraryStore.instance.tracks,
            ...MusicLibraryStore.instance.catalogTracks.values,
          }.where((track) {
            if (profileBlocksExplicitMusic(activeProfile) && track.explicit) {
              return false;
            }
            if (profileBlocksMatureMusic(activeProfile) && track.matureTheme) {
              return false;
            }
            return track.matchesSearchQuery(normalized);
          }).toList();
    musicMatches.sort((a, b) {
      int rank(MusicTrack track) {
        final title = track.title.toLowerCase();
        if (title == normalized) return 0;
        if (title.contains(normalized)) return 1;
        if (_musicTextMatches(track.lyrics, normalized)) return 2;
        if (<String>[...track.soundtrackForTitles, ...track.relatedMediaTitles]
            .any((value) => _musicTextMatches(value, normalized))) {
          return 3;
        }
        if (_musicTextMatches(track.artist, normalized)) return 4;
        if (_musicTextMatches(track.album, normalized)) return 5;
        return 6;
      }

      final byRank = rank(a).compareTo(rank(b));
      return byRank != 0
          ? byRank
          : a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });

    // Source-backed soundtrack fallback entries make franchise search useful
    // even when providers omit track-to-film relationships or the user is offline.
    for (final soundtrackTrack in MusicSoundtrackIndex.search(query)) {
      final sameTrack = musicMatches.indexWhere((track) =>
          _compactMusicText(track.title) ==
              _compactMusicText(soundtrackTrack.title) &&
          _compactMusicText(track.artist) ==
              _compactMusicText(soundtrackTrack.artist));
      if (sameTrack < 0) {
        musicMatches.add(soundtrackTrack);
      } else {
        final existing = musicMatches[sameTrack];
        musicMatches[sameTrack] = MusicTrack(
          id: existing.id,
          title: existing.title,
          artist: existing.artist,
          album: existing.album.isNotEmpty
              ? existing.album
              : soundtrackTrack.album,
          artworkUrl: existing.artworkUrl ?? soundtrackTrack.artworkUrl,
          audioUrl: existing.audioUrl,
          duration: existing.duration,
          genres: existing.genres,
          featuredArtists: existing.featuredArtists,
          subgenres: existing.subgenres,
          explicit: existing.explicit,
          matureTheme: existing.matureTheme,
          lyrics: existing.lyrics,
          soundtrackForTitles: <String>{
            ...existing.soundtrackForTitles,
            ...soundtrackTrack.soundtrackForTitles
          }.toList(),
          relatedMediaTitles: <String>{
            ...existing.relatedMediaTitles,
            ...soundtrackTrack.relatedMediaTitles
          }.toList(),
          credits: <String>{...existing.credits, ...soundtrackTrack.credits}
              .toList(),
          soundtrackSourceName: soundtrackTrack.soundtrackSourceName,
          soundtrackSourceUrl: soundtrackTrack.soundtrackSourceUrl,
          providerUrl: existing.providerUrl ?? soundtrackTrack.providerUrl,
          providerName: existing.providerName ?? soundtrackTrack.providerName,
          providerId: existing.providerId ?? soundtrackTrack.providerId,
          catalogOnly: existing.catalogOnly,
          modifiedAt: existing.modifiedAt,
          addedByProfileId: existing.addedByProfileId,
          addedByProfileName: existing.addedByProfileName,
          addedSource: existing.addedSource,
        );
      }
    }

    final localAlbums = _localAlbumSearch(normalized);
    final localPeople = _localPeople(normalized);
    final localCharacters = _localCharacters(normalized);
    final themedEpisodes = normalized.isEmpty
        ? <SmartSearchEpisodeHit>[]
        : SmartSearchIntelligence.themedEpisodes(query, library);
    final products = normalized.isEmpty
        ? <ShopProduct>[]
        : (normalized == 'shop' ||
                normalized == 'products' ||
                normalized == 'merchandise'
            ? ShopCatalog.instance.products
                .where((product) => product.active)
                .take(12)
                .toList()
            : ShopCatalog.instance.searchProducts(query).take(12).toList());
    _searchDebounce?.cancel();
    final generation = ++_remoteSearchGeneration;
    setState(() {
      results = SmartSearch.search(query, library);
      musicResults = musicMatches;
      albumResults = localAlbums;
      productResults = products;
      peopleResults = localPeople;
      characterResults = localCharacters;
      episodeResults = themedEpisodes;
      socialResults = <Map<String, dynamic>>[];
      remoteSearchLoading = normalized.length >= 2 &&
          AppController.instance.backendApi.isAuthenticated;
    });

    if (normalized.length >= 2 &&
        AppController.instance.backendApi.isAuthenticated) {
      _searchDebounce = Timer(const Duration(milliseconds: 350), () {
        unawaited(_loadRemoteSearch(normalized, generation));
      });
    }

    animationController
      ..reset()
      ..forward();
  }

  String _compactMusicText(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');

  bool _musicTextMatches(String value, String query) {
    final field = value.trim().toLowerCase();
    final needle = query.trim().toLowerCase();
    if (field.isEmpty || needle.isEmpty) return false;
    if (field.contains(needle)) return true;
    final compactField = _compactMusicText(field);
    final compactNeedle = _compactMusicText(needle);
    return compactNeedle.length >= 2 && compactField.contains(compactNeedle);
  }

  List<Map<String, dynamic>> _localAlbumSearch(String query) {
    if (query.trim().isEmpty) return <Map<String, dynamic>>[];
    final groups = <String, List<MusicTrack>>{};
    for (final track in <MusicTrack>{
      ...MusicLibraryStore.instance.tracks,
      ...MusicLibraryStore.instance.catalogTracks.values,
    }) {
      final album = track.album.trim();
      if (album.isEmpty ||
          (!_musicTextMatches(album, query) &&
              !_musicTextMatches(track.artist, query))) {
        continue;
      }
      final key =
          '${_compactMusicText(album)}|${_compactMusicText(track.artist)}';
      (groups[key] ??= <MusicTrack>[]).add(track);
    }
    final output = groups.entries.map((entry) {
      final first = entry.value.first;
      return <String, dynamic>{
        'id': 'local-album:${entry.key}',
        'title': first.album,
        'artist': first.artist,
        'imageUrl': first.artworkUrl ?? '',
        'trackCount': entry.value.length,
        'tracks': entry.value,
        'source': 'local-library',
        'isOwned': MusicLibraryStore.instance.tracks.any((local) =>
            local.album.trim().toLowerCase() ==
                first.album.trim().toLowerCase() &&
            local.artist.trim().toLowerCase() ==
                first.artist.trim().toLowerCase()),
      };
    }).toList();
    output.sort((a, b) => (a['title'] ?? '')
        .toString()
        .toLowerCase()
        .compareTo((b['title'] ?? '').toString().toLowerCase()));
    return output.take(12).toList(growable: false);
  }

  List<Map<String, dynamic>> _localPeople(String query) {
    if (query.isEmpty) return <Map<String, dynamic>>[];
    final controller = AppController.instance;
    final indexedArtists = <String>{
      ...controller.musicCatalog,
      for (final track in <MusicTrack>{
        ...MusicLibraryStore.instance.tracks,
        ...MusicLibraryStore.instance.catalogTracks.values
      })
        track.artist,
      for (final track in <MusicTrack>{
        ...MusicLibraryStore.instance.tracks,
        ...MusicLibraryStore.instance.catalogTracks.values
      })
        ...track.featuredArtists,
    }.where((name) => name.trim().isNotEmpty).toList(growable: false);
    final sources = <String, List<String>>{
      'Actor': controller.actorsCatalog,
      'Director': controller.directorsCatalog,
      'Writer': controller.writersCatalog,
      'Artist / band': indexedArtists,
    };
    final categoryForQuery = switch (query) {
      'actor' || 'actors' => 'Actor',
      'director' || 'directors' => 'Director',
      'writer' || 'writers' => 'Writer',
      'artist' ||
      'artists' ||
      'band' ||
      'bands' ||
      'singer' ||
      'singers' =>
        'Artist / band',
      _ => null,
    };
    final found = <String, Map<String, dynamic>>{};
    for (final entry in sources.entries) {
      if (categoryForQuery != null && entry.key != categoryForQuery) continue;
      for (final name in entry.value) {
        final clean = name.trim();
        if (clean.isEmpty ||
            (categoryForQuery == null &&
                !clean.toLowerCase().contains(query))) {
          continue;
        }
        found.putIfAbsent(
            '${entry.key.toLowerCase()}|${clean.toLowerCase()}',
            () => <String, dynamic>{
                  'id': clean,
                  'name': clean,
                  'category': entry.key,
                  'source': 'local-library',
                });
      }
    }
    // A character query also returns only explicitly registered cast-to-character
    // credits, such as the performers credited as Peter Parker or Alex Russo.
    final matchingCharacters = _matchingLocalCharacters(query);
    for (final character in matchingCharacters) {
      for (final performer
          in CharacterDiscoveryIndex.localPerformersForCharacter(
        character,
        controller.library,
      )) {
        final name = performer['name']?.toString().trim() ?? '';
        if (name.isEmpty) continue;
        found.putIfAbsent(name.toLowerCase(), () => performer);
      }
    }
    return found.values.take(24).toList(growable: false);
  }

  List<String> _matchingLocalCharacters(String query) {
    final clean = query.trim();
    if (clean.length < 2) return const <String>[];
    final normalized = SmartSearchIntelligence.normalize(clean);
    final compact = SmartSearchIntelligence.compact(clean);
    final aliases = SmartSearchIntelligence.relatedTerms(clean);
    final aliasKeys = aliases
        .map(SmartSearchIntelligence.normalize)
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    final aliasCompactKeys = aliases
        .map(SmartSearchIntelligence.compact)
        .where((value) => value.length >= 4)
        .toList(growable: false);
    return CharacterDiscoveryIndex.knownCharacterNames(
      AppController.instance.library,
    )
        .where((name) {
          final candidate = SmartSearchIntelligence.normalize(name);
          final candidateCompact = SmartSearchIntelligence.compact(name);
          final directMatch = candidate.contains(normalized) ||
              candidateCompact.contains(compact) ||
              (compact.length >= 5 && compact.contains(candidateCompact));
          if (directMatch) return true;
          return aliasKeys.any((alias) => candidate.contains(alias)) ||
              aliasCompactKeys.any((alias) => candidateCompact.contains(alias));
        })
        .take(18)
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _localCharacters(String query) {
    final library = AppController.instance.library;
    final names = _matchingLocalCharacters(query);
    return names.map((name) {
      final appearances =
          CharacterDiscoveryIndex.titlesForCharacter(name, library);
      final imageUrl = _characterImageUrl(name, appearances);
      return <String, dynamic>{
        'id': 'local-character:${SmartSearchIntelligence.compact(name)}',
        'name': name,
        'category': 'Fictional character',
        'source': 'local-library-character-index',
        if (imageUrl != null) 'imageUrl': imageUrl,
        'appearanceCount': appearances.length,
      };
    }).toList(growable: false);
  }

  String? _characterImageUrl(
      String characterName, List<MediaItem> appearances) {
    final wanted = SmartSearchIntelligence.compact(characterName);
    for (final media in appearances) {
      for (final event in media.xrayEvents) {
        final character = <String>[
          event['characterName']?.toString() ?? '',
          event['character_name']?.toString() ?? '',
          event['character']?.toString() ?? '',
        ].join(' ');
        if (SmartSearchIntelligence.compact(character).contains(wanted)) {
          for (final key in const <String>[
            'characterImageUrl',
            'character_image_url',
            'characterPhotoUrl',
            'character_photo_url',
            'imageUrl',
            'image_url',
            'photoUrl',
            'photo_url',
          ]) {
            final url = event[key]?.toString().trim() ?? '';
            if (url.startsWith('http')) return url;
          }
        }
      }
    }
    for (final media in appearances) {
      final url = media.imageUrl?.trim() ?? '';
      if (url.startsWith('http')) return url;
    }
    return null;
  }

  List<Map<String, dynamic>> _maps(dynamic value) => value is List
      ? value
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList()
      : <Map<String, dynamic>>[];

  String _mapText(Map<String, dynamic> value, Iterable<String> keys) => keys
      .map((key) => value[key]?.toString() ?? '')
      .where((text) => text.isNotEmpty)
      .join(' ');

  String? _tmdbImageUrl(dynamic rawPath, {String size = 'w500'}) {
    final path = rawPath?.toString().trim() ?? '';
    if (!path.startsWith('/')) return null;
    return 'https://image.tmdb.org/t/p/$size$path';
  }

  Future<List<Map<String, dynamic>>> _searchTmdbPeople(
      String personName) async {
    final cacheKey = SmartSearchIntelligence.compact(personName);
    final cached = _tmdbPersonSearchCache[cacheKey];
    if (cached != null) return cached;
    try {
      final payload = await AppController.instance.backendApi.getTmdbMetadata(
        '/search/person',
        <String, String>{
          'query': personName,
          'page': '1',
          'include_adult': 'false',
          'language': 'en-US',
        },
      );
      final rawResults = payload['results'];
      final people = <Map<String, dynamic>>[];
      if (rawResults is List) {
        for (final raw in rawResults.whereType<Map>().take(5)) {
          final row = Map<String, dynamic>.from(raw);
          final id = row['id']?.toString().trim() ?? '';
          final name = (row['name'] ?? '').toString().trim();
          if (id.isEmpty || name.isEmpty) continue;
          final knownForRows = row['known_for'];
          final knownFor = knownForRows is List
              ? knownForRows
                  .whereType<Map>()
                  .map((work) =>
                      (work['title'] ?? work['name'] ?? '').toString().trim())
                  .where((title) => title.isNotEmpty)
                  .take(4)
                  .join(' · ')
              : '';
          final profilePath = row['profile_path']?.toString().trim() ?? '';
          people.add(<String, dynamic>{
            'id': 'tmdb-person:$id',
            'tmdbId': id,
            'name': name,
            'category': (row['known_for_department'] ?? 'Actor').toString(),
            'knownFor': knownFor.isEmpty ? 'TMDB person result' : knownFor,
            if (profilePath.startsWith('/'))
              'photoUrl': _tmdbImageUrl(profilePath, size: 'w185'),
            'source': 'tmdb-live-search',
          });
        }
      }
      final stablePeople = List<Map<String, dynamic>>.unmodifiable(people);
      _tmdbPersonSearchCache[cacheKey] = stablePeople;
      return stablePeople;
    } catch (_) {
      // Keep global-catalog and local people results usable when TMDB is offline.
      return const <Map<String, dynamic>>[];
    }
  }

  Future<List<MediaItem>> _searchRelatedTmdbMedia(
    String query,
    List<MediaItem> alreadyLoaded,
  ) async {
    final relatedQueries = SmartSearchIntelligence.relatedCatalogQueries(query);
    if (relatedQueries.isEmpty) return const <MediaItem>[];
    final app = AppController.instance;
    final termsAndPayloads = await Future.wait(
      relatedQueries.map((term) async {
        final cacheKey = SmartSearchIntelligence.normalize(term);
        try {
          final payload = _tmdbMultiSearchCache[cacheKey] ??
              await app.backendApi.getTmdbMetadata(
                '/search/multi',
                <String, String>{
                  'query': term,
                  'page': '1',
                  'include_adult': 'false',
                  'language': 'en-US',
                },
              );
          _tmdbMultiSearchCache[cacheKey] = payload;
          return <String, dynamic>{'term': term, 'payload': payload};
        } catch (_) {
          return <String, dynamic>{
            'term': term,
            'payload': <String, dynamic>{}
          };
        }
      }),
    );

    final profile = app.currentProfile;
    final output = <MediaItem>[];
    for (final entry in termsAndPayloads) {
      final payload = entry['payload'];
      if (payload is! Map || payload['results'] is! List) continue;
      for (final raw in (payload['results'] as List).whereType<Map>()) {
        final row = Map<String, dynamic>.from(raw);
        final mediaType = (row['media_type'] ?? '').toString();
        if (mediaType != 'movie' && mediaType != 'tv') continue;
        final rawId = row['id']?.toString().trim() ?? '';
        final isTv = mediaType == 'tv';
        final title =
            (isTv ? row['name'] : row['title'])?.toString().trim() ?? '';
        if (rawId.isEmpty || title.isEmpty) continue;
        final date =
            ((isTv ? row['first_air_date'] : row['release_date']) ?? '')
                .toString()
                .trim();
        final poster = _tmdbImageUrl(row['poster_path']) ??
            _tmdbImageUrl(row['backdrop_path']);
        final media = MediaItem.fromJson(<String, dynamic>{
          'id': 'tmdb:$mediaType:$rawId',
          'title': title,
          'originalTitle': row['original_title'] ?? row['original_name'],
          'canonicalTitle': title,
          'type': isTv ? 'tvShow' : 'movie',
          if (poster != null) 'imageUrl': poster,
          'description': row['overview']?.toString() ?? '',
          'releaseDate': date,
          'releaseYear':
              date.length >= 4 ? int.tryParse(date.substring(0, 4)) : null,
          if (isTv) 'seriesStartDate': date,
          'rating': row['vote_average'],
          'countryOfOrigin': row['origin_country'],
          'addedSource': 'tmdb-related-search',
        });
        final identity = RecommendationOwnershipMatcher.normalizeTitle(title);
        final candidates = <MediaItem>[
          ...app.library,
          ...app.recommendations,
          ...alreadyLoaded,
          ...output,
        ];
        final duplicate = candidates.any((existing) {
          final sameFormat = isTv
              ? existing.isSeries
              : SmartSearch._isMovie(existing.type.toLowerCase());
          if (!sameFormat) return false;
          final existingTitles = <String>{
            RecommendationOwnershipMatcher.normalizeTitle(existing.title),
            RecommendationOwnershipMatcher.normalizeTitle(
                existing.originalTitle ?? ''),
            RecommendationOwnershipMatcher.normalizeTitle(
                existing.canonicalTitle ?? ''),
          }..remove('');
          return existingTitles.contains(identity);
        });
        if (duplicate) continue;
        if (profile != null &&
            (!media.isAccessibleTo(profile) ||
                !TvProgrammingService.eligibleForProfile(media, profile))) {
          continue;
        }
        output.add(media);
      }
    }
    return output;
  }

  Future<void> _loadRemoteSearch(String query, int generation) async {
    final app = AppController.instance;
    final profile = app.currentProfile;
    if (profile == null || !app.backendApi.isAuthenticated) {
      if (mounted && generation == _remoteSearchGeneration) {
        setState(() => remoteSearchLoading = false);
      }
      return;
    }

    final remoteMedia = <MediaItem>[];
    final remotePeople = <Map<String, dynamic>>[];
    final remoteCharacters = <Map<String, dynamic>>[];
    final remoteSocial = <Map<String, dynamic>>[];
    final remoteMusic = <MusicTrack>[];
    final remoteAlbums = <Map<String, dynamic>>[];
    try {
      // Search the backend's complete catalog as well as the local library.
      // This is how catalog-only films and series can appear without being
      // mislabeled as locally owned or playable.
      final response =
          await app.backendApi.searchGlobalMedia(query, limit: 100);
      final rawResults = response['results'];
      if (rawResults is List) {
        for (final raw in rawResults.whereType<Map>()) {
          final row = Map<String, dynamic>.from(raw);
          final rawMedia = row['media'];
          if (rawMedia is! Map) continue;
          final media = MediaItem.fromJson(Map<String, dynamic>.from(rawMedia));
          if (media.id.trim().isEmpty || media.title.trim().isEmpty) continue;
          if (!media.isAccessibleTo(profile) ||
              !TvProgrammingService.eligibleForProfile(media, profile)) {
            continue;
          }
          remoteMedia.add(media);
        }
      }
    } catch (_) {
      // Keep the local and previously loaded discovery candidates available offline.
    }

    // Search TMDB through the backend's allow-listed proxy so unowned catalog
    // entries and people can appear in Smart Search. These records are metadata
    // only; they do not gain local ownership or a playable source.
    if (query.trim().length >= 3) {
      try {
        final cacheKey = SmartSearchIntelligence.normalize(query);
        final payload = _tmdbMultiSearchCache[cacheKey] ??
            await app.backendApi.getTmdbMetadata(
              '/search/multi',
              <String, String>{
                'query': query,
                'page': '1',
                'include_adult': 'false',
                'language': 'en-US',
              },
            );
        _tmdbMultiSearchCache[cacheKey] = payload;
        final rawResults = payload['results'];
        if (rawResults is List) {
          for (final raw in rawResults.whereType<Map>()) {
            final row = Map<String, dynamic>.from(raw);
            final mediaType = (row['media_type'] ?? '').toString();
            final id = row['id']?.toString().trim() ?? '';
            if (mediaType == 'person') {
              final name = (row['name'] ?? '').toString().trim();
              if (id.isEmpty || name.isEmpty) continue;
              final knownForRows = row['known_for'];
              final knownFor = knownForRows is List
                  ? knownForRows
                      .whereType<Map>()
                      .map((work) => (work['title'] ?? work['name'] ?? '')
                          .toString()
                          .trim())
                      .where((title) => title.isNotEmpty)
                      .take(4)
                      .join(' · ')
                  : '';
              final profilePath = row['profile_path']?.toString().trim() ?? '';
              remotePeople.add(<String, dynamic>{
                'id': 'tmdb-person:$id',
                'tmdbId': id,
                'name': name,
                'category': (row['known_for_department'] ?? 'Actor').toString(),
                'knownFor': knownFor,
                if (profilePath.startsWith('/'))
                  'photoUrl': _tmdbImageUrl(profilePath, size: 'w185'),
                'source': 'tmdb-live-search',
              });
              continue;
            }
            if (mediaType != 'movie' && mediaType != 'tv') continue;
            final title = (mediaType == 'movie' ? row['title'] : row['name'])
                    ?.toString()
                    .trim() ??
                '';
            if (id.isEmpty || title.isEmpty) continue;
            final isTv = mediaType == 'tv';
            final rawDate = (isTv ? row['first_air_date'] : row['release_date'])
                    ?.toString()
                    .trim() ??
                '';
            final poster = _tmdbImageUrl(row['poster_path']) ??
                _tmdbImageUrl(row['backdrop_path']);
            final tmdbMedia = MediaItem.fromJson(<String, dynamic>{
              'id': 'tmdb:$mediaType:$id',
              'title': title,
              'originalTitle': row['original_title'] ?? row['original_name'],
              'canonicalTitle': title,
              'type': isTv ? 'tvShow' : 'movie',
              if (poster != null) 'imageUrl': poster,
              'description': row['overview']?.toString() ?? '',
              'releaseDate': rawDate,
              'releaseYear': rawDate.length >= 4
                  ? int.tryParse(rawDate.substring(0, 4))
                  : null,
              if (isTv) 'seriesStartDate': rawDate,
              'rating': row['vote_average'],
              'countryOfOrigin': row['origin_country'],
              'addedSource': 'tmdb-live-search',
            });
            final identity =
                RecommendationOwnershipMatcher.normalizeTitle(title);
            final duplicate = <MediaItem>[
              ...app.library,
              ...app.recommendations,
              ...remoteMedia,
            ].any((existing) {
              final sameFormat = isTv
                  ? existing.isSeries
                  : SmartSearch._isMovie(existing.type.toLowerCase());
              if (!sameFormat) return false;
              final existingTitles = <String>{
                RecommendationOwnershipMatcher.normalizeTitle(existing.title),
                RecommendationOwnershipMatcher.normalizeTitle(
                    existing.originalTitle ?? ''),
                RecommendationOwnershipMatcher.normalizeTitle(
                    existing.canonicalTitle ?? ''),
              }..remove('');
              return existingTitles.contains(identity);
            });
            if (!duplicate &&
                tmdbMedia.isAccessibleTo(profile) &&
                TvProgrammingService.eligibleForProfile(tmdbMedia, profile)) {
              remoteMedia.add(tmdbMedia);
            }
          }
        }
      } catch (_) {
        // TMDB is optional; local and backend catalog results remain available.
      }

      // Search a few related franchise terms so a Spider-Man query can also
      // return Avengers/Captain America crossovers and similar identities.
      try {
        final relatedMedia = await _searchRelatedTmdbMedia(query, remoteMedia);
        remoteMedia.addAll(relatedMedia);
      } catch (_) {
        // Literal TMDB results are still useful if cross-franchise lookup fails.
      }

      final relatedPeopleTerms =
          SmartSearchIntelligence.relatedPersonTerms(query);
      if (relatedPeopleTerms.isNotEmpty &&
          mounted &&
          generation == _remoteSearchGeneration &&
          controller.text.trim().toLowerCase() == query) {
        final personLookups = await Future.wait(
          relatedPeopleTerms.map(_searchTmdbPeople),
        );
        for (final personGroup in personLookups) {
          remotePeople.addAll(personGroup);
        }
      }
    }

    try {
      // The people index may match aliases and career metadata.
      final people = await app.backendApi.searchMediaPeople(query: query);
      remotePeople.addAll(people);
    } catch (_) {
      // Search still works from the local library if the people service is offline.
    }

    // Character credits are global catalog metadata. Avoid querying that index
    // for child profiles; they can still browse explicit character data from
    // their own permitted library.
    if (!CharacterDiscoveryIndex.isChildProfile) {
      try {
        final characters =
            await app.backendApi.searchMediaCharacters(query: query);
        for (final raw in characters) {
          final character = Map<String, dynamic>.from(raw);
          final name = (character['name'] ?? '').toString().trim();
          if (name.isEmpty) continue;
          final rawCredits = character['credits'];
          var relatedImageUrl = '';
          if (rawCredits is List) {
            for (final imageCredit in rawCredits.whereType<Map>()) {
              final work = imageCredit['work'];
              if (work is! Map) continue;
              final workRow = Map<String, dynamic>.from(work);
              final candidateImage = (workRow['posterUrl'] ??
                      workRow['poster_url'] ??
                      workRow['imageUrl'] ??
                      workRow['image_url'] ??
                      workRow['backdropUrl'] ??
                      workRow['backdrop_url'] ??
                      '')
                  .toString()
                  .trim();
              if (candidateImage.startsWith('http')) {
                relatedImageUrl = candidateImage;
                break;
              }
            }
          }
          remoteCharacters.add(<String, dynamic>{
            ...character,
            'category': 'Fictional character',
            'source': 'media-intelligence-character',
            if ((character['imageUrl'] ?? character['image_url'] ?? '')
                    .toString()
                    .trim()
                    .isEmpty &&
                relatedImageUrl.isNotEmpty)
              'imageUrl': relatedImageUrl,
          });
          if (rawCredits is! List) continue;
          for (final rawCredit in rawCredits.whereType<Map>()) {
            final creditRow = Map<String, dynamic>.from(rawCredit);
            final person = creditRow['person'];
            final credit = creditRow['credit'];
            if (person is! Map) continue;
            final personRow = Map<String, dynamic>.from(person);
            final personName = (personRow['name'] ?? '').toString().trim();
            if (personName.isEmpty) continue;
            final creditRowMap = credit is Map
                ? Map<String, dynamic>.from(credit)
                : <String, dynamic>{};
            remotePeople.add(<String, dynamic>{
              ...personRow,
              'category': (creditRowMap['category'] ?? 'Actor').toString(),
              'knownFor': 'As ${creditRowMap['characterName'] ?? name}',
              'characterName': creditRowMap['characterName'] ?? name,
              'source': 'media-intelligence-character-credit',
            });
          }
        }
      } catch (_) {
        // Character search is optional; local character metadata still works.
      }
    }
    // Add curated fictional-identity cards even when the media-intelligence
    // graph does not yet have cast/character credits imported. These cards do
    // not create performer credits; those remain sourced from actual records.
    if (!CharacterDiscoveryIndex.isChildProfile) {
      final characterNames =
          SmartSearchIntelligence.relatedCharacterTerms(query);
      final franchiseTerms = <String>{
        ...SmartSearchIntelligence.relatedTerms(query)
            .map(SmartSearchIntelligence.compact)
            .where((term) => term.length >= 4),
        if (characterNames.contains('Peter Parker')) 'spiderman',
      }.toList(growable: false);
      final allMedia = <MediaItem>[...app.library, ...remoteMedia];
      final relevantMedia = allMedia.where((media) {
        final titleKey = SmartSearchIntelligence.compact(
          '${media.title} ${media.originalTitle ?? ''} ${media.canonicalTitle ?? ''} ${media.franchiseName ?? ''}',
        );
        return franchiseTerms.any((term) => titleKey.contains(term));
      }).toList(growable: false);
      for (final name in characterNames) {
        if (remoteCharacters.any((row) =>
            SmartSearchIntelligence.compact((row['name'] ?? '').toString()) ==
            SmartSearchIntelligence.compact(name))) {
          continue;
        }
        final imageUrl = _characterImageUrl(name, relevantMedia);
        remoteCharacters.add(<String, dynamic>{
          'id': 'curated-character:${SmartSearchIntelligence.compact(name)}',
          'name': name,
          'category': 'Fictional character',
          'source': 'curated-character-query',
          if (imageUrl != null) 'imageUrl': imageUrl,
        });
      }
    }

    // Music providers are part of universal search, not a separate destination.
    // External records remain catalog-only and never receive an invented audio URL.
    try {
      final catalogPayload = await app.backendApi
          .searchMusicCatalog(query, type: 'all', limit: 10);
      final spotify = catalogPayload['spotify'] is Map
          ? Map<String, dynamic>.from(catalogPayload['spotify'] as Map)
          : <String, dynamic>{};
      final musicBrainz = catalogPayload['musicBrainz'] is Map
          ? Map<String, dynamic>.from(catalogPayload['musicBrainz'] as Map)
          : <String, dynamic>{};

      void addMusicRow(Map<String, dynamic> row,
          {required String provider, required String entity}) {
        final title = (row['title'] ?? row['name'] ?? '').toString().trim();
        final rawId = (row['id'] ?? '').toString().trim();
        if (title.isEmpty || rawId.isEmpty) return;
        final artist = (row['artist'] ?? row['artists'] ?? 'Unknown artist')
            .toString()
            .trim();
        final source = (row['source'] ?? provider).toString();
        final id = 'catalog:${provider.toLowerCase()}:$rawId';
        final fallbackUrl = provider.toLowerCase() == 'musicbrainz'
            ? 'https://musicbrainz.org/${entity == 'recording' ? 'recording' : entity == 'artist' ? 'artist' : 'release-group'}/$rawId'
            : '';
        if (entity == 'track' || entity == 'recording') {
          final duration =
              row['durationMs'] ?? row['lengthMs'] ?? row['duration_ms'];
          remoteMusic.add(MusicTrack(
            id: id,
            title: title,
            artist: artist.isEmpty ? 'Unknown artist' : artist,
            album: (row['album'] ?? '').toString(),
            artworkUrl: (row['imageUrl'] ?? row['coverArtUrl'])?.toString(),
            duration: Duration(
                milliseconds: duration is num
                    ? duration.toInt().clamp(0, 86400000).toInt()
                    : 0),
            explicit: row['explicit'] == true,
            providerUrl: (row['providerUrl'] ?? row['spotifyUrl'])
                        ?.toString()
                        .trim()
                        .isNotEmpty ==
                    true
                ? (row['providerUrl'] ?? row['spotifyUrl']).toString()
                : fallbackUrl,
            providerName: source,
            providerId: rawId,
            catalogOnly: true,
          ));
        } else if (entity == 'album' || entity == 'release-group') {
          remoteAlbums.add(<String, dynamic>{
            'id': 'catalog-album:${provider.toLowerCase()}:$rawId',
            'title': title,
            'artist': artist,
            'imageUrl':
                (row['imageUrl'] ?? row['coverArtUrl'] ?? '').toString(),
            'providerUrl': (row['spotifyUrl'] ?? row['providerUrl'])
                        ?.toString()
                        .trim()
                        .isNotEmpty ==
                    true
                ? (row['spotifyUrl'] ?? row['providerUrl']).toString()
                : fallbackUrl,
            'providerName': source,
            'providerId': rawId,
            'albumType': row['albumType'] ?? row['primaryType'] ?? 'Album',
            'releaseDate': row['releaseDate'] ?? row['firstReleaseDate'] ?? '',
            'trackCount': row['totalTracks'],
            'source': source,
            'isOwned': false,
          });
        } else if (entity == 'artist') {
          remotePeople.add(<String, dynamic>{
            'id': 'catalog-artist:${provider.toLowerCase()}:$rawId',
            'name': title,
            'category': 'Artist / band',
            'knownFor': (row['genres'] is List
                    ? (row['genres'] as List).join(' · ')
                    : row['artistType'] ?? 'Music artist')
                .toString(),
            'photoUrl': (row['imageUrl'] ?? '').toString(),
            'providerUrl': (row['spotifyUrl'] ?? row['providerUrl'])
                        ?.toString()
                        .trim()
                        .isNotEmpty ==
                    true
                ? (row['spotifyUrl'] ?? row['providerUrl']).toString()
                : fallbackUrl,
            'providerName': source,
            'providerId': rawId,
            'source': source,
          });
        }
      }

      for (final row in _maps(spotify['tracks'])) {
        addMusicRow(row, provider: 'Spotify', entity: 'track');
      }
      for (final row in _maps(musicBrainz['recordings'])) {
        addMusicRow(row, provider: 'MusicBrainz', entity: 'recording');
      }
      for (final row in _maps(spotify['albums'])) {
        addMusicRow(row, provider: 'Spotify', entity: 'album');
      }
      for (final row in _maps(musicBrainz['releaseGroups'])) {
        addMusicRow(row, provider: 'MusicBrainz', entity: 'release-group');
      }
      for (final row in _maps(spotify['artists'])) {
        addMusicRow(row, provider: 'Spotify', entity: 'artist');
      }
      for (final row in _maps(musicBrainz['artists'])) {
        addMusicRow(row, provider: 'MusicBrainz', entity: 'artist');
      }

      // The licensed lyrics endpoint returns track metadata and provider links only;
      // it does not copy full copyrighted lyrics into the app.
      final words = query
          .trim()
          .split(RegExp(r'\s+'))
          .where((word) => word.isNotEmpty)
          .length;
      if (query.trim().length >= 12 && words >= 3) {
        try {
          final lyricsPayload = await app.backendApi.searchMusicByLyrics(query);
          for (final row in _maps(lyricsPayload['items'])) {
            final id = (row['id'] ?? '').toString().trim();
            final title = (row['title'] ?? '').toString().trim();
            if (id.isEmpty || title.isEmpty) continue;
            remoteMusic.add(MusicTrack(
              id: 'catalog:musixmatch:$id',
              title: title,
              artist: (row['artist'] ?? 'Unknown artist').toString(),
              album: (row['album'] ?? '').toString(),
              explicit: row['explicit'] == true,
              providerUrl: row['providerUrl']?.toString(),
              providerName: 'Musixmatch',
              providerId: id,
              catalogOnly: true,
            ));
          }
        } catch (_) {
          // Lyric search is optional and depends on the licensed backend key.
        }
      }

      // A movie/show query can discover its soundtrack only when a catalog album
      // explicitly identifies itself as a soundtrack/score and names that title.
      // This deliberately avoids hard-coded or guessed song-to-film associations.
      final mediaKey = _compactMusicText(query);
      final soundtrackCandidates = <MediaItem>{
        ...app.library,
        ...app.recommendations,
        ...remoteMedia,
      }.where((media) {
        final title = media.title.trim();
        final compactTitle = _compactMusicText(title);
        return title.length > 3 &&
            mediaKey.length >= 4 &&
            (compactTitle.contains(mediaKey) ||
                mediaKey.contains(compactTitle));
      }).toList()
        ..sort((a, b) {
          final aStarts =
              _compactMusicText(a.title).startsWith(mediaKey) ? 0 : 1;
          final bStarts =
              _compactMusicText(b.title).startsWith(mediaKey) ? 0 : 1;
          return aStarts.compareTo(bStarts);
        });
      var soundtrackLookups = 0;
      for (final media in soundtrackCandidates.take(2)) {
        if (soundtrackLookups >= 2) break;
        try {
          final soundtrackPayload = await app.backendApi.searchMusicCatalog(
            '${media.title} soundtrack',
            type: 'album',
            limit: 10,
          );
          final soundtrackSpotify = soundtrackPayload['spotify'] is Map
              ? Map<String, dynamic>.from(soundtrackPayload['spotify'] as Map)
              : <String, dynamic>{};
          final candidates = _maps(soundtrackSpotify['albums']).where((album) {
            final title = (album['title'] ?? '').toString().toLowerCase();
            final compactAlbum = _compactMusicText(title);
            final compactMedia = _compactMusicText(media.title);
            final hasCue = title.contains('soundtrack') ||
                title.contains('motion picture') ||
                title.contains('original score') ||
                title.contains('music from') ||
                title.contains('ost') ||
                title.contains('film score');
            return hasCue &&
                compactMedia.length >= 4 &&
                compactAlbum.contains(compactMedia);
          }).toList();
          for (final album in candidates.take(1)) {
            final spotifyId = (album['id'] ?? '').toString().trim();
            if (spotifyId.isEmpty) continue;
            final details = await app.backendApi.getSpotifyAlbum(spotifyId);
            final trackRows = _maps(details['tracks']);
            for (final row in trackRows) {
              final id = (row['id'] ?? '').toString().trim();
              final title = (row['title'] ?? '').toString().trim();
              if (id.isEmpty || title.isEmpty) continue;
              final existingIndex = remoteMusic.indexWhere((track) =>
                  _compactMusicText(track.title) == _compactMusicText(title) &&
                  _compactMusicText(track.artist) ==
                      _compactMusicText((row['artist'] ?? '').toString()));
              final soundtrackTrack = MusicTrack(
                id: 'catalog:spotify:$id',
                title: title,
                artist: (row['artist'] ?? album['artist'] ?? 'Unknown artist')
                    .toString(),
                album:
                    (row['album'] ?? album['title'] ?? details['title'] ?? '')
                        .toString(),
                artworkUrl:
                    (row['imageUrl'] ?? album['imageUrl'] ?? '').toString(),
                duration: Duration(
                    milliseconds: (row['durationMs'] as num?)?.toInt() ?? 0),
                explicit: row['explicit'] == true,
                soundtrackForTitles: <String>[media.title],
                providerUrl: row['spotifyUrl']?.toString(),
                providerName: 'Spotify',
                providerId: id,
                catalogOnly: true,
              );
              if (existingIndex >= 0) {
                final existing = remoteMusic[existingIndex];
                remoteMusic[existingIndex] = MusicTrack(
                  id: existing.id,
                  title: existing.title,
                  artist: existing.artist,
                  album: existing.album.isEmpty
                      ? soundtrackTrack.album
                      : existing.album,
                  artworkUrl: existing.artworkUrl ?? soundtrackTrack.artworkUrl,
                  duration: existing.duration,
                  genres: existing.genres,
                  featuredArtists: existing.featuredArtists,
                  subgenres: existing.subgenres,
                  explicit: existing.explicit || soundtrackTrack.explicit,
                  matureTheme: existing.matureTheme,
                  lyrics: existing.lyrics,
                  soundtrackForTitles: <String>{
                    ...existing.soundtrackForTitles,
                    media.title
                  }.toList(),
                  relatedMediaTitles: existing.relatedMediaTitles,
                  credits: existing.credits,
                  soundtrackSourceName: existing.soundtrackSourceName ??
                      soundtrackTrack.soundtrackSourceName,
                  soundtrackSourceUrl: existing.soundtrackSourceUrl ??
                      soundtrackTrack.soundtrackSourceUrl,
                  providerUrl:
                      existing.providerUrl ?? soundtrackTrack.providerUrl,
                  providerName:
                      existing.providerName ?? soundtrackTrack.providerName,
                  providerId: existing.providerId ?? soundtrackTrack.providerId,
                  catalogOnly: true,
                );
              } else {
                remoteMusic.add(soundtrackTrack);
              }
            }
            remoteAlbums.add(<String, dynamic>{
              'id': 'catalog-album:spotify:$spotifyId',
              'title': album['title'] ?? media.title,
              'artist': album['artist'] ?? '',
              'imageUrl': album['imageUrl'] ?? '',
              'providerUrl': album['spotifyUrl'] ?? '',
              'providerName': 'Spotify',
              'providerId': spotifyId,
              'albumType': album['albumType'] ?? 'Soundtrack',
              'releaseDate': album['releaseDate'] ?? '',
              'trackCount': album['totalTracks'] ?? trackRows.length,
              'source': 'Spotify soundtrack catalog',
              'soundtrackForTitle': media.title,
              'isOwned': false,
            });
            soundtrackLookups++;
          }
        } catch (_) {
          // Soundtrack discovery is opportunistic; ordinary results remain usable.
        }
      }
      try {
        await MusicLibraryStore.instance.cacheCatalogTracks(remoteMusic);
      } catch (_) {
        // Search results remain usable for this session if cache persistence fails.
      }
    } catch (_) {
      // The authenticated music catalog is optional; keep local results available.
    }

    try {
      // Social search is limited to the current profile's authorized home feed.
      // It never searches arbitrary private accounts or private community content.
      final home = await app.backendApi.getSocialHome(profileId: profile.id);
      final showAllFriends = query == 'friends' || query == 'friend';
      final showAllCommunities = query == 'communities' || query == 'community';
      final showAllPosts = query == 'posts' || query == 'post';
      for (final key in <String>['friends', 'communities', 'posts']) {
        for (final item in _maps(home[key])) {
          final haystack = _mapText(item, <String>[
            'name',
            'display_name',
            'displayName',
            'username',
            'description',
            'body',
            'text',
            'title',
            'content',
            'message',
          ]).toLowerCase();
          final categoryBrowse = key == 'friends' && showAllFriends ||
              key == 'communities' && showAllCommunities ||
              key == 'posts' && showAllPosts;
          if (!categoryBrowse && !haystack.contains(query)) continue;
          remoteSocial.add(<String, dynamic>{
            'kind': key == 'friends'
                ? 'friend'
                : key == 'communities'
                    ? 'community'
                    : 'post',
            'data': item,
          });
        }
      }
    } catch (_) {
      // Social access may be unavailable for an offline or limited session.
    }

    if (!mounted ||
        generation != _remoteSearchGeneration ||
        controller.text.trim().toLowerCase() != query) {
      return;
    }

    final mergedMedia = SmartSearch.search(
      query,
      <MediaItem>[...app.library, ...remoteMedia],
    );
    final mergedCharacters = <String, Map<String, dynamic>>{};
    for (final character in <Map<String, dynamic>>[
      ...characterResults,
      ...remoteCharacters,
    ]) {
      final name = (character['name'] ?? character['displayName'] ?? '')
          .toString()
          .trim();
      if (name.isEmpty) continue;
      final key = SmartSearchIntelligence.compact(name);
      final localImage = _characterImageUrl(
        name,
        CharacterDiscoveryIndex.titlesForCharacter(name, app.library),
      );
      final candidate = <String, dynamic>{
        ...character,
        if (localImage != null &&
            (character['imageUrl'] ?? character['image_url'] ?? '')
                .toString()
                .trim()
                .isEmpty)
          'imageUrl': localImage,
      };
      final existing = mergedCharacters[key];
      if (existing == null) {
        mergedCharacters[key] = candidate;
      } else {
        for (final entry in candidate.entries) {
          final current = existing[entry.key];
          if ((current == null || current.toString().trim().isEmpty) &&
              entry.value != null &&
              entry.value.toString().trim().isNotEmpty) {
            existing[entry.key] = entry.value;
          }
        }
      }
    }

    final mergedPeople = <String, Map<String, dynamic>>{};
    for (final person in <Map<String, dynamic>>[
      ...peopleResults,
      ...remotePeople
    ]) {
      final name = _mapText(person, <String>[
        'name',
        'displayName',
        'display_name',
        'fullName',
        'full_name'
      ]).trim();
      if (name.isEmpty) continue;
      final categoryKey =
          _mapText(person, <String>['category', 'profession', 'role', 'type'])
              .toLowerCase();
      final categoryBucket = categoryKey.contains('artist') ||
              categoryKey.contains('band') ||
              categoryKey.contains('singer') ||
              categoryKey.contains('musician')
          ? 'artist'
          : categoryKey.contains('actor') ||
                  categoryKey.contains('actress') ||
                  categoryKey.contains('acting') ||
                  categoryKey.contains('performer')
              ? 'actor'
              : categoryKey;
      final key = '${name.toLowerCase()}|$categoryBucket';
      final existing = mergedPeople[key];
      if (existing == null) {
        mergedPeople[key] = Map<String, dynamic>.from(person);
      } else {
        for (final entry in person.entries) {
          final current = existing[entry.key];
          if ((current == null || current.toString().trim().isEmpty) &&
              entry.value != null &&
              entry.value.toString().trim().isNotEmpty) {
            existing[entry.key] = entry.value;
          }
        }
        // Prefer an indexed character-role credit over TMDB's generic known-for
        // titles, while retaining the TMDB headshot and biography identifiers.
        if (person['source'] == 'media-intelligence-character-credit') {
          final creditedRole = (person['knownFor'] ?? '').toString().trim();
          if (creditedRole.isNotEmpty) {
            existing['knownFor'] = creditedRole;
            if (person['characterName'] != null) {
              existing['characterName'] = person['characterName'];
            }
          }
        }
      }
    }
    final mergedEpisodeResults = SmartSearchIntelligence.themedEpisodes(
      query,
      <MediaItem>[...app.library, ...remoteMedia],
    );
    final mergedMusicByKey = <String, MusicTrack>{};
    final activeProfile = app.currentProfile;
    for (final candidate in <MusicTrack>[...musicResults, ...remoteMusic]) {
      if (profileBlocksExplicitMusic(activeProfile) && candidate.explicit) {
        continue;
      }
      if (profileBlocksMatureMusic(activeProfile) && candidate.matureTheme) {
        continue;
      }
      final key =
          '${_compactMusicText(candidate.title)}|${_compactMusicText(candidate.artist)}';
      if (key == '|') continue;
      final existing = mergedMusicByKey[key];
      if (existing == null) {
        mergedMusicByKey[key] = candidate;
        continue;
      }
      final candidateHasDirectProvider =
          candidate.providerUrl?.isNotEmpty == true &&
              candidate.providerName != 'Spotify search';
      final existingHasDirectProvider =
          existing.providerUrl?.isNotEmpty == true &&
              existing.providerName != 'Spotify search';
      final preferCandidate =
          (existing.catalogOnly && !candidate.catalogOnly) ||
              (!existingHasDirectProvider && candidateHasDirectProvider) ||
              (existing.soundtrackForTitles.isEmpty &&
                  candidate.soundtrackForTitles.isNotEmpty);
      final primary = preferCandidate ? candidate : existing;
      final secondary = preferCandidate ? existing : candidate;
      mergedMusicByKey[key] = MusicTrack(
        id: primary.id,
        title: primary.title,
        artist: primary.artist,
        album:
            primary.album.trim().isNotEmpty ? primary.album : secondary.album,
        artworkUrl: primary.artworkUrl ?? secondary.artworkUrl,
        audioUrl: primary.audioUrl,
        musicVideoUrl: primary.musicVideoUrl ?? secondary.musicVideoUrl,
        duration: primary.duration > Duration.zero
            ? primary.duration
            : secondary.duration,
        genres: <String>{...primary.genres, ...secondary.genres}.toList(),
        featuredArtists: <String>{
          ...primary.featuredArtists,
          ...secondary.featuredArtists
        }.toList(),
        subgenres:
            <String>{...primary.subgenres, ...secondary.subgenres}.toList(),
        explicit: primary.explicit || secondary.explicit,
        matureTheme: primary.matureTheme || secondary.matureTheme,
        lyrics: primary.lyrics.isNotEmpty ? primary.lyrics : secondary.lyrics,
        soundtrackForTitles: <String>{
          ...primary.soundtrackForTitles,
          ...secondary.soundtrackForTitles
        }.toList(),
        relatedMediaTitles: <String>{
          ...primary.relatedMediaTitles,
          ...secondary.relatedMediaTitles
        }.toList(),
        credits: <String>{...primary.credits, ...secondary.credits}.toList(),
        soundtrackSourceName:
            primary.soundtrackSourceName ?? secondary.soundtrackSourceName,
        soundtrackSourceUrl:
            primary.soundtrackSourceUrl ?? secondary.soundtrackSourceUrl,
        providerUrl: (primary.providerName != null &&
                primary.providerName!.isNotEmpty &&
                primary.providerName != 'Spotify search')
            ? primary.providerUrl ?? secondary.providerUrl
            : secondary.providerUrl ?? primary.providerUrl,
        providerName: (primary.providerName != null &&
                primary.providerName!.isNotEmpty &&
                primary.providerName != 'Spotify search')
            ? primary.providerName ?? secondary.providerName
            : secondary.providerName ?? primary.providerName,
        providerId: (primary.providerName != null &&
                primary.providerName!.isNotEmpty &&
                primary.providerName != 'Spotify search')
            ? primary.providerId ?? secondary.providerId
            : secondary.providerId ?? primary.providerId,
        catalogOnly: primary.catalogOnly && secondary.catalogOnly,
        modifiedAt: primary.modifiedAt ?? secondary.modifiedAt,
        addedByProfileId:
            primary.addedByProfileId ?? secondary.addedByProfileId,
        addedByProfileName:
            primary.addedByProfileName ?? secondary.addedByProfileName,
        addedSource:
            primary.catalogOnly ? secondary.addedSource : primary.addedSource,
      );
    }
    final mergedAlbumsByKey = <String, Map<String, dynamic>>{};
    for (final album in <Map<String, dynamic>>[
      ...albumResults,
      ...remoteAlbums
    ]) {
      final title = (album['title'] ?? '').toString();
      final artist = (album['artist'] ?? '').toString();
      if (title.trim().isEmpty) continue;
      final key = '${_compactMusicText(title)}|${_compactMusicText(artist)}';
      mergedAlbumsByKey.putIfAbsent(key, () => album);
    }
    final mergedPeopleWithMusic = <String, Map<String, dynamic>>{};
    for (final person in mergedPeople.values) {
      final nameKey = _compactMusicText((person['name'] ?? '').toString());
      final categoryKey =
          _mapText(person, <String>['category', 'profession', 'role', 'type'])
              .toLowerCase();
      final categoryBucket = categoryKey.contains('artist') ||
              categoryKey.contains('band') ||
              categoryKey.contains('singer') ||
              categoryKey.contains('musician')
          ? 'artist'
          : categoryKey.contains('actor') ||
                  categoryKey.contains('actress') ||
                  categoryKey.contains('acting') ||
                  categoryKey.contains('performer')
              ? 'actor'
              : categoryKey;
      final key = '$nameKey|$categoryBucket';
      if (nameKey.isNotEmpty) mergedPeopleWithMusic[key] = person;
    }
    setState(() {
      results = mergedMedia;
      musicResults = mergedMusicByKey.values.take(80).toList(growable: false);
      albumResults = mergedAlbumsByKey.values.take(24).toList(growable: false);
      characterResults =
          mergedCharacters.values.take(24).toList(growable: false);
      peopleResults =
          mergedPeopleWithMusic.values.take(50).toList(growable: false);
      episodeResults = mergedEpisodeResults;
      socialResults = remoteSocial.take(30).toList(growable: false);
      remoteSearchLoading = false;
    });
  }

  Future<void> _openPerson(Map<String, dynamic> person) async {
    final name = _mapText(person, <String>[
      'name',
      'displayName',
      'display_name',
      'fullName',
      'full_name'
    ]).trim();
    if (name.isEmpty) return;
    final category = _mapText(person, <String>[
      'category',
      'profession',
      'role',
      'type',
      'knownFor',
      'known_for',
    ]).toLowerCase();
    if (category.contains('artist') ||
        category.contains('band') ||
        category.contains('singer') ||
        category.contains('musician')) {
      if (!mounted) return;
      Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => MusicArtistProfileScreen(artistName: name),
          ));
      return;
    }

    final enriched = Map<String, dynamic>.from(person);
    final tmdbId = (person['tmdbId'] ?? '').toString().trim();
    if (tmdbId.isNotEmpty &&
        AppController.instance.backendApi.isAuthenticated) {
      try {
        final details = await AppController.instance.backendApi.getTmdbMetadata(
          '/person/$tmdbId',
          const <String, String>{'language': 'en-US'},
        );
        enriched.addAll(details);
        final profilePhoto =
            _tmdbImageUrl(details['profile_path'], size: 'w500');
        if (profilePhoto != null) enriched['photoUrl'] = profilePhoto;
      } catch (_) {
        // The TMDB search result itself is enough to open a lightweight profile.
      }
    }
    if (!mounted) return;
    final birthDate = (enriched['birthday'] ??
            enriched['dateOfBirth'] ??
            enriched['date_of_birth'] ??
            '')
        .toString();
    final photo = (enriched['photoUrl'] ??
            enriched['photo_url'] ??
            enriched['imageUrl'] ??
            enriched['image_url'] ??
            '')
        .toString();
    Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ActorDetailsScreen(
              actor: Actor(
            id: (enriched['tmdbId'] ??
                    enriched['id'] ??
                    enriched['personId'] ??
                    enriched['person_id'] ??
                    name)
                .toString(),
            name: name,
            photoUrl: photo,
            biography:
                (enriched['biography'] ?? enriched['bio'] ?? '').toString(),
            placeOfBirth:
                (enriched['place_of_birth'] ?? enriched['placeOfBirth'] ?? '')
                    .toString(),
            dateOfBirth: DateTime.tryParse(birthDate),
            knownFor: (person['knownFor'] ??
                    person['known_for'] ??
                    enriched['known_for_department'] ??
                    enriched['profession'] ??
                    enriched['category'] ??
                    'Entertainment')
                .toString(),
          )),
        ));
  }

  void _openSocialResult(Map<String, dynamic> result) {
    final kind = result['kind']?.toString() ?? '';
    final data = result['data'] is Map
        ? Map<String, dynamic>.from(result['data'] as Map)
        : <String, dynamic>{};
    if (kind == 'community') {
      Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => SocialCommunityDetailScreen(community: data),
          ));
    } else if (kind == 'post') {
      final id =
          (data['id'] ?? data['postId'] ?? data['post_id'] ?? '').toString();
      if (id.isEmpty) {
        return;
      }
      Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) =>
                SocialPostDetailScreen(postId: id, initialPost: data),
          ));
    } else if (kind == 'friend') {
      final accountId =
          (data['id'] ?? data['accountId'] ?? data['account_id'] ?? '')
              .toString();
      final profileId =
          (data['profileId'] ?? data['profile_id'] ?? '').toString();
      if (accountId.isEmpty || profileId.isEmpty) {
        return;
      }
      Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => SocialProfileDetailScreen(
              targetAccountId: accountId,
              targetProfileId: profileId,
              initialProfile: data,
            ),
          ));
    }
  }

  /// Performs `clearSearch` for this feature. Update this documentation when its contract changes.
  void clearSearch() {
    controller.clear();
    _searchDebounce?.cancel();
    _remoteSearchGeneration++;
    setState(() {
      results = <MediaItem>[];
      musicResults = <MusicTrack>[];
      albumResults = <Map<String, dynamic>>[];
      productResults = <ShopProduct>[];
      peopleResults = <Map<String, dynamic>>[];
      characterResults = <Map<String, dynamic>>[];
      episodeResults = <SmartSearchEpisodeHit>[];
      socialResults = <Map<String, dynamic>>[];
      remoteSearchLoading = false;
    });
    searchFocusNode.requestFocus();
  }

  /// Performs `useSuggestion` for this feature. Update this documentation when its contract changes.
  void useSuggestion(String suggestion) {
    controller.text = suggestion;

    controller.selection = TextSelection.fromPosition(
      TextPosition(
        offset: controller.text.length,
      ),
    );

    performSearch(suggestion);
  }

  /// Performs `_typeLabel` for this feature. Update this documentation when its contract changes.
  String _typeLabel(MediaItem media) {
    final type = media.type.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
    return switch (type) {
      'movie' || 'film' || 'featurefilm' => 'MOVIE',
      'tvshow' || 'series' || 'show' || 'television' => 'TV SERIES',
      'season' || 'tvseason' => 'TV SEASON',
      'episode' || 'tvepisode' => 'TV EPISODE',
      'song' || 'track' => 'SONG',
      'album' => 'ALBUM',
      'artist' => 'ARTIST',
      'musicvideo' => 'MUSIC VIDEO',
      'special' || 'tvspecial' => 'SPECIAL',
      'documentary' => 'DOCUMENTARY',
      'concert' || 'liveevent' => 'LIVE EVENT',
      'channel' || 'livetv' => 'CHANNEL',
      'trailer' => 'TRAILER',
      'short' || 'clip' => 'SHORT',
      _ =>
        media.type.trim().isEmpty ? 'MEDIA' : media.type.trim().toUpperCase(),
    };
  }

  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Stack(
        children: [
          const _SearchBackground(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 900;

                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop ? 1100 : 700,
                    ),
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: _buildHeader(theme),
                        ),
                        SliverToBoxAdapter(
                          child: _buildSearchBar(theme),
                        ),
                        SliverToBoxAdapter(
                          child: _buildResultsHeader(),
                        ),
                        _buildResultsList(isDesktop),
                        const SliverPadding(
                          padding: EdgeInsets.only(bottom: 50),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Performs `_buildHeader` for this feature. Update this documentation when its contract changes.
  Widget _buildHeader(ThemeData theme) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animationController,
        curve: Curves.easeOut,
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.08),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: animationController,
            curve: Curves.easeOutCubic,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            22,
            24,
            22,
            18,
          ),
          child: Row(
            children: [
              _GlassIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UniversalText(
                      'Smart Search',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 3),
                    UniversalText(
                      'Search titles, people, characters, or describe a plot or scene',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.52),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Performs `_buildSearchBar` for this feature. Update this documentation when its contract changes.
  Widget _buildSearchBar(ThemeData theme) {
    final focused = searchFocusNode.hasFocus;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 18,
            sigmaY: 18,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.075),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: focused
                    ? Colors.white.withValues(alpha: 0.28)
                    : Colors.white.withValues(alpha: 0.11),
              ),
            ),
            child: TextField(
              controller: controller,
              focusNode: searchFocusNode,
              autofocus: true,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              cursorColor: Colors.white,
              textInputAction: TextInputAction.search,
              onChanged: performSearch,
              onSubmitted: performSearch,
              decoration: InputDecoration(
                hintText: tr(
                  'Try a title, actor, character, or describe a scene…',
                ),
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.38),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Colors.white.withValues(alpha: 0.65),
                  size: 25,
                ),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        onPressed: clearSearch,
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white70,
                        ),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 19,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Performs `_buildResultsHeader` for this feature. Update this documentation when its contract changes.
  Widget _buildResultsHeader() {
    if (controller.text.trim().isEmpty) return const SizedBox.shrink();
    final count = results.length +
        musicResults.length +
        albumResults.length +
        productResults.length +
        peopleResults.length +
        characterResults.length +
        episodeResults.length +
        socialResults.length;
    final filters = const <String>[
      'All',
      'Songs',
      'Albums',
      'Artists',
      'Actors',
      'Movies',
      'Shows'
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 10),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(children: <Widget>[
              Expanded(
                  child: Text(
                remoteSearchLoading && count == 0
                    ? 'Searching…'
                    : count == 0
                        ? 'No results'
                        : '$count ${count == 1 ? 'result' : 'results'}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700),
              )),
              if (remoteSearchLoading)
                const SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(strokeWidth: 1.5))
              else if (count > 0)
                Text('CONNECTED SEARCH',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: .35),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4)),
            ]),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: <Widget>[
                for (final filter in filters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: selectedSearchCategory == filter,
                      onSelected: (_) =>
                          setState(() => selectedSearchCategory = filter),
                      selectedColor: const Color(0xFFB8FF32),
                      labelStyle: TextStyle(
                        color: selectedSearchCategory == filter
                            ? Colors.black
                            : Colors.white70,
                        fontWeight: FontWeight.w800,
                      ),
                      backgroundColor: const Color(0xFF202026),
                      side: BorderSide(
                          color: selectedSearchCategory == filter
                              ? Colors.transparent
                              : Colors.white12),
                    ),
                  ),
              ]),
            ),
          ]),
    );
  }

  /// Performs `_buildResultsList` for this feature. Update this documentation when its contract changes.
  Widget _buildResultsList(bool isDesktop) {
    if (controller.text.trim().isEmpty) {
      return SliverToBoxAdapter(
        child: SearchDiscoveryLanding(onSearch: useSuggestion),
      );
    }

    if (results.isEmpty &&
        musicResults.isEmpty &&
        albumResults.isEmpty &&
        productResults.isEmpty &&
        peopleResults.isEmpty &&
        characterResults.isEmpty &&
        episodeResults.isEmpty &&
        socialResults.isEmpty &&
        !remoteSearchLoading) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            22,
            55,
            22,
            40,
          ),
          child: _EmptySearchState(
            icon: Icons.movie_filter_outlined,
            title: tr('Nothing found'),
            message: tr(
              'Try a title, artist, actor, friend, community, post, or shop product.',
            ),
          ),
        ),
      );
    }

    final movieResults = results
        .where((media) => SmartSearch._isMovie(media.type.toLowerCase()))
        .toList(growable: false);
    final seriesResults = results
        .where((media) => SmartSearch._isTvShow(media.type.toLowerCase()))
        .toList(growable: false);
    final otherMediaResults = results
        .where((media) =>
            !SmartSearch._isMovie(media.type.toLowerCase()) &&
            !SmartSearch._isTvShow(media.type.toLowerCase()))
        .toList(growable: false);
    final filter = selectedSearchCategory;
    final showAll = filter == 'All';
    final showMovies = showAll || filter == 'Movies';
    final showShows = showAll || filter == 'Shows';
    final showSongs = showAll || filter == 'Songs';
    final showAlbums = showAll || filter == 'Albums';
    final showArtists = showAll || filter == 'Artists';
    final showActors = showAll || filter == 'Actors';
    bool isArtistPerson(Map<String, dynamic> person) {
      final category = _mapText(person, <String>[
        'category',
        'profession',
        'role',
        'type',
        'knownFor',
        'known_for'
      ]).toLowerCase();
      return category.contains('artist') ||
          category.contains('band') ||
          category.contains('singer') ||
          category.contains('musician');
    }

    bool isActorPerson(Map<String, dynamic> person) {
      final category = _mapText(person, <String>[
        'category',
        'profession',
        'role',
        'type',
        'knownFor',
        'known_for'
      ]).toLowerCase();
      return !isArtistPerson(person) &&
          (category.contains('actor') ||
              category.contains('actress') ||
              category.contains('acting') ||
              category.contains('performer') ||
              category.contains('cast'));
    }

    final artistPeople =
        peopleResults.where(isArtistPerson).toList(growable: false);
    final actorPeople =
        peopleResults.where(isActorPerson).toList(growable: false);
    final otherPeople = peopleResults
        .where((person) => !isArtistPerson(person) && !isActorPerson(person))
        .toList(growable: false);
    final hasSelectedCategoryResults = switch (filter) {
      'Songs' => musicResults.isNotEmpty,
      'Albums' => albumResults.isNotEmpty,
      'Artists' => artistPeople.isNotEmpty,
      'Actors' => actorPeople.isNotEmpty,
      'Movies' => movieResults.isNotEmpty,
      'Shows' => seriesResults.isNotEmpty || episodeResults.isNotEmpty,
      _ => true,
    };
    if (!showAll && !hasSelectedCategoryResults && !remoteSearchLoading) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 48, 22, 40),
          child: _EmptySearchState(
            icon: filter == 'Songs'
                ? Icons.music_off_rounded
                : Icons.search_off_rounded,
            title: 'No $filter found',
            message:
                'Try another spelling, or switch back to All to see related media and people.',
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          if (showMovies && movieResults.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(top: 4, bottom: 8),
              child: UniversalText('Movies',
                  style: TextStyle(
                      color: Colors.white70, fontWeight: FontWeight.w800)),
            ),
            for (var index = 0; index < movieResults.length; index++)
              _SearchResultCard(
                key: ValueKey('movie:${movieResults[index].id}'),
                media: movieResults[index],
                typeLabel: _typeLabel(movieResults[index]),
                index: index,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            MediaDetailsScreen(media: movieResults[index]))),
              ),
          ],
          if (showShows && seriesResults.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(top: 18, bottom: 8),
              child: UniversalText('Series',
                  style: TextStyle(
                      color: Colors.white70, fontWeight: FontWeight.w800)),
            ),
            for (var index = 0; index < seriesResults.length; index++)
              _SearchResultCard(
                key: ValueKey('series:${seriesResults[index].id}'),
                media: seriesResults[index],
                typeLabel: _typeLabel(seriesResults[index]),
                index: index,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            MediaDetailsScreen(media: seriesResults[index]))),
              ),
          ],
          if (showAll && otherMediaResults.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(top: 18, bottom: 8),
              child: UniversalText('Other media',
                  style: TextStyle(
                      color: Colors.white70, fontWeight: FontWeight.w800)),
            ),
            for (var index = 0; index < otherMediaResults.length; index++)
              _SearchResultCard(
                key: ValueKey('other:${otherMediaResults[index].id}'),
                media: otherMediaResults[index],
                typeLabel: _typeLabel(otherMediaResults[index]),
                index: index,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => MediaDetailsScreen(
                            media: otherMediaResults[index]))),
              ),
          ],
          if ((showAll || showShows) && episodeResults.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 9),
              child: Row(
                children: [
                  Text(episodeResults.first.theme.emoji,
                      style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${episodeResults.first.theme.label} themed episodes',
                      style: const TextStyle(
                          color: Colors.white70, fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text('${episodeResults.length}',
                      style: TextStyle(
                          color: Color(episodeResults.first.theme.colorValue),
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            for (final hit in episodeResults)
              Card(
                color: const Color(0xFF17171C),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                      color:
                          Color(hit.theme.colorValue).withValues(alpha: .55)),
                ),
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 54,
                      height: 66,
                      child: (hit.imageUrl?.startsWith('http') ?? false)
                          ? Image.network(hit.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => ColoredBox(
                                  color: Color(hit.theme.colorValue)
                                      .withValues(alpha: .14),
                                  child: Center(
                                      child: Text(hit.theme.emoji,
                                          style:
                                              const TextStyle(fontSize: 24)))))
                          : ColoredBox(
                              color: Color(hit.theme.colorValue)
                                  .withValues(alpha: .14),
                              child: Center(
                                  child: Text(hit.theme.emoji,
                                      style: const TextStyle(fontSize: 24))),
                            ),
                    ),
                  ),
                  title: Text(hit.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${hit.parent.title} · ${hit.positionLabel}${hit.description?.trim().isNotEmpty == true ? '\n${hit.description}' : ''}',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  trailing: Text(hit.theme.emoji,
                      style: const TextStyle(fontSize: 20)),
                  isThreeLine: hit.description?.trim().isNotEmpty == true,
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => MediaDetailsScreen(media: hit.parent),
                    ),
                  ),
                ),
              ),
          ],
          if ((showAll || showActors) && characterResults.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(top: 20, bottom: 8),
              child: UniversalText('Fictional characters',
                  style: TextStyle(
                      color: Colors.white70, fontWeight: FontWeight.w800)),
            ),
            for (final character in characterResults)
              Card(
                color: Colors.white.withValues(alpha: .055),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: ((character['imageUrl'] ??
                                    character['image_url'])
                                ?.toString()
                                .trim()
                                .startsWith('http') ??
                            false)
                        ? NetworkImage(
                            (character['imageUrl'] ?? character['image_url'])
                                .toString())
                        : null,
                    child: const Icon(Icons.face_retouching_natural_rounded),
                  ),
                  title: Text((character['name'] ??
                          character['displayName'] ??
                          'Character')
                      .toString()),
                  subtitle: Text(
                    '${character['category'] ?? 'Fictional character'}${character['appearanceCount'] == null ? '' : ' · ${character['appearanceCount']} indexed appearances'}',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    final name =
                        (character['name'] ?? character['displayName'] ?? '')
                            .toString()
                            .trim();
                    if (name.isEmpty) return;
                    Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              CharacterDiscoveryScreen(characterName: name),
                        ));
                  },
                ),
              ),
          ],
          if (showAlbums && albumResults.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(top: 18, bottom: 8),
              child: UniversalText('Albums',
                  style: TextStyle(
                      color: Colors.white70, fontWeight: FontWeight.w800)),
            ),
            for (final album in albumResults)
              Card(
                color: Colors.white.withValues(alpha: .055),
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: SizedBox(
                        width: 52,
                        height: 52,
                        child: ((album['imageUrl'] ?? album['artworkUrl'] ?? '')
                                .toString()
                                .startsWith('http'))
                            ? Image.network(
                                (album['imageUrl'] ?? album['artworkUrl'])
                                    .toString(),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.album_rounded))
                            : const Icon(Icons.album_rounded)),
                  ),
                  title: Text((album['title'] ?? 'Album').toString(),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                      '${album['artist'] ?? 'Unknown artist'}${(album['albumType'] ?? '').toString().trim().isEmpty ? '' : ' · ${album['albumType']}'}${album['releaseDate'] == null || album['releaseDate'].toString().isEmpty ? '' : ' · ${album['releaseDate']}'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  trailing: Icon(
                      (album['isOwned'] == true)
                          ? Icons.library_music_rounded
                          : Icons.open_in_new_rounded,
                      size: 18),
                  onTap: () async {
                    final rawTracks = album['tracks'];
                    final localTracks = rawTracks is List
                        ? rawTracks.whereType<MusicTrack>().toList()
                        : <MusicTrack>[];
                    final localRows = localTracks
                        .asMap()
                        .entries
                        .map((entry) => <String, dynamic>{
                              'title': entry.value.title,
                              'artist': entry.value.artist,
                              'durationMs': entry.value.duration.inMilliseconds,
                              'trackNumber': entry.key + 1,
                              'artworkUrl': entry.value.artworkUrl
                            })
                        .toList();
                    final provider =
                        (album['providerName'] ?? '').toString().toLowerCase();
                    final providerId =
                        (album['providerId'] ?? '').toString().trim();
                    if (provider == 'spotify' &&
                        providerId.isNotEmpty &&
                        AppController.instance.backendApi.isAuthenticated) {
                      await Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                              builder: (_) => SpotifyAlbumDetailsScreen(
                                  albumTitle:
                                      (album['title'] ?? 'Album').toString(),
                                  spotifyId: providerId,
                                  isOwned: album['isOwned'] == true,
                                  localArtistName:
                                      (album['artist'] ?? '').toString(),
                                  localTracks: localRows)));
                    } else {
                      await Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                              builder: (_) => OwnedAlbumDetailsScreen(
                                  albumTitle:
                                      (album['title'] ?? 'Album').toString(),
                                  artistName:
                                      (album['artist'] ?? '').toString(),
                                  artworkUrl:
                                      (album['imageUrl'] ?? album['artworkUrl'])
                                          ?.toString(),
                                  localTracks: localRows,
                                  isOwned: album['isOwned'] == true,
                                  resolveSpotifyMetadata: true)));
                    }
                  },
                ),
              ),
          ],
          if (showSongs && musicResults.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(top: 18, bottom: 8),
              child: UniversalText('Songs',
                  style: TextStyle(
                      color: Colors.white70, fontWeight: FontWeight.w800)),
            ),
            for (final track in musicResults)
              Card(
                color: Colors.white.withValues(alpha: .055),
                child: ListTile(
                  title: Text(track.title),
                  subtitle: Text(
                    '${musicTrackSubtitle(track, prefix: '${track.artist}${track.album.trim().isEmpty ? '' : ' · ${track.album}'}')}'
                    '${track.soundtrackForTitles.isEmpty && track.relatedMediaTitles.isEmpty ? '' : '\nSoundtrack connection · ${<String>{
                        ...track.soundtrackForTitles,
                        ...track.relatedMediaTitles
                      }.join(' · ')}'}'
                    '${track.catalogOnly ? '\nCatalog metadata · ${track.providerName ?? 'music provider'}' : ''}'
                    '${track.soundtrackSourceName == null ? '' : '\nRelationship source · ${track.soundtrackSourceName}'}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  leading: CircleAvatar(
                    backgroundImage:
                        (track.artworkUrl?.startsWith('http') ?? false)
                            ? NetworkImage(track.artworkUrl!)
                            : null,
                    child: const Icon(Icons.music_note_rounded),
                  ),
                  trailing:
                      Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                    RecommendationOwnershipBadge(
                      isOwned: !track.catalogOnly,
                      isWatched:
                          (MusicLibraryStore.instance.listenCounts[track.id] ??
                                  0) >
                              0,
                      watchedLabel: 'Listened',
                      compact: true,
                    ),
                    IconButton(
                        tooltip: 'More song options',
                        icon: const Icon(Icons.more_vert_rounded),
                        onPressed: () => showMusicTrackOptions(context, track)),
                  ]),
                  onTap: () => openMusicSearchTrack(context, track),
                ),
              ),
          ],
          if (showArtists && artistPeople.isNotEmpty) ...[
            const Padding(
                padding: EdgeInsets.only(top: 18, bottom: 8),
                child: UniversalText('Artists & bands',
                    style: TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.w800))),
            for (final person in artistPeople)
              Card(
                  color: Colors.white.withValues(alpha: .055),
                  child: ListTile(
                    leading: CircleAvatar(
                        backgroundImage: ((person['photoUrl'] ??
                                        person['photo_url'] ??
                                        person['imageUrl'] ??
                                        person['image_url'])
                                    ?.toString()
                                    .trim()
                                    .startsWith('http') ??
                                false)
                            ? NetworkImage((person['photoUrl'] ??
                                    person['photo_url'] ??
                                    person['imageUrl'] ??
                                    person['image_url'])
                                .toString())
                            : null,
                        child: const Icon(Icons.mic_external_on_rounded)),
                    title: Text(_mapText(person, <String>[
                      'name',
                      'displayName',
                      'display_name',
                      'fullName',
                      'full_name'
                    ]).trim()),
                    subtitle: Text((person['knownFor'] ??
                            person['known_for'] ??
                            person['category'] ??
                            person['providerName'] ??
                            'Music artist')
                        .toString()),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => unawaited(_openPerson(person)),
                  )),
          ],
          if (showActors && actorPeople.isNotEmpty) ...[
            const Padding(
                padding: EdgeInsets.only(top: 18, bottom: 8),
                child: UniversalText('Actors & performers',
                    style: TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.w800))),
            for (final person in actorPeople)
              Card(
                  color: Colors.white.withValues(alpha: .055),
                  child: ListTile(
                    leading: CircleAvatar(
                        backgroundImage: ((person['photoUrl'] ??
                                        person['photo_url'] ??
                                        person['imageUrl'] ??
                                        person['image_url'])
                                    ?.toString()
                                    .trim()
                                    .startsWith('http') ??
                                false)
                            ? NetworkImage((person['photoUrl'] ??
                                    person['photo_url'] ??
                                    person['imageUrl'] ??
                                    person['image_url'])
                                .toString())
                            : null,
                        child: const Icon(Icons.person_outline_rounded)),
                    title: Text(_mapText(person, <String>[
                      'name',
                      'displayName',
                      'display_name',
                      'fullName',
                      'full_name'
                    ]).trim()),
                    subtitle: Text((person['knownFor'] ??
                            person['known_for'] ??
                            person['category'] ??
                            'Entertainment')
                        .toString()),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => unawaited(_openPerson(person)),
                  )),
          ],
          if (showAll && otherPeople.isNotEmpty) ...[
            const Padding(
                padding: EdgeInsets.only(top: 18, bottom: 8),
                child: UniversalText(
                    'Directors, writers & entertainment people',
                    style: TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.w800))),
            for (final person in otherPeople)
              Card(
                  color: Colors.white.withValues(alpha: .055),
                  child: ListTile(
                    leading: CircleAvatar(
                        backgroundImage: ((person['photoUrl'] ??
                                        person['photo_url'] ??
                                        person['imageUrl'] ??
                                        person['image_url'])
                                    ?.toString()
                                    .trim()
                                    .startsWith('http') ??
                                false)
                            ? NetworkImage((person['photoUrl'] ??
                                    person['photo_url'] ??
                                    person['imageUrl'] ??
                                    person['image_url'])
                                .toString())
                            : null,
                        child: const Icon(Icons.person_outline_rounded)),
                    title: Text(_mapText(person, <String>[
                      'name',
                      'displayName',
                      'display_name',
                      'fullName',
                      'full_name'
                    ]).trim()),
                    subtitle: Text((person['knownFor'] ??
                            person['known_for'] ??
                            person['category'] ??
                            'Entertainment')
                        .toString()),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => unawaited(_openPerson(person)),
                  )),
          ],
          if (showAll && socialResults.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(top: 18, bottom: 8),
              child: UniversalText('Friends, communities & posts',
                  style: TextStyle(
                      color: Colors.white70, fontWeight: FontWeight.w800)),
            ),
            for (final result in socialResults)
              Builder(builder: (context) {
                final data = result['data'] is Map
                    ? Map<String, dynamic>.from(result['data'] as Map)
                    : <String, dynamic>{};
                final kind = result['kind']?.toString() ?? 'social';
                final title = _mapText(data, <String>[
                  'name',
                  'display_name',
                  'displayName',
                  'username',
                  'title',
                  'body',
                  'text',
                  'content'
                ]).trim();
                final subtitle = switch (kind) {
                  'community' =>
                    'Community · ${data['memberCount'] ?? data['member_count'] ?? ''} members',
                  'post' => 'Community or friend post',
                  _ => 'Friend',
                };
                return Card(
                  color: Colors.white.withValues(alpha: .055),
                  child: ListTile(
                    leading: CircleAvatar(
                        child: Icon(kind == 'community'
                            ? Icons.groups_2_outlined
                            : kind == 'post'
                                ? Icons.forum_outlined
                                : Icons.person_outline_rounded)),
                    title: Text(title.isEmpty ? 'Untitled $kind' : title,
                        maxLines: kind == 'post' ? 2 : 1,
                        overflow: TextOverflow.ellipsis),
                    subtitle: Text(subtitle),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _openSocialResult(result),
                  ),
                );
              }),
          ],
          if (showAll && productResults.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(top: 18, bottom: 8),
              child: UniversalText('Shop & merchandise',
                  style: TextStyle(
                      color: Colors.white70, fontWeight: FontWeight.w800)),
            ),
            for (final product in productResults)
              Card(
                color: Colors.white.withValues(alpha: .055),
                child: ListTile(
                  leading: const CircleAvatar(
                      child: Icon(Icons.shopping_bag_outlined)),
                  title: Text(product.name),
                  subtitle: Text(
                      '${product.category} · ${product.price.toStringAsFixed(2)} ${product.currency}'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            ShopProductDetailsScreen(product: product),
                      )),
                ),
              ),
          ],
          if (remoteSearchLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ]),
      ),
    );
  }
}

class _SearchResultCard extends StatefulWidget {
  final MediaItem media;
  final String typeLabel;
  final int index;
  final VoidCallback onTap;

  const _SearchResultCard({
    super.key,
    required this.media,
    required this.typeLabel,
    required this.index,
    required this.onTap,
  });

  @override
  State<_SearchResultCard> createState() => _SearchResultCardState();
}

class _SearchResultCardState extends State<_SearchResultCard> {
  bool hovering = false;

  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    final media = widget.media;
    final identityHint = _identityHint(media);
    final app = AppController.instance;
    final ownedRecord = RecommendationOwnershipMatcher.findOwnedMediaForMedia(
      media: media,
      controller: app,
    );
    final isOwned = ownedRecord != null;
    final isWatched = ownedRecord != null &&
        (app.isWatched(ownedRecord.id) ||
            app.getPlaybackProgress(ownedRecord.id) >= 0.95);
    final typeKey = media.type.toLowerCase();
    final watchedLabel = typeKey.contains('song') ||
            typeKey.contains('track') ||
            typeKey.contains('album')
        ? 'Listened'
        : 'Watched';

    return TweenAnimationBuilder<double>(
      duration: Duration(
        milliseconds: 350 + (widget.index * 55),
      ),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      builder: (
        context,
        value,
        child,
      ) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(
              0,
              20 * (1 - value),
            ),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 13),
        child: MouseRegion(
          onEnter: (_) {
            setState(() {
              hovering = true;
            });
          },
          onExit: (_) {
            setState(() {
              hovering = false;
            });
          },
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              transform: Matrix4.identity()
                ..translateByDouble(
                  hovering ? 3.0 : 0.0,
                  hovering ? -1.0 : 0.0,
                  0.0,
                  1.0,
                ),
              decoration: BoxDecoration(
                color: hovering
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.white.withValues(alpha: 0.055),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: hovering
                      ? Colors.white.withValues(alpha: 0.20)
                      : Colors.white.withValues(alpha: 0.075),
                ),
                boxShadow: hovering
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: 0.35,
                          ),
                          blurRadius: 22,
                          offset: const Offset(0, 9),
                        ),
                      ]
                    : null,
              ),
              child: Padding(
                padding: const EdgeInsets.all(9),
                child: Row(
                  children: [
                    _Poster(
                      media: media,
                      width: 105,
                      height: 145,
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 5,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              media.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: CinematicTitleFonts.captionStyle(
                                media,
                                baseFontSize: 17,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 9),
                            Wrap(
                              spacing: 7,
                              runSpacing: 6,
                              children: [
                                _MetaPill(
                                  label: widget.typeLabel,
                                ),
                                _MetaPill(
                                  label:
                                      media.displayYearLabel ?? 'Year unknown',
                                ),
                                if (media.displayEditionLabel != null)
                                  _MetaPill(label: media.displayEditionLabel!),
                                if (media.displaySeasonCount != null)
                                  _MetaPill(
                                      label:
                                          '${media.displaySeasonCount} ${media.displaySeasonCount == 1 ? 'Season' : 'Seasons'}'),
                                if (media.rating != null)
                                  _MetaPill(label: '★ ${media.rating}'),
                                RecommendationOwnershipBadge(
                                  isOwned: isOwned,
                                  isWatched: isWatched,
                                  watchedLabel: watchedLabel,
                                  compact: true,
                                ),
                              ],
                            ),
                            if (identityHint.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                identityHint,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: .95),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                            const SizedBox(height: 11),
                            Text(
                              media.description ?? '',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(
                                  alpha: 0.52,
                                ),
                                fontSize: 12.5,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedContainer(
                      duration: const Duration(
                        milliseconds: 200,
                      ),
                      width: 35,
                      height: 35,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(
                          alpha: hovering ? 0.13 : 0.055,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white.withValues(
                          alpha: hovering ? 0.9 : 0.45,
                        ),
                        size: 23,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _identityHint(MediaItem media) {
    final hints = <String>[];
    final original = media.originalTitle?.trim();
    if (original != null &&
        original.isNotEmpty &&
        original.toLowerCase() != media.title.trim().toLowerCase()) {
      hints.add('Original title: $original');
    }
    final disc = media.discTitle?.trim();
    if (disc != null &&
        disc.isNotEmpty &&
        disc.toLowerCase() != media.title.trim().toLowerCase()) {
      hints.add('Edition: $disc');
    }
    final country = media.countryOfOrigin?.trim();
    if (country != null && country.isNotEmpty) hints.add(country);
    final director =
        media.directors.isNotEmpty ? media.directors.first.trim() : '';
    if (director.isNotEmpty) hints.add('Directed by $director');
    if (hints.isEmpty && media.franchiseName?.trim().isNotEmpty == true) {
      hints.add('Part of ${media.franchiseName}');
    }
    return hints.join(' · ');
  }
}

class _Poster extends StatelessWidget {
  final MediaItem media;
  final double width;
  final double height;

  const _Poster({
    required this.media,
    required this.width,
    required this.height,
  });

  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    final imageUrl = media.imageUrl ?? '';

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              color: const Color(0xFF171717),
              child: const Center(
                child: Icon(
                  Icons.movie_outlined,
                  color: Colors.white24,
                  size: 32,
                ),
              ),
            ),
            if (imageUrl.isNotEmpty)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (
                  context,
                  child,
                  loadingProgress,
                ) {
                  if (loadingProgress == null) {
                    return child;
                  }

                  return Container(
                    color: const Color(0xFF171717),
                    child: const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white54,
                          ),
                        ),
                      ),
                    ),
                  );
                },
                errorBuilder: (
                  context,
                  error,
                  stackTrace,
                ) {
                  return Container(
                    color: const Color(0xFF171717),
                    child: const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white30,
                        size: 30,
                      ),
                    ),
                  );
                },
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 65,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(
                          alpha: 0.7,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final String label;

  const _MetaPill({
    required this.label,
  });

  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.075),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.68),
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconButton({
    required this.icon,
    required this.onTap,
  });

  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 21,
          ),
        ),
      ),
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptySearchState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.055),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white.withValues(alpha: 0.42),
            size: 34,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 9),
        ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 420,
          ),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchBackground extends StatelessWidget {
  const _SearchBackground();

  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -180,
            right: -130,
            child: Container(
              width: 430,
              height: 430,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(
                  alpha: 0.025,
                ),
              ),
            ),
          ),
          Positioned(
            top: 250,
            left: -230,
            child: Container(
              width: 460,
              height: 460,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(
                  alpha: 0.018,
                ),
              ),
            ),
          ),
          CustomPaint(
            size: Size.infinite,
            painter: _GridPainter(),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override

  /// Performs `paint` for this feature. Update this documentation when its contract changes.
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.018)
      ..strokeWidth = 0.5;

    const spacing = 45.0;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override

  /// Performs `shouldRepaint` for this feature. Update this documentation when its contract changes.
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) {
    return false;
  }
}
