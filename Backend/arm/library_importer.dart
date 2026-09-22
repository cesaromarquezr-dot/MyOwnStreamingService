// FILE: `Backend/arm/library_importer.dart`.
//
// Purpose:
// Provides the controlled boundary through which an approved ARM import can
// become a library item.
//
// STATUS:
// MOCK / UNVERIFIED.
//
// IMPORTANT:
// This is intentionally the ONLY proposed writer for the ARM review flow.
// It does not write directly to Supabase or the Flutter application's local
// state. A project-specific writer is injected after the existing library
// APIs have been reviewed.
//
// Security:
// A caller cannot bypass review by supplying a simple `approved = true`
// boolean. A complete ApprovalDecision is mandatory.
//
// Physical-media model:
//
//   Physical Release
//       -> Physical Disc
//           -> Disc Content
//
// Music model:
//
//   Music Release
//       -> Music Medium
//           -> Music Track
//               -> Canonical Music Recording
//
// The importer validates these relationships when they are present, but the
// actual persistence/matching operation remains the responsibility of the
// injected LibraryWriter.

import 'arm_models.dart';
import 'import_review_model.dart';
import 'metadata_service.dart';

/// Data handed to the final project-specific library writer.
class LibraryImportRequest {
  final ApprovalDecision approval;
  final ImportReviewSnapshot review;

  const LibraryImportRequest({
    required this.approval,
    required this.review,
  });

  /// The canonical title that should be used by the library writer when one
  /// has already been resolved.
  String get canonicalTitle =>
      review.canonicalTitle;

  /// The physical title reported by ARM.
  String get originalDiscTitle =>
      review.originalDiscTitle;

  /// Whether the imported content is bonus material.
  bool get isBonusContent =>
      review.isBonusContent;

  /// Whether the imported content is the primary content of its disc.
  bool get isPrimaryContent =>
      review.isPrimaryContent;

  /// Whether the imported content represents music.
  bool get isMusic =>
      review.isMusic;

  /// Physical release ID, when available.
  String? get physicalReleaseId =>
      approval.physicalReleaseId;

  /// Physical disc ID, when available.
  String? get physicalDiscId =>
      approval.physicalDiscId;

  /// Disc-content ID, when available.
  String? get discContentId =>
      approval.discContentId;

  /// Canonical recording ID, when the music identity layer has already
  /// matched the extracted recording.
  String? get canonicalRecordingId =>
      approval.canonicalRecordingId;
}

/// Function used to perform the project's actual library write.
typedef LibraryWriter = Future<String> Function(
  LibraryImportRequest request,
);

/// Sole import boundary for the ARM review workflow.
class LibraryImporter {
  final LibraryWriter writer;

  const LibraryImporter({
    required this.writer,
  });

  /// Imports an item only when the complete approval decision is valid.
  Future<String> import({
    required ImportReviewSnapshot review,
    required ApprovalDecision approval,
  }) async {
    _validateApproval(
      review: review,
      approval: approval,
    );

    final request = LibraryImportRequest(
      approval: approval,
      review: review,
    );

    return writer(request);
  }

  /// Performs all safety checks immediately before the library write.
  void _validateApproval({
    required ImportReviewSnapshot review,
    required ApprovalDecision approval,
  }) {
    _validateBasicApproval(
      review: review,
      approval: approval,
    );

    _validateMetadataSelection(
      review: review,
      approval: approval,
    );

    _validatePhysicalMedia(
      review: review,
      approval: approval,
    );

    _validateMusicIdentity(
      review: review,
      approval: approval,
    );
  }

  void _validateBasicApproval({
    required ImportReviewSnapshot review,
    required ApprovalDecision approval,
  }) {
    if (approval.jobId != review.jobId) {
      throw StateError(
        'Approval job does not match the reviewed ARM job.',
      );
    }

    if (!approval.verificationPassed ||
        !review.verification.passed) {
      throw StateError(
        'The rip must pass verification before library import.',
      );
    }

    if (approval.verificationScore !=
        review.verification.score) {
      throw StateError(
        'The approval verification score does not match the reviewed result.',
      );
    }

    if (approval.reviewerProfileId.trim().isEmpty) {
      throw StateError(
        'A reviewer profile is required.',
      );
    }

    if (approval.approvalNonce.trim().isEmpty) {
      throw StateError(
        'An approval nonce is required.',
      );
    }

    if (approval.approvedAt.isAfter(
      DateTime.now().toUtc(),
    )) {
      throw StateError(
        'Approval timestamp cannot be in the future.',
      );
    }
  }

