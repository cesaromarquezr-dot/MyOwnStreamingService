// FILE: `lib/library_privacy.dart`.
// Purpose: Implements the library privacy portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_core.dart';
import 'localization.dart';
import 'privacy_preferences.dart';

class LibraryPrivacyScreen extends StatefulWidget {
  const LibraryPrivacyScreen({super.key});

  @override
  State<LibraryPrivacyScreen> createState() => _LibraryPrivacyScreenState();
}

class _LibraryPrivacyScreenState extends State<LibraryPrivacyScreen> {
  PrivacyPreferences preferences = PrivacyPreferences();
  bool loadingPreferences = true;
  bool ownershipConfirmed = false;
  bool deleteMediaOnAccountDeletion = true;

  String get _profileId => AppController.instance.currentProfile?.id ?? 'default';

  @override
  void initState() {
    super.initState();
    _loadPrivacyPreferences();
  }

  Future<void> _loadPrivacyPreferences() async {
    final loaded = await PrivacyPreferencesStore.load(profileId: _profileId);
    if (!mounted) return;
    setState(() { preferences = loaded; loadingPreferences = false; });
  }

  Future<void> _updatePrivacy(void Function() change) async {
    final oldPresence = preferences.sharePresence;
    final oldActivity = preferences.shareActivity;
    setState(change);
    final nextPresence = preferences.sharePresence;
    final nextActivity = preferences.shareActivity;
    final profileId = AppController.instance.currentProfile?.id;
    final api = AppController.instance.backendApi;
    if (profileId != null && api.isAuthenticated &&
        ((oldPresence && !nextPresence) || (oldActivity && !nextActivity))) {
      try {
        await api.setSocialProfilePresence(
          profileId: profileId,
          availability: nextPresence ? null : 'away',
          clearActivity: !nextActivity || !nextPresence,
        );
      } catch (_) {
        // Local privacy intent is still saved if presence service is unavailable.
      }
    }
    await PrivacyPreferencesStore.save(profileId: _profileId, value: preferences);
    if (profileId != null && api.isAuthenticated && !oldPresence && nextPresence) {
      try {
        await api.setSocialProfilePresence(profileId: profileId, availability: 'active', clearActivity: true);
      } catch (_) {
        // Presence can refresh on the next authenticated heartbeat.
      }
    }
  }

