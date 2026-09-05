import '../database/database.dart';
import '../models/media.dart';

/// The type of item returned by Smart Search.
enum SearchResultType {
  movie,
  tvShow,
}

/// A single media search result.
///
/// Actors and other metadata are represented through the
/// [matchedBy] field. The frontend can use the complete media
/// object to determine how the result should be displayed.
class SearchResult {
  final Media media;
  final List<String> matchedBy;

  const SearchResult({
    required this.media,
    required this.matchedBy,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': media.type == MediaType.movie
          ? 'movie'
          : 'tvShow',
      'media': media.toJson(),
      'matchedBy': matchedBy,
    };
  }
}

/// Backend service responsible for global Smart Search.
///
/// This searches the complete media catalog, not merely the
/// titles owned by the current profile.
///
/// Searchable metadata includes:
///
/// - title
/// - description
/// - actors
/// - characters
/// - genres
/// - tags
/// - themes
/// - directors
/// - writers
/// - franchises
/// - references
/// - music
/// - year
class SearchService {
  final Database database;

  SearchService({
    required this.database,
  });

  /// Searches the complete catalog.
  ///
  /// Examples:
  ///
  ///     Spider-Man
  ///     Clint Eastwood
  ///     Jurassic Park
  ///     Christopher Daniel Barnes
  ///     1993
  ///
  /// Results are ranked by how strongly the search term
  /// matches the media metadata.
  List<SearchResult> search(
    String query, {
    int? limit,
  }) {
    final normalizedQuery =
        _normalize(query);

    if (normalizedQuery.isEmpty) {
      return [];
    }

    final catalog = database.getAllMedia();

    final results = <_ScoredSearchResult>[];

    for (final media in catalog) {
      final matchedBy = <String>[];
      int score = 0;

      // --------------------------------------------------------
      // TITLE
      // --------------------------------------------------------

      final title =
          _normalize(media.title);

      if (title == normalizedQuery) {
        score += 1000;
        matchedBy.add('title');
      } else if (title.startsWith(normalizedQuery)) {
        score += 800;
        matchedBy.add('title');
      } else if (title.contains(normalizedQuery)) {
        score += 600;
        matchedBy.add('title');
      }

      // --------------------------------------------------------
      // DESCRIPTION
      // --------------------------------------------------------

      if (_contains(
        media.description,
        normalizedQuery,
      )) {
        score += 100;
        matchedBy.add('description');
      }

      // --------------------------------------------------------
      // ACTORS
      // --------------------------------------------------------

      final actorMatch =
          _matchList(
        media.actors,
        normalizedQuery,
      );

      if (actorMatch) {
        score += 500;
        matchedBy.add('actor');
      }

      // --------------------------------------------------------
      // CHARACTERS
      // --------------------------------------------------------

      final characterMatch =
          _matchList(
        media.characters,
        normalizedQuery,
      );

      if (characterMatch) {
        score += 450;
        matchedBy.add('character');
      }

      // --------------------------------------------------------
      // FRANCHISES
      // --------------------------------------------------------

      final franchiseMatch =
          _matchList(
        media.franchises,
        normalizedQuery,
      );

      if (franchiseMatch) {
        score += 400;
        matchedBy.add('franchise');
      }

      // --------------------------------------------------------
      // REFERENCES
      // --------------------------------------------------------

      final referenceMatch =
          _matchList(
        media.references,
        normalizedQuery,
      );

      if (referenceMatch) {
        score += 350;
        matchedBy.add('reference');
      }

      // --------------------------------------------------------
      // DIRECTORS
      // --------------------------------------------------------

      final directorMatch =
          _matchList(
        media.directors,
        normalizedQuery,
      );

      if (directorMatch) {
        score += 300;
        matchedBy.add('director');
      }

      // --------------------------------------------------------
      // WRITERS
      // --------------------------------------------------------

      final writerMatch =
          _matchList(
        media.writers,
        normalizedQuery,
      );

      if (writerMatch) {
        score += 250;
        matchedBy.add('writer');
      }

      // --------------------------------------------------------
      // GENRES
      // --------------------------------------------------------

      final genreMatch =
          _matchList(
        media.genres,
        normalizedQuery,
      );

      if (genreMatch) {
        score += 200;
        matchedBy.add('genre');
      }

      // --------------------------------------------------------
      // THEMES
      // --------------------------------------------------------

      final themeMatch =
          _matchList(
        media.themes,
        normalizedQuery,
      );

      if (themeMatch) {
        score += 175;
        matchedBy.add('theme');
      }

      // --------------------------------------------------------
      // TAGS
      // --------------------------------------------------------

      final tagMatch =
          _matchList(
        media.tags,
        normalizedQuery,
      );

      if (tagMatch) {
        score += 150;
        matchedBy.add('tag');
      }

      // --------------------------------------------------------
      // MUSIC
      // --------------------------------------------------------

      final musicMatch =
          _matchList(
        media.music,
        normalizedQuery,
      );

      if (musicMatch) {
        score += 125;
        matchedBy.add('music');
      }

      // --------------------------------------------------------
      // YEAR
      // --------------------------------------------------------

      if (media.year != null &&
          media.year
              .toString()
              .toLowerCase() ==
              normalizedQuery) {
        score += 700;
        matchedBy.add('year');
      }

      // --------------------------------------------------------
      // RELEASE DATE
      // --------------------------------------------------------

      if (media.releaseDate != null &&
          media.releaseDate!
              .year
              .toString() ==
              normalizedQuery) {
        score += 700;

        if (!matchedBy.contains('year')) {
          matchedBy.add('year');
        }
      }

      // --------------------------------------------------------
      // KEEP MATCHES ONLY
      // --------------------------------------------------------

      if (score > 0) {
        results.add(
          _ScoredSearchResult(
            media: media,
            matchedBy: matchedBy,
            score: score,
          ),
        );
      }
    }

    // ----------------------------------------------------------
    // SORT BY RELEVANCE
    // ----------------------------------------------------------

    results.sort(
      (a, b) {
        final scoreComparison =
            b.score.compareTo(a.score);

        if (scoreComparison != 0) {
          return scoreComparison;
        }

        final yearA =
            a.media.year ?? 0;
        final yearB =
            b.media.year ?? 0;

        final yearComparison =
            yearB.compareTo(yearA);

        if (yearComparison != 0) {
          return yearComparison;
        }

        return a.media.title
            .toLowerCase()
            .compareTo(
              b.media.title.toLowerCase(),
            );
      },
    );

    final output = results
        .map(
          (result) => SearchResult(
            media: result.media,
            matchedBy: result.matchedBy,
          ),
        )
        .toList();

    if (limit != null &&
        limit > 0 &&
        output.length > limit) {
      return output.take(limit).toList();
    }

    return output;
  }

