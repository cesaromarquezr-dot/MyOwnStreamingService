import 'dart:io';

import '../config.dart';
import 'backup_service.dart';
import '../supabase_store.dart';

/// Read-only, on-demand diagnostics. This is intentionally not a privileged
/// autonomous agent: checks report evidence and recommendations but never
/// disable accounts, mutate database rows, rotate secrets, or delete files.
class SecurityBotService {
  SecurityBotService({
    SupabaseStore? store,
    BackupService? backupService,
  })  : _store = store ?? SupabaseStore.instance,
        _backupService = backupService ?? const BackupService();

  final SupabaseStore _store;
  final BackupService _backupService;

  static final Map<String, List<Map<String, dynamic>>> _localAudit = {};
  static const int _maxLocalAuditEvents = 40;

  static const List<Map<String, dynamic>> botCatalog = [
    {
      'id': 'sentinel',
      'name': 'Sentinel Bot',
      'category': 'Authentication signals',
      'description': 'Summarizes recent failed sign-ins, MFA failures, recovery failures, and suspicious-login events.',
      'permissionLevel': 'observe',
      'mode': 'on_demand',
    },
    {
      'id': 'database_guardian',
      'name': 'Database Guardian',
      'category': 'Database connectivity',
      'description': 'Checks whether the configured Supabase service can answer a minimal read-only query.',
      'permissionLevel': 'observe',
      'mode': 'on_demand',
    },
    {
      'id': 'backup_verifier',
      'name': 'Backup & Recovery Bot',
      'category': 'Backup readiness',
      'description': 'Checks the configured backup destination and freshness marker. It does not perform or restore a backup.',
      'permissionLevel': 'observe',
      'mode': 'on_demand',
    },
    {
      'id': 'transport_guardian',
      'name': 'Transport & Rate-Limit Bot',
      'category': 'Network posture',
      'description': 'Reviews HTTPS/TLS or trusted-proxy configuration and the configured request-rate limit.',
      'permissionLevel': 'observe',
      'mode': 'on_demand',
    },
    {
      'id': 'vulnerability_watch',
      'name': 'Vulnerability Watch Bot',
      'category': 'Dependency scanning',
      'description': 'Displays a trusted external scanner status marker when configured; it does not execute a scanner from a web request.',
      'permissionLevel': 'recommend',
      'mode': 'external_scanner_status',
    },
    {
      'id': 'permission_auditor',
      'name': 'Database Permission Auditor',
      'category': 'Row-level security',
      'description': 'Guides an administrator through a read-only RLS/policy inventory; the SQL report must be run separately in Supabase.',
      'permissionLevel': 'recommend',
      'mode': 'manual_sql_audit',
    },
    {
      'id': 'ai_safety_guardian',
      'name': 'AI Safety Guardian',
      'category': 'AI action governance',
      'description': 'Highlights the need for server-side tool authorization and approvals. Full AI tool-call telemetry is not yet connected to this dashboard.',
      'permissionLevel': 'recommend',
      'mode': 'manual_review',
    },
  ];

  Future<Map<String, dynamic>> status({
    required String accountId,
    int auditLimit = 40,
  }) async {
    final eventsResult = await _loadAudit(accountId, limit: auditLimit);
    final events = eventsResult['events'] as List<Map<String, dynamic>>;
    Map<String, dynamic>? latestReport;
    if (events.isNotEmpty) {
      final metadata = events.first['metadata'];
      if (metadata is Map) {
        final rawReport = metadata['report'];
        if (rawReport is Map) {
          latestReport = Map<String, dynamic>.from(rawReport);
        }
      }
    }

    return {
      'success': true,
      'bots': botCatalog,
      'latestReport': latestReport,
      'auditEvents': events,
      'auditStorage': {
        'durable': eventsResult['durable'] == true,
        'source': eventsResult['source'],
        'message': eventsResult['message'],
      },
      'scanMode': 'on_demand_read_only',
      'automaticRemediationEnabled': false,
    };
  }

