import 'dart:convert';

import 'package:http/http.dart' as http;

/// Authenticated Jellyfin server-side plugin management API.
///
/// These endpoints require a Jellyfin administrator/elevated account. Tokens
/// are supplied by the caller and are never written to disk by this service.
class JellyfinPluginAdminService {
  JellyfinPluginAdminService({
    required String baseUrl,
    required this.accessToken,
    required http.Client client,
  })  : baseUrl = _normalizeBaseUrl(baseUrl),
        _client = client;

  final String baseUrl;
  final String accessToken;
  final http.Client _client;

  static String _normalizeBaseUrl(String value) {
    var normalized = value.trim();
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  Map<String, String> get _headers => <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-Emby-Token': accessToken,
        'Authorization':
            'MediaBrowser Client="MyOwnStreamingService", Device="MyOwnStreamingService", DeviceId="moss-plugin-manager", Version="1.0.0", Token="$accessToken"',
      };

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('$baseUrl$path');
    return query == null || query.isEmpty
        ? uri
        : uri.replace(queryParameters: query);
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    final request = http.Request(method, _uri(path, query))
      ..headers.addAll(_headers);
    if (body != null) request.body = jsonEncode(body);

    final streamed = await _client
        .send(request)
        .timeout(const Duration(seconds: 35));
    final response = await http.Response.fromStream(streamed)
        .timeout(const Duration(seconds: 35));

    if (response.statusCode == 401) {
      throw const JellyfinPluginAdminException(
        'Jellyfin rejected this session. Sign in again with a server administrator account.',
      );
    }
    if (response.statusCode == 403) {
      throw const JellyfinPluginAdminException(
        'Administrator permission is required for plugin management. Sign in with a Jellyfin administrator account.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      var detail = response.body.trim();
      if (detail.isNotEmpty) {
        try {
          final decoded = jsonDecode(detail);
          if (decoded is Map) {
            detail = (decoded['Message'] ??
                    decoded['message'] ??
                    decoded['Title'] ??
                    decoded['title'] ??
                    detail)
                .toString();
          }
        } catch (_) {
          // Preserve non-JSON server error text as a useful diagnostic.
        }
      }
      if (detail.length > 240) detail = '${detail.substring(0, 240)}…';
      throw JellyfinPluginAdminException(
        'Jellyfin returned HTTP ${response.statusCode}${detail.isEmpty ? '.' : ': $detail'}',
      );
    }

    if (response.body.trim().isEmpty) return null;
    try {
      return jsonDecode(response.body);
    } on FormatException {
      return response.body;
    }
  }

  List<Map<String, dynamic>> _asMapList(dynamic raw, String key) {
    dynamic values = raw;
    if (raw is Map) {
      values = raw[key] ?? raw['Items'] ?? raw['items'] ?? raw['Packages'];
    }
    if (values is! List) return <Map<String, dynamic>>[];
    return values
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: true);
  }

  Future<List<Map<String, dynamic>>> getInstalledPlugins() async =>
      _asMapList(await _request('GET', '/Plugins'), 'Plugins');

  Future<List<Map<String, dynamic>>> getPackages() async =>
      _asMapList(await _request('GET', '/Packages'), 'Packages');

  Future<List<Map<String, dynamic>>> getRepositories() async =>
      _asMapList(await _request('GET', '/Repositories'), 'Repositories');

  Future<void> enablePlugin({
    required String pluginId,
    required String version,
  }) async {
    await _request(
      'POST',
      '/Plugins/${Uri.encodeComponent(pluginId)}/${Uri.encodeComponent(version)}/Enable',
    );
  }

  Future<void> disablePlugin({
    required String pluginId,
    required String version,
  }) async {
    await _request(
      'POST',
      '/Plugins/${Uri.encodeComponent(pluginId)}/${Uri.encodeComponent(version)}/Disable',
    );
  }

  Future<void> uninstallPlugin({
    required String pluginId,
    required String version,
  }) async {
    await _request(
      'DELETE',
      '/Plugins/${Uri.encodeComponent(pluginId)}/${Uri.encodeComponent(version)}',
    );
  }

  /// Starts a Jellyfin package installation from one of the server's enabled
  /// repositories. Jellyfin may still require a restart before it loads.
  Future<void> installPackage({
    required String name,
    String? assemblyGuid,
    String? version,
    String? repositoryUrl,
  }) async {
    final query = <String, String>{
      if (assemblyGuid != null && assemblyGuid.isNotEmpty)
        'assemblyGuid': assemblyGuid,
      if (version != null && version.isNotEmpty) 'version': version,
      if (repositoryUrl != null && repositoryUrl.isNotEmpty)
        'repositoryUrl': repositoryUrl,
    };
    await _request(
      'POST',
      '/Packages/Installed/${Uri.encodeComponent(name)}',
      query: query,
    );
  }

  /// Jellyfin replaces the repository list as a whole, so callers should pass
  /// the full list returned by [getRepositories] plus the intended changes.
  Future<void> setRepositories(
    List<Map<String, dynamic>> repositories,
  ) async {
    final payload = repositories.map((repository) {
      String? value(List<String> keys) {
        for (final key in keys) {
          final result = repository[key];
          if (result != null) return result.toString();
        }
        return null;
      }

      final enabled = repository['Enabled'] ?? repository['enabled'];
      return <String, dynamic>{
        'Name': value(const ['Name', 'name']) ?? 'Repository',
        'Url': value(const ['Url', 'URL', 'url']) ?? '',
        'Enabled': enabled is bool ? enabled : true,
      };
    }).toList();
    await _request('POST', '/Repositories', body: payload);
  }
}

class JellyfinPluginAdminException implements Exception {
  const JellyfinPluginAdminException(this.message);

  final String message;

  @override
  String toString() => message;
}
