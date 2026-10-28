// FILE: `lib/music.dart`.
// Purpose: Implements the Spotify-inspired music destination, player, discovery
// features, playlists and per-profile music customization.
// Physical audio files remain on the account's home server.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'backend_api.dart';
import 'app_core.dart';
import 'catalog_poster_image.dart' show AlbumArtworkImage;
import 'music_favorites.dart';
import 'music_genre_system.dart';
import 'details.dart';
import 'localization.dart';
import 'media_text_localizer.dart';
import 'profile_content_safety.dart';
import 'shop.dart';
import 'media_actions.dart';
import 'navidrome_setup.dart';
import 'social_sharing.dart';
import 'music_catalog_screen.dart';
import 'cinematic_title_fonts.dart';
import 'music_video_search_screen.dart';
import 'music_lyrics_search_screen.dart';
import 'library_view_modes.dart';

/// A music track imported from the account's home-server library.
class MusicTrack {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String? artworkUrl;
  final String? audioUrl;

  /// Optional locally stored music-video stream for this exact track.
  final String? musicVideoUrl;
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
  final String lyrics;

  /// Filesystem modification time supplied by the home-server scanner. This
  /// is a freshness signal, not the official album release date.
  final DateTime? modifiedAt;

  const MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    this.artworkUrl,
    this.audioUrl,
    this.musicVideoUrl,
    this.duration = Duration.zero,
    this.genres = const <String>[],
    this.featuredArtists = const <String>[],
    this.subgenres = const <String>[],
    this.explicit = false,
    this.matureTheme = false,
    this.lyrics = '',
    this.modifiedAt,
  });

  /// Canonicalized broad genres plus subgenres, without changing source tags.
  List<String> get allGenreTags => MusicGenreSystem.allTags(
        genres,
        subgenres: subgenres,
      );

  /// A hybrid/crossover label suitable for cards, search, and generated mixes.
  String get genreBlendLabel => MusicGenreSystem.displayLabel(
        genres,
        subgenres: subgenres,
      );

  /// True when metadata describes more than one broad genre or style family.
  bool get hasGenreBlend => MusicGenreSystem.hasBlend(
        genres,
        subgenres: subgenres,
      );

  String get genreDisplayLabel => allGenreTags.isEmpty
      ? 'Genre not specified'
      : (hasGenreBlend ? genreBlendLabel : allGenreTags.join(' • '));

  List<String> get genreSearchTerms => MusicGenreSystem.searchTerms(
        genres,
        subgenres: subgenres,
      );
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
              'Featured Tracks',
              'AI DJ',
              'Made For You',
              'Liked Songs',
              'On Repeat',
              'Top 100 Most Played',
              'Recently Played',
              'Mood Mixes',
              'Artists',
              'Albums',
              'Playlists',
              'Soundtrack Universe',
              'Genre Blends',
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
      'Featured Tracks',
      'AI DJ',
      'Made For You',
      'Liked Songs',
      'On Repeat',
      'Top 100 Most Played',
      'Recently Played',
      'Mood Mixes',
      'Artists',
      'Albums',
      'Playlists',
      'Soundtrack Universe',
      'Genre Blends',
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

  /// Recent per-profile listening timestamps used for an actual rolling 7-day chart.
  /// The legacy all-time listenCounts map remains available for existing screens.
  final Map<String, List<int>> listenEventTimestamps = <String, List<int>>{};

  bool get hasWeeklyListenData {
    final cutoff = DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;
    return listenEventTimestamps.values.any((events) => events.any((value) => value >= cutoff));
  }

  int weeklyListenCount(String trackId, {DateTime? now}) {
    final cutoff = (now ?? DateTime.now()).subtract(const Duration(days: 7)).millisecondsSinceEpoch;
    return (listenEventTimestamps[trackId] ?? const <int>[])
        .where((value) => value >= cutoff)
        .length;
  }

  /// Rule-based playlists are derived from current profile state on every read.
  /// They are intentionally not copied into custom playlists, so likes and
  /// listening history can update them without overwriting user curation.
  Map<String, List<String>> get smartPlaylists {
    final availableIds = tracks.map((track) => track.id).toSet();
    final liked = MusicFavoritesBridge.likedTracks()
        .where(availableIds.contains)
        .toList(growable: false);
    final recentlyAdded = tracks.toList()
      ..sort((a, b) {
        final aDate = a.modifiedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.modifiedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateCompare = bDate.compareTo(aDate);
        return dateCompare != 0
            ? dateCompare
            : a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
    final mostPlayed = listenCounts.entries
        .where((entry) => entry.value > 0 && availableIds.contains(entry.key))
        .toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        final aTitle =
            tracks.firstWhere((track) => track.id == a.key).title.toLowerCase();
        final bTitle =
            tracks.firstWhere((track) => track.id == b.key).title.toLowerCase();
        return aTitle.compareTo(bTitle);
      });
    final rankedIds =
        mostPlayed.map((entry) => entry.key).toList(growable: false);
    final output = <String, List<String>>{
      'Liked Songs': liked,
      'Recently Added': recentlyAdded
          .take(50)
          .map((track) => track.id)
          .toList(growable: false),
      'Most Played': rankedIds,
      'On Repeat': mostPlayed
          .where((entry) => entry.value >= 2)
          .take(50)
          .map((entry) => entry.key)
          .toList(growable: false),
      'Top 100 Most Played': rankedIds.take(100).toList(growable: false),
    };
    final genres = <String>{
      for (final track in tracks) ...track.allGenreTags,
    }.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    for (final genre in genres.take(12)) {
      output['$genre Mix'] = tracks
          .where((track) => MusicGenreSystem.matchesGenres(
                track.genres,
                <String>[genre],
                itemSubgenres: track.subgenres,
              ))
          .map((track) => track.id)
          .toList(growable: false);
    }

    final blendLabels = <String>{
      for (final track in tracks)
        if (track.hasGenreBlend) track.genreBlendLabel,
    }.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    for (final label in blendLabels.take(12)) {
      final mixKey = '$label Mix';
      output[mixKey] = <String>{
        ...(output[mixKey] ?? const <String>[]),
        ...tracks
            .where((track) =>
                track.hasGenreBlend && track.genreBlendLabel == label)
            .map((track) => track.id),
      }.toList(growable: false);
    }
    return output;
  }

  SharedPreferences? _playlistPreferences;
  String _playlistProfileKey = 'default';
  Future<void> _initializationQueue = Future<void>.value();

  /// Serializes profile initialization because Home and Music can both request
  /// it during the same first frame. This prevents duplicate preview entries
  /// and overlapping profile-preference writes.
  Future<void> initializeForProfile(String? profileId) {
    final next = _initializationQueue.then((_) => _initializeForProfile(profileId));
    _initializationQueue = next.catchError((Object _) {});
    return next;
  }

  Future<void> _initializeForProfile(String? profileId) async {
    _playlistPreferences ??= await SharedPreferences.getInstance();
    _playlistProfileKey =
        profileId?.trim().isNotEmpty == true ? profileId!.trim() : 'default';
    playlists
      ..clear()
      ..addAll(_decodePlaylists(
        _playlistPreferences!.getString('music_playlists_$_playlistProfileKey'),
      ));
    listenCounts
      ..clear()
      ..addAll(_decodeListenCounts(
        _playlistPreferences!
            .getString('music_listen_counts_$_playlistProfileKey'),
      ));
    listenEventTimestamps
      ..clear()
      ..addAll(_decodeListenEvents(
        _playlistPreferences!.getString('music_listen_events_$_playlistProfileKey'),
      ));

    // Preview-only tracks provide a realistic album page while keeping actual
    // playback disabled: the demo entries intentionally have no audio URLs.
    if (!tracks.any((track) => track.id == 'demo-preview-album-track-1')) {
      tracks.addAll(const [
        MusicTrack(
          id: 'demo-preview-album-track-1',
          title: 'Signal in the Dark (Preview)',
          artist: 'The Night Archive (Demo Artist)',
          album: 'Midnight Signals (Preview Album)',
          duration: Duration(minutes: 3, seconds: 42),
          genres: ['Electronic', 'Ambient'],
        ),
        MusicTrack(
          id: 'demo-preview-album-track-2',
          title: 'Neon Rain (Preview)',
          artist: 'The Night Archive (Demo Artist)',
          album: 'Midnight Signals (Preview Album)',
          duration: Duration(minutes: 4, seconds: 8),
          genres: ['Electronic', 'Ambient'],
        ),
        MusicTrack(
          id: 'demo-preview-album-track-3',
          title: 'Last Transmission (Preview)',
          artist: 'The Night Archive (Demo Artist)',
          album: 'Midnight Signals (Preview Album)',
          duration: Duration(minutes: 3, seconds: 56),
          genres: ['Electronic', 'Ambient'],
        ),
      ]);
    }

    // Local album/artist examples ensure Album and Artist details can be
    // explored before a real music library is imported. No audio URLs are set.
    const catalogExampleTracks = <MusicTrack>[
      MusicTrack(id: 'demo-catalog-track-1989-blank-space', title: 'Blank Space', artist: 'Taylor Swift', album: '1989', duration: Duration(minutes: 3, seconds: 51), genres: ['Pop']),
      MusicTrack(id: 'demo-catalog-track-1989-style', title: 'Style', artist: 'Taylor Swift', album: '1989', duration: Duration(minutes: 3, seconds: 51), genres: ['Pop']),
      MusicTrack(id: 'demo-catalog-track-1989-shake-it-off', title: 'Shake It Off', artist: 'Taylor Swift', album: '1989', duration: Duration(minutes: 3, seconds: 39), genres: ['Pop']),
      MusicTrack(id: 'demo-catalog-track-rare-rare', title: 'Rare', artist: 'Selena Gomez', album: 'Rare', duration: Duration(minutes: 3, seconds: 40), genres: ['Pop', 'Dance Pop']),
      MusicTrack(id: 'demo-catalog-track-rare-lose-you-to-love-me', title: 'Lose You to Love Me', artist: 'Selena Gomez', album: 'Rare', duration: Duration(minutes: 3, seconds: 26), genres: ['Pop']),
      MusicTrack(id: 'demo-catalog-track-rare-look-at-her-now', title: 'Look at Her Now', artist: 'Selena Gomez', album: 'Rare', duration: Duration(minutes: 2, seconds: 55), genres: ['Pop']),
      MusicTrack(id: 'demo-catalog-track-yhlqmdlg-la-dificil', title: 'La Difícil', artist: 'Bad Bunny', album: 'YHLQMDLG', duration: Duration(minutes: 2, seconds: 43), genres: ['Latin', 'Reggaeton']),
      MusicTrack(id: 'demo-catalog-track-yhlqmdlg-yo-perreo-sola', title: 'Yo Perreo Sola', artist: 'Bad Bunny', album: 'YHLQMDLG', duration: Duration(minutes: 2, seconds: 52), genres: ['Latin', 'Reggaeton']),
      MusicTrack(id: 'demo-catalog-track-yhlqmdlg-safaera', title: 'Safaera', artist: 'Bad Bunny', album: 'YHLQMDLG', duration: Duration(minutes: 4, seconds: 55), genres: ['Latin', 'Reggaeton', 'Latin Trap']),
      MusicTrack(id: 'demo-catalog-track-colores-amarillo', title: 'Amarillo', artist: 'J Balvin', album: 'Colores', duration: Duration(minutes: 2, seconds: 37), genres: ['Latin', 'Reggaeton']),
      MusicTrack(id: 'demo-catalog-track-colores-azul', title: 'Azul', artist: 'J Balvin', album: 'Colores', duration: Duration(minutes: 3, seconds: 25), genres: ['Latin', 'Reggaeton']),
      MusicTrack(id: 'demo-catalog-track-colores-rojo', title: 'Rojo', artist: 'J Balvin', album: 'Colores', duration: Duration(minutes: 2, seconds: 30), genres: ['Latin', 'Reggaeton']),
    ];
    for (final example in catalogExampleTracks) {
      if (!tracks.any((track) => track.id == example.id)) tracks.add(example);
    }

    // Smart playlists are derived automatically from the current music library.
    // Save names per profile; notify only for genuinely new generated genre mixes,
    // not for the baseline set on first launch.
    final knownPlaylistKey = 'music_known_auto_playlists_$_playlistProfileKey';
    final currentAutomaticNames = smartPlaylists.keys
        .where((name) => name.endsWith(' Mix'))
        .toSet();
    final previouslyKnown = _playlistPreferences!
        .getStringList(knownPlaylistKey);
    if (previouslyKnown == null) {
      await _playlistPreferences!.setStringList(
        knownPlaylistKey,
        currentAutomaticNames.toList()..sort(),
      );
    } else {
      final previousSet = previouslyKnown.toSet();
      final newNames = currentAutomaticNames.difference(previousSet).toList()..sort();
      for (final name in newNames) {
        AppController.instance.addNotification(
          action: 'a new automatic playlist was created: $name',
        );
      }
      if (newNames.isNotEmpty || previousSet.length != currentAutomaticNames.length) {
        await _playlistPreferences!.setStringList(
          knownPlaylistKey,
          currentAutomaticNames.toList()..sort(),
        );
      }
    }
    notifyListeners();
  }

  Map<String, List<String>> _decodePlaylists(String? encoded) {
    if (encoded == null || encoded.isEmpty) return <String, List<String>>{};
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return <String, List<String>>{};
      return decoded.map((key, value) => MapEntry(
            key.toString(),
            value is List
                ? value.map((id) => id.toString()).toList()
                : <String>[],
          ));
    } catch (_) {
      return <String, List<String>>{};
    }
  }

  Map<String, int> _decodeListenCounts(String? encoded) {
    if (encoded == null || encoded.isEmpty) return <String, int>{};
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return <String, int>{};
      return decoded.map((key, value) => MapEntry(
            key.toString(),
            value is num ? value.toInt().clamp(0, 1000000000) : 0,
          ));
    } catch (_) {
      return <String, int>{};
    }
  }

  Map<String, List<int>> _decodeListenEvents(String? encoded) {
    if (encoded == null || encoded.isEmpty) return <String, List<int>>{};
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return <String, List<int>>{};
      final cutoff = DateTime.now().subtract(const Duration(days: 45)).millisecondsSinceEpoch;
      return decoded.map((key, value) {
        final events = value is List
            ? value.whereType<num>().map((entry) => entry.toInt()).where((entry) => entry >= cutoff).toList(growable: true)
            : <int>[];
        return MapEntry(key.toString(), events);
      })..removeWhere((_, events) => events.isEmpty);
    } catch (_) {
      return <String, List<int>>{};
    }
  }

  Future<void> _persistListenEvents() async {
    final preferences = _playlistPreferences ??= await SharedPreferences.getInstance();
    await preferences.setString(
      'music_listen_events_$_playlistProfileKey',
      jsonEncode(listenEventTimestamps),
    );
  }

  Future<void> _persistListenCounts() async {
    final preferences =
        _playlistPreferences ??= await SharedPreferences.getInstance();
    await preferences.setString(
      'music_listen_counts_$_playlistProfileKey',
      jsonEncode(listenCounts),
    );
  }

  void _persistPlaylists() {
    _playlistPreferences?.setString(
      'music_playlists_$_playlistProfileKey',
      jsonEncode(playlists),
    );
  }

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
    final registeredGenreBlends = <String>{};

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

      for (final genre in track.allGenreTags) {
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

      if (track.hasGenreBlend) {
        final blend = track.genreBlendLabel.trim();
        final key = blend.toLowerCase();
        if (blend.isNotEmpty && registeredGenreBlends.add(key)) {
          entities.add(
            ShopEntity(
              type: 'genre',
              id: 'music-genre-blend:$key',
              name: blend,
              subtitle: 'Genre blend • Music',
            ),
          );
        }
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
  void createPlaylist(String name,
      {Iterable<String> trackIds = const <String>[]}) {
    final clean = name.trim();
    if (clean.isEmpty || playlists.containsKey(clean)) return;
    playlists[clean] = trackIds.toList();
    _persistPlaylists();
    AppController.instance.addNotification(action: 'created a new playlist: $clean');
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
    _persistPlaylists();
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
    _persistPlaylists();
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

  void addToQueue(MusicTrack track, {int? index}) {
    queue.remove(track.id);
    final insertAt = (index ?? queue.length).clamp(0, queue.length).toInt();
    queue.insert(insertAt, track.id);
    notifyListeners();
  }

  void removeFromQueue(String trackId) {
    queue.remove(trackId);
    if (queue.isEmpty) aiDjActive = false;
    notifyListeners();
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= queue.length) return;
    if (newIndex < 0 || newIndex >= queue.length) return;
    final id = queue.removeAt(oldIndex);
    queue.insert(newIndex, id);
    notifyListeners();
  }

  void clearQueue() {
    queue.clear();
    aiDjActive = false;
    notifyListeners();
  }

  /// Records and persists one listening event for this profile. The resulting
  /// local chart is a personal listening chart, not a worldwide streaming rank.
  void recordListen(String trackId) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final cutoff = DateTime.now().subtract(const Duration(days: 45)).millisecondsSinceEpoch;
    final events = listenEventTimestamps.putIfAbsent(trackId, () => <int>[]);
    events.removeWhere((timestamp) => timestamp < cutoff);
    events.add(now);
    listenCounts[trackId] = (listenCounts[trackId] ?? 0) + 1;
    unawaited(_persistListenCounts());
    unawaited(_persistListenEvents());
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
  bool _wrappedCompletionRecordedForCurrentPlayback = false;
  String? _playbackProfileId;
  Timer? _presenceHeartbeat;

  VideoPlayerController? get videoController => _controller;
  bool get isReady => _controller?.value.isInitialized == true;

  String _listeningActivity(MusicTrack track) {
    final library = MusicLibraryStore.instance;
    final playlist = library.activePlaylist;
    if (playlist != null && playlist.trim().isNotEmpty) {
      final ids = library.playlists[playlist] ?? const <String>[];
      final index = ids.indexOf(track.id);
      if (index >= 0) {
        return _capActivity(
            'Listening to playlist $playlist, item ${index + 1}, ${track.title}');
      }
    }
    final album = track.album.trim();
    if (album.isNotEmpty) {
      return _capActivity(
          'Listening to album $album, ${track.title} by ${track.artist}');
    }
    return _capActivity('Listening to ${track.title} by ${track.artist}');
  }

  String _capActivity(String value) =>
      value.length <= 160 ? value : '${value.substring(0, 157)}...';

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
    _playbackProfileId = profile?.id;
    _wrappedCompletionRecordedForCurrentPlayback = false;
    MusicLibraryStore.instance.currentTrackId = track.id;

    if (url == null || url.isEmpty) {
      isPlaying = false;
      notifyListeners();
      unawaited(_updateSocialListeningActivity(null));
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
      MusicLibraryStore.instance.recordListen(track.id);
      unawaited(
        _updateSocialListeningActivity(
          _listeningActivity(track),
        ),
      );
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

    final finishedTrack = currentTrack;
    if (finishedTrack != null && !_wrappedCompletionRecordedForCurrentPlayback) {
      _wrappedCompletionRecordedForCurrentPlayback = true;
      unawaited(AppController.instance.recordWrappedActivityDetails(
        mediaId: finishedTrack.id,
        canonicalWorkId: finishedTrack.id,
        title: finishedTrack.title,
        type: 'song',
        genres: finishedTrack.allGenreTags,
        artist: finishedTrack.artist,
        album: finishedTrack.album,
        profileIdOverride: _playbackProfileId,
      ));
    }

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
      unawaited(_updateSocialListeningActivity(null));
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
    final track = currentTrack;
    if (track != null) {
      unawaited(
        _updateSocialListeningActivity(
          _listeningActivity(track),
        ),
      );
    }
  }

  /// Toggles play/pause for the active track.
  Future<void> toggle() async {
    final controller = _controller;
    if (controller == null || !isReady) return;
    if (controller.value.isPlaying) {
      await controller.pause();
      isPlaying = false;
      unawaited(_updateSocialListeningActivity(null));
    } else {
      await controller.play();
      isPlaying = true;
      final track = currentTrack;
      if (track != null) {
        unawaited(
          _updateSocialListeningActivity(
            _listeningActivity(track),
          ),
        );
      }
    }
    notifyListeners();
  }

  Future<void> _updateSocialListeningActivity(String? activity) async {
    final profile = AppController.instance.currentProfile;
    final api = AppController.instance.backendApi;

    _presenceHeartbeat?.cancel();
    _presenceHeartbeat = null;

    if (activity == null) {
      if (profile != null && api.isAuthenticated) {
        try {
          await api.setSocialProfilePresence(
            profileId: profile.id,
            clearActivity: true,
          );
        } catch (error) {
          debugPrint(
            'Unable to update music presence: '
            '${error.toString().replaceFirst('Exception: ', '')}',
          );
        }
      }
      return;
    }

    if (profile == null || !api.isAuthenticated) return;

    try {
      await api.setSocialProfilePresence(
        profileId: profile.id,
        availability: 'busy',
        activityType: 'listening',
        activityText: activity,
        clearActivity: false,
      );
    } catch (error) {
      debugPrint(
        'Unable to update music presence: '
        '${error.toString().replaceFirst('Exception: ', '')}',
      );
    }

    _presenceHeartbeat = Timer.periodic(
      const Duration(minutes: 1),
      (_) {
        final track = currentTrack;
        unawaited(
          _updateSocialListeningActivity(
            isPlaying && track != null ? _listeningActivity(track) : null,
          ),
        );
      },
    );
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
  LibraryViewMode _albumViewMode = LibraryViewPreferenceStore.get(
    'music-albums',
    fallback: LibraryViewMode.grid,
  );
  final playback = MusicPlaybackController.instance;

  @override
  void initState() {
    super.initState();
    // Ensure album catalog examples are available even if Music is the first
    // destination opened after launch (without visiting Home first).
    AppController.instance.ensureDemoPreviewMedia(notify: false);
    unawaited(library.initializeForProfile(
      AppController.instance.currentProfile?.id,
    ));
    unawaited(MusicFavoritesBridge.initializeForProfile(
      AppController.instance.currentProfile?.id,
    ));
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
      animation: Listenable.merge(
          <Listenable>[library, playback, MusicFavoritesBridge.changes]),
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Color(int.parse(library.homeBackground)),
          body: SafeArea(
            child: CustomScrollView(
              slivers: <Widget>[
                SliverAppBar(
                  pinned: true,
                  title: const UniversalText(
                    'Music',
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
                      onPressed: _openLyricsSearch,
                      icon: const Icon(Icons.lyrics_outlined),
                      tooltip: 'Find a song by lyrics or sound',
                    ),
                    IconButton(
                      onPressed: _openMusicCatalog,
                      icon: const Icon(Icons.library_music_rounded),
                      tooltip: 'Search Spotify, MusicBrainz, and cover art',
                    ),
                    IconButton(
                      onPressed: _openDiscover,
                      icon: const Icon(Icons.explore_rounded),
                      tooltip: 'Discover music',
                    ),
                    IconButton(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                              builder: (_) => const NavidromeSetupScreen())),
                      icon: const Icon(Icons.dns_rounded),
                      tooltip: 'Connect personal music server',
                    ),
                    IconButton(
                      onPressed: _showCustomization,
                      icon: const Icon(Icons.tune_rounded),
                    ),
                  ],
                ),
                if (settings.showPlayer && playback.currentTrack != null)
                  SliverToBoxAdapter(child: _buildPlayer(settings)),
                SliverToBoxAdapter(child: _musicCatalogEntrySection()),
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
                LocalizedMediaText(track.title,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(track.artist,
                    style: const TextStyle(color: Colors.white60)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Visualizer, lyrics, or music video',
            onPressed: () => _showTrackDisplayOptions(track),
            icon: const Icon(Icons.graphic_eq_rounded),
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

  Future<void> _showTrackDisplayOptions(MusicTrack track) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF171717),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LocalizedMediaText(track.title,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
                Text(track.artist,
                    style: const TextStyle(color: Colors.white60)),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.graphic_eq_rounded),
                  title: const UniversalText('Audio visualizer'),
                  subtitle: const UniversalText(
                      'Keep audio playing with an animated visualizer.'),
                  onTap: () => Navigator.of(sheetContext).push(
                      MaterialPageRoute<void>(
                          builder: (_) => MusicTrackDisplayScreen(
                              track: track,
                              mode: MusicTrackDisplayMode.visualizer))),
                ),
                ListTile(
                  leading: const Icon(Icons.lyrics_rounded),
                  title: const UniversalText('Lyrics + visualizer'),
                  subtitle: Text(track.lyrics.trim().isEmpty
                      ? 'No local lyrics are available for this track.'
                      : 'Display available track lyrics with animated visuals.'),
                  onTap: () => Navigator.of(sheetContext).push(
                      MaterialPageRoute<void>(
                          builder: (_) => MusicTrackDisplayScreen(
                              track: track,
                              mode: MusicTrackDisplayMode.lyricsVisualizer))),
                ),
                ListTile(
                  leading: const Icon(Icons.music_video_rounded),
                  title: const UniversalText('Play linked music video'),
                  subtitle: Text((track.musicVideoUrl?.trim().isNotEmpty ??
                          false)
                      ? 'Play the matching local or authorized video URL.'
                      : 'No local video URL is linked to this track.'),
                  enabled: track.musicVideoUrl?.trim().isNotEmpty ?? false,
                  onTap: () => Navigator.of(sheetContext).push(
                      MaterialPageRoute<void>(
                          builder: (_) => MusicTrackDisplayScreen(
                              track: track,
                              mode: MusicTrackDisplayMode.video))),
                ),
                ListTile(
                  leading: const Icon(Icons.youtube_searched_for_rounded),
                  title: const UniversalText('Find music video on YouTube'),
                  subtitle: const UniversalText(
                      'Search videos matching this artist and song title.'),
                  onTap: () => Navigator.of(sheetContext).push(
                      MaterialPageRoute<void>(
                          builder: (_) => MusicVideoSearchScreen(
                              title: track.title, artist: track.artist))),
                ),
              ]),
        ),
      ),
    );
  }

  List<Widget> _homeSlivers(MusicPageCustomization settings) {
    final output = <Widget>[];
    for (final section in settings.sectionOrder) {
      if (section == 'Featured Tracks') {
        final featuredTracks = library.tracks.where((track) =>
          _isAllowedForCurrentProfile(track) &&
          track.featuredArtists.any((name) => name.trim().isNotEmpty)).toList(growable: false);
        output.add(_trackSection(
          'Featured Tracks',
          'Songs where an artist appears with or is featured by another artist',
          featuredTracks,
          Icons.people_alt_rounded,
        ));
      } else if (section == 'Weekly Discovery' && settings.showWeeklyDiscovery) {
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
      } else if (section == 'On Repeat') {
        output.add(_trackSection(
            'On Repeat',
            'Songs you have replayed most often',
            _tracksForSmartPlaylist('On Repeat'),
            Icons.repeat_rounded));
      } else if (section == 'Top 100 Most Played') {
        output.add(_trackSection(
            'Top 100 Most Played',
            'Your personal top tracks, ranked by recorded plays',
            _tracksForSmartPlaylist('Top 100 Most Played'),
            Icons.trending_up_rounded));
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
          'Imported artists plus catalog examples you can explore',
          library.tracks
              .map((t) => t.artist)
              .where((x) => x.trim().isNotEmpty)
              .toSet()
              .toList(),
          Icons.person_rounded,
          onItemTap: (artist) {
            final normalizedArtist = artist.trim().toLowerCase();
            final seenAlbums = <String>{};
            final credits = <Map<String, dynamic>>[];
            for (final track in library.tracks) {
              if (track.artist.trim().toLowerCase() == normalizedArtist &&
                  track.album.trim().isNotEmpty) {
                final key = track.album.trim().toLowerCase();
                if (seenAlbums.add(key)) {
                  credits.add({
                    'title': track.album,
                    'type': 'Album',
                    'category': 'Music',
                    'role': 'Artist'
                  });
                }
              }
              if (track.featuredArtists.any(
                  (name) => name.trim().toLowerCase() == normalizedArtist)) {
                credits.add({
                  'title': track.title,
                  'type': 'Track',
                  'category': 'Music',
                  'role': 'Featured artist',
                  'creditGroup': track.artist
                });
              }
            }
            Navigator.push(
                context,
                MaterialPageRoute<void>(
                  settings: const RouteSettings(name: '/app/page/artists'),
                  builder: (_) => MusicArtistProfileScreen(artistName: artist),
                ));
          },
        ));
      } else if (section == 'Albums' && settings.showAlbums) {
        output.add(_albumsSection());
      } else if (section == 'Playlists' && settings.showPlaylists) {
        output.add(SliverToBoxAdapter(child: _playlistSliver()));
      } else if (section == 'Soundtrack Universe' &&
          settings.showSoundtrackUniverse) {
        output.add(SliverToBoxAdapter(child: _soundtrackFeature()));
      } else if (section == 'Genre Blends') {
        output.add(_trackSection(
          'Genre-Blending Tracks',
          'Songs in your library that cross genre boundaries',
          library.tracks
              .where(_isAllowedForCurrentProfile)
              .where((track) => track.hasGenreBlend)
              .toList(growable: false),
          Icons.merge_type_rounded,
        ));
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
    final seeds = tracks
        .where((track) => (library.listenCounts[track.id] ?? 0) > 0)
        .toList();
    final seedTracks = seeds.isEmpty ? tracks.take(5).toList() : seeds;
    final seedArtists = <String>{};
    final seedFeatured = <String>{};
    final seedGenres = <String>{};
    final seedSubgenres = <String>{};
    for (final track in seedTracks) {
      seedArtists.add(track.artist.toLowerCase());
      seedFeatured.addAll(track.featuredArtists.map((a) => a.toLowerCase()));
      seedGenres.addAll(track.allGenreTags.map((g) => g.toLowerCase()));
      seedSubgenres.addAll(track.subgenres.map((g) => g.toLowerCase()));
    }

    final scored = <MusicTrack, int>{};
    for (final track in tracks) {
      var score = 0;
      final artist = track.artist.toLowerCase();
      final features =
          track.featuredArtists.map((a) => a.toLowerCase()).toSet();
      if (seedFeatured.contains(artist)) score += 18;
      if (seedArtists.contains(artist)) score += 12;
      if (features.any(seedArtists.contains)) score += 16;
      score += track.allGenreTags
              .map((g) => g.toLowerCase())
              .where(seedGenres.contains)
              .length *
          4;
      score += track.subgenres
              .map((g) => g.toLowerCase())
              .where(seedSubgenres.contains)
              .length *
          6;
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
      final aScore = (library.listenCounts[a.id] ?? 0) +
          a.genres.length +
          a.subgenres.length;
      final bScore = (library.listenCounts[b.id] ?? 0) +
          b.genres.length +
          b.subgenres.length;
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
                UniversalText('AI DJ',
                    style:
                        TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
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
              Text(
                  '${mix.length} tracks selected • AI DJ will continue automatically',
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
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
      SnackBar(
          content: UniversalText(
              'AI DJ started with ${mix.first.title} and queued ${mix.length} tracks.')),
    );
  }

  void _openAiDj() {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const MusicAiDjScreen()));
  }

  void _openDiscover() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const MusicDiscoverScreen()));
  }

  void _openMusicCatalog() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/app/page/music-catalog'),
        builder: (_) => const MusicCatalogScreen(),
      ),
    );
  }

  Widget _musicCatalogEntrySection() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Material(
          color: Colors.white.withValues(alpha: .055),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _openMusicCatalog,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.library_music_rounded, color: Colors.lightGreenAccent),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Music Catalog', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        SizedBox(height: 4),
                        Text('Search Spotify, explore MusicBrainz discographies, and find album artwork', style: TextStyle(color: Colors.white60, height: 1.3, fontSize: 12)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white70),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _systemPlaylistSection() {
    const names = [
      (
        'Made For You',
        'Personal mix from your listening history',
        Icons.person_rounded
      ),
      (
        'Discover Weekly',
        'Fresh tracks from your imported library',
        Icons.explore_rounded
      ),
      (
        'Daily Mix',
        'Familiar artists and albums you play often',
        Icons.repeat_rounded
      ),
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

  List<MusicTrack> _tracksForSmartPlaylist(String name) {
    final byId = <String, MusicTrack>{
      for (final track in library.tracks) track.id: track
    };
    return (library.smartPlaylists[name] ?? const <String>[])
        .map((id) => byId[id])
        .whereType<MusicTrack>()
        .toList(growable: false);
  }

  Widget _likedSongsSection() {
    final liked = MusicFavoritesBridge.likedTracks();
    final tracks =
        library.tracks.where((track) => liked.contains(track.id)).toList();
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
        .expand((track) => track.allGenreTags)
        .where((genre) => genre.trim().isNotEmpty)
        .toSet()
        .take(8)
        .toList();
    final values = genres.isEmpty
        ? const ['Chill', 'Focus', 'Energy', 'Favorites']
        : genres;
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
                subtitle: const UniversalText(
                    'Import or play music from your account server to build this section.'),
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
                    width: 225,
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
                                    LocalizedMediaText(track.title,
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
                                    if (track.hasGenreBlend)
                                      Text(
                                        track.genreBlendLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 10,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: MusicFavoritesBridge.likedTracks()
                                        .contains(track.id)
                                    ? 'Liked'
                                    : 'Like',
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _toggleTrackLike(track),
                                icon: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  child: Icon(
                                    MusicFavoritesBridge.likedTracks()
                                            .contains(track.id)
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    key: ValueKey(
                                        MusicFavoritesBridge.likedTracks()
                                            .contains(track.id)),
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Add to queue',
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  library.addToQueue(track);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              'Added ${track.title} to the queue.')));
                                },
                                icon: const Icon(Icons.queue_music_rounded),
                              ),
                              IconButton(
                                tooltip: 'Add to playlist',
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _selectPlaylistForTrack(track),
                                icon: const Icon(Icons.playlist_add_rounded),
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

  Widget _albumsSection() {
    final albumTracks = <String, MusicTrack>{};
    for (final track in library.tracks) {
      final title = track.album.trim();
      if (title.isNotEmpty) {
        albumTracks.putIfAbsent(title.toLowerCase(), () => track);
      }
    }
    final albumTitles = albumTracks.keys
        .map((key) => albumTracks[key]!.album.trim())
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final entries = albumTitles.map((albumTitle) {
      final track = albumTracks[albumTitle.toLowerCase()]!;
      final tracksOnAlbum = library.tracks
          .where((item) => item.album.trim().toLowerCase() == albumTitle.toLowerCase())
          .length;
      return LibraryViewEntry(
        title: albumTitle,
        subtitle: '${track.artist} · $tracksOnAlbum track${tracksOnAlbum == 1 ? '' : 's'}',
        fallbackIcon: Icons.album_rounded,
        artworkBuilder: (context, fit) => AlbumArtworkImage(
          title: albumTitle,
          artist: track.artist,
          imageUrl: track.artworkUrl,
          fit: fit,
          placeholder: Container(
            color: Colors.white10,
            alignment: Alignment.center,
            child: const Icon(Icons.album_rounded, color: Colors.white38, size: 32),
          ),
          errorPlaceholder: Container(
            color: Colors.white10,
            alignment: Alignment.center,
            child: const Icon(Icons.album_rounded, color: Colors.white38),
          ),
        ),
        onTap: () => _openLibraryAlbum(albumTitle, track),
      );
    }).toList(growable: false);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Albums', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            const Text(
              'Imported albums plus catalog examples; sample entries may not include audio files',
              style: TextStyle(color: Colors.white54),
            ),
            LibraryViewModePicker(
              scope: 'music-albums',
              value: _albumViewMode,
              onChanged: (mode) => setState(() => _albumViewMode = mode),
              compact: true,
            ),
            LibraryCollectionView(
              entries: entries,
              mode: _albumViewMode,
              padding: EdgeInsets.zero,
              emptyMessage: 'No albums in your music library yet.',
            ),
          ],
        ),
      ),
    );
  }

  void _openLibraryAlbum(String albumTitle, MusicTrack sourceTrack) {
    String normalize(String value) => value.toLowerCase().trim().replaceAll(
          RegExp(r"[\s\-_.,:;!?()\[\]{}\\/]+"),
          '',
        );
    final normalizedTitle = normalize(albumTitle);
    final titleMatches = MusicLibraryStore.instance.tracks
        .where((track) => normalize(track.album) == normalizedTitle)
        .toList(growable: false);
    final normalizedArtist = normalize(sourceTrack.artist);
    final artistMatches = titleMatches
        .where((track) => normalize(track.artist) == normalizedArtist)
        .toList(growable: false);
    final albumTracks = artistMatches.isNotEmpty ? artistMatches : titleMatches;
    final match = AppController.instance.library.where((media) =>
        media.type.toLowerCase().contains('album') &&
        normalize(media.title) == normalizedTitle).toList();
    MediaItem? media = match.isEmpty ? null : match.first;
    final localTracks = [
      for (var index = 0; index < albumTracks.length; index++)
        <String, dynamic>{
          'title': albumTracks[index].title,
          'artist': albumTracks[index].artist,
          'durationMs': albumTracks[index].duration.inMilliseconds,
          'trackNumber': index + 1,
          'artworkUrl': albumTracks[index].artworkUrl ?? '',
          'audioUrl': albumTracks[index].audioUrl ?? '',
        },
    ];
    Navigator.of(context).push(MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/app/page/album-details'),
      builder: (_) => OwnedAlbumDetailsScreen(
        media: media,
        albumTitle: albumTitle,
        artistName: sourceTrack.artist,
        artworkUrl: sourceTrack.artworkUrl,
        localTracks: localTracks,
      ),
    ));
  }

  Widget _nameSection(
      String title, String subtitle, List<String> values, IconData icon,
      {ValueChanged<String>? onItemTap}) {
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
                itemBuilder: (_, index) => InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap:
                      onItemTap == null ? null : () => onItemTap(values[index]),
                  child: Container(
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
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleTrackLike(MusicTrack track) async {
    final liked = MusicFavoritesBridge.likedTracks().contains(track.id);
    final result = await UniversalMediaActions.perform(
      context: UniversalMediaActionContext(
        contentType: 'music_track',
        contentId: track.id,
        profileId: AppController.instance.currentProfile?.id ?? 'local-profile',
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
  }

  void _showSmartPlaylist(String name, List<String> trackIds) {
    final byId = <String, MusicTrack>{
      for (final track in library.tracks) track.id: track
    };
    final tracks = trackIds
        .map((id) => byId[id])
        .whereType<MusicTrack>()
        .toList(growable: false);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF151515),
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .72,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Row(children: [
                  const Icon(Icons.auto_awesome_rounded),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(name,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w900))),
                  IconButton(
                    tooltip: 'Share playlist',
                    icon: const Icon(Icons.share_outlined),
                    onPressed: () => showSocialShareDialog(
                      sheetContext,
                      title: name,
                      message:
                          'Shared smart playlist: $name (${tracks.length} songs)',
                      mediaReference: {
                        'type': 'playlist',
                        'mediaType': 'playlist',
                        'mediaId': name,
                        'title': name,
                        'description': '${tracks.length} songs',
                        'trackIds': tracks.map((track) => track.id).toList()
                      },
                    ),
                  ),
                  IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close_rounded)),
                ]),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                        'This list is generated from your current library and activity.',
                        style: TextStyle(color: Colors.white60))),
              ),
              Expanded(
                child: tracks.isEmpty
                    ? const Center(
                        child: Text('No matching tracks yet.',
                            style: TextStyle(color: Colors.white60)))
                    : ListView.builder(
                        itemCount: tracks.length,
                        itemBuilder: (_, index) {
                          final track = tracks[index];
                          return ListTile(
                            leading: const Icon(Icons.music_note_rounded),
                            title: Text(track.title),
                            subtitle: Text(
                              name == 'On Repeat' ||
                                      name == 'Top 100 Most Played' ||
                                      name == 'Most Played'
                                  ? '${track.artist} • ${library.listenCounts[track.id] ?? 0} plays'
                                  : track.artist,
                            ),
                            trailing: Wrap(children: [
                              IconButton(
                                  tooltip: 'Open artist details',
                                  icon:
                                      const Icon(Icons.person_outline_rounded),
                                  onPressed: () => Navigator.of(sheetContext)
                                      .push(MaterialPageRoute<void>(
                                          builder: (_) =>
                                              MusicArtistProfileScreen(
                                                  artistName: track.artist)))),
                              IconButton(
                                  tooltip: 'Add to queue',
                                  icon: const Icon(Icons.queue_music_rounded),
                                  onPressed: () => library.addToQueue(track)),
                              IconButton(
                                  tooltip: 'Play',
                                  icon: const Icon(Icons.play_arrow_rounded),
                                  onPressed: () => unawaited(
                                      MusicPlaybackController.instance
                                          .play(track))),
                            ]),
                            onTap: () => unawaited(
                                MusicPlaybackController.instance.play(track)),
                          );
                        },
                      ),
              ),
            ],
          ),
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
          const Padding(
            padding: EdgeInsets.only(top: 8, bottom: 6),
            child: UniversalText('Smart playlists',
                style: TextStyle(
                    fontWeight: FontWeight.w800, color: Colors.white70)),
          ),
          for (final entry in library.smartPlaylists.entries)
            Card(
              child: ListTile(
                leading:
                    const CircleAvatar(child: Icon(Icons.auto_awesome_rounded)),
                title: Text(entry.key),
                subtitle: UniversalText(
                    '${entry.value.length} songs · updates automatically'),
                trailing: Wrap(children: [
                  IconButton(
                      tooltip: 'Queue playlist',
                      icon: const Icon(Icons.playlist_add_rounded),
                      onPressed: () {
                        library.setQueue(_tracksForSmartPlaylist(entry.key));
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content:
                                Text('Loaded ${entry.key} into the queue.')));
                      }),
                  const Icon(Icons.chevron_right_rounded),
                ]),
                onTap: () => _showSmartPlaylist(entry.key, entry.value),
              ),
            ),
          const Padding(
            padding: EdgeInsets.only(top: 16, bottom: 6),
            child: UniversalText('Your playlists',
                style: TextStyle(
                    fontWeight: FontWeight.w800, color: Colors.white70)),
          ),
          if (library.playlists.isEmpty)
            const Card(
              child: ListTile(
                title: UniversalText('No custom playlists created yet.'),
                subtitle: UniversalText(
                    'System-created playlists are generated automatically above.'),
              ),
            ),
          for (final entry in library.playlists.entries)
            Card(
              child: ListTile(
                onTap: () => _editPlaylistSongs(entry.key),
                title: Text(entry.key),
                subtitle: UniversalText('${entry.value.length} songs'),
                trailing: Wrap(
                  children: [
                    IconButton(
                      tooltip: 'Add or remove songs',
                      icon: const Icon(Icons.playlist_add_rounded),
                      onPressed: () => _editPlaylistSongs(entry.key),
                    ),
                    IconButton(
                      tooltip: 'Share playlist to messages',
                      icon: const Icon(Icons.share_outlined),
                      onPressed: () => showSocialShareDialog(
                        context,
                        title: entry.key,
                        message:
                            'Shared playlist: ${entry.key} (${entry.value.length} songs)',
                        mediaReference: {
                          'type': 'playlist',
                          'mediaType': 'playlist',
                          'mediaId': entry.key,
                          'title': entry.key,
                          'description': '${entry.value.length} songs',
                          'trackIds': entry.value,
                        },
                      ),
                    ),
                    if (ShopCatalog.instance
                        .productsForAssociation('playlist', entry.key,
                            name: entry.key)
                        .isNotEmpty)
                      IconButton(
                        tooltip: 'Shop related products',
                        icon: const Icon(Icons.storefront_outlined),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            settings: const RouteSettings(name: '/app/shop'),
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
                        MusicFavoritesBridge.likedPlaylists()
                                .contains(entry.key)
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
          const UniversalText(
            'Connect songs to the movies and shows where they belong, '
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
    final albumTitle = track.album.trim().isNotEmpty ? track.album : track.title;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AlbumArtworkImage(
        title: albumTitle,
        artist: track.artist,
        imageUrl: track.artworkUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: Container(
          width: size,
          height: size,
          color: Colors.white10,
          alignment: Alignment.center,
          child: const Icon(Icons.album_rounded, color: Colors.white38),
        ),
        errorPlaceholder: Container(
          width: size,
          height: size,
          color: Colors.white10,
          alignment: Alignment.center,
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

  void _openLyricsSearch() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/app/page/music-find-song'),
      builder: (_) => const MusicLyricsSearchScreen(),
    ));
  }

  void _showCustomization() {
    showMusicCustomization(context).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _showQueue() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF101010),
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final byId = <String, MusicTrack>{
            for (final track in library.tracks) track.id: track
          };
          final queuedTracks = library.queue
              .map((id) => byId[id])
              .whereType<MusicTrack>()
              .toList(growable: false);
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(sheetContext).height * .78,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                    child: Row(children: [
                      const Expanded(
                          child: UniversalText('QUEUE',
                              style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2))),
                      Text('${queuedTracks.length} songs',
                          style: const TextStyle(color: Colors.white60)),
                      IconButton(
                          tooltip: 'Clear queue',
                          onPressed: queuedTracks.isEmpty
                              ? null
                              : () {
                                  library.clearQueue();
                                  setSheetState(() {});
                                },
                          icon: const Icon(Icons.clear_all_rounded)),
                    ]),
                  ),
                  if (queuedTracks.isEmpty)
                    Expanded(
                        child: Center(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                          const Icon(Icons.queue_music_rounded,
                              size: 48, color: Colors.white54),
                          const SizedBox(height: 8),
                          const UniversalText('Your queue is empty.'),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                              onPressed: () {
                                library.setQueue(_weeklyDiscovery());
                                setSheetState(() {});
                              },
                              icon: const Icon(Icons.auto_awesome_rounded),
                              label: const UniversalText('Load discovery mix')),
                        ])))
                  else
                    Expanded(
                        child: ReorderableListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: queuedTracks.length,
                      onReorderItem: (oldIndex, newIndex) {
                        library.reorderQueue(oldIndex, newIndex);
                        setSheetState(() {});
                      },
                      itemBuilder: (context, index) {
                        final track = queuedTracks[index];
                        return ListTile(
                          key: ValueKey('queue-${track.id}'),
                          leading: ReorderableDragStartListener(
                              index: index,
                              child: const Icon(Icons.drag_handle_rounded)),
                          title: LocalizedMediaText(track.title,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(track.artist,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: Wrap(children: [
                            IconButton(
                                tooltip: 'Play now',
                                icon: const Icon(Icons.play_arrow_rounded),
                                onPressed: () {
                                  Navigator.pop(sheetContext);
                                  unawaited(playback.play(track));
                                }),
                            IconButton(
                                tooltip: 'Remove from queue',
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  library.removeFromQueue(track.id);
                                  setSheetState(() {});
                                }),
                          ]),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            unawaited(playback.play(track));
                          },
                        );
                      },
                    )),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      Expanded(
                          child: OutlinedButton.icon(
                              onPressed: () {
                                library.setQueue(_weeklyDiscovery(),
                                    aiDj: false);
                                setSheetState(() {});
                              },
                              icon: const Icon(Icons.explore_rounded),
                              label: const UniversalText(
                                  'Replace with discovery mix'))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: FilledButton.icon(
                              onPressed: () {
                                final track = playback.currentTrack;
                                if (track != null) {
                                  library.addToQueue(track);
                                  setSheetState(() {});
                                }
                              },
                              icon: const Icon(Icons.add_rounded),
                              label: const UniversalText('Add current'))),
                    ]),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _selectPlaylistForTrack(MusicTrack track) async {
    if (library.playlists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: UniversalText('Create a playlist first.'),
      ));
      return;
    }
    final playlistName = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            UniversalText('Add “${track.title}” to playlist',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            for (final entry in library.playlists.entries)
              ListTile(
                leading: Icon(entry.value.contains(track.id)
                    ? Icons.check_circle_rounded
                    : Icons.queue_music_rounded),
                title: Text(entry.key),
                subtitle: Text(entry.value.contains(track.id)
                    ? 'Already added'
                    : '${entry.value.length} songs'),
                enabled: !entry.value.contains(track.id),
                onTap: () => Navigator.pop(sheetContext, entry.key),
              ),
          ],
        ),
      ),
    );
    if (playlistName == null) return;
    final profileId =
        AppController.instance.currentProfile?.id ?? 'local-profile';
    final result = await UniversalMediaActions.perform(
      context: UniversalMediaActionContext(
        contentType: 'music_track',
        contentId: track.id,
        profileId: profileId,
        availableActions: const {UniversalMediaAction.addToPlaylist},
      ),
      action: UniversalMediaAction.addToPlaylist,
      targetId: playlistName,
      apply: () => library.toggleTrackInPlaylist(playlistName, track.id),
    );
    if (!result.applied || !mounted) return;
    library.registerShopEntities();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added ${track.title} to $playlistName.')),
    );
  }

  Future<void> _createPlaylist() async {
    final controller = TextEditingController();
    final selectedTrackIds = <String>{};
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const UniversalText('New playlist'),
          content: SizedBox(
            width: 420,
            height: 420,
            child: Column(
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: InputDecoration(labelText: tr('Playlist name')),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Choose songs (${selectedTrackIds.length})'),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: library.tracks.isEmpty
                      ? const Center(
                          child: UniversalText(
                              'No songs in your music library yet.'),
                        )
                      : ListView.builder(
                          itemCount: library.tracks.length,
                          itemBuilder: (context, index) {
                            final track = library.tracks[index];
                            final selected =
                                selectedTrackIds.contains(track.id);
                            return CheckboxListTile(
                              value: selected,
                              dense: true,
                              secondary: _artwork(track, size: 40),
                              title: LocalizedMediaText(track.title,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(track.artist,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              onChanged: (value) => setDialogState(() {
                                if (value == true) {
                                  selectedTrackIds.add(track.id);
                                } else {
                                  selectedTrackIds.remove(track.id);
                                }
                              }),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const UniversalText('Cancel')),
            FilledButton(
              onPressed: controller.text.trim().isEmpty
                  ? null
                  : () {
                      library.createPlaylist(controller.text,
                          trackIds: selectedTrackIds);
                      Navigator.pop(dialogContext, true);
                    },
              child: const UniversalText('Create'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (created == true && mounted) setState(() {});
  }

  Future<void> _editPlaylistSongs(String playlistName) async {
    final playlist = library.playlists[playlistName];
    if (playlist == null) return;
    final selected = Set<String>.from(playlist);
    final result = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Songs in $playlistName'),
          content: SizedBox(
            width: 420,
            height: 420,
            child: library.tracks.isEmpty
                ? const Center(
                    child: UniversalText('No songs in your music library yet.'),
                  )
                : ListView.builder(
                    itemCount: library.tracks.length,
                    itemBuilder: (context, index) {
                      final track = library.tracks[index];
                      final isSelected = selected.contains(track.id);
                      return CheckboxListTile(
                        value: isSelected,
                        dense: true,
                        secondary: _artwork(track, size: 40),
                        title: LocalizedMediaText(track.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(track.artist,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        onChanged: (value) => setDialogState(() {
                          if (value == true) {
                            selected.add(track.id);
                          } else {
                            selected.remove(track.id);
                          }
                        }),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const UniversalText('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, selected.toList()),
              child: const UniversalText('Save songs'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    final current =
        List<String>.from(library.playlists[playlistName] ?? const []);
    for (final id in current.where((id) => !result.contains(id))) {
      library.toggleTrackInPlaylist(playlistName, id);
    }
    for (final id in result.where((id) => !current.contains(id))) {
      library.toggleTrackInPlaylist(playlistName, id);
    }
    library.registerShopEntities();
    if (mounted) setState(() {});
  }
}

/// Dedicated music discovery experience.
enum MusicTrackDisplayMode { visualizer, lyricsVisualizer, video }

class MusicTrackDisplayScreen extends StatefulWidget {
  const MusicTrackDisplayScreen(
      {super.key, required this.track, required this.mode});
  final MusicTrack track;
  final MusicTrackDisplayMode mode;
  @override
  State<MusicTrackDisplayScreen> createState() =>
      _MusicTrackDisplayScreenState();
}

class _MusicTrackDisplayScreenState extends State<MusicTrackDisplayScreen> {
  VideoPlayerController? _video;
  String? _videoError;

  @override
  void initState() {
    super.initState();
    if (widget.mode == MusicTrackDisplayMode.video) _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    final raw = widget.track.musicVideoUrl?.trim();
    final uri = raw == null ? null : Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme) {
      setState(() =>
          _videoError = 'No valid music-video URL is linked to this track.');
      return;
    }
    final controller = VideoPlayerController.networkUrl(uri);
    _video = controller;
    try {
      await controller.initialize();
      await controller.play();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        setState(() => _videoError =
            'The music video could not be loaded. Check the local media gateway and video URL.');
      }
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.mode == MusicTrackDisplayMode.video;
    final showLyrics = widget.mode == MusicTrackDisplayMode.lyricsVisualizer;
    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080808),
        title: LocalizedMediaText(widget.track.title),
        actions: [
          IconButton(
            tooltip: isVideo ? 'Share music video' : 'Share song to messages',
            icon: const Icon(Icons.share_outlined),
            onPressed: () => showSocialShareDialog(
              context,
              title: isVideo
                  ? '${widget.track.title} — Music Video'
                  : widget.track.title,
              message:
                  '${isVideo ? 'Shared music video' : 'Shared song'}: ${widget.track.title} by ${widget.track.artist}',
              mediaReference: {
                'type': isVideo ? 'music_video' : 'song',
                'mediaType': isVideo ? 'music_video' : 'song',
                'mediaId': widget.track.id,
                'title': widget.track.title,
                'description':
                    '${widget.track.artist}${widget.track.album.trim().isEmpty ? '' : ' · ${widget.track.album}'}',
                'artist': widget.track.artist,
                'album': widget.track.album,
                if (isVideo) 'videoUrl': widget.track.musicVideoUrl,
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
          child: Center(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isVideo) ...[
                          if (_videoError != null)
                            Text(_videoError!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white70))
                          else if (_video?.value.isInitialized == true)
                            AspectRatio(
                                aspectRatio: _video!.value.aspectRatio,
                                child: VideoPlayer(_video!))
                          else
                            const CircularProgressIndicator(),
                          if (_video?.value.isInitialized == true)
                            IconButton(
                                onPressed: () {
                                  setState(() {
                                    _video!.value.isPlaying
                                        ? _video!.pause()
                                        : _video!.play();
                                  });
                                },
                                icon: Icon(
                                    (_video?.value.isPlaying ?? false)
                                        ? Icons.pause_circle
                                        : Icons.play_circle,
                                    size: 48)),
                        ] else ...[
                          Text(widget.track.artist,
                              style: const TextStyle(color: Colors.white60)),
                          const SizedBox(height: 32),
                          const _MusicVisualizerBars(),
                          if (showLyrics) ...[
                            const SizedBox(height: 28),
                            Text(
                                widget.track.lyrics.trim().isEmpty
                                    ? 'Lyrics are not available in your local metadata. Add a licensed lyrics source or an authorized local lyrics file.'
                                    : widget.track.lyrics,
                                textAlign: TextAlign.center,
                                style:
                                    const TextStyle(fontSize: 18, height: 1.7)),
                          ],
                        ],
                      ])))),
    );
  }
}

class _MusicVisualizerBars extends StatelessWidget {
  const _MusicVisualizerBars();
  @override
  Widget build(BuildContext context) => SizedBox(
      height: 150,
      child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var i = 0; i < 21; i++)
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Container(
                      width: 7,
                      height: 24 + ((i * 37) % 100).toDouble(),
                      decoration: BoxDecoration(
                          color: Color.lerp(const Color(0xFF5B8CFF),
                              const Color(0xFFC084FC), i / 20),
                          borderRadius: BorderRadius.circular(8))))
          ]));
}

/// Artist/band hub. The owned-library sections are always sourced from the
/// indexed NAS tracks; external chart/catalog sections never claim a missing
/// track is locally playable.
class MusicArtistProfileScreen extends StatelessWidget {
  const MusicArtistProfileScreen({super.key, required this.artistName});

  final String artistName;

  bool _same(String a, String b) =>
      a.trim().toLowerCase() == b.trim().toLowerCase();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        MusicLibraryStore.instance,
        MusicFavoritesBridge.changes,
      ]),
      builder: (context, _) {
        final all = MusicLibraryStore.instance.tracks;
        final primary = all.where((t) => _same(t.artist, artistName)).toList();
        final featured = all
            .where((t) => t.featuredArtists.any((a) => _same(a, artistName)))
            .toList();
        final related = <String>{};
        for (final track in [...primary, ...featured]) {
          if (!_same(track.artist, artistName)) related.add(track.artist);
          for (final guest in track.featuredArtists) {
            if (!_same(guest, artistName)) related.add(guest);
          }
        }
        final videos = <MusicTrack>{...primary, ...featured}
            .where((t) => !_isMusicDemoTrack(t))
            .toList(growable: false);
        final featuringCreditsById = <String, MusicTrack>{
          for (final track in featured) track.id: track,
          for (final track in primary.where((track) => track.featuredArtists.isNotEmpty)) track.id: track,
        };
        final featuringCredits = featuringCreditsById.values.toList(growable: false);
        bool isCatalogSample(MusicTrack track) =>
            track.id.startsWith('demo-catalog-track-') ||
            track.id.startsWith('demo-preview-album-track-');
        final catalogSampleTracks = primary.where(isCatalogSample).length;
        final indexedTracks = primary.where((track) => !isCatalogSample(track)).length;
        final catalogSampleAlbums = <String>{
          for (final track in primary)
            if (isCatalogSample(track)) track.album.trim(),
        }.where((album) => album.isNotEmpty).length;
        final indexedAlbums = <String>{
          for (final track in primary)
            if (!isCatalogSample(track) && track.album.trim().isNotEmpty) track.album.trim(),
        }.length;
        final playablePrimary = primary
            .where((track) => (track.audioUrl ?? '').trim().isNotEmpty)
            .toList(growable: false);
        return Scaffold(
          backgroundColor: const Color(0xFF090909),
          appBar: AppBar(
            backgroundColor: const Color(0xFF090909),
            title:
                Text(artistName, maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(
                tooltip: 'Share artist',
                icon: const Icon(Icons.share_outlined),
                onPressed: () => showSocialShareDialog(
                  context,
                  title: artistName,
                  message: 'Shared artist: $artistName',
                  mediaReference: {
                    'type': 'artist',
                    'mediaType': 'artist',
                    'mediaId': 'artist:${artistName.toLowerCase()}',
                    'title': artistName
                  },
                ),
              ),
            ],
          ),
          body: DefaultTabController(
                  length: 6,
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(artistName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 6),
                              Text(
                                  '$indexedTracks indexed tracks • $catalogSampleTracks catalog examples • $indexedAlbums indexed albums • $catalogSampleAlbums sample albums • ${videos.length} music videos',
                                  style:
                                      const TextStyle(color: Colors.white60)),
                              const SizedBox(height: 12),
                              Wrap(spacing: 8, runSpacing: 8, children: [
                                FilledButton.icon(
                                    onPressed: playablePrimary.isEmpty
                                        ? null
                                        : () {
                                            MusicLibraryStore.instance
                                                .setQueue(playablePrimary);
                                            unawaited(MusicPlaybackController
                                                .instance
                                                .play(playablePrimary.first));
                                          },
                                    icon: const Icon(Icons.play_arrow_rounded),
                                    label: const UniversalText(
                                        'Play available songs')),
                                OutlinedButton.icon(
                                    onPressed: () {
                                      final following =
                                          MusicFavoritesBridge.followedArtists()
                                              .contains(artistName);
                                      MusicFavoritesBridge.toggleArtist(
                                          artistName);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                              content: Text(following
                                                  ? 'Unfollowed $artistName.'
                                                  : 'Following $artistName.')));
                                    },
                                    icon: Icon(
                                        MusicFavoritesBridge.followedArtists()
                                                .contains(artistName)
                                            ? Icons.check_rounded
                                            : Icons.person_add_alt_1_rounded),
                                    label: Text(
                                        MusicFavoritesBridge.followedArtists()
                                                .contains(artistName)
                                            ? 'Following'
                                            : 'Follow artist')),
                                OutlinedButton.icon(
                                    onPressed: () =>
                                        _searchArtist(context, artistName),
                                    icon: const Icon(
                                        Icons.travel_explore_rounded),
                                    label:
                                        const UniversalText('Discover artist')),
                              ]),
                            ]),
                      ),
                      const TabBar(isScrollable: true, tabs: [
                        Tab(text: 'Songs'),
                        Tab(text: 'Discography'),
                        Tab(text: 'Popular'),
                        Tab(text: 'Music Videos'),
                        Tab(text: 'Featuring'),
                        Tab(text: 'Fans Also Like'),
                      ]),
                      Expanded(
                          child: TabBarView(children: [
                        _trackList(context, primary,
                            emptyMessage: 'No imported tracks or catalog examples found for this artist.'),
                        _SpotifyArtistDiscographySection(
                          artistName: artistName,
                          localTracks: primary,
                        ),
                        _SpotifyArtistPopularSection(
                          artistName: artistName,
                          localTracks: <MusicTrack>{...primary, ...featured}.toList(growable: false),
                        ),
                        _ArtistMusicVideosSection(tracks: videos),
                        _trackList(context, featuringCredits,
                            emptyMessage: 'No guest or featured-artist credits are indexed for this artist.',
                            creditLabel: 'Featured / collaborator'),
                        _FansAlsoLikeSection(
                          artistName: artistName,
                          seedArtists: related.toList(growable: false),
                        ),
                      ])),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _trackList(BuildContext context, List<MusicTrack> tracks,
      {required String emptyMessage,
      String? header,
      bool showListenCounts = false,
      String? creditLabel}) {
    if (tracks.isEmpty) return _empty(emptyMessage);
    return ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (header != null)
            ListTile(
                title: Text(header,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const UniversalText(
                    'Ranked from local listening history; not a worldwide chart.')),
          for (final track in tracks)
            ListTile(
              leading: _art(track),
              title: LocalizedMediaText(track.title),
              subtitle: Text([
                if (creditLabel != null) '$creditLabel ${track.artist}',
                track.album,
                if (track.featuredArtists.isNotEmpty)
                  'feat. ${track.featuredArtists.join(', ')}',
                if (track.id.startsWith('demo-catalog-track-') ||
                    track.id.startsWith('demo-preview-album-track-'))
                  'Catalog example • no audio file attached'
              ].where((x) => x.trim().isNotEmpty).join(' • ')),
              trailing: showListenCounts
                  ? Wrap(children: [
                      Text(
                          '${MusicLibraryStore.instance.listenCounts[track.id] ?? 0} plays'),
                      IconButton(
                          tooltip: 'Open artist details',
                          icon: const Icon(Icons.person_outline_rounded),
                          onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                  builder: (_) => MusicArtistProfileScreen(
                                      artistName: track.artist)))),
                    ])
                  : Wrap(children: [
                      IconButton(
                          tooltip: 'Open artist details',
                          icon: const Icon(Icons.person_outline_rounded),
                          onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                  builder: (_) => MusicArtistProfileScreen(
                                      artistName: track.artist)))),
                      IconButton(
                          tooltip: 'Add playable track to queue',
                          icon: const Icon(Icons.queue_music_rounded),
                          onPressed: () {
                            if ((track.audioUrl ?? '').trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Catalog example only — import this track to add playable audio.')));
                              return;
                            }
                            MusicLibraryStore.instance.addToQueue(track);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(
                                    'Added ${track.title} to the queue.')));
                          }),
                      IconButton(
                          tooltip: 'Share song',
                          icon: const Icon(Icons.share_outlined),
                          onPressed: () => showSocialShareDialog(context,
                                  title: track.title,
                                  message:
                                      'Shared song: ${track.title} by ${track.artist}',
                                  mediaReference: {
                                    'type': 'song',
                                    'mediaType': 'song',
                                    'mediaId': track.id,
                                    'title': track.title,
                                    'artist': track.artist,
                                    'album': track.album
                                  })),
                    ]),
              onTap: () {
                if ((track.audioUrl ?? '').trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Catalog example only — no audio file is attached. Import your own copy to play it.'),
                  ));
                  return;
                }
                MusicPlaybackController.instance.play(track);
              },
            ),
        ]);
  }

  Widget _art(MusicTrack track) {
    final albumTitle = track.album.trim().isNotEmpty ? track.album : track.title;
    return SizedBox(
      width: 48,
      height: 48,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: AlbumArtworkImage(
          title: albumTitle,
          artist: track.artist,
          imageUrl: track.artworkUrl,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          placeholder: const Icon(Icons.album_rounded),
          errorPlaceholder: const Icon(Icons.album_rounded),
        ),
      ),
    );
  }
  Widget _empty(String message) => Center(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60))));

  Future<void> _searchArtist(BuildContext context, String artist) async {
    final uri = Uri.https(
        'www.google.com', '/search', {'q': '$artist official music artist'});
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: UniversalText(
              'Could not open artist discovery in your browser.')));
    }
  }
}


