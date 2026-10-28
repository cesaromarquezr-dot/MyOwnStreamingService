// Shared helpers for cross-entity Smart Search and seasonal episode discovery.
//
// These aliases are search hints, not generated credits: the catalog's actual
// titles, cast, character, franchise, and episode metadata still determine
// what is displayed. A match is never treated as proof of a credit or ownership.
import 'app_core.dart';

class SmartSearchTheme {
  final String key;
  final String label;
  final String emoji;
  final int colorValue;
  final List<String> keywords;

  const SmartSearchTheme({
    required this.key,
    required this.label,
    required this.emoji,
    required this.colorValue,
    required this.keywords,
  });
}

class SmartSearchEpisodeHit {
  final MediaItem parent;
  final Map<String, dynamic> episode;
  final String title;
  final String? description;
  final String? imageUrl;
  final int? seasonNumber;
  final int? episodeNumber;
  final SmartSearchTheme theme;

  const SmartSearchEpisodeHit({
    required this.parent,
    required this.episode,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.theme,
  });

  String get positionLabel {
    if (seasonNumber == null && episodeNumber == null) {
      return 'Episode number unavailable';
    }
    final season = seasonNumber == null ? '' : 'S${seasonNumber!}';
    final episode = episodeNumber == null ? '' : 'E${episodeNumber!}';
    return '$season$episode'.trim();
  }
}

class SmartSearchIntelligence {
  SmartSearchIntelligence._();

  static const SmartSearchTheme halloween = SmartSearchTheme(
    key: 'halloween',
    label: 'Halloween',
    emoji: '🎃',
    colorValue: 0xFFFF8A00,
    keywords: <String>[
      'halloween', 'spooky', 'haunted', 'scary', 'horror', 'ghost', 'monster',
      'witch', 'vampire', 'pumpkin', 'costume', 'trick or treat', 'trick-or-treat',
      'fear itself', 'treehouse of horror', 'boos', 'boo', 'nightmare',
      'hauntening', 'scream', 'creepy',
    ],
  );

  static const SmartSearchTheme christmas = SmartSearchTheme(
    key: 'christmas',
    label: 'Holiday & Christmas',
    emoji: '🎄',
    colorValue: 0xFF2DA44E,
    keywords: <String>[
      'christmas', 'xmas', 'holiday', 'holidays', 'santa', 'reindeer', 'festive',
      'christmas eve', 'new year', 'winter break', 'holiday armadillo',
      'christmas party', 'undeck the halls', 'noel', 'noël', 'christmas waltz',
      'fishes', 'uncontrollable christmas', 'verandah santa', 'sabrina christmas',
      'carol of the bells', 'more the merrier', 'father christmas', 'christmas at the tipton',
      'twas the mission before christmas', 'simpsons roasting on an open fire',
    ],
  );

  static const List<SmartSearchTheme> themes = <SmartSearchTheme>[
    halloween,
    christmas,
  ];

  // Curated episode-title aliases supplement explicit tags/keywords. They only
  // match the named show plus the named episode, avoiding false-positive
  // labeling of every episode in a series. Catalog season/episode metadata is
  // still required before an episode can appear in results.
  static const Map<String, List<String>> _halloweenEpisodeAliases =
      <String, List<String>>{
    'wizards of waverly place': <String>['halloween'],
    'the simpsons': <String>['treehouse of horror', 'halloween of horror'],
    'brooklyn nine nine': <String>['halloween', 'halloween heist', 'halloveen'],
    'buffy the vampire slayer': <String>['halloween', 'fear itself'],
    'the office': <String>['halloween', 'costume contest'],
    'stranger things': <String>['trick or treat freak'],
    'abbott elementary': <String>['candy zombies'],
    'bojack horseman': <String>['mr peanutbutters boos'],
    'parks recreation': <String>['halloween surprise', 'meet n greet'],
    'psych': <String>['scary sherry biancas toast', 'tuesday the 17th'],
    'bobs burgers': <String>['the hauntening', 'full bars'],
    'south park': <String>['a nightmare on facetime'],
    'friends': <String>['the one with the halloween party'],
    'family guy': <String>['halloween on spooner street', 'petergeist'],
  };

