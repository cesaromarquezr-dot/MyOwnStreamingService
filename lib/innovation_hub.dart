import 'package:material_ui/material_ui.dart';

import 'innovation_features.dart';
import 'feature_center.dart';
import 'platform_capability_registry.dart';
import 'platform_reliability_center.dart';
import 'security_bot_center.dart';
import 'playback_diagnostics_center.dart';
import 'disc_ingestion_center.dart';
import 'screens/background_task_center_screen.dart';
import 'screens/developer_testing_studio_screen.dart';
import 'screens/integration_studio_screen.dart';
import 'connected_command_center.dart';
import 'entertainment_studio.dart';
import 'screens/offline_sync_center_screen.dart';
import 'screens/smart_media_import_center_screen.dart';
import 'screens/entertainment_command_center_screen.dart';
import 'accessibility_offline_settings.dart';
import 'streaming_experience.dart' show StreamingExperienceSettingsScreen;
import 'self_driving_network_center.dart';
import 'production_readiness.dart' show ProductionReadinessDashboardScreen;
import 'media_night_features.dart' show MyDataPrivacyCenterScreen;
import 'interface_experience_studio.dart';

/// A discoverable entry point for major feature modules that previously lived
/// as separate Dart screens. It links the modules into the primary app flow
/// without duplicating their implementations or claiming planned features are
/// fully integrated.
class InnovationHubScreen extends StatelessWidget {
  const InnovationHubScreen({super.key});

