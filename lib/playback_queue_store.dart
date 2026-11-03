import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum PlaybackQueueKind { media, music }

abstract final class PlaybackQueueNavigation {
  static bool Function(String mediaId)? playMedia;
}

class PlaybackQueueEntry {
  const PlaybackQueueEntry({required this.kind, required this.id});

  final PlaybackQueueKind kind;
  final String id;

  String get key => '${kind.name}:$id';

  Map<String, String> toJson() => <String, String>{
        'kind': kind.name,
        'id': id,
      };

  @override
  bool operator ==(Object other) =>
      other is PlaybackQueueEntry && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);

  static PlaybackQueueEntry? tryParse(dynamic value) {
    if (value is! Map) return null;
    final id = value['id']?.toString().trim() ?? '';
    final kind = switch (value['kind']?.toString()) {
      'media' => PlaybackQueueKind.media,
      'music' => PlaybackQueueKind.music,
      _ => null,
    };
    if (id.isEmpty || kind == null) return null;
    return PlaybackQueueEntry(kind: kind, id: id);
  }
}

/// Stores a profile's mixed queue as typed IDs, never URLs or file paths.
class PlaybackQueueStore {
  const PlaybackQueueStore();

  static const String _keyPrefix = 'mos_playback_queue_v1_';

  static String _key(String profileId) {
    final id = profileId.trim().isEmpty ? 'default' : profileId.trim();
    return '$_keyPrefix${Uri.encodeComponent(id)}';
  }

  Future<List<PlaybackQueueEntry>> load({required String profileId}) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(profileId));
    if (raw == null || raw.isEmpty) return <PlaybackQueueEntry>[];
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const FormatException('The saved playback queue is invalid.');
    }
    final entries = <PlaybackQueueEntry>[];
    final seen = <String>{};
    for (final value in decoded) {
      final entry = PlaybackQueueEntry.tryParse(value);
      if (entry == null) {
        throw const FormatException('The saved playback queue is invalid.');
      }
      if (seen.add(entry.key)) entries.add(entry);
    }
    return entries;
  }

  Future<void> add({
    required String profileId,
    required PlaybackQueueEntry entry,
  }) async {
    if (entry.id.trim().isEmpty) return;
    final queue = await load(profileId: profileId);
    if (queue.any((item) => item.key == entry.key)) return;
    queue.add(entry);
    await replace(profileId: profileId, entries: queue);
  }

  Future<void> remove({
    required String profileId,
    required PlaybackQueueEntry entry,
  }) async {
    final queue = await load(profileId: profileId)
      ..removeWhere((item) => item.key == entry.key);
    await replace(profileId: profileId, entries: queue);
  }

  Future<void> replace({
    required String profileId,
    required List<PlaybackQueueEntry> entries,
  }) async {
    final unique = <String, PlaybackQueueEntry>{};
    for (final entry in entries) {
      final id = entry.id.trim();
      if (id.isNotEmpty) {
        unique.putIfAbsent(
          '${entry.kind.name}:$id',
          () => PlaybackQueueEntry(kind: entry.kind, id: id),
        );
      }
    }
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      _key(profileId),
      jsonEncode(unique.values.map((entry) => entry.toJson()).toList()),
    );
    if (!saved) throw StateError('The playback queue could not be saved.');
  }

  Future<void> clear({required String profileId}) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_key(profileId));
  }
}
