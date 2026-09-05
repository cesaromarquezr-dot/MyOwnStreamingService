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

  void setToken(String token) {
    _token = token;
  }

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
  ///
  /// The returned data contains:
  ///
  /// - account
  /// - subscription
  /// - payment
  /// - payment ID
  /// - checkout token
  ///
  /// The checkout token is only used for the payment process.
  /// It is NOT an authentication token.
  Future<Map<String, dynamic>> signup({
    required String username,
    required String email,
    required String password,
    required String firstProfileName,
    required String plan,
  }) async {
    final cleanPlan =
        plan.trim().toLowerCase();

    if (cleanPlan != 'monthly' &&
        cleanPlan != 'yearly') {
      throw BackendApiException(
        'Subscription plan must be monthly or yearly.',
      );
    }

    /*
     * Make absolutely sure signup starts without an
     * authenticated session.
     *
     * This prevents an old token from accidentally being
     * associated with the new signup request.
     */
    clearToken();

    final response = await http.post(
      Uri.parse('$baseUrl/auth/signup'),
      headers: _headers,
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
        'firstProfileName': firstProfileName,
        'plan': cleanPlan,
      }),
    );

    final data =
        _decodeResponse(response);

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw BackendApiException(
        data['error']?.toString() ??
            'Unable to create account.',
        statusCode:
            response.statusCode,
      );
    }

    /*
     * The backend should NOT return a normal auth token
     * during signup.
     *
     * If one is accidentally returned, do not store it.
     */
    clearToken();

    final payment =
        data['payment'];

    if (payment is! Map) {
      throw BackendApiException(
        'Account was created but no payment session was returned.',
        statusCode:
            response.statusCode,
      );
    }

    final paymentId =
        payment['id']?.toString();

    final checkoutToken =
        payment['checkoutToken']?.toString();

    if (paymentId == null ||
        paymentId.isEmpty) {
      throw BackendApiException(
        'Payment session was created but no payment ID was returned.',
        statusCode:
            response.statusCode,
      );
    }

    if (checkoutToken == null ||
        checkoutToken.isEmpty) {
      throw BackendApiException(
        'Payment session was created but no checkout authorization was returned.',
        statusCode:
            response.statusCode,
      );
    }

    return data;
  }

  /// Logs into an account.
  ///
  /// The backend will reject login if the account's
  /// subscription has not been activated through payment.
  Future<Map<String, dynamic>> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: _headers,
      body: jsonEncode({
        'login': usernameOrEmail,
        'password': password,
      }),
    );

    final data =
        _decodeResponse(response);

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw BackendApiException(
        data['error']?.toString() ??
            'Unable to log in.',
        statusCode:
            response.statusCode,
      );
    }

    final token =
        data['token']?.toString();

    if (token == null ||
        token.isEmpty) {
      throw BackendApiException(
        'Backend login succeeded but no authentication token was returned.',
        statusCode:
            response.statusCode,
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

    final data =
        _decodeResponse(response);

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw BackendApiException(
        data['error']?.toString() ??
            'Unable to retrieve account.',
        statusCode:
            response.statusCode,
      );
    }

    return data;
  }

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
  // PAYMENT
  // ==========================================================

  /// Retrieves the status of a signup checkout session.
  ///
  /// This endpoint does NOT require a normal authentication token.
  ///
  /// Instead, the temporary checkout token returned during signup
  /// authorizes access to this specific payment session.
  Future<Map<String, dynamic>> getCheckoutPaymentStatus({
    required String paymentId,
    required String checkoutToken,
  }) async {
    if (paymentId.trim().isEmpty) {
      throw BackendApiException(
        'Payment ID is required.',
      );
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

    /*
     * Deliberately use headers without Authorization.
     *
     * A checkout session is pre-login and therefore must not
     * depend on a normal authentication token.
     */
    final response = await http.get(
      uri,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    final data =
        _decodeResponse(response);

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw BackendApiException(
        data['error']?.toString() ??
            'Unable to retrieve payment status.',
        statusCode:
            response.statusCode,
      );
    }

    return data;
  }

  /// Verifies a completed signup payment.
  ///
  /// IMPORTANT:
  ///
  /// processorTransactionId is the payment provider's
  /// transaction/reference ID.
  ///
  /// This method does NOT accept:
  ///
  /// - card numbers
  /// - CVV
  /// - PIN
  /// - bank account numbers
  /// - bank passwords
  /// - online banking credentials
  ///
  /// The backend uses the checkout token to identify the
  /// correct payment session and account.
  Future<Map<String, dynamic>> verifyCheckoutPayment({
    required String paymentId,
    required String checkoutToken,
    required String processorTransactionId,
  }) async {
    if (paymentId.trim().isEmpty) {
      throw BackendApiException(
        'Payment ID is required.',
      );
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
        'processorTransactionId':
            processorTransactionId,
      }),
    );

    final data =
        _decodeResponse(response);

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw BackendApiException(
        data['error']?.toString() ??
            'Unable to verify payment.',
        statusCode:
            response.statusCode,
      );
    }

    /*
     * Payment verification does NOT automatically create
     * a normal authentication token.
     *
     * The user must log in normally after payment.
     */
    clearToken();

    return data;
  }

  /// Creates a payment session for an already authenticated
  /// account.
  ///
  /// This is useful for future subscription renewals or
  /// subscription changes.
  Future<Map<String, dynamic>> createPayment({
    required String plan,
  }) async {
    if (!isAuthenticated) {
      throw BackendApiException(
        'You must be logged in before creating a payment.',
      );
    }

    final cleanPlan =
        plan.trim().toLowerCase();

    if (cleanPlan != 'monthly' &&
        cleanPlan != 'yearly') {
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

    final data =
        _decodeResponse(response);

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw BackendApiException(
        data['error']?.toString() ??
            'Unable to create payment session.',
        statusCode:
            response.statusCode,
      );
    }

    return data;
  }

  /// Gets the status of a payment belonging to the
  /// authenticated account.
  Future<Map<String, dynamic>> getPaymentStatus({
    required String paymentId,
  }) async {
    if (!isAuthenticated) {
      throw BackendApiException(
        'You must be logged in before checking payment status.',
      );
    }

    if (paymentId.trim().isEmpty) {
      throw BackendApiException(
        'Payment ID is required.',
      );
    }

    final response = await http.get(
      Uri.parse(
        '$baseUrl/payment/status/${Uri.encodeComponent(paymentId)}',
      ),
      headers: _headers,
    );

    final data =
        _decodeResponse(response);

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw BackendApiException(
        data['error']?.toString() ??
            'Unable to retrieve payment status.',
        statusCode:
            response.statusCode,
      );
    }

    return data;
  }

  /// Verifies a payment for an already authenticated account.
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
      throw BackendApiException(
        'Payment ID is required.',
      );
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
        'processorTransactionId':
            processorTransactionId,
      }),
    );

    final data =
        _decodeResponse(response);

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw BackendApiException(
        data['error']?.toString() ??
            'Unable to verify payment.',
        statusCode:
            response.statusCode,
      );
    }

    return data;
  }

  /// Cancels an authenticated payment session.
  Future<Map<String, dynamic>> cancelPayment({
    required String paymentId,
  }) async {
    if (!isAuthenticated) {
      throw BackendApiException(
        'You must be logged in before cancelling a payment.',
      );
    }

    if (paymentId.trim().isEmpty) {
      throw BackendApiException(
        'Payment ID is required.',
      );
    }

    final response = await http.post(
      Uri.parse(
        '$baseUrl/payment/cancel/${Uri.encodeComponent(paymentId)}',
      ),
      headers: _headers,
    );

    final data =
        _decodeResponse(response);

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw BackendApiException(
        data['error']?.toString() ??
            'Unable to cancel payment.',
        statusCode:
            response.statusCode,
      );
    }

    return data;
  }

  // ==========================================================
  // RECOMMENDATIONS
  // ==========================================================

  /// Gets recommendations for the currently authenticated
  /// account/profile.
  ///
  /// The profile ID is optional so this method remains compatible
  /// with AppController's existing:
  ///
  ///     await backendApi.getRecommendations();
  ///
  /// If a profile ID is supplied, it is sent to the backend.
  Future<Map<String, dynamic>> getRecommendations({
    String? profileId,
    int limit = 20,
  }) async {
    if (!isAuthenticated) {
      throw BackendApiException(
        'You must be logged in before loading recommendations.',
      );
    }

    final safeLimit =
        limit.clamp(1, 100);

    final queryParameters =
        <String, String>{
      'limit': safeLimit.toString(),
    };

    if (profileId != null &&
        profileId.trim().isNotEmpty) {
      queryParameters['profileId'] =
          profileId.trim();
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

    final data =
        _decodeResponse(response);

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw BackendApiException(
        data['error']?.toString() ??
            'Unable to retrieve recommendations.',
        statusCode:
            response.statusCode,
      );
    }

    return data;
  }

  // ==========================================================
  // GROUP RECOMMENDATIONS
  // ==========================================================

  /// Creates a recommendation for the group.
  ///
  /// A recommendation can be:
  ///
  /// - A catalog item, when mediaId is supplied.
  /// - A manually entered movie/show that does not exist in the
  ///   catalog, when mediaId is null.
  ///
  /// activeParticipants contains the profile IDs that were
  /// active when voting started.
  ///
  /// votingDurationHours controls how long voting remains open.
  /// The backend uses 24 hours when this value is omitted.
  Future<Map<String, dynamic>> createGroupRecommendation({
    required String title,
    required String type,
    required String profileId,
    String? mediaId,
    Set<String>? activeParticipants,
    int? votingDurationHours,
  }) async {
    _requireAuthentication();

    final String cleanTitle =
        title.trim();

    if (cleanTitle.isEmpty) {
      throw BackendApiException(
        'Recommendation title is required.',
      );
    }

    final String cleanType =
        type.trim();

    if (cleanType != 'movie' &&
        cleanType != 'tvShow') {
      throw BackendApiException(
        'Recommendation type must be "movie" or "tvShow".',
      );
    }

    final String cleanProfileId =
        profileId.trim();

    if (cleanProfileId.isEmpty) {
      throw BackendApiException(
        'Profile ID is required.',
      );
    }

    String? cleanMediaId =
        mediaId?.trim();

    if (cleanMediaId != null &&
        cleanMediaId.isEmpty) {
      cleanMediaId = null;
    }

    if (votingDurationHours != null &&
        votingDurationHours <= 0) {
      throw BackendApiException(
        'Voting duration must be greater than zero.',
      );
    }

    final Set<String> participants =
        <String>{
      ...?activeParticipants,
      cleanProfileId,
    };

    final Map<String, dynamic> body =
        <String, dynamic>{
      'title': cleanTitle,
      'type': cleanType,
      'profileId': cleanProfileId,
      'activeParticipants':
          participants.toList(),
    };

    if (cleanMediaId != null) {
      body['mediaId'] = cleanMediaId;
    }

    if (votingDurationHours != null) {
      body['votingDurationHours'] =
          votingDurationHours;
    }

    final response = await http.post(
      Uri.parse(
        '$baseUrl/group/recommendations',
      ),
      headers: _headers,
      body: jsonEncode(body),
    );

    return _requireSuccess(
      response,
      'Unable to create group recommendation.',
    );
  }

  /// Gets all group recommendations for the account.
  Future<Map<String, dynamic>>
      getGroupRecommendations() async {
    _requireAuthentication();

    final response = await http.get(
      Uri.parse(
        '$baseUrl/group/recommendations',
      ),
      headers: _headers,
    );

    return _requireSuccess(
      response,
      'Unable to retrieve group recommendations.',
    );
  }

  /// Gets one group recommendation.
  Future<Map<String, dynamic>>
      getGroupRecommendation({
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

  /// Votes YES or NO on a group recommendation.
  Future<Map<String, dynamic>>
      voteOnGroupRecommendation({
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

    final cleanVote =
        vote.trim().toLowerCase();

    if (cleanVote != 'yes' &&
        cleanVote != 'no') {
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

  /// Closes voting on a group recommendation.
  ///
  /// If there is a majority YES, the backend also adds the
  /// recommendation to the account's shared group wishlist.
  Future<Map<String, dynamic>>
      closeGroupRecommendationVoting({
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

  /// Deletes a group recommendation.
  Future<Map<String, dynamic>>
      deleteGroupRecommendation({
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

  /// Gets the shared wishlist for the authenticated account.
  ///
  /// Unlike a personal profile library, this wishlist belongs
  /// to the account and is shared by the group's profiles.
  Future<Map<String, dynamic>>
      getGroupWishlist() async {
    _requireAuthentication();

    final response = await http.get(
      Uri.parse(
        '$baseUrl/group/wishlist',
      ),
      headers: _headers,
    );

    return _requireSuccess(
      response,
      'Unable to retrieve group wishlist.',
    );
  }

  /// Removes a media item from the shared group wishlist.
  Future<Map<String, dynamic>>
      removeFromGroupWishlist({
    required String mediaId,
  }) async {
    _requireAuthentication();

    if (mediaId.trim().isEmpty) {
      throw BackendApiException(
        'Media ID is required.',
      );
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

  /// Marks a group wishlist item as acquired.
  ///
  /// The backend:
  ///
  /// 1. Removes the media from the shared group wishlist.
  /// 2. Adds the media to the selected profile's library.
  ///
  /// profileId determines which profile receives ownership.
  Future<Map<String, dynamic>>
      acquireGroupWishlistItem({
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
  // ARM
  // ==========================================================

  Future<List<dynamic>> getArmDrives() async {
    final response = await http.get(
      Uri.parse('$baseUrl/arm/drives'),
      headers: _headers,
    );

    final data =
        _decodeResponse(response);

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw BackendApiException(
        data['error']?.toString() ??
            'Unable to retrieve ARM drives.',
        statusCode:
            response.statusCode,
      );
    }

    final drives =
        data['drives'];

    if (drives is List) {
      return drives;
    }

    return [];
  }

  // ==========================================================
  // INTERNAL HELPERS
  // ==========================================================

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
    final data =
        _decodeResponse(response);

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw BackendApiException(
        data['error']?.toString() ??
            fallbackError,
        statusCode:
            response.statusCode,
      );
    }

    return data;
  }

  // ==========================================================
  // RESPONSE DECODING
  // ==========================================================

  Map<String, dynamic> _decodeResponse(
    http.Response response,
  ) {
    if (response.body.isEmpty) {
      return {};
    }

    try {
      final decoded =
          jsonDecode(response.body);

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