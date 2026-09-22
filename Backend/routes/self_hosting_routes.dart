// FILE: `Backend/routes/self_hosting_routes.dart`.
// Purpose: Exposes authenticated self-hosting status for administration and
// diagnostics. Access can be restricted to the configured VPN networks.
//
// Security model:
// - Authentication is required.
// - The configured private/VPN network restriction is required.
// - Infrastructure status is never returned to unauthenticated callers.
// - Responses are explicitly non-cacheable.
// - Secrets, credentials, proxy tokens, and session material are not exposed.

import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import '../config.dart';
import '../middleware/authentication.dart';
import '../self_hosting_security.dart';

class SelfHostingRoutes {
  final AuthenticationMiddleware authentication;
  final SelfHostingSecurity security;

  SelfHostingRoutes({
    required this.authentication,
    required this.security,
  });

  static const String _statusPath =
      '/api/v1/self-hosting/status';

  Future<void> handle(HttpRequest request) async {
    var responseStarted = false;

    try {
      _applyCors(request.response);

      // --------------------------------------------------------
      // CORS PREFLIGHT
      // --------------------------------------------------------

      if (request.method == 'OPTIONS') {
        responseStarted = true;
        request.response.statusCode = HttpStatus.noContent;
        await request.response.close();
        return;
      }

      // --------------------------------------------------------
      // ROUTE
      // --------------------------------------------------------

      if (request.uri.path != _statusPath) {
        responseStarted = true;

        await _json(
          request.response,
          HttpStatus.notFound,
          {
            'success': false,
            'error': 'Self-hosting route not found.',
          },
        );
        return;
      }

      // --------------------------------------------------------
      // METHOD
      // --------------------------------------------------------

      if (request.method != 'GET') {
        responseStarted = true;

        await _json(
          request.response,
          HttpStatus.methodNotAllowed,
          {
            'success': false,
            'error': 'Method not allowed.',
          },
        );
        return;
      }

      // --------------------------------------------------------
      // AUTHENTICATION
      // --------------------------------------------------------

      final account =
          authentication.authenticate(request);

      if (account == null) {
        responseStarted = true;

        await _json(
          request.response,
          HttpStatus.unauthorized,
          {
            'success': false,
            'error': 'Authentication required.',
          },
        );
        return;
      }

      // --------------------------------------------------------
      // PRIVATE/VPN NETWORK RESTRICTION
      // --------------------------------------------------------
      //
      // This check intentionally occurs before exposing any hosting
      // diagnostics. A caller who is authenticated but outside the
      // configured private network receives no infrastructure status.
      // --------------------------------------------------------

      if (!security.vpnAllowed(request)) {
        responseStarted = true;

        await _json(
          request.response,
          HttpStatus.forbidden,
          {
            'success': false,
            'error':
                'This endpoint requires the configured private/VPN network.',
          },
        );
        return;
      }

      // --------------------------------------------------------
      // STATUS
      // --------------------------------------------------------

      final publicUrl = AppConfig.publicUrl.trim();
      final ddnsHostname =
          AppConfig.ddnsHostname.trim();
      final ddnsProvider =
          AppConfig.ddnsProvider.trim();

      final payload = <String, dynamic>{
        'success': true,
        'accountId': account.id,

        'publicUrl': publicUrl,

        'ddns': {
          'hostname': ddnsHostname,
          'provider': ddnsProvider,
          'configured': ddnsHostname.isNotEmpty,
        },

        'reverseProxy': {
          'required': AppConfig.requireTrustedProxy,
          'trustedProxyCidrsConfigured':
              AppConfig.trustedProxyCidrs.isNotEmpty,
        },

        'vpn': {
          'configured':
              AppConfig.vpnCidrs.isNotEmpty,
          'requestAllowed':
              true,
        },

        'ports': {
          'publicHttps':
              AppConfig.publicHttpsPort,
          'internalBackend':
              AppConfig.internalBackendPort,
        },
      };

      responseStarted = true;

      await _json(
        request.response,
        HttpStatus.ok,
        payload,
      );
    } catch (error, stackTrace) {
      developer.log(
        'Self-hosting status request failed.',
        name: 'SelfHostingRoutes',
        error: error,
        stackTrace: stackTrace,
      );

      if (!responseStarted) {
        await _json(
          request.response,
          HttpStatus.internalServerError,
          {
            'success': false,
            'error':
                'Unable to retrieve self-hosting status.',
          },
        );
      }
    }
  }

  // ==========================================================
  // RESPONSE HEADERS
  // ==========================================================

  void _applyCors(HttpResponse response) {
    response.headers.set(
      'Access-Control-Allow-Origin',
      '*',
    );

    response.headers.set(
      'Access-Control-Allow-Methods',
      'GET, OPTIONS',
    );

    response.headers.set(
      'Access-Control-Allow-Headers',
      'Authorization, Content-Type',
    );

    response.headers.set(
      'Access-Control-Expose-Headers',
      'Content-Type',
    );

    response.headers.set(
      'Cache-Control',
      'no-store, no-cache, must-revalidate',
    );

    response.headers.set(
      'Pragma',
      'no-cache',
    );

    response.headers.set(
      'X-Content-Type-Options',
      'nosniff',
    );
  }

  // ==========================================================
  // JSON RESPONSE
  // ==========================================================

  Future<void> _json(
    HttpResponse response,
    int status,
    Map<String, dynamic> body,
  ) async {
    response.statusCode = status;
    response.headers.contentType = ContentType.json;

    response.write(
      jsonEncode(body),
    );

    await response.close();
  }
}