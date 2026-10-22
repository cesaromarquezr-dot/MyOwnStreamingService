import 'package:flutter/material.dart';

/// Describes the three proposed Mindscape AI roles. This catalog is product
/// configuration only; it does not create live AI workers or grant permissions.
class MindscapeAiBotRole {
  final String id;
  final String name;
  final String tagline;
  final String purpose;
  final IconData icon;
  final List<String> responsibilities;
  final List<String> guardrails;

  const MindscapeAiBotRole({
    required this.id,
    required this.name,
    required this.tagline,
    required this.purpose,
    required this.icon,
    required this.responsibilities,
    required this.guardrails,
  });
}

class MindscapeAiBotCatalog {
  MindscapeAiBotCatalog._();

  static const List<MindscapeAiBotRole> roles = <MindscapeAiBotRole>[
    MindscapeAiBotRole(
      id: 'steward',
      name: 'Steward',
      tagline: 'The Butler • Security, housekeeping & encryption',
      purpose:
          'A calm, dependable caretaker that watches the service perimeter, keeps the digital house orderly, and checks encryption posture.',
      icon: Icons.security_rounded,
      responsibilities: <String>[
        'Review approved security events, session anomalies, and service-health signals.',
        'Identify temporary-file and cache housekeeping opportunities without touching a user’s media library.',
        'Check configured TLS, storage-encryption, and secret-handling posture; draft key-rotation plans when needed.',
        'Prepare redacted summaries and a prioritized action list for the administrator.',
      ],
      guardrails: <String>[
        'Read-only by default; secrets and raw credentials are never shown in reports.',
        'Key rotation, permission changes, account lockouts, and deletion require explicit authorization.',
        'A security recommendation never overrides backend authorization or existing policy.',
      ],
    ),
    MindscapeAiBotRole(
      id: 'moxie',
      name: 'Moxie',
      tagline: 'The Social Spark • Humor, connection & tactical coordination',
      purpose:
          'A personable companion that makes the service feel welcoming, helps people connect around entertainment, and coordinates safe plans.',
      icon: Icons.forum_rounded,
      responsibilities: <String>[
        'Help plan watch parties, theme nights, group votes, and household schedules.',
        'Offer profile-appropriate humor and conversational style, with user controls for tone and quiet mode.',
        'Turn goals or incidents into clear task plans, priorities, checklists, and handoffs to the other roles.',
        'Draft invitations and messages for review instead of sending them silently.',
      ],
      guardrails: <String>[
        'Honor profile permissions, Kids restrictions, blocks, and social privacy settings.',
        'Never reveal another person’s private viewing history or sensitive profile data to make a joke.',
        'No posting, messaging, purchases, account changes, or privileged tactical action without the required confirmation.',
      ],
    ),
    MindscapeAiBotRole(
      id: 'fixer',
      name: 'Fixer',
      tagline: 'The Handyman • Maintenance, incident containment & video analysis',
      purpose:
          'A practical maintenance specialist for diagnostics, service recovery, supported storage optimization, and authorized media analysis.',
      icon: Icons.build_circle_rounded,
      responsibilities: <String>[
        'Review connected service health, worker queues, storage capacity, drive-health signals, and backup status.',
        'Treat digital “fire suppression” as incident triage: raise alerts and isolate only pre-approved, reversible failing jobs or services.',
        'Recommend platform-native storage maintenance based on drive type and operating system instead of blindly defragmenting every volume.',
        'Analyze media only through a configured, authorized video-inference pipeline and permitted metadata, captions, chapters, or frames.',
      ],
      guardrails: <String>[
        'Digital incident containment is not physical fire protection and does not replace hardware, smoke, or fire-safety systems.',
        'Never run destructive cleanup, disk repair, volume changes, or broad defragmentation automatically.',
        'Use appropriate SSD TRIM/OS optimization and HDD maintenance; verify drive type and platform before recommending an operation.',
        'If video models or authorized media inputs are not configured, report analysis as unavailable instead of inventing results.',
      ],
    ),
  ];
}

/// Role catalog and operating contract for the Mindscape AI team.
/// No background workers, provider calls, or privileged actions are triggered
/// by opening this screen.
class MindscapeAiTeamScreen extends StatelessWidget {
  const MindscapeAiTeamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Mindscape AI Team')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: <Color>[
                  theme.colorScheme.primaryContainer,
                  theme.colorScheme.surfaceContainerHighest,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.psychology_alt_rounded, size: 34),
                SizedBox(height: 10),
                Text(
                  'Three minds. Clear responsibilities. Shared safeguards.',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 8),
                Text(
                  'Steward protects and keeps order; Moxie brings social intelligence and coordination; Fixer handles diagnostics and supported maintenance.',
                  style: TextStyle(height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const _RuntimeNotice(),
          const SizedBox(height: 16),
          for (final role in MindscapeAiBotCatalog.roles) ...[
            _BotRoleCard(role: role),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 4),
          const Text(
            'Shared operating rules',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const _OperatingRule(
            icon: Icons.lock_outline_rounded,
            title: 'Least privilege',
            detail:
                'Give each agent a separate identity and only the minimum tools, data, and profile scope needed for its job.',
          ),
          const _OperatingRule(
            icon: Icons.fact_check_outlined,
            title: 'Preview and approve',
            detail:
                'Show the proposed action, target, risk, and rollback plan before sensitive changes. Production mutations are not authorized by AI output alone.',
          ),
          const _OperatingRule(
            icon: Icons.receipt_long_outlined,
            title: 'Auditable and private',
            detail:
                'Log actor, tool, outcome, and approval with secrets redacted. Treat media metadata, captions, and imported text as untrusted input.',
          ),
          const _OperatingRule(
            icon: Icons.verified_user_outlined,
            title: 'Fail safely',
            detail:
                'If a connector, permission check, model, or health signal is unavailable, say so and avoid guessing or taking a risky fallback action.',
          ),
        ],
      ),
    );
  }
}

class _RuntimeNotice extends StatelessWidget {
  const _RuntimeNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_outline_rounded),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Role definitions are added; the AI model connectors, scheduler, telemetry, and tool integrations are not connected by this screen. No agent is running in the background yet.',
              style: TextStyle(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _BotRoleCard extends StatelessWidget {
  final MindscapeAiBotRole role;

  const _BotRoleCard({required this.role});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(role.icon),
        ),
        title: Text(role.name, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(role.tagline),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: Text(role.purpose, style: const TextStyle(height: 1.4)),
          ),
          const SizedBox(height: 12),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Responsibilities', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 4),
          for (final responsibility in role.responsibilities)
            _BulletText(text: responsibility),
          const SizedBox(height: 10),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Safety boundaries', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 4),
          for (final guardrail in role.guardrails)
            _BulletText(text: guardrail, icon: Icons.shield_outlined),
        ],
      ),
    );
  }
}

class _BulletText extends StatelessWidget {
  final String text;
  final IconData icon;

  const _BulletText({required this.text, this.icon = Icons.check_circle_outline_rounded});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
          ],
        ),
      );
}

class _OperatingRule extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;

  const _OperatingRule({required this.icon, required this.title, required this.detail});

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(detail),
      );
}
