/// Genre classification helpers for the music library.
///
/// Music genres intentionally live separately from the movie/TV GenreSystem:
/// a music track can combine broad genres and fine-grained styles without
/// making those categories appear as movie genres.
class MusicGenreSystem {
  MusicGenreSystem._();

  static const List<String> canonicalGenres = <String>[
    'Alternative Rock',
    'Ambient',
    'Art Pop',
    'Art Rock',
    'Avant-Garde Metal',
    'Ballad',
    'Big Band',
    'Blues',
    'Bluegrass',
    'British Rap',
    'Classical',
    'Country',
    'Country Rap',
    'Country-Pop',
    'Dance',
    'Disco',
    'Drum and Bass',
    'EDM',
    'Electronic',
    'Experimental',
    'Folk',
    'Funk',
    'Funk Metal',
    'Garage Rock',
    'Gospel',
    'Grime',
    'Hard Rock',
    'Heavy Metal',
    'Hip-Hop',
    'House',
    'Industrial',
    'Industrial EDM',
    'Industrial Metal',
    'Jazz',
    'Japanese Pop-Metal',
    'K-Pop',
    'Latin',
    'Metal',
    'Metalcore',
    'Musical Theatre',
    'New Wave',
    'Opera',
    'Pop',
    'Pop Metal',
    'Pop Rock',
    'Progressive Metal',
    'Progressive Rock',
    'Punk Rock',
    'R&B',
    'Rap',
    'Rap Rock',
    'Reggae',
    'Rock',
    'Rock Opera',
    'Ska',
    'Soul',
    'Soundtrack',
    'Swing',
    'Symphonic Metal',
    'Techno',
    'Thrash Metal',
    'Trap',
    'UK Garage',
    'World Music',
  ];

  static const Map<String, String> _aliases = <String, String>{
    'alt rock': 'Alternative Rock',
    'alternative': 'Alternative Rock',
    'hip hop': 'Hip-Hop',
    'hiphop': 'Hip-Hop',
    'rap hip hop': 'Hip-Hop',
    'r and b': 'R&B',
    'rhythm and blues': 'R&B',
    'edm': 'EDM',
    'electronic dance music': 'EDM',
    'electronica': 'Electronic',
    'prog rock': 'Progressive Rock',
    'prog metal': 'Progressive Metal',
    'heavy rock': 'Hard Rock',
    'metal': 'Metal',
    'ukg': 'UK Garage',
    'garage': 'Garage Rock',
    'country pop': 'Country-Pop',
    'country-pop': 'Country-Pop',
    'country rap': 'Country Rap',
    'country-rap': 'Country Rap',
    'rap rock': 'Rap Rock',
    'pop rock': 'Pop Rock',
    'pop-rock': 'Pop Rock',
    'pop metal': 'Pop Metal',
    'pop-metal': 'Pop Metal',
    'j-pop metal': 'Japanese Pop-Metal',
    'japanese pop metal': 'Japanese Pop-Metal',
    'musical theater': 'Musical Theatre',
    'rock opera': 'Rock Opera',
    'big-band': 'Big Band',
    'drum n bass': 'Drum and Bass',
    'drum & bass': 'Drum and Bass',
  };

