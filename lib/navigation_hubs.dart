// FILE: `lib/navigation_hubs.dart`.
// Purpose: Fixed primary-navigation hubs for Library, Discover, and Friends.
// The primary navbar stays intentionally small; detailed destinations live
// inside these hubs or behind More.

import 'package:flutter/material.dart';

import 'app_core.dart';
import 'app_customization.dart';
import 'feature_center.dart';
import 'library_hubs.dart';
import 'library_release.dart';
import 'movies.dart';
import 'music.dart';
import 'my_tv.dart';
import 'radio.dart';
import 'reviews.dart';
import 'series.dart';
import 'smart_search.dart';
import 'social_center.dart';

class LibraryHubScreen extends StatelessWidget {
  const LibraryHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: PageContentCustomizationStore.revision,
      builder: (context, _) {
        final controller = AppController.instance;
        final library = controller.library;
        final movies =
            library.where((m) => m.type.toLowerCase().contains('movie')).length;
        final shows = library.where((m) {
          final type = m.type.toLowerCase();
          return type.contains('tv') ||
              type.contains('show') ||
              type.contains('series');
        }).length;
        final music = library.where((m) {
          final type = m.type.toLowerCase();
          return type.contains('music') ||
              type.contains('song') ||
              type.contains('album') ||
              type.contains('track');
        }).length;
        final settings = PageContentCustomizationStore.settingsFor('library');
        final sectionDraft = AppSectionCustomizationStore.settingsFor(controller.currentProfile);
        final entries = <String, _HubEntry>{
          'movies': _HubEntry(
            'Movies',
            'Movies in the account NAS library',
            Icons.movie_rounded,
            () => _push(context, const MoviesScreen()),
          ),
          'tv-shows': _HubEntry(
            'TV Shows',
            'Series and episodes',
            Icons.tv_rounded,
            () => _push(context, const SeriesScreen()),
          ),
          'music': _HubEntry(
            'Music',
            'Albums, artists and tracks',
            Icons.music_note_rounded,
            () => _push(context, const MusicScreen()),
          ),
          'radio': _HubEntry(
            'Radio',
            'Live and saved stations',
            Icons.radio_rounded,
            () => _push(context, const RadioScreen()),
          ),
          'collections': _HubEntry(
            'Collections',
            'Curated account collections',
            Icons.collections_bookmark_rounded,
            () => _push(context, const CollectionsPanel()),
          ),
          'my-tv': _HubEntry(
            'My TV',
            'Your television-focused library',
            Icons.live_tv_rounded,
            () => _push(context, const MyTvScreen()),
          ),
          'favorites': _HubEntry(
            'Favorites',
            'Liked media and music',
            Icons.favorite_rounded,
            () => _push(context, const FavoritesScreen()),
          ),
          'coming-soon': _HubEntry(
            'Coming Soon',
            'Scheduled library publications',
            Icons.schedule_rounded,
            () => _push(
              context,
              ComingSoonScreen(
                loader: controller.backendApi.getScheduledLibraryAdditions,
              ),
            ),
          ),
        };

        return _HubScaffold(
          title: 'Library',
          subtitle:
              'Everything published to this account’s shared home-server library.',
          icon: Icons.video_library_rounded,
          children: [
            for (final section in settings.visibleSections)
              if (section == 'summary')
                Row(
                  children: [
                    Expanded(
                      child: _statCard(
                        context,
                        'Media',
                        '${library.length}',
                        Icons.library_music_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _statCard(
                        context,
                        'Movies',
                        '$movies',
                        Icons.movie_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _statCard(
                        context,
                        'TV',
                        '$shows',
                        Icons.tv_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _statCard(
                        context,
                        'Music',
                        '$music',
                        Icons.album_outlined,
                      ),
                    ),
                  ],
                )
              else if (section == 'storage')
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.storage_rounded),
                    title: const Text('Account-wide library storage'),
                    subtitle: Text(
                      'One physical copy lives on the account home NAS. ${controller.currentAccount?.profiles.length ?? 0} profiles share access while keeping their own progress, ratings and collections.',
                    ),
                  ),
                )
              else if (entries[section] case final entry?)
                _hubCard(
                  context,
                  entry,
                  compact: sectionDraft.libraryCardStyle == 'Compact',
                  landscape: sectionDraft.libraryCardStyle == 'Landscape',
                ),
          ],
        );
      },
    );
  }

  Widget _statCard(BuildContext context, String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            Text(title, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class DiscoverHubScreen extends StatelessWidget {
  const DiscoverHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: PageContentCustomizationStore.revision,
      builder: (context, _) {
        final settings = PageContentCustomizationStore.settingsFor('discover');
        final entries = <String, _HubEntry>{
          'movies': _HubEntry(
            'Movies',
            'Browse your movie catalog',
            Icons.movie_rounded,
            () => _push(context, const MoviesScreen()),
          ),
          'tv-shows': _HubEntry(
            'TV Shows',
            'Browse series and episodes',
            Icons.tv_rounded,
            () => _push(context, const SeriesScreen()),
          ),
          'reviews': _HubEntry(
            'Reviews',
            'Read and publish reviews',
            Icons.rate_review_rounded,
            () => _push(context, const ReviewsHubScreen()),
          ),
          'people': _HubEntry(
            'People',
            'Actors, directors and media credits',
            Icons.people_alt_rounded,
            () => _push(context, const LibraryActorsScreen()),
          ),
          'music': _HubEntry(
            'Music',
            'Artists, albums and songs',
            Icons.music_note_rounded,
            () => _push(context, const MusicScreen()),
          ),
          'radio': _HubEntry(
            'Radio',
            'Discover live radio',
            Icons.radio_rounded,
            () => _push(context, const RadioScreen()),
          ),
        };
        return _HubScaffold(
          title: 'Discover',
          subtitle:
              'Find media, people, communities, reviews and everything else in the service.',
          icon: Icons.explore_rounded,
          children: [
            for (final section in settings.visibleSections)
              if (section == 'search')
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.search_rounded, size: 30),
                    title: const Text(
                      'Universal Search',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: const Text(
                      'Search movies, TV, music and the growing social catalog.',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _push(context, const SmartSearchScreen()),
                  ),
                )
              else if (entries[section] case final entry?)
                _hubCard(context, entry),
          ],
        );
      },
    );
  }
}

