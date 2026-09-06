import 'dart:async';
import 'package:flutter/material.dart';
import 'app_core.dart';
import 'signup.dart';
import 'movies.dart';
import 'series.dart';
import 'smart_search.dart';
import 'hollywood.dart';
import 'details.dart';

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

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const MainScreen(),
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
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        onRefresh: () => setState(() {}),
      ),
      const MoviesScreen(),
      const SeriesScreen(),
      const ActorsScreen(),
      const MusicScreen(),
      const TrailersScreen(),
      const SmartSearchScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: pages[selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.movie_outlined),
            selectedIcon: Icon(Icons.movie),
            label: 'Movies',
          ),
          NavigationDestination(
            icon: Icon(Icons.tv_outlined),
            selectedIcon: Icon(Icons.tv),
            label: 'TV Shows',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Actors',
          ),
          NavigationDestination(
            icon: Icon(Icons.music_note_outlined),
            selectedIcon: Icon(Icons.music_note),
            label: 'Music',
          ),
          NavigationDestination(
            icon: Icon(Icons.play_arrow_outlined),
            selectedIcon: Icon(Icons.play_arrow),
            label: 'Trailers',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_circle_outlined),
            selectedIcon: Icon(Icons.account_circle),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ============================================================
// HOME
// ============================================================

class HomeScreen extends StatelessWidget {
  final VoidCallback? onRefresh;

  const HomeScreen({
    super.key,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final controller = AppController.instance;
    final profile = controller.currentProfile;

    if (profile == null) {
      return const Scaffold(
        body: Center(
          child: Text('No profile selected.'),
        ),
      );
    }

    final library = controller.library;

    final movies = library
        .where(
          (media) =>
              media.type.toLowerCase() == 'movie',
        )
        .toList();

    final tvShows = library
        .where(
          (media) {
            final type = media.type.toLowerCase();

            return type == 'tvshow' ||
                type == 'tv_show' ||
                type == 'tv show';
          },
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Streaming Service',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          ActivityButton(),
          IconButton(
            tooltip: 'Group',
            icon: const Icon(Icons.groups),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const GroupHubScreen(),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'profiles') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const ProfileScreen(),
                  ),
                );
              }

              if (value == 'import') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const ImportMediaScreen(),
                  ),
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem<String>(
                value: 'profiles',
                child: Text('Profiles'),
              ),
              PopupMenuItem<String>(
                value: 'import',
                child: Text('Add Movie or Show'),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          onRefresh?.call();

          if (controller.backendApi.isAuthenticated) {
            await controller.loadRecommendations();
            await controller.loadGroupWishlist();
            await controller.loadGroupRecommendations();
          }
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Welcome, ${profile.name}',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your personal library',
              style: TextStyle(
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 25),
            if (library.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.video_library_outlined,
                        size: 70,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        'Your library is empty',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Add your own movies and TV shows to build your personal streaming library.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const ImportMediaScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: const Text(
                          'Add Movie or Show',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (controller.watched.isNotEmpty) ...[
              const SectionTitle(
                title: 'Recently Watched',
              ),
              MediaHorizontalList(
                media: controller.watched,
              ),
              const SizedBox(height: 25),
            ],
            if (movies.isNotEmpty) ...[
              const SectionTitle(
                title: 'Movies',
              ),
              MediaHorizontalList(
                media: movies,
              ),
              const SizedBox(height: 25),
            ],
            if (tvShows.isNotEmpty) ...[
              const SectionTitle(
                title: 'TV Shows',
              ),
              MediaHorizontalList(
                media: tvShows,
              ),
              const SizedBox(height: 25),
            ],
            if (library.isNotEmpty) ...[
              const SectionTitle(
                title: 'My Library',
              ),
              MediaHorizontalList(
                media: library,
              ),
              const SizedBox(height: 25),
            ],
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const ImportMediaScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text(
                'Add Movie or Show',
              ),
            ),
            const SizedBox(height: 15),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const GroupHubScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.groups),
              label: const Text(
                'Group Chat & Watch Together',
              ),
            ),
          ],
        ),
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
  State<ImportMediaScreen> createState() =>
      _ImportMediaScreenState();
}

