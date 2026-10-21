// Owns the app shell's current page identity and Navigator route tracking.
// Kept separate from main.dart so routing behavior can be maintained and tested
// without editing the large root application widget.
import 'package:flutter/material.dart';

final AppPageState appPageState = AppPageState();
final AppPageRouteObserver appPageRouteObserver = AppPageRouteObserver();

int? primaryIndexForPage(String pageId) => switch (pageId) {
      'home' => 0,
      'library' ||
      'movies' ||
      'series' ||
      'music' ||
      'people' ||
      'actors' ||
      'artists' ||
      'bands' ||
      'shop' ||
      'marketplace' ||
      'food-delivery' ||
      'public-live-tv' ||
      'my-tv' =>
        1,
      'friends' => 2,
      _ => null,
    };

class AppPageState extends ChangeNotifier {
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

class AppPageRouteObserver extends NavigatorObserver {
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
      appPageState.setPage(
        pageId,
        selectedPrimaryIndex: selectedPrimaryIndex,
        customizing: customizing,
      );
      return;
    }

    final updateId = ++_pendingPageUpdate;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (updateId != _pendingPageUpdate) return;
      appPageState.setPage(
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
      return appPageState.pageId;
    }
    if (name == '/app/player' ||
        name == '/app/page/public-live-tv/fullscreen') {
      return 'player';
    }
    if (name != null && name.startsWith('/app/page/')) {
      return name.substring('/app/page/'.length);
    }
    if (name == '/app/shop') return 'shop';
    if (name == '/app/page/food-delivery') return 'food-delivery';
    if (name == '/app/details') return 'details';
    if (name == '/app/customize' || name == '/app/more') {
      return appPageState.pageId;
    }
    if (name == '/app/profiles') return 'profiles';
    if (name == '/app/server-selection') return 'server-selection';
    if (name != null && name.startsWith('/main/')) {
      final destination = name.substring('/main/'.length);
      if (destination == 'home' || destination == 'library' || destination == 'friends') {
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
    appPageState.setPage(
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
      selectedPrimaryIndex: primaryIndexForPage(pageId),
      customizing: _isUnnamedPopup(route)
          ? appPageState.isCustomizing
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
        selectedPrimaryIndex: primaryIndexForPage(previousPageId),
        customizing: _isUnnamedPopup(previousRoute)
            ? appPageState.isCustomizing
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
        selectedPrimaryIndex: primaryIndexForPage(pageId),
        customizing: _isUnnamedPopup(newRoute)
            ? appPageState.isCustomizing
            : name == '/app/customize' || name == '/app/more',
      );
    }
  }
}
