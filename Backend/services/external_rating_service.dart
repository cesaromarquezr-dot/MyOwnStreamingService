// FILE: Backend/services/external_rating_service.dart
// Purpose: Provider-backed external ratings. Secrets stay on the backend.
//
// Direct provider licensing/terms are required before production use. The
// service is adapter-based so a provider can be enabled without changing the
// rating domain or Flutter clients.

import 'dart:convert';
import 'dart:io';

import '../config.dart';
import '../models/rating.dart';

class ExternalRatingService {
  final Map<String, List<ExternalRating>> _cache = <String, List<ExternalRating>>{};

  Future<List<ExternalRating>> getRatings({
    required String title,
    int? year,
    String? imdbId,
    String mediaType = 'movie',
    bool refresh = false,
  }) async {
    final key = '${mediaType.toLowerCase()}:${imdbId ?? title}:$year';
    if (!refresh && _cache.containsKey(key)) return List.unmodifiable(_cache[key]!);

    final ratings = <ExternalRating>[];
    ratings.addAll(await _tmdb(title: title, year: year, mediaType: mediaType));
    ratings.addAll(await _omdb(title: title, year: year, imdbId: imdbId, mediaType: mediaType));

    // Deduplicate by provider/kind while preserving the most recently fetched value.
    final deduped = <String, ExternalRating>{};
    for (final rating in ratings) {
      deduped['${rating.provider.name}:${rating.kind.name}'] = rating;
    }
    final result = deduped.values.toList(growable: false);
    _cache[key] = result;
    return result;
  }

  Future<List<ExternalRating>> _tmdb({
    required String title,
    required int? year,
    required String mediaType,
  }) async {
    final token = AppConfig.tmdbApiToken;
    if (token.isEmpty) return const [];

    final type = mediaType.toLowerCase() == 'tv' || mediaType.toLowerCase().contains('show')
        ? 'tv'
        : 'movie';
    final uri = Uri.https('api.themoviedb.org', '/3/search/$type', {
      'query': title,
      if (year != null) type == 'movie' ? 'year' : 'first_air_date_year': '$year',
    });

    try {
      final response = await _get(uri, bearer: token);
      if (response == null) return const [];
      final json = response;
      if (json is! Map || json['results'] is! List || (json['results'] as List).isEmpty) return const [];
      final first = (json['results'] as List).first;
      if (first is! Map) return const [];
      final value = (first['vote_average'] as num?)?.toDouble();
      final votes = (first['vote_count'] as num?)?.toInt();
      if (value == null) return const [];
      return [ExternalRating(
        provider: RatingProvider.tmdb,
        kind: RatingKind.community,
        value: value,
        scale: 10,
        voteCount: votes,
        updatedAt: DateTime.now().toUtc(),
        url: 'https://www.themoviedb.org/',
      )];
    } catch (_) {
      return const [];
    }
  }

  Future<List<ExternalRating>> _omdb({
    required String title,
    required int? year,
    required String? imdbId,
    required String mediaType,
  }) async {
    final key = AppConfig.omdbApiKey;
    if (key.isEmpty) return const [];

    final uri = Uri.https('www.omdbapi.com', '/', {
      'apikey': key,
      if (imdbId != null && imdbId.isNotEmpty) 'i': imdbId,
      if (imdbId == null || imdbId.isEmpty) 't': title,
      if (year != null) 'y': '$year',
      'type': mediaType.toLowerCase().contains('tv') || mediaType.toLowerCase().contains('show') ? 'series' : 'movie',
    });

    try {
      final response = await _get(uri);
      if (response == null) return const [];
      final json = response;
      if (json is! Map || json['Response']?.toString() == 'False') return const [];
      final list = json['Ratings'];
      if (list is! List) return const [];

      final output = <ExternalRating>[];
      for (final entry in list) {
        if (entry is! Map) continue;
        final source = entry['Source']?.toString() ?? '';
        final value = entry['Value']?.toString() ?? '';
        if (source == 'Internet Movie Database') {
          final score = double.tryParse(value.split('/').first);
          if (score != null) output.add(_rating(RatingProvider.imdb, score, 10));
        } else if (source == 'Rotten Tomatoes') {
          final score = double.tryParse(value.replaceAll('%', ''));
          if (score != null) output.add(_rating(RatingProvider.rottenTomatoes, score, 100, kind: RatingKind.critic));
        } else if (source == 'Metacritic') {
          final score = double.tryParse(value.split('/').first);
          if (score != null) output.add(_rating(RatingProvider.metacritic, score, 100, kind: RatingKind.critic));
        }
      }
      return output;
    } catch (_) {
      return const [];
    }
  }

  ExternalRating _rating(RatingProvider provider, double value, double scale, {RatingKind kind = RatingKind.community}) =>
      ExternalRating(provider: provider, kind: kind, value: value, scale: scale, updatedAt: DateTime.now().toUtc());

  Future<Map<String, dynamic>?> _get(Uri uri, {String? bearer}) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (bearer != null && bearer.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $bearer');
      }
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
