// Domain API methods extracted from backend_api.dart.
part of '../backend_api.dart';

extension BackendApiGroupMethods on BackendApi {
  // ==========================================================
  // RECOMMENDATIONS
  // ==========================================================

  /// Retrieves personalized recommendations.
  Future<Map<String, dynamic>> getRecommendations({
    String? profileId,
    int limit = 20,
  }) async {
    if (!isAuthenticated) {
      throw BackendApiException(
        'You must be logged in before loading recommendations.',
      );
    }

    final safeLimit = limit.clamp(1, 100);

    final queryParameters = <String, String>{
      'limit': safeLimit.toString(),
    };

    if (profileId != null && profileId.trim().isNotEmpty) {
      queryParameters['profileId'] = profileId.trim();
    }

    final uri = Uri.parse(
      '$baseUrl/recommendations',
    ).replace(
      queryParameters: queryParameters,
    );

    final response = await _networkClient.get(
      uri,
      headers: _headers,
    );

    return _requireSuccess(
      response,
      'Unable to retrieve recommendations.',
    );
  }

  // ==========================================================
  // GROUP RECOMMENDATIONS
  // ==========================================================

  /// Creates a group recommendation.
  Future<Map<String, dynamic>> createGroupRecommendation({
    required String title,
    required String type,
    required String profileId,
    String? mediaId,
    Set<String>? activeParticipants,
    int? votingDurationHours,
  }) async {
    _requireAuthentication();

    final cleanTitle = title.trim();
    final cleanType = type.trim();
    final cleanProfileId = profileId.trim();

    if (cleanTitle.isEmpty) {
      throw BackendApiException(
        'Recommendation title is required.',
      );
    }

    if (cleanType != 'movie' && cleanType != 'tvShow') {
      throw BackendApiException(
        'Recommendation type must be "movie" or "tvShow".',
      );
    }

    if (cleanProfileId.isEmpty) {
      throw BackendApiException(
        'Profile ID is required.',
      );
    }

    String? cleanMediaId = mediaId?.trim();

    if (cleanMediaId != null && cleanMediaId.isEmpty) {
      cleanMediaId = null;
    }

    if (votingDurationHours != null && votingDurationHours <= 0) {
      throw BackendApiException(
        'Voting duration must be greater than zero.',
      );
    }

    final participants = <String>{
      ...?activeParticipants,
      cleanProfileId,
    };

    final body = <String, dynamic>{
      'title': cleanTitle,
      'type': cleanType,
      'profileId': cleanProfileId,
      'activeParticipants': participants.toList(),
    };

    if (cleanMediaId != null) {
      body['mediaId'] = cleanMediaId;
    }

    if (votingDurationHours != null) {
      body['votingDurationHours'] = votingDurationHours;
    }

    final response = await _networkClient.post(
      Uri.parse('$baseUrl/group/recommendations'),
      headers: _headers,
      body: jsonEncode(body),
    );

    return _requireSuccess(
      response,
      'Unable to create group recommendation.',
    );
  }

  /// Retrieves group recommendations.
  Future<Map<String, dynamic>> getGroupRecommendations() async {
    _requireAuthentication();

    final response = await _networkClient.get(
      Uri.parse('$baseUrl/group/recommendations'),
      headers: _headers,
    );

    return _requireSuccess(
      response,
      'Unable to retrieve group recommendations.',
    );
  }

  /// Retrieves one group recommendation.
  Future<Map<String, dynamic>> getGroupRecommendation({
    required String recommendationId,
  }) async {
    _requireAuthentication();

    if (recommendationId.trim().isEmpty) {
      throw BackendApiException(
        'Recommendation ID is required.',
      );
    }

    final response = await _networkClient.get(
      Uri.parse(
        '$baseUrl/group/recommendations/'
        '${Uri.encodeComponent(recommendationId)}',
      ),
      headers: _headers,
    );

    return _requireSuccess(
      response,
      'Unable to retrieve group recommendation.',
    );
  }

