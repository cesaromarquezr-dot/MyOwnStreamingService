// FILE: `Backend/services/rating_service.dart`.
// Purpose: Retrieves and caches external ratings and stores profile ratings.
// Provider credentials remain server-side; Flutter never receives API keys.

import 'dart:convert';
import 'dart:io';

import '../database/database.dart';
import '../models/rating.dart';
import '../supabase_store.dart';

class RatingService {
  final Database database;
  final Duration timeout;
  final Map<String, MediaRatings> _cache = <String, MediaRatings>{};

  RatingService(this.database, {this.timeout = const Duration(seconds: 10)});

  /// Returns cached ratings. If refresh is requested, configured providers are queried.
  Future<MediaRatings> getRatings({
    required String mediaId,
    String? title,
    int? year,
    String mediaType = 'movie',
    String? tmdbId,
    String? musicBrainzId,
    bool refresh = false,
  }) async {
    if (!refresh && _cache.containsKey(mediaId)) return _cache[mediaId]!;

    final ratings = <ExternalRating>[];
    final tmdb = await _tmdb(title: title, year: year, mediaType: mediaType, tmdbId: tmdbId);
    if (tmdb != null) ratings.add(tmdb);

    final imdb = await _configuredProvider( RatingProvider.imdb, RatingKind.audience, mediaId: mediaId, title: title, year: year);
    if (imdb != null) ratings.add(imdb);

    final rtCritic = await _configuredProvider( RatingProvider.rottenTomatoes, RatingKind.critic, mediaId: mediaId, title: title, year: year);
    if (rtCritic != null) ratings.add(rtCritic);
    final rtAudience = await _configuredProvider( RatingProvider.rottenTomatoes, RatingKind.audience, mediaId: mediaId, title: title, year: year, audience: true);
    if (rtAudience != null) ratings.add(rtAudience);

    final music = await _musicBrainz(musicBrainzId);
    if (music != null) ratings.add(music);

    final result = MediaRatings(mediaId: mediaId, ratings: ratings);
    _cache[mediaId] = result;
    for (final rating in ratings) {
      try {
        await SupabaseStore.instance.upsertExternalRating(mediaId, rating);
      } catch (_) {
        // The in-memory cache remains usable when the optional migration has
        // not yet been applied or Supabase is temporarily unavailable.
      }
    }
    return result;
  }

  /// Saves or replaces a profile's 0.5-5 star rating.
  Future<UserMediaRating> saveUserRating({required String accountId, required String profileId, required String mediaId, required double stars}) async {
    if (stars < 0.5 || stars > 5 || ((stars * 2).roundToDouble() != stars * 2)) {
      throw Exception('User rating must be between 0.5 and 5 stars in 0.5-star increments.');
    }
    final rating = UserMediaRating(mediaId: mediaId, profileId: profileId, stars: stars, updatedAt: DateTime.now());
    database.userMediaRatings['$accountId:$profileId:$mediaId'] = rating;
    try {
      await SupabaseStore.instance.upsertUserMediaRating(rating, accountId);
    } catch (_) {
      // Keep the backend cache usable if the optional migration is unavailable.
    }
    return rating;
  }

  UserMediaRating? getUserRating({required String accountId, required String profileId, required String mediaId}) =>
      database.userMediaRatings['$accountId:$profileId:$mediaId'];

  void clearCache(String mediaId) => _cache.remove(mediaId);

  Future<ExternalRating?> _tmdb({String? title, int? year, required String mediaType, String? tmdbId}) async {
    final key = Platform.environment['TMDB_API_KEY']?.trim();
    if (key == null || key.isEmpty) return null;

    try {
      String? id = tmdbId;
      String endpointType = mediaType.toLowerCase().contains('tv') || mediaType.toLowerCase().contains('show') ? 'tv' : 'movie';
      if (id == null || id.isEmpty) {
        if (title == null || title.trim().isEmpty) return null;
        final searchUri = Uri.https('api.themoviedb.org', '/3/search/$endpointType', {
          'api_key': key,
          'query': title,
          if (year != null) endpointType == 'movie' ? 'year' : 'first_air_date_year': year.toString(),
        });
        final search = await _get(searchUri);
        final results = search['results'];
        if (results is! List || results.isEmpty) return null;
        final first = results.first;
        if (first is! Map) return null;
        id = first['id']?.toString();
      }
      if (id == null || id.isEmpty) return null;
      final details = await _get(Uri.https('api.themoviedb.org', '/3/$endpointType/$id', {'api_key': key}));
      final value = details['vote_average'];
      if (value is! num) return null;
      return ExternalRating(provider: RatingProvider.tmdb, kind: RatingKind.audience, value: value.toDouble(), scale: 10, voteCount: details['vote_count'] is num ? (details['vote_count'] as num).toInt() : null, updatedAt: DateTime.now(), url: 'https://www.themoviedb.org/$endpointType/$id');
    } catch (_) {
      return null;
    }
  }

  Future<ExternalRating?> _musicBrainz(String? mbid) async {
    if (mbid == null || mbid.trim().isEmpty) return null;
    try {
      final json = await _get(Uri.https('musicbrainz.org', '/ws/2/release-group/$mbid', {'fmt': 'json', 'inc': 'ratings'}), userAgent: 'PersonalStreamingService/1.0');
      final rating = json['rating'];
      if (rating is! Map || rating['value'] is! num) return null;
      return ExternalRating(provider: RatingProvider.musicBrainz, kind: RatingKind.community, value: (rating['value'] as num).toDouble(), scale: 5, voteCount: rating['votes-count'] is num ? (rating['votes-count'] as num).toInt() : null, updatedAt: DateTime.now(), url: 'https://musicbrainz.org/release-group/$mbid');
    } catch (_) {
      return null;
    }
  }

  Future<ExternalRating?> _configuredProvider( RatingProvider provider, RatingKind kind, {required String mediaId, String? title, int? year, bool audience = false}) async {
    final prefix = provider == RatingProvider.imdb ? 'IMDB_RATINGS_URL' : audience ? 'ROTTENTOMATOES_AUDIENCE_URL' : 'ROTTENTOMATOES_CRITICS_URL';
    final template = Platform.environment[prefix]?.trim();
    if (template == null || template.isEmpty) return null;
    try {
      final url = template.replaceAll('{mediaId}', Uri.encodeComponent(mediaId)).replaceAll('{title}', Uri.encodeComponent(title ?? '')).replaceAll('{year}', year?.toString() ?? '');
      final json = await _get(Uri.parse(url));
      final value = json['value'] ?? json['score'] ?? json['rating'];
      final scale = json['scale'] ?? (provider == RatingProvider.rottenTomatoes ? 100 : 10);
      if (value is! num || scale is! num) return null;
      return ExternalRating(provider: provider, kind: kind, value: value.toDouble(), scale: scale.toDouble(), voteCount: json['voteCount'] is num ? (json['voteCount'] as num).toInt() : json['reviewCount'] is num ? (json['reviewCount'] as num).toInt() : null, updatedAt: DateTime.now(), url: json['url']?.toString());
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _get(Uri uri, {String? userAgent}) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri).timeout(timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.userAgentHeader, userAgent ?? 'PersonalStreamingService/1.0');
      final response = await request.close().timeout(timeout);
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('HTTP ${response.statusCode}');
      final decoded = jsonDecode(body);
      if (decoded is! Map) throw Exception('Invalid JSON');
      return Map<String, dynamic>.from(decoded);
    } finally {
      client.close();
    }
  }
}
