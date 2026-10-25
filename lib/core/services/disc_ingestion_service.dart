import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app_core.dart';
import 'original_language_defaults.dart';

enum DiscRipStatus { running, succeeded, failed, cancelled }

class MakeMkvTitle {
  const MakeMkvTitle({required this.index, required this.name, required this.duration, required this.chapters, required this.audioTracks, required this.subtitleTracks});
  final int index;
  final String name;
  final String duration;
  final int chapters;
  final List<String> audioTracks;
  final List<String> subtitleTracks;
}


class MakeMkvDrive {
  const MakeMkvDrive({
    required this.index,
    required this.visible,
    required this.enabled,
    required this.flags,
    required this.name,
    required this.discName,
  });

  final int index;
  final bool visible;
  final bool enabled;
  final int flags;
  final String name;
  final String discName;

  factory MakeMkvDrive.fromRobotLine(String line) {
    final raw = line.startsWith('DRV:') ? line.substring(4) : line;
    final fields = _parseRobotCsv(raw);
    if (fields.length < 6) {
      throw FormatException('Malformed MakeMKV drive record.');
    }
    final index = int.tryParse(fields[0]);
    if (index == null) {
      throw const FormatException('MakeMKV returned an invalid drive index.');
    }
    return MakeMkvDrive(
      index: index,
      visible: fields[1] == '1',
      enabled: fields[2] == '1',
      flags: int.tryParse(fields[3]) ?? 0,
      name: fields[4],
      discName: fields[5],
    );
  }
}

class DiscRipJob {
  DiscRipJob({
    required this.id,
    required this.driveIndex,
    required this.driveName,
    required this.titleSelector,
    required this.outputPath,
    required this.createdAt,
    this.status = DiscRipStatus.running,
    this.progress = 0,
    this.phase = 'Starting MakeMKV',
    this.startedAt,
    this.completedAt,
    this.exitCode,
    this.error,
    List<String>? events,
    List<String>? outputFiles,
    List<String>? importedFiles,
  })  : events = events ?? <String>[],
        outputFiles = outputFiles ?? <String>[],
        importedFiles = importedFiles ?? <String>[];

  final String id;
  final int driveIndex;
  final String driveName;
  final String titleSelector;
  final String outputPath;
  final DateTime createdAt;
  DiscRipStatus status;
  double progress;
  String phase;
  DateTime? startedAt;
  DateTime? completedAt;
  int? exitCode;
  String? error;
  final List<String> events;
  final List<String> outputFiles;
  final List<String> importedFiles;

  Map<String, dynamic> toJson() => {
        'id': id,
        'driveIndex': driveIndex,
        'driveName': driveName,
        'titleSelector': titleSelector,
        'outputPath': outputPath,
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
        'progress': progress,
        'phase': phase,
        if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
        if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
        if (exitCode != null) 'exitCode': exitCode,
        if (error != null) 'error': error,
        'events': events.take(120).toList(growable: false),
        'outputFiles': outputFiles,
        'importedFiles': importedFiles,
      };

  factory DiscRipJob.fromJson(Map<String, dynamic> json) {
    DiscRipStatus parseStatus(dynamic raw) => DiscRipStatus.values.firstWhere(
          (item) => item.name == raw?.toString(),
          orElse: () => DiscRipStatus.failed,
        );
    DateTime? parseDate(dynamic raw) => raw == null ? null : DateTime.tryParse(raw.toString());
    List<String> strings(dynamic raw) => raw is List ? raw.map((item) => item.toString()).toList() : <String>[];
    return DiscRipJob(
      id: json['id']?.toString() ?? '',
      driveIndex: (json['driveIndex'] as num?)?.toInt() ?? 0,
      driveName: json['driveName']?.toString() ?? 'Optical drive',
      titleSelector: json['titleSelector']?.toString() ?? 'all',
      outputPath: json['outputPath']?.toString() ?? '',
      createdAt: parseDate(json['createdAt']) ?? DateTime.now(),
      status: parseStatus(json['status']),
      progress: ((json['progress'] as num?)?.toDouble() ?? 0).clamp(0.0, 1.0).toDouble(),
      phase: json['phase']?.toString() ?? 'Restored from history',
      startedAt: parseDate(json['startedAt']),
      completedAt: parseDate(json['completedAt']),
      exitCode: (json['exitCode'] as num?)?.toInt(),
      error: json['error']?.toString(),
      events: strings(json['events']),
      outputFiles: strings(json['outputFiles']),
      importedFiles: strings(json['importedFiles']),
    );
  }
}

