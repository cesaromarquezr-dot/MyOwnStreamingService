// FILE: Backend/services/media_metadata_service.dart
// Purpose: Server-side proxy for approved TMDB metadata endpoints. The TMDB
// credentials remain in the backend environment and are never returned to Flutter.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

class MediaMetadataUpstreamException implements Exception {
  const MediaMetadataUpstreamException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'MediaMetadataUpstreamException($statusCode): $message';
}

class MediaMetadataService {
  MediaMetadataService({
    required this.tmdbApiKey,
    required this.tmdbApiToken,
    this.omdbApiKey = '',
  }) : _client = HttpClient() {
    _client.connectionTimeout = const Duration(seconds: 8);
    _client.idleTimeout = const Duration(seconds: 20);
  }

  final String tmdbApiKey;
  final String tmdbApiToken;
  final String omdbApiKey;
  final HttpClient _client;

  static const Set<String> _allowedQueryParameters = <String>{
    'language',
    'query',
    'include_adult',
    'page',
    'year',
    'first_air_date_year',
    'append_to_response',
    'include_image_language',
    'with_companies',
    'primary_release_date.gte',
    'primary_release_date.lte',
    'first_air_date.gte',
    'first_air_date.lte',
    'sort_by',
    'vote_count.gte',
    'vote_count.lte',
    'vote_average.gte',
    'vote_average.lte',
    'with_genres',
    'with_keywords',
    'with_original_language',
    'origin_country',
    'region',
    'include_video',
    'include_null_first_air_dates',
    'with_watch_providers',
    'with_watch_monetization_types',
    'watch_region',
    'certification_country',
    'certification',
    'with_release_type',
    'release_date.gte',
    'release_date.lte',
  };

  bool get tmdbConfigured =>
      tmdbApiToken.trim().isNotEmpty || tmdbApiKey.trim().isNotEmpty;

  Map<String, dynamic> providerStatus() => <String, dynamic>{
        'tmdb': <String, dynamic>{
          'configured': tmdbConfigured,
          'purpose':
              'Movie, TV, person, cast/crew, biography, poster, and backdrop metadata',
        },
        'omdb': <String, dynamic>{
          'configured': omdbApiKey.trim().isNotEmpty,
          'purpose':
              'Optional IMDb, Rotten Tomatoes, and Metascore values when supplied by OMDb',
        },
      };

  /// Proxies only a small allow-list of TMDB paths used by this application.
  /// This is deliberately not an unrestricted URL/proxy endpoint.
  Future<Map<String, dynamic>> getTmdb({
    required String path,
    Map<String, String> query = const <String, String>{},
  }) async {
    if (!tmdbConfigured) {
      throw const FormatException(
        'TMDB is not configured on the backend. Add TMDB_API_KEY or TMDB_API_TOKEN to Backend/.env.',
      );
    }

    final safePath = _validatedPath(path);
    final parameters = <String, String>{'language': 'en-US'};
    for (final entry in query.entries) {
      if (!_allowedQueryParameters.contains(entry.key)) {
        throw FormatException('Unsupported TMDB query parameter: ${entry.key}');
      }
      final value = entry.value.trim();
      if (value.length > 500 || value.contains('\u0000')) {
        throw const FormatException(
            'TMDB query parameter is too long or invalid.');
      }
      if (value.isNotEmpty) parameters[entry.key] = value;
    }

    if (tmdbApiToken.trim().isEmpty) {
      parameters['api_key'] = tmdbApiKey.trim();
    }

    final uri = Uri.https('api.themoviedb.org', '/3$safePath', parameters);
    try {
      final request =
          await _client.getUrl(uri).timeout(const Duration(seconds: 10));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (tmdbApiToken.trim().isNotEmpty) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer ${tmdbApiToken.trim()}',
        );
      }
      final response =
          await request.close().timeout(const Duration(seconds: 15));
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 15));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw MediaMetadataUpstreamException(
          response.statusCode,
          'TMDB returned HTTP ${response.statusCode}.',
        );
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        throw const FormatException(
            'TMDB returned an unexpected response format.');
      }
      return Map<String, dynamic>.from(decoded);
    } on TimeoutException {
      throw const MediaMetadataUpstreamException(
        HttpStatus.gatewayTimeout,
        'TMDB request timed out.',
      );
    }
  }

  /// Gets optional third-party ratings from OMDb, using only a TMDB-supplied
  /// IMDb ID. The API key never leaves the backend. When OMDb is not configured,
  /// the response tells the client to display that ratings are unavailable.
  Future<Map<String, dynamic>> getOmdbRatings({
    required String imdbId,
  }) async {
    final cleanId = imdbId.trim();
    if (!RegExp(r'^tt[0-9]{5,12}$').hasMatch(cleanId)) {
      throw const FormatException('A valid IMDb title ID is required.');
    }
    if (omdbApiKey.trim().isEmpty) {
      return <String, dynamic>{
        'configured': false,
        'available': false,
        'imdbId': cleanId,
        'ratings': <dynamic>[],
      };
    }

    final uri = Uri.https('www.omdbapi.com', '/', <String, String>{
      'apikey': omdbApiKey.trim(),
      'i': cleanId,
      'plot': 'short',
    });
    try {
      final request =
          await _client.getUrl(uri).timeout(const Duration(seconds: 8));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response =
          await request.close().timeout(const Duration(seconds: 12));
      final body = await response.transform(utf8.decoder).join().timeout(
            const Duration(seconds: 12),
          );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw MediaMetadataUpstreamException(
          response.statusCode,
          'OMDb returned HTTP ${response.statusCode}.',
        );
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        throw const FormatException(
            'OMDb returned an unexpected response format.');
      }
      final json = Map<String, dynamic>.from(decoded);
      final rawRatings = json['Ratings'];
      final ratings = rawRatings is List
          ? rawRatings
              .whereType<Map>()
              .map((item) => <String, dynamic>{
                    'source': item['Source']?.toString() ?? '',
                    'value': item['Value']?.toString() ?? '',
                  })
              .toList(growable: false)
          : <Map<String, dynamic>>[];
      final success = json['Response']?.toString().toLowerCase() == 'true';
      return <String, dynamic>{
        'configured': true,
        'available': success,
        'imdbId': cleanId,
        'title': json['Title']?.toString(),
        'year': json['Year']?.toString(),
        'imdbRating': json['imdbRating']?.toString(),
        'imdbVotes': json['imdbVotes']?.toString(),
        'metascore': json['Metascore']?.toString(),
        'ratings': ratings,
        if (!success)
          'message':
              json['Error']?.toString() ?? 'No external ratings are available.',
      };
    } on TimeoutException {
      throw const MediaMetadataUpstreamException(
        HttpStatus.gatewayTimeout,
        'OMDb request timed out.',
      );
    }
  }

  String _validatedPath(String input) {
    final path = input.trim().replaceFirst(RegExp(r'^/+'), '');
    if (path.isEmpty || path.length > 180 || path.contains('..')) {
      throw const FormatException('Invalid TMDB resource path.');
    }
    final allowed =
        RegExp(r'^search/(movie|tv|person|keyword)$').hasMatch(path) ||
            RegExp(r'^discover/(movie|tv)$').hasMatch(path) ||
            RegExp(
              r'^(movie|tv)/[1-9][0-9]*(/(recommendations|images|credits|videos|keywords|reviews))?$',
            ).hasMatch(path) ||
            RegExp(r'^person/[1-9][0-9]*(/combined_credits)?$').hasMatch(path);
    if (!allowed) {
      throw const FormatException(
          'This TMDB resource is not enabled by the backend.');
    }
    return '/$path';
  }
}
