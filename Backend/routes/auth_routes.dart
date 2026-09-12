// FILE: `Backend/routes/auth_routes.dart`.
// Purpose: Implements the auth routes portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import '../middleware/authentication.dart';
import '../models/subscription.dart';
import '../services/auth_service.dart';
import '../services/payment_service.dart';
import '../services/email_service.dart';

class AuthRoutes {
  final AuthService authService;
  final AuthenticationMiddleware authentication;
  final PaymentService paymentService;
  final EmailService emailService;

  AuthRoutes({
    required this.authService,
    required this.authentication,
    required this.paymentService,
    required this.emailService,
  });

  /// Performs `handle` for this feature. Update this documentation when its contract changes.
  Future<void> handle(
    HttpRequest request,
  ) async {
    try {
      final path = request.uri.path;

      // -----------------------------------------------------------------------
      // SIGNUP
      // -----------------------------------------------------------------------

      if (request.method == 'POST' &&
          path == '/api/v1/auth/signup') {
        await _signup(request);
        return;
      }

      // -----------------------------------------------------------------------
      // LOGIN (EMAIL + PASSWORD)
      // -----------------------------------------------------------------------

      if (request.method == 'POST' &&
          path == '/api/v1/auth/login') {
        await _login(request);
        return;
      }

      // -----------------------------------------------------------------------
      // LOGOUT
      // -----------------------------------------------------------------------

      if (request.method == 'POST' &&
          path == '/api/v1/auth/verify-security') {
        await _verifySecurity(request);
        return;
      }

      if (request.method == 'POST' &&
          path == '/api/v1/auth/logout') {
        await _logout(request);
        return;
      }

      // -----------------------------------------------------------------------
      // CURRENT ACCOUNT
      // -----------------------------------------------------------------------

      if (request.method == 'GET' &&
          path == '/api/v1/auth/me') {
        await _me(request);
        return;
      }

      // -----------------------------------------------------------------------
      // CURRENT SESSION
      // -----------------------------------------------------------------------

      if (request.method == 'GET' &&
          path == '/api/v1/auth/session') {
        await _session(request);
        return;
      }

      // -----------------------------------------------------------------------
      // LOGOUT ALL SESSIONS
      // -----------------------------------------------------------------------

      if (request.method == 'POST' &&
          path == '/api/v1/auth/logout-all') {
        await _logoutAll(request);
        return;
      }

      // -----------------------------------------------------------------------
      // PROFILES
      // -----------------------------------------------------------------------

      if (request.method == 'POST' &&
          path == '/api/v1/profiles') {
        await _addProfile(request);
        return;
      }

      if (request.method == 'DELETE' && path == '/api/v1/auth/account') {
        await _deleteAccount(request);
        return;
      }

      if (request.method == 'DELETE' &&
          path.startsWith('/api/v1/profiles/')) {
        await _removeProfile(request);
        return;
      }

      _sendJson(
        request.response,
        statusCode: HttpStatus.notFound,
        body: {
          'success': false,
          'error': 'Authentication route not found.',
        },
      );
    } catch (error, stackTrace) {
      developer.log(
        'Authentication route error.',
        error: error,
        stackTrace: stackTrace,
        name: 'AuthRoutes',
      );

      if (!request.response.headers.contentType
          .toString()
          .contains('application/json')) {
        _sendJson(
          request.response,
          statusCode: HttpStatus.internalServerError,
          body: {
            'success': false,
            'error': _errorMessage(error),
          },
        );
      }
    }
  }

  // ===========================================================================
  // SIGNUP
  // ===========================================================================

