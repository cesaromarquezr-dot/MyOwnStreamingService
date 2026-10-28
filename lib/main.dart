// FILE: `lib/main.dart`.
// Purpose: Implements the main portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_core.dart';
import 'cinematic_title_fonts.dart';
import 'backend_api.dart';
import 'core/services/self_driving_network_engine.dart';
import 'library_release.dart';
import 'physical_media_library.dart';
import 'media_health_screen.dart';
import 'signup.dart';
import 'smart_search.dart';
import 'details.dart';
import 'player.dart';
import 'seasonal_collections.dart';
import 'profiles.dart';
import 'account_settings.dart';
import 'device_features.dart';
import 'how_it_works.dart';
import 'shop.dart';
import 'watch_and_enjoy.dart';
import 'hey_marathon.dart';
import 'music.dart';
import 'home_server.dart';
import 'home_widgets.dart';
import 'home_streaming_discovery.dart';
import 'weekly_top10.dart';
import 'home_cinematic_recommendations.dart';
import 'cinematic_discovery_studio.dart';
import 'channel_center.dart';
import 'home_arrow_rail.dart';
import 'page_hero_banner.dart';
import 'country_origin_style.dart';
import 'recommendation_ownership.dart';
import 'catalog_poster_image.dart';
import 'music_catalog_screen.dart';
import 'home_franchise_progress.dart';
import 'playback_diagnostics_center.dart';
import 'platform_reliability_center.dart';
import 'movies.dart';
import 'series.dart';
import 'release_order_timeline.dart';
import 'innovation_features.dart';
import 'supabase/supabase_service.dart';
import 'responsive.dart';
import 'localization.dart';
import 'media_text_localizer.dart';
import 'activity_timeline.dart';
import 'social_home.dart';
import 'streaming_experience.dart';
import 'perfect_streaming_experience.dart';
import 'app_accessibility.dart';
import 'accessibility_offline_settings.dart';
import 'production_readiness.dart';
import 'security_settings.dart';
import 'navigation_hubs.dart';
import 'media_universe.dart';
import 'my_tv.dart';
import 'public_live_tv.dart';
import 'marketplace_hub.dart';
import 'social_story_experience.dart';
import 'app_customization.dart';
import 'entertainment_studio.dart';
import 'page_customization_button.dart';
import 'social_theme_gallery.dart';
import 'server_selection.dart';
import 'tv_controller.dart';
import 'tv_host.dart';
import 'entertainment_extensions.dart';
import 'innovation_hub.dart';
import 'streaming_upgrade_center.dart';
import 'jellyfin_plugins_hub.dart';
import 'core/services/automatic_backup_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env', isOptional: true);
  } catch (error) {
    // Configuration is optional. Do not log environment values or credentials.
    debugPrint('Optional .env configuration could not be loaded: $error');
  }
  // These boot steps are independent after .env is loaded. Run them together
  // instead of paying the sum of every SharedPreferences/SDK initialization.
  // The first frame is still gated on settings required to render the app, but
  // non-critical backup work is intentionally moved off the startup path.
  await Future.wait<void>(<Future<void>>[
    SelfDrivingNetworkMonitor.instance.initialize(),
    SupabaseService.instance.initialize(),
    HomeCustomizationStore.initialize(),
    PageContentCustomizationStore.initialize(),
    AppSectionCustomizationStore.initialize(),
    DetailsCustomizationStore.initialize(),
    MusicPageCustomizationStore.initialize(),
    AppController.instance.initializeBadges(),
    PlatformPreferenceStore.initialize(),
    ShopCatalog.instance.initialize(),
    StoryPlacementStore.load(AppController.instance.currentProfile),
  ]);

  runApp(const MyStreamingService());

  // Startup snapshots serialize and checksum many preferences and read the
  // result back from disk. Do that after the UI has painted, not before runApp.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // Let the first interaction settle before checksum/JSON backup work uses
    // the UI isolate and local disk.
    Timer(const Duration(seconds: 3), () {
      unawaited(AutomaticBackupService.instance.initialize());
    });
  });
}

final _AppPageState _appPageState = _AppPageState();
final _AppPageRouteObserver _appPageRouteObserver = _AppPageRouteObserver();

int? _primaryIndexForPage(String pageId) => switch (pageId) {
      'home' => 0,
      'library' ||
      'movies' ||
      'series' ||
      'music' ||
      'people' ||
      'actors' ||
      'artists' ||
      'bands' =>
        1,
      'shop' => 3,
      'friends' => 2,
      _ => null,
    };

class _AppPageState extends ChangeNotifier {
  String pageId = 'boot';
  int primaryIndex = 0;
  bool isCustomizing = false;

  void setPage(
    String value, {
    int? selectedPrimaryIndex,
    bool? customizing,
  }) {
    final nextPrimaryIndex = selectedPrimaryIndex ?? primaryIndex;
    final nextCustomizing = customizing ?? isCustomizing;
    if (pageId == value &&
        primaryIndex == nextPrimaryIndex &&
        isCustomizing == nextCustomizing) {
      return;
    }
    pageId = value;
    primaryIndex = nextPrimaryIndex;
    isCustomizing = nextCustomizing;
    notifyListeners();
  }

  void refresh() => notifyListeners();
}

class _AppPageRouteObserver extends NavigatorObserver {
  final Map<Route<dynamic>, String> _pageIds = <Route<dynamic>, String>{};
  Route<dynamic>? _topRoute;
  int _pendingPageUpdate = 0;

