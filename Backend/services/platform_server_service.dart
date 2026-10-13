// Server selection/assignment service. Supabase is the durable source when configured;
// the in-memory catalog keeps local development functional without external services.

import 'dart:io';

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

  /// Synthetic local servers may only be used when persistence is deliberately
  /// disabled or the mock launcher explicitly enables this development catalog.
  /// Never silently offer/assign fake servers in a normal Supabase deployment.
  bool get _allowLocalDevelopmentCatalog {
    final value = (Platform.environment['PLATFORM_SERVER_MOCK'] ?? '')
        .trim()
        .toLowerCase();
    return value == 'true' || value == '1' || value == 'yes';
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
        final result = await store.loadPlatformServerContext(
          accountExternalId: account.id,
        );
        if (result != null) {
          final persistedContext = ServerContext.fromJson(result);
          // In the explicit mock mode, an empty Supabase catalog falls back to
          // seeded local servers so onboarding can be exercised end to end.
          if (!_allowLocalDevelopmentCatalog ||
              persistedContext.currentServer != null ||
              persistedContext.availableServers.isNotEmpty) {
            return persistedContext;
          }
        } else if (!_allowLocalDevelopmentCatalog) {
          throw StateError(
            'No Supabase account mapping was found for the signed-in account. '
            'Verify accounts.external_account_id and the platform-server migrations.',
          );
        }
      } catch (error) {
        if (!_allowLocalDevelopmentCatalog) rethrow;
        // Only the explicit mock launcher may fall back to the seeded catalog.
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

    final cleanServerId = serverId.trim();
    final isSeededLocalServer = cleanServerId.startsWith('local-server-');
    if (store.enabled &&
        !(isSeededLocalServer && _allowLocalDevelopmentCatalog)) {
      final result = await store.claimPlatformServer(
        accountExternalId: account.id,
        serverId: cleanServerId,
        displayName: cleanName,
      );
      return PlatformServer.fromJson(
        Map<String, dynamic>.from(result['server'] as Map),
      );
    }

    // In local development, claim the explicitly seeded ID in memory. This is
    // intentionally not allowed unless PLATFORM_SERVER_MOCK=true (or Supabase
    // is disabled), otherwise fake server IDs could be assigned in production.
    final existing = _accountAssignments[account.id];
    if (existing != null && existing != cleanServerId) {
      throw StateError('This account already has a server assignment.');
    }
    final server = _servers[cleanServerId];
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
