enum ServerAgentStatus { offline, online, degraded, updating }
enum StorageStatus { offline, available, receiving, migrating, degraded }

class MediaServerAgentSnapshot {
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

  const MediaServerAgentSnapshot({
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
        if (lastHeartbeatAt != null) 'lastHeartbeatAt': lastHeartbeatAt!.toUtc().toIso8601String(),
      };

  factory MediaServerAgentSnapshot.fromJson(Map<String, dynamic> json) => MediaServerAgentSnapshot(
        serverId: json['serverId']?.toString() ?? json['server_id']?.toString() ?? '',
        accountId: json['accountId']?.toString() ?? json['account_id']?.toString() ?? '',
        agentId: json['agentId']?.toString() ?? json['agent_id']?.toString() ?? '',
        status: ServerAgentStatus.values.firstWhere(
          (value) => value.name == json['status']?.toString(),
          orElse: () => ServerAgentStatus.offline,
        ),
        storageStatus: StorageStatus.values.firstWhere(
          (value) => value.name == (json['storageStatus'] ?? json['storage_status'])?.toString(),
          orElse: () => StorageStatus.offline,
        ),
        nasName: json['nasName']?.toString() ?? json['nas_name']?.toString(),
        totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
        freeBytes: (json['freeBytes'] as num?)?.toInt() ?? 0,
        currentJobId: json['currentJobId']?.toString() ?? json['current_job_id']?.toString(),
        lastHeartbeatAt: DateTime.tryParse(json['lastHeartbeatAt']?.toString() ?? json['last_heartbeat_at']?.toString() ?? ''),
      );
}