  void _schedulePageUpdate(
    String pageId, {
    int? selectedPrimaryIndex,
    required bool customizing,
  }) {
    // The onboarding routes must update the shell state immediately.
    // Otherwise a previously selected profile can leave the main navbar
    // visible for a frame (or longer if another route update supersedes the
    // pending callback).
    if (pageId == 'server-selection' || pageId == 'profiles') {
      _pendingPageUpdate++;
      _appPageState.setPage(
        pageId,
        selectedPrimaryIndex: selectedPrimaryIndex,
        customizing: customizing,
      );
      return;
    }

    final updateId = ++_pendingPageUpdate;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (updateId != _pendingPageUpdate) return;
      _appPageState.setPage(
        pageId,
        selectedPrimaryIndex: selectedPrimaryIndex,
        customizing: customizing,
      );
    });
  }

  bool _isUnnamedPopup(Route<dynamic> route) {
    final name = route.settings.name;
    return (name == null || name.isEmpty) && route is PopupRoute<dynamic>;
  }

  String _pageIdForRoute(String? name, Route<dynamic> route) {
    // Dialogs and modal sheets are unnamed PopupRoutes by default. They are
    // overlays on the current screen, not new page destinations. Keeping the
    // current page identity prevents the Customize tooltip from targeting a
    // phantom/previous page and prevents onboarding overlays from revealing
    // the global navbar while the server name dialog is open.
    if (_isUnnamedPopup(route)) {
      return _appPageState.pageId;
    }
    if (name == '/app/player') return 'player';
    if (name != null && name.startsWith('/app/page/')) {
      return name.substring('/app/page/'.length);
    }
    if (name == '/app/shop') return 'shop';
    if (name == '/app/page/food-delivery') return 'food-delivery';
    if (name == '/app/details') return 'details';
    if (name == '/app/customize' || name == '/app/more') {
      return _appPageState.pageId;
    }
    if (name == '/app/profiles') return 'profiles';
    if (name == '/app/server-selection') return 'server-selection';
    if (name != null && name.startsWith('/main/')) {
      final destination = name.substring('/main/'.length);
      if (destination == 'home' ||
          destination == 'library' ||
          destination == 'friends') {
        return destination;
      }
    }
    if (name == '/main') return 'home';
    return 'page_${identityHashCode(route)}';
  }

  void setPageForRoute(Route<dynamic>? route, String pageId, int primaryIndex) {
    // Invalidate any queued route-observer callbacks from routes that were
    // removed during an onboarding handoff. Otherwise a stale profile/server
    // route can overwrite the newly rendered MainScreen state after this frame.
    if (route != null) _pageIds[route] = pageId;
    // A still-mounted page behind a pushed route (notably MainScreen behind
    // ProfileSelectionScreen) can rebuild after the push. Only the top route
    // is allowed to publish the visible page ID, or the global navbar can
    // flash back on over profile selection.
    if (route != null && _topRoute != null && route != _topRoute) return;
    _pendingPageUpdate++;
    _appPageState.setPage(
      pageId,
      selectedPrimaryIndex: primaryIndex,
      customizing: false,
    );
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _topRoute = route;
    final name = route.settings.name;
    final pageId = _pageIdForRoute(name, route);
    _pageIds[route] = pageId;
    _schedulePageUpdate(
      pageId,
      selectedPrimaryIndex: _primaryIndexForPage(pageId),
      customizing: _isUnnamedPopup(route)
          ? _appPageState.isCustomizing
          : name == '/app/customize' || name == '/app/more',
    );
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _pageIds.remove(route);
    if (_topRoute == route) _topRoute = previousRoute;
    if (previousRoute != null) {
      final previousPageId = _pageIds[previousRoute] ?? 'home';
      _schedulePageUpdate(
        previousPageId,
        selectedPrimaryIndex: _primaryIndexForPage(previousPageId),
        customizing: _isUnnamedPopup(previousRoute)
            ? _appPageState.isCustomizing
            : previousRoute.settings.name == '/app/customize' ||
                previousRoute.settings.name == '/app/more',
      );
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    if (_topRoute == route) _topRoute = previousRoute;
    // didRemove commonly fires for background routes discarded by
    // pushAndRemoveUntil. Those routes are not the visible page, so never let
    // their previousRoute overwrite the active page (especially during the
    // server -> profile -> Home onboarding handoff).
    _pageIds.remove(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (_topRoute == oldRoute || _topRoute == null) _topRoute = newRoute;
    if (oldRoute != null) _pageIds.remove(oldRoute);
    if (newRoute != null) {
      final name = newRoute.settings.name;
      final pageId = _pageIdForRoute(name, newRoute);
      _pageIds[newRoute] = pageId;
      _schedulePageUpdate(
        pageId,
        selectedPrimaryIndex: _primaryIndexForPage(pageId),
        customizing: _isUnnamedPopup(newRoute)
            ? _appPageState.isCustomizing
            : name == '/app/customize' || name == '/app/more',
      );
    }
  }
}

/// Implements the `MyStreamingService` class for this feature or UI component.
final GlobalKey<NavigatorState> _appNavigatorKey = GlobalKey<NavigatorState>();

/// Root application widget that owns the global navigator and language picker.
class MyStreamingService extends StatefulWidget {
  const MyStreamingService({super.key});

  @override
  State<MyStreamingService> createState() => _MyStreamingServiceState();
}

/// State for [MyStreamingService], including the global language picker overlay.
class _MyStreamingServiceState extends State<MyStreamingService> {
  @override
  void initState() {
    super.initState();
    PageCustomizationController.configure(_openPageCustomizationFor);
    LanguageController.instance.addListener(_handleLanguageChanged);
  }

  void _handleLanguageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    LanguageController.instance.removeListener(_handleLanguageChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: Locale(LanguageController.instance.current.code),
      supportedLocales: LanguageController.languages
          .map((language) => Locale(language.code))
          .toList(growable: false),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      navigatorKey: _appNavigatorKey,
      navigatorObservers: <NavigatorObserver>[_appPageRouteObserver],
      title: tr('My Personal Streaming Service'),
      builder: (context, child) {
        // Keep one Overlay above the app Navigator. The Navigator itself
        // owns its route overlay, but the language picker also needs an
        // Overlay ancestor. Keeping both here avoids a second overlay being
        // installed dynamically during login/route replacement.
        return Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (overlayContext) {
                return AnimatedBuilder(
                  animation: LanguageController.instance,
                  builder: (_, __) {
                    final rtl =
                        LanguageController.instance.current.code == 'ar';
                    return Directionality(
                      textDirection:
                          rtl ? TextDirection.rtl : TextDirection.ltr,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ResponsiveScope(
                            child: _AppPageSurface(
                              child: ResponsiveAppSurface(
                                child: child ?? const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            OverlayEntry(
              builder: (overlayContext) => Positioned.fill(
                child: AnimatedBuilder(
                  animation: _appPageState,
                  builder: (context, _) {
                    final profileSelected =
                        AppController.instance.currentProfile != null;
                    final routeIsOnboarding = _appPageState.pageId == 'boot' ||
                        _appPageState.pageId == 'profiles' ||
                        _appPageState.pageId == 'server-selection' ||
                        _appPageState.pageId == 'import';

                    if (!profileSelected ||
                        routeIsOnboarding ||
                        _appPageState.pageId == 'player') {
                      return const SizedBox.shrink();
                    }

                    return Align(
                      alignment: Alignment.bottomLeft,
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: 12,
                          bottom: MediaQuery.paddingOf(context).bottom + 12,
                        ),
                        child: const IgnorePointer(
                          ignoring: false,
                          child: Material(
                            color: Colors.transparent,
                            child: LanguagePicker(),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF090909),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        cardTheme: CardThemeData(
          color: const Color(0xFF141414),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF151515),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF151515),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.redAccent),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF0E0E0E),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      home: _initialPage(),
    );
  }
}

Widget _initialPage() {
  final token = Uri.base.queryParameters['token']?.trim() ?? '';
  if (token.isNotEmpty) {
    return InvitationJoinScreen(token: token);
  }
  return const SplashScreen();
}

class _PageAppearance {
  final int accentColor;
  final int backgroundColor;
  final String density;

  const _PageAppearance({
    this.accentColor = 0xFFE53935,
    this.backgroundColor = 0xFF090909,
    this.density = 'Comfortable',
  });

  _PageAppearance copyWith({
    int? accentColor,
    int? backgroundColor,
    String? density,
  }) =>
      _PageAppearance(
        accentColor: accentColor ?? this.accentColor,
        backgroundColor: backgroundColor ?? this.backgroundColor,
        density: density ?? this.density,
      );
}

class _PageAppearanceStore {
  static final Map<String, _PageAppearance> _cache =
      <String, _PageAppearance>{};

  static String get _profileKey =>
      AppController.instance.currentProfile?.id ?? 'default';

  static String _key(String pageId) => 'page_appearance_${_profileKey}_$pageId';

  static _PageAppearance forPage(String pageId) {
    final cacheKey = '${_profileKey}_$pageId';
    return _cache.putIfAbsent(cacheKey, () {
      final raw = HomeCustomizationStore._prefs?.getString(_key(pageId));
      if (raw == null) return const _PageAppearance();
      try {
        final json = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        return _PageAppearance(
          accentColor: (json['accentColor'] as num?)?.toInt() ?? 0xFFE53935,
          backgroundColor:
              (json['backgroundColor'] as num?)?.toInt() ?? 0xFF090909,
          density: json['density']?.toString() ?? 'Comfortable',
        );
      } catch (_) {
        return const _PageAppearance();
      }
    });
  }

  static Future<void> save(String pageId, _PageAppearance appearance) async {
    _cache['${_profileKey}_$pageId'] = appearance;
    await HomeCustomizationStore._prefs?.setString(
      _key(pageId),
      jsonEncode(<String, dynamic>{
        'accentColor': appearance.accentColor,
        'backgroundColor': appearance.backgroundColor,
        'density': appearance.density,
      }),
    );
    _appPageState.refresh();
  }
}

class _AppPageSurface extends StatelessWidget {
  final Widget child;

  const _AppPageSurface({required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        _appPageState,
        AppController.instance,
        AppAccessibilitySettings.instance,
        HomeCustomizationStore.revision,
      ]),
      builder: (context, _) {
        AppAccessibilitySettings.instance.ensureLoaded(
          profileId: AppController.instance.currentProfile?.id,
        );
        final appearance = _PageAppearanceStore.forPage(_appPageState.pageId);
        final accessibility = AppAccessibilitySettings.instance;
        final density = switch (appearance.density) {
          'Compact' => VisualDensity.compact,
          'Spacious' => const VisualDensity(horizontal: 1, vertical: 1),
          _ => VisualDensity.standard,
        };
        final baseTheme = Theme.of(context);
        final highContrastScheme = ColorScheme.fromSeed(
          seedColor: Colors.white,
          brightness: baseTheme.brightness,
        ).copyWith(
          primary: Colors.white,
          onPrimary: Colors.black,
          secondary: Colors.yellowAccent,
          onSecondary: Colors.black,
          surface: Colors.black,
          onSurface: Colors.white,
        );
        final theme = baseTheme.copyWith(
          scaffoldBackgroundColor: accessibility.highContrast
              ? Colors.black
              : Color(appearance.backgroundColor),
          colorScheme: accessibility.highContrast
              ? highContrastScheme
              : ColorScheme.fromSeed(
                  seedColor: Color(appearance.accentColor),
                  brightness: baseTheme.brightness,
                ),
          textTheme: accessibility.highContrast
              ? baseTheme.textTheme
                  .apply(bodyColor: Colors.white, displayColor: Colors.white)
              : baseTheme.textTheme,
          visualDensity: density,
        );
        final media = MediaQuery.of(context);
        final systemScale = media.textScaler.scale(14.0) / 14.0;
        final effectiveTextScale = (systemScale * accessibility.appTextScale)
            .clamp(0.75, 2.2)
            .toDouble();
        final showGlobalNavigation =
            AppController.instance.currentProfile != null &&
                _appPageState.pageId != 'boot' &&
                _appPageState.pageId != 'profiles' &&
                _appPageState.pageId != 'server-selection' &&
                _appPageState.pageId != 'import' &&
                _appPageState.pageId != 'player' &&
                _appPageState.pageId != 'customize' &&
                _appPageState.pageId != 'more' &&
                !_appPageState.isCustomizing;
        final configuredNav = HomeCustomizationStore.settingsFor(
          AppController.instance.currentProfile,
        ).navbarPosition;
        final navPosition = const {'Top', 'Bottom', 'Left', 'Right'}.contains(configuredNav)
            ? configuredNav
            : 'Bottom';
        final verticalNav = navPosition == 'Left' || navPosition == 'Right';
        const globalNavigationHeight = 84.0;
        const globalNavigationRailWidth = 88.0;
        final safe = MediaQuery.paddingOf(context);
        final bottomInset = showGlobalNavigation && navPosition == 'Bottom'
            ? globalNavigationHeight + safe.bottom : 0.0;
        final topInset = showGlobalNavigation && navPosition == 'Top'
            ? globalNavigationHeight + safe.top : 0.0;
        final leftInset = showGlobalNavigation && navPosition == 'Left'
            ? globalNavigationRailWidth + safe.left : 0.0;
        final rightInset = showGlobalNavigation && navPosition == 'Right'
            ? globalNavigationRailWidth + safe.right : 0.0;
        return MediaQuery(
          data: media.copyWith(
            disableAnimations: accessibility.reduceMotion,
            textScaler: TextScaler.linear(effectiveTextScale),
          ),
          child: Theme(
            data: theme,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Padding(
                  padding: EdgeInsets.only(
                    top: topInset,
                    bottom: bottomInset,
                    left: leftInset,
                    right: rightInset,
                  ),
                  child: child,
                ),
                if (showGlobalNavigation)
                  Positioned(
                    left: navPosition == 'Left' ? 0 : (verticalNav ? null : 0),
                    right: navPosition == 'Right' ? 0 : (verticalNav ? null : 0),
                    top: verticalNav ? 0 : (navPosition == 'Top' ? 0 : null),
                    bottom: verticalNav ? 0 : (navPosition == 'Bottom' ? 0 : null),
                    width: verticalNav ? globalNavigationRailWidth : null,
                    height: verticalNav ? null : globalNavigationHeight,
                    child: SafeArea(
                      top: navPosition == 'Top' || verticalNav,
                      bottom: navPosition == 'Bottom' || verticalNav,
                      left: navPosition == 'Left' || !verticalNav,
                      right: navPosition == 'Right' || !verticalNav,
                      child: _GlobalPrimaryNavigationBar(vertical: verticalNav),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _pageTitleFor(String pageId) => switch (pageId) {
      'home' => 'Home',
      'library' => 'Watch',
      'friends' => 'Friends',
      'movies' => 'Movies',
      'series' => 'TV Shows',
      'music' => 'Music',
      'people' => 'People',
      'actors' => 'Actors',
      'artists' => 'Artists & Bands',
      'bands' => 'Bands',
      'shop' => 'Store',
      'details' => 'Details',
      'collections' => 'Collections',
      'my-tv' => 'TV Channels',
      'hey-marathon' => 'Hey Marathon',
      'store-creation' => 'Store Creation',
      'store-settings' => 'Store Settings',
      'seller-dashboard' => 'Seller Dashboard',
      'favorites' => 'Favorites',
      'coming-soon' => 'Coming Soon',
      'search' => 'Search',
      'reviews' => 'Reviews',
      'import' => 'Import',
      'remote-access' => 'Remote Access',
      'settings' => 'Settings',
      'devices' => 'Devices',
      'home-server' => 'Home Server',
      'members' => 'Account Members',
      'production-readiness' => 'Production Readiness',
      'accessibility-offline' => 'Accessibility & Offline',
      'security-privacy' => 'Security & Privacy',
      _ => 'Page',
    };

void _openPageCustomizationFor(BuildContext context, String pageId) {
  final navigator = _appNavigatorKey.currentState;
  if (navigator == null) return;
  final navigatorContext = navigator.context;
  if (pageId == 'home') {
    navigator.push<void>(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/app/customize'),
        builder: (_) => const CustomizeHomeScreen(
          lockedPage: CustomizationPage.home,
        ),
      ),
    );
  } else if (pageId == 'details') {
    navigator.push<void>(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/app/customize'),
        builder: (_) => const CustomizeHomeScreen(
          lockedPage: CustomizationPage.details,
        ),
      ),
    );
  } else if (pageId == 'music') {
    showMusicCustomization(navigatorContext);
  } else {
    navigator.push<void>(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/app/customize'),
        builder: (_) => _PageCustomizationScreen(pageId: pageId),
      ),
    );
  }
}

class _PageCustomizationScreen extends StatefulWidget {
  final String pageId;

  const _PageCustomizationScreen({required this.pageId});

  @override
  State<_PageCustomizationScreen> createState() =>
      _PageCustomizationScreenState();
}

class _PageCustomizationScreenState extends State<_PageCustomizationScreen> {
  late _PageAppearance draft;
  late PageContentCustomization contentDraft;
  late AppSectionCustomization sectionDraft;
  PageHeroSettings? _heroSettings;

  static const _colors = <String, int>{
    'Red': 0xFFE53935,
    'Purple': 0xFF9C27B0,
    'Blue': 0xFF2196F3,
    'Teal': 0xFF009688,
    'Green': 0xFF4CAF50,
    'Amber': 0xFFFFC107,
  };

  @override
  void initState() {
    super.initState();
    draft = _PageAppearanceStore.forPage(widget.pageId);
    contentDraft = PageContentCustomizationStore.settingsFor(widget.pageId);
    sectionDraft = AppSectionCustomizationStore.settingsFor(
        AppController.instance.currentProfile);
    StoryPlacementStore.load(AppController.instance.currentProfile);
    if (widget.pageId == 'movies' || widget.pageId == 'series') {
      unawaited(PageHeroSettingsStore.load(widget.pageId).then((value) {
        if (mounted) setState(() => _heroSettings = value);
      }));
    }
  }

  Widget _socialThemeDropdown(
      String label, String value, ValueChanged<String> onChanged) {
    return SocialThemePickerField(
      label: label,
      value: value,
      onChanged: onChanged,
    );
  }

  void _moveSocialNavItem(int from, int to) {
    setState(() {
      final order = List<String>.from(sectionDraft.socialNavOrder);
      final moved = order.removeAt(from);
      order.insert(to, moved);
      sectionDraft.socialNavOrder = order;
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = _pageTitleFor(widget.pageId);
    final sections = PageContentCustomizationStore.sectionsFor(widget.pageId);
    return Scaffold(
      appBar: AppBar(title: Text('Customize $title')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const UniversalText(
            'These settings apply only to this page.',
            style: TextStyle(color: Colors.white70),
          ),
          if (_heroSettings != null) ...[
            const SizedBox(height: 16),
            PageHeroSettingsPanel(
              pageTitle: widget.pageId == 'series' ? 'TV Shows' : 'Movies',
              settings: _heroSettings!,
              onChanged: (value) => setState(() => _heroSettings = value),
            ),
            const SizedBox(height: 12),
          ],
          if (widget.pageId == 'shop' ||
              widget.pageId == 'library' ||
              widget.pageId == 'friends') ...[
            const SizedBox(height: 4),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$title layout',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    if (widget.pageId == 'shop') ...[
                      DropdownButtonFormField<String>(
                        initialValue: sectionDraft.shopCardStyle,
                        decoration: const InputDecoration(
                            labelText: 'Product card style'),
                        items: const ['Compact', 'Comfortable', 'Large']
                            .map((v) =>
                                DropdownMenuItem(value: v, child: Text(v)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => sectionDraft.shopCardStyle = v);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<int>(
                        initialValue: sectionDraft.shopColumns,
                        decoration: const InputDecoration(
                            labelText: 'Products per row'),
                        items: const [1, 2, 3, 4]
                            .map((v) =>
                                DropdownMenuItem(value: v, child: Text('$v')))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => sectionDraft.shopColumns = v);
                          }
                        },
                      ),
                      SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: sectionDraft.showShopPrices,
                          onChanged: (v) =>
                              setState(() => sectionDraft.showShopPrices = v),
                          title: const UniversalText('Show prices')),
                      SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: sectionDraft.showShopInventory,
                          onChanged: (v) => setState(
                              () => sectionDraft.showShopInventory = v),
                          title: const UniversalText('Show inventory counts')),
                    ] else if (widget.pageId == 'library') ...[
                      DropdownButtonFormField<String>(
                        initialValue: sectionDraft.libraryViewMode,
                        decoration:
                            const InputDecoration(labelText: 'Library layout'),
                        items: const [
                          DropdownMenuItem(
                              value: 'List', child: UniversalText('List view')),
                          DropdownMenuItem(
                              value: 'Grid', child: UniversalText('Grid view')),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => sectionDraft.libraryViewMode = v);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: sectionDraft.libraryCardStyle,
                        decoration: const InputDecoration(
                            labelText: 'Library card appearance'),
                        items: const ['Poster', 'Landscape', 'Compact']
                            .map((v) =>
                                DropdownMenuItem(value: v, child: Text(v)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => sectionDraft.libraryCardStyle = v);
                          }
                        },
                      ),
                      if (sectionDraft.libraryViewMode == 'Grid') ...[
                        const SizedBox(height: 10),
                        DropdownButtonFormField<int>(
                          initialValue:
                              sectionDraft.libraryColumns.clamp(1, 6).toInt(),
                          decoration: const InputDecoration(
                              labelText: 'Widgets per row'),
                          items: const [1, 2, 3, 4, 5, 6]
                              .map((v) => DropdownMenuItem(
                                  value: v, child: Text('$v per row')))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => sectionDraft.libraryColumns = v);
                            }
                          },
                        ),
                      ],
                      const SizedBox(height: 16),
                      const UniversalText('Individual widget sizes',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      const UniversalText(
                          'Choose the size of each library shortcut independently.',
                          style: TextStyle(color: Colors.white60)),
                      const SizedBox(height: 8),
                      for (final item in const <Map<String, String>>[
                        {'id': 'movies', 'label': 'Movies'},
                        {'id': 'tv-shows', 'label': 'TV shows'},
                        {'id': 'music', 'label': 'Music'},
                        {'id': 'collections', 'label': 'Collections'},
                        {'id': 'favorites', 'label': 'Favorites'},
                        {'id': 'coming-soon', 'label': 'Coming soon'},
                      ])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: DropdownButtonFormField<String>(
                            initialValue: const [
                              'Small',
                              'Medium',
                              'Large'
                            ].contains(
                                    sectionDraft.libraryWidgetSizes[item['id']])
                                ? sectionDraft.libraryWidgetSizes[item['id']]
                                : 'Medium',
                            decoration: InputDecoration(
                                labelText: '${item['label']} widget size'),
                            items: const ['Small', 'Medium', 'Large']
                                .map((v) =>
                                    DropdownMenuItem(value: v, child: Text(v)))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() {
                                  sectionDraft.libraryWidgetSizes = {
                                    ...sectionDraft.libraryWidgetSizes,
                                    item['id']!: v,
                                  };
                                });
                              }
                            },
                          ),
                        ),
                    ] else ...[
                      const UniversalText('Customize each social surface',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      const UniversalText(
                          'Use general design styles for each section. These presets do not use another service’s name, logo, or branded assets.',
                          style: TextStyle(color: Colors.white60)),
                      const SizedBox(height: 12),
                      _socialThemeDropdown('Feed theme', sectionDraft.feedStyle,
                          (v) => setState(() => sectionDraft.feedStyle = v)),
                      const SizedBox(height: 10),
                      _socialThemeDropdown(
                          'Profile page theme',
                          sectionDraft.profilePageStyle,
                          (v) => setState(
                              () => sectionDraft.profilePageStyle = v)),
                      const SizedBox(height: 10),
                      _socialThemeDropdown(
                          'Communities theme',
                          sectionDraft.communitiesStyle,
                          (v) => setState(
                              () => sectionDraft.communitiesStyle = v)),
                      const SizedBox(height: 10),
                      _socialThemeDropdown(
                          'Friends theme',
                          sectionDraft.friendsStyle,
                          (v) => setState(() => sectionDraft.friendsStyle = v)),
                      const SizedBox(height: 10),
                      _socialThemeDropdown(
                          'Messages theme',
                          sectionDraft.messagesStyle,
                          (v) =>
                              setState(() => sectionDraft.messagesStyle = v)),
                      const SizedBox(height: 10),
                      _socialThemeDropdown(
                          'Reels / Shorts / Videos theme',
                          sectionDraft.reelsStyle,
                          (v) => setState(() => sectionDraft.reelsStyle = v)),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<String>(
                        initialValue: sectionDraft.socialNavPosition,
                        decoration: const InputDecoration(
                            labelText: 'Social navigation position'),
                        items: const [
                          DropdownMenuItem(
                              value: 'Top', child: UniversalText('Top bar')),
                          DropdownMenuItem(
                              value: 'Left',
                              child: UniversalText('Left side rail')),
                          DropdownMenuItem(
                              value: 'Right',
                              child: UniversalText('Right side rail')),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => sectionDraft.socialNavPosition = v);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      const UniversalText('Social section order',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      const UniversalText(
                          'Choose each profile’s preferred order.',
                          style:
                              TextStyle(color: Colors.white60, fontSize: 12)),
                      const SizedBox(height: 6),
                      for (var index = 0;
                          index < sectionDraft.socialNavOrder.length;
                          index++)
                        Card(
                          child: ListTile(
                            title: Text(sectionDraft.socialNavOrder[index]),
                            leading: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                      visualDensity: VisualDensity.compact,
                                      tooltip: 'Move up',
                                      onPressed: index == 0
                                          ? null
                                          : () => _moveSocialNavItem(
                                              index, index - 1),
                                      icon: const Icon(
                                          Icons.keyboard_arrow_up_rounded)),
                                  IconButton(
                                      visualDensity: VisualDensity.compact,
                                      tooltip: 'Move down',
                                      onPressed: index ==
                                              sectionDraft
                                                      .socialNavOrder.length -
                                                  1
                                          ? null
                                          : () => _moveSocialNavItem(
                                              index, index + 1),
                                      icon: const Icon(
                                          Icons.keyboard_arrow_down_rounded)),
                                ]),
                          ),
                        ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: sectionDraft.profilePageViewMode,
                        decoration: const InputDecoration(
                            labelText: 'Profile posts layout'),
                        items: const [
                          DropdownMenuItem(
                              value: 'Post cards',
                              child: UniversalText('Post card boxes')),
                          DropdownMenuItem(
                              value: 'Timeline',
                              child: UniversalText('Scrollable timeline'))
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(
                                () => sectionDraft.profilePageViewMode = v);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: sectionDraft.profilePostsSortOrder,
                        decoration: const InputDecoration(
                            labelText: 'Profile post order'),
                        items: const [
                          DropdownMenuItem(
                              value: 'Newest to Oldest',
                              child: UniversalText('Newest to Oldest')),
                          DropdownMenuItem(
                              value: 'Oldest to Newest',
                              child: UniversalText('Oldest to Newest'))
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(
                                () => sectionDraft.profilePostsSortOrder = v);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: sectionDraft.friendsViewMode,
                        decoration:
                            const InputDecoration(labelText: 'Friends layout'),
                        items: const [
                          DropdownMenuItem(
                              value: 'List', child: UniversalText('List view')),
                          DropdownMenuItem(
                              value: 'Cards', child: UniversalText('Card view'))
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => sectionDraft.friendsViewMode = v);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: sectionDraft.friendsSortOrder,
                        decoration:
                            const InputDecoration(labelText: 'Friends order'),
                        items: const [
                          DropdownMenuItem(
                              value: 'Oldest to Newest',
                              child: UniversalText('Oldest to Newest')),
                          DropdownMenuItem(
                              value: 'Newest to Oldest',
                              child: UniversalText('Newest to Oldest')),
                          DropdownMenuItem(
                              value: 'A-Z',
                              child: UniversalText('Alphabetical A-Z')),
                          DropdownMenuItem(
                              value: 'Z-A',
                              child: UniversalText('Alphabetical Z-A'))
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => sectionDraft.friendsSortOrder = v);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: sectionDraft.communitiesViewMode,
                        decoration: const InputDecoration(
                            labelText: 'Communities layout'),
                        items: const [
                          DropdownMenuItem(
                              value: 'List', child: UniversalText('List view')),
                          DropdownMenuItem(
                              value: 'Cards', child: UniversalText('Card view'))
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(
                                () => sectionDraft.communitiesViewMode = v);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: sectionDraft.communitiesMembershipFilter,
                        decoration: const InputDecoration(
                            labelText: 'Communities to show'),
                        items: const [
                          DropdownMenuItem(
                              value: 'All',
                              child: UniversalText('All available')),
                          DropdownMenuItem(
                              value: 'Joined',
                              child: UniversalText('Joined communities')),
                          DropdownMenuItem(
                              value: 'Created',
                              child: UniversalText('Communities I created'))
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() =>
                                sectionDraft.communitiesMembershipFilter = v);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: sectionDraft.communitiesSortOrder,
                        decoration: const InputDecoration(
                            labelText: 'Communities order'),
                        items: const [
                          DropdownMenuItem(
                              value: 'Newest to Oldest',
                              child: UniversalText('Newest to Oldest')),
                          DropdownMenuItem(
                              value: 'Oldest to Newest',
                              child: UniversalText('Oldest to Newest')),
                          DropdownMenuItem(
                              value: 'Movies', child: UniversalText('Movies')),
                          DropdownMenuItem(
                              value: 'Shows', child: UniversalText('Shows')),
                          DropdownMenuItem(
                              value: 'Music', child: UniversalText('Music')),
                          DropdownMenuItem(
                              value: 'Joined',
                              child: UniversalText('Recently joined')),
                          DropdownMenuItem(
                              value: 'Created',
                              child: UniversalText('Recently created'))
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(
                                () => sectionDraft.communitiesSortOrder = v);
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: StoryPlacementStore.forProfile(
                            AppController.instance.currentProfile),
                        decoration: const InputDecoration(
                            labelText: 'Friends’ Stories placement'),
                        items: const [
                          DropdownMenuItem(
                              value: 'none',
                              child: UniversalText('Don’t show')),
                          DropdownMenuItem(
                              value: 'home', child: UniversalText('Home only')),
                          DropdownMenuItem(
                              value: 'friends',
                              child: UniversalText('Friends only')),
                          DropdownMenuItem(
                              value: 'both',
                              child: UniversalText('Home + Friends')),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            StoryPlacementStore.setForProfile(
                                AppController.instance.currentProfile, v);
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 20),
          DropdownButtonFormField<int>(
            initialValue: _colors.values.contains(draft.accentColor)
                ? draft.accentColor
                : _colors.values.first,
            decoration: const InputDecoration(labelText: 'Accent color'),
            items: _colors.entries
                .map((entry) => DropdownMenuItem<int>(
                      value: entry.value,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 9,
                            backgroundColor: Color(entry.value),
                          ),
                          const SizedBox(width: 10),
                          Text(entry.key),
                        ],
                      ),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => draft = draft.copyWith(accentColor: value));
              }
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: draft.backgroundColor,
            decoration: const InputDecoration(labelText: 'Page background'),
            items: const [
              DropdownMenuItem(
                  value: 0xFF090909, child: UniversalText('Black')),
              DropdownMenuItem(
                  value: 0xFF151515, child: UniversalText('Charcoal')),
              DropdownMenuItem(value: 0xFF071A33, child: UniversalText('Navy')),
              DropdownMenuItem(
                  value: 0xFF0B2B17, child: UniversalText('Forest')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => draft = draft.copyWith(backgroundColor: value));
              }
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: draft.density,
            decoration: const InputDecoration(labelText: 'Content spacing'),
            items: const [
              DropdownMenuItem(
                  value: 'Compact', child: UniversalText('Compact')),
              DropdownMenuItem(
                  value: 'Comfortable', child: UniversalText('Comfortable')),
              DropdownMenuItem(
                  value: 'Spacious', child: UniversalText('Spacious')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => draft = draft.copyWith(density: value));
              }
            },
          ),
          if (sections.isNotEmpty) ...[
            const SizedBox(height: 24),
            const UniversalText(
              'Page sections',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const UniversalText(
              'Choose what appears and use the arrows to change its order.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            for (var index = 0;
                index < contentDraft.sectionOrder.length;
                index++)
              Card(
                child: ListTile(
                  title: Text(_customizationSectionName(
                    widget.pageId,
                    contentDraft.sectionOrder[index],
                  )),
                  leading: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Move up',
                        onPressed: index == 0
                            ? null
                            : () => _moveContentSection(index, index - 1),
                        icon: const Icon(Icons.keyboard_arrow_up_rounded),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Move down',
                        onPressed: index == contentDraft.sectionOrder.length - 1
                            ? null
                            : () => _moveContentSection(index, index + 1),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      ),
                    ],
                  ),
                  trailing: Switch(
                    value: !contentDraft.hiddenSections
                        .contains(contentDraft.sectionOrder[index]),
                    onChanged: (visible) =>
                        _setContentSectionVisible(index, visible),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () async {
              final navigator = Navigator.of(context);
              await _PageAppearanceStore.save(widget.pageId, draft);
              final heroSettings = _heroSettings;
              if (heroSettings != null) {
                await PageHeroSettingsStore.save(widget.pageId, heroSettings);
              }
              await PageContentCustomizationStore.apply(
                widget.pageId,
                contentDraft,
              );
              await AppSectionCustomizationStore.save(
                AppController.instance.currentProfile,
                sectionDraft,
              );
              if (!mounted) return;
              navigator.pop();
            },
            icon: const Icon(Icons.check_rounded),
            label: const UniversalText('Save this page'),
          ),
        ],
      ),
    );
  }

  void _moveContentSection(int from, int to) {
    setState(() {
      final order = List<String>.from(contentDraft.sectionOrder);
      final moved = order.removeAt(from);
      order.insert(to, moved);
      contentDraft = PageContentCustomization(
        sectionOrder: order,
        hiddenSections: contentDraft.hiddenSections,
      );
    });
  }

  void _setContentSectionVisible(int index, bool visible) {
    final section = contentDraft.sectionOrder[index];
    final hidden = Set<String>.from(contentDraft.hiddenSections);
    if (visible) {
      hidden.remove(section);
    } else {
      if (contentDraft.visibleSections.length <= 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  UniversalText('Keep at least one page section visible.')),
        );
        return;
      }
      hidden.add(section);
    }
    setState(() {
      contentDraft = PageContentCustomization(
        sectionOrder: contentDraft.sectionOrder,
        hiddenSections: hidden,
      );
    });
  }
}

String _customizationSectionName(String pageId, String id) => switch (id) {
      'search' => 'Universal search',
      'movies' => 'Movies',
      'tv-shows' => 'TV shows',
      'reviews' => 'Reviews',
      'people' => 'People',
      'music' => 'Music',
      'summary' => 'Library summary',
      'collections' => 'Collections',
      'my-tv' => 'My TV',
      'favorites' => 'Favorites',
      'coming-soon' => 'Coming soon',
      'storage' => 'Account storage',
      'featured' => 'Featured products',
      'related' => 'Related to your library',
      'stores' => 'Stores',
      'products' => 'Products',
      'media' => 'Matching media results',
      'feed' => 'Feed',
      'reels' => 'Reels',
      'messages' => 'Messages',
      'friends' => 'Friends',
      'communities' => 'Communities',
      'my-page' => 'My Page',
      _ => '$pageId section',
    };

// ============================================================
String? _pendingChatInviteToken = Uri.base.queryParameters['chatInvite'];

Future<void> _enterMainHome() => _navigateToMainHome();

Future<void> _enterMainHomeFrom(BuildContext sourceContext) =>
    _navigateToMainHome(sourceContext);

Future<void> _navigateToMainHome([BuildContext? sourceContext]) async {
  NavigatorState? navigator;
  // Prefer the navigator attached to the active onboarding route. The global
  // key can briefly still point at a navigator whose route stack is being
  // replaced after server/profile handoff.
  if (sourceContext != null && sourceContext.mounted) {
    navigator = Navigator.of(sourceContext, rootNavigator: true);
  }
  navigator ??= _appNavigatorKey.currentState;
  if (navigator == null) return;

  var destination = PrimaryDestination.home;
  final token = _pendingChatInviteToken?.trim();
  final profile = AppController.instance.currentProfile;
  if (token != null && token.isNotEmpty && profile != null) {
    // Do not let an invite API stall the onboarding flow. If the request fails
    // or times out, the person still reaches Home and can use the in-community
    // Join chat action later.
    _pendingChatInviteToken = null;
    try {
      await AppController.instance.backendApi
          .acceptSocialConversationInvite(
            profileId: profile.id,
            token: token,
          )
          .timeout(const Duration(seconds: 8));
      destination = PrimaryDestination.friends;
    } catch (_) {
      destination = PrimaryDestination.home;
    }
  }

  if (!navigator.mounted) return;
  // Keep onboarding active until the first MainScreen frame is rendered.
  final routeName = '/main/${destination.name}';
  navigator.pushAndRemoveUntil<void>(
    MaterialPageRoute<void>(
      settings: RouteSettings(name: routeName),
      builder: (_) => MainScreen(initialDestination: destination),
    ),
    (route) => false,
  );
}

// SPLASH SCREEN
// ============================================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

/// Implements the `_SplashScreenState` class for this feature or UI component.
class _SplashScreenState extends State<SplashScreen> {
  @override

  /// Performs `initState` for this feature. Update this documentation when its contract changes.
  void initState() {
    super.initState();
    _restoreOrShowWelcome();
  }

  /// Restores an existing encrypted session. Returning users skip the
  /// How It Works, sign-up, and login screens and go directly to profile selection.
  Future<void> _restoreOrShowWelcome() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    final restored = await AppController.instance.restoreBackendSession();
    if (!mounted) return;

    if (restored) {
      final serverContext = await AppController.instance.loadServerContext();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          settings: RouteSettings(
              name: serverContext.needsServerSelection
                  ? '/app/server-selection'
                  : '/app/profiles'),
          builder: (_) => serverContext.needsServerSelection
              ? ServerSelectionScreen(
                  onProfileReady: _enterMainHomeFrom,
                  onOpened: () => _appPageState.setPage('server-selection',
                      selectedPrimaryIndex: 0, customizing: false),
                  onServerSaved: () => _appPageState.setPage('profiles',
                      selectedPrimaryIndex: 0, customizing: false),
                )
              : ProfileSelectionScreen(
                  onProfileSelected: (profileContext) =>
                      _enterMainHomeFrom(profileContext),
                  onOpened: () => _appPageState.setPage('profiles',
                      selectedPrimaryIndex: 0, customizing: false),
                ),
        ),
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HowItWorksScreen(
          loginBuilder: (_) => const LoginScreen(),
        ),
      ),
    );
  }

  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(
              Icons.play_circle_fill,
              size: 90,
              color: Colors.red,
            ),
            SizedBox(height: 20),
            UniversalText(
              'MY STREAMING SERVICE',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// LOGIN
// ============================================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

/// Implements the `_LoginScreenState` class for this feature or UI component.
class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool obscurePassword = true;
  bool loggingIn = false;
  @override

  /// Performs `dispose` for this feature. Update this documentation when its contract changes.
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  /// Performs `login` for this feature. Update this documentation when its contract changes.
  Future<void> login() async {
    if (loggingIn) return;
    final email = emailController.text.trim();
    final password = passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: UniversalText(
            'Enter your email and password.',
          ),
        ),
      );
      return;
    }

    setState(() {
      loggingIn = true;
    });

    final controller = AppController.instance;

    try {
      final loginResponse = await controller.loginWithBackend(
        email: email,
        password: password,
      );

      if (loginResponse['requiresMfa'] == true) {
        if (!mounted) return;
        final codeController = TextEditingController();
        final verified = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const UniversalText('Multi-factor authentication'),
            content: TextField(
                controller: codeController,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                    labelText: 'Enter the 6-digit code sent to your email')),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const UniversalText('CANCEL')),
              FilledButton(
                  onPressed: () async {
                    try {
                      await controller.backendApi.verifyMfaLogin(
                          email: email, code: codeController.text);
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext, true);
                      }
                    } catch (_) {
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext, false);
                      }
                    }
                  },
                  child: const UniversalText('VERIFY')),
            ],
          ),
        );
        codeController.dispose();
        if (verified != true) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: UniversalText('MFA verification was not completed.')));
          return;
        }
        final account = await controller.backendApi.getCurrentAccount();
        controller.applyBackendAccountFromResponse(account);
      }

      final security = controller.lastLoginSecurity;
      if (security?['suspicious'] == true) {
        final question = security?['question']?.toString().trim();
        if (question == null || question.isEmpty) {
          await controller.logoutFromBackend();
          throw Exception(
              'This sign-in was flagged as suspicious, but no security question is configured.');
        }

        if (!mounted) return;
        final answerController = TextEditingController();
        final verified = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const UniversalText('Suspicious Login Detected'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const UniversalText(
                    'This sign-in looks different from a known device or follows recent failed attempts.'),
                const SizedBox(height: 16),
                const UniversalText('Security question',
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(question,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                TextField(
                    controller: answerController,
                    autofocus: true,
                    obscureText: true,
                    decoration:
                        InputDecoration(labelText: tr('Enter your answer'))),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const UniversalText('SIGN OUT')),
              FilledButton(
                  onPressed: () async {
                    try {
                      final ok = await controller.backendApi
                          .verifySecurityAnswer(answerController.text);
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext, ok);
                      }
                    } catch (_) {
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext, false);
                      }
                    }
                  },
                  child: const UniversalText('VERIFY')),
            ],
          ),
        );
        answerController.dispose();
        if (verified != true) {
          await controller.logoutFromBackend();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: UniversalText(
                  'Access denied. The security answer was incorrect.')));
          return;
        }
      }

      if (!mounted) return;

      final serverContext = await controller.loadServerContext();
      if (!mounted) return;
      if (serverContext.needsServerSelection) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            settings: const RouteSettings(name: '/app/server-selection'),
            builder: (_) => ServerSelectionScreen(
              onProfileReady: _enterMainHomeFrom,
              onOpened: () => _appPageState.setPage('server-selection',
                  selectedPrimaryIndex: 0, customizing: false),
              onServerSaved: () => _appPageState.setPage('profiles',
                  selectedPrimaryIndex: 0, customizing: false),
            ),
          ),
        );
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileSelectionScreen(
            onProfileSelected: (profileContext) =>
                _enterMainHomeFrom(profileContext),
            onOpened: () => _appPageState.setPage('profiles',
                selectedPrimaryIndex: 0, customizing: false),
          ),
          settings: const RouteSettings(name: '/app/profiles'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      String message = error.toString();

      if (message.startsWith('BackendApiException:')) {
        message = message
            .replaceFirst(
              'BackendApiException:',
              '',
            )
            .trim();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          loggingIn = false;
        });
      }
    }
  }

  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 450,
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.play_circle_fill,
                  size: 80,
                  color: Colors.red,
                ),
                const SizedBox(height: 20),
                const UniversalText(
                  'Welcome Back',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: emailController,
                  enabled: !loggingIn,
                  decoration: InputDecoration(
                    labelText: tr('Email address'),
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: passwordController,
                  enabled: !loggingIn,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: tr('Password'),
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: loggingIn
                          ? null
                          : () {
                              setState(() {
                                obscurePassword = !obscurePassword;
                              });
                            },
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: loggingIn ? null : login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: loggingIn
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const UniversalText(
                            'LOGIN',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: loggingIn
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SignupScreen(),
                            ),
                          );
                        },
                  child: const UniversalText(
                    'Create a new account',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const Map<String, Color> namedColors = {
  'Red': Colors.red,
  'Blue': Colors.blue,
  'Black': Colors.black,
  'White': Colors.white,
  'Yellow': Colors.yellow,
  'Green': Colors.green,
  'Purple': Colors.purple,
  'Violet': Color.fromARGB(255, 238, 130, 238),
  'Indigo': Colors.indigo,
  'Pink': Colors.pink,
  'Maroon': Color.fromARGB(255, 128, 0, 0),
  'Fuchsia': Color.fromARGB(255, 255, 0, 255),
  'Aqua': Color.fromARGB(255, 0, 255, 255),
  'Cyan': Colors.cyan,
  'Orange': Colors.orange,
  'Brown': Colors.brown,
  'Lime': Colors.lime,
  'Teal': Colors.teal,
  'Amber': Colors.amber,
  'Grey': Colors.grey,
};

Color colorFromName(String name) => namedColors[name] ?? Colors.black;

const List<String> _defaultHomeSectionOrder = <String>[
  'Hero Banner',
  'Movies by Country',
  'Shows by Country',
  'New Albums',
  "This Week's Top 10 Movies",
  "This Week's Top 10 Shows",
  "This Week's Top 10 Albums",
  "This Week's Top 10 Songs",
  "This Week's Top 10 Actors",
  "This Week's Top 10 Actresses",
  "This Week's Top 10 Singers",
  "This Week's Top 10 Bands",
  'Ranking of All Top 10s',
  'Recommendations & Mood',
  'Franchise Progress',
  'Channels',
  'Friends Stories',
  'Storage Progress',
  'Continue Watching',
  'Themed Episodes',
  'You Might Also Like',
  'Collections',
  'Because You Watched',
  'People & Cast Recommendations',
  'Library Recommendations',
  'Friends & Communities',
  'Recently Watched',
  'Movies',
  'TV Shows',
  'New Additions',
  'All Library',
  'Music & Film',
  'Seasonal Collections',
  'Media Intelligence Tools',
];

const Map<String, String> _legacyHomeSectionAliases = <String, String>{
  'International Movies': 'Movies by Country',
  'International Shows': 'Shows by Country',
  'Recommended': 'Library Recommendations',
  'Recommendations': 'Library Recommendations',
  'Recently Added': 'New Additions',
  'Friends & Community': 'Friends & Communities',
  'Music': 'Music & Film',
  'Popular': 'Library Recommendations',
};

/// Implements the `HomeCustomization` class for this feature or UI component.
class HomeCustomization {
  bool showHero;
  bool showContinueWatching;
  bool showRecentlyWatched;
  bool showMovies;
  bool showTvShows;
  bool showNewAdditions;
  bool showAllLibrary;
  bool showRecommendations;
  bool showMusic;
  bool showFilm;
  bool showSeasonalCollections;
  bool showFriendsCommunity;
  String homeMediaLayout;
  String heroStyle;
  String cardSize;
  int heroItemCount;
  String navbarPosition;
  String storageBarPosition;
  double storageBarThickness;
  String homeBackgroundColor;
  String navbarColor;
  String navbarGlowColor;
  String navbarItemColor;
  String navbarStyle;
  double navbarOpacity;
  double navbarRadius;
  List<String> sectionOrder;
  List<String> navigationOrder;
  List<String> hiddenSections;

  HomeCustomization({
    this.showHero = true,
    this.showContinueWatching = true,
    this.showRecentlyWatched = true,
    this.showMovies = true,
    this.showTvShows = true,
    this.showNewAdditions = true,
    this.showAllLibrary = false,
    this.showRecommendations = true,
    this.showMusic = true,
    this.showFilm = true,
    this.showSeasonalCollections = true,
    this.showFriendsCommunity = true,
    this.homeMediaLayout = 'Left & Right',
    this.heroStyle = 'Cinematic',
    this.cardSize = 'Medium',
    this.heroItemCount = 8,
    this.navbarPosition = 'Bottom',
    this.storageBarPosition = 'Bottom',
    this.storageBarThickness = 12,
    this.homeBackgroundColor = 'Black',
    this.navbarColor = 'Black',
    this.navbarGlowColor = 'Red',
    this.navbarItemColor = 'Purple',
    this.navbarStyle = 'Solid',
    this.navbarOpacity = 0.95,
    this.navbarRadius = 24,
    List<String>? sectionOrder,
    List<String>? navigationOrder,
    List<String>? hiddenSections,
  })  : sectionOrder = sectionOrder ?? List<String>.from(_defaultHomeSectionOrder),
        hiddenSections = hiddenSections ?? <String>[],
        navigationOrder = navigationOrder ??
            [
              'Profile',
              'Home',
              'Surprise Me',
              'More',
              'Music',
              'Film',
              'Collections',
            ];

  bool isSectionVisible(String section) {
    if (hiddenSections.contains(section)) return false;
    return switch (section) {
      'Hero Banner' => showHero,
      'Continue Watching' => showContinueWatching,
      'Recently Watched' => showRecentlyWatched,
      'Movies' => showMovies,
      'TV Shows' => showTvShows,
      'New Additions' => showNewAdditions,
      'All Library' => showAllLibrary,
      'Library Recommendations' => showRecommendations,
      'Storage Progress' => storageBarPosition != 'Hidden',
      'Friends & Communities' => showFriendsCommunity,
      'Music & Film' => showMusic,
      'Seasonal Collections' => showSeasonalCollections,
      _ => true,
    };
  }

  void setSectionVisible(String section, bool visible) {
    if (visible) {
      hiddenSections.remove(section);
    } else if (!hiddenSections.contains(section)) {
      hiddenSections.add(section);
    }
    switch (section) {
      case 'Hero Banner': showHero = visible;
      case 'Continue Watching': showContinueWatching = visible;
      case 'Recently Watched': showRecentlyWatched = visible;
      case 'Movies': showMovies = visible;
      case 'TV Shows': showTvShows = visible;
      case 'New Additions': showNewAdditions = visible;
      case 'All Library': showAllLibrary = visible;
      case 'Library Recommendations': showRecommendations = visible;
      case 'Storage Progress':
        storageBarPosition = visible ? 'Bottom' : 'Hidden';
      case 'Friends & Communities': showFriendsCommunity = visible;
      case 'Music & Film': showMusic = visible;
      case 'Seasonal Collections': showSeasonalCollections = visible;
    }
  }

  HomeCustomization copy() => HomeCustomization(
        showHero: showHero,
        showContinueWatching: showContinueWatching,
        showRecentlyWatched: showRecentlyWatched,
        showMovies: showMovies,
        showTvShows: showTvShows,
        showNewAdditions: showNewAdditions,
        showAllLibrary: showAllLibrary,
        showRecommendations: showRecommendations,
        showMusic: showMusic,
        showFilm: showFilm,
        showSeasonalCollections: showSeasonalCollections,
        showFriendsCommunity: showFriendsCommunity,
        homeMediaLayout: homeMediaLayout,
        heroStyle: heroStyle,
        cardSize: cardSize,
        heroItemCount: heroItemCount,
        navbarPosition: navbarPosition,
        storageBarPosition: storageBarPosition,
        storageBarThickness: storageBarThickness,
        homeBackgroundColor: homeBackgroundColor,
        navbarColor: navbarColor,
        navbarGlowColor: navbarGlowColor,
        navbarItemColor: navbarItemColor,
        navbarStyle: navbarStyle,
        navbarOpacity: navbarOpacity,
        navbarRadius: navbarRadius,
        sectionOrder: List<String>.from(sectionOrder),
        navigationOrder: List<String>.from(navigationOrder),
        hiddenSections: List<String>.from(hiddenSections),
      );
}

/// Implements the `HomeCustomizationStore` class for this feature or UI component.
class HomeCustomizationStore {
  HomeCustomizationStore._();

  static final Map<String, HomeCustomization> _settings =
      <String, HomeCustomization>{};
  static final Set<String> _configuredProfiles = <String>{};
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);
  static SharedPreferences? _prefs;

  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    const settingsPrefix = 'home_customization_';
    const setupPrefix = 'profile_setup_completed_';
    for (final key in _prefs!.getKeys()) {
      if (key.startsWith(settingsPrefix)) {
        final raw = _prefs!.getString(key);
        if (raw == null) continue;
        try {
          final settings = _fromJson(
            Map<String, dynamic>.from(jsonDecode(raw) as Map),
          );
          if (!settings.sectionOrder.contains('Music & Film')) {
            settings.sectionOrder.add('Music & Film');
          }
          if (!settings.sectionOrder.contains('Friends & Communities')) {
            settings.sectionOrder.insert(0, 'Friends & Communities');
          }
          settings.navigationOrder.removeWhere(
            (item) =>
                item == 'Group Chat' ||
                item == 'Discover' ||
                item == 'My TV' ||
                item == 'Shop',
          );
          if (!settings.navigationOrder.contains('Surprise Me')) {
            final moreIndex = settings.navigationOrder.indexOf('More');
            if (moreIndex >= 0) {
              settings.navigationOrder.insert(moreIndex, 'Surprise Me');
            } else {
              settings.navigationOrder.add('Surprise Me');
            }
          }
          _settings[key.substring(settingsPrefix.length)] = settings;
        } catch (_) {}
      } else if (key.startsWith(setupPrefix) && _prefs!.getBool(key) == true) {
        _configuredProfiles.add(key.substring(setupPrefix.length));
      }
    }
  }

  static String _key(Profile? profile) => profile?.id ?? 'default';

  static HomeCustomization settingsFor(Profile? profile) {
    final value =
        _settings.putIfAbsent(_key(profile), () => HomeCustomization());
    value.navigationOrder.removeWhere(
      (item) =>
          item == 'Group Chat' ||
          item == 'Discover' ||
          item == 'My TV' ||
          item == 'Shop',
    );
    if (!value.navigationOrder.contains('Surprise Me')) {
      final moreIndex = value.navigationOrder.indexOf('More');
      if (moreIndex >= 0) {
        value.navigationOrder.insert(moreIndex, 'Surprise Me');
      } else {
        value.navigationOrder.add('Surprise Me');
      }
    }
    return value.copy();
  }

  static HomeCustomization get settings =>
      settingsFor(AppController.instance.currentProfile);

  static Map<String, dynamic> snapshotFor(Profile? profile) {
    return _toJson(settingsFor(profile));
  }

  static bool isConfigured(Profile? profile) =>
      _configuredProfiles.contains(_key(profile));
  static bool get hasConfigured =>
      isConfigured(AppController.instance.currentProfile);

  static void apply(HomeCustomization value, [Profile? profile]) {
    final key = _key(profile ?? AppController.instance.currentProfile);
    final copy = value.copy();
    copy.navigationOrder.removeWhere(
      (item) =>
          item == 'Group Chat' ||
          item == 'Discover' ||
          item == 'My TV' ||
          item == 'Shop',
    );
    _settings[key] = copy;
    _prefs?.setString('home_customization_$key', jsonEncode(_toJson(copy)));
    revision.value++;
  }

  static Future<void> markSetupCompleted([Profile? profile]) async {
    final key = _key(profile ?? AppController.instance.currentProfile);
    _configuredProfiles.add(key);
    await _prefs?.setBool('profile_setup_completed_$key', true);
  }

  static Future<void> clearSetupCompleted([Profile? profile]) async {
    final key = _key(profile ?? AppController.instance.currentProfile);
    _configuredProfiles.remove(key);
    await _prefs?.remove('profile_setup_completed_$key');
  }

  static void removeProfile(Profile profile) {
    _settings.remove(profile.id);
    _configuredProfiles.remove(profile.id);
    _prefs?.remove('home_customization_${profile.id}');
    _prefs?.remove('profile_setup_completed_${profile.id}');
  }

  static void clear() {
    for (final key in _settings.keys) {
      _prefs?.remove('home_customization_$key');
    }
    for (final key in _configuredProfiles) {
      _prefs?.remove('profile_setup_completed_$key');
    }
    _settings.clear();
    _configuredProfiles.clear();
    revision.value++;
  }

  static List<String> _normalizeSectionOrder(dynamic raw) {
    if (raw is! List) return List<String>.from(_defaultHomeSectionOrder);
    final supported = _defaultHomeSectionOrder.toSet();
    final result = <String>[];
    for (final value in raw) {
      final oldName = value.toString();
      final name = _legacyHomeSectionAliases[oldName] ?? oldName;
      if (supported.contains(name) && !result.contains(name)) result.add(name);
    }
    // Keep the hero first for older saved profiles that never stored it as a
    // section. Insert newly introduced sections by their canonical position
    // relative to existing sections, while preserving the user's saved order
    // among all sections they had already customized.
    if (!result.contains('Hero Banner')) result.insert(0, 'Hero Banner');
    for (final name in _defaultHomeSectionOrder) {
      if (result.contains(name)) continue;
      final rank = _defaultHomeSectionOrder.indexOf(name);
      var insertAt = result.length;
      for (var index = 0; index < result.length; index++) {
        final existingRank = _defaultHomeSectionOrder.indexOf(result[index]);
        if (existingRank > rank) {
          insertAt = index;
          break;
        }
      }
      result.insert(insertAt, name);
    }
    return result;
  }

  static List<String> _normalizeHiddenSections(dynamic raw) {
    if (raw is! List) return <String>[];
    final supported = _defaultHomeSectionOrder.toSet();
    return raw
        .map((value) => value.toString())
        // These were standalone promotional shelves, not country shelves.
        // Do not migrate their old hidden state onto the replacement country
        // shelves, or users with an older profile will never see US/other
        // country sections after updating.
        .where((oldName) =>
            oldName != 'International Movies' &&
            oldName != 'International Shows')
        .map((oldName) => _legacyHomeSectionAliases[oldName] ?? oldName)
        .where(supported.contains)
        .toSet()
        .toList();
  }

  static Map<String, dynamic> _toJson(HomeCustomization v) => {
        'showHero': v.showHero,
        'showContinueWatching': v.showContinueWatching,
        'showRecentlyWatched': v.showRecentlyWatched,
        'showMovies': v.showMovies,
        'showTvShows': v.showTvShows,
        'showNewAdditions': v.showNewAdditions,
        'showAllLibrary': v.showAllLibrary,
        'showRecommendations': v.showRecommendations,
        'showMusic': v.showMusic,
        'showFilm': v.showFilm,
        'showSeasonalCollections': v.showSeasonalCollections,
        'showFriendsCommunity': v.showFriendsCommunity,
        'homeMediaLayout': v.homeMediaLayout,
        'heroStyle': v.heroStyle,
        'cardSize': v.cardSize,
        'heroItemCount': v.heroItemCount,
        'navbarPosition': v.navbarPosition,
        'storageBarPosition': v.storageBarPosition,
        'storageBarThickness': v.storageBarThickness,
        'homeBackgroundColor': v.homeBackgroundColor,
        'navbarColor': v.navbarColor,
        'navbarGlowColor': v.navbarGlowColor,
        'navbarItemColor': v.navbarItemColor,
        'navbarStyle': v.navbarStyle,
        'navbarOpacity': v.navbarOpacity,
        'navbarRadius': v.navbarRadius,
        'sectionOrder': v.sectionOrder,
        'navigationOrder': v.navigationOrder,
        'hiddenSections': v.hiddenSections,
      };

  static String _colorNameFromStored(dynamic value, String fallback) {
    final stored = value?.toString();
    if (stored != null && namedColors.containsKey(stored)) return stored;

    // Convert older saved hex values to the new friendly color names.
    const legacy = <String, String>{
      '0xFF090909': 'Black',
      '0xFF0E0E0E': 'Black',
      '0xFFFF0000': 'Red',
      '0xFF8B5CF6': 'Purple',
      '0xFF0B2B17': 'Green',
      '0xFF071A33': 'Blue',
      '0xFF2B0B2B': 'Maroon',
      '0xFF1E3A8A': 'Blue',
      '0xFF14532D': 'Green',
      '0xFF4C1D95': 'Purple',
      '0xFF00FF66': 'Green',
      '0xFF00B7FF': 'Cyan',
      '0xFFFF00FF': 'Fuchsia',
      '0xFFFFFFFF': 'White',
      '0xFFFFC107': 'Amber',
      '0xFF22D3EE': 'Cyan',
    };
    return legacy[stored] ?? fallback;
  }

  static HomeCustomization _fromJson(Map<String, dynamic> m) =>
      HomeCustomization(
        showHero: m['showHero'] == false ? false : true,
        showContinueWatching: m['showContinueWatching'] == false ? false : true,
        showRecentlyWatched: m['showRecentlyWatched'] == false ? false : true,
        showMovies: m['showMovies'] == false ? false : true,
        showTvShows: m['showTvShows'] == false ? false : true,
        showNewAdditions: m['showNewAdditions'] == false ? false : true,
        showAllLibrary: m['showAllLibrary'] == true,
        showRecommendations: m['showRecommendations'] == false ? false : true,
        showMusic: m['showMusic'] == false ? false : true,
        showFilm: m['showFilm'] == false ? false : true,
        showSeasonalCollections:
            m['showSeasonalCollections'] == false ? false : true,
        showFriendsCommunity: m['showFriendsCommunity'] == false ? false : true,
        homeMediaLayout: m['homeMediaLayout']?.toString() == 'Top & Bottom'
            ? 'Under Banner'
            : (m['homeMediaLayout']?.toString() ?? 'Left & Right'),
        heroStyle: m['heroStyle']?.toString() ?? 'Cinematic',
        cardSize: m['cardSize']?.toString() ?? 'Medium',
        heroItemCount: ((m['heroItemCount'] as num?)?.toInt() ?? 8).clamp(1, 40).toInt(),
        navbarPosition: m['navbarPosition']?.toString() ?? 'Bottom',
        storageBarPosition: m['storageBarPosition']?.toString() ?? 'Bottom',
        storageBarThickness: (m['storageBarThickness'] is num
            ? (m['storageBarThickness'] as num).toDouble()
            : 12),
        homeBackgroundColor:
            _colorNameFromStored(m['homeBackgroundColor'], 'Black'),
        navbarColor: _colorNameFromStored(m['navbarColor'], 'Black'),
        navbarGlowColor: _colorNameFromStored(m['navbarGlowColor'], 'Red'),
        navbarItemColor: _colorNameFromStored(m['navbarItemColor'], 'Purple'),
        navbarStyle: m['navbarStyle']?.toString() ?? 'Solid',
        navbarOpacity: (m['navbarOpacity'] as num?)?.toDouble() ?? 0.95,
        navbarRadius: (m['navbarRadius'] as num?)?.toDouble() ?? 24,
        sectionOrder: _normalizeSectionOrder(m['sectionOrder']),
        hiddenSections: _normalizeHiddenSections(m['hiddenSections']),
        navigationOrder: m['navigationOrder'] is List
            ? List<String>.from(m['navigationOrder'] as List)
                .where((item) => <String>{
                      'Home',
                      'Profile',
                      'Surprise Me',
                      'More',
                      'Music',
                      'Film',
                      'Collections',
                      'Movies',
                      'TV Shows',
                      'Friends',
                      'Library',
                    }.contains(item))
                .toList()
            : null,
      );
}

