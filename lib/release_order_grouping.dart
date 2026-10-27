import 'app_core.dart';
import 'media_identity_sorting.dart';

/// Top-level content lanes shown inside each release-year group.
enum ReleaseOrderSection { movies, shows, music, other }

enum ReleaseOrderDirection { oldestFirst, newestFirst }

/// One year in the release timeline. A null year means release year is unknown.
/// Empty sections are omitted so the UI can render only lanes with content.
class ReleaseOrderYearGroup {
  final int? year;
  final Map<ReleaseOrderSection, List<MediaItem>> sections;

  const ReleaseOrderYearGroup({required this.year, required this.sections});

  String get label => year?.toString() ?? 'Release year unknown';

  int get itemCount => sections.values.fold<int>(
        0,
        (total, items) => total + items.length,
      );

  Iterable<MediaItem> get allItems sync* {
    for (final section in ReleaseOrderSection.values) {
      yield* sections[section] ?? const <MediaItem>[];
    }
  }
}

/// Groups a mixed library by release year, then by broad media type. Exact
/// release dates determine the order within each section; entries without an
/// exact date follow in a stable title order rather than receiving invented
/// dates. The 2015 movie dates supplied by the user are retained as fallbacks
/// for those six titles when an imported record has only the year.
class ReleaseOrderGrouping {
  const ReleaseOrderGrouping._();

  static final Map<String, DateTime> _userProvided2015MovieDates =
      <String, DateTime>{
    'ant man': DateTime.utc(2015, 7, 17),
    'avengers age of ultron': DateTime.utc(2015, 5, 1),
    'goosebumps': DateTime.utc(2015, 10, 16),
    'jurassic world': DateTime.utc(2015, 6, 12),
    'minions': DateTime.utc(2015, 6, 11),
    'star wars the force awakens': DateTime.utc(2015, 12, 18),
  };

  static const List<ReleaseOrderSection> sectionOrder =
      <ReleaseOrderSection>[
    ReleaseOrderSection.movies,
    ReleaseOrderSection.shows,
    ReleaseOrderSection.music,
    ReleaseOrderSection.other,
  ];

  static List<ReleaseOrderYearGroup> group(
    Iterable<MediaItem> items, {
    ReleaseOrderDirection direction = ReleaseOrderDirection.newestFirst,
    bool includeUnknownYear = true,
  }) {
    final grouped = <int?, Map<ReleaseOrderSection, List<MediaItem>>>{};

    for (final item in items) {
      final year = releaseYearFor(item);
      if (year == null && !includeUnknownYear) continue;
      final section = sectionFor(item);
      final yearBucket = grouped.putIfAbsent(
        year,
        () => <ReleaseOrderSection, List<MediaItem>>{},
      );
      yearBucket.putIfAbsent(section, () => <MediaItem>[]).add(item);
    }

    final years = grouped.keys.whereType<int>().toList();
    years.sort((a, b) => direction == ReleaseOrderDirection.newestFirst
        ? b.compareTo(a)
        : a.compareTo(b));
    final orderedYears = <int?>[...years];
    // Unknown release years are always last, independent of direction.
    if (grouped.containsKey(null)) orderedYears.add(null);

    return orderedYears.map((year) {
      final rawSections = grouped[year]!;
      final orderedSections = <ReleaseOrderSection, List<MediaItem>>{};
      for (final section in sectionOrder) {
        final contents = rawSections[section];
        if (contents == null || contents.isEmpty) continue;
        orderedSections[section] = List<MediaItem>.unmodifiable(
          _sortWithinSection(contents),
        );
      }
      return ReleaseOrderYearGroup(
        year: year,
        sections: Map<ReleaseOrderSection, List<MediaItem>>.unmodifiable(
          orderedSections,
        ),
      );
    }).toList(growable: false);
  }

  /// Exact calendar date used for chronological ordering and display. An
  /// edition's date is preferred to the original work's date; a series uses
  /// its start/premiere date. When no precise date exists, the six 2015 movie
  /// examples supplied for this feature have an explicit curated fallback.
  static DateTime? releaseDateFor(MediaItem item) {
    if (item.isSeries) {
      if (item.seriesStartDate != null) return item.seriesStartDate;
      if (item.releaseDate != null &&
          (item.seriesStartYear == null ||
              item.seriesStartYear == item.releaseDate!.year)) {
        return item.releaseDate;
      }
      return null;
    }

    if (item.editionReleaseDate != null) return item.editionReleaseDate;
    if (item.editionReleaseYear != null &&
        item.editionReleaseYear != item.releaseYear) {
      // Do not sort a later edition using the original work's release date.
      return null;
    }
    if (item.releaseDate != null) return item.releaseDate;
    return _userProvidedMovieDate(item);
  }

