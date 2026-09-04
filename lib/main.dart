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

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void login() {
    final username = usernameController.text.trim();
    final password = passwordController.text;

    final controller = AppController.instance;

    final success = controller.login(
      username,
      password,
    );

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Incorrect username/email or password.',
          ),
        ),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const MainScreen(),
      ),
    );
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
                  decoration: const InputDecoration(
                    labelText: 'Username or Email',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: passwordController,
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
                      onPressed: () {
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
                    onPressed: login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text(
                      'LOGIN',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SignupScreen(),
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

  final controller = AppController.instance;

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
      return const Center(
        child: Text('No profile selected.'),
      );
    }

    final library = profile.library;

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
                  builder: (_) => const GroupHubScreen(),
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
                    builder: (_) => const ProfileScreen(),
                  ),
                );
              }

              if (value == 'import') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ImportMediaScreen(),
                  ),
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'profiles',
                child: Text('Profiles'),
              ),
              PopupMenuItem(
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
        },
        child: ListView(
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

            if (library.media.isEmpty)
              EmptyLibraryCard(
                onAddPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ImportMediaScreen(),
                    ),
                  );
                },
              ),

            if (library.continueWatching.isNotEmpty) ...[
              const SectionTitle(
                title: 'Continue Watching',
              ),
              MediaHorizontalList(
                media: library.continueWatching,
              ),
              const SizedBox(height: 25),
            ],

            if (library.recentlyWatched.isNotEmpty) ...[
              const SectionTitle(
                title: 'Recently Watched',
              ),
              MediaHorizontalList(
                media: library.recentlyWatched,
              ),
              const SizedBox(height: 25),
            ],

            if (library.movies.isNotEmpty) ...[
              const SectionTitle(
                title: 'Movies',
              ),
              MediaHorizontalList(
                media: library.movies,
              ),
              const SizedBox(height: 25),
            ],

            if (library.tvShows.isNotEmpty) ...[
              const SectionTitle(
                title: 'TV Shows',
              ),
              MediaHorizontalList(
                media: library.tvShows,
              ),
              const SizedBox(height: 25),
            ],

            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ImportMediaScreen(),
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
                    builder: (_) => const GroupHubScreen(),
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
          const Icon(Icons.notifications_outlined),
          if (controller.activityFeed.isNotEmpty)
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
          builder: (_) => const ActivityPanel(),
        );
      },
    );
  }
}

// ============================================================
// ACTIVITY PANEL
// ============================================================

class ActivityPanel extends StatelessWidget {
  const ActivityPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppController.instance;

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * .7,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                child: controller.activityFeed.isEmpty
                    ? const Center(
                        child: Text(
                          'No activity yet.',
                        ),
                      )
                    : ListView.builder(
                        itemCount:
                            controller.activityFeed.length,
                        itemBuilder: (_, index) {
                          final event =
                              controller.activityFeed[index];

                          return ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.person),
                            ),
                            title: Text(event.message),
                            subtitle: Text(
                              event.profileName,
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
  }
}

// ============================================================
// EMPTY LIBRARY
// ============================================================

class EmptyLibraryCard extends StatelessWidget {
  final VoidCallback onAddPressed;

