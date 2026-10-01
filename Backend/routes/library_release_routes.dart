import 'dart:convert';
import 'dart:io';

import '../middleware/authentication.dart';
import '../services/library_release_service.dart';

class LibraryReleaseRoutes {
  final AuthenticationMiddleware authentication;
  final LibraryReleaseService service;

  LibraryReleaseRoutes({required this.authentication, required this.service});

  Future<void> handle(HttpRequest request) async {
    _cors(request.response);
    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }
    final account = authentication.authenticate(request);
    if (account == null) return _json(request.response, 401, {'success': false, 'error': 'Authentication required.'});
    try {
      final path = request.uri.path;
      if (request.method == 'GET' && path == '/api/v1/library/releases') {
        return _json(request.response, 200, {'success': true, 'items': service.forAccount(account.id).map((e) => e.toJson()).toList()});
      }
      if (request.method == 'POST' && path == '/api/v1/library/releases') {
        final body = await _body(request);
        final item = service.schedule(
          accountId: account.id,
          mediaId: _required(body, 'mediaId'),
          title: _required(body, 'title'),
          mediaType: _required(body, 'mediaType'),
          scheduledFor: DateTime.parse(_required(body, 'scheduledFor')).toUtc(),
          timeZone: body['timeZone']?.toString() ?? 'UTC',
        );
        return _json(request.response, 201, {'success': true, 'item': item.toJson()});
      }
      final prefix = '/api/v1/library/releases/';
      if (path.startsWith(prefix)) {
        final remainder = path.substring(prefix.length);
        final parts = remainder.split('/');
        if (parts.length == 2 && parts[0].isNotEmpty && request.method == 'POST') {
          final id = parts[0];
          if (parts[1] == 'publish') return _json(request.response, 200, {'success': true, 'item': service.publishNow(id, accountId: account.id).toJson()});
          if (parts[1] == 'cancel') return _json(request.response, 200, {'success': true, 'item': service.cancel(id, accountId: account.id).toJson()});
        }
      }
      return _json(request.response, 404, {'success': false, 'error': 'Library release endpoint not found.'});
    } catch (e) {
      return _json(request.response, 400, {'success': false, 'error': e.toString().replaceFirst('Exception: ', '')});
    }
  }

  Future<Map<String, dynamic>> _body(HttpRequest request) async {
    final raw = await utf8.decoder.bind(request).join();
    final decoded = raw.trim().isEmpty ? <String, dynamic>{} : jsonDecode(raw);
    if (decoded is! Map) throw const FormatException('A JSON object is required.');
    return Map<String, dynamic>.from(decoded);
  }

  String _required(Map<String, dynamic> body, String key) {
    final value = body[key]?.toString().trim() ?? '';
    if (value.isEmpty) throw FormatException('$key is required.');
    return value;
  }

  Future<void> _json(HttpResponse response, int status, Map<String, dynamic> value) async {
    response.statusCode = status;
    response.headers.contentType = ContentType.json;
    response.headers.set('cache-control', 'no-store');
    response.write(jsonEncode(value));
    await response.close();
  }

  void _cors(HttpResponse response) {
    response.headers.set('access-control-allow-origin', '*');
    response.headers.set('access-control-allow-headers', 'Origin, Content-Type, Accept, Authorization');
    response.headers.set('access-control-allow-methods', 'GET, POST, OPTIONS');
  }
}