  /// Searches only movies.
  List<SearchResult> searchMovies(
    String query, {
    int? limit,
  }) {
    return search(
      query,
      limit: null,
    )
        .where(
          (result) =>
              result.media.type ==
              MediaType.movie,
        )
        .take(
          limit ?? 100,
        )
        .toList();
  }

  /// Searches only TV shows.
  List<SearchResult> searchTvShows(
    String query, {
    int? limit,
  }) {
    return search(
      query,
      limit: null,
    )
        .where(
          (result) =>
              result.media.type ==
              MediaType.tvShow,
        )
        .take(
          limit ?? 100,
        )
        .toList();
  }

  /// Returns every media item associated with a particular
  /// actor.
  ///
  /// This allows a search such as "Clint Eastwood" to return
  /// every movie/show containing that actor.
  List<SearchResult> searchActor(
    String actorName, {
    int? limit,
  }) {
    final normalized =
        _normalize(actorName);

    if (normalized.isEmpty) {
      return [];
    }

    final results = database
        .getAllMedia()
        .where(
          (media) => _matchList(
            media.actors,
            normalized,
          ),
        )
        .map(
          (media) => SearchResult(
            media: media,
            matchedBy: const ['actor'],
          ),
        )
        .toList();

    _sortByMostRecent(results);

    if (limit != null &&
        limit > 0 &&
        results.length > limit) {
      return results.take(limit).toList();
    }

    return results;
  }

  /// Returns every media item containing a reference to the
  /// searched subject.
  ///
  /// For example, if Ted 2 contains "Jurassic Park" in its
  /// references metadata, searching "Jurassic Park" can return
  /// Ted 2 as a reference result.
  List<SearchResult> searchReferences(
    String reference, {
    int? limit,
  }) {
    final normalized =
        _normalize(reference);

    if (normalized.isEmpty) {
      return [];
    }

    final results = database
        .getAllMedia()
        .where(
          (media) => _matchList(
            media.references,
            normalized,
          ),
        )
        .map(
          (media) => SearchResult(
            media: media,
            matchedBy: const ['reference'],
          ),
        )
        .toList();

    _sortByMostRecent(results);

    if (limit != null &&
        limit > 0 &&
        results.length > limit) {
      return results.take(limit).toList();
    }

    return results;
  }

  // ==========================================================
  // HELPERS
  // ==========================================================

  String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  bool _contains(
    String? value,
    String normalizedQuery,
  ) {
    if (value == null ||
        value.trim().isEmpty) {
      return false;
    }

    return _normalize(value)
        .contains(normalizedQuery);
  }

  bool _matchList(
    List<String> values,
    String normalizedQuery,
  ) {
    for (final value in values) {
      final normalizedValue =
          _normalize(value);

      if (normalizedValue == normalizedQuery ||
          normalizedValue.contains(normalizedQuery) ||
          normalizedQuery.contains(normalizedValue)) {
        return true;
      }
    }

    return false;
  }

  void _sortByMostRecent(
    List<SearchResult> results,
  ) {
    results.sort(
      (a, b) {
        final yearA =
            a.media.year ?? 0;
        final yearB =
            b.media.year ?? 0;

        final yearComparison =
            yearB.compareTo(yearA);

        if (yearComparison != 0) {
          return yearComparison;
        }

        return a.media.title
            .toLowerCase()
            .compareTo(
              b.media.title.toLowerCase(),
            );
      },
    );
  }
}

// ============================================================
// INTERNAL SEARCH RESULT
// ============================================================

class _ScoredSearchResult {
  final Media media;
  final List<String> matchedBy;
  final int score;

  const _ScoredSearchResult({
    required this.media,
    required this.matchedBy,
    required this.score,
  });
}