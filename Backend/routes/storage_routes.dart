// FILE: `Backend/routes/storage_routes.dart`.
// Purpose: Implements the storage routes portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'dart:convert';
import 'dart:io';

import '../middleware/authentication.dart';
import '../config.dart';
import '../services/email_service.dart';
import '../services/storage_manager_service.dart';

/// Implements the `StorageRoutes` class for this feature or UI component.
class StorageRoutes {
  final AuthenticationMiddleware authentication;
  final EmailService email;
  final StorageManagerService storageManager;

  StorageRoutes({
    required this.authentication,
    required this.email,
    this.storageManager = const StorageManagerService(),
  });

  /// Performs `handle` for this feature. Update this documentation when its contract changes.
  Future<void> handle(HttpRequest request) async {
    try {
      final path = request.uri.path;

      if (request.method == 'GET' && path == '/api/v1/storage/system') {
        return await _system(request);
      }

      if (request.method == 'GET' && path == '/api/v1/storage') {
        return await _get(request);
      }

      if (request.method == 'POST' &&
          path == '/api/v1/storage/request') {
        return await _request(request);
      }

      if (request.method == 'GET' && path == '/api/v1/storage/notifications') {
        return await _notifications(request);
      }

      if (request.method == 'POST' && path == '/api/v1/storage/admin/list') {
        return await _adminList(request);
      }

      if (request.method == 'POST' && path == '/api/v1/storage/admin/update') {
        return await _adminUpdate(request);
      }

      return await _json(
        request.response,
        404,
        {
          'success': false,
          'error': 'Storage route not found.',
        },
      );
    } catch (e) {
      return await _json(
        request.response,
        400,
        {
          'success': false,
          'error': e.toString().replaceFirst(
                'Exception: ',
                '',
              ),
        },
      );
    }
  }

  /// Returns live NAS filesystem, RAID, backup, and UPS information.
  Future<void> _system(HttpRequest r) async {
    if (authentication.authenticate(r) == null) return await _unauth(r);
    return await _json(r.response, 200, await storageManager.snapshot());
  }

  /// Performs `_get` for this feature. Update this documentation when its contract changes.
  Future<void> _get(HttpRequest r) async {
    final a = authentication.authenticate(r);

    if (a == null) {
      return await _unauth(r);
    }

    return await _json(
      r.response,
      200,
      {
        'success': true,
        'limitBytes': a.storageLimitBytes,
        'usedBytes': a.storageUsedBytes,
        'freeBytes':
            a.storageLimitBytes - a.storageUsedBytes,
        'requestPending': a.storageRequestPending,
        'requestedTerabytes': a.storageRequestedTerabytes,
        'requestFeeUsd': a.storageRequestFeeUsd,
        'requestStatus': a.storageRequestStatus,
      },
    );
  }

  /// Performs `_request` for this feature. Update this documentation when its contract changes.
  Future<void> _request(HttpRequest r) async {
    final a = authentication.authenticate(r);

    if (a == null) {
      return await _unauth(r);
    }

    if (a.storageRequestPending) {
      throw Exception('A storage request is already pending.');
    }

    final body = await _body(r);
    final tb = body['additionalTerabytes'] is num
        ? (body['additionalTerabytes'] as num).toInt()
        : int.tryParse(body['additionalTerabytes']?.toString() ?? '') ?? 0;
    if (tb <= 0 || tb > 100) {
      throw Exception('Choose between 1 and 100 TB of additional storage.');
    }

    final fee = tb * AppConfig.additionalStoragePricePerTbUsd;
    a.storageRequestPending = true;
    a.storageRequestAt = DateTime.now();
    a.storageRequestedTerabytes = tb;
    a.storageRequestFeeUsd = fee;
    a.storageRequestStatus = 'requested';

    a.addNotification(
      'Storage request sent',
      'Your request for $tb TB of additional storage was sent to the platform owner. Fee: \$${fee.toStringAsFixed(2)} USD.',
    );

    await email.storageRequest(a.email, a.username, a.id, 'Server ${a.id}', tb, fee);

    return await _json(
      r.response,
      202,
      {
        'success': true,
        'message':
            'Storage request sent to the platform owner.',
        'requestPending': true,
      },
    );
  }