  /// Performs `_signup` for this feature. Update this documentation when its contract changes.
  Future<void> _signup(
    HttpRequest request,
  ) async {
    final body =
        await _readJsonBody(request);

    final email =
        _readRequiredString(
      body,
      'email',
    );

    final password =
        _readRequiredString(
      body,
      'password',
    );

    final firstProfileName = body['firstProfileName']?.toString().trim() ?? '';
    final securityQuestion = _readRequiredString(body, 'securityQuestion');
    final securityAnswer = _readRequiredString(body, 'securityAnswer');

    final termsVersion = _readRequiredString(body, 'termsVersion');
    final privacyVersion = _readRequiredString(body, 'privacyVersion');
    final acceptableUseVersion = _readRequiredString(body, 'acceptableUseVersion');
    final legalAcceptedAt = DateTime.tryParse(body['legalAcceptedAt']?.toString() ?? '');
    if (legalAcceptedAt == null) {
      throw HttpException('A valid legal acceptance timestamp is required.');
    }

    final planValue =
        body['plan']
            ?.toString()
            .trim()
            .toLowerCase();

    final plan =
        _parseSubscriptionPlan(
      planValue,
    );

    final account =
        await authService.createAccount(
      email: email,
      password: password,
      plan: plan,
      firstProfileName:
          firstProfileName,
      securityQuestion: securityQuestion,
      securityAnswer: securityAnswer,
      termsVersion: termsVersion,
      privacyVersion: privacyVersion,
      acceptableUseVersion: acceptableUseVersion,
      legalAcceptedAt: legalAcceptedAt.toUtc(),
    );

    // Signup does not create a normal login session.
    //
    // The subscription must be activated through the payment flow first.
    final payment =
        paymentService.createPaymentSession(
      account: account,
      plan: plan,
    );

    _sendJson(
      request.response,
      statusCode: HttpStatus.created,
      body: {
        'success': true,
        'message':
            'Account created. Complete payment to activate your subscription.',
        'paymentRequired': true,
        'account': account.toJson(),
        'subscription':
            account.subscription?.toJson(),
        'payment': payment.toJson(
          includeCheckoutToken: true,
        ),
      },
    );
  }

  /// Performs `_verifySecurity` for this feature. Update this documentation when its contract changes.
  Future<void> _verifySecurity(HttpRequest request) async {
    final token = authentication.extractToken(request);
    if (token == null) {
      _sendAuthenticationRequired(request.response);
      return;
    }
    final body = await _readJsonBody(request);
    final answer = _readRequiredString(body, 'answer');
    final valid = await authService.verifySecurityAnswer(token: token, answer: answer);
    _sendJson(request.response, statusCode: HttpStatus.ok, body: {
      'success': valid,
      'verified': valid,
      'message': valid ? 'Security answer verified.' : 'Incorrect security answer.',
    });
  }

  // ===========================================================================
  // LOGIN
  // ===========================================================================

  /// Performs `_login` for this feature. Update this documentation when its contract changes.
  Future<void> _login(
    HttpRequest request,
  ) async {
    final body =
        await _readJsonBody(request);

    final email =
        _readRequiredString(
      body,
      'email',
    );

    final password =
        _readRequiredString(
      body,
      'password',
    );

    final clientIp =
        request.connectionInfo?.remoteAddress.address ?? 'unknown';
    final userAgent =
        request.headers.value(HttpHeaders.userAgentHeader) ?? 'unknown';

    final loginResult =
        await authService.login(
      login: email,
      password: password,
      ipAddress: clientIp,
      userAgent: userAgent,
    );

    final token = loginResult.token;

    final account =
        authService.accountFromToken(
      token,
    );

    final session =
        authService.sessionFromToken(
      token,
    );

    _sendJson(
      request.response,
      statusCode: HttpStatus.ok,
      body: {
        'success': true,
        'message': 'Login successful.',
        'token': token,
        'expiresAt':
            session?.expiresAt
                .toIso8601String(),
        'account':
            account?.toJson(),
        'security': {
          'suspicious': loginResult.suspicious,
          'reasons': loginResult.reasons,
          'question': account?.securityQuestion,
          'requiresVerification': loginResult.suspicious,
        },
      },
    );
  }

  // ===========================================================================
  // LOGOUT
  // ===========================================================================

