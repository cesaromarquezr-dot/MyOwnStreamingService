import 'package:flutter/material.dart';

import 'app_core.dart';
import 'details.dart';

class SmartSearch {
  static List<MediaItem> search(
    String query,
    List<MediaItem> library,
  ) {
    final q = query.trim().toLowerCase();

    if (q.isEmpty) {
      return [];
    }

    return library.where((media) {
      final title =
          media.title.toLowerCase();

      final description =
          media.description?.toLowerCase() ?? '';

      final type =
          media.type.toLowerCase();

      final year =
          media.releaseYear?.toString() ?? '';

      final rating =
          media.rating?.toString() ?? '';

      // Title search.
      if (title.contains(q)) {
        return true;
      }

      // Description search.
      if (description.contains(q)) {
        return true;
      }

      // Type search.
      if (type.contains(q)) {
        return true;
      }

      // Year search.
      if (year == q) {
        return true;
      }

      // Rating search.
      if (rating == q) {
        return true;
      }

      // Friendly type aliases.
      if ((q == 'movie' || q == 'movies') &&
          type == 'movie') {
        return true;
      }

      if ((q == 'tv' ||
              q == 'tv show' ||
              q == 'tv shows' ||
              q == 'series' ||
              q == 'show' ||
              q == 'shows') &&
          (type == 'tvshow' ||
              type == 'tv_show' ||
              type == 'tv show')) {
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

  List<MediaItem> results =
      <MediaItem>[];

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void performSearch(String value) {
    final library =
        AppController.instance.library;

    setState(() {
      results = SmartSearch.search(
        value,
        library,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Smart Search',
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: controller,
              onChanged: performSearch,
              style: const TextStyle(
                color: Colors.white,
              ),
              decoration:
                  InputDecoration(
                hintText:
                    'Movie, show, year, description...',
                hintStyle:
                    const TextStyle(
                  color: Colors.grey,
                ),
                prefixIcon:
                    const Icon(
                  Icons.search,
                  color: Colors.white,
                ),
                suffixIcon:
                    controller.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(
                              Icons.clear,
                              color: Colors.white70,
                            ),
                            onPressed: () {
                              controller.clear();
                              performSearch('');
                              setState(() {});
                            },
                          ),
                filled: true,
                fillColor:
                    Colors.grey.shade900,
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                  borderSide:
                      BorderSide.none,
                ),
              ),
            ),
          ),

          Expanded(
            child: results.isEmpty
                ? Center(
                    child: Text(
                      controller.text.trim().isEmpty
                          ? 'Search your library'
                          : 'No results',
                      style:
                          const TextStyle(
                        color:
                            Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount:
                        results.length,
                    itemBuilder: (_, index) {
                      final media =
                          results[index];

                      final type =
                          media.type
                              .toLowerCase();

                      final typeLabel =
                          type == 'movie'
                              ? 'Movie'
                              : 'TV Show';

                      return ListTile(
                        leading:
                            SizedBox(
                          width: 55,
                          height: 75,
                          child: media.imageUrl !=
                                      null &&
                                  media.imageUrl!
                                      .isNotEmpty
                              ? ClipRRect(
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    6,
                                  ),
                                  child:
                                      Image.network(
                                    media.imageUrl!,
                                    fit: BoxFit
                                        .cover,
                                    errorBuilder:
                                        (_, __, ___) {
                                      return const Icon(
                                        Icons
                                            .movie,
                                        color: Colors
                                            .white,
                                      );
                                    },
                                  ),
                                )
                              : const Icon(
                                  Icons.movie,
                                  color:
                                      Colors.white,
                                  size: 35,
                                ),
                        ),
                        title: Text(
                          media.title,
                          style:
                              const TextStyle(
                            color:
                                Colors.white,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          _subtitleFor(
                            media,
                            typeLabel,
                          ),
                          style:
                              const TextStyle(
                            color:
                                Colors.grey,
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

  String _subtitleFor(
    MediaItem media,
    String typeLabel,
  ) {
    final parts =
        <String>[];

    if (media.releaseYear != null) {
      parts.add(
        media.releaseYear.toString(),
      );
    }

    parts.add(typeLabel);

    if (media.rating != null) {
      parts.add(
        '★ ${media.rating!.toStringAsFixed(1)}',
      );
    }

    return parts.join(' • ');
  }
}