  /// Records a yes/no vote on a group recommendation.
  Future<Map<String, dynamic>> voteOnGroupRecommendation({
    required String recommendationId,
    required String profileId,
    required String vote,
  }) async {
    _requireAuthentication();

    if (recommendationId.trim().isEmpty) {
      throw BackendApiException(
        'Recommendation ID is required.',
      );
    }

    if (profileId.trim().isEmpty) {
      throw BackendApiException(
        'Profile ID is required.',
      );
    }

    final cleanVote = vote.trim().toLowerCase();

    if (cleanVote != 'yes' && cleanVote != 'no') {
      throw BackendApiException(
        'Vote must be either "yes" or "no".',
      );
    }

    final response = await _networkClient.post(
      Uri.parse(
        '$baseUrl/group/recommendations/'
        '${Uri.encodeComponent(recommendationId)}/vote',
      ),
      headers: _headers,
      body: jsonEncode({
        'profileId': profileId.trim(),
        'vote': cleanVote,
      }),
    );

    return _requireSuccess(
      response,
      'Unable to submit group recommendation vote.',
    );
  }

  /// Closes group recommendation voting.
  Future<Map<String, dynamic>> closeGroupRecommendationVoting({
    required String recommendationId,
  }) async {
    _requireAuthentication();

    if (recommendationId.trim().isEmpty) {
      throw BackendApiException(
        'Recommendation ID is required.',
      );
    }

    final response = await _networkClient.post(
      Uri.parse(
        '$baseUrl/group/recommendations/'
        '${Uri.encodeComponent(recommendationId)}/close',
      ),
      headers: _headers,
    );

    return _requireSuccess(
      response,
      'Unable to close group recommendation voting.',
    );
  }

  /// Deletes a group recommendation.
  Future<Map<String, dynamic>> deleteGroupRecommendation({
    required String recommendationId,
  }) async {
    _requireAuthentication();

    if (recommendationId.trim().isEmpty) {
      throw BackendApiException(
        'Recommendation ID is required.',
      );
    }

    final response = await _networkClient.delete(
      Uri.parse(
        '$baseUrl/group/recommendations/'
        '${Uri.encodeComponent(recommendationId)}',
      ),
      headers: _headers,
    );

    return _requireSuccess(
      response,
      'Unable to delete group recommendation.',
    );
  }

  // ==========================================================
  // GROUP WISHLIST
  // ==========================================================

  /// Retrieves the Group Wishlist.
  Future<Map<String, dynamic>> getGroupWishlist() async {
    _requireAuthentication();

    final response = await _networkClient.get(
      Uri.parse('$baseUrl/group/wishlist'),
      headers: _headers,
    );

    return _requireSuccess(
      response,
      'Unable to retrieve group wishlist.',
    );
  }

  /// Removes a media item from the Group Wishlist.
  Future<Map<String, dynamic>> removeFromGroupWishlist({
    required String mediaId,
  }) async {
    _requireAuthentication();

    if (mediaId.trim().isEmpty) {
      throw BackendApiException(
        'Media ID is required.',
      );
    }

    final response = await _networkClient.delete(
      Uri.parse(
        '$baseUrl/group/wishlist/'
        '${Uri.encodeComponent(mediaId)}',
      ),
      headers: _headers,
    );

    return _requireSuccess(
      response,
      'Unable to remove media from group wishlist.',
    );
  }

  /// Acquires a Group Wishlist item.
  Future<Map<String, dynamic>> acquireGroupWishlistItem({
    required String mediaId,
    required String profileId,
  }) async {
    _requireAuthentication();

    if (mediaId.trim().isEmpty) {
      throw BackendApiException(
        'Media ID is required.',
      );
    }

    if (profileId.trim().isEmpty) {
      throw BackendApiException(
        'Profile ID is required.',
      );
    }

    final response = await _networkClient.post(
      Uri.parse(
        '$baseUrl/group/wishlist/'
        '${Uri.encodeComponent(mediaId)}/acquire',
      ),
      headers: _headers,
      body: jsonEncode({
        'profileId': profileId.trim(),
      }),
    );

    return _requireSuccess(
      response,
      'Unable to acquire group wishlist item.',
    );
  }

  // ==========================================================
  // GROUP WATCH
  // ==========================================================

