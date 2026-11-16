import '../../app_core.dart';

/// A non-destructive match group. Every item remains in the library until a
/// person inspects it; alternate cuts and editions are never merged here.
class PotentialDuplicateGroup {
  final String key;
  final String normalizedTitle;
  final String mediaType;
  final int? releaseYear;
  final List<MediaItem> items;

  const PotentialDuplicateGroup({
    required this.key,
    required this.normalizedTitle,
    required this.mediaType,
    required this.releaseYear,
    required this.items,
  });

  bool get containsDifferentEditions => items
      .map((item) {
        final name = item.editionName?.trim() ?? '';
        final type = item.editionType?.trim() ?? '';
        return (name.isNotEmpty ? name : type).toLowerCase();
      })
      .where((value) => value.isNotEmpty)
      .toSet()
      .length > 1;
}


/// A review-only report for a TV season whose indexed episode list is known to
/// be incomplete. Missing trailing episodes are reported only when the season
/// metadata supplies an authoritative expected episode count; otherwise only
/// gaps inside the observed numbering range are reported.
class IncompleteSeasonFinding {
  final String mediaId;
  final String seriesTitle;
  final int seasonNumber;
  final int? expectedEpisodeCount;
  final int actualEpisodeCount;
  final List<int> missingEpisodeNumbers;

  const IncompleteSeasonFinding({
    required this.mediaId,
    required this.seriesTitle,
    required this.seasonNumber,
    required this.expectedEpisodeCount,
    required this.actualEpisodeCount,
    required this.missingEpisodeNumbers,
  });

  bool get hasExpectedCount => expectedEpisodeCount != null;
}

class LibraryAuditFinding {
  final String id;
  final String mediaId;
  final String title;
  final String category;
  final String description;
  final int priority;

  const LibraryAuditFinding({
    required this.id,
    required this.mediaId,
    required this.title,
    required this.category,
    required this.description,
    this.priority = 1,
  });
}

/// Safe library audit helpers shared by the recovery and repair screens.
/// The service never deletes, merges, or rewrites a media record.
class LibraryProtectionService {
  const LibraryProtectionService._();

