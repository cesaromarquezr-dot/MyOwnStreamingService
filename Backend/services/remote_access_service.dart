// FILE: `Backend/services/remote_access_service.dart`.
// Purpose: Implements the remote access service portion of the streaming
// service.
// This file is part of the documented Flutter/home-server architecture.
//
// Security responsibilities:
// - Generates cryptographically secure one-time codes and worker tokens.
// - Keeps worker access scoped to the owning account.
// - Consumes registration codes after successful use.
// - Rejects expired registration codes.
// - Prevents arbitrary accounts from queueing jobs on another account's
//   worker.
// - Keeps remote worker tokens out of normal response/logging paths unless
//   the caller explicitly needs the registration result.

import 'dart:convert';
import 'dart:math';

import '../database/database.dart';
import '../models/account.dart';
import '../models/remote_worker.dart';

class RemoteAccessService {
  final Database database;
  final Random _random = Random.secure();

  RemoteAccessService(this.database);

  static const Duration oneTimeCodeLifetime = Duration(minutes: 10);

  static const int maximumNameLength = 200;
  static const int maximumPlatformLength = 100;
  static const int maximumDriveNameLength = 200;
  static const int maximumTokenLength = 1024;

  String _id(String prefix) {
    final normalizedPrefix = _safePrefix(prefix);

    return '${normalizedPrefix}_'
        '${DateTime.now().microsecondsSinceEpoch}_'
        '${_random.nextInt(1 << 30).toRadixString(16)}_'
        '${_random.nextInt(1 << 30).toRadixString(16)}';
  }

  String _code() {
    return (100000 + _random.nextInt(900000)).toString();
  }

  String _token() {
    final randomBytes = List<int>.generate(
      48,
      (_) => _random.nextInt(256),
      growable: false,
    );

    final encoded = base64UrlEncode(randomBytes).replaceAll('=', '');

    return 'worker_${encoded}_${_random.nextInt(1 << 30).toRadixString(16)}';
  }

  /// Creates a short-lived code used to register a remote worker.
  ///
  /// Creating a new code invalidates the previous code for this account.
  String createOneTimeCode(Account account) {
    _requireAccount(account);

    final code = _code();
    final now = DateTime.now();

    database.oneTimeCodesByAccountId[account.id] = code;
    database.oneTimeCodeExpiryByAccountId[account.id] =
        now.add(oneTimeCodeLifetime);

    return code;
  }

  /// Registers a remote worker using an account-scoped one-time code.
  ///
  /// The code is consumed immediately after successful validation.
  RemoteWorker registerWorker({
    required Account account,
    required String code,
    required String name,
    required String platform,
    required bool hasDiscReader,
    required bool supportsExternalReader,
  }) {
    _requireAccount(account);

    final normalizedCode = code.trim();

    if (!_isValidOneTimeCode(normalizedCode)) {
      throw Exception('Invalid or expired one-time access code.');
    }

    final expected = database.oneTimeCodesByAccountId[account.id];
    final expiry = database.oneTimeCodeExpiryByAccountId[account.id];

    if (expected == null || expiry == null) {
      throw Exception('Invalid or expired one-time access code.');
    }

    final now = DateTime.now();

    if (!now.isBefore(expiry)) {
      _consumeOneTimeCode(account.id);
      throw Exception('Invalid or expired one-time access code.');
    }

    if (!_constantTimeEquals(expected, normalizedCode)) {
      throw Exception('Invalid or expired one-time access code.');
    }

    final normalizedName = _boundedText(
      name,
      maximumNameLength,
      fallback: 'Remote computer',
    );

    final normalizedPlatform = _boundedText(
      platform,
      maximumPlatformLength,
      fallback: 'unknown',
    );

    // Consume the code before creating the worker. The registration code
    // must never remain reusable after successful authentication.
    _consumeOneTimeCode(account.id);

    final createdAt = DateTime.now();

    final worker = RemoteWorker(
      id: _id('worker'),
      accountId: account.id,
      name: normalizedName,
      platform: normalizedPlatform,
      hasDiscReader: hasDiscReader,
      supportsExternalReader: supportsExternalReader,
      createdAt: createdAt,
      lastSeenAt: createdAt,
      token: _token(),
    );

    database.remoteWorkersById[worker.id] = worker;

    return worker;
  }

  /// Returns workers belonging to the supplied account only.
  List<RemoteWorker> workersFor(Account account) {
    _requireAccount(account);

    final workers = database.remoteWorkersById.values
        .where((worker) => worker.accountId == account.id)
        .toList();

    workers.sort(
      (a, b) => b.lastSeenAt.compareTo(a.lastSeenAt),
    );

    return workers;
  }

  /// Resolves a worker authentication token.
  ///
  /// The route layer must still associate the resulting worker with the
  /// authenticated account where applicable.
  RemoteWorker workerForToken(String token) {
    final normalizedToken = token.trim();

    if (!_isPlausibleWorkerToken(normalizedToken)) {
      throw Exception('Remote worker not found.');
    }

    for (final worker in database.remoteWorkersById.values) {
      if (_constantTimeEquals(worker.token, normalizedToken)) {
        return worker;
      }
    }

    throw Exception('Remote worker not found.');
  }

