// FILE: `lib/main.dart`.
// Purpose: Implements the main portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_core.dart';
import 'backend_api.dart';
import 'signup.dart';
import 'movies.dart';
import 'series.dart';
import 'smart_search.dart';
import 'details.dart';
import 'profiles.dart';
import 'feature_center.dart';
import 'ultimate_features.dart';
import 'ultimate_platform.dart';
import 'library_privacy.dart';
import 'remote_access.dart';
import 'account_settings.dart';
import 'device_features.dart';
import 'roadmap_features.dart';
import 'next_gen_features.dart';
import 'how_it_works.dart';
import 'sports.dart';
import 'platform_expansion.dart';
import 'music.dart';
import 'home_server.dart';
import 'storage_dashboard.dart';
import 'library_hubs.dart';
import 'home_widgets.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HomeCustomizationStore.initialize();
  await DetailsCustomizationStore.initialize();
  await AppController.instance.initializeBadges();
  await PlatformPreferenceStore.initialize();
  runApp(const MyStreamingService());
}
class MyStreamingService extends StatelessWidget {
  const MyStreamingService({super.key});
  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Streaming Service',
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
      home: const SplashScreen(),
    );
  }
}
// ============================================================
// SPLASH SCREEN
// ============================================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}
class _SplashScreenState extends State<SplashScreen> {
  @override
  /// Performs `initState` for this feature. Update this documentation when its contract changes.
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HowItWorksScreen(
            loginBuilder: (_) => const LoginScreen(),
          ),
        ),
      );
    });
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
            Text(
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
        const SnackBar(
          content: Text(
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
      await controller.loginWithBackend(
        email: email,
        password: password,
      );

      final security = controller.lastLoginSecurity;
      if (security?['suspicious'] == true) {
        final question = security?['question']?.toString().trim();
        if (question == null || question.isEmpty) {
          await controller.logoutFromBackend();
          throw Exception('This sign-in was flagged as suspicious, but no security question is configured.');
        }

        if (!mounted) return;
        final answerController = TextEditingController();
        final verified = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Suspicious Login Detected'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('This sign-in looks different from a known device or follows recent failed attempts.'),
                const SizedBox(height: 16),
                const Text('Security question', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(question, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                TextField(controller: answerController, autofocus: true, obscureText: true, decoration: const InputDecoration(labelText: 'Enter your answer')),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('SIGN OUT')),
              FilledButton(onPressed: () async {
                try {
                  final ok = await controller.backendApi.verifySecurityAnswer(answerController.text);
                  if (dialogContext.mounted) Navigator.pop(dialogContext, ok);
                } catch (_) {
                  if (dialogContext.mounted) Navigator.pop(dialogContext, false);
                }
              }, child: const Text('VERIFY')),
            ],
          ),
        );
        answerController.dispose();
        if (verified != true) {
          await controller.logoutFromBackend();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Access denied. The security answer was incorrect.')));
          return;
        }
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileSelectionScreen(
            onProfileSelected: (context) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const MainScreen(),
                ),
              );
            },
          ),
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
                const Text(
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
                  decoration: const InputDecoration(
                    labelText: 'Email address',
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
                    labelText: 'Password',
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
                                obscurePassword =
                                    !obscurePassword;
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
                        : const Text(
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
                              builder: (_) =>
                                  const SignupScreen(),
                            ),
                          );
                        },
                  child: const Text(
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

class HomeCustomization {
  bool showHero;
  bool showContinueWatching;
  bool showRecentlyWatched;
  bool showMovies;
  bool showTvShows;
  bool showNewAdditions;
  bool showAllLibrary;
  bool showRecommendations;
  bool showLiveSports;
  bool showMusic;
  bool showFilm;
  String homeMediaLayout;
  String heroStyle;
  String cardSize;
  String navbarPosition;
  String storageBarPosition;
  String liveSportsPosition;
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

  HomeCustomization({
    this.showHero = true,
    this.showContinueWatching = true,
    this.showRecentlyWatched = true,
    this.showMovies = true,
    this.showTvShows = true,
    this.showNewAdditions = true,
    this.showAllLibrary = false,
    this.showRecommendations = true,
    this.showLiveSports = true,
    this.showMusic = true,
    this.showFilm = true,
    this.homeMediaLayout = 'Left & Right',
    this.heroStyle = 'Cinematic',
    this.cardSize = 'Medium',
    this.navbarPosition = 'Bottom',
    this.storageBarPosition = 'Bottom',
    this.liveSportsPosition = 'Top',
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
  }) : sectionOrder = sectionOrder ?? [
          'Continue Watching',
          'Recently Watched',
          'Movies',
          'TV Shows',
          'New Additions',
          'All Library',
          'Recommendations',
          'Music & Film',
          'Live Sports',
        ],
        navigationOrder = navigationOrder ?? [
          'Profile',
          'Home',
          'Live Sports',
          'More',
          'Music',
          'Film',
        ];

  HomeCustomization copy() => HomeCustomization(
        showHero: showHero,
        showContinueWatching: showContinueWatching,
        showRecentlyWatched: showRecentlyWatched,
        showMovies: showMovies,
        showTvShows: showTvShows,
        showNewAdditions: showNewAdditions,
        showAllLibrary: showAllLibrary,
        showRecommendations: showRecommendations,
        showLiveSports: showLiveSports,
        showMusic: showMusic,
        showFilm: showFilm,
        homeMediaLayout: homeMediaLayout,
        heroStyle: heroStyle,
        cardSize: cardSize,
        navbarPosition: navbarPosition,
        storageBarPosition: storageBarPosition,
        liveSportsPosition: liveSportsPosition,
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
      );
}

class HomeCustomizationStore {
  HomeCustomizationStore._();

  static final Map<String, HomeCustomization> _settings = <String, HomeCustomization>{};
  static final Set<String> _configuredProfiles = <String>{};
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
          _settings[key.substring(settingsPrefix.length)] = settings;
        } catch (_) {}
      } else if (key.startsWith(setupPrefix) && _prefs!.getBool(key) == true) {
        _configuredProfiles.add(key.substring(setupPrefix.length));
      }
    }
  }

  static String _key(Profile? profile) => profile?.id ?? 'default';

  static HomeCustomization settingsFor(Profile? profile) =>
      _settings.putIfAbsent(_key(profile), () => HomeCustomization()).copy();

  static HomeCustomization get settings => settingsFor(AppController.instance.currentProfile);

  static bool isConfigured(Profile? profile) => _configuredProfiles.contains(_key(profile));
  static bool get hasConfigured => isConfigured(AppController.instance.currentProfile);

  static void apply(HomeCustomization value, [Profile? profile]) {
    final key = _key(profile ?? AppController.instance.currentProfile);
    final copy = value.copy();
    _settings[key] = copy;
    _prefs?.setString('home_customization_$key', jsonEncode(_toJson(copy)));
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
  }

  static Map<String, dynamic> _toJson(HomeCustomization v) => {
    'showHero': v.showHero, 'showContinueWatching': v.showContinueWatching, 'showRecentlyWatched': v.showRecentlyWatched,
    'showMovies': v.showMovies, 'showTvShows': v.showTvShows, 'showNewAdditions': v.showNewAdditions,
    'showAllLibrary': v.showAllLibrary, 'showRecommendations': v.showRecommendations, 'showLiveSports': v.showLiveSports, 'showMusic': v.showMusic, 'showFilm': v.showFilm, 'homeMediaLayout': v.homeMediaLayout, 'heroStyle': v.heroStyle,
    'cardSize': v.cardSize, 'navbarPosition': v.navbarPosition, 'storageBarPosition': v.storageBarPosition, 'liveSportsPosition': v.liveSportsPosition, 'storageBarThickness': v.storageBarThickness,
    'homeBackgroundColor': v.homeBackgroundColor, 'navbarColor': v.navbarColor, 'navbarGlowColor': v.navbarGlowColor, 'navbarItemColor': v.navbarItemColor,
    'navbarStyle': v.navbarStyle, 'navbarOpacity': v.navbarOpacity, 'navbarRadius': v.navbarRadius,
    'sectionOrder': v.sectionOrder, 'navigationOrder': v.navigationOrder,
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

  static HomeCustomization _fromJson(Map<String, dynamic> m) => HomeCustomization(
    showHero: m['showHero'] == false ? false : true, showContinueWatching: m['showContinueWatching'] == false ? false : true,
    showRecentlyWatched: m['showRecentlyWatched'] == false ? false : true, showMovies: m['showMovies'] == false ? false : true,
    showTvShows: m['showTvShows'] == false ? false : true, showNewAdditions: m['showNewAdditions'] == false ? false : true,
    showAllLibrary: m['showAllLibrary'] == true, showRecommendations: m['showRecommendations'] == false ? false : true, showLiveSports: m['showLiveSports'] == false ? false : true,
    showMusic: m['showMusic'] == false ? false : true, showFilm: m['showFilm'] == false ? false : true, homeMediaLayout: m['homeMediaLayout']?.toString() ?? 'Left & Right',
    heroStyle: m['heroStyle']?.toString() ?? 'Cinematic', cardSize: m['cardSize']?.toString() ?? 'Medium',
    navbarPosition: m['navbarPosition']?.toString() ?? 'Bottom', storageBarPosition: m['storageBarPosition']?.toString() ?? 'Bottom', liveSportsPosition: m['liveSportsPosition']?.toString() ?? 'Top', storageBarThickness: (m['storageBarThickness'] is num ? (m['storageBarThickness'] as num).toDouble() : 12),
    homeBackgroundColor: _colorNameFromStored(m['homeBackgroundColor'], 'Black'),
    navbarColor: _colorNameFromStored(m['navbarColor'], 'Black'),
    navbarGlowColor: _colorNameFromStored(m['navbarGlowColor'], 'Red'),
    navbarItemColor: _colorNameFromStored(m['navbarItemColor'], 'Purple'),
    navbarStyle: m['navbarStyle']?.toString() ?? 'Solid',
    navbarOpacity: (m['navbarOpacity'] as num?)?.toDouble() ?? 0.95,
    navbarRadius: (m['navbarRadius'] as num?)?.toDouble() ?? 24,
    sectionOrder: m['sectionOrder'] is List ? List<String>.from(m['sectionOrder'] as List) : null,
    navigationOrder: m['navigationOrder'] is List ? List<String>.from(m['navigationOrder'] as List) : null,
  );
}

enum _CustomizationPage {
  home,
  details,
}

class CustomizeHomeScreen extends StatefulWidget {
  final bool firstSetup;

  const CustomizeHomeScreen({super.key, this.firstSetup = false});

  @override
  State<CustomizeHomeScreen> createState() => _CustomizeHomeScreenState();
}

class _CustomizeHomeScreenState extends State<CustomizeHomeScreen> {
  late HomeCustomization draft;
  late DetailsCustomization detailsDraft;
  _CustomizationPage selectedPage = _CustomizationPage.home;
  @override
  /// Performs `initState` for this feature. Update this documentation when its contract changes.
  void initState() {
    super.initState();
    draft = HomeCustomizationStore.settingsFor(AppController.instance.currentProfile);
    detailsDraft = DetailsCustomizationStore.settingsFor(
      AppController.instance.currentProfile,
    );
    _normalizeHomePositions();
  }

  void _normalizeHomePositions() {
    final positions = <String>['Top', 'Bottom', 'Left', 'Right'];
    if (draft.storageBarPosition != 'Hidden' && !positions.contains(draft.storageBarPosition)) draft.storageBarPosition = 'Bottom';
    if (!positions.contains(draft.liveSportsPosition) || draft.liveSportsPosition == draft.navbarPosition || draft.liveSportsPosition == draft.storageBarPosition) {
      draft.liveSportsPosition = positions.firstWhere((p) => p != draft.navbarPosition && p != draft.storageBarPosition, orElse: () => 'Top');
    }
  }

