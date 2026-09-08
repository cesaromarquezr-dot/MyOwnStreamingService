import 'dart:io';

import '../models/account.dart';
import '../services/auth_service.dart';

class AuthenticationMiddleware {
  final AuthService authService;

  AuthenticationMiddleware({
    required this.authService,
  });

  Account? authenticate(
    HttpRequest request,
  ) {
    final authorization =
        request.headers.value(
      HttpHeaders.authorizationHeader,
    );

    if (authorization == null) {
      return null;
    }

    if (!authorization.startsWith(
      'Bearer ',
    )) {
      return null;
    }

    final token =
        authorization.substring(7).trim();

    if (token.isEmpty) {
      return null;
    }

    return authService.accountFromToken(
      token,
    );
  }

  String? extractToken(
    HttpRequest request,
  ) {
    final authorization =
        request.headers.value(
      HttpHeaders.authorizationHeader,
    );

    if (authorization == null) {
      return null;
    }

    if (!authorization.startsWith(
      'Bearer ',
    )) {
      return null;
    }

    final token =
        authorization.substring(7).trim();

    if (token.isEmpty) {
      return null;
    }

    return token;
  }
}