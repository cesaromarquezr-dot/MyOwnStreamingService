// Compatibility API for app-owned activity and record synchronization.
// Kept separate from the optional Social Center API so removing social screens
// does not remove the app's core media-action and continuity records.

import 'dart:convert';

import 'backend_api.dart';

extension BackendApiAppRecords on BackendApi {
  Map<String, String> get _appRecordHeaders => <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token!.isNotEmpty)
          'Authorization': 'Bearer $token',
      };

  void _requireAppRecordAuthentication() {
    if (!isAuthenticated) {
      throw BackendApiException(
        'You must be logged in before using this feature.',
      );
    }
  }

  Map<String, dynamic> _decodeAppRecordResponse(
    dynamic response,
    String fallbackError,
  ) {
    Map<String, dynamic> data = <String, dynamic>{};
    final body = response.body.toString();
    if (body.isNotEmpty) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map) {
          data = Map<String, dynamic>.from(decoded);
        } else {
          data = <String, dynamic>{'data': decoded};
        }
      } catch (_) {
        data = <String, dynamic>{'error': body};
      }
    }

    final statusCode = response.statusCode as int? ?? 0;
    if (statusCode < 200 || statusCode >= 300) {
      throw BackendApiException(
        data['error']?.toString() ?? fallbackError,
        statusCode: statusCode > 0 ? statusCode : null,
      );
    }
    return data;
  }

  /// Saves an app-owned record used by continuity, watch order, and X-Ray.
  Future<Map<String, dynamic>> saveAppRecord({
    String? profileId,
    required String recordType,
    required String recordKey,
    Map<String, dynamic> data = const <String, dynamic>{},
  }) async {
    _requireAppRecordAuthentication();
    final response = await BackendApi.sharedNetworkClient.post(
      Uri.parse('$baseUrl/records'),
      headers: _appRecordHeaders,
      body: jsonEncode(<String, dynamic>{
        'profileId': profileId,
        'recordType': recordType,
        'recordKey': recordKey,
        'data': data,
      }),
    );
    return _decodeAppRecordResponse(
      response,
      'Unable to save the application record.',
    );
  }

  /// Records an idempotent media action without duplicating domain state.
  Future<Map<String, dynamic>> recordUniversalMediaAction({
    required String profileId,
    required String action,
    required String contentType,
    required String contentId,
    required String idempotencyKey,
    String? mediaVersionId,
    String? targetId,
  }) async {
    _requireAppRecordAuthentication();
    final response = await BackendApi.sharedNetworkClient.post(
      Uri.parse('$baseUrl/media-action'),
      headers: _appRecordHeaders,
      body: jsonEncode(<String, dynamic>{
        'profileId': profileId,
        'action': action,
        'contentType': contentType,
        'contentId': contentId,
        'idempotencyKey': idempotencyKey,
        'mediaVersionId': mediaVersionId,
        'targetId': targetId,
      }),
    );
    return _decodeAppRecordResponse(
      response,
      'Unable to record the media action.',
    );
  }

  /// Loads activity events for a profile when the activity endpoint is enabled.
  Future<List<Map<String, dynamic>>> getMediaActivity({
    required String profileId,
    int limit = 50,
  }) async {
    _requireAppRecordAuthentication();
    final uri = Uri.parse('$baseUrl/activity').replace(
      queryParameters: <String, String>{
        'profileId': profileId,
        'limit': limit.toString(),
      },
    );
    final response = await BackendApi.sharedNetworkClient.get(
      uri,
      headers: _appRecordHeaders,
    );
    final data = _decodeAppRecordResponse(
      response,
      'Unable to load profile activity.',
    );
    final activities = data['activities'];
    if (activities is! List) return <Map<String, dynamic>>[];
    return activities
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: false);
  }
}
