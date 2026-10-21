// FILE: `lib/navigation_hubs.dart`.
// Purpose: Fixed primary-navigation hubs for Library and Friends.
// The primary navbar stays intentionally small; detailed destinations live
// inside these hubs or behind More.

import 'package:flutter/material.dart';
import 'backend_api.dart';
import 'app_core.dart';
import 'app_customization.dart';
import 'feature_center.dart';
import 'library_hubs.dart';
import 'library_release.dart';
import 'movies.dart';
import 'music.dart';
import 'my_tv.dart';
import 'series.dart';
import 'social_center.dart';
import 'localization.dart';

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
        final sectionDraft =
            AppSectionCustomizationStore.settingsFor(controller.currentProfile);
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

        final children = <Widget>[];
        final visibleEntrySections = settings.visibleSections
            .where((section) => entries.containsKey(section))
            .toList(growable: false);
        final availableWidth = (MediaQuery.sizeOf(context).width - 36)
            .clamp(180.0, 4000.0)
            .toDouble();
        // Honor the saved column preference while keeping each shortcut wide
        // enough to remain readable on narrow phones.
        final responsiveMaxColumns =
            (availableWidth / 118).floor().clamp(1, 6).toInt();
        final gridColumns =
            sectionDraft.libraryColumns.clamp(1, responsiveMaxColumns).toInt();
        final gridCardWidth =
            (availableWidth - (10 * (gridColumns - 1))) / gridColumns;
        var gridInserted = false;

        for (final section in settings.visibleSections) {
          if (section == 'summary') {
            children.add(
              Row(
                children: [
                  Expanded(
                      child: _statCard(context, 'Media', '${library.length}',
                          Icons.library_music_outlined)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _statCard(
                          context, 'Movies', '$movies', Icons.movie_outlined)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _statCard(
                          context, 'TV', '$shows', Icons.tv_outlined)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _statCard(
                          context, 'Music', '$music', Icons.album_outlined)),
                ],
              ),
            );
          } else if (section == 'storage') {
            children.add(
              Card(
                child: ListTile(
                  leading: const Icon(Icons.storage_rounded),
                  title: const UniversalText('Account-wide library storage'),
                  subtitle: Text(
                    'One physical copy lives on the account home NAS. ${controller.currentAccount?.profiles.length ?? 0} profiles share access while keeping their own progress, ratings and collections.',
                  ),
                ),
              ),
            );
          } else if (entries.containsKey(section)) {
            if (sectionDraft.libraryViewMode == 'Grid') {
              if (!gridInserted) {
                children.add(
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final itemSection in visibleEntrySections)
                        _hubGridCard(
                          context,
                          entries[itemSection]!,
                          width:
                              (sectionDraft.libraryWidgetSizes[itemSection] ==
                                          'Large' &&
                                      gridColumns > 1)
                                  ? gridCardWidth * 2 + 10
                                  : gridCardWidth,
                          size: sectionDraft.libraryWidgetSizes[itemSection] ??
                              'Medium',
                          compact: sectionDraft.libraryCardStyle == 'Compact',
                          landscape:
                              sectionDraft.libraryCardStyle == 'Landscape',
                        ),
                    ],
                  ),
                );
                gridInserted = true;
              }
            } else {
              children.add(
                _hubCard(
                  context,
                  entries[section]!,
                  compact: sectionDraft.libraryCardStyle == 'Compact',
                  landscape: sectionDraft.libraryCardStyle == 'Landscape',
                  size: sectionDraft.libraryWidgetSizes[section] ?? 'Medium',
                ),
              );
            }
          }
        }

        return _HubScaffold(
          title: 'Library',
          subtitle:
              'Everything published to this account’s shared home-server library.',
          icon: Icons.video_library_rounded,
          children: children,
        );
      },
    );
  }

  Widget _statCard(
      BuildContext context, String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22),
            const SizedBox(height: 8),
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900)),
            Text(title,
                style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class FriendsAndCommunitiesScreen extends StatelessWidget {
  final String? initialConversationId;

  const FriendsAndCommunitiesScreen({
    super.key,
    this.initialConversationId,
  });

  @override
  Widget build(BuildContext context) => SocialCenterScreen(
        initialConversationId: initialConversationId,
      );
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
                      Text(title,
                          style: const TextStyle(
                              fontSize: 28, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 5),
                      Text(subtitle,
                          style: const TextStyle(
                              color: Colors.white60, height: 1.4)),
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
  String size = 'Medium',
}) =>
    Card(
      child: ListTile(
        dense: compact || size == 'Small',
        minVerticalPadding:
            size == 'Large' ? 18 : (compact || size == 'Small' ? 3 : 8),
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

Widget _hubGridCard(
  BuildContext context,
  _HubEntry entry, {
  required double width,
  required String size,
  bool compact = false,
  bool landscape = false,
}) {
  final height = switch (size) {
    'Small' => 110.0,
    'Large' => 205.0,
    _ => 150.0,
  };
  final iconSize = switch (size) {
    'Small' => 22.0,
    'Large' => 38.0,
    _ => 30.0,
  };
  return SizedBox(
    width: width,
    height: height,
    child: Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: entry.onTap,
        child: Padding(
          padding: EdgeInsets.all(
              size == 'Small' ? 10 : (size == 'Large' ? 18 : 14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(entry.icon, size: iconSize),
              const Spacer(),
              Text(entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              if (size != 'Small') ...[
                const SizedBox(height: 4),
                Text(entry.subtitle,
                    maxLines: size == 'Large' ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: Colors.white60, fontSize: 11)),
              ],
              if (landscape || compact)
                const Align(
                    alignment: Alignment.bottomRight,
                    child: Icon(Icons.chevron_right_rounded, size: 18)),
            ],
          ),
        ),
      ),
    ),
  );
}

void _push(BuildContext context, Widget page) {
  final pageId = switch (page) {
    MoviesScreen() => 'movies',
    SeriesScreen() => 'series',
    MusicScreen() => 'music',
    LibraryActorsScreen() => 'actors',
    CollectionsPanel() => 'collections',
    MyTvScreen() => 'my-tv',
    FavoritesScreen() => 'favorites',
    ComingSoonScreen() => 'coming-soon',
    _ => null,
  };
  Navigator.push(
    context,
    MaterialPageRoute(
      settings:
          pageId == null ? null : RouteSettings(name: '/app/page/$pageId'),
      builder: (_) => page,
    ),
  );
}
