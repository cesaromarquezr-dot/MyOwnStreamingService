// FILE: Backend/arm/episode_order_resolver.dart
// Purpose: Resolve explicit TV episode numbering without depending on disc
// number, rip-job creation time, or import order.

import 'arm_models.dart';
import 'metadata_service.dart';

/// Parses strong, explicit episode-number signals and produces a canonical
/// ordering key. It deliberately does not guess an episode from disc position.
class ArmEpisodeOrderResolver {
  const ArmEpisodeOrderResolver();

  static final List<RegExp> _patterns = <RegExp>[
    // S01E02, S01E02E03, S01E02-E03.
    RegExp(
      r'\bS(\d{1,2})[ ._-]*E(\d{1,3})(?:[ ._-]*E?(\d{1,3}))?\b',
      caseSensitive: false,
    ),
    // 1x02 or 1x02-03.
    RegExp(
      r'\b(\d{1,2})x(\d{1,3})(?:-(\d{1,3}))?\b',
      caseSensitive: false,
    ),
    // Season 1 Episode 2.
    RegExp(
      r'\bSeason\s*(\d{1,2})\s*(?:,|[-:]|\s)+\s*Episode\s*(\d{1,3})\b',
      caseSensitive: false,
    ),
  ];

  /// Resolves metadata already supplied by ARM first, then explicit episode
  /// codes in the title/path. Pattern-only matches are flagged for review until
  /// a trusted metadata provider or the user confirms the series identity.
  ArmDiscTitle resolve(ArmDiscTitle title) {
    final currentIdentity = title.episodeIdentity;
    if (currentIdentity?.isResolved == true) {
      // Some disc scanners label every title as a generic movie. A resolved
      // canonical episode identity is stronger evidence than that broad label.
      return title.isEpisode ? title : title.withEpisodeIdentity(currentIdentity);
    }

    final metadata = title.metadata;
    final supplied = _readIdentityFromMetadata(metadata);
    if (supplied != null && supplied.isResolved) {
      return title.withEpisodeIdentity(supplied);
    }

    final candidates = <String>[
      _text(metadata['episodeCode']),
      _text(metadata['filename']),
      _text(metadata['name']),
      title.title,
      _basename(title.outputPath),
    ].where((value) => value.isNotEmpty).toList(growable: false);

    for (final candidate in candidates) {
      for (final pattern in _patterns) {
        final match = pattern.firstMatch(candidate);
        if (match == null) continue;

        final season = int.tryParse(match.group(1) ?? '');
        final episode = int.tryParse(match.group(2) ?? '');
        final endEpisode = int.tryParse(match.group(3) ?? '');
        if (season == null || episode == null || episode < 1) continue;

        final explicitSeriesTitle = _firstNonEmpty(<dynamic>[
          metadata['seriesTitle'],
          metadata['series_title'],
          metadata['showTitle'],
          metadata['show_title'],
          metadata['series'],
        ]);
        final prefix = candidate.substring(0, match.start).trim();
        final suffix = candidate.substring(match.end).trim();
        final seriesTitle = explicitSeriesTitle ?? _cleanSeriesPrefix(prefix);
        final episodeTitle = _firstNonEmpty(<dynamic>[
              metadata['episodeTitle'],
              metadata['episode_title'],
              metadata['episodeName'],
              metadata['episode_name'],
              _cleanEpisodeSuffix(suffix),
            ]) ??
            (title.title == candidate ? title.title : null);

        final identity = ArmEpisodeIdentity(
          seriesId: _firstNonEmpty(<dynamic>[
            metadata['seriesId'],
            metadata['series_id'],
            metadata['showId'],
            metadata['show_id'],
            metadata['seriesExternalId'],
        metadata['series_external_id'],
          ]),
          seriesTitle: seriesTitle,
          seasonNumber: season,
          episodeNumber: episode,
          episodeEndNumber: endEpisode,
          absoluteEpisodeNumber: _readInt(metadata['absoluteEpisodeNumber'] ?? metadata['absolute_episode_number']),
          episodeTitle: episodeTitle,
          orderScheme: _firstNonEmpty(<dynamic>[
                metadata['orderScheme'],
                metadata['order_scheme'],
                metadata['episodeOrder'],
                metadata['episode_order'],
              ]) ??
              'aired',
          confidence: 0.72,
          matchSource: 'explicit_title_pattern_pending_confirmation',
        );
        return title.withEpisodeIdentity(identity);
      }
    }

    return title;
  }

