// FILE: `Backend/database/database.dart`.
// Purpose: Implements the database portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.
//
// The database maintains the backend's authoritative in-memory state while
// Supabase provides durable persistence for the entities that currently have
// a SupabaseStore implementation.
//
// ARM ingestion state is also modeled here so physical release, physical
// disc, disc content, rip-job and canonical music-recording relationships
// survive across individual service calls during the backend process.
//
// Durable ARM persistence can be added to SupabaseStore/database migrations
// without changing the public Database API defined here.

import 'dart:async';
import 'dart:developer' as developer;

import '../arm/arm_models.dart';
import '../models/account.dart';
import '../models/account_member.dart';
import '../models/media.dart';
import '../models/group_recommendation.dart';
import '../models/group_watch_session.dart';
import '../models/group_chat_room.dart';
import '../models/payment_session.dart';
import '../models/subscription.dart';
import '../models/profile.dart';
import '../models/remote_worker.dart';
import '../models/review.dart';
import '../supabase_store.dart';

class SessionRecord {
  final String token;
  final String accountId;

  final DateTime createdAt;
  final DateTime expiresAt;

  final String ipAddress;
  final String userAgent;

  DateTime lastUsedAt;

  SessionRecord({
    required this.token,
    required this.accountId,
    required this.createdAt,
    required this.expiresAt,
    required this.lastUsedAt,
    this.ipAddress = 'unknown',
    this.userAgent = 'unknown',
  });

  bool get isExpired {
    return !DateTime.now().isBefore(expiresAt);
  }

  /// Performs `toJson` for this feature. Update this documentation when its
  /// contract changes.
  Map<String, dynamic> toJson() {
    return {
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'lastUsedAt': lastUsedAt.toIso8601String(),
      'ipAddress': ipAddress,
      'userAgent': userAgent,
    };
  }
}

class Database {
  Database._();

  static final Database instance = Database._();

  // ---------------------------------------------------------------------------
  // SESSION CONFIGURATION
  // ---------------------------------------------------------------------------

  // First-pass session lifetime.
  //
  // This is an absolute lifetime. Later we can add:
  // - trusted devices
  // - idle timeout
  // - device revocation
  // - suspicious-login detection
  // - per-device sessions
  static const Duration defaultSessionLifetime = Duration(days: 30);

  // ---------------------------------------------------------------------------
  // PERSISTENCE
  // ---------------------------------------------------------------------------

