// FILE: `Backend/server.dart`.
// Purpose: Implements the HTTP/HTTPS server portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.
//
// Deployment:
//
//   Internet
//      ↓
//   Cloudflare
//      ↓
//   Firewall
//      ↓
//   NGINX Proxy Manager
//      ↓
//   Dart backend
//
// TLS:
// - BACKEND_TLS_ENABLED=true: Dart terminates TLS.
// - BACKEND_TLS_ENABLED=false: NGINX Proxy Manager terminates public TLS
//   and forwards internal HTTP traffic to the Dart backend.
//
// Supported environment variables:
//     SERVER_HOST
//     SERVER_PUBLIC_URL
//     BACKEND_TLS_ENABLED
//     REQUIRE_TRUSTED_PROXY
//     PROXY_SHARED_SECRET
//     TRUSTED_PROXY_CIDRS
//     VPN_CIDRS
//     RATE_LIMIT_PER_MINUTE
//     ALLOWED_ORIGINS
//     TLS_CERTIFICATE_PATH
//     TLS_PRIVATE_KEY_PATH
//     TLS_PRIVATE_KEY_PASSWORD
//     ARM_MOCK
//     ARM_MOCK_VERIFY_FAIL
//     ARM_SERVER_URL
//     ARM_USERNAME
//     ARM_PASSWORD
//     FOOD_PAYMENT_MOCK (development only)
//
// Local development certificate fallback:
//     Backend/certs/127.0.0.1+2.pem
//     Backend/certs/127.0.0.1+2-key.pem
//
// The Flutter development client should connect to:
//     https://127.0.0.1:8080

import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'arm/arm_client.dart';
import 'arm/arm_service.dart';
import 'arm/mock_arm_service.dart';
import 'config.dart';
import 'database/database.dart';
import 'middleware/authentication.dart';
import 'routes/arm_routes.dart';
import 'routes/auth_routes.dart';
import 'routes/game_routes.dart';
import 'routes/food_delivery_routes.dart';
import 'routes/group_routes.dart';
import 'routes/home_server_routes.dart';
import 'routes/legal_routes.dart';
import 'routes/library_release_routes.dart';
import 'routes/library_routes.dart';
import 'routes/live_shopping_routes.dart';
import 'routes/location_routes.dart';
import 'routes/media_intelligence_routes.dart';
import 'routes/payment_routes.dart';
import 'routes/physical_item_routes.dart';
import 'routes/platform_routes.dart';
import 'routes/platform_server_routes.dart';
import 'routes/playback_routes.dart';
import 'routes/profile_governance_routes.dart';
import 'routes/radio_routes.dart';
import 'routes/rating_routes.dart';
import 'routes/recommendations_routes.dart';
import 'routes/remote_access_routes.dart';
import 'routes/review_routes.dart';
import 'routes/search_routes.dart';
import 'routes/self_hosting_routes.dart';
import 'routes/server_agent_routes.dart';
import 'routes/shop_routes.dart';
import 'routes/sports_routes.dart';
import 'routes/storage_routes.dart';
import 'routes/supabase_sync_routes.dart';
import 'routes/tv_channel_routes.dart';
import 'routes/tv_pairing_routes.dart';
import 'self_hosting_security.dart';
import 'services/auth_service.dart';
import 'services/email_service.dart';
import 'services/game_service.dart';
import 'services/food_delivery_service.dart';
import 'services/group_recommendation_service.dart';
import 'services/group_watch_service.dart';
import 'services/home_server_service.dart';
import 'services/library_release_service.dart';
import 'services/media_analyzer_service.dart';
import 'services/media_intelligence_service.dart';
import 'services/media_server_agent_service.dart';
import 'services/mock_payment_processor.dart';
import 'services/payment_method_service.dart';
import 'services/payment_provider_service.dart';
import 'services/payment_service.dart';
import 'services/platform_server_service.dart';
import 'services/profile_governance_service.dart';
import 'services/rating_service.dart';
import 'services/recommendations_service.dart';
import 'services/remote_access_service.dart';
import 'services/review_publication_service.dart';
import 'services/review_service.dart';
import 'services/search_service.dart';
import 'services/shop_service.dart';
import 'services/sports_service.dart';
import 'services/storage_manager_service.dart';
import 'services/subscription_service.dart';
import 'services/tv_channel_service.dart';
import 'services/tv_pairing_service.dart';
import 'services/transcode_cache_service.dart';
import 'services/transcoding_service.dart';
import 'supabase_store.dart';

