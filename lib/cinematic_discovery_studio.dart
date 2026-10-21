/// Cinematic discovery features built on the existing local catalog.
///
/// This module deliberately describes its data boundaries: mood ranking uses
/// available genre/tag/history signals, and calendar items are profile-scoped
/// local reminders until a trusted release/event provider is configured.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_core.dart';
import 'details.dart';
import 'genre_system.dart';
import 'media_night_features.dart';
import 'media_feature_preferences.dart';
import 'smart_search.dart';
import 'social_center.dart';
import 'watch_party_lobby.dart';
import 'xray.dart';

const Color _cinemaBg = Color(0xFF0B0B10);
const Color _cinemaPanel = Color(0xFF171722);
const Color _cinemaAccent = Color(0xFF8B7CFF);

/// Transparent catalog-based ranking helpers shared by the discovery screens.
class CinematicDiscoveryLogic {
  CinematicDiscoveryLogic._();

  static bool isMovie(MediaItem item) {
    final type = item.type.toLowerCase();
    return type.contains('movie') || type.contains('film');
  }

  static String _text(MediaItem item) => <String>[
        item.title,
        item.description ?? '',
        ...item.genres,
        ...item.tags,
        ...item.actors,
        ...item.directors,
        ...item.writers,
        ...item.companies,
        item.franchiseName ?? '',
      ].join(' ').toLowerCase();

  static double moodScore(
    MediaItem item, {
    required int humor,
    required int intensity,
    required int darkness,
    required int romance,
    required int novelty,
    Set<String> familiarGenres = const <String>{},
  }) {
    final genres = <String>{
      for (final genre in GenreSystem.normalizeGenres(item.genres))
        ...GenreSystem.componentsFor(genre)
            .map((component) => component.toLowerCase()),
    };
    final text = _text(item);
    double axis(int value, bool matches, {double weight = 1}) {
      final preference = (value - 50) / 50;
      if (!matches) return 0;
      return preference * 10 * weight;
    }

    final funny =
        genres.any(const {'comedy', 'animation', 'family'}.contains) ||
            RegExp(r'\b(funny|humor|humour|satire|slapstick|comedic)\b')
                .hasMatch(text);
    final intense =
        genres.any(const {'thriller', 'action', 'horror', 'crime'}.contains) ||
            RegExp(r'\b(intense|suspense|high stakes|chase|survival)\b')
                .hasMatch(text);
    final dark = genres.any(const {'horror', 'crime', 'thriller'}.contains) ||
        RegExp(r'\b(dark|bleak|violent|gothic|disturbing|psychological)\b')
            .hasMatch(text);
    final romantic = genres.contains('romance') ||
        RegExp(r'\b(romance|romantic|love story|relationship)\b')
            .hasMatch(text);

    var score = 0.0;
    score += axis(humor, funny);
    score += axis(intensity, intense);
    score += axis(darkness, dark);
    score += axis(romance, romantic);

    if (novelty >= 50) {
      final unfamiliar =
          genres.where((g) => !familiarGenres.contains(g)).length;
      score +=
          (novelty - 50) / 50 * (unfamiliar * 2.5 + item.genres.length * 0.5);
    } else if (genres.any(familiarGenres.contains)) {
      score += (50 - novelty) / 50 * 2.0;
    }

    final controller = AppController.instance;
    if (controller.liked.any((seed) => seed.id == item.id)) score += 2;
    if (controller.isWatched(item.id)) score -= 2.5;
    score += (item.rating ?? 0) / 10;
    return score;
  }

  static List<MediaItem> rankForMood(
    Iterable<MediaItem> items, {
    required int humor,
    required int intensity,
    required int darkness,
    required int romance,
    required int novelty,
    bool unwatchedOnly = true,
  }) {
    final controller = AppController.instance;
    final familiarGenres = <String>{
      for (final item in <MediaItem>[
        ...controller.watched,
        ...controller.liked
      ])
        for (final genre in GenreSystem.normalizeGenres(item.genres))
          ...GenreSystem.componentsFor(genre)
              .map((component) => component.toLowerCase()),
    };
    final candidates =
        items.where((item) => !unwatchedOnly || !controller.isWatched(item.id));
    final ranked = candidates.toList()
      ..sort((a, b) => moodScore(
            b,
            humor: humor,
            intensity: intensity,
            darkness: darkness,
            romance: romance,
            novelty: novelty,
            familiarGenres: familiarGenres,
          ).compareTo(moodScore(
            a,
            humor: humor,
            intensity: intensity,
            darkness: darkness,
            romance: romance,
            novelty: novelty,
            familiarGenres: familiarGenres,
          )));
    return ranked;
  }

  static String moodExplanation(
    MediaItem item, {
    required int humor,
    required int intensity,
    required int darkness,
    required int romance,
    required int novelty,
  }) {
    final parts = <String>[];
    final genres = <String>{
      for (final genre in GenreSystem.normalizeGenres(item.genres))
        ...GenreSystem.componentsFor(genre)
            .map((component) => component.toLowerCase()),
    };
    if (humor >= 65 &&
        genres.intersection({'comedy', 'animation', 'family'}).isNotEmpty) {
      parts.add('fits your lighter/funnier setting');
    }
    if (intensity >= 65 &&
        genres.intersection(
            {'thriller', 'action', 'horror', 'crime'}).isNotEmpty) {
      parts.add('matches your intensity preference');
    }
    if (darkness >= 65 &&
        genres.intersection({'horror', 'crime', 'thriller'}).isNotEmpty) {
      parts.add('fits a darker mood');
    }
    if (romance >= 65 && genres.contains('romance')) {
      parts.add('includes romance');
    }
    if (novelty >= 70) parts.add('leans toward discovery and variety');
    if (novelty <= 30 &&
        AppController.instance.watched.any((watched) => watched.genres
            .any((genre) => genres.contains(genre.toLowerCase())))) {
      parts.add('overlaps with familiar genres');
    }
    if (parts.isEmpty) {
      parts.add('ranked from available genre, rating and history signals');
    }
    return 'Suggested because it ${parts.join(' and ')}.';
  }

