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
// reviewer information, and the physical-media context that produced the
// decision.
//
// Physical-media model:
//
//   Physical Release
//       -> Physical Disc
//           -> Disc Content
//
// A review therefore identifies the content being approved while preserving
// the physical release/disc provenance. A bonus disc is not automatically
// treated as another movie, and a soundtrack track is not automatically
// treated as a new canonical recording.

import 'arm_models.dart';
import 'metadata_service.dart';

/// Immutable snapshot shown to the user during import review.
///
/// The snapshot represents one reviewable content item. The optional physical
/// release/disc fields allow the same workflow to review content from a
/// multi-disc physical release without losing disc provenance.
class ImportReviewSnapshot {
  final String jobId;

  /// The ARM-interpreted title/content item being reviewed.
  final ArmDiscTitle discTitle;

  /// Metadata search results associated with the content.
  final MetadataSearchResult metadata;

  /// Structural verification performed against the extracted content.
  final ArmVerificationResult verification;

  /// Metadata candidate explicitly selected by the reviewer.
  final MetadataCandidate? selectedMatch;

  /// Physical release containing this content, when known.
  final ArmPhysicalRelease? physicalRelease;

  /// Physical disc containing this content, when known.
  final ArmPhysicalDisc? physicalDisc;

  /// The exact disc-content record being reviewed, when known.
  final ArmDiscContent? discContent;

  /// Canonical recording candidate when the content is music.
  ///
  /// This does not mean the recording has already been created or merged.
  /// The persistence/identity layer is responsible for matching it against
  /// existing recordings using identifiers and/or fingerprints.
  final ArmMusicRecording? recordingCandidate;

  final DateTime createdAt;

  const ImportReviewSnapshot({
    required this.jobId,
    required this.discTitle,
    required this.metadata,
    required this.verification,
    this.selectedMatch,
    this.physicalRelease,
    this.physicalDisc,
    this.discContent,
    this.recordingCandidate,
    required this.createdAt,
  });

  /// Returns the original physical-disc title exactly as reported by ARM
  /// whenever ARM supplied one.
  String get originalDiscTitle =>
      discTitle.discTitle ?? discTitle.title;

  /// Returns the canonical title when one has already been resolved.
  ///
  /// This is deliberately separate from [originalDiscTitle].
  String get canonicalTitle {
    final canonical = discTitle.canonicalTitle?.trim();

    if (canonical != null &&
        canonical.isNotEmpty) {
      return canonical;
    }

    return discTitle.title;
  }

  /// Whether this review represents bonus material rather than the primary
  /// content of the disc.
  bool get isBonusContent =>
      discContent?.isBonus ??
      _inferBonusFromTitle(discTitle);

  /// Whether the reviewed content is the primary content of its disc.
  bool get isPrimaryContent =>
      discContent?.primary ??
      !_inferBonusFromTitle(discTitle);

  /// Whether the reviewed content is music.
  bool get isMusic =>
      discTitle.isMusic ||
      discContent?.contentType ==
          ArmDiscContentType.music;

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
      physicalRelease: physicalRelease,
      physicalDisc: physicalDisc,
      discContent: discContent,
      recordingCandidate: recordingCandidate,
      createdAt: createdAt,
    );
  }

  /// Creates a copy with physical-release context attached.
  ImportReviewSnapshot withPhysicalMedia({
    ArmPhysicalRelease? release,
    ArmPhysicalDisc? disc,
    ArmDiscContent? content,
  }) {
    return ImportReviewSnapshot(
      jobId: jobId,
      discTitle: discTitle,
      metadata: metadata,
      verification: verification,
      selectedMatch: selectedMatch,
      physicalRelease: release ?? physicalRelease,
      physicalDisc: disc ?? physicalDisc,
      discContent: content ?? discContent,
      recordingCandidate: recordingCandidate,
      createdAt: createdAt,
    );
  }

  /// Creates a copy with a canonical music-recording candidate attached.
  ///
  /// The candidate is provenance information for the review. It is not itself
  /// a database identity and must still be matched against existing
  /// recordings before persistence.
  ImportReviewSnapshot withRecordingCandidate(
    ArmMusicRecording candidate,
  ) {
    return ImportReviewSnapshot(
      jobId: jobId,
      discTitle: discTitle,
      metadata: metadata,
      verification: verification,
      selectedMatch: selectedMatch,
      physicalRelease: physicalRelease,
      physicalDisc: physicalDisc,
      discContent: discContent,
      recordingCandidate: candidate,
      createdAt: createdAt,
    );
  }

  /// Indicates whether the snapshot contains enough information to request
  /// approval.
  ///
  /// This does not itself approve the import.
  bool get canRequestApproval =>
      verification.passed &&
      selectedMatch != null &&
      selectedMatch!.id.trim().isNotEmpty &&
      jobId.trim().isNotEmpty;

  bool _inferBonusFromTitle(
    ArmDiscTitle title,
  ) {
    final classification =
        title.classification.trim().toLowerCase();

    if (classification.contains('bonus') ||
        classification.contains('extra') ||
        classification.contains('deleted') ||
        classification.contains('trailer') ||
        classification.contains('behind') ||
        classification.contains('featurette') ||
        classification.contains('interview') ||
        classification.contains('commentary')) {
      return true;
    }

    return false;
  }
}

