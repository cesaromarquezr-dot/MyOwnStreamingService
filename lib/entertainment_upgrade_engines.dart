import 'music.dart';

/// Relationship results are derived only from explicit imported/catalog
/// relationship fields. This engine never infers a soundtrack link from a
/// similar title or artist name.
class MusicRelationshipEngine {
  const MusicRelationshipEngine._();

  /// True only for media imported into this account's own music library.
  /// Demo previews and external catalogue search results are never treated as
  /// owned files for health audits, profile totals or music relationships.
  static bool isOwnedTrack(MusicTrack track) {
    final id = track.id.toLowerCase();
    return !track.catalogOnly &&
        !id.startsWith('demo-catalog-track-') &&
        !id.startsWith('demo-preview-album-track-') &&
        track.addedSource.toLowerCase() != 'external-catalog';
  }

  static List<MusicTrack> ownedTracks(Iterable<MusicTrack> tracks) =>
      tracks.where(isOwnedTrack).toList(growable: false);

  static List<MusicTrack> collaborations(Iterable<MusicTrack> tracks) =>
      ownedTracks(tracks)
          .where((track) => track.featuredArtists
              .any((artist) => artist.trim().isNotEmpty))
          .toList(growable: false);

  static List<MusicTrack> soundtrackLinked(Iterable<MusicTrack> tracks) =>
      ownedTracks(tracks)
          .where((track) => track.soundtrackForTitles
                  .any((title) => title.trim().isNotEmpty) ||
              track.relatedMediaTitles.any((title) => title.trim().isNotEmpty))
          .toList(growable: false);

  static Map<String, int> collaborationArtistCounts(
      Iterable<MusicTrack> tracks) {
    final counts = <String, int>{};
    for (final track in collaborations(tracks)) {
      final artists = <String>{
        track.artist.trim(),
        ...track.featuredArtists.map((value) => value.trim()),
      }..removeWhere((value) => value.isEmpty);
      for (final artist in artists) {
        counts.update(artist, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    return counts;
  }

  static List<String> linkedMediaTitles(MusicTrack track) {
    final titles = <String>{
      ...track.soundtrackForTitles.map((value) => value.trim()),
      ...track.relatedMediaTitles.map((value) => value.trim()),
    }.where((value) => value.isNotEmpty).toList();
    titles.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return titles;
  }
}
