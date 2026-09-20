// FILE: Backend/routes/playback_routes.dart.
// Purpose: Authenticated playback negotiation and server-side transcoding preparation.

import 'dart:convert';
import 'dart:io';

import '../middleware/authentication.dart';
import '../models/media_capabilities.dart';
import '../services/media_analyzer_service.dart';
import '../services/media_access_policy.dart';
import '../services/transcoding_service.dart';

class PlaybackRoutes {
  final AuthenticationMiddleware authentication;
  final TranscodingService transcoding;
  final MediaAccessPolicy mediaAccessPolicy;

  PlaybackRoutes({required this.authentication, required this.transcoding, MediaAccessPolicy? mediaAccessPolicy})
      : mediaAccessPolicy = mediaAccessPolicy ?? MediaAccessPolicy();

  Future<void> handle(HttpRequest request) async {
    final account = authentication.authenticate(request);
    if (account == null) return _json(request.response, 401, {'success': false, 'error': 'Authentication required.'});

    if (request.method == 'POST' && request.uri.path == '/api/v1/playback/prepare') {
      final body = await _body(request);
      final relative = body['path']?.toString().trim() ?? '';
      if (relative.isEmpty || relative.contains('..')) {
        return _json(request.response, 400, {'success': false, 'error': 'A safe relative media path is required.'});
      }

      final rootPath = Platform.environment['MEDIA_ROOT']?.trim().isNotEmpty == true
          ? Platform.environment['MEDIA_ROOT']!.trim()
          : './media';
      final root = Directory(rootPath).absolute;
      final input = File('${root.path}${Platform.pathSeparator}$relative').absolute;
      if (!input.path.startsWith(root.path) || !input.existsSync()) {
        return _json(request.response, 404, {'success': false, 'error': 'Media file not found.'});
      }

      try {
        final probe = await transcoding.analyzer.analyze(input);
        final capabilities = MediaCapabilities.fromJson(body['capabilities'] is Map
            ? Map<String, dynamic>.from(body['capabilities'] as Map)
            : const <String, dynamic>{});
        final profile = transcoding.decide(probe, capabilities);
        File? output;
        if (profile.mode != 'directPlay') output = await transcoding.prepare(input, profile);

        final playbackPath = output == null ? relative : '${_relativeToCache(output)}';
        return _json(request.response, 200, {
          'success': true,
          'decision': profile.toJson(),
          'source': probe.toJson(),
          'path': playbackPath,
          'mode': profile.mode,
          'message': output == null ? 'Direct playback selected.' : 'Compatible playback copy is ready.',
          'mediaAccessPolicy': mediaAccessPolicy.toJson(),
        });
      } catch (e) {
        return _json(request.response, 500, {'success': false, 'error': 'Playback preparation failed.', 'details': '$e'});
      }
    }

    return _json(request.response, 404, {'success': false, 'error': 'Playback route not found.'});
  }

  String _relativeToCache(File output) {
    final rootPath = Platform.environment['MEDIA_ROOT']?.trim().isNotEmpty == true
        ? Platform.environment['MEDIA_ROOT']!.trim()
        : './media';
    final cachePath = output.absolute.path;
    // Stream route supports the dedicated cache prefix without exposing an absolute path.
    return 'transcode_cache/${cachePath.split(Platform.pathSeparator).last}';
  }

  Future<Map<String, dynamic>> _body(HttpRequest request) async {
    final text = await utf8.decoder.bind(request).join();
    if (text.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(text);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
  }

  void _json(HttpResponse response, int status, Map<String, dynamic> body) {
    response.statusCode = status;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    response.close();
  }
}