  const EmptyLibraryCard({
    super.key,
    required this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
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
              onPressed: onAddPressed,
              icon: const Icon(Icons.add),
              label: const Text(
                'Add Movie or Show',
              ),
            ),
          ],
        ),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: media.posterUrl == null
                    ? Container(
                        width: double.infinity,
                        color: Colors.grey.shade900,
                        child: const Icon(
                          Icons.movie,
                          size: 45,
                        ),
                      )
                    : Image.network(
                        media.posterUrl!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          return Container(
                            color: Colors.grey.shade900,
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
          ],
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
  final trailerController = TextEditingController();

  MediaType selectedType = MediaType.movie;

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

    int? year;

    if (yearController.text.trim().isNotEmpty) {
      year = int.tryParse(
        yearController.text.trim(),
      );
    }

    final trailerId =
        trailerController.text.trim().isEmpty
            ? null
            : trailerController.text.trim();

    final media = MediaItem(
      id: DateTime.now()
          .microsecondsSinceEpoch
          .toString(),
      title: title,
      type: selectedType,
      year: year,
      posterUrl:
          posterController.text.trim().isEmpty
              ? null
              : posterController.text.trim(),
      description:
          'Imported into your personal library.',
      genre: [],
      tags: [],
      themes: [],
      cast: [],
      music: [],
      trailer: trailerId == null
          ? null
          : Trailer(
              youtubeVideoId: trailerId,
              title: '$title Trailer',
            ),
      audioTracks: [],
      subtitleTracks: [],
      chapters: [],
      extras: [],
    );

    AppController.instance.addMedia(media);

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
    final controller = AppController.instance;

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
                    contentPadding: EdgeInsets.zero,
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
                    contentPadding: EdgeInsets.zero,
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
                      'Importing ${(progress * 100).round()}%',
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

          DropdownButtonFormField<MediaType>(
            initialValue: selectedType,
            decoration: const InputDecoration(
              labelText: 'Type',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: MediaType.movie,
                child: Text('Movie'),
              ),
              DropdownMenuItem(
                value: MediaType.tvShow,
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
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Year',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 15),

          TextField(
            controller: posterController,
            decoration: const InputDecoration(
              labelText: 'Poster URL (optional)',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 15),

          TextField(
            controller: trailerController,
            decoration: const InputDecoration(
              labelText: 'YouTube Trailer ID (optional)',
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

class _PlayerScreenState extends State<PlayerScreen> {
  double position = 0;

  bool videoFinished = false;
  bool creditsStarted = false;
  bool autoplayCancelled = false;

  int autoplaySeconds = 10;

  Future<void> finishVideo() async {
    if (videoFinished) return;

    setState(() {
      videoFinished = true;
      position = 1;
    });

    final controller = AppController.instance;

    controller.updateProgress(
      widget.media,
      1,
    );

    if (!widget.media.isEpisode) {
      controller.markFinished(widget.media);
      return;
    }

    final nextEpisode =
        controller.getNextEpisode(widget.media);

    if (nextEpisode == null) {
      setState(() {
        creditsStarted = true;
      });
      return;
    }

    setState(() {
      creditsStarted = true;
      autoplayCancelled = false;
      autoplaySeconds = 10;
    });

    while (
        autoplaySeconds > 0 &&
        mounted &&
        !autoplayCancelled) {
      await Future.delayed(
        const Duration(seconds: 1),
      );

      if (!mounted || autoplayCancelled) {
        return;
      }

      setState(() {
        autoplaySeconds--;
      });
    }

    if (!mounted || autoplayCancelled) {
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          media: nextEpisode,
        ),
      ),
    );
  }

  void cancelAutoplay() {
    setState(() {
      autoplayCancelled = true;
    });
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
      body: Stack(
        children: [
          Column(
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
                    ],
                  ),
                ),
              ),

              Slider(
                value: position,
                onChanged: videoFinished
                    ? null
                    : (value) {
                        setState(() {
                          position = value;
                        });

                        if (value >= .999) {
                          finishVideo();
                        }
                      },
              ),

              SafeArea(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (_) =>
                              AudioSubtitleOptions(
                            media: media,
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
                      onPressed: () {},
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

              const SizedBox(height: 15),
            ],
          ),

          if (creditsStarted &&
              media.isEpisode &&
              !autoplayCancelled)
            Positioned(
              bottom: 120,
              left: 20,
              right: 20,
              child: NextEpisodeCountdown(
                seconds: autoplaySeconds,
                nextEpisode:
                    AppController.instance
                        .getNextEpisode(media),
                onCancel: cancelAutoplay,
                onPlayNow: () {
                  final next =
                      AppController.instance
                          .getNextEpisode(media);

                  if (next == null) return;

                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlayerScreen(
                        media: next,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// NEXT EPISODE COUNTDOWN
// ============================================================

class NextEpisodeCountdown extends StatelessWidget {
  final int seconds;
  final MediaItem? nextEpisode;
  final VoidCallback onCancel;
  final VoidCallback onPlayNow;

  const NextEpisodeCountdown({
    super.key,
    required this.seconds,
    required this.nextEpisode,
    required this.onCancel,
    required this.onPlayNow,
  });

  @override
  Widget build(BuildContext context) {
    if (nextEpisode == null) {
      return const SizedBox.shrink();
    }

    return Card(
      color: Colors.black87,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'Next episode in $seconds',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              nextEpisode!.title,
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    child: const Text(
                      'CANCEL',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onPlayNow,
                    child: const Text(
                      'PLAY NOW',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// AUDIO / SUBTITLE OPTIONS
// ============================================================

class AudioSubtitleOptions
    extends StatelessWidget {
  final MediaItem media;

  const AudioSubtitleOptions({
    super.key,
    required this.media,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          shrinkWrap: true,
          children: [
            const Text(
              'Audio',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            if (media.audioTracks.isEmpty)
              const ListTile(
                title: Text(
                  'No imported audio tracks.',
                ),
              ),

            ...media.audioTracks.map(
              (track) => ListTile(
                leading: const Icon(
                  Icons.volume_up,
                ),
                title: Text(
                  track.language,
                ),
                subtitle: Text(
                  track.format,
                ),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Subtitles',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            if (media.subtitleTracks.isEmpty)
              const ListTile(
                title: Text(
                  'No imported subtitle tracks.',
                ),
              ),

            ...media.subtitleTracks.map(
              (track) => ListTile(
                leading: const Icon(
                  Icons.subtitles,
                ),
                title: Text(
                  track.language,
                ),
                subtitle: Text(
                  track.sdh ? 'SDH' : 'Standard',
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
// TRAILERS
// ============================================================

class TrailersScreen extends StatelessWidget {
  const TrailersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile =
        AppController.instance.currentProfile;

    if (profile == null) {
      return const Scaffold(
        body: Center(
          child: Text('No profile selected.'),
        ),
      );
    }

    final trailers = profile.library.media
        .where((media) => media.trailer != null)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trailers'),
      ),
      body: trailers.isEmpty
          ? const Center(
              child: Text(
                'No trailers in your library yet.',
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: trailers.length,
              itemBuilder: (_, index) {
                final media = trailers[index];

                return Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.play_circle,
                      color: Colors.red,
                    ),
                    title: Text(
                      media.trailer!.title,
                    ),
                    subtitle: Text(
                      media.title,
                    ),
                    trailing: const Icon(
                      Icons.open_in_new,
                    ),
                    onTap: () {
                      openTrailer(
                        context,
                        media.trailer!,
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

void openTrailer(
  BuildContext context,
  Trailer trailer,
) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        'Open YouTube trailer: ${trailer.youtubeVideoId}',
      ),
    ),
  );
}

// ============================================================
// MUSIC
// ============================================================

class MusicScreen extends StatelessWidget {
  const MusicScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile =
        AppController.instance.currentProfile;

    if (profile == null) {
      return const Scaffold(
        body: Center(
          child: Text('No profile selected.'),
        ),
      );
    }

    final music = <MusicItem>[];

    for (final media in profile.library.media) {
      music.addAll(media.music);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Music'),
      ),
      body: music.isEmpty
          ? const Center(
              child: Text(
                'No music discovered yet.',
              ),
            )
          : ListView.builder(
              itemCount: music.length,
              itemBuilder: (_, index) {
                final item = music[index];

                return ListTile(
                  leading: const Icon(
                    Icons.music_note,
                  ),
                  title: Text(item.title),
                  subtitle: Text(
                    '${item.artistOrComposer} • '
                    '${item.type.name}',
                  ),
                );
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
  State<ProfileScreen> createState() =>
      _ProfileScreenState();
}

class _ProfileScreenState
    extends State<ProfileScreen> {
  final controller = AppController.instance;

  @override
  Widget build(BuildContext context) {
    final account = controller.account;

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
            'Profiles ${account.profiles.length}/7',
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
                  child: profile.avatarUrl == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(profile.name),
                subtitle: Text(
                  profile.id ==
                          controller.currentProfile?.id
                      ? 'Current profile'
                      : 'Profile',
                ),
                trailing: PopupMenuButton<String>(
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
                    PopupMenuItem(
                      value: 'switch',
                      child: Text('Switch'),
                    ),
                    PopupMenuItem(
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
                account.subscription?.plan.name
                        .toUpperCase() ??
                    'NO SUBSCRIPTION',
              ),
              subtitle: Text(
                account.subscription?.status.name ??
                    'None',
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
            onPressed: () {
              controller.logout();

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
  final nameController = TextEditingController();

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
    final controller = AppController.instance;

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
              '\$8 USD / month',
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
              '\$50 USD / year',
            ),
            subtitle: const Text(
              'Save \$46 compared with 12 monthly payments',
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
  final messageController = TextEditingController();

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppController.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Group',
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: controller.groupMessages.isEmpty
                ? const Center(
                    child: Text(
                      'No group messages yet.',
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(15),
                    itemCount:
                        controller.groupMessages.length,
                    itemBuilder: (_, index) {
                      final message =
                          controller.groupMessages[index];

                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person),
                        ),
                        title: Text(
                          message.profileId,
                        ),
                        subtitle: Text(
                          message.text,
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
                    controller: messageController,
                    decoration:
                        const InputDecoration(
                      hintText:
                          'Message the group...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    final text =
                        messageController.text.trim();

                    if (text.isEmpty) return;

                    controller.sendGroupMessage(
                      text,
                    );

                    messageController.clear();

                    setState(() {});
                  },
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
              icon: const Icon(Icons.how_to_vote),
              label: const Text(
                'WISHLIST & VOTING',
              ),
            ),
          ),
        ],
      ),
    );
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
  final titleController = TextEditingController();

  @override
  void dispose() {
    titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppController.instance;

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
                title: Text(item.title),
                subtitle: Text(
                  '${item.yesVotes} yes / '
                  '${item.noVotes} no',
                ),
                trailing: Wrap(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.thumb_up,
                      ),
                      onPressed: () {
                        controller.voteWishlist(
                          item.id,
                          true,
                        );
                        setState(() {});
                      },
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.thumb_down,
                      ),
                      onPressed: () {
                        controller.voteWishlist(
                          item.id,
                          false,
                        );
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText:
                    'Movie or show suggestion',
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
          onPressed: () {
            final title =
                titleController.text.trim();

            if (title.isEmpty) return;

            controller.addWishlistItem(
              title,
              MediaType.movie,
            );

            setState(() {
              titleController.clear();
            });
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
// GROUP WATCH
// ============================================================

class GroupWatchDialog extends StatelessWidget {
  final MediaItem media;

  const GroupWatchDialog({
    super.key,
    required this.media,
  });

  @override
  Widget build(BuildContext context) {
    final controller = AppController.instance;

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
            ),

            const SizedBox(height: 20),

            const Text(
              'Invite the other active profiles. Everyone must accept before the group watch session starts.',
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 25),

            ...controller.account!.profiles
                .where(
                  (profile) =>
                      profile.id !=
                      controller.currentProfile!.id,
                )
                .map(
                  (profile) => ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person),
                    ),
                    title: Text(profile.name),
                    trailing: const Text(
                      'INVITE',
                    ),
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
  State<GroupWatchPreferencesScreen> createState() =>
      _GroupWatchPreferencesScreenState();
}

class _GroupWatchPreferencesScreenState
    extends State<GroupWatchPreferencesScreen> {
  String audioLanguage = 'Original';
  bool subtitlesEnabled = false;
  String? subtitleLanguage;

  @override
  Widget build(BuildContext context) {
    final audioLanguages =
        widget.media.audioTracks
            .map((track) => track.language)
            .toSet()
            .toList();

    final subtitleLanguages =
        widget.media.subtitleTracks
            .map((track) => track.language)
            .toSet()
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Group Watch Preferences',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Choose your audio language',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          DropdownButtonFormField<String>(
            initialValue:
                audioLanguages.contains(
              audioLanguage,
            )
                    ? audioLanguage
                    : null,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
            items: audioLanguages
                .map(
                  (language) =>
                      DropdownMenuItem<String>(
                    value: language,
                    child: Text(language),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                audioLanguage =
                    value ?? audioLanguage;
              });
            },
          ),

          const SizedBox(height: 25),

          SwitchListTile(
            title: const Text(
              'Subtitles',
            ),
            value: subtitlesEnabled,
            onChanged: (value) {
              setState(() {
                subtitlesEnabled = value;
              });
            },
          ),

          if (subtitlesEnabled) ...[
            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              initialValue:
                  subtitleLanguages.contains(
                subtitleLanguage,
              )
                      ? subtitleLanguage
                      : null,
              decoration:
                  const InputDecoration(
                labelText:
                    'Subtitle language',
                border: OutlineInputBorder(),
              ),
              items: subtitleLanguages
                  .map(
                    (language) =>
                        DropdownMenuItem<String>(
                      value: language,
                      child: Text(language),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  subtitleLanguage =
                      value;
                });
              },
            ),
          ],

          const SizedBox(height: 35),

          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'SAVE PREFERENCES',
              ),
            ),
          ),
        ],
      ),
    );
  }
}