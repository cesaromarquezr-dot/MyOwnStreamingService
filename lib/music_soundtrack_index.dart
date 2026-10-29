import 'package:my_own_streaming_service/music.dart';

/// Verifiable soundtrack-to-media relationships used as a search safety net.
/// The catalog providers remain dynamic; this compact index only fills gaps in
/// cross-media relationships that general music search APIs often omit.
class MusicSoundtrackSeed {
  const MusicSoundtrackSeed({
    required this.key,
    required this.title,
    required this.artist,
    required this.album,
    required this.mediaTitles,
    required this.sourceName,
    required this.sourceUrl,
    this.artistAliases = const <String>[],
    this.titleAliases = const <String>[],
  });

  final String key;
  final String title;
  final String artist;
  final String album;
  final List<String> mediaTitles;
  final String sourceName;
  final String sourceUrl;
  final List<String> artistAliases;
  final List<String> titleAliases;

  static String _compact(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');

  bool matchesQuery(String query) {
    final needle = _compact(query.trim());
    if (needle.isEmpty) return false;
    final franchiseTokens = <String>['spiderman', 'spidey', 'peterparker'];
    if (franchiseTokens.contains(needle)) return mediaTitles.any((title) => _compact(title).contains('spider'));
    final haystack = <String>{
      title,
      artist,
      album,
      ...mediaTitles,
      ...artistAliases,
      ...titleAliases,
    }.map(_compact).where((value) => value.isNotEmpty);
    return haystack.any((value) => value.contains(needle) || (needle.length >= 4 && needle.contains(value)));
  }

  MusicTrack asCatalogTrack() => MusicTrack(
        id: 'soundtrack-index:$key',
        title: title,
        artist: artist,
        album: album,
        soundtrackForTitles: mediaTitles,
        relatedMediaTitles: mediaTitles,
        credits: <String>['Soundtrack relationship verified against a cited soundtrack reference.'],
        soundtrackSourceName: sourceName,
        soundtrackSourceUrl: sourceUrl,
        providerName: 'Spotify search',
        providerUrl: 'https://open.spotify.com/search/${Uri.encodeComponent('$title $artist')}',
        catalogOnly: true,
        addedSource: 'verified-soundtrack-index',
      );
}

class MusicSoundtrackIndex {
  MusicSoundtrackIndex._();

