// FILE: `lib/backend_api.dart`.
// Purpose: Implements the backend api portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Implements the `BackendApiException` class for this feature or UI component.
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

/// Implements the `BackendApi` class for this feature or UI component.
class BackendApi {
  final String baseUrl;

  String? _token;
  static const _tokenStorageKey = 'backend_session_token';
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  BackendApi({
    this.baseUrl = const String.fromEnvironment(
      'BACKEND_API_URL',
      defaultValue: 'https://127.0.0.1:8080/api/v1',
    ),
  }) {
    assertSecureEndpoint();
  }

  String? get token => _token;

  /// Restores the authenticated session token from encrypted device storage.
  Future<bool> restoreToken() async {
    final stored = await _secureStorage.read(key: _tokenStorageKey);
    if (stored == null || stored.trim().isEmpty) {
      _token = null;
      return false;
    }
    _token = stored.trim();
    return true;
  }

  Uri get baseUri => Uri.parse(baseUrl);

  void assertSecureEndpoint() {
    final uri = baseUri;

    if (uri.scheme != 'https' &&
        uri.host != '127.0.0.1' &&
        uri.host != 'localhost') {
      throw BackendApiException(
        'Insecure HTTP backend endpoints are not allowed. '
        'Configure an HTTPS backend URL.',
      );
    }
  }

  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  /// Performs `setToken` for this feature. Update this documentation when its contract changes.
  Future<void> setToken(String token) async {
    _token = token;
    await _secureStorage.write(key: _tokenStorageKey, value: token);
  }