  /// Loads persistent account data from Supabase into the in-memory cache.
  ///
  /// The backend remains the authoritative API; Supabase is the durable
  /// store for the entities currently supported by SupabaseStore.
  ///
  /// ARM ingestion entities are intentionally not loaded here yet because
  /// their durable schema/store implementation is being introduced separately.
  Future<void> initializePersistent() async {
    try {
      final store = SupabaseStore.instance;

      if (!store.enabled) {
        return;
      }

      final accounts = await store.loadAccounts();

      for (final account in accounts) {
        _cacheAccount(account);
      }

      final payments = await store.loadPayments();

      for (final payment in payments) {
        paymentsById[payment.id] = payment;
      }

      final memberLogins = await store.loadMemberLogins();

      for (final login in memberLogins) {
        registerMemberLogin(login);
      }

      // Account.passwordHash is the canonical owner credential. Re-register
      // each owner identity from the durable account record so a stale member
      // identity cannot take precedence over a valid account password.
      for (final account in accountsById.values) {
        if (account.email.trim().isEmpty ||
            account.passwordHash.trim().isEmpty) {
          continue;
        }

        registerMemberLogin(
          MemberLoginRecord(
            memberId: 'owner_${account.id}',
            accountId: account.id,
            email: account.email.trim().toLowerCase(),
            passwordHash: account.passwordHash,
            role: 'owner',
            status: 'active',
          ),
        );
      }
    } catch (error, stackTrace) {
      developer.log(
        'Unable to load persistent database state. Starting with in-memory cache.',
        name: 'Database',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _cacheAccount(Account account) {
    final username = account.username.trim().toLowerCase();
    final email = account.email.trim().toLowerCase();

    accountsById[account.id] = account;

    if (username.isNotEmpty) {
      accountIdByUsername[username] = account.id;
    }

    if (email.isNotEmpty) {
      accountIdByEmail[email] = account.id;
    }
  }

  void _persistAccount(Account account) {
    unawaited(
      SupabaseStore.instance
          .upsertAccount(account)
          .catchError((error, stackTrace) {
        developer.log(
          'Account persistence failed.',
          name: 'Database',
          error: error,
          stackTrace: stackTrace,
        );
      }),
    );
  }

  /// Persists an account and waits for the durable Supabase write to finish.
  ///
  /// Use this for authentication-critical operations such as account creation
  /// and password changes so a successful HTTP response is never returned
  /// before the credential has been durably stored.
  Future<void> persistAccountAndWait(
    Account account,
  ) async {
    await SupabaseStore.instance.upsertAccount(account);
  }

  // ---------------------------------------------------------------------------
  // PAYMENT PERSISTENCE
  // ---------------------------------------------------------------------------

  /// Stores a payment session in the in-memory cache and asynchronously
  /// persists it to the durable Supabase payment store.
  void savePayment(
    PaymentSession payment,
  ) {
    paymentsById[payment.id] = payment;

    unawaited(
      SupabaseStore.instance
          .upsertPayment(payment)
          .catchError((error, stackTrace) {
        developer.log(
          'Payment persistence failed.',
          name: 'Database',
          error: error,
          stackTrace: stackTrace,
        );
      }),
    );
  }

  /// Persists a payment session and waits for the durable Supabase write
  /// to finish.
  Future<void> persistPaymentAndWait(
    PaymentSession payment,
  ) async {
    paymentsById[payment.id] = payment;

    await SupabaseStore.instance.upsertPayment(payment);
  }

  /// Retrieves a payment session from the in-memory payment cache.
  PaymentSession? getPayment(
    String paymentId,
  ) {
    final normalizedId = paymentId.trim();

    if (normalizedId.isEmpty) {
      return null;
    }

    return paymentsById[normalizedId];
  }

  /// Returns all payment sessions belonging to an account.
  List<PaymentSession> getPaymentsForAccount(
    String accountId,
  ) {
    final normalizedAccountId = accountId.trim();

    if (normalizedAccountId.isEmpty) {
      return const <PaymentSession>[];
    }

    return paymentsById.values
        .where(
          (payment) => payment.accountId == normalizedAccountId,
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // ACCOUNTS
  // ---------------------------------------------------------------------------

  final Map<String, Account> accountsById = <String, Account>{};

  final Map<String, String> accountIdByUsername = <String, String>{};

  final Map<String, String> accountIdByEmail = <String, String>{};

  // Login identities are separate from accounts. A person can belong to
  // multiple accounts, so email must never be used as the account ID.
  final Map<String, List<MemberLoginRecord>> memberLoginsByEmail =
      <String, List<MemberLoginRecord>>{};

  // ---------------------------------------------------------------------------
  // PAYMENTS
  // ---------------------------------------------------------------------------

  /// Payment sessions are cached here after being loaded from the durable
  /// Supabase store. Supabase remains the persistent source of truth.
  final Map<String, PaymentSession> paymentsById =
      <String, PaymentSession>{};

  // ---------------------------------------------------------------------------
  // SESSIONS
  // ---------------------------------------------------------------------------

  final Map<String, SessionRecord> sessions = <String, SessionRecord>{};

  // Recent failed login timestamps, keyed by normalized username/email.
  // This is intentionally bounded and in-memory for the current backend.
  final Map<String, List<DateTime>> failedLoginAttempts =
      <String, List<DateTime>>{};

  final Map<String, Set<String>> knownLoginFingerprints =
      <String, Set<String>>{};

  final Map<String, String> oneTimeCodesByAccountId =
      <String, String>{};

  final Map<String, DateTime> oneTimeCodeExpiryByAccountId =
      <String, DateTime>{};

  final Map<String, RemoteWorker> remoteWorkersById =
      <String, RemoteWorker>{};

  final Map<String, RemoteImportJob> remoteImportJobsById =
      <String, RemoteImportJob>{};

  // ---------------------------------------------------------------------------
  // ARM INGESTION
  // ---------------------------------------------------------------------------
  //
  // These maps are the backend's current in-process ARM ingestion store.
  //
  // The important distinction is:
  //
  //   rip job       = operation/lifecycle
  //   release       = physical publication/edition
  //   physical disc = individual physical medium
  //   content       = material found on that disc
  //   recording     = canonical music recording identity
  //
  // A physical release may contain multiple physical discs and a disc may
  // contain multiple content items. Music tracks reference recordings rather
  // than creating a new canonical recording for every release.

  final Map<String, ArmRipJob> armRipJobsById =
      <String, ArmRipJob>{};

  final Map<String, ArmPhysicalRelease> armPhysicalReleasesById =
      <String, ArmPhysicalRelease>{};

  final Map<String, ArmPhysicalDisc> armPhysicalDiscsById =
      <String, ArmPhysicalDisc>{};

  final Map<String, ArmDiscContent> armDiscContentsById =
      <String, ArmDiscContent>{};

  final Map<String, ArmMusicRecording> armMusicRecordingsById =
      <String, ArmMusicRecording>{};

  /// Returns all ARM rip jobs currently known to this backend process.
  List<ArmRipJob> getArmRipJobs() {
    return List<ArmRipJob>.unmodifiable(
      armRipJobsById.values,
    );
  }

  /// Saves an ARM rip job in the in-memory ingestion store.
  ///
  /// Associated physical-release, physical-disc, disc-content and recording
  /// entities are also indexed when present on the job.
  void saveArmRipJob(
    ArmRipJob job,
  ) {
    armRipJobsById[job.id] = job;

    final release = job.physicalRelease;

    if (release != null) {
      saveArmPhysicalRelease(release);
    }

    final disc = job.physicalDisc;

    if (disc != null) {
      saveArmPhysicalDisc(disc);
    }

    for (final recording in job.recordings) {
      saveArmMusicRecording(recording);
    }

    if (disc != null) {
      for (final content in disc.contents) {
        saveArmDiscContent(content);
      }
    }
  }

  /// Retrieves an ARM rip job by ID.
  ArmRipJob? getArmRipJobById(
    String jobId,
  ) {
    final normalizedId = jobId.trim();

    if (normalizedId.isEmpty) {
      return null;
    }

    return armRipJobsById[normalizedId];
  }

  /// Deletes an ARM rip job from the in-memory ingestion store.
  ///
  /// Physical provenance is deliberately not deleted here. A completed
  /// release/disc/content record may be referenced by the library import
  /// workflow even after the transient rip job is no longer needed.
  void deleteArmRipJob(
    String jobId,
  ) {
    armRipJobsById.remove(
      jobId.trim(),
    );
  }

  /// Saves a physical media release.
  void saveArmPhysicalRelease(
    ArmPhysicalRelease release,
  ) {
    armPhysicalReleasesById[release.id] = release;

    for (final disc in release.discs) {
      saveArmPhysicalDisc(disc);
    }
  }

  /// Retrieves a physical release by ID.
  ArmPhysicalRelease? getArmPhysicalReleaseById(
    String releaseId,
  ) {
    final normalizedId = releaseId.trim();

    if (normalizedId.isEmpty) {
      return null;
    }

    return armPhysicalReleasesById[normalizedId];
  }

  /// Returns all physical releases currently known to the backend.
  List<ArmPhysicalRelease> getArmPhysicalReleases() {
    return List<ArmPhysicalRelease>.unmodifiable(
      armPhysicalReleasesById.values,
    );
  }

  /// Returns physical releases whose title matches the supplied title.
  ///
  /// This is intentionally a discovery helper, not an identity merge.
  /// Persistence/metadata resolution must use stronger identifiers such as
  /// barcode, edition, provider identifiers and reviewed metadata before
  /// deciding that two releases are the same physical release.
  List<ArmPhysicalRelease> findArmPhysicalReleasesByTitle(
    String title,
  ) {
    final normalizedTitle = title.trim().toLowerCase();

    if (normalizedTitle.isEmpty) {
      return const <ArmPhysicalRelease>[];
    }

    return armPhysicalReleasesById.values
        .where(
          (release) =>
              release.title.trim().toLowerCase() == normalizedTitle,
        )
        .toList();
  }

  /// Saves a physical disc and indexes its disc contents.
  void saveArmPhysicalDisc(
    ArmPhysicalDisc disc,
  ) {
    armPhysicalDiscsById[disc.id] = disc;

    for (final content in disc.contents) {
      saveArmDiscContent(content);
    }
  }

  /// Retrieves a physical disc by ID.
  ArmPhysicalDisc? getArmPhysicalDiscById(
    String discId,
  ) {
    final normalizedId = discId.trim();

    if (normalizedId.isEmpty) {
      return null;
    }

    return armPhysicalDiscsById[normalizedId];
  }

  /// Returns all physical discs belonging to a physical release.
  List<ArmPhysicalDisc> getArmPhysicalDiscsForRelease(
    String releaseId,
  ) {
    final normalizedReleaseId = releaseId.trim();

    if (normalizedReleaseId.isEmpty) {
      return const <ArmPhysicalDisc>[];
    }

    final discs = armPhysicalDiscsById.values
        .where(
          (disc) => disc.releaseId == normalizedReleaseId,
        )
        .toList();

    discs.sort(
      (a, b) => a.discNumber.compareTo(
        b.discNumber,
      ),
    );

    return discs;
  }

  /// Saves a single disc-content record.
  void saveArmDiscContent(
    ArmDiscContent content,
  ) {
    armDiscContentsById[content.id] = content;
  }

  /// Retrieves disc content by ID.
  ArmDiscContent? getArmDiscContentById(
    String contentId,
  ) {
    final normalizedId = contentId.trim();

    if (normalizedId.isEmpty) {
      return null;
    }

    return armDiscContentsById[normalizedId];
  }

  /// Returns all content items belonging to a physical disc.
  List<ArmDiscContent> getArmDiscContentsForDisc(
    String discId,
  ) {
    final normalizedDiscId = discId.trim();

    if (normalizedDiscId.isEmpty) {
      return const <ArmDiscContent>[];
    }

    return armDiscContentsById.values
        .where(
          (content) => content.discId == normalizedDiscId,
        )
        .toList();
  }

  /// Returns only primary/feature content from a physical disc.
  List<ArmDiscContent> getPrimaryArmDiscContentsForDisc(
    String discId,
  ) {
    return getArmDiscContentsForDisc(discId)
        .where(
          (content) => content.primary,
        )
        .toList();
  }

  /// Returns bonus/non-primary content from a physical disc.
  List<ArmDiscContent> getBonusArmDiscContentsForDisc(
    String discId,
  ) {
    return getArmDiscContentsForDisc(discId)
        .where(
          (content) => content.isBonus,
        )
        .toList();
  }

  /// Saves a canonical music recording candidate.
  ///
  /// The database deliberately does not automatically merge recordings based
  /// only on title or artist. Different performances can share those values.
  /// Strong identifiers such as ISRC, verified duration and audio fingerprints
  /// should be used by the identity-resolution layer.
  void saveArmMusicRecording(
    ArmMusicRecording recording,
  ) {
    armMusicRecordingsById[recording.id] = recording;
  }

  /// Retrieves a canonical music recording by ID.
  ArmMusicRecording? getArmMusicRecordingById(
    String recordingId,
  ) {
    final normalizedId = recordingId.trim();

    if (normalizedId.isEmpty) {
      return null;
    }

    return armMusicRecordingsById[normalizedId];
  }

  /// Returns all canonical music recordings currently known to the backend.
  List<ArmMusicRecording> getArmMusicRecordings() {
    return List<ArmMusicRecording>.unmodifiable(
      armMusicRecordingsById.values,
    );
  }

  /// Finds recordings with a matching ISRC.
  ///
  /// ISRC is treated as a strong identity signal, but the caller should still
  /// validate provider metadata and recording version before performing a
  /// permanent merge.
  List<ArmMusicRecording> findArmMusicRecordingsByIsrc(
    String isrc,
  ) {
    final normalizedIsrc = isrc.trim().toUpperCase();

    if (normalizedIsrc.isEmpty) {
      return const <ArmMusicRecording>[];
    }

    return armMusicRecordingsById.values
        .where(
          (recording) =>
              recording.isrc?.trim().toUpperCase() == normalizedIsrc,
        )
        .toList();
  }

  /// Finds recordings with a matching audio fingerprint.
  ///
  /// Fingerprints are compared as normalized strings. Fingerprint generation
  /// and similarity scoring remain outside this database cache.
  List<ArmMusicRecording> findArmMusicRecordingsByFingerprint(
    String fingerprint,
  ) {
    final normalizedFingerprint = fingerprint.trim().toLowerCase();

    if (normalizedFingerprint.isEmpty) {
      return const <ArmMusicRecording>[];
    }

    return armMusicRecordingsById.values
        .where(
          (recording) =>
              recording.audioFingerprint?.trim().toLowerCase() ==
              normalizedFingerprint,
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // LOGIN SECURITY
  // ---------------------------------------------------------------------------

  /// Performs `getKnownLoginFingerprints` for this feature. Update this
  /// documentation when its contract changes.
  Set<String> getKnownLoginFingerprints(
    String accountId,
  ) =>
      knownLoginFingerprints.putIfAbsent(
        accountId,
        () => <String>{},
      );

  /// Performs `recordFailedLogin` for this feature. Update this documentation
  /// when its contract changes.
  void recordFailedLogin(
    String login,
  ) {
    final key = login.trim().toLowerCase();

    if (key.isEmpty) {
      return;
    }

    final now = DateTime.now();

    final attempts = failedLoginAttempts.putIfAbsent(
      key,
      () => <DateTime>[],
    );

    attempts.removeWhere(
      (time) => now.difference(time) > const Duration(minutes: 15),
    );

    attempts.add(now);

    if (attempts.length > 10) {
      attempts.removeRange(
        0,
        attempts.length - 10,
      );
    }
  }

  /// Performs `recentFailedLoginCount` for this feature. Update this
  /// documentation when its contract changes.
  int recentFailedLoginCount(
    String login,
  ) {
    final key = login.trim().toLowerCase();

    final attempts = failedLoginAttempts[key];

    if (attempts == null) {
      return 0;
    }

    final now = DateTime.now();

    attempts.removeWhere(
      (time) => now.difference(time) > const Duration(minutes: 15),
    );

    return attempts.length;
  }

  /// Performs `clearFailedLoginAttempts` for this feature. Update this
  /// documentation when its contract changes.
  void clearFailedLoginAttempts(
    String login,
  ) {
    failedLoginAttempts.remove(
      login.trim().toLowerCase(),
    );
  }

  // ---------------------------------------------------------------------------
  // MEDIA
  // ---------------------------------------------------------------------------

  final Map<String, Media> mediaById = <String, Media>{};

  // Media reviews are kept here by the current backend persistence abstraction.
  final Map<String, MediaReview> reviewsById =
      <String, MediaReview>{};

  // ---------------------------------------------------------------------------
  // GROUP RECOMMENDATIONS
  // ---------------------------------------------------------------------------

  final Map<String, GroupRecommendation> groupRecommendationsById =
      <String, GroupRecommendation>{};

  // ---------------------------------------------------------------------------
  // GROUP WATCH
  // ---------------------------------------------------------------------------

  final Map<String, GroupWatchSession> groupWatchSessionsById =
      <String, GroupWatchSession>{};

  final Map<String, GroupChatRoom> groupChatRoomsById =
      <String, GroupChatRoom>{};

  // ---------------------------------------------------------------------------
  // ACCOUNTS
  // ---------------------------------------------------------------------------

  Account? getAccountById(
    String accountId,
  ) {
    return accountsById[accountId];
  }

  Account? getAccountByUsername(
    String username,
  ) {
    final normalized = username.trim().toLowerCase();

    final accountId = accountIdByUsername[normalized];

    if (accountId == null) {
      return null;
    }

    return accountsById[accountId];
  }

  List<MemberLoginRecord> getMemberLoginsByEmail(
    String email,
  ) {
    return List<MemberLoginRecord>.unmodifiable(
      memberLoginsByEmail[email.trim().toLowerCase()] ??
          const <MemberLoginRecord>[],
    );
  }

  void registerMemberLogin(
    MemberLoginRecord login,
  ) {
    final key = login.email.trim().toLowerCase();

    if (key.isEmpty) {
      return;
    }

    final entries = memberLoginsByEmail.putIfAbsent(
      key,
      () => <MemberLoginRecord>[],
    );

    entries.removeWhere(
      (existing) => existing.memberId == login.memberId,
    );

    entries.add(login);
  }

  void removeMemberLogin(
    String email, {
    String? accountId,
  }) {
    final key = email.trim().toLowerCase();

    final entries = memberLoginsByEmail[key];

    if (entries == null) {
      return;
    }

    if (accountId == null) {
      memberLoginsByEmail.remove(key);
      return;
    }

    entries.removeWhere(
      (login) => login.accountId == accountId,
    );

    if (entries.isEmpty) {
      memberLoginsByEmail.remove(key);
    }
  }

  Account? getAccountByEmail(
    String email,
  ) {
    final normalized = email.trim().toLowerCase();

    final accountId = accountIdByEmail[normalized];

    if (accountId == null) {
      return null;
    }

    return accountsById[accountId];
  }

  Account? getAccountForProfile(
    String profileId,
  ) {
    for (final account in accountsById.values) {
      if (account.getProfileById(profileId) != null) {
        return account;
      }
    }

    return null;
  }

  Profile? getProfileById(
    String profileId,
  ) {
    for (final account in accountsById.values) {
      final profile = account.getProfileById(profileId);

      if (profile != null) {
        return profile;
      }
    }

    return null;
  }

  String? getAccountIdForProfile(
    String profileId,
  ) {
    for (final account in accountsById.values) {
      if (account.getProfileById(profileId) != null) {
        return account.id;
      }
    }

    return null;
  }

  /// Performs `hasProfile` for this feature. Update this documentation when
  /// its contract changes.
  bool hasProfile(
    String profileId,
  ) {
    return getProfileById(profileId) != null;
  }

  /// Performs `profileBelongsToAccount` for this feature. Update this
  /// documentation when its contract changes.
  bool profileBelongsToAccount({
    required String accountId,
    required String profileId,
  }) {
    final account = getAccountById(accountId);

    if (account == null) {
      return false;
    }

    return account.getProfileById(profileId) != null;
  }

  /// Performs `saveAccount` for this feature. Update this documentation when
  /// its contract changes.
  void saveAccount(
    Account account, {
    bool persist = true,
  }) {
    final username = account.username.trim().toLowerCase();
    final email = account.email.trim().toLowerCase();

    final previous = accountsById[account.id];

    if (previous != null) {
      final previousUsername =
          previous.username.trim().toLowerCase();

      final previousEmail =
          previous.email.trim().toLowerCase();

      if (previousUsername != username &&
          accountIdByUsername[previousUsername] == account.id) {
        accountIdByUsername.remove(
          previousUsername,
        );
      }

      if (previousEmail != email &&
          accountIdByEmail[previousEmail] == account.id) {
        accountIdByEmail.remove(
          previousEmail,
        );
      }
    }

    accountsById[account.id] = account;

    registerMemberLogin(
      MemberLoginRecord(
        memberId: 'owner_${account.id}',
        accountId: account.id,
        email: email,
        passwordHash: account.passwordHash,
        role: 'owner',
        status: 'active',
      ),
    );

    if (username.isNotEmpty) {
      accountIdByUsername[username] = account.id;
    }

    if (email.isNotEmpty) {
      accountIdByEmail[email] = account.id;
    }

    if (persist) {
      _persistAccount(account);
    }
  }

  /// Performs `deleteAccount` for this feature. Update this documentation when
  /// its contract changes.
  void deleteAccount(
    String accountId,
  ) {
    final account = accountsById[accountId];

    if (account == null) {
      return;
    }

    final username = account.username.trim().toLowerCase();
    final email = account.email.trim().toLowerCase();

    accountIdByUsername.remove(username);
    accountIdByEmail.remove(email);

    accountsById.remove(accountId);

    for (final email in memberLoginsByEmail.keys.toList()) {
      removeMemberLogin(
        email,
        accountId: accountId,
      );
    }

    deleteSessionsForAccount(accountId);

    // Remove Group Watch sessions hosted by this account.
    groupWatchSessionsById.removeWhere(
      (_, session) => session.accountId == accountId,
    );

    paymentsById.removeWhere(
      (_, payment) => payment.accountId == accountId,
    );

    unawaited(
      SupabaseStore.instance.deleteAccount(accountId).catchError(
        (error, stackTrace) {
          developer.log(
            'Account deletion persistence failed.',
            name: 'Database',
            error: error,
            stackTrace: stackTrace,
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SESSIONS
  // ---------------------------------------------------------------------------

  /// Performs `saveSession` for this feature. Update this documentation when
  /// its contract changes.
  void saveSession(
    String token,
    String accountId, {
    Duration? ttl,
    String ipAddress = 'unknown',
    String userAgent = 'unknown',
  }) {
    final normalizedToken = token.trim();
    final normalizedAccountId = accountId.trim();

    if (normalizedToken.isEmpty || normalizedAccountId.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final lifetime = ttl ?? defaultSessionLifetime;

    sessions[normalizedToken] = SessionRecord(
      token: normalizedToken,
      accountId: normalizedAccountId,
      createdAt: now,
      expiresAt: now.add(lifetime),
      lastUsedAt: now,
      ipAddress: ipAddress,
      userAgent: userAgent,
    );
  }

  SessionRecord? getSession(
    String token,
  ) {
    final session = sessions[token];

    if (session == null) {
      return null;
    }

    if (session.isExpired) {
      sessions.remove(token);
      return null;
    }

    return session;
  }

  String? getAccountIdForSession(
    String token,
  ) {
    final session = getSession(token);

    if (session == null) {
      return null;
    }

    session.lastUsedAt = DateTime.now();

    return session.accountId;
  }

  Account? getAccountForSession(
    String token,
  ) {
    final accountId = getAccountIdForSession(token);

    if (accountId == null) {
      return null;
    }

    return getAccountById(accountId);
  }

  /// Performs `deleteSession` for this feature. Update this documentation
  /// when its contract changes.
  void deleteSession(
    String token,
  ) {
    sessions.remove(token);
  }

  /// Replaces an existing session token while preserving its
  /// account/device metadata.
  String? rotateSession(
    String oldToken,
    String newToken,
  ) {
    final session = getSession(oldToken);

    if (session == null) {
      return null;
    }

    final now = DateTime.now();

    sessions.remove(oldToken);

    sessions[newToken] = SessionRecord(
      token: newToken,
      accountId: session.accountId,
      createdAt: now,
      expiresAt: now.add(defaultSessionLifetime),
      lastUsedAt: now,
      ipAddress: session.ipAddress,
      userAgent: session.userAgent,
    );

    return session.accountId;
  }

  /// Performs `deleteSessionsForAccount` for this feature. Update this
  /// documentation when its contract changes.
  void deleteSessionsForAccount(
    String accountId,
  ) {
    sessions.removeWhere(
      (_, session) => session.accountId == accountId,
    );
  }

  /// Performs `getSessionsForAccount` for this feature. Update this
  /// documentation when its contract changes.
  List<SessionRecord> getSessionsForAccount(
    String accountId,
  ) {
    final result = <SessionRecord>[];
    final expiredTokens = <String>[];

    for (final entry in sessions.entries) {
      final session = entry.value;

      if (session.isExpired) {
        expiredTokens.add(entry.key);
        continue;
      }

      if (session.accountId == accountId) {
        result.add(session);
      }
    }

    for (final token in expiredTokens) {
      sessions.remove(token);
    }

    result.sort(
      (a, b) => b.lastUsedAt.compareTo(
        a.lastUsedAt,
      ),
    );

    return result;
  }

  // ---------------------------------------------------------------------------
  // MEDIA
  // ---------------------------------------------------------------------------

  /// Performs `saveMedia` for this feature. Update this documentation when
  /// its contract changes.
  void saveMedia(
    Media media,
  ) {
    mediaById[media.id] = media;
  }

  Media? getMediaById(
    String mediaId,
  ) {
    return mediaById[mediaId];
  }

  /// Performs `getAllMedia` for this feature. Update this documentation when
  /// its contract changes.
  List<Media> getAllMedia() {
    final media = mediaById.values.toList();

    media.sort(
      (a, b) {
        final aDate = a.releaseDate;
        final bDate = b.releaseDate;

        if (aDate != null && bDate != null) {
          final dateCompare = bDate.compareTo(aDate);

          if (dateCompare != 0) {
            return dateCompare;
          }
        }

        if (aDate != null) {
          return -1;
        }

        if (bDate != null) {
          return 1;
        }

        final aYear = a.year;
        final bYear = b.year;

        if (aYear != null &&
            bYear != null &&
            aYear != bYear) {
          return bYear.compareTo(aYear);
        }

        if (aYear != null) {
          return -1;
        }

        if (bYear != null) {
          return 1;
        }

        return a.title.toLowerCase().compareTo(
              b.title.toLowerCase(),
            );
      },
    );

    return media;
  }

  /// Performs `getMovies` for this feature. Update this documentation when
  /// its contract changes.
  List<Media> getMovies() {
    return getAllMedia()
        .where(
          (media) => media.isMovie,
        )
        .toList();
  }

  /// Performs `getTvShows` for this feature. Update this documentation when
  /// its contract changes.
  List<Media> getTvShows() {
    return getAllMedia()
        .where(
          (media) => media.isTvShow,
        )
        .toList();
  }

  /// Performs `getSeries` for this feature. Update this documentation when
  /// its contract changes.
  List<Media> getSeries(
    String seriesId,
  ) {
    return getAllMedia()
        .where(
          (media) => media.seriesId == seriesId,
        )
        .toList();
  }

  /// Performs `hasMedia` for this feature. Update this documentation when
  /// its contract changes.
  bool hasMedia(
    String mediaId,
  ) {
    return mediaById.containsKey(mediaId);
  }

  /// Performs `deleteMedia` for this feature. Update this documentation when
  /// its contract changes.
  void deleteMedia(
    String mediaId,
  ) {
    mediaById.remove(mediaId);
  }

  // ---------------------------------------------------------------------------
  // GROUP RECOMMENDATIONS
  // ---------------------------------------------------------------------------

  /// Performs `saveGroupRecommendation` for this feature. Update this
  /// documentation when its contract changes.
  void saveGroupRecommendation(
    GroupRecommendation recommendation,
  ) {
    groupRecommendationsById[recommendation.id] = recommendation;
  }

  GroupRecommendation? getGroupRecommendationById(
    String recommendationId,
  ) {
    return groupRecommendationsById[recommendationId];
  }

  List<GroupRecommendation> getGroupRecommendationsForAccount(
    String accountId,
  ) {
    return groupRecommendationsById.values
        .where(
          (recommendation) =>
              recommendation.accountId == accountId,
        )
        .toList();
  }

  List<GroupRecommendation> getVotingGroupRecommendationsForAccount(
    String accountId,
  ) {
    return getGroupRecommendationsForAccount(accountId)
        .where(
          (recommendation) => recommendation.isVotingOpen,
        )
        .toList();
  }

  /// Performs `deleteGroupRecommendation` for this feature. Update this
  /// documentation when its contract changes.
  void deleteGroupRecommendation(
    String recommendationId,
  ) {
    groupRecommendationsById.remove(recommendationId);
  }

  /// Performs `clearGroupRecommendations` for this feature. Update this
  /// documentation when its contract changes.
  void clearGroupRecommendations() {
    groupRecommendationsById.clear();
  }

  // ---------------------------------------------------------------------------
  // GROUP WATCH
  // ---------------------------------------------------------------------------

  /// Performs `saveGroupWatchSession` for this feature. Update this
  /// documentation when its contract changes.
  void saveGroupWatchSession(
    GroupWatchSession session,
  ) {
    groupWatchSessionsById[session.id] = session;
  }

  GroupWatchSession? getGroupWatchSessionById(
    String sessionId,
  ) {
    return groupWatchSessionsById[sessionId];
  }

  List<GroupWatchSession> getGroupWatchSessionsForAccount(
    String accountId,
  ) {
    return groupWatchSessionsById.values.where(
      (session) {
        if (session.accountId == accountId) {
          return true;
        }

        for (final participant in session.participants.values) {
          if (participant.accountId == accountId) {
            return true;
          }
        }

        return false;
      },
    ).toList();
  }

  /// Performs `getGroupWatchSessionsForProfile` for this feature. Update this
  /// documentation when its contract changes.
  List<GroupWatchSession> getGroupWatchSessionsForProfile(
    String profileId,
  ) {
    return groupWatchSessionsById.values
        .where(
          (session) =>
              session.hostProfileId == profileId ||
              session.participants.containsKey(profileId),
        )
        .toList();
  }

  List<GroupWatchSession> getActiveGroupWatchSessions() {
    return groupWatchSessionsById.values
        .where(
          (session) =>
              session.status == GroupWatchSessionStatus.playing ||
              session.status == GroupWatchSessionStatus.paused,
        )
        .toList();
  }

  List<GroupWatchSession> getWaitingGroupWatchSessions() {
    return groupWatchSessionsById.values
        .where(
          (session) =>
              session.status == GroupWatchSessionStatus.waiting ||
              session.status == GroupWatchSessionStatus.ready,
        )
        .toList();
  }

  /// Performs `deleteGroupWatchSession` for this feature. Update this
  /// documentation when its contract changes.
  void deleteGroupWatchSession(
    String sessionId,
  ) {
    groupWatchSessionsById.remove(sessionId);
  }

  /// Performs `clearGroupWatchSessions` for this feature. Update this
  /// documentation when its contract changes.
  void clearGroupWatchSessions() {
    groupWatchSessionsById.clear();
  }

  // ---------------------------------------------------------------------------
  // CLEAR
  // ---------------------------------------------------------------------------

  /// Clears all in-memory database state.
  ///
  /// This does not delete durable Supabase data. It only resets the current
  /// backend process cache.
  void clear() {
    accountsById.clear();
    accountIdByUsername.clear();
    accountIdByEmail.clear();

    memberLoginsByEmail.clear();

    paymentsById.clear();

    sessions.clear();

    failedLoginAttempts.clear();
    knownLoginFingerprints.clear();
    oneTimeCodesByAccountId.clear();
    oneTimeCodeExpiryByAccountId.clear();

    remoteWorkersById.clear();
    remoteImportJobsById.clear();

    mediaById.clear();
    reviewsById.clear();

    groupRecommendationsById.clear();

    groupWatchSessionsById.clear();
    groupChatRoomsById.clear();

    // ARM ingestion state is process-local at this stage. Durable ARM
    // persistence will be handled by the database/store migration layer.
    armRipJobsById.clear();
    armPhysicalReleasesById.clear();
    armPhysicalDiscsById.clear();
    armDiscContentsById.clear();
    armMusicRecordingsById.clear();
  }
}