  Future<Map<String, dynamic>> runChecks({required String accountId}) async {
    final startedAt = DateTime.now().toUtc();
    final findings = <Map<String, dynamic>>[];

    await _checkAuthenticationSignals(findings, startedAt);
    await _checkDatabase(findings);
    await _checkBackup(findings);
    _checkTransport(findings);
    _checkRateLimit(findings);
    _checkVulnerabilityScanner(findings, startedAt);
    findings.add(_finding(
      id: 'rls_manual_review',
      botId: 'permission_auditor',
      severity: 'info',
      status: 'manual_review',
      title: 'RLS and table-policy inventory needs a separate SQL review',
      summary: 'The bot endpoint checks reachability but does not inspect pg_policies or automatically change row-level security policies.',
      recommendation: 'Run Backend/database/security_audit_readonly.sql in the Supabase SQL Editor using an administrator role. Review each result table-by-table; do not add broad policies just to make a warning disappear.',
    ));
    findings.add(_finding(
      id: 'ai_safety_review',
      botId: 'ai_safety_guardian',
      severity: 'info',
      status: 'manual_review',
      title: 'AI tool-action review remains separate',
      summary: 'This dashboard does not inspect every AI tool invocation or grant it permissions.',
      recommendation: 'Keep authorization in the backend for every tool. Require explicit approval for destructive or account-level actions, and connect tool-call audit events before treating this bot as automated coverage.',
    ));

    final counts = <String, int>{};
    for (final finding in findings) {
      final severity = finding['severity']?.toString() ?? 'info';
      counts[severity] = (counts[severity] ?? 0) + 1;
    }
    final overallStatus = SecurityBotPolicy.overallStatus(findings);
    final completedAt = DateTime.now().toUtc();
    final report = <String, dynamic>{
      'scanId': 'scan_${completedAt.microsecondsSinceEpoch}',
      'startedAt': startedAt.toIso8601String(),
      'completedAt': completedAt.toIso8601String(),
      'status': overallStatus,
      'findings': findings,
      'summary': {
        'total': findings.length,
        'critical': counts['critical'] ?? 0,
        'error': counts['error'] ?? 0,
        'warning': counts['warning'] ?? 0,
        'info': counts['info'] ?? 0,
      },
      'readOnly': true,
      'automaticRemediationEnabled': false,
    };

    var durable = false;
    String? persistenceError;
    if (_store.enabled) {
      try {
        await _store.recordSecurityEvent(
          accountId: accountId,
          eventType: 'security_bot_scan',
          metadata: {'report': report},
        );
        durable = true;
      } catch (_) {
        persistenceError = 'The scan completed, but its audit entry could not be persisted.';
      }
    } else {
      persistenceError = 'Supabase is not configured; this scan will be kept in memory only.';
    }

    final event = <String, dynamic>{
      'eventType': 'security_bot_scan',
      'createdAt': completedAt.toIso8601String(),
      'metadata': {'report': report},
      'durable': durable,
    };
    final history = _localAudit.putIfAbsent(accountId, () => <Map<String, dynamic>>[]);
    history.insert(0, event);
    if (history.length > _maxLocalAuditEvents) {
      history.removeRange(_maxLocalAuditEvents, history.length);
    }

    return {
      'success': true,
      'report': report,
      'auditStorage': {
        'durable': durable,
        'source': durable ? 'supabase_security_events' : 'process_memory',
        'message': persistenceError ?? 'Scan report saved to the backend security-event audit table.',
      },
    };
  }