  static List<List<MediaItem>> topDoubleFeatures(Iterable<MediaItem> items,
      {int limit = 5}) {
    final movies = items.where(isMovie).toList(growable: false);
    final scored = <({MediaItem first, MediaItem second, double score})>[];
    for (var i = 0; i < movies.length; i++) {
      for (var j = i + 1; j < movies.length; j++) {
        final a = movies[i];
        final b = movies[j];
        if (a.id == b.id ||
            a.title.trim().toLowerCase() == b.title.trim().toLowerCase()) {
          continue;
        }
        final ga = <String>{
          for (final genre in GenreSystem.normalizeGenres(a.genres))
            ...GenreSystem.componentsFor(genre)
                .map((component) => component.toLowerCase()),
        };
        final gb = <String>{
          for (final genre in GenreSystem.normalizeGenres(b.genres))
            ...GenreSystem.componentsFor(genre)
                .map((component) => component.toLowerCase()),
        };
        final common = ga.intersection(gb).length;
        final diverse = ga.union(gb).length;
        final aFranchise =
            (a.franchiseId ?? a.franchiseName ?? '').trim().toLowerCase();
        final bFranchise =
            (b.franchiseId ?? b.franchiseName ?? '').trim().toLowerCase();
        final sameFranchise = aFranchise.isNotEmpty && aFranchise == bFranchise;
        final complementary =
            (ga.contains('horror') && gb.contains('comedy')) ||
                (ga.contains('comedy') && gb.contains('horror')) ||
                (ga.contains('romance') && gb.contains('thriller')) ||
                (ga.contains('thriller') && gb.contains('romance')) ||
                (ga.contains('science fiction') && gb.contains('drama')) ||
                (ga.contains('drama') && gb.contains('science fiction')) ||
                (ga.contains('action') && gb.contains('comedy')) ||
                (ga.contains('comedy') && gb.contains('action'));
        final sharedDirector = a.directors.any((name) => b.directors.any(
            (other) =>
                other.trim().toLowerCase() == name.trim().toLowerCase()));
        final score = common * 2.0 +
            diverse * 0.8 +
            (sameFranchise ? 7 : 0) +
            (complementary ? 4 : 0) +
            (sharedDirector ? 1.5 : 0) +
            (a.rating ?? 0) / 20 +
            (b.rating ?? 0) / 20;
        scored.add((first: a, second: b, score: score));
      }
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    final result = <List<MediaItem>>[];
    final seen = <String>{};
    for (final pair in scored) {
      final ids = [pair.first.id, pair.second.id]..sort();
      final key = ids.join('::');
      if (seen.add(key)) result.add([pair.first, pair.second]);
      if (result.length >= limit) break;
    }
    return result;
  }

  static String doubleFeatureReason(MediaItem a, MediaItem b) {
    final genresA = <String>{
      for (final genre in GenreSystem.normalizeGenres(a.genres))
        ...GenreSystem.componentsFor(genre)
            .map((component) => component.toLowerCase()),
    };
    final genresB = <String>{
      for (final genre in GenreSystem.normalizeGenres(b.genres))
        ...GenreSystem.componentsFor(genre)
            .map((component) => component.toLowerCase()),
    };
    if ((genresA.contains('horror') && genresB.contains('comedy')) ||
        (genresB.contains('horror') && genresA.contains('comedy'))) {
      return 'A scare-and-laugh double feature, combining horror with comedy.';
    }
    if ((genresA.contains('romance') && genresB.contains('thriller')) ||
        (genresB.contains('romance') && genresA.contains('thriller'))) {
      return 'A romance-and-suspense pairing with different emotional gears.';
    }
    final franchiseA =
        (a.franchiseId ?? a.franchiseName ?? '').trim().toLowerCase();
    final franchiseB =
        (b.franchiseId ?? b.franchiseName ?? '').trim().toLowerCase();
    if (franchiseA.isNotEmpty && franchiseA == franchiseB) {
      return 'A connected-franchise pairing for a mini-marathon.';
    }
    return 'Paired from overlapping genres, related metadata and available ratings.';
  }

  static Map<String, List<MediaItem>> franchiseGroups(
    Iterable<MediaItem> items, {
    String sortMode = 'Recommended Order',
  }) {
    final groups = <String, List<MediaItem>>{};
    for (final item in items) {
      final name =
          (item.franchiseName ?? item.adaptationGroupName ?? '').trim();
      final id = (item.franchiseId ?? item.adaptationGroupId ?? '').trim();
      final key = name.isNotEmpty ? name : id;
      if (key.isEmpty) continue;
      groups.putIfAbsent(key, () => <MediaItem>[]).add(item);
    }
    for (final group in groups.values) {
      group.sort((a, b) {
        if (sortMode == 'Title') {
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        }
        final byYear =
            (a.releaseYear ?? 999999).compareTo(b.releaseYear ?? 999999);
        if (sortMode == 'Release Year') {
          return byYear != 0
              ? byYear
              : a.title.toLowerCase().compareTo(b.title.toLowerCase());
        }
        final orderA = a.franchiseOrder ?? (1 << 20);
        final orderB = b.franchiseOrder ?? (1 << 20);
        final byOrder = orderA.compareTo(orderB);
        if (byOrder != 0 && orderA != (1 << 20) && orderB != (1 << 20)) {
          return byOrder;
        }
        return byYear != 0
            ? byYear
            : a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
    }
    final orderedKeys = groups.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return {for (final key in orderedKeys) key: groups[key]!};
  }

  static List<MediaItem> conciergeSearch(
      String query, Iterable<MediaItem> library) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return <MediaItem>[];
    final normalized = GenreSystem.genresMentionedIn(q);
    final explicitGenres = normalized
        .where((value) => GenreSystem.canonicalGenres
            .any((g) => g.toLowerCase() == value.toLowerCase()))
        .toList(growable: false);
    final moodEntries = GenreSystem.moodGenreHints.entries
        .where((entry) => q.contains(entry.key))
        .toList(growable: false);
    final stopWords = <String>{
      'find',
      'show',
      'me',
      'a',
      'an',
      'the',
      'movie',
      'movies',
      'film',
      'films',
      'series',
      'shows',
      'tv',
      'that',
      'are',
      'is',
      'with',
      'for',
      'something',
      'please',
      'i',
      'want',
      'watch',
      'of',
      'and',
      'or',
      'under',
      'minutes',
      'minute',
      ...GenreSystem.canonicalGenres.map((g) => g.toLowerCase()),
      ...GenreSystem.moodGenreHints.keys,
    };
    final discoveredGenreTokens = normalized
        .expand((genre) => genre.toLowerCase().split(RegExp(r'[^a-z0-9]+')))
        .where((token) => token.isNotEmpty)
        .toSet();
    final textTokens = q
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .split(RegExp(r'\s+'))
        .where((token) =>
            token.length > 2 &&
            !stopWords.contains(token) &&
            !discoveredGenreTokens.contains(token))
        .toList();
    final results = library.where((item) {
      if (explicitGenres.isNotEmpty &&
          !GenreSystem.matchesGenres(item.genres, explicitGenres,
              matchAll: true)) {
        return false;
      }
      if (moodEntries.isNotEmpty &&
          !moodEntries.any((entry) => GenreSystem.matchesGenres(
              item.genres, entry.value,
              matchAll: false))) {
        return false;
      }
      final metadata = _text(item);
      return textTokens.isEmpty || textTokens.any(metadata.contains);
    }).toList();
    if (results.isEmpty && explicitGenres.isEmpty && moodEntries.isEmpty) {
      return SmartSearch.search(query, library.toList());
    }
    results.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
    return results;
  }
}

class CinematicDiscoveryStudioScreen extends StatelessWidget {
  const CinematicDiscoveryStudioScreen({super.key});

  void _open(BuildContext context, Widget screen) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _cinemaBg,
        appBar: AppBar(
            title: const Text('My Cinematic Universe'),
            backgroundColor: _cinemaBg),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                  colors: [Color(0xFF30244F), Color(0xFF161622)]),
              border: Border.all(color: Colors.white12),
            ),
            child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.auto_awesome_rounded,
                      size: 38, color: Color(0xFFD4C7FF)),
                  SizedBox(height: 12),
                  Text('More than a wall of posters',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.w900)),
                  SizedBox(height: 7),
                  Text(
                      'Explore by mood, find smart double features, follow connected franchises, save premiere reminders and learn what your viewing history says about you.',
                      style: TextStyle(color: Colors.white70, height: 1.4)),
                ]),
          ),
          const SizedBox(height: 18),
          _studioTile(
              context,
              Icons.tune_rounded,
              'Mood Mixer',
              'Tune humor, intensity, darkness, romance and novelty.',
              const MoodMixerScreen()),
          _studioTile(
              context,
              Icons.theaters_rounded,
              'Smart Double Feature',
              'Find two movies that pair well from your current catalog.',
              const SmartDoubleFeatureScreen()),
          _studioTile(
              context,
              Icons.account_tree_rounded,
              'Franchise Navigator',
              'Browse linked titles in release or franchise order.',
              const FranchiseNavigatorScreen()),
          _studioTile(
              context,
              Icons.event_rounded,
              'Personal Premiere Calendar',
              'Save profile-specific premieres, episode dates and event reminders.',
              const PremiereCalendarScreen()),
          _studioTile(
              context,
              Icons.video_library_rounded,
              'My Entertainment Vault',
              'Filter physical discs, favorites, watched titles and available playback URLs.',
              const EntertainmentVaultScreen()),
          _studioTile(
              context,
              Icons.auto_graph_rounded,
              'My Media Wrapped',
              'See top genres, hybrid genres, people and franchises in watched history.',
              const MediaWrappedScreen()),
          _studioTile(
              context,
              Icons.travel_explore_rounded,
              'X-Ray Story Explorer',
              'Choose a title to explore cast, production, connections and spoiler-aware details.',
              const XRayCatalogPickerScreen()),
          _studioTile(
              context,
              Icons.search_rounded,
              'Hey Media Watch Concierge',
              'Search using requests such as “funny horror movies” or “romantic thrillers”.',
              const WatchConciergeScreen()),
          _studioTile(
              context,
              Icons.public_rounded,
              'Universal Catalog Search',
              'Search the current entertainment catalog by title, genre, cast and metadata.',
              const CinematicUniversalSearchScreen()),
          const SizedBox(height: 8),
          const Text('Personal entertainment tools',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          _studioTile(
              context,
              Icons.nightlight_round,
              'My Media Night',
              'Plan a themed night with catalog picks, music, food ideas and the existing Watch Party flow.',
              const MyMediaNightScreen()),
          _studioTile(
              context,
              Icons.radar_rounded,
              'My Availability Radar',
              'Separate personal playback, physical copies and metadata-only titles.',
              const MediaAvailabilityRadarScreen()),
          _studioTile(
              context,
              Icons.tune_rounded,
              'Taste Tuner',
              'Save profile-scoped preferred genres, excluded genres and rating preferences.',
              const TasteTunerScreen()),
          _studioTile(
              context,
              Icons.visibility_off_rounded,
              'Spoiler Shield',
              'Hide synopsis and cast for titles you have not marked watched.',
              const SpoilerShieldScreen()),
          _studioTile(
              context,
              Icons.queue_play_next_rounded,
              'My Next Up Queue',
              'Maintain and reorder the active profile’s personal queue.',
              const NextUpQueueScreen()),
          _studioTile(
              context,
              Icons.luggage_rounded,
              'Travel Mode',
              'Prepare a shortlist for offline checks before a trip; it does not download media.',
              const TravelModeScreen()),
          _studioTile(
              context,
              Icons.fact_check_rounded,
              'Media Data Quality Center',
              'Find possible duplicates and missing metadata without auto-editing your catalog.',
              const MediaDataQualityCenterScreen()),
          _studioTile(
              context,
              Icons.privacy_tip_outlined,
              'My Data & Privacy Center',
              'Export a local profile summary or clear this module’s local settings.',
              const MyDataPrivacyCenterScreen()),
          _studioTile(
              context,
              Icons.groups_rounded,
              'Watch Party 2.0',
              'Open the existing party lobby; real synchronization requires connected services.',
              const WatchPartyLobbyScreen()),
          _studioTile(
              context,
              Icons.forum_rounded,
              'Fandom & Communities',
              'Open the existing social center for friends, communities and messages.',
              const SocialCenterScreen()),
          const SizedBox(height: 10),
          const Text(
              'Integration note: release feeds, provider-wide availability, cross-device party sync, external platform playback and live event delivery require connected provider/backend integrations. These local-catalog tools do not invent that data.',
              style:
                  TextStyle(color: Colors.white54, fontSize: 12, height: 1.4)),
        ]),
      );

  Widget _studioTile(BuildContext context, IconData icon, String title,
          String subtitle, Widget screen) =>
      Card(
          color: _cinemaPanel,
          margin: const EdgeInsets.only(bottom: 9),
          child: ListTile(
            leading: CircleAvatar(
                backgroundColor: _cinemaAccent.withValues(alpha: .15),
                child: Icon(icon, color: _cinemaAccent)),
            title: Text(title,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
            subtitle:
                Text(subtitle, style: const TextStyle(color: Colors.white60)),
            trailing:
                const Icon(Icons.chevron_right_rounded, color: Colors.white54),
            onTap: () => _open(context, screen),
          ));
}

