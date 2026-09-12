// Library directories shared by the Film navigation menu and Home shortcuts.
import 'package:flutter/material.dart';
import 'app_core.dart';
import 'details.dart';
import 'feature_center.dart';
import 'music_favorites.dart';

class LibraryCollectionsScreen extends StatelessWidget {
  const LibraryCollectionsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Collections')),
        body: const CollectionsPanel(),
      );
}

class LibraryActorsScreen extends StatelessWidget {
  const LibraryActorsScreen({super.key});
  @override
  Widget build(BuildContext context) => const _PeopleDirectoryScreen(kind: 'Actors');
}

class LibraryDirectorsScreen extends StatelessWidget {
  const LibraryDirectorsScreen({super.key});
  @override
  Widget build(BuildContext context) => const _PeopleDirectoryScreen(kind: 'Directors');
}

class _PeopleDirectoryScreen extends StatelessWidget {
  final String kind;
  const _PeopleDirectoryScreen({required this.kind});

  @override
  Widget build(BuildContext context) {
    final library = AppController.instance.library;
    final values = <String>{};
    for (final media in library) {
      values.addAll(kind == 'Actors' ? media.actors : media.directors);
    }
    final people = values.where((e) => e.trim().isNotEmpty).toList()..sort();
    return Scaffold(
      appBar: AppBar(title: Text(kind)),
      body: people.isEmpty
          ? Center(child: Text('No $kind metadata has been imported yet.'))
          : GridView.builder(
              padding: const EdgeInsets.all(18),
              itemCount: people.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.sizeOf(context).width >= 900 ? 4 : MediaQuery.sizeOf(context).width >= 600 ? 3 : 2,
                childAspectRatio: 1.65,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (_, index) {
                final person = people[index];
                return Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _PersonMediaScreen(kind: kind, person: person))),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(kind == 'Actors' ? Icons.person_rounded : Icons.videocam_rounded, size: 34),
                        const SizedBox(height: 10),
                        Text(person, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                      ]),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _PersonMediaScreen extends StatelessWidget {
  final String kind;
  final String person;
  const _PersonMediaScreen({required this.kind, required this.person});

  @override
  Widget build(BuildContext context) {
    final library = AppController.instance.library.where((media) {
      final names = kind == 'Actors' ? media.actors : media.directors;
      return names.any((name) => name.toLowerCase() == person.toLowerCase());
    }).toList();
    return Scaffold(
      appBar: AppBar(title: Text(person)),
      body: library.isEmpty
          ? const Center(child: Text('No movies or shows found.'))
          : ListView.builder(
              padding: const EdgeInsets.all(18),
              itemCount: library.length,
              itemBuilder: (_, index) {
                final media = library[index];
                return Card(
                  child: ListTile(
                    leading: media.imageUrl == null ? const Icon(Icons.movie_rounded) : Image.network(media.imageUrl!, width: 52, height: 70, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.movie_rounded)),
                    title: Text(media.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('${media.type}${media.releaseYear == null ? '' : ' • ${media.releaseYear}'}'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MediaDetailsScreen(media: media))),
                  ),
                );
              },
            ),
    );
  }
}

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = AppController.instance;
    final likedMedia = controller.liked;
    final music = MusicFavoritesBridge.likedTracks();
    final playlists = MusicFavoritesBridge.likedPlaylists();
    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text('Film & TV', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          if (likedMedia.isEmpty) const Card(child: ListTile(title: Text('No liked movies or shows yet.'))),
          for (final media in likedMedia) Card(child: ListTile(title: Text(media.title), subtitle: Text(media.type), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MediaDetailsScreen(media: media))))),
          const SizedBox(height: 18),
          const Text('Liked songs', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          if (music.isEmpty) const Card(child: ListTile(title: Text('No liked songs yet.'))),
          for (final title in music) Card(child: ListTile(leading: const Icon(Icons.music_note_rounded), title: Text(title))),
          const SizedBox(height: 18),
          const Text('Liked albums', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          if (MusicFavoritesBridge.likedAlbums().isEmpty) const Card(child: ListTile(title: Text('No liked albums yet.'))),
          for (final album in MusicFavoritesBridge.likedAlbums()) Card(child: ListTile(leading: const Icon(Icons.album_rounded), title: Text(album))),
          const SizedBox(height: 18),
          const Text('Liked playlists', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          if (playlists.isEmpty) const Card(child: ListTile(title: Text('No liked playlists yet.'))),
          for (final playlist in playlists) Card(child: ListTile(leading: const Icon(Icons.queue_music_rounded), title: Text(playlist))),
        ],
      ),
    );
  }
}
