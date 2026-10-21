// FILE: `lib/smart_search.dart`.
// Purpose: Implements the smart search portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'backend_api.dart';
import 'app_core.dart';
import 'privacy_preferences.dart';
import 'details.dart';
import 'localization.dart';
import 'music.dart';
import 'music_favorites.dart';
import 'shop.dart';
import 'hollywood.dart';
import 'social_detail_pages.dart';
import 'home_streaming_discovery.dart';

class SmartSearch {
  static List<MediaItem> search(
    String query,
    List<MediaItem> library,
  ) {
    final q = query.trim().toLowerCase();

    if (q.isEmpty) {
      return [];
    }

    final normalizedQuery = _normalize(q);

    final typeQueries = <String>{
      'movie',
      'movies',
      'film',
      'films',
    };

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

    final scored = <_SearchMatch>[];
    final recommendationIds = <String, int>{
      for (var i = 0; i < AppController.instance.recommendations.length; i++)
        AppController.instance.recommendations[i].id:
            (50 - i).clamp(5, 50).toInt(),
    };

    for (final media in library) {
      final title = media.title.toLowerCase();
      final normalizedTitle = _normalize(title);

      final description = (media.description ?? '').toLowerCase();

      final normalizedDescription = _normalize(description);

      final type = media.type.toLowerCase();
      final year =
          (media.displayYearLabel ?? media.releaseYear?.toString() ?? '')
              .toLowerCase();
      final rating = media.rating.toString();

      var score = 0;

      final matchesExactTitle = normalizedTitle == normalizedQuery;

      final matchesTitle = normalizedTitle.contains(normalizedQuery);

      final matchesDescription =
          normalizedDescription.contains(normalizedQuery);

      final matchesType = type.contains(normalizedQuery);

      final normalizedYearQuery = normalizedQuery.replaceAll('-', '–');
      final matchesYear = year == normalizedYearQuery ||
          year.split(RegExp(r'[-–]')).contains(normalizedQuery);

      final matchesRating = rating == normalizedQuery;

      if (matchesExactTitle) {
        score += 120;
      } else if (matchesTitle) {
        score += 70;
      } else if (normalizedQuery.length >= 4) {
        // Typo tolerance for short title queries (e.g. "batmn" → "Batman").
        // Bounded edit distance avoids turning broad searches into unrelated matches.
        final titleTokens =
            normalizedTitle.split(' ').where((part) => part.isNotEmpty);
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
        ...media.directors,
        ...media.writers,
        ...media.genres,
        ...media.tags,
        ...media.music,
        ...media.studios,
        ...media.companies,
        if (media.franchiseName != null) media.franchiseName!,
      ];
      final matchesMetadata = _matchesMetadata(normalizedQuery, metadataFields);
      if (matchesMetadata) score += 28;

      if (matchesDescription) {
        score += 20;
      }

      if (matchesType) {
        score += 15;
      }

      if (matchesYear) {
        score += 45;
      }

      if (matchesRating) {
        score += 25;
      }

      if (isMovieQuery && _isMovie(type)) {
        score += 70;
      }

      if (isTvQuery && _isTvShow(type)) {
        score += 70;
      }

      if (score > 0) {
        // Personal relevance is a tie-breaker only after a genuine query match.
        score += recommendationIds[media.id] ?? 0;
        scored.add(
          _SearchMatch(
            media: media,
            score: score,
          ),
        );
      }
    }

    scored.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);

      if (scoreCompare != 0) {
        return scoreCompare;
      }

