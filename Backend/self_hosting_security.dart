// FILE: `Backend/self_hosting_security.dart`.
// Purpose: Enforces reverse-proxy, client-IP, CORS, rate-limit, and VPN-aware
// controls for production home-server deployments.
//
// Trust model:
//
//   Internet
//      ↓
//   Cloudflare
//      ↓
//   Firewall
//      ↓
//   NGINX Proxy Manager
//      ↓
//   Dart backend
//
// Forwarded client-IP headers are trusted only when the immediate peer is
// inside AppConfig.trustedProxyCidrs.
//
// The backend must never treat arbitrary client-supplied forwarding headers
// as authoritative.

import 'dart:convert';
import 'dart:io';

import 'config.dart';

class SelfHostingSecurity {
SelfHostingSecurity({
DateTime Function()? clock,
}) : _clock = clock ?? DateTime.now;

final DateTime Function() _clock;

final Map<String, _RateWindow> _rateWindows = {};

static const int _maximumRateWindowEntries = 10000;

// ============================================================
// TRUSTED PROXY
// ============================================================

bool isTrustedProxy(HttpRequest request) {
final remote = request.connectionInfo?.remoteAddress;

return _matchesAny(
  remote,
  AppConfig.trustedProxyCidrs,
);

}

// ============================================================
// CLIENT IP
// ============================================================

/// Returns the client IP used for rate limiting and access controls.
///
/// Forwarded headers are accepted only when the immediate connection
/// originates from a configured trusted proxy.
String clientIp(HttpRequest request) {
final remote =
request.connectionInfo?.remoteAddress;

final remoteIp = remote?.address ?? 'unknown';

if (!_isUsableIp(remote)) {
  return remoteIp;
}

if (!isTrustedProxy(request)) {
  return remoteIp;
}

// Cloudflare supplies CF-Connecting-IP as the original client address.
final cloudflareIp =
    request.headers.value('CF-Connecting-IP')?.trim();

if (_validIp(cloudflareIp)) {
  return cloudflareIp!;
}

// NGINX commonly forwards the client address through X-Real-IP.
final realIp =
    request.headers.value('X-Real-IP')?.trim();

if (_validIp(realIp)) {
  return realIp!;
}

// Fall back to the first address in X-Forwarded-For.
//
// This is only trusted because the immediate peer has already been
// established as a trusted proxy.
final forwardedFor =
    request.headers.value('X-Forwarded-For');

if (forwardedFor != null) {
  final forwardedAddresses =
      forwardedFor
          .split(',')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty);

  for (final candidate in forwardedAddresses) {
    if (_validIp(candidate)) {
      return candidate;
    }
  }
}

return remoteIp;

}

// ============================================================
// REVERSE-PROXY REQUIREMENT
// ============================================================

/// Determines whether the request arrived through the configured
/// trusted reverse-proxy path.
///
/// When REQUIRE_TRUSTED_PROXY=false, the backend may be accessed directly.
/// This is useful for local development.
bool proxyRequirementSatisfied(HttpRequest request) {
if (!AppConfig.requireTrustedProxy) {
return true;
}

if (!isTrustedProxy(request)) {
  return false;
}

final expected =
    AppConfig.proxySharedSecret;

// A configured proxy secret is mandatory when trusted-proxy enforcement
// is enabled.
if (expected.isEmpty) {
  return false;
}

final supplied =
    request.headers.value('X-Streaming-Proxy-Key');

if (supplied == null || supplied.isEmpty) {
  return false;
}

return _constantTimeEquals(
  supplied,
  expected,
);

}

// ============================================================
// VPN ACCESS
// ============================================================

/// Determines whether the request's immediate peer belongs to the
/// configured VPN network.
///
/// This intentionally does not trust arbitrary X-Forwarded-For headers.
/// Private/VPN endpoints should either be reached directly from the
/// configured network or use a trusted proxy whose network policy is
/// explicitly modeled elsewhere.
bool vpnAllowed(HttpRequest request) {
final configuredCidrs =
AppConfig.vpnCidrs;

if (configuredCidrs.isEmpty) {
  return true;
}

final remote =
    request.connectionInfo?.remoteAddress;

return _matchesAny(
  remote,
  configuredCidrs,
);

}

// ============================================================
// RATE LIMITING
// ============================================================

