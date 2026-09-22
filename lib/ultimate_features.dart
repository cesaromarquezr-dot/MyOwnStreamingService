// FILE: `lib/ultimate_features.dart`.
// Purpose: Implements the ultimate features portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_core.dart';
import 'localization.dart';
import 'music.dart';

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
              Icon(Icons.sports_kabaddi_outlined),
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
                        Icons.sports_kabaddi_outlined,
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
                          'Everything in one place: library, devices, security, travel, games, discovery and server controls.',
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
                        : '${account.username} • ${account.email}',
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
  const BackupScreen({
    super.key,
  });

  @override
  State<BackupScreen> createState() =>
      _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool metadata = true;
  bool history = true;
  bool profiles = true;
  bool collections = true;

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    final selectedCount = [
      metadata,
      history,
      profiles,
      collections,
    ].where((selected) => selected).length;

    return Scaffold(
      appBar: AppBar(
        title: const UniversalText(
          'Backup & Recovery',
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
                    Icons.backup_outlined,
                    size: 28,
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: UniversalText(
                      'Backups protect your library metadata and account configuration. Actual media backups depend on the server storage you connect.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: UniversalText(
                      'Backup selection',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Chip(
                    label: UniversalText(
                      '$selectedCount of 4 selected',
                    ),
                  ),
                ],
              ),
            ),
          ),
          SwitchListTile(
            title: const UniversalText(
              'Library metadata',
            ),
            subtitle: const UniversalText(
              'Titles, identifiers and media metadata.',
            ),
            value: metadata,
            onChanged: (value) {
              setState(() {
                metadata = value;
              });
            },
          ),
          SwitchListTile(
            title: const UniversalText(
              'Watch history',
            ),
            subtitle: const UniversalText(
              'Watched titles and account activity history.',
            ),
            value: history,
            onChanged: (value) {
              setState(() {
                history = value;
              });
            },
          ),
          SwitchListTile(
            title: const UniversalText(
              'Profiles & settings',
            ),
            subtitle: const UniversalText(
              'Profiles and account configuration.',
            ),
            value: profiles,
            onChanged: (value) {
              setState(() {
                profiles = value;
              });
            },
          ),
          SwitchListTile(
            title: const UniversalText(
              'Collections & achievements',
            ),
            subtitle: const UniversalText(
              'Collections and feature activity.',
            ),
            value: collections,
            onChanged: (value) {
              setState(() {
                collections = value;
              });
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: selectedCount == 0
                  ? null
                  : () {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(
                        const SnackBar(
                          content: UniversalText(
                            'Backup job queued.',
                          ),
                        ),
                      );
                    },
              icon: const Icon(
                Icons.backup,
              ),
              label: const UniversalText(
                'BACK UP NOW',
              ),
            ),
          ),
        ],
      ),
    );
  }
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