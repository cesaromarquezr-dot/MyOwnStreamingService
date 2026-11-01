import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_core.dart';
import 'channel_center.dart';
import 'coming_soon_release_screen.dart';
import 'details.dart';
import 'franchise_universe_browse_hub.dart';
import 'media_extras_library.dart';
import 'media_universe.dart';
import 'music.dart';
import 'music_video_search_screen.dart';
import 'my_tv.dart';
import 'power_performance_screen.dart';
import 'perfect_streaming_experience.dart';
import 'profiles_permissions_hub.dart';
import 'release_order_timeline.dart';
import 'smart_search.dart';
import 'streaming_intelligence_hub.dart';
import 'weekly_top10.dart';

/// One entry point for the strongest, service-inspired discovery features.
/// Provider-specific services remain catalog links; the app never claims that
/// it owns or can play a title just because an external catalog lists it.
class StreamingServicesHubScreen extends StatelessWidget {
  const StreamingServicesHubScreen({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppController.instance;
    final profile = controller.currentProfile;
    final library = controller.library
        .where((item) => profile == null || item.isAccessibleTo(profile))
        .toList(growable: false);
    final shows = library.where((item) => item.isSeries).length;
    final musicCount = library.where(_isMusic).length;
    final videoCount = library.length >= shows + musicCount
        ? library.length - shows - musicCount
        : 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Streaming Services Hub')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _hero(context, profile?.name ?? 'Current profile', library.length,
              videoCount, shows, musicCount),
          const SizedBox(height: 20),
          _heading(context, 'Discover anything',
              'Search across your library and available metadata.'),
          _featureTile(
            context,
            icon: Icons.manage_search_rounded,
            title: 'Universal Smart Search',
            subtitle:
                'Songs, lyrics, albums, artists, actors, movies, shows and soundtrack connections.',
            onTap: () => _open(context, const SmartSearchScreen()),
          ),
          _featureTile(
            context,
            icon: Icons.hub_rounded,
            title: 'Connected Entertainment & X-Ray',
            subtitle:
                'People, credits, cinematic universes, relationships, watch orders and live-position X-Ray.',
            onTap: () => _open(context, const StreamingIntelligenceHubScreen()),
          ),
          _featureTile(
            context,
            icon: Icons.leaderboard_rounded,
            title: 'Your Library Top 10',
            subtitle:
                'Personalized rankings for owned movies, shows, albums, songs and credited people.',
            onTap: () => _open(context, const WeeklyTop10RankingsScreen()),
          ),
          _featureTile(
            context,
            icon: Icons.sort_by_alpha_rounded,
            title: 'Release-order timeline',
            subtitle:
                'Browse your movies, shows and albums by release date, newest-first or oldest-first.',
            onTap: () => _open(context, const ReleaseOrderTimelineScreen()),
          ),
          const SizedBox(height: 20),
          _heading(context, 'Browse by experience',
              'Keep movies, shows, music, live programming and bonus content connected.'),
          _featureTile(
            context,
            icon: Icons.calendar_month_rounded,
            title: 'Anime, episodes & release calendar',
            subtitle:
                'Open upcoming episode dates first, including anime when the metadata provider supplies them; switch to other release categories as needed.',
            onTap: () => _open(context,
                const ComingSoonReleaseScreen(initialFilter: 'Episodes')),
          ),
          _featureTile(
            context,
            icon: Icons.movie_filter_rounded,
            title: 'Franchises & cinematic universes',
            subtitle:
                'Connected titles, timelines, watch order and known continuity relationships.',
            onTap: () => _open(
              context,
              const FranchiseUniverseBrowseHubScreen(
                mode: FranchiseUniverseBrowseMode.franchises,
              ),
            ),
          ),
          _featureTile(
            context,
            icon: Icons.sports_score_rounded,
            title: 'Live sports & events',
            subtitle:
                'Open configured live channels and your TV schedule. Event access depends on your connected provider and regional rights.',
            onTap: () => _open(context, const MyTvScreen()),
          ),
          _featureTile(
            context,
            icon: Icons.tv_rounded,
            title: 'My TV & program schedule',
            subtitle:
                'Your profile-specific TV experience and configured program listings.',
            onTap: () => _open(context, const MyTvScreen()),
          ),
          _featureTile(
            context,
            icon: Icons.video_library_outlined,
            title: 'Curated channels',
            subtitle:
                'Create themed channels from movies and shows in your personal library.',
            onTap: () => _open(context, const ChannelCenterScreen()),
          ),
          _featureTile(
            context,
            icon: Icons.queue_music_rounded,
            title: 'Music & soundtrack discovery',
            subtitle:
                'Open your music library, artist/album navigation, collaborations and movie soundtrack search.',
            onTap: () => _open(context, const MusicScreen()),
          ),
          _featureTile(
            context,
            icon: Icons.smart_display_outlined,
            title: 'Music videos & short-form discovery',
            subtitle:
                'Find official music-video candidates for songs imported into your music library.',
            onTap: () => _open(context, const MusicVideoDiscoveryScreen()),
          ),
          _featureTile(
            context,
            icon: Icons.auto_awesome_motion_rounded,
            title: 'Bonus scenes & short-form extras',
            subtitle:
                'Imported trailers, deleted scenes, featurettes, commentaries and alternate cuts.',
            onTap: () => _open(context, const MediaExtrasLibraryScreen()),
          ),
          _featureTile(
            context,
            icon: Icons.public_rounded,
            title: 'Free & ad-supported discovery',
            subtitle:
                'Browse local playable items and open official free-streaming destinations available in your region.',
            onTap: () => _open(context, const FreeStreamingGuideScreen()),
          ),
          const SizedBox(height: 20),
          _heading(context, 'Your household and playback',
              'Personalize each profile and control resource use.'),
          _featureTile(
            context,
            icon: Icons.family_restroom_rounded,
            title: 'Profiles & parental controls',
            subtitle:
                'Profile preferences, maturity settings and permission controls.',
            onTap: () =>
                _open(context, const ProfilesAndPermissionsHubScreen()),
          ),
          _featureTile(
            context,
            icon: Icons.tune_rounded,
            title: 'Personalized discovery preferences',
            subtitle:
                'Control personalized discovery, navigation, autoplay and playback continuity by profile.',
            onTap: () =>
                _open(context, const PerfectStreamingExperienceScreen()),
          ),
          _featureTile(
            context,
            icon: Icons.energy_savings_leaf_rounded,
            title: 'Playback quality & Energy Saver',
            subtitle:
                'Eco mode, preview behavior, data saver, reduced motion and supported playback options.',
            onTap: () => _open(context, const PowerPerformanceScreen()),
          ),
          _featureTile(
            context,
            icon: Icons.account_tree_outlined,
            title: 'Media universe & collection graph',
            subtitle:
                'Explore the metadata connections already attached to your accessible library.',
            onTap: () => _open(context, const MediaUniverseScreen()),
          ),
          const SizedBox(height: 12),
          const Text(
            'Availability, prices, provider subscriptions, sports rights and stream quality vary by country, plan, title and device. External catalog matches are not proof of a playable stream. This hub only opens official destinations or capabilities supported by the configured provider and your own media sources.',
            style: TextStyle(color: Colors.white54, height: 1.45, fontSize: 12),
          ),
        ],
      ),
    );
  }

  static bool _isMusic(MediaItem item) {
    final type = item.type.toLowerCase();
    return type.contains('music') ||
        type.contains('album') ||
        type.contains('song') ||
        type.contains('track') ||
        type.contains('audio');
  }

  Widget _hero(BuildContext context, String profile, int total, int videos,
      int shows, int music) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xff272044), Color(0xff101721)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.live_tv_rounded, size: 34),
        const SizedBox(height: 10),
        Text('The best of streaming, connected.',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                )),
        const SizedBox(height: 6),
        Text(
            'One home for $profile, across your own library and verified discovery sources.',
            style: const TextStyle(color: Colors.white70, height: 1.4)),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _metric('Library', total, Icons.video_library_outlined),
          _metric('Movies / video', videos, Icons.movie_outlined),
          _metric('Shows', shows, Icons.live_tv_outlined),
          _metric('Music', music, Icons.music_note_rounded),
        ]),
      ]),
    );
  }

  Widget _metric(String label, int value, IconData icon) => Chip(
        avatar: Icon(icon, size: 16),
        label: Text('$label · $value'),
        side: BorderSide(color: Colors.white.withValues(alpha: .08)),
        backgroundColor: Colors.white.withValues(alpha: .07),
      );

  Widget _heading(BuildContext context, String title, String subtitle) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(color: Colors.white60, height: 1.4)),
        ]),
      );

  Widget _featureTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) =>
      Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Icon(icon, size: 27),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      );
}

