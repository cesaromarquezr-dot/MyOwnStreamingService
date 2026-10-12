import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../models/media_server_agent.dart';

/// Coordinates with the local Media Server Agent.
///
/// The cloud/client layers receive metadata and short-lived HTTPS playback
/// descriptors. NAS credentials and physical paths stay inside the agent.
class MediaServerAgentService {
  final Map<String, MediaServerAgentSnapshot> _snapshots =
      <String, MediaServerAgentSnapshot>{};

  MediaServerAgentSnapshot snapshot(String serverId) {
    final clean = serverId.trim();
    return _snapshots[clean] ??
        MediaServerAgentSnapshot(
          serverId: clean,
          accountId: '',
          agentId: '',
          status: ServerAgentStatus.offline,
          storageStatus: StorageStatus.offline,
        );
  }

  void heartbeat(MediaServerAgentSnapshot value) {
    if (value.serverId.trim().isEmpty || value.agentId.trim().isEmpty) return;
    _snapshots[value.serverId.trim()] = value;
  }

  /// Builds a short-lived signed URL for the TrueNAS media gateway.
  /// The signing secret and private NAS paths never leave the backend.
  Map<String, dynamic> playbackTarget({
    required String serverId,
    required String mediaId,
    String? versionId,
  }) {
    final snapshot = this.snapshot(serverId);
    if (snapshot.status == ServerAgentStatus.offline ||
        snapshot.storageStatus == StorageStatus.offline) {
      throw StateError('Media server agent or storage is offline.');
    }

    final baseUrl = (Platform.environment['MEDIA_AGENT_BASE_URL'] ?? '').trim();
    final secret = (Platform.environment['MEDIA_AGENT_SHARED_SECRET'] ?? '').trim();
    if (baseUrl.isEmpty || secret.length < 32) {
      throw StateError(
        'Media gateway is not configured. Set MEDIA_AGENT_BASE_URL and a '
        'MEDIA_AGENT_SHARED_SECRET of at least 32 characters.',
      );
    }

    final expiresAt = DateTime.now().toUtc().add(const Duration(minutes: 10));
    final expires = expiresAt.millisecondsSinceEpoch ~/ 1000;
    final cleanServerId = serverId.trim();
    final cleanMediaId = mediaId.trim();
    final payload = '$cleanServerId\n$cleanMediaId\n$expires';
    final signature = Hmac(sha256, utf8.encode(secret))
        .convert(utf8.encode(payload))
        .toString();
    final parsedBase = Uri.parse(baseUrl);
    final basePath = parsedBase.path.replaceAll(RegExp(r'/$'), '');
    final uri = parsedBase.replace(
      path: '$basePath/stream',
      queryParameters: {
        'server_id': cleanServerId,
        'media_id': cleanMediaId,
        'exp': '$expires',
        'sig': signature,
      },
    );

    return {
      'serverId': cleanServerId,
      'agentId': snapshot.agentId,
      'mediaId': cleanMediaId,
      if (versionId != null && versionId.trim().isNotEmpty)
        'versionId': versionId,
      'playbackSessionId': signature.substring(0, 24),
      'url': uri.toString(),
      'expiresAt': expiresAt.toIso8601String(),
      'transport': 'https-range',
      'status': 'ready',
    };
  }
}