class MoodMixerScreen extends StatefulWidget {
  const MoodMixerScreen({super.key});
  @override
  State<MoodMixerScreen> createState() => _MoodMixerScreenState();
}

class _MoodMixerScreenState extends State<MoodMixerScreen> {
  double humor = 70, intensity = 45, darkness = 35, romance = 45, novelty = 65;
  bool unwatchedOnly = true;
  TasteTunerPreferences _tastePreferences = const TasteTunerPreferences();

  @override
  void initState() {
    super.initState();
    MediaFeaturePreferences.loadTaste().then((value) {
      if (mounted) setState(() => _tastePreferences = value);
    });
  }

  Widget _moodSlider(String label, double value, ValueChanged<double> changed,
          String low, String high) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w700))),
          Text('${value.round()}%',
              style: const TextStyle(color: Colors.white60))
        ]),
        Slider(
            value: value, min: 0, max: 100, divisions: 20, onChanged: changed),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(low,
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
          Text(high,
              style: const TextStyle(color: Colors.white38, fontSize: 11))
        ]),
      ]);

  @override
  Widget build(BuildContext context) {
    final library = AppController.instance.library;
    final watchedIds =
        AppController.instance.watched.map((item) => item.id).toSet();
    final ranked = CinematicDiscoveryLogic.rankForMood(
      library,
      humor: humor.round(),
      intensity: intensity.round(),
      darkness: darkness.round(),
      romance: romance.round(),
      novelty: novelty.round(),
      unwatchedOnly: unwatchedOnly,
    )
        .where((item) => MediaNightFeatureLogic.matchesTaste(
              item,
              _tastePreferences,
              watchedIds: watchedIds,
            ))
        .take(30)
        .toList();
    return Scaffold(
        backgroundColor: _cinemaBg,
        appBar:
            AppBar(title: const Text('Mood Mixer'), backgroundColor: _cinemaBg),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Set the feeling, not just the genre.',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text(
              'Scores are inferred from genre labels, tags, text and profile history. Titles without mood metadata are not treated as verified mood matches.',
              style: TextStyle(color: Colors.white60)),
          const SizedBox(height: 16),
          _moodSlider('Humor', humor, (v) => setState(() => humor = v),
              'Serious', 'Funny'),
          _moodSlider('Intensity', intensity,
              (v) => setState(() => intensity = v), 'Relaxed', 'Intense'),
          _moodSlider('Darkness', darkness, (v) => setState(() => darkness = v),
              'Lighthearted', 'Dark'),
          _moodSlider('Romance', romance, (v) => setState(() => romance = v),
              'Little / none', 'Romantic'),
          _moodSlider('Novelty', novelty, (v) => setState(() => novelty = v),
              'Comfort picks', 'Surprising'),
          SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: unwatchedOnly,
              title: const Text('Hide completed titles'),
              onChanged: (v) => setState(() => unwatchedOnly = v)),
          const Divider(color: Colors.white12),
          Text('${ranked.length} suggestions from your catalog',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (ranked.isEmpty)
            const _DiscoveryEmpty(
                message:
                    'There are no titles to show for the current profile and filters.'),
          ...ranked.map((item) => _MediaResultTile(
              item: item,
              subtitle:
                  '${GenreSystem.displayLabel(item.genres)}\n${CinematicDiscoveryLogic.moodExplanation(item, humor: humor.round(), intensity: intensity.round(), darkness: darkness.round(), romance: romance.round(), novelty: novelty.round())}')),
        ]));
  }
}

