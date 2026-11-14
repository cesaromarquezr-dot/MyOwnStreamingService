import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../app_core.dart';
import '../backend_api.dart';
import '../catalog_poster_image.dart';
import '../core/services/recent_playback_store.dart';
import '../core/services/playback_progress_sync_service.dart';
import '../details.dart';
import '../entertainment_extensions.dart';
import '../library_protection_center.dart';
import 'living_room_controls_screen.dart';
import '../group_watch.dart';
import '../media_health_screen.dart';
import '../music.dart';
import '../player.dart';
import '../presence/account_profile_presence_service.dart';
import '../smart_search.dart';
import '../widgets/account_profile_presence_strip.dart';
import '../widgets/media_status_badges.dart';
import 'entertainment_command_center_screen.dart';
import 'personal_discovery_lists_screen.dart';
import 'smart_media_import_center_screen.dart';
import 'offline_sync_center_screen.dart';

/// Profile-scoped activity hub for playback continuity, recent media,
/// recommendations, and catalog maintenance shortcuts.
class MyMediaHubScreen extends StatefulWidget {
  const MyMediaHubScreen({super.key});

  @override
  State<MyMediaHubScreen> createState() => _MyMediaHubScreenState();
}

class _MyMediaHubScreenState extends State<MyMediaHubScreen> {
  final AppController _app = AppController.instance;
  List<RecentPlaybackEntry> _recent = const <RecentPlaybackEntry>[];
  bool _loadingRecent = true;
  bool _presenceSnapshotReady = false;
  bool _syncingContinuity = false;
  bool _continuitySyncRequested = false;
  Timer? _continuitySyncTimer;
  Set<String> _knownPresenceActivity = <String>{};
  String? _observedProfileId;

