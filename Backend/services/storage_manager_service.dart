// FILE: Backend/services/storage_manager_service.dart.
// Purpose: Monitors NAS filesystem, RAID, backup, and UPS state without
// destructively changing the storage controller or filesystem.
//
// This service is intentionally read-only. It never:
// - creates, deletes, mounts, unmounts, or formats storage;
// - modifies RAID configuration;
// - starts/stops a backup;
// - changes UPS state;
// - deletes transcoding or media files.
//
// Production deployments should run this service with the minimum OS
// permissions required to read the configured storage/probe information.

import 'dart:async';
import 'dart:io';

import '../config.dart';
import '../models/storage.dart';
import 'backup_service.dart';

class StorageManagerService {
  static const Duration _probeTimeout = Duration(seconds: 10);

  static const int _maxRawOutputLength = 16 * 1024;

  final BackupService backupService;

  const StorageManagerService({
    this.backupService = const BackupService(),
  });

  /// Returns a non-destructive snapshot of the configured media storage.
  Future<Map<String, dynamic>> snapshot() async {
    final filesystem = await _filesystemStatus(AppConfig.mediaRoot);
    final raid = await _raidStatus();
    final ups = await _upsStatus();

    Map<String, dynamic> backupProbe;
    try {
      backupProbe = await backupService.status();
    } catch (_) {
      backupProbe = const {
        'configured': false,
        'state': 'unavailable',
        'reachable': false,
        'destination': '',
      };
    }

    final totalBytes = _nonNegativeInt(filesystem['sizeBytes']);
    final usedBytes = _boundedUsedBytes(
      filesystem['usedBytes'],
      totalBytes,
    );

    final pool = StoragePoolStatus(
      name: _boundedText(
        Platform.environment['MEDIA_POOL_NAME'] ?? 'MediaPool',
        maxLength: 200,
        fallback: 'MediaPool',
      ),
      raidLevel: _boundedText(
        raid['raidLevel']?.toString() ?? 'unknown',
        maxLength: 50,
        fallback: 'unknown',
      ),
      driveCount: _nonNegativeInt(raid['driveCount']),
      usableBytes: totalBytes,
      usedBytes: usedBytes,
      health: _boundedText(
        raid['health']?.toString() ?? 'unknown',
        maxLength: 100,
        fallback: 'unknown',
      ),
      rebuilding: raid['rebuilding'] == true,
      rebuildProgress: _boundedProgress(raid['rebuildProgress']),
      drives: const [],
    );

    final backup = BackupStatus(
      configured: backupProbe['configured'] == true,
      state: _boundedText(
        backupProbe['state']?.toString() ?? 'not_configured',
        maxLength: 100,
        fallback: 'not_configured',
      ),
      lastSuccessfulBackup: DateTime.tryParse(
        Platform.environment['BACKUP_LAST_SUCCESS'] ?? '',
      )?.toUtc(),
      destination: _boundedText(
        backupProbe['destination']?.toString() ?? '',
        maxLength: 2048,
      ),
    );

    return {
      'success': true,
      'mediaPath': _boundedText(
        AppConfig.mediaRoot,
        maxLength: 4096,
      ),
      'pool': pool.toJson(),
      'filesystem': {
        'known': filesystem['known'] == true,
        'sizeBytes': totalBytes,
        'usedBytes': usedBytes,
        'freeBytes': _nonNegativeInt(filesystem['freeBytes']),
        'usagePercent': _usagePercent(usedBytes, totalBytes),
      },
      'raidRaw': raid['raw'],
      'backup': {
        ...backup.toJson(),
        'reachable': backupProbe['reachable'] == true,
      },
      'ups': ups.toJson(),
      'policy': {
        'raidIsNotBackup': true,
        'originalMediaIsPreserved': true,
        'transcodeCacheMayBeDeleted': true,
        'storageMonitoringIsReadOnly': true,
        'recommendedRaid':
            'RAID 6 for larger media arrays; RAID 10 where performance is the priority.',
      },
    };
  }

  Future<Map<String, dynamic>> _filesystemStatus(String path) async {
    final normalizedPath = path.trim();

    if (normalizedPath.isEmpty) {
      return _unknownFilesystem();
    }

    try {
      if (!await Directory(normalizedPath).exists()) {
        return _unknownFilesystem();
      }
    } catch (_) {
      return _unknownFilesystem();
    }

    if (Platform.isWindows) {
      return _windowsFilesystemStatus(normalizedPath);
    }

    return _unixFilesystemStatus(normalizedPath);
  }