  static const Map<String, List<String>> _holidayEpisodeAliases =
      <String, List<String>>{
    'friends': <String>['the one with the holiday armadillo'],
    'seinfeld': <String>['the strike'],
    'the office': <String>['christmas party'],
    'modern family': <String>['undeck the halls'],
    'the west wing': <String>['noel'],
    'mad men': <String>['christmas waltz'],
    'the bear': <String>['fishes'],
    'community': <String>['abeds uncontrollable christmas'],
    'the simpsons': <String>['simpsons roasting on an open fire'],
    'bluey': <String>['verandah santa'],
    'bojack horseman': <String>['sabrinas christmas wish'],
    'ted lasso': <String>['carol of the bells'],
    'virgin river': <String>['the more the merrier', 'father christmas'],
    'hannah montana': <String>['killing me softly with his height'],
    'thats so raven': <String>['escape clause'],
    'the suite life of zack cody': <String>['christmas at the tipton'],
    'lab rats': <String>['twas the mission before christmas', 'halloween'],
  };

  /// Normalizes punctuation and spacing so Spider-Man, Spider Man, and
  /// SpiderMan can match the same catalog identity without changing display text.
  static String normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String compact(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Curated query expansion for common multi-identity franchises and aliases.
  /// The catalog still decides whether a matching item exists and is accessible.
  static List<String> relatedTerms(String rawQuery) {
    final query = normalize(rawQuery);
    final key = compact(query);
    if (key.isEmpty) return const <String>[];

    if (const <String>{
      'spider', 'spiderman', 'peterparker', 'milesmorales', 'spiderverse',
      'spidernoir', 'spidergwen', 'spiderwoman', 'spiderpunk', 'spiderham',
      'spiderman2099', 'miguelohara', 'hobiebrown', 'gwenstacy', 'benreilly',
    }.contains(key)) {
      return const <String>[
        'Spider-Man', 'Spider-Man 2', 'Spider-Man 3', 'The Amazing Spider-Man',
        'The Amazing Spider-Man 2', 'Captain America: Civil War',
        'Spider-Man: Homecoming', 'Avengers: Infinity War', 'Avengers: Endgame',
        'Spider-Man: Into the Spider-Verse', 'Spider-Man: Across the Spider-Verse',
        'Spider-Man: Far From Home', 'Spider-Man: No Way Home',
        'Spider-Man: Brand New Day', 'Spider-Man (1967)', 'Spider-Man (1981)',
        'Spider-Man and His Amazing Friends', 'Spider-Man: The Animated Series',
        'Spider-Man Unlimited', 'The New Animated Series', 'The Spectacular Spider-Man',
        'Ultimate Spider-Man', 'Spider-Man (2017)', 'Spidey and His Amazing Friends',
        'Your Friendly Neighborhood Spider-Man', 'Spider-Noir', 'Peter Parker',
        'Miles Morales', 'Spider-Gwen', 'Gwen Stacy', 'Spider-Man 2099',
        'Miguel O’Hara', 'Spider-Punk', 'Hobie Brown', 'Spider-Ham', 'Peter Porker',
        'Ben Reilly', 'Iron Spider', 'Tobey Maguire', 'Andrew Garfield',
        'Tom Holland', 'Paul Soles', 'Neil Patrick Harris', 'Christopher Daniel Barnes',
        'Drake Bell', 'Dan Gilvezan', 'Jake Johnson', 'Shameik Moore', 'Nicolas Cage',
        'Hailee Steinfeld', 'Oscar Isaac', 'Daniel Kaluuya', 'John Mulaney',
      ];
    }

    if (const <String>{
      'iron', 'ironman', 'tonystark', 'ironheart', 'ririwilliams',
    }.contains(key)) {
      return const <String>[
        'Iron Man', 'Iron Man 2', 'Iron Man 3', 'Iron Man: Armored Adventures',
        'The Super Hero Squad Show', 'Avengers', 'Avengers: Age of Ultron',
        'Avengers: Infinity War', 'Avengers: Endgame', 'Captain America: Civil War',
        'Spider-Man: Homecoming', 'Ironheart', 'Tony Stark', 'Riri Williams',
      ];
    }

    if (const <String>{
      'alexrusso', 'wizards', 'wizardsofwaverlyplace', 'alexvsalex',
    }.contains(key)) {
      return const <String>[
        'Alex Russo', 'Selena Gomez', 'Wizards of Waverly Place',
        'Wizards of Waverly Place: The Movie', 'The Wizards Return: Alex vs. Alex',
      ];
    }

    if (key == 'taylor') {
      return const <String>[
        'Taylor Swift', 'Taylor Lautner', 'The Ridiculous 6', 'The Twilight Saga',
      ];
    }

    return const <String>[];
  }

  /// Extra TMDB multi-searches for cross-franchise titles that a literal
  /// search would otherwise miss (for example, Spider-Man -> Avengers films).
  /// Kept small so one short query does not fan out into dozens of requests.
  static List<String> relatedCatalogQueries(String rawQuery) {
    final key = compact(normalize(rawQuery));
    final plotTitles = plotRelatedTitles(rawQuery);
    if (plotTitles.isNotEmpty) return plotTitles;
    if (const <String>{
      'spider', 'spiderman', 'peterparker', 'milesmorales', 'spiderverse',
      'spidernoir', 'spidergwen', 'spiderwoman', 'spiderpunk', 'spiderham',
      'spiderman2099', 'miguelohara', 'hobiebrown', 'gwenstacy', 'benreilly',
    }.contains(key)) {
      return const <String>['Spider-Man', 'Avengers', 'Captain America', 'Spider-Noir'];
    }
    if (const <String>{'iron', 'ironman', 'tonystark', 'ironheart', 'ririwilliams'}
        .contains(key)) {
      return const <String>['Avengers', 'Captain America', 'Spider-Man Homecoming'];
    }
    if (const <String>{'alexrusso', 'wizards', 'wizardsofwaverlyplace', 'alexvsalex'}
        .contains(key)) {
      return const <String>['Wizards of Waverly Place'];
    }
    if (key == 'taylor') {
      return const <String>['Twilight', 'The Ridiculous 6'];
    }
    return const <String>[];
  }

  /// Recognizes plot-description language and maps strong, recognizable clues
  /// to catalog title searches. This is intentionally a small intent layer,
  /// not a claim that the app has a trained semantic model or exhaustive plot DB.
  /// General description matching is handled by [semanticPlotScore].
  static List<String> plotRelatedTitles(String rawQuery) {
    final query = normalize(rawQuery);
    if (query.isEmpty) return const <String>[];
    final words = query.split(' ').where((word) => word.isNotEmpty).toSet();
    bool hasWord(Iterable<String> options) =>
        options.any((option) => words.contains(normalize(option)));
    bool hasPhrase(Iterable<String> options) =>
        options.any((option) => query.contains(normalize(option)));

    final titles = <String>[];

    // The wedding-night game with the new in-laws is the defining premise of
    // Ready or Not. Include common typos such as "cuople" in the detection.
    final weddingCue = hasWord(const <String>[
      'couple', 'couples', 'cuople', 'marry', 'marries', 'married', 'marriage',
      'wedding', 'bride', 'groom', 'newlywed', 'newlyweds', 'husband', 'wife',
    ]);
    final familyCue = hasWord(const <String>[
      'husband', 'wife', 'family', 'families', 'in-laws', 'inlaws', 'relatives',
      'inlaw', 'parents',
    ]) || hasPhrase(const <String>['husband family', 'husband s family', 'in laws']);
    final gameCue = hasWord(const <String>[
      'game', 'games', 'play', 'plays', 'playing', 'survive', 'survival',
      'deadly', 'hide', 'seek', 'hunt', 'hunted',
    ]);
    if (weddingCue && familyCue && gameCue) {
      titles.add('Ready or Not');
    }

    // Deadpool & Wolverine's TVA plot and the skeleton/adamantium fight are
    // strong clues even when the user never types the official title.
    final deadpoolCue = hasWord(const <String>['deadpool', 'wade']);
    final wolverineCue = hasWord(const <String>[
      'wolverine', 'logan', 'skeleton', 'bones', 'adamantium', 'tva', 'agents',
    ]);
    if (deadpoolCue && wolverineCue) {
      titles.add('Deadpool & Wolverine');
    }

    final slothCue = hasWord(const <String>['sloth', 'sloths']);
    final killerCue = hasWord(const <String>[
      'serial', 'killer', 'killers', 'murderer', 'murder', 'murderous', 'killing',
      'kills', 'kill',
    ]);
    if (slothCue && killerCue) {
      titles.add('Slotherhouse');
    }

    final protagonistCue = hasWord(const <String>[
      'girl', 'woman', 'female', 'teen', 'student', 'daughter', 'heroine',
    ]);
    final deathCue = hasWord(const <String>[
      'dies', 'die', 'died', 'death', 'dead', 'killed', 'murdered', 'murder',
    ]);
    final repetitionCue = hasWord(const <String>[
      'repeatedly', 'repeat', 'repeats', 'again', 'loop', 'loops', 'relives',
      'relive', 'repeating', 'repeated',
    ]) || hasPhrase(const <String>[
      'same day', 'over and over', 'day again', 'every day', 'time loop',
    ]);
    if (protagonistCue && deathCue && repetitionCue) {
      titles.add('Happy Death Day');
    }

    return List<String>.unmodifiable(titles.toSet());
  }

  /// Returns a modest relevance score for natural-language plot descriptions.
  /// Common prompt filler is ignored and related vocabulary is folded into
  /// shared concepts (e.g. "married" and "bride", or "relives" and "again").
  /// A result still needs at least two meaningful concept matches to avoid
  /// flooding the results with titles that share only one generic word.
  static int semanticPlotScore(String rawQuery, String candidateText) {
    final query = normalize(rawQuery);
    final candidate = normalize(candidateText);
    if (query.length < 12 || candidate.isEmpty) return 0;

    const stopWords = <String>{
      'a', 'an', 'the', 'and', 'or', 'but', 'then', 'where', 'what', 'when',
      'which', 'who', 'why', 'how', 'movie', 'movies', 'film', 'films', 'show',
      'series', 'episode', 'episodes', 'about', 'with', 'without', 'from', 'into',
      'onto', 'for', 'to', 'of', 'in', 'on', 'at', 'by', 'as', 'is', 'are', 'was',
      'were', 'be', 'been', 'being', 'has', 'have', 'had', 'do', 'does', 'did',
      'that', 'this', 'it', 'its', 'their', 'his', 'her', 'they', 'them', 'you',
      'your', 'we', 'i', 'me', 'my', 'can', 'could', 'would', 'should', 'will',
      'gets', 'get', 'got', 'makes', 'make', 'made', 'starts', 'start',
      'there', 'one', 'some', 'thing', 'things', 'person', 'someone', 'something',
    };
    String concept(String token) {
      switch (token) {
        case 'couple':
        case 'couples':
        case 'cuople':
        case 'marry':
        case 'marries':
        case 'married':
        case 'marriage':
        case 'bride':
        case 'groom':
        case 'newlywed':
        case 'newlyweds':
        case 'husband':
        case 'wife':
        case 'spouse':
        case 'fiance':
        case 'fiancee':
          return 'wedding';
        case 'families':
        case 'relatives':
        case 'inlaw':
        case 'inlaws':
        case 'parents':
          return 'family';
        case 'plays':
        case 'playing':
        case 'games':
        case 'gameplay':
          return 'game';
        case 'sloths':
          return 'sloth';
        case 'serial':
        case 'killer':
        case 'killers':
        case 'kill':
        case 'kills':
        case 'killing':
        case 'murderer':
        case 'murderers':
        case 'murder':
        case 'murdered':
        case 'murderous':
          return 'death';
        case 'dies':
        case 'died':
        case 'die':
        case 'dead':
          return 'death';
        case 'repeatedly':
        case 'repeats':
        case 'repeated':
        case 'repeating':
        case 'relive':
        case 'relives':
        case 'reliving':
        case 'loop':
        case 'loops':
          return 'repeatday';
        case 'girl':
        case 'girls':
        case 'woman':
        case 'women':
        case 'female':
        case 'teen':
        case 'teens':
        case 'student':
        case 'students':
        case 'daughter':
        case 'heroine':
          return 'protagonist';
        case 'skeletons':
        case 'bones':
        case 'adamantium':
          return 'skeleton';
        case 'agents':
          return 'agent';
        default:
          return token;
      }
    }

    Set<String> features(String value) {
      final normalized = normalize(value);
      final result = <String>{
        for (final token in normalized.split(' '))
          if (token.isNotEmpty && !stopWords.contains(token)) concept(token),
      };
      // Phrase-level intent handles wording whose parts may not be contiguous
      // in a synopsis, such as "same day" versus "relives the day".
      if (RegExp(r'\b(same day|every day|day again|over and over|time loop)\b')
          .hasMatch(normalized)) {
        result.add('repeatday');
      }
      if (RegExp(r'\b(in laws|husband s family|wife s family)\b')
          .hasMatch(normalized)) {
        result.add('family');
      }
      if (RegExp(r'\b(wedding night|newly married|gets married)\b')
          .hasMatch(normalized)) {
        result.add('wedding');
      }
      return result;
    }

    final queryFeatures = features(query);
    final candidateFeatures = features(candidate);
    if (queryFeatures.length < 2) return 0;
    final shared = queryFeatures.intersection(candidateFeatures).length;
    if (shared < 2) return 0;
    final coverage = shared / queryFeatures.length;
    return (shared * 10 + coverage * 12).round().clamp(0, 48).toInt();
  }

  /// Fictional identities worth showing in the dedicated Characters section.
  /// Character cards do not assert actor credits; those must come from indexed
  /// credits or an actual TMDB person result in the separate People section.
  static List<String> relatedCharacterTerms(String rawQuery) {
    final key = compact(normalize(rawQuery));
    if (const <String>{
      'spider', 'spiderman', 'peterparker', 'milesmorales', 'spiderverse',
      'spidernoir', 'spidergwen', 'spiderwoman', 'spiderpunk', 'spiderham',
      'spiderman2099', 'miguelohara', 'hobiebrown', 'gwenstacy', 'benreilly',
    }.contains(key)) {
      return const <String>[
        'Spider-Man', 'Peter Parker', 'Miles Morales', 'Gwen Stacy',
        'Spider-Noir', 'Miguel O’Hara', 'Spider-Punk', 'Hobie Brown',
        'Spider-Ham', 'Peter Porker', 'Ben Reilly', 'Iron Spider',
      ];
    }
    if (const <String>{'iron', 'ironman', 'tonystark', 'ironheart', 'ririwilliams'}
        .contains(key)) {
      return const <String>['Iron Man', 'Tony Stark', 'Ironheart', 'Riri Williams'];
    }
    if (const <String>{'alexrusso', 'wizards', 'wizardsofwaverlyplace', 'alexvsalex'}
        .contains(key)) {
      return const <String>['Alex Russo'];
    }
    if (key == 'peter') return const <String>['Peter Parker'];
    return const <String>[];
  }

  /// Person-name searches that connect a character/franchise query to cast.
  /// TMDB or the backend must return an actual person record before it is shown.
  static List<String> relatedPersonTerms(String rawQuery) {
    final key = compact(normalize(rawQuery));
    if (const <String>{
      'spider', 'spiderman', 'peterparker', 'milesmorales', 'spiderverse',
      'spidernoir', 'spidergwen', 'spiderwoman', 'spiderpunk', 'spiderham',
      'spiderman2099', 'miguelohara', 'hobiebrown', 'gwenstacy', 'benreilly',
    }.contains(key)) {
      return const <String>[
        'Tobey Maguire', 'Andrew Garfield', 'Tom Holland', 'Paul Soles',
        'Neil Patrick Harris', 'Christopher Daniel Barnes', 'Drake Bell',
        'Dan Gilvezan', 'Jake Johnson', 'Shameik Moore', 'Nicolas Cage', 'Hailee Steinfeld',
        'Oscar Isaac', 'Daniel Kaluuya', 'John Mulaney',
      ];
    }
    if (const <String>{'iron', 'ironman', 'tonystark', 'ironheart', 'ririwilliams'}
        .contains(key)) {
      return const <String>['Robert Downey Jr.', 'Dominique Thorne'];
    }
    if (const <String>{'alexrusso', 'wizards', 'wizardsofwaverlyplace', 'alexvsalex'}
        .contains(key)) {
      return const <String>['Selena Gomez'];
    }
    if (key == 'taylor') {
      return const <String>['Taylor Swift', 'Taylor Lautner'];
    }
    return const <String>[];
  }

  /// Detects themed-episode searches only when a theme is explicitly requested.
  static SmartSearchTheme? themeForQuery(String rawQuery) {
    final query = normalize(rawQuery);
    final asksForEpisodes = query.contains('episode') ||
        query.contains('episodes') ||
        query.contains('themed') ||
        query.contains('theme');
    for (final theme in themes) {
      if (theme.keywords.any((keyword) => query.contains(normalize(keyword)))) {
        return theme;
      }
      if (asksForEpisodes &&
          ((theme.key == 'halloween' && query.contains('spooky')) ||
              (theme.key == 'christmas' &&
                  (query.contains('holiday') || query.contains('seasonal'))))) {
        return theme;
      }
    }
    return null;
  }

  /// Finds only episodes whose own title, summary, or explicit metadata signals
  /// the selected theme. It doesn't label every episode in a series as themed.
  static List<SmartSearchEpisodeHit> themedEpisodes(
    String query,
    List<MediaItem> library,
  ) {
    final theme = themeForQuery(query);
    if (theme == null) return const <SmartSearchEpisodeHit>[];
    final entries = <SmartSearchEpisodeHit>[];
    final seen = <String>{};
    for (final media in library) {
      for (final rawSeason in media.seasons) {
        final season = Map<String, dynamic>.from(rawSeason);
        final seasonNumber = _asInt(season['seasonNumber'] ?? season['season_number'] ??
            season['number'] ?? season['season']);
        final rawEpisodes = season['episodes'];
        if (rawEpisodes is! List) continue;
        for (final rawEpisode in rawEpisodes) {
          if (rawEpisode is! Map) continue;
          final episode = Map<String, dynamic>.from(rawEpisode);
          final title = _firstText(episode, const <String>['title', 'name', 'episodeTitle']) ?? 'Episode';
          final description = _firstText(episode, const <String>['description', 'overview', 'summary', 'plot']);
          final searchable = normalize(<String>[
            title,
            description ?? '',
            _valueText(episode['genres']),
            _valueText(episode['tags']),
            _valueText(episode['themes']),
            _valueText(episode['keywords']),
            _valueText(episode['topic']),
            _valueText(episode['category']),
          ].join(' '));
          final titleKey = compact(title);
          final showKey = compact(<String>[
            media.title,
            media.originalTitle ?? '',
            media.canonicalTitle ?? '',
          ].join(' '));
          final explicitThemeMatch = theme.keywords.any(
            (keyword) => searchable.contains(normalize(keyword)),
          );
          final aliases = theme.key == 'halloween'
              ? _halloweenEpisodeAliases
              : _holidayEpisodeAliases;
          final curatedThemeMatch = aliases.entries.any((entry) {
            final show = compact(entry.key);
            if (!showKey.contains(show)) return false;
            return entry.value.any((alias) {
              final episodeAlias = compact(alias);
              return titleKey == episodeAlias ||
                  titleKey.contains(episodeAlias) ||
                  episodeAlias.contains(titleKey);
            });
          });
          if (!explicitThemeMatch && !curatedThemeMatch) continue;
          final episodeNumber = _asInt(episode['episodeNumber'] ?? episode['episode_number'] ??
              episode['episode'] ?? episode['number']);
          final id = _firstText(episode, const <String>['id', 'episodeId', 'episode_id']) ?? title;
          final uniqueKey = '${media.id}:${seasonNumber ?? ''}:${episodeNumber ?? ''}:$id';
          if (!seen.add(uniqueKey)) continue;
          final imageUrl = _firstText(episode, const <String>[
            'imageUrl', 'image_url', 'posterUrl', 'poster_url', 'stillUrl', 'still_url',
          ]) ?? media.imageUrl;
          entries.add(SmartSearchEpisodeHit(
            parent: media,
            episode: episode,
            title: title,
            description: description,
            imageUrl: imageUrl,
            seasonNumber: seasonNumber,
            episodeNumber: episodeNumber,
            theme: theme,
          ));
        }
      }
    }
    entries.sort((a, b) {
      final aName = '${a.parent.title} ${a.seasonNumber ?? 0} ${a.episodeNumber ?? 0} ${a.title}';
      final bName = '${b.parent.title} ${b.seasonNumber ?? 0} ${b.episodeNumber ?? 0} ${b.title}';
      return aName.toLowerCase().compareTo(bName.toLowerCase());
    });
    return entries.take(60).toList(growable: false);
  }

  static String _valueText(dynamic value) {
    if (value == null) return '';
    if (value is Iterable) return value.map((part) => part?.toString() ?? '').join(' ');
    if (value is Map) return value.values.map((part) => part?.toString() ?? '').join(' ');
    return value.toString();
  }

  static String? _firstText(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value == null || value is Map || value is List) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  static int? _asInt(dynamic value) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
}
