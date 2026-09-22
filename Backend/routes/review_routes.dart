// FILE: Backend/routes/review_routes.dart
//
// HTTP API routes for profile reviews and privacy-safe global reviews.
//
// Review privacy model:
// - Account reviews are visible only to the authenticated account.
// - Global reviews are exposed through Review.toJson(global: true).
// - Profile ownership is always checked against the authenticated account.
// - The route never trusts a client-supplied account ID.
// - Review text, usernames, labels, and media IDs are length-limited.
// - Authentication/security responses are never cached.

import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import '../middleware/authentication.dart';
import '../services/review_service.dart';

class ReviewRoutes {
  final AuthenticationMiddleware authentication;
  final ReviewService service;

  ReviewRoutes({
    required this.authentication,
    required this.service,
  });

  static const String _globalPath = '/api/v1/reviews/global';
  static const String _reviewsPath = '/api/v1/reviews';

  static const int _maxBodyBytes = 64 * 1024;
  static const int _maxMediaIdLength = 256;
  static const int _maxProfileIdLength = 256;
  static const int _maxProfileNameLength = 200;
  static const int _maxGlobalUsernameLength = 200;
  static const int _maxLabelLength = 200;
  static const int _maxReviewTextLength = 5000;

  Future<void> handle(HttpRequest request) async {
    var responseStarted = false;

    try {
      _applyCors(request.response);

      if (request.method == 'OPTIONS') {
        request.response.statusCode = HttpStatus.noContent;
        await request.response.close();
        return;
      }

      final auth = authentication.authenticate(request);

      if (auth == null) {
        responseStarted = true;
        await _json(
          request.response,
          HttpStatus.unauthorized,
          {
            'success': false,
            'error': 'Authentication required.',
          },
        );
        return;
      }

      final path = request.uri.path;

      // -------------------------------------------------------------------
      // GET /api/v1/reviews/global?mediaId=...
      //
      // Returns the privacy-safe representation produced by the review
      // model's global serializer.
      // -------------------------------------------------------------------
      if (request.method == 'GET' && path == _globalPath) {
        final mediaId = _readRequiredQueryValue(
          request.uri.queryParameters['mediaId'],
          field: 'mediaId',
          maxLength: _maxMediaIdLength,
        );

        final reviews = service
            .globalReviews(mediaId)
            .map((review) => review.toJson(global: true))
            .toList(growable: false);

        responseStarted = true;
        await _json(
          request.response,
          HttpStatus.ok,
          {
            'success': true,
            'reviews': reviews,
          },
        );
        return;
      }

      // -------------------------------------------------------------------
      // GET /api/v1/reviews?mediaId=...
      //
      // Account-scoped reviews. The account ID comes from authenticated
      // session state, never from the request.
      // -------------------------------------------------------------------
      if (request.method == 'GET' && path == _reviewsPath) {
        final mediaId = _readRequiredQueryValue(
          request.uri.queryParameters['mediaId'],
          field: 'mediaId',
          maxLength: _maxMediaIdLength,
        );

        final reviews = service
            .accountReviews(auth.id, mediaId)
            .map((review) => review.toJson())
            .toList(growable: false);

        responseStarted = true;
        await _json(
          request.response,
          HttpStatus.ok,
          {
            'success': true,
            'reviews': reviews,
          },
        );
        return;
      }

      // -------------------------------------------------------------------
      // POST /api/v1/reviews
      // -------------------------------------------------------------------
      if (request.method == 'POST' && path == _reviewsPath) {
        final body = await _body(request);

        final profileId = _readRequiredString(
          body['profileId'],
          field: 'profileId',
          maxLength: _maxProfileIdLength,
        );

        final mediaId = _readRequiredString(
          body['mediaId'],
          field: 'mediaId',
          maxLength: _maxMediaIdLength,
        );

        final profile = _findProfile(auth.profiles, profileId);

        if (profile == null) {
          responseStarted = true;
          await _json(
            request.response,
            HttpStatus.badRequest,
            {
              'success': false,
              'error': 'Profile not found.',
            },
          );
          return;
        }

        final score = _readScore(body['score']);

        final label = _readOptionalString(
          body['label'],
          field: 'label',
          maxLength: _maxLabelLength,
        );

        final text = _readOptionalString(
          body['text'],
          field: 'text',
          maxLength: _maxReviewTextLength,
        );

        final globalUsername = _readOptionalString(
          body['globalUsername'],
          field: 'globalUsername',
          maxLength: _maxGlobalUsernameLength,
        );

        final profileName = _readProfileName(profile.name);

        final review = service.create(
          accountId: auth.id,
          profileId: profile.id,
          profileName: profileName,
          mediaId: mediaId,
          score: score,
          label: label,
          text: text,
          globalUsername: globalUsername,
        );

        responseStarted = true;
        await _json(
          request.response,
          HttpStatus.created,
          {
            'success': true,
            'review': review.toJson(),
          },
        );
        return;
      }

      responseStarted = true;
      await _json(
        request.response,
        HttpStatus.notFound,
        {
          'success': false,
          'error': 'Review route not found.',
        },
      );
    } on FormatException catch (error, stackTrace) {
      _logError(
        'Invalid review request',
        error,
        stackTrace,
      );

      if (!responseStarted) {
        await _json(
          request.response,
          HttpStatus.badRequest,
          {
            'success': false,
            'error': error.message,
          },
        );
      }
    } on ArgumentError catch (error, stackTrace) {
      _logError(
        'Invalid review argument',
        error,
        stackTrace,
      );

      if (!responseStarted) {
        await _json(
          request.response,
          HttpStatus.badRequest,
          {
            'success': false,
            'error': _safeArgumentMessage(error),
          },
        );
      }
    } catch (error, stackTrace) {
      _logError(
        'Review route failure',
        error,
        stackTrace,
      );

      if (!responseStarted) {
        await _json(
          request.response,
          HttpStatus.internalServerError,
          {
            'success': false,
            'error': 'Unable to process the review request.',
          },
        );
      }
    }
  }

