// Domain API methods extracted from backend_api.dart.
part of '../backend_api.dart';

extension BackendApiDeviceMethods on BackendApi {
  // ==========================================================
  // SERVER CONTEXT
  // ==========================================================

  Future<Map<String, dynamic>> getServerContext() async {
    final response = await http.get(
      Uri.parse('$baseUrl/platform-servers/context'),
      headers: _headers,
    );
    return _requireSuccess(response, 'Unable to load server context.');
  }

  Future<Map<String, dynamic>> claimServer({required String serverId, required String displayName}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/platform-servers/claim'),
      headers: _headers,
      body: jsonEncode({'serverId': serverId, 'displayName': displayName}),
    );
    return _requireSuccess(response, 'Unable to claim server.');
  }

  Future<Map<String, dynamic>> renameServer({required String displayName}) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/platform-servers/name'),
      headers: _headers,
      body: jsonEncode({'displayName': displayName}),
    );
    return _requireSuccess(response, 'Unable to rename server.');
  }

  // ==========================================================
  // TV CONTROL
  // ==========================================================

  Future<List<Map<String, dynamic>>> getTvPairings() async {
    final response = await http.get(
      Uri.parse('$baseUrl/tv-control/pairings'),
      headers: _headers,
    );
    final data = await _requireSuccess(response, 'Unable to load TV pairings.');
    return data['pairings'] is List
        ? (data['pairings'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> pairTvDevice(
    String code, {
    required String profileId,
    required String phoneDeviceId,
  }) async {
    return pairTv(code: code, phoneDeviceId: phoneDeviceId, profileId: profileId);
  }

  Future<Map<String, dynamic>> createTvPairingCode({required String tvDeviceId, required String tvDeviceName}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/tv-control/pairing-code'),
      headers: _headers,
      body: jsonEncode({'tvDeviceId': tvDeviceId, 'tvDeviceName': tvDeviceName}),
    );
    return _requireSuccess(response, 'Unable to create TV pairing code.');
  }

  Future<Map<String, dynamic>> pairTv({required String code, required String phoneDeviceId, required String profileId}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/tv-control/pair'),
      headers: _headers,
      body: jsonEncode({'code': code, 'phoneDeviceId': phoneDeviceId, 'profileId': profileId}),
    );
    return _requireSuccess(response, 'Unable to pair TV.');
  }

  Future<Map<String, dynamic>> getTvState(String tvDeviceId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/tv-control/state/${Uri.encodeComponent(tvDeviceId)}'),
      headers: _headers,
    );
    final data = await _requireSuccess(response, 'Unable to load TV state.');
    return data['state'] is Map ? Map<String, dynamic>.from(data['state'] as Map) : <String, dynamic>{};
  }

  Future<void> publishTvState({required String tvDeviceId, required Map<String, dynamic> state}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/tv-control/state'),
      headers: _headers,
      body: jsonEncode({'tvDeviceId': tvDeviceId, 'state': state}),
    );
    _requireSuccess(response, 'Unable to publish TV state.');
  }

  Future<void> sendTvCommand({required String tvDeviceId, required String profileId, required Map<String, dynamic> command}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/tv-control/command'),
      headers: _headers,
      body: jsonEncode({'tvDeviceId': tvDeviceId, 'profileId': profileId, 'command': command}),
    );
    _requireSuccess(response, 'Unable to send TV command.');
  }

  Future<List<Map<String, dynamic>>> pollTvCommands(String tvDeviceId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/tv-control/commands/${Uri.encodeComponent(tvDeviceId)}'),
      headers: _headers,
    );
    final data = await _requireSuccess(response, 'Unable to poll TV commands.');
    return data['commands'] is List
        ? (data['commands'] as List).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
        : <Map<String, dynamic>>[];
  }

  // ==========================================================
  // AUTOMATIC TV CHANNEL / CONTENT INTELLIGENCE
  // ==========================================================

  Future<Map<String, dynamic>> getTvChannelCapabilities() async {
    final response = await http.get(
      Uri.parse('$baseUrl/tv-channels/capabilities'),
      headers: _headers,
    );
    return _requireSuccess(response, 'Unable to load TV channel capabilities.');
  }

  Future<List<Map<String, dynamic>>> getTvChannelDefinitions({bool kidsProfile = false}) async {
    final uri = Uri.parse('$baseUrl/tv-channels/definitions').replace(
      queryParameters: {'kids': kidsProfile.toString()},
    );
    final response = await http.get(uri, headers: _headers);
    final data = await _requireSuccess(response, 'Unable to load TV channel definitions.');
    return data['channels'] is List
        ? (data['channels'] as List).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList(growable: false)
        : <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> getTvSeasonalPolicy({bool kidsProfile = false}) async {
    final uri = Uri.parse('$baseUrl/tv-channels/seasonal-policy').replace(
      queryParameters: {'kids': kidsProfile.toString()},
    );
    final response = await http.get(uri, headers: _headers);
    return _requireSuccess(response, 'Unable to load TV seasonal policy.');
  }

  Future<Map<String, dynamic>> classifyTvContent(Map<String, dynamic> media) async {
    final response = await http.post(
      Uri.parse('$baseUrl/tv-channels/classify'),
      headers: _headers,
      body: jsonEncode(media),
    );
    return _requireSuccess(response, 'Unable to classify TV content.');
  }

  // ==========================================================
  // MEDIA DEVICE / PLAYBACK SESSIONS
  // ==========================================================

  Future<Map<String, dynamic>> registerMediaDevice({required String profileId, required String deviceId, required String name, required String type}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/media-intelligence/device'),
      headers: _headers,
      body: jsonEncode({'profileId': profileId, 'id': deviceId, 'name': name, 'type': type}),
    );
    return _requireSuccess(response, 'Unable to register device.');
  }

  Future<Map<String, dynamic>> createPlaybackSession({required String profileId, required String deviceId, String? mediaId, String state = 'idle', double positionSeconds = 0}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/media-intelligence/session'),
      headers: _headers,
      body: jsonEncode({
        'profileId': profileId,
        'deviceId': deviceId,
        if (mediaId != null) 'mediaId': mediaId,
        'state': state,
        'positionSeconds': positionSeconds,
      }),
    );
    return _requireSuccess(response, 'Unable to create playback session.');
  }

  Future<Map<String, dynamic>> updatePlaybackSession({required String sessionId, String? mediaId, String? state, double? positionSeconds}) async {
    final response = await http.put(
      Uri.parse('$baseUrl/media-intelligence/session'),
      headers: _headers,
      body: jsonEncode({
        'id': sessionId,
        if (mediaId != null) 'mediaId': mediaId,
        if (state != null) 'state': state,
        if (positionSeconds != null) 'positionSeconds': positionSeconds,
      }),
    );
    return _requireSuccess(response, 'Unable to update playback session.');
  }


}
