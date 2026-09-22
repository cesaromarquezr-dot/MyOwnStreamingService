// FILE: `lib/music.dart`.
// Purpose: Implements the Spotify-inspired music destination, player, discovery
// features, playlists and per-profile music customization.
// Physical audio files remain on the account's home server.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import 'app_core.dart';
import 'music_favorites.dart';
import 'details.dart';
import 'localization.dart';
import 'profile_content_safety.dart';
import 'shop.dart';

/// A music track imported from the account's home-server library.
class MusicTrack {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String? artworkUrl;
  final String? audioUrl;
  final Duration duration;
  final List<String> genres;
  /// Additional artists explicitly credited on the track, such as features.
  final List<String> featuredArtists;
  /// Optional richer genre/subgenre metadata from the home-server importer.
  final List<String> subgenres;
  /// Explicit-content flag supplied by licensed/import metadata.
  final bool explicit;
  /// Mature-theme flag supplied by licensed/import metadata.
  final bool matureTheme;

  const MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    this.artworkUrl,
    this.audioUrl,
    this.duration = Duration.zero,
    this.genres = const <String>[],
    this.featuredArtists = const <String>[],
    this.subgenres = const <String>[],
    this.explicit = false,
    this.matureTheme = false,
  });
}

/// Stores per-profile music presentation and discovery preferences.
class MusicPageCustomization {
  bool showSearch;
  bool showPlayer;
  bool showWeeklyDiscovery;
  bool showAIDJ;
  bool showSystemPlaylists;
  bool showLikedSongs;
  bool showRecentlyPlayed;
  bool showMoodMixes;
  bool showSoundtrackUniverse;
  bool showAlbums;
  bool showArtists;
  bool showPlaylists;
  String cardStyle;
  String playerStyle;
  List<String> sectionOrder;

  MusicPageCustomization({
    this.showSearch = true,
    this.showPlayer = true,
    this.showWeeklyDiscovery = true,
    this.showAIDJ = true,
    this.showSystemPlaylists = true,
    this.showLikedSongs = true,
    this.showRecentlyPlayed = true,
    this.showMoodMixes = true,
    this.showSoundtrackUniverse = true,
    this.showAlbums = true,
    this.showArtists = true,
    this.showPlaylists = true,
    this.cardStyle = 'Comfortable',
    this.playerStyle = 'Bottom player',
    List<String>? sectionOrder,
  }) : sectionOrder = sectionOrder ??
            [
              'Weekly Discovery',
              'AI DJ',
              'Made For You',
              'Liked Songs',
              'Recently Played',
              'Mood Mixes',
              'Artists',
              'Albums',
              'Playlists',
              'Soundtrack Universe',
            ];

  MusicPageCustomization copy() => MusicPageCustomization(
        showSearch: showSearch,
        showPlayer: showPlayer,
        showWeeklyDiscovery: showWeeklyDiscovery,
        showAIDJ: showAIDJ,
        showSystemPlaylists: showSystemPlaylists,
        showLikedSongs: showLikedSongs,
        showRecentlyPlayed: showRecentlyPlayed,
        showMoodMixes: showMoodMixes,
        showSoundtrackUniverse: showSoundtrackUniverse,
        showAlbums: showAlbums,
        showArtists: showArtists,
        showPlaylists: showPlaylists,
        cardStyle: cardStyle,
        playerStyle: playerStyle,
        sectionOrder: List<String>.from(sectionOrder),
      );
}

/// Persists music customization per selected profile.
class MusicPageCustomizationStore {
  MusicPageCustomizationStore._();