enum CustomizationPage {
  home,
  details,
  music,
}

enum _PreviewDeviceCategory {
  phone,
  tablet,
  desktop,
  tv,
}

class _PreviewDevicePreset {
  final String name;
  final _PreviewDeviceCategory category;
  final double width;
  final double height;
  final IconData icon;
  final bool landscape;

  const _PreviewDevicePreset({
    required this.name,
    required this.category,
    required this.width,
    required this.height,
    required this.icon,
    this.landscape = false,
  });
}

const _previewDevices = <_PreviewDevicePreset>[
  _PreviewDevicePreset(
      name: 'iPhone',
      category: _PreviewDeviceCategory.phone,
      width: 390,
      height: 844,
      icon: Icons.phone_iphone_rounded),
  _PreviewDevicePreset(
      name: 'Samsung Galaxy',
      category: _PreviewDeviceCategory.phone,
      width: 412,
      height: 915,
      icon: Icons.phone_android_rounded),
  _PreviewDevicePreset(
      name: 'Android Phone',
      category: _PreviewDeviceCategory.phone,
      width: 412,
      height: 892,
      icon: Icons.android_rounded),
  _PreviewDevicePreset(
      name: 'LG Phone',
      category: _PreviewDeviceCategory.phone,
      width: 393,
      height: 873,
      icon: Icons.phone_android_rounded),
  _PreviewDevicePreset(
      name: 'iPad',
      category: _PreviewDeviceCategory.tablet,
      width: 820,
      height: 1180,
      icon: Icons.tablet_mac_rounded),
  _PreviewDevicePreset(
      name: 'iPad Pro',
      category: _PreviewDeviceCategory.tablet,
      width: 1024,
      height: 1366,
      icon: Icons.tablet_mac_rounded),
  _PreviewDevicePreset(
      name: 'Android Tablet',
      category: _PreviewDeviceCategory.tablet,
      width: 800,
      height: 1280,
      icon: Icons.tablet_android_rounded),
  _PreviewDevicePreset(
      name: 'Windows PC',
      category: _PreviewDeviceCategory.desktop,
      width: 1440,
      height: 900,
      icon: Icons.desktop_windows_rounded),
  _PreviewDevicePreset(
      name: 'Mac',
      category: _PreviewDeviceCategory.desktop,
      width: 1440,
      height: 900,
      icon: Icons.desktop_mac_rounded),
  _PreviewDevicePreset(
      name: 'Laptop',
      category: _PreviewDeviceCategory.desktop,
      width: 1366,
      height: 768,
      icon: Icons.laptop_mac_rounded),
  _PreviewDevicePreset(
      name: 'Smart TV',
      category: _PreviewDeviceCategory.tv,
      width: 1920,
      height: 1080,
      icon: Icons.tv_rounded,
      landscape: true),
  _PreviewDevicePreset(
      name: '4K TV',
      category: _PreviewDeviceCategory.tv,
      width: 3840,
      height: 2160,
      icon: Icons.tv_rounded,
      landscape: true),
  _PreviewDevicePreset(
      name: 'TV / Large Display',
      category: _PreviewDeviceCategory.tv,
      width: 1280,
      height: 720,
      icon: Icons.connected_tv_rounded,
      landscape: true),
];

/// Implements the `CustomizeHomeScreen` class for this feature or UI component.
class CustomizeHomeScreen extends StatefulWidget {
  final bool firstSetup;
  final CustomizationPage? lockedPage;

  const CustomizeHomeScreen({
    super.key,
    this.firstSetup = false,
    this.lockedPage,
  });

  @override
  State<CustomizeHomeScreen> createState() => _CustomizeHomeScreenState();
}

/// Implements the `_CustomizeHomeScreenState` class for this feature or UI component.
class _CustomizeHomeScreenState extends State<CustomizeHomeScreen> {
  late HomeCustomization draft;
  late DetailsCustomization detailsDraft;
  late MusicPageCustomization musicDraft;
  PageHeroSettings _homeHeroSettings = const PageHeroSettings();
  late CustomizationPage selectedPage;
  bool detailsPreviewTvShow = true;
  _PreviewDeviceCategory _previewCategory = _PreviewDeviceCategory.phone;
  String _previewDeviceName = 'iPhone';
  String storyPlacement = 'friends';

  // Prevent repeated taps while an async save/navigation operation is in
  // progress. This avoids Flutter Navigator's !_debugLocked assertion.
  bool _isSaving = false;

  // Home and Details share one scrollable customization page. Resetting this
  // controller when the page changes guarantees the next customization
  // section always opens at its top.
  final ScrollController _customizationScrollController = ScrollController();
  @override

  /// Performs `initState` for this feature. Update this documentation when its contract changes.
  void initState() {
    super.initState();
    selectedPage = widget.lockedPage ?? CustomizationPage.home;
    draft = HomeCustomizationStore.settingsFor(
        AppController.instance.currentProfile);
    detailsDraft = DetailsCustomizationStore.settingsFor(
      AppController.instance.currentProfile,
    );
    musicDraft = MusicPageCustomizationStore.settingsFor(
      AppController.instance.currentProfile,
    );
    unawaited(_loadHomeHeroSettings());
    storyPlacement =
        StoryPlacementStore.forProfile(AppController.instance.currentProfile);
    unawaited(_loadStoryPlacementPreference());
    _normalizeHomePositions();
  }

  Future<void> _loadHomeHeroSettings() async {
    final loaded = await PageHeroSettingsStore.load('home');
    if (!mounted) return;
    setState(() {
      _homeHeroSettings = loaded;
      draft.heroItemCount = loaded.itemCount;
    });
  }

  Future<void> _loadStoryPlacementPreference() async {
    await StoryPlacementStore.load(AppController.instance.currentProfile);
    if (mounted) {
      setState(() {
        storyPlacement = StoryPlacementStore.forProfile(
            AppController.instance.currentProfile);
      });
    }
  }

  void _normalizeHomePositions() {
    // All three edge controls may intentionally share the same side. The Home
    // layout distributes 2 items as outer slots and 3 items as left/center/right
    // (or top/middle/bottom) slots, so do not move saved positions here.
    const positions = <String>{'Top', 'Bottom', 'Left', 'Right'};
    if (!positions.contains(draft.navbarPosition) &&
        draft.navbarPosition != 'Floating') {
      draft.navbarPosition = 'Bottom';
    }
    if (!positions.contains(draft.storageBarPosition) &&
        draft.storageBarPosition != 'Hidden') {
      draft.storageBarPosition = 'Bottom';
    }
  }

  /// Performs `_save` for this feature. Update this documentation when its contract changes.
  Future<void> _save() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    final profile = AppController.instance.currentProfile;
    await StoryPlacementStore.setForProfile(profile, storyPlacement);
    if (selectedPage == CustomizationPage.home) {
      draft.heroItemCount = _homeHeroSettings.itemCount;
      await PageHeroSettingsStore.save('home', _homeHeroSettings);
    }

    // First setup is a strict forward-only sequence: Home -> Details -> Music.
    // Each step saves before advancing, so a crash or app
    // restart cannot silently discard the completed customization.
    if (widget.firstSetup) {
      if (selectedPage == CustomizationPage.home) {
        HomeCustomizationStore.apply(draft, profile);
        await _syncCustomization(profile);
        if (!mounted) return;
        setState(() => selectedPage = CustomizationPage.details);
        _resetCustomizationScroll();
        if (mounted) setState(() => _isSaving = false);
        return;
      }

      if (selectedPage == CustomizationPage.details) {
        DetailsCustomizationStore.apply(profile, detailsDraft);
        await _syncCustomization(profile);
        if (!mounted) return;
        setState(() => selectedPage = CustomizationPage.music);
        _resetCustomizationScroll();
        if (mounted) setState(() => _isSaving = false);
        return;
      }

      // Music completes the first-time profile setup. The completion flag is
      // stored per profile so returning to the app will not reopen customization.
      MusicPageCustomizationStore.apply(profile, musicDraft);
      HomeCustomizationStore.apply(draft, profile);
      DetailsCustomizationStore.apply(profile, detailsDraft);
      await _syncCustomization(profile);
      await HomeCustomizationStore.markSetupCompleted(profile);

      if (!mounted) return;
      // The profile is now fully customized, so go directly to Home. Account
      // invitations remain available later from the More (three-dot) menu.
      if (mounted) setState(() => _isSaving = false);
      await _enterMainHome();
      return;
    }

    if (widget.lockedPage == CustomizationPage.home) {
      HomeCustomizationStore.apply(draft, profile);
    } else if (widget.lockedPage == CustomizationPage.details) {
      DetailsCustomizationStore.apply(profile, detailsDraft);
    } else if (widget.lockedPage == CustomizationPage.music) {
      MusicPageCustomizationStore.apply(profile, musicDraft);
    } else {
      HomeCustomizationStore.apply(draft, profile);
      DetailsCustomizationStore.apply(profile, detailsDraft);
      MusicPageCustomizationStore.apply(profile, musicDraft);
    }

    await _syncCustomization(profile);

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _syncCustomization(Profile? profile) async {
    if (profile == null || !AppController.instance.backendApi.isAuthenticated) {
      return;
    }
    try {
      await AppController.instance.backendApi
          .syncProfileCustomizationToSupabase(
        profileId: profile.id,
        home: HomeCustomizationStore.snapshotFor(profile),
        details: DetailsCustomizationStore.snapshotFor(profile),
        platform: PlatformPreferenceStore.snapshot(),
        music: MusicPageCustomizationStore.snapshotFor(profile),
      );
    } catch (_) {
      // Local settings remain usable if Supabase is temporarily unavailable.
    }
  }

