// FILE: `Backend/config.dart`.
// Purpose: Central configuration for the streaming service backend.
// This file is part of the documented Flutter/home-server architecture.
//
// Configuration is read from environment variables so deployment-specific
// values and secrets remain outside the application source code.

import 'dart:io';

class AppConfig {
// ============================================================
// SERVER
// ============================================================

static String get host {
final configured = Platform.environment['SERVER_HOST']?.trim();

if (configured != null && configured.isNotEmpty) {
  return configured;
}

return '0.0.0.0';

}

static const int port = 8080;

// ============================================================
// API VERSION
// ============================================================

static const String apiVersion = 'v1';

// ============================================================
// BASE URL
// ============================================================

/// Public base URL used to construct API URLs.
///
/// In production this should normally be the HTTPS hostname exposed by
/// Cloudflare/NGINX Proxy Manager rather than the internal Dart server.
static String get baseUrl {
final configured =
Platform.environment['SERVER_PUBLIC_URL']?.trim();

if (configured != null && configured.isNotEmpty) {
  return _normalizeBaseUrl(configured);
}

return 'https://127.0.0.1:$port';

}

/// API root, for example:
/// https://example.com/api/v1
static String get apiBaseUrl => '$baseUrl/api/$apiVersion';

// ============================================================
// SELF-HOSTING / REVERSE PROXY
// ============================================================

/// Public HTTPS URL users should use.
///
/// This is intentionally separate from the internal backend bind address.
static String get publicUrl => baseUrl;

/// When true, the backend requires the configured trusted-proxy checks.
static bool get requireTrustedProxy =>
_environmentBool(
'REQUIRE_TRUSTED_PROXY',
false,
);

/// Shared secret expected from the configured reverse proxy.
///
/// Never send this value to Flutter or include it in logs.
static String get proxySharedSecret =>
Platform.environment['PROXY_SHARED_SECRET']?.trim() ?? '';

/// CIDRs belonging to trusted proxy infrastructure such as:
///
/// Cloudflare -> NGINX Proxy Manager -> backend
///
/// These values must be configured to match the actual deployment.
static List<String> get trustedProxyCidrs =>
_environmentList('TRUSTED_PROXY_CIDRS');

/// CIDRs allowed to access endpoints marked as VPN/private.
static List<String> get vpnCidrs =>
_environmentList('VPN_CIDRS');

/// Maximum requests per client IP per minute.
static int get rateLimitPerMinute =>
_environmentInt(
'RATE_LIMIT_PER_MINUTE',
120,
min: 1,
max: 100000,
);

/// Whether Dart terminates TLS itself.
///
/// Set to false when NGINX Proxy Manager terminates public TLS and the
/// Dart backend receives internal HTTP traffic.
static bool get backendTlsEnabled =>
_environmentBool(
'BACKEND_TLS_ENABLED',
true,
);

/// Allowed browser origins.
///
/// Production deployments should use exact HTTPS origins. A wildcard
/// should only be used intentionally for development/non-browser clients.
static List<String> get allowedOrigins {
final configured = _environmentList('ALLOWED_ORIGINS');

if (configured.isNotEmpty) {
  return List.unmodifiable(configured);
}

// Local Flutter Web development fallback.
return const <String>[
  'http://localhost',
  'http://127.0.0.1',
];

}

/// DDNS hostname advertised by the home server.
static String get ddnsHostname =>
Platform.environment['DDNS_HOSTNAME']?.trim() ?? '';

/// DDNS provider name used by deployment tooling.
static String get ddnsProvider =>
Platform.environment['DDNS_PROVIDER']?.trim() ?? '';

/// Public HTTPS port exposed by the firewall/reverse proxy.
static int get publicHttpsPort =>
_environmentInt(
'PUBLIC_HTTPS_PORT',
443,
min: 1,
max: 65535,
);

/// Internal backend port.
///
/// This should not be port-forwarded directly from the router.
static int get internalBackendPort => port;

// ============================================================
// ARM SERVER
// ============================================================

/// URL of the authenticated ARM server.
///
/// ARM credentials remain backend-only.
static String get armServerUrl {
final configured =
Platform.environment['ARM_SERVER_URL']?.trim();

if (configured != null && configured.isNotEmpty) {
  return _normalizeBaseUrl(configured);
}

// ARM uses the same backend HTTPS endpoint by default.
return baseUrl;

}

// ============================================================
// WORLDWIDE POSTAL CODE LOOKUP
// ============================================================

/// Optional GeoNames username used by the postal-code lookup route.
///
/// The username remains on the backend and is never sent to Flutter.
static String get geonamesUsername =>
Platform.environment['GEONAMES_USERNAME']?.trim() ?? '';

// ============================================================
// MEDIA STORAGE
// ============================================================

/// Publicly named media-library path used by application services.
static String get mediaLibraryPath => mediaRoot;

/// Root directory containing managed media.
static String get mediaRoot {
final configured =
Platform.environment['MEDIA_ROOT']?.trim();

if (configured != null && configured.isNotEmpty) {
  return configured;
}

return 'media';

}

// ============================================================
// STORAGE CAPACITIES
// ============================================================

static int get moviesCapacityBytes =>
_environmentInt(
'MOVIES_CAPACITY_BYTES',
0,
min: 0,
);

static int get seriesCapacityBytes =>
_environmentInt(
'SERIES_CAPACITY_BYTES',
0,
min: 0,
);

static int get musicCapacityBytes =>
_environmentInt(
'MUSIC_CAPACITY_BYTES',
0,
min: 0,
);

static int get availableStorageBytes =>
_environmentInt(
'AVAILABLE_STORAGE_BYTES',
0,
min: 0,
);

// ============================================================
// ADDITIONAL STORAGE PRICING
// ============================================================

static double get additionalStoragePricePerTbUsd =>
_environmentDouble(
'ADDITIONAL_STORAGE_PRICE_PER_TB_USD',
0.0,
min: 0.0,
);

// ============================================================
// ENVIRONMENT HELPERS
// ============================================================

static List<String> _environmentList(String name) {
final value =
Platform.environment[name]?.trim() ?? '';

if (value.isEmpty) {
  return const <String>[];
}

return value
    .split(',')
    .map((value) => value.trim())
    .where((value) => value.isNotEmpty)
    .toList(growable: false);

}

static bool _environmentBool(
String name,
bool defaultValue,
) {
final value =
Platform.environment[name]?.trim().toLowerCase();

if (value == null || value.isEmpty) {
  return defaultValue;
}

switch (value) {
  case '1':
  case 'true':
  case 'yes':
  case 'on':
    return true;

  case '0':
  case 'false':
  case 'no':
  case 'off':
    return false;

  default:
    return defaultValue;
}

}

static int _environmentInt(
String name,
int defaultValue, {
int? min,
int? max,
}) {
final value =
Platform.environment[name]?.trim();

if (value == null || value.isEmpty) {
  return defaultValue;
}

final parsed = int.tryParse(value);

if (parsed == null) {
  return defaultValue;
}

if (min != null && parsed < min) {
  return defaultValue;
}

if (max != null && parsed > max) {
  return defaultValue;
}

return parsed;

}

static double _environmentDouble(
String name,
double defaultValue, {
double? min,
double? max,
}) {
final value =
Platform.environment[name]?.trim();

if (value == null || value.isEmpty) {
  return defaultValue;
}

final parsed = double.tryParse(value);

if (parsed == null || !parsed.isFinite) {
  return defaultValue;
}

if (min != null && parsed < min) {
  return defaultValue;
}

if (max != null && parsed > max) {
  return defaultValue;
}

return parsed;

}

// ============================================================
// URL NORMALIZATION
// ============================================================

static String _normalizeBaseUrl(String value) {
var normalized = value.trim();

while (normalized.endsWith('/')) {
  normalized = normalized.substring(
    0,
    normalized.length - 1,
  );
}

return normalized;

}
}