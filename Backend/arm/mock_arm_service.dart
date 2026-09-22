// FILE: `Backend/arm/mock_arm_service.dart`.
// Purpose: Provides a deterministic Phase 1 ARM simulation for development
// and verification when no physical ARM installation is available.
//
// This class is deliberately isolated from the production ARM client. It is
// enabled only by the backend ARM_MOCK=true environment setting.
//
// The mock intentionally exercises the same physical-media model used by the
// production ARM service:
//   Physical release
//     -> physical disc
//       -> disc content
//         -> optional canonical music recording
//
// This prevents the mock path from masking integration problems in the real
// ARM/import pipeline.

import 'arm_client.dart';
import 'arm_models.dart';
import 'arm_service.dart';

/// Simulates the ARM monitoring/ripping lifecycle without optical hardware.
///
/// Each refresh advances one deterministic state. The normal successful path
/// is:
///
///   queued
///     -> detecting
///     -> ripping
///     -> ripping
///     -> verifying
///     -> readyForReview
///
/// The optional verificationPasses=false mode exercises the rejected branch.
///
/// The simulated disc contains:
/// - one primary movie feature;
/// - one bonus feature;
/// - one trailer.
///
/// This is intentional: it verifies that a physical disc is not treated as
/// a single movie and that non-primary material remains separate content.
class MockArmService extends ArmService {
  final bool verificationPasses;

  final Map<String, ArmRipJob> _mockJobs = <String, ArmRipJob>{};
  final Map<String, int> _refreshCounts = <String, int>{};

