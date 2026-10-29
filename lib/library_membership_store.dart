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

  String get _serverBootstrapKey => '${_storageKey}_server_bootstrapped_v1';
  String get _pendingOverridesKey => '${_storageKey}_pending_overrides_v1';

  Future<bool> isServerBootstrapComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_serverBootstrapKey) ?? false;
  }

  Future<void> setServerBootstrapComplete(bool complete) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setBool(_serverBootstrapKey, complete);
    if (!saved) {
      throw StateError('The library membership sync state could not be saved.');
    }
  }

  /// Pending local operations are kept until the server confirms them. The
  /// map stores media ID -> desired hidden state, so both remove and re-add
  /// operations survive a connection outage and can be replayed safely.
  Future<Map<String, bool>> loadPendingOverrides() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingOverridesKey);
    if (raw == null || raw.trim().isEmpty) return <String, bool>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, bool>{};
      return <String, bool>{
        for (final entry in decoded.entries)
          if (entry.key.toString().trim().isNotEmpty && entry.value is bool)
            entry.key.toString().trim(): entry.value as bool,
      };
    } catch (_) {
      // Preserve library usability if an old/corrupt pending cache is found.
      return <String, bool>{};
    }
  }

  Future<void> savePendingOverride(String mediaId, bool hidden) async {
    final id = mediaId.trim();
    if (id.isEmpty) return;
    final overrides = await loadPendingOverrides();
    overrides[id] = hidden;
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(_pendingOverridesKey, jsonEncode(overrides));
    if (!saved) throw StateError('The pending library membership operation could not be saved.');
  }

  Future<void> clearPendingOverride(String mediaId, bool expectedHidden) async {
    final id = mediaId.trim();
    final overrides = await loadPendingOverrides();
    if (overrides[id] != expectedHidden) return;
    overrides.remove(id);
    final prefs = await SharedPreferences.getInstance();
    if (overrides.isEmpty) {
      await prefs.remove(_pendingOverridesKey);
    } else {
      await prefs.setString(_pendingOverridesKey, jsonEncode(overrides));
    }
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
