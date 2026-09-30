// FILE: Backend/routes/radio_routes.dart.
// Purpose: Discovers publicly listed radio stations for the user's selected
// listening location and exposes station metadata to the Flutter client.
//
// The route combines Radio Browser directory data with a small set of
// broadcaster-confirmed market metadata. A station is never discarded solely
// because the public directory does not expose a playable raw stream; the UI
// can open the broadcaster's own listening page instead.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../middleware/authentication.dart';
import '../services/radio_market_catalog.dart';

class RadioRoutes {
  static const String _path = '/api/v1/radio/stations';
  static const Duration _timeout = Duration(seconds: 12);
  static const int _maxResponseBytes = 6 * 1024 * 1024;

  final AuthenticationMiddleware authentication;

  const RadioRoutes({required this.authentication});

  Future<void> handle(HttpRequest request) async {
    _applyCors(request.response);
    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }

    if (request.uri.path != _path) {
      await _json(request.response, HttpStatus.notFound, {
        'success': false,
        'error': 'Radio route not found.',
      });
      return;
    }

    final account = authentication.authenticate(request);
    if (account == null) {
      await _json(request.response, HttpStatus.unauthorized, {
        'success': false,
        'error': 'Authentication required.',
      });
      return;
    }
    final _ = account;

    if (request.method != 'GET') {
      await _json(request.response, HttpStatus.methodNotAllowed, {
        'success': false,
        'error': 'GET required.',
      });
      return;
    }

    try {
      final query = request.uri.queryParameters;
      final countryCode = _clean(query['countryCode'], 3)?.toUpperCase();
      final rawState = _clean(query['state'], 120);
      final state = rawState == null ? null : RadioMarketCatalog.normalizeStateForRoute(rawState);
      final city = _clean(query['city'], 160);
      final search = _clean(query['q'], 160);
      final tag = _clean(query['tag'], 120);
      final band = _clean(query['band'], 12)?.toUpperCase();
      final limit = _parseLimit(query['limit']);

      final rows = <Map<String, dynamic>>[];
      final seen = <String>{};

      // First try stations with healthy directory streams. A directory outage
      // should not prevent the verified market catalog from working.
      try {
        final firstBatch = await _fetchDirectory(
          countryCode: countryCode,
          state: state,
          city: city,
          search: search,
          tag: tag,
          hideBroken: true,
          fetchLimit: mathMax(limit * 3, 120),
        );
        _mergeDirectoryRows(rows, seen, firstBatch, band: band);
      } catch (_) {
        // Continue to the broadcaster catalog below.
      }

      // Some major broadcasters are present in public directories but their
      // stream endpoint is intentionally omitted or marked broken. Fetch a
      // second pass without dropping those metadata records.
      if (rows.length < limit) {
        try {
          final secondBatch = await _fetchDirectory(
            countryCode: countryCode,
            state: state,
            city: city,
            search: search,
            tag: tag,
            hideBroken: false,
            fetchLimit: mathMax(limit * 4, 180),
          );
          _mergeDirectoryRows(rows, seen, secondBatch, band: band);
        } catch (_) {
          // Continue with whatever the directory already returned.
        }
      }

      // Finally fill known local-market gaps. These rows point to official
      // listening pages when the raw stream is not available from the public
      // directory.
      if (countryCode != null && state != null && city != null) {
        for (final seed in RadioMarketCatalog.forLocation(
          countryCode: countryCode,
          state: state,
          city: city,
        )) {
          final normalized = _normalizeMarketStation(seed);
          if (band != null && normalized['band'] != band) continue;
          if (search != null && !_matchesSearch(normalized, search)) continue;
          if (tag != null && !_matchesTag(normalized, tag)) continue;
          final identity = _identityFor(normalized);
          if (!seen.add(identity)) continue;
          rows.add(normalized);
          if (rows.length >= limit) break;
        }
      }

      // Put actual local radio stations ahead of less useful directory rows
      // while keeping a stable deterministic order within each group.
      rows.sort((a, b) {
        final aMarket = a['source'] == 'Broadcaster market catalog' ? 0 : 1;
        final bMarket = b['source'] == 'Broadcaster market catalog' ? 0 : 1;
        if (aMarket != bMarket) return aMarket.compareTo(bMarket);
        final aLocal = a['city']?.toString().trim().isNotEmpty == true ? 0 : 1;
        final bLocal = b['city']?.toString().trim().isNotEmpty == true ? 0 : 1;
        if (aLocal != bLocal) return aLocal.compareTo(bLocal);
        final aFrequency = _number(a['frequency']) ?? 99999;
        final bFrequency = _number(b['frequency']) ?? 99999;
        return aFrequency.compareTo(bFrequency);
      });

      await _json(request.response, HttpStatus.ok, {
        'success': true,
        'source': 'Radio Browser + broadcaster market catalog',
        'location': {
          'countryCode': countryCode,
          'state': state,
          'city': city,
        },
        'stations': rows.take(limit).toList(growable: false),
      });
    } catch (error) {
      await _json(request.response, HttpStatus.badGateway, {
        'success': false,
        'error': 'Radio station discovery is temporarily unavailable.',
        'detail': error.toString().length > 300 ? error.toString().substring(0, 300) : error.toString(),
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchDirectory({
    required String? countryCode,
    required String? state,
    required String? city,
    required String? search,
    required String? tag,
    required bool hideBroken,
    required int fetchLimit,
  }) async {
    final params = <String, String>{
      'hidebroken': hideBroken ? 'true' : 'false',
      'order': 'clickcount',
      'reverse': 'true',
      'limit': '$fetchLimit',
    };
    if (countryCode != null) params['countrycode'] = countryCode;
    if (state != null) params['state'] = state;
    if (city != null) params['city'] = city;
    if (search != null) params['name'] = search;
    if (tag != null) params['tag'] = tag;

    final baseUrl = (Platform.environment['RADIO_BROWSER_BASE_URL'] ?? '')
        .trim()
        .replaceFirst(RegExp(r'/$'), '');
    final base = baseUrl.isEmpty ? 'https://all.api.radio-browser.info' : baseUrl;
    final uri = Uri.parse('$base/json/stations/search').replace(queryParameters: params);

    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final requestToApi = await client.getUrl(uri).timeout(_timeout);
      requestToApi.headers.set('User-Agent', 'StreamingService/1.0 radio discovery');
      final response = await requestToApi.close().timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Radio directory returned ${response.statusCode}.');
      }
      final bytes = await _readLimited(response);
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! List) throw const FormatException('Unexpected radio directory response.');
      return decoded.whereType<Map>().map(Map<String, dynamic>.from).toList(growable: false);
    } finally {
      client.close(force: true);
    }
  }

