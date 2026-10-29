import 'package:flutter/material.dart';

import 'app_core.dart';
import 'profile_administration.dart';
import 'profile_content_safety.dart';
import 'profiles.dart';

/// A single route to profile-scoped governance and content-safety settings.
/// Actual permission enforcement continues to live in the authenticated backend.
class ProfilesAndPermissionsHubScreen extends StatelessWidget {
  const ProfilesAndPermissionsHubScreen({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final profile = AppController.instance.currentProfile;
    return Scaffold(
      appBar: AppBar(title: const Text('Profiles & Permissions')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.family_restroom_rounded, size: 34),
                  const SizedBox(height: 10),
                  const Text('Household access, by profile',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(
                    profile == null
                        ? 'Select a profile before opening profile-specific controls.'
                        : 'Selected profile: ${profile.name}. Progress, preferences and safety choices remain profile-scoped where supported.',
                    style: const TextStyle(color: Colors.white70, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: profile == null
                        ? () => _open(context, const ProfileSelectionScreen())
                        : () => _open(context, ProfileAdministrationScreen(profile: profile)),
                    icon: const Icon(Icons.manage_accounts_rounded),
                    label: Text(profile == null ? 'Choose profile' : 'Profile administration'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: const Text('Content safety & parental controls'),
              subtitle: const Text('Age level, restricted content and profile safety settings'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: profile == null
                  ? () => _open(context, const ProfileSelectionScreen())
                  : () => _open(context, ProfileContentSafetyScreen(profile: profile)),
            ),
          ),
          const SizedBox(height: 10),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Security boundary: this screen does not grant permissions by itself. Account ownership, account-scoped authorization, rate limits and remote administration rules are enforced by the backend. Use HTTPS for remote access and keep server credentials out of the Flutter app.',
                style: TextStyle(color: Colors.white60, height: 1.45),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
