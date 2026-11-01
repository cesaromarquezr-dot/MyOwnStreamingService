import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_core.dart';
import 'details.dart';
import 'energy_saver.dart';
import 'media_metadata_catalog_screen.dart';
import 'music.dart';
import 'profile_content_safety.dart';
import 'home_arrow_rail.dart';
import 'home_hero_hover_preview.dart';
import 'media_artwork_auto_resolver.dart';
import 'widgets/added_by_profile_label.dart';

const List<(String, String, IconData)> _top10ScopeCategories =
    <(String, String, IconData)>[
  ('actors', 'Actors', Icons.face_rounded),
  ('actresses', 'Actresses', Icons.face_3_rounded),
  ('directors', 'Directors', Icons.movie_creation_rounded),
  ('writers', 'Writers / Screenwriters', Icons.edit_rounded),
  ('composers', 'Composers', Icons.music_note_rounded),
  ('singers', 'Singers', Icons.mic_rounded),
  ('bands', 'Bands', Icons.groups_rounded),
  ('albums', 'Albums', Icons.album_rounded),
  ('songs', 'Songs', Icons.music_note_rounded),
];

/// One Home Top 10 scope with a category picker for people and music.
class Top10ScopeShelf extends StatefulWidget {
  const Top10ScopeShelf(
      {super.key, required this.scopeKey, required this.title});

  final String scopeKey;
  final String title;

  @override
  State<Top10ScopeShelf> createState() => _Top10ScopeShelfState();
}

class _Top10ScopeShelfState extends State<Top10ScopeShelf> {
  String _chartKey = 'actors';

  @override
  Widget build(BuildContext context) {
    final category =
        _top10ScopeCategories.firstWhere((item) => item.$1 == _chartKey);
    final scopeDescription = switch (widget.scopeKey) {
      'global' =>
        'TMDB popularity for people; global ListenBrainz charts for music.',
      'account' =>
        'Shared credits and listening completed by every profile in this account.',
      _ => 'Ranked from this profile’s library and listening history.',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Row(children: [
            Expanded(
                child: Text(widget.title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900))),
            Text(category.$2,
                style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
          child: Text(scopeDescription,
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            scrollDirection: Axis.horizontal,
            itemCount: _top10ScopeCategories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 7),
            itemBuilder: (context, index) {
              final item = _top10ScopeCategories[index];
              return ChoiceChip(
                avatar: Icon(item.$3, size: 16),
                label: Text(item.$2),
                selected: _chartKey == item.$1,
                onSelected: (_) => setState(() => _chartKey = item.$1),
                visualDensity: VisualDensity.compact,
                labelStyle:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              );
            },
          ),
        ),
        WeeklyTop10Shelf(
          key: ValueKey('${widget.scopeKey}:$_chartKey'),
          chartKey: _chartKey,
          title: '${widget.title.toUpperCase()} · ${category.$2.toUpperCase()}',
          scopeKey: widget.scopeKey,
        ),
      ],
    );
  }
}

/// Category shelves are intentionally data-driven so Home customization can
/// reorder or hide each chart independently.
class WeeklyTop10Shelf extends StatefulWidget {
  const WeeklyTop10Shelf(
      {super.key,
      required this.chartKey,
      required this.title,
      this.scopeKey = 'profile'});

  final String chartKey;
  final String title;
  final String scopeKey;

  @override
  State<WeeklyTop10Shelf> createState() => _WeeklyTop10ShelfState();
}

class _WeeklyTop10ShelfState extends State<WeeklyTop10Shelf> {
  bool _loading = true;
  String? _message;
  List<_RankedItem> _items = <_RankedItem>[];
  int _requestId = 0;
  bool _musicInitialized = false;
  bool _musicInitializing = false;
  String? _musicProfileId;
  String? _loadedProfileId;
  String? _loadedAccountId;

  @override
  void initState() {
    super.initState();
    _loadedProfileId = AppController.instance.currentProfile?.id;
    _loadedAccountId = AppController.instance.currentAccount?.id;
    AppController.instance.addListener(_handleControllerChanged);
    if (_isMusicChart) {
      MusicLibraryStore.instance.addListener(_refreshMusicChart);
      _loadMusicChart();
    } else {
      _loadScopedTmdbChart();
    }
  }

