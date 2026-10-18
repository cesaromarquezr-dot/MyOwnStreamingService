import 'package:flutter/material.dart';

const _opsAccent = Color(0xFF8B7CFF);

/// Operational overview and workflow catalogue. Production records and actions
/// must be loaded through authenticated, server-authorized APIs.
class PlatformOperationsCenterScreen extends StatelessWidget {
  const PlatformOperationsCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const sections = <_OpsSection>[
      _OpsSection(Icons.admin_panel_settings, 'Unified Admin Control Center', 'Users, roles, support agents, moderation, plans, service health and audit history.', 'Admin RBAC required'),
      _OpsSection(Icons.support_agent, 'Customer Support Operations', 'Ticket assignment, public replies, internal notes, SLA timers, escalation, knowledge base and satisfaction surveys.', 'Support API required'),
      _OpsSection(Icons.monitor_heart, 'Reliability & Incident Management', 'Service health, playback/API latency, error rates, incident timeline, alert routing, backup and rollback runbooks.', 'Telemetry required'),
      _OpsSection(Icons.badge, 'Identity & Access Management', 'SSO, MFA, Active Directory / Entra ID group mapping, least-privilege roles and session revocation.', 'Identity provider required'),
      _OpsSection(Icons.receipt_long, 'Subscription & Billing Center', 'Plans, renewals, invoices, purchases, rentals, refunds and signed payment-webhook reconciliation.', 'Payment provider required'),
      _OpsSection(Icons.movie_filter, 'Content & Rights Management', 'Catalog publishing, age ratings, territory rights, licensing windows, audio/subtitle tracks and ingestion workflow.', 'Rights service required'),
      _OpsSection(Icons.privacy_tip, 'Privacy & Data Governance', 'Consent, data export/deletion requests, retention policies, private-message access controls and privacy audit trails.', 'Privacy workflows required'),
      _OpsSection(Icons.verified, 'Automated Quality & Release Pipeline', 'Flutter analysis/tests, API contract tests, SQL migration checks, dependency/secrets scanning and staged deployment gates.', 'CI runner required'),
    ];
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B10),
      appBar: AppBar(title: const Text('Platform Operations'), backgroundColor: const Color(0xFF11111A)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('One operations layer for the whole streaming service', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('These cards describe the planned operational domains. This screen is a navigation/readiness catalogue, not a live monitoring console; connect authenticated services before showing real records or enabling administrative actions.', style: TextStyle(color: Colors.white60, height: 1.45)),
        const SizedBox(height: 18),
        const Wrap(spacing: 8, runSpacing: 8, children: [
          _ReadinessChip(label: '8 workstreams', icon: Icons.dashboard_customize),
          _ReadinessChip(label: 'Least privilege', icon: Icons.lock_outline),
          _ReadinessChip(label: 'Audit-first', icon: Icons.history),
        ]),
        const SizedBox(height: 18),
        ...sections.map((s) => Card(
          color: const Color(0xFF171722), margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            contentPadding: const EdgeInsets.all(14),
            leading: CircleAvatar(backgroundColor: _opsAccent.withValues(alpha: .16), child: Icon(s.icon, color: _opsAccent)),
            title: Text(s.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            subtitle: Padding(padding: const EdgeInsets.only(top: 7), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(s.description, style: const TextStyle(color: Colors.white60, height: 1.35)), const SizedBox(height: 8), Text(s.dependency, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12))])),
          ),
        )),
        const SizedBox(height: 8),
        const Text('Security rule: hiding this screen in the client is not authorization. Every admin, support, billing, identity and privacy endpoint must verify the authenticated identity and role on the server.', style: TextStyle(color: Colors.orangeAccent, fontSize: 12, height: 1.4)),
      ]),
    );
  }
}

class _OpsSection {
  final IconData icon; final String title; final String description; final String dependency;
  const _OpsSection(this.icon, this.title, this.description, this.dependency);
}

class _ReadinessChip extends StatelessWidget {
  final String label; final IconData icon;
  const _ReadinessChip({required this.label, required this.icon});
  @override
  Widget build(BuildContext context) => Chip(avatar: Icon(icon, size: 16, color: _opsAccent), label: Text(label), backgroundColor: const Color(0xFF1B1A29), labelStyle: const TextStyle(color: Colors.white70));
}