class FriendsAndCommunitiesScreen extends StatelessWidget {
  const FriendsAndCommunitiesScreen({super.key});

  @override
  Widget build(BuildContext context) => const SocialCenterScreen();
}

class _HubScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;

  const _HubScaffold({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(icon, size: 38),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 5),
                      Text(subtitle, style: const TextStyle(color: Colors.white60, height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        ...children,
      ],
    );
  }
}

class _HubEntry {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _HubEntry(this.title, this.subtitle, this.icon, this.onTap);
}

Widget _hubCard(
  BuildContext context,
  _HubEntry entry, {
  bool compact = false,
  bool landscape = false,
}) =>
    Card(
      child: ListTile(
        dense: compact,
        minVerticalPadding: compact ? 4 : 8,
        leading: landscape
            ? CircleAvatar(child: Icon(entry.icon, size: 20))
            : Icon(entry.icon),
        title: Text(
          entry.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          entry.subtitle,
          maxLines: landscape ? 1 : 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: entry.onTap,
      ),
    );

void _push(BuildContext context, Widget page) {
  final pageId = switch (page) {
    MoviesScreen() => 'movies',
    SeriesScreen() => 'series',
    MusicScreen() => 'music',
    LibraryActorsScreen() => 'actors',
    RadioScreen() => 'radio',
    CollectionsPanel() => 'collections',
    MyTvScreen() => 'my-tv',
    FavoritesScreen() => 'favorites',
    ComingSoonScreen() => 'coming-soon',
    SmartSearchScreen() => 'search',
    ReviewsHubScreen() => 'reviews',
    _ => null,
  };
  Navigator.push(
    context,
    MaterialPageRoute(
      settings: pageId == null ? null : RouteSettings(name: '/app/page/$pageId'),
      builder: (_) => page,
    ),
  );
}
