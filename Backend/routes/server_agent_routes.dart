import 'dart:convert';
import 'dart:io';

import '../middleware/authentication.dart';
import '../models/media_server_agent.dart';
import '../services/media_server_agent_service.dart';
import '../supabase_store.dart';

/// Client-facing view of the local Media Server Agent. Raw NAS credentials and
/// private filesystem paths are never returned.
class ServerAgentRoutes {
  final AuthenticationMiddleware authentication;
  final MediaServerAgentService service;
  final SupabaseStore store;

  const ServerAgentRoutes({
    required this.authentication,
    required this.service,
    required this.store,
  });

  Future<void> handle(HttpRequest request) async {
    final path = request.uri.path;

    // The trusted TrueNAS agent authenticates heartbeats with a shared secret.
    // Account ownership is resolved server-side from Supabase, never accepted
    // from the request body.
    if (request.method == 'POST' && path == '/api/v1/server-agent/heartbeat') {
      final configuredSecret =
          (Platform.environment['MEDIA_AGENT_SHARED_SECRET'] ?? '').trim();
      final suppliedSecret =
          (request.headers.value('x-media-agent-secret') ?? '').trim();
      if (configuredSecret.length < 32 ||
          !_constantTimeEquals(configuredSecret, suppliedSecret)) {
        return _json(request.response, 401, {
          'success': false,
          'error': 'Invalid media-agent credentials.',
        });
      }
      final body = await _readJson(request);
      final serverId = body['serverId']?.toString().trim() ?? '';
      final agentId = body['agentId']?.toString().trim() ?? '';
      if (serverId.isEmpty || agentId.isEmpty) {
        return _json(request.response, 400, {
          'success': false,
          'error': 'serverId and agentId are required.',
        });
      }
      try {
        final accountId = await store.externalAccountIdForServer(serverId);
        if (accountId == null) {
          return _json(request.response, 404, {
            'success': false,
            'error': 'Server ownership could not be verified.',
          });
        }
        final storageStatus =
            body['storageStatus']?.toString() == 'available'
                ? StorageStatus.available
                : StorageStatus.offline;
        service.heartbeat(MediaServerAgentSnapshot(
          serverId: serverId,
          accountId: accountId,
          agentId: agentId,
          status: storageStatus == StorageStatus.available
              ? ServerAgentStatus.online
              : ServerAgentStatus.degraded,
          storageStatus: storageStatus,
          nasName: body['nasName']?.toString(),
          totalBytes: (body['totalBytes'] as num?)?.toInt() ?? 0,
          freeBytes: (body['freeBytes'] as num?)?.toInt() ?? 0,
          lastHeartbeatAt: DateTime.now().toUtc(),
        ));
        return _json(request.response, 200, {
          'success': true,
          'serverId': serverId,
          'status': storageStatus == StorageStatus.available ? 'online' : 'degraded',
        });
      } catch (_) {
        return _json(request.response, 503, {
          'success': false,
          'error': 'Unable to register media-agent heartbeat.',
        });
      }
    }

    final principal = authentication.principal(request);
    if (principal == null) return _json(request.response, 401, {'success': false, 'error': 'Authentication required.'});

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

  bool _constantTimeEquals(String left, String right) {
    final a = utf8.encode(left);
    final b = utf8.encode(right);
    var difference = a.length ^ b.length;
    final length = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < length; i++) {
      final av = i < a.length ? a[i] : 0;
      final bv = i < b.length ? b[i] : 0;
      difference |= av ^ bv;
    }
    return difference == 0;
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
