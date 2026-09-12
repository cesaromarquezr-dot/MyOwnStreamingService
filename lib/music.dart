// Music home, playlist management and the persistent background music player.
//
// Music has its own content model and customization surface while sharing
// profiles, statistics and the home-server media library with Movies/TV.
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'app_core.dart';
import 'music_favorites.dart';
import 'details.dart';

class MusicTrack {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String? artworkUrl;
  final String? audioUrl;
  final Duration duration;
  final List<String> genres;

  const MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    this.artworkUrl,
    this.audioUrl,
    this.duration = Duration.zero,
    this.genres = const <String>[],
  });
}

/// Stores playlists and music-specific visual preferences for the current session.
class MusicLibraryStore extends ChangeNotifier {
  MusicLibraryStore._();
  static final MusicLibraryStore instance = MusicLibraryStore._();

  final List<MusicTrack> tracks = <MusicTrack>[];

  final Map<String, List<String>> playlists = <String, List<String>>{};

  final Map<String, int> listenCounts = <String, int>{};
  String? activePlaylist;
  String? currentTrackId;
  bool shuffle = false;
  bool repeat = false;

  String homeBackground = '0xFF090909';
  String navbarColor = '0xFF101010';
  String navbarGlow = '0xFFFF0000';
  String itemColor = '0xFF8B5CF6';

  MusicTrack? get currentTrack {
    for (final track in tracks) {
      if (track.id == currentTrackId) return track;
    }
    return null;
  }

  /// Creates a user playlist without changing or deleting source music.
  void createPlaylist(String name, {Iterable<String> trackIds = const <String>[]}) {
    final clean = name.trim();
    if (clean.isEmpty || playlists.containsKey(clean)) return;
    playlists[clean] = trackIds.toList();
    AppController.instance.addNotification(action: 'created playlist "$clean"');
    notifyListeners();
  }

  /// Deletes a custom playlist while preserving its music files.
  void deletePlaylist(String name) {
    if (name == 'Favorites' ||
        name == 'Movie Soundtracks' ||
        name == 'TV Soundtracks') {
      return;
    }
    playlists.remove(name);
    if (activePlaylist == name) activePlaylist = null;
    notifyListeners();
  }

  /// Adds or removes a track from a playlist.
  void toggleTrackInPlaylist(String playlist, String trackId) {
    final list = playlists[playlist];
    if (list == null) return;
    if (list.contains(trackId)) {
      list.remove(trackId);
    } else {
      list.add(trackId);
    }
    notifyListeners();
  }

  /// Records one listening event for music statistics and achievement logic.
  void recordListen(String trackId) {
    listenCounts[trackId] = (listenCounts[trackId] ?? 0) + 1;
    notifyListeners();
  }
}

/// Owns the audio controller so music can survive navigation between screens.
class MusicPlaybackController extends ChangeNotifier {
  MusicPlaybackController._();
  static final MusicPlaybackController instance = MusicPlaybackController._();

  VideoPlayerController? _controller;
  MusicTrack? currentTrack;
  bool isPlaying = false;
  bool loading = false;
  bool _resumeAfterVideo = false;

  VideoPlayerController? get videoController => _controller;
  bool get isReady => _controller?.value.isInitialized == true;

