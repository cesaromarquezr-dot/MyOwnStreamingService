import 'dart:convert';
import 'dart:io';

import '../middleware/authentication.dart';

class LibraryRoutes {
  final AuthenticationMiddleware authentication;

  LibraryRoutes({required this.authentication});

  Future<void> handle(HttpRequest request) async {
    final account = authentication.authenticate(request);
    if (account == null) {
      return _json(request.response, 401, {
      'success': false,
      'error': 'Authentication required.',
      });
    }

    final path = request.uri.path;
    if (request.method == 'GET' && path == '/api/v1/library/privacy') {
      return _json(request.response, 200, {
        'success': true,
        'accountId': account.id,
        'privateLibrary': true,
        'storage': {
          'limitBytes': account.storageLimitBytes,
          'usedBytes': account.storageUsedBytes,
        },
        'ownershipDeclarationRequiredForDiscImport': true,
        'deleteMediaWithAccountDeletion': true,
      });
    }

    if (request.method == 'POST' && path == '/api/v1/library/ownership-declaration') {
      final body = await _body(request);
      if (body['confirmed'] != true) {
        return _json(request.response, 400, {
          'success': false,
          'error': 'Ownership/authorization confirmation is required.',
        });
      }
      return _json(request.response, 200, {
        'success': true,
        'accountId': account.id,
        'confirmed': true,
        'message': 'Authorized-use declaration recorded for this import session.',
      });
    }

    if (request.method == 'POST' && path == '/api/v1/library/deletion-request') {
      return _json(request.response, 202, {
        'success': true,
        'accountId': account.id,
        'status': 'queued',
        'message': 'Library deletion has been queued. Production storage workers must remove originals, derivatives, caches and backups according to the retention policy.',
      });
    }

    return _json(request.response, 404, {
      'success': false,
      'error': 'Library route not found.',
    });
  }

  Future<Map<String, dynamic>> _body(HttpRequest request) async {
    final raw = await utf8.decoder.bind(request).join();
    if (raw.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) throw Exception('JSON object required.');
    return Map<String, dynamic>.from(decoded);
  }

  Future<void> _json(HttpResponse response, int code, Map<String, dynamic> data) async {
    response.statusCode = code;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(data));
    await response.close();
  }
}
