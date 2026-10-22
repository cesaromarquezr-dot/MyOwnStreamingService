import 'package:flutter/material.dart';

import 'entertainment_extensions.dart';
import 'mindscape_ai_orchestrator.dart';
import 'mindscape_ai_team.dart';
import 'platform_reliability_center.dart';
import 'worldwide_access_family_safety.dart';

/// Single discoverable home for the AI roles and connected operational tools.
/// This screen labels unconnected model/worker integrations honestly.
class AiBotCenterScreen extends StatelessWidget {
  const AiBotCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('AI Bot Center')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.smart_toy_rounded, size: 36, color: theme.colorScheme.primary),
                const SizedBox(height: 10),
                Text('Meet your AI operations team', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                const Text('Steward, Moxie, and Fixer have defined roles and guardrails. Model connections, persistent workers, telemetry, and tool permissions are shown as unverified until their real integrations are connected and tested.', style: TextStyle(color: Colors.white70, height: 1.4)),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          for (final role in MindscapeAiBotCatalog.roles)
            Card(
              child: ListTile(
                leading: CircleAvatar(child: Icon(role.icon)),
                title: Text(role.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text('${role.tagline}\nRole definition available · live model/tool execution not verified'),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _open(context, const MindscapeAiTeamScreen()),
              ),
            ),
          const SizedBox(height: 18),
          Text('Operations and coordination', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          _ToolTile(
            icon: Icons.security_rounded,
            title: 'Security & Reliability Bots',
            subtitle: 'On-demand backend checks, audit results, and administrator approvals.',
            status: 'On-demand checks',
            onTap: () => _open(context, const SecurityBotCenterScreen()),
          ),
          _ToolTile(
            icon: Icons.account_tree_rounded,
            title: 'Mindscape AI Orchestrator',
            subtitle: 'Draft and review task proposals for Steward, Moxie, and Fixer.',
            status: 'Proposal UI · no autonomous execution',
            onTap: () => _open(context, const MindscapeAiOrchestratorScreen()),
          ),
          _ToolTile(
            icon: Icons.monitor_heart_outlined,
            title: 'Reliability Command Center',
            subtitle: 'Streaming capacity, storage forecasts, and connected health signals.',
            status: 'Disconnected signals remain unknown',
            onTap: () => _open(context, const PlatformReliabilityCenterScreen()),
          ),
          _ToolTile(
            icon: Icons.public_rounded,
            title: 'Worldwide Access & Family Safety',
            subtitle: 'Review remote-access readiness, profile boundaries, and session safety.',
            status: 'Requires local deployment checks',
            onTap: () => _open(context, const WorldwideAccessFamilySafetyScreen()),
          ),
          const SizedBox(height: 16),
          const Text('Automation safeguards: backend permission checks, least-privilege tool scopes, redacted audit logs, and approval for high-impact actions are required before agents are allowed to change production state.', style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4)),
        ],
      ),
    );
  }

  static void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => screen));
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({required this.icon, required this.title, required this.subtitle, required this.status, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: CircleAvatar(child: Icon(icon)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text('$subtitle\n$status'),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    ),
  );
}