  static const List<_MusicBlendRule> _blendRules = <_MusicBlendRule>[
    _MusicBlendRule(
      label: 'Industrial EDM / Metal / Pop-Rock Fusion',
      components: <String>[
        'Electronic',
        'Metal',
        'Industrial EDM',
        'Thrash Metal',
        'Japanese Pop-Metal',
        'Pop Rock',
      ],
    ),
    _MusicBlendRule(
      label: 'Country-Rap / Pop Crossover',
      components: <String>['Country', 'Hip-Hop', 'Pop'],
    ),
    _MusicBlendRule(
      label: 'Opera-Rock Ballad',
      components: <String>['Rock', 'Opera', 'Hard Rock', 'Ballad'],
    ),
    _MusicBlendRule(
      label: 'Swing / Big Band Metal Fusion',
      components: <String>['Swing', 'Big Band', 'Metal', 'Heavy Metal'],
    ),
    _MusicBlendRule(
      label: 'UK Garage / Grime / Hip-Hop',
      components: <String>['UK Garage', 'Grime', 'Hip-Hop'],
    ),
    _MusicBlendRule(
      label: 'Funk Metal / Rap / Classical Fusion',
      components: <String>['Rock', 'Metal', 'Hip-Hop', 'Funk Metal', 'Rap Rock', 'Classical'],
    ),
    _MusicBlendRule(
      label: 'Progressive Art Rock',
      components: <String>['Alternative Rock', 'Progressive Rock', 'Art Rock'],
    ),
    _MusicBlendRule(
      label: 'Musical Theatre / Rock Opera',
      components: <String>['Musical Theatre', 'Opera', 'Rock'],
    ),
    _MusicBlendRule(
      label: 'Symphonic Metal + Rap',
      components: <String>['Symphonic Metal', 'Hip-Hop'],
    ),
    _MusicBlendRule(
      label: 'Country-Rap Crossover',
      components: <String>['Country', 'Hip-Hop'],
    ),
    _MusicBlendRule(
      label: 'Jazz Rap',
      components: <String>['Jazz', 'Hip-Hop'],
    ),
    _MusicBlendRule(
      label: 'Jazz Rock',
      components: <String>['Jazz', 'Rock'],
    ),
    _MusicBlendRule(
      label: 'Electronic Rock',
      components: <String>['Electronic', 'Rock'],
    ),
    _MusicBlendRule(
      label: 'Pop Rock',
      components: <String>['Pop', 'Rock'],
    ),
    _MusicBlendRule(
      label: 'Funk Metal',
      components: <String>['Funk', 'Metal'],
    ),
    _MusicBlendRule(
      label: 'Pop Metal',
      components: <String>['Pop', 'Metal'],
    ),
    _MusicBlendRule(
      label: 'Pop-R&B',
      components: <String>['Pop', 'R&B'],
    ),
    _MusicBlendRule(
      label: 'Funk Soul',
      components: <String>['Funk', 'Soul'],
    ),
    _MusicBlendRule(
      label: 'Reggae Fusion',
      components: <String>['Reggae', 'Hip-Hop'],
    ),
    _MusicBlendRule(
      label: 'Rap Rock',
      components: <String>['Rock', 'Hip-Hop'],
    ),
    _MusicBlendRule(
      label: 'Country-Pop',
      components: <String>['Country', 'Pop'],
    ),
  ];

  static const Map<String, List<String>> _impliedGenres =
      <String, List<String>>{
    'country rap': <String>['Country', 'Hip-Hop'],
    'country pop': <String>['Country', 'Pop'],
    'hip hop': <String>['Rap'],
    'rap': <String>['Hip-Hop'],
    'jazz rap': <String>['Jazz', 'Hip-Hop'],
    'jazz rock': <String>['Jazz', 'Rock'],
    'electronic rock': <String>['Electronic', 'Rock'],
    'pop r&b': <String>['Pop', 'R&B'],
    'funk soul': <String>['Funk', 'Soul'],
    'reggae fusion': <String>['Reggae', 'Hip-Hop'],
    'rap rock': <String>['Rock', 'Hip-Hop'],
    'pop rock': <String>['Pop', 'Rock'],
    'pop metal': <String>['Pop', 'Metal'],
    'symphonic metal': <String>['Metal'],
    'industrial metal': <String>['Industrial', 'Metal'],
    'funk metal': <String>['Funk', 'Metal'],
    'progressive metal': <String>['Progressive Rock', 'Metal'],
    'japanese pop metal': <String>['Pop', 'Metal'],
    'hard rock': <String>['Rock'],
    'alternative rock': <String>['Rock'],
    'progressive rock': <String>['Rock'],
    'art rock': <String>['Rock'],
    'thrash metal': <String>['Metal'],
    'heavy metal': <String>['Metal'],
  };