  @override
  void didUpdateWidget(covariant WeeklyTop10Shelf oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chartKey != widget.chartKey ||
        oldWidget.scopeKey != widget.scopeKey) {
      final wasMusicChart = const <String>{
        'albums',
        'songs',
        'singers',
        'bands'
      }.contains(oldWidget.chartKey);
      if (wasMusicChart && !_isMusicChart) {
        MusicLibraryStore.instance.removeListener(_refreshMusicChart);
      } else if (!wasMusicChart && _isMusicChart) {
        MusicLibraryStore.instance.addListener(_refreshMusicChart);
        _musicInitialized = false;
      }
      final chartKeyAfterBuild = widget.chartKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || widget.chartKey != chartKeyAfterBuild) return;
        if (_isMusicChart) {
          _loadMusicChart();
        } else {
          _loadScopedTmdbChart();
        }
      });
    }
  }

  @override
  void dispose() {
    MusicLibraryStore.instance.removeListener(_refreshMusicChart);
    AppController.instance.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _handleControllerChanged() {
    final profileId = AppController.instance.currentProfile?.id;
    final accountId = AppController.instance.currentAccount?.id;
    final changed = widget.scopeKey == 'profile'
        ? profileId != _loadedProfileId
        : widget.scopeKey == 'account' && accountId != _loadedAccountId;
    if (!changed) return;
    _loadedProfileId = profileId;
    _loadedAccountId = accountId;
    if (_isMusicChart) {
      _musicInitialized = false;
      _loadMusicChart();
    } else {
      _loadScopedTmdbChart();
    }
  }

  bool get _isMusicChart => const <String>{
        'albums',
        'songs',
        'singers',
        'bands'
      }.contains(widget.chartKey);

  void _refreshMusicChart() {
    if (_isMusicChart && mounted && !_musicInitializing) {
      _loadMusicChart(notify: false);
    }
  }

  Future<void> _loadScopedTmdbChart() async {
    if (widget.scopeKey == 'global') {
      await _loadGlobalTmdbChart();
    } else if (widget.scopeKey == 'account') {
      await _loadAccountTmdbChart();
    } else {
      await _loadTmdbChart();
    }
  }

  Future<void> _loadGlobalTmdbChart() async {
    final requestId = ++_requestId;
    if (mounted) {
      setState(() {
        _loading = true;
        _message = null;
      });
    }
    try {
      final api = AppController.instance.backendApi;
      final payloads = await Future.wait(<Future<Map<String, dynamic>>>[
        for (var page = 1; page <= 5; page++)
          api.getTmdbMetadata('/person/popular',
              <String, String>{'page': '$page', 'language': 'en-US'}),
      ]);
      final rows = <Map<String, dynamic>>[];
      for (final payload in payloads) {
        final raw = payload['results'];
        if (raw is List) {
          rows.addAll(raw
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row)));
        }
      }
      final targetDepartment = switch (widget.chartKey) {
        'directors' => 'directing',
        'writers' => 'writing',
        'composers' => 'sound',
        _ => 'acting',
      };
      final targetGender = widget.chartKey == 'actresses' ? 1 : 2;
      final people = rows.where((person) {
        final department =
            (person['known_for_department'] ?? '').toString().toLowerCase();
        if (department != targetDepartment) return false;
        if (widget.chartKey == 'actors' || widget.chartKey == 'actresses') {
          return person['gender'] == targetGender;
        }
        return true;
      }).toList()
        ..sort((a, b) =>
            _number(b['popularity']).compareTo(_number(a['popularity'])));
      final items = <_RankedItem>[];
      for (final person in people.take(10)) {
        final id = person['id']?.toString() ?? '';
        final name = (person['name'] ?? '').toString().trim();
        if (id.isEmpty || name.isEmpty) continue;
        final profilePath = person['profile_path']?.toString().trim() ?? '';
        final image = profilePath.isEmpty
            ? null
            : 'https://image.tmdb.org/t/p/w500$profilePath';
        items.add(_personRankedItem(
          rank: items.length + 1,
          name: name,
          subtitle:
              'TMDB popularity ${_number(person['popularity']).toStringAsFixed(1)}',
          imageUrl: image,
        ));
      }
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _items = items;
        _loading = false;
        _message = items.isEmpty
            ? 'TMDB has no popular ${_categoryLabel(widget.chartKey).toLowerCase()} entries for this period.'
            : null;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _items = <_RankedItem>[];
        _loading = false;
        _message =
            'TMDB global rankings could not be loaded. Check backend authentication and TMDB configuration.';
      });
      debugPrint('Global TMDB Top 10 failed: $error');
    }
  }

  static double _number(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0;

  String _categoryLabel(String key) {
    for (final category in _top10ScopeCategories) {
      if (category.$1 == key) return category.$2;
    }
    return key;
  }

  Future<void> _loadTmdbChart() async {
    final requestId = ++_requestId;
    final controller = AppController.instance;
    final profile = controller.currentProfile;
    if (mounted) {
      setState(() {
        _loading = true;
        _message = null;
      });
    }

    try {
      final visible = controller.library
          .where((media) => media.isAccessibleTo(profile))
          .where((media) => !isExcludedEntertainmentType(media.type))
          .where((media) => media.addedSource != 'demo-preview')
          .where((media) => !media.tags.any((tag) => const <String>{
                'demo-preview',
                'preview-only',
                'not-playable'
              }.contains(tag.toLowerCase().trim())))
          .toList(growable: false);
      final items = <_RankedItem>[];

      bool isShow(MediaItem media) {
        final type = media.type.toLowerCase().replaceAll('_', ' ').trim();
        return media.isSeries ||
            type == 'show' ||
            type == 'tvshow' ||
            type == 'tv show' ||
            type == 'series' ||
            type == 'television';
      }

      bool isMovie(MediaItem media) {
        final type = media.type.toLowerCase().trim();
        return !isShow(media) &&
            (type == 'movie' ||
                type == 'film' ||
                type == 'feature' ||
                type == 'feature film' ||
                type.contains('movie') ||
                type.contains('film'));
      }

      int mediaScore(MediaItem media) {
        var score = 0;
        if (controller.liked.any((item) => item.id == media.id)) score += 180;
        if (controller.isWatched(media.id)) score += 90;
        score += ((media.userRatingStars ??
                    media.audienceRating ??
                    media.rating ??
                    0) *
                8)
            .round();
        score += (controller.getPlaybackProgress(media.id) * 45).round();
        // Recently imported titles fill an otherwise tied Top 10 without
        // pretending that catalog-wide popularity describes the user's library.
        final ageDays =
            DateTime.now().difference(media.addedAt).inDays.clamp(0, 3650);
        score += (30 - (ageDays ~/ 30)).clamp(0, 30).toInt();
        return score;
      }

      if (widget.chartKey == 'movies' || widget.chartKey == 'shows') {
        final wantShows = widget.chartKey == 'shows';
        final ranked = visible
            .where((media) => wantShows ? isShow(media) : isMovie(media))
            .toList()
          ..sort((a, b) {
            final score = mediaScore(b).compareTo(mediaScore(a));
            if (score != 0) return score;
            final added = b.addedAt.compareTo(a.addedAt);
            return added != 0
                ? added
                : a.title.toLowerCase().compareTo(b.title.toLowerCase());
          });
        for (final media in ranked.take(10)) {
          final status = <String>[
            if (controller.liked.any((item) => item.id == media.id)) 'Favorite',
            if (controller.isWatched(media.id)) 'Watched',
            if (controller.getPlaybackProgress(media.id) > 0 &&
                controller.getPlaybackProgress(media.id) < 1)
              'In progress',
            if ((media.releaseYear ?? media.seriesStartYear) != null)
              '${media.releaseYear ?? media.seriesStartYear}',
          ];
          items.add(_RankedItem(
            rank: items.length + 1,
            title: media.title,
            subtitle:
                status.isEmpty ? 'Owned in your library' : status.join(' • '),
            imageUrl: media.imageUrl,
            media: media,
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => MediaDetailsScreen(media: media),
            )),
          ));
        }
      } else {
        // People charts are derived from cast and crew credits attached to
        // titles accessible to the active profile.
        final people = <String, _OwnedPersonAggregate>{};
        for (final media in visible) {
          if (!isMovie(media) && !isShow(media)) continue;
          final creditNames = switch (widget.chartKey) {
            'directors' => media.directors.toSet(),
            'writers' => media.writers.toSet(),
            'composers' => media.music.toSet(),
            _ => media.actors.toSet(),
          };
          for (final rawName in creditNames) {
            final name = rawName.trim();
            if (name.isEmpty) continue;
            final key = name.toLowerCase();
            final aggregate =
                people.putIfAbsent(key, () => _OwnedPersonAggregate(name));
            aggregate.ownedTitleCount++;
            aggregate.score += 1 +
                (controller.isWatched(media.id) ? 2 : 0) +
                (controller.liked.any((item) => item.id == media.id) ? 2 : 0);
          }
        }
        final entries = people.entries.toList()
          ..sort((a, b) {
            final count = b.value.score.compareTo(a.value.score);
            if (count != 0) return count;
            return a.value.name
                .toLowerCase()
                .compareTo(b.value.name.toLowerCase());
          });
        final isGenderCategory =
            widget.chartKey == 'actors' || widget.chartKey == 'actresses';
        final gender = widget.chartKey == 'actresses' ? 1 : 2;
        final matchingEntries = isGenderCategory
            ? await _filterPeopleByTmdbGender(entries.take(40).toList(), gender)
            : entries;
        for (final entry in matchingEntries.take(10)) {
          final person = entry.value;
          items.add(_RankedItem(
            rank: items.length + 1,
            title: person.name,
            subtitle:
                '${person.ownedTitleCount} owned ${person.ownedTitleCount == 1 ? 'title' : 'titles'}',
            imageUrl: person.artworkUrl,
            media: null,
            onTap: () => _openPersonSearch(person.name),
          ));
        }
      }

      if (!mounted || requestId != _requestId) return;
      setState(() {
        _items = items;
        _loading = false;
        _message = items.isEmpty
            ? (widget.chartKey == 'actresses' || widget.chartKey == 'actors'
                ? 'No matching ${_categoryLabel(widget.chartKey).toLowerCase()} are linked to this profile’s library yet, or TMDB could not verify their gender.'
                : 'No matching items are in this profile’s library yet. Import media and its metadata to build this Top 10.')
            : null;
      });
      if (items.isNotEmpty &&
          const <String>{
            'actors',
            'actresses',
            'directors',
            'writers',
            'composers'
          }.contains(widget.chartKey)) {
        unawaited(_hydratePeopleArtwork(requestId));
      }
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _items = <_RankedItem>[];
        _loading = false;
        _message =
            'Your library Top 10 could not be calculated. Check the library metadata and try again.';
      });
      debugPrint('Owned Top 10 chart failed: $error');
    }
  }

  Future<List<List<Map<String, dynamic>>>> _wrappedActivityForProfileIds(
    List<String> profileIds,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final output = <List<Map<String, dynamic>>>[];
    for (final profileId in profileIds) {
      final raw = preferences.getString('moss_wrapped_activity_$profileId');
      if (raw == null) {
        output.add(<Map<String, dynamic>>[]);
        continue;
      }
      try {
        final decoded = jsonDecode(raw);
        output.add(decoded is List
            ? decoded
                .whereType<Map>()
                .map((row) => Map<String, dynamic>.from(row))
                .toList(growable: false)
            : <Map<String, dynamic>>[]);
      } catch (_) {
        output.add(<Map<String, dynamic>>[]);
      }
    }
    return output;
  }

  Future<void> _loadAccountTmdbChart() async {
    final requestId = ++_requestId;
    if (mounted) {
      setState(() {
        _loading = true;
        _message = null;
      });
    }
    try {
      final controller = AppController.instance;
      final profileIds =
          (controller.currentAccount?.profiles ?? const <Profile>[])
              .map((profile) => profile.id.trim())
              .where((id) => id.isNotEmpty)
              .toList(growable: false);
      final activities = await _wrappedActivityForProfileIds(
        profileIds.isEmpty && controller.currentProfile != null
            ? <String>[controller.currentProfile!.id]
            : profileIds,
      );
      if (activities.isEmpty || activities.any((events) => events.isEmpty)) {
        if (!mounted || requestId != _requestId) return;
        setState(() {
          _items = <_RankedItem>[];
          _loading = false;
          _message =
              'This account chart fills when every profile has completed some movie or show playback.';
        });
        return;
      }
      Set<String> mediaIdsFor(List<Map<String, dynamic>> events) => events
          .where((event) => event['action'] == 'completed')
          .where((event) => !const <String>{'song', 'track', 'music_track'}
              .contains((event['type'] ?? '').toString().toLowerCase()))
          .map((event) {
            final canonicalId =
                (event['canonicalWorkId'] ?? '').toString().trim();
            return canonicalId.isNotEmpty
                ? canonicalId
                : (event['mediaId'] ?? '').toString();
          })
          .where((id) => id.isNotEmpty)
          .toSet();
      final commonIds = mediaIdsFor(activities.first);
      for (final events in activities.skip(1)) {
        commonIds.retainAll(mediaIdsFor(events));
      }
      final profiles = controller.currentAccount?.profiles ?? const <Profile>[];
      final commonMedia = controller.library.where((media) {
        final canonicalId = media.canonicalWorkId?.trim();
        final workId =
            canonicalId?.isNotEmpty == true ? canonicalId! : media.id;
        if (!commonIds.contains(workId) ||
            isExcludedEntertainmentType(media.type)) {
          return false;
        }
        return profiles.every((profile) => media.isAccessibleTo(profile));
      }).toList(growable: false);
      final people = <String, _OwnedPersonAggregate>{};
      for (final media in commonMedia) {
        final type = media.type.toLowerCase().replaceAll('_', ' ').trim();
        final isShow = media.isSeries ||
            const <String>{'show', 'tvshow', 'tv show', 'series', 'television'}
                .contains(type);
        final isMovie = !isShow &&
            (type.contains('movie') ||
                type.contains('film') ||
                type == 'feature');
        if (!isMovie && !isShow) continue;
        final credits = switch (widget.chartKey) {
          'directors' => media.directors,
          'writers' => media.writers,
          'composers' => media.music,
          _ => media.actors,
        };
        for (final rawName in credits.toSet()) {
          final name = rawName.trim();
          if (name.isEmpty) continue;
          final key = name.toLowerCase();
          final aggregate =
              people.putIfAbsent(key, () => _OwnedPersonAggregate(name));
          aggregate.ownedTitleCount++;
          aggregate.score += activities.length;
          aggregate.artworkUrl ??= media.imageUrl;
        }
      }
      var entries = people.entries.toList()
        ..sort((a, b) {
          final byScore = b.value.score.compareTo(a.value.score);
          return byScore != 0
              ? byScore
              : a.value.name
                  .toLowerCase()
                  .compareTo(b.value.name.toLowerCase());
        });
      if (widget.chartKey == 'actors' || widget.chartKey == 'actresses') {
        entries = await _filterPeopleByTmdbGender(
            entries.take(40).toList(), widget.chartKey == 'actresses' ? 1 : 2);
      }
      final items = <_RankedItem>[];
      for (final entry in entries.take(10)) {
        items.add(_personRankedItem(
          rank: items.length + 1,
          name: entry.value.name,
          subtitle:
              'In ${entry.value.ownedTitleCount} titles watched by every profile',
          imageUrl: entry.value.artworkUrl,
        ));
      }
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _items = items;
        _loading = false;
        _message = items.isEmpty
            ? 'No ${_categoryLabel(widget.chartKey).toLowerCase()} appear in titles completed by every profile yet.'
            : null;
      });
      if (items.isNotEmpty) unawaited(_hydratePeopleArtwork(requestId));
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _items = <_RankedItem>[];
        _loading = false;
        _message = 'The account-wide common Top 10 could not be calculated.';
      });
      debugPrint('Account common Top 10 failed: $error');
    }
  }

  Future<List<MapEntry<String, _OwnedPersonAggregate>>>
      _filterPeopleByTmdbGender(
    List<MapEntry<String, _OwnedPersonAggregate>> entries,
    int gender,
  ) async {
    final matches = await Future.wait(entries.map((entry) async {
      try {
        final payload = await AppController.instance.backendApi.getTmdbMetadata(
          '/search/person',
          <String, String>{'query': entry.value.name, 'include_adult': 'false'},
        );
        final results = payload['results'];
        if (results is! List) return false;
        final normalized = entry.value.name.toLowerCase().trim();
        return results.whereType<Map>().any((person) =>
            (person['name'] ?? '').toString().toLowerCase().trim() ==
                normalized &&
            person['gender'] == gender);
      } catch (_) {
        return false;
      }
    }));
    return <MapEntry<String, _OwnedPersonAggregate>>[
      for (var index = 0; index < entries.length; index++)
        if (matches[index]) entries[index],
    ];
  }

  _RankedItem _personRankedItem({
    required int rank,
    required String name,
    required String subtitle,
    String? imageUrl,
  }) =>
      _RankedItem(
        rank: rank,
        title: name,
        subtitle: subtitle,
        imageUrl: imageUrl,
        media: null,
        onTap: () => _openPersonSearch(name),
      );

  void _openPersonSearch(String name) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) =>
          MediaMetadataCatalogScreen(initialType: 'person', initialQuery: name),
    ));
  }

  Future<void> _hydratePeopleArtwork(int requestId) async {
    final startingItems = List<_RankedItem>.from(_items);
    for (final candidate in startingItems) {
      if (!mounted || requestId != _requestId) return;
      final portrait = await MediaArtworkAutoResolver.resolvePersonPortrait(
        candidate.title,
        pageId: EnergySaverController.instance.activePage,
      );
      if (portrait == null ||
          portrait.isEmpty ||
          !mounted ||
          requestId != _requestId) {
        continue;
      }
      final index = _items.indexWhere((item) =>
          item.rank == candidate.rank && item.title == candidate.title);
      if (index < 0 || _items[index].imageUrl == portrait) continue;
      setState(() {
        final current = _items[index];
        _items[index] = _RankedItem(
          rank: current.rank,
          title: current.title,
          subtitle: current.subtitle,
          imageUrl: portrait,
          media: current.media,
          onTap: current.onTap,
        );
      });
    }
  }

  Future<void> _loadMusicChart({bool notify = true}) async {
    final requestId = ++_requestId;
    if (notify && mounted) {
      setState(() {
        _loading = true;
        _message = null;
      });
    }
    if (widget.scopeKey == 'global') {
      await _loadGlobalMusicChart(requestId);
      return;
    }
    if (widget.scopeKey == 'account') {
      await _loadAccountMusicChart(requestId);
      return;
    }
    final store = MusicLibraryStore.instance;
    try {
      final profileId = AppController.instance.currentProfile?.id;
      if (_musicProfileId != profileId) {
        _musicInitialized = false;
        _musicProfileId = profileId;
      }
      if (!_musicInitialized) {
        _musicInitializing = true;
        try {
          await store.initializeForProfile(profileId);
          _musicInitialized = true;
        } finally {
          _musicInitializing = false;
        }
      }
      final profile = AppController.instance.currentProfile;
      final tracks = store.tracks.where((track) =>
          !track.id.startsWith('demo-catalog-track-') &&
          !track.id.startsWith('demo-preview-album-track-') &&
          !(profileBlocksExplicitMusic(profile) && track.explicit) &&
          !(profileBlocksMatureMusic(profile) && track.matureTheme));
      final trackList = tracks.toList(growable: false);
      // Rankings are based on items actually present in this music library.
      // Lifetime plays are a secondary tie-breaker, never an ownership gate.
      int score(MusicTrack track) => 1 + (store.listenCounts[track.id] ?? 0);
      final ranked = <_RankedItem>[];

      if (widget.chartKey == 'songs') {
        final ordered = trackList.toList()
          ..sort((a, b) {
            final byScore = score(b).compareTo(score(a));
            return byScore != 0
                ? byScore
                : a.title.toLowerCase().compareTo(b.title.toLowerCase());
          });
        for (final track in ordered.take(10)) {
          ranked.add(_musicItem(
            ranked.length + 1,
            track.title,
            track.artist,
            track.artworkUrl,
            MediaItem(
              id: 'weekly-song-${track.id}',
              title: track.title,
              type: 'song',
              imageUrl: track.artworkUrl,
              description: '${track.artist} • ${track.album}',
              trailerUrl: track.musicVideoUrl,
              music: <String>[track.artist, ...track.featuredArtists],
              genres: track.allGenreTags,
              addedByProfileId: track.addedByProfileId,
              addedByProfileName: track.addedByProfileName,
              addedSource: track.addedSource,
            ),
          ));
        }
      } else if (widget.chartKey == 'albums') {
        final grouped = <String, _AlbumAggregate>{};
        for (final track in trackList) {
          if (track.album.trim().isEmpty) continue;
          final key =
              '${track.album.toLowerCase().trim()}|${track.artist.toLowerCase().trim()}';
          final value = grouped.putIfAbsent(
            key,
            () => _AlbumAggregate(track.album, track.artist, track.artworkUrl),
          );
          value.score += score(track);
          value.artworkUrl ??= track.artworkUrl;
          value.observeAttribution(track);
        }
        final ordered = grouped.values.toList()
          ..sort((a, b) => b.score.compareTo(a.score));
        for (final album in ordered.take(10)) {
          final media = MediaItem(
            id: 'weekly-album-${album.title}-${album.artist}',
            title: album.title,
            type: 'album',
            imageUrl: album.artworkUrl,
            description: album.artist,
            music: <String>[album.artist],
            addedByProfileId: album.addedByProfileId,
            addedByProfileName: album.addedByProfileName,
            addedSource: album.addedSource,
          );
          ranked.add(_musicItem(ranked.length + 1, album.title, album.artist,
              album.artworkUrl, media));
        }
      } else {
        final artistScores = <String, int>{};
        final artistImages = <String, String?>{};
        final artistNames = <String, String>{};
        for (final track in trackList) {
          final plays = score(track);
          final names = <String>{track.artist, ...track.featuredArtists}
              .where((name) => name.trim().isNotEmpty);
          for (final name in names) {
            final key = name.toLowerCase().trim();
            artistScores[key] = (artistScores[key] ?? 0) + plays;
            artistNames[key] = name.trim();
            artistImages.putIfAbsent(key, () => track.artworkUrl);
          }
        }
        bool isBand(String name) {
          final value = name.toLowerCase().trim();
          if (value == 'the weeknd' || value == 'the kid laroi') return false;
          return RegExp(
                      r'\b(band|orchestra|ensemble|collective|quartet|trio|choir|group|company)\b')
                  .hasMatch(value) ||
              value.startsWith('the ') ||
              value.contains(' & ') ||
              value.contains(' and ');
        }

        final wantBands = widget.chartKey == 'bands';
        final keys = artistScores.keys
            .where((key) => isBand(artistNames[key] ?? '') == wantBands)
            .toList()
          ..sort((a, b) => artistScores[b]!.compareTo(artistScores[a]!));
        for (final key in keys.take(10)) {
          final name = artistNames[key] ?? key;
          ranked.add(_musicItem(
            ranked.length + 1,
            name,
            'From your owned tracks',
            artistImages[key],
            MediaItem(
              id: 'weekly-${wantBands ? 'band' : 'artist'}-${key.replaceAll(RegExp(r'[^a-z0-9]+'), '-')}',
              title: name,
              type: wantBands ? 'band' : 'artist',
              imageUrl: artistImages[key],
              description:
                  '${wantBands ? 'Band' : 'Singer / artist'} • From your owned tracks',
              music: <String>[name],
            ),
            openArtistProfile: true,
          ));
        }
      }

      if (!mounted || requestId != _requestId) return;
      setState(() {
        _items = ranked;
        _loading = false;
        _message = ranked.isEmpty
            ? 'No owned tracks are available for this chart yet. Import music to build your library Top 10.'
            : null;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _items = <_RankedItem>[];
        _loading = false;
        _message = 'Unable to build this profile\'s owned music chart.';
      });
      debugPrint('Weekly Top 10 music chart failed: $error');
    }
  }

  bool _isBandName(String name) {
    final value = name.toLowerCase().trim();
    if (value == 'the weeknd' || value == 'the kid laroi') return false;
    return RegExp(
                r'\b(band|orchestra|ensemble|collective|quartet|trio|choir|group|company)\b')
            .hasMatch(value) ||
        value.startsWith('the ') ||
        value.contains(' & ') ||
        value.contains(' and ');
  }

  Future<void> _loadGlobalMusicChart(int requestId) async {
    try {
      final payload =
          await AppController.instance.backendApi.getGlobalMusicCharts();
      final items = <_RankedItem>[];
      if (widget.chartKey == 'songs' || widget.chartKey == 'albums') {
        final key = widget.chartKey == 'songs' ? 'recordings' : 'releaseGroups';
        final raw = payload[key];
        final rows = raw is List ? raw.whereType<Map>() : const <Map>[];
        for (final row in rows.take(10)) {
          final item = Map<String, dynamic>.from(row);
          final title = (item['title'] ?? '').toString().trim();
          if (title.isEmpty) continue;
          final artist = (item['artist'] ?? 'Unknown artist').toString();
          final image = item['artworkUrl']?.toString();
          final listens = item['listenCount'] is num
              ? (item['listenCount'] as num).toInt()
              : 0;
          final type = widget.chartKey == 'songs' ? 'song' : 'album';
          items.add(_musicItem(
            items.length + 1,
            title,
            '$artist • $listens sitewide listens',
            image,
            MediaItem(
              id: 'global-$type-${item['musicBrainzId'] ?? title}',
              title: title,
              type: type,
              imageUrl: image,
              description: '$artist • ListenBrainz sitewide chart',
              music: <String>[artist],
            ),
          ));
        }
      } else {
        final raw = payload['artists'];
        final rows = raw is List ? raw.whereType<Map>() : const <Map>[];
        final wantBands = widget.chartKey == 'bands';
        for (final row in rows) {
          final item = Map<String, dynamic>.from(row);
          final name = (item['title'] ?? '').toString().trim();
          if (name.isEmpty || _isBandName(name) != wantBands) continue;
          final listens = item['listenCount'] is num
              ? (item['listenCount'] as num).toInt()
              : 0;
          items.add(_musicItem(
            items.length + 1,
            name,
            '$listens sitewide listens • ListenBrainz',
            item['artworkUrl']?.toString(),
            MediaItem(
              id: 'global-artist-${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}',
              title: name,
              type: wantBands ? 'band' : 'artist',
              description: 'ListenBrainz sitewide listening chart',
              music: <String>[name],
            ),
            openArtistProfile: true,
          ));
          if (items.length >= 10) break;
        }
      }
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _items = items;
        _loading = false;
        _message = items.isEmpty
            ? 'The global ${_categoryLabel(widget.chartKey).toLowerCase()} chart has no entries available yet.'
            : null;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _items = <_RankedItem>[];
        _loading = false;
        _message =
            'Global ListenBrainz charts could not be loaded. Check the backend connection.';
      });
      debugPrint('Global music Top 10 failed: $error');
    }
  }

  Future<void> _loadAccountMusicChart(int requestId) async {
    try {
      final controller = AppController.instance;
      final profileIds =
          (controller.currentAccount?.profiles ?? const <Profile>[])
              .map((profile) => profile.id.trim())
              .where((id) => id.isNotEmpty)
              .toList(growable: false);
      final ids = profileIds.isEmpty && controller.currentProfile != null
          ? <String>[controller.currentProfile!.id]
          : profileIds;
      await MusicLibraryStore.instance.initializeForProfile(
        controller.currentProfile?.id,
      );
      final activities = await _wrappedActivityForProfileIds(ids);
      if (activities.isEmpty || activities.any((rows) => rows.isEmpty)) {
        if (!mounted || requestId != _requestId) return;
        setState(() {
          _items = <_RankedItem>[];
          _loading = false;
          _message =
              'This account chart fills after every profile completes music playback.';
        });
        return;
      }
      String keyFor(Map<String, dynamic> event) {
        final title = (event['title'] ?? '').toString().trim().toLowerCase();
        final artist = (event['artist'] ?? '').toString().trim().toLowerCase();
        return '$title|$artist';
      }

      List<Map<String, dynamic>> songRows(List<Map<String, dynamic>> rows) =>
          rows
              .where((row) => row['action'] == 'completed')
              .where((row) => const <String>{'song', 'track', 'music_track'}
                  .contains((row['type'] ?? '').toString().toLowerCase()))
              .where((row) => keyFor(row) != '|')
              .toList(growable: false);
      final profileRows = activities.map(songRows).toList(growable: false);
      if (profileRows.any((rows) => rows.isEmpty)) {
        if (!mounted || requestId != _requestId) return;
        setState(() {
          _items = <_RankedItem>[];
          _loading = false;
          _message = 'No songs have been completed by every profile yet.';
        });
        return;
      }
      final commonKeys = profileRows.first.map(keyFor).toSet();
      for (final rows in profileRows.skip(1)) {
        commonKeys.retainAll(rows.map(keyFor).toSet());
      }
      final profileNames =
          controller.currentAccount?.profiles ?? const <Profile>[];
      final tracksByKey = <String, MusicTrack>{};
      for (final track in MusicLibraryStore.instance.tracks) {
        tracksByKey[
                '${track.title.trim().toLowerCase()}|${track.artist.trim().toLowerCase()}'] =
            track;
      }
      final aggregates = <String, _CommonMusicAggregate>{};
      for (final key in commonKeys) {
        final perProfile = profileRows
            .map((rows) => rows.where((row) => keyFor(row) == key).length)
            .toList();
        var sharedPlays = perProfile.first;
        for (final plays in perProfile.skip(1)) {
          if (plays < sharedPlays) sharedPlays = plays;
        }
        final matchingEvents =
            profileRows.first.where((row) => keyFor(row) == key).toList();
        final event = matchingEvents.first;
        final track = tracksByKey[key] ??
            MusicTrack(
              id: (event['mediaId'] ?? key).toString(),
              title: (event['title'] ?? '').toString(),
              artist: (event['artist'] ?? 'Unknown artist').toString(),
              album: (event['album'] ?? '').toString(),
            );
        if (profileNames.any((profile) =>
            profileBlocksExplicitMusic(profile) && track.explicit ||
            profileBlocksMatureMusic(profile) && track.matureTheme)) {
          continue;
        }
        final aggregateKey = switch (widget.chartKey) {
          'songs' => key,
          'albums' =>
            '${track.album.trim().toLowerCase()}|${track.artist.trim().toLowerCase()}',
          _ => track.artist.trim().toLowerCase(),
        };
        if (aggregateKey.trim().isEmpty) continue;
        final aggregate = aggregates.putIfAbsent(
          aggregateKey,
          () => _CommonMusicAggregate(track: track),
        );
        aggregate.sharedPlays += sharedPlays;
      }
      final ordered = aggregates.values.where((aggregate) {
        if (widget.chartKey == 'bands') {
          return _isBandName(aggregate.track.artist);
        }
        if (widget.chartKey == 'singers') {
          return !_isBandName(aggregate.track.artist);
        }
        return true;
      }).toList()
        ..sort((a, b) {
          final plays = b.sharedPlays.compareTo(a.sharedPlays);
          return plays != 0
              ? plays
              : a.track.title
                  .toLowerCase()
                  .compareTo(b.track.title.toLowerCase());
        });
      final items = <_RankedItem>[];
      for (final aggregate in ordered.take(10)) {
        final track = aggregate.track;
        final isArtist =
            widget.chartKey == 'singers' || widget.chartKey == 'bands';
        final title = widget.chartKey == 'songs'
            ? track.title
            : widget.chartKey == 'albums'
                ? track.album
                : track.artist;
        if (title.trim().isEmpty) continue;
        final subtitle = isArtist
            ? '${aggregate.sharedPlays} shared listens across profiles'
            : '${track.artist} • ${aggregate.sharedPlays} shared listens';
        items.add(_musicItem(
          items.length + 1,
          title,
          subtitle,
          track.artworkUrl,
          MediaItem(
            id: 'account-common-${widget.chartKey}-${title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}',
            title: title,
            type: isArtist
                ? (widget.chartKey == 'bands' ? 'band' : 'artist')
                : widget.chartKey == 'songs'
                    ? 'song'
                    : 'album',
            imageUrl: track.artworkUrl,
            description: subtitle,
            music: <String>[track.artist],
          ),
          openArtistProfile: isArtist,
        ));
      }
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _items = items;
        _loading = false;
        _message = items.isEmpty
            ? 'No shared ${_categoryLabel(widget.chartKey).toLowerCase()} appear in completed listening from every profile yet.'
            : null;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _items = <_RankedItem>[];
        _loading = false;
        _message =
            'The account-wide common music Top 10 could not be calculated.';
      });
      debugPrint('Account common music Top 10 failed: $error');
    }
  }

  _RankedItem _musicItem(
    int rank,
    String title,
    String subtitle,
    String? imageUrl,
    MediaItem? media, {
    bool openArtistProfile = false,
  }) {
    return _RankedItem(
      rank: rank,
      title: title,
      subtitle: subtitle,
      imageUrl: imageUrl,
      media: media,
      onTap: openArtistProfile || media == null
          ? () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => MusicArtistProfileScreen(artistName: title),
              ))
          : () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => MediaDetailsScreen(media: media),
              )),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading && _items.isEmpty && _message == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 3),
                        Text(_subtitle,
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 11)),
                      ]),
                ),
                const Icon(Icons.trending_up_rounded, color: Colors.white54),
              ],
            ),
          ),
          if (_loading)
            const SizedBox(
                height: 130,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
          else if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
              child: Text(_message ?? 'No chart entries available.',
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
            )
          else
            HomeArrowRail(
              height: 235,
              itemCount: _items.length,
              separatorExtent: 12,
              padding: const EdgeInsets.symmetric(horizontal: 48),
              itemBuilder: (context, index) =>
                  _RankedPosterCard(item: _items[index]),
            ),
        ],
      ),
    );
  }

  String get _subtitle {
    if (widget.scopeKey == 'global') {
      return const <String>{
        'actors',
        'actresses',
        'directors',
        'writers',
        'composers'
      }.contains(widget.chartKey)
          ? 'Global TMDB popular people ranking'
          : 'Global ListenBrainz sitewide listening ranking';
    }
    if (widget.scopeKey == 'account') {
      return 'Shared activity and titles completed by every profile in this account';
    }
    return switch (widget.chartKey) {
      'actors' ||
      'actresses' =>
        'Cast credits from titles in this profile’s library',
      'directors' => 'Directors credited on this profile’s movies and shows',
      'writers' =>
        'Writers and screenwriters credited on this profile’s movies and shows',
      'composers' => 'Composers credited on this profile’s movies and shows',
      'albums' ||
      'songs' =>
        'Music library entries ranked by this profile’s listening activity',
      'singers' ||
      'bands' =>
        'Artists credited on this profile’s music library',
      _ => 'This profile’s Top 10',
    };
  }
}

