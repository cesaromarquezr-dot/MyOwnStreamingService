import 'app_core.dart';

/// One curated browse category. Matching is intentionally metadata-driven:
/// this layer never infers genre from a title or poster.
class HomeBrowseGenre {
  final String id;
  final String label;
  final List<String> aliases;

  const HomeBrowseGenre({
    required this.id,
    required this.label,
    required this.aliases,
  });
}

class HomeBrowseGenreFacet {
  final HomeBrowseGenre genre;
  final int count;

  const HomeBrowseGenreFacet({required this.genre, required this.count});
}

/// Shared genre taxonomy for Home's Focus Browse bar and its genre shelves.
/// Synonyms accommodate common metadata-provider spellings.
class HomeBrowseGenreCatalog {
  const HomeBrowseGenreCatalog._();

  static const List<HomeBrowseGenre> genres = <HomeBrowseGenre>[
    HomeBrowseGenre(
      id: 'action',
      label: 'Action',
      aliases: <String>['action'],
    ),
    HomeBrowseGenre(
      id: 'comedy',
      label: 'Comedy',
      aliases: <String>['comedy', 'comedies'],
    ),
    HomeBrowseGenre(
      id: 'drama',
      label: 'Drama',
      aliases: <String>['drama'],
    ),
    HomeBrowseGenre(
      id: 'thriller',
      label: 'Thriller',
      aliases: <String>['thriller', 'suspense'],
    ),
    HomeBrowseGenre(
      id: 'scifi-fantasy',
      label: 'Sci-Fi & Fantasy',
      aliases: <String>[
        'science fiction',
        'sci-fi',
        'scifi',
        'fantasy',
        'space opera',
      ],
    ),
    HomeBrowseGenre(
      id: 'horror',
      label: 'Horror',
      aliases: <String>['horror', 'supernatural horror'],
    ),
    HomeBrowseGenre(
      id: 'family-animation',
      label: 'Family & Animation',
      aliases: <String>[
        'family',
        'animation',
        'animated',
        'children',
        'kids',
      ],
    ),
    HomeBrowseGenre(
      id: 'crime-mystery',
      label: 'Crime & Mystery',
      aliases: <String>['crime', 'mystery', 'detective', 'police'],
    ),
    HomeBrowseGenre(
      id: 'romance',
      label: 'Romance',
      aliases: <String>['romance', 'romantic'],
    ),
    HomeBrowseGenre(
      id: 'documentary',
      label: 'Documentaries',
      aliases: <String>['documentary', 'docuseries', 'docu-series'],
    ),
    HomeBrowseGenre(
      id: 'adventure',
      label: 'Adventure',
      aliases: <String>['adventure'],
    ),
    HomeBrowseGenre(
      id: 'reality-competition',
      label: 'Reality & Competition',
      aliases: <String>[
        'reality',
        'competition',
        'game show',
        'talent show',
      ],
    ),
    HomeBrowseGenre(
      id: 'music-concerts',
      label: 'Music & Concerts',
      aliases: <String>[
        'music',
        'concert',
        'concert film',
        'live performance',
      ],
    ),
  ];

  static HomeBrowseGenre? byId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final genre in genres) {
      if (genre.id == id) return genre;
    }
    return null;
  }

  static bool matches(MediaItem media, String genreId) {
    final genre = byId(genreId);
    if (genre == null) return false;
    if (genreId == 'music-concerts' && _isMusicMedia(media.type)) {
      return true;
    }
    final metadata = <String>[
      ...media.genres,
      if (media.primaryGenre?.trim().isNotEmpty == true) media.primaryGenre!,
      ...media.tags,
      ...media.themes,
      ...media.tones,
    ];
    return metadata.any((value) => _matchesAnyAlias(value, genre.aliases));
  }

  static List<MediaItem> filter(
    Iterable<MediaItem> source,
    String? genreId,
  ) {
    if (genreId == null || genreId.isEmpty) {
      return source.toList(growable: false);
    }
    return source
        .where((media) => matches(media, genreId))
        .toList(growable: false);
  }

  static List<HomeBrowseGenreFacet> facets(Iterable<MediaItem> source) {
    final items = source.toList(growable: false);
    final result = <HomeBrowseGenreFacet>[];
    for (final genre in genres) {
      final count = items.where((media) => matches(media, genre.id)).length;
      if (count > 0) {
        result.add(HomeBrowseGenreFacet(genre: genre, count: count));
      }
    }
    result.sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      return byCount != 0
          ? byCount
          : a.genre.label.toLowerCase().compareTo(b.genre.label.toLowerCase());
    });
    return result;
  }

  static bool _isMusicMedia(String type) {
    final normalized = type
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
    return normalized == 'album' ||
        normalized == 'music album' ||
        normalized == 'record' ||
        normalized == 'soundtrack album' ||
        normalized == 'music' ||
        normalized == 'song' ||
        normalized == 'track';
  }

  static bool _matchesAnyAlias(String value, List<String> aliases) {
    final normalized = _normalize(value);
    if (normalized.isEmpty) return false;
    for (final alias in aliases) {
      final candidate = _normalize(alias);
      if (candidate.isEmpty) continue;
      // Phrase boundaries avoid accidental matches such as the letters
      // 'action' appearing at the end of an unrelated word.
      if (' $normalized '.contains(' $candidate ')) return true;
    }
    return false;
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
