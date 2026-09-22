// FILE: `Backend/routes/storage_routes.dart`.
// Purpose: Implements the storage routes portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../config.dart';
import '../middleware/authentication.dart';
import '../services/email_service.dart';
import '../services/storage_manager_service.dart';

/// Implements the storage API routes.
class StorageRoutes {
  final AuthenticationMiddleware authentication;
  final EmailService email;
  final StorageManagerService storageManager;

  static const int _maxBodyBytes = 64 * 1024;
  static const int _maxAdditionalTerabytes = 100;

  StorageRoutes({
    required this.authentication,
    required this.email,
    this.storageManager = const StorageManagerService(),
  });

  /// Handles all storage-related API routes.
  Future<void> handle(HttpRequest request) async {
    var responseStarted = false;

    try {
      if (request.method == 'OPTIONS') {
        responseStarted = true;
        return await _corsPreflight(request.response);
      }

      final path = request.uri.path;

      if (request.method == 'GET' &&
          path == '/api/v1/storage/system') {
        return await _system(request);
      }

      if (request.method == 'GET' &&
          path == '/api/v1/storage') {
        return await _get(request);
      }

      if (request.method == 'POST' &&
          path == '/api/v1/storage/request') {
        return await _request(request);
      }

      if (request.method == 'GET' &&
          path == '/api/v1/storage/notifications') {
        return await _notifications(request);
      }

      if (request.method == 'POST' &&
          path == '/api/v1/storage/admin/list') {
        return await _adminList(request);
      }

      if (request.method == 'POST' &&
          path == '/api/v1/storage/admin/update') {
        return await _adminUpdate(request);
      }

      responseStarted = true;
      return await _json(
        request.response,
        404,
        {
          'success': false,
          'error': 'Storage route not found.',
        },
      );
    } catch (e, stackTrace) {
      stderr.writeln('Storage route error: $e');
      stderr.writeln(stackTrace);

      if (responseStarted || request.response.headers.contentType != null) {
        return;
      }

      return await _json(
        request.response,
        500,
        {
          'success': false,
          'error': 'An internal storage service error occurred.',
        },
      );
    }
  }

  /// Returns live NAS filesystem, RAID, backup, and UPS information.
  Future<void> _system(HttpRequest request) async {
    final account = authentication.authenticate(request);

    if (account == null) {
      return await _unauth(request);
    }

    return await _json(
      request.response,
      200,
      await storageManager.snapshot(),
    );
  }

  /// Returns the authenticated account's storage allocation.
  Future<void> _get(HttpRequest request) async {
    final account = authentication.authenticate(request);

    if (account == null) {
      return await _unauth(request);
    }

    final freeBytes = account.storageLimitBytes -
        account.storageUsedBytes;

    return await _json(
      request.response,
      200,
      {
        'success': true,
        'limitBytes': account.storageLimitBytes,
        'usedBytes': account.storageUsedBytes,
        'freeBytes': freeBytes < 0 ? 0 : freeBytes,
        'requestPending': account.storageRequestPending,
        'requestedTerabytes':
            account.storageRequestedTerabytes,
        'requestFeeUsd':
            account.storageRequestFeeUsd,
        'requestStatus':
            account.storageRequestStatus,
      },
    );
  }

  /// Creates a request for additional physical storage.
  Future<void> _request(HttpRequest request) async {
    final account = authentication.authenticate(request);

    if (account == null) {
      return await _unauth(request);
    }

    if (account.storageRequestPending) {
      return await _json(
        request.response,
        409,
        {
          'success': false,
          'error': 'A storage request is already pending.',
        },
      );
    }

    final body = await _body(request);

    final terabytes = _parsePositiveInt(
      body['additionalTerabytes'],
    );

    if (terabytes == null ||
        terabytes <= 0 ||
        terabytes > _maxAdditionalTerabytes) {
      return await _json(
        request.response,
        400,
        {
          'success': false,
          'error':
              'Choose between 1 and $_maxAdditionalTerabytes TB of additional storage.',
        },
      );
    }

    final fee =
        terabytes * AppConfig.additionalStoragePricePerTbUsd;

    account.storageRequestPending = true;
    account.storageRequestAt = DateTime.now();
    account.storageRequestedTerabytes = terabytes;
    account.storageRequestFeeUsd = fee;
    account.storageRequestStatus = 'requested';

    account.addNotification(
      'Storage request sent',
      'Your request for $terabytes TB of additional storage was sent to the platform owner. '
          'Fee: \$${fee.toStringAsFixed(2)} USD.',
    );

    // The account state has already been updated successfully.
    // Notification delivery must not turn a successful request into a
    // misleading server error.
    try {
      await email.storageRequest(
        account.email,
        account.username,
        account.id,
        'Server ${account.id}',
        terabytes,
        fee,
      );
    } catch (e, stackTrace) {
      stderr.writeln(
        'Storage request email failed for account ${account.id}: $e',
      );
      stderr.writeln(stackTrace);
    }

    return await _json(
      request.response,
      202,
      {
        'success': true,
        'message':
            'Storage request sent to the platform owner.',
        'requestPending': true,
        'requestedTerabytes': terabytes,
        'requestFeeUsd': fee,
      },
    );
  }

