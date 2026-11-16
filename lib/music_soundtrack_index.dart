import 'package:my_own_streaming_service/music.dart';

import 'featured_soundtrack_catalog.dart';

/// Search adapter for source-backed soundtrack relationships.
///
/// The standalone catalogue is also consumed by media Details pages. This
/// adapter converts entries into catalog-only MusicTrack records for Smart
/// Search without claiming that a local audio file is owned or playable.
class MusicSoundtrackIndex {
  MusicSoundtrackIndex._();

  static List<FeaturedSoundtrackEntry> get seeds =>
      FeaturedSoundtrackCatalog.entries;

  static MusicTrack _asCatalogTrack(FeaturedSoundtrackEntry seed) => MusicTrack(
        id: 'soundtrack-index:${seed.key}',
        title: seed.title,
        artist: seed.artist,
        album: seed.album,
        featuredArtists: seed.creditedArtists,
        soundtrackForTitles: seed.mediaTitles,
        relatedMediaTitles: seed.mediaTitles,
        credits: <String>[
          seed.relationshipLabel,
          'Soundtrack kind: ${seed.kind.name}.',
          if (seed.isCoverOrAlternateVersion) 'Cover or alternate recording.',
          if (seed.creditedArtists.isNotEmpty)
            'Additional credited performers: ${seed.creditedArtists.join(', ')}.',
          if ((seed.placementNote ?? '').trim().isNotEmpty) seed.placementNote!,
          'Soundtrack relationship source: ${seed.sourceName}.',
        ],
        soundtrackSourceName: seed.sourceName,
        soundtrackSourceUrl: seed.sourceUrl,
        providerName: 'Spotify search',
        providerUrl:
            'https://open.spotify.com/search/${Uri.encodeComponent('${seed.title} ${seed.artist}')}',
        catalogOnly: true,
        addedSource: 'verified-soundtrack-index',
      );

  static List<MusicTrack> search(String query) {
    final cleaned = query.trim();
    if (cleaned.isEmpty) return <MusicTrack>[];
    return FeaturedSoundtrackCatalog.search(cleaned)
        .map(_asCatalogTrack)
        .toList(growable: false);
  }
}
