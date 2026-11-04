// Domain API methods for profile-scoped Personal Media Intelligence.
part of '../backend_api.dart';

extension BackendApiPersonalExperienceMethods on BackendApi {
  Future<Map<String, dynamic>> getPersonalExperience({required String profileId}) async {
    _requireAuthentication();
    final endpoint = Uri.parse('$baseUrl/experience').replace(
      queryParameters: {'profileId': profileId},
    );
    return _requireSuccess(
      await _networkClient.get(endpoint, headers: _headers),
      'Unable to load your entertainment memory.',
    );
  }

  Future<Map<String, dynamic>> recordMusicExperience({
    required String profileId,
    required String title,
    required String artist,
    String? album,
    String? trackId,
    String? genre,
    String? source,
    String eventType = 'played',
    int durationSeconds = 0,
    String? artworkUrl,
  }) async {
    _requireAuthentication();
    return _requireSuccess(
      await _networkClient.post(
        Uri.parse('$baseUrl/experience/music/events'),
        headers: _headers,
        body: jsonEncode({
          'profileId': profileId,
          'title': title,
          'artist': artist,
          'album': album,
          'trackId': trackId,
          'genre': genre,
          'source': source,
          'eventType': eventType,
          'durationSeconds': durationSeconds,
          'artworkUrl': artworkUrl,
        }),
      ),
      'Unable to save music history.',
    );
  }

  Future<Map<String, dynamic>> getMusicExperienceHistory({
    required String profileId,
    int limit = 100,
  }) async {
    _requireAuthentication();
    final endpoint = Uri.parse('$baseUrl/experience/music/history').replace(
      queryParameters: {'profileId': profileId, 'limit': '$limit'},
    );
    return _requireSuccess(
      await _networkClient.get(endpoint, headers: _headers),
      'Unable to load music history.',
    );
  }

  Future<Map<String, dynamic>> getMusicExperienceStats({
    required String profileId,
    int? year,
    String scope = 'profile',
  }) async {
    _requireAuthentication();
    final query = <String, String>{'profileId': profileId, 'scope': scope};
    if (year != null) query['year'] = '$year';
    final endpoint = Uri.parse('$baseUrl/experience/music/stats').replace(queryParameters: query);
    return _requireSuccess(
      await _networkClient.get(endpoint, headers: _headers),
      'Unable to load music statistics.',
    );
  }

  Future<Map<String, dynamic>> saveEpisodeIdentificationNote({
    required String profileId,
    required String seriesTitle,
    required int seasonNumber,
    required int episodeNumber,
    String? seriesId,
    String? episodeTitle,
    String? officialOverview,
    List<String> openingNotes = const [],
    List<String> tags = const [],
    int durationSeconds = 0,
    String? discLabel,
    String? armTitleId,
    double confidence = 0,
  }) async {
    _requireAuthentication();
    return _requireSuccess(
      await _networkClient.post(
        Uri.parse('$baseUrl/experience/episode-notes'),
        headers: _headers,
        body: jsonEncode({
          'profileId': profileId,
          'seriesId': seriesId,
          'seriesTitle': seriesTitle,
          'seasonNumber': seasonNumber,
          'episodeNumber': episodeNumber,
          'episodeTitle': episodeTitle,
          'officialOverview': officialOverview,
          'openingNotes': openingNotes,
          'tags': tags,
          'durationSeconds': durationSeconds,
          'discLabel': discLabel,
          'armTitleId': armTitleId,
          'confidence': confidence,
        }),
      ),
      'Unable to save the episode identification note.',
    );
  }

  Future<Map<String, dynamic>> saveDiscEpisodeMapping({
    required String profileId,
    required String discFingerprint,
    required String seriesTitle,
    required int seasonNumber,
    String? seriesId,
    String? discLabel,
    List<Map<String, dynamic>> titleMappings = const [],
  }) async {
    _requireAuthentication();
    return _requireSuccess(
      await _networkClient.post(
        Uri.parse('$baseUrl/experience/disc-mappings'),
        headers: _headers,
        body: jsonEncode({
          'profileId': profileId,
          'discFingerprint': discFingerprint,
          'discLabel': discLabel,
          'seriesTitle': seriesTitle,
          'seriesId': seriesId,
          'seasonNumber': seasonNumber,
          'titleMappings': titleMappings,
        }),
      ),
      'Unable to save the disc-to-episode mapping.',
    );
  }

  Future<Map<String, dynamic>> saveConcertTrackingEntry({
    required String profileId,
    required String artist,
    required String eventDate,
    String? city,
    String? venue,
    String? ticketUrl,
    String? id,
  }) async {
    _requireAuthentication();
    return _requireSuccess(
      await _networkClient.post(
        Uri.parse('$baseUrl/experience/concerts'),
        headers: _headers,
        body: jsonEncode({
          'profileId': profileId,
          'artist': artist,
          'eventDate': eventDate,
          'city': city,
          'venue': venue,
          'ticketUrl': ticketUrl,
          'id': id,
          'source': 'manual',
        }),
      ),
      'Unable to save the concert tracker entry.',
    );
  }

  Future<Map<String, dynamic>> savePreservationRecord({
    required String profileId,
    required String title,
    String? id,
    String? mediaType,
    String? source,
    String? status,
    String? verificationStatus,
    String? checksum,
    int fileSizeBytes = 0,
    String? discLabel,
    String? mediaId,
  }) async {
    _requireAuthentication();
    return _requireSuccess(
      await _networkClient.post(
        Uri.parse('$baseUrl/experience/preservation'),
        headers: _headers,
        body: jsonEncode({
          'profileId': profileId,
          'id': id,
          'title': title,
          'mediaType': mediaType,
          'source': source,
          'status': status,
          'verificationStatus': verificationStatus,
          'checksum': checksum,
          'fileSizeBytes': fileSizeBytes,
          'discLabel': discLabel,
          'mediaId': mediaId,
        }),
      ),
      'Unable to save the preservation record.',
    );
  }

  Future<Map<String, dynamic>> getInterfaceExperienceConfig({
    required String profileId,
  }) async {
    _requireAuthentication();
    final endpoint = Uri.parse('$baseUrl/experience/interface-designs')
        .replace(queryParameters: {'profileId': profileId});
    return _requireSuccess(
      await _networkClient.get(endpoint, headers: _headers),
      'Unable to load interface experience designs.',
    );
  }

  Future<Map<String, dynamic>> saveInterfaceExperienceConfig({
    required String profileId,
    required Map<String, dynamic> config,
  }) async {
    _requireAuthentication();
    return _requireSuccess(
      await _networkClient.put(
        Uri.parse('$baseUrl/experience/interface-designs'),
        headers: _headers,
        body: jsonEncode({'profileId': profileId, 'config': config}),
      ),
      'Unable to save interface experience designs.',
    );
  }
}
