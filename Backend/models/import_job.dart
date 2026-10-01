enum ImportKind { movie, tv, music }
enum ImportState {
  detecting,
  ripping,
  staging,
  analyzing,
  verifying,
  matching,
  review,
  approved,
  transferring,
  completed,
  failed,
  cancelled,
}

class ImportJob {
  final String id;
  final String accountId;
  final ImportKind kind;
  ImportState state;
  double progress;
  String? title;
  String? driveId;
  String? serverId;
  int verifiedItems;
  int totalItems;
  String? error;
  final DateTime createdAt;
  DateTime updatedAt;

  ImportJob({
    required this.id,
    required this.accountId,
    required this.kind,
    required this.state,
    this.progress = 0,
    this.title,
    this.driveId,
    this.serverId,
    this.verifiedItems = 0,
    this.totalItems = 0,
    this.error,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = (createdAt ?? DateTime.now()).toUtc(),
        updatedAt = (updatedAt ?? DateTime.now()).toUtc();

  Map<String, dynamic> toJson() => {
        'id': id,
        'accountId': accountId,
        'kind': kind.name,
        'state': state.name,
        'progress': progress,
        if (title != null) 'title': title,
        if (driveId != null) 'driveId': driveId,
        if (serverId != null) 'serverId': serverId,
        'verifiedItems': verifiedItems,
        'totalItems': totalItems,
        if (error != null) 'error': error,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}
