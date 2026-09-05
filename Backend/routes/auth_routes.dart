import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import '../middleware/authentication.dart';
import '../models/subscription.dart';
import '../services/auth_service.dart';
import '../services/payment_service.dart';

class AuthRoutes {
  final AuthService authService;
  final AuthenticationMiddleware authentication;
  final PaymentService paymentService;

  AuthRoutes({
    required this.authService,
    required this.authentication,
    required this.paymentService,
  });

  Future<void> handle(HttpRequest request) async {
    _addCorsHeaders(request.response);

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }

    final path = request.uri.path;

    try {
      // --------------------------------------------------------
      // AUTHENTICATION
      // --------------------------------------------------------

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
          path == '/api/v1/auth/logout') {
        await _logout(request);
        return;
      }

      if (request.method == 'GET' &&
          path == '/api/v1/auth/me') {
        await _me(request);
        return;
      }

      // --------------------------------------------------------
      // PROFILES
      // --------------------------------------------------------

      if (request.method == 'POST' &&
          path == '/api/v1/profiles') {
        await _addProfile(request);
        return;
      }

      if (request.method == 'DELETE' &&
          path.startsWith('/api/v1/profiles/')) {
        await _deleteProfile(request);
        return;
      }

      await _sendJson(
        request.response,
        HttpStatus.notFound,
        {
          'success': false,
          'error': 'Route not found.',
        },
      );
    } catch (error) {
      developer.log(
        'Authentication route error: $error',
        name: 'AuthRoutes',
      );

      if (!request.response.headers.contentType
          .toString()
          .contains('json')) {
        await _sendJson(
          request.response,
          HttpStatus.badRequest,
          {
            'success': false,
            'error': _cleanError(error),
          },
        );
      }
    }
  }

  // ------------------------------------------------------------
  // SIGN UP
  // ------------------------------------------------------------

  Future<void> _signup(
    HttpRequest request,
  ) async {
    final body = await _readJson(request);

    final username = body['username'];
    final email = body['email'];
    final password = body['password'];
    final firstProfileName =
        body['firstProfileName'];

    if (username is! String ||
        email is! String ||
        password is! String ||
        firstProfileName is! String) {
      await _sendJson(
        request.response,
        HttpStatus.badRequest,
        {
          'success': false,
          'error':
              'username, email, password and firstProfileName are required.',
        },
      );

      return;
    }

    final cleanUsername = username.trim();
    final cleanEmail = email.trim();
    final cleanPassword = password;
    final cleanProfileName =
        firstProfileName.trim();

    if (cleanUsername.isEmpty ||
        cleanEmail.isEmpty ||
        cleanPassword.isEmpty ||
        cleanProfileName.isEmpty) {
      await _sendJson(
        request.response,
        HttpStatus.badRequest,
        {
          'success': false,
          'error':
              'username, email, password and firstProfileName cannot be empty.',
        },
      );

      return;
    }

    // ----------------------------------------------------------
    // SUBSCRIPTION PLAN
    // ----------------------------------------------------------

    final planValue =
        body['plan']?.toString().trim().toLowerCase();

    SubscriptionPlan plan;

    if (planValue == 'yearly') {
      plan = SubscriptionPlan.yearly;
    } else if (planValue == 'monthly' ||
        planValue == null ||
        planValue.isEmpty) {
      plan = SubscriptionPlan.monthly;
    } else {
      await _sendJson(
        request.response,
        HttpStatus.badRequest,
        {
          'success': false,
          'error':
              'plan must be either monthly or yearly.',
        },
      );

      return;
    }

    // ----------------------------------------------------------
    // ACCOUNT CREATION
    // ----------------------------------------------------------
    //
    // AuthService creates the account with an INACTIVE
    // subscription.
    //
    // No login session is created here.
    //

    final account = authService.createAccount(
      username: cleanUsername,
      email: cleanEmail,
      password: cleanPassword,
      firstProfileName: cleanProfileName,
      plan: plan,
    );

    // ----------------------------------------------------------
    // PAYMENT CHECKOUT SESSION
    // ----------------------------------------------------------
    //
    // A temporary checkout token is created specifically for
    // completing this signup payment.
    //
    // This is NOT a login token and cannot be used to access
    // the account.
    //
    // The payment service determines the actual price.
    //
    // Raw card/bank information is never passed to AuthRoutes.
    //

    final payment =
        paymentService.createPaymentSession(
      account: account,
      plan: plan,
    );

    // ----------------------------------------------------------
    // SIGNUP RESPONSE
    // ----------------------------------------------------------
    //
    // The frontend should use payment.id and checkoutToken to
    // continue to the payment screen.
    //
    // There is intentionally NO authentication token here.
    //

    await _sendJson(
      request.response,
      HttpStatus.created,
      {
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

  // ------------------------------------------------------------
  // LOGIN
  // ------------------------------------------------------------

  Future<void> _login(
    HttpRequest request,
  ) async {
    final body = await _readJson(request);

    final login = body['login'];
    final password = body['password'];

    if (login is! String ||
        password is! String) {
      await _sendJson(
        request.response,
        HttpStatus.badRequest,
        {
          'success': false,
          'error':
              'login and password are required.',
        },
      );

      return;
    }

    final cleanLogin = login.trim();

    if (cleanLogin.isEmpty ||
        password.isEmpty) {
      await _sendJson(
        request.response,
        HttpStatus.badRequest,
        {
          'success': false,
          'error':
              'login and password cannot be empty.',
        },
      );

      return;
    }

    // AuthService.login() checks the subscription before creating
    // an authentication session.
    //
    // Therefore an unpaid/inactive account cannot log in.
    final token = authService.login(
      login: cleanLogin,
      password: password,
    );

    final account =
        authService.accountFromToken(token);

    await _sendJson(
      request.response,
      HttpStatus.ok,
      {
        'success': true,
        'message': 'Login successful.',
        'token': token,
        'account': account?.toJson(),
      },
    );
  }

  // ------------------------------------------------------------
  // LOGOUT
  // ------------------------------------------------------------

  Future<void> _logout(
    HttpRequest request,
  ) async {
    final account =
        authentication.authenticate(request);

    if (account == null) {
      await _sendUnauthorized(
        request.response,
      );
      return;
    }

    final token =
        _getBearerToken(request);

    if (token != null) {
      authService.logout(token);
    }

    await _sendJson(
      request.response,
      HttpStatus.ok,
      {
        'success': true,
        'message':
            'Logged out successfully.',
      },
    );
  }

  // ------------------------------------------------------------
  // CURRENT ACCOUNT
  // ------------------------------------------------------------

  Future<void> _me(
    HttpRequest request,
  ) async {
    final account =
        authentication.authenticate(request);

    if (account == null) {
      await _sendUnauthorized(
        request.response,
      );
      return;
    }

    await _sendJson(
      request.response,
      HttpStatus.ok,
      {
        'success': true,
        'account': account.toJson(),
      },
    );
  }

  // ------------------------------------------------------------
  // ADD PROFILE
  // ------------------------------------------------------------

  Future<void> _addProfile(
    HttpRequest request,
  ) async {
    final account =
        authentication.authenticate(request);

    if (account == null) {
      await _sendUnauthorized(
        request.response,
      );
      return;
    }

    if (account.profiles.length >= 7) {
      await _sendJson(
        request.response,
        HttpStatus.badRequest,
        {
          'success': false,
          'error':
              'An account can have a maximum of 7 profiles.',
          'profileCount':
              account.profiles.length,
          'maxProfiles': 7,
        },
      );

      return;
    }

    final body = await _readJson(request);

    final name = body['name'];

    if (name is! String) {
      await _sendJson(
        request.response,
        HttpStatus.badRequest,
        {
          'success': false,
          'error':
              'Profile name is required.',
        },
      );

      return;
    }

    final cleanName = name.trim();

    if (cleanName.isEmpty) {
      await _sendJson(
        request.response,
        HttpStatus.badRequest,
        {
          'success': false,
          'error':
              'Profile name cannot be empty.',
        },
      );

      return;
    }

    String? avatarUrl;

    if (body['avatarUrl'] is String) {
      final value =
          (body['avatarUrl'] as String).trim();

      if (value.isNotEmpty) {
        avatarUrl = value;
      }
    }

    final profile = authService.addProfile(
      account: account,
      name: cleanName,
      avatarUrl: avatarUrl,
    );

    await _sendJson(
      request.response,
      HttpStatus.created,
      {
        'success': true,
        'message':
            'Profile created successfully.',
        'profile': profile.toJson(),
        'profileCount':
            account.profiles.length,
        'maxProfiles': 7,
      },
    );
  }

  // ------------------------------------------------------------
  // DELETE PROFILE
  // ------------------------------------------------------------

  Future<void> _deleteProfile(
    HttpRequest request,
  ) async {
    final account =
        authentication.authenticate(request);

    if (account == null) {
      await _sendUnauthorized(
        request.response,
      );
      return;
    }

    const prefix =
        '/api/v1/profiles/';

    final profileId =
        request.uri.path.substring(
      prefix.length,
    );

    if (profileId.trim().isEmpty) {
      await _sendJson(
        request.response,
        HttpStatus.badRequest,
        {
          'success': false,
          'error':
              'Profile ID is required.',
        },
      );

      return;
    }

    authService.removeProfile(
      account: account,
      profileId: profileId,
    );

    await _sendJson(
      request.response,
      HttpStatus.ok,
      {
        'success': true,
        'message':
            'Profile deleted successfully.',
        'profiles': account.profiles.map(
          (profile) {
            return profile.toJson();
          },
        ).toList(),
      },
    );
  }

  // ------------------------------------------------------------
  // READ JSON BODY
  // ------------------------------------------------------------

  Future<Map<String, dynamic>> _readJson(
    HttpRequest request,
  ) async {
    final content =
        await utf8.decoder
            .bind(request)
            .join();

    if (content.trim().isEmpty) {
      return {};
    }

    final decoded = jsonDecode(content);

    if (decoded is! Map) {
      throw Exception(
        'Request body must be a JSON object.',
      );
    }

    return Map<String, dynamic>.from(
      decoded,
    );
  }

  // ------------------------------------------------------------
  // AUTHORIZATION HEADER
  // ------------------------------------------------------------

  String? _getBearerToken(
    HttpRequest request,
  ) {
    final authorization =
        request.headers.value(
      HttpHeaders.authorizationHeader,
    );

    if (authorization == null) {
      return null;
    }

    if (!authorization
        .startsWith('Bearer ')) {
      return null;
    }

    final token =
        authorization.substring(7).trim();

    if (token.isEmpty) {
      return null;
    }

    return token;
  }

  // ------------------------------------------------------------
  // UNAUTHORIZED
  // ------------------------------------------------------------

  Future<void> _sendUnauthorized(
    HttpResponse response,
  ) async {
    await _sendJson(
      response,
      HttpStatus.unauthorized,
      {
        'success': false,
        'error':
            'Authentication required.',
      },
    );
  }

  // ------------------------------------------------------------
  // JSON RESPONSE
  // ------------------------------------------------------------

  Future<void> _sendJson(
    HttpResponse response,
    int statusCode,
    Map<String, dynamic> data,
  ) async {
    response.statusCode = statusCode;

    response.headers.contentType =
        ContentType.json;

    response.write(
      jsonEncode(data),
    );

    await response.close();
  }

  // ------------------------------------------------------------
  // CORS
  // ------------------------------------------------------------

  void _addCorsHeaders(
    HttpResponse response,
  ) {
    response.headers.set(
      'Access-Control-Allow-Origin',
      '*',
    );

    response.headers.set(
      'Access-Control-Allow-Methods',
      'GET, POST, DELETE, OPTIONS',
    );

    response.headers.set(
      'Access-Control-Allow-Headers',
      'Origin, Content-Type, Accept, Authorization',
    );
  }

  // ------------------------------------------------------------
  // ERROR CLEANUP
  // ------------------------------------------------------------

  String _cleanError(Object error) {
    final message = error.toString();

    if (message.startsWith('Exception: ')) {
      return message.substring(11);
    }

    return message;
  }
}