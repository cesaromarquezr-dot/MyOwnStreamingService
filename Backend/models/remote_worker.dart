class RemoteWorker {
  final String id;
  final String accountId;
  final String name;
  final String platform;
  final bool hasDiscReader;
  final bool supportsExternalReader;
  final DateTime createdAt;
  DateTime lastSeenAt;
  final String token;

  RemoteWorker({required this.id, required this.accountId, required this.name, required this.platform, required this.hasDiscReader, required this.supportsExternalReader, required this.createdAt, required this.lastSeenAt, required this.token});

  Map<String, dynamic> toJson({bool includeToken = false}) => {
    'id': id, 'name': name, 'platform': platform, 'hasDiscReader': hasDiscReader,
    'supportsExternalReader': supportsExternalReader, 'createdAt': createdAt.toIso8601String(),
    'lastSeenAt': lastSeenAt.toIso8601String(), if (includeToken) 'workerToken': token,
  };
}

class RemoteImportJob {
  final String id;
  final String accountId;
  final String workerId;
  final String driveName;
  String status;
  double progress;
  String? title;
  String? message;
  final DateTime createdAt;

  RemoteImportJob({required this.id, required this.accountId, required this.workerId, required this.driveName, this.status = 'queued', this.progress = 0, this.title, this.message, required this.createdAt});

  Map<String, dynamic> toJson() => {'id': id, 'workerId': workerId, 'driveName': driveName, 'status': status, 'progress': progress, 'title': title, 'message': message, 'createdAt': createdAt.toIso8601String()};
}