  static final _sections = <_InnovationEntry>[
    _InnovationEntry(
      title: 'Platform Expansion',
      subtitle:
          'Profile preferences, playback behavior, security and platform settings.',
      icon: Icons.tune_rounded,
      builder: () => PlatformExpansionScreen(),
      stage: 'Settings',
    ),
    _InnovationEntry(
      title: 'Expanded Platform',
      subtitle:
          'Browse capabilities, foundations and remaining implementation work.',
      icon: Icons.hub_rounded,
      builder: () => ExpandedPlatformScreen(),
      stage: 'Capability catalog',
    ),
    _InnovationEntry(
      title: 'Ultimate Features',
      subtitle:
          'Explore the app’s advanced media, account and service utilities.',
      icon: Icons.auto_awesome_rounded,
      builder: () => UltimateFeaturesScreen(),
      stage: 'Feature suite',
    ),
    _InnovationEntry(
      title: 'Ultimate Streaming Platform',
      subtitle:
          'Player, family, social, library, cloud, security, devices and studio.',
      icon: Icons.rocket_launch_rounded,
      builder: () => UltimatePlatformScreen(),
      stage: 'Platform suite',
    ),
    _InnovationEntry(
      title: 'Disc Ingestion Center',
      subtitle:
          'Monitor MakeMKV jobs, write to NAS storage, validate output, and review metadata before library import.',
      icon: Icons.album_rounded,
      builder: () => const DiscIngestionCenterScreen(),
      stage: 'Disc ingestion',
    ),
    _InnovationEntry(
      title: 'Security Diagnostics',
      subtitle:
          'Run read-only security, database, backup, transport, and dependency-scan status checks.',
      icon: Icons.security_rounded,
      builder: () => const ServerSecurityBotCenterScreen(),
      stage: 'Diagnostics',
    ),
    _InnovationEntry(
      title: 'Discover & Recaps',
      subtitle:
          'Recommendations, collections, entertainment recaps and shared actors.',
      icon: Icons.explore_rounded,
      builder: () => FeatureCenterScreen(),
      stage: 'Discovery',
    ),
    _InnovationEntry(
      title: 'Feature Roadmap',
      subtitle:
          'Open additional feature concepts and implementation entry points.',
      icon: Icons.map_outlined,
      builder: () => RoadmapFeaturesScreen(),
      stage: 'Roadmap',
    ),
    _InnovationEntry(
      title: 'Playback Diagnostics',
      subtitle:
          'Guided troubleshooting for buffering, failed playback, subtitles, transcoding, and remote access.',
      icon: Icons.troubleshoot_rounded,
      builder: () => const PlaybackDiagnosticsCenterScreen(),
      stage: 'Playback diagnostics',
    ),
    _InnovationEntry(
      title: 'MyOwn Reliability Center',
      subtitle:
          'Performance planning, storage forecasts, recovery workstreams, household safety, and honest system readiness signals.',
      icon: Icons.monitor_heart_outlined,
      builder: () => const PlatformReliabilityCenterScreen(),
      stage: 'Reliability and recovery',
    ),
    _InnovationEntry(
      title: 'Capability Registry & Master Roadmap',
      subtitle:
          'Search all major capabilities, status, acceptance criteria, and integration dependencies.',
      icon: Icons.fact_check_outlined,
      builder: () => const PlatformCapabilityRegistryScreen(),
      stage: 'Capability Registry',
    ),
    _InnovationEntry(
      title: 'Background Tasks & Activity',
      subtitle:
          'Monitor disc-ingestion progress, local backup snapshots, queued sync updates and recent profile activity in one place.',
      icon: Icons.pending_actions_rounded,
      builder: () => const BackgroundTaskCenterScreen(),
      stage: 'Background Tasks',
    ),
    _InnovationEntry(
      title: 'Developer & Testing Studio',
      subtitle:
          'Run read-only runtime checks, review catalog health, and prepare Flutter analyzer, test and build verification.',
      icon: Icons.developer_mode_rounded,
      builder: () => const DeveloperTestingStudioScreen(),
      stage: 'Developer Testing',
    ),
    _InnovationEntry(
      title: 'Plugin & Integration Studio',
      subtitle:
          'Check the backend, cinematic metadata and music catalog provider status; open the app’s existing integration surfaces.',
      icon: Icons.extension_rounded,
      builder: () => const IntegrationStudioScreen(),
      stage: 'Integrations',
    ),
    _InnovationEntry(
      title: 'Universal Search & Command Hub',
      subtitle:
          'Search across entertainment and access the app’s shared command tools.',
      icon: Icons.manage_search_rounded,
      builder: () => const UniversalSearchHubScreen(),
      stage: 'Universal Search',
    ),
    _InnovationEntry(
      title: 'Connected Command Center',
      subtitle:
          'Open shared account, device and connected-experience controls.',
      icon: Icons.control_camera_rounded,
      builder: () => const ConnectedCommandCenterScreen(),
      stage: 'Connected Command Center',
    ),
    _InnovationEntry(
      title: 'Media Edition Manager',
      subtitle:
          'Keep theatrical, extended, remastered and regional editions distinct.',
      icon: Icons.collections_bookmark_rounded,
      builder: () => const StudioRecordsScreen(kind: StudioRecordKind.editions),
      stage: 'Editions',
    ),
    _InnovationEntry(
      title: 'Smart Collections 2.0',
      subtitle:
          'Build rule-driven collections from media type, genre, ownership and viewing activity.',
      icon: Icons.rule_folder_rounded,
      builder: () => const SmartCollectionsScreen(),
      stage: 'Smart Collections',
    ),
    _InnovationEntry(
      title: 'Home Widgets Studio',
      subtitle:
          'Review and configure the available personalized home widget features.',
      icon: Icons.widgets_outlined,
      builder: () => const HomeWidgetsScreen(),
      stage: 'Home Widgets',
    ),
    _InnovationEntry(
      title: 'Recommendation Transparency & Feedback',
      subtitle:
          'Inspect recommendation signals and provide profile-specific feedback.',
      icon: Icons.recommend_rounded,
      builder: () => const RecommendationTransparencyScreen(),
      stage: 'Recommendation Feedback',
    ),
    _InnovationEntry(
      title: 'Smart Media Import Center',
      subtitle:
          'Scan, identify, review, and approve new media before it enters your library.',
      icon: Icons.move_to_inbox_outlined,
      builder: () => const SmartMediaImportCenterScreen(),
      stage: 'Media Import',
    ),
    _InnovationEntry(
      title: 'Offline & Synchronization Center',
      subtitle:
          'Review offline downloads, cached metadata, queued account changes and synchronization status.',
      icon: Icons.sync_rounded,
      builder: () => const OfflineSyncCenterScreen(),
      stage: 'Offline Sync',
    ),
    _InnovationEntry(
      title: 'Subtitle & Audio Preferences',
      subtitle:
          'Manage preferred audio/subtitle languages, subtitle appearance and playback experience preferences.',
      icon: Icons.closed_caption_rounded,
      builder: () => const StreamingExperienceSettingsScreen(),
      stage: 'Audio and Subtitles',
    ),
    _InnovationEntry(
      title: 'Accessibility & Offline Preferences',
      subtitle:
          'Configure accessibility settings, subtitle defaults and offline behavior.',
      icon: Icons.accessibility_new_rounded,
      builder: () => const AccessibilityOfflineSettingsScreen(),
      stage: 'Accessibility',
    ),
    _InnovationEntry(
      title: 'Entertainment Command Center',
      subtitle:
          'A single operational dashboard for import, backups, offline sync, health, profile safety and devices.',
      icon: Icons.dashboard_customize_rounded,
      builder: () => const EntertainmentCommandCenterScreen(),
      stage: 'Command Center',
    ),
    _InnovationEntry(
      title: 'Production Readiness & Diagnostics',
      subtitle:
          'Review the platform readiness checklist and existing service diagnostics.',
      icon: Icons.monitor_heart_outlined,
      builder: () => const ProductionReadinessDashboardScreen(),
      stage: 'Production Diagnostics',
    ),
    _InnovationEntry(
      title: 'Network Automation & Resilience',
      subtitle:
          'Configure the existing self-driving network monitor, retry policies and observe-only mode.',
      icon: Icons.settings_suggest_rounded,
      builder: () => const SelfDrivingNetworkCenterScreen(),
      stage: 'Network Automation',
    ),
    _InnovationEntry(
      title: 'Universal Playback Preferences',
      subtitle:
          'Open profile-specific audio, caption, playback and continuity preferences.',
      icon: Icons.play_circle_outline_rounded,
      builder: () => const PlaybackPreferencesScreen(),
      stage: 'Playback Preferences',
    ),
    _InnovationEntry(
      title: 'Interface Experience & Seasonal Rules',
      subtitle:
          'Customize Classic, Store, Kiosk and Theater experiences, including seasonal appearance behavior.',
      icon: Icons.palette_outlined,
      builder: () => const InterfaceExperienceStudioScreen(),
      stage: 'Experience Studio',
    ),
    _InnovationEntry(
      title: 'Smart Media Librarian Audit',
      subtitle:
          'Review metadata gaps and possible duplicate entries without automatically modifying or deleting files.',
      icon: Icons.fact_check_rounded,
      builder: () => const SmartMediaLibrarianScreen(),
      stage: 'Media Audit',
    ),
    _InnovationEntry(
      title: 'Media Relationship Graph',
      subtitle:
          'Explore relationships between titles, cast, crew, studios, franchises and music credits.',
      icon: Icons.hub_outlined,
      builder: () => const MediaConnectionGraphScreen(),
      stage: 'Relationship Graph',
    ),
    _InnovationEntry(
      title: 'Data & Privacy Center',
      subtitle:
          'Review local profile-data handling and export or clear this module’s saved preferences.',
      icon: Icons.privacy_tip_outlined,
      builder: () => const MyDataPrivacyCenterScreen(),
      stage: 'Privacy',
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
                    style:
                        TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
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
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(entry.icon),
                ),
                title: Text(entry.title,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(entry.subtitle),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    settings: RouteSettings(
                        name:
                            '/app/innovation/${entry.stage.toLowerCase().replaceAll(' ', '-')}'),
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
