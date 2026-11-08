import 'dart:io';

class SubtitleSearchCue {
  const SubtitleSearchCue({
    required this.mediaId,
    required this.startMs,
    required this.text,
  });

  final String mediaId;
  final int startMs;
  final String text;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'mediaId': mediaId,
        'startMs': startMs,
        'text': text,
      };
}

class SubtitleIndexSummary {
  const SubtitleIndexSummary({
    required this.indexedFiles,
    required this.indexedCues,
    required this.skippedFiles,
    required this.warnings,
  });

  final int indexedFiles;
  final int indexedCues;
  final int skippedFiles;
  final List<String> warnings;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'indexedFiles': indexedFiles,
        'indexedCues': indexedCues,
        'skippedFiles': skippedFiles,
        'warnings': warnings,
      };
}

class SubtitleSearchResult {
  const SubtitleSearchResult({
    required this.matches,
    required this.hasMore,
  });

  final List<SubtitleSearchCue> matches;
  final bool hasMore;
}

class SubtitleSearchService {
  static const int _maximumActiveAccounts = 2;
  static const int _maximumVisitedFiles = 100000;
  static const int _maximumSubtitleFiles = 2500;
  static const int _maximumSubtitleFileBytes = 2 * 1024 * 1024;
  static const int _maximumIndexBytes = 16 * 1024 * 1024;
  static const int _maximumIndexedCues = 100000;
  static const int _maximumResults = 100;

  static final RegExp _mediaExtension =
      RegExp(r'\.(mkv|mp4|m4v|avi|mov|webm|ts|m2ts)$', caseSensitive: false);
  static final RegExp _subtitleExtension =
      RegExp(r'\.(srt|vtt)$', caseSensitive: false);
  static final RegExp _timingLine = RegExp(
    r'((?:\d{1,}:)?\d{2}:\d{2}[,.]\d{3})\s+-->\s+'
    r'((?:\d{1,}:)?\d{2}:\d{2}[,.]\d{3})',
  );
  static final RegExp _htmlTag = RegExp(r'<[^>]*>');
  static final RegExp _assTag = RegExp(r'\{\\[^}]*\}');
  static final RegExp _htmlEntity = RegExp(
    r'&(amp|lt|gt|quot|apos|#39|nbsp);',
    caseSensitive: false,
  );

  final Map<String, List<SubtitleSearchCue>> _indexes =
      <String, List<SubtitleSearchCue>>{};

  Future<SubtitleIndexSummary> index({
    required String accountId,
    required Directory mediaRoot,
  }) async {
    final cleanAccountId = accountId.trim();
    if (cleanAccountId.isEmpty) {
      throw const FormatException('An authenticated account is required.');
    }
    if (!await mediaRoot.exists()) {
      throw const FileSystemException('Media root does not exist.');
    }

    final canonicalRoot = await mediaRoot.resolveSymbolicLinks();
    final rootPrefix = _rootPrefix(canonicalRoot);
    final mediaByDirectory = <String, List<_MediaFile>>{};
    final subtitleFiles = <_SubtitleFile>[];
    var visitedFiles = 0;
    var reachedFileLimit = false;

    await for (final entity
        in Directory(canonicalRoot).list(recursive: true, followLinks: false)) {
      if (entity is! File ||
          await FileSystemEntity.type(entity.path, followLinks: false) !=
              FileSystemEntityType.file) {
        continue;
      }

      visitedFiles++;
      if (visitedFiles > _maximumVisitedFiles) {
        reachedFileLimit = true;
        break;
      }

      final path = _relativePath(entity.path, rootPrefix);
      if (path == null) continue;
      final name = path.split('/').last;
      final directory =
          path.contains('/') ? path.substring(0, path.lastIndexOf('/')) : '';
      if (_mediaExtension.hasMatch(name)) {
        final stem = name.substring(0, name.lastIndexOf('.')).toLowerCase();
        mediaByDirectory.putIfAbsent(directory, () => <_MediaFile>[]).add(
              _MediaFile(path, stem),
            );
      } else if (_subtitleExtension.hasMatch(name)) {
        subtitleFiles.add(_SubtitleFile(entity, directory, name));
        if (subtitleFiles.length > _maximumSubtitleFiles) {
          subtitleFiles.removeLast();
          reachedFileLimit = true;
          break;
        }
      }
    }

    for (final files in mediaByDirectory.values) {
      files
          .sort((left, right) => right.stem.length.compareTo(left.stem.length));
    }

    final cues = <SubtitleSearchCue>[];
    var indexedFiles = 0;
    var skippedFiles = 0;
    var indexedBytes = 0;
    final warnings = <String>[];

    for (final subtitle in subtitleFiles) {
      final media = _matchingMedia(
        subtitle,
        mediaByDirectory[subtitle.directory] ?? const <_MediaFile>[],
      );
      if (media == null) {
        skippedFiles++;
        continue;
      }

      final canonicalSubtitlePath = await subtitle.file.resolveSymbolicLinks();
      if (!_isInsideRoot(canonicalRoot, canonicalSubtitlePath)) {
        skippedFiles++;
        continue;
      }
      final safeSubtitleFile = File(canonicalSubtitlePath);
      final length = await safeSubtitleFile.length();
      if (length <= 0 || length > _maximumSubtitleFileBytes) {
        skippedFiles++;
        continue;
      }
      if (indexedBytes + length > _maximumIndexBytes) {
        warnings.add('The subtitle index reached its storage limit.');
        break;
      }

      List<SubtitleSearchCue> parsed;
      try {
        parsed = parse(
          await safeSubtitleFile.readAsString(),
          mediaId: media,
        );
      } on FormatException {
        skippedFiles++;
        continue;
      }
      if (parsed.isEmpty) {
        skippedFiles++;
        continue;
      }
      if (cues.length + parsed.length > _maximumIndexedCues) {
        warnings.add('The subtitle index reached its cue limit.');
        break;
      }

      cues.addAll(parsed);
      indexedBytes += length;
      indexedFiles++;
    }

    if (reachedFileLimit) {
      warnings.add('The library scan reached its file-count limit.');
    }

    _rememberIndex(cleanAccountId, cues);
    return SubtitleIndexSummary(
      indexedFiles: indexedFiles,
      indexedCues: cues.length,
      skippedFiles: skippedFiles,
      warnings: List<String>.unmodifiable(warnings),
    );
  }

