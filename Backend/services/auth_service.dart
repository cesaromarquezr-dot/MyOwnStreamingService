// FILE: `Backend/services/auth_service.dart`.
// Purpose: Implements the auth service portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'dart:convert';
import 'dart:math';

import 'package:password_guard/password_guard.dart';

import '../database/database.dart';
import '../models/account.dart';
import '../models/account_member.dart';
import '../supabase_store.dart';
import 'package:crypto/crypto.dart';
import '../models/profile.dart';
import '../models/subscription.dart';
import 'subscription_service.dart';
import 'email_service.dart';

class AuthLoginResult {
  final String? token;
  final bool suspicious;
  final List<String> reasons;
  final bool requiresMfa;

  const AuthLoginResult({
    required this.token,
    required this.suspicious,
    required this.reasons,
    this.requiresMfa = false,
  });
}

class AuthService {
  final Database database;
  final SubscriptionService subscriptionService;
  final EmailService emailService;

  final Random _random = Random.secure();

  AuthService({
    required this.database,
    required this.subscriptionService,
    required this.emailService,
  });

  /// Records a security event without writing passwords, bearer tokens, or MFA codes to logs.
  Future<void> _audit(String eventType, {String? accountId, Map<String, dynamic> metadata = const {}}) async {
    try {
      await SupabaseStore.instance.recordSecurityEvent(accountId: accountId, eventType: eventType, metadata: metadata);
    } catch (_) {
      // Security telemetry must never make authentication fail.
    }
  }

  // ---------------------------------------------------------------------------
  // ID / TOKEN GENERATION
  // ---------------------------------------------------------------------------

  /// Performs `_generateId` for this feature. Update this documentation when its contract changes.
  String _generateId(String prefix) {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final randomPart = _random.nextInt(1000000000);

    return '${prefix}_${timestamp}_$randomPart';
  }

  /// Performs `_generateSessionToken` for this feature. Update this documentation when its contract changes.
  String _generateSessionToken() {
    final bytes = List<int>.generate(
      48,
      (_) => _random.nextInt(256),
    );

    final encoded = base64UrlEncode(bytes).replaceAll('=', '');

    return 'session_$encoded';
  }

  // ---------------------------------------------------------------------------
  // PASSWORDS
  // ---------------------------------------------------------------------------

  /// Performs `_hashPassword` for this feature. Update this documentation when its contract changes.
  Future<String> _hashPassword(
    String password,
  ) async {
    final result = await PasswordGuard.hash(
      password: password,
      algorithm: PasswordAlgorithm.argon2id,
    );

    return result.hash;
  }