  void _validateMetadataSelection({
    required ImportReviewSnapshot review,
    required ApprovalDecision approval,
  }) {
    final selected = review.selectedMatch;

    if (selected == null) {
      throw StateError(
        'No metadata match was selected.',
      );
    }

    if (approval.selectedMetadataId !=
        selected.id) {
      throw StateError(
        'The approved metadata does not match the reviewed selection.',
      );
    }

    if (approval.selectedMetadataId.trim().isEmpty) {
      throw StateError(
        'A selected metadata ID is required.',
      );
    }

    if (selected.provider !=
        approval.selectedProvider) {
      throw StateError(
        'The approved metadata provider does not match the reviewed selection.',
      );
    }

    if (selected.provider ==
        MetadataProvider.mock) {
      // This is deliberately allowed in the mock phase.
      //
      // Production implementation should reject mock provider IDs before
      // production library import.
    }
  }

  void _validatePhysicalMedia({
    required ImportReviewSnapshot review,
    required ApprovalDecision approval,
  }) {
    final release = review.physicalRelease;
    final disc = review.physicalDisc;
    final content = review.discContent;

    if (release == null &&
        disc == null &&
        content == null) {
      // Existing/non-physical imports remain compatible with the workflow.
      return;
    }

    if (release == null) {
      throw StateError(
        'A physical disc/content import requires a physical release.',
      );
    }

    if (release.id.trim().isEmpty) {
      throw StateError(
        'The physical release must have a valid ID.',
      );
    }

    if (approval.physicalReleaseId !=
        release.id) {
      throw StateError(
        'The approved physical release does not match the reviewed release.',
      );
    }

    if (disc == null) {
      throw StateError(
        'A physical release import requires a physical disc.',
      );
    }

    if (disc.id.trim().isEmpty) {
      throw StateError(
        'The physical disc must have a valid ID.',
      );
    }

    if (disc.releaseId != release.id) {
      throw StateError(
        'The physical disc does not belong to the reviewed physical release.',
      );
    }

    if (approval.physicalDiscId !=
        disc.id) {
      throw StateError(
        'The approved physical disc does not match the reviewed disc.',
      );
    }

    if (disc.discNumber <= 0) {
      throw StateError(
        'A physical disc must have a positive disc number.',
      );
    }

    if (content == null) {
      // A release/disc can be reviewed before ARM has assigned an individual
      // content record. The writer may create the content during persistence.
      return;
    }

    if (content.id.trim().isEmpty) {
      throw StateError(
        'The disc content must have a valid ID.',
      );
    }

    if (content.discId != disc.id) {
      throw StateError(
        'The reviewed disc content does not belong to the approved disc.',
      );
    }

    if (approval.discContentId !=
        content.id) {
      throw StateError(
        'The approved disc content does not match the reviewed content.',
      );
    }

    if (content.primary &&
        content.isBonus) {
      throw StateError(
        'A single disc content item cannot be both primary and bonus content.',
      );
    }

    if (approval.isBonusContent !=
        content.isBonus) {
      throw StateError(
        'The approval bonus-content state does not match the reviewed content.',
      );
    }
  }

  void _validateMusicIdentity({
    required ImportReviewSnapshot review,
    required ApprovalDecision approval,
  }) {
    if (!review.isMusic) {
      if (approval.canonicalRecordingId != null) {
        throw StateError(
          'A non-music import cannot reference a canonical music recording.',
        );
      }

      return;
    }

    final candidate =
        review.recordingCandidate;

    if (candidate == null) {
      // A music extraction may still be imported before the canonical
      // recording matcher has resolved it. The persistence layer can create
      // or reconcile the recording later.
      return;
    }

    if (candidate.title.trim().isEmpty) {
      throw StateError(
        'A music recording candidate requires a title.',
      );
    }

    if (approval.canonicalRecordingId != null &&
        approval.canonicalRecordingId!.trim().isEmpty) {
      throw StateError(
        'A canonical recording ID cannot be empty.',
      );
    }

    if (approval.canonicalRecordingId != null) {
      // The ID is validated as an approval reference here. The writer remains
      // responsible for confirming that the referenced canonical recording
      // actually exists and that the candidate matches it.
      return;
    }

    // No canonical ID means the recording still needs identity resolution.
    // This is allowed because import order must not determine whether a song
    // becomes a duplicate recording.
  }
}