class _RankedItem {
  const _RankedItem({
    required this.rank,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.media,
    required this.onTap,
  });
  final int rank;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final MediaItem? media;
  final VoidCallback onTap;

  MediaItem get previewMedia =>
      media ??
      MediaItem(
        id: 'weekly-chart-item-${title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}',
        title: title,
        type: 'chart item',
        imageUrl: imageUrl,
        description: subtitle,
      );
}

class _OwnedPersonAggregate {
  _OwnedPersonAggregate(this.name);
  final String name;
  int ownedTitleCount = 0;
  int score = 0;
  String? artworkUrl;
}

class _AlbumAggregate {
  _AlbumAggregate(this.title, this.artist, this.artworkUrl);
  final String title;
  final String artist;
  String? artworkUrl;
  int score = 0;
  final Set<String> _profileNames = <String>{};
  final Set<String> _profileIds = <String>{};
  final Set<String> _sources = <String>{};

  void observeAttribution(MusicTrack track) {
    final name = track.addedByProfileName?.trim() ?? '';
    final id = track.addedByProfileId?.trim() ?? '';
    final source = track.addedSource.trim();
    if (name.isNotEmpty) _profileNames.add(name);
    if (id.isNotEmpty) _profileIds.add(id);
    if (source.isNotEmpty && source.toLowerCase() != 'unknown') {
      _sources.add(source);
    }
  }

