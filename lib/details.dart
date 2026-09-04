import 'package:flutter/material.dart';

import 'app_core.dart';
import 'player.dart';
import 'trailer.dart';

class MediaDetailsScreen extends StatelessWidget {
  final MediaItem media;

  const MediaDetailsScreen({
    super.key,
    required this.media,
  });

  void showExtras(
    BuildContext context,
    MediaItem item,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: item.extras.isEmpty
                ? const SizedBox(
                    height: 150,
                    child: Center(
                      child: Text(
                        'No extras were imported for this title.',
                        style: TextStyle(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  )
                : ListView(
                    shrinkWrap: true,
                    children: [
                      const Text(
                        'EXTRAS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 15),
                      ...item.extras.map(
                        (extra) => ListTile(
                          leading: const Icon(
                            Icons.movie_filter,
                            color: Colors.white,
                          ),
                          title: Text(
                            extra.title,
                            style: const TextStyle(
                              color: Colors.white,
                            ),
                          ),
                          subtitle: extra.description == null
                              ? null
                              : Text(
                                  extra.description!,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

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

  void playTrailer(BuildContext context) {
    final trailer = media.trailer;

    if (trailer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No trailer is available for this title.',
          ),
        ),
      );
      return;
    }

    openTrailer(
      context,
      trailer,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppController.instance;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          media.title,
          style: const TextStyle(
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (media.posterUrl != null &&
                media.posterUrl!.isNotEmpty)
              Image.network(
                media.posterUrl!,
                width: double.infinity,
                height: 450,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return Container(
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
                },
              )
            else
              Container(
                height: 450,
                width: double.infinity,
                color: Colors.grey.shade900,
                child: const Center(
                  child: Icon(
                    Icons.movie,
                    color: Colors.white,
                    size: 80,
                  ),
                ),
              ),

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

                  Text(
                    '${media.year ?? ''} • ${media.mediaTypeName}',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 20),

                  if (media.description.isNotEmpty)
                    Text(
                      media.description,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),

                  const SizedBox(height: 20),

                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          playMedia(context);
                        },
                        icon: const Icon(
                          Icons.play_arrow,
                        ),
                        label: const Text('PLAY'),
                      ),

                      OutlinedButton.icon(
                        onPressed: () {
                          controller.toggleLike(media);
                        },
                        icon: Icon(
                          media.liked
                              ? Icons.thumb_up
                              : Icons.thumb_up_outlined,
                        ),
                        label: const Text('LIKE'),
                      ),

                      OutlinedButton.icon(
                        onPressed: () {
                          controller.toggleDislike(media);
                        },
                        icon: Icon(
                          media.disliked
                              ? Icons.thumb_down
                              : Icons.thumb_down_outlined,
                        ),
                        label: const Text('DISLIKE'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  if (media.genre.isNotEmpty) ...[
                    const Text(
                      'Genres',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: media.genre
                          .map(
                            (genre) => Chip(
                              label: Text(genre),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 30),
                  ],

                  if (media.cast.isNotEmpty) ...[
                    const Text(
                      'Cast',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 15),

                    SizedBox(
                      height: 170,
                      child: ListView.builder(
                        scrollDirection:
                            Axis.horizontal,
                        itemCount:
                            media.cast.length,
                        itemBuilder: (_, index) {
                          final person =
                              media.cast[index];

                          return Container(
                            width: 120,
                            margin:
                                const EdgeInsets.only(
                              right: 12,
                            ),
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 45,
                                  backgroundImage:
                                      person.photoUrl !=
                                                  null &&
                                              person
                                                  .photoUrl!
                                                  .isNotEmpty
                                          ? NetworkImage(
                                              person.photoUrl!,
                                            )
                                          : null,
                                  child: person.photoUrl ==
                                              null ||
                                          person
                                              .photoUrl!
                                              .isEmpty
                                      ? const Icon(
                                          Icons.person,
                                        )
                                      : null,
                                ),

                                const SizedBox(height: 8),

                                Text(
                                  person.actorName,
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                  style:
                                      const TextStyle(
                                    color: Colors.white,
                                  ),
                                ),

                                Text(
                                  person.characterName,
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                  style:
                                      const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 30),

                  if (media.music.isNotEmpty) ...[
                    const Text(
                      'Music',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    ...media.music.map(
                      (song) => ListTile(
                        contentPadding:
                            EdgeInsets.zero,
                        leading: const Icon(
                          Icons.music_note,
                          color: Colors.white,
                        ),
                        title: Text(
                          song.title,
                          style:
                              const TextStyle(
                            color: Colors.white,
                          ),
                        ),
                        subtitle: Text(
                          song.artistOrComposer,
                          style:
                              const TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 30),

                  if (media.trailer != null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          playTrailer(context);
                        },
                        icon: const Icon(
                          Icons.ondemand_video,
                        ),
                        label: const Text(
                          'WATCH TRAILER',
                        ),
                      ),
                    ),

                  const SizedBox(height: 15),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        showExtras(
                          context,
                          media,
                        );
                      },
                      icon: const Icon(
                        Icons.movie_filter,
                      ),
                      label: const Text(
                        'EXTRAS',
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
}