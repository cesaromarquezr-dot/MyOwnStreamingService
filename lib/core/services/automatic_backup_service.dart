import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Creates local recovery snapshots for app preferences and customization.
///
/// A snapshot protects local UI/settings state (including Home hero choices,
/// item artwork selections and details-page customization) from loss when a
/// server becomes unavailable. It does not back up media files or remote
/// database rows; those require a backup on the server/database itself.
class AutomaticBackupService with WidgetsBindingObserver {
  AutomaticBackupService._();

  static final AutomaticBackupService instance = AutomaticBackupService._();

  static const Duration backupInterval = Duration(minutes: 12);
  static const Duration changeCheckInterval = Duration(seconds: 45);
  static const int maxArchiveSnapshots = 60;
  static const int schemaVersion = 1;
  static const String _enabledKey = 'moss_backup_auto_enabled';
  static const String _latestFileName = 'latest.json';

  final ValueNotifier<AutomaticBackupStatus> status =
      ValueNotifier<AutomaticBackupStatus>(
    const AutomaticBackupStatus(
      enabled: true,
      isBusy: false,
      backupCount: 0,
      message: 'Preparing local backup storage…',
    ),
  );

  SharedPreferences? _preferences;
  Directory? _directory;
  Timer? _backupTimer;
  Timer? _changeTimer;
  bool _initialized = false;
  bool _busy = false;
  String? _lastFingerprint;

