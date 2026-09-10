import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'app_core.dart';
import 'details.dart';
import 'player.dart';

/// Phase 2 features are intentionally kept in one module so the existing
/// 34-feature implementation remains stable while the app gains a richer
/// personal streaming layer.
class Phase2Store {
  Phase2Store._();
  static final Set<String> downloads = <String>{};
  static final Map<String, List<String>> playlists = <String, List<String>>{};
  static final Map<String, bool> toggles = <String, bool>{
    'autoplay': true,
    'skipIntro': true,
    'skipRecap': true,
    'dataSaver': false,
    'wifiOnly': true,
    'pinProtection': false,
    'kidsMode': false,
    'notifications': true,
    'spoilers': false,
    'sync': true,
    'pip': true,
    'haptic': true,
  };

  static bool getBool(String key) => toggles[key] ?? false;
  static void setBool(String key, bool value) => toggles[key] = value;
}

class NextGenFeaturesScreen extends StatefulWidget {
  const NextGenFeaturesScreen({super.key});
  @override
  State<NextGenFeaturesScreen> createState() => _NextGenFeaturesScreenState();
}

class _NextGenFeaturesScreenState extends State<NextGenFeaturesScreen> {
  int tab = 0;
  final tabs = const ['Discover', 'My Stuff', 'Stats', 'Settings'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Next-Gen Streaming'),
        actions: [
          IconButton(
            tooltip: 'What is new',
            icon: const Icon(Icons.auto_awesome_rounded),
            onPressed: () => _showWhatIsNew(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < tabs.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(tabs[i]),
                        selected: tab == i,
                        onSelected: (_) => setState(() => tab = i),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: tab,
              children: const [
                SmartDiscoverPanel(),
                MyStuffPanel(),
                WatchStatsPanel(),
                Phase2SettingsPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showWhatIsNew(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF151515),
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: ListView(
            shrinkWrap: true,
            children: const [
              Text('Phase 2', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              SizedBox(height: 8),
              Text('The new layer adds smarter discovery, personal collections, playlists, downloads, viewing analytics, playback controls, privacy, kids mode, data saving, sync controls and an AI-style watch assistant.', style: TextStyle(color: Colors.white70, height: 1.45)),
              SizedBox(height: 18),
              _Bullet('Smart “what should I watch?” discovery'),
              _Bullet('Watchlist, likes, unfinished and downloads in one place'),
              _Bullet('Viewing streaks, hours, genres and completion stats'),
              _Bullet('Custom playlists for movies and shows'),
              _Bullet('Offline/download manager UI'),
              _Bullet('Playback, subtitle and data-saver preferences'),
              _Bullet('Kids mode and privacy controls'),
              _Bullet('Cloud-sync and backup controls'),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(padding: EdgeInsets.only(top: 4), child: Icon(Icons.check_circle, size: 16, color: Colors.redAccent)),
      const SizedBox(width: 9),
      Expanded(child: Text(text, style: const TextStyle(color: Colors.white70))),
    ]),
  );
}

class SmartDiscoverPanel extends StatefulWidget {
  const SmartDiscoverPanel({super.key});
  @override
  State<SmartDiscoverPanel> createState() => _SmartDiscoverPanelState();
}

class _SmartDiscoverPanelState extends State<SmartDiscoverPanel> {
  String mood = 'Anything';
  String query = '';
  final search = TextEditingController();

  @override
  void dispose() { search.dispose(); super.dispose(); }

  List<MediaItem> get all => AppController.instance.library;

  List<MediaItem> get filtered {
    final q = query.trim().toLowerCase();
    final source = q.isEmpty ? all : all.where((m) =>
      m.title.toLowerCase().contains(q) ||
      m.genres.any((g) => g.toLowerCase().contains(q)) ||
      m.actors.any((a) => a.toLowerCase().contains(q)) ||
      m.directors.any((d) => d.toLowerCase().contains(q))
    ).toList();
    if (mood == 'Anything') return source;
    final wanted = mood.toLowerCase();
    return source.where((m) => m.genres.any((g) => g.toLowerCase().contains(wanted)) || m.tags.any((g) => g.toLowerCase().contains(wanted))).toList();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppController.instance;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
          children: [
            const _HeroCard(
              icon: Icons.auto_awesome,
              title: 'Your personal watch assistant',
              subtitle: 'Tell the app what you feel like watching, or search by title, actor, director, genre or tag.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: search,
              onChanged: (v) => setState(() => query = v),
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Search your library…', suffixIcon: query.isEmpty ? null : IconButton(onPressed: () { search.clear(); setState(() => query = ''); }, icon: const Icon(Icons.close))),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final item in const ['Anything', 'Comedy', 'Drama', 'Action', 'Horror', 'Romance', 'Sci-Fi', 'Family'])
                  Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(item), selected: mood == item, onSelected: (_) => setState(() => mood = item))),
              ]),
            ),
            const SizedBox(height: 20),
            _SectionTitle('Best matches for you', Icons.recommend_rounded),
            const SizedBox(height: 10),
            if (filtered.isEmpty)
              const _EmptyCard(title: 'Nothing matches yet', subtitle: 'Add more movies or shows to build smarter recommendations.')
            else
              ...filtered.take(12).map((media) => _MediaRow(media: media)),
            const SizedBox(height: 18),
            _SectionTitle('Quick picks', Icons.bolt_rounded),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _QuickAction(icon: Icons.shuffle, title: 'Surprise me', onTap: () {
                if (all.isEmpty) return;
                final pick = all[math.Random().nextInt(all.length)];
                Navigator.push(context, MaterialPageRoute(builder: (_) => MediaDetailsScreen(media: pick)));
              })),
              const SizedBox(width: 10),
              Expanded(child: _QuickAction(icon: Icons.history, title: 'Continue', onTap: () {
                final items = all.where((m) => controller.getPlaybackProgress(m.id) > 0 && controller.getPlaybackProgress(m.id) < 1).toList();
                if (items.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nothing is waiting to be continued.'))); return; }
                Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(media: items.first)));
              })),
            ]),
          ],
        ),
      ),
    );
  }
}