/// Search for music-video candidates for tracks that actually belong to the
/// selected profile's imported music library. Results use the existing
/// backend-authorized YouTube search; catalog-only songs are not misrepresented
/// as owned tracks.
class MusicVideoDiscoveryScreen extends StatefulWidget {
  const MusicVideoDiscoveryScreen({super.key});

  @override
  State<MusicVideoDiscoveryScreen> createState() =>
      _MusicVideoDiscoveryScreenState();
}

class _MusicVideoDiscoveryScreenState extends State<MusicVideoDiscoveryScreen> {
  final TextEditingController _search = TextEditingController();
  List<MusicTrack> _tracks = <MusicTrack>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  Future<void> _loadTracks() async {
    try {
      await MusicLibraryStore.instance.initializeForProfile(
        AppController.instance.currentProfile?.id,
      );
    } catch (_) {
      // An offline music source should leave this screen usable with an empty state.
    }
    if (!mounted) return;
    setState(() {
      _tracks = MusicLibraryStore.instance.tracks
          .where((track) => !track.catalogOnly)
          .toList()
        ..sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      _loading = false;
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final tracks = _tracks
        .where((track) =>
            query.isEmpty ||
            '${track.title} ${track.artist} ${track.album}'
                .toLowerCase()
                .contains(query))
        .toList(growable: false);
    return Scaffold(
      appBar: AppBar(title: const Text('Music Videos & Short-Form')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text(
            'Choose an imported song to search for an official music video. Search results are candidates from the configured provider; ownership and playback still depend on the actual source.',
            style: TextStyle(color: Colors.white70, height: 1.4)),
        const SizedBox(height: 12),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Filter imported songs',
            prefixIcon: Icon(Icons.search_rounded),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Center(
              child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          )),
        if (!_loading && _tracks.isEmpty)
          const Card(
              child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                      'No imported songs were found for this profile. Import music or connect your music server first.'))),
        if (!_loading && _tracks.isNotEmpty && tracks.isEmpty)
          const Card(
              child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No imported songs match this search.'))),
        ...tracks.take(150).map((track) => Card(
              child: ListTile(
                leading: track.artworkUrl?.trim().isNotEmpty == true
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          track.artworkUrl!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.music_note_rounded),
                        ))
                    : const Icon(Icons.music_note_rounded),
                title: Text(track.title),
                subtitle: Text(
                    '${track.artist}${track.album.trim().isEmpty ? '' : ' · ${track.album}'}'),
                trailing: const Icon(Icons.smart_display_outlined),
                onTap: () =>
                    Navigator.of(context).push<void>(MaterialPageRoute<void>(
                  builder: (_) => MusicVideoSearchScreen(
                      title: track.title, artist: track.artist),
                )),
              ),
            )),
        const SizedBox(height: 8),
        const Text(
            'Searches are initiated only when you select a song, which helps reduce background requests and respects Eco mode.',
            style: TextStyle(color: Colors.white54, height: 1.4, fontSize: 12)),
      ]),
    );
  }
}

