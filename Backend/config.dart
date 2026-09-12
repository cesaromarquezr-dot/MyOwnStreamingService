// FILE: `Backend/config.dart`.
// Purpose: Implements the config portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'dart:io';

class AppConfig {
  // ---------------------------------------------------------------------------
  // SERVER
  // ---------------------------------------------------------------------------

  /// Bind address for the home server. Use 0.0.0.0 so LAN clients can connect.
  static String get host => Platform.environment['SERVER_HOST']?.trim().isNotEmpty == true ? Platform.environment['SERVER_HOST']!.trim() : '0.0.0.0';

  static const int port = 8080;

  static const String apiVersion =
      'v1';

  static String get baseUrl {
    return Platform.environment['SERVER_PUBLIC_URL']?.trim().isNotEmpty == true
        ? Platform.environment['SERVER_PUBLIC_URL']!.trim()
        : 'http://127.0.0.1:$port';
  }

  static String get apiBaseUrl {
    return '$baseUrl/api/$apiVersion';
  }

  // ARM
  // Set ARM_SERVER_URL in the backend environment to the ARM web UI,
  // for example http://192.168.1.50:8080.
  static String get armServerUrl =>
      Platform.environment['ARM_SERVER_URL']?.trim().isNotEmpty == true
          ? Platform.environment['ARM_SERVER_URL']!.trim()
          : 'http://127.0.0.1:8081';

  // ---------------------------------------------------------------------------
  // AUTHENTICATION
  // ---------------------------------------------------------------------------

  // Absolute lifetime of a normal login session.
  //
  // Later we can make this configurable per device/trust level.
  static const Duration sessionLifetime =
      Duration(days: 30);

  // Minimum password length for the first
  // authentication implementation.
  //
  // We will strengthen the password policy in
  // the next authentication pass.
  static const int minimumPasswordLength =
      6;

  /// Root directory containing server-managed media.
  static String get mediaRoot => Platform.environment['MEDIA_ROOT']?.trim().isNotEmpty == true ? Platform.environment['MEDIA_ROOT']!.trim() : './media';
  /// Default Movies capacity: 1 TB. Override with MOVIES_CAPACITY_BYTES.
  static int get moviesCapacityBytes => int.tryParse(Platform.environment['MOVIES_CAPACITY_BYTES'] ?? '') ?? 1000000000000;
  /// Default Series capacity: 5 TB. Override with SERIES_CAPACITY_BYTES.
  static int get seriesCapacityBytes => int.tryParse(Platform.environment['SERIES_CAPACITY_BYTES'] ?? '') ?? 5000000000000;
  /// Default Music capacity: 32 GB. Override with MUSIC_CAPACITY_BYTES.
  static int get musicCapacityBytes => int.tryParse(Platform.environment['MUSIC_CAPACITY_BYTES'] ?? '') ?? 32000000000;
  /// Default free/available pool shown by the dashboard: 20 TB.
  static int get availableStorageBytes => int.tryParse(Platform.environment['AVAILABLE_STORAGE_BYTES'] ?? '') ?? 20000000000000;
}
