// FILE: lib/film.dart.
// Purpose: Provides the dedicated Film experience for movies, TV, trailers,
// people, franchises, genres and geographic associations.

import 'package:flutter/material.dart';

import 'app_core.dart';
import 'details.dart';
import 'localization.dart';
import 'media_text_localizer.dart';
import 'movies.dart';
import 'series.dart';

/// Unified movie/TV experience. Individual playback and metadata still open
/// through the existing Details and player systems.
class FilmExperienceScreen extends StatefulWidget {
  const FilmExperienceScreen({super.key});

  @override
  State<FilmExperienceScreen> createState() => _FilmExperienceScreenState();
}

class _FilmExperienceScreenState extends State<FilmExperienceScreen> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final library = AppController.instance.library;
    final movies = library
        .where((m) =>
            m.type.toLowerCase().contains('movie') ||
            m.type.toLowerCase().contains('film'))
        .toList();
    final shows = library
        .where((m) =>
            m.type.toLowerCase().contains('show') ||
            m.type.toLowerCase().contains('series'))
        .toList();
    final trailers = library
        .where((m) => m.trailerUrl != null && m.trailerUrl!.isNotEmpty)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const UniversalText('Film'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          _hero(context, library),
          if (library.any(
              (m) => m.imageUrl != null && m.imageUrl!.trim().isNotEmpty)) ...[
            const SizedBox(height: 18),
            _FilmArtworkShowcase(
                items: library
                    .where((m) =>
                        m.imageUrl != null && m.imageUrl!.trim().isNotEmpty)
                    .toList()),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('Movies', Icons.movie_outlined,
                  () => _open(context, const MoviesScreen())),
              _chip('TV Shows', Icons.tv_outlined,
                  () => _open(context, const SeriesScreen())),
              _chip('Trailers', Icons.play_circle_outline,
                  () => _showItems(context, 'Trailers', trailers)),
              _chip(
                  'People',
                  Icons.people_outline,
                  () =>
                      _showDirectory(context, 'People', Icons.people_outline)),
              _chip(
                  'Franchises',
                  Icons.account_tree_outlined,
                  () => _showDirectory(
                      context, 'Franchises', Icons.account_tree_outlined)),
              _chip(
                  'Genres',
                  Icons.category_outlined,
                  () => _showDirectory(
                      context, 'Genres', Icons.category_outlined)),
              _chip(
                  'Countries',
                  Icons.public_outlined,
                  () => _showDirectory(context, 'Geographic Associations',
                      Icons.public_outlined)),
            ],
          ),
          const SizedBox(height: 18),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                  value: 0,
                  label: UniversalText('All'),
                  icon: Icon(Icons.apps_rounded)),
              ButtonSegment(
                  value: 1,
                  label: UniversalText('Movies'),
                  icon: Icon(Icons.movie_outlined)),
              ButtonSegment(
                  value: 2,
                  label: UniversalText('TV'),
                  icon: Icon(Icons.tv_outlined)),
            ],
            selected: {tab},
            onSelectionChanged: (value) => setState(() => tab = value.first),
          ),
          const SizedBox(height: 18),
          if (library.isEmpty)
            const Card(
                child: Padding(
                    padding: EdgeInsets.all(24),
                    child: UniversalText(
                        'Your Film experience will populate as movies and shows are imported.')))
          else
            ..._sections(
                context,
                tab == 1
                    ? movies
                    : tab == 2
                        ? shows
                        : library),
        ],
      ),
    );
  }

  Widget _hero(BuildContext context, List<MediaItem> library) {
    final artwork = library
        .where((m) => m.imageUrl != null && m.imageUrl!.trim().isNotEmpty)
        .toList();
    final featured = artwork.isEmpty ? null : artwork.first;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOutCubic,
      height: featured == null ? 190 : 270,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white12),
        image: featured == null
            ? null
            : DecorationImage(
                image: NetworkImage(featured.imageUrl!),
                fit: BoxFit.cover,
                onError: (_, __) {},
                colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: .58), BlendMode.darken),
              ),
      ),
      child: Stack(fit: StackFit.expand, children: [
        if (featured != null)
          DecoratedBox(
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                Colors.black.withValues(alpha: .92),
                Colors.black.withValues(alpha: .36)
              ]))),
        Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.movie_creation_outlined, size: 38),
                  const SizedBox(height: 10),
                  const UniversalText('Your Film Universe',
                      style:
                          TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  UniversalText(
                      featured == null
                          ? 'Your screen stays dark until your library has artwork. Movies, shows and trailers live together here.'
                          : '${featured.title}  •  Movies, shows and stories from your library',
                      style:
                          const TextStyle(color: Colors.white70, height: 1.4)),
                ])),
      ]),
    );
  }

  List<Widget> _sections(BuildContext context, List<MediaItem> items) {
    final movies = items
        .where((m) =>
            m.type.toLowerCase().contains('movie') ||
            m.type.toLowerCase().contains('film'))
        .take(12)
        .toList();
    final shows = items
        .where((m) =>
            m.type.toLowerCase().contains('show') ||
            m.type.toLowerCase().contains('series'))
        .take(12)
        .toList();
    final recent = List<MediaItem>.from(items)
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return [
      if (movies.isNotEmpty)
        _mediaSection(context, 'Movies', movies, Icons.movie_outlined),
      if (shows.isNotEmpty)
        _mediaSection(context, 'TV Shows', shows, Icons.tv_outlined),
      if (movies.isEmpty && shows.isEmpty)
        _mediaSection(context, 'Library', recent.take(20).toList(),
            Icons.video_library_outlined),
    ];
  }

  Widget _mediaSection(BuildContext context, String title,
          List<MediaItem> items, IconData icon) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900))
        ]),
        const SizedBox(height: 8),
        ...items.map((item) => Card(
                child: ListTile(
              leading: item.imageUrl == null
                  ? const Icon(Icons.movie_outlined)
                  : Image.network(item.imageUrl!,
                      width: 48,
                      height: 68,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.movie_outlined)),
              title: LocalizedMediaText(item.title),
              subtitle: Text(
                  '${item.type}${item.releaseYear == null ? '' : ' • ${item.releaseYear}'}'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => MediaDetailsScreen(media: item))),
            ))),
        const SizedBox(height: 14),
      ]);

  Widget _chip(String title, IconData icon, VoidCallback action) => ActionChip(
      avatar: Icon(icon, size: 18), label: Text(title), onPressed: action);

  void _open(BuildContext? context, Widget page) {
    if (context == null) return;
    final pageId = switch (page) {
      MoviesScreen() => 'movies',
      SeriesScreen() => 'series',
      _ => 'movies',
    };
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: RouteSettings(name: '/app/page/$pageId'),
        builder: (_) => page,
      ),
    );
  }

  void _showItems(BuildContext context, String title, List<MediaItem> items) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => _FilmItemListScreen(title: title, items: items)));
  }

  void _showDirectory(BuildContext context, String title, IconData icon) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => _FilmDirectoryScreen(title: title, icon: icon)));
  }
}

