// Domain API methods extracted from backend_api.dart.
part of '../backend_api.dart';

extension BackendApiLibraryMethods on BackendApi {
  // ==========================================================
  // LIBRARY
  // ==========================================================

  /// Removes media from the server's database index.
  Future<Map<String, dynamic>> deleteServerMedia(
    String relativeMediaId,
  ) async {
    _requireAuthentication();

    final response = await http.delete(
      Uri.parse(
        '$baseUrl/library/media/'
        '${Uri.encodeComponent(relativeMediaId)}',
      ),
      headers: _headers,
    );

    return _requireSuccess(
      response,
      'Unable to remove media from the database index.',
    );
  }

  /// Updates metadata for media stored on the home server.
  Future<Map<String, dynamic>> updateServerMediaMetadata({
    required String relativeMediaId,
    String? title,
    int? year,
    String? description,
    String? posterUrl,
    String? trailerUrl,
    Map<String, dynamic>? metadata,
  }) async {
    _requireAuthentication();

    final response = await http.put(
      Uri.parse(
        '$baseUrl/library/media/'
        '${Uri.encodeComponent(relativeMediaId)}',
      ),
      headers: _headers,
      body: jsonEncode({
        'title': title,
        'year': year,
        'description': description,
        'posterUrl': posterUrl,
        'trailerUrl': trailerUrl,
        'metadata': metadata,
      }),
    );

    return _requireSuccess(
      response,
      'Unable to update media metadata.',
    );
  }

  /// Scans the home server's completed media directories.
  Future<Map<String, dynamic>> scanServerLibrary() async {
    _requireAuthentication();

    final response = await http.get(
      Uri.parse('$baseUrl/library/server-scan'),
      headers: _headers,
    );

    return _requireSuccess(
      response,
      'Unable to scan the home server library.',
    );
  }

