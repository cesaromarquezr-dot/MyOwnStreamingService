import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'app_core.dart';
import 'backend_api.dart';
import 'signup.dart';
import 'movies.dart';
import 'series.dart';
import 'smart_search.dart';
import 'hollywood.dart';
import 'details.dart';
import 'profiles.dart';
import 'feature_center.dart';
import 'ultimate_features.dart';
import 'remote_access.dart';
import 'account_settings.dart';
import 'device_features.dart';
import 'roadmap_features.dart';
void main() {
  runApp(const MyStreamingService());
}
class MyStreamingService extends StatelessWidget {
  const MyStreamingService({super.key});
  @override
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
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
      );
    });
  }
  @override
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
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  bool obscurePassword = true;
  bool loggingIn = false;
  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }
  Future<void> login() async {
    if (loggingIn) return;
    final username = usernameController.text.trim();
    final password = passwordController.text;
    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter your username/email and password.',
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
        usernameOrEmail: username,
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
                  controller: usernameController,
                  enabled: !loggingIn,
                  decoration: const InputDecoration(
                    labelText: 'Username or Email',
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

class HomeCustomization {
  bool showHero;
  bool showContinueWatching;
  bool showRecentlyWatched;
  bool showMovies;
  bool showTvShows;
  bool showNewAdditions;
  bool showAllLibrary;
  bool showRecommendations;
  String heroStyle;
  String cardSize;
  String navbarPosition;
  String storageBarPosition;
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
    this.heroStyle = 'Cinematic',
    this.cardSize = 'Medium',
    this.navbarPosition = 'Bottom',
    this.storageBarPosition = 'Above Navbar',
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
        ],
        navigationOrder = navigationOrder ?? [
          'Home',
          'Movies',
          'TV Shows',
          'Actors',
          'Music',
          'Trailers',
          'Search',
          'Collections',
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
        heroStyle: heroStyle,
        cardSize: cardSize,
        navbarPosition: navbarPosition,
        storageBarPosition: storageBarPosition,
        sectionOrder: List<String>.from(sectionOrder),
        navigationOrder: List<String>.from(navigationOrder),
      );
}

class HomeCustomizationStore {
  HomeCustomizationStore._();

  static final Map<String, HomeCustomization> _settings =
      <String, HomeCustomization>{};

  // A profile is considered configured only after the user explicitly saves
  // the first-time customization screen. Reading default settings must not
  // count as configuration.
  static final Set<String> _configuredProfiles = <String>{};

  static String _key(Profile? profile) => profile?.id ?? 'default';

  static HomeCustomization settingsFor(Profile? profile) {
    return _settings.putIfAbsent(
      _key(profile),
      () => HomeCustomization(),
    ).copy();
  }

  // Backwards-compatible accessor for code that only needs the current profile.
  static HomeCustomization get settings => settingsFor(AppController.instance.currentProfile);

  static bool isConfigured(Profile? profile) =>
      _configuredProfiles.contains(_key(profile));

  static bool get hasConfigured =>
      isConfigured(AppController.instance.currentProfile);

  static void apply(HomeCustomization value, [Profile? profile]) {
    final key = _key(profile ?? AppController.instance.currentProfile);
    _settings[key] = value.copy();
    _configuredProfiles.add(key);
  }

  static void removeProfile(Profile profile) {
    _settings.remove(profile.id);
    _configuredProfiles.remove(profile.id);
  }

  static void clear() {
    _settings.clear();
    _configuredProfiles.clear();
  }
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
  void initState() {
    super.initState();
    draft = HomeCustomizationStore.settingsFor(AppController.instance.currentProfile);
    detailsDraft = DetailsCustomizationStore.settingsFor(
      AppController.instance.currentProfile,
    );
  }

  void _save() {
    HomeCustomizationStore.apply(draft, AppController.instance.currentProfile);
    DetailsCustomizationStore.apply(
      AppController.instance.currentProfile,
      detailsDraft,
    );
    Navigator.of(context).pop(true);
  }

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

  Widget _pageSelector() {
    return Row(
      children: [
        Expanded(
          child: _customizationButton(
            label: 'HOME PAGE',
            icon: Icons.home_rounded,
            selected: selectedPage == _CustomizationPage.home,
            onPressed: () {
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
            onPressed: () {
              setState(() {
                selectedPage = _CustomizationPage.details;
              });
            },
          ),
        ),
      ],
    );
  }

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
          onChanged: (value) => setState(() => draft.navbarPosition = value),
        ),
        const SizedBox(height: 12),
        _dropdown(
          label: 'Where should the storage bar appear?',
          value: draft.storageBarPosition,
          values: const ['Top', 'Bottom', 'Above Navbar', 'Hidden'],
          onChanged: (value) => setState(() => draft.storageBarPosition = value),
        ),
        const SizedBox(height: 8),
        const Text(
          'Storage capacity is not exposed by app_core.dart yet, so the current bar shows library occupancy. It is ready to use real server/device storage once those metrics are added.',
          style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.4),
        ),
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
        const SizedBox(height: 24),
        _sectionOrder(
          title: 'SECTION ORDER',
          subtitle: 'Drag Home sections to change their order.',
          items: draft.sectionOrder,
        ),
        const SizedBox(height: 24),
        _sectionOrder(
          title: 'NAVIGATION ORDER',
          subtitle: 'Drag navigation items to personalize this profile.',
          items: draft.navigationOrder,
          onChanged: (value) => setState(() => draft.navigationOrder = value),
        ),
      ],
    );
  }

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
  Widget build(BuildContext context) {
    final isHome = selectedPage == _CustomizationPage.home;

    return Scaffold(
      backgroundColor: const Color(0xFF070707),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070707),
        surfaceTintColor: Colors.transparent,
        title: Text(
          widget.firstSetup ? 'Make Home Yours' : 'Customize App',
        ),
        automaticallyImplyLeading: !widget.firstSetup,
        actions: [
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
                  widget.firstSetup ? 'ENTER MY HOME' : 'SAVE CHANGES',
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
  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          HomeCustomizationStore.isConfigured(
            AppController.instance.currentProfile,
          )) {
        return;
      }
      Navigator.of(context).push<bool>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const CustomizeHomeScreen(firstSetup: true),
        ),
      ).then((_) {
        if (mounted) setState(() {});
      });
    });
  }

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
      ),
    );
  }

  void _openImport() {
    Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const ImportMediaScreen()))
        .then((_) { if (mounted) setState(() {}); });
  }

  void _openProfiles() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileSelectionScreen()))
        .then((_) { if (mounted) setState(() {}); });
  }

  void _openFeatureCenter() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const FeatureCenterScreen()));
  }

  void _openEverything() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const UltimateFeaturesScreen()));
  }

  void _openRemoteAccess() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const RemoteAccessScreen()));
  }

  void _openAccountSettings() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountSettingsScreen()));
  }

  void _openDevices() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const DeviceCenterScreen()));
  }

  void _openRoadmapFeatures() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const RoadmapFeaturesScreen()));
  }

  void _openGroup() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const GroupHubScreen()));
  }

  void _openNotifications() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _ActivitySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(onRefresh: () => setState(() {})),
      const MoviesScreen(),
      const SeriesScreen(),
      const ActorsScreen(),
      const MusicScreen(),
      const TrailersScreen(),
      const SmartSearchScreen(),
      const CollectionsPanel(),
    ];

    final settings = HomeCustomizationStore.settingsFor(AppController.instance.currentProfile);
    final navbar = _StreamingNavigationBar(
      selectedIndex: selectedIndex,
      position: settings.navbarPosition,
      navigationOrder: settings.navigationOrder,
      onSelect: (index) { if (index != selectedIndex) setState(() => selectedIndex = index); },
      onNotifications: _openNotifications,
      onGroup: _openGroup,
      onProfile: _openProfiles,
      onMore: _openMore,
    );
    final page = AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      child: KeyedSubtree(key: ValueKey(selectedIndex), child: pages[selectedIndex]),
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

    return Scaffold(backgroundColor: const Color(0xFF070707), body: content);
  }
}

