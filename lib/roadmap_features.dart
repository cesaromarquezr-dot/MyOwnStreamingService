import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_core.dart';
import 'feature_center.dart';
import 'ultimate_features.dart';
import 'device_features.dart';
import 'remote_access.dart';
import 'main.dart' show CustomizeHomeScreen;
import 'details.dart';

class RoadmapFeaturesScreen extends StatelessWidget {
  const RoadmapFeaturesScreen({super.key});

  @override
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
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('34-Feature Roadmap')),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: features.length,
        itemBuilder: (context, index) {
          final f = features[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: CircleAvatar(child: Text('${f.number}')),
              title: Text(f.title, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(f.description),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => f.builder(context))),
            ),
          );
        },
      ),
    );
  }
}

class _RoadmapFeature {
  final int number;
  final String title;
  final IconData icon;
  final String description;
  final Widget Function(BuildContext) builder;
  _RoadmapFeature(this.number, this.title, this.icon, this.description, this.builder);
}

List<MediaItem> _library() => AppController.instance.library;

class AskMyLibraryScreen extends StatefulWidget {
  const AskMyLibraryScreen({super.key});
  @override State<AskMyLibraryScreen> createState() => _AskMyLibraryScreenState();
}
class _AskMyLibraryScreenState extends State<AskMyLibraryScreen> {
  final query = TextEditingController();
  List<MediaItem> results = <MediaItem>[];
  String explanation = 'Ask about titles, actors, genres, years, watched state or your next watch.';

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
    appBar: AppBar(title: const Text('Ask My Library')),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        TextField(controller: query, onSubmitted: (_) => ask(), decoration: InputDecoration(hintText: 'e.g. unwatched action movies from the 2000s', suffixIcon: IconButton(onPressed: ask, icon: const Icon(Icons.search)))),
        const SizedBox(height: 12),
        Align(alignment: Alignment.centerLeft, child: Text(explanation, style: const TextStyle(color: Colors.white70))),
        const SizedBox(height: 12),
        Expanded(child: ListView.builder(itemCount: results.length, itemBuilder: (_, i) {
          final m = results[i];
          return Card(child: ListTile(title: Text(m.title), subtitle: Text('${m.releaseYear ?? ''} • ${m.type}'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MediaDetailsScreen(media: m)))));
        })),
      ]),
    ),
  );
}

class SmartCollectionsScreen extends StatefulWidget { const SmartCollectionsScreen({super.key}); @override State<SmartCollectionsScreen> createState() => _SmartCollectionsScreenState(); }
class _SmartCollectionsScreenState extends State<SmartCollectionsScreen> {
  String rule = 'Unwatched';
  List<MediaItem> get items { final l = _library(); switch (rule) { case 'Watched': return l.where((m) => AppController.instance.isWatched(m.id)).toList(); case 'Movies': return l.where((m) => m.type == 'movie').toList(); case 'TV Shows': return l.where((m) => m.type != 'movie').toList(); case 'Liked': return l.where((m) => AppController.instance.liked.any((x) => x.id == m.id)).toList(); default: return l.where((m) => !AppController.instance.isWatched(m.id)).toList(); } }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Smart Collections')), body: Padding(padding: const EdgeInsets.all(16), child: Column(children: [DropdownButtonFormField<String>(initialValue: rule, items: const ['Unwatched','Watched','Movies','TV Shows','Liked'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) => setState(() => rule = v!)), const SizedBox(height: 12), Align(alignment: Alignment.centerLeft, child: Text('${items.length} titles match this live rule')), const SizedBox(height: 12), Expanded(child: ListView(children: items.map((m) => ListTile(leading: const Icon(Icons.movie_outlined), title: Text(m.title), subtitle: Text('${m.releaseYear ?? ''} • ${m.type}'))).toList()))])));
}

class RecommendationCompetitionScreen extends StatelessWidget {
  const RecommendationCompetitionScreen({super.key});
  @override Widget build(BuildContext context) {
    final recs = [...AppController.instance.groupRecommendations];
    recs.sort((a, b) => _yes(b).compareTo(_yes(a)));
    return Scaffold(appBar: AppBar(title: const Text('Recommendation Competition')), body: ListView(padding: const EdgeInsets.all(16), children: [
      if (recs.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('No active recommendations yet.'))),
      ...recs.asMap().entries.map((entry) { final r = entry.value; return Card(child: ListTile(leading: CircleAvatar(child: Text('${entry.key + 1}')), title: Text(r['title']?.toString() ?? 'Untitled'), subtitle: Text('YES ${r['yesVotes'] ?? 0} • NO ${r['noVotes'] ?? 0}'), trailing: entry.key == 0 ? const Icon(Icons.emoji_events_rounded) : null)); }),
    ]));
  }
  static int _yes(Map<String, dynamic> r) => int.tryParse(r['yesVotes']?.toString() ?? '0') ?? 0;
}

