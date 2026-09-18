// FILE: `Backend/arm/import_review_model.dart`.
//
// Purpose:
// Contains immutable snapshots and explicit approval decisions used by the
// Import/Rip review workflow.
//
// STATUS:
// MOCK / UNVERIFIED.
//
// Security:
// A library import cannot be authorized with a simple boolean. The approval
// decision contains the specific job, selected metadata, verification result,
// and reviewer information that produced the decision.

import 'arm_models.dart';
import 'metadata_service.dart';

/// Immutable snapshot shown to the user during import review.
class ImportReviewSnapshot {
  final String jobId;
  final ArmDiscTitle discTitle;
  final MetadataSearchResult metadata;
  final ArmVerificationResult verification;
  final MetadataCandidate? selectedMatch;
  final DateTime createdAt;

  const ImportReviewSnapshot({
    required this.jobId,
    required this.discTitle,
    required this.metadata,
    required this.verification,
    this.selectedMatch,
    required this.createdAt,
  });

  /// Returns the original disc title exactly as reported by ARM.
  String get originalDiscTitle =>
      discTitle.discTitle ?? discTitle.title;

  /// Creates a copy after the reviewer selects a metadata candidate.
  ImportReviewSnapshot selectMatch(
    MetadataCandidate candidate,
  ) {
    return ImportReviewSnapshot(
      jobId: jobId,
      discTitle: discTitle,
      metadata: metadata,
      verification: verification,
      selectedMatch: candidate,
      createdAt: createdAt,
    );
  }

  /// Indicates whether the snapshot contains enough information to request
  /// approval. This does not itself approve the import.
  bool get canRequestApproval =>
      verification.passed &&
      selectedMatch != null &&
      selectedMatch!.id.trim().isNotEmpty;
}

/// Explicit approval record required by LibraryImporter.
class ApprovalDecision {
  final String jobId;
  final String selectedMetadataId;
  final MetadataProvider selectedProvider;
  final double verificationScore;
  final bool verificationPassed;
  final String reviewerProfileId;
  final DateTime approvedAt;
  final String approvalNonce;

  const ApprovalDecision({
    required this.jobId,
    required this.selectedMetadataId,
    required this.selectedProvider,
    required this.verificationScore,
    required this.verificationPassed,
    required this.reviewerProfileId,
    required this.approvedAt,
    required this.approvalNonce,
  });

  /// Creates an approval decision only after validating the review snapshot.
  factory ApprovalDecision.fromReview({
    required ImportReviewSnapshot review,
    required String reviewerProfileId,
    required String approvalNonce,
  }) {
    final selected = review.selectedMatch;

    if (!review.verification.passed) {
      throw StateError(
        'A failed verification cannot be approved.',
      );
    }

    if (selected == null || selected.id.trim().isEmpty) {
      throw StateError(
        'A metadata match must be selected before approval.',
      );
    }

    if (review.jobId.trim().isEmpty) {
      throw StateError(
        'A valid ARM job ID is required.',
      );
    }

    if (reviewerProfileId.trim().isEmpty) {
      throw StateError(
        'A reviewer profile ID is required.',
      );
    }

    if (approvalNonce.trim().isEmpty) {
      throw StateError(
        'An approval nonce is required.',
      );
    }

    return ApprovalDecision(
      jobId: review.jobId,
      selectedMetadataId: selected.id,
      selectedProvider: selected.provider,
      verificationScore: review.verification.score,
      verificationPassed: review.verification.passed,
      reviewerProfileId: reviewerProfileId,
      approvedAt: DateTime.now().toUtc(),
      approvalNonce: approvalNonce,
    );
  }
}