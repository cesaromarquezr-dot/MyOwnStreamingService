// API routes for the home media server dashboard.
import 'dart:convert';
import 'dart:io';
import '../middleware/authentication.dart';
import '../services/home_server_service.dart';

class HomeServerRoutes {
  final AuthenticationMiddleware authentication;
  final HomeServerService service;
  HomeServerRoutes({required this.authentication, required this.service});

  Future<void> handle(HttpRequest request) async {
  final auth = authentication.authenticate(request);
  if (auth == null) {
    await _json(
      request.response,
      401,
      {'success': false, 'error': 'Authentication required.'},
    );
    return;
  }

  try {
    if (request.method == 'GET' &&
        request.uri.path == '/api/v1/server/storage') {
      await _json(
        request.response,
        200,
        {'success': true, ...service.storageStatus()},
      );
      return;
    }

    if (request.method == 'GET' &&
        request.uri.path == '/api/v1/server/arm') {
      await _json(
        request.response,
        200,
        {'success': true, ...service.armStatus()},
      );
      return;
    }

    await _json(
      request.response,
      404,
      {'success': false, 'error': 'Home server route not found.'},
    );
  } catch (e) {
    await _json(
      request.response,
      500,
      {'success': false, 'error': e.toString()},
    );
  }
}

  Future<void> _json(HttpResponse response, int code, Map<String, dynamic> body) async {
    response.statusCode = code;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    await response.close();
  }
}