class WatchHistoryTimelineScreen extends StatelessWidget {
  const WatchHistoryTimelineScreen({super.key});
  @override Widget build(BuildContext context) { final watched = AppController.instance.watched; return Scaffold(appBar: AppBar(title: const Text('Watch History')), body: watched.isEmpty ? const Center(child: Text('Nothing watched yet.')) : ListView.separated(padding: const EdgeInsets.all(16), itemCount: watched.length, separatorBuilder: (_, __) => const Divider(), itemBuilder: (_, i) { final m = watched[watched.length - 1 - i]; return ListTile(leading: CircleAvatar(child: Text('${i + 1}')), title: Text(m.title), subtitle: Text('${m.releaseYear ?? ''} • Watched by ${AppController.instance.currentProfile?.name ?? 'profile'}')); })); }
}

class MusicModeScreen extends StatelessWidget {
  const MusicModeScreen({super.key});
  @override Widget build(BuildContext context) { final grouped = <String, List<String>>{}; for (final m in _library()) { for (final item in m.music) { grouped.putIfAbsent(m.title, () => <String>[]).add(item); } } return Scaffold(appBar: AppBar(title: const Text('Music Mode')), body: grouped.isEmpty ? const Center(child: Text('No music metadata has been imported yet.')) : ListView(padding: const EdgeInsets.all(16), children: grouped.entries.expand((e) => [Padding(padding: const EdgeInsets.only(top: 10, bottom: 4), child: Text(e.key, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))), ...e.value.map((x) => ListTile(leading: const Icon(Icons.music_note_rounded), title: Text(x)))]).toList())); }
}

class TrailerTheaterScreen extends StatelessWidget {
  const TrailerTheaterScreen({super.key});
  @override Widget build(BuildContext context) { final media = _library().where((m) => (m.trailerUrl ?? '').trim().isNotEmpty).toList(); return Scaffold(appBar: AppBar(title: const Text('Trailer Theater')), body: media.isEmpty ? const Center(child: Text('No trailers are available.')) : GridView.builder(padding: const EdgeInsets.all(16), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: .75), itemCount: media.length, itemBuilder: (_, i) { final m = media[i]; return Card(child: InkWell(onTap: () async { final uri = Uri.tryParse(m.trailerUrl!); if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication); }, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: m.imageUrl == null ? const Center(child: Icon(Icons.movie_rounded, size: 48)) : Image.network(m.imageUrl!, fit: BoxFit.cover, width: double.infinity, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.movie_rounded, size: 48)))), Padding(padding: const EdgeInsets.all(10), child: Text(m.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),]))); })); }
}