class _FilmItemListScreen extends StatelessWidget {
  final String title;
  final List<MediaItem> items;
  const _FilmItemListScreen({required this.title, required this.items});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ListView(
            padding: const EdgeInsets.all(16),
            children: items
                .map((item) => Card(
                    child: ListTile(
                        title: LocalizedMediaText(item.title),
                        subtitle: Text(item.type),
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    MediaDetailsScreen(media: item))))))
                .toList()),
      );
}

class _FilmDirectoryScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  const _FilmDirectoryScreen({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ListView(padding: const EdgeInsets.all(18), children: [
          Icon(icon, size: 52),
          const SizedBox(height: 12),
          Text(title,
              style:
                  const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const UniversalText(
              'This directory is connected to the global Media Universe and will populate from imported/catalog metadata without exposing another account’s ownership.',
              style: TextStyle(color: Colors.white60)),
        ]),
      );
}

/// Content-aware animated poster rail for the Film experience. It is only
/// rendered when real library artwork exists; empty libraries stay black.
class _FilmArtworkShowcase extends StatefulWidget {
  final List<MediaItem> items;
  const _FilmArtworkShowcase({required this.items});

  @override
  State<_FilmArtworkShowcase> createState() => _FilmArtworkShowcaseState();
}

class _FilmArtworkShowcaseState extends State<_FilmArtworkShowcase> {
  @override
  Widget build(BuildContext context) {
    final items = widget.items.take(12).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const UniversalText('From your library',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
      const SizedBox(height: 12),
      SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              return TweenAnimationBuilder<double>(
                key: ValueKey('film-art-${item.id}'),
                tween: Tween(begin: .88, end: 1),
                duration: Duration(milliseconds: 350 + (index % 5) * 90),
                curve: Curves.easeOutCubic,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: SizedBox(
                    width: 126,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => MediaDetailsScreen(media: item))),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Hero(
                                      tag: 'film-art-${item.id}',
                                      child: Image.network(
                                        item.imageUrl!,
                                        width: 126,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const ColoredBox(
                                                color: Colors.black,
                                                child: Center(
                                                    child: Icon(
                                                        Icons.movie_outlined))),
                                      ),
                                    ))),
                            const SizedBox(height: 7),
                            Text(item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                          ]),
                    )),
              );
            },
          )),
    ]);
  }
}