  static String _key(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[_\-]+'), ' ')
      .replaceAll(RegExp(r'[^a-z0-9&+ ]'), '')
      .replaceAll(RegExp(r'\s+'), ' ');

  static String canonicalize(String raw) {
    final key = _key(raw);
    if (key.isEmpty) return '';
    for (final genre in canonicalGenres) {
      if (_key(genre) == key) return genre;
    }
    return _aliases[key] ?? _titleCase(raw.trim());
  }

  static String _titleCase(String value) {
    final clean = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.isEmpty) return clean;
    return clean.split(' ').map((word) {
      if (word.isEmpty) return word;
      if (word.toUpperCase() == word && word.length <= 4) return word;
      return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
    }).join(' ');
  }

  static List<String> normalizeGenres(Iterable<String> genres) {
    final result = <String>[];
    final seen = <String>{};
    for (final raw in genres) {
      if (raw.trim().isEmpty) continue;
      final canonical = canonicalize(raw);
      final key = _key(canonical);
      if (key.isNotEmpty && seen.add(key)) result.add(canonical);
    }
    return List<String>.unmodifiable(result);
  }

  static List<String> allTags(
    Iterable<String> genres, {
    Iterable<String> subgenres = const <String>[],
  }) => normalizeGenres(<String>[...genres, ...subgenres]);

  static bool hasBlend(
    Iterable<String> genres, {
    Iterable<String> subgenres = const <String>[],
  }) {
    final mainGenres = normalizeGenres(genres);
    final styles = normalizeGenres(subgenres);
    if (mainGenres.length > 1 || styles.length > 1) return true;
    // A named crossover subgenre (for example Country Rap or Rap Rock) can
    // communicate multiple parent genres even when the scanner found one tag.
    for (final tag in <String>[...mainGenres, ...styles]) {
      if ((_impliedGenres[_key(tag)]?.length ?? 0) > 1) return true;
    }
    return false;
  }

  /// Creates a readable style label. Recognized blends get editorial labels;
  /// other combinations retain every normalized tag rather than losing data.
  static String displayLabel(
    Iterable<String> genres, {
    Iterable<String> subgenres = const <String>[],
  }) {
    final mainGenres = normalizeGenres(genres);
    final styles = normalizeGenres(subgenres);
    final normalized = normalizeGenres(<String>[...mainGenres, ...styles]);
    if (normalized.isEmpty) return 'Genre not specified';
    if (normalized.length == 1) return normalized.single;
    final keys = _expandedKeys(normalized);

    for (final rule in _blendRules) {
      final requiredKeys = rule.components.map(_key).toSet();
      if (requiredKeys.every(keys.contains)) {
        final additionalMainGenres = mainGenres.where((genre) {
          final key = _key(genre);
          if (requiredKeys.contains(key)) return false;
          final implied = _impliedGenres[key];
          if (implied != null && implied.isNotEmpty) {
            return !implied.map(_key).every(requiredKeys.contains);
          }
          return true;
        }).toList(growable: false);
        if (additionalMainGenres.isEmpty) return rule.label;
        return '${rule.label} • ${additionalMainGenres.join(' + ')}';
      }
    }

    if (keys.contains('country') && keys.contains('pop')) return 'Country-Pop';
    if (keys.contains('country') && keys.contains('hip hop')) {
      return 'Country-Rap Crossover';
    }
    if (keys.contains('rock') && keys.contains('hip hop')) return 'Rap Rock';
    return normalized.join(' + ');
  }

