// FILE: `Backend/arm/mock_arm_service.dart`.
// Purpose: Provides a deterministic Phase 1 ARM simulation for development
// and verification when no physical ARM installation is available.
//
// This class is deliberately isolated from the production ARM client. It is
// enabled only by the backend ARM_MOCK=true environment setting.

import 'arm_client.dart';
import 'arm_models.dart';
import 'arm_service.dart';

/// Simulates the ARM monitoring/ripping lifecycle without optical hardware.
///
/// Each refresh advances one deterministic state. The normal successful path
/// is queued -> detecting -> ripping -> verifying -> readyForReview. The
/// optional verificationPasses=false mode exercises the rejected branch.
class MockArmService extends ArmService {
  final bool verificationPasses;
  final Map<String, ArmRipJob> _mockJobs = <String, ArmRipJob>{};
  final Map<String, int> _refreshCounts = <String, int>{};

  MockArmService({this.verificationPasses = true})
      : super(
          client: ArmClient(armServerUrl: 'http://127.0.0.1'),
        );

  @override
  Future<bool> isConnected() async => true;

  @override
  Future<List<ArmDrive>> findDrives() async {
    final inserted = _mockJobs.values.any(
      (job) => !job.isFinished,
    );

    return <ArmDrive>[
      ArmDrive(
        id: 'mock-drive-1',
        path: 'MOCK://optical-drive-1',
        name: 'Mock ARM Optical Drive',
        available: true,
        discInserted: inserted,
      ),
    ];
  }

  @override
  Future<ArmDisc> scanDisc({required String driveId}) async {
    final job = _latestJob();
    if (job == null) {
      return ArmDisc(
        driveId: driveId,
        detected: false,
      );
    }

    return ArmDisc(
      driveId: driveId,
      title: job.title,
      mediaType: job.mediaType,
      discType: job.discType,
      region: job.region,
      detected: true,
      titles: job.titles,
    );
  }

  @override
  Future<ArmRipJob> startImport({required String driveId}) async {
    final now = DateTime.now();
    final title = ArmDiscTitle(
      id: 'mock-title-1',
      title: 'Mock Disc Movie',
      mediaType: 'movie',
      classification: 'feature',
      year: 2026,
      durationSeconds: 7200,
      confidence: 1.0,
      outputPath: 'MOCK://media/mock-disc-movie.mkv',
      metadata: const <String, dynamic>{
        'source': 'Phase 1 mock ARM',
      },
      canonicalTitle: 'Mock Disc Movie',
      originalTitle: 'Mock Disc Movie',
      originalLanguage: 'English',
      countryOfOrigin: 'United States',
      discTitle: 'Mock Disc Movie',
      detectedRegion: 'Region Free',
      archiveFormat: 'source',
    );

    final job = ArmRipJob(
      id: 'mock_rip_${now.microsecondsSinceEpoch}',
      driveId: driveId,
      status: ArmJobStatus.queued.name,
      progress: 0,
      createdAt: now,
      title: 'Mock Disc Movie',
      mediaType: 'movie',
      message: 'Mock ARM is waiting for the simulated disc insertion.',
      outputPath: title.outputPath,
      discType: 'DVD',
      region: 'Region Free',
      titles: <ArmDiscTitle>[title],
      collectionTitle: 'Mock Disc Movie',
    );

    _mockJobs[job.id] = job;
    _refreshCounts[job.id] = 0;
    return job;
  }

  @override
  Future<ArmRipJob> refreshJob(String jobId) async {
    final job = _mockJobs[jobId];
    if (job == null) {
      throw Exception('Mock ARM job not found.');
    }

    final count = (_refreshCounts[jobId] ?? 0) + 1;
    _refreshCounts[jobId] = count;

    switch (count) {
      case 1:
        job.status = ArmJobStatus.detecting.name;
        job.progress = 5;
        job.message = 'Mock disc detected. ARM is identifying the disc.';
        break;
      case 2:
        job.status = ArmJobStatus.ripping.name;
        job.progress = 30;
        job.message = 'Mock ARM is ripping the disc.';
        break;
      case 3:
        job.status = ArmJobStatus.ripping.name;
        job.progress = 60;
        job.message = 'Mock ARM is finishing the disc rip.';
        break;
      case 4:
        job.status = ArmJobStatus.verifying.name;
        job.progress = 85;
        job.message = 'Mock ARM is verifying the ripped media.';
        break;
      default:
        job.progress = 100;
        job.verification = ArmVerificationResult(
          passed: verificationPasses,
          score: verificationPasses ? 1.0 : 0.0,
          reason: verificationPasses
              ? 'Mock structural verification passed.'
              : 'Mock verification failure requested for Phase 1 testing.',
          checks: const <String>[
            'Mock output exists',
            'Mock video stream present',
            'Mock audio stream present',
            'Mock duration check passed',
          ],
          failures: verificationPasses
              ? const <String>[]
              : const <String>['Mock verification failure requested.'],
          durationSeconds: 7200,
          expectedDurationSeconds: 7200,
          chapterCount: 12,
          expectedChapterCount: 12,
          hasVideo: true,
          hasAudio: true,
          contentFingerprintAvailable: false,
        );
        job.status = verificationPasses
            ? ArmJobStatus.readyForReview.name
            : ArmJobStatus.rejected.name;
        job.message = verificationPasses
            ? 'Mock rip verified. Review the disc metadata before adding it to your library.'
            : 'Mock rip rejected by verification. It cannot be added to your library.';
        job.completedAt = DateTime.now();
        break;
    }

    return job;
  }

  @override
  Future<ArmRipJob> cancelJob(String jobId) async {
    final job = _mockJobs[jobId];
    if (job == null) {
      throw Exception('Mock ARM job not found.');
    }
    job.status = ArmJobStatus.cancelled.name;
    job.message = 'Mock ARM import cancelled by the user.';
    return job;
  }

  ArmRipJob? _latestJob() {
    if (_mockJobs.isEmpty) return null;
    return _mockJobs.values.last;
  }
}
