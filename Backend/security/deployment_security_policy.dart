import 'dart:io';

/// Fail-closed checks for internet-facing production deployments.
///
/// This policy intentionally does not select or configure a firewall/WAF.
/// It ensures the backend refuses to start when required application-layer
/// deployment controls have not been configured explicitly.
class DeploymentSecurityPolicy {
  const DeploymentSecurityPolicy._();

  static List<String> productionIssues({
    required String publicUrl,
    required bool requireTrustedProxy,
    required String proxySharedSecret,
    required List<String> trustedProxyCidrs,
    required List<String> allowedOrigins,
    required bool allowedOriginsExplicitlyConfigured,
    required bool mockServicesEnabled,
  }) {
    final issues = <String>[];
    final uri = Uri.tryParse(publicUrl.trim());

    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        _isLoopbackHost(uri.host)) {
      issues.add('SERVER_PUBLIC_URL must be a valid HTTPS URL in production.');
    }

    if (!requireTrustedProxy) {
      issues.add(
        'REQUIRE_TRUSTED_PROXY=true is required in production so the API is not an unguarded public entry point.',
      );
    }

    if (proxySharedSecret.trim().length < 32) {
      issues.add('PROXY_SHARED_SECRET must contain at least 32 characters.');
    }

    if (trustedProxyCidrs.isEmpty ||
        trustedProxyCidrs.any((cidr) => !_isValidCidr(cidr))) {
      issues.add(
        'TRUSTED_PROXY_CIDRS must contain valid, narrowly scoped proxy IP/CIDR entries.',
      );
    }

    if (!allowedOriginsExplicitlyConfigured || allowedOrigins.isEmpty) {
      issues.add(
        'ALLOWED_ORIGINS must explicitly list the production web-app origins.',
      );
    }

    if (allowedOrigins.any((origin) => !_isExactHttpsOrigin(origin))) {
      issues.add(
        'ALLOWED_ORIGINS must use exact HTTPS origins; wildcards and HTTP origins are not permitted in production.',
      );
    }

    if (mockServicesEnabled) {
      issues.add(
        'Mock services must be disabled when APP_ENV=production.',
      );
    }

    return List<String>.unmodifiable(issues);
  }

  static bool _isExactHttpsOrigin(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.contains('*')) return false;

    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        _isLoopbackHost(uri.host) ||
        uri.path.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return false;
    }

    return true;
  }

  static bool _isLoopbackHost(String host) {
    final normalized = host.toLowerCase();
    return normalized == 'localhost' ||
        normalized == '127.0.0.1' ||
        normalized == '::1' ||
        normalized == '0.0.0.0';
  }

  static bool _isValidCidr(String value) {
    final parts = value.trim().split('/');
    if (parts.length > 2 || parts.first.isEmpty) return false;

    final address = InternetAddress.tryParse(parts.first.trim());
    if (address == null) return false;

    final maxPrefix = address.type == InternetAddressType.IPv4 ? 32 : 128;
    if (parts.length == 1) return true;

    final prefix = int.tryParse(parts[1].trim());
    if (prefix == null || prefix < 0 || prefix > maxPrefix) return false;
    // Refuse dangerously broad trust ranges. Proxy peers should be exact IPs
    // or narrowly scoped network ranges, never 0.0.0.0/0 or ::/0.
    final minimumSpecificity =
        address.type == InternetAddressType.IPv4 ? 16 : 32;
    return prefix >= minimumSpecificity;
  }
}