class MyStuffPanel extends StatefulWidget {
  const MyStuffPanel({super.key});
  @override
  State<MyStuffPanel> createState() => _MyStuffPanelState();
}

class _MyStuffPanelState extends State<MyStuffPanel> {
  String filter = 'All';
  final playlistController = TextEditingController();
  @override
  void dispose() { playlistController.dispose(); super.dispose(); }

  List<MediaItem> get items {
    final c = AppController.instance;
    switch (filter) {
      case 'Liked': return c.liked;
      case 'Watched': return c.watched;
      case 'Continue': return c.library.where((m) { final p = c.getPlaybackProgress(m.id); return p > 0 && p < 1; }).toList();
      case 'Downloads': return c.library.where((m) => Phase2Store.downloads.contains(m.id)).toList();
      default: return c.library;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppController.instance;
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        children: [
          _SectionTitle('My Stuff', Icons.video_library_outlined),
          const SizedBox(height: 10),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            for (final f in const ['All', 'Continue', 'Liked', 'Watched', 'Downloads'])
              Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(f), selected: filter == f, onSelected: (_) => setState(() => filter = f))),
          ])),
          const SizedBox(height: 16),
          _StatStrip(items: c.library.length, watched: c.watched.length, liked: c.liked.length, downloads: Phase2Store.downloads.length),
          const SizedBox(height: 18),
          _SectionTitle('Playlists', Icons.queue_music_rounded),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: playlistController, decoration: const InputDecoration(hintText: 'New playlist name'))),
            const SizedBox(width: 8),
            IconButton.filled(onPressed: _createPlaylist, icon: const Icon(Icons.add)),
          ]),
          if (Phase2Store.playlists.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final entry in Phase2Store.playlists.entries)
              Card(child: ListTile(leading: const Icon(Icons.playlist_play), title: Text(entry.key), subtitle: Text('${entry.value.length} item(s)'), trailing: const Icon(Icons.chevron_right), onTap: () => _showPlaylist(context, entry.key))),
          ],
          const SizedBox(height: 18),
          _SectionTitle('$filter (${items.length})', Icons.filter_list_rounded),
          const SizedBox(height: 8),
          if (items.isEmpty) const _EmptyCard(title: 'Nothing here yet', subtitle: 'Your activity will appear in this section as you use the app.')
          else ...items.map((m) => _MediaRow(media: m, showDownload: true)),
        ],
      ),
    );
  }

  void _createPlaylist() {
    final name = playlistController.text.trim();
    if (name.isEmpty) return;
    Phase2Store.playlists.putIfAbsent(name, () => <String>[]);
    playlistController.clear();
    setState(() {});
  }

  void _showPlaylist(BuildContext context, String name) {
    final ids = Phase2Store.playlists[name] ?? <String>[];
    final media = AppController.instance.library.where((m) => ids.contains(m.id)).toList();
    showModalBottomSheet<void>(context: context, backgroundColor: const Color(0xFF151515), isScrollControlled: true, builder: (_) => SafeArea(child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(16), children: [Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)), const SizedBox(height: 12), if (media.isEmpty) const _EmptyCard(title: 'Playlist is empty', subtitle: 'Use the playlist button on a title to add it.') else ...media.map((m) => _MediaRow(media: m))])));
  }
}