  /// Starts a server-provided audio stream for a track.
  Future<void> play(MusicTrack track) async {
    final url = track.audioUrl?.trim();
    currentTrack = track;
    MusicLibraryStore.instance.currentTrackId = track.id;
    MusicLibraryStore.instance.recordListen(track.id);

    if (url == null || url.isEmpty) {
      isPlaying = false;
      notifyListeners();
      return;
    }

    loading = true;
    notifyListeners();
    await _controller?.dispose();

    final uri = Uri.tryParse(url);
    if (uri == null) {
      loading = false;
      notifyListeners();
      return;
    }

    final controller = VideoPlayerController.networkUrl(uri);
    _controller = controller;
    try {
      await controller.initialize();
      await controller.play();
      isPlaying = true;
    } catch (_) {
      isPlaying = false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Pauses music when a movie/show starts and remembers whether it should resume.
  bool pauseForVideo() {
    _resumeAfterVideo = isPlaying;
    if (isPlaying) {
      _controller?.pause();
      isPlaying = false;
      notifyListeners();
    }
    return _resumeAfterVideo;
  }

  /// Resumes the previously playing track after movie/show playback ends or closes.
  Future<void> resumeAfterVideo() async {
    if (!_resumeAfterVideo || _controller == null) return;
    _resumeAfterVideo = false;
    await _controller!.play();
    isPlaying = true;
    notifyListeners();
  }

  /// Toggles play/pause for the active track.
  Future<void> toggle() async {
    final controller = _controller;
    if (controller == null || !isReady) return;
    if (controller.value.isPlaying) {
      await controller.pause();
      isPlaying = false;
    } else {
      await controller.play();
      isPlaying = true;
    }
    notifyListeners();
  }
}

/// Dedicated Music home for ripped albums, artists/bands and user playlists.
class MusicScreen extends StatefulWidget {
  const MusicScreen({super.key});

  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> {
  final library = MusicLibraryStore.instance;
  final playback = MusicPlaybackController.instance;

  /// Builds the browse-first music interface.
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[library, playback]),
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Color(int.parse(library.homeBackground)),
          body: SafeArea(
            child: CustomScrollView(
              slivers: <Widget>[
                SliverAppBar(
                  pinned: true,
                  title: const Text(
                    'Music',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  actions: <Widget>[
                    IconButton(
                      onPressed: _showSearch,
                      icon: const Icon(Icons.search_rounded),
                    ),
                    IconButton(
                      onPressed: _showCustomization,
                      icon: const Icon(Icons.tune_rounded),
                    ),
                  ],
                ),
                SliverToBoxAdapter(child: _buildPlayer()),
                ..._homeSlivers(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlayer() {
    final track = playback.currentTrack;
    if (track == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: <Widget>[
          const CircleAvatar(
            radius: 24,
            child: Icon(Icons.music_note_rounded),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(track.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(track.artist, style: const TextStyle(color: Colors.white60)),
              ],
            ),
          ),
          IconButton(
            onPressed: playback.isReady ? playback.toggle : null,
            icon: Icon(
              playback.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _homeSlivers() {
    return <Widget>[
      _section('Singer / Band', library.tracks.map((t) => t.artist).where((x) => x.trim().isNotEmpty).toSet().toList(), Icons.person_rounded),
      _section('Albums', library.tracks.map((t) => t.album).where((x) => x.trim().isNotEmpty).toSet().toList(), Icons.album_rounded),
      SliverToBoxAdapter(child: _playlistSliver()),
      SliverToBoxAdapter(child: _soundtrackFeature()),
    ];
  }

  Widget _section(String title, List<String> values, IconData icon) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            SizedBox(
              height: 82,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: values.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, index) {
                  return Container(
                    width: 150,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(icon),
                        const Spacer(),
                        Text(
                          values[index],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _playlistSliver() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('Playlists', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
          FilledButton.icon(onPressed: _createPlaylist, icon: const Icon(Icons.add), label: const Text('Create')),
        ]),
        const SizedBox(height: 8),
        if (library.playlists.isEmpty) const Card(child: ListTile(title: Text('No playlists created yet.'))),
        for (final entry in library.playlists.entries) Card(child: ListTile(title: Text(entry.key), subtitle: Text('${entry.value.length} songs'), trailing: IconButton(icon: Icon(MusicFavoritesBridge.likedPlaylists().contains(entry.key) ? Icons.favorite : Icons.favorite_border), onPressed: () { MusicFavoritesBridge.togglePlaylist(entry.key); setState(() {}); }))),
      ]),
    );
  }

  Widget _soundtrackFeature() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: <Color>[Color(0xFF26154D), Color(0xFF10233E)]), borderRadius: BorderRadius.circular(22)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Soundtrack Universe', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text('Songs attached to the movies and shows in your library, such as a soundtrack cue from The Breakfast Club or Back to the Future.'),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SoundtrackUniverseScreen())), icon: const Icon(Icons.open_in_new_rounded), label: const Text('Open Soundtrack Universe')),
      ]),
    );
  }

  /// Opens music search.
  void _showSearch() {
    showSearch<MusicTrack?>(
      context: context,
      delegate: _MusicSearchDelegate(library.tracks),
    );
  }

  /// Opens music-specific visual customization.
  void _showCustomization() {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => _MusicCustomization(store: library),
    );
  }

  /// Creates a user playlist.
  Future<void> _createPlaylist() async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Playlist name'),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              library.createPlaylist(controller.text);
              Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();
  }
}

class _MusicSearchDelegate extends SearchDelegate<MusicTrack?> {
  final List<MusicTrack> tracks;
  _MusicSearchDelegate(this.tracks);

  @override
  List<Widget>? buildActions(BuildContext context) => <Widget>[
        IconButton(onPressed: () => query = '', icon: const Icon(Icons.clear)),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        onPressed: () => close(context, null),
        icon: const Icon(Icons.arrow_back),
      );

  @override
  Widget buildResults(BuildContext context) => _results(context);

  @override
  Widget buildSuggestions(BuildContext context) => _results(context);

  Widget _results(BuildContext context) {
    final q = query.toLowerCase();
    return ListView(
      children: <Widget>[
        for (final track in tracks.where(
          (track) => '${track.title} ${track.artist} ${track.album}'.toLowerCase().contains(q),
        ))
          ListTile(
            title: Text(track.title),
            subtitle: Text('${track.artist} • ${track.album}'),
            onTap: () {
              MusicPlaybackController.instance.play(track);
              close(context, track);
            },
          ),
      ],
    );
  }
}

class _MusicCustomization extends StatefulWidget {
  final MusicLibraryStore store;
  const _MusicCustomization({required this.store});

  @override
  State<_MusicCustomization> createState() => _MusicCustomizationState();
}

class _MusicCustomizationState extends State<_MusicCustomization> {
  /// Applies one of the preset color combinations to the music interface.
  void _pick(String field, String value) {
    setState(() {
      if (field == 'home') widget.store.homeBackground = value;
      if (field == 'nav') widget.store.navbarColor = value;
      if (field == 'glow') widget.store.navbarGlow = value;
      if (field == 'item') widget.store.itemColor = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          const Text('Music customization', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('Customize music independently: home color, navbar color, glow, item color, playlists and layout.'),
          const SizedBox(height: 16),
          _colorTile('home', 'Home background', widget.store.homeBackground),
          _colorTile('nav', 'Navbar color', widget.store.navbarColor),
          _colorTile('glow', 'Navbar glow', widget.store.navbarGlow),
          _colorTile('item', 'Navbar item color', widget.store.itemColor),
        ],
      ),
    );
  }

  Widget _colorTile(String key, String title, String value) {
    return ListTile(
      title: Text(title),
      subtitle: Text(value),
      trailing: const Icon(Icons.palette_outlined),
      onTap: () => _pick(key, _nextColor(key)),
    );
  }

  String _nextColor(String key) {
    if (key == 'home') return '0xFF0B2B17';
    if (key == 'nav') return '0xFF1E3A8A';
    if (key == 'glow') return '0xFFFF0000';
    return '0xFF8B5CF6';
  }
}


class SoundtrackUniverseScreen extends StatelessWidget {
  const SoundtrackUniverseScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final rows = <MapEntry<MediaItem, String>>[];
    for (final media in AppController.instance.library) {
      for (final song in media.music) {
        if (song.trim().isNotEmpty) rows.add(MapEntry(media, song));
      }
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Soundtrack Universe')),
      body: rows.isEmpty
          ? const Center(child: Text('No soundtrack metadata has been imported yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(18),
              itemCount: rows.length,
              itemBuilder: (_, index) {
                final row = rows[index];
                return Card(child: ListTile(leading: const Icon(Icons.music_note_rounded), title: Text(row.value, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('From ${row.key.title}'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MediaDetailsScreen(media: row.key)))));
              },
            ),
    );
  }
}

