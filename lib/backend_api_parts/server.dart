// Domain API methods extracted from backend_api.dart.
part of '../backend_api.dart';

extension BackendApiServerMethods on BackendApi {
  // ==========================================================
  // EMAIL / REMOTE ACCESS
  // ==========================================================

  /// Creates a remote access code.
  Future<Map<String, dynamic>> createRemoteAccessCode() async {
    _requireAuthentication();

    final response = await _networkClient.post(
      Uri.parse('$baseUrl/remote/access-code'),
      headers: _headers,
    );

    return _requireSuccess(
      response,
      'Unable to create remote access code.',
    );
  }

  /// Retrieves registered remote computers.
  Future<Map<String, dynamic>> getRemoteWorkers() async {
    _requireAuthentication();

    final response = await _networkClient.get(
      Uri.parse('$baseUrl/remote/workers'),
      headers: _headers,
    );

    return _requireSuccess(
      response,
      'Unable to retrieve remote computers.',
    );
  }

  /// Queues a remote disc import job.
  Future<Map<String, dynamic>> queueRemoteImport({
    required String workerId,
    String driveName = 'Disc reader',
  }) async {
    _requireAuthentication();

    final response = await _networkClient.post(
      Uri.parse('$baseUrl/remote/jobs'),
      headers: _headers,
      body: jsonEncode({
        'workerId': workerId,
        'driveName': driveName,
      }),
    );

    return _requireSuccess(
      response,
      'Unable to queue remote disc import.',
    );
  }

  // ==========================================================
  // ARM
  // ==========================================================

  /// Retrieves the current ARM connection status.
  Future<Map<String, dynamic>> getArmStatus() async {
    _requireAuthentication();

    final response = await _networkClient.get(
      Uri.parse('$baseUrl/arm/status'),
      headers: _headers,
    );

    return _requireSuccess(
      response,
      'Unable to connect to ARM.',
    );
  }

  /// Retrieves the optical/media drives connected to the ARM system.
  ///
  /// The backend returns the drives inside a `drives` list.
  /// If the response does not contain a valid list, an empty
  /// list is returned.
  Future<List<dynamic>> getArmDrives() async {
    _requireAuthentication();

    final response = await _networkClient.get(
      Uri.parse('$baseUrl/arm/drives'),
      headers: _headers,
    );

    final data = await _requireSuccess(
      response,
      'Unable to retrieve ARM drives.',
    );

    final drives = data['drives'];

    if (drives is! List) {
      return <dynamic>[];
    }

    return drives;
  }

  /// Scans a disc in the selected ARM drive.
  Future<Map<String, dynamic>> scanArmDisc({
    required String driveId,
  }) async {
    _requireAuthentication();

    final response = await _networkClient.post(
      Uri.parse('$baseUrl/arm/scan'),
      headers: _headers,
      body: jsonEncode({
        'driveId': driveId,
      }),
    );

    return _requireSuccess(
      response,
      'Unable to scan the ARM disc.',
    );
  }

  /// Starts ARM disc monitoring/import for the selected drive.
  Future<Map<String, dynamic>> startArmImport({
    required String driveId,
  }) async {
    _requireAuthentication();

    final response = await _networkClient.post(
      Uri.parse('$baseUrl/arm/import'),
      headers: _headers,
      body: jsonEncode({
        'driveId': driveId,
      }),
    );

    return _requireSuccess(
      response,
      'Unable to start ARM disc monitoring.',
    );
  }

  /// Retrieves the current status of an ARM import job.
  Future<Map<String, dynamic>> getArmJob({
    required String jobId,
  }) async {
    _requireAuthentication();

    final response = await _networkClient.get(
      Uri.parse(
        '$baseUrl/arm/jobs/${Uri.encodeComponent(jobId)}',
      ),
      headers: _headers,
    );

    return _requireSuccess(
      response,
      'Unable to retrieve ARM job status.',
    );
  }

  /// Cancels an active ARM import job.
  Future<Map<String, dynamic>> cancelArmJob({
    required String jobId,
  }) async {
    _requireAuthentication();

    final response = await _networkClient.post(
      Uri.parse(
        '$baseUrl/arm/jobs/'
        '${Uri.encodeComponent(jobId)}/cancel',
      ),
      headers: _headers,
    );

    return _requireSuccess(
      response,
      'Unable to cancel the ARM import.',
    );
  }

  // ==========================================================
  // PHYSICAL OWNERSHIP
  // ==========================================================