  /// Sorts catalog items by the most precise known release date. Exact dates
  /// win; if only a year is known, January 1 is used as a stable year-level
  /// fallback. Items without any date/year always remain last in both orders.
  static int compareMediaByReleaseDate(
    MediaItem a,
    MediaItem b, {
    required bool newestFirst,
  }) {
    DateTime? sortDate(MediaItem item) {
      final exact = releaseDateFor(item);
      if (exact != null) return exact;
      final year = releaseYearFor(item);
      return year == null ? null : DateTime(year, 1, 1);
    }

    final aDate = sortDate(a);
    final bDate = sortDate(b);
    if (aDate == null || bDate == null) {
      if (aDate == null && bDate == null) {
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      }
      return aDate == null ? 1 : -1;
    }
    final byDate = aDate.compareTo(bDate);
    if (byDate != 0) return newestFirst ? -byDate : byDate;
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  }

  /// Chooses the most precise known year for timeline placement.
  static int? releaseYearFor(MediaItem item) {
    if (item.isSeries) {
      return item.seriesStartDate?.year ??
          item.seriesStartYear ??
          item.releaseDate?.year ??
          item.releaseYear ??
          _yearFromDisplayLabel(item.displayYearLabel);
    }
    return item.editionReleaseDate?.year ??
        item.editionReleaseYear ??
        item.releaseDate?.year ??
        item.releaseYear ??
        _userProvidedMovieDate(item)?.year;
  }

  static DateTime? _userProvidedMovieDate(MediaItem item) {
    if (sectionFor(item) != ReleaseOrderSection.movies) return null;
    if (item.releaseYear != null && item.releaseYear != 2015) return null;
    if (item.editionReleaseYear != null && item.editionReleaseYear != 2015) {
      return null;
    }

    final possibleTitles = <String?>[
      item.title,
      item.canonicalTitle,
      item.originalTitle,
    ];
    for (final title in possibleTitles) {
      final clean = title?.trim() ?? '';
      if (clean.isEmpty) continue;
      final withoutYearSuffix = clean.replaceFirst(
        RegExp(r'\s*\(\d{4}\)\s*$'),
        '',
      );
      final normalized = MediaIdentitySorting.normalizedTitle(withoutYearSuffix);
      final knownDate = _userProvided2015MovieDates[normalized];
      if (knownDate != null) return knownDate;
    }
    return null;
  }

  static List<MediaItem> _sortWithinSection(List<MediaItem> items) {
    final dated = <MediaItem>[];
    final undated = <MediaItem>[];
    for (final item in items) {
      if (releaseDateFor(item) == null) {
        undated.add(item);
      } else {
        dated.add(item);
      }
    }

    dated.sort((a, b) {
      final left = releaseDateFor(a)!;
      final right = releaseDateFor(b)!;
      var compared = _dateKey(left).compareTo(_dateKey(right));
      if (compared != 0) return compared;
      return _compareByTitle(a, b);
    });
    return <MediaItem>[
      ...dated,
      ...MediaIdentitySorting.byTitle(undated),
    ];
  }

  static int _dateKey(DateTime date) =>
      date.year * 10000 + date.month * 100 + date.day;

  static int _compareByTitle(MediaItem a, MediaItem b) {
    final ordered = MediaIdentitySorting.byTitle(<MediaItem>[a, b]);
    if (identical(ordered.first, a) && !identical(a, b)) return -1;
    if (identical(ordered.first, b) && !identical(a, b)) return 1;
    return 0;
  }

  static int? _yearFromDisplayLabel(String? label) {
    if (label == null) return null;
    final match = RegExp(r'^(\d{4})').firstMatch(label.trim());
    return int.tryParse(match?.group(1) ?? '');
  }

  static ReleaseOrderSection sectionFor(MediaItem item) {
    final normalized = item.type.toLowerCase().replaceAll(
          RegExp(r'[\s_-]+'),
          '',
        );

    if (item.isSeries ||
        normalized.contains('episode') ||
        normalized.contains('season') ||
        normalized == 'miniseries' ||
        normalized == 'limitedseries') {
      return ReleaseOrderSection.shows;
    }

    if (normalized == 'movie' ||
        normalized == 'film' ||
        normalized == 'featurefilm' ||
        normalized == 'shortfilm' ||
        normalized == 'video') {
      return ReleaseOrderSection.movies;
    }

    if (normalized == 'album' ||
        normalized == 'musicalbum' ||
        normalized == 'song' ||
        normalized == 'track' ||
        normalized == 'audio' ||
        normalized == 'music' ||
        normalized == 'single' ||
        normalized == 'soundtrack' ||
        normalized == 'audiobook') {
      return ReleaseOrderSection.music;
    }

    return ReleaseOrderSection.other;
  }

  /// Genre filtering is a filter, not a grouping operation, so an album tagged
  /// with multiple genres never appears as duplicate entries in the timeline.
  static List<MediaItem> filterByGenre(
    Iterable<MediaItem> items,
    String genre,
  ) {
    final target = _normalizeGenre(genre);
    if (target.isEmpty) return items.toList(growable: false);
    return items
        .where((item) => item.genres.any((value) => _normalizeGenre(value) == target))
        .toList(growable: false);
  }

  static String _normalizeGenre(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
