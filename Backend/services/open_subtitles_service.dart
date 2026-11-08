// FILE: Backend/services/open_subtitles_service.dart
// Purpose: Server-side OpenSubtitles REST API integration for subtitle discovery.
// The API key is kept in the backend environment and is never returned to Flutter.
// This endpoint finds subtitles for a known title/ID. OpenSubtitles does not
// expose a public endpoint that searches the text of every subtitle by quote.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

class OpenSubtitlesUpstreamException implements Exception {
  const OpenSubtitlesUpstreamException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'OpenSubtitlesUpstreamException($statusCode): $message';
}

class OpenSubtitlesService {
  OpenSubtitlesService({
    required this.apiKey,
    required this.userAgent,
  }) : _client = HttpClient() {
    _client.connectionTimeout = const Duration(seconds: 8);
    _client.idleTimeout = const Duration(seconds: 20);
    _client.maxConnectionsPerHost = 4;
  }

  final String apiKey;
  final String userAgent;
  final HttpClient _client;
  static const String _base = 'https://api.opensubtitles.com/api/v1';

  bool get configured => apiKey.trim().isNotEmpty;

  Map<String, dynamic> status() => <String, dynamic>{
        'configured': configured,
        'provider': 'OpenSubtitles',
        'purpose': 'Find available subtitle uploads for a known movie, show, episode, or TMDB ID.',
        'dialogueTextSearch': false,
        'note': 'OpenSubtitles searches subtitle availability by title or external ID; it does not provide a global full-transcript quote-search endpoint.',
      };

