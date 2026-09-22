import 'dart:async';
// FILE: Backend/services/media_analyzer_service.dart.
//
// Purpose:
// Uses ffprobe to inspect media streams without modifying the original file.
//
// The analyzer is intentionally read-only. It does not transcode, remux,
// repair, delete, or otherwise modify the inspected media file.

import 'dart:convert';
import 'dart:io';

class MediaProbe {
  final String container;
  final String videoCodec;
  final String audioCodec;
  final int width;
  final int height;
  final int? bitrateKbps;

  /// Whether ffprobe found a video stream.
  final bool hasVideo;

  /// Whether ffprobe found an audio stream.
  final bool hasAudio;

  /// Number of video streams reported by ffprobe.
  final int videoStreamCount;

  /// Number of audio streams reported by ffprobe.
  final int audioStreamCount;

  /// Duration reported by ffprobe, in seconds.
  final double? durationSeconds;

  /// Optional stream language tags, preserving ffprobe metadata.
  final List<String> audioLanguages;

  /// Optional video language tags, preserving ffprobe metadata.
  final List<String> videoLanguages;

  const MediaProbe({
    required this.container,
    required this.videoCodec,
    required this.audioCodec,
    required this.width,
    required this.height,
    this.bitrateKbps,
    this.hasVideo = false,
    this.hasAudio = false,
    this.videoStreamCount = 0,
    this.audioStreamCount = 0,
    this.durationSeconds,
    this.audioLanguages = const [],
    this.videoLanguages = const [],
  });

  Map<String, dynamic> toJson() => {
        'container': container,
        'videoCodec': videoCodec,
        'audioCodec': audioCodec,
        'width': width,
        'height': height,
        'bitrateKbps': bitrateKbps,
        'hasVideo': hasVideo,
        'hasAudio': hasAudio,
        'videoStreamCount': videoStreamCount,
        'audioStreamCount': audioStreamCount,
        'durationSeconds': durationSeconds,
        'audioLanguages': audioLanguages,
        'videoLanguages': videoLanguages,
      };
}

class MediaAnalyzerService {
  final String ffprobeExecutable;

  /// Maximum amount of time ffprobe may run for one analysis.
  final Duration timeout;

  const MediaAnalyzerService({
    this.ffprobeExecutable = 'ffprobe',
    this.timeout = const Duration(minutes: 2),
  });

  /// Inspects [file] with ffprobe without modifying it.
  ///
  /// A video stream is optional so this can also inspect audio-only media.
  /// At least one audio or video stream must be present for the result to be
  /// considered usable.
  Future<MediaProbe> analyze(File file) async {
    final path = file.path.trim();

    if (path.isEmpty) {
      throw ArgumentError.value(
        file.path,
        'file',
        'Media file path must not be empty.',
      );
    }

    if (!await file.exists()) {
      throw StateError('Media file does not exist.');
    }

    final stat = await file.stat();

    if (stat.type != FileSystemEntityType.file) {
      throw StateError('Media path is not a regular file.');
    }

    final result = await _runFfprobe(path);

    if (result.exitCode != 0) {
      final stderr = _sanitizeProcessOutput(result.stderr);

      throw StateError(
        stderr.isEmpty
            ? 'ffprobe failed with exit code ${result.exitCode}.'
            : 'ffprobe failed with exit code ${result.exitCode}: $stderr',
      );
    }

    final stdout = result.stdout.toString().trim();

    if (stdout.isEmpty) {
      throw StateError('ffprobe returned no media metadata.');
    }

    final dynamic decoded;

    try {
      decoded = jsonDecode(stdout);
    } on FormatException {
      throw StateError('ffprobe returned invalid JSON.');
    }

    if (decoded is! Map) {
      throw StateError('ffprobe returned an unexpected JSON structure.');
    }

    final json = Map<String, dynamic>.from(decoded);

    final streams = _readStreams(json['streams']);
    final format = _readMap(json['format']);

    final videoStreams = streams
        .where((stream) => stream['codec_type'] == 'video')
        .toList();

    final audioStreams = streams
        .where((stream) => stream['codec_type'] == 'audio')
        .toList();

    if (videoStreams.isEmpty && audioStreams.isEmpty) {
      throw StateError(
        'ffprobe did not find an audio or video stream.',
      );
    }

    final video = videoStreams.isEmpty
        ? const <String, dynamic>{}
        : videoStreams.first;

    final audio = audioStreams.isEmpty
        ? const <String, dynamic>{}
        : audioStreams.first;

    final durationSeconds = _doubleValue(
      format['duration'],
    );

    final bitrate = _bitrateKbps(
      format['bit_rate'] ??
          video['bit_rate'] ??
          audio['bit_rate'],
    );

    return MediaProbe(
      container: _container(format, file.path),
      videoCodec: _codec(video),
      audioCodec: _codec(audio),
      width: _intValue(video['width']) ?? 0,
      height: _intValue(video['height']) ?? 0,
      bitrateKbps: bitrate,
      hasVideo: videoStreams.isNotEmpty,
      hasAudio: audioStreams.isNotEmpty,
      videoStreamCount: videoStreams.length,
      audioStreamCount: audioStreams.length,
      durationSeconds: durationSeconds,
      audioLanguages: _languages(audioStreams),
      videoLanguages: _languages(videoStreams),
    );
  }

