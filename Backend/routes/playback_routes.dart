// FILE: Backend/routes/playback_routes.dart.
// Purpose: Authenticated playback negotiation and server-side transcoding preparation.
//
// Security notes:
// - Media paths are always treated as relative paths.
// - Canonical filesystem paths are checked to prevent traversal and symlink escapes.
// - Absolute Windows/Unix paths and NUL bytes are rejected.
// - Transcoding output paths are never exposed as absolute filesystem paths.
// - Request bodies are bounded before JSON parsing.
// - Internal exceptions are logged server-side but not returned to clients.

import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import '../middleware/authentication.dart';
import '../models/media_capabilities.dart';
import '../services/media_access_policy.dart';
import '../services/transcoding_service.dart';

class PlaybackRoutes {
  static const String _preparePath = '/api/v1/playback/prepare';
  static const int _maxBodyBytes = 256 * 1024;

  final AuthenticationMiddleware authentication;
  final TranscodingService transcoding;
  final MediaAccessPolicy mediaAccessPolicy;

  PlaybackRoutes({
    required this.authentication,
    required this.transcoding,
    MediaAccessPolicy? mediaAccessPolicy,
  }) : mediaAccessPolicy = mediaAccessPolicy ?? MediaAccessPolicy();

  Future<void> handle(HttpRequest request) async {
    _applyCors(request.response);

    if (request.method == 'OPTIONS') {
      await _close(request.response, 204);
      return;
    }

    final account = authentication.authenticate(request);
    if (account == null) {
      await _json(
        request.response,
        401,
        <String, dynamic>{
          'success': false,
          'error': 'Authentication required.',
        },
      );
      return;
    }

    if (request.method == 'POST' &&
        request.uri.path == _preparePath) {
      await _preparePlayback(request);
      return;
    }

    await _json(
      request.response,
      404,
      <String, dynamic>{
        'success': false,
        'error': 'Playback route not found.',
      },
    );
  }

  Future<void> _preparePlayback(HttpRequest request) async {
    late final Map<String, dynamic> body;

    try {
      body = await _body(request);
    } on FormatException {
      await _json(
        request.response,
        400,
        <String, dynamic>{
          'success': false,
          'error': 'Request body must contain a valid JSON object.',
        },
      );
      return;
    } on _RequestTooLargeException {
      await _json(
        request.response,
        413,
        <String, dynamic>{
          'success': false,
          'error': 'Request body is too large.',
        },
      );
      return;
    } catch (error, stackTrace) {
      developer.log(
        'Playback request body parsing failed.',
        name: 'PlaybackRoutes',
        error: error,
        stackTrace: stackTrace,
      );

      await _json(
        request.response,
        400,
        <String, dynamic>{
          'success': false,
          'error': 'Invalid playback request.',
        },
      );
      return;
    }

    final relative = body['path']?.toString().trim() ?? '';

    if (!_isSafeRelativePath(relative)) {
      await _json(
        request.response,
        400,
        <String, dynamic>{
          'success': false,
          'error': 'A safe relative media path is required.',
        },
      );
      return;
    }

    final root = _mediaRoot();

    final input = await _resolveContainedFile(
      root: root,
      relativePath: relative,
    );

    if (input == null) {
      await _json(
        request.response,
        404,
        <String, dynamic>{
          'success': false,
          'error': 'Media file not found.',
        },
      );
      return;
    }

    final capabilities = _parseCapabilities(body['capabilities']);

    try {
      final probe = await transcoding.analyzer.analyze(input);
      final profile = transcoding.decide(probe, capabilities);

      File? output;

      if (profile.mode != 'directPlay') {
        output = await transcoding.prepare(input, profile);
      }

      final playbackPath = output == null
          ? relative
          : _relativeToCache(output, root);

      await _json(
        request.response,
        200,
        <String, dynamic>{
          'success': true,
          'decision': profile.toJson(),
          'source': probe.toJson(),
          'path': playbackPath,
          'mode': profile.mode,
          'message': output == null
              ? 'Direct playback selected.'
              : 'Compatible playback copy is ready.',
          'mediaAccessPolicy': mediaAccessPolicy.toJson(),
        },
      );
    } catch (error, stackTrace) {
      developer.log(
        'Playback preparation failed.',
        name: 'PlaybackRoutes',
        error: error,
        stackTrace: stackTrace,
      );

      await _json(
        request.response,
        500,
        <String, dynamic>{
          'success': false,
          'error': 'Playback preparation failed.',
        },
      );
    }
  }

  MediaCapabilities _parseCapabilities(Object? value) {
    if (value is! Map) {
      return MediaCapabilities.fromJson(
        const <String, dynamic>{},
      );
    }

    return MediaCapabilities.fromJson(
      Map<String, dynamic>.from(value),
    );
  }

  Directory _mediaRoot() {
    final configured = Platform.environment['MEDIA_ROOT']?.trim();

    final path = configured == null || configured.isEmpty
        ? './media'
        : configured;

    return Directory(path).absolute;
  }

