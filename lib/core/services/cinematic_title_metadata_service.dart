import 'dart:convert';

import 'package:http/http.dart' as http;

/// Live title metadata and credits from TMDB.
///
/// The API key is supplied at build/run time, not committed to the repository:
/// --dart-define=TMDB_API_KEY=your_key
class CinematicTitleMetadataService {
  CinematicTitleMetadataService._();

  static const String _apiKey = String.fromEnvironment('TMDB_API_KEY');
  static const String _baseUrl = 'https://api.themoviedb.org/3';
  static bool get isConfigured => _apiKey.trim().isNotEmpty;

  static Future<CinematicTitleMetadata?> lookupTitle({
    required String title,
    required bool isTv,
    int? year,
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty || !isConfigured) return null;

    final searchPath = isTv ? '/search/tv' : '/search/movie';
    final query = <String, String>{
      'query': cleanTitle,
      'include_adult': 'false',
      'page': '1',
      'language': 'en-US',
      if (year != null)
        (isTv ? 'first_air_date_year' : 'year'): year.toString(),
    };
    var search = await _get(searchPath, query);
    var results = search['results'];
    var exactMatch = _findExactMatch(results, cleanTitle, isTv);

    // A year hint can be stale or missing. Retry without it, but still require
    // an exact normalized title match to avoid showing the wrong person's work.
    if (exactMatch == null && year != null) {
      search = await _get(searchPath, <String, String>{
        'query': cleanTitle,
        'include_adult': 'false',
        'page': '1',
        'language': 'en-US',
      });
      results = search['results'];
      exactMatch = _findExactMatch(results, cleanTitle, isTv);
    }
    if (exactMatch == null) return null;

    final id = _toInt(exactMatch['id']);
    if (id == null) return null;
    final detailsPath = isTv ? '/tv/$id' : '/movie/$id';
    final details = await _get(detailsPath, <String, String>{
      'append_to_response': 'credits',
      'language': 'en-US',
    });
    final credits = details['credits'] is Map
        ? Map<String, dynamic>.from(details['credits'] as Map)
        : <String, dynamic>{};
    final castRows = credits['cast'] is List
        ? (credits['cast'] as List).whereType<Map>()
        : const <Map>[];
    final crewRows = credits['crew'] is List
        ? (credits['crew'] as List).whereType<Map>()
        : const <Map>[];

    final cast = <String>[];
    final characters = <String>[];
    for (final row in castRows.take(20)) {
      final name = row['name']?.toString().trim() ?? '';
      final character = row['character']?.toString().trim() ?? '';
      if (name.isNotEmpty && !cast.contains(name)) cast.add(name);
      if (character.isNotEmpty && !characters.contains(character)) {
        characters.add(character);
      }
    }

    final directors = <String>[];
    final writers = <String>[];
    final music = <String>[];
    for (final row in crewRows) {
      final name = row['name']?.toString().trim() ?? '';
      final job = row['job']?.toString().trim().toLowerCase() ?? '';
      if (name.isEmpty) continue;
      if (job == 'director' || job == 'series director') {
        if (!directors.contains(name)) directors.add(name);
      }
      if (const <String>{
        'writer',
        'screenplay',
        'story',
        'teleplay',
        'adaptation',
      }.contains(job)) {
        if (!writers.contains(name)) writers.add(name);
      }
      if (job.contains('music') || job == 'composer') {
        if (!music.contains(name)) music.add(name);
      }
    }

    final actualTitle = (isTv
            ? details['name'] ?? details['original_name']
            : details['title'] ?? details['original_title'])
        ?.toString()
        .trim();
    final releaseDate = (isTv
            ? details['first_air_date']
            : details['release_date'])
        ?.toString();
    return CinematicTitleMetadata(
      providerId: id,
      title: actualTitle?.isNotEmpty == true ? actualTitle! : cleanTitle,
      isTv: isTv,
      overview: details['overview']?.toString() ?? '',
      posterPath: details['poster_path']?.toString(),
      releaseDate: releaseDate?.isNotEmpty == true ? releaseDate : null,
      cast: cast,
      characters: characters,
      directors: directors,
      writers: writers,
      music: music,
    );
  }

  static Map<String, dynamic>? _findExactMatch(
    dynamic rawResults,
    String requestedTitle,
    bool isTv,
  ) {
    if (rawResults is! List) return null;
    final requested = _normalize(requestedTitle);
    for (final candidate in rawResults.whereType<Map>()) {
      final map = Map<String, dynamic>.from(candidate);
      final possibleTitles = isTv
          ? <dynamic>[map['name'], map['original_name']]
          : <dynamic>[map['title'], map['original_title']];
      if (possibleTitles.any((value) =>
          value != null && _normalize(value.toString()) == requested)) {
        return map;
      }
      // TMDB's official title punctuation can vary (e.g. Thunderbolts*); the
      // normalizer intentionally treats punctuation as non-semantic.
    }
    return null;
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]'), '');

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  static Future<Map<String, dynamic>> _get(
    String path, [
    Map<String, String>? query,
  ]) async {
    final params = <String, String>{
      'api_key': _apiKey,
      'language': 'en-US',
      ...?query,
    };
    final response = await http
        .get(Uri.parse('$_baseUrl$path').replace(queryParameters: params))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('TMDB returned HTTP ${response.statusCode}.');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('TMDB returned an unexpected response.');
    }
    return Map<String, dynamic>.from(decoded);
  }
}

class CinematicTitleMetadata {
  const CinematicTitleMetadata({
    required this.providerId,
    required this.title,
    required this.isTv,
    required this.overview,
    required this.posterPath,
    required this.releaseDate,
    required this.cast,
    required this.characters,
    required this.directors,
    required this.writers,
    required this.music,
  });

  final int providerId;
  final String title;
  final bool isTv;
  final String overview;
  final String? posterPath;
  final String? releaseDate;
  final List<String> cast;
  final List<String> characters;
  final List<String> directors;
  final List<String> writers;
  final List<String> music;
}
