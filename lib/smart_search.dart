import 'package:flutter/material.dart';
import 'app_core.dart';
import 'details.dart';

class SmartSearch {
  static List<MediaItem> search(
    String query,
    UserLibrary library,
  ) {
    final q = query.trim().toLowerCase();

    if (q.isEmpty) {
      return [];
    }

    // Collection searches.
    if (q == 'trilogy' || q == 'trilogies') {
      return library.media
          .where((m) => m.tags.contains('trilogy'))
          .toList();
    }

    if (q == 'saga' || q == 'sagas') {
      return library.media
          .where((m) => m.tags.contains('saga'))
          .toList();
    }

    if (q == 'franchise' || q == 'franchises') {
      return library.media
          .where((m) => m.tags.contains('franchise'))
          .toList();
    }

    return library.media.where((media) {
      if (media.title.toLowerCase().contains(q)) {
        return true;
      }

      if (media.description.toLowerCase().contains(q)) {
        return true;
      }

      if (media.genre.any(
        (genre) => genre.toLowerCase().contains(q),
      )) {
        return true;
      }

      if (media.tags.any(
        (tag) => tag.toLowerCase().contains(q),
      )) {
        return true;
      }

      if (media.themes.any(
        (theme) => theme.toLowerCase().contains(q),
      )) {
        return true;
      }

      if (media.cast.any(
        (person) =>
            person.actorName.toLowerCase().contains(q) ||
            person.characterName.toLowerCase().contains(q),
      )) {
        return true;
      }

      if (media.year?.toString() == q) {
        return true;
      }

      return false;
    }).toList();
  }
}

class SmartSearchScreen extends StatefulWidget {
  const SmartSearchScreen({super.key});

  @override
  State<SmartSearchScreen> createState() =>
      _SmartSearchScreenState();
}

class _SmartSearchScreenState
    extends State<SmartSearchScreen> {
  final TextEditingController controller =
      TextEditingController();

  List<MediaItem> results = [];

  void performSearch(String value) {
    final profile =
        AppController.instance.currentProfile;

    if (profile == null) {
      setState(() {
        results = [];
      });
      return;
    }

    setState(() {
      results = SmartSearch.search(
        value,
        profile.library,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Smart Search'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: controller,
              onChanged: performSearch,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText:
                    'Movie, actor, character, genre, year, saga...',
                hintStyle:
                    const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Colors.white,
                ),
                filled: true,
                fillColor: Colors.grey.shade900,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          Expanded(
            child: results.isEmpty
                ? const Center(
                    child: Text(
                      'No results',
                      style: TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (_, index) {
                      final media = results[index];

                      return ListTile(
                        leading: media.posterUrl != null &&
                                media.posterUrl!.isNotEmpty
                            ? Image.network(
                                media.posterUrl!,
                                width: 55,
                                fit: BoxFit.cover,
                              )
                            : const Icon(
                                Icons.movie,
                                color: Colors.white,
                              ),
                        title: Text(
                          media.title,
                          style: const TextStyle(
                            color: Colors.white,
                          ),
                        ),
                        subtitle: Text(
                          '${media.year ?? ''} • ${media.type == MediaType.movie ? 'Movie' : 'TV Show'}',
                          style: const TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  MediaDetailsScreen(
                                media: media,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}