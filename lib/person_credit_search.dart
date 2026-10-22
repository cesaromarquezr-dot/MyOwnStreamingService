/// Parses conversational searches for all works connected to one person.
///
/// Examples:
/// - "Adam Sandler movies"
/// - "Jim Carrey movies and shows"
/// - "Selena Gomez movies, shows, and songs"
///
/// This class intentionally matches catalog credits; it does not manufacture
/// credits for a person or imply that an unavailable item can be played.
class PersonCreditQuery {
  final String personName;
  final bool includeMovies;
  final bool includeShows;
  final bool includeSongs;

  const PersonCreditQuery({
    required this.personName,
    required this.includeMovies,
    required this.includeShows,
    required this.includeSongs,
  });

  bool get includeAllMedia => includeMovies && includeShows && includeSongs;

  static PersonCreditQuery? parse(String rawQuery) {
    var cleaned = rawQuery
        .replaceAll(RegExp(r"[^A-Za-z0-9À-ÖØ-öø-ÿ\u0100-\u024F'’\- ]+"), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return null;

    var tokens = cleaned.split(' ').where((token) => token.isNotEmpty).toList();
    // Strip common request prefixes first so "show me Adam Sandler movies"
    // doesn't confuse the verb "show" with the content category "shows".
    final prefixes = <List<String>>[
      ['tell', 'me', 'about'],
      ['search', 'for'],
      ['find', 'me'],
      ['get', 'me'],
      ['give', 'me'],
      ['show', 'me'],
      ['what', 'are'],
      ['who', 'are'],
    ];
    var changed = true;
    while (changed && tokens.isNotEmpty) {
      changed = false;
      for (final prefix in prefixes) {
        if (tokens.length >= prefix.length &&
            List<String>.generate(prefix.length, (i) => tokens[i].toLowerCase())
                    .join(' ') ==
                prefix.join(' ')) {
          tokens = tokens.skip(prefix.length).toList();
          changed = true;
          break;
        }
      }
      if (!changed &&
          tokens.isNotEmpty &&
          const {'find', 'search', 'list', 'recommend', 'get', 'show'}
              .contains(tokens.first.toLowerCase())) {
        tokens = tokens.skip(1).toList();
        changed = true;
      }
    }

    final lower = tokens.map((token) => token.toLowerCase()).toList();
    var includeMovies = lower.any(
        (token) => const {'movie', 'movies', 'film', 'films'}.contains(token));
    var includeShows = lower.any((token) =>
        const {'show', 'shows', 'series', 'television', 'tv'}.contains(token));
    var includeSongs = lower.any((token) => const {
          'song',
          'songs',
          'music',
          'track',
          'tracks',
          'discography'
        }.contains(token));
    final allWorkQuery = lower.any((token) => const {
              'filmography',
              'discography',
              'credits',
              'career'
            }.contains(token)) ||
        (lower.contains('all') && lower.contains('work'));

    if (!includeMovies && !includeShows && !includeSongs && !allWorkQuery) {
      return null;
    }
    if (allWorkQuery) {
      includeMovies = true;
      includeShows = true;
      includeSongs = true;
    }

    const categoryWords = <String>{
      'movie',
      'movies',
      'film',
      'films',
      'show',
      'shows',
      'series',
      'television',
      'tv',
      'song',
      'songs',
      'music',
      'track',
      'tracks',
      'discography',
      'filmography',
      'credits',
      'credit',
      'career',
      'work',
      'all',
      'and',
      'or',
      'by',
      'featuring',
      'feat',
      'with',
      'please',
      'find',
      'search',
      'list',
      'recommend',
      'get',
      'give',
      'tell',
      'me',
      'about',
      'what',
      'are',
      'who',
      'actor',
      'actress',
      'singer',
      'artist',
      'performer',
    };
    final nameTokens = <String>[];
    for (final token in tokens) {
      if (!categoryWords.contains(token.toLowerCase())) nameTokens.add(token);
    }
    final personName = nameTokens.join(' ').trim();
    if (personName.isEmpty ||
        !RegExp(r'[A-Za-zÀ-ÖØ-öø-ÿ]').hasMatch(personName)) {
      return null;
    }
    return PersonCreditQuery(
      personName: personName,
      includeMovies: includeMovies,
      includeShows: includeShows,
      includeSongs: includeSongs,
    );
  }

  bool matchesMediaType(String rawType) {
    final type = _normalize(rawType).replaceAll(' ', '');
    final movie = const {'movie', 'movies', 'film', 'films', 'featurefilm'}
        .contains(type);
    final show = const {
      'show',
      'shows',
      'tvshow',
      'tvshows',
      'tvseries',
      'series',
      'television',
      'televisionseries',
      'televisionshow'
    }.contains(type);
    return (includeMovies && movie) || (includeShows && show);
  }

  bool matchesMediaCredits({
    Iterable<String> actors = const [],
    Iterable<String> directors = const [],
    Iterable<String> writers = const [],
    Iterable<String> music = const [],
  }) =>
      matchesAnyName(<String>[
        ...actors,
        ...directors,
        ...writers,
        ...music,
      ]);

  bool matchesAnyName(Iterable<String> candidateNames) => candidateNames
      .any((candidate) => namesLikelyMatch(personName, candidate));

  bool matchesTrack(
      {required String artist, Iterable<String> featuredArtists = const []}) {
    if (!includeSongs) return false;
    return namesLikelyMatch(personName, artist) ||
        featuredArtists
            .any((artistName) => namesLikelyMatch(personName, artistName));
  }

  /// A conservative name matcher supporting one-character typos in long names
  /// (e.g. "Selina Gomez" against a catalog credit for "Selena Gomez").
  static bool namesLikelyMatch(String queryName, String candidateName) {
    final query = _normalize(queryName);
    final candidate = _normalize(candidateName);
    if (query.isEmpty || candidate.isEmpty) return false;
    if (query == candidate ||
        candidate.contains(query) ||
        query.contains(candidate)) {
      return true;
    }
    final expected =
        query.split(' ').where((token) => token.isNotEmpty).toList();
    final actual =
        candidate.split(' ').where((token) => token.isNotEmpty).toList();
    if (expected.isEmpty || actual.isEmpty) return false;
    return expected.every((word) => actual.any((candidateWord) {
          if (word == candidateWord) return true;
          if ((word.length - candidateWord.length).abs() > 1 ||
              word.length < 4) {
            return false;
          }
          return _editDistanceAtMostOne(word, candidateWord);
        }));
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9À-ÖØ-öø-ÿ\u0100-\u024F]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static bool _editDistanceAtMostOne(String left, String right) {
    if (left == right) return true;
    if ((left.length - right.length).abs() > 1) return false;
    var i = 0;
    var j = 0;
    var edits = 0;
    while (i < left.length && j < right.length) {
      if (left[i] == right[j]) {
        i++;
        j++;
        continue;
      }
      edits++;
      if (edits > 1) return false;
      if (left.length > right.length) {
        i++;
      } else if (right.length > left.length) {
        j++;
      } else {
        i++;
        j++;
      }
    }
    if (i < left.length || j < right.length) edits++;
    return edits <= 1;
  }
}
