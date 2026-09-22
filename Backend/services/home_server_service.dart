// FILE: Backend/services/home_server_service.dart.
//
// Purpose:
// Provides home-server storage and ARM integration status.
//
// Storage status is observational only. This service does not create,
// delete, move, or modify media files.
//
// The configured category capacities remain application-level quotas.
// Filesystem capacity is reported separately when the operating system
// exposes it through the platform's standard command-line tools.

import 'dart:convert';
import 'dart:io';

import '../config.dart';

class HomeServerService {
  /// Returns configured media paths, capacities, filesystem usage, and
  /// filesystem capacity information.
  Map<String, dynamic> storageStatus() {
    final movies = _path(
      'MOVIES_PATH',
      '${AppConfig.mediaRoot}/movies',
    );
    final series = _path(
      'SERIES_PATH',
      '${AppConfig.mediaRoot}/series',
    );
    final music = _path(
      'MUSIC_PATH',
      '${AppConfig.mediaRoot}/music',
    );

    final categories = <Map<String, dynamic>>[
      _category(
        'Movies',
        movies,
        AppConfig.moviesCapacityBytes,
      ),
      _category(
        'Series',
        series,
        AppConfig.seriesCapacityBytes,
      ),
      _category(
        'Music',
        music,
        AppConfig.musicCapacityBytes,
      ),
    ];

    final filesystemByPath = <String, Map<String, dynamic>>{};

    for (final category in categories) {
      final path = category['path'] as String;
      filesystemByPath[path] = _filesystemCapacity(path);
    }

    return {
      'root': AppConfig.mediaRoot,
      'categories': categories,
      'availableBytes': AppConfig.availableStorageBytes,
      'totalBytes': AppConfig.moviesCapacityBytes +
          AppConfig.seriesCapacityBytes +
          AppConfig.musicCapacityBytes +
          AppConfig.availableStorageBytes,
      'filesystem': {
        'categories': filesystemByPath,
      },
    };
  }

  /// Returns the paths used by ARM and the media importer.
  Map<String, dynamic> armStatus() => {
        'armServerUrl': AppConfig.armServerUrl,
        'mediaRoot': AppConfig.mediaRoot,
        'opticalDriveHint':
            Platform.environment['ARM_OPTICAL_DRIVE']?.trim().isNotEmpty == true
                ? Platform.environment['ARM_OPTICAL_DRIVE']!.trim()
                : 'Configure ARM optical drive',
        'connected': AppConfig.armServerUrl.trim().isNotEmpty,
      };

  Map<String, dynamic> _category(
    String name,
    String path,
    int capacity,
  ) {
    final normalizedCapacity = capacity < 0 ? 0 : capacity;
    final directory = Directory(path);
    final exists = directory.existsSync();
    final usedBytes = exists ? _size(directory) : 0;

    final remainingConfiguredBytes = normalizedCapacity > usedBytes
        ? normalizedCapacity - usedBytes
        : 0;

    return {
      'name': name,
      'path': path,
      'capacityBytes': normalizedCapacity,
      'usedBytes': usedBytes,
      'remainingConfiguredBytes': remainingConfiguredBytes,
      'usagePercent': normalizedCapacity > 0
          ? ((usedBytes / normalizedCapacity) * 100)
              .clamp(0, 100)
              .toDouble()
          : null,
      'exists': exists,
    };
  }

  String _path(String environmentKey, String fallback) {
    final configured = Platform.environment[environmentKey]?.trim();

    if (configured != null && configured.isNotEmpty) {
      return configured;
    }

    return fallback;
  }

  /// Calculates media usage without following symbolic links.
  ///
  /// Errors from inaccessible files/directories are ignored so one
  /// unreadable item cannot make the entire storage status endpoint fail.
  int _size(Directory directory) {
    var total = 0;

    try {
      for (final entity in directory.listSync(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) {
          continue;
        }

        try {
          final length = entity.lengthSync();

          // Guard against integer overflow even though Dart's int is
          // arbitrary precision on supported platforms.
          if (length > 0) {
            total += length;
          }
        } catch (_) {
          // Ignore individual files that cannot be inspected.
        }
      }
    } catch (_) {
      // Ignore inaccessible directories.
    }

    return total;
  }

  /// Returns filesystem-level capacity for the volume containing [path].
  ///
  /// Dart's core File/Directory APIs do not expose portable filesystem
  /// capacity information, so this uses:
  ///   - PowerShell Get-Volume on Windows.
  ///   - df on Unix-like systems.
  ///
  /// Failure is represented as `known: false` rather than causing the
  /// storage status request to fail.
  Map<String, dynamic> _filesystemCapacity(String path) {
    if (path.trim().isEmpty) {
      return _unknownFilesystemCapacity();
    }

    try {
      if (Platform.isWindows) {
        return _windowsFilesystemCapacity(path);
      }

      return _unixFilesystemCapacity(path);
    } catch (_) {
      return _unknownFilesystemCapacity();
    }
  }