  Future<ProcessResult> _runFfprobe(String path) async {
    try {
      return await Process.run(
        ffprobeExecutable,
        <String>[
          '-v',
          'error',
          '-show_entries',
          'format=format_name,format_long_name,bit_rate,duration',
          '-show_entries',
          'stream=codec_type,codec_name,width,height,bit_rate:stream_tags=language',
          '-of',
          'json',
          path,
        ],
      ).timeout(timeout);
    } on TimeoutException {
      throw StateError(
        'ffprobe analysis timed out after ${timeout.inSeconds} seconds.',
      );
    } on ProcessException catch (error) {
      throw StateError(
        'Unable to start ffprobe: ${error.message}',
      );
    }
  }

  List<Map<String, dynamic>> _readStreams(dynamic value) {
    if (value is! List) {
      return const <Map<String, dynamic>>[];
    }

    final streams = <Map<String, dynamic>>[];

    for (final entry in value) {
      if (entry is Map) {
        streams.add(Map<String, dynamic>.from(entry));
      }
    }

    return streams;
  }

  Map<String, dynamic> _readMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return const <String, dynamic>{};
  }

  String _container(
    Map<String, dynamic> format,
    String path,
  ) {
    final formatName = '${format['format_name'] ?? ''}'.trim();

    if (formatName.isNotEmpty) {
      return formatName.split(',').first.toLowerCase();
    }

    return _extension(path);
  }

  String _codec(Map<String, dynamic> stream) {
    final codec = '${stream['codec_name'] ?? ''}'.trim();

    if (codec.isEmpty) {
      return 'unknown';
    }

    return codec.toLowerCase();
  }

  int? _bitrateKbps(dynamic value) {
    final bitsPerSecond = _doubleValue(value);

    if (bitsPerSecond == null || bitsPerSecond < 0) {
      return null;
    }

    return (bitsPerSecond / 1000).round();
  }

  int? _intValue(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value.trim());
    }

    return null;
  }

  double? _doubleValue(dynamic value) {
    if (value is double) {
      return value.isFinite ? value : null;
    }

    if (value is num) {
      final result = value.toDouble();
      return result.isFinite ? result : null;
    }

    if (value is String) {
      final result = double.tryParse(value.trim());

      if (result == null || !result.isFinite) {
        return null;
      }

      return result;
    }

    return null;
  }

  List<String> _languages(
    List<Map<String, dynamic>> streams,
  ) {
    final languages = <String>{};

    for (final stream in streams) {
      final tags = _readMap(stream['tags']);
      final language = '${tags['language'] ?? ''}'.trim().toLowerCase();

      if (language.isNotEmpty) {
        languages.add(language);
      }
    }

    return languages.toList(growable: false);
  }

  String _sanitizeProcessOutput(dynamic output) {
    final text = output.toString().trim();

    if (text.isEmpty) {
      return '';
    }

    // Avoid returning an arbitrarily large ffprobe diagnostic to an API
    // caller or log.
    const maxLength = 2000;

    if (text.length <= maxLength) {
      return text;
    }

    return '${text.substring(0, maxLength)}...';
  }

  String _extension(String path) {
    final normalized = path.trim();

    final separator = [
      normalized.lastIndexOf('/'),
      normalized.lastIndexOf('\\'),
    ].reduce((a, b) => a > b ? a : b);

    final dot = normalized.lastIndexOf('.');

    if (dot <= separator || dot == normalized.length - 1) {
      return 'unknown';
    }

    return normalized.substring(dot + 1).toLowerCase();
  }
}
