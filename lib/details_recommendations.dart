import 'package:flutter/material.dart';

import 'app_core.dart';

/// Builds profile-local related titles from known recommendations and the
/// account's existing library. The ranking favours shared franchise, genre,
/// tags, cast, and format; no external catalog is required.
class DetailsRecommendationsSection extends StatelessWidget {
  final MediaItem source;
  final ValueChanged<MediaItem> onOpen;

  const DetailsRecommendationsSection({
    super.key,
    required this.source,
    required this.onOpen,
  });

  Set<String> _normalized(Iterable<String> values) => values
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .toSet();

  int _score(MediaItem candidate) {
    var score = 0;
    if (source.franchiseId != null &&
        source.franchiseId == candidate.franchiseId) {
      score += 20;
    }
    final sourceGenres = _normalized(source.genres);
    final candidateGenres = _normalized(candidate.genres);
    score += sourceGenres.intersection(candidateGenres).length * 5;

    final sourceTags = _normalized(source.tags);
    final candidateTags = _normalized(candidate.tags);
    score += sourceTags.intersection(candidateTags).length * 3;

    final sourcePeople = _normalized(<String>[
      ...source.actors,
      ...source.directors,
      ...source.music,
    ]);
    final candidatePeople = _normalized(<String>[
      ...candidate.actors,
      ...candidate.directors,
      ...candidate.music,
    ]);
    score += sourcePeople.intersection(candidatePeople).length * 2;

    final sourceType = source.type.toLowerCase().replaceAll('_', '').replaceAll(' ', '');
    final candidateType = candidate.type.toLowerCase().replaceAll('_', '').replaceAll(' ', '');
    if (sourceType == candidateType) score += 1;
    return score;
  }

  List<MediaItem> _buildItems() {
    final controller = AppController.instance;
    final byId = <String, MediaItem>{};
    for (final item in <MediaItem>[
      ...controller.recommendations,
      ...controller.library,
      ...controller.watched,
      ...controller.liked,
    ]) {
      if (item.id != source.id) byId.putIfAbsent(item.id, () => item);
    }
    final items = byId.values.toList()
      ..sort((a, b) {
        final scoreOrder = _score(b).compareTo(_score(a));
        if (scoreOrder != 0) return scoreOrder;
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
    return items.take(10).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final items = _buildItems();
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'You might also like',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              final imageUrl = item.imageUrl;
              return SizedBox(
                width: 132,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onOpen(item),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: SizedBox(
                            width: 132,
                            child: imageUrl != null && imageUrl.startsWith('http')
                                ? Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _ArtworkFallback(title: item.title),
                                  )
                                : _ArtworkFallback(title: item.title),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.type,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ArtworkFallback extends StatelessWidget {
  final String title;
  const _ArtworkFallback({required this.title});

  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFF202027),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.movie_creation_outlined, size: 30, color: Colors.white54),
            const SizedBox(height: 8),
            Text(title, maxLines: 3, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
          ],
        ),
      );
}
