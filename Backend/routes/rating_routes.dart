// FILE: `Backend/routes/rating_routes.dart`.
// Purpose: Handles provider-rating reads and private profile ratings.
//
// Provider ratings are external/provider data.
// User ratings are private to the authenticated account/profile.
// Provider scores and personal profile ratings are never combined.

import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import '../middleware/authentication.dart';
import '../services/rating_service.dart';

class RatingRoutes {
  static const String _ratingsPath = '/api/v1/ratings';
  static const String _userRatingsPath = '/api/v1/ratings/user';

  static const int _maxBodyBytes = 64 * 1024;
  static const int _maxMediaIdLength = 256;
  static const int _maxProfileIdLength = 256;
  static const int _maxTitleLength = 500;
  static const int _maxMediaTypeLength = 64;
  static const int _maxProviderIdLength = 256;

  final AuthenticationMiddleware authentication;
  final RatingService service;

  RatingRoutes({
    required this.authentication,
    required this.service,
  });

  Future<void> handle(HttpRequest request) async {
    _applyCors(request.response);

    if (request.method == 'OPTIONS') {
      await _close(request.response, 204);
      return;
    }

    final auth = authentication.authenticate(request);

    if (auth == null) {
      await _json(
        request.response,
        401,
        <String, dynamic>{
          'success': false,
          'error': 'Authentication required.',
        },
      );
      return;
    }

    try {
      if (request.method == 'GET' &&
          request.uri.path == _ratingsPath) {
        await _getRatings(request, auth);
        return;
      }

      if (request.method == 'POST' &&
          request.uri.path == _userRatingsPath) {
        await _saveUserRating(request, auth);
        return;
      }

      await _json(
        request.response,
        404,
        <String, dynamic>{
          'success': false,
          'error': 'Rating route not found.',
        },
      );
    } on FormatException catch (error, stackTrace) {
      developer.log(
        'Invalid rating request.',
        name: 'RatingRoutes',
        error: error,
        stackTrace: stackTrace,
      );

      await _json(
        request.response,
        400,
        <String, dynamic>{
          'success': false,
          'error': 'Invalid rating request.',
        },
      );
    } on _RequestTooLargeException catch (error, stackTrace) {
      developer.log(
        'Rating request body exceeded size limit.',
        name: 'RatingRoutes',
        error: error,
        stackTrace: stackTrace,
      );

      await _json(
        request.response,
        413,
        <String, dynamic>{
          'success': false,
          'error': 'Request body is too large.',
        },
      );
    } catch (error, stackTrace) {
      developer.log(
        'Rating route failed.',
        name: 'RatingRoutes',
        error: error,
        stackTrace: stackTrace,
      );

      await _json(
        request.response,
        500,
        <String, dynamic>{
          'success': false,
          'error': 'Unable to process the rating request.',
        },
      );
    }
  }

  Future<void> _getRatings(
    HttpRequest request,
    dynamic auth,
  ) async {
    final query = request.uri.queryParameters;

    final mediaId = query['mediaId']?.trim() ?? '';

    if (mediaId.isEmpty) {
      await _json(
        request.response,
        400,
        <String, dynamic>{
          'success': false,
          'error': 'mediaId is required.',
        },
      );
      return;
    }

    if (mediaId.length > _maxMediaIdLength) {
      await _json(
        request.response,
        400,
        <String, dynamic>{
          'success': false,
          'error': 'mediaId is too long.',
        },
      );
      return;
    }

    final profileId = query['profileId']?.trim();

    if (profileId != null && profileId.isNotEmpty) {
      if (profileId.length > _maxProfileIdLength ||
          !_profileBelongsToAccount(auth, profileId)) {
        await _json(
          request.response,
          403,
          <String, dynamic>{
            'success': false,
            'error': 'Profile does not belong to this account.',
          },
        );
        return;
      }
    }

    final title = query['title']?.trim() ?? '';

    if (title.length > _maxTitleLength) {
      await _json(
        request.response,
        400,
        <String, dynamic>{
          'success': false,
          'error': 'title is too long.',
        },
      );
      return;
    }

    final mediaType = query['mediaType']?.trim() ?? 'movie';

    if (mediaType.isEmpty || mediaType.length > _maxMediaTypeLength) {
      await _json(
        request.response,
        400,
        <String, dynamic>{
          'success': false,
          'error': 'mediaType is invalid.',
        },
      );
      return;
    }

    final tmdbId = _optionalBoundedValue(
      query['tmdbId'],
      _maxProviderIdLength,
    );

    final musicBrainzId = _optionalBoundedValue(
      query['musicBrainzId'],
      _maxProviderIdLength,
    );

    final refresh = _parseBoolean(query['refresh']);

    final ratings = await service.providerRatings(
      mediaId: mediaId,
      title: title,
      year: _parseYear(query['year']),
      mediaType: mediaType,
      tmdbId: tmdbId,
      musicBrainzId: musicBrainzId,
      refresh: refresh,
    );

    final user = profileId == null || profileId.isEmpty
        ? null
        : service.userRating(
            mediaId: mediaId,
            profileId: profileId,
          );

    await _json(
      request.response,
      200,
      <String, dynamic>{
        'success': true,
        'ratings': ratings,
        'userRating': user?.toJson(),
      },
    );
  }

