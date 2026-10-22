import 'dart:io';

import '../database/database.dart';

/// Deterministic, read-only operational checks. Results contain no raw secret
/// values and never perform automatic remediation. Future scheduled workers
/// must reuse these checks and append every action to a durable audit store.
class OperationsBotService {
  final Database database;
  Map<String, dynamic>? _lastReport;

  OperationsBotService({required this.database});

  Map<String, dynamic> status() => <String, dynamic>{
        'success': true,
        'lastReport': _lastReport,
        'executionMode': 'on-demand-read-only',
        'supportsAutomaticRemediation': false,
      };

  Map<String, dynamic> runScan() {
    final now = DateTime.now().toUtc();
    final accounts = database.accountsById.values.toList(growable: false);
    final profiles = accounts.expand((account) => account.profiles).toList(growable: false);
    final profileIds = profiles.map((profile) => profile.id.trim()).where((id) => id.isNotEmpty).toList();
    final usernames = profiles
        .map((profile) => profile.username?.trim().replaceFirst(RegExp(r'^@'), '').toLowerCase() ?? '')
        .toList(growable: false);
    final namedUsernames = usernames.where((username) => username.isNotEmpty).toList(growable: false);
    final duplicateUsernameCount = namedUsernames.length - namedUsernames.toSet().length;
    final missingUsernameCount = usernames.where((username) => username.isEmpty).length;
    final duplicateProfileIdCount = profileIds.length - profileIds.toSet().length;

    final production = (Platform.environment['APP_ENV'] ?? '').toLowerCase() == 'production';
    final paymentMockEnabled = <String>['ARM_MOCK', 'FOOD_PAYMENT_MOCK']
        .any((key) => (Platform.environment[key] ?? '').trim().toLowerCase() == 'true');
    final mailConfigured = (Platform.environment['SMTP_HOST'] ?? '').trim().isNotEmpty ||
        (Platform.environment['EMAIL_PROVIDER_API_KEY'] ?? '').trim().isNotEmpty;
    final mediaAgentConfigured = (Platform.environment['MEDIA_AGENT_BASE_URL'] ?? '').trim().isNotEmpty &&
        (Platform.environment['MEDIA_AGENT_SHARED_SECRET'] ?? '').trim().isNotEmpty;
    final tlsDisabled = (Platform.environment['BACKEND_TLS_ENABLED'] ?? 'true').trim().toLowerCase() == 'false';

    final checks = <Map<String, dynamic>>[
      _check(
        id: 'profile_username_uniqueness',
        title: 'Profile username uniqueness',
        status: duplicateUsernameCount == 0 ? 'passed' : 'failed',
        severity: duplicateUsernameCount == 0 ? 'info' : 'high',
        details: duplicateUsernameCount == 0
            ? 'No duplicate normalized usernames were found among loaded profiles.'
            : '$duplicateUsernameCount duplicate normalized usernames were found among loaded profiles. The shared database unique constraint remains the final authority.',
      ),
      _check(
        id: 'profile_username_completeness',
        title: 'Profile username completeness',
        status: missingUsernameCount == 0 ? 'passed' : 'warning',
        severity: missingUsernameCount == 0 ? 'info' : 'medium',
        details: '$missingUsernameCount profiles have no public username. Review legacy profiles before public social features require one.',
      ),
      _check(
        id: 'profile_identity_integrity',
        title: 'Profile ID integrity',
        status: duplicateProfileIdCount == 0 ? 'passed' : 'failed',
        severity: duplicateProfileIdCount == 0 ? 'info' : 'critical',
        details: duplicateProfileIdCount == 0
            ? 'Profile IDs are unique in the currently loaded server account map.'
            : '$duplicateProfileIdCount duplicate profile IDs were found; do not auto-merge or delete records.',
      ),
      _check(
        id: 'production_mock_guard',
        title: 'Production mock integration guard',
        status: production && paymentMockEnabled ? 'failed' : (paymentMockEnabled ? 'warning' : 'passed'),
        severity: production && paymentMockEnabled ? 'critical' : (paymentMockEnabled ? 'medium' : 'info'),
        details: production && paymentMockEnabled
            ? 'A payment/ARM mock flag is enabled in production mode.'
            : paymentMockEnabled
                ? 'One or more development mock flags are enabled. Keep this environment isolated from production.'
                : 'No known payment/ARM mock flag is enabled.',
      ),
      _check(
        id: 'tls_mode',
        title: 'TLS termination mode',
        status: tlsDisabled ? 'warning' : 'passed',
        severity: tlsDisabled ? 'medium' : 'info',
        details: tlsDisabled
            ? 'Backend TLS is disabled. Use only behind a correctly configured trusted TLS-terminating proxy or on a private development interface.'
            : 'Backend TLS mode is enabled by configuration. This check does not validate the certificate chain or external proxy configuration.',
      ),
      _check(
        id: 'email_provider',
        title: 'Email delivery integration',
        status: mailConfigured ? 'passed' : 'not_configured',
        severity: 'low',
        details: mailConfigured
            ? 'An email provider configuration variable is present; delivery was not tested by this read-only scan.'
            : 'No supported SMTP/provider key is configured; email delivery cannot be confirmed.',
      ),
      _check(
        id: 'media_agent',
        title: 'Home media agent connection',
        status: mediaAgentConfigured ? 'passed' : 'not_configured',
        severity: 'low',
        details: mediaAgentConfigured
            ? 'The media agent endpoint and shared secret are configured; this scan does not expose either value or perform a connection test.'
            : 'The media agent endpoint/shared secret pair is not fully configured.',
      ),
      _check(
        id: 'backup_restore',
        title: 'Backup and restore readiness',
        status: 'manual_review',
        severity: 'medium',
        details: 'A real backup verification and restore drill require the configured storage provider and a disposable restore target; they are not inferred from configuration alone.',
      ),
    ];

    final summary = <String, int>{
      'passed': checks.where((check) => check['status'] == 'passed').length,
      'warning': checks.where((check) => check['status'] == 'warning' || check['status'] == 'not_configured' || check['status'] == 'manual_review').length,
      'failed': checks.where((check) => check['status'] == 'failed').length,
    };
    _lastReport = <String, dynamic>{
      'generatedAt': now.toIso8601String(),
      'accountCount': accounts.length,
      'profileCount': profiles.length,
      'summary': summary,
      'checks': checks,
      'executionMode': 'on-demand-read-only',
    };
    return <String, dynamic>{'success': true, ..._lastReport!};
  }

  Map<String, dynamic> _check({
    required String id,
    required String title,
    required String status,
    required String severity,
    required String details,
  }) => <String, dynamic>{
        'id': id,
        'title': title,
        'status': status,
        'severity': severity,
        'details': details,
      };
}