  static final Map<String, MusicPageCustomization> _settings =
      <String, MusicPageCustomization>{};
  static SharedPreferences? _prefs;

  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    const prefix = 'music_customization_';
    for (final key in _prefs!.getKeys().where((k) => k.startsWith(prefix))) {
      final raw = _prefs!.getString(key);
      if (raw == null) continue;
      try {
        _settings[key.substring(prefix.length)] =
            _fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
      } catch (_) {}
    }
  }

  static MusicPageCustomization settingsFor(Profile? profile) {
    final key = profile?.id ?? 'default';
    final value = _settings[key] ??= MusicPageCustomization();
    const defaults = <String>[
      'Weekly Discovery',
      'AI DJ',
      'Made For You',
      'Liked Songs',
      'Recently Played',
      'Mood Mixes',
      'Artists',
      'Albums',
      'Playlists',
      'Soundtrack Universe',
    ];
    for (final section in defaults) {
      if (!value.sectionOrder.contains(section)) {
        value.sectionOrder.add(section);
      }
    }
    return value.copy();
  }

  static void apply(Profile? profile, MusicPageCustomization value) {
    final key = profile?.id ?? 'default';
    final copy = value.copy();
    _settings[key] = copy;
    _prefs?.setString(
      'music_customization_$key',
      jsonEncode(_toJson(copy)),
    );
  }

  static Map<String, dynamic> snapshotFor(Profile? profile) =>
      _toJson(settingsFor(profile));

  static Map<String, dynamic> _toJson(MusicPageCustomization value) => {
        'showSearch': value.showSearch,
        'showPlayer': value.showPlayer,
        'showWeeklyDiscovery': value.showWeeklyDiscovery,
        'showAIDJ': value.showAIDJ,
        'showSystemPlaylists': value.showSystemPlaylists,
        'showLikedSongs': value.showLikedSongs,
        'showRecentlyPlayed': value.showRecentlyPlayed,
        'showMoodMixes': value.showMoodMixes,
        'showSoundtrackUniverse': value.showSoundtrackUniverse,
        'showAlbums': value.showAlbums,
        'showArtists': value.showArtists,
        'showPlaylists': value.showPlaylists,
        'cardStyle': value.cardStyle,
        'playerStyle': value.playerStyle,
        'sectionOrder': value.sectionOrder,
      };

  static MusicPageCustomization _fromJson(Map<String, dynamic> map) =>
      MusicPageCustomization(
        showSearch: map['showSearch'] == false ? false : true,
        showPlayer: map['showPlayer'] == false ? false : true,
        showWeeklyDiscovery: map['showWeeklyDiscovery'] == false ? false : true,
        showAIDJ: map['showAIDJ'] == false ? false : true,
        showSystemPlaylists: map['showSystemPlaylists'] == false ? false : true,
        showLikedSongs: map['showLikedSongs'] == false ? false : true,
        showRecentlyPlayed: map['showRecentlyPlayed'] == false ? false : true,
        showMoodMixes: map['showMoodMixes'] == false ? false : true,
        showSoundtrackUniverse:
            map['showSoundtrackUniverse'] == false ? false : true,
        showAlbums: map['showAlbums'] == false ? false : true,
        showArtists: map['showArtists'] == false ? false : true,
        showPlaylists: map['showPlaylists'] == false ? false : true,
        cardStyle: map['cardStyle']?.toString() ?? 'Comfortable',
        playerStyle: map['playerStyle']?.toString() ?? 'Bottom player',
        sectionOrder: map['sectionOrder'] is List
            ? (map['sectionOrder'] as List).map((e) => e.toString()).toList()
            : null,
      );
}

/// Stores playlists and music-specific runtime state.
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

  /// Tracks the ordered queue used by AI DJ and normal playback.
  final List<String> queue = <String>[];
  bool aiDjActive = false;

  /// Publishes lightweight music metadata to the Shop association index.
  /// Audio files and private track data remain on the account's home server.
  void registerShopEntities() {
    final entities = <ShopEntity>[];

    for (final track in tracks) {
      entities.add(
        ShopEntity(
          type: 'song',
          id: track.id,
          name: track.title,
          subtitle: 'Song • ${track.artist}',
        ),
      );

      if (track.artist.trim().isNotEmpty) {
        final artistId = 'artist:${track.artist.trim().toLowerCase()}';
        entities.add(
          ShopEntity(
            type: 'artist',
            id: artistId,
            name: track.artist,
            subtitle: 'Artist',
          ),
        );
      }

      if (track.album.trim().isNotEmpty) {
        final albumId =
            'album:${track.artist.trim().toLowerCase()}:${track.album.trim().toLowerCase()}';
        entities.add(
          ShopEntity(
            type: 'album',
            id: albumId,
            name: track.album,
            subtitle: 'Album • ${track.artist}',
          ),
        );
      }

      for (final genre in track.genres) {
        final clean = genre.trim();
        if (clean.isEmpty) continue;
        entities.add(
          ShopEntity(
            type: 'genre',
            id: 'music-genre:${clean.toLowerCase()}',
            name: clean,
            subtitle: 'Music genre',
          ),
        );
      }

      for (final artist in track.featuredArtists) {
        final clean = artist.trim();
        if (clean.isEmpty) continue;
        entities.add(
          ShopEntity(
            type: 'artist',
            id: 'artist:${clean.toLowerCase()}',
            name: clean,
            subtitle: 'Featured artist',
          ),
        );
      }
    }

    for (final playlistName in playlists.keys) {
      final clean = playlistName.trim();
      if (clean.isEmpty) continue;
      entities.add(
        ShopEntity(
          type: 'playlist',
          id: 'playlist:${clean.toLowerCase()}',
          name: clean,
          subtitle: 'Music playlist',
        ),
      );
    }

    ShopCatalog.instance.registerExternalEntities(entities);
  }

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

  /// Creates a user playlist without changing source music.
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

  /// Replaces the current playback queue without changing the source files.
  void setQueue(Iterable<MusicTrack> tracks, {bool aiDj = false}) {
    queue
      ..clear()
      ..addAll(tracks.map((track) => track.id));
    aiDjActive = aiDj;
    notifyListeners();
  }

  /// Records one listening event for music statistics and discovery ordering.
  void recordListen(String trackId) {
    listenCounts[trackId] = (listenCounts[trackId] ?? 0) + 1;
    notifyListeners();
  }
}

