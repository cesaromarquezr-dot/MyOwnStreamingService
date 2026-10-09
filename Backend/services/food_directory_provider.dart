// FILE: Backend/services/food_directory_provider.dart
// Purpose: Best-effort discovery of nearby public restaurant listings.
//
// The public Photon service is used as an OpenStreetMap-backed discovery source.
// It is not a commercial SLA-backed restaurant directory. Results may be
// incomplete, outdated, or missing phone/menu details. Registered platform
// restaurants remain the source of truth for in-app ordering and checkout.

import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;

class FoodDirectoryProvider {
  FoodDirectoryProvider._();

  static final FoodDirectoryProvider instance = FoodDirectoryProvider._();

  static const Duration _cacheTtl = Duration(minutes: 10);
  static const int _limitPerCategory = 35;
  static const int _maxResponseBytes = 2 * 1024 * 1024;
  static const Duration _timeout = Duration(seconds: 5);

  final Map<String, _DirectoryCacheEntry> _cache = {};

  bool get enabled {
    final value = (Platform.environment['FOOD_EXTERNAL_DIRECTORY_ENABLED'] ?? 'true')
        .trim()
        .toLowerCase();
    return value != 'false' && value != '0' && value != 'no';
  }

  Future<List<Map<String, dynamic>>> nearby({
    required double latitude,
    required double longitude,
    required double radiusKm,
    int limit = 50,
  }) async {
    if (!enabled) return const [];
    if (!latitude.isFinite || !longitude.isFinite ||
        latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
      return const [];
    }

    final safeRadius = radiusKm.clamp(0.5, 50.0).toDouble();
    final safeLimit = limit.clamp(1, 100).toInt();
    final cacheKey = '${latitude.toStringAsFixed(3)}:${longitude.toStringAsFixed(3)}:${safeRadius.round()}';
    final now = DateTime.now().toUtc();
    final cached = _cache[cacheKey];
    if (cached != null && now.isBefore(cached.expiresAt)) {
      return cached.results.take(safeLimit).toList(growable: false);
    }

    final resultsById = <String, Map<String, dynamic>>{};
    // Photon supports category-filtered reverse lookups. Query food categories
    // concurrently to keep the user-facing wait bounded by one provider timeout.
    final categories = const ['restaurant', 'fast_food', 'cafe', 'food_court'];
    final featureSets = await Future.wait(categories.map((category) =>
        _safeRequestFeatures(latitude, longitude, category)));
    for (final features in featureSets) {
      for (final feature in features) {
        final item = _toRestaurant(feature, latitude, longitude);
        if (item == null) continue;
        final distance = (item['distanceKm'] as num).toDouble();
        if (distance > safeRadius) continue;
        resultsById.putIfAbsent(item['id'] as String, () => item);
      }
    }

    final results = resultsById.values.toList(growable: true)
      ..sort((a, b) =>
          (a['distanceKm'] as num).compareTo((b['distanceKm'] as num)));
    final capped = results.take(100).toList(growable: false);
    _cache[cacheKey] = _DirectoryCacheEntry(
      expiresAt: now.add(_cacheTtl),
      results: capped,
    );
    // Keep the in-memory cache bounded for a long-running backend.
    if (_cache.length > 300) {
      final expiredKeys = _cache.entries
          .where((entry) => now.isAfter(entry.value.expiresAt))
          .map((entry) => entry.key)
          .toList(growable: false);
      for (final key in expiredKeys) {
        _cache.remove(key);
      }
      while (_cache.length > 300) {
        _cache.remove(_cache.keys.first);
      }
    }
    return capped.take(safeLimit).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _safeRequestFeatures(
    double latitude,
    double longitude,
    String category,
  ) async {
    try {
      return await _requestFeatures(
        latitude: latitude,
        longitude: longitude,
        category: category,
      );
    } catch (error, stackTrace) {
      developer.log(
        'External food directory lookup failed for $category.',
        name: 'food_directory_provider',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> _requestFeatures({
    required double latitude,
    required double longitude,
    required String category,
  }) async {
    final uri = Uri.https('photon.komoot.io', '/reverse/', {
      'lat': '$latitude',
      'lon': '$longitude',
      'limit': '$_limitPerCategory',
      'lang': 'en',
      'osm_tag': 'amenity:$category',
    });
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final request = await client.getUrl(uri).timeout(_timeout);
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'MyOwnStreamingService/1.0 (Food and Delivery restaurant discovery)',
      );
      final response = await request.close().timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.drain<void>();
        throw HttpException('Directory provider returned HTTP ${response.statusCode}.');
      }
      final bytes = <int>[];
      await for (final chunk in response.timeout(_timeout)) {
        if (bytes.length + chunk.length > _maxResponseBytes) {
          throw const FormatException('Directory response was too large.');
        }
        bytes.addAll(chunk);
      }
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map || decoded['features'] is! List) return const [];
      return (decoded['features'] as List)
          .whereType<Map>()
          .map((feature) => Map<String, dynamic>.from(feature))
          .toList(growable: false);
    } finally {
      client.close(force: true);
    }
  }

