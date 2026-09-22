// FILE: `Backend/arm/arm_verifier.dart`.
// Purpose: Verifies ripped ARM media before it is allowed into the library.
//
// This file is part of the documented Flutter/home-server architecture.
//
// Verification is intentionally structural. It can establish that extracted
// media exists, can be inspected, contains the expected stream types, has a
// plausible duration, and can be decoded. It does not claim that every scene,
// chapter, song, or bonus feature expected from a particular physical release
// is present unless a trusted release-specific reference is supplied.
//
// Supported content categories include:
//   - movie / feature video
//   - television / episode video
//   - bonus-feature video
//   - music / soundtrack / album audio
//   - data or other disc content
//
// Physical-release identity is handled by the ARM models/service layer.
// This verifier only validates the extracted content itself.

import 'dart:convert';
import 'dart:io';

import 'arm_models.dart';

class ArmVerifier {
  /// Percentage represented as a decimal fraction.
  ///
  /// 0.08 means an extracted runtime may differ by up to 8% from the
  /// expected runtime before the verification fails.
  final double durationTolerance;

  const ArmVerifier({
    this.durationTolerance = 0.08,
  });

  /// Verifies extracted media using the default video-oriented behavior.
  ///
  /// This method is retained for compatibility with existing callers such as
  /// ArmService.refreshJob().
  Future<ArmVerificationResult> verify({
    required String outputPath,
    double? expectedDurationSeconds,
    int? expectedChapterCount,
  }) async {
    return verifyContent(
      outputPath: outputPath,
      contentType: ArmDiscContentType.feature,
      expectedDurationSeconds: expectedDurationSeconds,
      expectedChapterCount: expectedChapterCount,
    );
  }

