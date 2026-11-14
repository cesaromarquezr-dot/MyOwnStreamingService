import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Reads the existing profile-scoped music history without introducing a
/// second playlist or listen-count database.
class MediaMusicHistoryStore {
  static String _profileKey(String? profileId) =>
      profileId?.trim().isNotEmpty == true ? profileId!.trim() : 'default';

  static Future<Map<String, List<String>>> _playlists(String? profileId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('music_playlists_${_profileKey(profileId)}');
    if (raw == null || raw.isEmpty) return <String, List<String>>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, List<String>>{};
      return <String, List<String>>{
        for (final entry in decoded.entries)
          if (entry.value is List)
            entry.key.toString(): (entry.value as List)
                .map((value) => value.toString())
                .toList(growable: false),
      };
    } catch (_) {
      return <String, List<String>>{};
    }
  }

  static Future<List<String>> playlistsContainingTracks({
    required String? profileId,
    required Iterable<String> trackIds,
  }) async {
    final ids = trackIds.map((value) => value.trim()).where((v) => v.isNotEmpty).toSet();
    if (ids.isEmpty) return const <String>[];
    final playlists = await _playlists(profileId);
    return playlists.entries
        .where((entry) => entry.value.any(ids.contains))
        .map((entry) => entry.key)
        .toList(growable: false);
  }

  static Future<bool> albumHasListeningActivity({
    required String? profileId,
    required Iterable<String> trackIds,
  }) async {
    final ids = trackIds.map((value) => value.trim()).where((v) => v.isNotEmpty).toSet();
    if (ids.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('music_listen_counts_${_profileKey(profileId)}');
    if (raw == null || raw.isEmpty) return false;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return false;
      return ids.any((id) {
        final value = decoded[id];
        return (value is num && value > 0) || (int.tryParse(value?.toString() ?? '') ?? 0) > 0;
      });
    } catch (_) {
      return false;
    }
  }
}
