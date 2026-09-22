// FILE: Backend/routes/shop_routes.dart.
// Purpose: Authenticated global marketplace association search/sync endpoints.
//
// Marketplace architecture:
// - Global shop entities contain lightweight association metadata.
// - Private/source media remains on the source server.
// - Search requires an authenticated account.
// - Synchronization is attributed to the authenticated account.
// - The client never supplies the authoritative account ID.
// - Responses are non-cacheable because marketplace associations can change.

import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import '../middleware/authentication.dart';
import '../models/shop_entity.dart';
import '../services/shop_service.dart';

class ShopRoutes {
  final AuthenticationMiddleware authenticationMiddleware;
  final ShopService shopService;

  ShopRoutes({
    required this.authenticationMiddleware,
    required this.shopService,
  });

  static const String _entitiesPath =
      '/api/v1/shop/entities';

  static const String _syncPath =
      '/api/v1/shop/entities/sync';

  static const int _defaultLimit = 50;
  static const int _maxLimit = 100;

  static const int _maxQueryLength = 200;
  static const int _maxBodyBytes = 512 * 1024;
  static const int _maxEntities = 500;

  Future<void> handle(HttpRequest request) async {
    var responseStarted = false;

    try {
      _applyCors(request.response);

      // --------------------------------------------------------
      // CORS PREFLIGHT
      // --------------------------------------------------------

      if (request.method == 'OPTIONS') {
        responseStarted = true;
        request.response.statusCode = HttpStatus.noContent;
        await request.response.close();
        return;
      }

      // --------------------------------------------------------
      // AUTHENTICATION
      // --------------------------------------------------------

      final account =
          authenticationMiddleware.authenticate(request);

      if (account == null) {
        responseStarted = true;

        await _sendJson(
          request.response,
          HttpStatus.unauthorized,
          {
            'success': false,
            'error': 'Authentication required.',
          },
        );
        return;
      }

      // --------------------------------------------------------
      // SEARCH
      // --------------------------------------------------------

      if (request.method == 'GET' &&
          request.uri.path == _entitiesPath) {
        final rawQuery =
            request.uri.queryParameters['q'];

        if (rawQuery == null) {
          responseStarted = true;

          await _sendJson(
            request.response,
            HttpStatus.badRequest,
            {
              'success': false,
              'error': 'A search query is required.',
            },
          );
          return;
        }

        final query = rawQuery.trim();

        if (query.isEmpty) {
          responseStarted = true;

          await _sendJson(
            request.response,
            HttpStatus.badRequest,
            {
              'success': false,
              'error': 'A search query is required.',
            },
          );
          return;
        }

        if (query.length > _maxQueryLength) {
          responseStarted = true;

          await _sendJson(
            request.response,
            HttpStatus.badRequest,
            {
              'success': false,
              'error':
                  'Search query must be $_maxQueryLength characters or fewer.',
            },
          );
          return;
        }

        if (query.contains('\u0000')) {
          responseStarted = true;

          await _sendJson(
            request.response,
            HttpStatus.badRequest,
            {
              'success': false,
              'error': 'Search query contains an invalid character.',
            },
          );
          return;
        }

        final limit = _parseLimit(
          request.uri.queryParameters['limit'],
        );

        final results = await shopService.searchEntities(
          query,
          limit: limit,
        );

        responseStarted = true;

        await _sendJson(
          request.response,
          HttpStatus.ok,
          {
            'success': true,
            'query': query,
            'count': results.length,
            'entities': results
                .map((entity) => entity.toJson())
                .toList(growable: false),
          },
        );
        return;
      }

      // --------------------------------------------------------
      // ENTITY SYNCHRONIZATION
      // --------------------------------------------------------

      if (request.method == 'POST' &&
          request.uri.path == _syncPath) {
        final body = await _readBody(request);

        final rawEntities = body['entities'];

        if (rawEntities is! List) {
          responseStarted = true;

          await _sendJson(
            request.response,
            HttpStatus.badRequest,
            {
              'success': false,
              'error':
                  'A JSON object containing an entities array is required.',
            },
          );
          return;
        }

        if (rawEntities.length > _maxEntities) {
          responseStarted = true;

          await _sendJson(
            request.response,
            HttpStatus.badRequest,
            {
              'success': false,
              'error':
                  'A maximum of $_maxEntities entities may be synchronized per request.',
            },
          );
          return;
        }

        final entities = <ShopEntity>[];

        for (var index = 0;
            index < rawEntities.length;
            index++) {
          final raw = rawEntities[index];

          if (raw is! Map) {
            throw FormatException(
              'Entity at index $index must be a JSON object.',
            );
          }

          final entity = ShopEntity.fromJson(
            Map<String, dynamic>.from(raw),
          );

          _validateEntity(
            entity,
            index: index,
          );

          entities.add(entity);
        }

        await shopService.syncEntities(
          account.id,
          entities,
        );

        responseStarted = true;

        await _sendJson(
          request.response,
          HttpStatus.ok,
          {
            'success': true,
            'count': entities.length,
          },
        );
        return;
      }

      // --------------------------------------------------------
      // UNKNOWN ROUTE
      // --------------------------------------------------------

      responseStarted = true;

      await _sendJson(
        request.response,
        HttpStatus.notFound,
        {
          'success': false,
          'error': 'Shop route not found.',
        },
      );
    } on FormatException catch (error, stackTrace) {
      developer.log(
        'Invalid Shop request.',
        name: 'ShopRoutes',
        error: error,
        stackTrace: stackTrace,
      );

      if (!responseStarted) {
        await _sendJson(
          request.response,
          HttpStatus.badRequest,
          {
            'success': false,
            'error': error.message,
          },
        );
      }
    } catch (error, stackTrace) {
      developer.log(
        'Shop request error.',
        name: 'ShopRoutes',
        error: error,
        stackTrace: stackTrace,
      );

      if (!responseStarted) {
        await _sendJson(
          request.response,
          HttpStatus.internalServerError,
          {
            'success': false,
            'error': 'Unable to process Shop request.',
          },
        );
      }
    }
  }

