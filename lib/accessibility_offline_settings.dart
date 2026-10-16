import 'package:flutter/material.dart';

import 'app_core.dart';
import 'app_accessibility.dart';
import 'localization.dart';
import 'offline_sync_queue.dart';
import 'offline_metadata_cache.dart';
import 'privacy_preferences.dart';
import 'streaming_experience.dart';

/// User-level accessibility, activity privacy, and retryable local progress sync.
class AccessibilityOfflineSettingsScreen extends StatefulWidget {
  const AccessibilityOfflineSettingsScreen({super.key});

  @override
  State<AccessibilityOfflineSettingsScreen> createState() => _AccessibilityOfflineSettingsScreenState();
}

class _AccessibilityOfflineSettingsScreenState extends State<AccessibilityOfflineSettingsScreen> {
  StreamingExperiencePreferences playback = StreamingExperiencePreferences();
  PrivacyPreferences privacy = PrivacyPreferences();
  List<PendingSyncAction> pending = const <PendingSyncAction>[];
  bool loading = true;
  bool saving = false;
  bool syncing = false;
  String? error;

  String get _profileId => AppController.instance.currentProfile?.id ?? 'default';
  String get _accountId => AppController.instance.currentAccount?.id ?? 'local';
  OfflineSyncQueue get _queue => OfflineSyncQueue(scopeId: _accountId);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final values = await Future.wait<dynamic>([
        StreamingExperiencePreferences.load(profileId: _profileId),
        PrivacyPreferencesStore.load(profileId: _profileId),
        _queue.list(),
      ]);
      if (!mounted) return;
      setState(() {
        playback = values[0] as StreamingExperiencePreferences;
        privacy = values[1] as PrivacyPreferences;
        pending = values[2] as List<PendingSyncAction>;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { loading = false; error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  Future<void> _savePlayback(void Function() change) async {
    setState(() { change(); saving = true; });
    try {
      await playback.save(profileId: _profileId);
      await AppAccessibilitySettings.instance.reload(profileId: _profileId);
      if (mounted) setState(() => saving = false);
    } catch (e) {
      if (mounted) setState(() { saving = false; error = e.toString(); });
    }
  }

  Future<void> _savePrivacy(void Function() change) async {
    final priorPresence = privacy.sharePresence;
    final priorActivity = privacy.shareActivity;
    setState(() { change(); saving = true; });
    final nextPresence = privacy.sharePresence;
    final nextActivity = privacy.shareActivity;
    try {
      final api = AppController.instance.backendApi;
      final profileId = AppController.instance.currentProfile?.id;
      if (profileId != null && api.isAuthenticated &&
          ((priorPresence && !nextPresence) || (priorActivity && !nextActivity))) {
        // Clear server-side activity while the previous permission still allows this request.
        await api.setSocialProfilePresence(
          profileId: profileId,
          availability: nextPresence ? null : 'away',
          clearActivity: !nextActivity || !nextPresence,
        );
      }
      await PrivacyPreferencesStore.save(profileId: _profileId, value: privacy);
      if (!privacy.allowOfflineMetadata) {
        await OfflineMetadataCache(profileId: _profileId).clear();
      }
      if (profileId != null && api.isAuthenticated && !priorPresence && nextPresence) {
        await api.setSocialProfilePresence(profileId: profileId, availability: 'active', clearActivity: true);
      }
      if (mounted) setState(() => saving = false);
    } catch (e) {
      if (mounted) setState(() { saving = false; error = e.toString().replaceFirst('Exception: ', ''); });
      await PrivacyPreferencesStore.save(profileId: _profileId, value: privacy);
      if (!privacy.allowOfflineMetadata) {
        await OfflineMetadataCache(profileId: _profileId).clear();
      }
    }
  }

  Future<void> _syncPending() async {
    if (syncing) return;
    setState(() { syncing = true; error = null; });
    try {
      final controller = AppController.instance;
      if (!controller.backendApi.isAuthenticated || controller.currentAccount == null) {
        throw StateError('Sign in to sync queued playback progress. Pending changes have been kept on this device.');
      }
      // The account snapshot includes the latest playback-progress map. Clear the
      // queue only after the authenticated backend confirms the snapshot write.
      await controller.syncCurrentAccountToSupabase();
      await _queue.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: UniversalText('Pending changes synchronized.')));
      await _load();
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const UniversalText('Accessibility & Offline')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              if (error != null) Card(child: Padding(padding: const EdgeInsets.all(12), child: Text(error!))),
              Card(
                child: Column(children: [
                  const ListTile(
                    leading: Icon(Icons.accessibility_new_rounded),
                    title: UniversalText('Accessibility'),
                    subtitle: UniversalText('These settings are stored per profile. System-level accessibility settings remain respected where the platform permits.'),
                  ),
                  SwitchListTile(
                    title: const UniversalText('High contrast'),
                    value: playback.highContrast,
                    onChanged: saving ? null : (value) => _savePlayback(() => playback.highContrast = value),
                  ),
                  SwitchListTile(
                    title: const UniversalText('Reduce motion'),
                    value: playback.reduceMotion,
                    onChanged: saving ? null : (value) => _savePlayback(() => playback.reduceMotion = value),
                  ),
                  ListTile(
                    title: const UniversalText('App text size'),
                    subtitle: Text('${(playback.appTextScale * 100).round()}%'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Slider(
                      min: 0.85,
                      max: 1.6,
                      divisions: 15,
                      value: playback.appTextScale.clamp(0.85, 1.6).toDouble(),
                      label: '${(playback.appTextScale * 100).round()}%',
                      onChanged: saving ? null : (value) => _savePlayback(() => playback.appTextScale = value),
                    ),
                  ),
                  SwitchListTile(
                    title: const UniversalText('Subtitles by default'),
                    value: playback.subtitlesEnabled,
                    onChanged: saving ? null : (value) => _savePlayback(() => playback.subtitlesEnabled = value),
                  ),
                  ListTile(
                    title: const UniversalText('Subtitle size'),
                    subtitle: Text('${(playback.subtitleScale * 100).round()}%'),
                    trailing: SizedBox(
                      width: 160,
                      child: Slider(
                        min: 0.75,
                        max: 2.0,
                        divisions: 25,
                        value: playback.subtitleScale.clamp(0.75, 2.0).toDouble(),
                        onChanged: saving ? null : (value) => _savePlayback(() => playback.subtitleScale = value),
                      ),
                    ),
                  ),
                  SwitchListTile(
                    title: const UniversalText('Prefer audio description tracks'),
                    value: playback.audioDescriptions,
                    onChanged: saving ? null : (value) => _savePlayback(() => playback.audioDescriptions = value),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(children: [
                  const ListTile(
                    leading: Icon(Icons.privacy_tip_outlined),
                    title: UniversalText('Profile privacy'),
                    subtitle: UniversalText('These options are enforced locally and by the presence API when available. Cross-device preference sync requires the production API/migration rollout.'),
                  ),
                  SwitchListTile(
                    title: const UniversalText('Share active status'),
                    subtitle: const UniversalText('Allow other profiles on this account to see whether this profile is active.'),
                    value: privacy.sharePresence,
                    onChanged: saving ? null : (value) => _savePrivacy(() => privacy.sharePresence = value),
                  ),
                  SwitchListTile(
                    title: const UniversalText('Share current activity'),
                    subtitle: const UniversalText('Allow titles, songs, and other current activity to appear beside this profile.'),
                    value: privacy.shareActivity,
                    onChanged: saving ? null : (value) => _savePrivacy(() => privacy.shareActivity = value),
                  ),
                  SwitchListTile(
                    title: const UniversalText('Personalized recommendations'),
                    subtitle: const UniversalText('Use this profile’s likes and watch history to rank recommendations.'),
                    value: privacy.personalizedRecommendations,
                    onChanged: saving ? null : (value) => _savePrivacy(() => privacy.personalizedRecommendations = value),
                  ),
                  SwitchListTile(
                    title: const UniversalText('Share playback diagnostics'),
                    subtitle: const UniversalText('Allow non-content technical playback events. Off by default.'),
                    value: privacy.sharePlaybackDiagnostics,
                    onChanged: saving ? null : (value) => _savePrivacy(() => privacy.sharePlaybackDiagnostics = value),
                  ),
                  SwitchListTile(
                    title: const UniversalText('Cache non-sensitive metadata offline'),
                    subtitle: const UniversalText('Allows eligible metadata and progress to remain available locally; media downloads depend on rights and platform support.'),
                    value: privacy.allowOfflineMetadata,
                    onChanged: saving ? null : (value) => _savePrivacy(() => privacy.allowOfflineMetadata = value),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const UniversalText('Pending offline sync', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text('${pending.length} playback progress update(s) waiting to be synchronized.'),
                    const SizedBox(height: 8),
                    const UniversalText('Progress is coalesced by profile and media ID. Messages, passwords, payment information, and raw media are never put in this queue.'),
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: FilledButton.icon(
                      onPressed: syncing || pending.isEmpty ? null : _syncPending,
                      icon: syncing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.sync_rounded),
                      label: UniversalText(syncing ? 'Syncing…' : 'Sync pending changes now'),
                    )),
                    if (pending.isNotEmpty)
                      Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () async { await _queue.clear(); await _load(); }, child: const UniversalText('Discard pending progress'))),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
              const UniversalText('Offline mode preserves the latest progress locally. Network reconnection triggers are platform-specific; use Sync pending changes when connection returns. Full protected media downloads are not implied by this metadata queue.', style: TextStyle(color: Colors.white60, fontSize: 12)),
            ]),
    );
  }
}
