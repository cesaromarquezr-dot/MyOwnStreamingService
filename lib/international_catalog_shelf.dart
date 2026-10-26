import 'package:flutter/material.dart';

import 'app_core.dart';
import 'details.dart';
import 'catalog_poster_image.dart';

/// A dedicated, always-visible rail for curated international catalog records.
/// Media titles are rendered with Text, never the app's phrase translator.
class InternationalCatalogShelf extends StatelessWidget {
  final String title;
  final List<MediaItem> items;

  const InternationalCatalogShelf({
    super.key,
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 0, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: Row(
              children: [
                const Icon(Icons.public_rounded, color: Colors.white70, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                Text(
                  '${items.length}',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 18),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                return SizedBox(
                  width: 126,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => MediaDetailsScreen(media: item),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            height: 136,
                            width: 126,
                            child: CatalogPosterImage(
                              media: item,
                              width: 126,
                              height: 136,
                              fit: BoxFit.cover,
                              placeholder: Container(
                                color: const Color(0xFF242424),
                                alignment: Alignment.center,
                                child: const Icon(Icons.movie_outlined, color: Colors.white70, size: 32),
                              ),
                              errorPlaceholder: Container(
                                color: const Color(0xFF242424),
                                alignment: Alignment.center,
                                child: const Icon(Icons.movie_outlined, color: Colors.white70, size: 32),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                      ],
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