  /// Applies the explicit episode identity supplied by a metadata candidate
  /// after a user confirms that match in the import-review screen. A selected
  /// episode candidate becomes a confirmed identity, rather than a guess based
  /// only on its filename.
  ArmDiscTitle applyConfirmedMetadataMatch(
    ArmDiscTitle title,
    MetadataCandidate candidate,
  ) {
    if (candidate.entityType != MetadataEntityType.episode) return title;

    final metadata = <String, dynamic>{
      if (candidate.metadata['metadata'] is Map)
        ...Map<String, dynamic>.from(candidate.metadata['metadata'] as Map),
      ...candidate.metadata,
    };
    final existing = title.episodeIdentity;
    int? readInt(dynamic value) => value is num
        ? value.toInt()
        : int.tryParse(value?.toString() ?? '');
    String? readString(dynamic value) {
      final text = value?.toString().trim();
      return text == null || text.isEmpty ? null : text;
    }

    final identity = ArmEpisodeIdentity(
      seriesId: readString(metadata['seriesId'] ?? metadata['series_id'] ?? metadata['showId'] ??
              metadata['show_id'] ?? metadata['seriesExternalId'] ?? metadata['series_external_id']) ??
          existing?.seriesId,
      seriesTitle: readString(metadata['seriesTitle'] ?? metadata['series_title'] ?? metadata['showTitle'] ??
              metadata['show_title'] ?? metadata['series']) ??
          existing?.seriesTitle,
      seasonNumber: readInt(metadata['seasonNumber'] ?? metadata['season_number'] ?? metadata['season']) ??
          existing?.seasonNumber,
      episodeNumber: readInt(metadata['episodeNumber'] ?? metadata['episode_number'] ?? metadata['episode']) ??
          existing?.episodeNumber,
      episodeEndNumber: readInt(metadata['episodeEndNumber'] ?? metadata['episode_end_number']) ??
          existing?.episodeEndNumber,
      absoluteEpisodeNumber: readInt(metadata['absoluteEpisodeNumber'] ?? metadata['absolute_episode_number']) ??
          existing?.absoluteEpisodeNumber,
      episodeTitle: readString(metadata['episodeTitle'] ?? metadata['episode_title'] ?? metadata['episodeName'] ?? metadata['episode_name']) ??
          candidate.title,
      orderScheme: readString(metadata['orderScheme'] ?? metadata['order_scheme'] ?? metadata['episodeOrder'] ?? metadata['episode_order']) ??
          existing?.orderScheme ??
          'aired',
      confidence: 1.0,
      matchSource: 'user_confirmed:${candidate.provider.name}',
    );

    return identity.isResolved
        ? title.withEpisodeIdentity(
            identity,
            canonicalTitle: candidate.title,
            originalTitle: title.originalTitle ?? title.discTitle ?? title.title,
          )
        : title;
  }

  /// Sorts episode entries by canonical series/season/episode identity. Items
  /// that cannot be safely resolved are kept after resolved entries and sorted
  /// deterministically by display title and ID. Physical disc number is never
  /// consulted, so importing Disc 3 before Disc 1 cannot change watch order.
  List<ArmDiscTitle> sortForWatchOrder(Iterable<ArmDiscTitle> input) {
    final result = input.toList();
    result.sort((a, b) {
      final ai = a.episodeIdentity;
      final bi = b.episodeIdentity;
      final aResolved = ai?.isResolved == true;
      final bResolved = bi?.isResolved == true;
      if (aResolved != bResolved) return aResolved ? -1 : 1;

      if (aResolved && bResolved) {
        var compare = ai!.seriesKey.compareTo(bi!.seriesKey);
        if (compare != 0) return compare;
        compare = ai.seasonNumber!.compareTo(bi.seasonNumber!);
        if (compare != 0) return compare;
        compare = ai.episodeNumber!.compareTo(bi.episodeNumber!);
        if (compare != 0) return compare;
        compare = (ai.episodeEndNumber ?? ai.episodeNumber!).compareTo(
          bi.episodeEndNumber ?? bi.episodeNumber!,
        );
        if (compare != 0) return compare;
      }

      final titleCompare = a.title.toLowerCase().compareTo(b.title.toLowerCase());
      if (titleCompare != 0) return titleCompare;
      return a.id.compareTo(b.id);
    });
    return result;
  }