class SmartDoubleFeatureScreen extends StatelessWidget {
  const SmartDoubleFeatureScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final pairs = CinematicDiscoveryLogic.topDoubleFeatures(
        AppController.instance.library);
    return Scaffold(
        backgroundColor: _cinemaBg,
        appBar: AppBar(
            title: const Text('Smart Double Feature'),
            backgroundColor: _cinemaBg),
        body: pairs.isEmpty
            ? const _DiscoveryEmpty(
                message:
                    'Add at least two distinct movie titles with genre metadata to generate pairings.')
            : ListView(padding: const EdgeInsets.all(16), children: [
                const Text('Two movies, one curated night.',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text(
                    'Pairings use genre overlap, complementary genres, shared franchise/crew metadata and available ratings. Runtime is not estimated unless real runtime metadata becomes available.',
                    style: TextStyle(color: Colors.white60)),
                const SizedBox(height: 14),
                ...pairs.asMap().entries.map((entry) {
                  final pair = entry.value;
                  final a = pair[0];
                  final b = pair[1];
                  return Card(
                      color: _cinemaPanel,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('DOUBLE FEATURE ${entry.key + 1}',
                                    style: const TextStyle(
                                        color: _cinemaAccent,
                                        fontSize: 11,
                                        letterSpacing: 1.3,
                                        fontWeight: FontWeight.w800)),
                                const SizedBox(height: 8),
                                _PairMovie(item: a),
                                const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 5),
                                    child: Center(
                                        child: Icon(Icons.add_circle_outline,
                                            color: _cinemaAccent))),
                                _PairMovie(item: b),
                                const SizedBox(height: 10),
                                Text(
                                    CinematicDiscoveryLogic.doubleFeatureReason(
                                        a, b),
                                    style:
                                        const TextStyle(color: Colors.white70)),
                              ])));
                }),
              ]));
  }
}

