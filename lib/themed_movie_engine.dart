import 'app_core.dart';
import 'themed_episode_engine.dart';

class HolidayMovieMoodMatch {
  const HolidayMovieMoodMatch({
    required this.holidayKey,
    required this.holidayLabel,
    required this.moodKey,
    required this.moodLabel,
    required this.confidence,
    required this.seasonalPriority,
  });

  final String holidayKey;
  final String holidayLabel;
  final String moodKey;
  final String moodLabel;
  final int confidence;
  final int seasonalPriority;
}

/// Theme classifier for imported feature films.
///
/// It reuses the shared holiday vocabulary and curated movie aliases from
/// [ThemedEpisodeEngine], while explicitly excluding TV series and episodes.
class ThemedMovieEngine {
  ThemedMovieEngine._();

  static const Map<String, String> _moodLabels = <String, String>{
    'halloween-light': 'Halloween, without the scares',
    'valentines-nonromantic': "Valentine's Day, without the romance",
    'new-year-chaos': "New Year's Eve gone sideways",
    'dark-holiday': 'Holiday horror & dark comedy',
    'holiday-action-adventure': 'Holiday action & adventure',
    'holiday-sci-fi-fantasy': 'Holiday sci-fi & fantasy',
    'holiday-comedy': 'Holiday comedies',
  };

  static const Map<String, Map<String, List<String>>> _curatedMoodTitles =
      <String, Map<String, List<String>>>{
    'halloween-light': <String, List<String>>{
      'halloween': <String>[
        'hocus pocus',
        'hocus pocus 2',
        'hubie halloween',
        'halloweentown',
        'halloweentown ii',
        'casper',
        'the nightmare before christmas',
        'the addams family',
        'beetlejuice',
      ],
    },
    'valentines-nonromantic': <String, List<String>>{
      'valentines': <String>['my bloody valentine', 'valentine', 'heart eyes'],
    },
    'new-year-chaos': <String, List<String>>{
      'new-year': <String>[
        'y2k',
        'terror train',
        'new year s evil',
        'end of days',
      ],
    },
    'dark-holiday': <String, List<String>>{
      'christmas': <String>[
        'violent night',
        'it s a wonderful knife',
        'krampus',
        'the mean one',
      ],
      'thanksgiving': <String>['thankskilling', 'thanksgiving'],
      'easter': <String>[
        'critters 2 the main course',
        'easter bloody easter',
      ],
      'independence-day': <String>[
        'jaws',
        'i know what you did last summer',
      ],
      'juneteenth': <String>['the blackening'],
      'st-patricks': <String>['leprechaun'],
      'april-fools': <String>['april fools day'],
      'new-year': <String>[
        'terror train',
        'new year s evil',
        'end of days',
      ],
      'valentines': <String>['my bloody valentine', 'valentine', 'heart eyes'],
    },
    'holiday-action-adventure': <String, List<String>>{
      'christmas': <String>['red one', 'die hard', 'violent night'],
    },
    'holiday-sci-fi-fantasy': <String, List<String>>{
      'christmas': <String>[
        'it s a wonderful life',
        'red one',
        'the christmas chronicles',
        'the polar express',
      ],
      'new-year': <String>['y2k'],
    },
  };

  static const List<String> _darkGenres = <String>[
    'horror',
    'slasher',
    'gore',
    'dark comedy',
  ];

  static bool isMovie(MediaItem media) {
    if (media.isSeries) return false;
    final type = media.type.toLowerCase().trim();
    return type == 'movie' ||
        type == 'film' ||
        type == 'feature' ||
        type.contains('movie') ||
        type.contains('film');
  }

  static List<ThemedEpisodeMatch> matchesForMovie(
    MediaItem movie, {
    DateTime? date,
  }) {
    if (!isMovie(movie)) return const <ThemedEpisodeMatch>[];
    return ThemedEpisodeEngine.detectMediaMatches(
      title: movie.title,
      description: movie.description ?? '',
      genres: movie.genres,
      tags: movie.tags,
      date: date,
    );
  }

