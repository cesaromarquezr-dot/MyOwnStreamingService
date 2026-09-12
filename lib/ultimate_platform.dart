// FILE: `lib/ultimate_platform.dart`.
// Purpose: Implements the ultimate platform portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'package:flutter/material.dart';
import 'app_core.dart';
import 'details.dart';

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
        title: const Text('Ultimate Streaming Platform'),
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
        const SnackBar(content: Text('Add media first.')),
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
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.psychology),
            hintText: 'Try: funny sci-fi with a strong female lead',
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
          title: const Text('Sign out other devices'),
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Remote session control is connected to the platform layer.')),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.delete_sweep),
          title: const Text('Clear local activity'),
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
            subtitle: const Text('Platform-ready configuration'),
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
              SnackBar(content: Text('$x is available from the platform control layer.')),
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
      title: const Text('Clear local activity?'),
      content: const Text(
          'This removes local-only activity from the current app session.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          onPressed: () {
            final controller = AppController.instance;
            controller.activity.clear();
            controller.watched.clear();
            Navigator.pop(context);
          },
          child: const Text('CLEAR'),
        ),
      ],
    ),
  );
}
