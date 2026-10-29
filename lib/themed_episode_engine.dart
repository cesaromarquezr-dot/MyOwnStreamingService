/// Holiday and themed-episode matching for the local media catalogue.
///
/// Recognition is metadata-driven and conservative: explicit episode titles,
/// tags and descriptions win over broad words. A show airing near a holiday is
/// never considered themed solely because of its air date. Seasonal priority
/// changes with the calendar, but every recognized theme remains discoverable.
class ThemedEpisodeMatch {
  const ThemedEpisodeMatch({
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

class ThemedEpisodeEngine {
  ThemedEpisodeEngine._();

  static const Map<String, String> _labels = <String, String>{
    'halloween': 'Halloween',
    'christmas': 'Christmas',
    'thanksgiving': 'Thanksgiving',
    'valentines': "Valentine's Day",
    'easter': 'Easter',
    'hanukkah': 'Hanukkah',
    'kwanzaa': 'Kwanzaa',
    'ramadan': 'Ramadan',
    'eid': 'Eid',
    'diwali': 'Diwali',
    'lunar-new-year': 'Lunar New Year',
    'yom-kippur': 'Yom Kippur',
    'st-patricks': "St. Patrick's Day",
    'mothers-day': "Mother's Day",
    'fathers-day': "Father's Day",
    'labor-day': 'Labor Day',
    'juneteenth': 'Juneteenth',
    'dia-de-muertos': 'Día de Muertos',
    'festivus': 'Festivus',
    'chrismukkah': 'Chrismukkah',
    'holiday-mashup': 'Holiday Mashup',
    'new-year': 'New Year',
    'graduation': 'Graduation',
    'back-to-school': 'Back to School',
    'independence-day': 'Independence Day',
    'earth-day': 'Earth Day',
    'pride-month': 'Pride Month',
    'cinco-de-mayo': 'Cinco de Mayo',
    'memorial-day': 'Memorial Day',
    'veterans-day': 'Veterans Day',
  };

  static const Map<String, List<String>> _keywords = <String, List<String>>{
    'halloween': <String>[
      'halloween', 'trick or treat', 'treehouse of horror', 'haunted house',
      'costume party', 'costume contest', 'pumpkin carving', 'jack o lantern',
      'ghost story', 'spooky', 'horror night', 'monster mash', 'all hallows',
      'hubie halloween', 'the nightmare before christmas',
    ],
    'christmas': <String>[
      'christmas', 'santa claus', 'santa', 'reindeer', 'christmas eve',
      'christmas party', 'holiday gift exchange', 'secret santa', 'mistletoe',
      'stocking stuffer', 'twas the mission before christmas', 'noel',
      'father christmas', 'carol of the bells', 'uncontrollable christmas',
      'the nightmare before christmas', 'the grinch', 'home alone',
      'jingle all the way', 'miracle on 34th street', 'good luck charlie it s christmas',
      'a very muppet christmas', 'how the grinch stole christmas',
    ],
    'thanksgiving': <String>[
      'thanksgiving', 'thanksgiving dinner', 'turkey day', 'thanksgiving turkey',
      'friendsgiving', 'the peck', 'turkey in a can', 'an indecent thanksgiving proposal',
      'thanks hoarding', 'holiday armadillo',
    ],
    'valentines': <String>[
      "valentine's day", 'valentines day', 'valentine day', 'love potion',
      'blind date', 'romantic dinner', 'cupid', 'love is in the air',
    ],
    'easter': <String>[
      'easter', 'easter egg hunt', 'easter bunny', 'good friday', 'resurrection',
      'valloweaster',
    ],
    'hanukkah': <String>[
      'hanukkah', 'chanukah', 'menorah', 'dreidel', 'gelt', 'festival of lights',
      'holiday armadillo',
    ],
    'kwanzaa': <String>['kwanzaa', 'kinara', 'seven principles of kwanzaa'],
    'ramadan': <String>[
      'ramadan', 'iftar', 'suhoor', 'fasting month', 'breaking the fast',
    ],
    'eid': <String>[
      'eid al adha', 'eid al-adha', 'eid al fitr', 'eid al-fitr', 'eid mubarak',
      'feast of sacrifice',
    ],
    'diwali': <String>[
      'diwali', 'deepavali', 'festival of lights', 'diyas', 'rangoli',
    ],
    'lunar-new-year': <String>[
      'lunar new year', 'chinese new year', 'spring festival', 'year of the dragon',
      'year of the snake', 'red envelope', 'lantern festival',
    ],
    'yom-kippur': <String>['yom kippur', 'day of atonement', 'kol nidre'],
    'st-patricks': <String>[
      "st. patrick's day", 'st patricks day', 'shamrock', 'leprechaun',
      'wearing green',
    ],
    'mothers-day': <String>[
      "mother's day", 'mothers day', 'mother-daughter day', 'mom gets a day off',
    ],
    'fathers-day': <String>["father's day", 'fathers day', 'dad gets a day off'],
    'labor-day': <String>['labor day', 'labour day', 'last weekend of summer'],
    'juneteenth': <String>['juneteenth', 'june nineteenth', 'emancipation day'],
    'dia-de-muertos': <String>[
      'día de muertos', 'dia de muertos', 'day of the dead', 'ofrenda',
      'calavera', 'sugar skull',
    ],
    'festivus': <String>['festivus', 'airing of grievances', 'feats of strength'],
    'chrismukkah': <String>['chrismukkah', 'christmukkah', 'christmas hanukkah'],
    'holiday-mashup': <String>['valloweaster', 'holiday mashup', 'holiday mash-up'],
    'new-year': <String>[
      'new year', "new year's eve", 'new years eve', 'midnight countdown',
      'ball drop', 'new year resolution',
    ],
    'graduation': <String>['graduation', 'commencement', 'senior prom', 'valedictorian'],
    'back-to-school': <String>[
      'back to school', 'first day of school', 'school starts', 'new school year',
    ],
    'independence-day': <String>['independence day', 'fourth of july', '4th of july', 'fireworks display'],
    'earth-day': <String>['earth day', 'environmental cleanup', 'save the planet'],
    'pride-month': <String>['pride month', 'pride parade', 'pride festival'],
    'cinco-de-mayo': <String>['cinco de mayo', 'battle of puebla'],
    'memorial-day': <String>['memorial day', 'fallen soldiers', 'memorial service'],
    'veterans-day': <String>['veterans day', 'armistice day', 'remembrance day'],
  };

  /// Curated film/show title aliases. These deliberately allow the same title
  /// to belong to more than one holiday (for example, The Nightmare Before
  /// Christmas belongs in both Halloween and Christmas collections).
  static const Map<String, List<String>> _curatedMediaTitles =
      <String, List<String>>{
    'halloween': <String>[
      'halloween',
      'hubie halloween',
      'the nightmare before christmas',
      'hocus pocus',
      'hocus pocus 2',
      'beetlejuice',
      'casper',
      'its the great pumpkin charlie brown',
      'it s the great pumpkin charlie brown',
      'the addams family',
    ],
    'christmas': <String>[
      'the nightmare before christmas',
      'good luck charlie it s christmas',
      'good luck charlie its christmas',
      'the grinch',
      'how the grinch stole christmas',
      'a very muppet christmas',
      'miracle on 34th street',
      'jingle all the way',
      'home alone',
      'home alone 2 lost in new york',
      'the santa clause',
      'elf',
      'national lampoon s christmas vacation',
      'a christmas story',
      'a christmas carol',
      'the muppet christmas carol',
      'the christmas chronicles',
      'christmas with the kranks',
      'deck the halls',
      'four christmases',
      'scrooged',
      'arthur christmas',
      'the polar express',
      'last christmas',
      'the holiday',
      'klaus',
    ],
    'valentines': <String>[
      'valentine s day',
      'valentines day',
      'be my valentine charlie brown',
      'isn t it romantic',
      'isnt it romantic',
      'love actually',
      'the vow',
      'the notebook',
    ],
    'thanksgiving': <String>[
      'a charlie brown thanksgiving',
      'planes trains and automobiles',
      'free birds',
    ],
    'easter': <String>[
      'hop',
      'here comes peter cottontail',
      'it s the easter beagle charlie brown',
      'it s the easter beagle',
    ],
    'st-patricks': <String>[
      'the luck of the irish',
      'darby o gill and the little people',
      'luck',
    ],
    'new-year': <String>['new year s eve', 'new year s eve'],
  };

  /// Exact show/episode aliases supplement provider metadata. Aliases are
  /// normalized and must match both the show and an episode-title fragment.
  static const Map<String, Map<String, List<String>>> _curated =
      <String, Map<String, List<String>>>{
    'halloween': <String, List<String>>{
      'wizards of waverly place': <String>['halloween'],
      'lab rats': <String>['halloween'],
      'the simpsons': <String>['treehouse of horror', 'halloween of horror'],
      'brooklyn nine nine': <String>['halloween', 'halloween heist', 'halloveen', 'valloweaster'],
      'buffy the vampire slayer': <String>['halloween', 'fear itself'],
      'the office': <String>['halloween', 'costume contest'],
      'stranger things': <String>['trick or treat freak'],
      'abbott elementary': <String>['candy zombies'],
      'bojack horseman': <String>['mr peanutbutters boos'],
      'parks and recreation': <String>['meet n greet', 'halloween surprise'],
      'psych': <String>['scary sherry biancas toast', 'tuesday the 17th'],
      'bobs burgers': <String>['the hauntening', 'full bars'],
      'south park': <String>['a nightmare on facetime'],
      'friends': <String>['the one with the halloween party'],
      'family guy': <String>['halloween on spooner street', 'petergeist'],
    },
    'christmas': <String, List<String>>{
      'lab rats': <String>['twas the mission before christmas'],
      'friends': <String>['the one with the holiday armadillo'],
      'the office': <String>['christmas party', 'a benihana christmas'],
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
      'the suite life of zack and cody': <String>['christmas at the tipton'],
    },
    'thanksgiving': <String, List<String>>{
      'friends': <String>['thanksgiving', 'football', 'the one with the list'],
      'bobs burgers': <String>[
        'an indecent thanksgiving proposal', 'dawn of the peck', 'turkey in a can',
        'thanks hoarding',
      ],
    },
    'valentines': <String, List<String>>{
      'modern family': <String>['valentines day'],
      'parks and recreation': <String>['galentines day', 'valentines day'],
      'the office': <String>['valentines day'],
    },
    'hanukkah': <String, List<String>>{
      'rugrats': <String>['chanukah', 'hanukkah'],
    },
    'diwali': <String, List<String>>{
      'the office': <String>['diwali'],
    },
    'lunar-new-year': <String, List<String>>{
      'american dragon jake long': <String>['year of the dragon', 'lunar new year'],
      'abby hatcher': <String>['lunar new year', 'chinese new year'],
    },
    'ramadan': <String, List<String>>{
      'arthur': <String>['ramadan'],
    },
    'eid': <String, List<String>>{
      'mimpi metropolitan': <String>['eid al adha', 'eid al-adha'],
    },
    'yom-kippur': <String, List<String>>{
      'arthur': <String>['yom kippur'],
    },
    'festivus': <String, List<String>>{
      'seinfeld': <String>['the strike'],
    },
    'chrismukkah': <String, List<String>>{
      'the oc': <String>['the best chrismukkah ever', 'chrismukkah'],
    },
    'holiday-mashup': <String, List<String>>{
      'brooklyn nine nine': <String>['valloweaster'],
    },
  };

  static String normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r"[^a-z0-9]+"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// The leading seasonal theme used for the main page title.
  static String get currentThemeKey {
    final themes = _activeThemes(DateTime.now());
    return themes.isEmpty ? 'christmas' : themes.first;
  }

  static String get currentSeasonLabel => _labels[currentThemeKey] ?? currentThemeKey;

  static String labelFor(String key) => _labels[key] ?? key;

  /// A small, recognizable holiday figure rendered beside themed shelf titles.
  static String iconFor(String key) {
    const icons = <String, String>{
      'halloween': '🎃',
      'christmas': '🎄',
      'thanksgiving': '🥧',
      'valentines': '💝',
      'easter': '🐰',
      'hanukkah': '🕎',
      'kwanzaa': '🕯️',
      'ramadan': '🌙',
      'eid': '🌙',
      'diwali': '🪔',
      'lunar-new-year': '🏮',
      'yom-kippur': '🕯️',
      'st-patricks': '☘️',
      'mothers-day': '💐',
      'fathers-day': '🎁',
      'labor-day': '🛠️',
      'juneteenth': '✊🏾',
      'dia-de-muertos': '💀',
      'festivus': '🎉',
      'chrismukkah': '🕎',
      'holiday-mashup': '🎊',
      'new-year': '🎆',
      'graduation': '🎓',
      'back-to-school': '🎒',
      'independence-day': '🎆',
      'earth-day': '🌎',
      'pride-month': '🏳️‍🌈',
      'cinco-de-mayo': '🎊',
      'memorial-day': '🇺🇸',
      'veterans-day': '🇺🇸',
    };
    return icons[key] ?? '🎉';
  }

  /// Holiday-specific ARGB accents used for themed cards and shelf headings.
  static int colorArgbFor(String key) {
    const colors = <String, int>{
      'halloween': 0xFFFF8A00,
      'christmas': 0xFF35A853,
      'thanksgiving': 0xFFC56A2D,
      'valentines': 0xFFFF4F87,
      'easter': 0xFFB58AE8,
      'hanukkah': 0xFF4AA3FF,
      'kwanzaa': 0xFFB71C1C,
      'ramadan': 0xFF2FAE91,
      'eid': 0xFF2FAE91,
      'diwali': 0xFFFFB300,
      'lunar-new-year': 0xFFD32F2F,
      'yom-kippur': 0xFF7E9CCB,
      'st-patricks': 0xFF21A366,
      'mothers-day': 0xFFE878A8,
      'fathers-day': 0xFF4F83CC,
      'labor-day': 0xFF87909A,
      'juneteenth': 0xFF7B4FA3,
      'dia-de-muertos': 0xFFE96B35,
      'festivus': 0xFFB0B8C1,
      'chrismukkah': 0xFFB51F2A,
      'holiday-mashup': 0xFF9C65B8,
      'new-year': 0xFFFFD54F,
      'graduation': 0xFF4F65B5,
      'back-to-school': 0xFF1C9B8E,
      'independence-day': 0xFF3C6EBD,
      'earth-day': 0xFF49A55A,
      'pride-month': 0xFFD65A9E,
      'cinco-de-mayo': 0xFF2E9D58,
      'memorial-day': 0xFF3C6EBD,
      'veterans-day': 0xFF3C6EBD,
    };
    return colors[key] ?? 0xFF8B7CFF;
  }

  static List<String> _activeThemes(DateTime date) {
    // Seasonal prominence, not religious observance dates. Exact observance
    // dates vary by year, lunar calendar and location; metadata still determines
    // whether a particular episode belongs to the theme.
    switch (date.month) {
      case 1:
        return const <String>['new-year', 'lunar-new-year'];
      case 2:
        return const <String>['valentines', 'lunar-new-year', 'ramadan'];
      case 3:
        return const <String>['st-patricks', 'ramadan', 'easter', 'eid'];
      case 4:
        return const <String>['easter', 'ramadan', 'eid', 'earth-day'];
      case 5:
        return const <String>['mothers-day', 'cinco-de-mayo', 'graduation', 'memorial-day'];
      case 6:
        return const <String>['juneteenth', 'fathers-day', 'pride-month'];
      case 7:
        return const <String>['independence-day'];
      case 8:
        return const <String>['back-to-school'];
      case 9:
        return const <String>['labor-day', 'back-to-school', 'yom-kippur'];
      case 10:
        return const <String>['halloween', 'dia-de-muertos', 'diwali'];
      case 11:
        return const <String>['thanksgiving', 'diwali', 'dia-de-muertos', 'veterans-day'];
      case 12:
        return const <String>['christmas', 'hanukkah', 'kwanzaa', 'chrismukkah', 'new-year'];
      default:
        return const <String>[];
    }
  }

  static List<String> themesForDate([DateTime? date]) {
    final now = date ?? DateTime.now();
    final active = _activeThemes(now);
    final rest = _labels.keys.where((key) => !active.contains(key)).toList();
    return <String>[...active, ...rest];
  }

  static int seasonalPriority(String key, [DateTime? date]) {
    final order = themesForDate(date);
    final index = order.indexOf(key);
    return index < 0 ? 500 : index;
  }

  static String episodeLabel(Map<String, dynamic> season, Map<String, dynamic> episode) {
    final seasonNumber = _number(season, const <String>[
      'seasonNumber', 'season_number', 'number', 'season',
    ]);
    final episodeNumber = _number(episode, const <String>[
      'episodeNumber', 'episode_number', 'number', 'episode',
    ]);
    if (seasonNumber == null && episodeNumber == null) return 'Special episode';
    if (seasonNumber == null) return 'Episode $episodeNumber';
    if (episodeNumber == null) return 'Season $seasonNumber';
    return 'Season $seasonNumber, Episode $episodeNumber';
  }

  static int? _number(Map<String, dynamic> values, List<String> keys) {
    for (final key in keys) {
      final raw = values[key];
      if (raw is num) return raw.toInt();
      final parsed = int.tryParse(raw?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }

  static ThemedEpisodeMatch? detectEpisode({
    required String showTitle,
    required Map<String, dynamic> episode,
    DateTime? date,
  }) {
    final title = (episode['title'] ?? episode['name'] ?? '').toString();
    final summary = <String>[
      title,
      (episode['description'] ?? episode['overview'] ?? episode['plot'] ?? '').toString(),
      _asSearchText(episode['genres']),
      _asSearchText(episode['tags']),
      _asSearchText(episode['keywords']),
      _asSearchText(episode['holiday']),
      _asSearchText(episode['theme']),
    ].join(' ');
    final normalizedShow = normalize(showTitle);
    final normalizedTitle = normalize(title);
    final normalizedText = normalize(summary);
    if (normalizedTitle.isEmpty && normalizedText.trim().isEmpty) return null;

    ThemedEpisodeMatch? best;
    for (final key in _labels.keys) {
      var confidence = 0;
      final curatedShows = _curated[key];
      if (curatedShows != null) {
        for (final entry in curatedShows.entries) {
          if (normalizedShow == normalize(entry.key) ||
              normalizedShow.contains(normalize(entry.key)) ||
              normalize(entry.key).contains(normalizedShow)) {
            if (entry.value.any((alias) {
              final normalizedAlias = normalize(alias);
              return normalizedTitle.isNotEmpty &&
                  (normalizedTitle.contains(normalizedAlias) ||
                      normalizedAlias.contains(normalizedTitle));
            })) {
              confidence = 100;
              break;
            }
          }
        }
      }

      final words = _keywords[key] ?? const <String>[];
      for (final keyword in words) {
        final needle = normalize(keyword);
        if (needle.length < 4) continue;
        if (normalizedTitle.contains(needle)) {
          confidence = confidence < 90 ? 90 : confidence;
        } else if (normalizedText.contains(needle)) {
          confidence = confidence < 65 ? 65 : confidence;
        }
      }
      // A show-specific exact alias is stronger than a loose description hit.
      if (confidence > 0 &&
          (best == null ||
              confidence > best.confidence ||
              (confidence == best.confidence &&
                  seasonalPriority(key, date) < best.seasonalPriority))) {
        best = ThemedEpisodeMatch(
          key: key,
          label: _labels[key] ?? key,
          confidence: confidence,
          seasonalPriority: seasonalPriority(key, date),
        );
      }
    }
    return best;
  }

  static ThemedEpisodeMatch? detectMedia({
    required String title,
    String description = '',
    Iterable<String> genres = const <String>[],
    Iterable<String> tags = const <String>[],
    DateTime? date,
  }) {
    final matches = detectMediaMatches(
      title: title,
      description: description,
      genres: genres,
      tags: tags,
      date: date,
    );
    if (matches.isEmpty) return null;
    matches.sort((a, b) {
      final confidence = b.confidence.compareTo(a.confidence);
      if (confidence != 0) return confidence;
      return a.seasonalPriority.compareTo(b.seasonalPriority);
    });
    return matches.first;
  }

  /// Finds every credible holiday theme for a film or show. Unlike a single
  /// best-match classifier, this can place crossover titles in multiple rows.
  static List<ThemedEpisodeMatch> detectMediaMatches({
    required String title,
    String description = '',
    Iterable<String> genres = const <String>[],
    Iterable<String> tags = const <String>[],
    DateTime? date,
  }) {
    final normalizedTitle = normalize(title);
    if (normalizedTitle.isEmpty) return const <ThemedEpisodeMatch>[];
    final normalizedText = normalize(<String>[
      title,
      description,
      ...genres,
      ...tags,
    ].join(' '));
    final matches = <ThemedEpisodeMatch>[];
    for (final key in _labels.keys) {
      var confidence = 0;
      final curated = _curatedMediaTitles[key] ?? const <String>[];
      for (final alias in curated) {
        final normalizedAlias = normalize(alias);
        if (normalizedAlias.isEmpty) continue;
        // Long aliases are useful for franchise variants. Very short aliases
        // (such as "elf" or "hop") require an exact title to avoid false hits.
        final exact = normalizedTitle == normalizedAlias;
        final titleContainsAlias = normalizedAlias.length >= 7 &&
            normalizedTitle.contains(normalizedAlias);
        final aliasContainsTitle = normalizedTitle.length >= 9 &&
            normalizedAlias.contains(normalizedTitle);
        if (exact || titleContainsAlias || aliasContainsTitle) {
          confidence = 100;
          break;
        }
      }
      for (final keyword in _keywords[key] ?? const <String>[]) {
        final needle = normalize(keyword);
        if (needle.length < 4) continue;
        if (normalizedTitle.contains(needle)) {
          if (confidence < 90) confidence = 90;
        } else if (normalizedText.contains(needle) && confidence < 65) {
          confidence = 65;
        }
      }
      if (confidence > 0) {
        matches.add(ThemedEpisodeMatch(
          key: key,
          label: _labels[key] ?? key,
          confidence: confidence,
          seasonalPriority: seasonalPriority(key, date),
        ));
      }
    }
    matches.sort((a, b) {
      final seasonal = a.seasonalPriority.compareTo(b.seasonalPriority);
      if (seasonal != 0) return seasonal;
      return b.confidence.compareTo(a.confidence);
    });
    return matches;
  }

  static String _asSearchText(dynamic value) {
    if (value is List) return value.map((item) => item.toString()).join(' ');
    if (value is Map) return value.values.map((item) => item.toString()).join(' ');
    return value?.toString() ?? '';
  }
}
