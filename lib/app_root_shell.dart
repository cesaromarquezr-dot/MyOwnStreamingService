// Root MaterialApp shell for MyOwnStreamingService.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_accessibility.dart';
import 'app_core.dart';
import 'app_theme.dart';
import 'localization.dart';
import 'navigation/app_route_state.dart';
import 'navigation/page_appearance_store.dart';
import 'page_customization_button.dart';
import 'responsive.dart';

/// Shared Navigator key used by app routes and the root MaterialApp.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Owns global locale, navigator, overlays, theme and app-surface composition.
class AppRootShell extends StatefulWidget {
  const AppRootShell({
    super.key,
    required this.navigatorKey,
    required this.home,
    required this.onConfigurePageCustomization,
    required this.primaryNavigationBuilder,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget home;
  final void Function(BuildContext context, String pageId)
      onConfigurePageCustomization;
  final WidgetBuilder primaryNavigationBuilder;

  @override
  State<AppRootShell> createState() => _AppRootShellState();
}

class _AppRootShellState extends State<AppRootShell> {
  @override
  void initState() {
    super.initState();
    PageCustomizationController.configure(widget.onConfigurePageCustomization);
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
      navigatorKey: widget.navigatorKey,
      navigatorObservers: <NavigatorObserver>[appPageRouteObserver],
      title: tr('My Personal Streaming Service'),
      builder: (context, child) {
        // One Overlay remains above the app Navigator so both routes and the
        // language picker share the same overlay ancestry.
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
                              primaryNavigationBuilder:
                                  widget.primaryNavigationBuilder,
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
                  animation: appPageState,
                  builder: (context, _) {
                    final profileSelected =
                        AppController.instance.currentProfile != null;
                    final routeIsOnboarding =
                        appPageState.pageId == 'boot' ||
                        appPageState.pageId == 'profiles' ||
                        appPageState.pageId == 'server-selection' ||
                        appPageState.pageId == 'import';
                    if (!profileSelected ||
                        routeIsOnboarding ||
                        appPageState.pageId == 'player') {
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
      theme: AppTheme.dark,
      home: widget.home,
    );
  }
}

class _AppPageSurface extends StatelessWidget {
  const _AppPageSurface({
    required this.child,
    required this.primaryNavigationBuilder,
  });

  final Widget child;
  final WidgetBuilder primaryNavigationBuilder;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        appPageState,
        AppController.instance,
        AppAccessibilitySettings.instance,
      ]),
      builder: (context, _) {
        final accessibilityProfileId = AppController.instance.currentProfile?.id;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          AppAccessibilitySettings.instance.ensureLoaded(
            profileId: accessibilityProfileId,
          );
        });
        final appearance = PageAppearanceStore.forPage(appPageState.pageId);
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
              ? baseTheme.textTheme.apply(
                  bodyColor: Colors.white,
                  displayColor: Colors.white,
                )
              : baseTheme.textTheme,
          visualDensity: density,
        );
        final media = MediaQuery.of(context);
        final systemScale = media.textScaler.scale(14.0) / 14.0;
        final effectiveTextScale =
            (systemScale * accessibility.appTextScale).clamp(0.75, 2.2).toDouble();
        final showGlobalNavigation =
            AppController.instance.currentProfile != null &&
                appPageState.pageId != 'boot' &&
                appPageState.pageId != 'profiles' &&
                appPageState.pageId != 'server-selection' &&
                appPageState.pageId != 'import' &&
                appPageState.pageId != 'player' &&
                appPageState.pageId != 'customize' &&
                appPageState.pageId != 'more' &&
                !appPageState.isCustomizing;
        const globalNavigationHeight = 84.0;
        final bottomInset = showGlobalNavigation
            ? globalNavigationHeight + MediaQuery.paddingOf(context).bottom
            : 0.0;
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
                  padding: EdgeInsets.only(bottom: bottomInset),
                  child: child,
                ),
                if (showGlobalNavigation)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: SafeArea(
                      top: false,
                      child: primaryNavigationBuilder(context),
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