/// Owns audio playback so music can survive navigation.
class MusicPlaybackController extends ChangeNotifier {
  MusicPlaybackController._();
  static final MusicPlaybackController instance = MusicPlaybackController._();

  VideoPlayerController? _controller;
  MusicTrack? currentTrack;
  bool isPlaying = false;
  bool loading = false;
  bool _resumeAfterVideo = false;
  bool _advancing = false;

  VideoPlayerController? get videoController => _controller;
  bool get isReady => _controller?.value.isInitialized == true;

  /// Starts a server-provided audio stream for a track.
  Future<void> play(MusicTrack track) async {
    final profile = AppController.instance.currentProfile;
    if (profileBlocksExplicitMusic(profile) && track.explicit) {
      return;
    }
    if (profileBlocksMatureMusic(profile) && track.matureTheme) {
      return;
    }
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
    controller.addListener(_handlePlaybackTick);
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

  /// Advances an AI DJ queue when the active track finishes.
  void _handlePlaybackTick() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (!controller.value.isCompleted || _advancing) return;

    final store = MusicLibraryStore.instance;
    if (!store.aiDjActive || store.queue.isEmpty) return;

    _advanceAiDj();
  }

  /// Selects the next queued AI DJ track and starts it automatically.
  Future<void> _advanceAiDj() async {
    if (_advancing) return;
    _advancing = true;
    try {
      final store = MusicLibraryStore.instance;
      final currentId = currentTrack?.id;
      final index = currentId == null ? -1 : store.queue.indexOf(currentId);
      var nextIndex = index + 1;
      if (nextIndex >= store.queue.length) nextIndex = 0;

      if (store.queue.isEmpty) return;
      final nextId = store.queue[nextIndex];
      MusicTrack? next;
      for (final track in store.tracks) {
        if (track.id == nextId) {
          next = track;
          break;
        }
      }
      if (next == null) return;
      await play(next);
    } finally {
      _advancing = false;
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

  /// Resumes the previously playing track.
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

/// Spotify-inspired music home for ripped albums, artists and discovery.
class MusicScreen extends StatefulWidget {
  const MusicScreen({super.key});

  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> {
  final library = MusicLibraryStore.instance;
  final playback = MusicPlaybackController.instance;

  @override
  void initState() {
    super.initState();
    library.registerShopEntities();
    ShopCatalog.instance.syncShopEntityIndex();
  }

  MusicPageCustomization get customization =>
      MusicPageCustomizationStore.settingsFor(
        AppController.instance.currentProfile,
      );

  @override
  Widget build(BuildContext context) {
    final settings = customization;

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
                  title: const UniversalText('Music',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  actions: [
                    if (settings.showSearch)
                      IconButton(
                        onPressed: _showSearch,
                        icon: const Icon(Icons.search_rounded),
                        tooltip: 'Search music',
                      ),
                    IconButton(
                      onPressed: _openDiscover,
                      icon: const Icon(Icons.explore_rounded),
                      tooltip: 'Discover music',
                    ),
                    IconButton(
                      onPressed: _showCustomization,
                      icon: const Icon(Icons.tune_rounded),
                    ),
                  ],
                ),
                if (settings.showPlayer && playback.currentTrack != null)
                  SliverToBoxAdapter(child: _buildPlayer(settings)),
                ..._homeSlivers(settings),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlayer(MusicPageCustomization settings) {
    final track = playback.currentTrack;
    if (track == null) return const SizedBox.shrink();

    final compact = settings.playerStyle == 'Compact';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: EdgeInsets.all(compact ? 10 : 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          _artwork(track, size: compact ? 40 : 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(track.title,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(track.artist,
                    style: const TextStyle(color: Colors.white60)),
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
          IconButton(
            onPressed: _showQueue,
            icon: const Icon(Icons.queue_music_rounded),
          ),
        ],
      ),
    );
  }

  List<Widget> _homeSlivers(MusicPageCustomization settings) {
    final output = <Widget>[];
    for (final section in settings.sectionOrder) {
      if (section == 'Weekly Discovery' && settings.showWeeklyDiscovery) {
        output.add(_trackSection(
          'Weekly Discovery',
          'Fresh music selected from artists, genres and listening activity',
          _weeklyDiscovery(),
          Icons.auto_awesome_rounded,
        ));
        output.add(_discoverEntrySection());
      } else if (section == 'AI DJ' && settings.showAIDJ) {
        output.add(_aiDjSection());
      } else if (section == 'Made For You' && settings.showSystemPlaylists) {
        output.add(_systemPlaylistSection());
      } else if (section == 'Liked Songs' && settings.showLikedSongs) {
        output.add(_likedSongsSection());
      } else if (section == 'Recently Played' && settings.showRecentlyPlayed) {
        output.add(_trackSection(
          'Recently Played',
          'Based on your recent listening activity',
          _recentlyPlayed(),
          Icons.history_rounded,
        ));
      } else if (section == 'Mood Mixes' && settings.showMoodMixes) {
        output.add(_moodSection());
      } else if (section == 'Artists' && settings.showArtists) {
        output.add(_nameSection(
          'Artists',
          'Singers and bands from your library',
          library.tracks
              .map((t) => t.artist)
              .where((x) => x.trim().isNotEmpty)
              .toSet()
              .toList(),
          Icons.person_rounded,
        ));
      } else if (section == 'Albums' && settings.showAlbums) {
        output.add(_nameSection(
          'Albums',
          'Albums you ripped to your home server',
          library.tracks
              .map((t) => t.album)
              .where((x) => x.trim().isNotEmpty)
              .toSet()
              .toList(),
          Icons.album_rounded,
        ));
      } else if (section == 'Playlists' && settings.showPlaylists) {
        output.add(SliverToBoxAdapter(child: _playlistSliver()));
      } else if (section == 'Soundtrack Universe' &&
          settings.showSoundtrackUniverse) {
        output.add(SliverToBoxAdapter(child: _soundtrackFeature()));
      }
    }
    return output;
  }

  bool _isAllowedForCurrentProfile(MusicTrack track) {
    final profile = AppController.instance.currentProfile;
    if (profileBlocksExplicitMusic(profile) && track.explicit) return false;
    if (profileBlocksMatureMusic(profile) && track.matureTheme) return false;
    return true;
  }

  List<MusicTrack> _weeklyDiscovery() {
    final tracks = library.tracks.where(_isAllowedForCurrentProfile).toList();
    if (tracks.isEmpty) return const <MusicTrack>[];

    // Discover Weekly follows artist relationships, including featured
    // artists, then uses genres/subgenres and listening activity as supporting
    // signals. Everything remains limited to the imported home-server library.
    final seeds = tracks.where((track) => (library.listenCounts[track.id] ?? 0) > 0).toList();
    final seedTracks = seeds.isEmpty ? tracks.take(5).toList() : seeds;
    final seedArtists = <String>{};
    final seedFeatured = <String>{};
    final seedGenres = <String>{};
    final seedSubgenres = <String>{};
    for (final track in seedTracks) {
      seedArtists.add(track.artist.toLowerCase());
      seedFeatured.addAll(track.featuredArtists.map((a) => a.toLowerCase()));
      seedGenres.addAll(track.genres.map((g) => g.toLowerCase()));
      seedSubgenres.addAll(track.subgenres.map((g) => g.toLowerCase()));
    }

    final scored = <MusicTrack, int>{};
    for (final track in tracks) {
      var score = 0;
      final artist = track.artist.toLowerCase();
      final features = track.featuredArtists.map((a) => a.toLowerCase()).toSet();
      if (seedFeatured.contains(artist)) score += 18;
      if (seedArtists.contains(artist)) score += 12;
      if (features.any(seedArtists.contains)) score += 16;
      score += track.genres.map((g) => g.toLowerCase()).where(seedGenres.contains).length * 4;
      score += track.subgenres.map((g) => g.toLowerCase()).where(seedSubgenres.contains).length * 6;
      score += (library.listenCounts[track.id] ?? 0).clamp(0, 5);
      if (score > 0) scored[track] = score;
    }

    final items = scored.keys.toList()
      ..sort((a, b) => scored[b]!.compareTo(scored[a]!));
    return items.take(12).toList();
  }

  List<MusicTrack> _recentlyPlayed() {
    final items = library.tracks.where(_isAllowedForCurrentProfile).toList();
    items.sort(
      (a, b) => (library.listenCounts[b.id] ?? 0)
          .compareTo(library.listenCounts[a.id] ?? 0),
    );
    return items.take(8).toList();
  }

  Widget _discoverEntrySection() {
    final tracks = _discoverTracks();
    return SliverToBoxAdapter(
      child: Card(
        margin: const EdgeInsets.fromLTRB(16, 18, 16, 0),
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.explore_rounded)),
          title: const UniversalText('Discover'),
          subtitle: Text(tracks.isEmpty
              ? 'Discover music from your imported library.'
              : '${tracks.length} discovery picks based on artists, genres and related listening.'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: _openDiscover,
        ),
      ),
    );
  }

  List<MusicTrack> _discoverTracks() {
    final tracks = library.tracks.where(_isAllowedForCurrentProfile).toList();
    tracks.sort((a, b) {
      final aScore = (library.listenCounts[a.id] ?? 0) + a.genres.length + a.subgenres.length;
      final bScore = (library.listenCounts[b.id] ?? 0) + b.genres.length + b.subgenres.length;
      return bScore.compareTo(aScore);
    });
    return tracks.take(18).toList();
  }

  Widget _aiDjSection() {
    final mix = _buildAiDjMix();
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 18, 16, 0),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3B1D5E), Color(0xFF102E42)],
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_awesome_rounded),
                SizedBox(width: 8),
                UniversalText('AI DJ', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 6),
            const UniversalText(
              'A continuous hands-free mix built from your listening history, artists, genres and imported library.',
              style: TextStyle(color: Colors.white70, height: 1.35),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: mix.isEmpty ? null : _startAiDj,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const UniversalText('START AI DJ'),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: mix.isEmpty ? null : _openAiDj,
                  icon: const Icon(Icons.queue_music_rounded),
                  label: const UniversalText('VIEW MIX'),
                ),
              ],
            ),
            if (mix.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('${mix.length} tracks selected • AI DJ will continue automatically', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }

  List<MusicTrack> _buildAiDjMix() {
    final tracks = List<MusicTrack>.from(_weeklyDiscovery());
    if (tracks.length < 2) return tracks;

    // Interleave artists where possible so the DJ does not simply replay an album.
    final result = <MusicTrack>[];
    final remaining = List<MusicTrack>.from(tracks);
    String? lastArtist;
    while (remaining.isNotEmpty) {
      var index = remaining.indexWhere((track) => track.artist != lastArtist);
      if (index < 0) index = 0;
      final track = remaining.removeAt(index);
      result.add(track);
      lastArtist = track.artist;
    }
    return result;
  }

  Future<void> _startAiDj() async {
    final mix = _buildAiDjMix();
    if (mix.isEmpty) return;
    library.setQueue(mix, aiDj: true);
    await playback.play(mix.first);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: UniversalText('AI DJ started with ${mix.first.title} and queued ${mix.length} tracks.')),
    );
  }

  void _openAiDj() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const MusicAiDjScreen()));
  }

  void _openDiscover() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const MusicDiscoverScreen()));
  }

  Widget _systemPlaylistSection() {
    const names = [
      ('Made For You', 'Personal mix from your listening history', Icons.person_rounded),
      ('Discover Weekly', 'Fresh tracks from your imported library', Icons.explore_rounded),
      ('Daily Mix', 'Familiar artists and albums you play often', Icons.repeat_rounded),
    ];
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const UniversalText('MADE FOR YOU',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.3,
                    color: Colors.white54)),
            const SizedBox(height: 9),
            for (final item in names)
              Card(
                child: ListTile(
                  leading: CircleAvatar(child: Icon(item.$3)),
                  title: Text(item.$1,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(item.$2),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _playGeneratedPlaylist(item.$1),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _playGeneratedPlaylist(String name) async {
    final tracks = _weeklyDiscovery();
    if (tracks.isEmpty) return;
    await playback.play(tracks.first);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: UniversalText('$name is ready to play.')),
      );
    }
  }

  Widget _likedSongsSection() {
    final liked = MusicFavoritesBridge.likedTracks();
    final tracks =
        library.tracks.where((track) => liked.contains(track.title)).toList();
    return SliverToBoxAdapter(
      child: _trackSectionBody(
        'Liked Songs',
        'Your saved favorites',
        tracks,
        Icons.favorite_rounded,
      ),
    );
  }

  Widget _moodSection() {
    final genres = library.tracks
        .expand((track) => track.genres)
        .where((genre) => genre.trim().isNotEmpty)
        .toSet()
        .take(8)
        .toList();
    final values =
        genres.isEmpty ? const ['Chill', 'Focus', 'Energy', 'Favorites'] : genres;
    return _nameSection(
      'Mood & Genre Mixes',
      'Quick mixes based on the music in your library',
      values,
      Icons.mood_rounded,
    );
  }

  Widget _trackSection(
    String title,
    String subtitle,
    List<MusicTrack> tracks,
    IconData icon,
  ) {
    return SliverToBoxAdapter(
      child: _trackSectionBody(title, subtitle, tracks, icon),
    );
  }

  Widget _trackSectionBody(
    String title,
    String subtitle,
    List<MusicTrack> tracks,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 7),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 9),
          if (tracks.isEmpty)
            Card(
              child: ListTile(
                leading: const Icon(Icons.music_off_rounded),
                title: UniversalText('No $title yet'),
                subtitle: const UniversalText('Import or play music from your account server to build this section.'),
              ),
            )
          else
            SizedBox(
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: tracks.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, index) {
                  final track = tracks[index];
                  return SizedBox(
                    width: 190,
                    child: Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => playback.play(track),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: [
                              _artwork(track, size: 54),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(track.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800)),
                                    Text(track.artist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _nameSection(
    String title,
    String subtitle,
    List<String> values,
    IconData icon,
  ) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Colors.white54)),
            const SizedBox(height: 9),
            SizedBox(
              height: 82,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: values.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, index) => Container(
                  width: 155,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon),
                      const Spacer(),
                      Text(values[index],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: UniversalText('Playlists',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              ),
              FilledButton.icon(
                onPressed: _createPlaylist,
                icon: const Icon(Icons.add),
                label: const UniversalText('Create'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (library.playlists.isEmpty)
            const Card(
              child: ListTile(
                title: UniversalText('No custom playlists created yet.'),
                subtitle: UniversalText('System-created playlists are generated automatically above.'),
              ),
            ),
          for (final entry in library.playlists.entries)
            Card(
              child: ListTile(
                title: Text(entry.key),
                subtitle: UniversalText('${entry.value.length} songs'),
                trailing: Wrap(
                  children: [
                    if (ShopCatalog.instance.productsForAssociation('playlist', entry.key, name: entry.key).isNotEmpty)
                      IconButton(
                        tooltip: 'Shop related products',
                        icon: const Icon(Icons.storefront_outlined),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ShopScreen(
                              contextAssociationType: 'playlist',
                              contextAssociationId: entry.key,
                              contextAssociationName: entry.key,
                            ),
                          ),
                        ),
                      ),
                    IconButton(
                      icon: Icon(
                        MusicFavoritesBridge.likedPlaylists().contains(entry.key)
                            ? Icons.favorite
                            : Icons.favorite_border,
                      ),
                      onPressed: () {
                        MusicFavoritesBridge.togglePlaylist(entry.key);
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _soundtrackFeature() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF26154D), Color(0xFF10233E)]),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const UniversalText('Soundtrack Universe',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const UniversalText('Connect songs to the movies and shows where they belong, '
            'turning your film and music libraries into one soundtrack universe.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SoundtrackUniverseScreen(),
              ),
            ),
            icon: const Icon(Icons.open_in_new_rounded),
            label: const UniversalText('OPEN SOUNDTRACK UNIVERSE'),
          ),
        ],
      ),
    );
  }

  Widget _artwork(MusicTrack track, {double size = 52}) {
    final url = track.artworkUrl?.trim();
    if (url == null || url.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.album_rounded, color: Colors.white38),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          color: Colors.white10,
          child: const Icon(Icons.album_rounded, color: Colors.white38),
        ),
      ),
    );
  }

  void _showSearch() {
    showSearch<MusicTrack?>(
      context: context,
      delegate: _MusicSearchDelegate(library.tracks),
    );
  }

  void _showCustomization() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MusicCustomization(store: library),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _showQueue() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF101010),
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(18),
          children: [
            const UniversalText('QUEUE',
                style: TextStyle(
                    fontWeight: FontWeight.w900, letterSpacing: 1.2)),
            const SizedBox(height: 10),
            for (final track in _weeklyDiscovery())
              ListTile(
                leading: const Icon(Icons.music_note_rounded),
                title: Text(track.title),
                subtitle: Text(track.artist),
                onTap: () {
                  Navigator.pop(context);
                  playback.play(track);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _createPlaylist() async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const UniversalText('New playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: tr('Playlist name')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const UniversalText('Cancel')),
          FilledButton(
            onPressed: () {
              library.createPlaylist(controller.text);
              Navigator.pop(context);
            },
            child: const UniversalText('Create'),
          ),
        ],
      ),
    );
    controller.dispose();
  }
}