  static String normalizeTitle(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'\([^)]*\)'), ' ')
      .replaceAll(RegExp(r'\[[^\]]*\]'), ' ')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');

  static String normalizeType(String value) {
    final type = value.toLowerCase().trim();
    if (type.contains('episode')) return 'episode';
    if (type.contains('movie') || type.contains('film')) return 'movie';
    if (type.contains('series') || type.contains('show') || type == 'tv') {
      return 'show';
    }
    if (type.contains('album')) return 'album';
    if (type.contains('song') || type.contains('track') || type == 'music') {
      return 'track';
    }
    return type.isEmpty ? 'unknown' : type;
  }

  static List<PotentialDuplicateGroup> findPotentialDuplicates(
    Iterable<MediaItem> mediaItems,
  ) {
    final grouped = <String, List<MediaItem>>{};
    final metadata = <String, ({String title, String type, int? year})>{};
    for (final item in mediaItems) {
      final title = normalizeTitle(
        (item.canonicalTitle?.trim().isNotEmpty == true
            ? item.canonicalTitle!
            : item.originalTitle?.trim().isNotEmpty == true
                ? item.originalTitle!
                : item.title),
      );
      if (title.isEmpty) continue;
      final type = normalizeType(item.type);
      final year = item.releaseYear ?? item.editionReleaseYear;
      final key = '$type|$title|${year ?? 'unknown-year'}';
      grouped.putIfAbsent(key, () => <MediaItem>[]).add(item);
      metadata[key] = (title: title, type: type, year: year);
    }
    final groups = <PotentialDuplicateGroup>[];
    for (final entry in grouped.entries) {
      if (entry.value.length < 2) continue;
      final values = List<MediaItem>.from(entry.value)
        ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      final info = metadata[entry.key]!;
      groups.add(PotentialDuplicateGroup(
        key: entry.key,
        normalizedTitle: info.title,
        mediaType: info.type,
        releaseYear: info.year,
        items: List<MediaItem>.unmodifiable(values),
      ));
    }
    groups.sort((a, b) {
      final bySize = b.items.length.compareTo(a.items.length);
      if (bySize != 0) return bySize;
      return a.normalizedTitle.compareTo(b.normalizedTitle);
    });
    return List<PotentialDuplicateGroup>.unmodifiable(groups);
  }

  /// Finds incomplete season episode lists without assuming that a partial
  /// provider response is the complete season. Trailing omissions are only
  /// inferred when the season includes an expected episode-count field.
  static List<IncompleteSeasonFinding> findIncompleteSeasons(
    Iterable<MediaItem> mediaItems,
  ) {
    final findings = <IncompleteSeasonFinding>[];
    for (final item in mediaItems) {
      if (!item.isSeries) continue;
      for (final season in item.seasons) {
        final seasonNumber = _readPositiveInt(
              season['seasonNumber'] ??
                  season['season_number'] ??
                  season['number'],
            ) ??
            0;
        final rawEpisodes = season['episodes'];
        final episodeRows = rawEpisodes is List
            ? rawEpisodes.whereType<Map>().toList(growable: false)
            : const <Map>[];
        final episodeNumbers = <int>{};
        for (final row in episodeRows) {
          final number = _readPositiveInt(
            row['episodeNumber'] ??
                row['episode_number'] ??
                row['number'],
          );
          if (number != null) episodeNumbers.add(number);
        }
        final expected = _readPositiveInt(
          season['episodeCount'] ??
              season['episode_count'] ??
              season['numberOfEpisodes'] ??
              season['number_of_episodes'] ??
              season['totalEpisodes'] ??
              season['total_episodes'],
        );
        final missing = <int>[];
        if (expected != null) {
          for (var number = 1; number <= expected; number++) {
            if (!episodeNumbers.contains(number)) missing.add(number);
          }
        } else if (episodeNumbers.length > 1) {
          final ordered = episodeNumbers.toList()..sort();
          for (var number = ordered.first + 1; number < ordered.last; number++) {
            if (!episodeNumbers.contains(number)) missing.add(number);
          }
        }
        final isIncomplete = expected != null
            ? episodeNumbers.length < expected
            : missing.isNotEmpty;
        if (!isIncomplete) continue;
        findings.add(IncompleteSeasonFinding(
          mediaId: item.id,
          seriesTitle: item.title,
          seasonNumber: seasonNumber,
          expectedEpisodeCount: expected,
          actualEpisodeCount: episodeNumbers.length,
          missingEpisodeNumbers: List<int>.unmodifiable(missing),
        ));
      }
    }
    findings.sort((a, b) {
      final titleCompare = a.seriesTitle.toLowerCase().compareTo(b.seriesTitle.toLowerCase());
      if (titleCompare != 0) return titleCompare;
      return a.seasonNumber.compareTo(b.seasonNumber);
    });
    return List<IncompleteSeasonFinding>.unmodifiable(findings);
  }

  static int? _readPositiveInt(dynamic value) {
    final number = value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
    return number != null && number > 0 ? number : null;
  }

  static List<LibraryAuditFinding> audit(Iterable<MediaItem> mediaItems) {
    final findings = <LibraryAuditFinding>[];
    for (final item in mediaItems) {
      final mediaId = item.id.trim();
      if (mediaId.isEmpty) continue;
      final title = item.title.trim().isEmpty ? 'Untitled media' : item.title.trim();
      final image = item.imageUrl?.trim() ?? '';
      if (image.isEmpty) {
        findings.add(LibraryAuditFinding(
          id: '$mediaId:artwork',
          mediaId: mediaId,
          title: title,
          category: 'Missing artwork',
          description: 'No poster or artwork URL is saved for this item.',
          priority: 2,
        ));
      }
      if ((item.description?.trim() ?? '').isEmpty) {
        findings.add(LibraryAuditFinding(
          id: '$mediaId:description',
          mediaId: mediaId,
          title: title,
          category: 'Missing description',
          description: 'A synopsis has not been saved for this item.',
        ));
      }
      if ((item.playbackUrl?.trim() ?? '').isEmpty &&
          (item.trailerUrl?.trim() ?? '').isEmpty) {
        findings.add(LibraryAuditFinding(
          id: '$mediaId:source',
          mediaId: mediaId,
          title: title,
          category: 'No playback source',
          description: 'Neither a media-server URL nor a trailer URL is saved.',
          priority: 3,
        ));
      }
      final type = normalizeType(item.type);
      if ((type == 'movie' || type == 'show') &&
          item.releaseYear == null &&
          item.seriesStartYear == null &&
          item.releaseDate == null &&
          item.seriesStartDate == null) {
        findings.add(LibraryAuditFinding(
          id: '$mediaId:release',
          mediaId: mediaId,
          title: title,
          category: 'Missing release date',
          description: 'Release year/date is missing; verify before sorting by release.',
        ));
      }
    }
    findings.sort((a, b) {
      final byPriority = b.priority.compareTo(a.priority);
      if (byPriority != 0) return byPriority;
      final byCategory = a.category.compareTo(b.category);
      if (byCategory != 0) return byCategory;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return List<LibraryAuditFinding>.unmodifiable(findings);
  }
}
