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
            final type =
                media.type.toLowerCase();

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

  String selectedType = 'movie';

  bool connectArm = false;
  bool importing = false;
  double progress = 0;

  @override
  void dispose() {
    titleController.dispose();
    yearController.dispose();
    posterController.dispose();
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
// PLAYER
// ============================================================

class PlayerScreen extends StatefulWidget {
  final MediaItem media;

  const PlayerScreen({
    super.key,
    required this.media,
  });

  @override
  State<PlayerScreen> createState() =>
      _PlayerScreenState();
}

class _PlayerScreenState
    extends State<PlayerScreen> {
  late double position;
  bool videoFinished = false;

  @override
  void initState() {
    super.initState();

    position = AppController.instance
        .getPlaybackProgress(
          widget.media.id,
        );

    position =
        position.clamp(0.0, 1.0).toDouble();

    videoFinished = position >= 1.0;
  }

  void finishVideo() {
    if (videoFinished) return;

    setState(() {
      videoFinished = true;
      position = 1.0;
    });

    final controller =
        AppController.instance;

    controller.updatePlaybackProgress(
      widget.media.id,
      1.0,
    );

    controller.finishWatching(
      widget.media,
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.media;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(media.title),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.play_circle_fill,
                    size: 100,
                    color: Colors.white,
                  ),

                  const SizedBox(height: 20),

                  Text(
                    'PLAYER',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    media.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          Slider(
            value: position,
            min: 0,
            max: 1,
            onChanged: videoFinished
                ? null
                : (value) {
                    setState(() {
                      position = value;
                    });

                    AppController.instance
                        .updatePlaybackProgress(
                      media.id,
                      value,
                    );

                    if (value >= .999) {
                      finishVideo();
                    }
                  },
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(
                left: 15,
                right: 15,
                bottom: 15,
              ),
              child: Wrap(
                alignment:
                    WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Audio and subtitle tracks are not available for this media item.',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.language,
                    ),
                    label: const Text(
                      'Audio & Subtitles',
                    ),
                  ),

                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              GroupWatchDialog(
                            media: media,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.groups,
                    ),
                    label: const Text(
                      'GROUP SHARE',
                    ),
                  ),

                  OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'No extras are available for this media item.',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.movie_filter,
                    ),
                    label: const Text(
                      'EXTRAS',
                    ),
                  ),
                ],
              ),
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
          textAlign: TextAlign.center,
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
              await controller
                  .logoutFromBackend();

              if (!mounted) return;

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

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  void sendMessage() {
    final text =
        messageController.text.trim();

    if (text.isEmpty) return;

    AppController.instance.sendGroupMessage(
      message: text,
    );

    messageController.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller =
        AppController.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Group'),
      ),
      body: Column(
        children: [
          Expanded(
            child: controller
                    .groupMessages
                    .isEmpty
                ? const Center(
                    child: Text(
                      'No group messages yet.',
                    ),
                  )
                : ListView.builder(
                    padding:
                        const EdgeInsets.all(15),
                    itemCount: controller
                        .groupMessages
                        .length,
                    itemBuilder: (_, index) {
                      final message =
                          controller
                              .groupMessages[index];

                      return ListTile(
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
                            color:
                                Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      );
                    },
                  ),
          ),

          Padding(
            padding: const EdgeInsets.all(10),
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
                  onPressed: sendMessage,
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(10),
            child: OutlinedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) =>
                      const WishlistDialog(),
                );
              },
              icon: const Icon(
                Icons.favorite_outline,
              ),
              label: const Text(
                'WISHLIST',
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
        timestamp.hour.toString().padLeft(2, '0');

    final minute =
        timestamp.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }
}

// ============================================================
// WISHLIST
// ============================================================

class WishlistDialog extends StatefulWidget {
  const WishlistDialog({super.key});

  @override
  State<WishlistDialog> createState() =>
      _WishlistDialogState();
}

class _WishlistDialogState
    extends State<WishlistDialog> {
  final titleController =
      TextEditingController();

  @override
  void dispose() {
    titleController.dispose();
    super.dispose();
  }

  void addWishlistItem() {
    final title =
        titleController.text.trim();

    if (title.isEmpty) {
      return;
    }

    final media = MediaItem(
      id: DateTime.now()
          .microsecondsSinceEpoch
          .toString(),
      title: title,
      type: 'movie',
    );

    AppController.instance.addToWishlist(
      media,
    );

    titleController.clear();
    setState(() {});
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
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (controller.wishlist.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No wishlist items.',
                ),
              ),

            ...controller.wishlist.map(
              (item) => ListTile(
                leading: const Icon(
                  Icons.movie_outlined,
                ),
                title: Text(
                  item.title,
                ),
                subtitle: Text(
                  item.type,
                ),
                trailing: IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                  ),
                  onPressed: () {
                    controller
                        .removeFromWishlist(
                      item.id,
                    );
                    setState(() {});
                  },
                ),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller:
                  titleController,
              onSubmitted: (_) =>
                  addWishlistItem(),
              decoration:
                  const InputDecoration(
                labelText:
                    'Movie or show suggestion',
                border:
                    OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.pop(context),
          child: const Text(
            'CLOSE',
          ),
        ),

        ElevatedButton(
          onPressed: addWishlistItem,
          child: const Text(
            'ADD',
          ),
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

                controller
                    .createGroupWatchSession(
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