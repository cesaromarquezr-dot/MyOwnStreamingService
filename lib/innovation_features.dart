// Consolidated feature module for platform settings, capability catalog,
// ultimate feature screens, ultimate platform panels, discovery and recaps,
// and the feature roadmap. Keep these related screens together to reduce
// top-level lib/ file fragmentation without removing their functionality.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_core.dart';
import 'genre_system.dart';
import 'localization.dart';
import 'supabase/supabase_config.dart';
import 'dart:math' as math;
import 'music.dart';
import 'details.dart';
import 'package:url_launcher/url_launcher.dart';
import 'feature_center.dart';
import 'device_features.dart';
import 'remote_access.dart';
import 'main.dart' show CustomizeHomeScreen;
import 'music_achievements.dart';
import 'home_server.dart';
import 'storage_dashboard.dart';
import 'cinematic_discovery_studio.dart';
import 'core/services/automatic_backup_service.dart';

// Consolidated from lib/platform_expansion.dart.
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
        title: const UniversalText('Platform Expansion'),
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
                  const UniversalText('NEXT PLATFORM LAYER',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const UniversalText('Profile-scoped controls for security, playback, TV, '
                    'notifications, backup, discovery, collections, '
                    'privacy, kids safety and performance.',
                  ),
                  const SizedBox(height: 12),
                  UniversalText('Active profile: '
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
              title: const UniversalText('Backup Manifest Preview'),
              subtitle: const UniversalText('Preview the profile-scoped settings that will be backed up.',
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
        title: const UniversalText('Backup Manifest'),
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
                  SnackBar(
                    content: UniversalText('Backup manifest copied to clipboard.'),
                  ),
                );
              }
            },
            child: const UniversalText('COPY'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const UniversalText('DONE'),
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


// Consolidated from lib/expanded_platform.dart.
/// Delivery state for capabilities tracked by the expanded-platform roadmap.
enum CapabilityStage { foundation, existing, planned }

@immutable
class PlatformCapability {
  const PlatformCapability({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.stage,
    required this.icon,
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final CapabilityStage stage;
  final IconData icon;
}

/// Single source of truth for the next-wave platform capability inventory.
/// Existing means the project already has a related feature surface; it does
/// not claim every production integration is complete.
class ExpandedPlatformCatalog {
  ExpandedPlatformCatalog._();

  static const capabilities = <PlatformCapability>[
    PlatformCapability(id: 'hey_media_agents', title: 'Hey Media Agent Skills', description: 'Permission-aware orchestration across discovery, playback, library, social and commerce.', category: 'Hey Media AI', stage: CapabilityStage.foundation, icon: Icons.auto_awesome),
    PlatformCapability(id: 'scene_navigation', title: 'Smart Scene Navigation', description: 'Searchable scenes, chapter jumps, bookmarks and spoiler-aware results.', category: 'Media', stage: CapabilityStage.planned, icon: Icons.movie_filter),
    PlatformCapability(id: 'multi_room', title: 'Multi-Room Entertainment', description: 'Authorized device discovery, room preferences and playback handoff.', category: 'Devices', stage: CapabilityStage.planned, icon: Icons.speaker_group),
    PlatformCapability(id: 'connection_graph', title: 'Entertainment Connection Graph', description: 'Connect titles, cast, crew, artists, soundtracks and related products.', category: 'Discovery', stage: CapabilityStage.foundation, icon: Icons.hub),
    PlatformCapability(id: 'watch_activities', title: 'Trivia and Watch-Along Activities', description: 'Optional quizzes, polls and spoiler-aware party activities.', category: 'Social', stage: CapabilityStage.planned, icon: Icons.quiz),
    PlatformCapability(id: 'activity_timeline', title: 'Personal Entertainment Timeline', description: 'Private, editable activity history with export and visibility controls.', category: 'Profiles', stage: CapabilityStage.foundation, icon: Icons.timeline),
    PlatformCapability(id: 'achievements', title: 'Digital Collectibles and Achievements', description: 'Cosmetic milestones and transparent community achievements.', category: 'Profiles', stage: CapabilityStage.planned, icon: Icons.workspace_premium),
    PlatformCapability(id: 'structured_reviews', title: 'Structured Reviews', description: 'Category ratings, spoiler labels, abuse reporting and verified-purchase signals.', category: 'Community', stage: CapabilityStage.foundation, icon: Icons.rate_review),
    PlatformCapability(id: 'library_health', title: 'Library Health Assistant', description: 'Detect duplicate imports, missing episodes, metadata mismatches and unavailable files.', category: 'Personal Library', stage: CapabilityStage.foundation, icon: Icons.health_and_safety),
    PlatformCapability(id: 'language_accessibility', title: 'Language and Accessibility Matching', description: 'Per-profile language, caption, subtitle, audio-description and text preferences.', category: 'Accessibility', stage: CapabilityStage.foundation, icon: Icons.closed_caption),
    PlatformCapability(id: 'restaurant_confidence', title: 'Restaurant Confidence Tools', description: 'Ingredient and allergen details with staff confirmation for uncertain requests.', category: 'Food Delivery', stage: CapabilityStage.existing, icon: Icons.restaurant),
    PlatformCapability(id: 'smart_wishlists', title: 'Smart Wishlists and Price Alerts', description: 'Saved products, restock alerts and trustworthy price-change notifications.', category: 'Commerce', stage: CapabilityStage.planned, icon: Icons.favorite),
    PlatformCapability(id: 'order_center', title: 'Order and Receipt Center', description: 'Food and marketplace receipts, status, support, cancellations and refunds.', category: 'Commerce', stage: CapabilityStage.foundation, icon: Icons.receipt_long),
    PlatformCapability(id: 'creator_collaboration', title: 'Creator Collaboration Workspace', description: 'Shared drafts, assigned reviews, assets, revision history and publishing schedules.', category: 'Creators', stage: CapabilityStage.planned, icon: Icons.groups),
    PlatformCapability(id: 'playback_diagnostics', title: 'Playback Diagnostics', description: 'Explain buffering, codec, network and media-availability problems.', category: 'Reliability', stage: CapabilityStage.foundation, icon: Icons.network_check),
    PlatformCapability(id: 'privacy_devices', title: 'Privacy and Connected Device Center', description: 'Review sessions, authorized devices, permissions, AI memory and account activity.', category: 'Security', stage: CapabilityStage.foundation, icon: Icons.shield),
    PlatformCapability(id: 'integrations', title: 'Integration Platform', description: 'Scoped, revocable integrations with documented APIs and rate limits.', category: 'Platform', stage: CapabilityStage.planned, icon: Icons.extension),
    PlatformCapability(id: 'feature_flags', title: 'Feature Flags and Staged Rollouts', description: 'Enable capabilities for internal testing or selected cohorts before general release.', category: 'Operations', stage: CapabilityStage.foundation, icon: Icons.flag),
    PlatformCapability(id: 'notifications', title: 'Unified Notification Engine', description: 'One preference center for social, orders, media jobs and reminders.', category: 'Platform', stage: CapabilityStage.foundation, icon: Icons.notifications),
    PlatformCapability(id: 'audit_trail', title: 'Security Audit Trail', description: 'Record sensitive operations without unnecessary personal-data collection.', category: 'Security', stage: CapabilityStage.foundation, icon: Icons.fact_check),
    PlatformCapability(id: 'metadata_reconciliation', title: 'Metadata Reconciliation', description: 'Merge disc, local-file and provider metadata while preserving provenance.', category: 'Media', stage: CapabilityStage.foundation, icon: Icons.merge_type),
    PlatformCapability(id: 'graceful_degradation', title: 'Graceful Degradation', description: 'Keep unrelated features usable when an external service or NAS is unavailable.', category: 'Reliability', stage: CapabilityStage.foundation, icon: Icons.offline_bolt),
    PlatformCapability(id: 'hey_discover', title: 'Hey Discover Universal Search', description: 'Search movies, TV, music, creators, products, restaurants and events with natural-language filters.', category: 'Discovery', stage: CapabilityStage.foundation, icon: Icons.search),
    PlatformCapability(id: 'universal_media_vault', title: 'Universal Media Vault', description: 'Unify owned media availability, editions, track metadata, import history and secure TrueNAS streaming.', category: 'Personal Library', stage: CapabilityStage.existing, icon: Icons.video_library),
    PlatformCapability(id: 'collector_collection', title: 'Collector Collection Manager', description: 'Catalog physical discs and editions, condition, purchase details, duplicates and exportable inventory.', category: 'Personal Library', stage: CapabilityStage.planned, icon: Icons.collections_bookmark),
    PlatformCapability(id: 'advanced_player', title: 'Advanced Player Toolkit', description: 'Track selection, subtitle sync, chapters, playback speed, skip controls and cross-device resume.', category: 'Media', stage: CapabilityStage.existing, icon: Icons.play_circle),
    PlatformCapability(id: 'watch_parties', title: 'Watch Parties 2.0', description: 'Synchronized viewing, host controls, invitations, chat, reactions and scheduled rooms.', category: 'Social', stage: CapabilityStage.existing, icon: Icons.groups),
    PlatformCapability(id: 'hey_marathon', title: 'Hey Marathon Planner', description: 'Build viewing schedules and optional themed meal and merchandise plans.', category: 'Discovery', stage: CapabilityStage.existing, icon: Icons.event_available),
    PlatformCapability(id: 'creator_studio', title: 'Creator Studio', description: 'Manage uploads, drafts, captions, thumbnails, publishing, analytics and eligible monetization.', category: 'Creators', stage: CapabilityStage.planned, icon: Icons.video_library),
    PlatformCapability(id: 'home_theater', title: 'Hey Home Theater', description: 'Coordinate compatible TVs, speakers and supported smart-home routines with explicit permissions.', category: 'Devices', stage: CapabilityStage.planned, icon: Icons.home),
    PlatformCapability(id: 'offline_travel', title: 'Offline and Travel Mode', description: 'Queue eligible downloads, manage device storage and reconcile progress after reconnecting.', category: 'Media', stage: CapabilityStage.planned, icon: Icons.download_for_offline),
    PlatformCapability(id: 'family_household', title: 'Family and Household Hub', description: 'Individual profiles, parent-approved purchases, age controls and shared household lists.', category: 'Profiles', stage: CapabilityStage.foundation, icon: Icons.family_restroom),
    PlatformCapability(id: 'events_experiences', title: 'Events and Experiences', description: 'Discover screenings, concerts and fan events with RSVP, accessibility details and ticket links.', category: 'Community', stage: CapabilityStage.planned, icon: Icons.event),
    PlatformCapability(id: 'gifting', title: 'Gifting and Shared Purchases', description: 'Gift eligible plans, merchandise and restaurant vouchers with group contributions and redemption tracking.', category: 'Commerce', stage: CapabilityStage.planned, icon: Icons.card_giftcard),
    PlatformCapability(id: 'activity_insights', title: 'Personal Activity and Insights', description: 'User-controlled watching, listening, collection, and community recaps with data export.', category: 'Profiles', stage: CapabilityStage.foundation, icon: Icons.insights),
    PlatformCapability(id: 'subscription_companion', title: 'Subscription and Spending Companion', description: 'Track authorized subscription details, renewals, spending summaries and optional budget alerts.', category: 'Commerce', stage: CapabilityStage.planned, icon: Icons.account_balance_wallet),
    PlatformCapability(id: 'seller_operations', title: 'Seller and Restaurant Operations', description: 'Manage menus, inventory, hours, order preparation, customer messages, promotions and refunds.', category: 'Commerce', stage: CapabilityStage.existing, icon: Icons.storefront),
    PlatformCapability(id: 'media_ops_control_plane', title: 'Media Operations Control Plane', description: 'Monitor import, metadata, thumbnail and transcode jobs with retries, failures and server health.', category: 'Operations', stage: CapabilityStage.foundation, icon: Icons.monitor_heart),
    PlatformCapability(id: 'music_studio', title: 'Music Studio', description: 'Artist pages, albums, playlists, lyrics and credits, connected to soundtracks and media titles.', category: 'Music', stage: CapabilityStage.existing, icon: Icons.music_note),
    PlatformCapability(id: 'membership_rewards', title: 'Unified Membership and Rewards', description: 'Transparent points and eligible benefits across platform plans, Shop purchases and food orders.', category: 'Commerce', stage: CapabilityStage.planned, icon: Icons.loyalty),
    PlatformCapability(id: 'trivia_activities', title: 'Fandom Trivia and Watch-Along Activities', description: 'Optional trivia, polls and predictions with spoiler-aware timing and accessibility settings.', category: 'Social', stage: CapabilityStage.planned, icon: Icons.quiz),
    PlatformCapability(id: 'privacy_ai_memory', title: 'Hey Media Memory Controls', description: 'Review, edit, disable and delete explicitly saved assistant preferences and memories.', category: 'Security', stage: CapabilityStage.foundation, icon: Icons.psychology),
    PlatformCapability(id: 'proactive_assistant', title: 'Hey Media Proactive Assistant', description: 'Permission-based suggestions for resumes, library fixes, events and watch-party preparation; always dismissible.', category: 'Hey Media AI', stage: CapabilityStage.planned, icon: Icons.lightbulb_outline),
    PlatformCapability(id: 'interactive_entertainment', title: 'Interactive Entertainment', description: 'Support provider-authorized branching stories, polls and interactive playback without changing ordinary video playback.', category: 'Media', stage: CapabilityStage.planned, icon: Icons.account_tree),
    PlatformCapability(id: 'franchise_timeline', title: 'Franchise and Universe Timeline', description: 'Organize connected titles by release, story chronology or recommended order with spoiler-aware warnings.', category: 'Discovery', stage: CapabilityStage.foundation, icon: Icons.timeline),
    PlatformCapability(id: 'custom_media_spaces', title: 'Custom Media Spaces', description: 'Create themed, shareable personal spaces with artwork, filters, curated media and explicit visibility.', category: 'Personal Library', stage: CapabilityStage.foundation, icon: Icons.dashboard_customize),
    PlatformCapability(id: 'nas_storage_intelligence', title: 'NAS Storage Intelligence', description: 'Track storage capacity, integrity checks, backup verification and health alerts without destructive automatic cleanup.', category: 'Operations', stage: CapabilityStage.planned, icon: Icons.storage),
    PlatformCapability(id: 'accessibility_companion', title: 'Accessibility Companion', description: 'Provide accessible navigation, high contrast, screen-reader semantics, reduced motion and compatible audio description controls.', category: 'Accessibility', stage: CapabilityStage.foundation, icon: Icons.accessibility_new),
    PlatformCapability(id: 'group_decisions', title: 'Group Decision Assistant', description: 'Help a group choose media using volunteered preferences without exposing private watch histories.', category: 'Social', stage: CapabilityStage.planned, icon: Icons.how_to_vote),
    PlatformCapability(id: 'media_provenance', title: 'Media Provenance and Version History', description: 'Track metadata sources, import history, confidence and reversible corrections without overwriting media binaries.', category: 'Media', stage: CapabilityStage.foundation, icon: Icons.history),
    PlatformCapability(id: 'marketplace_trust', title: 'Marketplace Trust Center', description: 'Support seller verification, transparent fees, dispute workflows, returns and listing authenticity signals.', category: 'Commerce', stage: CapabilityStage.planned, icon: Icons.verified_user),
    PlatformCapability(id: 'premieres_live_events', title: 'Premieres and Live Community Events', description: 'Schedule approved creator premieres, moderated live chat and Q&A with operational safeguards.', category: 'Creators', stage: CapabilityStage.planned, icon: Icons.live_tv),
    PlatformCapability(id: 'developer_integration_hub', title: 'Developer and Integration Hub', description: 'Manage documented APIs, scoped credentials, rate limits, test environments and revocable integrations.', category: 'Platform', stage: CapabilityStage.planned, icon: Icons.api),
    PlatformCapability(id: 'self_service_recovery', title: 'Self-Service Recovery Center', description: 'Help users diagnose playback and import failures, safely retry tasks and review service status.', category: 'Reliability', stage: CapabilityStage.planned, icon: Icons.build_circle),
    PlatformCapability(id: 'edition_intelligence', title: 'Collector Edition Intelligence', description: 'Track theatrical, extended, remastered and regional editions, disc formats, track layouts and extras without merging distinct cuts.', category: 'Personal Library', stage: CapabilityStage.foundation, icon: Icons.collections_bookmark),
    PlatformCapability(id: 'explainable_recommendations', title: 'Explainable Recommendations', description: 'Let users see and tune why media is recommended, with explicit feedback and privacy-preserving preference signals.', category: 'Discovery', stage: CapabilityStage.foundation, icon: Icons.auto_awesome),
    PlatformCapability(id: 'secure_media_gateway', title: 'Secure Media Access Gateway', description: 'Authorize private TrueNAS playback through a server-side gateway or short-lived scoped access; never expose NAS credentials to clients.', category: 'Security', stage: CapabilityStage.foundation, icon: Icons.vpn_key),
    PlatformCapability(id: 'unified_commerce_orchestration', title: 'Unified Commerce Orchestration', description: 'Share checkout, receipts, notifications, support, refund records and fraud controls while preserving dedicated restaurant and delivery workflows.', category: 'Commerce', stage: CapabilityStage.foundation, icon: Icons.shopping_cart_checkout),
    PlatformCapability(id: 'release_readiness', title: 'Release Readiness and Recovery', description: 'Gate releases on automated tests, migration checks, backups, observability, rollback plans and documented incident procedures.', category: 'Operations', stage: CapabilityStage.foundation, icon: Icons.check_circle),
  ];

  static List<PlatformCapability> inCategory(String category) =>
      capabilities.where((item) => item.category == category).toList();

  static Set<String> get categories =>
      capabilities.map((item) => item.category).toSet();
}

/// Bookmark for a timestamp or chapter in media the user is authorized to view.
@immutable
class MediaSceneBookmark {
  const MediaSceneBookmark({
    required this.id,
    required this.mediaKey,
    required this.positionMs,
    this.label,
    this.note,
    this.createdAt,
  });

  final String id;
  final String mediaKey;
  final int positionMs;
  final String? label;
  final String? note;
  final DateTime? createdAt;

  factory MediaSceneBookmark.fromJson(Map<String, dynamic> json) =>
      MediaSceneBookmark(
        id: json['id'] as String,
        mediaKey: json['media_key'] as String,
        positionMs: (json['position_ms'] as num).toInt(),
        label: json['label'] as String?,
        note: json['note'] as String?,
        createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
      );

  Map<String, dynamic> toInsertJson() => {
        'media_key': mediaKey,
        'position_ms': positionMs,
        if (label != null && label!.trim().isNotEmpty) 'label': label!.trim(),
        if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
      };
}

/// Explicitly user-managed assistant memory; do not store secrets or sensitive
/// profile inferences here. The UI should always support review and deletion.
@immutable
class HeyMediaMemoryEntry {
  const HeyMediaMemoryEntry({
    required this.id,
    required this.memoryKey,
    required this.memoryValue,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String memoryKey;
  final String memoryValue;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory HeyMediaMemoryEntry.fromJson(Map<String, dynamic> json) =>
      HeyMediaMemoryEntry(
        id: json['id'] as String,
        memoryKey: json['memory_key'] as String,
        memoryValue: json['memory_value'] as String,
        createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
        updatedAt: DateTime.tryParse('${json['updated_at'] ?? ''}'),
      );
}

/// Small persistence facade for new personal-platform features. RLS remains
/// the authority; callers must never pass or trust a client-supplied user ID.
class ExpandedPlatformRepository {
  ExpandedPlatformRepository._();
  static final ExpandedPlatformRepository instance =
      ExpandedPlatformRepository._();

  bool get isAvailable => SupabaseConfig.client != null;

  Future<List<MediaSceneBookmark>> sceneBookmarks(String mediaKey) async {
    final client = SupabaseConfig.client;
    if (client == null || client.auth.currentUser == null) return const [];
    final rows = await client
        .from('user_media_scene_bookmarks')
        .select('id,media_key,position_ms,label,note,created_at')
        .eq('media_key', mediaKey)
        .order('position_ms');
    return rows.map((row) => MediaSceneBookmark.fromJson(
        Map<String, dynamic>.from(row))).toList();
  }

  Future<MediaSceneBookmark?> addSceneBookmark({
    required String mediaKey,
    required int positionMs,
    String? label,
    String? note,
  }) async {
    final client = SupabaseConfig.client;
    if (client == null || client.auth.currentUser == null) return null;
    if (mediaKey.trim().isEmpty || positionMs < 0) {
      throw ArgumentError('A media key and non-negative position are required.');
    }
    final row = await client
        .from('user_media_scene_bookmarks')
        .insert(MediaSceneBookmark(
          id: '', mediaKey: mediaKey.trim(), positionMs: positionMs,
          label: label, note: note,
        ).toInsertJson())
        .select('id,media_key,position_ms,label,note,created_at')
        .single();
    return MediaSceneBookmark.fromJson(Map<String, dynamic>.from(row));
  }

  Future<List<HeyMediaMemoryEntry>> assistantMemory() async {
    final client = SupabaseConfig.client;
    if (client == null || client.auth.currentUser == null) return const [];
    final rows = await client
        .from('hey_media_memory_entries')
        .select('id,memory_key,memory_value,created_at,updated_at')
        .order('updated_at', ascending: false);
    return rows.map((row) => HeyMediaMemoryEntry.fromJson(
        Map<String, dynamic>.from(row))).toList();
  }

  Future<void> saveAssistantMemory({
    required String key,
    required String value,
  }) async {
    final client = SupabaseConfig.client;
    if (client == null || client.auth.currentUser == null) {
      throw StateError('Sign in before saving Hey Media memory.');
    }
    final normalizedKey = key.trim();
    final normalizedValue = value.trim();
    if (normalizedKey.isEmpty || normalizedValue.isEmpty) {
      throw ArgumentError('Memory key and value cannot be empty.');
    }
    if (normalizedKey.length > 100 || normalizedValue.length > 2000) {
      throw ArgumentError('Memory key or value exceeds the allowed length.');
    }
    await client.from('hey_media_memory_entries').upsert({
      'memory_key': normalizedKey,
      'memory_value': normalizedValue,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,memory_key');
  }

  Future<void> deleteAssistantMemory(String id) async {
    final client = SupabaseConfig.client;
    if (client == null || client.auth.currentUser == null) return;
    await client.from('hey_media_memory_entries').delete().eq('id', id);
  }


  Future<List<HeyMediaSuggestion>> assistantSuggestions() async {
    final client = SupabaseConfig.client;
    if (client == null || client.auth.currentUser == null) return const [];
    final rows = await client
        .from('user_hey_media_suggestions')
        .select('id,suggestion_type,title,body,status,expires_at')
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return rows.map((row) => HeyMediaSuggestion.fromJson(
        Map<String, dynamic>.from(row))).toList();
  }

  Future<void> dismissAssistantSuggestion(String id) async {
    final client = SupabaseConfig.client;
    if (client == null || client.auth.currentUser == null) return;
    if (id.trim().isEmpty) throw ArgumentError('Suggestion id is required.');
    await client.from('user_hey_media_suggestions').update({
      'status': 'dismissed',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id).eq('status', 'pending');
  }

  Future<List<UserMediaSpace>> mediaSpaces() async {
    final client = SupabaseConfig.client;
    if (client == null || client.auth.currentUser == null) return const [];
    final rows = await client.from('user_media_spaces')
        .select('id,title,description,visibility,created_at')
        .order('created_at', ascending: false);
    return rows.map((row) => UserMediaSpace.fromJson(
        Map<String, dynamic>.from(row))).toList();
  }

  Future<UserMediaSpace?> createMediaSpace({
    required String title,
    String? description,
    String visibility = 'private',
  }) async {
    final client = SupabaseConfig.client;
    if (client == null || client.auth.currentUser == null) {
      throw StateError('Sign in before creating a media space.');
    }
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty || normalizedTitle.length > 120) {
      throw ArgumentError('Media space title must be 1–120 characters.');
    }
    if (!const {'private', 'friends', 'public'}.contains(visibility)) {
      throw ArgumentError('Unsupported media space visibility.');
    }
    final row = await client.from('user_media_spaces').insert(
      UserMediaSpace(id: '', title: normalizedTitle, description: description,
        visibility: visibility).toInsertJson(),
    ).select('id,title,description,visibility,created_at').single();
    return UserMediaSpace.fromJson(Map<String, dynamic>.from(row));
  }


  Future<List<CollectorEdition>> collectorEditions() async {
    final client = SupabaseConfig.client;
    if (client == null || client.auth.currentUser == null) return const [];
    final rows = await client.from('user_media_collector_editions')
        .select('id,media_key,edition_title,disc_format,region_code,edition_details,condition_label,acquired_at,created_at')
        .order('created_at', ascending: false);
    return rows.map((row) => CollectorEdition.fromJson(
        Map<String, dynamic>.from(row))).toList();
  }

  Future<CollectorEdition?> saveCollectorEdition({
    required String mediaKey,
    required String editionTitle,
    String? discFormat,
    String? regionCode,
    String? conditionLabel,
    DateTime? acquiredAt,
    Map<String, dynamic> editionDetails = const {},
  }) async {
    final client = SupabaseConfig.client;
    if (client == null || client.auth.currentUser == null) {
      throw StateError('Sign in before saving a collector edition.');
    }
    if (mediaKey.trim().isEmpty || mediaKey.trim().length > 500) {
      throw ArgumentError('A valid media key is required.');
    }
    if (editionTitle.trim().isEmpty || editionTitle.trim().length > 200) {
      throw ArgumentError('Edition title must be 1–200 characters.');
    }
    final row = await client.from('user_media_collector_editions').insert({
      'media_key': mediaKey.trim(),
      'edition_title': editionTitle.trim(),
      if (discFormat != null && discFormat.trim().isNotEmpty)
        'disc_format': discFormat.trim(),
      if (regionCode != null && regionCode.trim().isNotEmpty)
        'region_code': regionCode.trim(),
      if (conditionLabel != null && conditionLabel.trim().isNotEmpty)
        'condition_label': conditionLabel.trim(),
      if (acquiredAt != null) 'acquired_at': acquiredAt.toUtc().toIso8601String(),
      'edition_details': editionDetails,
    }).select('id,media_key,edition_title,disc_format,region_code,edition_details,condition_label,acquired_at,created_at').single();
    return CollectorEdition.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> recordRecommendationFeedback({
    required String mediaKey,
    required String signal,
    String? recommendationSource,
    String? explanation,
  }) async {
    final client = SupabaseConfig.client;
    if (client == null || client.auth.currentUser == null) {
      throw StateError('Sign in before saving recommendation feedback.');
    }
    const allowedSignals = {'like', 'dislike', 'not_interested', 'already_seen', 'not_for_me'};
    if (mediaKey.trim().isEmpty || mediaKey.trim().length > 500) {
      throw ArgumentError('A valid media key is required.');
    }
    if (!allowedSignals.contains(signal)) {
      throw ArgumentError('Unsupported recommendation feedback signal.');
    }
    await client.from('user_recommendation_feedback').insert({
      'media_key': mediaKey.trim(),
      'signal': signal,
      if (recommendationSource != null && recommendationSource.trim().isNotEmpty)
        'recommendation_source': recommendationSource.trim(),
      if (explanation != null && explanation.trim().isNotEmpty)
        'explanation': explanation.trim(),
    });
  }

}


@immutable
class HeyMediaSuggestion {
  const HeyMediaSuggestion({
    required this.id,
    required this.suggestionType,
    required this.title,
    required this.body,
    this.status = 'pending',
    this.expiresAt,
  });

  final String id;
  final String suggestionType;
  final String title;
  final String body;
  final String status;
  final DateTime? expiresAt;

  factory HeyMediaSuggestion.fromJson(Map<String, dynamic> json) =>
      HeyMediaSuggestion(
        id: json['id'] as String,
        suggestionType: json['suggestion_type'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        status: (json['status'] as String?) ?? 'pending',
        expiresAt: json['expires_at'] == null
            ? null
            : DateTime.tryParse('${json['expires_at']}'),
      );
}

@immutable
class UserMediaSpace {
  const UserMediaSpace({
    required this.id,
    required this.title,
    this.description,
    this.visibility = 'private',
    this.createdAt,
  });

  final String id;
  final String title;
  final String? description;
  final String visibility;
  final DateTime? createdAt;

  factory UserMediaSpace.fromJson(Map<String, dynamic> json) => UserMediaSpace(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        visibility: (json['visibility'] as String?) ?? 'private',
        createdAt: json['created_at'] == null
            ? null
            : DateTime.tryParse('${json['created_at']}'),
      );

  Map<String, dynamic> toInsertJson() => {
        'title': title.trim(),
        if (description != null && description!.trim().isNotEmpty)
          'description': description!.trim(),
        'visibility': visibility,
      };
}

@immutable
class MediaMetadataProvenance {
  const MediaMetadataProvenance({
    required this.mediaKey,
    required this.fieldName,
    required this.sourceType,
    this.sourceReference,
    this.confidence,
    this.observedValue,
  });

  final String mediaKey;
  final String fieldName;
  final String sourceType;
  final String? sourceReference;
  final double? confidence;
  final Map<String, dynamic>? observedValue;

  factory MediaMetadataProvenance.fromJson(Map<String, dynamic> json) =>
      MediaMetadataProvenance(
        mediaKey: json['media_key'] as String,
        fieldName: json['field_name'] as String,
        sourceType: json['source_type'] as String,
        sourceReference: json['source_reference'] as String?,
        confidence: (json['confidence'] as num?)?.toDouble(),
        observedValue: json['observed_value'] == null
            ? null
            : Map<String, dynamic>.from(json['observed_value'] as Map),
      );
}

/// User-owned physical-media edition record. Details describe the edition and
/// never contain filesystem paths, credentials, or signed media URLs.
@immutable
class CollectorEdition {
  const CollectorEdition({
    required this.id,
    required this.mediaKey,
    required this.editionTitle,
    this.discFormat,
    this.regionCode,
    this.editionDetails = const {},
    this.conditionLabel,
    this.acquiredAt,
    this.createdAt,
  });

  final String id;
  final String mediaKey;
  final String editionTitle;
  final String? discFormat;
  final String? regionCode;
  final Map<String, dynamic> editionDetails;
  final String? conditionLabel;
  final DateTime? acquiredAt;
  final DateTime? createdAt;

  factory CollectorEdition.fromJson(Map<String, dynamic> json) => CollectorEdition(
        id: json['id'] as String,
        mediaKey: json['media_key'] as String,
        editionTitle: json['edition_title'] as String,
        discFormat: json['disc_format'] as String?,
        regionCode: json['region_code'] as String?,
        editionDetails: json['edition_details'] is Map
            ? Map<String, dynamic>.from(json['edition_details'] as Map)
            : const {},
        conditionLabel: json['condition_label'] as String?,
        acquiredAt: json['acquired_at'] == null
            ? null
            : DateTime.tryParse('${json['acquired_at']}'),
        createdAt: json['created_at'] == null
            ? null
            : DateTime.tryParse('${json['created_at']}'),
      );
}

/// Explicit user feedback used to tune recommendations; it is not a sensitive
/// inferred profile and remains private to the authenticated user.
@immutable
class RecommendationFeedback {
  const RecommendationFeedback({
    required this.mediaKey,
    required this.signal,
    this.recommendationSource,
    this.explanation,
  });

  final String mediaKey;
  final String signal;
  final String? recommendationSource;
  final String? explanation;

  Map<String, dynamic> toInsertJson() => {
        'media_key': mediaKey.trim(),
        'signal': signal,
        if (recommendationSource != null && recommendationSource!.trim().isNotEmpty)
          'recommendation_source': recommendationSource!.trim(),
        if (explanation != null && explanation!.trim().isNotEmpty)
          'explanation': explanation!.trim(),
      };
}

/// In-app index for the expanded capabilities. The stage labels are honest
/// delivery metadata; entries marked planned are not presented as finished.
class ExpandedPlatformScreen extends StatefulWidget {
  const ExpandedPlatformScreen({super.key});

  @override
  State<ExpandedPlatformScreen> createState() => _ExpandedPlatformScreenState();
}

class _ExpandedPlatformScreenState extends State<ExpandedPlatformScreen> {
  String selectedCategory = 'All';

  String _stageLabel(CapabilityStage stage) => switch (stage) {
        CapabilityStage.existing => 'Existing surface',
        CapabilityStage.foundation => 'Foundation added',
        CapabilityStage.planned => 'Needs implementation',
      };

  Color _stageColor(BuildContext context, CapabilityStage stage) => switch (stage) {
        CapabilityStage.existing => Colors.green,
        CapabilityStage.foundation => Theme.of(context).colorScheme.primary,
        CapabilityStage.planned => Theme.of(context).colorScheme.outline,
      };

  @override
  Widget build(BuildContext context) {
    final categories = ['All', ...(ExpandedPlatformCatalog.categories.toList()..sort())];
    final items = selectedCategory == 'All'
        ? ExpandedPlatformCatalog.capabilities
        : ExpandedPlatformCatalog.inCategory(selectedCategory);
    return Scaffold(
      appBar: AppBar(title: const Text('Expanded Platform')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'New capability foundations and the remaining implementation roadmap.',
              style: TextStyle(fontSize: 14),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: categories.map((category) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(category),
                  selected: selectedCategory == category,
                  onSelected: (_) => setState(() => selectedCategory = category),
                ),
              )).toList(),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                final color = _stageColor(context, item.stage);
                return Card(
                  child: ListTile(
                    isThreeLine: true,
                    leading: CircleAvatar(child: Icon(item.icon)),
                    title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.description),
                          const SizedBox(height: 6),
                          Wrap(spacing: 6, runSpacing: 4, children: [
                            Chip(label: Text(item.category), visualDensity: VisualDensity.compact),
                            Chip(
                              label: Text(_stageLabel(item.stage)),
                              labelStyle: TextStyle(color: color, fontSize: 12),
                              visualDensity: VisualDensity.compact,
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


// Consolidated from lib/ultimate_features.dart.
class UltimateFeaturesScreen extends StatefulWidget {
  const UltimateFeaturesScreen({super.key});

  @override
  State<UltimateFeaturesScreen> createState() =>
      _UltimateFeaturesScreenState();
}

class _UltimateFeaturesScreenState extends State<UltimateFeaturesScreen> {
  final controller = AppController.instance;

  bool autoChannel = true;
  bool wifiOnly = true;
  bool twoFactor = false;
  bool childSafe = false;

  String channel = 'My Streaming Channel';

  int get movies => controller.library
      .where(
        (m) => m.type.toLowerCase().contains('movie'),
      )
      .length;

  int get shows => math.max(
        0,
        controller.library.length - movies,
      );

  int get watched => controller.watched.length;

  int get liked => controller.liked.length;

  int get profiles => controller.currentAccount?.profiles.length ?? 0;

  int get musicTracks => MusicLibraryStore.instance.tracks.length;

  int get musicPlaylists =>
      MusicLibraryStore.instance.playlists.length;

  double get watchedPercentage {
    if (controller.library.isEmpty) return 0;

    return (watched / controller.library.length)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  /// Performs `_push` for this feature. Update this documentation when its contract changes.
  Future<void> _push(Widget page) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => page,
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  /// Performs `_snack` for this feature. Update this documentation when its contract changes.
  void _snack(
    String message, {
    IconData icon = Icons.info_outline_rounded,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          duration: const Duration(seconds: 3),
          content: Row(
            children: [
              Icon(
                icon,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(message),
              ),
            ],
          ),
        ),
      );
  }

  /// Performs `_aiConcierge` for this feature. Update this documentation when its contract changes.
  Future<void> _aiConcierge() async {
    final textController = TextEditingController();

    final request = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.auto_awesome_rounded),
              SizedBox(width: 10),
              Expanded(
                child: UniversalText('AI Movie Concierge'),
              ),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const UniversalText(
                  'Ask about your own library. Describe what you want to watch and the concierge can help narrow it down.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: textController,
                  autofocus: true,
                  maxLines: 3,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    hintText: tr('What do you want to watch?'),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(bottom: 40),
                      child: Icon(Icons.chat_bubble_outline_rounded),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) {
                    Navigator.pop(
                      dialogContext,
                      textController.text.trim(),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const UniversalText('CANCEL'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  textController.text.trim(),
                );
              },
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const UniversalText('ASK'),
            ),
          ],
        );
      },
    );

    textController.dispose();

    if (!mounted || request == null) return;

    final query = request.trim();

    if (controller.library.isEmpty) {
      _snack(
        'Add a movie or show first so the concierge has something to work with.',
        icon: Icons.library_add_outlined,
      );
      return;
    }

    final random = math.Random();

    final matching = query.isEmpty
        ? <MediaItem>[]
        : controller.library
              .where(
                (media) => media.title.toLowerCase().contains(
                  query.toLowerCase(),
                ),
              )
              .toList();

    final MediaItem pick;

    if (matching.isNotEmpty) {
      pick = matching[random.nextInt(matching.length)];
    } else {
      pick = controller.library[
          random.nextInt(controller.library.length)];
    }

    _snack(
      'Concierge suggestion: ${pick.title}',
      icon: Icons.auto_awesome_rounded,
    );
  }

  /// Performs `_roulette` for this feature. Update this documentation when its contract changes.
  void _roulette() {
    if (controller.library.isEmpty) {
      _snack(
        'Add some movies or shows first.',
        icon: Icons.library_add_outlined,
      );
      return;
    }

    final random = math.Random();
    final pick = controller.library[
        random.nextInt(controller.library.length)];

    _snack(
      'Tonight’s pick: ${pick.title}',
      icon: Icons.casino_outlined,
    );
  }

  /// Performs `_battle` for this feature. Update this documentation when its contract changes.
  Future<void> _battle() async {
    if (controller.library.length < 2) {
      _snack(
        'Add at least two titles for a Movie Battle.',
        icon: Icons.library_add_outlined,
      );
      return;
    }

    final random = math.Random();

    final a = controller.library[
        random.nextInt(controller.library.length)];

    MediaItem b = controller.library[
        random.nextInt(controller.library.length)];

    while (b.id == a.id) {
      b = controller.library[
          random.nextInt(controller.library.length)];
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.flash_on_outlined),
              SizedBox(width: 10),
              UniversalText('Movie Battle'),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _battleTitleCard(a.title),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: UniversalText(
                    'VS',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                _battleTitleCard(b.title),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const UniversalText('CLOSE'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);

                _snack(
                  'Battle recorded between ${a.title} and ${b.title}.',
                  icon: Icons.emoji_events_outlined,
                );
              },
              icon: const Icon(Icons.how_to_vote_outlined),
              label: const UniversalText('PICK ONE'),
            ),
          ],
        );
      },
    );
  }

  Widget _battleTitleCard(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.55),
      ),
      child: Text(
        title,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  /// Performs `_security` for this feature. Update this documentation when its contract changes.
  void _security() {
    _push(
      const SecurityCenterScreen(),
    );
  }

  /// Performs `_owner` for this feature. Update this documentation when its contract changes.
  void _owner() {
    _push(
      const OwnerDashboardScreen(),
    );
  }

  /// Performs `_channelScreen` for this feature. Update this documentation when its contract changes.
  void _channelScreen() {
    _push(
      ChannelScreen(
        channel: channel,
        library: controller.library,
      ),
    );
  }

  /// Performs `_stats` for this feature. Update this documentation when its contract changes.
  void _stats() {
    _push(
      const StatisticsScreen(),
    );
  }

  /// Performs `_showChannelNameDialog` for this feature. Update this documentation when its contract changes.
  Future<void> _showChannelNameDialog() async {
    final textController = TextEditingController(
      text: channel,
    );

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const UniversalText('Channel name'),
          content: TextField(
            controller: textController,
            autofocus: true,
            maxLength: 60,
            decoration: InputDecoration(
              hintText: tr('My Streaming Channel'),
              prefixIcon: const Icon(Icons.live_tv_rounded),
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (value) {
              Navigator.pop(
                dialogContext,
                value,
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const UniversalText('CANCEL'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  textController.text,
                );
              },
              child: const UniversalText('SAVE'),
            ),
          ],
        );
      },
    );

    textController.dispose();

    if (!mounted || result == null) return;

    final next = result.trim();

    setState(() {
      channel = next.isEmpty
          ? 'My Streaming Channel'
          : next;
    });

    _snack(
      'Channel name updated.',
      icon: Icons.check_circle_outline_rounded,
    );
  }

  /// Performs `_openPlaceholderFeature` for this feature. Update this documentation when its contract changes.
  void _openPlaceholderFeature(
    String title,
    String message,
  ) {
    _snack(
      '$title: $message',
      icon: Icons.auto_awesome_outlined,
    );
  }

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const UniversalText('Everything'),
            actions: [
              IconButton(
                onPressed: _aiConcierge,
                icon: const Icon(
                  Icons.auto_awesome_rounded,
                ),
                tooltip: tr('AI Concierge'),
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;

              return ListView(
                padding: EdgeInsets.fromLTRB(
                  wide ? 28 : 16,
                  12,
                  wide ? 28 : 16,
                  30,
                ),
                children: [
                  _hero(wide),

                  const SizedBox(height: 16),

                  if (wide)
                    _buildWideFeatureOverview()
                  else
                    _buildCompactFeatureOverview(),

                  const SizedBox(height: 10),

                  // ACCOUNT & SECURITY
                  _section(
                    'Account & Security',
                    Icons.shield_outlined,
                    [
                      _tile(
                        Icons.admin_panel_settings_outlined,
                        'Owner Dashboard',
                        'Server, profiles, storage, devices, jobs and account controls',
                        _owner,
                      ),
                      _tile(
                        Icons.security_outlined,
                        'Security Center',
                        'Sessions, suspicious logins, trusted devices, 2FA and sign out everywhere',
                        _security,
                      ),
                      _switchTile(
                        Icons.verified_user_outlined,
                        'Two-factor authentication',
                        'Add an extra sign-in step',
                        twoFactor,
                        (value) {
                          setState(() {
                            twoFactor = value;
                          });

                          _snack(
                            value
                                ? '2FA enabled for this session.'
                                : '2FA disabled.',
                            icon: value
                                ? Icons.verified_user_outlined
                                : Icons.info_outline_rounded,
                          );
                        },
                      ),
                    ],
                  ),

                  // YOUR LIBRARY
                  _section(
                    'Your Library',
                    Icons.video_library_outlined,
                    [
                      _tile(
                        Icons.insights_outlined,
                        'Advanced Statistics',
                        '$movies movies • $shows shows • $watched watched',
                        _stats,
                      ),
                      _tile(
                        Icons.collections_bookmark_outlined,
                        'Smart Collections',
                        'Manual, shared and automatic collections',
                        () {
                          _openPlaceholderFeature(
                            'Smart Collections',
                            'Use Discover, Collections & Wrapped to manage them.',
                          );
                        },
                      ),
                      _tile(
                        Icons.map_outlined,
                        'Movie Map',
                        'Explore your library by filming and story locations',
                        () {
                          _push(
                            const MovieMapScreen(),
                          );
                        },
                      ),
                      _tile(
                        Icons.history_toggle_off,
                        'Movie Time Machine',
                        'Jump back through your watching history',
                        () {
                          _openPlaceholderFeature(
                            'Movie Time Machine',
                            'Your earliest watched titles are ready to explore.',
                          );
                        },
                      ),
                    ],
                  ),

                  // FUN & SOCIAL
                  _section(
                    'Fun & Social',
                    Icons.groups_outlined,
                    [
                      _tile(
                        Icons.casino_outlined,
                        'What Should We Watch?',
                        'Spin your shared library',
                        _roulette,
                      ),
                      _tile(
                        Icons.flash_on_outlined,
                        'Movie Battles',
                        'Put two titles head-to-head',
                        _battle,
                      ),
                      _tile(
                        Icons.quiz_outlined,
                        'Guess the Movie',
                        'Quiz mode using your library',
                        () {
                          _openPlaceholderFeature(
                            'Guess the Movie',
                            'A quiz can be generated from your library.',
                          );
                        },
                      ),
                      _tile(
                        Icons.people_outline,
                        'Who Knows You Best?',
                        'Compare profile watch habits',
                        () {
                          _openPlaceholderFeature(
                            'Who Knows You Best?',
                            'Profile activity is ready for comparison.',
                          );
                        },
                      ),
                      _tile(
                        Icons.emoji_events_outlined,
                        'Group Awards',
                        'Best binge, most adventurous, most rewatched and more',
                        () {
                          _openPlaceholderFeature(
                            'Group Awards',
                            'Awards can be calculated from account activity.',
                          );
                        },
                      ),
                      _tile(
                        Icons.chat_bubble_outline,
                        'Spoiler-Protected Chat',
                        'Hide messages until everyone reaches the scene',
                        () {
                          _openPlaceholderFeature(
                            'Spoiler-Protected Chat',
                            'Spoiler protection is ready for the next group chat.',
                          );
                        },
                      ),
                    ],
                  ),

                  // AI & DISCOVERY
                  _section(
                    'AI & Discovery',
                    Icons.auto_awesome_outlined,
                    [
                      _tile(
                        Icons.auto_awesome,
                        'AI Movie Concierge',
                        'Natural-language recommendations from your library',
                        _aiConcierge,
                      ),
                      _tile(
                        Icons.link_rounded,
                        'Because You Watched…',
                        'Build recommendation chains from your history',
                        () {
                          _openPlaceholderFeature(
                            'Because You Watched…',
                            'A recommendation chain can be generated from your history.',
                          );
                        },
                      ),
                      _tile(
                        Icons.account_tree_outlined,
                        'AI Actor Connections',
                        'Find connections between actors in your library',
                        () {
                          _openPlaceholderFeature(
                            'AI Actor Connections',
                            'Actor relationship data can be explored from your library.',
                          );
                        },
                      ),
                      _tile(
                        Icons.help_outline,
                        'Mystery Recommendation',
                        'Get a surprise title without seeing the reason first',
                        _roulette,
                      ),
                    ],
                  ),

                  // STREAMING CHANNEL
                  _section(
                    'My Streaming Channel',
                    Icons.live_tv_outlined,
                    [
                      _tile(
                        Icons.live_tv_rounded,
                        'My Streaming Channel',
                        'A fictional 24-hour channel generated from your library',
                        _channelScreen,
                      ),
                      _switchTile(
                        Icons.schedule_rounded,
                        'Automatic channel schedule',
                        'Keep generating a rolling schedule',
                        autoChannel,
                        (value) {
                          setState(() {
                            autoChannel = value;
                          });

                          _snack(
                            value
                                ? 'Automatic channel scheduling enabled.'
                                : 'Automatic channel scheduling paused.',
                            icon: Icons.schedule_rounded,
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.edit_outlined,
                        ),
                        title: const UniversalText(
                          'Channel name',
                        ),
                        subtitle: Text(
                          channel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                        ),
                        onTap: _showChannelNameDialog,
                      ),
                    ],
                  ),

                  // TRAVEL & DOWNLOADS
                  _section(
                    'Travel & Downloads',
                    Icons.flight_takeoff_outlined,
                    [
                      _switchTile(
                        Icons.wifi_rounded,
                        'Wi-Fi only downloads',
                        'Avoid cellular data when preparing a trip',
                        wifiOnly,
                        (value) {
                          setState(() {
                            wifiOnly = value;
                          });

                          _snack(
                            value
                                ? 'Downloads restricted to Wi-Fi.'
                                : 'Downloads may use cellular data.',
                            icon: Icons.wifi_rounded,
                          );
                        },
                      ),
                      _tile(
                        Icons.flight_takeoff_rounded,
                        'Road Trip / Flight Pack',
                        'Choose movies and entire TV seasons for offline viewing',
                        () {
                          _openPlaceholderFeature(
                            'Road Trip / Flight Pack',
                            'Open Devices, TV & Road Trip to manage downloads.',
                          );
                        },
                      ),
                      _tile(
                        Icons.directions_car_outlined,
                        'Car Mode',
                        'Bluetooth audio, compatible car displays and passenger viewing',
                        () {
                          _openPlaceholderFeature(
                            'Car Mode',
                            'Video should only be viewed by passengers.',
                          );
                        },
                      ),
                    ],
                  ),

                  // DEVICE EXPERIENCE
                  _section(
                    'Device Experience',
                    Icons.devices_other_outlined,
                    [
                      _tile(
                        Icons.computer_rounded,
                        'PC / Desktop',
                        'Website/desktop app with the exclusive disc-import workflow',
                        () {
                          _openPlaceholderFeature(
                            'PC / Desktop',
                            'Desktop includes disc reader, remote import and full library management.',
                          );
                        },
                      ),
                      _tile(
                        Icons.phone_iphone_rounded,
                        'Phone / Tablet',
                        'Streaming, offline downloads, casting and remote control',
                        () {
                          _openPlaceholderFeature(
                            'Phone / Tablet',
                            'Mobile includes downloads, casting and remote control.',
                          );
                        },
                      ),
                      _tile(
                        Icons.tv_rounded,
                        'TV',
                        'Big-screen experience with QR pairing and remote control',
                        () {
                          _openPlaceholderFeature(
                            'TV',
                            'The TV experience supports QR pairing and remote control.',
                          );
                        },
                      ),
                      _tile(
                        Icons.cable_rounded,
                        'HDMI / Cast fallback',
                        'Connect a computer to a TV by HDMI or cast from a mobile device',
                        () {
                          _openPlaceholderFeature(
                            'HDMI / Cast fallback',
                            'Use HDMI or supported casting when a TV app is unavailable.',
                          );
                        },
                      ),
                    ],
                  ),

                  // PLATFORM OPERATIONS
                  _section(
                    'Platform Operations',
                    Icons.dns_outlined,
                    [
                      _tile(
                        Icons.notifications_active_outlined,
                        'Notification Center',
                        'Email-style alerts for devices, security, imports and storage',
                        () {
                          _push(
                            const NotificationCenterScreen(),
                          );
                        },
                      ),
                      _tile(
                        Icons.cloud_queue_rounded,
                        'Backup & Recovery',
                        'Back up metadata, profiles, settings, collections and history',
                        () {
                          _push(
                            const BackupScreen(),
                          );
                        },
                      ),
                      _tile(
                        Icons.storage_rounded,
                        'Storage Manager',
                        'Track account-wide storage and requests for additional capacity',
                        () {
                          _openPlaceholderFeature(
                            'Storage Manager',
                            'Storage Manager uses the account-wide server storage bar.',
                          );
                        },
                      ),
                      _tile(
                        Icons.disc_full_outlined,
                        'Disc Import Center',
                        'Detect → identify → rip → process → completed',
                        () {
                          _openPlaceholderFeature(
                            'Disc Import Center',
                            'Disc importing is available on trusted desktop workers.',
                          );
                        },
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildWideFeatureOverview() {
    return Row(
      children: [
        Expanded(
          child: _overviewMetric(
            Icons.movie_outlined,
            '$movies',
            'Movies',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _overviewMetric(
            Icons.tv_outlined,
            '$shows',
            'Shows',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _overviewMetric(
            Icons.check_circle_outline_rounded,
            '$watched',
            'Watched',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _overviewMetric(
            Icons.favorite_border_rounded,
            '$liked',
            'Liked',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _overviewMetric(
            Icons.music_note_outlined,
            '$musicTracks',
            'Songs',
          ),
        ),
      ],
    );
  }

  Widget _buildCompactFeatureOverview() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _compactMetric(
          Icons.movie_outlined,
          '$movies movies',
        ),
        _compactMetric(
          Icons.tv_outlined,
          '$shows shows',
        ),
        _compactMetric(
          Icons.check_circle_outline_rounded,
          '$watched watched',
        ),
        _compactMetric(
          Icons.favorite_border_rounded,
          '$liked liked',
        ),
        _compactMetric(
          Icons.people_outline,
          '$profiles profiles',
        ),
      ],
    );
  }

  Widget _overviewMetric(
    IconData icon,
    String value,
    String label,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _compactMetric(
    IconData icon,
    String label,
  ) {
    return Chip(
      avatar: Icon(
        icon,
        size: 18,
      ),
      label: Text(label),
    );
  }

  /// Performs `_hero` for this feature. Update this documentation when its contract changes.
  Widget _hero(bool wide) {
    final account = controller.currentAccount;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.14),
              Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.30),
            ],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(
            wide ? 24 : 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: wide ? 58 : 52,
                    height: wide ? 58 : 52,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: wide ? 30 : 27,
                    ),
                  ),
                  const SizedBox(width: 15),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        UniversalText(
                          'Your streaming universe',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                          ),
                        ),
                        SizedBox(height: 7),
                        UniversalText(
                          'Everything in one place: library, devices, security, discovery and server controls.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _heroChip(
                    Icons.video_library_outlined,
                    '${controller.library.length} library titles',
                  ),
                  _heroChip(
                    Icons.people_outline,
                    '$profiles profiles',
                  ),
                  _heroChip(
                    Icons.music_note_outlined,
                    '$musicTracks songs',
                  ),
                  _heroChip(
                    account == null
                        ? Icons.person_off_outlined
                        : Icons.person_outline_rounded,
                    account == null
                        ? 'Signed out'
                        : 'Account connected',
                  ),
                ],
              ),

              const SizedBox(height: 18),

              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: watchedPercentage,
                        minHeight: 7,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    controller.library.isEmpty
                        ? 'No watch history'
                        : '${(watchedPercentage * 100).round()}% watched',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroChip(
    IconData icon,
    String label,
  ) {
    return Chip(
      avatar: Icon(
        icon,
        size: 17,
      ),
      label: Text(label),
    );
  }

  /// Performs `_section` for this feature. Update this documentation when its contract changes.
  Widget _section(
    String title,
    IconData icon,
    List<Widget> children,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              4,
              15,
              4,
              7,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 19,
                  color: Theme.of(context)
                      .colorScheme
                      .primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  /// Performs `_tile` for this feature. Update this documentation when its contract changes.
  Widget _tile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return ListTile(
      minVerticalPadding: 12,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 4,
      ),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.60),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 21,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(
          top: 3,
        ),
        child: Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
      ),
      onTap: onTap,
    );
  }

  /// Performs `_switchTile` for this feature. Update this documentation when its contract changes.
  Widget _switchTile(
    IconData icon,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 4,
      ),
      secondary: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.60),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 21,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(
          top: 3,
        ),
        child: Text(
          subtitle,
        ),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}

// -----------------------------------------------------------------------------
// OWNER DASHBOARD
// -----------------------------------------------------------------------------

class OwnerDashboardScreen extends StatelessWidget {
  const OwnerDashboardScreen({super.key});

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    final controller = AppController.instance;
    final account = controller.currentAccount;

    final double storageProgress =
        account == null || account.storageLimitBytes <= 0
            ? 0.0
            : (account.storageUsedBytes /
                      account.storageLimitBytes)
                  .clamp(0.0, 1.0)
                  .toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const UniversalText('Owner Dashboard'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const UniversalText(
                    'Account control center',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    account == null
                        ? 'No account loaded'
                        : account.email,
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: storageProgress,
                    minHeight: 10,
                  ),
                  const SizedBox(height: 8),
                  UniversalText(
                    '${_size(account?.storageUsedBytes ?? 0)} used of ${_size(account?.storageLimitBytes ?? 1000000000000)}',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        avatar: const Icon(
                          Icons.people_outline,
                          size: 17,
                        ),
                        label: UniversalText(
                          '${account?.profiles.length ?? 0} profiles',
                        ),
                      ),
                      const Chip(
                        avatar: Icon(
                          Icons.security_outlined,
                          size: 17,
                        ),
                        label: UniversalText('Security'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          _card(
            context,
            Icons.people,
            'Profiles',
            '${account?.profiles.length ?? 0} account-wide profiles',
          ),
          _card(
            context,
            Icons.devices,
            'Trusted devices',
            'Manage TVs, phones and remote computers',
          ),
          _card(
            context,
            Icons.disc_full,
            'Remote disc jobs',
            'Detect → identify → rip → process → complete',
          ),
          _card(
            context,
            Icons.email_outlined,
            'Email notifications',
            'Welcome, device, security, media and storage alerts',
          ),
          _card(
            context,
            Icons.payments_outlined,
            'Subscription',
            'USD base: \$10/month or \$100/year equivalent, localized at checkout',
          ),
          _card(
            context,
            Icons.storage,
            'Storage requests',
            'Approve or deny additional account-wide server capacity',
          ),
        ],
      ),
    );
  }

  /// Performs `_card` for this feature. Update this documentation when its contract changes.
  Widget _card(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(
          Icons.chevron_right,
        ),
        onTap: () {
          ScaffoldMessenger.of(
            context,
          )
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: UniversalText(
                  '$title controls opened.',
                ),
              ),
            );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// SECURITY
// -----------------------------------------------------------------------------

class SecurityCenterScreen extends StatelessWidget {
  const SecurityCenterScreen({
    super.key,
  });

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const UniversalText('Security Center'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.security_outlined,
                    size: 30,
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: UniversalText(
                      'Review account sessions, trusted devices and sign-in protections from one place.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          _securityCard(
            Icons.login,
            'Active sessions',
            'Review phones, browsers, TVs and remote computers.',
          ),
          _securityCard(
            Icons.warning_amber_rounded,
            'Suspicious login alerts',
            'Email includes location and time, for example London, England at 2:00 PM PST.',
          ),
          _securityCard(
            Icons.devices_other,
            'Trusted devices',
            'Revoke any device you no longer recognize.',
          ),
          _securityCard(
            Icons.password,
            'One-time codes',
            'Codes are sent to the registered email and expire after 10 minutes.',
          ),
          _securityCard(
            Icons.logout,
            'Sign out everywhere',
            'End all active sessions except the current one.',
          ),
          _securityCard(
            Icons.phonelink_lock,
            'Remote worker security',
            'Remote disc computers use a separate worker token, not the account password.',
          ),
        ],
      ),
    );
  }

  static Widget _securityCard(
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(
          Icons.chevron_right,
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// STATISTICS
// -----------------------------------------------------------------------------

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({
    super.key,
  });

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    final controller = AppController.instance;

    final ratings = controller.library
        .where(
          (media) => media.rating != null,
        )
        .map(
          (media) => media.rating!,
        )
        .toList();

    double averageRating = 0.0;

    if (ratings.isNotEmpty) {
      final total = ratings.fold<double>(
        0.0,
        (sum, rating) => sum + rating.toDouble(),
      );

      averageRating = total / ratings.length;
    }

    final movieCount = controller.library
        .where(
          (media) => media.type
              .toLowerCase()
              .contains('movie'),
        )
        .length;

    final showCount = math.max(
      0,
      controller.library.length - movieCount,
    );

    final streak = math.max(
      0,
      controller.watched.length,
    );

    return Scaffold(
      appBar: AppBar(
        title: const UniversalText(
          'Advanced Statistics',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _statisticsHero(
            context,
            controller,
            movieCount,
            showCount,
            averageRating,
          ),
          const SizedBox(height: 12),
          _stat(
            'Library titles',
            '${controller.library.length}',
          ),
          _stat(
            'Movies',
            '$movieCount',
          ),
          _stat(
            'TV shows',
            '$showCount',
          ),
          _stat(
            'Music songs',
            '${MusicLibraryStore.instance.tracks.length}',
          ),
          _stat(
            'Music playlists',
            '${MusicLibraryStore.instance.playlists.length}',
          ),
          _stat(
            'Watched',
            '${controller.watched.length}',
          ),
          _stat(
            'Liked',
            '${controller.liked.length}',
          ),
          _stat(
            'Average title rating',
            averageRating.toStringAsFixed(1),
          ),
          _stat(
            'Watch streak',
            '$streak day activity streak',
          ),
          const SizedBox(height: 18),
          const UniversalText(
            'Profile personality',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.person_outline_rounded,
                    size: 28,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      controller.watched.isEmpty
                          ? 'Explorer — start watching to build your personality card.'
                          : controller.watched.length > 10
                              ? 'Binge Master — you love finishing what you start.'
                              : 'Curious Viewer — you are building a diverse watch history.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statisticsHero(
    BuildContext context,
    AppController controller,
    int movieCount,
    int showCount,
    double averageRating,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const UniversalText(
              'Library snapshot',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const UniversalText(
              'A quick view of your account activity and library composition.',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _miniStat(
                    '$movieCount',
                    'Movies',
                  ),
                ),
                Expanded(
                  child: _miniStat(
                    '$showCount',
                    'Shows',
                  ),
                ),
                Expanded(
                  child: _miniStat(
                    '${controller.watched.length}',
                    'Watched',
                  ),
                ),
                Expanded(
                  child: _miniStat(
                    averageRating.toStringAsFixed(1),
                    'Rating',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(
    String value,
    String label,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  /// Performs `_stat` for this feature. Update this documentation when its contract changes.
  Widget _stat(
    String title,
    String value,
  ) {
    return Card(
      child: ListTile(
        title: Text(title),
        trailing: Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// MOVIE MAP
// -----------------------------------------------------------------------------

class MovieMapScreen extends StatelessWidget {
  const MovieMapScreen({
    super.key,
  });

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const UniversalText('Movie Map'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.12),
                    ),
                    child: const Icon(
                      Icons.public,
                      size: 45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const UniversalText(
                    'Your Movie Map',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const UniversalText(
                    'When location metadata is available, titles can be grouped by filming location and story setting.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(
                        const SnackBar(
                          content: UniversalText(
                            'Map metadata will populate as titles are identified.',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.explore,
                    ),
                    label: const UniversalText(
                      'EXPLORE',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// CHANNEL
// -----------------------------------------------------------------------------

class ChannelScreen extends StatelessWidget {
  final String channel;
  final List<MediaItem> library;

  const ChannelScreen({
    super.key,
    required this.channel,
    required this.library,
  });

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    final list = [...library];

    return Scaffold(
      appBar: AppBar(
        title: Text(channel),
      ),
      body: list.isEmpty
          ? const Center(
              child: UniversalText(
                'Add media to generate your channel.',
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final media = list[index];
                final hour = (index * 90) % 24;

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: UniversalText(
                        '${index + 1}',
                      ),
                    ),
                    title: Text(
                      media.title,
                    ),
                    subtitle: UniversalText(
                      '${hour.toString().padLeft(2, '0')}:00 • ${media.type}',
                    ),
                    trailing: const Icon(
                      Icons.play_arrow_rounded,
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// -----------------------------------------------------------------------------
// NOTIFICATION CENTER
// -----------------------------------------------------------------------------

class NotificationCenterScreen extends StatelessWidget {
  const NotificationCenterScreen({
    super.key,
  });

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const UniversalText(
          'Notification Center',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.notifications_active_outlined,
                    size: 28,
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: UniversalText(
                      'Important account, device, security, media and storage activity appears here.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          _notification(
            'Welcome',
            'Welcome to your own personal streaming service.',
          ),
          _notification(
            'New paired device',
            'A new trusted device was paired with your account.',
          ),
          _notification(
            'Suspicious login',
            'Suspicious login detected with location and time details.',
          ),
          _notification(
            'Media added',
            'A profile added a movie or TV show to the shared account library.',
          ),
          _notification(
            'One-time access code',
            'Your one-time access code was sent to the registered email.',
          ),
          _notification(
            'Storage approved',
            'Your request for more storage was successfully approved.',
          ),
        ],
      ),
    );
  }

  static Widget _notification(
    String title,
    String subtitle,
  ) {
    return Card(
      child: ListTile(
        leading: const Icon(
          Icons.email_outlined,
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(
          Icons.chevron_right,
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// BACKUP
// -----------------------------------------------------------------------------

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final AutomaticBackupService _backupService =
      AutomaticBackupService.instance;
  List<AutomaticBackupRecord> _backups = const [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _backupService.status.addListener(_handleBackupStatusChanged);
    unawaited(_reloadBackups());
  }

  void _handleBackupStatusChanged() {
    if (mounted) unawaited(_reloadBackups());
  }

  @override
  void dispose() {
    _backupService.status.removeListener(_handleBackupStatusChanged);
    super.dispose();
  }

  Future<void> _reloadBackups() async {
    try {
      final records = await _backupService.listBackups();
      if (mounted) setState(() => _backups = records);
    } catch (error) {
      if (mounted) _showMessage('Could not load local backups: $error');
    }
  }

  Future<void> _createBackup() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _backupService.backupNow();
      await _reloadBackups();
      if (mounted) _showMessage('Local backup created and checksum-verified.');
    } catch (error) {
      if (mounted) _showMessage('Backup failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreBackup(AutomaticBackupRecord record) async {
    final approved = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const UniversalText('Restore this backup?'),
            content: UniversalText(
              'This replaces the app preferences and customizations saved in '
              'this snapshot. More recent local preference changes may be '
              'overwritten. Passwords and tokens are not included. After '
              'restoring, restart MyOwnStreamingService so every screen reloads.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const UniversalText('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const UniversalText('Restore backup'),
              ),
            ],
          ),
        ) ??
        false;
    if (!approved || _busy) return;
    setState(() => _busy = true);
    try {
      await _backupService.restoreBackup(record.filePath);
      await _reloadBackups();
      if (mounted) {
        _showMessage(
          'Backup restored. Restart the app to refresh all open screens.',
        );
      }
    } catch (error) {
      if (mounted) _showMessage('Restore failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: UniversalText(message)),
    );
  }

  String _formatTimestamp(DateTime value) {
    final date = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _backupService.status,
      builder: (context, _) {
        final backupStatus = _backupService.status.value;
        return Scaffold(
          appBar: AppBar(
            title: const UniversalText('Automatic Backup & Recovery'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        backupStatus.enabled
                            ? Icons.shield_outlined
                            : Icons.pause_circle_outline,
                        size: 30,
                        color: backupStatus.enabled
                            ? Colors.greenAccent
                            : Theme.of(context).colorScheme.secondary,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const UniversalText(
                              'Automatic local backups',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const UniversalText(
                              'A verified checkpoint is written every 12 minutes '
                              'while the app is running. Saved preference changes '
                              'are also detected about every 45 seconds, and the '
                              'app attempts a checkpoint when it is paused.',
                            ),
                            const SizedBox(height: 8),
                            UniversalText(
                              backupStatus.message,
                              style: TextStyle(
                                fontSize: 12,
                                color: backupStatus.message.startsWith('Backup failed')
                                    ? Colors.orangeAccent
                                    : Theme.of(context).colorScheme.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                title: const UniversalText('Enable automatic backups'),
                subtitle: const UniversalText(
                  'Keep the latest recovery point and retain up to 60 interval snapshots.',
                ),
                value: backupStatus.enabled,
                onChanged: _busy
                    ? null
                    : (enabled) async {
                        await _backupService.setEnabled(enabled);
                        await _reloadBackups();
                      },
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const UniversalText(
                        'Backup status',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      _BackupDetailRow(
                        label: 'Last checkpoint',
                        value: backupStatus.lastBackupAt == null
                            ? 'Not available yet'
                            : _formatTimestamp(backupStatus.lastBackupAt!),
                      ),
                      _BackupDetailRow(
                        label: 'Saved restore points',
                        value: '${_backups.length}',
                      ),
                      if (backupStatus.directoryPath != null)
                        _BackupDetailRow(
                          label: 'Local backup folder',
                          value: backupStatus.directoryPath!,
                        ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _busy ? null : _createBackup,
                          icon: _busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.backup_rounded),
                          label: UniversalText(
                            _busy ? 'PLEASE WAIT…' : 'BACK UP NOW',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 16, 4, 8),
                child: UniversalText(
                  'Recovery points',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                ),
              ),
              if (_backups.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: UniversalText(
                      'No valid backup snapshots yet. Choose Back Up Now to create the first recovery point.',
                    ),
                  ),
                )
              else
                ..._backups.map((record) => Card(
                      child: ListTile(
                        leading: Icon(
                          record.isLatest
                              ? Icons.history_toggle_off_rounded
                              : Icons.restore_rounded,
                        ),
                        title: Text(
                          "${record.isLatest ? 'Latest recovery point' : 'Recovery point'} • ${_formatTimestamp(record.createdAt)}",
                        ),
                        subtitle: Text(
                          '${record.preferenceCount} saved settings • ${record.reason.replaceAll('_', ' ')}',
                        ),
                        trailing: TextButton(
                          onPressed: _busy ? null : () => _restoreBackup(record),
                          child: const UniversalText('Restore'),
                        ),
                      ),
                    )),
              const SizedBox(height: 12),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: UniversalText(
                    'What this protects: local app preferences and customizations, '
                    'including saved artwork selections, Home hero choices, details-page '
                    'layout settings and other supported preferences. Credentials and '
                    'tokens are excluded for safety. This does not copy video/music files '
                    'or back up remote Supabase/Jellyfin database records. Configure a '
                    'separate server/off-site backup for those, and keep this app data on '
                    'a device or drive independent from the media server when possible.',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BackupDetailRow extends StatelessWidget {
  const _BackupDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 132,
              child: UniversalText(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SelectableText(
                value,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      );
}

// -----------------------------------------------------------------------------
// STORAGE FORMATTER
// -----------------------------------------------------------------------------

String _size(int bytes) {
  if (bytes >= 1000000000000) {
    final tb = bytes / 1000000000000;

    return '${tb.toStringAsFixed(
      bytes % 1000000000000 == 0 ? 0 : 1,
    )} TB';
  }

  if (bytes >= 1000000000) {
    return '${(bytes / 1000000000).toStringAsFixed(0)} GB';
  }

  if (bytes >= 1000000) {
    return '${(bytes / 1000000).toStringAsFixed(0)} MB';
  }

  if (bytes >= 1000) {
    return '${(bytes / 1000).toStringAsFixed(0)} KB';
  }

  return '$bytes B';
}


// Consolidated from lib/ultimate_platform.dart.
class UltimatePlatformStore {
  UltimatePlatformStore._();
  static final Map<String, bool> features = <String, bool>{
    'aiConcierge': true,
    'naturalSearch': true,
    'tasteLearning': true,
    'adaptiveStreaming': true,
    'skipIntro': true,
    'skipRecap': true,
    'autoCredits': true,
    'cloudSync': true,
    'twoFactor': false,
    'kidsMode': false,
    'screenTime': false,
    'watchParty': true,
    'friends': true,
    'libraryScanner': true,
    'autoMetadata': true,
    'multiVersion': true,
    'hdr': true,
    'dataSaver': false,
    'wifiOnly': true,
    'notifications': true,
    'privacyAnalytics': true,
  };

  static bool enabled(String key) => features[key] ?? false;
  static void set(String key, bool value) => features[key] = value;
}

class UltimatePlatformScreen extends StatefulWidget {
  const UltimatePlatformScreen({super.key});

  @override
  State<UltimatePlatformScreen> createState() => _UltimatePlatformScreenState();
}

class _UltimatePlatformScreenState extends State<UltimatePlatformScreen> {
  int tab = 0;
  final tabs = const [
    'AI', 'Player', 'Family', 'Social', 'Library', 'Cloud', 'Security',
    'Devices', 'Studio',
  ];

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const UniversalText('Ultimate Streaming Platform'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            onPressed: () => _surprise(context),
          ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                for (var i = 0; i < tabs.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: ChoiceChip(
                      label: Text(tabs[i]),
                      selected: tab == i,
                      onSelected: (_) => setState(() => tab = i),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: tab,
              children: const [
                _AiPanel(),
                _PlayerPanel(),
                _FamilyPanel(),
                _SocialPanel(),
                _LibraryPanel(),
                _CloudPanel(),
                _SecurityPanel(),
                _DevicesPanel(),
                _StudioPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Performs `_surprise` for this feature. Update this documentation when its contract changes.
  void _surprise(BuildContext context) {
    final items = List<MediaItem>.from(AppController.instance.library);
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: UniversalText('Add media first.')),
      );
      return;
    }
    items.shuffle();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MediaDetailsScreen(media: items.first)),
    );
  }
}

class _AiPanel extends StatefulWidget {
  const _AiPanel();

  @override
  State<_AiPanel> createState() => _AiPanelState();
}

class _AiPanelState extends State<_AiPanel> {
  final q = TextEditingController();

  @override
  /// Performs `dispose` for this feature. Update this documentation when its contract changes.
  void dispose() {
    q.dispose();
    super.dispose();
  }

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    final items = AppController.instance.library;
    final text = q.text.toLowerCase();
    final matches = items.where((m) {
      return text.isEmpty ||
          m.title.toLowerCase().contains(text) ||
          m.genres.any((x) => x.toLowerCase().contains(text)) ||
          m.actors.any((x) => x.toLowerCase().contains(text));
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _hero(Icons.auto_awesome, 'AI Personal Concierge',
            'Search your private library using natural-language preferences.'),
        const SizedBox(height: 14),
        TextField(
          controller: q,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.psychology),
            hintText: tr('Try: funny sci-fi with a strong female lead'),
          ),
        ),
        const SizedBox(height: 18),
        _title('Natural-language discovery'),
        ...matches.take(10).map(
          (m) => ListTile(
            leading: const Icon(Icons.movie_outlined),
            title: Text(m.title),
            subtitle: Text(m.genres.take(3).join(' • ')),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => MediaDetailsScreen(media: m)),
            ),
          ),
        ),
        _switch('Taste learning',
            'Learn from likes, dislikes and completion.', 'tasteLearning'),
        _switch('AI concierge',
            'Enable conversational recommendation mode.', 'aiConcierge'),
      ],
    );
  }
}

class _PlayerPanel extends StatelessWidget {
  const _PlayerPanel();

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _hero(Icons.play_circle_fill, 'Premium Player',
            'Adaptive quality, HDR, skip intro/recap, credits, PiP and data controls.'),
        _switch('Adaptive streaming', 'Choose the best available quality.',
            'adaptiveStreaming'),
        _switch('HDR', 'Prefer HDR-capable streams.', 'hdr'),
        _switch('Skip intro', 'Skip detected introductions.', 'skipIntro'),
        _switch('Skip recap', 'Skip detected recaps.', 'skipRecap'),
        _switch('Automatic credits',
            'Detect credits and offer the next episode.', 'autoCredits'),
        _switch('Picture in picture',
            'Enable supported PiP playback.', 'pip'),
        _switch('Data saver', 'Prefer lower bandwidth.', 'dataSaver'),
        _switch('Wi-Fi only downloads',
            'Restrict downloads to Wi-Fi.', 'wifiOnly'),
      ],
    );
  }
}

class _FamilyPanel extends StatelessWidget {
  const _FamilyPanel();

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _hero(Icons.family_restroom, 'Family Center',
            'Profiles, kids controls, screen time and protected content.'),
        _switch('Kids Mode',
            'Restrict discovery to age-appropriate content.', 'kidsMode'),
        _switch('Screen-time limits',
            'Prepare per-profile viewing schedules.', 'screenTime'),
        _switch('PIN protection',
            'Protect profiles and restricted content.', 'twoFactor'),
        _switch('Family watchlists',
            'Share selected lists with household profiles.', 'watchParty'),
      ],
    );
  }
}

class _SocialPanel extends StatelessWidget {
  const _SocialPanel();

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _hero(Icons.groups, 'Social & Watch Together',
            'Friends, synchronized parties, shared queues and reactions.'),
        _switch('Watch parties',
            'Enable synchronized group sessions.', 'watchParty'),
        _switch('Friends', 'Enable friend/activity features.', 'friends'),
        _switch('Shared queues',
            'Build a common playback queue.', 'watchParty'),
        _switch('Live reactions',
            'Emoji reactions during group playback.', 'friends'),
      ],
    );
  }
}

class _LibraryPanel extends StatelessWidget {
  const _LibraryPanel();

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    final a = AppController.instance;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _hero(Icons.video_library, 'Media Intelligence',
            'Automatic scanning, metadata matching, artwork, versions and technical analysis.'),
        _switch('Library scanner',
            'Monitor configured sources for new content.', 'libraryScanner'),
        _switch('Automatic metadata',
            'Enrich cast, genres and artwork.', 'autoMetadata'),
        _switch('Multiple versions',
            'Keep 4K, HD and alternate cuts together.', 'multiVersion'),
        _metric('Library', '${a.library.length} titles'),
        _metric('Genres', '${a.genresCatalog.length}'),
        _metric('Actors', '${a.actorsCatalog.length}'),
      ],
    );
  }
}

class _CloudPanel extends StatelessWidget {
  const _CloudPanel();

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    final a = AppController.instance;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _hero(Icons.cloud_sync, 'Cloud Platform',
            'Synchronization, backups, sessions and cross-device state.'),
        _switch('Cloud sync',
            'Synchronize profiles, progress, lists and preferences.', 'cloudSync'),
        _metric('Backend', a.isBackendAuthenticated ? 'Authenticated' : 'Local mode'),
        _metric('Session', a.backendToken == null ? 'Local' : 'Token active'),
      ],
    );
  }
}

class _SecurityPanel extends StatelessWidget {
  const _SecurityPanel();

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _hero(Icons.shield, 'Privacy & Security',
            'Account protection, sessions, privacy and data controls.'),
        _switch('Two-factor authentication',
            'Protect account sign-ins with a second factor.', 'twoFactor'),
        _switch('Security notifications',
            'Notify about important account events.', 'notifications'),
        _switch('Privacy analytics',
            'Allow anonymous product analytics.', 'privacyAnalytics'),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const UniversalText('Sign out other devices'),
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: UniversalText('Remote session control is connected to the platform layer.')),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.delete_sweep),
          title: const UniversalText('Clear local activity'),
          onTap: () => _confirmClear(context),
        ),
      ],
    );
  }
}

class _DevicesPanel extends StatelessWidget {
  const _DevicesPanel();

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    const devices = [
      'Android', 'iOS', 'Windows', 'macOS', 'Linux', 'Web',
      'Android TV / Google TV', 'Apple TV', 'Fire TV',
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _hero(Icons.devices_other, 'Every Screen',
            'Mobile, desktop, web and TV platform readiness.'),
        for (final x in devices)
          ListTile(
            leading: const Icon(Icons.check_circle_outline),
            title: Text(x),
            subtitle: const UniversalText('Platform-ready configuration'),
          ),
      ],
    );
  }
}

class _StudioPanel extends StatelessWidget {
  const _StudioPanel();

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    final a = AppController.instance;
    const tools = [
      'Catalog Manager', 'User & Profile Manager', 'Subscription Manager',
      'Import & Metadata Manager', 'Recommendation Lab',
      'Analytics & Viewing Reports', 'Remote Server Manager', 'Audit Log',
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _hero(Icons.dashboard_customize, 'Creator / Admin Studio',
            'Catalog, users, subscriptions, imports, recommendations, analytics and servers.'),
        _metric('Catalog', '${a.library.length} titles'),
        _metric('Collections', '${a.collections.length}'),
        _metric('Watch history', '${a.watched.length}'),
        _metric('Wishlist', '${a.wishlist.length}'),
        for (final x in tools)
          ListTile(
            leading: const Icon(Icons.admin_panel_settings_outlined),
            title: Text(x),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: UniversalText('$x is available from the platform control layer.')),
            ),
          ),
      ],
    );
  }
}

