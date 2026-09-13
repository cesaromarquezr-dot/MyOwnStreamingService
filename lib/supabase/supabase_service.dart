// FILE: `lib/supabase_service.dart`.
// Purpose: Part of the documented streaming-service client/backend architecture.
// Media files remain on the appropriate account server; this source contains application logic, UI, or API coordination.

import 'supabase_config.dart';

/// Client-side persistence facade for application state.
///
/// The client never receives a Supabase service-role key and never stores
/// movie/TV/music files in Supabase. Physical media remains on the account's
/// home server.
class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  bool get isConfigured => SupabaseConfig.isConfigured;

  Future<void> initialize() => SupabaseConfig.initialize();

  Future<Map<String, dynamic>?> currentAccount() async {
    final client = SupabaseConfig.client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return null;
    final row = await client
        .from('accounts')
        .select('id,username,display_name,avatar_url,status,created_at')
        .eq('auth_user_id', user.id)
        .maybeSingle();
    return row;
  }

  Future<List<Map<String, dynamic>>> profiles() async {
    final client = SupabaseConfig.client;
    if (client == null) return const [];
    final account = await currentAccount();
    final accountId = account?['id'];
    if (accountId == null) return const [];
    final rows = await client
        .from('profiles')
        .select()
        .eq('account_id', accountId)
        .eq('is_active', true)
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> myServers() async {
    final client = SupabaseConfig.client;
    if (client == null) return const [];
    final rows = await client.from('servers').select().order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> myServerMedia(String serverId) async {
    final client = SupabaseConfig.client;
    if (client == null) return const [];
    final rows = await client
        .from('server_media')
        .select('id,server_id,media_catalog_id,server_media_id,availability,metadata_version,last_seen_at,metadata,media_catalog(*)')
        .eq('server_id', serverId);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> globalReviews(String mediaCatalogId) async {
    final client = SupabaseConfig.client;
    if (client == null) return const [];
    final rows = await client
        .from('reviews')
        .select('id,media_catalog_id,rating,review_text,public_username,created_at')
        .eq('media_catalog_id', mediaCatalogId)
        .eq('visibility', 'global')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }
}