  File? get _latestFile => _directory == null
      ? null
      : File('${_directory!.path}${Platform.pathSeparator}$_latestFileName');

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      _preferences = await SharedPreferences.getInstance();
      final support = await getApplicationSupportDirectory();
      _directory = Directory(
        '${support.path}${Platform.pathSeparator}MyOwnStreamingService'
        '${Platform.pathSeparator}automatic_backups',
      );
      await _directory!.create(recursive: true);
      final enabled = _preferences!.getBool(_enabledKey) ?? true;
      status.value = status.value.copyWith(
        enabled: enabled,
        message: enabled
            ? 'Automatic local backups are enabled.'
            : 'Automatic backups are paused.',
        directoryPath: _directory!.path,
      );
      WidgetsBinding.instance.addObserver(this);
      if (enabled) {
        // Capture current durable preferences immediately, then start the
        // interval and change-detection timers.
        await _writeSnapshot(archive: true, reason: 'startup');
        _startTimers();
      } else {
        await _refreshBackupCount();
      }
    } catch (error) {
      status.value = status.value.copyWith(
        message: 'Local backup storage could not be initialized: $error',
      );
      // Backups must never prevent the main app from starting.
    }
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = _preferences ??= await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
    status.value = status.value.copyWith(
      enabled: enabled,
      message: enabled
          ? 'Automatic local backups are enabled.'
          : 'Automatic backups are paused.',
    );
    if (enabled) {
      try {
        if (_directory == null) {
          final support = await getApplicationSupportDirectory();
          _directory = Directory(
            '${support.path}${Platform.pathSeparator}MyOwnStreamingService'
            '${Platform.pathSeparator}automatic_backups',
          );
          await _directory!.create(recursive: true);
        }
        await _writeSnapshot(archive: true, reason: 'enabled');
        _startTimers();
      } catch (error) {
        status.value = status.value.copyWith(
          message: 'Automatic backup could not start: $error',
        );
      }
    } else {
      _stopTimers();
    }
  }

  Future<void> backupNow() async {
    await initialize();
    if (_directory == null) {
      throw StateError('Local backup directory is unavailable.');
    }
    await _writeSnapshot(archive: true, reason: 'manual', force: true);
  }

  /// The most recent and retained interval snapshots, newest first.
  Future<List<AutomaticBackupRecord>> listBackups() async {
    await initialize();
    final directory = _directory;
    if (directory == null || !await directory.exists()) return const [];
    final records = <AutomaticBackupRecord>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File || !entity.path.toLowerCase().endsWith('.json')) {
        continue;
      }
      try {
        final decoded = await _decodeFile(entity);
        final snapshot = decoded['preferences'] as Map<String, dynamic>;
        records.add(AutomaticBackupRecord(
          filePath: entity.path,
          createdAt: DateTime.parse(decoded['createdAt'] as String).toLocal(),
          preferenceCount: snapshot.length,
          isLatest: entity.uri.pathSegments.last == _latestFileName,
          reason: decoded['reason']?.toString() ?? 'scheduled',
        ));
      } catch (_) {
        // Ignore partial/corrupt files in the list; keep the other snapshots
        // available so a failed write cannot hide older recovery points.
      }
    }
    records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return records;
  }

  Future<void> restoreBackup(String filePath) async {
    await initialize();
    final directory = _directory;
    final prefs = _preferences ??= await SharedPreferences.getInstance();
    if (directory == null) throw StateError('Backup storage is unavailable.');
    final file = File(filePath).absolute;
    if (file.parent.path != directory.absolute.path || !await file.exists()) {
      throw ArgumentError(
          'The selected backup is not in the local backup folder.');
    }
    final decoded = await _decodeFile(file);
    final saved = Map<String, dynamic>.from(
      decoded['preferences'] as Map<String, dynamic>,
    );

    // Roll back restorable preferences, but never remove credentials or this
    // service's own enable flag. Sensitive keys were excluded at backup time.
    for (final key in prefs.getKeys().toList(growable: false)) {
      if (_isRestorablePreferenceKey(key)) {
        await prefs.remove(key);
      }
    }
    for (final entry in saved.entries) {
      if (!_isRestorablePreferenceKey(entry.key)) continue;
      final value = entry.value;
      if (value is String) {
        await prefs.setString(entry.key, value);
      } else if (value is bool) {
        await prefs.setBool(entry.key, value);
      } else if (value is int) {
        await prefs.setInt(entry.key, value);
      } else if (value is double) {
        await prefs.setDouble(entry.key, value);
      } else if (value is List && value.every((item) => item is String)) {
        await prefs.setStringList(entry.key, value.cast<String>());
      }
    }

    _lastFingerprint = _fingerprint(_safePreferenceSnapshot());
    status.value = status.value.copyWith(
      lastBackupAt: DateTime.now(),
      message:
          'Settings restored. Restart the app to refresh all open screens.',
    );
    // Preserve the restored state as a new named recovery point and latest.
    await _writeSnapshot(archive: true, reason: 'restored', force: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!status.value.enabled) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_writeSnapshot(archive: true, reason: 'app_pause'));
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_writeSnapshot(archive: false, reason: 'resume'));
      _startTimers();
    }
  }

  void _startTimers() {
    _backupTimer?.cancel();
    _changeTimer?.cancel();
    if (!status.value.enabled || _directory == null) return;
    _backupTimer = Timer.periodic(backupInterval, (_) {
      unawaited(_writeSnapshot(archive: true, reason: 'scheduled'));
    });
    _changeTimer = Timer.periodic(changeCheckInterval, (_) async {
      if (_busy || !status.value.enabled) return;
      final fingerprint = _fingerprint(_safePreferenceSnapshot());
      if (_lastFingerprint != null && fingerprint != _lastFingerprint) {
        // Update the recovery point quickly after a customization changes,
        // without generating a timestamped archive every 45 seconds.
        await _writeSnapshot(archive: false, reason: 'changed');
      }
    });
  }

  void _stopTimers() {
    _backupTimer?.cancel();
    _backupTimer = null;
    _changeTimer?.cancel();
    _changeTimer = null;
  }

  Future<void> _writeSnapshot({
    required bool archive,
    required String reason,
    bool force = false,
  }) async {
    if (_busy || (!status.value.enabled && !force) || _directory == null) {
      return;
    }
    _busy = true;
    status.value = status.value.copyWith(isBusy: true);
    try {
      await _directory!.create(recursive: true);
      final preferences = _safePreferenceSnapshot();
      final createdAt = DateTime.now().toUtc();
      final base = <String, dynamic>{
        'schemaVersion': schemaVersion,
        'app': 'MyOwnStreamingService',
        'createdAt': createdAt.toIso8601String(),
        'reason': reason,
        'preferenceCount': preferences.length,
        'preferences': preferences,
      };
      final checksum = sha256.convert(utf8.encode(jsonEncode(base))).toString();
      final output = <String, dynamic>{...base, 'sha256': checksum};
      final encoded = const JsonEncoder.withIndent('  ').convert(output);
      final latest = _latestFile!;
      await _writeAtomically(latest, encoded);
      // Read the file back and validate the checksum before reporting success.
      await _decodeFile(latest);
      if (archive) {
        final stamp = createdAt.microsecondsSinceEpoch;
        final archived = File(
          '${_directory!.path}${Platform.pathSeparator}backup_$stamp.json',
        );
        await _writeAtomically(archived, encoded);
        await _decodeFile(archived);
        await _trimArchives();
      }
      _lastFingerprint = _fingerprint(preferences);
      status.value = status.value.copyWith(
        lastBackupAt: createdAt.toLocal(),
        backupCount: await _countBackups(),
        isBusy: false,
        message: archive
            ? 'Local backup completed (${reason.replaceAll('_', ' ')}).'
            : 'Latest local recovery point refreshed.',
        directoryPath: _directory!.path,
      );
    } catch (error) {
      status.value = status.value.copyWith(
        isBusy: false,
        message: 'Backup failed; previous snapshots were kept: $error',
      );
    } finally {
      _busy = false;
    }
  }

  Map<String, dynamic> _safePreferenceSnapshot() {
    final prefs = _preferences;
    if (prefs == null) return <String, dynamic>{};
    final result = <String, dynamic>{};
    final keys = prefs.getKeys().toList()..sort();
    for (final key in keys) {
      if (!_isRestorablePreferenceKey(key)) continue;
      final value = prefs.get(key);
      if (value == null) continue;
      if (value is String) {
        result[key] = _redactStructuredString(value);
      } else if (value is bool || value is int || value is double) {
        result[key] = value;
      } else if (value is List && value.every((item) => item is String)) {
        result[key] = value.cast<String>();
      }
    }
    return result;
  }

  String _redactStructuredString(String value) {
    final trimmed = value.trim();
    if (!(trimmed.startsWith('{') || trimmed.startsWith('['))) return value;
    try {
      final decoded = jsonDecode(value);
      final redacted = _redactJsonValue(decoded);
      return jsonEncode(redacted);
    } catch (_) {
      return value;
    }
  }

  dynamic _redactJsonValue(dynamic value) {
    if (value is Map) {
      final result = <String, dynamic>{};
      for (final entry in value.entries) {
        final key = entry.key.toString();
        if (_isSensitiveKey(key)) continue;
        result[key] = _redactJsonValue(entry.value);
      }
      return result;
    }
    if (value is List) return value.map(_redactJsonValue).toList();
    return value;
  }

  @visibleForTesting
  static bool isSensitivePreferenceKey(String key) => _isSensitiveKey(key);

  static bool _isSensitiveKey(String key) {
    final normalized = key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    const blockedFragments = <String>[
      'password',
      'passwd',
      'secret',
      'token',
      'apikey',
      'authorization',
      'credential',
      'privatekey',
      'clientsecret',
      'refreshkey',
      'jwt',
      'cookie',
      'supabaseauth',
      'sessionid',
    ];
    return blockedFragments.any(normalized.contains);
  }

  static bool _isRestorablePreferenceKey(String key) {
    if (key.startsWith('moss_backup_')) return false;
    if (key.startsWith('flutter_secure_storage')) return false;
    if (key.startsWith('flutter.')) return false;
    if (_isSensitiveKey(key)) return false;
    return true;
  }

  String _fingerprint(Map<String, dynamic> preferences) =>
      sha256.convert(utf8.encode(jsonEncode(preferences))).toString();

  Future<Map<String, dynamic>> _decodeFile(File file) async {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) throw const FormatException('Invalid backup format.');
    final map = Map<String, dynamic>.from(decoded);
    if (map['schemaVersion'] != schemaVersion ||
        map['app'] != 'MyOwnStreamingService' ||
        map['preferences'] is! Map ||
        map['sha256'] is! String) {
      throw const FormatException('Unsupported or incomplete backup.');
    }
    final base = <String, dynamic>{
      'schemaVersion': map['schemaVersion'],
      'app': map['app'],
      'createdAt': map['createdAt'],
      'reason': map['reason'],
      'preferenceCount': map['preferenceCount'],
      'preferences': map['preferences'],
    };
    final expected = sha256.convert(utf8.encode(jsonEncode(base))).toString();
    if (expected != map['sha256']) {
      throw const FormatException('Backup checksum validation failed.');
    }
    return map;
  }

  Future<void> _writeAtomically(File destination, String contents) async {
    final temp = File('${destination.path}.tmp');
    await temp.writeAsString(contents, flush: true);
    if (await destination.exists()) await destination.delete();
    await temp.rename(destination.path);
  }

  Future<int> _countBackups() async {
    final directory = _directory;
    if (directory == null || !await directory.exists()) return 0;
    var count = 0;
    await for (final item in directory.list(followLinks: false)) {
      if (item is File &&
          item.path.endsWith('.json') &&
          !item.path.endsWith(_latestFileName)) {
        count++;
      }
    }
    return count;
  }

  Future<void> _refreshBackupCount() async {
    status.value = status.value.copyWith(backupCount: await _countBackups());
  }

  Future<void> _trimArchives() async {
    final directory = _directory;
    if (directory == null) return;
    final files = <File>[];
    await for (final item in directory.list(followLinks: false)) {
      if (item is File &&
          item.path.split(Platform.pathSeparator).last.startsWith('backup_') &&
          item.path.endsWith('.json')) {
        files.add(item);
      }
    }
    files.sort((a, b) => b.path.compareTo(a.path));
    for (final old in files.skip(maxArchiveSnapshots)) {
      try {
        await old.delete();
      } catch (_) {
        // Cleanup failure does not invalidate the newly written backup.
      }
    }
  }
}

