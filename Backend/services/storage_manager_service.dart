// FILE: Backend/services/storage_manager_service.dart.
// Purpose: Monitors NAS filesystem, RAID, backup, and UPS state without
// destructively changing the storage controller or filesystem.

import 'dart:io';

import '../config.dart';
import '../models/storage.dart';
import 'backup_service.dart';

class StorageManagerService {
  final BackupService backupService;

  const StorageManagerService({this.backupService = const BackupService()});

  /// Returns a non-destructive snapshot of the configured media storage.
  Future<Map<String, dynamic>> snapshot() async {
    final filesystem = await _filesystemStatus(AppConfig.mediaRoot);
    final raid = await _raidStatus();
    final ups = await _upsStatus();
    final backupProbe = await backupService.status();

    final pool = StoragePoolStatus(
      name: Platform.environment['MEDIA_POOL_NAME'] ?? 'MediaPool',
      raidLevel: raid['raidLevel']?.toString() ?? 'unknown',
      driveCount: int.tryParse('${raid['driveCount'] ?? 0}') ?? 0,
      usableBytes: int.tryParse('${filesystem['sizeBytes'] ?? 0}') ?? 0,
      usedBytes: int.tryParse('${filesystem['usedBytes'] ?? 0}') ?? 0,
      health: raid['health']?.toString() ?? 'unknown',
      rebuilding: raid['rebuilding'] == true,
      rebuildProgress: double.tryParse('${raid['rebuildProgress'] ?? 0}') ?? 0,
      drives: const [],
    );

    final backup = BackupStatus(
      configured: backupProbe['configured'] == true,
      state: backupProbe['state']?.toString() ?? 'not_configured',
      lastSuccessfulBackup: DateTime.tryParse(
        Platform.environment['BACKUP_LAST_SUCCESS'] ?? '',
      ),
      destination: backupProbe['destination']?.toString() ?? '',
    );

    return {
      'success': true,
      'mediaPath': AppConfig.mediaRoot,
      'pool': pool.toJson(),
      'raidRaw': raid['raw'],
      'backup': {...backup.toJson(), 'reachable': backupProbe['reachable']},
      'ups': ups.toJson(),
      'policy': {
        'raidIsNotBackup': true,
        'originalMediaIsPreserved': true,
        'transcodeCacheMayBeDeleted': true,
        'recommendedRaid': 'RAID 6 for larger media arrays; RAID 10 where performance is the priority.',
      },
    };
  }

  Future<Map<String, dynamic>> _filesystemStatus(String path) async {
    if (!Directory(path).existsSync()) {
      return {'sizeBytes': 0, 'usedBytes': 0, 'freeBytes': 0};
    }

    if (Platform.isWindows) {
      final match = RegExp(r'^([A-Za-z]:)').firstMatch(path);
      final drive = match?.group(1) ?? 'C:';
      final result = await Process.run('powershell', [
        '-NoProfile', '-Command',
        '(Get-PSDrive -Name ${drive[0]}).Used; (Get-PSDrive -Name ${drive[0]}).Free',
      ]);
      final values = result.stdout.toString().split(RegExp(r'\r?\n'))
          .where((v) => v.trim().isNotEmpty)
          .map((v) => int.tryParse(v.trim()) ?? 0).toList();
      if (values.length >= 2) {
        final used = values[0];
        final free = values[1];
        return {'sizeBytes': used + free, 'usedBytes': used, 'freeBytes': free};
      }
    } else {
      final result = await Process.run('df', ['-P', path]);
      final lines = result.stdout.toString().trim().split(RegExp(r'\r?\n'));
      if (lines.length >= 2) {
        final fields = lines.last.split(RegExp(r'\s+'));
        if (fields.length >= 5) {
          final total = int.tryParse(fields[1]) ?? 0;
          final used = int.tryParse(fields[2]) ?? 0;
          final free = int.tryParse(fields[3]) ?? 0;
          return {'sizeBytes': total * 1024, 'usedBytes': used * 1024, 'freeBytes': free * 1024};
        }
      }
    }
    return {'sizeBytes': 0, 'usedBytes': 0, 'freeBytes': 0};
  }

  Future<Map<String, dynamic>> _raidStatus() async {
    if (Platform.isLinux) {
      final result = await Process.run('sh', ['-c', 'cat /proc/mdstat 2>/dev/null || true']);
      final raw = result.stdout.toString();
      final match = RegExp(r'\b(raid[0-9]+)\b', caseSensitive: false).firstMatch(raw);
      final rebuilding = raw.contains('recovery') || raw.contains('resync') || raw.contains('reshape');
      final progress = RegExp(r'(\d+(?:\.\d+)?)%').firstMatch(raw)?.group(1);
      return {
        'raidLevel': match?.group(1)?.toUpperCase() ?? 'unknown',
        'driveCount': RegExp(r'\[[0-9]+/[0-9]+\]').firstMatch(raw)?.group(0)?.replaceAll(RegExp(r'[^0-9/]'), '') .split('/').first ?? '0',
        'health': raw.contains('_') ? 'degraded_or_rebuilding' : (raw.isEmpty ? 'unknown' : 'healthy'),
        'rebuilding': rebuilding,
        'rebuildProgress': double.tryParse(progress ?? '0') ?? 0,
        'raw': raw,
      };
    }
    return {
      'raidLevel': Platform.environment['RAID_LEVEL'] ?? 'not_detected',
      'driveCount': Platform.environment['RAID_DRIVE_COUNT'] ?? '0',
      'health': Platform.environment['RAID_HEALTH'] ?? 'unknown',
      'rebuilding': Platform.environment['RAID_REBUILDING'] == 'true',
      'rebuildProgress': double.tryParse(Platform.environment['RAID_REBUILD_PROGRESS'] ?? '0') ?? 0,
      'raw': null,
    };
  }

  Future<UpsStatus> _upsStatus() async {
    final name = Platform.environment['UPS_NAME']?.trim() ?? '';
    if (name.isEmpty) {
      return const UpsStatus(configured: false, onBattery: false, batteryPercent: 0, estimatedRuntimeSeconds: 0, state: 'not_configured');
    }
    try {
      final result = await Process.run('upsc', [name]);
      final output = result.stdout.toString();
      String value(String key) {
        for (final line in output.split(RegExp(r'\r?\n'))) {
          if (line.startsWith('$key:')) return line.substring(key.length + 1).trim();
        }
        return '';
      }
      final status = value('ups.status');
      return UpsStatus(
        configured: true,
        onBattery: status.contains('OB'),
        batteryPercent: double.tryParse(value('battery.charge'))?.round() ?? 0,
        estimatedRuntimeSeconds: double.tryParse(value('battery.runtime'))?.round() ?? 0,
        state: status.isEmpty ? 'unknown' : status,
      );
    } catch (_) {
      return const UpsStatus(configured: true, onBattery: false, batteryPercent: 0, estimatedRuntimeSeconds: 0, state: 'unavailable');
    }
  }
}