class _ImportMediaScreenState
    extends State<ImportMediaScreen> {
  final titleController = TextEditingController();
  final yearController = TextEditingController();
  final posterController = TextEditingController();

  // Trailer URL entered during manual import.
  final trailerController = TextEditingController();

  String selectedType = 'movie';
  bool connectArm = false;
  bool importing = false;
  double progress = 0;

  @override
  void dispose() {
    titleController.dispose();
    yearController.dispose();
    posterController.dispose();
    trailerController.dispose();
    super.dispose();
  }

  Future<void> simulateImport() async {
    if (importing) return;

    setState(() {
      importing = true;
      progress = 0;
    });

    for (int i = 1; i <= 20; i++) {
      await Future.delayed(
        const Duration(milliseconds: 150),
      );

      if (!mounted) return;

      setState(() {
        progress = i / 20;
      });
    }

    if (!mounted) return;

    setState(() {
      importing = false;
    });

    addManualMedia();
  }

  void addManualMedia() {
    final title = titleController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter a movie or show title.',
          ),
        ),
      );
      return;
    }

    final yearText =
        yearController.text.trim();

    final year = yearText.isEmpty
        ? null
        : int.tryParse(yearText);

    final posterText =
        posterController.text.trim();

    final trailerText =
        trailerController.text.trim();

    final media = MediaItem(
      id: DateTime.now()
          .microsecondsSinceEpoch
          .toString(),
      title: title,
      type: selectedType,
      imageUrl:
          posterText.isEmpty
              ? null
              : posterText,
      description:
          'Imported into your personal library.',
      releaseYear: year,
      trailerUrl:
          trailerText.isEmpty
              ? null
              : trailerText,
    );

    AppController.instance.addToLibrary(
      media,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$title added to your library.',
        ),
      ),
    );

    titleController.clear();
    yearController.clear();
    posterController.clear();
    trailerController.clear();

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller =
        AppController.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add Movie or Show',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Automatic Disc Import',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Connect this app to your home server and ARM to detect and import your own discs.',
                  ),
                  SwitchListTile(
                    contentPadding:
                        EdgeInsets.zero,
                    title: const Text(
                      'Connect to ARM',
                    ),
                    subtitle: Text(
                      connectArm
                          ? 'ARM connection enabled'
                          : 'Not connected',
                    ),
                    value: connectArm,
                    onChanged: (value) {
                      setState(() {
                        connectArm = value;
                      });
                    },
                  ),
                  const ListTile(
                    contentPadding:
                        EdgeInsets.zero,
                    leading: Icon(
                      Icons.disc_full,
                    ),
                    title: Text(
                      'Optical Drive',
                    ),
                    subtitle: Text(
                      'Waiting for home-server connection',
                    ),
                  ),
                  if (importing) ...[
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: progress,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Importing '
                      '${(progress * 100).round()}%',
                    ),
                  ],
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: importing
                          ? null
                          : simulateImport,
                      icon: const Icon(
                        Icons.disc_full,
                      ),
                      label: const Text(
                        'START AUTOMATIC RIP',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 25),
          const Text(
            'Manual Import / Metadata',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          DropdownButtonFormField<String>(
            initialValue: selectedType,
            decoration: const InputDecoration(
              labelText: 'Type',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem<String>(
                value: 'movie',
                child: Text('Movie'),
              ),
              DropdownMenuItem<String>(
                value: 'tvShow',
                child: Text('TV Show'),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;

              setState(() {
                selectedType = value;
              });
            },
          ),
          const SizedBox(height: 15),
          TextField(
            controller: titleController,
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: yearController,
            keyboardType:
                TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Year',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: posterController,
            decoration: const InputDecoration(
              labelText:
                  'Poster URL (optional)',
              border: OutlineInputBorder(),
            ),
          ),

          // Trailer URL.
          const SizedBox(height: 15),
          TextField(
            controller: trailerController,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Trailer URL (optional)',
              hintText: 'Paste YouTube trailer URL...',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: addManualMedia,
              child: const Text(
                'ADD TO MY LIBRARY',
              ),
            ),
          ),
          const SizedBox(height: 30),
          Text(
            'Current profile: '
            '${controller.currentProfile?.name ?? 'None'}',
            style: TextStyle(
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
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
  State<ProfileScreen> createState() =>
      _ProfileScreenState();
}

class _ProfileScreenState
    extends State<ProfileScreen> {
  final controller =
      AppController.instance;

  @override
  Widget build(BuildContext context) {
    final account =
        controller.currentAccount;

    if (account == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'No account is logged in.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profiles'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Profiles '
            '${account.profiles.length}/7',
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Up to 7 profiles with no extra charge.',
          ),
          const SizedBox(height: 20),
          ...account.profiles.map(
            (profile) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage:
                      profile.avatarUrl == null
                          ? null
                          : NetworkImage(
                              profile.avatarUrl!,
                            ),
                  child:
                      profile.avatarUrl == null
                          ? const Icon(
                              Icons.person,
                            )
                          : null,
                ),
                title: Text(profile.name),
                subtitle: Text(
                  profile.id ==
                          controller
                              .currentProfile
                              ?.id
                      ? 'Current profile'
                      : 'Profile',
                ),
                trailing:
                    PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'switch') {
                      controller.switchProfile(
                        profile.id,
                      );
                      setState(() {});
                    }

                    if (value == 'delete') {
                      controller.removeProfile(
                        profile.id,
                      );
                      setState(() {});
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem<String>(
                      value: 'switch',
                      child: Text('Switch'),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 15),
          if (account.profiles.length < 7)
            ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) =>
                      const AddProfileDialog(),
                ).then((_) {
                  setState(() {});
                });
              },
              icon: const Icon(Icons.add),
              label: const Text(
                'ADD PROFILE',
              ),
            ),
          const SizedBox(height: 30),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.workspace_premium,
              ),
              title: Text(
                account.subscription.plan.name
                    .toUpperCase(),
              ),
              subtitle: Text(
                account.subscription.status.name,
              ),
              trailing: TextButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) =>
                        const SubscribeDialog(),
                  );
                },
                child: const Text(
                  'Manage',
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () async {
              await controller.logoutFromBackend();

              if (!context.mounted) return;

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const LoginScreen(),
                ),
                (_) => false,
              );
            },
            child: const Text(
              'LOG OUT',
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ADD PROFILE
// ============================================================

class AddProfileDialog extends StatefulWidget {
  const AddProfileDialog({super.key});

  @override
  State<AddProfileDialog> createState() =>
      _AddProfileDialogState();
}

class _AddProfileDialogState
    extends State<AddProfileDialog> {
  final nameController =
      TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Add Profile',
      ),
      content: TextField(
        controller: nameController,
        decoration: const InputDecoration(
          labelText: 'Profile name',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text(
            'CANCEL',
          ),
        ),
        ElevatedButton(
          onPressed: () {
            final name =
                nameController.text.trim();

            if (name.isEmpty) return;

            AppController.instance.addProfile(
              name,
            );

            Navigator.pop(context);
          },
          child: const Text(
            'ADD',
          ),
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
  State<GroupHubScreen> createState() =>
      _GroupHubScreenState();
}

class _GroupHubScreenState
    extends State<GroupHubScreen> {
  final messageController =
      TextEditingController();

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
      await Future.wait([
        controller.loadGroupWishlist(),
        controller.loadGroupRecommendations(),
      ]);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to load group data: $error',
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

  void sendMessage() {
    final text =
        messageController.text.trim();

    if (text.isEmpty) {
      return;
    }

    AppController.instance.sendGroupMessage(
      message: text,
    );

    messageController.clear();

    setState(() {});
  }

  Future<void> openRecommendationDialog() async {
    await showDialog(
      context: context,
      builder: (_) =>
          const AddGroupRecommendationDialog(),
    );

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> refreshRecommendations() async {
    final controller =
        AppController.instance;

    try {
      await controller.loadGroupRecommendations();

      if (mounted) {
        setState(() {});
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to refresh recommendations: $error',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller =
        AppController.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Group'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed:
                loading ? null : loadGroupData,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: loadGroupData,
              child: ListView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.all(15),
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Group Chat',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed:
                            openRecommendationDialog,
                        icon: const Icon(
                          Icons.movie_outlined,
                        ),
                        label: const Text(
                          'RECOMMEND',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  if (controller
                      .groupRecommendations
                      .isNotEmpty) ...[
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Group Recommendations',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip:
                              'Refresh recommendations',
                          icon: const Icon(
                            Icons.refresh,
                          ),
                          onPressed:
                              refreshRecommendations,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...controller
                        .groupRecommendations
                        .map(
                          (recommendation) =>
                              GroupRecommendationCard(
                            recommendation:
                                recommendation,
                            onChanged: () {
                              if (mounted) {
                                setState(() {});
                              }
                            },
                          ),
                        ),
                    const SizedBox(height: 20),
                  ],
                  if (controller
                      .groupMessages
                      .isEmpty)
                    Card(
                      child: Padding(
                        padding:
                            const EdgeInsets.all(20),
                        child: Text(
                          'No group messages yet.',
                          style: TextStyle(
                            color:
                                Colors.grey.shade400,
                          ),
                        ),
                      ),
                    )
                  else
                    ...controller
                        .groupMessages
                        .map(
                          (message) =>
                              ListTile(
                            contentPadding:
                                EdgeInsets.zero,
                            leading:
                                const CircleAvatar(
                              child: Icon(
                                Icons.person,
                              ),
                            ),
                            title: Text(
                              message.sender,
                            ),
                            subtitle: Text(
                              message.message,
                            ),
                            trailing: Text(
                              _formatTime(
                                message.timestamp,
                              ),
                              style: TextStyle(
                                color: Colors
                                    .grey
                                    .shade500,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                  const SizedBox(height: 25),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Shared Group Wishlist',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip:
                            'Refresh wishlist',
                        icon: const Icon(
                          Icons.refresh,
                        ),
                        onPressed: () async {
                          try {
                            await controller
                                .loadGroupWishlist();

                            if (context.mounted) {
                              setState(() {});
                            }
                          } catch (error) {
                            if (!context.mounted) {
                              return;
                            }

                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Unable to load wishlist: $error',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (controller
                      .wishlist
                      .isEmpty)
                    Card(
                      child: Padding(
                        padding:
                            const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.favorite_border,
                              size: 45,
                            ),
                            const SizedBox(
                              height: 10,
                            ),
                            const Text(
                              'The group wishlist is empty.',
                              style: TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                            const SizedBox(
                              height: 5,
                            ),
                            Text(
                              'Group wishlist items will appear here.',
                              textAlign:
                                  TextAlign.center,
                              style: TextStyle(
                                color: Colors
                                    .grey
                                    .shade400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...controller
                        .wishlist
                        .map(
                          (item) =>
                              GroupWishlistCard(
                            item: item,
                            onChanged: () {
                              setState(() {});
                            },
                          ),
                        ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller:
                          messageController,
                      onSubmitted: (_) =>
                          sendMessage(),
                      decoration:
                          const InputDecoration(
                        hintText:
                            'Message the group...',
                        border:
                            OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(
                      Icons.send,
                    ),
                    onPressed:
                        sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(
    DateTime timestamp,
  ) {
    final hour =
        timestamp.hour
            .toString()
            .padLeft(2, '0');

    final minute =
        timestamp.minute
            .toString()
            .padLeft(2, '0');

    return '$hour:$minute';
  }
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

    final participants =
        _stringSet(
      widget.recommendation['activeParticipants'],
    );

    if (participants.isNotEmpty &&
        !participants.contains(
          currentProfile.id,
        )) {
      _showMessage(
        'Your profile is not eligible to vote on this recommendation.',
      );
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

    final participants =
        _stringSet(
      recommendation['activeParticipants'],
    );

    final isParticipant =
        currentProfile != null &&
        (participants.isEmpty ||
            participants.contains(
              currentProfile.id,
            ));

    final canVote =
        status == 'voting' &&
        remaining > Duration.zero &&
        currentProfile != null &&
        isParticipant &&
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
              else if (!isParticipant &&
                  currentProfile != null)
                Text(
                  'Your profile is not eligible to vote.',
                  style: TextStyle(
                    color:
                        Colors.grey.shade400,
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

class GroupWatchDialog
    extends StatelessWidget {
  final MediaItem media;

  const GroupWatchDialog({
    super.key,
    required this.media,
  });

  @override
  Widget build(BuildContext context) {
    final controller =
        AppController.instance;

    final account =
        controller.currentAccount;

    final currentProfile =
        controller.currentProfile;

    if (account == null ||
        currentProfile == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'No account or profile selected.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Group Watch',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Watch ${media.title} together',
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            const Text(
              'Invite the other profiles to watch together.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 25),
            ...account.profiles
                .where(
                  (profile) =>
                      profile.id !=
                      currentProfile.id,
                )
                .map(
                  (profile) => ListTile(
                    leading:
                        const CircleAvatar(
                      child: Icon(
                        Icons.person,
                      ),
                    ),
                    title: Text(
                      profile.name,
                    ),
                    trailing:
                        const Text('INVITE'),
                  ),
                ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          GroupWatchPreferencesScreen(
                        media: media,
                      ),
                    ),
                  );
                },
                child: const Text(
                  'CONTINUE',
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
// GROUP WATCH PREFERENCES
// ============================================================

class GroupWatchPreferencesScreen
    extends StatefulWidget {
  final MediaItem media;

  const GroupWatchPreferencesScreen({
    super.key,
    required this.media,
  });

  @override
  State<GroupWatchPreferencesScreen>
      createState() =>
          _GroupWatchPreferencesScreenState();
}

class _GroupWatchPreferencesScreenState
    extends State<GroupWatchPreferencesScreen> {
  bool subtitlesEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Group Watch Preferences',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            widget.media.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 25),
          const ListTile(
            leading: Icon(
              Icons.language,
            ),
            title: Text(
              'Audio',
            ),
            subtitle: Text(
              'Original audio',
            ),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            title: const Text(
              'Subtitles',
            ),
            value: subtitlesEnabled,
            onChanged: (value) {
              setState(() {
                subtitlesEnabled =
                    value;
              });
            },
          ),
          const SizedBox(height: 35),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                final controller =
                    AppController.instance;

                controller.createGroupWatchSession(
                  widget.media,
                );

                Navigator.pop(context);
              },
              child: const Text(
                'START GROUP WATCH',
              ),
            ),
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

Set<String> _stringSet(
  dynamic value,
) {
  if (value is! Iterable) {
    return <String>{};
  }

  return value
      .map(
        (item) => item.toString(),
      )
      .where(
        (item) => item.isNotEmpty,
      )
      .toSet();
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