  /// Performs `_save` for this feature. Update this documentation when its contract changes.
  Future<void> _save() async {
    final profile = AppController.instance.currentProfile;

    if (widget.firstSetup && selectedPage == _CustomizationPage.home) {
      HomeCustomizationStore.apply(draft, profile);
      setState(() {
        selectedPage = _CustomizationPage.details;
      });
      return;
    }

    HomeCustomizationStore.apply(draft, profile);
    DetailsCustomizationStore.apply(profile, detailsDraft);

    if (widget.firstSetup) {
      await HomeCustomizationStore.markSetupCompleted(profile);
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  List<String> _availableHomePositions(HomeCustomization value, {bool allowHidden = false, bool excludeNavbar = true}) {
    final positions = <String>['Top', 'Bottom', 'Left', 'Right'];
    if (excludeNavbar) positions.removeWhere((p) => p == value.navbarPosition);
    if (excludeNavbar && value.storageBarPosition != 'Hidden') positions.removeWhere((p) => p == value.storageBarPosition);
    if (allowHidden) positions.add('Hidden');
    return positions.isEmpty ? <String>['Top'] : positions;
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
    required ValueChanged<String> onChanged,
  }) {
    final safeValue = values.contains(value) ? value : values.first;

    return DropdownButtonFormField<String>(
      initialValue: safeValue,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final item in values)
          DropdownMenuItem<String>(
            value: item,
            child: Text(item),
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
            selected: selectedPage == _CustomizationPage.home,
            onPressed: widget.firstSetup 
            ? () {}
            :(){
              setState(() {
                selectedPage = _CustomizationPage.home;
              });
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _customizationButton(
            label: 'DETAILS PAGE',
            icon: Icons.movie_outlined,
            selected: selectedPage == _CustomizationPage.details,
            onPressed: widget.firstSetup 
            ? () {}
        : () {
              setState(() {
                selectedPage = _CustomizationPage.details;
              });
            },
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
    required VoidCallback onPressed,
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
    final isHome = selectedPage == _CustomizationPage.home;

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
            isHome ? Icons.home_rounded : Icons.movie_outlined,
            color: Colors.redAccent,
            size: 30,
          ),
          const SizedBox(height: 12),
          Text(
            isHome
                ? (widget.firstSetup
                    ? 'How do you want your main screen to look?'
                    : 'Build your Home screen your way.')
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
                ? 'Choose what appears, change the presentation, position your navigation, and drag Home sections into the order you want.'
                : 'Choose which Details sections appear, control metadata and poster presentation, and drag sections into the order you want.',
            style: const TextStyle(
              color: Colors.white60,
              height: 1.45,
            ),
          ),
          if (!isHome) ...[
            const SizedBox(height: 12),
            Text(
              'Profile: ${AppController.instance.currentProfile?.name ?? 'No profile selected'}',
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
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
        const Text(
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
        const SizedBox(height: 24),
        const Text(
          'NAVIGATION & STORAGE',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 10),
        _dropdown(
          label: 'Where do you want your navbar?',
          value: draft.navbarPosition,
          values: const ['Bottom', 'Top', 'Left', 'Right', 'Floating'],
          onChanged: (value) => setState(() { draft.navbarPosition = value; _normalizeHomePositions(); }),
        ),
        const SizedBox(height: 12),
        _sectionOrder(
          title: 'NAVIGATION ORDER',
          subtitle: 'Drag navbar items to change their order. More stays as the expandable menu.',
          items: draft.navigationOrder,
          onChanged: (newOrder) => setState(() => draft.navigationOrder = newOrder),
        ),
        const SizedBox(height: 12),
        _dropdown(
          label: 'Where should the storage bar appear?',
          value: draft.storageBarPosition,
          values: _availableHomePositions(draft, allowHidden: true, excludeNavbar: false),
          onChanged: (value) => setState(() => draft.storageBarPosition = value),
        ),
        const SizedBox(height: 8),
        Text('Storage bar thickness: ${draft.storageBarThickness.round()} px', style: const TextStyle(color: Colors.white70)),
        Slider(value: draft.storageBarThickness.clamp(4, 32), min: 4, max: 32, divisions: 14, onChanged: (value) => setState(() => draft.storageBarThickness = value)),
        _dropdown(
          label: 'Where should Live Sports appear on Home?',
          value: draft.liveSportsPosition,
          values: _availableHomePositions(draft, excludeNavbar: true),
          onChanged: (value) => setState(() => draft.liveSportsPosition = value),
        ),
        const SizedBox(height: 8),
        const Text('A Home position is removed when it is already occupied by the navbar or storage bar.', style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.4)),
        const SizedBox(height: 24),
        const Text('COLORS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: Colors.white54)),
        const SizedBox(height: 10),
        _colorDropdown(
          label: 'Home background',
          value: draft.homeBackgroundColor,
          onChanged: (value) => setState(() => draft.homeBackgroundColor = value),
        ),
        const SizedBox(height: 10),
        _colorDropdown(
          label: 'Navbar color',
          value: draft.navbarColor,
          onChanged: (value) => setState(() => draft.navbarColor = value),
        ),
        const SizedBox(height: 10),
        _colorDropdown(
          label: 'Navbar glow outline',
          value: draft.navbarGlowColor,
          onChanged: (value) => setState(() => draft.navbarGlowColor = value),
        ),
        const SizedBox(height: 10),
        _colorDropdown(
          label: 'Navbar item color',
          value: draft.navbarItemColor,
          onChanged: (value) => setState(() => draft.navbarItemColor = value),
        ),
        const SizedBox(height: 10),
        _dropdown(
          label: 'Navbar shape',
          value: draft.navbarStyle,
          values: const ['Solid', 'Transparent', 'Curved', 'Angled'],
          onChanged: (value) => setState(() => draft.navbarStyle = value),
        ),
        const SizedBox(height: 10),
        Text('Navbar opacity: ${(draft.navbarOpacity * 100).round()}%', style: const TextStyle(color: Colors.white70)),
        Slider(
          value: draft.navbarOpacity.clamp(.10, 1.0),
          min: .10,
          max: 1.0,
          divisions: 18,
          label: '${(draft.navbarOpacity * 100).round()}%',
          onChanged: (value) => setState(() => draft.navbarOpacity = value),
        ),
        Text('Navbar corner radius: ${draft.navbarRadius.round()} px', style: const TextStyle(color: Colors.white70)),
        Slider(
          value: draft.navbarRadius.clamp(0, 42),
          min: 0,
          max: 42,
          divisions: 21,
          label: '${draft.navbarRadius.round()} px',
          onChanged: (value) => setState(() => draft.navbarRadius = value),
        ),
        const SizedBox(height: 24),
        const Text('HOME MEDIA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: Colors.white54)),
        const SizedBox(height: 10),
        _dropdown(
          label: 'Music + Film arrangement',
          value: draft.homeMediaLayout,
          values: const ['Left & Right', 'Top & Bottom'],
          onChanged: (value) => setState(() => draft.homeMediaLayout = value),
        ),
        _toggle('Music', 'Show a Music destination on Home.', draft.showMusic, (v) => setState(() => draft.showMusic = v)),
        _toggle('Film', 'Show Movies and Shows together on Home.', draft.showFilm, (v) => setState(() => draft.showFilm = v)),
        const SizedBox(height: 24),
        const Text(
          'SECTIONS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 10),
        _toggle(
          'Hero banner',
          'Show the featured title at the top.',
          draft.showHero,
          (v) => setState(() => draft.showHero = v),
        ),
        _toggle(
          'Continue Watching',
          'Resume movies and episodes you started.',
          draft.showContinueWatching,
          (v) => setState(() => draft.showContinueWatching = v),
        ),
        _toggle(
          'Recently Watched',
          'Show titles you watched most recently.',
          draft.showRecentlyWatched,
          (v) => setState(() => draft.showRecentlyWatched = v),
        ),
        _toggle(
          'Movies',
          'Show your movie collection.',
          draft.showMovies,
          (v) => setState(() => draft.showMovies = v),
        ),
        _toggle(
          'TV Shows',
          'Show your TV collection.',
          draft.showTvShows,
          (v) => setState(() => draft.showTvShows = v),
        ),
        _toggle(
          'New Additions',
          'Show the newest titles in your library.',
          draft.showNewAdditions,
          (v) => setState(() => draft.showNewAdditions = v),
        ),
        _toggle(
          'All Library',
          'Show everything in one section.',
          draft.showAllLibrary,
          (v) => setState(() => draft.showAllLibrary = v),
        ),
        _toggle('Live Sports', 'Show Live Sports when authentic/original authorized broadcasts are available.', draft.showLiveSports, (v) => setState(() => draft.showLiveSports = v)),
        const SizedBox(height: 24),
        _sectionOrder(
          title: 'SECTION ORDER',
          subtitle: 'Drag Home sections to change their order.',
          items: draft.sectionOrder,
        ),
      ],
    );
  }

  /// Performs `_buildDetailsPage` for this feature. Update this documentation when its contract changes.
  Widget _buildDetailsPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
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
          onChanged: (value) => setState(() => detailsDraft.posterStyle = value),
        ),
        const SizedBox(height: 12),
        _dropdown(
          label: 'Title alignment',
          value: detailsDraft.titleAlignment,
          values: const ['Left', 'Center', 'Right'],
          onChanged: (value) => setState(() => detailsDraft.titleAlignment = value),
        ),
        const SizedBox(height: 12),
        _dropdown(label: 'Poster position', value: detailsDraft.posterPosition, values: const ['Left', 'Center', 'Right'], onChanged: (v) => setState(() => detailsDraft.posterPosition = v)),
        const SizedBox(height: 12),
        _dropdown(label: 'Poster size', value: detailsDraft.posterSize, values: const ['Small', 'Medium', 'Large'], onChanged: (v) => setState(() => detailsDraft.posterSize = v)),
        const SizedBox(height: 12),
        _dropdown(label: 'Button alignment', value: detailsDraft.buttonAlignment, values: const ['Left', 'Center', 'Right'], onChanged: (v) => setState(() => detailsDraft.buttonAlignment = v)),
        const SizedBox(height: 12),
        _dropdown(label: 'Information alignment', value: detailsDraft.informationAlignment, values: const ['Left', 'Center', 'Right'], onChanged: (v) => setState(() => detailsDraft.informationAlignment = v)),
        const SizedBox(height: 24),
        const Text(
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
        const SizedBox(height: 24),
        const Text(
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
          onChanged: (value) => setState(() => detailsDraft.seasonPlacement = value),
        ),
        const SizedBox(height: 12),
        _dropdown(
          label: 'Season order',
          value: detailsDraft.seasonOrder,
          values: const ['Top to Bottom', 'Bottom to Top'],
          onChanged: (value) => setState(() => detailsDraft.seasonOrder = value),
        ),
        const SizedBox(height: 12),
        _dropdown(label: 'Season selector', value: detailsDraft.seasonSelectorStyle, values: const ['Buttons', 'Dropdown'], onChanged: (v) => setState(() => detailsDraft.seasonSelectorStyle = v)),
        const SizedBox(height: 12),
        _dropdown(label: 'Episode naming', value: detailsDraft.episodeNaming, values: const ['Actual Title', 'Season X, Episode Y', 'Both'], onChanged: (v) => setState(() => detailsDraft.episodeNaming = v)),
        const SizedBox(height: 24),
        const Text(
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
          title: 'DETAILS SECTION ORDER',
          subtitle: 'Drag Details sections to change their order.',
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
                  child: Text(
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
    final isHome = selectedPage == _CustomizationPage.home;

    return Scaffold(
      backgroundColor: const Color(0xFF070707),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070707),
        surfaceTintColor: Colors.transparent,
        title: Text(
          widget.firstSetup
              ? (selectedPage == _CustomizationPage.home ? 'Customize Home' : 'Customize Details')
              : 'Customize App',
        ),
        automaticallyImplyLeading: !widget.firstSetup,
        actions: widget.firstSetup
            ? const []
            : [
                TextButton(
                  onPressed: _save,
                  child: const Text(
                    'SAVE',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _pageSelector(),
            const SizedBox(height: 18),
            _headerCard(),
            const SizedBox(height: 24),
            if (isHome) _buildHomePage() else _buildDetailsPage(),
            const SizedBox(height: 26),
            SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_rounded),
                label: Text(
                  widget.firstSetup
                      ? (selectedPage == _CustomizationPage.home ? 'CONTINUE TO DETAILS' : 'ENTER MY HOME')
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



// ============================================================
// MAIN SCREEN
// ============================================================

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  String selectedDestination = 'Home';

  @override
  /// Performs `initState` for this feature. Update this documentation when its contract changes.
  void initState() {
    super.initState();
  }

  /// Performs `_openMore` for this feature. Update this documentation when its contract changes.
  void _openMore() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _MoreActionsSheet(
        onImport: () { Navigator.pop(context); _openImport(); },
        onProfiles: () { Navigator.pop(context); _openProfiles(); },
        onWishlist: () {
          Navigator.pop(context);
          showDialog<void>(context: context, builder: (_) => const WishlistDialog());
        },
        onCustomize: () {
          Navigator.pop(context);
          Navigator.of(context).push<bool>(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => const CustomizeHomeScreen(),
            ),
          ).then((_) { if (mounted) setState(() {}); });
        },
        onFeatureCenter: () { Navigator.pop(context); _openFeatureCenter(); },
        onEverything: () { Navigator.pop(context); _openEverything(); },
        onRemoteAccess: () { Navigator.pop(context); _openRemoteAccess(); },
        onAccountSettings: () { Navigator.pop(context); _openAccountSettings(); },
        onDevices: () { Navigator.pop(context); _openDevices(); },
        onRoadmapFeatures: () { Navigator.pop(context); _openRoadmapFeatures(); },
        onNextGen: () { Navigator.pop(context); _openNextGen(); },
        onPlatformExpansion: () { Navigator.pop(context); _openPlatformExpansion(); },
        onNotifications: () { Navigator.pop(context); _openNotifications(); },
      ),
    );
  }

  /// Performs `_openImport` for this feature. Update this documentation when its contract changes.
  void _openImport() {
    Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const ImportMediaScreen()))
        .then((_) { if (mounted) setState(() {}); });
  }

  /// Performs `_openProfiles` for this feature. Update this documentation when its contract changes.
  void _openProfiles() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileSelectionScreen()))
        .then((_) { if (mounted) setState(() {}); });
  }

  /// Performs `_openFeatureCenter` for this feature. Update this documentation when its contract changes.
  void _openFeatureCenter() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const FeatureCenterScreen()));
  }

