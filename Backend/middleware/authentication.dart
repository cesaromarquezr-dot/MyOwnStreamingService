// FILE: `Backend/middleware/authentication.dart`.
// Purpose: Implements the authentication portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.
//
// Authentication is intentionally kept at the middleware boundary. Route
// handlers can authenticate a request without needing to know how tokens are
// extracted or how accounts are resolved.
//
// Expected header:
//   Authorization: Bearer <token>
//
// No passwords, credentials, or raw authentication tokens are logged or
// persisted by this middleware.

import 'dart:io';

import '../models/account.dart';
import '../services/auth_service.dart';

class AuthenticationMiddleware {
final AuthService authService;

AuthenticationMiddleware({
required this.authService,
});

/// Resolves the authenticated account for [request].
///
/// Returns null when:
/// - the Authorization header is missing;
/// - the authentication scheme is not Bearer;
/// - the Bearer token is empty;
/// - the AuthService cannot resolve the token to an account.
Account? authenticate(
HttpRequest request,
) {
final token = extractToken(request);

if (token == null) {
  return null;
}

return authService.accountFromToken(token);

}

/// Extracts a Bearer token from the Authorization header.
///
/// The authentication scheme comparison is case-insensitive, while the
/// token itself is preserved exactly after surrounding whitespace is
/// removed.
String? extractToken(
HttpRequest request,
) {
final authorization = request.headers.value(
HttpHeaders.authorizationHeader,
);

if (authorization == null) {
  return null;
}

final value = authorization.trim();

if (value.isEmpty) {
  return null;
}

final separator = value.indexOf(' ');

if (separator <= 0) {
  return null;
}

final scheme = value.substring(0, separator);

if (scheme.toLowerCase() != 'bearer') {
  return null;
}

final token = value.substring(separator + 1).trim();

if (token.isEmpty) {
  return null;
}

return token;

}
}
