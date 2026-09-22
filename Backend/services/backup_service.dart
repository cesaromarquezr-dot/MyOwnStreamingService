// FILE: Backend/services/backup_service.dart.
//
// Purpose: Provides a safe, read-only backup policy abstraction.
// It never deletes, moves, or modifies originals.

import 'dart:convert';
import 'dart:io';

/// Provides operational status for the configured backup destination.
///
/// This service intentionally does not perform backup copies or deletion.
/// Actual backup execution belongs in a separate service/job.
class BackupService {
  const BackupService();

  /// Checks whether the configured backup destination is reachable and
  /// reports backup freshness and available filesystem capacity.
  ///
  /// Environment variables:
  ///
  /// BACKUP_DESTINATION
  ///   Directory used for backups.
  ///
  /// BACKUP_LAST_SUCCESS
  ///   Optional ISO-8601 timestamp representing the last successful backup.
  ///
  /// BACKUP_LAST_SUCCESS_FILE
  ///   Optional file whose modification time represents the last successful
  ///   backup. If supplied, this takes precedence over BACKUP_LAST_SUCCESS.
  ///
  /// BACKUP_MAX_AGE_HOURS
  ///   Maximum acceptable backup age. Defaults to 24 hours.
  ///
  /// BACKUP_TOTAL_BYTES / BACKUP_FREE_BYTES
  ///   Optional explicit capacity values. Useful when filesystem statistics
  ///   are supplied by an external backup system.
  Future<Map<String, dynamic>> status() async {
    final destination =
        Platform.environment['BACKUP_DESTINATION']?.trim() ?? '';

    final configured = destination.isNotEmpty;

    if (!configured) {
      return const {
        'configured': false,
        'reachable': false,
        'state': 'not_configured',
        'freshness': {
          'state': 'unknown',
          'lastSuccess': null,
          'ageSeconds': null,
          'maxAgeSeconds': 86400,
          'stale': true,
        },
        'capacity': {
          'available': false,
          'totalBytes': null,
          'freeBytes': null,
          'usedBytes': null,
          'usedPercent': null,
        },
        'raidIsNotBackup': true,
      };
    }

    bool reachable = false;

    try {
      reachable = await Directory(destination).exists();
    } on FileSystemException {
      reachable = false;
    } on OSError {
      reachable = false;
    }

    if (!reachable) {
      return {
        'configured': true,
        'reachable': false,
        'state': 'unreachable',
        'freshness': _freshnessStatus(),
        'capacity': const {
          'available': false,
          'totalBytes': null,
          'freeBytes': null,
          'usedBytes': null,
          'usedPercent': null,
        },
        'raidIsNotBackup': true,
      };
    }

    final freshness = _freshnessStatus();
    final capacity = await _capacityStatus(destination);

    final freshnessState = freshness['state'] as String? ?? 'unknown';

    String state;

    if (!reachable) {
      state = 'unreachable';
    } else if (freshnessState == 'stale') {
      state = 'stale';
    } else if (freshnessState == 'unknown') {
      state = 'freshness_unknown';
    } else if (capacity['available'] != true) {
      state = 'capacity_unknown';
    } else if ((capacity['usedPercent'] as num?) != null &&
        (capacity['usedPercent'] as num) >= 95) {
      state = 'capacity_critical';
    } else if ((capacity['usedPercent'] as num?) != null &&
        (capacity['usedPercent'] as num) >= 85) {
      state = 'capacity_warning';
    } else {
      state = 'ready';
    }

    return {
      'configured': true,
      'reachable': true,
      'state': state,
      'freshness': freshness,
      'capacity': capacity,
      'raidIsNotBackup': true,
    };
  }

  Map<String, dynamic> _freshnessStatus() {
    final maxAgeHours = _positiveIntEnvironment(
      'BACKUP_MAX_AGE_HOURS',
      fallback: 24,
    );

    final maxAge = Duration(hours: maxAgeHours);

    DateTime? lastSuccess;

    final markerPath =
        Platform.environment['BACKUP_LAST_SUCCESS_FILE']?.trim() ?? '';

    if (markerPath.isNotEmpty) {
      try {
        final marker = File(markerPath);
        if (marker.existsSync()) {
          lastSuccess = marker.statSync().modified;
        }
      } on FileSystemException {
        lastSuccess = null;
      } on OSError {
        lastSuccess = null;
      }
    }

    if (lastSuccess == null) {
      final configuredTimestamp =
          Platform.environment['BACKUP_LAST_SUCCESS']?.trim() ?? '';

      if (configuredTimestamp.isNotEmpty) {
        lastSuccess = DateTime.tryParse(configuredTimestamp);
      }
    }

    if (lastSuccess == null) {
      return {
        'state': 'unknown',
        'lastSuccess': null,
        'ageSeconds': null,
        'maxAgeSeconds': maxAge.inSeconds,
        'stale': true,
      };
    }

    final now = DateTime.now();
    final age = now.difference(lastSuccess);

    // A future timestamp is treated as invalid rather than as a fresh backup.
    if (age.isNegative) {
      return {
        'state': 'unknown',
        'lastSuccess': lastSuccess.toUtc().toIso8601String(),
        'ageSeconds': null,
        'maxAgeSeconds': maxAge.inSeconds,
        'stale': true,
      };
    }

    final stale = age > maxAge;

    return {
      'state': stale ? 'stale' : 'fresh',
      'lastSuccess': lastSuccess.toUtc().toIso8601String(),
      'ageSeconds': age.inSeconds,
      'maxAgeSeconds': maxAge.inSeconds,
      'stale': stale,
    };
  }