  /// Performs `_openEverything` for this feature. Update this documentation when its contract changes.
  void _openEverything() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const UltimateFeaturesScreen()));
  }

  /// Performs `_openRemoteAccess` for this feature. Update this documentation when its contract changes.
  void _openRemoteAccess() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const RemoteAccessScreen()));
  }

  /// Performs `_openAccountSettings` for this feature. Update this documentation when its contract changes.
  void _openAccountSettings() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountSettingsScreen()));
  }

  /// Performs `_openDevices` for this feature. Update this documentation when its contract changes.
  void _openDevices() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const DeviceCenterScreen()));
  }

  /// Performs `_openRoadmapFeatures` for this feature. Update this documentation when its contract changes.
  void _openRoadmapFeatures() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const RoadmapFeaturesScreen()));
  }

  /// Performs `_openNextGen` for this feature. Update this documentation when its contract changes.
  void _openNextGen() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const NextGenFeaturesScreen()));
  }

  /// Performs `_openPlatformExpansion` for this feature. Update this documentation when its contract changes.
  void _openPlatformExpansion() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PlatformExpansionScreen()),
    );
  }

  /// Performs `_openNotifications` for this feature. Update this documentation when its contract changes.
  void _openNotifications() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _ActivitySheet(),
    );
  }

  List<String> _normalizedNavigationOrder(List<String> value) {
    const defaults = <String>['Profile', 'Home', 'Live Sports', 'More', 'Music', 'Film'];
    final result = <String>[];
    for (final name in value) {
      if (defaults.contains(name) && !result.contains(name)) result.add(name);
    }
    for (final name in defaults) {
      if (!result.contains(name)) result.add(name);
    }
    return result;
  }

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    // Primary navigation is fixed to six destinations: Profile, Home, Live Sports,
    // More, Music and Film. Music and Film expose secondary destinations on hover/tap.
    final settings = HomeCustomizationStore.settingsFor(AppController.instance.currentProfile);
    final navigationOrder = _normalizedNavigationOrder(settings.navigationOrder);
    final pageByName = <String, Widget>{
      'Profile': const ProfileScreen(),
      'Home': HomeScreen(onRefresh: () => setState(() {}), onNotifications: _openNotifications),
      'Live Sports': const LiveSportsScreen(),
      'More': const _MoreNavigationPlaceholder(),
      'Music': const MusicScreen(),
      'Film': const MoviesScreen(),
    };
    final pages = navigationOrder.map((name) => pageByName[name]!).toList();
    final safeSelectedIndex = navigationOrder.indexOf(selectedDestination).clamp(0, pages.length - 1).toInt();
    final selectedName = navigationOrder[safeSelectedIndex];
    final navbar = _StreamingNavigationBar(
      position: settings.navbarPosition,
      onSelect: (index) {
        final name = navigationOrder[index];
        if (name == 'Profile') { _openProfiles(); return; }
        if (name == 'More') { _openMore(); return; }
        final destination = navigationOrder[index];
        if (destination != selectedDestination) {
          setState(() => selectedDestination = destination);
        }
      },
      onMore: _openMore,
      navigationOrder: navigationOrder,
      selectedName: selectedName,
      backgroundColor: colorFromName(settings.navbarColor),
      glowColor: colorFromName(settings.navbarGlowColor),
      itemColor: colorFromName(settings.navbarItemColor),
      style: settings.navbarStyle,
      opacity: settings.navbarOpacity,
      radius: settings.navbarRadius,
    );
    final page = AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      child: KeyedSubtree(key: ValueKey(selectedName), child: pages[safeSelectedIndex]),
    );

    Widget content;
    switch (settings.navbarPosition) {
      case 'Top':
        content = Column(children: [navbar, Expanded(child: page)]);
        break;
      case 'Left':
        content = Row(children: [navbar, Expanded(child: page)]);
        break;
      case 'Right':
        content = Row(children: [Expanded(child: page), navbar]);
        break;
      case 'Floating':
        content = Stack(children: [
          Positioned.fill(child: page),
          Positioned(left: 12, right: 12, bottom: 12, child: SafeArea(top: false, child: Center(child: navbar))),
        ]);
        break;
      case 'Bottom':
      default:
        content = Column(children: [Expanded(child: page), navbar]);
        break;
    }

    return Scaffold(backgroundColor: colorFromName(settings.homeBackgroundColor), body: content);
  }
}

class _StreamingNavigationBar extends StatelessWidget {
  final String position;
  final ValueChanged<int> onSelect;
  final VoidCallback onMore;
  final Color backgroundColor;
  final Color glowColor;
  final Color itemColor;
  final String style;
  final double opacity;
  final double radius;
  final List<String> navigationOrder;
  final String selectedName;

  const _StreamingNavigationBar({
    required this.position,
    required this.onSelect,
    required this.onMore,
    required this.backgroundColor,
    required this.glowColor,
    required this.itemColor,
    required this.style,
    required this.opacity,
    required this.radius,
    required this.navigationOrder,
    required this.selectedName,
  });

  void _open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final vertical = position == 'Left' || position == 'Right';
    final filmEntries = <_NavMenuEntry>[
      _NavMenuEntry('Movies', Icons.movie_outlined, () => _open(context, const MoviesScreen())),
      _NavMenuEntry('Series', Icons.tv_outlined, () => _open(context, const SeriesScreen())),
      _NavMenuEntry('Trailers', Icons.play_circle_outline, () => _open(context, const TrailersScreen())),
      _NavMenuEntry('Actors', Icons.people_outline, () => _open(context, const LibraryActorsScreen())),
      _NavMenuEntry('Collections', Icons.collections_bookmark_outlined, () => _open(context, const LibraryCollectionsScreen())),
      _NavMenuEntry('Directors', Icons.videocam_outlined, () => _open(context, const LibraryDirectorsScreen())),
      _NavMenuEntry('Franchises', Icons.account_tree_outlined, () => _open(context, const _NavigationDirectoryScreen(title: 'Franchises', icon: Icons.account_tree_outlined))),
      _NavMenuEntry('Genres', Icons.category_outlined, () => _open(context, const _NavigationDirectoryScreen(title: 'Genres', icon: Icons.category_outlined))),
      _NavMenuEntry('Wishlist', Icons.favorite_border_rounded, () => _open(context, const FavoritesScreen())),
      _NavMenuEntry('Search', Icons.search_rounded, () => _open(context, const SmartSearchScreen())),
    ];
    final musicEntries = <_NavMenuEntry>[
      _NavMenuEntry('Singers / Bands', Icons.person_outline_rounded, () => _open(context, const _NavigationDirectoryScreen(title: 'Singers / Bands', icon: Icons.person_outline_rounded))),
      _NavMenuEntry('Albums', Icons.album_outlined, () => _open(context, const _NavigationDirectoryScreen(title: 'Albums', icon: Icons.album_outlined))),
      _NavMenuEntry('Playlists', Icons.queue_music_rounded, () => _open(context, const MusicScreen())),
      _NavMenuEntry('Soundtrack Universe', Icons.library_music_outlined, () => _open(context, const SoundtrackUniverseScreen())),
    ];

    final dataByName = <String, _NavItemData>{
      'Profile': const _NavItemData(Icons.account_circle_outlined, Icons.account_circle_rounded, 'Profile'),
      'Home': const _NavItemData(Icons.home_outlined, Icons.home_rounded, 'Home'),
      'Live Sports': const _NavItemData(Icons.sports_soccer_outlined, Icons.sports_soccer_rounded, 'Live Sports'),
      'More': const _NavItemData(Icons.more_horiz_rounded, Icons.more_horiz_rounded, 'More'),
      'Music': const _NavItemData(Icons.music_note_outlined, Icons.music_note_rounded, 'Music'),
      'Film': const _NavItemData(Icons.movie_outlined, Icons.movie_rounded, 'Film'),
    };
    final actions = <Widget>[
      for (final name in navigationOrder)
        if (name == 'More')
          _NavButton(data: dataByName[name]!, selected: false, vertical: vertical, onTap: onMore, color: itemColor)
        else if (name == 'Music')
          _NavMenuButton(data: dataByName[name]!, selected: selectedName == name, vertical: vertical, color: itemColor, entries: musicEntries, onTap: () => onSelect(navigationOrder.indexOf(name)), menuSide: position == 'Right' ? AxisDirection.left : AxisDirection.right, menuVerticalDirection: (position == 'Bottom' || position == 'Floating') ? AxisDirection.up : AxisDirection.down)
        else if (name == 'Film')
          _NavMenuButton(data: dataByName[name]!, selected: selectedName == name, vertical: vertical, color: itemColor, entries: filmEntries, onTap: () => onSelect(navigationOrder.indexOf(name)), menuSide: position == 'Right' ? AxisDirection.left : AxisDirection.right, menuVerticalDirection: (position == 'Bottom' || position == 'Floating') ? AxisDirection.up : AxisDirection.down)
        else
          _NavButton(data: dataByName[name]!, selected: selectedName == name, vertical: vertical, onTap: () => onSelect(navigationOrder.indexOf(name)), color: itemColor),
    ];

    final alpha = style == 'Transparent' ? .08 : style == 'Curved' ? opacity : style == 'Angled' ? opacity : opacity;
    final effectiveColor = backgroundColor.withValues(alpha: alpha.clamp(.05, 1.0));
    final decoration = BoxDecoration(
      color: effectiveColor,
      border: Border.all(color: glowColor.withValues(alpha: .35), width: 1.2),
      borderRadius: BorderRadius.circular(style == 'Curved' ? radius.clamp(20, 44) : radius.clamp(0, 32)),
      boxShadow: [BoxShadow(blurRadius: style == 'Transparent' ? 12 : 28, offset: const Offset(0, -8), color: glowColor.withValues(alpha: .16))],
    );
    final inner = vertical
        ? SingleChildScrollView(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4), child: Column(mainAxisSize: MainAxisSize.min, children: actions))
        : SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), child: Row(mainAxisSize: MainAxisSize.min, children: actions));
    final child = style == 'Angled'
        ? ClipPath(clipper: _AngledNavbarClipper(), child: DecoratedBox(decoration: decoration, child: inner))
        : DecoratedBox(decoration: decoration, child: inner);
    return SafeArea(top: false, child: ConstrainedBox(
      constraints: vertical ? const BoxConstraints(minWidth: 104, maxWidth: 104, maxHeight: 620) : const BoxConstraints(minHeight: 76, maxHeight: 84),
      child: child,
    ));
  }
}

class _NavMenuEntry {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _NavMenuEntry(this.label, this.icon, this.onTap);
}

class _NavMenuButton extends StatefulWidget {
  final _NavItemData data;
  final bool selected;
  final bool vertical;
  final Color color;
  final List<_NavMenuEntry> entries;
  final VoidCallback onTap;
  final AxisDirection menuSide;
  final AxisDirection menuVerticalDirection;
  const _NavMenuButton({required this.data, required this.selected, required this.vertical, required this.color, required this.entries, required this.onTap, required this.menuSide, required this.menuVerticalDirection});
  @override State<_NavMenuButton> createState() => _NavMenuButtonState();
}

class _NavMenuButtonState extends State<_NavMenuButton> {
  OverlayEntry? _overlay;
  Timer? _hideTimer;

  void _cancelHide() => _hideTimer?.cancel();
  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 260), _hideMenu);
  }
  void _hideMenu() { _overlay?.remove(); _overlay = null; }

  void _showMenu() {
    _cancelHide();
    if (_overlay != null) return;
    final box = context.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;
    final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
    final size = box.size;
    const menuWidth = 220.0;
    final left = widget.vertical
        ? (widget.menuSide == AxisDirection.left
            ? origin.dx - menuWidth - 8
            : origin.dx + size.width + 8)
        : origin.dx;

    Widget menu() => MouseRegion(
          onEnter: (_) => _cancelHide(),
          onExit: (_) => _scheduleHide(),
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: menuWidth,
              constraints: const BoxConstraints(maxHeight: 520),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xF51A1A1A),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white12),
                boxShadow: const [
                  BoxShadow(blurRadius: 28, color: Color(0x55000000)),
                ],
              ),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final entry in widget.entries)
                    ListTile(
                      dense: true,
                      leading: Icon(entry.icon, size: 20),
                      title: Text(entry.label),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onTap: () {
                        _hideMenu();
                        entry.onTap();
                      },
                    ),
                ],
              ),
            ),
          ),
        );

    _overlay = OverlayEntry(
      builder: (_) {
        if (widget.vertical) {
          return Positioned(left: left, top: origin.dy, child: menu());
        }
        if (widget.menuVerticalDirection == AxisDirection.up) {
          return Positioned(
            left: left,
            bottom: overlay.size.height - origin.dy + 8,
            child: menu(),
          );
        }
        return Positioned(
          left: left,
          top: origin.dy + size.height + 8,
          child: menu(),
        );
      },
    );
    Overlay.of(context).insert(_overlay!);
  }

  @override
  void dispose() { _hideTimer?.cancel(); _hideMenu(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final active = widget.selected;
    final width = widget.vertical ? 94.0 : (active ? 92.0 : 76.0);
    return Padding(
      padding: widget.vertical ? const EdgeInsets.symmetric(vertical: 2) : const EdgeInsets.symmetric(horizontal: 2),
      child: MouseRegion(
        onEnter: (_) => _showMenu(), onExit: (_) => _scheduleHide(),
        child: Material(color: active ? Colors.white.withValues(alpha: .10) : Colors.transparent, borderRadius: BorderRadius.circular(18), child: InkWell(
          borderRadius: BorderRadius.circular(18), onTap: widget.onTap,
          child: SizedBox(width: width, height: 60, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(active ? widget.data.selectedIcon : widget.data.icon, size: 22, color: active ? widget.color : widget.color.withValues(alpha: .72)),
            const SizedBox(height: 3), Text(widget.data.label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(color: active ? Colors.white : Colors.white54, fontSize: 9.5, fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
            const SizedBox(height: 2), Container(width: active ? 18 : 0, height: 2, decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(10))),
          ])),
        )),
      ),
    );
  }
}

class _AngledNavbarClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()..moveTo(18, 0)..lineTo(size.width - 18, 0)..lineTo(size.width, 14)..lineTo(size.width, size.height - 14)..lineTo(size.width - 18, size.height)..lineTo(18, size.height)..lineTo(0, size.height - 14)..lineTo(0, 14)..close();
  @override bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _MoreNavigationPlaceholder extends StatelessWidget {
  const _MoreNavigationPlaceholder();
  @override Widget build(BuildContext context) => const SizedBox.shrink();
}

