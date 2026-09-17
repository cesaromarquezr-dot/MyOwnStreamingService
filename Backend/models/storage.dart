// FILE: Backend/models/storage.dart.
// Purpose: Data models for NAS storage pools, drives, backups, and UPS state.

class StorageDriveStatus {
  final String id;
  final String device;
  final String model;
  final int capacityBytes;
  final String state;
  final bool healthy;
  final bool replaceable;

  const StorageDriveStatus({required this.id, required this.device, required this.model, required this.capacityBytes, required this.state, required this.healthy, required this.replaceable});

  Map<String, dynamic> toJson() => {'id': id, 'device': device, 'model': model, 'capacityBytes': capacityBytes, 'state': state, 'healthy': healthy, 'replaceable': replaceable};
}

class StoragePoolStatus {
  final String name;
  final String raidLevel;
  final int driveCount;
  final int usableBytes;
  final int usedBytes;
  final String health;
  final bool rebuilding;
  final double rebuildProgress;
  final List<StorageDriveStatus> drives;

  const StoragePoolStatus({required this.name, required this.raidLevel, required this.driveCount, required this.usableBytes, required this.usedBytes, required this.health, required this.rebuilding, required this.rebuildProgress, required this.drives});

  int get freeBytes => (usableBytes - usedBytes).clamp(0, usableBytes);

  Map<String, dynamic> toJson() => {'name': name, 'raidLevel': raidLevel, 'driveCount': driveCount, 'usableBytes': usableBytes, 'usedBytes': usedBytes, 'freeBytes': freeBytes, 'health': health, 'rebuilding': rebuilding, 'rebuildProgress': rebuildProgress, 'drives': drives.map((d) => d.toJson()).toList()};
}

class BackupStatus {
  final bool configured;
  final String state;
  final DateTime? lastSuccessfulBackup;
  final String destination;

  const BackupStatus({required this.configured, required this.state, required this.lastSuccessfulBackup, required this.destination});

  Map<String, dynamic> toJson() => {'configured': configured, 'state': state, 'lastSuccessfulBackup': lastSuccessfulBackup?.toIso8601String(), 'destination': destination};
}

class UpsStatus {
  final bool configured;
  final bool onBattery;
  final int batteryPercent;
  final int estimatedRuntimeSeconds;
  final String state;

  const UpsStatus({required this.configured, required this.onBattery, required this.batteryPercent, required this.estimatedRuntimeSeconds, required this.state});

  Map<String, dynamic> toJson() => {'configured': configured, 'onBattery': onBattery, 'batteryPercent': batteryPercent, 'estimatedRuntimeSeconds': estimatedRuntimeSeconds, 'state': state};
}
