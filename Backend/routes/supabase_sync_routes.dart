// FILE: `Backend/routes/supabase_sync_routes.dart`.
// Purpose: Receives authenticated Flutter application state and persists a
// sanitized account snapshot in Supabase through the server-side service role.
//
// Security boundary:
// - The Flutter client never receives the Supabase service-role key.
// - Authentication is performed by the backend before persistence.
// - Client snapshots are treated as untrusted input.
// - Request bodies are bounded before JSON parsing.
// - Profile synchronization is restricted to profiles belonging to the
//   authenticated account by the SupabaseStore/service layer.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../middleware/authentication.dart';
import '../supabase_store.dart';

/// Implements authenticated synchronization from the Flutter client to
/// Supabase.
class SupabaseSyncRoutes {
  final AuthenticationMiddleware authentication;
  final SupabaseStore store;

  static const int _maxBodyBytes = 512 * 1024;
  static const int _maxProfileIdLength = 256;

  SupabaseSyncRoutes({
    required this.authentication,
    SupabaseStore? store,
  }) : store = store ?? SupabaseStore.instance;

  /// Handles the account/profile synchronization endpoints.
  Future<void> handle(HttpRequest request) async {
    try {
      if (request.method == 'OPTIONS') {
        return await _corsPreflight(request.response);
      }

      final path = request.uri.path;

      final isAccountSync =
          path == '/api/v1/supabase/sync/account';

      const profilePrefix =
          '/api/v1/supabase/sync/profile/';

      final isProfileSync =
          path.startsWith(profilePrefix);

      if (request.method != 'POST' ||
          (!isAccountSync && !isProfileSync)) {
        return await _json(
          request.response,
          HttpStatus.notFound,
          {
            'success': false,
            'error': 'Supabase sync route not found.',
          },
        );
      }

      final account = authentication.authenticate(request);

      if (account == null) {
        return await _json(
          request.response,
          HttpStatus.unauthorized,
          {
            'success': false,
            'error': 'Authentication required.',
          },
        );
      }

      if (!store.enabled) {
        return await _json(
          request.response,
          HttpStatus.serviceUnavailable,
          {
            'success': false,
            'error':
                'Supabase persistence is not configured on this backend server.',
          },
        );
      }

      final body = await _body(request);

      if (isAccountSync) {
        await store.syncAccountSnapshot(
          account,
          clientSnapshot: body,
        );

        return await _json(
          request.response,
          HttpStatus.ok,
          {
            'success': true,
            'accountId': account.id,
            'synced': true,
          },
        );
      }

      final profileId = Uri.decodeComponent(
        path.substring(profilePrefix.length),
      ).trim();

      if (profileId.isEmpty) {
        return await _json(
          request.response,
          HttpStatus.badRequest,
          {
            'success': false,
            'error': 'Profile ID is required.',
          },
        );
      }

      if (profileId.length > _maxProfileIdLength) {
        return await _json(
          request.response,
          HttpStatus.badRequest,
          {
            'success': false,
            'error': 'Profile ID is too long.',
          },
        );
      }

      if (_containsControlCharacter(profileId)) {
        return await _json(
          request.response,
          HttpStatus.badRequest,
          {
            'success': false,
            'error': 'Invalid profile ID.',
          },
        );
      }

      await store.saveProfileCustomization(
        accountExternalId: account.id,
        profileExternalId: profileId,
        home: _mapOrNull(body['home']),
        details: _mapOrNull(body['details']),
        platform: _mapOrNull(body['platform']),
        music: _mapOrNull(body['music']),
      );

      return await _json(
        request.response,
        HttpStatus.ok,
        {
          'success': true,
          'accountId': account.id,
          'profileId': profileId,
          'synced': true,
        },
      );
    } on FormatException catch (e, stackTrace) {
      stderr.writeln('Supabase sync validation error: $e');
      stderr.writeln(stackTrace);

      return await _json(
        request.response,
        HttpStatus.badRequest,
        {
          'success': false,
          'error': _safeFormatError(e),
        },
      );
    } catch (e, stackTrace) {
      stderr.writeln('Supabase sync route error: $e');
      stderr.writeln(stackTrace);

      return await _json(
        request.response,
        HttpStatus.internalServerError,
        {
          'success': false,
          'error':
              'An internal synchronization error occurred.',
        },
      );
    }
  }

  /// Reads and validates a bounded JSON request body.
  Future<Map<String, dynamic>> _body(
    HttpRequest request,
  ) async {
    final contentLength = request.contentLength;

    if (contentLength > _maxBodyBytes) {
      throw const FormatException(
        'Request body is too large.',
      );
    }

    final bytes = <int>[];
    var totalBytes = 0;

    await for (final chunk in request) {
      totalBytes += chunk.length;

      if (totalBytes > _maxBodyBytes) {
        throw const FormatException(
          'Request body is too large.',
        );
      }

      bytes.addAll(chunk);
    }

    if (bytes.isEmpty) {
      return <String, dynamic>{};
    }

    final text = utf8.decode(
      Uint8List.fromList(bytes),
      allowMalformed: false,
    );

    if (text.trim().isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(text);

    if (decoded is! Map) {
      throw const FormatException(
        'JSON object required.',
      );
    }

    return Map<String, dynamic>.from(decoded);
  }

  /// Converts an optional JSON object into the expected map type.
  ///
  /// Invalid section types are rejected rather than silently converted to
  /// empty maps. This prevents a malformed client snapshot from appearing
  /// to have synchronized successfully.
  Map<String, dynamic>? _mapOrNull(Object? value) {
    if (value == null) {
      return null;
    }

    if (value is! Map) {
      throw const FormatException(
        'Synchronization sections must be JSON objects.',
      );
    }

    return Map<String, dynamic>.from(value);
  }

  bool _containsControlCharacter(String value) {
    for (final codeUnit in value.codeUnits) {
      if (codeUnit < 0x20 || codeUnit == 0x7f) {
        return true;
      }
    }

    return false;
  }

  String _safeFormatError(FormatException error) {
    final message = error.message.trim();

    if (message.isEmpty) {
      return 'Invalid request.';
    }

    return message;
  }

  Future<void> _corsPreflight(
    HttpResponse response,
  ) async {
    _applySecurityHeaders(response);

    response.headers.set(
      'Access-Control-Allow-Origin',
      '*',
    );
    response.headers.set(
      'Access-Control-Allow-Methods',
      'POST, OPTIONS',
    );
    response.headers.set(
      'Access-Control-Allow-Headers',
      'Authorization, Content-Type',
    );
    response.headers.set(
      'Access-Control-Max-Age',
      '600',
    );

    response.statusCode = HttpStatus.noContent;
    await response.close();
  }

  /// Writes a JSON response with API security headers.
  Future<void> _json(
    HttpResponse response,
    int status,
    Map<String, dynamic> data,
  ) async {
    _applySecurityHeaders(response);

    response.headers.set(
      'Access-Control-Allow-Origin',
      '*',
    );
    response.headers.contentType = ContentType.json;
    response.statusCode = status;

    response.write(jsonEncode(data));
    await response.close();
  }

  void _applySecurityHeaders(HttpResponse response) {
    response.headers.set(
      'Cache-Control',
      'no-store, no-cache, must-revalidate',
    );
    response.headers.set(
      'Pragma',
      'no-cache',
    );
    response.headers.set(
      'X-Content-Type-Options',
      'nosniff',
    );
  }
}