  // -------------------------------------------------------------------------
  // Request parsing
  // -------------------------------------------------------------------------

  Future<Map<String, dynamic>> _body(HttpRequest request) async {
    final contentLength = request.contentLength;

    if (contentLength > _maxBodyBytes) {
      throw const FormatException('Request body is too large.');
    }

    final bytes = <int>[];
    var total = 0;

    await for (final chunk in request) {
      total += chunk.length;

      if (total > _maxBodyBytes) {
        throw const FormatException('Request body is too large.');
      }

      bytes.addAll(chunk);
    }

    if (bytes.isEmpty) {
      return <String, dynamic>{};
    }

    final raw = utf8.decode(bytes, allowMalformed: false);

    if (raw.trim().isEmpty) {
      return <String, dynamic>{};
    }

    dynamic decoded;

    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const FormatException('Invalid JSON body.');
    }

    if (decoded is! Map) {
      throw const FormatException('JSON object required.');
    }

    return Map<String, dynamic>.from(decoded);
  }

  // -------------------------------------------------------------------------
  // Validation
  // -------------------------------------------------------------------------

  String _readRequiredString(
    dynamic value, {
    required String field,
    required int maxLength,
  }) {
    if (value == null) {
      throw FormatException('$field is required.');
    }

    final text = value.toString().trim();

    if (text.isEmpty) {
      throw FormatException('$field is required.');
    }

    if (text.length > maxLength) {
      throw FormatException('$field is too long.');
    }

    if (text.contains('\u0000')) {
      throw FormatException('$field contains an invalid character.');
    }

    return text;
  }

  String _readRequiredQueryValue(
    String? value, {
    required String field,
    required int maxLength,
  }) {
    return _readRequiredString(
      value,
      field: field,
      maxLength: maxLength,
    );
  }

  String _readOptionalString(
    dynamic value, {
    required String field,
    required int maxLength,
  }) {
    if (value == null) {
      return '';
    }

    final text = value.toString().trim();

    if (text.length > maxLength) {
      throw FormatException('$field is too long.');
    }

    if (text.contains('\u0000')) {
      throw FormatException('$field contains an invalid character.');
    }

    return text;
  }

  String _readProfileName(String value) {
    final name = value.trim();

    if (name.isEmpty) {
      throw const FormatException('Profile name is required.');
    }

    if (name.length > _maxProfileNameLength) {
      throw const FormatException('Profile name is too long.');
    }

    if (name.contains('\u0000')) {
      throw const FormatException(
        'Profile name contains an invalid character.',
      );
    }

    return name;
  }

  double _readScore(dynamic value) {
    if (value == null) {
      throw const FormatException('score is required.');
    }

    final score = value is num
        ? value.toDouble()
        : double.tryParse(value.toString().trim());

    if (score == null || !score.isFinite) {
      throw const FormatException('score must be a valid number.');
    }

    if (score < 0 || score > 5) {
      throw const FormatException('score must be between 0 and 5.');
    }

    return score;
  }

  dynamic _findProfile(
    Iterable<dynamic> profiles,
    String profileId,
  ) {
    for (final profile in profiles) {
      if (profile.id == profileId) {
        return profile;
      }
    }

    return null;
  }

  // -------------------------------------------------------------------------
  // Response helpers
  // -------------------------------------------------------------------------

  void _applyCors(HttpResponse response) {
    response.headers.set(
      'Access-Control-Allow-Origin',
      '*',
    );
    response.headers.set(
      'Access-Control-Allow-Methods',
      'GET, POST, OPTIONS',
    );
    response.headers.set(
      'Access-Control-Allow-Headers',
      'Authorization, Content-Type',
    );
    response.headers.set(
      'Access-Control-Expose-Headers',
      'Content-Type',
    );
    response.headers.set(
      'Cache-Control',
      'no-store, no-cache, must-revalidate',
    );
    response.headers.set(
      'Pragma',
      'no-cache',
    );
    response.headers.set(
      'X-Content-Type-Options',
      'nosniff',
    );
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

  String _safeArgumentMessage(ArgumentError error) {
    final message = error.message?.toString().trim() ?? '';

    if (message.isEmpty) {
      return 'Invalid request.';
    }

    return message;
  }

  void _logError(
    String message,
    Object error,
    StackTrace stackTrace,
  ) {
    developer.log(
      message,
      name: 'ReviewRoutes',
      error: error,
      stackTrace: stackTrace,
    );
  }
}