  Future<Map<String, dynamic>> _windowsFilesystemStatus(String path) async {
    final match = RegExp(r'^([A-Za-z]):').firstMatch(path);
    final drive = match?.group(1)?.toUpperCase();

    if (drive == null || drive.isEmpty) {
      return _unknownFilesystem();
    }

    // Get-Volume is read-only. The drive name is derived from the validated
    // local path rather than accepted directly from a network request.
    final command = '''
\$volume = Get-Volume -DriveLetter '$drive' -ErrorAction Stop
[long](\$volume.Size)
[long](\$volume.SizeRemaining)
''';

    try {
      final result = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          command,
        ],
      ).timeout(_probeTimeout);

      if (result.exitCode != 0) {
        return _unknownFilesystem();
      }

      final values = _parseIntegerLines(result.stdout.toString());

      if (values.length < 2) {
        return _unknownFilesystem();
      }

      final total = _nonNegativeInt(values[0]);
      final free = _nonNegativeInt(values[1]);
      final boundedFree = free > total ? total : free;
      final used = total - boundedFree;

      return {
        'known': total > 0,
        'sizeBytes': total,
        'usedBytes': used,
        'freeBytes': boundedFree,
      };
    } on TimeoutException {
      return _unknownFilesystem();
    } on ProcessException {
      return _unknownFilesystem();
    } catch (_) {
      return _unknownFilesystem();
    }
  }

  Future<Map<String, dynamic>> _unixFilesystemStatus(String path) async {
    try {
      final result = await Process.run(
        'df',
        ['-P', path],
      ).timeout(_probeTimeout);

      if (result.exitCode != 0) {
        return _unknownFilesystem();
      }

      final output = result.stdout.toString();
      final lines = output
          .split(RegExp(r'\r?\n'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();

      if (lines.length < 2) {
        return _unknownFilesystem();
      }

      // POSIX df -P uses:
      // filesystem blocks used available capacity mounted-on
      //
      // A mount path can contain spaces, so use the final four whitespace
      // separated fields rather than assuming the filesystem field has no
      // whitespace.
      final fields = lines.last.split(RegExp(r'\s+'));

      if (fields.length < 5) {
        return _unknownFilesystem();
      }

      final totalBlocks = int.tryParse(fields[fields.length - 4]);
      final usedBlocks = int.tryParse(fields[fields.length - 3]);
      final freeBlocks = int.tryParse(fields[fields.length - 2]);

      if (totalBlocks == null ||
          usedBlocks == null ||
          freeBlocks == null ||
          totalBlocks < 0 ||
          usedBlocks < 0 ||
          freeBlocks < 0) {
        return _unknownFilesystem();
      }

      final total = _safeMultiplyBy1024(totalBlocks);
      final used = _safeMultiplyBy1024(usedBlocks);
      final free = _safeMultiplyBy1024(freeBlocks);

      final boundedTotal = total;
      final boundedUsed = used > boundedTotal ? boundedTotal : used;
      final boundedFree = free > boundedTotal
          ? boundedTotal
          : free > boundedTotal - boundedUsed
              ? boundedTotal - boundedUsed
              : free;

      return {
        'known': boundedTotal > 0,
        'sizeBytes': boundedTotal,
        'usedBytes': boundedUsed,
        'freeBytes': boundedFree,
      };
    } on TimeoutException {
      return _unknownFilesystem();
    } on ProcessException {
      return _unknownFilesystem();
    } catch (_) {
      return _unknownFilesystem();
    }
  }

  Future<Map<String, dynamic>> _raidStatus() async {
    if (Platform.isLinux) {
      return _linuxRaidStatus();
    }

    return _configuredRaidStatus();
  }

  Future<Map<String, dynamic>> _linuxRaidStatus() async {
    try {
      // /proc/mdstat is read-only. No mdadm mutation commands are executed.
      final result = await Process.run(
        'cat',
        ['/proc/mdstat'],
      ).timeout(_probeTimeout);

      if (result.exitCode != 0) {
        return _unknownRaid(raw: '');
      }

      final raw = _boundedText(
        result.stdout.toString(),
        maxLength: _maxRawOutputLength,
      );

      if (raw.trim().isEmpty) {
        return _unknownRaid(raw: raw);
      }

      final raidMatch = RegExp(
        r'\b(raid[0-9]+)\b',
        caseSensitive: false,
      ).firstMatch(raw);

      final arrayMatch = RegExp(
        r'\[(\d+)/(\d+)\]',
      ).firstMatch(raw);

      final rebuilding = RegExp(
        r'\b(recovery|resync|reshape|check)\b',
        caseSensitive: false,
      ).hasMatch(raw);

      final progressMatch = RegExp(
        r'(\d+(?:\.\d+)?)%',
      ).firstMatch(raw);

      final configuredDrives = int.tryParse(arrayMatch?.group(1) ?? '') ?? 0;
      final expectedDrives = int.tryParse(arrayMatch?.group(2) ?? '') ?? 0;

      final health = _linuxRaidHealth(
        raw: raw,
        rebuilding: rebuilding,
        configuredDrives: configuredDrives,
        expectedDrives: expectedDrives,
      );

      return {
        'raidLevel': raidMatch?.group(1)?.toUpperCase() ?? 'unknown',
        'driveCount': expectedDrives > 0 ? expectedDrives : configuredDrives,
        'health': health,
        'rebuilding': rebuilding,
        'rebuildProgress': _boundedProgress(
          double.tryParse(progressMatch?.group(1) ?? '0') ?? 0,
        ),
        'raw': raw,
      };
    } on TimeoutException {
      return _unknownRaid(raw: '');
    } on ProcessException {
      return _unknownRaid(raw: '');
    } catch (_) {
      return _unknownRaid(raw: '');
    }
  }

  Map<String, dynamic> _configuredRaidStatus() {
    final raidLevel = _boundedText(
      Platform.environment['RAID_LEVEL'] ?? 'not_detected',
      maxLength: 50,
      fallback: 'not_detected',
    );

    final driveCount =
        int.tryParse(Platform.environment['RAID_DRIVE_COUNT'] ?? '') ?? 0;

    final health = _boundedText(
      Platform.environment['RAID_HEALTH'] ?? 'unknown',
      maxLength: 100,
      fallback: 'unknown',
    );

    final rebuilding =
        Platform.environment['RAID_REBUILDING']?.toLowerCase() == 'true';

    final progress = double.tryParse(
          Platform.environment['RAID_REBUILD_PROGRESS'] ?? '',
        ) ??
        0;

    return {
      'raidLevel': raidLevel,
      'driveCount': _nonNegativeInt(driveCount),
      'health': health,
      'rebuilding': rebuilding,
      'rebuildProgress': _boundedProgress(progress),
      'raw': null,
    };
  }

  Future<UpsStatus> _upsStatus() async {
    final name = Platform.environment['UPS_NAME']?.trim() ?? '';

    if (name.isEmpty) {
      return const UpsStatus(
        configured: false,
        onBattery: false,
        batteryPercent: 0,
        estimatedRuntimeSeconds: 0,
        state: 'not_configured',
      );
    }

    // Do not pass arbitrary command arguments from the HTTP layer. UPS_NAME
    // is read from the server environment only.
    if (!_isSafeUpsIdentifier(name)) {
      return const UpsStatus(
        configured: true,
        onBattery: false,
        batteryPercent: 0,
        estimatedRuntimeSeconds: 0,
        state: 'invalid_configuration',
      );
    }

    try {
      final result = await Process.run(
        'upsc',
        [name],
      ).timeout(_probeTimeout);

      if (result.exitCode != 0) {
        return const UpsStatus(
          configured: true,
          onBattery: false,
          batteryPercent: 0,
          estimatedRuntimeSeconds: 0,
          state: 'unavailable',
        );
      }

      final output = _boundedText(
        result.stdout.toString(),
        maxLength: _maxRawOutputLength,
      );

      String value(String key) {
        for (final line in output.split(RegExp(r'\r?\n'))) {
          if (line.startsWith('$key:')) {
            return line.substring(key.length + 1).trim();
          }
        }
        return '';
      }

      final status = value('ups.status').toUpperCase();

      final battery = _boundedPercentage(
        double.tryParse(value('battery.charge')) ?? 0,
      );

      final runtime = _nonNegativeInt(
        double.tryParse(value('battery.runtime'))?.round() ?? 0,
      );

      return UpsStatus(
        configured: true,
        onBattery: status
            .split(RegExp(r'\s+'))
            .where((part) => part.isNotEmpty)
            .contains('OB'),
        batteryPercent: battery,
        estimatedRuntimeSeconds: runtime,
        state: status.isEmpty
            ? 'unknown'
            : _boundedText(
                status,
                maxLength: 100,
                fallback: 'unknown',
              ),
      );
    } on TimeoutException {
      return const UpsStatus(
        configured: true,
        onBattery: false,
        batteryPercent: 0,
        estimatedRuntimeSeconds: 0,
        state: 'timeout',
      );
    } on ProcessException {
      return const UpsStatus(
        configured: true,
        onBattery: false,
        batteryPercent: 0,
        estimatedRuntimeSeconds: 0,
        state: 'unavailable',
      );
    } catch (_) {
      return const UpsStatus(
        configured: true,
        onBattery: false,
        batteryPercent: 0,
        estimatedRuntimeSeconds: 0,
        state: 'unavailable',
      );
    }
  }

  Map<String, dynamic> _unknownFilesystem() {
    return const {
      'known': false,
      'sizeBytes': 0,
      'usedBytes': 0,
      'freeBytes': 0,
    };
  }

  Map<String, dynamic> _unknownRaid({required String raw}) {
    return {
      'raidLevel': 'unknown',
      'driveCount': 0,
      'health': 'unknown',
      'rebuilding': false,
      'rebuildProgress': 0.0,
      'raw': raw.isEmpty ? null : raw,
    };
  }

  String _linuxRaidHealth({
    required String raw,
    required bool rebuilding,
    required int configuredDrives,
    required int expectedDrives,
  }) {
    if (rebuilding) {
      return 'rebuilding';
    }

    if (configuredDrives > 0 &&
        expectedDrives > 0 &&
        configuredDrives < expectedDrives) {
      return 'degraded';
    }

    // mdstat uses underscores in the active-device bitmap when a member is
    // missing. Avoid treating every underscore in arbitrary output as proof
    // of failure.
    final arrayLine = raw
        .split(RegExp(r'\r?\n'))
        .firstWhere(
          (line) => line.contains('[') && line.contains(']'),
          orElse: () => '',
        );

    if (RegExp(r'\[\d+/\d+\]\s+\[.*_.*\]')
        .hasMatch(arrayLine)) {
      return 'degraded';
    }

    return 'healthy';
  }

  List<int> _parseIntegerLines(String output) {
    final values = <int>[];

    for (final line in output.split(RegExp(r'\r?\n'))) {
      final value = int.tryParse(line.trim());
      if (value != null) {
        values.add(value);
      }
    }

    return values;
  }

  bool _isSafeUpsIdentifier(String value) {
    if (value.isEmpty || value.length > 200) {
      return false;
    }

    // NUT UPS identifiers are configuration values, not shell expressions.
    // Process.run does not invoke a shell, but rejecting control characters
    // still prevents malformed configuration from reaching the probe.
    return !value.contains(RegExp(r'[\x00-\x1F\x7F]'));
  }

  int _nonNegativeInt(Object? value) {
    final parsed = value is int
        ? value
        : int.tryParse(value?.toString() ?? '');

    if (parsed == null || parsed < 0) {
      return 0;
    }

    return parsed;
  }

  int _boundedUsedBytes(Object? value, int total) {
    final used = _nonNegativeInt(value);
    return used > total ? total : used;
  }

  int _safeMultiplyBy1024(int value) {
    if (value <= 0) {
      return 0;
    }

    const maxInt = 0x7FFFFFFFFFFFFFFF;

    if (value > maxInt ~/ 1024) {
      return maxInt;
    }

    return value * 1024;
  }

  double _boundedProgress(Object? value) {
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;

    if (!parsed.isFinite) {
      return 0;
    }

    return parsed.clamp(0, 100).toDouble();
  }

  int _boundedPercentage(double value) {
    if (!value.isFinite) {
      return 0;
    }

    return value.clamp(0, 100).round();
  }

  double _usagePercent(int used, int total) {
    if (total <= 0) {
      return 0;
    }

    final value = (used / total) * 100;

    if (!value.isFinite) {
      return 0;
    }

    return value.clamp(0, 100).toDouble();
  }

  String _boundedText(
    String value, {
    required int maxLength,
    String fallback = '',
  }) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return fallback;
    }

    final withoutControls = trimmed.replaceAll(
      RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'),
      '',
    );

    if (withoutControls.isEmpty) {
      return fallback;
    }

    if (withoutControls.length <= maxLength) {
      return withoutControls;
    }

    return withoutControls.substring(0, maxLength);
  }
}