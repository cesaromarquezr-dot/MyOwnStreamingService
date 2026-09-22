// FILE: `Backend/routes/remote_access_routes.dart`.
// Purpose: Implements the remote access routes portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.
//
// Security model:
// - Account-facing operations require a normal authenticated account session.
// - Worker registration is authorized by the server-issued one-time code.
// - The client-supplied accountId is never treated as authorization by itself.
// - Worker polling and job updates require the worker token.
// - Worker tokens are never returned by ordinary worker-list endpoints.
// - Remote job access is restricted to the worker that owns the job.
// - Internal exceptions are logged server-side and are not returned to clients.

import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import '../middleware/authentication.dart';
import '../services/email_service.dart';
import '../services/remote_access_service.dart';

class RemoteAccessRoutes {
  static const String _accessCodePath =
      '/api/v1/remote/access-code';

  static const String _workerRegisterPath =
      '/api/v1/remote/workers/register';

  static const String _workersPath =
      '/api/v1/remote/workers';

  static const String _jobsPath =
      '/api/v1/remote/jobs';

  static const String _workerJobsPath =
      '/api/v1/remote/worker/jobs';

  static const String _workerJobPrefix =
      '/api/v1/remote/worker/jobs/';

  static const int _maxBodyBytes = 128 * 1024;
  static const int _maxAccountIdLength = 256;
  static const int _maxWorkerIdLength = 256;
  static const int _maxJobIdLength = 256;
  static const int _maxCodeLength = 256;
  static const int _maxNameLength = 256;
  static const int _maxPlatformLength = 128;
  static const int _maxDriveNameLength = 256;
  static const int _maxStatusLength = 64;
  static const int _maxTitleLength = 500;
  static const int _maxMessageLength = 2000;

  final AuthenticationMiddleware authentication;
  final RemoteAccessService service;
  final EmailService email;

  RemoteAccessRoutes({
    required this.authentication,
    required this.service,
    required this.email,
  });

  Future<void> handle(HttpRequest request) async {
    _cors(request.response);

    if (request.method == 'OPTIONS') {
      await _close(
        request.response,
        HttpStatus.noContent,
      );
      return;
    }

    try {
      final path = request.uri.path;

      if (request.method == 'POST' &&
          path == _accessCodePath) {
        await _code(request);
        return;
      }

      if (request.method == 'POST' &&
          path == _workerRegisterPath) {
        await _register(request);
        return;
      }

      if (request.method == 'GET' &&
          path == _workersPath) {
        await _workers(request);
        return;
      }

      if (request.method == 'POST' &&
          path == _jobsPath) {
        await _queue(request);
        return;
      }

      if (request.method == 'GET' &&
          path == _workerJobsPath) {
        await _workerJobs(request);
        return;
      }

      if (request.method == 'POST' &&
          path.startsWith(_workerJobPrefix)) {
        await _workerUpdate(request);
        return;
      }

      await _json(
        request.response,
        HttpStatus.notFound,
        <String, dynamic>{
          'success': false,
          'error': 'Remote access route not found.',
        },
      );
    } on FormatException catch (error, stackTrace) {
      developer.log(
        'Invalid remote access request.',
        name: 'RemoteAccessRoutes',
        error: error,
        stackTrace: stackTrace,
      );

      await _json(
        request.response,
        HttpStatus.badRequest,
        <String, dynamic>{
          'success': false,
          'error': 'Invalid remote access request.',
        },
      );
    } on _RequestTooLargeException catch (error, stackTrace) {
      developer.log(
        'Remote access request body exceeded size limit.',
        name: 'RemoteAccessRoutes',
        error: error,
        stackTrace: stackTrace,
      );

      await _json(
        request.response,
        HttpStatus.requestEntityTooLarge,
        <String, dynamic>{
          'success': false,
          'error': 'Request body is too large.',
        },
      );
    } catch (error, stackTrace) {
      developer.log(
        'Remote access route failed.',
        name: 'RemoteAccessRoutes',
        error: error,
        stackTrace: stackTrace,
      );

      await _json(
        request.response,
        HttpStatus.internalServerError,
        <String, dynamic>{
          'success': false,
          'error': 'Unable to process the remote access request.',
        },
      );
    }
  }

