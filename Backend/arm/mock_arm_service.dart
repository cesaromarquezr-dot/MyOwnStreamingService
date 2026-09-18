// FILE: `Backend/arm/mock_arm_service.dart`.
//
// Purpose:
// Simulates an Automatic Ripping Machine for development and review before
// real ARM hardware is available.
//
// STATUS:
// MOCK / UNVERIFIED.
//
// This implementation does NOT access an optical drive.
// It does NOT communicate with real ARM.
// It does NOT rip discs.
//
// It simulates:
// - ARM online/offline state
// - optical drive discovery
// - disc insertion
// - title identification
// - ripping progress
// - processing
// - verification
// - ready-for-review state
// - failed/cancelled workflows

import 'dart:async';

import 'arm_models.dart';

/// Mock ARM service used for testing the Import/Rip workflow without hardware.
class MockArmService {
  final List<ArmDrive> _drives = [
    ArmDrive(
      id: 'mock-drive-1',
      path: '/dev/mock/sr0',
      name: 'Mock USB Blu-ray Drive',
      available: true,
      discInserted: false,
    ),
  ];

  final Map<String, ArmRipJob> _jobs = {};

  bool _online = true;
  int _jobCounter = 0;

  /// Indicates whether the simulated ARM service is online.
  bool get isOnline => _online;

  /// Sets the simulated ARM connectivity state.
  void setOnline(bool value) {
    _online = value;
  }

  /// Returns simulated optical drives.
  Future<List<ArmDrive>> findDrives() async {
    _requireOnline();

    return List<ArmDrive>.unmodifiable(
      _drives,
    );
  }

  /// Simulates inserting a movie disc.
  ///
  /// The disc title is deliberately preserved as the original disc title so
  /// the later metadata resolver can rematch it without losing source data.
  Future<ArmRipJob> insertMovieDisc({
    String title = 'The Matrix',
    int year = 1999,
  }) async {
    _requireOnline();

    final drive = _drives.first;

    _setDiscInserted(
      drive.id,
      true,
    );

    final job = ArmRipJob(
      id: _nextJobId(),
      driveId: drive.id,
      status: ArmJobStatus.detecting.name,
      progress: 0,
      createdAt: DateTime.now(),
      title: title,
      mediaType: 'movie',
      message: 'Mock disc detected.',
      outputPath:
          '/mock/arm/output/${_safeName(title)}.mkv',
      discType: 'Blu-ray',
      region: 'A',
      titles: [
        ArmDiscTitle(
          id: 'mock-title-1',
          title: title,
          mediaType: 'movie',
          classification: 'feature',
          year: year,
          durationSeconds: 8160,
          confidence: 0.96,
          outputPath:
              '/mock/arm/output/${_safeName(title)}.mkv',
          discTitle: title,
          detectedRegion: 'A',
          audioCodec: 'DTS',
          archiveFormat: 'source',
          losslessAudio: false,
          metadata: {
            'mock': true,
            'discTitle': title,
          },
        ),
      ],
    );

    _jobs[job.id] = job;

    return job;
  }

  /// Simulates inserting an audio CD.
  Future<ArmRipJob> insertMusicDisc({
    String album = 'Mock Album',
    String artist = 'Mock Artist',
  }) async {
    _requireOnline();

    final drive = _drives.first;

    _setDiscInserted(
      drive.id,
      true,
    );

    final job = ArmRipJob(
      id: _nextJobId(),
      driveId: drive.id,
      status: ArmJobStatus.detecting.name,
      progress: 0,
      createdAt: DateTime.now(),
      title: album,
      mediaType: 'music',
      message: 'Mock audio CD detected.',
      outputPath:
          '/mock/arm/output/${_safeName(album)}',
      discType: 'Audio CD',
      titles: [
        ArmDiscTitle(
          id: 'mock-track-1',
          title: album,
          mediaType: 'music',
          classification: 'album',
          confidence: 0.94,
          outputPath:
              '/mock/arm/output/${_safeName(album)}',
          discTitle: album,
          archiveFormat: 'flac',
          losslessAudio: true,
          artist: artist,
          album: album,
          trackNumber: 1,
          discNumber: 1,
          metadata: {
            'mock': true,
            'discTitle': album,
            'artist': artist,
            'album': album,
          },
        ),
      ],
    );

    _jobs[job.id] = job;

    return job;
  }

