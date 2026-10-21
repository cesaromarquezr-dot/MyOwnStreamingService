// FILE: `lib/backend_api.dart`.
// Purpose: Implements the backend api portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'privacy_preferences.dart';

part 'backend_api_parts/account.dart';
part 'backend_api_parts/library.dart';
part 'backend_api_parts/groups.dart';
part 'backend_api_parts/server.dart';
part 'backend_api_parts/commerce.dart';
part 'backend_api_parts/admin.dart';
part 'backend_api_parts/discovery.dart';
part 'backend_api_parts/social.dart';
part 'backend_api_parts/collaboration.dart';
part 'backend_api_parts/commerce_platform.dart';
part 'backend_api_parts/devices.dart';
part 'backend_api_parts/support.dart';

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
