import '../app_core.dart';
import '../supabase/supabase_config.dart';
import '../supabase/supabase_service.dart';

/// Supabase-backed community reviews and discussion boards for a canonical
/// movie, series, episode, album, song, or other library item.
///
/// The service stores metadata and text only. Media files remain on the
/// user's home server. Row-level security is enforced by the accompanying
/// migration; the client never receives a service-role key.
class MediaCommunityService {
  MediaCommunityService._();
  static final MediaCommunityService instance = MediaCommunityService._();

  bool get isConfigured => SupabaseConfig.client != null;
  bool get isAuthenticated => SupabaseConfig.client?.auth.currentUser != null;

  Future<String> _accountId() async {
    final account = await SupabaseService.instance.currentAccount();
    final id = account?['id']?.toString().trim() ?? '';
    if (id.isEmpty) {
      throw StateError('Sign in to your MyOwnStreamingService account to use community features.');
    }
    return id;
  }

  Future<Map<String, String>> _ownedProfile() async {
    final profile = AppController.instance.currentProfile;
    final profileId = profile?.id.trim() ?? '';
    if (profileId.isEmpty) {
      throw StateError('Select a profile before posting.');
    }
    final profiles = await SupabaseService.instance.profiles();
    for (final row in profiles) {
      if (row['id']?.toString() == profileId) {
        return <String, String>{
          'id': profileId,
          'name': row['name']?.toString().trim().isNotEmpty == true
              ? row['name'].toString().trim()
              : 'Profile',
        };
      }
    }
    throw StateError('The selected profile does not belong to the signed-in account.');
  }

  Future<List<Map<String, dynamic>>> loadReviews(
    String mediaKey, {
    int page = 1,
  }) async {
    if (page < 1) return const <Map<String, dynamic>>[];
    final client = SupabaseConfig.client;
    if (client == null) return const <Map<String, dynamic>>[];
    final rows = await client
        .from('media_community_reviews')
        .select('id,media_key,profile_id,profile_name,rating,review_text,has_play_activity,created_at,updated_at')
        .eq('media_key', mediaKey)
        .order('created_at', ascending: false)
        .range((page - 1) * 100, page * 100 - 1);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> saveReview({
    required String mediaKey,
    required String mediaTitle,
    required String mediaType,
    required int rating,
    required String reviewText,
    required bool hasPlayActivity,
    String visibility = 'account',
  }) async {
    if (rating < 1 || rating > 5) throw ArgumentError.value(rating, 'rating');
    if (!const <String>{'global', 'account'}.contains(visibility)) {
      throw ArgumentError.value(visibility, 'visibility');
    }
    final body = reviewText.trim();
    if (body.length < 3 || body.length > 3000) {
      throw ArgumentError('A review must contain between 3 and 3000 characters.');
    }
    final client = SupabaseConfig.client;
    if (client == null) throw StateError('Community reviews require Supabase configuration.');
    final accountId = await _accountId();
    final profile = await _ownedProfile();
    final profileId = profile['id']!;
    await client.from('media_community_reviews').upsert(<String, dynamic>{
      'media_key': mediaKey,
      'media_title': mediaTitle,
      'media_type': mediaType,
      'account_id': accountId,
      'profile_id': profileId,
      'profile_name': profile['name'],
      'rating': rating,
      'review_text': body,
      'has_play_activity': hasPlayActivity,
      'visibility': visibility,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'media_key,profile_id');
  }

  Future<List<Map<String, dynamic>>> loadThreads(String mediaKey) async {
    final client = SupabaseConfig.client;
    if (client == null) return const <Map<String, dynamic>>[];
    final rows = await client
        .from('media_discussion_threads')
        .select('id,media_key,profile_id,profile_name,title,body,contains_spoilers,created_at')
        .eq('media_key', mediaKey)
        .order('created_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> createThread({
    required String mediaKey,
    required String mediaTitle,
    required String mediaType,
    required String title,
    required String body,
    required bool containsSpoilers,
    String visibility = 'account',
  }) async {
    final cleanTitle = title.trim();
    final cleanBody = body.trim();
    if (!const <String>{'global', 'account'}.contains(visibility)) {
      throw ArgumentError.value(visibility, 'visibility');
    }
    if (cleanTitle.length < 3 || cleanTitle.length > 120) {
      throw ArgumentError('Discussion titles must contain 3–120 characters.');
    }
    if (cleanBody.length < 3 || cleanBody.length > 5000) {
      throw ArgumentError('Discussion posts must contain 3–5000 characters.');
    }
    final client = SupabaseConfig.client;
    if (client == null) throw StateError('Discussion boards require Supabase configuration.');
    final accountId = await _accountId();
    final profile = await _ownedProfile();
    await client.from('media_discussion_threads').insert(<String, dynamic>{
      'media_key': mediaKey,
      'media_title': mediaTitle,
      'media_type': mediaType,
      'account_id': accountId,
      'profile_id': profile['id'],
      'profile_name': profile['name'],
      'title': cleanTitle,
      'body': cleanBody,
      'contains_spoilers': containsSpoilers,
      'visibility': visibility,
    });
  }

  Future<List<Map<String, dynamic>>> loadReplies(String threadId) async {
    final client = SupabaseConfig.client;
    if (client == null) return const <Map<String, dynamic>>[];
    final rows = await client
        .from('media_discussion_replies')
        .select('id,thread_id,profile_id,profile_name,body,created_at')
        .eq('thread_id', threadId)
        .order('created_at', ascending: true)
        .limit(200);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> addReply({required String threadId, required String body}) async {
    final cleanBody = body.trim();
    if (cleanBody.length < 2 || cleanBody.length > 3000) {
      throw ArgumentError('Replies must contain 2–3000 characters.');
    }
    final client = SupabaseConfig.client;
    if (client == null) throw StateError('Discussion boards require Supabase configuration.');
    final accountId = await _accountId();
    final profile = await _ownedProfile();
    await client.from('media_discussion_replies').insert(<String, dynamic>{
      'thread_id': threadId,
      'account_id': accountId,
      'profile_id': profile['id'],
      'profile_name': profile['name'],
      'body': cleanBody,
    });
  }
}
