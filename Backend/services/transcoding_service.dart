// FILE: Backend/services/transcoding_service.dart.
// Purpose: Selects direct play, remux, audio-only transcode, or full
// transcode and creates disposable cached playback copies.
//
// Original media is never modified by this service.
// Generated files belong exclusively to TranscodeCacheService.
//
// The service is intentionally conservative:
// - direct-play decisions never invoke FFmpeg;
// - remux/audio/video transcodes run through the bounded scheduler;
// - FFmpeg input/output paths are passed as Process.run arguments, never
//   through a shell;
// - generated output is written only into the dedicated transcode cache;
// - failed/partial cache files are removed;
// - FFmpeg execution has a bounded timeout.

import 'dart:async';
import 'dart:io';

import '../models/media_capabilities.dart';
import '../models/playback_profile.dart';
import 'media_analyzer_service.dart';
import 'transcode_cache_service.dart';
import 'transcoding_scheduler_service.dart';

class TranscodingService {
  static const Duration _ffmpegTimeout = Duration(hours: 2);
  static const int _maxProcessOutput = 16 * 1024;

  final MediaAnalyzerService analyzer;
  final TranscodeCacheService cache;
  final String ffmpegExecutable;
  final TranscodingSchedulerService scheduler;

  TranscodingService({
    required this.analyzer,
    required this.cache,
    this.ffmpegExecutable = 'ffmpeg',
    TranscodingSchedulerService? scheduler,
  }) : scheduler = scheduler ??
            TranscodingSchedulerService(
              maxConcurrentJobs: _configuredConcurrency(),
            );

  /// Determines the least expensive playback mode supported by the device.
  ///
  /// The returned profile is a playback decision, not a guarantee that the
  /// client can actually decode every stream. Playback routes should still
  /// handle FFmpeg/preparation failures gracefully.
  PlaybackProfile decide(
    MediaProbe media,
    MediaCapabilities device,
  ) {
    _validateProbe(media);
    _validateCapabilities(device);

    final videoSupported = _videoIsSupported(media, device);
    final audioSupported = _audioIsSupported(media, device);
    final containerSupported = _containerIsSupported(media, device);

    if (videoSupported &&
        audioSupported &&
        containerSupported) {
      return PlaybackProfile(
        mode: 'directPlay',
        videoCodec: media.videoCodec,
        audioCodec: media.audioCodec,
        container: media.container,
        width: media.width,
        height: media.height,
        bitrateKbps: media.bitrateKbps,
        reason:
            'Device supports the original streams and container.',
      );
    }

    if (videoSupported &&
        audioSupported &&
        !containerSupported) {
      return PlaybackProfile(
        mode: 'remux',
        videoCodec: media.videoCodec,
        audioCodec: media.audioCodec,
        container: 'mp4',
        width: media.width,
        height: media.height,
        bitrateKbps: media.bitrateKbps,
        reason:
            'Only the container is incompatible.',
      );
    }

    if (videoSupported && !audioSupported) {
      return PlaybackProfile(
        mode: 'audioTranscode',
        videoCodec: media.videoCodec,
        audioCodec: 'aac',
        container: 'mp4',
        width: media.width,
        height: media.height,
        bitrateKbps: _audioTranscodeBitrate(
  media.bitrateKbps ?? 192,
),
        reason:
            'Video is compatible but audio must be converted.',
      );
    }

    final target = _targetDimensions(
      media.width,
      media.height,
      device.maxWidth,
      device.maxHeight,
    );

    return PlaybackProfile(
      mode: 'transcode',
      videoCodec: 'h264',
      audioCodec: 'aac',
      container: 'mp4',
      width: target.width,
      height: target.height,
      bitrateKbps: _targetBitrate(
        target.width,
        target.height,
      ),
      reason:
          'Video, audio, or resolution is not directly compatible.',
    );
  }