class _NavigationDirectoryScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  const _NavigationDirectoryScreen({required this.title, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070707),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Text(title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 58, color: Colors.white54),
              const SizedBox(height: 14),
              Text(
                '$title will appear here as your library metadata grows.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const _NavItemData(this.icon, this.selectedIcon, this.label);
}

class _NavButton extends StatefulWidget {
  final _NavItemData data;
  final bool selected;
  final bool vertical;
  final VoidCallback onTap;
  final Color color;
  const _NavButton({required this.data, required this.selected, required this.onTap, this.vertical = false, this.color = Colors.white});
  @override State<_NavButton> createState() => _NavButtonState();
}
class _NavButtonState extends State<_NavButton> {
  bool pressed = false;
  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    final active = widget.selected;
    final width = widget.vertical ? 78.0 : (active ? 92.0 : 68.0);
    return Padding(
      padding: widget.vertical ? const EdgeInsets.symmetric(vertical: 2) : const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: active ? Colors.white.withValues(alpha: .10) : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTapDown: (_) => setState(() => pressed = true),
          onTapCancel: () => setState(() => pressed = false),
          onTap: () { setState(() => pressed = false); widget.onTap(); },
          child: AnimatedScale(
            scale: pressed ? .94 : 1,
            duration: const Duration(milliseconds: 100),
            child: SizedBox(
              width: width,
              height: 60,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Stack(clipBehavior: Clip.none, children: [
                  Icon(active ? widget.data.selectedIcon : widget.data.icon, size: 22, color: active ? widget.color : widget.color.withValues(alpha: .72)),
                ]),
                const SizedBox(height: 3),
                Text(widget.data.label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(color: active ? Colors.white : Colors.white54, fontSize: 9.5, fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
                const SizedBox(height: 2),
                Container(width: active ? 18 : 0, height: 2, decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(10))),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _MoreActionsSheet extends StatelessWidget {
  final VoidCallback onImport;
  final VoidCallback onProfiles;
  final VoidCallback onWishlist;
  final VoidCallback onCustomize;
  final VoidCallback onFeatureCenter;
  final VoidCallback onEverything;
  final VoidCallback onRemoteAccess;
  final VoidCallback onAccountSettings;
  final VoidCallback onDevices;
  final VoidCallback onRoadmapFeatures;
  final VoidCallback onNextGen;
  final VoidCallback onPlatformExpansion;
  final VoidCallback onNotifications;

  const _MoreActionsSheet({
    required this.onImport,
    required this.onProfiles,
    required this.onWishlist,
    required this.onCustomize,
    required this.onFeatureCenter,
    required this.onEverything,
    required this.onRemoteAccess,
    required this.onAccountSettings,
    required this.onDevices,
    required this.onRoadmapFeatures,
    required this.onNextGen,
    required this.onPlatformExpansion,
    required this.onNotifications,
  });

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return _PremiumSheet(
      title: 'More',
      subtitle: 'Manage your streaming service',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetAction(
            icon: Icons.library_add_outlined,
            title: 'Rip / Import Disc',
            subtitle: 'DVD, Blu-ray, UHD and approved media import',
            onTap: onImport,
          ),
          _SheetAction(
            icon: Icons.manage_accounts_outlined,
            title: 'Manage Profiles',
            subtitle: 'Switch, create, or remove profiles',
            onTap: onProfiles,
          ),
          _SheetAction(
            icon: Icons.favorite_outline_rounded,
            title: 'Group Wishlist',
            subtitle: 'See shared movies and shows',
            onTap: onWishlist,
          ),
          _SheetAction(
            icon: Icons.tune_rounded,
            title: 'Customize App',
            subtitle: 'Customize Home and Details',
            onTap: onCustomize,
          ),
          _SheetAction(
            icon: Icons.auto_awesome_rounded,
            title: 'Discover & Recaps',
            subtitle:
                'Recommendations, collections, achievements and recaps',
            onTap: onFeatureCenter,
          ),
          _SheetAction(
            icon: Icons.apps_rounded,
            title: 'Everything',
            subtitle: 'Security, AI, stats, travel, backup and more',
            onTap: onEverything,
          ),
          _SheetAction(
            icon: Icons.devices_other_rounded,
            title: 'Remote Access',
            subtitle: 'Manage trusted remote computers and imports',
            onTap: onRemoteAccess,
          ),
          _SheetAction(
            icon: Icons.settings_rounded,
            title: 'Account Settings',
            subtitle: 'Storage, subscription and account controls',
            onTap: onAccountSettings,
          ),
          _SheetAction(
            icon: Icons.devices_rounded,
            title: 'Device Center',
            subtitle:
                'Downloads, casting, HDMI and Bluetooth guidance',
            onTap: onDevices,
          ),
          _SheetAction(
            icon: Icons.auto_awesome_rounded,
            title: 'Next-Gen Features',
            subtitle:
                'Smart discovery, My Stuff, stats, downloads, privacy and advanced settings',
            onTap: onNextGen,
          ),
          _SheetAction(
            icon: Icons.tune_rounded,
            title: 'Platform Expansion',
            subtitle:
                'Security, playback, TV, backup, discovery, sports, privacy and kids controls',
            onTap: onPlatformExpansion,
          ),
          _SheetAction(
            icon: Icons.notifications_active_outlined,
            title: 'Notifications',
            subtitle: 'Recent profile activity and messages',
            onTap: onNotifications,
          ),
          _SheetAction(
            icon: Icons.favorite_rounded,
            title: 'Favorites',
            subtitle:
                'Liked movies, shows, songs, albums and playlists',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const FavoritesScreen(),
              ),
            ),
          ),
          _SheetAction(
            icon: Icons.workspace_premium_rounded,
            title: 'Ultimate Platform',
            subtitle:
                'AI, premium player, family, social, cloud, security, devices and Studio',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const UltimatePlatformScreen(),
              ),
            ),
          ),
          _SheetAction(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy & Ownership',
            subtitle:
                'Private library, authorized media, storage and account deletion',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const LibraryPrivacyScreen(),
              ),
            ),
          ),
          _SheetAction(
            icon: Icons.storage_rounded,
            title: 'Server Storage',
            subtitle:
                'Movies, Series, Music and available capacity',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const StorageDashboardScreen(),
              ),
            ),
          ),
          _SheetAction(
            icon: Icons.dns_rounded,
            title: 'Home Server & ARM',
            subtitle:
                'Server health, ARM connection and media import pipeline',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const HomeServerScreen(),
              ),
            ),
          ),
          _SheetAction(
  icon: Icons.emoji_events_outlined,
  title: 'Music Achievements',
  subtitle: 'Music badges such as Cultured and Swiftie',
  onTap: () => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => const FeatureCenterScreen(),
    ),
  ),
),
          _SheetAction(
            icon: Icons.rocket_launch_rounded,
            title: '100-Feature Roadmap',
            subtitle: 'Open every implemented roadmap feature',
            onTap: onRoadmapFeatures,
          ),
        ],
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SheetAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white.withValues(alpha: .045),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white38),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * .82;

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
                Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
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

class _ActivitySheet extends StatelessWidget {
  const _ActivitySheet();

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    final activity = AppController.instance.activity;
    return _PremiumSheet(
      title: 'Notifications',
      subtitle: activity.isEmpty ? 'You are all caught up' : 'Recent activity',
      child: SizedBox(
        height: MediaQuery.of(context).size.height * .55,
        child: activity.isEmpty
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_none_rounded, size: 54, color: Colors.white38),
                    SizedBox(height: 12),
                    Text('No activity yet.', style: TextStyle(color: Colors.white60)),
                  ],
                ),
              )
            : ListView.separated(
                itemCount: activity.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, index) {
                  final event = activity[index];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .045),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CircleAvatar(
                          radius: 20,
                          backgroundColor: Color(0x22FF0000),
                          child: Icon(Icons.notifications_none_rounded, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(event.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text(event.action, style: const TextStyle(color: Colors.white60)),
                              const SizedBox(height: 5),
                              Text(
                                event.timestamp.toString(),
                                style: const TextStyle(color: Colors.white38, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
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

  const HomeScreen({super.key, this.onRefresh, this.onNotifications});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _heroController;

  @override
  /// Performs `initState` for this feature. Update this documentation when its contract changes.
  void initState() {
    super.initState();
    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  /// Performs `dispose` for this feature. Update this documentation when its contract changes.
  void dispose() {
    _heroController.dispose();
    super.dispose();
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
        body: Center(child: Text('No profile selected.')),
      );
    }

    final library = controller.library;
    final settings = HomeCustomizationStore.settingsFor(AppController.instance.currentProfile);
    final homeBackground = colorFromName(settings.homeBackgroundColor);

    // Deliberately keep the empty home completely clean. All management
    // actions live in the navigation bar's More menu.
    if (library.isEmpty) {
      return Scaffold(
        backgroundColor: homeBackground,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          title: const Text('Home', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.1)),
          actions: [
            ActivityButton(onPressed: widget.onNotifications),
            const SizedBox(width: 8),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Your library is empty',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please add using the 3 dots in the navbar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final watched = controller.watched;
    final movies = library
        .where((media) => media.type.toLowerCase() == 'movie')
        .toList();
    final tvShows = library.where((media) {
      final type = media.type.toLowerCase();
      return type == 'tvshow' || type == 'tv_show' || type == 'tv show';
    }).toList();
    final heroMedia = watched.isNotEmpty ? watched.first : library.first;

    return Scaffold(
      backgroundColor: homeBackground,
      body: HomePositionedLayout(
        navbarPosition: settings.navbarPosition,
        storagePosition: settings.storageBarPosition,
        liveSportsPosition: settings.liveSportsPosition,
        storageThickness: settings.storageBarThickness,
        showLiveSports: settings.showLiveSports,
        child: RefreshIndicator(
          color: Colors.white,
          backgroundColor: const Color(0xFF171717),
          onRefresh: _refresh,
          child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              floating: true,
              elevation: 0,
              backgroundColor: const Color(0xE6070707),
              surfaceTintColor: Colors.transparent,
              titleSpacing: 20,
              title: const Text(
                'Home',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: 1.1),
              ),
              actions: [
                ActivityButton(onPressed: widget.onNotifications),
                const SizedBox(width: 8),
              ],
            ),
            if (settings.showHero)
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: CurvedAnimation(parent: _heroController, curve: Curves.easeOut),
                  child: _HomeHero(
                    media: heroMedia,
                    profileName: profile.name,
                    onPlay: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MediaDetailsScreen(media: heroMedia))),
                  ),
                ),
              ),
            for (final section in settings.sectionOrder)
              ..._buildHomeSectionSlivers(section, settings, watched, movies, tvShows, library, controller.recommendations),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
          ),
        ),
      ),
    );
  }
}

List<Widget> _buildHomeSectionSlivers(
  String section,
  HomeCustomization settings,
  List<MediaItem> watched,
  List<MediaItem> movies,
  List<MediaItem> tvShows,
  List<MediaItem> library,
  List<MediaItem> recommendations,
) {
  List<MediaItem> items;
  String subtitle;
  bool enabled;
  switch (section) {
    case 'Continue Watching': items = watched; subtitle = 'Pick up where you left off'; enabled = settings.showContinueWatching; break;
    case 'Recently Watched': items = watched; subtitle = 'What you watched recently'; enabled = settings.showRecentlyWatched; break;
    case 'Movies': items = movies; subtitle = 'From your collection'; enabled = settings.showMovies; break;
    case 'TV Shows': items = tvShows; subtitle = 'Your series collection'; enabled = settings.showTvShows; break;
    case 'New Additions':
      items = List<MediaItem>.from(library)..sort((a,b) => b.addedAt.compareTo(a.addedAt));
      subtitle = 'Recently added to your library'; enabled = settings.showNewAdditions; break;
    case 'All Library': items = library; subtitle = 'Everything in your library'; enabled = settings.showAllLibrary; break;
    case 'Recommendations': items = recommendations; subtitle = 'Picked for your profile'; enabled = settings.showRecommendations; break;
    case 'Music & Film':
      return [if (settings.showMusic || settings.showFilm) SliverToBoxAdapter(child: _HomeMusicFilmChooser(settings: settings))];
    case 'Live Sports': return const [];
    default: return const [];
  }
  if (!enabled || items.isEmpty) return const [];
  return [
    SliverToBoxAdapter(child: _PremiumSectionHeader(title: section, subtitle: subtitle)),
    SliverToBoxAdapter(child: MediaHorizontalList(media: items)),
  ];
}

class _HomeMusicFilmChooser extends StatelessWidget {
  final HomeCustomization settings;
  const _HomeMusicFilmChooser({required this.settings});

  Widget _panel(BuildContext context, {required String title, required String subtitle, required IconData icon, required List<Widget> actions}) {
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .045),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: .07)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, size: 22), const SizedBox(width: 8), Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)))]),
          const SizedBox(height: 5),
          Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 12),
          ...actions,
        ]),
    );
  }

  Widget _action(BuildContext context, String label, IconData icon, Widget page) => SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)), icon: Icon(icon, size: 17), label: Text(label)));

  @override
  Widget build(BuildContext context) {
    final panels = <Widget>[];
    if (settings.showMusic) {
      panels.add(_panel(context, title: 'Music', subtitle: 'Songs, albums and playlists', icon: Icons.music_note_rounded, actions: [
        _action(context, 'Open Music', Icons.play_circle_outline_rounded, const MusicScreen()),
      ]));
    }
    if (settings.showFilm) {
      panels.add(_panel(context, title: 'Film', subtitle: 'Movies or shows', icon: Icons.movie_creation_outlined, actions: [
        Row(children: [Expanded(child: _action(context, 'Movies', Icons.movie_outlined, const MoviesScreen())), const SizedBox(width: 8), Expanded(child: _action(context, 'Shows', Icons.tv_rounded, const SeriesScreen()))]),
      ]));
    }
    if (panels.isEmpty) return const SizedBox.shrink();
    final body = settings.homeMediaLayout == 'Top & Bottom'
        ? Column(children: [for (var i = 0; i < panels.length; i++) ...[panels[i], if (i != panels.length - 1) const SizedBox(height: 12)]])
        : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [for (var i = 0; i < panels.length; i++) ...[Expanded(child: panels[i]), if (i != panels.length - 1) const SizedBox(width: 12)]]);
    return Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: body);
  }
}

