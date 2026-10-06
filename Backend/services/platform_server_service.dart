// Server selection/assignment service. Supabase is the durable source when configured;
// the in-memory catalog keeps local development functional without external services.

import '../models/account.dart';
import '../models/platform_server.dart';
import '../supabase_store.dart';

class PlatformServerService {
  final SupabaseStore store;
  final Map<String, PlatformServer> _servers = <String, PlatformServer>{};
  final Map<String, String> _accountAssignments = <String, String>{};
  final Map<String, String> _accountDisplayNames = <String, String>{};

  PlatformServerService({required this.store}) {
    _seedLocalCatalog();
  }

  void _seedLocalCatalog() {
    if (_servers.isNotEmpty) return;
    for (var i = 1; i <= 50; i++) {
      final warehouseIndex = i <= 25 ? 1 : 2;
      final number = i <= 25 ? i : i - 25;
      final id = 'local-server-$i';
      _servers[id] = PlatformServer(
        id: id,
        warehouseId: 'local-warehouse-$warehouseIndex',
        warehouseName: warehouseIndex == 1 ? 'North Warehouse' : 'South Warehouse',
        name: 'Server ${number.toString().padLeft(2, '0')}',
        status: 'available',
        storageTotalBytes: 20 * 1024 * 1024 * 1024 * 1024,
        storageUsedBytes: (number * 0.22 * 1024 * 1024 * 1024 * 1024).round(),
        ramGb: number.isEven ? 128 : 96,
        cpuCores: number.isEven ? 32 : 24,
        sshEnabled: true,
        endpoint: 'server-$i.local',
      );
    }
  }

  Future<ServerContext> contextFor(Account account) async {
    if (store.enabled) {
      try {
        final result = await store.loadPlatformServerContext(accountExternalId: account.id);
        if (result != null) return ServerContext.fromJson(result);
      } catch (_) {
        // Fall back to local state when the optional store is unavailable.
      }
    }

    final serverId = _accountAssignments[account.id];
    if (serverId != null) {
      final base = _servers[serverId];
      if (base != null) {
        final current = PlatformServer(
          id: base.id,
          warehouseId: base.warehouseId,
          warehouseName: base.warehouseName,
          name: base.name,
          status: 'claimed',
          storageTotalBytes: base.storageTotalBytes,
          storageUsedBytes: base.storageUsedBytes,
          ramGb: base.ramGb,
          cpuCores: base.cpuCores,
          sshEnabled: base.sshEnabled,
          endpoint: base.endpoint,
          customName: _accountDisplayNames[account.id],
          assignedToCurrentAccount: true,
        );
        return ServerContext(currentServer: current, availableServers: _available());
      }
    }
    return ServerContext(availableServers: _available());
  }

  List<PlatformServer> _available() => _servers.values
      .where((server) =>
          server.status == 'available' && !_accountAssignments.containsValue(server.id))
      .toList(growable: false);

  Future<PlatformServer> claim({
    required Account account,
    required String serverId,
    required String displayName,
  }) async {
    final cleanName = displayName.trim();
    if (cleanName.isEmpty) throw ArgumentError('A server display name is required.');
    if (cleanName.length > 100) throw ArgumentError('Server display name is too long.');

    if (store.enabled) {
      final result = await store.claimPlatformServer(
        accountExternalId: account.id,
        serverId: serverId.trim(),
        displayName: cleanName,
      );
      return PlatformServer.fromJson(Map<String, dynamic>.from(result['server'] as Map));
    }

    final existing = _accountAssignments[account.id];
    if (existing != null && existing != serverId) {
      throw StateError('This account already has a server assignment.');
    }
    final server = _servers[serverId.trim()];
    if (server == null) throw StateError('Server not found.');
    if (server.status != 'available') throw StateError('Server is no longer available.');
    if (_accountAssignments.containsValue(server.id)) {
      throw StateError('Server is no longer available.');
    }
    _accountAssignments[account.id] = server.id;
    _accountDisplayNames[account.id] = cleanName;
    return PlatformServer(
      id: server.id,
      warehouseId: server.warehouseId,
      warehouseName: server.warehouseName,
      name: server.name,
      status: 'claimed',
      storageTotalBytes: server.storageTotalBytes,
      storageUsedBytes: server.storageUsedBytes,
      ramGb: server.ramGb,
      cpuCores: server.cpuCores,
      sshEnabled: server.sshEnabled,
      endpoint: server.endpoint,
      customName: cleanName,
      assignedToCurrentAccount: true,
    );
  }

  Future<PlatformServer?> rename({required Account account, required String displayName}) async {
    final clean = displayName.trim();
    if (clean.isEmpty) throw ArgumentError('A server display name is required.');
    if (store.enabled) {
      final result = await store.renamePlatformServer(
        accountExternalId: account.id,
        displayName: clean,
      );
      final server = result['server'];
      return server is Map ? PlatformServer.fromJson(Map<String, dynamic>.from(server)) : null;
    }
    final serverId = _accountAssignments[account.id];
    if (serverId == null) return null;
    _accountDisplayNames[account.id] = clean;
    return (await contextFor(account)).currentServer;
  }

  Future<void> release(Account account) async {
    if (store.enabled) {
      await store.releasePlatformServer(accountExternalId: account.id);
      return;
    }
    _accountAssignments.remove(account.id);
    _accountDisplayNames.remove(account.id);
  }
}
