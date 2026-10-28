import 'package:flutter/material.dart';

import 'app_core.dart';
import 'details.dart';
import 'media_metadata_catalog_screen.dart';
import 'music.dart';
import 'profile_content_safety.dart';
import 'home_arrow_rail.dart';

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
      if (_isMusicChart) {
        _loadMusicChart();
      } else {
        _loadTmdbChart();
      }
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
    if (!AppController.instance.isBackendAuthenticated) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _items = <_RankedItem>[];
        _message = 'Sign in to load this week\'s live TMDB rankings.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final path = switch (widget.chartKey) {
        'movies' => '/trending/movie/week',
        'shows' => '/trending/tv/week',
        'actors' || 'actresses' => '/trending/person/week',
        _ => '/trending/movie/week',
      };
      final peopleChart = widget.chartKey == 'actors' || widget.chartKey == 'actresses';
      final rows = <Map<String, dynamic>>[];
      // TMDB's trending people list is mixed-gender. Fetch further pages only
      // when needed so each actor/actress chart can fill up to ten entries.
      final pagesToCheck = peopleChart ? 4 : 1;
      for (var page = 1; page <= pagesToCheck; page++) {
        final payload = await AppController.instance.backendApi.getTmdbMetadata(
          path,
          <String, String>{'page': '$page', 'language': 'en-US'},
        );
        final rawResults = payload['results'];
        if (rawResults is List) {
          rows.addAll(rawResults.whereType<Map>().map((row) => Map<String, dynamic>.from(row)));
        }
        if (!peopleChart) break;
        final matchingPeople = rows.where((row) {
          final gender = row['gender'] is num
              ? (row['gender'] as num).toInt()
              : int.tryParse(row['gender']?.toString() ?? '0') ?? 0;
          return widget.chartKey == 'actresses' ? gender == 1 : gender == 2;
        }).length;
        if (matchingPeople >= 10) break;
      }
      final filtered = rows.where((row) {
        if (!peopleChart) return true;
        final gender = row['gender'] is num
            ? (row['gender'] as num).toInt()
            : int.tryParse(row['gender']?.toString() ?? '0') ?? 0;
        return widget.chartKey == 'actresses' ? gender == 1 : gender == 2;
      }).take(10).toList(growable: false);
      final items = <_RankedItem>[];
      for (var index = 0; index < filtered.length; index++) {
        final row = filtered[index];
        final person = peopleChart;
        final isShow = widget.chartKey == 'shows';
        final id = row['id']?.toString() ?? '';
        final title = (person
                ? row['name']
                : (row[isShow ? 'name' : 'title'] ?? row['name'] ?? row['title']))
            ?.toString()
            .trim() ?? '';
        if (id.isEmpty || title.isEmpty) continue;
        final dateText = (row[isShow ? 'first_air_date' : 'release_date'] ?? '').toString();
        final parsedDate = DateTime.tryParse(dateText);
        final poster = (person ? row['profile_path'] : row['poster_path'])?.toString() ?? '';
        final imageUrl = poster.startsWith('/') ? 'https://image.tmdb.org/t/p/w500$poster' : null;
        final knownFor = row['known_for_department']?.toString().trim() ?? '';
        final mediaType = isShow ? 'tvshow' : 'movie';
        final countryCodes = row['origin_country'];
        final origin = countryCodes is List
            ? countryCodes.map((value) => countryNameFromCode(value.toString())).where((value) => value.isNotEmpty).join(', ')
            : '';
        final media = person
            ? null
            : MediaItem(
                id: 'tmdb-$mediaType-$id',
                title: title,
                type: mediaType,
                imageUrl: imageUrl,
                description: row['overview']?.toString(),
                releaseDate: parsedDate,
                releaseYear: parsedDate?.year,
                countryOfOrigin: origin.isEmpty ? null : origin,
                rating: row['vote_average'] is num ? (row['vote_average'] as num).toDouble() : null,
              );
        items.add(_RankedItem(
          rank: index + 1,
          title: title,
          subtitle: person
              ? (knownFor.isEmpty ? 'Trending this week' : '$knownFor • Trending this week')
              : <String>[if (parsedDate != null) '${parsedDate.year}', if (origin.isNotEmpty) origin, 'Trending this week'].join(' • '),
          imageUrl: imageUrl,
          media: media,
          onTap: person
              ? () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => MediaMetadataCatalogScreen(initialType: 'person', initialQuery: title),
                  ))
              : () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => MediaDetailsScreen(media: media!),
                  )),
        ));
      }
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _items = items;
        _loading = false;
        _message = items.isEmpty ? 'No ranked results are available for this chart right now.' : null;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _items = <_RankedItem>[];
        _loading = false;
        _message = 'Weekly chart unavailable. Check TMDB settings and backend access.';
      });
      debugPrint('Weekly Top 10 TMDB chart failed: $error');
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
      // Only timestamped plays from the rolling 7-day window count toward a
      // weekly chart. Old lifetime totals cannot be assigned to a week safely.
      int score(MusicTrack track) => store.weeklyListenCount(track.id);
      final ranked = <_RankedItem>[];

      if (widget.chartKey == 'songs') {
        final ordered = trackList.where((track) => score(track) > 0).toList()
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
            MediaItem(id: 'weekly-song-${track.id}', title: track.title, type: 'song', imageUrl: track.artworkUrl, music: <String>[track.artist, ...track.featuredArtists]),
          ));
        }
      } else if (widget.chartKey == 'albums') {
        final grouped = <String, _AlbumAggregate>{};
        for (final track in trackList) {
          if (score(track) <= 0 || track.album.trim().isEmpty) continue;
          final key = '${track.album.toLowerCase().trim()}|${track.artist.toLowerCase().trim()}';
          final value = grouped.putIfAbsent(key, () => _AlbumAggregate(track.album, track.artist, track.artworkUrl));
          value.score += score(track);
          value.artworkUrl ??= track.artworkUrl;
        }
        final ordered = grouped.values.toList()..sort((a, b) => b.score.compareTo(a.score));
        for (final album in ordered.take(10)) {
          final media = MediaItem(id: 'weekly-album-${album.title}-${album.artist}', title: album.title, type: 'album', imageUrl: album.artworkUrl, music: <String>[album.artist]);
          ranked.add(_musicItem(ranked.length + 1, album.title, album.artist, album.artworkUrl, media));
        }
      } else {
        final artistScores = <String, int>{};
        final artistImages = <String, String?>{};
        final artistNames = <String, String>{};
        for (final track in trackList) {
          final plays = score(track);
          if (plays <= 0) continue;
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
          ranked.add(_musicItem(ranked.length + 1, name, 'Your plays this week', artistImages[key], null));
        }
      }

      if (!mounted || requestId != _requestId) return;
      setState(() {
        _items = ranked;
        _loading = false;
        _message = ranked.isEmpty
            ? 'No plays have been recorded in the last 7 days for this profile yet. Play music to start building this weekly chart.'
            : null;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _items = <_RankedItem>[];
        _loading = false;
        _message = 'Unable to load this profile\'s listening chart.';
      });
      debugPrint('Weekly Top 10 music chart failed: $error');
    }
  }

  _RankedItem _musicItem(int rank, String title, String subtitle, String? imageUrl, MediaItem? media) {
    return _RankedItem(
      rank: rank,
      title: title,
      subtitle: subtitle,
      imageUrl: imageUrl,
      media: media,
      onTap: media == null
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
        'movies' || 'shows' || 'actors' || 'actresses' => 'TMDB trending over the last week',
        'albums' || 'songs' || 'singers' || 'bands' => "Your profile's listening activity over the last 7 days",
        _ => 'Weekly chart',
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
}

class _AlbumAggregate {
  _AlbumAggregate(this.title, this.artist, this.artworkUrl);
  final String title;
  final String artist;
  String? artworkUrl;
  int score = 0;
}

class _RankedPosterCard extends StatelessWidget {
  const _RankedPosterCard({required this.item});
  final _RankedItem item;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
        ]),
      ),
    );
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
          const Text('Open any weekly chart to see its full ranked list.', style: TextStyle(color: Colors.white60, fontSize: 12)),
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
    ('movies', 'THIS WEEK\'S TOP 10 MOVIES'),
    ('shows', 'THIS WEEK\'S TOP 10 SHOWS'),
    ('albums', 'THIS WEEK\'S TOP 10 ALBUMS'),
    ('songs', 'THIS WEEK\'S TOP 10 SONGS'),
    ('actors', 'THIS WEEK\'S TOP 10 ACTORS'),
    ('actresses', 'THIS WEEK\'S TOP 10 ACTRESSES'),
    ('singers', 'THIS WEEK\'S TOP 10 SINGERS'),
    ('bands', 'THIS WEEK\'S TOP 10 BANDS'),
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
        title: const Text('Weekly Top 10 Rankings'),
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
