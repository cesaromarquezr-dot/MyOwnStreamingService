import 'package:flutter/material.dart';

import 'app_core.dart';
import 'player.dart';

class MediaDetailsScreen extends StatelessWidget {
  final MediaItem media;

  const MediaDetailsScreen({
    super.key,
    required this.media,
  });

  void playMedia(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          media: media,
        ),
      ),
    );
  }

  void toggleLike(BuildContext context) {
    final controller = AppController.instance;

    if (controller.isLiked(media.id)) {
      controller.clearReaction(media.id);
    } else {
      controller.likeMedia(media);
    }
  }

  void toggleDislike(BuildContext context) {
    final controller = AppController.instance;

    if (controller.isDisliked(media.id)) {
      controller.clearReaction(media.id);
    } else {
      controller.dislikeMedia(media);
    }
  }

  String getMediaTypeName() {
    final value = media.type.trim().toLowerCase();

    switch (value) {
      case 'movie':
        return 'Movie';

      case 'series':
      case 'tv':
      case 'show':
        return 'TV Show';

      case 'episode':
        return 'Episode';

      case 'special':
        return 'Special';

      case 'documentary':
        return 'Documentary';

      default:
        if (value.isEmpty) {
          return 'Title';
        }

        return value[0].toUpperCase() +
            value.substring(1);
    }
  }

  Widget buildPoster() {
    if (media.imageUrl != null &&
        media.imageUrl!.trim().isNotEmpty) {
      return Image.network(
        media.imageUrl!,
        width: double.infinity,
        height: 450,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return buildPosterPlaceholder();
        },
      );
    }

    return buildPosterPlaceholder();
  }

  Widget buildPosterPlaceholder() {
    return Container(
      width: double.infinity,
      height: 450,
      color: Colors.grey.shade900,
      child: const Center(
        child: Icon(
          Icons.movie,
          color: Colors.white,
          size: 80,
        ),
      ),
    );
  }

  Widget buildRating() {
    if (media.rating == null) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.star,
          color: Colors.amber,
          size: 20,
        ),
        const SizedBox(width: 5),
        Text(
          media.rating!.toStringAsFixed(1),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget buildOwnershipMessage(bool owned) {
    if (owned) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.green,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'You own this title.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.white70,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'This title is not in your library.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppController.instance;

    final bool owned =
        controller.isOwned(media.id);

    final bool liked =
        controller.isLiked(media.id);

    final bool disliked =
        controller.isDisliked(media.id);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          media.title,
          style: const TextStyle(
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            buildPoster(),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    media.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      if (media.releaseYear != null)
                        Text(
                          media.releaseYear!.toString(),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),

                      if (media.releaseYear != null)
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          child: Text(
                            '•',
                            style: TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                        ),

                      Text(
                        getMediaTypeName(),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),

                      if (media.rating != null) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          child: Text(
                            '•',
                            style: TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        buildRating(),
                      ],
                    ],
                  ),

                  const SizedBox(height: 25),

                  if (media.description != null &&
                      media.description!.trim().isNotEmpty)
                    Text(
                      media.description!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),

                  const SizedBox(height: 25),

                  buildOwnershipMessage(owned),

                  const SizedBox(height: 25),

                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      // WATCH ONLY APPEARS WHEN
                      // THE USER OWNS THE TITLE.
                      if (owned)
                        ElevatedButton.icon(
                          onPressed: () {
                            playMedia(context);
                          },
                          icon: const Icon(
                            Icons.play_arrow,
                          ),
                          label: const Text(
                            'WATCH',
                          ),
                        ),

                      OutlinedButton.icon(
                        onPressed: () {
                          toggleLike(context);
                        },
                        icon: Icon(
                          liked
                              ? Icons.thumb_up
                              : Icons.thumb_up_outlined,
                        ),
                        label: const Text(
                          'LIKE',
                        ),
                      ),

                      OutlinedButton.icon(
                        onPressed: () {
                          toggleDislike(context);
                        },
                        icon: Icon(
                          disliked
                              ? Icons.thumb_down
                              : Icons.thumb_down_outlined,
                        ),
                        label: const Text(
                          'DISLIKE',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  if (!owned)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.grey.shade800,
                        ),
                        borderRadius:
                            BorderRadius.circular(10),
                      ),
                      child: const Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NOT IN YOUR LIBRARY',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Add this title to your library when it becomes available through your media collection.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (owned)
                    const SizedBox(height: 10),

                  if (owned)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          controller.removeFromLibrary(
                            media.id,
                          );

                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Removed from your library.',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.remove_circle_outline,
                        ),
                        label: const Text(
                          'REMOVE FROM LIBRARY',
                        ),
                      ),
                    ),

                  if (!owned)
                    const SizedBox(height: 10),

                  if (!owned)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          controller.addToLibrary(
                            media,
                          );

                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Added to your library.',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.library_add,
                        ),
                        label: const Text(
                          'ADD TO LIBRARY',
                        ),
                      ),
                    ),

                  const SizedBox(height: 30),

                  const Text(
                    'TITLE INFORMATION',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 15),

                  buildInfoRow(
                    'Title',
                    media.title,
                  ),

                  buildInfoRow(
                    'Type',
                    getMediaTypeName(),
                  ),

                  if (media.releaseYear != null)
                    buildInfoRow(
                      'Release Year',
                      media.releaseYear!.toString(),
                    ),

                  if (media.rating != null)
                    buildInfoRow(
                      'Rating',
                      media.rating!.toStringAsFixed(1),
                    ),

                  const SizedBox(height: 30),

                  if (owned)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          playMedia(context);
                        },
                        icon: const Icon(
                          Icons.play_arrow,
                        ),
                        label: const Text(
                          'WATCH NOW',
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildInfoRow(
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 12,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 15,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}