import 'package:material_ui/material_ui.dart';

import 'app_core.dart';
import 'details.dart';
import 'genre_catalog.dart';
import 'genre_system.dart';
import 'music.dart';
import 'music_genre_system.dart';

/// Searchable genre and subgenre browser for film, television, and music.
class GenreExplorerScreen extends StatefulWidget {
  const GenreExplorerScreen({super.key, this.initialMedium = 'Movies'});

  final String initialMedium;

  @override
  State<GenreExplorerScreen> createState() => _GenreExplorerScreenState();
}

class _GenreExplorerScreenState extends State<GenreExplorerScreen> {
  late String _medium;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _medium = widget.initialMedium;
  }

  List<GenreCatalogGroup> get _groups {
    final groups = MediaGenreCatalog.groupsFor(_medium);
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return groups;
    return groups
        .map((group) {
          final groupMatches = group.name.toLowerCase().contains(query);
          final matches = groupMatches
              ? group.genres
              : group.genres
                  .where((genre) => genre.toLowerCase().contains(query));
          return GenreCatalogGroup(
            group.name,
            matches.toList(growable: false),
          );
        })
        .where((group) => group.genres.isNotEmpty)
        .toList(growable: false);
  }

  void _openGenre(String genre) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => GenreResultsScreen(medium: _medium, genre: genre),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF08090D) : null,
      appBar: AppBar(
        title: const Text('Explore Genres'),
        actions: [
          IconButton(
            tooltip: 'Clear search',
            onPressed:
                _query.isEmpty ? null : () => setState(() => _query = ''),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
        children: [
          const Text('Find your next favourite',
              style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(
            'Browse broad genres, subgenres and hybrid styles. Results are matched against metadata in your library.',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                  value: 'Movies',
                  label: Text('Movies'),
                  icon: Icon(Icons.movie_outlined)),
              ButtonSegment(
                  value: 'Shows',
                  label: Text('TV'),
                  icon: Icon(Icons.tv_outlined)),
              ButtonSegment(
                  value: 'Music',
                  label: Text('Music'),
                  icon: Icon(Icons.music_note_rounded)),
            ],
            selected: {_medium},
            onSelectionChanged: (value) =>
                setState(() => _medium = value.first),
          ),
          const SizedBox(height: 14),
          TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: 'Search genres and subgenres',
              filled: true,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 12),
          if (_groups.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No genres match that search.')),
            )
          else
            ..._groups.map((group) => _GenreGroupCard(
                  group: group,
                  forceExpanded: _query.trim().isNotEmpty,
                  onSelected: _openGenre,
                )),
        ],
      ),
    );
  }
}

class _GenreGroupCard extends StatelessWidget {
  const _GenreGroupCard({
    required this.group,
    required this.forceExpanded,
    required this.onSelected,
  });

  final GenreCatalogGroup group;
  final bool forceExpanded;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.symmetric(vertical: 5),
        child: ExpansionTile(
          key: ValueKey('${group.name}:$forceExpanded'),
          initiallyExpanded: forceExpanded,
          title: Text(group.name,
              style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('${group.genres.length} genres and subgenres'),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: group.genres
                    .map((genre) => ActionChip(
                          label: Text(genre),
                          onPressed: () => onSelected(genre),
                        ))
                    .toList(growable: false),
              ),
            ),
          ],
        ),
      );
}

class GenreResultsScreen extends StatelessWidget {
  const GenreResultsScreen({
    super.key,
    required this.medium,
    required this.genre,
  });

  final String medium;
  final String genre;

  bool _isFilmOrShow(MediaItem item) {
    final type = item.type.toLowerCase();
    if (medium == 'Shows') {
      return item.isSeries ||
          type.contains('show') ||
          type.contains('series') ||
          type.contains('tv');
    }
    return type.contains('movie') ||
        type.contains('film') ||
        type.contains('documentary');
  }

  @override
  Widget build(BuildContext context) {
    if (medium == 'Music') {
      final store = MusicLibraryStore.instance;
      final tracks =
          <MusicTrack>{...store.tracks, ...store.catalogTracks.values}.toList();
      final results = tracks
          .where((track) => MusicGenreSystem.matchesGenres(
                track.genres,
                [genre],
                itemSubgenres: track.subgenres,
              ))
          .toList(growable: false);
      return Scaffold(
        appBar: AppBar(title: Text(genre)),
        body: results.isEmpty
            ? _GenreEmptyState(genre: genre)
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: results.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final track = results[index];
                  return ListTile(
                    leading: _GenreArtwork(
                        url: track.artworkUrl, icon: Icons.music_note_rounded),
                    title: Text(track.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                        '${track.artist}${track.album.isEmpty ? '' : ' · ${track.album}'}'),
                    trailing: Icon(
                      (track.audioUrl?.trim().isNotEmpty ?? false)
                          ? Icons.play_circle_outline_rounded
                          : Icons.library_music_rounded,
                    ),
                    onTap: () async {
                      if (track.audioUrl?.trim().isNotEmpty ?? false) {
                        await MusicPlaybackController.instance.play(track);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'This catalog item has no imported audio file to play yet.',
                            ),
                          ),
                        );
                      }
                    },
                  );
                },
              ),
      );
    }

    final results = AppController.instance.library.where((item) {
      if (!_isFilmOrShow(item)) return false;
      final tags = <String>[...item.genres, ...item.tags];
      return GenreSystem.matchesGenres(tags, [genre], matchAll: true);
    }).toList(growable: false)
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return Scaffold(
      appBar: AppBar(title: Text(genre)),
      body: results.isEmpty
          ? _GenreEmptyState(genre: genre)
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: results.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = results[index];
                return ListTile(
                  leading: _GenreArtwork(
                      url: item.imageUrl, icon: Icons.movie_outlined),
                  title: Text(item.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                      '${item.releaseYear ?? ''}${item.genres.isEmpty ? '' : ' · ${item.genres.join(' / ')}'}'),
                  onTap: () =>
                      Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => MediaDetailsScreen(
                        media: item,
                        wrappedContextType: 'genre',
                        wrappedContextId: genre.toLowerCase(),
                        wrappedContextTitle: genre),
                  )),
                );
              },
            ),
    );
  }
}

class _GenreArtwork extends StatelessWidget {
  const _GenreArtwork({required this.url, required this.icon});
  final String? url;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final value = url?.trim() ?? '';
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 54,
        height: 64,
        child: value.isEmpty
            ? ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Icon(icon))
            : Image.network(value,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => ColoredBox(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Icon(icon),
                    )),
      ),
    );
  }
}

class _GenreEmptyState extends StatelessWidget {
  const _GenreEmptyState({required this.genre});
  final String genre;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.local_movies_outlined, size: 42),
            const SizedBox(height: 10),
            Text('No imported items tagged "$genre" yet.',
                textAlign: TextAlign.center),
            const SizedBox(height: 5),
            const Text(
                'The genre remains searchable and will appear when matching metadata is imported.',
                textAlign: TextAlign.center),
          ]),
        ),
      );
}
