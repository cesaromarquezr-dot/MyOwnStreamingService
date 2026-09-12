// FILE: `Backend/routes/sports_routes.dart`.
// Purpose: Implements the sports routes portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'dart:convert';
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

  /// Performs `handle` for this feature. Update this documentation when its contract changes.
  Future<void> handle(HttpRequest request) async {
    request.response.headers.set(
      'Access-Control-Allow-Origin',
      '*',
    );
    request.response.headers.set(
      'Access-Control-Allow-Headers',
      'Content-Type, Authorization',
    );
    request.response.headers.set(
      'Access-Control-Allow-Methods',
      'GET, OPTIONS',
    );

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }

    if (authentication.authenticate(request) == null) {
      await _json(
        request,
        HttpStatus.unauthorized,
        {
          'success': false,
          'error': 'Authentication required.',
        },
      );
      return;
    }

    if (request.method != 'GET') {
      await _json(
        request,
        HttpStatus.methodNotAllowed,
        {
          'success': false,
          'error': 'GET required.',
        },
      );
      return;
    }

    if (request.uri.path == '/api/v1/sports') {
      await _json(
        request,
        HttpStatus.ok,
        {
          'success': true,
          'sports': service.sports(),
        },
      );
      return;
    }

    if (request.uri.path == '/api/v1/sports/teams') {
      final leagues = await service.availableTeams();
      await _json(
        request,
        HttpStatus.ok,
        {
          'success': true,
          'leagues': leagues,
        },
      );
      return;
    }

    if (request.uri.path == '/api/v1/sports/live') {
      final games = await service.liveGames(
        sport: request.uri.queryParameters['sport'],
        country: request.uri.queryParameters['country'],
      );

      await _json(
        request,
        HttpStatus.ok,
        {
          'success': true,
          'games': games.map((g) => g.toJson()).toList(),
          'policy':
              'Only authorized authentic/original broadcasts are returned.',
        },
      );
      return;
    }

    if (request.uri.path == '/api/v1/sports/upcoming') {
      final requestedDays = int.tryParse(request.uri.queryParameters['days'] ?? '') ?? 7;
      final days = requestedDays.clamp(1, 14).toInt();
      final games = await service.upcomingGames(
        sport: request.uri.queryParameters['sport'],
        country: request.uri.queryParameters['country'],
        days: days,
      );

      await _json(
        request,
        HttpStatus.ok,
        {
          'success': true,
          'games': games.map((g) => g.toJson()).toList(),
        },
      );
      return;
    }

    await _json(
      request,
      HttpStatus.notFound,
      {
        'success': false,
        'error': 'Sports route not found.',
      },
    );
  }

  /// Performs `_json` for this feature. Update this documentation when its contract changes.
  Future<void> _json(
    HttpRequest request,
    int status,
    Map<String, dynamic> data,
  ) async {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(data));
    await request.response.close();
  }
}