  ArmEpisodeIdentity? _readIdentityFromMetadata(Map<String, dynamic> metadata) {
    final nestedMetadata = metadata['metadata'];
    if (nestedMetadata is Map) {
      metadata = <String, dynamic>{
        ...Map<String, dynamic>.from(nestedMetadata),
        ...metadata,
      };
    }
    final nested = metadata['episodeIdentity'];
    if (nested is Map) {
      final identity = ArmEpisodeIdentity.fromJson(
        Map<String, dynamic>.from(nested),
      );
      return identity.isResolved ? identity : null;
    }

    final season = _readInt(metadata['seasonNumber'] ?? metadata['season_number'] ?? metadata['season']);
    final episode = _readInt(metadata['episodeNumber'] ?? metadata['episode_number'] ?? metadata['episode']);
    if (season == null || episode == null || episode < 1) return null;

    final identity = ArmEpisodeIdentity(
      seriesId: _firstNonEmpty(<dynamic>[
        metadata['seriesId'],
        metadata['series_id'],
        metadata['showId'],
        metadata['show_id'],
        metadata['seriesExternalId'],
        metadata['series_external_id'],
      ]),
      seriesTitle: _firstNonEmpty(<dynamic>[
        metadata['seriesTitle'],
        metadata['series_title'],
        metadata['showTitle'],
        metadata['show_title'],
        metadata['series'],
      ]),
      seasonNumber: season,
      episodeNumber: episode,
      episodeEndNumber: _readInt(metadata['episodeEndNumber'] ?? metadata['episode_end_number']),
      absoluteEpisodeNumber: _readInt(metadata['absoluteEpisodeNumber'] ?? metadata['absolute_episode_number']),
      episodeTitle: _firstNonEmpty(<dynamic>[
        metadata['episodeTitle'],
        metadata['episode_title'],
        metadata['episodeName'],
        metadata['episode_name'],
      ]),
      orderScheme: _firstNonEmpty(<dynamic>[
            metadata['orderScheme'],
            metadata['order_scheme'],
            metadata['episodeOrder'],
            metadata['episode_order'],
          ]) ??
          'aired',
      confidence: _readDouble(metadata['matchConfidence'] ?? metadata['match_confidence'] ?? metadata['confidence']) ?? 0.95,
      matchSource: _firstNonEmpty(<dynamic>[
            metadata['matchSource'],
            metadata['match_source'],
            metadata['source'],
          ]) ??
          'arm_episode_metadata',
    );
    return identity.isResolved ? identity : null;
  }

  String _basename(String? path) {
    if (path == null || path.trim().isEmpty) return '';
    return path.split(RegExp(r'[\\/]')).last.replaceFirst(RegExp(r'\.[^.]+$'), '');
  }

  String _cleanSeriesPrefix(String value) => value
      .replaceAll(RegExp(r'[._-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  String? _cleanEpisodeSuffix(String value) {
    final cleaned = value
        .replaceFirst(RegExp(r'^[\s._\-–—:]+'), '')
        .replaceAll(RegExp(r'[._]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  String _text(dynamic value) => value?.toString().trim() ?? '';

  String? _firstNonEmpty(Iterable<dynamic> values) {
    for (final value in values) {
      final candidate = value?.toString().trim();
      if (candidate != null && candidate.isNotEmpty) return candidate;
    }
    return null;
  }

  int? _readInt(dynamic value) => value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '');

  double? _readDouble(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');
}