  /// Starter franchise index. Extend this list from licensed/media-intelligence
  /// relationship records; do not derive a relationship from title similarity.
  static const List<MusicSoundtrackSeed> seeds = <MusicSoundtrackSeed>[
    MusicSoundtrackSeed(
      key: 'brand-new-day-eoo',
      title: 'EoO',
      artist: 'Bad Bunny',
      album: '',
      mediaTitles: <String>['Spider-Man: Brand New Day'],
      sourceName: 'Radio Times soundtrack guide',
      sourceUrl: 'https://www.radiotimes.com/movies/scifi/spider-man-brand-new-day-soundtrack/',
    ),
    MusicSoundtrackSeed(
      key: 'brand-new-day-wolf-like-me',
      title: 'Wolf Like Me',
      artist: 'TV on the Radio',
      album: 'Return to Cookie Mountain',
      mediaTitles: <String>['Spider-Man: Brand New Day'],
      sourceName: 'Radio Times soundtrack guide',
      sourceUrl: 'https://www.radiotimes.com/movies/scifi/spider-man-brand-new-day-soundtrack/',
    ),
    MusicSoundtrackSeed(
      key: 'brand-new-day-im-every-woman',
      title: "I'm Every Woman",
      artist: 'Chaka Khan',
      album: 'Chaka',
      mediaTitles: <String>['Spider-Man: Brand New Day'],
      sourceName: 'Radio Times soundtrack guide',
      sourceUrl: 'https://www.radiotimes.com/movies/scifi/spider-man-brand-new-day-soundtrack/',
    ),
    MusicSoundtrackSeed(
      key: 'brand-new-day-monopoly',
      title: 'Monopoly',
      artist: 'Monetochka',
      album: '',
      mediaTitles: <String>['Spider-Man: Brand New Day'],
      sourceName: 'Radio Times soundtrack guide',
      sourceUrl: 'https://www.radiotimes.com/movies/scifi/spider-man-brand-new-day-soundtrack/',
    ),
    MusicSoundtrackSeed(
      key: 'brand-new-day-loser',
      title: 'Loser',
      artist: 'Tame Impala',
      album: '',
      mediaTitles: <String>['Spider-Man: Brand New Day'],
      sourceName: 'Radio Times soundtrack guide',
      sourceUrl: 'https://www.radiotimes.com/movies/scifi/spider-man-brand-new-day-soundtrack/',
    ),
    MusicSoundtrackSeed(
      key: 'brand-new-day-fire-for-you',
      title: 'Fire for You',
      artist: 'Cannons',
      album: 'Shadows',
      mediaTitles: <String>['Spider-Man: Brand New Day'],
      sourceName: 'Radio Times soundtrack guide',
      sourceUrl: 'https://www.radiotimes.com/movies/scifi/spider-man-brand-new-day-soundtrack/',
    ),
    MusicSoundtrackSeed(
      key: 'brand-new-day-st-elmos-fire',
      title: "St. Elmo's Fire",
      artist: 'Brian Eno',
      album: 'Another Green World',
      mediaTitles: <String>['Spider-Man: Brand New Day'],
      sourceName: 'Radio Times soundtrack guide',
      sourceUrl: 'https://www.radiotimes.com/movies/scifi/spider-man-brand-new-day-soundtrack/',
    ),
    MusicSoundtrackSeed(
      key: 'brand-new-day-oh-yeah',
      title: 'Oh yeah?',
      artist: 'Steve Lacy',
      album: '',
      mediaTitles: <String>['Spider-Man: Brand New Day'],
      sourceName: 'Radio Times soundtrack guide',
      sourceUrl: 'https://www.radiotimes.com/movies/scifi/spider-man-brand-new-day-soundtrack/',
    ),
    MusicSoundtrackSeed(
      key: 'brand-new-day-dame-tu-amistad',
      title: 'Dame Tu Amistad',
      artist: 'Dominique Patrick Noel, Hector Luis Pagan, Eduardo Padua & Eddie Montalvo',
      album: '',
      mediaTitles: <String>['Spider-Man: Brand New Day'],
      sourceName: 'Radio Times soundtrack guide',
      sourceUrl: 'https://www.radiotimes.com/movies/scifi/spider-man-brand-new-day-soundtrack/',
    ),
    MusicSoundtrackSeed(
      key: 'brand-new-day-party-in-the-usa',
      title: 'Party in the U.S.A.',
      artist: 'Miley Cyrus',
      album: 'The Time of Our Lives',
      mediaTitles: <String>['Spider-Man: Brand New Day'],
      sourceName: 'Radio Times soundtrack guide',
      sourceUrl: 'https://www.radiotimes.com/movies/scifi/spider-man-brand-new-day-soundtrack/',
    ),
    MusicSoundtrackSeed(
      key: 'spiderman-hero',
      title: 'Hero',
      artist: 'Chad Kroeger feat. Josey Scott',
      album: 'Music from and Inspired by Spider-Man',
      mediaTitles: <String>['Spider-Man (2002)'],
      artistAliases: <String>['Nickelback', 'Josey Scott', 'Chad Kroeger feat. Josey Scott'],
      sourceName: 'IMDb soundtrack credits',
      sourceUrl: 'https://www.imdb.com/title/tt0145487/soundtrack/',
    ),
    MusicSoundtrackSeed(
      key: 'spiderman-2-raindrops',
      title: 'Raindrops Keep Fallin’ on My Head',
      artist: 'B. J. Thomas',
      album: '',
      mediaTitles: <String>['Spider-Man 2 (2004)'],
      artistAliases: <String>['B.J. Thomas', 'BJ Thomas'],
      titleAliases: <String>['Raindrops Keep Falling on My Head'],
      sourceName: 'IMDb soundtrack credits',
      sourceUrl: 'https://www.imdb.com/title/tt0316654/soundtrack/',
    ),
    MusicSoundtrackSeed(
      key: 'spiderman-3-funky-soul',
      title: 'People Get Up and Drive Your Funky Soul (Remix)',
      artist: 'James Brown',
      album: '',
      mediaTitles: <String>['Spider-Man 3 (2007)', 'Spider-Man: Into the Spider-Verse'],
      titleAliases: <String>['People Get Up And Drive Your Funky Soul', 'Funky Soul Remix'],
      sourceName: 'WhatSong soundtrack guide',
      sourceUrl: 'https://www.whatsong.org/movie/spider-man-3',
    ),
    MusicSoundtrackSeed(
      key: 'spiderman-into-spider-verse-sunflower',
      title: 'Sunflower',
      artist: 'Post Malone & Swae Lee',
      album: 'Spider-Man: Into the Spider-Verse (Soundtrack from & Inspired by the Motion Picture)',
      mediaTitles: <String>['Spider-Man: Into the Spider-Verse'],
      artistAliases: <String>['Post Malone', 'Swae Lee'],
      sourceName: 'IMDb soundtrack credits',
      sourceUrl: 'https://www.imdb.com/es-es/title/tt4633694/soundtrack/',
    ),
    MusicSoundtrackSeed(
      key: 'amazing-spiderman-2-gone-gone-gone',
      title: 'Gone, Gone, Gone',
      artist: 'Phillip Phillips',
      album: 'The World from the Side of the Moon',
      mediaTitles: <String>['The Amazing Spider-Man 2 (2014)'],
      sourceName: 'Soundtrack Radar',
      sourceUrl: 'https://soundtrackradar.com/the-amazing-spider-man-2-soundtrack/',
    ),
    MusicSoundtrackSeed(
      key: 'no-way-home-magic-number',
      title: 'The Magic Number',
      artist: 'De La Soul',
      album: '3 Feet High and Rising',
      mediaTitles: <String>['Spider-Man: No Way Home'],
      titleAliases: <String>['Three Is a Magic Number', '3 Is the Magic Number'],
      sourceName: 'De La Soul official store',
      sourceUrl: 'https://store.wearedelasoul.com/products/the-magic-number-cassingle',
    ),
  ];

  static List<MusicTrack> search(String query) {
    final cleaned = query.trim();
    if (cleaned.isEmpty) return <MusicTrack>[];
    return seeds.where((seed) => seed.matchesQuery(cleaned))
        .map((seed) => seed.asCatalogTrack())
        .toList(growable: false);
  }
}
