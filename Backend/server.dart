// FILE: `Backend/server.dart`.
// Purpose: Implements the HTTPS server portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.
//
// HTTPS:
// - The backend listens using TLS instead of plain HTTP.
// - Certificate and private-key paths may be supplied through environment
//   variables for custom/production deployments.
// - For local development, the backend automatically falls back to the
//   certificate files stored in Backend/certs/.
// - Optional:
//     TLS_PRIVATE_KEY_PASSWORD
//
// Supported environment variables:
//     TLS_CERTIFICATE_PATH
//     TLS_PRIVATE_KEY_PATH
//
// Local development fallback:
//     Backend/certs/127.0.0.1+2.pem
//     Backend/certs/127.0.0.1+2-key.pem
//
// Example PowerShell configuration for custom certificates:
//   $env:TLS_CERTIFICATE_PATH="C:\path\to\localhost.crt"
//   $env:TLS_PRIVATE_KEY_PATH="C:\path\to\localhost.key"
//   dart run server.dart
//
// The Flutter client should connect to:
//   https://127.0.0.1:8080

import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'config.dart';
import 'supabase_store.dart';
import 'database/database.dart';
import 'middleware/authentication.dart';

import 'routes/auth_routes.dart';
import 'routes/recommendations_routes.dart';
import 'routes/search_routes.dart';
import 'routes/payment_routes.dart';
import 'routes/arm_routes.dart';
import 'routes/group_routes.dart';
import 'routes/remote_access_routes.dart';
import 'routes/storage_routes.dart';
import 'routes/platform_routes.dart';
import 'routes/library_routes.dart';
import 'routes/playback_routes.dart';
import 'routes/legal_routes.dart';
import 'routes/sports_routes.dart';
import 'routes/review_routes.dart';
import 'routes/rating_routes.dart';
import 'routes/home_server_routes.dart';
import 'routes/supabase_sync_routes.dart';
import 'routes/media_intelligence_routes.dart';

import 'services/auth_service.dart';
import 'services/recommendations_service.dart';
import 'services/search_service.dart';
import 'services/subscription_service.dart';
import 'services/payment_service.dart';
import 'services/group_recommendation_service.dart';
import 'services/group_watch_service.dart';
import 'services/email_service.dart';
import 'services/remote_access_service.dart';
import 'services/sports_service.dart';
import 'services/review_service.dart';
import 'services/rating_service.dart';
import 'services/home_server_service.dart';
import 'services/media_intelligence_service.dart';
import 'services/media_analyzer_service.dart';
import 'services/transcode_cache_service.dart';
import 'services/transcoding_service.dart';
import 'services/storage_manager_service.dart';

import 'arm/arm_client.dart';
import 'arm/arm_service.dart';
import 'arm/mock_arm_service.dart';