class _HomeHero extends StatelessWidget {
  final MediaItem media;
  final String profileName;
  final VoidCallback onPlay;

  const _HomeHero({
    required this.media,
    required this.profileName,
    required this.onPlay,
  });

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Container(
      height: 430,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: const Color(0xFF151515),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (media.imageUrl != null)
            Image.network(
              media.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: .08),
                  Colors.black.withValues(alpha: .26),
                  Colors.black.withValues(alpha: .95),
                ],
                stops: const [0, .42, 1],
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  media.type.toUpperCase(),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.4, color: Colors.white70),
                ),
                const SizedBox(height: 9),
                Text(
                  media.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 31, height: 1.05, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 7),
                Text('Welcome back, $profileName', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 17),
                FilledButton.icon(
                  onPressed: onPlay,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Open', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _PremiumSectionHeader({required this.title, required this.subtitle});

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }
}

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
        tooltip: 'Notifications',
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.notifications_outlined),
            if (controller.activity.isNotEmpty)
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
        onPressed: onPressed ?? () {
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

  const MediaHorizontalList({
    super.key,
    required this.media,
  });

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return SizedBox(
      height: 245,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: media.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: 12),
        itemBuilder: (_, index) {
          return MediaCard(
            media: media[index],
          );
        },
      ),
    );
  }
}

// ============================================================
// MEDIA CARD
// ============================================================

class MediaCard extends StatelessWidget {
  final MediaItem media;

