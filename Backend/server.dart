import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'config.dart';
import 'database/database.dart';
import 'middleware/authentication.dart';

import 'routes/auth_routes.dart';
import 'routes/recommendations_routes.dart';
import 'routes/search_routes.dart';
import 'routes/payment_routes.dart';
import 'routes/arm_routes.dart';
import 'routes/group_routes.dart';

import 'services/auth_service.dart';
import 'services/recommendations_service.dart';
import 'services/search_service.dart';
import 'services/subscription_service.dart';
import 'services/payment_service.dart';
import 'services/group_recommendation_service.dart';

import 'arm/arm_client.dart';
import 'arm/arm_service.dart';

Future<void> main() async {
  final database = Database.instance;

  // ------------------------------------------------------------
  // SERVICES
  // ------------------------------------------------------------

  final subscriptionService = SubscriptionService();

  final authService = AuthService(
    database: database,
    subscriptionService: subscriptionService,
  );

  final recommendationsService =
      const RecommendationsService();

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

  final groupRecommendationService =
      GroupRecommendationService(
    database,
  );

  // ------------------------------------------------------------
  // AUTHENTICATION
  // ------------------------------------------------------------

  final authentication =
      AuthenticationMiddleware(
    authService: authService,
  );

  // ------------------------------------------------------------
  // AUTH ROUTES
  // ------------------------------------------------------------

  final authRoutes = AuthRoutes(
    authService: authService,
    authentication: authentication,
    paymentService: paymentService,
  );

  // ------------------------------------------------------------
  // RECOMMENDATION ROUTES
  // ------------------------------------------------------------

  final recommendationsRoutes =
      RecommendationsRoutes(
    authenticationMiddleware: authentication,
    recommendationsService:
        recommendationsService,
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
    recommendationService:
        groupRecommendationService,
  );

  // ------------------------------------------------------------
  // ARM CONNECTION
  // ------------------------------------------------------------

  //
  // IMPORTANT:
  // Replace this with the actual address of your ARM server.
  //
  final armClient = ArmClient(
    armServerUrl: 'http://YOUR-ARM-SERVER',
  );

  final armService = ArmService(
    client: armClient,
  );

  final armRoutes = ArmRoutes(
    armService: armService,
    authentication: authentication,
  );

  // ------------------------------------------------------------
  // START SERVER
  // ------------------------------------------------------------

  final server = await HttpServer.bind(
    AppConfig.host,
    AppConfig.port,
  );

  developer.log('');

  developer.log(
    '==========================================',
  );

  developer.log(
    ' Personal Streaming Service Backend',
  );

  developer.log(
    '==========================================',
  );

  developer.log('');

  developer.log(
    'Backend started successfully.',
  );

  developer.log(
    'Address: ${AppConfig.baseUrl}',
  );

  developer.log(
    'API:     ${AppConfig.apiBaseUrl}',
  );

  developer.log('');

  developer.log(
    'Health:  ${AppConfig.baseUrl}/api/v1/health',
  );

  developer.log(
    'ARM:     ${AppConfig.apiBaseUrl}/arm/',
  );

  developer.log(
    'Recommendations: '
    '${AppConfig.apiBaseUrl}/recommendations',
  );

  developer.log(
    'Search: '
    '${AppConfig.apiBaseUrl}/search',
  );

  developer.log(
    'Payments: '
    '${AppConfig.apiBaseUrl}/payment/',
  );

  developer.log(
    'Group: '
    '${AppConfig.apiBaseUrl}/group/',
  );

  developer.log('');

  developer.log(
    'Waiting for requests...',
  );

  developer.log('');

  await for (final request in server) {
    await _handleRequest(
      request,
      authRoutes,
      recommendationsRoutes,
      searchRoutes,
      paymentRoutes,
      groupRoutes,
      armRoutes,
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
) async {
  try {
    _addCorsHeaders(request.response);

    // ----------------------------------------------------------
    // CORS PREFLIGHT
    // ----------------------------------------------------------

    if (request.method == 'OPTIONS') {
      request.response.statusCode =
          HttpStatus.noContent;

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

    // ----------------------------------------------------------
    // RECOMMENDATION ROUTES
    // ----------------------------------------------------------

    if (path ==
        '/api/v1/recommendations') {
      await recommendationsRoutes.handle(
        request,
      );
      return;
    }

    // ----------------------------------------------------------
    // SMART SEARCH ROUTES
    // ----------------------------------------------------------

    if (path ==
        '/api/v1/search') {
      await searchRoutes.handle(
        request,
      );
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
      'service':
          'Personal Streaming Service',
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

  response.headers.contentType =
      ContentType.json;

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