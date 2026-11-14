import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_core.dart';
import 'backend_api.dart';
import 'details.dart';
import 'media_universe.dart';
import 'recommendation_ownership.dart';
import 'recommendation_preferences.dart';
import 'performer_universe.dart';

/// A single entry point for the shared recommendation graph. Entity shelves
/// use only metadata already indexed in the catalog; missing credits are not
/// fabricated and external-only titles require catalog ingestion first.
class DiscoveryCenterScreen extends StatefulWidget {
  const DiscoveryCenterScreen({super.key});

  @override
  State<DiscoveryCenterScreen> createState() => _DiscoveryCenterScreenState();
}

class _DiscoveryCenterScreenState extends State<DiscoveryCenterScreen> {
  final AppController _controller = AppController.instance;
  RecommendationPreferences _preferences = const RecommendationPreferences();
  String? _activeCategory;
  String? _activeEntity;
  bool _loadingPreferences = true;
  bool _savingPreferences = false;
  String? _preferenceError;
  String? _observedProfileId;

  @override
  void initState() {
    super.initState();
    _observedProfileId = _profileId;
    _controller.addListener(_onControllerChanged);
    unawaited(_load());
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    final profileId = _profileId;
    if (profileId != _observedProfileId) {
      _observedProfileId = profileId;
      unawaited(_load());
    }
    if (mounted) setState(() {});
  }

  String get _profileId =>
      _controller.currentProfile?.id.trim().isNotEmpty == true
          ? _controller.currentProfile!.id.trim()
          : 'local';

  Future<void> _load() async {
    await _loadPreferences();
    if (_controller.backendApi.isAuthenticated) {
      await _controller.loadRecommendations();
    }
  }

  Future<void> _loadPreferences() async {
    setState(() {
      _loadingPreferences = true;
      _preferenceError = null;
    });
    try {
      if (_controller.backendApi.isAuthenticated && _profileId != 'local') {
        final response =
            await _controller.backendApi.getRecommendationPreferences(
          profileId: _profileId,
        );
        _preferences =
            RecommendationPreferences.fromJson(response['preferences']);
      } else {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('moss_discovery_preferences_$_profileId');
        if (raw != null) {
          _preferences = RecommendationPreferences.fromJson(jsonDecode(raw));
        }
      }
    } catch (error) {
      _preferenceError = 'Could not load saved discovery settings: $error';
    } finally {
      if (mounted) setState(() => _loadingPreferences = false);
    }
  }

