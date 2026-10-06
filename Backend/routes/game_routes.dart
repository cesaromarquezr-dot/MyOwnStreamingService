import 'dart:convert';
import 'dart:io';

import '../middleware/authentication.dart';
import '../services/game_service.dart';

class GameRoutes {
  static const String prefix = '/api/v1/games';
  final AuthenticationMiddleware authentication;
  final GameService service;

  GameRoutes({required this.authentication, required this.service});

  Future<void> handle(HttpRequest request) async {
    final account = authentication.authenticate(request);
    if (account == null) {
      await _json(request.response, 401, {'success': false, 'error': 'Authentication required.'});
      return;
    }
    try {
      if (request.method == 'GET' && request.uri.path == '$prefix/ratings') {
        final profileId = request.uri.queryParameters['profileId']?.trim() ?? '';
        if (profileId.isEmpty) throw const FormatException('profileId is required.');
        if (!_profileBelongsToAccount(account, profileId)) throw StateError('Profile does not belong to this account.');
        final ratings = await service.ratingsFor(account, profileId);
        await _json(request.response, 200, {'success': true, 'ratings': ratings});
        return;
      }
      if (request.method == 'POST' && request.uri.path == '$prefix/matches') {
        final body = await _body(request);
        final profileId = body['profileId']?.toString().trim() ?? '';
        final gameId = body['gameId']?.toString().trim() ?? '';
        final mode = body['mode']?.toString().trim() ?? 'casual';
        if (profileId.isEmpty || gameId.isEmpty) throw const FormatException('profileId and gameId are required.');
        if (!_profileBelongsToAccount(account, profileId)) throw StateError('Profile does not belong to this account.');
        final match = await service.createMatch(account: account, profileId: profileId, gameId: gameId, mode: mode, opponentProfileId: body['opponentProfileId']?.toString());
        await _json(request.response, 201, {'success': true, 'match': match});
        return;
      }
      if (request.method == 'POST' && request.uri.path == '$prefix/results') {
        final body = await _body(request);
        final profileId = body['profileId']?.toString().trim() ?? '';
        final gameId = body['gameId']?.toString().trim() ?? '';
        final mode = body['mode']?.toString().trim() ?? 'ranked';
        final result = body['result']?.toString().trim().toLowerCase() ?? 'loss';
        if (profileId.isEmpty || gameId.isEmpty) throw const FormatException('profileId and gameId are required.');
        if (!_profileBelongsToAccount(account, profileId)) throw StateError('Profile does not belong to this account.');
        if (!{'win', 'loss', 'draw'}.contains(result)) throw const FormatException('Invalid result.');
        final updated = await service.submitResult(account: account, profileId: profileId, gameId: gameId, mode: mode, result: result, opponentRating: body['opponentRating'] is num ? (body['opponentRating'] as num).toDouble() : 500);
        await _json(request.response, 200, {'success': true, 'rating': updated});
        return;
      }
      await _json(request.response, 404, {'success': false, 'error': 'Game route not found.'});
    } on FormatException catch (error) {
      await _json(request.response, 400, {'success': false, 'error': error.message});
    } catch (error) {
      await _json(request.response, 500, {'success': false, 'error': 'Game request failed: $error'});
    }
  }

  bool _profileBelongsToAccount(dynamic account, String profileId) {
    try {
      return account.profiles.any((profile) => profile.id.toString() == profileId);
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> _body(HttpRequest request) async {
    final decoded = jsonDecode(await utf8.decoder.bind(request).join());
    if (decoded is! Map) throw const FormatException('Invalid JSON body.');
    return Map<String, dynamic>.from(decoded);
  }

  Future<void> _json(HttpResponse response, int status, Map<String, dynamic> body) async {
    response.statusCode = status;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    await response.close();
  }
}
