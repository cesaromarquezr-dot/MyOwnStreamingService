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
    if (_sourceFingerprint(oldSource) != _sourceFingerprint(newSource)) {
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
      final fetched = await CinematicTitleMetadataService.lookupRecommendations(
        providerId: metadata.providerId,
        isTv: metadata.isTv,
        limit: 20,
      );
      if (!mounted || request != _requestSequence) return;
      final sourceKey = RecommendationOwnershipMatcher.normalizeTitle(source.title);
      final seen = <int>{metadata.providerId};
      final filtered = <CinematicTitleRecommendation>[];
      for (final item in fetched) {
        if (item.providerId <= 0 || !seen.add(item.providerId)) continue;
        if (item.isTv == source.isSeries &&
            RecommendationOwnershipMatcher.normalizeTitle(item.title) == sourceKey) {
          continue;
        }
        filtered.add(item);
      }
      setState(() => _recommendations = List.unmodifiable(filtered));
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
      setState(() {
        _moodRecommendations = List.unmodifiable(results.where((item) =>
            item.providerId > 0 && seen.add(item.providerId)));
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