  Future<void> _code(HttpRequest request) async {
    final account =
        authentication.authenticate(request);

    if (account == null) {
      await _unauth(request);
      return;
    }

    final code = service.createOneTimeCode(account);

    await email.oneTimeCode(
      account.email,
      code,
    );

    await _json(
      request.response,
      HttpStatus.ok,
      <String, dynamic>{
        'success': true,
        // The code is returned because the existing application contract
        // supports displaying/copying it during local worker setup.
        // Production deployments should prefer delivering it only through
        // the configured trusted channel.
        'code': code,
        'expiresInSeconds': 600,
      },
    );
  }

  Future<void> _register(HttpRequest request) async {
    final body = await _body(request);

    final accountId =
        body['accountId']?.toString().trim() ?? '';

    final code =
        body['code']?.toString().trim() ?? '';

    final name =
        body['name']?.toString().trim() ?? '';

    final platform =
        body['platform']?.toString().trim() ?? 'unknown';

    if (accountId.isEmpty ||
        accountId.length > _maxAccountIdLength) {
      await _json(
        request.response,
        HttpStatus.badRequest,
        <String, dynamic>{
          'success': false,
          'error': 'A valid accountId is required.',
        },
      );
      return;
    }

    if (code.isEmpty || code.length > _maxCodeLength) {
      await _json(
        request.response,
        HttpStatus.badRequest,
        <String, dynamic>{
          'success': false,
          'error': 'A valid registration code is required.',
        },
      );
      return;
    }

    if (name.length > _maxNameLength) {
      await _json(
        request.response,
        HttpStatus.badRequest,
        <String, dynamic>{
          'success': false,
          'error': 'Worker name is too long.',
        },
      );
      return;
    }

    if (platform.isEmpty ||
        platform.length > _maxPlatformLength) {
      await _json(
        request.response,
        HttpStatus.badRequest,
        <String, dynamic>{
          'success': false,
          'error': 'Worker platform is invalid.',
        },
      );
      return;
    }

    final account =
        authentication.authService.database.accountsById[
            accountId];

    if (account == null) {
      // Do not disclose whether the account identifier exists.
      await _json(
        request.response,
        HttpStatus.unauthorized,
        <String, dynamic>{
          'success': false,
          'error': 'Invalid worker registration credentials.',
        },
      );
      return;
    }

    try {
      final worker = service.registerWorker(
        account: account,
        code: code,
        name: name,
        platform: platform,
        hasDiscReader:
            body['hasDiscReader'] == true,
        supportsExternalReader:
            body['supportsExternalReader'] == true,
      );

      await email.newDevice(
        account.email,
        worker.name,
      );

      await _json(
        request.response,
        HttpStatus.created,
        <String, dynamic>{
          'success': true,
          'worker': worker.toJson(
            includeToken: true,
          ),
        },
      );
    } catch (error, stackTrace) {
      developer.log(
        'Remote worker registration failed.',
        name: 'RemoteAccessRoutes',
        error: error,
        stackTrace: stackTrace,
      );

      await _json(
        request.response,
        HttpStatus.unauthorized,
        <String, dynamic>{
          'success': false,
          'error': 'Invalid worker registration credentials.',
        },
      );
    }
  }

  Future<void> _workers(HttpRequest request) async {
    final account =
        authentication.authenticate(request);

    if (account == null) {
      await _unauth(request);
      return;
    }

    await _json(
      request.response,
      HttpStatus.ok,
      <String, dynamic>{
        'success': true,
        'workers': service
            .workersFor(account)
            .map(
              (worker) => worker.toJson(),
            )
            .toList(growable: false),
      },
    );
  }

  Future<void> _queue(HttpRequest request) async {
    final account =
        authentication.authenticate(request);

    if (account == null) {
      await _unauth(request);
      return;
    }

    final body = await _body(request);

    final workerId =
        body['workerId']?.toString().trim() ?? '';

    final driveName =
        body['driveName']?.toString().trim() ??
            'Disc reader';

    if (workerId.isEmpty ||
        workerId.length > _maxWorkerIdLength) {
      await _json(
        request.response,
        HttpStatus.badRequest,
        <String, dynamic>{
          'success': false,
          'error': 'A valid workerId is required.',
        },
      );
      return;
    }

    if (driveName.isEmpty ||
        driveName.length > _maxDriveNameLength) {
      await _json(
        request.response,
        HttpStatus.badRequest,
        <String, dynamic>{
          'success': false,
          'error': 'driveName is invalid.',
        },
      );
      return;
    }

    final job = service.queueImport(
      account: account,
      workerId: workerId,
      driveName: driveName,
    );

    await _json(
      request.response,
      HttpStatus.accepted,
      <String, dynamic>{
        'success': true,
        'job': job.toJson(),
      },
    );
  }

