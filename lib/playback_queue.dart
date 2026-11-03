import 'package:flutter/material.dart';

import 'app_core.dart';
import 'details.dart';
import 'music.dart';
import 'player.dart';
import 'profile_content_safety.dart';
import 'playback_queue_store.dart';

class PlaybackQueueScreen extends StatefulWidget {
  const PlaybackQueueScreen({super.key});

  @override
  State<PlaybackQueueScreen> createState() => _PlaybackQueueScreenState();
}

class _PlaybackQueueScreenState extends State<PlaybackQueueScreen> {
  final PlaybackQueueStore _store = const PlaybackQueueStore();
  List<PlaybackQueueEntry> _entries = <PlaybackQueueEntry>[];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  String get _profileId =>
      AppController.instance.currentProfile?.id ?? 'default';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final entries = await _store.load(profileId: _profileId);
      String? musicError;
      try {
        await MusicLibraryStore.instance.initializeForProfile(_profileId);
      } catch (error) {
        musicError = 'Music library could not be loaded: $error';
      }
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
        _error = musicError;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load the playback queue: $error';
      });
    }
  }

  MediaItem? _mediaForId(String id) {
    final controller = AppController.instance;
    for (final item in controller.library) {
      if (item.id == id && item.isAccessibleTo(controller.currentProfile)) {
        return item;
      }
    }
    return null;
  }

  MusicTrack? _trackForId(String id) {
    for (final track in MusicLibraryStore.instance.tracks) {
      if (track.id == id) return track;
    }
    return null;
  }

  Future<void> _addFromLibrary() async {
    final controller = AppController.instance;
    final queuedKeys = _entries.map((entry) => entry.key).toSet();
    final mediaItems = controller.library
        .where((item) =>
            item.isAccessibleTo(controller.currentProfile) &&
            !queuedKeys.contains('${PlaybackQueueKind.media.name}:${item.id}'))
        .toList(growable: false);
    final musicTracks = MusicLibraryStore.instance.tracks
        .where((track) =>
            !queuedKeys
                .contains('${PlaybackQueueKind.music.name}:${track.id}') &&
            !(profileBlocksExplicitMusic(controller.currentProfile) &&
                track.explicit) &&
            !(profileBlocksMatureMusic(controller.currentProfile) &&
                track.matureTheme))
        .toList(growable: false);
    final selected = await showModalBottomSheet<PlaybackQueueEntry>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.75,
          child: Column(
            children: [
              const ListTile(
                title: Text('Add from your library'),
                subtitle: Text('Movies, episodes, albums, and tracks'),
              ),
              Expanded(
                child: mediaItems.isEmpty && musicTracks.isEmpty
                    ? const Center(
                        child: Text('Everything in your library is queued.'))
                    : ListView(
                        children: [
                          for (final media in mediaItems)
                            ListTile(
                              leading: const Icon(Icons.movie_outlined),
                              title: Text(media.title),
                              subtitle: Text(media.type),
                              onTap: () => Navigator.pop(
                                context,
                                PlaybackQueueEntry(
                                  kind: PlaybackQueueKind.media,
                                  id: media.id,
                                ),
                              ),
                            ),
                          for (final track in musicTracks)
                            ListTile(
                              leading: const Icon(Icons.music_note_rounded),
                              title: Text(track.title),
                              subtitle:
                                  Text('${track.artist} · ${track.album}'),
                              onTap: () => Navigator.pop(
                                context,
                                PlaybackQueueEntry(
                                  kind: PlaybackQueueKind.music,
                                  id: track.id,
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await _store.add(profileId: _profileId, entry: selected);
      await _reload();
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not add that title: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    if (_saving) return;
    final reordered = List<PlaybackQueueEntry>.from(_entries);
    final item = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, item);
    setState(() {
      _entries = reordered;
      _saving = true;
      _error = null;
    });
    try {
      await _store.replace(profileId: _profileId, entries: reordered);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not save the new queue order: $error');
        await _reload();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove(PlaybackQueueEntry entry) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _store.remove(profileId: _profileId, entry: entry);
      await _reload();
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not remove that title: $error');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveAsCollection() async {
    if (_entries.isEmpty || _saving) return;
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save queue as a collection'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Collection name'),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    nameController.dispose();
    if (name == null || name.trim().isEmpty || !mounted) return;
    try {
      final mediaIds = _entries
          .where((entry) => entry.kind == PlaybackQueueKind.media)
          .map((entry) => entry.id)
          .toList(growable: false);
      final trackIds = _entries
          .where((entry) => entry.kind == PlaybackQueueKind.music)
          .map((entry) => entry.id)
          .toList(growable: false);
      if (mediaIds.isNotEmpty) {
        AppController.instance.createCollection(
          name: name.trim(),
          description: 'Saved from the playback queue.',
          shared: false,
          mediaIds: mediaIds,
        );
      }
      if (trackIds.isNotEmpty) {
        MusicLibraryStore.instance
            .createPlaylist(name.trim(), trackIds: trackIds);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Queue saved as a private collection.')),
      );
    } catch (error) {
      setState(
          () => _error = 'Could not save this queue as a collection: $error');
    }
  }

  Future<void> _clearQueue() async {
    if (_entries.isEmpty || _saving) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear playback queue?'),
        content:
            const Text('This only clears the queue for the current profile.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear queue'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _saving = true);
    try {
      await _store.clear(profileId: _profileId);
      await _reload();
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not clear the queue: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _play(PlaybackQueueEntry entry) async {
    if (entry.kind == PlaybackQueueKind.music) {
      final track = _trackForId(entry.id);
      if (track == null || track.audioUrl?.trim().isNotEmpty != true) return;
      final profile = AppController.instance.currentProfile;
      if ((profileBlocksExplicitMusic(profile) && track.explicit) ||
          (profileBlocksMatureMusic(profile) && track.matureTheme)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('This track is blocked by the profile settings.')),
        );
        return;
      }
      await _remove(entry);
      if (!mounted) return;
      await MusicPlaybackController.instance.play(track);
      return;
    }
    final media = _mediaForId(entry.id);
    if (media == null) return;
    final canPlay = (media.playbackUrl?.trim().isNotEmpty ?? false) ||
        (media.trailerUrl?.trim().isNotEmpty ?? false);
    if (canPlay) {
      await _remove(entry);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => PlayerScreen(media: media)),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MediaDetailsScreen(media: media),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Up Next'),
          actions: [
            IconButton(
              tooltip: 'Add from library',
              onPressed: _saving ? null : _addFromLibrary,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        body: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text(
                'Your private, profile-specific queue. Drag titles to reorder; items are saved by ID and never include stream URLs.',
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: MaterialBanner(
                  content: Text(_error!),
                  actions: [
                    TextButton(onPressed: _reload, child: const Text('Retry')),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: _saving ? null : _addFromLibrary,
                    icon: const Icon(Icons.add),
                    label: const Text('Add titles'),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Save as private collection',
                    onPressed:
                        _saving || _entries.isEmpty ? null : _saveAsCollection,
                    icon: const Icon(Icons.playlist_add_check_rounded),
                  ),
                  IconButton(
                    tooltip: 'Clear queue',
                    onPressed: _saving || _entries.isEmpty ? null : _clearQueue,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
            if (_saving) const LinearProgressIndicator(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _entries.isEmpty
                      ? const Center(
                          child: Text(
                            'Your queue is empty. Add movies, episodes, albums, or tracks from your library.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ReorderableListView.builder(
                          itemCount: _entries.length,
                          onReorderItem: _reorder,
                          itemBuilder: (context, index) {
                            final entry = _entries[index];
                            final media = entry.kind == PlaybackQueueKind.media
                                ? _mediaForId(entry.id)
                                : null;
                            final track = entry.kind == PlaybackQueueKind.music
                                ? _trackForId(entry.id)
                                : null;
                            final available = media != null || track != null;
                            final hasPlaybackSource = media != null
                                ? (media.playbackUrl?.trim().isNotEmpty ??
                                        false) ||
                                    (media.trailerUrl?.trim().isNotEmpty ??
                                        false)
                                : track?.audioUrl?.trim().isNotEmpty == true;
                            final canOpen = media != null || hasPlaybackSource;
                            final title = media?.title ?? track?.title;
                            return ListTile(
                              key: ValueKey<String>('queue:${entry.key}'),
                              leading: Icon(
                                  entry.kind == PlaybackQueueKind.music
                                      ? Icons.music_note_rounded
                                      : Icons.drag_handle),
                              title: Text(title ?? 'Unavailable title'),
                              subtitle: Text(
                                !available
                                    ? 'No longer available to this profile'
                                    : track != null
                                        ? '${track.artist} · ${track.album}'
                                        : media!.type,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: !available
                                        ? 'Unavailable'
                                        : hasPlaybackSource
                                            ? 'Play'
                                            : media != null
                                                ? 'Open details'
                                                : 'No playable source',
                                    onPressed: _saving || !available || !canOpen
                                        ? null
                                        : () => _play(entry),
                                    icon: const Icon(Icons.play_arrow_rounded),
                                  ),
                                  IconButton(
                                    tooltip: 'Remove from queue',
                                    onPressed:
                                        _saving ? null : () => _remove(entry),
                                    icon: const Icon(Icons.close),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      );
}