class HomeWidgetsScreen extends StatefulWidget { const HomeWidgetsScreen({super.key}); @override State<HomeWidgetsScreen> createState() => _HomeWidgetsScreenState(); }
class _HomeWidgetsScreenState extends State<HomeWidgetsScreen> { final widgets = <String>['Continue Watching','Wishlist','Watch Streak','Recommendations','Recently Added','Storage']; @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Home Widgets')), body: ReorderableListView.builder(padding: const EdgeInsets.all(16), itemCount: widgets.length, onReorderItem: (a, b) => setState(() { final item = widgets.removeAt(a); widgets.insert(b, item); }), itemBuilder: (_, i) => Card(key: ValueKey(widgets[i]), child: ListTile(leading: const Icon(Icons.drag_handle_rounded), title: Text(widgets[i]), trailing: const Icon(Icons.widgets_rounded))))); }

class ProfileRelationshipsScreen extends StatefulWidget { const ProfileRelationshipsScreen({super.key}); @override State<ProfileRelationshipsScreen> createState() => _ProfileRelationshipsScreenState(); }
class _ProfileRelationshipsScreenState extends State<ProfileRelationshipsScreen> { final permissions = <String, bool>{'Watch': true, 'Recommend': true, 'Vote': true, 'Wishlist': true, 'Customize UI': true}; @override Widget build(BuildContext context) { final profiles = AppController.instance.currentAccount?.profiles ?? <Profile>[]; return Scaffold(appBar: AppBar(title: const Text('Profile Relationships')), body: ListView(padding: const EdgeInsets.all(16), children: profiles.map((p) => Card(child: ExpansionTile(title: Text(p.name), subtitle: const Text('Optional permissions'), children: permissions.keys.map((k) => SwitchListTile(title: Text(k), value: permissions[k]!, onChanged: (v) => setState(() => permissions[k] = v))).toList()))).toList())); } }

class ReactionGuideScreen extends StatelessWidget { const ReactionGuideScreen({super.key}); @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Reactions')), body: ListView(padding: const EdgeInsets.all(16), children: const [ListTile(leading: Text('❤️', style: TextStyle(fontSize: 26)), title: Text('Love it')), ListTile(leading: Text('🔥', style: TextStyle(fontSize: 26)), title: Text('Amazing')), ListTile(leading: Text('😂', style: TextStyle(fontSize: 26)), title: Text('Funny')), ListTile(leading: Text('😱', style: TextStyle(fontSize: 26)), title: Text('Scary')), ListTile(leading: Text('😭', style: TextStyle(fontSize: 26)), title: Text('Emotional')), ListTile(leading: Text('🤯', style: TextStyle(fontSize: 26)), title: Text('Mind-blowing'))])); }

class AdvancedLibrarySearchScreen extends StatefulWidget { const AdvancedLibrarySearchScreen({super.key}); @override State<AdvancedLibrarySearchScreen> createState() => _AdvancedLibrarySearchScreenState(); }
class _AdvancedLibrarySearchScreenState extends State<AdvancedLibrarySearchScreen> { final q = TextEditingController(); String type = 'All'; bool unwatched = false; List<MediaItem> results = <MediaItem>[]; void search() { final term = q.text.toLowerCase(); final all = _library(); setState(() => results = all.where((m) => (term.isEmpty || m.title.toLowerCase().contains(term) || m.genres.any((x) => x.toLowerCase().contains(term)) || m.tags.any((x) => x.toLowerCase().contains(term)) || m.actors.any((x) => x.toLowerCase().contains(term)) || m.directors.any((x) => x.toLowerCase().contains(term))) && (type == 'All' || (type == 'Movies' ? m.type == 'movie' : m.type != 'movie')) && (!unwatched || !AppController.instance.isWatched(m.id))).toList()); } @override void dispose() { q.dispose(); super.dispose(); } @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Advanced Search')), body: Padding(padding: const EdgeInsets.all(16), child: Column(children: [TextField(controller: q, onSubmitted: (_) => search(), decoration: const InputDecoration(labelText: 'Title, actor, director, genre or tag')), Row(children: [Expanded(child: DropdownButton<String>(value: type, isExpanded: true, items: const ['All','Movies','TV Shows'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) => setState(() => type = v!))), Switch(value: unwatched, onChanged: (v) => setState(() => unwatched = v)), const Text('Unwatched'), IconButton(onPressed: search, icon: const Icon(Icons.search))]), Expanded(child: ListView(children: results.map((m) => ListTile(title: Text(m.title), subtitle: Text('${m.releaseYear ?? ''} • ${m.type}'))).toList()))]))); }

class ActorFranchiseRoadmapScreen extends StatelessWidget { const ActorFranchiseRoadmapScreen({super.key}); @override Widget build(BuildContext context) { final actors = _library().expand((m) => m.actors).toSet().toList(); return Scaffold(appBar: AppBar(title: const Text('Actors & Franchises')), body: ListView(padding: const EdgeInsets.all(16), children: [const Text('Actors in your library', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), const SizedBox(height: 8), ...actors.map((a) => ListTile(leading: const Icon(Icons.person_outline_rounded), title: Text(a)))])); } }

class GroupWatchRoadmapScreen extends StatelessWidget { const GroupWatchRoadmapScreen({super.key}); @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Watch Together 2.0')), body: const Center(child: Text('Use Group Watch from the Home screen to start a synchronized party.'))); }

class RoadmapListLayoutScreen extends StatelessWidget {
  const RoadmapListLayoutScreen({super.key});
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('List Layouts')),
    body: ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 8,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => Card(
        child: ListTile(
          dense: i.isEven,
          leading: CircleAvatar(child: Text('${i + 1}')),
          title: Text(i.isEven ? 'Compact ListTile' : 'Spacious ListTile'),
          subtitle: const Text('Constrained inside a scrolling ListView to prevent overflow.'),
        ),
      ),
    ),
  );
}

class ArchitectureScreen extends StatelessWidget { const ArchitectureScreen({super.key}); @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Architecture')), body: ListView(padding: const EdgeInsets.all(20), children: const [Text('Account-scoped data', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), Text('Library, subscription and shared media belong to the account.', style: TextStyle(color: Colors.white70)), SizedBox(height: 20), Text('Profile-scoped experience', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), Text('Navigation, Home layout, Details layout, recommendations, history, wishlist and preferences belong to the selected profile.', style: TextStyle(color: Colors.white70)), SizedBox(height: 20), Text('Persistence boundary', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), Text('The local stores are isolated behind profile IDs so a Supabase repository can replace them without redesigning the UI.', style: TextStyle(color: Colors.white70))])); }