  /// Performs `_verifyPassword` for this feature. Update this documentation when its contract changes.
  Future<bool> _verifyPassword(
    String password,
    String passwordHash,
  ) async {
    try {
      return await PasswordGuard.verify(
        password: password,
        hash: passwordHash,
      );
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // ACCOUNT CREATION
  // ---------------------------------------------------------------------------

  /// Performs `createAccount` for this feature. Update this documentation when its contract changes.
  Future<Account> createAccount({
    String? username,
    required String email,
    required String password,
    required SubscriptionPlan plan,
    required String firstProfileName,
    required String securityQuestion,
    required String securityAnswer,
    required String termsVersion,
    required String privacyVersion,
    required String acceptableUseVersion,
    required DateTime legalAcceptedAt,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (!_isValidEmail(cleanEmail)) {
      throw Exception('A valid email address is required.');
    }

    final localPart = cleanEmail.split('@').first.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    var cleanUsername = (username ?? '').trim();
    if (cleanUsername.isEmpty) {
      cleanUsername = '${localPart}_account';
      var suffix = 2;
      while (database.getAccountByUsername(cleanUsername) != null) {
        cleanUsername = '${localPart}_account_$suffix';
        suffix++;
      }
    }


    if (password.length < 10) {
      throw Exception(
        'Password must be at least 10 characters long.',
      );
    }

    if (database.getAccountByUsername(cleanUsername) != null) {
      throw Exception(
        'That username is already in use.',
      );
    }

    if (database.getAccountByEmail(cleanEmail) != null) {
      throw Exception(
        'That email address is already in use.',
      );
    }

    if (securityQuestion.trim().isEmpty || securityAnswer.trim().isEmpty) {
      throw Exception('A security question and answer are required.');
    }

    if (termsVersion.trim().isEmpty || privacyVersion.trim().isEmpty || acceptableUseVersion.trim().isEmpty) {
      throw Exception('Current legal policies must be accepted.');
    }

    final passwordHash = await _hashPassword(password);
    final securityAnswerHash = await _hashPassword(securityAnswer.trim().toLowerCase());

    final account = Account(
      id: _generateId('account'),
      username: cleanUsername,
      email: cleanEmail,
      passwordHash: passwordHash,
      securityQuestion: securityQuestion.trim(),
      securityAnswerHash: securityAnswerHash,
      termsVersionAccepted: termsVersion.trim(),
      privacyVersionAccepted: privacyVersion.trim(),
      acceptableUseVersionAccepted: acceptableUseVersion.trim(),
      legalAcceptedAt: legalAcceptedAt.toUtc(),
    );

    // New accounts intentionally start with ZERO profiles.
    // The owner creates profiles after entering the account.

    // Signup intentionally creates an inactive subscription.
    //
    // Payment must be completed before login is allowed.
    subscriptionService.subscribe(
      account,
      plan,
    );

    database.saveAccount(account);
    await database.persistAccountAndWait(account);

    await emailService.welcome(
      account.email,
      account.username,
    );

    return account;
  }

  // ---------------------------------------------------------------------------
  // SUBSCRIPTION / LOGIN ELIGIBILITY
  // ---------------------------------------------------------------------------

  /// Performs `canLogin` for this feature. Update this documentation when its contract changes.
  bool canLogin(
    Account account,
  ) {
    return account.hasActiveSubscription;
  }

  /// Performs `requiresPayment` for this feature. Update this documentation when its contract changes.
  bool requiresPayment(
    Account account,
  ) {
    return !account.hasActiveSubscription;
  }

  // ---------------------------------------------------------------------------
  // LOGIN
  // ---------------------------------------------------------------------------

  /// Performs `login` for this feature. Update this documentation when its contract changes.
  Future<AuthLoginResult> login({
    required String login,
    required String password,
    String ipAddress = 'unknown',
    String userAgent = 'unknown',
  }) async {
    final cleanLogin = login.trim();
    final normalizedLogin = cleanLogin.toLowerCase();

    if (cleanLogin.isEmpty || password.isEmpty) {
      database.recordFailedLogin(normalizedLogin);
      await _audit('login_failed', metadata: {'identifierHash': sha256.convert(utf8.encode(normalizedLogin)).toString()});
      throw Exception(
        'Invalid email or password.',
      );
    }

    if (database.recentFailedLoginCount(normalizedLogin) >= 10) {
      throw Exception('Too many failed login attempts. Try again later.');
    }

    // Account.passwordHash is the canonical owner credential. Do not let a
    // stale owner member-identity row override it during authentication.
    Account? account = database.getAccountByEmail(normalizedLogin);
    if (account == null) {
      account = database.getAccountByUsername(normalizedLogin);
    }

    String? passwordHash;

    if (account != null && account.passwordHash.isNotEmpty &&
        await _verifyPassword(password, account.passwordHash)) {
      passwordHash = account.passwordHash;

      // Keep the canonical owner identity synchronized for legacy/member-based
      // operations without using it as the source of truth for owner login.
      database.registerMemberLogin(MemberLoginRecord(
        memberId: 'owner_${account.id}',
        accountId: account.id,
        email: account.email.trim().toLowerCase(),
        passwordHash: account.passwordHash,
        role: 'owner',
        status: 'active',
      ));
    }

    // An email may also identify an invited member of another account. Test
    // every active identity rather than trusting whichever row is returned
    // first from persistent storage.
    if (passwordHash == null) {
      final memberLogins =
          database.getMemberLoginsByEmail(normalizedLogin);
      final activeMembers =
          memberLogins.where((member) => member.status == 'active').toList();
      final matches = <MemberLoginRecord>[];

      for (final member in activeMembers) {
        if (await _verifyPassword(password, member.passwordHash)) {
          final memberAccount = database.getAccountById(member.accountId);
          if (memberAccount != null) {
            matches.add(member);
          }
        }
      }

      if (matches.length == 1) {
        final member = matches.single;
        account = database.getAccountById(member.accountId);
        passwordHash = member.passwordHash;
      } else if (matches.length > 1) {
        throw Exception(
          'This email belongs to multiple streaming accounts. Select an account before signing in.',
        );
      }
    }

    if (account == null || passwordHash == null || passwordHash.isEmpty) {
      database.recordFailedLogin(normalizedLogin);
      await _audit('login_failed', metadata: {'identifierHash': sha256.convert(utf8.encode(normalizedLogin)).toString()});
      throw Exception(
        'Invalid email or password.',
      );
    }

    if (passwordHash == account.passwordHash &&
        PasswordGuard.needsRehash(account.passwordHash)) {
      account.passwordHash = await _hashPassword(
        password,
      );

      database.saveAccount(account);
    }

    if (!account.hasActiveSubscription) {
      throw Exception(
        'Your subscription is not active. Complete payment before logging in.',
      );
    }

    final recentFailures =
        database.recentFailedLoginCount(
      normalizedLogin,
    );

    final normalizedIp = ipAddress.trim().isEmpty
        ? 'unknown'
        : ipAddress.trim();

    final normalizedAgent =
        userAgent.trim().isEmpty
            ? 'unknown'
            : userAgent.trim();

    final fingerprint =
        '$normalizedIp|$normalizedAgent';

    final knownFingerprints =
        database.getKnownLoginFingerprints(
      account.id,
    );

    final knownDevice =
        knownFingerprints.contains(
      fingerprint,
    );

    final reasons = <String>[];

    if (knownFingerprints.isNotEmpty && !knownDevice) {
      reasons.add(
        'new browser or device or network',
      );
    }

    if (recentFailures >= 2) {
      reasons.add(
        '$recentFailures recent failed login attempts',
      );
    }

    final suspicious = reasons.isNotEmpty;

    if (suspicious) {
      await emailService.suspicious(
        account.email,
        normalizedIp,
        DateTime.now().toIso8601String(),
      );
    }

    if (account.mfaEnabled) {
      await startMfaEnrollment(account);
      return AuthLoginResult(
        token: null,
        suspicious: suspicious,
        reasons: reasons,
        requiresMfa: true,
      );
    }

    final token = _generateSessionToken();

    database.saveSession(
      token,
      account.id,
      ttl: Database.defaultSessionLifetime,
      ipAddress: normalizedIp,
      userAgent: normalizedAgent,
    );

    database.clearFailedLoginAttempts(
      normalizedLogin,
    );

    knownFingerprints.add(
      fingerprint,
    );
    await _audit('login_success', accountId: account.id, metadata: {'suspicious': suspicious, 'ip': normalizedIp});

    return AuthLoginResult(
      token: token,
      suspicious: suspicious,
      reasons: reasons,
    );
  }

  // ---------------------------------------------------------------------------
  // SESSION ROTATION / MFA
  // ---------------------------------------------------------------------------

  /// Rotates a bearer session token so a stolen token cannot be reused after rotation.
  String? rotateSession(String token) {
    final newToken = _generateSessionToken();
    final accountId = database.rotateSession(token.trim(), newToken);
    if (accountId == null) return null;
    return newToken;
  }

  /// Starts an email-based MFA enrollment challenge. The plaintext code is only
  /// sent through the configured email provider; the backend stores its hash.
  Future<void> startMfaEnrollment(Account account) async {
    final code = (100000 + _random.nextInt(900000)).toString();
    final codeHash = sha256.convert(utf8.encode(code)).toString();
    account.mfaChallengeHash = codeHash;
    account.mfaChallengeExpiresAt = DateTime.now().toUtc().add(const Duration(minutes: 10));
    database.saveAccount(account);
    await database.persistAccountAndWait(account);
    await _audit('mfa_challenge_sent', accountId: account.id);
    await emailService.mfaCode(account.email, code);
  }

  /// Confirms the MFA challenge and enables MFA without persisting the plaintext code.
  Future<void> verifyMfaEnrollment(Account account, String code) async {
    final expires = account.mfaChallengeExpiresAt;
    if (expires == null || !DateTime.now().toUtc().isBefore(expires.toUtc())) {
      throw Exception('The MFA verification code has expired.');
    }
    final expected = account.mfaChallengeHash;
    final actual = sha256.convert(utf8.encode(code.trim())).toString();
    if (expected.isEmpty || actual != expected) {
      throw Exception('Incorrect MFA verification code.');
    }
    account.mfaEnabled = true;
    account.mfaChallengeHash = '';
    account.mfaChallengeExpiresAt = null;
    database.saveAccount(account);
    await database.persistAccountAndWait(account);
    await _audit('mfa_enabled', accountId: account.id);
  }

  /// Disables MFA and clears any outstanding verification challenge.
  Future<void> disableMfa(Account account) async {
    account.mfaEnabled = false;
    account.mfaChallengeHash = '';
    account.mfaChallengeExpiresAt = null;
    database.saveAccount(account);
    await database.persistAccountAndWait(account);
    await _audit('mfa_disabled', accountId: account.id);
  }

  /// Changes an account password after verifying the current password.
  Future<void> changePassword({required Account account, required String currentPassword, required String newPassword}) async {
    if (newPassword.length < 10) throw Exception('New password must be at least 10 characters long.');
    if (currentPassword.isEmpty || !await _verifyPassword(currentPassword, account.passwordHash)) {
      throw Exception('Current password is incorrect.');
    }
    account.passwordHash = await _hashPassword(newPassword);
    database.saveAccount(account);
    await database.persistAccountAndWait(account);
    database.deleteSessionsForAccount(account.id);
    await _audit('password_changed', accountId: account.id);
  }

  /// Completes an MFA-protected login and issues a fresh session token.
  Future<AuthLoginResult> verifyMfaLogin({required String login, required String code, String ipAddress = 'unknown', String userAgent = 'unknown'}) async {
    final normalized = login.trim().toLowerCase();
    Account? account = database.getAccountByEmail(normalized);
    account ??= database.getAccountByUsername(normalized);
    if (account == null || !account.mfaEnabled) throw Exception('MFA verification is not available for this account.');
    final expires = account.mfaChallengeExpiresAt;
    final actual = sha256.convert(utf8.encode(code.trim())).toString();
    if (expires == null || !DateTime.now().toUtc().isBefore(expires.toUtc()) || actual != account.mfaChallengeHash) {
      database.recordFailedLogin('mfa:$normalized');
      throw Exception('Invalid or expired MFA code.');
    }
    account.mfaChallengeHash = '';
    account.mfaChallengeExpiresAt = null;
    database.saveAccount(account);
    await database.persistAccountAndWait(account);
    final token = _generateSessionToken();
    database.saveSession(token, account.id, ttl: Database.defaultSessionLifetime, ipAddress: ipAddress, userAgent: userAgent);
    database.clearFailedLoginAttempts('mfa:$normalized');
    await _audit('mfa_login_success', accountId: account.id, metadata: {'ip': ipAddress});
    return AuthLoginResult(token: token, suspicious: false, reasons: const [], requiresMfa: false);
  }

  /// Returns a redacted session list suitable for the account security screen.
  List<Map<String, dynamic>> sessionsForAccount(Account account, String currentToken) {
    final current = currentToken.trim();
    return database.getSessionsForAccount(account.id).map((session) {
      final tokenHash = sha256.convert(utf8.encode(_sessionFingerprint(session))).toString();
      return {
        'sessionId': tokenHash,
        'current': _sessionFingerprint(session) == _sessionFingerprint(database.getSession(current) ?? session),
        'createdAt': session.createdAt.toIso8601String(),
        'expiresAt': session.expiresAt.toIso8601String(),
        'lastUsedAt': session.lastUsedAt.toIso8601String(),
        'ipAddress': session.ipAddress,
        'userAgent': session.userAgent,
      };
    }).toList();
  }

  String _sessionFingerprint(SessionRecord session) => '${session.createdAt.microsecondsSinceEpoch}|${session.accountId}|${session.ipAddress}|${session.userAgent}';

  /// Revokes one redacted session identifier without exposing bearer tokens.
  bool revokeSessionById(Account account, String sessionId) {
    for (final entry in database.sessions.entries.toList()) {
      final session = entry.value;
      if (session.accountId != account.id) continue;
      final fingerprint = sha256.convert(utf8.encode(_sessionFingerprint(session))).toString();
      if (fingerprint == sessionId.trim()) {
        database.deleteSession(entry.key);
        return true;
      }
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // PASSWORD RECOVERY
  // ---------------------------------------------------------------------------

  /// Returns the configured security question for an account recovery request.
  /// The answer itself is never returned by the backend.
  String getSecurityQuestion(String login) {
    final normalized = login.trim().toLowerCase();
    Account? account = database.getAccountByEmail(normalized);
    account ??= database.getAccountByUsername(normalized);

    if (account == null || account.securityQuestion.trim().isEmpty) {
      throw Exception('We could not find an account with those sign-in details.');
    }

    return account.securityQuestion.trim();
  }

  /// Resets an existing account password after the account security answer
  /// has been verified. The plaintext password is never persisted.
  Future<void> resetPassword({
    required String login,
    required String securityAnswer,
    required String newPassword,
  }) async {
    final normalized = login.trim().toLowerCase();
    final answer = securityAnswer.trim().toLowerCase();

    if (newPassword.length < 6) {
      throw Exception('Password must be at least 10 characters long.');
    }
    if (answer.isEmpty) {
      throw Exception('Security answer is required.');
    }

    Account? account = database.getAccountByEmail(normalized);
    account ??= database.getAccountByUsername(normalized);

    if (account == null || account.securityAnswerHash.trim().isEmpty) {
      throw Exception('We could not verify the account recovery request.');
    }

    final valid = await _verifyPassword(answer, account.securityAnswerHash);
    if (!valid) {
      throw Exception('Incorrect security answer.');
    }

    account.passwordHash = await _hashPassword(newPassword);

    // Update the in-memory canonical account and persist the new credential
    // before reporting success. This prevents the next login from falling
    // back to a stale member identity or disappearing after a restart.
    database.saveAccount(account);
    await database.persistAccountAndWait(account);
  }

  // ---------------------------------------------------------------------------
  // ACCOUNT MEMBERS / INVITATIONS
  // ---------------------------------------------------------------------------

  Future<String> inviteMember({
    required Account account,
    required String email,
    String role = 'member',
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (!_isValidEmail(cleanEmail)) throw Exception('A valid member email address is required.');
    if (cleanEmail == account.email.trim().toLowerCase()) {
      throw Exception('The account owner is already a member.');
    }
    final token = _generateSessionToken();
    final tokenHash = sha256.convert(utf8.encode(token)).toString();
    final expiresAt = DateTime.now().toUtc().add(const Duration(days: 7));
    await SupabaseStore.instance.createMemberInvitation(
      accountExternalId: account.id,
      email: cleanEmail,
      role: role,
      tokenHash: tokenHash,
      expiresAt: expiresAt,
    );
    await emailService.memberInvitation(
      cleanEmail,
      account.username,
      token,
      expiresAt,
    );
    return token;
  }

  Future<Map<String, dynamic>> acceptMemberInvitation({
    required String token,
    required String email,
    String? password,
  }) async {
    final cleanToken = token.trim();
    final cleanEmail = email.trim().toLowerCase();
    if (cleanToken.isEmpty || !_isValidEmail(cleanEmail)) {
      throw Exception('A valid invitation and email are required.');
    }
    final tokenHash = sha256.convert(utf8.encode(cleanToken)).toString();
    String? passwordHash;
    if (password != null && password.isNotEmpty) {
      if (password.length < 10) throw Exception('Password must be at least 10 characters long.');
      passwordHash = await _hashPassword(password);
    }
    final result = await SupabaseStore.instance.acceptMemberInvitation(
      tokenHash: tokenHash,
      email: cleanEmail,
      passwordHash: passwordHash,
    );
    final account = database.getAccountById(result['accountId']?.toString() ?? '');
    if (account != null) {
      database.registerMemberLogin(MemberLoginRecord(
        memberId: result['memberId']?.toString() ?? '',
        accountId: account.id,
        email: cleanEmail,
        passwordHash: result['_passwordHash']?.toString() ?? passwordHash ?? account.passwordHash,
        role: result['role']?.toString() ?? 'member',
        status: 'active',
      ));
    }
    result.remove('_passwordHash');
    return result;
  }

  // ---------------------------------------------------------------------------
  // ACCOUNT DELETION
  // ---------------------------------------------------------------------------

  /// Performs `deleteAccount` for this feature. Update this documentation when its contract changes.
  void deleteAccount(
    Account account,
  ) {
    database.sessions.removeWhere(
      (_, session) => session.accountId == account.id,
    );

    database.remoteWorkersById.removeWhere(
      (_, worker) => worker.accountId == account.id,
    );

    database.remoteImportJobsById.removeWhere(
      (_, job) => job.accountId == account.id,
    );

    database.deleteAccount(
      account.id,
    );
  }

  // ---------------------------------------------------------------------------
  // SESSION LOOKUP
  // ---------------------------------------------------------------------------

  Account? accountFromToken(
    String token,
  ) {
    final cleanToken = token.trim();

    if (cleanToken.isEmpty) {
      return null;
    }

    return database.getAccountForSession(
      cleanToken,
    );
  }

  SessionRecord? sessionFromToken(
    String token,
  ) {
    final cleanToken = token.trim();

    if (cleanToken.isEmpty) {
      return null;
    }

    return database.getSession(
      cleanToken,
    );
  }

  // ---------------------------------------------------------------------------
  // SECURITY VERIFICATION
  // ---------------------------------------------------------------------------

  /// Verifies the authenticated account's security answer. The plaintext
  /// answer is compared only against the stored Argon2id hash.
  Future<bool> verifySecurityAnswer({
    required String token,
    required String answer,
  }) async {
    final account = accountFromToken(token);
    if (account == null || answer.trim().isEmpty) return false;
    return _verifyPassword(
      answer.trim().toLowerCase(),
      account.securityAnswerHash,
    );
  }

  // ---------------------------------------------------------------------------
  // LOGOUT
  // ---------------------------------------------------------------------------

  /// Performs `logout` for this feature. Update this documentation when its contract changes.
  void logout(
    String token,
  ) {
    final cleanToken = token.trim();

    if (cleanToken.isEmpty) {
      return;
    }

    database.deleteSession(
      cleanToken,
    );
  }

  /// Performs `logoutAllSessions` for this feature. Update this documentation when its contract changes.
  void logoutAllSessions(
    String accountId,
  ) {
    database.deleteSessionsForAccount(
      accountId,
    );
  }

  // ---------------------------------------------------------------------------
  // PROFILES
  // ---------------------------------------------------------------------------

  Profile addProfile({
    required Account account,
    required String name,
    String? avatarUrl,
  }) {
    final cleanName = name.trim();

    if (cleanName.isEmpty) {
      throw Exception(
        'Profile name is required.',
      );
    }

    if (!account.canAddProfile) {
      throw Exception(
        'You can have a maximum of ${Account.maxProfiles} profiles.',
      );
    }

    if (account.hasProfile(
      cleanName,
    )) {
      throw Exception(
        'A profile with that name already exists.',
      );
    }

    final cleanAvatarUrl = avatarUrl?.trim();

    final profile = Profile(
      id: _generateId('profile'),
      name: cleanName,
      avatarUrl:
          cleanAvatarUrl == null ||
                  cleanAvatarUrl.isEmpty
              ? null
              : cleanAvatarUrl,
    );

    account.addExistingProfile(
      profile,
    );

    database.saveAccount(
      account,
    );

    return profile;
  }

  /// Performs `removeProfile` for this feature. Update this documentation when its contract changes.
  void removeProfile({
    required Account account,
    required String profileId,
  }) {
    final cleanProfileId = profileId.trim();

    if (cleanProfileId.isEmpty) {
      throw Exception(
        'Profile ID is required.',
      );
    }

    if (account.profiles.length <= 1) {
      throw Exception(
        'The final profile cannot be deleted.',
      );
    }

    final profile = account.getProfileById(
      cleanProfileId,
    );

    if (profile == null) {
      throw Exception(
        'Profile not found.',
      );
    }

    account.removeProfile(
      cleanProfileId,
    );

    database.saveAccount(
      account,
    );
  }

  // ---------------------------------------------------------------------------
  // ACCOUNT UPDATE
  // ---------------------------------------------------------------------------

  Future<Account> updateAccount({
    required Account account,
    String? username,
    String? email,
    required String currentPassword,
  }) async {
    if (currentPassword.isEmpty ||
        !await _verifyPassword(currentPassword, account.passwordHash)) {
      throw Exception('Current password is incorrect.');
    }

    final nextUsername = username?.trim();
    final nextEmail = email?.trim().toLowerCase();

    if (nextUsername != null && nextUsername.isEmpty) {
      throw Exception('Username cannot be empty.');
    }
    if (nextEmail != null && !_isValidEmail(nextEmail)) {
      throw Exception('A valid email address is required.');
    }

    if (nextUsername != null &&
        nextUsername.toLowerCase() != account.username.trim().toLowerCase() &&
        database.getAccountByUsername(nextUsername) != null) {
      throw Exception('That username is already in use.');
    }

    if (nextEmail != null &&
        nextEmail != account.email.trim().toLowerCase() &&
        database.getAccountByEmail(nextEmail) != null) {
      throw Exception('That email address is already in use.');
    }

    if (nextUsername != null) account.username = nextUsername;
    if (nextEmail != null) account.email = nextEmail;

    database.saveAccount(account);
    return account;
  }

  // ---------------------------------------------------------------------------
  // PROFILE UPDATE
  // ---------------------------------------------------------------------------

  Future<Profile> updateProfile({
    required Account account,
    required String profileId,
    required String name,
    String? avatarUrl,
  }) async {
    final cleanId = profileId.trim();
    final cleanName = name.trim();
    if (cleanId.isEmpty) throw Exception('Profile ID is required.');
    if (cleanName.isEmpty) throw Exception('Profile name is required.');

    final profile = account.getProfileById(cleanId);
    if (profile == null) throw Exception('Profile not found.');

    final existing = account.profiles.any((item) =>
        item.id != cleanId &&
        item.name.trim().toLowerCase() == cleanName.toLowerCase());
    if (existing) throw Exception('A profile with that name already exists.');

    profile.name = cleanName;
    final cleanAvatar = avatarUrl?.trim();
    profile.avatarUrl = cleanAvatar == null || cleanAvatar.isEmpty
        ? null
        : cleanAvatar;

    database.saveAccount(account);

    return profile;
  }

  // ---------------------------------------------------------------------------
  // VALIDATION
  // ---------------------------------------------------------------------------

  /// Performs `_isValidEmail` for this feature. Update this documentation when its contract changes.
  bool _isValidEmail(
    String email,
  ) {
    final pattern = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    );

    return pattern.hasMatch(email);
  }
}
