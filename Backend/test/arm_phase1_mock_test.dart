// FILE: `Backend/test/arm_phase1_mock_test.dart`.
// Purpose: Verifies the deterministic Phase 1 mock ARM state machine,
// physical-media provenance, verification, and cancellation behavior.

import 'package:test/test.dart';

import '../arm/arm_models.dart';
import '../arm/mock_arm_service.dart';

void main() {
test('successful mock ARM workflow reaches readyForReview', () async {
final arm = MockArmService();

expect(await arm.isConnected(), isTrue);

final job = await arm.startImport(driveId: 'mock-drive-1');

expect(job.status, ArmJobStatus.queued.name);
expect(job.driveId, 'mock-drive-1');
expect(job.physicalRelease, isNotNull);
expect(job.physicalDisc, isNotNull);
expect(job.physicalRelease!.discs, isNotEmpty);
expect(job.physicalDisc!.releaseId, job.physicalRelease!.id);
expect(job.physicalDisc!.discNumber, greaterThanOrEqualTo(1));

var current = job;
for (var i = 0; i < 4; i++) {
  current = await arm.refreshJob(current.id);
}

expect(current.status, ArmJobStatus.readyForReview.name);
expect(current.verification?.passed, isTrue);

final release = current.physicalRelease;
final disc = current.physicalDisc;

expect(release, isNotNull);
expect(disc, isNotNull);
expect(disc!.releaseId, release!.id);
expect(disc.contents, isNotEmpty);

final primaryContents =
    disc.contents.where((content) => content.primary).toList();
final bonusContents =
    disc.contents.where((content) => content.isBonus).toList();

expect(primaryContents, isNotEmpty);
expect(bonusContents, isNotEmpty);

expect(
  bonusContents.any(
    (content) =>
        content.contentType == ArmDiscContentType.bonusFeature.name,
  ),
  isTrue,
);

});

test('failed mock verification reaches rejected', () async {
final arm = MockArmService(verificationPasses: false);

final job = await arm.startImport(driveId: 'mock-drive-1');

var current = job;
for (var i = 0; i < 4; i++) {
  current = await arm.refreshJob(current.id);
}

expect(current.status, ArmJobStatus.rejected.name);
expect(current.verification?.passed, isFalse);

});

test('cancelled mock job cannot advance to review', () async {
final arm = MockArmService();

final job = await arm.startImport(driveId: 'mock-drive-1');
final cancelled = await arm.cancelJob(job.id);

expect(cancelled.status, ArmJobStatus.cancelled.name);

final refreshed = await arm.refreshJob(job.id);

expect(refreshed.status, ArmJobStatus.cancelled.name);

});

test('mock ARM workflow preserves deterministic job identity', () async {
final arm = MockArmService();

final job = await arm.startImport(driveId: 'mock-drive-1');

final firstRefresh = await arm.refreshJob(job.id);
final secondRefresh = await arm.refreshJob(job.id);

expect(firstRefresh.id, job.id);
expect(secondRefresh.id, job.id);
expect(firstRefresh.driveId, job.driveId);
expect(secondRefresh.driveId, job.driveId);

});
}
