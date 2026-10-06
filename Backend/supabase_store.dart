// FILE: `Backend/supabase_store.dart`.
// Purpose: Server-side Supabase persistence for account/application metadata.
// Physical movie, TV, music and disc files remain on each user's home server.
//
// Security boundary:
// - This class uses the Supabase service-role key and therefore MUST remain
//   backend-only.
// - Flutter clients must never receive the service-role key.
// - Client-provided snapshots and metadata are treated as untrusted input.
// - Physical media files remain on the user's home server; Supabase stores
//   metadata, account state, synchronization state, and references.

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:supabase/supabase.dart';

import 'models/account.dart';
import 'models/account_member.dart';
import 'models/payment_session.dart';
import 'models/library_addition.dart';
import 'models/profile.dart';
import 'models/profile_governance.dart';
import 'models/physical_item.dart';
import 'models/shop_entity.dart';
import 'models/subscription.dart';

class SupabaseStore {
  SupabaseStore._();

  static final SupabaseStore instance = SupabaseStore._();

  static const int _maxIdLength = 200;
  static const int _maxEmailLength = 320;
  static const int _maxNameLength = 500;
  static const int _maxMetadataTextLength = 4000;
  static const int _maxSnapshotBytes = 512 * 1024;
  static const int _maxSecurityMetadataBytes = 32 * 1024;
  static const int _maxShopQueryLength = 200;
  static const int _maxShopEntities = 500;
  static const int maxSocialAttachmentBytes = 50 * 1024 * 1024;
  static const String _socialPhotoBucket = 'social-media';

  SupabaseClient? _client;

  bool get enabled => _client != null;

  // ---------------------------------------------------------------------------
  // INITIALIZATION
  // ---------------------------------------------------------------------------

  void initialize() {
    if (_client != null) return;

    final url = (Platform.environment['SUPABASE_URL'] ??
            const String.fromEnvironment('SUPABASE_URL'))
        .trim();

    final key = (Platform.environment['SUPABASE_SERVICE_ROLE_KEY'] ??
            const String.fromEnvironment('SUPABASE_SERVICE_ROLE_KEY'))
        .trim();

    // Supabase is intentionally optional for local/offline development.
    if (url.isEmpty || key.isEmpty) {
      return;
    }

    final parsedUrl = Uri.tryParse(url);

    if (parsedUrl == null ||
        !parsedUrl.isAbsolute ||
        (parsedUrl.scheme != 'https' && parsedUrl.scheme != 'http') ||
        parsedUrl.host.isEmpty) {
      throw StateError(
        'SUPABASE_URL must be a valid absolute HTTP(S) URL.',
      );
    }

    if (key.length < 20) {
      throw StateError(
        'SUPABASE_SERVICE_ROLE_KEY appears to be invalid.',
      );
    }

    _client = SupabaseClient(
      url,
      key,
    );
  }

  SupabaseClient? get _db => _client;

  Future<Map<String, dynamic>> loadSocialHome({
    required String accountExternalId,
    required String profileExternalId,
  }) async {
    final c = _db;
    if (c == null)
      throw StateError('Social features require Supabase persistence.');
    final current = await c
        .from('accounts')
        .select('id,username,display_name,avatar_url')
        .eq('external_account_id', accountExternalId)
        .maybeSingle();
    if (current == null) throw StateError('Account not found.');
    final accountId = current['id'].toString();
    final outgoing = await c
        .from('social_friendships')
        .select()
        .eq('requester_account_id', accountId)
        .eq('requester_profile_id', profileExternalId)
        .eq('status', 'accepted');
    final incoming = await c
        .from('social_friendships')
        .select()
        .eq('recipient_account_id', accountId)
        .eq('recipient_profile_id', profileExternalId)
        .eq('status', 'accepted');
    final friends = <Map<String, dynamic>>[];
    final friendKeys = <String>{};
    for (final row in [...outgoing, ...incoming]) {
      final outgoingFriend =
          row['requester_account_id'].toString() == accountId;
      final otherId = (outgoingFriend
              ? row['recipient_account_id']
              : row['requester_account_id'])
          .toString();
      final otherProfile = (outgoingFriend
              ? row['recipient_profile_id']
              : row['requester_profile_id'])
          .toString();
      final key = '$otherId:$otherProfile';
      if (!friendKeys.add(key)) continue;
      final other = await c
          .from('accounts')
          .select('id,username,display_name,avatar_url')
          .eq('id', otherId)
          .maybeSingle();
      if (other != null) {
        friends.add({...other, 'profileId': otherProfile});
      }
    }
    final pendingRows = await c
        .from('social_friendships')
        .select()
        .eq('recipient_account_id', accountId)
        .eq('recipient_profile_id', profileExternalId)
        .eq('status', 'pending')
        .order('created_at', ascending: false)
        .limit(20);
    final requests = <Map<String, dynamic>>[];
    for (final row in pendingRows) {
      final sender = await c
          .from('accounts')
          .select('username,display_name,avatar_url')
          .eq('id', row['requester_account_id'].toString())
          .maybeSingle();
      if (sender != null) requests.add({...row, 'sender': sender});
    }
    final candidates = await c
        .from('accounts')
        .select('id,username,display_name,avatar_url')
        .eq('status', 'active')
        .eq('social_discoverable', true)
        .neq('id', accountId)
        .limit(50);
    final excluded = {
      ...friendKeys,
      for (final row in pendingRows)
        '${row['requester_account_id']}:${row['requester_profile_id']}'
    };
    final suggestions = <Map<String, dynamic>>[];
    for (final person in candidates) {
      if (suggestions.length >= 10) break;
      final otherProfiles = await c
          .from('profiles')
          .select('external_profile_id,name')
          .eq('account_id', person['id'].toString())
          .eq('is_active', true)
          .not('external_profile_id', 'is', null)
          .limit(1);
      if (otherProfiles.isEmpty) continue;
      final profile = otherProfiles.first;
      final key = '${person['id']}:${profile['external_profile_id']}';
      if (excluded.contains(key)) continue;
      suggestions.add({
        ...person,
        'profileId': profile['external_profile_id'],
        'profileName': profile['name']
      });
    }

    final posts = <Map<String, dynamic>>[];
    for (final friend in friends) {
      final items = await c
          .from('social_posts')
          .select()
          .eq('author_account_id', friend['id'].toString())
          .eq('author_profile_id', friend['profileId'].toString())
          .eq('visibility', 'friends')
          .order('created_at', ascending: false)
          .limit(20);
      posts.addAll(items.map((row) => {...row, 'author': friend}));
    }

    final ownPosts = await c
        .from('social_posts')
        .select()
        .eq('author_account_id', accountId)
        .eq('author_profile_id', profileExternalId)
        .eq('visibility', 'friends')
        .order('created_at', ascending: false)
        .limit(20);
    for (final row in ownPosts) {
      posts.add({
        ...Map<String, dynamic>.from(row),
        'author': current,
        'isMine': true,
      });
    }

    final memberships = await c
        .from('social_community_memberships')
        .select('community_id')
        .eq('account_id', accountId)
        .eq('profile_id', profileExternalId);
    final joinedCommunityIds =
        memberships.map((item) => item['community_id'].toString()).toSet();
    final communityPosts = <Map<String, dynamic>>[];
    if (joinedCommunityIds.isNotEmpty) {
      final communityLinks = await c
          .from('social_post_communities')
          .select('post_id,community_id')
          .inFilter('community_id', joinedCommunityIds.toList());
      final legacyCommunityPosts = await c
          .from('social_posts')
          .select('id,community_id')
          .inFilter('community_id', joinedCommunityIds.toList())
          .limit(100);
      final communityIdsByPost = <String, Set<String>>{};
      for (final link in communityLinks) {
        communityIdsByPost
            .putIfAbsent(link['post_id'].toString(), () => <String>{})
            .add(link['community_id'].toString());
      }
      for (final row in legacyCommunityPosts) {
        final communityId = row['community_id']?.toString();
        if (communityId == null || communityId.isEmpty) continue;
        communityIdsByPost
            .putIfAbsent(row['id'].toString(), () => <String>{})
            .add(communityId);
      }
      for (final entry in communityIdsByPost.entries) {
        final row = await c
            .from('social_posts')
            .select()
            .eq('id', entry.key)
            .eq('visibility', 'community')
            .maybeSingle();
        if (row == null) continue;
        final authorId = row['author_account_id'].toString();
        final author = await c
            .from('accounts')
            .select('id,username,display_name,avatar_url')
            .eq('id', authorId)
            .maybeSingle();
        communityPosts.add({
          ...Map<String, dynamic>.from(row),
          'author': author == null
              ? <String, dynamic>{}
              : Map<String, dynamic>.from(author),
          'communityPost': true,
          'communityIds': entry.value.toList(),
        });
      }
    }

    final allVisiblePosts = <String, Map<String, dynamic>>{
      for (final post in [...posts, ...communityPosts])
        if (post['id'] != null) post['id'].toString(): post,
    };
    for (final entry in allVisiblePosts.entries) {
      final reactions = await c
          .from('social_post_reactions')
          .select('reaction,account_id,profile_id')
          .eq('post_id', entry.key);
      final comments = await c
          .from('social_post_comments')
          .select('id')
          .eq('post_id', entry.key);
      final myReaction = reactions.where((item) =>
          item['account_id'].toString() == accountId &&
          item['profile_id'].toString() == profileExternalId);
      entry.value['reactionCount'] = reactions.length;
      entry.value['commentCount'] = comments.length;
      entry.value['myReaction'] =
          myReaction.isEmpty ? null : myReaction.first['reaction']?.toString();
      await _attachSocialMedia(entry.value);
    }
    posts
      ..clear()
      ..addAll(
        allVisiblePosts.values.where((post) => post['communityPost'] != true),
      )
      ..sort((a, b) => (b['created_at']?.toString() ?? '')
          .compareTo(a['created_at']?.toString() ?? ''));
    communityPosts
      ..clear()
      ..addAll(
        allVisiblePosts.values.where((post) => post['communityPost'] == true),
      )
      ..sort((a, b) => (b['created_at']?.toString() ?? '')
          .compareTo(a['created_at']?.toString() ?? ''));

    final communities = await c
        .from('social_communities')
        .select('id,name,slug,description,visibility,created_at')
        .eq('visibility', 'public')
        .order('name')
        .limit(100);
    final stories = await _loadSocialStories(
      accountId: accountId,
      profileExternalId: profileExternalId,
    );
    final communityStories = await _loadCommunityStories(
      accountId: accountId,
      profileExternalId: profileExternalId,
    );
    return {
      'friendCount': friends.length,
      'friends': friends,
      'requests': requests,
      'suggestions': suggestions,
      'posts': posts.take(30).toList(),
      'communityPosts': communityPosts.take(100).toList(),
      'stories': stories,
      'communityStories': communityStories,
      'communities': communities
          .map((community) => {
                ...community,
                'joined':
                    joinedCommunityIds.contains(community['id'].toString()),
              })
          .toList(),
    };
  }

  Future<void> _attachSocialMedia(Map<String, dynamic> row) async {
    final c = _db;
    if (c == null) return;
    final reference = row['media_reference'];
    if (reference is! Map) return;
    final attachmentPath = (reference['attachmentPath'] ??
            reference['videoPath'] ??
            reference['photoPath'])
        ?.toString();
    final coverPath = reference['coverPath']?.toString();
    if ((attachmentPath == null || attachmentPath.isEmpty) &&
        (coverPath == null || coverPath.isEmpty)) {
      return;
    }

    final authorAccountId =
        (row['author_account_id'] ?? row['sender_account_id'])?.toString() ??
            '';
    final authorProfileId =
        (row['author_profile_id'] ?? row['sender_profile_id'])?.toString() ??
            '';
    final referenceOwnerAccountId =
        reference['attachmentOwnerAccountId']?.toString();
    final referenceOwnerProfileId =
        reference['attachmentOwnerProfileId']?.toString();
    final ownerPrefix =
        '${referenceOwnerAccountId ?? authorAccountId}/'
        '${Uri.encodeComponent(referenceOwnerProfileId ?? authorProfileId)}/';
    String? signedUrl;
    if (attachmentPath != null && attachmentPath.isNotEmpty) {
      if (!attachmentPath.startsWith(ownerPrefix) ||
          attachmentPath.contains('..')) {
        return;
      }
      signedUrl = await c.storage
          .from(_socialPhotoBucket)
          .createSignedUrl(attachmentPath, 600);
    }
    String? coverUrl;
    if (coverPath != null && coverPath.isNotEmpty) {
      if (!coverPath.startsWith(ownerPrefix) || coverPath.contains('..')) {
        return;
      }
      coverUrl = await c.storage
          .from(_socialPhotoBucket)
          .createSignedUrl(coverPath, 600);
    }
    row['mediaReference'] = {
      ...Map<String, dynamic>.from(reference),
      if (signedUrl != null &&
          (reference['type'] == 'photo' || reference['type'] == 'image'))
        'imageUrl': signedUrl,
      if (signedUrl != null && reference['type'] == 'video')
        'videoUrl': signedUrl,
      if (signedUrl != null &&
          (reference['type'] == 'voice' || reference['type'] == 'audio'))
        'audioUrl': signedUrl,
      if (coverUrl != null) 'coverUrl': coverUrl,
    };
  }

  Future<Map<String, dynamic>> sendSocialFriendRequest(
      {required String accountExternalId,
      required String profileExternalId,
      required String username}) async {
    final c = _db;
    if (c == null)
      throw StateError('Social features require Supabase persistence.');
    final me = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id', accountExternalId)
        .maybeSingle();
    final target = await c
        .from('accounts')
        .select('id')
        .ilike('username', username.trim())
        .maybeSingle();
    if (me == null || target == null)
      throw StateError('Account or user not found.');
    final targetProfiles = await c
        .from('profiles')
        .select('external_profile_id')
        .eq('account_id', target['id'].toString())
        .eq('is_active', true)
        .not('external_profile_id', 'is', null)
        .limit(1);
    if (targetProfiles.isEmpty)
      throw StateError('That user has no active profile.');
    final targetProfile =
        targetProfiles.first['external_profile_id'].toString();
    if (me['id'].toString() == target['id'].toString() &&
        profileExternalId == targetProfile)
      throw StateError('You cannot add yourself.');
    final rows = await c
        .from('social_friendships')
        .select()
        .eq('requester_account_id', me['id'].toString())
        .eq('requester_profile_id', profileExternalId)
        .eq('recipient_account_id', target['id'].toString())
        .eq('recipient_profile_id', targetProfile)
        .limit(1);
    if (rows.isNotEmpty &&
        ['pending', 'accepted'].contains(rows.first['status']))
      throw StateError('A request or friendship already exists.');
    final data = {
      'requester_account_id': me['id'],
      'requester_profile_id': profileExternalId,
      'recipient_account_id': target['id'],
      'recipient_profile_id': targetProfile,
      'status': 'pending',
      'updated_at': DateTime.now().toUtc().toIso8601String()
    };
    if (rows.isNotEmpty)
      return Map<String, dynamic>.from(await c
          .from('social_friendships')
          .update(data)
          .eq('id', rows.first['id'].toString())
          .select()
          .single());
    return Map<String, dynamic>.from(
        await c.from('social_friendships').insert(data).select().single());
  }

  Future<Map<String, dynamic>> answerSocialFriendRequest(
      {required String accountExternalId,
      required String profileExternalId,
      required String friendshipId,
      required String action}) async {
    final c = _db;
    if (c == null)
      throw StateError('Social features require Supabase persistence.');
    if (!{'accept', 'decline', 'remove'}.contains(action))
      throw ArgumentError('Unsupported friendship action.');
    final me = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id', accountExternalId)
        .single();
    final query = c.from('social_friendships').select().eq('id', friendshipId);
    final row = await query.maybeSingle();
    if (row == null) throw StateError('Friend request not found.');
    final isRecipient =
        row['recipient_account_id'].toString() == me['id'].toString() &&
            row['recipient_profile_id'] == profileExternalId;
    final isRequester =
        row['requester_account_id'].toString() == me['id'].toString() &&
            row['requester_profile_id'] == profileExternalId;
    if (!isRecipient && !isRequester)
      throw StateError('Friend request does not belong to this profile.');
    if ((action == 'accept' || action == 'decline') &&
        (!isRecipient || row['status'] != 'pending'))
      throw StateError('This request is no longer pending.');
    if (action == 'remove' && row['status'] != 'accepted')
      throw StateError('This friendship is no longer active.');
    final status = action == 'accept'
        ? 'accepted'
        : action == 'decline'
            ? 'declined'
            : 'removed';
    return Map<String, dynamic>.from(await c
        .from('social_friendships')
        .update({
          'status': status,
          'updated_at': DateTime.now().toUtc().toIso8601String()
        })
        .eq('id', friendshipId)
        .select()
        .single());
  }

  Future<Map<String, dynamic>> createSocialPost({
    required String accountExternalId,
    required String profileExternalId,
    required String profileName,
    required String body,
    String? communityId,
    List<String> communityIds = const <String>[],
    Map<String, dynamic>? mediaReference,
  }) async {
    final c = _db;
    if (c == null)
      throw StateError('Social features require Supabase persistence.');
    final me = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id', accountExternalId)
        .single();

    final targets = <String>{
      if (communityId != null && communityId.trim().isNotEmpty)
        communityId.trim(),
      ...communityIds
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty),
    }.toList();

    for (final targetCommunityId in targets) {
      final membership = await c
          .from('social_community_memberships')
          .select('community_id')
          .eq('community_id', targetCommunityId)
          .eq('account_id', me['id'].toString())
          .eq('profile_id', profileExternalId)
          .maybeSingle();
      if (membership == null) {
        throw StateError('Join every selected community before posting.');
      }
    }

    final row = await c
        .from('social_posts')
        .insert({
          'author_account_id': me['id'],
          'author_profile_id': profileExternalId,
          'author_profile_name': profileName,
          'body': body.trim(),
          'visibility': targets.isEmpty ? 'friends' : 'community',
          'community_id': targets.isEmpty ? null : targets.first,
          'media_reference': _validateSocialMediaReference(
            mediaReference,
            accountId: me['id'].toString(),
            profileId: profileExternalId,
          ),
        })
        .select()
        .single();

    final postId = row['id'].toString();
    if (targets.isNotEmpty) {
      await c.from('social_post_communities').upsert(
            targets
                .map(
                  (targetCommunityId) => {
                    'post_id': postId,
                    'community_id': targetCommunityId,
                  },
                )
                .toList(),
            onConflict: 'post_id,community_id',
          );
    }

