import 'package:flutter/material.dart';

import '../app_core.dart';
import '../library_protection_center.dart';
import '../media_health_screen.dart';
import '../presence/account_profile_presence_service.dart';
import '../profile_administration.dart';
import '../profile_content_safety.dart';
import '../accessibility_offline_settings.dart';
import '../widgets/account_profile_presence_strip.dart';
import 'living_room_controls_screen.dart';
import 'offline_sync_center_screen.dart';
import 'personal_discovery_lists_screen.dart';
import 'smart_media_import_center_screen.dart';

/// Cross-feature dashboard for the current profile/account.
class EntertainmentCommandCenterScreen extends StatelessWidget {
  const EntertainmentCommandCenterScreen({super.key});

  void _open(BuildContext context, Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final app = AppController.instance;
    final profile = app.currentProfile;
    final account = app.currentAccount;
    final otherProfiles = AccountProfilePresenceService.instance.otherActiveProfiles;
    final libraryCount = app.library.where((item) => item.isAccessibleTo(profile)).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Entertainment Command Center')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const AccountProfilePresenceStrip(),
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(profile?.name ?? 'No active profile', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text('${account?.profiles.length ?? 0} account profiles · $libraryCount accessible library titles · ${otherProfiles.length} other profile(s) active'),
          const SizedBox(height: 10),
          const Text('Manage imports, discovery lists, offline access, profile protection and living-room controls from one place.'),
        ]))),
        const SizedBox(height: 10),
        _CommandAction(icon: Icons.library_add_rounded, title: 'Smart Media Import Center', subtitle: 'Disc intake, TMDB metadata lookup, import review and post-import health checks.', onTap: () => _open(context, const SmartMediaImportCenterScreen())),
        _CommandAction(icon: Icons.bookmarks_outlined, title: 'Personal Discovery Lists', subtitle: 'Watch Later, Listen Later, Want to Own and Recently Discovered.', onTap: () => _open(context, const PersonalDiscoveryListsScreen())),
        _CommandAction(icon: Icons.cloud_sync_rounded, title: 'Offline & Sync Center', subtitle: 'Pending progress updates, cached metadata and authorized offline files.', onTap: () => _open(context, const OfflineSyncCenterScreen())),
        _CommandAction(icon: Icons.health_and_safety_outlined, title: 'Media Library Health', subtitle: 'Review missing artwork, descriptions, streams, audio and subtitle metadata.', onTap: () => _open(context, const MediaHealthScreen())),
        _CommandAction(icon: Icons.backup_outlined, title: 'Backup & Recovery', subtitle: 'Library metadata snapshots, backup history and non-destructive repair tools.', onTap: () => _open(context, const LibraryProtectionCenterScreen())),
        _CommandAction(icon: Icons.accessibility_new_rounded, title: 'Accessibility & Offline Preferences', subtitle: 'Contrast, motion, text size, subtitles, audio description and privacy settings.', onTap: () => _open(context, const AccessibilityOfflineSettingsScreen())),
        _CommandAction(icon: Icons.gamepad_rounded, title: 'Living Room Controls', subtitle: 'Keyboard, TV remote and supported controller navigation guidance.', onTap: () => _open(context, const LivingRoomControlsScreen())),
        if (profile != null) ...[
          _CommandAction(icon: Icons.child_care_rounded, title: 'Profile Content & Safety', subtitle: 'Age level, explicit-content controls, search and Group Watch restrictions.', onTap: () => _open(context, ProfileContentSafetyScreen(profile: profile))),
          _CommandAction(icon: Icons.admin_panel_settings_outlined, title: 'Profile Administration & PIN', subtitle: 'Profile governance, permissions and secure device-local PIN protection.', onTap: () => _open(context, ProfileAdministrationScreen(profile: profile))),
        ],
        const SizedBox(height: 12),
        const Text('Some capabilities require a signed-in account, a configured media server, an optical drive or platform-specific controller support. Each destination explains its current requirements.'),
      ]),
    );
  }
}

class _CommandAction extends StatelessWidget {
  const _CommandAction({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(child: ListTile(leading: CircleAvatar(child: Icon(icon)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(subtitle), trailing: const Icon(Icons.chevron_right_rounded), onTap: onTap, isThreeLine: true));
}
