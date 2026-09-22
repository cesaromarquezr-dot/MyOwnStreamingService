// FILE: Backend/services/transcoding_scheduler_service.dart.
// Purpose: Schedules independent playback transcodes so multiple household
// streams can run concurrently without allowing unlimited work to overwhelm
// a server.
//
// The scheduler controls concurrency only. It does not start processes,
// perform transcoding, or cancel an already-running transcoder unless the
// supplied task itself supports cancellation.
//
// Jobs are executed FIFO.

import 'dart:async';
import 'dart:collection';

class TranscodingSchedulerService {
  static const int defaultMaxConcurrentJobs = 2;
  static const int defaultMaxQueuedJobs = 100;

  final int maxConcurrentJobs;
  final int maxQueuedJobs;

  int _running = 0;
  int _nextJobNumber = 0;
  bool _closed = false;

  final Queue<_QueuedJob<dynamic>> _queue =
      Queue<_QueuedJob<dynamic>>();

  /// Creates a scheduler with a bounded number of simultaneous jobs.
  ///
  /// [maxQueuedJobs] limits waiting work. Running jobs are not included in
  /// that limit.
  TranscodingSchedulerService({
    this.maxConcurrentJobs = defaultMaxConcurrentJobs,
    this.maxQueuedJobs = defaultMaxQueuedJobs,
  })  : assert(maxConcurrentJobs > 0),
        assert(maxQueuedJobs >= 0);

  /// Number of jobs currently consuming a transcoding slot.
  int get runningJobs => _running;

  /// Number of jobs waiting for a transcoding slot.
  int get queuedJobs => _queue.length;

  /// Maximum number of jobs that can run concurrently.
  int get concurrencyLimit => maxConcurrentJobs;

  /// Whether the scheduler has been closed.
  bool get isClosed => _closed;

  /// Number of available execution slots.
  int get availableSlots {
    final available = maxConcurrentJobs - _running;
    return available < 0 ? 0 : available;
  }

  /// Schedules [task] for execution.
  ///
  /// The returned future completes with the task result.
  ///
  /// Throws [StateError] when the scheduler is closed or its waiting queue
  /// has reached [maxQueuedJobs].
  Future<T> schedule<T>(
    Future<T> Function() task, {
    String? label,
  }) {
    if (_closed) {
      return Future<T>.error(
        StateError('Transcoding scheduler is closed.'),
      );
    }

    if (_queue.length >= maxQueuedJobs &&
        _running >= maxConcurrentJobs) {
      return Future<T>.error(
        StateError(
          'Transcoding scheduler queue is full.',
        ),
      );
    }

    final normalizedLabel = _normalizeLabel(label);

    final completer = Completer<T>();

    final job = _QueuedJob<T>(
      id: _generateJobId(),
      task: task,
      completer: completer,
      label: normalizedLabel,
    );

    _queue.add(job);
    _drain();

    return completer.future;
  }

  /// Attempts to cancel a queued job.
  ///
  /// Returns true when the job was still waiting and was successfully
  /// removed. Returns false when it is already running, completed, or does
  /// not exist.
  bool cancel(String jobId) {
    if (_closed || jobId.trim().isEmpty) {
      return false;
    }

    _QueuedJob<dynamic>? found;

    for (final job in _queue) {
      if (job.id == jobId) {
        found = job;
        break;
      }
    }

    if (found == null) {
      return false;
    }

    _queue.remove(found);

    if (!found.completer.isCompleted) {
      found.completer.completeError(
        TranscodingJobCancelledException(
          'Transcoding job was cancelled before execution.',
        ),
      );
    }

    return true;
  }

  /// Cancels every queued job.
  ///
  /// Already-running tasks are allowed to finish because Dart futures cannot
  /// safely be forcefully terminated by this scheduler.
  int cancelQueued() {
    var cancelled = 0;

    while (_queue.isNotEmpty) {
      final job = _queue.removeFirst();

      if (!job.completer.isCompleted) {
        job.completer.completeError(
          TranscodingJobCancelledException(
            'Transcoding job was cancelled before execution.',
          ),
        );
        cancelled++;
      }
    }

    return cancelled;
  }

  /// Stops accepting new work and cancels jobs still waiting in the queue.
  ///
  /// Existing running jobs continue to completion.
  void close() {
    if (_closed) {
      return;
    }

    _closed = true;
    cancelQueued();
  }

  void _drain() {
    if (_closed) {
      return;
    }

    while (_running < maxConcurrentJobs && _queue.isNotEmpty) {
      final job = _queue.removeFirst();

      if (job.completer.isCompleted) {
        continue;
      }

      _running++;

      _execute(job);
    }
  }

  Future<void> _execute<T>(_QueuedJob<T> job) async {
    try {
      if (!job.completer.isCompleted) {
        final result = await job.task();

        if (!job.completer.isCompleted) {
          job.completer.complete(result);
        }
      }
    } catch (error, stackTrace) {
      if (!job.completer.isCompleted) {
        job.completer.completeError(
          error,
          stackTrace,
        );
      }
    } finally {
      _running--;

      // Always drain in a microtask so completion/error delivery and slot
      // accounting remain stable even when a task completes synchronously.
      scheduleMicrotask(_drain);
    }
  }

  String _generateJobId() {
    _nextJobNumber++;

    return 'transcode_job_'
        '${DateTime.now().toUtc().microsecondsSinceEpoch}_'
        '$_nextJobNumber';
  }

  String? _normalizeLabel(String? label) {
    if (label == null) {
      return null;
    }

    final normalized = label.trim();

    if (normalized.isEmpty) {
      return null;
    }

    if (normalized.length > 200) {
      throw ArgumentError(
        'Transcoding job label is too long.',
      );
    }

    if (normalized.contains(
      RegExp(r'[\x00-\x1F\x7F]'),
    )) {
      throw ArgumentError(
        'Transcoding job label contains control characters.',
      );
    }

    return normalized;
  }
}

/// Exception returned when a queued transcoding job is cancelled before it
/// starts.
class TranscodingJobCancelledException implements Exception {
  final String message;

  const TranscodingJobCancelledException(this.message);

  @override
  String toString() {
    return 'TranscodingJobCancelledException: $message';
  }
}

/// Internal queued task representation.
class _QueuedJob<T> {
  final String id;
  final Future<T> Function() task;
  final Completer<T> completer;
  final String? label;

  _QueuedJob({
    required this.id,
    required this.task,
    required this.completer,
    this.label,
  });
}