import 'package:material_ui/material_ui.dart';

import 'app_core.dart';
import 'core/services/library_protection_service.dart';
import 'details.dart';
import 'library_protection_center.dart';
import 'music.dart';

/// Non-destructive diagnostics for the active profile's media catalog.
/// This screen reports metadata gaps; it does not delete or rewrite media.
class MediaHealthScreen extends StatefulWidget {
  const MediaHealthScreen({super.key});

  @override
  State<MediaHealthScreen> createState() => _MediaHealthScreenState();
}

class _MediaHealthScreenState extends State<MediaHealthScreen> {
  final AppController _app = AppController.instance;
  final MusicLibraryStore _music = MusicLibraryStore.instance;

  @override
  void initState() {
    super.initState();
    _app.addListener(_refresh);
    _music.addListener(_refresh);
  }

  @override
  void dispose() {
    _app.removeListener(_refresh);
    _music.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  List<MediaItem> get _media => _app.library
      .where((item) => item.isAccessibleTo(_app.currentProfile))
      .toList(growable: false);

  List<MusicTrack> get _ownedTracks => _music.tracks
      .where((track) => !track.catalogOnly)
      .toList(growable: false);

  int get _missingArtwork =>
      _media.where((item) => (item.imageUrl?.trim() ?? '').isEmpty).length;

  int get _missingDescriptions =>
      _media.where((item) => (item.description?.trim() ?? '').isEmpty).length;

  int get _missingPlaybackSources =>
      _media.where((item) => (item.playbackUrl?.trim() ?? '').isEmpty).length;

  int get _missingSubtitleMetadata =>
      _media.where((item) => item.subtitles.isEmpty).length;

  int get _missingAudioMetadata =>
      _media.where((item) => item.audioTracks.isEmpty).length;

  int get _missingAlbumArtwork => _ownedTracks
      .where((track) => (track.artworkUrl?.trim() ?? '').isEmpty)
      .length;

  int get _missingAudioFiles => _ownedTracks
      .where((track) => (track.audioUrl?.trim() ?? '').isEmpty)
      .length;

  List<LibraryAuditFinding> get _findings =>
      LibraryProtectionService.audit(_media);

  List<PotentialDuplicateGroup> get _duplicates =>
      LibraryProtectionService.findPotentialDuplicates(_media);

  void _openMedia(String mediaId) {
    MediaItem? media;
    for (final item in _media) {
      if (item.id == mediaId) {
        media = item;
        break;
      }
    }
    if (media == null) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => MediaDetailsScreen(media: media!),
    ));
  }

  Widget _metric(String title, String value, IconData icon, String note) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Icon(icon,
                  size: 27, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w900)),
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(note, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _findingTile(LibraryAuditFinding finding) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.info_outline_rounded),
        title:
            Text(finding.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${finding.category} · ${finding.description}',
            maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => _openMedia(finding.mediaId),
      );

  @override
  Widget build(BuildContext context) {
    final media = _media;
    final tracks = _ownedTracks;
    final findings = _findings;
    final duplicates = _duplicates;
    final issueCount = _missingArtwork +
        _missingDescriptions +
        _missingPlaybackSources +
        _missingAlbumArtwork +
        _missingAudioFiles;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Library Health'),
        actions: [
          IconButton(
            tooltip: 'Recalculate diagnostics',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    issueCount == 0
                        ? Icons.verified_rounded
                        : Icons.health_and_safety_rounded,
                    size: 34,
                    color: issueCount == 0
                        ? Colors.green
                        : Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            issueCount == 0
                                ? 'No obvious metadata gaps'
                                : '$issueCount catalog checks need attention',
                            style:
                                const TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 3),
                        Text(
                            '${media.length} accessible movies and shows · ${tracks.length} owned music tracks'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _metric(
              'Missing movie/show artwork',
              '$_missingArtwork',
              Icons.image_not_supported_outlined,
              'Poster or artwork URL is empty.'),
          _metric('Missing descriptions', '$_missingDescriptions',
              Icons.description_outlined, 'A synopsis has not been saved.'),
          _metric(
              'No direct playback URL',
              '$_missingPlaybackSources',
              Icons.play_disabled_rounded,
              'A server may still resolve playback on demand.'),
          _metric(
              'No indexed subtitle metadata',
              '$_missingSubtitleMetadata',
              Icons.subtitles_off_rounded,
              'Informational only; subtitles are optional.'),
          _metric(
              'No indexed audio-track metadata',
              '$_missingAudioMetadata',
              Icons.audiotrack_rounded,
              'Informational only; some files expose tracks at runtime.'),
          _metric('Music albums missing artwork', '$_missingAlbumArtwork',
              Icons.album_rounded, 'Owned music tracks without album artwork.'),
          _metric(
              'Owned music tracks without audio URL',
              '$_missingAudioFiles',
              Icons.music_off_rounded,
              'Catalog-only discovery entries are excluded.'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: Text('Potential duplicate titles',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900))),
              Text('${duplicates.length} groups'),
            ],
          ),
          const SizedBox(height: 6),
          if (duplicates.isEmpty)
            const Text(
                'No duplicate title groups were detected by the current title/type/year matcher.')
          else
            ...duplicates.take(8).map((group) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.content_copy_rounded),
                    title: Text(group.normalizedTitle),
                    subtitle: Text(
                        '${group.items.length} records · ${group.mediaType} · ${group.releaseYear ?? 'year unknown'}${group.containsDifferentEditions ? ' · editions differ' : ''}'),
                    onTap: () =>
                        Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => const LibraryProtectionCenterScreen(
                          initialTabIndex: 1),
                    )),
                  ),
                )),
          const SizedBox(height: 18),
          Text('Repair queue',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text(
              'Select an item to open its details and review available metadata or playback settings. No records are changed automatically.'),
          const SizedBox(height: 6),
          if (findings.isEmpty)
            const Text('No findings from the current catalog audit.')
          else
            ...findings.take(30).map(_findingTile),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const LibraryProtectionCenterScreen(),
            )),
            icon: const Icon(Icons.shield_outlined),
            label: const Text('Open Backup & Recovery Center'),
          ),
          const SizedBox(height: 10),
          const Text(
            'Limitations: these checks inspect indexed metadata and URL shape, not remote server availability. An empty direct URL is not proof that an item cannot play. Potential duplicates are review suggestions only; editions are never merged or deleted automatically. The backup center stores local settings checkpoints and exports a sanitized metadata snapshot; it does not back up movie/music files or replace a server database backup.',
            style: TextStyle(fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}
