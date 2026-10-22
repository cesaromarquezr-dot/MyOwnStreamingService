/// Endpoint-specific throttles layered on top of the backend's global IP
/// limit. Buckets are separate so login traffic cannot consume the recovery
/// budget, and all limits are still keyed by the resolved client IP.
class RequestRateLimitRule {
  const RequestRateLimitRule({required this.bucket, required this.perMinute});

  final String bucket;
  final int perMinute;
}

class RequestRateLimitPolicy {
  const RequestRateLimitPolicy._();

  static RequestRateLimitRule? forRequest({
    required String method,
    required String path,
    required int loginPerMinute,
    required int signupPerMinute,
    required int recoveryPerMinute,
    required int mfaPerMinute,
    required int sensitiveAccountPerMinute,
  }) {
    final verb = method.toUpperCase();

    if (verb == 'PATCH' && path.startsWith('/api/v1/profile-governance/')) {
      return RequestRateLimitRule(
        bucket: 'profile-governance',
        perMinute: sensitiveAccountPerMinute,
      );
    }

    if (verb != 'POST') return null;

    switch (path) {
      case '/api/v1/auth/login':
        return RequestRateLimitRule(
          bucket: 'auth-login',
          perMinute: loginPerMinute,
        );
      case '/api/v1/auth/signup':
      case '/api/v1/auth/invitations/accept':
        return RequestRateLimitRule(
          bucket: 'auth-signup',
          perMinute: signupPerMinute,
        );
      case '/api/v1/auth/oauth/exchange':
        return RequestRateLimitRule(
          bucket: 'auth-oauth-exchange',
          perMinute: loginPerMinute,
        );
      case '/api/v1/auth/password-recovery/question':
      case '/api/v1/auth/password-recovery/reset':
        return RequestRateLimitRule(
          bucket: 'auth-recovery',
          perMinute: recoveryPerMinute,
        );
      case '/api/v1/auth/mfa/verify-login':
      case '/api/v1/auth/mfa/verify':
      case '/api/v1/security/mfa/start':
      case '/api/v1/security/mfa/enroll':
      case '/api/v1/security/mfa/enroll/verify':
      case '/api/v1/security/mfa/verify':
      case '/api/v1/security/mfa/disable':
        return RequestRateLimitRule(
          bucket: 'auth-mfa',
          perMinute: mfaPerMinute,
        );
      case '/api/v1/security/password':
      case '/api/v1/security/sessions/revoke':
      case '/api/v1/auth/session/rotate':
      case '/api/v1/auth/logout-all':
        return RequestRateLimitRule(
          bucket: 'account-security',
          perMinute: sensitiveAccountPerMinute,
        );
    }

    return null;
  }
}