  void _resetCustomizationScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_customizationScrollController.hasClients) return;
      _customizationScrollController.jumpTo(0);
    });
  }

  void _selectCustomizationPage(CustomizationPage page) {
    if (_isSaving || selectedPage == page) return;

    setState(() {
      selectedPage = page;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_customizationScrollController.hasClients) return;
      _customizationScrollController.jumpTo(0);
    });
  }

  @override
  void dispose() {
    _customizationScrollController.dispose();
    super.dispose();
  }

  /// Performs `_toggle` for this feature. Update this documentation when its contract changes.
  Widget _toggle(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .045),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .06)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: SwitchListTile.adaptive(
          tileColor: Colors.transparent,
          value: value,
          onChanged: onChanged,
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(color: Colors.white54),
          ),
          activeThumbColor: Colors.redAccent,
        ),
      ),
    );
  }

  /// Performs `_dropdown` for this feature. Update this documentation when its contract changes.
  Widget _dropdown({
    required String label,
    required String value,
    required List<String> values,
    List<String>? labels,
    required ValueChanged<String> onChanged,
  }) {
    final safeValue = values.contains(value) ? value : values.first;

    return DropdownButtonFormField<String>(
      initialValue: safeValue,
      decoration: InputDecoration(labelText: label),
      items: [
        for (var index = 0; index < values.length; index++)
          DropdownMenuItem<String>(
            value: values[index],
            child: Text(labels != null && index < labels.length
                ? labels[index]
                : values[index]),
          ),
      ],
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }

  Widget _colorDropdown({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    final safeValue = namedColors.containsKey(value) ? value : 'Black';

    return DropdownButtonFormField<String>(
      initialValue: safeValue,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: namedColors[safeValue],
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
          ),
        ),
      ),
      items: [
        for (final entry in namedColors.entries)
          DropdownMenuItem<String>(
            value: entry.key,
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: entry.value,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                ),
                const SizedBox(width: 12),
                Text(entry.key),
              ],
            ),
          ),
      ],
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }

  /// Performs `_pageSelector` for this feature. Update this documentation when its contract changes.
  Widget _pageSelector() {
    return Row(
      children: [
        Expanded(
          child: _customizationButton(
            label: 'HOME PAGE',
            icon: Icons.home_rounded,
            selected: selectedPage == CustomizationPage.home,
            onPressed: widget.firstSetup
                ? null
                : () => _selectCustomizationPage(CustomizationPage.home),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _customizationButton(
            label: 'DETAILS PAGE',
            icon: Icons.movie_outlined,
            selected: selectedPage == CustomizationPage.details,
            onPressed: widget.firstSetup
                ? null
                : () => _selectCustomizationPage(CustomizationPage.details),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _customizationButton(
            label: 'MUSIC PAGE',
            icon: Icons.music_note_rounded,
            selected: selectedPage == CustomizationPage.music,
            onPressed: widget.firstSetup
                ? (selectedPage == CustomizationPage.music
                    ? null
                    : () => _selectCustomizationPage(CustomizationPage.music))
                : () => _selectCustomizationPage(CustomizationPage.music),
          ),
        ),
      ],
    );
  }

  /// Performs `_customizationButton` for this feature. Update this documentation when its contract changes.
  Widget _customizationButton({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 52,
      child: selected
          ? ElevatedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
    );
  }

  /// Performs `_headerCard` for this feature. Update this documentation when its contract changes.
  Widget _headerCard() {
    final isHome = selectedPage == CustomizationPage.home;
    final isMusic = selectedPage == CustomizationPage.music;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          colors: [
            Colors.red.withValues(alpha: .22),
            const Color(0xFF171717),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isHome
                ? Icons.home_rounded
                : isMusic
                    ? Icons.music_note_rounded
                    : Icons.movie_outlined,
            color: Colors.redAccent,
            size: 30,
          ),
          const SizedBox(height: 12),
          Text(
            isHome
                ? (widget.firstSetup
                    ? 'How do you want your main screen to look?'
                    : 'Build your Home screen your way.')
                : isMusic
                    ? 'Build your Music page your way.'
                    : 'Build your Details page your way.',
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w900,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isHome
                ? 'Choose what appears, change the presentation, and drag Home sections into the order you want.'
                : isMusic
                    ? 'Choose discovery sections, the persistent player, Spotify-inspired mixes, and the order of your Music page.'
                    : 'Choose which Details sections appear, control metadata and poster presentation, and drag sections into the order you want.',
            style: const TextStyle(
              color: Colors.white60,
              height: 1.45,
            ),
          ),
          if (!isHome && !isMusic) ...[
            const SizedBox(height: 12),
            UniversalText(
              'Profile: ${AppController.instance.currentProfile?.name ?? 'No profile selected'}',
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const UniversalText(
              'These Details settings belong only to the currently selected profile.',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  /// Performs `_buildHomePage` for this feature. Update this documentation when its contract changes.
  Widget _buildHomePage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const UniversalText(
          'PRESENTATION',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 10),
        _dropdown(
          label: 'Hero style',
          value: draft.heroStyle,
          values: const ['Cinematic', 'Minimal', 'Compact'],
          onChanged: (value) => setState(() => draft.heroStyle = value),
        ),
        const SizedBox(height: 12),
        _dropdown(
          label: 'Media card size',
          value: draft.cardSize,
          values: const ['Small', 'Medium', 'Large'],
          onChanged: (value) => setState(() => draft.cardSize = value),
        ),
        const SizedBox(height: 12),
        PageHeroSettingsPanel(
          pageTitle: 'Home',
          settings: _homeHeroSettings,
          onChanged: (value) => setState(() {
            _homeHeroSettings = value;
            draft.heroItemCount = value.itemCount;
          }),
        ),
        const SizedBox(height: 12),
        _dropdown(
          label: 'Navigation bar position',
          value: draft.navbarPosition,
          values: const ['Bottom', 'Top', 'Left', 'Right'],
          onChanged: (value) => setState(() {
            draft.navbarPosition = value;
            HomeCustomizationStore.apply(draft, AppController.instance.currentProfile);
          }),
        ),
        const SizedBox(height: 24),
        const UniversalText('COLORS',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
                color: Colors.white54)),
        const SizedBox(height: 10),
        _colorDropdown(
          label: 'Home background',
          value: draft.homeBackgroundColor,
          onChanged: (value) =>
              setState(() => draft.homeBackgroundColor = value),
        ),
        const SizedBox(height: 24),
        const UniversalText('HOME MEDIA',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
                color: Colors.white54)),
        const SizedBox(height: 10),
        _dropdown(
          label: 'Music & Film placement',
          value: draft.homeMediaLayout,
          values: const ['Left & Right', 'Under Banner'],
          onChanged: (value) => setState(() => draft.homeMediaLayout = value),
        ),
        _toggle('Music', 'Show a Music destination on Home.', draft.showMusic,
            (v) => setState(() => draft.showMusic = v)),
        _toggle('Film', 'Show the dedicated Film experience on Home.',
            draft.showFilm, (v) => setState(() => draft.showFilm = v)),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.collections_bookmark_outlined),
          title: UniversalText('Collections'),
          subtitle: UniversalText(
            'Configure the Collections shelf under Home section visibility.',
          ),
        ),
        const SizedBox(height: 24),
        const UniversalText(
          'HOME SECTIONS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 10),
        const UniversalText(
          'HOME SECTION VISIBILITY',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 10),
        for (final section in draft.sectionOrder)
          _toggle(
            section,
            _homeSectionDescription(section),
            section == 'Friends Stories'
                ? (storyPlacement == 'home' || storyPlacement == 'both')
                : draft.isSectionVisible(section),
            (visible) => setState(() {
              draft.setSectionVisible(section, visible);
              if (section == 'Friends Stories') {
                if (visible) {
                  if (storyPlacement == 'none') storyPlacement = 'home';
                  if (storyPlacement == 'friends') storyPlacement = 'both';
                } else {
                  if (storyPlacement == 'both') storyPlacement = 'friends';
                  if (storyPlacement == 'home') storyPlacement = 'none';
                }
              }
            }),
          ),
        const SizedBox(height: 24),
        const UniversalText(
          'FRIENDS STORIES',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 10),
        _dropdown(
          label: 'Show friends’ Stories',
          value: storyPlacement,
          values: const ['none', 'home', 'friends', 'both'],
          labels: const [
            "Don't show",
            'Home only',
            'Friends only',
            'Home + Friends'
          ],
          onChanged: (value) => setState(() {
            storyPlacement = value;
            final showOnHome = value == 'home' || value == 'both';
            draft.setSectionVisible('Friends Stories', showOnHome);
          }),
        ),
        const SizedBox(height: 24),
        _sectionOrder(
          title: tr('SECTION ORDER'),
          subtitle: tr('Drag Home sections to change their order.'),
          items: draft.sectionOrder,
        ),
      ],
    );
  }

  /// Builds the Music customization controls. This page is available from
  /// Contextual customization is opened from the current page rather than forced during sign-in.
  Widget _buildMusicPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const UniversalText(
          'MUSIC PRESENTATION',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 10),
        _dropdown(
          label: 'Music card style',
          value: musicDraft.cardStyle,
          values: const ['Comfortable', 'Compact', 'Large'],
          onChanged: (value) => setState(() => musicDraft.cardStyle = value),
        ),
        const SizedBox(height: 12),
        _dropdown(
          label: 'Player style',
          value: musicDraft.playerStyle,
          values: const ['Bottom player', 'Compact'],
          onChanged: (value) => setState(() => musicDraft.playerStyle = value),
        ),
        const SizedBox(height: 22),
        const UniversalText(
          'DISCOVERY & PLAYER',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 10),
        _toggle('Search bar', 'Show Music search.', musicDraft.showSearch,
            (v) => setState(() => musicDraft.showSearch = v)),
        _toggle(
            'Player',
            'Show the persistent player and queue.',
            musicDraft.showPlayer,
            (v) => setState(() => musicDraft.showPlayer = v)),
        _toggle(
            'Weekly Discovery',
            'Show the weekly discovery mix.',
            musicDraft.showWeeklyDiscovery,
            (v) => setState(() => musicDraft.showWeeklyDiscovery = v)),
        _toggle('AI DJ', 'Show the AI DJ launcher.', musicDraft.showAIDJ,
            (v) => setState(() => musicDraft.showAIDJ = v)),
        _toggle(
            'System-created playlists',
            'Show Made For You, Discover Weekly and Daily Mix.',
            musicDraft.showSystemPlaylists,
            (v) => setState(() => musicDraft.showSystemPlaylists = v)),
        _toggle(
            'Liked Songs',
            'Show saved favorites.',
            musicDraft.showLikedSongs,
            (v) => setState(() => musicDraft.showLikedSongs = v)),
        _toggle(
            'Recently Played',
            'Show recent listening.',
            musicDraft.showRecentlyPlayed,
            (v) => setState(() => musicDraft.showRecentlyPlayed = v)),
        _toggle(
            'Mood & Genre Mixes',
            'Show quick mixes from imported metadata.',
            musicDraft.showMoodMixes,
            (v) => setState(() => musicDraft.showMoodMixes = v)),
        const SizedBox(height: 22),
        const UniversalText(
          'LIBRARY',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 10),
        _toggle(
            'Artists / Bands',
            'Show singers and bands.',
            musicDraft.showArtists,
            (v) => setState(() => musicDraft.showArtists = v)),
        _toggle('Albums', 'Show ripped albums.', musicDraft.showAlbums,
            (v) => setState(() => musicDraft.showAlbums = v)),
        _toggle('Playlists', 'Show custom playlists.', musicDraft.showPlaylists,
            (v) => setState(() => musicDraft.showPlaylists = v)),
        _toggle(
            'Soundtrack Universe',
            'Connect songs with the films and shows that use them.',
            musicDraft.showSoundtrackUniverse,
            (v) => setState(() => musicDraft.showSoundtrackUniverse = v)),
        const SizedBox(height: 20),
        _sectionOrder(
          title: tr('MUSIC SECTION ORDER'),
          subtitle: tr(
              'Drag discovery, library and soundtrack sections into your preferred order.'),
          items: musicDraft.sectionOrder,
          onChanged: (value) => setState(() => musicDraft.sectionOrder = value),
        ),
      ],
    );
  }

  /// Performs `_buildDetailsPage` for this feature. Update this documentation when its contract changes.
  Widget _buildDetailsPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const UniversalText(
          'DETAILS PRESENTATION',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 10),
        _dropdown(
          label: 'Poster style',
          value: detailsDraft.posterStyle,
          values: const ['Standard', 'Full Screen', 'Compact', 'Side'],
          onChanged: (value) =>
              setState(() => detailsDraft.posterStyle = value),
        ),
        const SizedBox(height: 12),
        _dropdown(
          label: 'Title alignment',
          value: detailsDraft.titleAlignment,
          values: const ['Left', 'Center', 'Right'],
          onChanged: (value) =>
              setState(() => detailsDraft.titleAlignment = value),
        ),
        const SizedBox(height: 12),
        _dropdown(
            label: 'Poster position',
            value: detailsDraft.posterPosition,
            values: const ['Left', 'Center', 'Right'],
            onChanged: (v) => setState(() => detailsDraft.posterPosition = v)),
        const SizedBox(height: 12),
        _dropdown(
            label: 'Poster size',
            value: detailsDraft.posterSize,
            values: const ['Small', 'Medium', 'Large'],
            onChanged: (v) => setState(() => detailsDraft.posterSize = v)),
        const SizedBox(height: 12),
        _dropdown(
            label: 'Button alignment',
            value: detailsDraft.buttonAlignment,
            values: const ['Left', 'Center', 'Right'],
            onChanged: (v) => setState(() => detailsDraft.buttonAlignment = v)),
        const SizedBox(height: 12),
        _dropdown(
            label: 'Information alignment',
            value: detailsDraft.informationAlignment,
            values: const ['Left', 'Center', 'Right'],
            onChanged: (v) =>
                setState(() => detailsDraft.informationAlignment = v)),
        const SizedBox(height: 24),
        const UniversalText(
          'DETAILS SECTIONS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 10),
        _toggle(
          'Poster',
          'Show the poster or artwork.',
          detailsDraft.showPoster,
          (v) => setState(() => detailsDraft.showPoster = v),
        ),
        _toggle(
          'Title',
          'Show the media title.',
          detailsDraft.showTitle,
          (v) => setState(() => detailsDraft.showTitle = v),
        ),
        _toggle(
          'Metadata',
          'Show release year, rating and other metadata.',
          detailsDraft.showMetadata,
          (v) => setState(() => detailsDraft.showMetadata = v),
        ),
        _toggle(
          'Ownership',
          'Show whether the title belongs to your library.',
          detailsDraft.showOwnership,
          (v) => setState(() => detailsDraft.showOwnership = v),
        ),
        _toggle(
          'Description',
          'Show the title description.',
          detailsDraft.showDescription,
          (v) => setState(() => detailsDraft.showDescription = v),
        ),
        _toggle(
          'Seasons',
          'Show the Seasons section for TV shows.',
          detailsDraft.showSeasons,
          (v) => setState(() => detailsDraft.showSeasons = v),
        ),
        _toggle(
          'Play',
          'Show the Play button.',
          detailsDraft.showPlay,
          (v) => setState(() => detailsDraft.showPlay = v),
        ),
        _toggle(
          'Trailer',
          'Show the trailer button when a trailer exists.',
          detailsDraft.showTrailer,
          (v) => setState(() => detailsDraft.showTrailer = v),
        ),
        _toggle(
          'Group Watch',
          'Show Group Watch controls.',
          detailsDraft.showGroupWatch,
          (v) => setState(() => detailsDraft.showGroupWatch = v),
        ),
        _toggle(
          'Audio & Subtitles',
          'Show language and subtitle controls.',
          detailsDraft.showAudioSubtitles,
          (v) => setState(() => detailsDraft.showAudioSubtitles = v),
        ),
        _toggle(
          'Reactions',
          'Show Like and Dislike controls.',
          detailsDraft.showReactions,
          (v) => setState(() => detailsDraft.showReactions = v),
        ),
        _toggle(
          'Information',
          'Show additional information.',
          detailsDraft.showInformation,
          (v) => setState(() => detailsDraft.showInformation = v),
        ),
        _toggle(
          'Library',
          'Show Add/Remove from Library controls.',
          detailsDraft.showLibrary,
          (v) => setState(() => detailsDraft.showLibrary = v),
        ),
        _toggle(
          'Recommendations',
          'Show explainable recommendations based on shared cast, genre, themes, franchise and setting.',
          detailsDraft.showRecommendations,
          (v) => setState(() => detailsDraft.showRecommendations = v),
        ),
        const SizedBox(height: 24),
        const UniversalText(
          'SEASONS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 10),
        _dropdown(
          label: 'Season placement',
          value: detailsDraft.seasonPlacement,
          values: const ['Left', 'Center', 'Right'],
          onChanged: (value) =>
              setState(() => detailsDraft.seasonPlacement = value),
        ),
        const SizedBox(height: 12),
        _dropdown(
          label: 'Season order',
          value: detailsDraft.seasonOrder,
          values: const ['Top to Bottom', 'Bottom to Top'],
          onChanged: (value) =>
              setState(() => detailsDraft.seasonOrder = value),
        ),
        const SizedBox(height: 12),
        _dropdown(
            label: 'Season selector',
            value: detailsDraft.seasonSelectorStyle,
            values: const ['Buttons', 'Dropdown'],
            onChanged: (v) =>
                setState(() => detailsDraft.seasonSelectorStyle = v)),
        const SizedBox(height: 12),
        _dropdown(
            label: 'Episode naming',
            value: detailsDraft.episodeNaming,
            values: const ['Actual Title', 'Season X, Episode Y', 'Both'],
            onChanged: (v) => setState(() => detailsDraft.episodeNaming = v)),
        const SizedBox(height: 24),
        const UniversalText(
          'METADATA',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 10),
        _toggle(
          'Release year',
          'Show the release year in the Details metadata.',
          detailsDraft.showReleaseYear,
          (v) => setState(() => detailsDraft.showReleaseYear = v),
        ),
        _toggle(
          'Rating',
          'Show the title rating.',
          detailsDraft.showRating,
          (v) => setState(() => detailsDraft.showRating = v),
        ),
        _toggle(
          'Content rating',
          'Show the content rating when available.',
          detailsDraft.showContentRating,
          (v) => setState(() => detailsDraft.showContentRating = v),
        ),
        _toggle(
          'Runtime',
          'Show runtime when available.',
          detailsDraft.showRuntime,
          (v) => setState(() => detailsDraft.showRuntime = v),
        ),
        const SizedBox(height: 24),
        _sectionOrder(
          title: tr('DETAILS SECTION ORDER'),
          subtitle: tr('Drag Details sections to change their order.'),
          items: detailsDraft.sectionOrder,
          onChanged: (newOrder) {
            setState(() {
              detailsDraft.sectionOrder = newOrder;
            });
          },
        ),
      ],
    );
  }

  /// Live preview of the actual Home/Details presentation. The Details
  /// preview is a data-free wireframe so the user can see every configurable
  /// section before a title has been ripped/imported. Real ripped media is
  /// rendered by `MediaDetailsScreen` after it exists in the library.
  Widget _customizationPreview() {
    final isHome = selectedPage == CustomizationPage.home;
    final isMusic = selectedPage == CustomizationPage.music;
    final Widget actualPage = isHome
        ? _buildHomeCustomizationPreview()
        : isMusic
            ? _buildMusicCustomizationPreview()
            : _buildDetailsCustomizationPreview();
    final devices = _previewDevices
        .where((device) => device.category == _previewCategory)
        .toList();
    final selectedDevice = devices.firstWhere(
      (device) => device.name == _previewDeviceName,
      orElse: () => devices.first,
    );
    if (_previewDeviceName != selectedDevice.name) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _previewDeviceName != selectedDevice.name) {
          setState(() => _previewDeviceName = selectedDevice.name);
        }
      });
    }

    final isTv = selectedDevice.category == _PreviewDeviceCategory.tv;
    final isPhone = selectedDevice.category == _PreviewDeviceCategory.phone;

    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isHome
                    ? Icons.home_rounded
                    : isMusic
                        ? Icons.music_note_rounded
                        : Icons.movie_outlined,
                color: colorFromName(draft.navbarGlowColor),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: UniversalText(
                  'LIVE DEVICE PREVIEW',
                  style: TextStyle(
                      fontWeight: FontWeight.w900, letterSpacing: 1.2),
                ),
              ),
              Icon(
                isTv ? Icons.settings_remote_rounded : Icons.touch_app_rounded,
                size: 17,
                color: Colors.white54,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _previewCategorySelector(),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: selectedDevice.name,
            decoration: InputDecoration(
              labelText: tr('Device / Screen'),
              prefixIcon: Icon(Icons.devices_other_rounded),
              border: OutlineInputBorder(),
            ),
            items: devices
                .map((device) => DropdownMenuItem<String>(
                      value: device.name,
                      child: Row(
                        children: [
                          Icon(device.icon, size: 20),
                          const SizedBox(width: 8),
                          Text(device.name),
                        ],
                      ),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _previewDeviceName = value);
            },
          ),
          if (!isHome) ...[
            const SizedBox(height: 10),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(
                    value: false,
                    icon: Icon(Icons.movie_outlined),
                    label: UniversalText('Movie')),
                ButtonSegment<bool>(
                    value: true,
                    icon: Icon(Icons.tv_outlined),
                    label: UniversalText('TV Show')),
              ],
              selected: <bool>{detailsPreviewTvShow},
              onSelectionChanged: (value) {
                if (value.isNotEmpty) {
                  setState(() => detailsPreviewTvShow = value.first);
                }
              },
            ),
          ],
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isPhone ? 8 : 14),
            decoration: BoxDecoration(
              color: const Color(0xFF050505),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: .1)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = constraints.maxWidth - (isPhone ? 16 : 28);
                final maxHeight = isPhone ? 620.0 : 680.0;
                final scale = (maxWidth / selectedDevice.width)
                    .clamp(0.05, maxHeight / selectedDevice.height)
                    .toDouble();
                return Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(isPhone
                        ? 28
                        : isTv
                            ? 10
                            : 18),
                    child: SizedBox(
                      width: selectedDevice.width * scale,
                      height: selectedDevice.height * scale,
                      child: DecoratedBox(
                        decoration:
                            const BoxDecoration(color: Color(0xFF090909)),
                        child: Transform.scale(
                          scale: scale,
                          alignment: Alignment.topLeft,
                          child: SizedBox(
                            width: selectedDevice.width,
                            height: selectedDevice.height,
                            child: AbsorbPointer(
                              absorbing: true,
                              child: actualPage,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          UniversalText(
            '${selectedDevice.name} • ${selectedDevice.width.toInt()} × ${selectedDevice.height.toInt()} • ${isTv ? 'TV remote / focus layout' : 'touch / pointer layout'}',
            style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            isHome
                ? 'Changes to Home customization are reflected live in the selected device preview.'
                : isMusic
                    ? 'Changes to Music customization are reflected live in the selected device preview.'
                    : 'Changes to Details customization are reflected live in the selected device preview.',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _previewCategorySelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _previewCategoryButton(_PreviewDeviceCategory.phone,
              Icons.phone_iphone_rounded, '📱 Phone'),
          _previewCategoryButton(_PreviewDeviceCategory.tablet,
              Icons.tablet_mac_rounded, '📱 Tablet'),
          _previewCategoryButton(_PreviewDeviceCategory.desktop,
              Icons.desktop_windows_rounded, '🖥️ Desktop'),
          _previewCategoryButton(
              _PreviewDeviceCategory.tv, Icons.tv_rounded, '📺 TV / Large'),
        ],
      ),
    );
  }

  Widget _previewCategoryButton(
    _PreviewDeviceCategory category,
    IconData icon,
    String label,
  ) {
    final selected = _previewCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: Icon(icon, size: 17),
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          final first = _previewDevices
              .firstWhere((device) => device.category == category);
          setState(() {
            _previewCategory = category;
            _previewDeviceName = first.name;
          });
        },
      ),
    );
  }

  Widget _buildHomeCustomizationPreview() {
    // The live product uses one fixed primary navbar. Keep the preview aligned
    // with that shell instead of previewing the removed configurable mega-bar.
    final previewNavbar = Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: colorFromName(draft.navbarColor).withValues(alpha: .95),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colorFromName(draft.navbarGlowColor).withValues(alpha: .35),
        ),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _PreviewNavItem(Icons.home_rounded, 'Home', true),
            _PreviewNavItem(Icons.video_library_rounded, 'Library', false),
            _PreviewNavItem(Icons.people_rounded, 'Friends', false),
            _PreviewNavItem(Icons.more_horiz_rounded, 'More', false),
          ],
        ),
      ),
    );

    final page = _homeCustomizationOutline();
    return HomePositionedLayout(
      navbarPosition: 'Bottom',
      storagePosition: 'Bottom',
      storageThickness: draft.storageBarThickness,
      navbar: previewNavbar,
      child: page,
    );
  }

  Widget _homeCustomizationOutline() {
    final background = colorFromName(draft.homeBackgroundColor);
    final sections = <Widget>[];

    // Browse shortcuts stay pinned as navigation; content sections below use
    // the exact visibility and ordering that will be applied to the Home page.
    sections.add(_homePreviewMediaEntryButtons());

    for (final section in draft.sectionOrder) {
      if (!draft.isSectionVisible(section)) continue;
      if (section == 'Friends Stories' &&
          storyPlacement != 'home' && storyPlacement != 'both') {
        continue;
      }

      switch (section) {
        case 'Hero Banner':
          sections.add(_homePreviewHero());
        case 'Movies':
          sections.add(_homePreviewMediaSection(
            'MOVIES',
            'Sample movies',
            Icons.movie_outlined,
            isTvShow: false,
          ));
        case 'TV Shows':
          sections.add(_homePreviewMediaSection(
            'TV SHOWS',
            'Sample shows',
            Icons.tv_outlined,
            isTvShow: true,
          ));
        case 'Continue Watching':
          sections.add(_homePreviewMediaSection(
            'CONTINUE WATCHING',
            'Movies & shows in progress',
            Icons.play_circle_outline_rounded,
            isTvShow: false,
            progress: true,
          ));
        case 'Recently Watched':
          sections.add(_homePreviewMediaSection(
            'RECENTLY WATCHED',
            'Movies & shows you watched',
            Icons.history_rounded,
            isTvShow: true,
          ));
        case 'New Additions':
          sections.add(_homePreviewMediaSection(
            'NEW ADDITIONS',
            'Recently imported movies & shows',
            Icons.fiber_new_rounded,
            isTvShow: false,
          ));
        case 'All Library':
          sections.add(_homePreviewMediaSection(
            'ALL LIBRARY',
            'Movies and TV shows',
            Icons.video_library_outlined,
            isTvShow: true,
          ));
        case 'Library Recommendations':
          sections.add(_homePreviewMediaSection(
            'LIBRARY RECOMMENDATIONS',
            'Recommended for this profile',
            Icons.auto_awesome_outlined,
            isTvShow: false,
          ));
        case 'Movies by Country':
          sections.add(_homePreviewMediaSection(
            'MOVIES FROM COUNTRY', "Grouped by each title's recorded country of origin",
            Icons.public_rounded, isTvShow: false));
        case 'Shows by Country':
          sections.add(_homePreviewMediaSection(
            'SHOWS FROM COUNTRY', "Grouped by each title's recorded country of origin",
            Icons.public_rounded, isTvShow: true));
        case 'New Albums':
          sections.add(_homePreviewBar('NEW ALBUMS', Icons.album_rounded));
        case "This Week's Top 10 Movies":
          sections.add(_homePreviewBar("THIS WEEK'S TOP 10 MOVIES", Icons.movie_rounded));
        case "This Week's Top 10 Shows":
          sections.add(_homePreviewBar("THIS WEEK'S TOP 10 SHOWS", Icons.tv_rounded));
        case "This Week's Top 10 Albums":
          sections.add(_homePreviewBar("THIS WEEK'S TOP 10 ALBUMS", Icons.album_rounded));
        case "This Week's Top 10 Songs":
          sections.add(_homePreviewBar("THIS WEEK'S TOP 10 SONGS", Icons.music_note_rounded));
        case "This Week's Top 10 Actors":
          sections.add(_homePreviewBar("THIS WEEK'S TOP 10 ACTORS", Icons.face_rounded));
        case "This Week's Top 10 Actresses":
          sections.add(_homePreviewBar("THIS WEEK'S TOP 10 ACTRESSES", Icons.face_3_rounded));
        case "This Week's Top 10 Singers":
          sections.add(_homePreviewBar("THIS WEEK'S TOP 10 SINGERS", Icons.mic_rounded));
        case "This Week's Top 10 Bands":
          sections.add(_homePreviewBar("THIS WEEK'S TOP 10 BANDS", Icons.groups_rounded));
        case 'Ranking of All Top 10s':
          sections.add(_homePreviewBar('RANKING OF ALL TOP 10S', Icons.leaderboard_rounded));
        case 'Recommendations & Mood':
          sections.add(_homePreviewBar('RECOMMENDATIONS & MOOD', Icons.auto_awesome_outlined));
        case 'Franchise Progress':
          sections.add(_homePreviewBar('FRANCHISE & SAGA PROGRESS', Icons.timeline_rounded));
        case 'Channels':
          sections.add(_homePreviewBar('CHANNELS', Icons.live_tv_rounded));
        case 'Friends Stories':
          sections.add(_homePreviewBar('FRIENDS STORIES', Icons.auto_stories_rounded));
        case 'Storage Progress':
          sections.add(_homePreviewBar('STORAGE PROGRESS', Icons.storage_rounded));
        case 'Themed Episodes':
          sections.add(_homePreviewBar('THEMED EPISODES', Icons.theater_comedy_rounded));
        case 'You Might Also Like':
          sections.add(_homePreviewBar('YOU MIGHT ALSO LIKE', Icons.thumb_up_alt_outlined));
        case 'Collections':
          sections.add(_homePreviewBar('COLLECTIONS', Icons.collections_bookmark_outlined));
        case 'Because You Watched':
          sections.add(_homePreviewBar('BECAUSE YOU WATCHED', Icons.movie_filter_outlined));
        case 'People & Cast Recommendations':
          sections.add(_homePreviewBar('PEOPLE & CAST RECOMMENDATIONS', Icons.person_search_rounded));
        case 'Friends & Communities':
          sections.add(_homePreviewBar('FRIENDS & COMMUNITIES', Icons.groups_rounded));
        case 'Media Intelligence Tools':
          sections.add(_homePreviewBar('MEDIA INTELLIGENCE TOOLS', Icons.auto_awesome_rounded));
        case 'Music & Film':
          sections.add(_homePreviewBar('MUSIC & FILM', Icons.headphones_rounded));
        case 'Seasonal Collections':
          sections.add(_homePreviewBar('SEASONAL COLLECTIONS', Icons.calendar_month_rounded));
      }
    }

    return Material(
      color: background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: sections.isEmpty
              ? const [
                  Padding(
                    padding: EdgeInsets.all(40),
                    child: UniversalText(
                      'No Home sections are currently enabled.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                ]
              : sections,
        ),
      ),
    );
  }

  Widget _homePreviewHero() {
    return Container(
      height: draft.heroStyle == 'Minimal' ? 150 : 210,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF181818),
        border: Border.all(color: Colors.white.withValues(alpha: .16)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Icon(Icons.movie_filter_outlined,
                size: 34, color: Colors.white38),
            const SizedBox(height: 8),
            Text(
              draft.heroStyle.toUpperCase(),
              style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1),
            ),
            const SizedBox(height: 4),
            const UniversalText(
              'FEATURED MOVIE / TV SHOW',
              style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  Widget _homePreviewMediaEntryButtons() {
    final buttons = <Widget>[
      if (draft.showMusic) _previewEntry('MUSIC', Icons.music_note_rounded),
      if (draft.showFilm) _previewEntry('FILM', Icons.movie_creation_outlined),
      _previewEntry('COLLECTIONS', Icons.collections_bookmark_outlined),
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: .16)),
        color: const Color(0xFF121212),
      ),
      child: draft.homeMediaLayout == 'Under Banner'
          ? Column(children: [
              for (var i = 0; i < buttons.length; i++) ...[
                buttons[i],
                if (i != buttons.length - 1) const SizedBox(height: 8)
              ]
            ])
          : Row(children: [
              for (var i = 0; i < buttons.length; i++) ...[
                Expanded(child: buttons[i]),
                if (i != buttons.length - 1) const SizedBox(width: 8)
              ]
            ]),
    );
  }

  Widget _previewEntry(String label, IconData icon) => Container(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: .18)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 18, color: Colors.white54),
          const SizedBox(width: 7),
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Colors.white54)),
        ]),
      );

  Widget _homePreviewMediaSection(
    String title,
    String subtitle,
    IconData icon, {
    required bool isTvShow,
    bool progress = false,
  }) {
    final cardWidth = switch (draft.cardSize) {
      'Small' => 78.0,
      'Large' => 125.0,
      _ => 100.0,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colorFromName(draft.navbarGlowColor)),
              const SizedBox(width: 7),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, letterSpacing: .8)),
              ),
              Text(subtitle,
                  style: const TextStyle(color: Colors.white38, fontSize: 9)),
            ],
          ),
          const SizedBox(height: 9),
          SizedBox(
            height: cardWidth * 1.48 + (progress ? 20 : 0),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              separatorBuilder: (_, __) => const SizedBox(width: 9),
              itemBuilder: (context, index) {
                final label =
                    isTvShow ? 'SHOW ${index + 1}' : 'MOVIE ${index + 1}';
                return SizedBox(
                  width: cardWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF151515),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: .18)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                  isTvShow
                                      ? Icons.tv_outlined
                                      : Icons.movie_outlined,
                                  size: 25,
                                  color: Colors.white38),
                              const SizedBox(height: 5),
                              Text(label,
                                  style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ),
                      if (progress) ...[
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child:
                              LinearProgressIndicator(value: .62, minHeight: 4),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _homePreviewBar(String label, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: .14)),
      ),
      child: Row(
        children: [
          Icon(icon, color: colorFromName(draft.navbarGlowColor)),
          const SizedBox(width: 9),
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w900, letterSpacing: .8)),
          const Spacer(),
          const Icon(Icons.chevron_right_rounded, color: Colors.white38),
        ],
      ),
    );
  }

  Widget _buildMusicCustomizationPreview() {
    final sections = <Widget>[];
    for (final section in musicDraft.sectionOrder) {
      final enabled = switch (section) {
        'Weekly Discovery' => musicDraft.showWeeklyDiscovery,
        'AI DJ' => musicDraft.showAIDJ,
        'Made For You' => musicDraft.showSystemPlaylists,
        'Liked Songs' => musicDraft.showLikedSongs,
        'Recently Played' => musicDraft.showRecentlyPlayed,
        'Mood Mixes' => musicDraft.showMoodMixes,
        'Artists' => musicDraft.showArtists,
        'Albums' => musicDraft.showAlbums,
        'Playlists' => musicDraft.showPlaylists,
        'Soundtrack Universe' => musicDraft.showSoundtrackUniverse,
        _ => false,
      };
      if (!enabled) continue;
      sections.add(
        _musicPreviewSection(
          section.toUpperCase(),
          section == 'AI DJ'
              ? 'SMART DJ / MIX CONTROLS'
              : section == 'Made For You'
                  ? 'MADE FOR YOU • DISCOVER WEEKLY • DAILY MIX'
                  : 'MUSIC SECTION',
          section == 'AI DJ'
              ? Icons.auto_awesome_rounded
              : section == 'Weekly Discovery'
                  ? Icons.auto_awesome_rounded
                  : Icons.music_note_rounded,
        ),
      );
    }

    return Material(
      color: const Color(0xFF090909),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 70),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: musicDraft.playerStyle == 'Compact' ? 58 : 76,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF151515),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  const Icon(Icons.album_outlined, color: Colors.white38),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: UniversalText('NOW PLAYING • TRACK / ARTIST',
                        style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
                  Icon(
                    Icons.play_arrow_rounded,
                    color: colorFromName(draft.navbarGlowColor),
                  ),
                  const Icon(Icons.queue_music_rounded, color: Colors.white38),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (sections.isEmpty)
              const Padding(
                padding: EdgeInsets.all(30),
                child: UniversalText(
                  'No Music sections are currently enabled.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54),
                ),
              )
            else
              ...sections,
          ],
        ),
      ),
    );
  }

  Widget _musicPreviewSection(String title, String subtitle, IconData icon) {
    final width = musicDraft.cardStyle == 'Compact'
        ? 72.0
        : musicDraft.cardStyle == 'Large'
            ? 108.0
            : 90.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .035),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: .14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: colorFromName(draft.navbarGlowColor)),
              const SizedBox(width: 7),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(color: Colors.white38, fontSize: 8)),
          const SizedBox(height: 8),
          SizedBox(
            height: width * .82,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              separatorBuilder: (_, __) => const SizedBox(width: 7),
              itemBuilder: (_, index) => Container(
                width: width,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF151515),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.music_note_rounded,
                        size: 20, color: Colors.white30),
                    const SizedBox(height: 4),
                    UniversalText('ITEM ${index + 1}',
                        style: const TextStyle(
                            fontSize: 7, color: Colors.white38)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCustomizationPreview() {
    final sections = <Widget>[];

    for (final section in detailsDraft.sectionOrder) {
      final widget = _detailsPreviewSection(section);
      if (widget != null) sections.add(widget);
    }

    return Material(
      color: const Color(0xFF090909),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 34),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: sections.isEmpty
              ? const [
                  Padding(
                    padding: EdgeInsets.all(30),
                    child: UniversalText(
                      'No Details sections are currently enabled.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                ]
              : sections,
        ),
      ),
    );
  }

  Widget? _detailsPreviewSection(String section) {
    final enabled = switch (section) {
      'Poster' => detailsDraft.showPoster,
      'Title' => detailsDraft.showTitle,
      'Metadata' => detailsDraft.showMetadata,
      'Ownership' => detailsDraft.showOwnership,
      'Description' => detailsDraft.showDescription,
      'Seasons' => detailsPreviewTvShow && detailsDraft.showSeasons,
      'Collection Items' => true,
      'Play' => detailsDraft.showPlay,
      'Trailer' => detailsDraft.showTrailer,
      'Group Watch' => detailsDraft.showGroupWatch,
      'Reviews' => true,
      'Audio & Subtitles' => detailsDraft.showAudioSubtitles,
      'Reactions' => detailsDraft.showReactions,
      'Information' => detailsDraft.showInformation,
      'Library' => detailsDraft.showLibrary,
      _ => false,
    };

    if (!enabled) return null;

    return switch (section) {
      'Poster' => _detailsOutlinePoster(),
      'Title' => _detailsOutlineTitle(),
      'Metadata' => _detailsOutlineMetadata(),
      'Ownership' => _detailsOutlineBar('LIBRARY OWNERSHIP'),
      'Description' =>
        _detailsOutlineText('Description / synopsis placeholder text'),
      'Seasons' => _detailsOutlineSeasons(),
      'Collection Items' => _detailsOutlineCard('COLLECTION ITEMS'),
      'Play' => _detailsOutlineButton(Icons.play_arrow_rounded, 'PLAY'),
      'Trailer' => _detailsOutlineButton(
          Icons.play_circle_outline_rounded, 'WATCH TRAILER'),
      'Group Watch' => _detailsOutlineButton(
          Icons.groups_outlined, 'GROUP WATCH / WATCH TOGETHER'),
      'Reviews' => _detailsOutlineButton(Icons.rate_review_outlined, 'REVIEWS'),
      'Audio & Subtitles' => _detailsOutlineButton(
          Icons.closed_caption_outlined, 'AUDIO & SUBTITLES'),
      'Reactions' => _detailsOutlineReactions(),
      'Information' => _detailsOutlineInformation(),
      'Library' => _detailsOutlineLibrary(),
      _ => null,
    };
  }

  Widget _detailsOutlinePoster() {
    final width = detailsDraft.posterSize == 'Small'
        ? 175.0
        : detailsDraft.posterSize == 'Large'
            ? 285.0
            : 225.0;

    Alignment alignment;
    switch (detailsDraft.posterPosition) {
      case 'Left':
        alignment = Alignment.centerLeft;
      case 'Right':
        alignment = Alignment.centerRight;
      default:
        alignment = Alignment.center;
    }

    if (detailsDraft.posterStyle == 'Side') {
      return _detailsOutlineCard(
        'POSTER',
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailsPosterBox(width: 120),
            const SizedBox(width: 14),
            Expanded(
              child: _detailsOutlineStack([
                'TITLE',
                'YEAR • RATING • RUNTIME',
                'DIRECTORS / ACTORS',
              ]),
            ),
          ],
        ),
      );
    }

    if (detailsDraft.posterStyle == 'Full Screen') {
      return _detailsOutlineCard(
        'POSTER / HERO',
        child: SizedBox(
          height: 300,
          child: _detailsPosterBox(fill: true),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Align(
        alignment: alignment,
        child: _detailsPosterBox(width: width),
      ),
    );
  }

  Widget _detailsPosterBox({double? width, bool fill = false}) {
    final box = Container(
      width: width,
      height: fill ? null : (width ?? 180) * 1.5,
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: .18)),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.movie_outlined, size: 48, color: Colors.white38),
            SizedBox(height: 8),
            UniversalText('POSTER',
                style: TextStyle(
                    color: Colors.white38, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
    return box;
  }

  Widget _detailsOutlineTitle() {
    return _detailsOutlineCard(
      'TITLE',
      child: _detailsTextLine(
        'Movie or Show Title',
        size: 27,
        alignment: _detailsTextAlignment(detailsDraft.titleAlignment),
      ),
    );
  }

  Widget _detailsOutlineMetadata() {
    final pills = <String>[];
    if (detailsDraft.showReleaseYear) pills.add('2026');
    if (detailsDraft.showRating) pills.add('★ 8.7');
    if (detailsDraft.showContentRating) pills.add('PG-13');
    if (detailsDraft.showRuntime) pills.add('2h 10m');

    return _detailsOutlineCard(
      'METADATA',
      child: Wrap(
        alignment: _detailsWrapAlignment(detailsDraft.informationAlignment),
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final pill in pills)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: .16)),
                color: Colors.white.withValues(alpha: .035),
              ),
              child: Text(pill,
                  style: const TextStyle(
                      color: Colors.white70, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }

  Widget _detailsOutlineSeasons() {
    final episodes = List.generate(
      3,
      (index) => _detailsOutlineEpisode(index + 1),
    );

    return _detailsOutlineCard(
      'SEASONS & EPISODES',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _detailsOutlineStack(['SEASON 1', 'SEASON 2', 'SEASON 3']),
          const SizedBox(height: 14),
          _detailsTextLine(
            'Season 1',
            size: 18,
            alignment: _detailsTextAlignment(detailsDraft.seasonPlacement),
          ),
          const SizedBox(height: 10),
          ...episodes,
        ],
      ),
    );
  }

  Widget _detailsOutlineEpisode(int number) {
    final label = switch (detailsDraft.episodeNaming) {
      'Season X, Episode Y' => 'SEASON 1 • EPISODE $number',
      'Both' => 'S1E$number',
      _ => 'Episode $number title',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: .025),
        border: Border.all(color: Colors.white.withValues(alpha: .10)),
      ),
      child: Row(
        children: [
          Container(
            width: 92,
            height: 62,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: .14)),
            ),
            child: const Center(
                child: Icon(Icons.image_outlined, color: Colors.white30)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _detailsOutlineStack([
              label,
              'Episode description / runtime',
            ]),
          ),
          const Icon(Icons.play_circle_outline_rounded, color: Colors.white38),
        ],
      ),
    );
  }

  Widget _detailsOutlineInformation() {
    return _detailsOutlineCard(
      'INFORMATION',
      child: Column(
        children: [
          _detailsOutlineInfoRow('Directors', 'Director name • Director name'),
          _detailsOutlineInfoRow(
              'Actors', 'Actor name • Actor name • Actor name'),
          _detailsOutlineInfoRow('Release Year', '2026'),
          _detailsOutlineInfoRow('Rating', '★ 8.7 / 10'),
          _detailsOutlineInfoRow('Runtime', '2h 10m'),
          _detailsOutlineInfoRow('Content Rating', 'PG-13'),
        ],
      ),
    );
  }

  Widget _detailsOutlineInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(label,
                style: const TextStyle(color: Colors.white38, fontSize: 13)),
          ),
          Expanded(
            child: _detailsTextLine(
              value,
              size: 13,
              alignment:
                  _detailsTextAlignment(detailsDraft.informationAlignment),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailsOutlineReactions() {
    return _detailsOutlineCard(
      'REACTIONS',
      child: Row(
        children: [
          Expanded(child: _detailsMiniButton(Icons.thumb_up_outlined, 'LIKE')),
          const SizedBox(width: 8),
          Expanded(
              child: _detailsMiniButton(Icons.thumb_down_outlined, 'DISLIKE')),
        ],
      ),
    );
  }

  Widget _detailsOutlineLibrary() {
    return _detailsOutlineCard(
      'LIBRARY',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _detailsOutlineButton(Icons.add_to_queue_rounded, 'ADD TO LIBRARY'),
          const SizedBox(height: 8),
          _detailsOutlineButton(
              Icons.collections_bookmark_outlined, 'ADD TO COLLECTION'),
        ],
      ),
    );
  }

  Widget _detailsOutlineButton(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: _detailsButtonAlignment(),
        child: OutlinedButton.icon(
          onPressed: null,
          icon: Icon(icon),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: Colors.white.withValues(alpha: .16)),
            foregroundColor: Colors.white54,
          ),
        ),
      ),
    );
  }

  Widget _detailsMiniButton(IconData icon, String label) {
    return OutlinedButton.icon(
      onPressed: null,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: Colors.white.withValues(alpha: .14)),
        foregroundColor: Colors.white54,
      ),
    );
  }

  Widget _detailsOutlineCard(String label, {Widget? child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .11)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          child ?? _detailsOutlineBar('OUTLINE'),
        ],
      ),
    );
  }

  Widget _detailsOutlineBar(String text) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: .14)),
      ),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white38, fontWeight: FontWeight.w700)),
    );
  }

  Widget _detailsOutlineText(String text) {
    return _detailsOutlineCard(
      'DESCRIPTION',
      child: Text(
        text,
        style: const TextStyle(color: Colors.white38, height: 1.5),
        textAlign: _detailsTextAlignment(detailsDraft.informationAlignment),
      ),
    );
  }

  Widget _detailsOutlineStack(List<String> labels) {
    return Column(
      crossAxisAlignment:
          _detailsCrossAxisAlignment(detailsDraft.informationAlignment),
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i != 0) const SizedBox(height: 6),
          _detailsTextLine(labels[i],
              size: i == 0 ? 15 : 12,
              alignment:
                  _detailsTextAlignment(detailsDraft.informationAlignment)),
        ],
      ],
    );
  }

  Widget _detailsTextLine(String text,
      {double size = 14, TextAlign alignment = TextAlign.left}) {
    return Text(
      text,
      textAlign: alignment,
      style: TextStyle(
        color: Colors.white54,
        fontSize: size,
        fontWeight: size >= 18 ? FontWeight.w900 : FontWeight.w700,
      ),
    );
  }

  TextAlign _detailsTextAlignment(String value) {
    switch (value) {
      case 'Center':
        return TextAlign.center;
      case 'Right':
        return TextAlign.right;
      default:
        return TextAlign.left;
    }
  }

  CrossAxisAlignment _detailsCrossAxisAlignment(String value) {
    switch (value) {
      case 'Center':
        return CrossAxisAlignment.center;
      case 'Right':
        return CrossAxisAlignment.end;
      default:
        return CrossAxisAlignment.start;
    }
  }

  WrapAlignment _detailsWrapAlignment(String value) {
    switch (value) {
      case 'Center':
        return WrapAlignment.center;
      case 'Right':
        return WrapAlignment.end;
      default:
        return WrapAlignment.start;
    }
  }

  Alignment _detailsButtonAlignment() {
    switch (detailsDraft.buttonAlignment) {
      case 'Center':
        return Alignment.center;
      case 'Right':
        return Alignment.centerRight;
      default:
        return Alignment.centerLeft;
    }
  }

  /// Performs `_sectionOrder` for this feature. Update this documentation when its contract changes.
  Widget _sectionOrder({
    required String title,
    required String subtitle,
    required List<String> items,
    ValueChanged<List<String>>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(color: Colors.white54),
        ),
        const SizedBox(height: 10),
        Container(
          constraints: const BoxConstraints(maxHeight: 360),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .035),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: .06)),
          ),
          child: ReorderableListView.builder(
            shrinkWrap: true,
            buildDefaultDragHandles: true,
            itemCount: items.length,
            onReorderItem: (oldIndex, newIndex) {
              final reordered = List<String>.from(items);
              final item = reordered.removeAt(oldIndex);
              reordered.insert(newIndex, item);

              if (onChanged != null) {
                onChanged(reordered);
              } else {
                setState(() {
                  if (identical(items, draft.navigationOrder)) {
                    draft.navigationOrder = reordered;
                  } else {
                    draft.sectionOrder = reordered;
                  }
                });
              }
            },
            itemBuilder: (context, index) {
              final name = items[index];
              return Material(
                key: ValueKey('${title}_$name'),
                color: const Color(0xFF151515),
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  tileColor: Colors.transparent,
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.red.withValues(alpha: .12),
                    child: UniversalText(
                      '${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  trailing: const Icon(
                    Icons.drag_indicator_rounded,
                    color: Colors.white38,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    final isHome = selectedPage == CustomizationPage.home;
    final isMusic = selectedPage == CustomizationPage.music;

    return Scaffold(
      backgroundColor: const Color(0xFF070707),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070707),
        surfaceTintColor: Colors.transparent,
        title: UniversalText(
          widget.firstSetup
              ? (selectedPage == CustomizationPage.home
                  ? 'Customize Home'
                  : selectedPage == CustomizationPage.details
                      ? 'Customize Details'
                      : 'Customize Music')
              : 'Customize ${switch (selectedPage) {
                  CustomizationPage.home => 'Home',
                  CustomizationPage.details => 'Details',
                  CustomizationPage.music => 'Music',
                }}',
        ),
        automaticallyImplyLeading: !widget.firstSetup,
        actions: widget.firstSetup
            ? const []
            : [
                TextButton(
                  onPressed: _save,
                  child: const UniversalText(
                    'SAVE',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
      ),
      body: SafeArea(
        child: ListView(
          controller: _customizationScrollController,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            if (widget.lockedPage == null || widget.firstSetup) _pageSelector(),
            const SizedBox(height: 18),
            _headerCard(),
            const SizedBox(height: 18),
            if (isHome)
              _buildHomePage()
            else if (isMusic)
              _buildMusicPage()
            else
              _buildDetailsPage(),
            _customizationPreview(),
            const SizedBox(height: 26),
            SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: const Icon(Icons.check_rounded),
                label: UniversalText(
                  _isSaving
                      ? 'SAVING...'
                      : widget.firstSetup
                          ? (selectedPage == CustomizationPage.home
                              ? 'CONTINUE TO DETAILS'
                              : selectedPage == CustomizationPage.details
                                  ? 'CONTINUE TO MUSIC'
                                  : 'CONTINUE TO ACCOUNT INVITE')
                          : 'SAVE CHANGES',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;

  const _PreviewNavItem(this.icon, this.label, this.selected);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: selected ? Colors.white : Colors.white54),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            color: selected ? Colors.white : Colors.white54,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// MAIN APPLICATION SHELL
// ============================================================

class MainScreen extends StatefulWidget {
  final PrimaryDestination initialDestination;
  final String? initialConversationId;

  const MainScreen({
    super.key,
    this.initialDestination = PrimaryDestination.home,
    this.initialConversationId,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

enum PrimaryDestination {
  home,
  library,
  friends,
}

// Keep the active main shell alive when primary destinations change. This
// avoids reconstructing Home/library/Friends and repeating their entry work.
_MainScreenState? _activeMainScreenState;

class _GlobalPrimaryNavigationBar extends StatelessWidget {
  const _GlobalPrimaryNavigationBar({this.vertical = false});
  final bool vertical;

  void _select(BuildContext context, int index) {
    if (index == 3) {
      _showGlobalMore();
      return;
    }
    if (index == 4) {
      final navigator = _appNavigatorKey.currentState;
      if (navigator == null) return;
      navigator.push<void>(MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/app/profiles'),
        builder: (_) => ProfileSelectionScreen(
          onOpened: () => _appPageState.setPage('profiles', selectedPrimaryIndex: 0, customizing: false),
          onProfileSelected: (selectionContext) {
            Navigator.of(selectionContext, rootNavigator: true).pushAndRemoveUntil<void>(
              MaterialPageRoute<void>(
                settings: const RouteSettings(name: '/main/home'),
                builder: (_) => const MainScreen(initialDestination: PrimaryDestination.home),
              ),
              (route) => false,
            );
          },
        ),
      ));
      return;
    }
    final destination = PrimaryDestination.values[index];
    final navigator = _appNavigatorKey.currentState;
    if (navigator == null) return;

    final activeShell = _activeMainScreenState;
    if (activeShell != null && activeShell.mounted) {
      var foundMainRoute = false;
      navigator.popUntil((route) {
        final name = route.settings.name ?? '';
        if (name.startsWith('/main/')) {
          foundMainRoute = true;
          return true;
        }
        return route.isFirst;
      });
      if (foundMainRoute) {
        activeShell.selectDestination(destination);
        _appPageState.setPage(
          destination.name,
          selectedPrimaryIndex: index,
          customizing: false,
        );
        return;
      }
    }

    // Safe fallback for unusual entry flows that do not have a named main
    // route yet (for example, app links or a reset during onboarding).
    _appPageState.setPage(destination.name, selectedPrimaryIndex: index, customizing: false);
    navigator.pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: '/main/${destination.name}'),
        builder: (_) => MainScreen(initialDestination: destination),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_appPageState, AppController.instance]),
      builder: (context, _) {
        final selectedIndex = _appPageState.primaryIndex.clamp(0, 2).toInt();
        final profile = AppController.instance.currentProfile;
        final rawProfileName = profile?.name.trim() ?? '';
        final profileLabel = rawProfileName.isEmpty ? 'Profile' : rawProfileName;
        final profileAvatar = profile == null
            ? const Icon(Icons.person_outline_rounded)
            : _MainProfileAvatar(profile: profile, size: 30);
        if (vertical) {
          return Material(
            color: const Color(0xF20B0B0B),
            child: NavigationRail(
              backgroundColor: const Color(0xF20B0B0B),
              selectedIndex: selectedIndex,
              labelType: NavigationRailLabelType.all,
              destinations: <NavigationRailDestination>[
                const NavigationRailDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: Text('Home')),
                const NavigationRailDestination(icon: Icon(Icons.video_library_outlined), selectedIcon: Icon(Icons.video_library_rounded), label: Text('Watch')),
                const NavigationRailDestination(icon: Icon(Icons.people_outline_rounded), selectedIcon: Icon(Icons.people_rounded), label: Text('Friends')),
                const NavigationRailDestination(icon: Icon(Icons.more_horiz_rounded), selectedIcon: Icon(Icons.more_horiz_rounded), label: Text('More')),
                NavigationRailDestination(icon: profileAvatar, selectedIcon: profileAvatar, label: Text(profileLabel)),
              ],
              onDestinationSelected: (index) => _select(context, index),
            ),
          );
        }
        return NavigationBar(
          height: 84,
          selectedIndex: selectedIndex,
          destinations: <NavigationDestination>[
            const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
            const NavigationDestination(icon: Icon(Icons.video_library_outlined), selectedIcon: Icon(Icons.video_library_rounded), label: 'Watch'),
            const NavigationDestination(icon: Icon(Icons.people_outline_rounded), selectedIcon: Icon(Icons.people_rounded), label: 'Friends'),
            const NavigationDestination(icon: Icon(Icons.more_horiz_rounded), selectedIcon: Icon(Icons.more_horiz_rounded), label: 'More'),
            NavigationDestination(icon: profileAvatar, selectedIcon: profileAvatar, label: profileLabel),
          ],
          onDestinationSelected: (index) => _select(context, index),
        );
      },
    );
  }
}

void _showGlobalMore() {
  final navigator = _appNavigatorKey.currentState;
  if (navigator == null) return;

  void push(Widget page, {String? routeName}) {
    navigator.push<void>(
      MaterialPageRoute<void>(
        settings: routeName == null ? null : RouteSettings(name: routeName),
        builder: (_) => page,
      ),
    );
  }

  showModalBottomSheet<void>(
    context: navigator.context,
    routeSettings: const RouteSettings(name: '/app/more'),
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => _MoreActionsSheet(
      onSettings: () {
        Navigator.of(sheetContext).pop();
        push(const AccountSettingsScreen(), routeName: '/app/page/settings');
      },
      onStreamingExperience: () {
        Navigator.of(sheetContext).pop();
        push(const StreamingExperienceSettingsScreen(),
            routeName: '/app/page/streaming-experience');
      },
      onPerfectStreaming: () {
        Navigator.of(sheetContext).pop();
        push(const PerfectStreamingExperienceScreen(),
            routeName: '/app/page/perfect-streaming');
      },
      onDevices: () {
        Navigator.of(sheetContext).pop();
        push(const DeviceCenterScreen(), routeName: '/app/page/devices');
      },
      onHomeServer: () {
        Navigator.of(sheetContext).pop();
        push(
          HomeServerScreen(
            onImportRip: () => push(
              const ImportMediaScreen(),
              routeName: '/app/page/import',
            ),
          ),
          routeName: '/app/page/home-server',
        );
      },
      onStreamingUpgrades: () {
        Navigator.of(sheetContext).pop();
        push(const StreamingUpgradeCenterScreen(), routeName: '/app/page/streaming-upgrades');
      },
      onJellyfinPlugins: () {
        Navigator.of(sheetContext).pop();
        push(const JellyfinPluginsHubScreen(), routeName: '/app/page/jellyfin-plugins');
      },
      onImport: () {
        Navigator.of(sheetContext).pop();
        push(const ImportMediaScreen(), routeName: '/app/page/import');
      },
      onMembers: () {
        Navigator.of(sheetContext).pop();
        push(const AccountInviteScreen(), routeName: '/app/page/members');
      },
      onWatchAndEnjoy: () {
        Navigator.of(sheetContext).pop();
        push(const WatchAndEnjoyScreen(),
            routeName: '/app/page/watch-and-enjoy');
      },
      onShop: () {
        Navigator.of(sheetContext).pop();
        push(
          const MarketplaceHubScreen(initialMode: MarketplaceMode.shop),
          routeName: '/app/marketplace/shop',
        );
      },
      onFoodDelivery: () {
        Navigator.of(sheetContext).pop();
        push(
          const MarketplaceHubScreen(initialMode: MarketplaceMode.food),
          routeName: '/app/marketplace/food',
        );
      },
      onHeyMarathon: () {
        Navigator.of(sheetContext).pop();
        push(const HeyMarathonScreen(), routeName: '/app/page/hey-marathon');
      },
      onMyTv: () {
        Navigator.of(sheetContext).pop();
        push(const MyTvScreen(), routeName: '/app/watch/my-tv');
      },
      onPublicLiveTv: () {
        Navigator.of(sheetContext).pop();
        push(const PublicLiveTvScreen(), routeName: '/app/watch/live-tv');
      },
      onTvController: () {
        Navigator.of(sheetContext).pop();
        push(const TvControllerScreen(), routeName: '/app/page/tv-controller');
      },
      onTvHost: () {
        Navigator.of(sheetContext).pop();
        push(const TvHostScreen(), routeName: '/app/page/tv-host');
      },
      onProductionReadiness: () {
        Navigator.of(sheetContext).pop();
        push(const ProductionReadinessDashboardScreen(),
            routeName: '/app/page/production-readiness');
      },
      onSecurityPrivacy: () {
        Navigator.of(sheetContext).pop();
        push(const SecuritySettingsScreen(),
            routeName: '/app/page/security-privacy');
      },
      onAccessibilityOffline: () {
        Navigator.of(sheetContext).pop();
        push(const AccessibilityOfflineSettingsScreen(),
            routeName: '/app/page/accessibility-offline');
      },
      onEntertainmentStudio: () {
        Navigator.of(sheetContext).pop();
        push(const EntertainmentStudioScreen(),
            routeName: '/app/page/entertainment-studio');
      },
      onInnovationHub: () {
        Navigator.of(sheetContext).pop();
        push(const InnovationHubScreen(), routeName: '/app/innovation');
      },
      onWrapped: () {
        Navigator.of(sheetContext).pop();
        push(const MediaWrappedCollectionsScreen(),
            routeName: '/app/page/wrapped');
      },
      onSpecialEvents: () {
        Navigator.of(sheetContext).pop();
        push(const MyTvSpecialEventsScreen(),
            routeName: '/app/page/special-events');
      },
      onInterruptionMode: () {
        Navigator.of(sheetContext).pop();
        push(const RealLifeInterruptionModeScreen(),
            routeName: '/app/page/interruption-mode');
      },
      onSecurityBots: () {
        Navigator.of(sheetContext).pop();
        push(const SecurityBotCenterScreen(),
            routeName: '/app/page/security-bots');
      },
    ),
  );
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  late PrimaryDestination selected = widget.initialDestination;

  String get _pageTitle => switch (selected) {
        PrimaryDestination.home => 'Home',
        PrimaryDestination.library => 'Watch',
        PrimaryDestination.friends => 'Friends',
      };


  Widget _pageFor(PrimaryDestination destination) {
    switch (destination) {
      case PrimaryDestination.home:
        return HomeScreen(
          showAppBar: false,
          onRefresh: () => setState(() {}),
          onNotifications: null,
        );
      case PrimaryDestination.library:
        return const LibraryHubScreen();
      case PrimaryDestination.friends:
        return FriendsAndCommunitiesScreen(
          initialConversationId: widget.initialConversationId,
        );
    }
  }

  void _showSurpriseMe() {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/app/page/surprise-me'),
        builder: (_) => const SurpriseMeScreen(),
      ),
    );
  }

  Timer? _presenceHeartbeat;

  final Set<PrimaryDestination> _visitedDestinations = <PrimaryDestination>{};

  void selectDestination(PrimaryDestination destination) {
    if (!mounted) return;
    setState(() {
      selected = destination;
      _visitedDestinations.add(destination);
    });
  }

  @override
  void initState() {
    super.initState();
    _visitedDestinations.add(selected);
    _activeMainScreenState = this;
    WidgetsBinding.instance.addObserver(this);
    LanguageController.instance.loadForCurrentProfile();
    unawaited(AppController.instance.loadActivity());
    _startPresenceHeartbeat();
  }

  void _startPresenceHeartbeat() {
    _presenceHeartbeat?.cancel();
    unawaited(_touchSocialPresence());
    _presenceHeartbeat = Timer.periodic(
      const Duration(minutes: 1),
      (_) => unawaited(_touchSocialPresence()),
    );
  }

  Future<void> _touchSocialPresence() async {
    if (!mounted ||
        <String>{'boot', 'profiles', 'server-selection'}
            .contains(_appPageState.pageId)) {
      return;
    }
    final controller = AppController.instance;
    final profile = controller.currentProfile;
    if (profile == null || !controller.backendApi.isAuthenticated) return;
    try {
      // A heartbeat updates last-seen without overriding the current
      // availability or the watching/listening activity set by the player.
      await controller.backendApi
          .setSocialProfilePresence(profileId: profile.id);
    } catch (_) {
      // Presence is advisory and must never interrupt playback or navigation.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPresenceHeartbeat();
    } else {
      _presenceHeartbeat?.cancel();
      _presenceHeartbeat = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _presenceHeartbeat?.cancel();
    if (identical(_activeMainScreenState, this)) {
      _activeMainScreenState = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _appPageRouteObserver.setPageForRoute(
          ModalRoute.of(context),
          selected.name,
          selected.index,
        );
      }
    });
    final background = colorFromName(
      HomeCustomizationStore.settingsFor(
        AppController.instance.currentProfile,
      ).homeBackgroundColor,
    );

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppShellHeader(
              title: _pageTitle,
              pageId: selected.name,
              onSearch: (query) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    settings: const RouteSettings(name: '/app/page/search'),
                    builder: (_) => SmartSearchScreen(initialQuery: query),
                  ),
                );
              },
              onSurpriseMe: _showSurpriseMe,
            ),
            Expanded(
              child: IndexedStack(
                index: selected.index,
                children: <Widget>[
                  for (final destination in PrimaryDestination.values)
                    if (_visitedDestinations.contains(destination))
                      TickerMode(
                        enabled: selected == destination,
                        child: Offstage(
                          offstage: selected != destination,
                          child: _pageFor(destination),
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fixed primary navigation. Secondary features belong behind More or within
/// the Library / Friends hubs rather than occupying the navbar.
class SimplePrimaryNavigationBar extends StatelessWidget {
  final PrimaryDestination? selected;
  final ValueChanged<PrimaryDestination?> onSelected;
  final VoidCallback onMore;

  const SimplePrimaryNavigationBar({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final items = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home_rounded),
        label: 'Home',
      ),
      const NavigationDestination(
        icon: Icon(Icons.video_library_outlined),
        selectedIcon: Icon(Icons.video_library_rounded),
        label: 'Watch',
      ),
      const NavigationDestination(
        icon: Icon(Icons.people_outline_rounded),
        selectedIcon: Icon(Icons.people_rounded),
        label: 'Friends',
      ),
      const NavigationDestination(
        icon: Icon(Icons.more_horiz_rounded),
        selectedIcon: Icon(Icons.more_horiz_rounded),
        label: 'More',
      ),
    ];

    final index = switch (selected) {
      PrimaryDestination.home => 0,
      PrimaryDestination.library => 1,
      PrimaryDestination.friends => 2,
      null => 0,
    };

    return NavigationBar(
      selectedIndex: index,
      onDestinationSelected: (value) {
        if (value == 3) {
          onMore();
        } else {
          onSelected(PrimaryDestination.values[value]);
        }
      },
      destinations: items,
    );
  }
}

/// Compact contextual utility/header bar shared by every major page.
class AppShellHeader extends StatefulWidget {
  final String title;
  final String pageId;
  final ValueChanged<String> onSearch;
  final VoidCallback onSurpriseMe;

  const AppShellHeader({
    super.key,
    required this.title,
    required this.pageId,
    required this.onSearch,
    required this.onSurpriseMe,
  });

  @override
  State<AppShellHeader> createState() => _AppShellHeaderState();
}

class _AppShellHeaderState extends State<AppShellHeader> {
  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 760;

    return Container(
      padding:
          EdgeInsets.fromLTRB(compact ? 12 : 20, 10, compact ? 12 : 20, 10),
      decoration: BoxDecoration(
        color: const Color(0xEE090909),
        border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: .07))),
      ),
      child: Row(
        children: [
          if (!compact) ...[
            Text(widget.title,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(width: 18),
          ],
          Expanded(
            child: Semantics(
              button: true,
              label: 'Open Smart Search',
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: () => widget.onSearch(''),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .055),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          color: Colors.white.withValues(alpha: .72),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            compact
                                ? 'Search everything…'
                                : 'Search movies, TV, music, people, communities…',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .65),
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 19,
                          color: Colors.white.withValues(alpha: .55),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (!compact)
            FilledButton.tonalIcon(
              onPressed: widget.onSurpriseMe,
              icon: const Icon(Icons.shuffle_rounded, size: 19),
              label: const UniversalText('Surprise Me'),
            )
          else
            IconButton(
              tooltip: 'Surprise Me',
              onPressed: widget.onSurpriseMe,
              icon: const Icon(Icons.shuffle_rounded),
            ),
          ActivityButton(),
          PageCustomizeButton(pageId: widget.pageId),
        ],
      ),
    );
  }
}

