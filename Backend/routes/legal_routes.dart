// FILE: `Backend/routes/legal_routes.dart`.
// Purpose: Implements the legal routes portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'dart:convert';
import 'dart:io';
import '../middleware/authentication.dart';

class LegalRoutes {
  static const termsVersion = '2026-09-10';
  static const privacyVersion = '2026-09-10';
  static const acceptableUseVersion = '2026-09-10';

  final AuthenticationMiddleware authentication;
  LegalRoutes({required this.authentication});

  /// Performs `handle` for this feature. Update this documentation when its contract changes.
  Future<void> handle(HttpRequest request) async {
    final path = request.uri.path;
    if (request.method == 'POST' && path == '/api/v1/legal/copyright-report') {
      try {
        final body = await _body(request);
        final email = body['reporterEmail']?.toString().trim() ?? '';
        final work = body['workDescription']?.toString().trim() ?? '';
        final allegation = body['allegation']?.toString().trim() ?? '';
        if (email.isEmpty || work.isEmpty || allegation.isEmpty) {
          _sendJson(request.response, HttpStatus.badRequest, {'error': 'Reporter email, work description and allegation are required.'});
          return;
        }
        _sendJson(request.response, HttpStatus.accepted, {
          'success': true,
          'status': 'received',
          'message': 'The report was received for review. This development endpoint does not itself determine infringement.',
        });
      } catch (_) {
        _sendJson(request.response, HttpStatus.badRequest, {'error': 'A valid JSON report is required.'});
      }
      return;
    }

    if (request.method == 'GET' && path == '/api/v1/legal/policies') {
      _sendJson(request.response, HttpStatus.ok, {
        'success': true,
        'policies': {
          'terms': {'version': termsVersion, 'title': 'Terms of Service'},
          'privacy': {'version': privacyVersion, 'title': 'Privacy Policy'},
          'acceptableUse': {'version': acceptableUseVersion, 'title': 'Copyright & Acceptable Use'},
        },
        'principles': [
          'Private libraries are isolated by account authorization.',
          'Customers must use media they own or are legally authorized to use.',
          'The service does not grant copyright permissions.',
          'The service does not authorize DRM circumvention or unauthorized redistribution.',
          'Production deployments must maintain an appropriate copyright notice and response process.',
        ],
      });
      return;
    }

    final account = authentication.authenticate(request);
    if (account == null) {
      _sendJson(request.response, HttpStatus.unauthorized, {'error': 'Authentication required.'});
      return;
    }

    if (request.method == 'GET' && path == '/api/v1/legal/account-acceptance') {
      _sendJson(request.response, HttpStatus.ok, {
        'success': true,
        'accountId': account.id,
        'legalAccepted': account.termsVersionAccepted.isNotEmpty &&
            account.privacyVersionAccepted.isNotEmpty &&
            account.acceptableUseVersionAccepted.isNotEmpty,
        'termsVersion': account.termsVersionAccepted,
        'privacyVersion': account.privacyVersionAccepted,
        'acceptableUseVersion': account.acceptableUseVersionAccepted,
        'acceptedAt': account.legalAcceptedAt?.toIso8601String(),
        'currentVersions': {
          'terms': termsVersion,
          'privacy': privacyVersion,
          'acceptableUse': acceptableUseVersion,
        },
      });
      return;
    }

    _sendJson(request.response, HttpStatus.notFound, {'error': 'Legal route not found.'});
  }

  Future<Map<String, dynamic>> _body(HttpRequest request) async {
    final raw = await utf8.decoder.bind(request).join();
    if (raw.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) throw const FormatException('JSON object required');
    return Map<String, dynamic>.from(decoded);
  }

  /// Performs `_sendJson` for this feature. Update this documentation when its contract changes.
  void _sendJson(HttpResponse response, int statusCode, Map<String, dynamic> body) {
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    response.close();
  }
}