  /// Queues a disc import for an account-owned remote worker.
  RemoteImportJob queueImport({
    required Account account,
    required String workerId,
    required String driveName,
  }) {
    _requireAccount(account);

    final normalizedWorkerId = workerId.trim();

    if (normalizedWorkerId.isEmpty) {
      throw Exception('Remote worker ID is required.');
    }

    if (normalizedWorkerId.length > 200) {
      throw Exception('Remote worker ID is too long.');
    }

    final worker = database.remoteWorkersById[normalizedWorkerId];

    if (worker == null || worker.accountId != account.id) {
      throw Exception('Remote worker not found.');
    }

    if (!worker.hasDiscReader && !worker.supportsExternalReader) {
      throw Exception(
        'This computer has no supported disc reader. '
        'Connect an internal or external universal disc reader first.',
      );
    }

    final normalizedDriveName = _boundedText(
      driveName,
      maximumDriveNameLength,
      fallback: 'Disc reader',
    );

    final job = RemoteImportJob(
      id: _id('remote_rip'),
      accountId: account.id,
      workerId: worker.id,
      driveName: normalizedDriveName,
      createdAt: DateTime.now(),
      message: 'Queued for the remote computer.',
    );

    database.remoteImportJobsById[job.id] = job;

    return job;
  }

  /// Returns queued jobs belonging to the specified worker.
  ///
  /// The worker is already expected to have been authenticated by the route
  /// layer, but account ownership is also checked where an account is
  /// available through the worker record.
  List<RemoteImportJob> pendingForWorker(RemoteWorker worker) {
    final workerId = worker.id.trim();

    if (workerId.isEmpty) {
      return const <RemoteImportJob>[];
    }

    final jobs = database.remoteImportJobsById.values
        .where(
          (job) =>
              job.workerId == workerId &&
              job.accountId == worker.accountId &&
              job.status.trim().toLowerCase() == 'queued',
        )
        .toList();

    jobs.sort(
      (a, b) => a.createdAt.compareTo(b.createdAt),
    );

    return jobs;
  }

  /// Removes a worker owned by the supplied account.
  ///
  /// Associated queued jobs are removed as well so an old worker cannot
  /// continue receiving work after it has been revoked.
  bool removeWorker({
    required Account account,
    required String workerId,
  }) {
    _requireAccount(account);

    final normalizedWorkerId = workerId.trim();

    if (normalizedWorkerId.isEmpty) {
      return false;
    }

    final worker = database.remoteWorkersById[normalizedWorkerId];

    if (worker == null || worker.accountId != account.id) {
      return false;
    }

    database.remoteWorkersById.remove(normalizedWorkerId);

    final jobIds = database.remoteImportJobsById.values
        .where((job) => job.workerId == normalizedWorkerId)
        .map((job) => job.id)
        .toList(growable: false);

    for (final jobId in jobIds) {
      database.remoteImportJobsById.remove(jobId);
    }

    return true;
  }

  /// Removes expired registration credentials for an account.
  bool clearExpiredOneTimeCode(Account account) {
    _requireAccount(account);

    final expiry = database.oneTimeCodeExpiryByAccountId[account.id];

    if (expiry == null) {
      return false;
    }

    if (DateTime.now().isBefore(expiry)) {
      return false;
    }

    _consumeOneTimeCode(account.id);
    return true;
  }

  void _consumeOneTimeCode(String accountId) {
    database.oneTimeCodesByAccountId.remove(accountId);
    database.oneTimeCodeExpiryByAccountId.remove(accountId);
  }

  void _requireAccount(Account account) {
    if (account.id.trim().isEmpty) {
      throw Exception('Account ID is required.');
    }
  }

  String _boundedText(
    String value,
    int maximum, {
    required String fallback,
  }) {
    final normalized = value.trim();

    if (normalized.isEmpty) {
      return fallback;
    }

    if (normalized.length > maximum) {
      throw Exception('Input exceeds the maximum allowed length.');
    }

    if (_containsControlCharacter(normalized)) {
      throw Exception('Input contains unsupported control characters.');
    }

    return normalized;
  }

  bool _isValidOneTimeCode(String code) {
    if (code.length != 6) {
      return false;
    }

    return RegExp(r'^[0-9]{6}$').hasMatch(code);
  }

  bool _isPlausibleWorkerToken(String token) {
    if (token.isEmpty || token.length > maximumTokenLength) {
      return false;
    }

    if (!token.startsWith('worker_')) {
      return false;
    }

    return !_containsControlCharacter(token);
  }

  bool _containsControlCharacter(String value) {
    for (final codeUnit in value.codeUnits) {
      if (codeUnit < 0x20 || codeUnit == 0x7F) {
        return true;
      }
    }

    return false;
  }

  bool _constantTimeEquals(String first, String second) {
    final firstBytes = utf8.encode(first);
    final secondBytes = utf8.encode(second);

    var difference = firstBytes.length ^ secondBytes.length;
    final length = firstBytes.length < secondBytes.length
        ? firstBytes.length
        : secondBytes.length;

    for (var i = 0; i < length; i++) {
      difference |= firstBytes[i] ^ secondBytes[i];
    }

    return difference == 0;
  }

  String _safePrefix(String prefix) {
    final normalized = prefix
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

    return normalized.isEmpty ? 'remote' : normalized;
  }
}