  /// Persists a reviewed ARM rip in the home server's indexed library.
  /// The backend verifies that the output file exists inside MEDIA_ROOT.
  Future<List<Map<String, dynamic>>> getScheduledLibraryAdditions() async {
    final response = await http.get(Uri.parse('$baseUrl/library/releases'),
        headers: _headers);
    final data = await _requireSuccess(
        response, 'Unable to load scheduled library additions.');
    final raw = data['items'];
    return raw is List
        ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> scheduleLibraryAddition(
      {required String mediaId,
      required String title,
      required String mediaType,
      required DateTime scheduledFor,
      String timeZone = 'UTC'}) async {
    final response = await http.post(Uri.parse('$baseUrl/library/releases'),
        headers: _headers,
        body: jsonEncode({
          'mediaId': mediaId,
          'title': title,
          'mediaType': mediaType,
          'scheduledFor': scheduledFor.toUtc().toIso8601String(),
          'timeZone': timeZone
        }));
    return _requireSuccess(response, 'Unable to schedule library addition.');
  }

  Future<Map<String, dynamic>> publishScheduledLibraryAddition(
      String id) async {
    final r = await http.post(
        Uri.parse('$baseUrl/library/releases/$id/publish'),
        headers: _headers);
    return _requireSuccess(r, 'Unable to publish scheduled library addition.');
  }

  Future<Map<String, dynamic>> cancelScheduledLibraryAddition(String id) async {
    final r = await http.post(Uri.parse('$baseUrl/library/releases/$id/cancel'),
        headers: _headers);
    return _requireSuccess(r, 'Unable to cancel scheduled library addition.');
  }

  Future<Map<String, dynamic>> getPaymentProviderStatus() async {
    final r = await http.get(Uri.parse('$baseUrl/payment/providers'),
        headers: _headers);
    return _requireSuccess(r, 'Unable to load payment providers.');
  }

  Future<Map<String, dynamic>> importApprovedArmMedia({
    required String outputPath,
    required String title,
    required String type,
    int? year,
    String? description,
    String? posterUrl,
    String? trailerUrl,
    required Map<String, dynamic> metadata,
  }) async {
    _requireAuthentication();
    final response = await http
        .post(
          Uri.parse('$baseUrl/library/import-approved'),
          headers: _headers,
          body: jsonEncode({
            'outputPath': outputPath,
            'title': title,
            'type': type,
            'year': year,
            'description': description,
            'posterUrl': posterUrl,
            'trailerUrl': trailerUrl,
            'metadata': metadata,
          }),
        )
        .timeout(const Duration(seconds: 30));
    return _requireSuccess(
      response,
      'Unable to save the approved rip to the home server library.',
    );
  }

  /// Retrieves library privacy settings.
  Future<Map<String, dynamic>> getLibraryPrivacy() async {
    _requireAuthentication();

    final response = await http.get(
      Uri.parse('$baseUrl/library/privacy'),
      headers: _headers,
    );

    return _requireSuccess(
      response,
      'Unable to retrieve library privacy settings.',
    );
  }

  /// Confirms the library ownership declaration.
  Future<Map<String, dynamic>> confirmOwnershipDeclaration() async {
    _requireAuthentication();

    final response = await http
        .post(
          Uri.parse(
            '$baseUrl/library/ownership-declaration',
          ),
          headers: _headers,
          body: jsonEncode({
            'confirmed': true,
          }),
        )
        .timeout(const Duration(seconds: 30));

    return _requireSuccess(
      response,
      'Unable to record the ownership declaration.',
    );
  }

  /// Requests deletion of the home server library.
  Future<Map<String, dynamic>> requestLibraryDeletion() async {
    _requireAuthentication();

    final response = await http.post(
      Uri.parse(
        '$baseUrl/library/deletion-request',
      ),
      headers: _headers,
    );

    return _requireSuccess(
      response,
      'Unable to request library deletion.',
    );
  }

  // ==========================================================
  // PLAYBACK / CODEC NEGOTIATION
  // ==========================================================

  /// Asks the account server to inspect a media file and prepare the best
  /// playback mode for the current device.
  Future<Map<String, dynamic>> preparePlayback({
    required String path,
    Map<String, dynamic>? capabilities,
  }) async {
    _requireAuthentication();
    final response = await http.post(
      Uri.parse('$baseUrl/playback/prepare'),
      headers: _headers,
      body: jsonEncode({
        'path': path,
        'capabilities': capabilities ?? <String, dynamic>{},
      }),
    );
    return _requireSuccess(response, 'Unable to prepare playback.');
  }

  /// Returns conservative capabilities for the Flutter player. The server
  /// remains the authority and can choose a safer transcode when uncertain.
  Map<String, dynamic> playbackCapabilities() => {
        'videoCodecs': <String>['h264'],
        'audioCodecs': <String>['aac', 'mp3'],
        'containers': <String>['mp4'],
        'maxWidth': 3840,
        'maxHeight': 2160,
        'hdr': false,
      };

  /// Builds an authenticated URL for the server's direct/remuxed/transcoded
  /// media stream. The bearer token is supplied by the player as a header.
  Uri playbackUri(String relativePath) => Uri.parse(
        '$baseUrl/library/stream?path=${Uri.encodeQueryComponent(relativePath)}',
      );

  // ==========================================================
  // STORAGE
  // ==========================================================

  /// Retrieves the account's storage information.
  Future<Map<String, dynamic>> getStorage() async {
    _requireAuthentication();

    final response = await http.get(
      Uri.parse('$baseUrl/storage'),
      headers: _headers,
    );

    return _requireSuccess(
      response,
      'Unable to retrieve storage.',
    );
  }

  /// Requests a specific amount of additional physical server storage.
  Future<Map<String, dynamic>> requestMoreStorage({
    int additionalTerabytes = 1,
  }) async {
    _requireAuthentication();

    final response = await http.post(
      Uri.parse('$baseUrl/storage/request'),
      headers: _headers,
      body: jsonEncode({
        'additionalTerabytes': additionalTerabytes,
      }),
    );

    return _requireSuccess(
      response,
      'Unable to request more storage.',
    );
  }

  /// Retrieves in-app storage notifications.
  Future<Map<String, dynamic>> getStorageNotifications() async {
    _requireAuthentication();

    final response = await http.get(
      Uri.parse('$baseUrl/storage/notifications'),
      headers: _headers,
    );

    return _requireSuccess(
      response,
      'Unable to retrieve notifications.',
    );
  }

  // ==========================================================
  // SUPABASE SYNCHRONIZATION
  // ==========================================================

  /// Uploads sanitized Flutter account metadata through the
  /// authenticated backend into Supabase.
  ///
  /// Physical media files are never included.
  Future<Map<String, dynamic>> syncProfileCustomizationToSupabase({
    required String profileId,
    Map<String, dynamic>? home,
    Map<String, dynamic>? details,
    Map<String, dynamic>? platform,
    Map<String, dynamic>? music,
  }) async {
    _requireAuthentication();

    final response = await http.post(
      Uri.parse(
        '$baseUrl/supabase/sync/profile/'
        '${Uri.encodeComponent(profileId)}',
      ),
      headers: _headers,
      body: jsonEncode({
        'home': home ?? <String, dynamic>{},
        'details': details ?? <String, dynamic>{},
        'platform': platform ?? <String, dynamic>{},
        'music': music ?? <String, dynamic>{},
      }),
    );

    return _requireSuccess(
      response,
      'Unable to synchronize profile customization.',
    );
  }

  /// Synchronizes sanitized account metadata with Supabase.
  Future<Map<String, dynamic>> syncAccountToSupabase({
    required Map<String, dynamic> snapshot,
  }) async {
    _requireAuthentication();

    final response = await http.post(
      Uri.parse('$baseUrl/supabase/sync/account'),
      headers: _headers,
      body: jsonEncode(snapshot),
    );

    return _requireSuccess(
      response,
      'Unable to synchronize account data with Supabase.',
    );
  }


}