  /// Returns the account's in-app notifications.
  Future<void> _notifications(HttpRequest request) async {
    final account = authentication.authenticate(request);

    if (account == null) {
      return await _unauth(request);
    }

    return await _json(
      request.response,
      200,
      {
        'success': true,
        'notifications': account.notifications,
      },
    );
  }

  /// Lists all pending storage requests for the platform administrator.
  Future<void> _adminList(HttpRequest request) async {
    if (!_adminAuthorized(request)) {
      return await _adminDenied(request);
    }

    final accounts =
        authentication.authService.database.accountsById.values;

    final requests = accounts
        .where((account) => account.storageRequestPending)
        .map(
          (account) => {
            'accountId': account.id,
            'username': account.username,
            'email': account.email,
            'serverName': 'Server ${account.id}',
            'additionalTerabytes':
                account.storageRequestedTerabytes,
            'feeUsd': account.storageRequestFeeUsd,
            'status': account.storageRequestStatus,
            'requestedAt':
                account.storageRequestAt?.toIso8601String(),
          },
        )
        .toList(growable: false);

    return await _json(
      request.response,
      200,
      {
        'success': true,
        'requests': requests,
      },
    );
  }

  /// Updates a storage request as the physical purchase/install process
  /// advances.
  Future<void> _adminUpdate(HttpRequest request) async {
    if (!_adminAuthorized(request)) {
      return await _adminDenied(request);
    }

    final body = await _body(request);

    final accountId = body['accountId']?.toString().trim() ?? '';

    if (accountId.isEmpty || accountId.length > 256) {
      return await _json(
        request.response,
        400,
        {
          'success': false,
          'error': 'A valid accountId is required.',
        },
      );
    }

    final account =
        authentication.authService.database.accountsById[accountId];

    if (account == null) {
      return await _json(
        request.response,
        404,
        {
          'success': false,
          'error': 'Account not found.',
        },
      );
    }

    final status = body['status']?.toString().trim() ?? '';

    const validStatuses = {
      'accepted',
      'payment_received',
      'storage_acquired',
      'installation_pending',
      'completed',
      'rejected',
    };

    if (!validStatuses.contains(status)) {
      return await _json(
        request.response,
        400,
        {
          'success': false,
          'error': 'Invalid storage request status.',
        },
      );
    }

    if (status == 'completed') {
      final requestedTb = _parsePositiveInt(
        body['additionalTerabytes'],
      );

      final terabytes =
          requestedTb ?? account.storageRequestedTerabytes;

      if (terabytes <= 0 ||
          terabytes > _maxAdditionalTerabytes) {
        return await _json(
          request.response,
          400,
          {
            'success': false,
            'error':
                'Additional storage must be between 1 and $_maxAdditionalTerabytes TB.',
          },
        );
      }

      final additionalBytes =
          terabytes * 1000000000000;

      account.storageLimitBytes += additionalBytes;
      account.storageRequestPending = false;
      account.storageRequestStatus = 'completed';
      account.storageRequestedTerabytes = terabytes;

      account.addNotification(
        'Storage updated',
        'You have $terabytes TB more storage available on your server.',
      );

      try {
        await email.storageInstalled(
          account.email,
          terabytes,
        );
      } catch (e, stackTrace) {
        stderr.writeln(
          'Storage installation email failed for account ${account.id}: $e',
        );
        stderr.writeln(stackTrace);
      }
    } else if (status == 'rejected') {
      account.storageRequestPending = false;
      account.storageRequestStatus = 'rejected';

      account.addNotification(
        'Storage request declined',
        'Your additional storage request was not approved.',
      );
    } else {
      account.storageRequestStatus = status;

      final message = switch (status) {
        'accepted' =>
          'We accepted your additional storage request. Please be patient while we obtain and install the storage on your server.',
        'payment_received' =>
          'Your storage payment was received. We are preparing the physical storage for your server.',
        'storage_acquired' =>
          'Your additional storage has been acquired and is being prepared for installation.',
        _ =>
          'Your additional storage is ready for installation on your server.',
      };

      account.addNotification(
        'Storage request update',
        message,
      );

      if (status == 'accepted') {
        try {
          await email.storageAccepted(
            account.email,
            account.storageRequestedTerabytes,
          );
        } catch (e, stackTrace) {
          stderr.writeln(
            'Storage acceptance email failed for account ${account.id}: $e',
          );
          stderr.writeln(stackTrace);
        }
      }
    }

    return await _json(
      request.response,
      200,
      {
        'success': true,
        'status': account.storageRequestStatus,
        'limitBytes': account.storageLimitBytes,
      },
    );
  }