class _MoreChoice {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onSelected;

  const _MoreChoice(this.title, this.subtitle, this.icon, this.onSelected);
}

class _MoreActionsSheet extends StatelessWidget {
  final VoidCallback onSettings;
  final VoidCallback onStreamingExperience;
  final VoidCallback onPerfectStreaming;
  final VoidCallback onDevices;
  final VoidCallback onHomeServer;
  final VoidCallback onStreamingUpgrades;
  final VoidCallback onJellyfinPlugins;
  final VoidCallback onImport;
  final VoidCallback onMembers;
  final VoidCallback onShop;
  final VoidCallback onFoodDelivery;
  final VoidCallback onWatchAndEnjoy;
  final VoidCallback onHeyMarathon;
  final VoidCallback onMyTv;
  final VoidCallback onPublicLiveTv;
  final VoidCallback onTvController;
  final VoidCallback onTvHost;
  final VoidCallback onProductionReadiness;
  final VoidCallback onSecurityPrivacy;
  final VoidCallback onAccessibilityOffline;
  final VoidCallback onEntertainmentStudio;
  final VoidCallback onInnovationHub;
  final VoidCallback onWrapped;
  final VoidCallback onSpecialEvents;
  final VoidCallback onInterruptionMode;
  final VoidCallback onSecurityBots;

  const _MoreActionsSheet({
    required this.onSettings,
    required this.onStreamingExperience,
    required this.onPerfectStreaming,
    required this.onDevices,
    required this.onHomeServer,
    required this.onStreamingUpgrades,
    required this.onJellyfinPlugins,
    required this.onImport,
    required this.onMembers,
    required this.onShop,
    required this.onFoodDelivery,
    required this.onWatchAndEnjoy,
    required this.onHeyMarathon,
    required this.onMyTv,
    required this.onPublicLiveTv,
    required this.onTvController,
    required this.onTvHost,
    required this.onProductionReadiness,
    required this.onSecurityPrivacy,
    required this.onAccessibilityOffline,
    required this.onEntertainmentStudio,
    required this.onInnovationHub,
    required this.onWrapped,
    required this.onSpecialEvents,
    required this.onInterruptionMode,
    required this.onSecurityBots,
  });

  @override
  Widget build(BuildContext context) {
    return _PremiumSheet(
      title: 'More',
      subtitle: 'Server, account, device and utility settings',
      child: GridView.count(
        shrinkWrap: true,
        crossAxisCount: MediaQuery.sizeOf(context).width >= 700 ? 3 : 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.25,
        children: [
          _combinedCard(
            context,
            Icons.manage_accounts_outlined,
            'Account & Server',
            'Manage members, profiles, storage and server',
            [
              _MoreChoice('Account Members', 'Invite or manage account members',
                  Icons.people_alt_outlined, onMembers),
              _MoreChoice('Home Server', 'Server status and storage',
                  Icons.dns_rounded, onHomeServer),
            ],
          ),
          _moreCard(Icons.auto_awesome_rounded, 'Streaming Upgrade Center',
              'Watchlist, Jellyfin, search, profiles and media shortcuts', onStreamingUpgrades),
          _moreCard(
              Icons.extension_rounded,
              'Jellyfin Plugins',
              'Browse plugin catalog, copy repository URLs and follow installation guides',
              onJellyfinPlugins),
          _moreCard(Icons.album_rounded, 'Import / Rip',
              'Import media and run the ARM disc-import workflow', onImport),
          _moreCard(
              Icons.settings_rounded,
              'Settings',
              'Account, subscription, device, playback and support settings',
              onSettings),
          _moreCard(
              Icons.auto_awesome_rounded,
              'My Entertainment Wrapped',
              'Monthly/yearly recaps and archived Wrapped Collections',
              onWrapped),
          _moreCard(
              Icons.event_available_rounded,
              'My TV Special Events',
              'Stable, randomized theme weeks spread throughout the year',
              onSpecialEvents),
          _moreCard(
              Icons.pause_circle_outline_rounded,
              'Interruption Mode',
              'Pause, save playback position and resume with explicit controls',
              onInterruptionMode),
          _moreCard(
              Icons.health_and_safety_outlined,
              'Security & Database Bots',
              'Run owner-only read-only security and integrity checks',
              onSecurityBots),
          _moreCard(
              Icons.admin_panel_settings_rounded,
              'Production Readiness',
              'Owner-only service health, backups and operations',
              onProductionReadiness),
          _moreCard(Icons.security_rounded, 'Security & Privacy',
              'Sessions, MFA and account security', onSecurityPrivacy),
          _moreCard(
              Icons.accessibility_new_rounded,
              'Accessibility & Offline',
              'Text scaling, activity privacy and pending sync',
              onAccessibilityOffline),
        ],
      ),
    );
  }

  Widget _combinedCard(BuildContext context, IconData icon, String title,
      String subtitle, List<_MoreChoice> choices) {
    return Material(
      color: Colors.white.withValues(alpha: .045),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (choiceContext) => _PremiumSheet(
            title: title,
            subtitle: subtitle,
            child: Column(
                mainAxisSize: MainAxisSize.min,
                children: choices
                    .map((choice) => ListTile(
                          leading: Icon(choice.icon),
                          title: Text(choice.title),
                          subtitle: Text(choice.subtitle),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            Navigator.of(choiceContext).pop();
                            choice.onSelected();
                          },
                        ))
                    .toList()),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 26),
                const SizedBox(height: 8),
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 11)),
              ]),
        ),
      ),
    );
  }

  Widget _moreCard(
      IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Material(
      color: Colors.white.withValues(alpha: .045),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 26),
              const SizedBox(height: 8),
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// HOME
// ============================================================

class HomeScreen extends StatefulWidget {
  final VoidCallback? onRefresh;
  final VoidCallback? onNotifications;
  final HomeCustomization? previewSettings;
  final bool showAppBar;

  const HomeScreen({
    super.key,
    this.onRefresh,
    this.onNotifications,
    this.previewSettings,
    this.showAppBar = true,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// Implements the `_HomeScreenState` class for this feature or UI component.
class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _heroController;

  @override

  /// Performs `initState` for this feature. Update this documentation when its contract changes.
  void initState() {
    super.initState();
    // Keep Home previewable before a home-server scan completes; Smart Search
    // can immediately find the explicitly labeled, non-playable demo entries.
    AppController.instance.ensureDemoPreviewMedia(notify: false);
    // Seed personalized New Albums and library-aware music discovery as soon
    // as the active profile opens Home (rather than waiting for the Music tab).
    unawaited(MusicLibraryStore.instance.initializeForProfile(
      AppController.instance.currentProfile?.id,
    ));
    if (AppController.instance.backendApi.isAuthenticated) {
      unawaited(_syncHomeServerMedia());
    }
    StoryPlacementStore.revision.addListener(_onStoryPlacementChanged);
    HomeCustomizationStore.revision.addListener(_onHomeCustomizationChanged);
    unawaited(_loadStoryPlacement());
    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    )..forward();
  }

  Future<void> _syncHomeServerMedia() async {
    try {
      await AppController.instance.syncHomeServerLibrary();
    } catch (_) {
      // Local preview media stays available even when the server is offline.
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadStoryPlacement() async {
    await StoryPlacementStore.load(AppController.instance.currentProfile);
    if (mounted) setState(() {});
  }

  void _onStoryPlacementChanged() {
    if (mounted) setState(() {});
  }

  void _onHomeCustomizationChanged() {
    if (mounted) setState(() {});
  }

  @override

  /// Performs `dispose` for this feature. Update this documentation when its contract changes.
  void dispose() {
    StoryPlacementStore.revision.removeListener(_onStoryPlacementChanged);
    HomeCustomizationStore.revision.removeListener(_onHomeCustomizationChanged);
    _heroController.dispose();
    super.dispose();
  }

  void _showHomeExploreMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _PremiumSheet(
        title: 'Explore',
        subtitle:
            'More ways to discover your movies, shows, music and collections.',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.timeline_rounded),
              title: const UniversalText('Release Order'),
              subtitle: const UniversalText(
                  'Browse movies, shows and albums grouped by release year.'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(sheetContext).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    settings:
                        const RouteSettings(name: '/app/page/release-order'),
                    builder: (_) => const ReleaseOrderTimelineScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.hub_rounded),
              title: const UniversalText('Media Universe'),
              subtitle: const UniversalText(
                  'Explore titles, connected franchises, people and artwork.'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(sheetContext).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    settings: const RouteSettings(name: '/app/media-universe'),
                    builder: (_) => const MediaUniverseScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Performs `_refresh` for this feature. Update this documentation when its contract changes.
  Future<void> _refresh() async {
    final controller = AppController.instance;
    if (controller.backendApi.isAuthenticated) {
      await controller.loadRecommendations();
      await controller.loadGroupWishlist();
      await controller.loadGroupRecommendations();
    }
    widget.onRefresh?.call();
    if (mounted) setState(() {});
  }

  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    final controller = AppController.instance;
    final profile = controller.currentProfile;

    if (profile == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF070707),
        body: Center(child: UniversalText('No profile selected.')),
      );
    }

    final library = controller.library
        .where((media) => media.isAccessibleTo(profile))
        .toList(growable: false);
    final settings = widget.previewSettings ??
        HomeCustomizationStore.settingsFor(
            AppController.instance.currentProfile);
    final homeBackground = colorFromName(settings.homeBackgroundColor);

    final watched = controller.watched
        .where((media) => media.isAccessibleTo(profile))
        .toList(growable: false);
    final movies = internationalCatalogFirst(
      library.where((media) => media.type.toLowerCase() == 'movie'),
    );
    final tvShows = internationalCatalogFirst(library.where((media) {
      final type = media.type.toLowerCase();
      return type == 'tvshow' || type == 'tv_show' || type == 'tv show';
    }));
    // Compute personalized ranking once per Home build rather than once per
    // section, keeping search/discovery overhead bounded on larger libraries.
    final homeRecommendations = SmartSearch.recommendations(library);
    // Prefer personalized, recently watched, and then remaining library titles
    // for the rotating hero. Deduplicate so a title never repeats in one cycle.
    final homeHeroItems = <MediaItem>[];
    final homeHeroSeen = <String>{};
    final homeHeroCandidates = <MediaItem>[
      ...homeRecommendations
          .where((item) => item.imageUrl?.trim().isNotEmpty == true),
      ...watched.where((item) => item.imageUrl?.trim().isNotEmpty == true),
      ...library.where((item) => item.imageUrl?.trim().isNotEmpty == true),
      ...homeRecommendations,
      ...watched,
      ...library,
    ];
    final configuredHeroCount = settings.heroItemCount.clamp(1, 40).toInt();
    for (final item in homeHeroCandidates) {
      if (homeHeroSeen.add(item.id)) {
        homeHeroItems.add(item);
        if (homeHeroItems.length >= configuredHeroCount) break;
      }
    }
    // If the catalog is sparse, show the titles available up to the configured
    // count, rather than silently reverting to every catalog item.
    if (homeHeroItems.isEmpty && library.isNotEmpty) {
      homeHeroItems.addAll(library.take(configuredHeroCount));
    }

    return Scaffold(
      backgroundColor: homeBackground,
      body: RefreshIndicator(
        color: Colors.white,
        backgroundColor: const Color(0xFF171717),
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (widget.showAppBar)
              SliverAppBar(
                pinned: true,
                floating: true,
                automaticallyImplyLeading: false,
                elevation: 0,
                backgroundColor: const Color(0xE6070707),
                surfaceTintColor: Colors.transparent,
                titleSpacing: 20,
                title: const UniversalText(
                  'Home',
                  style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1),
                ),
                actions: [
                  PageCustomizeButton(pageId: 'home'),
                  ActivityButton(onPressed: widget.onNotifications),
                  const SizedBox(width: 8),
                ],
              ),
            SliverToBoxAdapter(
              child: HomeBrowseNavigation(
                onExplore: _showHomeExploreMenu,
                onMovies: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      settings: const RouteSettings(name: '/app/page/movies'),
                      builder: (_) => const MoviesScreen(),
                    )),
                onShows: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      settings: const RouteSettings(name: '/app/page/series'),
                      builder: (_) => const SeriesScreen(),
                    )),
                onMusic: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      settings: const RouteSettings(name: '/app/page/music'),
                      builder: (_) => const MusicScreen(),
                    )),
                onPhysicalMedia: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      settings:
                          const RouteSettings(name: '/app/physical-media'),
                      builder: (_) => const PhysicalMediaLibraryScreen(),
                    )),
                onLiveTv: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      settings: const RouteSettings(name: '/app/watch/live-tv'),
                      builder: (_) => const PublicLiveTvScreen(),
                    )),
                onMyTv: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      settings: const RouteSettings(name: '/app/watch/my-tv'),
                      builder: (_) => const MyTvScreen(),
                    )),
              ),
            ),
            if (library.isEmpty && homeRecommendations.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        UniversalText('Your library is empty',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 25, fontWeight: FontWeight.w800)),
                        SizedBox(height: 8),
                        UniversalText(
                            'Please add using the 3 dots in the navbar.',
                            textAlign: TextAlign.center,
                            style:
                                TextStyle(color: Colors.white54, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ),
            for (final section in settings.sectionOrder)
              ..._buildHomeSectionSlivers(
                context,
                section,
                settings,
                watched,
                movies,
                tvShows,
                library,
                homeRecommendations,
                homeHeroItems: homeHeroItems,
                heroController: _heroController,
                profile: profile,
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

String _normalizeOwnedAlbumLookup(String value) => value.toLowerCase().trim().replaceAll(
      RegExp(r"[\s\-_.,:;!?()\[\]{}\\/]+"),
      '',
    );

List<Map<String, dynamic>> _localTracksForHomeAlbum(String title, String artist) {
  final wantedTitle = _normalizeOwnedAlbumLookup(title);
  final wantedArtist = _normalizeOwnedAlbumLookup(artist);
  if (wantedTitle.isEmpty) return <Map<String, dynamic>>[];
  final titleMatches = MusicLibraryStore.instance.tracks
      .where((track) => !track.id.startsWith('demo-catalog-track-') &&
          !track.id.startsWith('demo-preview-album-track-') &&
          _normalizeOwnedAlbumLookup(track.album) == wantedTitle)
      .toList(growable: false);
  if (titleMatches.isEmpty) return <Map<String, dynamic>>[];
  final artistMatches = wantedArtist.isEmpty
      ? titleMatches
      : titleMatches.where((track) {
          final candidateArtist = _normalizeOwnedAlbumLookup(track.artist);
          return candidateArtist.isNotEmpty &&
              (candidateArtist == wantedArtist ||
                  candidateArtist.contains(wantedArtist) ||
                  wantedArtist.contains(candidateArtist));
        }).toList(growable: false);
  // Don't mark a same-title release by a different artist as owned.
  final selected = wantedArtist.isEmpty ? titleMatches : artistMatches;
  return [
    for (var index = 0; index < selected.length; index++)
      <String, dynamic>{
        'id': selected[index].id,
        'title': selected[index].title,
        'artist': selected[index].artist,
        'album': selected[index].album,
        'durationMs': selected[index].duration.inMilliseconds,
        'trackNumber': index + 1,
        'artworkUrl': selected[index].artworkUrl ?? '',
        'audioUrl': selected[index].audioUrl ?? '',
      },
  ];
}

bool _isAlbumInLocalMusicLibrary(String title, String artist) =>
    _localTracksForHomeAlbum(title, artist).isNotEmpty;

void _playHomeAlbumLocalTrack(Map<String, dynamic> row) {
  final id = row['id']?.toString() ?? '';
  if (id.isEmpty) return;
  for (final track in MusicLibraryStore.instance.tracks) {
    if (track.id == id && (track.audioUrl?.trim().isNotEmpty ?? false)) {
      unawaited(MusicPlaybackController.instance.play(track));
      return;
    }
  }
}

final Map<String, String> _homeAlbumHoverPreviewTrackIds = <String, String>{};

void _handleHomeAlbumHover(String albumTitle, String artistName, bool hovering) {
  final key = '${_normalizeOwnedAlbumLookup(artistName)}|${_normalizeOwnedAlbumLookup(albumTitle)}';
  final playback = MusicPlaybackController.instance;
  if (hovering) {
    final candidates = MusicLibraryStore.instance.tracks.where((track) =>
      !track.id.startsWith('demo-catalog-track-') &&
      !track.id.startsWith('demo-preview-album-track-') &&
      (track.audioUrl?.trim().isNotEmpty ?? false) &&
      _normalizeOwnedAlbumLookup(track.album) == _normalizeOwnedAlbumLookup(albumTitle) &&
      _normalizeOwnedAlbumLookup(track.artist) == _normalizeOwnedAlbumLookup(artistName)).toList(growable: false);
    if (candidates.isEmpty) return;
    final index = DateTime.now().microsecondsSinceEpoch.abs() % candidates.length;
    final track = candidates[index];
    _homeAlbumHoverPreviewTrackIds[key] = track.id;
    unawaited(playback.play(track));
    return;
  }
  final previewId = _homeAlbumHoverPreviewTrackIds.remove(key);
  if (previewId != null && playback.currentTrack?.id == previewId && playback.isPlaying) {
    unawaited(playback.toggle());
  }
}

List<Widget> _buildHomeSectionSlivers(
  BuildContext context,
  String section,
  HomeCustomization settings,
  List<MediaItem> watched,
  List<MediaItem> movies,
  List<MediaItem> tvShows,
  List<MediaItem> library,
  List<MediaItem> recommendations, {
  required List<MediaItem> homeHeroItems,
  required AnimationController heroController,
  required Profile? profile,
}) {
  if (!settings.isSectionVisible(section)) return const <Widget>[];

  switch (section) {
    case 'Hero Banner':
      if (homeHeroItems.isEmpty) return const <Widget>[];
      return <Widget>[
        SliverToBoxAdapter(
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: heroController,
              curve: Curves.easeOut,
            ),
            child: HomeHeroCarousel(
              items: homeHeroItems,
              settingsKey: 'home',
              // More Info must always show details, even when the media has a playable file.
              onOpen: (media) => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  settings: const RouteSettings(name: '/app/details'),
                  builder: (_) => MediaDetailsScreen(media: media),
                ),
              ),
              onPlay: (media) => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  settings: const RouteSettings(name: '/app/player'),
                  builder: (_) => PlayerScreen(media: media),
                ),
              ),
            ),
          ),
        ),
      ];
    case 'Recommendations & Mood':
      return <Widget>[
        SliverToBoxAdapter(
          child: HomeCinematicRecommendationsSection(
            watched: watched,
            library: library,
          ),
        ),
      ];
    case 'Franchise Progress':
      return const <Widget>[SliverToBoxAdapter(child: HomeFranchiseSagaHub())];
    case 'Channels':
      return const <Widget>[SliverToBoxAdapter(child: HomeChannelsSection())];
    case 'Media Intelligence Tools':
      return const <Widget>[SliverToBoxAdapter(child: HomeMediaIntelligenceToolsShelf())];
    case 'Friends Stories':
      return profile != null && StoryPlacementStore.showsOnHome(profile)
          ? <Widget>[
              SliverToBoxAdapter(
                child: FriendsStoriesStrip(profileId: profile.id),
              ),
            ]
          : const <Widget>[];
    case 'Storage Progress':
      return settings.storageBarPosition != 'Hidden'
          ? <Widget>[
              SliverToBoxAdapter(
                child: HomeStorageProgressBar(
                  thickness: settings.storageBarThickness,
                  axis: Axis.horizontal,
                ),
              ),
            ]
          : const <Widget>[];
    case 'Movies by Country':
      return _countryShelfSlivers(items: movies, sectionLabel: 'Movies');
    case 'Shows by Country':
      return _countryShelfSlivers(items: tvShows, sectionLabel: 'Shows');
    case "This Week's Top 10 Movies":
      return <Widget>[SliverToBoxAdapter(child: WeeklyTop10Shelf(chartKey: 'movies', title: "THIS WEEK'S TOP 10 MOVIES"))];
    case "This Week's Top 10 Shows":
      return <Widget>[SliverToBoxAdapter(child: WeeklyTop10Shelf(chartKey: 'shows', title: "THIS WEEK'S TOP 10 SHOWS"))];
    case "This Week's Top 10 Albums":
      return <Widget>[SliverToBoxAdapter(child: WeeklyTop10Shelf(chartKey: 'albums', title: "THIS WEEK'S TOP 10 ALBUMS"))];
    case "This Week's Top 10 Songs":
      return <Widget>[SliverToBoxAdapter(child: WeeklyTop10Shelf(chartKey: 'songs', title: "THIS WEEK'S TOP 10 SONGS"))];
    case "This Week's Top 10 Actors":
      return <Widget>[SliverToBoxAdapter(child: WeeklyTop10Shelf(chartKey: 'actors', title: "THIS WEEK'S TOP 10 ACTORS"))];
    case "This Week's Top 10 Actresses":
      return <Widget>[SliverToBoxAdapter(child: WeeklyTop10Shelf(chartKey: 'actresses', title: "THIS WEEK'S TOP 10 ACTRESSES"))];
    case "This Week's Top 10 Singers":
      return <Widget>[SliverToBoxAdapter(child: WeeklyTop10Shelf(chartKey: 'singers', title: "THIS WEEK'S TOP 10 SINGERS"))];
    case "This Week's Top 10 Bands":
      return <Widget>[SliverToBoxAdapter(child: WeeklyTop10Shelf(chartKey: 'bands', title: "THIS WEEK'S TOP 10 BANDS"))];
    case 'Ranking of All Top 10s':
      return const <Widget>[SliverToBoxAdapter(child: WeeklyTop10LeaderboardShelf())];
    case 'New Albums':
      return <Widget>[
        SliverToBoxAdapter(
          child: SpotifyHomeAlbumsShelf(
            isOwnedAlbum: _isAlbumInLocalMusicLibrary,
            localTracksForAlbum: _localTracksForHomeAlbum,
            prepareMusicLibrary: () => MusicLibraryStore.instance.initializeForProfile(
              AppController.instance.currentProfile?.id,
            ),
            ownedArtistNames: () {
              final tracks = MusicLibraryStore.instance.tracks
                  .where((track) => !track.id.startsWith('demo-catalog-track-') &&
                      !track.id.startsWith('demo-preview-album-track-'));
              final names = <String>{};
              for (final track in tracks) {
                final primary = track.artist.trim();
                if (primary.isNotEmpty) names.add(primary);
                for (final featured in track.featuredArtists) {
                  if (featured.trim().isNotEmpty) names.add(featured.trim());
                }
              }
              return names.toList(growable: false);
            },
            onAlbumHover: _handleHomeAlbumHover,
            onPlayLocalTrack: _playHomeAlbumLocalTrack,
          ),
        ),
      ];
    case 'Continue Watching':
      return _homeMediaRail(section, watched, 'Pick up where you left off');
    case 'Recently Watched':
      return _homeMediaRail(section, watched, 'What you watched recently');
    case 'Movies':
      return _homeMediaRail(section, movies, 'From your collection');
    case 'TV Shows':
      return _homeMediaRail(section, tvShows, 'Your series collection');
    case 'New Additions':
      final items = List<MediaItem>.from(library)
        ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
      return _homeMediaRail(section, items, 'Recently added to your library');
    case 'All Library':
      return _homeMediaRail(section, library, 'Everything in your library');
    case 'Library Recommendations':
      return _homeMediaRail(section, recommendations, 'Picked for your profile');
    case 'Themed Episodes':
      return const <Widget>[SliverToBoxAdapter(child: HomeThemedEpisodesSection())];
    case 'You Might Also Like':
      return <Widget>[
        SliverToBoxAdapter(
          child: HomeYouMayAlsoLikeSection(library: library, watched: watched),
        ),
      ];
    case 'Collections':
      return const <Widget>[SliverToBoxAdapter(child: HomeCollectionShelves())];
    case 'Because You Watched':
      return <Widget>[
        SliverToBoxAdapter(
          child: HomeReasonedRecommendationShelves(library: library, watched: watched),
        ),
      ];
    case 'People & Cast Recommendations':
      return <Widget>[
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HomeBecauseYouWatchedPeopleShelves(library: library, watched: watched),
              HomeExternalPeopleRecommendationShelves(watched: watched),
            ],
          ),
        ),
      ];
    case 'Friends & Communities':
      return <Widget>[
        SliverToBoxAdapter(
          child: SocialHomeSection(
            key: ValueKey(AppController.instance.currentProfile?.id),
          ),
        ),
      ];
    case 'Music & Film':
      return settings.showMusic
          ? <Widget>[SliverToBoxAdapter(child: _HomeContinueListeningSection())]
          : const <Widget>[];
    case 'Seasonal Collections':
      return <Widget>[SliverToBoxAdapter(child: _HomeSeasonalCollections())];
    default:
      return const <Widget>[];
  }
}

