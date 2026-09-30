import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Profile-scoped liked-music state shared by music and favorites screens.
class MusicFavoritesBridge {
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);
  static final Set<String> _likedTracks = <String>{};
  static final Set<String> _likedAlbums = <String>{};
  static final Set<String> _likedPlaylists = <String>{};
  static SharedPreferences? _preferences;
  static String _profileKey = 'default';

  static Future<void> initializeForProfile(String? profileId) async {
    _preferences ??= await SharedPreferences.getInstance();
    _profileKey = profileId?.trim().isNotEmpty == true ? profileId!.trim() : 'default';
    _likedTracks
      ..clear()
      ..addAll(_preferences!.getStringList('music_liked_tracks_$_profileKey') ?? const []);
    _likedAlbums
      ..clear()
      ..addAll(_preferences!.getStringList('music_liked_albums_$_profileKey') ?? const []);
    _likedPlaylists
      ..clear()
      ..addAll(_preferences!.getStringList('music_liked_playlists_$_profileKey') ?? const []);
    changes.value++;
  }

  static List<String> likedTracks() => _likedTracks.toList()..sort();
  static List<String> likedAlbums() => _likedAlbums.toList()..sort();
  static List<String> likedPlaylists() => _likedPlaylists.toList()..sort();
  static void toggleTrack(String id) {
    _likedTracks.contains(id) ? _likedTracks.remove(id) : _likedTracks.add(id);
    unawaited(_persist('music_liked_tracks_$_profileKey', _likedTracks));
  }

  static void toggleAlbum(String title) {
    _likedAlbums.contains(title) ? _likedAlbums.remove(title) : _likedAlbums.add(title);
    unawaited(_persist('music_liked_albums_$_profileKey', _likedAlbums));
  }

  static void togglePlaylist(String title) {
    _likedPlaylists.contains(title) ? _likedPlaylists.remove(title) : _likedPlaylists.add(title);
    unawaited(_persist('music_liked_playlists_$_profileKey', _likedPlaylists));
  }

  static Future<void> _persist(String key, Set<String> values) async {
    final preferences = _preferences ??= await SharedPreferences.getInstance();
    await preferences.setStringList(key, values.toList()..sort());
    changes.value++;
  }
}
