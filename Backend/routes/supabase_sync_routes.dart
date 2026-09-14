// FILE: `Backend/routes/supabase_sync_routes.dart`.
// Purpose: Receives authenticated Flutter application state and persists a
// sanitized account snapshot in Supabase through the server-side service role.

import 'dart:convert';
import 'dart:io';

import '../middleware/authentication.dart';
import '../supabase_store.dart';

/// Implements authenticated synchronization from the Flutter client to Supabase.
class SupabaseSyncRoutes {
  final AuthenticationMiddleware authentication;
  final SupabaseStore store;

  SupabaseSyncRoutes({
    required this.authentication,
    SupabaseStore? store,
  }) : store = store ?? SupabaseStore.instance;

  /// Handles the account snapshot upload endpoint.
  Future<void> handle(HttpRequest request) async {
    try {
      final path = request.uri.path;
      if (request.method != 'POST' ||
          (path != '/api/v1/supabase/sync/account' &&
              !path.startsWith('/api/v1/supabase/sync/profile/'))) {
        return await _json(request.response, 404, {'success': false, 'error': 'Supabase sync route not found.'});
      }

      final account = authentication.authenticate(request);
      if (account == null) {
        return await _json(request.response, 401, {'success': false, 'error': 'Authentication required.'});
      }

      if (!store.enabled) {
        return await _json(request.response, 503, {
          'success': false,
          'error': 'Supabase persistence is not configured on this backend server.',
        });
      }

      final body = await _body(request);

      if (path == '/api/v1/supabase/sync/account') {
        await store.syncAccountSnapshot(account, clientSnapshot: body);
        return await _json(request.response, 200, {
          'success': true,
          'accountId': account.id,
          'synced': true,
        });
      }

      final prefix = '/api/v1/supabase/sync/profile/';
      final profileId = Uri.decodeComponent(path.substring(prefix.length)).trim();
      if (profileId.isEmpty) {
        return await _json(request.response, 400, {'success': false, 'error': 'Profile ID is required.'});
      }

      await store.saveProfileCustomization(
        accountExternalId: account.id,
        profileExternalId: profileId,
        home: body['home'] is Map
            ? Map<String, dynamic>.from(body['home'] as Map)
            : null,
        details: body['details'] is Map
            ? Map<String, dynamic>.from(body['details'] as Map)
            : null,
        platform: body['platform'] is Map
            ? Map<String, dynamic>.from(body['platform'] as Map)
            : null,
      );

      return await _json(request.response, 200, {
        'success': true,
        'accountId': account.id,
        'profileId': profileId,
        'synced': true,
      });
    } catch (e) {
      return await _json(request.response, 400, {
        'success': false,
        'error': e.toString().replaceFirst('Exception: ', ''),
      });
    }
  }

  /// Reads and validates the JSON request body.
  Future<Map<String, dynamic>> _body(HttpRequest request) async {
    final text = await utf8.decoder.bind(request).join();
    if (text.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(text);
    if (decoded is! Map) throw Exception('JSON object required.');
    return Map<String, dynamic>.from(decoded);
  }

  /// Writes a JSON response.
  Future<void> _json(HttpResponse response, int status, Map<String, dynamic> data) async {
    response.statusCode = status;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(data));
    await response.close();
  }
}
