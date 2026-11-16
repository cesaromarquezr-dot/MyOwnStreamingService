import 'package:material_ui/material_ui.dart';

import 'app_core.dart';
import 'music.dart';

/// A profile-scoped achievement computed from actual library and playback data.
/// The passport never inserts demo titles or awards achievements manually.
class PassportAchievement {
  final String title;
  final String category;
  final String description;
  final IconData icon;
  final int progress;
  final int target;

  const PassportAchievement({
    required this.title,
    required this.category,
    required this.description,
    required this.icon,
    required this.progress,
    required this.target,
  });

  bool get unlocked => progress >= target;
  double get fraction =>
      target <= 0 ? 0 : (progress / target).clamp(0.0, 1.0).toDouble();
}

/// Builds achievement stamps from the active profile's real watched media,
/// imported metadata, collections, playlists and listen counters.
class EntertainmentPassportEngine {
  const EntertainmentPassportEngine._();

  static List<PassportAchievement> build({
    required AppController app,
    required MusicLibraryStore music,
  }) {
    final watchedById = <String, MediaItem>{};
    for (final item in app.watched) {
      if (item.id.trim().isNotEmpty) watchedById[item.id] = item;
    }
    final watched = watchedById.values.toList(growable: false);
    final profileId = app.currentProfile?.id;
    final profileCollections = app.collections
        .where((collection) =>
            profileId != null &&
            (collection.createdByProfileId == profileId ||
                collection.contributorProfileIds.contains(profileId)))
        .toList(growable: false);
    String normalizedType(MediaItem item) => item.type
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');

    final movies = watched
        .where((item) =>
            normalizedType(item).contains('movie') ||
            normalizedType(item).contains('film'))
        .toList(growable: false);
    final shows = watched
        .where((item) =>
            item.isSeries ||
            normalizedType(item) == 'episode' ||
            normalizedType(item) == 'tv')
        .toList(growable: false);

    final genres = <String>{};
    final actors = <String>{};
    final directors = <String>{};
    final decades = <int>{};
    final franchiseTitles = <String, Set<String>>{};
    final studioTitles = <String, Set<String>>{};
    var horrorTitles = 0;

    for (final item in watched) {
      genres.addAll(item.genres
          .map((value) => _clean(value).toLowerCase())
          .where((value) => value.isNotEmpty));
      actors.addAll(item.actors
          .map((value) => _clean(value).toLowerCase())
          .where((value) => value.isNotEmpty));
      directors.addAll(item.directors
          .map((value) => _clean(value).toLowerCase())
          .where((value) => value.isNotEmpty));
      final year = item.releaseYear ??
          item.seriesStartYear ??
          item.releaseDate?.year ??
          item.seriesStartDate?.year;
      if (year != null && year > 0) decades.add((year ~/ 10) * 10);
      if (item.genres.any((genre) => genre.toLowerCase().contains('horror'))) {
        horrorTitles++;
      }
      final franchiseNames = <String>{
        if (_clean(item.franchiseName ?? '').isNotEmpty)
          _clean(item.franchiseName!),
        ...item.franchiseNames.map(_clean).where((value) => value.isNotEmpty),
        ...item.cinematicUniverseNames
            .map(_clean)
            .where((value) => value.isNotEmpty),
      };
      for (final name in franchiseNames) {
        franchiseTitles.putIfAbsent(name, () => <String>{}).add(item.id);
      }
      final studioNames = <String>{
        ...item.studios.map(_clean).where((value) => value.isNotEmpty),
        ...item.companies.map(_clean).where((value) => value.isNotEmpty),
      };
      for (final name in studioNames) {
        studioTitles.putIfAbsent(name, () => <String>{}).add(item.id);
      }
    }

    final listenedTracks = music.tracks
        .where((track) => (music.listenCounts[track.id] ?? 0) > 0)
        .toList(growable: false);
    final listenedArtists = listenedTracks
        .map((track) => _clean(track.artist))
        .where((value) => value.isNotEmpty)
        .toSet();
    final listenedAlbums = listenedTracks
        .where((track) =>
            _clean(track.artist).isNotEmpty && _clean(track.album).isNotEmpty)
        .map((track) => '${_clean(track.artist)}|${_clean(track.album)}')
        .toSet();
    final listenCount = listenedTracks.fold<int>(
      0,
      (total, track) => total + (music.listenCounts[track.id] ?? 0),
    );
    final allGenres = <String>{
      ...genres,
      ...music.tracks
          .where((track) => (music.listenCounts[track.id] ?? 0) > 0)
          .expand((track) =>
              track.allGenreTags.map((value) => _clean(value).toLowerCase()))
          .where((value) => value.isNotEmpty),
    };

    final badges = <PassportAchievement>[
      PassportAchievement(
        title: 'Movie Explorer',
        category: 'Movies',
        description: 'Watch 10 different movies.',
        icon: Icons.movie_creation_outlined,
        progress: movies.map((item) => item.id).toSet().length,
        target: 10,
      ),
      PassportAchievement(
        title: 'Series Explorer',
        category: 'TV',
        description: 'Watch 5 different series or shows.',
        icon: Icons.tv_outlined,
        progress: shows.map((item) => item.id).toSet().length,
        target: 5,
      ),
      PassportAchievement(
        title: 'Music Explorer',
        category: 'Music',
        description: 'Listen to music by 10 different artists.',
        icon: Icons.library_music_outlined,
        progress: listenedArtists.length,
        target: 10,
      ),
      PassportAchievement(
        title: 'Album Collector',
        category: 'Music',
        description: 'Listen to tracks from 10 different albums.',
        icon: Icons.album_outlined,
        progress: listenedAlbums.length,
        target: 10,
      ),
      PassportAchievement(
        title: 'Genre Explorer',
        category: 'Discovery',
        description:
            'Explore 8 different genres across watched and listened media.',
        icon: Icons.explore_outlined,
        progress: allGenres.length,
        target: 8,
      ),
      PassportAchievement(
        title: 'Director Explorer',
        category: 'People',
        description: 'Discover work from 10 different directors.',
        icon: Icons.movie_filter_outlined,
        progress: directors.length,
        target: 10,
      ),
      PassportAchievement(
        title: 'Cast Explorer',
        category: 'People',
        description: 'Discover 20 different credited performers.',
        icon: Icons.people_alt_outlined,
        progress: actors.length,
        target: 20,
      ),
      PassportAchievement(
        title: 'Decade Explorer',
        category: 'Time Travel',
        description: 'Watch titles released in 5 different decades.',
        icon: Icons.history_toggle_off_rounded,
        progress: decades.length,
        target: 5,
      ),
      PassportAchievement(
        title: 'Horror Fan',
        category: 'Genres',
        description: 'Watch 5 titles tagged with the Horror genre.',
        icon: Icons.nightlight_outlined,
        progress: horrorTitles,
        target: 5,
      ),
      PassportAchievement(
        title: 'Listening Legend',
        category: 'Music',
        description: 'Reach 100 recorded music listens.',
        icon: Icons.headphones_rounded,
        progress: listenCount,
        target: 100,
      ),
      PassportAchievement(
        title: 'Collection Curator',
        category: 'Collections',
        description: 'Create or own 5 media collections.',
        icon: Icons.collections_bookmark_outlined,
        progress: profileCollections.length,
        target: 5,
      ),
    ];

    // These personalized stamps are generated only from franchise/universe and
    // studio/company metadata actually attached to watched titles.
    final franchiseEntries = franchiseTitles.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    for (final entry in franchiseEntries.take(5)) {
      badges.add(PassportAchievement(
        title: 'Franchise Explorer · ${entry.key}',
        category: 'Franchises',
        description:
            'Watch 3 distinct titles from this verified franchise or universe.',
        icon: Icons.auto_awesome_mosaic_outlined,
        progress: entry.value.length,
        target: 3,
      ));
    }
    final studioEntries = studioTitles.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    for (final entry in studioEntries.take(5)) {
      badges.add(PassportAchievement(
        title: 'Studio Collector · ${entry.key}',
        category: 'Studios',
        description:
            'Watch 3 distinct titles associated with this studio or company.',
        icon: Icons.business_outlined,
        progress: entry.value.length,
        target: 3,
      ));
    }

    badges.sort((a, b) {
      if (a.unlocked != b.unlocked) return a.unlocked ? -1 : 1;
      final progressCompare = b.fraction.compareTo(a.fraction);
      if (progressCompare != 0) return progressCompare;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return List<PassportAchievement>.unmodifiable(badges);
  }

  static String _clean(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ');
}

/// Collectible, read-only achievement passport for the currently selected
/// profile. Stamps are recalculated from that profile's local library state.
class EntertainmentPassportScreen extends StatefulWidget {
  const EntertainmentPassportScreen({super.key});

  @override
  State<EntertainmentPassportScreen> createState() =>
      _EntertainmentPassportScreenState();
}

class _EntertainmentPassportScreenState
    extends State<EntertainmentPassportScreen> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final app = AppController.instance;
    final music = MusicLibraryStore.instance;
    final achievements =
        EntertainmentPassportEngine.build(app: app, music: music);
    final profileId = app.currentProfile?.id;
    final accessibleLibraryCount = app.library
        .where((item) => item.isAccessibleTo(app.currentProfile))
        .length;
    final curatedCollectionCount = app.collections
        .where((collection) =>
            profileId != null &&
            (collection.createdByProfileId == profileId ||
                collection.contributorProfileIds.contains(profileId)))
        .length;
    final unlocked = achievements.where((badge) => badge.unlocked).length;
    final visible = achievements
        .where((badge) => switch (_filter) {
              'Unlocked' => badge.unlocked,
              'In progress' => !badge.unlocked,
              _ => true,
            })
        .toList(growable: false);
    final profileName = app.currentProfile?.name ?? 'Current profile';
    final totalListens = music.tracks.fold<int>(
      0,
      (sum, track) =>
          sum +
          ((music.listenCounts[track.id] ?? 0) > 0
              ? music.listenCounts[track.id]!
              : 0),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Entertainment Passport')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primary.withValues(alpha: .24),
                  Theme.of(context).colorScheme.tertiary.withValues(alpha: .12),
                ],
              ),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: .24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.card_membership_rounded, size: 38),
                const SizedBox(height: 10),
                const Text(
                  'Your entertainment journey',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                    '$profileName · $unlocked of ${achievements.length} stamps unlocked'),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value:
                      achievements.isEmpty ? 0 : unlocked / achievements.length,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(8),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _summaryChip(
                  Icons.movie_outlined, '${app.watched.length} watched'),
              _summaryChip(
                  Icons.library_music_outlined, '$totalListens listens'),
              _summaryChip(Icons.video_library_outlined,
                  '$accessibleLibraryCount library items'),
              _summaryChip(Icons.collections_bookmark_outlined,
                  '$curatedCollectionCount collections'),
            ],
          ),
          const SizedBox(height: 18),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment<String>(value: 'All', label: Text('All')),
              ButtonSegment<String>(value: 'Unlocked', label: Text('Unlocked')),
              ButtonSegment<String>(
                  value: 'In progress', label: Text('In progress')),
            ],
            selected: <String>{_filter},
            onSelectionChanged: (selection) =>
                setState(() => _filter = selection.first),
          ),
          const SizedBox(height: 14),
          if (visible.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text('There are no stamps in this filter yet.'),
              ),
            )
          else
            ...visible.map((badge) => _PassportStampCard(badge: badge)),
          const SizedBox(height: 10),
          const Text(
            'Stamps are calculated from this profile’s recorded library metadata and playback counts. Franchise and studio stamps appear only when those relationships exist in your own catalog. Nothing is awarded from sample titles, and your passport is not shared automatically.',
            style: TextStyle(fontSize: 12, height: 1.4, color: Colors.white60),
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(IconData icon, String label) => Chip(
        avatar: Icon(icon, size: 16),
        label: Text(label),
        visualDensity: VisualDensity.compact,
      );
}

class _PassportStampCard extends StatelessWidget {
  final PassportAchievement badge;
  const _PassportStampCard({required this.badge});

  @override
  Widget build(BuildContext context) {
    final color = badge.unlocked
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: .52);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
                color: color.withValues(alpha: .10),
              ),
              child: Icon(
                  badge.unlocked ? badge.icon : Icons.lock_outline_rounded,
                  color: color,
                  size: 27),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(badge.title,
                            style:
                                const TextStyle(fontWeight: FontWeight.w900)),
                      ),
                      Text(
                        badge.unlocked
                            ? 'Unlocked'
                            : '${badge.progress}/${badge.target}',
                        style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text('${badge.category} · ${badge.description}',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 9),
                  LinearProgressIndicator(
                    value: badge.fraction,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(8),
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
