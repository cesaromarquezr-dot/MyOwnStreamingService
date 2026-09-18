// FILE: `Backend/routes/rating_routes.dart`.
// Purpose: Exposes authenticated rating retrieval and profile-rating endpoints.

import 'dart:convert';
import 'dart:io';

import '../middleware/authentication.dart';
import '../services/rating_service.dart';

class RatingRoutes {
  final AuthenticationMiddleware authentication;
  final RatingService service;

  RatingRoutes({required this.authentication, required this.service});

  /// Handles all rating API endpoints.
  Future<void> handle(HttpRequest request) async {
    try {
      final account = authentication.authenticate(request);
      if (account == null) return _json(request.response, 401, {'success': false, 'error': 'Authentication required.'});

      final path = request.uri.path;
      if (request.method == 'GET' && path == '/api/v1/ratings') {
        final q = request.uri.queryParameters;
        final mediaId = q['mediaId']?.trim() ?? '';
        if (mediaId.isEmpty) return _json(request.response, 400, {'success': false, 'error': 'mediaId is required.'});
        final ratings = await service.getRatings(mediaId: mediaId, title: q['title'], year: int.tryParse(q['year'] ?? ''), mediaType: q['mediaType'] ?? 'movie', tmdbId: q['tmdbId'], musicBrainzId: q['musicBrainzId'], refresh: q['refresh'] == 'true');
        final profileId = q['profileId']?.trim() ?? '';
        final user = profileId.isEmpty ? null : service.getUserRating(accountId: account.id, profileId: profileId, mediaId: mediaId);
        return _json(request.response, 200, {'success': true, 'ratings': ratings.ratings.map((r) => r.toJson()).toList(), 'userRating': user?.toJson()});
      }

      if (request.method == 'POST' && path == '/api/v1/ratings/user') {
        final body = await _body(request);
        final profileId = body['profileId']?.toString() ?? '';
        if (!account.profiles.any((profile) => profile.id == profileId)) return _json(request.response, 400, {'success': false, 'error': 'Profile not found.'});
        final rating = await service.saveUserRating(accountId: account.id, profileId: profileId, mediaId: body['mediaId']?.toString() ?? '', stars: _double(body['stars']) ?? 0);
        return _json(request.response, 201, {'success': true, 'rating': rating.toJson()});
      }

      return _json(request.response, 404, {'success': false, 'error': 'Rating route not found.'});
    } catch (error) {
      return _json(request.response, 400, {'success': false, 'error': error.toString().replaceFirst('Exception: ', '')});
    }
  }

  Future<Map<String, dynamic>> _body(HttpRequest request) async {
    final text = await utf8.decoder.bind(request).join();
    if (text.trim().isEmpty) return {};
    final value = jsonDecode(text);
    if (value is! Map) throw Exception('Request body must be a JSON object.');
    return Map<String, dynamic>.from(value);
  }

  double? _double(dynamic value) => value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');

  Future<void> _json(HttpResponse response, int status, Map<String, dynamic> body) async {
    response.statusCode = status;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    await response.close();
  }
}