      return a.media.title.toLowerCase().compareTo(
            b.media.title.toLowerCase(),
          );
    });

    return scored.map((match) => match.media).toList();
  }

  /// Ranks the account's own library using backend recommendations when present,
  /// plus a transparent local fallback based on likes, watch history and metadata.
  /// This is a lightweight personal relevance model, not a claim of ML training.
  static List<MediaItem> recommendations(List<MediaItem> library,
      {int limit = 12}) {
    if (limit <= 0 || library.isEmpty) return <MediaItem>[];
    final controller = AppController.instance;
    final profileId = controller.currentProfile?.id;
    if (!PrivacyPreferencesStore.cached(profileId)
        .personalizedRecommendations) {
      final excluded = <String>{
        ...controller.disliked.map((item) => item.id),
        ...controller.watched.map((item) => item.id),
      };
      final generic = library
          .where((item) =>
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

    final candidates = library
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
      if (candidateFranchise.isNotEmpty && candidateFranchise == seedFranchise) {
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
      if (normalized.contains(query)) return true;
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

  static String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

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
  List<ShopProduct> productResults = <ShopProduct>[];
  List<Map<String, dynamic>> peopleResults = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> socialResults = <Map<String, dynamic>>[];
  bool remoteSearchLoading = false;
  Timer? _searchDebounce;
  int _remoteSearchGeneration = 0;

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
    final musicMatches = normalized.isEmpty
        ? <MusicTrack>[]
        : MusicLibraryStore.instance.tracks.where((track) {
            final searchable = <String>[
              track.title,
              track.artist,
              track.album,
              ...track.genres,
              ...track.featuredArtists,
              ...track.subgenres,
            ].join(' ').toLowerCase();
            return searchable.contains(normalized);
          }).toList();
    musicMatches.sort((a, b) {
      final aExact = a.title.toLowerCase() == normalized ? 0 : 1;
      final bExact = b.title.toLowerCase() == normalized ? 0 : 1;
      if (aExact != bExact) return aExact.compareTo(bExact);
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });

    final localPeople = _localPeople(normalized);
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
      productResults = products;
      peopleResults = localPeople;
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

  List<Map<String, dynamic>> _localPeople(String query) {
    if (query.isEmpty) return <Map<String, dynamic>>[];
    final controller = AppController.instance;
    final sources = <String, List<String>>{
      'Actor': controller.actorsCatalog,
      'Director': controller.directorsCatalog,
      'Writer': controller.writersCatalog,
      'Artist / band': controller.musicCatalog,
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
            clean.toLowerCase(),
            () => <String, dynamic>{
                  'id': clean,
                  'name': clean,
                  'category': entry.key,
                  'source': 'local-library',
                });
      }
    }
    return found.values.take(12).toList(growable: false);
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

  Future<void> _loadRemoteSearch(String query, int generation) async {
    final app = AppController.instance;
    final profile = app.currentProfile;
    if (profile == null || !app.backendApi.isAuthenticated) {
      if (mounted && generation == _remoteSearchGeneration) {
        setState(() => remoteSearchLoading = false);
      }
      return;
    }

    final remotePeople = <Map<String, dynamic>>[];
    final remoteSocial = <Map<String, dynamic>>[];
    try {
      // The backend may match credits, aliases, or career metadata rather than
      // only the display name, so preserve all results returned for this query.
      final people = await app.backendApi.searchMediaPeople(query: query);
      remotePeople.addAll(people);
    } catch (_) {
      // Search still works from the local library if the people service is offline.
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
      mergedPeople.putIfAbsent(name.toLowerCase(), () => person);
    }
    setState(() {
      peopleResults = mergedPeople.values.take(15).toList(growable: false);
      socialResults = remoteSocial.take(30).toList(growable: false);
      remoteSearchLoading = false;
    });
  }

  void _openPerson(Map<String, dynamic> person) {
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
      Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => MusicArtistProfileScreen(artistName: name),
          ));
      return;
    }
    Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ActorDetailsScreen(
              actor: Actor(
            id: (person['id'] ??
                    person['personId'] ??
                    person['person_id'] ??
                    name)
                .toString(),
            name: name,
            photoUrl: (person['photoUrl'] ??
                    person['photo_url'] ??
                    person['imageUrl'] ??
                    person['image_url'] ??
                    '')
                .toString(),
            biography: (person['biography'] ?? person['bio'] ?? '').toString(),
            placeOfBirth:
                (person['placeOfBirth'] ?? person['place_of_birth'] ?? '')
                    .toString(),
            dateOfBirth: DateTime.tryParse(
                (person['dateOfBirth'] ?? person['date_of_birth'] ?? '')
                    .toString()),
            knownFor: (person['knownFor'] ??
                    person['known_for'] ??
                    person['profession'] ??
                    person['category'] ??
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
      if (id.isEmpty) return;
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
      if (accountId.isEmpty || profileId.isEmpty) return;
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
      productResults = <ShopProduct>[];
      peopleResults = <Map<String, dynamic>>[];
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
      'podcast' => 'PODCAST',
      'audiobook' => 'AUDIOBOOK',
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
                      'Search movies, shows, music, themes, playlists, and collections',
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
                  'Search movies, shows, music, people, friends, communities, products…',
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
    if (controller.text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        22,
        25,
        22,
        12,
      ),
      child: Row(
        children: [
          Text(
            remoteSearchLoading &&
                    results.isEmpty &&
                    musicResults.isEmpty &&
                    productResults.isEmpty &&
                    peopleResults.isEmpty &&
                    socialResults.isEmpty
                ? 'Searching…'
                : results.isEmpty &&
                        musicResults.isEmpty &&
                        productResults.isEmpty &&
                        peopleResults.isEmpty &&
                        socialResults.isEmpty
                    ? 'No results'
                    : '${results.length + musicResults.length + productResults.length + peopleResults.length + socialResults.length} ${(results.length + musicResults.length + productResults.length + peopleResults.length + socialResults.length) == 1 ? 'result' : 'results'}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (remoteSearchLoading)
            const SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(strokeWidth: 1.5))
          else if (results.isNotEmpty ||
              musicResults.isNotEmpty ||
              productResults.isNotEmpty ||
              peopleResults.isNotEmpty ||
              socialResults.isNotEmpty)
            UniversalText(
              'CONNECTED SEARCH',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
        ],
      ),
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
        productResults.isEmpty &&
        peopleResults.isEmpty &&
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

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          if (results.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(top: 4, bottom: 8),
              child: UniversalText('Movies & TV',
                  style: TextStyle(
                      color: Colors.white70, fontWeight: FontWeight.w800)),
            ),
            for (var index = 0; index < results.length; index++)
              _SearchResultCard(
                key: ValueKey('media:${results[index].id}'),
                media: results[index],
                typeLabel: _typeLabel(results[index]),
                index: index,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            MediaDetailsScreen(media: results[index]))),
              ),
          ],
          if (musicResults.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(top: 18, bottom: 8),
              child: UniversalText('Music',
                  style: TextStyle(
                      color: Colors.white70, fontWeight: FontWeight.w800)),
            ),
            for (final track in musicResults)
              Card(
                color: Colors.white.withValues(alpha: .055),
                child: ListTile(
                  leading:
                      const CircleAvatar(child: Icon(Icons.music_note_rounded)),
                  title: Text(track.title),
                  subtitle: Text(
                      '${track.artist}${track.album.trim().isEmpty ? '' : ' · ${track.album}'}'),
                  trailing: const Icon(Icons.play_arrow_rounded),
                  onTap: () => MusicPlaybackController.instance.play(track),
                ),
              ),
          ],
          if (peopleResults.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(top: 18, bottom: 8),
              child: UniversalText('Actors, artists & entertainment people',
                  style: TextStyle(
                      color: Colors.white70, fontWeight: FontWeight.w800)),
            ),
            for (final person in peopleResults)
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
                                .isNotEmpty ??
                            false)
                        ? NetworkImage((person['photoUrl'] ??
                                person['photo_url'] ??
                                person['imageUrl'] ??
                                person['image_url'])
                            .toString())
                        : null,
                    child: const Icon(Icons.person_outline_rounded),
                  ),
                  title: Text(_mapText(person, <String>[
                    'name',
                    'displayName',
                    'display_name',
                    'fullName',
                    'full_name'
                  ]).trim()),
                  subtitle: Text((person['knownFor'] ??
                          person['known_for'] ??
                          person['profession'] ??
                          person['category'] ??
                          'Entertainment')
                      .toString()),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _openPerson(person),
                ),
              ),
          ],
          if (socialResults.isNotEmpty) ...[
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
          if (productResults.isNotEmpty) ...[
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
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
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