  /// Creates a new Group Watch session and sends invitations
  /// to the selected profiles.
  ///
  /// Profiles may belong to different accounts when the backend
  /// confirms that they own the same media.
  Future<Map<String, dynamic>> createGroupWatchSession({
    required String mediaId,
    required String title,
    required String type,
    required String profileId,
    Set<String>? invitedProfileIds,
    int? invitationDurationHours,
  }) async {
    _requireAuthentication();

    final cleanMediaId = mediaId.trim();
    final cleanTitle = title.trim();
    final cleanType = type.trim();
    final cleanProfileId = profileId.trim();

    if (cleanMediaId.isEmpty) {
      throw BackendApiException(
        'Media ID is required.',
      );
    }

    if (cleanTitle.isEmpty) {
      throw BackendApiException(
        'Title is required.',
      );
    }

    if (cleanType != 'movie' && cleanType != 'tvShow') {
      throw BackendApiException(
        'Group Watch type must be "movie" or "tvShow".',
      );
    }

    if (cleanProfileId.isEmpty) {
      throw BackendApiException(
        'Profile ID is required.',
      );
    }

    if (invitationDurationHours != null && invitationDurationHours <= 0) {
      throw BackendApiException(
        'Invitation duration must be greater than zero.',
      );
    }

    final invitedProfiles = <String>{
      ...?invitedProfileIds,
    }
        .map((profile) => profile.trim())
        .where((profile) => profile.isNotEmpty)
        .toSet();

    final body = <String, dynamic>{
      'mediaId': cleanMediaId,
      'title': cleanTitle,
      'type': cleanType,
      'profileId': cleanProfileId,
      'invitedProfileIds': invitedProfiles.toList(),
    };

    if (invitationDurationHours != null) {
      body['invitationDurationHours'] = invitationDurationHours;
    }

    final response = await _networkClient.post(
      Uri.parse('$baseUrl/group/watch'),
      headers: _headers,
      body: jsonEncode(body),
    );

    return _requireSuccess(
      response,
      'Unable to create Group Watch session.',
    );
  }

  /// Retrieves Group Watch sessions.
  Future<Map<String, dynamic>> getGroupWatchSessions() async {
    _requireAuthentication();

    final response = await _networkClient.get(
      Uri.parse('$baseUrl/group/watch'),
      headers: _headers,
    );

    return _requireSuccess(
      response,
      'Unable to retrieve Group Watch sessions.',
    );
  }

  /// Retrieves a Group Watch session.
  Future<Map<String, dynamic>> getGroupWatchSession({
    required String sessionId,
  }) async {
    _requireAuthentication();

    final cleanSessionId = sessionId.trim();

    if (cleanSessionId.isEmpty) {
      throw BackendApiException(
        'Group Watch session ID is required.',
      );
    }

    final response = await _networkClient.get(
      Uri.parse(
        '$baseUrl/group/watch/'
        '${Uri.encodeComponent(cleanSessionId)}',
      ),
      headers: _headers,
    );

    return _requireSuccess(
      response,
      'Unable to retrieve Group Watch session.',
    );
  }

  /// Accepts a Group Watch invitation.
  Future<Map<String, dynamic>> acceptGroupWatchInvitation({
    required String sessionId,
    required String profileId,
  }) async {
    _requireAuthentication();

    final cleanSessionId = sessionId.trim();
    final cleanProfileId = profileId.trim();

    if (cleanSessionId.isEmpty) {
      throw BackendApiException(
        'Group Watch session ID is required.',
      );
    }

    if (cleanProfileId.isEmpty) {
      throw BackendApiException(
        'Profile ID is required.',
      );
    }

    final response = await _networkClient.post(
      Uri.parse(
        '$baseUrl/group/watch/'
        '${Uri.encodeComponent(cleanSessionId)}/accept',
      ),
      headers: _headers,
      body: jsonEncode({
        'profileId': cleanProfileId,
      }),
    );

    return _requireSuccess(
      response,
      'Unable to accept Group Watch invitation.',
    );
  }

  /// Declines a Group Watch invitation.
  Future<Map<String, dynamic>> declineGroupWatchInvitation({
    required String sessionId,
    required String profileId,
  }) async {
    _requireAuthentication();

    final cleanSessionId = sessionId.trim();
    final cleanProfileId = profileId.trim();

    if (cleanSessionId.isEmpty) {
      throw BackendApiException(
        'Group Watch session ID is required.',
      );
    }

    if (cleanProfileId.isEmpty) {
      throw BackendApiException(
        'Profile ID is required.',
      );
    }

    final response = await _networkClient.post(
      Uri.parse(
        '$baseUrl/group/watch/'
        '${Uri.encodeComponent(cleanSessionId)}/decline',
      ),
      headers: _headers,
      body: jsonEncode({
        'profileId': cleanProfileId,
      }),
    );

    return _requireSuccess(
      response,
      'Unable to decline Group Watch invitation.',
    );
  }