  Map<String, dynamic>? _toRestaurant(
    Map<String, dynamic> feature,
    double originLatitude,
    double originLongitude,
  ) {
    final properties = feature['properties'];
    final geometry = feature['geometry'];
    if (properties is! Map || geometry is! Map) return null;
    final tags = Map<String, dynamic>.from(properties);
    final coordinates = geometry['coordinates'];
    if (coordinates is! List || coordinates.length < 2) return null;
    final longitude = _asDouble(coordinates[0]);
    final latitude = _asDouble(coordinates[1]);
    if (!latitude.isFinite || !longitude.isFinite ||
        latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
      return null;
    }

    final name = _firstText(tags, const ['name', 'local_name', 'street']);
    if (name.isEmpty) return null;
    final osmType = _firstText(tags, const ['osm_type']).toLowerCase();
    final osmId = _firstText(tags, const ['osm_id']);
    if (osmId.isEmpty) return null;
    final id = 'osm_${osmType.isEmpty ? 'place' : osmType}_$osmId';
    final number = _firstText(tags, const ['housenumber', 'house_number']);
    final street = _firstText(tags, const ['street']);
    final address = [
      if (number.isNotEmpty) number,
      if (street.isNotEmpty) street,
    ].join(' ').trim();
    final distance = _distanceKm(originLatitude, originLongitude, latitude, longitude);
    final countryCode = _firstText(tags, const ['countrycode', 'country_code']).toUpperCase();
    final category = _firstText(tags, const ['osm_value', 'type', 'amenity']);
    final cuisine = _firstText(tags, const ['cuisine']);

    return {
      'id': id,
      'name': name,
      'cuisine': cuisine.isEmpty ? _categoryLabel(category) : cuisine.replaceAll(';', ', '),
      'description': 'Public OpenStreetMap directory listing. Details may be incomplete.',
      'phone': _firstText(tags, const ['phone', 'contact:phone']),
      'website': _firstText(tags, const ['website', 'contact:website', 'url']),
      'openingHours': _firstText(tags, const ['opening_hours']),
      'address': address,
      'city': _firstText(tags, const ['city', 'town', 'village', 'locality', 'district']),
      'stateRegion': _firstText(tags, const ['state', 'province', 'region']),
      'postalCode': _firstText(tags, const ['postcode', 'postal_code']),
      'countryCode': countryCode.length == 2 ? countryCode : '',
      'latitude': latitude,
      'longitude': longitude,
      'distanceKm': double.parse(distance.toStringAsFixed(2)),
      'rating': 0,
      'reviewCount': 0,
      'deliveryFeeCents': 0,
      'serviceFeeCents': 0,
      'taxRateBasisPoints': 0,
      'loyaltyPointsPerCurrency': 1,
      'allowsDelivery': false,
      'allowsPickup': false,
      'minimumOrderCents': 0,
      'etaMinMinutes': 0,
      'etaMaxMinutes': 0,
      'isOpen': true,
      'heroImageUrl': null,
      'tags': const <String>[],
      'currencyCode': 'USD',
      'source': 'openstreetmap',
      'isOrderable': false,
    };
  }

  String _categoryLabel(String value) => switch (value.toLowerCase()) {
        'restaurant' => 'Restaurant',
        'fast_food' => 'Fast food',
        'cafe' => 'Cafe',
        'food_court' => 'Food court',
        _ => 'Food business',
      };

  String _firstText(Map<String, dynamic> values, List<String> keys) {
    for (final key in keys) {
      final value = values[key]?.toString().trim() ?? '';
      if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
    }
    return '';
  }

  double _asDouble(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? double.nan;

  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}

class _DirectoryCacheEntry {
  final DateTime expiresAt;
  final List<Map<String, dynamic>> results;

  const _DirectoryCacheEntry({required this.expiresAt, required this.results});
}
