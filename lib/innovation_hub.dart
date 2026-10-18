import 'package:flutter/material.dart';

import 'innovation_features.dart';
import 'feature_center.dart';

/// A discoverable entry point for major feature modules that previously lived
/// as separate Dart screens. It links the modules into the primary app flow
/// without duplicating their implementations or claiming planned features are
/// fully integrated.
class InnovationHubScreen extends StatelessWidget {
  const InnovationHubScreen({super.key});

  static final _sections = <_InnovationEntry>[
    _InnovationEntry(
      title: 'Platform Expansion',
      subtitle: 'Profile preferences, playback behavior, security and platform settings.',
      icon: Icons.tune_rounded,
      builder: () => PlatformExpansionScreen(),
      stage: 'Settings',
    ),
    _InnovationEntry(
      title: 'Expanded Platform',
      subtitle: 'Browse capabilities, foundations and remaining implementation work.',
      icon: Icons.hub_rounded,
      builder: () => ExpandedPlatformScreen(),
      stage: 'Capability catalog',
    ),
    _InnovationEntry(
      title: 'Ultimate Features',
      subtitle: 'Explore the app’s advanced media, account and service utilities.',
      icon: Icons.auto_awesome_rounded,
      builder: () => UltimateFeaturesScreen(),
      stage: 'Feature suite',
    ),
    _InnovationEntry(
      title: 'Ultimate Streaming Platform',
      subtitle: 'AI, player, family, social, library, cloud, security, devices and studio.',
      icon: Icons.rocket_launch_rounded,
      builder: () => UltimatePlatformScreen(),
      stage: 'Platform suite',
    ),
    _InnovationEntry(
      title: 'Discover & Recaps',
      subtitle: 'Recommendations, collections, entertainment recaps and shared actors.',
      icon: Icons.explore_rounded,
      builder: () => FeatureCenterScreen(),
      stage: 'Discovery',
    ),
    _InnovationEntry(
      title: 'Feature Roadmap',
      subtitle: 'Open additional feature concepts and implementation entry points.',
      icon: Icons.map_outlined,
      builder: () => RoadmapFeaturesScreen(),
      stage: 'Roadmap',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Innovation & Platform Hub')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Color(0xFF292044), Color(0xFF15151F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.layers_rounded, size: 32, color: Color(0xFFFFD36E)),
                SizedBox(height: 10),
                Text('One home for the expanded platform',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                SizedBox(height: 6),
                Text(
                  'These feature modules are linked from the main app here. Each screen keeps its existing implementation; capabilities that need provider, device, or backend support remain subject to those integrations.',
                  style: TextStyle(color: Colors.white70, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final entry in _sections) ...[
            Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(entry.icon),
                ),
                title: Text(entry.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(entry.subtitle),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    settings: RouteSettings(name: '/app/innovation/${entry.stage.toLowerCase().replaceAll(' ', '-')}'),
                    builder: (_) => entry.builder(),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            'Integration note: a module being reachable in the app does not imply that every listed capability is production-connected. Check each module’s status and integration notes before relying on external services.',
            style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _InnovationEntry {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget Function() builder;
  final String stage;

  _InnovationEntry({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.builder,
    required this.stage,
  });
}