/// Dedicated music discovery experience.
class MusicDiscoverScreen extends StatelessWidget {
  const MusicDiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = MusicLibraryStore.instance;
    final tracks = store.tracks.where((track) {
      final profile = AppController.instance.currentProfile;
      if (profileBlocksExplicitMusic(profile) && track.explicit) return false;
      if (profileBlocksMatureMusic(profile) && track.matureTheme) return false;
      return true;
    }).toList();
    tracks.sort((a, b) {
      final aScore = (store.listenCounts[a.id] ?? 0) + a.genres.length * 2 + a.subgenres.length;
      final bScore = (store.listenCounts[b.id] ?? 0) + b.genres.length * 2 + b.subgenres.length;
      return bScore.compareTo(aScore);
    });
    return Scaffold(
      appBar: AppBar(title: const UniversalText('Discover Music')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const UniversalText('Discover', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const UniversalText('Explore music already available in your account server using listening history, artists, genres and soundtrack connections.', style: TextStyle(color: Colors.white60)),
          const SizedBox(height: 18),
          _discoverGroup(context, 'Because You Listen', tracks.take(8).toList()),
          const SizedBox(height: 18),
          _discoverGroup(context, 'Artists & Genres To Explore', tracks.skip(8).take(8).toList()),
          const SizedBox(height: 18),
          _discoverGroup(context, 'Soundtrack Connections', tracks.where((track) => track.genres.any((g) => g.toLowerCase().contains('soundtrack'))).take(8).toList()),
        ],
      ),
    );
  }

  Widget _discoverGroup(BuildContext context, String title, List<MusicTrack> tracks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        if (tracks.isEmpty)
          const Card(child: ListTile(title: UniversalText('Nothing to show yet.')))
        else
          for (final track in tracks)
            Card(
              child: ListTile(
                leading: _MusicDiscoverArtwork(track: track),
                title: Text(track.title),
                subtitle: Text('${track.artist} • ${track.album}'),
                trailing: Wrap(
                  children: [
                    if (ShopCatalog.instance.productsForAssociation('song', track.id, name: track.title).isNotEmpty)
                      IconButton(
                        tooltip: 'Shop song products',
                        icon: const Icon(Icons.storefront_outlined),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopScreen(contextAssociationType: 'song', contextAssociationId: track.id, contextAssociationName: track.title))),
                      ),
                    if (ShopCatalog.instance.productsForAssociation('artist', track.artist, name: track.artist).isNotEmpty)
                      IconButton(
                        tooltip: 'Shop artist products',
                        icon: const Icon(Icons.person_outline_rounded),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopScreen(contextAssociationType: 'artist', contextAssociationId: track.artist, contextAssociationName: track.artist))),
                      ),
                    if (ShopCatalog.instance.productsForAssociation('album', track.album, name: track.album).isNotEmpty)
                      IconButton(
                        tooltip: 'Shop album products',
                        icon: const Icon(Icons.album_outlined),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopScreen(contextAssociationType: 'album', contextAssociationId: track.album, contextAssociationName: track.album))),
                      ),
                    IconButton(
                      tooltip: 'Play',
                      icon: const Icon(Icons.play_arrow_rounded),
                      onPressed: () => MusicPlaybackController.instance.play(track),
                    ),
                  ],
                ),
                onTap: () => MusicPlaybackController.instance.play(track),
              ),
            ),
      ],
    );
  }
}