Future<void> main() async {
  SupabaseStore.instance.initialize();

  final database = Database.instance;
  await database.initializePersistent();

  // ------------------------------------------------------------
  // SERVICES
  // ------------------------------------------------------------

  final subscriptionService = SubscriptionService();
  final emailService = EmailService.fromEnvironment();

  final authService = AuthService(
    database: database,
    subscriptionService: subscriptionService,
    emailService: emailService,
  );

  final recommendationsService = const RecommendationsService();
  final mediaIntelligenceService = MediaIntelligenceService();

  final searchService = SearchService(
    database: database,
  );

  // ------------------------------------------------------------
  // PAYMENT SERVICE
  // ------------------------------------------------------------

  final paymentService = PaymentService(
    database: database,
    subscriptionService: subscriptionService,
  );

  // ------------------------------------------------------------
  // GROUP RECOMMENDATION SERVICE
  // ------------------------------------------------------------

  final groupRecommendationService = GroupRecommendationService(
    database,
  );

  // ------------------------------------------------------------
  // GROUP WATCH SERVICE
  // ------------------------------------------------------------

  final groupWatchService = GroupWatchService(
    database: database,
  );

  // ------------------------------------------------------------
  // AUTHENTICATION
  // ------------------------------------------------------------

  final authentication = AuthenticationMiddleware(
    authService: authService,
  );

  // ------------------------------------------------------------
  // AUTH ROUTES
  // ------------------------------------------------------------

  final authRoutes = AuthRoutes(
    authService: authService,
    authentication: authentication,
    paymentService: paymentService,
    emailService: emailService,
  );

  // ------------------------------------------------------------
  // RECOMMENDATION ROUTES
  // ------------------------------------------------------------

  final recommendationsRoutes = RecommendationsRoutes(
    authenticationMiddleware: authentication,
    recommendationsService: recommendationsService,
    database: database,
  );

  // ------------------------------------------------------------
  // SEARCH ROUTES
  // ------------------------------------------------------------

  final searchRoutes = SearchRoutes(
    authenticationMiddleware: authentication,
    searchService: searchService,
  );

  // ------------------------------------------------------------
  // PAYMENT ROUTES
  // ------------------------------------------------------------

  final paymentRoutes = PaymentRoutes(
    authenticationMiddleware: authentication,
    paymentService: paymentService,
    database: database,
  );

  // ------------------------------------------------------------
  // GROUP ROUTES
  // ------------------------------------------------------------

  final groupRoutes = GroupRoutes(
    database: database,
    authenticationMiddleware: authentication,
    recommendationService: groupRecommendationService,
    watchService: groupWatchService,
  );

  // ---------------------------------------------------------------------------
// ARM SERVICE CONFIGURATION
// ---------------------------------------------------------------------------
//
// Phase 1 development can use the deterministic mock ARM service when
// ARM_MOCK=true is supplied to the backend process.
//
// IMPORTANT:
// - Mock mode is NEVER enabled automatically.
// - The production/default path remains the real authenticated ARM client.
// - ARM credentials are read from environment variables and are never sent
//   to Flutter.
// - This explicit switch helps prevent accidentally running mock mode in
//   production.
//
// Development:
//   $env:ARM_MOCK="true"
//   dart run server.dart
//
// Production / real ARM:
//   ARM_MOCK must be unset or set to false.
// ---------------------------------------------------------------------------

final armMockEnabled =
    (Platform.environment['ARM_MOCK'] ?? '').trim().toLowerCase() == 'true';

final armVerificationPasses =
    (Platform.environment['ARM_MOCK_VERIFY_FAIL'] ?? '')
            .trim()
            .toLowerCase() !=
        'true';

final armService = armMockEnabled
    ? MockArmService(
        verificationPasses: armVerificationPasses,
      )
    : ArmService(
        client: ArmClient(
          armServerUrl: AppConfig.armServerUrl,
          username: Platform.environment['ARM_USERNAME'],
          password: Platform.environment['ARM_PASSWORD'],
        ),
      );

// Make the selected ARM mode obvious in the backend console.
// This is intentionally a status message only; no credentials are printed.
print(
  armMockEnabled
      ? 'ARM mode: MOCK (Phase 1)'
      : 'ARM mode: REAL',
);

  final armRoutes = ArmRoutes(
    armService: armService,
    authentication: authentication,
  );

  // ------------------------------------------------------------
  // ADDITIONAL ROUTES
  // ------------------------------------------------------------

  final remoteAccessService = RemoteAccessService(database);

  final storageManagerService = const StorageManagerService();

  final storageRoutes = StorageRoutes(
    authentication: authentication,
    email: emailService,
    storageManager: storageManagerService,
  );

  final platformRoutes = PlatformRoutes(
    authentication: authentication,
    paymentService: paymentService,
  );

  final libraryRoutes = LibraryRoutes(
    authentication: authentication,
  );

  final transcodingService = TranscodingService(
    analyzer: const MediaAnalyzerService(),
    cache: TranscodeCacheService(),
  );
  final playbackRoutes = PlaybackRoutes(
    authentication: authentication,
    transcoding: transcodingService,
  );

  final legalRoutes = LegalRoutes(
    authentication: authentication,
  );

  final sportsRoutes = SportsRoutes(
    authentication: authentication,
    service: const SportsService(),
  );

  final reviewRoutes = ReviewRoutes(
    authentication: authentication,
    service: ReviewService(database),
  );

  final ratingRoutes = RatingRoutes(
    authentication: authentication,
    service: RatingService(database),
  );

  final homeServerRoutes = HomeServerRoutes(
    authentication: authentication,
    service: HomeServerService(),
  );

  final supabaseSyncRoutes = SupabaseSyncRoutes(
    authentication: authentication,
  );

  final mediaIntelligenceRoutes = MediaIntelligenceRoutes(
    authentication: authentication,
    service: mediaIntelligenceService,
  );

  final remoteAccessRoutes = RemoteAccessRoutes(
    authentication: authentication,
    service: remoteAccessService,
    email: emailService,
  );

  // ------------------------------------------------------------
  // START HTTPS SERVER
  // ------------------------------------------------------------

  // Environment variables remain supported for production/custom
  // certificate locations. For local development, automatically use
  // the certificate files stored in Backend/certs/.
  final defaultCertificatePath = Platform.script
      .resolve('certs/127.0.0.1+2.pem')
      .toFilePath();

  final defaultPrivateKeyPath = Platform.script
      .resolve('certs/127.0.0.1+2-key.pem')
      .toFilePath();

  final certificatePath =
      Platform.environment['TLS_CERTIFICATE_PATH']?.trim();

  final privateKeyPath =
      Platform.environment['TLS_PRIVATE_KEY_PATH']?.trim();

  final privateKeyPassword =
      Platform.environment['TLS_PRIVATE_KEY_PASSWORD'];

  final resolvedCertificatePath =
      certificatePath == null || certificatePath.isEmpty
          ? defaultCertificatePath
          : certificatePath;

  final resolvedPrivateKeyPath =
      privateKeyPath == null || privateKeyPath.isEmpty
          ? defaultPrivateKeyPath
          : privateKeyPath;

  final certificateFile =
      File(resolvedCertificatePath);

  final privateKeyFile =
      File(resolvedPrivateKeyPath);

  if (!certificateFile.existsSync()) {
    throw StateError(
      'Unable to find the HTTPS certificate.\n'
      'Expected: $resolvedCertificatePath',
    );
  }

  if (!privateKeyFile.existsSync()) {
    throw StateError(
      'Unable to find the HTTPS private key.\n'
      'Expected: $resolvedPrivateKeyPath',
    );
  }

  final securityContext = SecurityContext();

  try {
    securityContext.useCertificateChain(
      resolvedCertificatePath,
    );

    if (privateKeyPassword != null &&
        privateKeyPassword.isNotEmpty) {
      securityContext.usePrivateKey(
        resolvedPrivateKeyPath,
        password: privateKeyPassword,
      );
    } else {
      securityContext.usePrivateKey(
        resolvedPrivateKeyPath,
      );
    }
  } on TlsException catch (error) {
    throw StateError(
      'Unable to load the HTTPS certificate/private key: $error',
    );
  } on FileSystemException catch (error) {
    throw StateError(
      'Unable to access the HTTPS certificate/private key: $error',
    );
  }

  final server = await HttpServer.bindSecure(
    AppConfig.host,
    AppConfig.port,
    securityContext,
  );

  // ============================================================
  // STARTUP BANNER
  // ============================================================

  print('');
  print('==========================================');
  print(' Personal Streaming Service Backend');
  print('==========================================');
  print('');

  print('Backend started successfully with HTTPS.');
  print('Address: ${AppConfig.baseUrl}');
  print('API:     ${AppConfig.apiBaseUrl}');
  print('');

  print('TLS certificate: configured');
  print('TLS private key: configured');
  print('');

  print(
    'Health:  ${AppConfig.baseUrl}/api/v1/health',
  );

  print(
    'ARM:     ${AppConfig.apiBaseUrl}/arm/',
  );

  print(
    'Recommendations: '
    '${AppConfig.apiBaseUrl}/recommendations',
  );

  print(
    'Search: '
    '${AppConfig.apiBaseUrl}/search',
  );

  print(
    'Payments: '
    '${AppConfig.apiBaseUrl}/payment/',
  );

  print(
    'Group: '
    '${AppConfig.apiBaseUrl}/group/',
  );

  print('');

  print('Waiting for HTTPS requests...');
  print('');

  await for (final request in server) {
    await _handleRequest(
      request,
      authRoutes,
      recommendationsRoutes,
      searchRoutes,
      paymentRoutes,
      groupRoutes,
      armRoutes,
      sportsRoutes,
      remoteAccessRoutes,
      storageRoutes,
      platformRoutes,
      libraryRoutes,
      playbackRoutes,
      legalRoutes,
      reviewRoutes,
      ratingRoutes,
      homeServerRoutes,
      supabaseSyncRoutes,
      mediaIntelligenceRoutes,
    );
  }
}

