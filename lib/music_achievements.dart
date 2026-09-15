import 'package:flutter/material.dart';

import 'music.dart';
import 'localization.dart';

class MusicAchievementsScreen extends StatelessWidget {
  const MusicAchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: MusicLibraryStore.instance,
      builder: (context, _) {
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
        final totalListens = store.listenCounts.values.fold<int>(0, (sum, count) => sum + count);
        final taylorSwift = tracks.any(
          (track) => track.artist.trim().toLowerCase() == 'taylor swift',
        );

        final badges = <_MusicAchievement>[
          _MusicAchievement(
            title: tr('Cultured'),
            description: tr('Explore at least 25 different artists.'),
            icon: Icons.public_rounded,
            progress: artists.length,
            target: 25,
          ),
          _MusicAchievement(
            title: tr('Swiftie'),
            description: tr('Have Taylor Swift in your music library.'),
            icon: Icons.star_rounded,
            progress: taylorSwift ? 1 : 0,
            target: 1,
          ),
          _MusicAchievement(
            title: tr('Album Collector'),
            description: tr('Collect at least 10 different albums.'),
            icon: Icons.album_rounded,
            progress: albums.length,
            target: 10,
          ),
          _MusicAchievement(
            title: tr('Genre Explorer'),
            description: tr('Explore at least 8 different genres.'),
            icon: Icons.explore_rounded,
            progress: genres.length,
            target: 8,
          ),
          _MusicAchievement(
            title: tr('On Repeat'),
            description: tr('Reach 100 total music listens.'),
            icon: Icons.repeat_rounded,
            progress: totalListens,
            target: 100,
          ),
        ];

        final unlocked = badges.where((badge) => badge.unlocked).length;

        return Scaffold(
          appBar: AppBar(
            title: const UniversalText('Music Achievements'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: <Widget>[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: <Widget>[
                      const CircleAvatar(
                        radius: 30,
                        child: Icon(Icons.emoji_events_rounded, size: 30),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const UniversalText('Music Achievements',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 4),
                            UniversalText('$unlocked of ${badges.length} badges unlocked'),
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
          ),
        );
      },
    );
  }

  Widget _achievementTile(_MusicAchievement badge) {
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
          children: <Widget>[
            CircleAvatar(
              radius: 25,
              child: Icon(badge.unlocked ? badge.icon : Icons.lock_outline_rounded),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
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
                          color: badge.unlocked ? Colors.greenAccent : Colors.white60,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(badge.description, style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 9),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(value: ratio, minHeight: 6),
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

class _MusicAchievement {
  final String title;
  final String description;
  final IconData icon;
  final int progress;
  final int target;

  const _MusicAchievement({
    required this.title,
    required this.description,
    required this.icon,
    required this.progress,
    required this.target,
  });

  bool get unlocked => progress >= target;
}