  Map<String, dynamic> _windowsFilesystemCapacity(String path) {
    final drive = _windowsDriveLetter(path);

    if (drive == null) {
      return _unknownFilesystemCapacity();
    }

    final command = '''
\$volume = Get-Volume -DriveLetter '$drive' -ErrorAction Stop
[PSCustomObject]@{
  Size = [int64]\$volume.Size
  SizeRemaining = [int64]\$volume.SizeRemaining
} | ConvertTo-Json -Compress
''';

    final result = Process.runSync(
      'powershell.exe',
      <String>[
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        command,
      ],
      runInShell: false,
    );

    if (result.exitCode != 0) {
      return _unknownFilesystemCapacity();
    }

    final output = result.stdout.toString().trim();

    if (output.isEmpty) {
      return _unknownFilesystemCapacity();
    }

    final decoded = jsonDecode(output);

    if (decoded is! Map) {
      return _unknownFilesystemCapacity();
    }

    final totalBytes = _nonNegativeInt(decoded['Size']);
    final freeBytes = _nonNegativeInt(decoded['SizeRemaining']);

    if (totalBytes == null || freeBytes == null || totalBytes == 0) {
      return _unknownFilesystemCapacity();
    }

    final normalizedFree = freeBytes > totalBytes ? totalBytes : freeBytes;
    final usedBytes = totalBytes - normalizedFree;

    return _knownFilesystemCapacity(
      totalBytes: totalBytes,
      freeBytes: normalizedFree,
      usedBytes: usedBytes,
    );
  }

  Map<String, dynamic> _unixFilesystemCapacity(String path) {
    final result = Process.runSync(
      'df',
      <String>[
        '-Pk',
        path,
      ],
      runInShell: false,
    );

    if (result.exitCode != 0) {
      return _unknownFilesystemCapacity();
    }

    final lines = result.stdout
        .toString()
        .trim()
        .split(RegExp(r'\r?\n'))
        .where((line) => line.trim().isNotEmpty)
        .toList();

    if (lines.length < 2) {
      return _unknownFilesystemCapacity();
    }

    // POSIX `df -P` guarantees a single filesystem record per line, with
    // whitespace-separated fields:
    // Filesystem  1024-blocks  Used  Available  Capacity  Mounted on
    //
    // Mount points may contain spaces, so only the first five fields are
    // relevant here.
    final fields = lines.last.trim().split(RegExp(r'\s+'));

    if (fields.length < 5) {
      return _unknownFilesystemCapacity();
    }

    final blocks = int.tryParse(fields[1]);
    final availableBlocks = int.tryParse(fields[3]);

    if (blocks == null || availableBlocks == null || blocks <= 0) {
      return _unknownFilesystemCapacity();
    }

    final totalBytes = blocks * 1024;
    final freeBytes = (availableBlocks * 1024).clamp(0, totalBytes);
    final usedBytes = totalBytes - freeBytes;

    return _knownFilesystemCapacity(
      totalBytes: totalBytes,
      freeBytes: freeBytes,
      usedBytes: usedBytes,
    );
  }

  String? _windowsDriveLetter(String path) {
    final match = RegExp(r'^[A-Za-z]:').firstMatch(path.trim());

    if (match == null) {
      return null;
    }

    return path.trim()[0].toUpperCase();
  }

  int? _nonNegativeInt(Object? value) {
    if (value is int) {
      return value < 0 ? 0 : value;
    }

    if (value is num) {
      final converted = value.toInt();
      return converted < 0 ? 0 : converted;
    }

    if (value is String) {
      final parsed = int.tryParse(value.trim());

      if (parsed == null) {
        return null;
      }

      return parsed < 0 ? 0 : parsed;
    }

    return null;
  }

  Map<String, dynamic> _knownFilesystemCapacity({
    required int totalBytes,
    required int freeBytes,
    required int usedBytes,
  }) {
    final normalizedTotal = totalBytes < 0 ? 0 : totalBytes;
    final normalizedFree = freeBytes.clamp(0, normalizedTotal);
    final normalizedUsed = usedBytes.clamp(0, normalizedTotal);

    return {
      'known': true,
      'totalBytes': normalizedTotal,
      'freeBytes': normalizedFree,
      'usedBytes': normalizedUsed,
      'usagePercent': normalizedTotal > 0
          ? ((normalizedUsed / normalizedTotal) * 100)
              .clamp(0, 100)
              .toDouble()
          : null,
      'freePercent': normalizedTotal > 0
          ? ((normalizedFree / normalizedTotal) * 100)
              .clamp(0, 100)
              .toDouble()
          : null,
    };
  }

  Map<String, dynamic> _unknownFilesystemCapacity() => {
        'known': false,
        'totalBytes': null,
        'freeBytes': null,
        'usedBytes': null,
        'usagePercent': null,
        'freePercent': null,
      };
}