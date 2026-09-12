// FILE: `lib/backend_api.dart`.
// Purpose: Implements the backend api portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'dart:convert';

import 'package:http/http.dart' as http;

class BackendApiException implements Exception {
  final String message;
  final int? statusCode;

  BackendApiException(
    this.message, {
    this.statusCode,
  });

  @override
  /// Performs `toString` for this feature. Update this documentation when its contract changes.
  String toString() {
    if (statusCode != null) {
      return 'BackendApiException ($statusCode): $message';
    }

    return 'BackendApiException: $message';
  }
}

class BackendApi {
  final String baseUrl;

  String? _token;

  BackendApi({
    this.baseUrl = 'http://127.0.0.1:8080/api/v1',
  });

  String? get token => _token;

  bool get isAuthenticated =>
      _token != null && _token!.isNotEmpty;

  /// Performs `setToken` for this feature. Update this documentation when its contract changes.
  void setToken(String token) {
    _token = token;
  }

  /// Performs `clearToken` for this feature. Update this documentation when its contract changes.
  void clearToken() {
    _token = null;
  }

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (isAuthenticated) {
      headers['Authorization'] = 'Bearer $_token';
    }

    return headers;
  }

  Future<Map<String, dynamic>> getLegalPolicies() async {
    final response = await http.get(Uri.parse('$baseUrl/legal/policies'), headers: _headers);
    final data = _decodeResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendApiException(data['error']?.toString() ?? 'Unable to load legal policies.', statusCode: response.statusCode);
    }
    return data;
  }

  Future<Map<String, dynamic>> getLegalAcceptance() async {
    final response = await http.get(Uri.parse('$baseUrl/legal/account-acceptance'), headers: _headers);
    final data = _decodeResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendApiException(data['error']?.toString() ?? 'Unable to load legal acceptance.', statusCode: response.statusCode);
    }
    return data;
  }

  // ==========================================================
  // AUTH
  // ==========================================================

  /// Creates a new account and starts the payment process.
  ///
  /// IMPORTANT:
  ///
  /// Signup does NOT authenticate the user.
  ///
  /// The backend creates the account with an inactive
  /// subscription and returns a payment session.
  Future<Map<String, dynamic>> signup({
    required String email,
    required String password,
    required String firstProfileName,
    required String plan,
    required String securityQuestion,
    required String securityAnswer,
    required String termsVersion,
    required String privacyVersion,
    required String acceptableUseVersion,
  }) async {
    final cleanPlan = plan.trim().toLowerCase();

    if (cleanPlan != 'monthly' && cleanPlan != 'yearly') {
      throw BackendApiException(
        'Subscription plan must be monthly or yearly.',
      );
    }

    clearToken();

    final response = await http.post(
      Uri.parse('$baseUrl/auth/signup'),
      headers: _headers,
      body: jsonEncode({
        'email': email,
        'password': password,
        'firstProfileName': firstProfileName,
        'plan': cleanPlan,
        'securityQuestion': securityQuestion,
        'securityAnswer': securityAnswer,
        'termsVersion': termsVersion,
        'privacyVersion': privacyVersion,
        'acceptableUseVersion': acceptableUseVersion,
        'legalAcceptedAt': DateTime.now().toUtc().toIso8601String(),
      }),
    );

    final data = _decodeResponse(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendApiException(
        data['error']?.toString() ?? 'Unable to create account.',
        statusCode: response.statusCode,
      );
    }

    clearToken();

    final payment = data['payment'];

    if (payment is! Map) {
      throw BackendApiException(
        'Account was created but no payment session was returned.',
        statusCode: response.statusCode,
      );
    }

    final paymentId = payment['id']?.toString();
    final checkoutToken = payment['checkoutToken']?.toString();

    if (paymentId == null || paymentId.isEmpty) {
      throw BackendApiException(
        'Payment session was created but no payment ID was returned.',
        statusCode: response.statusCode,
      );
    }

    if (checkoutToken == null || checkoutToken.isEmpty) {
      throw BackendApiException(
        'Payment session was created but no checkout authorization was returned.',
        statusCode: response.statusCode,
      );
    }

    return data;
  }

  /// Logs into an account.
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: _headers,
      body: jsonEncode({
        'email': email.trim().toLowerCase(),
        'password': password,
      }),
    );

    final data = _decodeResponse(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendApiException(
        data['error']?.toString() ?? 'Unable to log in.',
        statusCode: response.statusCode,
      );
    }

    final token = data['token']?.toString();

    if (token == null || token.isEmpty) {
      throw BackendApiException(
        'Backend login succeeded but no authentication token was returned.',
        statusCode: response.statusCode,
      );
    }

    setToken(token);

    return data;
  }

  Future<Map<String, dynamic>> me() async {
    if (!isAuthenticated) {
      throw BackendApiException(
        'You must be logged in before retrieving your account.',
      );
    }

    final response = await http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: _headers,
    );

    final data = _decodeResponse(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendApiException(
        data['error']?.toString() ?? 'Unable to retrieve account.',
        statusCode: response.statusCode,
      );
    }

    return data;
  }

  /// Performs `logout` for this feature. Update this documentation when its contract changes.
  Future<void> logout() async {
    if (!isAuthenticated) {
      return;
    }

    try {
      await http.post(
        Uri.parse('$baseUrl/auth/logout'),
        headers: _headers,
      );
    } finally {
      clearToken();
    }
  }

  // ==========================================================
  // CROSS-ACCOUNT GROUP CHAT
  // ==========================================================
  Future<Map<String, dynamic>> createGroupChatRoom({required String name, required String profileId, Set<String>? invitedProfiles}) async {
    _requireAuthentication();
    final response = await http.post(Uri.parse('$baseUrl/group/chat'), headers: _headers, body: jsonEncode({'name': name.trim(), 'profileId': profileId.trim(), 'invitedProfiles': (invitedProfiles ?? {}).toList()}));
    return _requireSuccess(response, 'Unable to create group chat room.');
  }

  Future<Map<String, dynamic>> getGroupChatRooms() async {
    _requireAuthentication();
    final response = await http.get(Uri.parse('$baseUrl/group/chat'), headers: _headers);
    return _requireSuccess(response, 'Unable to retrieve group chat rooms.');
  }

  Future<Map<String, dynamic>> getGroupChatRoom(String roomId) async {
    _requireAuthentication();
    final response = await http.get(Uri.parse('$baseUrl/group/chat/${Uri.encodeComponent(roomId)}/messages'), headers: _headers);
    return _requireSuccess(response, 'Unable to retrieve group chat room.');
  }

  Future<Map<String, dynamic>> sendGroupChatMessage({required String roomId, required String profileId, required String message, String? badgeName}) async {
    _requireAuthentication();
    final response = await http.post(Uri.parse('$baseUrl/group/chat/${Uri.encodeComponent(roomId)}/messages'), headers: _headers, body: jsonEncode({'profileId': profileId, 'message': message, 'badgeName': badgeName}));
    return _requireSuccess(response, 'Unable to send group chat message.');
  }

  // ==========================================================
  // PAYMENT
  // ==========================================================

  Future<Map<String, dynamic>> getCheckoutPaymentStatus({
    required String paymentId,
    required String checkoutToken,
  }) async {
    if (paymentId.trim().isEmpty) {
      throw BackendApiException('Payment ID is required.');
    }

    if (checkoutToken.trim().isEmpty) {
      throw BackendApiException(
        'Checkout authorization is required.',
      );
    }

    final uri = Uri.parse(
      '$baseUrl/payment/checkout/status/${Uri.encodeComponent(paymentId)}',
    ).replace(
      queryParameters: {
        'checkoutToken': checkoutToken,
      },
    );

    final response = await http.get(
      uri,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    final data = _decodeResponse(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendApiException(
        data['error']?.toString() ??
            'Unable to retrieve payment status.',
        statusCode: response.statusCode,
      );
    }

    return data;
  }

  Future<Map<String, dynamic>> verifyCheckoutPayment({
    required String paymentId,
    required String checkoutToken,
    required String processorTransactionId,
  }) async {
    if (paymentId.trim().isEmpty) {
      throw BackendApiException('Payment ID is required.');
    }

    if (checkoutToken.trim().isEmpty) {
      throw BackendApiException(
        'Checkout authorization is required.',
      );
    }

    if (processorTransactionId.trim().isEmpty) {
      throw BackendApiException(
        'Payment processor transaction ID is required.',
      );
    }

    final response = await http.post(
      Uri.parse(
        '$baseUrl/payment/checkout/verify/${Uri.encodeComponent(paymentId)}',
      ),
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'checkoutToken': checkoutToken,
        'processorTransactionId': processorTransactionId,
      }),
    );

    final data = _decodeResponse(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendApiException(
        data['error']?.toString() ?? 'Unable to verify payment.',
        statusCode: response.statusCode,
      );
    }

    clearToken();

    return data;
  }

  Future<Map<String, dynamic>> createPayment({
    required String plan,
  }) async {
    if (!isAuthenticated) {
      throw BackendApiException(
        'You must be logged in before creating a payment.',
      );
    }

    final cleanPlan = plan.trim().toLowerCase();

    if (cleanPlan != 'monthly' && cleanPlan != 'yearly') {
      throw BackendApiException(
        'Subscription plan must be monthly or yearly.',
      );
    }

    final response = await http.post(
      Uri.parse('$baseUrl/payment/create'),
      headers: _headers,
      body: jsonEncode({
        'plan': cleanPlan,
      }),
    );

    return _requireSuccess(
      response,
      'Unable to create payment session.',
    );
  }

  Future<Map<String, dynamic>> getPaymentStatus({
    required String paymentId,
  }) async {
    if (!isAuthenticated) {
      throw BackendApiException(
        'You must be logged in before checking payment status.',
      );
    }

    if (paymentId.trim().isEmpty) {
      throw BackendApiException('Payment ID is required.');
    }

    final response = await http.get(
      Uri.parse(
        '$baseUrl/payment/status/${Uri.encodeComponent(paymentId)}',
      ),
      headers: _headers,
    );

    return _requireSuccess(
      response,
      'Unable to retrieve payment status.',
    );
  }

  Future<Map<String, dynamic>> verifyPayment({
    required String paymentId,
    required String processorTransactionId,
  }) async {
    if (!isAuthenticated) {
      throw BackendApiException(
        'You must be logged in before verifying a payment.',
      );
    }

    if (paymentId.trim().isEmpty) {
      throw BackendApiException('Payment ID is required.');
    }

    if (processorTransactionId.trim().isEmpty) {
      throw BackendApiException(
        'Payment processor transaction ID is required.',
      );
    }

    final response = await http.post(
      Uri.parse(
        '$baseUrl/payment/verify/${Uri.encodeComponent(paymentId)}',
      ),
      headers: _headers,
      body: jsonEncode({
        'processorTransactionId': processorTransactionId,
      }),
    );

    return _requireSuccess(
      response,
      'Unable to verify payment.',
    );
  }

  Future<Map<String, dynamic>> cancelPayment({
    required String paymentId,
  }) async {
    if (!isAuthenticated) {
      throw BackendApiException(
        'You must be logged in before cancelling a payment.',
      );
    }

    if (paymentId.trim().isEmpty) {
      throw BackendApiException('Payment ID is required.');
    }

    final response = await http.post(
      Uri.parse(
        '$baseUrl/payment/cancel/${Uri.encodeComponent(paymentId)}',
      ),
      headers: _headers,
    );

    return _requireSuccess(
      response,
      'Unable to cancel payment.',
    );
  }

  Future<Map<String, dynamic>> addProfile({required String name, String? avatarUrl}) async {
    _requireAuthentication();
    final response = await http.post(Uri.parse('$baseUrl/profiles'), headers: _headers, body: jsonEncode({'name': name.trim(), 'avatarUrl': avatarUrl}));
    return _requireSuccess(response, 'Unable to create profile.');
  }


  Future<Map<String, dynamic>> removeProfile(String profileId) async {
    _requireAuthentication();
    final response = await http.delete(Uri.parse('$baseUrl/profiles/${Uri.encodeComponent(profileId)}'), headers: _headers);
    return _requireSuccess(response, 'Unable to delete profile.');
  }

  Future<Map<String, dynamic>> deleteAccount() async {
    _requireAuthentication();
    final response = await http.delete(Uri.parse('$baseUrl/auth/account'), headers: _headers);
    final data = _requireSuccess(response, 'Unable to delete account.');
    clearToken();
    return data;
  }


  /// Scans the home server's completed media directories.
  Future<Map<String, dynamic>> scanServerLibrary() async {
    _requireAuthentication();
    final response = await http.get(Uri.parse('$baseUrl/library/server-scan'), headers: _headers);
    return _requireSuccess(response, 'Unable to scan the home server library.');
  }

  Future<Map<String, dynamic>> getLibraryPrivacy() async {
    _requireAuthentication();
    final response = await http.get(
      Uri.parse('$baseUrl/library/privacy'),
      headers: _headers,
    );
    return _requireSuccess(response, 'Unable to retrieve library privacy settings.');
  }

  Future<Map<String, dynamic>> confirmOwnershipDeclaration() async {
    _requireAuthentication();
    final response = await http.post(
      Uri.parse('$baseUrl/library/ownership-declaration'),
      headers: _headers,
      body: jsonEncode({'confirmed': true}),
    );
    return _requireSuccess(response, 'Unable to record the ownership declaration.');
  }

  Future<Map<String, dynamic>> requestLibraryDeletion() async {
    _requireAuthentication();
    final response = await http.post(
      Uri.parse('$baseUrl/library/deletion-request'),
      headers: _headers,
    );
    return _requireSuccess(response, 'Unable to request library deletion.');
  }

  Future<Map<String, dynamic>> getStorage() async {
    _requireAuthentication();
    final response = await http.get(Uri.parse('$baseUrl/storage'), headers: _headers);
    return _requireSuccess(response, 'Unable to retrieve storage.');
  }

  Future<Map<String, dynamic>> requestMoreStorage() async {
    _requireAuthentication();
    final response = await http.post(Uri.parse('$baseUrl/storage/request'), headers: _headers);
    return _requireSuccess(response, 'Unable to request more storage.');
  }

  // ==========================================================
  // RECOMMENDATIONS
  // ==========================================================

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

    final response = await http.get(
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
      throw BackendApiException('Profile ID is required.');
    }

    String? cleanMediaId = mediaId?.trim();

    if (cleanMediaId != null && cleanMediaId.isEmpty) {
      cleanMediaId = null;
    }

    if (votingDurationHours != null &&
        votingDurationHours <= 0) {
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

    final response = await http.post(
      Uri.parse('$baseUrl/group/recommendations'),
      headers: _headers,
      body: jsonEncode(body),
    );

    return _requireSuccess(
      response,
      'Unable to create group recommendation.',
    );
  }

  Future<Map<String, dynamic>> getGroupRecommendations() async {
    _requireAuthentication();

    final response = await http.get(
      Uri.parse('$baseUrl/group/recommendations'),
      headers: _headers,
    );

    return _requireSuccess(
      response,
      'Unable to retrieve group recommendations.',
    );
  }

  Future<Map<String, dynamic>> getGroupRecommendation({
    required String recommendationId,
  }) async {
    _requireAuthentication();

    if (recommendationId.trim().isEmpty) {
      throw BackendApiException(
        'Recommendation ID is required.',
      );
    }

    final response = await http.get(
      Uri.parse(
        '$baseUrl/group/recommendations/${Uri.encodeComponent(recommendationId)}',
      ),
      headers: _headers,
    );

    return _requireSuccess(
      response,
      'Unable to retrieve group recommendation.',
    );
  }

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

    final response = await http.post(
      Uri.parse(
        '$baseUrl/group/recommendations/${Uri.encodeComponent(recommendationId)}/vote',
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

  Future<Map<String, dynamic>> closeGroupRecommendationVoting({
    required String recommendationId,
  }) async {
    _requireAuthentication();

    if (recommendationId.trim().isEmpty) {
      throw BackendApiException(
        'Recommendation ID is required.',
      );
    }

    final response = await http.post(
      Uri.parse(
        '$baseUrl/group/recommendations/${Uri.encodeComponent(recommendationId)}/close',
      ),
      headers: _headers,
    );

    return _requireSuccess(
      response,
      'Unable to close group recommendation voting.',
    );
  }

  Future<Map<String, dynamic>> deleteGroupRecommendation({
    required String recommendationId,
  }) async {
    _requireAuthentication();

    if (recommendationId.trim().isEmpty) {
      throw BackendApiException(
        'Recommendation ID is required.',
      );
    }

    final response = await http.delete(
      Uri.parse(
        '$baseUrl/group/recommendations/${Uri.encodeComponent(recommendationId)}',
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

  Future<Map<String, dynamic>> getGroupWishlist() async {
    _requireAuthentication();

    final response = await http.get(
      Uri.parse('$baseUrl/group/wishlist'),
      headers: _headers,
    );

    return _requireSuccess(
      response,
      'Unable to retrieve group wishlist.',
    );
  }

  Future<Map<String, dynamic>> removeFromGroupWishlist({
    required String mediaId,
  }) async {
    _requireAuthentication();

    if (mediaId.trim().isEmpty) {
      throw BackendApiException('Media ID is required.');
    }

    final response = await http.delete(
      Uri.parse(
        '$baseUrl/group/wishlist/${Uri.encodeComponent(mediaId)}',
      ),
      headers: _headers,
    );

    return _requireSuccess(
      response,
      'Unable to remove media from group wishlist.',
    );
  }

  Future<Map<String, dynamic>> acquireGroupWishlistItem({
    required String mediaId,
    required String profileId,
  }) async {
    _requireAuthentication();

    if (mediaId.trim().isEmpty) {
      throw BackendApiException('Media ID is required.');
    }

    if (profileId.trim().isEmpty) {
      throw BackendApiException('Profile ID is required.');
    }

    final response = await http.post(
      Uri.parse(
        '$baseUrl/group/wishlist/${Uri.encodeComponent(mediaId)}/acquire',
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
      throw BackendApiException('Media ID is required.');
    }

    if (cleanTitle.isEmpty) {
      throw BackendApiException('Title is required.');
    }

    if (cleanType != 'movie' && cleanType != 'tvShow') {
      throw BackendApiException(
        'Group Watch type must be "movie" or "tvShow".',
      );
    }

    if (cleanProfileId.isEmpty) {
      throw BackendApiException('Profile ID is required.');
    }

    if (invitationDurationHours != null &&
        invitationDurationHours <= 0) {
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
      body['invitationDurationHours'] =
          invitationDurationHours;
    }

    final response = await http.post(
      Uri.parse('$baseUrl/group/watch'),
      headers: _headers,
      body: jsonEncode(body),
    );

    return _requireSuccess(
      response,
      'Unable to create Group Watch session.',
    );
  }

  Future<Map<String, dynamic>> getGroupWatchSessions() async {
    _requireAuthentication();

    final response = await http.get(
      Uri.parse('$baseUrl/group/watch'),
      headers: _headers,
    );

    return _requireSuccess(
      response,
      'Unable to retrieve Group Watch sessions.',
    );
  }

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

    final response = await http.get(
      Uri.parse(
        '$baseUrl/group/watch/${Uri.encodeComponent(cleanSessionId)}',
      ),
      headers: _headers,
    );

    return _requireSuccess(
      response,
      'Unable to retrieve Group Watch session.',
    );
  }

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
      throw BackendApiException('Profile ID is required.');
    }

    final response = await http.post(
      Uri.parse(
        '$baseUrl/group/watch/${Uri.encodeComponent(cleanSessionId)}/accept',
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
      throw BackendApiException('Profile ID is required.');
    }

    final response = await http.post(
      Uri.parse(
        '$baseUrl/group/watch/${Uri.encodeComponent(cleanSessionId)}/decline',
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
      throw BackendApiException('Profile ID is required.');
    }

    final response = await http.post(
      Uri.parse(
        '$baseUrl/group/watch/${Uri.encodeComponent(cleanSessionId)}/audio',
      ),
      headers: _headers,
      body: jsonEncode({
        'profileId': cleanProfileId,
        'audioTrackId':
            cleanAudioTrackId?.isEmpty == true
                ? null
                : cleanAudioTrackId,
      }),
    );

    return _requireSuccess(
      response,
      'Unable to set Group Watch audio track.',
    );
  }

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
      throw BackendApiException('Profile ID is required.');
    }

    final response = await http.post(
      Uri.parse(
        '$baseUrl/group/watch/${Uri.encodeComponent(cleanSessionId)}/subtitles',
      ),
      headers: _headers,
      body: jsonEncode({
        'profileId': cleanProfileId,
        'subtitleTrackId':
            cleanSubtitleTrackId?.isEmpty == true
                ? null
                : cleanSubtitleTrackId,
      }),
    );

    return _requireSuccess(
      response,
      'Unable to set Group Watch subtitle track.',
    );
  }

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
      throw BackendApiException('Profile ID is required.');
    }

    final response = await http.post(
      Uri.parse(
        '$baseUrl/group/watch/${Uri.encodeComponent(cleanSessionId)}/start',
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
      throw BackendApiException('Profile ID is required.');
    }

    final response = await http.post(
      Uri.parse(
        '$baseUrl/group/watch/${Uri.encodeComponent(cleanSessionId)}/play',
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
      throw BackendApiException('Profile ID is required.');
    }

    if (cleanReason.isEmpty) {
      throw BackendApiException('Pause reason is required.');
    }

    final response = await http.post(
      Uri.parse(
        '$baseUrl/group/watch/${Uri.encodeComponent(cleanSessionId)}/pause',
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
      throw BackendApiException('Profile ID is required.');
    }

    final response = await http.post(
      Uri.parse(
        '$baseUrl/group/watch/${Uri.encodeComponent(cleanSessionId)}/resume',
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
  /// IMPORTANT:
  ///
  /// The backend route expects `positionMilliseconds`.
  /// We therefore send the Duration directly as milliseconds.
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
      throw BackendApiException('Profile ID is required.');
    }

    if (position.isNegative) {
      throw BackendApiException(
        'Playback position cannot be negative.',
      );
    }

    final int positionMilliseconds =
        position.inMilliseconds;

    final response = await http.post(
      Uri.parse(
        '$baseUrl/group/watch/${Uri.encodeComponent(cleanSessionId)}/position',
      ),
      headers: _headers,
      body: jsonEncode({
        'profileId': cleanProfileId,
        'positionMilliseconds':
            positionMilliseconds,
      }),
    );

    return _requireSuccess(
      response,
      'Unable to update Group Watch position.',
    );
  }

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
      throw BackendApiException('Profile ID is required.');
    }

    final response = await http.post(
      Uri.parse(
        '$baseUrl/group/watch/${Uri.encodeComponent(cleanSessionId)}/end',
      ),
      headers: _headers,
      body: jsonEncode({
        'profileId': cleanProfileId,
      }),
    );

    return _requireSuccess(
      response,
      'Unable to end Group Watch.',
    );
  }

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
      throw BackendApiException('Profile ID is required.');
    }

    final response = await http.delete(
      Uri.parse(
        '$baseUrl/group/watch/${Uri.encodeComponent(cleanSessionId)}',
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


  // ==========================================================
  // EMAIL / REMOTE ACCESS
  // ==========================================================
  Future<Map<String, dynamic>> createRemoteAccessCode() async {
    _requireAuthentication();
    final response = await http.post(Uri.parse('$baseUrl/remote/access-code'), headers: _headers);
    return _requireSuccess(response, 'Unable to create remote access code.');
  }

  Future<Map<String, dynamic>> getRemoteWorkers() async {
    _requireAuthentication();
    final response = await http.get(Uri.parse('$baseUrl/remote/workers'), headers: _headers);
    return _requireSuccess(response, 'Unable to retrieve remote computers.');
  }

  Future<Map<String, dynamic>> queueRemoteImport({required String workerId, String driveName = 'Disc reader'}) async {
    _requireAuthentication();
    final response = await http.post(Uri.parse('$baseUrl/remote/jobs'), headers: _headers, body: jsonEncode({'workerId': workerId, 'driveName': driveName}));
    return _requireSuccess(response, 'Unable to queue remote disc import.');
  }

  // ==========================================================
  // ARM
  // ==========================================================

  Future<Map<String, dynamic>> getArmStatus() async {
    _requireAuthentication();
    final response = await http.get(
      Uri.parse('$baseUrl/arm/status'),
      headers: _headers,
    );
    return _requireSuccess(response, 'Unable to connect to ARM.');
  }

   Future<List<dynamic>> getArmDrives() async {
  _requireAuthentication();

  final response = await http.get(
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


  Future<Map<String, dynamic>> scanArmDisc({
    required String driveId,
  }) async {
    _requireAuthentication();
    final response = await http.post(
      Uri.parse('$baseUrl/arm/scan'),
      headers: _headers,
      body: jsonEncode({'driveId': driveId}),
    );
    return _requireSuccess(response, 'Unable to scan the ARM disc.');
  }

  Future<Map<String, dynamic>> startArmImport({
    required String driveId,
  }) async {
    _requireAuthentication();
    final response = await http.post(
      Uri.parse('$baseUrl/arm/import'),
      headers: _headers,
      body: jsonEncode({'driveId': driveId}),
    );
    return _requireSuccess(response, 'Unable to start ARM disc monitoring.');
  }

  Future<Map<String, dynamic>> getArmJob({
    required String jobId,
  }) async {
    _requireAuthentication();
    final response = await http.get(
      Uri.parse('$baseUrl/arm/jobs/${Uri.encodeComponent(jobId)}'),
      headers: _headers,
    );
    return _requireSuccess(response, 'Unable to retrieve ARM job status.');
  }

  Future<Map<String, dynamic>> cancelArmJob({
    required String jobId,
  }) async {
    _requireAuthentication();
    final response = await http.post(
      Uri.parse('$baseUrl/arm/jobs/${Uri.encodeComponent(jobId)}/cancel'),
      headers: _headers,
    );
    return _requireSuccess(response, 'Unable to cancel the ARM import.');
  }


  Future<Map<String, dynamic>> getLiveSports({String? sport, String? country}) async {
    _requireAuthentication();
    final params = <String, String>{};
    if (sport != null && sport.isNotEmpty) params['sport'] = sport;
    if (country != null && country.isNotEmpty) params['country'] = country;
    final uri = Uri.parse('$baseUrl/sports/live').replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers);
    return _requireSuccess(response, 'Unable to load live sports.');
  }

  Future<List<dynamic>> getSports() async {
    _requireAuthentication();
    final response = await http.get(Uri.parse('$baseUrl/sports'), headers: _headers);
    final data = await _requireSuccess(response, 'Unable to load sports.');
    return data['sports'] is List ? data['sports'] as List : <dynamic>[];
  }

  Future<Map<String, dynamic>> getUpcomingSports({String? sport, String? country, int days = 7}) async {
    _requireAuthentication();
    final params = <String, String>{'days': days.toString()};
    if (sport != null && sport.isNotEmpty) params['sport'] = sport;
    if (country != null && country.isNotEmpty) params['country'] = country;
    final uri = Uri.parse('$baseUrl/sports/upcoming').replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers);
    return _requireSuccess(response, 'Unable to load upcoming sports.');
  }

  // ==========================================================
  // HOME SERVER, MUSIC AND REVIEWS
  // ==========================================================

  /// Reads the home server storage dashboard.
  Future<Map<String, dynamic>> getHomeServerStorage() async {
    _requireAuthentication();
    final response = await http.get(Uri.parse('$baseUrl/server/storage'), headers: _headers);
    return _requireSuccess(response, 'Unable to load home server storage.');
  }

  /// Reads the ARM connection and media-root configuration.
  Future<Map<String, dynamic>> getHomeServerArm() async {
    _requireAuthentication();
    final response = await http.get(Uri.parse('$baseUrl/server/arm'), headers: _headers);
    return _requireSuccess(response, 'Unable to load ARM server status.');
  }

  /// Loads reviews visible inside the current account.
  Future<Map<String, dynamic>> getReviews(String mediaId) async {
    _requireAuthentication();
    final uri = Uri.parse('$baseUrl/reviews').replace(queryParameters: {'mediaId': mediaId});
    return _requireSuccess(await http.get(uri, headers: _headers), 'Unable to load reviews.');
  }

  /// Loads public reviews without exposing email or account identifiers.
  Future<Map<String, dynamic>> getGlobalReviews(String mediaId) async {
    _requireAuthentication();
    final uri = Uri.parse('$baseUrl/reviews/global').replace(queryParameters: {'mediaId': mediaId});
    return _requireSuccess(await http.get(uri, headers: _headers), 'Unable to load global reviews.');
  }

  /// Publishes a profile review using a user-selected global pseudonym.
  Future<Map<String, dynamic>> submitReview({required String mediaId, required String profileId, required double score, required String label, required String text, required String globalUsername}) async {
    _requireAuthentication();
    final response = await http.post(Uri.parse('$baseUrl/reviews'), headers: _headers, body: jsonEncode({'mediaId': mediaId, 'profileId': profileId, 'score': score, 'label': label, 'text': text, 'globalUsername': globalUsername}));
    return _requireSuccess(response, 'Unable to submit review.');
  }

  // ==========================================================
  // INTERNAL HELPERS
  // ==========================================================

  /// Performs `_requireAuthentication` for this feature. Update this documentation when its contract changes.
  void _requireAuthentication() {
    if (!isAuthenticated) {
      throw BackendApiException(
        'You must be logged in before using this feature.',
      );
    }
  }

  Future<Map<String, dynamic>> _requireSuccess(
    http.Response response,
    String fallbackError,
  ) async {
    final data = _decodeResponse(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendApiException(
        data['error']?.toString() ?? fallbackError,
        statusCode: response.statusCode,
      );
    }

    return data;
  }

  // ==========================================================
  // RESPONSE DECODING
  // ==========================================================

  /// Performs `verifySecurityAnswer` for this feature. Update this documentation when its contract changes.
  Future<bool> verifySecurityAnswer(String answer) async {
    if (!isAuthenticated) return false;
    final response = await http.post(
      Uri.parse('$baseUrl/auth/verify-security'),
      headers: _headers,
      body: jsonEncode({'answer': answer}),
    );
    final data = _decodeResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendApiException(data['error']?.toString() ?? 'Unable to verify security answer.', statusCode: response.statusCode);
    }
    return data['verified'] == true;
  }

  /// Performs `_decodeResponse` for this feature. Update this documentation when its contract changes.
  Map<String, dynamic> _decodeResponse(
    http.Response response,
  ) {
    if (response.body.isEmpty) {
      return {};
    }

    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      return {
        'data': decoded,
      };
    } catch (_) {
      return {
        'error': response.body,
      };
    }
  }
}