  Future<void> _checkAuthenticationSignals(
    List<Map<String, dynamic>> findings,
    DateTime now,
  ) async {
    if (!_store.enabled) {
      findings.add(_finding(
        id: 'auth_signals_unavailable',
        botId: 'sentinel',
        severity: 'warning',
        status: 'not_configured',
        title: 'Authentication telemetry is unavailable',
        summary: 'Supabase is not configured, so the Sentinel Bot cannot query persisted authentication events.',
        recommendation: 'Configure Supabase persistence and apply the existing streaming_service.sql security-events schema. Existing backend rate limiting still applies independently.',
      ));
      return;
    }

    try {
      final signals = await _store.summarizeRecentSecuritySignals(
        since: now.subtract(const Duration(hours: 1)),
      );
      final failed = (signals['login_failed'] ?? 0) +
          (signals['mfa_login_failed'] ?? 0) +
          (signals['password_recovery_failed'] ?? 0);
      final suspicious = signals['suspicious_login'] ?? 0;
      final policy = SecurityBotPolicy.failedAuthenticationFinding(
        failedEvents: failed,
        suspiciousLoginEvents: suspicious,
      );
      final sampledEvents = signals['sampledEvents'] ?? 0;
      final sampleCapReached = sampledEvents >= 2000;
      final high = policy['severity'] == 'critical';
      final elevated = policy['severity'] == 'warning' || high || sampleCapReached;
      findings.add(_finding(
        id: 'auth_signals',
        botId: 'sentinel',
        severity: high ? 'critical' : elevated ? 'warning' : 'info',
        status: high ? 'critical' : elevated ? 'warning' : 'ok',
        title: high
            ? 'Elevated authentication-failure volume'
            : sampleCapReached
                ? 'Authentication event sample reached its cap'
                : elevated
                    ? 'Authentication activity deserves review'
                    : 'No configured anomaly threshold was exceeded',
        summary: 'Past hour: $failed failed sign-in/MFA/recovery events and $suspicious suspicious-login events across up to 2,000 recent security-event records. Counts are aggregated; account identifiers, IP values, and login metadata are not returned. A full sample may mean activity is higher than these counts.',
        recommendation: elevated || high
            ? 'Review the server security-event logs and current request throttling. This bot does not automatically block accounts or IP addresses.'
            : 'Keep monitoring enabled and investigate any correlated alerts from your proxy or identity provider.',
        evidence: {
          'windowMinutes': 60,
          'failedSignInMfaRecovery': failed,
          'suspiciousLogin': suspicious,
          'sampledEvents': sampledEvents,
          'sampleCapReached': sampleCapReached,
        },
      ));
    } catch (_) {
      findings.add(_finding(
        id: 'auth_signals_query_failed',
        botId: 'sentinel',
        severity: 'warning',
        status: 'unavailable',
        title: 'Authentication signals could not be queried',
        summary: 'The security-event query failed. The result is unknown, not a clean bill of health.',
        recommendation: 'Verify the security_events table and backend service-role connectivity. No automatic response was taken.',
      ));
    }
  }

  Future<void> _checkDatabase(List<Map<String, dynamic>> findings) async {
    if (!_store.enabled) {
      findings.add(_finding(
        id: 'database_not_configured',
        botId: 'database_guardian',
        severity: 'warning',
        status: 'not_configured',
        title: 'Supabase persistence is not configured',
        summary: 'The backend is operating without the configured Supabase store.',
        recommendation: 'Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in the backend environment. Never expose the service-role key to Flutter or logs.',
      ));
      return;
    }

    try {
      await _store.probeConnection();
      findings.add(_finding(
        id: 'database_connectivity',
        botId: 'database_guardian',
        severity: 'info',
        status: 'ok',
        title: 'Database connectivity check passed',
        summary: 'The backend performed a minimal read-only query successfully.',
        recommendation: 'This only verifies connectivity. It does not prove every RLS policy, schema, backup, or data relationship is correct; run the separate SQL permission audit before production changes.',
      ));
    } catch (_) {
      findings.add(_finding(
        id: 'database_connectivity_failed',
        botId: 'database_guardian',
        severity: 'error',
        status: 'failed',
        title: 'Database connectivity check failed',
        summary: 'The configured database did not answer the read-only health query.',
        recommendation: 'Check Supabase availability, schema migration state, network connectivity, and backend-only credentials. Do not paste secret keys into the issue report.',
      ));
    }
  }

  Future<void> _checkBackup(List<Map<String, dynamic>> findings) async {
    try {
      final status = await _backupService.status();
      findings.add(SecurityBotPolicy.backupFinding(status));
    } catch (_) {
      findings.add(_finding(
        id: 'backup_check_failed',
        botId: 'backup_verifier',
        severity: 'warning',
        status: 'unknown',
        title: 'Backup status could not be determined',
        summary: 'The read-only backup configuration check failed.',
        recommendation: 'Check BACKUP_DESTINATION and its permissions. A reachable destination does not prove the files are restorable; test restoration in an isolated environment.',
      ));
    }
  }