  /// Verifies an extracted disc content item.
  ///
  /// The content type controls which streams are required:
  ///
  ///   feature / bonusFeature / episode
  ///       video + audio
  ///
  ///   music / soundtrack
  ///       audio
  ///
  ///   data / other
  ///       structural inspection only
  Future<ArmVerificationResult> verifyContent({
    required String outputPath,
    required ArmDiscContentType contentType,
    double? expectedDurationSeconds,
    int? expectedChapterCount,
    int? expectedAudioStreamCount,
    int? expectedVideoStreamCount,
  }) async {
    final file = await _findMediaFile(
      outputPath,
      contentType,
    );

    if (file == null) {
      return _failedResult(
        reason:
            'The extracted media could not be found on the backend host.',
        failures: [
          'Output file is missing or not accessible.',
        ],
      );
    }

    final probe = await _probe(file.path);

    if (probe == null) {
      return _failedResult(
        reason:
            'ffprobe could not read the extracted media.',
        failures: [
          'Media stream inspection failed.',
        ],
      );
    }

    final format = probe['format'] is Map
        ? Map<String, dynamic>.from(
            probe['format'] as Map,
          )
        : <String, dynamic>{};

    final streams = _mapsFrom(
      probe['streams'],
    );

    final chapters = _mapsFrom(
      probe['chapters'],
    );

    final duration = _number(
      format['duration'] ??
          probe['duration'],
    );

    final videoStreams = streams
        .where(
          (stream) =>
              stream['codec_type']?.toString() ==
              'video',
        )
        .toList(growable: false);

    final audioStreams = streams
        .where(
          (stream) =>
              stream['codec_type']?.toString() ==
              'audio',
        )
        .toList(growable: false);

    final subtitleStreams = streams
        .where(
          (stream) =>
              stream['codec_type']?.toString() ==
              'subtitle',
        )
        .toList(growable: false);

    final hasVideo = videoStreams.isNotEmpty;
    final hasAudio = audioStreams.isNotEmpty;

    final checks = <String>[
      'Media file exists.',
      'ffprobe stream inspection completed.',
    ];

    final failures = <String>[];

    final requiresVideo = _requiresVideo(
      contentType,
    );

    final requiresAudio = _requiresAudio(
      contentType,
    );

    if (requiresVideo && !hasVideo) {
      failures.add(
        'No video stream was found for this video content.',
      );
    }

    if (requiresAudio && !hasAudio) {
      failures.add(
        'No audio stream was found for this audio-bearing content.',
      );
    }

    if (!requiresVideo && !requiresAudio) {
      if (streams.isEmpty &&
          !_hasRecognizedDataFormat(format)) {
        failures.add(
          'No recognizable media streams or data format were found.',
        );
      } else {
        checks.add(
          'Content has a recognizable structure for its declared type.',
        );
      }
    }

    if (duration == null || duration <= 0) {
      if (requiresVideo || requiresAudio) {
        failures.add(
          'The extracted media has no valid duration.',
        );
      }
    } else {
      checks.add(
        'Extracted duration is valid.',
      );
    }

    if (expectedDurationSeconds != null &&
        duration != null &&
        expectedDurationSeconds > 0) {
      final difference =
          (duration - expectedDurationSeconds).abs() /
              expectedDurationSeconds;

      if (difference > durationTolerance) {
        failures.add(
          'Runtime differs from the expected release by '
          '${(difference * 100).toStringAsFixed(1)}%.',
        );
      } else {
        checks.add(
          'Runtime is within the expected release tolerance.',
        );
      }
    }

    if (expectedChapterCount != null &&
        expectedChapterCount > 0) {
      if (chapters.length < expectedChapterCount) {
        failures.add(
          'Only ${chapters.length} chapters were found; '
          'expected at least $expectedChapterCount.',
        );
      } else {
        checks.add(
          'Chapter structure is present.',
        );
      }
    }

    if (expectedAudioStreamCount != null &&
        expectedAudioStreamCount > 0) {
      if (audioStreams.length <
          expectedAudioStreamCount) {
        failures.add(
          'Only ${audioStreams.length} audio streams were found; '
          'expected at least $expectedAudioStreamCount.',
        );
      } else {
        checks.add(
          'Expected audio stream count is present.',
        );
      }
    }

    if (expectedVideoStreamCount != null &&
        expectedVideoStreamCount > 0) {
      if (videoStreams.length <
          expectedVideoStreamCount) {
        failures.add(
          'Only ${videoStreams.length} video streams were found; '
          'expected at least $expectedVideoStreamCount.',
        );
      } else {
        checks.add(
          'Expected video stream count is present.',
        );
      }
    }

    final decodeResult = await _decode(
      file.path,
      contentType: contentType,
      hasVideo: hasVideo,
      hasAudio: hasAudio,
    );

    if (decodeResult.exitCode != 0) {
      final errorText = _truncate(
        decodeResult.stderr.toString(),
      );

      failures.add(
        errorText.isEmpty
            ? 'Media decode reported errors.'
            : 'Media decode reported errors: $errorText',
      );
    } else {
      checks.add(
        'Media decode completed without ffmpeg errors.',
      );
    }

    final passed = failures.isEmpty;

    final score = _score(
      failures.length,
    );

    return ArmVerificationResult(
      passed: passed,
      score: score,
      reason: passed
          ? 'Disc content passed structural integrity checks.'
          : 'Disc content failed one or more structural integrity checks.',
      checks: checks,
      failures: failures,
      durationSeconds: duration,
      expectedDurationSeconds: expectedDurationSeconds,
      chapterCount: chapters.length,
      expectedChapterCount: expectedChapterCount,
      hasVideo: hasVideo,
      hasAudio: hasAudio,
      contentFingerprintAvailable: false,
    );
  }

  /// Verifies a video feature explicitly.
  Future<ArmVerificationResult> verifyVideo({
    required String outputPath,
    double? expectedDurationSeconds,
    int? expectedChapterCount,
  }) {
    return verifyContent(
      outputPath: outputPath,
      contentType: ArmDiscContentType.feature,
      expectedDurationSeconds: expectedDurationSeconds,
      expectedChapterCount: expectedChapterCount,
    );
  }

  /// Verifies a bonus feature such as deleted scenes, trailers,
  /// documentaries, interviews, or behind-the-scenes material.
  Future<ArmVerificationResult> verifyBonusFeature({
    required String outputPath,
    double? expectedDurationSeconds,
    int? expectedChapterCount,
  }) {
    return verifyContent(
      outputPath: outputPath,
      contentType: ArmDiscContentType.bonusFeature,
      expectedDurationSeconds: expectedDurationSeconds,
      expectedChapterCount: expectedChapterCount,
    );
  }