  /// Performs `_logout` for this feature. Update this documentation when its contract changes.
  Future<void> _logout(
    HttpRequest request,
  ) async {
    final account =
        authentication.authenticate(
      request,
    );

    if (account == null) {
      _sendAuthenticationRequired(
        request.response,
      );
      return;
    }

    final token =
        authentication.extractToken(
      request,
    );

    if (token == null) {
      _sendAuthenticationRequired(
        request.response,
      );
      return;
    }

    authService.logout(
      token,
    );

    _sendJson(
      request.response,
      statusCode: HttpStatus.ok,
      body: {
        'success': true,
        'message': 'Logged out successfully.',
      },
    );
  }

  // ===========================================================================
  // CURRENT ACCOUNT
  // ===========================================================================

  /// Performs `_me` for this feature. Update this documentation when its contract changes.
  Future<void> _me(
    HttpRequest request,
  ) async {
    final account =
        authentication.authenticate(
      request,
    );

    if (account == null) {
      _sendAuthenticationRequired(
        request.response,
      );
      return;
    }

    _sendJson(
      request.response,
      statusCode: HttpStatus.ok,
      body: {
        'success': true,
        'account': account.toJson(),
      },
    );
  }

  // ===========================================================================
  // CURRENT SESSION
  // ===========================================================================

  /// Performs `_session` for this feature. Update this documentation when its contract changes.
  Future<void> _session(
    HttpRequest request,
  ) async {
    final account =
        authentication.authenticate(
      request,
    );

    if (account == null) {
      _sendAuthenticationRequired(
        request.response,
      );
      return;
    }

    final token =
        authentication.extractToken(
      request,
    );

    if (token == null) {
      _sendAuthenticationRequired(
        request.response,
      );
      return;
    }

    final session =
        authService.sessionFromToken(
      token,
    );

    if (session == null) {
      _sendAuthenticationRequired(
        request.response,
      );
      return;
    }

    _sendJson(
      request.response,
      statusCode: HttpStatus.ok,
      body: {
        'success': true,
        'session': {
          'createdAt':
              session.createdAt
                  .toIso8601String(),
          'expiresAt':
              session.expiresAt
                  .toIso8601String(),
          'lastUsedAt':
              session.lastUsedAt
                  .toIso8601String(),
          'ipAddress': session.ipAddress,
          'userAgent': session.userAgent,
        },
        'accountId': account.id,
      },
    );
  }

  // ===========================================================================
  // LOGOUT ALL
  // ===========================================================================

  /// Performs `_logoutAll` for this feature. Update this documentation when its contract changes.
  Future<void> _logoutAll(
    HttpRequest request,
  ) async {
    final account =
        authentication.authenticate(
      request,
    );

    if (account == null) {
      _sendAuthenticationRequired(
        request.response,
      );
      return;
    }

    authService.logoutAllSessions(
      account.id,
    );

    _sendJson(
      request.response,
      statusCode: HttpStatus.ok,
      body: {
        'success': true,
        'message':
            'All sessions have been logged out.',
      },
    );
  }

  /// Performs `_deleteAccount` for this feature. Update this documentation when its contract changes.
  Future<void> _deleteAccount(HttpRequest request) async {
    final account=authentication.authenticate(request);
    if(account==null){_sendAuthenticationRequired(request.response);return;}
    authService.deleteAccount(account);
    _sendJson(request.response,statusCode:HttpStatus.ok,body:{'success':true,'message':'Account deleted successfully.'});
  }

  // ===========================================================================
  // ADD PROFILE
  // ===========================================================================

