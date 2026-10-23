import 'app_core.dart';

/// Deterministic, metadata-aware ordering and duplicate-candidate detection.
/// A title match is never sufficient grounds to merge two media records.
enum MediaTitleSortDirection { ascending, descending }

class MediaIdentitySorting {
  const MediaIdentitySorting._();

  static String normalizedTitle(String value) {
    var result = value.trim().toLowerCase();
    // Ignore leading articles for ordering, without changing the display title.
    result = result.replaceFirst(RegExp(r'^(the|a|an)\s+'), '');
    result = result.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
    return result;
  }

  static List<MediaItem> byTitle(
    Iterable<MediaItem> items, {
    MediaTitleSortDirection direction = MediaTitleSortDirection.ascending,
  }) {
    final result = items.toList(growable: false);
    result.sort((a, b) {
      final titleA = normalizedTitle(a.canonicalTitle?.trim().isNotEmpty == true
          ? a.canonicalTitle!
          : a.title);
      final titleB = normalizedizedTitleFor(b);
      var compared = titleA.compareTo(titleB);
      if (direction == MediaTitleSortDirection.descending) {
        compared = -compared;
      }
      if (compared != 0) return compared;

      // For same-name works, older release comes first. Unknown years last.
      final yearA = a.seriesStartYear ?? a.releaseYear ?? 999999;
      final yearB = b.seriesStartYear ?? b.releaseYear ?? 999999;
      compared = yearA.compareTo(yearB);
      if (compared != 0) return compared;

      compared = _creator(a).compareTo(_creator(b));
      if (compared != 0) return compared;
      compared = (a.editionName ?? '').toLowerCase().compareTo(
            (b.editionName ?? '').toLowerCase(),
          );
      if (compared != 0) return compared;
      return a.id.compareTo(b.id);
    });
    return result;
  }

  static String normalizedizedTitleFor(MediaItem item) =>
      normalizedTitle(item.canonicalTitle?.trim().isNotEmpty == true
          ? item.canonicalTitle!
          : item.title);

  static String _creator(MediaItem item) {
    if (item.music.isNotEmpty) return item.music.first.toLowerCase();
    if (item.actors.isNotEmpty && item.type.toLowerCase().contains('music')) {
      return item.actors.first.toLowerCase();
    }
    if (item.directors.isNotEmpty) return item.directors.first.toLowerCase();
    if (item.studios.isNotEmpty) return item.studios.first.toLowerCase();
    return '';
  }

  /// Returns groups that deserve duplicate review; never merges or deletes.
  /// Same title with different known years is deliberately not a duplicate.
  static List<List<MediaItem>> duplicateCandidates(Iterable<MediaItem> items) {
    final groups = <String, List<MediaItem>>{};
    for (final item in items) {
      final title = normalizedTitle(item.canonicalTitle?.trim().isNotEmpty == true
          ? item.canonicalTitle!
          : item.title);
      if (title.isEmpty) continue;
      final creator = _creator(item);
      final year = item.seriesStartYear ?? item.releaseYear;
      final key = '${item.type.toLowerCase().trim()}|$title|${year ?? '?'}|$creator';
      groups.putIfAbsent(key, () => <MediaItem>[]).add(item);
    }
    return groups.values
        .where((group) => group.length > 1)
        .map((group) => List<MediaItem>.unmodifiable(group))
        .toList(growable: false);
  }

  /// Stable human-readable disambiguator; display title itself stays unchanged.
  static String disambiguator(MediaItem item) {
    final year = item.seriesStartYear ?? item.releaseYear;
    final parts = <String>[];
    if (year != null) parts.add('$year');
    if (item.type.toLowerCase().contains('song') ||
        item.type.toLowerCase().contains('track')) {
      if (item.music.isNotEmpty) parts.add(item.music.first);
    } else if (item.directors.isNotEmpty) {
      parts.add(item.directors.first);
    }
    if ((item.editionName ?? '').trim().isNotEmpty) {
      parts.add(item.editionName!.trim());
    }
    return parts.join(' · ');
  }
}
