import 'dart:async';

import 'package:flutter/material.dart';

import 'app_core.dart';
import 'details.dart';
import 'media_metadata_catalog_screen.dart';
import 'recommendation_ownership.dart';
import 'core/services/cinematic_title_metadata_service.dart';
import 'tmdb_title_recommendations_section.dart';

/// Home-first TMDB recommendations and mood discovery. The latest watched
/// movie/show is the anchor; when there is no watch history it falls back to a
/// movie/show in the active profile's library.
class HomeCinematicRecommendationsSection extends StatefulWidget {
  const HomeCinematicRecommendationsSection({
    super.key,
    required this.watched,
    required this.library,
  });

  final List<MediaItem> watched;
  final List<MediaItem> library;

  @override
  State<HomeCinematicRecommendationsSection> createState() =>
      _HomeCinematicRecommendationsSectionState();
}

class _HomeCinematicRecommendationsSectionState
    extends State<HomeCinematicRecommendationsSection> {
  MediaItem? _source;
  CinematicTitleMetadata? _sourceMetadata;
  List<CinematicTitleRecommendation> _recommendations =
      const <CinematicTitleRecommendation>[];
  Map<String, List<CinematicTitleRecommendation>> _recommendationGroups =
      const <String, List<CinematicTitleRecommendation>>{};
  String _selectedRecommendationGroup = 'combined';
  static const List<(String, String)> _recommendationModes = <(String, String)>[
    ('owned', '1 · In My Library'),
    ('external', '2 · Not Owned'),
    ('combined', '3 · Owned + Not Owned'),
    ('genre', '4 · Genre'),
    ('company', '5 · Company'),
    ('actors', '6 · Actors'),
    ('all', '7 · All of the Above'),
  ];
  List<CinematicTitleRecommendation> _moodRecommendations =
      const <CinematicTitleRecommendation>[];
  String? _selectedMoodKey;
  String? _error;
  bool _loading = false;
  bool _loadingMood = false;
  int _requestSequence = 0;

  static bool _isMovieOrShow(MediaItem item) {
    final type = item.type.trim().toLowerCase();
    if (type.contains('album') ||
        type.contains('music') ||
        type == 'track' ||
        type == 'artist' ||
        type == 'audio' ||
        type == 'song') {
      return false;
    }
    return item.isSeries ||
        type == 'movie' ||
        type == 'film' ||
        type.contains('movie') ||
        type.contains('film') ||
        type == 'feature';
  }

  static MediaItem? _chooseSource(
    List<MediaItem> watched,
    List<MediaItem> library,
  ) {
    for (final candidate in <MediaItem>[...watched, ...library]) {
      if (_isMovieOrShow(candidate) &&
          candidate.title.trim().isNotEmpty) {
        return candidate;
      }
    }
    return null;
  }

  static String _sourceFingerprint(MediaItem? item) => item == null
      ? ''
      : '${item.id}|${item.title}|${item.isSeries}|${item.releaseYear ?? item.seriesStartYear ?? ''}';

  @override
  void initState() {
    super.initState();
    unawaited(_loadForSource());
  }

  @override
  void didUpdateWidget(covariant HomeCinematicRecommendationsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldSource = _chooseSource(oldWidget.watched, oldWidget.library);
    final newSource = _chooseSource(widget.watched, widget.library);
    final oldLibraryIds = oldWidget.library.map((item) => item.id).join('|');
    final newLibraryIds = widget.library.map((item) => item.id).join('|');
    if (_sourceFingerprint(oldSource) != _sourceFingerprint(newSource) ||
        oldLibraryIds != newLibraryIds) {
      unawaited(_loadForSource());
    }
  }

  Future<void> _loadForSource() async {
    final request = ++_requestSequence;
    final source = _chooseSource(widget.watched, widget.library);
    if (source == null || !CinematicTitleMetadataService.isConfigured) {
      if (mounted) {
        setState(() {
          _source = source;
          _sourceMetadata = null;
          _recommendations = const <CinematicTitleRecommendation>[];
          _recommendationGroups = const <String, List<CinematicTitleRecommendation>>{};
          _moodRecommendations = const <CinematicTitleRecommendation>[];
          _loading = false;
          _error = null;
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _source = source;
        _sourceMetadata = null;
        _recommendations = const <CinematicTitleRecommendation>[];
        _recommendationGroups = const <String, List<CinematicTitleRecommendation>>{};
        _selectedRecommendationGroup = 'combined';
        _moodRecommendations = const <CinematicTitleRecommendation>[];
        _selectedMoodKey = null;
        _loading = true;
        _loadingMood = false;
        _error = null;
      });
    }
    try {
      final metadata = await CinematicTitleMetadataService.lookupTitle(
        title: source.title,
        isTv: source.isSeries,
        year: source.releaseYear ?? source.seriesStartYear,
      );
      if (!mounted || request != _requestSequence) return;
      setState(() => _sourceMetadata = metadata);
      if (metadata == null) {
        setState(() {
          _recommendations = const <CinematicTitleRecommendation>[];
          _error = 'Recommendations are unavailable for this title match.';
        });
        return;
      }
      final fetchedGroups = await CinematicTitleMetadataService
          .lookupPersonalizedRecommendationGroups(
        source: metadata,
        limit: 24,
      );
      if (!mounted || request != _requestSequence) return;

      final sourceKey = RecommendationOwnershipMatcher.normalizeTitle(source.title);
      final controller = AppController.instance;
      final allSimilar = _decorateRecommendations(
        fetchedGroups['similar'] ?? const <CinematicTitleRecommendation>[],
        controller: controller,
        fallbackReason: 'Because you watched ${source.title}.',
      ).where((item) =>
          RecommendationOwnershipMatcher.normalizeTitle(item.title) != sourceKey)
          .toList(growable: false);
      final backendPersonalized = _loadBackendRecommendationCards(
        controller: controller,
        source: source,
      );
      final ownedSimilar = _mergeRecommendationCards(
        <CinematicTitleRecommendation>[
          ...backendPersonalized.where((item) => item.isOwned),
          ...allSimilar.where((item) => item.isOwned),
        ].map((item) => item.withContext(
              owned: true,
              reason: item.recommendationReason ??
                  'Already in your library. Recommended because you watched ${source.title}.',
            )).toList(growable: false),
      );
      final externalSimilar = _mergeRecommendationCards(
        <CinematicTitleRecommendation>[
          ...backendPersonalized.where((item) => !item.isOwned),
          ...allSimilar.where((item) => !item.isOwned),
        ].map((item) => item.withContext(
              owned: false,
              reason: item.recommendationReason ??
                  'Not in your library yet. Recommended because you watched ${source.title}.',
            )).toList(growable: false),
      );
      final combined = _mergeRecommendationCards(
        <CinematicTitleRecommendation>[...backendPersonalized, ...allSimilar],
      );
      final genre = _decorateRecommendations(
        fetchedGroups['genre'] ?? const <CinematicTitleRecommendation>[],
        controller: controller,
        fallbackReason: 'Shares genre traits with ${source.title}.',
      );
      final company = _decorateRecommendations(
        fetchedGroups['company'] ?? const <CinematicTitleRecommendation>[],
        controller: controller,
        fallbackReason: 'Shares a production company or network with ${source.title}.',
      );
      final actors = _decorateRecommendations(
        fetchedGroups['actors'] ?? const <CinematicTitleRecommendation>[],
        controller: controller,
        fallbackReason: 'Features cast members from ${source.title}.',
      );
      final allProviderSignals = _decorateRecommendations(
        fetchedGroups['all'] ?? const <CinematicTitleRecommendation>[],
        controller: controller,
        fallbackReason: 'Matches several signals from ${source.title}.',
      );
      final all = _mergeRecommendationCards(<CinematicTitleRecommendation>[
        ...backendPersonalized,
        ...allProviderSignals,
      ]);
      final groups = <String, List<CinematicTitleRecommendation>>{
        'owned': List<CinematicTitleRecommendation>.unmodifiable(ownedSimilar),
        'external': List<CinematicTitleRecommendation>.unmodifiable(externalSimilar),
        'combined': List<CinematicTitleRecommendation>.unmodifiable(combined),
        'genre': genre,
        'company': company,
        'actors': actors,
        'all': all,
      };
      setState(() {
        _recommendationGroups = Map<String, List<CinematicTitleRecommendation>>.unmodifiable(groups);
        _recommendations = groups[_selectedRecommendationGroup] ?? combined;
      });
    } catch (error) {
      if (!mounted || request != _requestSequence) return;
      setState(() {
        _recommendations = const <CinematicTitleRecommendation>[];
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted && request == _requestSequence) {
        setState(() => _loading = false);
      }
    }
  }

  List<CinematicTitleRecommendation> _loadBackendRecommendationCards({
    required AppController controller,
    required MediaItem source,
  }) {
    final output = <CinematicTitleRecommendation>[];
    final media = controller.recommendations;
    for (var index = 0; index < media.length; index++) {
      final candidate = media[index];
      if (!_isMovieOrShow(candidate) ||
          candidate.isSeries != source.isSeries ||
          candidate.id == source.id ||
          RecommendationOwnershipMatcher.normalizeTitle(candidate.title) ==
              RecommendationOwnershipMatcher.normalizeTitle(source.title)) {
        continue;
      }
      final detail = index < controller.recommendationDetails.length
          ? controller.recommendationDetails[index]
          : const <String, dynamic>{};
      final reasons = detail['reasons'];
      final explanation = reasons is List
          ? reasons
              .whereType<Map>()
              .map((reason) => reason['description']?.toString().trim() ?? '')
              .where((reason) => reason.isNotEmpty)
              .take(2)
              .join(' ')
          : '';
      final owned = detail['isInLibrary'] == true;
      final defaultReason = owned
          ? 'Already in your library. Personalized from your viewing history and preferences.'
          : 'Not in your library yet. Personalized from your viewing history and preferences.';
      output.add(CinematicTitleRecommendation.fromMediaItem(
        candidate,
        isOwned: owned,
        reason: explanation.isEmpty ? defaultReason : explanation,
      ));
    }
    return List<CinematicTitleRecommendation>.unmodifiable(output);
  }

  List<CinematicTitleRecommendation> _mergeRecommendationCards(
    List<CinematicTitleRecommendation> items,
  ) {
    final merged = <String, CinematicTitleRecommendation>{};
    for (final item in items) {
      final year = item.releaseYear?.toString() ?? '';
      final key = '${item.isTv ? 'tv' : 'movie'}:'
          '${RecommendationOwnershipMatcher.normalizeTitle(item.title)}:$year';
      final existing = merged[key];
      if (existing == null) {
        merged[key] = item;
      } else if (existing.recommendationReason == null &&
          item.recommendationReason != null) {
        merged[key] = existing.withContext(
          reason: item.recommendationReason,
          owned: existing.isOwned || item.isOwned,
        );
      } else if (item.isOwned && !existing.isOwned) {
        merged[key] = existing.withContext(owned: true);
      }
    }
    return List<CinematicTitleRecommendation>.unmodifiable(merged.values);
  }

  List<CinematicTitleRecommendation> _decorateRecommendations(
    List<CinematicTitleRecommendation> items, {
    required AppController controller,
    required String fallbackReason,
  }) {
    final seen = <String>{};
    return items.where((item) {
      final identity = item.localMedia?.id ??
          '${item.isTv ? 'tv' : 'movie'}:${item.providerId}';
      return (item.providerId > 0 || item.localMedia != null) &&
          seen.add(identity);
    }).map((item) {
          final owned = item.localMedia != null
              ? item.isOwned
              : RecommendationOwnershipMatcher.isRecommendationOwned(
                  recommendation: item,
                  controller: controller,
                );
          return item.withContext(
            owned: owned,
            reason: item.recommendationReason ?? fallbackReason,
          );
        }).toList(growable: false);
  }

  void _selectRecommendationGroup(String key) {
    if (key == _selectedRecommendationGroup) return;
    setState(() {
      _selectedRecommendationGroup = key;
      _recommendations = _recommendationGroups[key] ?? const <CinematicTitleRecommendation>[];
    });
  }

  Future<void> _loadMood(CinematicRecommendationMood mood) async {
    final metadata = _sourceMetadata;
    if (metadata == null) return;
    setState(() {
      _selectedMoodKey = mood.key;
      _moodRecommendations = const <CinematicTitleRecommendation>[];
      _loadingMood = true;
      _error = null;
    });
    final request = _requestSequence;
    try {
      final results = await CinematicTitleMetadataService.lookupMoodRecommendations(
        moodKey: mood.key,
        sourceProviderId: metadata.providerId,
        sourceIsTv: metadata.isTv,
        limit: 20,
      );
      if (!mounted || request != _requestSequence || _selectedMoodKey != mood.key) return;
      final seen = <int>{metadata.providerId};
      final controller = AppController.instance;
      setState(() {
        _moodRecommendations = List.unmodifiable(results
            .where((item) => item.providerId > 0 && seen.add(item.providerId))
            .map((item) => item.withContext(
                  owned: RecommendationOwnershipMatcher.isRecommendationOwned(
                    recommendation: item,
                    controller: controller,
                  ),
                  reason: 'A ${mood.label} pick based on your discovery choice.',
                )));
      });
    } catch (error) {
      if (mounted && request == _requestSequence) {
        setState(() => _error = 'Could not load mood picks: ${error.toString().replaceFirst('Exception: ', '')}');
      }
    } finally {
      if (mounted && request == _requestSequence) setState(() => _loadingMood = false);
    }
  }

  Future<void> _openRecommendation(CinematicTitleRecommendation recommendation) async {
    final directMedia = recommendation.localMedia;
    if (directMedia != null) {
      await Navigator.of(context).push<void>(MaterialPageRoute<void>(
        builder: (_) => MediaDetailsScreen(media: directMedia),
      ));
      return;
    }
    final controller = AppController.instance;
    final localMatch = RecommendationOwnershipMatcher.findMediaForTitle(
      title: recommendation.title,
      isTv: recommendation.isTv,
      year: recommendation.releaseYear,
      controller: controller,
    );
    if (!mounted) return;
    if (localMatch != null) {
      await Navigator.of(context).push<void>(MaterialPageRoute<void>(
        builder: (_) => MediaDetailsScreen(media: localMatch),
      ));
      return;
    }
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => TmdbMetadataDetailsScreen(
        id: recommendation.providerId,
        type: recommendation.isTv ? 'tv' : 'movie',
        initialTitle: recommendation.title,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_source == null || !CinematicTitleMetadataService.isConfigured) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null && _recommendations.isEmpty && !_loading)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ),
          Text(
            'Seven ways to discover ${_source!.isSeries ? 'shows' : 'movies'}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 9),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final mode in _recommendationModes)
                  Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: ChoiceChip(
                      label: Text(mode.$2),
                      selected: _selectedRecommendationGroup == mode.$1,
                      onSelected: (_) => _selectRecommendationGroup(mode.$1),
                      showCheckmark: false,
                      backgroundColor: const Color(0xFF202027),
                      selectedColor: const Color(0xFF6955C8),
                      labelStyle: TextStyle(
                        color: _selectedRecommendationGroup == mode.$1
                            ? Colors.white
                            : Colors.white70,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                      side: BorderSide(
                        color: _selectedRecommendationGroup == mode.$1
                            ? const Color(0xFF9C8CF0)
                            : Colors.white12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TMDBTitleRecommendationsSection(
            sourceTitle: _source!.title,
            recommendations: _recommendations,
            loading: _loading,
            onOpen: (recommendation) => unawaited(_openRecommendation(recommendation)),
            moodOptionsEnabled: _sourceMetadata != null,
            selectedMoodKey: _selectedMoodKey,
            moodRecommendations: _moodRecommendations,
            loadingMoodRecommendations: _loadingMood,
            moodRecommendationError: _loadingMood ? null : _error,
            onMoodSelected: (mood) => unawaited(_loadMood(mood)),
          ),
        ],
      ),
    );
  }
}
