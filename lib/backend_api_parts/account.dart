// Domain API methods extracted from backend_api.dart.
part of '../backend_api.dart';

extension BackendApiAccountMethods on BackendApi {
  // ==========================================================
  // LEGAL
  // ==========================================================

  /// Loads the current legal policies from the backend.
  Future<Map<String, dynamic>> getLegalPolicies() async {
    final response = await _networkClient.get(
      Uri.parse('$baseUrl/legal/policies'),
      headers: _headers,
    );

    final data = _decodeResponse(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendApiException(
        data['error']?.toString() ?? 'Unable to load legal policies.',
        statusCode: response.statusCode,
      );
    }

    return data;
  }

  /// Loads the authenticated account's legal acceptance state.
  Future<Map<String, dynamic>> getLegalAcceptance() async {
    final response = await _networkClient.get(
      Uri.parse('$baseUrl/legal/account-acceptance'),
      headers: _headers,
    );

    final data = _decodeResponse(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendApiException(
        data['error']?.toString() ?? 'Unable to load legal acceptance.',
        statusCode: response.statusCode,
      );
    }

    return data;
  }

  // ==========================================================
  // PUBLIC PLATFORM PRICING
  // ==========================================================

  /// Loads the current server-cost-based subscription pricing used by signup.
  Future<Map<String, dynamic>> getPlatformPricing() async {
    final response = await _networkClient.get(
      Uri.parse('$baseUrl/platform/pricing'),
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    return _requireSuccess(
      response,
      'Unable to load subscription pricing.',
    );
  }

  // ==========================================================
  // AUTH
  // ==========================================================

  /// Creates a new account and starts the payment process.
  ///
  /// Signup does NOT authenticate the user.
  ///
  /// The backend creates the account with an inactive
  /// subscription and returns a payment session.
  Future<Map<String, dynamic>> signup({
    required String email,
    required String password,
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

    final response = await _networkClient.post(
      Uri.parse('$baseUrl/auth/signup'),
      headers: _headers,
      body: jsonEncode({
        'email': email,
        'password': password,
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

  /// Logs into an account using the account email or username.
  /// The backend receives the canonical `email` field for compatibility with
  /// the authentication route; the value may also be a username.
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _networkClient.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: _headers,
      body: jsonEncode({
        'email': email.trim(),
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

    if (data['requiresMfa'] == true) {
      return data;
    }

    if (token == null || token.isEmpty) {
      throw BackendApiException(
        'Backend login succeeded but no authentication token was returned.',
        statusCode: response.statusCode,
      );
    }

    await setToken(token);

    return data;
  }

  /// Loads the currently authenticated account without asking for the password again.
  Future<Map<String, dynamic>> getCurrentAccount() async {
    _requireAuthentication();
    final response = await _networkClient.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: _headers,
    );
    return _requireSuccess(response, 'Unable to restore the account session.');
  }

  /// Invites another login identity to the currently authenticated account.
  Future<Map<String, dynamic>> inviteAccountMember({
    required String email,
    String? phone,
    String role = 'member',
    bool sendEmail = true,
  }) async {
    _requireAuthentication();

    final response = await _networkClient.post(
      Uri.parse('$baseUrl/auth/invitations'),
      headers: _headers,
      body: jsonEncode({
        'email': email.trim().toLowerCase(),
        'phone': phone?.trim(),
        'role': role,
        'sendEmail': sendEmail,
      }),
    );

    return _requireSuccess(
      response,
      'Unable to create account invitation.',
    );
  }

  /// Loads the members of the authenticated streaming account.
  Future<Map<String, dynamic>> addExistingAccountMember({
    required String username,
    String role = 'member',
  }) async {
    final response = await _networkClient.post(
      Uri.parse('$baseUrl/auth/members/add'),
      headers: _headers,
      body: jsonEncode({
        'username': username.trim().replaceFirst('@', ''),
        'role': role,
      }),
    );

    return _requireSuccess(
        response, 'Unable to add that existing user to this account.');
  }

  Future<List<Map<String, dynamic>>> getAccountMembers() async {
    _requireAuthentication();

    final response = await _networkClient.get(
      Uri.parse('$baseUrl/auth/members'),
      headers: _headers,
    );

    final data = await _requireSuccess(
      response,
      'Unable to load account members.',
    );

    final raw = data['members'];

    if (raw is! List) {
      return const [];
    }

    return raw
        .whereType<Map>()
        .map(
          (item) => Map<String, dynamic>.from(item),
        )
        .toList();
  }

  /// Accepts an invitation.
  ///
  /// If the email has never logged in before, a password creates
  /// its identity. Existing identities keep their existing password.
  Future<Map<String, dynamic>> acceptAccountInvitation({
    required String token,
    required String email,
    String? password,
  }) async {
    final response = await _networkClient.post(
      Uri.parse('$baseUrl/auth/invitations/accept'),
      headers: _headers,
      body: jsonEncode({
        'token': token,
        'email': email.trim().toLowerCase(),
        if (password != null && password.isNotEmpty) 'password': password,
      }),
    );

    return _requireSuccess(
      response,
      'Unable to accept account invitation.',
    );
  }

  /// Retrieves the security question for an existing account without
  /// returning any password or security-answer material.
  Future<String> getPasswordRecoveryQuestion({required String email}) async {
    final response = await _networkClient.post(
      Uri.parse('$baseUrl/auth/password-recovery/question'),
      headers: _headers,
      body: jsonEncode({'email': email.trim()}),
    );

    final data = _decodeResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendApiException(
        data['error']?.toString() ?? 'Unable to start password recovery.',
        statusCode: response.statusCode,
      );
    }

    final question = data['question']?.toString().trim() ?? '';
    if (question.isEmpty) {
      throw BackendApiException(
          'The account does not have a recovery question configured.');
    }
    return question;
  }

  /// Changes an existing account password using its security answer.
  Future<void> resetPassword({
    required String email,
    required String securityAnswer,
    required String newPassword,
  }) async {
    final response = await _networkClient.post(
      Uri.parse('$baseUrl/auth/password-recovery/reset'),
      headers: _headers,
      body: jsonEncode({
        'email': email.trim(),
        'securityAnswer': securityAnswer,
        'newPassword': newPassword,
      }),
    );

    final data = _decodeResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendApiException(
        data['error']?.toString() ?? 'Unable to reset the account password.',
        statusCode: response.statusCode,
      );
    }
  }

  /// Retrieves the authenticated account.
  Future<Map<String, dynamic>> me() async {
    if (!isAuthenticated) {
      throw BackendApiException(
        'You must be logged in before retrieving your account.',
      );
    }

    final response = await _networkClient.get(
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

  /// Logs out of the backend account.
  Future<void> logout() async {
    if (!isAuthenticated) {
      return;
    }

    try {
      await _networkClient.post(
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

  /// Creates a cross-account Group Chat room.
  Future<Map<String, dynamic>> createGroupChatRoom({
    required String name,
    required String profileId,
    Set<String>? invitedProfiles,
  }) async {
    _requireAuthentication();

    final response = await _networkClient.post(
      Uri.parse('$baseUrl/group/chat'),
      headers: _headers,
      body: jsonEncode({
        'name': name.trim(),
        'profileId': profileId.trim(),
        'invitedProfiles': (invitedProfiles ?? {}).toList(),
      }),
    );

    return _requireSuccess(
      response,
      'Unable to create group chat room.',
    );
  }

  /// Retrieves the Group Chat rooms available to the user.
  Future<Map<String, dynamic>> getGroupChatRooms() async {
    _requireAuthentication();

    final response = await _networkClient.get(
      Uri.parse('$baseUrl/group/chat'),
      headers: _headers,
    );

    return _requireSuccess(
      response,
      'Unable to retrieve group chat rooms.',
    );
  }

  /// Retrieves a Group Chat room and its messages.
  Future<Map<String, dynamic>> getGroupChatRoom(
    String roomId,
  ) async {
    _requireAuthentication();

    final response = await _networkClient.get(
      Uri.parse(
        '$baseUrl/group/chat/'
        '${Uri.encodeComponent(roomId)}/messages',
      ),
      headers: _headers,
    );

    return _requireSuccess(
      response,
      'Unable to retrieve group chat room.',
    );
  }

  /// Sends a message to a Group Chat room.
  Future<Map<String, dynamic>> sendGroupChatMessage({
    required String roomId,
    required String profileId,
    required String message,
    String? badgeName,
  }) async {
    _requireAuthentication();

    final response = await _networkClient.post(
      Uri.parse(
        '$baseUrl/group/chat/'
        '${Uri.encodeComponent(roomId)}/messages',
      ),
      headers: _headers,
      body: jsonEncode({
        'profileId': profileId,
        'message': message,
        'badgeName': badgeName,
      }),
    );

    return _requireSuccess(
      response,
      'Unable to send group chat message.',
    );
  }

  // ==========================================================
  // PAYMENT
  // ==========================================================

  /// Retrieves a checkout payment status.
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
      '$baseUrl/payment/checkout/status/'
      '${Uri.encodeComponent(paymentId)}',
    ).replace(
      queryParameters: {
        'checkoutToken': checkoutToken,
      },
    );

    final response = await _networkClient.get(
      uri,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    final data = _decodeResponse(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendApiException(
        data['error']?.toString() ?? 'Unable to retrieve payment status.',
        statusCode: response.statusCode,
      );
    }

    return data;
  }

  /// Verifies a checkout payment.
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

    final response = await _networkClient.post(
      Uri.parse(
        '$baseUrl/payment/checkout/verify/'
        '${Uri.encodeComponent(paymentId)}',
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

  /// Creates an authenticated payment session.
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

    final response = await _networkClient.post(
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

  /// Retrieves an authenticated payment status.
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

    final response = await _networkClient.get(
      Uri.parse(
        '$baseUrl/payment/status/'
        '${Uri.encodeComponent(paymentId)}',
      ),
      headers: _headers,
    );

    return _requireSuccess(
      response,
      'Unable to retrieve payment status.',
    );
  }

  /// Verifies an authenticated payment.
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

    final response = await _networkClient.post(
      Uri.parse(
        '$baseUrl/payment/verify/'
        '${Uri.encodeComponent(paymentId)}',
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

  /// Cancels an authenticated payment.
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

    final response = await _networkClient.post(
      Uri.parse(
        '$baseUrl/payment/cancel/'
        '${Uri.encodeComponent(paymentId)}',
      ),
      headers: _headers,
    );

    return _requireSuccess(
      response,
      'Unable to cancel payment.',
    );
  }

  // ==========================================================
  // PROFILES / ACCOUNT
  // ==========================================================

  /// Creates a new profile.
  Future<Map<String, dynamic>> addProfile({
    required String name,
    required String username,
    String? avatarUrl,
  }) async {
    _requireAuthentication();

    final response = await _networkClient.post(
      Uri.parse('$baseUrl/profiles'),
      headers: _headers,
      body: jsonEncode({
        'name': name.trim(),
        'username': username.trim().replaceFirst(RegExp(r'^@'), '').toLowerCase(),
        'avatarUrl': avatarUrl,
      }),
    );

    return _requireSuccess(
      response,
      'Unable to create profile.',
    );
  }

  /// Removes an existing profile.
  Future<Map<String, dynamic>> removeProfile(
    String profileId,
  ) async {
    _requireAuthentication();

    final response = await _networkClient.delete(
      Uri.parse(
        '$baseUrl/profiles/${Uri.encodeComponent(profileId)}',
      ),
      headers: _headers,
    );

    return _requireSuccess(
      response,
      'Unable to delete profile.',
    );
  }

  /// Updates account-level information.
  Future<Map<String, dynamic>> updateAccount({
    String? username,
    String? email,
    required String currentPassword,
  }) async {
    _requireAuthentication();

    final response = await _networkClient.put(
      Uri.parse('$baseUrl/auth/me'),
      headers: _headers,
      body: jsonEncode({
        'username': username,
        'email': email,
        'currentPassword': currentPassword,
      }),
    );

    return _requireSuccess(
      response,
      'Unable to update account.',
    );
  }

  /// Updates profile information.
  Future<Map<String, dynamic>> updateProfile({
    required String profileId,
    required String name,
    String? username,
    String? avatarUrl,
  }) async {
    _requireAuthentication();

    final response = await _networkClient.put(
      Uri.parse(
        '$baseUrl/profiles/${Uri.encodeComponent(profileId)}',
      ),
      headers: _headers,
      body: jsonEncode({
        'name': name.trim(),
        if (username != null) 'username': username.trim(),
        'avatarUrl': avatarUrl,
      }),
    );

    return _requireSuccess(
      response,
      'Unable to update profile.',
    );
  }

  /// Deletes the authenticated streaming account.
  Future<Map<String, dynamic>> deleteAccount() async {
    _requireAuthentication();

    final response = await _networkClient.delete(
      Uri.parse('$baseUrl/auth/account'),
      headers: _headers,
    );

    final data = await _requireSuccess(
      response,
      'Unable to delete account.',
    );

    clearToken();

    return data;
  }


}
