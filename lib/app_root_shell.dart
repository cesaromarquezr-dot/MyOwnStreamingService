import 'dart:io';

// Root MaterialApp shell for MyOwnStreamingService.
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    as flutter_localizations;

import 'app_accessibility.dart';
import 'app_core.dart';
import 'app_theme.dart';
import 'interface_experience.dart';
import 'interface_appearance.dart';
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
        flutter_localizations.GlobalWidgetsLocalizations.delegate,
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
                    final routeIsOnboarding = appPageState.pageId == 'boot' ||
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
        InterfaceAppearanceStore.revision,
        InterfaceExperienceRepository.instance.notifier,
      ]),
      builder: (context, _) {
        final accessibilityProfileId =
            AppController.instance.currentProfile?.id;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          AppAccessibilitySettings.instance.ensureLoaded(
            profileId: accessibilityProfileId,
          );
          if (InterfaceAppearanceStore.profileId !=
              (accessibilityProfileId?.trim().isNotEmpty == true
                  ? accessibilityProfileId
                  : 'default')) {
            InterfaceAppearanceStore.load(profileId: accessibilityProfileId);
          }
        });
        final pageAppearance = PageAppearanceStore.forPage(appPageState.pageId);
        final activeMode = InterfaceExperienceRepository
                .instance.notifier.value?.activeExperience ??
            'classic';
        final skin = InterfaceAppearanceStore.forMode(activeMode);
        final accessibility = AppAccessibilitySettings.instance;
        final useHighContrast =
            accessibility.highContrast || skin.skinPreset == 'High Contrast';
        final density = switch (pageAppearance.density) {
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
        final bodyFont = skin.fontAssignments['Descriptions'];
        final appTitleFont = skin.fontAssignments['Application title'];
        final sectionFont = skin.fontAssignments['Section headings'];
        final mediaTitleFont = skin.fontAssignments['Movie and show titles'];
        final navigationFont = skin.fontAssignments['Navigation'];
        final buttonFont = skin.fontAssignments['Buttons'];
        final metadataFont = skin.fontAssignments['Metadata and ratings'];
        final radius = Radius.circular(skin.cornerRadius);
        final hasModeBackdrop = skin.backdropPath.isNotEmpty &&
            File(skin.backdropPath).existsSync();
        final isGlass = skin.skinPreset.toLowerCase().contains('glass') ||
            skin.skinPreset.toLowerCase().contains('crystal');
        final cardTint = Color(skin.backgroundColor).withValues(
          alpha: (skin.cardOpacity * (isGlass ? (1 - skin.transparency) : 1))
              .clamp(.08, 1),
        );
        final sourceTextTheme = useHighContrast
            ? baseTheme.textTheme.apply(
                bodyColor: Colors.white,
                displayColor: Colors.white,
              )
            : baseTheme.textTheme;
        final themedText = sourceTextTheme.copyWith(
          displayLarge:
              sourceTextTheme.displayLarge?.copyWith(fontFamily: appTitleFont),
          displayMedium:
              sourceTextTheme.displayMedium?.copyWith(fontFamily: appTitleFont),
          displaySmall:
              sourceTextTheme.displaySmall?.copyWith(fontFamily: appTitleFont),
          headlineLarge: sourceTextTheme.headlineLarge
              ?.copyWith(fontFamily: sectionFont ?? appTitleFont),
          headlineMedium: sourceTextTheme.headlineMedium
              ?.copyWith(fontFamily: sectionFont ?? appTitleFont),
          headlineSmall: sourceTextTheme.headlineSmall
              ?.copyWith(fontFamily: sectionFont ?? appTitleFont),
          titleLarge: sourceTextTheme.titleLarge?.copyWith(
              fontFamily: mediaTitleFont ?? sectionFont ?? appTitleFont),
          titleMedium: sourceTextTheme.titleMedium?.copyWith(
              fontFamily: mediaTitleFont ?? sectionFont ?? appTitleFont),
          bodyLarge: sourceTextTheme.bodyLarge?.copyWith(fontFamily: bodyFont),
          bodyMedium:
              sourceTextTheme.bodyMedium?.copyWith(fontFamily: bodyFont),
          bodySmall: sourceTextTheme.bodySmall
              ?.copyWith(fontFamily: metadataFont ?? bodyFont),
          labelLarge:
              sourceTextTheme.labelLarge?.copyWith(fontFamily: buttonFont),
          labelMedium: sourceTextTheme.labelMedium
              ?.copyWith(fontFamily: navigationFont ?? buttonFont),
          labelSmall:
              sourceTextTheme.labelSmall?.copyWith(fontFamily: metadataFont),
        );
        final theme = baseTheme.copyWith(
          scaffoldBackgroundColor: useHighContrast
              ? Colors.black
              : Color(skin.backgroundColor).withValues(
                  alpha: hasModeBackdrop ? .72 : 1,
                ),
          colorScheme: useHighContrast
              ? highContrastScheme
              : ColorScheme.fromSeed(
                  seedColor: Color(skin.accentColor),
                  brightness: baseTheme.brightness,
                ),
          textTheme: themedText,
          cardTheme: CardThemeData(
            color: cardTint,
            surfaceTintColor: Colors.transparent,
            elevation: isGlass ? 0 : baseTheme.cardTheme.elevation ?? 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(radius),
              side: skin.borderHighlights && isGlass
                  ? BorderSide(color: Colors.white.withValues(alpha: .16))
                  : BorderSide.none,
            ),
          ),
          iconTheme: IconThemeData(color: Color(skin.accentColor)),
          visualDensity: density,
        );
        final media = MediaQuery.of(context);
        final systemScale = media.textScaler.scale(14.0) / 14.0;
        final effectiveTextScale = (systemScale * accessibility.appTextScale)
            .clamp(0.75, 2.2)
            .toDouble();
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
                if (hasModeBackdrop)
                  Positioned.fill(
                    child: Image.file(
                      File(skin.backdropPath),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                if (hasModeBackdrop)
                  Positioned.fill(
                    child: ColoredBox(
                      color: Color(skin.backgroundColor).withValues(alpha: .38),
                    ),
                  ),
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
