// FILE: Backend/services/transcoding_scheduler_service.dart.
// Purpose: Schedules independent playback transcodes so multiple household
// streams can run concurrently without allowing unlimited work to overwhelm a server.

import 'dart:async';

/// A small fair scheduler for independent transcoding/playback preparation jobs.
class TranscodingSchedulerService {
  final int maxConcurrentJobs;
  int _running = 0;
  final List<_QueuedJob<dynamic>> _queue = <_QueuedJob<dynamic>>[];

  /// Creates a scheduler with a bounded number of simultaneous jobs.
  TranscodingSchedulerService({this.maxConcurrentJobs = 2})
      : assert(maxConcurrentJobs > 0);

  /// Number of jobs currently consuming a transcoding slot.
  int get runningJobs => _running;

  /// Number of jobs waiting for a transcoding slot.
  int get queuedJobs => _queue.length;

  /// Runs [task] when a transcoding slot becomes available.
  Future<T> schedule<T>(Future<T> Function() task) {
    final completer = Completer<T>();
    _queue.add(_QueuedJob<T>(task, completer));
    _drain();
    return completer.future;
  }

  void _drain() {
    while (_running < maxConcurrentJobs && _queue.isNotEmpty) {
      final job = _queue.removeAt(0);
      _running++;
      () async {
        try {
          job.completer.complete(await job.task());
        } catch (error, stack) {
          job.completer.completeError(error, stack);
        } finally {
          _running--;
          _drain();
        }
      }();
    }
  }
}

/// Internal queued task representation used by [TranscodingSchedulerService].
class _QueuedJob<T> {
  final Future<T> Function() task;
  final Completer<T> completer;

  _QueuedJob(this.task, this.completer);
}
