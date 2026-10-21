import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'backend_api.dart';
import 'app_core.dart';
import 'app_customization.dart';
import 'social_theme_gallery.dart';
import 'music.dart';
import 'shop.dart';
import 'social_video_editor.dart';
import 'social_sharing.dart';
import 'social_reels.dart';
import 'social_story_experience.dart';
import 'friend_story_profile_viewer.dart';
import 'localization.dart';
import 'media_text_localizer.dart';
import 'social_detail_pages.dart';
import 'universal_sharing_hub.dart';

class _SocialPostDraft {
  const _SocialPostDraft({required this.body, this.photo});

  final String body;
  final XFile? photo;
}

String _socialInitial(String value) {
  final clean = value.trim();
  return clean.isEmpty ? '?' : clean.substring(0, 1).toUpperCase();
}

String _presenceState(Map<String, dynamic> member) {
  final explicit = (member['presenceStatus'] ??
          member['availability'] ??
          member['presence_status'])
      ?.toString()
      .toLowerCase();
  // A stale or explicitly away/offline presence must never keep a red/green
  // halo after the app is closed or the profile stops reporting heartbeats.
  if (const {'away', 'offline', 'invisible'}.contains(explicit)) {
    return 'offline';
  }
  final rawLastSeen =
      (member['lastSeenAt'] ?? member['last_seen_at'])?.toString();
  final lastSeen = DateTime.tryParse(rawLastSeen ?? '');
  if (lastSeen == null ||
      DateTime.now().toUtc().difference(lastSeen.toUtc()) >
          const Duration(minutes: 5)) {
    return 'offline';
  }
  if (explicit == 'busy' || explicit == 'occupied') return 'busy';
  if (explicit == 'active' || explicit == 'online') return 'active';
  return 'active';
}

Color? _presenceGlowColor(Map<String, dynamic> member) =>
    switch (_presenceState(member)) {
      'active' => Colors.greenAccent,
      'busy' => Colors.redAccent,
      _ => null,
    };

String _lastSeenPhrase(Map<String, dynamic> member) {
  final raw = (member['lastSeenAt'] ?? member['last_seen_at'])?.toString();
  final date = DateTime.tryParse(raw ?? '');
  if (date == null) return 'Last seen time unavailable';
  final difference = DateTime.now().toUtc().difference(date.toUtc());
  if (difference.inMinutes < 1) return 'Last seen just now';
  if (difference.inMinutes < 60) {
    return 'Last seen ${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
  }
  if (difference.inHours < 24) {
    return 'Last seen ${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
  }
  if (difference.inDays < 7) {
    return 'Last seen ${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
  }
  if (difference.inDays < 30) {
    final weeks = (difference.inDays / 7).floor();
    return 'Last seen $weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
  }
  if (difference.inDays < 365) {
    final months = (difference.inDays / 30).floor();
    return 'Last seen $months ${months == 1 ? 'month' : 'months'} ago';
  }
  final years = (difference.inDays / 365).floor();
  return 'Last seen $years ${years == 1 ? 'year' : 'years'} ago';
}

String _presenceTooltip(Map<String, dynamic> member) {
  final state = _presenceState(member);
  final activity =
      (member['activityText'] ?? member['activity_text'])?.toString().trim();
  if (state == 'busy') {
    return activity == null || activity.isEmpty
        ? 'Occupied'
        : 'Occupied • $activity';
  }
  if (state == 'active') {
    return activity == null || activity.isEmpty
        ? 'Online'
        : 'Online • $activity';
  }
  return _lastSeenPhrase(member);
}

Widget _presenceAvatar(Map<String, dynamic> member, String name,
    {double radius = 20}) {
  final glow = _presenceGlowColor(member);
  final avatarUrl = (member['avatar_url'] ?? member['avatarUrl'])?.toString();
  return Tooltip(
    message: _presenceTooltip(member),
    child: Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: glow == null
            ? const <BoxShadow>[]
            : [
                BoxShadow(
                    color: glow.withValues(alpha: .8),
                    blurRadius: 11,
                    spreadRadius: 2),
              ],
        border: glow == null ? null : Border.all(color: glow, width: 1.5),
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundImage: avatarUrl == null || avatarUrl.isEmpty
            ? null
            : NetworkImage(avatarUrl),
        child: avatarUrl == null || avatarUrl.isEmpty
            ? Text(_socialInitial(name))
            : null,
      ),
    ),
  );
}

Widget _memberNameLabel(Map<String, dynamic> member) {
  final name = member['display_name']?.toString() ??
      member['username']?.toString() ??
      'Member';
  final nickname = member['nickname']?.toString().trim() ?? '';
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      if (nickname.isNotEmpty)
        Text(
          nickname,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
          ),
        ),
    ],
  );
}

class _SocialReviewDraft {
  const _SocialReviewDraft({
    required this.media,
    required this.score,
    required this.body,
    required this.shareToPage,
    required this.communityIds,
  });

  final MediaItem media;
  final double score;
  final String body;
  final bool shareToPage;
  final List<String> communityIds;
}

/// Social center inspired by modern chat/feed products:
/// - stories at the top of the feed
/// - friend/community feed with lightweight reactions and comments
/// - message inbox with a desktop split-pane layout
/// - friend requests and community discovery
///
/// Social content contains references/metadata only. Media playback remains
/// owned by the existing home-server/media architecture.
class SocialCenterScreen extends StatefulWidget {
  final String? initialConversationId;

  const SocialCenterScreen({
    super.key,
    this.initialConversationId,
  });

  @override
  State<SocialCenterScreen> createState() => _SocialCenterScreenState();
}