  SubtitleSearchResult search({
    required String accountId,
    required String query,
  }) {
    final normalizedQuery = _normalizeSearchText(query);
    if (normalizedQuery.length < 2 || normalizedQuery.length > 500) {
      throw const FormatException(
        'Search terms must contain 2 to 500 characters.',
      );
    }

    final cues = _indexes[accountId.trim()];
    if (cues == null) {
      throw StateError('Index subtitles before searching dialogue.');
    }

    final queryTerms = _searchTerms(normalizedQuery);
    if (queryTerms.isEmpty) {
      throw const FormatException('Enter meaningful dialogue words to search.');
    }

    // Subtitle sentences are often split over several short SRT/VTT cues.
    // Search a bounded rolling window so a remembered line can span adjacent
    // caption cards instead of requiring every word to live in one cue.
    // Pre-tokenize each cue once; the index can contain up to 100,000 cues.
    final cueWords = cues
        .map((cue) => _normalizeSearchText(cue.text)
            .split(' ')
            .where((word) => word.isNotEmpty)
            .toSet())
        .toList(growable: false);
    final minimumCoverage = queryTerms.length <= 3 ? 0.999 : 0.68;
    final candidates = <_ScoredCue>[];
    for (var start = 0; start < cues.length; start++) {
      final first = cues[start];
      final combined = StringBuffer();
      final candidateWords = <String>{};
      var bestEnd = -1;
      var bestScore = 0.0;
      var bestText = '';
      final lastAllowed = (start + 15).clamp(0, cues.length - 1);

      for (var end = start; end <= lastAllowed; end++) {
        final cue = cues[end];
        if (cue.mediaId != first.mediaId) break;
        if (end > start && cue.startMs - first.startMs > 90000) break;
        if (combined.length > 0) combined.write(' ');
        combined.write(cue.text);
        final text = combined.toString();
        if (text.length > 1800) break;
        candidateWords.addAll(cueWords[end]);

        final score = _termCoverage(
          queryTerms,
          candidateWords,
          minimumCoverage: minimumCoverage,
        );
        if (score > bestScore) {
          bestScore = score;
          bestEnd = end;
          bestText = text;
        }
        if (score >= 0.999) break;
      }

      if (bestEnd >= start && bestScore >= minimumCoverage) {
        candidates.add(_ScoredCue(
          cue: SubtitleSearchCue(
            mediaId: first.mediaId,
            startMs: first.startMs,
            text: bestText.length > 700
                ? '${bestText.substring(0, 697)}…'
                : bestText,
          ),
          score: bestScore,
        ));
      }
    }

    candidates.sort((left, right) {
      final score = right.score.compareTo(left.score);
      if (score != 0) return score;
      return left.cue.startMs.compareTo(right.cue.startMs);
    });

    // Overlapping rolling windows are the same remembered scene. Keep the
    // strongest hit per nearby timestamp while preserving separate episodes.
    final deduplicated = <_ScoredCue>[];
    for (final candidate in candidates) {
      final duplicate = deduplicated.any((existing) =>
          existing.cue.mediaId == candidate.cue.mediaId &&
          (existing.cue.startMs - candidate.cue.startMs).abs() <= 12000);
      if (!duplicate) deduplicated.add(candidate);
      if (deduplicated.length > _maximumResults) break;
    }

    final hasMore = deduplicated.length > _maximumResults;
    return SubtitleSearchResult(
      matches: List<SubtitleSearchCue>.unmodifiable(
        deduplicated.take(_maximumResults).map((entry) => entry.cue),
      ),
      hasMore: hasMore,
    );
  }

