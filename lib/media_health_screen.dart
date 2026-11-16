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

  List<IncompleteSeasonFinding> get _incompleteSeasons =>
      LibraryProtectionService.findIncompleteSeasons(_media);

  List<_CollectionSuggestion> get _collectionSuggestions {
    final groups = <String, _CollectionSuggestion>{};
    void add(String name, String kind, MediaItem item) {
      final clean = name.trim();
      if (clean.isEmpty) return;
      final title = switch (kind) {
        'Genre' => '$clean Collection',
        'Studio / company' => '$clean Studio Collection',
        _ => '$clean Franchise Collection',
      };
      final key = title.toLowerCase();
      final existing = groups.putIfAbsent(
        key,
        () => _CollectionSuggestion(
          name: title,
          kind: kind,
          description:
              'A suggested collection grouped from verified $kind metadata in your library.',
          items: <MediaItem>{},
        ),
      );
      existing.items.add(item);
    }

    for (final item in _media) {
      for (final value in <String>{
        if ((item.franchiseName ?? '').trim().isNotEmpty)
          item.franchiseName!.trim(),
        ...item.franchiseNames
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty),
        ...item.cinematicUniverseNames
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty),
      }) {
        add(value, 'Franchise / universe', item);
      }
      for (final value in <String>{
        ...item.studios
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty),
        ...item.companies
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty),
      }) {
        add(value, 'Studio / company', item);
      }
      for (final value in item.genres
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)) {
        add(value, 'Genre', item);
      }
    }

    final existingNames = _app.collections
        .map((collection) => collection.name.trim().toLowerCase())
        .toSet();
    final suggestions = groups.values
        .where((suggestion) =>
            suggestion.items.length >= 3 &&
            !existingNames.contains(suggestion.name.toLowerCase()))
        .toList();
    suggestions.sort((a, b) => b.items.length.compareTo(a.items.length));
    return suggestions.take(8).toList(growable: false);
  }

  List<List<MusicTrack>> get _duplicateMusicGroups {
    String normalize(String value) => value
        .toLowerCase()
        .replaceAll(RegExp(r'\([^)]*\)|\[[^]]*\]'), ' ')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');

    final grouped = <String, List<MusicTrack>>{};
    for (final track in _ownedTracks) {
      final title = normalize(track.title);
      final artist = normalize(track.artist);
      if (title.isEmpty || artist.isEmpty) continue;
      grouped.putIfAbsent('$artist|$title', () => <MusicTrack>[]).add(track);
    }
    final result = grouped.values
        .where((tracks) => tracks.length > 1)
        .map((tracks) => List<MusicTrack>.unmodifiable(tracks))
        .toList();
    result.sort((a, b) {
      final byArtist =
          a.first.artist.toLowerCase().compareTo(b.first.artist.toLowerCase());
      return byArtist != 0
          ? byArtist
          : a.first.title.toLowerCase().compareTo(b.first.title.toLowerCase());
    });
    return result;
  }

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
    final incompleteSeasons = _incompleteSeasons;
    final duplicateMusicGroups = _duplicateMusicGroups;
    final collectionSuggestions = _collectionSuggestions;
    final issueCount = _missingArtwork +
        _missingDescriptions +
        _missingPlaybackSources +
        _missingAlbumArtwork +
        _missingAudioFiles +
        incompleteSeasons.length;

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
          _metric(
              'Incomplete indexed TV seasons',
              '${incompleteSeasons.length}',
              Icons.live_tv_outlined,
              'Only authoritative episode counts or gaps in observed numbering are used.'),
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
          Row(
            children: [
              Expanded(
                  child: Text('TV season completeness',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900))),
              Text('${incompleteSeasons.length} seasons'),
            ],
          ),
          const SizedBox(height: 6),
          if (incompleteSeasons.isEmpty)
            const Text(
                'No missing episode numbers were found in the currently indexed season metadata.')
          else
            ...incompleteSeasons.take(20).map((finding) {
              final missing = finding.missingEpisodeNumbers;
              final missingLabel = missing.isEmpty
                  ? 'Episode list is shorter than the expected count.'
                  : 'Missing ${missing.take(12).map((number) => 'E${number.toString().padLeft(2, '0')}').join(', ')}${missing.length > 12 ? ', …' : ''}';
              final expected = finding.expectedEpisodeCount == null
                  ? 'numbering gap in indexed data'
                  : '${finding.actualEpisodeCount}/${finding.expectedEpisodeCount} indexed episodes';
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.playlist_remove_rounded),
                  title: Text(
                      '${finding.seriesTitle} · Season ${finding.seasonNumber}'),
                  subtitle: Text('$expected · $missingLabel'),
                  onTap: () => _openMedia(finding.mediaId),
                ),
              );
            }),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                  child: Text('Potential duplicate music tracks',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900))),
              Text('${duplicateMusicGroups.length} groups'),
            ],
          ),
          const SizedBox(height: 6),
          if (duplicateMusicGroups.isEmpty)
            const Text(
                'No repeated artist/title pairs were found in the owned music catalog.')
          else
            ...duplicateMusicGroups.take(12).map((group) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.library_music_outlined),
                    title: Text('${group.first.title} · ${group.first.artist}',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                        '${group.length} tracks · ${group.map((track) => track.album).where((album) => album.trim().isNotEmpty).toSet().join(' / ')}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ),
                )),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                  child: Text('Suggested collections',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900))),
              Text('${collectionSuggestions.length} ideas'),
            ],
          ),
          const SizedBox(height: 6),
          if (collectionSuggestions.isEmpty)
            const Text(
                'No new collection suggestions are available. Suggestions require at least three library items sharing verified genre, studio, company, franchise or universe metadata.')
          else
            ...collectionSuggestions.map((suggestion) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.collections_bookmark_outlined),
                    title: Text(suggestion.name),
                    subtitle: Text(
                        '${suggestion.items.length} titles · ${suggestion.kind}'),
                    trailing: IconButton(
                      tooltip: 'Create ${suggestion.name}',
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      onPressed: () {
                        final collection = _app.createCollection(
                          name: suggestion.name,
                          description: suggestion.description,
                          mediaIds: suggestion.items.map((item) => item.id),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Created ${collection.name}')),
                        );
                      },
                    ),
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
            'Limitations: these checks inspect indexed metadata and URL shape, not remote server availability. An empty direct URL is not proof that an item cannot play. Potential title/music duplicates and missing episodes are review suggestions only; editions are never merged or deleted automatically. Trailing episode gaps are not inferred unless a season declares its expected episode count. The backup center stores local settings checkpoints and exports a sanitized metadata snapshot; it does not back up movie/music files or replace a server database backup.',
            style: TextStyle(fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _CollectionSuggestion {
  final String name;
  final String kind;
  final String description;
  final Set<MediaItem> items;

  _CollectionSuggestion({
    required this.name,
    required this.kind,
    required this.description,
    required this.items,
  });
}
