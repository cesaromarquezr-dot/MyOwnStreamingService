// Library directories shared by the Film navigation menu and Home shortcuts.
import 'package:flutter/material.dart';
import 'app_core.dart';
import 'details.dart';
import 'feature_center.dart';
import 'music_favorites.dart';
import 'music.dart';
import 'widgets/category_filter_chips.dart';
import 'widgets/like_toggle_button.dart';
import 'localization.dart';

class LibraryCollectionsScreen extends StatelessWidget {
  const LibraryCollectionsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const UniversalText('Collections')),
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
          ? Center(child: UniversalText('No $kind metadata has been imported yet.'))
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
          ? const Center(child: UniversalText('No movies or shows found.'))
          : ListView.builder(
              padding: const EdgeInsets.all(18),
              itemCount: library.length,
              itemBuilder: (_, index) {
                final media = library[index];
                return Card(
                  child: ListTile(
                    leading: media.imageUrl == null ? const Icon(Icons.movie_rounded) : Image.network(media.imageUrl!, width: 52, height: 70, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.movie_rounded)),
                    title: Text(media.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: UniversalText('${media.type}${media.releaseYear == null ? '' : ' • ${media.releaseYear}'}'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MediaDetailsScreen(media: media))),
                  ),
                );
              },
            ),
    );
  }
}

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  String _songCategory = 'All';
  String _mediaCategory = 'All';

  List<String> _categories(Iterable<String> values) {
    final result = <String>{'All'};
    for (final value in values) {
      if (value.trim().isNotEmpty) result.add(value.trim());
    }
    return result.toList();
  }

  bool _matches(List<String> values, String selected) {
    if (selected == 'All') return true;
    return values.any((value) => value.toLowerCase() == selected.toLowerCase());
  }

  Future<void> _createSongPlaylist(List<MusicTrack> tracks) async {
    if (tracks.isEmpty) return;
    final name = TextEditingController(text: '$_songCategory Favorites');
    final shouldCreate = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const UniversalText('Create New Playlist'),
        content: TextField(
          controller: name,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Playlist name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const UniversalText('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const UniversalText('Create')),
        ],
      ),
    );
    final playlistName = name.text.trim();
    name.dispose();
    if (shouldCreate != true || playlistName.isEmpty) return;
    final store = MusicLibraryStore.instance;
    store.createPlaylist(
      playlistName,
      trackIds: tracks.map((track) => track.id),
    );
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: UniversalText('Created "$playlistName".')));
  }

  Future<void> _createMediaCollection(List<MediaItem> media) async {
    if (media.isEmpty) return;
    final name = TextEditingController(text: '$_mediaCategory Movies & Shows');
    final shouldCreate = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const UniversalText('Create New Collection'),
        content: TextField(
          controller: name,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Collection name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const UniversalText('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const UniversalText('Create')),
        ],
      ),
    );
    final collectionName = name.text.trim();
    name.dispose();
    if (shouldCreate != true || collectionName.isEmpty) return;
    AppController.instance.createCollection(
      name: collectionName,
      automatic: false,
      mediaIds: media.map((item) => item.id),
    );
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: UniversalText('Created "$collectionName".')));
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppController.instance;
    final likedMedia = controller.liked;
    final musicLibrary = MusicLibraryStore.instance;
    final likedSongTitles = MusicFavoritesBridge.likedTracks().toSet();
    final likedTracks = musicLibrary.tracks.where((track) => likedSongTitles.contains(track.title)).toList();
    final songCategories = _categories(
      likedTracks.expand((track) => [...track.genres, ...track.subgenres]),
    );
    final mediaCategories = _categories(
      likedMedia.expand((media) => [...media.genres, ...media.tags]),
    );
    final filteredSongs = likedTracks.where((track) => _matches([...track.genres, ...track.subgenres], _songCategory)).toList();
    final filteredMedia = likedMedia.where((media) => _matches([...media.genres, ...media.tags], _mediaCategory)).toList();

    return Scaffold(
      appBar: AppBar(title: const UniversalText('Favorites')),
      body: AnimatedBuilder(
        animation: musicLibrary,
        builder: (_, __) => ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const UniversalText('Liked Movies & TV Shows', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            CategoryFilterChips(
              categories: mediaCategories,
              selectedCategory: _mediaCategory,
              onSelected: (value) => setState(() => _mediaCategory = value),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: filteredMedia.isEmpty ? null : () => _createMediaCollection(filteredMedia),
                icon: const Icon(Icons.create_new_folder_outlined),
                label: const UniversalText('Create New Collection'),
              ),
            ),
            if (filteredMedia.isEmpty) const Card(child: ListTile(title: UniversalText('No liked movies or shows in this category yet.'))),
            for (final media in filteredMedia)
              Card(child: ListTile(
                leading: const Icon(Icons.movie_outlined),
                title: Text(media.title),
                subtitle: Text(media.type),
                trailing: LikeToggleButton(
                  liked: controller.isLiked(media.id),
                  onPressed: () {
                    controller.clearReaction(media.id);
                    setState(() {});
                  },
                ),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MediaDetailsScreen(media: media))),
              )),
            const SizedBox(height: 22),
            const UniversalText('Liked Songs', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            CategoryFilterChips(
              categories: songCategories,
              selectedCategory: _songCategory,
              onSelected: (value) => setState(() => _songCategory = value),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: filteredSongs.isEmpty ? null : () => _createSongPlaylist(filteredSongs),
                icon: const Icon(Icons.queue_music_outlined),
                label: const UniversalText('Create New Playlist'),
              ),
            ),
            if (filteredSongs.isEmpty) const Card(child: ListTile(title: UniversalText('No liked songs in this category yet.'))),
            for (final track in filteredSongs)
              Card(child: ListTile(
                leading: const Icon(Icons.music_note_rounded),
                title: Text(track.title),
                subtitle: Text(track.artist),
                trailing: LikeToggleButton(
                  liked: true,
                  onPressed: () {
                    MusicFavoritesBridge.toggleTrack(track.title);
                    setState(() {});
                  },
                ),
              )),
            const SizedBox(height: 18),
            const UniversalText('Liked Albums', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            if (MusicFavoritesBridge.likedAlbums().isEmpty) const Card(child: ListTile(title: UniversalText('No liked albums yet.'))),
            for (final album in MusicFavoritesBridge.likedAlbums()) Card(child: ListTile(leading: const Icon(Icons.album_rounded), title: Text(album))),
            const SizedBox(height: 18),
            const UniversalText('Liked Playlists', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            if (MusicFavoritesBridge.likedPlaylists().isEmpty) const Card(child: ListTile(title: UniversalText('No liked playlists yet.'))),
            for (final playlist in MusicFavoritesBridge.likedPlaylists()) Card(child: ListTile(leading: const Icon(Icons.queue_music_rounded), title: Text(playlist))),
          ],
        ),
      ),
    );
  }
}
