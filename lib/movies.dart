import 'package:flutter/material.dart';

import 'app_core.dart';
import 'details.dart';

class MoviesScreen extends StatelessWidget {
  const MoviesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = AppController.instance.library;

    final movies = library
        .where(
          (media) =>
              media.type.toLowerCase() == 'movie',
        )
        .toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Movies'),
      ),
      body: movies.isEmpty
          ? const Center(
              child: Text(
                'No movies in your library yet.\n\n'
                'Use "Add Movie or Show" to import one.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                ),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate:
                  const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                childAspectRatio: .68,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
              ),
              itemCount: movies.length,
              itemBuilder: (_, index) {
                final movie = movies[index];

                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            MediaDetailsScreen(
                          media: movie,
                        ),
                      ),
                    );
                  },
                  child: Card(
                    color: Colors.grey.shade900,
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: movie.imageUrl != null &&
                                  movie.imageUrl!
                                      .isNotEmpty
                              ? Image.network(
                                  movie.imageUrl!,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (_, __, ___) {
                                    return const Center(
                                      child: Icon(
                                        Icons.movie,
                                        color:
                                            Colors.white,
                                        size: 60,
                                      ),
                                    );
                                  },
                                )
                              : const Center(
                                  child: Icon(
                                    Icons.movie,
                                    color: Colors.white,
                                    size: 60,
                                  ),
                                ),
                        ),
                        Padding(
                          padding:
                              const EdgeInsets.all(8),
                          child: Text(
                            movie.title,
                            maxLines: 2,
                            overflow:
                                TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}