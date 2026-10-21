import 'package:flutter/material.dart';
import 'backend_api.dart';
import 'app_core.dart';
import 'accessibility_offline_settings.dart';
import 'core/services/profile_governance_api.dart';
import 'localization.dart';
import 'security_settings.dart';
import 'self_hosting_settings.dart';
import 'storage_dashboard.dart';
import 'streaming_experience.dart';

class _HealthCheck {
  final String name;
  final String detail;
  final bool ok;
  const _HealthCheck(this.name, this.detail, this.ok);
}

/// Owner-only operator view. A successful API probe does not imply that every
/// underlying dependency or remote-client path has been production-certified.
class ProductionReadinessDashboardScreen extends StatefulWidget {
  const ProductionReadinessDashboardScreen({super.key});

  @override
  State<ProductionReadinessDashboardScreen> createState() =>
      _ProductionReadinessDashboardScreenState();
}

class _ProductionReadinessDashboardScreenState
    extends State<ProductionReadinessDashboardScreen> {
  bool loading = true;
  bool authorized = false;
  String? error;
  List<_HealthCheck> checks = const <_HealthCheck>[];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<_HealthCheck> _probe(
      String label, Future<Object?> Function() request) async {
    try {
      final result = await request();
      final summary = _summarize(result);
      var ok = true;
      if (result is Map) {
        if (result['success'] == false || result['ok'] == false) ok = false;
        final status = result['status']?.toString().toLowerCase();
        if (status != null &&
            const {'error', 'failed', 'unavailable', 'unhealthy'}
                .contains(status)) {
          ok = false;
        }
      }
      return _HealthCheck(label, summary, ok);
    } catch (e) {
      return _HealthCheck(
          label, e.toString().replaceFirst('Exception: ', ''), false);
    }
  }

  String _summarize(Object? value) {
    if (value is List) return '${value.length} item(s) returned';
    if (value is Map) {
      final success = value['success'];
      final status = value['status'];
      if (status != null) return 'Status: $status';
      if (success == false) return 'Service returned an unsuccessful response';
      return 'Authenticated endpoint responded';
    }
    return 'Endpoint responded';
  }

  Future<void> _refresh() async {
    setState(() {
      loading = true;
      error = null;
    });
    final controller = AppController.instance;
    if (!controller.backendApi.isAuthenticated ||
        controller.currentAccount == null) {
      if (!mounted) return;
      setState(() {
        loading = false;
        authorized = false;
        error =
            'Sign in with the account owner profile to view production health.';
      });
      return;
    }
    try {
      final capabilities =
          await ProfileGovernanceApi(controller.backendApi).getCapabilities();
      final isOwner = capabilities['isAccountOwner'] == true;
      if (!isOwner) {
        if (!mounted) return;
        setState(() {
          loading = false;
          authorized = false;
          error =
              'This dashboard is limited to the account owner. The backend must enforce the same authorization.';
        });
        return;
      }
      final results = await Future.wait<_HealthCheck>(<Future<_HealthCheck>>[
        _probe('Home-server storage API',
            () => controller.backendApi.getHomeServerStorage()),
        _probe('Media import / ARM API',
            () => controller.backendApi.getHomeServerArm()),
        _probe('Account membership API',
            () => controller.backendApi.getAccountMembers()),
      ]);
      if (!mounted) return;
      setState(() {
        authorized = true;
        checks = results;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        authorized = false;
        error = e.toString().replaceFirst('Exception: ', '');
        loading = false;
      });
    }
  }

  void _open(Widget page, String routeName) {
    Navigator.of(context).push<void>(MaterialPageRoute<void>(
      settings: RouteSettings(name: routeName),
      builder: (_) => page,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const UniversalText('Production Readiness'),
        actions: [
          IconButton(
              tooltip: 'Refresh health checks',
              onPressed: loading ? null : _refresh,
              icon: const Icon(Icons.refresh_rounded))
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : !authorized
              ? Center(
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.admin_panel_settings_outlined,
                            size: 48),
                        const SizedBox(height: 12),
                        Text(error ?? 'Owner authorization required',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                            onPressed: _refresh,
                            icon: const Icon(Icons.refresh),
                            label: const UniversalText('Try again'))
                      ])))
              : ListView(padding: const EdgeInsets.all(16), children: [
                  const Card(
                      child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                UniversalText('Service health',
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900)),
                                SizedBox(height: 6),
                                UniversalText(
                                    'These are authenticated endpoint probes, not a full host/NAS monitoring agent. Add metrics collection and alerting on the server for CPU, memory, disk, transcoding queue depth, certificates, and restore drills.'),
                              ]))),
                  const SizedBox(height: 10),
                  for (final check in checks)
                    Card(
                        child: ListTile(
                      leading: Icon(
                          check.ok
                              ? Icons.check_circle_outline
                              : Icons.error_outline,
                          color: check.ok
                              ? Colors.greenAccent
                              : Colors.orangeAccent),
                      title: Text(check.name),
                      subtitle: Text(check.detail,
                          maxLines: 3, overflow: TextOverflow.ellipsis),
                      trailing: Text(check.ok ? 'Responding' : 'Unavailable',
                          style: TextStyle(
                              color: check.ok
                                  ? Colors.greenAccent
                                  : Colors.orangeAccent,
                              fontSize: 12)),
                    )),
                  const SizedBox(height: 10),
                  const Card(
                      child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                UniversalText('Backup and recovery',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800)),
                                SizedBox(height: 6),
                                UniversalText(
                                    'Use scripts/production/backup.sh for an encrypted database + sanitized source snapshot, and scripts/production/restore_supabase.sh only for a verified recovery. TrueNAS ZFS snapshots must be configured and restore-tested separately.'),
                                SizedBox(height: 6),
                                UniversalText(
                                    'Never run a destructive restore against production without a verified backup, reviewed target URL, and explicit RESTORE confirmation.'),
                              ]))),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                      onPressed: () => _open(const SecuritySettingsScreen(),
                          '/app/page/security-privacy'),
                      icon: const Icon(Icons.security_rounded),
                      label: const UniversalText('Security & Privacy')),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                      onPressed: () => _open(
                          const StorageDashboardScreen(), '/app/page/storage'),
                      icon: const Icon(Icons.storage_rounded),
                      label: const UniversalText('Storage Dashboard')),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                      onPressed: () => _open(const SelfHostingSettingsScreen(),
                          '/app/page/self-hosting'),
                      icon: const Icon(Icons.dns_rounded),
                      label: const UniversalText('Self-hosting & Server')),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                      onPressed: () => _open(
                          const StreamingExperienceSettingsScreen(),
                          '/app/page/streaming-experience'),
                      icon: const Icon(Icons.high_quality_rounded),
                      label: const UniversalText('Streaming Experience')),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                      onPressed: () => _open(
                          const AccessibilityOfflineSettingsScreen(),
                          '/app/page/accessibility-offline'),
                      icon: const Icon(Icons.accessibility_new_rounded),
                      label: const UniversalText('Accessibility & Offline')),
                ]),
    );
  }
}