  /// Sets the selected Group Watch audio track.
  Future<Map<String, dynamic>> setGroupWatchAudioTrack({
    required String sessionId,
    required String profileId,
    String? audioTrackId,
  }) async {
    _requireAuthentication();

    final cleanSessionId = sessionId.trim();
    final cleanProfileId = profileId.trim();
    final cleanAudioTrackId = audioTrackId?.trim();

    if (cleanSessionId.isEmpty) {
      throw BackendApiException(
        'Group Watch session ID is required.',
      );
    }

    if (cleanProfileId.isEmpty) {
      throw BackendApiException(
        'Profile ID is required.',
      );
    }

    final response = await _networkClient.post(
      Uri.parse(
        '$baseUrl/group/watch/'
        '${Uri.encodeComponent(cleanSessionId)}/audio',
      ),
      headers: _headers,
      body: jsonEncode({
        'profileId': cleanProfileId,
        'audioTrackId':
            cleanAudioTrackId?.isEmpty == true ? null : cleanAudioTrackId,
      }),
    );

    return _requireSuccess(
      response,
      'Unable to set Group Watch audio track.',
    );
  }

  /// Sets the selected Group Watch subtitle track.
  Future<Map<String, dynamic>> setGroupWatchSubtitleTrack({
    required String sessionId,
    required String profileId,
    String? subtitleTrackId,
  }) async {
    _requireAuthentication();

    final cleanSessionId = sessionId.trim();
    final cleanProfileId = profileId.trim();
    final cleanSubtitleTrackId = subtitleTrackId?.trim();

    if (cleanSessionId.isEmpty) {
      throw BackendApiException(
        'Group Watch session ID is required.',
      );
    }

    if (cleanProfileId.isEmpty) {
      throw BackendApiException(
        'Profile ID is required.',
      );
    }

    final response = await _networkClient.post(
      Uri.parse(
        '$baseUrl/group/watch/'
        '${Uri.encodeComponent(cleanSessionId)}/subtitles',
      ),
      headers: _headers,
      body: jsonEncode({
        'profileId': cleanProfileId,
        'subtitleTrackId':
            cleanSubtitleTrackId?.isEmpty == true ? null : cleanSubtitleTrackId,
      }),
    );

    return _requireSuccess(
      response,
      'Unable to set Group Watch subtitle track.',
    );
  }

  /// Starts a Group Watch session.
  Future<Map<String, dynamic>> startGroupWatchSession({
    required String sessionId,
    required String profileId,
  }) async {
    _requireAuthentication();

    final cleanSessionId = sessionId.trim();
    final cleanProfileId = profileId.trim();

    if (cleanSessionId.isEmpty) {
      throw BackendApiException(
        'Group Watch session ID is required.',
      );
    }

    if (cleanProfileId.isEmpty) {
      throw BackendApiException(
        'Profile ID is required.',
      );
    }

    final response = await _networkClient.post(
      Uri.parse(
        '$baseUrl/group/watch/'
        '${Uri.encodeComponent(cleanSessionId)}/start',
      ),
      headers: _headers,
      body: jsonEncode({
        'profileId': cleanProfileId,
      }),
    );

    return _requireSuccess(
      response,
      'Unable to start Group Watch.',
    );
  }

  /// Resumes Group Watch playback.
  Future<Map<String, dynamic>> playGroupWatchSession({
    required String sessionId,
    required String profileId,
  }) async {
    _requireAuthentication();

    final cleanSessionId = sessionId.trim();
    final cleanProfileId = profileId.trim();

    if (cleanSessionId.isEmpty) {
      throw BackendApiException(
        'Group Watch session ID is required.',
      );
    }

    if (cleanProfileId.isEmpty) {
      throw BackendApiException(
        'Profile ID is required.',
      );
    }

    final response = await _networkClient.post(
      Uri.parse(
        '$baseUrl/group/watch/'
        '${Uri.encodeComponent(cleanSessionId)}/play',
      ),
      headers: _headers,
      body: jsonEncode({
        'profileId': cleanProfileId,
      }),
    );

    return _requireSuccess(
      response,
      'Unable to resume Group Watch playback.',
    );
  }

  /// Pauses Group Watch playback.
  Future<Map<String, dynamic>> pauseGroupWatchSession({
    required String sessionId,
    required String profileId,
    required String reason,
  }) async {
    _requireAuthentication();

    final cleanSessionId = sessionId.trim();
    final cleanProfileId = profileId.trim();
    final cleanReason = reason.trim();

    if (cleanSessionId.isEmpty) {
      throw BackendApiException(
        'Group Watch session ID is required.',
      );
    }

    if (cleanProfileId.isEmpty) {
      throw BackendApiException(
        'Profile ID is required.',
      );
    }

    if (cleanReason.isEmpty) {
      throw BackendApiException(
        'Pause reason is required.',
      );
    }

    final response = await _networkClient.post(
      Uri.parse(
        '$baseUrl/group/watch/'
        '${Uri.encodeComponent(cleanSessionId)}/pause',
      ),
      headers: _headers,
      body: jsonEncode({
        'profileId': cleanProfileId,
        'reason': cleanReason,
      }),
    );

    return _requireSuccess(
      response,
      'Unable to pause Group Watch.',
    );
  }

