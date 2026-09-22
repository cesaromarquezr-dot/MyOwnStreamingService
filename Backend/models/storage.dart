// FILE: Backend/models/storage.dart.
// Purpose: Data models for NAS storage pools, drives, backups, and UPS state.
//
// These are infrastructure status/read models. They describe the state
// reported by the host/NAS/storage provider; they do not themselves perform
// disk, RAID, backup, or UPS operations.

class StorageDriveStatus {
  final String id;
  final String device;
  final String model;
  final int capacityBytes;
  final String state;
  final bool healthy;
  final bool replaceable;

  const StorageDriveStatus({
    required this.id,
    required this.device,
    required this.model,
    required this.capacityBytes,
    required this.state,
    required this.healthy,
    required this.replaceable,
  });

  bool get isValid =>
      id.trim().isNotEmpty &&
      device.trim().isNotEmpty &&
      model.trim().isNotEmpty &&
      capacityBytes >= 0 &&
      state.trim().isNotEmpty;

  bool get hasCapacity => capacityBytes > 0;

  bool get needsReplacement => replaceable && !healthy;

  StorageDriveStatus copyWith({
    String? id,
    String? device,
    String? model,
    int? capacityBytes,
    String? state,
    bool? healthy,
    bool? replaceable,
  }) {
    return StorageDriveStatus(
      id: id ?? this.id,
      device: device ?? this.device,
      model: model ?? this.model,
      capacityBytes: capacityBytes ?? this.capacityBytes,
      state: state ?? this.state,
      healthy: healthy ?? this.healthy,
      replaceable: replaceable ?? this.replaceable,
    );
  }