Map<String, dynamic> _musicCatalogMap(dynamic value) => value is Map
    ? Map<String, dynamic>.from(value)
    : <String, dynamic>{};

List<Map<String, dynamic>> _musicCatalogRows(dynamic value) => value is List
    ? value.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList()
    : <Map<String, dynamic>>[];

String _musicLookupKey(String value) => value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

bool _isMusicDemoTrack(MusicTrack track) =>
    track.id.startsWith('demo-catalog-track-') || track.id.startsWith('demo-preview-album-track-');

List<MusicTrack> _realArtistTracks(Iterable<MusicTrack> tracks) => tracks.where((track) => !_isMusicDemoTrack(track)).toList(growable: false);

Future<Map<String, dynamic>?> _findSpotifyArtist(String artistName) async {
  if (!AppController.instance.isBackendAuthenticated) return null;
  final result = await AppController.instance.backendApi.searchMusicCatalog(artistName, type: 'artist', limit: 5);
  final spotify = _musicCatalogMap(result['spotify']);
  final candidates = _musicCatalogRows(spotify['artists']);
  for (final candidate in candidates) {
    if (_musicLookupKey(candidate['name']?.toString() ?? '') == _musicLookupKey(artistName)) return candidate;
  }
  return null;
}

List<Map<String, dynamic>> _localAlbumTrackRows(String artistName, String albumTitle) {
  final wantedAlbum = _musicLookupKey(albumTitle);
  final wantedArtist = _musicLookupKey(artistName);
  return <Map<String, dynamic>>[
    for (final track in MusicLibraryStore.instance.tracks)
      if (!_isMusicDemoTrack(track) &&
          _musicLookupKey(track.album) == wantedAlbum &&
          (_musicLookupKey(track.artist) == wantedArtist ||
              _musicLookupKey(track.artist).contains(wantedArtist) ||
              wantedArtist.contains(_musicLookupKey(track.artist))))
        <String, dynamic>{
          'id': track.id,
          'title': track.title,
          'artist': track.artist,
          'album': track.album,
          'audioUrl': track.audioUrl ?? '',
          'artworkUrl': track.artworkUrl ?? '',
          'durationMs': track.duration.inMilliseconds,
        },
  ];
}

