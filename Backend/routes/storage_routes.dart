import 'dart:convert';
import 'dart:io';

import '../middleware/authentication.dart';
import '../services/email_service.dart';

class StorageRoutes {
  final AuthenticationMiddleware authentication;
  final EmailService email;

  StorageRoutes({
    required this.authentication,
    required this.email,
  });

  Future<void> handle(HttpRequest request) async {
    try {
      final path = request.uri.path;

      if (request.method == 'GET' && path == '/api/v1/storage') {
        return await _get(request);
      }

      if (request.method == 'POST' &&
          path == '/api/v1/storage/request') {
        return await _request(request);
      }

      if (request.method == 'POST' &&
          path == '/api/v1/storage/grant') {
        return await _grant(request);
      }

      return await _json(
        request.response,
        404,
        {
          'success': false,
          'error': 'Storage route not found.',
        },
      );
    } catch (e) {
      return await _json(
        request.response,
        400,
        {
          'success': false,
          'error': e.toString().replaceFirst(
                'Exception: ',
                '',
              ),
        },
      );
    }
  }

  Future<void> _get(HttpRequest r) async {
    final a = authentication.authenticate(r);

    if (a == null) {
      return await _unauth(r);
    }

    return await _json(
      r.response,
      200,
      {
        'success': true,
        'limitBytes': a.storageLimitBytes,
        'usedBytes': a.storageUsedBytes,
        'freeBytes':
            a.storageLimitBytes - a.storageUsedBytes,
        'requestPending': a.storageRequestPending,
      },
    );
  }

  Future<void> _request(HttpRequest r) async {
    final a = authentication.authenticate(r);

    if (a == null) {
      return await _unauth(r);
    }

    if (a.storageRequestPending) {
      throw Exception(
        'A storage request is already pending.',
      );
    }

    a.storageRequestPending = true;
    a.storageRequestAt = DateTime.now();

    await email.storageRequest(
      a.email,
      a.username,
    );

    return await _json(
      r.response,
      202,
      {
        'success': true,
        'message':
            'Storage request sent to the platform owner.',
        'requestPending': true,
      },
    );
  }

  Future<void> _grant(HttpRequest r) async {
    final key =
        Platform.environment['STREAM_PLATFORM_ADMIN_KEY'] ??
            '';

    if (key.isEmpty ||
        r.headers.value('x-platform-admin-key') != key) {
      return await _json(
        r.response,
        403,
        {
          'success': false,
          'error':
              'Platform admin authorization required.',
        },
      );
    }

    final b = await _body(r);

    final id = b['accountId']?.toString() ?? '';

    final tb = b['additionalTerabytes'] is num
        ? (b['additionalTerabytes'] as num).toInt()
        : int.tryParse(
              b['additionalTerabytes']?.toString() ?? '',
            ) ??
            0;

    final a =
        authentication.authService.database.accountsById[id];

    if (a == null) {
      return await _json(
        r.response,
        404,
        {
          'success': false,
          'error': 'Account not found.',
        },
      );
    }

    if (tb <= 0) {
      throw Exception(
        'Additional storage must be greater than zero.',
      );
    }

    a.storageLimitBytes += tb * 1000000000000;
    a.storageRequestPending = false;

    await email.storageApproved(
      a.email,
      tb,
    );

    return await _json(
      r.response,
      200,
      {
        'success': true,
        'limitBytes': a.storageLimitBytes,
        'additionalTerabytes': tb,
        'requestPending': false,
      },
    );
  }

  Future<Map<String, dynamic>> _body(HttpRequest r) async {
    final s = await utf8.decoder.bind(r).join();

    if (s.trim().isEmpty) {
      return {};
    }

    final d = jsonDecode(s);

    if (d is! Map) {
      throw Exception('JSON object required.');
    }

    return Map<String, dynamic>.from(d);
  }

  Future<void> _unauth(HttpRequest r) {
    return _json(
      r.response,
      401,
      {
        'success': false,
        'error': 'Authentication required.',
      },
    );
  }

  Future<void> _json(
    HttpResponse r,
    int code,
    Map<String, dynamic> body,
  ) async {
    r.statusCode = code;
    r.headers.contentType = ContentType.json;
    r.write(jsonEncode(body));
    await r.close();
  }
}