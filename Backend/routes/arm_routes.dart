// FILE: `Backend/routes/arm_routes.dart`.
// Purpose: Implements the arm routes portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'dart:convert';
import 'dart:io';

import '../arm/arm_service.dart';
import '../middleware/authentication.dart';

class ArmRoutes {
  final ArmService armService;

  final AuthenticationMiddleware authentication;

  ArmRoutes({
    required this.armService,
    required this.authentication,
  });

  /// Performs `handle` for this feature. Update this documentation when its contract changes.
  Future<void> handle(
    HttpRequest request,
  ) async {
    _addCorsHeaders(request.response);

    if (request.method == 'OPTIONS') {
      request.response.statusCode =
          HttpStatus.noContent;

      await request.response.close();

      return;
    }

    try {
      final path = request.uri.path;

      if (request.method == 'GET' &&
          path == '/api/v1/arm/status') {
        await _status(request);
        return;
      }

      if (request.method == 'GET' &&
          path == '/api/v1/arm/drives') {
        await _drives(request);
        return;
      }

      if (request.method == 'POST' &&
          path == '/api/v1/arm/scan') {
        await _scan(request);
        return;
      }

      if (request.method == 'POST' &&
          path == '/api/v1/arm/import') {
        await _import(request);
        return;
      }

      if (request.method == 'GET' &&
          path.startsWith('/api/v1/arm/jobs/')) {
        await _job(request);
        return;
      }

      if (request.method == 'POST' &&
          path.startsWith('/api/v1/arm/jobs/') &&
          path.endsWith('/cancel')) {
        await _cancel(request);
        return;
      }

      await _sendJson(
        request.response,
        HttpStatus.notFound,
        {
          'success': false,
          'error': 'ARM route not found.',
        },
      );
    } catch (error) {
      await _sendJson(
        request.response,
        HttpStatus.badRequest,
        {
          'success': false,
          'error': _cleanError(error),
        },
      );
    }
  }

  /// Performs `_status` for this feature. Update this documentation when its contract changes.
  Future<void> _status(
    HttpRequest request,
  ) async {
    final account =
        authentication.authenticate(request);

    if (account == null) {
      await _sendUnauthorized(request.response);
      return;
    }

    final connected =
        await armService.isConnected();

    await _sendJson(
      request.response,
      HttpStatus.ok,
      {
        'success': true,
        'connected': connected,
        'service': 'ARM',
      },
    );
  }

  /// Performs `_drives` for this feature. Update this documentation when its contract changes.
  Future<void> _drives(
    HttpRequest request,
  ) async {
    final account =
        authentication.authenticate(request);

    if (account == null) {
      await _sendUnauthorized(request.response);
      return;
    }

    final drives =
        await armService.findDrives();

    await _sendJson(
      request.response,
      HttpStatus.ok,
      {
        'success': true,
        'drives': drives.map(
          (drive) => drive.toJson(),
        ).toList(),
      },
    );
  }

  /// Performs `_scan` for this feature. Update this documentation when its contract changes.
  Future<void> _scan(
    HttpRequest request,
  ) async {
    final account =
        authentication.authenticate(request);

    if (account == null) {
      await _sendUnauthorized(request.response);
      return;
    }

    final body = await _readJson(request);

    final driveId = body['driveId'];

    if (driveId is! String ||
        driveId.trim().isEmpty) {
      await _sendJson(
        request.response,
        HttpStatus.badRequest,
        {
          'success': false,
          'error': 'driveId is required.',
        },
      );

      return;
    }

    final disc = await armService.scanDisc(
      driveId: driveId,
    );

    await _sendJson(
      request.response,
      HttpStatus.ok,
      {
        'success': true,
        'disc': disc.toJson(),
      },
    );
  }

