// FILE: Backend/routes/media_metadata_routes.dart
// Purpose: Authenticated endpoints for the server-side TMDB metadata proxy.

import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import '../middleware/authentication.dart';
import '../services/media_metadata_service.dart';

class MediaMetadataRoutes {
  MediaMetadataRoutes({
    required this.authentication,
    required this.service,
  });

  final AuthenticationMiddleware authentication;
  final MediaMetadataService service;

  static const String _prefix = '/api/v1/media-metadata';

  Future<void> handle(HttpRequest request) async {
    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }
    if (request.method != 'GET') {
      await _json(request, HttpStatus.methodNotAllowed, <String, dynamic>{
        'success': false,
        'error': 'Method not allowed.',
      });
      return;
    }

    final account = authentication.authenticate(request);
    if (account == null) {
      await _json(request, HttpStatus.unauthorized, <String, dynamic>{
        'success': false,
        'error': 'Authentication required.',
      });
      return;
    }
    final _ = account;

    try {
      final path = request.uri.path;
      if (path == '$_prefix/status') {
        await _json(request, HttpStatus.ok, <String, dynamic>{
          'success': true,
          'providers': service.providerStatus(),
        });
        return;
      }

      if (path == '$_prefix/tmdb') {
        final tmdbPath = request.uri.queryParameters['path']?.trim() ?? '';
        if (tmdbPath.isEmpty) {
          await _json(request, HttpStatus.badRequest, <String, dynamic>{
            'success': false,
            'error': 'A TMDB resource path is required.',
          });
          return;
        }
        final query = <String, String>{};
        request.uri.queryParameters.forEach((key, value) {
          if (key != 'path') query[key] = value;
        });
        final payload = await service.getTmdb(path: tmdbPath, query: query);
        await _json(request, HttpStatus.ok, payload);
        return;
      }

      await _json(request, HttpStatus.notFound, <String, dynamic>{
        'success': false,
        'error': 'Media metadata route not found.',
      });
    } on FormatException catch (error) {
      await _json(request, HttpStatus.badRequest, <String, dynamic>{
        'success': false,
        'error': error.message,
      });
    } on MediaMetadataUpstreamException catch (error, stackTrace) {
      developer.log(
        'TMDB metadata request failed.',
        name: 'MediaMetadataRoutes',
        error: error,
        stackTrace: stackTrace,
      );
      await _json(
        request,
        error.statusCode == HttpStatus.notFound
            ? HttpStatus.notFound
            : (error.statusCode == HttpStatus.gatewayTimeout
                ? HttpStatus.gatewayTimeout
                : HttpStatus.badGateway),
        <String, dynamic>{
          'success': false,
          'error': error.statusCode == HttpStatus.notFound
              ? 'TMDB metadata was not found.'
              : 'TMDB metadata is temporarily unavailable. Check backend provider configuration and access.',
        },
      );
    } catch (error, stackTrace) {
      developer.log(
        'Media metadata request failed.',
        name: 'MediaMetadataRoutes',
        error: error,
        stackTrace: stackTrace,
      );
      await _json(request, HttpStatus.internalServerError, <String, dynamic>{
        'success': false,
        'error': 'Unable to load media metadata right now.',
      });
    }
  }

  Future<void> _json(
    HttpRequest request,
    int statusCode,
    Map<String, dynamic> payload,
  ) async {
    request.response.statusCode = statusCode;
    request.response.headers.contentType = ContentType.json;
    request.response.headers.set('Cache-Control', 'private, max-age=60');
    request.response.write(jsonEncode(payload));
    await request.response.close();
  }
}
