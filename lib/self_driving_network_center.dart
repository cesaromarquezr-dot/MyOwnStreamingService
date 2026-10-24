// Live overview and controls for the app's self-driving API network layer.
import 'package:flutter/material.dart';

import 'backend_api.dart';
import 'core/services/self_driving_network_engine.dart';

class SelfDrivingNetworkCenterScreen extends StatefulWidget {
  const SelfDrivingNetworkCenterScreen({super.key});

  @override
  State<SelfDrivingNetworkCenterScreen> createState() =>
      _SelfDrivingNetworkCenterScreenState();
}

class _SelfDrivingNetworkCenterScreenState
    extends State<SelfDrivingNetworkCenterScreen> {
  final SelfDrivingNetworkMonitor _monitor = SelfDrivingNetworkMonitor.instance;
  bool _checkingBackend = false;
  String _probeMessage = 'No backend probe run in this session.';
  bool? _backendOnline;
  final TextEditingController _diagnosticController = TextEditingController();
  String _diagnosticAnswer =
      'Ask a question about latency, security, traffic routing, or prediction. The first version analyzes local metrics only.';

  @override
  void initState() {
    super.initState();
    _monitor.initialize();
  }

  Future<void> _checkBackend() async {
    setState(() {
      _checkingBackend = true;
      _probeMessage = 'Checking the configured backend health endpoint…';
      _backendOnline = null;
    });
    try {
      final result = await BackendApi().checkBackendHealth();
      if (!mounted) return;
      final online = result['success'] == true &&
          (result['status'] == null || result['status'] == 'online');
      setState(() {
        _backendOnline = online;
        _probeMessage = online
            ? 'Backend replied successfully at ${DateTime.now().toLocal().toString().substring(0, 19)}.'
            : 'The backend replied, but did not report a healthy status.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _backendOnline = false;
        _probeMessage = 'Backend probe failed: ${_safeError(error)}';
      });
    } finally {
      if (mounted) setState(() => _checkingBackend = false);
    }
  }

  String _safeError(Object error) {
    final value = error.toString();
    // Avoid exposing request URLs or query parameters in the status panel.
    if (value.contains('://')) return 'connection unavailable or timed out';
    return value.length > 140 ? '${value.substring(0, 137)}…' : value;
  }

  @override
  void dispose() {
    _diagnosticController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Self-Driving Network'),
        actions: [
          IconButton(
            tooltip: 'Clear local network history',
            onPressed: _monitor.clearHistory,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _monitor,
        builder: (context, _) {
          final p95 = _monitor.p95LatencyMs;
          final p50 = _monitor.medianLatencyMs;
          final firstLatency = _monitor.firstObservedHostConnectionLatencyMs;
          final samples = _monitor.samples.take(12).toList(growable: false);
          final state = _monitor.healthLabel;
          final stateColor = switch (state) {
            'Healthy' => Colors.green,
            'Degraded' => Colors.orange,
            'Critical' => theme.colorScheme.error,
            _ => theme.colorScheme.secondary,
          };
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: stateColor.withValues(alpha: 0.14),
                            foregroundColor: stateColor,
                            child: const Icon(Icons.hub_outlined),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Network state',
                                    style: theme.textTheme.titleMedium),
                                Text(
                                  state,
                                  style:
                                      theme.textTheme.headlineSmall?.copyWith(
                                    color: stateColor,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.auto_awesome,
                              color: theme.colorScheme.primary, size: 30),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'The app learns from the shared app network client, measures time to response headers, and automatically retries only safe GET/HEAD requests after selected transient failures. Backend APIs, food-service APIs, and the public TV playlist contribute when used; offline-download connections contribute header metrics without the API retry policy. Supabase and third-party player traffic are outside this monitor. Metrics are kept locally in memory.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Text('Trend: ${_monitor.trendLabel}',
                          style: theme.textTheme.labelLarge),
                      const SizedBox(height: 16),
                      Text('Operating mode', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<NetworkAutomationMode>(
                        initialValue: _monitor.mode,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.tune_rounded),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: NetworkAutomationMode.automatic,
                            child: Text(
                                'Automatic — adapt timeouts and safe retries'),
                          ),
                          DropdownMenuItem(
                            value: NetworkAutomationMode.observeOnly,
                            child: Text('Observe only — measure, do not retry'),
                          ),
                          DropdownMenuItem(
                            value: NetworkAutomationMode.paused,
                            child:
                                Text('Paused — stop collecting local samples'),
                          ),
                        ],
                        onChanged: (mode) {
                          if (mode != null) _monitor.setMode(mode);
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _modeDescription(_monitor.mode),
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                      Text('Intent-based policy',
                          style: theme.textTheme.titleSmall),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<NetworkIntentProfile>(
                        initialValue: _monitor.intentProfile,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.route_rounded),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: NetworkIntentProfile.balanced,
                            child: Text('Balanced — default response policy'),
                          ),
                          DropdownMenuItem(
                            value: NetworkIntentProfile.streamingPriority,
                            child: Text(
                                'Streaming priority — more response headroom'),
                          ),
                          DropdownMenuItem(
                            value: NetworkIntentProfile.lowLatency,
                            child: Text(
                                'Low latency — fail faster within safe bounds'),
                          ),
                        ],
                        onChanged: (profile) {
                          if (profile != null) {
                            _monitor.setIntentProfile(profile);
                          }
                        },
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _monitor.intentDescription,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: MediaQuery.sizeOf(context).width >= 760 ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.55,
                children: [
                  _MetricCard(
                      label: 'HTTP attempts observed',
                      value: '${_monitor.requestsObserved}',
                      icon: Icons.swap_horiz_rounded),
                  _MetricCard(
                      label: 'Safe retries',
                      value: '${_monitor.retryAttempts}',
                      icon: Icons.replay_rounded),
                  _MetricCard(
                      label: 'Transient failures',
                      value: '${_monitor.transientFailures}',
                      icon: Icons.warning_amber_rounded),
                  _MetricCard(
                      label: 'Timeouts',
                      value: '${_monitor.timeouts}',
                      icon: Icons.timer_off_outlined),
                  _MetricCard(
                      label: 'P50 header latency',
                      value: p50 == null ? '—' : '${p50.round()} ms',
                      icon: Icons.speed_rounded),
                  _MetricCard(
                      label: 'P95 header latency',
                      value: p95 == null ? '—' : '${p95.round()} ms',
                      icon: Icons.show_chart_rounded),
                  _MetricCard(
                      label: 'Avg first-host response latency',
                      value: firstLatency == null
                          ? 'Learning'
                          : '$firstLatency ms',
                      icon: Icons.bolt_rounded),
                  _MetricCard(
                      label: 'Slow responses (last 30)',
                      value: '${_monitor.slowRequestCount}',
                      icon: Icons.hourglass_bottom_rounded),
                  _MetricCard(
                      label: 'Recent failures',
                      value: '${(_monitor.recentFailureRate * 100).round()}%',
                      icon: Icons.monitor_heart_outlined),
                  _MetricCard(
                      label: 'Retry suppression',
                      value: '${_monitor.activeRetrySuppressions} host(s)',
                      icon: Icons.shield_outlined),
                  _MetricCard(
                      label: 'Burst hosts detected',
                      value: '${_monitor.detectedBurstHosts}',
                      icon: Icons.security_rounded),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Network operations assistant',
                          style: theme.textTheme.titleLarge),
                      const SizedBox(height: 6),
                      Text(
                        'Ask in ordinary language. This privacy-preserving first version answers from local telemetry using deterministic diagnostics; no question, token, or request payload is sent to an LLM service.',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _diagnosticController,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (value) => setState(
                            () => _diagnosticAnswer = _monitor.diagnose(value)),
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          hintText: 'Example: why is latency rising?',
                          prefixIcon: const Icon(Icons.forum_outlined),
                          suffixIcon: IconButton(
                            tooltip: 'Analyze local network metrics',
                            onPressed: () => setState(() => _diagnosticAnswer =
                                _monitor.diagnose(_diagnosticController.text)),
                            icon: const Icon(Icons.search_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(_diagnosticAnswer),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                      child: Text('Adaptive security and Zero Trust',
                          style: theme.textTheme.titleLarge)),
                  Text('${_monitor.securityEvents.length} events',
                      style: theme.textTheme.labelMedium),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'The local guard detects unusual outbound request bursts and repeated host failures. It only applies bounded delay to safe reads; it does not inspect credentials, block user accounts, or claim to stop inbound DDoS attacks.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              if (_monitor.securityEvents.isEmpty)
                const Card(
                    child: ListTile(
                        leading: Icon(Icons.verified_user_outlined),
                        title: Text('No local network security events'),
                        subtitle: Text(
                            'Events appear when an outbound burst or repeated transient failure crosses the local threshold.')))
              else
                for (final event in _monitor.securityEvents.take(5))
                  Card(
                    child: ListTile(
                      leading: Icon(
                        event.severity == NetworkEventSeverity.critical
                            ? Icons.gpp_bad_outlined
                            : Icons.shield_outlined,
                        color: event.severity == NetworkEventSeverity.critical
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary,
                      ),
                      title: Text(event.title),
                      subtitle: Text(
                          '${event.host} · ${event.details}\nAction: ${event.action}'),
                      isThreeLine: true,
                      trailing: Text(
                          '${event.at.toLocal().hour.toString().padLeft(2, '0')}:${event.at.toLocal().minute.toString().padLeft(2, '0')}',
                          style: theme.textTheme.labelSmall),
                    ),
                  ),
              const SizedBox(height: 16),
              Text('Enterprise capability readiness',
                  style: theme.textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                'These labels intentionally separate application features from enterprise WLAN features that require an authorized network controller or identity integration.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              _CapabilityCard(
                icon: Icons.verified_user_outlined,
                title: 'Zero Trust transport posture',
                status: 'PARTIAL',
                detail:
                    'The app enforces secure backend URL policy and stores its session token in secure storage. Device posture, continuous identity checks, and policy-based access denial need backend identity integration.',
              ),
              _CapabilityCard(
                icon: Icons.security_outlined,
                title: 'Burst detection and local protection',
                status: _monitor.mode == NetworkAutomationMode.automatic
                    ? 'ACTIVE'
                    : 'OBSERVE / PAUSED',
                detail:
                    'Detects sustained outbound request bursts and repeated transient failures; automatic mode slows safe reads and suppresses retry storms within bounded limits.',
              ),
              _CapabilityCard(
                icon: Icons.insights_outlined,
                title: 'Telemetry and experience latency',
                status: 'ACTIVE',
                detail:
                    'Tracks per-host response-header samples, P50/P95 latency, first observed successful host latency, failure rate, timeouts, and slow responses. It does not measure Wi-Fi association or third-party player buffering.',
              ),
              _CapabilityCard(
                icon: Icons.auto_graph_rounded,
                title: 'Predictive analytics',
                status: 'HEURISTIC',
                detail:
                    'Raises deterministic trend signals from rolling median and error rates. A trained ML/LLM inference provider is not connected yet.',
              ),
              _CapabilityCard(
                icon: Icons.hub_outlined,
                title: 'Intent-based networking',
                status: 'APP LEVEL',
                detail:
                    'Balanced, Streaming Priority, and Low Latency intents adjust bounded response-header timeout policy. They do not reserve router bandwidth or configure a switch.',
              ),
              _CapabilityCard(
                icon: Icons.cable_outlined,
                title: 'Inline wired/wireless microsegmentation',
                status: 'CONTROLLER REQUIRED',
                detail:
                    'Needs a managed gateway or network-controller API to apply consistent wired/wireless access policies. No such controller is configured in this project.',
              ),
              _CapabilityCard(
                icon: Icons.router_outlined,
                title: 'Rogue DHCP protection and dynamic DFS',
                status: 'ACCESS POINT REQUIRED',
                detail:
                    'Requires network-side DHCP/RF telemetry and authorized access-point controls. A mobile/desktop app HTTP client cannot see rogue DHCP offers or change radio channels.',
              ),
              _CapabilityCard(
                icon: Icons.wifi_tethering_rounded,
                title: 'OpenRoaming integration',
                status: 'IDENTITY PROVIDER REQUIRED',
                detail:
                    'Requires a participating roaming federation, operator credentials, and supported OS/network provisioning. It cannot be enabled solely by an app-side HTTP patch.',
              ),
              _CapabilityCard(
                icon: Icons.alt_route_rounded,
                title: 'Dynamic traffic engineering / failover',
                status: 'APPROVED ENDPOINTS REQUIRED',
                detail:
                    'The current configuration does not register a pool of compatible backend endpoints. Failover is intentionally disabled until alternate origins are explicitly approved and health-checked.',
              ),
              _CapabilityCard(
                icon: Icons.support_agent_rounded,
                title: 'Marvis VNA / Mist AI integration',
                status: 'VENDOR API REQUIRED',
                detail:
                    'No Juniper Mist tenant, Marvis telemetry connector, or credentials are configured. The app must not represent local request heuristics as a connected vendor AI service.',
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Backend connectivity',
                          style: theme.textTheme.titleLarge),
                      const SizedBox(height: 6),
                      Text(_probeMessage),
                      if (_backendOnline != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              _backendOnline!
                                  ? Icons.check_circle_outline
                                  : Icons.error_outline,
                              color: _backendOnline!
                                  ? Colors.green
                                  : theme.colorScheme.error,
                            ),
                            const SizedBox(width: 8),
                            Text(_backendOnline! ? 'Reachable' : 'Unreachable'),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _checkingBackend ? null : _checkBackend,
                        icon: _checkingBackend
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.network_check_rounded),
                        label: Text(_checkingBackend
                            ? 'Checking…'
                            : 'Check backend now'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                      child: Text('Recent network activity',
                          style: theme.textTheme.titleLarge)),
                  TextButton.icon(
                    onPressed: _monitor.clearHistory,
                    icon: const Icon(Icons.clear_all_rounded),
                    label: const Text('Clear'),
                  ),
                ],
              ),
              if (samples.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                        'No samples yet. Use network-backed app features or run the backend check to start learning the baseline.'),
                  ),
                )
              else
                for (final sample in samples)
                  Card(
                    child: ListTile(
                      leading: Icon(
                        sample.networkHealthy
                            ? Icons.check_circle_outline
                            : Icons.warning_amber_rounded,
                        color: sample.networkHealthy
                            ? Colors.green
                            : theme.colorScheme.error,
                      ),
                      title: Text('${sample.method} ${sample.path}',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '${sample.host} · ${sample.statusCode?.toString() ?? sample.failureKind ?? 'no response'} · ${sample.durationMs} ms${sample.wasRetry ? ' · retry' : ''}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        '${sample.at.toLocal().hour.toString().padLeft(2, '0')}:${sample.at.toLocal().minute.toString().padLeft(2, '0')}:${sample.at.toLocal().second.toString().padLeft(2, '0')}',
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                  ),
              const SizedBox(height: 12),
              Text(
                'Safety boundaries: only body-less GET/HEAD calls receive adaptive response-header timeouts and up to two retries. Retryable HTTP statuses are 408, 502, 503, and 504. Repeated failures suppress retry attempts for 30 seconds; an outbound burst can add only a short delay to safe reads. This client does not detect inbound DDoS, change routers/firewalls, block accounts, or modify server data.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          );
        },
      ),
    );
  }

  String _modeDescription(NetworkAutomationMode mode) => switch (mode) {
        NetworkAutomationMode.automatic =>
          'Adapts response-header timeouts for body-less GET/HEAD requests between 8 and 30 seconds from P95 latency, with up to two bounded retries.',
        NetworkAutomationMode.observeOnly =>
          'Continues collecting request outcomes; body-less GET/HEAD calls use a fixed response-header timeout and no retries.',
        NetworkAutomationMode.paused =>
          'Stops adding local samples and disables adaptive timeout and retry behavior. Previous in-memory samples remain until cleared or the app restarts.',
      };
}

class _CapabilityCard extends StatelessWidget {
  const _CapabilityCard({
    required this.icon,
    required this.title,
    required this.status,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String status;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = status == 'ACTIVE' || status == 'APP LEVEL';
    final color = active ? Colors.green : theme.colorScheme.secondary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(status,
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: color, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(detail, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(
      {required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            Text(value,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text(label,
                style: theme.textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
