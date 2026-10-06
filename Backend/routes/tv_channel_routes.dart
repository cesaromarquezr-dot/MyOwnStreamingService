import 'dart:convert';
import 'dart:io';

import '../middleware/authentication.dart';
import '../services/tv_channel_service.dart';

class TvChannelRoutes {
  static const prefix = '/api/v1/tv-channels';
  final AuthenticationMiddleware authentication;
  final TvChannelService service;

  TvChannelRoutes({required this.authentication, required this.service});

  Future<void> handle(HttpRequest request) async {
    if (request.method == 'OPTIONS') {
      await _json(request.response, 204, {});
      return;
    }
    if (authentication.authenticate(request) == null) {
      await _json(request.response, 401, {'success': false, 'error': 'Authentication required.'});
      return;
    }

    if (request.method == 'GET' && request.uri.path == '$prefix/capabilities') {
      await _json(request.response, 200, {'success': true, ...service.capabilities()});
      return;
    }
    if (request.method == 'GET' && request.uri.path == '$prefix/definitions') {
      final kids = request.uri.queryParameters['kids'] == 'true';
      await _json(request.response, 200, {'success': true, 'channels': service.channelDefinitions(kidsProfile: kids)});
      return;
    }
    if (request.method == 'GET' && request.uri.path == '$prefix/seasonal-policy') {
      final kids = request.uri.queryParameters['kids'] == 'true';
      await _json(request.response, 200, {'success': true, 'policy': service.seasonalPolicy(kidsProfile: kids)});
      return;
    }
    if (request.method == 'POST' && request.uri.path == '$prefix/classify') {
      final body = await _body(request);
      await _json(request.response, 200, {'success': true, 'intelligence': service.classify(body)});
      return;
    }
    await _json(request.response, 404, {'success': false, 'error': 'TV channel route not found.'});
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
