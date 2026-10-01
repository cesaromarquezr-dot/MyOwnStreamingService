enum ServerAgentStatus {
  offline,
  online,
  degraded,
  updating,
}

enum StorageStatus {
  offline,
  available,
  receiving,
  migrating,
  degraded,
}

class ServerAgentSnapshot {
  final String serverId;
  final String accountId;
  final String agentId;
  final ServerAgentStatus status;
  final StorageStatus storageStatus;
  final String? nasName;
  final int totalBytes;
  final int freeBytes;
  final String? currentJobId;
  final DateTime? lastHeartbeatAt;

  const ServerAgentSnapshot({
    required this.serverId,
    this.accountId = '',
    required this.agentId,
    required this.status,
    required this.storageStatus,
    this.nasName,
    this.totalBytes = 0,
    this.freeBytes = 0,
    this.currentJobId,
    this.lastHeartbeatAt,
  });

  factory ServerAgentSnapshot.fromJson(Map<String, dynamic> json) {
    ServerAgentStatus parseAgent(dynamic value) => ServerAgentStatus.values.firstWhere(
          (item) => item.name == value?.toString(),
          orElse: () => ServerAgentStatus.offline,
        );
    StorageStatus parseStorage(dynamic value) => StorageStatus.values.firstWhere(
          (item) => item.name == value?.toString(),
          orElse: () => StorageStatus.offline,
        );

    return ServerAgentSnapshot(
      serverId: json['serverId']?.toString() ?? json['server_id']?.toString() ?? '',
      agentId: json['agentId']?.toString() ?? json['agent_id']?.toString() ?? '',
      status: parseAgent(json['status']),
      storageStatus: parseStorage(json['storageStatus'] ?? json['storage_status']),
      nasName: json['nasName']?.toString() ?? json['nas_name']?.toString(),
      totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
      freeBytes: (json['freeBytes'] as num?)?.toInt() ?? 0,
      currentJobId: json['currentJobId']?.toString() ?? json['current_job_id']?.toString(),
      lastHeartbeatAt: DateTime.tryParse(
        json['lastHeartbeatAt']?.toString() ?? json['last_heartbeat_at']?.toString() ?? '',
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'serverId': serverId,
        'accountId': accountId,
        'agentId': agentId,
        'status': status.name,
        'storageStatus': storageStatus.name,
        if (nasName != null) 'nasName': nasName,
        'totalBytes': totalBytes,
        'freeBytes': freeBytes,
        if (currentJobId != null) 'currentJobId': currentJobId,
        if (lastHeartbeatAt != null) 'lastHeartbeatAt': lastHeartbeatAt!.toIso8601String(),
      };
}