  void _checkTransport(List<Map<String, dynamic>> findings) {
    final tlsEnabled = AppConfig.backendTlsEnabled;
    final publicUrl = Platform.environment['SERVER_PUBLIC_URL']?.trim() ?? '';
    final publicUri = publicUrl.isEmpty ? null : Uri.tryParse(publicUrl);
    final advertisedHttps = publicUrl.isEmpty || publicUri?.scheme == 'https';
    final production = (Platform.environment['APP_ENV'] ?? '').trim().toLowerCase() == 'production';
    final publicUrlPresent = publicUrl.isNotEmpty;
    final trustedProxyReady = AppConfig.requireTrustedProxy &&
        AppConfig.proxySharedSecret.isNotEmpty &&
        AppConfig.trustedProxyCidrs.isNotEmpty;
    if (production && !publicUrlPresent) {
      findings.add(_finding(
        id: 'production_public_url_missing',
        botId: 'transport_guardian',
        severity: 'error',
        status: 'warning',
        title: 'Production public URL is not configured',
        summary: 'APP_ENV is production but SERVER_PUBLIC_URL is empty.',
        recommendation: 'Set SERVER_PUBLIC_URL to the real public HTTPS origin before exposing the service.',
      ));
    } else if (!advertisedHttps) {
      findings.add(_finding(
        id: 'public_url_not_https',
        botId: 'transport_guardian',
        severity: 'error',
        status: 'warning',
        title: 'Configured public URL is not HTTPS',
        summary: 'SERVER_PUBLIC_URL does not advertise an HTTPS URL.',
        recommendation: 'Use the public HTTPS origin, and verify TLS termination at the backend or trusted reverse proxy.',
      ));
    } else if (tlsEnabled || trustedProxyReady) {
      findings.add(_finding(
        id: 'transport_posture',
        botId: 'transport_guardian',
        severity: 'info',
        status: 'ok',
        title: tlsEnabled ? 'Backend TLS is configured' : 'Trusted-proxy checks are configured',
        summary: tlsEnabled
            ? 'BACKEND_TLS_ENABLED is on. This check verifies configuration only, not public certificate validity.'
            : 'TLS appears to be delegated to a trusted proxy with a shared secret and allowlisted proxy CIDRs.',
        recommendation: 'Verify the actual public endpoint certificate and firewall exposure during deployment validation.',
      ));
    } else {
      findings.add(_finding(
        id: 'transport_posture_warning',
        botId: 'transport_guardian',
        severity: 'error',
        status: 'warning',
        title: 'Transport termination needs review',
        summary: 'Backend TLS is disabled and the complete trusted-proxy requirement is not configured.',
        recommendation: 'Enable backend TLS or configure trusted proxy validation, including PROXY_SHARED_SECRET and TRUSTED_PROXY_CIDRS. Do not expose the internal backend port directly to the internet.',
      ));
    }
  }

  void _checkRateLimit(List<Map<String, dynamic>> findings) {
    final rate = AppConfig.rateLimitPerMinute;
    findings.add(_finding(
      id: 'request_rate_limit',
      botId: 'transport_guardian',
      severity: rate > 0 ? 'info' : 'error',
      status: rate > 0 ? 'ok' : 'failed',
      title: rate > 0 ? 'Request rate limiting has a positive configured threshold' : 'Request rate limit is invalid',
      summary: 'Configured global threshold: $rate requests per client per minute.',
      recommendation: 'Tune thresholds using real traffic and reverse-proxy behavior. Rate limits complement—not replace—authentication and route authorization.',
      evidence: {'requestsPerMinute': rate},
    ));
  }

