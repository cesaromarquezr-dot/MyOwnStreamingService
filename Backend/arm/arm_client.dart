// FILE: `Backend/arm/arm_client.dart`.
// Purpose: Provides the authenticated HTTP client used by the backend to
// communicate with ARM (Automated Ripping Machine).
//
// This file is part of the documented Flutter/home-server architecture.
//
// ARM-specific media interpretation belongs in the ARM services/routes.
// This class intentionally remains a transport layer so that physical
// releases, discs, disc contents, movie titles, bonus material, soundtrack
// releases, and canonical music recordings can be implemented above it.

import 'dart:convert';
import 'dart:io';

class ArmClient {
  final String armServerUrl;

  final Duration timeout;

  /// Optional backend-only ARM credentials.
  ///
  /// These values must never be sent to Flutter or persisted in the client.
  final String? username;
  final String? password;

  /// Identifies the streaming-service backend to ARM.
  final String userAgent;

  ArmClient({
    required this.armServerUrl,
    this.timeout = const Duration(seconds: 15),
    this.username,
    this.password,
    this.userAgent = 'StreamingServiceBackend/1.0',
  }) {
    final normalized = armServerUrl.trim();

    if (normalized.isEmpty) {
      throw ArgumentError.value(
        armServerUrl,
        'armServerUrl',
        'ARM server URL cannot be empty.',
      );
    }

    final uri = Uri.tryParse(normalized);

    if (uri == null ||
        !uri.hasScheme ||
        uri.host.trim().isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw ArgumentError.value(
        armServerUrl,
        'armServerUrl',
        'ARM server URL must be a valid HTTP or HTTPS URL.',
      );
    }

    if (timeout <= Duration.zero) {
      throw ArgumentError.value(
        timeout,
        'timeout',
        'ARM client timeout must be greater than zero.',
      );
    }
  }

  Uri _buildUri(String path) {
    final base = armServerUrl.trim().endsWith('/')
        ? armServerUrl.trim().substring(
              0,
              armServerUrl.trim().length - 1,
            )
        : armServerUrl.trim();

    final normalizedPath = path.startsWith('/') ? path : '/$path';

    return Uri.parse('$base$normalizedPath');
  }

  /// Checks whether ARM is reachable and accepts the configured credentials.
  ///
  /// A successful 2xx response means the ARM integration is available.
  /// Authentication failures are deliberately treated as unavailable because
  /// callers generally need to know whether the authenticated integration is
  /// usable, rather than merely whether the TCP endpoint exists.
  Future<bool> checkConnection() async {
    try {
      final response = await _send(
        method: 'GET',
        path: '/',
        includeJsonHeaders: false,
      );

      return response.statusCode >= 200 &&
          response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// Convenience wrapper for ARM's JSON mode endpoint.
  Future<Map<String, dynamic>> getJsonMode(String mode) {
    return get(
      '/json?mode=${Uri.encodeQueryComponent(mode)}',
    );
  }

  /// Performs an authenticated GET request against ARM.
  Future<Map<String, dynamic>> get(
    String path,
  ) async {
    final response = await _send(
      method: 'GET',
      path: path,
    );

    return _decodeJsonResponse(response);
  }

  /// Performs an authenticated POST request against ARM.
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _send(
      method: 'POST',
      path: path,
      body: body,
    );

    return _decodeJsonResponse(response);
  }

  /// Performs an authenticated PUT request against ARM.
  ///
  /// This is useful for future ARM synchronization/reconciliation endpoints
  /// without requiring callers to implement their own HTTP handling.
  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _send(
      method: 'PUT',
      path: path,
      body: body,
    );

    return _decodeJsonResponse(response);
  }

  /// Performs an authenticated DELETE request against ARM.
  ///
  /// DELETE is allowed to return an empty response body. In that case an empty
  /// map is returned.
  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _send(
      method: 'DELETE',
      path: path,
      body: body,
    );

    return _decodeJsonResponse(response);
  }

  Future<_ArmHttpResponse> _send({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    bool includeJsonHeaders = true,
  }) async {
    final client = HttpClient();

    try {
      final uri = _buildUri(path);

      final request = await _openRequest(
        client,
        method,
        uri,
      ).timeout(timeout);

      request.headers.set(
        HttpHeaders.userAgentHeader,
        userAgent,
      );

      if (includeJsonHeaders) {
        request.headers.set(
          HttpHeaders.acceptHeader,
          'application/json',
        );
      }

      _applyAuthentication(request);

      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }

      final response = await request.close().timeout(timeout);

      final responseBody = await utf8.decoder
          .bind(response)
          .join()
          .timeout(timeout);

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw ArmClientException(
          'ARM returned HTTP ${response.statusCode}'
          '${responseBody.trim().isEmpty ? '.' : ': ${_truncate(responseBody)}'}',
          statusCode: response.statusCode,
          responseBody: responseBody,
        );
      }

      return _ArmHttpResponse(
        statusCode: response.statusCode,
        body: responseBody,
      );
    } on ArmClientException {
      rethrow;
    } on SocketException catch (error) {
      throw ArmClientException(
        'Unable to connect to ARM: $error',
      );
    } on HttpException catch (error) {
      throw ArmClientException(
        'ARM HTTP request failed: $error',
      );
    } on FormatException catch (error) {
      throw ArmClientException(
        'ARM returned malformed data: $error',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<HttpClientRequest> _openRequest(
    HttpClient client,
    String method,
    Uri uri,
  ) {
    switch (method.toUpperCase()) {
      case 'GET':
        return client.getUrl(uri);
      case 'POST':
        return client.postUrl(uri);
      case 'PUT':
        return client.putUrl(uri);
      case 'DELETE':
        return client.deleteUrl(uri);
      default:
        throw ArmClientException(
          'Unsupported ARM HTTP method: $method.',
        );
    }
  }

  Map<String, dynamic> _decodeJsonResponse(
    _ArmHttpResponse response,
  ) {
    final body = response.body;

    if (body.trim().isEmpty) {
      return {};
    }

    final decoded = jsonDecode(body);

    if (decoded is! Map) {
      throw ArmClientException(
        'ARM returned an invalid JSON response.',
        statusCode: response.statusCode,
        responseBody: body,
      );
    }

    return Map<String, dynamic>.from(decoded);
  }

  /// Adds HTTP Basic authentication when ARM credentials are configured.
  ///
  /// Credentials remain entirely inside the backend process.
  void _applyAuthentication(
    HttpClientRequest request,
  ) {
    final user = username?.trim() ?? '';
    final secret = password ?? '';

    if (user.isEmpty) {
      return;
    }

    final encoded = base64Encode(
      utf8.encode('$user:$secret'),
    );

    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Basic $encoded',
    );
  }

  String _truncate(
    String value, {
    int maxLength = 2000,
  }) {
    final normalized = value.trim();

    if (normalized.length <= maxLength) {
      return normalized;
    }

    return '${normalized.substring(0, maxLength)}…';
  }
}

class _ArmHttpResponse {
  final int statusCode;
  final String body;

  const _ArmHttpResponse({
    required this.statusCode,
    required this.body,
  });
}

class ArmClientException implements Exception {
  final String message;
  final int? statusCode;
  final String? responseBody;

  ArmClientException(
    this.message, {
    this.statusCode,
    this.responseBody,
  });

  @override
  String toString() {
    return message;
  }
}