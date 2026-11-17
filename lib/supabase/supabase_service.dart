import 'dart:convert';

// FILE: `lib/supabase_service.dart`.
// Purpose: Part of the documented streaming-service client/backend architecture.
// Media files remain on the appropriate account server; this source contains
// application logic, UI, or API coordination.

import 'supabase_config.dart';

/// Client-side persistence facade for application state.
///
/// The client never receives a Supabase service-role key and never stores
/// movie/TV/music files in Supabase. Physical media remains on the account's
/// home server.
class SupabaseService {
  SupabaseService._();

  /// Shared service instance.
  static final SupabaseService instance = SupabaseService._();

  /// Whether Supabase configuration is available.
  bool get isConfigured => SupabaseConfig.isConfigured;

  /// Initialize Supabase when configuration is available.
  Future<void> initialize() => SupabaseConfig.initialize();

  /// Returns the currently authenticated account.
  ///
  /// Returns null when Supabase is not configured, there is no authenticated
  /// user, or no matching account row exists.
  Future<Map<String, dynamic>?> currentAccount() async {
    final client = SupabaseConfig.client;
    final user = client?.auth.currentUser;

    if (client == null || user == null) {
      return null;
    }

    final row = await client
        .from('accounts')
        .select(
          'id,username,display_name,avatar_url,status,created_at',
        )
        .eq('auth_user_id', user.id)
        .maybeSingle();

    return row;
  }

  /// Returns the active profiles belonging to the authenticated account.
  Future<List<Map<String, dynamic>>> profiles() async {
    final client = SupabaseConfig.client;

    if (client == null) {
      return const [];
    }

    final account = await currentAccount();
    final accountId = account?['id'];

    if (accountId == null) {
      return const [];
    }

    final rows = await client
        .from('profiles')
        .select()
        .eq('account_id', accountId)
        .eq('is_active', true)
        .order('created_at');

    return List<Map<String, dynamic>>.from(rows);
  }

  /// Runs the account-authenticated hybrid catalog search. Vector retrieval is
  /// optional: when the embedding function is not configured or unavailable,
  /// PostgreSQL still searches its full-text and trigram indexes.
  Future<List<Map<String, dynamic>>> hybridSearchMedia({
    required String query,
    int limit = 50,
    bool requireSubtitles = false,
    bool requireAudioDescription = false,
    bool requireAdFree = false,
  }) async {
    final client = SupabaseConfig.client;
    final clean = query.trim();
    if (client == null || client.auth.currentUser == null || clean.isEmpty) {
      return const <Map<String, dynamic>>[];
    }

    String? embeddingText;
    try {
      final embedded = await client.functions.invoke(
        'hybrid-search-embedding',
        body: <String, dynamic>{'action': 'query', 'text': clean},
      );
      final payload = embedded.data;
      if (payload is Map && payload['embedding'] is List) {
        embeddingText = '[${(payload['embedding'] as List).join(',')}]';
      }
    } catch (_) {
      // FTS + trigram remain a complete fallback when embeddings are offline.
    }

    final response = await client.rpc('hybrid_search_media', params: <String, dynamic>{
      'query_text': clean,
      'query_embedding': embeddingText,
      'result_limit': limit.clamp(1, 100),
      'filter_subtitles': requireSubtitles,
      'filter_audio_description': requireAudioDescription,
      'filter_ad_free': requireAdFree,
    });
    if (response is! List) return const <Map<String, dynamic>>[];
    return response
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  /// Whether Supabase has an authenticated user session for search RPCs.
  bool get isAuthenticated => SupabaseConfig.client?.auth.currentUser != null;

  /// Converts a short user-recorded search utterance into text. Audio is sent
  /// only to the configured Edge Function and is not stored by this client.
  Future<String> transcribeSearchAudio(
    List<int> audioBytes, {
    required String mimeType,
  }) async {
    final client = SupabaseConfig.client;
    if (client == null || client.auth.currentUser == null) {
      throw StateError('Sign in to use voice search.');
    }
    if (audioBytes.isEmpty || audioBytes.length > 5 * 1024 * 1024) {
      throw ArgumentError('Voice search audio must be between 1 byte and 5 MB.');
    }
    final response = await client.functions.invoke(
      'transcribe-search-audio',
      body: <String, dynamic>{
        'audioBase64': base64Encode(audioBytes),
        'mimeType': mimeType,
      },
    );
    final data = response.data;
    final transcript = data is Map ? (data['text'] ?? '').toString().trim() : '';
    if (transcript.isEmpty) throw StateError('No speech was recognized.');
    return transcript;
  }

  /// Returns servers associated with the current application context.
  Future<List<Map<String, dynamic>>> myServers() async {
    final client = SupabaseConfig.client;

    if (client == null) {
      return const [];
    }

    final rows = await client
        .from('servers')
        .select()
        .order('created_at');

    return List<Map<String, dynamic>>.from(rows);
  }

  /// Returns media available from a specific home server.
  ///
  /// The media files themselves remain on the home server. Supabase stores
  /// catalog and availability metadata only.
  Future<List<Map<String, dynamic>>> myServerMedia(
    String serverId,
  ) async {
    final client = SupabaseConfig.client;

    if (client == null) {
      return const [];
    }

    final rows = await client
        .from('server_media')
        .select(
          'id,'
          'server_id,'
          'media_catalog_id,'
          'server_media_id,'
          'availability,'
          'metadata_version,'
          'last_seen_at,'
          'metadata,'
          'media_catalog(*)',
        )
        .eq('server_id', serverId);

    return List<Map<String, dynamic>>.from(rows);
  }

  /// Returns globally visible reviews for a catalog item.
  Future<List<Map<String, dynamic>>> globalReviews(
    String mediaCatalogId,
  ) async {
    final client = SupabaseConfig.client;

    if (client == null) {
      return const [];
    }

    final rows = await client
        .from('reviews')
        .select(
          'id,'
          'media_catalog_id,'
          'rating,'
          'review_text,'
          'public_username,'
          'created_at',
        )
        .eq('media_catalog_id', mediaCatalogId)
        .eq('visibility', 'global')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(rows);
  }
}