class _SpotifyArtistDiscographySection extends StatefulWidget {
  const _SpotifyArtistDiscographySection({required this.artistName, required this.localTracks});
  final String artistName;
  final List<MusicTrack> localTracks;
  @override
  State<_SpotifyArtistDiscographySection> createState() => _SpotifyArtistDiscographySectionState();
}

class _SpotifyArtistDiscographySectionState extends State<_SpotifyArtistDiscographySection> {
  final List<Map<String, dynamic>> _externalAlbums = <Map<String, dynamic>>[];
  String? _spotifyId;
  String? _error;
  int _total = 0;
  int _offset = 0;
  bool _loading = true;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadFirstPage());
  }

  Future<void> _loadFirstPage() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final artist = await _findSpotifyArtist(widget.artistName);
      final id = artist?['id']?.toString() ?? '';
      if (id.isEmpty) {
        if (mounted) setState(() { _error = 'No exact Spotify artist match was found.'; _total = 0; });
        return;
      }
      final page = await AppController.instance.backendApi.getSpotifyArtistAlbums(id, limit: 10, offset: 0);
      final items = _musicCatalogRows(page['items']);
      if (!mounted) return;
      setState(() {
        _spotifyId = id;
        _externalAlbums
          ..clear()
          ..addAll(items);
        _offset = items.length;
        _total = int.tryParse(page['total']?.toString() ?? '') ?? items.length;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('BackendApiException: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    final id = _spotifyId;
    if (id == null || _loadingMore || _offset >= _total) return;
    setState(() => _loadingMore = true);
    try {
      final page = await AppController.instance.backendApi.getSpotifyArtistAlbums(id, limit: 10, offset: _offset);
      final items = _musicCatalogRows(page['items']);
      if (!mounted) return;
      setState(() {
        final seen = _externalAlbums.map((row) => row['id']?.toString() ?? '').toSet();
        _externalAlbums.addAll(items.where((row) => (row['id']?.toString() ?? '').isNotEmpty && !seen.contains(row['id']?.toString())));
        _offset += items.length;
        _total = int.tryParse(page['total']?.toString() ?? '') ?? _total;
        if (items.isEmpty) _total = _offset;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('BackendApiException: ', ''));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final album in _externalAlbums) {
      final title = album['title']?.toString() ?? '';
      final key = _musicLookupKey(title);
      if (key.isNotEmpty && seen.add(key)) rows.add(album);
    }
    for (final track in _realArtistTracks(widget.localTracks)) {
      final album = track.album.trim();
      final key = _musicLookupKey(album);
      if (album.isNotEmpty && seen.add(key)) {
        rows.add(<String, dynamic>{'title': album, 'artist': track.artist, 'imageUrl': track.artworkUrl ?? '', 'releaseDate': '', 'id': '', 'source': 'Local library'});
      }
    }
    rows.sort((a, b) => (DateTime.tryParse(b['releaseDate']?.toString() ?? '') ?? DateTime(1900)).compareTo(DateTime.tryParse(a['releaseDate']?.toString() ?? '') ?? DateTime(1900)));
    if (_loading && rows.isEmpty) return const Center(child: CircularProgressIndicator());
    if (rows.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error ?? 'Discography is unavailable. Sign in and configure Spotify in Backend/.env.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60))));
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        const ListTile(title: Text('Discography', style: TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('Spotify releases compared with your imported music library. Missing releases are dimmed; playback requires a local media file.')),
        if (_error != null) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Text(_error!, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12))),
        for (final album in rows) _albumRow(context, album),
        if (_offset < _total)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: OutlinedButton.icon(
              onPressed: _loadingMore ? null : _loadMore,
              icon: _loadingMore ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.expand_more_rounded),
              label: Text(_loadingMore ? 'Loading releases…' : 'Load more discography (${_externalAlbums.length} of $_total)'),
            ),
          ),
      ],
    );
  }

  void _playLocalTrackRow(Map<String, dynamic> row) {
    final id = row['id']?.toString() ?? '';
    for (final track in MusicLibraryStore.instance.tracks) {
      if (track.id == id && (track.audioUrl?.trim().isNotEmpty ?? false)) {
        unawaited(MusicPlaybackController.instance.play(track));
        return;
      }
    }
  }

  Widget _albumRow(BuildContext context, Map<String, dynamic> album) {
    final title = album['title']?.toString() ?? 'Album';
    final artist = album['artist']?.toString() ?? widget.artistName;
    final local = _localAlbumTrackRows(widget.artistName, title);
    final owned = local.isNotEmpty;
    final image = album['imageUrl']?.toString() ?? '';
    final spotifyId = album['id']?.toString() ?? '';
    return Opacity(
      opacity: owned ? 1 : .48,
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: AlbumArtworkImage(
            title: title,
            artist: artist,
            imageUrl: image,
            width: 52,
            height: 52,
            fit: BoxFit.cover,
            placeholder: const SizedBox(
              width: 52, height: 52,
              child: ColoredBox(color: Color(0xFF242424), child: Icon(Icons.album_rounded)),
            ),
          ),
        ),
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: CinematicTitleFonts.captionStyleForTitle(title, type: 'album', baseFontSize: 14, color: Colors.white)),
        subtitle: Text(<String>[artist, if ((album['releaseDate']?.toString() ?? '').length >= 4) album['releaseDate'].toString().substring(0, 4), owned ? 'In your library' : 'Not in library'].join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        trailing: Icon(owned ? Icons.library_add_check_rounded : Icons.lock_outline_rounded, color: owned ? Colors.lightGreenAccent : Colors.white38),
        onTap: spotifyId.isEmpty ? null : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SpotifyAlbumDetailsScreen(
          albumTitle: title,
          spotifyId: spotifyId,
          isOwned: owned,
          localArtistName: widget.artistName,
          localTracks: local,
          onPlayLocalTrack: _playLocalTrackRow,
        ))),
      ),
    );
  }
}

