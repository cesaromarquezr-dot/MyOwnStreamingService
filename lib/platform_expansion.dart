// FILE: `lib/platform_expansion.dart`.
// Purpose: Implements the platform expansion portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_core.dart';

// Profile-scoped settings introduced by the platform expansion pass.
//
// These settings intentionally live separately from HomeCustomizationStore so
// the existing 100-feature implementation remains backwards compatible.
class PlatformPreferenceStore {
  PlatformPreferenceStore._();

  static SharedPreferences? _prefs;

  static Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static String _profileKey(String name) =>
      AppController.instance.currentProfile?.id ?? 'default';

  static String _key(String name, String setting) =>
    'platform_${_profileKey(name)}_${name}_$setting';

  static bool getBool(String name, String setting, {bool fallback = true}) {
    return _prefs?.getBool(_key(name, setting)) ?? fallback;
  }

  static Future<void> setBool(
    String name,
    String setting,
    bool value,
  ) async {
    await _prefs?.setBool(_key(name, setting), value);
  }

  static String getString(
    String name,
    String setting, {
    String fallback = '',
  }) {
    return _prefs?.getString(_key(name, setting)) ?? fallback;
  }

  static Future<void> setString(
    String name,
    String setting,
    String value,
  ) async {
    await _prefs?.setString(_key(name, setting), value);
  }

  static bool kidsSetting(String setting, {bool fallback = true}) =>
      getBool('kids', setting, fallback: fallback);

  static Future<void> setKidsSetting(String setting, bool value) =>
      setBool('kids', setting, value);

  static Map<String, dynamic> snapshot() {
    final profileId = _profileKey('snapshot');
    final prefix = 'platform_${profileId}_';
    final result = <String, dynamic>{};
    for (final key in _prefs?.getKeys() ?? <String>{}) {
      if (!key.startsWith(prefix)) continue;
      final shortKey = key.substring(prefix.length);
      result[shortKey] = _prefs?.get(key);
    }
    return result;
  }
}

class PlatformExpansionScreen extends StatelessWidget {
  const PlatformExpansionScreen({super.key});