  Future<void> _savePreferences(RecommendationPreferences next) async {
    setState(() {
      _preferences = next;
      _savingPreferences = true;
      _preferenceError = null;
    });
    try {
      if (_controller.backendApi.isAuthenticated && _profileId != 'local') {
        await _controller.backendApi.updateRecommendationPreferences(
          profileId: _profileId,
          preferences: next.toJson(),
        );
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'moss_discovery_preferences_$_profileId',
          jsonEncode(next.toJson()),
        );
      }
    } catch (error) {
      _preferenceError = 'Could not save discovery settings: $error';
    } finally {
      if (mounted) setState(() => _savingPreferences = false);
    }
  }

  List<MediaItem> get _visibleLibrary => _controller.library
      .where((item) => item.isAccessibleTo(_controller.currentProfile))
      .where((item) => !isExcludedEntertainmentType(item.type))
      .toList(growable: false);

  String _key(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  List<String> _unique(Iterable<String> values) => values
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .fold<Map<String, String>>(<String, String>{}, (map, value) {
        map.putIfAbsent(_key(value), () => value);
        return map;
      })
      .values
      .toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  List<String> _entitiesFor(String category) {
    final items = _visibleLibrary;
    switch (category) {
      case 'performers':
        return _unique(items.expand((item) => <String>[
              ...item.actors,
              ...item.music,
            ]));
      case 'studios':
        return _unique(items.expand((item) => <String>[
              ...item.studios,
              ...item.companies,
            ]));
      case 'creators':
        return _unique(items.expand((item) => <String>[
              ...item.directors,
              ...item.writers,
              ...item.music,
            ]));
      case 'characters':
        return _unique(items.expand((item) => item.characters));
      case 'stories':
        return _unique(items.expand((item) => <String>[
              ...item.genres,
              ...item.tags,
              ...item.themes,
            ]));
      case 'franchises':
        return _unique(items.expand((item) => <String>[
              if (item.franchiseName != null) item.franchiseName!,
              ...item.franchiseNames,
              ...item.cinematicUniverseNames,
            ]));
      case 'adaptations':
        return _unique(items
            .map(
                (item) => item.adaptationGroupName ?? item.originalAuthor ?? '')
            .where((value) => value.trim().isNotEmpty));
      case 'soundtracks':
        return _unique(items.expand((item) => <String>[...item.music]));
      case 'moodEra':
        return _unique(items.expand((item) => <String>[
              ...item.genres,
              ...item.tags,
              ...item.themes,
              ...item.tones,
              if (item.releaseYear != null)
                '${(item.releaseYear! ~/ 10) * 10}s',
            ]));
      case 'world':
        return _unique(items.expand((item) => <String>[
              if (item.countryOfOrigin != null) item.countryOfOrigin!,
              if (item.originalLanguage != null) item.originalLanguage!,
              if (item.language != null) item.language!,
              ...item.culturalSettings,
              ...item.culturalInspirations,
            ]));
      case 'hidden':
        final counts = <String, int>{};
        for (final item in items) {
          for (final name in <String>[
            ...item.actors,
            ...item.directors,
            ...item.writers,
            ...item.music
          ]) {
            final key = _key(name);
            if (key.isNotEmpty) counts[key] = (counts[key] ?? 0) + 1;
          }
        }
        return _unique(items.expand((item) => <String>[
              ...item.actors,
              ...item.directors,
              ...item.writers,
              ...item.music,
            ])).where((name) => (counts[_key(name)] ?? 0) >= 2).toList();
      case 'awards':
        return _unique(items.expand((item) => item.externalRatings
            .where((rating) =>
                rating['award'] != null || rating['awardName'] != null)
            .map((rating) =>
                (rating['award'] ?? rating['awardName']).toString())));
      case 'trails':
        return _unique(items.expand((item) => item.graphRelationships
            .map((relationship) => relationship.relationshipType)));
      case 'taste':
        return _unique(items.expand(
            (item) => <String>[...item.genres, ...item.tags, ...item.themes]));
      default:
        return const <String>[];
    }
  }

  List<MediaItem> _itemsForEntity(String category, String entity) {
    final key = _key(entity);
    return _visibleLibrary.where((item) {
      Iterable<String> values;
      switch (category) {
        case 'performers':
        case 'soundtracks':
          values = <String>[...item.actors, ...item.music];
          break;
        case 'studios':
          values = <String>[...item.studios, ...item.companies];
          break;
        case 'creators':
          values = <String>[...item.directors, ...item.writers, ...item.music];
          break;
        case 'characters':
          values = item.characters;
          break;
        case 'stories':
        case 'taste':
        case 'moodEra':
          values = <String>[
            ...item.genres,
            ...item.tags,
            ...item.themes,
            ...item.tones,
            if (item.releaseYear != null) '${(item.releaseYear! ~/ 10) * 10}s',
          ];
          break;
        case 'franchises':
          values = <String>[
            item.franchiseName ?? '',
            ...item.franchiseNames,
            ...item.cinematicUniverseNames,
          ];
          break;
        case 'adaptations':
          values = <String>[
            item.adaptationGroupName ?? '',
            item.originalAuthor ?? ''
          ];
          break;
        case 'world':
          values = <String>[
            item.countryOfOrigin ?? '',
            item.originalLanguage ?? '',
            item.language ?? '',
            ...item.culturalSettings,
            ...item.culturalInspirations,
          ];
          break;
        case 'hidden':
          values = <String>[
            ...item.actors,
            ...item.directors,
            ...item.writers,
            ...item.music
          ];
          break;
        case 'awards':
          values = item.externalRatings.map((rating) =>
              (rating['award'] ?? rating['awardName'] ?? '').toString());
          break;
        case 'trails':
          values = item.graphRelationships
              .map((relationship) => relationship.relationshipType);
          break;
        default:
          values = const <String>[];
      }
      return values.any((value) => _key(value) == key);
    }).toList(growable: false);
  }

  Future<void> _feedback(MediaItem media, String action) async {
    try {
      await _controller.backendApi.saveRecommendationFeedback(
        profileId: _profileId,
        mediaId: media.id,
        action: action,
      );
      await _controller.loadRecommendations();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your discovery feedback was saved.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save feedback: $error')),
        );
      }
    }
  }

  void _openMedia(MediaItem media) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/app/page/discovery-title'),
      builder: (_) => MediaDetailsScreen(media: media),
    ));
  }

  static const _categories =
      <({String id, String title, String subtitle, IconData icon})>[
    (
      id: 'performers',
      title: 'Performer Universe',
      subtitle:
          'Actors, voice performers, singers, musicians and credited collaborators',
      icon: Icons.theater_comedy_rounded
    ),
    (
      id: 'studios',
      title: 'Studios',
      subtitle: 'Explore production studios and company catalogs',
      icon: Icons.movie_filter_rounded
    ),
    (
      id: 'creators',
      title: 'Creators & Collaborators',
      subtitle: 'Directors, writers, composers and recurring teams',
      icon: Icons.groups_rounded
    ),
    (
      id: 'characters',
      title: 'Character Discovery',
      subtitle: 'Find characters across titles and connected stories',
      icon: Icons.face_retouching_natural_rounded
    ),
    (
      id: 'stories',
      title: 'Story & Theme Discovery',
      subtitle: 'Themes, plot devices, subgenres and tone tags',
      icon: Icons.auto_stories_rounded
    ),
    (
      id: 'franchises',
      title: 'Franchises & Universes',
      subtitle: 'Sequels, prequels, spin-offs and connected timelines',
      icon: Icons.account_tree_rounded
    ),
    (
      id: 'adaptations',
      title: 'Adaptations',
      subtitle: 'Books, games, comics and inspired-by connections',
      icon: Icons.menu_book_rounded
    ),
    (
      id: 'soundtracks',
      title: 'Song-to-Screen',
      subtitle: 'Music credits, soundtrack links and performers',
      icon: Icons.library_music_rounded
    ),
    (
      id: 'moodEra',
      title: 'Mood & Decade',
      subtitle: 'Explore by feeling, genre, era and release decade',
      icon: Icons.mood_rounded
    ),
    (
      id: 'world',
      title: 'World Cinema & Cultures',
      subtitle:
          'Production origin and language; cultural links only when indexed',
      icon: Icons.public_rounded
    ),
    (
      id: 'hidden',
      title: 'Hidden Connections',
      subtitle: 'People and collaborators appearing across your library',
      icon: Icons.hub_rounded
    ),
    (
      id: 'awards',
      title: 'Awards & Recognition',
      subtitle: 'Award data appears when verified catalog credits exist',
      icon: Icons.emoji_events_rounded
    ),
    (
      id: 'trails',
      title: 'Recommendation Trails',
      subtitle: 'Follow verified relationship types through your catalog',
      icon: Icons.route_rounded
    ),
    (
      id: 'taste',
      title: 'Your Entertainment DNA',
      subtitle: 'A live map of your genres, themes and recurring interests',
      icon: Icons.psychology_rounded
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final visibleCategories = _categories
        .where((item) => _preferences.enabledSections.contains(item.id))
        .toList();
    final activeCategories =
        visibleCategories.where((item) => item.id == _activeCategory).toList();
    final activeCategory =
        activeCategories.isEmpty ? null : activeCategories.first;
    final entities = _activeCategory == null
        ? const <String>[]
        : _entitiesFor(_activeCategory!);
    final matching = activeCategory == null || _activeEntity == null
        ? const <MediaItem>[]
        : _itemsForEntity(activeCategory.id, _activeEntity!);
    return Scaffold(
      backgroundColor: const Color(0xFF090B12),
      appBar: AppBar(
        title: const Text('Discovery Center'),
        backgroundColor: const Color(0xFF10131E),
        actions: [
          IconButton(
            tooltip: 'Open the interactive Media Universe graph',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const MediaUniverseScreen(),
            )),
            icon: const Icon(Icons.hub_rounded),
          ),
          IconButton(
            tooltip: 'Compare two titles',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const DiscoveryTitleComparisonScreen(),
            )),
            icon: const Icon(Icons.compare_arrows_rounded),
          ),
          IconButton(
            tooltip: 'Refresh recommendations',
            onPressed: _controller.recommendationsLoading
                ? null
                : () => _controller.loadRecommendations(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        children: [
          _hero(),
          const SizedBox(height: 18),
          if (_preferences.enabledSections.contains('forYou')) ...[
            _recommendationsSection(),
            const SizedBox(height: 20),
          ],
          _preferencesSection(),
          const SizedBox(height: 22),
          const Text('Explore the relationship graph',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text(
              'These destinations use the shared catalog graph. Results are limited to relationships and credits that have actually been indexed.',
              style: TextStyle(color: Colors.white60, height: 1.4)),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, constraints) {
            final columns = constraints.maxWidth > 900
                ? 3
                : constraints.maxWidth > 560
                    ? 2
                    : 1;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visibleCategories.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                mainAxisExtent: 114,
              ),
              itemBuilder: (context, index) =>
                  _categoryCard(visibleCategories[index]),
            );
          }),
          if (activeCategory != null) ...[
            const SizedBox(height: 20),
            _selectedCategoryPanel(activeCategory, entities, matching),
          ],
        ],
      ),
    );
  }

  Widget _hero() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            colors: [Color(0xFF26234C), Color(0xFF132D42), Color(0xFF141923)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withValues(alpha: .09)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Your entertainment, connected.',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
          const SizedBox(height: 7),
          const Text(
              'Discover across movies, television and music through shared performers, studios, stories, characters, soundtracks and cultural connections.',
              style: TextStyle(color: Colors.white70, height: 1.45)),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _pill('${_preferences.familiarPercent}% familiar',
                const Color(0xFF70B7FF)),
            _pill('${_preferences.unexpectedPercent}% unexpected',
                const Color(0xFFC5A1FF)),
            _pill(
                _preferences.includeLibraryItems &&
                        _preferences.includeExternalItems
                    ? 'Library + catalog'
                    : _preferences.includeLibraryItems
                        ? 'Library only'
                        : _preferences.includeExternalItems
                            ? 'Catalog only'
                            : 'No recommendation sources',
                const Color(0xFF8BD9B2)),
          ]),
        ]),
      );

  Widget _pill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: color.withValues(alpha: .6))),
        child: Text(text,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w800, fontSize: 11)),
      );

  Widget _recommendationsSection() {
    final items = _controller.recommendations;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Expanded(
            child: Text('For You',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
        if (_controller.recommendationsLoading)
          const SizedBox(
              width: 17,
              height: 17,
              child: CircularProgressIndicator(strokeWidth: 2)),
      ]),
      const SizedBox(height: 5),
      const Text(
          'A profile-specific mix of rediscovery and new-to-you titles. Match estimates describe catalog similarity, not guaranteed personal enjoyment.',
          style: TextStyle(color: Colors.white60, height: 1.4)),
      const SizedBox(height: 10),
      if (_controller.recommendationsError != null)
        _messageCard(_controller.recommendationsError!),
      if (items.isEmpty && !_controller.recommendationsLoading)
        _messageCard(_controller.backendApi.isAuthenticated
            ? 'No recommendations are available yet. Add or watch titles with reliable metadata, then refresh.'
            : 'Sign in to load account recommendations. Local catalog exploration remains available below.'),
      ...items.take(12).toList().asMap().entries.map((entry) {
        final media = entry.value;
        final detail = entry.key < _controller.recommendationDetails.length
            ? _controller.recommendationDetails[entry.key]
            : const <String, dynamic>{};
        final rawMatch = detail['matchPercentage'];
        final match = rawMatch is num
            ? rawMatch.toDouble()
            : double.tryParse(rawMatch?.toString() ?? '');
        final discoveryType = detail['discoveryType']?.toString() ?? 'familiar';
        final reasons = detail['reasons'] is List
            ? (detail['reasons'] as List).whereType<Map>().toList()
            : const <Map>[];
        final householdReason = reasons
            .where((reason) =>
                reason['title']?.toString().startsWith('Watched by ') == true)
            .toList();
        final explanationReasons =
            householdReason.isNotEmpty ? householdReason : reasons;
        final explanation = explanationReasons.isEmpty
            ? 'Related through available catalog metadata.'
            : explanationReasons
                .take(2)
                .map((reason) => reason['description']?.toString() ?? '')
                .where((value) => value.isNotEmpty)
                .join(' ');
        final isOwned = detail['isInLibrary'] == true;
        final isWatched = detail['isWatched'] == true;
        return Card(
          color: const Color(0xFF151A27),
          margin: const EdgeInsets.only(bottom: 9),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: () => _openMedia(media),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: SizedBox(
                      width: 68,
                      height: 96,
                      child: media.imageUrl?.startsWith('http') == true
                          ? Image.network(media.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _posterFallback(media.title))
                          : _posterFallback(media.title)),
                ),
                const SizedBox(width: 11),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(media.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(
                          '${media.type}${media.releaseYear == null ? '' : ' · ${media.releaseYear}'}',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 11)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 5, runSpacing: 5, children: [
                        RecommendationOwnershipBadge(
                            isOwned: isOwned,
                            isWatched: isWatched,
                            compact: true),
                        _pill(
                            discoveryType == 'unexpected'
                                ? 'Unexpected'
                                : 'Familiar',
                            discoveryType == 'unexpected'
                                ? const Color(0xFFC5A1FF)
                                : const Color(0xFF70B7FF)),
                        if (match != null)
                          _pill('${match.toStringAsFixed(0)}% catalog match',
                              const Color(0xFF8BD9B2)),
                      ]),
                      if (_preferences.explainRecommendations) ...[
                        const SizedBox(height: 6),
                        Text(explanation,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                                height: 1.3)),
                      ],
                    ])),
                PopupMenuButton<String>(
                  tooltip: 'Give feedback',
                  onSelected: (action) => _feedback(media, action),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                        value: 'moreLikeThis', child: Text('More like this')),
                    PopupMenuItem(
                        value: 'notInterested', child: Text('Not interested')),
                    PopupMenuItem(
                        value: 'alreadyWatched',
                        child: Text('Already watched')),
                    PopupMenuItem(
                        value: 'likeActorNotGenre',
                        child: Text('Like the performer, not the genre')),
                    PopupMenuItem(
                        value: 'likeStoryNotTone',
                        child: Text('Like the story, not the tone')),
                    PopupMenuItem(
                        value: 'notPreferredGenre',
                        child: Text('Not my preferred genre')),
                    PopupMenuItem(
                        value: 'stopShowing',
                        child: Text('Stop showing this title')),
                  ],
                ),
              ]),
            ),
          ),
        );
      }),
    ]);
  }

  Widget _preferencesSection() => Card(
        color: const Color(0xFF131824),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(
                  child: Text('Discovery Preferences',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900))),
              if (_savingPreferences || _loadingPreferences)
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
            ]),
            const SizedBox(height: 6),
            Text(
                '${_preferences.familiarPercent}% familiar · ${_preferences.unexpectedPercent}% unexpected',
                style: const TextStyle(color: Colors.white70)),
            Slider(
              value: _preferences.familiarPercent.toDouble(),
              min: 0,
              max: 100,
              divisions: 20,
              label: '${_preferences.familiarPercent}% familiar',
              onChanged: (value) => setState(() => _preferences =
                  _preferences.copyWith(familiarPercent: value.round())),
              onChangeEnd: (_) => _savePreferences(_preferences),
            ),
            _switch(
                'Include titles already in my library',
                _preferences.includeLibraryItems,
                (value) => _updatePreference(includeLibraryItems: value)),
            _switch(
                'Include titles outside my library',
                _preferences.includeExternalItems,
                (value) => _updatePreference(includeExternalItems: value)),
            _switch(
                'Include partially watched titles for rediscovery',
                _preferences.includeWatchedItems,
                (value) => _updatePreference(includeWatchedItems: value)),
            _switch('Allow rewatches', _preferences.includeRewatches,
                (value) => _updatePreference(includeRewatches: value)),
            _switch(
                'Explain why each item was recommended',
                _preferences.explainRecommendations,
                (value) => _updatePreference(explainRecommendations: value)),
            _switch(
                'Avoid spoilers in discovery explanations',
                _preferences.spoilerSafe,
                (value) => _updatePreference(spoilerSafe: value)),
            _switch('Exclude titles I disliked', _preferences.excludeDisliked,
                (value) => _updatePreference(excludeDisliked: value)),
            const Divider(color: Colors.white12),
            const Text(
                'Cross-profile discovery is private by default. Both profiles must opt in before another profile’s activity can contribute.',
                style: TextStyle(
                    color: Colors.white60, fontSize: 12, height: 1.4)),
            _switch(
                'Share my activity with other profiles',
                _preferences.shareHistoryWithOtherProfiles,
                (value) =>
                    _updatePreference(shareHistoryWithOtherProfiles: value)),
            _switch(
                'Use activity shared by other profiles',
                _preferences.useOtherProfileActivity,
                (value) => _updatePreference(useOtherProfileActivity: value)),
            const Divider(color: Colors.white12),
            const Text('Discovery sections',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(spacing: 7, runSpacing: 7, children: [
              FilterChip(
                label: const Text('For You', style: TextStyle(fontSize: 11)),
                selected: _preferences.enabledSections.contains('forYou'),
                onSelected: _savingPreferences
                    ? null
                    : (enabled) {
                        final nextSections = <String>{
                          ..._preferences.enabledSections
                        };
                        if (enabled) {
                          nextSections.add('forYou');
                        } else {
                          nextSections.remove('forYou');
                        }
                        unawaited(_savePreferences(_preferences.copyWith(
                            enabledSections: nextSections.toList())));
                      },
              ),
              ..._categories.map((category) => FilterChip(
                    label: Text(category.title,
                        style: const TextStyle(fontSize: 11)),
                    selected:
                        _preferences.enabledSections.contains(category.id),
                    onSelected: _savingPreferences
                        ? null
                        : (enabled) {
                            final nextSections = <String>{
                              ..._preferences.enabledSections
                            };
                            if (enabled) {
                              nextSections.add(category.id);
                            } else {
                              nextSections.remove(category.id);
                            }
                            unawaited(_savePreferences(_preferences.copyWith(
                                enabledSections: nextSections.toList())));
                          },
                  )),
            ]),
            const SizedBox(height: 8),
            Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _savingPreferences ? null : _manageTastePriorities,
                  icon: const Icon(Icons.tune_rounded, size: 17),
                  label: const Text(
                      'Prioritize performers, studios and story themes'),
                )),
            if (_preferenceError != null)
              Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_preferenceError!,
                      style: const TextStyle(
                          color: Colors.orangeAccent, fontSize: 11))),
            Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                    onPressed: _savingPreferences
                        ? null
                        : () => _savePreferences(_preferences),
                    icon: const Icon(Icons.save_rounded, size: 17),
                    label: const Text('Save preferences'))),
          ]),
        ),
      );

  Future<void> _manageTastePriorities() async {
    final performers = TextEditingController(
        text: _preferences.prioritizedPerformers.join(', '));
    final studios =
        TextEditingController(text: _preferences.prioritizedStudios.join(', '));
    final themes =
        TextEditingController(text: _preferences.prioritizedThemes.join(', '));
    final excluded =
        TextEditingController(text: _preferences.excludedGenres.join(', '));
    final excludedTones =
        TextEditingController(text: _preferences.excludedTones.join(', '));
    List<String> parse(String value) => value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
    final updated = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tune your discovery taste'),
        content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: performers,
              decoration: const InputDecoration(
                  labelText: 'Prioritized performers',
                  hintText: 'Names separated by commas')),
          TextField(
              controller: studios,
              decoration: const InputDecoration(
                  labelText: 'Prioritized studios',
                  hintText: 'Studios separated by commas')),
          TextField(
              controller: themes,
              decoration: const InputDecoration(
                  labelText: 'Preferred story themes',
                  hintText: 'Themes separated by commas')),
          TextField(
              controller: excluded,
              decoration: const InputDecoration(
                  labelText: 'Genres to exclude',
                  hintText: 'Genres separated by commas')),
          TextField(
              controller: excludedTones,
              decoration: const InputDecoration(
                  labelText: 'Tones to avoid',
                  hintText: 'Tones separated by commas')),
          const SizedBox(height: 8),
          const Text(
              'Use exact names or tags already present in your catalog metadata. These controls do not create credits or relationships.',
              style: TextStyle(fontSize: 12, color: Colors.black54)),
        ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (updated == true && mounted) {
      await _savePreferences(_preferences.copyWith(
        prioritizedPerformers: parse(performers.text),
        prioritizedStudios: parse(studios.text),
        prioritizedThemes: parse(themes.text),
        excludedGenres: parse(excluded.text),
        excludedTones: parse(excludedTones.text),
      ));
    }
    performers.dispose();
    studios.dispose();
    themes.dispose();
    excluded.dispose();
    excludedTones.dispose();
  }

  void _updatePreference({
    bool? includeLibraryItems,
    bool? includeExternalItems,
    bool? includeWatchedItems,
    bool? includeRewatches,
    bool? explainRecommendations,
    bool? spoilerSafe,
    bool? excludeDisliked,
    bool? shareHistoryWithOtherProfiles,
    bool? useOtherProfileActivity,
  }) {
    final next = _preferences.copyWith(
      includeLibraryItems: includeLibraryItems,
      includeExternalItems: includeExternalItems,
      includeWatchedItems: includeWatchedItems,
      includeRewatches: includeRewatches,
      explainRecommendations: explainRecommendations,
      spoilerSafe: spoilerSafe,
      excludeDisliked: excludeDisliked,
      shareHistoryWithOtherProfiles: shareHistoryWithOtherProfiles,
      useOtherProfileActivity: useOtherProfileActivity,
    );
    unawaited(_savePreferences(next));
  }

  Widget _switch(String label, bool value, ValueChanged<bool> onChanged) =>
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(label,
            style: const TextStyle(fontSize: 13, color: Colors.white)),
        value: value,
        onChanged: _savingPreferences ? null : onChanged,
      );

  Widget _categoryCard(
      ({String id, String title, String subtitle, IconData icon}) category) {
    final selected = _activeCategory == category.id;
    final count = _entitiesFor(category.id).length;
    return Material(
      color: selected ? const Color(0xFF252848) : const Color(0xFF151A27),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => setState(() {
          _activeCategory = category.id;
          _activeEntity = null;
        }),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Container(
                width: 39,
                height: 39,
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .07),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(category.icon, color: const Color(0xFFB7B4FF))),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Text(category.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 13)),
                  const SizedBox(height: 3),
                  Text(category.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 10, height: 1.25)),
                  const SizedBox(height: 4),
                  Text('$count indexed connections',
                      style: const TextStyle(
                          color: Color(0xFF9CB8FF),
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ])),
          ]),
        ),
      ),
    );
  }

  Widget _selectedCategoryPanel(
    ({String id, String title, String subtitle, IconData icon}) category,
    List<String> entities,
    List<MediaItem> matching,
  ) =>
      Card(
        color: const Color(0xFF121824),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(category.title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900))),
              IconButton(
                  onPressed: () => setState(() {
                        _activeCategory = null;
                        _activeEntity = null;
                      }),
                  icon: const Icon(Icons.close_rounded))
            ]),
            Text(category.subtitle,
                style: const TextStyle(color: Colors.white60, height: 1.35)),
            const SizedBox(height: 10),
            if (entities.isEmpty)
              _messageCard(category.id == 'awards'
                  ? 'No verified award credits are indexed yet. The app will not infer wins or nominations from ordinary ratings.'
                  : 'No matching metadata is indexed in this profile’s visible library yet.'),
            if (entities.isNotEmpty)
              Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: entities
                      .take(120)
                      .map((entity) => ChoiceChip(
                            label: Text(entity),
                            selected: _activeEntity == entity,
                            onSelected: (_) =>
                                setState(() => _activeEntity = entity),
                            selectedColor: const Color(0xFF45466C),
                            backgroundColor: const Color(0xFF242A39),
                            labelStyle: const TextStyle(
                                color: Colors.white, fontSize: 11),
                          ))
                      .toList()),
            if (_activeEntity != null) ...[
              if (category.id == 'performers') ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: () =>
                        Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => PerformerUniverseScreen(
                          performerName: _activeEntity!),
                    )),
                    icon: const Icon(Icons.person_search_rounded),
                    label: Text(
                        'Explore ${_activeEntity!} across movies, TV & music'),
                  ),
                ),
              ],
              const Divider(color: Colors.white12, height: 24),
              Text('Connected titles · ${matching.length}',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              if (matching.isEmpty)
                const Text(
                    'No titles in the visible library match this indexed entity.',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
              ...matching.take(20).map((media) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.movie_outlined,
                        color: Color(0xFFB7B4FF)),
                    title: Text(media.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                        '${media.type}${media.releaseYear == null ? '' : ' · ${media.releaseYear}'}',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11)),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: Colors.white54),
                    onTap: () => _openMedia(media),
                  )),
            ],
          ]),
        ),
      );

  Widget _messageCard(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
            color: const Color(0xFF151A27),
            borderRadius: BorderRadius.circular(13)),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white60, height: 1.4, fontSize: 12)),
      );

  Widget _posterFallback(String title) => Container(
        color: const Color(0xFF272B3B),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(6),
        child: Text(title,
            maxLines: 4,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: Colors.white70)),
      );
}