class _SpotifyArtistPopularSection extends StatefulWidget {
  const _SpotifyArtistPopularSection({required this.artistName, required this.localTracks});
  final String artistName;
  final List<MusicTrack> localTracks;
  @override
  State<_SpotifyArtistPopularSection> createState() => _SpotifyArtistPopularSectionState();
}

class _SpotifyArtistPopularSectionState extends State<_SpotifyArtistPopularSection> {
  late Future<Map<String, dynamic>> _future;
  @override
  void initState() { super.initState(); _future = _load(); }
  Future<Map<String, dynamic>> _load() async {
    try { return await AppController.instance.backendApi.getPopularArtistTracks(widget.artistName); }
    catch (error) { return <String, dynamic>{'items': <Map<String, dynamic>>[], 'message': error.toString().replaceFirst('BackendApiException: ', '')}; }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _future,
    builder: (context, snapshot) {
      final external = _musicCatalogRows(snapshot.data?['items']);
      final locals = _realArtistTracks(widget.localTracks);
      final usedLocal = <String>{};
      final rowEntries = <Map<String, dynamic>>[];
      for (final row in external) {
        final titleKey = _musicLookupKey(row['title']?.toString() ?? '');
        MusicTrack? local;
        for (final candidate in locals) {
          if (_musicLookupKey(candidate.title) == titleKey &&
              (candidate.audioUrl?.trim().isNotEmpty ?? false)) { local = candidate; break; }
        }
        if (local != null) usedLocal.add(local.id);
        rowEntries.add(<String, dynamic>{'external': row, 'local': local});
      }
      for (final track in locals) {
        if (usedLocal.contains(track.id)) continue;
        rowEntries.add(<String, dynamic>{'local': track});
      }
      if (snapshot.connectionState == ConnectionState.waiting && rowEntries.isEmpty) return const Center(child: CircularProgressIndicator());
      if (rowEntries.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(snapshot.data?['message']?.toString() ?? 'Popular tracks are unavailable until Spotify is configured.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60))));
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const ListTile(title: Text('Popular & your tracks', style: TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('Spotify catalog-ranked tracks plus all of your imported songs. Songs not in your library cannot be played here.')),
          for (final entry in rowEntries) _trackRow(context, entry),
        ],
      );
    },
  );

  Widget _trackRow(BuildContext context, Map<String, dynamic> entry) {
    final raw = entry['external'] is Map ? Map<String, dynamic>.from(entry['external'] as Map) : <String, dynamic>{};
    final local = entry['local'] is MusicTrack ? entry['local'] as MusicTrack : null;
    final title = local?.title ?? raw['title']?.toString() ?? 'Track';
    final artist = local?.artist ?? raw['artist']?.toString() ?? widget.artistName;
    final image = local?.artworkUrl ?? raw['imageUrl']?.toString() ?? '';
    final canPlay = local != null && (local.audioUrl?.trim().isNotEmpty ?? false);
    final score = raw['popularity'] is num ? 'Popularity ${raw['popularity']}' : 'Spotify catalog result';
    return Opacity(
      opacity: canPlay ? 1 : .43,
      child: ListTile(
        leading: SizedBox(width: 48, height: 48, child: image.trim().startsWith('http') ? Image.network(image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.music_note_rounded)) : const Icon(Icons.music_note_rounded)),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(canPlay ? '$artist · In your library' : '$artist · $score · Not in library', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        trailing: IconButton(
          tooltip: canPlay ? 'Play imported track' : 'Import this track to enable playback',
          icon: Icon(canPlay ? Icons.play_arrow_rounded : Icons.lock_outline_rounded),
          onPressed: canPlay ? () => unawaited(MusicPlaybackController.instance.play(local)) : null,
        ),
        onTap: canPlay ? () => unawaited(MusicPlaybackController.instance.play(local)) : null,
      ),
    );
  }
}

class _ArtistMusicVideosSection extends StatefulWidget {
  const _ArtistMusicVideosSection({required this.tracks});
  final List<MusicTrack> tracks;
  @override
  State<_ArtistMusicVideosSection> createState() => _ArtistMusicVideosSectionState();
}

class _ArtistMusicVideosSectionState extends State<_ArtistMusicVideosSection> {
  bool _loading = false;
  String? _message;
  List<Map<String, dynamic>> _rows = <Map<String, dynamic>>[];
  final Set<String> _searched = <String>{};