  String? get addedByProfileName => _profileNames.isEmpty
      ? null
      : (_profileNames.length == 1 ? _profileNames.first : 'multiple profiles');
  String? get addedByProfileId =>
      _profileIds.length == 1 ? _profileIds.first : null;
  String get addedSource => _sources.isEmpty ? 'unknown' : _sources.first;
}

class _CommonMusicAggregate {
  _CommonMusicAggregate({required this.track});
  final MusicTrack track;
  int sharedPlays = 0;
}

class _RankedPosterCard extends StatelessWidget {
  const _RankedPosterCard({required this.item});
  final _RankedItem item;

  @override
  Widget build(BuildContext context) {
    return HomeHeroHoverPreviewRegion(
        media: item.previewMedia,
        child: SizedBox(
          width: 140,
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: item.onTap,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Stack(fit: StackFit.expand, children: [
                    if (item.imageUrl?.trim().isNotEmpty == true)
                      Image.network(item.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _fallback())
                    else
                      _fallback(),
                    Positioned(
                      left: 7,
                      top: 7,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: .84),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text('#${item.rank}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 13)),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 7),
              Text(item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 12.5)),
              Text(item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: Colors.white54, fontSize: 10.5)),
              if (item.media != null)
                AddedByProfileLabel.forMedia(item.media!, compact: true),
            ]),
          ),
        ));
  }

  Widget _fallback() => Container(
        color: const Color(0xFF202020),
        alignment: Alignment.center,
        child: const Icon(Icons.trending_up_rounded,
            color: Colors.white38, size: 34),
      );
}

