// Domain API methods extracted from backend_api.dart.
part of '../backend_api.dart';

extension BackendApiCommerceMethods on BackendApi {
  // ==========================================================
  // SHOP
  // ==========================================================

  Future<Map<String, dynamic>> searchShopEntities(
    String query,
    int limit,
  ) async {
    _requireAuthentication();
    final uri = Uri.parse('$baseUrl/shop/entities').replace(
      queryParameters: {
        'q': query.trim(),
        'limit': limit.clamp(1, 100).toString(),
      },
    );
    return _requireSuccess(
      await http.get(uri, headers: _headers),
      'Unable to search shop entities.',
    );
  }

  Future<Map<String, dynamic>> syncShopEntities(
    List<Map<String, dynamic>> entities,
  ) async {
    _requireAuthentication();
    return _requireSuccess(
      await http.post(
        Uri.parse('$baseUrl/shop/entities/sync'),
        headers: _headers,
        body: jsonEncode({'entities': entities}),
      ),
      'Unable to synchronize shop entities.',
    );
  }


}
