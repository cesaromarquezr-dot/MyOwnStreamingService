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

    return writer(
      LibraryImportRequest(
        approval: approval,
        review: review,
      ),
    );
  }

  /// Performs all safety checks immediately before the library write.
  void _validateApproval({
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

    final selected = review.selectedMatch;

    if (selected == null) {
      throw StateError(
        'No metadata match was selected.',
      );
    }

    if (approval.selectedMetadataId != selected.id) {
      throw StateError(
        'The approved metadata does not match the reviewed selection.',
      );
    }

    if (approval.selectedMetadataId.trim().isEmpty) {
      throw StateError(
        'A selected metadata ID is required.',
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

    if (approval.approvedAt.isAfter(DateTime.now().toUtc())) {
      throw StateError(
        'Approval timestamp cannot be in the future.',
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
}