  /// Advances a mock rip by the requested percentage.
  Future<ArmRipJob> advance(
    String jobId, {
    double amount = 10,
  }) async {
    _requireOnline();

    final job = _getJob(jobId);

    if (job.isFinished) {
      return job;
    }

    job.progress =
        (job.progress + amount).clamp(0, 100);

    if (job.progress < 5) {
      job.status = ArmJobStatus.detecting.name;
      job.message = 'Detecting disc...';
    } else if (job.progress < 15) {
      job.status = ArmJobStatus.identifying.name;
      job.message = 'Identifying disc...';
    } else if (job.progress < 85) {
      job.status = ArmJobStatus.ripping.name;
      job.message =
          'Mock ARM is ripping the disc...';
    } else if (job.progress < 100) {
      job.status = ArmJobStatus.processing.name;
      job.message =
          'Finalizing the ripped media...';
    } else {
      job.progress = 100;
      job.status = ArmJobStatus.verifying.name;
      job.message =
          'Running media verification...';

      job.verification = _successfulVerification();

      if (job.verification!.passed) {
        job.status =
            ArmJobStatus.readyForReview.name;
        job.message =
            'Mock rip verified. Ready for metadata review.';
        job.completedAt = DateTime.now();
      } else {
        job.status =
            ArmJobStatus.rejected.name;
        job.message =
            'Mock rip failed verification.';
      }

      _setDiscInserted(
        job.driveId,
        false,
      );
    }

    return job;
  }

  /// Returns the current mock job.
  Future<ArmRipJob> refreshJob(String jobId) async {
    _requireOnline();

    return _getJob(jobId);
  }

  /// Simulates cancelling a rip.
  Future<ArmRipJob> cancelJob(String jobId) async {
    _requireOnline();

    final job = _getJob(jobId);

    if (!job.isFinished) {
      job.status =
          ArmJobStatus.cancelled.name;
      job.message = 'Mock import cancelled.';
      job.completedAt = DateTime.now();

      _setDiscInserted(
        job.driveId,
        false,
      );
    }

    return job;
  }

  /// Simulates a verification failure for review testing.
  Future<ArmRipJob> failVerification(
    String jobId,
  ) async {
    _requireOnline();

    final job = _getJob(jobId);

    job.progress = 100;
    job.status =
        ArmJobStatus.verifying.name;

    job.verification = ArmVerificationResult(
      passed: false,
      score: 25,
      reason:
          'Mock verification failure.',
      checks: const [
        'Mock file exists.',
      ],
      failures: const [
        'Mock corrupted video stream.',
        'Mock audio stream mismatch.',
      ],
      hasVideo: true,
      hasAudio: false,
      contentFingerprintAvailable: false,
    );

    job.status =
        ArmJobStatus.rejected.name;

    job.message =
        'Mock rip rejected by verification.';

    return job;
  }

  /// Creates the successful verification result used by mock jobs.
  ArmVerificationResult _successfulVerification() {
    return const ArmVerificationResult(
      passed: true,
      score: 100,
      reason:
          'Mock media passed structural verification.',
      checks: [
        'Mock output exists.',
        'Mock video stream is readable.',
        'Mock audio stream is readable.',
        'Mock runtime is within tolerance.',
      ],
      failures: [],
      durationSeconds: 8160,
      expectedDurationSeconds: 8160,
      chapterCount: 24,
      expectedChapterCount: 24,
      hasVideo: true,
      hasAudio: true,
      contentFingerprintAvailable: false,
    );
  }

  /// Returns a unique mock ARM job ID.
  String _nextJobId() {
    _jobCounter++;

    return 'mock-arm-job-$_jobCounter';
  }

  /// Gets a mock job or throws when it doesn't exist.
  ArmRipJob _getJob(String jobId) {
    final job = _jobs[jobId];

    if (job == null) {
      throw StateError(
        'Mock ARM job "$jobId" was not found.',
      );
    }

    return job;
  }

  /// Changes simulated optical-drive insertion state.
  void _setDiscInserted(
    String driveId,
    bool inserted,
  ) {
    final index = _drives.indexWhere(
      (drive) => drive.id == driveId,
    );

    if (index == -1) return;

    final old = _drives[index];

    _drives[index] = ArmDrive(
      id: old.id,
      path: old.path,
      name: old.name,
      available: old.available,
      discInserted: inserted,
    );
  }

  /// Ensures the mock ARM service is online.
  void _requireOnline() {
    if (!_online) {
      throw StateError(
        'MOCK ARM is offline.',
      );
    }
  }

  /// Produces a filesystem-safe mock filename.
  String _safeName(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }
}