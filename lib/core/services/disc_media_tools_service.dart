import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// Optional local post-rip tools. The original MakeMKV rip is never replaced:
/// HandBrake writes a second MKV so the lossless/source rip remains available.
class DiscMediaToolsService {
  DiscMediaToolsService._();
  static final DiscMediaToolsService instance = DiscMediaToolsService._();

  static const _handBrakeKey = 'disc_tools_handbrake_cli_v1';
  static const _mkvMergeKey = 'disc_tools_mkvmerge_cli_v1';
  static const _presetKey = 'disc_tools_handbrake_preset_v1';

  String handBrakePath = '';
  String mkvMergePath = '';
  String preset = 'Fast 1080p30';
  bool _initialized = false;

  String get suggestedHandBrakePath {
    if (Platform.isWindows) return r'C:\Program Files\HandBrake\HandBrakeCLI.exe';
    if (Platform.isMacOS) return '/opt/homebrew/bin/HandBrakeCLI';
    return 'HandBrakeCLI';
  }

  String get suggestedMkvMergePath {
    if (Platform.isWindows) return r'C:\Program Files\MKVToolNix\mkvmerge.exe';
    if (Platform.isMacOS) return '/opt/homebrew/bin/mkvmerge';
    return 'mkvmerge';
  }

  Future<void> initialize() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    handBrakePath = prefs.getString(_handBrakeKey) ?? suggestedHandBrakePath;
    mkvMergePath = prefs.getString(_mkvMergeKey) ?? suggestedMkvMergePath;
    preset = prefs.getString(_presetKey) ?? 'Fast 1080p30';
    _initialized = true;
  }

  Future<void> save({String? handBrake, String? mkvMerge, String? handBrakePreset}) async {
    await initialize();
    final prefs = await SharedPreferences.getInstance();
    if (handBrake != null) handBrakePath = handBrake.trim();
    if (mkvMerge != null) mkvMergePath = mkvMerge.trim();
    if (handBrakePreset != null) preset = handBrakePreset.trim();
    await prefs.setString(_handBrakeKey, handBrakePath);
    await prefs.setString(_mkvMergeKey, mkvMergePath);
    await prefs.setString(_presetKey, preset);
  }

  Future<String> checkExecutable(String rawPath, {required String label, required String versionArgument}) async {
    final path = rawPath.trim();
    if (path.isEmpty) throw StateError('$label path is empty.');
    if (path.contains('/') || path.contains('\\')) {
      if (!await File(path).exists()) throw StateError('$label was not found at: $path');
    }
    final result = await Process.run(path, <String>[versionArgument], runInShell: false)
        .timeout(const Duration(seconds: 20));
    final output = '${result.stdout}\n${result.stderr}'.trim();
    if (result.exitCode != 0) throw StateError('$label check failed (exit ${result.exitCode}): ${_tail(output)}');
    return output.isEmpty ? '$label is available.' : _tail(output);
  }

  /// Uses MKVToolNix's machine-readable identify output to inspect tracks,
  /// chapters and container metadata without modifying the file.
  Future<Map<String, dynamic>> identifyMkv(String filePath) async {
    await initialize();
    final file = File(filePath.trim());
    if (!await file.exists()) throw StateError('MKV file does not exist: ${file.path}');
    final result = await Process.run(mkvMergePath, <String>['--identification-format', 'json', '--identify', file.path], runInShell: false)
        .timeout(const Duration(minutes: 2));
    if (result.exitCode != 0) throw StateError('mkvmerge identify failed: ${_tail('${result.stdout}\n${result.stderr}')}');
    final decoded = jsonDecode(result.stdout.toString());
    if (decoded is! Map) throw const FormatException('mkvmerge returned an unexpected JSON document.');
    return Map<String, dynamic>.from(decoded);
  }

  /// Creates an optional compressed playback copy. The source rip is retained.
  /// `av_mkv` forces Matroska output even when a preset normally defaults to MP4.
  Future<String> transcodeToMkv({required String sourcePath, String? outputPath, String? selectedPreset}) async {
    await initialize();
    final source = File(sourcePath.trim());
    if (!await source.exists()) throw StateError('Source MKV does not exist: ${source.path}');
    final lower = source.path.toLowerCase();
    if (!lower.endsWith('.mkv')) throw ArgumentError('HandBrake source must be an MKV file.');
    if (lower.endsWith('.handbrake.mkv')) throw ArgumentError('This looks like an existing HandBrake output. Select the original MakeMKV rip to avoid repeated lossy encoding.');
    final destination = (outputPath ?? _defaultTranscodePath(source.path)).trim();
    if (destination.isEmpty || destination.toLowerCase() == source.path.toLowerCase()) {
      throw ArgumentError('Choose a different output path; the original rip must never be overwritten.');
    }
    if (!destination.toLowerCase().endsWith('.mkv')) throw ArgumentError('HandBrake output must use the .mkv extension.');
    if (await File(destination).exists()) throw StateError('Output already exists. Choose another filename so no existing file is overwritten.');
    final chosenPreset = (selectedPreset ?? preset).trim();
    if (chosenPreset.isEmpty) throw ArgumentError('Enter a HandBrake preset name.');
    final outputDirectory = File(destination).parent;
    await outputDirectory.create(recursive: true);

    final result = await Process.run(
      handBrakePath,
      <String>[
        '--input', source.path,
        '--output', destination,
        '--format', 'av_mkv',
        '--preset', chosenPreset,
        '--all-audio',
        '--all-subtitles',
        '--markers',
      ],
      runInShell: false,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    ).timeout(const Duration(hours: 8));
    if (result.exitCode != 0) {
      throw StateError('HandBrake failed (exit ${result.exitCode}): ${_tail('${result.stdout}\n${result.stderr}')}');
    }
    final output = File(destination);
    if (!await output.exists() || await output.length() < 4) {
      throw StateError('HandBrake reported success but did not create a usable output file.');
    }
    return destination;
  }

  String _defaultTranscodePath(String source) {
    final index = source.lastIndexOf(RegExp(r'[/\\]'));
    final directory = index < 0 ? '' : source.substring(0, index + 1);
    final name = index < 0 ? source : source.substring(index + 1);
    final stem = name.replaceFirst(RegExp(r'\.mkv$', caseSensitive: false), '');
    return '$directory$stem.handbrake.mkv';
  }

  String _tail(String value) {
    final lines = const LineSplitter().convert(value.trim());
    return lines.length <= 8 ? value.trim() : lines.skip(lines.length - 8).join('\n');
  }
}