class WatchStatsPanel extends StatelessWidget {
  const WatchStatsPanel({super.key});
  @override
  Widget build(BuildContext context) {
    final c = AppController.instance;
    final watched = c.watched;
    final hours = watched.length * 1.8;
    final genreCounts = <String, int>{};
    for (final m in watched) {
      for (final g in m.genres) {
        genreCounts[g] = (genreCounts[g] ?? 0) + 1;
      }
    }
    final sorted = genreCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final completed = c.library.where((m) => c.getPlaybackProgress(m.id) >= .99).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
      children: [
        const _HeroCard(icon: Icons.insights_rounded, title: 'Your viewing intelligence', subtitle: 'A private snapshot of how you use your personal streaming service.'),
        const SizedBox(height: 14),
        GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, childAspectRatio: 1.35, crossAxisSpacing: 10, mainAxisSpacing: 10, children: [
          _MetricCard(label: 'Titles watched', value: '${watched.length}', icon: Icons.visibility_rounded),
          _MetricCard(label: 'Hours watched', value: hours.toStringAsFixed(1), icon: Icons.schedule_rounded),
          _MetricCard(label: 'Completed', value: '$completed', icon: Icons.task_alt_rounded),
          _MetricCard(label: 'Library size', value: '${c.library.length}', icon: Icons.library_books_rounded),
        ]),
        const SizedBox(height: 20),
        _SectionTitle('Top genres', Icons.local_fire_department_rounded),
        const SizedBox(height: 10),
        if (sorted.isEmpty) const _EmptyCard(title: 'Not enough data', subtitle: 'Watch a few titles to unlock genre insights.')
        else ...sorted.take(8).map((e) => Padding(padding: const EdgeInsets.only(bottom: 9), child: _ProgressRow(label: e.key, value: e.value / math.max(1, sorted.first.value), count: e.value))),
        const SizedBox(height: 20),
        _SectionTitle('Milestones', Icons.emoji_events_rounded),
        const SizedBox(height: 10),
        _Achievement(title: 'First watch', unlocked: watched.isNotEmpty, icon: Icons.play_arrow_rounded),
        _Achievement(title: 'Five titles watched', unlocked: watched.length >= 5, icon: Icons.looks_5_rounded),
        _Achievement(title: 'Library builder', unlocked: c.library.length >= 10, icon: Icons.library_add_rounded),
        _Achievement(title: 'Completionist', unlocked: completed >= 10, icon: Icons.workspace_premium_rounded),
      ],
    );
  }
}

class Phase2SettingsPanel extends StatefulWidget {
  const Phase2SettingsPanel({super.key});
  @override
  State<Phase2SettingsPanel> createState() => _Phase2SettingsPanelState();
}

