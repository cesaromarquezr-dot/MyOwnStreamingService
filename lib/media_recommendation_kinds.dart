import 'app_core.dart';

/// Canonical presentation buckets for mixed-media recommendation shelves.
///
/// A recommendation can be a film, a TV show, or a music album. Keeping this
/// classification in one place prevents album records from being presented as
/// movies just because both are stored as MediaItem objects.
enum RecommendationMediaKind { film, tvShow, musicAlbum, other }

abstract final class RecommendationMediaKinds {
  static RecommendationMediaKind classify(MediaItem media) {
    final type = media.type
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');

    if (type.contains('album') || type == 'soundtrack') {
      return RecommendationMediaKind.musicAlbum;
    }
    if (media.isSeries ||
        type == 'tv' ||
        type == 'show' ||
        type == 'television' ||
        type == 'tv show' ||
        type == 'tvshow' ||
        type.contains('series')) {
      return RecommendationMediaKind.tvShow;
    }
    if (type == 'movie' ||
        type == 'film' ||
        type == 'feature' ||
        type.contains('movie') ||
        type.contains('film') ||
        type.contains('documentary')) {
      return RecommendationMediaKind.film;
    }
    return RecommendationMediaKind.other;
  }

  static String label(RecommendationMediaKind kind) {
    switch (kind) {
      case RecommendationMediaKind.film:
        return 'Film';
      case RecommendationMediaKind.tvShow:
        return 'TV Show';
      case RecommendationMediaKind.musicAlbum:
        return 'Music Album';
      case RecommendationMediaKind.other:
        return 'Other';
    }
  }

  static String pluralLabel(RecommendationMediaKind kind) {
    switch (kind) {
      case RecommendationMediaKind.film:
        return 'Films';
      case RecommendationMediaKind.tvShow:
        return 'TV Shows';
      case RecommendationMediaKind.musicAlbum:
        return 'Music Albums';
      case RecommendationMediaKind.other:
        return 'Other';
    }
  }

  static const List<RecommendationMediaKind> displayOrder =
      <RecommendationMediaKind>[
    RecommendationMediaKind.film,
    RecommendationMediaKind.tvShow,
    RecommendationMediaKind.musicAlbum,
    RecommendationMediaKind.other,
  ];

  static Map<RecommendationMediaKind, List<MediaItem>> group(
    Iterable<MediaItem> media, {
    bool includeOther = false,
  }) {
    final result = <RecommendationMediaKind, List<MediaItem>>{};
    for (final item in media) {
      final kind = classify(item);
      if (!includeOther && kind == RecommendationMediaKind.other) continue;
      result.putIfAbsent(kind, () => <MediaItem>[]).add(item);
    }
    return result;
  }
}
