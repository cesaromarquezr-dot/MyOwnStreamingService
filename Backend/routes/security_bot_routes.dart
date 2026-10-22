import 'dart:convert';
import 'dart:io';

import '../middleware/authentication.dart';
import '../services/security_bot_service.dart';

/// Admin-only, read-only security bot control plane. Access is denied unless
/// SECURITY_BOT_ADMIN_ACCOUNT_IDS explicitly lists the authenticated account.
class SecurityBotRoutes {
  SecurityBotRoutes({
    required this.authentication,
    required this.service,
  });

  final AuthenticationMiddleware authentication;
  final SecurityBotService service;
  static const String _base = '/api/v1/security-bots';

  Set<String> get _adminAccountIds => (Platform.environment[
              'SECURITY_BOT_ADMIN_ACCOUNT_IDS'] ??
          '')
      .split(',')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet();

  Future<void> handle(HttpRequest request) async {
    final response = request.response;
    response.headers.set('Cache-Control', 'no-store');
    response.headers.set('X-Content-Type-Options', 'nosniff');
    response.headers.set('Content-Type', 'application/json; charset=utf-8');

    if (request.method == 'OPTIONS') {
      response.statusCode = HttpStatus.noContent;
      await response.close();
      return;
    }

    final account = authentication.authenticate(request);
    if (account == null) {
      await _json(response, HttpStatus.unauthorized, {
        'success': false,
        'error': 'Authentication required.',
      });
      return;
    }

    final admins = _adminAccountIds;
    if (admins.isEmpty) {
      await _json(response, HttpStatus.serviceUnavailable, {
        'success': false,
        'error': 'Security bot administration is not configured. Set SECURITY_BOT_ADMIN_ACCOUNT_IDS on the backend host.',
      });
      return;
    }
    if (!admins.contains(account.id)) {
      await _json(response, HttpStatus.forbidden, {
        'success': false,
        'error': 'Security bot administrator permission required.',
      });
      return;
    }

    try {
      final path = request.uri.path;
      if (request.method == 'GET' && path == '$_base/status') {
        await _json(response, HttpStatus.ok,
            await service.status(accountId: account.id));
        return;
      }
      if (request.method == 'POST' && path == '$_base/run') {
        final result = await service.runChecks(accountId: account.id);
        await _json(response, HttpStatus.ok, result);
        return;
      }
      if (request.method == 'GET' && path == '$_base/audit') {
        final parsedLimit = int.tryParse(request.uri.queryParameters['limit'] ?? '40') ?? 40;
        final limit = parsedLimit.clamp(1, 100).toInt();
        final state = await service.status(accountId: account.id, auditLimit: limit);
        final events = state['auditEvents'] is List
            ? (state['auditEvents'] as List).take(limit).toList()
            : const <dynamic>[];
        await _json(response, HttpStatus.ok, {
          'success': true,
          'events': events,
          'auditStorage': state['auditStorage'],
        });
        return;
      }

      await _json(response, HttpStatus.notFound, {
        'success': false,
        'error': 'Security bot endpoint not found.',
      });
    } catch (_) {
      // Do not send exception details, query values or configuration to clients.
      await _json(response, HttpStatus.internalServerError, {
        'success': false,
        'error': 'Security bot diagnostics could not be completed.',
      });
    }
  }

  Future<void> _json(
    HttpResponse response,
    int statusCode,
    Map<String, dynamic> body,
  ) async {
    response.statusCode = statusCode;
    response.headers.set('Cache-Control', 'no-store');
    response.write(jsonEncode(body));
    await response.close();
  }
}
