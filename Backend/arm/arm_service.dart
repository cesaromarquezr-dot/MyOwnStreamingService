import 'dart:math';

import 'arm_client.dart';
import 'arm_models.dart';
import 'arm_verifier.dart';

class ArmService {
  final ArmClient client;
  final ArmVerifier verifier;

  final Random _random = Random();
  final Map<String, ArmRipJob> _jobs = {};
  final Map<String, String> _armJobIds = {};

  ArmService({
    required this.client,
    this.verifier = const ArmVerifier(),
  });

  String _generateId(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(100000)}';

  Future<bool> isConnected() => client.checkConnection();

  Future<List<ArmDrive>> findDrives() async {
    // ARM automatically detects optical-drive insertion through udev. Its
    // supported JSON UI API exposes jobs rather than a separate "insert disc"
    // command, so we infer active drives from current jobs and optional
    // ARM_DRIVES configuration.
    final configured = const String.fromEnvironment('ARM_DRIVES', defaultValue: '');
    final drives = <ArmDrive>[];

    for (final raw in configured.split(',')) {
      final path = raw.trim();
      if (path.isEmpty) continue;
      drives.add(
        ArmDrive(
          id: path,
          path: path,
          name: path,
          available: true,
          discInserted: false,
        ),
      );
    }

    final jobs = await _getArmJobs();
    final seen = <String>{...drives.map((d) => d.id)};

    for (final job in jobs) {
      final path = _string(job, ['devpath', 'device', 'drive', 'drive_path']);
      if (path == null || path.isEmpty || seen.contains(path)) continue;
      seen.add(path);
      drives.add(
        ArmDrive(
          id: path,
          path: path,
          name: path,
          available: true,
          discInserted: !_isFinishedArmStatus(_string(job, ['status'])),
        ),
      );
    }

    if (drives.isEmpty) {
      drives.add(
        ArmDrive(
          id: 'arm-auto',
          path: '',
          name: 'ARM automatic drive monitor',
          available: true,
          discInserted: false,
        ),
      );
    }

    return drives;
  }

  Future<ArmDisc> scanDisc({required String driveId}) async {
    final jobs = await _getArmJobs();
    final matching = jobs.where((job) {
      final path = _string(job, ['devpath', 'device', 'drive', 'drive_path']);
      return driveId == 'arm-auto' || path == driveId;
    }).toList();

    if (matching.isEmpty) {
      return ArmDisc(
        driveId: driveId,
        detected: false,
      );
    }

    final job = matching.last;
    return ArmDisc(
      driveId: driveId,
      title: _string(job, ['title', 'name']),
      mediaType: _string(job, ['videotype', 'mediaType', 'type']),
      discType: _normalizeDiscType(_string(job, ['disctype', 'discType'])),
      region: _string(job, ['region']),
      detected: true,
    );
  }

  Future<ArmRipJob> startImport({required String driveId}) async {
    final local = ArmRipJob(
      id: _generateId('rip'),
      driveId: driveId,
      status: ArmJobStatus.detecting.name,
      progress: 0,
      createdAt: DateTime.now(),
      message:
          'ARM is monitoring the optical drive. Insert the disc; ARM will detect and start the rip automatically.',
    );
    _jobs[local.id] = local;

    // ARM's normal workflow is automatic: inserting a disc triggers the job.
    // We snapshot the newest matching ARM job instead of inventing an ARM
    // "start" endpoint that does not exist.
    final jobs = await _getArmJobs();
    if (jobs.isNotEmpty) {
      final armJob = jobs.last;
      final armId = _string(armJob, ['job_id', 'jobId', 'id']);
      if (armId != null) _armJobIds[local.id] = armId;
      _applyArmJob(local, armJob);
    }

    return local;
  }

