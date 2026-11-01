import 'music.dart';
import 'themed_episode_engine.dart';

/// A confidently identified theme for an imported music track.
class ThemedSongMatch {
  const ThemedSongMatch({
    required this.key,
    required this.label,
    required this.confidence,
    required this.seasonalPriority,
  });

  final String key;
  final String label;
  final int confidence;
  final int seasonalPriority;
}

class _CuratedSong {
  const _CuratedSong({
    required this.title,
    required this.artists,
    this.titleAliases = const <String>[],
  });

  final String title;
  final List<String> artists;
  final List<String> titleAliases;
}

/// Matches music in the user's imported library to holidays and other themes.
///
/// Curated matches use both the song title and credited artist so a cover with
/// the same title is not silently treated as the canonical recording. Metadata
/// matching is a lower-confidence fallback for properly tagged albums/tracks.
class ThemedSongEngine {
  ThemedSongEngine._();

  static const Map<String, List<_CuratedSong>> _curated =
      <String, List<_CuratedSong>>{
    'halloween': <_CuratedSong>[
      _CuratedSong(
        title: 'Thriller',
        artists: <String>['Michael Jackson'],
      ),
      _CuratedSong(
        title: 'Ghostbusters',
        artists: <String>['Ray Parker Jr.', 'Ray Parker'],
        titleAliases: <String>['Ghost Busters'],
      ),
      _CuratedSong(
        title: 'Monster Mash',
        artists: <String>[
          'Bobby "Boris" Pickett & The Crypt-Kickers',
          'Bobby Boris Pickett',
          'Bobby Pickett',
          'The Crypt-Kickers',
        ],
      ),
      _CuratedSong(
        title: "Somebody's Watching Me",
        artists: <String>['Rockwell'],
        titleAliases: <String>['Somebody Is Watching Me'],
      ),
      _CuratedSong(
        title: 'Calling All the Monsters',
        artists: <String>['China Anne McClain'],
      ),
      _CuratedSong(
        title: 'This Is Halloween',
        artists: <String>[
          'The Citizens of Halloween',
          'Citizens of Halloweentown',
          'Danny Elfman',
        ],
      ),
    ],
    'christmas': <_CuratedSong>[
      _CuratedSong(
        title: 'All I Want for Christmas Is You',
        artists: <String>['Mariah Carey'],
        titleAliases: <String>['All I Want for Christmas'],
      ),
      _CuratedSong(
        title: "Rockin' Around the Christmas Tree",
        artists: <String>['Brenda Lee'],
        titleAliases: <String>['Rocking Around the Christmas Tree'],
      ),
      _CuratedSong(
        title: 'Underneath the Tree',
        artists: <String>['Kelly Clarkson'],
      ),
      _CuratedSong(
        title: 'Jingle Bell Rock',
        artists: <String>['Bobby Helms'],
      ),
      _CuratedSong(
        title: 'Last Christmas',
        artists: <String>['Wham!'],
      ),
      _CuratedSong(
        title: 'Santa Tell Me',
        artists: <String>['Ariana Grande'],
      ),
      _CuratedSong(
        title: 'Sleigh Ride',
        artists: <String>['The Ronettes'],
      ),
      _CuratedSong(
        title: 'Let It Snow! Let It Snow! Let It Snow!',
        artists: <String>['Dean Martin'],
        titleAliases: <String>['Let It Snow'],
      ),
      _CuratedSong(
        title: 'It\'s Beginning to Look a Lot Like Christmas',
        artists: <String>['Michael Bublé', 'Michael Buble'],
        titleAliases: <String>['Its Beginning to Look a Lot Like Christmas'],
      ),
      _CuratedSong(
        title: 'A Holly Jolly Christmas',
        artists: <String>['Burl Ives'],
      ),
      _CuratedSong(
        title: 'It\'s the Most Wonderful Time of the Year',
        artists: <String>['Andy Williams'],
        titleAliases: <String>['The Most Wonderful Time of the Year'],
      ),
    ],
  };

  static String normalize(String value) => value
      .toLowerCase()
      .replaceAll('&', ' and ')
      .replaceAll(RegExp(r"[^a-z0-9]+"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static bool _artistMatches(String actual, Iterable<String> expected) {
    final normalizedActual = normalize(actual);
    if (normalizedActual.isEmpty) return false;
    for (final artist in expected) {
      final normalizedExpected = normalize(artist);
      if (normalizedExpected.isEmpty) continue;
      if (normalizedActual == normalizedExpected ||
          normalizedActual.contains(normalizedExpected) ||
          normalizedExpected.contains(normalizedActual)) {
        return true;
      }
    }
    return false;
  }

  static List<ThemedSongMatch> matchesForTrack(
    MusicTrack track, {
    DateTime? date,
  }) {
    final trackTitle = normalize(track.title);
    if (trackTitle.isEmpty) return const <ThemedSongMatch>[];

    final creditedArtists = <String>[
      track.artist,
      ...track.featuredArtists,
    ].where((value) => value.trim().isNotEmpty).toList(growable: false);
    final bestByTheme = <String, int>{};
    for (final entry in _curated.entries) {
      for (final song in entry.value) {
        final aliases = <String>{
          normalize(song.title),
          ...song.titleAliases.map(normalize),
        }..remove('');
        final titleMatches = aliases.any((alias) =>
            trackTitle == alias ||
            trackTitle.startsWith('$alias ') ||
            trackTitle.endsWith(' $alias'));
        if (!titleMatches) continue;

        final hasArtistMetadata = creditedArtists.isNotEmpty;
        final artistMatches = creditedArtists.any(
          (actual) => _artistMatches(actual, song.artists),
        );
        if (hasArtistMetadata && !artistMatches) continue;
        final confidence = artistMatches ? 100 : 86;
        final previous = bestByTheme[entry.key] ?? 0;
        if (confidence > previous) bestByTheme[entry.key] = confidence;
      }
    }

    // Use the same metadata intelligence as themed movies/episodes for tracks
    // tagged with a holiday or theme, e.g. an imported compilation album named
    // "Halloween Hits". This is intentionally lower confidence than a curated
    // title-and-artist recording match.
    final metadataMatches = ThemedEpisodeEngine.detectMediaMatches(
      title: track.title,
      description: track.album,
      genres: track.allGenreTags,
      date: date,
    );
    for (final match in metadataMatches) {
      final previous = bestByTheme[match.key] ?? 0;
      final confidence = match.confidence.clamp(1, 78).toInt();
      if (confidence > previous) bestByTheme[match.key] = confidence;
    }

    final matches = <ThemedSongMatch>[
      for (final entry in bestByTheme.entries)
        ThemedSongMatch(
          key: entry.key,
          label: ThemedEpisodeEngine.labelFor(entry.key),
          confidence: entry.value,
          seasonalPriority: ThemedEpisodeEngine.seasonalPriority(
            entry.key,
            date,
          ),
        ),
    ];
    matches.sort((a, b) {
      final seasonal = a.seasonalPriority.compareTo(b.seasonalPriority);
      if (seasonal != 0) return seasonal;
      return b.confidence.compareTo(a.confidence);
    });
    return matches;
  }

  static List<String> themesForTrack(MusicTrack track, {DateTime? date}) =>
      matchesForTrack(track, date: date)
          .map((match) => match.key)
          .toList(growable: false);

  /// A stable, human-readable list of seed recordings used by the Home shelves.
  /// This is metadata only; it never creates fake or playable library tracks.
  static Map<String, List<String>> get curatedSongTitles =>
      <String, List<String>>{
        for (final entry in _curated.entries)
          entry.key: entry.value.map((song) => song.title).toList(growable: false),
      };
}
