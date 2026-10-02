// FILE: Backend/routes/location_routes.dart
// Purpose: Provides address suggestions, reverse geocoding, and postal-code
// lookup for store, checkout, and nearby-radio flows. GeoNames is used for
// postal lookup when configured; OpenStreetMap Photon supplies public fallback
// results and address suggestions.
//
// Security notes:
// - This endpoint is intentionally public because checkout address forms may
//   need postal-code lookup before authentication.
// - Address queries and approximate radio coordinates are sent to Photon when
//   the user requests address or nearby-station lookup.
// - Postal lookup sends only the selected city and country to its provider.
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
  static const String _postalCodesPath = '/api/v1/location/postal-codes';
  static const String _addressSuggestionsPath =
      '/api/v1/location/address-suggestions';
  static const String _reverseGeocodePath = '/api/v1/location/reverse';

  static const Duration _providerTimeout = Duration(seconds: 8);

  static const int _maxCityLength = 120;
  static const int _maxPostalCodeLength = 32;
  static const int _maxAddressQueryLength = 200;

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
    if (request.method == 'GET' && path == _addressSuggestionsPath) {
      await _addressSuggestions(request);
      return;
    }
    if (request.method == 'GET' && path == _reverseGeocodePath) {
      await _reverseGeocode(request);
      return;
    }

    await _json(request, 404, {
      'success': false,
      'error': 'Location route not found.',
    });
  }

  Future<void> _addressSuggestions(HttpRequest request) async {
    final query = request.uri.queryParameters['q']?.trim() ?? '';
    if (query.length < 3 || query.length > _maxAddressQueryLength) {
      await _json(request, 400, {
        'success': false,
        'error':
            'q must contain between 3 and $_maxAddressQueryLength characters.',
      });
      return;
    }

    try {
      final features = await _photonFeatures(
        Uri.https('photon.komoot.io', '/api/', {
          'q': query,
          'limit': '8',
          'lang': 'en',
        }),
      );
      final suggestions = features
          .map(_normalizePhotonFeature)
          .where((address) => address['label']?.toString().isNotEmpty == true)
          .toList(growable: false);
      await _json(request, 200, {
        'success': true,
        'suggestions': suggestions,
      });
    } on TimeoutException catch (error, stackTrace) {
      developer.log(
        'Photon address lookup timed out.',
        name: 'location_routes',
        error: error,
        stackTrace: stackTrace,
      );
      await _json(request, 504, {
        'success': false,
        'error': 'Address search timed out.',
      });
    } on HttpException catch (error, stackTrace) {
      developer.log(
        'Photon address lookup failed.',
        name: 'location_routes',
        error: error,
        stackTrace: stackTrace,
      );
      await _json(request, 502, {
        'success': false,
        'error': 'Address search is temporarily unavailable.',
      });
    } on FormatException catch (error, stackTrace) {
      developer.log(
        'Photon returned invalid address data.',
        name: 'location_routes',
        error: error,
        stackTrace: stackTrace,
      );
      await _json(request, 502, {
        'success': false,
        'error': 'Address provider returned invalid data.',
      });
    } on SocketException catch (error, stackTrace) {
      developer.log(
        'Photon address search failed at the network layer.',
        name: 'location_routes',
        error: error,
        stackTrace: stackTrace,
      );
      await _json(request, 502, {
        'success': false,
        'error': 'Address search is temporarily unavailable.',
      });
    }
  }

  Future<void> _reverseGeocode(HttpRequest request) async {
    final latitude = double.tryParse(
      request.uri.queryParameters['lat']?.trim() ?? '',
    );
    final longitude = double.tryParse(
      request.uri.queryParameters['lon']?.trim() ?? '',
    );
    if (latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      await _json(request, 400, {
        'success': false,
        'error': 'Valid latitude and longitude values are required.',
      });
      return;
    }

    try {
      final features = await _photonFeatures(
        Uri.https('photon.komoot.io', '/reverse/', {
          'lat': '$latitude',
          'lon': '$longitude',
          'lang': 'en',
        }),
      );
      if (features.isEmpty) {
        await _json(request, 404, {
          'success': false,
          'error': 'No address was found for the current location.',
        });
        return;
      }
      await _json(request, 200, {
        'success': true,
        'location': _normalizePhotonFeature(features.first),
      });
    } on TimeoutException catch (error, stackTrace) {
      developer.log(
        'Photon reverse lookup timed out.',
        name: 'location_routes',
        error: error,
        stackTrace: stackTrace,
      );
      await _json(request, 504, {
        'success': false,
        'error': 'Current location lookup timed out.',
      });
    } on HttpException catch (error, stackTrace) {
      developer.log(
        'Photon reverse lookup failed.',
        name: 'location_routes',
        error: error,
        stackTrace: stackTrace,
      );
      await _json(request, 502, {
        'success': false,
        'error': 'Current location lookup is temporarily unavailable.',
      });
    } on FormatException catch (error, stackTrace) {
      developer.log(
        'Photon returned invalid reverse-lookup data.',
        name: 'location_routes',
        error: error,
        stackTrace: stackTrace,
      );
      await _json(request, 502, {
        'success': false,
        'error': 'Location provider returned invalid data.',
      });
    } on SocketException catch (error, stackTrace) {
      developer.log(
        'Photon reverse lookup failed at the network layer.',
        name: 'location_routes',
        error: error,
        stackTrace: stackTrace,
      );
      await _json(request, 502, {
        'success': false,
        'error': 'Current location lookup is temporarily unavailable.',
      });
    }
  }

  Future<List<Map<String, dynamic>>> _photonFeatures(Uri uri) async {
    final client = HttpClient()..connectionTimeout = _providerTimeout;
    try {
      final providerRequest =
          await client.getUrl(uri).timeout(_providerTimeout);
      providerRequest.headers.set(
        HttpHeaders.userAgentHeader,
        'MyOwnStreamingService/1.0 address lookup',
      );
      final response = await providerRequest.close().timeout(_providerTimeout);
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(_providerTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Photon returned HTTP ${response.statusCode}.',
        );
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map || decoded['features'] is! List) {
        throw const FormatException('Unexpected Photon response.');
      }
      return (decoded['features'] as List)
          .whereType<Map>()
          .map((feature) => Map<String, dynamic>.from(feature))
          .toList(growable: false);
    } finally {
      client.close(force: true);
    }
  }

  Map<String, dynamic> _normalizePhotonFeature(
    Map<String, dynamic> feature,
  ) {
    final properties = feature['properties'] is Map
        ? Map<String, dynamic>.from(feature['properties'] as Map)
        : <String, dynamic>{};
    String? firstValue(Iterable<String> keys) {
      for (final key in keys) {
        final value = properties[key]?.toString().trim();
        if (value != null && value.isNotEmpty) return value;
      }
      return null;
    }

    final houseNumber = firstValue(const ['housenumber']);
    final street = firstValue(const ['street', 'name']);
    final addressLine1 = [
      if (houseNumber != null && street != null) houseNumber,
      if (street != null) street,
    ].join(' ');
    final city = firstValue(
      const ['city', 'locality', 'town', 'village', 'municipality'],
    );
    final state = firstValue(const ['state', 'county']);
    final postalCode = firstValue(const ['postcode']);
    final country = firstValue(const ['country']);
    final countryCode = firstValue(const ['countrycode'])?.toUpperCase();
    final label = [
      if (addressLine1.isNotEmpty) addressLine1,
      if (city != null) city,
      if (state != null) state,
      if (postalCode != null) postalCode,
      if (country != null) country,
    ].join(', ');

    return {
      'label':
          label.isEmpty ? firstValue(const ['name', 'district']) ?? '' : label,
      'addressLine1': addressLine1,
      'city': city ?? '',
      'state': state ?? '',
      'stateCode': firstValue(const ['statecode']) ?? '',
      'postalCode': postalCode ?? '',
      'country': country ?? '',
      'countryCode': countryCode ?? '',
    };
  }

  Future<void> _postalCodes(HttpRequest request) async {
    final username = AppConfig.geonamesUsername.trim();

    final country =
        request.uri.queryParameters['country']?.trim().toUpperCase();

    final city = request.uri.queryParameters['city']?.trim();

    final postal = request.uri.queryParameters['postalCode']?.trim();

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

    if (username.isEmpty) {
      await _postalCodesFromPhoton(request, country!, city);
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

    final client = HttpClient()..connectionTimeout = _providerTimeout;

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

  Future<void> _postalCodesFromPhoton(
    HttpRequest request,
    String country,
    String city,
  ) async {
    try {
      final features = await _photonFeatures(
        Uri.https('photon.komoot.io', '/api/', {
          'q': city,
          'countrycode': country.toLowerCase(),
          'limit': '20',
          'lang': 'en',
        }),
      );
      final codes = <String>{};
      for (final feature in features) {
        final properties = feature['properties'];
        if (properties is! Map) continue;
        final value = properties['postcode']?.toString().trim();
        if (value != null && value.isNotEmpty) codes.add(value);
      }
      final sortedCodes = codes.toList()..sort();
      await _json(request, 200, {
        'success': true,
        'country': country,
        'city': city,
        'postalCodes': sortedCodes,
        'source': 'OpenStreetMap Photon',
      });
    } on TimeoutException catch (error, stackTrace) {
      developer.log(
        'Photon postal-code lookup timed out.',
        name: 'location_routes',
        error: error,
        stackTrace: stackTrace,
      );
      await _json(request, 504, {
        'success': false,
        'error': 'Postal-code search timed out.',
      });
    } on HttpException catch (error, stackTrace) {
      developer.log(
        'Photon postal-code lookup failed.',
        name: 'location_routes',
        error: error,
        stackTrace: stackTrace,
      );
      await _json(request, 502, {
        'success': false,
        'error': 'Postal-code search is temporarily unavailable.',
      });
    } on FormatException catch (error, stackTrace) {
      developer.log(
        'Photon returned invalid postal-code data.',
        name: 'location_routes',
        error: error,
        stackTrace: stackTrace,
      );
      await _json(request, 502, {
        'success': false,
        'error': 'Postal-code provider returned invalid data.',
      });
    } on SocketException catch (error, stackTrace) {
      developer.log(
        'Photon postal-code lookup failed at the network layer.',
        name: 'location_routes',
        error: error,
        stackTrace: stackTrace,
      );
      await _json(request, 502, {
        'success': false,
        'error': 'Postal-code search is temporarily unavailable.',
      });
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
