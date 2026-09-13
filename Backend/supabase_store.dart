// FILE: `Backend/supabase_store.dart`.
// Purpose: Part of the documented streaming-service client/backend architecture.
// Media files remain on the appropriate account server; this source contains application logic, UI, or API coordination.

import 'package:supabase/supabase.dart';

import 'models/account.dart';

/// Server-side Supabase persistence adapter.
///
/// The service-role key is read only from the home-server environment and is
/// never shipped to Flutter. Physical media remains on the home server.
class SupabaseStore {
  SupabaseStore._();
  static final SupabaseStore instance = SupabaseStore._();

  SupabaseClient? _client;

  bool get enabled => _client != null;

  void initialize() {
    final url = const String.fromEnvironment('SUPABASE_URL');
    final key = const String.fromEnvironment('SUPABASE_SERVICE_ROLE_KEY');
    if (url.isEmpty || key.isEmpty) return;
    _client = SupabaseClient(url, key);
  }

  Future<Map<String, dynamic>?> accountByAuthUserId(String authUserId) async {
    final c = _client;
    if (c == null) return null;
    return await c.from('accounts').select().eq('auth_user_id', authUserId).maybeSingle();
  }

  Future<Map<String, dynamic>?> registerServer({
    required String accountId,
    required String name,
    String? endpoint,
  }) async {
    final c = _client;
    if (c == null) return null;
    final row = await c.rpc('register_home_server', params: {
      'p_name': name,
      'p_endpoint': endpoint,
    });
    return row is Map<String, dynamic> ? row : null;
  }

  Future<void> heartbeat(String serverId) async {
    final c = _client;
    if (c == null) return;
    await c.rpc('server_heartbeat', params: {'p_server_id': serverId});
  }


  /// Uploads a sanitized account snapshot to Supabase.
  ///
  /// Password hashes, security-answer hashes, session tokens, and physical
  /// media files are deliberately excluded. The backend service-role key is
  /// used only here, never by Flutter.
  Future<void> syncAccountSnapshot(
    Account account, {
    Map<String, dynamic>? clientSnapshot,
  }) async {
    final c = _client;
    if (c == null) return;

    final rows = <Map<String, dynamic>>[
      {
        'external_account_id': account.id,
        'username': account.username,
        'email': account.email,
        'status': 'active',
        'storage_limit_bytes': account.storageLimitBytes,
        'storage_used_bytes': account.storageUsedBytes,
        'storage_request_pending': account.storageRequestPending,
        'storage_requested_terabytes': account.storageRequestedTerabytes,
        'storage_request_fee_usd': account.storageRequestFeeUsd,
        'storage_request_status': account.storageRequestStatus,
        'storage_request_at': account.storageRequestAt?.toUtc().toIso8601String(),
        'profiles': account.profiles.map((p) => {
          'external_profile_id': p.id,
          'name': p.name,
          'avatar_url': p.avatarUrl,
        }).toList(),
        'shared_media_ids': List<String>.from(account.sharedMediaIds),
        'wishlist_media_ids': List<String>.from(account.wishlistMediaIds),
        'wishlist_recommendation_ids': List<String>.from(account.wishlistRecommendationIds),
        'notifications': List<Map<String, dynamic>>.from(account.notifications),
        'client_snapshot': clientSnapshot ?? <String, dynamic>{},
        'synced_at': DateTime.now().toUtc().toIso8601String(),
      },
    ];

    await c.from('account_sync_snapshots').upsert(
      rows,
      onConflict: 'external_account_id',
    );
  }

  Future<List<dynamic>> checkGroupWatchCompatibility({
    required String mediaCatalogId,
    required String versionKey,
    required List<String> profileIds,
  }) async {
    final c = _client;
    if (c == null) return const [];
    final result = await c.rpc('check_group_watch_compatibility', params: {
      'p_media_catalog_id': mediaCatalogId,
      'p_version_key': versionKey,
      'p_profile_ids': profileIds,
    });
    return result is List ? result : const [];
  }
}
