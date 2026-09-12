// FILE: `Backend/arm/arm_verifier.dart`.
// Purpose: Implements the arm verifier portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'dart:convert';
import 'dart:io';

import 'arm_models.dart';

/// Verifies a ripped media file before the user is allowed to add it to the
/// library. This is intentionally structural: read/decode errors, missing
/// streams, severe duration mismatches and chapter mismatches are rejected.
///
/// A true scene-by-scene comparison requires a trusted reference fingerprint
/// for the exact release. The verifier therefore never claims that it can
/// identify a particular missing scene without that reference.
class ArmVerifier {
  final double durationTolerance;

  const ArmVerifier({
    this.durationTolerance = 0.08,
  });

  /// Performs `verify` for this feature. Update this documentation when its contract changes.
  Future<ArmVerificationResult> verify({
    required String outputPath,
    double? expectedDurationSeconds,
    int? expectedChapterCount,
  }) async {
    final file = await _findVideoFile(outputPath);
    if (file == null) {
      return ArmVerificationResult(
        passed: false,
        score: 0,
        reason: 'The ripped video could not be found on the backend host.',
        failures: ['Output file is missing or not accessible.'],
      );
    }

    final probe = await _probe(file.path);
    if (probe == null) {
      return ArmVerificationResult(
        passed: false,
        score: 0,
        reason: 'ffprobe could not read the extracted video.',
        failures: ['Media stream inspection failed.'],
      );
    }

    final duration = _number(probe['duration']);
    final streams = probe['streams'] is List ? probe['streams'] as List : [];
    final chapters = probe['chapters'] is List ? probe['chapters'] as List : [];

    final hasVideo = streams.any(
      (stream) => stream is Map && stream['codec_type']?.toString() == 'video',
    );
    final hasAudio = streams.any(
      (stream) => stream is Map && stream['codec_type']?.toString() == 'audio',
    );

    final checks = <String>[
      'Video file exists.',
      'ffprobe stream inspection completed.',
    ];
    final failures = <String>[];

    if (!hasVideo) failures.add('No video stream was found.');
    if (!hasAudio) failures.add('No audio stream was found.');

    if (duration == null || duration <= 0) {
      failures.add('The extracted video has no valid duration.');
    }

    if (expectedDurationSeconds != null &&
        duration != null &&
        expectedDurationSeconds > 0) {
      final difference =
          (duration - expectedDurationSeconds).abs() / expectedDurationSeconds;
      if (difference > durationTolerance) {
        failures.add(
          'Runtime differs from the expected release by '
          '${(difference * 100).toStringAsFixed(1)}%.',
        );
      } else {
        checks.add('Runtime is within the expected release tolerance.');
      }
    }

    if (expectedChapterCount != null && expectedChapterCount > 0) {
      if (chapters.length < expectedChapterCount) {
        failures.add(
          'Only ${chapters.length} chapters were found; '
          'expected at least $expectedChapterCount.',
        );
      } else {
        checks.add('Chapter structure is present.');
      }
    }

    final decodeExit = await Process.run(
      'ffmpeg',
      ['-v', 'error', '-i', file.path, '-map', '0:v:0', '-f', 'null', '-'],
    );

    if (decodeExit.exitCode != 0) {
      failures.add(
        'Full video decode reported errors. The disc may contain corrupted '
        'or unreadable content.',
      );
    } else {
      checks.add('Full video decode completed without ffmpeg errors.');
    }

    final passed = failures.isEmpty;
    final score = passed
        ? 100.0
        : (100.0 - failures.length * 25.0).clamp(0.0, 100.0);

    return ArmVerificationResult(
      passed: passed,
      score: score,
      reason: passed
          ? 'Disc content passed structural integrity checks.'
          : 'Disc rejected because the extracted content failed integrity checks.',
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

  /// Performs `_findVideoFile` for this feature. Update this documentation when its contract changes.
  Future<File?> _findVideoFile(String outputPath) async {
    final entity = FileSystemEntity.typeSync(outputPath);
    if (entity == FileSystemEntityType.file) {
      return File(outputPath);
    }

    if (entity != FileSystemEntityType.directory) return null;

    File? best;
    var bestSize = -1;
    await for (final entity in Directory(outputPath).list(recursive: true)) {
      if (entity is! File) continue;
      final lower = entity.path.toLowerCase();
      if (!['.mkv', '.mp4', '.m4v', '.ts', '.m2ts', '.avi']
          .any(lower.endsWith)) {
        continue;
      }
      final size = await entity.length();
      if (size > bestSize) {
        best = entity;
        bestSize = size;
      }
    }
    return best;
  }

  Future<Map<String, dynamic>?> _probe(String path) async {
    final result = await Process.run(
      'ffprobe',
      [
        '-v',
        'error',
        '-show_entries',
        'format=duration',
        '-show_streams',
        '-show_chapters',
        '-of',
        'json',
        path,
      ],
    );

    if (result.exitCode != 0) return null;

    try {
      final decoded = jsonDecode(result.stdout.toString());
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  double? _number(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');
}
