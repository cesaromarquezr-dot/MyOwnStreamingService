// FILE: `lib/music_achievements.dart`.
// Purpose: Provides the unified profile achievements experience.
// Achievements are grouped into Music, Movies, and Shows instead of exposing
// a music-only destination.

import 'package:flutter/material.dart';

import 'app_core.dart';
import 'localization.dart';
import 'music.dart';

/// Displays the profile's achievements across music, movies, and shows.
class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const UniversalText('Achievements'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Music', icon: Icon(Icons.music_note_rounded)),
              Tab(text: 'Movies', icon: Icon(Icons.movie_outlined)),
              Tab(text: 'Shows', icon: Icon(Icons.tv_outlined)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _MusicAchievements(),
            _FilmAchievements(),
            _ShowAchievements(),
          ],
        ),
      ),
    );
  }
}

/// Builds music-specific achievements from the current music library.
class _MusicAchievements extends StatelessWidget {
  const _MusicAchievements();

  @override
  Widget build(BuildContext context) {
    final store = MusicLibraryStore.instance;
    final tracks = store.tracks;
    final artists = tracks
        .map((track) => track.artist.trim())
        .where((artist) => artist.isNotEmpty)
        .toSet();
    final albums = tracks
        .map((track) => '${track.artist.trim()} • ${track.album.trim()}')
        .where((album) => album != ' • ')
        .toSet();
    final genres = tracks
        .expand((track) => track.genres)
        .map((genre) => genre.trim().toLowerCase())
        .where((genre) => genre.isNotEmpty)
        .toSet();
    final totalListens = store.listenCounts.values.fold<int>(
      0,
      (sum, count) => sum + count,
    );
    final taylorSwift = tracks.any(
      (track) => track.artist.trim().toLowerCase() == 'taylor swift',
    );

    final badges = <_Achievement>[
      _Achievement(
        title: tr('Cultured'),
        description: tr('Explore at least 25 different artists.'),
        icon: Icons.public_rounded,
        progress: artists.length,
        target: 25,
      ),
      _Achievement(
        title: tr('Swiftie'),
        description: tr('Have Taylor Swift in your music library.'),
        icon: Icons.star_rounded,
        progress: taylorSwift ? 1 : 0,
        target: 1,
      ),
      _Achievement(
        title: tr('Album Collector'),
        description: tr('Collect at least 10 different albums.'),
        icon: Icons.album_rounded,
        progress: albums.length,
        target: 10,
      ),
      _Achievement(
        title: tr('Genre Explorer'),
        description: tr('Explore at least 8 different genres.'),
        icon: Icons.explore_rounded,
        progress: genres.length,
        target: 8,
      ),
      _Achievement(
        title: tr('On Repeat'),
        description: tr('Reach 100 total music listens.'),
        icon: Icons.repeat_rounded,
        progress: totalListens,
        target: 100,
      ),
    ];

    return _AchievementList(
      category: 'Music',
      badges: badges,
    );
  }
}

/// Builds movie-specific achievements from the profile's watched media.
class _FilmAchievements extends StatelessWidget {
  const _FilmAchievements();

  @override
  Widget build(BuildContext context) {
    final watched = AppController.instance.watched;
    final movies = watched.where((media) => media.type.trim().toLowerCase() == 'movie').toList();
    final uniqueMovies = movies.map((media) => media.id).toSet();
    final genres = movies
        .expand((media) => media.genres)
        .map((genre) => genre.trim().toLowerCase())
        .where((genre) => genre.isNotEmpty)
        .toSet();

    return _AchievementList(
      category: 'Movies',
      badges: [
        _Achievement(
          title: tr('Moviegoer'),
          description: tr('Watch at least 10 movies.'),
          icon: Icons.movie_creation_outlined,
          progress: uniqueMovies.length,
          target: 10,
        ),
        _Achievement(
          title: tr('Movie Marathon'),
          description: tr('Watch at least 50 movies.'),
          icon: Icons.local_movies_outlined,
          progress: uniqueMovies.length,
          target: 50,
        ),
        _Achievement(
          title: tr('Film Explorer'),
          description: tr('Explore at least 8 movie genres.'),
          icon: Icons.explore_outlined,
          progress: genres.length,
          target: 8,
        ),
      ],
    );
  }
}

/// Builds show-specific achievements from the profile's watched media.
class _ShowAchievements extends StatelessWidget {
  const _ShowAchievements();

  @override
  Widget build(BuildContext context) {
    final watched = AppController.instance.watched;
    final shows = watched.where((media) {
      final type = media.type.trim().toLowerCase();
      return type == 'tvshow' || type == 'tv_show' || type == 'tv show' || type == 'show' || type == 'series';
    }).toList();
    final uniqueShows = shows.map((media) => media.id).toSet();
    final genres = shows
        .expand((media) => media.genres)
        .map((genre) => genre.trim().toLowerCase())
        .where((genre) => genre.isNotEmpty)
        .toSet();

    return _AchievementList(
      category: 'Shows',
      badges: [
        _Achievement(
          title: tr('Series Explorer'),
          description: tr('Watch at least 5 shows.'),
          icon: Icons.tv_outlined,
          progress: uniqueShows.length,
          target: 5,
        ),
        _Achievement(
          title: tr('Binge Watcher'),
          description: tr('Watch at least 25 shows or series entries.'),
          icon: Icons.playlist_play_rounded,
          progress: uniqueShows.length,
          target: 25,
        ),
        _Achievement(
          title: tr('Show Explorer'),
          description: tr('Explore at least 8 show genres.'),
          icon: Icons.explore_outlined,
          progress: genres.length,
          target: 8,
        ),
      ],
    );
  }
}

/// Renders a category header and its achievement cards.
class _AchievementList extends StatelessWidget {
  final String category;
  final List<_Achievement> badges;

  const _AchievementList({
    required this.category,
    required this.badges,
  });

  @override
  Widget build(BuildContext context) {
    final unlocked = badges.where((badge) => badge.unlocked).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 30,
                  child: Icon(Icons.emoji_events_rounded, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UniversalText(
                        '$category Achievements',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      UniversalText(
                        '$unlocked of ${badges.length} badges unlocked',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final badge in badges) _achievementTile(badge),
      ],
    );
  }

  Widget _achievementTile(_Achievement badge) {
    final ratio = badge.target <= 0
        ? 0.0
        : (badge.progress / badge.target).clamp(0.0, 1.0).toDouble();
    final progressText = badge.target == 1 && badge.unlocked
        ? 'Unlocked'
        : '${badge.progress} / ${badge.target}';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              child: Icon(
                badge.unlocked
                    ? badge.icon
                    : Icons.lock_outline_rounded,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          badge.title,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      Text(
                        progressText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: badge.unlocked
                              ? Colors.greenAccent
                              : Colors.white60,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    badge.description,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 9),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Represents one achievement and its current progress.
class _Achievement {
  final String title;
  final String description;
  final IconData icon;
  final int progress;
  final int target;

  const _Achievement({
    required this.title,
    required this.description,
    required this.icon,
    required this.progress,
    required this.target,
  });

  bool get unlocked => progress >= target;
}