class FranchiseNavigatorScreen extends StatefulWidget {
  const FranchiseNavigatorScreen({super.key});
  @override
  State<FranchiseNavigatorScreen> createState() =>
      _FranchiseNavigatorScreenState();
}

class _FranchiseNavigatorScreenState extends State<FranchiseNavigatorScreen> {
  String filter = '';
  String sortMode = 'Recommended Order';
  @override
  Widget build(BuildContext context) {
    final groups = CinematicDiscoveryLogic.franchiseGroups(
        AppController.instance.library,
        sortMode: sortMode);
    final entries = groups.entries
        .where((entry) =>
            entry.key.toLowerCase().contains(filter.toLowerCase()) ||
            entry.value.any(
                (m) => m.title.toLowerCase().contains(filter.toLowerCase())))
        .toList();
    return Scaffold(
        backgroundColor: _cinemaBg,
        appBar: AppBar(
            title: const Text('Franchise Navigator'),
            backgroundColor: _cinemaBg),
        body: Column(children: [
          Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                TextField(
                    onChanged: (v) => setState(() => filter = v),
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search franchise or title')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                    initialValue: sortMode,
                    decoration:
                        const InputDecoration(labelText: 'Viewing order'),
                    items: const ['Recommended Order', 'Release Year', 'Title']
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => sortMode = v);
                    }),
              ])),
          Expanded(
              child: entries.isEmpty
                  ? const _DiscoveryEmpty(
                      message:
                          'No franchise relationships are available. Add franchise metadata or relationship links during catalog import.')
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: entries
                          .map((entry) => Card(
                              color: _cinemaPanel,
                              child: ExpansionTile(
                                iconColor: _cinemaAccent,
                                collapsedIconColor: Colors.white60,
                                title: Text(entry.key,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800)),
                                subtitle: Text(
                                    '${entry.value.length} connected title${entry.value.length == 1 ? '' : 's'}',
                                    style:
                                        const TextStyle(color: Colors.white60)),
                                children: entry.value
                                    .map((item) => _MediaResultTile(
                                        item: item,
                                        subtitle:
                                            '${item.releaseYear ?? 'Year unknown'} • ${GenreSystem.displayLabel(item.genres)}'))
                                    .toList(),
                              )))
                          .toList())),
        ]));
  }
}

class PremiereEvent {
  final String id;
  final String title;
  final DateTime date;
  final String kind;
  final String notes;
  const PremiereEvent(
      {required this.id,
      required this.title,
      required this.date,
      required this.kind,
      required this.notes});
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'date': date.toIso8601String(),
        'kind': kind,
        'notes': notes
      };
  static PremiereEvent? fromJson(dynamic value) {
    if (value is! Map) return null;
    final date = DateTime.tryParse(value['date']?.toString() ?? '');
    final title = value['title']?.toString().trim() ?? '';
    if (date == null || title.isEmpty) return null;
    return PremiereEvent(
        id: value['id']?.toString() ??
            '${title}_${date.millisecondsSinceEpoch}',
        title: title,
        date: date,
        kind: value['kind']?.toString() ?? 'Reminder',
        notes: value['notes']?.toString() ?? '');
  }
}

class PremiereCalendarScreen extends StatefulWidget {
  const PremiereCalendarScreen({super.key});
  @override
  State<PremiereCalendarScreen> createState() => _PremiereCalendarScreenState();
}