  @override
  void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) => _loadVideos()); }
  Future<void> _loadVideos() async {
    if (_loading) return;
    setState(() => _loading = true);
    final rows = <Map<String, dynamic>>[];
    try {
      final tracks = _realArtistTracks(widget.tracks).take(8).toList(growable: false);
      for (final track in tracks) {
        if (!AppController.instance.isBackendAuthenticated) break;
        if ((track.musicVideoUrl ?? '').trim().isNotEmpty) {
          rows.add(<String, dynamic>{'track': track, 'localVideoUrl': track.musicVideoUrl});
          continue;
        }
        if (_searched.contains(track.id)) continue;
        _searched.add(track.id);
        try {
          final result = await AppController.instance.backendApi.searchMusicVideos('${track.artist} ${track.title} official music video', limit: 1);
          final found = _musicCatalogRows(result['items']);
          if (found.isNotEmpty) {
            rows.add(<String, dynamic>{'track': track, 'video': found.first});
          } else if (_message == null && (result['configured'] == false)) {
            _message = result['message']?.toString();
          }
        } catch (_) {}
      }
      if (mounted) setState(() => _rows = rows);
    } catch (error) {
      if (mounted) setState(() => _message = error.toString().replaceFirst('BackendApiException: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openTrackVideo(BuildContext context, Map<String, dynamic> row) {
    final track = row['track'] as MusicTrack;
    final video = row['video'] is Map
        ? Map<String, dynamic>.from(row['video'] as Map)
        : null;
    if ((track.musicVideoUrl?.trim().isNotEmpty ?? false)) {
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => MusicTrackDisplayScreen(track: track, mode: MusicTrackDisplayMode.video),
      ));
    } else if (video != null && (video['videoId']?.toString() ?? '').isNotEmpty) {
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => MusicVideoSearchScreen(
          title: track.title,
          artist: track.artist,
          initialVideo: video,
        ),
      ));
    } else {
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => MusicVideoSearchScreen(title: track.title, artist: track.artist),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        const ListTile(title: Text('Music Videos', style: TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('Searches for embeddable YouTube matches for songs in your imported library.')),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if ((_message ?? '').isNotEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(_message!, style: const TextStyle(color: Colors.white54, fontSize: 12))),
        if (_rows.isEmpty && !_loading) Padding(padding: const EdgeInsets.all(20), child: Text(widget.tracks.isEmpty ? 'No imported tracks are indexed for this artist yet.' : 'No matching video was returned. You can search each song manually.', style: const TextStyle(color: Colors.white60))),
        for (final row in _rows)
          Builder(builder: (context) {
            final track = row['track'] as MusicTrack;
            final video = row['video'] is Map ? Map<String, dynamic>.from(row['video'] as Map) : <String, dynamic>{};
            final title = video['title']?.toString() ?? track.title;
            final thumb = video['thumbnailUrl']?.toString() ?? track.artworkUrl ?? '';
            return ListTile(
              leading: SizedBox(width: 64, height: 48, child: thumb.startsWith('http') ? Image.network(thumb, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.music_video_rounded)) : const Icon(Icons.music_video_rounded)),
              title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text('${track.title} · ${video['channelTitle']?.toString() ?? track.artist}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 11)),
              trailing: IconButton(
                tooltip: (track.musicVideoUrl?.trim().isNotEmpty ?? false) ? 'Play stored music video' : 'Find music video',
                icon: const Icon(Icons.play_circle_outline_rounded),
                onPressed: () => _openTrackVideo(context, row),
              ),
              onTap: () => _openTrackVideo(context, row),
            );
          }),
        if (!_loading && widget.tracks.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 20), child: OutlinedButton.icon(onPressed: () { _searched.clear(); unawaited(_loadVideos()); }, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry video discovery'))),
      ],
    );
  }
}

