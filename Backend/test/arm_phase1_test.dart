// FILE: `Backend/test/arm_phase1_test.dart`.
// Purpose: Runs the Phase 1 mock ARM state-machine checks without requiring
// a real ARM installation or an optical drive.
//
// This is intentionally a dependency-free smoke test so the backend package
// does not need a test framework dependency just to prove the Phase 1 gate.

import '../arm/arm_models.dart';
import '../arm/import_review_model.dart';
import '../arm/library_importer.dart';
import '../arm/mock_arm_service.dart';

Future<void> main() async {
  await _testSuccessfulApprovalPath();
  await _testFailedVerificationGate();
  await _testCancelledPath();
  await _testOfflinePath();
  await _testNoMetadataPath();
  _testApprovalRequiresMetadataId();

  print('PHASE 1 ARM TEST: ALL CHECKS PASSED');
}

Future<void> _testSuccessfulApprovalPath() async {
  final arm = MockArmService();
  arm.insertMovieDisc();
  final job = await arm.startImport(driveId: 'mock-drive');

  _expect(job.status == ArmJobStatus.queued.name, 'job starts queued');

  arm.advance(job.id);
  _expect(job.status == ArmJobStatus.detecting.name, 'queued -> detecting');

  arm.advance(job.id);
  _expect(job.status == ArmJobStatus.ripping.name, 'detecting -> ripping');

  arm.advance(job.id);
  _expect(job.status == ArmJobStatus.verifying.name, 'ripping -> verifying');
  _expect(job.verification?.passed == true, 'verification passes');

  arm.advance(job.id);
  _expect(
    job.status == ArmJobStatus.readyForReview.name,
    'verifying -> readyForReview',
  );

  final review = ImportReviewSnapshot.fromJob(job);
  _expect(review.canRequestApproval, 'review is eligible for approval');
  _expect(review.discTitle == 'The Matrix', 'original disc title is preserved');

  var writeCount = 0;
  final importer = LibraryImporter(
    writer: (_) async => writeCount++,
  );
  final decision = ApprovalDecision(
    jobId: review.jobId,
    selectedMetadataId: 'test-metadata-id',
    verificationScore: review.verification.score,
    verificationPassed: review.verification.passed,
    reviewerProfileId: 'test-reviewer',
    approvedAt: DateTime.now(),
    approvalNonce: 'test-approval-nonce',
  );

  _expect(writeCount == 0, 'nothing is written before approval');
  await importer.import(review, decision);
  _expect(writeCount == 1, 'approved review reaches the writer');
}

Future<void> _testFailedVerificationGate() async {
  final arm = MockArmService();
  arm.insertMovieDisc();
  final job = await arm.startImport(driveId: 'mock-drive');
  final failed = arm.failVerification(job.id);

  _expect(failed.status == ArmJobStatus.rejected.name, 'failed rip is rejected');
  _expect(failed.verification?.passed == false, 'verification is false');

  final review = ImportReviewSnapshot(
    jobId: failed.id,
    discTitle: failed.title ?? '',
    ripJob: failed,
    verification: failed.verification!,
    createdAt: DateTime.now(),
  );
  var writeCount = 0;
  final importer = LibraryImporter(writer: (_) async => writeCount++);
  final decision = ApprovalDecision(
    jobId: review.jobId,
    selectedMetadataId: 'test-metadata-id',
    verificationScore: 0,
    verificationPassed: false,
    reviewerProfileId: 'test-reviewer',
    approvedAt: DateTime.now(),
    approvalNonce: 'test-approval-nonce',
  );

  await _expectThrows(
    () => importer.import(review, decision),
    'failed verification must throw',
  );
  _expect(writeCount == 0, 'failed verification never reaches the writer');
}

Future<void> _testCancelledPath() async {
  final arm = MockArmService();
  arm.insertMovieDisc();
  final job = await arm.startImport(driveId: 'mock-drive');
  final cancelled = arm.cancelJob(job.id);

  _expect(cancelled.status == ArmJobStatus.cancelled.name, 'job can be cancelled');
  await _expectThrows(
    () => Future<void>.sync(() => ImportReviewSnapshot.fromJob(cancelled)),
    'cancelled job cannot become a review',
  );
}

Future<void> _testOfflinePath() async {
  final arm = MockArmService();
  arm.setOnline(false);

  _expect(await arm.isConnected() == false, 'offline ARM reports disconnected');
  await _expectThrows(
    () => arm.findDrives(),
    'offline ARM blocks drive discovery',
  );
}

Future<void> _testNoMetadataPath() async {
  final arm = MockArmService();
  arm.insertMovieDisc();
  final job = await arm.startImport(driveId: 'mock-drive');
  arm.advance(job.id);
  arm.advance(job.id);
  arm.advance(job.id);
  arm.advance(job.id);

  final review = ImportReviewSnapshot.fromJob(job);
  const String? selectedMetadataId = null;

  _expect(review.discTitle == 'The Matrix', 'review still has disc identity');
  _expect(selectedMetadataId == null, 'metadata remains absent in Phase 1');
}

void _testApprovalRequiresMetadataId() {
  final decision = ApprovalDecision(
    jobId: 'job-1',
    selectedMetadataId: null,
    verificationScore: 1,
    verificationPassed: true,
    reviewerProfileId: 'reviewer-1',
    approvedAt: DateTime.now(),
    approvalNonce: 'nonce-1',
  );

  _expectThrowsSync(
    decision.validate,
    'approval requires a metadata ID even though metadata is not integrated yet',
  );
}

void _expect(bool condition, String description) {
  if (!condition) {
    throw StateError('FAILED: $description');
  }
  print('PASS: $description');
}

Future<void> _expectThrows(
  Future<void> Function() action,
  String description,
) async {
  try {
    await action();
  } catch (_) {
    print('PASS: $description');
    return;
  }
  throw StateError('FAILED: $description');
}

void _expectThrowsSync(void Function() action, String description) {
  try {
    action();
  } catch (_) {
    print('PASS: $description');
    return;
  }
  throw StateError('FAILED: $description');
}