class _SocialCenterScreenState extends State<SocialCenterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late List<String> _visibleTabSections;
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _visibleTabSections = _configuredTabSections;
    _tabs = TabController(length: _visibleTabSections.length, vsync: this);
    StoryPlacementStore.revision.addListener(_onStoryPlacementChanged);
    unawaited(_loadStoryPlacement());
    PageContentCustomizationStore.revision
        .addListener(_onPageCustomizationChanged);
    AppSectionCustomizationStore.revision
        .addListener(_onPageCustomizationChanged);
    final initialConversationId = widget.initialConversationId?.trim();
    if (initialConversationId != null && initialConversationId.isNotEmpty) {
      unawaited(_loadAndOpenInitialConversation(initialConversationId));
    } else {
      unawaited(_load());
    }
  }

  Future<void> _loadAndOpenInitialConversation(String conversationId) async {
    await _load();
    if (!mounted) return;
    final messagesIndex = _tabSections.indexOf('messages');
    if (messagesIndex >= 0) _tabs.animateTo(messagesIndex);
    await _openConversation(conversationId);
  }

  Future<void> _loadStoryPlacement() async {
    await StoryPlacementStore.load(AppController.instance.currentProfile);
    if (mounted) setState(() {});
  }

  List<String> get _configuredTabSections {
    final configured =
        PageContentCustomizationStore.settingsFor('friends').visibleSections;
    final sections = configured.isEmpty ? <String>['feed'] : configured;
    final settings = AppSectionCustomizationStore.settingsFor(
        AppController.instance.currentProfile);
    String idForLabel(String label) => switch (label) {
          'Feed' => 'feed',
          'Reels' => 'reels',
          'Messages' => 'messages',
          'Communities' => 'communities',
          'Friends' => 'friends',
          'My Page' => 'my-page',
          _ => label.toLowerCase(),
        };
    final preferred = settings.socialNavOrder
        .map(idForLabel)
        .where(sections.contains)
        .toList();
    return <String>[
      ...preferred,
      ...sections.where((section) => !preferred.contains(section))
    ];
  }

  List<String> get _tabSections => _visibleTabSections;

  void _onStoryPlacementChanged() {
    if (mounted) setState(() {});
  }

  void _onPageCustomizationChanged() {
    if (!mounted) return;
    final oldSections = _visibleTabSections;
    final activeIndex = _tabs.index.clamp(0, oldSections.length - 1).toInt();
    final activeSection = oldSections[activeIndex];
    final sections = _configuredTabSections;
    final nextIndex =
        sections.indexOf(activeSection).clamp(0, sections.length - 1).toInt();
    final previous = _tabs;
    setState(() {
      _visibleTabSections = sections;
      _tabs = TabController(
        length: sections.length,
        vsync: this,
        initialIndex: nextIndex,
      );
    });
    previous.dispose();
  }

  @override
  void dispose() {
    StoryPlacementStore.revision.removeListener(_onStoryPlacementChanged);
    PageContentCustomizationStore.revision
        .removeListener(_onPageCustomizationChanged);
    AppSectionCustomizationStore.revision
        .removeListener(_onPageCustomizationChanged);
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final controller = AppController.instance;
    final profile = controller.currentProfile;
    if (profile == null || !controller.backendApi.isAuthenticated) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Select a profile and sign in to use social features.';
      });
      return;
    }

    try {
      final data = await controller.backendApi
          .getSocialCenter(profileId: profile.id)
          .timeout(const Duration(seconds: 15),
              onTimeout: () => throw Exception(
                  'Friends could not load in time. Check your connection and try again.'));
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _act(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<Map<String, dynamic>> _list(String key) =>
      (_data?[key] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSectionCustomizationStore.revision,
      builder: (context, _) {
        final settings = AppSectionCustomizationStore.settingsFor(
            AppController.instance.currentProfile);
        return AnimatedBuilder(
          animation: _tabs,
          builder: (context, _) {
            final activeSection = _tabSections.isEmpty
                ? 'feed'
                : _tabSections[
                    _tabs.index.clamp(0, _tabSections.length - 1).toInt()];
            return Theme(
              data: _themeForSocialStyle(
                  Theme.of(context), _styleForSurface(settings, activeSection)),
              child: _buildSocialContent(),
            );
          },
        );
      },
    );
  }

  String _styleForSurface(AppSectionCustomization settings, String section) =>
      switch (section) {
        'feed' => settings.feedStyle,
        'my-page' => settings.profilePageStyle,
        'communities' => settings.communitiesStyle,
        'friends' => settings.friendsStyle,
        'messages' => settings.messagesStyle,
        'reels' => settings.reelsStyle,
        _ => 'Casual',
      };

  ThemeData _themeForSocialStyle(ThemeData base, String style) {
    final tokens = socialThemeTokensFor(style);
    final radius = tokens.radius;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(
        color: tokens.border.withValues(
          alpha: style == 'Minimalist' ? .48 : .82,
        ),
        width: tokens.borderWidth,
      ),
    );
    final scheme = ColorScheme.fromSeed(
      seedColor: tokens.accent,
      brightness: tokens.brightness,
    ).copyWith(
      primary: tokens.accent,
      onPrimary: tokens.isLight ? Colors.white : const Color(0xFF111218),
      surface: tokens.surface,
      onSurface: tokens.text,
      outline: tokens.border,
    );
    final cardElevation = switch (style) {
      'Skeuomorphic' => 5.0,
      'Material' => 2.0,
      _ => 0.0,
    };

    return base.copyWith(
      brightness: tokens.brightness,
      scaffoldBackgroundColor: tokens.canvas,
      canvasColor: tokens.canvas,
      colorScheme: scheme,
      visualDensity:
          style == 'Compact' ? VisualDensity.compact : VisualDensity.standard,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: tokens.canvas,
        foregroundColor: tokens.text,
        surfaceTintColor: Colors.transparent,
        elevation: style == 'Skeuomorphic' ? 3 : 0,
      ),
      tabBarTheme: base.tabBarTheme.copyWith(
        labelColor: tokens.accent,
        indicatorColor: tokens.accent,
        indicatorSize: TabBarIndicatorSize.label,
      ),
      cardTheme: base.cardTheme.copyWith(
        color: tokens.surface,
        elevation: cardElevation,
        shadowColor: tokens.accent.withValues(alpha: .20),
        surfaceTintColor: Colors.transparent,
        shape: shape,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: tokens.accent.withValues(
          alpha: tokens.isLight ? .10 : .15,
        ),
        selectedColor: tokens.accent.withValues(alpha: .26),
        side: BorderSide(
          color: tokens.border.withValues(alpha: .75),
          width: style == 'Brutalism' || style == 'High Contrast' ? 1.8 : 1,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            style == 'Brutalism' || style == 'Flat' ? 2 : radius,
          ),
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: tokens.surface,
        labelStyle: TextStyle(color: tokens.muted),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide:
              BorderSide(color: tokens.border, width: tokens.borderWidth),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: tokens.accent, width: 1.8),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tokens.accent,
          foregroundColor:
              tokens.isLight ? Colors.white : const Color(0xFF111218),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              style == 'Brutalism' || style == 'Flat' ? 2 : radius,
            ),
          ),
        ),
      ),
      navigationBarTheme: base.navigationBarTheme.copyWith(
        backgroundColor: tokens.surface,
        indicatorColor: tokens.accent.withValues(alpha: .22),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(color: tokens.text, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildSocialContent() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final socialSettings = AppSectionCustomizationStore.settingsFor(
        AppController.instance.currentProfile);
    final navPosition = socialSettings.socialNavPosition;

    return Column(
      children: [
        _header(showSectionNavigation: navPosition == 'Top'),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.error_outline_rounded),
                title: const UniversalText('Social services unavailable'),
                subtitle: Text(_error!),
                trailing: IconButton(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ),
            ),
          ),
        Expanded(
          child: navPosition == 'Left' || navPosition == 'Right'
              ? Row(children: [
                  if (navPosition == 'Left') _sideSectionNavigation(),
                  Expanded(
                      child: TabBarView(
                          controller: _tabs,
                          children: _tabSections.map(_pageForTab).toList())),
                  if (navPosition == 'Right') _sideSectionNavigation(),
                ])
              : TabBarView(
                  controller: _tabs,
                  children: _tabSections.map(_pageForTab).toList()),
        ),
      ],
    );
  }

  Widget _header({bool showSectionNavigation = true}) {
    final stories = _list('stories');
    final conversations = _list('conversations');
    final requests = _list('requests');

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.people_alt_rounded, size: 30),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UniversalText(
                      'Friends & Community',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                    UniversalText(
                      'Watch together, talk about media, and share what you are enjoying.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
              ),
              IconButton(
                tooltip: 'Create account group chat',
                onPressed: _newAccountGroupMessage,
                icon: const Icon(Icons.group_work_outlined),
              ),
              FilledButton.icon(
                onPressed: _newMessage,
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: const UniversalText('Message'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (showSectionNavigation)
            TabBar(
              controller: _tabs,
              isScrollable: true,
              tabs: _tabSections.map((section) {
                return switch (section) {
                  'feed' => const Tab(
                      text: 'Feed',
                      icon: Icon(Icons.dynamic_feed_rounded),
                    ),
                  'reels' => const Tab(
                      text: 'Reels',
                      icon: Icon(Icons.play_circle_outline_rounded),
                    ),
                  'messages' => Tab(
                      text: conversations.isEmpty
                          ? 'Messages'
                          : 'Messages (${conversations.length})',
                      icon: const Icon(Icons.forum_rounded),
                    ),
                  'friends' => Tab(
                      text: requests.isEmpty
                          ? 'Friends'
                          : 'Friends (${requests.length})',
                      icon: const Icon(Icons.people_outline_rounded),
                    ),
                  'communities' => const Tab(
                      text: 'Communities',
                      icon: Icon(Icons.groups_rounded),
                    ),
                  'my-page' => const Tab(
                      text: 'My Page',
                      icon: Icon(Icons.account_circle_outlined),
                    ),
                  _ => const Tab(text: 'Social'),
                };
              }).toList(),
            ),
          const SizedBox(height: 10),
          if (StoryPlacementStore.showsOnFriends(
              AppController.instance.currentProfile))
            SizedBox(
              height: 106,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _storyComposer(),
                  ...stories.map(_storyBubble),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _socialSurfaceLabel(String section) => switch (section) {
        'feed' => 'Feed',
        'reels' => 'Reels',
        'messages' => 'Messages',
        'friends' => 'Friends',
        'communities' => 'Communities',
        'my-page' => 'My Page',
        _ => section,
      };

  Widget _sideSectionNavigation() {
    final selectedIndex = _tabs.index.clamp(0, _tabSections.length - 1).toInt();
    return Container(
      width: 92,
      color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: .8),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        itemCount: _tabSections.length,
        itemBuilder: (context, index) {
          final section = _tabSections[index];
          final selected = index == selectedIndex;
          final icon = switch (section) {
            'feed' => Icons.dynamic_feed_rounded,
            'reels' => Icons.play_circle_outline_rounded,
            'messages' => Icons.forum_rounded,
            'friends' => Icons.people_outline_rounded,
            'communities' => Icons.groups_rounded,
            'my-page' => Icons.account_circle_outlined,
            _ => Icons.apps_rounded,
          };
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Material(
              color: selected
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: .18)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _tabs.animateTo(index),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                  child: Column(children: [
                    Icon(icon,
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : null),
                    const SizedBox(height: 4),
                    Text(_socialSurfaceLabel(section),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight:
                                selected ? FontWeight.w800 : FontWeight.w500)),
                  ]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _pageForTab(String section) => switch (section) {
        'feed' => _feedTab(),
        'reels' => SocialReelsScreen(
            posts: <Map<String, dynamic>>[
              ..._list('posts'),
              ..._list('communityPosts'),
            ],
            onRefresh: _load,
          ),
        'messages' => _messagesTab(),
        'friends' => _friendsTab(),
        'communities' => _communitiesTab(),
        'my-page' => _myPageTab(),
        _ => const SizedBox.shrink(),
      };

  Widget _feedTab() {
    final posts = <Map<String, dynamic>>[
      ..._list('posts'),
      ..._list('communityPosts'),
    ]..sort((a, b) => (b['created_at']?.toString() ?? '')
        .compareTo(a['created_at']?.toString() ?? ''));
    final profile = AppController.instance.currentProfile;
    if (profile == null) return const SizedBox.shrink();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
        children: [
          _composerCard(profile.id),
          const SizedBox(height: 12),
          if (posts.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.dynamic_feed_outlined),
                title: UniversalText('Your social feed is quiet'),
                subtitle: UniversalText(
                  'Add friends, join a community, or share a story to get started.',
                ),
              ),
            ),
          ...posts.map(_postCard),
        ],
      ),
    );
  }

  Widget _myPageTab() {
    final profile = AppController.instance.currentProfile;
    if (profile == null) return const SizedBox.shrink();
    final profileSettings = AppSectionCustomizationStore.settingsFor(profile);
    final posts = _list('posts')
        .where((post) =>
            post['isMine'] == true ||
            post['author_profile_id']?.toString() == profile.id ||
            post['authorProfileId']?.toString() == profile.id)
        .toList()
      ..sort((a, b) {
        final dateA = DateTime.tryParse(
                (a['created_at'] ?? a['createdAt'])?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = DateTime.tryParse(
                (b['created_at'] ?? b['createdAt'])?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return profileSettings.profilePostsSortOrder == 'Oldest to Newest'
            ? dateA.compareTo(dateB)
            : dateB.compareTo(dateA);
      });
    final totalFriends = _list('friends').length;
    final totalPosts =
        (_data?['ownPostCount'] as num?)?.toInt() ?? posts.length;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundImage: profile.avatarUrl == null ||
                                profile.avatarUrl!.trim().isEmpty
                            ? null
                            : NetworkImage(profile.avatarUrl!),
                        child: profile.avatarUrl == null ||
                                profile.avatarUrl!.trim().isEmpty
                            ? Text(_initial(profile.name))
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              '$totalFriends friends • $totalPosts posts',
                              style: const TextStyle(color: Colors.white54),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Edit profile',
                        onPressed: _busy ? null : _editMyProfile,
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: _profileCountShortcut(
                      icon: Icons.people_alt_outlined,
                      label: 'Friends',
                      value: '$totalFriends',
                      section: 'Friends',
                    )),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _profileCountShortcut(
                      icon: Icons.storefront_outlined,
                      label: 'Following',
                      value:
                          '${(_data?['followingCount'] as num?)?.toInt() ?? _list('following').length}',
                      section: 'Following',
                    )),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _profileCountShortcut(
                      icon: Icons.groups_outlined,
                      label: 'Communities',
                      value:
                          '${(_data?['communityCount'] as num?)?.toInt() ?? _list('communities').where((item) => item['joined'] == true).length}',
                      section: 'Communities',
                    )),
                  ]),
                  const SizedBox(height: 14),
                  const UniversalText(
                    'Your page combines your social posts, media reviews, shorts, and community shares.',
                    style: TextStyle(color: Colors.white60, height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _busy ? null : _composePagePost,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: const UniversalText('Post or photo'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _composeReview,
                        icon: const Icon(Icons.rate_review_outlined),
                        label: const UniversalText('Write a review'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : () => _createShort(),
                        icon: const Icon(Icons.movie_creation_outlined),
                        label: const UniversalText('Create Short'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (posts.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.lock_outline_rounded),
                title: UniversalText('Your friends-only page is ready'),
                subtitle: UniversalText(
                  'Share a post, a photo, or a media review to get started.',
                ),
              ),
            ),
          if (profileSettings.profilePageViewMode == 'Post cards' &&
              posts.isNotEmpty)
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 800
                    ? 3
                    : constraints.maxWidth >= 520
                        ? 2
                        : 1;
                final width =
                    (constraints.maxWidth - (columns - 1) * 10) / columns;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: posts
                      .map((post) => SizedBox(
                            width: width,
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      const Icon(Icons.article_outlined,
                                          size: 18),
                                      const SizedBox(width: 6),
                                      Expanded(
                                          child: Text(
                                              post['author_profile_name']
                                                      ?.toString() ??
                                                  profile.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w800)))
                                    ]),
                                    const SizedBox(height: 8),
                                    Text(post['body']?.toString() ?? '',
                                        maxLines: 6,
                                        overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 8),
                                    Text(post['created_at']?.toString() ?? '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 10)),
                                  ],
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                );
              },
            )
          else
            ...posts.map(_postCard),
        ],
      ),
    );
  }

  Widget _profileCountShortcut(
          {required IconData icon,
          required String label,
          required String value,
          required String section}) =>
      InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => SocialConnectionsScreen(initialSection: section),
        )),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(children: [
            Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 5),
            Text(value,
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white60, fontSize: 11)),
          ]),
        ),
      );

  Future<void> _editMyProfile() async {
    final profile = AppController.instance.currentProfile;
    if (profile == null) return;
    final nameController = TextEditingController(text: profile.name);
    final avatarController =
        TextEditingController(text: profile.avatarUrl ?? '');
    final result = await showDialog<(String, String?)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const UniversalText('Edit profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Profile name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            TextField(
              controller: avatarController,
              maxLength: 2048,
              decoration: const InputDecoration(
                labelText: 'Avatar URL (optional)',
                hintText: 'https://…',
                prefixIcon: Icon(Icons.image_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const UniversalText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              (
                nameController.text.trim(),
                avatarController.text.trim().isEmpty
                    ? null
                    : avatarController.text.trim()
              ),
            ),
            child: const UniversalText('Save'),
          ),
        ],
      ),
    );
    nameController.dispose();
    avatarController.dispose();
    if (result == null || result.$1.isEmpty) return;
    await _act(() async {
      final response = await AppController.instance.backendApi.updateProfile(
        profileId: profile.id,
        name: result.$1,
        avatarUrl: result.$2,
      );
      final updated = response['profile'];
      if (updated is Map) {
        final values = Map<String, dynamic>.from(updated);
        profile.name = values['name']?.toString() ?? result.$1;
        profile.avatarUrl = values['avatarUrl']?.toString();
      } else {
        profile.name = result.$1;
        profile.avatarUrl = result.$2;
      }
      if (mounted) setState(() {});
    });
  }

  Future<void> _composePagePost() async {
    final profile = AppController.instance.currentProfile;
    if (profile == null) return;
    final controller = TextEditingController();
    XFile? photo;
    final draft = await showDialog<_SocialPostDraft>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const UniversalText('Post to My Page'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 4,
                maxLength: 4000,
                decoration: const InputDecoration(
                  hintText: 'Share with your friends',
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 1600,
                      imageQuality: 85,
                    );
                    if (picked != null) setDialogState(() => photo = picked);
                  },
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(photo?.name ?? 'Add a photo'),
                ),
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: UniversalText(
                  'Photos are private and shown only to authorized friends.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const UniversalText('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                _SocialPostDraft(body: controller.text.trim(), photo: photo),
              ),
              child: const UniversalText('Post'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (draft == null) return;
    if (draft.body.isEmpty) {
      _showMessage('Add a caption before publishing your photo or post.');
      return;
    }

    await _act(() async {
      Map<String, dynamic>? mediaReference;
      if (draft.photo != null) {
        final extension = draft.photo!.name.split('.').last.toLowerCase();
        final contentType = switch (extension) {
          'png' => 'image/png',
          'webp' => 'image/webp',
          'jpg' || 'jpeg' => 'image/jpeg',
          _ => throw const FormatException(
              'Choose a JPEG, PNG, or WebP photo.',
            ),
        };
        final bytes = await draft.photo!.readAsBytes();
        if (bytes.length > 5 * 1024 * 1024) {
          throw const FormatException('Photos must be 5 MB or smaller.');
        }
        final path =
            await AppController.instance.backendApi.uploadSocialAttachment(
          profileId: profile.id,
          bytes: bytes,
          contentType: contentType,
        );
        mediaReference = {'type': 'photo', 'photoPath': path};
      }
      await AppController.instance.backendApi.createSocialPost(
        profileId: profile.id,
        body: draft.body,
        mediaReference: mediaReference,
      );
    });
  }

  Future<void> _composeReview() async {
    final profile = AppController.instance.currentProfile;
    if (profile == null) return;
    final media = AppController.instance.library;
    if (media.isEmpty) {
      _showMessage('Add media to your library before writing a review.');
      return;
    }
    final communities = _list('communities')
        .where((community) => community['joined'] == true)
        .toList();
    final draft = await _reviewDraftDialog(media, communities);
    if (draft == null || draft.body.trim().isEmpty) return;

    await _act(() async {
      final label = _reviewLabel(draft.score);
      final response = await AppController.instance.backendApi.submitReview(
        mediaId: draft.media.id,
        profileId: profile.id,
        score: draft.score,
        label: label,
        text: draft.body.trim(),
      );
      final review = response['review'] is Map
          ? Map<String, dynamic>.from(response['review'] as Map)
          : <String, dynamic>{};
      final reference = <String, dynamic>{
        'type': 'review',
        'reviewId': review['id']?.toString() ?? '',
        'mediaId': draft.media.id,
        'mediaTitle': draft.media.title,
        'score': draft.score,
        'label': label,
      };
      if (draft.shareToPage) {
        await AppController.instance.backendApi.createSocialPost(
          profileId: profile.id,
          body: draft.body.trim(),
          mediaReference: reference,
        );
      }
      if (draft.communityIds.isNotEmpty) {
        await AppController.instance.backendApi.createSocialPost(
          profileId: profile.id,
          body: draft.body.trim(),
          communityIds: draft.communityIds,
          mediaReference: reference,
        );
      }
    });
  }

  Future<_SocialReviewDraft?> _reviewDraftDialog(
    List<MediaItem> media,
    List<Map<String, dynamic>> communities,
  ) async {
    final controller = TextEditingController();
    var selectedMediaId = media.first.id;
    var score = 8.0;
    var shareToPage = true;
    final selectedCommunities = <String>{};
    final result = await showDialog<_SocialReviewDraft>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          scrollable: true,
          title: const UniversalText('Write a media review'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedMediaId,
                decoration: const InputDecoration(labelText: 'Media'),
                items: media
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(
                          item.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selectedMediaId = value);
                  }
                },
              ),
              const SizedBox(height: 10),
              Text('Score: ${score.toStringAsFixed(1)}/10'),
              Slider(
                min: 0,
                max: 10,
                divisions: 20,
                value: score,
                label: score.toStringAsFixed(1),
                onChanged: (value) => setDialogState(() => score = value),
              ),
              TextField(
                controller: controller,
                maxLines: 5,
                maxLength: 4000,
                decoration: const InputDecoration(
                  labelText: 'Your review',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const UniversalText('Share to My Page'),
                subtitle:
                    const UniversalText('Visible to your accepted friends'),
                value: shareToPage,
                onChanged: (value) => setDialogState(() => shareToPage = value),
              ),
              if (communities.isNotEmpty) ...[
                const UniversalText(
                  'Also share to communities',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                for (final community in communities)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(community['name']?.toString() ?? 'Community'),
                    value: selectedCommunities
                        .contains(community['id'].toString()),
                    onChanged: (selected) {
                      setDialogState(() {
                        final id = community['id'].toString();
                        if (selected == true) {
                          selectedCommunities.add(id);
                        } else {
                          selectedCommunities.remove(id);
                        }
                      });
                    },
                  ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const UniversalText('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final selected = media.firstWhere(
                  (item) => item.id == selectedMediaId,
                );
                Navigator.pop(
                  dialogContext,
                  _SocialReviewDraft(
                    media: selected,
                    score: score,
                    body: controller.text,
                    shareToPage: shareToPage,
                    communityIds: selectedCommunities.toList(),
                  ),
                );
              },
              child: const UniversalText('Save review'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (result != null && !result.shareToPage && result.communityIds.isEmpty) {
      _showMessage('Choose My Page, at least one community, or both to share.');
      return null;
    }
    return result;
  }

  String _reviewLabel(double score) => switch (score) {
        >= 8.5 => 'Excellent',
        >= 7 => 'Good',
        >= 5 => 'Mixed',
        _ => 'Poor',
      };

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _composerCard(String profileId) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const CircleAvatar(child: Icon(Icons.person_rounded)),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => _composePost(profileId),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .06),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const UniversalText(
                    'What are you watching, listening to, or collecting?',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Story',
              onPressed: _composeStory,
              icon: const Icon(Icons.add_circle_outline_rounded),
            ),
            IconButton(
              tooltip: 'Create short video',
              onPressed: () => _createShort(),
              icon: const Icon(Icons.video_call_outlined),
            ),
            IconButton(
              tooltip: 'Create video story',
              onPressed: () => _createShort(asStory: true),
              icon: const Icon(Icons.add_a_photo_outlined),
            ),
          ],
        ),
      ),
    );
  }

  Widget _postCard(Map<String, dynamic> post) {
    final author = post['author'] is Map
        ? Map<String, dynamic>.from(post['author'] as Map)
        : <String, dynamic>{};
    final displayName = author['display_name']?.toString() ??
        post['author_profile_name']?.toString() ??
        'Friend';
    final username = author['username']?.toString();
    final reaction = post['myReaction']?.toString();
    final isCommunity = post['communityPost'] == true;
    final mediaReference = post['mediaReference'] is Map
        ? Map<String, dynamic>.from(post['mediaReference'] as Map)
        : post['media_reference'] is Map
            ? Map<String, dynamic>.from(post['media_reference'] as Map)
            : <String, dynamic>{};

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Text(_initial(displayName))),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        [
                          if (username != null && username.isNotEmpty)
                            '@$username',
                          if (isCommunity) 'Community post',
                        ].join('  ·  '),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.more_horiz_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              post['body']?.toString() ?? '',
              style: const TextStyle(fontSize: 15, height: 1.4),
            ),
            if (mediaReference['type'] == 'review') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.rate_review_outlined, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${mediaReference['mediaTitle'] ?? 'Media'} · ${mediaReference['score'] ?? ''}/10',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (mediaReference['type'] == 'product') ...[
              const SizedBox(height: 10),
              _socialProductCard(mediaReference),
            ],
            if (mediaReference['type'] == 'chat_invite') ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .045),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(child: Icon(Icons.forum_rounded)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              mediaReference['conversationTitle']?.toString() ??
                                  'Group chat',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w900)),
                          const UniversalText(
                              'Group chat invitation · expires in 30 days',
                              style: TextStyle(
                                  color: Colors.white60, fontSize: 11)),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => _acceptChatInvite(mediaReference),
                      icon: const Icon(Icons.login_rounded, size: 17),
                      label: const UniversalText('Join chat'),
                    ),
                  ],
                ),
              ),
            ],
            if (mediaReference['imageUrl'] != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  mediaReference['imageUrl'].toString(),
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            ],
            if (mediaReference['type'] == 'video') ...[
              const SizedBox(height: 10),
              Text(
                'Related to ${mediaReference['relatedMediaTitle'] ?? 'library media'}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (mediaReference['coverUrl'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: InkWell(
                    onTap: () {
                      final videoUrl = mediaReference['videoUrl']?.toString();
                      if (videoUrl != null) _playSocialVideo(videoUrl);
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            mediaReference['coverUrl'].toString(),
                            width: double.infinity,
                            height: 260,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox(height: 160),
                          ),
                        ),
                        const CircleAvatar(
                          backgroundColor: Colors.black54,
                          child: Icon(Icons.play_arrow_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${post['reactionCount'] ?? 0} reactions',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(width: 12),
                Text(
                  '${post['commentCount'] ?? 0} comments',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
            const Divider(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _reactToPost(
                      post['id']?.toString() ?? '',
                      reaction == '❤️' ? 'remove' : '❤️',
                    ),
                    icon: Icon(
                      reaction == '❤️'
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: reaction == '❤️' ? Colors.redAccent : null,
                    ),
                    label: const UniversalText('Like'),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _commentPost(post['id']?.toString() ?? ''),
                    icon: const Icon(Icons.mode_comment_outlined),
                    label: const UniversalText('Comment'),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _sharePost(post),
                    icon: const Icon(Icons.send_outlined),
                    label: const UniversalText('Share'),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _openPostDetail(post),
                icon: const Icon(Icons.open_in_new_rounded, size: 17),
                label: const UniversalText('View discussion'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPostDetail(Map<String, dynamic> post) async {
    final postId = post['id']?.toString() ?? '';
    if (postId.isEmpty) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => SocialPostDetailScreen(postId: postId, initialPost: post),
    ));
  }

  Future<void> _openFriendProfile(Map<String, dynamic> friend) async {
    final accountId = friend['id']?.toString() ?? '';
    final profileId = friend['profileId']?.toString() ?? '';
    if (accountId.isEmpty || profileId.isEmpty) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => SocialProfileDetailScreen(
        targetAccountId: accountId,
        targetProfileId: profileId,
        initialProfile: friend,
      ),
    ));
  }

  Widget _socialProductCard(Map<String, dynamic> reference) {
    final productId = reference['productId']?.toString();
    final product =
        productId == null ? null : ShopCatalog.instance.productById(productId);
    final title = product?.name ?? reference['title']?.toString() ?? 'Product';
    final description = product?.description ??
        reference['description']?.toString() ??
        'Open the product page for details and purchasing.';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: product == null
            ? null
            : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ShopProductDetailsScreen(product: product),
                  ),
                ),
        child: Row(
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: product?.imageUrls.isNotEmpty == true
                  ? Image.network(product!.imageUrls.first, fit: BoxFit.cover)
                  : const Center(child: Icon(Icons.shopping_bag_outlined)),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const UniversalText(
                      'PRODUCT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product == null
                          ? description
                          : '${product.price.toStringAsFixed(2)} ${product.currency} • ${product.inventoryQuantity} in stock',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white60),
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Widget _messagesTab() {
    final conversations = _list('conversations');
    return Row(
      children: [
        SizedBox(
          width: MediaQuery.sizeOf(context).width >= 850
              ? 330
              : MediaQuery.sizeOf(context).width * .40,
          child: Container(
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.white10)),
            ),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: UniversalText(
                          'Messages',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Create account group chat',
                        onPressed: _newAccountGroupMessage,
                        icon: const Icon(Icons.group_work_outlined),
                      ),
                      IconButton(
                        tooltip: 'Message an account profile',
                        onPressed: _newAccountDirectMessage,
                        icon: const Icon(Icons.person_search_rounded),
                      ),
                      IconButton(
                        tooltip: 'Create group chat with friends',
                        onPressed: _newGroupMessage,
                        icon: const Icon(Icons.group_add_outlined),
                      ),
                      IconButton(
                        tooltip:
                            'Share anything, view shared items, polls, and Watch Party plans',
                        onPressed: () =>
                            Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => UniversalSharingHubScreen(
                            conversations: conversations
                                .map((e) => Map<String, dynamic>.from(e))
                                .toList(),
                          ),
                        )),
                        icon: const Icon(Icons.ios_share_rounded),
                      ),
                      IconButton(
                        tooltip: 'New direct message to a friend',
                        onPressed: _newMessage,
                        icon: const Icon(Icons.edit_rounded),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintText: 'Search messages',
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: .04),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                if (conversations.isEmpty)
                  const ListTile(
                    leading: Icon(Icons.forum_outlined),
                    title: UniversalText('No conversations yet'),
                    subtitle: UniversalText('Start one with a friend.'),
                  ),
                ...conversations.map(_conversationTile),
              ],
            ),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(28),
            alignment: Alignment.center,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.forum_rounded, size: 58, color: Colors.white24),
                SizedBox(height: 12),
                UniversalText(
                  'Select a conversation',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 4),
                UniversalText(
                  'Messages stay profile-scoped and never grant media playback access.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _conversationTile(Map<String, dynamic> conversation) {
    final members = (conversation['members'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final other = members.firstWhere(
      (item) => item['isSelf'] != true,
      orElse: () => members.isNotEmpty ? members.first : <String, dynamic>{},
    );
    final name = conversation['kind'] == 'group'
        ? (conversation['title']?.toString().trim().isNotEmpty == true
            ? conversation['title'].toString()
            : 'Group chat')
        : other['display_name']?.toString() ??
            other['username']?.toString() ??
            'Conversation';
    final last = conversation['lastMessage'] is Map
        ? Map<String, dynamic>.from(conversation['lastMessage'] as Map)
        : <String, dynamic>{};
    final unread = (conversation['unreadCount'] as num?)?.toInt() ?? 0;

    return ListTile(
      onTap: () => _openConversation(conversation['id']?.toString() ?? ''),
      leading: _presenceAvatar(other, name, radius: 23),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        last['body']?.toString() ?? 'Start a conversation',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white54),
      ),
      trailing: unread > 0
          ? CircleAvatar(
              radius: 11,
              child: Text(
                '$unread',
                style: const TextStyle(fontSize: 10),
              ),
            )
          : null,
    );
  }

  Widget _friendsTab() {
    final friends = _list('friends');
    final requests = _list('requests');
    final guardianRequests = _list('guardianRequests');
    final suggestions = _list('suggestions');
    return AnimatedBuilder(
      animation: AppSectionCustomizationStore.revision,
      builder: (context, _) {
        final settings = AppSectionCustomizationStore.settingsFor(
            AppController.instance.currentProfile);
        friends.sort((a, b) {
          final nameA = (a['display_name'] ?? a['username'] ?? '')
              .toString()
              .toLowerCase();
          final nameB = (b['display_name'] ?? b['username'] ?? '')
              .toString()
              .toLowerCase();
          final dateA = DateTime.tryParse(
                  (a['friends_since'] ?? a['created_at'])?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final dateB = DateTime.tryParse(
                  (b['friends_since'] ?? b['created_at'])?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return switch (settings.friendsSortOrder) {
            'Z-A' => nameB.compareTo(nameA),
            'Newest to Oldest' => dateB.compareTo(dateA),
            'Oldest to Newest' => dateA.compareTo(dateB),
            _ => nameA.compareTo(nameB),
          };
        });
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Row(children: [
                Expanded(
                    child: Text('Your people • ${friends.length} friends',
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w900))),
                TextButton.icon(
                  onPressed: () =>
                      Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => const SocialConnectionsScreen(
                        initialSection: 'Friends'),
                  )),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const UniversalText('View all'),
                ),
                FilledButton.icon(
                    onPressed: _addFriend,
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const UniversalText('Add Friend')),
              ]),
              const SizedBox(height: 10),
              if (friends.isEmpty)
                const Card(
                    child: ListTile(
                        leading: Icon(Icons.person_search_rounded),
                        title: UniversalText('No friends yet'),
                        subtitle: UniversalText(
                            'Use a unique @username to connect.'))),
              ...friends.map((friend) =>
                  _friendDisplayCard(friend, settings.friendsViewMode)),
              if (requests.isNotEmpty) ...[
                const SizedBox(height: 20),
                const UniversalText('Friend requests',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                ...requests.map(_requestCard),
              ],
              if (guardianRequests.isNotEmpty) ...[
                const SizedBox(height: 20),
                const UniversalText('Guardian approval queue',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const UniversalText(
                    'Requests sent to a supervised profile are held here for a guardian decision.',
                    style: TextStyle(color: Colors.white60, fontSize: 12)),
                const SizedBox(height: 8),
                ...guardianRequests.map(_guardianRequestCard),
              ],
              if (suggestions.isNotEmpty) ...[
                const SizedBox(height: 20),
                const UniversalText('People you may know',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                ...suggestions.map(_suggestionCard),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _friendDisplayCard(Map<String, dynamic> friend, String viewMode) {
    final name = friend['display_name']?.toString() ?? 'Friend';
    final username = friend['username']?.toString() ?? '';
    final friendSince = DateTime.tryParse(
        (friend['friends_since'] ?? friend['created_at'])?.toString() ?? '');
    final subtitle = <String>[
      if (username.isNotEmpty) '@$username',
      if (friendSince != null)
        'Friends since ${friendSince.toLocal().toString().split(' ').first}',
      _presenceTooltip(friend),
    ].join(' • ');
    final content = ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      leading:
          _presenceAvatar(friend, name, radius: viewMode == 'Cards' ? 24 : 19),
      title: Text(name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      onTap: () => _openFriendProfile(friend),
      trailing: Wrap(
          spacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Chip(label: UniversalText('Friend')),
            IconButton(
                tooltip: 'Message',
                onPressed: () => _startMessageFor(username),
                icon: const Icon(Icons.chat_bubble_outline_rounded)),
          ]),
    );
    return viewMode == 'Cards'
        ? Card(clipBehavior: Clip.antiAlias, child: content)
        : content;
  }

  Widget _guardianRequestCard(Map<String, dynamic> request) {
    final sender = request['sender'] is Map
        ? Map<String, dynamic>.from(request['sender'] as Map)
        : <String, dynamic>{};
    final profile = AppController.instance.currentProfile;
    if (profile == null) return const SizedBox.shrink();
    final friendshipId = request['id']?.toString() ?? '';
    final senderName = sender['display_name']?.toString() ??
        sender['username']?.toString() ??
        'Someone';
    final childName =
        request['childProfileName']?.toString() ?? 'child profile';
    return Card(
        child: ListTile(
      leading: const Icon(Icons.family_restroom_rounded),
      title: Text('$senderName wants to add $childName'),
      subtitle:
          Text('@${sender['username'] ?? ''} • Waiting for guardian approval'),
      trailing: Wrap(spacing: 4, children: [
        TextButton(
            onPressed: friendshipId.isEmpty
                ? null
                : () => _act(() async {
                      await AppController.instance.backendApi
                          .respondGuardianFriendRequest(
                              profileId: profile.id,
                              friendshipId: friendshipId,
                              action: 'block');
                    }),
            child: const UniversalText('Block')),
        FilledButton(
            onPressed: friendshipId.isEmpty
                ? null
                : () => _act(() async {
                      await AppController.instance.backendApi
                          .respondGuardianFriendRequest(
                              profileId: profile.id,
                              friendshipId: friendshipId,
                              action: 'approve');
                    }),
            child: const UniversalText('Approve')),
      ]),
    ));
  }

  Future<void> _openCommunityDetail(Map<String, dynamic> community) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => SocialCommunityDetailScreen(
        community: Map<String, dynamic>.from(community),
      ),
    ));
    if (mounted) await _load();
  }

  Widget _communitiesTab() {
    final profile = AppController.instance.currentProfile;
    final allCommunities = _list('communities');
    final posts = _list('communityPosts');
    final stories = _list('communityStories');
    return AnimatedBuilder(
      animation: AppSectionCustomizationStore.revision,
      builder: (context, _) {
        final settings = AppSectionCustomizationStore.settingsFor(profile);
        final communities = allCommunities.where((community) {
          final joined = community['joined'] == true;
          final creator = (community['created_by_profile_id'] ??
                  community['createdByProfileId'] ??
                  community['owner_profile_id'])
              ?.toString();
          switch (settings.communitiesMembershipFilter) {
            case 'Joined':
              return joined;
            case 'Created':
              return profile != null && creator == profile.id;
            default:
              return true;
          }
        }).toList();
        int dateCompare(
            Map<String, dynamic> a, Map<String, dynamic> b, String field) {
          final da = DateTime.tryParse((a[field] ?? '').toString()) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final db = DateTime.tryParse((b[field] ?? '').toString()) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return da.compareTo(db);
        }

        communities.sort((a, b) {
          switch (settings.communitiesSortOrder) {
            case 'Oldest to Newest':
              return dateCompare(a, b, 'created_at');
            case 'Newest to Oldest':
              return dateCompare(b, a, 'created_at');
            case 'Joined':
              return dateCompare(b, a, 'joined_at');
            case 'Created':
              return dateCompare(b, a, 'created_at');
            case 'Movies':
            case 'Shows':
            case 'Music':
              final target = settings.communitiesSortOrder.toLowerCase();
              int rank(Map<String, dynamic> community) {
                final type =
                    (community['category'] ?? community['media_type'] ?? '')
                        .toString()
                        .toLowerCase();
                return type == target ? 0 : 1;
              }
              final byCategory = rank(a).compareTo(rank(b));
              return byCategory != 0
                  ? byCategory
                  : (a['name']?.toString() ?? '')
                      .compareTo(b['name']?.toString() ?? '');
            default:
              return (a['name']?.toString() ?? '')
                  .compareTo(b['name']?.toString() ?? '');
          }
        });
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(padding: const EdgeInsets.all(18), children: [
            Row(children: [
              Expanded(
                  child: Text('Communities • ${communities.length}',
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w900))),
              FilledButton.icon(
                  onPressed: _createCommunity,
                  icon: const Icon(Icons.add_rounded),
                  label: const UniversalText('Create')),
            ]),
            const SizedBox(height: 10),
            if (communities.isEmpty)
              const Card(
                  child: ListTile(
                      leading: Icon(Icons.groups_rounded),
                      title: UniversalText('No matching communities'),
                      subtitle: UniversalText(
                          'Try another filter or create a community.'))),
            ...communities.map((community) {
              final communityId = community['id']?.toString() ?? '';
              final isJoined = community['joined'] == true;
              final creatorId = (community['created_by_profile_id'] ??
                      community['createdByProfileId'] ??
                      community['owner_profile_id'])
                  ?.toString();
              final currentIsCreator =
                  profile != null && creatorId == profile.id;
              final communityPosts = posts.where((post) {
                final ids = (post['communityIds'] as List? ?? const [])
                    .map((id) => id.toString());
                return post['community_id']?.toString() == communityId ||
                    ids.contains(communityId);
              });
              final communityStories = stories.where(
                  (story) => story['community_id']?.toString() == communityId);
              final category = (community['category'] ?? 'general').toString();
              final subtitle = <String>[
                if (category.isNotEmpty) category,
                if (isJoined) 'Joined',
                if (currentIsCreator) 'Created by you'
              ].join(' • ');
              if (settings.communitiesViewMode == 'List') {
                return Card(
                    child: ListTile(
                  onTap: () => _openCommunityDetail(community),
                  leading:
                      const CircleAvatar(child: Icon(Icons.groups_rounded)),
                  title: Text(community['name']?.toString() ?? 'Community'),
                  subtitle: Text(
                    '${community['description']?.toString() ?? ''}\n${community['memberCount'] ?? 0} members · ${community['postCount'] ?? 0} posts${subtitle.isEmpty ? '' : ' · $subtitle'}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  isThreeLine: true,
                  trailing: isJoined
                      ? const Chip(label: UniversalText('Joined'))
                      : FilledButton(
                          onPressed: () => _act(() => AppController
                              .instance.backendApi
                              .joinSocialCommunity(
                                  profileId:
                                      AppController.instance.currentProfile!.id,
                                  communityId: communityId)),
                          child: const UniversalText('Join')),
                ));
              }
              return Card(
                  child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        onTap: () => _openCommunityDetail(community),
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                            child: Icon(Icons.groups_rounded)),
                        title: Text(
                            community['name']?.toString() ?? 'Community',
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(
                          '${community['description']?.toString() ?? ''}\n${community['memberCount'] ?? 0} members · ${community['postCount'] ?? 0} posts${subtitle.isEmpty ? '' : ' · $subtitle'}',
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                        isThreeLine: true,
                        trailing: isJoined
                            ? const Chip(label: UniversalText('Joined'))
                            : FilledButton(
                                onPressed: () => _act(() => AppController
                                    .instance.backendApi
                                    .joinSocialCommunity(
                                        profileId: AppController
                                            .instance.currentProfile!.id,
                                        communityId: communityId)),
                                child: const UniversalText('Join')),
                      ),
                      if (isJoined) ...[
                        Wrap(spacing: 8, children: [
                          TextButton.icon(
                              onPressed: () => _openCommunityDetail(community),
                              icon: const Icon(Icons.open_in_new_rounded),
                              label: const UniversalText('View community')),
                          TextButton.icon(
                              onPressed: () =>
                                  _composeCommunityPost(communityId),
                              icon: const Icon(Icons.post_add_rounded),
                              label: const UniversalText('Post')),
                          TextButton.icon(
                              onPressed: () =>
                                  _composeStory(communityId: communityId),
                              icon: const Icon(Icons.add_circle_outline),
                              label: const UniversalText('Story')),
                        ]),
                        if (communityStories.isNotEmpty) ...[
                          const UniversalText('Stories',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          SizedBox(
                              height: 92,
                              child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: communityStories
                                      .map(_storyBubble)
                                      .toList())),
                        ],
                        if (communityPosts.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const UniversalText('Community posts',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          ...communityPosts.map(_postCard),
                        ],
                      ],
                    ]),
              ));
            }),
          ]),
        );
      },
    );
  }

  Widget _requestCard(Map<String, dynamic> request) {
    final sender = request['sender'] is Map
        ? Map<String, dynamic>.from(request['sender'] as Map)
        : <String, dynamic>{};
    final profile = AppController.instance.currentProfile;
    if (profile == null) return const SizedBox.shrink();
    return Card(
      child: ListTile(
        leading: const Icon(Icons.person_add_alt_1_rounded),
        title: Text(sender['display_name']?.toString() ?? 'Someone'),
        subtitle: Text('@${sender['username'] ?? ''}'),
        trailing: Wrap(
          children: [
            TextButton(
              onPressed: () => _act(
                () => AppController.instance.backendApi.respondFriendRequest(
                  profileId: profile.id,
                  friendshipId: request['id'].toString(),
                  action: 'decline',
                ),
              ),
              child: const UniversalText('Decline'),
            ),
            FilledButton(
              onPressed: () => _act(
                () => AppController.instance.backendApi.respondFriendRequest(
                  profileId: profile.id,
                  friendshipId: request['id'].toString(),
                  action: 'accept',
                ),
              ),
              child: const UniversalText('Accept'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _suggestionCard(Map<String, dynamic> person) {
    final profile = AppController.instance.currentProfile;
    if (profile == null) return const SizedBox.shrink();
    final username = person['username']?.toString() ?? '';
    return Card(
      child: ListTile(
        leading: const Icon(Icons.person_search_rounded),
        title: Text(person['display_name']?.toString() ?? username),
        subtitle: Text('@$username'),
        trailing: IconButton(
          onPressed: username.isEmpty
              ? null
              : () => _act(
                    () => AppController.instance.backendApi.sendFriendRequest(
                      profileId: profile.id,
                      username: username,
                    ),
                  ),
          icon: const Icon(Icons.person_add_alt_1_rounded),
        ),
      ),
    );
  }

  Widget _storyComposer() {
    return GestureDetector(
      onTap: _composeStory,
      child: Container(
        width: 78,
        margin: const EdgeInsets.only(right: 10),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 29,
              child: Icon(Icons.add_rounded),
            ),
            const SizedBox(height: 5),
            const UniversalText(
              'Your story',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _storyBubble(Map<String, dynamic> story) {
    final author = story['author'] is Map
        ? Map<String, dynamic>.from(story['author'] as Map)
        : <String, dynamic>{};
    final name = author['display_name']?.toString() ??
        author['username']?.toString() ??
        'Friend';
    return GestureDetector(
      onTap: () => _showStory(story),
      child: Container(
        width: 78,
        margin: const EdgeInsets.only(right: 10),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 27,
                child: Text(_initial(name)),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _composePost(String profileId) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const UniversalText('Create post'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 5,
          maxLength: 4000,
          decoration: const InputDecoration(
            hintText: 'What are you watching, listening to, or collecting?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const UniversalText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const UniversalText('Post'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.trim().isEmpty) return;
    await _act(
      () => AppController.instance.backendApi.createSocialPost(
        profileId: profileId,
        body: value.trim(),
      ),
    );
  }

  Future<void> _composeCommunityPost(String communityId) async {
    final profile = AppController.instance.currentProfile;
    if (profile == null) return;
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const UniversalText('Post to community'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 5,
          maxLength: 4000,
          decoration: const InputDecoration(
            hintText: 'Share with members of this community',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const UniversalText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const UniversalText('Post'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.trim().isEmpty) return;
    await _act(
      () => AppController.instance.backendApi.createSocialPost(
        profileId: profile.id,
        body: value.trim(),
        communityIds: [communityId],
      ),
    );
  }

  Future<void> _composeStory({String? communityId}) async {
    final profile = AppController.instance.currentProfile;
    if (profile == null) return;
    final friends = _list('friends');
    final media = AppController.instance.library
        .where((item) => item.isAccessibleTo(profile))
        .toList();
    final draft = await Navigator.push<StoryDraft>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/app/story/create'),
        builder: (_) => StoryComposerScreen(friends: friends, media: media),
      ),
    );
    if (!mounted || draft == null) return;
    String? attachmentPath;
    if (draft.media != null) {
      try {
        final bytes = await draft.media!.readAsBytes();
        if (bytes.isEmpty || bytes.length > 50 * 1024 * 1024) {
          _showError('Story attachments must be smaller than 50 MB.');
          return;
        }
        final extension = draft.media!.name.split('.').last.toLowerCase();
        final contentType = draft.mediaType == 'photo'
            ? switch (extension) {
                'jpg' || 'jpeg' => 'image/jpeg',
                'png' => 'image/png',
                'webp' => 'image/webp',
                _ => null,
              }
            : switch (extension) {
                'mp4' || 'm4v' => 'video/mp4',
                'mov' => 'video/quicktime',
                'webm' => 'video/webm',
                _ => null,
              };
        if (contentType == null) {
          _showError('Choose a JPEG, PNG, WebP, MP4, MOV, or WebM Story file.');
          return;
        }
        attachmentPath =
            await AppController.instance.backendApi.uploadSocialAttachment(
          profileId: profile.id,
          bytes: bytes,
          contentType: contentType,
        );
      } catch (error) {
        _showError(error.toString());
        return;
      }
    }
    final reference = <String, dynamic>{
      'type': draft.mediaType == 'photo'
          ? 'photo'
          : draft.mediaType == 'video'
              ? 'video'
              : 'story',
      if (attachmentPath != null)
        (draft.mediaType == 'photo' ? 'photoPath' : 'videoPath'):
            attachmentPath,
      if (draft.media != null) 'fileName': draft.media!.name,
      if (draft.storyData.isNotEmpty) 'storyData': draft.storyData,
    };
    await _act(
      () => AppController.instance.backendApi.createSocialStory(
        profileId: profile.id,
        body: draft.body.trim().isEmpty ? 'Story' : draft.body.trim(),
        communityId: communityId,
        expiresInHours: draft.expiresInHours,
        mediaReference: reference['type'] == 'story' && draft.storyData.isEmpty
            ? null
            : reference,
      ),
    );
  }

  List<Map<String, String>> _shortContentLinks(Profile profile) {
    final links = <Map<String, String>>[];
    for (final media in AppController.instance.library.where(
      (item) => item.isAccessibleTo(profile),
    )) {
      final normalizedType = media.type.toLowerCase();
      final type = normalizedType.contains('show') ||
              normalizedType.contains('series') ||
              normalizedType.contains('tv')
          ? 'show'
          : normalizedType.contains('movie') || normalizedType.contains('film')
              ? 'movie'
              : null;
      if (type != null) {
        links.add({
          'id': media.id,
          'title': media.title,
          'type': type,
          'subtitle': type == 'show' ? 'TV show' : 'Movie',
        });
      }
    }
    for (final track in MusicLibraryStore.instance.tracks) {
      links.add({
        'id': track.id,
        'title': track.title,
        'type': 'song',
        'subtitle': 'Song · ${track.artist}',
      });
    }
    return links;
  }

  Future<Map<String, String>?> _chooseShortContentLink(
    List<Map<String, String>> links,
  ) {
    return showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        Map<String, String>? selected;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const UniversalText('Link to library content'),
            content: SizedBox(
              width: 440,
              child: links.isEmpty
                  ? const UniversalText(
                      'Add a movie, show, or song to this profile’s library first.',
                    )
                  : RadioGroup<Map<String, String>>(
                      groupValue: selected,
                      onChanged: (value) =>
                          setDialogState(() => selected = value),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: links.length,
                        itemBuilder: (context, index) {
                          final link = links[index];
                          return RadioListTile<Map<String, String>>(
                            value: link,
                            title: Text(link['title']!),
                            subtitle: Text(link['subtitle']!),
                          );
                        },
                      ),
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const UniversalText('Cancel'),
              ),
              FilledButton(
                onPressed: selected == null
                    ? null
                    : () => Navigator.pop(dialogContext, selected),
                child: const UniversalText('Continue'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<int?> _chooseStoryLifetime() => showDialog<int>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: const UniversalText('Choose story lifetime'),
          children: [
            for (final option in const {
              24: '24 hours',
              48: '2 days',
              72: '3 days',
              168: '1 week',
            }.entries)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, option.key),
                child: Text(option.value),
              ),
          ],
        ),
      );

  Future<String?> _chooseShortContentMode() => showDialog<String>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: const UniversalText('Choose Short format'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, 'short'),
              child: const ListTile(
                leading: Icon(Icons.flash_on_rounded),
                title: UniversalText('Short'),
                subtitle: UniversalText(
                    'Quick vertical clip tied to a movie, show, or song.'),
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, 'review'),
              child: const ListTile(
                leading: Icon(Icons.star_rate_rounded),
                title: UniversalText('Video review'),
                subtitle: UniversalText(
                    'Review a movie, show, or song in vertical format.'),
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, 'skit'),
              child: const ListTile(
                leading: Icon(Icons.theater_comedy_rounded),
                title: UniversalText('Skit'),
                subtitle: UniversalText(
                    'A scene, parody, or character skit inspired by media.'),
              ),
            ),
          ],
        ),
      );

  Future<void> _createShort({
    bool asStory = false,
    String? communityId,
  }) async {
    final profile = AppController.instance.currentProfile;
    if (profile == null) return;
    final links = _shortContentLinks(profile);
    final related = await _chooseShortContentLink(links);
    if (related == null || !mounted) return;
    final contentMode = await _chooseShortContentMode();
    if (contentMode == null || !mounted) return;
    final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    final result = await Navigator.of(context).push<SocialVideoEditResult>(
      MaterialPageRoute(
        builder: (_) => SocialVideoEditorScreen(source: File(picked.path)),
      ),
    );
    if (result == null || !mounted) return;
    final videoBytes = await result.video.readAsBytes();
    if (videoBytes.length > 50 * 1024 * 1024 ||
        result.coverBytes.length > 50 * 1024 * 1024) {
      await result.video.delete();
      _showMessage('Each video and cover must be 50 MB or smaller.');
      return;
    }
    final expiresInHours = asStory ? await _chooseStoryLifetime() : null;
    if (asStory && expiresInHours == null) {
      await result.video.delete();
      return;
    }
    final api = AppController.instance.backendApi;
    final body = [
      if (result.caption.trim().isNotEmpty) result.caption.trim(),
      'Related to ${related['subtitle']}: ${related['title']}',
    ].join('\n');
    await _act(() async {
      final videoPath = await api.uploadSocialAttachment(
        profileId: profile.id,
        bytes: videoBytes,
        contentType: 'video/mp4',
      );
      final coverPath = await api.uploadSocialAttachment(
        profileId: profile.id,
        bytes: result.coverBytes,
        contentType: 'image/jpeg',
      );
      final mediaReference = <String, dynamic>{
        'type': 'video',
        'videoPath': videoPath,
        'coverPath': coverPath,
        'relatedMediaId': related['id'],
        'relatedMediaType': related['type'],
        'relatedMediaTitle': related['title'],
        'contentMode': contentMode,
      };
      if (asStory) {
        await api.createSocialStory(
          profileId: profile.id,
          body: body,
          communityId: communityId,
          expiresInHours: expiresInHours!,
          mediaReference: mediaReference,
        );
      } else {
        await api.createSocialPost(
          profileId: profile.id,
          body: body,
          mediaReference: mediaReference,
        );
      }
    });
    if (await result.video.exists()) await result.video.delete();
  }

  Future<void> _playSocialVideo(String url) async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          contentPadding: EdgeInsets.zero,
          content: AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
          actions: [
            IconButton(
              onPressed: () => controller.value.isPlaying
                  ? controller.pause()
                  : controller.play(),
              icon: Icon(
                controller.value.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const UniversalText('Close'),
            ),
          ],
        ),
      );
    } catch (error) {
      _showMessage('Unable to play this video: $error');
    } finally {
      await controller.dispose();
    }
  }

  Future<void> _addFriend() async {
    final profile = AppController.instance.currentProfile;
    if (profile == null) return;
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const UniversalText('Add a friend'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '@username'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const UniversalText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const UniversalText('Send request'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.trim().isEmpty) return;
    await _act(
      () => AppController.instance.backendApi.sendFriendRequest(
        profileId: profile.id,
        username: value.trim().replaceFirst('@', ''),
      ),
    );
  }

  Future<void> _createCommunity() async {
    final profile = AppController.instance.currentProfile;
    if (profile == null) return;
    final name = await _prompt('Create community', 'Community name');
    if (name == null || name.trim().isEmpty) return;
    final description =
        await _prompt('Community description', 'Description') ?? '';
    if (!mounted) return;
    var category = 'general';
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const UniversalText('Community category'),
          content: DropdownButtonFormField<String>(
            initialValue: category,
            decoration: const InputDecoration(labelText: 'Organize by'),
            items: const [
              DropdownMenuItem(value: 'movies', child: UniversalText('Movies')),
              DropdownMenuItem(value: 'shows', child: UniversalText('Shows')),
              DropdownMenuItem(value: 'music', child: UniversalText('Music')),
              DropdownMenuItem(
                  value: 'general', child: UniversalText('General')),
            ],
            onChanged: (value) {
              if (value != null) setDialogState(() => category = value);
            },
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const UniversalText('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, category),
                child: const UniversalText('Create')),
          ],
        ),
      ),
    );
    if (selected == null) return;
    await _act(() => AppController.instance.backendApi.createSocialCommunity(
          profileId: profile.id,
          name: name.trim(),
          description: description.trim(),
          category: selected,
        ));
  }

  Future<void> _newAccountDirectMessage() async {
    final controller = AppController.instance;
    final current = controller.currentProfile;
    if (current == null) return;
    final profiles = (controller.currentAccount?.profiles ?? <Profile>[])
        .where((profile) => profile.id != current.id)
        .toList();
    if (profiles.isEmpty) {
      _showMessage(
          'Create another profile on this account before starting an account chat.');
      return;
    }
    final selectedId = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        String? selected = profiles.first.id;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const UniversalText('Message an account profile'),
            content: SizedBox(
              width: 420,
              child: RadioGroup<String>(
                groupValue: selected,
                onChanged: (value) => setDialogState(() => selected = value),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: profiles
                      .map((profile) => RadioListTile<String>(
                            value: profile.id,
                            title: Text(profile.name),
                          ))
                      .toList(),
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const UniversalText('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, selected),
                  child: const UniversalText('Open chat')),
            ],
          ),
        );
      },
    );
    if (selectedId == null) return;
    try {
      final response =
          await controller.backendApi.createSocialAccountConversation(
        profileId: current.id,
        targetProfileId: selectedId,
      );
      final conversation = response['conversation'] is Map
          ? Map<String, dynamic>.from(response['conversation'] as Map)
          : <String, dynamic>{};
      final id = conversation['id']?.toString();
      if (id == null || id.isEmpty || !mounted) return;
      await _load();
      final messagesIndex = _tabSections.indexOf('messages');
      if (messagesIndex >= 0) _tabs.animateTo(messagesIndex);
      await _openConversation(id);
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _newAccountGroupMessage() async {
    final controller = AppController.instance;
    final current = controller.currentProfile;
    if (current == null) return;
    if (!controller.backendApi.isAuthenticated) {
      _showMessage('Sign in to create an account group chat.');
      return;
    }
    final profiles = (controller.currentAccount?.profiles ?? <Profile>[])
        .where((profile) => profile.id != current.id)
        .toList();
    if (profiles.isEmpty) {
      _showMessage(
          'Create another profile on this account before creating a group chat.');
      return;
    }

    final titleController = TextEditingController(text: 'Account group');
    final selectedIds = <String>{};
    final result = await showDialog<(String, List<String>)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const UniversalText('Create account group chat'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    maxLength: 100,
                    decoration: const InputDecoration(labelText: 'Group name'),
                  ),
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: UniversalText('Choose profiles from this account'),
                  ),
                  ...profiles.map((profile) => CheckboxListTile(
                        value: selectedIds.contains(profile.id),
                        onChanged: (checked) => setDialogState(() {
                          if (checked == true) {
                            selectedIds.add(profile.id);
                          } else {
                            selectedIds.remove(profile.id);
                          }
                        }),
                        title: Text(profile.name),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      )),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const UniversalText('Cancel')),
            FilledButton(
              onPressed: selectedIds.isEmpty
                  ? null
                  : () => Navigator.pop(
                        dialogContext,
                        (titleController.text, selectedIds.toList()),
                      ),
              child: const UniversalText('Create group'),
            ),
          ],
        ),
      ),
    );
    titleController.dispose();
    if (result == null || result.$2.isEmpty) return;
    try {
      final response =
          await controller.backendApi.createSocialAccountGroupConversation(
        profileId: current.id,
        title: result.$1,
        profileIds: result.$2,
      );
      final conversation = response['conversation'] is Map
          ? Map<String, dynamic>.from(response['conversation'] as Map)
          : <String, dynamic>{};
      final id = conversation['id']?.toString();
      if (id == null || id.isEmpty || !mounted) return;
      await _load();
      final messagesIndex = _tabSections.indexOf('messages');
      if (messagesIndex >= 0) _tabs.animateTo(messagesIndex);
      await _openConversation(id);
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _newMessage() async {
    final username = await _prompt('New message', '@username of a friend');
    if (username == null || username.trim().isEmpty) return;
    await _startMessageFor(username.trim().replaceFirst('@', ''));
  }

  Future<void> _newGroupMessage() async {
    final titleController = TextEditingController();
    final friendsController = TextEditingController();
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const UniversalText('Create group chat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Group name'),
            ),
            TextField(
              controller: friendsController,
              decoration: const InputDecoration(
                labelText: 'Friend usernames',
                hintText: 'alex, sam',
                helperText: 'Add at least two accepted friends.',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const UniversalText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              (titleController.text, friendsController.text),
            ),
            child: const UniversalText('Create'),
          ),
        ],
      ),
    );
    titleController.dispose();
    friendsController.dispose();
    if (result == null) return;
    final profile = AppController.instance.currentProfile;
    if (profile == null) return;
    final usernames = result.$2
        .split(RegExp(r'[,;\s]+'))
        .map((name) => name.trim().replaceFirst('@', ''))
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
    try {
      final response =
          await AppController.instance.backendApi.createSocialGroupConversation(
        profileId: profile.id,
        title: result.$1.trim(),
        usernames: usernames,
      );
      final conversation = response['conversation'] is Map
          ? Map<String, dynamic>.from(response['conversation'] as Map)
          : <String, dynamic>{};
      final id = conversation['id']?.toString();
      if (id == null || id.isEmpty || !mounted) return;
      await _load();
      final messagesIndex = _tabSections.indexOf('messages');
      if (messagesIndex >= 0) _tabs.animateTo(messagesIndex);
      await _showGroupChatInviteOptions(
        conversationId: id,
        conversationTitle:
            result.$1.trim().isEmpty ? 'Group chat' : result.$1.trim(),
      );
      await _openConversation(id);
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  String _chatInviteUrl(String token) {
    final base = Uri.base;
    if (base.scheme == 'http' || base.scheme == 'https') {
      final query = Map<String, String>.from(base.queryParameters)
        ..['chatInvite'] = token;
      return base.replace(queryParameters: query).toString();
    }
    // Native builds may use this URI when a matching app-link handler is
    // registered; the in-app community card also has a direct Join action.
    return 'myownstreamingservice://join-chat/$token';
  }

  Future<void> _showGroupChatInviteOptions({
    required String conversationId,
    required String conversationTitle,
  }) async {
    final profile = AppController.instance.currentProfile;
    if (profile == null) return;

    String token;
    try {
      final response = await AppController.instance.backendApi
          .createSocialConversationInvite(
        profileId: profile.id,
        conversationId: conversationId,
      );
      final invite = response['invite'] is Map
          ? Map<String, dynamic>.from(response['invite'] as Map)
          : <String, dynamic>{};
      token = invite['token']?.toString() ?? '';
      if (token.isEmpty) {
        throw StateError('The server did not return an invite token.');
      }
    } catch (error) {
      if (mounted) {
        _showMessage(
          'Chat created, but invite links are unavailable. Apply the social conversation invite migration and update the backend. ${error.toString().replaceFirst('Exception: ', '')}',
        );
      }
      return;
    }

    final inviteUrl = _chatInviteUrl(token);
    final communities = _list('communities')
        .where((community) => community['joined'] == true)
        .toList(growable: false);
    String? selectedCommunityId =
        communities.isEmpty ? null : communities.first['id']?.toString();
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const UniversalText('Invite people to this chat'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'Share a link for “$conversationTitle”. It expires in 30 days and allows up to 100 joins.'),
                  const SizedBox(height: 12),
                  SelectableText(inviteUrl,
                      style: const TextStyle(color: Colors.lightBlueAccent)),
                  const SizedBox(height: 18),
                  if (communities.isNotEmpty) ...[
                    const UniversalText('Post this invite in a community',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCommunityId,
                      decoration:
                          const InputDecoration(labelText: 'Joined community'),
                      items: communities
                          .map((community) => DropdownMenuItem<String>(
                                value: community['id']?.toString(),
                                child: Text(
                                    community['name']?.toString() ??
                                        'Community',
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => selectedCommunityId = value),
                    ),
                  ] else
                    const UniversalText(
                        'Join a community first to post the invite there.',
                        style: TextStyle(color: Colors.white60)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const UniversalText('Done'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: inviteUrl));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) _showMessage('Group chat invite link copied.');
              },
              icon: const Icon(Icons.copy_rounded),
              label: const UniversalText('Copy link'),
            ),
            FilledButton.icon(
              onPressed: selectedCommunityId == null
                  ? null
                  : () async {
                      final communityId = selectedCommunityId!;
                      Navigator.pop(dialogContext);
                      try {
                        await AppController.instance.backendApi
                            .createSocialPost(
                          profileId: profile.id,
                          body:
                              'Join our group chat “$conversationTitle” using the Join chat card below.',
                          communityIds: [communityId],
                          mediaReference: {
                            'type': 'chat_invite',
                            'inviteToken': token,
                            'inviteUrl': inviteUrl,
                            'conversationTitle': conversationTitle,
                          },
                        );
                        await _load();
                        if (mounted) {
                          _showMessage('Invite posted to the community.');
                        }
                      } catch (error) {
                        if (mounted) {
                          _showMessage(
                              error.toString().replaceFirst('Exception: ', ''));
                        }
                      }
                    },
              icon: const Icon(Icons.groups_rounded),
              label: const UniversalText('Share to community'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _acceptChatInvite(Map<String, dynamic> mediaReference) async {
    final profile = AppController.instance.currentProfile;
    final token = mediaReference['inviteToken']?.toString() ?? '';
    if (profile == null || token.isEmpty) {
      _showMessage('This chat invite is incomplete.');
      return;
    }
    try {
      final response = await AppController.instance.backendApi
          .acceptSocialConversationInvite(
        profileId: profile.id,
        token: token,
      );
      final conversation = response['conversation'] is Map
          ? Map<String, dynamic>.from(response['conversation'] as Map)
          : <String, dynamic>{};
      final conversationId = response['conversationId']?.toString() ??
          conversation['id']?.toString() ??
          '';
      if (conversationId.isEmpty) {
        throw StateError('The invite did not identify a conversation.');
      }
      await _load();
      if (!mounted) return;
      final messagesIndex = _tabSections.indexOf('messages');
      if (messagesIndex >= 0) _tabs.animateTo(messagesIndex);
      await _openConversation(conversationId);
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _startMessageFor(String username) async {
    final profile = AppController.instance.currentProfile;
    if (profile == null || username.trim().isEmpty) return;
    try {
      final result =
          await AppController.instance.backendApi.createSocialConversation(
        profileId: profile.id,
        username: username,
      );
      final conversation =
          result['conversation'] is Map ? result['conversation'] as Map : null;
      final id = conversation?['id']?.toString();
      if (id == null || id.isEmpty) return;
      if (!mounted) return;
      final messagesIndex = _tabSections.indexOf('messages');
      if (messagesIndex >= 0) _tabs.animateTo(messagesIndex);
      await _openConversation(id);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }

  Future<void> _openConversation(String conversationId) async {
    if (conversationId.isEmpty) return;
    final profile = AppController.instance.currentProfile;
    if (profile == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SocialConversationScreen(
          conversationId: conversationId,
          profileId: profile.id,
        ),
      ),
    );
    await _load();
  }

  Future<void> _reactToPost(String postId, String reaction) async {
    if (postId.isEmpty) return;
    if (reaction == 'remove') {
      final profile = AppController.instance.currentProfile;
      if (profile == null) return;
      await _act(
        () => AppController.instance.backendApi.reactToSocialPost(
          profileId: profile.id,
          postId: postId,
          reaction: 'remove',
        ),
      );
      return;
    }
    final profile = AppController.instance.currentProfile;
    if (profile == null) return;
    await _act(
      () => AppController.instance.backendApi.reactToSocialPost(
        profileId: profile.id,
        postId: postId,
        reaction: reaction,
      ),
    );
  }

  Future<void> _commentPost(String postId) async {
    if (postId.isEmpty) return;
    final value = await _prompt('Comment', 'Write a comment');
    if (value == null || value.trim().isEmpty) return;
    final profile = AppController.instance.currentProfile;
    if (profile == null) return;
    await _act(
      () => AppController.instance.backendApi.commentOnSocialPost(
        profileId: profile.id,
        postId: postId,
        body: value.trim(),
      ),
    );
  }

  Future<void> _sharePost(Map<String, dynamic> post) async {
    final reference = post['mediaReference'] is Map
        ? Map<String, dynamic>.from(post['mediaReference'] as Map)
        : post['media_reference'] is Map
            ? Map<String, dynamic>.from(post['media_reference'] as Map)
            : <String, dynamic>{};
    final type = reference['type']?.toString();
    final title = reference['relatedMediaTitle']?.toString() ??
        reference['mediaTitle']?.toString() ??
        'post';
    final messageReference = <String, dynamic>{
      if (type == 'video') ...{
        'type': 'video',
        if (reference['videoPath'] != null)
          'attachmentPath': reference['videoPath'],
        'title': title,
        if (reference['relatedMediaId'] != null)
          'mediaId': reference['relatedMediaId'],
        if (reference['relatedMediaType'] != null)
          'mediaType': reference['relatedMediaType'],
      } else if (type == 'photo') ...{
        'type': 'photo',
        if (reference['photoPath'] != null)
          'attachmentPath': reference['photoPath'],
      } else ...{
        'type': 'recommendation',
        'title': title,
        if (reference['mediaId'] != null) 'mediaId': reference['mediaId'],
        if (reference['mediaType'] != null) 'mediaType': reference['mediaType'],
      },
    };
    await showSocialShareDialog(
      context,
      title: 'post',
      message: post['body']?.toString() ?? '',
      mediaReference: messageReference,
      sourcePostId: type == 'video' ? post['id']?.toString() : null,
    );
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message.replaceFirst('Exception: ', ''))));
    }
  }

  void _showStory(Map<String, dynamic> story) {
    final author = story['author'] is Map
        ? Map<String, dynamic>.from(story['author'] as Map)
        : <String, dynamic>{};
    final authorId =
        (author['profileId'] ?? author['profile_id'] ?? author['id'])
                ?.toString() ??
            '';
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/app/story/view'),
        builder: (_) => authorId.isNotEmpty
            ? FriendStoryProfileViewer(friend: author)
            : StoryViewerScreen(story: story),
      ),
    );
  }

  Future<String?> _prompt(String title, String hint) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: title == 'Comment' || title == 'Create post' ? 4 : 1,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const UniversalText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const UniversalText('Continue'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  String _initial(String value) {
    final clean = value.trim();
    return clean.isEmpty ? '?' : clean.substring(0, 1).toUpperCase();
  }
}

