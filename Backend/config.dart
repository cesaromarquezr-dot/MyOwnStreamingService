// FILE: `Backend/config.dart`.
// Purpose: Central configuration for the streaming service backend.
// This file is part of the documented Flutter/home-server architecture.

import 'dart:io';

class AppConfig {
  // ============================================================
  // SERVER
  // ============================================================

  static String get host =>
      Platform.environment['SERVER_HOST']?.trim().isNotEmpty == true
          ? Platform.environment['SERVER_HOST']!.trim()
          : '0.0.0.0';

  static const int port = 8080;

  // ============================================================
  // API VERSION
  // ============================================================

  static const String apiVersion = 'v1';

  // ============================================================
  // BASE URL
  // ============================================================

  static String get baseUrl {
    final configuredUrl =
        Platform.environment['SERVER_PUBLIC_URL']?.trim();

    if (configuredUrl != null && configuredUrl.isNotEmpty) {
      return configuredUrl;
    }

    // The backend is HTTPS.
    return 'https://127.0.0.1:$port';
  }

  // ============================================================
  // API BASE URL
  // ============================================================

  static String get apiBaseUrl => '$baseUrl/api/$apiVersion';

  // ============================================================
  // ARM SERVER URL
  // ============================================================

  static String get armServerUrl {
    final configuredUrl =
        Platform.environment['ARM_SERVER_URL']?.trim();

    if (configuredUrl != null && configuredUrl.isNotEmpty) {
      return configuredUrl;
    }

    // ARM uses the same HTTPS backend by default.
    return baseUrl;
  }

  // ============================================================
  // MEDIA STORAGE
  // ============================================================

  static String get mediaLibraryPath => mediaRoot;

  static String get mediaRoot {
    final configuredPath =
        Platform.environment['MEDIA_ROOT']?.trim();

    if (configuredPath != null && configuredPath.isNotEmpty) {
      return configuredPath;
    }

    // Default home-server media location.
    return 'media';
  }

  // ============================================================
  // STORAGE CAPACITIES
  // ============================================================

  static int get moviesCapacityBytes =>
      _environmentInt(
        'MOVIES_CAPACITY_BYTES',
        0,
      );

  static int get seriesCapacityBytes =>
      _environmentInt(
        'SERIES_CAPACITY_BYTES',
        0,
      );

  static int get musicCapacityBytes =>
      _environmentInt(
        'MUSIC_CAPACITY_BYTES',
        0,
      );

  static int get availableStorageBytes =>
      _environmentInt(
        'AVAILABLE_STORAGE_BYTES',
        0,
      );

  // ============================================================
  // ADDITIONAL STORAGE PRICING
  // ============================================================

  static double get additionalStoragePricePerTbUsd =>
      _environmentDouble(
        'ADDITIONAL_STORAGE_PRICE_PER_TB_USD',
        0.0,
      );

  // ============================================================
  // ENVIRONMENT HELPERS
  // ============================================================

  static int _environmentInt(
    String name,
    int defaultValue,
  ) {
    final value = Platform.environment[name]?.trim();

    if (value == null || value.isEmpty) {
      return defaultValue;
    }

    return int.tryParse(value) ?? defaultValue;
  }

  static double _environmentDouble(
    String name,
    double defaultValue,
  ) {
    final value = Platform.environment[name]?.trim();

    if (value == null || value.isEmpty) {
      return defaultValue;
    }

    return double.tryParse(value) ?? defaultValue;
  }
}