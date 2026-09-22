// FILE: `Backend/routes/sports_routes.dart`.
// Purpose: Implements the sports routes portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.
//
// Sports access model:
// - All sports endpoints require authentication.
// - Only authorized/original broadcasts should be surfaced by SportsService.
// - This route does not grant broadcast rights; it only exposes the service's
//   already-authorized catalog and scheduling results.
// - Sports data is not cached by the HTTP layer because live/upcoming data
//   can change quickly.

import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import '../middleware/authentication.dart';
import '../services/sports_service.dart';

class SportsRoutes {
  final AuthenticationMiddleware authentication;
  final SportsService service;

  SportsRoutes({
    required this.authentication,
    required this.service,
  });

  static const String _sportsPath =
      '/api/v1/sports';

  static const String _teamsPath =
      '/api/v1/sports/teams';

  static const String _livePath =
      '/api/v1/sports/live';

  static const String _upcomingPath =
      '/api/v1/sports/upcoming';

  static const int _defaultDays = 7;
  static const int _maxDays = 14;

  static const int _maxSportLength = 100;
  static const int _maxCountryLength = 100;

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
      // ROUTE VALIDATION
      // --------------------------------------------------------

      const supportedPaths = <String>{
        _sportsPath,
        _teamsPath,
        _livePath,
        _upcomingPath,
      };

      if (!supportedPaths.contains(request.uri.path)) {
        responseStarted = true;

        await _json(
          request.response,
          HttpStatus.notFound,
          {
            'success': false,
            'error': 'Sports route not found.',
          },
        );
        return;
      }

      // --------------------------------------------------------
      // METHOD
      // --------------------------------------------------------

      if (request.method != 'GET') {
        responseStarted = true;

        await _json(
          request.response,
          HttpStatus.methodNotAllowed,
          {
            'success': false,
            'error': 'GET required.',
          },
        );
        return;
      }

      // --------------------------------------------------------
      // AUTHENTICATION
      // --------------------------------------------------------

      final account =
          authentication.authenticate(request);

      if (account == null) {
        responseStarted = true;

        await _json(
          request.response,
          HttpStatus.unauthorized,
          {
            'success': false,
            'error': 'Authentication required.',
          },
        );
        return;
      }

      // Keep authentication authoritative even when the current
      // SportsService API does not require account information.
      final _ = account;

      // --------------------------------------------------------
      // SPORTS CATALOG
      // --------------------------------------------------------

      if (request.uri.path == _sportsPath) {
        final sports = service.sports();

        responseStarted = true;

        await _json(
          request.response,
          HttpStatus.ok,
          {
            'success': true,
            'sports': sports,
          },
        );
        return;
      }

      // --------------------------------------------------------
      // TEAMS / LEAGUES
      // --------------------------------------------------------

      if (request.uri.path == _teamsPath) {
        final leagues =
            await service.availableTeams();

        responseStarted = true;

        await _json(
          request.response,
          HttpStatus.ok,
          {
            'success': true,
            'leagues': leagues,
          },
        );
        return;
      }

      // --------------------------------------------------------
      // LIVE GAMES
      // --------------------------------------------------------

      if (request.uri.path == _livePath) {
        final sport = _readOptionalFilter(
          request.uri.queryParameters['sport'],
          field: 'sport',
          maxLength: _maxSportLength,
        );

        final country = _readOptionalFilter(
          request.uri.queryParameters['country'],
          field: 'country',
          maxLength: _maxCountryLength,
        );

        final games = await service.liveGames(
          sport: sport,
          country: country,
        );

        responseStarted = true;

        await _json(
          request.response,
          HttpStatus.ok,
          {
            'success': true,
            'games': games
                .map((game) => game.toJson())
                .toList(growable: false),
            'policy':
                'Only authorized authentic/original broadcasts are returned.',
          },
        );
        return;
      }

      // --------------------------------------------------------
      // UPCOMING GAMES
      // --------------------------------------------------------

      if (request.uri.path == _upcomingPath) {
        final sport = _readOptionalFilter(
          request.uri.queryParameters['sport'],
          field: 'sport',
          maxLength: _maxSportLength,
        );

        final country = _readOptionalFilter(
          request.uri.queryParameters['country'],
          field: 'country',
          maxLength: _maxCountryLength,
        );

        final days = _parseDays(
          request.uri.queryParameters['days'],
        );

        final games = await service.upcomingGames(
          sport: sport,
          country: country,
          days: days,
        );

        responseStarted = true;

        await _json(
          request.response,
          HttpStatus.ok,
          {
            'success': true,
            'days': days,
            'games': games
                .map((game) => game.toJson())
                .toList(growable: false),
          },
        );
        return;
      }

      // Defensive fallback.
      if (!responseStarted) {
        responseStarted = true;

        await _json(
          request.response,
          HttpStatus.notFound,
          {
            'success': false,
            'error': 'Sports route not found.',
          },
        );
      }
    } on FormatException catch (error, stackTrace) {
      developer.log(
        'Invalid sports request.',
        name: 'SportsRoutes',
        error: error,
        stackTrace: stackTrace,
      );

      if (!responseStarted) {
        await _json(
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
        'Sports request error.',
        name: 'SportsRoutes',
        error: error,
        stackTrace: stackTrace,
      );

      if (!responseStarted) {
        await _json(
          request.response,
          HttpStatus.internalServerError,
          {
            'success': false,
            'error': 'Unable to retrieve sports information.',
          },
        );
      }
    }
  }

  // ==========================================================
  // QUERY VALIDATION
  // ==========================================================

  String? _readOptionalFilter(
    String? value, {
    required String field,
    required int maxLength,
  }) {
    if (value == null) {
      return null;
    }

    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return null;
    }

    if (trimmed.length > maxLength) {
      throw FormatException(
        '$field must be $maxLength characters or fewer.',
      );
    }

    if (trimmed.contains('\u0000')) {
      throw FormatException(
        '$field contains an invalid character.',
      );
    }

    return trimmed;
  }

  int _parseDays(String? value) {
    if (value == null || value.trim().isEmpty) {
      return _defaultDays;
    }

    final parsed = int.tryParse(value.trim());

    if (parsed == null) {
      throw const FormatException(
        'days must be a valid integer.',
      );
    }

    if (parsed < 1 || parsed > _maxDays) {
      throw FormatException(
        'days must be between 1 and $_maxDays.',
      );
    }

    return parsed;
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
      'Access-Control-Allow-Headers',
      'Content-Type, Authorization',
    );

    response.headers.set(
      'Access-Control-Allow-Methods',
      'GET, OPTIONS',
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

  Future<void> _json(
    HttpResponse response,
    int status,
    Map<String, dynamic> data,
  ) async {
    response.statusCode = status;
    response.headers.contentType = ContentType.json;

    response.write(
      jsonEncode(data),
    );

    await response.close();
  }
}