  Future<void> _workerJobs(HttpRequest request) async {
    final token =
        request.headers.value(
              'x-remote-worker-token',
            )?.trim() ??
            '';

    if (token.isEmpty) {
      await _workerUnauthorized(request);
      return;
    }

    final worker = _workerForToken(token);

    if (worker == null) {
      await _workerUnauthorized(request);
      return;
    }

    worker.lastSeenAt = DateTime.now();

    await _json(
      request.response,
      HttpStatus.ok,
      <String, dynamic>{
        'success': true,
        'jobs': service
            .pendingForWorker(worker)
            .map(
              (job) => job.toJson(),
            )
            .toList(growable: false),
      },
    );
  }

  Future<void> _workerUpdate(HttpRequest request) async {
    final token =
        request.headers.value(
              'x-remote-worker-token',
            )?.trim() ??
            '';

    if (token.isEmpty) {
      await _workerUnauthorized(request);
      return;
    }

    final worker = _workerForToken(token);

    if (worker == null) {
      await _workerUnauthorized(request);
      return;
    }

    final id = _extractJobId(
      request.uri.path,
    );

    if (id == null) {
      await _json(
        request.response,
        HttpStatus.badRequest,
        <String, dynamic>{
          'success': false,
          'error': 'A valid remote import job ID is required.',
        },
      );
      return;
    }

    final database =
        authentication.authService.database;

    final job =
        database.remoteImportJobsById[id];

    if (job == null ||
        job.workerId != worker.id) {
      await _json(
        request.response,
        HttpStatus.notFound,
        <String, dynamic>{
          'success': false,
          'error': 'Remote import job not found.',
        },
      );
      return;
    }

    final body = await _body(request);

    final validationError =
        _validateWorkerUpdate(body);

    if (validationError != null) {
      await _json(
        request.response,
        HttpStatus.badRequest,
        <String, dynamic>{
          'success': false,
          'error': validationError,
        },
      );
      return;
    }

    final previousStatus =
        job.status;

    if (body.containsKey('status')) {
      job.status =
          body['status'].toString().trim();
    }

    if (body.containsKey('progress')) {
      job.progress =
          (body['progress'] as num).toDouble();
    }

    if (body.containsKey('title')) {
      job.title =
          body['title']?.toString().trim();
    }

    if (body.containsKey('message')) {
      job.message =
          body['message']?.toString().trim();
    }

    worker.lastSeenAt = DateTime.now();

    if (job.status == 'completed' &&
        previousStatus != 'completed') {
      final account =
          database.accountsById[worker.accountId];

      if (account != null) {
        try {
          await email.mediaAdded(
            account.email,
            'Remote computer',
            job.title ?? 'New media',
            details:
                'The remote disc-import worker completed '
                'processing. The media is available to '
                'profiles on the account.',
          );
        } catch (error, stackTrace) {
          developer.log(
            'Unable to send remote media completion email.',
            name: 'RemoteAccessRoutes',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }
    }

    await _json(
      request.response,
      HttpStatus.ok,
      <String, dynamic>{
        'success': true,
        'job': job.toJson(),
      },
    );
  }

  dynamic _workerForToken(String token) {
    try {
      return service.workerForToken(token);
    } catch (error, stackTrace) {
      developer.log(
        'Remote worker token lookup failed.',
        name: 'RemoteAccessRoutes',
        error: error,
        stackTrace: stackTrace,
      );

      return null;
    }
  }

  String? _extractJobId(String path) {
    if (!path.startsWith(_workerJobPrefix)) {
      return null;
    }

    final encodedId =
        path.substring(_workerJobPrefix.length);

    if (encodedId.isEmpty ||
        encodedId.contains('/') ||
        encodedId.contains('\\') ||
        encodedId.contains('\u0000')) {
      return null;
    }

    final id = Uri.decodeComponent(
      encodedId,
    ).trim();

    if (id.isEmpty ||
        id.length > _maxJobIdLength ||
        id.contains('/') ||
        id.contains('\\') ||
        id.contains('\u0000') ||
        id == '.' ||
        id == '..') {
      return null;
    }

    return id;
  }

  String? _validateWorkerUpdate(
    Map<String, dynamic> body,
  ) {
    if (body.containsKey('status')) {
      final status =
          body['status']?.toString().trim() ?? '';

      if (status.isEmpty ||
          status.length > _maxStatusLength) {
        return 'status is invalid.';
      }

      if (!_allowedStatuses.contains(status)) {
        return 'Unsupported remote job status.';
      }
    }

    if (body.containsKey('progress')) {
      final value = body['progress'];

      if (value is! num) {
        return 'progress must be numeric.';
      }

      final progress = value.toDouble();

      if (!progress.isFinite ||
          progress < 0.0 ||
          progress > 1.0) {
        return 'progress must be between 0 and 1.';
      }
    }

    if (body.containsKey('title')) {
      final title =
          body['title']?.toString().trim() ?? '';

      if (title.length > _maxTitleLength) {
        return 'title is too long.';
      }
    }

    if (body.containsKey('message')) {
      final message =
          body['message']?.toString().trim() ?? '';

      if (message.length > _maxMessageLength) {
        return 'message is too long.';
      }
    }

    return null;
  }

  static const Set<String> _allowedStatuses = <String>{
    'queued',
    'pending',
    'running',
    'processing',
    'completed',
    'failed',
    'cancelled',
    'canceled',
  };

  Future<Map<String, dynamic>> _body(
    HttpRequest request,
  ) async {
    final contentLength =
        request.contentLength;

    if (contentLength > _maxBodyBytes) {
      throw const _RequestTooLargeException();
    }

    final chunks = <List<int>>[];
    var totalBytes = 0;

    await for (final chunk in request) {
      totalBytes += chunk.length;

      if (totalBytes > _maxBodyBytes) {
        throw const _RequestTooLargeException();
      }

      chunks.add(chunk);
    }

    if (totalBytes == 0) {
      return <String, dynamic>{};
    }

    final bytes = <int>[];

    for (final chunk in chunks) {
      bytes.addAll(chunk);
    }

    final text = utf8.decode(bytes);

    if (text.trim().isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(text);

    if (decoded is! Map) {
      throw const FormatException(
        'JSON object required.',
      );
    }

    return Map<String, dynamic>.from(
      decoded,
    );
  }

  Future<void> _unauth(
    HttpRequest request,
  ) {
    return _json(
      request.response,
      HttpStatus.unauthorized,
      <String, dynamic>{
        'success': false,
        'error': 'Authentication required.',
      },
    );
  }

  Future<void> _workerUnauthorized(
    HttpRequest request,
  ) {
    return _json(
      request.response,
      HttpStatus.unauthorized,
      <String, dynamic>{
        'success': false,
        'error': 'Valid remote worker credentials are required.',
      },
    );
  }

  Future<void> _json(
    HttpResponse response,
    int code,
    Map<String, dynamic> body,
  ) async {
    response.statusCode = code;

    response.headers
      ..contentType = ContentType.json
      ..set(
        'Cache-Control',
        'no-store, no-cache, must-revalidate',
      )
      ..set(
        'Pragma',
        'no-cache',
      )
      ..set(
        'X-Content-Type-Options',
        'nosniff',
      );

    response.write(
      jsonEncode(body),
    );

    await response.close();
  }

  Future<void> _close(
    HttpResponse response,
    int code,
  ) async {
    response.statusCode = code;

    response.headers
      ..set(
        'Cache-Control',
        'no-store',
      )
      ..set(
        'X-Content-Type-Options',
        'nosniff',
      );

    await response.close();
  }

  void _cors(HttpResponse response) {
    response.headers
      ..set(
        'Access-Control-Allow-Origin',
        '*',
      )
      ..set(
        'Access-Control-Allow-Methods',
        'GET, POST, OPTIONS',
      )
      ..set(
        'Access-Control-Allow-Headers',
        'Origin, Content-Type, Accept, Authorization, '
            'X-Remote-Worker-Token',
      )
      ..set(
        'Access-Control-Expose-Headers',
        'Content-Type, Content-Length',
      );
  }
}

class _RequestTooLargeException
    implements Exception {
  const _RequestTooLargeException();
}