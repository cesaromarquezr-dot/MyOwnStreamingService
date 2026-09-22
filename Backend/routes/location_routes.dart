// FILE: Backend/routes/location_routes.dart
// Purpose: Provides secure, provider-backed postal-code lookup for store and
// checkout address flows. Country/state/city selection itself is bundled in
// Flutter; this route is used when the UI needs postal-code results for a city.
//
// Security notes:
// - This endpoint is intentionally public because checkout address forms may
//   need postal-code lookup before authentication.
// - Only city/country/postal-code search parameters are sent to GeoNames.
// - Provider credentials are never returned to clients.
// - Provider requests have bounded timeouts.
// - Provider failures are normalized into generic API errors.
// - Responses are marked no-store because postal lookup is an external,
//   provider-backed request rather than authoritative account data.

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import '../config.dart';

class LocationRoutes {
  static const String _postalCodesPath =
      '/api/v1/location/postal-codes';

  static const Duration _providerTimeout = Duration(seconds: 8);

  static const int _maxCityLength = 120;
  static const int _maxPostalCodeLength = 32;

  /// Handles public geographic lookup requests.
  Future<void> handle(HttpRequest request) async {
    _applyCors(request);

    if (request.method == 'OPTIONS') {
      await _empty(request, 204);
      return;
    }

    final path = request.uri.path;

    if (request.method == 'GET' && path == _postalCodesPath) {
      await _postalCodes(request);
      return;
    }

    await _json(request, 404, {
      'success': false,
      'error': 'Location route not found.',
    });
  }

  Future<void> _postalCodes(HttpRequest request) async {
    final username = AppConfig.geonamesUsername.trim();

    final country =
        request.uri.queryParameters['country']?.trim().toUpperCase();

    final city = request.uri.queryParameters['city']?.trim();

    final postal =
        request.uri.queryParameters['postalCode']?.trim();

    if (username.isEmpty) {
      await _json(request, 503, {
        'success': false,
        'error': 'Postal-code provider is not configured.',
      });
      return;
    }

    if (!_isValidCountry(country)) {
      await _json(request, 400, {
        'success': false,
        'error': 'country must be a valid ISO-2 country code.',
      });
      return;
    }

    if (city == null || city.isEmpty) {
      await _json(request, 400, {
        'success': false,
        'error': 'city is required.',
      });
      return;
    }

    if (city.length > _maxCityLength) {
      await _json(request, 400, {
        'success': false,
        'error': 'city is too long.',
      });
      return;
    }

    if (postal != null && postal.length > _maxPostalCodeLength) {
      await _json(request, 400, {
        'success': false,
        'error': 'postalCode is too long.',
      });
      return;
    }

    final query = <String, String>{
      'placename': city,
      'country': country!,
      'maxRows': '1000',
      'username': username,
      'type': 'json',
    };

    if (postal != null && postal.isNotEmpty) {
      query['postalcode'] = postal;
    }

    final uri = Uri.https(
      'secure.geonames.org',
      '/postalCodeSearchJSON',
      query,
    );

    final client = HttpClient()
      ..connectionTimeout = _providerTimeout;

    try {
      final providerResponse = await client
          .getUrl(uri)
          .timeout(_providerTimeout)
          .then((request) => request.close())
          .timeout(_providerTimeout);

      final body = await providerResponse
          .transform(utf8.decoder)
          .join()
          .timeout(_providerTimeout);

      if (providerResponse.statusCode < 200 ||
          providerResponse.statusCode >= 300) {
        developer.log(
          'GeoNames returned HTTP ${providerResponse.statusCode}.',
          name: 'location_routes',
        );

        await _json(request, 502, {
          'success': false,
          'error': 'Postal-code provider is temporarily unavailable.',
        });
        return;
      }

      dynamic decoded;

      try {
        decoded = jsonDecode(body);
      } on FormatException catch (error, stackTrace) {
        developer.log(
          'GeoNames returned invalid JSON.',
          name: 'location_routes',
          error: error,
          stackTrace: stackTrace,
        );

        await _json(request, 502, {
          'success': false,
          'error': 'Postal-code provider returned an invalid response.',
        });
        return;
      }

      // GeoNames may return HTTP 200 with a JSON-level error object.
      if (decoded is Map && decoded['status'] is Map) {
        final providerStatus = decoded['status'];
        final providerMessage = providerStatus is Map
            ? providerStatus['message']?.toString()
            : null;

        developer.log(
          'GeoNames reported a provider error'
          '${providerMessage == null ? '.' : ': $providerMessage'}',
          name: 'location_routes',
        );

        await _json(request, 502, {
          'success': false,
          'error': 'Postal-code provider rejected the lookup.',
        });
        return;
      }

      final codes = <String>{};

      if (decoded is Map && decoded['postalCodes'] is List) {
        for (final row in decoded['postalCodes'] as List) {
          if (row is! Map) {
            continue;
          }

          final value = row['postalCode']?.toString().trim();

          if (value != null && value.isNotEmpty) {
            codes.add(value);
          }
        }
      }

      final sortedCodes = codes.toList()..sort();

      await _json(request, 200, {
        'success': true,
        'country': country,
        'city': city,
        'postalCodes': sortedCodes,
      });
    } on TimeoutException catch (error, stackTrace) {
      developer.log(
        'GeoNames postal-code lookup timed out.',
        name: 'location_routes',
        error: error,
        stackTrace: stackTrace,
      );

      await _json(request, 504, {
        'success': false,
        'error': 'Postal-code provider timed out.',
      });
    } on SocketException catch (error, stackTrace) {
      developer.log(
        'GeoNames postal-code lookup failed at the network layer.',
        name: 'location_routes',
        error: error,
        stackTrace: stackTrace,
      );

      await _json(request, 502, {
        'success': false,
        'error': 'Postal-code provider is unavailable.',
      });
    } on HttpException catch (error, stackTrace) {
      developer.log(
        'GeoNames postal-code lookup failed.',
        name: 'location_routes',
        error: error,
        stackTrace: stackTrace,
      );

      await _json(request, 502, {
        'success': false,
        'error': 'Postal-code provider is unavailable.',
      });
    } catch (error, stackTrace) {
      developer.log(
        'Unexpected postal-code lookup failure.',
        name: 'location_routes',
        error: error,
        stackTrace: stackTrace,
      );

      await _json(request, 502, {
        'success': false,
        'error': 'Postal-code lookup failed.',
      });
    } finally {
      client.close(force: true);
    }
  }

