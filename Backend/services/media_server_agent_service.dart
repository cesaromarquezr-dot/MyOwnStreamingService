import '../models/media_server_agent.dart';

/// Coordinates with the local Media Server Agent.
///
/// The cloud/client layers receive metadata and short-lived HTTPS playback
/// descriptors. NAS credentials and physical paths stay inside the agent.
class MediaServerAgentService {
  final Map<String, MediaServerAgentSnapshot> _snapshots = <String, MediaServerAgentSnapshot>{};

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

  /// Builds a non-secret playback target. The actual agent implementation may
  /// sign the URL or use a long-lived outbound control channel later.
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

    return {
      'serverId': serverId,
      'agentId': snapshot.agentId,
      'mediaId': mediaId,
      if (versionId != null && versionId.trim().isNotEmpty) 'versionId': versionId,
      'transport': 'https-range',
      'status': 'agent-ready',
    };
  }
}
