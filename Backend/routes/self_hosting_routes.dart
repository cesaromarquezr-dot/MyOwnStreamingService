// FILE: `Backend/routes/self_hosting_routes.dart`.
// Purpose: Exposes authenticated self-hosting status for administration and
// diagnostics. Access can be restricted to the configured VPN networks.

import 'dart:convert';
import 'dart:io';

import '../config.dart';
import '../middleware/authentication.dart';
import '../self_hosting_security.dart';

class SelfHostingRoutes {
  final AuthenticationMiddleware authentication;
  final SelfHostingSecurity security;

  SelfHostingRoutes({required this.authentication, required this.security});

  Future<void> handle(HttpRequest request) async {
    final account = authentication.authenticate(request);
    if (account == null) return _json(request, 401, {'success': false, 'error': 'Authentication required.'});
    if (!security.vpnAllowed(request)) return _json(request, 403, {'success': false, 'error': 'This endpoint requires the configured private/VPN network.'});
    if (request.method == 'GET' && request.uri.path == '/api/v1/self-hosting/status') {
      return _json(request, 200, {
        'success': true,
        'accountId': account.id,
        'publicUrl': AppConfig.publicUrl,
        'ddns': {'hostname': AppConfig.ddnsHostname, 'provider': AppConfig.ddnsProvider},
        'reverseProxy': {'required': AppConfig.requireTrustedProxy, 'trustedProxyCidrsConfigured': AppConfig.trustedProxyCidrs.isNotEmpty},
        'vpn': {'configured': AppConfig.vpnCidrs.isNotEmpty},
        'ports': {'publicHttps': AppConfig.publicHttpsPort, 'internalBackend': AppConfig.internalBackendPort},
      });
    }
    return _json(request, 404, {'success': false, 'error': 'Self-hosting route not found.'});
  }

  Future<void> _json(HttpRequest request, int status, Map<String, dynamic> body) async {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(body));
    await request.response.close();
  }
}
