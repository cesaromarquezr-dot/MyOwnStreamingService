// FILE: `Backend/test/arm_phase1_mock_test.dart`.
// Purpose: Verifies the deterministic Phase 1 mock ARM state machine.

import 'package:test/test.dart';

import '../arm/arm_models.dart';
import '../arm/mock_arm_service.dart';

void main() {
  test('successful mock ARM workflow reaches readyForReview', () async {
    final arm = MockArmService();
    expect(await arm.isConnected(), isTrue);

    final job = await arm.startImport(driveId: 'mock-drive-1');
    expect(job.status, ArmJobStatus.queued.name);

    var current = job;
    for (var i = 0; i < 4; i++) {
      current = await arm.refreshJob(job.id);
    }

    expect(current.status, ArmJobStatus.readyForReview.name);
    expect(current.verification?.passed, isTrue);
  });

  test('failed mock verification reaches rejected', () async {
    final arm = MockArmService(verificationPasses: false);
    final job = await arm.startImport(driveId: 'mock-drive-1');

    var current = job;
    for (var i = 0; i < 4; i++) {
      current = await arm.refreshJob(job.id);
    }

    expect(current.status, ArmJobStatus.rejected.name);
    expect(current.verification?.passed, isFalse);
  });

  test('cancelled mock job cannot advance to review', () async {
    final arm = MockArmService();
    final job = await arm.startImport(driveId: 'mock-drive-1');
    final cancelled = await arm.cancelJob(job.id);

    expect(cancelled.status, ArmJobStatus.cancelled.name);
  });
}
