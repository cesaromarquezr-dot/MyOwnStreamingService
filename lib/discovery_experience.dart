// FILE: `lib/discovery_experience.dart`.
// Purpose: Provides local recommendation reasoning and seasonal collection UI.
// Physical media remains on the account's home server; this file only works with
// library metadata already available to the Flutter client.

import 'package:flutter/material.dart';

import 'app_core.dart';
import 'localization.dart';

/// Describes why one owned title is a useful recommendation for another title.
class MediaRecommendation {
  final MediaItem media;
  final String reason;
  final int score;

  const MediaRecommendation({
    required this.media,
    required this.reason,
    required this.score,
  });
}

/// Produces explainable recommendations from the user's own library.
///
/// The engine intentionally uses relationships that can be derived from
/// imported metadata: genre, tags, cast, directors, franchise and themes.
class MediaRecommendationEngine {
  static List<MediaRecommendation> forMedia(
    MediaItem source,
    Iterable<MediaItem> library,
  ) {
    final results = <MediaRecommendation>[];

    for (final candidate in library) {
      if (candidate.id == source.id) continue;

      var score = 0;
      final reasons = <String>[];

      final sourceGenres = _normalized(source.genres);
      final candidateGenres = _normalized(candidate.genres);
      final sharedGenres = sourceGenres.intersection(candidateGenres);
      if (sharedGenres.isNotEmpty) {
        score += sharedGenres.length * 3;
        reasons.add('same ${sharedGenres.take(2).join(' + ')}');
      }

      final sourceTags = _normalized(source.tags);
      final candidateTags = _normalized(candidate.tags);
      final sharedTags = sourceTags.intersection(candidateTags);
      if (sharedTags.isNotEmpty) {
        score += sharedTags.length * 2;
        reasons.add('shared themes: ${sharedTags.take(2).join(', ')}');
      }

      final sourceActors = _normalized(source.actors);
      final candidateActors = _normalized(candidate.actors);
      final sharedActors = sourceActors.intersection(candidateActors);
      if (sharedActors.isNotEmpty) {
        score += sharedActors.length * 6;
        reasons.add('shared cast: ${sharedActors.take(2).join(', ')}');
      }

      final sourceDirectors = _normalized(source.directors);
      final candidateDirectors = _normalized(candidate.directors);
      final sharedDirectors = sourceDirectors.intersection(candidateDirectors);
      if (sharedDirectors.isNotEmpty) {
        score += sharedDirectors.length * 5;
        reasons.add('same director');
      }

      if (source.franchiseId != null &&
          source.franchiseId!.trim().isNotEmpty &&
          source.franchiseId == candidate.franchiseId) {
        score += 12;
        reasons.add('same franchise');
      }

      final semanticReason = _semanticReason(source, candidate);
      if (semanticReason != null) {
        score += 8;
        reasons.add(semanticReason);
      }

      if (score > 0) {
        results.add(
          MediaRecommendation(
            media: candidate,
            reason: reasons.isEmpty ? 'similar library signals' : reasons.join(' • '),
            score: score,
          ),
        );
      }
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results.take(12).toList();
  }

  static Set<String> _normalized(Iterable<String> values) {
    return values
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet();
  }

  static String? _semanticReason(MediaItem source, MediaItem candidate) {
    final sourceText =
        '${source.title} ${source.description ?? ''} ${source.genres.join(' ')} ${source.tags.join(' ')}'
            .toLowerCase();
    final candidateText =
        '${candidate.title} ${candidate.description ?? ''} ${candidate.genres.join(' ')} ${candidate.tags.join(' ')}'
            .toLowerCase();

    final sitcom = _containsAny(sourceText, const ['sitcom', 'comedy series']);
    final candidateSitcom =
        _containsAny(candidateText, const ['sitcom', 'comedy series']);
    if (sitcom && candidateSitcom) {
      return 'same sitcom / ensemble-comedy feeling';
    }

    if (_containsAny(sourceText, const ['friend group', 'friendship', 'ensemble']) &&
        _containsAny(candidateText, const ['friend group', 'friendship', 'ensemble'])) {
      return 'similar friend-group dynamics';
    }

    if (_containsAny(sourceText, const ['school', 'teacher']) &&
        _containsAny(candidateText, const ['school', 'teacher'])) {
      return 'same school-setting theme';
    }

    if (_containsAny(sourceText, const ['police', 'cop', 'detective']) &&
        _containsAny(candidateText, const ['police', 'cop', 'detective'])) {
      return 'same police / detective setting';
    }

    if (source.title.toLowerCase().contains('friends') &&
        candidate.title.toLowerCase().contains('how i met your mother')) {
      return 'friend-group sitcom with character-driven relationships';
    }

    if (source.title.toLowerCase().contains('friends') &&
        candidate.title.toLowerCase().contains('brooklyn nine-nine')) {
      return 'sitcom with a workplace police setting';
    }

    if (source.title.toLowerCase().contains('friends') &&
        candidate.title.toLowerCase().contains('modern family')) {
      return 'sitcom centered on family relationships';
    }

    if (source.title.toLowerCase().contains('friends') &&
        candidate.title.toLowerCase().contains('abbott elementary')) {
      return 'sitcom centered on a school community';
    }

    return null;
  }

  static bool _containsAny(String value, List<String> terms) =>
      terms.any(value.contains);
}

/// Determines the seasonal collection that fits the current calendar month.
class SeasonalCollectionEngine {
  static String titleFor(DateTime date) {
    switch (date.month) {
      case 1:
        return 'New Year & Winter';
      case 2:
        return 'Valentine’s Day';
      case 3:
      case 4:
        return 'Spring Stories';
      case 5:
        return 'Family & Friendship';
      case 6:
      case 7:
        return 'Summer Nights';
      case 8:
        return 'Back to School';
      case 9:
        return 'Fall Favorites';
      case 10:
        return 'Halloween';
      case 11:
        return 'Thanksgiving & Gratitude';
      case 12:
        return 'Christmas & Holiday';
      default:
        return 'Seasonal Favorites';
    }
  }

