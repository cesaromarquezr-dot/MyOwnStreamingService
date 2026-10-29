// Account-wide library publication scheduler.
// The media file is already on the account NAS; this controls publication only.

import 'dart:async';

import '../database/database.dart';
import '../models/library_addition.dart';

class LibraryReleaseService {
  final Database database;
  final Map<String, LibraryAddition> _items = <String, LibraryAddition>{};
  Timer? _timer;

  LibraryReleaseService({required this.database}) {
    _items.addAll(database.libraryAdditionsById);
    _scheduleNextPublication();
  }

  /// Sleeps until the next scheduled publication instead of waking the server
  /// every minute when no release is due. Scheduled publications remain
  /// persisted, so a restart rebuilds the timer from the database.
  void _scheduleNextPublication() {
    _timer?.cancel();
    _timer = null;

    DateTime? nextDue;
    for (final item in _items.values) {
      if (item.status != LibraryAdditionStatus.scheduled) continue;
      final due = item.scheduledFor.toUtc();
      if (nextDue == null || due.isBefore(nextDue)) nextDue = due;
    }
    if (nextDue == null) return;

    final delay = nextDue.difference(DateTime.now().toUtc());
    _timer = Timer(delay.isNegative ? Duration.zero : delay, () {
      _timer = null;
      unawaited(publishDue());
    });
  }

  void dispose() => _timer?.cancel();

  LibraryAddition schedule({
    required String accountId,
    required String mediaId,
    required String title,
    required String mediaType,
    required DateTime scheduledFor,
    required String timeZone,
  }) {
    final when = scheduledFor.toUtc();
    if (!when.isAfter(DateTime.now().toUtc())) {
      throw ArgumentError('A scheduled release must be in the future.');
    }
    final item = LibraryAddition(
      id: 'release_${DateTime.now().microsecondsSinceEpoch}',
      accountId: accountId,
      mediaId: mediaId,
      title: title,
      mediaType: mediaType,
      scheduledFor: when,
      timeZone: timeZone.trim().isEmpty ? 'UTC' : timeZone.trim(),
    );
    _items[item.id] = item;
    database.saveLibraryAddition(item);
    _scheduleNextPublication();
    return item;
  }

  LibraryAddition? get(String id) => _items[id.trim()];

  List<LibraryAddition> forAccount(String accountId) => _items.values
      .where((item) =>
          item.accountId == accountId &&
          item.status == LibraryAdditionStatus.scheduled)
      .toList()
    ..sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));

  LibraryAddition publishNow(String id, {required String accountId}) {
    final item = _items[id.trim()];
    if (item == null || item.accountId != accountId) {
      throw StateError('Scheduled library addition not found.');
    }
    if (item.status == LibraryAdditionStatus.cancelled) {
      throw StateError('The scheduled addition was cancelled.');
    }
    item.status = LibraryAdditionStatus.published;
    item.publishedAt = DateTime.now().toUtc();
    database.saveLibraryAddition(item);
    _scheduleNextPublication();
    return item;
  }

  LibraryAddition cancel(String id, {required String accountId}) {
    final item = _items[id.trim()];
    if (item == null || item.accountId != accountId) {
      throw StateError('Scheduled library addition not found.');
    }
    if (item.status == LibraryAdditionStatus.published) {
      throw StateError('A published library addition cannot be cancelled.');
    }
    item.status = LibraryAdditionStatus.cancelled;
    item.cancelledAt = DateTime.now().toUtc();
    database.saveLibraryAddition(item);
    _scheduleNextPublication();
    return item;
  }

  Future<void> publishDue() async {
    final now = DateTime.now().toUtc();
    for (final item in _items.values) {
      if (item.status == LibraryAdditionStatus.scheduled &&
          !item.scheduledFor.isAfter(now)) {
        item.status = LibraryAdditionStatus.published;
        item.publishedAt = now;
        database.saveLibraryAddition(item);
      }
    }
    _scheduleNextPublication();
  }
}
