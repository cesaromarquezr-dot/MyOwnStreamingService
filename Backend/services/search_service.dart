// FILE: `Backend/services/search_service.dart`.
// Purpose: Implements the search service portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.
//
// Search is intentionally catalog-wide. Authorization/privacy decisions for
// which catalog entries an account may actually open or play remain outside
// this relevance engine.

import '../database/database.dart';
import '../models/media.dart';

/// The type of item returned by Smart Search.
enum SearchResultType {
  movie,
  tvShow,
}

/// A single media search result.
class SearchResult {
  final Media media;
  final List<String> matchedBy;

  const SearchResult({
    required this.media,
    required this.matchedBy,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': media.type == MediaType.movie ? 'movie' : 'tvShow',
      'media': media.toJson(),
      'matchedBy': List<String>.unmodifiable(matchedBy),
    };
  }
}

/// Backend service responsible for global Smart Search.
///
/// This searches the complete media catalog, not merely the titles owned by
/// the current profile.
///
/// Searchable metadata includes:
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
  static const int defaultLimit = 50;
  static const int maximumLimit = 100;
  static const int maximumQueryLength = 200;
  static const int maximumMetadataValueLength = 1000;

  final Database database;

  SearchService({
    required this.database,
  });

  /// Searches the complete catalog.
  ///
  /// Results are ranked by how strongly the search term matches the media
  /// metadata.
  List<SearchResult> search(
    String query, {
    int? limit,
  }) {
    final normalizedQuery = _validateAndNormalizeQuery(query);
    final effectiveLimit = _validateLimit(limit);

    if (normalizedQuery.isEmpty) {
      return [];
    }

    final catalog = database.getAllMedia();
    final results = <_ScoredSearchResult>[];

    for (final media in catalog) {
      final matchedBy = <String>[];
      var score = 0;

      // --------------------------------------------------------
      // TITLE
      // --------------------------------------------------------

      final title = _normalize(media.title);

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

      if (_contains(media.description, normalizedQuery)) {
        score += 100;
        matchedBy.add('description');
      }

      // --------------------------------------------------------
      // ACTORS
      // --------------------------------------------------------

      if (_matchList(media.actors, normalizedQuery)) {
        score += 500;
        matchedBy.add('actor');
      }

      // --------------------------------------------------------
      // CHARACTERS
      // --------------------------------------------------------

      if (_matchList(media.characters, normalizedQuery)) {
        score += 450;
        matchedBy.add('character');
      }

      // --------------------------------------------------------
      // FRANCHISES
      // --------------------------------------------------------

      if (_matchList(media.franchises, normalizedQuery)) {
        score += 400;
        matchedBy.add('franchise');
      }

      // --------------------------------------------------------
      // REFERENCES
      // --------------------------------------------------------

      if (_matchList(media.references, normalizedQuery)) {
        score += 350;
        matchedBy.add('reference');
      }

      // --------------------------------------------------------
      // DIRECTORS
      // --------------------------------------------------------

      if (_matchList(media.directors, normalizedQuery)) {
        score += 300;
        matchedBy.add('director');
      }

      // --------------------------------------------------------
      // WRITERS
      // --------------------------------------------------------

      if (_matchList(media.writers, normalizedQuery)) {
        score += 250;
        matchedBy.add('writer');
      }

      // --------------------------------------------------------
      // GENRES
      // --------------------------------------------------------

      if (_matchList(media.genres, normalizedQuery)) {
        score += 200;
        matchedBy.add('genre');
      }

      // --------------------------------------------------------
      // THEMES
      // --------------------------------------------------------

      if (_matchList(media.themes, normalizedQuery)) {
        score += 175;
        matchedBy.add('theme');
      }

      // --------------------------------------------------------
      // TAGS
      // --------------------------------------------------------

      if (_matchList(media.tags, normalizedQuery)) {
        score += 150;
        matchedBy.add('tag');
      }

      // --------------------------------------------------------
      // MUSIC
      // --------------------------------------------------------

      if (_matchList(media.music, normalizedQuery)) {
        score += 125;
        matchedBy.add('music');
      }

      // --------------------------------------------------------
      // YEAR
      // --------------------------------------------------------

      if (media.year != null &&
          media.year.toString() == normalizedQuery) {
        score += 700;
        matchedBy.add('year');
      }

      // --------------------------------------------------------
      // RELEASE DATE
      // --------------------------------------------------------

      if (media.releaseDate != null &&
          media.releaseDate!.year.toString() == normalizedQuery) {
        score += 700;

        if (!matchedBy.contains('year')) {
          matchedBy.add('year');
        }
      }

      if (score > 0) {
        results.add(
          _ScoredSearchResult(
            media: media,
            matchedBy: List<String>.unmodifiable(matchedBy),
            score: score,
          ),
        );
      }
    }

    _sortScoredResults(results);

    final selected = effectiveLimit == null
        ? results
        : results.take(effectiveLimit);

    return selected
        .map(
          (result) => SearchResult(
            media: result.media,
            matchedBy: result.matchedBy,
          ),
        )
        .toList(growable: false);
  }

  /// Searches only movies.
  List<SearchResult> searchMovies(
    String query, {
    int? limit,
  }) {
    final effectiveLimit = _validateLimit(limit);
    final results = search(query);

    final filtered = results.where(
      (result) => result.media.type == MediaType.movie,
    );

    return effectiveLimit == null
        ? filtered.toList(growable: false)
        : filtered.take(effectiveLimit).toList(growable: false);
  }

  /// Searches only TV shows.
  List<SearchResult> searchTvShows(
    String query, {
    int? limit,
  }) {
    final effectiveLimit = _validateLimit(limit);
    final results = search(query);

    final filtered = results.where(
      (result) => result.media.type == MediaType.tvShow,
    );

    return effectiveLimit == null
        ? filtered.toList(growable: false)
        : filtered.take(effectiveLimit).toList(growable: false);
  }

  /// Returns every media item associated with a particular actor.
  List<SearchResult> searchActor(
    String actorName, {
    int? limit,
  }) {
    final normalized = _validateAndNormalizeQuery(actorName);
    final effectiveLimit = _validateLimit(limit);

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

    _sortPublicResults(results);

    return effectiveLimit == null
        ? results
        : results.take(effectiveLimit).toList(growable: false);
  }

  /// Returns every media item containing a reference to the searched subject.
  List<SearchResult> searchReferences(
    String reference, {
    int? limit,
  }) {
    final normalized = _validateAndNormalizeQuery(reference);
    final effectiveLimit = _validateLimit(limit);

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

    _sortPublicResults(results);

    return effectiveLimit == null
        ? results
        : results.take(effectiveLimit).toList(growable: false);
  }

  // ==========================================================
  // VALIDATION
  // ==========================================================

  String _validateAndNormalizeQuery(String value) {
    if (value.contains('\u0000')) {
      throw Exception('Search query contains an invalid character.');
    }

    if (value.length > maximumQueryLength) {
      throw Exception(
        'Search query must not exceed $maximumQueryLength characters.',
      );
    }

    return _normalize(value);
  }

  int? _validateLimit(int? limit) {
    if (limit == null) {
      return defaultLimit;
    }

    if (limit < 1 || limit > maximumLimit) {
      throw Exception(
        'Search limit must be between 1 and $maximumLimit.',
      );
    }

    return limit;
  }

  // ==========================================================
  // NORMALIZATION / MATCHING
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
    if (value == null || value.trim().isEmpty) {
      return false;
    }

    if (value.length > maximumMetadataValueLength) {
      value = value.substring(0, maximumMetadataValueLength);
    }

    return _normalize(value).contains(normalizedQuery);
  }

  bool _matchList(
    List<String> values,
    String normalizedQuery,
  ) {
    if (normalizedQuery.isEmpty) {
      return false;
    }

    for (final value in values) {
      if (value.isEmpty) {
        continue;
      }

      var candidate = value;

      if (candidate.length > maximumMetadataValueLength) {
        candidate = candidate.substring(0, maximumMetadataValueLength);
      }

      final normalizedValue = _normalize(candidate);

      if (normalizedValue.isEmpty) {
        continue;
      }

      if (normalizedValue == normalizedQuery ||
          normalizedValue.contains(normalizedQuery)) {
        return true;
      }
    }

    return false;
  }

  // ==========================================================
  // SORTING
  // ==========================================================

  void _sortScoredResults(
    List<_ScoredSearchResult> results,
  ) {
    results.sort(
      (a, b) {
        final scoreComparison = b.score.compareTo(a.score);

        if (scoreComparison != 0) {
          return scoreComparison;
        }

        final yearA = a.media.year ?? 0;
        final yearB = b.media.year ?? 0;

        final yearComparison = yearB.compareTo(yearA);

        if (yearComparison != 0) {
          return yearComparison;
        }

        final titleComparison = _normalize(a.media.title).compareTo(
          _normalize(b.media.title),
        );

        if (titleComparison != 0) {
          return titleComparison;
        }

        // Stable deterministic tie-breaker for duplicate titles.
        return a.media.id.compareTo(b.media.id);
      },
    );
  }

  void _sortPublicResults(
    List<SearchResult> results,
  ) {
    results.sort(
      (a, b) {
        final yearA = a.media.year ?? 0;
        final yearB = b.media.year ?? 0;

        final yearComparison = yearB.compareTo(yearA);

        if (yearComparison != 0) {
          return yearComparison;
        }

        final titleComparison = _normalize(a.media.title).compareTo(
          _normalize(b.media.title),
        );

        if (titleComparison != 0) {
          return titleComparison;
        }

        return a.media.id.compareTo(b.media.id);
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