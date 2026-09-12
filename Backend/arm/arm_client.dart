// FILE: `Backend/arm/arm_client.dart`.
// Purpose: Implements the arm client portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'dart:convert';
import 'dart:io';

class ArmClient {
  final String armServerUrl;

  final Duration timeout;

  ArmClient({
    required this.armServerUrl,
    this.timeout = const Duration(seconds: 15),
  });

  Uri _buildUri(String path) {
    final base = armServerUrl.endsWith('/')
        ? armServerUrl.substring(
            0,
            armServerUrl.length - 1,
          )
        : armServerUrl;

    return Uri.parse('$base$path');
  }

  /// Performs `checkConnection` for this feature. Update this documentation when its contract changes.
  Future<bool> checkConnection() async {
    try {
      final client = HttpClient();

      try {
        final request = await client
            .getUrl(
              _buildUri('/'),
            )
            .timeout(timeout);

        final response = await request.close()
            .timeout(timeout);

        return response.statusCode >= 200 &&
            response.statusCode < 500;
      } finally {
        client.close();
      }
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getJsonMode(String mode) {
    return get('/json?mode=${Uri.encodeQueryComponent(mode)}');
  }

  Future<Map<String, dynamic>> get(
    String path,
  ) async {
    final client = HttpClient();

    try {
      final request = await client
          .getUrl(
            _buildUri(path),
          )
          .timeout(timeout);

      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/json',
      );

      final response = await request
          .close()
          .timeout(timeout);

      final body =
          await utf8.decoder.bind(response).join();

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw ArmClientException(
          'ARM returned HTTP ${response.statusCode}.',
        );
      }

      if (body.trim().isEmpty) {
        return {};
      }

      final decoded = jsonDecode(body);

      if (decoded is! Map) {
        throw ArmClientException(
          'ARM returned an invalid JSON response.',
        );
      }

      return Map<String, dynamic>.from(decoded);
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final client = HttpClient();

    try {
      final request = await client
          .postUrl(
            _buildUri(path),
          )
          .timeout(timeout);

      request.headers.contentType =
          ContentType.json;

      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/json',
      );

      if (body != null) {
        request.write(
          jsonEncode(body),
        );
      }

      final response = await request
          .close()
          .timeout(timeout);

      final responseBody =
          await utf8.decoder.bind(response).join();

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw ArmClientException(
          'ARM returned HTTP ${response.statusCode}.',
        );
      }

      if (responseBody.trim().isEmpty) {
        return {};
      }

      final decoded =
          jsonDecode(responseBody);

      if (decoded is! Map) {
        throw ArmClientException(
          'ARM returned an invalid JSON response.',
        );
      }

      return Map<String, dynamic>.from(decoded);
    } finally {
      client.close();
    }
  }
}


class ArmClientException implements Exception {
  final String message;

  ArmClientException(this.message);

  @override
  /// Performs `toString` for this feature. Update this documentation when its contract changes.
  String toString() {
    return message;
  }
}