/// A legal/free discovery page. This doesn't ingest third-party video or
/// guarantee regional catalogs; it links out to official destinations and
/// keeps the user's own available media distinct from external services.
class FreeStreamingGuideScreen extends StatelessWidget {
  const FreeStreamingGuideScreen({super.key});

  static const List<(String, String, String, IconData)> _providers =
      <(String, String, String, IconData)>[
    (
      'Tubi',
      'Free movies and TV with ads; catalog availability varies by country.',
      'https://tubitv.com/',
      Icons.movie_outlined
    ),
    (
      'Pluto TV',
      'Free channel-style TV and on-demand selections where available.',
      'https://pluto.tv/',
      Icons.live_tv_rounded
    ),
    (
      'Plex',
      'Free, ad-supported movies, TV and live channels in supported markets.',
      'https://watch.plex.tv/',
      Icons.play_circle_outline_rounded
    ),
    (
      'Prime Video',
      'Browse any free or ad-supported titles currently offered to your account; a Prime subscription may be required for some content.',
      'https://www.primevideo.com/',
      Icons.play_circle_outline_rounded
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final profile = AppController.instance.currentProfile;
    final playable = AppController.instance.library
        .where((item) =>
            (profile == null || item.isAccessibleTo(profile)) &&
            (item.playbackUrl?.trim().isNotEmpty ?? false))
        .toList(growable: false);
    return Scaffold(
      appBar: AppBar(title: const Text('Free & Ad-Supported')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text(
            'Free catalogs, public channels and your own playable library in one place. External provider availability and ad tiers vary by region and change over time.',
            style: TextStyle(color: Colors.white70, height: 1.45)),
        const SizedBox(height: 14),
        Text('Official destinations',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        ..._providers.map((provider) => Card(
              child: ListTile(
                leading: Icon(provider.$4, size: 28),
                title: Text(provider.$1,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(provider.$2),
                trailing: const Icon(Icons.open_in_new_rounded),
                onTap: () async {
                  final uri = Uri.parse(provider.$3);
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
              ),
            )),
        const SizedBox(height: 18),
        Text('Playable in your library',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(
            '${playable.length} item(s) have a playback URL in the current profile-accessible library.',
            style: const TextStyle(color: Colors.white60)),
        if (playable.isEmpty)
          const Card(
              child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text(
                      'No local playback URLs are configured yet. Import files or connect your authorized media server.'))),
        ...playable.take(20).map((item) => Card(
              child: ListTile(
                leading: const Icon(Icons.play_circle_outline_rounded),
                title: Text(item.title),
                subtitle: Text(item.type),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                        builder: (_) => MediaDetailsScreen(media: item))),
              ),
            )),
        const SizedBox(height: 10),
        const Text(
            'Free listing does not mean every title can be played in this app. Only media with an accessible playback URL is counted as locally playable; provider links open the provider’s official site.',
            style: TextStyle(color: Colors.white54, height: 1.4, fontSize: 12)),
      ]),
    );
  }
}
