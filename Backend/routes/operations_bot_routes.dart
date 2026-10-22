import 'dart:convert';
import 'dart:io';

import '../middleware/authentication.dart';
import '../services/operations_bot_service.dart';

/// Owner-only route for read-only, on-demand operations checks.
class OperationsBotRoutes {
  final AuthenticationMiddleware authentication;
  final OperationsBotService service;

  const OperationsBotRoutes({required this.authentication, required this.service});

  Future<void> handle(HttpRequest request) async {
    request.response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    request.response.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');

    final principal = authentication.principal(request);
    if (principal == null) {
      await _json(request.response, HttpStatus.unauthorized, <String, dynamic>{'success': false, 'error': 'Authentication required.'});
      return;
    }
    if (!principal.isOwner) {
      await _json(request.response, HttpStatus.forbidden, <String, dynamic>{'success': false, 'error': 'Only the account owner can run server operations checks.'});
      return;
    }

    final path = request.uri.path;
    if (request.method == 'GET' && path == '/api/v1/operations/bots/status') {
      await _json(request.response, HttpStatus.ok, service.status());
      return;
    }
    if (request.method == 'POST' && path == '/api/v1/operations/bots/run') {
      await _json(request.response, HttpStatus.ok, service.runScan());
      return;
    }
    await _json(request.response, HttpStatus.methodNotAllowed, <String, dynamic>{
      'success': false,
      'error': 'Use GET /status or POST /run.',
    });
  }

  Future<void> _json(HttpResponse response, int statusCode, Map<String, dynamic> body) async {
    response.statusCode = statusCode;
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    response.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');
    response.write(jsonEncode(body));
    await response.close();
  }
}
