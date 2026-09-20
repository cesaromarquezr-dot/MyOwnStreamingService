// FILE: `Backend/self_hosting_security.dart`.
// Purpose: Enforces reverse-proxy, client-IP, CORS, rate-limit, and VPN-aware
// controls for production home-server deployments.

import 'dart:io';

import 'config.dart';

class SelfHostingSecurity {
  final Map<String, _RateWindow> _rateWindows = {};

  bool isTrustedProxy(HttpRequest request) =>
      _matchesAny(request.connectionInfo?.remoteAddress, AppConfig.trustedProxyCidrs);

  String clientIp(HttpRequest request) {
    final remote = request.connectionInfo?.remoteAddress.address ?? 'unknown';
    if (!isTrustedProxy(request)) return remote;
    final forwarded = request.headers.value('CF-Connecting-IP') ??
        request.headers.value('X-Real-IP');
    if (forwarded != null && _validIp(forwarded.trim())) return forwarded.trim();
    final xff = request.headers.value('X-Forwarded-For');
    if (xff != null) {
      final first = xff.split(',').first.trim();
      if (_validIp(first)) return first;
    }
    return remote;
  }

  bool proxyRequirementSatisfied(HttpRequest request) {
    if (!AppConfig.requireTrustedProxy) return true;
    if (!isTrustedProxy(request)) return false;
    final expected = AppConfig.proxySharedSecret;
    if (expected.isEmpty) return false;
    return request.headers.value('X-Streaming-Proxy-Key') == expected;
  }

  bool vpnAllowed(HttpRequest request) {
    if (AppConfig.vpnCidrs.isEmpty) return true;
    return _matchesAny(request.connectionInfo?.remoteAddress, AppConfig.vpnCidrs);
  }

  bool allowRate(String key) {
    final now = DateTime.now();
    final current = _rateWindows[key];
    if (current == null || now.difference(current.started).inMinutes >= 1) {
      _rateWindows[key] = _RateWindow(now, 1);
      return true;
    }
    if (current.count >= AppConfig.rateLimitPerMinute) return false;
    current.count++;
    return true;
  }

  static bool _validIp(String value) => InternetAddress.tryParse(value) != null;

  static bool _matchesAny(InternetAddress? address, List<String> cidrs) {
    if (address == null) return false;
    return cidrs.any((cidr) => _matchesCidr(address, cidr));
  }

  static bool _matchesCidr(InternetAddress address, String cidr) {
    final parts = cidr.split('/');
    final network = InternetAddress.tryParse(parts.first.trim());
    final prefix = int.tryParse(parts.length == 2 ? parts[1] : '') ??
        (network?.type == InternetAddressType.IPv6 ? 128 : 32);
    if (network == null || network.type != address.type) return false;
    final a = address.rawAddress;
    final n = network.rawAddress;
    final fullBytes = prefix ~/ 8;
    final remaining = prefix % 8;
    for (var i = 0; i < fullBytes; i++) {
      if (a[i] != n[i]) return false;
    }
    if (remaining == 0) return true;
    final mask = (0xFF << (8 - remaining)) & 0xFF;
    return (a[fullBytes] & mask) == (n[fullBytes] & mask);
  }
}

class _RateWindow {
  final DateTime started;
  int count;
  _RateWindow(this.started, this.count);
}
