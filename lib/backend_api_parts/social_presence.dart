// Same-account profile presence used by Kiosk, Theater and Listening Lounge.
part of '../backend_api.dart';

extension BackendApiSocialPresenceMethods on BackendApi {
  Future<List<Map<String, dynamic>>> getSocialAccountProfiles({
    required String profileId,
  }) async {
    _requireAuthentication();
    final endpoint = Uri.parse('$baseUrl/social/account-profiles').replace(
      queryParameters: <String, String>{'profileId': profileId},
    );
    final data = await _requireSuccess(
      await _networkClient.get(endpoint, headers: _headers),
      'Unable to load active profiles in this account.',
    );
    final rows = data['profiles'];
    if (rows is! List) return const <Map<String, dynamic>>[];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  Future<void> setSocialProfilePresence({
    required String profileId,
    required String availability,
    String? activityType,
    String? activityText,
    bool clearActivity = false,
  }) async {
    _requireAuthentication();
    await _requireSuccess(
      await _networkClient.post(
        Uri.parse('$baseUrl/social/presence'),
        headers: _headers,
        body: jsonEncode(<String, dynamic>{
          'profileId': profileId,
          'availability': availability,
          'activityType': activityType,
          'activityText': activityText,
          'clearActivity': clearActivity,
        }),
      ),
      'Unable to update this profile’s presence.',
    );
  }
}
