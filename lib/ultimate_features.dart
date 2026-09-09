import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_core.dart';

class UltimateFeaturesScreen extends StatefulWidget {
  const UltimateFeaturesScreen({super.key});

  @override
  State<UltimateFeaturesScreen> createState() =>
      _UltimateFeaturesScreenState();
}

class _UltimateFeaturesScreenState
    extends State<UltimateFeaturesScreen> {
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

  int get shows => controller.library.length - movies;

  int get watched => controller.watched.length;

  int get hours =>
      watched +
      controller.watched
          .where(
            (m) => m.type.toLowerCase().contains('movie'),
          )
          .length;

  void _push(Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => page,
      ),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Future<void> _aiConcierge() async {
    final textController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('AI Movie Concierge'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ask about your own library. '
              'Example: “I have 90 minutes, what should I watch?”',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              decoration: const InputDecoration(
                hintText: 'What do you want to watch?',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);

              final String pick;

              if (controller.library.isEmpty) {
                pick = 'Add a movie or show first.';
              } else {
                final random = math.Random();
                pick = controller
                    .library[
                        random.nextInt(controller.library.length)]
                    .title;
              }

              _snack(
                'Concierge: Try “$pick”.',
              );
            },
            child: const Text('ASK'),
          ),
        ],
      ),
    );

    textController.dispose();
  }

  void _roulette() {
    if (controller.library.isEmpty) {
      _snack(
        'Add some movies or shows first.',
      );
      return;
    }

    final random = math.Random();

    final pick = controller.library[
        random.nextInt(controller.library.length)];

    _snack(
      'Tonight’s pick: ${pick.title}',
    );
  }

  void _battle() {
    if (controller.library.length < 2) {
      _snack(
        'Add at least two titles for a Movie Battle.',
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

    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Movie Battle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              a.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'VS',
              style: TextStyle(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              b.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('PICK ONE'),
          ),
        ],
      ),
    );
  }

  void _security() {
    _push(
      const SecurityCenterScreen(),
    );
  }

  void _owner() {
    _push(
      const OwnerDashboardScreen(),
    );
  }

  void _channelScreen() {
    _push(
      ChannelScreen(
        channel: channel,
        library: controller.library,
      ),
    );
  }

  void _stats() {
    _push(
      const StatisticsScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Everything'),
        actions: [
          IconButton(
            onPressed: _aiConcierge,
            icon: const Icon(
              Icons.auto_awesome_rounded,
            ),
            tooltip: 'AI Concierge',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          16,
          12,
          16,
          30,
        ),
        children: [
          _hero(),

          const SizedBox(height: 14),

          // ACCOUNT & SECURITY
          _section(
            'Account & Security',
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
                  );
                },
              ),
            ],
          ),

          // YOUR LIBRARY
          _section(
            'Your Library',
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
                  _snack(
                    'Smart collection tools are available from Discover, Collections & Wrapped.',
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
                  _snack(
                    'Time Machine opened: showing your earliest watched titles.',
                  );
                },
              ),
            ],
          ),

          // FUN & SOCIAL
          _section(
            'Fun & Social',
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
                  _snack(
                    'Guess the Movie: coming up with a title from your library…',
                  );
                },
              ),
              _tile(
                Icons.people_outline,
                'Who Knows You Best?',
                'Compare profile watch habits',
                () {
                  _snack(
                    'Profile quiz ready.',
                  );
                },
              ),
              _tile(
                Icons.emoji_events_outlined,
                'Group Awards',
                'Best binge, most adventurous, most rewatched and more',
                () {
                  _snack(
                    'Group Awards calculated from account activity.',
                  );
                },
              ),
              _tile(
                Icons.chat_bubble_outline,
                'Spoiler-Protected Chat',
                'Hide messages until everyone reaches the scene',
                () {
                  _snack(
                    'Spoiler protection enabled for the next group chat.',
                  );
                },
              ),
            ],
          ),

          // AI & DISCOVERY
          _section(
            'AI & Discovery',
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
                  _snack(
                    'Recommendation chain generated.',
                  );
                },
              ),
              _tile(
                Icons.account_tree_outlined,
                'AI Actor Connections',
                'Find connections between actors in your library',
                () {
                  _snack(
                    'Actor connection graph ready.',
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
                },
              ),
              ListTile(
                title: const Text(
                  'Channel style',
                ),
                subtitle: Text(
                  channel,
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                ),
                onTap: () async {
                  final textController =
                      TextEditingController(
                    text: channel,
                  );

                  await showDialog<void>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text(
                        'Channel name',
                      ),
                      content: TextField(
                        controller:
                            textController,
                        decoration:
                            const InputDecoration(
                          hintText:
                              'My Streaming Channel',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(
                              context,
                            );
                          },
                          child:
                              const Text('CANCEL'),
                        ),
                        FilledButton(
                          onPressed: () {
                            setState(() {
                              channel =
                                  textController.text
                                          .trim()
                                          .isEmpty
                                      ? 'My Streaming Channel'
                                      : textController
                                          .text
                                          .trim();
                            });

                            Navigator.pop(
                              context,
                            );
                          },
                          child:
                              const Text('SAVE'),
                        ),
                      ],
                    ),
                  );

                  textController.dispose();
                },
              ),
            ],
          ),

          // TRAVEL & DOWNLOADS
          _section(
            'Travel & Downloads',
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
                },
              ),
              _tile(
                Icons.flight_takeoff_rounded,
                'Road Trip / Flight Pack',
                'Choose movies and entire TV seasons for offline viewing',
                () {
                  _snack(
                    'Open Devices, TV & Road Trip to manage downloads.',
                  );
                },
              ),
              _tile(
                Icons.directions_car_outlined,
                'Car Mode',
                'Bluetooth audio, compatible car displays and passenger viewing',
                () {
                  _snack(
                    'Car Mode ready. Video should only be viewed by passengers.',
                  );
                },
              ),
            ],
          ),

          // DEVICE EXPERIENCE
          _section(
            'Device Experience',
            [
              _tile(
                Icons.computer_rounded,
                'PC / Desktop',
                'Website/desktop app with the exclusive disc-import workflow',
                () {
                  _snack(
                    'Desktop: disc reader + remote import + full library management.',
                  );
                },
              ),
              _tile(
                Icons.phone_iphone_rounded,
                'Phone / Tablet',
                'Streaming, offline downloads, casting and remote control',
                () {
                  _snack(
                    'Mobile: downloads + casting + remote control.',
                  );
                },
              ),
              _tile(
                Icons.tv_rounded,
                'TV',
                'Big-screen experience with QR pairing and remote control',
                () {
                  _snack(
                    'TV: best viewing experience.',
                  );
                },
              ),
              _tile(
                Icons.cable_rounded,
                'HDMI / Cast fallback',
                'Connect a computer to a TV by HDMI or cast from a mobile device',
                () {
                  _snack(
                    'Use HDMI or supported casting when a TV app is unavailable.',
                  );
                },
              ),
            ],
          ),

          // PLATFORM OPERATIONS
          _section(
            'Platform Operations',
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
                  _snack(
                    'Storage Manager uses the account-wide server storage bar.',
                  );
                },
              ),
              _tile(
                Icons.disc_full_outlined,
                'Disc Import Center',
                'Detect → identify → rip → process → completed',
                () {
                  _snack(
                    'Disc Import Center is available on trusted desktop workers.',
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hero() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Your streaming universe',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Everything in one place: library, devices, security, '
              'travel, games, discovery and server controls.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text(
                    '${controller.library.length} library titles',
                  ),
                ),
                Chip(
                  label: Text(
                    '${controller.currentAccount?.profiles.length ?? 0} profiles',
                  ),
                ),
                Chip(
                  label: Text(
                    controller.currentAccount == null
                        ? 'Signed out'
                        : 'Account connected',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(
    String title,
    List<Widget> children,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 8,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              4,
              12,
              4,
              6,
            ),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Card(
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(
        Icons.chevron_right,
      ),
      onTap: onTap,
    );
  }

  Widget _switchTile(
    IconData icon,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
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
  Widget build(BuildContext context) {
    final controller = AppController.instance;
    final account = controller.currentAccount;

    final double storageProgress =
        account == null ||
                account.storageLimitBytes <= 0
            ? 0.0
            : (account.storageUsedBytes /
                    account.storageLimitBytes)
                .clamp(0.0, 1.0)
                .toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Owner Dashboard',
        ),
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
                  const Text(
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
                  Text(
                    '${_size(account?.storageUsedBytes ?? 0)} '
                    'used of '
                    '${_size(account?.storageLimitBytes ?? 1000000000000)}',
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
          ).showSnackBar(
            SnackBar(
              content: Text(
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

class SecurityCenterScreen
    extends StatelessWidget {
  const SecurityCenterScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Security Center',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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

class StatisticsScreen
    extends StatelessWidget {
  const StatisticsScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final controller =
        AppController.instance;

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
        (sum, rating) =>
            sum + rating.toDouble(),
      );

      averageRating =
          total / ratings.length;
    }

    final movieCount = controller.library
        .where(
          (media) => media.type
              .toLowerCase()
              .contains('movie'),
        )
        .length;

    final showCount =
        controller.library.length -
            movieCount;

    final streak =
        math.max(0, controller.watched.length);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Advanced Statistics',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
            'Watched',
            '${controller.watched.length}',
          ),

          _stat(
            'Average title rating',
            averageRating.toStringAsFixed(1),
          ),

          _stat(
            'Watch streak',
            '$streak day activity streak',
          ),

          const SizedBox(height: 12),

          const Text(
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
              child: Text(
                controller.watched.isEmpty
                    ? 'Explorer — start watching to build your personality card.'
                    : controller.watched.length > 10
                        ? 'Binge Master — you love finishing what you start.'
                        : 'Curious Viewer — you are building a diverse watch history.',
              ),
            ),
          ),
        ],
      ),
    );
  }

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

class MovieMapScreen
    extends StatelessWidget {
  const MovieMapScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Movie Map',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(
                    Icons.public,
                    size: 70,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your Movie Map',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'When location metadata is available, '
                    'titles can be grouped by filming location '
                    'and story setting.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Map metadata will populate as titles are identified.',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.explore,
                    ),
                    label: const Text(
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

class ChannelScreen
    extends StatelessWidget {
  final String channel;
  final List<MediaItem> library;

  const ChannelScreen({
    super.key,
    required this.channel,
    required this.library,
  });

  @override
  Widget build(BuildContext context) {
    final list = [...library];

    return Scaffold(
      appBar: AppBar(
        title: Text(channel),
      ),
      body: list.isEmpty
          ? const Center(
              child: Text(
                'Add media to generate your channel.',
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final media = list[index];

                final hour =
                    (index * 90) % 24;

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        '${index + 1}',
                      ),
                    ),
                    title: Text(
                      media.title,
                    ),
                    subtitle: Text(
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

class NotificationCenterScreen
    extends StatelessWidget {
  const NotificationCenterScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notification Center',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// BACKUP
// -----------------------------------------------------------------------------

class BackupScreen
    extends StatefulWidget {
  const BackupScreen({
    super.key,
  });

  @override
  State<BackupScreen> createState() =>
      _BackupScreenState();
}

class _BackupScreenState
    extends State<BackupScreen> {
  bool metadata = true;
  bool history = true;
  bool profiles = true;
  bool collections = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Backup & Recovery',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'Backups protect your library metadata and account configuration. '
                'Actual media backups depend on the server storage you connect.',
              ),
            ),
          ),

          SwitchListTile(
            title: const Text(
              'Library metadata',
            ),
            value: metadata,
            onChanged: (value) {
              setState(() {
                metadata = value;
              });
            },
          ),

          SwitchListTile(
            title: const Text(
              'Watch history',
            ),
            value: history,
            onChanged: (value) {
              setState(() {
                history = value;
              });
            },
          ),

          SwitchListTile(
            title: const Text(
              'Profiles & settings',
            ),
            value: profiles,
            onChanged: (value) {
              setState(() {
                profiles = value;
              });
            },
          ),

          SwitchListTile(
            title: const Text(
              'Collections & achievements',
            ),
            value: collections,
            onChanged: (value) {
              setState(() {
                collections = value;
              });
            },
          ),

          const SizedBox(height: 12),

          FilledButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Backup job queued.',
                  ),
                ),
              );
            },
            icon: const Icon(
              Icons.backup,
            ),
            label: const Text(
              'BACK UP NOW',
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
    final tb =
        bytes / 1000000000000;

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

  return '$bytes B';
}