    return Map<String, dynamic>.from(row);
  }

  Future<Map<String, dynamic>> createSocialCommunity(
      {required String accountExternalId,
      required String profileExternalId,
      required String name,
      required String description}) async {
    final c = _db;
    if (c == null)
      throw StateError('Social features require Supabase persistence.');
    final me = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id', accountExternalId)
        .single();
    final slugBase = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'(^-+|-+$)'), '');
    final row = await c
        .from('social_communities')
        .insert({
          'name': name.trim(),
          'slug':
              '$slugBase-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}',
          'description': description.trim(),
          'created_by_account_id': me['id']
        })
        .select()
        .single();
    await c.from('social_community_memberships').insert({
      'community_id': row['id'],
      'account_id': me['id'],
      'profile_id': profileExternalId,
      'role': 'owner'
    });
    return Map<String, dynamic>.from(row);
  }

  Future<void> joinSocialCommunity(
      {required String accountExternalId,
      required String profileExternalId,
      required String communityId}) async {
    final c = _db;
    if (c == null)
      throw StateError('Social features require Supabase persistence.');
    final me = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id', accountExternalId)
        .single();
    final community = await c
        .from('social_communities')
        .select('visibility')
        .eq('id', communityId)
        .maybeSingle();
    if (community == null || community['visibility'] != 'public')
      throw StateError('This community cannot be joined.');
    await c.from('social_community_memberships').upsert({
      'community_id': communityId,
      'account_id': me['id'],
      'profile_id': profileExternalId
    }, onConflict: 'community_id,account_id,profile_id');
  }

  // ---------------------------------------------------------------------------
  // SOCIAL V2: STORIES, POSTS, REACTIONS, COMMENTS, MESSAGES, AND NOTES
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> loadSocialCenter({
    required String accountExternalId,
    required String profileExternalId,
  }) async {
    final c = _db;
    if (c == null) {
      throw StateError('Social features require Supabase persistence.');
    }

    final current = await c
        .from('accounts')
        .select('id,username,display_name,avatar_url')
        .eq('external_account_id', accountExternalId)
        .maybeSingle();
    if (current == null) throw StateError('Account not found.');
    final accountId = current['id'].toString();

    final base = await loadSocialHome(
      accountExternalId: accountExternalId,
      profileExternalId: profileExternalId,
    );

    final conversations = await _loadSocialConversations(
      accountId: accountId,
      profileExternalId: profileExternalId,
    );

    return {
      ...base,
      'conversations': conversations,
    };
  }

  Future<List<Map<String, dynamic>>> _loadSocialStories({
    required String accountId,
    required String profileExternalId,
  }) async {
    final c = _db;
    if (c == null) return const <Map<String, dynamic>>[];

    final now = DateTime.now().toUtc().toIso8601String();
    final rows = await c
        .from('social_stories')
        .select()
        .gt('expires_at', now)
        .order('created_at', ascending: false)
        .limit(100);

    final friendships = await c
        .from('social_friendships')
        .select(
          'requester_account_id,requester_profile_id,recipient_account_id,recipient_profile_id',
        )
        .eq('status', 'accepted');

    final friendProfiles = <String>{'$accountId:$profileExternalId'};
    for (final row in friendships) {
      final requester = row['requester_account_id'].toString();
      final recipient = row['recipient_account_id'].toString();
      if (requester == accountId) {
        friendProfiles.add(
          '$recipient:${row['recipient_profile_id']}',
        );
      } else if (recipient == accountId) {
        friendProfiles.add(
          '$requester:${row['requester_profile_id']}',
        );
      }
    }

    final visible = <Map<String, dynamic>>[];
    for (final raw in rows) {
      final row = Map<String, dynamic>.from(raw);
      final authorId = row['author_account_id']?.toString() ?? '';
      final authorProfileId = row['author_profile_id']?.toString() ?? '';
      if (row['visibility'] != 'friends' ||
          !friendProfiles.contains('$authorId:$authorProfileId')) {
        continue;
      }

      final author = await c
          .from('accounts')
          .select('username,display_name,avatar_url')
          .eq('id', authorId)
          .maybeSingle();

      final story = {
        ...row,
        'author': author == null
            ? <String, dynamic>{}
            : Map<String, dynamic>.from(author),
        'isMine': authorId == accountId && authorProfileId == profileExternalId,
      };
      await _attachSocialMedia(story);
      visible.add(story);
    }
    return visible;
  }

  Future<List<Map<String, dynamic>>> _loadCommunityStories({
    required String accountId,
    required String profileExternalId,
  }) async {
    final c = _db;
    if (c == null) return const <Map<String, dynamic>>[];
    final memberships = await c
        .from('social_community_memberships')
        .select('community_id')
        .eq('account_id', accountId)
        .eq('profile_id', profileExternalId);
    final communityIds =
        memberships.map((row) => row['community_id'].toString()).toList();
    if (communityIds.isEmpty) return const <Map<String, dynamic>>[];

    final now = DateTime.now().toUtc().toIso8601String();
    final rows = await c
        .from('social_stories')
        .select()
        .eq('visibility', 'community')
        .inFilter('community_id', communityIds)
        .gt('expires_at', now)
        .order('created_at', ascending: false)
        .limit(100);
    final result = <Map<String, dynamic>>[];
    for (final raw in rows) {
      final row = Map<String, dynamic>.from(raw);
      final authorId = row['author_account_id']?.toString() ?? '';
      final author = await c
          .from('accounts')
          .select('username,display_name,avatar_url')
          .eq('id', authorId)
          .maybeSingle();
      final story = {
        ...row,
        'author': author == null
            ? <String, dynamic>{}
            : Map<String, dynamic>.from(author),
      };
      final community = await c
          .from('social_communities')
          .select('name')
          .eq('id', row['community_id'].toString())
          .maybeSingle();
      story['communityName'] = community?['name']?.toString() ?? 'Community';
      await _attachSocialMedia(story);
      result.add(story);
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> _loadSocialConversations({
    required String accountId,
    required String profileExternalId,
  }) async {
    final c = _db;
    if (c == null) return const <Map<String, dynamic>>[];

    final memberships = await c
        .from('social_conversation_members')
        .select('conversation_id,last_read_at,last_delivered_at')
        .eq('account_id', accountId)
        .eq('profile_id', profileExternalId);

    final result = <Map<String, dynamic>>[];
    for (final membership in memberships) {
      final conversationId = membership['conversation_id'].toString();
      final conversation = await c
          .from('social_conversations')
          .select()
          .eq('id', conversationId)
          .maybeSingle();
      if (conversation == null) continue;

      final members = await c
          .from('social_conversation_members')
          .select('account_id,profile_id,role')
          .eq('conversation_id', conversationId);

      final people = <Map<String, dynamic>>[];
      for (final member in members) {
        final otherAccountId = member['account_id'].toString();
        final person = await c
            .from('accounts')
            .select('username,display_name,avatar_url')
            .eq('id', otherAccountId)
            .maybeSingle();
        if (person != null) {
          final presence = await c
              .from('social_profile_presence')
              .select(
                'availability,activity_type,activity_text,nickname,last_seen_at',
              )
              .eq('account_id', member['account_id'].toString())
              .eq('profile_id', member['profile_id'].toString())
              .maybeSingle();
          people.add({
            ...Map<String, dynamic>.from(person),
            'accountId': otherAccountId,
            'profileId': member['profile_id'],
            'role': member['role'],
            'isSelf': otherAccountId == accountId,
            'presenceStatus': presence?['availability'] ?? 'away',
            'activityType': presence?['activity_type'],
            'activityText': presence?['activity_text'],
            'nickname': presence?['nickname'],
            'lastSeenAt': presence?['last_seen_at'],
          });
        }
      }

      final messages = await c
          .from('social_messages')
          .select()
          .eq('conversation_id', conversationId)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false)
          .limit(1);
      final lastMessage =
          messages.isEmpty ? null : Map<String, dynamic>.from(messages.first);
      if (lastMessage != null &&
          lastMessage['sender_account_id'].toString() != accountId) {
        final deliveredAt = DateTime.now().toUtc().toIso8601String();
        await c
            .from('social_conversation_members')
            .update({'last_delivered_at': deliveredAt})
            .eq('conversation_id', conversationId)
            .eq('account_id', accountId)
            .eq('profile_id', profileExternalId);
        membership['last_delivered_at'] = deliveredAt;
      }

      final lastRead = membership['last_read_at']?.toString();
      var unreadCount = 0;
      if (lastRead == null || lastRead.isEmpty) {
        final unread = await c
            .from('social_messages')
            .select('id')
            .eq('conversation_id', conversationId)
            .neq('sender_account_id', accountId)
            .isFilter('deleted_at', null);
        unreadCount = unread.length;
      } else {
        final unread = await c
            .from('social_messages')
            .select('id')
            .eq('conversation_id', conversationId)
            .neq('sender_account_id', accountId)
            .gt('created_at', lastRead)
            .isFilter('deleted_at', null);
        unreadCount = unread.length;
      }

      result.add({
        ...Map<String, dynamic>.from(conversation),
        'members': people,
        'lastMessage': lastMessage,
        'unreadCount': unreadCount,
      });
    }

    result.sort((a, b) {
      final aTime = a['lastMessage']?['created_at']?.toString() ??
          a['created_at']?.toString() ??
          '';
      final bTime = b['lastMessage']?['created_at']?.toString() ??
          b['created_at']?.toString() ??
          '';
      return bTime.compareTo(aTime);
    });
    return result;
  }

  Future<Map<String, dynamic>> createSocialConversation({
    required String accountExternalId,
    required String profileExternalId,
    required String username,
  }) async {
    final c = _db;
    if (c == null) {
      throw StateError('Social features require Supabase persistence.');
    }
    final me = await c
        .from('accounts')
        .select('id,username,display_name')
        .eq('external_account_id', accountExternalId)
        .single();
    final target = await c
        .from('accounts')
        .select('id,username,display_name,avatar_url')
        .ilike('username', username.trim().replaceFirst('@', ''))
        .maybeSingle();
    if (target == null) throw StateError('User not found.');
    if (me['id'].toString() == target['id'].toString()) {
      throw StateError('You cannot start a conversation with yourself.');
    }

    final targetProfiles = await c
        .from('profiles')
        .select('external_profile_id')
        .eq('account_id', target['id'].toString())
        .eq('is_active', true)
        .not('external_profile_id', 'is', null)
        .limit(1);
    if (targetProfiles.isEmpty) {
      throw StateError('That user has no active profile.');
    }
    final targetProfileId =
        targetProfiles.first['external_profile_id'].toString();

    final friendship = await c
        .from('social_friendships')
        .select('id')
        .eq('status', 'accepted')
        .or(
          'and(requester_account_id.eq.${me['id']},recipient_account_id.eq.${target['id']}),'
          'and(requester_account_id.eq.${target['id']},recipient_account_id.eq.${me['id']})',
        )
        .limit(1);
    if (friendship.isEmpty) {
      throw StateError('You can message people after you become friends.');
    }

    final myMemberships = await c
        .from('social_conversation_members')
        .select('conversation_id')
        .eq('account_id', me['id'].toString())
        .eq('profile_id', profileExternalId);
    for (final item in myMemberships) {
      final conversationId = item['conversation_id'].toString();
      final others = await c
          .from('social_conversation_members')
          .select('account_id,profile_id')
          .eq('conversation_id', conversationId)
          .neq('account_id', me['id'].toString());
      if (others.length == 1 &&
          others.first['account_id'].toString() == target['id'].toString()) {
        final conversation = await c
            .from('social_conversations')
            .select()
            .eq('id', conversationId)
            .maybeSingle();
        if (conversation != null) {
          return {
            'conversation': conversation,
            'created': false,
          };
        }
      }
    }

    final conversation = await c
        .from('social_conversations')
        .insert({
          'kind': 'direct',
          'created_by_account_id': me['id'],
          'created_by_profile_id': profileExternalId,
        })
        .select()
        .single();
    await c.from('social_conversation_members').insert([
      {
        'conversation_id': conversation['id'],
        'account_id': me['id'],
        'profile_id': profileExternalId,
        'role': 'member',
      },
      {
        'conversation_id': conversation['id'],
        'account_id': target['id'],
        'profile_id': targetProfileId,
        'role': 'member',
      },
    ]);
    return {
      'conversation': conversation,
      'created': true,
      'target': target,
    };
  }

  Future<Map<String, dynamic>> createSocialGroupConversation({
    required String accountExternalId,
    required String profileExternalId,
    required String title,
    required List<String> usernames,
  }) async {
    final c = _db;
    if (c == null)
      throw StateError('Social features require Supabase persistence.');
    final me = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id', accountExternalId)
        .single();
    final cleanNames = usernames
        .map((name) => name.trim().replaceFirst('@', ''))
        .where((name) => name.isNotEmpty)
        .map((name) => name.toLowerCase())
        .toSet()
        .toList();
    if (cleanNames.length < 2 || cleanNames.length > 50) {
      throw ArgumentError('Choose between 2 and 50 friends for a group chat.');
    }
    final members = <Map<String, dynamic>>[
      {
        'account_id': me['id'],
        'profile_id': profileExternalId,
        'role': 'owner',
      },
    ];
    for (final username in cleanNames) {
      final target = await c
          .from('accounts')
          .select('id')
          .ilike('username', username)
          .maybeSingle();
      if (target == null) throw StateError('User @$username was not found.');
      if (target['id'].toString() == me['id'].toString()) continue;
      final profiles = await c
          .from('profiles')
          .select('external_profile_id')
          .eq('account_id', target['id'].toString())
          .eq('is_active', true)
          .not('external_profile_id', 'is', null)
          .limit(1);
      if (profiles.isEmpty)
        throw StateError('User @$username has no active profile.');
      final targetProfile = profiles.first['external_profile_id'].toString();
      final friendship = await c
          .from('social_friendships')
          .select('id')
          .eq('status', 'accepted')
          .or(
            'and(requester_account_id.eq.${me['id']},requester_profile_id.eq.$profileExternalId,recipient_account_id.eq.${target['id']},recipient_profile_id.eq.$targetProfile),'
            'and(requester_account_id.eq.${target['id']},requester_profile_id.eq.$targetProfile,recipient_account_id.eq.${me['id']},recipient_profile_id.eq.$profileExternalId)',
          )
          .limit(1);
      if (friendship.isEmpty) {
        throw StateError(
            'You can add @$username to a group after becoming friends.');
      }
      members.add({
        'account_id': target['id'],
        'profile_id': targetProfile,
        'role': 'member',
      });
    }
    if (members.length < 3) {
      throw ArgumentError('A group chat needs at least two other people.');
    }
    final conversation = await c
        .from('social_conversations')
        .insert({
          'kind': 'group',
          'title': title.trim().isEmpty
              ? 'Group chat'
              : title.trim().substring(0, min(100, title.trim().length)),
          'created_by_account_id': me['id'],
          'created_by_profile_id': profileExternalId,
        })
        .select()
        .single();
    await c.from('social_conversation_members').insert([
      for (final member in members)
        {
          ...member,
          'conversation_id': conversation['id'],
        },
    ]);
    return {'conversation': conversation, 'created': true};
  }

  Future<Map<String, dynamic>> setSocialGroupSendPolicy({
    required String accountExternalId,
    required String profileExternalId,
    required String conversationId,
    required String policy,
  }) async {
    if (!{'all_members', 'admins_only'}.contains(policy)) {
      throw ArgumentError('Choose a valid group message policy.');
    }
    final c = _db;
    if (c == null)
      throw StateError('Social features require Supabase persistence.');
    final me = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id', accountExternalId)
        .single();
    final membership = await c
        .from('social_conversation_members')
        .select('role')
        .eq('conversation_id', conversationId)
        .eq('account_id', me['id'].toString())
        .eq('profile_id', profileExternalId)
        .maybeSingle();
    if (membership == null ||
        !{'owner', 'moderator'}.contains(membership['role'])) {
      throw StateError('Only a group admin can change who may send messages.');
    }
    return Map<String, dynamic>.from(await c
        .from('social_conversations')
        .update({'send_policy': policy})
        .eq('id', conversationId)
        .eq('kind', 'group')
        .select()
        .single());
  }

  Future<Map<String, dynamic>> loadSocialConversation({
    required String accountExternalId,
    required String profileExternalId,
    required String conversationId,
    String? after,
  }) async {
    final c = _db;
    if (c == null) {
      throw StateError('Social features require Supabase persistence.');
    }
    final me = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id', accountExternalId)
        .single();

    final membership = await c
        .from('social_conversation_members')
        .select('last_read_at,last_delivered_at')
        .eq('conversation_id', conversationId)
        .eq('account_id', me['id'].toString())
        .eq('profile_id', profileExternalId)
        .maybeSingle();
    if (membership == null) throw StateError('Conversation not found.');

    final conversation = await c
        .from('social_conversations')
        .select()
        .eq('id', conversationId)
        .maybeSingle();
    if (conversation == null) throw StateError('Conversation not found.');

    final afterTime = after == null ? null : DateTime.tryParse(after);
    final messageCursor = afterTime
        ?.subtract(const Duration(milliseconds: 1))
        .toUtc()
        .toIso8601String();
    final messages = messageCursor == null
        ? await c
            .from('social_messages')
            .select()
            .eq('conversation_id', conversationId)
            .isFilter('deleted_at', null)
            .order('created_at', ascending: true)
            .limit(500)
        : await c
            .from('social_messages')
            .select()
            .eq('conversation_id', conversationId)
            .gt('created_at', messageCursor)
            .isFilter('deleted_at', null)
            .order('created_at', ascending: true)
            .limit(500);

    final members = await c
        .from('social_conversation_members')
        .select(
          'account_id,profile_id,role,last_read_at,last_delivered_at,chat_background_color,chat_background_image_path',
        )
        .eq('conversation_id', conversationId);

    final people = <Map<String, dynamic>>[];
    for (final member in members) {
      final person = await c
          .from('accounts')
          .select('username,display_name,avatar_url')
          .eq('id', member['account_id'].toString())
          .maybeSingle();
      if (person != null) {
        final presence = await c
            .from('social_profile_presence')
            .select(
              'availability,activity_type,activity_text,nickname,last_seen_at',
                                    )
            .eq('account_id', member['account_id'].toString())
            .eq('profile_id', member['profile_id'].toString())
            .maybeSingle();

        people.add({
          ...Map<String, dynamic>.from(person),
          'accountId': member['account_id'],
          'profileId': member['profile_id'],
          'role': member['role'],
          'lastReadAt': member['last_read_at'],
          'lastDeliveredAt': member['last_delivered_at'],
          'presenceStatus': presence?['availability'] ?? 'away',
          'activityType': presence?['activity_type'],
          'activityText': presence?['activity_text'],
          'nickname': presence?['nickname'],
          'lastSeenAt': presence?['last_seen_at'],
          if (member['account_id'].toString() == me['id'].toString())
            'chatBackgroundColor': member['chat_background_color'],
          if (member['account_id'].toString() == me['id'].toString())
            'chatBackgroundImagePath': member['chat_background_image_path'],
          'isSelf': member['account_id'].toString() == me['id'].toString(),
        });
      }
    }

    final readAt = DateTime.now().toUtc().toIso8601String();
    await c
        .from('social_conversation_members')
        .update({'last_read_at': readAt, 'last_delivered_at': readAt})
        .eq('conversation_id', conversationId)
        .eq('account_id', me['id'].toString());
    for (final person in people) {
      if (person['isSelf'] == true) {
        person['lastReadAt'] = readAt;
        person['lastDeliveredAt'] = readAt;
        final backgroundPath =
            person['chatBackgroundImagePath']?.toString();
        if (backgroundPath != null && backgroundPath.isNotEmpty) {
          final ownerPrefix =
              '${me['id']}/${Uri.encodeComponent(profileExternalId)}/';
          if (!backgroundPath.startsWith(ownerPrefix) ||
              backgroundPath.contains('..')) {
            throw StateError('Chat background image is invalid.');
          }
          person['chatBackgroundImageUrl'] = await c.storage
              .from(_socialPhotoBucket)
              .createSignedUrl(backgroundPath, 600);
        }
      }
    }

    final visibleMessages = <Map<String, dynamic>>[];
    for (final item in messages) {
      final message = Map<String, dynamic>.from(item);
      message['isMine'] =
          message['sender_account_id'].toString() == me['id'].toString() &&
              message['sender_profile_id'].toString() == profileExternalId;
      if (message['view_once'] == true && message['isMine'] != true) {
        final viewed = await c
            .from('social_message_views')
            .select('message_id')
            .eq('message_id', message['id'].toString())
            .eq('account_id', me['id'].toString())
            .eq('profile_id', profileExternalId)
            .limit(1);
        message['media_reference'] = {
          if (message['media_reference'] is Map)
            ...Map<String, dynamic>.from(message['media_reference'] as Map),
          'expired': viewed.isNotEmpty,
          'requiresView': viewed.isEmpty,
        };
      } else {
        await _attachSocialMedia(message);
      }
      visibleMessages.add(message);
    }

    final pollIds = <String>[];
    for (final message in visibleMessages) {
      final reference = message['media_reference'];
      if (reference is Map && reference['type'] == 'poll') {
        final pollId = reference['pollId']?.toString();
        if (pollId != null && pollId.isNotEmpty) pollIds.add(pollId);
      }
    }
    for (final pollId in pollIds) {
      final poll = await c
          .from('social_chat_polls')
          .select()
          .eq('id', pollId)
          .maybeSingle();
      if (poll == null) continue;
      final votes = await c
          .from('social_chat_poll_votes')
          .select('option_index,account_id,profile_id')
          .eq('poll_id', pollId);
      final pollData = Map<String, dynamic>.from(poll);
      pollData['voteCounts'] = List<int>.generate(
        (poll['options'] as List? ?? const []).length,
        (index) => votes.where((vote) => vote['option_index'] == index).length,
      );
      pollData['myVote'] = votes
          .where((vote) =>
              vote['account_id'].toString() == me['id'].toString() &&
              vote['profile_id'].toString() == profileExternalId)
          .map((vote) => vote['option_index'])
          .firstOrNull;
      for (final message in visibleMessages) {
        final reference = message['media_reference'];
        if (reference is Map && reference['pollId']?.toString() == pollId) {
          message['poll'] = pollData;
        }
      }
    }

    final messageIds =
        visibleMessages.map((message) => message['id'].toString()).toList();
    if (messageIds.isNotEmpty) {
      final reactions = await c
          .from('social_message_reactions')
          .select('message_id,reaction,account_id,profile_id')
          .inFilter('message_id', messageIds);
      for (final message in visibleMessages) {
        final messageReactions = reactions.where((reaction) =>
            reaction['message_id'].toString() == message['id'].toString());
        final ownReactions = reactions
            .where((reaction) =>
                reaction['message_id'].toString() == message['id'].toString() &&
                reaction['account_id'].toString() == me['id'].toString() &&
                reaction['profile_id'].toString() == profileExternalId)
            .map((reaction) => reaction['reaction'].toString())
            .toList();
        message['reactions'] = ownReactions;
        final summary = <String, int>{};
        for (final reaction in messageReactions) {
          final emoji = reaction['reaction'].toString();
          summary[emoji] = (summary[emoji] ?? 0) + 1;
        }
        message['reactionSummary'] = summary;
        message['reactionCount'] = messageReactions.length;
      }
    }

    final typingRows = await c
        .from('social_conversation_typing')
        .select('account_id,profile_id')
        .eq('conversation_id', conversationId)
        .gt('typing_until', DateTime.now().toUtc().toIso8601String())
        .neq('account_id', me['id'].toString());
    final typingMembers = <Map<String, dynamic>>[];
    for (final typingRow in typingRows) {
      final person = people.firstWhere(
        (member) =>
            member['accountId'].toString() ==
                typingRow['account_id'].toString() &&
            member['profileId'].toString() ==
                typingRow['profile_id'].toString(),
        orElse: () => <String, dynamic>{},
      );
      if (person.isNotEmpty) typingMembers.add(person);
    }

    return {
      'conversation': conversation,
      'members': people,
      'messages': visibleMessages,
      'typingMembers': typingMembers,
    };
  }

  Future<void> setSocialConversationTyping({
    required String accountExternalId,
    required String profileExternalId,
    required String conversationId,
    required bool isTyping,
  }) async {
    final c = _db;
    if (c == null) {
      throw StateError('Social features require Supabase persistence.');
    }
    final me = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id', accountExternalId)
        .single();
    final membership = await c
        .from('social_conversation_members')
        .select('conversation_id')
        .eq('conversation_id', conversationId)
        .eq('account_id', me['id'].toString())
        .eq('profile_id', profileExternalId)
        .maybeSingle();
    if (membership == null) throw StateError('Conversation not found.');

    final now = DateTime.now().toUtc();
    await c.from('social_conversation_typing').upsert({
      'conversation_id': conversationId,
      'account_id': me['id'],
      'profile_id': profileExternalId,
      'typing_until': (isTyping ? now.add(const Duration(seconds: 8)) : now)
          .toIso8601String(),
    }, onConflict: 'conversation_id,account_id,profile_id');
  }

  Future<void> setSocialProfilePresence({
    required String accountExternalId,
    required String profileExternalId,
    String? availability,
    String? activityType,
    String? activityText,
    String? nickname,
    bool clearActivity = false,
    bool clearNickname = false,
  }) async {
    final c = _db;
    if (c == null) {
      throw StateError('Social features require Supabase persistence.');
    }
    final account = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id', accountExternalId)
        .single();
    final accountId = account['id'].toString();
    final profile = await c
        .from('profiles')
        .select('external_profile_id')
        .eq('account_id', accountId)
        .eq('external_profile_id', profileExternalId)
        .eq('is_active', true)
        .maybeSingle();
    if (profile == null) throw StateError('Profile not found.');

    if (availability != null &&
        !{'active', 'away', 'busy'}.contains(availability)) {
      throw ArgumentError('Invalid presence status.');
    }
    if (activityType != null &&
        !{'watching', 'listening'}.contains(activityType)) {
      throw ArgumentError('Invalid activity type.');
    }
    final cleanActivity = activityText?.trim();
    if (cleanActivity != null && cleanActivity.length > 160) {
      throw ArgumentError('Activity text must be 160 characters or fewer.');
    }
    final cleanNickname = nickname?.trim();
    if (cleanNickname != null && cleanNickname.length > 48) {
      throw ArgumentError('Nicknames must be 48 characters or fewer.');
    }

    final existing = await c
        .from('social_profile_presence')
        .select(
          'availability,activity_type,activity_text,nickname',
        )
        .eq('account_id', accountId)
        .eq('profile_id', profileExternalId)
        .maybeSingle();
    final now = DateTime.now().toUtc().toIso8601String();
    await c.from('social_profile_presence').upsert({
      'account_id': accountId,
      'profile_id': profileExternalId,
      'availability': availability ?? existing?['availability'] ?? 'active',
      'activity_type': clearActivity
          ? null
          : activityType ?? existing?['activity_type'],
      'activity_text': clearActivity
          ? null
          : cleanActivity ?? existing?['activity_text'],
      'nickname': clearNickname ? null : cleanNickname ?? existing?['nickname'],
      'last_seen_at': now,
      'updated_at': now,
    }, onConflict: 'account_id,profile_id');
  }

  Future<void> setSocialConversationAppearance({
    required String accountExternalId,
    required String profileExternalId,
    required String conversationId,
    String? backgroundColor,
    String? backgroundImagePath,
    bool clearBackgroundColor = false,
    bool clearBackgroundImage = false,
  }) async {
    final c = _db;
    if (c == null) {
      throw StateError('Social features require Supabase persistence.');
    }
    final me = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id', accountExternalId)
        .single();
    final membership = await c
        .from('social_conversation_members')
        .select('conversation_id')
        .eq('conversation_id', conversationId)
        .eq('account_id', me['id'].toString())
        .eq('profile_id', profileExternalId)
        .maybeSingle();
    if (membership == null) throw StateError('Conversation not found.');

    final updates = <String, dynamic>{};
    if (backgroundColor != null) {
      if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(backgroundColor)) {
        throw ArgumentError('Invalid chat background color.');
      }
      updates['chat_background_color'] = backgroundColor.toUpperCase();
    } else if (clearBackgroundColor) {
      updates['chat_background_color'] = null;
    }
    if (backgroundImagePath != null) {
      final ownerPrefix =
          '${me['id']}/${Uri.encodeComponent(profileExternalId)}/';
      if (!backgroundImagePath.startsWith(ownerPrefix) ||
          backgroundImagePath.contains('..') ||
          backgroundImagePath.length > 512) {
        throw ArgumentError('Chat background image does not belong to profile.');
      }
      updates['chat_background_image_path'] = backgroundImagePath;
    } else if (clearBackgroundImage) {
      updates['chat_background_image_path'] = null;
    }
    if (updates.isEmpty) return;
    await c
        .from('social_conversation_members')
        .update(updates)
        .eq('conversation_id', conversationId)
        .eq('account_id', me['id'].toString())
        .eq('profile_id', profileExternalId);
  }

  Future<Map<String, dynamic>> forwardSocialVideoMessage({
    required String accountExternalId,
    required String profileExternalId,
    required String sourceMessageId,
    required String conversationId,
  }) async {
    final c = _db;
    if (c == null) {
      throw StateError('Social features require Supabase persistence.');
    }
    final me = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id', accountExternalId)
        .single();
    final source = await c
        .from('social_messages')
        .select()
        .eq('id', sourceMessageId)
        .isFilter('deleted_at', null)
        .maybeSingle();
    if (source == null) throw StateError('Video message not found.');

    final sourceMember = await c
        .from('social_conversation_members')
        .select('conversation_id')
        .eq('conversation_id', source['conversation_id'].toString())
        .eq('account_id', me['id'].toString())
        .eq('profile_id', profileExternalId)
        .maybeSingle();
    if (sourceMember == null) {
      throw StateError('You cannot forward this video.');
    }
    final targetMember = await c
        .from('social_conversation_members')
        .select('role')
        .eq('conversation_id', conversationId)
        .eq('account_id', me['id'].toString())
        .eq('profile_id', profileExternalId)
        .maybeSingle();
    if (targetMember == null) throw StateError('Conversation not found.');
    final targetConversation = await c
        .from('social_conversations')
        .select('kind,send_policy')
        .eq('id', conversationId)
        .single();
    if (targetConversation['kind'] == 'group' &&
        targetConversation['send_policy'] == 'admins_only' &&
        !{'owner', 'moderator'}.contains(targetMember['role'])) {
      throw StateError('Only group admins can send messages in this chat.');
    }

    final sourceReference = source['media_reference'];
    if (sourceReference is! Map || sourceReference['type'] != 'video') {
      throw StateError('Only video messages can be forwarded.');
    }
    final reference = Map<String, dynamic>.from(sourceReference);
    final path = (reference['attachmentPath'] ?? reference['photoPath'])
        ?.toString();
    if (path != null && path.isNotEmpty) {
      final ownerAccountId =
          (reference['attachmentOwnerAccountId'] ??
                  source['sender_account_id'])
              .toString();
      final ownerProfileId =
          (reference['attachmentOwnerProfileId'] ??
                  source['sender_profile_id'])
              .toString();
      final ownerPrefix =
          '$ownerAccountId/${Uri.encodeComponent(ownerProfileId)}/';
      if (!path.startsWith(ownerPrefix) || path.contains('..')) {
        throw StateError('Video attachment is unavailable.');
      }
      reference['attachmentOwnerAccountId'] = ownerAccountId;
      reference['attachmentOwnerProfileId'] = ownerProfileId;
    }
    return Map<String, dynamic>.from(
      await c
          .from('social_messages')
          .insert({
            'conversation_id': conversationId,
            'sender_account_id': me['id'],
            'sender_profile_id': profileExternalId,
            'body': source['body']?.toString().trim().isNotEmpty == true
                ? source['body']
                : 'Shared video',
            'message_type': 'video',
            'media_reference': reference,
            'text_format': <String, dynamic>{},
            'view_once': false,
          })
          .select()
          .single(),
    );
  }

  Future<Map<String, dynamic>> forwardSocialVideoPost({
    required String accountExternalId,
    required String profileExternalId,
    required String sourcePostId,
    required String conversationId,
  }) async {
    final c = _db;
    if (c == null) {
    throw StateError('Social features require Supabase persistence.');
    }
    final me = await c
      .from('accounts')
      .select('id')
      .eq('external_account_id', accountExternalId)
      .single();
    final post = await c
      .from('social_posts')
      .select()
      .eq('id', sourcePostId)
      .maybeSingle();
    if (post == null) throw StateError('Video post not found.');

    final authorAccountId = post['author_account_id'].toString();
    final authorProfileId = post['author_profile_id'].toString();
    final isAuthor = authorAccountId == me['id'].toString() &&
      authorProfileId == profileExternalId;
    var canRead = isAuthor;
    if (!canRead && post['visibility'] == 'community') {
    final membership = await c
        .from('social_community_memberships')
        .select('community_id')
        .eq('community_id', post['community_id'].toString())
        .eq('account_id', me['id'].toString())
        .eq('profile_id', profileExternalId)
        .maybeSingle();
    canRead = membership != null;
    } else if (!canRead && post['visibility'] == 'friends') {
    final friendships = await c
        .from('social_friendships')
        .select(
          'requester_account_id,requester_profile_id,recipient_account_id,recipient_profile_id',
        )
        .eq('status', 'accepted');
    canRead = friendships.any((friendship) {
      final requesterIsMe =
          friendship['requester_account_id'].toString() ==
                  me['id'].toString() &&
              friendship['requester_profile_id'].toString() ==
                  profileExternalId;
      final recipientIsAuthor =
          friendship['recipient_account_id'].toString() == authorAccountId &&
              friendship['recipient_profile_id'].toString() ==
                  authorProfileId;
      final recipientIsMe =
          friendship['recipient_account_id'].toString() ==
                  me['id'].toString() &&
              friendship['recipient_profile_id'].toString() ==
                  profileExternalId;
      final requesterIsAuthor =
          friendship['requester_account_id'].toString() == authorAccountId &&
              friendship['requester_profile_id'].toString() ==
                  authorProfileId;
      return (requesterIsMe && recipientIsAuthor) ||
          (recipientIsMe && requesterIsAuthor);
    });
    }
    if (!canRead) throw StateError('You cannot share this post.');

    final targetMember = await c
      .from('social_conversation_members')
      .select('role')
      .eq('conversation_id', conversationId)
      .eq('account_id', me['id'].toString())
      .eq('profile_id', profileExternalId)
      .maybeSingle();
    if (targetMember == null) throw StateError('Conversation not found.');
    final targetConversation = await c
      .from('social_conversations')
      .select('kind,send_policy')
      .eq('id', conversationId)
      .single();
    if (targetConversation['kind'] == 'group' &&
      targetConversation['send_policy'] == 'admins_only' &&
      !{'owner', 'moderator'}.contains(targetMember['role'])) {
    throw StateError('Only group admins can send messages in this chat.');
    }

    final sourceReference = post['media_reference'];
    if (sourceReference is! Map || sourceReference['type'] != 'video') {
    throw StateError('Only video posts can be shared to chats.');
    }
    final reference = Map<String, dynamic>.from(sourceReference);
    final path =
      (reference['attachmentPath'] ?? reference['videoPath'])?.toString();
    if (path != null && path.isNotEmpty) {
    final ownerPrefix =
        '$authorAccountId/${Uri.encodeComponent(authorProfileId)}/';
    if (!path.startsWith(ownerPrefix) || path.contains('..')) {
      throw StateError('Video attachment is unavailable.');
    }
    reference['attachmentPath'] = path;
    reference['attachmentOwnerAccountId'] = authorAccountId;
    reference['attachmentOwnerProfileId'] = authorProfileId;
    }
    return Map<String, dynamic>.from(
    await c
        .from('social_messages')
        .insert({
          'conversation_id': conversationId,
          'sender_account_id': me['id'],
          'sender_profile_id': profileExternalId,
          'body': post['body']?.toString().trim().isNotEmpty == true
              ? post['body']
              : 'Shared video',
          'message_type': 'video',
          'media_reference': reference,
          'text_format': <String, dynamic>{},
          'view_once': false,
        })
        .select()
        .single(),
    );
  }

  Future<Map<String, dynamic>> sendSocialMessage({
    required String accountExternalId,
    required String profileExternalId,
    required String conversationId,
    required String body,
    String? replyToMessageId,
    String messageType = 'text',
    Map<String, dynamic>? mediaReference,
    Map<String, dynamic>? textFormat,
    bool viewOnce = false,
  }) async {
    final c = _db;
    if (c == null) {
      throw StateError('Social features require Supabase persistence.');
    }
    final me = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id', accountExternalId)
        .single();
    final membership = await c
        .from('social_conversation_members')
        .select('conversation_id,role')
        .eq('conversation_id', conversationId)
        .eq('account_id', me['id'].toString())
        .eq('profile_id', profileExternalId)
        .maybeSingle();
    if (membership == null)
      throw StateError('You are not a member of this conversation.');

    final conversation = await c
        .from('social_conversations')
        .select('kind,send_policy')
        .eq('id', conversationId)
        .single();
    if (conversation['kind'] == 'group' &&
        conversation['send_policy'] == 'admins_only' &&
        !{'owner', 'moderator'}.contains(membership['role'])) {
      throw StateError('Only group admins can send messages in this chat.');
    }

    final clean = body.trim();
    if ((clean.isEmpty && mediaReference == null) || clean.length > 4000) {
      throw ArgumentError('Add message text or an attachment.');
    }

    final safeMediaReference = _validateMessageMediaReference(mediaReference,
        accountId: me['id'].toString(), profileId: profileExternalId);
    final safeTextFormat = _validateSocialTextFormat(textFormat);
    return Map<String, dynamic>.from(
      await c
          .from('social_messages')
          .insert({
            'conversation_id': conversationId,
            'sender_account_id': me['id'],
            'sender_profile_id': profileExternalId,
            'body': clean.isEmpty ? ' ' : clean,
            'message_type': messageType,
            'media_reference': safeMediaReference,
            'text_format': safeTextFormat,
            'view_once': viewOnce,
            'reply_to_message_id': replyToMessageId,
          })
          .select()
          .single(),
    );
  }

  Map<String, dynamic> _validateSocialTextFormat(
    Map<String, dynamic>? format,
  ) {
    if (format == null) return <String, dynamic>{};
    if (format.length > 8) throw ArgumentError('Invalid text formatting.');
    const allowedFonts = {
    'Arial',
    'Georgia',
    'Courier New',
    'Times New Roman',
    'Verdana',
    };
    final result = <String, dynamic>{};
    final font = format['fontFamily'];
    if (font is String && allowedFonts.contains(font)) {
    result['fontFamily'] = font;
    } else if (font != null) {
    throw ArgumentError('Unsupported font.');
    }
    final color = format['color'];
    if (color is String && RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(color)) {
    result['color'] = color.toUpperCase();
    } else if (color != null) {
    throw ArgumentError('Invalid text color.');
    }
    for (final key in const [
    'bold',
    'italic',
    'underline',
    'strikeThrough',
    'metallic',
    'spoiler',
    ]) {
    final value = format[key];
    if (value is bool && value) result[key] = value;
    if (value != null && value is! bool) {
      throw ArgumentError('Invalid text formatting.');
    }
    }
    return result;
  }

  Future<Map<String, dynamic>> createSocialChatPoll({
    required String accountExternalId,
    required String profileExternalId,
    required String conversationId,
    required String question,
    required List<String> options,
  }) async {
    final cleanQuestion = question.trim();
    final cleanOptions = options.map((option) => option.trim()).toList();
    if (cleanQuestion.isEmpty ||
        cleanQuestion.length > 500 ||
        cleanOptions.length < 2 ||
        cleanOptions.length > 10 ||
        cleanOptions.any((option) => option.isEmpty || option.length > 200) ||
        cleanOptions.toSet().length != cleanOptions.length) {
      throw ArgumentError('A poll needs a question and 2–10 unique options.');
    }
    final c = _db;
    if (c == null)
      throw StateError('Social features require Supabase persistence.');
    final membership = await _getSocialConversationMembership(
      c,
      accountExternalId: accountExternalId,
      profileExternalId: profileExternalId,
      conversationId: conversationId,
    );
    if (membership['kind'] != 'group') {
      throw StateError('Polls can only be created in group chats.');
    }
    final message = await sendSocialMessage(
      accountExternalId: accountExternalId,
      profileExternalId: profileExternalId,
      conversationId: conversationId,
      body: cleanQuestion,
      messageType: 'poll',
    );
    final poll = await c
        .from('social_chat_polls')
        .insert({
          'message_id': message['id'],
          'question': cleanQuestion,
          'options': cleanOptions,
        })
        .select()
        .single();
    await c.from('social_messages').update({
      'media_reference': {'type': 'poll', 'pollId': poll['id'].toString()},
    }).eq('id', message['id'].toString());
    return {'message': message, 'poll': poll};
  }

  Future<Map<String, dynamic>> voteSocialChatPoll({
    required String accountExternalId,
    required String profileExternalId,
    required String conversationId,
    required String pollId,
    required int optionIndex,
  }) async {
    final c = _db;
    if (c == null)
      throw StateError('Social features require Supabase persistence.');
    final membership = await _getSocialConversationMembership(
      c,
      accountExternalId: accountExternalId,
      profileExternalId: profileExternalId,
      conversationId: conversationId,
    );
    final poll = await c
        .from('social_chat_polls')
        .select('id,options,closes_at')
        .eq('id', pollId)
        .maybeSingle();
    if (poll == null) throw StateError('Poll not found.');
    final options = poll['options'] as List? ?? const [];
    if (membership['kind'] != 'group' ||
        optionIndex < 0 ||
        optionIndex >= options.length) {
      throw ArgumentError('Invalid poll option.');
    }
    final closesAt = DateTime.tryParse(poll['closes_at']?.toString() ?? '');
    if (closesAt != null && closesAt.isBefore(DateTime.now().toUtc())) {
      throw StateError('This poll is closed.');
    }
    return Map<String, dynamic>.from(await c
        .from('social_chat_poll_votes')
        .upsert({
          'poll_id': pollId,
          'account_id': membership['accountId'],
          'profile_id': profileExternalId,
          'option_index': optionIndex,
        }, onConflict: 'poll_id,account_id,profile_id')
        .select()
        .single());
  }

  Future<Map<String, dynamic>> _getSocialConversationMembership(
    SupabaseClient client, {
    required String accountExternalId,
    required String profileExternalId,
    required String conversationId,
  }) async {
    final account = await client
        .from('accounts')
        .select('id')
        .eq('external_account_id', accountExternalId)
        .single();
    final member = await client
        .from('social_conversation_members')
        .select('role')
        .eq('conversation_id', conversationId)
        .eq('account_id', account['id'].toString())
        .eq('profile_id', profileExternalId)
        .maybeSingle();
    if (member == null)
      throw StateError('You are not a member of this conversation.');
    final conversation = await client
        .from('social_conversations')
        .select('kind')
        .eq('id', conversationId)
        .maybeSingle();
    if (conversation == null) throw StateError('Conversation not found.');
    return {
      'kind': conversation['kind'],
      'role': member['role'],
      'accountId': account['id'],
    };
  }

  Map<String, dynamic>? _validateMessageMediaReference(
    Map<String, dynamic>? reference, {
    required String accountId,
    required String profileId,
  }) {
    if (reference == null) return null;
    if (reference.length > 12)
      throw ArgumentError('Invalid message attachment.');
    final type = reference['type']?.toString();
    const allowed = {
      'photo',
      'image',
      'video',
      'voice',
      'audio',
      'gif',
      'sticker',
      'link',
      'product',
      'recommendation',
      'friend_invite',
      'poll',
    };
    if (!allowed.contains(type))
      throw ArgumentError('Unsupported message type.');
    final path =
        (reference['attachmentPath'] ?? reference['photoPath'])?.toString();
    if (path != null && path.isNotEmpty) {
      final ownerPrefix = '$accountId/${Uri.encodeComponent(profileId)}/';
      if (!path.startsWith(ownerPrefix) ||
          path.contains('..') ||
          path.length > 512) {
        throw ArgumentError('Attachment does not belong to this profile.');
      }
    }
    final result = <String, dynamic>{'type': type};
    if (path != null && path.isNotEmpty) {
      result['attachmentPath'] = path;
    }
    for (final key in const [
      'url',
      'title',
      'description',
      'mimeType',
      'fileName',
      'productId',
      'productUrl',
      'mediaId',
      'mediaType',
      'pollId',
      'username',
      'viewOnce',
      'emoji',
    ]) {
      final value = reference[key];
      if (value is String && value.trim().isNotEmpty) {
        result[key] = value.trim().substring(0, min(1000, value.trim().length));
      } else if (value is bool && key == 'viewOnce') {
        result[key] = value;
      }
    }
    return result;
  }

  Future<Map<String, dynamic>> reactToSocialMessage({
    required String accountExternalId,
    required String profileExternalId,
    required String messageId,
    required String reaction,
  }) async {
    final c = _db;
    if (c == null)
      throw StateError('Social features require Supabase persistence.');
    final me = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id', accountExternalId)
        .single();
    final message = await c
        .from('social_messages')
        .select('conversation_id')
        .eq('id', messageId)
        .maybeSingle();
    if (message == null) throw StateError('Message not found.');
    final membership = await c
        .from('social_conversation_members')
        .select('conversation_id')
        .eq('conversation_id', message['conversation_id'].toString())
        .eq('account_id', me['id'].toString())
        .eq('profile_id', profileExternalId)
        .maybeSingle();
    if (membership == null)
      throw StateError('You cannot react to this message.');
    if (reaction.trim().toLowerCase() == 'remove') {
      await c
          .from('social_message_reactions')
          .delete()
          .eq('message_id', messageId)
          .eq('account_id', me['id'].toString())
          .eq('profile_id', profileExternalId);
      return {'removed': true, 'messageId': messageId};
    }

    return Map<String, dynamic>.from(await c
        .from('social_message_reactions')
        .upsert({
          'message_id': messageId,
          'account_id': me['id'],
          'profile_id': profileExternalId,
          'reaction': reaction.trim(),
        }, onConflict: 'message_id,account_id,profile_id')
        .select()
        .single());
  }

  Future<Map<String, dynamic>> viewSocialOnceMessage({
    required String accountExternalId,
    required String profileExternalId,
    required String messageId,
  }) async {
    final c = _db;
    if (c == null)
      throw StateError('Social features require Supabase persistence.');
    final me = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id', accountExternalId)
        .single();
    final message = await c
        .from('social_messages')
        .select()
        .eq('id', messageId)
        .maybeSingle();
    if (message == null || message['view_once'] != true) {
      throw StateError('View-once message not found.');
    }
    final membership = await c
        .from('social_conversation_members')
        .select('account_id')
        .eq('conversation_id', message['conversation_id'].toString())
        .eq('account_id', me['id'].toString())
        .eq('profile_id', profileExternalId)
        .maybeSingle();
    if (membership == null) throw StateError('You cannot view this message.');
    if (message['sender_account_id'].toString() == me['id'].toString() &&
        message['sender_profile_id'].toString() == profileExternalId) {
      throw StateError('You cannot open your own view-once message.');
    }
    final previous = await c
        .from('social_message_views')
        .select('message_id')
        .eq('message_id', messageId)
        .eq('account_id', me['id'].toString())
        .eq('profile_id', profileExternalId)
        .limit(1);
    if (previous.isNotEmpty) return {'expired': true};
    final result = Map<String, dynamic>.from(message);
    result['isMine'] = false;
    final reference = message['media_reference'];
    if (reference is! Map) throw StateError('View-once media is unavailable.');
    final path =
        (reference['attachmentPath'] ?? reference['photoPath'])?.toString();
    if (path == null || path.isEmpty) {
      throw StateError('View-once media is unavailable.');
    }
    final ownerPrefix =
        '${message['sender_account_id']}/${Uri.encodeComponent(message['sender_profile_id'].toString())}/';
    if (!path.startsWith(ownerPrefix) || path.contains('..')) {
      throw StateError('View-once media is unavailable.');
    }
    final signedUrl =
        await c.storage.from(_socialPhotoBucket).createSignedUrl(path, 60);
    await c.from('social_message_views').insert({
      'message_id': messageId,
      'account_id': me['id'],
      'profile_id': profileExternalId,
    });
    final safeReference = Map<String, dynamic>.from(reference);
    if (safeReference['type'] == 'photo' || safeReference['type'] == 'image') {
      safeReference['imageUrl'] = signedUrl;
    } else if (safeReference['type'] == 'video') {
      safeReference['videoUrl'] = signedUrl;
    } else {
      safeReference['audioUrl'] = signedUrl;
    }
    result['mediaReference'] = safeReference;
    return {'message': result, 'expired': false};
  }

  Future<Map<String, dynamic>> reactToSocialPost({
    required String accountExternalId,
    required String profileExternalId,
    required String postId,
    required String reaction,
  }) async {
    final c = _db;
    if (c == null)
      throw StateError('Social features require Supabase persistence.');
    final me = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id', accountExternalId)
        .single();
    final post = await c
        .from('social_posts')
        .select('author_account_id,author_profile_id,community_id,visibility')
        .eq('id', postId)
        .maybeSingle();
    if (post == null) throw StateError('Post not found.');
    if (!await _canAccessSocialPost(
      c,
      accountId: me['id'].toString(),
      profileId: profileExternalId,
      postId: postId,
      post: Map<String, dynamic>.from(post),
    )) {
      throw StateError('You cannot react to this post.');
    }
    if (reaction.trim().toLowerCase() == 'remove') {
      await c
          .from('social_post_reactions')
          .delete()
          .eq('post_id', postId)
          .eq('account_id', me['id'].toString())
          .eq('profile_id', profileExternalId);
      return {'removed': true, 'postId': postId};
    }
    return Map<String, dynamic>.from(await c
        .from('social_post_reactions')
        .upsert({
          'post_id': postId,
          'account_id': me['id'],
          'profile_id': profileExternalId,
          'reaction': reaction.trim(),
        }, onConflict: 'post_id,account_id,profile_id')
        .select()
        .single());
  }

  Future<Map<String, dynamic>> commentOnSocialPost({
    required String accountExternalId,
    required String profileExternalId,
    required String postId,
    required String body,
  }) async {
    final c = _db;
    if (c == null)
      throw StateError('Social features require Supabase persistence.');
    final me = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id', accountExternalId)
        .single();
    final post = await c
        .from('social_posts')
        .select('author_account_id,author_profile_id,community_id,visibility')
        .eq('id', postId)
        .maybeSingle();
    if (post == null) throw StateError('Post not found.');
    if (!await _canAccessSocialPost(
      c,
      accountId: me['id'].toString(),
      profileId: profileExternalId,
      postId: postId,
      post: Map<String, dynamic>.from(post),
    )) {
      throw StateError('You cannot comment on this post.');
    }
    final clean = body.trim();
    if (clean.isEmpty || clean.length > 2000)
      throw ArgumentError('Comment must contain 1–2000 characters.');
    return Map<String, dynamic>.from(await c
        .from('social_post_comments')
        .insert({
          'post_id': postId,
          'author_account_id': me['id'],
          'author_profile_id': profileExternalId,
          'body': clean,
        })
        .select()
        .single());
  }

  Future<bool> _canAccessSocialPost(
    SupabaseClient client, {
    required String accountId,
    required String profileId,
    required String postId,
    required Map<String, dynamic> post,
  }) async {
    final authorAccountId = post['author_account_id']?.toString() ?? '';
    final authorProfileId = post['author_profile_id']?.toString() ?? '';
    if (authorAccountId == accountId && authorProfileId == profileId) {
      return true;
    }
    if (post['visibility'] == 'community') {
      final links = await client
          .from('social_post_communities')
          .select('community_id')
          .eq('post_id', postId);
      final communityIds = <String>{
        if (post['community_id'] != null) post['community_id'].toString(),
        ...links.map((row) => row['community_id'].toString()),
      };
      if (communityIds.isEmpty) return false;
      final memberships = await client
          .from('social_community_memberships')
          .select('community_id')
          .eq('account_id', accountId)
          .eq('profile_id', profileId)
          .inFilter('community_id', communityIds.toList());
      return memberships.isNotEmpty;
    }

    final outgoing = await client
        .from('social_friendships')
        .select('id')
        .eq('status', 'accepted')
        .eq('requester_account_id', accountId)
        .eq('requester_profile_id', profileId)
        .eq('recipient_account_id', authorAccountId)
        .eq('recipient_profile_id', authorProfileId)
        .maybeSingle();
    if (outgoing != null) return true;
    final incoming = await client
        .from('social_friendships')
        .select('id')
        .eq('status', 'accepted')
        .eq('requester_account_id', authorAccountId)
        .eq('requester_profile_id', authorProfileId)
        .eq('recipient_account_id', accountId)
        .eq('recipient_profile_id', profileId)
        .maybeSingle();
    return incoming != null;
  }

  Future<Map<String, dynamic>> _getSocialStoryForInteraction({
    required dynamic client,
    required String accountId,
    required String profileExternalId,
    required String storyId,
    required bool allowExpiredForOwner,
  }) async {
    final row = await client
        .from('social_stories')
        .select()
        .eq('id', storyId)
        .maybeSingle();
    if (row == null) throw StateError('Story not found.');
    final story = Map<String, dynamic>.from(row);
    final authorAccountId = story['author_account_id'].toString();
    final authorProfileId = story['author_profile_id'].toString();
    final mine = authorAccountId == accountId && authorProfileId == profileExternalId;
    if (!mine && !allowExpiredForOwner) {
      final expires = DateTime.tryParse(story['expires_at']?.toString() ?? '');
      if (expires != null && !expires.toUtc().isAfter(DateTime.now().toUtc())) {
        throw StateError('This Story has expired.');
      }
    }
    if (mine) return story;
    var allowed = false;
    if (story['visibility'] == 'community') {
      final communityId = story['community_id']?.toString();
      if (communityId != null && communityId.isNotEmpty) {
        final membership = await client
            .from('social_community_memberships')
            .select('community_id')
            .eq('community_id', communityId)
            .eq('account_id', accountId)
            .eq('profile_id', profileExternalId)
            .maybeSingle();
        allowed = membership != null;
      }
    } else {
      final friendship = await client
          .from('social_friendships')
          .select('id')
          .eq('status', 'accepted')
          .or(
            'and(requester_account_id.eq.$accountId,recipient_account_id.eq.$authorAccountId),'
            'and(requester_account_id.eq.$authorAccountId,recipient_account_id.eq.$accountId)',
          )
          .limit(1);
      allowed = friendship.isNotEmpty;
    }
    if (!allowed) throw StateError('You cannot interact with this Story.');
    return story;
  }

  Future<Map<String, dynamic>> recordSocialStoryView({
    required String accountExternalId,
    required String profileExternalId,
    required String storyId,
  }) async {
    final c = _db;
    if (c == null) throw StateError('Social features require Supabase persistence.');
    final me = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id', accountExternalId)
        .single();
    final story = await _getSocialStoryForInteraction(
      client: c,
      accountId: me['id'].toString(),
      profileExternalId: profileExternalId,
      storyId: storyId,
      allowExpiredForOwner: false,
    );
    final current = await c
        .from('social_story_views')
        .select('view_count,first_viewed_at')
        .eq('story_id', story['id'].toString())
        .eq('viewer_account_id', me['id'].toString())
        .eq('viewer_profile_id', profileExternalId)
        .maybeSingle();
    final count = (current?['view_count'] as num?)?.toInt() ?? 0;
    final now = DateTime.now().toUtc().toIso8601String();
    final saved = await c
        .from('social_story_views')
        .upsert({
          'story_id': story['id'],
          'viewer_account_id': me['id'],
          'viewer_profile_id': profileExternalId,
          'view_count': count + 1,
          'first_viewed_at': current?['first_viewed_at'] ?? now,
          'last_viewed_at': now,
        }, onConflict: 'story_id,viewer_account_id,viewer_profile_id')
        .select()
        .single();
    return Map<String, dynamic>.from(saved);
  }

  Future<Map<String, dynamic>> getSocialStoryInsights({
    required String accountExternalId,
    required String profileExternalId,
    required String storyId,
  }) async {
    final c = _db;
    if (c == null) throw StateError('Social features require Supabase persistence.');
    final me = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id', accountExternalId)
        .single();
    final story = await _getSocialStoryForInteraction(
      client: c,
      accountId: me['id'].toString(),
      profileExternalId: profileExternalId,
      storyId: storyId,
      allowExpiredForOwner: true,
    );
    if (story['author_account_id'].toString() != me['id'].toString() ||
        story['author_profile_id'].toString() != profileExternalId) {
      throw StateError('Only the Story owner can view Story analytics.');
    }
    final views = await c
        .from('social_story_views')
        .select('viewer_account_id,viewer_profile_id,view_count,last_viewed_at')
        .eq('story_id', storyId)
        .order('view_count', ascending: false);
    final reactions = await c
        .from('social_story_reactions')
        .select('account_id,profile_id,reaction')
        .eq('story_id', storyId);
    final reactionKeys = <String>{
      for (final row in reactions) '${row['account_id']}:${row['profile_id']}',
    };
    final accountIds = views.map((row) => row['viewer_account_id'].toString()).toSet();
    final accounts = <String, Map<String, dynamic>>{};
    for (final accountId in accountIds) {
      final account = await c
          .from('accounts')
          .select('id,username,display_name,avatar_url')
          .eq('id', accountId)
          .maybeSingle();
      if (account != null) accounts[accountId] = Map<String, dynamic>.from(account);
    }
    final viewers = <Map<String, dynamic>>[];
    for (final row in views) {
      final accountId = row['viewer_account_id'].toString();
      final profileId = row['viewer_profile_id'].toString();
      final account = accounts[accountId] ?? <String, dynamic>{};
      viewers.add({
        'accountId': accountId,
        'profileId': profileId,
        'username': account['username'],
        'displayName': account['display_name'] ?? account['username'] ?? 'User',
        'avatarUrl': account['avatar_url'],
        'viewCount': (row['view_count'] as num?)?.toInt() ?? 0,
        'lastViewedAt': row['last_viewed_at'],
        'liked': reactionKeys.contains('$accountId:$profileId'),
      });
    }
    final totalViews = viewers.fold<int>(0, (sum, item) => sum + ((item['viewCount'] as num?)?.toInt() ?? 0));
    return {
      'storyId': storyId,
      'totalViews': totalViews,
      'uniqueViewers': viewers.length,
      'likes': reactions.length,
      'viewers': viewers,
    };
  }

  Future<Map<String, dynamic>> reactToSocialStory({
    required String accountExternalId,
    required String profileExternalId,
    required String storyId,
    required String reaction,
  }) async {
    final c = _db;
    if (c == null) throw StateError('Social features require Supabase persistence.');
    final me = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id', accountExternalId)
        .single();
    await _getSocialStoryForInteraction(
      client: c,
      accountId: me['id'].toString(),
      profileExternalId: profileExternalId,
      storyId: storyId,
      allowExpiredForOwner: false,
    );
    if (reaction.trim().toLowerCase() == 'remove') {
      await c
          .from('social_story_reactions')
          .delete()
          .eq('story_id', storyId)
          .eq('account_id', me['id'].toString())
          .eq('profile_id', profileExternalId);
      return {'removed': true, 'storyId': storyId};
    }
    return Map<String, dynamic>.from(await c
        .from('social_story_reactions')
        .upsert({
          'story_id': storyId,
          'account_id': me['id'],
          'profile_id': profileExternalId,
          'reaction': reaction.trim(),
        }, onConflict: 'story_id,account_id,profile_id')
        .select()
        .single());
  }

  Future<Map<String, dynamic>> voteSocialStoryPoll({
    required String accountExternalId,
    required String profileExternalId,
    required String storyId,
    required int optionIndex,
  }) async {
    final c = _db;
    if (c == null) throw StateError('Social features require Supabase persistence.');
    final me = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id', accountExternalId)
        .single();
    final story = await _getSocialStoryForInteraction(
      client: c,
      accountId: me['id'].toString(),
      profileExternalId: profileExternalId,
      storyId: storyId,
      allowExpiredForOwner: false,
    );
    final reference = story['media_reference'];
    final storyData = reference is Map ? reference['storyData'] : null;
    final poll = storyData is Map ? storyData['poll'] : null;
    final options = poll is Map ? poll['options'] : null;
    if (options is! List || optionIndex < 0 || optionIndex >= options.length) {
      throw ArgumentError('That Story poll option is not available.');
    }
    final vote = await c
        .from('social_story_poll_votes')
        .upsert({
          'story_id': storyId,
          'account_id': me['id'],
          'profile_id': profileExternalId,
          'option_index': optionIndex,
        }, onConflict: 'story_id,account_id,profile_id')
        .select()
        .single();
    return Map<String, dynamic>.from(vote);
  }

  Future<Map<String, dynamic>> reshareSocialStory({
    required String accountExternalId,
    required String profileExternalId,
    required String storyId,
    int expiresInHours = 24,
  }) async {
    final c = _db;
    if (c == null) throw StateError('Social features require Supabase persistence.');
    if (expiresInHours < 24 || expiresInHours > 168) throw ArgumentError('Story duration must be between 24 and 168 hours.');
    final me = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id', accountExternalId)
        .single();
    final original = await _getSocialStoryForInteraction(
      client: c,
      accountId: me['id'].toString(),
      profileExternalId: profileExternalId,
      storyId: storyId,
      allowExpiredForOwner: false,
    );
    final author = await c
        .from('accounts')
        .select('username,display_name')
        .eq('id', original['author_account_id'].toString())
        .maybeSingle();

    final rawReference = original['media_reference'];

    final reference = rawReference is Map
        ? Map<String, dynamic>.from(rawReference)
        : <String, dynamic>{};

    reference['attachmentOwnerAccountId'] =
        original['author_account_id'].toString();

    reference['attachmentOwnerProfileId'] =
        original['author_profile_id'].toString();

    final storyData = reference['storyData'] is Map
        ? Map<String, dynamic>.from(reference['storyData'])
        : <String, dynamic>{};
    storyData['originalStoryId'] = storyId;
    storyData['originalAuthor'] = author?['username'] ?? author?['display_name'] ?? 'Friend';
    reference['storyData'] = storyData;
    return Map<String, dynamic>.from(await c
        .from('social_stories')
        .insert({
          'author_account_id': me['id'],
          'author_profile_id': profileExternalId,
          'body': 'Shared ${author?['display_name'] ?? author?['username'] ?? 'a friend'}\'s Story',
          'visibility': 'friends',
          'community_id': null,
          'media_reference': reference,
          'expires_at': DateTime.now().toUtc().add(Duration(hours: expiresInHours)).toIso8601String(),
        })
        .select()
        .single());
  }

  Future<Map<String, dynamic>> createSocialStory({
    required String accountExternalId,
    required String profileExternalId,
    required String body,
    String? communityId,
    int expiresInHours = 24,
    Map<String, dynamic>? mediaReference,
  }) async {
    final c = _db;
    if (c == null)
      throw StateError('Social features require Supabase persistence.');
    final me = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id', accountExternalId)
        .single();
    final clean = body.trim();
    if (clean.isEmpty || clean.length > 1000)
      throw ArgumentError('Story must contain 1–1000 characters.');
    if (expiresInHours < 24 || expiresInHours > 168) {
      throw ArgumentError('Story duration must be between 24 and 168 hours.');
    }
    final targetCommunityId = communityId?.trim();
    if (targetCommunityId != null && targetCommunityId.isNotEmpty) {
      final membership = await c
          .from('social_community_memberships')
          .select('community_id')
          .eq('community_id', targetCommunityId)
          .eq('account_id', me['id'].toString())
          .eq('profile_id', profileExternalId)
          .maybeSingle();
      if (membership == null) {
        throw StateError('Join this community before sharing a story there.');
      }
    }
    return Map<String, dynamic>.from(await c
        .from('social_stories')
        .insert({
          'author_account_id': me['id'],
          'author_profile_id': profileExternalId,
          'body': clean,
          'visibility': targetCommunityId == null || targetCommunityId.isEmpty
              ? 'friends'
              : 'community',
          'community_id':
              targetCommunityId?.isEmpty == true ? null : targetCommunityId,
          'media_reference': _validateSocialMediaReference(
            mediaReference,
            accountId: me['id'].toString(),
            profileId: profileExternalId,
          ),
          'expires_at': DateTime.now()
              .toUtc()
              .add(Duration(hours: expiresInHours))
              .toIso8601String(),
        })
        .select()
        .single());
  }

  Future<String> uploadSocialAttachment({
    required String accountExternalId,
    required String profileExternalId,
    required List<int> bytes,
    required String contentType,
  }) async {
    final c = _db;
    if (c == null)
      throw StateError('Social features require Supabase persistence.');
    if (bytes.isEmpty || bytes.length > maxSocialAttachmentBytes) {
      throw ArgumentError('Attachments must be between 1 byte and 50 MB.');
    }
    const extensions = <String, String>{
      'image/jpeg': 'jpg',
      'image/png': 'png',
      'image/webp': 'webp',
      'video/mp4': 'mp4',
      'video/webm': 'webm',
      'video/quicktime': 'mov',
      'audio/mp4': 'm4a',
      'audio/aac': 'aac',
      'audio/mpeg': 'mp3',
      'audio/ogg': 'ogg',
      'audio/webm': 'webm',
    };
    final extension = extensions[contentType.toLowerCase()];
    if (extension == null)
      throw ArgumentError('Unsupported attachment format.');

    final account = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id', accountExternalId)
        .single();
    final accountId = account['id'].toString();
    final profile = await c
        .from('profiles')
        .select('external_profile_id')
        .eq('account_id', accountId)
        .eq('external_profile_id', profileExternalId)
        .eq('is_active', true)
        .maybeSingle();
    if (profile == null) throw StateError('Profile not found.');

    final random = Random.secure();
    final token = List<int>.generate(16, (_) => random.nextInt(256))
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    final path =
        '$accountId/${Uri.encodeComponent(profileExternalId)}/$token.$extension';
    await c.storage.from(_socialPhotoBucket).uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
    return path;
  }

  Map<String, dynamic>? _validateSocialMediaReference(
    Map<String, dynamic>? value, {
    required String accountId,
    required String profileId,
  }) {
    if (value == null) return null;
    if (value.length > 12) throw ArgumentError('Invalid social attachment.');
    final ownerPrefix = '$accountId/${Uri.encodeComponent(profileId)}/';
    String? ownedPath(String key, String label) {
      final path = value[key]?.toString().trim();
      if (path == null || path.isEmpty) return null;
      if (!path.startsWith(ownerPrefix) || path.length > 512 || path.contains('..')) {
        throw ArgumentError('$label attachment does not belong to this profile.');
      }
      return path;
    }

    final photoPath = ownedPath('photoPath', 'Photo');
    final videoPath = ownedPath('videoPath', 'Video');
    final coverPath = ownedPath('coverPath', 'Cover');
    final type = value['type']?.toString().trim();
    final storyData = value['storyData'];
    final cleanStoryData = storyData is Map
        ? _sanitizeStoryData(Map<String, dynamic>.from(storyData))
        : null;

    if (type == 'video') {
      if (videoPath == null) throw ArgumentError('Story video is missing.');
      final relatedMediaId = value['relatedMediaId']?.toString().trim() ?? '';
      final relatedMediaTitle = value['relatedMediaTitle']?.toString().trim() ?? '';
      final relatedMediaType = value['relatedMediaType']?.toString().trim() ?? '';
      final contentMode = value['contentMode']?.toString().trim() ?? 'short';
      final hasShortMetadata = relatedMediaId.isNotEmpty || relatedMediaTitle.isNotEmpty || relatedMediaType.isNotEmpty;
      if (hasShortMetadata &&
          (relatedMediaId.isEmpty || relatedMediaId.length > 200 ||
              relatedMediaTitle.isEmpty || relatedMediaTitle.length > 300 ||
              !{'movie', 'show', 'song'}.contains(relatedMediaType) ||
              !{'short', 'review', 'skit'}.contains(contentMode))) {
        throw ArgumentError('Short videos must be linked to a movie, show, or song.');
      }
      return <String, dynamic>{
        'type': 'video',
        'videoPath': videoPath,
        if (coverPath != null) 'coverPath': coverPath,
        if (hasShortMetadata) ...{
          'relatedMediaId': relatedMediaId,
          'relatedMediaTitle': relatedMediaTitle,
          'relatedMediaType': relatedMediaType,
          'contentMode': contentMode,
        },
        if (cleanStoryData != null && cleanStoryData.isNotEmpty) 'storyData': cleanStoryData,
        if (value['fileName'] != null) 'fileName': value['fileName'].toString().substring(0, min(180, value['fileName'].toString().length)),
      };
    }
    if (type == 'photo') {
      if (photoPath == null) throw ArgumentError('Story photo is missing.');
      return <String, dynamic>{
        'type': 'photo',
        'photoPath': photoPath,
        if (cleanStoryData != null && cleanStoryData.isNotEmpty) 'storyData': cleanStoryData,
        if (value['fileName'] != null) 'fileName': value['fileName'].toString().substring(0, min(180, value['fileName'].toString().length)),
      };
    }
    if (type == 'story') {
      if (photoPath != null || videoPath != null || coverPath != null) {
        throw ArgumentError('Text-only Stories cannot contain attachment paths.');
      }
      return {
        'type': 'story',
        if (cleanStoryData != null && cleanStoryData.isNotEmpty) 'storyData': cleanStoryData,
      };
    }
    if (type == 'product') {
      final productId = value['productId']?.toString().trim() ?? '';
      if (productId.isEmpty || productId.length > 200) throw ArgumentError('Product shares require a valid product.');
      final title = value['title']?.toString().trim() ?? '';
      final description = value['description']?.toString().trim() ?? '';
      if (title.length > 300 || description.length > 2000) throw ArgumentError('Product share text is too long.');
      return {
        'type': 'product',
        'productId': productId,
        if (title.isNotEmpty) 'title': title,
        if (description.isNotEmpty) 'description': description,
      };
    }
    if (type == 'review') {
      if (photoPath == null) throw ArgumentError('Review attachment requires a photo.');
      return {
        'type': 'review',
        'photoPath': photoPath,
        if (value['reviewId'] != null) 'reviewId': value['reviewId'].toString(),
        if (value['score'] is num) 'score': (value['score'] as num).clamp(0, 10).toDouble(),
        if (value['label'] != null) 'label': value['label'].toString().substring(0, min(100, value['label'].toString().length)),
        if (value['spoiler'] == true) 'spoiler': true,
      };
    }
    throw ArgumentError('Unsupported social attachment.');
  }

  Map<String, dynamic> _sanitizeStoryData(Map<String, dynamic> data) {
    final encoded = jsonEncode(data);
    if (encoded.length > 20000) throw ArgumentError('Story customization data is too large.');
    final result = <String, dynamic>{};
    for (final entry in data.entries) {
      if (entry.key.length > 64) continue;
      if (entry.key == 'mentions' && entry.value is List) {
        result['mentions'] = (entry.value as List).whereType<Map>().take(20).map((item) => Map<String, dynamic>.from(item)).toList();
      } else if (entry.key == 'lyrics' && entry.value is String) {
        result['lyrics'] = entry.value.toString().substring(0, min(8000, entry.value.toString().length));
      } else {
        result[entry.key] = entry.value;
      }
    }
    return result;
  }

  Future<Map<String, dynamic>> createSocialMediaNote({
    required String accountExternalId,
    required String profileExternalId,
    required String mediaId,
    required String mediaVersionId,
    required int positionMilliseconds,
    required String text,
  }) async {
    final c = _db;
    if (c == null)
      throw StateError('Social features require Supabase persistence.');
    final me = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id', accountExternalId)
        .single();
    final clean = text.trim();
    if (clean.isEmpty || clean.length > 1000)
      throw ArgumentError('Note must contain 1–1000 characters.');
    return Map<String, dynamic>.from(await c
        .from('social_media_notes')
        .insert({
          'account_id': me['id'],
          'profile_id': profileExternalId,
          'media_id': mediaId,
          'media_version_id': mediaVersionId,
          'position_milliseconds':
              positionMilliseconds < 0 ? 0 : positionMilliseconds,
          'text': clean,
        })
        .select()
        .single());
  }

  Future<List<Map<String, dynamic>>> getSocialMediaNotes({
    required String accountExternalId,
    required String profileExternalId,
    required String mediaId,
    String? mediaVersionId,
  }) async {
    final c = _db;
    if (c == null) return const <Map<String, dynamic>>[];
    final me = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id', accountExternalId)
        .single();
    var query = c
        .from('social_media_notes')
        .select()
        .eq('account_id', me['id'].toString())
        .eq('profile_id', profileExternalId)
        .eq('media_id', mediaId);
    if (mediaVersionId != null && mediaVersionId.trim().isNotEmpty) {
      query = query.eq('media_version_id', mediaVersionId.trim());
    }
    final rows = await query
        .order('position_milliseconds')
        .order('created_at', ascending: true);
    return rows.map((item) => Map<String, dynamic>.from(item)).toList();
  }

  // ---------------------------------------------------------------------------
  // ACCOUNT LOOKUP
  // ---------------------------------------------------------------------------

  /// Persists an account-owned physical copy. A provider catalog result is
  /// never accepted as a substitute for this ownership record.
  Future<void> upsertPhysicalItem(PhysicalItem item) async {
    final c = _db;
    if (c == null) return;

    final externalAccountId = _requiredId(item.accountId, field: 'accountId');
    final existingAccount = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id', externalAccountId)
        .maybeSingle();
    if (existingAccount == null) {
      throw StateError('The physical item account does not exist.');
    }
    final internalAccountId = _requiredId(
      existingAccount['id']?.toString(),
      field: 'accounts.id',
    );

    final existingItem = await c
        .from('physical_items')
        .select('id,ownership_status,ownership_history')
        .eq('account_id', internalAccountId)
        .eq('external_item_id', item.id.trim())
        .maybeSingle();
    if (existingItem != null) {
      final oldHistory = existingItem['ownership_history'];
      final oldHistoryCount = oldHistory is List ? oldHistory.length : 0;
      if (item.ownershipHistory.length < oldHistoryCount) {
        throw StateError('Physical ownership history cannot be removed.');
      }
      final oldStatus = existingItem['ownership_status']?.toString();
      if (oldStatus != item.ownershipStatus.name &&
          (item.ownershipHistory.length <= oldHistoryCount ||
              item.ownershipHistory.last.status != item.ownershipStatus)) {
        throw StateError('Ownership status changes require a history record.');
      }
    }

    await c.from('physical_items').upsert({
      'external_item_id': _requiredId(item.id, field: 'physicalItem.id'),
      'account_id': internalAccountId,
      'title':
          _boundedText(item.title, field: 'physicalItem.title', maxLength: 500),
      'format': item.format.name,
      'region': _safeNullableText(item.region, maxLength: 100),
      'edition': _safeNullableText(item.edition, maxLength: 500),
      'media_edition_id': item.editionId,
      'physical_release_ref':
          _safeNullableText(item.physicalReleaseId, maxLength: 200),
      'release_date':
          item.releaseDate?.toUtc().toIso8601String().substring(0, 10),
      'barcode': _safeNullableText(item.barcode, maxLength: 100),
      'catalog_number': _safeNullableText(item.catalogNumber, maxLength: 200),
      'disc_count': item.discCount,
      'acquired_at': item.acquiredAt.toUtc().toIso8601String(),
      'item_condition': _safeNullableText(item.condition, maxLength: 200),
      'ownership_status': item.ownershipStatus.name,
      'notes': _safeNullableText(item.notes, maxLength: 4000),
      'artwork_url': _safeNullableText(item.artworkUrl, maxLength: 2048),
      'included_extras': item.includedExtras,
      'ownership_history':
          item.ownershipHistory.map((change) => change.toJson()).toList(),
    }, onConflict: 'account_id,external_item_id');

    final persistedItem = existingItem ??
        await c
            .from('physical_items')
            .select('id')
            .eq('account_id', internalAccountId)
            .eq('external_item_id', item.id.trim())
            .single();
    final physicalItemId = _requiredId(
      persistedItem['id']?.toString(),
      field: 'physical_items.id',
    );
    final oldHistory = existingItem?['ownership_history'];
    final oldHistoryCount = oldHistory is List ? oldHistory.length : 0;
    for (var index = oldHistoryCount;
        index < item.ownershipHistory.length;
        index++) {
      final change = item.ownershipHistory[index];
      final eventKey =
          '${index}_${change.changedAt.toUtc().toIso8601String()}_${change.status.name}';
      await c.from('physical_ownership_events').upsert({
        'physical_item_id': physicalItemId,
        'event_key': eventKey,
        'new_status': change.status.name,
        'actor_ref': change.actorId,
        'note': _safeNullableText(change.note, maxLength: 1000),
        'changed_at': change.changedAt.toUtc().toIso8601String(),
      }, onConflict: 'physical_item_id,event_key', ignoreDuplicates: true);
    }
  }

  /// Loads physical ownership records for one external account ID.
  Future<List<PhysicalItem>> loadPhysicalItems(String accountId) async {
    final c = _db;
    if (c == null) return const <PhysicalItem>[];

    final externalAccountId = _requiredId(accountId, field: 'accountId');
    final account = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id', externalAccountId)
        .maybeSingle();
    if (account == null) return const <PhysicalItem>[];
    final internalAccountId =
        _requiredId(account['id']?.toString(), field: 'accounts.id');

    final rows = await c
        .from('physical_items')
        .select()
        .eq('account_id', internalAccountId)
        .order('acquired_at', ascending: false);

    return rows.map((raw) {
      final row = Map<String, dynamic>.from(raw);
      return PhysicalItem.fromJson({
        'id': row['external_item_id'],
        'accountId': externalAccountId,
        'title': row['title'],
        'format': row['format'],
        'region': row['region'],
        'edition': row['edition'],
        'editionId': row['media_edition_id'],
        'physicalReleaseId': row['physical_release_ref'],
        'releaseDate': row['release_date'],
        'barcode': row['barcode'],
        'catalogNumber': row['catalog_number'],
        'discCount': row['disc_count'],
        'acquiredAt': row['acquired_at'],
        'condition': row['item_condition'],
        'ownershipStatus': row['ownership_status'],
        'notes': row['notes'],
        'artworkUrl': row['artwork_url'],
        'includedExtras': row['included_extras'],
        'ownershipHistory': row['ownership_history'],
        'createdAt': row['created_at'],
        'updatedAt': row['updated_at'],
      });
    }).toList(growable: false);
  }

  Future<Map<String, dynamic>?> accountByAuthUserId(
    String authUserId,
  ) async {
    final c = _db;
    if (c == null) return null;

    final cleanId = _requiredId(
      authUserId,
      field: 'authUserId',
    );

    final row = await c
        .from('accounts')
        .select()
        .eq('auth_user_id', cleanId)
        .maybeSingle();

    return row == null ? null : Map<String, dynamic>.from(row);
  }

  // ---------------------------------------------------------------------------
  // ACCOUNT PERSISTENCE
  // ---------------------------------------------------------------------------

  Future<void> upsertAccount(
    Account account,
  ) async {
    final c = _db;
    if (c == null) return;

    _validateAccount(account);

    final externalAccountId = _requiredId(
      account.id,
      field: 'account.id',
    );

    final username = _boundedText(
      account.username,
      field: 'account.username',
      maxLength: _maxNameLength,
    );

    final email = _normalizeEmail(account.email);

    final existing = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id', externalAccountId)
        .maybeSingle();

    Map<String, dynamic> row;

    final values = <String, dynamic>{
      'external_account_id': externalAccountId,
      'username': username,
      'email': email,
      'display_name': username,
      'status': 'active',
      'profile_administration_policy': {
        'allowMembersToManageOwnProfiles':
            account.allowMembersToManageOwnProfiles,
      },
    };

    if (existing == null) {
      final created = await c.from('accounts').insert(values).select().single();

      row = Map<String, dynamic>.from(created);
    } else {
      final internalExistingId = _requiredId(
        existing['id']?.toString(),
        field: 'accounts.id',
      );

      final updated = await c
          .from('accounts')
          .update(values)
          .eq('id', internalExistingId)
          .select()
          .single();

      row = Map<String, dynamic>.from(updated);
    }

    final internalAccountId = _requiredId(
      row['id']?.toString(),
      field: 'accounts.id',
    );

    // -----------------------------------------------------------------------
    // OWNER LOGIN IDENTITY
    // -----------------------------------------------------------------------

    final existingIdentity = await c
        .from('member_identities')
        .select('id')
        .eq('email', email)
        .maybeSingle();

    late final String identityId;

    if (existingIdentity == null) {
      final createdIdentity = await c
          .from('member_identities')
          .insert({
            'email': email,
            'password_hash': account.passwordHash,
          })
          .select('id')
          .single();

      identityId = _requiredId(
        createdIdentity['id']?.toString(),
        field: 'member_identities.id',
      );
    } else {
      identityId = _requiredId(
        existingIdentity['id']?.toString(),
        field: 'member_identities.id',
      );
    }

    await c.from('member_identities').update({
      'password_hash': account.passwordHash,
    }).eq(
      'id',
      identityId,
    );

    final existingOwner = await c
        .from('account_members')
        .select('id')
        .eq('account_id', internalAccountId)
        .eq('identity_id', identityId)
        .maybeSingle();

    if (existingOwner == null) {
      await c.from('account_members').insert({
        'account_id': internalAccountId,
        'identity_id': identityId,
        'role': 'owner',
        'status': 'active',
        'display_name': username,
      });
    } else {
      await c.from('account_members').update({
        'role': 'owner',
        'status': 'active',
        'display_name': username,
      }).eq(
        'id',
        existingOwner['id'],
      );
    }

    // -----------------------------------------------------------------------
    // HOME SERVER
    // -----------------------------------------------------------------------

    final existingServer = await c
        .from('servers')
        .select('id')
        .eq('account_id', internalAccountId)
        .maybeSingle();

    if (existingServer == null) {
      final server = await c
          .from('servers')
          .insert({
            'account_id': internalAccountId,
            'name': 'Home Server',
            'status': 'pending',
            'server_type': 'home',
          })
          .select('id')
          .single();

      final serverId = _requiredId(
        server['id']?.toString(),
        field: 'servers.id',
      );

      await c.from('server_storage').upsert(
        {
          'server_id': serverId,
          'total_bytes': _safeNonNegativeInt(
            account.storageLimitBytes,
          ),
          'used_bytes': _safeNonNegativeInt(
            account.storageUsedBytes,
          ),
          'available_bytes': _availableBytes(
            account.storageLimitBytes,
            account.storageUsedBytes,
          ),
        },
        onConflict: 'server_id',
      );
    }

    // Every account gets exactly one wishlist.
    await c.from('wishlists').upsert(
      {
        'account_id': internalAccountId,
      },
      onConflict: 'account_id',
    );

    // -----------------------------------------------------------------------
    // PRIVATE CREDENTIALS
    // -----------------------------------------------------------------------
    //
    // These values must remain backend-only. They are deliberately stored in
    // a separate table from the public account row.

    await c.from('account_private_credentials').upsert(
      {
        'account_id': internalAccountId,
        'external_account_id': externalAccountId,
        'password_hash': account.passwordHash,
        'security_question': _boundedText(
          account.securityQuestion,
          field: 'securityQuestion',
          maxLength: 1000,
        ),
        'security_answer_hash': account.securityAnswerHash,
        'mfa_enabled': account.mfaEnabled,
        'mfa_challenge_hash': account.mfaChallengeHash,
        'mfa_challenge_expires_at':
            account.mfaChallengeExpiresAt?.toUtc().toIso8601String(),
        'mfa_challenge_member_id': account.mfaChallengeMemberId,
      },
      onConflict: 'external_account_id',
    );

    // -----------------------------------------------------------------------
    // SUBSCRIPTION
    // -----------------------------------------------------------------------

    final subscription = account.subscription;

    if (subscription != null) {
      await c.from('subscriptions').upsert(
        {
          'account_id': internalAccountId,
          'plan': subscription.plan.name,
          'status': subscription.active ? 'active' : 'inactive',
          'current_period_start':
              subscription.startedAt.toUtc().toIso8601String(),
          'current_period_end':
              subscription.expiresAt.toUtc().toIso8601String(),
        },
        onConflict: 'account_id',
      );
    }

    // -----------------------------------------------------------------------
    // PROFILES
    // -----------------------------------------------------------------------

    final existingProfiles = await c
        .from('profiles')
        .select('id,external_profile_id')
        .eq('account_id', internalAccountId);

    final existingExternalIds = <String>{};

    for (final raw in existingProfiles) {
      final id = raw['external_profile_id']?.toString().trim();

      if (id != null && id.isNotEmpty) {
        existingExternalIds.add(id);
      }
    }

    final activeProfileIds = <String>{};

    for (final profile in account.profiles) {
      final profileId = _requiredId(
        profile.id,
        field: 'profile.id',
      );

      final profileName = _boundedText(
        profile.name,
        field: 'profile.name',
        maxLength: _maxNameLength,
      );

      activeProfileIds.add(profileId);

      await c.from('profiles').upsert(
        {
          'account_id': internalAccountId,
          'external_profile_id': profileId,
          'name': profileName,
          'avatar_url': _safeNullableText(
            profile.avatarUrl,
            maxLength: 2048,
          ),
          'governance': profile.governance.toJson(),
          'is_active': true,
        },
        onConflict: 'external_profile_id',
      );
    }

    // Remove profiles deleted through the backend API.
    //
    // The database schema is expected to cascade dependent profile settings,
    // watch state, and related rows.
    for (final oldId in existingExternalIds.difference(activeProfileIds)) {
      await c
          .from('profiles')
          .delete()
          .eq('external_profile_id', oldId)
          .eq('account_id', internalAccountId);
    }

    // -----------------------------------------------------------------------
    // ACCOUNT SNAPSHOT
    // -----------------------------------------------------------------------

    await syncAccountSnapshot(account);
  }

  // ---------------------------------------------------------------------------
  // PAYMENTS
  // ---------------------------------------------------------------------------

  Future<void> upsertPayment(
    PaymentSession payment,
  ) async {
    final c = _db;
    if (c == null) return;

    _validatePayment(payment);

    final account = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id', payment.accountId)
        .maybeSingle();

    if (account == null) {
      throw StateError(
        'Account not found in Supabase for payment ${payment.id}.',
      );
    }

    final internalAccountId = _requiredId(
      account['id']?.toString(),
      field: 'accounts.id',
    );

    final values = <String, dynamic>{
      'account_id': internalAccountId,
      'provider': 'backend',
      'provider_payment_id': payment.id,
      'amount': payment.amount,
      'currency': payment.currency.trim().toUpperCase(),
      'status': payment.status.name,
      'plan': payment.plan.name,

      // Preserved because the existing PaymentSession model requires it for
      // checkout restoration. This table must remain backend/service-role
      // accessible only.
      'checkout_token': payment.checkoutToken,

      'expires_at': payment.expiresAt?.toUtc().toIso8601String(),
      'completed_at': payment.completedAt?.toUtc().toIso8601String(),
      'processor_transaction_id': _safeNullableText(
        payment.processorTransactionId,
        maxLength: 500,
      ),
      'failure_reason': _safeNullableText(
        payment.failureReason,
        maxLength: 2000,
      ),
      'created_at': payment.createdAt.toUtc().toIso8601String(),
    };

    final existing = await c
        .from('payments')
        .select('id')
        .eq('provider_payment_id', payment.id)
        .maybeSingle();

    if (existing == null) {
      await c.from('payments').insert(values);
    } else {
      final internalPaymentId = _requiredId(
        existing['id']?.toString(),
        field: 'payments.id',
      );

      await c.from('payments').update(values).eq(
            'id',
            internalPaymentId,
          );
    }
  }

  Future<List<PaymentSession>> loadPayments() async {
    final c = _db;
    if (c == null) return const <PaymentSession>[];

    final accountRows =
        await c.from('accounts').select('id,external_account_id');

    final externalAccountIdsByInternalId = <String, String>{};

    for (final raw in accountRows) {
      final row = Map<String, dynamic>.from(raw);

      final internalId = row['id']?.toString().trim() ?? '';
      final externalId = row['external_account_id']?.toString().trim() ?? '';

      if (internalId.isEmpty || externalId.isEmpty) {
        continue;
      }

      externalAccountIdsByInternalId[internalId] = externalId;
    }

    final paymentRows = await c.from('payments').select().order(
          'created_at',
          ascending: false,
        );

    final result = <PaymentSession>[];

    for (final raw in paymentRows) {
      try {
        final row = Map<String, dynamic>.from(raw);

        final paymentId = row['provider_payment_id']?.toString().trim() ?? '';

        final internalAccountId = row['account_id']?.toString().trim() ?? '';

        final externalAccountId =
            externalAccountIdsByInternalId[internalAccountId] ?? '';

        if (paymentId.isEmpty || externalAccountId.isEmpty) {
          continue;
        }

        final amount = _parseDouble(row['amount']);

        if (amount == null || !amount.isFinite || amount < 0) {
          continue;
        }

        final plan = _subscriptionPlan(row['plan']);
        final status = _paymentStatus(row['status']);

        if (plan == null || status == null) {
          continue;
        }

        final createdAt = DateTime.tryParse(
          row['created_at']?.toString() ?? '',
        );

        if (createdAt == null) {
          continue;
        }

        result.add(
          PaymentSession(
            id: paymentId,
            accountId: externalAccountId,
            plan: plan,
            amount: amount,
            currency: row['currency']?.toString() ?? '',
            status: status,
            createdAt: createdAt.toLocal(),
            expiresAt: _parseDateTime(row['expires_at']),
            completedAt: _parseDateTime(row['completed_at']),
            processorTransactionId: _nullable(row['processor_transaction_id']),
            failureReason: _nullable(row['failure_reason']),
            checkoutToken: row['checkout_token']?.toString() ?? '',
          ),
        );
      } catch (_) {
        // One malformed payment must not prevent other valid payments from
        // loading during backend startup.
        continue;
      }
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // SECURITY EVENTS
  // ---------------------------------------------------------------------------

  Future<void> recordSecurityEvent({
    String? accountId,
    required String eventType,
    Map<String, dynamic> metadata = const {},
  }) async {
    final c = _db;
    if (c == null) return;

    final cleanEventType = _boundedText(
      eventType,
      field: 'eventType',
      maxLength: 200,
    );

    String? internalId;

    if (accountId != null && accountId.trim().isNotEmpty) {
      final cleanAccountId = _requiredId(
        accountId,
        field: 'accountId',
      );

      final row = await c
          .from('accounts')
          .select('id')
          .eq('external_account_id', cleanAccountId)
          .maybeSingle();

      internalId = row?['id']?.toString();
    }

    final safeMetadata = _sanitizeJsonMap(
      metadata,
      maxBytes: _maxSecurityMetadataBytes,
    );

    await c.from('security_events').insert({
      'account_id': internalId,
      'event_type': cleanEventType,
      'metadata': safeMetadata,
    });
  }

  // ---------------------------------------------------------------------------
  // SCHEDULED LIBRARY PUBLICATION
  // ---------------------------------------------------------------------------

  Future<void> upsertLibraryAddition(LibraryAddition item) async {
    final c = _db;
    if (c == null) return;
    final account = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id', item.accountId)
        .maybeSingle();
    if (account == null)
      throw StateError('Account not found for library addition.');
    final internalAccountId =
        _requiredId(account['id']?.toString(), field: 'accounts.id');
    await c.from('library_additions').upsert({
      'id': item.id,
      'account_id': internalAccountId,
      'server_media_id': item.mediaId,
      'title':
          _boundedText(item.title, field: 'title', maxLength: _maxNameLength),
      'media_type':
          _boundedText(item.mediaType, field: 'mediaType', maxLength: 64),
      'scheduled_for': item.scheduledFor.toUtc().toIso8601String(),
      'scheduled_timezone': _boundedText(item.timeZone,
          field: 'scheduledTimezone', maxLength: 128),
      'status': item.status.name,
      'created_at': item.createdAt.toUtc().toIso8601String(),
      'published_at': item.publishedAt?.toUtc().toIso8601String(),
      'cancelled_at': item.cancelledAt?.toUtc().toIso8601String(),
    }, onConflict: 'id');
  }

  Future<List<LibraryAddition>> loadLibraryAdditions() async {
    final c = _db;
    if (c == null) return const <LibraryAddition>[];
    final accounts = await c.from('accounts').select('id,external_account_id');
    final ids = <String, String>{};
    for (final raw in accounts) {
      final row = Map<String, dynamic>.from(raw);
      final internal = row['id']?.toString().trim() ?? '';
      final external = row['external_account_id']?.toString().trim() ?? '';
      if (internal.isNotEmpty && external.isNotEmpty) ids[internal] = external;
    }
    final rows =
        await c.from('library_additions').select().order('scheduled_for');
    final result = <LibraryAddition>[];
    for (final raw in rows) {
      final row = Map<String, dynamic>.from(raw);
      final accountId = ids[row['account_id']?.toString() ?? ''];
      if (accountId == null) continue;
      final scheduled =
          DateTime.tryParse(row['scheduled_for']?.toString() ?? '');
      if (scheduled == null) continue;
      final status = LibraryAdditionStatus.values.firstWhere(
        (s) => s.name == row['status']?.toString(),
        orElse: () => LibraryAdditionStatus.scheduled,
      );
      result.add(LibraryAddition(
        id: row['id']?.toString() ?? '',
        accountId: accountId,
        mediaId: row['server_media_id']?.toString() ?? '',
        title: row['title']?.toString() ?? '',
        mediaType: row['media_type']?.toString() ?? 'movie',
        scheduledFor: scheduled,
        timeZone: row['scheduled_timezone']?.toString() ?? 'UTC',
        status: status,
        createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
            DateTime.now().toUtc(),
        publishedAt: DateTime.tryParse(row['published_at']?.toString() ?? ''),
        cancelledAt: DateTime.tryParse(row['cancelled_at']?.toString() ?? ''),
      ));
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // ACCOUNT RESTORATION
  // ---------------------------------------------------------------------------

  Future<List<Account>> loadAccounts() async {
    final c = _db;
    if (c == null) return const <Account>[];

    final accountRows = await c.from('accounts').select();
    final result = <Account>[];

    for (final raw in accountRows) {
      try {
        final row = Map<String, dynamic>.from(raw);

        final externalId = row['external_account_id']?.toString().trim() ?? '';

        if (externalId.isEmpty) {
          continue;
        }

        final internalAccountId = row['id']?.toString().trim() ?? '';

        if (internalAccountId.isEmpty) {
          continue;
        }

        final credentialRow = await c
            .from('account_private_credentials')
            .select()
            .eq('account_id', internalAccountId)
            .maybeSingle();

        if (credentialRow == null) {
          // Accounts created directly through Supabase Auth are intentionally
          // not imported into the custom backend until their private backend
          // credential record exists.
          continue;
        }

        final profileRows = await c
            .from('profiles')
            .select()
            .eq('account_id', internalAccountId)
            .eq('is_active', true)
            .order('created_at');

        final profiles = <Profile>[];

        for (final profileRaw in profileRows) {
          final profileRow = Map<String, dynamic>.from(profileRaw);

          final profileExternalId =
              profileRow['external_profile_id']?.toString().trim() ?? '';

          if (profileExternalId.isEmpty) {
            continue;
          }

          profiles.add(
            Profile(
              id: profileExternalId,
              name: profileRow['name']?.toString() ?? '',
              avatarUrl: _nullable(
                profileRow['avatar_url'],
              ),
              governance: ProfileGovernance.fromJson(
                profileRow['governance'] is Map
                    ? Map<String, dynamic>.from(profileRow['governance'])
                    : null,
              ),
            ),
          );
        }

        Subscription? subscription;

        final subscriptionRow = await c
            .from('subscriptions')
            .select()
            .eq('account_id', internalAccountId)
            .maybeSingle();

        if (subscriptionRow != null) {
          final plan = _subscriptionPlan(subscriptionRow['plan']);

          if (plan != null) {
            final startedAt = DateTime.tryParse(
                  subscriptionRow['current_period_start']?.toString() ?? '',
                ) ??
                DateTime.now().toUtc();

            final expiresAt = DateTime.tryParse(
                  subscriptionRow['current_period_end']?.toString() ?? '',
                ) ??
                startedAt;

            subscription = Subscription(
              id: subscriptionRow['id']?.toString() ??
                  'sub_${externalId.replaceAll('-', '')}',
              plan: plan,
              startedAt: startedAt.toLocal(),
              expiresAt: expiresAt.toLocal(),
              active: subscriptionRow['status']?.toString() == 'active',
            );
          }
        }

        final account = Account(
          id: externalId,
          username: row['username']?.toString() ?? '',
          email: row['email']?.toString() ?? '',
          passwordHash: credentialRow['password_hash']?.toString() ?? '',
          securityQuestion:
              credentialRow['security_question']?.toString() ?? '',
          securityAnswerHash:
              credentialRow['security_answer_hash']?.toString() ?? '',
          mfaEnabled: credentialRow['mfa_enabled'] == true,
          mfaChallengeHash:
              credentialRow['mfa_challenge_hash']?.toString() ?? '',
          mfaChallengeExpiresAt: DateTime.tryParse(
            credentialRow['mfa_challenge_expires_at']?.toString() ?? '',
          ),
          mfaChallengeMemberId:
              credentialRow['mfa_challenge_member_id']?.toString(),
          allowMembersToManageOwnProfiles: row['profile_administration_policy']
                  is Map &&
              Map<String, dynamic>.from(row['profile_administration_policy'])[
                      'allowMembersToManageOwnProfiles'] ==
                  true,
          profiles: profiles,
          subscription: subscription,
        );

        result.add(account);
      } catch (_) {
        // A malformed account must not prevent the remaining valid accounts
        // from being restored.
        continue;
      }
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // MEMBER LOGINS
  // ---------------------------------------------------------------------------

  Future<List<MemberLoginRecord>> loadMemberLogins() async {
    final c = _db;
    if (c == null) {
      return const <MemberLoginRecord>[];
    }

    final identities = await c.from('member_identities').select(
          'id,email,password_hash',
        );

    final members = await c.from('account_members').select(
          'id,account_id,identity_id,role,status,profile_id',
        );

    List<dynamic> memberProfileRows = const <dynamic>[];
    try {
      memberProfileRows = await c.from('account_member_profiles').select(
            'account_member_id,profile_id,is_primary',
          );
    } catch (_) {
      // The additive profile-assignment migration may not have been applied
      // yet. Fall back to the legacy single profile_id column.
    }
    final profileIdsByMember = <String, List<String>>{};
    for (final rawAssignment in memberProfileRows) {
      final assignment = Map<String, dynamic>.from(rawAssignment);
      final memberId = assignment['account_member_id']?.toString() ?? '';
      final profileId = assignment['profile_id']?.toString() ?? '';
      if (memberId.isEmpty || profileId.isEmpty) continue;
      profileIdsByMember.putIfAbsent(memberId, () => <String>[]).add(profileId);
    }

    final identityById = <String, Map<String, dynamic>>{};

    for (final rawIdentity in identities) {
      final identity = Map<String, dynamic>.from(rawIdentity);

      final identityId = identity['id']?.toString().trim() ?? '';

      if (identityId.isNotEmpty) {
        identityById[identityId] = identity;
      }
    }

    final result = <MemberLoginRecord>[];

    for (final rawMember in members) {
      final member = Map<String, dynamic>.from(rawMember);

      final identityId = member['identity_id']?.toString().trim() ?? '';

      final identity = identityById[identityId];

      if (identity == null) {
        continue;
      }

      final email = identity['email']?.toString().trim().toLowerCase() ?? '';

      final hash = identity['password_hash']?.toString() ?? '';

      final accountId = member['account_id']?.toString().trim() ?? '';

      if (email.isEmpty || hash.isEmpty || accountId.isEmpty) {
        continue;
      }

      result.add(
        MemberLoginRecord(
          memberId: member['id']?.toString() ?? '',
          accountId: accountId,
          email: email,
          passwordHash: hash,
          role: member['role']?.toString() ?? 'member',
          status: member['status']?.toString() ?? 'active',
          profileIds: <String>[
            ...?profileIdsByMember[member['id']?.toString()],
            if (member['profile_id']?.toString().trim().isNotEmpty == true)
              member['profile_id'].toString(),
          ],
        ),
      );
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // MEMBER INVITATIONS
  // ---------------------------------------------------------------------------

  Future<String> createMemberInvitation({
    required String accountExternalId,
    required String email,
    String role = 'member',
    required String tokenHash,
    required DateTime expiresAt,
  }) async {
    final c = _db;

    if (c == null) {
      throw StateError('Supabase is not configured.');
    }

    final accountId = _requiredId(
      accountExternalId,
      field: 'accountExternalId',
    );

    final cleanEmail = _normalizeEmail(email);

    final cleanTokenHash = _boundedText(
      tokenHash,
      field: 'tokenHash',
      maxLength: 512,
    );

    final account = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id', accountId)
        .maybeSingle();

    if (account == null) {
      throw StateError(
        'Account not found in Supabase.',
      );
    }

    final internalAccountId = _requiredId(
      account['id']?.toString(),
      field: 'accounts.id',
    );

    final existingIdentity = await c
        .from('member_identities')
        .select('id')
        .eq('email', cleanEmail)
        .maybeSingle();

    if (existingIdentity != null) {
      final existingMembership = await c
          .from('account_members')
          .select('id,status')
          .eq(
            'account_id',
            internalAccountId,
          )
          .eq(
            'identity_id',
            existingIdentity['id'],
          )
          .maybeSingle();

      if (existingMembership != null &&
          existingMembership['status']?.toString().toLowerCase() == 'active') {
        throw StateError(
          'That email is already a member of this account.',
        );
      }
    }

    final normalizedRole =
        role.trim().toLowerCase() == 'admin' ? 'admin' : 'member';

    final invitation = await c
        .from('account_invitations')
        .insert({
          'account_id': internalAccountId,
          'email': cleanEmail,
          'role': normalizedRole,
          'token_hash': cleanTokenHash,
          'expires_at': expiresAt.toUtc().toIso8601String(),
          'status': 'pending',
        })
        .select('id')
        .single();

    return _requiredId(
      invitation['id']?.toString(),
      field: 'account_invitations.id',
    );
  }

  Future<Map<String, dynamic>> acceptMemberInvitation({
    required String tokenHash,
    required String email,
    String? passwordHash,
  }) async {
    final c = _db;

    if (c == null) {
      throw StateError('Supabase is not configured.');
    }

    final cleanTokenHash = _boundedText(
      tokenHash,
      field: 'tokenHash',
      maxLength: 512,
    );

    final cleanEmail = _normalizeEmail(email);

    final invite = await c
        .from('account_invitations')
        .select()
        .eq('token_hash', cleanTokenHash)
        .eq('status', 'pending')
        .maybeSingle();

    if (invite == null) {
      throw StateError(
        'Invitation is invalid or has expired.',
      );
    }

    final expiresAt = DateTime.tryParse(
      invite['expires_at']?.toString() ?? '',
    );

    if (expiresAt == null ||
        !DateTime.now().toUtc().isBefore(expiresAt.toUtc())) {
      await c.from('account_invitations').update({
        'status': 'expired',
      }).eq(
        'id',
        invite['id'],
      );

      throw StateError(
        'Invitation has expired.',
      );
    }

    final invitationEmail =
        invite['email']?.toString().trim().toLowerCase() ?? '';

    if (cleanEmail != invitationEmail) {
      throw StateError(
        'Invitation email does not match.',
      );
    }

    var identity = await c
        .from('member_identities')
        .select(
          'id,email,password_hash',
        )
        .eq('email', cleanEmail)
        .maybeSingle();

    if (identity == null) {
      if (passwordHash == null || passwordHash.isEmpty) {
        throw StateError(
          'A password is required to create this login.',
        );
      }

      identity = await c
          .from('member_identities')
          .insert({
            'email': cleanEmail,
            'password_hash': passwordHash,
          })
          .select(
            'id,email,password_hash',
          )
          .single();
    }

    final accountId = _requiredId(
      invite['account_id']?.toString(),
      field: 'account_invitations.account_id',
    );

    final identityId = _requiredId(
      identity['id']?.toString(),
      field: 'member_identities.id',
    );

    final member = await c
        .from('account_members')
        .upsert(
          {
            'account_id': accountId,
            'identity_id': identityId,
            'role': invite['role']?.toString() ?? 'member',
            'status': 'active',
          },
          onConflict: 'account_id,identity_id',
        )
        .select(
          'id,account_id,role,status',
        )
        .single();

    await c.from('account_invitations').update({
      'status': 'accepted',
      'accepted_at': DateTime.now().toUtc().toIso8601String(),
    }).eq(
      'id',
      invite['id'],
    );

    return {
      'memberId': member['id'].toString(),
      'accountId': accountId,
      'email': cleanEmail,
      'role': member['role']?.toString() ?? 'member',

      // Consumed by AuthService and immediately removed from the result
      // before it reaches any HTTP response.
      '_passwordHash': identity['password_hash']?.toString() ?? '',
    };
  }

  // ---------------------------------------------------------------------------
  // ACCOUNT MEMBERS
  // ---------------------------------------------------------------------------

  Future<void> assignMemberProfiles({
    required String accountExternalId,
    required String memberId,
    required List<String> profileIds,
  }) async {
    final c = _db;
    if (c == null) throw StateError('Supabase is not configured.');

    final account = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id',
            _requiredId(accountExternalId, field: 'accountExternalId'))
        .maybeSingle();
    if (account == null) throw StateError('Account not found in Supabase.');

    final internalAccountId =
        _requiredId(account['id']?.toString(), field: 'accounts.id');
    final cleanMemberId = _requiredId(memberId, field: 'memberId');
    final uniqueProfiles = <String>{
      for (final id in profileIds)
        if (id.trim().isNotEmpty) id.trim(),
    };

    final member = await c
        .from('account_members')
        .select('id,account_id')
        .eq('id', cleanMemberId)
        .eq('account_id', internalAccountId)
        .maybeSingle();
    if (member == null) throw StateError('Account member not found.');

    final profileIdMap = <String, String>{};
    if (uniqueProfiles.isNotEmpty) {
      final validRows = await c
          .from('profiles')
          .select('id,external_profile_id')
          .eq('account_id', internalAccountId);
      for (final row in validRows) {
        final external = row['external_profile_id']?.toString().trim() ?? '';
        final internal = row['id']?.toString().trim() ?? '';
        if (external.isNotEmpty && internal.isNotEmpty)
          profileIdMap[external] = internal;
      }
      final invalid = uniqueProfiles.difference(profileIdMap.keys.toSet());
      if (invalid.isNotEmpty)
        throw StateError('One or more profiles do not belong to this account.');
    }

    await c
        .from('account_member_profiles')
        .delete()
        .eq('account_member_id', cleanMemberId);
    if (uniqueProfiles.isEmpty) return;

    final rows = uniqueProfiles
        .toList()
        .asMap()
        .entries
        .map((entry) => {
              'account_member_id': cleanMemberId,
              'profile_id': profileIdMap[entry.value],
              'is_primary': entry.key == 0,
            })
        .toList();
    await c.from('account_member_profiles').insert(rows);
  }

  Future<List<Map<String, dynamic>>> listAccountMembers(
    String accountExternalId,
  ) async {
    final c = _db;

    if (c == null) {
      return const [];
    }

    final cleanAccountId = _requiredId(
      accountExternalId,
      field: 'accountExternalId',
    );

    final account = await c
        .from('accounts')
        .select('id')
        .eq(
          'external_account_id',
          cleanAccountId,
        )
        .maybeSingle();

    if (account == null) {
      throw StateError(
        'Account not found in Supabase.',
      );
    }

    final internalAccountId = _requiredId(
      account['id']?.toString(),
      field: 'accounts.id',
    );

    final members = await c
        .from('account_members')
        .select(
          'id,identity_id,role,status,display_name,profile_id',
        )
        .eq(
          'account_id',
          internalAccountId,
        );

    final identities = await c.from('member_identities').select(
          'id,email',
        );

    final identityById = <String, Map<String, dynamic>>{};

    for (final rawIdentity in identities) {
      final identity = Map<String, dynamic>.from(rawIdentity);

      final identityId = identity['id']?.toString().trim() ?? '';

      if (identityId.isNotEmpty) {
        identityById[identityId] = identity;
      }
    }

    List<dynamic> memberProfileRows = const <dynamic>[];
    try {
      memberProfileRows = await c.from('account_member_profiles').select(
            'account_member_id,profile_id,is_primary',
          );
    } catch (_) {}

    final internalToExternalProfile = <String, String>{};
    final profileRows = await c
        .from('profiles')
        .select('id,external_profile_id')
        .eq('account_id', internalAccountId);
    for (final rawProfile in profileRows) {
      final internal = rawProfile['id']?.toString().trim() ?? '';
      final external =
          rawProfile['external_profile_id']?.toString().trim() ?? '';
      if (internal.isNotEmpty && external.isNotEmpty)
        internalToExternalProfile[internal] = external;
    }

    final profilesByMember = <String, List<String>>{};
    for (final rawAssignment in memberProfileRows) {
      final row = Map<String, dynamic>.from(rawAssignment as Map);
      final memberId = row['account_member_id']?.toString().trim() ?? '';
      final profileId =
          internalToExternalProfile[row['profile_id']?.toString().trim() ?? ''];
      if (memberId.isNotEmpty && profileId != null) {
        profilesByMember.putIfAbsent(memberId, () => <String>[]).add(profileId);
      }
    }

    final accountRows = await c.from('accounts').select('id,username,email');
    final usernameByEmail = <String, String>{};
    for (final rawAccount in accountRows) {
      final row = Map<String, dynamic>.from(rawAccount);
      final email = row['email']?.toString().trim().toLowerCase() ?? '';
      final username = row['username']?.toString().trim() ?? '';
      if (email.isNotEmpty && username.isNotEmpty)
        usernameByEmail[email] = username;
    }

    final result = <Map<String, dynamic>>[];

    for (final raw in members) {
      final member = Map<String, dynamic>.from(raw);

      final identityId = member['identity_id']?.toString().trim() ?? '';

      final identity = identityById[identityId];

      if (identity == null) {
        continue;
      }

      final memberId = member['id']?.toString() ?? '';
      final assignedProfiles = <String>[
        ...?profilesByMember[memberId],
        if (member['profile_id']?.toString().trim().isNotEmpty == true)
          member['profile_id'].toString(),
      ].toSet().toList();

      final memberEmail =
          identity['email']?.toString().trim().toLowerCase() ?? '';
      result.add({
        'id': member['id'],
        'email': identity['email'],
        'username': usernameByEmail[memberEmail],
        'role': member['role'],
        'status': member['status'],
        'displayName': member['display_name'],
        'profileId': assignedProfiles.isEmpty ? null : assignedProfiles.first,
        'profileIds': assignedProfiles,
      });
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // ADD EXISTING ACCOUNT USER AS MEMBER
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> addExistingAccountMemberByUsername({
    required String accountExternalId,
    required String username,
    String role = 'member',
  }) async {
    final c = _db;
    if (c == null) throw StateError('Supabase is not configured.');

    final cleanAccountId =
        _requiredId(accountExternalId, field: 'accountExternalId');
    final cleanUsername = _boundedText(username.trim(),
        field: 'username', maxLength: _maxNameLength);
    final normalizedRole =
        role.trim().toLowerCase() == 'admin' ? 'admin' : 'member';

    final current = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id', cleanAccountId)
        .maybeSingle();
    if (current == null) throw StateError('Account not found in Supabase.');
    final currentId =
        _requiredId(current['id']?.toString(), field: 'accounts.id');

    final target = await c
        .from('accounts')
        .select('id,username,email,display_name')
        .ilike('username', cleanUsername)
        .maybeSingle();
    if (target == null)
      throw StateError('No account user was found with @$cleanUsername.');

    final targetId =
        _requiredId(target['id']?.toString(), field: 'target accounts.id');
    if (targetId == currentId)
      throw StateError('That username already belongs to this account.');

    final ownerMembership = await c
        .from('account_members')
        .select('identity_id')
        .eq('account_id', targetId)
        .eq('role', 'owner')
        .eq('status', 'active')
        .limit(1)
        .maybeSingle();
    if (ownerMembership == null)
      throw StateError('That user does not have an active login identity yet.');

    final identityId = _requiredId(ownerMembership['identity_id']?.toString(),
        field: 'member identity');

    final existing = await c
        .from('account_members')
        .select('id,status')
        .eq('account_id', currentId)
        .eq('identity_id', identityId)
        .maybeSingle();

    final row = await c
        .from('account_members')
        .upsert({
          'account_id': currentId,
          'identity_id': identityId,
          'role': normalizedRole,
          'status': 'active',
          'display_name': target['display_name'] ?? target['username'],
          'accepted_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'account_id,identity_id')
        .select('id,account_id,role,status,display_name')
        .single();

    return {
      'id': row['id'],
      'accountId': cleanAccountId,
      'username': target['username'],
      'email': target['email'],
      'displayName': row['display_name'],
      'role': row['role'],
      'status': row['status'],
      'alreadyMember':
          existing != null && existing['status']?.toString() == 'active',
    };
  }

  // ---------------------------------------------------------------------------
  // ACCOUNT DELETION
  // ---------------------------------------------------------------------------

  Future<void> deleteAccount(
    String externalAccountId,
  ) async {
    final c = _db;
    if (c == null) return;

    final cleanId = _requiredId(
      externalAccountId,
      field: 'externalAccountId',
    );

    final row = await c
        .from('accounts')
        .select('id')
        .eq(
          'external_account_id',
          cleanId,
        )
        .maybeSingle();

    if (row == null) return;

    final internalId = _requiredId(
      row['id']?.toString(),
      field: 'accounts.id',
    );

    await c.from('accounts').delete().eq(
          'id',
          internalId,
        );
  }

  // ---------------------------------------------------------------------------
  // PROFILE
  // ---------------------------------------------------------------------------

  Future<void> updateProfile({
    required String accountExternalId,
    required String profileExternalId,
    required String name,
    String? avatarUrl,
  }) async {
    final c = _db;
    if (c == null) return;

    final cleanAccountId = _requiredId(
      accountExternalId,
      field: 'accountExternalId',
    );

    final cleanProfileId = _requiredId(
      profileExternalId,
      field: 'profileExternalId',
    );

    final cleanName = _boundedText(
      name,
      field: 'name',
      maxLength: _maxNameLength,
    );

    final account = await c
        .from('accounts')
        .select('id')
        .eq(
          'external_account_id',
          cleanAccountId,
        )
        .maybeSingle();

    if (account == null) {
      throw StateError(
        'Account not found in Supabase.',
      );
    }

    final internalAccountId = _requiredId(
      account['id']?.toString(),
      field: 'accounts.id',
    );

    final profile = await c
        .from('profiles')
        .select('id')
        .eq(
          'external_profile_id',
          cleanProfileId,
        )
        .eq(
          'account_id',
          internalAccountId,
        )
        .maybeSingle();

    if (profile == null) {
      throw StateError(
        'Profile not found in Supabase.',
      );
    }

    await c.from('profiles').update({
      'name': cleanName,
      'avatar_url': _safeNullableText(
        avatarUrl,
        maxLength: 2048,
      ),
      'is_active': true,
    }).eq(
      'id',
      profile['id'],
    );
  }

  Future<void> upsertProfile({
    required String accountExternalId,
    required Profile profile,
  }) async {
    final c = _db;
    if (c == null) return;

    final account = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id',
            _requiredId(accountExternalId, field: 'accountExternalId'))
        .maybeSingle();
    if (account == null) throw StateError('Account not found in Supabase.');

    final internalAccountId =
        _requiredId(account['id']?.toString(), field: 'accounts.id');
    final profileId = _requiredId(profile.id, field: 'profile.id');

    await c.from('profiles').upsert({
      'account_id': internalAccountId,
      'external_profile_id': profileId,
      'name': _boundedText(profile.name,
          field: 'profile.name', maxLength: _maxNameLength),
      'avatar_url': _safeNullableText(profile.avatarUrl, maxLength: 2048),
      'governance': profile.governance.toJson(),
      'is_active': true,
    }, onConflict: 'external_profile_id');
  }

  // ---------------------------------------------------------------------------
  // SERVER MEDIA
  // ---------------------------------------------------------------------------

  Future<void> upsertServerMedia({
    required String accountExternalId,
    required String relativeMediaId,
    required String title,
    required String type,
    int? year,
    String? description,
    String? posterUrl,
    String? trailerUrl,
    Map<String, dynamic>? metadata,
    int? fileSizeBytes,
  }) async {
    final c = _db;
    if (c == null) return;

    final cleanAccountId = _requiredId(
      accountExternalId,
      field: 'accountExternalId',
    );

    final cleanRelativeMediaId = _boundedText(
      relativeMediaId,
      field: 'relativeMediaId',
      maxLength: 1000,
    );

    final cleanTitle = _boundedText(
      title,
      field: 'title',
      maxLength: _maxNameLength,
    );

    final cleanType = _boundedText(
      type,
      field: 'type',
      maxLength: 100,
    );

    if (year != null && (year < 1800 || year > 3000)) {
      throw ArgumentError.value(
        year,
        'year',
        'must be between 1800 and 3000',
      );
    }

    if (fileSizeBytes != null && fileSizeBytes < 0) {
      throw ArgumentError.value(
        fileSizeBytes,
        'fileSizeBytes',
        'must not be negative',
      );
    }

    final account = await c
        .from('accounts')
        .select('id')
        .eq(
          'external_account_id',
          cleanAccountId,
        )
        .maybeSingle();

    if (account == null) {
      throw StateError(
        'Account not found in Supabase.',
      );
    }

    final internalAccountId = _requiredId(
      account['id']?.toString(),
      field: 'accounts.id',
    );

    final server = await c
        .from('servers')
        .select('id')
        .eq(
          'account_id',
          internalAccountId,
        )
        .maybeSingle();

    late String serverId;

    if (server == null) {
      final created = await c
          .from('servers')
          .insert({
            'account_id': internalAccountId,
            'name': 'Home Server',
            'status': 'online',
            'server_type': 'home',
            'last_seen_at': DateTime.now().toUtc().toIso8601String(),
          })
          .select('id')
          .single();

      serverId = _requiredId(
        created['id']?.toString(),
        field: 'servers.id',
      );
    } else {
      serverId = _requiredId(
        server['id']?.toString(),
        field: 'servers.id',
      );

      await c.from('servers').update({
        'status': 'online',
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      }).eq(
        'id',
        serverId,
      );
    }

    final incomingMetadata = metadata ?? const <String, dynamic>{};
    if (incomingMetadata['source'] == 'home-server-scanner') {
      final existing = await c
          .from('server_media')
          .select('id,metadata')
          .eq('server_id', serverId)
          .eq('server_media_id', cleanRelativeMediaId)
          .maybeSingle();
      final existingMetadata = existing?['metadata'];
      if (existing != null &&
          existingMetadata is Map &&
          existingMetadata['source'] == 'approved-arm-import') {
        await c.from('server_media').update({
          'availability': 'available',
          'last_seen_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', existing['id']);
        return;
      }
    }

    final normalizedType = cleanType.trim().toLowerCase();

    final canonicalKey =
        '$normalizedType:${cleanTitle.toLowerCase()}:${year ?? ''}';

    final catalog = await c
        .from('media_catalog')
        .select('id')
        .eq(
          'canonical_key',
          canonicalKey,
        )
        .maybeSingle();

    final mediaType = _mediaType(
      cleanType,
    );

    final safeMetadata = _sanitizeJsonMap(
      metadata ?? const {},
      maxBytes: _maxSnapshotBytes,
    );

    final catalogMetadata = <String, dynamic>{
      ...safeMetadata,
      if (trailerUrl != null && trailerUrl.trim().isNotEmpty)
        'trailerUrl': _boundedText(
          trailerUrl,
          field: 'trailerUrl',
          maxLength: 2048,
        ),
      if (fileSizeBytes != null) 'fileSizeBytes': fileSizeBytes,
    };

    final catalogValues = <String, dynamic>{
      'canonical_key': canonicalKey,
      'title': cleanTitle,
      'media_type': mediaType,
      'year': year,
      'description': _safeNullableText(
        description,
        maxLength: 5000,
      ),
      'poster_url': _safeNullableText(
        posterUrl,
        maxLength: 2048,
      ),
      'metadata': catalogMetadata,
    };

    late String catalogId;

    if (catalog == null) {
      final created = await c
          .from('media_catalog')
          .insert(catalogValues)
          .select('id')
          .single();

      catalogId = _requiredId(
        created['id']?.toString(),
        field: 'media_catalog.id',
      );
    } else {
      catalogId = _requiredId(
        catalog['id']?.toString(),
        field: 'media_catalog.id',
      );

      await c.from('media_catalog').update(catalogValues).eq(
            'id',
            catalogId,
          );
    }

    await c.from('server_media').upsert(
      {
        'server_id': serverId,
        'media_catalog_id': catalogId,
        'server_media_id': cleanRelativeMediaId,
        'availability': 'available',
        'metadata': safeMetadata,
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'server_id,server_media_id',
    );
  }

  Future<void> updateServerMediaMetadata({
    required String accountExternalId,
    required String relativeMediaId,
    String? title,
    int? year,
    String? description,
    String? posterUrl,
    String? trailerUrl,
    Map<String, dynamic>? metadata,
  }) async {
    final c = _db;
    if (c == null) return;

    final cleanAccountId = _requiredId(
      accountExternalId,
      field: 'accountExternalId',
    );

    final cleanRelativeMediaId = _boundedText(
      relativeMediaId,
      field: 'relativeMediaId',
      maxLength: 1000,
    );

    if (year != null && (year < 1800 || year > 3000)) {
      throw ArgumentError.value(
        year,
        'year',
        'must be between 1800 and 3000',
      );
    }

    final account = await c
        .from('accounts')
        .select('id')
        .eq(
          'external_account_id',
          cleanAccountId,
        )
        .maybeSingle();

    if (account == null) {
      throw StateError(
        'Account not found in Supabase.',
      );
    }

    final internalAccountId = _requiredId(
      account['id']?.toString(),
      field: 'accounts.id',
    );

    final server = await c
        .from('servers')
        .select('id')
        .eq(
          'account_id',
          internalAccountId,
        )
        .maybeSingle();

    if (server == null) {
      throw StateError(
        'Home server not found in Supabase.',
      );
    }

    final serverId = _requiredId(
      server['id']?.toString(),
      field: 'servers.id',
    );

    final serverMedia = await c
        .from('server_media')
        .select('id,media_catalog_id')
        .eq(
          'server_id',
          serverId,
        )
        .eq(
          'server_media_id',
          cleanRelativeMediaId,
        )
        .maybeSingle();

    if (serverMedia == null) {
      throw StateError(
        'Media is not indexed for this home server.',
      );
    }

    final values = <String, dynamic>{};

    if (title != null) {
      values['title'] = _boundedText(
        title,
        field: 'title',
        maxLength: _maxNameLength,
      );
    }

    if (year != null) {
      values['year'] = year;
    }

    if (description != null) {
      values['description'] = _safeNullableText(
        description,
        maxLength: 5000,
      );
    }

    if (posterUrl != null) {
      values['poster_url'] = _safeNullableText(
        posterUrl,
        maxLength: 2048,
      );
    }

    final current = await c
        .from('media_catalog')
        .select('metadata')
        .eq(
          'id',
          serverMedia['media_catalog_id'],
        )
        .single();

    final currentMetadata = <String, dynamic>{};

    if (current['metadata'] is Map) {
      currentMetadata.addAll(
        _sanitizeJsonMap(
          Map<String, dynamic>.from(
            current['metadata'] as Map,
          ),
          maxBytes: _maxSnapshotBytes,
        ),
      );
    }

    if (metadata != null) {
      currentMetadata.addAll(
        _sanitizeJsonMap(
          metadata,
          maxBytes: _maxSnapshotBytes,
        ),
      );
    }

    if (trailerUrl != null) {
      currentMetadata['trailerUrl'] = _boundedText(
        trailerUrl,
        field: 'trailerUrl',
        maxLength: 2048,
      );
    }

    values['metadata'] = currentMetadata;

    if (values.isNotEmpty) {
      await c.from('media_catalog').update(values).eq(
            'id',
            serverMedia['media_catalog_id'],
          );
    }

    if (metadata != null) {
      await c.from('server_media').update({
        'metadata': _sanitizeJsonMap(
          metadata,
          maxBytes: _maxSnapshotBytes,
        ),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq(
        'id',
        serverMedia['id'],
      );
    }
  }

  Future<void> deleteServerMedia({
    required String accountExternalId,
    required String relativeMediaId,
  }) async {
    final c = _db;
    if (c == null) return;

    final cleanAccountId = _requiredId(
      accountExternalId,
      field: 'accountExternalId',
    );

    final cleanRelativeMediaId = _boundedText(
      relativeMediaId,
      field: 'relativeMediaId',
      maxLength: 1000,
    );

    final account = await c
        .from('accounts')
        .select('id')
        .eq(
          'external_account_id',
          cleanAccountId,
        )
        .maybeSingle();

    if (account == null) return;

    final internalAccountId = _requiredId(
      account['id']?.toString(),
      field: 'accounts.id',
    );

    final server = await c
        .from('servers')
        .select('id')
        .eq(
          'account_id',
          internalAccountId,
        )
        .maybeSingle();

    if (server == null) return;

    await c
        .from('server_media')
        .delete()
        .eq(
          'server_id',
          server['id'],
        )
        .eq(
          'server_media_id',
          cleanRelativeMediaId,
        );
  }

  // ---------------------------------------------------------------------------
  // PROFILE CUSTOMIZATION
  // ---------------------------------------------------------------------------

  Future<void> saveProfileCustomization({
    required String accountExternalId,
    required String profileExternalId,
    Map<String, dynamic>? home,
    Map<String, dynamic>? details,
    Map<String, dynamic>? platform,
    Map<String, dynamic>? music,
  }) async {
    final c = _db;
    if (c == null) return;

    final cleanAccountId = _requiredId(
      accountExternalId,
      field: 'accountExternalId',
    );

    final cleanProfileId = _requiredId(
      profileExternalId,
      field: 'profileExternalId',
    );

    final account = await c
        .from('accounts')
        .select('id')
        .eq(
          'external_account_id',
          cleanAccountId,
        )
        .maybeSingle();

    if (account == null) return;

    final internalAccountId = _requiredId(
      account['id']?.toString(),
      field: 'accounts.id',
    );

    final profile = await c
        .from('profiles')
        .select('id')
        .eq(
          'account_id',
          internalAccountId,
        )
        .eq(
          'external_profile_id',
          cleanProfileId,
        )
        .maybeSingle();

    if (profile == null) return;

    await c.from('profile_customization_snapshots').upsert(
      {
        'profile_id': profile['id'],
        'home_configuration': _sanitizeJsonMap(
          home ?? const {},
          maxBytes: _maxSnapshotBytes,
        ),
        'details_configuration': _sanitizeJsonMap(
          details ?? const {},
          maxBytes: _maxSnapshotBytes,
        ),
        'platform_configuration': _sanitizeJsonMap(
          platform ?? const {},
          maxBytes: _maxSnapshotBytes,
        ),
        'music_configuration': _sanitizeJsonMap(
          music ?? const {},
          maxBytes: _maxSnapshotBytes,
        ),
      },
      onConflict: 'profile_id',
    );
  }

  // ---------------------------------------------------------------------------
  // ACCOUNT SNAPSHOTS
  // ---------------------------------------------------------------------------

  Future<void> syncAccountSnapshot(
    Account account, {
    Map<String, dynamic>? clientSnapshot,
  }) async {
    final c = _db;
    if (c == null) return;

    _validateAccount(account);

    final safeClientSnapshot = _sanitizeJsonMap(
      clientSnapshot ?? const {},
      maxBytes: _maxSnapshotBytes,
    );

    final safeNotifications = account.notifications
        .map(
          (notification) => _sanitizeJsonMap(
            notification,
            maxBytes: 16 * 1024,
          ),
        )
        .toList();

    final rows = <Map<String, dynamic>>[
      {
        'external_account_id': _requiredId(
          account.id,
          field: 'account.id',
        ),
        'username': _boundedText(
          account.username,
          field: 'account.username',
          maxLength: _maxNameLength,
        ),
        'email': _normalizeEmail(account.email),
        'status': 'active',
        'storage_limit_bytes': _safeNonNegativeInt(
          account.storageLimitBytes,
        ),
        'storage_used_bytes': _safeNonNegativeInt(
          account.storageUsedBytes,
        ),
        'storage_request_pending': account.storageRequestPending,
        'storage_requested_terabytes': account.storageRequestedTerabytes < 0
            ? 0
            : account.storageRequestedTerabytes,
        'storage_request_fee_usd': account.storageRequestFeeUsd.isFinite &&
                account.storageRequestFeeUsd >= 0
            ? account.storageRequestFeeUsd
            : 0,
        'storage_request_status': _safeNullableText(
          account.storageRequestStatus,
          maxLength: 100,
        ),
        'storage_request_at':
            account.storageRequestAt?.toUtc().toIso8601String(),
        'profiles': account.profiles
            .map(
              (profile) => {
                'external_profile_id': _requiredId(
                  profile.id,
                  field: 'profile.id',
                ),
                'name': _boundedText(
                  profile.name,
                  field: 'profile.name',
                  maxLength: _maxNameLength,
                ),
                'avatar_url': _safeNullableText(
                  profile.avatarUrl,
                  maxLength: 2048,
                ),
              },
            )
            .toList(),
        'shared_media_ids': _boundedStringList(
          account.sharedMediaIds,
        ),
        'wishlist_media_ids': _boundedStringList(
          account.wishlistMediaIds,
        ),
        'wishlist_recommendation_ids': _boundedStringList(
          account.wishlistRecommendationIds,
        ),
        'notifications': safeNotifications,
        'client_snapshot': safeClientSnapshot,
        'synced_at': DateTime.now().toUtc().toIso8601String(),
      },
    ];

    await c.from('account_sync_snapshots').upsert(
          rows,
          onConflict: 'external_account_id',
        );
  }

  // ---------------------------------------------------------------------------
  // GROUP WATCH
  // ---------------------------------------------------------------------------

  Future<List<dynamic>> checkGroupWatchCompatibility({
    required String mediaCatalogId,
    required String versionKey,
    required List<String> profileIds,
  }) async {
    final c = _db;
    if (c == null) return const [];

    final cleanMediaCatalogId = _requiredId(
      mediaCatalogId,
      field: 'mediaCatalogId',
    );

    final cleanVersionKey = _boundedText(
      versionKey,
      field: 'versionKey',
      maxLength: 500,
    );

    final cleanProfileIds = _boundedStringList(
      profileIds,
      maxItems: 100,
    );

    final result = await c.rpc(
      'check_group_watch_compatibility',
      params: {
        'p_media_catalog_id': cleanMediaCatalogId,
        'p_version_key': cleanVersionKey,
        'p_profile_ids': cleanProfileIds,
      },
    );

    return result is List ? result : const [];
  }

  // ---------------------------------------------------------------------------
  // SHOP ENTITIES
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> searchShopEntities({
    required String query,
    int limit = 50,
  }) async {
    final c = _db;

    if (c == null) {
      return <Map<String, dynamic>>[];
    }

    final safeQuery = _boundedText(
      query,
      field: 'query',
      maxLength: _maxShopQueryLength,
    );

    if (safeQuery.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    final safeLimit = limit.clamp(1, 100).toInt();

    // Escape ILIKE wildcard characters so user input is treated as search
    // text rather than an arbitrary wildcard expression.
    final pattern = '%${_escapeIlike(safeQuery)}%';

    final rows = await c
        .from('shop_entities')
        .select(
          'entity_type,entity_id,name,subtitle,'
          'account_external_id,is_public',
        )
        .eq(
          'is_public',
          true,
        )
        .ilike(
          'name',
          pattern,
        )
        .order('name')
        .limit(safeLimit);

    final typeRows = await c
        .from('shop_entities')
        .select(
          'entity_type,entity_id,name,subtitle,'
          'account_external_id,is_public',
        )
        .eq(
          'is_public',
          true,
        )
        .ilike(
          'entity_type',
          pattern,
        )
        .order('name')
        .limit(safeLimit);

    final merged = <String, Map<String, dynamic>>{};

    for (final raw in [
      ...rows,
      ...typeRows,
    ]) {
      final row = Map<String, dynamic>.from(raw);

      final entityType = row['entity_type']?.toString().trim() ?? '';

      final entityId = row['entity_id']?.toString().trim() ?? '';

      final accountExternalId =
          row['account_external_id']?.toString().trim() ?? '';

      if (entityType.isEmpty || entityId.isEmpty) {
        continue;
      }

      final key = '$entityType:$entityId:$accountExternalId';

      merged[key] = row;
    }

    final result = <Map<String, dynamic>>[];

    for (final raw in merged.values) {
      final row = Map<String, dynamic>.from(raw);

      final entity = ShopEntity(
        type: _boundedText(
          row['entity_type']?.toString() ?? 'other',
          field: 'entity_type',
          maxLength: 100,
        ),
        id: _boundedText(
          row['entity_id']?.toString() ?? '',
          field: 'entity_id',
          maxLength: _maxIdLength,
        ),
        name: _boundedText(
          row['name']?.toString() ?? '',
          field: 'name',
          maxLength: _maxNameLength,
        ),
        subtitle: _boundedText(
          row['subtitle']?.toString() ?? '',
          field: 'subtitle',
          maxLength: _maxNameLength,
        ),
        accountExternalId: _safeNullableText(
          row['account_external_id'],
          maxLength: _maxIdLength,
        ),
        isPublic: row['is_public'] != false,
      );

      if (entity.id.isEmpty || entity.name.isEmpty) {
        continue;
      }

      result.add(entity.toJson());
    }

    return result;
  }

  Future<void> upsertShopEntities({
    required String accountExternalId,
    required List<ShopEntity> entities,
  }) async {
    final c = _db;

    if (c == null) return;

    final cleanAccountId = _requiredId(
      accountExternalId,
      field: 'accountExternalId',
    );

    if (entities.isEmpty) return;

    if (entities.length > _maxShopEntities) {
      throw ArgumentError.value(
        entities.length,
        'entities',
        'must contain no more than $_maxShopEntities items',
      );
    }

    final now = DateTime.now().toUtc().toIso8601String();

    final rows = <Map<String, dynamic>>[];

    for (final entity in entities) {
      final type = _boundedText(
        entity.type.trim().isEmpty ? 'other' : entity.type.trim().toLowerCase(),
        field: 'entity.type',
        maxLength: 100,
      );

      final id = _boundedText(
        entity.id,
        field: 'entity.id',
        maxLength: _maxIdLength,
      );

      final name = _boundedText(
        entity.name,
        field: 'entity.name',
        maxLength: _maxNameLength,
      );

      if (id.isEmpty || name.isEmpty) {
        continue;
      }

      final subtitle = _boundedText(
        entity.subtitle,
        field: 'entity.subtitle',
        maxLength: _maxNameLength,
      );

      final scoped = type == 'collection' || type == 'playlist';

      final entityKey = scoped
          ? '$type:${cleanAccountId.toLowerCase()}:${id.toLowerCase()}'
          : '$type:${id.toLowerCase()}';

      rows.add({
        'entity_key': entityKey,
        'entity_type': type,
        'entity_id': id,
        'name': name,
        'subtitle': subtitle,
        'account_external_id': cleanAccountId,
        'is_public': entity.isPublic,
        'updated_at': now,
      });
    }

    if (rows.isEmpty) return;

    await c.from('shop_entities').upsert(
          rows,
          onConflict: 'entity_key',
        );
  }

  // ---------------------------------------------------------------------------
  // GENERIC APP RECORDS
  // ---------------------------------------------------------------------------

  /// Stores an application record in the extensible application records table.
  ///
  /// Financial credentials are explicitly out of scope for this method. Use
  /// the dedicated payment-provider token tables for tokenized payment data.
  Future<void> upsertAppRecord({
    required String accountExternalId,
    String? profileExternalId,
    required String recordType,
    required String recordKey,
    required String recordId,
    required Map<String, dynamic> data,
  }) async {
    final c = _db;
    if (c == null) return;

    final internalAccount = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id',
            _requiredId(accountExternalId, field: 'accountExternalId'))
        .maybeSingle();

    if (internalAccount == null) {
      throw StateError('Account not found in Supabase.');
    }

    final safeData = _sanitizeJsonMap(
      data,
      maxBytes: _maxSnapshotBytes,
    );

    await c.from('app_records').upsert(
      {
        'id': _requiredId(recordId, field: 'recordId'),
        'account_id': _requiredId(internalAccount['id']?.toString(),
            field: 'accounts.id'),
        'profile_external_id': _nullable(profileExternalId) ?? '',
        'record_type':
            _boundedText(recordType, field: 'recordType', maxLength: 120),
        'record_key':
            _boundedText(recordKey, field: 'recordKey', maxLength: 240),
        'data': safeData,
      },
      onConflict: 'account_id,profile_external_id,record_type,record_key',
    );
  }

  Future<List<Map<String, dynamic>>> loadAppRecords({
    required String accountExternalId,
    String? profileExternalId,
    String? recordType,
  }) async {
    final c = _db;
    if (c == null) return const <Map<String, dynamic>>[];

    final internalAccount = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id',
            _requiredId(accountExternalId, field: 'accountExternalId'))
        .maybeSingle();

    if (internalAccount == null) {
      return const <Map<String, dynamic>>[];
    }

    dynamic query = c
        .from('app_records')
        .select()
        .eq('account_id', internalAccount['id'])
        .order('updated_at', ascending: false);

    final cleanProfile = _nullable(profileExternalId);
    final cleanType = _nullable(recordType);

    if (cleanProfile != null) {
      query = query.eq('profile_external_id', cleanProfile);
    }
    if (cleanType != null) {
      query = query.eq('record_type', cleanType);
    }

    final rows = await query;
    final result = <Map<String, dynamic>>[];

    for (final raw in rows) {
      final row = Map<String, dynamic>.from(raw);
      result.add({
        'id': row['id']?.toString() ?? '',
        'accountId': accountExternalId,
        'profileId': _nullable(row['profile_external_id']),
        'recordType': row['record_type']?.toString() ?? '',
        'recordKey': row['record_key']?.toString() ?? '',
        'data': row['data'] is Map
            ? Map<String, dynamic>.from(row['data'] as Map)
            : <String, dynamic>{},
        'createdAt': row['created_at']?.toString(),
        'updatedAt': row['updated_at']?.toString(),
      });
    }

    return result;
  }

  Future<void> deleteAppRecord({
    required String accountExternalId,
    String? profileExternalId,
    required String recordType,
    required String recordKey,
  }) async {
    final c = _db;
    if (c == null) return;

    final internalAccount = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id',
            _requiredId(accountExternalId, field: 'accountExternalId'))
        .maybeSingle();

    if (internalAccount == null) return;

    dynamic query = c
        .from('app_records')
        .delete()
        .eq('account_id', internalAccount['id'])
        .eq('record_type',
            _boundedText(recordType, field: 'recordType', maxLength: 120))
        .eq('record_key',
            _boundedText(recordKey, field: 'recordKey', maxLength: 240));

    final cleanProfile = _nullable(profileExternalId);
    if (cleanProfile == null) {
      query = query.eq('profile_external_id', '');
    } else {
      query = query.eq('profile_external_id', cleanProfile);
    }

    await query;
  }

  // ---------------------------------------------------------------------------
  // MEDIA KNOWLEDGE
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> loadPublishedKnowledgeFacts({
    required String mediaWorkId,
  }) async {
    final c = _db;
    if (c == null) return const <Map<String, dynamic>>[];
    final cleanId =
        _boundedText(mediaWorkId, field: 'mediaWorkId', maxLength: 256);
    final rows = await c
        .from('media_knowledge_facts')
        .select('*, media_knowledge_fact_sources(*)')
        .eq('media_work_id', cleanId)
        .eq('editorial_status', 'published')
        .order('created_at', ascending: false);
    return rows.whereType<Map>().map((raw) {
      final row = Map<String, dynamic>.from(raw);
      return {
        'id': row['id']?.toString() ?? '',
        'mediaWorkId': row['media_work_id']?.toString() ?? cleanId,
        'mediaVersionId': row['media_version_id']?.toString(),
        'category': row['category']?.toString() ?? '',
        'title': row['title']?.toString() ?? '',
        'body': row['body']?.toString() ?? '',
        'claimStatus': row['claim_status']?.toString() ?? 'established',
        'spoilerScope': row['spoiler_scope']?.toString() ?? 'none',
        'difficulty': row['difficulty']?.toString() ?? 'casual',
        'relatedEntities': row['related_entities'] is List
            ? row['related_entities']
            : const <dynamic>[],
        'reviewedAt': row['reviewed_at']?.toString(),
        'sources': (row['media_knowledge_fact_sources'] is List)
            ? (row['media_knowledge_fact_sources'] as List)
                .whereType<Map>()
                .map((source) => {
                      'id': source['id']?.toString() ?? '',
                      'title': source['title']?.toString() ?? '',
                      'url': source['url']?.toString() ?? '',
                      'sourceType': source['source_type']?.toString() ?? '',
                      'publisher': source['publisher']?.toString(),
                      'publishedAt': source['published_at']?.toString(),
                      'accessedAt': source['accessed_at']?.toString(),
                      'evidenceRelation':
                          source['evidence_relation']?.toString() ??
                              'direct_support',
                      'locator': source['locator']?.toString(),
                      'supportingNote': source['supporting_note']?.toString(),
                    })
                .toList()
            : const <dynamic>[],
      };
    }).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> loadPublishedKnowledgeStories({
    required String mediaWorkId,
  }) async {
    final c = _db;
    if (c == null) return const <Map<String, dynamic>>[];
    final cleanId =
        _boundedText(mediaWorkId, field: 'mediaWorkId', maxLength: 256);
    final rows = await c
        .from('media_knowledge_stories')
        .select('*, media_knowledge_story_steps(*, media_knowledge_facts(*))')
        .eq('anchor_media_work_id', cleanId)
        .eq('editorial_status', 'published')
        .order('created_at', ascending: false);
    return rows.whereType<Map>().map((raw) {
      final row = Map<String, dynamic>.from(raw);
      final rawSteps = row['media_knowledge_story_steps'];
      final steps = rawSteps is List
          ? rawSteps
              .whereType<Map>()
              .map((step) => {
                    'stepNumber': step['step_number'],
                    'factId': step['fact_id']?.toString() ?? '',
                    'transitionNote': step['transition_note']?.toString(),
                  })
              .toList()
          : <dynamic>[];
      return {
        'id': row['id']?.toString() ?? '',
        'anchorMediaWorkId': row['anchor_media_work_id']?.toString() ?? cleanId,
        'title': row['title']?.toString() ?? '',
        'summary': row['summary']?.toString(),
        'spoilerScope': row['spoiler_scope']?.toString() ?? 'none',
        'steps': steps,
      };
    }).toList(growable: false);
  }

  // ---------------------------------------------------------------------------
  // SELLER PAYOUT DESTINATIONS
  // ---------------------------------------------------------------------------

  Future<void> upsertSellerPayoutDestination({
    required String accountExternalId,
    required Map<String, dynamic> destination,
  }) async {
    final c = _db;
    if (c == null) return;

    final internalAccount = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id',
            _requiredId(accountExternalId, field: 'accountExternalId'))
        .maybeSingle();
    if (internalAccount == null)
      throw StateError('Account not found in Supabase.');

    final safeMetadata = _sanitizeJsonMap(
      destination['metadata'] is Map
          ? Map<String, dynamic>.from(destination['metadata'] as Map)
          : const <String, dynamic>{},
      maxBytes: _maxSecurityMetadataBytes,
    );

    await c.from('seller_payout_destinations').upsert({
      'id': _requiredId(destination['id']?.toString(), field: 'destination.id'),
      'seller_account_id':
          _requiredId(internalAccount['id']?.toString(), field: 'accounts.id'),
      'provider_key': _boundedText(destination['providerKey']?.toString() ?? '',
          field: 'providerKey', maxLength: 100),
      'method_type': _boundedText(destination['methodType']?.toString() ?? '',
          field: 'methodType', maxLength: 100),
      'display_name': _boundedText(destination['displayName']?.toString() ?? '',
          field: 'displayName', maxLength: 240),
      'provider_account_reference':
          _nullable(destination['providerAccountReference']?.toString()),
      'masked_identifier':
          _nullable(destination['maskedIdentifier']?.toString()),
      'enabled': destination['enabled'] != false,
      'verified': destination['verified'] == true,
      'metadata': safeMetadata,
    }, onConflict: 'id');
  }

  Future<List<Map<String, dynamic>>> loadSellerPayoutDestinations({
    required String accountExternalId,
  }) async {
    final c = _db;
    if (c == null) return const <Map<String, dynamic>>[];

    final internalAccount = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id',
            _requiredId(accountExternalId, field: 'accountExternalId'))
        .maybeSingle();
    if (internalAccount == null) return const <Map<String, dynamic>>[];

    final rows = await c
        .from('seller_payout_destinations')
        .select()
        .eq('seller_account_id', internalAccount['id'])
        .order('created_at', ascending: false);

    return rows.map<Map<String, dynamic>>((raw) {
      final row = Map<String, dynamic>.from(raw);
      return {
        'id': row['id']?.toString() ?? '',
        'sellerAccountId': accountExternalId,
        'providerKey': row['provider_key']?.toString() ?? '',
        'methodType': row['method_type']?.toString() ?? '',
        'displayName': row['display_name']?.toString() ?? '',
        'providerAccountReference':
            _nullable(row['provider_account_reference']?.toString()),
        'maskedIdentifier': _nullable(row['masked_identifier']?.toString()),
        'enabled': row['enabled'] == true,
        'verified': row['verified'] == true,
        'metadata': row['metadata'] is Map
            ? Map<String, dynamic>.from(row['metadata'] as Map)
            : <String, dynamic>{},
        'createdAt': row['created_at']?.toString(),
        'updatedAt': row['updated_at']?.toString(),
      };
    }).toList();
  }

  Future<void> deleteSellerPayoutDestination({
    required String accountExternalId,
    required String destinationId,
  }) async {
    final c = _db;
    if (c == null) return;

    final internalAccount = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id',
            _requiredId(accountExternalId, field: 'accountExternalId'))
        .maybeSingle();
    if (internalAccount == null) return;

    await c
        .from('seller_payout_destinations')
        .delete()
        .eq('id', _requiredId(destinationId, field: 'destinationId'))
        .eq('seller_account_id', internalAccount['id']);
  }

  Future<void> saveShopLiveEvent({
    required String accountExternalId,
    required Map<String, dynamic> event,
  }) async {
    final c = _db;
    if (c == null) return;
    final accountRow = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id',
            _requiredId(accountExternalId, field: 'accountExternalId'))
        .maybeSingle();
    if (accountRow == null) throw StateError('Account not found in Supabase.');
    final id = _requiredId(event['id']?.toString(), field: 'event.id');
    final questions = event['questions'] is List
        ? (event['questions'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : const <Map<String, dynamic>>[];
    final poll = event['poll'] is Map
        ? Map<String, dynamic>.from(event['poll'] as Map)
        : null;
    await c.from('shop_live_events').upsert({
      'id': id,
      'seller_account_id': accountRow['id'],
      'seller_external_id': accountExternalId,
      'store_id': _boundedText(event['storeId']?.toString() ?? '',
          field: 'event.storeId', maxLength: 200),
      'store_name': _boundedText(event['storeName']?.toString() ?? '',
          field: 'event.storeName', maxLength: 240),
      'title': _boundedText(event['title']?.toString() ?? '',
          field: 'event.title', maxLength: 240),
      'description': _boundedText(event['description']?.toString() ?? '',
          field: 'event.description', maxLength: 4000),
      'status': event['status']?.toString() ?? 'scheduled',
      'scheduled_at': event['scheduledAt'],
      'started_at': event['startedAt'],
      'ended_at': event['endedAt'],
      'stream_url': _nullable(event['streamUrl']?.toString()),
      'replay_url': _nullable(event['replayUrl']?.toString()),
      'product_ids': (event['productIds'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(),
      'pinned_product_id': _nullable(event['pinnedProductId']?.toString()),
      'questions': questions,
      'poll': poll,
      'randomized_rewards_enabled': event['randomizedRewardsEnabled'] == true,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'id');
  }

  Future<List<Map<String, dynamic>>> loadShopLiveEvents() async {
    final c = _db;
    if (c == null) return const <Map<String, dynamic>>[];
    final rows = await c
        .from('shop_live_events')
        .select()
        .order('scheduled_at', ascending: true)
        .limit(100);
    return rows.map<Map<String, dynamic>>(_shopLiveEventFromRow).toList();
  }

  Future<Map<String, dynamic>?> loadShopLiveEvent(String id) async {
    final c = _db;
    if (c == null) return null;
    final row =
        await c.from('shop_live_events').select().eq('id', id).maybeSingle();
    return row == null ? null : _shopLiveEventFromRow(row);
  }

  Map<String, dynamic> _shopLiveEventFromRow(dynamic raw) {
    final row = Map<String, dynamic>.from(raw as Map);
    return <String, dynamic>{
      'id': row['id']?.toString() ?? '',
      'sellerAccountId': row['seller_external_id']?.toString() ?? '',
      'storeId': row['store_id']?.toString() ?? '',
      'storeName': row['store_name']?.toString() ?? '',
      'title': row['title']?.toString() ?? '',
      'description': row['description']?.toString() ?? '',
      'status': row['status']?.toString() ?? 'scheduled',
      'scheduledAt': row['scheduled_at']?.toString(),
      'startedAt': row['started_at']?.toString(),
      'endedAt': row['ended_at']?.toString(),
      'streamUrl': row['stream_url']?.toString(),
      'replayUrl': row['replay_url']?.toString(),
      'productIds': row['product_ids'] is List
          ? (row['product_ids'] as List)
              .map((value) => value.toString())
              .toList()
          : <String>[],
      'pinnedProductId': row['pinned_product_id']?.toString(),
      'questions': row['questions'] is List
          ? (row['questions'] as List)
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : <Map<String, dynamic>>[],
      'poll': row['poll'] is Map
          ? Map<String, dynamic>.from(row['poll'] as Map)
          : null,
      'randomizedRewardsEnabled': row['randomized_rewards_enabled'] == true,
      'createdAt': row['created_at']?.toString(),
      'updatedAt': row['updated_at']?.toString(),
    };
  }

  // ---------------------------------------------------------------------------
  // VALIDATION / SANITIZATION HELPERS
  // ---------------------------------------------------------------------------

  static void _validateAccount(
    Account account,
  ) {
    _requiredId(
      account.id,
      field: 'account.id',
    );

    _boundedText(
      account.username,
      field: 'account.username',
      maxLength: _maxNameLength,
    );

    _normalizeEmail(account.email);

    if (account.passwordHash.trim().isEmpty) {
      throw StateError(
        'Account password hash is missing.',
      );
    }

    if (account.securityAnswerHash.trim().isEmpty) {
      throw StateError(
        'Account security-answer hash is missing.',
      );
    }

    if (account.profiles.length > 7) {
      throw ArgumentError(
        'An account cannot contain more than 7 profiles.',
      );
    }
  }

  static void _validatePayment(
    PaymentSession payment,
  ) {
    _requiredId(
      payment.id,
      field: 'payment.id',
    );

    _requiredId(
      payment.accountId,
      field: 'payment.accountId',
    );

    if (!payment.amount.isFinite || payment.amount < 0) {
      throw ArgumentError(
        'Payment amount must be finite and non-negative.',
      );
    }

    final currency = payment.currency.trim();

    if (currency.length != 3) {
      throw ArgumentError(
        'Payment currency must be a 3-letter code.',
      );
    }

    if (payment.checkoutToken != null && payment.checkoutToken!.length > 2048) {
      throw ArgumentError(
        'Payment checkout token is too long.',
      );
    }
  }

  static String _requiredId(
    String? value, {
    required String field,
  }) {
    final clean = value?.trim() ?? '';

    if (clean.isEmpty) {
      throw ArgumentError(
        '$field must not be empty.',
      );
    }

    if (clean.length > _maxIdLength) {
      throw ArgumentError(
        '$field exceeds the maximum length.',
      );
    }

    _rejectControlCharacters(
      clean,
      field,
    );

    return clean;
  }

  static String _boundedText(
    String value, {
    required String field,
    required int maxLength,
  }) {
    final clean = value.trim();

    if (clean.length > maxLength) {
      throw ArgumentError(
        '$field exceeds the maximum length of $maxLength.',
      );
    }

    _rejectControlCharacters(
      clean,
      field,
    );

    return clean;
  }

  static String? _safeNullableText(
    String? value, {
    required int maxLength,
  }) {
    if (value == null) return null;

    final clean = value.trim();

    if (clean.isEmpty) return null;

    if (clean.length > maxLength) {
      throw ArgumentError(
        'Text value exceeds the maximum length of $maxLength.',
      );
    }

    _rejectControlCharacters(
      clean,
      'text',
    );

    return clean;
  }

  static String _normalizeEmail(
    String value,
  ) {
    final clean = value.trim().toLowerCase();

    if (clean.isEmpty ||
        clean.length > _maxEmailLength ||
        !clean.contains('@')) {
      throw ArgumentError(
        'A valid email address is required.',
      );
    }

    _rejectControlCharacters(
      clean,
      'email',
    );

    return clean;
  }

  static void _rejectControlCharacters(
    String value,
    String field,
  ) {
    for (final codeUnit in value.codeUnits) {
      if (codeUnit < 0x20 || codeUnit == 0x7f) {
        throw ArgumentError(
          '$field contains invalid control characters.',
        );
      }
    }
  }

  static int _safeNonNegativeInt(
    int value,
  ) {
    return value < 0 ? 0 : value;
  }

  static int _availableBytes(
    int total,
    int used,
  ) {
    final safeTotal = _safeNonNegativeInt(total);
    final safeUsed = _safeNonNegativeInt(used);

    if (safeUsed >= safeTotal) {
      return 0;
    }

    return safeTotal - safeUsed;
  }

  static List<String> _boundedStringList(
    Iterable<String> values, {
    int maxItems = 5000,
  }) {
    final result = <String>[];

    for (final value in values) {
      if (result.length >= maxItems) {
        break;
      }

      final clean = value.trim();

      if (clean.isEmpty) {
        continue;
      }

      if (clean.length > _maxIdLength) {
        continue;
      }

      try {
        _rejectControlCharacters(
          clean,
          'list value',
        );
      } catch (_) {
        continue;
      }

      if (!result.contains(clean)) {
        result.add(clean);
      }
    }

    return result;
  }

  static Map<String, dynamic> _sanitizeJsonMap(
    Map<String, dynamic> source, {
    required int maxBytes,
  }) {
    final sanitized = _sanitizeJsonValue(source);

    final map = sanitized is Map
        ? Map<String, dynamic>.from(
            sanitized,
          )
        : <String, dynamic>{};

    final encoded = jsonEncode(map);

    if (utf8.encode(encoded).length <= maxBytes) {
      return map;
    }

    // If the payload is too large, keep only fields in deterministic order
    // until the configured byte budget is reached.
    final reduced = <String, dynamic>{};

    final keys = map.keys.toList()..sort();

    for (final key in keys) {
      final candidate = Map<String, dynamic>.from(
        reduced,
      );

      candidate[key] = map[key];

      final candidateBytes = utf8
          .encode(
            jsonEncode(candidate),
          )
          .length;

      if (candidateBytes > maxBytes) {
        continue;
      }

      reduced[key] = map[key];
    }

    return reduced;
  }

  static dynamic _sanitizeJsonValue(
    dynamic value, {
    int depth = 0,
  }) {
    if (depth > 8) {
      return null;
    }

    if (value == null || value is bool || value is num) {
      return value;
    }

    if (value is String) {
      final clean = value.trim();

      if (clean.length > _maxMetadataTextLength) {
        return clean.substring(
          0,
          _maxMetadataTextLength,
        );
      }

      try {
        _rejectControlCharacters(
          clean,
          'metadata',
        );
      } catch (_) {
        return null;
      }

      return clean;
    }

    if (value is List) {
      final result = <dynamic>[];

      for (final item in value) {
        if (result.length >= 1000) {
          break;
        }

        result.add(
          _sanitizeJsonValue(
            item,
            depth: depth + 1,
          ),
        );
      }

      return result;
    }

    if (value is Map) {
      final result = <String, dynamic>{};

      for (final entry in value.entries) {
        if (result.length >= 500) {
          break;
        }

        final key = entry.key.toString().trim();

        if (key.isEmpty || key.length > 300) {
          continue;
        }

        try {
          _rejectControlCharacters(
            key,
            'metadata key',
          );
        } catch (_) {
          continue;
        }

        result[key] = _sanitizeJsonValue(
          entry.value,
          depth: depth + 1,
        );
      }

      return result;
    }

    // Do not serialize arbitrary Dart objects into persistence.
    return value.toString().length <= _maxMetadataTextLength
        ? value.toString()
        : value.toString().substring(
              0,
              _maxMetadataTextLength,
            );
  }

  static String _escapeIlike(
    String value,
  ) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
  }

  // ---------------------------------------------------------------------------
  // PARSING HELPERS
  // ---------------------------------------------------------------------------

  static String? _nullable(
    dynamic value,
  ) {
    if (value == null) return null;

    final text = value.toString().trim();

    return text.isEmpty ? null : text;
  }

  static DateTime? _parseDateTime(
    dynamic value,
  ) {
    if (value == null) return null;

    final text = value.toString().trim();

    if (text.isEmpty) return null;

    return DateTime.tryParse(
      text,
    )?.toLocal();
  }

  static double? _parseDouble(
    dynamic value,
  ) {
    if (value == null) return null;

    if (value is num) {
      return value.toDouble();
    }

    final text = value.toString().trim();

    if (text.isEmpty) return null;

    return double.tryParse(text);
  }

  static SubscriptionPlan? _subscriptionPlan(
    dynamic value,
  ) {
    final normalized = value?.toString().trim().toLowerCase();

    switch (normalized) {
      case 'monthly':
        return SubscriptionPlan.monthly;

      case 'yearly':
        return SubscriptionPlan.yearly;

      default:
        return null;
    }
  }

  static PaymentStatus? _paymentStatus(
    dynamic value,
  ) {
    final normalized = value?.toString().trim().toLowerCase();

    switch (normalized) {
      case 'pending':
        return PaymentStatus.pending;

      case 'processing':
        return PaymentStatus.processing;

      case 'succeeded':
        return PaymentStatus.succeeded;

      case 'failed':
        return PaymentStatus.failed;

      case 'cancelled':
      case 'canceled':
        return PaymentStatus.cancelled;

      default:
        return null;
    }
  }

  static String _mediaType(
    String type,
  ) {
    switch (type.trim().toLowerCase()) {
      case 'tvshow':
      case 'tv_show':
      case 'tv show':
      case 'series':
      case 'episode':
        return 'tv_show';

      case 'music':
        return 'music';

      case 'album':
        return 'album';

      case 'disc':
        return 'disc';

      default:
        return 'movie';
    }
  }

  // ---------------------------------------------------------------------------
  // PLATFORM SERVERS
  // ---------------------------------------------------------------------------

  Future<String?> _accountInternalId(String externalId) async {
    final c = _db;
    if (c == null) return null;
    final byExternal = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id', externalId)
        .maybeSingle();
    if (byExternal != null && byExternal['id'] != null) {
      return byExternal['id'].toString();
    }
    final byId = await c.from('accounts').select('id').eq('id', externalId).maybeSingle();
    return byId?['id']?.toString();
  }

  Future<Map<String, dynamic>?> loadPlatformServerContext({
    required String accountExternalId,
  }) async {
    final c = _db;
    if (c == null) return null;
    final accountId = await _accountInternalId(accountExternalId);
    if (accountId == null) return null;

    final current = await c
        .from('platform_server_assignments')
        .select('display_name, role, assigned_at, server:platform_servers(id,warehouse_id,name,status,storage_total_bytes,storage_used_bytes,ram_gb,cpu_cores,ssh_enabled,endpoint,warehouse:platform_warehouses(id,name))')
        .eq('account_id', accountId)
        .isFilter('released_at', null)
        .maybeSingle();

    final availableRows = await c
        .from('platform_servers')
        .select('id,warehouse_id,name,status,storage_total_bytes,storage_used_bytes,ram_gb,cpu_cores,ssh_enabled,endpoint,warehouse:platform_warehouses(id,name)')
        .eq('status', 'available')
        .isFilter('claimed_account_id', null)
        .order('name');

    Map<String, dynamic>? normalize(dynamic row, {String? displayName, bool assigned = false}) {
      if (row is! Map) return null;
      final data = Map<String, dynamic>.from(row);
      final warehouse = data['warehouse'];
      if (warehouse is Map) {
        data['warehouseName'] = warehouse['name']?.toString() ?? '';
      }
      data['customName'] = displayName;
      data['assignedToCurrentAccount'] = assigned;
      return data;
    }

    final currentServer = current?['server'];
    return {
      'currentServer': normalize(
        currentServer,
        displayName: current?['display_name']?.toString(),
        assigned: true,
      ),
      'availableServers': availableRows
          .map((row) => normalize(row))
          .whereType<Map<String, dynamic>>()
          .toList(growable: false),
    };
  }

  Future<Map<String, dynamic>> claimPlatformServer({
    required String accountExternalId,
    required String serverId,
    required String displayName,
  }) async {
    final c = _db;
    if (c == null) throw StateError('Supabase is not configured.');
    final accountId = await _accountInternalId(accountExternalId);
    if (accountId == null) throw StateError('Account not found.');

    final existing = await c
        .from('platform_server_assignments')
        .select('display_name, server:platform_servers(id,warehouse_id,name,status,storage_total_bytes,storage_used_bytes,ram_gb,cpu_cores,ssh_enabled,endpoint,warehouse:platform_warehouses(id,name))')
        .eq('account_id', accountId)
        .isFilter('released_at', null)
        .maybeSingle();
    if (existing != null) {
      final current = existing['server'];
      if (current is Map) {
        final normalized = Map<String, dynamic>.from(current);
        final warehouse = normalized['warehouse'];
        normalized['warehouseName'] = warehouse is Map ? warehouse['name']?.toString() ?? '' : '';
        normalized['customName'] = existing['display_name']?.toString();
        normalized['assignedToCurrentAccount'] = true;
        return {'server': normalized};
      }
      throw StateError('This account already has a server assignment.');
    }

    final claimed = await c
        .from('platform_servers')
        .update({
          'claimed_account_id': accountId,
          'claimed_at': DateTime.now().toUtc().toIso8601String(),
          'status': 'claimed',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', serverId)
        .eq('status', 'available')
        .isFilter('claimed_account_id', null)
        .select('id,warehouse_id,name,status,storage_total_bytes,storage_used_bytes,ram_gb,cpu_cores,ssh_enabled,endpoint,warehouse:platform_warehouses(id,name)')
        .maybeSingle();

    if (claimed == null) {
      throw StateError('Server is no longer available.');
    }

    await c.from('platform_server_assignments').insert({
      'account_id': accountId,
      'server_id': serverId,
      'display_name': displayName,
      'role': 'owner',
    });

    final normalized = Map<String, dynamic>.from(claimed);
    final warehouse = normalized['warehouse'];
    normalized['warehouseName'] = warehouse is Map ? warehouse['name']?.toString() ?? '' : '';
    normalized['customName'] = displayName;
    normalized['assignedToCurrentAccount'] = true;
    return {'server': normalized};
  }

  Future<Map<String, dynamic>> renamePlatformServer({
    required String accountExternalId,
    required String displayName,
  }) async {
    final c = _db;
    if (c == null) throw StateError('Supabase is not configured.');
    final accountId = await _accountInternalId(accountExternalId);
    if (accountId == null) throw StateError('Account not found.');
    final row = await c
        .from('platform_server_assignments')
        .update({'display_name': displayName})
        .eq('account_id', accountId)
        .isFilter('released_at', null)
        .select('display_name,server:platform_servers(id,warehouse_id,name,status,storage_total_bytes,storage_used_bytes,ram_gb,cpu_cores,ssh_enabled,endpoint,warehouse:platform_warehouses(id,name))')
        .maybeSingle();
    if (row == null) throw StateError('No active server assignment exists.');
    final server = Map<String, dynamic>.from(row['server'] as Map);
    final warehouse = server['warehouse'];
    server['warehouseName'] = warehouse is Map ? warehouse['name']?.toString() ?? '' : '';
    server['customName'] = row['display_name']?.toString();
    server['assignedToCurrentAccount'] = true;
    return {'server': server};
  }

  Future<void> releasePlatformServer({required String accountExternalId}) async {
    final c = _db;
    if (c == null) throw StateError('Supabase is not configured.');
    final accountId = await _accountInternalId(accountExternalId);
    if (accountId == null) throw StateError('Account not found.');
    final assignment = await c
        .from('platform_server_assignments')
        .select('server_id')
        .eq('account_id', accountId)
        .isFilter('released_at', null)
        .maybeSingle();
    if (assignment == null) return;
    final serverId = assignment['server_id']?.toString();
    await c.from('platform_server_assignments').update({
      'released_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('account_id', accountId).isFilter('released_at', null);
    if (serverId != null && serverId.isNotEmpty) {
      await c.from('platform_servers').update({
        'claimed_account_id': null,
        'claimed_at': null,
        'status': 'available',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', serverId);
    }
  }


  // ---------------------------------------------------------------------------
  // GAME RATINGS
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> loadGameRatings({
    required String accountExternalId,
    required String profileId,
  }) async {
    final c = _db;
    if (c == null) return const <Map<String, dynamic>>[];
    final accountId = await _accountInternalId(accountExternalId);
    if (accountId == null) return const <Map<String, dynamic>>[];
    final rows = await c
        .from('game_ratings')
        .select('profile_id,game_id,mode,rating,games_played,wins,losses,draws,xp,current_streak,best_streak')
        .eq('account_id', accountId)
        .eq('profile_id', profileId);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList(growable: false);
  }

  Future<void> upsertGameRating({
    required String accountExternalId,
    required Map<String, dynamic> rating,
  }) async {
    final c = _db;
    if (c == null) return;
    final accountId = await _accountInternalId(accountExternalId);
    if (accountId == null) return;
    await c.from('game_ratings').upsert({
      'account_id': accountId,
      'profile_id': rating['profileId']?.toString() ?? '',
      'game_id': rating['gameId']?.toString() ?? '',
      'mode': rating['mode']?.toString() ?? 'ranked',
      'rating': rating['rating'] ?? 500,
      'games_played': rating['gamesPlayed'] ?? 0,
      'wins': rating['wins'] ?? 0,
      'losses': rating['losses'] ?? 0,
      'draws': rating['draws'] ?? 0,
      'xp': rating['xp'] ?? 0,
      'current_streak': rating['currentStreak'] ?? 0,
      'best_streak': rating['bestStreak'] ?? 0,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'account_id,profile_id,game_id,mode');
  }

}
