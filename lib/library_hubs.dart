// Library directories shared by the Film navigation menu and Home shortcuts.
import 'dart:async';

import 'package:flutter/material.dart';
import 'app_core.dart';
import 'details.dart';
import 'feature_center.dart';
import 'music_favorites.dart';
import 'music.dart';
import 'widgets/category_filter_chips.dart';
import 'widgets/like_toggle_button.dart';
import 'localization.dart';
import 'media_actions.dart';
import 'people_timeline.dart';

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
              itemCount: library.length + 1,
              itemBuilder: (_, index) {
                if (index == 0) {
                  final localCredits = library.map((media) {
                    return {
                      'title': media.title,
                      'type': media.type,
                      'category': kind == 'Actors' ? 'Acting' : 'Directing',
                      'role': kind == 'Actors' ? 'Cast credit' : 'Director',
                      'year': media.releaseYear,
                      'mediaId': media.id,
                    };
                  }).where((credit) => library.any((media) => media.id == credit['mediaId'] &&
                      (kind == 'Actors' ? media.actors : media.directors).any((name) => name.toLowerCase() == person.toLowerCase()))).toList();
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.timeline_rounded),
                      title: const Text('Career timeline', style: TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: const Text('Combine acting and other career credits'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => PeopleCareerTimelineScreen(personName: person, localCredits: localCredits),
                      )),
                    ),
                  );
                }
                final media = library[index - 1];
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
  String _movieCategory = 'All';
  String _showCategory = 'All';

  Future<void> _unlikeMedia(MediaItem media) async {
    final controller = AppController.instance;
    final result = await UniversalMediaActions.perform(
      context: UniversalMediaActionContext(
        contentType: media.type,
        contentId: media.id,
        mediaVersionId: media.mediaVersionId,
        profileId: controller.currentProfile?.id ?? 'local-profile',
        availableActions: const {
          UniversalMediaAction.like,
          UniversalMediaAction.removeReaction,
        },
      ),
      action: UniversalMediaAction.removeReaction,
      apply: () => controller.clearReaction(media.id),
    );
    if (result.applied && mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    unawaited(MusicLibraryStore.instance.initializeForProfile(
      AppController.instance.currentProfile?.id,
    ));
    unawaited(MusicFavoritesBridge.initializeForProfile(
      AppController.instance.currentProfile?.id,
    ));
  }

  List<String> _categories(Iterable<String> values, {List<String> presets = const []}) {
    final result = <String>{'All'};
    result.addAll(presets);
    for (final value in values) {
      if (value.trim().isNotEmpty) result.add(value.trim());
    }
    return result.toList();
  }

  bool _matches(List<String> values, String selected) {
    if (selected == 'All') return true;
    final key = selected.trim().toLowerCase();
    final aliases = switch (key) {
      'sci-fi' => const {'sci-fi', 'science fiction', 'science-fiction'},
      'reggaeton' => const {'reggaeton', 'reggaetón'},
      'nostalgic' => const {'nostalgic', 'nostalgia'},
      'party dance' => const {'party dance', 'dance', 'dance-pop', 'party'},
      _ => {key},
    };
    return values.any((value) => aliases.contains(value.trim().toLowerCase()));
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

  Future<void> _createMediaCollection(List<MediaItem> media, {required String defaultName}) async {
    if (media.isEmpty) return;
    final name = TextEditingController(text: defaultName);
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
    bool isShow(MediaItem media) {
      final type = media.type.toLowerCase();
      return type.contains('tv') || type.contains('show') ||
          type.contains('series') || type.contains('episode');
    }
    final likedMovies = likedMedia.where((media) => !isShow(media)).toList();
    final likedShows = likedMedia.where(isShow).toList();
    final musicLibrary = MusicLibraryStore.instance;
    final likedSongIds = MusicFavoritesBridge.likedTracks().toSet();
    final likedTracks = musicLibrary.tracks.where((track) => likedSongIds.contains(track.id)).toList();
    final songCategories = _categories(
      likedTracks.expand((track) => [...track.genres, ...track.subgenres]),
      presets: const ['Country', 'Rap', 'Pop', 'Reggaeton', 'Corridos Tumbados', 'Party Dance', 'Nostalgic'],
    );
    final movieCategories = _categories(
      likedMovies.expand((media) => [...media.genres, ...media.tags]),
      presets: const ['Action', 'Comedy', 'Sci-Fi', 'Drama', 'Documentary', 'Mockumentary'],
    );
    final showCategories = _categories(
      likedShows.expand((media) => [...media.genres, ...media.tags]),
      presets: const ['Action', 'Comedy', 'Sci-Fi', 'Drama', 'Documentary', 'Mockumentary'],
    );
    final filteredSongs = likedTracks.where((track) => _matches([...track.genres, ...track.subgenres], _songCategory)).toList();
    final filteredMovies = likedMovies.where((media) => _matches([...media.genres, ...media.tags], _movieCategory)).toList();
    final filteredShows = likedShows.where((media) => _matches([...media.genres, ...media.tags], _showCategory)).toList();

    return Scaffold(
      appBar: AppBar(title: const UniversalText('Favorites')),
      body: AnimatedBuilder(
        animation: Listenable.merge([musicLibrary, MusicFavoritesBridge.changes]),
        builder: (_, __) => ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const UniversalText('Liked Movies', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            CategoryFilterChips(
              categories: movieCategories,
              selectedCategory: _movieCategory,
              onSelected: (value) => setState(() => _movieCategory = value),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: filteredMovies.isEmpty ? null : () => _createMediaCollection(filteredMovies, defaultName: '$_movieCategory Movies'),
                icon: const Icon(Icons.create_new_folder_outlined),
                label: const UniversalText('Create New Collection'),
              ),
            ),
            if (filteredMovies.isEmpty) const Card(child: ListTile(title: UniversalText('No liked movies in this category yet.'))),
            for (final media in filteredMovies)
              Card(child: ListTile(
                leading: const Icon(Icons.movie_outlined),
                title: Text(media.title),
                subtitle: Text(media.type),
                trailing: LikeToggleButton(
                  liked: controller.isLiked(media.id),
                  onPressed: () => _unlikeMedia(media),
                ),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MediaDetailsScreen(media: media))),
              )),
            const SizedBox(height: 18),
            const UniversalText('Liked TV Shows', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            CategoryFilterChips(
              categories: showCategories,
              selectedCategory: _showCategory,
              onSelected: (value) => setState(() => _showCategory = value),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: filteredShows.isEmpty ? null : () => _createMediaCollection(filteredShows, defaultName: '$_showCategory Shows'),
                icon: const Icon(Icons.create_new_folder_outlined),
                label: const UniversalText('Create New Collection'),
              ),
            ),
            if (filteredShows.isEmpty) const Card(child: ListTile(title: UniversalText('No liked shows in this category yet.'))),
            for (final media in filteredShows)
              Card(child: ListTile(
                leading: const Icon(Icons.tv_outlined),
                title: Text(media.title),
                subtitle: Text(media.type),
                trailing: LikeToggleButton(
                  liked: controller.isLiked(media.id),
                  onPressed: () => _unlikeMedia(media),
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
                  onPressed: () async {
                    final liked = MusicFavoritesBridge.likedTracks().contains(track.id);
                    final result = await UniversalMediaActions.perform(
                      context: UniversalMediaActionContext(
                        contentType: 'music_track',
                        contentId: track.id,
                        profileId: controller.currentProfile?.id ?? 'local-profile',
                        availableActions: const {
                          UniversalMediaAction.like,
                          UniversalMediaAction.removeReaction,
                        },
                      ),
                      action: liked
                          ? UniversalMediaAction.removeReaction
                          : UniversalMediaAction.like,
                      apply: () => MusicFavoritesBridge.toggleTrack(track.id),
                    );
                    if (result.applied && mounted) setState(() {});
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