@immutable
class AutomaticBackupStatus {
  const AutomaticBackupStatus({
    required this.enabled,
    required this.isBusy,
    required this.backupCount,
    required this.message,
    this.lastBackupAt,
    this.directoryPath,
  });

  final bool enabled;
  final bool isBusy;
  final int backupCount;
  final String message;
  final DateTime? lastBackupAt;
  final String? directoryPath;

  AutomaticBackupStatus copyWith({
    bool? enabled,
    bool? isBusy,
    int? backupCount,
    String? message,
    DateTime? lastBackupAt,
    String? directoryPath,
  }) =>
      AutomaticBackupStatus(
        enabled: enabled ?? this.enabled,
        isBusy: isBusy ?? this.isBusy,
        backupCount: backupCount ?? this.backupCount,
        message: message ?? this.message,
        lastBackupAt: lastBackupAt ?? this.lastBackupAt,
        directoryPath: directoryPath ?? this.directoryPath,
      );
}

@immutable
class AutomaticBackupRecord {
  const AutomaticBackupRecord({
    required this.filePath,
    required this.createdAt,
    required this.preferenceCount,
    required this.isLatest,
    required this.reason,
  });

  final String filePath;
  final DateTime createdAt;
  final int preferenceCount;
  final bool isLatest;
  final String reason;
}