  @override
  void initState() {
    super.initState();
    _app.addListener(_refresh);
    MusicLibraryStore.instance.addListener(_refresh);
    AccountProfilePresenceService.instance.addListener(_onPresenceChanged);
    final activeProfile = _app.currentProfile;
    _observedProfileId = activeProfile?.id;
    if (activeProfile != null) {
      AccountProfilePresenceService.instance.start(
        profileId: activeProfile.id,
        activityType: 'browsing',
        activityText: 'My Media Hub',
      );
    }
    unawaited(MusicLibraryStore.instance.initializeForProfile(
      _app.currentProfile?.id,
    ));
    unawaited(_loadRecent());
    if (_app.backendApi.isAuthenticated) {
      unawaited(_app.loadRecommendations());
    }
    _continuitySyncTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (mounted) unawaited(_loadRecent());
    });
  }

  @override
  void dispose() {
    _app.removeListener(_refresh);
    MusicLibraryStore.instance.removeListener(_refresh);
    AccountProfilePresenceService.instance.removeListener(_onPresenceChanged);
    _continuitySyncTimer?.cancel();
    super.dispose();
  }

  void _refresh() {
    final profileId = _app.currentProfile?.id;
    if (profileId != _observedProfileId) {
      _observedProfileId = profileId;
      _recent = const <RecentPlaybackEntry>[];
      _loadingRecent = true;
      unawaited(MusicLibraryStore.instance.initializeForProfile(profileId));
      unawaited(_loadRecent());
      if (profileId != null) {
        if (_app.backendApi.isAuthenticated) {
          unawaited(_app.loadRecommendations());
        }
        AccountProfilePresenceService.instance.start(
          profileId: profileId,
          activityType: 'browsing',
          activityText: 'My Media Hub',
        );
      }
    }
    if (mounted) setState(() {});
  }

  void _onPresenceChanged() {
    final active = AccountProfilePresenceService.instance.otherActiveProfiles;
    final next = active
        .map((profile) =>
            '${profile.profileId}|${profile.activityType ?? ""}|${profile.activityText ?? ""}')
        .toSet();
    if (!_presenceSnapshotReady) {
      _presenceSnapshotReady = true;
      _knownPresenceActivity = next;
      if (mounted) setState(() {});
      return;
    }
    final newlyActive = next.difference(_knownPresenceActivity);
    _knownPresenceActivity = next;
    if (!mounted) return;
    setState(() {});
    for (final profile in active) {
      final key =
          '${profile.profileId}|${profile.activityType ?? ""}|${profile.activityText ?? ""}';
      if (!newlyActive.contains(key)) continue;
      final type = profile.activityType;
      if (type != 'watching' && type != 'listening') continue;
      final activity = (profile.activityText?.trim().isNotEmpty == true)
          ? profile.activityText!.trim()
          : (type == 'watching' ? 'a movie or show' : 'music');
      final verb = type == 'watching' ? 'watching in' : 'listening in';
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('${profile.name} started $verb $activity')),
      );
    }
  }

  Future<void> _loadRecent() async {
    if (_syncingContinuity) {
      _continuitySyncRequested = true;
      return;
    }
    final profileId = _app.currentProfile?.id;
    if (profileId == null || profileId.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _recent = const <RecentPlaybackEntry>[];
          _loadingRecent = false;
        });
      }
      return;
    }
    _syncingContinuity = true;
    try {
      if (_app.backendApi.isAuthenticated) {
        final progress = await PlaybackProgressSyncService.synchronizeProfile(
          api: _app.backendApi,
          profileId: profileId,
          currentProgress: Map<String, double>.from(_app.playbackProgress),
        );
        if (!mounted || _app.currentProfile?.id != profileId) return;
        _app.applyPlaybackProgressSnapshot(progress);
        await RecentPlaybackStore.syncWithBackend(
          api: _app.backendApi,
          profileId: profileId,
        );
      }
    } catch (_) {
      // Local progress/history remains available when account sync is offline.
    } finally {
      _syncingContinuity = false;
      if (_continuitySyncRequested && mounted) {
        _continuitySyncRequested = false;
        unawaited(_loadRecent());
      }
    }
    final entries = await RecentPlaybackStore.load(profileId);
    if (!mounted || _app.currentProfile?.id != profileId) return;
    setState(() {
      _recent = entries;
      _loadingRecent = false;
    });
  }

  List<MediaItem> get _library => _app.library
      .where((media) => media.isAccessibleTo(_app.currentProfile))
      .toList(growable: false);

  List<MediaItem> get _continueWatching {
    final results = _library.where((media) {
      final progress = _app.getPlaybackProgress(media.id);
      return progress > 0.01 && progress < .95;
    }).toList();
    results.sort((a, b) => _app
        .getPlaybackProgress(b.id)
        .compareTo(_app.getPlaybackProgress(a.id)));
    return results;
  }

  List<MediaItem> get _recommended {
    final server = _app.recommendations
        .where((media) => media.isAccessibleTo(_app.currentProfile))
        .toList(growable: false);
    if (server.isNotEmpty) return server.take(12).toList(growable: false);
    return SmartSearch.recommendations(_library, limit: 12);
  }

  Future<void> _recommendationFeedback(MediaItem media, String action) async {
    final profileId = _app.currentProfile?.id;
    if (profileId == null || !_app.backendApi.isAuthenticated) return;
    try {
      await _app.backendApi.saveRecommendationFeedback(
        profileId: profileId,
        mediaId: media.id,
        action: action,
      );
      await _app.loadRecommendations();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Could not save recommendation feedback: $error')),
      );
    }
  }

  List<MusicTrack> get _continueListening =>
      MusicLibraryStore.instance.tracks.where((track) {
        final progress = _app.getPlaybackProgress(track.id);
        return progress > 0.01 &&
            progress < 0.95 &&
            track.audioUrl?.trim().isNotEmpty == true;
      }).toList(growable: false)
        ..sort((a, b) => _app
            .getPlaybackProgress(b.id)
            .compareTo(_app.getPlaybackProgress(a.id)));

  Widget _musicResumeRail(List<MusicTrack> tracks) {
    if (tracks.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Text('No partially played albums or tracks to resume yet.'),
      );
    }
    return SizedBox(
      height: 188,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tracks.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final track = tracks[index];
          final progress = _app.getPlaybackProgress(track.id).clamp(0.0, 1.0);
          return SizedBox(
            width: 112,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _playTrack(track),
                    borderRadius: BorderRadius.circular(9),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: (track.artworkUrl?.trim().isNotEmpty == true)
                              ? Image.network(track.artworkUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const ColoredBox(
                                        color: Colors.black12,
                                        child: Icon(Icons.album_rounded),
                                      ))
                              : const ColoredBox(
                                  color: Colors.black12,
                                  child: Icon(Icons.album_rounded),
                                ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: LinearProgressIndicator(
                              value: progress, minHeight: 4),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w800)),
                Text(track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          );
        },
      ),
    );
  }

  Map<String, MediaItem> get _mediaById => <String, MediaItem>{
        for (final media in _library) media.id: media,
      };

  Map<String, MusicTrack> get _tracksById => <String, MusicTrack>{
        for (final track in MusicLibraryStore.instance.tracks) track.id: track,
        ...MusicLibraryStore.instance.catalogTracks,
      };

  void _openMedia(MediaItem media) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => MediaDetailsScreen(media: media),
    ));
  }

  void _playMedia(MediaItem media) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PlayerScreen(media: media),
    ));
  }

  Future<void> _watchTogether(MediaItem media) async {
    final profileId = _app.currentProfile?.id;
    if (profileId == null || profileId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Select a profile before starting a shared session.')),
      );
      return;
    }
    try {
      final session = await _app.createBackendGroupWatchSession(
        media,
        profileId: profileId,
      );
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => GroupWatchScreen(media: media, sessionId: session.id),
      ));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Could not start shared viewing: ${error.toString().replaceFirst('Exception: ', '')}')),
      );
    }
  }

  Future<void> _playTrack(MusicTrack track) async {
    await MusicPlaybackController.instance.play(track);
    if (!mounted) return;
    if (!MusicPlaybackController.instance.isPlaying) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'This track does not currently have a playable audio stream.')),
      );
    }
  }

  Widget _sectionTitle(String title, String subtitle, IconData icon) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900)),
                  Text(subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _mediaRail(List<MediaItem> items,
      {bool showProgress = false,
      bool allowGroup = false,
      bool allowFeedback = false}) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('Nothing to show here yet.'),
      );
    }
    return SizedBox(
      height: allowFeedback ? 264 : (allowGroup ? 242 : 216),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 11),
        itemBuilder: (context, index) {
          final media = items[index];
          final progress = _app.getPlaybackProgress(media.id).clamp(0.0, 1.0);
          return SizedBox(
            width: 126,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () =>
                        showProgress ? _playMedia(media) : _openMedia(media),
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CatalogPosterImage(
                              media: media, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 5,
                          right: 5,
                          child: MediaStatusBadgeRow(media: media, dense: true),
                        ),
                        if (showProgress)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 4,
                              backgroundColor: Colors.black54,
                            ),
                          ),
                        Positioned(
                          right: 6,
                          bottom: 8,
                          child: CircleAvatar(
                            radius: 15,
                            backgroundColor:
                                Colors.black.withValues(alpha: .78),
                            child: const Icon(Icons.play_arrow_rounded,
                                color: Colors.white, size: 19),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(media.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w800)),
                if (allowGroup)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _watchTogether(media),
                      icon: const Icon(Icons.groups_rounded, size: 14),
                      label: const Text('Watch together'),
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact),
                    ),
                  ),
                if (allowFeedback)
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Recommend more like this',
                        visualDensity: VisualDensity.compact,
                        onPressed: () =>
                            _recommendationFeedback(media, 'moreLikeThis'),
                        icon: const Icon(Icons.thumb_up_alt_outlined, size: 17),
                      ),
                      IconButton(
                        tooltip: 'Show me less of this',
                        visualDensity: VisualDensity.compact,
                        onPressed: () =>
                            _recommendationFeedback(media, 'notInterested'),
                        icon:
                            const Icon(Icons.thumb_down_alt_outlined, size: 17),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _recentList() {
    if (_loadingRecent) {
      return const Padding(
        padding: EdgeInsets.all(18),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_recent.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
            'Your recently played movies, shows and music will appear here.'),
      );
    }
    final mediaById = _mediaById;
    final tracksById = _tracksById;
    final entries = _recent.take(12).toList(growable: false);
    return Column(
      children: [
        for (final entry in entries)
          Builder(builder: (context) {
            final video = entry.kind == 'video' ? mediaById[entry.id] : null;
            final track = entry.kind == 'audio' ? tracksById[entry.id] : null;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: SizedBox(
                width: 42,
                height: 56,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: video != null
                      ? CatalogPosterImage(media: video, fit: BoxFit.cover)
                      : (entry.artworkUrl?.trim().isNotEmpty == true
                          ? Image.network(entry.artworkUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const ColoredBox(
                                  color: Colors.black12,
                                  child: Icon(Icons.music_note_rounded)))
                          : const ColoredBox(
                              color: Colors.black12,
                              child: Icon(Icons.play_circle_outline_rounded))),
                ),
              ),
              title: Text(entry.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                  entry.subtitle ?? (entry.kind == 'audio' ? 'Music' : 'Video'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                tooltip: 'Play again',
                onPressed: video != null
                    ? () => _playMedia(video)
                    : (track != null ? () => _playTrack(track) : null),
                icon: const Icon(Icons.play_circle_outline_rounded),
              ),
              onTap: video != null
                  ? () => _openMedia(video)
                  : (track != null ? () => _playTrack(track) : null),
            );
          }),
      ],
    );
  }

  Widget _summaryChip(IconData icon, String label) => Chip(
        avatar: Icon(icon, size: 16),
        label: Text(label),
        visualDensity: VisualDensity.compact,
      );

  @override
  Widget build(BuildContext context) {
    final continueWatching = _continueWatching;
    final recommendations = _recommended;
    final musicTracks = MusicLibraryStore.instance.tracks
        .where((track) =>
            (MusicLibraryStore.instance.listenCounts[track.id] ?? 0) > 0)
        .toList()
      ..sort((a, b) => (MusicLibraryStore.instance.listenCounts[b.id] ?? 0)
          .compareTo(MusicLibraryStore.instance.listenCounts[a.id] ?? 0));

    return Scaffold(
      appBar: AppBar(title: const Text('My Media Hub')),
      body: RefreshIndicator(
        onRefresh: _loadRecent,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            const AccountProfilePresenceStrip(),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _summaryChip(Icons.movie_outlined, '${_library.length} titles'),
                _summaryChip(Icons.play_circle_outline_rounded,
                    '${continueWatching.length} in progress'),
                _summaryChip(
                    Icons.history_rounded, '${_recent.length} recent plays'),
                _summaryChip(Icons.headphones_rounded,
                    '${MusicLibraryStore.instance.listenCounts.values.fold<int>(0, (sum, count) => sum + count)} music plays'),
              ],
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) =>
                                  const EntertainmentCommandCenterScreen())),
                      icon: const Icon(Icons.dashboard_customize_rounded),
                      label: const Text('Command Center'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => const SmartSearchScreen())),
                      icon: const Icon(Icons.search_rounded),
                      label: const Text('Universal Search'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) =>
                                  const PersonalDiscoveryListsScreen())),
                      icon: const Icon(Icons.bookmarks_outlined),
                      label: const Text('My Lists'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) =>
                                  const SmartMediaImportCenterScreen())),
                      icon: const Icon(Icons.library_add_rounded),
                      label: const Text('Import Media'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => const OfflineSyncCenterScreen())),
                      icon: const Icon(Icons.cloud_sync_rounded),
                      label: const Text('Offline & Sync'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => const MediaHealthScreen())),
                      icon: const Icon(Icons.health_and_safety_rounded),
                      label: const Text('Media Health'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) =>
                                  const LibraryProtectionCenterScreen())),
                      icon: const Icon(Icons.backup_rounded),
                      label: const Text('Backup & Recovery'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) =>
                                  const LivingRoomControlsScreen())),
                      icon: const Icon(Icons.gamepad_rounded),
                      label: const Text('Controller Controls'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) =>
                                  const MediaWrappedCollectionsScreen())),
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: const Text('Entertainment Wrapped'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _sectionTitle(
                'Continue Watching',
                'Resume movies and episodes using saved playback progress.',
                Icons.play_circle_outline_rounded),
            _mediaRail(continueWatching, showProgress: true, allowGroup: true),
            const SizedBox(height: 22),
            _sectionTitle(
                'Continue Listening',
                'Resume imported music at its saved position on this profile.',
                Icons.headphones_rounded),
            _musicResumeRail(_continueListening),
            const SizedBox(height: 22),
            _sectionTitle(
                'Recently Played',
                'Recent playback metadata synced for this profile when account connectivity is available.',
                Icons.history_rounded),
            _recentList(),
            const SizedBox(height: 22),
            _sectionTitle(
                'Recommended for You',
                'Profile recommendations with feedback controls; local suggestions appear when the backend is unavailable.',
                Icons.auto_awesome_rounded),
            _mediaRail(recommendations, allowGroup: true, allowFeedback: true),
            if (musicTracks.isNotEmpty) ...[
              const SizedBox(height: 22),
              _sectionTitle(
                  'Most Played Music',
                  'Your most-listened imported tracks.',
                  Icons.headphones_rounded),
              for (final track in musicTracks.take(8))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading:
                      const CircleAvatar(child: Icon(Icons.music_note_rounded)),
                  title: Text(track.title),
                  subtitle: Text('${track.artist} · ${track.album}'),
                  trailing: Text(
                      '${MusicLibraryStore.instance.listenCounts[track.id] ?? 0} plays'),
                  onTap: () => _playTrack(track),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
