import 'package:flutter/material.dart';

import 'supabase/supabase_config.dart';

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
    PlatformCapability(id: 'marketplace', title: 'Unified Marketplace', description: 'Connect entertainment discovery with approved products, merchants, restaurants and order support.', category: 'Commerce', stage: CapabilityStage.existing, icon: Icons.shopping_bag),
    PlatformCapability(id: 'music_studio', title: 'Music Studio', description: 'Artist pages, albums, playlists, lyrics and credits, connected to soundtracks and media titles.', category: 'Music', stage: CapabilityStage.existing, icon: Icons.music_note),
    PlatformCapability(id: 'membership_rewards', title: 'Unified Membership and Rewards', description: 'Transparent points and eligible benefits across platform plans, marketplace orders and food orders.', category: 'Commerce', stage: CapabilityStage.planned, icon: Icons.loyalty),
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
