// FILE: `Backend/routes/auth_routes.dart`.
//
// Purpose: Implements the authentication, account, profile, session, and
// security routes of the streaming service.
//
// This file is part of the documented Flutter/home-server architecture.
//
// Route responsibilities:
// - authenticate/validate HTTP requests
// - validate request payloads
// - invoke AuthService/PaymentService/EmailService
// - serialize safe account/session responses
// - map expected business failures to HTTP status codes
//
// Authentication, password hashing, session storage, MFA verification,
// account persistence, and payment processing belong to their respective
// services. This route layer must not implement those mechanisms itself.

import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import '../middleware/authentication.dart';
import '../models/account.dart';
import '../models/subscription.dart';
import '../services/auth_service.dart';
import '../services/email_service.dart';
import '../services/payment_service.dart';
import '../supabase_store.dart';

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

  Future<void> handle(HttpRequest request) async {
    _addCorsHeaders(request.response);

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }

    try {
      final path = request.uri.path;

      // ---------------------------------------------------------------------
      // PUBLIC AUTHENTICATION
      // ---------------------------------------------------------------------

      if (request.method == 'POST' &&
          path == '/api/v1/auth/signup') {
        await _signup(request);
        return;
      }

      if (request.method == 'POST' &&
          path == '/api/v1/auth/login') {
        await _login(request);
        return;
      }

      if (request.method == 'POST' &&
          path == '/api/v1/auth/mfa/verify-login') {
        await _mfaVerifyLogin(request);
        return;
      }

      if (request.method == 'POST' &&
          path == '/api/v1/auth/password-recovery/question') {
        await _passwordRecoveryQuestion(request);
        return;
      }

      if (request.method == 'POST' &&
          path == '/api/v1/auth/password-recovery/reset') {
        await _passwordRecoveryReset(request);
        return;
      }

      if (request.method == 'POST' &&
          path == '/api/v1/auth/invitations/accept') {
        await _acceptInvitation(request);
        return;
      }

      // ---------------------------------------------------------------------
      // AUTHENTICATED ACCOUNT / MEMBERSHIP
      // ---------------------------------------------------------------------

      if (request.method == 'POST' &&
          path == '/api/v1/auth/invitations') {
        await _inviteMember(request);
        return;
      }

      if (request.method == 'GET' &&
          path == '/api/v1/auth/members') {
        await _members(request);
        return;
      }

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

      if (request.method == 'POST' &&
          path == '/api/v1/auth/session/rotate') {
        await _rotateSession(request);
        return;
      }

      if (request.method == 'GET' &&
          path == '/api/v1/auth/me') {
        await _me(request);
        return;
      }

      if (request.method == 'PUT' &&
          path == '/api/v1/auth/me') {
        await _updateAccount(request);
        return;
      }

      if (request.method == 'GET' &&
          path == '/api/v1/auth/session') {
        await _session(request);
        return;
      }

      if (request.method == 'POST' &&
          path == '/api/v1/auth/logout-all') {
        await _logoutAll(request);
        return;
      }

      if (request.method == 'DELETE' &&
          path == '/api/v1/auth/account') {
        await _deleteAccount(request);
        return;
      }

      // ---------------------------------------------------------------------
      // SECURITY
      // ---------------------------------------------------------------------

      if (request.method == 'GET' &&
          path == '/api/v1/security/status') {
        await _securityStatus(request);
        return;
      }

      if (request.method == 'GET' &&
          path == '/api/v1/security/sessions') {
        await _securitySessions(request);
        return;
      }

      if (request.method == 'POST' &&
          path == '/api/v1/security/sessions/revoke') {
        await _securityRevokeSession(request);
        return;
      }

      if (request.method == 'POST' &&
          path == '/api/v1/security/password') {
        await _securityPassword(request);
        return;
      }

      if (request.method == 'POST' &&
          path == '/api/v1/security/mfa/start') {
        await _securityMfaStart(request);
        return;
      }

      if (request.method == 'POST' &&
          path == '/api/v1/security/mfa/verify') {
        await _securityMfaVerify(request);
        return;
      }

      if (request.method == 'POST' &&
          path == '/api/v1/security/mfa/disable') {
        await _securityMfaDisable(request);
        return;
      }

      // ---------------------------------------------------------------------
      // PROFILES
      // ---------------------------------------------------------------------

      if (request.method == 'POST' &&
          path == '/api/v1/profiles') {
        await _addProfile(request);
        return;
      }

      if (request.method == 'PUT' &&
          _isProfileItemPath(path)) {
        await _updateProfile(request);
        return;
      }

      if (request.method == 'DELETE' &&
          _isProfileItemPath(path)) {
        await _removeProfile(request);
        return;
      }

      await _sendJson(
        request.response,
        statusCode: HttpStatus.notFound,
        body: {
          'success': false,
          'error': 'Authentication route not found.',
        },
      );
    } on FormatException catch (error, stackTrace) {
      _logRouteError(error, stackTrace);

      await _sendJson(
        request.response,
        statusCode: HttpStatus.badRequest,
        body: {
          'success': false,
          'error': _errorMessage(error),
        },
      );
    } on HttpException catch (error, stackTrace) {
      _logRouteError(error, stackTrace);

      await _sendJson(
        request.response,
        statusCode: _authErrorStatusCode(error.message),
        body: {
          'success': false,
          'error': error.message,
        },
      );
    } on ArgumentError catch (error, stackTrace) {
      _logRouteError(error, stackTrace);

      await _sendJson(
        request.response,
        statusCode: HttpStatus.badRequest,
        body: {
          'success': false,
          'error': _errorMessage(error),
        },
      );
    } catch (error, stackTrace) {
      _logRouteError(error, stackTrace);

      if (!request.response.headers.contentType
          .toString()
          .contains('application/json')) {
        final message = _errorMessage(error);

        await _sendJson(
          request.response,
          statusCode: _authErrorStatusCode(message),
          body: {
            'success': false,
            'error': message,
          },
        );
      }
    }
  }

  // =========================================================================
  // SIGNUP
  // =========================================================================

  Future<void> _signup(HttpRequest request) async {
    final body = await _readJsonBody(request);

    final email = _readRequiredString(body, 'email');
    final password = _readRequiredString(body, 'password');

    // Diagnostic logging intentionally records only the password length.
    // Never log the plaintext password.
    developer.log(
      'Signup password length received: ${password.length}',
      name: 'AuthRoutes',
    );

    final firstProfileName =
        body['firstProfileName']?.toString().trim() ?? '';

    final securityQuestion =
        _readRequiredString(body, 'securityQuestion');

    final securityAnswer =
        _readRequiredString(body, 'securityAnswer');

    final termsVersion =
        _readRequiredString(body, 'termsVersion');

    final privacyVersion =
        _readRequiredString(body, 'privacyVersion');

    final acceptableUseVersion =
        _readRequiredString(body, 'acceptableUseVersion');

    final legalAcceptedAt = DateTime.tryParse(
      body['legalAcceptedAt']?.toString() ?? '',
    );

    if (legalAcceptedAt == null) {
      throw const FormatException(
        'A valid legal acceptance timestamp is required.',
      );
    }

    final planValue = body['plan']
        ?.toString()
        .trim()
        .toLowerCase();

    final plan = _parseSubscriptionPlan(planValue);

    final account = await authService.createAccount(
      email: email,
      password: password,
      plan: plan,
      firstProfileName: firstProfileName,
      securityQuestion: securityQuestion,
      securityAnswer: securityAnswer,
      termsVersion: termsVersion,
      privacyVersion: privacyVersion,
      acceptableUseVersion: acceptableUseVersion,
      legalAcceptedAt: legalAcceptedAt.toUtc(),
    );

    // Signup intentionally does not create a normal login session.
    //
    // The subscription must be activated through the payment flow first.
    final payment = paymentService.createPaymentSession(
      account: account,
      plan: plan,
    );

    await _sendJson(
      request.response,
      statusCode: HttpStatus.created,
      body: {
        'success': true,
        'message':
            'Account created. Complete payment to activate your subscription.',
        'paymentRequired': true,
        'account': account.toJson(),
        'subscription': account.subscription?.toJson(),
        'payment': payment.toJson(
          includeCheckoutToken: true,
        ),
      },
    );
  }

  // =========================================================================
  // INVITATIONS / MEMBERS
  // =========================================================================

  Future<void> _inviteMember(HttpRequest request) async {
    final account = authentication.authenticate(request);

    if (account == null) {
      await _sendAuthenticationRequired(request.response);
      return;
    }

    final body = await _readJsonBody(request);
    final email = _readRequiredString(body, 'email');

    final role =
        body['role']?.toString().trim().toLowerCase() ?? 'member';

    final token = await authService.inviteMember(
      account: account,
      email: email,
      role: role,
    );

    await _sendJson(
      request.response,
      statusCode: HttpStatus.created,
      body: {
        'success': true,
        'message': 'Invitation created.',
        // Development clients can use the token to complete the flow when
        // SMTP is not configured. Persistent storage must contain only the
        // token hash.
        'invitationToken': token,
      },
    );
  }

  Future<void> _members(HttpRequest request) async {
    final account = authentication.authenticate(request);

    if (account == null) {
      await _sendAuthenticationRequired(request.response);
      return;
    }

    final members =
        await SupabaseStore.instance.listAccountMembers(account.id);

    await _sendJson(
      request.response,
      statusCode: HttpStatus.ok,
      body: {
        'success': true,
        'members': members,
      },
    );
  }

  Future<void> _acceptInvitation(HttpRequest request) async {
    final body = await _readJsonBody(request);

    final token = _readRequiredString(body, 'token');
    final email = _readRequiredString(body, 'email');
    final password = body['password']?.toString();

    final result = await authService.acceptMemberInvitation(
      token: token,
      email: email,
      password: password,
    );

    await _sendJson(
      request.response,
      statusCode: HttpStatus.ok,
      body: {
        'success': true,
        'message':
            'Invitation accepted. You are now a member of the account.',
        'membership': result,
      },
    );
  }

  // =========================================================================
  // SECURITY VERIFICATION / PASSWORD RECOVERY
  // =========================================================================

  Future<void> _verifySecurity(HttpRequest request) async {
    final token = authentication.extractToken(request);

    if (token == null) {
      await _sendAuthenticationRequired(request.response);
      return;
    }

    final body = await _readJsonBody(request);
    final answer = _readRequiredString(body, 'answer');

    final valid = await authService.verifySecurityAnswer(
      token: token,
      answer: answer,
    );

    await _sendJson(
      request.response,
      statusCode: HttpStatus.ok,
      body: {
        'success': valid,
        'verified': valid,
        'message': valid
            ? 'Security answer verified.'
            : 'Incorrect security answer.',
      },
    );
  }

  Future<void> _passwordRecoveryQuestion(
    HttpRequest request,
  ) async {
    final body = await _readJsonBody(request);

    final login =
        (body['login'] ?? body['email'])
                ?.toString()
                .trim() ??
            '';

    if (login.isEmpty) {
      throw const FormatException(
        'email is required.',
      );
    }

    final question = authService.getSecurityQuestion(login);

    await _sendJson(
      request.response,
      statusCode: HttpStatus.ok,
      body: {
        'success': true,
        'question': question,
      },
    );
  }

  Future<void> _passwordRecoveryReset(
    HttpRequest request,
  ) async {
    final body = await _readJsonBody(request);

    final login =
        (body['login'] ?? body['email'])
                ?.toString()
                .trim() ??
            '';

    if (login.isEmpty) {
      throw const FormatException(
        'email is required.',
      );
    }

    final securityAnswer =
        _readRequiredString(body, 'securityAnswer');

    final newPassword =
        _readRequiredString(body, 'newPassword');

    await authService.resetPassword(
      login: login,
      securityAnswer: securityAnswer,
      newPassword: newPassword,
    );

    await _sendJson(
      request.response,
      statusCode: HttpStatus.ok,
      body: {
        'success': true,
        'message':
            'Password reset successfully. You can now sign in with your new password.',
      },
    );
  }

  // =========================================================================
  // LOGIN
  // =========================================================================

  Future<void> _login(HttpRequest request) async {
    final body = await _readJsonBody(request);

    // AuthService already supports email/username login. Keep the API
    // compatible by accepting both `login` and the legacy `email` key.
    final login =
        (body['login'] ?? body['email'])
                ?.toString()
                .trim() ??
            '';

    if (login.isEmpty) {
      throw const FormatException(
        'email is required.',
      );
    }

    final password =
        _readRequiredString(body, 'password');

    final clientIp =
        request.connectionInfo?.remoteAddress.address ??
            'unknown';

    final userAgent =
        request.headers.value(
              HttpHeaders.userAgentHeader,
            ) ??
            'unknown';

    final loginResult = await authService.login(
      login: login,
      password: password,
      ipAddress: clientIp,
      userAgent: userAgent,
    );

    if (loginResult.requiresMfa ||
        loginResult.token == null) {
      await _sendJson(
        request.response,
        statusCode: HttpStatus.ok,
        body: {
          'success': true,
          'requiresMfa': true,
          'message':
              'MFA verification is required before a session can be created.',
        },
      );
      return;
    }

    final token = loginResult.token!;

    final account =
        authService.accountFromToken(token);

    final session =
        authService.sessionFromToken(token);

    await _sendJson(
      request.response,
      statusCode: HttpStatus.ok,
      body: {
        'success': true,
        'message': 'Login successful.',
        'token': token,
        'expiresAt':
            session?.expiresAt.toIso8601String(),
        'account': account?.toJson(),
        'security': {
          'suspicious': loginResult.suspicious,
          'reasons': loginResult.reasons,
          'question': account?.securityQuestion,
          'requiresVerification': loginResult.suspicious,
        },
      },
    );
  }

  // =========================================================================
  // MFA LOGIN
  // =========================================================================

  Future<void> _mfaVerifyLogin(
    HttpRequest request,
  ) async {
    final body = await _readJsonBody(request);

    final login =
        (body['login'] ?? body['email'])
                ?.toString()
                .trim() ??
            '';

    if (login.isEmpty) {
      throw const FormatException(
        'email is required.',
      );
    }

    final code =
        _readRequiredString(body, 'code');

    final ip =
        request.connectionInfo?.remoteAddress.address ??
            'unknown';

    final agent =
        request.headers.value(
              HttpHeaders.userAgentHeader,
            ) ??
            'unknown';

    final result = await authService.verifyMfaLogin(
      login: login,
      code: code,
      ipAddress: ip,
      userAgent: agent,
    );

    final token = result.token;

    final session = token == null
        ? null
        : authService.sessionFromToken(token);

    await _sendJson(
      request.response,
      statusCode: HttpStatus.ok,
      body: {
        'success': true,
        'token': token,
        'expiresAt':
            session?.expiresAt.toIso8601String(),
        'requiresMfa': false,
      },
    );
  }

  // =========================================================================
  // LOGOUT / SESSION
  // =========================================================================

  Future<void> _logout(HttpRequest request) async {
    final account =
        authentication.authenticate(request);

    if (account == null) {
      await _sendAuthenticationRequired(
        request.response,
      );
      return;
    }

    final token =
        authentication.extractToken(request);

    if (token == null) {
      await _sendAuthenticationRequired(
        request.response,
      );
      return;
    }

    authService.logout(token);

    await _sendJson(
      request.response,
      statusCode: HttpStatus.ok,
      body: {
        'success': true,
        'message': 'Logged out successfully.',
      },
    );
  }

  Future<void> _session(HttpRequest request) async {
    final account =
        authentication.authenticate(request);

    if (account == null) {
      await _sendAuthenticationRequired(
        request.response,
      );
      return;
    }

    final token =
        authentication.extractToken(request);

    if (token == null) {
      await _sendAuthenticationRequired(
        request.response,
      );
      return;
    }

    final session =
        authService.sessionFromToken(token);

    if (session == null) {
      await _sendAuthenticationRequired(
        request.response,
      );
      return;
    }

    await _sendJson(
      request.response,
      statusCode: HttpStatus.ok,
      body: {
        'success': true,
        'session': {
          'createdAt':
              session.createdAt.toIso8601String(),
          'expiresAt':
              session.expiresAt.toIso8601String(),
          'lastUsedAt':
              session.lastUsedAt.toIso8601String(),
          'ipAddress': session.ipAddress,
          'userAgent': session.userAgent,
        },
        'accountId': account.id,
      },
    );
  }

  Future<void> _rotateSession(
    HttpRequest request,
  ) async {
    final account =
        authentication.authenticate(request);

    if (account == null) {
      await _sendAuthenticationRequired(
        request.response,
      );
      return;
    }

    final oldToken =
        authentication.extractToken(request);

    if (oldToken == null) {
      await _sendAuthenticationRequired(
        request.response,
      );
      return;
    }

    final token =
        authService.rotateSession(oldToken);

    if (token == null) {
      await _sendAuthenticationRequired(
        request.response,
      );
      return;
    }

    final session =
        authService.sessionFromToken(token);

    await _sendJson(
      request.response,
      statusCode: HttpStatus.ok,
      body: {
        'success': true,
        'token': token,
        'expiresAt':
            session?.expiresAt.toIso8601String(),
        'accountId': account.id,
      },
    );
  }

  Future<void> _logoutAll(
    HttpRequest request,
  ) async {
    final account =
        authentication.authenticate(request);

    if (account == null) {
      await _sendAuthenticationRequired(
        request.response,
      );
      return;
    }

    authService.logoutAllSessions(account.id);

    await _sendJson(
      request.response,
      statusCode: HttpStatus.ok,
      body: {
        'success': true,
        'message':
            'All sessions have been logged out.',
      },
    );
  }

  // =========================================================================
  // SECURITY STATUS / SESSIONS
  // =========================================================================

  Future<void> _securityStatus(
    HttpRequest request,
  ) async {
    final account =
        authentication.authenticate(request);

    if (account == null) {
      await _sendAuthenticationRequired(
        request.response,
      );
      return;
    }

    await _sendJson(
      request.response,
      statusCode: HttpStatus.ok,
      body: {
        'success': true,
        'mfaEnabled': account.mfaEnabled,
        'activeSessions':
            databaseSessions(account).length,
        'passwordPolicy': {
          'minimumLength': 10,
          'algorithm': 'Argon2id',
        },
        'secureTransportRequired': true,
        'csrfModel':
            'Bearer-token API; no cookie-authenticated state-changing endpoints',
        'passkeys': {
          'status':
              'available-for-web-webauthn-integration',
          'registered': false,
        },
      },
    );
  }

  List<Map<String, dynamic>> databaseSessions(
    Account account,
  ) {
    return authService.sessionsForAccount(
      account,
      '',
    );
  }

  Future<void> _securitySessions(
    HttpRequest request,
  ) async {
    final account =
        authentication.authenticate(request);

    if (account == null) {
      await _sendAuthenticationRequired(
        request.response,
      );
      return;
    }

    final token =
        authentication.extractToken(request) ?? '';

    await _sendJson(
      request.response,
      statusCode: HttpStatus.ok,
      body: {
        'success': true,
        'sessions':
            authService.sessionsForAccount(
          account,
          token,
        ),
      },
    );
  }

  Future<void> _securityRevokeSession(
    HttpRequest request,
  ) async {
    final account =
        authentication.authenticate(request);

    if (account == null) {
      await _sendAuthenticationRequired(
        request.response,
      );
      return;
    }

    final body = await _readJsonBody(request);

    final sessionId =
        _readRequiredString(body, 'sessionId');

    final revoked =
        authService.revokeSessionById(
      account,
      sessionId,
    );

    await _sendJson(
      request.response,
      statusCode: revoked
          ? HttpStatus.ok
          : HttpStatus.notFound,
      body: {
        'success': revoked,
        'message': revoked
            ? 'Session revoked.'
            : 'Session not found.',
      },
    );
  }

  Future<void> _securityPassword(
    HttpRequest request,
  ) async {
    final account =
        authentication.authenticate(request);

    if (account == null) {
      await _sendAuthenticationRequired(
        request.response,
      );
      return;
    }

    final body = await _readJsonBody(request);

    final currentPassword =
        _readRequiredString(
      body,
      'currentPassword',
    );

    final newPassword =
        _readRequiredString(
      body,
      'newPassword',
    );

    await authService.changePassword(
      account: account,
      currentPassword: currentPassword,
      newPassword: newPassword,
    );

    await _sendJson(
      request.response,
      statusCode: HttpStatus.ok,
      body: {
        'success': true,
        'message':
            'Password changed. All sessions were revoked.',
      },
    );
  }

  Future<void> _securityMfaStart(
    HttpRequest request,
  ) async {
    final account =
        authentication.authenticate(request);

    if (account == null) {
      await _sendAuthenticationRequired(
        request.response,
      );
      return;
    }

    await authService.startMfaEnrollment(account);

    await _sendJson(
      request.response,
      statusCode: HttpStatus.ok,
      body: {
        'success': true,
        'message':
            'MFA verification code sent to the account email.',
      },
    );
  }

  Future<void> _securityMfaVerify(
    HttpRequest request,
  ) async {
    final account =
        authentication.authenticate(request);

    if (account == null) {
      await _sendAuthenticationRequired(
        request.response,
      );
      return;
    }

    final body = await _readJsonBody(request);

    final code =
        _readRequiredString(body, 'code');

    await authService.verifyMfaEnrollment(
      account,
      code,
    );

    await _sendJson(
      request.response,
      statusCode: HttpStatus.ok,
      body: {
        'success': true,
        'mfaEnabled': true,
      },
    );
  }

  Future<void> _securityMfaDisable(
    HttpRequest request,
  ) async {
    final account =
        authentication.authenticate(request);

    if (account == null) {
      await _sendAuthenticationRequired(
        request.response,
      );
      return;
    }

    await authService.disableMfa(account);

    await _sendJson(
      request.response,
      statusCode: HttpStatus.ok,
      body: {
        'success': true,
        'mfaEnabled': false,
      },
    );
  }

  // =========================================================================
  // CURRENT ACCOUNT
  // =========================================================================

  Future<void> _me(HttpRequest request) async {
    final account =
        authentication.authenticate(request);

    if (account == null) {
      await _sendAuthenticationRequired(
        request.response,
      );
      return;
    }

    await _sendJson(
      request.response,
      statusCode: HttpStatus.ok,
      body: {
        'success': true,
        'account': account.toJson(),
      },
    );
  }

  Future<void> _updateAccount(
    HttpRequest request,
  ) async {
    final account =
        authentication.authenticate(request);

    if (account == null) {
      await _sendAuthenticationRequired(
        request.response,
      );
      return;
    }

    final body = await _readJsonBody(request);

    final currentPassword =
        _readRequiredString(
      body,
      'currentPassword',
    );

    final username =
        body.containsKey('username')
            ? body['username']?.toString()
            : null;

    final email =
        body.containsKey('email')
            ? body['email']?.toString()
            : null;

    final updated =
        await authService.updateAccount(
      account: account,
      username: username,
      email: email,
      currentPassword: currentPassword,
    );

    await _sendJson(
      request.response,
      statusCode: HttpStatus.ok,
      body: {
        'success': true,
        'account': updated.toJson(),
      },
    );
  }

  Future<void> _deleteAccount(
    HttpRequest request,
  ) async {
    final account =
        authentication.authenticate(request);

    if (account == null) {
      await _sendAuthenticationRequired(
        request.response,
      );
      return;
    }

    authService.deleteAccount(account);

    await _sendJson(
      request.response,
      statusCode: HttpStatus.ok,
      body: {
        'success': true,
        'message':
            'Account deleted successfully.',
      },
    );
  }

  // =========================================================================
  // PROFILES
  // =========================================================================

  Future<void> _addProfile(
    HttpRequest request,
  ) async {
    final account =
        authentication.authenticate(request);

    if (account == null) {
      await _sendAuthenticationRequired(
        request.response,
      );
      return;
    }

    final body = await _readJsonBody(request);

    final name =
        _readRequiredString(body, 'name');

    final avatarUrl =
        body['avatarUrl']?.toString();

    final profile = authService.addProfile(
      account: account,
      name: name,
      avatarUrl: avatarUrl,
    );

    await emailService.send(
      to: account.email,
      subject:
          'New profile created: ${profile.name}',
      body:
          'A new profile named ${profile.name} was created on your personal streaming service.',
    );

    await _sendJson(
      request.response,
      statusCode: HttpStatus.created,
      body: {
        'success': true,
        'profile': profile.toJson(),
        'profiles': account.profiles
            .map(
              (profile) => profile.toJson(),
            )
            .toList(),
        'profileCount':
            account.profiles.length,
        'maxProfiles': 7,
      },
    );
  }

  Future<void> _updateProfile(
    HttpRequest request,
  ) async {
    final account =
        authentication.authenticate(request);

    if (account == null) {
      await _sendAuthenticationRequired(
        request.response,
      );
      return;
    }

    final profileId =
        _profileIdFromPath(request.uri.path);

    if (profileId == null) {
      throw const FormatException(
        'Profile ID is required.',
      );
    }

    final body = await _readJsonBody(request);

    final name =
        _readRequiredString(body, 'name');

    final avatarUrl =
        body['avatarUrl']?.toString();

    final profile =
        await authService.updateProfile(
      account: account,
      profileId: profileId,
      name: name,
      avatarUrl: avatarUrl,
    );

    await _sendJson(
      request.response,
      statusCode: HttpStatus.ok,
      body: {
        'success': true,
        'profile': profile.toJson(),
      },
    );
  }

  Future<void> _removeProfile(
    HttpRequest request,
  ) async {
    final account =
        authentication.authenticate(request);

    if (account == null) {
      await _sendAuthenticationRequired(
        request.response,
      );
      return;
    }

    final profileId =
        _profileIdFromPath(request.uri.path);

    if (profileId == null) {
      throw const FormatException(
        'Profile ID is required.',
      );
    }

    authService.removeProfile(
      account: account,
      profileId: profileId,
    );

    await _sendJson(
      request.response,
      statusCode: HttpStatus.ok,
      body: {
        'success': true,
        'message':
            'Profile removed successfully.',
        'profiles': account.profiles
            .map(
              (profile) => profile.toJson(),
            )
            .toList(),
        'profileCount':
            account.profiles.length,
        'maxProfiles': 7,
      },
    );
  }

  // =========================================================================
  // PATH HELPERS
  // =========================================================================

  bool _isProfileItemPath(String path) {
    const prefix = '/api/v1/profiles/';

    if (!path.startsWith(prefix)) {
      return false;
    }

    final encodedId =
        path.substring(prefix.length);

    return encodedId.isNotEmpty &&
        !encodedId.contains('/');
  }

  String? _profileIdFromPath(String path) {
    if (!_isProfileItemPath(path)) {
      return null;
    }

    final prefix = '/api/v1/profiles/';
    final encodedId =
        path.substring(prefix.length);

    try {
      final decoded =
          Uri.decodeComponent(encodedId).trim();

      return decoded.isEmpty ? null : decoded;
    } on FormatException {
      return null;
    }
  }

  // =========================================================================
  // HELPERS
  // =========================================================================

  Future<Map<String, dynamic>> _readJsonBody(
    HttpRequest request,
  ) async {
    final body =
        await utf8.decoder.bind(request).join();

    if (body.trim().isEmpty) {
      throw const FormatException(
        'Request body is required.',
      );
    }

    dynamic decoded;

    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const FormatException(
        'Request body contains invalid JSON.',
      );
    }

    if (decoded is! Map) {
      throw const FormatException(
        'Request body must be a JSON object.',
      );
    }

    return Map<String, dynamic>.from(decoded);
  }

  String _readRequiredString(
    Map<String, dynamic> body,
    String key,
  ) {
    final raw = body[key];

    if (raw == null) {
      throw FormatException(
        '$key is required.',
      );
    }

    final value = raw.toString().trim();

    if (value.isEmpty) {
      throw FormatException(
        '$key is required.',
      );
    }

    return value;
  }

  SubscriptionPlan _parseSubscriptionPlan(
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
        throw const FormatException(
          'Invalid subscription plan.',
        );
    }
  }

  // =========================================================================
  // HTTP / ERROR HELPERS
  // =========================================================================

  Future<void> _sendAuthenticationRequired(
    HttpResponse response,
  ) async {
    await _sendJson(
      response,
      statusCode: HttpStatus.unauthorized,
      body: {
        'success': false,
        'error': 'Authentication required.',
      },
    );
  }

  Future<void> _sendJson(
    HttpResponse response, {
    required int statusCode,
    required Map<String, dynamic> body,
  }) async {
    if (response.headers.contentType == null) {
      response.headers.contentType =
          ContentType.json;
    }

    response.statusCode = statusCode;

    response.write(
      jsonEncode(body),
    );

    await response.close();
  }

  void _addCorsHeaders(
    HttpResponse response,
  ) {
    response.headers.set(
      'Access-Control-Allow-Origin',
      '*',
    );

    response.headers.set(
      'Access-Control-Allow-Methods',
      'GET, POST, PUT, DELETE, OPTIONS',
    );

    response.headers.set(
      'Access-Control-Allow-Headers',
      'Origin, Content-Type, Accept, Authorization',
    );
  }

  void _logRouteError(
    Object error,
    StackTrace stackTrace,
  ) {
    developer.log(
      'Authentication route error.',
      error: error,
      stackTrace: stackTrace,
      name: 'AuthRoutes',
    );
  }

  String _errorMessage(Object error) {
    final text = error.toString();

    if (text.startsWith('Exception: ')) {
      return text.substring('Exception: '.length);
    }

    return text;
  }

  int _authErrorStatusCode(String message) {
    final normalized =
        message.toLowerCase();

    if (normalized.contains(
          'invalid email or password',
        ) ||
        normalized.contains(
          'incorrect security answer',
        ) ||
        normalized.contains(
          'could not verify the account recovery',
        ) ||
        normalized.contains(
          'invalid credentials',
        ) ||
        normalized.contains(
          'invalid mfa',
        ) ||
        normalized.contains(
          'incorrect mfa',
        )) {
      return HttpStatus.unauthorized;
    }

    if (normalized.contains(
          'already in use',
        ) ||
        normalized.contains(
          'email address is already',
        ) ||
        normalized.contains(
          'username is already',
        ) ||
        normalized.contains(
          'already exists',
        )) {
      return HttpStatus.conflict;
    }

    if (normalized.contains(
      'authentication required',
    )) {
      return HttpStatus.unauthorized;
    }

    if (normalized.contains(
          'not found',
        ) ||
        normalized.contains(
          'does not exist',
        )) {
      return HttpStatus.notFound;
    }

    if (normalized.contains(
          'forbidden',
        ) ||
        normalized.contains(
          'not permitted',
        ) ||
        normalized.contains(
          'permission denied',
        )) {
      return HttpStatus.forbidden;
    }

    if (normalized.contains(
          'subscription is not active',
        ) ||
        normalized.contains(
          'subscription required',
        )) {
      return HttpStatus.forbidden;
    }

    if (normalized.contains(
          'required',
        ) ||
        normalized.contains(
          'invalid subscription plan',
        ) ||
        normalized.contains(
          'invalid json',
        ) ||
        normalized.contains(
          'password must be at least',
        )) {
      return HttpStatus.badRequest;
    }

    return HttpStatus.internalServerError;
  }
}