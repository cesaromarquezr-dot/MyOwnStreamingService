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
      .replaceAll(RegExp(r'[^a-z0-9]'), '');

  static int? _yearOf(MediaItem item) =>
      item.releaseYear ?? (item.isSeries ? item.seriesStartYear : null);

  static bool _sameTitleAndFormat({
    required String title,
    required bool isTv,
    required MediaItem item,
  }) =>
      normalizeTitle(title) == normalizeTitle(item.title) &&
      normalizeTitle(title).isNotEmpty &&
      isTv == item.isSeries;

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
String recommendationOwnershipLabel(bool isOwned) =>
    isOwned ? 'Owned' : 'Not owned';

/// Purchase links are only useful when the current profile does not already
/// have the recommended media in its accessible library.
bool shouldShowBuySectionForOwnership({required bool isOwned}) => !isOwned;

/// Compact, consistent status marker shown on recommendation cards.
class RecommendationOwnershipBadge extends StatelessWidget {
  const RecommendationOwnershipBadge({
    super.key,
    required this.isOwned,
    this.compact = false,
  });

  final bool isOwned;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = isOwned ? const Color(0xFF8BE3A1) : const Color(0xFFFFD27A);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 9,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xE817171D),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOwned ? Icons.check_circle_rounded : Icons.shopping_bag_outlined,
            size: compact ? 10 : 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            recommendationOwnershipLabel(isOwned),
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