class DiscoveryTitleComparisonScreen extends StatefulWidget {
  const DiscoveryTitleComparisonScreen({super.key});

  @override
  State<DiscoveryTitleComparisonScreen> createState() =>
      _DiscoveryTitleComparisonScreenState();
}

class _DiscoveryTitleComparisonScreenState
    extends State<DiscoveryTitleComparisonScreen> {
  String? _sourceId;
  String? _targetId;
  Map<String, dynamic>? _comparison;
  bool _loading = false;
  String? _error;

  List<MediaItem> get _items => AppController.instance.library
      .where(
          (item) => item.isAccessibleTo(AppController.instance.currentProfile))
      .where((item) => !isExcludedEntertainmentType(item.type))
      .toList(growable: false);

  Future<void> _compare() async {
    final profileId = AppController.instance.currentProfile?.id;
    if (profileId == null ||
        _sourceId == null ||
        _targetId == null ||
        _sourceId == _targetId) {
      setState(() => _error =
          'Select two different titles and make sure a profile is active.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _comparison = null;
    });
    try {
      final response =
          await AppController.instance.backendApi.compareRecommendationTitles(
        profileId: profileId,
        sourceId: _sourceId!,
        targetId: _targetId!,
      );
      if (mounted) {
        setState(() => _comparison = response['comparison'] is Map
            ? Map<String, dynamic>.from(response['comparison'] as Map)
            : null);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF090B12),
        appBar: AppBar(
            title: const Text('Compare Two Titles'),
            backgroundColor: const Color(0xFF10131E)),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('How are these stories connected?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text(
              'Compare people, characters, story themes, production studios, genres, music and franchise metadata. A missing signal means the catalog has not indexed it; it does not mean the titles have no real-world connection.',
              style: TextStyle(color: Colors.white60, height: 1.4)),
          const SizedBox(height: 18),
          _selector('First title', _sourceId,
              (value) => setState(() => _sourceId = value)),
          const SizedBox(height: 12),
          _selector('Second title', _targetId,
              (value) => setState(() => _targetId = value)),
          const SizedBox(height: 16),
          FilledButton.icon(
              onPressed: _loading ? null : _compare,
              icon: const Icon(Icons.compare_arrows_rounded),
              label: Text(_loading ? 'Comparing…' : 'Compare metadata')),
          if (_error != null)
            Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!,
                    style: const TextStyle(color: Colors.orangeAccent))),
          if (_comparison != null) ...[
            const SizedBox(height: 20),
            Card(
                color: const Color(0xFF151A27),
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${_comparison!['matchEstimate'] ?? 0}% catalog match estimate',
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 6),
                          Text(
                              _comparison!['disclaimer']?.toString() ??
                                  'This is not a probability of personal preference.',
                              style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                  height: 1.4)),
                          const SizedBox(height: 12),
                          if (_comparison!['confidenceLabel'] ==
                              'insufficient_metadata')
                            const Text(
                                'Not enough indexed information to calculate a meaningful comparison.',
                                style: TextStyle(color: Colors.orangeAccent)),
                          if (_comparison!['breakdown'] is Map)
                            ...(_comparison!['breakdown'] as Map)
                                .entries
                                .map((entry) {
                              final values = entry.value is List
                                  ? (entry.value as List)
                                      .map((value) => value.toString())
                                      .toList()
                                  : <String>[];
                              return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 5),
                                  child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                            width: 150,
                                            child: Text(
                                                _label(entry.key.toString()),
                                                style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.w700))),
                                        Expanded(
                                            child: Text(
                                                values.isEmpty
                                                    ? 'No shared indexed metadata'
                                                    : values.join(' · '),
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12))),
                                      ]));
                            }),
                        ]))),
          ],
        ]),
      );

  Widget _selector(
          String label, String? value, ValueChanged<String?> onChanged) =>
      DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
            labelText: label,
            filled: true,
            fillColor: const Color(0xFF171C2A),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
        items: _items
            .map((item) => DropdownMenuItem<String>(
                value: item.id,
                child: Text(
                    '${item.title}${item.releaseYear == null ? '' : ' (${item.releaseYear})'}',
                    overflow: TextOverflow.ellipsis)))
            .toList(),
        onChanged: onChanged,
      );

  String _label(String value) => value
      .replaceAllMapped(RegExp(r'[A-Z]'), (match) => ' ${match.group(0)}')
      .trim();
}
