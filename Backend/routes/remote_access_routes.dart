// FILE: `Backend/routes/remote_access_routes.dart`.
// Purpose: Implements the remote access routes portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'dart:convert';
import 'dart:io';

import '../middleware/authentication.dart';
import '../services/email_service.dart';
import '../services/remote_access_service.dart';

class RemoteAccessRoutes {
  final AuthenticationMiddleware authentication;
  final RemoteAccessService service;
  final EmailService email;

  RemoteAccessRoutes({
    required this.authentication,
    required this.service,
    required this.email,
  });

  /// Performs `handle` for this feature. Update this documentation when its contract changes.
  Future<void> handle(HttpRequest request) async {
    _cors(request.response);

    try {
      final path = request.uri.path;

      if (request.method == 'POST' &&
          path == '/api/v1/remote/access-code') {
        return await _code(request);
      }

      if (request.method == 'POST' &&
          path == '/api/v1/remote/workers/register') {
        return await _register(request);
      }

      if (request.method == 'GET' &&
          path == '/api/v1/remote/workers') {
        return await _workers(request);
      }

      if (request.method == 'POST' &&
          path == '/api/v1/remote/jobs') {
        return await _queue(request);
      }

      if (request.method == 'GET' &&
          path.startsWith('/api/v1/remote/worker/jobs')) {
        return await _workerJobs(request);
      }

      if (request.method == 'POST' &&
          path.startsWith('/api/v1/remote/worker/jobs/')) {
        return await _workerUpdate(request);
      }

      return await _json(
        request.response,
        404,
        {
          'success': false,
          'error': 'Remote access route not found.',
        },
      );
    } catch (e) {
      return await _json(
        request.response,
        400,
        {
          'success': false,
          'error': _clean(e),
        },
      );
    }
  }

  /// Performs `_code` for this feature. Update this documentation when its contract changes.
  Future<void> _code(HttpRequest r) async {
    final a = authentication.authenticate(r);

    if (a == null) {
      return await _unauth(r);
    }

    final code = service.createOneTimeCode(a);

    await email.oneTimeCode(a.email, code);

    return await _json(
      r.response,
      200,
      {
        'success': true,
        'code': code,
        'expiresInSeconds': 600,
      },
    );
  }

  /// Performs `_register` for this feature. Update this documentation when its contract changes.
  Future<void> _register(HttpRequest r) async {
    final b = await _body(r);

    final accountId = b['accountId']?.toString();

    if (accountId == null || accountId.isEmpty) {
      return await _json(
        r.response,
        400,
        {
          'success': false,
          'error': 'accountId is required.',
        },
      );
    }

    final account =
        authentication.authService.database.accountsById[accountId];

    if (account == null) {
      return await _json(
        r.response,
        404,
        {
          'success': false,
          'error': 'Account not found.',
        },
      );
    }

    final w = service.registerWorker(
      account: account,
      code: b['code']?.toString() ?? '',
      name: b['name']?.toString() ?? '',
      platform: b['platform']?.toString() ?? 'unknown',
      hasDiscReader: b['hasDiscReader'] == true,
      supportsExternalReader: b['supportsExternalReader'] == true,
    );

    await email.newDevice(account.email, w.name);

    return await _json(
      r.response,
      201,
      {
        'success': true,
        'worker': w.toJson(includeToken: true),
      },
    );
  }

  /// Performs `_workers` for this feature. Update this documentation when its contract changes.
  Future<void> _workers(HttpRequest r) async {
    final a = authentication.authenticate(r);

    if (a == null) {
      return await _unauth(r);
    }

    return await _json(
      r.response,
      200,
      {
        'success': true,
        'workers': service
            .workersFor(a)
            .map((w) => w.toJson())
            .toList(),
      },
    );
  }

  /// Performs `_queue` for this feature. Update this documentation when its contract changes.
  Future<void> _queue(HttpRequest r) async {
    final a = authentication.authenticate(r);

    if (a == null) {
      return await _unauth(r);
    }

    final b = await _body(r);

    final j = service.queueImport(
      account: a,
      workerId: b['workerId']?.toString() ?? '',
      driveName: b['driveName']?.toString() ?? 'Disc reader',
    );

    return await _json(
      r.response,
      202,
      {
        'success': true,
        'job': j.toJson(),
      },
    );
  }

  /// Performs `_workerJobs` for this feature. Update this documentation when its contract changes.
  Future<void> _workerJobs(HttpRequest r) async {
    final token =
        r.headers.value('x-remote-worker-token') ?? '';

    final w = service.workerForToken(token);

    w.lastSeenAt = DateTime.now();

    return await _json(
      r.response,
      200,
      {
        'success': true,
        'jobs': service
            .pendingForWorker(w)
            .map((j) => j.toJson())
            .toList(),
      },
    );
  }

  /// Performs `_workerUpdate` for this feature. Update this documentation when its contract changes.
  Future<void> _workerUpdate(HttpRequest r) async {
    final token =
        r.headers.value('x-remote-worker-token') ?? '';

    final w = service.workerForToken(token);

    final id = r.uri.path.substring(
      '/api/v1/remote/worker/jobs/'.length,
    );

    final j =
        authentication.authService.database.remoteImportJobsById[id];

    if (j == null || j.workerId != w.id) {
      throw Exception('Remote import job not found.');
    }

    final b = await _body(r);

    final previousStatus = j.status;

    j.status = b['status']?.toString() ?? j.status;

    j.progress = (b['progress'] is num)
        ? (b['progress'] as num).toDouble()
        : j.progress;

    j.title = b['title']?.toString() ?? j.title;

    j.message = b['message']?.toString() ?? j.message;

    if (j.status == 'completed' &&
        previousStatus != 'completed') {
      final account =
          authentication.authService.database.accountsById[w.accountId];

      if (account != null) {
        await email.mediaAdded(
          account.email,
          'Remote computer',
          j.title ?? 'New media',
          details:
              'The remote disc-import worker completed processing. '
              'The media is available to every profile on the account.',
        );
      }
    }

    return await _json(
      r.response,
      200,
      {
        'success': true,
        'job': j.toJson(),
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

  /// Performs `_unauth` for this feature. Update this documentation when its contract changes.
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

  /// Performs `_json` for this feature. Update this documentation when its contract changes.
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

  /// Performs `_cors` for this feature. Update this documentation when its contract changes.
  void _cors(HttpResponse r) {
    r.headers.set(
      'Access-Control-Allow-Origin',
      '*',
    );

    r.headers.set(
      'Access-Control-Allow-Methods',
      'GET, POST, OPTIONS',
    );

    r.headers.set(
      'Access-Control-Allow-Headers',
      'Origin, Content-Type, Accept, Authorization, X-Remote-Worker-Token',
    );
  }

  /// Performs `_clean` for this feature. Update this documentation when its contract changes.
  String _clean(Object e) {
    return e.toString().replaceFirst(
      'Exception: ',
      '',
    );
  }
}
