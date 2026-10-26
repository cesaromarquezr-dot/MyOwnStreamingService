// FILE: `lib/backend_api.dart`.
// Purpose: Implements the backend api portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'privacy_preferences.dart';
import 'core/config/app_env.dart';
import 'core/services/self_driving_network_engine.dart';

part 'backend_api_parts/account.dart';
part 'backend_api_parts/library.dart';
part 'backend_api_parts/groups.dart';
part 'backend_api_parts/server.dart';
part 'backend_api_parts/commerce.dart';
part 'backend_api_parts/admin.dart';
part 'backend_api_parts/discovery.dart';
part 'backend_api_parts/social.dart';
part 'backend_api_parts/collaboration.dart';
part 'backend_api_parts/commerce_platform.dart';
part 'backend_api_parts/devices.dart';
part 'backend_api_parts/support.dart';

/// Implements the `BackendApiException` class for this feature or UI component.
class BackendApiException implements Exception {
  final String message;
  final int? statusCode;

  BackendApiException(
    this.message, {
    this.statusCode,
  });

  @override

  /// Performs `toString` for this feature. Update this documentation when its contract changes.
  String toString() {
    if (statusCode != null) {
      return 'BackendApiException ($statusCode): $message';
    }

    return 'BackendApiException: $message';
  }
}

/// Implements the `BackendApi` class for this feature or UI component.
class BackendApi {
  final String baseUrl;

  String? _token;
  SelfDrivingHttpClient get _networkClient =>
      SelfDrivingNetworkMonitor.instance.httpClient;

  /// Shared policy-controlled client for other app-owned HTTP integrations.
  /// Large media transfers may use a dedicated inner client while still
  /// reporting through the same monitor.
  static SelfDrivingHttpClient get sharedNetworkClient =>
      SelfDrivingNetworkMonitor.instance.httpClient;
  static const _tokenStorageKey = 'backend_session_token';
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  BackendApi({String? baseUrl}) : baseUrl = _resolveBaseUrl(baseUrl) {
    assertSecureEndpoint();
  }

  static String _resolveBaseUrl(String? supplied) {
    final explicit = supplied?.trim() ?? '';
    return explicit.isNotEmpty ? explicit : AppEnv.backendApiUrl;
  }

  String? get token => _token;

  /// Restores the authenticated session token from encrypted device storage.
  Future<bool> restoreToken() async {
    final stored = await _secureStorage.read(key: _tokenStorageKey);
    if (stored == null || stored.trim().isEmpty) {
      _token = null;
      return false;
    }
    _token = stored.trim();
    return true;
  }

  Uri get baseUri => Uri.parse(baseUrl);

  void assertSecureEndpoint() {
    final uri = baseUri;

    if (uri.scheme != 'https' &&
        uri.host != '127.0.0.1' &&
        uri.host != 'localhost') {
      throw BackendApiException(
        'Insecure HTTP backend endpoints are not allowed. '
        'Configure an HTTPS backend URL.',
      );
    }
  }

  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  /// Performs `setToken` for this feature. Update this documentation when its contract changes.
  Future<void> setToken(String token) async {
    _token = token;
    await _secureStorage.write(key: _tokenStorageKey, value: token);
  }

  /// Performs `clearToken` for this feature. Update this documentation when its contract changes.
  Future<void> clearToken() async {
    _token = null;
    await _secureStorage.delete(key: _tokenStorageKey);
  }

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (isAuthenticated) {
      headers['Authorization'] = 'Bearer $_token';
    }