  /// Search index terms include all tags, the blend label, and pairwise labels.
  static List<String> searchTerms(
    Iterable<String> genres, {
    Iterable<String> subgenres = const <String>[],
  }) {
    final mainGenres = normalizeGenres(genres);
    final styles = normalizeGenres(subgenres);
    final normalized = normalizeGenres(<String>[...mainGenres, ...styles]);
    final terms = <String>[...normalized];
    if (normalized.length > 1) {
      terms.add(displayLabel(mainGenres, subgenres: styles));
      for (var i = 0; i < normalized.length; i++) {
        for (var j = i + 1; j < normalized.length; j++) {
          terms.add(displayLabel(<String>[normalized[i], normalized[j]]));
        }
      }
    }
    final seen = <String>{};
    return List<String>.unmodifiable(
      terms.where((term) => term.trim().isNotEmpty && seen.add(_key(term))),
    );
  }

  /// Matches individual genres, or a recognized hybrid label as an AND filter.
  static bool matchesGenres(
    Iterable<String> itemGenres,
    Iterable<String> selectedGenres, {
    Iterable<String> itemSubgenres = const <String>[],
    bool matchAll = true,
  }) {
    final item = _expandedKeys(allTags(itemGenres, subgenres: itemSubgenres));
    final selected = normalizeGenres(selectedGenres);
    if (selected.isEmpty) return true;

    bool matchesOne(String selection) {
      final labelKey = _key(selection);
      for (final rule in _blendRules) {
        if (_key(rule.label) == labelKey) {
          return rule.components.map(_key).every(item.contains);
        }
      }
      final canonical = _key(canonicalize(selection));
      final implied = _impliedGenres[canonical];
      if (implied != null && implied.length > 1) {
        return implied.map(_key).every(item.contains);
      }
      return item.contains(canonical);
    }

    return matchAll
        ? selected.every(matchesOne)
        : selected.any(matchesOne);
  }

  static Set<String> _expandedKeys(Iterable<String> values) {
    final expanded = <String>{};
    for (final value in values) {
      final key = _key(value);
      if (key.isEmpty) continue;
      expanded.add(key);
      for (final implied in _impliedGenres[key] ?? const <String>[]) {
        expanded.add(_key(implied));
      }
    }
    return expanded;
  }

  /// Recognized catalog examples can supplement thin/one-tag ID3 metadata.
  /// The match requires both a known title and a compatible artist credit.
  static MusicGenreExample? referenceExampleFor(String title, String artist) {
    final titleKey = _key(title);
    final plainTitleKey = _key(title.replaceFirst(
      RegExp(r'\s*[\(\[]?\s*(?:feat(?:uring)?\.?|ft\.?|remix|radio edit)\b.*$', caseSensitive: false),
      '',
    ));
    final artistKey = _key(artist);
    if (titleKey.isEmpty || artistKey.isEmpty) return null;
    for (final example in referenceExamples) {
      final exampleTitleKey = _key(example.title);
      if (exampleTitleKey != titleKey && exampleTitleKey != plainTitleKey) {
        continue;
      }
      if (example.artistMatchTokens.any((token) => artistKey.contains(_key(token))) ||
          _key(example.artist) == artistKey) {
        return example;
      }
    }
    return null;
  }

