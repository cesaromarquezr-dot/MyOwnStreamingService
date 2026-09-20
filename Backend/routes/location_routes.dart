// FILE: Backend/routes/location_routes.dart
// Purpose: Provides secure, provider-backed postal-code lookup for store and
// checkout address flows. Country/state/city selection itself is bundled in
// Flutter; this route is used when the UI needs postal-code results for a city.

import 'dart:convert';
import 'dart:io';

import '../config.dart';

class LocationRoutes {
  /// Handles public geographic lookup requests.
  Future<void> handle(HttpRequest request) async {
    final path = request.uri.path;
    if (request.method == 'GET' && path == '/api/v1/location/postal-codes') {
      return _postalCodes(request);
    }

    await _json(request, 404, {
      'success': false,
      'error': 'Location route not found.',
    });
  }

  Future<void> _postalCodes(HttpRequest request) async {
    final username = AppConfig.geonamesUsername;
    final country = request.uri.queryParameters['country']?.trim().toUpperCase();
    final city = request.uri.queryParameters['city']?.trim();
    final postal = request.uri.queryParameters['postalCode']?.trim();

    if (username.isEmpty) {
      return _json(request, 503, {
        'success': false,
        'error': 'Postal-code provider is not configured. Set GEONAMES_USERNAME on the backend.',
      });
    }
    if (country == null || country.length != 2 || city == null || city.isEmpty) {
      return _json(request, 400, {
        'success': false,
        'error': 'country (ISO-2) and city are required.',
      });
    }

    final query = <String, String>{
      'placename': city,
      'country': country,
      'maxRows': '1000',
      'username': username,
      'type': 'json',
    };
    if (postal != null && postal.isNotEmpty) query['postalcode'] = postal;

    final uri = Uri.https('secure.geonames.org', '/postalCodeSearchJSON', query);
    final client = HttpClient();
    try {
      final response = await (await client.getUrl(uri)).close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _json(request, 502, {
          'success': false,
          'error': 'Postal-code provider returned HTTP ${response.statusCode}.',
        });
      }
      final decoded = jsonDecode(body);
      final codes = <String>{};
      if (decoded is Map && decoded['postalCodes'] is List) {
        for (final row in decoded['postalCodes'] as List) {
          if (row is Map && row['postalCode'] != null) {
            final value = row['postalCode'].toString().trim();
            if (value.isNotEmpty) codes.add(value);
          }
        }
      }
      return _json(request, 200, {
        'success': true,
        'country': country,
        'city': city,
        'postalCodes': codes.toList()..sort(),
      });
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _json(HttpRequest request, int status, Map<String, dynamic> data) async {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(data));
    await request.response.close();
  }
}
