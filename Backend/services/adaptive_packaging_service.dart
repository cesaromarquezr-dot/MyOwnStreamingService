// FILE: Backend/services/adaptive_packaging_service.dart.
// Purpose: Create reusable VOD HLS/DASH packages from authorized media files.
//
// This service only writes derived output under the configured adaptive cache.
// It never overwrites the source file. The calling route must authenticate
// the user, resolve the media path beneath MEDIA_ROOT, and expose the package
// through a short-lived opaque playback capability rather than a filesystem
// path. DRM encryption/licensing is intentionally not simulated here.

import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'dart:convert';

class AdaptivePackagingService {
  final String ffmpegExecutable;
  final Duration timeout;

  const AdaptivePackagingService({
    this.ffmpegExecutable = 'ffmpeg',
    this.timeout = const Duration(hours: 3),
  });

  Future<File> prepare({
    required File input,
    required Directory outputDirectory,
    required String format,
    required bool hasAudio,
  }) async {
    final normalizedFormat = format.trim().toLowerCase();
    if (normalizedFormat != 'hls' && normalizedFormat != 'dash') {
      throw ArgumentError.value(format, 'format', 'Use hls or dash.');
    }
    if (!await input.exists()) throw StateError('Media file not found.');
    await outputDirectory.create(recursive: true);

    final manifest = File('${outputDirectory.path}${Platform.pathSeparator}'
        '${normalizedFormat == 'hls' ? 'master.m3u8' : 'manifest.mpd'}');
    if (await _usable(manifest)) return manifest;

    // Do not leave an incomplete manifest from an earlier interrupted run.
    try {
      if (await outputDirectory.exists()) {
        await for (final entry in outputDirectory.list(followLinks: false)) {
          if (entry is File) {
            try { await entry.delete(); } on FileSystemException { /* best effort */ }
          } else if (entry is Directory) {
            try { await entry.delete(recursive: true); } on FileSystemException { /* best effort */ }
          }
        }
      }
    } catch (_) {
      // FFmpeg below will return a clear error if stale files cannot be removed.
    }

    final args = _arguments(
      input: input,
      outputDirectory: outputDirectory,
      format: normalizedFormat,
      hasAudio: hasAudio,
    );
    ProcessResult result;
    try {
      result = await Process.run(ffmpegExecutable, args).timeout(timeout);
    } on TimeoutException {
      throw StateError('Adaptive packaging exceeded its execution timeout.');
    } on ProcessException catch (error) {
      throw StateError('FFmpeg could not start: ${_safe(error.message)}');
    }
    if (result.exitCode != 0) {
      throw StateError('FFmpeg adaptive packaging failed: ${_safe(result.stderr.toString())}');
    }
    if (!await _usable(manifest)) {
      throw StateError('FFmpeg did not produce a valid $normalizedFormat manifest.');
    }
    return manifest;
  }