  /// Verifies a music/audio extraction without incorrectly requiring video.
  Future<ArmVerificationResult> verifyMusic({
    required String outputPath,
    double? expectedDurationSeconds,
  }) {
    return verifyContent(
      outputPath: outputPath,
      contentType: ArmDiscContentType.song,
      expectedDurationSeconds: expectedDurationSeconds,
    );
  }

  Future<File?> _findMediaFile(
    String outputPath,
    ArmDiscContentType contentType,
  ) async {
    final entityType = FileSystemEntity.typeSync(
      outputPath,
    );

    if (entityType == FileSystemEntityType.file) {
      return File(outputPath);
    }

    if (entityType != FileSystemEntityType.directory) {
      return null;
    }

    File? best;
    var bestScore = -1.0;

    await for (final entity
        in Directory(outputPath).list(
      recursive: true,
    )) {
      if (entity is! File) {
        continue;
      }

      final path = entity.path.toLowerCase();

      final extensionScore =
          _extensionScore(
        path,
        contentType,
      );

      if (extensionScore <= 0) {
        continue;
      }

      final size = await _safeFileSize(entity);

      if (size <= 0) {
        continue;
      }

      final score =
          extensionScore +
              (size / (1024 * 1024 * 1024));

      if (score > bestScore) {
        best = entity;
        bestScore = score;
      }
    }

    return best;
  }

  double _extensionScore(
    String path,
    ArmDiscContentType contentType,
  ) {
    const videoExtensions = [
      '.mkv',
      '.mp4',
      '.m4v',
      '.ts',
      '.m2ts',
      '.avi',
      '.mov',
      '.webm',
    ];

    const audioExtensions = [
      '.flac',
      '.wav',
      '.alac',
      '.m4a',
      '.mp3',
      '.aac',
      '.ogg',
      '.opus',
      '.ape',
    ];

    const dataOrContainerExtensions = [
      '.iso',
      '.img',
      '.bin',
      '.cue',
    ];

    if (_requiresVideo(contentType)) {
      if (videoExtensions.any(
        path.endsWith,
      )) {
        return 10;
      }

      return 0;
    }

    if (_requiresAudio(contentType)) {
      if (audioExtensions.any(
        path.endsWith,
      )) {
        return 10;
      }

      // Some music rips may remain inside a video/container file.
      if (videoExtensions.any(
        path.endsWith,
      )) {
        return 5;
      }

      return 0;
    }

    if (dataOrContainerExtensions.any(
      path.endsWith,
    )) {
      return 10;
    }

    if (videoExtensions.any(
      path.endsWith,
    )) {
      return 5;
    }

    if (audioExtensions.any(
      path.endsWith,
    )) {
      return 5;
    }

    return 0;
  }

  Future<Map<String, dynamic>?> _probe(
    String path,
  ) async {
    final result = await Process.run(
      'ffprobe',
      [
        '-v',
        'error',
        '-show_entries',
        'format=duration,format_name,format_long_name',
        '-show_streams',
        '-show_chapters',
        '-of',
        'json',
        path,
      ],
    );

    if (result.exitCode != 0) {
      return null;
    }

    try {
      final decoded = jsonDecode(
        result.stdout.toString(),
      );

      return decoded is Map
          ? Map<String, dynamic>.from(
              decoded,
            )
          : null;
    } catch (_) {
      return null;
    }
  }