class _Phase2SettingsPanelState extends State<Phase2SettingsPanel> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
      children: [
        _settingsGroup('Playback', [
          _settings('autoplay', Icons.skip_next_rounded, 'Autoplay next episode', 'Start the next episode automatically.'),
          _settings('skipIntro', Icons.fast_forward_rounded, 'Skip intro', 'Offer an instant intro skip action.'),
          _settings('skipRecap', Icons.redo_rounded, 'Skip recap', 'Skip episode recaps when available.'),
          _settings('pip', Icons.picture_in_picture_alt_rounded, 'Picture in picture', 'Keep video visible while browsing.'),
        ]),
        _settingsGroup('Downloads & data', [
          _settings('dataSaver', Icons.data_saver_on_rounded, 'Data saver', 'Reduce image and streaming data usage.'),
          _settings('wifiOnly', Icons.wifi_rounded, 'Wi-Fi only downloads', 'Prevent downloads over cellular data.'),
          _settings('sync', Icons.cloud_sync_rounded, 'Cloud sync', 'Keep preferences and progress synchronized.'),
        ]),
        _settingsGroup('Privacy & family', [
          _settings('kidsMode', Icons.child_care_rounded, 'Kids mode', 'Limit discovery to family-friendly titles.'),
          _settings('pinProtection', Icons.lock_outline_rounded, 'PIN protection', 'Require a PIN before opening protected areas.'),
          _settings('spoilers', Icons.visibility_off_rounded, 'Show spoilers', 'Allow spoiler-sensitive metadata to appear.'),
          _settings('notifications', Icons.notifications_active_outlined, 'Notifications', 'Activity and recommendation alerts.'),
        ]),
        _settingsGroup('Accessibility', [
          _settings('haptic', Icons.vibration_rounded, 'Haptic feedback', 'Use subtle feedback for controls.'),
        ]),
        const SizedBox(height: 10),
        Card(child: ListTile(leading: const Icon(Icons.download_rounded), title: const Text('Download manager'), subtitle: Text('${Phase2Store.downloads.length} title(s) queued or saved'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DownloadManagerScreen())))),
        Card(child: ListTile(leading: const Icon(Icons.security_rounded), title: const Text('Privacy & security center'), subtitle: const Text('Sessions, data export, sign-in protection'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyCenterScreen())))),
      ],
    );
  }

  Widget _settings(String key, IconData icon, String title, String subtitle) {
    return SwitchListTile.adaptive(
      value: Phase2Store.getBool(key),
      onChanged: (v) => setState(() => Phase2Store.setBool(key, v)),
      secondary: Icon(icon), title: Text(title), subtitle: Text(subtitle),
    );
  }

  Widget _settingsGroup(String title, List<Widget> children) => Card(margin: const EdgeInsets.only(bottom: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.fromLTRB(16, 15, 16, 3), child: Text(title.toUpperCase(), style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1))), ...children]));
}

class DownloadManagerScreen extends StatefulWidget {
  const DownloadManagerScreen({super.key});
  @override
  State<DownloadManagerScreen> createState() => _DownloadManagerScreenState();
}
class _DownloadManagerScreenState extends State<DownloadManagerScreen> {
  @override
  Widget build(BuildContext context) {
    final c = AppController.instance;
    return Scaffold(appBar: AppBar(title: const Text('Download Manager')), body: ListView(padding: const EdgeInsets.all(16), children: [
      const _HeroCard(icon: Icons.download_done_rounded, title: 'Offline library', subtitle: 'Choose titles to keep available for offline viewing. The current build tracks the download state locally.'),
      const SizedBox(height: 14),
      if (c.library.isEmpty) const _EmptyCard(title: 'No titles available', subtitle: 'Import a movie or show first.')
      else ...c.library.map((m) {
        final saved = Phase2Store.downloads.contains(m.id);
        return Card(child: ListTile(leading: _Poster(media: m, width: 48, height: 64), title: Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis), subtitle: Text(saved ? 'Available offline' : 'Not downloaded'), trailing: IconButton(icon: Icon(saved ? Icons.delete_outline : Icons.download_outlined), onPressed: () { setState(() { if (saved) {
          Phase2Store.downloads.remove(m.id);
        } else {
          Phase2Store.downloads.add(m.id);
        } }); })));
      }),
    ]));
  }
}

