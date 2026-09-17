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
  final String token;
  final bool suspicious;
  final List<String> reasons;

  const AuthLoginResult({
    required this.token,
    required this.suspicious,
    required this.reasons,
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


    if (password.length < 6) {
      throw Exception(
        'Password must be at least 6 characters long.',
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
      throw Exception(
        'Invalid email or password.',
      );
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

    return AuthLoginResult(
      token: token,
      suspicious: suspicious,
      reasons: reasons,
    );
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
      throw Exception('Password must be at least 6 characters long.');
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
      if (password.length < 6) throw Exception('Password must be at least 6 characters long.');
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