class _PremiereCalendarScreenState extends State<PremiereCalendarScreen> {
  List<PremiereEvent> events = <PremiereEvent>[];
  bool loading = true;
  String get _storageKey =>
      'premiere_calendar_v1_${AppController.instance.currentProfile?.id ?? 'guest'}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      final decoded =
          raw == null ? <dynamic>[] : jsonDecode(raw) as List<dynamic>;
      final loaded = decoded
          .map(PremiereEvent.fromJson)
          .whereType<PremiereEvent>()
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      if (mounted) {
        setState(() {
          events = loaded;
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          events = <PremiereEvent>[];
          loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _storageKey, jsonEncode(events.map((e) => e.toJson()).toList()));
  }

  Future<void> _addEvent() async {
    final title = TextEditingController();
    final notes = TextEditingController();
    DateTime date = DateTime.now().add(const Duration(days: 7));
    String kind = 'Premiere';
    final event = await showDialog<PremiereEvent>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (context, refresh) => AlertDialog(
                  title: const Text('Add calendar reminder'),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(
                        controller: title,
                        autofocus: true,
                        decoration: const InputDecoration(
                            labelText: 'Title or event name')),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                        initialValue: kind,
                        decoration:
                            const InputDecoration(labelText: 'Event type'),
                        items: const [
                          'Premiere',
                          'New Episode',
                          'Live Event',
                          'Service Arrival',
                          'Service Leaving',
                          'Watch Party',
                          'Reminder'
                        ]
                            .map((v) =>
                                DropdownMenuItem(value: v, child: Text(v)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) refresh(() => kind = v);
                        }),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                              context: context,
                              initialDate: date,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100));
                          if (picked != null) refresh(() => date = picked);
                        },
                        icon: const Icon(Icons.calendar_month),
                        label: Text('Date: ${_formatDate(date)}')),
                    TextField(
                        controller: notes,
                        maxLines: 2,
                        decoration: const InputDecoration(
                            labelText: 'Notes or source (optional)')),
                  ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () {
                          final text = title.text.trim();
                          if (text.isEmpty) return;
                          Navigator.pop(
                              dialogContext,
                              PremiereEvent(
                                  id: '${DateTime.now().microsecondsSinceEpoch}',
                                  title: text,
                                  date: date,
                                  kind: kind,
                                  notes: notes.text.trim()));
                        },
                        child: const Text('Save reminder'))
                  ],
                )));
    title.dispose();
    notes.dispose();
    if (event == null || !mounted) return;
    setState(() {
      events.add(event);
      events.sort((a, b) => a.date.compareTo(b.date));
    });
    await _save();
  }

  Future<void> _remove(PremiereEvent event) async {
    setState(() => events.removeWhere((e) => e.id == event.id));
    await _save();
  }

  static String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: _cinemaBg,
      appBar: AppBar(
          title: const Text('Personal Premiere Calendar'),
          backgroundColor: _cinemaBg,
          actions: [
            IconButton(
                onPressed: _addEvent,
                tooltip: 'Add reminder',
                icon: const Icon(Icons.add))
          ]),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              const Text('Keep your entertainment plans together.',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text(
                  'Reminders are stored on this device for the current profile. Official release dates, provider arrival/expiry data and event invitations are not fetched automatically.',
                  style: TextStyle(color: Colors.white60)),
              const SizedBox(height: 14),
              if (events.isEmpty)
                const _DiscoveryEmpty(
                    message:
                        'No reminders yet. Add a premiere, new-episode date, live event or watch-party plan.'),
              ...events.map((event) => Card(
                  color: _cinemaPanel,
                  child: ListTile(
                    leading: CircleAvatar(
                        backgroundColor: _cinemaAccent.withValues(alpha: .15),
                        child: const Icon(Icons.event, color: _cinemaAccent)),
                    title: Text(event.title,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                    subtitle: Text(
                        '${_formatDate(event.date)} • ${event.kind}${event.notes.isEmpty ? '' : '\n${event.notes}'}',
                        style: const TextStyle(color: Colors.white60)),
                    isThreeLine: event.notes.isNotEmpty,
                    trailing: IconButton(
                        tooltip: 'Delete reminder',
                        onPressed: () => _remove(event),
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.white54)),
                  ))),
              const SizedBox(height: 8),
              FilledButton.icon(
                  onPressed: _addEvent,
                  icon: const Icon(Icons.add),
                  label: const Text('Add reminder')),
            ]));
}

class EntertainmentVaultScreen extends StatefulWidget {
  const EntertainmentVaultScreen({super.key});
  @override
  State<EntertainmentVaultScreen> createState() =>
      _EntertainmentVaultScreenState();
}

class _EntertainmentVaultScreenState extends State<EntertainmentVaultScreen> {
  String filter = 'Everything';
  @override
  Widget build(BuildContext context) {
    final c = AppController.instance;
    final library = c.library;
    final items = library.where((m) {
      switch (filter) {
        case 'Physical discs':
          return m.discType != null ||
              m.discCollectionId != null ||
              m.discTitleId != null;
        case 'Playable URLs':
          return (m.playbackUrl ?? '').trim().isNotEmpty;
        case 'Favorites':
          return c.isLiked(m.id);
        case 'Watched':
          return c.isWatched(m.id);
        case 'Unwatched':
          return !c.isWatched(m.id);
        case 'In progress':
          final p = c.getPlaybackProgress(m.id);
          return p > 0 && p < 0.95;
        default:
          return true;
      }
    }).toList();
    return Scaffold(
        backgroundColor: _cinemaBg,
        appBar: AppBar(
            title: const Text('My Entertainment Vault'),
            backgroundColor: _cinemaBg),
        body: Column(children: [
          Padding(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<String>(
                  initialValue: filter,
                  decoration: const InputDecoration(labelText: 'Show me'),
                  items: const [
                    'Everything',
                    'Physical discs',
                    'Playable URLs',
                    'Favorites',
                    'Watched',
                    'Unwatched',
                    'In progress'
                  ]
                      .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => filter = v);
                  })),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('${items.length} catalog items',
                      style: const TextStyle(color: Colors.white60)))),
          Expanded(
              child: items.isEmpty
                  ? const _DiscoveryEmpty(
                      message: 'No catalog items match this vault filter yet.')
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      itemBuilder: (_, i) => _MediaResultTile(
                          item: items[i],
                          subtitle:
                              '${GenreSystem.displayLabel(items[i].genres)}\n${items[i].discType != null ? 'Physical media' : (items[i].playbackUrl?.trim().isNotEmpty == true ? 'Playback URL available' : 'Catalog metadata only')}'))),
        ]));
  }
}

