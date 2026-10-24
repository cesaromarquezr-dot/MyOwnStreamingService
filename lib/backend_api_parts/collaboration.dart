// Domain API methods extracted from backend_api.dart.
part of '../backend_api.dart';

extension BackendApiCollaborationMethods on BackendApi {
  Future<Map<String, dynamic>> getCollaborativeQueue(
      {required String queueId}) async {
    _requireAuthentication();
    return _requireSuccess(
      await _networkClient.get(
        Uri.parse('$baseUrl/queue/${Uri.encodeComponent(queueId)}'),
        headers: _headers,
      ),
      'Unable to load collaborative queue.',
    );
  }

  Future<Map<String, dynamic>> updateCollaborativeQueueItem({
    required String queueId,
    required String recordKey,
    int? position,
    bool? skipped,
  }) async {
    _requireAuthentication();
    return _requireSuccess(
      await _networkClient.patch(
        Uri.parse(
            '$baseUrl/queue/${Uri.encodeComponent(queueId)}/items/${Uri.encodeComponent(recordKey)}'),
        headers: _headers,
        body: jsonEncode({'position': position, 'skipped': skipped}),
      ),
      'Unable to update collaborative queue item.',
    );
  }

  Future<void> deleteCollaborativeQueueItem(
      {required String queueId, required String recordKey}) async {
    _requireAuthentication();
    await _requireSuccess(
      await _networkClient.delete(
        Uri.parse(
            '$baseUrl/queue/${Uri.encodeComponent(queueId)}/items/${Uri.encodeComponent(recordKey)}'),
        headers: _headers,
      ),
      'Unable to remove collaborative queue item.',
    );
  }

  Future<Map<String, dynamic>> createCollaborativeQueue({
    required String profileId,
    String name = 'Shared Queue',
    String mode = 'party',
  }) async {
    _requireAuthentication();
    return _requireSuccess(
      await _networkClient.post(
        Uri.parse('$baseUrl/queue'),
        headers: _headers,
        body: jsonEncode({
          'profileId': profileId,
          'name': name,
          'mode': mode,
        }),
      ),
      'Unable to create collaborative queue.',
    );
  }

  Future<Map<String, dynamic>> addCollaborativeQueueItem({
    required String queueId,
    required String profileId,
    required String mediaId,
    required String mediaType,
    required String title,
    String? sourceVersionKey,
  }) async {
    _requireAuthentication();
    return _requireSuccess(
      await _networkClient.post(
        Uri.parse('$baseUrl/queue/${Uri.encodeComponent(queueId)}/items'),
        headers: _headers,
        body: jsonEncode({
          'profileId': profileId,
          'mediaId': mediaId,
          'mediaType': mediaType,
          'title': title,
          'sourceVersionKey': sourceVersionKey,
        }),
      ),
      'Unable to add the item to the collaborative queue.',
    );
  }

  Future<Map<String, dynamic>> createShareCard({
    String? profileId,
    required String contentType,
    required String contentId,
    required String title,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    _requireAuthentication();
    return _requireSuccess(
      await _networkClient.post(
        Uri.parse('$baseUrl/share-card'),
        headers: _headers,
        body: jsonEncode({
          'profileId': profileId,
          'contentType': contentType,
          'contentId': contentId,
          'title': title,
          'metadata': metadata,
        }),
      ),
      'Unable to create a share card.',
    );
  }


}