  /// Returns the account's in-app notifications.
  Future<void> _notifications(HttpRequest r) async {
    final a = authentication.authenticate(r);
    if (a == null) return await _unauth(r);
    return await _json(r.response, 200, {'success': true, 'notifications': a.notifications});
  }

  /// Lists all storage requests for the platform administrator.
  Future<void> _adminList(HttpRequest r) async {
    if (!_adminAuthorized(r)) return await _adminDenied(r);
    final accounts = authentication.authService.database.accountsById.values;
    return await _json(r.response, 200, {
      'success': true,
      'requests': accounts.where((a) => a.storageRequestPending).map((a) => {
        'accountId': a.id,
        'username': a.username,
        'email': a.email,
        'serverName': 'Server ${a.id}',
        'additionalTerabytes': a.storageRequestedTerabytes,
        'feeUsd': a.storageRequestFeeUsd,
        'status': a.storageRequestStatus,
        'requestedAt': a.storageRequestAt?.toIso8601String(),
      }).toList(),
    });
  }

  /// Updates a storage request as the physical purchase/install process advances.
  Future<void> _adminUpdate(HttpRequest r) async {
    if (!_adminAuthorized(r)) return await _adminDenied(r);
    final b = await _body(r);
    final id = b['accountId']?.toString() ?? '';
    final a = authentication.authService.database.accountsById[id];
    if (a == null) return await _json(r.response, 404, {'success': false, 'error': 'Account not found.'});
    final status = b['status']?.toString() ?? '';
    if (!{'accepted','payment_received','storage_acquired','installation_pending','completed','rejected'}.contains(status)) {
      return await _json(r.response, 400, {'success': false, 'error': 'Invalid storage request status.'});
    }
    if (status == 'completed') {
      final tb = b['additionalTerabytes'] is num ? (b['additionalTerabytes'] as num).toInt() : a.storageRequestedTerabytes;
      if (tb <= 0) return await _json(r.response, 400, {'success': false, 'error': 'Additional storage must be greater than zero.'});
      a.storageLimitBytes += tb * 1000000000000;
      a.storageRequestPending = false;
      a.storageRequestStatus = 'completed';
      a.storageRequestedTerabytes = tb;
      a.addNotification('Storage updated', 'You have $tb TB more storage available on your server.');
      await email.storageInstalled(a.email, tb);
    } else if (status == 'rejected') {
      a.storageRequestPending = false;
      a.storageRequestStatus = 'rejected';
      a.addNotification('Storage request declined', 'Your additional storage request was not approved.');
    } else {
      a.storageRequestStatus = status;
      final message = switch (status) {
        'accepted' => 'We accepted your additional storage request. Please be patient while we obtain and install the storage on your server.',
        'payment_received' => 'Your storage payment was received. We are preparing the physical storage for your server.',
        'storage_acquired' => 'Your additional storage has been acquired and is being prepared for installation.',
        _ => 'Your additional storage is ready for installation on your server.',
      };
      a.addNotification('Storage request update', message);
      if (status == 'accepted') await email.storageAccepted(a.email, a.storageRequestedTerabytes);
    }
    return await _json(r.response, 200, {'success': true, 'status': a.storageRequestStatus, 'limitBytes': a.storageLimitBytes});
  }

  Future<Map<String, dynamic>> _body(HttpRequest r) async {
    final s = await utf8.decoder.bind(r).join();

    if (s.trim().isEmpty) {
      return {};
    }

    final d = jsonDecode(s);

    if (d is! Map) {
      throw Exception('JSON object required.');
    }

    return Map<String, dynamic>.from(d);
  }

  Future<void> _unauth(HttpRequest r) {
    return _json(
      r.response,
      401,
      {
        'success': false,
        'error': 'Authentication required.',
      },
    );
  }

  Future<void> _json(
    HttpResponse r,
    int code,
    Map<String, dynamic> body,
  ) async {
    r.statusCode = code;
    r.headers.contentType = ContentType.json;
    r.write(jsonEncode(body));
    await r.close();
  }

  bool _adminAuthorized(HttpRequest r) {
    final key = Platform.environment['STREAM_PLATFORM_ADMIN_KEY'] ?? '';
    return key.isNotEmpty && r.headers.value('x-platform-admin-key') == key;
  }

  Future<void> _adminDenied(HttpRequest r) => _json(r.response, 403, {'success': false, 'error': 'Platform admin authorization required.'});

}