  Future<List<Map<String, dynamic>>> getPhysicalItems() async {
    _requireAuthentication();
    final result = await _requireSuccess(
      await _networkClient.get(
        Uri.parse('$baseUrl/physical-items'),
        headers: _headers,
      ),
      'Unable to load physical media ownership.',
    );
    final rows = result['items'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> addPhysicalItem({
    required String title,
    required String format,
    required DateTime acquiredAt,
    String? region,
    String? edition,
    String? editionId,
    String? physicalReleaseId,
    DateTime? releaseDate,
    String? barcode,
    String? catalogNumber,
    int discCount = 1,
    String? condition,
    String? notes,
    String? artworkUrl,
    List<String> includedExtras = const [],
  }) async {
    _requireAuthentication();
    return _requireSuccess(
      await _networkClient.post(
        Uri.parse('$baseUrl/physical-items'),
        headers: _headers,
        body: jsonEncode({
          'title': title,
          'format': format,
          'acquiredAt': acquiredAt.toUtc().toIso8601String(),
          'region': region,
          'edition': edition,
          'editionId': editionId,
          'physicalReleaseId': physicalReleaseId,
          'releaseDate': releaseDate?.toUtc().toIso8601String(),
          'barcode': barcode,
          'catalogNumber': catalogNumber,
          'discCount': discCount,
          'condition': condition,
          'notes': notes,
          'artworkUrl': artworkUrl,
          'includedExtras': includedExtras,
        }),
      ),
      'Unable to register physical media ownership.',
    );
  }

  Future<Map<String, dynamic>> updatePhysicalOwnershipStatus({
    required String itemId,
    required String status,
    String? note,
  }) async {
    _requireAuthentication();
    return _requireSuccess(
      await _networkClient.post(
        Uri.parse(
          '$baseUrl/physical-items/${Uri.encodeComponent(itemId)}/ownership-status',
        ),
        headers: _headers,
        body: jsonEncode({'status': status, 'note': note}),
      ),
      'Unable to update physical media ownership.',
    );
  }

  // ==========================================================
  // HOME SERVER, MUSIC AND REVIEWS
  // ==========================================================

  /// Reads the home server storage dashboard.
  Future<Map<String, dynamic>> getHomeServerStorage() async {
    _requireAuthentication();

    final response = await _networkClient.get(
      Uri.parse('$baseUrl/server/storage'),
      headers: _headers,
    );

    return _requireSuccess(
      response,
      'Unable to load home server storage.',
    );
  }

  /// Reads the ARM connection and media-root configuration.
  Future<Map<String, dynamic>> getHomeServerArm() async {
    _requireAuthentication();

    final response = await _networkClient.get(
      Uri.parse('$baseUrl/server/arm'),
      headers: _headers,
    );

    return _requireSuccess(
      response,
      'Unable to load ARM server status.',
    );
  }

  /// Loads reviews visible inside the current account.
  Future<Map<String, dynamic>> getReviews(
    String mediaId,
  ) async {
    _requireAuthentication();

    final uri = Uri.parse(
      '$baseUrl/reviews',
    ).replace(
      queryParameters: {
        'mediaId': mediaId,
      },
    );

    return _requireSuccess(
      await _networkClient.get(
        uri,
        headers: _headers,
      ),
      'Unable to load reviews.',
    );
  }

  /// Loads public reviews without exposing email or account identifiers.
  Future<Map<String, dynamic>> getGlobalReviews(
    String mediaId,
  ) async {
    _requireAuthentication();

    final uri = Uri.parse(
      '$baseUrl/reviews/global',
    ).replace(
      queryParameters: {
        'mediaId': mediaId,
      },
    );

    return _requireSuccess(
      await _networkClient.get(
        uri,
        headers: _headers,
      ),
      'Unable to load global reviews.',
    );
  }

  /// Publishes a profile review using a user-selected global pseudonym.
  Future<Map<String, dynamic>> submitReview({
    required String mediaId,
    required String profileId,
    required double score,
    required String label,
    required String text,
    String reviewType = 'written',
    String? videoUrl,
    bool spoiler = false,
  }) async {
    _requireAuthentication();

    final response = await _networkClient.post(
      Uri.parse('$baseUrl/reviews'),
      headers: _headers,
      body: jsonEncode({
        'mediaId': mediaId,
        'profileId': profileId,
        'score': score,
        'label': label,
        'text': text,
        'reviewType': reviewType,
        'videoUrl': videoUrl,
        'spoiler': spoiler,
      }),
    );

    return _requireSuccess(
      response,
      'Unable to submit review.',
    );
  }

  Future<Map<String, dynamic>> publishReview({
    required String reviewId,
    required String mediaId,
    required String profileId,
    required String destination,
    String? destinationId,
    bool spoiler = false,
  }) async {
    _requireAuthentication();
    return _requireSuccess(
      await _networkClient.post(
        Uri.parse('$baseUrl/reviews/publish'),
        headers: _headers,
        body: jsonEncode({
          'reviewId': reviewId,
          'mediaId': mediaId,
          'profileId': profileId,
          'destination': destination,
          'destinationId': destinationId,
          'spoiler': spoiler,
        }),
      ),
      'Unable to publish review.',
    );
  }

  Future<Map<String, dynamic>> getReviewPublications(
      {required String reviewId}) async {
    _requireAuthentication();
    final uri = Uri.parse('$baseUrl/reviews/publications')
        .replace(queryParameters: {'reviewId': reviewId});
    return _requireSuccess(await _networkClient.get(uri, headers: _headers),
        'Unable to load review publications.');
  }

  Future<Map<String, dynamic>> addReviewInteraction({
    required String publicationId,
    required String profileId,
    required String type,
    String body = '',
    String? reaction,
  }) async {
    _requireAuthentication();
    return _requireSuccess(
      await _networkClient.post(
        Uri.parse('$baseUrl/reviews/interactions'),
        headers: _headers,
        body: jsonEncode({
          'publicationId': publicationId,
          'profileId': profileId,
          'type': type,
          'body': body,
          'reaction': reaction,
        }),
      ),
      'Unable to add review interaction.',
    );
  }

  // ==========================================================
  // RATINGS
  // ==========================================================

  /// Loads provider ratings and the current profile's personal rating.
  Future<Map<String, dynamic>> getRatings({
    required String mediaId,
    String? title,
    int? year,
    String mediaType = 'movie',
    String? tmdbId,
    String? imdbId,
    String? musicBrainzId,
    String? profileId,
    bool refresh = false,
  }) async {
    _requireAuthentication();
    final query = <String, String>{
      'mediaId': mediaId,
      if (title != null && title.isNotEmpty) 'title': title,
      if (year != null) 'year': year.toString(),
      'mediaType': mediaType,
      if (tmdbId != null && tmdbId.isNotEmpty) 'tmdbId': tmdbId,
      if (imdbId != null && imdbId.isNotEmpty) 'imdbId': imdbId,
      if (musicBrainzId != null && musicBrainzId.isNotEmpty)
        'musicBrainzId': musicBrainzId,
      if (profileId != null && profileId.isNotEmpty) 'profileId': profileId,
      'refresh': refresh.toString(),
    };
    final uri = Uri.parse('$baseUrl/ratings').replace(queryParameters: query);
    return _requireSuccess(await _networkClient.get(uri, headers: _headers),
        'Unable to load media ratings.');
  }

  /// Saves a profile rating in half-star increments from 0.5 to 5.0.
  Future<Map<String, dynamic>> saveUserRating({
    required String mediaId,
    required String profileId,
    required double stars,
  }) async {
    _requireAuthentication();
    return _requireSuccess(
      await _networkClient.post(
        Uri.parse('$baseUrl/ratings/user'),
        headers: _headers,
        body: jsonEncode(
            {'mediaId': mediaId, 'profileId': profileId, 'stars': stars}),
      ),
      'Unable to save your rating.',
    );
  }

  // ==========================================================
  // WORLDWIDE LOCATION
  // ==========================================================

  Future<Map<String, dynamic>> getPostalCodes(
    String countryCode,
    String city,
  ) async {
    final cleanCountry = countryCode.trim();
    final cleanCity = city.trim();
    if (cleanCountry.isEmpty || cleanCity.isEmpty) {
      throw BackendApiException('Country code and city are required.');
    }
    final uri = Uri.parse('$baseUrl/location/postal-codes').replace(
      queryParameters: {
        'country': cleanCountry,
        'city': cleanCity,
      },
    );
    return _requireSuccess(
      await _networkClient.get(uri, headers: _headers),
      'Unable to retrieve postal codes.',
    );
  }

  Future<List<Map<String, dynamic>>> searchAddressSuggestions(
    String query,
  ) async {
    final cleanQuery = query.trim();
    if (cleanQuery.length < 3) return const [];
    final uri = Uri.parse('$baseUrl/location/address-suggestions').replace(
      queryParameters: {'q': cleanQuery},
    );
    final data = await _requireSuccess(
      await _networkClient.get(uri, headers: _headers),
      'Unable to search addresses.',
    );
    return data['suggestions'] is List
        ? (data['suggestions'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false)
        : const [];
  }

  Future<Map<String, dynamic>> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse('$baseUrl/location/reverse').replace(
      queryParameters: {
        'lat': '$latitude',
        'lon': '$longitude',
      },
    );
    final data = await _requireSuccess(
      await _networkClient.get(uri, headers: _headers),
      'Unable to determine the current location.',
    );
    final location = data['location'];
    if (location is! Map) {
      throw BackendApiException('The location provider returned no address.');
    }
    return Map<String, dynamic>.from(location);
  }


}