class WeeklyTop10LeaderboardShelf extends StatelessWidget {
  const WeeklyTop10LeaderboardShelf({super.key});

  static const List<(String, String, IconData)> _categories =
      <(String, String, IconData)>[
    ('movies', 'Movies', Icons.movie_rounded),
    ('shows', 'Shows', Icons.tv_rounded),
    ('albums', 'Albums', Icons.album_rounded),
    ('songs', 'Songs', Icons.music_note_rounded),
    ('actors', 'Actors', Icons.face_rounded),
    ('actresses', 'Actresses', Icons.face_3_rounded),
    ('directors', 'Directors', Icons.movie_creation_rounded),
    ('writers', 'Writers / Screenwriters', Icons.edit_rounded),
    ('composers', 'Composers', Icons.music_note_rounded),
    ('singers', 'Singers', Icons.mic_rounded),
    ('bands', 'Bands', Icons.groups_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: .12)),
          gradient: const LinearGradient(
              colors: <Color>[Color(0xFF20202A), Color(0xFF101013)]),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('RANKING OF ALL TOP 10S',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text(
              'Rankings come from items and credits in your own library.',
              style: TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final category in _categories)
              ActionChip(
                avatar: Icon(category.$3, size: 17),
                label: Text('Top 10 ${category.$2}'),
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) =>
                      WeeklyTop10RankingsScreen(initialChartKey: category.$1),
                )),
              ),
          ]),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const WeeklyTop10RankingsScreen())),
              icon: const Icon(Icons.leaderboard_rounded),
              label: const Text('View all rankings'),
            ),
          ),
        ]),
      ),
    );
  }
}

