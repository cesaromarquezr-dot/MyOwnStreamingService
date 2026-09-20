// FILE: `Backend/routes/rating_routes.dart`.
// Purpose: Handles provider-rating reads and private profile ratings.

import 'dart:convert';
import 'dart:io';

import '../middleware/authentication.dart';
import '../services/rating_service.dart';

class RatingRoutes {
  final AuthenticationMiddleware authentication;
  final RatingService service;

  RatingRoutes({
    required this.authentication,
    required this.service,
  });

  Future<void> handle(HttpRequest request) async {
    try {
      final auth = authentication.authenticate(request);
      if (auth == null) {
        await _json(request.response, 401, {
          'success': false,
          'error': 'Authentication required.',
        });
        return;
      }

      if (request.method == 'GET' &&
          request.uri.path == '/api/v1/ratings') {
        final query = request.uri.queryParameters;
        final mediaId = query['mediaId']?.trim() ?? '';
        if (mediaId.isEmpty) {
          await _json(request.response, 400, {
            'success': false,
            'error': 'mediaId is required.',
          });
          return;
        }

        final profileId = query['profileId']?.trim();
        if (profileId != null &&
            profileId.isNotEmpty &&
            auth.profiles.every((profile) => profile.id != profileId)) {
          await _json(request.response, 403, {
            'success': false,
            'error': 'Profile does not belong to this account.',
          });
          return;
        }

        final ratings = service.providerRatings(
          mediaId: mediaId,
          title: query['title'] ?? '',
          year: int.tryParse(query['year'] ?? ''),
          mediaType: query['mediaType'] ?? 'movie',
          tmdbId: query['tmdbId'],
          musicBrainzId: query['musicBrainzId'],
          refresh: query['refresh'] == 'true',
        );

        final user = profileId == null || profileId.isEmpty
            ? null
            : service.userRating(mediaId: mediaId, profileId: profileId);

        await _json(request.response, 200, {
          'success': true,
          'ratings': ratings,
          'userRating': user?.toJson(),
        });
        return;
      }

      if (request.method == 'POST' &&
          request.uri.path == '/api/v1/ratings/user') {
        final body = await _body(request);
        final profileId = body['profileId']?.toString().trim() ?? '';
        if (auth.profiles.every((profile) => profile.id != profileId)) {
          await _json(request.response, 403, {
            'success': false,
            'error': 'Profile does not belong to this account.',
          });
          return;
        }

        final stars = body['stars'] is num
            ? (body['stars'] as num).toDouble()
            : double.tryParse(body['stars']?.toString() ?? '');

        if (stars == null) {
          await _json(request.response, 400, {
            'success': false,
            'error': 'stars is required.',
          });
          return;
        }

        final rating = service.saveUserRating(
          mediaId: body['mediaId']?.toString() ?? '',
          profileId: profileId,
          stars: stars,
        );

        await _json(request.response, 200, {
          'success': true,
          'userRating': rating.toJson(),
        });
        return;
      }

      await _json(request.response, 404, {
        'success': false,
        'error': 'Rating route not found.',
      });
    } catch (error) {
      await _json(request.response, 400, {
        'success': false,
        'error': error.toString().replaceFirst('Exception: ', ''),
      });
    }
  }

  Future<Map<String, dynamic>> _body(HttpRequest request) async {
    final raw = await utf8.decoder.bind(request).join();
    if (raw.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) throw Exception('JSON object required.');
    return Map<String, dynamic>.from(decoded);
  }

  Future<void> _json(
    HttpResponse response,
    int code,
    Map<String, dynamic> body,
  ) async {
    response.statusCode = code;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    await response.close();
  }
}