  bool _isValidCountry(String? country) {
    if (country == null || country.length != 2) {
      return false;
    }

    return RegExp(r'^[A-Z]{2}$').hasMatch(country);
  }

  void _applyCors(HttpRequest request) {
    final headers = request.response.headers;

    headers.set('Access-Control-Allow-Origin', '*');
    headers.set(
      'Access-Control-Allow-Methods',
      'GET, OPTIONS',
    );
    headers.set(
      'Access-Control-Allow-Headers',
      'Authorization, Content-Type',
    );
    headers.set(
      'Access-Control-Expose-Headers',
      'Content-Type',
    );
  }

  Future<void> _json(
    HttpRequest request,
    int status,
    Map<String, dynamic> data,
  ) async {
    if (_responseHasStarted(request)) {
      return;
    }

    final response = request.response;

    response.statusCode = status;
    response.headers.contentType = ContentType.json;
    response.headers.set(
      'Cache-Control',
      'no-store, no-cache, must-revalidate',
    );
    response.headers.set('Pragma', 'no-cache');
    response.headers.set('X-Content-Type-Options', 'nosniff');

    response.write(jsonEncode(data));
    await response.close();
  }

  Future<void> _empty(
    HttpRequest request,
    int status,
  ) async {
    if (_responseHasStarted(request)) {
      return;
    }

    final response = request.response;

    response.statusCode = status;
    response.headers.set(
      'Cache-Control',
      'no-store, no-cache, must-revalidate',
    );
    response.headers.set('Pragma', 'no-cache');

    await response.close();
  }

  bool _responseHasStarted(HttpRequest request) {
    return request.response.headers.contentType != null ||
        request.response.statusCode != 200;
  }
}