  const MediaCard({
    super.key,
    required this.media,
  });

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return SizedBox(
      width: 145,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MediaDetailsScreen(
                media: media,
              ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    BorderRadius.circular(10),
                child: media.imageUrl == null
                    ? Container(
                        width: double.infinity,
                        color: Colors.grey.shade900,
                        child: const Icon(
                          Icons.movie,
                          size: 45,
                        ),
                      )
                    : Image.network(
                        media.imageUrl!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, __, ___) {
                          return Container(
                            color:
                                Colors.grey.shade900,
                            child: const Icon(
                              Icons.broken_image,
                            ),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              media.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (media.releaseYear != null)
              Text(
                media.releaseYear.toString(),
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
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
        title: const Text('Actors'),
      ),
      body: const Center(
        child: Text(
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

class _ImportMediaScreenState extends State<ImportMediaScreen> {
  final titleController = TextEditingController();
  final yearController = TextEditingController();
  final posterController = TextEditingController();
  final trailerController = TextEditingController();
  final descriptionController = TextEditingController();

  static const discTypes = <String>[
    'DVD',
    'Blu-ray',
    '4K Ultra HD',
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
    super.dispose();
  }

  /// Performs `_startArmImport` for this feature. Update this documentation when its contract changes.
  Future<void> _startArmImport() async {
    if (importing) return;

    setState(() {
      importing = true;
      progress = 0;
      verificationPassed = false;
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
      final drive = drives.whereType<Map>().cast<Map<String, dynamic>>().firstWhere(
            (item) => item['available'] != false,
            orElse: () => <String, dynamic>{
              'id': 'arm-auto',
              'name': 'ARM automatic drive monitor',
            },
          );

      driveId = drive['id']?.toString() ?? 'arm-auto';

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
      if (status == 'readyForReview') {
        _pollTimer?.cancel();
        _prepareReview(map);
      } else if (status == 'rejected' || status == 'failed') {
        _pollTimer?.cancel();
        setState(() {
          importing = false;
          verificationPassed = false;
          verification = map['verification'] is Map
              ? Map<String, dynamic>.from(map['verification'])
              : null;
          statusMessage = map['message']?.toString() ??
              'Disc rejected by the integrity checks.';
        });
      }
    } catch (_) {
      // Keep polling: ARM jobs can temporarily disappear while ARM refreshes
      // its database/UI state.
    }
  }

  /// Performs `_prepareReview` for this feature. Update this documentation when its contract changes.
  void _prepareReview(Map<String, dynamic> job) {
    final verificationData = job['verification'];
    final discType = job['discType']?.toString();
    final region = job['region']?.toString();

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

    if (titles.isEmpty && (job['title']?.toString().trim().isNotEmpty ?? false)) {
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
      verificationPassed = verification?['passed'] == true;
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
      selectedRegion =
          regions.contains(region) ? region! : selectedRegion;
      statusMessage = verificationPassed
          ? titles.length > 1
              ? 'Disc verified. ARM detected ${titles.length} separate titles on this disc. Review them before adding them to your library.'
              : 'Disc verified. Review the metadata, then click ADD TO LIBRARY.'
          : 'Disc rejected. It cannot be added to your library.';
    });
  }

  /// Performs `_normalizeMediaType` for this feature. Update this documentation when its contract changes.
  String _normalizeMediaType(String? value) {
    final v = (value ?? '').toLowerCase();
    if (v.contains('tv') || v.contains('series') || v.contains('show')) {
      return 'tvShow';
    }
    return 'movie';
  }

  /// Performs `_isImportableDiscTitle` for this feature. Update this documentation when its contract changes.
  bool _isImportableDiscTitle(Map<String, dynamic> title) {
    final type = (title['mediaType']?.toString() ?? 'movie').toLowerCase();
    final classification = (title['classification']?.toString() ?? 'feature').toLowerCase();
    final movieLike = type.contains('movie') ||
        type.contains('film') ||
        type.contains('tv') ||
        type.contains('show') ||
        type.contains('series');
    final featureLike = classification.isEmpty ||
        classification == 'feature' ||
        classification == 'feature_film' ||
        classification == 'main_feature';
    return movieLike && featureLike;
  }

  /// Performs `_strings` for this feature. Update this documentation when its contract changes.
  List<String> _strings(dynamic value) {
    if (value is! List) return <String>[];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  /// Performs `_addVerifiedDiscToLibrary` for this feature. Update this documentation when its contract changes.
  Future<void> _addVerifiedDiscToLibrary() async {
    if (!verificationPassed || reviewJob == null) return;
    if (!ownershipConfirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please confirm that you own or are legally authorized to use this media.')),
      );
      return;
    }
    try {
      await AppController.instance.backendApi.confirmOwnershipDeclaration();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
      return;
    }

    if (!mounted) return;
    final job = reviewJob!;
    final selectedTitles = detectedDiscTitles
        .where((title) => selectedDiscTitleIds.contains(title['id']?.toString()))
        .toList();

    if (selectedTitles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one title from the disc before adding it.')),
      );
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

    for (final titleData in selectedTitles) {
      final title = (titleData['canonicalTitle']?.toString().trim().isNotEmpty == true ? titleData['canonicalTitle']?.toString().trim() : titleData['title']?.toString().trim()) ?? '';
      final discTitle = titleData['discTitle']?.toString() ?? titleData['title']?.toString();
      if (title.isEmpty) continue;

      final metadata = titleData['metadata'] is Map
          ? Map<String, dynamic>.from(titleData['metadata'] as Map)
          : <String, dynamic>{};
      final year = titleData['year'] is num
          ? (titleData['year'] as num).toInt()
          : int.tryParse(titleData['year']?.toString() ?? '') ??
              (metadata['year'] is num
                  ? (metadata['year'] as num).toInt()
                  : int.tryParse(metadata['year']?.toString() ?? '') ??
                      (job['year'] is num
                          ? (job['year'] as num).toInt()
                          : int.tryParse(job['year']?.toString() ?? '')));
      final media = MediaItem(
        id: 'arm_${DateTime.now().microsecondsSinceEpoch}_${titleData['id']}',
        title: title,
        type: _normalizeMediaType(titleData['mediaType']?.toString() ?? job['mediaType']?.toString()),
        imageUrl: poster.isEmpty
            ? (titleData['posterUrl']?.toString() ?? metadata['posterUrl']?.toString() ?? job['posterUrl']?.toString())
            : poster,
        description: descriptionController.text.trim().isEmpty
            ? titleData['description']?.toString() ?? metadata['description']?.toString() ?? job['description']?.toString() ?? DescriptionGenerator.movie(title: title, year: year)
            : descriptionController.text.trim(),
        releaseYear: year,
        trailerUrl: trailer.isEmpty
            ? (titleData['trailerUrl']?.toString() ?? metadata['trailerUrl']?.toString() ?? job['trailerUrl']?.toString())
            : trailer,
        discType: selectedDiscType,
        discRegion: titleData['detectedRegion']?.toString() ?? job['region']?.toString() ?? selectedRegion,
        discTitle: discTitle,
        discMarketCountry: titleData['discMarketCountry']?.toString() ?? job['discMarketCountry']?.toString(),
        originalTitle: titleData['originalTitle']?.toString() ?? titleData['canonicalTitle']?.toString(),
        originalLanguage: titleData['originalLanguage']?.toString(),
        countryOfOrigin: titleData['countryOfOrigin']?.toString(),
        canonicalTitle: titleData['canonicalTitle']?.toString() ?? title,

        discCollectionId: collectionId,
        discCollectionTitle: collectionTitle,
        discNumber: discNumber,
        discTitleId: titleData['id']?.toString(),
        actors: _strings(titleData['actors']).isNotEmpty ? _strings(titleData['actors']) : (metadata['actors'] is List ? _strings(metadata['actors']) : _strings(job['actors'])),
        directors: _strings(titleData['directors']).isNotEmpty ? _strings(titleData['directors']) : (metadata['directors'] is List ? _strings(metadata['directors']) : _strings(job['directors'])),
        writers: _strings(titleData['writers']).isNotEmpty ? _strings(titleData['writers']) : (metadata['writers'] is List ? _strings(metadata['writers']) : _strings(job['writers'])),
        music: _strings(titleData['music']).isNotEmpty ? _strings(titleData['music']) : (metadata['music'] is List ? _strings(metadata['music']) : _strings(job['music'])),
        genres: _strings(titleData['genres']).isNotEmpty ? _strings(titleData['genres']) : (metadata['genres'] is List ? _strings(metadata['genres']) : _strings(job['genres'])),
        tags: _strings(titleData['tags']).isNotEmpty ? _strings(titleData['tags']) : (metadata['tags'] is List ? _strings(metadata['tags']) : _strings(job['tags'])),
        chapters: _strings(titleData['chapters']).isNotEmpty ? _strings(titleData['chapters']) : (metadata['chapters'] is List ? _strings(metadata['chapters']) : _strings(job['chapters'])),
        audioTracks: _strings(titleData['audioTracks']).isNotEmpty ? _strings(titleData['audioTracks']) : (metadata['audioTracks'] is List ? _strings(metadata['audioTracks']) : _strings(job['audioTracks'])),
        subtitles: _strings(titleData['subtitles']).isNotEmpty ? _strings(titleData['subtitles']) : (metadata['subtitles'] is List ? _strings(metadata['subtitles']) : _strings(job['subtitles'])),
        extras: _strings(titleData['extras']).isNotEmpty ? _strings(titleData['extras']) : (metadata['extras'] is List ? _strings(metadata['extras']) : _strings(job['extras'])),
      );

      AppController.instance.addToLibrary(media);
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
        title: const Text('Add Movie or Show'),
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
                  const Text(
                    'ARM AUTOMATIC DISC IMPORT',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'ARM stays enabled. Insert a DVD, Blu-ray, or 4K Ultra HD disc and ARM will detect it and perform the extraction automatically.',
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('ARM'),
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
                    Text(
                      '${(progress * 100).round()}% • $statusMessage',
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: importing ? null : _startArmImport,
                      icon: const Icon(Icons.play_circle_fill),
                      label: const Text('DETECT DISC / START ARM MONITOR'),
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
                    const Text(
                      'MULTI-TITLE DISC DETECTED',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'ARM found ${detectedDiscTitles.length} separate title candidates on this physical disc. Each selected movie will become its own library item while remaining linked to the same disc.',
                      style: const TextStyle(color: Colors.white70, height: 1.35),
                    ),
                    const SizedBox(height: 10),
                    ...detectedDiscTitles.map((title) {
                      final id = title['id']?.toString() ?? '';
                      final selected = selectedDiscTitleIds.contains(id);
                      final confidence = title['confidence'];
                      final confidenceText = confidence is num && confidence > 0
                          ? ' • ${(confidence.toDouble() <= 1 ? confidence.toDouble() * 100 : confidence.toDouble()).round()}% match'
                          : '';
                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: selected,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              selectedDiscTitleIds.add(id);
                            } else {
                              selectedDiscTitleIds.remove(id);
                            }
                          });
                        },
                        title: Text(title['canonicalTitle']?.toString() ?? title['title']?.toString() ?? 'Unknown title'),
                        subtitle: Text(
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
                      Text(
                        'Ripped runtime: ${_formatSeconds(verification!['durationSeconds'])}',
                      ),
                    if (verification?['chapterCount'] != null)
                      Text(
                        'Chapters detected: ${verification!['chapterCount']}',
                      ),
                    const SizedBox(height: 8),
                    ..._strings(verification?['failures']).map(
                      (failure) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
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
            const Text(
              'IMPORT REVIEW',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selectedType,
              decoration: const InputDecoration(
                labelText: 'Media Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'movie', child: Text('Movie')),
                DropdownMenuItem(value: 'tvShow', child: Text('TV Show')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => selectedType = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: yearController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Year',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selectedDiscType,
              decoration: const InputDecoration(
                labelText: 'Disc Type',
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
              decoration: const InputDecoration(
                labelText: 'Region',
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
              decoration: const InputDecoration(
                labelText: 'Poster URL (optional fallback)',
                hintText: 'Use this if the disc/metadata provider has no poster.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: trailerController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Trailer URL (optional fallback)',
                hintText: 'Use this if the disc/metadata provider has no trailer.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),
            Material(
              color: Colors.transparent,
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: ownershipConfirmed,
                onChanged: (value) => setState(() => ownershipConfirmed = value ?? false),
                title: const Text('I own or am legally authorized to use this media.'),
                subtitle: const Text('My Streaming Service provides storage and streaming infrastructure; applicable local law determines what copying and remote streaming are permitted.'),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .04),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'When you add this verified disc, its actors, directors, writers, music, genres, tags, chapters, audio tracks, subtitles, and extras will be cataloged with the media.',
                style: TextStyle(color: Colors.grey.shade300),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 54,
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _addVerifiedDiscToLibrary,
                icon: const Icon(Icons.library_add),
                label: const Text('ADD TO LIBRARY'),
              ),
            ),
          ],

          const SizedBox(height: 30),
          Text(
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
    final trailers = AppController.instance.library.where((m) => m.trailerUrl?.trim().isNotEmpty == true).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Trailers')),
      body: trailers.isEmpty
          ? const Center(child: Text('No trailers have been added to your library yet. ARM review can add a YouTube link when a disc does not contain a trailer.'))
          : ListView.builder(
              padding: const EdgeInsets.all(18),
              itemCount: trailers.length,
              itemBuilder: (_, index) {
                final media = trailers[index];
                return Card(child: ListTile(leading: const Icon(Icons.play_circle_fill_rounded), title: Text(media.title, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(media.type), trailing: const Icon(Icons.open_in_new_rounded), onTap: () async { final uri = Uri.tryParse(media.trailerUrl!); if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication); }));
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

class _ProfileScreenState extends State<ProfileScreen> {
  final controller = AppController.instance;

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    final account = controller.currentAccount;

    if (account == null) {
      return const Scaffold(body: Center(child: Text('No account is logged in.')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF070707),
      appBar: AppBar(
        title: const Text('Profiles', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        children: [
          const Text('Who is watching?', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('${account.profiles.length}/7 profiles', style: const TextStyle(color: Colors.white54)),
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
                label: const Text('CREATE PROFILE'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
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
                      Text(account.subscription.plan.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(account.subscription.status.name, style: const TextStyle(color: Colors.white54)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => showDialog(context: context, builder: (_) => const SubscribeDialog()),
                  child: const Text('Manage'),
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
            label: const Text('LOG OUT'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: BorderSide(color: Colors.red.withValues(alpha: .35)),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }
}

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
      color: current ? Colors.white.withValues(alpha: .09) : Colors.white.withValues(alpha: .045),
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
                    Text(profile.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(current ? 'Current profile' : 'Tap to switch', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'switch') onSwitch();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'switch', child: Text('Switch')), 
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MainProfileAvatar extends StatelessWidget {
  final Profile profile;
  final double size;

  const _MainProfileAvatar({required this.profile, required this.size});

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    final avatar = profile.avatarUrl;
    if (avatar != null && avatar.startsWith('avatar:')) {
      final index = int.tryParse(avatar.substring(6)) ?? 0;
      const icons = [
        Icons.person_rounded,
        Icons.face_rounded,
        Icons.pets_rounded,
        Icons.smart_toy_rounded,
        Icons.rocket_launch_rounded,
        Icons.auto_awesome_rounded,
      ];
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: .08),
        ),
        child: Icon(icons[index % icons.length], size: size * .48, color: Colors.white70),
      );
    }
    if (avatar != null && (avatar.startsWith('http://') || avatar.startsWith('https://'))) {
      return CircleAvatar(radius: size / 2, backgroundImage: NetworkImage(avatar));
    }
    if (avatar != null && avatar.isNotEmpty) {
      return CircleAvatar(radius: size / 2, backgroundImage: FileImage(File(avatar)));
    }
    return CircleAvatar(radius: size / 2, child: Text(profile.name.isEmpty ? '?' : profile.name[0].toUpperCase()));
  }
}

class AddProfileDialog extends StatefulWidget {
  const AddProfileDialog({super.key});

  @override
  State<AddProfileDialog> createState() => _AddProfileDialogState();
}

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
      title: const Text('Create Profile'),
      content: TextField(
        controller: nameController,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Profile name',
          prefixIcon: Icon(Icons.person_outline_rounded),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
        FilledButton(
          onPressed: () {
            final name = nameController.text.trim();
            if (name.isEmpty) return;
            AppController.instance.addProfile(name);
            Navigator.pop(context);
          },
          child: const Text('CREATE'),
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
    final controller =
        AppController.instance;

    return AlertDialog(
      title: const Text(
        'Subscription',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Choose your subscription.',
          ),
          const SizedBox(height: 20),
          ListTile(
            title: const Text(
              '\$9.99 USD / month',
            ),
            subtitle: const Text(
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
            title: const Text(
              '\$99.99 USD / year',
            ),
            subtitle: const Text(
              'Save \$19.89 compared with 12 monthly payments',
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

// ============================================================
// GROUP HUB
// ============================================================

class GroupHubScreen extends StatefulWidget {
  const GroupHubScreen({super.key});

  @override
  State<GroupHubScreen> createState() => _GroupHubScreenState();
}

class _GroupHubScreenState extends State<GroupHubScreen> {
  final messageController = TextEditingController();
  bool loading = false;

  @override
  /// Performs `initState` for this feature. Update this documentation when its contract changes.
  void initState() {
    super.initState();
    loadGroupData();
  }

  @override
  /// Performs `dispose` for this feature. Update this documentation when its contract changes.
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  /// Performs `loadGroupData` for this feature. Update this documentation when its contract changes.
  Future<void> loadGroupData() async {
    final controller = AppController.instance;
    if (!controller.backendApi.isAuthenticated) return;
    if (mounted) setState(() => loading = true);
    try {
      await Future.wait([
        controller.loadGroupWishlist(),
        controller.loadGroupRecommendations(),
      ]);
    } catch (error) {
      if (mounted) _showMessage('Unable to load group data: $error');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  /// Performs `_showMessage` for this feature. Update this documentation when its contract changes.
  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Performs `sendMessage` for this feature. Update this documentation when its contract changes.
  void sendMessage() {
    final text = messageController.text.trim();
    if (text.isEmpty) return;
    AppController.instance.sendGroupMessage(message: text);
    messageController.clear();
    setState(() {});
  }

  /// Performs `openRecommendationDialog` for this feature. Update this documentation when its contract changes.
  Future<void> openRecommendationDialog() async {
    await showDialog(context: context, builder: (_) => const AddGroupRecommendationDialog());
    if (mounted) setState(() {});
  }

  /// Performs `refreshRecommendations` for this feature. Update this documentation when its contract changes.
  Future<void> refreshRecommendations() async {
    try {
      await AppController.instance.loadGroupRecommendations();
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) _showMessage('Unable to refresh recommendations: $error');
    }
  }

  /// Performs `refreshWishlist` for this feature. Update this documentation when its contract changes.
  Future<void> refreshWishlist() async {
    try {
      await AppController.instance.loadGroupWishlist();
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) _showMessage('Unable to refresh wishlist: $error');
    }
  }

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    final controller = AppController.instance;
    return Scaffold(
      backgroundColor: const Color(0xFF070707),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: const Text('Group', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [IconButton(tooltip: 'Refresh', onPressed: loading ? null : loadGroupData, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: loadGroupData,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF242424), Color(0xFF101010)]),
                      border: Border.all(color: Colors.white.withValues(alpha: .07)),
                    ),
                    child: Row(children: [
                      Container(width: 54, height: 54, decoration: BoxDecoration(color: Colors.red.withValues(alpha: .14), borderRadius: BorderRadius.circular(17)), child: const Icon(Icons.groups_rounded, size: 28)),
                      const SizedBox(width: 14),
                      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Watch together', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                        SizedBox(height: 4),
                        Text('Chat, recommend titles, and build a shared watchlist.', style: TextStyle(color: Colors.white60, height: 1.35)),
                      ])),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  _GroupSectionHeader(title: 'Group Chat', icon: Icons.chat_bubble_outline_rounded, action: _SmallHeaderButton(icon: Icons.movie_outlined, label: 'Recommend', onTap: openRecommendationDialog)),
                  const SizedBox(height: 10),
                  if (controller.groupMessages.isEmpty)
                    const _GroupEmptyCard(icon: Icons.forum_outlined, title: 'No messages yet', subtitle: 'Start the conversation below.')
                  else
                    ...controller.groupMessages.map((message) => _GroupMessageBubble(sender: message.sender, message: message.message, time: _formatTime(message.timestamp), badgeName: controller.currentProfileBadge())),
                  if (controller.groupRecommendations.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    _GroupSectionHeader(title: 'Recommendations', icon: Icons.auto_awesome_outlined, action: IconButton(onPressed: refreshRecommendations, icon: const Icon(Icons.refresh_rounded))),
                    const SizedBox(height: 10),
                    ...controller.groupRecommendations.map((recommendation) => GroupRecommendationCard(recommendation: recommendation, onChanged: () { if (mounted) setState(() {}); })),
                  ],
                  const SizedBox(height: 22),
                  _GroupSectionHeader(title: 'Shared Wishlist', icon: Icons.favorite_outline_rounded, action: IconButton(onPressed: refreshWishlist, icon: const Icon(Icons.refresh_rounded))),
                  const SizedBox(height: 10),
                  if (controller.wishlist.isEmpty)
                    const _GroupEmptyCard(icon: Icons.favorite_border_rounded, title: 'Your group wishlist is empty', subtitle: 'Approved recommendations will appear here.')
                  else
                    ...controller.wishlist.map((item) => GroupWishlistCard(item: item, onChanged: () { if (mounted) setState(() {}); })),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              decoration: BoxDecoration(color: const Color(0xFF101010), border: Border(top: BorderSide(color: Colors.white.withValues(alpha: .07)))),
              child: Row(children: [
                Expanded(child: TextField(controller: messageController, onSubmitted: (_) => sendMessage(), textInputAction: TextInputAction.send, decoration: InputDecoration(hintText: 'Message the group...', filled: true, fillColor: Colors.white.withValues(alpha: .05), prefixIcon: const Icon(Icons.chat_bubble_outline_rounded), border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none)))),
                const SizedBox(width: 8),
                Material(color: Colors.red, borderRadius: BorderRadius.circular(17), child: InkWell(onTap: sendMessage, borderRadius: BorderRadius.circular(17), child: const SizedBox(width: 52, height: 52, child: Icon(Icons.send_rounded)))),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  /// Performs `_formatTime` for this feature. Update this documentation when its contract changes.
  String _formatTime(DateTime timestamp) => '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
}

class _GroupSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? action;
  const _GroupSectionHeader({required this.title, required this.icon, this.action});
  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) => Row(children: [Icon(icon, size: 20, color: Colors.white70), const SizedBox(width: 9), Expanded(child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))), if (action != null) action!]);
}

class _SmallHeaderButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SmallHeaderButton({required this.icon, required this.label, required this.onTap});
  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) => TextButton.icon(onPressed: onTap, icon: Icon(icon, size: 17), label: Text(label), style: TextButton.styleFrom(foregroundColor: Colors.white));
}

class _GroupEmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _GroupEmptyCard({required this.icon, required this.title, required this.subtitle});
  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .035), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: .06))), child: Column(children: [Icon(icon, size: 42, color: Colors.white38), const SizedBox(height: 10), Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white38, fontSize: 12))]));
}

class _GroupMessageBubble extends StatelessWidget {
  final String sender;
  final String message;
  final String time;
  final String? badgeName;
  const _GroupMessageBubble({required this.sender, required this.message, required this.time, this.badgeName});
  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .045), borderRadius: BorderRadius.circular(17)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const CircleAvatar(radius: 20, child: Icon(Icons.person_rounded, size: 20)), const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Row(children: [Flexible(child: Text(sender, style: const TextStyle(fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis)), if (badgeName != null && badgeName!.isNotEmpty) ...[const SizedBox(width: 6), _InlineBadgeTag(label: badgeName!)] ])), Text(time, style: const TextStyle(color: Colors.white38, fontSize: 11))]), const SizedBox(height: 4), Text(message, style: const TextStyle(color: Colors.white70, height: 1.35))]))]));
}

class _InlineBadgeTag extends StatelessWidget {
  final String label;
  const _InlineBadgeTag({required this.label});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.amber.withValues(alpha: .13), borderRadius: BorderRadius.circular(999)), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.emoji_events_rounded, size: 10, color: Colors.amber), const SizedBox(width: 3), Text(label, style: const TextStyle(color: Colors.amber, fontSize: 8, fontWeight: FontWeight.w800))]));
}

// ============================================================
// ADD GROUP RECOMMENDATION
// ============================================================

class AddGroupRecommendationDialog
    extends StatefulWidget {
  const AddGroupRecommendationDialog({
    super.key,
  });

  @override
  State<AddGroupRecommendationDialog>
      createState() =>
          _AddGroupRecommendationDialogState();
}

class _AddGroupRecommendationDialogState
    extends State<
        AddGroupRecommendationDialog> {
  final TextEditingController
      titleController =
      TextEditingController();

  final TextEditingController
      customDurationController =
      TextEditingController();

  String selectedType = 'movie';
  String selectedDuration = '24h';
  String customDurationUnit = 'hours';
  bool submitting = false;

  @override
  /// Performs `dispose` for this feature. Update this documentation when its contract changes.
  void dispose() {
    titleController.dispose();
    customDurationController.dispose();
    super.dispose();
  }

  int? get selectedDurationHours {
    switch (selectedDuration) {
      case '24h':
        return 24;

      case '3d':
        return 72;

      case '1w':
        return 168;

      case 'custom':
        final amount = int.tryParse(
          customDurationController.text.trim(),
        );

        if (amount == null || amount <= 0) {
          return null;
        }

        if (customDurationUnit == 'days') {
          return amount * 24;
        }

        return amount;
    }

    return 24;
  }

  /// Performs `submitRecommendation` for this feature. Update this documentation when its contract changes.
  Future<void> submitRecommendation() async {
    if (submitting) {
      return;
    }

    final title =
        titleController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter a movie or TV show title.',
          ),
        ),
      );
      return;
    }

    final controller =
        AppController.instance;

    final currentProfile =
        controller.currentProfile;

    if (currentProfile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No profile is currently selected.',
          ),
        ),
      );
      return;
    }

    final durationHours =
        selectedDurationHours;

    if (durationHours == null ||
        durationHours <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter a valid custom voting duration.',
          ),
        ),
      );
      return;
    }

    setState(() {
      submitting = true;
    });

    try {
      await controller.createGroupRecommendation(
        title: title,
        type: selectedType,
        profileId: currentProfile.id,
        votingDurationHours: durationHours,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '"$title" was recommended to the group. '
            'Voting is open for ${_formatDuration(durationHours)}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

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
          content: Text(
            'Unable to create recommendation: $message',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          submitting = false;
        });
      }
    }
  }

  /// Performs `_formatDuration` for this feature. Update this documentation when its contract changes.
  String _formatDuration(int hours) {
    if (hours % 168 == 0) {
      final weeks = hours ~/ 168;

      return weeks == 1
          ? '1 week'
          : '$weeks weeks';
    }

    if (hours % 24 == 0) {
      final days = hours ~/ 24;

      return days == 1
          ? '1 day'
          : '$days days';
    }

    return hours == 1
        ? '1 hour'
        : '$hours hours';
  }

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Recommend to the Group',
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                'Recommend any movie or TV show to the group. '
                'It does not have to already exist in your library.',
              ),
              const SizedBox(
                height: 20,
              ),
              TextField(
                controller:
                    titleController,
                enabled:
                    !submitting,
                autofocus: true,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Movie or TV show title',
                  hintText:
                      'Enter a title...',
                  prefixIcon:
                      Icon(Icons.search),
                  border:
                      OutlineInputBorder(),
                ),
              ),
              const SizedBox(
                height: 15,
              ),
              DropdownButtonFormField<String>(
                initialValue:
                    selectedType,
                decoration:
                    const InputDecoration(
                  labelText: 'Type',
                  border:
                      OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem<String>(
                    value: 'movie',
                    child: Row(
                      children: [
                        Icon(
                          Icons.movie_outlined,
                        ),
                        SizedBox(
                          width: 10,
                        ),
                        Text(
                          'Movie',
                        ),
                      ],
                    ),
                  ),
                  DropdownMenuItem<String>(
                    value: 'tvShow',
                    child: Row(
                      children: [
                        Icon(
                          Icons.tv_outlined,
                        ),
                        SizedBox(
                          width: 10,
                        ),
                        Text(
                          'TV Show',
                        ),
                      ],
                    ),
                  ),
                ],
                onChanged:
                    submitting
                        ? null
                        : (value) {
                            if (value == null) {
                              return;
                            }

                            setState(() {
                              selectedType =
                                  value;
                            });
                          },
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                initialValue:
                    selectedDuration,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Voting duration',
                  border:
                      OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem<String>(
                    value: '24h',
                    child: Text(
                      '24 hours',
                    ),
                  ),
                  DropdownMenuItem<String>(
                    value: '3d',
                    child: Text(
                      '3 days',
                    ),
                  ),
                  DropdownMenuItem<String>(
                    value: '1w',
                    child: Text(
                      '1 week',
                    ),
                  ),
                  DropdownMenuItem<String>(
                    value: 'custom',
                    child: Text(
                      'Custom',
                    ),
                  ),
                ],
                onChanged:
                    submitting
                        ? null
                        : (value) {
                            if (value == null) {
                              return;
                            }

                            setState(() {
                              selectedDuration =
                                  value;
                            });
                          },
              ),
              if (selectedDuration ==
                  'custom') ...[
                const SizedBox(height: 15),
                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller:
                            customDurationController,
                        enabled:
                            !submitting,
                        keyboardType:
                            TextInputType.number,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Amount',
                          hintText:
                              'Example: 12',
                          border:
                              OutlineInputBorder(),
                        ),
                        onChanged: (_) {
                          setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Expanded(
                      child:
                          DropdownButtonFormField<
                              String>(
                        initialValue:
                            customDurationUnit,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Unit',
                          border:
                              OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem<
                              String>(
                            value:
                                'hours',
                            child:
                                Text(
                              'Hours',
                            ),
                          ),
                          DropdownMenuItem<
                              String>(
                            value:
                                'days',
                            child:
                                Text(
                              'Days',
                            ),
                          ),
                        ],
                        onChanged:
                            submitting
                                ? null
                                : (value) {
                                    if (value ==
                                        null) {
                                      return;
                                    }

                                    setState(() {
                                      customDurationUnit =
                                          value;
                                    });
                                  },
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Text(
                selectedDuration ==
                        'custom'
                    ? selectedDurationHours ==
                            null
                        ? 'Enter a duration greater than 0.'
                        : 'Voting will remain open for '
                            '${_formatDuration(selectedDurationHours!)}.'
                    : 'Voting will remain open for '
                        '${_formatDuration(selectedDurationHours ?? 24)}.',
                style: TextStyle(
                  color: Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              submitting
                  ? null
                  : () {
                      Navigator.of(
                        context,
                      ).pop();
                    },
          child: const Text(
            'CANCEL',
          ),
        ),
        ElevatedButton.icon(
          onPressed:
              submitting
                  ? null
                  : submitRecommendation,
          icon:
              submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.send,
                    ),
          label: const Text(
            'RECOMMEND',
          ),
        ),
      ],
    );
  }
}