  /// Performs `_deleteAccount` for this feature. Update this documentation when its contract changes.
  Future<void> _exportAccountData() async {
    final controller = AppController.instance;
    final account = controller.currentAccount;
    if (account == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: UniversalText('No signed-in account data is available to export.')),
      );
      return;
    }
    final snapshot = <String, dynamic>{
      'format': 'myownstreamingservice-account-export-v1',
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'account': <String, dynamic>{
        'id': account.id,
        'username': account.username,
        'profiles': account.profiles.map((profile) => <String, dynamic>{
          'id': profile.id,
          'name': profile.name,
          'avatarUrl': profile.avatarUrl,
        }).toList(),
      },
      'currentProfileId': controller.currentProfile?.id,
      'libraryMediaIds': controller.library.map((item) => item.id).toList(),
      'watchedMediaIds': controller.watched.map((item) => item.id).toList(),
      'likedMediaIds': controller.liked.map((item) => item.id).toList(),
      'dislikedMediaIds': controller.disliked.map((item) => item.id).toList(),
      'playbackProgress': Map<String, double>.from(controller.playbackProgress),
      'collections': controller.collections.map((item) => item.toJson()).toList(),
      'privacyPreferences': PrivacyPreferencesStore.cached(controller.currentProfile?.id).toJson(),
    };
    await Clipboard.setData(ClipboardData(text: JsonEncoder.withIndent('  ').convert(snapshot)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: UniversalText('Account export copied as JSON. Store it securely; it contains personal library information.')),
    );
  }

  Future<void> _deleteAccount() async {
    if (!deleteMediaOnAccountDeletion) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const UniversalText('Delete account and library?'),
        content: const UniversalText('This requests account deletion and removal of stored media according to the service deletion policy. This action cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const UniversalText('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const UniversalText('Delete account')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await AppController.instance.backendApi.deleteAccount();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: UniversalText('Account deletion request completed.')),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    final account = AppController.instance.currentAccount;
    final used = account?.storageUsedBytes ?? 0;
    final limit = account?.storageLimitBytes ?? 0;
    final ratio = limit <= 0 ? 0.0 : (used / limit).clamp(0.0, 1.0).toDouble();

    return Scaffold(
      appBar: AppBar(title: const UniversalText('Privacy & Ownership')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _PolicyCard(
            icon: Icons.verified_user_outlined,
            title: tr('Your library is private'),
            body: 'Media is associated with your account/profile and must be protected by backend authorization and database row-level security. Normal service operation should not require manual inspection of your personal library.',
          ),
          const SizedBox(height: 14),
          _PolicyCard(
            icon: Icons.copyright_outlined,
            title: tr('Authorized personal media'),
            body: 'Only import content you own or are legally authorized to copy and use. Owning a physical disc does not by itself guarantee every form of copying or remote streaming is lawful in every country.',
          ),
          const SizedBox(height: 14),
          if (loadingPreferences) const LinearProgressIndicator(),
          const SwitchListTile(
            title: UniversalText('Private library'),
            subtitle: UniversalText('Account isolation is always enforced by backend authorization and database policies; it cannot be disabled from this screen.'),
            value: true,
            onChanged: null,
          ),
          SwitchListTile(
            title: const UniversalText('Usage diagnostics'),
            subtitle: const UniversalText('Allow privacy-conscious playback diagnostics and reliability metrics. Off by default.'),
            value: preferences.sharePlaybackDiagnostics,
            onChanged: loadingPreferences ? null : (v) => _updatePrivacy(() => preferences.sharePlaybackDiagnostics = v),
          ),
          SwitchListTile(
            title: const UniversalText('Share online status'),
            subtitle: const UniversalText('Allow other profiles on the account to see when this profile is active.'),
            value: preferences.sharePresence,
            onChanged: loadingPreferences ? null : (v) => _updatePrivacy(() => preferences.sharePresence = v),
          ),
          SwitchListTile(
            title: const UniversalText('Share current activity'),
            subtitle: const UniversalText('Allow current movies, episodes, or music to appear beside this profile.'),
            value: preferences.shareActivity,
            onChanged: loadingPreferences ? null : (v) => _updatePrivacy(() => preferences.shareActivity = v),
          ),
          SwitchListTile(
            title: const UniversalText('Delete stored media with account deletion'),
            subtitle: const UniversalText('Queue the account library and its derived media for deletion according to the retention policy.'),
            value: deleteMediaOnAccountDeletion,
            onChanged: (v) => setState(() => deleteMediaOnAccountDeletion = v),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const UniversalText('STORAGE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(value: ratio),
                  const SizedBox(height: 8),
                  UniversalText('${_formatBytes(used)} used of ${_formatBytes(limit)}'),
                  const SizedBox(height: 8),
                  const UniversalText('Storage includes originals, streaming versions, thumbnails and other derived media where applicable.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const UniversalText('IMPORT DECLARATION', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  const UniversalText('Before adding disc-based media, confirm that you own or are legally authorized to use the content and understand that local law controls what copying and remote streaming are permitted.'),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: ownershipConfirmed,
                    onChanged: (v) => setState(() => ownershipConfirmed = v ?? false),
                    title: const UniversalText('I confirm authorized use of the media I import.'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _exportAccountData,
            icon: const Icon(Icons.download_outlined),
            label: const UniversalText('EXPORT MY ACCOUNT DATA (JSON)'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _showPolicy(context),
            icon: const Icon(Icons.description_outlined),
            label: const UniversalText('VIEW OWNERSHIP & PRIVACY POLICY'),
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: deleteMediaOnAccountDeletion ? _deleteAccount : null,
            icon: const Icon(Icons.delete_forever_outlined),
            label: const UniversalText('DELETE ACCOUNT & STORED LIBRARY'),
          ),
        ],
      ),
    );
  }

  /// Performs `_showPolicy` for this feature. Update this documentation when its contract changes.
  void _showPolicy(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF151515),
      builder: (_) => const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(22, 22, 22, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UniversalText('Your content. Your library.', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              SizedBox(height: 12),
              UniversalText('My Streaming Service provides applications, storage and streaming infrastructure for customers managing authorized personal media. The service does not grant ownership or copyright rights in movies, shows, music or other works.'),
              SizedBox(height: 12),
              UniversalText('Privacy: Your library should be isolated from other customers. Service providers may still process technical data, metadata, security events and information necessary to operate, secure and comply with lawful requests.'),
              SizedBox(height: 12),
              UniversalText('Deletion: Account deletion can queue stored media, transcoded versions, thumbnails and associated library records for deletion under the service retention policy.'),
              SizedBox(height: 12),
              UniversalText('Legal use: Customers are responsible for ensuring that importing, storing, copying and remotely streaming their media is permitted by applicable law.'),
            ],
          ),
        ),
      ),
    );
  }

  /// Performs `_formatBytes` for this feature. Update this documentation when its contract changes.
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class _PolicyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _PolicyCard({required this.icon, required this.title, required this.body});

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 30),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(body, style: TextStyle(color: Colors.grey.shade300, height: 1.35)),
            ])),
          ],
        ),
      ),
    );
  }
}