  /// Creates or retrieves a disposable playback copy.
  ///
  /// Direct-play profiles do not require a generated file and therefore
  /// produce an error if passed to this method. Playback routing should
  /// stream the original media directly for direct-play decisions.
  Future<File> prepare(
    File input,
    PlaybackProfile profile,
  ) async {
    _validateInput(input);
    _validateProfile(profile);

    if (profile.mode == 'directPlay') {
      throw StateError(
        'Direct-play profiles do not require transcoding.',
      );
    }

    return scheduler.schedule(
      () => _prepareInternal(
        input,
        profile,
      ),
      label: 'transcode:${profile.mode}',
    );
  }

  Future<File> _prepareInternal(
    File input,
    PlaybackProfile profile,
  ) async {
    await cache.ensureDirectory();

    final cacheKey = cache.key(
      input.path,
      profile.toJson(),
    );

    final output = cache.fileFor(cacheKey);

    if (await _isUsableCacheFile(output)) {
      return output;
    }

    // A zero-byte/invalid previous output is disposable cache state.
    await _deleteIfExists(output);

    final args = _buildFfmpegArguments(
      input,
      output,
      profile,
    );

    ProcessResult result;

    try {
      result = await Process.run(
        ffmpegExecutable,
        args,
      ).timeout(_ffmpegTimeout);
    } on TimeoutException {
      await _deleteIfExists(output);

      throw StateError(
        'Transcoding timed out.',
      );
    } on ProcessException catch (error) {
      await _deleteIfExists(output);

      throw StateError(
        'Unable to start the transcoder: '
        '${_safeErrorText(error.message)}',
      );
    } catch (_) {
      await _deleteIfExists(output);
      rethrow;
    }

    if (result.exitCode != 0) {
      await _deleteIfExists(output);

      throw StateError(
        'FFmpeg failed with exit code ${result.exitCode}. '
        '${_safeFfmpegError(result.stderr)}',
      );
    }

    if (!await _isUsableCacheFile(output)) {
      await _deleteIfExists(output);

      throw StateError(
        'FFmpeg completed without producing a valid cache file.',
      );
    }

    return output;
  }

  List<String> _buildFfmpegArguments(
    File input,
    File output,
    PlaybackProfile profile,
  ) {
    final inputPath = input.absolute.path;
    final outputPath = output.absolute.path;

    final args = <String>[
      '-hide_banner',
      '-nostdin',
      '-y',
      '-i',
      inputPath,
    ];

    switch (profile.mode) {
      case 'remux':
        args.addAll([
          '-map',
          '0:v:0?',
          '-map',
          '0:a:0?',
          '-c',
          'copy',
          '-movflags',
          '+faststart',
        ]);
        break;

      case 'audioTranscode':
        args.addAll([
          '-map',
          '0:v:0?',
          '-map',
          '0:a:0?',
          '-c:v',
          'copy',
          '-c:a',
          'aac',
          '-b:a',
          _audioBitrate(profile.bitrateKbps ?? 192),
          '-movflags',
          '+faststart',
        ]);
        break;

      case 'transcode':
        args.addAll([
          '-map',
          '0:v:0?',
          '-map',
          '0:a:0?',
          '-c:v',
          _configuredVideoEncoder(),
          '-preset',
          _configuredPreset(),
          '-crf',
          _configuredCrf(),
          '-vf',
          _scaleFilter(
            profile.width ?? 1920,
            profile.height ?? 1080,
          ),
          '-pix_fmt',
          'yuv420p',
          '-c:a',
          'aac',
          '-b:a',
          _audioBitrate(profile.bitrateKbps ?? 192),
          '-movflags',
          '+faststart',
        ]);
        break;

      default:
        throw ArgumentError(
          'Unsupported transcoding mode: ${profile.mode}',
        );
    }

    args.add(outputPath);

    return args;
  }

  bool _videoIsSupported(
    MediaProbe media,
    MediaCapabilities device,
  ) {
    if (media.videoCodec.trim().isEmpty) {
      return false;
    }

    if (device.videoCodecs.isEmpty) {
      return false;
    }

    final codec = media.videoCodec.trim().toLowerCase();

    final supported = device.videoCodecs.any(
      (value) => value.trim().toLowerCase() == codec,
    );

    return supported &&
        media.width > 0 &&
        media.height > 0 &&
        media.width <= device.maxWidth &&
        media.height <= device.maxHeight;
  }

