import 'dart:convert';
import 'dart:io';

import '../middleware/authentication.dart';
import '../services/tv_pairing_service.dart';

class TvPairingRoutes {
  static const String prefix = '/api/v1/tv-control';
  final AuthenticationMiddleware authentication;
  final TvPairingService service;

  TvPairingRoutes({required this.authentication, required this.service});

  Future<void> handle(HttpRequest request) async {
    final account = authentication.authenticate(request);
    if (account == null) {
      await _json(request.response, 401, {'success': false, 'error': 'Authentication required.'});
      return;
    }
    try {
      if (request.method == 'GET' && request.uri.path.startsWith('$prefix/state/')) {
        final tvDeviceId = Uri.decodeComponent(request.uri.path.substring('$prefix/state/'.length));
        await _json(request.response, 200, {'success': true, 'state': service.stateForAccount(account.id, tvDeviceId)});
        return;
      }
      if (request.method == 'POST' && request.uri.path == '$prefix/state') {
        final body = await _body(request);
        final tvDeviceId = body['tvDeviceId']?.toString().trim() ?? '';
        final state = body['state'] is Map ? Map<String, dynamic>.from(body['state'] as Map) : <String, dynamic>{};
        if (tvDeviceId.isEmpty) throw const FormatException('tvDeviceId is required.');
        service.updateState(accountId: account.id, tvDeviceId: tvDeviceId, state: state);
        await _json(request.response, 200, {'success': true});
        return;
      }
      if (request.method == 'GET' && request.uri.path == '$prefix/pairings') {
        await _json(request.response, 200, {'success': true, 'pairings': service.pairingsForAccount(account.id)});
        return;
      }

      if (request.method == 'POST' && request.uri.path == '$prefix/pairing-code') {
        final body = await _body(request);
        final tvDeviceId = body['tvDeviceId']?.toString().trim() ?? '';
        final tvDeviceName = body['tvDeviceName']?.toString().trim() ?? 'Living Room TV';
        if (tvDeviceId.isEmpty) throw const FormatException('tvDeviceId is required.');
        final result = service.createCode(accountId: account.id, tvDeviceId: tvDeviceId, tvDeviceName: tvDeviceName);
        await _json(request.response, 201, {'success': true, ...result});
        return;
      }
      if (request.method == 'POST' && request.uri.path == '$prefix/pair') {
        final body = await _body(request);
        final code = body['code']?.toString().trim() ?? '';
        final phoneDeviceId = body['phoneDeviceId']?.toString().trim() ?? '';
        final profileId = body['profileId']?.toString().trim() ?? '';
        if (code.isEmpty || phoneDeviceId.isEmpty || profileId.isEmpty) throw const FormatException('code, phoneDeviceId and profileId are required.');
        final profiles = account.profiles;
        final belongs = profiles.any((profile) {
          try { return profile.id.toString() == profileId; } catch (_) { return false; }
        });
        if (!belongs) throw StateError('Profile does not belong to this account.');
        final result = service.pair(accountId: account.id, code: code, phoneDeviceId: phoneDeviceId, profileId: profileId);
        await _json(request.response, 200, {'success': true, 'pairing': result});
        return;
      }
      if (request.method == 'POST' && request.uri.path == '$prefix/command') {
        final body = await _body(request);
        final tvDeviceId = body['tvDeviceId']?.toString().trim() ?? '';
        final profileId = body['profileId']?.toString().trim() ?? '';
        final command = body['command'];
        if (tvDeviceId.isEmpty || profileId.isEmpty || command is! Map) throw const FormatException('tvDeviceId, profileId and command are required.');
        final profiles = account.profiles;
        final belongs = profiles.any((profile) {
          try { return profile.id.toString() == profileId; } catch (_) { return false; }
        });
        if (!belongs) throw StateError('Profile does not belong to this account.');
        service.command(accountId: account.id, tvDeviceId: tvDeviceId, profileId: profileId, command: Map<String, dynamic>.from(command));
        await _json(request.response, 202, {'success': true});
        return;
      }
      if (request.method == 'GET' && request.uri.path.startsWith('$prefix/commands/')) {
        final tvDeviceId = request.uri.path.substring('$prefix/commands/'.length).trim();
        if (tvDeviceId.isEmpty) throw const FormatException('tvDeviceId is required.');
        await _json(request.response, 200, {'success': true, 'commands': service.drainCommands(account.id, tvDeviceId)});
        return;
      }
      await _json(request.response, 404, {'success': false, 'error': 'TV control route not found.'});
    } on FormatException catch (error) {
      await _json(request.response, 400, {'success': false, 'error': error.message});
    } on StateError catch (error) {
      await _json(request.response, 409, {'success': false, 'error': error.message});
    } catch (_) {
      await _json(request.response, 500, {'success': false, 'error': 'TV control request failed.'});
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
