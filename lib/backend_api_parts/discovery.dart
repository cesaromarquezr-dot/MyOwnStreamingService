// Domain API methods extracted from backend_api.dart.
part of '../backend_api.dart';

extension BackendApiDiscoveryMethods on BackendApi {
  // ==========================================================
  // PLATFORM SERVICES
  // ==========================================================

  Future<Map<String, dynamic>> getPlatformFeatureStatus() async {
    _requireAuthentication();
    return _requireSuccess(
      await _networkClient.get(
        Uri.parse('$baseUrl/features/status'),
        headers: _headers,
      ),
      'Unable to load platform feature status.',
    );
  }

  /// Loads canonical seasons scoped to one television production.
  Future<List<Map<String, dynamic>>> getKnowledgeFacts(
      {required String mediaWorkId}) async {
    _requireAuthentication();
    final uri = Uri.parse('$baseUrl/media-intelligence/knowledge')
        .replace(queryParameters: {'mediaWorkId': mediaWorkId});
    final data = await _requireSuccess(
      await _networkClient.get(uri, headers: _headers),
      'Unable to load media knowledge.',
    );
    return data['facts'] is List
        ? (data['facts'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];
  }

  Future<List<Map<String, dynamic>>> getKnowledgeStories(
      {required String mediaWorkId}) async {
    _requireAuthentication();
    final uri = Uri.parse('$baseUrl/media-intelligence/knowledge/stories')
        .replace(queryParameters: {'mediaWorkId': mediaWorkId});
    final data = await _requireSuccess(
      await _networkClient.get(uri, headers: _headers),
      'Unable to load media deep dives.',
    );
    return data['stories'] is List
        ? (data['stories'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];
  }

  Future<List<Map<String, dynamic>>> getMediaSeasons(
      {required String seriesId}) async {
    _requireAuthentication();
    final uri = Uri.parse('$baseUrl/media-intelligence/seasons')
        .replace(queryParameters: {'seriesId': seriesId});
    final data = await _requireSuccess(
      await _networkClient.get(uri, headers: _headers),
      'Unable to load this series seasons.',
    );
    return data['seasons'] is List
        ? (data['seasons'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];
  }

  Future<List<Map<String, dynamic>>> getMediaConnections(
      {required String mediaId}) async {
    _requireAuthentication();
    final uri = Uri.parse('$baseUrl/media-intelligence/connections')
        .replace(queryParameters: {'id': mediaId});
    final data = await _requireSuccess(
      await _networkClient.get(uri, headers: _headers),
      'Unable to load related productions.',
    );
    return data['connections'] is List
        ? (data['connections'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];
  }

  Future<List<Map<String, dynamic>>> getMediaWorks() async {
    _requireAuthentication();
    final data = await _requireSuccess(
      await _networkClient.get(Uri.parse('$baseUrl/media-intelligence/works'),
          headers: _headers),
      'Unable to load related production titles.',
    );
    return data['works'] is List
        ? (data['works'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];
  }

  /// Searches the authenticated global media catalog, not just locally owned files.
  /// Results are metadata records; local membership and playback access are
  /// still resolved by the app's profile-aware library.
  Future<Map<String, dynamic>> searchGlobalMedia(
    String query, {
    int limit = 50,
  }) async {
    _requireAuthentication();
    final clean = query.trim();
    if (clean.isEmpty) return <String, dynamic>{'results': <dynamic>[]};
    final uri = Uri.parse('$baseUrl/search').replace(
      queryParameters: <String, String>{
        'q': clean,
        'limit': '${limit.clamp(1, 100)}',
      },
    );
    return _requireSuccess(
      await _networkClient.get(uri, headers: _headers),
      'Unable to search the global media catalog.',
    );
  }

  Future<List<Map<String, dynamic>>> searchMediaPeople(
      {String query = ''}) async {
    _requireAuthentication();
    final uri = Uri.parse('$baseUrl/media-intelligence/people').replace(
        queryParameters: query.trim().isEmpty ? null : {'q': query.trim()});
    final data = await _requireSuccess(
        await _networkClient.get(uri, headers: _headers), 'Unable to search people.');
    return data['people'] is List
        ? (data['people'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];
  }

  /// Searches verified person-to-character credits in the media intelligence graph.
  /// Returns metadata only; it does not grant playback access to any work.
  Future<List<Map<String, dynamic>>> searchMediaCharacters({
    required String query,
  }) async {
    _requireAuthentication();
    final clean = query.trim();
    if (clean.length < 2) return <Map<String, dynamic>>[];
    final uri = Uri.parse('$baseUrl/media-intelligence/characters')
        .replace(queryParameters: {'q': clean});
    final data = await _requireSuccess(
      await _networkClient.get(uri, headers: _headers),
      'Unable to search character credits.',
    );
    return data['characters'] is List
        ? (data['characters'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> createMediaPerson(
      {required String id, required String name}) async {
    _requireAuthentication();
    return _requireSuccess(
      await _networkClient.post(Uri.parse('$baseUrl/media-intelligence/person'),
          headers: _headers, body: jsonEncode({'id': id, 'name': name})),
      'Unable to create this person.',
    );
  }

  Future<Map<String, dynamic>> getPersonCareerTimeline(
      {required String personId, String? category}) async {
    _requireAuthentication();
    final query = <String, String>{'personId': personId};
    if (category?.trim().isNotEmpty == true && category != 'All') {
      query['category'] = category!.trim();
    }
    final uri = Uri.parse('$baseUrl/media-intelligence/people/timeline')
        .replace(queryParameters: query);
    return _requireSuccess(await _networkClient.get(uri, headers: _headers),
        'Unable to load this career timeline.');
  }

  Future<Map<String, dynamic>> savePersonCareerCredit({
    required String personId,
    required String mediaId,
    required String category,
    String role = '',
    String? characterName,
    String? creditGroup,
    int? startYear,
    int? endYear,
    String? source,
  }) async {
    _requireAuthentication();
    return _requireSuccess(
      await _networkClient.post(Uri.parse('$baseUrl/media-intelligence/person-credit'),
          headers: _headers,
          body: jsonEncode({
            'personId': personId,
            'mediaId': mediaId,
            'category': category,
            'role': role,
            if (characterName != null) 'characterName': characterName,
            if (creditGroup != null) 'creditGroup': creditGroup,
            if (startYear != null) 'startYear': startYear,
            if (endYear != null) 'endYear': endYear,
            if (source != null) 'source': source,
          })),
      'Unable to save this career credit.',
    );
  }

  /// Stores a season under its own series identity.
  Future<Map<String, dynamic>> saveMediaSeason({
    required String seriesId,
    required int seasonNumber,
    String? title,
    int? startYear,
    int? endYear,
    int? episodeCount,
  }) async {
    _requireAuthentication();
    return _requireSuccess(
      await _networkClient.post(
        Uri.parse('$baseUrl/media-intelligence/season'),
        headers: _headers,
        body: jsonEncode({
          'seriesId': seriesId,
          'seasonNumber': seasonNumber,
          if (title?.trim().isNotEmpty == true) 'title': title!.trim(),
          if (startYear != null) 'startYear': startYear,
          if (endYear != null) 'endYear': endYear,
          if (episodeCount != null) 'episodeCount': episodeCount,
        }),
      ),
      'Unable to save this season.',
    );
  }

  Future<List<Map<String, dynamic>>> getAppRecords({
    String? profileId,
    String? recordType,
  }) async {
    _requireAuthentication();
    final query = <String, String>{};
    if (profileId?.trim().isNotEmpty == true) {
      query['profileId'] = profileId!.trim();
    }
    if (recordType?.trim().isNotEmpty == true) {
      query['recordType'] = recordType!.trim();
    }
    final uri = Uri.parse('$baseUrl/records').replace(queryParameters: query);
    final data = await _requireSuccess(
      await _networkClient.get(uri, headers: _headers),
      'Unable to load application records.',
    );
    return (data['records'] is List)
        ? (data['records'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];
  }


}