  bool _audioIsSupported(
    MediaProbe media,
    MediaCapabilities device,
  ) {
    if (media.audioCodec.trim().isEmpty) {
      return false;
    }

    final codec = media.audioCodec.trim().toLowerCase();

    return device.audioCodecs.any(
      (value) => value.trim().toLowerCase() == codec,
    );
  }

  bool _containerIsSupported(
    MediaProbe media,
    MediaCapabilities device,
  ) {
    if (media.container.trim().isEmpty) {
      return false;
    }

    final container = media.container.trim().toLowerCase();

    return device.containers.any(
      (value) => value.trim().toLowerCase() == container,
    );
  }

  _TargetDimensions _targetDimensions(
    int sourceWidth,
    int sourceHeight,
    int maxWidth,
    int maxHeight,
  ) {
    if (sourceWidth <= 0 ||
        sourceHeight <= 0 ||
        maxWidth <= 0 ||
        maxHeight <= 0) {
      throw StateError(
        'Invalid video dimensions for transcoding.',
      );
    }

    final widthScale = maxWidth / sourceWidth;
    final heightScale = maxHeight / sourceHeight;

    final scale = widthScale < heightScale
        ? widthScale
        : heightScale;

    if (scale >= 1) {
      return _TargetDimensions(
        _evenDimension(sourceWidth),
        _evenDimension(sourceHeight),
      );
    }

    var width = (sourceWidth * scale).floor();
    var height = (sourceHeight * scale).floor();

    width = _evenDimension(width);
    height = _evenDimension(height);

    width = width.clamp(2, maxWidth);
    height = height.clamp(2, maxHeight);

    return _TargetDimensions(
      width,
      height,
    );
  }

  String _scaleFilter(
    int width,
    int height,
  ) {
    if (width < 2 || height < 2) {
      throw ArgumentError(
        'Invalid target video dimensions.',
      );
    }

    return 'scale=$width:$height:force_original_aspect_ratio=decrease';
  }

  int _targetBitrate(
    int width,
    int height,
  ) {
    final pixels = width * height;

    if (pixels >= 3840 * 2160) {
      return 16000;
    }

    if (pixels >= 1920 * 1080) {
      return 6000;
    }

    if (pixels >= 1280 * 720) {
      return 3500;
    }

    return 1800;
  }

  int _audioTranscodeBitrate(int sourceBitrate) {
    if (sourceBitrate <= 0) {
      return 192;
    }

    if (sourceBitrate < 96) {
      return 96;
    }

    if (sourceBitrate < 128) {
      return 128;
    }

    if (sourceBitrate < 192) {
      return 160;
    }

    return 192;
  }

  String _audioBitrate(int requestedKbps) {
    final bitrate = requestedKbps <= 0
        ? 192
        : requestedKbps.clamp(64, 320);

    return '${bitrate}k';
  }

  String _configuredVideoEncoder() {
    final configured =
        Platform.environment['TRANSCODE_VIDEO_ENCODER']
            ?.trim();

    if (configured == null || configured.isEmpty) {
      return 'libx264';
    }

    if (!_isSafeFfmpegValue(configured)) {
      throw StateError(
        'Invalid TRANSCODE_VIDEO_ENCODER configuration.',
      );
    }

    return configured;
  }

  String _configuredPreset() {
    final configured =
        Platform.environment['TRANSCODE_PRESET']?.trim();

    if (configured == null || configured.isEmpty) {
      return 'veryfast';
    }

    if (!_isSafeFfmpegValue(configured)) {
      throw StateError(
        'Invalid TRANSCODE_PRESET configuration.',
      );
    }

    return configured;
  }

  String _configuredCrf() {
    final configured =
        Platform.environment['TRANSCODE_CRF']?.trim();

    if (configured == null || configured.isEmpty) {
      return '21';
    }

    final crf = int.tryParse(configured);

    if (crf == null || crf < 0 || crf > 51) {
      throw StateError(
        'TRANSCODE_CRF must be an integer from 0 through 51.',
      );
    }

    return crf.toString();
  }

