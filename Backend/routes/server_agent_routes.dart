import 'dart:convert';
import 'dart:io';

import '../middleware/authentication.dart';
import '../services/media_server_agent_service.dart';

/// Client-facing view of the local Media Server Agent. Raw NAS credentials and
/// private filesystem paths are never returned.
class ServerAgentRoutes {
  final AuthenticationMiddleware authentication;
  final MediaServerAgentService service;

  const ServerAgentRoutes({required this.authentication, required this.service});

  Future<void> handle(HttpRequest request) async {
    final principal = authentication.principal(request);
    if (principal == null) return _json(request.response, 401, {'success': false, 'error': 'Authentication required.'});

    final path = request.uri.path;
    const prefix = '/api/v1/server-agent/';

    if (request.method == 'POST' && path == '/api/v1/server-agent/playback') {
      final body = await _readJson(request);
      final mediaId = body['mediaId']?.toString().trim() ?? '';
      final versionId = body['versionId']?.toString().trim();
      final serverId = body['serverId']?.toString().trim() ?? '';
      if (mediaId.isEmpty || serverId.isEmpty) {
        return _json(request.response, 400, {
          'success': false,
          'error': 'mediaId and serverId are required for agent playback.',
        });
      }
      final snapshot = service.snapshot(serverId);
      if (snapshot.agentId.isEmpty || snapshot.accountId != principal.account.id) {
        return _json(request.response, 404, {'success': false, 'error': 'Server agent not found.'});
      }
      try {
        final target = service.playbackTarget(
          serverId: serverId,
          mediaId: mediaId,
          versionId: versionId,
        );
        return _json(request.response, 200, {'success': true, 'stream': target});
      } on StateError catch (error) {
        return _json(request.response, 409, {'success': false, 'error': error.message});
      }
    }

    if (request.method == 'GET' && path.startsWith(prefix) && path.endsWith('/status')) {
      final serverId = Uri.decodeComponent(path.substring(prefix.length, path.length - '/status'.length)).trim();
      if (serverId.isEmpty) return _json(request.response, 400, {'success': false, 'error': 'serverId is required.'});
      final snapshot = service.snapshot(serverId);
      if (snapshot.agentId.isEmpty || snapshot.accountId.isEmpty) {
        return _json(request.response, 404, {'success': false, 'error': 'Server agent not found.'});
      }
      if (snapshot.accountId != principal.account.id) {
        return _json(request.response, 403, {'success': false, 'error': 'This server is not available to the current account.'});
      }
      return _json(request.response, 200, {'success': true, 'agent': snapshot.toJson()});
    }

    return _json(request.response, 404, {'success': false, 'error': 'Server agent route not found.'});
  }

  Future<Map<String, dynamic>> _readJson(HttpRequest request) async {
    final bytes = <int>[];
    await for (final chunk in request) {
      bytes.addAll(chunk);
      if (bytes.length > 128 * 1024) {
        throw const FormatException('Request body is too large.');
      }
    }
    if (bytes.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) throw const FormatException('JSON object required.');
    return Map<String, dynamic>.from(decoded);
  }

  Future<void> _json(HttpResponse response, int status, Map<String, dynamic> body) async {
    response.statusCode = status;
    response.headers.contentType = ContentType.json;
    response.headers.set('Cache-Control', 'no-store');
    response.write(jsonEncode(body));
    await response.close();
  }
}
