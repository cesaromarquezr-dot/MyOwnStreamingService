import 'dart:convert';
import 'dart:io';

import '../middleware/authentication.dart';
import '../models/subscription.dart';
import '../services/auth_service.dart';

class AuthRoutes {
  final AuthService authService;
  final AuthenticationMiddleware authentication;

  AuthRoutes({
    required this.authService,
    required this.authentication,
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

  Future<void> _signup(
    HttpRequest request,
  ) async {
    final body = await _readJson(request);

    final username = body['username'];
    final email = body['email'];
    final password = body['password'];
    final firstProfileName = body['firstProfileName'];

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

    final planValue = body['plan'];

    SubscriptionPlan plan;

    if (planValue == 'yearly') {
      plan = SubscriptionPlan.yearly;
    } else if (planValue == 'monthly' ||
        planValue == null) {
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

    final account = authService.createAccount(
      username: username,
      email: email,
      password: password,
      firstProfileName: firstProfileName,
      plan: plan,
    );

    final token = authService.login(
      login: username,
      password: password,
    );

    await _sendJson(
      request.response,
      HttpStatus.created,
      {
        'success': true,
        'message': 'Account created successfully.',
        'token': token,
        'account': account.toJson(),
      },
    );
  }

  Future<void> _login(
    HttpRequest request,
  ) async {
    final body = await _readJson(request);

    final login = body['login'];
    final password = body['password'];

    if (login is! String || password is! String) {
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

    final token = authService.login(
      login: login,
      password: password,
    );

    final account = authService.accountFromToken(token);

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

  Future<void> _logout(
    HttpRequest request,
  ) async {
    final account = authentication.authenticate(request);

    if (account == null) {
      await _sendUnauthorized(request.response);
      return;
    }

    final token = _getBearerToken(request);

    if (token != null) {
      authService.logout(token);
    }

    await _sendJson(
      request.response,
      HttpStatus.ok,
      {
        'success': true,
        'message': 'Logged out successfully.',
      },
    );
  }

  Future<void> _me(
    HttpRequest request,
  ) async {
    final account = authentication.authenticate(request);

    if (account == null) {
      await _sendUnauthorized(request.response);
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

  Future<void> _addProfile(
    HttpRequest request,
  ) async {
    final account = authentication.authenticate(request);

    if (account == null) {
      await _sendUnauthorized(request.response);
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
          'error': 'Profile name is required.',
        },
      );

      return;
    }

    String? avatarUrl;

    if (body['avatarUrl'] is String) {
      avatarUrl = body['avatarUrl'];
    }

    final profile = authService.addProfile(
      account: account,
      name: name,
      avatarUrl: avatarUrl,
    );

    await _sendJson(
      request.response,
      HttpStatus.created,
      {
        'success': true,
        'message': 'Profile created successfully.',
        'profile': profile.toJson(),
        'profileCount': account.profiles.length,
        'maxProfiles': 7,
      },
    );
  }

  Future<void> _deleteProfile(
    HttpRequest request,
  ) async {
    final account = authentication.authenticate(request);

    if (account == null) {
      await _sendUnauthorized(request.response);
      return;
    }

    final prefix = '/api/v1/profiles/';

    final profileId = request.uri.path.substring(
      prefix.length,
    );

    if (profileId.isEmpty) {
      await _sendJson(
        request.response,
        HttpStatus.badRequest,
        {
          'success': false,
          'error': 'Profile ID is required.',
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
        'message': 'Profile deleted successfully.',
        'profiles': account.profiles.map(
          (profile) {
            return profile.toJson();
          },
        ).toList(),
      },
    );
  }

  Future<Map<String, dynamic>> _readJson(
    HttpRequest request,
  ) async {
    final content = await utf8.decoder.bind(request).join();

    if (content.trim().isEmpty) {
      return {};
    }

    final decoded = jsonDecode(content);

    if (decoded is! Map) {
      throw Exception(
        'Request body must be a JSON object.',
      );
    }

    return Map<String, dynamic>.from(decoded);
  }

  String? _getBearerToken(
    HttpRequest request,
  ) {
    final authorization = request.headers.value(
      HttpHeaders.authorizationHeader,
    );

    if (authorization == null) {
      return null;
    }

    if (!authorization.startsWith('Bearer ')) {
      return null;
    }

    final token = authorization.substring(7).trim();

    if (token.isEmpty) {
      return null;
    }

    return token;
  }

  Future<void> _sendUnauthorized(
    HttpResponse response,
  ) async {
    await _sendJson(
      response,
      HttpStatus.unauthorized,
      {
        'success': false,
        'error': 'Authentication required.',
      },
    );
  }

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

  String _cleanError(Object error) {
    final message = error.toString();

    if (message.startsWith('Exception: ')) {
      return message.substring(11);
    }

    return message;
  }
}