PaymentProcessorVerifier? _createPaymentProcessorVerifier() {
  final mockEnabled =
      (Platform.environment['ARM_MOCK'] ?? '').trim().toLowerCase() == 'true';

  if (!mockEnabled) {
    developer.log(
      'Payment processor: real provider verifier not configured.',
      name: 'Payment',
    );
    return null;
  }

  developer.log(
    'Payment processor: MOCK verifier enabled for local development.',
    name: 'Payment',
  );

  return createMockPaymentProcessorVerifier();
}

Future<void> main() async {
  _validateStartupConfiguration();

  SupabaseStore.instance.initialize();

  final database = Database.instance;
  await database.initializePersistent();

  // ------------------------------------------------------------
  // CORE SERVICES
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

  final ratingService = RatingService();

  final shopService = ShopService(
    database: database,
  );

  final paymentMethodService = PaymentMethodService();

  final libraryReleaseService = LibraryReleaseService(
    database: database,
  );

  final paymentProviderService = PaymentProviderService();

  final foodDeliveryService = FoodDeliveryService(
    paymentMethods: paymentMethodService,
  );

  // ------------------------------------------------------------
  // PAYMENT SERVICE
  // ------------------------------------------------------------

  final paymentService = PaymentService(
    database: database,
    subscriptionService: subscriptionService,
    processorVerifier: _createPaymentProcessorVerifier(),
  );

  // ------------------------------------------------------------
  // GROUP SERVICES
  // ------------------------------------------------------------

  final groupRecommendationService = GroupRecommendationService(
    database,
  );

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
  // ACCOUNT / PROFILE SERVICES
  // ------------------------------------------------------------

  final profileGovernanceService = ProfileGovernanceService(
    database,
  );

  final mediaServerAgentService = MediaServerAgentService();

  final platformServerService = PlatformServerService(
    store: SupabaseStore.instance,
  );

  final gameService = GameService(
    store: SupabaseStore.instance,
  );

  final tvPairingService = TvPairingService();

  // ------------------------------------------------------------
  // PROFILE GOVERNANCE ROUTES
  // ------------------------------------------------------------

  final profileGovernanceRoutes = ProfileGovernanceRoutes(
    authentication: authentication,
    service: profileGovernanceService,
  );

  // ------------------------------------------------------------
  // SERVER AGENT ROUTES
  // ------------------------------------------------------------

  final serverAgentRoutes = ServerAgentRoutes(
    authentication: authentication,
    service: mediaServerAgentService,
  );

  // ------------------------------------------------------------
  // PLATFORM SERVER ROUTES
  // ------------------------------------------------------------

  final platformServerRoutes = PlatformServerRoutes(
    authentication: authentication,
    service: platformServerService,
  );

  // ------------------------------------------------------------
  // GAME ROUTES
  // ------------------------------------------------------------

  final gameRoutes = GameRoutes(
    authentication: authentication,
    service: gameService,
  );

  // ------------------------------------------------------------
  // TV PAIRING ROUTES
  // ------------------------------------------------------------

  final tvPairingRoutes = TvPairingRoutes(
    authentication: authentication,
    service: tvPairingService,
  );

  // ------------------------------------------------------------
  // TV CHANNEL ROUTES
  // ------------------------------------------------------------

  final tvChannelRoutes = TvChannelRoutes(
    authentication: authentication,
    service: TvChannelService(),
  );

  final foodDeliveryRoutes = FoodDeliveryRoutes(
    authentication: authentication,
    service: foodDeliveryService,
  );

  // ------------------------------------------------------------
  // AUTH ROUTES
  // ------------------------------------------------------------

  final authRoutes = AuthRoutes(
    authService: authService,
    authentication: authentication,
    paymentService: paymentService,
    emailService: emailService,
    profileGovernanceService: profileGovernanceService,
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
  // SHOP ROUTES
  // ------------------------------------------------------------

  final shopRoutes = ShopRoutes(
    authenticationMiddleware: authentication,
    shopService: shopService,
  );

  final libraryReleaseRoutes = LibraryReleaseRoutes(
    authentication: authentication,
    service: libraryReleaseService,
  );

  final ratingRoutes = RatingRoutes(
    authentication: authentication,
    service: ratingService,
  );

  final liveShoppingRoutes = LiveShoppingRoutes(
    authentication: authentication,
  );

  // ------------------------------------------------------------
  // PAYMENT ROUTES
  // ------------------------------------------------------------

  final paymentRoutes = PaymentRoutes(
    authenticationMiddleware: authentication,
    paymentService: paymentService,
    database: database,
    paymentMethods: paymentMethodService,
    providerService: paymentProviderService,
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

  // ------------------------------------------------------------
  // ARM CONNECTION
  // ------------------------------------------------------------

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

  _log(
    armMockEnabled
        ? 'ARM mode: MOCK (Phase 1)'
        : 'ARM mode: REAL',
  );

  final armRoutes = ArmRoutes(
    armService: armService,
    authentication: authentication,
  );

  // ------------------------------------------------------------
  // ADDITIONAL SERVICES / ROUTES
  // ------------------------------------------------------------

  final remoteAccessService = RemoteAccessService(
    database,
  );

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
    publicationService: ReviewPublicationService(),
  );

  final homeServerRoutes = HomeServerRoutes(
    authentication: authentication,
    service: HomeServerService(),
  );

  final supabaseSyncRoutes = SupabaseSyncRoutes(
    authentication: authentication,
  );

  final locationRoutes = LocationRoutes();

  final radioRoutes = RadioRoutes(
    authentication: authentication,
  );

  final selfHostingSecurity = SelfHostingSecurity();

  final selfHostingRoutes = SelfHostingRoutes(
    authentication: authentication,
    security: selfHostingSecurity,
  );

  final mediaIntelligenceRoutes = MediaIntelligenceRoutes(
    authentication: authentication,
    service: mediaIntelligenceService,
    store: SupabaseStore.instance,
  );

  final physicalItemRoutes = PhysicalItemRoutes(
    authentication: authentication,
    database: database,
    store: SupabaseStore.instance,
  );

  final remoteAccessRoutes = RemoteAccessRoutes(
    authentication: authentication,
    service: remoteAccessService,
    email: emailService,
  );

  // ------------------------------------------------------------
  // START HTTP / HTTPS SERVER
  // ------------------------------------------------------------

  final securityContext = await _buildSecurityContext();

  final server = await _bindServer(
    securityContext,
  );

  // ------------------------------------------------------------
  // STARTUP BANNER
  // ------------------------------------------------------------

  _printStartupBanner(
    server,
    armMockEnabled: armMockEnabled,
  );

  // ------------------------------------------------------------
  // REQUEST LOOP
  // ------------------------------------------------------------

  await for (final request in server) {
    _handleRequest(
      request,
      authRoutes,
      recommendationsRoutes,
      searchRoutes,
      ratingRoutes,
      shopRoutes,
      liveShoppingRoutes,
      paymentRoutes,
      groupRoutes,
      armRoutes,
      sportsRoutes,
      remoteAccessRoutes,
      storageRoutes,
      platformRoutes,
      libraryRoutes,
      libraryReleaseRoutes,
      playbackRoutes,
      legalRoutes,
      reviewRoutes,
      homeServerRoutes,
      supabaseSyncRoutes,
      mediaIntelligenceRoutes,
      locationRoutes,
      radioRoutes,
      selfHostingRoutes,
      selfHostingSecurity,
      physicalItemRoutes,
      profileGovernanceRoutes,
      serverAgentRoutes,
      platformServerRoutes,
      gameRoutes,
      foodDeliveryRoutes,
      tvPairingRoutes,
      tvChannelRoutes,
    ).catchError(
      (Object error, StackTrace stackTrace) {
        developer.log(
          'Unhandled request task error.',
          name: 'Server',
          error: error,
          stackTrace: stackTrace,
        );
      },
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
  RatingRoutes ratingRoutes,
  ShopRoutes shopRoutes,
  LiveShoppingRoutes liveShoppingRoutes,
  PaymentRoutes paymentRoutes,
  GroupRoutes groupRoutes,
  ArmRoutes armRoutes,
  SportsRoutes sportsRoutes,
  RemoteAccessRoutes remoteAccessRoutes,
  StorageRoutes storageRoutes,
  PlatformRoutes platformRoutes,
  LibraryRoutes libraryRoutes,
  LibraryReleaseRoutes libraryReleaseRoutes,
  PlaybackRoutes playbackRoutes,
  LegalRoutes legalRoutes,
  ReviewRoutes reviewRoutes,
  HomeServerRoutes homeServerRoutes,
  SupabaseSyncRoutes supabaseSyncRoutes,
  MediaIntelligenceRoutes mediaIntelligenceRoutes,
  LocationRoutes locationRoutes,
  RadioRoutes radioRoutes,
  SelfHostingRoutes selfHostingRoutes,
  SelfHostingSecurity selfHostingSecurity,
  PhysicalItemRoutes physicalItemRoutes,
  ProfileGovernanceRoutes profileGovernanceRoutes,
  ServerAgentRoutes serverAgentRoutes,
  PlatformServerRoutes platformServerRoutes,
  GameRoutes gameRoutes,
  FoodDeliveryRoutes foodDeliveryRoutes,
  TvPairingRoutes tvPairingRoutes,
  TvChannelRoutes tvChannelRoutes,
) async {
  var responseStarted = false;

  try {
    // ----------------------------------------------------------
    // REVERSE-PROXY TRUST
    // ----------------------------------------------------------

    if (!selfHostingSecurity.proxyRequirementSatisfied(request)) {
      responseStarted = true;

      await _sendJson(
        request.response,
        HttpStatus.forbidden,
        <String, dynamic>{
          'success': false,
          'error':
              'Direct backend access is disabled; use the configured reverse proxy.',
        },
      );

      return;
    }

    // ----------------------------------------------------------
    // CLIENT IDENTIFICATION / RATE LIMIT
    // ----------------------------------------------------------

    final clientIp = selfHostingSecurity.clientIp(request);

    if (!selfHostingSecurity.allowRate(clientIp)) {
      responseStarted = true;

      _addSecurityHeaders(
        request.response,
      );

      await _sendJson(
        request.response,
        HttpStatus.tooManyRequests,
        <String, dynamic>{
          'success': false,
          'error': 'Rate limit exceeded.',
        },
      );

      return;
    }

    // ----------------------------------------------------------
    // SECURITY HEADERS / CORS
    // ----------------------------------------------------------

    _addSecurityHeaders(
      request.response,
    );

    _addCorsHeaders(
      request,
    );

    // ----------------------------------------------------------
    // CORS PREFLIGHT
    // ----------------------------------------------------------

    if (request.method == 'OPTIONS') {
      responseStarted = true;

      request.response.statusCode = HttpStatus.noContent;

      request.response.headers.set(
        'Cache-Control',
        'no-store',
      );

      await request.response.close();

      return;
    }

    final path = request.uri.path;

    // ----------------------------------------------------------
    // HEALTH
    // ----------------------------------------------------------

    if (request.method == 'GET' &&
        path == '/api/v1/health') {
      await _health(
        request,
      );

      responseStarted = true;
      return;
    }

    // ----------------------------------------------------------
    // PROFILE GOVERNANCE
    // ----------------------------------------------------------

    if (path.startsWith('/api/v1/profile-governance/')) {
      await profileGovernanceRoutes.handle(
        request,
      );

      responseStarted = true;
      return;
    }

    // ----------------------------------------------------------
    // SERVER AGENT
    // ----------------------------------------------------------

    if (path.startsWith('/api/v1/server-agent/')) {
      await serverAgentRoutes.handle(
        request,
      );

      responseStarted = true;
      return;
    }

    // ----------------------------------------------------------
    // PLATFORM SERVERS
    // ----------------------------------------------------------

    if (path.startsWith('/api/v1/platform-servers/')) {
      await platformServerRoutes.handle(
        request,
      );

      responseStarted = true;
      return;
    }

    // ----------------------------------------------------------
    // GAMES
    // ----------------------------------------------------------

    if (path.startsWith('/api/v1/games/')) {
      await gameRoutes.handle(
        request,
      );

      responseStarted = true;
      return;
    }

    // ----------------------------------------------------------
    // TV CONTROL
    // ----------------------------------------------------------

    if (path.startsWith('/api/v1/tv-control/')) {
      await tvPairingRoutes.handle(
        request,
      );

      responseStarted = true;
      return;
    }

    // ----------------------------------------------------------
    // AUTH / PROFILES
    // ----------------------------------------------------------

    if (path.startsWith('/api/v1/auth/') ||
        path == '/api/v1/profiles' ||
        path.startsWith('/api/v1/profiles/')) {
      await authRoutes.handle(
        request,
      );

      responseStarted = true;
      return;
    }

    // ----------------------------------------------------------
    // TV CHANNELS
    // ----------------------------------------------------------

    if (path.startsWith('/api/v1/tv-channels/')) {
      await tvChannelRoutes.handle(
        request,
      );

      responseStarted = true;
      return;
    }

    // ----------------------------------------------------------
    // MEDIA INTELLIGENCE
    // ----------------------------------------------------------

    if (path.startsWith('/api/v1/media-intelligence/')) {
      await mediaIntelligenceRoutes.handle(
        request,
      );

      responseStarted = true;
      return;
    }

    // ----------------------------------------------------------
    // SELF-HOSTING
    // ----------------------------------------------------------

    if (path.startsWith('/api/v1/self-hosting/')) {
      await selfHostingRoutes.handle(
        request,
      );

      responseStarted = true;
      return;
    }

    // ----------------------------------------------------------
    // RADIO
    // ----------------------------------------------------------

    if (path == '/api/v1/radio/stations') {
      await radioRoutes.handle(
        request,
      );

      responseStarted = true;
      return;
    }

    // ----------------------------------------------------------
    // FOOD DELIVERY
    // ----------------------------------------------------------

    if (path.startsWith('/api/v1/food/')) {
      await foodDeliveryRoutes.handle(request);
      responseStarted = true;
      return;
    }

    // ----------------------------------------------------------
    // LOCATION
    // ----------------------------------------------------------

    if (path.startsWith('/api/v1/location/')) {
      await locationRoutes.handle(
        request,
      );

      responseStarted = true;
      return;
    }

    // ----------------------------------------------------------
    // RECOMMENDATIONS
    // ----------------------------------------------------------

    if (path == '/api/v1/recommendations') {
      await recommendationsRoutes.handle(
        request,
      );

      responseStarted = true;
      return;
    }

    // ----------------------------------------------------------
    // SEARCH
    // ----------------------------------------------------------

    if (path == '/api/v1/search') {
      await searchRoutes.handle(
        request,
      );

      responseStarted = true;
      return;
    }

    // ----------------------------------------------------------
    // RATINGS
    // ----------------------------------------------------------

    if (path == '/api/v1/ratings' ||
        path == '/api/v1/ratings/user') {
      await ratingRoutes.handle(
        request,
      );

      responseStarted = true;
      return;
    }

    // ----------------------------------------------------------
    // LIVE SHOPPING
    // ----------------------------------------------------------

    if (path.startsWith('/api/v1/shop/live-events')) {
      await liveShoppingRoutes.handle(
        request,
      );

      responseStarted = true;
      return;
    }

    // ----------------------------------------------------------
    // SHOP ENTITIES
    // ----------------------------------------------------------

    if (path == '/api/v1/shop/entities' ||
        path == '/api/v1/shop/entities/sync') {
      await shopRoutes.handle(
        request,
      );

      responseStarted = true;
      return;
    }

    // ----------------------------------------------------------
    // PAYMENTS
    // ----------------------------------------------------------

    if (path.startsWith('/api/v1/payment/') ||
        path == '/api/v1/seller/payout-destinations' ||
        path.startsWith('/api/v1/payment-methods')) {
      await paymentRoutes.handle(
        request,
      );

      responseStarted = true;
      return;
    }

    // ----------------------------------------------------------
    // GROUP
    // ----------------------------------------------------------

    if (path.startsWith('/api/v1/group/')) {
      await groupRoutes.handle(
        request,
      );

      responseStarted = true;
      return;
    }

    // ----------------------------------------------------------
    // REMOTE ACCESS
    // ----------------------------------------------------------

    if (path.startsWith('/api/v1/remote/')) {
      await remoteAccessRoutes.handle(
        request,
      );

      responseStarted = true;
      return;
    }

    // ----------------------------------------------------------
    // SUPABASE SYNC
    // ----------------------------------------------------------

    if (path == '/api/v1/supabase/sync/account' ||
        path.startsWith('/api/v1/supabase/sync/profile/') ||
        path == '/api/v1/features/status' ||
        path.startsWith('/api/v1/social/') ||
        path == '/api/v1/media-action' ||
        path == '/api/v1/activity' ||
        path == '/api/v1/records' ||
        path == '/api/v1/share-card' ||
        path == '/api/v1/queue' ||
        path.startsWith('/api/v1/queue/')) {
      await supabaseSyncRoutes.handle(
        request,
      );

      responseStarted = true;
      return;
    }

    // ----------------------------------------------------------
    // STORAGE
    // ----------------------------------------------------------

    if (path.startsWith('/api/v1/storage')) {
      await storageRoutes.handle(
        request,
      );

      responseStarted = true;
      return;
    }

    // ----------------------------------------------------------
    // PLATFORM
    // ----------------------------------------------------------

    if (path.startsWith('/api/v1/platform/')) {
      await platformRoutes.handle(
        request,
      );

      responseStarted = true;
      return;
    }

    // ----------------------------------------------------------
    // PLAYBACK
    // ----------------------------------------------------------

    if (path.startsWith('/api/v1/playback/')) {
      await playbackRoutes.handle(
        request,
      );

      responseStarted = true;
      return;
    }

    // ----------------------------------------------------------
    // LIBRARY RELEASES
    // ----------------------------------------------------------

    if (path.startsWith('/api/v1/library/releases')) {
      await libraryReleaseRoutes.handle(
        request,
      );

      responseStarted = true;
      return;
    }

    // ----------------------------------------------------------
    // LIBRARY
    // ----------------------------------------------------------

    if (path.startsWith('/api/v1/library/')) {
      await libraryRoutes.handle(
        request,
      );

      responseStarted = true;
      return;
    }

    // ----------------------------------------------------------
    // LEGAL
    // ----------------------------------------------------------

    if (path.startsWith('/api/v1/legal/')) {
      await legalRoutes.handle(
        request,
      );

      responseStarted = true;
      return;
    }

    // ----------------------------------------------------------
    // REVIEWS
    // ----------------------------------------------------------

    if (path.startsWith('/api/v1/reviews')) {
      await reviewRoutes.handle(
        request,
      );

      responseStarted = true;
      return;
    }

    // ----------------------------------------------------------
    // HOME SERVER
    // ----------------------------------------------------------

    if (path.startsWith('/api/v1/server/')) {
      await homeServerRoutes.handle(
        request,
      );

      responseStarted = true;
      return;
    }

    // ----------------------------------------------------------
    // SPORTS
    // ----------------------------------------------------------

    if (path.startsWith('/api/v1/sports')) {
      await sportsRoutes.handle(
        request,
      );

      responseStarted = true;
      return;
    }

    // ----------------------------------------------------------
    // PHYSICAL ITEMS
    // ----------------------------------------------------------

    if (path.startsWith('/api/v1/physical-items')) {
      await physicalItemRoutes.handle(
        request,
      );

      responseStarted = true;
      return;
    }

    // ----------------------------------------------------------
    // ARM
    // ----------------------------------------------------------

    if (path.startsWith('/api/v1/arm/')) {
      await armRoutes.handle(
        request,
      );

      responseStarted = true;
      return;
    }

    // ----------------------------------------------------------
    // ROUTE NOT FOUND
    // ----------------------------------------------------------

    responseStarted = true;

    await _sendJson(
      request.response,
      HttpStatus.notFound,
      <String, dynamic>{
        'success': false,
        'error': 'Route not found.',
        'path': path,
      },
    );
  } catch (error, stackTrace) {
    developer.log(
      'Request error.',
      name: 'Server',
      error: error,
      stackTrace: stackTrace,
    );

    if (responseStarted) {
      return;
    }

    try {
      responseStarted = true;

      await _sendJson(
        request.response,
        HttpStatus.internalServerError,
        <String, dynamic>{
          'success': false,
          'error': 'Internal server error.',
        },
      );
    } catch (sendError, sendStackTrace) {
      developer.log(
        'Unable to send request error response.',
        name: 'Server',
        error: sendError,
        stackTrace: sendStackTrace,
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
    <String, dynamic>{
      'success': true,
      'status': 'online',
      'service': 'Personal Streaming Service',
      'apiVersion': AppConfig.apiVersion,
    },
  );
}

// ============================================================
// SECURITY CONTEXT
// ============================================================

Future<SecurityContext?> _buildSecurityContext() async {
  if (!AppConfig.backendTlsEnabled) {
    return null;
  }

  final backendDirectory = Directory.current.path;

  final defaultCertificatePath =
      '$backendDirectory'
      '${Platform.pathSeparator}certs'
      '${Platform.pathSeparator}127.0.0.1+2.pem';

  final defaultPrivateKeyPath =
      '$backendDirectory'
      '${Platform.pathSeparator}certs'
      '${Platform.pathSeparator}127.0.0.1+2-key.pem';

  final configuredCertificate =
      Platform.environment['TLS_CERTIFICATE_PATH']?.trim();

  final configuredPrivateKey =
      Platform.environment['TLS_PRIVATE_KEY_PATH']?.trim();

  final certificatePath =
      configuredCertificate == null ||
          configuredCertificate.isEmpty
      ? defaultCertificatePath
      : configuredCertificate;

  final privateKeyPath =
      configuredPrivateKey == null ||
          configuredPrivateKey.isEmpty
      ? defaultPrivateKeyPath
      : configuredPrivateKey;

  final privateKeyPassword =
      Platform.environment['TLS_PRIVATE_KEY_PASSWORD'];

  final certificateFile = File(
    certificatePath,
  );

  final privateKeyFile = File(
    privateKeyPath,
  );

  if (!certificateFile.existsSync()) {
    throw StateError(
      'Unable to find the HTTPS certificate. '
      'Expected: $certificatePath',
    );
  }

  if (!privateKeyFile.existsSync()) {
    throw StateError(
      'Unable to find the HTTPS private key. '
      'Expected: $privateKeyPath',
    );
  }

  final context = SecurityContext();

  try {
    context.useCertificateChain(
      certificatePath,
    );

    if (privateKeyPassword != null &&
        privateKeyPassword.isNotEmpty) {
      context.usePrivateKey(
        privateKeyPath,
        password: privateKeyPassword,
      );
    } else {
      context.usePrivateKey(
        privateKeyPath,
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

  return context;
}

// ============================================================
// SERVER BINDING
// ============================================================

Future<HttpServer> _bindServer(
  SecurityContext? securityContext,
) async {
  if (AppConfig.backendTlsEnabled) {
    if (securityContext == null) {
      throw StateError(
        'TLS is enabled but no SecurityContext was created.',
      );
    }

    return HttpServer.bindSecure(
      AppConfig.host,
      AppConfig.port,
      securityContext,
    );
  }

  return HttpServer.bind(
    AppConfig.host,
    AppConfig.port,
  );
}

// ============================================================
// STARTUP VALIDATION
// ============================================================

void _validateStartupConfiguration() {
  final publicUrl = AppConfig.publicUrl;

  final parsedUrl = Uri.tryParse(
    publicUrl,
  );

  if (parsedUrl == null ||
      parsedUrl.scheme.isEmpty ||
      parsedUrl.host.isEmpty) {
    throw StateError(
      'SERVER_PUBLIC_URL is not a valid absolute URL: $publicUrl',
    );
  }

  if (AppConfig.backendTlsEnabled &&
      parsedUrl.scheme != 'https') {
    throw StateError(
      'BACKEND_TLS_ENABLED=true requires SERVER_PUBLIC_URL to use HTTPS.',
    );
  }

  if (AppConfig.requireTrustedProxy) {
    if (AppConfig.proxySharedSecret.isEmpty) {
      throw StateError(
        'REQUIRE_TRUSTED_PROXY=true requires PROXY_SHARED_SECRET.',
      );
    }

    if (AppConfig.trustedProxyCidrs.isEmpty) {
      throw StateError(
        'REQUIRE_TRUSTED_PROXY=true requires TRUSTED_PROXY_CIDRS.',
      );
    }
  }

  if (AppConfig.backendTlsEnabled &&
      AppConfig.port <= 0) {
    throw StateError(
      'The configured backend port is invalid.',
    );
  }
}

// ============================================================
// STARTUP LOGGING
// ============================================================

void _printStartupBanner(
  HttpServer server, {
  required bool armMockEnabled,
}) {
  _log('');
  _log('==========================================');
  _log(' Personal Streaming Service Backend');
  _log('==========================================');
  _log('');

  _log(
    AppConfig.backendTlsEnabled
        ? 'Backend started successfully with HTTPS.'
        : 'Backend started behind a reverse proxy using internal HTTP.',
  );

  _log(
    'Listen:  ${server.address.address}:${server.port}',
  );

  _log(
    'Public:  ${AppConfig.publicUrl}',
  );

  _log(
    'API:     ${AppConfig.apiBaseUrl}',
  );

  _log('');

  _log(
    'TLS termination: '
    '${AppConfig.backendTlsEnabled ? 'Dart backend' : 'NGINX Proxy Manager'}',
  );

  _log(
    'Trusted proxy: '
    '${AppConfig.requireTrustedProxy ? 'REQUIRED' : 'OPTIONAL'}',
  );

  _log(
    'Rate limit: '
    '${AppConfig.rateLimitPerMinute} requests/minute/IP',
  );

  _log(
    'ARM: '
    '${armMockEnabled ? 'MOCK (Phase 1)' : 'REAL'}',
  );

  _log('');

  _log(
    'Health:  ${AppConfig.apiBaseUrl}/health',
  );

  _log(
    'ARM:     ${AppConfig.apiBaseUrl}/arm/',
  );

  _log(
    'Recommendations: '
    '${AppConfig.apiBaseUrl}/recommendations',
  );

  _log(
    'Search: '
    '${AppConfig.apiBaseUrl}/search',
  );

  _log(
    'Payments: '
    '${AppConfig.apiBaseUrl}/payment/',
  );

  _log(
    'Group: '
    '${AppConfig.apiBaseUrl}/group/',
  );

  _log('');

  _log(
    AppConfig.backendTlsEnabled
        ? 'Waiting for HTTPS requests...'
        : 'Waiting for internal proxy requests...',
  );

  _log('');
}

void _log(
  String message,
) {
  developer.log(
    message,
    name: 'Server',
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
  if (response.headers.contentType == null) {
    response.headers.contentType = ContentType.json;
  }

  response.headers.set(
    'Cache-Control',
    'no-store, no-cache, must-revalidate',
  );

  response.headers.set(
    'Pragma',
    'no-cache',
  );

  response.statusCode = statusCode;

  response.write(
    jsonEncode(data),
  );

  await response.close();
}

// ============================================================
// SECURITY HEADERS
// ============================================================

void _addSecurityHeaders(
  HttpResponse response,
) {
  response.headers.set(
    'X-Content-Type-Options',
    'nosniff',
  );

  response.headers.set(
    'X-Frame-Options',
    'DENY',
  );

  response.headers.set(
    'Referrer-Policy',
    'no-referrer',
  );

  response.headers.set(
    'Permissions-Policy',
    'camera=(), microphone=(), geolocation=()',
  );

  response.headers.set(
    'Cache-Control',
    'no-store',
  );

  if (AppConfig.backendTlsEnabled ||
      AppConfig.publicUrl.toLowerCase().startsWith('https://')) {
    response.headers.set(
      'Strict-Transport-Security',
      'max-age=31536000; includeSubDomains',
    );
  }
}

// ============================================================
// CORS
// ============================================================

void _addCorsHeaders(
  HttpRequest request,
) {
  final origin = request.headers.value(
    'Origin',
  );

  final allowed = AppConfig.allowedOrigins;

  if (origin != null &&
      origin.isNotEmpty) {
    var originAllowed =
        allowed.contains('*') ||
        allowed.contains(origin);

    if (!originAllowed &&
        allowed.isNotEmpty) {
      try {
        final uri = Uri.parse(
          origin,
        );

        final isLocalHost =
            uri.scheme == 'http' &&
            (uri.host == 'localhost' ||
                uri.host == '127.0.0.1');

        if (isLocalHost) {
          originAllowed = allowed.any(
            (configured) {
              try {
                final configuredUri = Uri.parse(
                  configured,
                );

                return configuredUri.scheme ==
                        uri.scheme &&
                    configuredUri.host ==
                        uri.host;
              } catch (_) {
                return false;
              }
            },
          );
        }
      } catch (_) {
        originAllowed = false;
      }
    }

    if (originAllowed) {
      request.response.headers.set(
        'Access-Control-Allow-Origin',
        origin,
      );

      request.response.headers.set(
        'Vary',
        'Origin',
      );
    }
  }

  request.response.headers.set(
    'Access-Control-Allow-Methods',
    'GET, POST, PUT, PATCH, DELETE, OPTIONS',
  );

  request.response.headers.set(
    'Access-Control-Allow-Headers',
    'Origin, Content-Type, Accept, Authorization, X-Streaming-Proxy-Key',
  );

  request.response.headers.set(
    'Access-Control-Max-Age',
    '600',
  );
}