  /// Resumes a paused Group Watch session.
  Future<Map<String, dynamic>> resumeGroupWatchSession({
    required String sessionId,
    required String profileId,
  }) async {
    _requireAuthentication();

    final cleanSessionId = sessionId.trim();
    final cleanProfileId = profileId.trim();

    if (cleanSessionId.isEmpty) {
      throw BackendApiException(
        'Group Watch session ID is required.',
      );
    }

    if (cleanProfileId.isEmpty) {
      throw BackendApiException(
        'Profile ID is required.',
      );
    }

    final response = await _networkClient.post(
      Uri.parse(
        '$baseUrl/group/watch/'
        '${Uri.encodeComponent(cleanSessionId)}/resume',
      ),
      headers: _headers,
      body: jsonEncode({
        'profileId': cleanProfileId,
      }),
    );

    return _requireSuccess(
      response,
      'Unable to resume Group Watch.',
    );
  }

  /// Updates the globally synchronized Group Watch position.
  ///
  /// The backend route expects `positionMilliseconds`.
  /// The Duration is therefore sent directly as milliseconds.
  Future<Map<String, dynamic>> updateGroupWatchPosition({
    required String sessionId,
    required String profileId,
    required Duration position,
  }) async {
    _requireAuthentication();

    final cleanSessionId = sessionId.trim();
    final cleanProfileId = profileId.trim();

    if (cleanSessionId.isEmpty) {
      throw BackendApiException(
        'Group Watch session ID is required.',
      );
    }

    if (cleanProfileId.isEmpty) {
      throw BackendApiException(
        'Profile ID is required.',
      );
    }

    if (position.isNegative) {
      throw BackendApiException(
        'Playback position cannot be negative.',
      );
    }

    final int positionMilliseconds = position.inMilliseconds;

    final response = await _networkClient.post(
      Uri.parse(
        '$baseUrl/group/watch/'
        '${Uri.encodeComponent(cleanSessionId)}/position',
      ),
      headers: _headers,
      body: jsonEncode({
        'profileId': cleanProfileId,
        'positionMilliseconds': positionMilliseconds,
      }),
    );

    return _requireSuccess(
      response,
      'Unable to update Group Watch position.',
    );
  }

  /// Ends a Group Watch session.
  Future<Map<String, dynamic>> endGroupWatchSession({
    required String sessionId,
    required String profileId,
  }) async {
    _requireAuthentication();

    final cleanSessionId = sessionId.trim();
    final cleanProfileId = profileId.trim();

    if (cleanSessionId.isEmpty) {
      throw BackendApiException(
        'Group Watch session ID is required.',
      );
    }

    if (cleanProfileId.isEmpty) {
      throw BackendApiException(
        'Profile ID is required.',
      );
    }

    final response = await _networkClient.post(
      Uri.parse(
        '$baseUrl/group/watch/'
        '${Uri.encodeComponent(cleanSessionId)}/end',
      ),
      headers: _headers,
      body: jsonEncode({
        'profileId': cleanProfileId,
      }),
    );

    return _requireSuccess(
      response,
      'Unable to end Group Watch session.',
    );
  }

  /// Deletes a Group Watch session.
  Future<Map<String, dynamic>> deleteGroupWatchSession({
    required String sessionId,
    required String profileId,
  }) async {
    _requireAuthentication();

    final cleanSessionId = sessionId.trim();
    final cleanProfileId = profileId.trim();

    if (cleanSessionId.isEmpty) {
      throw BackendApiException(
        'Group Watch session ID is required.',
      );
    }

    if (cleanProfileId.isEmpty) {
      throw BackendApiException(
        'Profile ID is required.',
      );
    }

    final response = await _networkClient.delete(
      Uri.parse(
        '$baseUrl/group/watch/'
        '${Uri.encodeComponent(cleanSessionId)}',
      ),
      headers: _headers,
      body: jsonEncode({
        'profileId': cleanProfileId,
      }),
    );

    return _requireSuccess(
      response,
      'Unable to delete Group Watch session.',
    );
  }


}