  static const List<MusicGenreExample> referenceExamples =
      <MusicGenreExample>[
    MusicGenreExample(
      title: 'Old Town Road',
      artist: 'Lil Nas X (Billy Ray Cyrus remix version)',
      artistMatchTokens: <String>['Lil Nas X'],
      genres: <String>['Country', 'Hip-Hop', 'Pop'],
      subgenres: <String>['Country Rap', 'Trap'],
      description: 'Country storytelling and twang cross over with rap, trap, and pop appeal.',
    ),
    MusicGenreExample(
      title: 'Bohemian Rhapsody',
      artist: 'Queen',
      artistMatchTokens: <String>['Queen'],
      genres: <String>['Rock', 'Opera'],
      subgenres: <String>['Ballad', 'Art Rock', 'Progressive Rock', 'Hard Rock'],
      description: 'A multi-section song that moves through ballad, operatic, and hard-rock passages.',
    ),
    MusicGenreExample(
      title: 'Walk This Way',
      artist: 'Run-D.M.C. & Aerosmith',
      artistMatchTokens: <String>['Run DMC', 'Aerosmith'],
      genres: <String>['Hip-Hop', 'Rock'],
      subgenres: <String>['Rap Rock', 'Hard Rock'],
      description: 'A landmark crossover pairing hip-hop performance with rock instrumentation.',
    ),
    MusicGenreExample(
      title: 'Paranoid Android',
      artist: 'Radiohead',
      artistMatchTokens: <String>['Radiohead'],
      genres: <String>['Alternative Rock', 'Progressive Rock', 'Art Rock'],
      subgenres: <String>['Experimental'],
      description: 'An alternative/art-rock track built from several contrasting sections.',
    ),
    MusicGenreExample(
      title: 'Concrete',
      artist: 'Poppy',
      artistMatchTokens: <String>['Poppy'],
      genres: <String>['Electronic', 'Metal', 'Pop Rock'],
      subgenres: <String>['Industrial EDM', 'Thrash Metal', 'Japanese Pop-Metal'],
      description: 'A deliberately abrupt collision of electronic, metal, and pop-rock textures.',
    ),
    MusicGenreExample(
      title: 'And We Run',
      artist: 'Within Temptation feat. Xzibit',
      artistMatchTokens: <String>['Within Temptation'],
      genres: <String>['Symphonic Metal', 'Hip-Hop'],
      subgenres: <String>['Rap'],
      description: 'Symphonic-metal arrangements meet a featured rap performance.',
    ),
    MusicGenreExample(
      title: "A Tap Dancer's Dilemma",
      artist: 'Diablo Swing Orchestra',
      artistMatchTokens: <String>['Diablo Swing Orchestra'],
      genres: <String>['Swing', 'Big Band', 'Metal'],
      subgenres: <String>['Jazz', 'Heavy Metal', 'Avant-Garde Metal'],
      description: 'Swing and big-band color meet heavy, theatrical metal.',
    ),
    MusicGenreExample(
      title: 'The Final Lair (Down Once More)',
      artist: 'The Phantom of the Opera cast recording',
      artistMatchTokens: <String>['Phantom of the Opera', 'Original Cast'],
      genres: <String>['Musical Theatre', 'Opera', 'Rock'],
      subgenres: <String>['Rock Opera', 'Soundtrack'],
      description: 'A dramatic musical-theatre finale that draws on operatic and rock-opera intensity.',
    ),
    MusicGenreExample(
      title: 'Fit But You Know It',
      artist: 'The Streets',
      artistMatchTokens: <String>['The Streets'],
      genres: <String>['UK Garage', 'Grime', 'Hip-Hop'],
      subgenres: <String>['British Rap'],
      description: 'A UK rap track with garage and grime-associated rhythmic influences.',
    ),
    MusicGenreExample(
      title: 'Epic',
      artist: 'Faith No More',
      artistMatchTokens: <String>['Faith No More'],
      genres: <String>['Rock', 'Metal', 'Hip-Hop'],
      subgenres: <String>['Funk Metal', 'Rap Rock', 'Classical'],
      description: 'Funk-metal and rap-rock energy with an eclectic, classical-leaning finish.',
    ),
  ];
}

class MusicGenreExample {
  final String title;
  final String artist;
  final List<String> artistMatchTokens;
  final List<String> genres;
  final List<String> subgenres;
  final String description;

  const MusicGenreExample({
    required this.title,
    required this.artist,
    required this.artistMatchTokens,
    required this.genres,
    required this.subgenres,
    required this.description,
  });

  String get genreLabel => MusicGenreSystem.displayLabel(
        genres,
        subgenres: subgenres,
      );

  List<String> get allGenreTags => MusicGenreSystem.allTags(
        genres,
        subgenres: subgenres,
      );
}

class _MusicBlendRule {
  final String label;
  final List<String> components;

  const _MusicBlendRule({required this.label, required this.components});
}