    return headers;
  }

  // ==========================================================
  // INTERNAL HELPERS
  // ==========================================================

  /// Ensures an authenticated backend token is available.
  void _requireAuthentication() {
    if (!isAuthenticated) {
      throw BackendApiException(
        'You must be logged in before using this feature.',
      );
    }
  }

  /// Validates a successful HTTP response and decodes its JSON body.
  Future<Map<String, dynamic>> _requireSuccess(
    http.Response response,
    String fallbackError,
  ) async {
    final data = _decodeResponse(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendApiException(
        data['error']?.toString() ?? fallbackError,
        statusCode: response.statusCode,
      );
    }

    return data;
  }

  // ==========================================================
  // SECURITY
  // ==========================================================

  /// Verifies the authenticated user's security answer.
  Future<bool> verifySecurityAnswer(
    String answer,
  ) async {
    if (!isAuthenticated) {
      return false;
    }

    final response = await _networkClient.post(
      Uri.parse('$baseUrl/auth/verify-security'),
      headers: _headers,
      body: jsonEncode({
        'answer': answer,
      }),
    );

    final data = _decodeResponse(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendApiException(
        data['error']?.toString() ?? 'Unable to verify security answer.',
        statusCode: response.statusCode,
      );
    }

    return data['verified'] == true;
  }

  // ==========================================================
  // SECURITY BOT CONTROL CENTER
  // Keep these as BackendApi class methods so all consumers can call them
  // without relying on extension-import visibility.
  // ==========================================================

  Future<Map<String, dynamic>> getSecurityBotsStatus() async {
    _requireAuthentication();
    return _requireSuccess(
      await _networkClient.get(
        Uri.parse('$baseUrl/security-bots/status'),
        headers: _headers,
      ),
      'Unable to load the Security Bot Control Center.',
    );
  }

  Future<Map<String, dynamic>> runSecurityBotChecks() async {
    _requireAuthentication();
    return _requireSuccess(
      await _networkClient.post(
        Uri.parse('$baseUrl/security-bots/run'),
        headers: _headers,
      ),
      'Security diagnostics could not be completed.',
    );
  }

  Future<Map<String, dynamic>> getSecurityBotsAudit({int limit = 40}) async {
    _requireAuthentication();
    final bounded = limit.clamp(1, 100).toInt();
    return _requireSuccess(
      await _networkClient.get(
        Uri.parse('$baseUrl/security-bots/audit?limit=$bounded'),
        headers: _headers,
      ),
      'Unable to load the security bot audit history.',
    );
  }

  /// Performs a bounded health probe through the adaptive network client.
  /// The endpoint is intentionally public and returns no account-specific data.
  Future<Map<String, dynamic>> checkBackendHealth() async {
    final endpoint = Uri.parse(
      '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/health',
    );
    final response = await _networkClient.get(
      endpoint,
      headers: const {'Accept': 'application/json'},
    );
    return _requireSuccess(response, 'Backend health check failed.');
  }

  // ==========================================================
  // MUSIC CATALOG (Spotify + MusicBrainz + Cover Art Archive)
  // ==========================================================

  /// Returns provider setup status without exposing any credentials.
  Future<Map<String, dynamic>> getMusicCatalogStatus() async {
    _requireAuthentication();
    final response = await _networkClient.get(
      Uri.parse('$baseUrl/music-catalog/status'),
      headers: _headers,
    );
    return _requireSuccess(
      response,
      'Unable to check music catalog providers.',
    );
  }

  /// Searches external music metadata. Spotify credentials stay on the backend.
  Future<Map<String, dynamic>> searchMusicCatalog(
    String query, {
    String type = 'all',
    int limit = 10,
  }) async {
    _requireAuthentication();
    final endpoint = Uri.parse('$baseUrl/music-catalog/search').replace(
      queryParameters: <String, String>{
        'q': query.trim(),
        'type': type,
        'limit': '${limit.clamp(1, 10)}',
      },
    );
    final response = await _networkClient.get(endpoint, headers: _headers);
    return _requireSuccess(
      response,
      'Unable to search the music catalog.',
    );
  }

  /// Lists an artist's MusicBrainz release groups (album-level discography).
  Future<Map<String, dynamic>> getMusicDiscography(
    String artistMbid, {
    int limit = 100,
  }) async {
    _requireAuthentication();
    final endpoint = Uri.parse('$baseUrl/music-catalog/discography').replace(
      queryParameters: <String, String>{
        'mbid': artistMbid.trim(),
        'limit': '${limit.clamp(1, 100)}',
      },
    );
    final response = await _networkClient.get(endpoint, headers: _headers);
    return _requireSuccess(
      response,
      'Unable to load this artist discography.',
    );
  }

  /// Loads the Cover Art Archive listing for a MusicBrainz release or group.
  Future<Map<String, dynamic>> getMusicCoverArt(
    String mbid, {
    String entity = 'release-group',
  }) async {
    _requireAuthentication();
    final endpoint = Uri.parse('$baseUrl/music-catalog/cover-art').replace(
      queryParameters: <String, String>{
        'mbid': mbid.trim(),
        'entity': entity,
      },
    );
    final response = await _networkClient.get(endpoint, headers: _headers);
    return _requireSuccess(
      response,
      'Unable to load album artwork.',
    );
  }

  /// Loads the detailed Spotify artist profile and optional exact-match TMDB biography.
  Future<Map<String, dynamic>> getSpotifyArtist(String spotifyId) async {
    _requireAuthentication();
    final endpoint = Uri.parse('$baseUrl/music-catalog/artist').replace(
      queryParameters: <String, String>{'spotifyId': spotifyId.trim()},
    );
    return _requireSuccess(
      await _networkClient.get(endpoint, headers: _headers),
      'Unable to load the Spotify artist profile.',
    );
  }

  /// Loads a page of album/single releases for a Spotify artist.
  Future<Map<String, dynamic>> getSpotifyArtistAlbums(
    String spotifyId, {
    int limit = 10,
    int offset = 0,
  }) async {
    _requireAuthentication();
    final endpoint = Uri.parse('$baseUrl/music-catalog/artist-albums').replace(
      queryParameters: <String, String>{
        'spotifyId': spotifyId.trim(),
        'limit': '${limit.clamp(1, 10)}',
        'offset': '${offset.clamp(0, 10000)}',
      },
    );
    return _requireSuccess(
      await _networkClient.get(endpoint, headers: _headers),
      'Unable to load the artist discography.',
    );
  }

  /// Loads Spotify's regional new-release albums for a Home artwork shelf.
  Future<Map<String, dynamic>> getSpotifyFeaturedAlbums({
    int limit = 10,
    int offset = 0,
  }) async {
    _requireAuthentication();
    final endpoint = Uri.parse('$baseUrl/music-catalog/featured-albums').replace(
      queryParameters: <String, String>{
        'limit': '${limit.clamp(1, 20)}',
        'offset': '${offset.clamp(0, 1000)}',
      },
    );
    return _requireSuccess(
      await _networkClient.get(endpoint, headers: _headers),
      'Unable to load featured albums.',
    );
  }

  /// Loads album details, full supported track listing, and cover-art URLs from Spotify.
  Future<Map<String, dynamic>> getSpotifyAlbum(String spotifyId) async {
    _requireAuthentication();
    final endpoint = Uri.parse('$baseUrl/music-catalog/album').replace(
      queryParameters: <String, String>{'spotifyId': spotifyId.trim()},
    );
    return _requireSuccess(
      await _networkClient.get(endpoint, headers: _headers),
      'Unable to load the Spotify album and track list.',
    );
  }

  // ==========================================================
  // TMDB MEDIA METADATA (movies, TV, actors, crew and biographies)
  // ==========================================================

  /// Returns provider configuration status without exposing TMDB credentials.
  Future<Map<String, dynamic>> getMediaMetadataStatus() async {
    _requireAuthentication();
    final response = await _networkClient.get(
      Uri.parse('$baseUrl/media-metadata/status'),
      headers: _headers,
    );
    return _requireSuccess(response, 'Unable to check TMDB metadata configuration.');
  }

  /// Makes a bounded request through the authenticated backend's allow-listed
  /// TMDB proxy. TMDB keys/tokens are never sent from this Flutter client.
  Future<Map<String, dynamic>> getTmdbMetadata(
    String path, [
    Map<String, String> query = const <String, String>{},
  ]) async {
    _requireAuthentication();
    final normalizedPath = path.trim();
    if (normalizedPath.isEmpty || normalizedPath.length > 180) {
      throw BackendApiException('A valid TMDB resource path is required.');
    }
    final parameters = <String, String>{'path': normalizedPath, ...query};
    final endpoint = Uri.parse('$baseUrl/media-metadata/tmdb')
        .replace(queryParameters: parameters);
    final response = await _networkClient.get(endpoint, headers: _headers);
    return _requireSuccess(response, 'Unable to load TMDB metadata.');
  }

  /// Gets optional IMDb / Rotten Tomatoes / Metascore results from the backend.
  /// The OMDb key is only stored by the backend and is never sent by Flutter.
  Future<Map<String, dynamic>> getExternalMediaRatings(String imdbId) async {
    _requireAuthentication();
    final cleaned = imdbId.trim();
    if (!RegExp(r'^tt[0-9]{5,12}$').hasMatch(cleaned)) {
      throw BackendApiException('A valid IMDb title ID is required.');
    }
    final endpoint = Uri.parse('$baseUrl/media-metadata/omdb-ratings')
        .replace(queryParameters: <String, String>{'imdb_id': cleaned});
    final response = await _networkClient.get(endpoint, headers: _headers);
    return _requireSuccess(response, 'Unable to load external media ratings.');
  }

  // ==========================================================
  // RESPONSE DECODING
  // ==========================================================

  /// Decodes a backend HTTP response into a JSON map.
  Map<String, dynamic> _decodeResponse(
    http.Response response,
  ) {
    if (response.body.isEmpty) {
      return {};
    }

    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      return {
        'data': decoded,
      };
    } catch (_) {
      return {
        'error': response.body,
      };
    }
  }
}