class MkvValidationResult {
  const MkvValidationResult({
    required this.filePath,
    required this.sizeBytes,
    required this.hasEbmlHeader,
    this.error,
  });

  final String filePath;
  final int sizeBytes;
  final bool hasEbmlHeader;
  final String? error;

  bool get passed => error == null && sizeBytes >= 4 && hasEbmlHeader;
}

/// Local MakeMKV integration. It only starts ripping after an explicit user
/// action, does not flash firmware, and passes process arguments without a shell.
class DiscIngestionService extends ChangeNotifier {
  DiscIngestionService._();

  static final DiscIngestionService instance = DiscIngestionService._();

  static const _historyKey = 'disc_ingestion_jobs_v1';
  static const _executableKey = 'disc_ingestion_makemkv_path_v1';
  static const _destinationKey = 'disc_ingestion_destination_v1';

  SharedPreferences? _preferences;
  final List<DiscRipJob> _jobs = <DiscRipJob>[];
  Process? _activeProcess;
  String? _activeJobId;
  String _executablePath = '';
  String _destinationRoot = '';
  DateTime _lastProgressPersist = DateTime.fromMillisecondsSinceEpoch(0);

  List<DiscRipJob> get jobs => List<DiscRipJob>.unmodifiable(_jobs);
  String get executablePath => _executablePath;
  String get destinationRoot => _destinationRoot;
  bool get hasActiveRip => _activeProcess != null;
  bool get supportsLocalProcess => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  Future<void> initialize() async {
    if (_preferences != null) return;
    _preferences = await SharedPreferences.getInstance();
    _executablePath = _preferences!.getString(_executableKey) ?? _guessExecutablePath();
    _destinationRoot = _preferences!.getString(_destinationKey) ?? '';
    final encoded = _preferences!.getString(_historyKey);
    if (encoded != null) {
      try {
        final decoded = jsonDecode(encoded);
        if (decoded is List) {
          _jobs
            ..clear()
            ..addAll(decoded.whereType<Map>().map((row) => DiscRipJob.fromJson(Map<String, dynamic>.from(row))).take(100));
        }
      } catch (_) {
        // Ignore a corrupt local history blob. The ripping process itself is
        // never inferred from persisted UI state.
      }
    }
    for (final job in _jobs.where((item) => item.status == DiscRipStatus.running)) {
      job.status = DiscRipStatus.failed;
      job.phase = 'Interrupted';
      job.error = 'The app restarted while this job was marked running. Check the output folder before retrying.';
      job.completedAt = DateTime.now();
      _addEvent(job, job.error!);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> configure({String? executablePath, String? destinationRoot}) async {
    await initialize();
    if (executablePath != null) _executablePath = executablePath.trim();
    if (destinationRoot != null) _destinationRoot = destinationRoot.trim();
    await _preferences!.setString(_executableKey, _executablePath);
    await _preferences!.setString(_destinationKey, _destinationRoot);
    notifyListeners();
  }

  Future<List<MakeMkvDrive>> discoverDrives({String? executablePath}) async {
    await initialize();
    final executable = _resolveExecutable(executablePath ?? _executablePath);
    final result = await Process.run(
      executable,
      const <String>['--robot', '--cache=1', 'info', 'disc:9999'],
      runInShell: false,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    ).timeout(const Duration(seconds: 25));
    final output = '${result.stdout}\n${result.stderr}';
    final drives = <MakeMkvDrive>[];
    for (final line in const LineSplitter().convert(output)) {
      if (!line.startsWith('DRV:')) continue;
      try {
        final drive = MakeMkvDrive.fromRobotLine(line);
        if (drive.visible) drives.add(drive);
      } on FormatException {
        // A malformed record is skipped; other discovered devices remain usable.
      }
    }
    if (result.exitCode != 0 && drives.isEmpty) {
      throw StateError(_lastUsefulLine(output, 'MakeMKV drive discovery failed with exit code ${result.exitCode}.'));
    }
    return drives;
  }

  /// Reads MakeMKV's title table without starting a rip. Every title is shown
  /// for review; similar/short titles are never silently imported as movies.
  Future<List<MakeMkvTitle>> scanDiscTitles({required int driveIndex, String? executablePath}) async {
    await initialize();
    if (driveIndex < 0) throw ArgumentError('Choose a valid optical drive.');
    final executable = _resolveExecutable(executablePath ?? _executablePath);
    final result = await Process.run(executable, <String>['--robot', '--cache=1', 'info', 'disc:$driveIndex'], runInShell: false, stdoutEncoding: utf8, stderrEncoding: utf8).timeout(const Duration(seconds: 45));
    final output = '${result.stdout}\n${result.stderr}';
    final names = <int, String>{}; final durations = <int, String>{}; final chapters = <int, int>{};
    final audio = <int, List<String>>{}; final subtitles = <int, List<String>>{};
    for (final line in const LineSplitter().convert(output)) {
      if (line.startsWith('TINFO:')) {
        final f = _parseRobotCsv(line.substring(5)); if (f.length < 4) continue;
        final i = int.tryParse(f[0]); final attr = int.tryParse(f[1]); if (i == null || attr == null) continue;
        final value = f[3].trim();
        if (attr == 2 && value.isNotEmpty) names[i] = value;
        if (RegExp(r'^\d{1,2}:\d{2}:\d{2}$').hasMatch(value)) durations[i] = value;
        if (attr == 8) { final n = int.tryParse(value); if (n != null && n > 0) chapters[i] = n; }
        if (attr == 3 && value.isNotEmpty) (audio[i] ??= <String>[]).add(value);
        if (attr == 4 && value.isNotEmpty) (subtitles[i] ??= <String>[]).add(value);
      }
    }
    if (result.exitCode != 0 && names.isEmpty) throw StateError(_lastUsefulLine(output, 'MakeMKV could not scan the disc titles.'));
    final indexes = <int>{...names.keys, ...durations.keys}.toList()..sort();
    return indexes.map((i) => MakeMkvTitle(index: i, name: names[i] ?? 'Title ${i + 1}', duration: durations[i] ?? 'Duration unavailable', chapters: chapters[i] ?? 0, audioTracks: List.unmodifiable(audio[i] ?? const <String>[]), subtitleTracks: List.unmodifiable(subtitles[i] ?? const <String>[]))).toList(growable: false);
  }

  Future<void> testDestination(String root) async {
    final clean = root.trim();
    if (clean.isEmpty) throw ArgumentError('Enter an output folder first.');
    final directory = Directory(clean);
    await directory.create(recursive: true);
    final probe = File(_joinPath(clean, '.moss_write_test_${DateTime.now().microsecondsSinceEpoch}.tmp'));
    try {
      await probe.writeAsString('write-test', flush: true);
    } finally {
      if (await probe.exists()) await probe.delete();
    }
  }

  Future<DiscRipJob> startRip({
    required int driveIndex,
    required String driveName,
    required String titleSelector,
    required String outputRoot,
    required String folderName,
    required bool rightsConfirmed,
    String? executablePath,
  }) async {
    await initialize();
    if (!supportsLocalProcess) {
      throw UnsupportedError('Local MakeMKV process automation is supported only on Windows, macOS, and Linux desktop builds.');
    }
    if (!rightsConfirmed) {
      throw StateError('Confirm that you are authorized to make this copy before starting the rip.');
    }
    if (_activeProcess != null) throw StateError('A MakeMKV rip is already running.');
    if (driveIndex < 0) throw ArgumentError('Choose a valid optical drive.');
    final selector = titleSelector.trim().toLowerCase();
    if (selector != 'all' && !RegExp(r'^\d+(?:,\d+)*$').hasMatch(selector)) {
      throw ArgumentError("Title selector must be 'all', a numeric title index, or comma-separated numeric title indexes.");
    }
    final root = outputRoot.trim();
    final cleanFolder = _validateFolderName(folderName);
    if (root.isEmpty) throw ArgumentError('Enter an output root folder first.');
    await testDestination(root);
    final outputPath = _joinPath(root, cleanFolder);
    await Directory(outputPath).create(recursive: true);
    final executable = _resolveExecutable(executablePath ?? _executablePath);
    await configure(executablePath: executable, destinationRoot: root);

    final job = DiscRipJob(
      id: 'mkv_${DateTime.now().microsecondsSinceEpoch}',
      driveIndex: driveIndex,
      driveName: driveName,
      titleSelector: selector,
      outputPath: outputPath,
      createdAt: DateTime.now(),
      startedAt: DateTime.now(),
      status: DiscRipStatus.running,
      phase: 'Launching MakeMKV',
      events: <String>['${DateTime.now().toIso8601String()} · Job created.'],
    );
    _jobs.insert(0, job);
    if (_jobs.length > 100) _jobs.removeRange(100, _jobs.length);
    await _persist();
    notifyListeners();

    late final Process process;
    try {
      process = await Process.start(
        executable,
        <String>['--robot', '--cache=128', 'mkv', 'disc:$driveIndex', selector, outputPath],
        runInShell: false,
        mode: ProcessStartMode.normal,
      );
    } catch (error) {
      job.status = DiscRipStatus.failed;
      job.phase = 'Could not launch MakeMKV';
      job.error = 'Unable to start MakeMKV. Verify the console executable path and permissions. $error';
      job.completedAt = DateTime.now();
      _addEvent(job, job.error!);
      await _persist();
      notifyListeners();
      rethrow;
    }
    _activeProcess = process;
    _activeJobId = job.id;
    job.phase = 'Reading disc';
    _addEvent(job, 'Started MakeMKV for drive $driveIndex. Output: $outputPath');
    await _persist();
    notifyListeners();
    process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen(
      (line) => _handleProcessLine(job, line),
      onError: (Object error) => _addEvent(job, 'stdout stream error: $error'),
    );
    process.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen(
      (line) => _handleProcessLine(job, line),
      onError: (Object error) => _addEvent(job, 'stderr stream error: $error'),
    );
    unawaited(_completeProcess(job, process));
    return job;
  }

  Future<void> cancelRip(String jobId) async {
    final job = _findJob(jobId);
    if (job.status != DiscRipStatus.running) return;
    final process = _activeJobId == jobId ? _activeProcess : null;
    if (process == null) throw StateError('This job is not controlled by the current app process.');
    job.status = DiscRipStatus.cancelled;
    job.phase = 'Cancellation requested';
    job.completedAt = DateTime.now();
    _addEvent(job, 'Cancellation requested by the user. The output folder may contain partial files.');
    process.kill();
    await _persist();
    notifyListeners();
  }

  Future<MkvValidationResult> validateMkv(String filePath) async {
    final clean = filePath.trim();
    if (clean.isEmpty) return MkvValidationResult(filePath: clean, sizeBytes: 0, hasEbmlHeader: false, error: 'Enter a file path.');
    if (!clean.toLowerCase().endsWith('.mkv')) {
      return MkvValidationResult(filePath: clean, sizeBytes: 0, hasEbmlHeader: false, error: 'The selected file must have an .mkv extension.');
    }
    final file = File(clean);
    if (!await file.exists()) {
      return MkvValidationResult(filePath: clean, sizeBytes: 0, hasEbmlHeader: false, error: 'The file does not exist or the path is not accessible.');
    }
    try {
      final size = await file.length();
      if (size < 4) return MkvValidationResult(filePath: clean, sizeBytes: size, hasEbmlHeader: false, error: 'The file is empty or too small to be an MKV container.');
      final handle = await file.open(mode: FileMode.read);
      late List<int> bytes;
      try {
        bytes = await handle.read(4);
      } finally {
        await handle.close();
      }
      final header = bytes.length == 4 && bytes[0] == 0x1a && bytes[1] == 0x45 && bytes[2] == 0xdf && bytes[3] == 0xa3;
      return MkvValidationResult(
        filePath: clean,
        sizeBytes: size,
        hasEbmlHeader: header,
        error: header ? null : 'The file does not have the expected EBML/Matroska header. This is a signature check, not a full video-integrity test.',
      );
    } on FileSystemException catch (error) {
      return MkvValidationResult(filePath: clean, sizeBytes: 0, hasEbmlHeader: false, error: 'Unable to read file: ${error.message}');
    }
  }

  Future<MediaItem> importMkvToLibrary({
    required String filePath,
    required String title,
    required String mediaKind,
    required String discType,
    int? releaseYear,
    String? artworkUrl,
    String? discTitle,
  }) async {
    final validation = await validateMkv(filePath);
    if (!validation.passed) throw StateError(validation.error ?? 'MKV validation failed.');
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) throw ArgumentError('Enter a title before importing.');
    if (!const {'movie', 'tv', 'music'}.contains(mediaKind)) {
      throw ArgumentError('Unsupported library type.');
    }
    if (releaseYear != null && (releaseYear < 1888 || releaseYear > DateTime.now().year + 10)) {
      throw ArgumentError('Release year is outside the accepted range.');
    }
    final cleanArtwork = (artworkUrl ?? '').trim();
    if (cleanArtwork.isNotEmpty) {
      final uri = Uri.tryParse(cleanArtwork);
      if (uri == null || !uri.hasAuthority || uri.scheme.toLowerCase() != 'https' || uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment) {
        throw ArgumentError('Artwork URL must be a stable HTTPS URL without credentials, query strings, or fragments.');
      }
    }
    final normalizedPath = _normalizePath(filePath);
    final profile = AppController.instance.currentProfile;
    final inferredOriginalLanguage = OriginalLanguageDefaults.resolveFromFields(
      title: cleanTitle,
    );
    final media = MediaItem(
      id: 'disc-import-${_stablePathHash(normalizedPath)}',
      title: cleanTitle,
      originalTitle: cleanTitle,
      originalLanguage: inferredOriginalLanguage,
      type: mediaKind,
      imageUrl: cleanArtwork.isEmpty ? null : cleanArtwork,
      description: 'Imported through the Disc Ingestion Center. Review the metadata and connect this item to a configured media-server playback gateway.',
      releaseYear: releaseYear,
      discType: discType,
      discTitle: (discTitle ?? '').trim().isEmpty ? null : discTitle!.trim(),
      addedAt: DateTime.now(),
      addedByProfileId: profile?.id,
      addedByProfileName: profile?.name,
      addedSource: 'disc_ingestion_center',
    );
    await AppController.instance.addToLibrary(media);
    final job = _jobs.firstWhereOrNull((item) => item.outputFiles.contains(filePath));
    if (job != null && !job.importedFiles.contains(filePath)) {
      job.importedFiles.add(filePath);
      _addEvent(job, 'Added "$cleanTitle" to the app library metadata. Playback URL was not inferred from a filesystem path.');
      await _persist();
    }
    notifyListeners();
    return media;
  }

  Future<void> refreshJobOutputs(String jobId) async {
    final job = _findJob(jobId);
    final directory = Directory(job.outputPath);
    if (!await directory.exists()) return;
    final files = await _listMkvFiles(directory.path);
    job.outputFiles
      ..clear()
      ..addAll(files);
    _addEvent(job, 'Output scan found ${files.length} MKV file(s).');
    await _persist();
    notifyListeners();
  }

  String suggestTitleFromPath(String path) {
    var base = path.trim().split(RegExp(r'[/\\]')).last;
    base = base.replaceFirst(RegExp(r'\.mkv$', caseSensitive: false), '');
    base = base.replaceAll(RegExp(r'[._]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    return base;
  }


  String _guessExecutablePath() {
    if (Platform.isWindows) {
      for (final path in <String>[
        r'C:\Program Files (x86)\MakeMKV\makemkvcon64.exe',
        r'C:\Program Files\MakeMKV\makemkvcon64.exe',
      ]) {
        if (File(path).existsSync()) return path;
      }
      return 'makemkvcon64.exe';
    }
    if (Platform.isMacOS) {
      const appBinary = '/Applications/MakeMKV.app/Contents/MacOS/makemkvcon';
      return File(appBinary).existsSync() ? appBinary : 'makemkvcon';
    }
    return 'makemkvcon';
  }

  String _resolveExecutable(String raw) {
    final candidate = raw.trim().isEmpty ? _guessExecutablePath() : raw.trim();
    final executableName = candidate.split(RegExp(r'[/\\]')).last.toLowerCase();
    if (!const <String>{'makemkvcon64.exe', 'makemkvcon.exe', 'makemkvcon'}.contains(executableName)) {
      throw StateError('Only the MakeMKV console executable (makemkvcon) may be launched from this screen.');
    }
    if (candidate.contains('/') || candidate.contains('\\')) {
      if (!File(candidate).existsSync()) throw StateError('MakeMKV console executable not found at: $candidate');
    }
    return candidate;
  }

  String _validateFolderName(String raw) {
    final name = raw.trim();
    if (name.isEmpty || name == '.' || name == '..' || name.contains('..')) {
      throw ArgumentError('Enter a simple subfolder name for this disc job.');
    }
    if (name.contains(RegExp(r'[<>:"/\\|?*\x00-\x1F]')) || name.endsWith('.') || name.endsWith(' ')) {
      throw ArgumentError('The job folder name contains characters that are not safe on Windows or NAS paths.');
    }
    return name;
  }

  String _joinPath(String parent, String child) {
    if (parent.endsWith('/') || parent.endsWith('\\')) return '$parent$child';
    return '$parent${Platform.pathSeparator}$child';
  }

  Future<void> _completeProcess(DiscRipJob job, Process process) async {
    var exitCode = -1;
    try {
      exitCode = await process.exitCode;
    } catch (error) {
      if (job.status != DiscRipStatus.cancelled) {
        job.error = 'Unable to read MakeMKV process exit status: $error';
      }
    }
    job.exitCode = exitCode;
    job.completedAt = DateTime.now();
    if (job.status == DiscRipStatus.cancelled) {
      job.phase = 'Cancelled';
    } else if (exitCode == 0) {
      final files = await _listMkvFiles(job.outputPath);
      job.outputFiles
        ..clear()
        ..addAll(files);
      if (files.isNotEmpty) {
        job.status = DiscRipStatus.succeeded;
        job.progress = 1;
        job.phase = 'Completed · ${files.length} MKV file(s) found';
        _addEvent(job, 'MakeMKV exited successfully; found ${files.length} MKV file(s). Review each file before importing.');
      } else {
        job.status = DiscRipStatus.failed;
        job.phase = 'Completed without output';
        job.error = 'MakeMKV exited with code 0, but no MKV files were found in this job folder.';
        _addEvent(job, job.error!);
      }
    } else {
      job.status = DiscRipStatus.failed;
      job.phase = 'Failed';
      job.error ??= 'MakeMKV exited with code $exitCode. Check the latest log entries and MakeMKV installation permissions.';
      _addEvent(job, job.error!);
    }
    if (_activeJobId == job.id) {
      _activeProcess = null;
      _activeJobId = null;
    }
    await _persist();
    notifyListeners();
  }

  void _handleProcessLine(DiscRipJob job, String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return;
    if (trimmed.startsWith('PRGT:') || trimmed.startsWith('PRGC:')) {
      final fields = _parseRobotCsv(trimmed.substring(5));
      if (fields.isNotEmpty && fields.last.trim().isNotEmpty) {
        job.phase = fields.last.replaceAll(RegExp(r'[\r\n]'), ' ').trim();
        _addEvent(job, job.phase);
      }
    } else if (trimmed.startsWith('PRGV:')) {
      final fields = _parseRobotCsv(trimmed.substring(5));
      if (fields.length >= 3) {
        final current = double.tryParse(fields[0]);
        final max = double.tryParse(fields[2]);
        if (current != null && max != null && max > 0) {
          job.progress = (current / max).clamp(0.0, 0.999).toDouble();
        }
      }
      final now = DateTime.now();
      if (now.difference(_lastProgressPersist) >= const Duration(seconds: 1)) {
        _lastProgressPersist = now;
        unawaited(_persist());
        notifyListeners();
      }
    } else if (trimmed.startsWith('MSG:')) {
      final fields = _parseRobotCsv(trimmed.substring(4));
      if (fields.length >= 4 && fields[3].trim().isNotEmpty) {
        _addEvent(job, fields[3].trim());
      } else {
        _addEvent(job, _truncate(trimmed, 300));
      }
    } else {
      _addEvent(job, _truncate(trimmed, 300));
    }
    unawaited(_persist());
    notifyListeners();
  }

  void _addEvent(DiscRipJob job, String message) {
    final clean = message.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.isEmpty) return;
    final entry = '${DateTime.now().toLocal().toIso8601String()} · ${_truncate(clean, 500)}';
    job.events.add(entry);
    if (job.events.length > 120) job.events.removeRange(0, job.events.length - 120);
  }

  Future<void> _persist() async {
    final prefs = _preferences;
    if (prefs == null) return;
    await prefs.setString(_historyKey, jsonEncode(_jobs.take(100).map((job) => job.toJson()).toList()));
  }

  DiscRipJob _findJob(String id) => _jobs.firstWhere(
        (job) => job.id == id,
        orElse: () => throw StateError('Rip job not found.'),
      );

  Future<List<String>> _listMkvFiles(String path) async {
    final directory = Directory(path);
    if (!await directory.exists()) return <String>[];
    final result = <String>[];
    await for (final entity in directory.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.toLowerCase().endsWith('.mkv')) result.add(entity.path);
    }
    result.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return result;
  }

  String _lastUsefulLine(String text, String fallback) {
    final lines = const LineSplitter().convert(text).map((line) => line.trim()).where((line) => line.isNotEmpty).toList();
    return lines.isEmpty ? fallback : _truncate(lines.last, 500);
  }

  String _normalizePath(String path) => path.trim().replaceAll('/', '\\').toLowerCase();

  String _stablePathHash(String path) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(path)) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  String _truncate(String value, int limit) => value.length <= limit ? value : '${value.substring(0, limit)}…';
}

extension _FirstWhereOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final value in this) {
      if (test(value)) return value;
    }
    return null;
  }
}

List<String> _parseRobotCsv(String value) {
  final fields = <String>[];
  final current = StringBuffer();
  var quoted = false;
  for (var i = 0; i < value.length; i++) {
    final char = value[i];
    if (char == '\\' && i + 1 < value.length) {
      final next = value[i + 1];
      if (next == ',' || next == '\\' || next == '"') {
        current.write(next);
        i++;
        continue;
      }
      current.write(char);
      continue;
    }
    if (char == '"') {
      quoted = !quoted;
    } else if (char == ',' && !quoted) {
      fields.add(current.toString());
      current.clear();
    } else {
      current.write(char);
    }
  }
  fields.add(current.toString());
  return fields;
}