  /// Performs `clearToken` for this feature. Update this documentation when its contract changes.
  Future<void> clearToken() async {
    _token = null;
    await _secureStorage.delete(key: _tokenStorageKey);
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
  // LEGAL
  // ==========================================================

  /// Loads the current legal policies from the backend.
  Future<Map<String, dynamic>> getLegalPolicies() async {
    final response = await http.get(
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
    final response = await http.get(
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
    final response = await http.get(
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
    required String username,
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
        'username': username,
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

  /// Logs into an account using the account email or username.
  /// The backend receives the canonical `email` field for compatibility with
  /// the authentication route; the value may also be a username.
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
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
    final response = await http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: _headers,
    );
    return _requireSuccess(response, 'Unable to restore the account session.');
  }

  /// Invites another login identity to the currently authenticated account.
  Future<Map<String, dynamic>> inviteAccountMember({
    required String email,
    String role = 'member',
    bool sendEmail = true,
  }) async {
    _requireAuthentication();

    final response = await http.post(
      Uri.parse('$baseUrl/auth/invitations'),
      headers: _headers,
      body: jsonEncode({
        'email': email.trim().toLowerCase(),
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
    final response = await http.post(
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

    final response = await http.get(
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
    final response = await http.post(
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
    final response = await http.post(
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
    final response = await http.post(
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

  /// Logs out of the backend account.
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

  /// Creates a cross-account Group Chat room.
  Future<Map<String, dynamic>> createGroupChatRoom({
    required String name,
    required String profileId,
    Set<String>? invitedProfiles,
  }) async {
    _requireAuthentication();

    final response = await http.post(
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

    final response = await http.get(
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

    final response = await http.get(
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

    final response = await http.post(
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

    final response = await http.post(
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

    final response = await http.get(
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

    final response = await http.post(
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

    final response = await http.post(
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
    String? avatarUrl,
  }) async {
    _requireAuthentication();

    final response = await http.post(
      Uri.parse('$baseUrl/profiles'),
      headers: _headers,
      body: jsonEncode({
        'name': name.trim(),
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

    final response = await http.delete(
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

    final response = await http.put(
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
    String? avatarUrl,
  }) async {
    _requireAuthentication();

    final response = await http.put(
      Uri.parse(
        '$baseUrl/profiles/${Uri.encodeComponent(profileId)}',
      ),
      headers: _headers,
      body: jsonEncode({
        'name': name.trim(),
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

    final response = await http.delete(
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

  /// Retrieves group recommendations.
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

    final response = await http.get(
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

    final response = await http.post(
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

    final response = await http.post(
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

    final response = await http.delete(
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

    final response = await http.get(
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

    final response = await http.delete(
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

    final response = await http.post(
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

  /// Retrieves Group Watch sessions.
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

    final response = await http.get(
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

    final response = await http.post(
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

    final response = await http.post(
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

    final response = await http.post(
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

    final response = await http.post(
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

    final response = await http.post(
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

    final response = await http.post(
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

    final response = await http.post(
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

    final response = await http.post(
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

    final response = await http.post(
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

    final response = await http.post(
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

    final response = await http.delete(
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

  // ==========================================================
  // EMAIL / REMOTE ACCESS
  // ==========================================================

  /// Creates a remote access code.
  Future<Map<String, dynamic>> createRemoteAccessCode() async {
    _requireAuthentication();

    final response = await http.post(
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

    final response = await http.get(
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

    final response = await http.post(
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

    final response = await http.get(
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

  /// Scans a disc in the selected ARM drive.
  Future<Map<String, dynamic>> scanArmDisc({
    required String driveId,
  }) async {
    _requireAuthentication();

    final response = await http.post(
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

    final response = await http.post(
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

    final response = await http.get(
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

    final response = await http.post(
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
      await http.get(
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
      await http.post(
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
      await http.post(
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
  // LIVE SPORTS
  // ==========================================================

  /// Retrieves live sports events.
  Future<Map<String, dynamic>> getLiveSports({
    String? sport,
    String? country,
  }) async {
    _requireAuthentication();

    final params = <String, String>{};

    if (sport != null && sport.isNotEmpty) {
      params['sport'] = sport;
    }

    if (country != null && country.isNotEmpty) {
      params['country'] = country;
    }

    final uri = Uri.parse(
      '$baseUrl/sports/live',
    ).replace(
      queryParameters: params,
    );

    final response = await http.get(
      uri,
      headers: _headers,
    );

    return _requireSuccess(
      response,
      'Unable to load live sports.',
    );
  }

  /// Retrieves available sports teams.
  Future<Map<String, dynamic>> getSportsTeams() async {
    _requireAuthentication();

    final response = await http.get(
      Uri.parse('$baseUrl/sports/teams'),
      headers: _headers,
    );

    return _requireSuccess(
      response,
      'Unable to load sports teams.',
    );
  }

  /// Retrieves available sports.
  Future<List<dynamic>> getSports() async {
    _requireAuthentication();

    final response = await http.get(
      Uri.parse('$baseUrl/sports'),
      headers: _headers,
    );

    final data = await _requireSuccess(
      response,
      'Unable to load sports.',
    );

    return data['sports'] is List ? data['sports'] as List : <dynamic>[];
  }

  /// Retrieves upcoming sports events.
  Future<Map<String, dynamic>> getUpcomingSports({
    String? sport,
    String? country,
    int days = 7,
  }) async {
    _requireAuthentication();

    final params = <String, String>{
      'days': days.toString(),
    };

    if (sport != null && sport.isNotEmpty) {
      params['sport'] = sport;
    }

    if (country != null && country.isNotEmpty) {
      params['country'] = country;
    }

    final uri = Uri.parse(
      '$baseUrl/sports/upcoming',
    ).replace(
      queryParameters: params,
    );

    final response = await http.get(
      uri,
      headers: _headers,
    );

    return _requireSuccess(
      response,
      'Unable to load upcoming sports.',
    );
  }

  // ==========================================================
  // HOME SERVER, MUSIC AND REVIEWS
  // ==========================================================

  /// Reads the home server storage dashboard.
  Future<Map<String, dynamic>> getHomeServerStorage() async {
    _requireAuthentication();

    final response = await http.get(
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

    final response = await http.get(
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
      await http.get(
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
      await http.get(
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
    required String globalUsername,
    String reviewType = 'written',
    String? videoUrl,
    bool spoiler = false,
  }) async {
    _requireAuthentication();

    final response = await http.post(
      Uri.parse('$baseUrl/reviews'),
      headers: _headers,
      body: jsonEncode({
        'mediaId': mediaId,
        'profileId': profileId,
        'score': score,
        'label': label,
        'text': text,
        'globalUsername': globalUsername,
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
      await http.post(
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
    return _requireSuccess(await http.get(uri, headers: _headers),
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
      await http.post(
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
    return _requireSuccess(await http.get(uri, headers: _headers),
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
      await http.post(
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
      await http.get(uri, headers: _headers),
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
      await http.get(uri, headers: _headers),
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
      await http.get(uri, headers: _headers),
      'Unable to determine the current location.',
    );
    final location = data['location'];
    if (location is! Map) {
      throw BackendApiException('The location provider returned no address.');
    }
    return Map<String, dynamic>.from(location);
  }

  // ==========================================================
  // SHOP
  // ==========================================================

  Future<Map<String, dynamic>> searchShopEntities(
    String query,
    int limit,
  ) async {
    _requireAuthentication();
    final uri = Uri.parse('$baseUrl/shop/entities').replace(
      queryParameters: {
        'q': query.trim(),
        'limit': limit.clamp(1, 100).toString(),
      },
    );
    return _requireSuccess(
      await http.get(uri, headers: _headers),
      'Unable to search shop entities.',
    );
  }

  Future<Map<String, dynamic>> syncShopEntities(
    List<Map<String, dynamic>> entities,
  ) async {
    _requireAuthentication();
    return _requireSuccess(
      await http.post(
        Uri.parse('$baseUrl/shop/entities/sync'),
        headers: _headers,
        body: jsonEncode({'entities': entities}),
      ),
      'Unable to synchronize shop entities.',
    );
  }

  // ==========================================================
  // SELF-HOSTING
  // ==========================================================

  Future<Map<String, dynamic>> getSelfHostingStatus() async {
    _requireAuthentication();
    return _requireSuccess(
      await http.get(
        Uri.parse('$baseUrl/self-hosting/status'),
        headers: _headers,
      ),
      'Unable to retrieve self-hosting status.',
    );
  }

  // ==========================================================
  // MASTER PRODUCT ARCHITECTURE
  // ==========================================================

  Future<Map<String, dynamic>> getProfileGovernanceCapabilities() async {
    _requireAuthentication();
    return _requireSuccess(
      await http.get(
        Uri.parse('$baseUrl/profile-governance/capabilities'),
        headers: _headers,
      ),
      'Unable to load profile governance capabilities.',
    );
  }

  Future<Map<String, dynamic>> getProfileGovernance(
      {required String profileId}) async {
    _requireAuthentication();
    final clean = profileId.trim();
    if (clean.isEmpty) throw BackendApiException('Profile ID is required.');
    return _requireSuccess(
      await http.get(
        Uri.parse('$baseUrl/profile-governance/${Uri.encodeComponent(clean)}'),
        headers: _headers,
      ),
      'Unable to load profile governance.',
    );
  }

  Future<Map<String, dynamic>> updateProfileGovernance({
    required String profileId,
    required Map<String, dynamic> governance,
  }) async {
    _requireAuthentication();
    final clean = profileId.trim();
    if (clean.isEmpty) throw BackendApiException('Profile ID is required.');
    return _requireSuccess(
      await http.patch(
        Uri.parse('$baseUrl/profile-governance/${Uri.encodeComponent(clean)}'),
        headers: _headers,
        body: jsonEncode({'governance': governance}),
      ),
      'Unable to update profile governance.',
    );
  }

  Future<Map<String, dynamic>> updateAccountProfileAdministrationPolicy({
    required bool allowMembersToManageOwnProfiles,
  }) async {
    _requireAuthentication();
    return _requireSuccess(
      await http.patch(
        Uri.parse('$baseUrl/profile-governance/account-policy'),
        headers: _headers,
        body: jsonEncode({
          'allowMembersToManageOwnProfiles': allowMembersToManageOwnProfiles,
        }),
      ),
      'Unable to update account profile administration policy.',
    );
  }

  Future<Map<String, dynamic>> assignMemberProfiles({
    required String memberId,
    required List<String> profileIds,
  }) async {
    _requireAuthentication();
    final cleanMember = memberId.trim();
    if (cleanMember.isEmpty) {
      throw BackendApiException('Member ID is required.');
    }
    return _requireSuccess(
      await http.patch(
        Uri.parse(
            '$baseUrl/profile-governance/member/${Uri.encodeComponent(cleanMember)}'),
        headers: _headers,
        body: jsonEncode({'profileIds': profileIds}),
      ),
      'Unable to assign profiles to this member.',
    );
  }

  Future<Map<String, dynamic>> getServerAgentStatus(
      {required String serverId}) async {
    _requireAuthentication();
    final clean = serverId.trim();
    if (clean.isEmpty) throw BackendApiException('Server ID is required.');
    return _requireSuccess(
      await http.get(
        Uri.parse('$baseUrl/server-agent/${Uri.encodeComponent(clean)}/status'),
        headers: _headers,
      ),
      'Unable to load server agent status.',
    );
  }

  Future<Map<String, dynamic>> createMediaPlaybackStream({
    required String mediaId,
    String? versionId,
    String? serverId,
  }) async {
    _requireAuthentication();
    final cleanMedia = mediaId.trim();
    final cleanServer = serverId?.trim();
    if (cleanMedia.isEmpty || cleanServer == null || cleanServer.isEmpty) {
      throw BackendApiException(
          'Media ID and server ID are required for agent playback.');
    }
    final body = <String, dynamic>{
      'mediaId': cleanMedia,
      'serverId': cleanServer,
      if (versionId?.trim().isNotEmpty == true) 'versionId': versionId!.trim(),
    };
    return _requireSuccess(
      await http.post(
        Uri.parse('$baseUrl/server-agent/playback'),
        headers: _headers,
        body: jsonEncode(body),
      ),
      'Unable to create a media playback stream.',
    );
  }

  // ==========================================================
  // SECURITY / MFA
  // ==========================================================

  Future<Map<String, dynamic>> getSecurityStatus() async {
    _requireAuthentication();
    return _requireSuccess(
      await http.get(Uri.parse('$baseUrl/security/status'), headers: _headers),
      'Unable to retrieve security status.',
    );
  }

  Future<Map<String, dynamic>> getSecuritySessions() async {
    _requireAuthentication();
    return _requireSuccess(
      await http.get(Uri.parse('$baseUrl/security/sessions'),
          headers: _headers),
      'Unable to retrieve security sessions.',
    );
  }

  Future<Map<String, dynamic>> revokeSecuritySession({
    required String sessionId,
  }) async {
    _requireAuthentication();
    final cleanId = sessionId.trim();
    if (cleanId.isEmpty) throw BackendApiException('Session ID is required.');
    return _requireSuccess(
      await http.post(
        Uri.parse('$baseUrl/security/sessions/revoke'),
        headers: _headers,
        body: jsonEncode({'sessionId': cleanId}),
      ),
      'Unable to revoke the security session.',
    );
  }

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _requireAuthentication();
    if (currentPassword.isEmpty || newPassword.isEmpty) {
      throw BackendApiException('Current and new passwords are required.');
    }
    final response = await http.post(
      Uri.parse('$baseUrl/security/password'),
      headers: _headers,
      body: jsonEncode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    );
    final data = await _requireSuccess(response, 'Unable to change password.');
    await clearToken();
    return data;
  }

  Future<Map<String, dynamic>> startMfaEnrollment() async {
    _requireAuthentication();
    return _requireSuccess(
      await http.post(Uri.parse('$baseUrl/security/mfa/enroll'),
          headers: _headers),
      'Unable to start MFA enrollment.',
    );
  }

  Future<Map<String, dynamic>> verifyMfaEnrollment({
    required String code,
  }) async {
    _requireAuthentication();
    final cleanCode = code.trim();
    if (cleanCode.isEmpty) throw BackendApiException('MFA code is required.');
    return _requireSuccess(
      await http.post(
        Uri.parse('$baseUrl/security/mfa/enroll/verify'),
        headers: _headers,
        body: jsonEncode({'code': cleanCode}),
      ),
      'Unable to verify MFA enrollment.',
    );
  }

  Future<Map<String, dynamic>> disableMfa() async {
    _requireAuthentication();
    return _requireSuccess(
      await http.post(Uri.parse('$baseUrl/security/mfa/disable'),
          headers: _headers),
      'Unable to disable MFA.',
    );
  }

  Future<Map<String, dynamic>> verifyMfaLogin({
    required String email,
    required String code,
  }) async {
    final cleanEmail = email.trim();
    final cleanCode = code.trim();
    if (cleanEmail.isEmpty || cleanCode.isEmpty) {
      throw BackendApiException('Email and MFA code are required.');
    }
    final response = await http.post(
      Uri.parse('$baseUrl/auth/mfa/verify'),
      headers: _headers,
      body: jsonEncode({'email': cleanEmail, 'code': cleanCode}),
    );
    final data = await _requireSuccess(response, 'Unable to verify MFA login.');
    final token = data['token']?.toString();
    if (token == null || token.isEmpty) {
      throw BackendApiException(
          'MFA verification succeeded but no authentication token was returned.');
    }
    await setToken(token);
    return data;
  }

  // ==========================================================
  // PLATFORM SERVICES
  // ==========================================================

  Future<Map<String, dynamic>> getPlatformFeatureStatus() async {
    _requireAuthentication();
    return _requireSuccess(
      await http.get(
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
      await http.get(uri, headers: _headers),
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
      await http.get(uri, headers: _headers),
      'Unable to load media deep dives.',
    );
    return data['stories'] is List
        ? (data['stories'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];
  }

  Future<List<Map<String, dynamic>>> getRadioStations({
    String? countryCode,
    String? state,
    String? city,
    String? query,
    String? tag,
    String? band,
    int limit = 40,
  }) async {
    _requireAuthentication();
    final queryParameters = <String, String>{
      if (countryCode?.trim().isNotEmpty == true)
        'countryCode': countryCode!.trim(),
      if (state?.trim().isNotEmpty == true) 'state': state!.trim(),
      if (city?.trim().isNotEmpty == true) 'city': city!.trim(),
      if (query?.trim().isNotEmpty == true) 'q': query!.trim(),
      if (tag?.trim().isNotEmpty == true) 'tag': tag!.trim(),
      if (band?.trim().isNotEmpty == true) 'band': band!.trim(),
      'limit': '${limit.clamp(1, 100)}',
    };
    final uri = Uri.parse('$baseUrl/radio/stations')
        .replace(queryParameters: queryParameters);
    final data = await _requireSuccess(
      await http.get(uri, headers: _headers),
      'Unable to load radio stations.',
    );
    return data['stations'] is List
        ? (data['stations'] as List)
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
      await http.get(uri, headers: _headers),
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
      await http.get(uri, headers: _headers),
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
      await http.get(Uri.parse('$baseUrl/media-intelligence/works'),
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

  Future<List<Map<String, dynamic>>> searchMediaPeople(
      {String query = ''}) async {
    _requireAuthentication();
    final uri = Uri.parse('$baseUrl/media-intelligence/people').replace(
        queryParameters: query.trim().isEmpty ? null : {'q': query.trim()});
    final data = await _requireSuccess(
        await http.get(uri, headers: _headers), 'Unable to search people.');
    return data['people'] is List
        ? (data['people'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> createMediaPerson(
      {required String id, required String name}) async {
    _requireAuthentication();
    return _requireSuccess(
      await http.post(Uri.parse('$baseUrl/media-intelligence/person'),
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
    return _requireSuccess(await http.get(uri, headers: _headers),
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
      await http.post(Uri.parse('$baseUrl/media-intelligence/person-credit'),
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
      await http.post(
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
      await http.get(uri, headers: _headers),
      'Unable to load application records.',
    );
    return (data['records'] is List)
        ? (data['records'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> getSocialHome(
      {required String profileId}) async {
    _requireAuthentication();
    final uri = Uri.parse('$baseUrl/social/home')
        .replace(queryParameters: {'profileId': profileId});
    return _requireSuccess(await http.get(uri, headers: _headers),
        'Unable to load friends and communities.');
  }

  Future<Map<String, dynamic>> getSocialCenter(
      {required String profileId}) async {
    _requireAuthentication();
    final uri = Uri.parse('$baseUrl/social/center').replace(
      queryParameters: {'profileId': profileId},
    );
    return _requireSuccess(
      await http.get(uri, headers: _headers),
      'Unable to load social center.',
    );
  }

  Future<Map<String, dynamic>> createSocialConversation({
    required String profileId,
    required String username,
  }) =>
      _socialPost(
        'conversations',
        {'profileId': profileId, 'username': username.replaceFirst('@', '')},
        'Unable to start conversation.',
      );

  Future<Map<String, dynamic>> createSocialGroupConversation({
    required String profileId,
    required String title,
    required List<String> usernames,
  }) =>
      _socialPost(
        'conversations',
        {
          'profileId': profileId,
          'title': title,
          'usernames': usernames,
        },
        'Unable to create group chat.',
      );

  Future<Map<String, dynamic>> getSocialConversation({
    required String profileId,
    required String conversationId,
    String? after,
  }) async {
    _requireAuthentication();
    final uri = Uri.parse(
      '$baseUrl/social/conversations/${Uri.encodeComponent(conversationId)}',
    ).replace(queryParameters: {
      'profileId': profileId,
      if (after != null) 'after': after,
    });
    return _requireSuccess(
      await http.get(uri, headers: _headers),
      'Unable to load conversation.',
    );
  }

  Future<Map<String, dynamic>> sendSocialMessage({
    required String profileId,
    required String conversationId,
    required String body,
    String? replyToMessageId,
    String messageType = 'text',
    Map<String, dynamic>? mediaReference,
    Map<String, dynamic>? textFormat,
    bool viewOnce = false,
  }) =>
      _socialPost(
        'conversations/${Uri.encodeComponent(conversationId)}/messages',
        {
          'profileId': profileId,
          'body': body,
          if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
          'messageType': messageType,
          if (mediaReference != null) 'mediaReference': mediaReference,
          if (textFormat != null) 'textFormat': textFormat,
          if (viewOnce) 'viewOnce': true,
        },
        'Unable to send message.',
      );

  Future<Map<String, dynamic>> forwardSocialMessage({
    required String profileId,
    required String sourceMessageId,
    required String conversationId,
  }) =>
      _socialPost(
        'messages/${Uri.encodeComponent(sourceMessageId)}/forward',
        {'profileId': profileId, 'conversationId': conversationId},
        'Unable to forward video.',
      );

  Future<Map<String, dynamic>> forwardSocialPost({
    required String profileId,
    required String sourcePostId,
    required String conversationId,
  }) =>
      _socialPost(
        'posts/${Uri.encodeComponent(sourcePostId)}/share',
        {'profileId': profileId, 'conversationId': conversationId},
        'Unable to share video.',
      );

  Future<Map<String, dynamic>> setSocialConversationAppearance({
    required String profileId,
    required String conversationId,
    String? backgroundColor,
    String? backgroundImagePath,
    bool clearBackgroundColor = false,
    bool clearBackgroundImage = false,
  }) =>
      _socialPost(
        'conversations/${Uri.encodeComponent(conversationId)}/appearance',
        {
          'profileId': profileId,
          if (backgroundColor != null) 'backgroundColor': backgroundColor,
          if (clearBackgroundColor) 'clearBackgroundColor': true,
          if (backgroundImagePath != null)
            'backgroundImagePath': backgroundImagePath,
          if (clearBackgroundImage) 'clearBackgroundImage': true,
        },
        'Unable to save chat appearance.',
      );

  Future<Map<String, dynamic>> setSocialConversationTyping({
    required String profileId,
    required String conversationId,
    required bool isTyping,
  }) =>
      _socialPost(
        'conversations/${Uri.encodeComponent(conversationId)}/typing',
        {'profileId': profileId, 'isTyping': isTyping},
        'Unable to update typing status.',
      );

  Future<Map<String, dynamic>> setSocialProfilePresence({
    required String profileId,
    String? availability,
    String? activityType,
    String? activityText,
    String? nickname,
    bool clearActivity = false,
    bool clearNickname = false,
  }) =>
      _socialPost(
        'presence',
        {
          'profileId': profileId,
          if (availability != null) 'availability': availability,
          if (activityType != null) 'activityType': activityType,
          if (activityText != null) 'activityText': activityText,
          if (nickname != null) 'nickname': nickname,
          if (clearActivity) 'clearActivity': true,
          if (clearNickname) 'clearNickname': true,
        },
        'Unable to update profile presence.',
      );

  Future<Map<String, dynamic>> setSocialMessageNickname({
    required String profileId,
    required String nickname,
  }) =>
      setSocialProfilePresence(
        profileId: profileId,
        nickname: nickname,
        clearNickname: nickname.isEmpty,
      );

  Future<Map<String, dynamic>> setSocialGroupSendPolicy({
    required String profileId,
    required String conversationId,
    required String sendPolicy,
  }) =>
      _socialPatch(
        'conversations/${Uri.encodeComponent(conversationId)}',
        {'profileId': profileId, 'sendPolicy': sendPolicy},
        'Unable to update group chat settings.',
      );

  Future<Map<String, dynamic>> createSocialChatPoll({
    required String profileId,
    required String conversationId,
    required String question,
    required List<String> options,
  }) =>
      _socialPost(
        'conversations/${Uri.encodeComponent(conversationId)}/polls',
        {
          'profileId': profileId,
          'question': question,
          'options': options,
        },
        'Unable to create poll.',
      );

  Future<Map<String, dynamic>> voteSocialChatPoll({
    required String profileId,
    required String conversationId,
    required String pollId,
    required int optionIndex,
  }) =>
      _socialPost(
        'conversations/${Uri.encodeComponent(conversationId)}/polls/${Uri.encodeComponent(pollId)}/vote',
        {'profileId': profileId, 'optionIndex': optionIndex},
        'Unable to submit poll vote.',
      );

  Future<Map<String, dynamic>> viewSocialOnceMessage({
    required String profileId,
    required String messageId,
  }) =>
      _socialPost(
        'messages/${Uri.encodeComponent(messageId)}/view',
        {'profileId': profileId},
        'Unable to open view-once attachment.',
      );

  Future<Map<String, dynamic>> reactToSocialMessage({
    required String profileId,
    required String messageId,
    required String reaction,
  }) =>
      _socialPost(
        'messages/${Uri.encodeComponent(messageId)}',
        {'profileId': profileId, 'reaction': reaction},
        'Unable to react to message.',
      );

  Future<Map<String, dynamic>> reactToSocialPost({
    required String profileId,
    required String postId,
    required String reaction,
  }) =>
      _socialPost(
        'posts/react',
        {'profileId': profileId, 'postId': postId, 'reaction': reaction},
        'Unable to react to post.',
      );
  Future<Map<String, dynamic>> commentOnSocialPost({
    required String profileId,
    required String postId,
    required String body,
  }) =>
      _socialPost(
        'posts/comment',
        {'profileId': profileId, 'postId': postId, 'body': body},
        'Unable to comment on post.',
      );

  Future<Map<String, dynamic>> recordSocialStoryView({
    required String profileId,
    required String storyId,
  }) =>
      _socialPost(
        'stories/${Uri.encodeComponent(storyId)}/view',
        {'profileId': profileId},
        'Unable to record Story view.',
      );

  Future<Map<String, dynamic>> getSocialStoryInsights({
    required String profileId,
    required String storyId,
  }) async {
    _requireAuthentication();
    final uri = Uri.parse('$baseUrl/social/stories/${Uri.encodeComponent(storyId)}/insights')
        .replace(queryParameters: {'profileId': profileId});
    return _requireSuccess(
      await http.get(uri, headers: _headers),
      'Unable to load Story views.',
    );
  }

  Future<Map<String, dynamic>> reactToSocialStory({
    required String profileId,
    required String storyId,
    required String reaction,
  }) =>
      _socialPost(
        'stories/${Uri.encodeComponent(storyId)}/react',
        {'profileId': profileId, 'reaction': reaction},
        'Unable to react to Story.',
      );

  Future<Map<String, dynamic>> voteSocialStoryPoll({
    required String profileId,
    required String storyId,
    required int optionIndex,
  }) =>
      _socialPost(
        'stories/${Uri.encodeComponent(storyId)}/poll/vote',
        {'profileId': profileId, 'optionIndex': optionIndex},
        'Unable to vote on Story poll.',
      );

  Future<Map<String, dynamic>> reshareSocialStory({
    required String profileId,
    required String storyId,
    int expiresInHours = 24,
  }) =>
      _socialPost(
        'stories/${Uri.encodeComponent(storyId)}/reshare',
        {'profileId': profileId, 'expiresInHours': expiresInHours},
        'Unable to reshare Story.',
      );

  Future<Map<String, dynamic>> createSocialStory({
    required String profileId,
    required String body,
    String? communityId,
    int expiresInHours = 24,
    Map<String, dynamic>? mediaReference,
  }) =>
      _socialPost(
        'stories',
        {
          'profileId': profileId,
          'body': body,
          if (communityId != null) 'communityId': communityId,
          'expiresInHours': expiresInHours,
          if (mediaReference != null) 'mediaReference': mediaReference,
        },
        'Unable to publish story.',
      );

  Future<String> uploadSocialAttachment({
    required String profileId,
    required List<int> bytes,
    required String contentType,
  }) async {
    _requireAuthentication();
    final uri = Uri.parse('$baseUrl/social/attachments').replace(
      queryParameters: {'profileId': profileId},
    );
    final result = await _requireSuccess(
      await http.post(
        uri,
        headers: {
          ..._headers,
          'Content-Type': contentType,
        },
        body: bytes,
      ),
      'Unable to upload attachment.',
    );
    final path = result['attachmentPath']?.toString();
    if (path == null || path.isEmpty) {
      throw BackendApiException(
          'The server did not return an attachment reference.');
    }
    return path;
  }

  Future<Map<String, dynamic>> _socialPatch(
    String path,
    Map<String, dynamic> body,
    String error,
  ) async {
    _requireAuthentication();
    return _requireSuccess(
      await http.patch(
        Uri.parse('$baseUrl/social/$path'),
        headers: _headers,
        body: jsonEncode(body),
      ),
      error,
    );
  }

  Future<Map<String, dynamic>> getSocialMediaNotes({
    required String profileId,
    required String mediaId,
    String? mediaVersionId,
  }) async {
    _requireAuthentication();
    final uri = Uri.parse('$baseUrl/social/notes').replace(
      queryParameters: {
        'profileId': profileId,
        'mediaId': mediaId,
        if (mediaVersionId != null) 'mediaVersionId': mediaVersionId,
      },
    );
    return _requireSuccess(
      await http.get(uri, headers: _headers),
      'Unable to load media notes.',
    );
  }

  Future<Map<String, dynamic>> createSocialMediaNote({
    required String profileId,
    required String mediaId,
    required String mediaVersionId,
    required int positionMilliseconds,
    required String text,
  }) =>
      _socialPost(
        'notes',
        {
          'profileId': profileId,
          'mediaId': mediaId,
          'mediaVersionId': mediaVersionId,
          'positionMilliseconds': positionMilliseconds,
          'text': text,
        },
        'Unable to save media note.',
      );

  Future<Map<String, dynamic>> _socialPost(
      String path, Map<String, dynamic> body, String error) async {
    _requireAuthentication();
    return _requireSuccess(
        await http.post(Uri.parse('$baseUrl/social/$path'),
            headers: _headers, body: jsonEncode(body)),
        error);
  }

  Future<Map<String, dynamic>> sendFriendRequest(
          {required String profileId, required String username}) =>
      _socialPost(
          'friend-request',
          {'profileId': profileId, 'username': username},
          'Unable to send friend request.');

  Future<Map<String, dynamic>> respondFriendRequest(
      {required String profileId,
      required String friendshipId,
      required String action}) async {
    _requireAuthentication();
    return _requireSuccess(
        await http.patch(
            Uri.parse(
                '$baseUrl/social/friend-request/${Uri.encodeComponent(friendshipId)}'),
            headers: _headers,
            body: jsonEncode({'profileId': profileId, 'action': action})),
        'Unable to update friend request.');
  }

  Future<Map<String, dynamic>> createSocialPost({
    required String profileId,
    required String body,
    String? communityId,
    List<String> communityIds = const <String>[],
    Map<String, dynamic>? mediaReference,
  }) =>
      _socialPost(
        'posts',
        {
          'profileId': profileId,
          'body': body,
          if (communityId != null) 'communityId': communityId,
          if (communityIds.isNotEmpty) 'communityIds': communityIds,
          if (mediaReference != null) 'mediaReference': mediaReference,
        },
        'Unable to publish post.',
      );

  Future<Map<String, dynamic>> createSocialCommunity(
          {required String profileId,
          required String name,
          required String description}) =>
      _socialPost(
          'communities',
          {'profileId': profileId, 'name': name, 'description': description},
          'Unable to create community.');

  Future<Map<String, dynamic>> joinSocialCommunity(
          {required String profileId, required String communityId}) =>
      _socialPost(
          'communities/join',
          {'profileId': profileId, 'communityId': communityId},
          'Unable to join community.');

  Future<Map<String, dynamic>> saveAppRecord({
    String? profileId,
    required String recordType,
    required String recordKey,
    Map<String, dynamic> data = const <String, dynamic>{},
  }) async {
    _requireAuthentication();
    return _requireSuccess(
      await http.post(
        Uri.parse('$baseUrl/records'),
        headers: _headers,
        body: jsonEncode({
          'profileId': profileId,
          'recordType': recordType,
          'recordKey': recordKey,
          'data': data,
        }),
      ),
      'Unable to save the application record.',
    );
  }

  /// Records a completed action against a canonical media identity.
  /// Domain state remains owned by its existing likes, playlist, and
  /// collection services; this record provides an authenticated shared event.
  Future<Map<String, dynamic>> recordUniversalMediaAction({
    required String profileId,
    required String action,
    required String contentType,
    required String contentId,
    required String idempotencyKey,
    String? mediaVersionId,
    String? targetId,
  }) async {
    _requireAuthentication();
    return _requireSuccess(
      await http.post(
        Uri.parse('$baseUrl/media-action'),
        headers: _headers,
        body: jsonEncode({
          'profileId': profileId,
          'action': action,
          'contentType': contentType,
          'contentId': contentId,
          'idempotencyKey': idempotencyKey,
          'mediaVersionId': mediaVersionId,
          'targetId': targetId,
        }),
      ),
      'Unable to record the media action.',
    );
  }

  Future<List<Map<String, dynamic>>> getMediaActivity({
    required String profileId,
    int limit = 50,
  }) async {
    _requireAuthentication();
    final uri = Uri.parse('$baseUrl/activity').replace(
      queryParameters: {
        'profileId': profileId,
        'limit': limit.toString(),
      },
    );
    final data = await _requireSuccess(
      await http.get(uri, headers: _headers),
      'Unable to load profile activity.',
    );
    return data['activities'] is List
        ? (data['activities'] as List)
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList(growable: false)
        : <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> getCollaborativeQueue(
      {required String queueId}) async {
    _requireAuthentication();
    return _requireSuccess(
      await http.get(
        Uri.parse('$baseUrl/queue/${Uri.encodeComponent(queueId)}'),
        headers: _headers,
      ),
      'Unable to load collaborative queue.',
    );
  }

  Future<Map<String, dynamic>> updateCollaborativeQueueItem({
    required String queueId,
    required String recordKey,
    int? position,
    bool? skipped,
  }) async {
    _requireAuthentication();
    return _requireSuccess(
      await http.patch(
        Uri.parse(
            '$baseUrl/queue/${Uri.encodeComponent(queueId)}/items/${Uri.encodeComponent(recordKey)}'),
        headers: _headers,
        body: jsonEncode({'position': position, 'skipped': skipped}),
      ),
      'Unable to update collaborative queue item.',
    );
  }

  Future<void> deleteCollaborativeQueueItem(
      {required String queueId, required String recordKey}) async {
    _requireAuthentication();
    await _requireSuccess(
      await http.delete(
        Uri.parse(
            '$baseUrl/queue/${Uri.encodeComponent(queueId)}/items/${Uri.encodeComponent(recordKey)}'),
        headers: _headers,
      ),
      'Unable to remove collaborative queue item.',
    );
  }

  Future<Map<String, dynamic>> createCollaborativeQueue({
    required String profileId,
    String name = 'Shared Queue',
    String mode = 'party',
  }) async {
    _requireAuthentication();
    return _requireSuccess(
      await http.post(
        Uri.parse('$baseUrl/queue'),
        headers: _headers,
        body: jsonEncode({
          'profileId': profileId,
          'name': name,
          'mode': mode,
        }),
      ),
      'Unable to create collaborative queue.',
    );
  }

  Future<Map<String, dynamic>> addCollaborativeQueueItem({
    required String queueId,
    required String profileId,
    required String mediaId,
    required String mediaType,
    required String title,
    String? sourceVersionKey,
  }) async {
    _requireAuthentication();
    return _requireSuccess(
      await http.post(
        Uri.parse('$baseUrl/queue/${Uri.encodeComponent(queueId)}/items'),
        headers: _headers,
        body: jsonEncode({
          'profileId': profileId,
          'mediaId': mediaId,
          'mediaType': mediaType,
          'title': title,
          'sourceVersionKey': sourceVersionKey,
        }),
      ),
      'Unable to add the item to the collaborative queue.',
    );
  }

  Future<Map<String, dynamic>> createShareCard({
    String? profileId,
    required String contentType,
    required String contentId,
    required String title,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    _requireAuthentication();
    return _requireSuccess(
      await http.post(
        Uri.parse('$baseUrl/share-card'),
        headers: _headers,
        body: jsonEncode({
          'profileId': profileId,
          'contentType': contentType,
          'contentId': contentId,
          'title': title,
          'metadata': metadata,
        }),
      ),
      'Unable to create a share card.',
    );
  }

  Future<List<Map<String, dynamic>>> getPaymentMethodCatalog() async {
    _requireAuthentication();
    final data = await _requireSuccess(
      await http.get(
        Uri.parse('$baseUrl/payment-methods'),
        headers: _headers,
      ),
      'Unable to load payment methods.',
    );
    return (data['methods'] is List)
        ? (data['methods'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> saveSellerPaymentMethod({
    required String paymentMethodId,
    required String countryCode,
    required String currencyCode,
    String? providerAccountReference,
    bool verified = false,
  }) async {
    _requireAuthentication();
    return _requireSuccess(
      await http.post(
        Uri.parse('$baseUrl/payment-methods/seller'),
        headers: _headers,
        body: jsonEncode({
          'paymentMethodId': paymentMethodId,
          'countryCode': countryCode,
          'currencyCode': currencyCode,
          'providerAccountReference': providerAccountReference,
          'verified': verified,
        }),
      ),
      'Unable to save seller payment method.',
    );
  }

  Future<List<Map<String, dynamic>>> getSellerPayoutDestinations() async {
    _requireAuthentication();
    final data = await _requireSuccess(
      await http.get(
        Uri.parse('$baseUrl/seller/payout-destinations'),
        headers: _headers,
      ),
      'Unable to load seller payout destinations.',
    );
    return (data['destinations'] is List)
        ? (data['destinations'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> saveSellerPayoutDestination({
    required String providerKey,
    required String methodType,
    required String displayName,
    String? providerAccountReference,
    String? maskedIdentifier,
    bool enabled = true,
  }) async {
    _requireAuthentication();
    return _requireSuccess(
      await http.post(
        Uri.parse('$baseUrl/seller/payout-destinations'),
        headers: _headers,
        body: jsonEncode({
          'providerKey': providerKey,
          'methodType': methodType,
          'displayName': displayName,
          'providerAccountReference': providerAccountReference,
          'maskedIdentifier': maskedIdentifier,
          'enabled': enabled,
        }),
      ),
      'Unable to save seller payout destination.',
    );
  }

  Future<void> deleteSellerPayoutDestination(String id) async {
    _requireAuthentication();
    await _requireSuccess(
      await http.delete(
        Uri.parse('$baseUrl/seller/payout-destinations')
            .replace(queryParameters: {'id': id}),
        headers: _headers,
      ),
      'Unable to delete seller payout destination.',
    );
  }

  Future<List<Map<String, dynamic>>> getShopLiveEvents() async {
    _requireAuthentication();
    final data = await _requireSuccess(
      await http.get(Uri.parse('$baseUrl/shop/live-events'), headers: _headers),
      'Unable to load live shopping events.',
    );
    return (data['events'] is List)
        ? (data['events'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> createShopLiveEvent({
    required String storeId,
    required String storeName,
    required String title,
    required String description,
    required List<String> productIds,
    String? streamUrl,
    String? pinnedProductId,
    DateTime? scheduledAt,
    bool randomizedRewardsEnabled = false,
  }) async {
    _requireAuthentication();
    final data = await _requireSuccess(
      await http.post(Uri.parse('$baseUrl/shop/live-events'),
          headers: _headers,
          body: jsonEncode({
            'storeId': storeId,
            'storeName': storeName,
            'title': title,
            'description': description,
            'productIds': productIds,
            'streamUrl': streamUrl,
            'pinnedProductId': pinnedProductId,
            'scheduledAt': scheduledAt?.toUtc().toIso8601String(),
            'randomizedRewardsEnabled': randomizedRewardsEnabled,
          })),
      'Unable to create the live shopping event.',
    );
    return Map<String, dynamic>.from(data['event'] as Map);
  }

  Future<Map<String, dynamic>> updateShopLiveEvent({
    required String eventId,
    String? status,
    String? streamUrl,
    String? replayUrl,
    String? pinnedProductId,
    Map<String, dynamic>? poll,
    bool? randomizedRewardsEnabled,
  }) async {
    _requireAuthentication();
    final data = await _requireSuccess(
      await http.patch(
          Uri.parse(
              '$baseUrl/shop/live-events/${Uri.encodeComponent(eventId)}'),
          headers: _headers,
          body: jsonEncode({
            if (status != null) 'status': status,
            if (streamUrl != null) 'streamUrl': streamUrl,
            if (replayUrl != null) 'replayUrl': replayUrl,
            if (pinnedProductId != null) 'pinnedProductId': pinnedProductId,
            if (poll != null) 'poll': poll,
            if (randomizedRewardsEnabled != null)
              'randomizedRewardsEnabled': randomizedRewardsEnabled,
          })),
      'Unable to update the live shopping event.',
    );
    return Map<String, dynamic>.from(data['event'] as Map);
  }

  Future<Map<String, dynamic>> askShopLiveQuestion(
      {required String eventId,
      required String profileId,
      required String text}) async {
    _requireAuthentication();
    final data = await _requireSuccess(
      await http.post(
          Uri.parse(
              '$baseUrl/shop/live-events/${Uri.encodeComponent(eventId)}/questions'),
          headers: _headers,
          body: jsonEncode({'profileId': profileId, 'question': text})),
      'Unable to send your question.',
    );
    return Map<String, dynamic>.from(data['event'] as Map);
  }

  Future<Map<String, dynamic>> voteShopLivePoll(
      {required String eventId,
      required String profileId,
      required int optionIndex}) async {
    _requireAuthentication();
    final data = await _requireSuccess(
      await http.post(
          Uri.parse(
              '$baseUrl/shop/live-events/${Uri.encodeComponent(eventId)}/vote'),
          headers: _headers,
          body:
              jsonEncode({'profileId': profileId, 'optionIndex': optionIndex})),
      'Unable to submit your poll vote.',
    );
    return Map<String, dynamic>.from(data['event'] as Map);
  }

  Future<List<Map<String, dynamic>>> filterPaymentMethodsForBuyer({
    required String sellerAccountId,
    required String buyerCountryCode,
    required String currencyCode,
  }) async {
    _requireAuthentication();
    final data = await _requireSuccess(
      await http.post(
        Uri.parse('$baseUrl/payment-methods/filter'),
        headers: _headers,
        body: jsonEncode({
          'sellerAccountId': sellerAccountId,
          'buyerCountryCode': buyerCountryCode,
          'currencyCode': currencyCode,
        }),
      ),
      'Unable to filter payment methods.',
    );
    return (data['methods'] is List)
        ? (data['methods'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];
  }

  // ==========================================================
  // INTERNAL HELPERS
  // ==========================================================

  /// Ensures an authenticated backend token is available.
  void _requireAuthentication() {
    if (!isAuthenticated) {
      throw BackendApiException(
        'You must be logged in before using this feature.',
      );
    }
  }

  /// Validates a successful HTTP response and decodes its JSON body.
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
  // SECURITY
  // ==========================================================

  /// Verifies the authenticated user's security answer.
  Future<bool> verifySecurityAnswer(
    String answer,
  ) async {
    if (!isAuthenticated) {
      return false;
    }

    final response = await http.post(
      Uri.parse('$baseUrl/auth/verify-security'),
      headers: _headers,
      body: jsonEncode({
        'answer': answer,
      }),
    );

    final data = _decodeResponse(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendApiException(
        data['error']?.toString() ?? 'Unable to verify security answer.',
        statusCode: response.statusCode,
      );
    }

    return data['verified'] == true;
  }


  // ==========================================================
  // SERVER CONTEXT
  // ==========================================================

  Future<Map<String, dynamic>> getServerContext() async {
    final response = await http.get(
      Uri.parse('$baseUrl/platform-servers/context'),
      headers: _headers,
    );
    return _requireSuccess(response, 'Unable to load server context.');
  }

  Future<Map<String, dynamic>> claimServer({required String serverId, required String displayName}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/platform-servers/claim'),
      headers: _headers,
      body: jsonEncode({'serverId': serverId, 'displayName': displayName}),
    );
    return _requireSuccess(response, 'Unable to claim server.');
  }

  Future<Map<String, dynamic>> renameServer({required String displayName}) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/platform-servers/name'),
      headers: _headers,
      body: jsonEncode({'displayName': displayName}),
    );
    return _requireSuccess(response, 'Unable to rename server.');
  }

  // ==========================================================
  // GAMES
  // ==========================================================

  Future<List<Map<String, dynamic>>> getGameRatings({required String profileId}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/games/ratings?profileId=${Uri.encodeQueryComponent(profileId)}'),
      headers: _headers,
    );
    final data = await _requireSuccess(response, 'Unable to load game ratings.');
    return data['ratings'] is List
        ? (data['ratings'] as List).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
        : <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> createGameMatch({
    required String profileId,
    required String gameId,
    required String mode,
    String? opponentProfileId,
    String? difficulty,
    String? variant,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/games/matches'),
      headers: _headers,
      body: jsonEncode({
        'profileId': profileId,
        'gameId': gameId,
        'mode': mode,
        if (opponentProfileId != null) 'opponentProfileId': opponentProfileId,
        if (difficulty != null) 'difficulty': difficulty,
        if (variant != null) 'variant': variant,
      }),
    );
    return _requireSuccess(response, 'Unable to create game match.');
  }

  Future<Map<String, dynamic>> submitGameResult({
    required String profileId,
    required String gameId,
    required String mode,
    required String result,
    double? opponentRating,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/games/results'),
      headers: _headers,
      body: jsonEncode({
        'profileId': profileId,
        'gameId': gameId,
        'mode': mode,
        'result': result,
        if (opponentRating != null) 'opponentRating': opponentRating,
      }),
    );
    return _requireSuccess(response, 'Unable to submit game result.');
  }

  // ==========================================================
  // TV CONTROL
  // ==========================================================

  Future<List<Map<String, dynamic>>> getTvPairings() async {
    final response = await http.get(
      Uri.parse('$baseUrl/tv-control/pairings'),
      headers: _headers,
    );
    final data = await _requireSuccess(response, 'Unable to load TV pairings.');
    return data['pairings'] is List
        ? (data['pairings'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> pairTvDevice(
    String code, {
    required String profileId,
    required String phoneDeviceId,
  }) async {
    return pairTv(code: code, phoneDeviceId: phoneDeviceId, profileId: profileId);
  }

  Future<Map<String, dynamic>> createTvPairingCode({required String tvDeviceId, required String tvDeviceName}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/tv-control/pairing-code'),
      headers: _headers,
      body: jsonEncode({'tvDeviceId': tvDeviceId, 'tvDeviceName': tvDeviceName}),
    );
    return _requireSuccess(response, 'Unable to create TV pairing code.');
  }

  Future<Map<String, dynamic>> pairTv({required String code, required String phoneDeviceId, required String profileId}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/tv-control/pair'),
      headers: _headers,
      body: jsonEncode({'code': code, 'phoneDeviceId': phoneDeviceId, 'profileId': profileId}),
    );
    return _requireSuccess(response, 'Unable to pair TV.');
  }

  Future<Map<String, dynamic>> getTvState(String tvDeviceId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/tv-control/state/${Uri.encodeComponent(tvDeviceId)}'),
      headers: _headers,
    );
    final data = await _requireSuccess(response, 'Unable to load TV state.');
    return data['state'] is Map ? Map<String, dynamic>.from(data['state'] as Map) : <String, dynamic>{};
  }

  Future<void> publishTvState({required String tvDeviceId, required Map<String, dynamic> state}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/tv-control/state'),
      headers: _headers,
      body: jsonEncode({'tvDeviceId': tvDeviceId, 'state': state}),
    );
    _requireSuccess(response, 'Unable to publish TV state.');
  }

  Future<void> sendTvCommand({required String tvDeviceId, required String profileId, required Map<String, dynamic> command}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/tv-control/command'),
      headers: _headers,
      body: jsonEncode({'tvDeviceId': tvDeviceId, 'profileId': profileId, 'command': command}),
    );
    _requireSuccess(response, 'Unable to send TV command.');
  }

  Future<List<Map<String, dynamic>>> pollTvCommands(String tvDeviceId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/tv-control/commands/${Uri.encodeComponent(tvDeviceId)}'),
      headers: _headers,
    );
    final data = await _requireSuccess(response, 'Unable to poll TV commands.');
    return data['commands'] is List
        ? (data['commands'] as List).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
        : <Map<String, dynamic>>[];
  }

  // ==========================================================
  // AUTOMATIC TV CHANNEL / CONTENT INTELLIGENCE
  // ==========================================================

  Future<Map<String, dynamic>> getTvChannelCapabilities() async {
    final response = await http.get(
      Uri.parse('$baseUrl/tv-channels/capabilities'),
      headers: _headers,
    );
    return _requireSuccess(response, 'Unable to load TV channel capabilities.');
  }

  Future<List<Map<String, dynamic>>> getTvChannelDefinitions({bool kidsProfile = false}) async {
    final uri = Uri.parse('$baseUrl/tv-channels/definitions').replace(
      queryParameters: {'kids': kidsProfile.toString()},
    );
    final response = await http.get(uri, headers: _headers);
    final data = await _requireSuccess(response, 'Unable to load TV channel definitions.');
    return data['channels'] is List
        ? (data['channels'] as List).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList(growable: false)
        : <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> getTvSeasonalPolicy({bool kidsProfile = false}) async {
    final uri = Uri.parse('$baseUrl/tv-channels/seasonal-policy').replace(
      queryParameters: {'kids': kidsProfile.toString()},
    );
    final response = await http.get(uri, headers: _headers);
    return _requireSuccess(response, 'Unable to load TV seasonal policy.');
  }

  Future<Map<String, dynamic>> classifyTvContent(Map<String, dynamic> media) async {
    final response = await http.post(
      Uri.parse('$baseUrl/tv-channels/classify'),
      headers: _headers,
      body: jsonEncode(media),
    );
    return _requireSuccess(response, 'Unable to classify TV content.');
  }

  // ==========================================================
  // MEDIA DEVICE / PLAYBACK SESSIONS
  // ==========================================================

  Future<Map<String, dynamic>> registerMediaDevice({required String profileId, required String deviceId, required String name, required String type}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/media-intelligence/device'),
      headers: _headers,
      body: jsonEncode({'profileId': profileId, 'id': deviceId, 'name': name, 'type': type}),
    );
    return _requireSuccess(response, 'Unable to register device.');
  }

  Future<Map<String, dynamic>> createPlaybackSession({required String profileId, required String deviceId, String? mediaId, String state = 'idle', double positionSeconds = 0}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/media-intelligence/session'),
      headers: _headers,
      body: jsonEncode({
        'profileId': profileId,
        'deviceId': deviceId,
        if (mediaId != null) 'mediaId': mediaId,
        'state': state,
        'positionSeconds': positionSeconds,
      }),
    );
    return _requireSuccess(response, 'Unable to create playback session.');
  }

  Future<Map<String, dynamic>> updatePlaybackSession({required String sessionId, String? mediaId, String? state, double? positionSeconds}) async {
    final response = await http.put(
      Uri.parse('$baseUrl/media-intelligence/session'),
      headers: _headers,
      body: jsonEncode({
        'id': sessionId,
        if (mediaId != null) 'mediaId': mediaId,
        if (state != null) 'state': state,
        if (positionSeconds != null) 'positionSeconds': positionSeconds,
      }),
    );
    return _requireSuccess(response, 'Unable to update playback session.');
  }

  // ==========================================================
  // RESPONSE DECODING
  // ==========================================================

  /// Decodes a backend HTTP response into a JSON map.
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