List<Widget> _homeMediaRail(
  String title,
  List<MediaItem> items,
  String subtitle,
) {
  if (items.isEmpty) return const <Widget>[];
  return <Widget>[
    SliverToBoxAdapter(
      child: _PremiumSectionHeader(
        title: title == 'Library Recommendations' ? 'Recommended for You' : title,
        subtitle: subtitle,
      ),
    ),
    SliverToBoxAdapter(
      child: MediaHorizontalList(
        media: items,
        showOwnership: title == 'Library Recommendations',
        enableHomePreview: true,
      ),
    ),
  ];
}

List<Widget> _countryShelfSlivers({
  required List<MediaItem> items,
  required String sectionLabel,
}) {
  final grouped = <String, List<MediaItem>>{};
  for (final media in items) {
    for (final country in mediaCountryOriginParts(media)) {
      final bucket = grouped.putIfAbsent(country, () => <MediaItem>[]);
      if (!bucket.any((entry) => entry.id == media.id)) bucket.add(media);
    }
  }
  final countries = grouped.keys.toList()
    ..sort((a, b) {
      final byCount = grouped[b]!.length.compareTo(grouped[a]!.length);
      return byCount != 0 ? byCount : a.toLowerCase().compareTo(b.toLowerCase());
    });
  final result = <Widget>[];
  for (final country in countries) {
    final titles = grouped[country]!;
    // Use the familiar US label for American shelves while retaining the
    // canonical full country name in metadata and country matching.
    final displayCountry = country == 'United States' ? 'US' : country;
    result.add(SliverToBoxAdapter(
      child: _PremiumSectionHeader(
        title: '$sectionLabel from $displayCountry',
        subtitle: '${titles.length} ${titles.length == 1 ? 'title' : 'titles'} • Country of origin',
      ),
    ));
    result.add(SliverToBoxAdapter(
      child: MediaHorizontalList(media: titles, enableHomePreview: true),
    ));
  }
  return result;
}

String _homeSectionDescription(String section) => switch (section) {
      'Hero Banner' => 'Featured movie/show artwork near the top of Home.',
      'Recommendations & Mood' => 'TMDB recommendations and mood-based discovery.',
      'Franchise Progress' => 'Saga timelines and franchise completion progress.',
      'Channels' => 'Channel shortcuts, including live TV and curated channels.',
      'Friends Stories' => 'Stories shared by friends on the Home page.',
      'Storage Progress' => 'Local/server storage progress bar.',
      'Continue Watching' => 'Resume movies and episodes you started.',
      'Themed Episodes' => 'Seasonal and themed episode recommendations.',
      'You Might Also Like' => 'Suggestions based on your viewing history.',
      'Collections' => 'Curated, automatic, and personal collection shelves.',
      'Because You Watched' => 'Explainable recommendations related to recent viewing.',
      'People & Cast Recommendations' => 'More titles connected by known cast and creators.',
      'Library Recommendations' => 'Recommendations already available in your catalog.',
      'Friends & Communities' => 'Friend feed, suggestions, and communities.',
      'Recently Watched' => 'Titles you watched most recently.',
      'Movies' => 'Your movie collection.',
      'TV Shows' => 'Your TV collection.',
      'New Additions' => 'Recently imported movies and shows.',
      'All Library' => 'Every title in your library in one shelf.',
      'Movies by Country' => 'Separate movie shelves grouped by the recorded country of origin.',
      'Shows by Country' => 'Separate show shelves grouped by the recorded country of origin.',
      'New Albums' => 'New album covers from Spotify.',
      "This Week's Top 10 Movies" => "TMDB's weekly trending movie chart.",
      "This Week's Top 10 Shows" => "TMDB's weekly trending TV chart.",
      "This Week's Top 10 Albums" => "Albums ranked by this profile's listening activity.",
      "This Week's Top 10 Songs" => "Songs ranked by this profile's listening activity.",
      "This Week's Top 10 Actors" => 'Trending screen actors from TMDB this week.',
      "This Week's Top 10 Actresses" => 'Trending screen actresses from TMDB this week.',
      "This Week's Top 10 Singers" => "Singers ranked from this profile's listening activity.",
      "This Week's Top 10 Bands" => "Bands ranked from this profile's listening activity.",
      'Ranking of All Top 10s' => 'Open the leaderboard for all eight weekly Top 10 charts.',
      'Music & Film' => 'Resume locally playable music.',
      'Seasonal Collections' => 'Calendar-based collections for the current season.',
      'Media Intelligence Tools' => 'Discovery, insight, and media tools.',
      _ => 'Show or hide this section on Home.',
    };

/// Personalized Home rail for tracks the active profile can resume or replay.
/// Only tracks with a server-provided audio URL are offered for direct playback.
class _HomeContinueListeningSection extends StatefulWidget {
  @override
  State<_HomeContinueListeningSection> createState() =>
      _HomeContinueListeningSectionState();
}

class _HomeContinueListeningSectionState
    extends State<_HomeContinueListeningSection> {
  @override
  void initState() {
    super.initState();
    unawaited(MusicLibraryStore.instance.initializeForProfile(
      AppController.instance.currentProfile?.id,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: MusicLibraryStore.instance,
      builder: (context, _) {
        return AnimatedBuilder(
          animation: MusicPlaybackController.instance,
          builder: (context, _) {
            final store = MusicLibraryStore.instance;
            final current = MusicPlaybackController.instance.currentTrack;
            final tracks = store.tracks
                .where((track) => track.audioUrl?.trim().isNotEmpty == true)
                .toList()
              ..sort((a, b) => (store.listenCounts[b.id] ?? 0)
                  .compareTo(store.listenCounts[a.id] ?? 0));
            if (current != null &&
                current.audioUrl?.trim().isNotEmpty == true) {
              tracks.removeWhere((track) => track.id == current.id);
              tracks.insert(0, current);
            }
            if (tracks.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _PremiumSectionHeader(
                  title: 'Continue Listening',
                  subtitle: 'Pick up your music where you left off',
                ),
                HomeArrowRail(
                  height: 176,
                  itemCount: tracks.take(12).length,
                  separatorExtent: 12,
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  itemBuilder: (context, index) {
                    final track = tracks[index];
                    final playing = current?.id == track.id &&
                        MusicPlaybackController.instance.isPlaying;
                    return _HomeMusicPreviewCard(
                      key: ValueKey<String>(track.id),
                      track: track,
                      playing: playing,
                      onTap: () {
                        final playback = MusicPlaybackController.instance;
                        if (playback.currentTrack?.id == track.id &&
                            playback.isReady) {
                          unawaited(playback.toggle());
                        } else {
                          unawaited(playback.play(track));
                        }
                      },
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            );
          },
        );
      },
    );
  }
}

class _HomeMusicPreviewCard extends StatefulWidget {
  const _HomeMusicPreviewCard({
    super.key,
    required this.track,
    required this.playing,
    required this.onTap,
  });

  final MusicTrack track;
  final bool playing;
  final VoidCallback onTap;

  @override
  State<_HomeMusicPreviewCard> createState() => _HomeMusicPreviewCardState();
}

class _HomeMusicPreviewCardState extends State<_HomeMusicPreviewCard> {
  bool _hovering = false;

  String get _previewId => 'home-song-${widget.track.id}';

  MediaItem get _previewMedia => MediaItem(
        id: _previewId,
        title: widget.track.title,
        type: 'song',
        imageUrl: widget.track.artworkUrl,
        description: '${widget.track.artist} • ${widget.track.album}',
        trailerUrl: widget.track.musicVideoUrl,
        music: <String>[widget.track.artist, ...widget.track.featuredArtists],
        genres: widget.track.allGenreTags,
      );

  void _enter() {
    if (!_hovering && mounted) setState(() => _hovering = true);
    HomeHoverPreviewStore.show(_previewMedia);
  }

  void _exit() {
    if (_hovering && mounted) setState(() => _hovering = false);
    HomeHoverPreviewStore.clear(_previewId);
  }

  @override
  void dispose() {
    if (_hovering) HomeHoverPreviewStore.clear(_previewId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.track;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _enter(),
      onExit: (_) => _exit(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: _hovering ? 164 : 136,
        child: Material(
          color: _hovering
              ? Colors.white.withValues(alpha: .09)
              : Colors.white.withValues(alpha: .045),
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox.expand(
                        child: track.artworkUrl?.trim().isNotEmpty == true
                            ? Image.network(
                                track.artworkUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const ColoredBox(
                                  color: Color(0xFF252525),
                                  child: Center(
                                    child: Icon(Icons.music_note_rounded, size: 36),
                                  ),
                                ),
                              )
                            : const ColoredBox(
                                color: Color(0xFF252525),
                                child: Center(
                                  child: Icon(Icons.music_note_rounded, size: 36),
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      if (widget.playing)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(
                            Icons.graphic_eq_rounded,
                            size: 14,
                            color: Colors.greenAccent,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Colors.white60),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Calendar-aware Home section using only media already owned by the account.
class _HomeSeasonalCollections extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final title = SeasonalCollectionEngine.titleFor(DateTime.now());
    final matches = SeasonalCollectionEngine.matching(
      AppController.instance.library,
    );
    final songs = SeasonalCollectionEngine.matchingSongs(
      MusicLibraryStore.instance.tracks,
    );
    final total = matches.length + songs.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .045),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: .07)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_month_rounded),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w900),
                  ),
                ),
                UniversalText(
                  '$total items',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 5),
            const UniversalText(
              'Seasonal collection • movies, TV episodes/shows and songs • updates with the calendar',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (total == 0)
              const UniversalText(
                'No matching titles in your library yet.',
                style: TextStyle(color: Colors.white38),
              )
            else
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount:
                      (matches.length + songs.length).clamp(0, 8).toInt(),
                  separatorBuilder: (_, __) => const SizedBox(width: 9),
                  itemBuilder: (_, index) => Container(
                    width: 150,
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .04),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      index < matches.length
                          ? matches[index].title
                          : songs[index - matches.length].title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  settings: const RouteSettings(name: '/app/page/collections'),
                  builder: (_) => const SeasonalCollectionsScreen(),
                ),
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 17),
              label: const UniversalText('OPEN SEASONAL COLLECTION'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Implements the `_HomeMusicFilmChooser` class for this feature or UI component.
/// Implements the `_PremiumSectionHeader` class for this feature or UI component.
class _PremiumSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _PremiumSectionHeader({required this.title, required this.subtitle});

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    final countryMatch = RegExp(r'^(Movies|Shows) from (.+)$').firstMatch(title);
    final titleStyle = const TextStyle(fontSize: 22, fontWeight: FontWeight.w800);
    final Widget titleWidget;
    if (countryMatch == null) {
      titleWidget = Text(title, style: titleStyle);
    } else {
      final mediaKind = countryMatch.group(1)!;
      final country = countryMatch.group(2)!.trim();
      final palette = countryFlagColorsForName(country);
      final gradientColors = palette.length >= 2 ? palette : const <Color>[Colors.white, Colors.white];
      titleWidget = Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 2,
        children: [
          Text('$mediaKind from', style: titleStyle),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white.withValues(alpha: .12)),
            ),
            child: Text(
              countryFlagEmojiForName(country),
              style: const TextStyle(fontSize: 21, height: 1.05),
            ),
          ),
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => LinearGradient(
              colors: gradientColors,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ).createShader(bounds),
            child: Text(country, style: titleStyle.copyWith(color: Colors.white)),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleWidget,
          const SizedBox(height: 3),
          Text(subtitle,
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }
}

/// Country flag emojis carry the detailed national emblems (for example, the
/// US stars, Mexico's coat of arms, Canada's maple leaf and the UK Union Jack).
/// This mapping normalizes provider spellings and common aliases to ISO alpha-2.
// ============================================================
// ACTIVITY BUTTON
// ============================================================

class ActivityButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const ActivityButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final controller = AppController.instance;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => IconButton(
        tooltip: tr('Notifications'),
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.notifications_outlined),
            if (controller.unreadActivityCount > 0)
              Positioned(
                right: -1,
                top: -1,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        onPressed: onPressed ??
            () {
              showModalBottomSheet<void>(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (_) => const _ActivitySheet(),
              );
            },
      ),
    );
  }
}

/// Shared presentation container for More/notification sheets.
class _PremiumSheet extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _PremiumSheet({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * .78;

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: .08)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.white54)),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Activity/notification sheet backed by the local account activity feed.
class _ActivitySheet extends StatefulWidget {
  const _ActivitySheet();

  @override
  State<_ActivitySheet> createState() => _ActivitySheetState();
}

