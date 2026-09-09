import 'dart:math';
import '../database/database.dart';
import '../models/account.dart';
import '../models/remote_worker.dart';

class RemoteAccessService {
  final Database database;
  final Random _random = Random.secure();
  RemoteAccessService(this.database);

  String _id(String prefix) => '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(1000000)}';
  String _code() => (100000 + _random.nextInt(900000)).toString();
  String _token() => 'worker_${_id('token')}_${_random.nextInt(1 << 30)}';

  String createOneTimeCode(Account account) {
    final code = _code();
    database.oneTimeCodesByAccountId[account.id] = code;
    database.oneTimeCodeExpiryByAccountId[account.id] = DateTime.now().add(const Duration(minutes: 10));
    return code;
  }

  RemoteWorker registerWorker({required Account account, required String code, required String name, required String platform, required bool hasDiscReader, required bool supportsExternalReader}) {
    final expected = database.oneTimeCodesByAccountId[account.id];
    final expiry = database.oneTimeCodeExpiryByAccountId[account.id];
    if (expected == null || expected != code.trim() || expiry == null || DateTime.now().isAfter(expiry)) throw Exception('Invalid or expired one-time access code.');
    database.oneTimeCodesByAccountId.remove(account.id); database.oneTimeCodeExpiryByAccountId.remove(account.id);
    final worker = RemoteWorker(id: _id('worker'), accountId: account.id, name: name.trim().isEmpty ? 'Remote computer' : name.trim(), platform: platform, hasDiscReader: hasDiscReader, supportsExternalReader: supportsExternalReader, createdAt: DateTime.now(), lastSeenAt: DateTime.now(), token: _token());
    database.remoteWorkersById[worker.id] = worker;
    return worker;
  }

  List<RemoteWorker> workersFor(Account account) => database.remoteWorkersById.values.where((w) => w.accountId == account.id).toList();

  RemoteWorker workerForToken(String token) => database.remoteWorkersById.values.firstWhere((w) => w.token == token, orElse: () => throw Exception('Remote worker not found.'));

  RemoteImportJob queueImport({required Account account, required String workerId, required String driveName}) {
    final worker = database.remoteWorkersById[workerId]; if (worker == null || worker.accountId != account.id) throw Exception('Remote worker not found.');
    if (!worker.hasDiscReader && !worker.supportsExternalReader) throw Exception('This computer has no supported disc reader. Connect an internal or external universal disc reader first.');
    final job = RemoteImportJob(id: _id('remote_rip'), accountId: account.id, workerId: workerId, driveName: driveName.trim().isEmpty ? 'Disc reader' : driveName.trim(), createdAt: DateTime.now(), message: 'Queued for the remote computer.');
    database.remoteImportJobsById[job.id] = job; return job;
  }

  List<RemoteImportJob> pendingForWorker(RemoteWorker worker) => database.remoteImportJobsById.values.where((j) => j.workerId == worker.id && j.status == 'queued').toList();
}