  /// Performs `_import` for this feature. Update this documentation when its contract changes.
  Future<void> _import(
    HttpRequest request,
  ) async {
    final account =
        authentication.authenticate(request);

    if (account == null) {
      await _sendUnauthorized(request.response);
      return;
    }

    final body = await _readJson(request);

    final driveId = body['driveId'];

    if (driveId is! String ||
        driveId.trim().isEmpty) {
      await _sendJson(
        request.response,
        HttpStatus.badRequest,
        {
          'success': false,
          'error': 'driveId is required.',
        },
      );

      return;
    }

    final job = await armService.startImport(
      driveId: driveId,
    );

    await _sendJson(
      request.response,
      HttpStatus.accepted,
      {
        'success': true,
        'message': 'Import job created.',
        'job': job.toJson(),
      },
    );
  }

  /// Performs `_job` for this feature. Update this documentation when its contract changes.
  Future<void> _job(
    HttpRequest request,
  ) async {
    final account =
        authentication.authenticate(request);

    if (account == null) {
      await _sendUnauthorized(request.response);
      return;
    }

    const prefix = '/api/v1/arm/jobs/';

    final jobId = request.uri.path.substring(
      prefix.length,
    );

    if (jobId.isEmpty) {
      await _sendJson(
        request.response,
        HttpStatus.badRequest,
        {
          'success': false,
          'error': 'Job ID is required.',
        },
      );

      return;
    }

    final job = await armService.refreshJob(
      jobId,
    );

    await _sendJson(
      request.response,
      HttpStatus.ok,
      {
        'success': true,
        'job': job.toJson(),
      },
    );
  }

  /// Performs `_cancel` for this feature. Update this documentation when its contract changes.
  Future<void> _cancel(
    HttpRequest request,
  ) async {
    final account =
        authentication.authenticate(request);

    if (account == null) {
      await _sendUnauthorized(request.response);
      return;
    }

    const prefix = '/api/v1/arm/jobs/';
    const suffix = '/cancel';

    var jobId = request.uri.path.substring(
      prefix.length,
    );

    if (jobId.endsWith(suffix)) {
      jobId = jobId.substring(
        0,
        jobId.length - suffix.length,
      );
    }

    if (jobId.isEmpty) {
      await _sendJson(
        request.response,
        HttpStatus.badRequest,
        {
          'success': false,
          'error': 'Job ID is required.',
        },
      );

      return;
    }

    final job = await armService.cancelJob(
      jobId,
    );

    await _sendJson(
      request.response,
      HttpStatus.ok,
      {
        'success': true,
        'message': 'Import cancelled.',
        'job': job.toJson(),
      },
    );
  }

  Future<Map<String, dynamic>> _readJson(
    HttpRequest request,
  ) async {
    final content =
        await utf8.decoder.bind(request).join();

    if (content.trim().isEmpty) {
      return {};
    }

    final decoded = jsonDecode(content);

    if (decoded is! Map) {
      throw Exception(
        'Request body must be a JSON object.',
      );
    }

    return Map<String, dynamic>.from(
      decoded,
    );
  }

  /// Performs `_sendUnauthorized` for this feature. Update this documentation when its contract changes.
  Future<void> _sendUnauthorized(
    HttpResponse response,
  ) async {
    await _sendJson(
      response,
      HttpStatus.unauthorized,
      {
        'success': false,
        'error': 'Authentication required.',
      },
    );
  }

  /// Performs `_sendJson` for this feature. Update this documentation when its contract changes.
  Future<void> _sendJson(
    HttpResponse response,
    int statusCode,
    Map<String, dynamic> data,
  ) async {
    response.statusCode = statusCode;

    response.headers.contentType =
        ContentType.json;

    response.write(jsonEncode(data));

    await response.close();
  }

  /// Performs `_addCorsHeaders` for this feature. Update this documentation when its contract changes.
  void _addCorsHeaders(
    HttpResponse response,
  ) {
    response.headers.set(
      'Access-Control-Allow-Origin',
      '*',
    );

    response.headers.set(
      'Access-Control-Allow-Methods',
      'GET, POST, DELETE, OPTIONS',
    );

    response.headers.set(
      'Access-Control-Allow-Headers',
      'Origin, Content-Type, Accept, Authorization',
    );
  }

  /// Performs `_cleanError` for this feature. Update this documentation when its contract changes.
  String _cleanError(Object error) {
    final message = error.toString();

    if (message.startsWith('Exception: ')) {
      return message.substring(11);
    }

    return message;
  }
}