class _StreamingNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final String position;
  final List<String> navigationOrder;
  final ValueChanged<int> onSelect;
  final VoidCallback onNotifications;
  final VoidCallback onGroup;
  final VoidCallback onProfile;
  final VoidCallback onMore;

  const _StreamingNavigationBar({
    required this.selectedIndex,
    required this.position,
    required this.navigationOrder,
    required this.onSelect,
    required this.onNotifications,
    required this.onGroup,
    required this.onProfile,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final items = <_NavItemData>[
      const _NavItemData(Icons.home_outlined, Icons.home, 'Home'),
      const _NavItemData(Icons.movie_outlined, Icons.movie, 'Movies'),
      const _NavItemData(Icons.tv_outlined, Icons.tv, 'TV Shows'),
      const _NavItemData(Icons.people_outline, Icons.people, 'Actors'),
      const _NavItemData(Icons.music_note_outlined, Icons.music_note, 'Music'),
      const _NavItemData(Icons.play_arrow_outlined, Icons.play_arrow, 'Trailers'),
      const _NavItemData(Icons.search_outlined, Icons.search, 'Search'),
      const _NavItemData(Icons.collections_bookmark_outlined, Icons.collections_bookmark, 'Collections'),
    ];
    final vertical = position == 'Left' || position == 'Right';
    final floating = position == 'Floating';
    final indexByLabel = <String, int>{
      for (var i = 0; i < items.length; i++) items[i].label: i,
    };
    final orderedItems = navigationOrder
        .map((label) => indexByLabel[label])
        .whereType<int>()
        .toList();
    for (var i = 0; i < items.length; i++) {
      if (!orderedItems.contains(i)) orderedItems.add(i);
    }
    final actions = [
      for (final i in orderedItems)
        _NavButton(data: items[i], selected: selectedIndex == i, vertical: vertical, onTap: () => onSelect(i)),
      _NavButton(data: const _NavItemData(Icons.notifications_none_rounded, Icons.notifications_rounded, 'Notifications'), selected: false, vertical: vertical, showBadge: AppController.instance.activity.isNotEmpty, onTap: onNotifications),
      _NavButton(data: const _NavItemData(Icons.groups_outlined, Icons.groups_rounded, 'Group Chat'), selected: false, vertical: vertical, onTap: onGroup),
      _NavButton(data: const _NavItemData(Icons.account_circle_outlined, Icons.account_circle_rounded, 'Profile'), selected: false, vertical: vertical, onTap: onProfile),
      _NavButton(data: const _NavItemData(Icons.more_horiz_rounded, Icons.more_horiz_rounded, 'More'), selected: false, vertical: vertical, onTap: onMore),
    ];

    final bar = ConstrainedBox(
      constraints: vertical
          ? const BoxConstraints(minWidth: 92, maxWidth: 92, maxHeight: 520)
          : const BoxConstraints(minHeight: 76, maxHeight: 76),
      child: Container(
        width: vertical ? 92 : double.infinity,
        height: vertical ? null : 76,
        decoration: BoxDecoration(
          color: const Color(0xF20E0E0E),
          border: Border.all(color: Colors.white.withValues(alpha: .07)),
          borderRadius: floating ? BorderRadius.circular(24) : BorderRadius.zero,
          boxShadow: const [BoxShadow(blurRadius: 28, offset: Offset(0, -8), color: Color(0x66000000))],
        ),
        child: vertical
            ? SingleChildScrollView(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4), child: Column(mainAxisSize: MainAxisSize.min, children: actions))
            : SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7), child: Row(mainAxisSize: MainAxisSize.min, children: actions)),
      ),
    );
    return SafeArea(top: false, left: false, right: false, bottom: !floating, child: bar);
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
  final bool showBadge;
  final bool vertical;
  final VoidCallback onTap;
  const _NavButton({required this.data, required this.selected, required this.onTap, this.showBadge = false, this.vertical = false});
  @override State<_NavButton> createState() => _NavButtonState();
}
class _NavButtonState extends State<_NavButton> {
  bool pressed = false;
  @override
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
                  Icon(active ? widget.data.selectedIcon : widget.data.icon, size: 22, color: active ? Colors.white : Colors.white70),
                  if (widget.showBadge) Positioned(right: -4, top: -2, child: Container(width: 7, height: 7, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle))),
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
  });

  @override
  Widget build(BuildContext context) {
    return _PremiumSheet(
      title: 'More',
      subtitle: 'Manage your streaming service',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetAction(
            icon: Icons.library_add_outlined,
            title: 'Add Movie or Show',
            subtitle: 'Import media into your library',
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
            subtitle: 'Recommendations, collections, achievements and recaps',
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
            subtitle: 'Downloads, casting, HDMI and Bluetooth guidance',
            onTap: onDevices,
          ),
          _SheetAction(
            icon: Icons.rocket_launch_rounded,
            title: '34-Feature Roadmap',
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

  const HomeScreen({super.key, this.onRefresh});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _heroController;

  @override
  void initState() {
    super.initState();
    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _heroController.dispose();
    super.dispose();
  }

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

    // Deliberately keep the empty home completely clean. All management
    // actions live in the navigation bar's More menu.
    if (library.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF070707),
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
      backgroundColor: const Color(0xFF070707),
      body: RefreshIndicator(
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
              title: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: const LinearGradient(
                        colors: [Colors.red, Color(0xFF8B0000)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 23),
                  ),
                  const SizedBox(width: 11),
                  const Text(
                    'STREAM',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: 1.6),
                  ),
                ],
              ),
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
    default: return const [];
  }
  if (!enabled || items.isEmpty) return const [];
  return [
    SliverToBoxAdapter(child: _PremiumSectionHeader(title: section, subtitle: subtitle)),
    SliverToBoxAdapter(child: MediaHorizontalList(media: items)),
  ];
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
  ActivityButton({super.key});

  final controller = AppController.instance;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Activity',
      icon: Stack(
        children: [
          const Icon(
            Icons.notifications_outlined,
          ),
          if (controller.activity.isNotEmpty)
            Positioned(
              right: 0,
              top: 0,
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
      onPressed: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.grey.shade900,
          builder: (context) {
            final activity =
                AppController.instance.activity;

            return SafeArea(
              child: SizedBox(
                height:
                    MediaQuery.of(context).size.height * .7,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Activity',
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Expanded(
                        child: activity.isEmpty
                            ? const Center(
                                child: Text(
                                  'No activity yet.',
                                ),
                              )
                            : ListView.builder(
                                itemCount:
                                    activity.length,
                                itemBuilder: (_, index) {
                                  final event =
                                      activity[index];

                                  return ListTile(
                                    leading:
                                        const CircleAvatar(
                                      child: Icon(
                                        Icons.notifications,
                                      ),
                                    ),
                                    title: Text(
                                      event.title,
                                    ),
                                    subtitle: Text(
                                      event.action,
                                    ),
                                    trailing: Text(
                                      _formatActivityTime(
                                        event.timestamp,
                                      ),
                                      style: TextStyle(
                                        color: Colors
                                            .grey
                                            .shade500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatActivityTime(
    DateTime timestamp,
  ) {
    final difference =
        DateTime.now().difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'Just now';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    }

    return '${timestamp.month}/'
        '${timestamp.day}/'
        '${timestamp.year}';
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
  double progress = 0;
  String statusMessage = 'ARM is always enabled for disc imports.';
  String? jobId;
  String? driveId;

  Map<String, dynamic>? reviewJob;
  Map<String, dynamic>? verification;

  Timer? _pollTimer;

  @override
  void dispose() {
    _pollTimer?.cancel();
    titleController.dispose();
    yearController.dispose();
    posterController.dispose();
    trailerController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

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

  void _beginPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _pollArmJob(),
    );
    _pollArmJob();
  }

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

  void _prepareReview(Map<String, dynamic> job) {
    final verificationData = job['verification'];
    final discType = job['discType']?.toString();
    final region = job['region']?.toString();

    setState(() {
      importing = false;
      verification = verificationData is Map
          ? Map<String, dynamic>.from(verificationData)
          : null;
      verificationPassed = verification?['passed'] == true;
      titleController.text = job['title']?.toString() ?? '';
      selectedType = _normalizeMediaType(job['mediaType']?.toString());
      selectedDiscType =
          discTypes.contains(discType) ? discType! : selectedDiscType;
      selectedRegion =
          regions.contains(region) ? region! : selectedRegion;
      statusMessage = verificationPassed
          ? 'Disc verified. Review the metadata, then click ADD TO LIBRARY.'
          : 'Disc rejected. It cannot be added to your library.';
    });
  }

  String _normalizeMediaType(String? value) {
    final v = (value ?? '').toLowerCase();
    if (v.contains('tv') || v.contains('series') || v.contains('show')) {
      return 'tvShow';
    }
    return 'movie';
  }

  List<String> _strings(dynamic value) {
    if (value is! List) return <String>[];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  void _addVerifiedDiscToLibrary() {
    if (!verificationPassed || reviewJob == null) return;

    final title = titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A title is required before adding the disc.')),
      );
      return;
    }

    final job = reviewJob!;
    final year = int.tryParse(yearController.text.trim());
    final poster = posterController.text.trim();
    final trailer = trailerController.text.trim();

    final media = MediaItem(
      id: 'arm_${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      type: selectedType,
      imageUrl: poster.isEmpty ? job['posterUrl']?.toString() : poster,
      description: descriptionController.text.trim().isEmpty
          ? job['description']?.toString() ??
              DescriptionGenerator.movie(title: title, year: year)
          : descriptionController.text.trim(),
      releaseYear: year ??
          (job['year'] is num
              ? (job['year'] as num).toInt()
              : int.tryParse(job['year']?.toString() ?? '')),
      trailerUrl: trailer.isEmpty ? job['trailerUrl']?.toString() : trailer,
      discType: selectedDiscType,
      discRegion: selectedRegion,
      actors: _strings(job['actors']),
      directors: _strings(job['directors']),
      writers: _strings(job['writers']),
      music: _strings(job['music']),
      genres: _strings(job['genres']),
      tags: _strings(job['tags']),
      chapters: _strings(job['chapters']),
      audioTracks: _strings(job['audioTracks']),
      subtitles: _strings(job['subtitles']),
      extras: _strings(job['extras']),
    );

    AppController.instance.addToLibrary(media);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$title added to your library. Actors, directors, music, and other metadata were cataloged.',
        ),
      ),
    );

    Navigator.pop(context, true);
  }

  @override
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trailers'),
      ),
      body: const Center(
        child: Text(
          'Trailers will appear here when trailer metadata is added to MediaItem.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// ============================================================
// MUSIC
// ============================================================

class MusicScreen extends StatelessWidget {
  const MusicScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Music'),
      ),
      body: const Center(
        child: Text(
          'Music will appear here when music metadata is added to MediaItem.',
        ),
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
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  @override
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
  void initState() {
    super.initState();
    loadGroupData();
  }

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

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

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void sendMessage() {
    final text = messageController.text.trim();
    if (text.isEmpty) return;
    AppController.instance.sendGroupMessage(message: text);
    messageController.clear();
    setState(() {});
  }

  Future<void> openRecommendationDialog() async {
    await showDialog(context: context, builder: (_) => const AddGroupRecommendationDialog());
    if (mounted) setState(() {});
  }

  Future<void> refreshRecommendations() async {
    try {
      await AppController.instance.loadGroupRecommendations();
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) _showMessage('Unable to refresh recommendations: $error');
    }
  }

  Future<void> refreshWishlist() async {
    try {
      await AppController.instance.loadGroupWishlist();
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) _showMessage('Unable to refresh wishlist: $error');
    }
  }

  @override
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
                    ...controller.groupMessages.map((message) => _GroupMessageBubble(sender: message.sender, message: message.message, time: _formatTime(message.timestamp))),
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

  String _formatTime(DateTime timestamp) => '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
}

class _GroupSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? action;
  const _GroupSectionHeader({required this.title, required this.icon, this.action});
  @override
  Widget build(BuildContext context) => Row(children: [Icon(icon, size: 20, color: Colors.white70), const SizedBox(width: 9), Expanded(child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))), if (action != null) action!]);
}

class _SmallHeaderButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SmallHeaderButton({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => TextButton.icon(onPressed: onTap, icon: Icon(icon, size: 17), label: Text(label), style: TextButton.styleFrom(foregroundColor: Colors.white));
}

class _GroupEmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _GroupEmptyCard({required this.icon, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .035), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: .06))), child: Column(children: [Icon(icon, size: 42, color: Colors.white38), const SizedBox(height: 10), Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white38, fontSize: 12))]));
}

class _GroupMessageBubble extends StatelessWidget {
  final String sender;
  final String message;
  final String time;
  const _GroupMessageBubble({required this.sender, required this.message, required this.time});
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .045), borderRadius: BorderRadius.circular(17)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const CircleAvatar(radius: 20, child: Icon(Icons.person_rounded, size: 20)), const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text(sender, style: const TextStyle(fontWeight: FontWeight.w800))), Text(time, style: const TextStyle(color: Colors.white38, fontSize: 11))]), const SizedBox(height: 4), Text(message, style: const TextStyle(color: Colors.white70, height: 1.35))]))]));
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
  void initState() {
    super.initState();
    _updateRemaining();
    _startCountdown();
  }

  @override
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
  void dispose() {
    countdownTimer?.cancel();
    super.dispose();
  }

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

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
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
  void initState() {
    super.initState();
    loadWishlist();
  }

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