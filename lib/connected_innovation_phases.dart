import 'package:flutter/material.dart';

/// A unified entry point for the four cross-platform implementation phases.
/// UI is usable offline; live entitlement and commerce decisions must be
/// supplied by authenticated backend endpoints before production use.
class ConnectedInnovationPhasesScreen extends StatelessWidget {
  const ConnectedInnovationPhasesScreen({super.key});

  static const _background = Color(0xFF101018);
  static const _surface = Color(0xFF1B1B28);
  static const _accent = Color(0xFF9B8CFF);

  @override
  Widget build(BuildContext context) {
    final phases = <_PhaseInfo>[
      _PhaseInfo(
        number: '01', title: 'Shared foundations', icon: Icons.layers_rounded,
        summary: 'One access and ownership model across media, music, collections, chat and commerce.',
        items: const ['Canonical item references', 'Owned / subscribed / rented / shared states', 'Permission-aware actions', 'Consistent loading and error states'],
        status: 'FOUNDATION',
      ),
      _PhaseInfo(
        number: '02', title: 'Social integration', icon: Icons.people_alt_rounded,
        summary: 'Sharing cards and social activities work consistently across conversations and communities.',
        items: const ['Universal share entry point', 'Community, post and friend destinations', 'Watch Party invitations and readiness', 'Activity and notification events'],
        status: 'CONNECTED UI',
      ),
      _PhaseInfo(
        number: '03', title: 'Discovery & continuity', icon: Icons.auto_awesome_rounded,
        summary: 'Search, recommendations and continue-watching flows can cross media types.',
        items: const ['Unified search entry point', 'Save to personal/shared collections', 'Playback and listening continuity', 'Privacy-aware personalization controls'],
        status: 'INTEGRATION PLAN',
      ),
      _PhaseInfo(
        number: '04', title: 'Commerce & reliability', icon: Icons.shield_moon_rounded,
        summary: 'Bring Shop and Food Delivery together with secure, observable backend workflows.',
        items: const ['Shop, physical media and restaurant cards', 'Order status and history', 'Authorization, rate limits and audit events', 'Migration and API health checks'],
        status: 'BACKEND REQUIRED',
      ),
    ];

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        title: const Text('Connected Innovation'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(colors: [Color(0xFF30254E), Color(0xFF1B263B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.hub_rounded, color: _accent, size: 34),
              SizedBox(height: 12),
              Text('One connected entertainment ecosystem', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w800)),
              SizedBox(height: 8),
              Text('Four phases share the same foundations so streaming, social, discovery and commerce do not become disconnected features.', style: TextStyle(color: Color(0xFFD6D3E6), height: 1.4)),
            ]),
          ),
          const SizedBox(height: 18),
          for (final phase in phases) ...[
            _PhaseCard(info: phase, surface: _surface, accent: _accent),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          const Text('Implementation note', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17)),
          const SizedBox(height: 6),
          const Text('This dashboard and the shared data contracts are scaffolding for the phases. Real-time entitlements, payments, notifications, synchronized playback and recommendations require authenticated backend endpoints and integration tests; the interface does not pretend those server actions are already live.', style: TextStyle(color: Colors.white70, height: 1.45)),
        ],
      ),
    );
  }
}

class _PhaseInfo {
  final String number, title, summary, status;
  final IconData icon;
  final List<String> items;
  const _PhaseInfo({required this.number, required this.title, required this.icon, required this.summary, required this.items, required this.status});
}

class _PhaseCard extends StatelessWidget {
  final _PhaseInfo info;
  final Color surface, accent;
  const _PhaseCard({required this.info, required this.surface, required this.accent});

  @override
  Widget build(BuildContext context) => Card(
    color: surface,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFF303043))),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: accent.withValues(alpha: .14), borderRadius: BorderRadius.circular(14)), child: Icon(info.icon, color: accent)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('PHASE ${info.number}', style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
            Text(info.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          ])),
          const Icon(Icons.checklist_rounded, color: Colors.white38),
        ]),
        const SizedBox(height: 12),
        Text(info.summary, style: const TextStyle(color: Colors.white70, height: 1.4)),
        const SizedBox(height: 12),
        for (final item in info.items) Padding(padding: const EdgeInsets.only(bottom: 7), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.check_circle_outline_rounded, size: 17, color: Color(0xFF8FD9B5)), const SizedBox(width: 8), Expanded(child: Text(item, style: const TextStyle(color: Colors.white, fontSize: 13.5)))])),
        const SizedBox(height: 4),
        Align(alignment: Alignment.centerLeft, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: accent.withValues(alpha: .12), borderRadius: BorderRadius.circular(30)), child: Text(info.status, style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .7)))),
      ]),
    ),
  );
}
