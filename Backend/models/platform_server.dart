// Server infrastructure models used by server selection and cross-server features.

class PlatformServer {
  final String id;
  final String warehouseId;
  final String warehouseName;
  final String name;
  final String status;
  final int storageTotalBytes;
  final int storageUsedBytes;
  final int ramGb;
  final int cpuCores;
  final bool sshEnabled;
  final String? endpoint;
  final String? customName;
  final bool assignedToCurrentAccount;

  const PlatformServer({
    required this.id,
    required this.warehouseId,
    required this.warehouseName,
    required this.name,
    required this.status,
    required this.storageTotalBytes,
    required this.storageUsedBytes,
    required this.ramGb,
    required this.cpuCores,
    required this.sshEnabled,
    this.endpoint,
    this.customName,
    this.assignedToCurrentAccount = false,
  });

  double get storageUsedRatio => storageTotalBytes <= 0
      ? 0
      : (storageUsedBytes / storageTotalBytes).clamp(0, 1).toDouble();

  String get displayName =>
      customName?.trim().isNotEmpty == true ? customName!.trim() : name;

  factory PlatformServer.fromJson(Map<String, dynamic> json) {
    int intValue(Object? value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;
    return PlatformServer(
      id: json['id']?.toString() ?? '',
      warehouseId: json['warehouseId']?.toString() ?? json['warehouse_id']?.toString() ?? '',
      warehouseName: json['warehouseName']?.toString() ?? json['warehouse_name']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Server',
      status: json['status']?.toString() ?? 'available',
      storageTotalBytes: intValue(json['storageTotalBytes'] ?? json['storage_total_bytes']),
      storageUsedBytes: intValue(json['storageUsedBytes'] ?? json['storage_used_bytes']),
      ramGb: intValue(json['ramGb'] ?? json['ram_gb']),
      cpuCores: intValue(json['cpuCores'] ?? json['cpu_cores']),
      sshEnabled: json['sshEnabled'] == true || json['ssh_enabled'] == true,
      endpoint: json['endpoint']?.toString(),
      customName: json['customName']?.toString() ?? json['custom_name']?.toString(),
      assignedToCurrentAccount: json['assignedToCurrentAccount'] == true || json['assigned_to_current_account'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'warehouseId': warehouseId,
        'warehouseName': warehouseName,
        'name': name,
        'status': status,
        'storageTotalBytes': storageTotalBytes,
        'storageUsedBytes': storageUsedBytes,
        'ramGb': ramGb,
        'cpuCores': cpuCores,
        'sshEnabled': sshEnabled,
        'endpoint': endpoint,
        'customName': customName,
        'assignedToCurrentAccount': assignedToCurrentAccount,
      };
}

class ServerContext {
  final PlatformServer? currentServer;
  final List<PlatformServer> availableServers;

  const ServerContext({this.currentServer, this.availableServers = const []});

  bool get needsServerSelection => currentServer == null;

  factory ServerContext.fromJson(Map<String, dynamic> json) {
    final current = json['currentServer'];
    final available = json['availableServers'];
    return ServerContext(
      currentServer: current is Map ? PlatformServer.fromJson(Map<String, dynamic>.from(current)) : null,
      availableServers: available is List
          ? available.whereType<Map>().map((item) => PlatformServer.fromJson(Map<String, dynamic>.from(item))).toList(growable: false)
          : const [],
    );
  }
}