  Future<ArmRipJob> refreshJob(String jobId) async {
    final local = _jobs[jobId];
    if (local == null) throw Exception('Rip job not found.');

    final jobs = await _getArmJobs();
    Map<String, dynamic>? selected;

    final armId = _armJobIds[jobId];
    if (armId != null) {
      for (final job in jobs) {
        if (_string(job, ['job_id', 'jobId', 'id']) == armId) {
          selected = job;
          break;
        }
      }
    }

    selected ??= _selectRelevantJob(jobs, local.driveId);
    if (selected != null) {
      final foundArmId = _string(selected, ['job_id', 'jobId', 'id']);
      if (foundArmId != null) _armJobIds[jobId] = foundArmId;
      _applyArmJob(local, selected);

      if (_isCompleted(local.status) &&
          local.outputPath != null &&
          local.verification == null) {
        local.status = ArmJobStatus.verifying.name;
        local.verification = await verifier.verify(
          outputPath: local.outputPath!,
          expectedDurationSeconds:
              _double(selected, ['duration', 'runtime', 'length']),
          expectedChapterCount:
              _int(selected, ['chapter_count', 'chapterCount', 'chapters']),
        );
        if (local.verification!.passed) {
          local.status = ArmJobStatus.readyForReview.name;
          local.message = 'Rip verified. Review the metadata before adding it to your library.';
        } else {
          local.status = ArmJobStatus.rejected.name;
          local.message = local.verification!.reason;
        }
      }
    }

    return local;
  }

  Future<ArmRipJob> cancelJob(String jobId) async {
    final job = _jobs[jobId];
    if (job == null) throw Exception('Rip job not found.');
    if (job.isFinished) return job;

    // ARM exposes "abandon" in its web UI. We keep cancellation local unless
    // a stable authenticated abandon endpoint is explicitly configured.
    job.status = ArmJobStatus.cancelled.name;
    job.message = 'Import cancelled.';
    job.completedAt = DateTime.now();
    return job;
  }

  Future<List<Map<String, dynamic>>> _getArmJobs() async {
    final response = await client.getJsonMode('joblist');
    final results = response['results'];
    if (results is Map) {
      return results.values
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (results is List) {
      return results.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return <Map<String, dynamic>>[];
  }

  Map<String, dynamic>? _selectRelevantJob(
    List<Map<String, dynamic>> jobs,
    String driveId,
  ) {
    if (jobs.isEmpty) return null;
    if (driveId == 'arm-auto' || driveId.isEmpty) return jobs.last;

    for (final job in jobs.reversed) {
      final path = _string(job, ['devpath', 'device', 'drive', 'drive_path']);
      if (path == driveId) return job;
    }
    return jobs.last;
  }

  void _applyArmJob(ArmRipJob local, Map<String, dynamic> arm) {
    local.title = _string(arm, ['title', 'name']);
    local.mediaType = _string(arm, ['videotype', 'mediaType', 'type']);
    local.discType = _normalizeDiscType(_string(arm, ['disctype', 'discType']));
    local.region = _string(arm, ['region']);
    local.outputPath = _string(
      arm,
      ['outputPath', 'output_path', 'path', 'destination', 'destination_path'],
    );
    local.progress = _double(
          arm,
          ['progress_round', 'progress', 'percent'],
        ) ??
        0;
    final rawStatus = (_string(arm, ['status', 'state']) ?? 'active').toLowerCase();
    local.status = _mapStatus(rawStatus);
    local.message = _string(arm, ['message', 'stage', 'status']);
    if (_isCompleted(local.status)) {
      local.completedAt ??= DateTime.now();
    }
  }

  String _mapStatus(String raw) {
    if (raw.contains('fail') || raw.contains('error')) return ArmJobStatus.failed.name;
    if (raw.contains('success') || raw.contains('complete') || raw == 'finished') {
      return ArmJobStatus.completed.name;
    }
    if (raw.contains('transcod')) return ArmJobStatus.processing.name;
    if (raw.contains('rip')) return ArmJobStatus.ripping.name;
    if (raw.contains('ident')) return ArmJobStatus.identifying.name;
    return ArmJobStatus.processing.name;
  }

  bool _isCompleted(String status) =>
      status == ArmJobStatus.completed.name ||
      status == ArmJobStatus.failed.name;

  bool _isFinishedArmStatus(String? status) {
    final value = (status ?? '').toLowerCase();
    return value.contains('success') ||
        value.contains('finish') ||
        value.contains('complete') ||
        value.contains('fail') ||
        value.contains('error');
  }

  String? _string(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  double? _double(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      final parsed = value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }

  int? _int(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      final parsed = value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }

  String? _normalizeDiscType(String? value) {
    if (value == null) return null;
    final v = value.toLowerCase();
    if (v.contains('4k') || v.contains('uhd')) return '4K Ultra HD';
    if (v.contains('bluray') || v.contains('blu-ray')) return 'Blu-ray';
    if (v.contains('dvd')) return 'DVD';
    return value;
  }
}
