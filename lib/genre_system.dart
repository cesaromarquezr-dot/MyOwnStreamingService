/// Shared genre classification, hybrid labels, and discovery helpers.
///
/// The canonical genre list remains the source of truth. Hybrid labels are
/// derived from combinations, so the catalog does not need a separate record
/// for every possible genre pair.
class GenreSystem {
  GenreSystem._();

  static const List<String> canonicalGenres = <String>[
    'Action', 'Adventure', 'Animation', 'Comedy', 'Crime', 'Documentary',
    'Drama', 'Family', 'Fantasy', 'History', 'Horror', 'Music', 'Mystery',
    'Romance', 'Science Fiction', 'Thriller', 'War', 'Western', 'Reality',
    'News', 'Talk', 'Sport', 'Musical', 'Biography', 'Superhero',
  ];

  static const Map<String, String> _aliases = <String, String>{
    'sci fi': 'Science Fiction',
    'sci-fi': 'Science Fiction',
    'scifi': 'Science Fiction',
    'sf': 'Science Fiction',
    'romantic': 'Romance',
    'romantic thriller': 'Romantic Thriller',
    'horror comedy': 'Horror-Comedy',
    'romantic comedy': 'Romantic Comedy',
    'romcom': 'Romance',
    'rom com': 'Romance',
    'animated': 'Animation',
    'cartoon': 'Animation',
    'kids': 'Family',
    'children': 'Family',
    'biographical': 'Biography',
    'doc': 'Documentary',
    'true crime': 'Crime',
    'super heroes': 'Superhero',
    'super-hero': 'Superhero',
  };

  static const Map<String, String> _hybridLabels = <String, String>{
    'comedy|horror': 'Horror-Comedy',
    'romance|thriller': 'Romantic Thriller',
    'action|comedy': 'Action-Comedy',
    'comedy|romance': 'Romantic Comedy',
    'horror|science fiction': 'Sci-Fi Horror',
    'adventure|fantasy': 'Fantasy Adventure',
    'crime|thriller': 'Crime Thriller',
    'mystery|thriller': 'Mystery Thriller',
    'animation|fantasy': 'Animated Fantasy',
    'drama|romance': 'Romantic Drama',
    'action|thriller': 'Action Thriller',
    'horror|thriller': 'Horror Thriller',
    'action|science fiction': 'Sci-Fi Action',
    'drama|thriller': 'Drama Thriller',
    'fantasy|romance': 'Fantasy Romance',
    'crime|drama': 'Crime Drama',
    'adventure|science fiction': 'Sci-Fi Adventure',
    'animation|comedy': 'Animated Comedy',
    'animation|family': 'Family Animation',
    'drama|science fiction': 'Sci-Fi Drama',
    'comedy|drama': 'Comedy-Drama',
    'horror|mystery': 'Horror Mystery',
    'romance|science fiction': 'Sci-Fi Romance',
    'romance|western': 'Western Romance',
    'drama|western': 'Western Drama',
  };