  /// Reads and validates a bounded JSON request body.
  Future<Map<String, dynamic>> _body(HttpRequest request) async {
    final contentLength = request.contentLength;

    if (contentLength > _maxBodyBytes) {
      throw const FormatException(
        'Request body is too large.',
      );
    }

    final chunks = <int>[];
    var totalBytes = 0;

    await for (final chunk in request) {
      totalBytes += chunk.length;

      if (totalBytes > _maxBodyBytes) {
        throw const FormatException(
          'Request body is too large.',
        );
      }

      chunks.addAll(chunk);
    }

    if (chunks.isEmpty) {
      return <String, dynamic>{};
    }

    final source = utf8.decode(
      Uint8List.fromList(chunks),
      allowMalformed: false,
    );

    if (source.trim().isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(source);

    if (decoded is! Map) {
      throw const FormatException(
        'JSON object required.',
      );
    }

    return Map<String, dynamic>.from(decoded);
  }

  int? _parsePositiveInt(Object? value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      if (!value.isFinite || value % 1 != 0) {
        return null;
      }

      return value.toInt();
    }

    final text = value?.toString().trim();

    if (text == null || text.isEmpty) {
      return null;
    }

    return int.tryParse(text);
  }

  Future<void> _unauth(HttpRequest request) {
    return _json(
      request.response,
      401,
      {
        'success': false,
        'error': 'Authentication required.',
      },
    );
  }

  Future<void> _adminDenied(HttpRequest request) {
    return _json(
      request.response,
      403,
      {
        'success': false,
        'error':
            'Platform admin authorization required.',
      },
    );
  }

  /// Sends the CORS response for browser preflight requests.
  Future<void> _corsPreflight(HttpResponse response) async {
    _applySecurityHeaders(response);
    response.headers.set(
      'Access-Control-Allow-Origin',
      '*',
    );
    response.headers.set(
      'Access-Control-Allow-Methods',
      'GET, POST, OPTIONS',
    );
    response.headers.set(
      'Access-Control-Allow-Headers',
      'Authorization, Content-Type, X-Platform-Admin-Key',
    );
    response.headers.set(
      'Access-Control-Max-Age',
      '600',
    );

    response.statusCode = HttpStatus.noContent;
    await response.close();
  }

  Future<void> _json(
    HttpResponse response,
    int code,
    Map<String, dynamic> body,
  ) async {
    _applySecurityHeaders(response);

    response.headers.set(
      'Access-Control-Allow-Origin',
      '*',
    );
    response.headers.contentType = ContentType.json;
    response.statusCode = code;

    response.write(jsonEncode(body));
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

  /// Validates the high-privilege platform administrator key.
  ///
  /// This endpoint should additionally be kept behind a trusted private
  /// network/VPN or equivalent administrative access control in production.
  bool _adminAuthorized(HttpRequest request) {
    final configuredKey =
        Platform.environment['STREAM_PLATFORM_ADMIN_KEY'] ?? '';

    final suppliedKey =
        request.headers.value('x-platform-admin-key') ?? '';

    if (configuredKey.isEmpty ||
        suppliedKey.isEmpty ||
        configuredKey.length != suppliedKey.length) {
      return false;
    }

    final expected = utf8.encode(configuredKey);
    final supplied = utf8.encode(suppliedKey);

    var difference = 0;

    for (var i = 0; i < expected.length; i++) {
      difference |= expected[i] ^ supplied[i];
    }

    return difference == 0;
  }
}