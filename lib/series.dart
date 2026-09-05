import 'package:flutter/material.dart';

import 'app_core.dart';
import 'details.dart';

class SeriesScreen extends StatelessWidget {
  const SeriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = AppController.instance.library;

    final shows = library
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('TV Shows'),
      ),
      body: shows.isEmpty
          ? const Center(
              child: Text(
                'No TV shows in your library yet.\n\n'
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
              itemCount: shows.length,
              itemBuilder: (_, index) {
                final show = shows[index];

                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            MediaDetailsScreen(
                          media: show,
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
                          child: show.imageUrl != null &&
                                  show.imageUrl!.isNotEmpty
                              ? Image.network(
                                  show.imageUrl!,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (_, __, ___) {
                                    return const Center(
                                      child: Icon(
                                        Icons.tv,
                                        color: Colors.white,
                                        size: 60,
                                      ),
                                    );
                                  },
                                )
                              : const Center(
                                  child: Icon(
                                    Icons.tv,
                                    color: Colors.white,
                                    size: 60,
                                  ),
                                ),
                        ),
                        Padding(
                          padding:
                              const EdgeInsets.all(8),
                          child: Text(
                            show.title,
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
                        if (show.releaseYear != null)
                          Padding(
                            padding:
                                const EdgeInsets.only(
                              left: 8,
                              right: 8,
                              bottom: 8,
                            ),
                            child: Text(
                              show.releaseYear.toString(),
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
              },
            ),
    );
  }
}

/// Compatibility with your old class name.
class Series extends SeriesScreen {
  const Series({super.key});
}