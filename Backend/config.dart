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
  // SELF-HOSTING / REVERSE PROXY
  // ============================================================

  /// Public HTTPS URL users should use. Never expose the internal backend port.
  static String get publicUrl => baseUrl;

  /// When true, only the configured reverse proxy may reach the backend.
  static bool get requireTrustedProxy => _environmentBool('REQUIRE_TRUSTED_PROXY', false);

  /// Shared secret NGINX Proxy Manager adds as X-Streaming-Proxy-Key.
  static String get proxySharedSecret => Platform.environment['PROXY_SHARED_SECRET']?.trim() ?? '';

  /// CIDRs belonging to Cloudflare/NPM/private proxy networks.
  static List<String> get trustedProxyCidrs => _environmentList('TRUSTED_PROXY_CIDRS');

  /// CIDRs allowed to access endpoints marked VPN/private.
  static List<String> get vpnCidrs => _environmentList('VPN_CIDRS');

  /// Maximum requests per client IP per minute.
  static int get rateLimitPerMinute => _environmentInt('RATE_LIMIT_PER_MINUTE', 120);

  /// Whether Dart terminates TLS itself. Set false when NGINX Proxy Manager terminates TLS.
  static bool get backendTlsEnabled => _environmentBool('BACKEND_TLS_ENABLED', true);

  /// Allowed web origins. Use exact HTTPS origins in production; '*' is only for
  /// development and non-browser clients.
  static List<String> get allowedOrigins {
  final configured = _environmentList('ALLOWED_ORIGINS');

  if (configured.isNotEmpty) {
    return configured;
  }

  // Local Flutter Web development fallback.
  return <String>[
    'http://localhost',
    'http://127.0.0.1',
  ];
}

  /// DDNS hostname advertised by the home server.
  static String get ddnsHostname => Platform.environment['DDNS_HOSTNAME']?.trim() ?? '';

  /// DDNS provider name used by the deployment tooling.
  static String get ddnsProvider => Platform.environment['DDNS_PROVIDER']?.trim() ?? '';

  /// Public port exposed by the firewall/reverse proxy.
  static int get publicHttpsPort => _environmentInt('PUBLIC_HTTPS_PORT', 443);

  /// Internal backend port. This should not be port-forwarded from the router.
  static int get internalBackendPort => port;

  static List<String> _environmentList(String name) {
    final value = Platform.environment[name]?.trim() ?? '';
    if (value.isEmpty) return <String>[];
    return value.split(',').map((v) => v.trim()).where((v) => v.isNotEmpty).toList();
  }

  static bool _environmentBool(String name, bool defaultValue) {
    final value = Platform.environment[name]?.trim().toLowerCase();
    if (value == null || value.isEmpty) return defaultValue;
    return value == '1' || value == 'true' || value == 'yes';
  }

  // ============================================================
  // ARM SERVER URL
  // ============================================================

  // ============================================================
  // WORLDWIDE POSTAL CODE LOOKUP
  // ============================================================

  /// Optional GeoNames username used by the postal-code lookup route.
  /// The username stays on the backend and is never sent to Flutter.
  static String get geonamesUsername =>
      Platform.environment['GEONAMES_USERNAME']?.trim() ?? '';

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