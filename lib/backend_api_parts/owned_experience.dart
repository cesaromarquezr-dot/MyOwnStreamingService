// Authenticated APIs for the owner's private Store, Kiosk, Theater and disc UI.
part of '../backend_api.dart';

extension BackendApiOwnedExperienceMethods on BackendApi {
  Future<List<Map<String, dynamic>>> getOwnedCollections({String profileId = ''}) async {
    _requireAuthentication();
    final endpoint = Uri.parse('$baseUrl/collections').replace(queryParameters: {'profileId': profileId});
    final data = await _requireSuccess(await _networkClient.get(endpoint, headers: _headers), 'Unable to load disc collections.');
    return _maps(data['records']);
  }

  Future<Map<String, dynamic>> saveOwnedCollection({required String profileId, required Map<String, dynamic> collection}) async {
    _requireAuthentication();
    final data = await _requireSuccess(await _networkClient.post(Uri.parse('$baseUrl/collections'), headers: _headers, body: jsonEncode({'profileId': profileId, 'data': collection})), 'Unable to save this collection.');
    return _map(data['record']);
  }

  Future<void> deleteOwnedCollection({required String profileId, required String collectionId}) async {
    _requireAuthentication();
    final endpoint = Uri.parse('$baseUrl/collections/${Uri.encodeComponent(collectionId)}').replace(queryParameters: {'profileId': profileId});
    await _requireSuccess(await _networkClient.delete(endpoint, headers: _headers), 'Unable to remove this collection.');
  }

  Future<List<Map<String, dynamic>>> getTheaterSessions({String profileId = ''}) async {
    _requireAuthentication();
    final endpoint = Uri.parse('$baseUrl/theater/sessions').replace(queryParameters: {'profileId': profileId});
    final data = await _requireSuccess(await _networkClient.get(endpoint, headers: _headers), 'Unable to load private theater sessions.');
    return _maps(data['records']);
  }

  Future<Map<String, dynamic>> createTheaterSession({required String profileId, required String mediaId, required String title, List<String> seatIds = const [], String roomId = 'main-room'}) async {
    _requireAuthentication();
    final data = await _requireSuccess(await _networkClient.post(Uri.parse('$baseUrl/theater/sessions'), headers: _headers, body: jsonEncode({'profileId': profileId, 'data': {'mediaId': mediaId, 'title': title, 'seatIds': seatIds, 'roomId': roomId, 'status': 'ready'}})), 'Unable to create a private theater session.');
    return _map(data['record']);
  }

  Future<List<Map<String, dynamic>>> getKioskSessions({String profileId = ''}) async {
    _requireAuthentication();
    final endpoint = Uri.parse('$baseUrl/kiosk/sessions').replace(queryParameters: {'profileId': profileId});
    final data = await _requireSuccess(await _networkClient.get(endpoint, headers: _headers), 'Unable to load kiosk sessions.');
    return _maps(data['records']);
  }

  Future<Map<String, dynamic>> createKioskSession({required String profileId, required String mediaId, String mode = 'play'}) async {
    _requireAuthentication();
    final data = await _requireSuccess(await _networkClient.post(Uri.parse('$baseUrl/kiosk/sessions'), headers: _headers, body: jsonEncode({'profileId': profileId, 'data': {'mediaId': mediaId, 'mode': mode}})), 'Unable to record this kiosk session.');
    return _map(data['record']);
  }

  Future<Map<String, dynamic>?> getMediaExperienceProgress({required String profileId, required String mediaId}) async {
    _requireAuthentication();
    final endpoint = Uri.parse('$baseUrl/media-experience/progress/${Uri.encodeComponent(mediaId)}').replace(queryParameters: {'profileId': profileId});
    final data = await _requireSuccess(await _networkClient.get(endpoint, headers: _headers), 'Unable to load media progress.');
    return data['record'] is Map ? _map(data['record']) : null;
  }

  Future<Map<String, dynamic>> saveMediaExperienceProgress({required String profileId, required String mediaId, required int positionSeconds, String? audioTrack, String? subtitleTrack, String? lastSceneId}) async {
    _requireAuthentication();
    final endpoint = Uri.parse('$baseUrl/media-experience/progress/${Uri.encodeComponent(mediaId)}');
    final data = await _requireSuccess(await _networkClient.put(endpoint, headers: _headers, body: jsonEncode({'profileId': profileId, 'data': {'mediaId': mediaId, 'positionSeconds': positionSeconds < 0 ? 0 : positionSeconds, 'selectedAudioTrack': audioTrack, 'selectedSubtitleTrack': subtitleTrack, 'lastSceneId': lastSceneId}})), 'Unable to save media progress.');
    return _map(data['record']);
  }

  List<Map<String, dynamic>> _maps(Object? value) => value is List ? value.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList(growable: false) : const [];
  Map<String, dynamic> _map(Object? value) => value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
}
