// FILE: `lib/arm_importer.dart`.
// Purpose: Enforces the explicit ARM review/approval gate before library data
// is written by the Flutter application.

/// Captures the user's explicit approval of a reviewed ARM rip.
class ApprovalDecision {
  final String jobId;
  final String? selectedMetadataId;
  final String? reviewerProfileId;

  const ApprovalDecision({
    required this.jobId,
    this.selectedMetadataId,
    this.reviewerProfileId,
  });

  /// Validates the approval record before any library write is allowed.
  void validate({required bool verificationPassed}) {
    if (jobId.trim().isEmpty) {
      throw StateError('An ARM job ID is required for approval.');
    }
    if (!verificationPassed) {
      throw StateError('The ARM verification did not pass. The media cannot be imported.');
    }
  }
}

/// Sole application-side gate used by the ARM workflow before a library write.
class LibraryImporter {
  const LibraryImporter();

  /// Validates explicit approval and only then executes the supplied library
  /// writer. The writer is injected so this class does not invent or duplicate
  /// the application's existing library storage API.
  Future<void> import({
    required ApprovalDecision decision,
    required bool verificationPassed,
    required Future<void> Function() writer,
  }) async {
    decision.validate(verificationPassed: verificationPassed);
    await writer();
  }
}