  MockArmService({
    this.verificationPasses = true,
  }) : super(
          client: ArmClient(
            armServerUrl: 'http://127.0.0.1',
          ),
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
  Future<ArmDisc> scanDisc({
    required String driveId,
  }) async {
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
  Future<ArmRipJob> startImport({
    required String driveId,
  }) async {
    final now = DateTime.now();

    final feature = _buildFeatureTitle();
    final bonusFeature = _buildBonusFeatureTitle();
    final trailer = _buildTrailerTitle();

    final titles = <ArmDiscTitle>[
      feature,
      bonusFeature,
      trailer,
    ];

    final physicalRelease = ArmPhysicalRelease(
      id: 'mock-release-$driveId',
      title: 'Mock Disc Movie',
      releaseType: ArmReleaseType.movie,
      edition: 'Mock Collector Edition',
      barcode: null,
      country: 'United States',
      region: 'Region Free',
      releaseYear: 2026,
      discs: const <ArmPhysicalDisc>[],
      metadata: const <String, dynamic>{
        'source': 'Phase 1 mock ARM',
        'mock': true,
      },
    );

    final physicalDisc = ArmPhysicalDisc(
      id: 'mock-disc-$driveId',
      releaseId: physicalRelease.id,
      discNumber: 1,
      title: 'Mock Disc Movie — Disc 1',
      discType: ArmDiscType.movie,
      region: 'Region Free',
      outputPath: 'MOCK://media/mock-disc-movie/disc-1',
      contents: <ArmDiscContent>[
        feature.toDiscContent(
          discId: 'mock-disc-$driveId',
          contentId: 'mock-content-feature-$driveId',
        ),
        bonusFeature.toDiscContent(
          discId: 'mock-disc-$driveId',
          contentId: 'mock-content-bonus-$driveId',
        ),
        trailer.toDiscContent(
          discId: 'mock-disc-$driveId',
          contentId: 'mock-content-trailer-$driveId',
        ),
      ],
      metadata: const <String, dynamic>{
        'source': 'Phase 1 mock ARM',
        'mock': true,
      },
    );

    final releaseWithDisc = ArmPhysicalRelease(
      id: physicalRelease.id,
      title: physicalRelease.title,
      releaseType: physicalRelease.releaseType,
      edition: physicalRelease.edition,
      barcode: physicalRelease.barcode,
      country: physicalRelease.country,
      region: physicalRelease.region,
      releaseYear: physicalRelease.releaseYear,
      discs: <ArmPhysicalDisc>[
        physicalDisc,
      ],
      metadata: physicalRelease.metadata,
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
      outputPath: feature.outputPath,
      discType: 'DVD',
      region: 'Region Free',
      titles: titles,
      collectionTitle: 'Mock Disc Movie',
      physicalRelease: releaseWithDisc,
      physicalDisc: physicalDisc,
      recordings: const <ArmMusicRecording>[],
    );

    _mockJobs[job.id] = job;
    _refreshCounts[job.id] = 0;

    return job;
  }

  @override
  Future<ArmRipJob> refreshJob(
    String jobId,
  ) async {
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
        job.message =
            'Mock disc detected. ARM is identifying the physical release.';
        break;

      case 2:
        job.status = ArmJobStatus.ripping.name;
        job.progress = 30;
        job.message =
            'Mock ARM is ripping the physical disc and identifying disc contents.';
        break;

      case 3:
        job.status = ArmJobStatus.ripping.name;
        job.progress = 60;
        job.message =
            'Mock ARM is finishing the feature, bonus material, and trailer rip.';
        break;

      case 4:
        job.status = ArmJobStatus.verifying.name;
        job.progress = 85;
        job.message =
            'Mock ARM is verifying each simulated disc content item.';
        break;

      default:
        job.progress = 100;

        job.verification = _buildVerificationResult(job);

        job.status = verificationPasses
            ? ArmJobStatus.readyForReview.name
            : ArmJobStatus.rejected.name;

        job.message = verificationPasses
            ? 'Mock rip verified. Review the disc metadata and physical-media contents before adding it to your library.'
            : 'Mock rip rejected by verification. It cannot be added to your library.';

        job.completedAt = DateTime.now();
        break;
    }

    return job;
  }

  @override
  Future<ArmRipJob> cancelJob(
    String jobId,
  ) async {
    final job = _mockJobs[jobId];

    if (job == null) {
      throw Exception('Mock ARM job not found.');
    }

    job.status = ArmJobStatus.cancelled.name;
    job.message = 'Mock ARM import cancelled by the user.';

    return job;
  }

  ArmVerificationResult _buildVerificationResult(
    ArmRipJob job,
  ) {
    final contentCount = job.physicalDisc?.contents.length ?? job.titles.length;

    return ArmVerificationResult(
      passed: verificationPasses,
      score: verificationPasses ? 1.0 : 0.0,
      reason: verificationPasses
          ? 'Mock structural verification passed for the physical disc and its content items.'
          : 'Mock verification failure requested for Phase 1 testing.',
      checks: <String>[
        'Mock physical release identified',
        'Mock physical disc identified',
        'Mock output exists',
        'Mock primary feature identified',
        'Mock bonus content identified',
        'Mock trailer content identified',
        'Mock video stream present',
        'Mock audio stream present',
        'Mock duration check passed',
      ],
      failures: verificationPasses
          ? const <String>[]
          : const <String>[
              'Mock verification failure requested.',
            ],
      durationSeconds: 7200,
      expectedDurationSeconds: 7200,
      chapterCount: 12,
      expectedChapterCount: 12,
      hasVideo: true,
      hasAudio: true,
      contentFingerprintAvailable: false,
    );
  }

  ArmDiscTitle _buildFeatureTitle() {
    return ArmDiscTitle(
      id: 'mock-title-feature-1',
      title: 'Mock Disc Movie',
      mediaType: 'movie',
      classification: 'feature',
      year: 2026,
      durationSeconds: 7200,
      confidence: 1.0,
      outputPath: 'MOCK://media/mock-disc-movie/disc-1/feature.mkv',
      metadata: const <String, dynamic>{
        'source': 'Phase 1 mock ARM',
        'contentRole': 'primary',
      },
      canonicalTitle: 'Mock Disc Movie',
      originalTitle: 'Mock Disc Movie',
      originalLanguage: 'English',
      countryOfOrigin: 'United States',
      discTitle: 'Mock Disc Movie',
      detectedRegion: 'Region Free',
      archiveFormat: 'source',
    );
  }

  ArmDiscTitle _buildBonusFeatureTitle() {
    return ArmDiscTitle(
      id: 'mock-title-bonus-1',
      title: 'Mock Deleted Scenes',
      mediaType: 'movie',
      classification: 'bonus_feature',
      year: 2026,
      durationSeconds: 900,
      confidence: 1.0,
      outputPath:
          'MOCK://media/mock-disc-movie/disc-1/deleted-scenes.mkv',
      metadata: const <String, dynamic>{
        'source': 'Phase 1 mock ARM',
        'contentRole': 'bonus',
        'bonusType': 'deleted_scenes',
      },
      canonicalTitle: 'Mock Deleted Scenes',
      originalTitle: 'Mock Deleted Scenes',
      originalLanguage: 'English',
      countryOfOrigin: 'United States',
      discTitle: 'Mock Disc Movie',
      detectedRegion: 'Region Free',
      archiveFormat: 'source',
    );
  }

  ArmDiscTitle _buildTrailerTitle() {
    return ArmDiscTitle(
      id: 'mock-title-trailer-1',
      title: 'Mock Theatrical Trailer',
      mediaType: 'movie',
      classification: 'trailer',
      year: 2026,
      durationSeconds: 180,
      confidence: 1.0,
      outputPath:
          'MOCK://media/mock-disc-movie/disc-1/theatrical-trailer.mkv',
      metadata: const <String, dynamic>{
        'source': 'Phase 1 mock ARM',
        'contentRole': 'bonus',
        'bonusType': 'trailer',
      },
      canonicalTitle: 'Mock Theatrical Trailer',
      originalTitle: 'Mock Theatrical Trailer',
      originalLanguage: 'English',
      countryOfOrigin: 'United States',
      discTitle: 'Mock Disc Movie',
      detectedRegion: 'Region Free',
      archiveFormat: 'source',
    );
  }

  ArmRipJob? _latestJob() {
    if (_mockJobs.isEmpty) {
      return null;
    }

    return _mockJobs.values.last;
  }
}