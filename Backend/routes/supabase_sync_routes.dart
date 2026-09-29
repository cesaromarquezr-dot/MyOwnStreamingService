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
import 'dart:math';
import 'dart:typed_data';

import '../middleware/authentication.dart';
import '../models/account.dart';
import '../supabase_store.dart';

/// Implements authenticated synchronization from the Flutter client to
/// Supabase.
class SupabaseSyncRoutes {
  final AuthenticationMiddleware authentication;
  final SupabaseStore store;

  static const int _maxBodyBytes = 512 * 1024;
  static const int _maxProfileIdLength = 256;
  final Map<String, Map<String, dynamic>> _memoryRecords = {};

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

      final isMediaGraph = path.startsWith('/api/v1/phase2/');

      if (!isMediaGraph &&
          (request.method != 'POST' || (!isAccountSync && !isProfileSync))) {
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

      if (isMediaGraph) {
        return await _handleMediaGraph(request, account);
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
    } on ArgumentError catch (e, stackTrace) {
      stderr.writeln('Supabase sync validation error: $e');
      stderr.writeln(stackTrace);
      return await _json(request.response, HttpStatus.badRequest, {
        'success': false,
        'error': e.message?.toString() ?? 'Invalid request.',
      });
    } on StateError catch (e, stackTrace) {
      stderr.writeln('Supabase sync validation error: $e');
      stderr.writeln(stackTrace);
      return await _json(request.response, HttpStatus.badRequest, {
        'success': false,
        'error': e.message,
      });
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

  Future<void> _handleMediaGraph(HttpRequest request, Account account) async {
    final path = request.uri.path;
    if (request.method == 'GET' && path == '/api/v1/phase2/features') {
      return _json(request.response, HttpStatus.ok, {
        'success': true,
        'features': ['records', 'media_actions', 'collaborative_queues', 'share_cards', 'payment_methods', 'seller_payout_destinations'],
      });
    }
    if (path == '/api/v1/phase2/media-action' && request.method == 'POST') {
      final body = await _body(request);
      final profile = _ownedProfile(
        account,
        _requiredText(body, 'profileId', _maxProfileIdLength),
      );
      final action = _requiredText(body, 'action', 40);
      const supportedActions = <String>{
        'like',
        'dislike',
        'remove_reaction',
        'add_to_playlist',
        'remove_from_playlist',
        'add_to_collection',
        'remove_from_collection',
        'queue',
        'share',
        'rate',
        'review',
        'wishlist',
      };
      if (!supportedActions.contains(action)) {
        throw const FormatException('Unsupported media action.');
      }
      final contentType = _requiredText(body, 'contentType', 80);
      final contentId = _requiredText(body, 'contentId', 256);
      final idempotencyKey = _requiredText(body, 'idempotencyKey', 200);
      final targetId = _optionalText(body, 'targetId', 256);
      const targetActions = <String>{
        'add_to_playlist',
        'remove_from_playlist',
        'add_to_collection',
        'remove_from_collection',
      };
      if (targetActions.contains(action) && targetId == null) {
        throw const FormatException('A destination ID is required for this action.');
      }
      final versionId = _optionalText(body, 'mediaVersionId', 256);
      final record = await _saveRecord(
        account.id,
        profile,
        'universal_media_action',
        idempotencyKey,
        <String, dynamic>{
          'action': action,
          'contentType': contentType,
          'contentId': contentId,
          if (versionId != null) 'mediaVersionId': versionId,
          if (targetId != null) 'targetId': targetId,
          'idempotencyKey': idempotencyKey,
        },
      );
      return _json(request.response, HttpStatus.ok, {
        'success': true,
        'action': record,
      });
    }

      if (path == '/api/v1/phase2/records') {
      if (request.method == 'GET') {
        final profile = _ownedProfile(account, request.uri.queryParameters['profileId']);
        final type = request.uri.queryParameters['recordType'];
        final records = await _records(account.id, profile, type);
        records.removeWhere((record) =>
            const {'xray_private_note', 'xray_profile_settings'}
                .contains(record['recordType']) &&
            (profile == null || record['profileId'] != profile));
        return _json(request.response, HttpStatus.ok, {'success': true, 'records': records});
      }
      if (request.method == 'POST') {
        final body = await _body(request);
        final profile = _ownedProfile(account, body['profileId']?.toString());
        final type = _requiredText(body, 'recordType', 120);
        final key = _requiredText(body, 'recordKey', 240);
        final data = body['data'] is Map ? Map<String, dynamic>.from(body['data'] as Map) : <String, dynamic>{};
        _validateProfileRecord(type, key, profile, data);
        final record = await _saveRecord(account.id, profile, type, key, data);
        return _json(request.response, HttpStatus.ok, {'success': true, 'record': record});
      }
      if (request.method == 'DELETE') {
        final profile = _ownedProfile(account, request.uri.queryParameters['profileId']);
        final type = request.uri.queryParameters['recordType']?.trim() ?? '';
        final key = request.uri.queryParameters['recordKey']?.trim() ?? '';
        if (type.isEmpty || key.isEmpty) throw const FormatException('recordType and recordKey are required.');
        await store.deletePhase2Record(accountExternalId: account.id, profileExternalId: profile, recordType: type, recordKey: key);
        _memoryRecords.remove(_recordId(account.id, profile, type, key));
        return _json(request.response, HttpStatus.ok, {'success': true});
      }
    }
    if (path == '/api/v1/phase2/share-card' && request.method == 'POST') {
      final body = await _body(request);
      final profile = _ownedProfile(account, body['profileId']?.toString());
      final metadata = body['metadata'] is Map ? Map<String, dynamic>.from(body['metadata'] as Map) : <String, dynamic>{};
      final record = await _saveRecord(account.id, profile, 'share_card', DateTime.now().microsecondsSinceEpoch.toString(), {
        'contentType': _requiredText(body, 'contentType', 80),
        'contentId': _requiredText(body, 'contentId', 256),
        'title': _requiredText(body, 'title', 500),
        'metadata': metadata,
      });
      return _json(request.response, HttpStatus.created, {'success': true, 'shareCard': record});
    }
    if (path == '/api/v1/phase2/queue' && request.method == 'POST') {
      final body = await _body(request);
      final profile = _ownedProfile(account, body['profileId']?.toString());
      final id = 'queue_${DateTime.now().microsecondsSinceEpoch}';
      final record = await _saveRecord(account.id, profile, 'collaborative_queue', id, {
        'queueId': id, 'profileId': profile,
        'name': _optionalText(body, 'name', 120) ?? 'Shared Queue',
        'mode': _optionalText(body, 'mode', 40) ?? 'party', 'items': <dynamic>[],
      });
      return _json(request.response, HttpStatus.created, {'success': true, 'queue': record['data']});
    }
    if (path.startsWith('/api/v1/phase2/queue/')) {
      return _handleQueue(request, account);
    }
    return _json(request.response, HttpStatus.notFound, {'success': false, 'error': 'Route not found.'});
  }

  Future<List<Map<String, dynamic>>> _records(String accountId, String? profileId, String? type) async {
    final saved = await store.loadPhase2Records(accountExternalId: accountId, profileExternalId: profileId, recordType: type);
    final prefix = profileId == null ? '$accountId|' : '$accountId|$profileId|';
    final combined = <String, Map<String, dynamic>>{
      for (final record in saved) '${record['recordType']}|${record['recordKey']}': record,
      for (final entry in _memoryRecords.entries.where((entry) => entry.key.startsWith(prefix)))
        if (type == null || entry.value['recordType'] == type) '${entry.value['recordType']}|${entry.value['recordKey']}': entry.value,
    };
    return combined.values.toList()..sort((a, b) => '${b['updatedAt']}'.compareTo('${a['updatedAt']}'));
  }

  Future<Map<String, dynamic>> _saveRecord(String accountId, String? profileId, String type, String key, Map<String, dynamic> data) async {
    final id = _recordId(accountId, profileId, type, key);
    final previous = _memoryRecords[id];
    final record = <String, dynamic>{
      'id': previous?['id'] ?? _uuid(), 'accountId': accountId, 'profileId': profileId,
      'recordType': type, 'recordKey': key, 'data': Map<String, dynamic>.from(data),
      'createdAt': previous?['createdAt'] ?? DateTime.now().toUtc().toIso8601String(),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };
    await store.upsertPhase2Record(accountExternalId: accountId, profileExternalId: profileId, recordType: type, recordKey: key, recordId: record['id'] as String, data: record['data'] as Map<String, dynamic>);
    _memoryRecords[id] = record;
    return record;
  }

  Future<void> _handleQueue(HttpRequest request, dynamic account) async {
    const prefix = '/api/v1/phase2/queue/';
    final parts = request.uri.path.substring(prefix.length).split('/').map(Uri.decodeComponent).toList();
    if (parts.isEmpty || parts.first.isEmpty) return _json(request.response, HttpStatus.notFound, {'success': false, 'error': 'Queue not found.'});
    final id = parts.first;
    final records = await _records(account.id, null, 'collaborative_queue');
    final index = records.indexWhere((record) => record['recordKey'] == id);
    if (index < 0) return _json(request.response, HttpStatus.notFound, {'success': false, 'error': 'Queue not found.'});
    final record = records[index];
    final data = Map<String, dynamic>.from(record['data'] as Map);
    final items = (data['items'] as List? ?? const []).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
    if (parts.length == 1 && request.method == 'GET') return _json(request.response, HttpStatus.ok, {'success': true, 'queue': {...data, 'items': items}});
    if (parts.length == 2 && parts[1] == 'items' && request.method == 'POST') {
      final body = await _body(request);
      final profile = _ownedProfile(account, body['profileId']?.toString());
      if (data['profileId'] != profile) return _json(request.response, HttpStatus.forbidden, {'success': false, 'error': 'Queue belongs to another profile.'});
      final mediaId = _requiredText(body, 'mediaId', 256);
      if (items.any((item) => item['mediaId'] == mediaId)) return _json(request.response, HttpStatus.conflict, {'success': false, 'error': 'Media is already in this queue.'});
      items.add({'mediaId': mediaId, 'mediaType': _requiredText(body, 'mediaType', 80), 'title': _requiredText(body, 'title', 500), 'sourceVersionKey': _optionalText(body, 'sourceVersionKey', 256), 'position': items.length, 'skipped': false, 'addedByProfileId': profile});
    } else if (parts.length == 3 && parts[1] == 'items') {
      final i = items.indexWhere((item) => item['mediaId']?.toString() == parts[2]);
      if (i < 0) return _json(request.response, HttpStatus.notFound, {'success': false, 'error': 'Queue item not found.'});
      if (request.method == 'DELETE') { items.removeAt(i); }
      else if (request.method == 'PATCH') {
        final body = await _body(request);
        if (body['position'] is num) { final item = items.removeAt(i); items.insert((body['position'] as num).toInt().clamp(0, items.length), item); }
        final moved = items.indexWhere((item) => item['mediaId']?.toString() == parts[2]);
        if (body['skipped'] is bool && moved >= 0) items[moved]['skipped'] = body['skipped'];
      } else { return _json(request.response, HttpStatus.notFound, {'success': false, 'error': 'Route not found.'}); }
    } else { return _json(request.response, HttpStatus.notFound, {'success': false, 'error': 'Route not found.'}); }
    for (var i = 0; i < items.length; i++) { items[i]['position'] = i; }
    data['items'] = items;
    await _saveRecord(account.id, data['profileId']?.toString(), 'collaborative_queue', id, data);
    return _json(request.response, HttpStatus.ok, {'success': true, 'queue': data});
  }

  String? _ownedProfile(Account account, String? value) {
    final id = value?.trim();
    if (id == null || id.isEmpty) return null;
    if (!account.profiles.any((profile) => profile.id == id)) throw ArgumentError('Profile does not belong to this account.');
    return id;
  }

  void _validateProfileRecord(
    String type,
    String key,
    String? profileId,
    Map<String, dynamic> data,
  ) {
    if (type == 'xray_private_note') {
      if (profileId == null || data['profileId']?.toString() != profileId) {
        throw ArgumentError('X-Ray notes must belong to the authenticated profile.');
      }
      final noteId = _requiredText(data, 'id', 240);
      if (noteId != key) throw const FormatException('X-Ray note ID must match its record key.');
      _requiredText(data, 'mediaId', 256);
      _requiredText(data, 'mediaVersionId', 256);
      final position = data['positionMilliseconds'];
      if (position is! num || !position.isFinite || position < 0) {
        throw const FormatException('X-Ray note position must be a non-negative number.');
      }
      final text = _requiredText(data, 'text', 1000);
      if (text.length > 1000) throw const FormatException('X-Ray note text is too long.');
      if (DateTime.tryParse(data['createdAt']?.toString() ?? '') == null) {
        throw const FormatException('X-Ray note createdAt must be a valid timestamp.');
      }
    }

    if (type == 'xray_profile_settings') {
      if (profileId == null || key != 'settings') {
        throw ArgumentError('X-Ray settings must be saved to an authenticated profile.');
      }
      const spoilerLevels = {'noSpoilers', 'currentScene', 'currentMovie', 'franchise', 'everything'};
      if (!spoilerLevels.contains(data['spoilerLevel'])) {
        throw const FormatException('Invalid X-Ray spoiler level.');
      }
      for (final field in ['visibleSections', 'followedEntities']) {
        final values = data[field];
        if (values is! List || values.length > 100) {
          throw FormatException('X-Ray $field must be a list of at most 100 values.');
        }
        if (values.any((value) => value is! String || value.trim().isEmpty || value.length > 240)) {
          throw FormatException('X-Ray $field contains an invalid value.');
        }
      }
    }
  }

  String _requiredText(Map<String, dynamic> body, String key, int max) {
    final value = body[key]?.toString().trim() ?? '';
    if (value.isEmpty || value.length > max || value.contains('\u0000')) throw FormatException('$key is required and must be at most $max characters.');
    return value;
  }

  String? _optionalText(Map<String, dynamic> body, String key, int max) {
    final value = body[key]?.toString().trim();
    if (value == null || value.isEmpty) return null;
    if (value.length > max || value.contains('\u0000')) throw FormatException('$key must be at most $max characters.');
    return value;
  }

  String _recordId(String accountId, String? profile, String type, String key) => '$accountId|${profile ?? ''}|$type|$key';

  String _uuid() {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
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
      'GET, POST, PATCH, DELETE, OPTIONS',
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