// ============================================================
// REQUEST ROUTER
// ============================================================

Future<void> _handleRequest(
  HttpRequest request,
  AuthRoutes authRoutes,
  RecommendationsRoutes recommendationsRoutes,
  SearchRoutes searchRoutes,
  PaymentRoutes paymentRoutes,
  GroupRoutes groupRoutes,
  ArmRoutes armRoutes,
  SportsRoutes sportsRoutes,
  RemoteAccessRoutes remoteAccessRoutes,
  StorageRoutes storageRoutes,
  PlatformRoutes platformRoutes,
  LibraryRoutes libraryRoutes,
  PlaybackRoutes playbackRoutes,
  LegalRoutes legalRoutes,
  ReviewRoutes reviewRoutes,
  RatingRoutes ratingRoutes,
  HomeServerRoutes homeServerRoutes,
  SupabaseSyncRoutes supabaseSyncRoutes,
  MediaIntelligenceRoutes mediaIntelligenceRoutes,
) async {
  try {
    _addCorsHeaders(request.response);

    // ----------------------------------------------------------
    // CORS PREFLIGHT
    // ----------------------------------------------------------

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;

      await request.response.close();
      return;
    }

    final path = request.uri.path;

    // ----------------------------------------------------------
    // HEALTH CHECK
    // ----------------------------------------------------------

    if (request.method == 'GET' &&
        path == '/api/v1/health') {
      await _health(request);
      return;
    }

    // ----------------------------------------------------------
    // AUTHENTICATION AND PROFILE ROUTES
    // ----------------------------------------------------------

    if (path.startsWith('/api/v1/auth/') ||
        path == '/api/v1/profiles' ||
        path.startsWith('/api/v1/profiles/')) {
      await authRoutes.handle(request);
      return;
    }

    if (path.startsWith('/api/v1/media-intelligence/')) {
      await mediaIntelligenceRoutes.handle(request);
      return;
    }

    // ----------------------------------------------------------
    // RECOMMENDATION ROUTES
    // ----------------------------------------------------------

    if (path == '/api/v1/recommendations') {
      await recommendationsRoutes.handle(request);
      return;
    }

    // ----------------------------------------------------------
    // SMART SEARCH ROUTES
    // ----------------------------------------------------------

    if (path == '/api/v1/search') {
      await searchRoutes.handle(request);
      return;
    }

    // ----------------------------------------------------------
    // PAYMENT ROUTES
    // ----------------------------------------------------------

    if (path.startsWith('/api/v1/payment/')) {
      await paymentRoutes.handle(request);
      return;
    }

    // ----------------------------------------------------------
    // GROUP ROUTES
    // ----------------------------------------------------------

    if (path.startsWith('/api/v1/group/')) {
      await groupRoutes.handle(request);
      return;
    }

    // ----------------------------------------------------------
    // REMOTE ACCESS ROUTES
    // ----------------------------------------------------------

    if (path.startsWith('/api/v1/remote/')) {
      await remoteAccessRoutes.handle(request);
      return;
    }

    // ----------------------------------------------------------
    // SUPABASE SYNC
    // ----------------------------------------------------------

    if (path == '/api/v1/supabase/sync/account') {
      await supabaseSyncRoutes.handle(request);
      return;
    }

    // ----------------------------------------------------------
    // STORAGE ROUTES
    // ----------------------------------------------------------

    if (path.startsWith('/api/v1/storage')) {
      await storageRoutes.handle(request);
      return;
    }

    // ----------------------------------------------------------
    // PLATFORM ROUTES
    // ----------------------------------------------------------

    if (path.startsWith('/api/v1/platform/')) {
      await platformRoutes.handle(request);
      return;
    }

    // ----------------------------------------------------------
    // PLAYBACK ROUTES
    // ----------------------------------------------------------

    if (path.startsWith('/api/v1/playback/')) {
      await playbackRoutes.handle(request);
      return;
    }

    // ----------------------------------------------------------
    // LIBRARY ROUTES
    // ----------------------------------------------------------

    if (path.startsWith('/api/v1/library/')) {
      await libraryRoutes.handle(request);
      return;
    }

    // ----------------------------------------------------------
    // LEGAL ROUTES
    // ----------------------------------------------------------

    if (path.startsWith('/api/v1/legal/')) {
      await legalRoutes.handle(request);
      return;
    }

    // ----------------------------------------------------------
    // REVIEW ROUTES
    // ----------------------------------------------------------

    if (path.startsWith('/api/v1/reviews')) {
      await reviewRoutes.handle(request);
      return;
    }

    if (path.startsWith('/api/v1/ratings')) {
      await ratingRoutes.handle(request);
      return;
    }

    // ----------------------------------------------------------
    // HOME SERVER ROUTES
    // ----------------------------------------------------------

    if (path.startsWith('/api/v1/server/')) {
      await homeServerRoutes.handle(request);
      return;
    }

    // ----------------------------------------------------------
    // SPORTS ROUTES
    // ----------------------------------------------------------

    if (path.startsWith('/api/v1/sports')) {
      await sportsRoutes.handle(request);
      return;
    }

    // ----------------------------------------------------------
    // ARM ROUTES
    // ----------------------------------------------------------

    if (path.startsWith('/api/v1/arm/')) {
      await armRoutes.handle(request);
      return;
    }

    // ----------------------------------------------------------
    // ROUTE NOT FOUND
    // ----------------------------------------------------------

    await _sendJson(
      request.response,
      HttpStatus.notFound,
      {
        'success': false,
        'error': 'Route not found.',
        'path': path,
      },
    );
  } catch (error) {
    developer.log(
      'Request error: $error',
      name: 'Server',
    );

    if (!request.response.headers.contentType
        .toString()
        .contains('json')) {
      await _sendJson(
        request.response,
        HttpStatus.internalServerError,
        {
          'success': false,
          'error': 'Internal server error.',
        },
      );
    }
  }
}

// ============================================================
// HEALTH
// ============================================================

Future<void> _health(
  HttpRequest request,
) async {
  await _sendJson(
    request.response,
    HttpStatus.ok,
    {
      'success': true,
      'status': 'online',
      'service': 'Personal Streaming Service',
      'apiVersion': 'v1',
    },
  );
}

// ============================================================
// JSON RESPONSE
// ============================================================

Future<void> _sendJson(
  HttpResponse response,
  int statusCode,
  Map<String, dynamic> data,
) async {
  response.statusCode = statusCode;

  response.headers.contentType = ContentType.json;

  response.write(
    jsonEncode(data),
  );

  await response.close();
}

// ============================================================
// CORS
// ============================================================

void _addCorsHeaders(
  HttpResponse response,
) {
  response.headers.set(
    'Access-Control-Allow-Origin',
    '*',
  );

  response.headers.set(
    'Access-Control-Allow-Methods',
    'GET, POST, DELETE, OPTIONS',
  );

  response.headers.set(
    'Access-Control-Allow-Headers',
    'Origin, Content-Type, Accept, Authorization',
  );
}