class PrivacyCenterScreen extends StatefulWidget {
  const PrivacyCenterScreen({super.key});
  @override
  State<PrivacyCenterScreen> createState() => _PrivacyCenterScreenState();
}
class _PrivacyCenterScreenState extends State<PrivacyCenterScreen> {
  @override
  Widget build(BuildContext context) {
    final c = AppController.instance;
    return Scaffold(appBar: AppBar(title: const Text('Privacy & Security')), body: ListView(padding: const EdgeInsets.all(16), children: [
      const _HeroCard(icon: Icons.shield_rounded, title: 'Your account, your data', subtitle: 'These controls give you a single place to review privacy-sensitive behavior.'),
      const SizedBox(height: 14),
      Card(child: Column(children: [
        ListTile(leading: const Icon(Icons.person_outline), title: const Text('Active profile'), subtitle: Text(c.currentProfile?.name ?? 'None selected')),
        const Divider(height: 1),
        ListTile(leading: const Icon(Icons.devices_rounded), title: const Text('Backend session'), subtitle: Text(c.isBackendAuthenticated ? 'Authenticated' : 'Local/offline session')),
        const Divider(height: 1),
        SwitchListTile.adaptive(value: Phase2Store.getBool('sync'), onChanged: (v) => setState(() => Phase2Store.setBool('sync', v)), title: const Text('Cloud synchronization'), subtitle: const Text('Sync progress and preferences when backend access is available.')),
        SwitchListTile.adaptive(value: Phase2Store.getBool('pinProtection'), onChanged: (v) => setState(() => Phase2Store.setBool('pinProtection', v)), title: const Text('Protected areas'), subtitle: const Text('Use your account/profile security flow before protected features.')),
      ])),
      const SizedBox(height: 14),
      FilledButton.icon(onPressed: () => _confirmClearHistory(context), icon: const Icon(Icons.delete_sweep_rounded), label: const Text('CLEAR LOCAL WATCH HISTORY')),
      const SizedBox(height: 8),
      OutlinedButton.icon(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A data export request has been prepared. Connect a persistent backend export endpoint to make it downloadable.'))), icon: const Icon(Icons.file_download_outlined), label: const Text('EXPORT MY DATA')),
    ]));
  }
  void _confirmClearHistory(BuildContext context) {
    showDialog<void>(context: context, builder: (_) => AlertDialog(title: const Text('Clear watch history?'), content: const Text('This removes local watched and playback-progress data from this app session.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')), FilledButton(onPressed: () { final c = AppController.instance; c.watched.clear(); c.playbackProgress.clear(); Navigator.pop(context); setState(() {}); }, child: const Text('CLEAR'))]));
  }
}