  Future<bool> _isUsableCacheFile(File file) async {
    try {
      if (!await file.exists()) {
        return false;
      }

      final type = await FileSystemEntity.type(
        file.path,
        followLinks: false,
      );

      if (type != FileSystemEntityType.file) {
        return false;
      }

      return await file.length() > 0;
    } catch (_) {
      return false;
    }
  }

  Future<void> _deleteIfExists(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // A failed cleanup must not hide the original transcoding failure.
    }
  }

  void _validateInput(File input) {
    final path = input.path.trim();

    if (path.isEmpty) {
      throw ArgumentError(
        'Transcoding input path cannot be empty.',
      );
    }

    if (path.contains('\u0000')) {
      throw ArgumentError(
        'Transcoding input path contains an invalid character.',
      );
    }
  }

  void _validateProbe(MediaProbe media) {
    if (media.width < 0 ||
    media.height < 0 ||
    (media.bitrateKbps != null && media.bitrateKbps! < 0)) {
      throw ArgumentError(
        'Media probe contains invalid numeric values.',
      );
    }

    if (media.videoCodec.length > 100 ||
        media.audioCodec.length > 100 ||
        media.container.length > 100) {
      throw ArgumentError(
        'Media probe contains an oversized codec/container value.',
      );
    }
  }

  void _validateCapabilities(MediaCapabilities device) {
    if (device.maxWidth <= 0 ||
        device.maxHeight <= 0) {
      throw ArgumentError(
        'Playback device has invalid maximum dimensions.',
      );
    }
  }

  void _validateProfile(PlaybackProfile profile) {
    final mode = profile.mode.trim();

    const supportedModes = {
      'remux',
      'audioTranscode',
      'transcode',
    };

    if (!supportedModes.contains(mode)) {
      throw ArgumentError(
        'Unsupported transcoding mode: ${profile.mode}',
      );
    }

    if ((profile.width != null && profile.width! < 0) ||
    (profile.height != null && profile.height! < 0)) {
      throw ArgumentError(
        'Transcoding profile has invalid dimensions.',
      );
    }

    if ((profile.width != null && profile.width! > 7680) ||
    (profile.height != null && profile.height! > 4320)) {
      throw ArgumentError(
        'Transcoding dimensions exceed the supported limit.',
      );
    }

    if ((profile.bitrateKbps != null &&
        profile.bitrateKbps! < 0) ||
    (profile.bitrateKbps != null &&
        profile.bitrateKbps! > 100000)) {
      throw ArgumentError(
        'Transcoding bitrate is outside the supported range.',
      );
    }
  }

  bool _isSafeFfmpegValue(String value) {
    if (value.length > 200) {
      return false;
    }

    return !value.contains(
      RegExp(r'[\x00-\x1F\x7F]'),
    );
  }

  String _safeFfmpegError(Object? stderr) {
    final text = stderr?.toString().trim() ?? '';

    if (text.isEmpty) {
      return 'No diagnostic output was provided.';
    }

    final normalized = text.replaceAll(
      RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'),
      '',
    );

    if (normalized.length <= _maxProcessOutput) {
      return normalized;
    }

    return normalized.substring(0, _maxProcessOutput);
  }

  String _safeErrorText(String value) {
    final normalized = value.replaceAll(
      RegExp(r'[\x00-\x1F\x7F]'),
      '',
    );

    if (normalized.length <= 1000) {
      return normalized;
    }

    return normalized.substring(0, 1000);
  }

  int _evenDimension(int value) {
    if (value <= 2) {
      return 2;
    }

    final even = value.isOdd ? value - 1 : value;

    return even < 2 ? 2 : even;
  }

  static int _configuredConcurrency() {
    final raw =
        Platform.environment['TRANSCODE_MAX_CONCURRENT'];

    final parsed = int.tryParse(raw ?? '');

    if (parsed == null || parsed < 1) {
      return 2;
    }

    return parsed.clamp(1, 32);
  }
}

class _TargetDimensions {
  final int width;
  final int height;

  const _TargetDimensions(
    this.width,
    this.height,
  );
}