class SocialConversationScreen extends StatefulWidget {
  final String conversationId;
  final String profileId;

  const SocialConversationScreen({
    super.key,
    required this.conversationId,
    required this.profileId,
  });

  @override
  State<SocialConversationScreen> createState() =>
      _SocialConversationScreenState();
}

class _SocialConversationScreenState extends State<SocialConversationScreen> {
  Map<String, dynamic>? data;
  bool loading = true;
  bool sending = false;
  bool recording = false;
  bool viewOnceNext = false;
  Map<String, dynamic>? replyingTo;
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final AudioRecorder recorder = AudioRecorder();
  final ImagePicker picker = ImagePicker();
  Timer? _typingDebounce;
  Timer? _typingHeartbeat;
  Timer? _activityRefresh;
  bool _refreshingActivity = false;
  bool _activityErrorShown = false;
  bool _typingErrorShown = false;
  Map<String, dynamic> _textFormat = <String, dynamic>{};
  final Set<String> _revealedSpoilers = <String>{};

  static const _emojis = [
    '😀',
    '😂',
    '🥹',
    '😍',
    '😎',
    '🤔',
    '😭',
    '😡',
    '👏',
    '🙌',
    '👍',
    '👎',
    '❤️',
    '🔥',
    '🎉',
    '🍿',
    '👀',
    '💀',
    '⭐',
    '🤟',
  ];

