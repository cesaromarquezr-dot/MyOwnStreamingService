import 'package:flutter/material.dart';

import 'mindscape_ai_orchestrator.dart';
import 'mindscape_ai_team.dart';
import 'platform_reliability_models.dart';
import 'worldwide_access_family_safety.dart';

/// Reliability overview and planning tools. Host metrics deliberately start as
/// unknown until a trusted host collector or backend diagnostics provider is
/// connected. Calculators are estimates, not live measurements.
class PlatformReliabilityCenterScreen extends StatefulWidget {
  const PlatformReliabilityCenterScreen({super.key});

  @override
  State<PlatformReliabilityCenterScreen> createState() =>
      _PlatformReliabilityCenterScreenState();
}

class _PlatformReliabilityCenterScreenState
    extends State<PlatformReliabilityCenterScreen> {
  final _uploadController = TextEditingController(text: '100');
  final _streamBitrateController = TextEditingController(text: '12');
  final _freeStorageController = TextEditingController(text: '1000');
  final _reserveStorageController = TextEditingController(text: '150');
  final _dailyGrowthController = TextEditingController(text: '8');
  StreamBudgetEstimate? _streamEstimate;
  StorageForecast? _storageForecast;
  String? _inputError;

  static const _signals = <ReliabilitySignal>[
    ReliabilitySignal(id: 'server', label: 'Server health'),
    ReliabilitySignal(id: 'storage', label: 'Drive / pool health'),
    ReliabilitySignal(id: 'backup', label: 'Backup freshness'),
    ReliabilitySignal(id: 'gateway', label: 'Remote HTTPS gateway'),
    ReliabilitySignal(id: 'transcoder', label: 'Transcoding capacity'),
    ReliabilitySignal(id: 'alerts', label: 'External alert delivery'),
  ];

  @override
  void dispose() {
    _uploadController.dispose();
    _streamBitrateController.dispose();
    _freeStorageController.dispose();
    _reserveStorageController.dispose();
    _dailyGrowthController.dispose();
    super.dispose();
  }

  void _calculateStreamBudget() {
    final upload = double.tryParse(_uploadController.text.trim());
    final bitrate = double.tryParse(_streamBitrateController.text.trim());
    if (upload == null || bitrate == null || upload < 0 || bitrate <= 0) {
      setState(() {
        _inputError = 'Enter a non-negative sustained upload speed and a stream bitrate greater than zero.';
        _streamEstimate = null;
      });
      return;
    }
    setState(() {
      _inputError = null;
      _streamEstimate = StreamBudgetEstimate.calculate(
        sustainedUploadMbps: upload,
        averageStreamMbps: bitrate,
      );
    });
  }

  void _calculateStorageForecast() {
    final free = double.tryParse(_freeStorageController.text.trim());
    final reserve = double.tryParse(_reserveStorageController.text.trim());
    final growth = double.tryParse(_dailyGrowthController.text.trim());
    if (free == null || reserve == null || growth == null || free < 0 || reserve < 0 || growth < 0) {
      setState(() {
        _inputError = 'Enter valid non-negative storage values in GB.';
        _storageForecast = null;
      });
      return;
    }
    setState(() {
      _inputError = null;
      _storageForecast = StorageForecast.calculate(
        freeGb: free,
        reserveGb: reserve,
        dailyGrowthGb: growth,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('MyOwn Reliability Center')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.monitor_heart_outlined, size: 34, color: theme.colorScheme.primary),
                  const SizedBox(height: 10),
                  Text('Observe first. Recover safely.',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  const Text(
                    'This center combines reliability targets, local planning calculators, and recovery runbooks. A signal stays “Not connected” until a trusted server-side collector supplies verified data.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('System signals', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final signal in _signals) _SignalTile(signal: signal),
          const SizedBox(height: 20),
          Text('Remote stream capacity planner', style: theme.textTheme.titleLarge),
          const SizedBox(height: 6),
          const Text('Estimate only. Use measured sustained upload and the actual stream bitrates; 30% is reserved for overhead and household traffic.'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _numberField(_uploadController, 'Sustained upload (Mbps)')),
            const SizedBox(width: 10),
            Expanded(child: _numberField(_streamBitrateController, 'Per stream (Mbps)')),
          ]),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _calculateStreamBudget,
            icon: const Icon(Icons.speed_rounded),
            label: const Text('Estimate concurrent remote streams'),
          ),
          if (_streamEstimate != null)
            _ResultCard(
              title: 'Estimated upload budget',
              value: '${_streamEstimate!.estimatedConcurrentStreams} stream(s)',
              detail: '${_streamEstimate!.usableUploadMbps.toStringAsFixed(1)} Mbps usable after ${(100 * _streamEstimate!.reservedFraction).round()}% headroom. Actual performance must be tested.',
            ),
          const SizedBox(height: 20),
          Text('Smart storage planner', style: theme.textTheme.titleLarge),
          const SizedBox(height: 6),
          const Text('Forecasts when free space reaches your reserve based on the values you provide. This is not a live disk reading.'),
          const SizedBox(height: 8),
          _numberField(_freeStorageController, 'Current free space (GB)'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _numberField(_reserveStorageController, 'Keep free (GB)')),
            const SizedBox(width: 10),
            Expanded(child: _numberField(_dailyGrowthController, 'Growth per day (GB)')),
          ]),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _calculateStorageForecast,
            icon: const Icon(Icons.storage_rounded),
            label: const Text('Forecast storage reserve'),
          ),
          if (_storageForecast != null)
            _ResultCard(
              title: 'Time until reserve',
              value: _storageForecast!.daysUntilReserve == null
                  ? 'No growth entered'
                  : _storageForecast!.daysUntilReserve == 0
                      ? 'Reserve reached / exceeded'
                      : '${_storageForecast!.daysUntilReserve!.toStringAsFixed(1)} days',
              detail: 'Current free: ${_storageForecast!.freeGb.toStringAsFixed(1)} GB; reserve: ${_storageForecast!.reserveGb.toStringAsFixed(1)} GB.',
            ),
          if (_inputError != null) ...[
            const SizedBox(height: 8),
            Text(_inputError!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 20),
          Text('Reliability workstreams', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          const _WorkstreamTile(
            icon: Icons.bolt_rounded,
            title: 'Smart streaming optimizer',
            detail: 'Prefer Direct Play, then remux when codecs are compatible, and transcode only when needed and authorized. Cache only disposable transcodes.',
          ),
          const _WorkstreamTile(
            icon: Icons.health_and_safety_outlined,
            title: 'Self-healing infrastructure',
            detail: 'Retry safe transient jobs and restart approved application processes. Require authorization and rollback plans for service isolation or mutations.',
          ),
          const _WorkstreamTile(
            icon: Icons.verified_outlined,
            title: 'Media integrity guardian',
            detail: 'Use checksums, metadata validation, missing-file scans, and duplicate reports. Never silently delete or replace originals.',
          ),
          const _WorkstreamTile(
            icon: Icons.cloud_off_rounded,
            title: 'Offline Home Mode',
            detail: 'Keep local-LAN playback usable if the WAN fails, provided the server, router, local authentication, media, and client remain available. Remote access will be unavailable.',
          ),
          const _WorkstreamTile(
            icon: Icons.restore_rounded,
            title: 'Automatic recovery drills',
            detail: 'Schedule isolated backup restores and report RTO/RPO, checksums, and missing items. Never simulate failure by pulling a live drive or modifying the only production copy.',
          ),
          const _WorkstreamTile(
            icon: Icons.family_restroom_rounded,
            title: 'Worldwide access & family safety',
            detail: 'Use an authenticated HTTPS gateway, session revocation, profile isolation, and Kids policy enforcement. Keep database and storage administration ports private.',
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MindscapeAiOrchestratorScreen())),
            icon: const Icon(Icons.account_tree_outlined),
            label: const Text('Open Mindscape AI Orchestrator'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MindscapeAiTeamScreen())),
            icon: const Icon(Icons.psychology_alt_rounded),
            label: const Text('View Mindscape AI Team'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const WorldwideAccessFamilySafetyScreen())),
            icon: const Icon(Icons.public_rounded),
            label: const Text('Worldwide Access & Family Safety'),
          ),
          const SizedBox(height: 14),
          const Text('Deployment truth: no background monitor, remote gateway, failover storage, host telemetry, or AI worker is created just by opening this screen. Connect and test each service before marking it healthy.'),
        ],
      ),
    );
  }

  Widget _numberField(TextEditingController controller, String label) => TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      );
}

class _SignalTile extends StatelessWidget {
  final ReliabilitySignal signal;
  const _SignalTile({required this.signal});

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: const Icon(Icons.help_outline_rounded),
          title: Text(signal.label),
          subtitle: Text(signal.detail),
          trailing: const Chip(label: Text('Not connected')),
        ),
      );
}

class _ResultCard extends StatelessWidget {
  final String title;
  final String value;
  final String detail;
  const _ResultCard({required this.title, required this.value, required this.detail});

  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(detail),
          ]),
        ),
      );
}

class _WorkstreamTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  const _WorkstreamTile({required this.icon, required this.title, required this.detail});

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(detail),
          isThreeLine: true,
        ),
      );
}