/// Explicit approval record required by LibraryImporter.
///
/// The approval identifies the exact ARM job and selected metadata that the
/// reviewer authorized. Physical-media identifiers are retained when the
/// review supplied them so downstream import code can preserve provenance.
class ApprovalDecision {
  final String jobId;
  final String selectedMetadataId;
  final MetadataProvider selectedProvider;

  final double verificationScore;
  final bool verificationPassed;

  final String reviewerProfileId;
  final DateTime approvedAt;
  final String approvalNonce;

  /// Physical release identifier, when the approved content came from a known
  /// physical release.
  final String? physicalReleaseId;

  /// Physical disc identifier, when the approved content came from a known
  /// physical disc.
  final String? physicalDiscId;

  /// Disc-content identifier, when the approved item has already been mapped
  /// to a specific content record.
  final String? discContentId;

  /// Canonical music-recording identifier, if the review was already matched
  /// to an existing recording.
  ///
  /// This is intentionally optional. A recording candidate may exist without
  /// having been resolved to an existing canonical recording yet.
  final String? canonicalRecordingId;

  /// Indicates whether the approved item is bonus material.
  final bool isBonusContent;

  const ApprovalDecision({
    required this.jobId,
    required this.selectedMetadataId,
    required this.selectedProvider,
    required this.verificationScore,
    required this.verificationPassed,
    required this.reviewerProfileId,
    required this.approvedAt,
    required this.approvalNonce,
    this.physicalReleaseId,
    this.physicalDiscId,
    this.discContentId,
    this.canonicalRecordingId,
    this.isBonusContent = false,
  });

  /// Creates an approval decision only after validating the review snapshot.
  factory ApprovalDecision.fromReview({
    required ImportReviewSnapshot review,
    required String reviewerProfileId,
    required String approvalNonce,
    String? canonicalRecordingId,
  }) {
    final selected = review.selectedMatch;

    if (!review.verification.passed) {
      throw StateError(
        'A failed verification cannot be approved.',
      );
    }

    if (selected == null ||
        selected.id.trim().isEmpty) {
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

    if (review.isMusic &&
        review.recordingCandidate != null &&
        canonicalRecordingId != null &&
        canonicalRecordingId.trim().isEmpty) {
      throw StateError(
        'A canonical recording ID cannot be empty when supplied.',
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
      physicalReleaseId: review.physicalRelease?.id,
      physicalDiscId: review.physicalDisc?.id,
      discContentId: review.discContent?.id,
      canonicalRecordingId:
          canonicalRecordingId?.trim().isEmpty == true
              ? null
              : canonicalRecordingId?.trim(),
      isBonusContent: review.isBonusContent,
    );
  }

  /// Returns a serializable audit representation of the approval.
  ///
  /// The approval nonce is deliberately not exposed here. Callers should
  /// never unnecessarily persist or return the nonce as ordinary API data.
  Map<String, dynamic> toJson() {
    return {
      'jobId': jobId,
      'selectedMetadataId': selectedMetadataId,
      'selectedProvider': selectedProvider.name,
      'verificationScore': verificationScore,
      'verificationPassed': verificationPassed,
      'reviewerProfileId': reviewerProfileId,
      'approvedAt': approvedAt.toUtc().toIso8601String(),
      'physicalReleaseId': physicalReleaseId,
      'physicalDiscId': physicalDiscId,
      'discContentId': discContentId,
      'canonicalRecordingId': canonicalRecordingId,
      'isBonusContent': isBonusContent,
    };
  }
}