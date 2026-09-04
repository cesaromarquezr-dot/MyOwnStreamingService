import 'dart:math';

import 'arm_client.dart';
import 'arm_models.dart';

class ArmService {
  final ArmClient client;

  final Random _random = Random();

  final Map<String, ArmRipJob> _jobs = {};

  ArmService({
    required this.client,
  });

  String _generateId(String prefix) {
    final timestamp =
        DateTime.now().microsecondsSinceEpoch;

    return '${prefix}_${timestamp}_${_random.nextInt(100000)}';
  }

  Future<bool> isConnected() async {
    return client.checkConnection();
  }

  Future<List<ArmDrive>> findDrives() async {
    /*
     * IMPORTANT:
     *
     * Do not put guessed ARM endpoints here.
     *
     * Once the exact ARM interface/API is confirmed,
     * this method will translate its response into
     * ArmDrive objects.
     */

    throw UnimplementedError(
      'ARM drive discovery has not been connected to the '
      'specific ARM interface yet.',
    );
  }

  Future<ArmDisc> scanDisc({
    required String driveId,
  }) async {
    /*
     * The backend API is ready for disc scanning.
     *
     * The actual ARM-specific implementation should be
     * connected here after confirming the ARM interface.
     */

    throw UnimplementedError(
      'ARM disc scanning has not been connected to the '
      'specific ARM interface yet.',
    );
  }

  Future<ArmRipJob> startImport({
    required String driveId,
  }) async {
    /*
     * This creates our internal job representation.
     *
     * The actual ARM start/import command must be connected
     * to the ARM installation's supported interface.
     */

    final job = ArmRipJob(
      id: _generateId('rip'),
      driveId: driveId,
      status: ArmJobStatus.queued.name,
      progress: 0,
      createdAt: DateTime.now(),
      message: 'Waiting for ARM import integration.',
    );

    _jobs[job.id] = job;

    return job;
  }

  ArmRipJob? getJob(
    String jobId,
  ) {
    return _jobs[jobId];
  }

  List<ArmRipJob> getAllJobs() {
    return _jobs.values.toList();
  }

  Future<ArmRipJob> refreshJob(
    String jobId,
  ) async {
    final job = _jobs[jobId];

    if (job == null) {
      throw Exception(
        'Rip job not found.',
      );
    }

    /*
     * Later this will query ARM and update:
     *
     * status
     * progress
     * title
     * media type
     * output path
     * error message
     */

    return job;
  }

  Future<ArmRipJob> cancelJob(
    String jobId,
  ) async {
    final job = _jobs[jobId];

    if (job == null) {
      throw Exception(
        'Rip job not found.',
      );
    }

    if (job.isFinished) {
      return job;
    }

    /*
     * Later this will send the appropriate cancellation
     * request to the ARM installation.
     */

    job.status = ArmJobStatus.cancelled.name;
    job.message = 'Import cancelled.';
    job.completedAt = DateTime.now();

    return job;
  }
}