class MediaWrappedScreen extends StatelessWidget {
  const MediaWrappedScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final c = AppController.instance;
    final watched = c.watched;
    final genres = <String, int>{};
    final hybrids = <String, int>{};
    final actors = <String, int>{};
    final directors = <String, int>{};
    final franchises = <String, int>{};
    for (final item in watched) {
      final normalizedGenres = GenreSystem.normalizeGenres(item.genres);
      final components = <String>{
        for (final genre in normalizedGenres)
          ...GenreSystem.componentsFor(genre),
      };
      for (final genre in components) {
        genres[genre] = (genres[genre] ?? 0) + 1;
      }
      if (components.length > 1) {
        final label = GenreSystem.displayLabel(components);
        if (!label.contains(' • ')) hybrids[label] = (hybrids[label] ?? 0) + 1;
      }
      for (final actor in item.actors) {
        actors[actor] = (actors[actor] ?? 0) + 1;
      }
      for (final director in item.directors) {
        directors[director] = (directors[director] ?? 0) + 1;
      }
      final franchise = (item.franchiseName ?? '').trim();
      if (franchise.isNotEmpty) {
        franchises[franchise] = (franchises[franchise] ?? 0) + 1;
      }
    }
    List<MapEntry<String, int>> ranked(Map<String, int> map) {
      final list = map.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return list.take(6).toList();
    }

    Widget section(
            String title, IconData icon, List<MapEntry<String, int>> values) =>
        Card(
          color: _cinemaPanel,
          child: ExpansionTile(
            leading: Icon(icon, color: _cinemaAccent),
            title: Text(title,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
            children: values.isEmpty
                ? const [
                    ListTile(
                        title: Text('Not enough catalog/history metadata yet.',
                            style: TextStyle(color: Colors.white54)))
                  ]
                : values
                    .map((entry) => ListTile(
                          title: Text(entry.key,
                              style: const TextStyle(color: Colors.white70)),
                          trailing: Text('${entry.value}',
                              style: const TextStyle(color: Colors.white54)),
                        ))
                    .toList(),
          ),
        );

    return Scaffold(
        backgroundColor: _cinemaBg,
        appBar: AppBar(
            title: const Text('My Media Wrapped'), backgroundColor: _cinemaBg),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Your taste, from your own history.',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text(
              'This recap uses currently recorded watch history. It does not track time spent unless the source provides that metric.',
              style: TextStyle(color: Colors.white60)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: _WrappedStat(
                    label: 'Watched titles', value: '${watched.length}')),
            const SizedBox(width: 10),
            Expanded(
                child: _WrappedStat(
                    label: 'Catalog size', value: '${c.library.length}'))
          ]),
          const SizedBox(height: 12),
          section(
              'Your favorite genres', Icons.category_outlined, ranked(genres)),
          section(
              'Your hybrid genres', Icons.merge_type_rounded, ranked(hybrids)),
          section('Actors you watch most', Icons.person_outline_rounded,
              ranked(actors)),
          section('Directors you watch most', Icons.movie_filter_outlined,
              ranked(directors)),
          section('Franchises you revisit', Icons.account_tree_outlined,
              ranked(franchises)),
        ]));
  }
}

class WatchConciergeScreen extends StatefulWidget {
  const WatchConciergeScreen({super.key});
  @override
  State<WatchConciergeScreen> createState() => _WatchConciergeScreenState();
}

class _WatchConciergeScreenState extends State<WatchConciergeScreen> {
  final TextEditingController query = TextEditingController();
  List<MediaItem> results = <MediaItem>[];
  String lastQuery = '';
  void search() {
    final q = query.text.trim();
    setState(() {
      lastQuery = q;
      results = CinematicDiscoveryLogic.conciergeSearch(
          q, AppController.instance.library);
    });
  }

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: _cinemaBg,
      appBar: AppBar(
          title: const Text('Hey Media Watch Concierge'),
          backgroundColor: _cinemaBg),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Tell me what you feel like watching.',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w800))),
              const SizedBox(height: 6),
              const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                      'Examples: “funny horror movies”, “romantic thriller”, “dark mysteries”. Matching is based on local catalog metadata.',
                      style: TextStyle(color: Colors.white60))),
              const SizedBox(height: 12),
              TextField(
                  controller: query,
                  onSubmitted: (_) => search(),
                  decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.auto_awesome),
                      hintText: 'What do you want to watch?',
                      suffixIcon: IconButton(
                          onPressed: search, icon: const Icon(Icons.search)))),
              const SizedBox(height: 8),
              Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                      onPressed: search,
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Find titles'))),
            ])),
        const Divider(height: 1, color: Colors.white12),
        Expanded(
            child: lastQuery.isEmpty
                ? const _DiscoveryEmpty(
                    message:
                        'Try a mood, one genre, or a combination such as Horror + Comedy.')
                : results.isEmpty
                    ? const _DiscoveryEmpty(
                        message:
                            'No matching titles were found in the current catalog. Try a broader mood or genre.')
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: results.length,
                        itemBuilder: (_, i) => _MediaResultTile(
                            item: results[i],
                            subtitle:
                                GenreSystem.displayLabel(results[i].genres)))),
      ]));
}

