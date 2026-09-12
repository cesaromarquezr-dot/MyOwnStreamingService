// HTTP API routes for profile reviews and privacy-safe global reviews.
import 'dart:convert';
import 'dart:io';
import '../middleware/authentication.dart';
import '../services/review_service.dart';

class ReviewRoutes {
  final AuthenticationMiddleware authentication;
  final ReviewService service;
  ReviewRoutes({required this.authentication, required this.service});

  Future<void> handle(HttpRequest request) async {
  try {
    final auth = authentication.authenticate(request);

    if (auth == null) {
      await _json(
        request.response,
        401,
        {'success': false, 'error': 'Authentication required.'},
      );
      return;
    }

    final path = request.uri.path;

    if (request.method == 'GET' &&
        path == '/api/v1/reviews/global') {
      final mediaId = request.uri.queryParameters['mediaId'] ?? '';

      await _json(
        request.response,
        200,
        {
          'success': true,
          'reviews': service
              .globalReviews(mediaId)
              .map((r) => r.toJson(global: true))
              .toList(),
        },
      );
      return;
    }

    if (request.method == 'GET' &&
        path == '/api/v1/reviews') {
      final mediaId = request.uri.queryParameters['mediaId'] ?? '';

      await _json(
        request.response,
        200,
        {
          'success': true,
          'reviews': service
              .accountReviews(auth.id, mediaId)
              .map((r) => r.toJson())
              .toList(),
        },
      );
      return;
    }

    if (request.method == 'POST' &&
        path == '/api/v1/reviews') {
      final body = await _body(request);
      final profileId = body['profileId']?.toString() ?? '';

      final matches =
          auth.profiles.where((p) => p.id == profileId).toList();

      final profile = matches.isEmpty ? null : matches.first;

      if (profile == null) {
        await _json(
          request.response,
          400,
          {'success': false, 'error': 'Profile not found.'},
        );
        return;
      }

      final review = service.create(
        accountId: auth.id,
        profileId: profile.id,
        profileName: profile.name,
        mediaId: body['mediaId']?.toString() ?? '',
        score: (body['score'] as num?)?.toDouble() ??
            double.tryParse(body['score']?.toString() ?? '') ??
            0,
        label: body['label']?.toString() ?? '',
        text: body['text']?.toString() ?? '',
        globalUsername: body['globalUsername']?.toString() ?? '',
      );

      await _json(
        request.response,
        201,
        {
          'success': true,
          'review': review.toJson(),
        },
      );
      return;
    }

    await _json(
      request.response,
      404,
      {'success': false, 'error': 'Review route not found.'},
    );
  } catch (e) {
    await _json(
      request.response,
      400,
      {
        'success': false,
        'error': e.toString().replaceFirst('Exception: ', ''),
      },
    );
  }
}
  Future<Map<String, dynamic>> _body(HttpRequest request) async {
    final raw = await utf8.decoder.bind(request).join();
    if (raw.trim().isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) throw Exception('JSON object required.');
    return Map<String, dynamic>.from(decoded);
  }

  Future<void> _json(HttpResponse response, int code, Map<String, dynamic> body) async {
    response.statusCode = code;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    await response.close();
  }
}
