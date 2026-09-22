// FILE: `Backend/routes/platform_routes.dart`.
// Purpose: Implements the platform routes portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.
//
// Security notes:
// - All platform endpoints require authentication.
// - Dashboard responses are account-scoped.
// - Responses are explicitly non-cacheable because the dashboard can contain
//   account/security state.
// - Capability information describes platform functionality and does not
//   expose secrets or authentication material.
// - PaymentService remains an injected dependency for compatibility with the
//   existing backend wiring; payment operations belong to PaymentRoutes.

import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import '../middleware/authentication.dart';
import '../services/payment_service.dart';

class PlatformRoutes {
  final AuthenticationMiddleware authentication;

  // Retained for compatibility with the existing dependency graph.
  // Payment operations are intentionally handled by PaymentRoutes.
  final PaymentService paymentService;

  PlatformRoutes({
    required this.authentication,
    required this.paymentService,
  });

  Future<void> handle(HttpRequest request) async {
    _applyCors(request);

    if (request.method == 'OPTIONS') {
      await _empty(request, HttpStatus.noContent);
      return;
    }

    try {
      final auth = authentication.authenticate(request);

      if (auth == null) {
        await _json(
          request,
          HttpStatus.unauthorized,
          {
            'success': false,
            'error': 'Authentication required.',
          },
        );
        return;
      }

      final path = request.uri.path;

      if (request.method == 'GET' &&
          path == '/api/v1/platform/capabilities') {
        await _capabilities(request);
        return;
      }

      if (request.method == 'GET' &&
          path == '/api/v1/platform/dashboard') {
        await _dashboard(request, auth);
        return;
      }

      await _json(
        request,
        HttpStatus.notFound,
        {
          'success': false,
          'error': 'Platform route not found.',
        },
      );
    } catch (error, stackTrace) {
      developer.log(
        'Platform route error.',
        name: 'PlatformRoutes',
        error: error,
        stackTrace: stackTrace,
      );

      if (!_responseHasStarted(request.response)) {
        await _json(
          request,
          HttpStatus.internalServerError,
          {
            'success': false,
            'error': 'Platform request failed.',
          },
        );
      }
    }
  }

  Future<void> _capabilities(
    HttpRequest request,
  ) async {
    await _json(
      request,
      HttpStatus.ok,
      {
        'success': true,
        'capabilities': {
          /*
           * Core discovery and intelligence.
           */
          'aiConcierge': true,
          'naturalLanguageSearch': true,
          'metadataEnrichment': true,
          'internationalAdaptationRecommendations': true,
          'crossFormatRecommendations': true,

          /*
           * Playback and media delivery.
           */
          'adaptiveStreaming': true,
          'multiVersionMedia': true,
          'concurrentTranscoding': true,
          'groupWatchCompatibility': true,

          /*
           * Library and synchronization.
           */
          'cloudSync': true,
          'libraryScanner': true,
          'singleSourceOfTruth': true,
          'universalStableIds': true,
          'profileLevelMediaAccess': true,

          /*
           * ARM / physical-media ingestion.
           */
          'armAutomaticDiscIngestion': true,
          'armMultiTitleDiscImport': true,
          'armArtworkDescriptionCastImport': true,
          'armLosslessFlacArchive': true,
          'armRepairRecovery': true,

          /*
           * Marketplace and merchandise.
           */
          'eligibleMerchandiseOnly': true,

          /*
           * Security and account features.
           *
           * "Ready" means the platform has the capability/foundation;
           * it does not mean that every account has the feature enabled.
           */
          'twoFactorReady': true,
          'familyControls': true,
          'remoteSessions': true,

          /*
           * Supported client platforms.
           */
          'crossPlatform': [
            'android',
            'ios',
            'windows',
            'macos',
            'linux',
            'web',
            'android_tv',
            'apple_tv',
            'fire_tv',
          ],
        },
      },
    );
  }

  Future<void> _dashboard(
    HttpRequest request,
    dynamic account,
  ) async {
    /*
     * Keep the dashboard intentionally small.
     *
     * The platform route should not duplicate sensitive account data already
     * owned by AccountRoutes/AuthRoutes.
     */

    await _json(
      request,
      HttpStatus.ok,
      {
        'success': true,
        'accountId': account.id,
        'cloudSync': true,
        'security': {
          /*
           * This endpoint does not currently have a dedicated security
           * service dependency from which to determine the account's live
           * MFA state. Do not falsely report that MFA is disabled.
           *
           * The client should use /api/v1/security/status for authoritative
           * security state.
           */
          'twoFactor': null,
          'securityStatusEndpoint':
              '/api/v1/security/status',
        },
        'server': {
          'status': 'online',
        },
      },
    );
  }

  void _applyCors(HttpRequest request) {
    final headers = request.response.headers;

    headers.set(
      'Access-Control-Allow-Origin',
      '*',
    );
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
    Map<String, dynamic> body,
  ) async {
    final response = request.response;

    if (_responseHasStarted(response)) {
      return;
    }

    response.statusCode = status;
    response.headers.contentType = ContentType.json;

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

    response.write(jsonEncode(body));
    await response.close();
  }

  Future<void> _empty(
    HttpRequest request,
    int status,
  ) async {
    final response = request.response;

    if (_responseHasStarted(response)) {
      return;
    }

    response.statusCode = status;
    response.headers.set(
      'Cache-Control',
      'no-store, no-cache, must-revalidate',
    );
    response.headers.set(
      'Pragma',
      'no-cache',
    );

    await response.close();
  }

  bool _responseHasStarted(
    HttpResponse response,
  ) {
    return response.headers.contentType != null ||
        response.statusCode != HttpStatus.ok;
  }
}