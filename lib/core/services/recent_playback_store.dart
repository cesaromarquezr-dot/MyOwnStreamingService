import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../app_core.dart';
import '../../backend_api.dart';
import '../../backend_api_compatibility.dart';

/// Profile-scoped, metadata-only recent playback journal.
/// It never stores stream URLs, credentials, or local media paths.
class RecentPlaybackEntry {
  const RecentPlaybackEntry({
    required this.id,
    required this.title,
    required this.kind,
    required this.playedAt,
    this.subtitle,
    this.artworkUrl,
  });

  final String id;
  final String title;
  final String kind;
  final DateTime playedAt;
  final String? subtitle;
  final String? artworkUrl;

  factory RecentPlaybackEntry.fromJson(Map<String, dynamic> json) =>
      RecentPlaybackEntry(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? 'Untitled media',
        kind: json['kind']?.toString() ?? 'video',
        playedAt: DateTime.tryParse(json['playedAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        subtitle: json['subtitle']?.toString(),
        artworkUrl: json['artworkUrl']?.toString(),
      );

  Map<String, dynamic> toJson({bool includeArtworkUrl = true}) => <String, dynamic>{
        'id': id,
        'title': title,
        'kind': kind,
        'playedAt': playedAt.toIso8601String(),
        if (subtitle != null) 'subtitle': subtitle,
        if (includeArtworkUrl && artworkUrl != null) 'artworkUrl': artworkUrl,
      };
}

class RecentPlaybackStore {
  RecentPlaybackStore._();

  static String _key(String profileId) =>
      'moss_recent_playback_${profileId.trim()}';

  static Future<void> recordMedia({
    required MediaItem media,
    required String? profileId,
    BackendApi? api,
  }) => _record(
        profileId: profileId,
        api: api,
        id: media.id,
        title: media.title,
        kind: 'video',
        subtitle: media.type,
        artworkUrl: media.imageUrl,
      );

  static Future<void> recordTrack({
    required String id,
    required String title,
    required String artist,
    required String album,
    required String? artworkUrl,
    required String? profileId,
    BackendApi? api,
  }) => _record(
        profileId: profileId,
        api: api,
        id: id,
        title: title,
        kind: 'audio',
        subtitle: [artist, album].where((value) => value.trim().isNotEmpty).join(' · '),
        artworkUrl: artworkUrl,
      );

  static Future<void> _record({
    required String? profileId,
    BackendApi? api,
    required String id,
    required String title,
    required String kind,
    String? subtitle,
    String? artworkUrl,
  }) async {
    final profile = profileId?.trim() ?? '';
    if (profile.isEmpty || id.trim().isEmpty || title.trim().isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(profile));
      final entries = <RecentPlaybackEntry>[];
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded.whereType<Map>()) {
            entries.add(RecentPlaybackEntry.fromJson(
              Map<String, dynamic>.from(item),
            ));
          }
        }
      }
      entries.removeWhere((entry) => entry.id == id && entry.kind == kind);
      entries.insert(
        0,
        RecentPlaybackEntry(
          id: id,
          title: title.trim(),
          kind: kind,
          playedAt: DateTime.now().toUtc(),
          subtitle: subtitle,
          artworkUrl: artworkUrl,
        ),
      );
      await prefs.setString(
        _key(profile),
        jsonEncode(entries.take(50).map((entry) => entry.toJson()).toList()),
      );
      if (api != null && api.isAuthenticated) {
        unawaited(syncWithBackend(api: api, profileId: profile));
      }
    } catch (_) {
      // Recents are best-effort and must never interrupt playback.
    }
  }


  /// Synchronizes only recent-playback metadata for the active profile.
  /// Artwork URLs are catalog metadata; stream URLs, credentials and paths
  /// are never stored in this record.
  static Future<void> syncWithBackend({
    required BackendApi api,
    required String profileId,
  }) async {
    final profile = profileId.trim();
    if (profile.isEmpty || !api.isAuthenticated) return;
    const recordType = 'recent_playback_history';
    const recordKey = 'profile-recent-v1';
    try {
      final local = await load(profile);
      final merged = <String, RecentPlaybackEntry>{
        for (final entry in local) '${entry.kind}|${entry.id}': entry,
      };
      final records = await api.getAppRecords(
        profileId: profile,
        recordType: recordType,
      );
      for (final record in records) {
        if (record['recordKey'] != recordKey || record['data'] is! Map) continue;
        final data = Map<String, dynamic>.from(record['data'] as Map);
        final rows = data['entries'];
        if (rows is! List) continue;
        for (final row in rows.whereType<Map>()) {
          final entry = RecentPlaybackEntry.fromJson(Map<String, dynamic>.from(row));
          if (entry.id.isEmpty) continue;
          final key = '${entry.kind}|${entry.id}';
          final existing = merged[key];
          if (existing == null || entry.playedAt.isAfter(existing.playedAt)) {
            merged[key] = entry.artworkUrl == null && existing?.artworkUrl != null
                ? RecentPlaybackEntry(
                    id: entry.id,
                    title: entry.title,
                    kind: entry.kind,
                    playedAt: entry.playedAt,
                    subtitle: entry.subtitle,
                    artworkUrl: existing!.artworkUrl,
                  )
                : entry;
          }
        }
        break;
      }
      final ordered = merged.values.toList()
        ..sort((a, b) => b.playedAt.compareTo(a.playedAt));
      final retained = ordered.take(50).toList(growable: false);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key(profile),
        jsonEncode(retained.map((entry) => entry.toJson()).toList()),
      );
      await api.saveAppRecord(
        profileId: profile,
        recordType: recordType,
        recordKey: recordKey,
        data: <String, dynamic>{
          'entries': retained.map((entry) => entry.toJson(includeArtworkUrl: false)).toList(),
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
          'schemaVersion': 1,
        },
      );
    } catch (_) {
      // Keep local history intact when the optional account sync is offline.
    }
  }

  static Future<List<RecentPlaybackEntry>> load(String? profileId) async {
    final profile = profileId?.trim() ?? '';
    if (profile.isEmpty) return const <RecentPlaybackEntry>[];
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(profile));
      if (raw == null || raw.isEmpty) return const <RecentPlaybackEntry>[];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <RecentPlaybackEntry>[];
      final entries = decoded
          .whereType<Map>()
          .map((item) => RecentPlaybackEntry.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .where((entry) => entry.id.isNotEmpty)
          .toList(growable: false);
      return entries;
    } catch (_) {
      return const <RecentPlaybackEntry>[];
    }
  }
}
