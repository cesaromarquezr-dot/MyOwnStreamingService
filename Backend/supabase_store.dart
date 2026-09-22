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

import 'package:supabase/supabase.dart';

import 'models/account.dart';
import 'models/account_member.dart';
import 'models/payment_session.dart';
import 'models/profile.dart';
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

  // ---------------------------------------------------------------------------
  // ACCOUNT LOOKUP
  // ---------------------------------------------------------------------------

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
    };

    if (existing == null) {
      final created = await c
          .from('accounts')
          .insert(values)
          .select()
          .single();

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
      'processor_transaction_id':
          _safeNullableText(
        payment.processorTransactionId,
        maxLength: 500,
      ),
      'failure_reason':
          _safeNullableText(
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
      final externalId =
          row['external_account_id']?.toString().trim() ?? '';

      if (internalId.isEmpty || externalId.isEmpty) {
        continue;
      }

      externalAccountIdsByInternalId[internalId] = externalId;
    }

    final paymentRows = await c
        .from('payments')
        .select()
        .order(
          'created_at',
          ascending: false,
        );

    final result = <PaymentSession>[];

    for (final raw in paymentRows) {
      try {
        final row = Map<String, dynamic>.from(raw);

        final paymentId =
            row['provider_payment_id']?.toString().trim() ?? '';

        final internalAccountId =
            row['account_id']?.toString().trim() ?? '';

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
            processorTransactionId:
                _nullable(row['processor_transaction_id']),
            failureReason:
                _nullable(row['failure_reason']),
            checkoutToken:
                row['checkout_token']?.toString() ?? '',
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

        final externalId =
            row['external_account_id']?.toString().trim() ?? '';

        if (externalId.isEmpty) {
          continue;
        }

        final internalAccountId =
            row['id']?.toString().trim() ?? '';

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
          final profileRow =
              Map<String, dynamic>.from(profileRaw);

          final profileExternalId =
              profileRow['external_profile_id']
                      ?.toString()
                      .trim() ??
                  '';

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
          final plan =
              _subscriptionPlan(subscriptionRow['plan']);

          if (plan != null) {
            final startedAt = DateTime.tryParse(
                  subscriptionRow['current_period_start']
                          ?.toString() ??
                      '',
                ) ??
                DateTime.now().toUtc();

            final expiresAt = DateTime.tryParse(
                  subscriptionRow['current_period_end']
                          ?.toString() ??
                      '',
                ) ??
                startedAt;

            subscription = Subscription(
              id: subscriptionRow['id']?.toString() ??
                  'sub_${externalId.replaceAll('-', '')}',
              plan: plan,
              startedAt: startedAt.toLocal(),
              expiresAt: expiresAt.toLocal(),
              active:
                  subscriptionRow['status']?.toString() ==
                      'active',
            );
          }
        }

        final account = Account(
          id: externalId,
          username: row['username']?.toString() ?? '',
          email: row['email']?.toString() ?? '',
          passwordHash:
              credentialRow['password_hash']?.toString() ?? '',
          securityQuestion:
              credentialRow['security_question']?.toString() ?? '',
          securityAnswerHash:
              credentialRow['security_answer_hash']?.toString() ?? '',
          mfaEnabled:
              credentialRow['mfa_enabled'] == true,
          mfaChallengeHash:
              credentialRow['mfa_challenge_hash']
                      ?.toString() ??
                  '',
          mfaChallengeExpiresAt:
              DateTime.tryParse(
            credentialRow['mfa_challenge_expires_at']
                    ?.toString() ??
                '',
          ),
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

    final identities =
        await c.from('member_identities').select(
          'id,email,password_hash',
        );

    final members = await c.from('account_members').select(
      'id,account_id,identity_id,role,status',
    );

    final identityById = <String, Map<String, dynamic>>{};

    for (final rawIdentity in identities) {
      final identity =
          Map<String, dynamic>.from(rawIdentity);

      final identityId =
          identity['id']?.toString().trim() ?? '';

      if (identityId.isNotEmpty) {
        identityById[identityId] = identity;
      }
    }

    final result = <MemberLoginRecord>[];

    for (final rawMember in members) {
      final member =
          Map<String, dynamic>.from(rawMember);

      final identityId =
          member['identity_id']?.toString().trim() ?? '';

      final identity = identityById[identityId];

      if (identity == null) {
        continue;
      }

      final email =
          identity['email']
                  ?.toString()
                  .trim()
                  .toLowerCase() ??
              '';

      final hash =
          identity['password_hash']?.toString() ?? '';

      final accountId =
          member['account_id']?.toString().trim() ?? '';

      if (email.isEmpty ||
          hash.isEmpty ||
          accountId.isEmpty) {
        continue;
      }

      result.add(
        MemberLoginRecord(
          memberId:
              member['id']?.toString() ?? '',
          accountId: accountId,
          email: email,
          passwordHash: hash,
          role:
              member['role']?.toString() ??
                  'member',
          status:
              member['status']?.toString() ??
                  'active',
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
          existingMembership['status']
                  ?.toString()
                  .toLowerCase() ==
              'active') {
        throw StateError(
          'That email is already a member of this account.',
        );
      }
    }

    final normalizedRole =
        role.trim().toLowerCase() == 'admin'
            ? 'admin'
            : 'member';

    final invitation = await c
        .from('account_invitations')
        .insert({
          'account_id': internalAccountId,
          'email': cleanEmail,
          'role': normalizedRole,
          'token_hash': cleanTokenHash,
          'expires_at':
              expiresAt.toUtc().toIso8601String(),
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
        !DateTime.now()
            .toUtc()
            .isBefore(expiresAt.toUtc())) {
      await c
          .from('account_invitations')
          .update({
            'status': 'expired',
          })
          .eq(
            'id',
            invite['id'],
          );

      throw StateError(
        'Invitation has expired.',
      );
    }

    final invitationEmail =
        invite['email']
                ?.toString()
                .trim()
                .toLowerCase() ??
            '';

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
      if (passwordHash == null ||
          passwordHash.isEmpty) {
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
            'role':
                invite['role']?.toString() ??
                    'member',
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
      'accepted_at':
          DateTime.now().toUtc().toIso8601String(),
    }).eq(
      'id',
      invite['id'],
    );

    return {
      'memberId': member['id'].toString(),
      'accountId': accountId,
      'email': cleanEmail,
      'role':
          member['role']?.toString() ??
              'member',

      // Consumed by AuthService and immediately removed from the result
      // before it reaches any HTTP response.
      '_passwordHash':
          identity['password_hash']?.toString() ??
              '',
    };
  }

  // ---------------------------------------------------------------------------
  // ACCOUNT MEMBERS
  // ---------------------------------------------------------------------------

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

    final identities =
        await c.from('member_identities').select(
      'id,email',
    );

    final identityById = <String, Map<String, dynamic>>{};

    for (final rawIdentity in identities) {
      final identity =
          Map<String, dynamic>.from(rawIdentity);

      final identityId =
          identity['id']?.toString().trim() ?? '';

      if (identityId.isNotEmpty) {
        identityById[identityId] = identity;
      }
    }

    final result = <Map<String, dynamic>>[];

    for (final raw in members) {
      final member =
          Map<String, dynamic>.from(raw);

      final identityId =
          member['identity_id']?.toString().trim() ?? '';

      final identity = identityById[identityId];

      if (identity == null) {
        continue;
      }

      result.add({
        'id': member['id'],
        'email': identity['email'],
        'role': member['role'],
        'status': member['status'],
        'displayName': member['display_name'],
        'profileId': member['profile_id'],
      });
    }

    return result;
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

    if (year != null &&
        (year < 1800 || year > 3000)) {
      throw ArgumentError.value(
        year,
        'year',
        'must be between 1800 and 3000',
      );
    }

    if (fileSizeBytes != null &&
        fileSizeBytes < 0) {
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
            'last_seen_at':
                DateTime.now().toUtc().toIso8601String(),
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
        'last_seen_at':
            DateTime.now().toUtc().toIso8601String(),
      }).eq(
        'id',
        serverId,
      );
    }

    final normalizedType =
        cleanType.trim().toLowerCase();

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
      if (trailerUrl != null &&
          trailerUrl.trim().isNotEmpty)
        'trailerUrl': _boundedText(
          trailerUrl,
          field: 'trailerUrl',
          maxLength: 2048,
        ),
      if (fileSizeBytes != null)
        'fileSizeBytes': fileSizeBytes,
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

      await c
          .from('media_catalog')
          .update(catalogValues)
          .eq(
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
        'last_seen_at':
            DateTime.now().toUtc().toIso8601String(),
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

    if (year != null &&
        (year < 1800 || year > 3000)) {
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
      currentMetadata['trailerUrl'] =
          _boundedText(
        trailerUrl,
        field: 'trailerUrl',
        maxLength: 2048,
      );
    }

    values['metadata'] = currentMetadata;

    if (values.isNotEmpty) {
      await c
          .from('media_catalog')
          .update(values)
          .eq(
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
        'updated_at':
            DateTime.now().toUtc().toIso8601String(),
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

    final safeClientSnapshot =
        _sanitizeJsonMap(
      clientSnapshot ?? const {},
      maxBytes: _maxSnapshotBytes,
    );

    final safeNotifications =
        account.notifications
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
        'storage_limit_bytes':
            _safeNonNegativeInt(
          account.storageLimitBytes,
        ),
        'storage_used_bytes':
            _safeNonNegativeInt(
          account.storageUsedBytes,
        ),
        'storage_request_pending':
            account.storageRequestPending,
        'storage_requested_terabytes':
            account.storageRequestedTerabytes < 0
                ? 0
                : account.storageRequestedTerabytes,
        'storage_request_fee_usd':
            account.storageRequestFeeUsd.isFinite &&
                    account.storageRequestFeeUsd >= 0
                ? account.storageRequestFeeUsd
                : 0,
        'storage_request_status':
            _safeNullableText(
              account.storageRequestStatus,
              maxLength: 100,
            ),
        'storage_request_at':
            account.storageRequestAt
                ?.toUtc()
                .toIso8601String(),
        'profiles': account.profiles
            .map(
              (profile) => {
                'external_profile_id':
                    _requiredId(
                  profile.id,
                  field: 'profile.id',
                ),
                'name': _boundedText(
                  profile.name,
                  field: 'profile.name',
                  maxLength: _maxNameLength,
                ),
                'avatar_url':
                    _safeNullableText(
                  profile.avatarUrl,
                  maxLength: 2048,
                ),
              },
            )
            .toList(),
        'shared_media_ids':
            _boundedStringList(
          account.sharedMediaIds,
        ),
        'wishlist_media_ids':
            _boundedStringList(
          account.wishlistMediaIds,
        ),
        'wishlist_recommendation_ids':
            _boundedStringList(
          account.wishlistRecommendationIds,
        ),
        'notifications': safeNotifications,
        'client_snapshot':
            safeClientSnapshot,
        'synced_at':
            DateTime.now()
                .toUtc()
                .toIso8601String(),
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
        'p_media_catalog_id':
            cleanMediaCatalogId,
        'p_version_key':
            cleanVersionKey,
        'p_profile_ids':
            cleanProfileIds,
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

    final merged =
        <String, Map<String, dynamic>>{};

    for (final raw in [
      ...rows,
      ...typeRows,
    ]) {
      final row =
          Map<String, dynamic>.from(raw);

      final entityType =
          row['entity_type']
                  ?.toString()
                  .trim() ??
              '';

      final entityId =
          row['entity_id']
                  ?.toString()
                  .trim() ??
              '';

      final accountExternalId =
          row['account_external_id']
                  ?.toString()
                  .trim() ??
              '';

      if (entityType.isEmpty ||
          entityId.isEmpty) {
        continue;
      }

      final key =
          '$entityType:$entityId:$accountExternalId';

      merged[key] = row;
    }

    final result = <Map<String, dynamic>>[];

    for (final raw in merged.values) {
      final row =
          Map<String, dynamic>.from(raw);

      final entity = ShopEntity(
        type:
            _boundedText(
              row['entity_type']
                      ?.toString() ??
                  'other',
              field: 'entity_type',
              maxLength: 100,
            ),
        id:
            _boundedText(
              row['entity_id']
                      ?.toString() ??
                  '',
              field: 'entity_id',
              maxLength: _maxIdLength,
            ),
        name:
            _boundedText(
              row['name']?.toString() ?? '',
              field: 'name',
              maxLength: _maxNameLength,
            ),
        subtitle:
            _boundedText(
              row['subtitle']?.toString() ?? '',
              field: 'subtitle',
              maxLength: _maxNameLength,
            ),
        accountExternalId:
            _safeNullableText(
              row['account_external_id'],
              maxLength: _maxIdLength,
            ),
        isPublic:
            row['is_public'] != false,
      );

      if (entity.id.isEmpty ||
          entity.name.isEmpty) {
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

    final now =
        DateTime.now().toUtc().toIso8601String();

    final rows = <Map<String, dynamic>>[];

    for (final entity in entities) {
      final type = _boundedText(
        entity.type.trim().isEmpty
            ? 'other'
            : entity.type.trim().toLowerCase(),
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

      final scoped =
          type == 'collection' ||
          type == 'playlist';

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

    if (!payment.amount.isFinite ||
        payment.amount < 0) {
      throw ArgumentError(
        'Payment amount must be finite and non-negative.',
      );
    }

    final currency =
        payment.currency.trim();

    if (currency.length != 3) {
      throw ArgumentError(
        'Payment currency must be a 3-letter code.',
      );
    }

    if (payment.checkoutToken != null &&
        payment.checkoutToken!.length > 2048) {
      throw ArgumentError(
        'Payment checkout token is too long.',
      );
    }
  }

  static String _requiredId(
    String? value, {
    required String field,
  }) {
    final clean =
        value?.trim() ?? '';

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
      if (codeUnit < 0x20 ||
          codeUnit == 0x7f) {
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
    final safeTotal =
        _safeNonNegativeInt(total);
    final safeUsed =
        _safeNonNegativeInt(used);

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
    final sanitized =
        _sanitizeJsonValue(source);

    final map = sanitized is Map
        ? Map<String, dynamic>.from(
            sanitized,
          )
        : <String, dynamic>{};

    final encoded =
        jsonEncode(map);

    if (utf8
            .encode(encoded)
            .length <=
        maxBytes) {
      return map;
    }

    // If the payload is too large, keep only fields in deterministic order
    // until the configured byte budget is reached.
    final reduced =
        <String, dynamic>{};

    final keys = map.keys.toList()
      ..sort();

    for (final key in keys) {
      final candidate =
          Map<String, dynamic>.from(
        reduced,
      );

      candidate[key] = map[key];

      final candidateBytes =
          utf8.encode(
        jsonEncode(candidate),
      ).length;

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

    if (value == null ||
        value is bool ||
        value is num) {
      return value;
    }

    if (value is String) {
      final clean = value.trim();

      if (clean.length >
          _maxMetadataTextLength) {
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
      final result =
          <String, dynamic>{};

      for (final entry
          in value.entries) {
        if (result.length >= 500) {
          break;
        }

        final key =
            entry.key.toString().trim();

        if (key.isEmpty ||
            key.length > 300) {
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

        result[key] =
            _sanitizeJsonValue(
          entry.value,
          depth: depth + 1,
        );
      }

      return result;
    }

    // Do not serialize arbitrary Dart objects into persistence.
    return value.toString().length <=
            _maxMetadataTextLength
        ? value.toString()
        : value
            .toString()
            .substring(
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

    final text =
        value.toString().trim();

    return text.isEmpty
        ? null
        : text;
  }

  static DateTime? _parseDateTime(
    dynamic value,
  ) {
    if (value == null) return null;

    final text =
        value.toString().trim();

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

    final text =
        value.toString().trim();

    if (text.isEmpty) return null;

    return double.tryParse(text);
  }

  static SubscriptionPlan? _subscriptionPlan(
    dynamic value,
  ) {
    final normalized =
        value
            ?.toString()
            .trim()
            .toLowerCase();

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
    final normalized =
        value
            ?.toString()
            .trim()
            .toLowerCase();

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
}
