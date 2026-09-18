// FILE: `Backend/supabase_store.dart`.
// Purpose: Server-side Supabase persistence for account/application metadata.
// Physical movie, TV, music and disc files remain on each user's home server.

import 'dart:io';

import 'package:supabase/supabase.dart';

import 'models/account.dart';
import 'models/account_member.dart';
import 'models/profile.dart';
import 'models/subscription.dart';
import 'models/rating.dart';

class SupabaseStore {
  SupabaseStore._();
  static final SupabaseStore instance = SupabaseStore._();

  SupabaseClient? _client;

  bool get enabled => _client != null;

  void initialize() {
    if (_client != null) return;

    final url = (Platform.environment['SUPABASE_URL'] ??
            const String.fromEnvironment('SUPABASE_URL'))
        .trim();
    final key = (Platform.environment['SUPABASE_SERVICE_ROLE_KEY'] ??
            const String.fromEnvironment('SUPABASE_SERVICE_ROLE_KEY'))
        .trim();

    if (url.isEmpty || key.isEmpty) {
      return;
    }

    _client = SupabaseClient(url, key);
  }

  SupabaseClient? get _db => _client;

  /// Loads private profile ratings belonging to the supplied account.
  Future<List<UserMediaRating>> loadUserMediaRatings(String accountId) async {
    final c = _db;
    if (c == null) return const [];
    final rows = await c.from('profile_media_ratings').select('media_id,profile_id,stars,updated_at').eq('account_id', accountId);
    return rows.whereType<Map>().map((row) => UserMediaRating(
      mediaId: row['media_id']?.toString() ?? '',
      profileId: row['profile_id']?.toString() ?? '',
      stars: row['stars'] is num ? (row['stars'] as num).toDouble() : double.tryParse(row['stars']?.toString() ?? '') ?? 0,
      updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? '') ?? DateTime.now(),
    )).toList();
  }

  /// Persists a provider rating snapshot without storing provider credentials.
  Future<void> upsertExternalRating(String mediaId, ExternalRating rating) async {
    final c = _db;
    if (c == null) return;
    await c.from('media_external_ratings').upsert({
      'media_id': mediaId,
      'provider': rating.provider.name,
      'rating_kind': rating.kind.name,
      'value': rating.value,
      'scale': rating.scale,
      'vote_count': rating.voteCount,
      'source_url': rating.url,
      'updated_at': (rating.updatedAt ?? DateTime.now()).toIso8601String(),
    }, onConflict: 'media_id,provider,rating_kind');
  }

  /// Persists a private profile rating.
  Future<void> upsertUserMediaRating(UserMediaRating rating, String accountId) async {
    final c = _db;
    if (c == null) return;
    await c.from('profile_media_ratings').upsert({
      'account_id': accountId,
      'profile_id': rating.profileId,
      'media_id': rating.mediaId,
      'stars': rating.stars,
      'updated_at': rating.updatedAt.toIso8601String(),
    }, onConflict: 'account_id,profile_id,media_id');
  }

  Future<Map<String, dynamic>?> accountByAuthUserId(
    String authUserId,
  ) async {
    final c = _db;
    if (c == null) return null;
    final row = await c
        .from('accounts')
        .select()
        .eq('auth_user_id', authUserId)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  Future<void> upsertAccount(Account account) async {
    final c = _db;
    if (c == null) return;

    final existing = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id', account.id)
        .maybeSingle();

    Map<String, dynamic> row;

    final values = <String, dynamic>{
      'external_account_id': account.id,
      'username': account.username.trim(),
      'email': account.email.trim().toLowerCase(),
      'display_name': account.username.trim(),
      'status': 'active',
    };

    if (existing == null) {
      final created = await c
          .from('accounts')
          .insert(values)
          .select()
          .single();
      row = Map<String, dynamic>.from(created);
    } else {
      final updated = await c
          .from('accounts')
          .update(values)
          .eq('id', existing['id'])
          .select()
          .single();
      row = Map<String, dynamic>.from(updated);
    }

    final internalAccountId = row['id']?.toString();
    if (internalAccountId == null || internalAccountId.isEmpty) {
      throw StateError('Supabase did not return the account row ID.');
    }

    // The account owner's login identity is separate from the account row.
    // This allows additional emails to become members without creating new
    // accounts or new home servers.
    final existingIdentity = await c
        .from('member_identities')
        .select('id')
        .eq('email', account.email.trim().toLowerCase())
        .maybeSingle();
    final identityId = existingIdentity?['id']?.toString() ??
        (await c.from('member_identities').insert({
          'email': account.email.trim().toLowerCase(),
          'password_hash': account.passwordHash,
        }).select('id').single())['id'].toString();

    await c.from('member_identities').update({
      'password_hash': account.passwordHash,
    }).eq('id', identityId);

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
        'display_name': account.username.trim(),
      });
    } else {
      await c.from('account_members').update({
        'role': 'owner',
        'status': 'active',
        'display_name': account.username.trim(),
      }).eq('id', existingOwner['id']);
    }

    // Every account gets exactly one home-server row and one account wishlist.
    // These rows contain metadata only; physical media stays on the home server.
    final existingServer = await c
        .from('servers')
        .select('id')
        .eq('account_id', internalAccountId)
        .maybeSingle();
    if (existingServer == null) {
      final server = await c.from('servers').insert({
        'account_id': internalAccountId,
        'name': 'Home Server',
        'status': 'pending',
        'server_type': 'home',
      }).select('id').single();
      await c.from('server_storage').upsert({
        'server_id': server['id'],
        'total_bytes': account.storageLimitBytes,
        'used_bytes': account.storageUsedBytes,
        'available_bytes': account.storageLimitBytes > account.storageUsedBytes
            ? account.storageLimitBytes - account.storageUsedBytes
            : 0,
      }, onConflict: 'server_id');
    }

    await c.from('wishlists').upsert(
      {'account_id': internalAccountId},
      onConflict: 'account_id',
    );

    // Sensitive credentials live in the backend-only table. The HTTP API
    // never returns these values.
    await c.from('account_private_credentials').upsert(
      {
        'account_id': internalAccountId,
        'external_account_id': account.id,
        'password_hash': account.passwordHash,
        'security_question': account.securityQuestion,
        'security_answer_hash': account.securityAnswerHash,
      },
      onConflict: 'external_account_id',
    );

    final subscription = account.subscription;
    if (subscription != null) {
      await c.from('subscriptions').upsert(
        {
          'account_id': internalAccountId,
          'plan': subscription.plan.name,
          'status': subscription.active ? 'active' : 'inactive',
          'current_period_start': subscription.startedAt.toUtc().toIso8601String(),
          'current_period_end': subscription.expiresAt.toUtc().toIso8601String(),
        },
        onConflict: 'account_id',
      );
    }

    // Persist each profile as a first-class database row.
    final existingProfiles = await c
        .from('profiles')
        .select('id,external_profile_id')
        .eq('account_id', internalAccountId);

    final existingExternalIds = <String>{};
    for (final raw in existingProfiles) {
      final id = raw['external_profile_id']?.toString();
      if (id != null && id.isNotEmpty) existingExternalIds.add(id);
    }

    final activeProfileIds = <String>{};

    for (final profile in account.profiles) {
      activeProfileIds.add(profile.id);
      await c.from('profiles').upsert(
        {
          'account_id': internalAccountId,
          'external_profile_id': profile.id,
          'name': profile.name.trim(),
          'avatar_url': _nullable(profile.avatarUrl),
          'is_active': true,
        },
        onConflict: 'external_profile_id',
      );
    }

    // Remove profile rows deleted through the backend API. Cascading foreign
    // keys clean their UI settings, watch state and other profile data.
    for (final oldId in existingExternalIds.difference(activeProfileIds)) {
      await c
          .from('profiles')
          .delete()
          .eq('external_profile_id', oldId);
    }

    // Preserve the current account-wide application state in the existing
    // snapshot table as an audit/recovery copy without exposing credentials.
    await syncAccountSnapshot(account);
  }

  Future<List<Account>> loadAccounts() async {
    final c = _db;
    if (c == null) return const <Account>[];

    final accountRows = await c.from('accounts').select();
    final result = <Account>[];

    for (final raw in accountRows) {
      final row = Map<String, dynamic>.from(raw);
      final externalId = row['external_account_id']?.toString();
      if (externalId == null || externalId.isEmpty) continue;

      final credentialRow = await c
          .from('account_private_credentials')
          .select()
          .eq('account_id', row['id'])
          .maybeSingle();

      if (credentialRow == null) {
        // Accounts created directly through Supabase Auth are intentionally not
        // imported into the custom backend until their private backend
        // credential record exists.
        continue;
      }

      final profileRows = await c
          .from('profiles')
          .select()
          .eq('account_id', row['id'])
          .eq('is_active', true)
          .order('created_at');

      final profiles = <Profile>[];
      for (final profileRaw in profileRows) {
        final profileRow = Map<String, dynamic>.from(profileRaw);
        final profileExternalId =
            profileRow['external_profile_id']?.toString() ?? '';
        if (profileExternalId.isEmpty) continue;

        profiles.add(
          Profile(
            id: profileExternalId,
            name: profileRow['name']?.toString() ?? '',
            avatarUrl: _nullable(profileRow['avatar_url']),
          ),
        );
      }

      Subscription? subscription;
      final subscriptionRow = await c
          .from('subscriptions')
          .select()
          .eq('account_id', row['id'])
          .maybeSingle();

      if (subscriptionRow != null) {
        final plan = subscriptionRow['plan']?.toString().toLowerCase() == 'yearly'
            ? SubscriptionPlan.yearly
            : SubscriptionPlan.monthly;
        final startedAt = DateTime.tryParse(
              subscriptionRow['current_period_start']?.toString() ?? '',
            ) ??
            DateTime.now();
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

      final account = Account(
        id: externalId,
        username: row['username']?.toString() ?? '',
        email: row['email']?.toString() ?? '',
        passwordHash: credentialRow['password_hash']?.toString() ?? '',
        securityQuestion:
            credentialRow['security_question']?.toString() ?? '',
        securityAnswerHash:
            credentialRow['security_answer_hash']?.toString() ?? '',
        profiles: profiles,
        subscription: subscription,
      );

      result.add(account);
    }

    return result;
  }

  /// Loads individual login identities and their account memberships.
  /// A single identity may belong to multiple accounts.
  Future<List<MemberLoginRecord>> loadMemberLogins() async {
    final c = _db;
    if (c == null) return const <MemberLoginRecord>[];

    final identities = await c
        .from('member_identities')
        .select('id,email,password_hash');
    final members = await c
        .from('account_members')
        .select('id,account_id,identity_id,role,status');

    final result = <MemberLoginRecord>[];
    for (final rawMember in members) {
      final member = Map<String, dynamic>.from(rawMember);
      final identityId = member['identity_id']?.toString() ?? '';
      Map<String, dynamic>? identityRaw;
      for (final rawIdentity in identities) {
        final candidate = Map<String, dynamic>.from(rawIdentity);
        if (candidate['id']?.toString() == identityId) {
          identityRaw = candidate;
          break;
        }
      }
      if (identityRaw == null) continue;
      final email = identityRaw['email']?.toString().trim().toLowerCase() ?? '';
      final hash = identityRaw['password_hash']?.toString() ?? '';
      final accountId = member['account_id']?.toString() ?? '';
      if (email.isEmpty || hash.isEmpty || accountId.isEmpty) continue;
      result.add(MemberLoginRecord(
        memberId: member['id']?.toString() ?? '',
        accountId: accountId,
        email: email,
        passwordHash: hash,
        role: member['role']?.toString() ?? 'member',
        status: member['status']?.toString() ?? 'active',
      ));
    }
    return result;
  }

  Future<String> createMemberInvitation({
    required String accountExternalId,
    required String email,
    String role = 'member',
    required String tokenHash,
    required DateTime expiresAt,
  }) async {
    final c = _db;
    if (c == null) throw StateError('Supabase is not configured.');
    final account = await c.from('accounts').select('id').eq(
      'external_account_id', accountExternalId,
    ).maybeSingle();
    if (account == null) throw StateError('Account not found in Supabase.');
    final cleanEmail = email.trim().toLowerCase();
    final existingIdentity = await c.from('member_identities').select('id').eq(
      'email', cleanEmail,
    ).maybeSingle();
    if (existingIdentity != null) {
      final existingMembership = await c.from('account_members')
          .select('id,status')
          .eq('account_id', account['id'])
          .eq('identity_id', existingIdentity['id'])
          .maybeSingle();
      if (existingMembership != null && existingMembership['status'] == 'active') {
        throw StateError('That email is already a member of this account.');
      }
    }
    final invitation = await c.from('account_invitations').insert({
      'account_id': account['id'],
      'email': cleanEmail,
      'role': role == 'admin' ? 'admin' : 'member',
      'token_hash': tokenHash,
      'expires_at': expiresAt.toUtc().toIso8601String(),
      'status': 'pending',
    }).select('id').single();
    return invitation['id'].toString();
  }

  Future<Map<String, dynamic>> acceptMemberInvitation({
    required String tokenHash,
    required String email,
    String? passwordHash,
  }) async {
    final c = _db;
    if (c == null) throw StateError('Supabase is not configured.');
    final invite = await c.from('account_invitations').select()
        .eq('token_hash', tokenHash)
        .eq('status', 'pending')
        .maybeSingle();
    if (invite == null) throw StateError('Invitation is invalid or has expired.');
    final expiresAt = DateTime.tryParse(invite['expires_at']?.toString() ?? '');
    if (expiresAt == null || !DateTime.now().toUtc().isBefore(expiresAt.toUtc())) {
      await c.from('account_invitations').update({'status': 'expired'}).eq('id', invite['id']);
      throw StateError('Invitation has expired.');
    }
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail != invite['email'].toString().trim().toLowerCase()) {
      throw StateError('Invitation email does not match.');
    }
    var identity = await c.from('member_identities').select('id,email,password_hash')
        .eq('email', cleanEmail).maybeSingle();
    if (identity == null) {
      if (passwordHash == null || passwordHash.isEmpty) {
        throw StateError('A password is required to create this login.');
      }
      identity = await c.from('member_identities').insert({
        'email': cleanEmail,
        'password_hash': passwordHash,
      }).select('id,email,password_hash').single();
    }
    final member = await c.from('account_members').upsert({
      'account_id': invite['account_id'],
      'identity_id': identity['id'],
      'role': invite['role'] ?? 'member',
      'status': 'active',
    }, onConflict: 'account_id,identity_id').select('id,account_id,role,status').single();
    await c.from('account_invitations').update({
      'status': 'accepted',
      'accepted_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', invite['id']);
    return {
      'memberId': member['id'].toString(),
      'accountId': invite['account_id'].toString(),
      'email': cleanEmail,
      'role': member['role']?.toString() ?? 'member',
      '_passwordHash': identity['password_hash']?.toString() ?? '',
    };
  }

  Future<List<Map<String, dynamic>>> listAccountMembers(String accountExternalId) async {
    final c = _db;
    if (c == null) return const [];
    final account = await c.from('accounts').select('id').eq(
      'external_account_id', accountExternalId,
    ).maybeSingle();
    if (account == null) throw StateError('Account not found in Supabase.');
    final members = await c.from('account_members').select('id,identity_id,role,status,display_name,profile_id')
        .eq('account_id', account['id']);
    final identities = await c.from('member_identities').select('id,email');
    final result = <Map<String, dynamic>>[];
    for (final raw in members) {
      final member = Map<String, dynamic>.from(raw);
      final identityId = member['identity_id']?.toString() ?? '';
      for (final rawIdentity in identities) {
        final identity = Map<String, dynamic>.from(rawIdentity);
        if (identity['id']?.toString() != identityId) continue;
        result.add({
          'id': member['id'],
          'email': identity['email'],
          'role': member['role'],
          'status': member['status'],
          'displayName': member['display_name'],
          'profileId': member['profile_id'],
        });
        break;
      }
    }
    return result;
  }

  Future<void> deleteAccount(String externalAccountId) async {
    final c = _db;
    if (c == null) return;

    final row = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id', externalAccountId)
        .maybeSingle();

    if (row == null) return;

    await c.from('accounts').delete().eq('id', row['id']);
  }

  Future<void> updateProfile({
    required String accountExternalId,
    required String profileExternalId,
    required String name,
    String? avatarUrl,
  }) async {
    final c = _db;
    if (c == null) return;

    final account = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id', accountExternalId)
        .maybeSingle();
    if (account == null) throw StateError('Account not found in Supabase.');

    final profile = await c
        .from('profiles')
        .select('id')
        .eq('external_profile_id', profileExternalId)
        .eq('account_id', account['id'])
        .maybeSingle();
    if (profile == null) throw StateError('Profile not found in Supabase.');

    await c.from('profiles').update({
      'name': name.trim(),
      'avatar_url': _nullable(avatarUrl),
      'is_active': true,
    }).eq('id', profile['id']);
  }

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

    final account = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id', accountExternalId)
        .maybeSingle();
    if (account == null) throw StateError('Account not found in Supabase.');

    final server = await c
        .from('servers')
        .select('id')
        .eq('account_id', account['id'])
        .maybeSingle();

    late String serverId;
    if (server == null) {
      final created = await c.from('servers').insert({
        'account_id': account['id'],
        'name': 'Home Server',
        'status': 'online',
        'server_type': 'home',
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      }).select('id').single();
      serverId = created['id'].toString();
    } else {
      serverId = server['id'].toString();
      await c.from('servers').update({
        'status': 'online',
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', serverId);
    }

    final canonicalKey =
        '${type.trim().toLowerCase()}:${title.trim().toLowerCase()}:${year ?? ''}';

    final catalog = await c
        .from('media_catalog')
        .select('id')
        .eq('canonical_key', canonicalKey)
        .maybeSingle();

    late String catalogId;
    final mediaType = _mediaType(type);
    final catalogValues = <String, dynamic>{
      'canonical_key': canonicalKey,
      'title': title.trim(),
      'media_type': mediaType,
      'year': year,
      'description': _nullable(description),
      'poster_url': _nullable(posterUrl),
      'metadata': <String, dynamic>{
        ...?metadata,
        if (trailerUrl != null && trailerUrl.trim().isNotEmpty)
          'trailerUrl': trailerUrl.trim(),
        if (fileSizeBytes != null) 'fileSizeBytes': fileSizeBytes,
      },
    };

    if (catalog == null) {
      final created = await c
          .from('media_catalog')
          .insert(catalogValues)
          .select('id')
          .single();
      catalogId = created['id'].toString();
    } else {
      catalogId = catalog['id'].toString();
      await c.from('media_catalog').update(catalogValues).eq('id', catalogId);
    }

    await c.from('server_media').upsert(
      {
        'server_id': serverId,
        'media_catalog_id': catalogId,
        'server_media_id': relativeMediaId,
        'availability': 'available',
        'metadata': <String, dynamic>{
          ...?metadata,
          if (fileSizeBytes != null) 'fileSizeBytes': fileSizeBytes,
        },
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

    final account = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id', accountExternalId)
        .maybeSingle();
    if (account == null) throw StateError('Account not found in Supabase.');

    final server = await c
        .from('servers')
        .select('id')
        .eq('account_id', account['id'])
        .maybeSingle();
    if (server == null) throw StateError('Home server not found in Supabase.');

    final serverMedia = await c
        .from('server_media')
        .select('id,media_catalog_id')
        .eq('server_id', server['id'])
        .eq('server_media_id', relativeMediaId)
        .maybeSingle();
    if (serverMedia == null) throw StateError('Media is not indexed for this home server.');

    final values = <String, dynamic>{};
    if (title != null) values['title'] = title.trim();
    if (year != null) values['year'] = year;
    if (description != null) values['description'] = _nullable(description);
    if (posterUrl != null) values['poster_url'] = _nullable(posterUrl);

    final current = await c
        .from('media_catalog')
        .select('metadata')
        .eq('id', serverMedia['media_catalog_id'])
        .single();
    final nextMetadata = <String, dynamic>{
      if (current['metadata'] is Map) ...Map<String, dynamic>.from(current['metadata'] as Map),
      ...?metadata,
    };
    if (trailerUrl != null) {
      nextMetadata['trailerUrl'] = trailerUrl.trim();
    }
    values['metadata'] = nextMetadata;

    if (values.isNotEmpty) {
      await c.from('media_catalog')
          .update(values)
          .eq('id', serverMedia['media_catalog_id']);
    }

    if (metadata != null) {
      await c.from('server_media').update({
        'metadata': metadata,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', serverMedia['id']);
    }
  }

  Future<void> deleteServerMedia({
    required String accountExternalId,
    required String relativeMediaId,
  }) async {
    final c = _db;
    if (c == null) return;

    final account = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id', accountExternalId)
        .maybeSingle();
    if (account == null) return;

    final server = await c
        .from('servers')
        .select('id')
        .eq('account_id', account['id'])
        .maybeSingle();
    if (server == null) return;

    await c
        .from('server_media')
        .delete()
        .eq('server_id', server['id'])
        .eq('server_media_id', relativeMediaId);
  }

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

    final account = await c
        .from('accounts')
        .select('id')
        .eq('external_account_id', accountExternalId)
        .maybeSingle();
    if (account == null) return;

    final profile = await c
        .from('profiles')
        .select('id')
        .eq('account_id', account['id'])
        .eq('external_profile_id', profileExternalId)
        .maybeSingle();
    if (profile == null) return;

    await c.from('profile_customization_snapshots').upsert(
      {
        'profile_id': profile['id'],
        'home_configuration': home ?? <String, dynamic>{},
        'details_configuration': details ?? <String, dynamic>{},
        'platform_configuration': platform ?? <String, dynamic>{},
        'music_configuration': music ?? <String, dynamic>{},
      },
      onConflict: 'profile_id',
    );
  }

  Future<void> syncAccountSnapshot(
    Account account, {
    Map<String, dynamic>? clientSnapshot,
  }) async {
    final c = _db;
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
        'profiles': account.profiles
            .map((p) => {
                  'external_profile_id': p.id,
                  'name': p.name,
                  'avatar_url': p.avatarUrl,
                })
            .toList(),
        'shared_media_ids': List<String>.from(account.sharedMediaIds),
        'wishlist_media_ids': List<String>.from(account.wishlistMediaIds),
        'wishlist_recommendation_ids':
            List<String>.from(account.wishlistRecommendationIds),
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
    final c = _db;
    if (c == null) return const [];
    final result = await c.rpc('check_group_watch_compatibility', params: {
      'p_media_catalog_id': mediaCatalogId,
      'p_version_key': versionKey,
      'p_profile_ids': profileIds,
    });
    return result is List ? result : const [];
  }

  static String? _nullable(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static String _mediaType(String type) {
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
}
