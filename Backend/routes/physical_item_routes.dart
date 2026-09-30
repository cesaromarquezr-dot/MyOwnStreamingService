// Account-scoped CRUD for physical ownership records. Ownership status is
// transitioned and retained as history; physical items cannot be deleted.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../database/database.dart';
import '../middleware/authentication.dart';
import '../models/physical_item.dart';
import '../supabase_store.dart';

class PhysicalItemRoutes {
  final AuthenticationMiddleware authentication;
  final Database database;
  final SupabaseStore store;
  final Random _random = Random.secure();

  PhysicalItemRoutes({
    required this.authentication,
    required this.database,
    required this.store,
  });

  Future<void> handle(HttpRequest request) async {
    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }

    final account = authentication.authenticate(request);
    if (account == null || account.id.trim().isEmpty) {
      await _send(request.response, HttpStatus.unauthorized, {
        'success': false,
        'error': 'Authentication required.',
      });
      return;
    }

    try {
      final path = request.uri.path;
      if (request.method == 'GET' && path == '/api/v1/physical-items') {
        final items = await _load(account.id);
        await _send(request.response, HttpStatus.ok, {
          'success': true,
          'items': items.map((item) => item.toJson()).toList(),
        });
        return;
      }

      if (request.method == 'POST' && path == '/api/v1/physical-items') {
        final body = await _readBody(request);
        final now = DateTime.now().toUtc();
        final id = _newId();
        final payload = <String, dynamic>{
          ...body,
          'id': id,
          'accountId': account.id,
          'ownershipStatus': PhysicalOwnershipStatus.owned.name,
          'ownershipHistory': [
            {
              'status': PhysicalOwnershipStatus.owned.name,
              'changedAt': now.toIso8601String(),
              'actorId': account.id,
              'note': 'Physical item acquired and registered.',
            },
          ],
          'physicalReleaseId': body['physicalReleaseId'],
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
          'acquiredAt': body['acquiredAt'] ?? now.toIso8601String(),
        };
        final item = PhysicalItem.fromJson(payload);
        await _save(item);
        await _send(request.response, HttpStatus.created, {
          'success': true,
          'item': item.toJson(),
        });
        return;
      }

      final statusId = _statusItemId(path);
      if (request.method == 'POST' && statusId != null) {
        final body = await _readBody(request);
        final item = await _get(account.id, statusId);
        if (item == null) {
          await _send(request.response, HttpStatus.notFound, {
            'success': false,
            'error': 'Physical item not found.',
          });
          return;
        }
        final statusName = body['status']?.toString().trim().toLowerCase();
        final status = PhysicalOwnershipStatus.values.where(
          (candidate) => candidate.name.toLowerCase() == statusName,
        );
        if (status.isEmpty) {
          await _send(request.response, HttpStatus.badRequest, {
            'success': false,
            'error': 'A valid ownership status is required.',
          });
          return;
        }
        if (status.first == item.ownershipStatus) {
          await _send(request.response, HttpStatus.ok, {
            'success': true,
            'item': item.toJson(),
          });
          return;
        }
        final changed = item.changeOwnership(
          status: status.first,
          actorId: account.id,
          note: body['note']?.toString(),
        );
        await _save(changed);
        await _send(request.response, HttpStatus.ok, {
          'success': true,
          'item': changed.toJson(),
        });
        return;
      }

      await _send(request.response, HttpStatus.notFound, {
        'success': false,
        'error': 'Physical item route not found.',
      });
    } on FormatException catch (error) {
      await _send(request.response, HttpStatus.badRequest, {
        'success': false,
        'error': error.message,
      });
    } on ArgumentError catch (error) {
      await _send(request.response, HttpStatus.badRequest, {
        'success': false,
        'error': error.message,
      });
    } catch (_) {
      await _send(request.response, HttpStatus.internalServerError, {
        'success': false,
        'error': 'Unable to update physical media ownership.',
      });
    }
  }

  Future<List<PhysicalItem>> _load(String accountId) async {
    if (store.enabled) {
      final items = await store.loadPhysicalItems(accountId);
      for (final item in items) {
        database.savePhysicalItem(item);
      }
      return items;
    }
    return database.getPhysicalItemsForAccount(accountId);
  }

  Future<PhysicalItem?> _get(String accountId, String itemId) async {
    if (store.enabled) {
      for (final item in await store.loadPhysicalItems(accountId)) {
        if (item.id == itemId) {
          database.savePhysicalItem(item);
          return item;
        }
      }
      return null;
    }
    final cached = database.getPhysicalItem(accountId, itemId);
    if (cached != null) return cached;
    for (final item in await _load(accountId)) {
      if (item.id == itemId) return item;
    }
    return null;
  }

  Future<void> _save(PhysicalItem item) async {
    if (store.enabled) await store.upsertPhysicalItem(item);
    database.savePhysicalItem(item);
  }

  Future<Map<String, dynamic>> _readBody(HttpRequest request) async {
    final bytes = await request.fold<List<int>>(
      <int>[],
      (buffer, chunk) {
        if (buffer.length + chunk.length > 64 * 1024) {
          throw const FormatException('Request body is too large.');
        }
        return buffer..addAll(chunk);
      },
    );
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) throw const FormatException('JSON object required.');
    return Map<String, dynamic>.from(decoded);
  }

  String? _statusItemId(String path) {
    const prefix = '/api/v1/physical-items/';
    const suffix = '/ownership-status';
    if (!path.startsWith(prefix) || !path.endsWith(suffix)) return null;
    final id = path.substring(prefix.length, path.length - suffix.length);
    return id.isEmpty ? null : Uri.decodeComponent(id);
  }

  String _newId() {
    final bytes = List<int>.generate(18, (_) => _random.nextInt(256));
    return 'physical_${base64UrlEncode(bytes).replaceAll('=', '')}';
  }

  Future<void> _send(
    HttpResponse response,
    int status,
    Map<String, dynamic> body,
  ) async {
    response.statusCode = status;
    response.headers.contentType = ContentType.json;
    response.headers.set('cache-control', 'no-store');
    response.write(jsonEncode(body));
    await response.close();
  }
}
