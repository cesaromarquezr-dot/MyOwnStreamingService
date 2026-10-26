import 'package:flutter/material.dart';

import '../app_core.dart';
import '../cinematic_title_fonts.dart';
import '../details.dart';

/// A horizontally scrolling shelf of media cards.
///
/// This widget is intentionally data-driven: callers choose the media list,
/// and each card uses the existing media details route when selected.
class MediaHorizontalList extends StatelessWidget {
  final List<MediaItem> media;

  const MediaHorizontalList({super.key, required this.media});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 245,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: media.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, index) => MediaCard(media: media[index]),
      ),
    );
  }
}

/// A reusable poster card that opens the selected media's details screen.
class MediaCard extends StatelessWidget {
  final MediaItem media;

  const MediaCard({super.key, required this.media});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 145,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => MediaDetailsScreen(media: media),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: media.imageUrl == null
                    ? Container(
                        width: double.infinity,
                        color: Colors.grey.shade900,
                        child: const Icon(Icons.movie, size: 45),
                      )
                    : Image.network(
                        media.imageUrl!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade900,
                          child: const Icon(Icons.broken_image),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              media.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: CinematicTitleFonts.captionStyle(
                media,
                baseFontSize: 13.2,
                color: Theme.of(context).colorScheme.onSurface,
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