class _FansAlsoLikeSection extends StatefulWidget {
  const _FansAlsoLikeSection({required this.artistName, required this.seedArtists});
  final String artistName;
  final List<String> seedArtists;
  @override
  State<_FansAlsoLikeSection> createState() => _FansAlsoLikeSectionState();
}

class _FansAlsoLikeSectionState extends State<_FansAlsoLikeSection> {
  late Future<Map<String, dynamic>> _future;
  @override
  void initState() { super.initState(); _future = _load(); }

  Future<Map<String, dynamic>> _load() async {
    try { return await AppController.instance.backendApi.getRelatedMusicArtists(widget.artistName, limit: 12); }
    catch (error) { return <String, dynamic>{'items': <Map<String, dynamic>>[], 'message': error.toString().replaceFirst('BackendApiException: ', '')}; }
  }

  List<Map<String, dynamic>> _curatedFallback() {
    final name = _musicLookupKey(widget.artistName);
    const suggestions = <String, List<String>>{
      'morgan wallen': <String>['Ella Langley', 'Blake Shelton', 'Bailey Zimmerman', 'Post Malone', 'Tate McRae'],
      'j balvin': <String>['Maluma', 'Bad Bunny', 'Feid'],
      'selena gomez': <String>['Taylor Swift', 'Ariana Grande'],
    };
    final selected = suggestions.entries.where((entry) => _musicLookupKey(entry.key) == name).expand((entry) => entry.value);
    return selected.map((value) => <String, dynamic>{'name': value, 'similarityReason': 'Curated discovery suggestion'}).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _future,
    builder: (context, snapshot) {
      final byName = <String, Map<String, dynamic>>{};
      for (final row in [..._musicCatalogRows(snapshot.data?['items']), ..._curatedFallback()]) {
        final name = row['name']?.toString().trim() ?? '';
        if (name.isNotEmpty && _musicLookupKey(name) != _musicLookupKey(widget.artistName)) byName.putIfAbsent(_musicLookupKey(name), () => row);
      }
      for (final name in widget.seedArtists) {
        final clean = name.trim();
        if (clean.isNotEmpty && _musicLookupKey(clean) != _musicLookupKey(widget.artistName)) byName.putIfAbsent(_musicLookupKey(clean), () => <String, dynamic>{'name': clean, 'similarityReason': 'Found on a collaboration in your library'});
      }
      final rows = byName.values.toList()..sort((a, b) => (a['name']?.toString() ?? '').toLowerCase().compareTo((b['name']?.toString() ?? '').toLowerCase()));
      if (snapshot.connectionState == ConnectionState.waiting && rows.isEmpty) return const Center(child: CircularProgressIndicator());
      if (rows.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(snapshot.data?['message']?.toString() ?? 'No similar artists were found yet.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60))));
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const ListTile(title: Text('Fans Also Like', style: TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('Suggestions combine available genre metadata and artists credited on your imported tracks, including cross-genre collaborations.')),
          for (final artist in rows)
            ListTile(
              leading: SizedBox(width: 48, height: 48, child: (artist['imageUrl']?.toString() ?? '').startsWith('http') ? ClipOval(child: Image.network(artist['imageUrl'].toString(), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded))) : const CircleAvatar(child: Icon(Icons.person_rounded))),
              title: Text(artist['name']?.toString() ?? 'Artist'),
              subtitle: Text(artist['similarityReason']?.toString() ?? (artist['genres'] is List ? (artist['genres'] as List).take(3).join(' · ') : 'Explore artist'), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 11)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MusicArtistProfileScreen(artistName: artist['name']?.toString() ?? 'Artist'))),
            ),
        ],
      );
    },
  );
}

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
      final aScore = (store.listenCounts[a.id] ?? 0) +
          a.genres.length * 2 +
          a.subgenres.length;
      final bScore = (store.listenCounts[b.id] ?? 0) +
          b.genres.length * 2 +
          b.subgenres.length;
      return bScore.compareTo(aScore);
    });
    return Scaffold(
      appBar: AppBar(title: const UniversalText('Discover Music')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const UniversalText('Discover',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const UniversalText(
              'Explore music already available in your account server using listening history, artists, genres and soundtrack connections.',
              style: TextStyle(color: Colors.white60)),
          const SizedBox(height: 18),
          _discoverGroup(
              context, 'Because You Listen', tracks.take(8).toList()),
          const SizedBox(height: 18),
          _discoverGroup(context, 'Genre-Blending Tracks in Your Library',
              tracks.where((track) => track.hasGenreBlend).take(12).toList()),
          const SizedBox(height: 18),
          _discoverGroup(context, 'Artists & Genres To Explore',
              tracks.skip(8).take(8).toList()),
          const SizedBox(height: 18),
          _discoverGroup(
              context,
              'Soundtrack Connections',
              tracks
                  .where((track) => track.allGenreTags
                      .any((g) => g.toLowerCase().contains('soundtrack')))
                  .take(8)
                  .toList()),
          const SizedBox(height: 18),
          const _MusicGenreBlendExamplesSection(),
        ],
      ),
    );
  }

  Widget _discoverGroup(
      BuildContext context, String title, List<MusicTrack> tracks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        if (tracks.isEmpty)
          const Card(
              child: ListTile(title: UniversalText('Nothing to show yet.')))
        else
          for (final track in tracks)
            Card(
              child: ListTile(
                leading: _MusicDiscoverArtwork(track: track),
                title: LocalizedMediaText(track.title),
                subtitle: Text(
                  track.hasGenreBlend
                      ? '${track.artist} • ${track.album}\n${track.genreBlendLabel}\nTags: ${track.allGenreTags.join(' • ')}'
                      : '${track.artist} • ${track.album}',
                ),
                trailing: Wrap(
                  children: [
                    if (ShopCatalog.instance
                        .productsForAssociation('song', track.id,
                            name: track.title)
                        .isNotEmpty)
                      IconButton(
                        tooltip: 'Shop song products',
                        icon: const Icon(Icons.storefront_outlined),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            settings: const RouteSettings(name: '/app/shop'),
                            builder: (_) => ShopScreen(
                              contextAssociationType: 'song',
                              contextAssociationId: track.id,
                              contextAssociationName: track.title,
                            ),
                          ),
                        ),
                      ),
                    if (ShopCatalog.instance
                        .productsForAssociation('artist', track.artist,
                            name: track.artist)
                        .isNotEmpty)
                      IconButton(
                        tooltip: 'Shop artist products',
                        icon: const Icon(Icons.person_outline_rounded),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            settings: const RouteSettings(name: '/app/shop'),
                            builder: (_) => ShopScreen(
                              contextAssociationType: 'artist',
                              contextAssociationId: track.artist,
                              contextAssociationName: track.artist,
                            ),
                          ),
                        ),
                      ),
                    if (ShopCatalog.instance
                        .productsForAssociation('album', track.album,
                            name: track.album)
                        .isNotEmpty)
                      IconButton(
                        tooltip: 'Shop album products',
                        icon: const Icon(Icons.album_outlined),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            settings: const RouteSettings(name: '/app/shop'),
                            builder: (_) => ShopScreen(
                              contextAssociationType: 'album',
                              contextAssociationId: track.album,
                              contextAssociationName: track.album,
                            ),
                          ),
                        ),
                      ),
                    IconButton(
                      tooltip: 'Play',
                      icon: const Icon(Icons.play_arrow_rounded),
                      onPressed: () =>
                          MusicPlaybackController.instance.play(track),
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

/// Curated metadata-only examples demonstrate genre crossover labels.
/// They are not inserted into a user's playable library or used to imply access.
class _MusicGenreBlendExamplesSection extends StatelessWidget {
  const _MusicGenreBlendExamplesSection();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.merge_type_rounded),
        title: const UniversalText('Genre-Blending Examples'),
        subtitle: const UniversalText(
          'Reference examples • playback depends on your connected library',
        ),
        children: [
          for (final example in MusicGenreSystem.referenceExamples)
            ListTile(
              dense: true,
              leading: const Icon(Icons.music_note_rounded),
              title: Text(example.title),
              subtitle: Text(
                '${example.artist}\n${example.genreLabel}\n'
                'Genres and styles: ${example.allGenreTags.join(' • ')}\n'
                '${example.description}',
              ),
              isThreeLine: true,
            ),
        ],
      ),
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
    final likedIds = MusicFavoritesBridge.likedTracks().toSet();
    final current = store.currentTrack;
    tracks.sort((a, b) {
      int score(MusicTrack track) {
        var value = (store.listenCounts[track.id] ?? 0) * 4;
        if (likedIds.contains(track.id)) value += 6;
        if (current != null &&
            track.genres.any((genre) => current.genres
                .any((active) => active.toLowerCase() == genre.toLowerCase()))) {
          value += 3;
        }
        if (current != null &&
            (track.artist.toLowerCase() == current.artist.toLowerCase() ||
                track.featuredArtists.any((artist) =>
                    artist.toLowerCase() == current.artist.toLowerCase()))) {
          value += 2;
        }
        return value;
      }

      final byScore = score(b).compareTo(score(a));
      return byScore != 0
          ? byScore
          : a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    final selected = <MusicTrack>[];
    final remaining = List<MusicTrack>.from(tracks);
    String? lastArtist;
    while (remaining.isNotEmpty && selected.length < 18) {
      var index = remaining.indexWhere(
          (track) => track.artist.toLowerCase() != lastArtist?.toLowerCase());
      if (index < 0) index = 0;
      final track = remaining.removeAt(index);
      selected.add(track);
      lastArtist = track.artist;
    }
    return selected;
  }

  @override
  Widget build(BuildContext context) {
    final mix = _mix();
    return Scaffold(
      appBar: AppBar(title: const UniversalText('AI DJ')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const UniversalText('Your AI DJ',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const UniversalText(
              'A continuous queue assembled from your listening activity and music library. Playback stays on your account server.',
              style: TextStyle(color: Colors.white60)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: mix.isEmpty
                ? null
                : () async {
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
                leading: Text('${i + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                title: Text(mix[i].title),
                subtitle: Text(mix[i].artist),
                trailing: IconButton(
                  icon: const Icon(Icons.play_arrow_rounded),
                  onPressed: () =>
                      MusicPlaybackController.instance.play(mix[i]),
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
    final albumTitle = track.album.trim().isNotEmpty ? track.album : track.title;
    return ClipOval(
      child: AlbumArtworkImage(
        title: albumTitle,
        artist: track.artist,
        imageUrl: track.artworkUrl,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        placeholder: const SizedBox(
          width: 40,
          height: 40,
          child: CircleAvatar(child: Icon(Icons.album_rounded)),
        ),
      ),
    );
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
        for (final track in tracks.where((track) {
          final searchable = <String>[
            track.title,
            track.artist,
            track.album,
            ...track.genreSearchTerms,
          ].join(' ').toLowerCase();
          return searchable.contains(q);
        }))
          ListTile(
            title: LocalizedMediaText(track.title),
            subtitle: UniversalText(
              '${track.artist} • ${track.album}'
              '${track.allGenreTags.isEmpty ? '' : ' • ${track.genreDisplayLabel}'}',
            ),
            onTap: () {
              MusicPlaybackController.instance.play(track);
              close(context, track);
            },
          ),
      ],
    );
  }
}

Future<void> showMusicCustomization(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      routeSettings: const RouteSettings(name: '/app/customize'),
      builder: (_) => _MusicCustomization(
        store: MusicLibraryStore.instance,
      ),
    );

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
            const UniversalText(
              'Build a Spotify-inspired Music page without moving your audio files from the account server.',
              style: TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 18),
            _dropdown('Card style', draft.cardStyle,
                ['Comfortable', 'Compact', 'Large'], (v) {
              setState(() => draft.cardStyle = v);
            }),
            const SizedBox(height: 10),
            _dropdown(
                'Player style', draft.playerStyle, ['Bottom player', 'Compact'],
                (v) {
              setState(() => draft.playerStyle = v);
            }),
            const SizedBox(height: 18),
            _toggle('Search bar', 'Show music search.', draft.showSearch,
                (v) => setState(() => draft.showSearch = v)),
            _toggle('Player', 'Show the persistent music player and queue.',
                draft.showPlayer, (v) => setState(() => draft.showPlayer = v)),
            _toggle(
                'Weekly Discovery',
                'Show your weekly discovery mix.',
                draft.showWeeklyDiscovery,
                (v) => setState(() => draft.showWeeklyDiscovery = v)),
            _toggle('AI DJ', 'Show the AI DJ launcher.', draft.showAIDJ,
                (v) => setState(() => draft.showAIDJ = v)),
            _toggle(
                'System playlists',
                'Show Made For You / Discover Weekly / Daily Mix.',
                draft.showSystemPlaylists,
                (v) => setState(() => draft.showSystemPlaylists = v)),
            _toggle('Liked Songs', 'Show liked tracks.', draft.showLikedSongs,
                (v) => setState(() => draft.showLikedSongs = v)),
            _toggle(
                'Recently Played',
                'Show recent listening activity.',
                draft.showRecentlyPlayed,
                (v) => setState(() => draft.showRecentlyPlayed = v)),
            _toggle(
                'Mood & Genre Mixes',
                'Show quick mood/genre mixes.',
                draft.showMoodMixes,
                (v) => setState(() => draft.showMoodMixes = v)),
            _toggle('Artists', 'Show singers and bands.', draft.showArtists,
                (v) => setState(() => draft.showArtists = v)),
            _toggle('Albums', 'Show ripped albums.', draft.showAlbums,
                (v) => setState(() => draft.showAlbums = v)),
            _toggle('Playlists', 'Show custom playlists.', draft.showPlaylists,
                (v) => setState(() => draft.showPlaylists = v)),
            _toggle(
                'Soundtrack Universe',
                'Connect music to films and shows.',
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
              child: UniversalText(
                  'No soundtrack metadata has been imported yet.'),
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