  Future<Map<String, dynamic>> search({
    String? query,
    String? tmdbId,
    String type = 'all',
    String languages = 'en,es',
    int? year,
    int limit = 12,
  }) async {
    if (!configured) {
      return <String, dynamic>{
        'success': false,
        'configured': false,
        'provider': 'OpenSubtitles',
        'message': 'Add OPENSUBTITLES_API_KEY to Backend/.env to enable global subtitle discovery.',
        'results': <Map<String, dynamic>>[],
      };
    }

    final cleanQuery = query?.trim().toLowerCase() ?? '';
    final cleanTmdbId = tmdbId?.trim() ?? '';
    if (cleanQuery.isEmpty && cleanTmdbId.isEmpty) {
      throw const FormatException('Provide a title query or TMDB ID.');
    }
    if (cleanQuery.length > 120 || cleanQuery.contains('\u0000')) {
      throw const FormatException('Title query must be 1 to 120 characters.');
    }
    if (cleanTmdbId.isNotEmpty && !RegExp(r'^[1-9][0-9]{0,11}$').hasMatch(cleanTmdbId)) {
      throw const FormatException('TMDB ID must be a positive numeric identifier.');
    }
    if (!const <String>{'all', 'movie', 'episode'}.contains(type)) {
      throw const FormatException('Type must be all, movie, or episode.');
    }
    if (year != null && (year < 1880 || year > 2200 || cleanQuery.isEmpty)) {
      throw const FormatException('A year filter requires a title query and a valid year.');
    }

    final languageCodes = languages
        .split(',')
        .map((value) => value.trim().toLowerCase())
        .where((value) => RegExp(r'^[a-z]{2}(-[a-z]{2})?$').hasMatch(value))
        .toSet()
        .toList()
      ..sort();
    if (languageCodes.isEmpty) {
      throw const FormatException('At least one valid subtitle language is required.');
    }

    final parameters = <String, String>{
      if (cleanQuery.isNotEmpty) 'query': cleanQuery,
      if (cleanTmdbId.isNotEmpty) 'tmdb_id': cleanTmdbId,
      if (type != 'all') 'type': type,
      if (year != null) 'year': year.toString(),
      'languages': languageCodes.join(','),
    };
    final sortedEntries = parameters.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    final uri = Uri.parse('$_base/subtitles').replace(
      queryParameters: <String, String>{
        for (final entry in sortedEntries) entry.key: entry.value,
      },
    );

    try {
      final request = await _client.getUrl(uri).timeout(const Duration(seconds: 10));
      request.followRedirects = true;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set('Api-Key', apiKey.trim());
      request.headers.set(HttpHeaders.userAgentHeader, userAgent.trim().isEmpty ? 'MyOwnStreamingService/1.0' : userAgent.trim());
      final response = await request.close().timeout(const Duration(seconds: 18));
      final body = await response.transform(utf8.decoder).join().timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw OpenSubtitlesUpstreamException(
          response.statusCode,
          'OpenSubtitles returned HTTP ${response.statusCode}.',
        );
      }
      dynamic decoded;
      try {
        decoded = jsonDecode(body);
      } on FormatException {
        throw const OpenSubtitlesUpstreamException(
          HttpStatus.badGateway,
          'OpenSubtitles returned an unreadable response.',
        );
      }
      if (decoded is! Map) {
        throw const FormatException('OpenSubtitles returned an unexpected response.');
      }
      final rawItems = decoded['data'];
      final results = <Map<String, dynamic>>[];
      if (rawItems is List) {
        for (final raw in rawItems.whereType<Map>().take(limit.clamp(1, 20).toInt())) {
          final attributes = raw['attributes'] is Map
              ? Map<String, dynamic>.from(raw['attributes'] as Map)
              : <String, dynamic>{};
          final feature = attributes['feature_details'] is Map
              ? Map<String, dynamic>.from(attributes['feature_details'] as Map)
              : <String, dynamic>{};
          final files = attributes['files'] is List
              ? (attributes['files'] as List).whereType<Map>().toList(growable: false)
              : const <Map>[];
          final firstFile = files.isEmpty ? const <String, dynamic>{} : Map<String, dynamic>.from(files.first);
          results.add(<String, dynamic>{
            'subtitleId': raw['id']?.toString() ?? '',
            'title': (feature['parent_title']?.toString().trim().isNotEmpty == true)
                ? feature['parent_title'].toString()
                : (feature['movie_name']?.toString().trim().isNotEmpty == true
                    ? feature['movie_name'].toString()
                    : feature['title']?.toString() ?? ''),
            'episodeTitle': feature['title']?.toString() ?? '',
            'seasonNumber': feature['season_number'],
            'episodeNumber': feature['episode_number'],
            'year': feature['year'],
            'type': feature['feature_type']?.toString() ?? raw['type']?.toString() ?? '',
            'language': attributes['language']?.toString() ?? '',
            'release': attributes['release']?.toString() ?? '',
            'downloadCount': attributes['download_count'] ?? 0,
            'rating': attributes['ratings'] ?? 0,
            'trustedUploader': attributes['from_trusted'] == true,
            'aiTranslated': attributes['ai_translated'] == true,
            'machineTranslated': attributes['machine_translated'] == true,
            'tmdbId': feature['tmdb_id']?.toString() ?? '',
            'imdbId': feature['imdb_id']?.toString() ?? '',
            'pageUrl': attributes['url']?.toString() ?? '',
            'fileId': firstFile['file_id'],
            'fileName': firstFile['file_name']?.toString() ?? '',
          });
        }
      }
      return <String, dynamic>{
        'success': true,
        'configured': true,
        'provider': 'OpenSubtitles',
        'query': cleanQuery,
        'tmdbId': cleanTmdbId,
        'count': results.length,
        'totalPages': decoded['total_pages'] ?? 0,
        'results': results,
        'message': results.isEmpty
            ? 'No subtitle uploads were found for this title and language selection.'
            : 'Found subtitle uploads for this title. These are availability results, not matches against the remembered dialogue.',
      };
    } on TimeoutException {
      throw const OpenSubtitlesUpstreamException(
        HttpStatus.gatewayTimeout,
        'OpenSubtitles request timed out.',
      );
    } on HandshakeException {
      throw const OpenSubtitlesUpstreamException(
        HttpStatus.badGateway,
        'A secure connection to OpenSubtitles could not be established.',
      );
    } on SocketException {
      throw const OpenSubtitlesUpstreamException(
        HttpStatus.badGateway,
        'OpenSubtitles could not be reached.',
      );
    } on HttpException {
      throw const OpenSubtitlesUpstreamException(
        HttpStatus.badGateway,
        'The OpenSubtitles network request failed.',
      );
    }
  }
}