  static const _categories = <_PlatformCategory>[
    _PlatformCategory(
      'Account Security',
      '2FA, suspicious-login alerts, device approval and session controls.',
      Icons.security_rounded,
      'security',
      [
        _PreferenceSpec(
          'Two-factor authentication',
          'Require an additional verification step for sign-ins.',
          'two_factor',
        ),
        _PreferenceSpec(
          'Suspicious login alerts',
          'Notify this profile when a new or unusual login is detected.',
          'login_alerts',
        ),
        _PreferenceSpec(
          'New device approval',
          'Require approval before a new device can use this profile.',
          'device_approval',
        ),
        _PreferenceSpec(
          'Automatic session expiry',
          'Expire inactive sessions instead of keeping them indefinitely.',
          'session_expiry',
        ),
      ],
    ),
    _PlatformCategory(
      'Playback Experience',
      'Resume, autoplay, quality, subtitles and immersive playback behavior.',
      Icons.play_circle_fill_rounded,
      'playback',
      [
        _PreferenceSpec(
          'Resume playback',
          'Always offer the saved playback position.',
          'resume',
        ),
        _PreferenceSpec(
          'Autoplay next',
          'Automatically start the next movie or episode when appropriate.',
          'autoplay_next',
        ),
        _PreferenceSpec(
          'Preload next item',
          'Prepare the next episode or collection item in advance.',
          'preload_next',
        ),
        _PreferenceSpec(
          'Picture-in-picture',
          'Allow playback to continue in a floating window when supported.',
          'picture_in_picture',
        ),
        _PreferenceSpec(
          'Remember audio and subtitles',
          'Keep per-profile language and subtitle choices.',
          'remember_tracks',
        ),
      ],
    ),
    _PlatformCategory(
      'TV Experience',
      'Make series, seasons and episodes behave like a first-class streaming service.',
      Icons.tv_rounded,
      'tv',
      [
        _PreferenceSpec(
          'Autoplay next episode',
          'Continue to the next episode after an episode ends.',
          'autoplay_episode',
        ),
        _PreferenceSpec(
          'Preserve intros',
          'Keep TV intros intact rather than skipping them automatically.',
          'preserve_intros',
        ),
        _PreferenceSpec(
          'Continue unfinished seasons',
          'Prioritize the next unfinished episode on Home.',
          'continue_seasons',
        ),
        _PreferenceSpec(
          'Show specials',
          'Include specials in season and series navigation.',
          'show_specials',
        ),
      ],
    ),
    _PlatformCategory(
      'Notifications',
      'Control the events that can surface for this profile.',
      Icons.notifications_active_rounded,
      'notifications',
      [
        _PreferenceSpec(
          'New episodes',
          'Notify when followed series receive a new episode.',
          'new_episodes',
        ),
        _PreferenceSpec(
          'Recommendations',
          'Notify when a strong recommendation becomes available.',
          'recommendations',
        ),
        _PreferenceSpec(
          'Sports starting',
          'Notify when a followed live game is about to start.',
          'sports_starting',
        ),
        _PreferenceSpec(
          'Security events',
          'Always surface security and account-protection events.',
          'security_events',
        ),
      ],
    ),
    _PlatformCategory(
      'Backup & Restore',
      'Prepare profile configuration for backup, migration and recovery.',
      Icons.backup_rounded,
      'backup',
      [
        _PreferenceSpec(
          'Back up profile settings',
          'Include profile preferences in the backup manifest.',
          'profile_settings',
        ),
        _PreferenceSpec(
          'Back up watch state',
          'Include watch history and playback positions.',
          'watch_state',
        ),
        _PreferenceSpec(
          'Back up collections',
          'Include custom collection membership and ordering.',
          'collections',
        ),
        _PreferenceSpec(
          'Back up Home and Details layouts',
          'Include all profile UI customization.',
          'ui_layouts',
        ),
      ],
    ),
    _PlatformCategory(
      'Library Intelligence',
      'Tune recommendation and discovery behavior for this profile.',
      Icons.auto_awesome_rounded,
      'intelligence',
      [
        _PreferenceSpec(
          'Smart recommendations',
          'Use watch behavior and metadata to rank recommendations.',
          'smart_recommendations',
        ),
        _PreferenceSpec(
          'Recommendation diversity',
          'Avoid repeatedly recommending the same types of titles.',
          'diversity',
        ),
        _PreferenceSpec(
          'Because you watched',
          'Show explanation labels for recommendation decisions.',
          'because_you_watched',
        ),
        _PreferenceSpec(
          'Franchise progress',
          'Track progress across collections and franchises.',
          'franchise_progress',
        ),
      ],
    ),
    _PlatformCategory(
      'Search & Discovery',
      'Make title, localized-title and metadata discovery more flexible.',
      Icons.manage_search_rounded,
      'search',
      [
        _PreferenceSpec(
          'Natural-language search',
          'Interpret queries such as “unwatched sci-fi from the 2000s”.',
          'natural_language',
        ),
        _PreferenceSpec(
          'Localized title aliases',
          'Match original, translated and localized titles.',
          'localized_aliases',
        ),
        _PreferenceSpec(
          'Actor and crew search',
          'Search cast, directors and writers from one search field.',
          'people_search',
        ),
        _PreferenceSpec(
          'Search explanations',
          'Explain why a title matched the current query.',
          'explain_matches',
        ),
      ],
    ),
    _PlatformCategory(
      'Collection Studio',
      'Control collection ordering, versions and automatic playback.',
      Icons.collections_bookmark_rounded,
      'collections',
      [
        _PreferenceSpec(
          'Auto-play collection',
          'Continue to the next collection item automatically.',
          'autoplay_collection',
        ),
        _PreferenceSpec(
          'Use release order',
          'Prefer release order when a collection does not specify one.',
          'release_order',
        ),
        _PreferenceSpec(
          'Prefer highest quality',
          'Choose the highest available version when versions are equivalent.',
          'highest_quality',
        ),
        _PreferenceSpec(
          'Auto-advance near credits',
          'Offer the next collection item near the end of credits.',
          'credits_advance',
        ),
      ],
    ),
    _PlatformCategory(
      'Live Sports',
      'Tune the global live-sports experience without changing broadcast rights.',
      Icons.sports_soccer_rounded,
      'sports',
      [
        _PreferenceSpec(
          'Show Live Sports on Home',
          'Keep the sports section available on this profile.',
          'show_on_home',
        ),
        _PreferenceSpec(
          'Only show when live',
          'Hide the Home sports section when no authorized game is live.',
          'only_when_live',
        ),
        _PreferenceSpec(
          'Sports alerts',
          'Notify about followed teams and live-game starts.',
          'alerts',
        ),
        _PreferenceSpec(
          'Enable multiview',
          'Allow multiple authorized live games to be presented together.',
          'multiview',
        ),
      ],
    ),
    _PlatformCategory(
      'Privacy & Profile',
      'Control what this profile shares with other profiles.',
      Icons.privacy_tip_rounded,
      'privacy',
      [
        _PreferenceSpec(
          'Share activity',
          'Allow other profiles to see recent activity.',
          'share_activity',
        ),
        _PreferenceSpec(
          'Share reactions',
          'Allow other profiles to see reactions and likes.',
          'share_reactions',
        ),
        _PreferenceSpec(
          'Share watch history',
          'Allow shared recommendations to use this profile history.',
          'share_history',
        ),
        _PreferenceSpec(
          'Profile PIN',
          'Require a PIN before opening this profile.',
          'profile_pin',
        ),
      ],
    ),
    _PlatformCategory(
      'Kids Safety',
      'Age-aware controls and safer collections for child profiles.',
      Icons.child_care_rounded,
      'kids',
      [
        _PreferenceSpec(
          'Kids profile mode',
          'Enable child-oriented navigation and safer defaults.',
          'kids_mode',
        ),
        _PreferenceSpec(
          'Content age filters',
          'Filter titles above the selected profile age rating.',
          'age_filters',
        ),
        _PreferenceSpec(
          'Kids safe collections',
          'Limit automatic collections to approved safe titles.',
          'safe_collections',
        ),
        _PreferenceSpec(
          'Require PIN for mature content',
          'Require the profile PIN before showing restricted content.',
          'mature_pin',
        ),
        _PreferenceSpec(
          'Legacy / older-movie review',
          'Treat older titles as requiring extra review instead of trusting the original rating alone.',
          'legacy_review',
        ),
        _PreferenceSpec(
          'Nudity & partial nudity',
          'Block or require approval for titles with nudity or partial nudity.',
          'nudity',
        ),
        _PreferenceSpec(
          'Sexual content & sexualized imagery',
          'Block or require approval for sexual content, sexualized imagery and suggestive material.',
          'sexual_content',
        ),
        _PreferenceSpec(
          'Violence & gore',
          'Apply an additional safety check for violence, blood and graphic gore.',
          'violence_gore',
        ),
        _PreferenceSpec(
          'Profanity',
          'Apply a configurable profanity warning/filter in addition to age ratings.',
          'profanity',
        ),
        _PreferenceSpec(
          'Alcohol, drugs & smoking',
          'Flag substance use and smoking even when the title has a mild age rating.',
          'substances',
        ),
        _PreferenceSpec(
          'Horror & disturbing imagery',
          'Flag frightening, disturbing or intense imagery independently of the official rating.',
          'disturbing',
        ),
        _PreferenceSpec(
          'Suggestive dialogue & themes',
          'Flag mature jokes, suggestive dialogue and adult themes that may not raise the official rating.',
          'suggestive_themes',
        ),
        _PreferenceSpec(
          'Show parent content warnings',
          'Display detected content categories before playback so a parent can decide.',
          'parent_warnings',
        ),
        _PreferenceSpec(
          'Require approval for incomplete metadata',
          'Do not assume a title is safe when content metadata is missing or uncertain.',
          'incomplete_metadata',
        ),
        _PreferenceSpec(
          'Compare physical-disc rating',
          'Compare DVD/Blu-ray packaging ratings with current metadata before allowing child playback.',
          'disc_rating_compare',
        ),
        _PreferenceSpec(
          'Ask before playing flagged titles',
          'Send flagged titles to parent approval instead of silently allowing playback.',
          'approval_queue',
        ),
      ],
    ),
    _PlatformCategory(
      'Performance',
      'Tune animation, image loading and device workload.',
      Icons.speed_rounded,
      'performance',
      [
        _PreferenceSpec(
          'Smooth animations',
          'Use animated transitions throughout the application.',
          'animations',
        ),
        _PreferenceSpec(
          'Preload artwork',
          'Prefetch nearby poster and backdrop artwork when possible.',
          'preload_artwork',
        ),
        _PreferenceSpec(
          'Reduce motion',
          'Minimize nonessential UI animation for lower device workload.',
          'reduce_motion',
          defaultValue: false,
        ),
        _PreferenceSpec(
          'Fast Home mode',
          'Prefer fewer simultaneous Home queries and effects.',
          'fast_home',
          defaultValue: false,
        ),
      ],
    ),
  ];

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Platform Expansion'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'NEXT PLATFORM LAYER',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Profile-scoped controls for security, playback, TV, '
                    'notifications, backup, discovery, collections, sports, '
                    'privacy, kids safety and performance.',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Active profile: '
                    '${AppController.instance.currentProfile?.name ?? 'Default'}',
                    style: const TextStyle(color: Colors.white60),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          ..._categories.map(
            (category) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: Icon(category.icon),
                title: Text(
                  category.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(category.description),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _PlatformCategoryScreen(
                      category: category,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.file_present_rounded),
              title: const Text('Backup Manifest Preview'),
              subtitle: const Text(
                'Preview the profile-scoped settings that will be backed up.',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _showBackupPreview(context),
            ),
          ),
        ],
      ),
    );
  }

  /// Performs `_showBackupPreview` for this feature. Update this documentation when its contract changes.
  void _showBackupPreview(BuildContext context) {
    final json = const JsonEncoder.withIndent('  ').convert(
      PlatformPreferenceStore.snapshot(),
    );
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Backup Manifest'),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: SelectableText(
              json.isEmpty ? '{\n  "settings": {}\n}' : json,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: json));
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Backup manifest copied to clipboard.'),
                  ),
                );
              }
            },
            child: const Text('COPY'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('DONE'),
          ),
        ],
      ),
    );
  }
}

