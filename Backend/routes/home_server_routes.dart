// FILE: `Backend/routes/home_server_routes.dart`.
// Purpose: Implements the home-server dashboard API routes.
// This file is part of the documented Flutter/home-server architecture.
//
// Exposes authenticated, read-only dashboard information for:
// - Storage health/status
// - ARM / physical-media ingestion status
//
// The route layer does not perform storage or ARM operations itself.
// Those responsibilities remain in HomeServerService and its underlying
// services.

import 'dart:convert';
import 'dart:io';

import '../middleware/authentication.dart';
import '../services/home_server_service.dart';

class HomeServerRoutes {
  final AuthenticationMiddleware authentication;
  final HomeServerService service;

  HomeServerRoutes({
    required this.authentication,
    required this.service,
  });

  Future<void> handle(HttpRequest request) async {
    // ------------------------------------------------------------
    // CORS / PREFLIGHT
    // ------------------------------------------------------------

    _applyCorsHeaders(request.response);

    if (request.method == 'OPTIONS') {
      await _json(
        request.response,
        HttpStatus.noContent,
        <String, dynamic>{},
      );
      return;
    }

    // ------------------------------------------------------------
    // AUTHENTICATION
    // ------------------------------------------------------------

    final auth = authentication.authenticate(request);

    if (auth == null) {
      await _json(
        request.response,
        HttpStatus.unauthorized,
        <String, dynamic>{
          'success': false,
          'error': 'Authentication required.',
        },
      );
      return;
    }

    try {
      final path = request.uri.path;

      // ----------------------------------------------------------
      // STORAGE STATUS
      // ----------------------------------------------------------

      if (request.method == 'GET' &&
          path == '/api/v1/server/storage') {
        final status = service.storageStatus();

        await _json(
          request.response,
          HttpStatus.ok,
          <String, dynamic>{
            'success': true,
            ...status,
          },
        );
        return;
      }

      // ----------------------------------------------------------
      // ARM STATUS
      // ----------------------------------------------------------

      if (request.method == 'GET' &&
          path == '/api/v1/server/arm') {
        final status = service.armStatus();

        await _json(
          request.response,
          HttpStatus.ok,
          <String, dynamic>{
            'success': true,
            ...status,
          },
        );
        return;
      }

      // ----------------------------------------------------------
      // ROUTE NOT FOUND
      // ----------------------------------------------------------

      await _json(
        request.response,
        HttpStatus.notFound,
        <String, dynamic>{
          'success': false,
          'error': 'Home server route not found.',
        },
      );
    } catch (error, stackTrace) {
      // Do not expose a stack trace to the client. The exception itself
      // is returned because the existing API contract exposes an error
      // string, but stack details remain server-side.
      stderr.writeln(
        'HomeServerRoutes error: $error',
      );
      stderr.writeln(stackTrace);

      if (!request.response.headers.contentType.toString().isNotEmpty) {
        await _json(
          request.response,
          HttpStatus.internalServerError,
          <String, dynamic>{
            'success': false,
            'error': 'Home server request failed.',
          },
        );
      }
    }
  }

  // ==============================================================
  // CORS
  // ==============================================================

  void _applyCorsHeaders(HttpResponse response) {
    response.headers.set(
      'Access-Control-Allow-Origin',
      '*',
    );

    response.headers.set(
      'Access-Control-Allow-Methods',
      'GET, OPTIONS',
    );

    response.headers.set(
      'Access-Control-Allow-Headers',
      'Authorization, Content-Type',
    );

    response.headers.set(
      'Access-Control-Expose-Headers',
      'Content-Type',
    );
  }

  // ==============================================================
  // JSON RESPONSE
  // ==============================================================

  Future<void> _json(
    HttpResponse response,
    int statusCode,
    Map<String, dynamic> body,
  ) async {
    response.statusCode = statusCode;

    response.headers.contentType = ContentType.json;

    // Server status and ARM information should never be cached by a
    // browser, reverse proxy, or intermediary because the values can
    // change while the dashboard is open.
    response.headers.set(
      'Cache-Control',
      'no-store, no-cache, must-revalidate',
    );

    response.headers.set(
      'Pragma',
      'no-cache',
    );

    response.write(
      jsonEncode(body),
    );

    await response.close();
  }
}