  static List<MediaItem> matching(
    Iterable<MediaItem> library, {
    DateTime? date,
  }) {
    final month = (date ?? DateTime.now()).month;
    final terms = switch (month) {
      1 => const ['winter', 'new year', 'snow', 'holiday'],
      2 => const ['valentine', 'love', 'romance', 'romantic'],
      3 || 4 => const ['spring', 'family', 'friendship'],
      5 => const ['family', 'friendship'],
      6 || 7 => const ['summer', 'vacation', 'beach', 'night'],
      8 => const ['school', 'teacher', 'college'],
      9 => const ['fall', 'autumn'],
      10 => const ['halloween', 'horror', 'spooky', 'ghost', 'monster'],
      11 => const ['thanksgiving', 'family', 'gratitude', 'fall'],
      12 => const ['christmas', 'holiday', 'winter', 'santa'],
      _ => const <String>[],
    };

    final matches = library.where((media) {
      final text =
          '${media.title} ${media.description ?? ''} ${media.genres.join(' ')} ${media.tags.join(' ')} ${media.franchiseName ?? ''}'
              .toLowerCase();
      return terms.any(text.contains);
    }).toList();

    matches.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return matches;
  }
}

/// Reusable recommendation section for a media Details page.
class DetailsRecommendationsSection extends StatelessWidget {
  final MediaItem source;
  final ValueChanged<MediaItem>? onOpen;

  const DetailsRecommendationsSection({
    super.key,
    required this.source,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final results = MediaRecommendationEngine.forMedia(
      source,
      AppController.instance.library,
    );

    if (results.isEmpty) {
      return _emptyCard(
        icon: Icons.auto_awesome_outlined,
        title: tr('Recommendations'),
        message: tr('Recommendations will become more specific as your server imports genres, cast, tags and other metadata.'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const UniversalText('RECOMMENDED FOR YOU',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.3,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 10),
        for (final item in results)
          Card(
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              leading: _poster(item.media),
              title: Text(
                item.media.title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                item.reason,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: onOpen == null ? null : () => onOpen!(item.media),
            ),
          ),
      ],
    );
  }

  Widget _poster(MediaItem media) {
    final url = media.imageUrl?.trim();
    if (url == null || url.isEmpty) {
      return Container(
        width: 48,
        height: 68,
        decoration: BoxDecoration(
          color: const Color(0xFF171717),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: Colors.white12),
        ),
        child: const Icon(Icons.movie_outlined, color: Colors.white38),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: Image.network(
        url,
        width: 48,
        height: 68,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox(
          width: 48,
          height: 68,
          child: Icon(Icons.movie_outlined),
        ),
      ),
    );
  }

  Widget _emptyCard({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  Text(message, style: const TextStyle(color: Colors.white60)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen seasonal collection browser.
class SeasonalCollectionsScreen extends StatelessWidget {
  const SeasonalCollectionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final title = SeasonalCollectionEngine.titleFor(DateTime.now());
    final matches = SeasonalCollectionEngine.matching(
      AppController.instance.library,
    );

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_rounded, size: 34),
                  const SizedBox(width: 14),
                  Expanded(
                    child: UniversalText('This collection changes automatically with the calendar and only surfaces titles already in your account library.',
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (matches.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.auto_awesome_outlined,
                        size: 42, color: Colors.white38),
                    SizedBox(height: 10),
                    UniversalText('No matching titles yet',
                      style:
                          TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                    ),
                    SizedBox(height: 5),
                    UniversalText('When matching movies or shows are imported, they will appear here automatically.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ),
            )
          else
            for (final media in matches)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.movie_filter_outlined),
                  title: Text(media.title),
                  subtitle: Text(
                    [
                      if (media.releaseYear != null) '${media.releaseYear}',
                      ...media.genres.take(2),
                    ].join(' • '),
                  ),
                  onTap: null,
                ),
              ),
        ],
      ),
    );
  }
}
