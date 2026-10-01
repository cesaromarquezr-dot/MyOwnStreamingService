import '../models/import_job.dart';

/// Shared job registry for long-running platform operations.
///
/// Jobs are intentionally separate from HTTP requests so Flutter can poll or
/// subscribe to progress without holding a request open for ripping, copying,
/// verification, or migration.
class JobService {
  final Map<String, ImportJob> _jobs = <String, ImportJob>{};

  ImportJob? get(String id) => _jobs[id.trim()];

  List<ImportJob> forAccount(String accountId) => List<ImportJob>.unmodifiable(
        _jobs.values.where((job) => job.accountId == accountId),
      );

  void save(ImportJob job) {
    job.progress = job.progress.clamp(0, 1).toDouble();
    job.updatedAt = DateTime.now().toUtc();
    _jobs[job.id] = job;
  }

  void update(
    String id, {
    ImportState? state,
    double? progress,
    int? verifiedItems,
    int? totalItems,
    String? error,
  }) {
    final job = _jobs[id.trim()];
    if (job == null) return;
    if (state != null) job.state = state;
    if (progress != null) job.progress = progress.clamp(0, 1).toDouble();
    if (verifiedItems != null) job.verifiedItems = verifiedItems;
    if (totalItems != null) job.totalItems = totalItems;
    if (error != null) job.error = error;
    job.updatedAt = DateTime.now().toUtc();
  }
}
