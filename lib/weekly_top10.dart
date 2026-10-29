import 'dart:async';

import 'package:flutter/material.dart';

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

/// Category shelves are intentionally data-driven so Home customization can
/// reorder or hide each chart independently.
class WeeklyTop10Shelf extends StatefulWidget {
  const WeeklyTop10Shelf({super.key, required this.chartKey, required this.title});

  final String chartKey;
  final String title;

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

  @override
  void initState() {
    super.initState();
    if (_isMusicChart) {
      MusicLibraryStore.instance.addListener(_refreshMusicChart);
      _loadMusicChart();
    } else {
      _loadTmdbChart();
    }
  }

  @override
  void didUpdateWidget(covariant WeeklyTop10Shelf oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chartKey != widget.chartKey) {
      final wasMusicChart = const <String>{'albums', 'songs', 'singers', 'bands'}
          .contains(oldWidget.chartKey);
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
          _loadTmdbChart();
        }
      });
    }
  }

  @override
  void dispose() {
    MusicLibraryStore.instance.removeListener(_refreshMusicChart);
    super.dispose();
  }

  bool get _isMusicChart => const <String>{'albums', 'songs', 'singers', 'bands'}
      .contains(widget.chartKey);

  void _refreshMusicChart() {
    if (_isMusicChart && mounted && !_musicInitializing) {
      _loadMusicChart(notify: false);
    }
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
          .where((media) => !media.tags.any((tag) =>
              const <String>{'demo-preview', 'preview-only', 'not-playable'}
                  .contains(tag.toLowerCase().trim())))
          .toList(growable: false);
      final items = <_RankedItem>[];

      bool isShow(MediaItem media) {
        final type = media.type.toLowerCase().replaceAll('_', ' ').trim();
        return media.isSeries || type == 'show' || type == 'tvshow' ||
            type == 'tv show' || type == 'series' || type == 'television';
      }

      bool isMovie(MediaItem media) {
        final type = media.type.toLowerCase().trim();
        return !isShow(media) &&
            (type == 'movie' || type == 'film' || type == 'feature' ||
                type == 'feature film' || type.contains('movie') || type.contains('film'));
      }

      int mediaScore(MediaItem media) {
        var score = 0;
        if (controller.liked.any((item) => item.id == media.id)) score += 180;
        if (controller.isWatched(media.id)) score += 90;
        score += ((media.userRatingStars ?? media.audienceRating ?? media.rating ?? 0) * 8).round();
        score += (controller.getPlaybackProgress(media.id) * 45).round();
        // Recently imported titles fill an otherwise tied Top 10 without
        // pretending that catalog-wide popularity describes the user's library.
        final ageDays = DateTime.now().difference(media.addedAt).inDays.clamp(0, 3650);
        score += (30 - (ageDays ~/ 30)).clamp(0, 30).toInt();
        return score;
      }

      if (widget.chartKey == 'movies' || widget.chartKey == 'shows') {
        final wantShows = widget.chartKey == 'shows';
        final ranked = visible.where((media) => wantShows ? isShow(media) : isMovie(media)).toList()
          ..sort((a, b) {
            final score = mediaScore(b).compareTo(mediaScore(a));
            if (score != 0) return score;
            final added = b.addedAt.compareTo(a.addedAt);
            return added != 0 ? added : a.title.toLowerCase().compareTo(b.title.toLowerCase());
          });
        for (final media in ranked.take(10)) {
          final status = <String>[
            if (controller.liked.any((item) => item.id == media.id)) 'Favorite',
            if (controller.isWatched(media.id)) 'Watched',
            if (controller.getPlaybackProgress(media.id) > 0 && controller.getPlaybackProgress(media.id) < 1)
              'In progress',
            if ((media.releaseYear ?? media.seriesStartYear) != null)
              '${media.releaseYear ?? media.seriesStartYear}',
          ];
          items.add(_RankedItem(
            rank: items.length + 1,
            title: media.title,
            subtitle: status.isEmpty ? 'Owned in your library' : status.join(' • '),
            imageUrl: media.imageUrl,
            media: media,
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => MediaDetailsScreen(media: media),
            )),
          ));
        }
      } else {
        // People charts are derived from actual credits attached to titles in
        // the active profile's library; no trending-person list can introduce
        // actors who are unrelated to owned media.
        final people = <String, _OwnedPersonAggregate>{};
        final explicitPersonItems = visible.where((media) {
          final type = media.type.toLowerCase().trim();
          return type == 'actor' || type == 'actress' || type == 'person';
        }).toList(growable: false);
        for (final media in visible) {
          if (!isMovie(media) && !isShow(media)) continue;
          final creditNames = media.actors.toSet();
          for (final rawName in creditNames) {
            final name = rawName.trim();
            if (name.isEmpty) continue;
            final key = name.toLowerCase();
            final aggregate = people.putIfAbsent(key, () => _OwnedPersonAggregate(name));
            aggregate.ownedTitleCount++;
            aggregate.score += 1 + (controller.isWatched(media.id) ? 2 : 0) +
                (controller.liked.any((item) => item.id == media.id) ? 2 : 0);
          }
        }
        final wantActresses = widget.chartKey == 'actresses';
        final explicitType = wantActresses ? 'actress' : 'actor';
        final explicitPersonByName = <String, MediaItem>{
          for (final person in explicitPersonItems.where((item) =>
              item.type.toLowerCase().trim() == explicitType))
            person.title.toLowerCase(): person,
        };
        final explicitNames = explicitPersonByName.keys.toSet();
        final entries = people.entries.where((entry) {
          // Gender is not inferred from a person's name. Actresses are included
          // only when person metadata explicitly classifies them as such.
          if (wantActresses) return explicitNames.contains(entry.key);
          return true;
        }).toList()
          ..sort((a, b) {
            final count = b.value.score.compareTo(a.value.score);
            if (count != 0) return count;
            return a.value.name.toLowerCase().compareTo(b.value.name.toLowerCase());
          });
        for (final entry in entries.take(10)) {
          final person = entry.value;
          final catalogPerson = explicitPersonByName[entry.key];
          items.add(_RankedItem(
            rank: items.length + 1,
            title: person.name,
            subtitle: '${person.ownedTitleCount} owned ${person.ownedTitleCount == 1 ? 'title' : 'titles'}',
            imageUrl: catalogPerson?.imageUrl ?? person.artworkUrl,
            media: catalogPerson,
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => MediaMetadataCatalogScreen(initialType: 'person', initialQuery: person.name),
            )),
          ));
        }
      }

      if (!mounted || requestId != _requestId) return;
      setState(() {
        _items = items;
        _loading = false;
        _message = items.isEmpty
            ? (widget.chartKey == 'actresses'
                ? 'No actress credits are linked to your owned titles yet. Import person metadata with explicit gender information to populate this chart.'
                : 'No matching items are in this profile’s library yet. Import media and its metadata to build this Top 10.')
            : null;
      });
      if (items.isNotEmpty &&
          (widget.chartKey == 'actors' || widget.chartKey == 'actresses')) {
        unawaited(_hydratePeopleArtwork(requestId));
      }
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _items = <_RankedItem>[];
        _loading = false;
        _message = 'Your library Top 10 could not be calculated. Check the library metadata and try again.';
      });
      debugPrint('Owned Top 10 chart failed: $error');
    }
  }

  Future<void> _hydratePeopleArtwork(int requestId) async {
    final startingItems = List<_RankedItem>.from(_items);
    for (final candidate in startingItems) {
      if (!mounted || requestId != _requestId) return;
      final portrait = await MediaArtworkAutoResolver.resolvePersonPortrait(
        candidate.title,
        pageId: EnergySaverController.instance.activePage,
      );
      if (portrait == null || portrait.isEmpty || !mounted || requestId != _requestId) {
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
            return byScore != 0 ? byScore : a.title.toLowerCase().compareTo(b.title.toLowerCase());
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
          final key = '${track.album.toLowerCase().trim()}|${track.artist.toLowerCase().trim()}';
          final value = grouped.putIfAbsent(
            key,
            () => _AlbumAggregate(track.album, track.artist, track.artworkUrl),
          );
          value.score += score(track);
          value.artworkUrl ??= track.artworkUrl;
          value.observeAttribution(track);
        }
        final ordered = grouped.values.toList()..sort((a, b) => b.score.compareTo(a.score));
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
          ranked.add(_musicItem(ranked.length + 1, album.title, album.artist, album.artworkUrl, media));
        }
      } else {
        final artistScores = <String, int>{};
        final artistImages = <String, String?>{};
        final artistNames = <String, String>{};
        for (final track in trackList) {
          final plays = score(track);
          final names = <String>{track.artist, ...track.featuredArtists}.where((name) => name.trim().isNotEmpty);
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
          return RegExp(r'\b(band|orchestra|ensemble|collective|quartet|trio|choir|group|company)\b').hasMatch(value) ||
              value.startsWith('the ') || value.contains(' & ') || value.contains(' and ');
        }
        final wantBands = widget.chartKey == 'bands';
        final keys = artistScores.keys.where((key) => isBand(artistNames[key] ?? '') == wantBands).toList()
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
              description: '${wantBands ? 'Band' : 'Singer / artist'} • From your owned tracks',
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
    if (!_loading && _items.isEmpty && _message == null) return const SizedBox.shrink();
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
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(_subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  ]),
                ),
                const Icon(Icons.trending_up_rounded, color: Colors.white54),
              ],
            ),
          ),
          if (_loading)
            const SizedBox(height: 130, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
          else if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
              child: Text(_message ?? 'No chart entries available.', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            )
          else
            HomeArrowRail(
              height: 235,
              itemCount: _items.length,
              separatorExtent: 12,
              padding: const EdgeInsets.symmetric(horizontal: 48),
              itemBuilder: (context, index) => _RankedPosterCard(item: _items[index]),
            ),
        ],
      ),
    );
  }

  String get _subtitle => switch (widget.chartKey) {
        'movies' || 'shows' => 'Your owned library, ratings, favorites and playback progress',
        'actors' || 'actresses' => 'Cast credits from movies and shows you own',
        'albums' || 'songs' => 'Albums and songs present in your music library, with listens as a tie-breaker',
        'singers' || 'bands' => 'Artists credited on music you own',
        _ => 'Your library ranking',
      };
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

  MediaItem get previewMedia => media ?? MediaItem(
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
  String? get addedByProfileId => _profileIds.length == 1 ? _profileIds.first : null;
  String get addedSource => _sources.isEmpty ? 'unknown' : _sources.first;
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Stack(fit: StackFit.expand, children: [
                if (item.imageUrl?.trim().isNotEmpty == true)
                  Image.network(item.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallback())
                else
                  _fallback(),
                Positioned(
                  left: 7,
                  top: 7,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: .84), borderRadius: BorderRadius.circular(8)),
                    child: Text('#${item.rank}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 7),
          Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
          Text(item.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 10.5)),
          if (item.media != null)
            AddedByProfileLabel.forMedia(item.media!, compact: true),
        ]),
      ),
    ));
  }

  Widget _fallback() => Container(
        color: const Color(0xFF202020),
        alignment: Alignment.center,
        child: const Icon(Icons.trending_up_rounded, color: Colors.white38, size: 34),
      );
}

class WeeklyTop10LeaderboardShelf extends StatelessWidget {
  const WeeklyTop10LeaderboardShelf({super.key});

  static const List<(String, String, IconData)> _categories = <(String, String, IconData)>[
    ('movies', 'Movies', Icons.movie_rounded),
    ('shows', 'Shows', Icons.tv_rounded),
    ('albums', 'Albums', Icons.album_rounded),
    ('songs', 'Songs', Icons.music_note_rounded),
    ('actors', 'Actors', Icons.face_rounded),
    ('actresses', 'Actresses', Icons.face_3_rounded),
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
          gradient: const LinearGradient(colors: <Color>[Color(0xFF20202A), Color(0xFF101013)]),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('RANKING OF ALL TOP 10S', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('Rankings come from items and credits in your own library.', style: TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final category in _categories)
              ActionChip(
                avatar: Icon(category.$3, size: 17),
                label: Text('Top 10 ${category.$2}'),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => WeeklyTop10RankingsScreen(initialChartKey: category.$1),
                )),
              ),
          ]),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const WeeklyTop10RankingsScreen())),
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