class _ActivitySheetState extends State<_ActivitySheet> {
  final AppController _controller = AppController.instance;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onActivityChanged);
    unawaited(_controller.loadActivity());
  }

  void _onActivityChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onActivityChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activity = _controller.activity;
    return _PremiumSheet(
      title: tr('Notifications'),
      subtitle: activity.isEmpty
          ? 'You are all caught up'
          : '${_controller.unreadActivityCount} unread · ${activity.length} recent',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (activity.isNotEmpty)
            Row(
              children: [
                TextButton.icon(
                  onPressed: _controller.unreadActivityCount == 0
                      ? null
                      : _controller.markAllActivityRead,
                  icon: const Icon(Icons.done_all_rounded, size: 18),
                  label: const UniversalText('Mark all read'),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _controller.clearActivity,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const UniversalText('Clear all'),
                ),
              ],
            ),
          if (activity.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 42),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none_rounded,
                      size: 54, color: Colors.white38),
                  SizedBox(height: 12),
                  UniversalText('No activity yet.',
                      style: TextStyle(color: Colors.white60)),
                  SizedBox(height: 6),
                  UniversalText(
                      'Messages, likes, playback, and other activity will appear here.',
                      style: TextStyle(color: Colors.white38),
                      textAlign: TextAlign.center),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activity.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, index) {
                final event = activity[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _controller.markActivityRead(event.id),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: event.read
                          ? Colors.white.withValues(alpha: .025)
                          : const Color(0x22E53935),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: event.read
                            ? Colors.white10
                            : Colors.red.withValues(alpha: .25),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: event.read
                              ? Colors.white10
                              : const Color(0x22FF0000),
                          child: Icon(
                            event.read
                                ? Icons.notifications_none_rounded
                                : Icons.notifications_active_rounded,
                            size: 20,
                            color:
                                event.read ? Colors.white54 : Colors.redAccent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(event.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text(event.action,
                                  style:
                                      const TextStyle(color: Colors.white70)),
                              const SizedBox(height: 5),
                              Text(
                                MaterialLocalizations.of(context)
                                    .formatFullDate(event.timestamp),
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        if (!event.read)
                          const Padding(
                            padding: EdgeInsets.only(left: 8, top: 3),
                            child: Icon(Icons.circle,
                                size: 8, color: Colors.redAccent),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

// ============================================================
// SECTION TITLE
// ============================================================

class SectionTitle extends StatelessWidget {
  final String title;

  const SectionTitle({
    super.key,
    required this.title,
  });

  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ============================================================
// MEDIA HORIZONTAL LIST
// ============================================================

class MediaHorizontalList extends StatelessWidget {
  final List<MediaItem> media;
  final bool showOwnership;
  final bool enableHomePreview;

  const MediaHorizontalList({
    super.key,
    required this.media,
    this.showOwnership = false,
    this.enableHomePreview = false,
  });

  @override
  Widget build(BuildContext context) {
    return HomeArrowRail(
      height: 245,
      itemCount: media.length,
      separatorExtent: 12,
      padding: const EdgeInsets.symmetric(horizontal: 48),
      itemBuilder: (context, index) => MediaCard(
        media: media[index],
        showOwnership: showOwnership,
        enableHomePreview: enableHomePreview,
      ),
    );
  }
}

// ============================================================
// MEDIA CARD
// ============================================================

class MediaCard extends StatefulWidget {
  final MediaItem media;
  final bool showOwnership;
  final bool enableHomePreview;

  const MediaCard({
    super.key,
    required this.media,
    this.showOwnership = false,
    this.enableHomePreview = false,
  });

  @override
  State<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<MediaCard> {
  bool _hovering = false;

  @override
  void dispose() {
    if (_hovering && widget.enableHomePreview) {
      HomeHoverPreviewStore.clear(widget.media.id);
    }
    super.dispose();
  }

  void _setHovering(bool value) {
    if (_hovering != value && mounted) setState(() => _hovering = value);
    if (!widget.enableHomePreview) return;
    if (value) {
      HomeHoverPreviewStore.show(widget.media);
    } else {
      HomeHoverPreviewStore.clear(widget.media.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.media;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _setHovering(true),
      onExit: (_) => _setHovering(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: _hovering && widget.enableHomePreview ? 180 : 145,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: _hovering && widget.enableHomePreview
              ? [BoxShadow(color: Colors.black.withValues(alpha: .55), blurRadius: 26, offset: const Offset(0, 8))]
              : const [],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (widget.enableHomePreview) HomeHoverPreviewStore.clear(media.id);
            final normalizedType = media.type.trim().toLowerCase();
            final isAlbum = normalizedType.contains('album') || normalizedType == 'soundtrack';
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => isAlbum
                    ? CatalogAlbumDetailsEntryScreen(media: media)
                    : MediaDetailsScreen(media: media),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AnimatedScale(
                        scale: _hovering && widget.enableHomePreview ? 1.045 : 1,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        child: CatalogPosterImage(
                          media: media,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: Container(
                            color: Colors.grey.shade900,
                            alignment: Alignment.center,
                            child: const Icon(Icons.movie, size: 45),
                          ),
                          errorPlaceholder: Container(
                            color: Colors.grey.shade900,
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image),
                          ),
                        ),
                      ),
                      if (_hovering && widget.enableHomePreview)
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.black.withValues(alpha: .05), Colors.black.withValues(alpha: .84)],
                              ),
                            ),
                          ),
                        ),
                      if (_hovering && widget.enableHomePreview)
                        Center(
                          child: Container(
                            width: 48, height: 48,
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 30),
                          ),
                        ),
                      if (_hovering && widget.enableHomePreview)
                        Positioned(
                          left: 10, right: 10, bottom: 10,
                          child: Text(
                            media.title,
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: CinematicTitleFonts.captionStyle(
                              media, baseFontSize: 15, color: Colors.white,
                            ).copyWith(fontWeight: FontWeight.w900, shadows: const [Shadow(color: Colors.black87, blurRadius: 12)]),
                          ),
                        ),
                      if (widget.showOwnership)
                        Positioned(
                          top: 6, left: 6,
                          child: RecommendationOwnershipBadge(
                            isOwned: AppController.instance.isOwned(media.id),
                            compact: true,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                media.title,
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: CinematicTitleFonts.captionStyle(
                  media, baseFontSize: 13.2, color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              if (media.displayYearLabel != null)
                Text(
                  [media.displayYearLabel!, if (media.displayEditionLabel != null) media.displayEditionLabel!].join(' • '),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              if (media.isSeries || const <String>{'movie', 'film'}.contains(media.type.trim().toLowerCase()))
                Text(
                  'Origin: ${mediaCountryOriginLabel(media)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 10.5),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Resolves a local album catalogue card to provider album metadata when
/// an exact title/artist match exists. The original local title is never
/// rewritten. On a miss, keep the app's normal details screen available.
class CatalogAlbumDetailsEntryScreen extends StatefulWidget {
  const CatalogAlbumDetailsEntryScreen({super.key, required this.media});

  final MediaItem media;

  @override
  State<CatalogAlbumDetailsEntryScreen> createState() =>
      _CatalogAlbumDetailsEntryScreenState();
}

class _CatalogAlbumDetailsEntryScreenState
    extends State<CatalogAlbumDetailsEntryScreen> {
  late final Future<String?> _spotifyAlbumId = _resolveAlbumId();

  static String _normalize(String value) => value.toLowerCase().trim().replaceAll(
        RegExp(r"[\s\-_.,:;!?()\[\]{}\\/]+"),
        '',
      );

  Future<String?> _resolveAlbumId() async {
    if (!AppController.instance.isBackendAuthenticated) return null;
    final title = widget.media.title.trim();
    if (title.isEmpty) return null;
    try {
      final payload = await AppController.instance.backendApi.searchMusicCatalog(
        title,
        type: 'album',
        limit: 10,
      );
      final spotify = payload['spotify'] is Map
          ? Map<String, dynamic>.from(payload['spotify'] as Map)
          : <String, dynamic>{};
      final raw = spotify['albums'];
      if (raw is! List) return null;
      final wantedTitle = _normalize(title);
      final wantedArtists = widget.media.music
          .map(_normalize)
          .where((value) => value.isNotEmpty)
          .toSet();
      final matches = raw
          .whereType<Map>()
          .map((value) => Map<String, dynamic>.from(value))
          .where((value) => _normalize(value['title']?.toString() ?? '') == wantedTitle)
          .toList();
      if (matches.isEmpty) return null;
      matches.sort((a, b) {
        int score(Map<String, dynamic> row) {
          final artist = _normalize(row['artist']?.toString() ?? '');
          final hasArtist = wantedArtists.isEmpty ||
              wantedArtists.any((value) => artist.contains(value));
          final release = row['releaseDate']?.toString() ?? '';
          final yearMatch = widget.media.releaseYear == null ||
              (release.length >= 4 &&
                  release.startsWith(widget.media.releaseYear.toString()));
          return (hasArtist ? 0 : 2) + (yearMatch ? 0 : 1);
        }
        return score(a).compareTo(score(b));
      });
      final selected = matches.first;
      // When the local record names artists, don't route to a different
      // same-title album if none of the provider results match those artists.
      final selectedArtist = _normalize(selected['artist']?.toString() ?? '');
      if (wantedArtists.isNotEmpty &&
          !wantedArtists.any((value) => selectedArtist.contains(value))) {
        return null;
      }
      final id = selected['id']?.toString() ?? '';
      return RegExp(r'^[A-Za-z0-9]{22}$').hasMatch(id) ? id : null;
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> _localTracksForAlbum() {
    final title = _normalize(widget.media.title);
    final artistNames = widget.media.music.map(_normalize).where((v) => v.isNotEmpty).toSet();
    var local = MusicLibraryStore.instance.tracks
        .where((track) => _normalize(track.album) == title)
        .toList(growable: false);
    if (artistNames.isNotEmpty) {
      final artistMatches = local.where((track) => artistNames.any((artist) =>
          _normalize(track.artist).contains(artist) || artist.contains(_normalize(track.artist)))).toList();
      if (artistMatches.isNotEmpty) local = artistMatches;
    }
    return [
      for (var index = 0; index < local.length; index++)
        <String, dynamic>{
          'title': local[index].title,
          'artist': local[index].artist,
          'durationMs': local[index].duration.inMilliseconds,
          'trackNumber': index + 1,
          'artworkUrl': local[index].artworkUrl ?? '',
          'audioUrl': local[index].audioUrl ?? '',
        },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final owned = AppController.instance.isOwned(widget.media.id);
    final localTracks = _localTracksForAlbum();
    if (owned) {
      return OwnedAlbumDetailsScreen(
        media: widget.media,
        albumTitle: widget.media.title,
        artistName: widget.media.music.join(', '),
        artworkUrl: widget.media.imageUrl,
        localTracks: localTracks,
      );
    }
    return FutureBuilder<String?>(
      future: _spotifyAlbumId,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            backgroundColor: const Color(0xFF101010),
            appBar: AppBar(title: Text(widget.media.title)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final id = snapshot.data;
        if (id != null && id.isNotEmpty) {
          return SpotifyAlbumDetailsScreen(
            albumTitle: widget.media.title,
            spotifyId: id,
            isOwned: false,
            localMedia: widget.media,
            localArtistName: widget.media.music.join(', '),
            localTracks: localTracks,
          );
        }
        return MusicAlbumPageScreen(
          media: widget.media,
          isOwned: owned,
          localTracks: localTracks,
          // This entry screen has already attempted an exact title/artist
          // lookup; keep the local Music album page available without issuing
          // a duplicate request when no provider ID was found.
          resolveSpotifyMetadata: false,
        );
      },
    );
  }

}


// ============================================================
// ACTORS
// ============================================================

class ActorsFallbackScreen extends StatelessWidget {
  const ActorsFallbackScreen({
    super.key,
  });

  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const UniversalText('Actors'),
        actions: const [PageCustomizeButton(pageId: 'actors')],
      ),
      body: const Center(
        child: UniversalText(
          'Actors',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// IMPORT MEDIA
// ============================================================

class ImportMediaScreen extends StatefulWidget {
  const ImportMediaScreen({super.key});

  @override
  State<ImportMediaScreen> createState() => _ImportMediaScreenState();
}

/// Implements the `_ImportMediaScreenState` class for this feature or UI component.
class _ImportMediaScreenState extends State<ImportMediaScreen> {
  final titleController = TextEditingController();
  final yearController = TextEditingController();
  final posterController = TextEditingController();
  final trailerController = TextEditingController();
  final descriptionController = TextEditingController();
  final languagesController = TextEditingController();
  final subtitlesController = TextEditingController();
  final extrasController = TextEditingController();

  static const discTypes = <String>[
    'DVD',
    'Blu-ray',
    '4K Ultra HD',
    'Audio CD',
  ];

  static const regions = <String>[
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    'A',
    'B',
    'C',
    '0',
    'Region Free',
  ];

  String selectedType = 'movie';
  String selectedDiscType = 'DVD';
  String selectedRegion = 'Region Free';

  bool armConnected = false;
  bool importing = false;
  bool verificationPassed = false;
  bool ownershipConfirmed = false;
  bool rightsBlocked = false;
  String? rightsBlockReason;
  bool addingToLibrary = false;
  double progress = 0;
  String statusMessage = 'ARM is always enabled for disc imports.';
  String? jobId;
  String? driveId;

  Map<String, dynamic>? reviewJob;
  Map<String, dynamic>? verification;
  List<Map<String, dynamic>> detectedDiscTitles = <Map<String, dynamic>>[];
  final Set<String> selectedDiscTitleIds = <String>{};

  Timer? _pollTimer;

  @override

  /// Performs `dispose` for this feature. Update this documentation when its contract changes.
  void dispose() {
    _pollTimer?.cancel();
    titleController.dispose();
    yearController.dispose();
    posterController.dispose();
    trailerController.dispose();
    descriptionController.dispose();
    languagesController.dispose();
    subtitlesController.dispose();
    extrasController.dispose();
    super.dispose();
  }

  /// Performs `_startArmImport` for this feature. Update this documentation when its contract changes.
  Future<void> _startArmImport() async {
    if (importing) return;

    setState(() {
      importing = true;
      progress = 0;
      verificationPassed = false;
      rightsBlocked = false;
      rightsBlockReason = null;
      reviewJob = null;
      verification = null;
      statusMessage = 'Connecting to ARM...';
    });

    try {
      final api = AppController.instance.backendApi;
      final status = await api.getArmStatus();

      if (status['connected'] != true) {
        throw BackendApiException(
          'ARM is not reachable. Check ARM_SERVER_URL on the backend.',
        );
      }

      armConnected = true;

      final drives = await api.getArmDrives();
      final drive =
          drives.whereType<Map>().cast<Map<String, dynamic>>().firstWhere(
                (item) => item['available'] != false,
                orElse: () => <String, dynamic>{
                  'id': 'arm-auto',
                  'name': 'ARM automatic drive monitor',
                },
              );

      driveId = drive['id']?.toString() ?? 'arm-auto';

      // Preflight any metadata the connected ARM adapter already exposes.
      // A missing rights signal is unknown, not a declaration that a disc is
      // legitimate; explicit blocked signals prevent this app from proceeding.
      final preflight = await api.scanArmDisc(driveId: driveId!);
      final scannedDisc = preflight['disc'];
      if (scannedDisc is Map) {
        final reason = _rightsBlockReasonFor(
          Map<String, dynamic>.from(scannedDisc),
        );
        if (reason != null) {
          throw BackendApiException(
            'We do not allow pirated content in this service. $reason',
          );
        }
      }

      final result = await api.startArmImport(driveId: driveId!);
      final job = result['job'];

      if (job is! Map) {
        throw BackendApiException('ARM did not return a rip job.');
      }

      jobId = job['id']?.toString();
      statusMessage = job['message']?.toString() ??
          'ARM is monitoring the drive. Insert the disc to begin.';
      _beginPolling();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        importing = false;
        statusMessage = error.toString().replaceFirst('Exception: ', '');
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(statusMessage)),
      );
    }
  }

  /// Performs `_beginPolling` for this feature. Update this documentation when its contract changes.
  void _beginPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _pollArmJob(),
    );
    _pollArmJob();
  }

  /// Performs `_pollArmJob` for this feature. Update this documentation when its contract changes.
  Future<void> _pollArmJob() async {
    final id = jobId;
    if (id == null) return;

    try {
      final data = await AppController.instance.backendApi.getArmJob(jobId: id);
      final job = data['job'];
      if (job is! Map) return;

      final map = Map<String, dynamic>.from(job);
      final rawProgress = map['progress'];
      final nextProgress = rawProgress is num
          ? (rawProgress.toDouble().clamp(0.0, 100.0) / 100.0).toDouble()
          : progress;

      if (!mounted) return;

      setState(() {
        progress = nextProgress;
        statusMessage = map['message']?.toString() ??
            map['status']?.toString() ??
            statusMessage;
        reviewJob = map;
      });

      final status = map['status']?.toString();
      // ARM implementations report either readyForReview (the native
      // service) or completed (remote workers). Treat both as a terminal
      // rip result so the user can review and approve it instead of polling
      // forever after the extraction has finished.
      if (status == 'readyForReview' || status == 'completed') {
        _pollTimer?.cancel();
        _prepareReview(map);
      } else if (status == 'rejected' || status == 'failed') {
        _pollTimer?.cancel();
        final blockReason = _rightsBlockReasonFor(map);
        final message = map['message']?.toString() ??
            'Disc rejected by the integrity checks.';
        setState(() {
          importing = false;
          verificationPassed = false;
          rightsBlocked = blockReason != null ||
              message.toLowerCase().contains('pirated content');
          rightsBlockReason = blockReason ?? (rightsBlocked ? message : null);
          verification = map['verification'] is Map
              ? Map<String, dynamic>.from(map['verification'])
              : null;
          statusMessage = message;
        });
      }
    } catch (_) {
      // Keep polling: ARM jobs can temporarily disappear while ARM refreshes
      // its database/UI state.
    }
  }

  String? _rightsBlockReasonFor(Map<String, dynamic> value) {
    const blockedStatuses = <String>{
      'pirated',
      'piracy_confirmed',
      'unauthorized',
      'counterfeit',
      'blocked',
      'infringing',
      'known_pirated',
    };
    const statusKeys = <String>{
      'rightsStatus',
      'rights_status',
      'sourceLegitimacy',
      'source_legitimacy',
      'copyrightStatus',
      'copyright_status',
      'contentRightsStatus',
      'content_rights_status',
    };
    const flagKeys = <String>{
      'piracyDetected',
      'piracy_detected',
      'knownPirated',
      'known_pirated',
      'counterfeitDisc',
      'counterfeit_disc',
      'unauthorizedSource',
      'unauthorized_source',
    };
    for (final entry in value.entries) {
      final key = entry.key.toString();
      final raw = entry.value;
      if (flagKeys.contains(key) && raw == true) {
        return 'A trusted rights signal marked this disc/source as pirated or unauthorized.';
      }
      if (statusKeys.contains(key) &&
          blockedStatuses.contains(raw.toString().trim().toLowerCase())) {
        return 'A trusted rights signal marked this disc/source as ${raw.toString()}.';
      }
      if (raw is Map) {
        final nested = _rightsBlockReasonFor(Map<String, dynamic>.from(raw));
        if (nested != null) return nested;
      } else if (raw is List) {
        for (final item in raw) {
          if (item is Map) {
            final nested =
                _rightsBlockReasonFor(Map<String, dynamic>.from(item));
            if (nested != null) return nested;
          }
        }
      }
    }
    return null;
  }

  /// Performs `_prepareReview` for this feature. Update this documentation when its contract changes.
  void _prepareReview(Map<String, dynamic> job) {
    final blockReason = _rightsBlockReasonFor(job);
    final verificationData = job['verification'];
    final discType = job['discType']?.toString();
    final region = job['region']?.toString();
    final source = (job['titles'] is List &&
            (job['titles'] as List).isNotEmpty &&
            (job['titles'] as List).first is Map)
        ? Map<String, dynamic>.from((job['titles'] as List).first as Map)
        : job;
    final sourceMetadata = source['metadata'] is Map
        ? Map<String, dynamic>.from(source['metadata'] as Map)
        : <String, dynamic>{};

    final rawTitles = job['titles'];
    final titles = <Map<String, dynamic>>[];
    if (rawTitles is List) {
      for (var i = 0; i < rawTitles.length; i++) {
        final value = rawTitles[i];
        if (value is Map) {
          final map = Map<String, dynamic>.from(value);
          final id = map['id']?.toString().trim();
          map['id'] = (id == null || id.isEmpty) ? 'title_${i + 1}' : id;
          titles.add(map);
        }
      }
    }

    if (titles.isEmpty &&
        (job['title']?.toString().trim().isNotEmpty ?? false)) {
      titles.add({
        'id': 'title_1',
        'title': job['title']?.toString(),
        'mediaType': job['mediaType']?.toString() ?? 'movie',
        'classification': 'feature',
        'year': job['year'],
        'durationSeconds': job['durationSeconds'] ?? job['duration'],
        'confidence': job['confidence'] ?? 0,
        'outputPath': job['outputPath'],
        'metadata': job,
      });
    }

    setState(() {
      importing = false;
      verification = verificationData is Map
          ? Map<String, dynamic>.from(verificationData)
          : null;
      rightsBlocked = blockReason != null;
      rightsBlockReason = blockReason;
      verificationPassed = verification?['passed'] == true && !rightsBlocked;
      detectedDiscTitles = titles;
      selectedDiscTitleIds
        ..clear()
        ..addAll(
          titles
              .where(_isImportableDiscTitle)
              .map((title) => title['id'].toString()),
        );
      titleController.text = titles.isNotEmpty
          ? titles.first['title']?.toString() ?? ''
          : job['title']?.toString() ?? '';
      selectedType = _normalizeMediaType(
        titles.isNotEmpty
            ? titles.first['mediaType']?.toString()
            : job['mediaType']?.toString(),
      );
      selectedDiscType =
          discTypes.contains(discType) ? discType! : selectedDiscType;
      selectedRegion = regions.contains(region) ? region! : selectedRegion;
      languagesController.text = _strings(source['languages']).isNotEmpty
          ? _strings(source['languages']).join(', ')
          : _strings(sourceMetadata['languages']).isNotEmpty
              ? _strings(sourceMetadata['languages']).join(', ')
              : _strings(job['languages']).join(', ');
      subtitlesController.text = _strings(source['subtitles']).isNotEmpty
          ? _strings(source['subtitles']).join(', ')
          : _strings(sourceMetadata['subtitles']).isNotEmpty
              ? _strings(sourceMetadata['subtitles']).join(', ')
              : _strings(job['subtitles']).join(', ');
      extrasController.text = _strings(source['extras']).isNotEmpty
          ? _strings(source['extras']).join(', ')
          : _strings(sourceMetadata['extras']).isNotEmpty
              ? _strings(sourceMetadata['extras']).join(', ')
              : _strings(job['extras']).join(', ');
      statusMessage = rightsBlocked
          ? 'Import blocked: $blockReason We do not allow pirated content in this service.'
          : verificationPassed
              ? titles.length > 1
                  ? 'Disc verified. ARM detected ${titles.length} separate titles on this disc. Review them before adding them to your library.'
                  : 'Disc verified. Review the metadata, then click ADD TO LIBRARY.'
              : 'Disc rejected. It cannot be added to your library.';
    });
  }

  /// Performs `_normalizeMediaType` for this feature. Update this documentation when its contract changes.
  String _normalizeMediaType(String? value) {
    final v = (value ?? '').toLowerCase();
    if (v.contains('album') || v.contains('music') || v.contains('audio')) {
      return 'album';
    }
    if (v.contains('tv') || v.contains('series') || v.contains('show')) {
      return 'tvShow';
    }
    return 'movie';
  }

  /// Performs `_isImportableDiscTitle` for this feature. Update this documentation when its contract changes.
  bool _isImportableDiscTitle(Map<String, dynamic> title) {
    final type = (title['mediaType']?.toString() ?? 'movie').toLowerCase();
    final classification =
        (title['classification']?.toString() ?? 'feature').toLowerCase();
    final movieLike = type.contains('movie') ||
        type.contains('film') ||
        type.contains('tv') ||
        type.contains('show') ||
        type.contains('series');
    final featureLike = classification.isEmpty ||
        classification == 'feature' ||
        classification == 'feature_film' ||
        classification == 'main_feature' ||
        classification == 'series' ||
        classification == 'tv_show' ||
        classification == 'tvshow';
    final albumLike = type.contains('music') ||
        type.contains('audio') ||
        type.contains('album') ||
        classification == 'album';
    return (movieLike && featureLike) ||
        (albumLike && classification == 'album');
  }

  /// Performs `_strings` for this feature. Update this documentation when its contract changes.
  List<String> _strings(dynamic value) {
    if (value is! List) return <String>[];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  List<Map<String, dynamic>> _maps(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  /// Performs `_addVerifiedDiscToLibrary` for this feature. Update this documentation when its contract changes.
  Future<void> _addVerifiedDiscToLibrary() async {
    if (addingToLibrary) return;
    if (rightsBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: UniversalText(
            'We do not allow pirated content in this service. This disc was blocked by a trusted rights signal.'),
      ));
      return;
    }
    if (!verificationPassed || reviewJob == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: UniversalText(
            'Wait for the rip to finish and pass verification before adding it.'),
      ));
      return;
    }
    if (!ownershipConfirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: UniversalText(
                'Please confirm that you own or are legally authorized to use this media.')),
      );
      return;
    }
    setState(() {
      addingToLibrary = true;
      statusMessage = 'Recording ownership confirmation…';
    });
    try {
      await AppController.instance.backendApi.confirmOwnershipDeclaration();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        addingToLibrary = false;
        statusMessage = 'Could not record ownership confirmation.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
      return;
    }

    if (!mounted) return;
    final job = reviewJob!;
    final selectedTitles = detectedDiscTitles
        .where((title) =>
            _isImportableDiscTitle(title) &&
            selectedDiscTitleIds.contains(title['id']?.toString()))
        .toList();

    if (selectedTitles.isEmpty) {
      setState(() => addingToLibrary = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: UniversalText(
                'Select at least one title from the disc before adding it.')),
      );
      return;
    }

    final releaseChoice = await showLibraryReleaseChoice(context);
    if (releaseChoice == null) {
      if (mounted) setState(() => addingToLibrary = false);
      return;
    }

    final poster = posterController.text.trim();
    final trailer = trailerController.text.trim();
    final collectionId = job['discId']?.toString() ??
        job['disc_id']?.toString() ??
        'disc_${DateTime.now().microsecondsSinceEpoch}';
    final collectionTitle = job['collectionTitle']?.toString() ??
        job['discTitle']?.toString() ??
        job['title']?.toString() ??
        'Imported Disc';
    final discNumber = job['discNumber'] is num
        ? (job['discNumber'] as num).toInt()
        : int.tryParse(job['discNumber']?.toString() ?? '');
    final discExtras = detectedDiscTitles
        .where((title) => !_isImportableDiscTitle(title))
        .map((title) =>
            (title['canonicalTitle']?.toString().trim().isNotEmpty == true
                ? title['canonicalTitle']?.toString().trim()
                : title['title']?.toString().trim()) ??
            '')
        .where((title) => title.isNotEmpty)
        .toList();

    try {
      for (final titleData in selectedTitles) {
        final detectedTitle =
            (titleData['canonicalTitle']?.toString().trim().isNotEmpty == true
                    ? titleData['canonicalTitle']?.toString().trim()
                    : titleData['title']?.toString().trim()) ??
                '';
        final title =
            selectedTitles.length == 1 && titleController.text.trim().isNotEmpty
                ? titleController.text.trim()
                : detectedTitle;
        final discTitle = titleData['discTitle']?.toString() ??
            titleData['title']?.toString();
        if (title.isEmpty) continue;

        if (mounted) {
          setState(() => statusMessage = releaseChoice.schedule
              ? 'Saving "$title" to the NAS and scheduling release…'
              : 'Saving "$title" to the home server…');
        }

        final metadata = titleData['metadata'] is Map
            ? Map<String, dynamic>.from(titleData['metadata'] as Map)
            : <String, dynamic>{};
        final editedYear = selectedTitles.length == 1
            ? int.tryParse(yearController.text.trim())
            : null;
        final year = editedYear ??
            (titleData['year'] is num
                ? (titleData['year'] as num).toInt()
                : int.tryParse(titleData['year']?.toString() ?? '') ??
                    (metadata['year'] is num
                        ? (metadata['year'] as num).toInt()
                        : int.tryParse(metadata['year']?.toString() ?? '') ??
                            (job['year'] is num
                                ? (job['year'] as num).toInt()
                                : int.tryParse(
                                    job['year']?.toString() ?? ''))));
        final reviewerProfileId =
            AppController.instance.currentProfile?.id ?? '';
        final reviewerProfileName =
            AppController.instance.currentProfile?.name ?? '';
        final media = MediaItem(
          id: 'arm_${DateTime.now().microsecondsSinceEpoch}_${titleData['id']}',
          mediaVersionId: (titleData['mediaVersionId'] ??
                  titleData['versionId'] ??
                  metadata['mediaVersionId'] ??
                  job['mediaVersionId'])
              ?.toString(),
          title: title,
          type: selectedTitles.length == 1
              ? selectedType
              : _normalizeMediaType(titleData['mediaType']?.toString() ??
                  job['mediaType']?.toString()),
          addedByProfileId:
              reviewerProfileId.isEmpty ? null : reviewerProfileId,
          addedByProfileName:
              reviewerProfileName.isEmpty ? null : reviewerProfileName,
          addedSource: 'import/rip',
          imageUrl: poster.isEmpty
              ? (titleData['posterUrl']?.toString() ??
                  metadata['posterUrl']?.toString() ??
                  job['posterUrl']?.toString())
              : poster,
          description: descriptionController.text.trim().isEmpty
              ? titleData['description']?.toString() ??
                  metadata['description']?.toString() ??
                  job['description']?.toString() ??
                  DescriptionGenerator.movie(title: title, year: year)
              : descriptionController.text.trim(),
          releaseYear: year,
          trailerUrl: trailer.isEmpty
              ? (titleData['trailerUrl']?.toString() ??
                  metadata['trailerUrl']?.toString() ??
                  job['trailerUrl']?.toString())
              : trailer,
          discType: selectedDiscType,
          discRegion: titleData['detectedRegion']?.toString() ??
              job['region']?.toString() ??
              selectedRegion,
          discTitle: discTitle,
          discMarketCountry: titleData['discMarketCountry']?.toString() ??
              job['discMarketCountry']?.toString(),
          originalTitle: titleData['originalTitle']?.toString() ??
              titleData['canonicalTitle']?.toString(),
          originalLanguage: titleData['originalLanguage']?.toString(),
          countryOfOrigin: titleData['countryOfOrigin']?.toString(),
          canonicalTitle: titleData['canonicalTitle']?.toString() ?? title,
          discCollectionId: collectionId,
          discCollectionTitle: collectionTitle,
          discNumber: discNumber,
          discTitleId: titleData['id']?.toString(),
          actors: _strings(titleData['actors']).isNotEmpty
              ? _strings(titleData['actors'])
              : (metadata['actors'] is List
                  ? _strings(metadata['actors'])
                  : _strings(job['actors'])),
          directors: _strings(titleData['directors']).isNotEmpty
              ? _strings(titleData['directors'])
              : (metadata['directors'] is List
                  ? _strings(metadata['directors'])
                  : _strings(job['directors'])),
          writers: _strings(titleData['writers']).isNotEmpty
              ? _strings(titleData['writers'])
              : (metadata['writers'] is List
                  ? _strings(metadata['writers'])
                  : _strings(job['writers'])),
          music: _strings(titleData['music']).isNotEmpty
              ? _strings(titleData['music'])
              : (metadata['music'] is List
                  ? _strings(metadata['music'])
                  : _strings(job['music'])),
          genres: _strings(titleData['genres']).isNotEmpty
              ? _strings(titleData['genres'])
              : (metadata['genres'] is List
                  ? _strings(metadata['genres'])
                  : _strings(job['genres'])),
          tags: _strings(titleData['tags']).isNotEmpty
              ? _strings(titleData['tags'])
              : (metadata['tags'] is List
                  ? _strings(metadata['tags'])
                  : _strings(job['tags'])),
          chapters: _strings(titleData['chapters']).isNotEmpty
              ? _strings(titleData['chapters'])
              : (metadata['chapters'] is List
                  ? _strings(metadata['chapters'])
                  : _strings(job['chapters'])),
          audioTracks: _strings(titleData['audioTracks']).isNotEmpty
              ? _strings(titleData['audioTracks'])
              : (metadata['audioTracks'] is List
                  ? _strings(metadata['audioTracks'])
                  : _strings(job['audioTracks'])),
          xrayEvents: _maps(
            titleData['xrayEvents'] is List
                ? titleData['xrayEvents']
                : metadata['xrayEvents'] is List
                    ? metadata['xrayEvents']
                    : job['xrayEvents'],
          ),
          language: languagesController.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .join(', '),
          subtitles: subtitlesController.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
          extras: <String>{
            ...extrasController.text
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty),
            ...discExtras,
          }.toList(),
        );

        final outputPath = (titleData['outputPath'] ??
                metadata['outputPath'] ??
                job['outputPath'] ??
                metadata['path'] ??
                job['path'])
            ?.toString()
            .trim();
        if (outputPath == null || outputPath.isEmpty) {
          if (mounted) {
            setState(() => addingToLibrary = false);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: UniversalText(
                'ARM did not provide the ripped file path, so the content could not be saved.',
              ),
            ));
          }
          return;
        }

        try {
          final saved =
              await AppController.instance.backendApi.importApprovedArmMedia(
            outputPath: outputPath,
            title: media.title,
            type: media.type,
            year: media.releaseYear,
            description: media.description,
            posterUrl: media.imageUrl,
            trailerUrl: media.trailerUrl,
            metadata: <String, dynamic>{
              ...media.toJson(),
              'armJobId': job['id'],
              'verification': verification,
              'ownershipConfirmed': true,
              'libraryPublicationMode':
                  releaseChoice.schedule ? 'scheduled' : 'immediate',
              if (releaseChoice.schedule)
                'scheduledFor':
                    releaseChoice.scheduledFor!.toUtc().toIso8601String(),
              if (releaseChoice.schedule)
                'scheduledTimeZone': releaseChoice.timeZone,
            },
          );
          final mediaId = saved['mediaId']?.toString();
          if (mediaId == null || mediaId.isEmpty) {
            throw BackendApiException(
              'The server did not return the saved media identifier.',
            );
          }
          final persistedMedia = MediaItem.fromJson(
            <String, dynamic>{...media.toJson(), 'id': mediaId},
          );
          if (releaseChoice.schedule) {
            await AppController.instance.backendApi.scheduleLibraryAddition(
              mediaId: mediaId,
              title: media.title,
              mediaType: media.type,
              scheduledFor: releaseChoice.scheduledFor!,
              timeZone: releaseChoice.timeZone,
            );
          } else {
            AppController.instance.addToLibrary(persistedMedia);
          }
        } catch (error) {
          if (mounted) {
            setState(() {
              addingToLibrary = false;
              statusMessage =
                  'Save failed: ${error.toString().replaceFirst('Exception: ', '')}';
            });
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(error.toString().replaceFirst('Exception: ', '')),
            ));
          }
          return;
        }
      }
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      setState(() {
        addingToLibrary = false;
        statusMessage = 'Save failed: $message';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          selectedTitles.length == 1
              ? '${selectedTitles.first['title']} added to your library.'
              : '${selectedTitles.length} separate titles from this disc were added to your library.',
        ),
      ),
    );

    Navigator.pop(context, true);
  }

  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    final controller = AppController.instance;

    return Scaffold(
      appBar: AppBar(
        title: const UniversalText('Import / Rip Media'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const UniversalText(
                    'ARM AUTOMATIC DISC IMPORT',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const UniversalText(
                    'Import movies, TV episodes, and music albums from supported discs. ARM monitors the drive and reports detected titles, tracks, languages, subtitles, chapters, and verification status. Rights checks can block known unauthorized sources; metadata alone cannot prove a disc is legitimate.',
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.redAccent.withValues(alpha: .45)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.gpp_bad_outlined, color: Colors.redAccent),
                        SizedBox(width: 10),
                        Expanded(
                            child: Text(
                          'Copyright protection: We do not allow pirated content in this service. If a trusted rights check flags a disc/source as pirated, counterfeit, or unauthorized, the item is blocked from import. An ownership declaration is still required. Pre-rip stopping depends on the connected ARM worker supporting a pre-extraction rights hook; this app does not bypass DRM or disc copy protection.',
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const UniversalText('ARM'),
                    subtitle: Text(
                      armConnected
                          ? 'Connected — ARM is enabled permanently'
                          : 'Always ON — connect to ARM to begin',
                    ),
                    value: true,
                    onChanged: null,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.disc_full),
                    title: Text(
                      driveId == null
                          ? 'Optical Drive'
                          : 'Optical Drive: $driveId',
                    ),
                    subtitle: Text(statusMessage),
                  ),
                  if (importing) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: progress),
                    const SizedBox(height: 8),
                    UniversalText(
                      '${(progress * 100).round()}% • $statusMessage',
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: importing ? null : _startArmImport,
                      icon: const Icon(Icons.play_circle_fill),
                      label: const UniversalText(
                          'DETECT DISC / START ARM MONITOR'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (detectedDiscTitles.length > 1) ...[
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const UniversalText(
                      'MULTI-TITLE DISC DETECTED',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    UniversalText(
                      'ARM found ${detectedDiscTitles.length} disc titles. The feature is added once; deleted scenes, trailers, and other bonus titles are listed under Extras.',
                      style:
                          const TextStyle(color: Colors.white70, height: 1.35),
                    ),
                    const SizedBox(height: 10),
                    ...detectedDiscTitles.map((title) {
                      final id = title['id']?.toString() ?? '';
                      final importable = _isImportableDiscTitle(title);
                      final selected =
                          importable && selectedDiscTitleIds.contains(id);
                      final confidence = title['confidence'];
                      final confidenceText = confidence is num && confidence > 0
                          ? ' • ${(confidence.toDouble() <= 1 ? confidence.toDouble() * 100 : confidence.toDouble()).round()}% match'
                          : '';
                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: selected,
                        onChanged: importable
                            ? (value) {
                                setState(() {
                                  if (value == true) {
                                    selectedDiscTitleIds.add(id);
                                  } else {
                                    selectedDiscTitleIds.remove(id);
                                  }
                                });
                              }
                            : null,
                        title: Text(title['canonicalTitle']?.toString() ??
                            title['title']?.toString() ??
                            'Unknown title'),
                        subtitle: UniversalText(
                          '${title['discTitle'] == null ? '' : 'Disc: ${title['discTitle']} • '}${title['mediaType']?.toString() ?? 'movie'} • ${title['classification']?.toString() ?? 'feature'}${title['year'] == null ? '' : ' • ${title['year']}'}$confidenceText',
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
          if (rightsBlocked)
            Card(
              color: Colors.red.withValues(alpha: .10),
              child: const Padding(
                padding: EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.block_rounded,
                        color: Colors.redAccent, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('IMPORT BLOCKED',
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Colors.redAccent)),
                        SizedBox(height: 6),
                        Text(
                            'We do not allow pirated content in our service. This disc/source was flagged by a rights signal and cannot be added to your library.'),
                      ],
                    )),
                  ],
                ),
              ),
            ),
          if (verification != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      verificationPassed
                          ? 'DISC VERIFICATION PASSED'
                          : 'DISC REJECTED',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: verificationPassed
                            ? Colors.greenAccent
                            : Colors.redAccent,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      verification?['reason']?.toString() ??
                          'No verification message.',
                    ),
                    const SizedBox(height: 10),
                    if (verification?['durationSeconds'] != null)
                      UniversalText(
                        'Ripped runtime: ${_formatSeconds(verification!['durationSeconds'])}',
                      ),
                    if (verification?['chapterCount'] != null)
                      UniversalText(
                        'Chapters detected: ${verification!['chapterCount']}',
                      ),
                    const SizedBox(height: 8),
                    ..._strings(verification?['failures']).map(
                      (failure) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: UniversalText(
                          '• $failure',
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (reviewJob != null && verificationPassed) ...[
            const SizedBox(height: 20),
            const UniversalText(
              'IMPORT REVIEW',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selectedType,
              decoration: InputDecoration(
                labelText: tr('Media Type'),
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'movie', child: UniversalText('Movie')),
                DropdownMenuItem(
                    value: 'tvShow', child: UniversalText('TV Show')),
                DropdownMenuItem(value: 'album', child: UniversalText('Album')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => selectedType = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: tr('Title'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: yearController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: tr('Year'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selectedDiscType,
              decoration: InputDecoration(
                labelText: tr('Disc Type'),
                border: OutlineInputBorder(),
              ),
              items: discTypes
                  .map(
                    (type) => DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => selectedDiscType = value);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selectedRegion,
              decoration: InputDecoration(
                labelText: tr('Region'),
                border: OutlineInputBorder(),
              ),
              items: regions
                  .map(
                    (region) => DropdownMenuItem(
                      value: region,
                      child: Text(region),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => selectedRegion = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: posterController,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: tr('Poster URL (optional fallback)'),
                hintText:
                    tr('Use this if the disc/metadata provider has no poster.'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: trailerController,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: tr('Trailer URL (optional fallback)'),
                hintText: tr(
                    'Use this if the disc/metadata provider has no trailer.'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: tr('Description'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: languagesController,
              decoration: InputDecoration(
                labelText: tr('Languages found'),
                hintText: tr('English, Spanish, French'),
                helperText: tr('Separate multiple languages with commas.'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: subtitlesController,
              decoration: InputDecoration(
                labelText: tr('Subtitles found'),
                hintText: tr('English, Spanish, French'),
                helperText:
                    tr('Separate multiple subtitle languages with commas.'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: extrasController,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: tr('Extras found'),
                hintText: tr(
                    'Behind the scenes, deleted scenes, audio commentary, trailers from other movies'),
                helperText:
                    tr('Each extra can be entered as a comma-separated item.'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),
            Material(
              color: Colors.transparent,
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: ownershipConfirmed,
                onChanged: (value) =>
                    setState(() => ownershipConfirmed = value ?? false),
                title: const UniversalText(
                    'I own or am legally authorized to use this media.'),
                subtitle: const UniversalText(
                    'My Streaming Service provides storage and streaming infrastructure; applicable local law determines what copying and remote streaming are permitted.'),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .04),
                borderRadius: BorderRadius.circular(14),
              ),
              child: UniversalText(
                'When you add this verified disc, its languages, audio tracks, subtitles, extras, actors, directors, writers, music, genres, tags, and chapters will be cataloged with the media.',
                style: TextStyle(color: Colors.grey.shade300),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 54,
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: addingToLibrary ? null : _addVerifiedDiscToLibrary,
                icon: addingToLibrary
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.library_add),
                label: UniversalText(
                  addingToLibrary ? 'ADDING TO LIBRARY…' : 'ADD TO LIBRARY',
                ),
              ),
            ),
            if (addingToLibrary) ...[
              const SizedBox(height: 8),
              Text(statusMessage, textAlign: TextAlign.center),
            ],
          ],
          const SizedBox(height: 30),
          UniversalText(
            'Current profile: ${controller.currentProfile?.name ?? 'None'}',
            style: TextStyle(color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  /// Performs `_formatSeconds` for this feature. Update this documentation when its contract changes.
  String _formatSeconds(dynamic value) {
    final seconds = value is num
        ? value.toInt()
        : int.tryParse(value?.toString() ?? '') ?? 0;
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${secs.toString().padLeft(2, '0')}';
  }
}

// ============================================================
// TRAILERS
// ============================================================

class TrailersScreen extends StatelessWidget {
  const TrailersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final trailers = AppController.instance.library
        .where((m) => m.trailerUrl?.trim().isNotEmpty == true)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const UniversalText('Trailers')),
      body: trailers.isEmpty
          ? const Center(
              child: UniversalText(
                  'No trailers have been added to your library yet. ARM review can add a YouTube link when a disc does not contain a trailer.'))
          : ListView.builder(
              padding: const EdgeInsets.all(18),
              itemCount: trailers.length,
              itemBuilder: (_, index) {
                final media = trailers[index];
                return Card(
                    child: ListTile(
                        leading: const Icon(Icons.play_circle_fill_rounded),
                        title: LocalizedMediaText(media.title, preserveOriginal: true,
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(media.type),
                        trailing: const Icon(Icons.open_in_new_rounded),
                        onTap: () async {
                          final uri = Uri.tryParse(media.trailerUrl!);
                          if (uri != null) {
                            await launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          }
                        }));
              },
            ),
    );
  }
}

// ============================================================
// PROFILE
// ============================================================

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

/// Implements the `_ProfileScreenState` class for this feature or UI component.
class _ProfileScreenState extends State<ProfileScreen> {
  final controller = AppController.instance;

  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    final account = controller.currentAccount;

    if (account == null) {
      return const Scaffold(
          body: Center(child: UniversalText('No account is logged in.')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF070707),
      appBar: AppBar(
        title: const UniversalText('Profiles',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        children: [
          const UniversalText('Who is watching?',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          UniversalText('${account.profiles.length}/7 profiles',
              style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 24),
          ...account.profiles.map(
            (profile) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ProfileManagementCard(
                profile: profile,
                current: controller.currentProfile?.id == profile.id,
                onSwitch: () {
                  controller.switchProfile(profile.id);
                  setState(() {});
                },
                onDelete: () {
                  controller.removeProfile(profile.id);
                  setState(() {});
                },
              ),
            ),
          ),
          if (account.profiles.length < 7)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => const AddProfileDialog(),
                  ).then((_) {
                    if (mounted) setState(() {});
                  });
                },
                icon: const Icon(Icons.add_rounded),
                label: const UniversalText('CREATE PROFILE'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          if (controller.currentProfile != null) ...[
            const SizedBox(height: 24),
            const UniversalText('Recent media activity',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            SizedBox(
              height: 300,
              child: ActivityTimeline(
                profileId: controller.currentProfile!.id,
                limit: 10,
              ),
            ),
          ],
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .045),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: .07)),
            ),
            child: Row(
              children: [
                const Icon(Icons.workspace_premium_outlined, size: 28),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(account.subscription.plan.name.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(account.subscription.status.name,
                          style: const TextStyle(color: Colors.white54)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => showDialog(
                      context: context,
                      builder: (_) => const SubscribeDialog()),
                  child: const UniversalText('Manage'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () async {
              await controller.logoutFromBackend();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
            icon: const Icon(Icons.logout_rounded),
            label: const UniversalText('LOG OUT'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: BorderSide(color: Colors.red.withValues(alpha: .35)),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Implements the `_ProfileManagementCard` class for this feature or UI component.
class _ProfileManagementCard extends StatelessWidget {
  final Profile profile;
  final bool current;
  final VoidCallback onSwitch;
  final VoidCallback onDelete;

  const _ProfileManagementCard({
    required this.profile,
    required this.current,
    required this.onSwitch,
    required this.onDelete,
  });

  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Material(
      color: current
          ? Colors.white.withValues(alpha: .09)
          : Colors.white.withValues(alpha: .045),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onSwitch,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _MainProfileAvatar(profile: profile, size: 58),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.name,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(current ? 'Current profile' : 'Tap to switch',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'switch') onSwitch();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                      value: 'switch', child: UniversalText('Switch')),
                  PopupMenuItem(
                      value: 'delete', child: UniversalText('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Implements the `_MainProfileAvatar` class for this feature or UI component.
class _MainProfileAvatar extends StatelessWidget {
  final Profile profile;
  final double size;

  const _MainProfileAvatar({required this.profile, required this.size});

  Widget _fallback() {
    final name = profile.name.trim();
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: Colors.white.withValues(alpha: .10),
      child: Text(
        name.isEmpty ? '?' : name[0].toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontSize: size * .42,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatar = profile.avatarUrl?.trim() ?? '';

    // Avatar choices are saved as stable values such as `avatar:19`.
    // Index 19 is the 007 avatar; index 18 is the G avatar.
    if (avatar.startsWith('avatar:')) {
      final parsedIndex = int.tryParse(avatar.substring('avatar:'.length));
      const icons = <IconData>[
        Icons.person_rounded,
        Icons.face_rounded,
        Icons.star_rounded,
        Icons.favorite_rounded,
        Icons.pets_rounded,
        Icons.music_note_rounded,
        Icons.movie_rounded,
        Icons.auto_awesome_rounded,
        Icons.rocket_launch_rounded,
        Icons.emoji_emotions_rounded,
        Icons.public_rounded,
        Icons.web_rounded,
        Icons.shield_rounded,
        Icons.bolt_rounded,
        Icons.face_rounded,
        Icons.flashlight_on,
        Icons.pets_rounded,
        Icons.sailing_rounded,
        Icons.smart_toy_rounded,
        Icons.verified_user_rounded,
      ];
      if (parsedIndex != null && parsedIndex >= 0 && parsedIndex < icons.length) {
        final label = parsedIndex == 18 ? 'G' : (parsedIndex == 19 ? '007' : null);
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: .08),
          ),
          alignment: Alignment.center,
          child: parsedIndex == 14
              ? SizedBox(
                  width: size * .58,
                  height: size * .58,
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.topLeft,
                        child: CircleAvatar(
                          radius: size * .13,
                          backgroundColor: Colors.white,
                        ),
                      ),
                      Align(
                        alignment: Alignment.topRight,
                        child: CircleAvatar(
                          radius: size * .13,
                          backgroundColor: Colors.white,
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: CircleAvatar(
                          radius: size * .18,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : label != null
                  ? Text(
                      label,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: size * (label.length > 1 ? .30 : .48),
                        fontWeight: FontWeight.w900,
                      ),
                    )
                  : Icon(icons[parsedIndex], size: size * .48, color: Colors.white70),
        );
      }
      return _fallback();
    }

    // Photos selected through image_picker are persisted as local paths;
    // also accept file:// URIs and remote avatar URLs.
    if (avatar.startsWith('http://') || avatar.startsWith('https://')) {
      return ClipOval(
        child: Image.network(
          avatar,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _fallback(),
        ),
      );
    }

    if (avatar.isNotEmpty) {
      final uri = Uri.tryParse(avatar);
      final file = uri?.scheme == 'file' ? File.fromUri(uri!) : File(avatar);
      if (file.existsSync()) {
        return ClipOval(
          child: Image.file(
            file,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _fallback(),
          ),
        );
      }
    }

    return _fallback();
  }
}

/// Implements the `AddProfileDialog` class for this feature or UI component.
class AddProfileDialog extends StatefulWidget {
  const AddProfileDialog({super.key});

  @override
  State<AddProfileDialog> createState() => _AddProfileDialogState();
}

/// Implements the `_AddProfileDialogState` class for this feature or UI component.
class _AddProfileDialogState extends State<AddProfileDialog> {
  final nameController = TextEditingController();

  @override

  /// Performs `dispose` for this feature. Update this documentation when its contract changes.
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const UniversalText('Create Profile'),
      content: TextField(
        controller: nameController,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: tr('Profile name'),
          prefixIcon: Icon(Icons.person_outline_rounded),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const UniversalText('CANCEL')),
        FilledButton(
          onPressed: () {
            final name = nameController.text.trim();
            if (name.isEmpty) return;
            AppController.instance.addProfile(name);
            Navigator.pop(context);
          },
          child: const UniversalText('CREATE'),
        ),
      ],
    );
  }
}

// ============================================================
// SUBSCRIPTION
// ============================================================

class SubscribeDialog extends StatelessWidget {
  const SubscribeDialog({super.key});

  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    final controller = AppController.instance;

    return AlertDialog(
      title: const UniversalText(
        'Subscription',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const UniversalText(
            'Choose your subscription.',
          ),
          const SizedBox(height: 20),
          ListTile(
            title: const UniversalText(
              '\$54.99 USD / month',
            ),
            subtitle: const UniversalText(
              'No free trial',
            ),
            onTap: () {
              controller.subscribe(
                SubscriptionPlan.monthly,
              );
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: const UniversalText(
              '\$599.99 USD / year',
            ),
            subtitle: const UniversalText(
              'Save \$59.89 compared with 12 monthly payments',
            ),
            onTap: () {
              controller.subscribe(
                SubscriptionPlan.yearly,
              );
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

class _GroupEmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _GroupEmptyCard(
      {required this.icon, required this.title, required this.subtitle});
  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .035),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: .06))),
      child: Column(children: [
        Icon(icon, size: 42, color: Colors.white38),
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 12))
      ]));
}

// ============================================================
// GROUP WISHLIST CARD
// ============================================================

class GroupWishlistCard extends StatelessWidget {
  final WishlistItem item;
  final VoidCallback onChanged;

  const GroupWishlistCard({
    super.key,
    required this.item,
    required this.onChanged,
  });

  /// Performs `remove` for this feature. Update this documentation when its contract changes.
  Future<void> remove(
    BuildContext context,
  ) async {
    final controller = AppController.instance;

    try {
      await controller.removeFromGroupWishlist(
        item.id,
      );

      await controller.loadGroupWishlist();

      if (!context.mounted) return;

      onChanged();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: UniversalText(
            '${item.title} removed from the group wishlist.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: UniversalText(
            'Unable to remove item: $error',
          ),
        ),
      );
    }
  }

  /// Performs `acquire` for this feature. Update this documentation when its contract changes.
  Future<void> acquire(
    BuildContext context,
  ) async {
    final controller = AppController.instance;

    final account = controller.currentAccount;

    if (account == null || account.profiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: UniversalText(
            'No profiles are available.',
          ),
        ),
      );
      return;
    }

    final selectedProfile = await showDialog<Profile>(
      context: context,
      builder: (_) => SelectAcquisitionProfileDialog(
        profiles: account.profiles,
        currentProfile: controller.currentProfile,
      ),
    );

    if (selectedProfile == null) {
      return;
    }

    try {
      await controller.acquireGroupWishlistItem(
        mediaId: item.id,
        profileId: selectedProfile.id,
      );

      await controller.loadGroupWishlist();

      if (!context.mounted) return;

      onChanged();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: UniversalText(
            '${item.title} was acquired for ${selectedProfile.name}.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: UniversalText(
            'Unable to acquire item: $error',
          ),
        ),
      );
    }
  }

  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(
            Icons.movie_outlined,
          ),
        ),
        title: Text(
          item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          item.type,
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'acquire') {
              acquire(context);
            }

            if (value == 'remove') {
              remove(context);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem<String>(
              value: 'acquire',
              child: UniversalText(
                'Acquire / Rip',
              ),
            ),
            PopupMenuItem<String>(
              value: 'remove',
              child: UniversalText(
                'Remove',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SELECT ACQUISITION PROFILE
// ============================================================

class SelectAcquisitionProfileDialog extends StatelessWidget {
  final List<Profile> profiles;
  final Profile? currentProfile;

  const SelectAcquisitionProfileDialog({
    super.key,
    required this.profiles,
    required this.currentProfile,
  });

  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const UniversalText(
        'Add to Which Profile?',
      ),
      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const UniversalText(
              'Choose the profile whose personal library should receive this movie or show.',
            ),
            const SizedBox(height: 15),
            ...profiles.map(
              (profile) => ListTile(
                leading: CircleAvatar(
                  backgroundImage: profile.avatarUrl == null
                      ? null
                      : NetworkImage(
                          profile.avatarUrl!,
                        ),
                  child: profile.avatarUrl == null
                      ? const Icon(
                          Icons.person,
                        )
                      : null,
                ),
                title: Text(
                  profile.name,
                ),
                subtitle: profile.id == currentProfile?.id
                    ? const UniversalText(
                        'Current profile',
                      )
                    : null,
                trailing: const Icon(
                  Icons.chevron_right,
                ),
                onTap: () {
                  Navigator.pop(
                    context,
                    profile,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(
            context,
          ),
          child: const UniversalText('CANCEL'),
        ),
      ],
    );
  }
}

// ============================================================
// WISHLIST
// ============================================================

class WishlistDialog extends StatefulWidget {
  const WishlistDialog({super.key});

  @override
  State<WishlistDialog> createState() => _WishlistDialogState();
}

/// Implements the `_WishlistDialogState` class for this feature or UI component.
class _WishlistDialogState extends State<WishlistDialog> {
  bool loading = false;

  @override

  /// Performs `initState` for this feature. Update this documentation when its contract changes.
  void initState() {
    super.initState();
    loadWishlist();
  }

  /// Performs `loadWishlist` for this feature. Update this documentation when its contract changes.
  Future<void> loadWishlist() async {
    final controller = AppController.instance;

    if (!controller.backendApi.isAuthenticated) {
      return;
    }

    if (mounted) {
      setState(() {
        loading = true;
      });
    }

    try {
      await controller.loadGroupWishlist();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: UniversalText(
            'Unable to load group wishlist: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    final controller = AppController.instance;

    return AlertDialog(
      title: const UniversalText(
        'Group Wishlist',
      ),
      content: SizedBox(
        width: 600,
        height: 500,
        child: loading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : controller.wishlist.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.favorite_border,
                          size: 60,
                        ),
                        SizedBox(
                          height: 15,
                        ),
                        UniversalText(
                          'No group wishlist items.',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(
                          height: 8,
                        ),
                        UniversalText(
                          'Shared items for the group will appear here.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: controller.wishlist.length,
                    itemBuilder: (_, index) {
                      final item = controller.wishlist[index];

                      return GroupWishlistCard(
                        item: item,
                        onChanged: () {
                          setState(() {});
                        },
                      );
                    },
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const UniversalText('CLOSE'),
        ),
        ElevatedButton.icon(
          onPressed: loading ? null : loadWishlist,
          icon: const Icon(
            Icons.refresh,
          ),
          label: const UniversalText('REFRESH'),
        ),
      ],
    );
  }
}

// ============================================================
// GROUP WATCH
// ============================================================

class GroupWatchDialog extends StatefulWidget {
  final MediaItem media;
  const GroupWatchDialog({super.key, required this.media});
  @override
  State<GroupWatchDialog> createState() => _GroupWatchDialogState();
}

/// Implements the `_GroupWatchDialogState` class for this feature or UI component.
class _GroupWatchDialogState extends State<GroupWatchDialog> {
  final Set<String> selectedProfiles = <String>{};

  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    final controller = AppController.instance;
    final account = controller.currentAccount;
    final currentProfile = controller.currentProfile;
    if (account == null || currentProfile == null) {
      return const Scaffold(
          body:
              Center(child: UniversalText('No account or profile selected.')));
    }
    final invitees = account.profiles
        .where((profile) => profile.id != currentProfile.id)
        .toList();
    return Scaffold(
      backgroundColor: const Color(0xFF070707),
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          title: const UniversalText('Group Watch',
              style: TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
        children: [
          Container(
            height: 260,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                color: const Color(0xFF151515)),
            child: Stack(fit: StackFit.expand, children: [
              if (widget.media.imageUrl != null)
                Image.network(widget.media.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: .92)
                  ]))),
              Positioned(
                  left: 18,
                  right: 18,
                  bottom: 18,
                  child: LocalizedMediaText(widget.media.title, preserveOriginal: true,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 27, fontWeight: FontWeight.w900))),
            ]),
          ),
          const SizedBox(height: 22),
          const UniversalText('Invite people',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          const UniversalText('Select the profiles you want to watch with.',
              style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 12),
          if (invitees.isEmpty)
            _GroupEmptyCard(
                icon: Icons.people_outline_rounded,
                title: tr('No other profiles'),
                subtitle: tr('Create another profile to invite someone.'))
          else
            ...invitees.map((profile) {
              final selected = selectedProfiles.contains(profile.id);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: selected
                      ? Colors.red.withValues(alpha: .10)
                      : Colors.white.withValues(alpha: .045),
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    onTap: () => setState(() => selected
                        ? selectedProfiles.remove(profile.id)
                        : selectedProfiles.add(profile.id)),
                    borderRadius: BorderRadius.circular(18),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(children: [
                        _MainProfileAvatar(profile: profile, size: 48),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(profile.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 3),
                              Text(selected ? 'Selected' : 'Tap to invite',
                                  style: const TextStyle(
                                      color: Colors.white38, fontSize: 12))
                            ])),
                        Icon(
                            selected
                                ? Icons.check_circle_rounded
                                : Icons.circle_outlined,
                            color:
                                selected ? Colors.redAccent : Colors.white30),
                      ]),
                    ),
                  ),
                ),
              );
            }),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        GroupWatchPreferencesScreen(media: widget.media))),
            icon: const Icon(Icons.tune_rounded),
            label: Text(selectedProfiles.isEmpty
                ? 'CONTINUE'
                : 'CONTINUE WITH ${selectedProfiles.length} INVITE${selectedProfiles.length == 1 ? '' : 'S'}'),
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16))),
          ),
        ],
      ),
    );
  }
}

/// Implements the `GroupWatchPreferencesScreen` class for this feature or UI component.
class GroupWatchPreferencesScreen extends StatefulWidget {
  final MediaItem media;
  const GroupWatchPreferencesScreen({super.key, required this.media});
  @override
  State<GroupWatchPreferencesScreen> createState() =>
      _GroupWatchPreferencesScreenState();
}

/// Implements the `_GroupWatchPreferencesScreenState` class for this feature or UI component.
class _GroupWatchPreferencesScreenState
    extends State<GroupWatchPreferencesScreen> {
  bool subtitlesEnabled = false;
  String audio = 'Original audio';

  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070707),
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          title: const UniversalText('Your preferences',
              style: TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .045),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: .07))),
            child: Row(children: [
              const Icon(Icons.groups_rounded, size: 30),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    LocalizedMediaText(widget.media.title, preserveOriginal: true,
                        style: const TextStyle(
                            fontSize: 19, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    const UniversalText(
                        'Choose your language settings before starting.',
                        style: TextStyle(color: Colors.white54, fontSize: 12))
                  ]))
            ]),
          ),
          const SizedBox(height: 22),
          const UniversalText('Audio',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .045),
                borderRadius: BorderRadius.circular(17)),
            child: DropdownButtonFormField<String>(
              initialValue: audio,
              decoration: InputDecoration(
                  prefixIcon: Icon(Icons.language_rounded),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
              items: const [
                DropdownMenuItem(
                    value: 'Original audio',
                    child: UniversalText('Original audio'))
              ],
              onChanged: (value) {
                if (value != null) setState(() => audio = value);
              },
            ),
          ),
          const SizedBox(height: 18),
          Container(
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .045),
                borderRadius: BorderRadius.circular(17)),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(17),
              clipBehavior: Clip.antiAlias,
              child: SwitchListTile.adaptive(
                tileColor: Colors.transparent,
                title: const UniversalText('Subtitles',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const UniversalText('Use subtitles for this session',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
                value: subtitlesEnabled,
                onChanged: (value) => setState(() => subtitlesEnabled = value),
              ),
            ),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: () {
              AppController.instance.createGroupWatchSession(widget.media);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: const UniversalText('START GROUP WATCH'),
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16))),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// HOME INTELLIGENCE CENTERS
// ============================================================

