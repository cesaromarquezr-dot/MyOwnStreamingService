import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists profile-specific library removals independently of the media files.
///
/// A removal is a membership override, not a delete/rip operation. The media
/// source remains on the home server and can be added back by clearing its
/// hidden marker.
class LibraryMembershipStore {
  const LibraryMembershipStore({required this.scopeId});

  final String scopeId;

  String get _storageKey {
    final encodedScope = base64Url.encode(utf8.encode(scopeId.trim()));
    return 'moss_hidden_library_media_v1_$encodedScope';
  }

  Future<Set<String>> loadHiddenMediaIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_storageKey) ?? const <String>[])
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Future<void> saveHiddenMediaIds(Iterable<String> ids) async {
    final normalized = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setStringList(_storageKey, normalized);
    if (!saved) {
      throw StateError('The library membership change could not be saved.');
    }
  }
}