  // ==========================================================
  // LIMIT VALIDATION
  // ==========================================================

  int _parseLimit(String? value) {
    if (value == null || value.trim().isEmpty) {
      return _defaultLimit;
    }

    final parsed = int.tryParse(value.trim());

    if (parsed == null) {
      throw const FormatException(
        'limit must be a valid integer.',
      );
    }

    if (parsed < 1 || parsed > _maxLimit) {
      throw FormatException(
        'limit must be between 1 and $_maxLimit.',
      );
    }

    return parsed;
  }

  // ==========================================================
  // ENTITY VALIDATION
  // ==========================================================

  void _validateEntity(
    ShopEntity entity, {
    required int index,
  }) {
    final id = entity.id.trim();
    final name = entity.name.trim();

    if (id.isEmpty) {
      throw FormatException(
        'Entity at index $index is missing an ID.',
      );
    }

    if (name.isEmpty) {
      throw FormatException(
        'Entity at index $index is missing a name.',
      );
    }

    if (id.length > 256) {
      throw FormatException(
        'Entity at index $index has an ID that is too long.',
      );
    }

    if (name.length > 500) {
      throw FormatException(
        'Entity at index $index has a name that is too long.',
      );
    }

    if (id.contains('\u0000') ||
        name.contains('\u0000')) {
      throw FormatException(
        'Entity at index $index contains an invalid character.',
      );
    }
  }

  // ==========================================================
  // REQUEST BODY
  // ==========================================================

  Future<Map<String, dynamic>> _readBody(
    HttpRequest request,
  ) async {
    if (request.contentLength > _maxBodyBytes) {
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
      throw const FormatException(
        'Request body is required.',
      );
    }

    final raw = utf8.decode(
      bytes,
      allowMalformed: false,
    );

    if (raw.trim().isEmpty) {
      throw const FormatException(
        'Request body is required.',
      );
    }

    dynamic decoded;

    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const FormatException(
        'Invalid JSON body.',
      );
    }

    if (decoded is! Map) {
      throw const FormatException(
        'JSON object required.',
      );
    }

    return Map<String, dynamic>.from(decoded);
  }

  // ==========================================================
  // RESPONSE HEADERS
  // ==========================================================

  void _applyCors(HttpResponse response) {
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
      'Authorization, Content-Type',
    );

    response.headers.set(
      'Access-Control-Expose-Headers',
      'Content-Type',
    );

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

  // ==========================================================
  // JSON RESPONSE
  // ==========================================================

  Future<void> _sendJson(
    HttpResponse response,
    int statusCode,
    Map<String, dynamic> data,
  ) async {
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.json;

    response.write(
      jsonEncode(data),
    );

    await response.close();
  }
}