  Future<ProcessResult> _decode(
    String path, {
    required ArmDiscContentType contentType,
    required bool hasVideo,
    required bool hasAudio,
  }) async {
    final args = <String>[
      '-v',
      'error',
      '-i',
      path,
    ];

    if (_requiresVideo(contentType) &&
        hasVideo) {
      args.addAll([
        '-map',
        '0:v:0',
      ]);
    } else if (_requiresAudio(contentType) &&
        hasAudio) {
      args.addAll([
        '-map',
        '0:a:0',
      ]);
    } else if (hasVideo) {
      args.addAll([
        '-map',
        '0:v:0',
      ]);
    } else if (hasAudio) {
      args.addAll([
        '-map',
        '0:a:0',
      ]);
    } else {
      // Data-only/other content can still be inspected by ffprobe without
      // attempting to decode a nonexistent stream.
      return ProcessResult(
        0,
        0,
        '',
        '',
      );
    }

    args.addAll([
      '-f',
      'null',
      '-',
    ]);

    return Process.run(
      'ffmpeg',
      args,
    );
  }

  bool _requiresVideo(
    ArmDiscContentType contentType,
  ) {
    switch (contentType) {
      case ArmDiscContentType.feature:
      case ArmDiscContentType.episode:
      case ArmDiscContentType.bonusFeature:
      case ArmDiscContentType.deletedScene:
      case ArmDiscContentType.commentary:
      case ArmDiscContentType.trailer:
      case ArmDiscContentType.makingOf:
      case ArmDiscContentType.interview:
      case ArmDiscContentType.musicVideo:
        return true;

      case ArmDiscContentType.soundtrack:
      case ArmDiscContentType.song:
      case ArmDiscContentType.album:
      case ArmDiscContentType.data:
      case ArmDiscContentType.subtitle:
      case ArmDiscContentType.menu:
      case ArmDiscContentType.other:
        return false;
    }
  }

  bool _requiresAudio(
    ArmDiscContentType contentType,
  ) {
    switch (contentType) {
      case ArmDiscContentType.feature:
      case ArmDiscContentType.episode:
      case ArmDiscContentType.bonusFeature:
      case ArmDiscContentType.deletedScene:
      case ArmDiscContentType.commentary:
      case ArmDiscContentType.trailer:
      case ArmDiscContentType.makingOf:
      case ArmDiscContentType.interview:
      case ArmDiscContentType.musicVideo:
      case ArmDiscContentType.soundtrack:
      case ArmDiscContentType.song:
      case ArmDiscContentType.album:
        return true;

      case ArmDiscContentType.data:
      case ArmDiscContentType.subtitle:
      case ArmDiscContentType.menu:
      case ArmDiscContentType.other:
        return false;
    }
  }

  bool _hasRecognizedDataFormat(
    Map<String, dynamic> format,
  ) {
    final name = format['format_name']
        ?.toString()
        .trim();

    return name != null &&
        name.isNotEmpty;
  }

  List<Map<String, dynamic>> _mapsFrom(
    dynamic value,
  ) {
    if (value is! List) {
      return <Map<String, dynamic>>[];
    }

    return value
        .whereType<Map>()
        .map(
          (item) => Map<String, dynamic>.from(
            item,
          ),
        )
        .toList(growable: false);
  }

  List<String> _codecNames(
    List<Map<String, dynamic>> streams,
  ) {
    return streams
        .map(
          (stream) =>
              stream['codec_name']
                  ?.toString()
                  .trim() ??
              '',
        )
        .where(
          (codec) => codec.isNotEmpty,
        )
        .toSet()
        .toList(growable: false);
  }

  Future<int> _safeFileSize(
    File file,
  ) async {
    try {
      return await file.length();
    } catch (_) {
      return 0;
    }
  }

  ArmVerificationResult _failedResult({
    required String reason,
    required List<String> failures,
  }) {
    return ArmVerificationResult(
      passed: false,
      score: 0,
      reason: reason,
      failures: failures,
      checks: const [],
      contentFingerprintAvailable: false,
    );
  }

  double _score(
    int failureCount,
  ) {
    if (failureCount <= 0) {
      return 100;
    }

    return (100.0 -
            failureCount * 25.0)
        .clamp(0.0, 100.0);
  }

  double? _number(
    dynamic value,
  ) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value?.toString() ?? '',
    );
  }

  String _truncate(
    String value, {
    int maxLength = 1000,
  }) {
    final normalized = value.trim();

    if (normalized.length <= maxLength) {
      return normalized;
    }

    return '${normalized.substring(0, maxLength)}…';
  }
}