  void _checkVulnerabilityScanner(
    List<Map<String, dynamic>> findings,
    DateTime now,
  ) {
    final rawTimestamp = Platform.environment['SECURITY_BOT_VULN_SCAN_LAST_SUCCESS']?.trim() ?? '';
    final state = Platform.environment['SECURITY_BOT_VULN_SCAN_STATE']?.trim().toLowerCase() ?? '';
    final timestamp = DateTime.tryParse(rawTimestamp)?.toUtc();
    if (timestamp == null || timestamp.isAfter(now) || !{'clean', 'findings', 'failed'}.contains(state)) {
      findings.add(_finding(
        id: 'dependency_scan_unconfigured',
        botId: 'vulnerability_watch',
        severity: 'warning',
        status: 'not_configured',
        title: 'No trusted dependency-scan result is configured',
        summary: 'Vulnerability Watch does not execute package scanners from an HTTP request.',
        recommendation: 'Run dependency scanning in CI or trusted host automation, then publish SECURITY_BOT_VULN_SCAN_LAST_SUCCESS and SECURITY_BOT_VULN_SCAN_STATE (clean, findings, or failed) into the backend environment.',
      ));
      return;
    }

    final age = now.difference(timestamp);
    final fresh = age <= const Duration(days: 7);
    final hasFindings = state != 'clean';
    findings.add(_finding(
      id: 'dependency_scan_status',
      botId: 'vulnerability_watch',
      severity: !fresh || state == 'failed' ? 'warning' : hasFindings ? 'warning' : 'info',
      status: !fresh ? 'stale' : state == 'clean' ? 'ok' : state,
      title: !fresh
          ? 'Dependency scan result is stale'
          : state == 'clean'
              ? 'Latest reported dependency scan was clean'
              : state == 'findings'
                  ? 'Dependency scan reports findings'
                  : 'Dependency scan failed',
      summary: 'Scanner status marker timestamp: ${timestamp.toIso8601String()}. This is a trusted deployment-provided marker, not an independently verified scan.',
      recommendation: state == 'clean' && fresh
          ? 'Keep the CI scanner running on every dependency change.'
          : 'Review the scanner report in the trusted CI system; patch vulnerable dependencies after testing.',
      evidence: {'state': state, 'ageHours': age.inHours},
    ));
  }

  Future<Map<String, dynamic>> _loadAudit(
    String accountId, {
    int limit = 40,
  }) async {
    final boundedLimit = limit.clamp(1, 100).toInt();
    if (_store.enabled) {
      try {
        final persisted = await _store.loadSecurityBotScanEvents(
          accountId: accountId,
          limit: boundedLimit,
        );
        return {
          'events': persisted,
          'durable': true,
          'source': 'supabase_security_events',
          'message': 'Audit history is stored in the backend security_events table.',
        };
      } catch (_) {
        // Prefer transparent fallback to a failed dashboard when persistence
        // is temporarily unavailable. The response clearly marks this local.
      }
    }
    return {
      'events': List<Map<String, dynamic>>.from(_localAudit[accountId] ?? const [])
          .take(boundedLimit)
          .toList(growable: false),
      'durable': false,
      'source': 'process_memory',
      'message': 'Audit history is in memory only and will be lost when the backend restarts.',
    };
  }

  static Map<String, dynamic> _finding({
    required String id,
    required String botId,
    required String severity,
    required String status,
    required String title,
    required String summary,
    required String recommendation,
    Map<String, dynamic> evidence = const {},
  }) {
    return {
      'id': id,
      'botId': botId,
      'severity': severity,
      'status': status,
      'title': title,
      'summary': summary,
      'recommendation': recommendation,
      if (evidence.isNotEmpty) 'evidence': evidence,
    };
  }
}