class _PlatformCategoryScreen extends StatefulWidget {
  final _PlatformCategory category;

  const _PlatformCategoryScreen({required this.category});

  @override
  State<_PlatformCategoryScreen> createState() =>
      _PlatformCategoryScreenState();
}

class _PlatformCategoryScreenState extends State<_PlatformCategoryScreen> {
  late Map<String, bool> values;

  @override
  /// Performs `initState` for this feature. Update this documentation when its contract changes.
  void initState() {
    super.initState();
    values = {
      for (final item in widget.category.items)
        item.setting: PlatformPreferenceStore.getBool(
          widget.category.key,
          item.setting,
          fallback: item.defaultValue,
        ),
    };
  }

  /// Performs `_set` for this feature. Update this documentation when its contract changes.
  Future<void> _set(_PreferenceSpec item, bool value) async {
    setState(() => values[item.setting] = value);
    await PlatformPreferenceStore.setBool(
      widget.category.key,
      item.setting,
      value,
    );
  }

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.category.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(widget.category.description),
            ),
          ),
          const SizedBox(height: 12),
          ...widget.category.items.map(
            (item) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: SwitchListTile.adaptive(
                value: values[item.setting] ?? item.defaultValue,
                onChanged: (value) => _set(item, value),
                title: Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(item.description),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlatformCategory {
  final String title;
  final String description;
  final IconData icon;
  final String key;
  final List<_PreferenceSpec> items;

  const _PlatformCategory(
    this.title,
    this.description,
    this.icon,
    this.key,
    this.items,
  );
}

class _PreferenceSpec {
  final String title;
  final String description;
  final String setting;
  final bool defaultValue;

  const _PreferenceSpec(
    this.title,
    this.description,
    this.setting, {
    this.defaultValue = true,
  });
}