  static String _key(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[_\-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  static String canonicalize(String value) {
    final key = _key(value);
    for (final genre in canonicalGenres) {
      if (_key(genre) == key) return genre;
    }
    return _aliases[key] ?? value.trim();
  }

  static List<String> normalizeGenres(Iterable<String> genres) {
    final result = <String>[];
    final seen = <String>{};
    for (final raw in genres) {
      if (raw.trim().isEmpty) continue;
      final canonical = canonicalize(raw);
      final key = _key(canonical);
      if (seen.add(key)) result.add(canonical);
    }
    return List<String>.unmodifiable(result);
  }

  /// Human-friendly hybrid name for known pairs, or the canonical genre list.
  ///
  /// Known pairs are searched across every pair (not just the first two genres),
  /// so a title such as Horror + Comedy + Fantasy still gets the Horror-Comedy
  /// label regardless of metadata order.
  static String displayLabel(Iterable<String> genres) {
    final normalized = normalizeGenres(genres);
    if (normalized.isEmpty) return 'Genre not specified';
    if (normalized.length == 1) return normalized.single;

    for (var i = 0; i < normalized.length; i++) {
      for (var j = i + 1; j < normalized.length; j++) {
        final pair = <String>[_key(normalized[i]), _key(normalized[j])]..sort();
        final hybrid = _hybridLabels[pair.join('|')];
        if (hybrid != null) {
          final remaining = <String>[
            for (var k = 0; k < normalized.length; k++)
              if (k != i && k != j) normalized[k],
          ];
          return remaining.isEmpty ? hybrid : '$hybrid • ${remaining.join(' • ')}';
        }
      }
    }
    return normalized.join(' • ');
  }

  /// Expands a recognized hybrid label to its canonical component genres.
  /// This allows users to filter by a label such as "Horror-Comedy" even though
  /// catalog records store the individual genres rather than a duplicate label.
  static List<String> componentsFor(String genreOrHybrid) {
    final wanted = _key(genreOrHybrid);
    for (final entry in _hybridLabels.entries) {
      if (_key(entry.value) == wanted) {
        return List<String>.unmodifiable(entry.key.split('|').map(canonicalize));
      }
    }
    return List<String>.unmodifiable([canonicalize(genreOrHybrid)]);
  }

  /// Returns genre names plus common hybrid labels for search indexing.
  static List<String> searchTerms(Iterable<String> genres) {
    final normalized = normalizeGenres(genres);
    final terms = <String>[...normalized];
    for (final genre in normalized) {
      terms.addAll(componentsFor(genre));
    }
    if (normalized.length >= 2) {
      terms.add(displayLabel(normalized));
      for (var i = 0; i < normalized.length; i++) {
        for (var j = i + 1; j < normalized.length; j++) {
          terms.add(displayLabel(<String>[normalized[i], normalized[j]]));
        }
      }
    }
    final seen = <String>{};
    return terms.where((term) => seen.add(_key(term))).toList(growable: false);
  }

  /// Matches all requested genres by default; set [matchAll] false for OR.
  static bool matchesGenres(
    Iterable<String> itemGenres,
    Iterable<String> selectedGenres, {
    bool matchAll = true,
  }) {
    final selected = selectedGenres
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (selected.isEmpty) return true;
    final item = <String>{};
    for (final genre in normalizeGenres(itemGenres)) {
      item.addAll(componentsFor(genre).map(_key));
    }
    bool matchesOne(String selectedGenre) {
      final components = componentsFor(selectedGenre).map(_key).toList();
      // A hybrid filter always means both (or all) of its component genres.
      return components.length > 1
          ? components.every(item.contains)
          : item.contains(components.single);
    }
    return matchAll
        ? selected.every(matchesOne)
        : selected.any(matchesOne);
  }

  /// Parses common natural-language hybrid genre phrases from a query.
  static List<String> genresMentionedIn(String query) {
    final normalizedQuery = ' ${_key(query)} ';
    final found = <String>[];
    final candidates = <String>{
      ...canonicalGenres,
      ..._aliases.keys,
      ..._hybridLabels.values,
      'sci-fi',
      'sci fi',
    }.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final candidate in candidates) {
      final key = _key(candidate);
      if (key.isEmpty) continue;
      if (RegExp('(^| )${RegExp.escape(key)}( |\$)').hasMatch(normalizedQuery)) {
        final canonical = canonicalize(candidate);
        if (!found.any((value) => _key(value) == _key(canonical))) {
          found.add(canonical);
        }
      }
    }
    return List<String>.unmodifiable(found);
  }

  /// Simple mood filters used as a transparent discovery signal, not a claim
  /// that a title's mood has been independently verified.
  static const Map<String, List<String>> moodGenreHints = <String, List<String>>{
    'funny': <String>['Comedy', 'Animation'],
    'scary': <String>['Horror', 'Thriller'],
    'romantic': <String>['Romance', 'Drama'],
    'thought-provoking': <String>['Drama', 'Documentary', 'Science Fiction'],
    'adventurous': <String>['Adventure', 'Action', 'Fantasy'],
    'comforting': <String>['Family', 'Comedy', 'Romance'],
    'intense': <String>['Thriller', 'Action', 'Horror', 'Crime'],
    'mysterious': <String>['Mystery', 'Thriller', 'Crime'],
  };

  static List<String> shelvesFor(Iterable<String> genres) {
    final normalized = normalizeGenres(genres);
    final shelves = <String>[];
    for (var i = 0; i < normalized.length; i++) {
      for (var j = i + 1; j < normalized.length; j++) {
        final label = displayLabel(<String>[normalized[i], normalized[j]]);
        if (label.contains(' • ')) continue;
        if (!shelves.contains(label)) shelves.add(label);
      }
    }
    return shelves;
  }
}