class WeeklyTop10RankingsScreen extends StatelessWidget {
  const WeeklyTop10RankingsScreen({super.key, this.initialChartKey});
  final String? initialChartKey;

  static const List<(String, String)> _charts = <(String, String)>[
    ('movies', 'YOUR TOP 10 OWNED MOVIES'),
    ('shows', 'YOUR TOP 10 OWNED SHOWS'),
    ('albums', 'YOUR TOP 10 OWNED ALBUMS'),
    ('songs', 'YOUR TOP 10 OWNED SONGS'),
    ('actors', 'YOUR TOP 10 ACTORS FROM OWNED TITLES'),
    ('actresses', 'YOUR TOP 10 ACTRESSES FROM OWNED TITLES'),
    ('directors', 'YOUR TOP 10 DIRECTORS FROM OWNED TITLES'),
    ('writers', 'YOUR TOP 10 WRITERS / SCREENWRITERS FROM OWNED TITLES'),
    ('composers', 'YOUR TOP 10 COMPOSERS FROM OWNED TITLES'),
    ('singers', 'YOUR TOP 10 SINGERS FROM OWNED TRACKS'),
    ('bands', 'YOUR TOP 10 BANDS FROM OWNED TRACKS'),
  ];

  @override
  Widget build(BuildContext context) {
    final charts = initialChartKey == null
        ? _charts
        : <(String, String)>[
            ..._charts.where((chart) => chart.$1 == initialChartKey),
            ..._charts.where((chart) => chart.$1 != initialChartKey),
          ];
    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      appBar: AppBar(
        title: const Text('Your Library Top 10 Rankings'),
        backgroundColor: const Color(0xFF101010),
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 50),
        children: [
          for (final chart in charts)
            WeeklyTop10Shelf(chartKey: chart.$1, title: chart.$2),
        ],
      ),
    );
  }
}

/// Converts common ISO-3166 codes emitted by TMDB to human-readable names.
String countryNameFromCode(String code) => formatCountryName(code);
