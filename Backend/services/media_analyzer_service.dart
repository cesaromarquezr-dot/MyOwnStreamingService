// FILE: Backend/services/media_analyzer_service.dart.
// Purpose: Uses ffprobe to inspect media streams without modifying the original file.

import 'dart:convert';
import 'dart:io';

class MediaProbe {
  final String container;
  final String videoCodec;
  final String audioCodec;
  final int width;
  final int height;
  final int? bitrateKbps;

  const MediaProbe({
    required this.container,
    required this.videoCodec,
    required this.audioCodec,
    required this.width,
    required this.height,
    this.bitrateKbps,
  });

  Map<String, dynamic> toJson() => {
        'container': container,
        'videoCodec': videoCodec,
        'audioCodec': audioCodec,
        'width': width,
        'height': height,
        'bitrateKbps': bitrateKbps,
      };
}

class MediaAnalyzerService {
  final String ffprobeExecutable;

  const MediaAnalyzerService({this.ffprobeExecutable = 'ffprobe'});

  Future<MediaProbe> analyze(File file) async {
    final result = await Process.run(ffprobeExecutable, [
      '-v', 'error',
      '-show_entries', 'format=format_name,bit_rate',
      '-show_entries', 'stream=codec_type,codec_name,width,height,bit_rate',
      '-of', 'json',
      file.path,
    ]);

    if (result.exitCode != 0) {
      throw StateError('ffprobe failed: ${result.stderr}');
    }

    final json = jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
    final streams = (json['streams'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final video = streams.firstWhere((s) => s['codec_type'] == 'video', orElse: () => <String, dynamic>{});
    final audio = streams.firstWhere((s) => s['codec_type'] == 'audio', orElse: () => <String, dynamic>{});
    final format = json['format'] is Map ? Map<String, dynamic>.from(json['format']) : <String, dynamic>{};

    int? kbps(dynamic value) {
      final n = num.tryParse('$value');
      return n == null ? null : (n / 1000).round();
    }

    return MediaProbe(
      container: '${format['format_name'] ?? _extension(file.path)}'.split(',').first.toLowerCase(),
      videoCodec: '${video['codec_name'] ?? 'unknown'}'.toLowerCase(),
      audioCodec: '${audio['codec_name'] ?? 'unknown'}'.toLowerCase(),
      width: int.tryParse('${video['width'] ?? 0}') ?? 0,
      height: int.tryParse('${video['height'] ?? 0}') ?? 0,
      bitrateKbps: kbps(format['bit_rate'] ?? video['bit_rate']),
    );
  }

  String _extension(String path) {
    final dot = path.lastIndexOf('.');
    return dot == -1 ? 'unknown' : path.substring(dot + 1);
  }
}