  static String _normalizeSearchText(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r"[^a-z0-9']+"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static Set<String> _searchTerms(String value) {
    const stopWords = <String>{
      'a', 'an', 'the', 'and', 'or', 'but', 'then', 'when', 'where', 'what',
      'who', 'why', 'how', 'to', 'of', 'in', 'on', 'at', 'by', 'as', 'is',
      'are', 'was', 'were', 'be', 'been', 'being', 'i', 'me', 'my', 'you',
      'your', 'we', 'our', 'they', 'them', 'he', 'she', 'it', 'this', 'that',
      'do', 'does', 'did', 'just', 'think', 'know', 'answer', 'say', 'said',
    };
    final words = value
        .split(' ')
        .map((word) => word.trim())
        .where((word) => word.length >= 2 && !stopWords.contains(word))
        .toSet();
    return words.isEmpty
        ? value.split(' ').where((word) => word.length >= 2).toSet()
        : words;
  }

  static double _termCoverage(
    Set<String> queryTerms,
    Set<String> candidateWords, {
    required double minimumCoverage,
  }) {
    if (candidateWords.isEmpty) return 0;
    final exactMatches = queryTerms.intersection(candidateWords);
    final minimumMatched = (queryTerms.length * minimumCoverage).ceil();
    if (exactMatches.length >= minimumMatched) {
      return exactMatches.length / queryTerms.length;
    }

    // Fuzzy edit-distance checks are relatively expensive. Only run them when
    // a small number of misspelled words could lift this window to the match
    // threshold; ordinary non-matching subtitle windows stay inexpensive.
    final fuzzyBudget = queryTerms.length <= 3
        ? 0
        : (queryTerms.length * 0.15).ceil().clamp(1, 3).toInt();
    if (exactMatches.length + fuzzyBudget < minimumMatched) {
      return exactMatches.length / queryTerms.length;
    }

    var matched = exactMatches.length;
    for (final term in queryTerms.difference(exactMatches)) {
      final maximumDistance = term.length >= 7 ? 2 : 1;
      final foundTypo = candidateWords.any((word) =>
          (word.length - term.length).abs() <= maximumDistance &&
          _editDistanceAtMost(word, term, maximumDistance));
      if (foundTypo) {
        matched++;
        if (matched >= minimumMatched) return matched / queryTerms.length;
      }
    }
    return matched / queryTerms.length;
  }

  static bool _editDistanceAtMost(String left, String right, int maximum) {
    if (left == right) return true;
    if ((left.length - right.length).abs() > maximum) return false;
    var previous = List<int>.generate(right.length + 1, (index) => index);
    for (var i = 1; i <= left.length; i++) {
      final current = List<int>.filled(right.length + 1, maximum + 1);
      current[0] = i;
      var rowMinimum = current[0];
      for (var j = 1; j <= right.length; j++) {
        final substitution =
            left.codeUnitAt(i - 1) == right.codeUnitAt(j - 1) ? 0 : 1;
        current[j] = <int>[
          current[j - 1] + 1,
          previous[j] + 1,
          previous[j - 1] + substitution,
        ].reduce((a, b) => a < b ? a : b);
        if (current[j] < rowMinimum) rowMinimum = current[j];
      }
      if (rowMinimum > maximum) return false;
      previous = current;
    }
    return previous[right.length] <= maximum;
  }

  static List<SubtitleSearchCue> parse(
    String content, {
    required String mediaId,
  }) {
    final cues = <SubtitleSearchCue>[];
    final blocks = content.replaceAll('\r\n', '\n').split(RegExp(r'\n\s*\n'));
    for (final block in blocks) {
      final lines = block.split('\n');
      var timingLineIndex = -1;
      RegExpMatch? timing;
      for (var index = 0; index < lines.length; index++) {
        final match = _timingLine.firstMatch(lines[index]);
        if (match != null) {
          timingLineIndex = index;
          timing = match;
          break;
        }
      }
      if (timing == null) continue;

      final startMs = _parseTimestamp(timing.group(1)!);
      final endMs = _parseTimestamp(timing.group(2)!);
      if (startMs == null || endMs == null || endMs < startMs) continue;

      final rawText = lines.skip(timingLineIndex + 1).join(' ');
      final text = _decodeEntities(
        rawText.replaceAll(_htmlTag, '').replaceAll(_assTag, '').trim(),
      ).replaceAll(RegExp(r'\s+'), ' ');
      if (text.isEmpty || text.length > 2000) continue;

      cues.add(SubtitleSearchCue(
        mediaId: mediaId,
        startMs: startMs,
        text: text,
      ));
    }
    return List<SubtitleSearchCue>.unmodifiable(cues);
  }

  static String? _matchingMedia(
    _SubtitleFile subtitle,
    List<_MediaFile> candidates,
  ) {
    final subtitleStem = subtitle.name
        .substring(0, subtitle.name.lastIndexOf('.'))
        .toLowerCase();
    for (final media in candidates) {
      if (subtitleStem == media.stem ||
          subtitleStem.startsWith('${media.stem}.')) {
        return media.path;
      }
    }
    return null;
  }

  static int? _parseTimestamp(String value) {
    final parts = value.replaceAll(',', '.').split(':');
    final secondsAndMillis = parts.last.split('.');
    if (secondsAndMillis.length != 2) return null;
    final seconds = int.tryParse(secondsAndMillis[0]);
    final millis = int.tryParse(secondsAndMillis[1]);
    final minutes =
        parts.length >= 2 ? int.tryParse(parts[parts.length - 2]) : null;
    final hours = parts.length == 3 ? int.tryParse(parts[0]) : 0;
    if (seconds == null ||
        millis == null ||
        minutes == null ||
        hours == null ||
        seconds > 59 ||
        millis > 999 ||
        minutes > 59) {
      return null;
    }
    return ((hours * 3600 + minutes * 60 + seconds) * 1000) + millis;
  }

  static String _decodeEntities(String value) => value.replaceAllMapped(
        _htmlEntity,
        (match) => switch (match.group(1)!.toLowerCase()) {
          'amp' => '&',
          'lt' => '<',
          'gt' => '>',
          'quot' => '"',
          'apos' || '#39' => "'",
          'nbsp' => ' ',
          _ => match.group(0)!,
        },
      );

  static String _rootPrefix(String path) {
    final normalized = path.replaceAll('\\', '/');
    return normalized.endsWith('/') ? normalized : '$normalized/';
  }

  static String? _relativePath(String path, String rootPrefix) {
    final normalized = path.replaceAll('\\', '/');
    final root = rootPrefix.toLowerCase();
    if (!normalized.toLowerCase().startsWith(root)) return null;
    return normalized.substring(rootPrefix.length);
  }

  static bool _isInsideRoot(String rootPath, String candidatePath) {
    final normalizedRoot = rootPath.replaceAll('\\', '/');
    final rootPrefix =
        normalizedRoot.endsWith('/') ? normalizedRoot : '$normalizedRoot/';
    return candidatePath
        .replaceAll('\\', '/')
        .toLowerCase()
        .startsWith(rootPrefix.toLowerCase());
  }

  void _rememberIndex(String accountId, List<SubtitleSearchCue> cues) {
    _indexes.remove(accountId);
    if (_indexes.length >= _maximumActiveAccounts) {
      _indexes.remove(_indexes.keys.first);
    }
    _indexes[accountId] = List<SubtitleSearchCue>.unmodifiable(cues);
  }
}

class _ScoredCue {
  const _ScoredCue({required this.cue, required this.score});
  final SubtitleSearchCue cue;
  final double score;
}

class _MediaFile {
  const _MediaFile(this.path, this.stem);

  final String path;
  final String stem;
}

class _SubtitleFile {
  const _SubtitleFile(this.file, this.directory, this.name);

  final File file;
  final String directory;
  final String name;
}