/// Dedicated AI DJ queue view for inspecting and starting the generated mix.
class MusicAiDjScreen extends StatelessWidget {
  const MusicAiDjScreen({super.key});

  List<MusicTrack> _mix() {
    final store = MusicLibraryStore.instance;
    final tracks = store.tracks.where((track) {
      final profile = AppController.instance.currentProfile;
      if (profileBlocksExplicitMusic(profile) && track.explicit) return false;
      if (profileBlocksMatureMusic(profile) && track.matureTheme) return false;
      return true;
    }).toList();
    tracks.sort((a, b) => (store.listenCounts[b.id] ?? 0).compareTo(store.listenCounts[a.id] ?? 0));
    return tracks.take(18).toList();
  }

  @override
  Widget build(BuildContext context) {
    final mix = _mix();
    return Scaffold(
      appBar: AppBar(title: const UniversalText('AI DJ')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const UniversalText('Your AI DJ', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const UniversalText('A continuous queue assembled from your listening activity and music library. Playback stays on your account server.', style: TextStyle(color: Colors.white60)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: mix.isEmpty ? null : () async {
              MusicLibraryStore.instance.setQueue(mix, aiDj: true);
              await MusicPlaybackController.instance.play(mix.first);
              if (context.mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: const UniversalText('START AI DJ'),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < mix.length; i++)
            Card(
              child: ListTile(
                leading: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w900)),
                title: Text(mix[i].title),
                subtitle: Text(mix[i].artist),
                trailing: IconButton(
                  icon: const Icon(Icons.play_arrow_rounded),
                  onPressed: () => MusicPlaybackController.instance.play(mix[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MusicDiscoverArtwork extends StatelessWidget {
  final MusicTrack track;
  const _MusicDiscoverArtwork({required this.track});

  @override
  Widget build(BuildContext context) {
    final url = track.artworkUrl?.trim();
    if (url == null || url.isEmpty) return const CircleAvatar(child: Icon(Icons.album_rounded));
    return CircleAvatar(backgroundImage: NetworkImage(url));
  }
}

class _MusicSearchDelegate extends SearchDelegate<MusicTrack?> {
  final List<MusicTrack> tracks;
  _MusicSearchDelegate(this.tracks);

  @override
  List<Widget>? buildActions(BuildContext context) => [
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
      children: [
        for (final track in tracks.where(
          (track) => '${track.title} ${track.artist} ${track.album}'
              .toLowerCase()
              .contains(q),
        ))
          ListTile(
            title: Text(track.title),
            subtitle: UniversalText('${track.artist} • ${track.album}'),
            onTap: () {
              MusicPlaybackController.instance.play(track);
              close(context, track);
            },
          ),
      ],
    );
  }
}

/// Music-specific visual and discovery customization.
class _MusicCustomization extends StatefulWidget {
  final MusicLibraryStore store;
  const _MusicCustomization({required this.store});

  @override
  State<_MusicCustomization> createState() => _MusicCustomizationState();
}

class _MusicCustomizationState extends State<_MusicCustomization> {
  late MusicPageCustomization draft;

  @override
  void initState() {
    super.initState();
    draft = MusicPageCustomizationStore.settingsFor(
      AppController.instance.currentProfile,
    );
  }

  void _save() {
    MusicPageCustomizationStore.apply(
      AppController.instance.currentProfile,
      draft,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: .94,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          children: [
            const UniversalText('Music customization',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const UniversalText('Build a Spotify-inspired Music page without moving your audio files from the account server.',
              style: TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 18),
            _dropdown('Card style', draft.cardStyle,
                ['Comfortable', 'Compact', 'Large'], (v) {
              setState(() => draft.cardStyle = v);
            }),
            const SizedBox(height: 10),
            _dropdown('Player style', draft.playerStyle,
                ['Bottom player', 'Compact'], (v) {
              setState(() => draft.playerStyle = v);
            }),
            const SizedBox(height: 18),
            _toggle('Search bar', 'Show music search.', draft.showSearch,
                (v) => setState(() => draft.showSearch = v)),
            _toggle('Player', 'Show the persistent music player and queue.',
                draft.showPlayer, (v) => setState(() => draft.showPlayer = v)),
            _toggle('Weekly Discovery', 'Show your weekly discovery mix.',
                draft.showWeeklyDiscovery,
                (v) => setState(() => draft.showWeeklyDiscovery = v)),
            _toggle('AI DJ', 'Show the AI DJ launcher.',
                draft.showAIDJ, (v) => setState(() => draft.showAIDJ = v)),
            _toggle('System playlists', 'Show Made For You / Discover Weekly / Daily Mix.',
                draft.showSystemPlaylists,
                (v) => setState(() => draft.showSystemPlaylists = v)),
            _toggle('Liked Songs', 'Show liked tracks.', draft.showLikedSongs,
                (v) => setState(() => draft.showLikedSongs = v)),
            _toggle('Recently Played', 'Show recent listening activity.',
                draft.showRecentlyPlayed,
                (v) => setState(() => draft.showRecentlyPlayed = v)),
            _toggle('Mood & Genre Mixes', 'Show quick mood/genre mixes.',
                draft.showMoodMixes,
                (v) => setState(() => draft.showMoodMixes = v)),
            _toggle('Artists', 'Show singers and bands.', draft.showArtists,
                (v) => setState(() => draft.showArtists = v)),
            _toggle('Albums', 'Show ripped albums.', draft.showAlbums,
                (v) => setState(() => draft.showAlbums = v)),
            _toggle('Playlists', 'Show custom playlists.', draft.showPlaylists,
                (v) => setState(() => draft.showPlaylists = v)),
            _toggle('Soundtrack Universe', 'Connect music to films and shows.',
                draft.showSoundtrackUniverse,
                (v) => setState(() => draft.showSoundtrackUniverse = v)),
            const SizedBox(height: 18),
            const UniversalText('SECTION ORDER',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.3,
                    color: Colors.white54)),
            const SizedBox(height: 8),
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              onReorderItem: (oldIndex, newIndex) {
                setState(() {
                  final item = draft.sectionOrder.removeAt(oldIndex);
                  draft.sectionOrder.insert(newIndex, item);
                });
              },
              children: [
                for (final item in draft.sectionOrder)
                  ListTile(
                    key: ValueKey(item),
                    leading: const Icon(Icons.drag_handle_rounded),
                    title: Text(item),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_rounded),
                label: const UniversalText('SAVE MUSIC CUSTOMIZATION'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggle(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _dropdown(
    String label,
    String value,
    List<String> values,
    ValueChanged<String> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: values.contains(value) ? value : values.first,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final item in values)
          DropdownMenuItem(value: item, child: Text(item)),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

/// Opens soundtrack connections between music and owned film/TV metadata.
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
      appBar: AppBar(title: const UniversalText('Soundtrack Universe')),
      body: rows.isEmpty
          ? const Center(
              child: UniversalText('No soundtrack metadata has been imported yet.'),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(18),
              itemCount: rows.length,
              itemBuilder: (_, index) {
                final row = rows[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.music_note_rounded),
                    title: Text(row.value,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: UniversalText('From ${row.key.title}'),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MediaDetailsScreen(media: row.key),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
