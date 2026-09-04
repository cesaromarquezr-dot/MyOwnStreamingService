import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class recent {
  String? imgurl;
  String? name;

  recent({
    this.imgurl,
    this.name,
  });
}

/// Reusable recently-watched card.
class RecentlyWatchedCard extends StatelessWidget {
  final String? imgurl;
  final String? name;

  const RecentlyWatchedCard({
    super.key,
    this.imgurl,
    this.name,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      height: 220,
      margin: const EdgeInsets.only(left: 15),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imgurl != null && imgurl!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imgurl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const Icon(
                  Icons.movie,
                  color: Colors.white,
                  size: 50,
                ),
              )
            else
              const Center(
                child: Icon(
                  Icons.movie,
                  color: Colors.white,
                  size: 50,
                ),
              ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                color: Colors.black87,
                child: Text(
                  name ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compatibility name for your old series.dart.
class recentlywatched extends RecentlyWatchedCard {
  const recentlywatched({
    super.key,
    super.imgurl,
    super.name,
  });
}