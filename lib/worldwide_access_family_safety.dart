import 'package:flutter/material.dart';

/// A deployment checklist, not a remote-access configuration wizard.
/// Ticking an item is a local acknowledgement and is not remotely verified.
class WorldwideAccessFamilySafetyScreen extends StatefulWidget {
  const WorldwideAccessFamilySafetyScreen({super.key});

  @override
  State<WorldwideAccessFamilySafetyScreen> createState() =>
      _WorldwideAccessFamilySafetyScreenState();
}

class _WorldwideAccessFamilySafetyScreenState extends State<WorldwideAccessFamilySafetyScreen> {
  static const _checks = <_SafetyCheck>[
    _SafetyCheck('https', 'Authenticated HTTPS gateway', 'Valid certificate and renewal, exact allowed origins, trusted proxy configuration, and short-lived media authorization.'),
    _SafetyCheck('private-ports', 'Internal ports stay private', 'Database, SMB/NFS, NAS admin, raw backend, and worker-control ports are not publicly reachable.'),
    _SafetyCheck('sessions', 'Account and device sessions', 'Recovery, session expiry, device revocation, and invalid-token behavior are tested.'),
    _SafetyCheck('profiles', 'Household profile isolation', 'Backend APIs deny cross-profile/private-history reads and enforce profile ownership.'),
    _SafetyCheck('kids', 'Kids restrictions everywhere', 'Search, playback, music, community, commerce, notifications, and AI actions enforce restrictions server-side.'),
    _SafetyCheck('remote-test', 'External-network test', 'Tested from mobile data or another external network; DNS, TLS, seeking, subtitles, and concurrent playback work.'),
    _SafetyCheck('offline', 'Local Home Mode', 'A WAN-outage test confirms local media playback and required authentication still work on the LAN.'),
    _SafetyCheck('incident', 'Remote incident procedure', 'A documented way exists to disable external access, revoke sessions, preserve logs, and recover safely.'),
  ];

  final Set<String> _acknowledged = <String>{};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Worldwide Access & Family Safety')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.public_rounded, size: 34, color: theme.colorScheme.primary),
                const SizedBox(height: 8),
                Text('Access from anywhere. Expose as little as possible.', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                const Text('Use an authenticated HTTPS gateway for family streaming. Keep storage shares, database ports, NAS administration, and raw worker controls private. If inbound access is unavailable, use an approved secure tunnel/VPN rather than exposing internal services.'),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: _acknowledged.length / _checks.length),
          const SizedBox(height: 6),
          Text('${_acknowledged.length} of ${_checks.length} checklist items acknowledged', style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          Card(
            color: theme.colorScheme.errorContainer,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text('This is a local, manually ticked checklist. Ticks do not prove that a setting is configured or that an external security test passed.'),
            ),
          ),
          const SizedBox(height: 8),
          for (final check in _checks)
            Card(
              child: CheckboxListTile(
                value: _acknowledged.contains(check.id),
                onChanged: (value) => setState(() {
                  if (value == true) {
                    _acknowledged.add(check.id);
                  } else {
                    _acknowledged.remove(check.id);
                  }
                }),
                title: Text(check.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(check.detail),
                controlAffinity: ListTileControlAffinity.leading,
                isThreeLine: true,
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => setState(_acknowledged.clear),
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Reset checklist'),
          ),
        ],
      ),
    );
  }
}

class _SafetyCheck {
  final String id;
  final String title;
  final String detail;
  const _SafetyCheck(this.id, this.title, this.detail);
}
