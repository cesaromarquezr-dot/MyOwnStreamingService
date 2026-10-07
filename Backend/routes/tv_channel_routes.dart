import 'dart:convert';
import 'dart:io';

import '../middleware/authentication.dart';
import '../services/tv_channel_service.dart';

class TvChannelRoutes {
  static const prefix = '/api/v1/tv-channels';

  final AuthenticationMiddleware authentication;
  final TvChannelService service;

  TvChannelRoutes({
    required this.authentication,
    required this.service,
  });

  Future<void> handle(HttpRequest request) async {
    if (request.method == 'OPTIONS') {
      await _json(
        request.response,
        204,
        <String, dynamic>{},
      );
      return;
    }

    if (authentication.authenticate(request) == null) {
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

    // ----------------------------------------------------------
    // CAPABILITIES
    // ----------------------------------------------------------

    if (request.method == 'GET' &&
        request.uri.path == '$prefix/capabilities') {
      await _json(
        request.response,
        200,
        <String, dynamic>{
          'success': true,
          ...service.capabilities(),
        },
      );
      return;
    }

    // ----------------------------------------------------------
    // ACCOUNT-OWNED CHANNEL DEFINITIONS
    // ----------------------------------------------------------

    if (request.method == 'GET' &&
        request.uri.path == '$prefix/definitions') {
      final kids =
          request.uri.queryParameters['kids']?.toLowerCase() == 'true';

      await _json(
        request.response,
        200,
        <String, dynamic>{
          'success': true,
          'channels': service.channelDefinitions(
            kidsProfile: kids,
          ),
        },
      );
      return;
    }

    // ----------------------------------------------------------
    // SEASONAL PROGRAMMING POLICY
    // ----------------------------------------------------------

    if (request.method == 'GET' &&
        request.uri.path == '$prefix/seasonal-policy') {
      final kids =
          request.uri.queryParameters['kids']?.toLowerCase() == 'true';

      await _json(
        request.response,
        200,
        <String, dynamic>{
          'success': true,
          'policy': service.seasonalPolicy(
            kidsProfile: kids,
          ),
        },
      );
      return;
    }

    // ----------------------------------------------------------
    // CONTENT INTELLIGENCE
    // ----------------------------------------------------------

    if (request.method == 'POST' &&
        request.uri.path == '$prefix/classify') {
      try {
        final body = await _body(request);

        await _json(
          request.response,
          200,
          <String, dynamic>{
            'success': true,
            'intelligence': service.classify(body),
          },
        );
      } on FormatException catch (error) {
        await _json(
          request.response,
          400,
          <String, dynamic>{
            'success': false,
            'error': error.message,
          },
        );
      } catch (_) {
        await _json(
          request.response,
          500,
          <String, dynamic>{
            'success': false,
            'error': 'Unable to classify content.',
          },
        );
      }

      return;
    }

    // ----------------------------------------------------------
    // ROUTE NOT FOUND
    // ----------------------------------------------------------

    await _json(
      request.response,
      404,
      <String, dynamic>{
        'success': false,
        'error': 'TV channel route not found.',
        'path': request.uri.path,
      },
    );
  }

  Future<Map<String, dynamic>> _body(
    HttpRequest request,
  ) async {
    final raw = await utf8.decoder.bind(request).join();

    if (raw.trim().isEmpty) {
      throw const FormatException(
        'Request body is required.',
      );
    }

    final decoded = jsonDecode(raw);

    if (decoded is! Map) {
      throw const FormatException(
        'Invalid JSON body.',
      );
    }

    return Map<String, dynamic>.from(decoded);
  }

  Future<void> _json(
    HttpResponse response,
    int status,
    Map<String, dynamic> body,
  ) async {
    response.statusCode = status;
    response.headers.contentType = ContentType.json;

    response.headers.set(
      'Cache-Control',
      'no-store',
    );

    response.write(
      jsonEncode(body),
    );

    await response.close();
  }
}