  /// Finds holiday movies whose genre or tone deliberately differs from the
  /// holiday's usual movie stereotype. Holiday and mood remain separate tags.
  static List<HolidayMovieMoodMatch> curveballMatchesForMovie(
    MediaItem movie, {
    DateTime? date,
  }) {
    if (!isMovie(movie)) return const <HolidayMovieMoodMatch>[];
    final holidays = matchesForMovie(movie, date: date);
    if (holidays.isEmpty) return const <HolidayMovieMoodMatch>[];

    final title = ThemedEpisodeEngine.normalize(movie.title);
    final genreText = ThemedEpisodeEngine.normalize(
      <String>[...movie.genres, ...movie.tags].join(' '),
    );
    bool hasAny(Iterable<String> values) => values.any(
          (value) => genreText.contains(ThemedEpisodeEngine.normalize(value)),
        );
    bool matchesTitle(String alias) {
      final normalizedAlias = ThemedEpisodeEngine.normalize(alias);
      return title == normalizedAlias ||
          (normalizedAlias.length >= 7 && title.contains(normalizedAlias)) ||
          (title.length >= 9 && normalizedAlias.contains(title));
    }

    final result = <HolidayMovieMoodMatch>[];
    final seen = <String>{};

    void addMatch(ThemedEpisodeMatch holiday, String moodKey, int confidence) {
      if (!seen.add('${holiday.key}:$moodKey')) return;
      result.add(HolidayMovieMoodMatch(
        holidayKey: holiday.key,
        holidayLabel: holiday.label,
        moodKey: moodKey,
        moodLabel: _moodLabels[moodKey] ?? moodKey,
        confidence: confidence,
        seasonalPriority: holiday.seasonalPriority,
      ));
    }

    for (final holiday in holidays) {
      for (final mood in _curatedMoodTitles.entries) {
        final aliases = mood.value[holiday.key] ?? const <String>[];
        if (aliases.any(matchesTitle)) {
          addMatch(holiday, mood.key, 100);
        }
      }

      if (holiday.key == 'halloween' &&
          !hasAny(_darkGenres) &&
          hasAny(const <String>[
            'family',
            'animation',
            'comedy',
            'fantasy',
            'adventure',
          ])) {
        addMatch(holiday, 'halloween-light', 75);
      }

      if (holiday.key == 'valentines' &&
          !hasAny(const <String>['romance', 'romantic']) &&
          hasAny(const <String>[
            'horror',
            'slasher',
            'thriller',
            'action',
            'mystery',
            'crime',
            'science fiction',
            'sci fi',
          ])) {
        addMatch(holiday, 'valentines-nonromantic', 75);
      }

      if (holiday.key == 'new-year' &&
          hasAny(const <String>[
            'science fiction',
            'sci fi',
            'disaster',
            'action',
            'thriller',
            'horror',
            'comedy',
          ])) {
        addMatch(holiday, 'new-year-chaos', 75);
      }

      if (hasAny(const <String>['action', 'adventure'])) {
        addMatch(holiday, 'holiday-action-adventure', 75);
      }

      if (hasAny(const <String>[
        'science fiction',
        'sci fi',
        'sci-fi',
        'fantasy',
        'supernatural',
      ])) {
        addMatch(holiday, 'holiday-sci-fi-fantasy', 75);
      }

      if (hasAny(const <String>['comedy'])) {
        addMatch(holiday, 'holiday-comedy', 75);
      }

      if (hasAny(_darkGenres)) {
        addMatch(holiday, 'dark-holiday', 70);
      }
    }

    result.sort((a, b) {
      final seasonal = a.seasonalPriority.compareTo(b.seasonalPriority);
      if (seasonal != 0) return seasonal;
      return b.confidence.compareTo(a.confidence);
    });
    return result;
  }
}