  Future<void> _saveUserRating(
    HttpRequest request,
    dynamic auth,
  ) async {
    final body = await _body(request);

    final mediaId = body['mediaId']?.toString().trim() ?? '';
    final profileId = body['profileId']?.toString().trim() ?? '';

    if (mediaId.isEmpty) {
      await _json(
        request.response,
        400,
        <String, dynamic>{
          'success': false,
          'error': 'mediaId is required.',
        },
      );
      return;
    }

    if (mediaId.length > _maxMediaIdLength) {
      await _json(
        request.response,
        400,
        <String, dynamic>{
          'success': false,
          'error': 'mediaId is too long.',
        },
      );
      return;
    }

    if (profileId.isEmpty || profileId.length > _maxProfileIdLength) {
      await _json(
        request.response,
        400,
        <String, dynamic>{
          'success': false,
          'error': 'A valid profileId is required.',
        },
      );
      return;
    }

    if (!_profileBelongsToAccount(auth, profileId)) {
      await _json(
        request.response,
        403,
        <String, dynamic>{
          'success': false,
          'error': 'Profile does not belong to this account.',
        },
      );
      return;
    }

    final stars = _parseStars(body['stars']);

    if (stars == null) {
      await _json(
        request.response,
        400,
        <String, dynamic>{
          'success': false,
          'error': 'stars must be between 0.5 and 5.0 in 0.5-star increments.',
        },
      );
      return;
    }

    final rating = await service.saveUserRating(
      mediaId: mediaId,
      profileId: profileId,
      stars: stars,
    );

    await _json(
      request.response,
      200,
      <String, dynamic>{
        'success': true,
        'userRating': rating.toJson(),
      },
    );
  }

  bool _profileBelongsToAccount(
    dynamic auth,
    String profileId,
  ) {
    final profiles = auth.profiles;

    return profiles.any(
      (profile) => profile.id == profileId,
    );
  }

  int? _parseYear(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final year = int.tryParse(value.trim());

    if (year == null || year < 1800 || year > 3000) {
      return null;
    }

    return year;
  }

  double? _parseStars(Object? value) {
    final stars = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString().trim() ?? '');

    if (stars == null || !stars.isFinite) {
      return null;
    }

    if (stars < 0.5 || stars > 5.0) {
      return null;
    }

    final doubled = stars * 2;
    final rounded = doubled.round();

    if ((doubled - rounded).abs() > 0.000001) {
      return null;
    }

    return rounded / 2.0;
  }

  String? _optionalBoundedValue(
    String? value,
    int maxLength,
  ) {
    final normalized = value?.trim();

    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    if (normalized.length > maxLength) {
      return null;
    }

    return normalized;
  }

  bool _parseBoolean(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'true':
      case '1':
      case 'yes':
        return true;
      default:
        return false;
    }
  }

  Future<Map<String, dynamic>> _body(
    HttpRequest request,
  ) async {
    final contentLength = request.contentLength;

    if (contentLength > _maxBodyBytes) {
      throw const _RequestTooLargeException();
    }

    final chunks = <List<int>>[];
    var totalBytes = 0;

    await for (final chunk in request) {
      totalBytes += chunk.length;

      if (totalBytes > _maxBodyBytes) {
        throw const _RequestTooLargeException();
      }

      chunks.add(chunk);
    }

    if (totalBytes == 0) {
      return <String, dynamic>{};
    }

    final bytes = <int>[];

    for (final chunk in chunks) {
      bytes.addAll(chunk);
    }

    final raw = utf8.decode(bytes);

    if (raw.trim().isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(raw);

    if (decoded is! Map) {
      throw const FormatException(
        'JSON object required.',
      );
    }

    return Map<String, dynamic>.from(decoded);
  }

  void _applyCors(HttpResponse response) {
    response.headers
      ..set('Access-Control-Allow-Origin', '*')
      ..set(
        'Access-Control-Allow-Methods',
        'GET, POST, OPTIONS',
      )
      ..set(
        'Access-Control-Allow-Headers',
        'Authorization, Content-Type',
      )
      ..set(
        'Access-Control-Expose-Headers',
        'Content-Type, Content-Length',
      );
  }

  Future<void> _json(
    HttpResponse response,
    int code,
    Map<String, dynamic> body,
  ) async {
    response.statusCode = code;
    response.headers
      ..contentType = ContentType.json
      ..set('Cache-Control', 'no-store, no-cache, must-revalidate')
      ..set('Pragma', 'no-cache')
      ..set('X-Content-Type-Options', 'nosniff');

    response.write(jsonEncode(body));
    await response.close();
  }

  Future<void> _close(
    HttpResponse response,
    int code,
  ) async {
    response.statusCode = code;
    response.headers
      ..set('Cache-Control', 'no-store')
      ..set('X-Content-Type-Options', 'nosniff');

    await response.close();
  }
}

class _RequestTooLargeException implements Exception {
  const _RequestTooLargeException();
}