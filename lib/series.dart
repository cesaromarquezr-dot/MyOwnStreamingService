import 'package:flutter/material.dart';
import 'app_core.dart';
import 'details.dart';

class SeriesScreen extends StatelessWidget {
  const SeriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library =
        AppController.instance.currentProfile?.library;

    final shows = library?.tvShows ?? [];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('TV Shows'),
      ),
      body: shows.isEmpty
          ? const Center(
              child: Text(
                'No TV shows in your library yet.\n\nUse "Add Movie or Show" to import one.',
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
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            MediaDetailsScreen(media: show),
                      ),
                    );
                  },
                  child: Card(
                    color: Colors.grey.shade900,
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: show.posterUrl != null &&
                                  show.posterUrl!.isNotEmpty
                              ? Image.network(
                                  show.posterUrl!,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
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
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            show.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
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
class series extends SeriesScreen {
  const series({super.key});
}