  Future<String?> _prompt(String title, String hint) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: title == 'Comment' || title == 'Create post' ? 4 : 1,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const UniversalText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const UniversalText('Continue'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _setMyNickname() async {
    final nickname = await _prompt(
      'Set nickname',
      'Nickname shown below your name',
    );
    if (nickname == null) return;
    final clean = nickname.trim();
    if (clean.length > 48) {
      _showError('Nicknames must be 48 characters or fewer.');
      return;
    }
    try {
      await AppController.instance.backendApi.setSocialProfilePresence(
        profileId: widget.profileId,
        nickname: clean,
        clearNickname: clean.isEmpty,
      );
      await _load(scrollToBottom: false);
    } catch (error) {
      _showError(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _setAvailability(String availability) async {
    try {
      await AppController.instance.backendApi.setSocialProfilePresence(
        profileId: widget.profileId,
        availability: availability,
      );
      await _load(scrollToBottom: false);
    } catch (error) {
      _showError(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  void initState() {
    super.initState();
    messageController.addListener(_onMessageChanged);
    _load();
    _activityRefresh = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _load(incremental: true, scrollToBottom: false),
    );
  }

  void _onMessageChanged() {
    if (!mounted) return;
    setState(() {});
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_setTypingStatus(messageController.text.trim().isNotEmpty));
    });
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    _typingHeartbeat?.cancel();
    _activityRefresh?.cancel();
    messageController.removeListener(_onMessageChanged);
    messageController.dispose();
    scrollController.dispose();
    unawaited(recorder.dispose());
    super.dispose();
  }

  Future<void> _load({
    bool incremental = false,
    bool scrollToBottom = true,
  }) async {
    if (incremental && (_refreshingActivity || data == null)) return;
    if (incremental) _refreshingActivity = true;
    try {
      final currentMessages = (data?['messages'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      final after = incremental && currentMessages.isNotEmpty
          ? currentMessages.last['created_at']?.toString()
          : null;
      final result =
          await AppController.instance.backendApi.getSocialConversation(
        profileId: widget.profileId,
        conversationId: widget.conversationId,
        after: after,
      );
      if (!mounted) return;
      _activityErrorShown = false;
      if (incremental) {
        final knownIds =
            currentMessages.map((message) => message['id']?.toString()).toSet();
        final newMessages = (result['messages'] as List? ?? const [])
            .whereType<Map>()
            .map((message) => Map<String, dynamic>.from(message))
            .where((message) => !knownIds.contains(message['id']?.toString()));
        result['messages'] = [...currentMessages, ...newMessages];
      }
      setState(() {
        data = result;
        loading = false;
      });
      if (scrollToBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (scrollController.hasClients) {
            scrollController.jumpTo(scrollController.position.maxScrollExtent);
          }
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => loading = false);
      if (incremental && _activityErrorShown) return;
      if (incremental) _activityErrorShown = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (incremental) _refreshingActivity = false;
    }
  }

  Future<void> _setTypingStatus(bool isTyping) async {
    if (isTyping) {
      _typingHeartbeat ??= Timer.periodic(
        const Duration(seconds: 4),
        (_) => unawaited(_setTypingStatus(true)),
      );
    } else {
      _typingHeartbeat?.cancel();
      _typingHeartbeat = null;
    }
    try {
      await AppController.instance.backendApi.setSocialConversationTyping(
        profileId: widget.profileId,
        conversationId: widget.conversationId,
        isTyping: isTyping,
      );
      _typingErrorShown = false;
    } catch (error) {
      if (isTyping) {
        _typingHeartbeat?.cancel();
        _typingHeartbeat = null;
      }
      if (!mounted || _typingErrorShown) return;
      _typingErrorShown = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    }
  }

  Future<void> _send() async {
    final text = messageController.text.trim();
    if (text.isEmpty || sending) return;
    await _sendMessage(
      body: text,
      messageType: 'text',
      replyToMessageId: replyingTo?['id']?.toString(),
      textFormat: _textFormat,
    );
  }

  Future<void> _sendMessage({
    required String body,
    required String messageType,
    Map<String, dynamic>? mediaReference,
    Map<String, dynamic>? textFormat,
    bool viewOnce = false,
    String? replyToMessageId,
  }) async {
    if (sending) return;
    if (!_canSend) {
      _showError('Only group admins can send messages in this chat.');
      return;
    }
    _typingDebounce?.cancel();
    unawaited(_setTypingStatus(false));
    setState(() => sending = true);
    try {
      await AppController.instance.backendApi.sendSocialMessage(
        profileId: widget.profileId,
        conversationId: widget.conversationId,
        body: body.isEmpty ? 'Attachment' : body,
        messageType: messageType,
        mediaReference: mediaReference,
        textFormat: textFormat,
        viewOnce: viewOnce,
        replyToMessageId: replyToMessageId ?? replyingTo?['id']?.toString(),
      );
      messageController.clear();
      setState(() {
        replyingTo = null;
        viewOnceNext = false;
        _textFormat = <String, dynamic>{};
      });
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _react(String messageId) async {
    final reaction = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            for (final emoji in _emojis.take(16))
              SizedBox(
                width: 56,
                child: IconButton(
                  onPressed: () => Navigator.pop(context, emoji),
                  icon: Text(emoji, style: const TextStyle(fontSize: 25)),
                ),
              ),
          ],
        ),
      ),
    );
    if (reaction == null) return;
    await AppController.instance.backendApi.reactToSocialMessage(
      profileId: widget.profileId,
      messageId: messageId,
      reaction: reaction,
    );
    await _load();
  }

  Future<void> _chooseAttachment() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            _actionTile(context, 'photo-video', Icons.photo_camera_outlined,
                'Photo or video'),
            _actionTile(
                context, 'voice', Icons.mic_none_rounded, 'Voice message'),
            _actionTile(context, 'recommendation', Icons.movie_filter_outlined,
                'Recommend media or song'),
            _actionTile(context, 'product', Icons.shopping_bag_outlined,
                'Share a Shop product'),
            _actionTile(
                context, 'link', Icons.link_rounded, 'Share a store link'),
            _actionTile(
                context, 'gif', Icons.gif_box_outlined, 'Share a GIF link'),
            _actionTile(context, 'sticker', Icons.emoji_emotions_outlined,
                'Send a sticker'),
            _actionTile(context, 'friend', Icons.person_add_alt_1_rounded,
                'Suggest a friend'),
            if (_isGroup)
              _actionTile(
                  context, 'poll', Icons.poll_outlined, 'Create a poll'),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'photo-video':
        await _pickPhotoOrVideo();
      case 'voice':
        await _toggleVoiceRecording();
      case 'recommendation':
        await _recommendMedia();
      case 'product':
        await _shareProduct();
      case 'link':
        await _shareLink();
      case 'gif':
        await _shareGif();
      case 'sticker':
        await _chooseSticker();
      case 'friend':
        await _suggestFriend();
      case 'poll':
        await _createPoll();
    }
  }

  Widget _actionTile(
    BuildContext context,
    String value,
    IconData icon,
    String label,
  ) =>
      ListTile(
        leading: Icon(icon),
        title: Text(label),
        onTap: () => Navigator.pop(context, value),
      );

  Future<void> _pickPhotoOrVideo() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const UniversalText('Choose from library'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const UniversalText('Record with camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (!mounted || source == null) return;
    final kind = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const UniversalText('Photo'),
              onTap: () => Navigator.pop(context, 'photo'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const UniversalText('Video (up to 2 minutes)'),
              onTap: () => Navigator.pop(context, 'video'),
            ),
          ],
        ),
      ),
    );
    if (kind == null) return;
    final file = kind == 'photo'
        ? await picker.pickImage(
            source: source,
            maxWidth: 1920,
            imageQuality: 85,
          )
        : await picker.pickVideo(
            source: source,
            maxDuration: const Duration(minutes: 2),
          );
    if (file == null) return;
    final extension = file.name.split('.').last.toLowerCase();
    final mime = switch ((kind, extension)) {
      ('photo', 'jpg' || 'jpeg') => 'image/jpeg',
      ('photo', 'png') => 'image/png',
      ('photo', 'webp') => 'image/webp',
      ('video', 'mp4' || 'm4v') => 'video/mp4',
      ('video', 'mov') => 'video/quicktime',
      ('video', 'webm') => 'video/webm',
      _ => null,
    };
    if (mime == null) {
      _showError('Choose a JPEG, PNG, WebP, MP4, or WebM file.');
      return;
    }
    await _uploadAndSend(
      file: file,
      contentType: mime,
      mediaType: kind,
      messageType: kind,
    );
  }

  Future<void> _uploadAndSend({
    required XFile file,
    required String contentType,
    required String mediaType,
    required String messageType,
  }) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.length > 50 * 1024 * 1024) {
      _showError('Attachments must be smaller than 50 MB.');
      return;
    }
    final path = await AppController.instance.backendApi.uploadSocialAttachment(
      profileId: widget.profileId,
      bytes: bytes,
      contentType: contentType,
    );
    await _sendMessage(
      body: '',
      messageType: messageType,
      viewOnce: viewOnceNext,
      mediaReference: {
        'type': mediaType,
        'attachmentPath': path,
        'fileName': file.name,
        'mimeType': contentType,
        if (viewOnceNext) 'viewOnce': true,
      },
    );
  }

  Future<void> _toggleVoiceRecording() async {
    if (recording) {
      try {
        final path = await recorder.stop();
        if (!mounted) return;
        setState(() => recording = false);
        if (path == null) {
          throw StateError('The voice recording was not saved.');
        }
        final file = XFile(path, name: 'voice-message.m4a');
        await _uploadAndSend(
          file: file,
          contentType: 'audio/mp4',
          mediaType: 'voice',
          messageType: 'voice',
        );
      } catch (error) {
        if (mounted) _showError(error.toString());
      }
      return;
    }
    try {
      if (!await recorder.hasPermission()) {
        _showError(
            'Microphone permission is required to record a voice message.');
        return;
      }
      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}${Platform.pathSeparator}chat-${DateTime.now().microsecondsSinceEpoch}.m4a';
      await recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      if (mounted) setState(() => recording = true);
    } catch (error) {
      if (mounted) _showError('Unable to start voice recording: $error');
    }
  }

  Future<void> _recommendMedia() async {
    final option = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.movie_outlined),
            title: const UniversalText('Recommend a movie or show'),
            onTap: () => Navigator.pop(context, 'media'),
          ),
          ListTile(
            leading: const Icon(Icons.music_note_outlined),
            title: const UniversalText('Recommend a song'),
            onTap: () => Navigator.pop(context, 'song'),
          ),
        ]),
      ),
    );
    if (!mounted || option == null) return;
    if (option == 'media') {
      final library = AppController.instance.library;
      if (library.isEmpty) {
        _showError('Your library has no movies or shows to recommend.');
        return;
      }
      final selected = await showDialog<MediaItem>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const UniversalText('Choose a recommendation'),
          children: [
            for (final media in library)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, media),
                child: LocalizedMediaText(media.title),
              ),
          ],
        ),
      );
      if (!mounted || selected == null) return;
      await _sendMessage(
        body: 'Recommended ${selected.title}',
        messageType: 'recommendation',
        mediaReference: {
          'type': 'recommendation',
          'mediaId': selected.id,
          'mediaType': selected.type,
          'title': selected.title,
        },
      );
      return;
    }
    final tracks = MusicLibraryStore.instance.tracks;
    if (tracks.isEmpty) {
      _showError('Your music library has no songs to recommend.');
      return;
    }
    final track = await showDialog<MusicTrack>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const UniversalText('Choose a song'),
        children: [
          for (final item in tracks)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, item),
              child: Text('${item.title} — ${item.artist}'),
            ),
        ],
      ),
    );
    if (!mounted || track == null) return;
    await _sendMessage(
      body: 'Recommended ${track.title} by ${track.artist}',
      messageType: 'recommendation',
      mediaReference: {
        'type': 'recommendation',
        'mediaType': 'song',
        'mediaId': track.id,
        'title': track.title,
        'description': track.artist,
      },
    );
  }

  Future<void> _shareProduct() async {
    final products = ShopCatalog.instance.products
        .where((product) => product.active)
        .toList();
    if (products.isEmpty) {
      _showError('There are no active Shop products to share.');
      return;
    }
    final product = await showDialog<ShopProduct>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const UniversalText('Share a Shop product'),
        children: [
          for (final item in products)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, item),
              child: Text(
                  '${item.name} · ${item.currency} ${item.price.toStringAsFixed(2)}'),
            ),
        ],
      ),
    );
    if (product == null) return;
    await _sendMessage(
      body: 'Shared Shop product: ${product.name}',
      messageType: 'product',
      mediaReference: {
        'type': 'product',
        'productId': product.id,
        'title': product.name,
        'description': product.description,
      },
    );
  }

  Future<String?> _askText(String title, String hint) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const UniversalText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const UniversalText('Send'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<void> _shareLink() async {
    final value = await _askText('Share a store link', 'https://store.example');
    if (value == null || !_validHttpUrl(value)) {
      if (value != null) _showError('Enter a complete http or https link.');
      return;
    }
    await _sendMessage(
      body: value,
      messageType: 'link',
      mediaReference: {'type': 'link', 'url': value, 'title': 'Store link'},
    );
  }

  Future<void> _shareGif() async {
    final value = await _askText('Share a GIF URL', 'https://…/funny.gif');
    if (value == null || !_validHttpUrl(value)) {
      if (value != null) _showError('Enter a complete http or https GIF URL.');
      return;
    }
    await _sendMessage(
      body: 'GIF',
      messageType: 'gif',
      mediaReference: {'type': 'gif', 'url': value},
    );
  }

  bool _validHttpUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
  }

  Future<void> _chooseSticker() async {
    final sticker = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            for (final emoji in const [
              '🍿',
              '🦖',
              '🦸',
              '🚀',
              '👻',
              '🎃',
              '🐉',
              '🪄',
              '🏴‍☠️',
              '💥',
              '🌟',
              '🦄',
              '🎬',
              '🎵',
              '🐈',
              '🤖',
            ])
              SizedBox(
                width: 60,
                child: IconButton(
                  onPressed: () => Navigator.pop(context, emoji),
                  icon: Text(emoji, style: const TextStyle(fontSize: 28)),
                ),
              ),
          ],
        ),
      ),
    );
    if (sticker == null) return;
    await _sendMessage(
      body: sticker,
      messageType: 'sticker',
      mediaReference: {'type': 'sticker', 'emoji': sticker},
    );
  }

  Future<void> _suggestFriend() async {
    final username = AppController.instance.currentProfile?.username;
    if (username == null || username.trim().isEmpty) {
      _showError('Choose a profile with a username before inviting friends.');
      return;
    }
    await _sendMessage(
      body: 'I’d like you to connect with me.',
      messageType: 'friend_invite',
      mediaReference: {'type': 'friend_invite', 'username': username},
    );
  }

  Future<void> _createPoll() async {
    final questionController = TextEditingController();
    final optionsController = TextEditingController();
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const UniversalText('Create a group poll'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: questionController,
              decoration: const InputDecoration(labelText: 'Question'),
            ),
            TextField(
              controller: optionsController,
              decoration: const InputDecoration(
                labelText: 'Options',
                hintText: 'One option per line',
              ),
              minLines: 2,
              maxLines: 6,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const UniversalText('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(
                    context,
                    (questionController.text, optionsController.text),
                  ),
              child: const UniversalText('Create poll')),
        ],
      ),
    );
    questionController.dispose();
    optionsController.dispose();
    if (result == null) return;
    final options = result.$2
        .split(RegExp(r'[\n,;]'))
        .map((option) => option.trim())
        .where((option) => option.isNotEmpty)
        .toList();
    try {
      await AppController.instance.backendApi.createSocialChatPoll(
        profileId: widget.profileId,
        conversationId: widget.conversationId,
        question: result.$1.trim(),
        options: options,
      );
      await _load();
    } catch (error) {
      if (mounted) _showError(error.toString());
    }
  }

  Future<void> _votePoll(Map<String, dynamic> poll, int optionIndex) async {
    try {
      await AppController.instance.backendApi.voteSocialChatPoll(
        profileId: widget.profileId,
        conversationId: widget.conversationId,
        pollId: poll['id'].toString(),
        optionIndex: optionIndex,
      );
      await _load();
    } catch (error) {
      if (mounted) _showError(error.toString());
    }
  }

  Future<void> _openViewOnce(Map<String, dynamic> message) async {
    try {
      final response =
          await AppController.instance.backendApi.viewSocialOnceMessage(
        profileId: widget.profileId,
        messageId: message['id'].toString(),
      );
      if (!mounted) return;
      if (response['expired'] == true) {
        final reference = message['mediaReference'] is Map
            ? Map<String, dynamic>.from(message['mediaReference'] as Map)
            : <String, dynamic>{};
        reference
          ..['expired'] = true
          ..['requiresView'] = false;
        _replaceMessage(message, {'mediaReference': reference});
        return;
      }
      final viewed = response['message'];
      if (viewed is! Map) return;
      final viewedReference = viewed['mediaReference'];
      if (viewedReference is! Map) {
        _showError('The view-once attachment could not be opened.');
        return;
      }
      _replaceMessage(message, {
        'mediaReference': Map<String, dynamic>.from(viewedReference),
        'view_once_opened': true,
      });
    } catch (error) {
      if (mounted) _showError(error.toString());
    }
  }

  void _replaceMessage(
    Map<String, dynamic> original,
    Map<String, dynamic> updates,
  ) {
    setState(() {
      final messages = (data?['messages'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      final index = messages.indexWhere(
        (item) => item['id']?.toString() == original['id']?.toString(),
      );
      if (index >= 0) {
        messages[index] = {...messages[index], ...updates};
      }
      data = {...?data, 'messages': messages};
    });
  }

  Future<void> _setGroupPolicy(String policy) async {
    try {
      final response =
          await AppController.instance.backendApi.setSocialGroupSendPolicy(
        profileId: widget.profileId,
        conversationId: widget.conversationId,
        sendPolicy: policy,
      );
      final conversation = response['conversation'];
      if (conversation is Map) {
        setState(() => data = {
              ...?data,
              'conversation': Map<String, dynamic>.from(conversation),
            });
      }
    } catch (error) {
      if (mounted) _showError(error.toString());
    }
  }

  void _showError(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.replaceFirst('Exception: ', ''))),
    );
  }

  bool get _isGroup =>
      (data?['conversation'] as Map?)?['kind']?.toString() == 'group';

  bool get _isGroupAdmin {
    final members = (data?['members'] as List? ?? const [])
        .whereType<Map>()
        .map((member) => Map<String, dynamic>.from(member));
    return members.any(
      (member) =>
          member['isSelf'] == true &&
          {'owner', 'moderator'}.contains(member['role']),
    );
  }

  bool get _canSend {
    final conversation = data?['conversation'] as Map? ?? const {};
    return !_isGroup ||
        conversation['send_policy'] != 'admins_only' ||
        _isGroupAdmin;
  }

  DateTime? _messageTime(Map<String, dynamic> message, String key) {
    final value = message[key]?.toString();
    return value == null ? null : DateTime.tryParse(value)?.toUtc();
  }

  bool _memberHasReceived(
    Map<String, dynamic> member,
    Map<String, dynamic> message,
    String timestampKey,
  ) {
    final messageTime = _messageTime(message, 'created_at');
    final statusTime = _messageTime(member, timestampKey);
    return messageTime != null &&
        statusTime != null &&
        !statusTime.isBefore(messageTime);
  }

  Future<void> _editTextFormat() async {
    const colors = <String, Color>{
      'White': Colors.white,
      'Black': Colors.black,
      'Red': Colors.red,
      'Blue': Colors.blue,
      'Green': Colors.green,
      'Yellow': Colors.yellow,
      'Purple': Colors.purple,
      'Pink': Colors.pink,
    };
    final next = Map<String, dynamic>.from(_textFormat);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  UniversalText(
                    'Text style',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: next['fontFamily']?.toString() ?? 'Default',
                    decoration: const InputDecoration(labelText: 'Font'),
                    items: const [
                      'Default',
                      'Arial',
                      'Georgia',
                      'Courier New',
                      'Times New Roman',
                      'Verdana',
                    ]
                        .map(
                          (font) => DropdownMenuItem(
                            value: font,
                            child: Text(
                              font,
                              style: TextStyle(
                                fontFamily: font == 'Default' ? null : font,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (font) => setSheetState(() {
                      if (font == null || font == 'Default') {
                        next.remove('fontFamily');
                      } else {
                        next['fontFamily'] = font;
                      }
                    }),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final entry in const {
                        'bold': 'Bold',
                        'italic': 'Italic',
                        'underline': 'Underline',
                        'strikeThrough': 'Strike through',
                        'metallic': 'Metallic',
                        'spoiler': 'Mark as spoiler',
                      }.entries)
                        FilterChip(
                          label: Text(entry.value),
                          selected: next[entry.key] == true,
                          onSelected: (selected) => setSheetState(() {
                            if (selected) {
                              next[entry.key] = true;
                            } else {
                              next.remove(entry.key);
                            }
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const UniversalText('Character color'),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final entry in colors.entries)
                        Tooltip(
                          message: entry.key,
                          child: InkWell(
                            onTap: () => setSheetState(() {
                              next['color'] =
                                  '#${_hexColor(entry.value)}'.toUpperCase();
                            }),
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: CircleAvatar(
                                radius: 14,
                                backgroundColor: entry.value,
                                child: next['color'] ==
                                        '#${_hexColor(entry.value)}'
                                            .toUpperCase()
                                    ? Icon(
                                        Icons.check_rounded,
                                        size: 16,
                                        color:
                                            entry.value.computeLuminance() < .4
                                                ? Colors.white
                                                : Colors.black,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      TextButton(
                        onPressed: () =>
                            setSheetState(() => next.remove('color')),
                        child: const UniversalText('Default'),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const UniversalText('Apply'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (mounted) setState(() => _textFormat = next);
  }

  Future<void> _customizeChatBackground(
    List<Map<String, dynamic>> members,
  ) async {
    final self = members.firstWhere(
      (member) => member['isSelf'] == true,
      orElse: () => <String, dynamic>{},
    );
    final currentColor = self['chatBackgroundColor']
        ?.toString()
        .replaceFirst('#', '')
        .toUpperCase();
    final colors = <String, Color>{
      'Default': Theme.of(context).scaffoldBackgroundColor,
      'Midnight': const Color(0xFF101522),
      'Ocean': const Color(0xFF092B3A),
      'Forest': const Color(0xFF173327),
      'Plum': const Color(0xFF34213B),
      'Charcoal': const Color(0xFF292929),
    };
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UniversalText(
                'Chat background',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                children: [
                  for (final entry in colors.entries)
                    Tooltip(
                      message: entry.key,
                      child: InkWell(
                        onTap: () async {
                          Navigator.pop(sheetContext);
                          final color =
                              '#${_hexColor(entry.value)}'.toUpperCase();
                          await _saveChatAppearance(
                            backgroundColor:
                                entry.key == 'Default' ? null : color,
                            clearBackgroundColor: entry.key == 'Default',
                            clearBackgroundImage: true,
                          );
                        },
                        borderRadius: BorderRadius.circular(28),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: entry.value,
                          child: currentColor == _hexColor(entry.value) ||
                                  (entry.key == 'Default' &&
                                      currentColor == null)
                              ? const Icon(Icons.check_rounded)
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.image_outlined),
                title: const UniversalText('Choose a background image'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _pickChatBackgroundImage();
                },
              ),
              if (self['chatBackgroundImagePath'] != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.hide_image_outlined),
                  title: const UniversalText('Remove background image'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _saveChatAppearance(clearBackgroundImage: true);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickChatBackgroundImage() async {
    try {
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 2000,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        _showError('Chat background images must be 5 MB or smaller.');
        return;
      }
      final extension = image.name.split('.').last.toLowerCase();
      final contentType = switch (extension) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
      final path =
          await AppController.instance.backendApi.uploadSocialAttachment(
        profileId: widget.profileId,
        bytes: bytes,
        contentType: contentType,
      );
      await _saveChatAppearance(backgroundImagePath: path);
    } catch (error) {
      _showError(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _saveChatAppearance({
    String? backgroundColor,
    String? backgroundImagePath,
    bool clearBackgroundColor = false,
    bool clearBackgroundImage = false,
  }) async {
    try {
      await AppController.instance.backendApi.setSocialConversationAppearance(
        profileId: widget.profileId,
        conversationId: widget.conversationId,
        backgroundColor: backgroundColor,
        backgroundImagePath: backgroundImagePath,
        clearBackgroundColor: clearBackgroundColor,
        clearBackgroundImage: clearBackgroundImage,
      );
      await _load(scrollToBottom: false);
    } catch (error) {
      _showError(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  String _hexColor(Color color) =>
      color.toARGB32().toRadixString(16).substring(2).toUpperCase();

  Widget _messageDeliveryIndicator(
    Map<String, dynamic> message,
    List<Map<String, dynamic>> members,
  ) {
    final recipients = members.where((member) => member['isSelf'] != true);
    final recipientList = recipients.toList();
    final allDelivered = recipientList.isNotEmpty &&
        recipientList.every(
          (member) =>
              _memberHasReceived(member, message, 'lastDeliveredAt') ||
              _memberHasReceived(member, message, 'lastReadAt'),
        );
    final allRead = recipientList.isNotEmpty &&
        recipientList.every(
          (member) => _memberHasReceived(member, message, 'lastReadAt'),
        );
    final color =
        allRead ? Colors.lightBlueAccent : Colors.white.withValues(alpha: .72);
    return IconButton(
      tooltip: allRead
          ? 'Read by everyone. Tap for details'
          : allDelivered
              ? 'Delivered to everyone. Tap for details'
              : 'Sent. Tap for details',
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      onPressed: () => _showMessageReceipts(message, recipientList),
      icon: allDelivered
          ? Icon(Icons.done_all_rounded, size: 17, color: color)
          : Icon(Icons.check_rounded, size: 17, color: color),
    );
  }

  Future<void> _showMessageReceipts(
    Map<String, dynamic> message,
    List<Map<String, dynamic>> recipients,
  ) =>
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const UniversalText('Message info'),
          content: SizedBox(
            width: 360,
            child: recipients.isEmpty
                ? const UniversalText('No recipients to show.')
                : ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 400),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final member in recipients)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              child: Text(
                                _initial(
                                  member['display_name']?.toString() ??
                                      member['username']?.toString() ??
                                      '?',
                                ),
                              ),
                            ),
                            title: Text(
                              member['display_name']?.toString() ??
                                  member['username']?.toString() ??
                                  'Member',
                            ),
                            subtitle: Text(_receiptLabel(member, message)),
                          ),
                      ],
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const UniversalText('Close'),
            ),
          ],
        ),
      );

  String _receiptLabel(
    Map<String, dynamic> member,
    Map<String, dynamic> message,
  ) {
    if (_memberHasReceived(member, message, 'lastReadAt')) {
      final readAt = _messageTime(member, 'lastReadAt')?.toLocal();
      return readAt == null ? 'Read' : 'Read at ${_formatTime(readAt)}';
    }
    if (_memberHasReceived(member, message, 'lastDeliveredAt')) {
      return 'Delivered';
    }
    return 'Sent';
  }

  String _formatTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String? _typingLabel(List<Map<String, dynamic>> typists) {
    if (typists.isEmpty) return null;
    if (typists.length > 2) return 'Several people are typing…';
    final names = typists
        .map(
          (member) =>
              member['display_name']?.toString() ??
              member['username']?.toString() ??
              'Someone',
        )
        .toList();
    return names.length == 1
        ? '${names.first} is typing…'
        : '${names[0]} and ${names[1]} are typing…';
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final messages = (data?['messages'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final members = (data?['members'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final typingMembers = (data?['typingMembers'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final conversation = data?['conversation'] as Map? ?? const {};
    final self = members.firstWhere(
      (member) => member['isSelf'] == true,
      orElse: () => <String, dynamic>{},
    );
    final other = members.where((item) => item['isSelf'] != true).toList();
    final primaryMember = other.isEmpty ? self : other.first;
    final subtitleParts = conversation['kind'] == 'group'
        ? other
            .where((member) => _presenceState(member) == 'active')
            .map((member) => member['activityText']?.toString())
            .whereType<String>()
            .where((activity) => activity.isNotEmpty)
            .toList()
        : <String>[
            if (primaryMember['nickname']?.toString().trim().isNotEmpty == true)
              primaryMember['nickname'].toString().trim(),
            if (primaryMember['activityText']?.toString().trim().isNotEmpty ==
                true)
              primaryMember['activityText'].toString().trim(),
          ];
    final subtitle = subtitleParts.take(2).join(' · ');
    final title = conversation['kind'] == 'group'
        ? (conversation['title']?.toString().trim().isNotEmpty == true
            ? conversation['title'].toString()
            : other
                .map((item) => item['display_name'] ?? item['username'])
                .join(', '))
        : other.isEmpty
            ? 'Conversation'
            : other.first['display_name']?.toString() ??
                other.first['username']?.toString() ??
                'Conversation';
    final savedBackgroundColor =
        self['chatBackgroundColor']?.toString().replaceFirst('#', '');
    final backgroundColor = savedBackgroundColor != null &&
            RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(savedBackgroundColor)
        ? Color(int.parse(savedBackgroundColor, radix: 16) | 0xFF000000)
        : Theme.of(context).scaffoldBackgroundColor;
    final backgroundImageUrl = self['chatBackgroundImageUrl']?.toString();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            InkWell(
              customBorder: const CircleBorder(),
              onTap: _isGroup
                  ? null
                  : () {
                      final friend = Map<String, dynamic>.from(primaryMember);
                      final profileId = (friend['profileId'] ??
                                  friend['profile_id'] ??
                                  friend['targetProfileId'] ??
                                  friend['target_profile_id'] ??
                                  friend['id'])
                              ?.toString() ??
                          '';
                      if (profileId.isEmpty) return;
                      Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) =>
                              FriendStoryProfileViewer(friend: friend)));
                    },
              child: _presenceAvatar(primaryMember, title),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white60,
                          ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_isGroup && _isGroupAdmin)
            PopupMenuButton<String>(
              tooltip: 'Group settings',
              onSelected: _setGroupPolicy,
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'all_members',
                  child: UniversalText('All members can send'),
                ),
                PopupMenuItem(
                  value: 'admins_only',
                  child: UniversalText('Only admins can send'),
                ),
              ],
              icon: const Icon(Icons.settings_outlined),
            ),
          IconButton(
            tooltip: 'Customize chat background',
            onPressed: () => _customizeChatBackground(members),
            icon: const Icon(Icons.wallpaper_outlined),
          ),
          PopupMenuButton<String>(
            tooltip: 'Profile presence and nickname',
            onSelected: (value) {
              if (value == 'nickname') {
                _setMyNickname();
              } else {
                _setAvailability(value);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'active',
                child: ListTile(
                  leading: Icon(Icons.circle, color: Colors.greenAccent),
                  title: UniversalText('Active'),
                ),
              ),
              PopupMenuItem(
                value: 'away',
                child: ListTile(
                  leading: Icon(Icons.circle, color: Colors.grey),
                  title: UniversalText('Away'),
                ),
              ),
              PopupMenuItem(
                value: 'busy',
                child: ListTile(
                  leading: Icon(Icons.circle, color: Colors.redAccent),
                  title: UniversalText('Busy'),
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'nickname',
                child: ListTile(
                  leading: Icon(Icons.badge_outlined),
                  title: UniversalText('Set my nickname'),
                ),
              ),
            ],
            icon: const Icon(Icons.more_vert_rounded),
          ),
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          image: backgroundImageUrl == null || backgroundImageUrl.isEmpty
              ? null
              : DecorationImage(
                  image: NetworkImage(backgroundImageUrl),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: .42),
                    BlendMode.darken,
                  ),
                ),
        ),
        child: Column(
          children: [
            Expanded(
              child: messages.isEmpty
                  ? const Center(
                      child: UniversalText(
                        'Say hello 👋',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (_, index) {
                        final message = messages[index];
                        final mine = message['isMine'] == true;
                        final mediaReference = message['mediaReference'] is Map
                            ? Map<String, dynamic>.from(
                                message['mediaReference'] as Map,
                              )
                            : message['media_reference'] is Map
                                ? Map<String, dynamic>.from(
                                    message['media_reference'] as Map,
                                  )
                                : <String, dynamic>{};
                        final poll = message['poll'] is Map
                            ? Map<String, dynamic>.from(message['poll'] as Map)
                            : null;
                        final sender = members.firstWhere(
                          (member) =>
                              member['accountId']?.toString() ==
                                  message['sender_account_id']?.toString() &&
                              member['profileId']?.toString() ==
                                  message['sender_profile_id']?.toString(),
                          orElse: () => <String, dynamic>{},
                        );
                        final reactionSummary =
                            message['reactionSummary'] is Map
                                ? Map<String, dynamic>.from(
                                    message['reactionSummary'] as Map,
                                  )
                                : <String, dynamic>{};
                        return Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: GestureDetector(
                            onLongPress: () =>
                                _react(message['id']?.toString() ?? ''),
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.sizeOf(context).width * .72,
                              ),
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: mine
                                    ? const Color(0xFF005C4B)
                                    : const Color(0xFF202C33),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(18),
                                  topRight: const Radius.circular(18),
                                  bottomLeft: Radius.circular(mine ? 18 : 4),
                                  bottomRight: Radius.circular(mine ? 4 : 18),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_isGroup && sender.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 5),
                                      child: _memberNameLabel(sender),
                                    ),
                                  if (message['reply_to_message_id'] != null)
                                    _replyPreview(
                                      messages,
                                      message['reply_to_message_id'].toString(),
                                    ),
                                  _messageContent(
                                      message, mediaReference, poll),
                                  if (reactionSummary.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 5),
                                      child: Wrap(
                                        spacing: 6,
                                        children: [
                                          for (final entry
                                              in reactionSummary.entries)
                                            Text(
                                              '${entry.key} ${entry.value}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (mine)
                                        _messageDeliveryIndicator(
                                          message,
                                          members,
                                        ),
                                      if (mediaReference['type'] == 'video')
                                        IconButton(
                                          tooltip: 'Share video to chats',
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () =>
                                              showSocialShareDialog(
                                            context,
                                            title: mediaReference['title']
                                                    ?.toString() ??
                                                'video',
                                            message:
                                                message['body']?.toString() ??
                                                    'Shared video',
                                            mediaReference: mediaReference,
                                            sourceMessageId:
                                                message['id']?.toString(),
                                          ),
                                          icon: const Icon(
                                            Icons.share_outlined,
                                            size: 18,
                                          ),
                                        ),
                                      TextButton(
                                        onPressed: () => setState(
                                          () => replyingTo = message,
                                        ),
                                        child: const UniversalText('Reply'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (_typingLabel(typingMembers) case final typingLabel?)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _TypingDots(color: Colors.white.withValues(alpha: .7)),
                      const SizedBox(width: 8),
                      Text(
                        typingLabel,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (replyingTo != null)
                      ListTile(
                        dense: true,
                        title: Text(
                          'Replying to: ${replyingTo!['body'] ?? 'attachment'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          onPressed: () => setState(() => replyingTo = null),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Attachments, polls, media, and sharing',
                          onPressed:
                              sending || !_canSend ? null : _chooseAttachment,
                          icon: const Icon(Icons.add_circle_outline_rounded),
                        ),
                        IconButton(
                          tooltip: 'Emoji',
                          onPressed:
                              sending || !_canSend ? null : () => _sendEmoji(),
                          icon: const Icon(Icons.emoji_emotions_outlined),
                        ),
                        if (!recording)
                          IconButton(
                            tooltip: viewOnceNext
                                ? 'View-once attachment enabled'
                                : 'Make next attachment view once',
                            onPressed: !_canSend
                                ? null
                                : () => setState(
                                      () => viewOnceNext = !viewOnceNext,
                                    ),
                            icon: Icon(
                              Icons.timer_outlined,
                              color: viewOnceNext ? Colors.amber : null,
                            ),
                          ),
                        Expanded(
                          child: TextField(
                            controller: messageController,
                            minLines: 1,
                            maxLines: 5,
                            onSubmitted: (_) => _send(),
                            decoration: InputDecoration(
                              prefixIcon: IconButton(
                                tooltip: 'Text style',
                                onPressed: sending || !_canSend
                                    ? null
                                    : _editTextFormat,
                                icon: Icon(
                                  Icons.format_color_text_rounded,
                                  color: _textFormat.isEmpty
                                      ? null
                                      : Theme.of(context).colorScheme.secondary,
                                ),
                              ),
                              hintText: !_canSend
                                  ? 'Only group admins can send'
                                  : recording
                                      ? 'Recording voice message… tap mic to send'
                                      : 'Message $title',
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: .06),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              enabled: _canSend && !recording,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (recording)
                          IconButton(
                            onPressed: sending ? null : _toggleVoiceRecording,
                            icon: const Icon(Icons.stop_circle_outlined),
                            color: Colors.redAccent,
                          )
                        else if (messageController.text.trim().isNotEmpty)
                          IconButton(
                            onPressed: sending || !_canSend ? null : _send,
                            icon: const Icon(Icons.send_rounded),
                          )
                        else
                          IconButton(
                            tooltip: 'Record voice message',
                            onPressed: sending || !_canSend
                                ? null
                                : _toggleVoiceRecording,
                            icon: const Icon(Icons.mic_none_rounded),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _replyPreview(List<Map<String, dynamic>> messages, String id) {
    final parent = messages.where((message) => message['id']?.toString() == id);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        parent.isEmpty ? 'Reply' : '↳ ${parent.first['body'] ?? 'Attachment'}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _messageContent(
    Map<String, dynamic> message,
    Map<String, dynamic> reference,
    Map<String, dynamic>? poll,
  ) {
    final type = reference['type']?.toString() ??
        message['message_type']?.toString() ??
        'text';
    final format = message['text_format'] is Map
        ? Map<String, dynamic>.from(message['text_format'] as Map)
        : <String, dynamic>{};
    final messageId = message['id']?.toString() ?? '';
    if (format['spoiler'] == true &&
        messageId.isNotEmpty &&
        !_revealedSpoilers.contains(messageId)) {
      return InkWell(
        onTap: () => setState(() => _revealedSpoilers.add(messageId)),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 220,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.visibility_off_outlined, size: 18),
              SizedBox(width: 8),
              Flexible(child: UniversalText('Spoiler · tap to reveal')),
            ],
          ),
        ),
      );
    }
    if (reference['requiresView'] == true) {
      return TextButton.icon(
        onPressed: () => _openViewOnce(message),
        icon: const Icon(Icons.visibility_outlined),
        label: const UniversalText('Tap to view once'),
      );
    }
    if (reference['expired'] == true) {
      return const UniversalText('This view-once attachment has expired.');
    }
    if (reference['viewOnce'] == true &&
        message['isMine'] != true &&
        message['view_once_opened'] != true) {
      return TextButton.icon(
        onPressed: () => _openViewOnce(message),
        icon: const Icon(Icons.visibility_outlined),
        label: const UniversalText('Tap to view once'),
      );
    }
    if (type == 'poll' && poll != null) return _pollCard(poll);
    if (type == 'sticker') {
      return Text(
        reference['emoji']?.toString() ?? message['body']?.toString() ?? '✨',
        style: const TextStyle(fontSize: 44),
      );
    }
    if (type == 'photo' || type == 'image' || type == 'gif') {
      final url = (reference['imageUrl'] ?? reference['url'])?.toString();
      if (url != null && url.isNotEmpty) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            url,
            width: 250,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const UniversalText('Image unavailable'),
          ),
        );
      }
    }
    final videoUrl = reference['videoUrl']?.toString();
    if (type == 'video' && videoUrl != null) {
      return _ChatVideoPlayer(url: videoUrl);
    }
    final audioUrl = reference['audioUrl']?.toString();
    if ((type == 'voice' || type == 'audio') && audioUrl != null) {
      return _ChatVideoPlayer(url: audioUrl, audioOnly: true);
    }
    if (type == 'link') {
      final url =
          reference['url']?.toString() ?? message['body']?.toString() ?? '';
      return InkWell(
        onTap: () {
          final uri = Uri.tryParse(url);
          if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
            launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        child: Text(
          '${reference['title'] ?? 'Link'}\n$url',
          style: const TextStyle(
            color: Colors.lightBlueAccent,
            decoration: TextDecoration.underline,
          ),
        ),
      );
    }
    if (type == 'friend_invite') {
      final username = reference['username']?.toString() ?? '';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message['body']?.toString() ?? 'Friend request suggestion'),
          if (username.isNotEmpty)
            TextButton.icon(
              onPressed: () async {
                try {
                  await AppController.instance.backendApi.sendFriendRequest(
                    profileId: widget.profileId,
                    username: username,
                  );
                  await _load();
                } catch (error) {
                  if (mounted) _showError(error.toString());
                }
              },
              icon: const Icon(Icons.person_add_alt_1),
              label: Text('Send friend request to @$username'),
            ),
        ],
      );
    }
    if (type == 'product' ||
        type == 'recommendation' ||
        type == 'shared_item' ||
        type == 'collection' ||
        type == 'playlist' ||
        type == 'album' ||
        type == 'song' ||
        type == 'show' ||
        type == 'movie' ||
        type == 'store') {
      final mediaType =
          (reference['mediaType'] ?? type).toString().toLowerCase();
      final mediaId = reference['mediaId']?.toString() ??
          reference['media_id']?.toString() ??
          reference['id']?.toString();
      final catalogMatches = mediaId == null
          ? <MediaItem>[]
          : AppController.instance.library
              .where((item) => item.id == mediaId)
              .toList();
      final catalogMatch = catalogMatches.isEmpty ? null : catalogMatches.first;
      final explicitOwned = reference['isOwned'] ??
          reference['owned'] ??
          reference['is_owned'] ??
          reference['hasAccess'];
      final explicitAvailable = reference['accessEnabled'] ??
          reference['access_enabled'] ??
          reference['isAvailable'];
      // Ownership/access must come from the recipient's catalog or a server-provided
      // per-recipient flag. Never infer purchase ownership from a shared link alone.
      final owned = explicitOwned is bool
          ? explicitOwned
          : (explicitAvailable is bool
              ? explicitAvailable
              : catalogMatch != null);
      final title = reference['title']?.toString() ??
          message['body']?.toString() ??
          'Shared item';
      final icon = switch (mediaType) {
        'product' => Icons.shopping_bag_outlined,
        'store' => Icons.storefront_outlined,
        'song' || 'album' || 'playlist' || 'music' => Icons.music_note_outlined,
        'collection' => Icons.collections_bookmark_outlined,
        'show' || 'tv' || 'episode' => Icons.live_tv_outlined,
        'movie' || 'film' || 'recommendation' => Icons.movie_outlined,
        _ => Icons.open_in_new_rounded,
      };
      return Container(
        width: 280,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: owned ? const Color(0xFF263A36) : const Color(0xFF151A1D),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: owned ? const Color(0xFF4C8A79) : Colors.white12,
          ),
        ),
        child: Opacity(
          // Unowned items remain readable and tappable for details/save actions.
          opacity: owned ? 1 : .66,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, size: 21),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800))),
              ]),
              if (reference['description']?.toString().isNotEmpty == true) ...[
                const SizedBox(height: 5),
                Text(reference['description'].toString(),
                    maxLines: 3, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 8),
              Row(children: [
                Icon(owned ? Icons.check_circle_outline : Icons.lock_outline,
                    size: 15,
                    color: owned ? const Color(0xFF8FE0C5) : Colors.white54),
                const SizedBox(width: 5),
                Expanded(
                    child: Text(
                  owned
                      ? (mediaType == 'product' || mediaType == 'store'
                          ? 'Saved / accessible'
                          : 'Owned or available to you')
                      : (mediaType == 'product' || mediaType == 'store'
                          ? 'Not saved · details available'
                          : 'Not in your library · preview available'),
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600),
                )),
              ]),
              if (!owned) ...[
                const SizedBox(height: 4),
                const Text('Shared item is still visible to you.',
                    style: TextStyle(fontSize: 10, color: Colors.white54)),
              ],
            ],
          ),
        ),
      );
    }
    final decorations = <TextDecoration>[
      if (format['underline'] == true) TextDecoration.underline,
      if (format['strikeThrough'] == true) TextDecoration.lineThrough,
    ];
    final rawColor = format['color']?.toString();
    final color =
        rawColor != null && RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(rawColor)
            ? Color(int.parse(rawColor.substring(1), radix: 16) | 0xFF000000)
            : null;
    final text = Text(
      message['body']?.toString() ?? '',
      style: TextStyle(
        height: 1.3,
        color: format['metallic'] == true ? null : color,
        fontFamily: format['fontFamily']?.toString(),
        fontWeight:
            format['bold'] == true ? FontWeight.bold : FontWeight.normal,
        fontStyle:
            format['italic'] == true ? FontStyle.italic : FontStyle.normal,
        decoration: decorations.isEmpty
            ? TextDecoration.none
            : TextDecoration.combine(decorations),
      ),
    );
    return format['metallic'] == true
        ? ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => const LinearGradient(
              colors: [
                Color(0xFF8A8A8A),
                Color(0xFFF9F9F9),
                Color(0xFF777777),
                Color(0xFFE5E5E5),
              ],
            ).createShader(bounds),
            child: text,
          )
        : text;
  }

  Widget _pollCard(Map<String, dynamic> poll) {
    final options = (poll['options'] as List? ?? const [])
        .map((option) => option.toString())
        .toList();
    final counts = (poll['voteCounts'] as List? ?? const [])
        .map((count) => count is num ? count.toInt() : 0)
        .toList();
    final myVote = (poll['myVote'] as num?)?.toInt();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          poll['question']?.toString() ?? 'Group poll',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        for (var index = 0; index < options.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: OutlinedButton(
              onPressed: () => _votePoll(poll, index),
              child: Row(
                children: [
                  Expanded(child: Text(options[index])),
                  if (myVote == index) const Icon(Icons.check_rounded),
                  const SizedBox(width: 6),
                  Text('${index < counts.length ? counts[index] : 0}'),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _sendEmoji() async {
    final emoji = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            for (final item in _emojis)
              SizedBox(
                width: 56,
                child: IconButton(
                  onPressed: () => Navigator.pop(context, item),
                  icon: Text(item, style: const TextStyle(fontSize: 25)),
                ),
              ),
          ],
        ),
      ),
    );
    if (emoji != null) {
      await _sendMessage(body: emoji, messageType: 'emoji');
    }
  }

  String _initial(String value) {
    final clean = value.trim();
    return clean.isEmpty ? '?' : clean.substring(0, 1).toUpperCase();
  }
}

class _ChatVideoPlayer extends StatefulWidget {
  const _ChatVideoPlayer({required this.url, this.audioOnly = false});

  final String url;
  final bool audioOnly;

  @override
  State<_ChatVideoPlayer> createState() => _ChatVideoPlayerState();
}

class _ChatVideoPlayerState extends State<_ChatVideoPlayer> {
  late final VideoPlayerController controller;

  @override
  void initState() {
    super.initState();
    controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    controller.initialize().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const SizedBox(
        width: 220,
        height: 72,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return SizedBox(
      width: widget.audioOnly ? 250 : 260,
      child: Column(
        children: [
          if (!widget.audioOnly)
            AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            )
          else
            const Icon(Icons.graphic_eq_rounded, size: 40),
          IconButton(
            onPressed: () {
              setState(() {
                controller.value.isPlaying
                    ? controller.pause()
                    : controller.play();
              });
            },
            icon: Icon(
              controller.value.isPlaying
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_fill,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots({required this.color});

  final Color color;

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < 3; index++)
              Opacity(
                opacity: .35 +
                    .65 *
                        ((1 - (_controller.value * 3 - index).abs())
                            .clamp(0.0, 1.0)),
                child: Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      );
}

/// Community detail experience with membership actions and community content.
/// Join/leave mutations are delegated to the authenticated backend; the page
/// only changes its local membership state after the mutation succeeds.
class CommunityDetailPage extends StatefulWidget {
  const CommunityDetailPage({
    super.key,
    required this.community,
    required this.posts,
    required this.stories,
    required this.isJoined,
    required this.isOwner,
    required this.onJoin,
    required this.onLeave,
    required this.onCreatePost,
    required this.onCreateStory,
  });

  final Map<String, dynamic> community;
  final List<Map<String, dynamic>> posts;
  final List<Map<String, dynamic>> stories;
  final bool isJoined;
  final bool isOwner;
  final Future<void> Function() onJoin;
  final Future<void> Function() onLeave;
  final Future<void> Function() onCreatePost;
  final Future<void> Function() onCreateStory;

  @override
  State<CommunityDetailPage> createState() => _CommunityDetailPageState();
}

class _CommunityDetailPageState extends State<CommunityDetailPage> {
  late bool _joined;
  bool _busy = false;
  String _section = 'Posts';

  @override
  void initState() {
    super.initState();
    _joined = widget.isJoined;
  }

  Future<void> _membershipAction({required bool join}) async {
    if (_busy) return;
    if (!join && widget.isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Transfer community ownership before leaving.'),
      ));
      return;
    }
    setState(() => _busy = true);
    try {
      if (join) {
        await widget.onJoin();
      } else {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Leave this community?'),
            content: const Text(
                'You can rejoin later if the community is still available. You will lose access to member-only posts and stories.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Leave community')),
            ],
          ),
        );
        if (confirmed != true) return;
        await widget.onLeave();
      }
      if (mounted) setState(() => _joined = join);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(join
              ? 'You joined ${widget.community['name'] ?? 'the community'}.'
              : 'You left the community.'),
        ));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final community = widget.community;
    final name = community['name']?.toString() ?? 'Community';
    final description = community['description']?.toString().trim() ?? '';
    final category = (community['category'] ?? 'general').toString();
    final memberCount = (community['memberCount'] as num?)?.toInt() ?? 0;
    final postCount =
        (community['postCount'] as num?)?.toInt() ?? widget.posts.length;
    final createdAt =
        DateTime.tryParse((community['created_at'] ?? '').toString());
    final categoryIcon = switch (category.toLowerCase()) {
      'movies' => Icons.movie_creation_outlined,
      'shows' => Icons.live_tv_rounded,
      'music' => Icons.music_note_rounded,
      _ => Icons.groups_rounded,
    };

    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 220,
          title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF32215D),
                    Color(0xFF6A3CA0),
                    Color(0xFF171B36)
                  ],
                ),
              ),
              child: SafeArea(
                  child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 62, 24, 20),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.white.withValues(alpha: .16),
                          child: Icon(categoryIcon,
                              size: 30, color: Colors.white)),
                      const SizedBox(height: 10),
                      Text(name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w900,
                              color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(
                          '${category.isEmpty ? 'General' : '${category[0].toUpperCase()}${category.substring(1)}'} community • ${community['visibility'] == 'private' ? 'Private' : 'Public'}',
                          style: const TextStyle(color: Colors.white70)),
                    ]),
              )),
            ),
          ),
        ),
        SliverToBoxAdapter(
            child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (description.isNotEmpty)
              Text(description, style: Theme.of(context).textTheme.bodyLarge),
            if (description.isNotEmpty) const SizedBox(height: 16),
            Row(children: [
              Expanded(
                  child: _CommunityStat(
                      icon: Icons.people_alt_outlined,
                      value: _compactCount(memberCount),
                      label: 'Members')),
              const SizedBox(width: 10),
              Expanded(
                  child: _CommunityStat(
                      icon: Icons.article_outlined,
                      value: _compactCount(postCount),
                      label: 'Posts')),
              const SizedBox(width: 10),
              Expanded(
                  child: _CommunityStat(
                      icon: Icons.auto_awesome_outlined,
                      value: '${widget.stories.length}',
                      label: 'Stories')),
            ]),
            const SizedBox(height: 16),
            SizedBox(
                width: double.infinity,
                child: _joined
                    ? OutlinedButton.icon(
                        onPressed: _busy || widget.isOwner
                            ? null
                            : () => _membershipAction(join: false),
                        icon: _busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.check_circle_outline),
                        label: Text(widget.isOwner
                            ? 'Owner'
                            : 'Joined · Leave community'),
                      )
                    : FilledButton.icon(
                        onPressed:
                            _busy ? null : () => _membershipAction(join: true),
                        icon: _busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.group_add_outlined),
                        label: const Text('Join community'),
                      )),
            if (_joined) ...[
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () async {
                                await widget.onCreatePost();
                              },
                        icon: const Icon(Icons.post_add_rounded),
                        label: const Text('Create post'))),
                const SizedBox(width: 8),
                Expanded(
                    child: OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () async {
                                await widget.onCreateStory();
                              },
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Add story'))),
              ]),
            ],
            const SizedBox(height: 18),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: 'Posts',
                    label: Text('Posts'),
                    icon: Icon(Icons.forum_outlined)),
                ButtonSegment(
                    value: 'About',
                    label: Text('About'),
                    icon: Icon(Icons.info_outline)),
              ],
              selected: {_section},
              onSelectionChanged: (selection) =>
                  setState(() => _section = selection.first),
            ),
            const SizedBox(height: 12),
          ]),
        )),
        if (_section == 'About')
          SliverToBoxAdapter(
              child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Card(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('About this community',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 18)),
                          const SizedBox(height: 12),
                          _CommunityAboutRow(
                              icon: Icons.category_outlined,
                              label: 'Category',
                              value: category),
                          _CommunityAboutRow(
                              icon: Icons.public_outlined,
                              label: 'Visibility',
                              value: community['visibility']?.toString() ??
                                  'public'),
                          _CommunityAboutRow(
                              icon: Icons.calendar_today_outlined,
                              label: 'Created',
                              value: createdAt == null
                                  ? 'Date unavailable'
                                  : '${createdAt.day}/${createdAt.month}/${createdAt.year}'),
                          _CommunityAboutRow(
                              icon: Icons.admin_panel_settings_outlined,
                              label: 'Moderation',
                              value:
                                  'Follow community rules and keep discussions respectful.'),
                        ]))),
          ))
        else if (!_joined)
          SliverToBoxAdapter(
              child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Card(
                child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(children: [
                      const Icon(Icons.lock_outline_rounded, size: 34),
                      const SizedBox(height: 8),
                      const Text('Join the community to participate',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(
                          'Join to create posts and stories and take part in the conversation.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ]))),
          ))
        else if (widget.posts.isEmpty && widget.stories.isEmpty)
          SliverToBoxAdapter(
              child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const Icon(Icons.forum_outlined, size: 42),
              const SizedBox(height: 8),
              const Text('No posts yet',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('Be the first to start a conversation.')
            ]),
          ))
        else
          SliverList(
              delegate: SliverChildListDelegate([
            if (_joined && widget.stories.isNotEmpty) ...[
              const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text('Community stories',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800))),
              SizedBox(
                  height: 104,
                  child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: widget.stories.map((story) {
                        final author = story['author'] is Map
                            ? Map<String, dynamic>.from(story['author'] as Map)
                            : <String, dynamic>{};
                        final label = (author['display_name'] ??
                                author['username'] ??
                                'Member')
                            .toString();
                        return SizedBox(
                            width: 90,
                            child: Card(
                                child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const CircleAvatar(
                                              child: Icon(Icons.auto_awesome)),
                                          const SizedBox(height: 5),
                                          Text(label,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                              style:
                                                  const TextStyle(fontSize: 12))
                                        ]))));
                      }).toList())),
            ],
            if (_joined)
              ...widget.posts.map((post) {
                final author = post['author'] is Map
                    ? Map<String, dynamic>.from(post['author'] as Map)
                    : <String, dynamic>{};
                final authorName = (author['display_name'] ??
                        author['displayName'] ??
                        author['username'] ??
                        'Community member')
                    .toString();
                final body = (post['body'] ?? post['content'] ?? '').toString();
                final date =
                    DateTime.tryParse((post['created_at'] ?? '').toString());
                return Card(
                    margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                const CircleAvatar(
                                    radius: 17,
                                    child:
                                        Icon(Icons.person_outline, size: 18)),
                                const SizedBox(width: 9),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(authorName,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800)),
                                      Text(
                                          date == null
                                              ? 'Community post'
                                              : '${date.day}/${date.month}/${date.year}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall)
                                    ]))
                              ]),
                              if (body.isNotEmpty)
                                Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Text(body)),
                            ])));
              }),
          ])),
      ]),
    );
  }

  String _compactCount(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(value >= 10000000 ? 0 : 1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}K';
    }
    return '$value';
  }
}

class _CommunityStat extends StatelessWidget {
  const _CommunityStat(
      {required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Column(children: [
            Icon(icon, size: 20),
            const SizedBox(height: 6),
            Text(value,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            Text(label, style: Theme.of(context).textTheme.bodySmall)
          ])));
}

class _CommunityAboutRow extends StatelessWidget {
  const _CommunityAboutRow(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        Icon(icon, size: 19),
        const SizedBox(width: 10),
        SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w700))),
        Expanded(child: Text(value))
      ]));
}
