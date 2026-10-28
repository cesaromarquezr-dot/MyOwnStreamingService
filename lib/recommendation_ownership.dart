import 'package:flutter/material.dart';

import 'app_core.dart';
import 'core/services/cinematic_title_metadata_service.dart';


/// Resolves recommended titles against the active profile's real library.
///
/// TMDB recommendations do not carry local library IDs, so a recommendation
/// may be the same title as an owned catalog item but have a slightly different
/// release year (for example, a catalog edition/re-release year). We match by
/// normalized title and movie-vs-TV type first, then use years to disambiguate
/// only when the library contains multiple distinct releases with that title.
class RecommendationOwnershipMatcher {
  RecommendationOwnershipMatcher._();

  static String normalizeTitle(String value) => value
      .trim()
      .toLowerCase()
      // Remove only common separators; preserve Korean, Japanese, Chinese,
      // Arabic and other original-script letters for exact identity matching.
      .replaceAll(RegExp(r"[\s\-_.,:;!?()\[\]{}\\/]+"), '');

  static int? _yearOf(MediaItem item) =>
      item.releaseYear ?? (item.isSeries ? item.seriesStartYear : null);

  static bool _sameTitleAndFormat({
    required String title,
    required bool isTv,
    required MediaItem item,
  }) {
    final normalized = normalizeTitle(title);
    if (normalized.isEmpty || isTv != item.isSeries) return false;
    final itemTitles = <String>{
      normalizeTitle(item.title),
      normalizeTitle(item.originalTitle ?? ''),
      normalizeTitle(item.canonicalTitle ?? ''),
    }..remove('');
    return itemTitles.contains(normalized);
  }

  /// Finds a catalog record for a TMDB result, preferring an owned record and
  /// then a same-title local/catalog record. If found, normal details can show
  /// the local item or its Where to Buy section instead of a separate provider page.
  static MediaItem? findMediaForTitle({
    required String title,
    List<String> alternateTitles = const <String>[],
    required bool isTv,
    int? year,
    required AppController controller,
  }) {
    final titles = <String>{
      normalizeTitle(title),
      ...alternateTitles.map(normalizeTitle),
    }..remove('');
    if (titles.isEmpty) return null;
    final profile = controller.currentProfile;
    var candidates = controller.library.where((item) =>
        (profile == null || item.isAccessibleTo(profile)) &&
        item.isSeries == isTv &&
        <String>{
          normalizeTitle(item.title),
          normalizeTitle(item.originalTitle ?? ''),
          normalizeTitle(item.canonicalTitle ?? ''),
        }.intersection(titles).isNotEmpty).toList(growable: false);
    if (candidates.isEmpty) return null;
    if (year != null) {
      final exactYear = candidates.where((item) => _yearOf(item) == year).toList();
      if (exactYear.isNotEmpty) candidates = exactYear;
    }
    for (final candidate in candidates) {
      if (controller.isOwned(candidate.id)) return candidate;
    }
    return candidates.first;
  }

  static List<MediaItem> _ownedLibrary(AppController controller) =>
      controller.library
          .where((item) =>
              controller.isOwned(item.id) &&
              item.isAccessibleTo(controller.currentProfile))
          .toList(growable: false);

  static MediaItem? findOwnedMediaForMedia({
    required MediaItem media,
    required AppController controller,
  }) {
    if (controller.isOwned(media.id)) return media;
    return _findOwnedMatch(
      title: media.title,
      isTv: media.isSeries,
      year: _yearOf(media),
      ownedItems: _ownedLibrary(controller),
    );
  }

  static MediaItem? findOwnedMediaForRecommendation({
    required CinematicTitleRecommendation recommendation,
    required AppController controller,
  }) =>
      _findOwnedMatch(
        title: recommendation.title,
        isTv: recommendation.isTv,
        year: recommendation.releaseYear,
        ownedItems: _ownedLibrary(controller),
      );

  static bool isMediaOwned({
    required MediaItem media,
    required AppController controller,
  }) =>
      findOwnedMediaForMedia(media: media, controller: controller) != null;

  static bool isRecommendationOwned({
    required CinematicTitleRecommendation recommendation,
    required AppController controller,
  }) =>
      findOwnedMediaForRecommendation(
            recommendation: recommendation,
            controller: controller,
          ) !=
          null;

  static MediaItem? _findOwnedMatch({
    required String title,
    required bool isTv,
    required int? year,
    required List<MediaItem> ownedItems,
  }) {
    final sameTitle = ownedItems
        .where((item) =>
            _sameTitleAndFormat(title: title, isTv: isTv, item: item))
        .toList(growable: false);
    if (sameTitle.isEmpty) return null;

    // If either year is absent, title + media type is the strongest available
    // identity and is preferable to showing a false retailer offer.
    if (year == null) return sameTitle.first;
    for (final item in sameTitle) {
      final ownedYear = _yearOf(item);
      if (ownedYear == null || ownedYear == year) return item;
    }

    // A single owned release for a title is commonly represented in TMDB with
    // a different year because catalog metadata may refer to a re-release or
    // edition. Treat it as owned. Only preserve a year distinction when there
    // are multiple locally owned releases of that same title and media type.
    final distinctKnownYears = sameTitle
        .map(_yearOf)
        .whereType<int>()
        .toSet();
    if (distinctKnownYears.length <= 1) return sameTitle.first;
    return null;
  }
}

/// Shared ownership wording for every recommendation shelf.
String recommendationOwnershipLabel(bool isOwned, {bool isWatched = false}) {
  if (!isOwned) return 'Not owned';
  return isWatched ? 'Owned · Watched' : 'Owned · Unwatched';
}

/// Compact three-state marker for discovery and recommendation cards:
/// blue = in the library but not completed, green = watched/listened, red = not owned.
class RecommendationOwnershipBadge extends StatelessWidget {
  const RecommendationOwnershipBadge({
    super.key,
    required this.isOwned,
    this.isWatched = false,
    this.watchedLabel = 'Watched',
    this.compact = false,
  });

  final bool isOwned;
  final bool isWatched;
  final String watchedLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = !isOwned
        ? const Color(0xFFFF6B6B)
        : isWatched
            ? const Color(0xFF65D98A)
            : const Color(0xFF65B9FF);
    final label = !isOwned
        ? 'Not owned'
        : isWatched
            ? 'Owned · $watchedLabel'
            : 'Owned · Unwatched';
    final icon = !isOwned
        ? Icons.remove_shopping_cart_outlined
        : isWatched
            ? Icons.check_circle_rounded
            : Icons.video_library_outlined;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 9,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xE817171D),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .82)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 10 : 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: compact ? 9 : 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