// ============================================================
// GROUP RECOMMENDATION CARD
// ============================================================

class GroupRecommendationCard
    extends StatefulWidget {
  final Map<String, dynamic> recommendation;
  final VoidCallback onChanged;

  const GroupRecommendationCard({
    super.key,
    required this.recommendation,
    required this.onChanged,
  });

  @override
  State<GroupRecommendationCard>
      createState() =>
          _GroupRecommendationCardState();
}

class _GroupRecommendationCardState
    extends State<GroupRecommendationCard> {
  Timer? countdownTimer;
  Duration remaining = Duration.zero;
  bool voting = false;
  bool refreshingAfterDeadline = false;

  @override
  /// Performs `initState` for this feature. Update this documentation when its contract changes.
  void initState() {
    super.initState();
    _updateRemaining();
    _startCountdown();
  }

  @override
  /// Performs `didUpdateWidget` for this feature. Update this documentation when its contract changes.
  void didUpdateWidget(
    covariant GroupRecommendationCard oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.recommendation['votingEndsAt'] !=
        widget.recommendation['votingEndsAt']) {
      _updateRemaining();
    }

    _startCountdown();
  }

  @override
  /// Performs `dispose` for this feature. Update this documentation when its contract changes.
  void dispose() {
    countdownTimer?.cancel();
    super.dispose();
  }

  /// Performs `_startCountdown` for this feature. Update this documentation when its contract changes.
  void _startCountdown() {
    countdownTimer?.cancel();

    final status =
        _statusString(widget.recommendation);

    if (status != 'voting') {
      return;
    }

    countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted) return;
        _updateRemaining();
      },
    );
  }

  /// Performs `_updateRemaining` for this feature. Update this documentation when its contract changes.
  void _updateRemaining() {
    final endsAt =
        _dateTimeValue(
      widget.recommendation['votingEndsAt'],
    );

    if (endsAt == null) {
      if (mounted) {
        setState(() {
          remaining = Duration.zero;
        });
      }

      return;
    }

    final difference =
        endsAt.difference(DateTime.now());

    if (difference <= Duration.zero) {
      if (mounted) {
        setState(() {
          remaining = Duration.zero;
        });
      }

      _refreshAfterDeadline();
      return;
    }

    if (mounted) {
      setState(() {
        remaining = difference;
      });
    }
  }

  /// Performs `_refreshAfterDeadline` for this feature. Update this documentation when its contract changes.
  Future<void> _refreshAfterDeadline() async {
    if (refreshingAfterDeadline) {
      return;
    }

    final status =
        _statusString(widget.recommendation);

    if (status != 'voting') {
      return;
    }

    refreshingAfterDeadline = true;
    countdownTimer?.cancel();

    try {
      final controller =
          AppController.instance;

      await controller.loadGroupRecommendations();
      await controller.loadGroupWishlist();

      if (!mounted) return;

      widget.onChanged();
    } catch (_) {
    } finally {
      refreshingAfterDeadline = false;
    }
  }

  /// Performs `_vote` for this feature. Update this documentation when its contract changes.
  Future<void> _vote(String vote) async {
    if (voting) {
      return;
    }

    final controller =
        AppController.instance;

    final currentProfile =
        controller.currentProfile;

    if (currentProfile == null) {
      _showMessage(
        'No profile is currently selected.',
      );
      return;
    }

    final status =
        _statusString(widget.recommendation);

    if (status != 'voting' ||
        remaining <= Duration.zero) {
      await _refreshAfterDeadline();
      return;
    }

    final votes =
        _votesMap(
      widget.recommendation['votes'],
    );

    if (votes.containsKey(
      currentProfile.id,
    )) {
      _showMessage(
        'You have already voted on this recommendation.',
      );
      return;
    }

    setState(() {
      voting = true;
    });

    try {
      await controller.voteOnGroupRecommendation(
        recommendationId:
            _stringValue(
              widget.recommendation['id'],
            ),
        profileId:
            currentProfile.id,
        vote: vote,
      );

      await controller.loadGroupRecommendations();

      final updatedStatus =
          _findUpdatedRecommendationStatus();

      if (updatedStatus == 'approved') {
        await controller.loadGroupWishlist();
      }

      if (!mounted) return;

      widget.onChanged();

      _showMessage(
        vote == 'yes'
            ? 'Your YES vote was recorded.'
            : 'Your NO vote was recorded.',
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

      _showMessage(
        'Unable to record your vote: $message',
      );
    } finally {
      if (mounted) {
        setState(() {
          voting = false;
        });
      }
    }
  }

  /// Performs `_findUpdatedRecommendationStatus` for this feature. Update this documentation when its contract changes.
  String _findUpdatedRecommendationStatus() {
    final id =
        _stringValue(
          widget.recommendation['id'],
        );

    final controller =
        AppController.instance;

    for (final recommendation
        in controller.groupRecommendations) {
      if (_stringValue(
            recommendation['id'],
          ) ==
          id) {
        return _statusString(
          recommendation,
        );
      }
    }

    return _statusString(
      widget.recommendation,
    );
  }

  /// Performs `_showMessage` for this feature. Update this documentation when its contract changes.
  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    final recommendation =
        widget.recommendation;

    final controller =
        AppController.instance;

    final currentProfile =
        controller.currentProfile;

    final title =
        _stringValue(
      recommendation['title'],
      fallback: 'Untitled',
    );

    final type =
        _stringValue(
      recommendation['type'],
      fallback: 'movie',
    );

    final status =
        _statusString(recommendation);

    final recommender = _profileName(
      _stringValue(
        recommendation['recommendedByProfileId'],
      ),
      controller,
    );

    final votes =
        _votesMap(
      recommendation['votes'],
    );

    final yesVotes =
        _intValue(
          recommendation['yesVotes'],
          fallback: votes.values
              .where(
                (vote) => vote == 'yes',
              )
              .length,
        );

    final noVotes =
        _intValue(
          recommendation['noVotes'],
          fallback: votes.values
              .where(
                (vote) => vote == 'no',
              )
              .length,
        );

    final totalVotes = yesVotes + noVotes;

    final yesPercentage = _percentage(
      recommendation['yesPercentage'],
      yesVotes,
      totalVotes,
    );

    final noPercentage =
        _percentage(
      recommendation['noPercentage'],
      noVotes,
      totalVotes,
    );

    final currentVote =
        currentProfile == null
            ? null
            : votes[currentProfile.id];

    // All profiles belonging to the account can vote. The only per-profile
    // restriction is one vote per recommendation.
    final canVote =
        status == 'voting' &&
        remaining > Duration.zero &&
        currentProfile != null &&
        currentVote == null &&
        !voting;

    final typeIsMovie =
        type.toLowerCase() == 'movie';

    final icon =
        typeIsMovie
            ? Icons.movie_outlined
            : Icons.tv_outlined;

    final accentColor =
        status == 'approved'
            ? Colors.green
            : status == 'rejected' ||
                    status == 'expired'
                ? Colors.red
                : Colors.orange;

    return Card(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor:
                      accentColor.withValues(
                    alpha: .15,
                  ),
                  child: Icon(
                    icon,
                    color: accentColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${typeIsMovie ? 'Movie' : 'TV Show'} '
                        'recommended by $recommender',
                        style: TextStyle(
                          color:
                              Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            if (status == 'voting') ...[
              Row(
                children: [
                  const Icon(
                    Icons.schedule,
                    size: 18,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      remaining > Duration.zero
                          ? 'Voting ends in ${_formatRemaining(remaining)}'
                          : 'Voting ending...',
                      style: const TextStyle(
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
            ] else ...[
              const Row(
                children: [
                  Icon(
                    Icons.lock_clock,
                    size: 18,
                  ),
                  SizedBox(width: 7),
                  Text(
                    'Voting ended',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
            ],
            Row(
              children: [
                Expanded(
                  child: _VotePercentage(
                    label: 'YES',
                    percentage:
                        yesPercentage,
                    votes: yesVotes,
                    icon: Icons.check,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _VotePercentage(
                    label: 'NO',
                    percentage:
                        noPercentage,
                    votes: noVotes,
                    icon: Icons.close,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius:
                  BorderRadius.circular(5),
              child: Row(
                children: [
                  Expanded(
                    flex: _percentageFlex(
                      yesPercentage,
                    ),
                    child: Container(
                      height: 8,
                      color: Colors.green,
                    ),
                  ),
                  Expanded(
                    flex: _percentageFlex(
                      noPercentage,
                    ),
                    child: Container(
                      height: 8,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            if (status == 'voting') ...[
              if (currentVote != null)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(8),
                    color:
                        Colors.blueGrey.shade900,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        currentVote == 'yes'
                            ? Icons.check_circle
                            : Icons.cancel,
                        color:
                            currentVote == 'yes'
                                ? Colors.green
                                : Colors.red,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'You voted '
                          '${currentVote.toUpperCase()}',
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else if (currentProfile == null)
                Text(
                  'Select a profile to vote.',
                  style: TextStyle(
                    color:
                        Colors.grey.shade400,
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                            canVote
                                ? () =>
                                    _vote('yes')
                                : null,
                        icon: const Icon(
                          Icons.check,
                        ),
                        label: const Text(
                          'YES',
                        ),
                        style:
                            ElevatedButton
                                .styleFrom(
                          backgroundColor:
                              Colors.green
                                  .shade700,
                          foregroundColor:
                              Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                            canVote
                                ? () =>
                                    _vote('no')
                                : null,
                        icon: const Icon(
                          Icons.close,
                        ),
                        label: const Text(
                          'NO',
                        ),
                        style:
                            ElevatedButton
                                .styleFrom(
                          backgroundColor:
                              Colors.red
                                  .shade700,
                          foregroundColor:
                              Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
            if (status == 'approved') ...[
              const SizedBox(height: 5),
              const Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Added to Group Wishlist',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (status == 'rejected') ...[
              const SizedBox(height: 5),
              const Row(
                children: [
                  Icon(
                    Icons.cancel,
                    color: Colors.red,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Recommendation rejected',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (status == 'expired') ...[
              const SizedBox(height: 5),
              const Row(
                children: [
                  Icon(
                    Icons.timer_off,
                    color: Colors.red,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Recommendation expired',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (totalVotes == 0 &&
                status == 'voting')
              Padding(
                padding:
                    const EdgeInsets.only(
                  top: 8,
                ),
                child: Text(
                  'No votes yet.',
                  style: TextStyle(
                    color:
                        Colors.grey.shade500,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// VOTE PERCENTAGE
// ============================================================

class _VotePercentage extends StatelessWidget {
  final String label;
  final double percentage;
  final int votes;
  final IconData icon;

  const _VotePercentage({
    required this.label,
    required this.percentage,
    required this.votes,
    required this.icon,
  });

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    final color =
        label == 'YES'
            ? Colors.green
            : Colors.red;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(
            alpha: .4,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight:
                        FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${_formatPercentageValue(percentage)}%',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                Text(
                  '$votes vote${votes == 1 ? '' : 's'}',
                  style: TextStyle(
                    color:
                        Colors.grey.shade500,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatPercentageValue(
    double value,
  ) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(1);
  }
}

// ============================================================
// GROUP WISHLIST CARD
// ============================================================

class GroupWishlistCard
    extends StatelessWidget {
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
    final controller =
        AppController.instance;

    try {
      await controller.removeFromGroupWishlist(
        item.id,
      );

      await controller.loadGroupWishlist();

      if (!context.mounted) return;

      onChanged();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${item.title} removed from the group wishlist.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
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
    final controller =
        AppController.instance;

    final account =
        controller.currentAccount;

    if (account == null ||
        account.profiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No profiles are available.',
          ),
        ),
      );
      return;
    }

    final selectedProfile =
        await showDialog<Profile>(
      context: context,
      builder: (_) =>
          SelectAcquisitionProfileDialog(
        profiles: account.profiles,
        currentProfile:
            controller.currentProfile,
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
          content: Text(
            '${item.title} was acquired for ${selectedProfile.name}.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
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
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      child: ListTile(
        leading:
            const CircleAvatar(
          child: Icon(
            Icons.movie_outlined,
          ),
        ),
        title: Text(
          item.title,
          maxLines: 2,
          overflow:
              TextOverflow.ellipsis,
        ),
        subtitle: Text(
          item.type,
        ),
        trailing:
            PopupMenuButton<String>(
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
              child: Text(
                'Acquire / Rip',
              ),
            ),
            PopupMenuItem<String>(
              value: 'remove',
              child: Text(
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

class SelectAcquisitionProfileDialog
    extends StatelessWidget {
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
      title: const Text(
        'Add to Which Profile?',
      ),
      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            const Text(
              'Choose the profile whose personal library should receive this movie or show.',
            ),
            const SizedBox(height: 15),
            ...profiles.map(
              (profile) =>
                  ListTile(
                leading:
                    CircleAvatar(
                  backgroundImage:
                      profile.avatarUrl ==
                              null
                          ? null
                          : NetworkImage(
                              profile
                                  .avatarUrl!,
                            ),
                  child:
                      profile.avatarUrl ==
                              null
                          ? const Icon(
                              Icons.person,
                            )
                          : null,
                ),
                title:
                    Text(
                  profile.name,
                ),
                subtitle:
                    profile.id ==
                            currentProfile
                                ?.id
                        ? const Text(
                            'Current profile',
                          )
                        : null,
                trailing:
                    const Icon(
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
          onPressed: () =>
              Navigator.pop(
            context,
          ),
          child:
              const Text('CANCEL'),
        ),
      ],
    );
  }
}

// ============================================================
// WISHLIST
// ============================================================

class WishlistDialog
    extends StatefulWidget {
  const WishlistDialog({super.key});

  @override
  State<WishlistDialog> createState() =>
      _WishlistDialogState();
}

class _WishlistDialogState
    extends State<WishlistDialog> {
  bool loading = false;

  @override
  /// Performs `initState` for this feature. Update this documentation when its contract changes.
  void initState() {
    super.initState();
    loadWishlist();
  }

  /// Performs `loadWishlist` for this feature. Update this documentation when its contract changes.
  Future<void> loadWishlist() async {
    final controller =
        AppController.instance;

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
          content: Text(
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
    final controller =
        AppController.instance;

    return AlertDialog(
      title: const Text(
        'Group Wishlist',
      ),
      content: SizedBox(
        width: 600,
        height: 500,
        child: loading
            ? const Center(
                child:
                    CircularProgressIndicator(),
              )
            : controller
                    .wishlist
                    .isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.favorite_border,
                          size: 60,
                        ),
                        SizedBox(
                          height: 15,
                        ),
                        Text(
                          'No group wishlist items.',
                          style:
                              TextStyle(
                            fontSize: 18,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        SizedBox(
                          height: 8,
                        ),
                        Text(
                          'Shared items for the group will appear here.',
                          textAlign:
                              TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount:
                        controller.wishlist.length,
                    itemBuilder:
                        (_, index) {
                      final item =
                          controller
                              .wishlist[index];

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
          onPressed: () =>
              Navigator.pop(context),
          child:
              const Text('CLOSE'),
        ),
        ElevatedButton.icon(
          onPressed:
              loading ? null : loadWishlist,
          icon: const Icon(
            Icons.refresh,
          ),
          label:
              const Text('REFRESH'),
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

class _GroupWatchDialogState extends State<GroupWatchDialog> {
  final Set<String> selectedProfiles = <String>{};

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    final controller = AppController.instance;
    final account = controller.currentAccount;
    final currentProfile = controller.currentProfile;
    if (account == null || currentProfile == null) {
      return const Scaffold(body: Center(child: Text('No account or profile selected.')));
    }
    final invitees = account.profiles.where((profile) => profile.id != currentProfile.id).toList();
    return Scaffold(
      backgroundColor: const Color(0xFF070707),
      appBar: AppBar(backgroundColor: Colors.transparent, surfaceTintColor: Colors.transparent, title: const Text('Group Watch', style: TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
        children: [
          Container(
            height: 260,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(25), color: const Color(0xFF151515)),
            child: Stack(fit: StackFit.expand, children: [
              if (widget.media.imageUrl != null) Image.network(widget.media.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withValues(alpha: .92)]))),
              Positioned(left: 18, right: 18, bottom: 18, child: Text(widget.media.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900))),
            ]),
          ),
          const SizedBox(height: 22),
          const Text('Invite people', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          const Text('Select the profiles you want to watch with.', style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 12),
          if (invitees.isEmpty)
            const _GroupEmptyCard(icon: Icons.people_outline_rounded, title: 'No other profiles', subtitle: 'Create another profile to invite someone.')
          else
            ...invitees.map((profile) {
              final selected = selectedProfiles.contains(profile.id);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: selected ? Colors.red.withValues(alpha: .10) : Colors.white.withValues(alpha: .045),
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    onTap: () => setState(() => selected ? selectedProfiles.remove(profile.id) : selectedProfiles.add(profile.id)),
                    borderRadius: BorderRadius.circular(18),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(children: [
                        _MainProfileAvatar(profile: profile, size: 48),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(profile.name, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text(selected ? 'Selected' : 'Tap to invite', style: const TextStyle(color: Colors.white38, fontSize: 12))])),
                        Icon(selected ? Icons.check_circle_rounded : Icons.circle_outlined, color: selected ? Colors.redAccent : Colors.white30),
                      ]),
                    ),
                  ),
                ),
              );
            }),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupWatchPreferencesScreen(media: widget.media))),
            icon: const Icon(Icons.tune_rounded),
            label: Text(selectedProfiles.isEmpty ? 'CONTINUE' : 'CONTINUE WITH ${selectedProfiles.length} INVITE${selectedProfiles.length == 1 ? '' : 'S'}'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          ),
        ],
      ),
    );
  }
}

class GroupWatchPreferencesScreen extends StatefulWidget {
  final MediaItem media;
  const GroupWatchPreferencesScreen({super.key, required this.media});
  @override
  State<GroupWatchPreferencesScreen> createState() => _GroupWatchPreferencesScreenState();
}

class _GroupWatchPreferencesScreenState extends State<GroupWatchPreferencesScreen> {
  bool subtitlesEnabled = false;
  String audio = 'Original audio';

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070707),
      appBar: AppBar(backgroundColor: Colors.transparent, surfaceTintColor: Colors.transparent, title: const Text('Your preferences', style: TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .045), borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white.withValues(alpha: .07))),
            child: Row(children: [const Icon(Icons.groups_rounded, size: 30), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.media.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)), const SizedBox(height: 3), const Text('Choose your language settings before starting.', style: TextStyle(color: Colors.white54, fontSize: 12))]))]),
          ),
          const SizedBox(height: 22),
          const Text('Audio', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .045), borderRadius: BorderRadius.circular(17)),
            child: DropdownButtonFormField<String>(
              initialValue: audio,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.language_rounded), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
              items: const [DropdownMenuItem(value: 'Original audio', child: Text('Original audio'))],
              onChanged: (value) { if (value != null) setState(() => audio = value); },
            ),
          ),
          const SizedBox(height: 18),
          Container(
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .045), borderRadius: BorderRadius.circular(17)),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(17),
              clipBehavior: Clip.antiAlias,
              child: SwitchListTile.adaptive(
                tileColor: Colors.transparent,
                title: const Text('Subtitles', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Use subtitles for this session', style: TextStyle(color: Colors.white38, fontSize: 12)),
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
            label: const Text('START GROUP WATCH'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// GROUP RECOMMENDATION HELPERS
// ============================================================

String _stringValue(
  dynamic value, {
  String fallback = '',
}) {
  if (value == null) {
    return fallback;
  }

  final result = value.toString().trim();

  return result.isEmpty
      ? fallback
      : result;
}

String _statusString(
  Map<String, dynamic> recommendation,
) {
  return _stringValue(
    recommendation['status'],
    fallback: 'voting',
  ).toLowerCase();
}

DateTime? _dateTimeValue(
  dynamic value,
) {
  if (value is DateTime) {
    return value;
  }

  if (value is String) {
    return DateTime.tryParse(value);
  }

  return null;
}

int _intValue(
  dynamic value, {
  int fallback = 0,
}) {
  if (value is int) {
    return value;
  }

  if (value is double) {
    return value.round();
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(
        value?.toString() ?? '',
      ) ??
      fallback;
}

Map<String, String> _votesMap(
  dynamic value,
) {
  if (value is! Map) {
    return <String, String>{};
  }

  final result =
      <String, String>{};

  value.forEach(
    (key, vote) {
      final profileId =
          key.toString();

      final voteString =
          vote.toString().toLowerCase();

      if (voteString == 'yes' ||
          voteString == 'no') {
        result[profileId] =
            voteString;
      }
    },
  );

  return result;
}

double _percentage(
  dynamic value,
  int votes,
  int totalVotes,
) {
  if (value is num) {
    return value.toDouble();
  }

  if (totalVotes <= 0) {
    return 0;
  }

  return (votes / totalVotes) * 100;
}

String _profileName(
  String profileId,
  AppController controller,
) {
  final account =
      controller.currentAccount;

  if (account != null) {
    for (final profile
        in account.profiles) {
      if (profile.id == profileId) {
        return profile.name;
      }
    }
  }

  return profileId.isEmpty
      ? 'Unknown profile'
      : profileId;
}

String _formatRemaining(
  Duration duration,
) {
  if (duration <= Duration.zero) {
    return '0 minutes';
  }

  final days = duration.inDays;

  final hours =
      duration.inHours.remainder(24);

  final minutes =
      duration.inMinutes.remainder(60);

  final seconds =
      duration.inSeconds.remainder(60);

  if (days > 0) {
    if (hours > 0) {
      return '${days}d ${hours}h';
    }

    return '${days}d';
  }

  if (hours > 0) {
    if (minutes > 0) {
      return '${hours}h ${minutes}m';
    }

    return '${hours}h';
  }

  if (minutes > 0) {
    if (seconds > 0) {
      return '${minutes}m ${seconds}s';
    }

    return '${minutes}m';
  }

  return '${seconds}s';
}

int _percentageFlex(
  double percentage,
) {
  final rounded =
      percentage.round();

  if (rounded <= 0) {
    return 1;
  }

  return rounded;
}
