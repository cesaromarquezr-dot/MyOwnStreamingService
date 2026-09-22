// FILE: `Backend/routes/legal_routes.dart`.
// Purpose: Implements the legal routes portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.
//
// Public routes:
// - GET  /api/v1/legal/policies
// - POST /api/v1/legal/copyright-report
//
// Authenticated routes:
// - GET /api/v1/legal/account-acceptance
//
// Legal policy content is informational API data. This route does not make
// legal determinations, adjudicate copyright disputes, or grant permissions.

import 'dart:convert';
import 'dart:io';

import '../middleware/authentication.dart';

class LegalRoutes {
  static const String termsVersion = '2026-09-10';
  static const String privacyVersion = '2026-09-10';
  static const String acceptableUseVersion = '2026-09-10';

  final AuthenticationMiddleware authentication;

  LegalRoutes({
    required this.authentication,
  });

  Future<void> handle(HttpRequest request) async {
    _applyCorsHeaders(request.response);

    // Browser preflight requests do not contain the application's bearer
    // credentials and therefore must be handled before authentication.
    if (request.method == 'OPTIONS') {
      await _sendJson(
        request.response,
        HttpStatus.noContent,
        <String, dynamic>{},
      );
      return;
    }

    final path = request.uri.path;

    // ------------------------------------------------------------------
    // PUBLIC COPYRIGHT REPORT
    // ------------------------------------------------------------------

    if (request.method == 'POST' &&
        path == '/api/v1/legal/copyright-report') {
      await _handleCopyrightReport(request);
      return;
    }

    // ------------------------------------------------------------------
    // PUBLIC POLICY VERSIONS
    // ------------------------------------------------------------------

    if (request.method == 'GET' &&
        path == '/api/v1/legal/policies') {
      await _sendJson(
        request.response,
        HttpStatus.ok,
        <String, dynamic>{
          'success': true,
          'policies': <String, dynamic>{
            'terms': <String, dynamic>{
              'version': termsVersion,
              'title': 'Terms of Service',
            },
            'privacy': <String, dynamic>{
              'version': privacyVersion,
              'title': 'Privacy Policy',
            },
            'acceptableUse': <String, dynamic>{
              'version': acceptableUseVersion,
              'title': 'Copyright & Acceptable Use',
            },
          },
          'principles': <String>[
            'Private libraries are isolated by account authorization.',
            'Customers must use media they own or are legally authorized to use.',
            'The service does not grant copyright permissions.',
            'The service does not authorize DRM circumvention or unauthorized redistribution.',
            'Production deployments must maintain an appropriate copyright notice and response process.',
          ],
        },
      );
      return;
    }

    // ------------------------------------------------------------------
    // AUTHENTICATION
    // ------------------------------------------------------------------

    final account = authentication.authenticate(request);

    if (account == null) {
      await _sendJson(
        request.response,
        HttpStatus.unauthorized,
        <String, dynamic>{
          'success': false,
          'error': 'Authentication required.',
        },
      );
      return;
    }

    // ------------------------------------------------------------------
    // ACCOUNT LEGAL ACCEPTANCE
    // ------------------------------------------------------------------

    if (request.method == 'GET' &&
        path == '/api/v1/legal/account-acceptance') {
      final legalAccepted =
          account.termsVersionAccepted.isNotEmpty &&
          account.privacyVersionAccepted.isNotEmpty &&
          account.acceptableUseVersionAccepted.isNotEmpty;

      await _sendJson(
        request.response,
        HttpStatus.ok,
        <String, dynamic>{
          'success': true,
          'accountId': account.id,
          'legalAccepted': legalAccepted,
          'termsVersion': account.termsVersionAccepted,
          'privacyVersion': account.privacyVersionAccepted,
          'acceptableUseVersion': account.acceptableUseVersionAccepted,
          'acceptedAt': account.legalAcceptedAt?.toIso8601String(),
          'currentVersions': <String, dynamic>{
            'terms': termsVersion,
            'privacy': privacyVersion,
            'acceptableUse': acceptableUseVersion,
          },
        },
      );
      return;
    }

    // ------------------------------------------------------------------
    // NOT FOUND
    // ------------------------------------------------------------------

    await _sendJson(
      request.response,
      HttpStatus.notFound,
      <String, dynamic>{
        'success': false,
        'error': 'Legal route not found.',
      },
    );
  }

  Future<void> _handleCopyrightReport(HttpRequest request) async {
    try {
      final body = await _body(request);

      final reporterEmail =
          body['reporterEmail']?.toString().trim() ?? '';
      final workDescription =
          body['workDescription']?.toString().trim() ?? '';
      final allegation =
          body['allegation']?.toString().trim() ?? '';

      if (reporterEmail.isEmpty ||
          workDescription.isEmpty ||
          allegation.isEmpty) {
        await _sendJson(
          request.response,
          HttpStatus.badRequest,
          <String, dynamic>{
            'success': false,
            'error':
                'Reporter email, work description and allegation are required.',
          },
        );
        return;
      }

      // This endpoint acknowledges receipt only. It intentionally does not
      // determine whether infringement occurred.
      await _sendJson(
        request.response,
        HttpStatus.accepted,
        <String, dynamic>{
          'success': true,
          'status': 'received',
          'message':
              'The report was received for review. This development endpoint does not itself determine infringement.',
        },
      );
    } on FormatException {
      await _sendJson(
        request.response,
        HttpStatus.badRequest,
        <String, dynamic>{
          'success': false,
          'error': 'A valid JSON report is required.',
        },
      );
    } catch (error, stackTrace) {
      stderr.writeln('LegalRoutes copyright report error: $error');
      stderr.writeln(stackTrace);

      await _sendJson(
        request.response,
        HttpStatus.badRequest,
        <String, dynamic>{
          'success': false,
          'error': 'A valid JSON report is required.',
        },
      );
    }
  }

  Future<Map<String, dynamic>> _body(HttpRequest request) async {
    final raw = await utf8.decoder.bind(request).join();

    if (raw.trim().isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(raw);

    if (decoded is! Map) {
      throw const FormatException('JSON object required.');
    }

    return Map<String, dynamic>.from(decoded);
  }

  void _applyCorsHeaders(HttpResponse response) {
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
  }

  Future<void> _sendJson(
    HttpResponse response,
    int statusCode,
    Map<String, dynamic> body,
  ) async {
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.json;

    // Policy/account-acceptance responses should not become stale in a
    // browser, proxy, or shared cache when legal versions change.
    response.headers.set(
      'Cache-Control',
      'no-store, no-cache, must-revalidate',
    );
    response.headers.set(
      'Pragma',
      'no-cache',
    );

    response.write(jsonEncode(body));
    await response.close();
  }
}