  Future<File?> _resolveContainedFile({
    required Directory root,
    required String relativePath,
  }) async {
    try {
      final rootResolved = await root.resolveSymbolicLinks();

      final candidate = File(
        _joinPath(rootResolved, relativePath),
      );

      if (!candidate.existsSync()) {
        return null;
      }

      final candidateResolved =
          await candidate.resolveSymbolicLinks();

      if (!_isContainedPath(
        rootResolved,
        candidateResolved,
      )) {
        return null;
      }

      final resolvedFile = File(candidateResolved);

      if (!resolvedFile.existsSync()) {
        return null;
      }

      return resolvedFile;
    } on FileSystemException {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  bool _isSafeRelativePath(String value) {
    if (value.isEmpty || value.length > 4096) {
      return false;
    }

    if (value.contains('\u0000')) {
      return false;
    }

    // Normalize URI separators before checking traversal.
    final normalized = value.replaceAll('\\', '/');

    if (normalized.startsWith('/') ||
        normalized.startsWith('\\\\') ||
        normalized.startsWith('//')) {
      return false;
    }

    // Reject Windows drive-qualified paths such as C:/media/file.mkv.
    if (RegExp(r'^[A-Za-z]:').hasMatch(normalized)) {
      return false;
    }

    final segments = normalized.split('/');

    for (final segment in segments) {
      if (segment == '..') {
        return false;
      }
    }

    return true;
  }

  bool _isContainedPath(String rootPath, String candidatePath) {
    final root = _normalizeFilesystemPath(rootPath);
    final candidate = _normalizeFilesystemPath(candidatePath);

    if (candidate == root) {
      return false;
    }

    final prefix = root.endsWith(Platform.pathSeparator)
        ? root
        : '$root${Platform.pathSeparator}';

    return candidate.startsWith(prefix);
  }

  String _normalizeFilesystemPath(String value) {
    var normalized = value;

    while (normalized.endsWith(Platform.pathSeparator) &&
        normalized.length > 1) {
      normalized = normalized.substring(0, normalized.length - 1);
    }

    if (Platform.isWindows) {
      normalized = normalized.toLowerCase();
    }

    return normalized;
  }

  String _joinPath(String root, String relative) {
    final separator = Platform.pathSeparator;

    final normalizedRelative = relative
        .replaceAll('/', separator)
        .replaceAll('\\', separator);

    return '$root$separator$normalizedRelative';
  }

  String _relativeToCache(File output, Directory mediaRoot) {
    final outputPath = output.absolute.path;

    // The transcoding service normally places generated files beneath
    // the media cache. Never expose an absolute filesystem path.
    try {
      final cacheDirectory = Directory(
        _joinPath(mediaRoot.path, 'transcode_cache'),
      );

      final cacheRoot =
          cacheDirectory.resolveSymbolicLinksSync();

      final resolvedOutput =
          output.resolveSymbolicLinksSync();

      if (_isContainedPath(cacheRoot, resolvedOutput)) {
        final relative = resolvedOutput
            .substring(
              cacheRoot.length + Platform.pathSeparator.length,
            )
            .replaceAll('\\', '/');

        if (relative.isNotEmpty && !_isSafeRelativePath(relative)) {
          throw const FileSystemException(
            'Invalid transcoding cache output path.',
          );
        }

        return 'transcode_cache/$relative';
      }
    } catch (error, stackTrace) {
      developer.log(
        'Unable to resolve transcoding cache output path.',
        name: 'PlaybackRoutes',
        error: error,
        stackTrace: stackTrace,
      );
    }

    // Preserve the existing API contract without ever returning an
    // absolute filesystem location.
    final basename = outputPath
        .split(Platform.pathSeparator)
        .last
        .trim();

    if (basename.isEmpty ||
        basename == '.' ||
        basename == '..' ||
        basename.contains('/') ||
        basename.contains('\\') ||
        basename.contains('\u0000')) {
      throw const FileSystemException(
        'Invalid transcoding output filename.',
      );
    }

    return 'transcode_cache/$basename';
  }

  Future<Map<String, dynamic>> _body(HttpRequest request) async {
    final contentLength = request.contentLength;

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
        'Playback request must be a JSON object.',
      );
    }

    return Map<String, dynamic>.from(decoded);
  }

  void _applyCors(HttpResponse response) {
    response.headers
      ..set('Access-Control-Allow-Origin', '*')
      ..set(
        'Access-Control-Allow-Methods',
        'POST, OPTIONS',
      )
      ..set(
        'Access-Control-Allow-Headers',
        'Authorization, Content-Type, Range',
      )
      ..set(
        'Access-Control-Expose-Headers',
        'Content-Type, Content-Length, Content-Range, Accept-Ranges',
      );
  }

  Future<void> _json(
    HttpResponse response,
    int status,
    Map<String, dynamic> body,
  ) async {
    if (response.headers.contentType == null) {
      response.headers.contentType = ContentType.json;
    }

    response.statusCode = status;
    response.headers
      ..set('Cache-Control', 'no-store, no-cache, must-revalidate')
      ..set('Pragma', 'no-cache')
      ..set('X-Content-Type-Options', 'nosniff');

    response.write(jsonEncode(body));
    await response.close();
  }

  Future<void> _close(
    HttpResponse response,
    int status,
  ) async {
    response.statusCode = status;
    response.headers
      ..set('Cache-Control', 'no-store')
      ..set('X-Content-Type-Options', 'nosniff');

    await response.close();
  }
}

class _RequestTooLargeException implements Exception {
  const _RequestTooLargeException();
}