  Future<Map<String, dynamic>> _capacityStatus(String destination) async {
    final explicitTotal = _nonNegativeIntEnvironment('BACKUP_TOTAL_BYTES');
    final explicitFree = _nonNegativeIntEnvironment('BACKUP_FREE_BYTES');

    if (explicitTotal != null && explicitFree != null) {
      return _buildCapacity(
        totalBytes: explicitTotal,
        freeBytes: explicitFree,
        source: 'environment',
      );
    }

    if (Platform.isWindows) {
      final windowsCapacity = await _windowsCapacity(destination);

      if (windowsCapacity != null) {
        return windowsCapacity;
      }
    } else {
      final unixCapacity = await _unixCapacity(destination);

      if (unixCapacity != null) {
        return unixCapacity;
      }
    }

    return const {
      'available': false,
      'totalBytes': null,
      'freeBytes': null,
      'usedBytes': null,
      'usedPercent': null,
      'source': null,
    };
  }

  Future<Map<String, dynamic>?> _windowsCapacity(
    String destination,
  ) async {
    try {
      final drive = _windowsDriveLetter(destination);

      if (drive == null) {
        return null;
      }

      final script = r'''
$volume = Get-Volume -DriveLetter $env:BACKUP_DRIVE
if ($null -eq $volume) {
  exit 2
}
[Console]::WriteLine("$($volume.Size)|$($volume.SizeRemaining)")
''';

      final result = await Process.run(
        'powershell.exe',
        <String>[
          '-NoProfile',
          '-NonInteractive',
          '-ExecutionPolicy',
          'Bypass',
          '-Command',
          script,
        ],
        environment: {
          'BACKUP_DRIVE': drive,
        },
      );

      if (result.exitCode != 0) {
        return null;
      }

      final output = result.stdout.toString().trim();
      final parts = output.split('|');

      if (parts.length != 2) {
        return null;
      }

      final total = int.tryParse(parts[0].trim());
      final free = int.tryParse(parts[1].trim());

      if (total == null || free == null) {
        return null;
      }

      return _buildCapacity(
        totalBytes: total,
        freeBytes: free,
        source: 'filesystem',
      );
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _unixCapacity(
    String destination,
  ) async {
    try {
      final result = await Process.run(
        'df',
        <String>['-Pk', destination],
      );

      if (result.exitCode != 0) {
        return null;
      }

      final lines = const LineSplitter()
          .convert(result.stdout.toString())
          .where((line) => line.trim().isNotEmpty)
          .toList();

      if (lines.length < 2) {
        return null;
      }

      final fields = lines.last.trim().split(RegExp(r'\s+'));

      if (fields.length < 5) {
        return null;
      }

      // POSIX df -P reports:
      // filesystem blocks used available capacity mountpoint
      final totalKb = int.tryParse(fields[1]);
      final freeKb = int.tryParse(fields[3]);

      if (totalKb == null || freeKb == null) {
        return null;
      }

      return _buildCapacity(
        totalBytes: totalKb * 1024,
        freeBytes: freeKb * 1024,
        source: 'filesystem',
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _buildCapacity({
    required int totalBytes,
    required int freeBytes,
    required String source,
  }) {
    final safeTotal = totalBytes < 0 ? 0 : totalBytes;
    final safeFree = freeBytes.clamp(0, safeTotal);
    final usedBytes = safeTotal - safeFree;

    final usedPercent =
        safeTotal == 0 ? 0.0 : (usedBytes / safeTotal) * 100.0;

    return {
      'available': true,
      'totalBytes': safeTotal,
      'freeBytes': safeFree,
      'usedBytes': usedBytes,
      'usedPercent': double.parse(usedPercent.toStringAsFixed(2)),
      'source': source,
    };
  }

  String? _windowsDriveLetter(String destination) {
    final match = RegExp(r'^([A-Za-z]):(?:\\|/|$)').firstMatch(destination);

    if (match == null) {
      return null;
    }

    return match.group(1)!.toUpperCase();
  }

  int _positiveIntEnvironment(
    String name, {
    required int fallback,
  }) {
    final raw = Platform.environment[name]?.trim();

    if (raw == null || raw.isEmpty) {
      return fallback;
    }

    final parsed = int.tryParse(raw);

    if (parsed == null || parsed <= 0) {
      return fallback;
    }

    return parsed;
  }

  int? _nonNegativeIntEnvironment(String name) {
    final raw = Platform.environment[name]?.trim();

    if (raw == null || raw.isEmpty) {
      return null;
    }

    final parsed = int.tryParse(raw);

    if (parsed == null || parsed < 0) {
      return null;
    }

    return parsed;
  }
}