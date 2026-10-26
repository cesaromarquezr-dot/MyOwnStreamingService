import 'package:flutter/material.dart';

import 'core/services/cinematic_title_metadata_service.dart';

/// TMDB-backed title recommendations and mood-based discovery choices.
class TMDBTitleRecommendationsSection extends StatelessWidget {
  const TMDBTitleRecommendationsSection({
    super.key,
    required this.sourceTitle,
    required this.recommendations,
    required this.loading,
    required this.onOpen,
    required this.moodOptionsEnabled,
    required this.selectedMoodKey,
    required this.moodRecommendations,
    required this.loadingMoodRecommendations,
    required this.moodRecommendationError,
    required this.onMoodSelected,
  });

  final String sourceTitle;
  final List<CinematicTitleRecommendation> recommendations;
  final bool loading;
  final ValueChanged<CinematicTitleRecommendation> onOpen;
  final bool moodOptionsEnabled;
  final String? selectedMoodKey;
  final List<CinematicTitleRecommendation> moodRecommendations;
  final bool loadingMoodRecommendations;
  final String? moodRecommendationError;
  final ValueChanged<CinematicRecommendationMood> onMoodSelected;

  @override
  Widget build(BuildContext context) {
    final selectedMood = CinematicRecommendationMood.byKey(selectedMoodKey ?? '');
    final hasTitleRecommendations = recommendations.isNotEmpty || loading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasTitleRecommendations) ...[
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Because you watched '),
                TextSpan(
                  text: sourceTitle,
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const TextSpan(text: ', you might like...'),
              ],
            ),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              height: 1.25,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Personalized movie and TV discovery',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (recommendations.isEmpty && loading)
            const _RecommendationLoading(message: 'Finding movies and shows you may enjoy…')
          else
            _RecommendationCarousel(
              recommendations: recommendations,
              onOpen: onOpen,
            ),
          const SizedBox(height: 26),
        ],
        if (moodOptionsEnabled) ...[
          const Text(
            'Or maybe something a bit more...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              height: 1.25,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pick a mood to discover different movies or shows.',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final mood in CinematicRecommendationMood.all)
                ChoiceChip(
                  label: Text(mood.label),
                  selected: selectedMoodKey == mood.key,
                  onSelected: (selected) {
                    if (selected) onMoodSelected(mood);
                  },
                  showCheckmark: false,
                  backgroundColor: const Color(0xFF202027),
                  selectedColor: const Color(0xFF6955C8),
                  labelStyle: TextStyle(
                    color: selectedMoodKey == mood.key
                        ? Colors.white
                        : Colors.white70,
                    fontWeight: selectedMoodKey == mood.key
                        ? FontWeight.w800
                        : FontWeight.w500,
                  ),
                  side: BorderSide(
                    color: selectedMoodKey == mood.key
                        ? const Color(0xFF9C8CF0)
                        : Colors.white12,
                  ),
                ),
            ],
          ),
          if (selectedMood != null) ...[
            const SizedBox(height: 18),
            Text(
              'A little more ${selectedMood.label}...',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            if (loadingMoodRecommendations)
              const _RecommendationLoading(message: 'Finding picks for this mood…')
            else if (moodRecommendations.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  moodRecommendationError ??
                      'No matching titles were found. Try another mood.',
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
              )
            else
              _RecommendationCarousel(
                recommendations: moodRecommendations,
                onOpen: onOpen,
              ),
          ],
        ],
      ],
    );
  }
}

class _RecommendationLoading extends StatelessWidget {
  const _RecommendationLoading({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationCarousel extends StatelessWidget {
  const _RecommendationCarousel({
    required this.recommendations,
    required this.onOpen,
  });

  final List<CinematicTitleRecommendation> recommendations;
  final ValueChanged<CinematicTitleRecommendation> onOpen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 294,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: recommendations.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = recommendations[index];
          final poster = item.posterUrl;
          return SizedBox(
            width: 142,
            child: Material(
              color: const Color(0xFF17171C),
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onOpen(item),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: double.infinity,
                          height: 178,
                          child: poster == null
                              ? _PosterFallback(title: item.title)
                              : Image.network(
                                  poster,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _PosterFallback(title: item.title),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${item.mediaTypeLabel}${item.releaseYear == null ? '' : ' · ${item.releaseYear}'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                      const Spacer(),
                      if (item.voteAverage != null && item.voteAverage! > 0)
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 15,
                              color: Color(0xFFFFC857),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${item.voteAverage!.toStringAsFixed(1)}/10',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PosterFallback extends StatelessWidget {
  const _PosterFallback({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF282830),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.movie_creation_outlined,
            size: 30,
            color: Colors.white54,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
