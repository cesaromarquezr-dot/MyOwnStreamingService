import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../backend_api.dart';
import '../../backend_api_compatibility.dart';

class PlaybackProgressSyncSnapshot {
  const PlaybackProgressSyncSnapshot({
    required this.progress,
    required this.positionSeconds,
    required this.durationSeconds,
  });

  final Map<String, double> progress;
  final Map<String, int> positionSeconds;
  final Map<String, int> durationSeconds;
}

/// Profile-scoped, metadata-only playback progress synchronization.
/// The local snapshot is always written first; authenticated cloud writes are
/// debounced and failures leave local progress untouched for a later retry.
class PlaybackProgressSyncService {
  PlaybackProgressSyncService._();

  static const String _recordType = 'media_playback_progress';
  static const String _recordKey = 'profile-progress-v1';
  static const String _prefsPrefix = 'moss_playback_progress_sync_v1_';
  static final Map<String, Timer> _timers = <String, Timer>{};
  static final Map<String, Future<void>> _writeTails = <String, Future<void>>{};
  static final Map<String, ({DateTime at, double progress})>
      _lastLocalWrite = <String, ({DateTime at, double progress})>{};

  static String _key(String profileId) => '$_prefsPrefix${profileId.trim()}';

  static Future<Map<String, Map<String, dynamic>>> _readLocal(
      String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(profileId));
    if (raw == null || raw.isEmpty) return <String, Map<String, dynamic>>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, Map<String, dynamic>>{};
      return <String, Map<String, dynamic>>{
        for (final entry in decoded.entries)
          if (entry.value is Map)
            entry.key.toString(): Map<String, dynamic>.from(entry.value as Map),
      };
    } catch (_) {
      return <String, Map<String, dynamic>>{};
    }
  }

  static Future<void> _writeLocal(
    String profileId,
    Map<String, Map<String, dynamic>> values,
  ) async {
    if (values.length > 300) {
      final ordered = values.entries.toList()
        ..sort((a, b) {
          final aTime = DateTime.tryParse(a.value['updatedAt']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
          final bTime = DateTime.tryParse(b.value['updatedAt']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
          return bTime.compareTo(aTime);
        });
      values
        ..clear()
        ..addEntries(ordered.take(300));
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(profileId), jsonEncode(values));
  }

  static Future<void> recordLocalProgress({
    required BackendApi api,
    required String profileId,
    required String mediaId,
    required double progress,
    int? positionSeconds,
    int? durationSeconds,
  }) async {
    final profile = profileId.trim();
    final media = mediaId.trim();
    if (profile.isEmpty || media.isEmpty) return;
    final throttleKey = '$profile|$media';
    final normalized = progress.clamp(0.0, 1.0).toDouble();
    final now = DateTime.now().toUtc();
    final last = _lastLocalWrite[throttleKey];
    if (last != null &&
        now.difference(last.at) < const Duration(seconds: 8) &&
        (normalized - last.progress).abs() < 0.015) {
      return;
    }
    _lastLocalWrite[throttleKey] = (
      at: now,
      progress: normalized,
    );
    final previous = _writeTails[profile] ?? Future<void>.value();
    final next = previous.then((_) async {
      final values = await _readLocal(profile);
      values[media] = <String, dynamic>{
        'progress': normalized,
        'updatedAt': now.toIso8601String(),
        if (positionSeconds != null && positionSeconds >= 0)
          'positionSeconds': positionSeconds,
        if (durationSeconds != null && durationSeconds > 0)
          'durationSeconds': durationSeconds,
      };
      await _writeLocal(profile, values);
    });
    _writeTails[profile] = next.catchError((Object _) {});
    await next;
    _timers[profile]?.cancel();
    if (api.isAuthenticated) {
      _timers[profile] = Timer(const Duration(seconds: 8), () {
        unawaited(_pushLocal(api: api, profileId: profile));
      });
    }
  }

  static Future<void> _pushLocal({
    required BackendApi api,
    required String profileId,
  }) async {
    if (!api.isAuthenticated) return;
    try {
      final values = await _readLocal(profileId);
      // Read-before-write prevents a new device's first local progress event
      // from replacing older titles already stored by another device.
      final records = await api.getAppRecords(
        profileId: profileId,
        recordType: _recordType,
      );
      for (final record in records) {
        if (record['recordKey'] != _recordKey || record['data'] is! Map) continue;
        final data = Map<String, dynamic>.from(record['data'] as Map);
        final entries = data['entries'];
        if (entries is! Map) continue;
        for (final entry in entries.entries) {
          if (entry.value is! Map) continue;
          final remoteEntry = Map<String, dynamic>.from(entry.value as Map);
          final localEntry = values[entry.key.toString()];
          if (localEntry == null) {
            values[entry.key.toString()] = remoteEntry;
            continue;
          }
          final localDate = DateTime.tryParse(localEntry['updatedAt']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
          final remoteDate = DateTime.tryParse(remoteEntry['updatedAt']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
          if (remoteDate.isAfter(localDate)) {
            values[entry.key.toString()] = remoteEntry;
          }
        }
        break;
      }
      await _writeLocal(profileId, values);
      await api.saveAppRecord(
        profileId: profileId,
        recordType: _recordType,
        recordKey: _recordKey,
        data: <String, dynamic>{
          'entries': values,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
          'schemaVersion': 1,
        },
      );
    } catch (_) {
      // Progress remains in the local snapshot; the next sync can retry.
    }
  }

  /// Merges this device's latest progress with the profile's cloud record.
  /// Per-title timestamps prevent an older device from overwriting a newer seek.
  static Future<PlaybackProgressSyncSnapshot> synchronizeProfile({
    required BackendApi api,
    required String profileId,
    Map<String, double> currentProgress = const <String, double>{},
  }) async {
    final profile = profileId.trim();
    if (profile.isEmpty) {
      return const PlaybackProgressSyncSnapshot(
        progress: <String, double>{},
        positionSeconds: <String, int>{},
        durationSeconds: <String, int>{},
      );
    }
    final local = await _readLocal(profile);
    final remote = <String, Map<String, dynamic>>{};

    if (api.isAuthenticated) {
      try {
        final records = await api.getAppRecords(
          profileId: profile,
          recordType: _recordType,
        );
        for (final record in records) {
          if (record['recordKey'] != _recordKey || record['data'] is! Map) continue;
          final data = Map<String, dynamic>.from(record['data'] as Map);
          final entries = data['entries'];
          if (entries is! Map) continue;
          for (final entry in entries.entries) {
            if (entry.value is Map) {
              remote[entry.key.toString()] =
                  Map<String, dynamic>.from(entry.value as Map);
            }
          }
          break;
        }
      } catch (_) {
        // Cloud is optional for this pass. Return and retain local progress.
      }
    }

    // Older app builds may have progress in the controller but no timestamp
    // journal yet. Keep it as a fallback; a timestamped cloud entry wins.
    for (final entry in currentProgress.entries) {
      local.putIfAbsent(entry.key, () => <String, dynamic>{
        'progress': entry.value,
        'updatedAt': DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
            .toIso8601String(),
      });
    }

    final merged = <String, Map<String, dynamic>>{};
    final ids = <String>{...local.keys, ...remote.keys};
    for (final id in ids) {
      final localEntry = local[id];
      final remoteEntry = remote[id];
      if (localEntry == null) {
        merged[id] = remoteEntry!;
      } else if (remoteEntry == null) {
        merged[id] = localEntry;
      } else {
        final localDate = DateTime.tryParse(localEntry['updatedAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
        final remoteDate = DateTime.tryParse(remoteEntry['updatedAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
        merged[id] = remoteDate.isAfter(localDate) ? remoteEntry : localEntry;
      }
    }

    await _writeLocal(profile, merged);
    if (api.isAuthenticated) await _pushLocal(api: api, profileId: profile);

    final result = <String, double>{};
    final positions = <String, int>{};
    final durations = <String, int>{};
    for (final entry in merged.entries) {
      final value = double.tryParse(entry.value['progress']?.toString() ?? '');
      if (value != null && value.isFinite) {
        result[entry.key] = value.clamp(0.0, 1.0).toDouble();
      }
      final position = int.tryParse(entry.value['positionSeconds']?.toString() ?? '');
      final duration = int.tryParse(entry.value['durationSeconds']?.toString() ?? '');
      if (position != null && position >= 0) positions[entry.key] = position;
      if (duration != null && duration > 0) durations[entry.key] = duration;
    }
    return PlaybackProgressSyncSnapshot(
      progress: result,
      positionSeconds: positions,
      durationSeconds: durations,
    );
  }
}
