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
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.length < 2 || normalizedQuery.length > 160) {
      throw const FormatException(
        'Search terms must contain 2 to 160 characters.',
      );
    }

    final cues = _indexes[accountId.trim()];
    if (cues == null) {
      throw StateError('Index subtitles before searching dialogue.');
    }

    final terms = normalizedQuery
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .toSet();
    final matches = <SubtitleSearchCue>[];
    var hasMore = false;
    for (final cue in cues) {
      final text = cue.text.toLowerCase();
      if (terms.every(text.contains)) {
        matches.add(cue);
        if (matches.length > _maximumResults) {
          hasMore = true;
          break;
        }
      }
    }
    return SubtitleSearchResult(
      matches: List<SubtitleSearchCue>.unmodifiable(
        matches.take(_maximumResults),
      ),
      hasMore: hasMore,
    );
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