  /// Performs `_addProfile` for this feature. Update this documentation when its contract changes.
  Future<void> _addProfile(
    HttpRequest request,
  ) async {
    final account =
        authentication.authenticate(
      request,
    );

    if (account == null) {
      _sendAuthenticationRequired(
        request.response,
      );
      return;
    }

    final body =
        await _readJsonBody(request);

    final name =
        _readRequiredString(
      body,
      'name',
    );

    final avatarUrl =
        body['avatarUrl']?.toString();

    final profile =
        authService.addProfile(
      account: account,
      name: name,
      avatarUrl: avatarUrl,
    );

    await emailService.send(
      to: account.email,
      subject: 'New profile created: ${profile.name}',
      body: 'A new profile named ${profile.name} was created on your personal streaming service.',
    );

    _sendJson(
      request.response,
      statusCode: HttpStatus.created,
      body: {
        'success': true,
        'profile': profile.toJson(),
        'profiles': account.profiles
            .map(
              (profile) =>
                  profile.toJson(),
            )
            .toList(),
        'profileCount':
            account.profiles.length,
        'maxProfiles':7,
      },
    );
  }

  // ===========================================================================
  // REMOVE PROFILE
  // ===========================================================================

  /// Performs `_removeProfile` for this feature. Update this documentation when its contract changes.
  Future<void> _removeProfile(
    HttpRequest request,
  ) async {
    final account =
        authentication.authenticate(
      request,
    );

    if (account == null) {
      _sendAuthenticationRequired(
        request.response,
      );
      return;
    }

    final prefix =
        '/api/v1/profiles/';

    final profileId =
        request.uri.path
            .substring(prefix.length)
            .trim();

    if (profileId.isEmpty) {
      throw Exception(
        'Profile ID is required.',
      );
    }

    authService.removeProfile(
      account: account,
      profileId: profileId,
    );

    _sendJson(
      request.response,
      statusCode: HttpStatus.ok,
      body: {
        'success': true,
        'message':
            'Profile removed successfully.',
        'profiles': account.profiles
            .map(
              (profile) =>
                  profile.toJson(),
            )
            .toList(),
        'profileCount':
            account.profiles.length,
        'maxProfiles':
            7,
      },
    );
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  Future<Map<String, dynamic>>
      _readJsonBody(
    HttpRequest request,
  ) async {
    final body =
        await utf8.decoder
            .bind(request)
            .join();

    if (body.trim().isEmpty) {
      throw Exception(
        'Request body is required.',
      );
    }

    final decoded =
        jsonDecode(body);

    if (decoded is! Map) {
      throw Exception(
        'Request body must be a JSON object.',
      );
    }

    return Map<String, dynamic>.from(
      decoded,
    );
  }

  /// Performs `_readRequiredString` for this feature. Update this documentation when its contract changes.
  String _readRequiredString(
    Map<String, dynamic> body,
    String key,
  ) {
    final value =
        body[key]?.toString().trim();

    if (value == null ||
        value.isEmpty) {
      throw Exception(
        '$key is required.',
      );
    }

    return value;
  }

  SubscriptionPlan
      _parseSubscriptionPlan(
    String? value,
  ) {
    switch (value) {
      case 'yearly':
        return SubscriptionPlan.yearly;

      case 'monthly':
      case null:
      case '':
        return SubscriptionPlan.monthly;

      default:
        throw Exception(
          'Invalid subscription plan.',
        );
    }
  }

  /// Performs `_errorMessage` for this feature. Update this documentation when its contract changes.
  String _errorMessage(
    Object error,
  ) {
    final text =
        error.toString();

    if (text.startsWith(
      'Exception: ',
    )) {
      return text.substring(
        'Exception: '.length,
      );
    }

    return text;
  }

  /// Performs `_sendAuthenticationRequired` for this feature. Update this documentation when its contract changes.
  void _sendAuthenticationRequired(
    HttpResponse response,
  ) {
    _sendJson(
      response,
      statusCode:
          HttpStatus.unauthorized,
      body: {
        'success': false,
        'error':
            'Authentication required.',
      },
    );
  }

  /// Performs `_sendJson` for this feature. Update this documentation when its contract changes.
  void _sendJson(
    HttpResponse response, {
    required int statusCode,
    required Map<String, dynamic> body,
  }) {
    response.statusCode =
        statusCode;

    response.headers.contentType =
        ContentType.json;

    response.write(
      jsonEncode(body),
    );

    response.close();
  }
}
