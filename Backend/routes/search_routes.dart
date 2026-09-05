import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import '../middleware/authentication.dart';
import '../services/search_service.dart';

/// Handles the global Smart Search API.
///
/// Endpoint:
///
///     GET /api/v1/search?q=Spider-Man
///
/// Search is authenticated because it is part of the user's
/// streaming service application.
class SearchRoutes {
  final AuthenticationMiddleware authenticationMiddleware;
  final SearchService searchService;

  SearchRoutes({
    required this.authenticationMiddleware,
    required this.searchService,
  });

  // ==========================================================
  // REQUEST HANDLER
  // ==========================================================

  Future<void> handle(
    HttpRequest request,
  ) async {
    try {
      // --------------------------------------------------------
      // METHOD
      // --------------------------------------------------------

      if (request.method != 'GET') {
        await _sendJson(
          request.response,
          HttpStatus.methodNotAllowed,
          {
            'success': false,
            'error': 'Method not allowed.',
          },
        );
        return;
      }

      // --------------------------------------------------------
      // AUTHENTICATION
      // --------------------------------------------------------

      final account =
          authenticationMiddleware.authenticate(request);

      if (account == null) {
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
      // QUERY
      // --------------------------------------------------------

      final query =
          request.uri.queryParameters['q']?.trim() ?? '';

      if (query.isEmpty) {
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

      // Prevent unnecessarily large search requests.
      final safeQuery = query.length > 200
          ? query.substring(0, 200)
          : query;

      // --------------------------------------------------------
      // LIMIT
      // --------------------------------------------------------

      int limit = 50;

      final limitParameter =
          request.uri.queryParameters['limit'];

      if (limitParameter != null) {
        final parsedLimit =
            int.tryParse(limitParameter);

        if (parsedLimit != null) {
          limit = parsedLimit.clamp(1, 100);
        }
      }

      // --------------------------------------------------------
      // SEARCH
      // --------------------------------------------------------

      final results = searchService.search(
        safeQuery,
        limit: limit,
      );

      // --------------------------------------------------------
      // RESPONSE
      // --------------------------------------------------------

      await _sendJson(
        request.response,
        HttpStatus.ok,
        {
          'success': true,
          'query': safeQuery,
          'count': results.length,
          'results': results
              .map(
                (result) => result.toJson(),
              )
              .toList(),
        },
      );
    } catch (error, stackTrace) {
      developer.log(
        'Search request error: $error',
        name: 'SearchRoutes',
        error: error,
        stackTrace: stackTrace,
      );

      if (!request.response.headers.contentType
          .toString()
          .contains('json')) {
        await _sendJson(
          request.response,
          HttpStatus.internalServerError,
          {
            'success': false,
            'error': 'Unable to perform search.',
          },
        );
      }
    }
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

    response.headers.contentType =
        ContentType.json;

    response.write(
      jsonEncode(data),
    );

    await response.close();
  }
}