  static void _mergeDirectoryRows(
    List<Map<String, dynamic>> output,
    Set<String> seen,
    List<Map<String, dynamic>> decoded, {
    required String? band,
  }) {
    for (final row in decoded) {
      final streamUrl = _safeHttpUrl(row['url_resolved'] ?? row['url']);
      final homepage = _safeHttpUrl(row['homepage']);
      if (streamUrl == null && homepage == null) continue;
      final normalized = _normalizeStation(row, streamUrl: streamUrl, homepage: homepage);
      if (band != null && band.isNotEmpty && normalized['band'] != band) continue;
      final identity = _identityFor(normalized);
      if (!seen.add(identity)) continue;
      output.add(normalized);
    }
  }

  static Map<String, dynamic> _normalizeStation(
    Map<String, dynamic> row, {
    required String? streamUrl,
    required String? homepage,
  }) {
    final frequency = _number(row['frequency']);
    final name = row['name']?.toString() ?? 'Unknown station';
    final callSign = (row['callsign'] ?? row['call'] ?? '').toString().trim();
    return {
      'id': row['stationuuid']?.toString() ?? '',
      'name': name,
      'callSign': callSign,
      'country': row['country']?.toString() ?? '',
      'countryCode': row['countrycode']?.toString() ?? '',
      'state': row['state']?.toString() ?? '',
      'city': row['city']?.toString() ?? '',
      'language': row['language']?.toString() ?? '',
      'tags': row['tags']?.toString() ?? '',
      'homepage': homepage ?? '',
      'listenUrl': homepage ?? streamUrl ?? '',
      'favicon': row['favicon']?.toString() ?? '',
      'streamUrl': streamUrl ?? '',
      'streamAvailable': streamUrl != null,
      'codec': row['codec']?.toString() ?? '',
      'bitrate': _number(row['bitrate']),
      'frequency': frequency,
      'band': _inferBand(row, frequency),
      'nowPlaying': row['lastcheckok'] == 1 ? 'Live station stream' : 'Station metadata available',
      'source': 'Radio Browser',
    };
  }

