import 'dart:convert';
import 'dart:io';

import 'config.dart';
import 'database/database.dart';
import 'middleware/authentication.dart';
import 'routes/auth_routes.dart';
import 'services/auth_service.dart';
import 'services/subscription_service.dart';

import 'arm/arm_client.dart';
import 'arm/arm_service.dart';
import 'routes/arm_routes.dart';

Future<void> main() async {
  final database = Database.instance;

  final subscriptionService = SubscriptionService();

  final authService = AuthService(
    database: database,
    subscriptionService: subscriptionService,
  );

  final authentication = AuthenticationMiddleware(
    authService: authService,
  );

  final authRoutes = AuthRoutes(
    authService: authService,
    authentication: authentication,
  );

  // ARM connection.
  //
  // IMPORTANT:
  // Replace this with the actual address of your ARM server.
  // Do not leave YOUR-ARM-SERVER here when you are ready
  // to actually connect to ARM.
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

  final server = await HttpServer.bind(
    AppConfig.host,
    AppConfig.port,
  );

  print('');
  print('==========================================');
  print(' Personal Streaming Service Backend');
  print('==========================================');
  print('');
  print('Backend started successfully.');
  print('Address: ${AppConfig.baseUrl}');
  print('API:     ${AppConfig.apiBaseUrl}');
  print('');
  print('Health:  ${AppConfig.baseUrl}/api/v1/health');
  print('ARM:     ${AppConfig.apiBaseUrl}/arm/');
  print('');
  print('Waiting for requests...');
  print('');

  await for (final request in server) {
    await _handleRequest(
      request,
      authRoutes,
      armRoutes,
    );
  }
}

Future<void> _handleRequest(
  HttpRequest request,
  AuthRoutes authRoutes,
  ArmRoutes armRoutes,
) async {
  try {
    _addCorsHeaders(request.response);

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }

    final path = request.uri.path;

    // Health check.
    if (request.method == 'GET' &&
        path == '/api/v1/health') {
      await _health(request);
      return;
    }

    // Authentication and profile routes.
    if (path.startsWith('/api/v1/auth/') ||
        path == '/api/v1/profiles' ||
        path.startsWith('/api/v1/profiles/')) {
      await authRoutes.handle(request);
      return;
    }

    // ARM routes.
    if (path.startsWith('/api/v1/arm/')) {
      await armRoutes.handle(request);
      return;
    }

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
    print('Request error: $error');

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