class CinematicUniversalSearchScreen extends StatefulWidget {
  const CinematicUniversalSearchScreen({super.key});
  @override
  State<CinematicUniversalSearchScreen> createState() =>
      _CinematicUniversalSearchScreenState();
}

class _CinematicUniversalSearchScreenState
    extends State<CinematicUniversalSearchScreen> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final results = SmartSearch.search(query, AppController.instance.library);
    return Scaffold(
        backgroundColor: _cinemaBg,
        appBar: AppBar(
            title: const Text('Universal Catalog Search'),
            backgroundColor: _cinemaBg),
        body: Column(children: [
          Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                  onChanged: (v) => setState(() => query = v),
                  autofocus: true,
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText:
                          'Title, actor, genre, franchise, soundtrack…'))),
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                      'Search scope: current entertainment catalog. Shop, food delivery, friends and external streaming providers require their own connected data sources.',
                      style: TextStyle(color: Colors.white54, fontSize: 12)))),
          Expanded(
              child: query.trim().isEmpty
                  ? const _DiscoveryEmpty(
                      message:
                          'Search available movies, shows and imported catalog metadata.')
                  : results.isEmpty
                      ? const _DiscoveryEmpty(
                          message: 'No catalog matches were found.')
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: results.length,
                          itemBuilder: (_, i) => _MediaResultTile(
                              item: results[i],
                              subtitle:
                                  '${results[i].releaseYear ?? 'Year unknown'} • ${GenreSystem.displayLabel(results[i].genres)}'))),
        ]));
  }
}

class XRayCatalogPickerScreen extends StatefulWidget {
  const XRayCatalogPickerScreen({super.key});

  @override
  State<XRayCatalogPickerScreen> createState() =>
      _XRayCatalogPickerScreenState();
}

class _XRayCatalogPickerScreenState extends State<XRayCatalogPickerScreen> {
  final TextEditingController query = TextEditingController();
  final ValueNotifier<Duration> playbackPosition =
      ValueNotifier<Duration>(Duration.zero);

  @override
  void dispose() {
    query.dispose();
    playbackPosition.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = query.text.trim().toLowerCase();
    final items = AppController.instance.library.where((item) {
      if (q.isEmpty) return true;
      return <String>[
        item.title,
        item.description ?? '',
        ...item.genres,
        ...item.actors,
        ...item.directors,
      ].join(' ').toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: _cinemaBg,
      appBar: AppBar(
        title: const Text('X-Ray Story Explorer'),
        backgroundColor: _cinemaBg,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: query,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Find a title by name, genre or cast',
              ),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const _DiscoveryEmpty(
                    message: 'No catalog titles match this X-Ray search.',
                  )
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Card(
                        color: _cinemaPanel,
                        child: ListTile(
                          title: Text(
                            item.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            GenreSystem.displayLabel(item.genres),
                            style: const TextStyle(color: Colors.white60),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white54,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => XRayScreen(
                                  media: item,
                                  playbackPosition: playbackPosition,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _MediaResultTile extends StatelessWidget {
  final MediaItem item;
  final String subtitle;
  const _MediaResultTile({required this.item, required this.subtitle});
  @override
  Widget build(BuildContext context) => Card(
      color: _cinemaPanel,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
                width: 48,
                height: 68,
                child: (item.imageUrl ?? '').trim().isEmpty
                    ? const ColoredBox(
                        color: Colors.black26,
                        child:
                            Icon(Icons.movie_outlined, color: Colors.white54))
                    : Image.network(item.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const ColoredBox(
                            color: Colors.black26,
                            child: Icon(Icons.movie_outlined,
                                color: Colors.white54))))),
        title: Text(item.title,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white60)),
        trailing: const Icon(Icons.chevron_right, color: Colors.white54),
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
                builder: (_) => MediaDetailsScreen(media: item))),
      ));
}

class _PairMovie extends StatelessWidget {
  final MediaItem item;
  const _PairMovie({required this.item});
  @override
  Widget build(BuildContext context) => Row(children: [
        ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
                width: 50,
                height: 70,
                child: (item.imageUrl ?? '').trim().isEmpty
                    ? const ColoredBox(
                        color: Colors.black26,
                        child:
                            Icon(Icons.movie_outlined, color: Colors.white54))
                    : Image.network(item.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const ColoredBox(
                            color: Colors.black26,
                            child: Icon(Icons.movie_outlined,
                                color: Colors.white54))))),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.title,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(
              '${item.releaseYear ?? 'Year unknown'} • ${GenreSystem.displayLabel(item.genres)}',
              style: const TextStyle(color: Colors.white60))
        ])),
        Text(item.rating == null ? '—' : item.rating!.toStringAsFixed(1),
            style: const TextStyle(
                color: _cinemaAccent, fontWeight: FontWeight.w800)),
      ]);
}

class _WrappedStat extends StatelessWidget {
  final String label;
  final String value;
  const _WrappedStat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: _cinemaPanel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 27)),
        Text(label, style: const TextStyle(color: Colors.white60))
      ]));
}

class _DiscoveryEmpty extends StatelessWidget {
  final String message;
  const _DiscoveryEmpty({required this.message});
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.auto_awesome_mosaic_rounded,
                size: 42, color: Colors.white30),
            const SizedBox(height: 10),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, height: 1.4))
          ])));
}