  factory StorageDriveStatus.fromJson(Map<String, dynamic> json) {
    return StorageDriveStatus(
      id: _stringValue(json['id']),
      device: _stringValue(json['device']),
      model: _stringValue(json['model']),
      capacityBytes: _nonNegativeInt(json['capacityBytes']),
      state: _stringValue(json['state']),
      healthy: _boolValue(json['healthy']),
      replaceable: _boolValue(json['replaceable']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'device': device,
        'model': model,
        'capacityBytes': capacityBytes,
        'state': state,
        'healthy': healthy,
        'replaceable': replaceable,
      };

  @override
  String toString() {
    return 'StorageDriveStatus('
        'id: $id, '
        'device: $device, '
        'model: $model, '
        'capacityBytes: $capacityBytes, '
        'state: $state, '
        'healthy: $healthy, '
        'replaceable: $replaceable'
        ')';
  }
}

class StoragePoolStatus {
  final String name;
  final String raidLevel;
  final int driveCount;
  final int usableBytes;
  final int usedBytes;
  final String health;
  final bool rebuilding;

  /// Expected range is 0.0–1.0.
  final double rebuildProgress;

  final List<StorageDriveStatus> drives;

  const StoragePoolStatus({
    required this.name,
    required this.raidLevel,
    required this.driveCount,
    required this.usableBytes,
    required this.usedBytes,
    required this.health,
    required this.rebuilding,
    required this.rebuildProgress,
    required this.drives,
  });

  bool get isValid =>
      name.trim().isNotEmpty &&
      raidLevel.trim().isNotEmpty &&
      driveCount >= 0 &&
      usableBytes >= 0 &&
      usedBytes >= 0 &&
      health.trim().isNotEmpty &&
      rebuildProgress >= 0 &&
      rebuildProgress <= 1;

  int get normalizedUsedBytes {
    if (usableBytes <= 0) {
      return 0;
    }

    return usedBytes.clamp(0, usableBytes);
  }

  int get freeBytes {
    if (usableBytes <= 0) {
      return 0;
    }

    return (usableBytes - normalizedUsedBytes)
        .clamp(0, usableBytes);
  }

  double get usedPercent {
    if (usableBytes <= 0) {
      return 0;
    }

    return (normalizedUsedBytes / usableBytes * 100)
        .clamp(0.0, 100.0)
        .toDouble();
  }

  double get freePercent {
    if (usableBytes <= 0) {
      return 0;
    }

    return (freeBytes / usableBytes * 100)
        .clamp(0.0, 100.0)
        .toDouble();
  }

  bool get hasDrives => drives.isNotEmpty;

  int get healthyDriveCount =>
      drives.where((drive) => drive.healthy).length;

  int get replaceableDriveCount =>
      drives.where((drive) => drive.needsReplacement).length;

  bool get hasUnhealthyDrive =>
      drives.any((drive) => !drive.healthy);

  StoragePoolStatus copyWith({
    String? name,
    String? raidLevel,
    int? driveCount,
    int? usableBytes,
    int? usedBytes,
    String? health,
    bool? rebuilding,
    double? rebuildProgress,
    List<StorageDriveStatus>? drives,
  }) {
    return StoragePoolStatus(
      name: name ?? this.name,
      raidLevel: raidLevel ?? this.raidLevel,
      driveCount: driveCount ?? this.driveCount,
      usableBytes: usableBytes ?? this.usableBytes,
      usedBytes: usedBytes ?? this.usedBytes,
      health: health ?? this.health,
      rebuilding: rebuilding ?? this.rebuilding,
      rebuildProgress:
          _clampUnit(rebuildProgress ?? this.rebuildProgress),
      drives: List<StorageDriveStatus>.unmodifiable(
        drives ?? this.drives,
      ),
    );
  }

  factory StoragePoolStatus.fromJson(Map<String, dynamic> json) {
    final rawDrives = json['drives'];
    final parsedDrives = <StorageDriveStatus>[];

    if (rawDrives is List) {
      for (final value in rawDrives) {
        if (value is Map) {
          parsedDrives.add(
            StorageDriveStatus.fromJson(
              Map<String, dynamic>.from(value),
            ),
          );
        }
      }
    }

    return StoragePoolStatus(
      name: _stringValue(json['name']),
      raidLevel: _stringValue(json['raidLevel']),
      driveCount: _nonNegativeInt(json['driveCount']),
      usableBytes: _nonNegativeInt(json['usableBytes']),
      usedBytes: _nonNegativeInt(json['usedBytes']),
      health: _stringValue(json['health']),
      rebuilding: _boolValue(json['rebuilding']),
      rebuildProgress:
          _clampUnit(_doubleValue(json['rebuildProgress'])),
      drives: List<StorageDriveStatus>.unmodifiable(
        parsedDrives,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'raidLevel': raidLevel,
        'driveCount': driveCount,
        'usableBytes': usableBytes,
        'usedBytes': normalizedUsedBytes,
        'freeBytes': freeBytes,
        'health': health,
        'rebuilding': rebuilding,
        'rebuildProgress': rebuildProgress,
        'drives': drives.map((drive) => drive.toJson()).toList(),
      };

  @override
  String toString() {
    return 'StoragePoolStatus('
        'name: $name, '
        'raidLevel: $raidLevel, '
        'driveCount: $driveCount, '
        'usableBytes: $usableBytes, '
        'usedBytes: $normalizedUsedBytes, '
        'freeBytes: $freeBytes, '
        'health: $health, '
        'rebuilding: $rebuilding, '
        'rebuildProgress: $rebuildProgress, '
        'driveCountReported: ${drives.length}'
        ')';
  }
}

class BackupStatus {
  final bool configured;
  final String state;
  final DateTime? lastSuccessfulBackup;
  final String destination;

  const BackupStatus({
    required this.configured,
    required this.state,
    required this.lastSuccessfulBackup,
    required this.destination,
  });

  bool get isValid =>
      state.trim().isNotEmpty &&
      (!configured || destination.trim().isNotEmpty);

  bool get hasSuccessfulBackup =>
      lastSuccessfulBackup != null;

  bool get hasDestination =>
      destination.trim().isNotEmpty;

  bool get isHealthy {
    final normalized = state.trim().toLowerCase();

    return normalized == 'healthy' ||
        normalized == 'ready' ||
        normalized == 'success' ||
        normalized == 'successful' ||
        normalized == 'ok';
  }

  bool get isRunning {
    final normalized = state.trim().toLowerCase();

    return normalized == 'running' ||
        normalized == 'in_progress' ||
        normalized == 'in-progress' ||
        normalized == 'backing_up';
  }

  bool get hasFailure {
    final normalized = state.trim().toLowerCase();

    return normalized == 'failed' ||
        normalized == 'error' ||
        normalized == 'failure';
  }

  BackupStatus copyWith({
    bool? configured,
    String? state,
    DateTime? lastSuccessfulBackup,
    String? destination,
    bool clearLastSuccessfulBackup = false,
  }) {
    return BackupStatus(
      configured: configured ?? this.configured,
      state: state ?? this.state,
      lastSuccessfulBackup: clearLastSuccessfulBackup
          ? null
          : (lastSuccessfulBackup ?? this.lastSuccessfulBackup),
      destination: destination ?? this.destination,
    );
  }

  factory BackupStatus.fromJson(Map<String, dynamic> json) {
    return BackupStatus(
      configured: _boolValue(json['configured']),
      state: _stringValue(json['state']),
      lastSuccessfulBackup:
          _dateTimeValue(json['lastSuccessfulBackup']),
      destination: _stringValue(json['destination']),
    );
  }

  Map<String, dynamic> toJson() => {
        'configured': configured,
        'state': state,
        'lastSuccessfulBackup':
            lastSuccessfulBackup?.toIso8601String(),
        'destination': destination,
      };

  @override
  String toString() {
    return 'BackupStatus('
        'configured: $configured, '
        'state: $state, '
        'lastSuccessfulBackup: $lastSuccessfulBackup, '
        'hasDestination: $hasDestination'
        ')';
  }
}

class UpsStatus {
  final bool configured;
  final bool onBattery;
  final int batteryPercent;
  final int estimatedRuntimeSeconds;
  final String state;

  const UpsStatus({
    required this.configured,
    required this.onBattery,
    required this.batteryPercent,
    required this.estimatedRuntimeSeconds,
    required this.state,
  });

  bool get isValid =>
      batteryPercent >= 0 &&
      batteryPercent <= 100 &&
      estimatedRuntimeSeconds >= 0 &&
      state.trim().isNotEmpty;

  int get normalizedBatteryPercent =>
      batteryPercent.clamp(0, 100);

  bool get hasRuntimeEstimate =>
      estimatedRuntimeSeconds > 0;

  bool get isCharging {
    final normalized = state.trim().toLowerCase();

    return normalized == 'charging' ||
        normalized == 'online' ||
        normalized == 'line_power';
  }

  bool get isDischarging {
    final normalized = state.trim().toLowerCase();

    return onBattery ||
        normalized == 'discharging' ||
        normalized == 'on_battery';
  }

  bool get isCritical {
    final normalized = state.trim().toLowerCase();

    return normalized == 'critical' ||
        normalized == 'low' ||
        normalized == 'shutdown_pending' ||
        (isDischarging && normalizedBatteryPercent <= 10);
  }

  UpsStatus copyWith({
    bool? configured,
    bool? onBattery,
    int? batteryPercent,
    int? estimatedRuntimeSeconds,
    String? state,
  }) {
    return UpsStatus(
      configured: configured ?? this.configured,
      onBattery: onBattery ?? this.onBattery,
      batteryPercent:
          (batteryPercent ?? this.batteryPercent).clamp(0, 100),
      estimatedRuntimeSeconds:
          (estimatedRuntimeSeconds ?? this.estimatedRuntimeSeconds)
              .clamp(0, 9223372036854775807),
      state: state ?? this.state,
    );
  }

  factory UpsStatus.fromJson(Map<String, dynamic> json) {
    return UpsStatus(
      configured: _boolValue(json['configured']),
      onBattery: _boolValue(json['onBattery']),
      batteryPercent:
          _nonNegativeInt(json['batteryPercent']).clamp(0, 100),
      estimatedRuntimeSeconds:
          _nonNegativeInt(json['estimatedRuntimeSeconds']),
      state: _stringValue(json['state']),
    );
  }

  Map<String, dynamic> toJson() => {
        'configured': configured,
        'onBattery': onBattery,
        'batteryPercent': normalizedBatteryPercent,
        'estimatedRuntimeSeconds': estimatedRuntimeSeconds,
        'state': state,
      };

  @override
  String toString() {
    return 'UpsStatus('
        'configured: $configured, '
        'onBattery: $onBattery, '
        'batteryPercent: $normalizedBatteryPercent, '
        'estimatedRuntimeSeconds: $estimatedRuntimeSeconds, '
        'state: $state'
        ')';
  }
}

String _stringValue(
  dynamic value, {
  String fallback = '',
}) {
  if (value == null) {
    return fallback;
  }

  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

bool _boolValue(
  dynamic value, {
  bool fallback = false,
}) {
  if (value is bool) {
    return value;
  }

  if (value is num) {
    return value != 0;
  }

  if (value is String) {
    switch (value.trim().toLowerCase()) {
      case 'true':
      case '1':
      case 'yes':
      case 'y':
        return true;
      case 'false':
      case '0':
      case 'no':
      case 'n':
        return false;
    }
  }

  return fallback;
}

int _nonNegativeInt(
  dynamic value, {
  int fallback = 0,
}) {
  int? parsed;

  if (value is int) {
    parsed = value;
  } else if (value is num) {
    parsed = value.toInt();
  } else if (value is String) {
    parsed = int.tryParse(value.trim());
  }

  if (parsed == null || parsed < 0) {
    return fallback;
  }

  return parsed;
}

double _doubleValue(
  dynamic value, {
  double fallback = 0,
}) {
  if (value is num) {
    return value.toDouble();
  }

  if (value is String) {
    return double.tryParse(value.trim()) ?? fallback;
  }

  return fallback;
}

double _clampUnit(double value) {
  if (!value.isFinite) {
    return 0;
  }

  return value.clamp(0.0, 1.0).toDouble();
}

DateTime? _dateTimeValue(dynamic value) {
  if (value is DateTime) {
    return value;
  }

  if (value is String) {
    return DateTime.tryParse(value);
  }

  return null;
}