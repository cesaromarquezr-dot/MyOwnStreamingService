import 'dart:async';

import 'package:flutter/material.dart';

import '../app_core.dart';
import '../catalog_poster_image.dart';
import '../data/theater_repository.dart';
import '../details.dart';
import '../group_watch.dart';
import '../models/theater_models.dart';
import '../music.dart';
import '../presence/account_profile_presence_service.dart';
import '../widgets/account_profile_presence_strip.dart';
import '../playback_interruption_bridge.dart';
import '../stores/theater_store.dart';
import '../widgets/virtual_theater_3d_scene.dart';

/// Private, multi-room playback dashboard. A room only changes to Playing
/// after the actual player reports that playback has started.
class TheaterHomeScreen extends StatefulWidget {
  const TheaterHomeScreen({super.key});

  @override
  State<TheaterHomeScreen> createState() => _TheaterHomeScreenState();
}

class _TheaterHomeScreenState extends State<TheaterHomeScreen> {
  final TheaterRepository _repository = const TheaterRepository();
  final TheaterStore _store = TheaterStore.instance;
  Timer? _roomRefreshTimer;
  final TextEditingController _posterSearchController = TextEditingController();
  String _posterFilter = 'All';

  @override
  void initState() {
    super.initState();
    _store.addListener(_refresh);
    unawaited(_store.load(AppController.instance.currentProfile?.id).then((_) {
      _syncPresenceActivity();
    }));
    final profile = AppController.instance.currentProfile;
    if (profile != null) {
      AccountProfilePresenceService.instance.start(
        profileId: profile.id,
        activityType: 'browsing',
        activityText: 'Private Theater',
      );
    }
    _roomRefreshTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      unawaited(_store.refreshRemoteSessions());
    });
  }

  @override
  void dispose() {
    _roomRefreshTimer?.cancel();
    _posterSearchController.dispose();
    _store.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
      _syncPresenceActivity();
    }
  }

  void _syncPresenceActivity() {
    final profile = AppController.instance.currentProfile;
    if (profile == null) return;
    for (final room in _store.rooms) {
      final session = _store.sessionForRoom(room.id);
      if (session == null) continue;
      if (session.status == 'playing' || session.status == 'previewing') {
        AccountProfilePresenceService.instance.start(
          profileId: profile.id,
          activityType: 'watching',
          activityText: room.name,
        );
        return;
      }
    }
    AccountProfilePresenceService.instance.start(
      profileId: profile.id,
      activityType: 'browsing',
      activityText: 'Private Theater',
    );
  }

  List<MediaItem> get _library {
    final items = _repository.ownedScreeningLibrary().toList();
    items.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return items;
  }

  bool _isShow(MediaItem media) {
    final type = media.type.toLowerCase();
    return type.contains('tv') || type.contains('show') ||
        type.contains('series') || type.contains('episode') ||
        type.contains('television') || type.contains('special');
  }

  String _episodeSubtitle(MediaItem media) {
    final explicit = RegExp(
      r'(season\s+\d+\s*[·,:-]?\s*episode\s+\d+|s\d{1,2}e\d{1,3})',
      caseSensitive: false,
    ).firstMatch(media.title);
    if (explicit != null) return explicit.group(0)!.toUpperCase();
    final type = media.type.toLowerCase();
    if (type.contains('episode')) return 'TV episode';
    if (type.contains('series') || type.contains('show') || type.contains('tv')) {
      return 'TV series';
    }
    if (type.contains('special')) return 'TV special';
    return media.releaseYear?.toString() ?? 'Movie';
  }

  Future<void> _openRoomPicker(TheaterRoom room) async {
    final items = _library;
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your owned movies and episodes will appear here after import.')),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(sheetContext).size.height * .78,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                child: Text('Choose media for ${room.name}', style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final media = items[index];
                    return ListTile(
                      leading: SizedBox(
                        width: 46,
                        height: 64,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: CatalogPosterImage(media: media, fit: BoxFit.cover),
                        ),
                      ),
                      title: Text(media.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(_episodeSubtitle(media)),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _assignMediaToRoom(room, media);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _chooseRoomForMedia(MediaItem media) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
              child: Text('Send ${media.title} to…', maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            ),
            for (final room in _store.rooms)
              ListTile(
                leading: const Icon(Icons.meeting_room_rounded),
                title: Text(room.name),
                subtitle: Text(_store.sessionForRoom(room.id)?.title ?? 'Room available'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _assignMediaToRoom(room, media);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleRoomPlayback(TheaterRoom room, TheaterSession session) async {
    final isPlaying = session.status == 'playing' || session.status == 'previewing';
    final controlled = isPlaying
        ? PlaybackInterruptionBridge.pauseNow(roomId: room.id)
        : PlaybackInterruptionBridge.resumeNow(roomId: room.id);
    if (!controlled && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Playback controls are available on the device currently running this room.')),
      );
    }
  }

  Future<void> _assignMediaToRoom(TheaterRoom room, MediaItem media) async {
    await _store.createSession(
      mediaId: media.id,
      title: media.title,
      roomId: room.id,
      subtitle: _episodeSubtitle(media),
    );
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MediaDetailsScreen(
          media: media,
          theaterRoomId: room.id,
        ),
      ),
    );
  }

  Future<void> _stopRoom(TheaterRoom room, TheaterSession session) async {
    if (session.status == 'playing' || session.status == 'paused' || session.status == 'previewing') {
      if (PlaybackInterruptionBridge.stopNow(roomId: room.id)) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This room is not attached to a player on this device. Stop it from the device currently playing.')),
      );
      return;
    }
    await _store.updatePlaybackState(
      roomId: room.id,
      mediaId: session.mediaId,
      status: 'stopped',
    );
  }

  Future<void> _addRoom() async {
    final name = TextEditingController(text: 'Room ${_store.rooms.length + 1}');
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add theater room'),
        content: TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Room name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, name.text.trim()), child: const Text('Add room')),
        ],
      ),
    );
    name.dispose();
    if (result == null || result.trim().isEmpty) return;
    await _store.addRoom(name: result);
  }

  Future<void> _renameRoom(TheaterRoom room) async {
    final name = TextEditingController(text: room.name);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename room'),
        content: TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Room name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, name.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    name.dispose();
    if (result == null || result.trim().isEmpty) return;
    await _store.renameRoom(room.id, result);
  }

  Future<void> _removeRoom(TheaterRoom room) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove ${room.name}?'),
        content: const Text('This removes the room from this profile. Its active local session will be stopped.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed == true) await _store.removeRoom(room.id);
  }

  void _showRoomMenu(TheaterRoom room) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(leading: const Icon(Icons.edit_rounded), title: const Text('Rename room'), onTap: () { Navigator.pop(sheetContext); _renameRoom(room); }),
            ListTile(leading: const Icon(Icons.delete_outline_rounded), title: const Text('Remove room'), enabled: _store.rooms.length > 1, onTap: () { Navigator.pop(sheetContext); _removeRoom(room); }),
          ],
        ),
      ),
    );
  }

  Future<void> _startGroupWatch(MediaItem media) async {
    final profileId = AppController.instance.currentProfile?.id;
    if (profileId == null || profileId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a profile before starting a shared session.')),
      );
      return;
    }
    try {
      final session = await AppController.instance.createBackendGroupWatchSession(
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
        SnackBar(content: Text('Could not start shared viewing: ${error.toString().replaceFirst('Exception: ', '')}')),
      );
    }
  }

  String? _watchingProfileName(TheaterRoom room) {
    final matches = AccountProfilePresenceService.instance.activeProfiles.where(
      (profile) => profile.activityType == 'watching' &&
          profile.activityText?.trim().toLowerCase() == room.name.trim().toLowerCase(),
    );
    return matches.isEmpty ? null : matches.first.name;
  }

  Widget _buildPosterLobby(List<MediaItem> library) {
    final featured = library.where((media) =>
        media.imageUrl?.trim().isNotEmpty == true).take(12).toList(growable: false);
    if (featured.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.local_movies_rounded, color: Color(0xFFE4B66B)),
          const SizedBox(width: 8),
          Expanded(child: Text('Theater lobby · Featured posters', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
        ]),
        const SizedBox(height: 9),
        SizedBox(
          height: 166,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: featured.length,
            separatorBuilder: (_, __) => const SizedBox(width: 9),
            itemBuilder: (context, index) {
              final media = featured[index];
              return SizedBox(
                width: 104,
                child: InkWell(
                  onTap: () => _chooseRoomForMedia(media),
                  borderRadius: BorderRadius.circular(9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(9), child: CatalogPosterImage(media: media, fit: BoxFit.cover))),
                      const SizedBox(height: 5),
                      Text(media.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNowPlayingBoard(List<MediaItem> library) {
    final active = _store.rooms.where((room) {
      final session = _store.sessionForRoom(room.id);
      return session != null &&
          (session.status == 'playing' || session.status == 'previewing' || session.status == 'paused');
    }).toList(growable: false);
    return Card(
      color: const Color(0xFF171B24),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [Icon(Icons.live_tv_rounded, color: Color(0xFF3BCB83)), SizedBox(width: 8), Text('NOW PLAYING · PRIVATE ROOMS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0))]),
            const SizedBox(height: 8),
            if (active.isEmpty)
              const Text('No private room is playing right now. Choose a poster and assign it to a room.', style: TextStyle(color: Colors.white60, fontSize: 12))
            else
              for (final room in active)
                Builder(builder: (context) {
                  final session = _store.sessionForRoom(room.id)!;
                  final matching = library.where((item) => item.id == session.mediaId);
                  final media = matching.isEmpty ? null : matching.first;
                  final profileName = _watchingProfileName(room);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: SizedBox(
                      width: 42,
                      height: 58,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: media == null
                            ? const ColoredBox(color: Color(0xFF303746), child: Icon(Icons.movie_rounded))
                            : CatalogPosterImage(media: media, fit: BoxFit.cover),
                      ),
                    ),
                    title: Text(session.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(profileName == null
                        ? '${room.name} · ${session.status.toUpperCase()}'
                        : '${room.name} ($profileName) is ${session.status == 'paused' ? 'paused' : 'watching'}',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: media == null ? null : IconButton(
                      tooltip: 'Watch together',
                      onPressed: () => _startGroupWatch(media),
                      icon: const Icon(Icons.groups_rounded),
                    ),
                  );
                }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final library = _library;
    final posterQuery = _posterSearchController.text.trim().toLowerCase();
    final posterLibrary = library.where((media) {
      if (_posterFilter == 'Movies' && _isShow(media)) return false;
      if (_posterFilter == 'Shows' && !_isShow(media)) return false;
      if (posterQuery.isEmpty) return true;
      return <String>[media.title, media.description ?? '', ...media.genres, ...media.tags]
          .join(' ').toLowerCase().contains(posterQuery);
    }).toList(growable: false);
    final activeRooms = _store.rooms.where((room) {
      final session = _store.sessionForRoom(room.id);
      return session != null && session.isCurrent;
    }).length;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0D12),
      appBar: AppBar(
        title: const Text('Private Theater', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(tooltip: 'Add room', onPressed: _addRoom, icon: const Icon(Icons.add_home_work_rounded)),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(colors: [Color(0xFF32151C), Color(0xFF171B28)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              border: Border.all(color: const Color(0xFF9B6D4B).withValues(alpha: .55)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [Icon(Icons.theaters_rounded, color: Color(0xFFE4B66B)), SizedBox(width: 8), Text('YOUR PRIVATE THEATER', style: TextStyle(color: Color(0xFFE4B66B), fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w900))]),
                const SizedBox(height: 12),
                VirtualTheater3DScene(
                  posterMedia: library.take(8).toList(growable: false),
                  onPosterSelected: _chooseRoomForMedia,
                  playbackActive: _store.rooms.any((room) {
                    final session = _store.sessionForRoom(room.id);
                    return session != null &&
                        (session.status == 'playing' || session.status == 'previewing');
                  }),
                ),
                const SizedBox(height: 12),
                Text('Look around your auditorium', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text('Drag to look in every direction. Use the on-screen arrows to walk between the seats, aisles and rear poster wall.', style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
                const SizedBox(height: 8),
                Text('$activeRooms active room showings · ${_store.rooms.length} private rooms · ${library.length} movies and shows in your poster gallery', style: const TextStyle(color: Colors.white60, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const AccountProfilePresenceStrip(theaterStyle: true),
          const SizedBox(height: 12),
          _buildNowPlayingBoard(library),
          const SizedBox(height: 18),
          _buildPosterLobby(library),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: Text('All posters', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
              Text('${posterLibrary.length} titles', style: const TextStyle(color: Colors.white60, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 5),
          const Text('Browse every movie and show in this profile. Select a poster to choose a private room and open its player.', style: TextStyle(color: Colors.white60, fontSize: 11, height: 1.4)),
          const SizedBox(height: 10),
          TextField(
            controller: _posterSearchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search all movie and show posters…',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _posterSearchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear poster search',
                      onPressed: () {
                        _posterSearchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              isDense: true,
              filled: true,
              fillColor: Colors.white.withValues(alpha: .06),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            children: [
              for (final filter in const ['All', 'Movies', 'Shows'])
                ChoiceChip(
                  label: Text(filter),
                  selected: _posterFilter == filter,
                  onSelected: (_) => setState(() => _posterFilter = filter),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (posterLibrary.isEmpty)
            const Padding(padding: EdgeInsets.all(18), child: Text('Your owned movie and television posters will appear here after import.'))
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: posterLibrary.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 145,
                mainAxisExtent: 220,
                crossAxisSpacing: 10,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (context, index) {
                final media = posterLibrary[index];
                return InkWell(
                  onTap: () => _chooseRoomForMedia(media),
                  borderRadius: BorderRadius.circular(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(borderRadius: BorderRadius.circular(9), child: CatalogPosterImage(media: media, fit: BoxFit.cover)),
                            Positioned(
                              right: 5,
                              bottom: 5,
                              child: DecoratedBox(
                                decoration: BoxDecoration(color: Colors.black.withValues(alpha: .78), borderRadius: BorderRadius.circular(20)),
                                child: const Padding(padding: EdgeInsets.all(5), child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(media.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                      Text(_episodeSubtitle(media), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 9)),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: Text('All showings · private rooms', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
              TextButton.icon(onPressed: _addRoom, icon: const Icon(Icons.add_rounded), label: const Text('Add room')),
            ],
          ),
          const Text('Each room shows its assigned title and live playback state: now playing, paused, ready or available. These are private playback rooms, not paid cinema showtimes.', style: TextStyle(color: Colors.white60, fontSize: 11, height: 1.4)),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _store.rooms.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 360,
              mainAxisExtent: 244,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (context, index) {
              final room = _store.rooms[index];
              final session = _store.sessionForRoom(room.id);
              final matchingMedia = session == null
                  ? const <MediaItem>[]
                  : library.where((item) => item.id == session.mediaId).toList();
              final media = matchingMedia.isEmpty ? null : matchingMedia.first;
              return _TheaterRoomCard(
                room: room,
                session: session,
                media: media,
                watchingProfileName: _watchingProfileName(room),
                onSelect: () => _openRoomPicker(room),
                onOpen: session == null || media == null
                    ? null
                    : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MediaDetailsScreen(media: media, theaterRoomId: room.id))),
                onStop: session == null ? null : () => _stopRoom(room, session),
                onToggle: session == null || (session.status != 'playing' && session.status != 'previewing' && session.status != 'paused') ? null : () => _toggleRoomPlayback(room, session),
                onMenu: () => _showRoomMenu(room),
              );
            },
          ),
          const SizedBox(height: 22),
          _LoungeShortcut(
            icon: Icons.headphones_rounded,
            title: 'Listening Lounge',
            subtitle: 'Open your CDs, albums, artists, playlists and music queue.',
            actionLabel: 'Open music',
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MusicScreen())),
          ),
        ],
      ),
    );
  }

}

class _TheaterRoomCard extends StatelessWidget {
  const _TheaterRoomCard({
    required this.room,
    required this.session,
    required this.media,
    required this.watchingProfileName,
    required this.onSelect,
    required this.onOpen,
    required this.onStop,
    required this.onToggle,
    required this.onMenu,
  });

  final TheaterRoom room;
  final TheaterSession? session;
  final MediaItem? media;
  final String? watchingProfileName;
  final VoidCallback onSelect;
  final VoidCallback? onOpen;
  final VoidCallback? onStop;
  final VoidCallback? onToggle;
  final VoidCallback onMenu;

  String _formatPosition(double seconds) {
    final total = seconds.floor().clamp(0, 999999).toInt();
    final duration = Duration(seconds: total);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final remaining = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$remaining' : '${duration.inMinutes}:$remaining';
  }

  String _statusLabel(String? status) => switch (status) {
        'playing' => 'NOW PLAYING',
        'previewing' => 'PREVIEWING',
        'paused' => 'PAUSED',
        'starting' => 'STARTING',
        'error' => 'PLAYBACK ISSUE',
        'ready' => 'READY',
        _ => 'AVAILABLE',
      };

  Color _statusColor(String? status) => status == 'playing'
      ? const Color(0xFF3BCB83)
      : status == 'paused'
          ? const Color(0xFFE4B66B)
          : Colors.white54;

  @override
  Widget build(BuildContext context) {
    final current = session != null && session!.isCurrent;
    final imageMedia = media;
    return Card(
      margin: EdgeInsets.zero,
      color: const Color(0xFF171B24),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (imageMedia != null)
                  CatalogPosterImage(media: imageMedia, fit: BoxFit.cover)
                else
                  const ColoredBox(color: Color(0xFF252B38), child: Center(child: Icon(Icons.weekend_rounded, size: 42, color: Colors.white54))),
                const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black26, Colors.black87]))),
                Positioned(
                  left: 12,
                  right: 42,
                  bottom: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(room.name.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                      if (current) Text(_statusLabel(session?.status), style: TextStyle(color: _statusColor(session?.status), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
                      if (watchingProfileName != null) Text('(${watchingProfileName!}) is watching', style: const TextStyle(color: Color(0xFF8CF0B1), fontSize: 9, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                Positioned(right: 4, top: 4, child: IconButton(onPressed: onMenu, tooltip: 'Room options', icon: const Icon(Icons.more_vert_rounded, color: Colors.white))),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(11, 8, 11, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session?.title ?? 'Nothing playing', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                const SizedBox(height: 3),
                Text(
                  room.deviceName?.trim().isNotEmpty == true
                      ? '${session?.subtitle ?? room.description} · ${room.deviceName}'
                      : (session?.subtitle ?? room.description),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white60, fontSize: 10),
                ),
                if (session != null && session!.positionSeconds > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      'At ${_formatPosition(session!.positionSeconds)}',
                      style: const TextStyle(color: Colors.white54, fontSize: 9),
                    ),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: TextButton.icon(onPressed: current ? onOpen : onSelect, icon: Icon(current ? Icons.open_in_new_rounded : Icons.play_arrow_rounded, size: 17), label: Text(current ? 'Open title' : 'Choose media'), style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft))),
                    if (current && onToggle != null)
                      IconButton(
                        onPressed: onToggle,
                        tooltip: session?.status == 'paused' ? 'Resume room' : 'Pause room',
                        visualDensity: VisualDensity.compact,
                        icon: Icon(session?.status == 'paused' ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 20),
                      ),
                    if (current && onStop != null) IconButton(onPressed: onStop, tooltip: 'Stop room', visualDensity: VisualDensity.compact, icon: const Icon(Icons.stop_circle_outlined, size: 20)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoungeShortcut extends StatelessWidget {
  const _LoungeShortcut({required this.icon, required this.title, required this.subtitle, required this.actionLabel, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFF171B24),
        child: ListTile(
          leading: CircleAvatar(backgroundColor: const Color(0xFF303B4F), child: Icon(icon, color: Colors.white)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 11)),
          trailing: TextButton(onPressed: onTap, child: Text(actionLabel)),
        ),
      );
}
