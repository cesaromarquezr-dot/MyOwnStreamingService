// FILE: lib/film.dart.
// Purpose: Provides the dedicated Film experience for movies, TV, trailers,
// people, franchises, genres and geographic associations.

import 'package:flutter/material.dart';

import 'app_core.dart';
import 'details.dart';
import 'localization.dart';
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
        .where((m) => m.type.toLowerCase().contains('movie') || m.type.toLowerCase().contains('film'))
        .toList();
    final shows = library
        .where((m) => m.type.toLowerCase().contains('show') || m.type.toLowerCase().contains('series'))
        .toList();
    final trailers = library.where((m) => m.trailerUrl != null && m.trailerUrl!.isNotEmpty).toList();

    return Scaffold(
      appBar: AppBar(
        title: const UniversalText('Film'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          _hero(context),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('Movies', Icons.movie_outlined, () => _open(context, const MoviesScreen())),
              _chip('TV Shows', Icons.tv_outlined, () => _open(context, const SeriesScreen())),
              _chip('Trailers', Icons.play_circle_outline, () => _showItems(context, 'Trailers', trailers)),
              _chip('People', Icons.people_outline, () => _showDirectory(context, 'People', Icons.people_outline)),
              _chip('Franchises', Icons.account_tree_outlined, () => _showDirectory(context, 'Franchises', Icons.account_tree_outlined)),
              _chip('Genres', Icons.category_outlined, () => _showDirectory(context, 'Genres', Icons.category_outlined)),
              _chip('Countries', Icons.public_outlined, () => _showDirectory(context, 'Geographic Associations', Icons.public_outlined)),
            ],
          ),
          const SizedBox(height: 18),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('All'), icon: Icon(Icons.apps_rounded)),
              ButtonSegment(value: 1, label: Text('Movies'), icon: Icon(Icons.movie_outlined)),
              ButtonSegment(value: 2, label: Text('TV'), icon: Icon(Icons.tv_outlined)),
            ],
            selected: {tab},
            onSelectionChanged: (value) => setState(() => tab = value.first),
          ),
          const SizedBox(height: 18),
          if (library.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(24), child: UniversalText('Your Film experience will populate as movies and shows are imported.')))
          else
            ..._sections(context, tab == 1 ? movies : tab == 2 ? shows : library),
        ],
      ),
    );
  }

  Widget _hero(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white12),
          color: Colors.white.withValues(alpha: .045),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.movie_creation_outlined, size: 42),
          const SizedBox(height: 10),
          const UniversalText('Your Film Universe', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const UniversalText('Movies, shows, seasons, episodes, trailers, people, franchises and geographic connections in one dedicated experience.', style: TextStyle(color: Colors.white60, height: 1.4)),
        ]),
      );

  List<Widget> _sections(BuildContext context, List<MediaItem> items) {
    final movies = items.where((m) => m.type.toLowerCase().contains('movie') || m.type.toLowerCase().contains('film')).take(12).toList();
    final shows = items.where((m) => m.type.toLowerCase().contains('show') || m.type.toLowerCase().contains('series')).take(12).toList();
    final recent = List<MediaItem>.from(items)..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return [
      if (movies.isNotEmpty) _mediaSection(context, 'Movies', movies, Icons.movie_outlined),
      if (shows.isNotEmpty) _mediaSection(context, 'TV Shows', shows, Icons.tv_outlined),
      if (movies.isEmpty && shows.isEmpty) _mediaSection(context, 'Library', recent.take(20).toList(), Icons.video_library_outlined),
    ];
  }

  Widget _mediaSection(BuildContext context, String title, List<MediaItem> items, IconData icon) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900))]),
        const SizedBox(height: 8),
        ...items.map((item) => Card(child: ListTile(
          leading: item.imageUrl == null ? const Icon(Icons.movie_outlined) : Image.network(item.imageUrl!, width: 48, height: 68, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.movie_outlined)),
          title: Text(item.title),
          subtitle: Text('${item.type}${item.releaseYear == null ? '' : ' • ${item.releaseYear}'}'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MediaDetailsScreen(media: item))),
        ))),
        const SizedBox(height: 14),
      ]);

  Widget _chip(String title, IconData icon, VoidCallback action) => ActionChip(avatar: Icon(icon, size: 18), label: Text(title), onPressed: action);

  void _open(BuildContext? context, Widget page) {
    if (context == null) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  void _showItems(BuildContext context, String title, List<MediaItem> items) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => _FilmItemListScreen(title: title, items: items)));
  }

  void _showDirectory(BuildContext context, String title, IconData icon) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => _FilmDirectoryScreen(title: title, icon: icon)));
  }
}

class _FilmItemListScreen extends StatelessWidget {
  final String title;
  final List<MediaItem> items;
  const _FilmItemListScreen({required this.title, required this.items});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ListView(padding: const EdgeInsets.all(16), children: items.map((item) => Card(child: ListTile(title: Text(item.title), subtitle: Text(item.type), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MediaDetailsScreen(media: item)))))).toList()),
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
          Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const UniversalText('This directory is connected to the global Media Universe and will populate from imported/catalog metadata without exposing another account’s ownership.', style: TextStyle(color: Colors.white60)),
        ]),
      );
}
