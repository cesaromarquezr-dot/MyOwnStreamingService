// A small, durable queue for idempotent, non-sensitive updates. Do not queue
// passwords, access tokens, chat bodies, payment details, or raw media bytes.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class PendingSyncAction {
  final String id;
  final String type;
  final String resourceId;
  final String profileId;
  final Map<String, dynamic> payload;
  final DateTime queuedAt;

  const PendingSyncAction({
    required this.id,
    required this.type,
    required this.resourceId,
    required this.profileId,
    required this.payload,
    required this.queuedAt,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'type': type,
        'resourceId': resourceId,
        'profileId': profileId,
        'payload': payload,
        'queuedAt': queuedAt.toUtc().toIso8601String(),
      };

  factory PendingSyncAction.fromJson(Map<String, dynamic> json) => PendingSyncAction(
        id: json['id']?.toString() ?? '',
        type: json['type']?.toString() ?? '',
        resourceId: json['resourceId']?.toString() ?? '',
        profileId: json['profileId']?.toString() ?? '',
        payload: json['payload'] is Map
            ? Map<String, dynamic>.from(json['payload'] as Map)
            : const <String, dynamic>{},
        queuedAt: DateTime.tryParse(json['queuedAt']?.toString() ?? '')?.toUtc() ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
}

class OfflineSyncQueue {
  OfflineSyncQueue({required this.scopeId});

  final String scopeId;
  static const String _keyPrefix = 'mos_offline_sync_queue_v1_';
  static const Set<String> _allowedTypes = <String>{'playback_progress'};
  static final Map<String, DateTime> _lastWriteAt = <String, DateTime>{};
  static final Map<String, double> _lastWriteProgress = <String, double>{};

  String get _key => '$_keyPrefix${Uri.encodeComponent(scopeId.trim().isEmpty ? 'local' : scopeId.trim())}';

  Future<List<PendingSyncAction>> list() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return <PendingSyncAction>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <PendingSyncAction>[];
      return decoded.whereType<Map>().map((item) => PendingSyncAction.fromJson(Map<String, dynamic>.from(item))).where((item) => item.id.isNotEmpty && _allowedTypes.contains(item.type)).toList();
    } catch (_) {
      return <PendingSyncAction>[];
    }
  }

  Future<void> enqueuePlaybackProgress({
    required String profileId,
    required String mediaId,
    required double progress,
    DateTime? now,
  }) async {
    final cleanProfile = profileId.trim();
    final cleanMedia = mediaId.trim();
    if (cleanProfile.isEmpty || cleanMedia.isEmpty) return;
    final normalizedProgress = progress.clamp(0.0, 1.0).toDouble();
    final timestamp = (now ?? DateTime.now()).toUtc();
    final throttlingKey = '$scopeId|$cleanProfile|$cleanMedia';
    final lastAt = _lastWriteAt[throttlingKey];
    final lastProgress = _lastWriteProgress[throttlingKey];
    if (lastAt != null && timestamp.difference(lastAt) < const Duration(seconds: 10) && lastProgress != null && (normalizedProgress - lastProgress).abs() < 0.02) return;

    final queue = await list();
    final id = 'playback_progress:$cleanProfile:$cleanMedia';
    queue.removeWhere((item) => item.id == id);
    queue.add(PendingSyncAction(
      id: id,
      type: 'playback_progress',
      resourceId: cleanMedia,
      profileId: cleanProfile,
      payload: <String, dynamic>{'progress': normalizedProgress},
      queuedAt: timestamp,
    ));
    await _write(queue);
    _lastWriteAt[throttlingKey] = timestamp;
    _lastWriteProgress[throttlingKey] = normalizedProgress;
  }

  Future<int> flush(Future<bool> Function(PendingSyncAction action) send) async {
    final queue = await list();
    final remaining = <PendingSyncAction>[];
    var sent = 0;
    for (final action in queue) {
      var successful = false;
      try {
        successful = await send(action);
      } catch (_) {
        successful = false;
      }
      if (successful) {
        sent++;
      } else {
        remaining.add(action);
      }
    }
    await _write(remaining);
    return sent;
  }

  Future<void> clear() => _write(<PendingSyncAction>[]);

  Future<void> _write(List<PendingSyncAction> queue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(queue.map((item) => item.toJson()).toList()));
  }
}