  static Map<String, dynamic> _normalizeMarketStation(RadioMarketStation station) {
    return {
      'id': 'market:${station.callSign}',
      'name': station.name,
      'callSign': station.callSign,
      'country': 'United States',
      'countryCode': station.countryCode,
      'state': station.state,
      'city': station.city,
      'language': 'English',
      'tags': station.tags,
      'homepage': station.homepage,
      'listenUrl': station.homepage,
      'favicon': '',
      'streamUrl': '',
      'streamAvailable': false,
      'codec': '',
      'bitrate': null,
      'frequency': station.frequency,
      'band': station.band,
      'format': station.format,
      'nowPlaying': 'Official broadcaster listening page',
      'source': 'Broadcaster market catalog',
    };
  }

  static String _identityFor(Map<String, dynamic> station) {
    final callSign = station['callSign']?.toString().trim().toUpperCase() ?? '';
    if (callSign.isNotEmpty) return 'call:$callSign';
    final frequency = station['frequency']?.toString() ?? '';
    final name = station['name']?.toString().trim().toLowerCase() ?? '';
    return 'station:$frequency:$name';
  }

  static bool _matchesSearch(Map<String, dynamic> station, String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return [station['name'], station['callSign'], station['tags'], station['format']]
        .map((v) => v?.toString().toLowerCase() ?? '')
        .any((text) => text.contains(needle));
  }

  static bool _matchesTag(Map<String, dynamic> station, String query) {
    final needle = query.trim().toLowerCase();
    final haystack = [station['tags'], station['format']]
        .map((v) => v?.toString().toLowerCase() ?? '')
        .join(' ');
    return needle.isEmpty || haystack.contains(needle);
  }

  static String? _safeHttpUrl(Object? value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) return null;
    return uri.toString();
  }

  static String _inferBand(Map<String, dynamic> row, num? frequency) {
    final haystack = [row['name'], row['tags'], row['stationuuid']]
        .map((v) => v?.toString() ?? '')
        .join(' ')
        .toUpperCase();
    if (haystack.contains(' AM ') || haystack.startsWith('AM ') || haystack.contains(' AM-')) return 'AM';
    if (haystack.contains(' FM ') || haystack.startsWith('FM ') || haystack.contains(' FM-')) return 'FM';
    if (frequency != null) {
      if (frequency >= 150 && frequency <= 1710) return 'AM';
      if (frequency >= 87 && frequency <= 110) return 'FM';
    }
    return 'OTHER';
  }

  static num? _number(Object? value) =>
      value is num ? value : num.tryParse(value?.toString() ?? '');

  static String? _clean(String? value, int max) {
    final clean = value?.trim();
    if (clean == null || clean.isEmpty) return null;
    return clean.length > max ? clean.substring(0, max) : clean;
  }

  static int _parseLimit(String? raw) {
    final value = int.tryParse(raw ?? '') ?? 40;
    return value.clamp(1, 100);
  }

  static int mathMax(int a, int b) => a > b ? a : b;

  static Future<List<int>> _readLimited(HttpClientResponse response) async {
    final bytes = <int>[];
    await for (final chunk in response) {
      bytes.addAll(chunk);
      if (bytes.length > _maxResponseBytes) {
        throw const FormatException('Radio directory response is too large.');
      }
    }
    return bytes;
  }

  static Future<void> _json(HttpResponse response, int status, Object data) async {
    response.statusCode = status;
    response.headers.contentType = ContentType.json;
    response.headers.set('cache-control', 'no-store');
    response.write(jsonEncode(data));
    await response.close();
  }

  static void _applyCors(HttpResponse response) {
    response.headers.set('Access-Control-Allow-Origin', '*');
    response.headers.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
    response.headers.set('Access-Control-Allow-Headers', 'Origin, Content-Type, Accept, Authorization, X-Streaming-Proxy-Key');
  }
}
