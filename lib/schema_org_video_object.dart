import 'app_core.dart';

/// Builds Schema.org VideoObject JSON-LD for trusted web/API surfaces.
/// A Flutter client cannot itself make a title discoverable to web crawlers;
/// expose this payload from the server-rendered title page or catalog API.
class SchemaOrgVideoObject {
  SchemaOrgVideoObject._();

  static Map<String, dynamic> fromMedia(
    MediaItem media, {
    String? pageUrl,
    String? contentRating,
    String? datePublished,
  }) {
    final isSeries = media.isSeries;
    final published = datePublished ??
        (media.releaseDate ?? media.seriesStartDate)?.toIso8601String();
    final runtime = media.runtimeMinutes;
    final duration = runtime == null || runtime <= 0
        ? null
        : 'PT${runtime}M';
    final result = <String, dynamic>{
      '@context': 'https://schema.org',
      '@type': 'VideoObject',
      'name': media.title,
      'description': media.description,
      'thumbnailUrl': media.imageUrl == null ? null : <String>[media.imageUrl!],
      'datePublished': published,
      'duration': duration,
      'genre': media.genres.isEmpty ? null : media.genres,
      'inLanguage': media.originalLanguage ?? media.language,
      'contentRating': contentRating,
      'url': pageUrl,
      'identifier': media.id,
      'director': media.directors.isEmpty
          ? null
          : media.directors.map((name) => <String, String>{
                '@type': 'Person',
                'name': name,
              }).toList(growable: false),
      'actor': media.actors.isEmpty
          ? null
          : media.actors.map((name) => <String, String>{
                '@type': 'Person',
                'name': name,
              }).toList(growable: false),
      'isFamilyFriendly': contentRating == null
          ? null
          : <String>{'G', 'TV-G', 'TV-Y', 'TV-Y7'}.contains(contentRating),
      'additionalProperty': <Map<String, String>>[
        <String, String>{
          '@type': 'PropertyValue',
          'name': 'mediaType',
          'value': isSeries ? 'TVSeries' : media.type,
        },
        if (media.themes.isNotEmpty)
          <String, String>{
            '@type': 'PropertyValue',
            'name': 'themes',
            'value': media.themes.join(', '),
          },
        if (media.tones.isNotEmpty)
          <String, String>{
            '@type': 'PropertyValue',
            'name': 'moods',
            'value': media.tones.join(', '),
          },
      ],
    }..removeWhere((key, value) => value == null);
    return result;
  }
}
