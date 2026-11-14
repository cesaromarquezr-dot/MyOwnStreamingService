import 'package:material_ui/material_ui.dart';

import '../app_core.dart';
import '../community/media_music_history_store.dart';
import 'media_detail_arrow_rail.dart';

/// Shows the playlists and collections that currently contain an album.
class MediaAlbumContextSections extends StatelessWidget {
  const MediaAlbumContextSections({
    super.key,
    required this.albumTitle,
    required this.trackIds,
    this.media,
    this.profileId,
  });

  final String albumTitle;
  final List<String> trackIds;
  final MediaItem? media;
  final String? profileId;

  @override
  Widget build(BuildContext context) {
    final collections = AppController.instance.collections
        .where((collection) =>
            media != null && collection.mediaIds.contains(media!.id))
        .map((collection) => collection.name)
        .toList(growable: false);
    final playlists = MediaMusicHistoryStore.playlistsContainingTracks(
      profileId: profileId,
      trackIds: trackIds,
    );
    return FutureBuilder<List<String>>(
      future: playlists,
      builder: (context, snapshot) {
        final playlistNames = snapshot.data ?? const <String>[];
        if (collections.isEmpty &&
            playlistNames.isEmpty &&
            !snapshot.hasError &&
            snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(minHeight: 2),
          );
        }
        return Container(
          margin: const EdgeInsets.only(top: 20),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .045),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: .08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('This item appears in',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              if (collections.isNotEmpty) ...[
                const SizedBox(height: 9),
                const Text('Collections',
                    style: TextStyle(color: Colors.white60, fontSize: 11)),
                MediaDetailArrowRail(
                  height: 52,
                  spacing: 7,
                  semanticLabel: 'collections',
                  children: collections
                      .map((name) => Chip(
                            avatar: const Icon(
                                Icons.collections_bookmark_outlined,
                                size: 15),
                            label: Text(name),
                          ))
                      .toList(growable: false),
                ),
              ],
              if (playlistNames.isNotEmpty) ...[
                const SizedBox(height: 9),
                const Text('Playlists',
                    style: TextStyle(color: Colors.white60, fontSize: 11)),
                MediaDetailArrowRail(
                  height: 52,
                  spacing: 7,
                  semanticLabel: 'playlists',
                  children: playlistNames
                      .map((name) => Chip(
                            avatar:
                                const Icon(Icons.queue_music_rounded, size: 15),
                            label: Text(name),
                          ))
                      .toList(growable: false),
                ),
              ],
              if (snapshot.hasError)
                const Text('Playlist membership could not be loaded.',
                    style: TextStyle(color: Colors.orangeAccent, fontSize: 11)),
              if (collections.isEmpty &&
                  playlistNames.isEmpty &&
                  !snapshot.hasError)
                Text(
                    '$albumTitle is not currently listed in a collection or playlist.',
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        );
      },
    );
  }
}
