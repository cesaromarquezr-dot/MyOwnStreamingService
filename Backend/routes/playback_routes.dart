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
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../services/adaptive_packaging_service.dart';

import '../middleware/authentication.dart';
import '../models/media_capabilities.dart';
import '../services/media_access_policy.dart';
import '../services/transcoding_service.dart';

class PlaybackRoutes {
  static const String _preparePath = '/api/v1/playback/prepare';
  static const int _maxBodyBytes = 256 * 1024;
  static const String _adaptivePrefix = '/api/v1/playback/adaptive/';
  final Random _secureRandom = Random.secure();
  final Map<String, _AdaptivePlaybackSession> _adaptiveSessions = {};

  final AuthenticationMiddleware authentication;
  final TranscodingService transcoding;
  final MediaAccessPolicy mediaAccessPolicy;
  final AdaptivePackagingService adaptivePackaging;

  PlaybackRoutes({
    required this.authentication,
    required this.transcoding,
    MediaAccessPolicy? mediaAccessPolicy,
    AdaptivePackagingService? adaptivePackaging,
  })  : mediaAccessPolicy = mediaAccessPolicy ?? MediaAccessPolicy(),
        adaptivePackaging = adaptivePackaging ?? const AdaptivePackagingService();

  Future<void> handle(HttpRequest request) async {
    _applyCors(request.response);

    if (request.method == 'OPTIONS') {
      await _close(request.response, 204);
      return;
    }

    // Adaptive package assets use random, short-lived capability URLs so
    // native HLS/DASH players can fetch every manifest/segment without needing
    // to forward Authorization headers on nested playlist requests.
    if (request.method == 'GET' &&
        request.uri.path.startsWith(_adaptivePrefix)) {
      await _serveAdaptiveAsset(request);
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

    if (request.method == 'POST' && request.uri.path == _preparePath) {
      await _preparePlayback(request);
      return;
    }
    if (request.method == 'POST' && request.uri.path == '/api/v1/playback/adaptive') {
      await _prepareAdaptivePlayback(request, account.id);
      return;
    }
    if (request.method == 'POST' && request.uri.path == '/api/v1/playback/thumbnail') {
      await _generateThumbnail(request);
      return;
    }
    if (request.method == 'GET' && request.uri.path == '/api/v1/playback/capabilities') {
      await _playbackCapabilities(request);
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

  Future<void> _prepareAdaptivePlayback(HttpRequest request, String accountId) async {
    late final Map<String, dynamic> body;
    try {
      body = await _body(request);
    } on FormatException {
      await _json(request.response, 400, {'success': false, 'error': 'Request body must be valid JSON.'});
      return;
    } on _RequestTooLargeException {
      await _json(request.response, 413, {'success': false, 'error': 'Request body is too large.'});
      return;
    }

    final relative = body['path']?.toString().trim() ?? '';
    final format = body['format']?.toString().trim().toLowerCase() ?? 'hls';
    if (!_isSafeRelativePath(relative)) {
      await _json(request.response, 400, {'success': false, 'error': 'A safe relative media path is required.'});
      return;
    }
    if (!const {'hls', 'dash'}.contains(format)) {
      await _json(request.response, 400, {'success': false, 'error': 'format must be hls or dash.'});
      return;
    }

    try {
      final root = _mediaRoot();
      final input = await _resolveContainedFile(root: root, relativePath: relative);
      if (input == null) {
        await _json(request.response, 404, {'success': false, 'error': 'Media file not found.'});
        return;
      }
      final probe = await transcoding.analyzer.analyze(input);
      if (!probe.hasVideo) {
        await _json(request.response, 415, {'success': false, 'error': 'HLS/DASH packaging requires a video track. Audio-only music is not an adaptive video package.'});
        return;
      }
      final stat = await input.stat();
      final cacheKey = adaptivePackaging.cacheKey(
        inputPath: input.path,
        size: stat.size,
        modifiedAt: stat.modified,
        format: format,
      );
      final rootPath = await root.resolveSymbolicLinks();
      final outputDirectory = Directory(_joinPath(_joinPath(rootPath, 'adaptive_cache'), cacheKey));
      final manifest = await adaptivePackaging.prepare(
        input: input,
        outputDirectory: outputDirectory,
        format: format,
        hasAudio: probe.hasAudio,
      );
      final sessionId = _newCapabilityId();
      final expiresAt = DateTime.now().toUtc().add(const Duration(minutes: 60));
      _pruneAdaptiveSessions();
      _adaptiveSessions[sessionId] = _AdaptivePlaybackSession(
        accountId: accountId,
        directory: outputDirectory,
        expiresAt: expiresAt,
        format: format,
      );
      final assetPath = 'playback/adaptive/$sessionId/${manifest.uri.pathSegments.isNotEmpty ? manifest.uri.pathSegments.last : (format == 'hls' ? 'master.m3u8' : 'manifest.mpd')}';
      final cdnBases = _configuredCdnBases();
      await _json(request.response, 200, {
        'success': true,
        'format': format,
        'adaptiveBitrate': true,
        'manifestPath': '/api/v1/$assetPath',
        'expiresAt': expiresAt.toIso8601String(),
        'ttlSeconds': 3600,
        'renditions': const [
          {'height': 480, 'videoBitrateKbps': 800},
          {'height': 720, 'videoBitrateKbps': 1800},
          {'height': 1080, 'videoBitrateKbps': 4000},
        ],
        'cdnBaseUrls': cdnBases,
        'cdnMirrorPaths': cdnBases.map((base) => '$base/$assetPath').toList(),
        'deliveryNotes': [
          'The adaptive package is served from the origin unless a CDN is configured to mirror the package path.',
          'This package is not DRM-encrypted. Use a licensed DRM packaging and license service for protected commercial content.',
        ],
      });
    } catch (error, stackTrace) {
      developer.log('Adaptive playback preparation failed.', name: 'PlaybackRoutes', error: error, stackTrace: stackTrace);
      await _json(request.response, 500, {'success': false, 'error': 'Unable to prepare adaptive playback. Confirm FFmpeg is installed and the media is readable.'});
    }
  }

  Future<void> _serveAdaptiveAsset(HttpRequest request) async {
    _pruneAdaptiveSessions();
    final remainder = request.uri.path.substring(_adaptivePrefix.length);
    final segments = remainder.split('/');
    if (segments.length != 2) {
      await _close(request.response, 404);
      return;
    }
    final capability = segments[0];
    final filename = segments[1];
    if (!RegExp(r'^[A-Za-z0-9_-]{40,64}$').hasMatch(capability) ||
        filename.isEmpty || filename == '.' || filename == '..' ||
        filename.contains('\\') || filename.contains('\u0000') ||
        !RegExp(r'^[A-Za-z0-9_.%$-]+\.(m3u8|mpd|ts|m4s|m4a|mp4|vtt)$', caseSensitive: false).hasMatch(filename)) {
      await _close(request.response, 404);
      return;
    }
    final session = _adaptiveSessions[capability];
    if (session == null || !DateTime.now().toUtc().isBefore(session.expiresAt)) {
      _adaptiveSessions.remove(capability);
      await _close(request.response, 410);
      return;
    }
    final file = File(_joinPath(session.directory.path, Uri.decodeComponent(filename)));
    try {
      final dir = await session.directory.resolveSymbolicLinks();
      final resolved = await file.resolveSymbolicLinks();
      if (!_isContainedPath(dir, resolved) || !await File(resolved).exists()) {
        await _close(request.response, 404);
        return;
      }
      final resolvedFile = File(resolved);
      request.response.headers
        ..set('Cache-Control', 'private, no-store, max-age=0')
        ..set('Pragma', 'no-cache')
        ..set('X-Content-Type-Options', 'nosniff')
        ..set('Access-Control-Allow-Origin', '*')
        ..set('Access-Control-Allow-Methods', 'GET, OPTIONS')
        ..set('Access-Control-Allow-Headers', 'Range, Content-Type, Authorization');
      request.response.statusCode = 200;
      request.response.headers.contentType = _adaptiveContentType(filename);
      request.response.contentLength = await resolvedFile.length();
      await request.response.addStream(resolvedFile.openRead());
      await request.response.close();
    } on FileSystemException {
      await _close(request.response, 404);
    } on FormatException {
      await _close(request.response, 404);
    }
  }

  Future<void> _generateThumbnail(HttpRequest request) async {
    late final Map<String, dynamic> body;
    try {
      body = await _body(request);
    } on FormatException {
      await _json(request.response, 400, {'success': false, 'error': 'Request body must be valid JSON.'});
      return;
    } on _RequestTooLargeException {
      await _json(request.response, 413, {'success': false, 'error': 'Request body is too large.'});
      return;
    }
    final relative = body['path']?.toString().trim() ?? '';
    final rawSeconds = body['seconds'];
    final seconds = rawSeconds is num ? rawSeconds.toDouble() : double.tryParse(rawSeconds?.toString() ?? '') ?? 0;
    if (!_isSafeRelativePath(relative) || !seconds.isFinite || seconds < 0 || seconds > 24 * 60 * 60) {
      await _json(request.response, 400, {'success': false, 'error': 'Provide a safe relative media path and a timestamp between 0 and 86400 seconds.'});
      return;
    }
    try {
      final root = _mediaRoot();
      final input = await _resolveContainedFile(root: root, relativePath: relative);
      if (input == null) {
        await _json(request.response, 404, {'success': false, 'error': 'Media file not found.'});
        return;
      }
      final stat = await input.stat();
      final key = sha256.convert(utf8.encode('${input.path}|${stat.size}|${stat.modified.toUtc().toIso8601String()}|${seconds.toStringAsFixed(2)}|thumb-v1')).toString();
      final cacheRoot = Directory(_joinPath(await root.resolveSymbolicLinks(), 'thumbnail_cache'));
      await cacheRoot.create(recursive: true);
      final output = File(_joinPath(cacheRoot.path, '$key.jpg'));
      if (!await output.exists() || await output.length() < 100) {
        final result = await Process.run('ffmpeg', [
          '-hide_banner', '-nostdin', '-y', '-ss', seconds.toStringAsFixed(2),
          '-i', input.path, '-frames:v', '1', '-vf', r'scale=w=min(640\,iw):h=-2',
          '-q:v', '4', output.path,
        ]).timeout(const Duration(seconds: 90));
        if (result.exitCode != 0 || !await output.exists() || await output.length() < 100) {
          throw StateError('Thumbnail extraction failed.');
        }
      }
      final length = await output.length();
      if (length > 2 * 1024 * 1024) {
        await _json(request.response, 500, {'success': false, 'error': 'Generated thumbnail exceeded the size limit.'});
        return;
      }
      await _json(request.response, 200, {
        'success': true,
        'contentType': 'image/jpeg',
        'seconds': seconds,
        'widthLimit': 640,
        'imageBase64': base64Encode(await output.readAsBytes()),
      });
    } catch (error, stackTrace) {
      developer.log('Smart thumbnail generation failed.', name: 'PlaybackRoutes', error: error, stackTrace: stackTrace);
      await _json(request.response, 500, {'success': false, 'error': 'Unable to generate a thumbnail. Confirm FFmpeg is installed and the source contains video.'});
    }
  }

  Future<void> _playbackCapabilities(HttpRequest request) async {
    bool isHttpsUrl(String value) {
      final uri = Uri.tryParse(value.trim());
      return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
    }
    final widevine = Platform.environment['WIDEVINE_LICENSE_URL']?.trim() ?? '';
    final fairplay = Platform.environment['FAIRPLAY_LICENSE_URL']?.trim() ?? '';
    final playready = Platform.environment['PLAYREADY_LICENSE_URL']?.trim() ?? '';
    await _json(request.response, 200, {
      'success': true,
      'formats': ['hls', 'dash'],
      'adaptiveBitrate': true,
      'multiCdnConfigured': _configuredCdnBases().isNotEmpty,
      'cdnBaseUrls': _configuredCdnBases(),
      'drm': {
        'widevineConfigured': isHttpsUrl(widevine),
        'fairplayConfigured': isHttpsUrl(fairplay),
        'playreadyConfigured': isHttpsUrl(playready),
        'note': 'License URLs alone do not enable DRM. A licensed packager, entitlement checks, license proxy and DRM-capable native playback SDK are also required.',
      },
      'endToEndEncryptedChat': 'Client-side message encryption is available after the social_e2ee.sql migration has been applied and all conversation members have published keys.',
    });
  }

  String _newCapabilityId() {
    final bytes = List<int>.generate(32, (_) => _secureRandom.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  void _pruneAdaptiveSessions() {
    final now = DateTime.now().toUtc();
    _adaptiveSessions.removeWhere((_, value) => !now.isBefore(value.expiresAt));
  }

  List<String> _configuredCdnBases() {
    final configured = Platform.environment['PLAYBACK_CDN_BASE_URLS']?.trim() ?? '';
    if (configured.isEmpty) return const [];
    final values = <String>[];
    for (final item in configured.split(',')) {
      final uri = Uri.tryParse(item.trim());
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) continue;
      final normalized = item.trim().replaceFirst(RegExp(r'/+$'), '');
      if (!values.contains(normalized)) values.add(normalized);
    }
    return values;
  }

  ContentType _adaptiveContentType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.m3u8')) return ContentType('application', 'vnd.apple.mpegurl');
    if (lower.endsWith('.mpd')) return ContentType('application', 'dash+xml');
    if (lower.endsWith('.ts')) return ContentType('video', 'mp2t');
    if (lower.endsWith('.m4s')) return ContentType('video', 'iso.segment');
    if (lower.endsWith('.vtt')) return ContentType('text', 'vtt', charset: 'utf-8');
    if (lower.endsWith('.m4a')) return ContentType('audio', 'mp4');
    return ContentType('video', 'mp4');
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
        'GET, POST, OPTIONS',
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
class _AdaptivePlaybackSession {
  final String accountId;
  final Directory directory;
  final DateTime expiresAt;
  final String format;

  const _AdaptivePlaybackSession({
    required this.accountId,
    required this.directory,
    required this.expiresAt,
    required this.format,
  });
}
