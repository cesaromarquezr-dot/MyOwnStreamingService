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
import 'routes/legal_routes.dart';
import 'routes/sports_routes.dart';
import 'routes/review_routes.dart';
import 'routes/home_server_routes.dart';
import 'routes/supabase_sync_routes.dart';

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
import 'services/home_server_service.dart';

import 'arm/arm_client.dart';
import 'arm/arm_service.dart';

Future<void> main() async {
  // ============================================================
  // SUPABASE / PERSISTENT DATABASE
  // ============================================================

  SupabaseStore.instance.initialize();

  print('Backend Supabase persistence initialized.');

  final database = Database.instance;

  await database.initializePersistent();

  // ============================================================
  // SERVICES
  // ============================================================

  final subscriptionService = SubscriptionService();

  final emailService = EmailService.fromEnvironment();

  final authService = AuthService(
    database: database,
    subscriptionService: subscriptionService,
    emailService: emailService,
  );

  final recommendationsService = const RecommendationsService();

  final searchService = SearchService(
    database: database,
  );

  final paymentService = PaymentService(
    database: database,
    subscriptionService: subscriptionService,
  );

  final groupRecommendationService = GroupRecommendationService(
    database,
  );

  final groupWatchService = GroupWatchService(
    database: database,
  );

  // ============================================================
  // AUTHENTICATION
  // ============================================================

  final authentication = AuthenticationMiddleware(
    authService: authService,
  );

  // ============================================================
  // AUTH ROUTES
  // ============================================================

  final authRoutes = AuthRoutes(
    authService: authService,
    authentication: authentication,
    paymentService: paymentService,
    emailService: emailService,
  );

  // ============================================================
  // RECOMMENDATION ROUTES
  // ============================================================

  final recommendationsRoutes = RecommendationsRoutes(
    authenticationMiddleware: authentication,
    recommendationsService: recommendationsService,
    database: database,
  );

  // ============================================================
  // SEARCH ROUTES
  // ============================================================

  final searchRoutes = SearchRoutes(
    authenticationMiddleware: authentication,
    searchService: searchService,
  );

  // ============================================================
  // PAYMENT ROUTES
  // ============================================================

  final paymentRoutes = PaymentRoutes(
    authenticationMiddleware: authentication,
    paymentService: paymentService,
    database: database,
  );

  // ============================================================
  // GROUP ROUTES
  // ============================================================

  final groupRoutes = GroupRoutes(
    database: database,
    authenticationMiddleware: authentication,
    recommendationService: groupRecommendationService,
    watchService: groupWatchService,
  );

  // ============================================================
  // ARM
  // ============================================================

  final armClient = ArmClient(
    armServerUrl: AppConfig.armServerUrl,
  );

  final armService = ArmService(
    client: armClient,
  );

  final armRoutes = ArmRoutes(
    armService: armService,
    authentication: authentication,
  );

  // ============================================================
  // REMOTE ACCESS
  // ============================================================

  final remoteAccessService = RemoteAccessService(database);

  final remoteAccessRoutes = RemoteAccessRoutes(
    authentication: authentication,
    service: remoteAccessService,
    email: emailService,
  );

  // ============================================================
  // STORAGE
  // ============================================================

  final storageRoutes = StorageRoutes(
    authentication: authentication,
    email: emailService,
  );

  // ============================================================
  // PLATFORM
  // ============================================================

  final platformRoutes = PlatformRoutes(
    authentication: authentication,
    paymentService: paymentService,
  );

  // ============================================================
  // LIBRARY
  // ============================================================

  final libraryRoutes = LibraryRoutes(
    authentication: authentication,
  );

  // ============================================================
  // LEGAL
  // ============================================================

  final legalRoutes = LegalRoutes(
    authentication: authentication,
  );

  // ============================================================
  // SPORTS
  // ============================================================

  final sportsRoutes = SportsRoutes(
    authentication: authentication,
    service: const SportsService(),
  );

  // ============================================================
  // REVIEWS
  // ============================================================

  final reviewRoutes = ReviewRoutes(
    authentication: authentication,
    service: ReviewService(database),
  );

  // ============================================================
  // HOME SERVER
  // ============================================================

  final homeServerRoutes = HomeServerRoutes(
    authentication: authentication,
    service: HomeServerService(),
  );

  // ============================================================
  // SUPABASE SYNC
  // ============================================================

  final supabaseSyncRoutes = SupabaseSyncRoutes(
    authentication: authentication,
  );

  // ============================================================
  // HTTPS SERVER CONFIGURATION
  // ============================================================

  print('');
  print('HTTPS startup: beginning HTTPS configuration...');

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

  print(
    'HTTPS startup: certificate path = '
    '$resolvedCertificatePath',
  );

  print(
    'HTTPS startup: private key path = '
    '$resolvedPrivateKeyPath',
  );

  // ============================================================
  // VERIFY CERTIFICATE
  // ============================================================

  print('HTTPS startup: checking certificate file...');

  final certificateFile = File(
    resolvedCertificatePath,
  );

  if (!certificateFile.existsSync()) {
    throw StateError(
      'Unable to find the HTTPS certificate.\n'
      'Expected: $resolvedCertificatePath',
    );
  }

  print('HTTPS startup: certificate file exists.');

  // ============================================================
  // VERIFY PRIVATE KEY
  // ============================================================

  print('HTTPS startup: checking private key file...');

  final privateKeyFile = File(
    resolvedPrivateKeyPath,
  );

  if (!privateKeyFile.existsSync()) {
    throw StateError(
      'Unable to find the HTTPS private key.\n'
      'Expected: $resolvedPrivateKeyPath',
    );
  }

  print('HTTPS startup: private key file exists.');

  // ============================================================
  // SECURITY CONTEXT
  // ============================================================

  print('HTTPS startup: creating SecurityContext...');

  final securityContext = SecurityContext();

  try {
    print('HTTPS startup: loading certificate...');

    securityContext.useCertificateChain(
      resolvedCertificatePath,
    );

    print('HTTPS startup: certificate loaded.');

    if (privateKeyPassword != null &&
        privateKeyPassword.isNotEmpty) {
      print(
        'HTTPS startup: loading private key with password...',
      );

      securityContext.usePrivateKey(
        resolvedPrivateKeyPath,
        password: privateKeyPassword,
      );
    } else {
      print('HTTPS startup: loading private key...');

      securityContext.usePrivateKey(
        resolvedPrivateKeyPath,
      );
    }

    print('HTTPS startup: private key loaded.');
  } on TlsException catch (error) {
    print('HTTPS startup: TLS ERROR: $error');

    throw StateError(
      'Unable to load the HTTPS certificate/private key: $error',
    );
  } on FileSystemException catch (error) {
    print('HTTPS startup: FILE ERROR: $error');

    throw StateError(
      'Unable to access the HTTPS certificate/private key: $error',
    );
  }

  // ============================================================
  // BIND HTTPS SERVER
  // ============================================================

  print(
    'HTTPS startup: binding '
    '${AppConfig.host}:${AppConfig.port}...',
  );

  final server = await HttpServer.bindSecure(
    AppConfig.host,
    AppConfig.port,
    securityContext,
  );

  print('HTTPS startup: bindSecure completed.');

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

  // ============================================================
  // REQUEST LOOP
  // ============================================================

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
      legalRoutes,
      reviewRoutes,
      homeServerRoutes,
      supabaseSyncRoutes,
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
  LegalRoutes legalRoutes,
  ReviewRoutes reviewRoutes,
  HomeServerRoutes homeServerRoutes,
  SupabaseSyncRoutes supabaseSyncRoutes,
) async {
  try {
    _addCorsHeaders(request.response);

    // ==========================================================
    // CORS PREFLIGHT
    // ==========================================================

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;

      await request.response.close();

      return;
    }

    final path = request.uri.path;

    // ==========================================================
    // HEALTH
    // ==========================================================

    if (request.method == 'GET' &&
        path == '/api/v1/health') {
      await _health(request);
      return;
    }

    // ==========================================================
    // AUTH
    // ==========================================================

    if (path.startsWith('/api/v1/auth/') ||
        path == '/api/v1/profiles' ||
        path.startsWith('/api/v1/profiles/')) {
      await authRoutes.handle(request);
      return;
    }

    // ==========================================================
    // RECOMMENDATIONS
    // ==========================================================

    if (path == '/api/v1/recommendations') {
      await recommendationsRoutes.handle(request);
      return;
    }

    // ==========================================================
    // SEARCH
    // ==========================================================

    if (path == '/api/v1/search') {
      await searchRoutes.handle(request);
      return;
    }

    // ==========================================================
    // PAYMENTS
    // ==========================================================

    if (path.startsWith('/api/v1/payment/')) {
      await paymentRoutes.handle(request);
      return;
    }

    // ==========================================================
    // GROUP
    // ==========================================================

    if (path.startsWith('/api/v1/group/')) {
      await groupRoutes.handle(request);
      return;
    }

    // ==========================================================
    // REMOTE ACCESS
    // ==========================================================

    if (path.startsWith('/api/v1/remote/')) {
      await remoteAccessRoutes.handle(request);
      return;
    }

    // ==========================================================
    // SUPABASE SYNC
    // ==========================================================

    if (path == '/api/v1/supabase/sync/account') {
      await supabaseSyncRoutes.handle(request);
      return;
    }

    // ==========================================================
    // STORAGE
    // ==========================================================

    if (path.startsWith('/api/v1/storage')) {
      await storageRoutes.handle(request);
      return;
    }

    // ==========================================================
    // PLATFORM
    // ==========================================================

    if (path.startsWith('/api/v1/platform/')) {
      await platformRoutes.handle(request);
      return;
    }

    // ==========================================================
    // LIBRARY
    // ==========================================================

    if (path.startsWith('/api/v1/library/')) {
      await libraryRoutes.handle(request);
      return;
    }

    // ==========================================================
    // LEGAL
    // ==========================================================

    if (path.startsWith('/api/v1/legal/')) {
      await legalRoutes.handle(request);
      return;
    }

    // ==========================================================
    // REVIEWS
    // ==========================================================

    if (path.startsWith('/api/v1/reviews')) {
      await reviewRoutes.handle(request);
      return;
    }

    // ==========================================================
    // HOME SERVER
    // ==========================================================

    if (path.startsWith('/api/v1/server/')) {
      await homeServerRoutes.handle(request);
      return;
    }

    // ==========================================================
    // SPORTS
    // ==========================================================

    if (path.startsWith('/api/v1/sports')) {
      await sportsRoutes.handle(request);
      return;
    }

    // ==========================================================
    // ARM
    // ==========================================================

    if (path.startsWith('/api/v1/arm/')) {
      await armRoutes.handle(request);
      return;
    }

    // ==========================================================
    // NOT FOUND
    // ==========================================================

    await _sendJson(
      request.response,
      HttpStatus.notFound,
      {
        'success': false,
        'error': 'Route not found.',
        'path': path,
      },
    );
  } catch (error, stackTrace) {
    developer.log(
      'Request error: $error',
      name: 'Server',
      error: error,
      stackTrace: stackTrace,
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
// HEALTH CHECK
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