import '../../backend_api.dart';
import '../models/media_stream.dart';
import '../models/server_agent.dart';

class MediaServerApi {
  final BackendApi backendApi;

  const MediaServerApi(this.backendApi);

  Future<ServerAgentSnapshot> getAgentSnapshot({required String serverId}) async {
    final data = await backendApi.getServerAgentStatus(serverId: serverId);
    final raw = data['agent'];
    return ServerAgentSnapshot.fromJson(
      raw is Map ? Map<String, dynamic>.from(raw) : const <String, dynamic>{},
    );
  }

  Future<MediaStreamDescriptor> createPlaybackStream({
    required String serverId,
    required String mediaId,
    String? versionId,
  }) async {
    final data = await backendApi.createMediaPlaybackStream(
      serverId: serverId,
      mediaId: mediaId,
      versionId: versionId,
    );
    return MediaStreamDescriptor.fromJson(data['stream'] is Map
        ? Map<String, dynamic>.from(data['stream'] as Map)
        : data);
  }
}