Widget _hero(IconData icon, String title, String subtitle) {
  return Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFF171717),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 34, color: Colors.redAccent),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(subtitle,
                  style: const TextStyle(color: Colors.white70, height: 1.4)),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _title(String text) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(text,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
  );
}

Widget _switch(String title, String subtitle, String key) {
  return SwitchListTile(
    value: UltimatePlatformStore.enabled(key),
    onChanged: (value) => UltimatePlatformStore.set(key, value),
    title: Text(title),
    subtitle: Text(subtitle),
  );
}

Widget _metric(String title, String value) {
  return Card(
    child: ListTile(
      title: Text(title),
      trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
    ),
  );
}

void _confirmClear(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: const UniversalText('Clear local activity?'),
      content: const UniversalText('This removes local-only activity from the current app session.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const UniversalText('CANCEL'),
        ),
        FilledButton(
          onPressed: () {
            final controller = AppController.instance;
            controller.activity.clear();
            controller.watched.clear();
            Navigator.pop(context);
          },
          child: const UniversalText('CLEAR'),
        ),
      ],
    ),
  );
}


// Consolidated from lib/roadmap_features.dart.
/// Implements the `RoadmapFeaturesScreen` class for this feature or UI component.
class RoadmapFeaturesScreen extends StatelessWidget {
  const RoadmapFeaturesScreen({super.key});

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    final features = <_RoadmapFeature>[
      _RoadmapFeature(1, 'Recommendation Voting', Icons.how_to_vote_rounded, 'Every normal profile can vote on every recommendation.', (_) => const RecommendationCompetitionScreen()),
      _RoadmapFeature(2, 'ListTile Layout Fix', Icons.view_list_rounded, 'Use constrained, scroll-safe list layouts across feature surfaces.', (_) => const RoadmapListLayoutScreen()),
      _RoadmapFeature(3, 'All Profiles Can Vote', Icons.groups_rounded, 'Recommendation eligibility includes every profile on the account.', (_) => const RecommendationCompetitionScreen()),
      _RoadmapFeature(4, 'One Vote Per Profile', Icons.rule_rounded, 'Duplicate votes are rejected and the current vote is shown.', (_) => const RecommendationCompetitionScreen()),
      _RoadmapFeature(5, 'Wishlist Behavior', Icons.favorite_border_rounded, 'Approved recommendations flow into the shared wishlist.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(6, 'Per-Profile Navigation', Icons.navigation_rounded, 'Navigation order and placement are profile-specific.', (_) => const CustomizeHomeScreen()),
      _RoadmapFeature(7, 'Home Screen Builder', Icons.dashboard_customize_rounded, 'Reorder and show or hide Home sections.', (_) => const CustomizeHomeScreen()),
      _RoadmapFeature(8, 'Details Screen Builder', Icons.article_outlined, 'Per-profile Details section visibility and ordering.', (_) => const CustomizeHomeScreen()),
      _RoadmapFeature(9, 'Themes & Accent Colors', Icons.palette_outlined, 'Personal visual preferences for each profile.', (_) => const CustomizeHomeScreen()),
      _RoadmapFeature(10, 'Layout Presets', Icons.grid_view_rounded, 'Poster/card sizes and compact or spacious presentation.', (_) => const CustomizeHomeScreen()),
      _RoadmapFeature(11, 'Drag-and-Drop UI Builder', Icons.open_with_rounded, 'Reorder Home widgets and dashboard elements.', (_) => const HomeWidgetsScreen()),
      _RoadmapFeature(12, 'Smart Recommendations', Icons.auto_awesome_rounded, 'Use watch behavior, metadata and profile signals.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(13, 'Smart Collections', Icons.auto_awesome_mosaic_rounded, 'Dynamic collections based on live library rules.', (_) => const SmartCollectionsScreen()),
      _RoadmapFeature(14, 'Advanced Search', Icons.manage_search_rounded, 'Search title, actor, director, genre, tags, year and watched state.', (_) => const AdvancedLibrarySearchScreen()),
      _RoadmapFeature(144, 'My Cinematic Universe', Icons.auto_awesome_rounded, 'Discover by mood, hybrid genres, pairings, franchise timelines, calendar reminders, vault and viewing recap.', (_) => const CinematicDiscoveryStudioScreen()),
      _RoadmapFeature(15, 'Actor & Franchise Pages', Icons.theaters_rounded, 'Explore catalog actors and related titles.', (_) => const ActorFranchiseRoadmapScreen()),
      _RoadmapFeature(16, 'Trailer Theater', Icons.movie_filter_rounded, 'Browse imported trailers as a dedicated theater.', (_) => const TrailerTheaterScreen()),
      _RoadmapFeature(17, 'Music Mode', Icons.music_note_rounded, 'Browse soundtrack and music metadata from your library.', (_) => const MusicModeScreen()),
      _RoadmapFeature(18, 'Recommendation Competition', Icons.emoji_events_rounded, 'Rank recommendations and identify the weekly winner.', (_) => const RecommendationCompetitionScreen()),
      _RoadmapFeature(19, 'Achievements', Icons.workspace_premium_rounded, 'Watching, voting and collection milestones.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(20, 'Personal Statistics', Icons.insights_rounded, 'Watching totals, genres, streaks and recaps.', (_) => const StatisticsScreen()),
      _RoadmapFeature(21, 'Reactions', Icons.favorite_rounded, 'Love, funny, scary, emotional and mind-blowing reactions.', (_) => const ReactionGuideScreen()),
      _RoadmapFeature(22, 'Watch Together 2.0', Icons.groups_rounded, 'Synchronized group watching, chat and host controls.', (_) => const GroupWatchRoadmapScreen()),
      _RoadmapFeature(23, 'Activity Center', Icons.notifications_active_outlined, 'Watching, recommendations, imports and party activity.', (_) => const UltimateFeaturesScreen()),
      _RoadmapFeature(24, 'ARM Disc Intelligence', Icons.album_rounded, 'Detect, extract, identify, enrich, review and approve discs.', (_) => const UltimateFeaturesScreen()),
      _RoadmapFeature(25, 'ARM Metadata', Icons.fact_check_outlined, 'Catalog resolution, codecs, audio, subtitles, chapters and extras.', (_) => const UltimateFeaturesScreen()),
      _RoadmapFeature(26, 'Poster & Trailer Fallbacks', Icons.image_search_rounded, 'Manual URLs remain available when a disc lacks artwork or trailer data.', (_) => const UltimateFeaturesScreen()),
      _RoadmapFeature(27, 'Audio / Subtitle / Chapters / Extras', Icons.closed_caption_rounded, 'Expose imported disc metadata throughout Details.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(28, 'Manual Library Approval', Icons.verified_outlined, 'ARM stops at Review and requires Add to Library.', (_) => const UltimateFeaturesScreen()),
      _RoadmapFeature(29, 'Real Email', Icons.email_outlined, 'Account email flows are ready for real provider integration.', (_) => const SecurityCenterScreen()),
      _RoadmapFeature(30, 'Verification', Icons.mark_email_read_outlined, 'Verification and security challenge surfaces.', (_) => const SecurityCenterScreen()),
      _RoadmapFeature(31, 'Suspicious Login Protection', Icons.gpp_maybe_rounded, 'Security-question challenge before access is granted.', (_) => const SecurityCenterScreen()),
      _RoadmapFeature(32, 'Device Management', Icons.devices_rounded, 'Trusted devices, pairing and device access controls.', (_) => const DeviceCenterScreen()),
      _RoadmapFeature(33, 'Remote Access', Icons.public_rounded, 'Trusted remote computers and remote imports.', (_) => const RemoteAccessScreen()),
      _RoadmapFeature(34, 'Backup & Restore', Icons.backup_rounded, 'Backup and recovery controls for account and library state.', (_) => const BackupScreen()),
      _RoadmapFeature(51, 'ARM Canonical Title Resolution', Icons.language_rounded, 'Resolve localized disc titles to the canonical/original movie while preserving disc title, market and raw ARM region.', (_) => const UltimateFeaturesScreen()),
      _RoadmapFeature(52, 'Recommendation Feedback', Icons.feedback_outlined, 'Improve recommendations from explicit feedback.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(53, 'Recommendation Diversity', Icons.shuffle_rounded, 'Prevent recommendation feeds from becoming repetitive.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(54, 'Similar Titles', Icons.compare_arrows_rounded, 'Find titles similar to the current selection.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(55, 'Because You Watched', Icons.history_toggle_off_rounded, 'Generate recommendations from recent viewing.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(56, 'Continue Watching Intelligence', Icons.play_circle_outline_rounded, 'Prioritize unfinished titles and episodes intelligently.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(57, 'Franchise Progress', Icons.linear_scale_rounded, 'Show progress through franchise collections.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(58, 'Collection Completion', Icons.check_circle_outline_rounded, 'Track which franchise collections are complete.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(59, 'Collaborative Collections', Icons.group_work_rounded, 'Allow permitted profiles to contribute to shared collections.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(60, 'Collection Permissions', Icons.admin_panel_settings_outlined, 'Control who can view, add, remove or edit collections.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(61, 'Collection Posters', Icons.image_outlined, 'Build collection artwork from member posters.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(62, 'Collection Favorites', Icons.favorite_border_rounded, 'Like collections and surface favorites quickly.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(63, 'Collection Manual Ordering', Icons.reorder_rounded, 'Manually arrange titles inside a collection.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(64, 'Collection Release Order', Icons.sort_rounded, 'Automatically sort a collection by release order.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(65, 'Version Preference', Icons.movie_outlined, 'Prefer theatrical, extended, preferred or highest-quality versions.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(66, 'Auto Play Queue', Icons.queue_play_next_rounded, 'Build a playback queue from collection order.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(67, 'Credits Auto Advance', Icons.skip_next_rounded, 'Advance to the next eligible title around end credits.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(68, 'Episode Auto Advance', Icons.next_plan_rounded, 'Automatically continue to the next episode.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(69, 'Episode Progress', Icons.format_list_numbered_rounded, 'Track watched and partially watched episodes.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(70, 'Season Progress', Icons.playlist_play_rounded, 'Display completion progress for every season.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(71, 'Episode Ratings', Icons.star_border_rounded, 'Rate individual episodes independently.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(72, 'Watch-State Overrides', Icons.published_with_changes_rounded, 'Manually mark movies or episodes watched/unwatched.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(73, 'Duplicate Detection', Icons.content_copy_rounded, 'Detect duplicate library entries before approval.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(74, 'Metadata Conflict Review', Icons.difference_rounded, 'Compare conflicting metadata before saving.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(75, 'Metadata Locking', Icons.lock_outline_rounded, 'Protect manually corrected metadata from automatic replacement.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(76, 'Artwork Selection', Icons.photo_library_outlined, 'Choose among available posters and backdrops.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(77, 'Trailer Selection', Icons.ondemand_video_rounded, 'Choose the preferred trailer when multiple are available.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(78, 'Genre Management', Icons.category_outlined, 'Normalize and manage library genres.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(79, 'Tag Management', Icons.sell_outlined, 'Create and manage custom library tags.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(80, 'Actor Credits', Icons.person_search_rounded, 'Browse every library title associated with an actor.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(81, 'Director Credits', Icons.movie_creation_outlined, 'Browse every library title associated with a director.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(82, 'Writer Credits', Icons.edit_note_rounded, 'Browse every library title associated with a writer.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(83, 'Franchise Discovery', Icons.account_tree_rounded, 'Discover franchise relationships from imported metadata.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(84, 'Disc Title Review', Icons.fact_check_rounded, 'Review every detected ARM title before library approval.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(85, 'Disc Title Classification', Icons.label_important_outline_rounded, 'Classify films, extras, episodes and alternate cuts.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(86, 'Disc Confidence Scores', Icons.verified_user_outlined, 'Show ARM metadata confidence during review.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(87, 'Disc Collection Linking', Icons.link_rounded, 'Link separate library titles to their physical disc.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(88, 'Multi-Title Disc Import', Icons.library_add_rounded, 'Import multiple distinct movies from one physical disc.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(89, 'Import Approval Queue', Icons.playlist_add_check_rounded, 'Review pending imports before they enter the library.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(90, 'Import Rejection', Icons.block_outlined, 'Reject incorrect or unwanted ARM results.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(91, 'Import Job History', Icons.history_rounded, 'Review previous ARM scan and import jobs.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(92, 'Import Cancellation', Icons.cancel_outlined, 'Cancel eligible ARM jobs safely.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(93, 'Audio Track Browser', Icons.graphic_eq_rounded, 'Inspect imported audio tracks.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(94, 'Subtitle Browser', Icons.subtitles_outlined, 'Inspect available subtitle tracks.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(95, 'Chapter Browser', Icons.menu_book_rounded, 'Browse imported chapters.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(96, 'Extras Browser', Icons.video_library_outlined, 'Browse extras and bonus content separately.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(97, 'Kids Profile Mode', Icons.child_care_rounded, 'Create a simplified profile experience for children.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(98, 'Content Age Filters', Icons.filter_alt_outlined, 'Filter content by configurable age ratings.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(99, 'Profile PIN', Icons.pin_outlined, 'Protect selected profile actions with a PIN.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(100, 'Kids Safe Collections', Icons.family_restroom_rounded, 'Restrict collections available to child profiles.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(101, 'Account Security Center', Icons.security_rounded, 'Profile-scoped 2FA, suspicious-login alerts, new-device approval and session controls.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(102, 'Playback Experience Controls', Icons.play_circle_fill_rounded, 'Profile-scoped resume, autoplay, preload, picture-in-picture and track preferences.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(103, 'TV Experience Controls', Icons.tv_rounded, 'Series-first autoplay, preserved intros, specials and unfinished-season behavior.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(104, 'Notification Controls', Icons.notifications_active_rounded, 'Per-profile alerts for episodes, recommendations and security events.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(105, 'Backup & Migration Controls', Icons.backup_rounded, 'Profile-scoped backup manifest coverage for settings, watch state, collections and layouts.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(106, 'Library Intelligence Controls', Icons.auto_awesome_rounded, 'Tune smart recommendations, diversity, explanations and franchise progress.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(107, 'Search & Discovery Controls', Icons.manage_search_rounded, 'Enable natural-language, localized-title, actor and crew discovery.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(108, 'Collection Studio Controls', Icons.collections_bookmark_rounded, 'Configure collection autoplay, release order, quality preference and credit advance.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(110, 'Privacy & Profile Controls', Icons.privacy_tip_rounded, 'Control activity, reactions, watch-history sharing and profile PIN protection.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(111, 'Kids Safety Controls', Icons.child_care_rounded, 'Kids mode, age filters, safe collections and mature-content PIN protection.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(112, 'Performance Controls', Icons.speed_rounded, 'Tune animations, artwork preloading, reduced motion and fast Home mode.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(113, 'Legacy Movie Safety Review', Icons.history_edu_rounded, 'Apply extra kids-safety review to older movies whose historical ratings may not reflect modern parental expectations.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(114, 'Nudity Safety Detection', Icons.visibility_off_rounded, 'Flag nudity and partial nudity independently of the official age rating.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(115, 'Sexual Content Detection', Icons.no_adult_content_rounded, 'Flag sexual content, sexualized imagery and suggestive material for child profiles.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(116, 'Violence & Gore Safety', Icons.warning_amber_rounded, 'Apply additional violence and gore safeguards beyond the official rating.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(117, 'Profanity Safety', Icons.record_voice_over_rounded, 'Use profanity metadata as an independent kids-safety signal.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(118, 'Substance Use Safety', Icons.smoke_free_rounded, 'Flag alcohol, drugs and smoking independently of the official rating.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(119, 'Disturbing Content Safety', Icons.warning_rounded, 'Flag horror, frightening scenes and disturbing imagery for child profiles.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(120, 'Suggestive Themes Safety', Icons.forum_rounded, 'Flag mature jokes, suggestive dialogue and adult themes.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(121, 'Parent Content Warnings', Icons.info_outline_rounded, 'Show detected content categories to a parent before playback.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(122, 'Incomplete Metadata Protection', Icons.help_outline_rounded, 'Require parent review when content-safety metadata is missing or uncertain.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(123, 'Disc Rating Comparison', Icons.album_rounded, 'Compare the physical DVD/Blu-ray packaging rating with current catalog metadata.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(124, 'Parent Approval Queue', Icons.approval_rounded, 'Hold flagged child-profile titles for explicit parent approval.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(125, 'Per-Title Kids Overrides', Icons.rule_rounded, 'Allow a parent to approve or block individual titles regardless of general rules.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(126, 'Multi-Signal Kids Safety', Icons.shield_rounded, 'Combine age rating, content descriptors, legacy status, metadata confidence and parent rules instead of relying on a single rating.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(131, 'Global Language & Localization', Icons.translate_rounded, 'Global language selector with native language names, profile persistence, RTL support and localized metadata preferences.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(127, 'Music Home', Icons.music_note_rounded, 'Dedicated Music home with artists, bands, albums and songs.', (_) => const MusicScreen()),
      _RoadmapFeature(128, 'Custom Music Playlists', Icons.queue_music_rounded, 'Create, delete and curate profile playlists.', (_) => const MusicScreen()),
      _RoadmapFeature(129, 'Background Music Player', Icons.headphones_rounded, 'Keep music playing while browsing and resume it after movie/TV playback.', (_) => const MusicScreen()),
      _RoadmapFeature(130, 'Music Visual Customization', Icons.palette_outlined, 'Customize music home and navigation colors, glow and item styling.', (_) => const MusicScreen()),
      _RoadmapFeature(132, 'Soundtrack Universe', Icons.album_rounded, 'Connect movies, shows, albums and songs into soundtrack experiences.', (_) => const MusicScreen()),
      _RoadmapFeature(133, 'Music Statistics', Icons.bar_chart_rounded, 'Track music songs, playlists and listening alongside movie/TV statistics.', (_) => const StatisticsScreen()),
      _RoadmapFeature(134, 'Music Achievements & Badges', Icons.emoji_events_rounded, 'Badges such as Cultured, Swiftie and Album Collector.', (_) => const AchievementsScreen()),
      _RoadmapFeature(139, 'Home Server Dashboard', Icons.dns_rounded, 'Monitor the home server, media root and ARM connection.', (_) => const HomeServerScreen()),
      _RoadmapFeature(140, 'ARM Media Scanner', Icons.disc_full_rounded, 'Scan completed ARM media and synchronize discovered files into Flutter.', (_) => const HomeServerScreen()),
      _RoadmapFeature(141, 'Server Storage Dashboard', Icons.storage_rounded, 'Display Movies, Series, Music and available storage with hover details.', (_) => const StorageDashboardScreen()),
      _RoadmapFeature(142, 'Custom Storage Visualization', Icons.color_lens_rounded, 'Customize storage category colors and progress visualization.', (_) => const StorageDashboardScreen()),
      _RoadmapFeature(143, 'Expanded Platform Capability Center', Icons.hub_rounded, 'Browse new AI, discovery, social, commerce, privacy, reliability and operations capabilities.', (_) => const ExpandedPlatformScreen()),
    ];

    return Scaffold(
      appBar: AppBar(title: const UniversalText('Feature Roadmap')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: UniversalText('Platform features and controls',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: features.length,
        itemBuilder: (context, index) {
          final f = features[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: CircleAvatar(child: UniversalText('${f.number}')),
              title: Text(f.title, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(f.description),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => f.builder(context))),
            ),
          );
        },
            ),
          ),
        ],
      ),
    );
  }
}

/// Implements the `_RoadmapFeature` class for this feature or UI component.
class _RoadmapFeature {
  final int number;
  final String title;
  final IconData icon;
  final String description;
  final Widget Function(BuildContext) builder;
  _RoadmapFeature(this.number, this.title, this.icon, this.description, this.builder);
}

List<MediaItem> _library() => AppController.instance.library;

/// Implements the `AskMyLibraryScreen` class for this feature or UI component.
class AskMyLibraryScreen extends StatefulWidget {
  const AskMyLibraryScreen({super.key});
  @override State<AskMyLibraryScreen> createState() => _AskMyLibraryScreenState();
}
/// Implements the `_AskMyLibraryScreenState` class for this feature or UI component.
class _AskMyLibraryScreenState extends State<AskMyLibraryScreen> {
  final query = TextEditingController();
  List<MediaItem> results = <MediaItem>[];
  String explanation = 'Ask about titles, actors, genres, years, watched state or your next watch.';

  /// Performs `ask` for this feature. Update this documentation when its contract changes.
  void ask() {
    final q = query.text.trim().toLowerCase();
    var filtered = List<MediaItem>.from(_library());
    if (q.contains('unwatched')) filtered = filtered.where((m) => !AppController.instance.isWatched(m.id)).toList();
    if (q.contains('watched')) filtered = filtered.where((m) => AppController.instance.isWatched(m.id)).toList();
    if (q.contains('movie')) filtered = filtered.where((m) => m.type == 'movie').toList();
    if (q.contains('show') || q.contains('series') || q.contains('tv')) filtered = filtered.where((m) => m.type != 'movie').toList();
    final year = RegExp(r'\b(19|20)\d{2}\b').firstMatch(q)?.group(0);
    if (year != null) filtered = filtered.where((m) => m.releaseYear == int.tryParse(year)).toList();
    for (final genre in const ['action','comedy','drama','horror','romance','thriller','animation','sci-fi']) {
      if (q.contains(genre)) filtered = filtered.where((m) => m.genres.any((g) => g.toLowerCase().contains(genre))).toList();
    }
    setState(() {
      results = filtered;
      explanation = results.isEmpty ? 'No matching titles were found in this profile library.' : 'Found ${results.length} matching title${results.length == 1 ? '' : 's'} from your library metadata.';
    });
  }
  @override void dispose() { query.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const UniversalText('Ask My Library')),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        TextField(controller: query, onSubmitted: (_) => ask(), decoration: InputDecoration(hintText: tr('e.g. unwatched action movies from the 2000s'), suffixIcon: IconButton(onPressed: ask, icon: const Icon(Icons.search)))),
        const SizedBox(height: 12),
        Align(alignment: Alignment.centerLeft, child: Text(explanation, style: const TextStyle(color: Colors.white70))),
        const SizedBox(height: 12),
        Expanded(child: ListView.builder(itemCount: results.length, itemBuilder: (_, i) {
          final m = results[i];
          return Card(child: ListTile(title: Text(m.title), subtitle: UniversalText('${m.releaseYear ?? ''} • ${m.type}'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MediaDetailsScreen(media: m)))));
        })),
      ]),
    ),
  );
}

/// Implements the `SmartCollectionsScreen` class for this feature or UI component.
class SmartCollectionsScreen extends StatefulWidget { const SmartCollectionsScreen({super.key}); @override State<SmartCollectionsScreen> createState() => _SmartCollectionsScreenState(); }
class _SmartCollectionsScreenState extends State<SmartCollectionsScreen> {
  String rule = 'Unwatched';
  List<MediaItem> get items { final l = _library(); switch (rule) { case 'Watched': return l.where((m) => AppController.instance.isWatched(m.id)).toList(); case 'Movies': return l.where((m) => m.type == 'movie').toList(); case 'TV Shows': return l.where((m) => m.type != 'movie').toList(); case 'Liked': return l.where((m) => AppController.instance.liked.any((x) => x.id == m.id)).toList(); default: return l.where((m) => !AppController.instance.isWatched(m.id)).toList(); } }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const UniversalText('Smart Collections')), body: Padding(padding: const EdgeInsets.all(16), child: Column(children: [DropdownButtonFormField<String>(initialValue: rule, items: const ['Unwatched','Watched','Movies','TV Shows','Liked'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) => setState(() => rule = v!)), const SizedBox(height: 12), Align(alignment: Alignment.centerLeft, child: UniversalText('${items.length} titles match this live rule')), const SizedBox(height: 12), Expanded(child: ListView(children: items.map((m) => ListTile(leading: const Icon(Icons.movie_outlined), title: Text(m.title), subtitle: UniversalText('${m.releaseYear ?? ''} • ${m.type}'))).toList()))])));
}

/// Implements the `RecommendationCompetitionScreen` class for this feature or UI component.
class RecommendationCompetitionScreen extends StatelessWidget {
  const RecommendationCompetitionScreen({super.key});
  @override Widget build(BuildContext context) {
    final recs = [...AppController.instance.groupRecommendations];
    recs.sort((a, b) => _yes(b).compareTo(_yes(a)));
    return Scaffold(appBar: AppBar(title: const UniversalText('Recommendation Competition')), body: ListView(padding: const EdgeInsets.all(16), children: [
      if (recs.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(24), child: UniversalText('No active recommendations yet.'))),
      ...recs.asMap().entries.map((entry) { final r = entry.value; return Card(child: ListTile(leading: CircleAvatar(child: UniversalText('${entry.key + 1}')), title: Text(r['title']?.toString() ?? 'Untitled'), subtitle: UniversalText('YES ${r['yesVotes'] ?? 0} • NO ${r['noVotes'] ?? 0}'), trailing: entry.key == 0 ? const Icon(Icons.emoji_events_rounded) : null)); }),
    ]));
  }
  static int _yes(Map<String, dynamic> r) => int.tryParse(r['yesVotes']?.toString() ?? '0') ?? 0;
}

/// Implements the `WatchHistoryTimelineScreen` class for this feature or UI component.
class WatchHistoryTimelineScreen extends StatelessWidget {
  const WatchHistoryTimelineScreen({super.key});
  @override Widget build(BuildContext context) { final watched = AppController.instance.watched; return Scaffold(appBar: AppBar(title: const UniversalText('Watch History')), body: watched.isEmpty ? const Center(child: UniversalText('Nothing watched yet.')) : ListView.separated(padding: const EdgeInsets.all(16), itemCount: watched.length, separatorBuilder: (_, __) => const Divider(), itemBuilder: (_, i) { final m = watched[watched.length - 1 - i]; return ListTile(leading: CircleAvatar(child: UniversalText('${i + 1}')), title: Text(m.title), subtitle: UniversalText('${m.releaseYear ?? ''} • Watched by ${AppController.instance.currentProfile?.name ?? 'profile'}')); })); }
}

/// Implements the `MusicModeScreen` class for this feature or UI component.
class MusicModeScreen extends StatelessWidget {
  const MusicModeScreen({super.key});
  @override Widget build(BuildContext context) { final grouped = <String, List<String>>{}; for (final m in _library()) { for (final item in m.music) { grouped.putIfAbsent(m.title, () => <String>[]).add(item); } } return Scaffold(appBar: AppBar(title: const UniversalText('Music Mode')), body: grouped.isEmpty ? const Center(child: UniversalText('No music metadata has been imported yet.')) : ListView(padding: const EdgeInsets.all(16), children: grouped.entries.expand((e) => [Padding(padding: const EdgeInsets.only(top: 10, bottom: 4), child: Text(e.key, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))), ...e.value.map((x) => ListTile(leading: const Icon(Icons.music_note_rounded), title: Text(x)))]).toList())); }
}

/// Implements the `TrailerTheaterScreen` class for this feature or UI component.
class TrailerTheaterScreen extends StatelessWidget {
  const TrailerTheaterScreen({super.key});
  @override Widget build(BuildContext context) { final media = _library().where((m) => (m.trailerUrl ?? '').trim().isNotEmpty).toList(); return Scaffold(appBar: AppBar(title: const UniversalText('Trailer Theater')), body: media.isEmpty ? const Center(child: UniversalText('No trailers are available.')) : GridView.builder(padding: const EdgeInsets.all(16), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: .75), itemCount: media.length, itemBuilder: (_, i) { final m = media[i]; return Card(child: InkWell(onTap: () async { final uri = Uri.tryParse(m.trailerUrl!); if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication); }, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: m.imageUrl == null ? const Center(child: Icon(Icons.movie_rounded, size: 48)) : Image.network(m.imageUrl!, fit: BoxFit.cover, width: double.infinity, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.movie_rounded, size: 48)))), Padding(padding: const EdgeInsets.all(10), child: Text(m.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),]))); })); }
}

/// Implements the `HomeWidgetsScreen` class for this feature or UI component.
class HomeWidgetsScreen extends StatefulWidget { const HomeWidgetsScreen({super.key}); @override State<HomeWidgetsScreen> createState() => _HomeWidgetsScreenState(); }
class _HomeWidgetsScreenState extends State<HomeWidgetsScreen> { final widgets = <String>['Continue Watching','Wishlist','Watch Streak','Recommendations','Recently Added','Storage']; @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const UniversalText('Home Widgets')), body: ReorderableListView.builder(padding: const EdgeInsets.all(16), itemCount: widgets.length, onReorderItem: (a, b) => setState(() { final item = widgets.removeAt(a); widgets.insert(b, item); }), itemBuilder: (_, i) => Card(key: ValueKey(widgets[i]), child: ListTile(leading: const Icon(Icons.drag_handle_rounded), title: Text(widgets[i]), trailing: const Icon(Icons.widgets_rounded))))); }

class ProfileRelationshipsScreen extends StatefulWidget { const ProfileRelationshipsScreen({super.key}); @override State<ProfileRelationshipsScreen> createState() => _ProfileRelationshipsScreenState(); }
/// Implements the `_ProfileRelationshipsScreenState` class for this feature or UI component.
class _ProfileRelationshipsScreenState extends State<ProfileRelationshipsScreen> { final permissions = <String, bool>{'Watch': true, 'Recommend': true, 'Vote': true, 'Wishlist': true, 'Customize UI': true}; @override Widget build(BuildContext context) { final profiles = AppController.instance.currentAccount?.profiles ?? <Profile>[]; return Scaffold(appBar: AppBar(title: const UniversalText('Profile Relationships')), body: ListView(padding: const EdgeInsets.all(16), children: profiles.map((p) => Card(child: ExpansionTile(title: Text(p.name), subtitle: const UniversalText('Optional permissions'), children: permissions.keys.map((k) => SwitchListTile(title: Text(k), value: permissions[k]!, onChanged: (v) => setState(() => permissions[k] = v))).toList()))).toList())); } }

class ReactionGuideScreen extends StatelessWidget { const ReactionGuideScreen({super.key}); @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const UniversalText('Reactions')), body: ListView(padding: const EdgeInsets.all(16), children: const [ListTile(leading: UniversalText('❤️', style: TextStyle(fontSize: 26)), title: UniversalText('Love it')), ListTile(leading: UniversalText('🔥', style: TextStyle(fontSize: 26)), title: UniversalText('Amazing')), ListTile(leading: UniversalText('😂', style: TextStyle(fontSize: 26)), title: UniversalText('Funny')), ListTile(leading: UniversalText('😱', style: TextStyle(fontSize: 26)), title: UniversalText('Scary')), ListTile(leading: UniversalText('😭', style: TextStyle(fontSize: 26)), title: UniversalText('Emotional')), ListTile(leading: UniversalText('🤯', style: TextStyle(fontSize: 26)), title: UniversalText('Mind-blowing'))])); }

/// Implements the `AdvancedLibrarySearchScreen` class for this feature or UI component.
class AdvancedLibrarySearchScreen extends StatefulWidget {
  const AdvancedLibrarySearchScreen({super.key});
  @override
  State<AdvancedLibrarySearchScreen> createState() => _AdvancedLibrarySearchScreenState();
}

class _AdvancedLibrarySearchScreenState extends State<AdvancedLibrarySearchScreen> {
  final TextEditingController q = TextEditingController();
  String type = 'All';
  String mood = 'Any mood';
  bool unwatched = false;
  bool matchAllGenres = true;
  final Set<String> selectedGenres = <String>{};
  List<MediaItem> results = <MediaItem>[];

  void search() {
    final term = q.text.trim().toLowerCase();
    final mentionedGenres = GenreSystem.genresMentionedIn(term);
    final filters = <String>{...selectedGenres, ...mentionedGenres};
    final moodGenres = GenreSystem.moodGenreHints[mood] ?? const <String>[];
    final all = _library();
    setState(() {
      results = all.where((m) {
        final genreMatch = GenreSystem.matchesGenres(
          m.genres,
          filters,
          matchAll: matchAllGenres,
        );
        final moodMatch = moodGenres.isEmpty ||
            GenreSystem.matchesGenres(m.genres, moodGenres, matchAll: false);
        final textMatch = term.isEmpty ||
            mentionedGenres.isNotEmpty ||
            m.title.toLowerCase().contains(term) ||
            GenreSystem.searchTerms(m.genres).any((x) => x.toLowerCase().contains(term)) ||
            m.tags.any((x) => x.toLowerCase().contains(term)) ||
            m.actors.any((x) => x.toLowerCase().contains(term)) ||
            m.directors.any((x) => x.toLowerCase().contains(term));
        return textMatch &&
            (filters.isEmpty || genreMatch) &&
            moodMatch &&
            (type == 'All' || (type == 'Movies' ? m.type.toLowerCase() == 'movie' : m.type.toLowerCase() != 'movie')) &&
            (!unwatched || !AppController.instance.isWatched(m.id));
      }).toList();
    });
  }

  @override
  void dispose() {
    q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const UniversalText('Advanced Search')),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        TextField(
          controller: q,
          onSubmitted: (_) => search(),
          decoration: InputDecoration(
            labelText: tr('Title, actor, director, genre or tag'),
            hintText: 'Try “horror comedy” or “romantic thriller”',
            prefixIcon: const Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('Genre combinations', style: Theme.of(context).textTheme.titleSmall),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 88,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 6,
              runSpacing: 2,
              children: GenreSystem.canonicalGenres.map((genre) => FilterChip(
                label: Text(genre),
                selected: selectedGenres.contains(genre),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      selectedGenres.add(genre);
                    } else {
                      selectedGenres.remove(genre);
                    }
                  });
                  search();
                },
              )).toList(),
            ),
          ),
        ),
        Row(children: [
          Expanded(child: DropdownButton<String>(
            value: type,
            isExpanded: true,
            items: const ['All','Movies','TV Shows'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
            onChanged: (v) { if (v != null) { setState(() => type = v); search(); } },
          )),
          const SizedBox(width: 12),
          Expanded(child: DropdownButton<String>(
            value: mood,
            isExpanded: true,
            items: <String>['Any mood', ...GenreSystem.moodGenreHints.keys]
                .map((x) => DropdownMenuItem(value: x, child: Text(x == 'Any mood' ? x : x[0].toUpperCase() + x.substring(1))))
                .toList(),
            onChanged: (v) { if (v != null) { setState(() => mood = v); search(); } },
          )),
          IconButton(onPressed: search, icon: const Icon(Icons.search)),
        ]),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            const UniversalText('Match all selected genres'),
            Switch(value: matchAllGenres, onChanged: (v) { setState(() => matchAllGenres = v); search(); }),
            const UniversalText('Unwatched only'),
            Switch(value: unwatched, onChanged: (v) { setState(() => unwatched = v); search(); }),
          ],
        ),
        if (selectedGenres.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Combination: ${GenreSystem.displayLabel(selectedGenres)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        Expanded(
          child: results.isEmpty
              ? const Center(child: UniversalText('Search your library or choose genres to find a combination.'))
              : ListView.separated(
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final media = results[i];
                    final genreLabel = GenreSystem.displayLabel(media.genres);
                    return ListTile(
                      leading: const Icon(Icons.movie_filter_rounded),
                      title: Text(media.title),
                      subtitle: Text('${media.releaseYear ?? ''} • ${media.type} • $genreLabel'),
                    );
                  },
                ),
        ),
      ]),
    ),
  );
}

class ActorFranchiseRoadmapScreen extends StatelessWidget { const ActorFranchiseRoadmapScreen({super.key}); @override Widget build(BuildContext context) { final actors = _library().expand((m) => m.actors).toSet().toList(); return Scaffold(appBar: AppBar(title: const UniversalText('Actors & Franchises')), body: ListView(padding: const EdgeInsets.all(16), children: [const UniversalText('Actors in your library', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), const SizedBox(height: 8), ...actors.map((a) => ListTile(leading: const Icon(Icons.person_outline_rounded), title: Text(a)))])); } }

/// Implements the `GroupWatchRoadmapScreen` class for this feature or UI component.
class GroupWatchRoadmapScreen extends StatelessWidget { const GroupWatchRoadmapScreen({super.key}); @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const UniversalText('Watch Together 2.0')), body: const Center(child: UniversalText('Use Group Watch from the Home screen to start a synchronized party.'))); }

class RoadmapListLayoutScreen extends StatelessWidget {
  const RoadmapListLayoutScreen({super.key});
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const UniversalText('List Layouts')),
    body: ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 8,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => Card(
        child: ListTile(
          dense: i.isEven,
          leading: CircleAvatar(child: UniversalText('${i + 1}')),
          title: Text(i.isEven ? 'Compact ListTile' : 'Spacious ListTile'),
          subtitle: const UniversalText('Constrained inside a scrolling ListView to prevent overflow.'),
        ),
      ),
    ),
  );
}

/// Implements the `ArchitectureScreen` class for this feature or UI component.
class ArchitectureScreen extends StatelessWidget { const ArchitectureScreen({super.key}); @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const UniversalText('Architecture')), body: ListView(padding: const EdgeInsets.all(20), children: const [UniversalText('Account-scoped data', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), UniversalText('Library, subscription and shared media belong to the account.', style: TextStyle(color: Colors.white70)), SizedBox(height: 20), UniversalText('Profile-scoped experience', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), UniversalText('Navigation, Home layout, Details layout, recommendations, history, wishlist and preferences belong to the selected profile.', style: TextStyle(color: Colors.white70)), SizedBox(height: 20), UniversalText('Persistence boundary', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), UniversalText('The local stores are isolated behind profile IDs so a Supabase repository can replace them without redesigning the UI.', style: TextStyle(color: Colors.white70))])); }