class _MediaRow extends StatelessWidget {
  final MediaItem media;
  final bool showDownload;
  const _MediaRow({required this.media, this.showDownload = false});
  @override
  Widget build(BuildContext context) {
    final c = AppController.instance;
    final progress = c.getPlaybackProgress(media.id);
    return Card(margin: const EdgeInsets.only(bottom: 9), child: ListTile(
      contentPadding: const EdgeInsets.all(8),
      leading: _Poster(media: media, width: 58, height: 78),
      title: Text(media.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 4),
        Text([if (media.releaseYear != null) '${media.releaseYear}', media.type].join(' • ')),
        if (media.genres.isNotEmpty) Text(media.genres.take(3).join(' • '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        if (progress > 0) ...[const SizedBox(height: 7), LinearProgressIndicator(value: progress)],
      ]),
      trailing: PopupMenuButton<String>(onSelected: (v) => _action(context, v), itemBuilder: (_) => [const PopupMenuItem(value: 'play', child: Text('Play')), const PopupMenuItem(value: 'playlist', child: Text('Add to playlist')), if (showDownload) const PopupMenuItem(value: 'download', child: Text('Download'))]),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MediaDetailsScreen(media: media))),
    ));
  }
  void _action(BuildContext context, String action) {
    if (action == 'play') { Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(media: media))); return; }
    if (action == 'download') { Phase2Store.downloads.add(media.id); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${media.title} added to downloads.'))); return; }
    if (action == 'playlist') {
      if (Phase2Store.playlists.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Create a playlist in My Stuff first.'))); return; }
      showModalBottomSheet<void>(context: context, backgroundColor: const Color(0xFF151515), builder: (_) => SafeArea(child: ListView(shrinkWrap: true, children: Phase2Store.playlists.keys.map((name) => ListTile(title: Text(name), leading: const Icon(Icons.playlist_add), onTap: () { Phase2Store.playlists[name]!.add(media.id); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added ${media.title} to $name.'))); })).toList())));
    }
  }
}

class _Poster extends StatelessWidget {
  final MediaItem media; final double width; final double height;
  const _Poster({required this.media, required this.width, required this.height});
  @override
  Widget build(BuildContext context) => ClipRRect(borderRadius: BorderRadius.circular(10), child: media.imageUrl != null && media.imageUrl!.isNotEmpty ? Image.network(media.imageUrl!, width: width, height: height, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallback()) : _fallback());
  Widget _fallback() => Container(width: width, height: height, color: const Color(0xFF222222), child: const Icon(Icons.movie_outlined, color: Colors.white38));
}

class _HeroCard extends StatelessWidget {
  final IconData icon; final String title; final String subtitle;
  const _HeroCard({required this.icon, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.red.withValues(alpha: .14), borderRadius: BorderRadius.circular(15)), child: Icon(icon, color: Colors.redAccent)), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text(subtitle, style: const TextStyle(color: Colors.white60, height: 1.35))]))])));
}

class _EmptyCard extends StatelessWidget {
  final String title; final String subtitle;
  const _EmptyCard({required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [const Icon(Icons.inbox_outlined, size: 36, color: Colors.white30), const SizedBox(height: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54))])));
}

class _MetricCard extends StatelessWidget {
  final String label; final String value; final IconData icon;
  const _MetricCard({required this.label, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: Colors.redAccent), const Spacer(), Text(value, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)), Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12))])));
}

class _StatStrip extends StatelessWidget {
  final int items, watched, liked, downloads;
  const _StatStrip({required this.items, required this.watched, required this.liked, required this.downloads});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_mini('Library', items), _mini('Watched', watched), _mini('Liked', liked), _mini('Offline', downloads)])));
  Widget _mini(String label, int value) => Column(children: [Text('$value', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)), const SizedBox(height: 2), Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11))]);
}

class _ProgressRow extends StatelessWidget {
  final String label; final double value; final int count;
  const _ProgressRow({required this.label, required this.value, required this.count});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))), Text('$count', style: const TextStyle(color: Colors.white54))]), const SizedBox(height: 5), ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(value: value.clamp(0, 1).toDouble(), minHeight: 7))]);
}

class _Achievement extends StatelessWidget {
  final String title; final bool unlocked; final IconData icon;
  const _Achievement({required this.title, required this.unlocked, required this.icon});
  @override
  Widget build(BuildContext context) => Card(child: ListTile(leading: Icon(icon, color: unlocked ? Colors.amber : Colors.white24), title: Text(title), trailing: Icon(unlocked ? Icons.check_circle : Icons.lock_outline, color: unlocked ? Colors.greenAccent : Colors.white24)));
}

class _QuickAction extends StatelessWidget {
  final IconData icon; final String title; final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.title, required this.onTap});
  @override
  Widget build(BuildContext context) => FilledButton.tonalIcon(onPressed: onTap, icon: Icon(icon), label: Text(title));
}

class _SectionTitle extends StatelessWidget {
  final String title; final IconData icon;
  const _SectionTitle(this.title, this.icon);
  @override
  Widget build(BuildContext context) => Row(children: [Icon(icon, size: 19, color: Colors.redAccent), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))]);
}