/// Pure policy helpers so threshold behavior is easy to regression-test.
class SecurityBotPolicy {
  static Map<String, dynamic> backupFinding(Map<String, dynamic> backup) {
    final state = (backup['state'] ?? 'unknown').toString();
    final freshness = backup['freshness'] is Map
        ? Map<String, dynamic>.from(backup['freshness'] as Map)
        : const <String, dynamic>{};
    final capacity = backup['capacity'] is Map
        ? Map<String, dynamic>.from(backup['capacity'] as Map)
        : const <String, dynamic>{};
    final reachable = backup['reachable'] == true;
    final configured = backup['configured'] == true;
    final usedPercent = (capacity['usedPercent'] as num?)?.toDouble();

    var severity = 'warning';
    var result = 'unknown';
    var title = 'Backup readiness is not confirmed';
    var summary = 'The backup status is incomplete.';
    var recommendation = 'Configure a backup destination and a trusted last-success marker, then test a restore in an isolated environment.';

    if (!configured) {
      result = 'not_configured';
      title = 'Backup destination is not configured';
      summary = 'No BACKUP_DESTINATION is configured for this backend.';
    } else if (!reachable || state == 'unreachable') {
      severity = 'error';
      result = 'unreachable';
      title = 'Backup destination is unreachable';
      summary = 'The configured backup path could not be reached.';
      recommendation = 'Restore destination access and confirm that a new backup completes. Do not treat RAID as a backup.';
    } else if (state == 'capacity_critical' || (usedPercent != null && usedPercent >= 95)) {
      severity = 'critical';
      result = 'capacity_critical';
      title = 'Backup destination is almost full';
      summary = 'Reported backup storage usage is at least 95%.';
      recommendation = 'Expand storage or adjust retention after checking recovery obligations. Never delete the only known-good backup automatically.';
    } else if (state == 'capacity_warning' || (usedPercent != null && usedPercent >= 85)) {
      severity = 'warning';
      result = 'capacity_warning';
      title = 'Backup storage capacity is getting low';
      summary = 'Reported backup storage usage is at least 85%.';
      recommendation = 'Review backup growth and approved retention before making space.';
    } else if (freshness['state'] == 'stale' || state == 'stale') {
      severity = 'error';
      result = 'stale';
      title = 'Latest backup marker is stale';
      summary = 'The last successful backup is older than the configured maximum age.';
      recommendation = 'Investigate the failed or missed backup job and create a verified new restore point.';
    } else if (freshness['state'] == 'fresh' && reachable && configured) {
      severity = 'info';
      result = 'ok';
      title = 'Backup destination and freshness marker look healthy';
      summary = 'The configured destination is reachable and its success marker is within the age threshold.';
      recommendation = 'Periodically restore a backup in an isolated environment; freshness alone does not prove recoverability.';
    } else {
      result = 'freshness_unknown';
      summary = 'The destination is reachable, but no reliable recent-success marker is available.';
    }

    return {
      'id': 'backup_readiness',
      'botId': 'backup_verifier',
      'severity': severity,
      'status': result,
      'title': title,
      'summary': summary,
      'recommendation': recommendation,
      'evidence': {
        'configured': configured,
        'reachable': reachable,
        'freshness': freshness['state'] ?? 'unknown',
        if (usedPercent != null) 'usedPercent': usedPercent,
        'raidIsNotBackup': backup['raidIsNotBackup'] == true,
      },
    };
  }

  static Map<String, dynamic> failedAuthenticationFinding({
    required int failedEvents,
    required int suspiciousLoginEvents,
  }) {
    final critical = failedEvents >= 50 || suspiciousLoginEvents >= 10;
    final warning = failedEvents >= 15 || suspiciousLoginEvents >= 4;
    return {
      'severity': critical ? 'critical' : warning ? 'warning' : 'info',
      'status': critical ? 'critical' : warning ? 'warning' : 'ok',
      'failedEvents': failedEvents,
      'suspiciousLoginEvents': suspiciousLoginEvents,
    };
  }

  /// Prevents informational but unfinished security reviews from being
  /// summarized as a clean bill of health.
  static String overallStatus(List<Map<String, dynamic>> findings) {
    if (findings.any((finding) => finding['severity'] == 'critical')) {
      return 'critical';
    }
    if (findings.any((finding) => finding['severity'] == 'error')) {
      return 'error';
    }
    if (findings.any((finding) => finding['severity'] == 'warning')) {
      return 'attention';
    }
    if (findings.any((finding) => finding['status'] == 'manual_review')) {
      return 'review_required';
    }
    return 'healthy';
  }
}