/// Applies a fixed one-minute request window.
///
/// Returns false when the configured per-minute limit has been reached.
///
/// The map is deliberately bounded so an attacker cannot create an
/// unlimited number of rate-limit keys and consume process memory.
bool allowRate(String key) {
final normalizedKey =
key.trim().isEmpty ? 'unknown' : key.trim();

final now = _clock();

_removeExpiredWindows(now);

var current =
    _rateWindows[normalizedKey];

if (current == null ||
    now.difference(current.started).inSeconds >= 60) {
  current = _RateWindow(
    now,
    0,
  );

  if (_rateWindows.length >=
      _maximumRateWindowEntries) {
    _evictOldestWindow();
  }

  _rateWindows[normalizedKey] = current;
}

if (current.count >=
    AppConfig.rateLimitPerMinute) {
  return false;
}

current.count++;

return true;

}

/// Useful for tests and controlled shutdown/reconfiguration.
void clearRateLimits() {
_rateWindows.clear();
}

// ============================================================
// IP VALIDATION
// ============================================================

static bool _validIp(String? value) {
if (value == null || value.isEmpty) {
return false;
}

return InternetAddress.tryParse(value) != null;

}

static bool _isUsableIp(InternetAddress? address) {
if (address == null) {
return false;
}

return address.rawAddress.isNotEmpty;

}

// ============================================================
// CIDR MATCHING
// ============================================================

static bool _matchesAny(
InternetAddress? address,
List<String> cidrs,
) {
if (address == null) {
return false;
}

for (final cidr in cidrs) {
  if (_matchesCidr(address, cidr)) {
    return true;
  }
}

return false;

}

static bool _matchesCidr(
InternetAddress address,
String cidr,
) {
final value = cidr.trim();

if (value.isEmpty) {
  return false;
}

final parts = value.split('/');

if (parts.length > 2) {
  return false;
}

final network =
    InternetAddress.tryParse(
  parts.first.trim(),
);

if (network == null ||
    network.type != address.type) {
  return false;
}

final addressBytes =
    address.rawAddress;

final networkBytes =
    network.rawAddress;

if (addressBytes.length !=
    networkBytes.length) {
  return false;
}

final maxPrefix =
    address.type == InternetAddressType.IPv4
        ? 32
        : 128;

final prefix = parts.length == 2
    ? int.tryParse(parts[1].trim())
    : maxPrefix;

if (prefix == null ||
    prefix < 0 ||
    prefix > maxPrefix) {
  return false;
}

final fullBytes =
    prefix ~/ 8;

final remainingBits =
    prefix % 8;

for (var i = 0;
    i < fullBytes;
    i++) {
  if (addressBytes[i] !=
      networkBytes[i]) {
    return false;
  }
}

if (remainingBits == 0) {
  return true;
}

if (fullBytes >= addressBytes.length) {
  return false;
}

final mask =
    (0xFF << (8 - remainingBits)) & 0xFF;

return
    (addressBytes[fullBytes] & mask) ==
    (networkBytes[fullBytes] & mask);

}

// ============================================================
// CONSTANT-TIME SECRET COMPARISON
// ============================================================

static bool _constantTimeEquals(
String supplied,
String expected,
) {
final suppliedBytes =
utf8.encode(supplied);

final expectedBytes =
    utf8.encode(expected);

var difference =
    suppliedBytes.length ^
    expectedBytes.length;

final length =
    suppliedBytes.length >
            expectedBytes.length
        ? suppliedBytes.length
        : expectedBytes.length;

for (var i = 0;
    i < length;
    i++) {
  final a =
      i < suppliedBytes.length
          ? suppliedBytes[i]
          : 0;

  final b =
      i < expectedBytes.length
          ? expectedBytes[i]
          : 0;

  difference |= a ^ b;
}

return difference == 0;

}

// ============================================================
// RATE-WINDOW MEMORY MANAGEMENT
// ============================================================

void _removeExpiredWindows(
DateTime now,
) {
final expired = <String>[];

for (final entry
    in _rateWindows.entries) {
  if (now
          .difference(entry.value.started)
          .inSeconds >=
      60) {
    expired.add(entry.key);
  }
}

for (final key in expired) {
  _rateWindows.remove(key);
}

}

void _evictOldestWindow() {
if (_rateWindows.isEmpty) {
return;
}

String? oldestKey;
DateTime? oldestTime;

for (final entry
    in _rateWindows.entries) {
  if (oldestTime == null ||
      entry.value.started
          .isBefore(oldestTime)) {
    oldestKey = entry.key;
    oldestTime =
        entry.value.started;
  }
}

if (oldestKey != null) {
  _rateWindows.remove(oldestKey);
}

}
}

class _RateWindow {
final DateTime started;
int count;

_RateWindow(
this.started,
this.count,
);
}