/// Persistent entry point to the five platform foundations requested for Home.
/// This shelf is intentionally visible above the ordinary media rails.
class HomeMediaIntelligenceToolsShelf extends StatelessWidget {
  const HomeMediaIntelligenceToolsShelf({super.key});

  void _open(BuildContext context, Widget page, String route) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      settings: RouteSettings(name: route),
      builder: (_) => page,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final tools = <({
      String title,
      String subtitle,
      IconData icon,
      Color color,
      Widget page,
      String route
    })>[
      (
        title: 'Metadata Intelligence',
        subtitle: 'Audit data gaps and review matches',
        icon: Icons.manage_search_rounded,
        color: const Color(0xFF8B7CFF),
        page: const MetadataIntelligenceCenterScreen(),
        route: '/app/metadata-intelligence'
      ),
      (
        title: 'Collection Completion',
        subtitle: 'Owned titles versus catalog totals',
        icon: Icons.checklist_rounded,
        color: const Color(0xFF9DE5B0),
        page: const CollectionCompletionCenterScreen(),
        route: '/app/collection-completion'
      ),
      (
        title: 'Smart Collections & Planner',
        subtitle: 'Build collections and marathons',
        icon: Icons.auto_awesome_mosaic_rounded,
        color: const Color(0xFFFFD18C),
        page: const SmartCollectionsWatchPlannerScreen(),
        route: '/app/smart-collections-planner'
      ),
      (
        title: 'Playback & Server Health',
        subtitle: 'Catalog readiness and diagnostics',
        icon: Icons.monitor_heart_rounded,
        color: const Color(0xFF80D5FF),
        page: const PlaybackServerHealthCenterScreen(),
        route: '/app/playback-server-health'
      ),
      (
        title: 'Verified Backup & Recovery',
        subtitle: 'Backup status and restore readiness',
        icon: Icons.verified_user_rounded,
        color: const Color(0xFFFFA6A6),
        page: const VerifiedBackupRecoveryCenterScreen(),
        route: '/app/verified-backup-recovery'
      ),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PremiumSectionHeader(
            title: 'Library Intelligence & System Tools',
            subtitle:
                'Catalog quality, collection progress, smart planning, health, and recovery',
          ),
          HomeArrowRail(
            height: 126,
            itemCount: tools.length,
            separatorExtent: 10,
            padding: const EdgeInsets.symmetric(horizontal: 48),
            itemBuilder: (context, index) {
              final tool = tools[index];
              return SizedBox(
                width: 230,
                child: Material(
                  color: const Color(0xFF171722),
                  borderRadius: BorderRadius.circular(17),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _open(context, tool.page, tool.route),
                    child: Padding(
                      padding: const EdgeInsets.all(13),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: tool.color.withValues(alpha: .14),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(tool.icon, color: tool.color, size: 23),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(tool.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900)),
                                const SizedBox(height: 4),
                                Text(tool.subtitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 10,
                                        height: 1.25,
                                        color: Colors.white60)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class MetadataIntelligenceCenterScreen extends StatefulWidget {
  const MetadataIntelligenceCenterScreen({super.key});

  @override
  State<MetadataIntelligenceCenterScreen> createState() =>
      _MetadataIntelligenceCenterScreenState();
}

class _MetadataIntelligenceCenterScreenState
    extends State<MetadataIntelligenceCenterScreen> {
  String _filter = 'All issues';
  String _query = '';

  String _normalized(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  Set<String> _duplicateIds(List<MediaItem> items) {
    final buckets = <String, List<MediaItem>>{};
    for (final item in items) {
      final identity =
          _normalized(item.canonicalTitle ?? item.originalTitle ?? item.title);
      final type = item.type.toLowerCase().trim();
      final year = item.releaseYear ?? item.seriesStartYear;
      final key = '$identity|$type|${year ?? 'unknown'}';
      if (identity.isEmpty || item.canonicalWorkId?.trim().isNotEmpty == true) {
        continue;
      }
      buckets.putIfAbsent(key, () => <MediaItem>[]).add(item);
    }
    return buckets.values
        .where((bucket) => bucket.map((item) => item.id).toSet().length > 1)
        .expand((bucket) => bucket.map((item) => item.id))
        .toSet();
  }

  List<String> _issuesFor(MediaItem item, {required bool duplicateCandidate}) {
    final issues = <String>[];
    if (item.imageUrl?.trim().isNotEmpty != true) issues.add('Artwork');
    if (item.description?.trim().isNotEmpty != true) issues.add('Description');
    if (item.releaseDate == null &&
        item.releaseYear == null &&
        item.seriesStartYear == null) {
      issues.add('Release info');
    }
    if (item.actors.isEmpty && item.directors.isEmpty && item.writers.isEmpty) {
      issues.add('Credits');
    }
    if (item.studios.isEmpty && item.companies.isEmpty) issues.add('Companies');
    if ((item.franchiseName?.trim().isNotEmpty != true) &&
        item.franchiseNames.isEmpty &&
        item.cinematicUniverseNames.isEmpty &&
        item.cinematicUniverseSaga?.trim().isNotEmpty != true) {
      issues.add('Franchise links');
    }
    if (duplicateCandidate) issues.add('Potential duplicate');
    return issues;
  }

  void _openTitle(BuildContext context, MediaItem item) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/app/details'),
      builder: (_) => MediaDetailsScreen(media: item),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppController.instance,
      builder: (context, _) {
        final controller = AppController.instance;
        final profile = controller.currentProfile;
        final items = controller.library
            .where((item) => item.isAccessibleTo(profile))
            .toList(growable: false);
        final duplicates = _duplicateIds(items);
        final audits = <({MediaItem item, List<String> issues})>[];
        for (final item in items) {
          final issues = _issuesFor(item,
              duplicateCandidate: duplicates.contains(item.id));
          if (issues.isNotEmpty) audits.add((item: item, issues: issues));
        }
        final artworkMissing =
            audits.where((entry) => entry.issues.contains('Artwork')).length;
        final releaseMissing = audits
            .where((entry) => entry.issues.contains('Release info'))
            .length;
        final creditsMissing =
            audits.where((entry) => entry.issues.contains('Credits')).length;
        final displayed = audits.where((entry) {
          final matchesFilter =
              _filter == 'All issues' || entry.issues.contains(_filter);
          final query = _query.trim().toLowerCase();
          return matchesFilter &&
              (query.isEmpty || entry.item.title.toLowerCase().contains(query));
        }).toList(growable: false);

        return Scaffold(
          backgroundColor: const Color(0xFF0B0B10),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0B0B10),
            title: const Text('Metadata Intelligence Center'),
            actions: [
              IconButton(
                tooltip: 'Refresh audit',
                onPressed: () => setState(() {}),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF171722),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.info_outline_rounded,
                            color: Color(0xFF8B7CFF)),
                        SizedBox(width: 9),
                        Expanded(
                            child: Text('Local catalog audit',
                                style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900))),
                      ]),
                      const SizedBox(height: 7),
                      Text(
                          '${items.length} profile-visible titles reviewed. This audit finds metadata gaps and possible duplicates; it does not invent values or automatically merge titles.',
                          style: const TextStyle(
                              color: Colors.white60,
                              height: 1.4,
                              fontSize: 12)),
                      const SizedBox(height: 12),
                      const Text('External metadata provider: Not connected',
                          style: TextStyle(
                              color: Color(0xFFFFD18C),
                              fontWeight: FontWeight.w800,
                              fontSize: 12)),
                      const SizedBox(height: 4),
                      const Text(
                          'Connect a licensed metadata provider in the backend to fetch and verify remote credits, release dates, artwork, studio, and franchise facts.',
                          style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              height: 1.35)),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                          onPressed: () => Navigator.of(context)
                              .push(MaterialPageRoute<void>(
                            settings:
                                const RouteSettings(name: '/app/page/import'),
                            builder: (_) => const ImportMediaScreen(),
                          )),
                          icon: const Icon(Icons.add_to_photos_outlined),
                          label: const Text('Open Import Media'),
                        ),
                      ),
                    ]),
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 9, runSpacing: 9, children: [
                _MetadataMetric(
                    label: 'Titles',
                    value: '${items.length}',
                    icon: Icons.video_library_rounded),
                _MetadataMetric(
                    label: 'Missing artwork',
                    value: '$artworkMissing',
                    icon: Icons.image_not_supported_outlined),
                _MetadataMetric(
                    label: 'Missing release info',
                    value: '$releaseMissing',
                    icon: Icons.event_busy_outlined),
                _MetadataMetric(
                    label: 'Missing credits',
                    value: '$creditsMissing',
                    icon: Icons.people_alt_outlined),
                _MetadataMetric(
                    label: 'Duplicate candidates',
                    value: '${duplicates.length}',
                    icon: Icons.copy_all_rounded),
              ]),
              const SizedBox(height: 18),
              TextField(
                onChanged: (value) => setState(() => _query = value),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: 'Filter titles in this audit',
                  filled: true,
                  fillColor: const Color(0xFF171722),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final filter in const [
                    'All issues',
                    'Artwork',
                    'Description',
                    'Release info',
                    'Credits',
                    'Companies',
                    'Franchise links',
                    'Potential duplicate'
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: ChoiceChip(
                        label: Text(filter),
                        selected: _filter == filter,
                        onSelected: (_) => setState(() => _filter = filter),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 10),
              Text(
                  '${displayed.length} title${displayed.length == 1 ? '' : 's'} need review',
                  style: const TextStyle(
                      color: Colors.white70, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              if (displayed.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                      child: Text(
                          'No matching issues in the current local catalog.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54))),
                )
              else
                for (final entry in displayed)
                  Card(
                    color: const Color(0xFF171722),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                            width: 42,
                            height: 58,
                            child: entry.item.imageUrl?.trim().isNotEmpty ==
                                    true
                                ? Image.network(entry.item.imageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const ColoredBox(
                                            color: Color(0xFF252532),
                                            child: Icon(Icons.movie_outlined)))
                                : const ColoredBox(
                                    color: Color(0xFF252532),
                                    child: Icon(Icons.movie_outlined))),
                      ),
                      title: Text(entry.item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Wrap(spacing: 5, runSpacing: 4, children: [
                          for (final issue in entry.issues)
                            Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: .07),
                                    borderRadius: BorderRadius.circular(20)),
                                child: Text(issue,
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.white70))),
                        ]),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _openTitle(context, entry.item),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _MetadataMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _MetadataMetric(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(minWidth: 135),
        decoration: BoxDecoration(
            color: const Color(0xFF171722),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: Colors.white10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 20, color: const Color(0xFF8B7CFF)),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            Text(label,
                style: const TextStyle(fontSize: 10, color: Colors.white54)),
          ]),
        ]),
      );
}

class CollectionCompletionCenterScreen extends StatelessWidget {
  const CollectionCompletionCenterScreen({super.key});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: AppController.instance,
        builder: (context, _) {
          final controller = AppController.instance;
          final profile = controller.currentProfile;
          final items = controller.library
              .where((item) => item.isAccessibleTo(profile))
              .toList(growable: false);
          final franchises = HomeFranchiseProgressLogic.franchiseSagaExamples(
            items,
            HomeFranchiseProgressLogic.franchiseSagaGroups(items,
                collections: controller.collections),
          );
          final universes =
              HomeFranchiseProgressLogic.cinematicUniverseExamples(
            items,
            HomeFranchiseProgressLogic.cinematicUniverseGroups(items),
          );
          return Scaffold(
            backgroundColor: const Color(0xFF0B0B10),
            appBar: AppBar(
                backgroundColor: const Color(0xFF0B0B10),
                title: const Text('Collection Completion Center')),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
              children: [
                Text('Profile collection: ${items.length} local catalog titles',
                    style: const TextStyle(color: Colors.white60)),
                const SizedBox(height: 15),
                const Text('Franchises & Sagas',
                    style:
                        TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                if (franchises.isEmpty)
                  const Text(
                      'Import franchise metadata or use the featured examples below.',
                      style: TextStyle(color: Colors.white54)),
                for (final group in franchises)
                  _CollectionCompletionGroupTile(group: group),
                const SizedBox(height: 22),
                const Text('Cinematic Universes',
                    style:
                        TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                if (universes.isEmpty)
                  const Text(
                      'Import universe memberships or use the featured examples below.',
                      style: TextStyle(color: Colors.white54)),
                for (final group in universes)
                  _CollectionCompletionGroupTile(group: group),
                const SizedBox(height: 18),
                const Text(
                    'Completeness note: exact missing-title names require a complete external catalog. The owned counts above use only titles indexed in this profile.',
                    style: TextStyle(
                        color: Colors.white54, fontSize: 11, height: 1.4)),
              ],
            ),
          );
        },
      );
}

class _CollectionCompletionGroupTile extends StatelessWidget {
  final HomeFranchiseProgressGroup group;
  const _CollectionCompletionGroupTile({required this.group});

  @override
  Widget build(BuildContext context) {
    final total = group.totalTitles;
    final percentage = group.completionPercent;
    String count(int owned, int? all) =>
        all == null ? '$owned owned' : '$owned / $all';
    return Card(
      color: const Color(0xFF171722),
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Icon(
            group.type.toLowerCase().contains('universe')
                ? Icons.auto_awesome_rounded
                : Icons.account_tree_rounded,
            color: const Color(0xFF8B7CFF)),
        title: Text(group.name,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(total == null
            ? '${group.ownedTotalTitles} owned titles · total not available'
            : '${group.ownedTotalTitles} / $total titles · ${percentage ?? 0}%'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [
          if (group.completionFraction != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                      value: group.completionFraction,
                      minHeight: 6,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF9DE5B0)))),
            ),
          Row(children: [
            Expanded(
                child: Text(
                    'Movies: ${count(group.ownedMovies, group.totalMovies)}',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12))),
            Expanded(
                child: Text(
                    'Shows: ${count(group.ownedShows, group.totalShows)}',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)))
          ]),
          if (group.exampleNote != null)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(group.exampleNote!,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 11, height: 1.35))),
          const Divider(height: 20, color: Colors.white12),
          if (group.ownedTitles.isEmpty)
            const Text(
                'No matching titles are indexed for this profile yet. Add titles or import franchise/universe relationships to populate this list.',
                style:
                    TextStyle(color: Colors.white54, fontSize: 12, height: 1.4))
          else
            for (final media in group.ownedTitles)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.movie_outlined, size: 19),
                title: Text(media.title,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                    '${media.type} · ${media.displayYearLabel ?? 'Year unknown'}'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => MediaDetailsScreen(media: media))),
              ),
        ],
      ),
    );
  }
}

class SmartCollectionsWatchPlannerScreen extends StatelessWidget {
  const SmartCollectionsWatchPlannerScreen({super.key});

  void _open(BuildContext context, Widget page, String route) {
    Navigator.of(context).push(MaterialPageRoute<void>(
        settings: RouteSettings(name: route), builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: AppController.instance,
        builder: (context, _) {
          final controller = AppController.instance;
          final profile = controller.currentProfile;
          final items = controller.library
              .where((item) => item.isAccessibleTo(profile))
              .toList(growable: false);
          final unwatched = items
              .where((item) =>
                  !controller.isWatched(item.id) &&
                  !isExcludedEntertainmentType(item.type))
              .toList()
            ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
          final recent = List<MediaItem>.from(items)
            ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
          final groups = HomeFranchiseProgressLogic.franchiseSagaExamples(
            items,
            HomeFranchiseProgressLogic.franchiseSagaGroups(items,
                collections: controller.collections),
          );
          return Scaffold(
            backgroundColor: const Color(0xFF0B0B10),
            appBar: AppBar(
                backgroundColor: const Color(0xFF0B0B10),
                title: const Text('Smart Collections & Watch Planner')),
            body: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                children: [
                  const Text(
                      'Turn your library into useful collections and a viewing plan.',
                      style: TextStyle(color: Colors.white60)),
                  const SizedBox(height: 14),
                  _SystemActionCard(
                      icon: Icons.auto_awesome_mosaic_rounded,
                      title: 'Manage Smart Collections',
                      subtitle: 'Create and review rule-driven collections.',
                      onTap: () => _open(
                          context,
                          const SmartCollectionsScreen(),
                          '/app/smart-collections')),
                  _SystemActionCard(
                      icon: Icons.movie_filter_rounded,
                      title: 'Plan a Marathon',
                      subtitle: 'Build a saga or themed watch session.',
                      onTap: () => _open(context, const HeyMarathonScreen(),
                          '/app/marathon-planner')),
                  _SystemActionCard(
                      icon: Icons.account_tree_rounded,
                      title: 'Browse Franchise Navigator',
                      subtitle: 'Review release order and title relationships.',
                      onTap: () => _open(
                          context,
                          const FranchiseNavigatorScreen(),
                          '/app/franchise-navigator')),
                  const SizedBox(height: 16),
                  Text('Unwatched titles · ${unwatched.length}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  for (final media in unwatched.take(8))
                    ListTile(
                        leading: const Icon(Icons.play_circle_outline_rounded),
                        title: Text(media.title),
                        subtitle: Text(
                            '${media.type} · ${media.displayYearLabel ?? 'Year unknown'}'),
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) =>
                                    MediaDetailsScreen(media: media)))),
                  const SizedBox(height: 12),
                  Text('Recently added · ${recent.length}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  for (final media in recent.take(6))
                    ListTile(
                        leading: const Icon(Icons.new_releases_outlined),
                        title: Text(media.title),
                        subtitle: Text(
                            '${media.type} · ${media.displayYearLabel ?? 'Year unknown'}'),
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) =>
                                    MediaDetailsScreen(media: media)))),
                  const SizedBox(height: 12),
                  Text('Suggested saga marathons · ${groups.length}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900)),
                  for (final group in groups.take(6))
                    ListTile(
                        leading: const Icon(Icons.local_movies_outlined),
                        title: Text(group.name),
                        subtitle: Text(
                            '${group.ownedTotalTitles} titles available in your local catalog'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _open(
                            context,
                            const FranchiseNavigatorScreen(),
                            '/app/franchise-navigator')),
                ]),
          );
        },
      );
}

class PlaybackServerHealthCenterScreen extends StatelessWidget {
  const PlaybackServerHealthCenterScreen({super.key});

  void _open(BuildContext context, Widget page, String route) {
    Navigator.of(context).push(MaterialPageRoute<void>(
        settings: RouteSettings(name: route), builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: AppController.instance,
        builder: (context, _) {
          final controller = AppController.instance;
          final profile = controller.currentProfile;
          final items = controller.library
              .where((item) => item.isAccessibleTo(profile))
              .toList(growable: false);
          final directStreams = items
              .where((item) => item.playbackUrl?.trim().isNotEmpty == true)
              .length;
          final missingArtwork = items
              .where((item) => item.imageUrl?.trim().isNotEmpty != true)
              .length;
          final missingDescriptions = items
              .where((item) => item.description?.trim().isNotEmpty != true)
              .length;
          final watchedCount = controller.watched
              .where((item) => item.isAccessibleTo(profile))
              .length;
          return Scaffold(
            backgroundColor: const Color(0xFF0B0B10),
            appBar: AppBar(
                backgroundColor: const Color(0xFF0B0B10),
                title: const Text('Playback & Server Health')),
            body: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: const Color(0xFF171722),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10)),
                    child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Live host telemetry: Not connected',
                              style: TextStyle(
                                  color: Color(0xFFFFD18C),
                                  fontWeight: FontWeight.w900)),
                          SizedBox(height: 6),
                          Text(
                              'Numbers below are a local catalog readiness snapshot. Disk health, actual stream throughput, transcoder load, remote gateway status, and alert delivery require a host collector or backend diagnostics service.',
                              style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                  height: 1.4)),
                        ]),
                  ),
                  const SizedBox(height: 12),
                  Wrap(spacing: 9, runSpacing: 9, children: [
                    _MetadataMetric(
                        label: 'Visible titles',
                        value: '${items.length}',
                        icon: Icons.video_library_rounded),
                    _MetadataMetric(
                        label: 'Direct stream URLs',
                        value: '$directStreams',
                        icon: Icons.play_circle_outline_rounded),
                    _MetadataMetric(
                        label: 'Missing artwork',
                        value: '$missingArtwork',
                        icon: Icons.image_not_supported_outlined),
                    _MetadataMetric(
                        label: 'Missing descriptions',
                        value: '$missingDescriptions',
                        icon: Icons.description_outlined),
                    _MetadataMetric(
                        label: 'Watched titles',
                        value: '$watchedCount',
                        icon: Icons.visibility_outlined),
                  ]),
                  const SizedBox(height: 16),
                  _SystemActionCard(
                      icon: Icons.health_and_safety_rounded,
                      title: 'Media Catalog Health',
                      subtitle:
                          'Review missing posters, descriptions, and direct stream URLs.',
                      onTap: () => _open(context, const MediaHealthScreen(),
                          '/app/media-health')),
                  _SystemActionCard(
                      icon: Icons.troubleshoot_rounded,
                      title: 'Playback Diagnostics',
                      subtitle:
                          'Review playback diagnostics and troubleshooting guidance.',
                      onTap: () => _open(
                          context,
                          const PlaybackDiagnosticsCenterScreen(),
                          '/app/playback-diagnostics')),
                  _SystemActionCard(
                      icon: Icons.storage_rounded,
                      title: 'Server & Storage Reliability',
                      subtitle:
                          'Review capacity estimates and service readiness signals.',
                      onTap: () => _open(
                          context,
                          const PlatformReliabilityCenterScreen(),
                          '/app/platform-reliability')),
                ]),
          );
        },
      );
}

class VerifiedBackupRecoveryCenterScreen extends StatelessWidget {
  const VerifiedBackupRecoveryCenterScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF0B0B10),
        appBar: AppBar(
            backgroundColor: const Color(0xFF0B0B10),
            title: const Text('Verified Backup & Recovery')),
        body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
            children: [
              Container(
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                    color: const Color(0xFF171722),
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(color: Colors.white10)),
                child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Local settings backup: automatic',
                          style: TextStyle(
                              color: Color(0xFF91E6B3),
                              fontWeight: FontWeight.w900,
                              fontSize: 17)),
                      SizedBox(height: 7),
                      Text(
                          'The app now checkpoints local preferences and customization state every 12 minutes, updates the latest recovery point when changes are detected, and validates snapshots with a checksum. Server/database and off-site backup readiness remains unverified until a separate server-side backup target is configured and a restore drill succeeds.',
                          style: TextStyle(
                              color: Colors.white60,
                              height: 1.45,
                              fontSize: 12)),
                    ]),
              ),
              const SizedBox(height: 18),
              const Text('Recovery readiness checklist',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const _RecoveryReadinessRow(
                  title: 'Server/off-site backup target configured',
                  detail: 'Not verified; separate from local settings snapshots'),
              const _RecoveryReadinessRow(
                  title: 'Latest backup manifest/checksum validated',
                  detail: 'Not verified from this client'),
              const _RecoveryReadinessRow(
                  title: 'Off-site copy available',
                  detail: 'Not verified from this client'),
              const _RecoveryReadinessRow(
                  title: 'Restore drill completed successfully',
                  detail: 'Not verified from this client'),
              const SizedBox(height: 14),
              _SystemActionCard(
                  icon: Icons.backup_rounded,
                  title: 'Open Backup & Recovery',
                  subtitle:
                      'Choose metadata, watch history, profiles/settings, and collections for a backup request.',
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          settings:
                              const RouteSettings(name: '/app/backup-recovery'),
                          builder: (_) => const BackupScreen()))),
              _SystemActionCard(
                  icon: Icons.monitor_heart_rounded,
                  title: 'Review Server Reliability',
                  subtitle:
                      'Plan storage reserve and review server/gateway readiness signals.',
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          settings: const RouteSettings(
                              name: '/app/platform-reliability'),
                          builder: (_) =>
                              const PlatformReliabilityCenterScreen()))),
            ]),
      );
}

class _RecoveryReadinessRow extends StatelessWidget {
  final String title;
  final String detail;
  const _RecoveryReadinessRow({required this.title, required this.detail});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.help_outline_rounded,
              color: Colors.white38, size: 19),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(detail,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 11)),
              ])),
        ]),
      );
}

class _SystemActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _SystemActionCard(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFF171722),
        margin: const EdgeInsets.only(bottom: 9),
        child: ListTile(
          leading: Icon(icon, color: const Color(0xFF8B7CFF)),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(subtitle,
              style: const TextStyle(color: Colors.white60, height: 1.3)),
          trailing:
              const Icon(Icons.chevron_right_rounded, color: Colors.white54),
          onTap: onTap,
        ),
      );
}