  List<String> _arguments({
    required File input,
    required Directory outputDirectory,
    required String format,
    required bool hasAudio,
  }) {
    final out = outputDirectory.absolute.path;
    final args = <String>[
      '-hide_banner', '-nostdin', '-y', '-i', input.absolute.path,
      '-filter_complex',
      '[0:v:0]split=3[v480src][v720src][v1080src];'
      '[v480src]scale=w=-2:h=480:force_original_aspect_ratio=decrease:force_divisible_by=2[v480];'
      '[v720src]scale=w=-2:h=720:force_original_aspect_ratio=decrease:force_divisible_by=2[v720];'
      '[v1080src]scale=w=-2:h=1080:force_original_aspect_ratio=decrease:force_divisible_by=2[v1080]',
    ];

    if (format == 'hls') {
      if (hasAudio) {
        // Maps are paired audio/video in the order expected by var_stream_map.
        args.addAll([
          '-map', '0:a:0', '-map', '[v480]',
          '-map', '0:a:0', '-map', '[v720]',
          '-map', '0:a:0', '-map', '[v1080]',
          '-c:a:0', 'aac', '-b:a:0', '96k',
          '-c:a:1', 'aac', '-b:a:1', '128k',
          '-c:a:2', 'aac', '-b:a:2', '160k',
          '-c:v:0', 'libx264', '-preset', 'veryfast', '-pix_fmt', 'yuv420p',
          '-b:v:0', '800k', '-maxrate:v:0', '900k', '-bufsize:v:0', '1600k',
          '-c:v:1', 'libx264', '-preset', 'veryfast', '-pix_fmt', 'yuv420p',
          '-b:v:1', '1800k', '-maxrate:v:1', '2000k', '-bufsize:v:1', '3600k',
          '-c:v:2', 'libx264', '-preset', 'veryfast', '-pix_fmt', 'yuv420p',
          '-b:v:2', '4000k', '-maxrate:v:2', '4400k', '-bufsize:v:2', '8000k',
          '-var_stream_map', 'a:0,v:0 a:1,v:1 a:2,v:2',
        ]);
      } else {
        args.addAll([
          '-map', '[v480]', '-map', '[v720]', '-map', '[v1080]',
          '-an',
          '-c:v:0', 'libx264', '-preset', 'veryfast', '-pix_fmt', 'yuv420p', '-b:v:0', '800k',
          '-c:v:1', 'libx264', '-preset', 'veryfast', '-pix_fmt', 'yuv420p', '-b:v:1', '1800k',
          '-c:v:2', 'libx264', '-preset', 'veryfast', '-pix_fmt', 'yuv420p', '-b:v:2', '4000k',
          '-var_stream_map', 'v:0 v:1 v:2',
        ]);
      }
      args.addAll([
        '-f', 'hls', '-hls_time', '4', '-hls_playlist_type', 'vod',
        '-hls_flags', 'independent_segments',
        '-master_pl_name', 'master.m3u8',
        '-hls_segment_filename', '$out${Platform.pathSeparator}segment_%v_%05d.ts',
        '$out${Platform.pathSeparator}stream_%v.m3u8',
      ]);
    } else {
      args.addAll([
        '-map', '[v480]', '-map', '[v720]', '-map', '[v1080]',
        if (hasAudio) ...['-map', '0:a:0'],
        '-c:v:0', 'libx264', '-preset', 'veryfast', '-pix_fmt', 'yuv420p', '-b:v:0', '800k',
        '-c:v:1', 'libx264', '-preset', 'veryfast', '-pix_fmt', 'yuv420p', '-b:v:1', '1800k',
        '-c:v:2', 'libx264', '-preset', 'veryfast', '-pix_fmt', 'yuv420p', '-b:v:2', '4000k',
        if (hasAudio) ...['-c:a', 'aac', '-b:a', '160k'],
        '-f', 'dash', '-seg_duration', '4', '-use_template', '1', '-use_timeline', '1',
        '-adaptation_sets', hasAudio ? 'id=0,streams=v id=1,streams=a' : 'id=0,streams=v',
        '-init_seg_name', 'init-\$RepresentationID\$.m4s',
        '-media_seg_name', 'chunk-\$RepresentationID\$-\$Number%05d\$.m4s',
        '$out${Platform.pathSeparator}manifest.mpd',
      ]);
    }
    return args;
  }

  Future<bool> _usable(File file) async {
    try {
      return await file.exists() && (await file.length()) > 20;
    } on FileSystemException {
      return false;
    }
  }

  String cacheKey({required String inputPath, required int size, required DateTime modifiedAt, required String format}) =>
      sha256.convert(utf8.encode('$inputPath|$size|${modifiedAt.toUtc().toIso8601String()}|$format|adaptive-v1')).toString();

  String _safe(String value) {
    final clean = value.replaceAll(RegExp(r'[\r\n\t]+'), ' ').trim();
    return clean.length <= 500 ? clean : clean.substring(0, 500);
  }
}
