import 'dart:convert';
import 'dart:io';

import '../middleware/authentication.dart';
import '../services/platform_server_service.dart';

class PlatformServerRoutes {
  static const String prefix = '/api/v1/platform-servers';
  final AuthenticationMiddleware authentication;
  final PlatformServerService service;

  PlatformServerRoutes({required this.authentication, required this.service});

  Future<void> handle(HttpRequest request) async {
    final account = authentication.authenticate(request);
    if (account == null) {
      await _json(request.response, 401, {'success': false, 'error': 'Authentication required.'});
      return;
    }

    try {
      if (request.method == 'GET' && request.uri.path == '$prefix/context') {
        final context = await service.contextFor(account);
        await _json(request.response, 200, {
          'success': true,
          'currentServer': context.currentServer?.toJson(),
          'availableServers': context.availableServers.map((s) => s.toJson()).toList(growable: false),
        });
        return;
      }

      if (request.method == 'POST' && request.uri.path == '$prefix/claim') {
        final body = await _body(request);
        final serverId = body['serverId']?.toString().trim() ?? '';
        final displayName = body['displayName']?.toString().trim() ?? '';
        if (serverId.isEmpty || displayName.isEmpty) {
          throw FormatException('serverId and displayName are required.');
        }
        final server = await service.claim(account: account, serverId: serverId, displayName: displayName);
        await _json(request.response, 201, {'success': true, 'server': server.toJson()});
        return;
      }

      if (request.method == 'PATCH' && request.uri.path == '$prefix/name') {
        final body = await _body(request);
        final displayName = body['displayName']?.toString().trim() ?? '';
        if (displayName.isEmpty) throw FormatException('displayName is required.');
        final server = await service.rename(account: account, displayName: displayName);
        await _json(request.response, 200, {'success': true, 'server': server?.toJson()});
        return;
      }

      if (request.method == 'POST' && request.uri.path == '$prefix/release') {
        await service.release(account);
        await _json(request.response, 200, {'success': true});
        return;
      }

      await _json(request.response, 404, {'success': false, 'error': 'Platform server route not found.'});
    } on FormatException catch (error) {
      await _json(request.response, 400, {'success': false, 'error': error.message});
    } on ArgumentError catch (error) {
      await _json(request.response, 400, {'success': false, 'error': error.message});
    } on StateError catch (error) {
      await _json(request.response, 409, {'success': false, 'error': error.message});
    } catch (_) {
      await _json(request.response, 500, {'success': false, 'error': 'Server selection request failed.'});
    }
  }

  Future<Map<String, dynamic>> _body(HttpRequest request) async {
    final raw = await utf8.decoder.bind(request).join();
    final decoded = jsonDecode(raw);
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
