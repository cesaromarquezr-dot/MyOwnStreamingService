// FILE: `Backend/routes/arm_routes.dart`.
//
// Purpose: Implements the ARM routes portion of the streaming service.
//
// This file is part of the documented Flutter/home-server architecture.
//
// ARM route responsibilities:
// - authenticate the caller
// - validate HTTP input
// - invoke ArmService
// - serialize ARM/domain models
// - return appropriate HTTP responses
//
// ARM business logic, disc detection, ripping, verification, physical-media
// modeling, recording identity, and persistence belong to the ARM service and
// persistence layers rather than this route class.

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

  Future<void> handle(
    HttpRequest request,
  ) async {
    _addCorsHeaders(request.response);

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
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

      if (request.method == 'POST' &&
          _isCancelPath(path)) {
        await _cancel(request);
        return;
      }

      if (request.method == 'GET' &&
          _isJobPath(path)) {
        await _job(request);
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
    } on FormatException catch (error) {
      await _sendJson(
        request.response,
        HttpStatus.badRequest,
        {
          'success': false,
          'error': _cleanError(error),
        },
      );
    } on ArgumentError catch (error) {
      await _sendJson(
        request.response,
        HttpStatus.badRequest,
        {
          'success': false,
          'error': _cleanError(error),
        },
      );
    } catch (error) {
      await _sendJson(
        request.response,
        _statusCodeForError(error),
        {
          'success': false,
          'error': _cleanError(error),
        },
      );
    }
  }

  Future<void> _status(
    HttpRequest request,
  ) async {
    if (!_authenticate(request)) {
      await _sendUnauthorized(request.response);
      return;
    }

    final connected = await armService.isConnected();

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

  Future<void> _drives(
    HttpRequest request,
  ) async {
    if (!_authenticate(request)) {
      await _sendUnauthorized(request.response);
      return;
    }

    final drives = await armService.findDrives();

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

  Future<void> _scan(
    HttpRequest request,
  ) async {
    if (!_authenticate(request)) {
      await _sendUnauthorized(request.response);
      return;
    }

    final body = await _readJson(request);
    final driveId = _requiredString(
      body,
      'driveId',
    );

    if (driveId == null) {
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

  Future<void> _import(
    HttpRequest request,
  ) async {
    if (!_authenticate(request)) {
      await _sendUnauthorized(request.response);
      return;
    }

    final body = await _readJson(request);

    final driveId = _requiredString(
      body,
      'driveId',
    );

    if (driveId == null) {
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

  Future<void> _job(
    HttpRequest request,
  ) async {
    if (!_authenticate(request)) {
      await _sendUnauthorized(request.response);
      return;
    }

    final jobId = _jobIdFromPath(request.uri.path);

    if (jobId == null) {
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

    final job = await armService.refreshJob(jobId);

    await _sendJson(
      request.response,
      HttpStatus.ok,
      {
        'success': true,
        'job': job.toJson(),
      },
    );
  }

  Future<void> _cancel(
    HttpRequest request,
  ) async {
    if (!_authenticate(request)) {
      await _sendUnauthorized(request.response);
      return;
    }

    final jobId = _cancelJobIdFromPath(
      request.uri.path,
    );

    if (jobId == null) {
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

    final job = await armService.cancelJob(jobId);

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

  bool _authenticate(HttpRequest request) {
    return authentication.authenticate(request) != null;
  }

  Future<Map<String, dynamic>> _readJson(
    HttpRequest request,
  ) async {
    final content =
        await utf8.decoder.bind(request).join();

    if (content.trim().isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(content);

    if (decoded is! Map) {
      throw const FormatException(
        'Request body must be a JSON object.',
      );
    }

    return Map<String, dynamic>.from(decoded);
  }

  String? _requiredString(
    Map<String, dynamic> body,
    String key,
  ) {
    final value = body[key];

    if (value is! String) {
      return null;
    }

    final normalized = value.trim();

    if (normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  bool _isJobPath(String path) {
    const prefix = '/api/v1/arm/jobs/';

    if (!path.startsWith(prefix)) {
      return false;
    }

    final remainder = path.substring(prefix.length);

    if (remainder.isEmpty) {
      return false;
    }

    // A normal job route must contain exactly one job ID.
    return !remainder.contains('/');
  }

  bool _isCancelPath(String path) {
    const prefix = '/api/v1/arm/jobs/';
    const suffix = '/cancel';

    if (!path.startsWith(prefix) ||
        !path.endsWith(suffix)) {
      return false;
    }

    final jobId = path.substring(
      prefix.length,
      path.length - suffix.length,
    );

    return jobId.trim().isNotEmpty &&
        !jobId.contains('/');
  }

  String? _jobIdFromPath(String path) {
    const prefix = '/api/v1/arm/jobs/';

    if (!_isJobPath(path)) {
      return null;
    }

    final jobId = path.substring(prefix.length).trim();

    return jobId.isEmpty ? null : jobId;
  }

  String? _cancelJobIdFromPath(String path) {
    const prefix = '/api/v1/arm/jobs/';
    const suffix = '/cancel';

    if (!_isCancelPath(path)) {
      return null;
    }

    final jobId = path.substring(
      prefix.length,
      path.length - suffix.length,
    ).trim();

    return jobId.isEmpty ? null : jobId;
  }

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

  Future<void> _sendJson(
    HttpResponse response,
    int statusCode,
    Map<String, dynamic> data,
  ) async {
    if (response.headers.contentType == null) {
      response.headers.contentType = ContentType.json;
    }

    response.statusCode = statusCode;
    response.write(jsonEncode(data));
    await response.close();
  }

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

  int _statusCodeForError(Object error) {
    final message = _cleanError(error).toLowerCase();

    if (message.contains('not found') ||
        message.contains('unknown job') ||
        message.contains('unknown drive') ||
        message.contains('does not exist')) {
      return HttpStatus.notFound;
    }

    if (message.contains('already cancelled') ||
        message.contains('already completed') ||
        message.contains('already finished') ||
        message.contains('cannot cancel')) {
      return HttpStatus.conflict;
    }

    if (message.contains('not connected') ||
        message.contains('no drive') ||
        message.contains('drive unavailable') ||
        message.contains('disc unavailable')) {
      return HttpStatus.serviceUnavailable;
    }

    return HttpStatus.internalServerError;
  }

  String _cleanError(Object error) {
    final message = error.toString();

    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length);
    }

    return message;
  }
}