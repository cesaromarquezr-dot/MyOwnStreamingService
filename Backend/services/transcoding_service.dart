// FILE: Backend/services/transcoding_service.dart.
// Purpose: Selects direct play, remux, audio-only transcode, or full transcode and creates cached copies.

import 'dart:async';
import 'dart:io';

import '../models/media_capabilities.dart';
import '../models/playback_profile.dart';
import 'media_analyzer_service.dart';
import 'transcode_cache_service.dart';

class TranscodingService {
  final MediaAnalyzerService analyzer;
  final TranscodeCacheService cache;
  final String ffmpegExecutable;

  const TranscodingService({
    required this.analyzer,
    required this.cache,
    this.ffmpegExecutable = 'ffmpeg',
  });

  PlaybackProfile decide(MediaProbe media, MediaCapabilities device) {
    final videoOk = device.videoCodecs.contains(media.videoCodec) &&
        media.width <= device.maxWidth && media.height <= device.maxHeight;
    final audioOk = device.audioCodecs.contains(media.audioCodec);
    final containerOk = device.containers.contains(media.container);

    if (videoOk && audioOk && containerOk) {
      return PlaybackProfile(
        mode: 'directPlay',
        videoCodec: media.videoCodec,
        audioCodec: media.audioCodec,
        container: media.container,
        width: media.width,
        height: media.height,
        bitrateKbps: media.bitrateKbps,
        reason: 'Device supports the original streams and container.',
      );
    }
    if (videoOk && audioOk && !containerOk) {
      return PlaybackProfile(
        mode: 'remux',
        videoCodec: media.videoCodec,
        audioCodec: media.audioCodec,
        container: 'mp4',
        width: media.width,
        height: media.height,
        bitrateKbps: media.bitrateKbps,
        reason: 'Only the container is incompatible.',
      );
    }
    if (videoOk && !audioOk) {
      return PlaybackProfile(
        mode: 'audioTranscode',
        videoCodec: media.videoCodec,
        audioCodec: 'aac',
        container: 'mp4',
        width: media.width,
        height: media.height,
        bitrateKbps: media.bitrateKbps,
        reason: 'Video is compatible but audio must be converted.',
      );
    }
    final scale = media.width > device.maxWidth || media.height > device.maxHeight;
    final targetWidth = scale ? device.maxWidth : media.width;
    final targetHeight = scale ? device.maxHeight : media.height;
    return PlaybackProfile(
      mode: 'transcode',
      videoCodec: 'h264',
      audioCodec: 'aac',
      container: 'mp4',
      width: targetWidth,
      height: targetHeight,
      bitrateKbps: _targetBitrate(targetWidth, targetHeight),
      reason: 'Video, audio, or resolution is not directly compatible.',
    );
  }

  Future<File> prepare(File input, PlaybackProfile profile) async {
    await cache.ensureDirectory();
    final key = cache.key(input.path, profile.toJson());
    final output = cache.fileFor(key);
    if (output.existsSync() && output.lengthSync() > 0) return output;

    final args = <String>['-y', '-i', input.path];
    if (profile.mode == 'remux') {
      args.addAll(['-map', '0:v:0?', '-map', '0:a:0?', '-c', 'copy', '-movflags', '+faststart']);
    } else if (profile.mode == 'audioTranscode') {
      args.addAll(['-map', '0:v:0?', '-map', '0:a:0?', '-c:v', 'copy', '-c:a', 'aac', '-b:a', '192k', '-movflags', '+faststart']);
    } else {
      args.addAll([
        '-map', '0:v:0?', '-map', '0:a:0?',
        '-c:v', Platform.environment['TRANSCODE_VIDEO_ENCODER'] ?? 'libx264',
        '-preset', Platform.environment['TRANSCODE_PRESET'] ?? 'veryfast',
        '-crf', Platform.environment['TRANSCODE_CRF'] ?? '21',
        '-vf', 'scale=${profile.width}:${profile.height}:force_original_aspect_ratio=decrease',
        '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-b:a', '192k', '-movflags', '+faststart',
      ]);
    }
    args.add(output.path);

    final result = await Process.run(ffmpegExecutable, args);
    if (result.exitCode != 0 || !output.existsSync()) {
      if (output.existsSync()) await output.delete();
      throw StateError('ffmpeg failed: ${result.stderr}');
    }
    return output;
  }

  int _targetBitrate(int width, int height) {
    final pixels = width * height;
    if (pixels >= 3840 * 2160) return 16000;
    if (pixels >= 1920 * 1080) return 6000;
    if (pixels >= 1280 * 720) return 3500;
    return 1800;
  }
}
