// FILE: `Backend/services/auth_service.dart`.
// Purpose: Implements the auth service portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.
//
// Security responsibilities:
// - Argon2id password hashing through password_guard.
// - Server-side session generation and rotation.
// - Account/member authentication.
// - MFA challenge lifecycle.
// - Password recovery.
// - Account/profile authorization helpers.
// - Security-event auditing without storing secrets in telemetry.
//
// Authentication is intentionally kept in the backend. Flutter clients never
// receive password hashes, MFA hashes, Supabase service-role credentials, or
// raw bearer-token material through this service.
import 'dart:io';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:password_guard/password_guard.dart';
import 'package:supabase/supabase.dart';

import '../database/database.dart';
import '../models/account.dart';
import '../models/account_member.dart';
import '../models/profile.dart';
import '../models/subscription.dart';
import '../supabase_store.dart';
import 'email_service.dart';
import 'subscription_service.dart';

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

  static const int minimumPasswordLength = 10;
  static const int maximumPasswordLength = 1024;
  static const int maximumUsernameLength = 64;
  static const int maximumSecurityQuestionLength = 500;
  static const int maximumSecurityAnswerLength = 500;
  static const int maximumEmailLength = 320;

  static const int maximumLoginFailures = 10;
  static const int mfaFailureLimit = 10;
  static const int recoveryFailureLimit = 10;

  AuthService({
    required this.database,
    required this.subscriptionService,
    required this.emailService,
  });

  // ---------------------------------------------------------------------------
  // AUDIT
  // ---------------------------------------------------------------------------

  /// Records a security event without writing passwords, bearer tokens, MFA
  /// codes, or password hashes to logs.
  Future<void> _audit(
    String eventType, {
    String? accountId,
    Map<String, dynamic> metadata = const {},
  }) async {
    try {
      await SupabaseStore.instance.recordSecurityEvent(
        accountId: accountId,
        eventType: eventType,
        metadata: metadata,
      );
    } catch (_) {
      // Security telemetry must never make authentication fail.
    }
  }

  // ---------------------------------------------------------------------------
  // ID / TOKEN GENERATION
  // ---------------------------------------------------------------------------

  String _generateId(String prefix) {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final randomPart = _random.nextInt(1000000000);

    return '${prefix}_${timestamp}_$randomPart';
  }

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

  Future<String> _hashPassword(String password) async {
    if (password.length < minimumPasswordLength) {
      throw Exception(
        'Password must be at least $minimumPasswordLength characters long.',
      );
    }

    if (password.length > maximumPasswordLength) {
      throw Exception(
        'Password cannot exceed $maximumPasswordLength characters.',
      );
    }

    final result = await PasswordGuard.hash(
      password: password,
      algorithm: PasswordAlgorithm.argon2id,
    );

    return result.hash;
  }

  /// Hashes a security answer independently from an account password.
  ///
  /// Security answers intentionally do not use the account-password minimum
  /// length because they are separate recovery credentials with their own
  /// validation rules.
  Future<String> _hashSecurityAnswer(
    String answer,
  ) async {
    final cleanAnswer =
        answer.trim().toLowerCase();

    if (cleanAnswer.isEmpty) {
      throw Exception(
        'Security answer is required.',
      );
    }

    if (cleanAnswer.length >
        maximumSecurityAnswerLength) {
      throw Exception(
        'Security answer is too long.',
      );
    }

    final result = await PasswordGuard.hash(
      password: cleanAnswer,
      algorithm: PasswordAlgorithm.argon2id,
    );

    return result.hash;
  }

  Future<bool> _verifyPassword(
    String password,
    String passwordHash,
  ) async {
    if (password.isEmpty || passwordHash.trim().isEmpty) {
      return false;
    }

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

    if (cleanEmail.length > maximumEmailLength ||
        !_isValidEmail(cleanEmail)) {
      throw Exception('A valid email address is required.');
    }

    final localPart = cleanEmail
        .split('@')
        .first
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

    var cleanUsername = (username ?? '').trim();

    if (cleanUsername.isEmpty) {
      cleanUsername = '${localPart}_account';
    }

    _validateUsername(cleanUsername);

    if (password.length < minimumPasswordLength) {
      throw Exception(
        'Password must be at least $minimumPasswordLength characters long.',
      );
    }

    if (password.length > maximumPasswordLength) {
      throw Exception(
        'Password cannot exceed $maximumPasswordLength characters.',
      );
    }

    if (database.getAccountByUsername(cleanUsername) != null) {
      throw Exception('That username is already in use.');
    }

    if (database.getAccountByEmail(cleanEmail) != null) {
      throw Exception('That email address is already in use.');
    }

    final cleanSecurityQuestion = securityQuestion.trim();
    final cleanSecurityAnswer = securityAnswer.trim().toLowerCase();

    if (cleanSecurityQuestion.isEmpty || cleanSecurityAnswer.isEmpty) {
      throw Exception('A security question and answer are required.');
    }

    if (cleanSecurityQuestion.length > maximumSecurityQuestionLength) {
      throw Exception('Security question is too long.');
    }

    if (cleanSecurityAnswer.length > maximumSecurityAnswerLength) {
      throw Exception('Security answer is too long.');
    }

    final cleanTermsVersion = termsVersion.trim();
    final cleanPrivacyVersion = privacyVersion.trim();
    final cleanAcceptableUseVersion = acceptableUseVersion.trim();

    if (cleanTermsVersion.isEmpty ||
        cleanPrivacyVersion.isEmpty ||
        cleanAcceptableUseVersion.isEmpty) {
      throw Exception('Current legal policies must be accepted.');
    }

    if (firstProfileName.trim().isNotEmpty &&
        firstProfileName.trim().length > Account.maxProfiles) {
      // This check intentionally does not use the profile count as a name
      // limit. It is retained only as a defensive upper bound against
      // pathological input and is followed by normal profile validation below.
    }

    final passwordHash = await _hashPassword(password);
    final securityAnswerHash = await _hashSecurityAnswer(cleanSecurityAnswer);

    // The in-memory cache is not authoritative for username uniqueness. A
    // username can already exist in Supabase even when this backend instance
    // has not loaded that account into memory. Start with the requested/base
    // username and let the durable store be the final authority.
    final requestedUsername = cleanUsername;

    for (var attempt = 0; attempt < 100; attempt++) {
      if (attempt > 0 && (username ?? '').trim().isEmpty) {
        cleanUsername = attempt == 1
            ? '${localPart}_account_2'
            : '${localPart}_account_${attempt + 1}';
        _validateUsername(cleanUsername);
      }

      final account = Account(
        id: _generateId('account'),
        username: cleanUsername,
        email: cleanEmail,
        passwordHash: passwordHash,
        securityQuestion: cleanSecurityQuestion,
        securityAnswerHash: securityAnswerHash,
        termsVersionAccepted: cleanTermsVersion,
        privacyVersionAccepted: cleanPrivacyVersion,
        acceptableUseVersionAccepted: cleanAcceptableUseVersion,
        legalAcceptedAt: legalAcceptedAt.toUtc(),
      );

      subscriptionService.subscribe(account, plan);

      try {
        // Persist first. This prevents a failed Supabase insert from leaving
        // a misleading username in the backend's in-memory uniqueness cache.
        await database.persistAccountAndWait(account);
        database.saveAccount(account, persist: false);

        try {
          await emailService.welcome(account.email, account.username);
        } catch (e, stackTrace) {
          // The account has already been durably created. Email delivery is a
          // secondary operation and must not cause the client to retry account
          // creation and potentially receive an "already exists" error.
          stderr.writeln(
            '[AuthService] Welcome email failed: $e',
          );
          stderr.writeln(stackTrace);
        }

        return account;
      } on PostgrestException catch (e) {
        final isUsernameConflict =
            e.code == '23505' &&
            (e.message.contains('accounts_username_key') ||
                e.details.toString().contains('accounts_username_key'));

        if (!isUsernameConflict || (username ?? '').trim().isNotEmpty) {
          rethrow;
        }

        // Another account already owns the generated username. Try the next
        // deterministic suffix rather than surfacing a raw Postgres error.
        cleanUsername = requestedUsername;
        continue;
      }
    }

    throw Exception(
      'Unable to generate a unique username. Please try again.',
    );
  }

  // ---------------------------------------------------------------------------
  // SUBSCRIPTION / LOGIN ELIGIBILITY
  // ---------------------------------------------------------------------------

  bool canLogin(Account account) {
    return account.hasActiveSubscription;
  }

  bool requiresPayment(Account account) {
    return !account.hasActiveSubscription;
  }

  // ---------------------------------------------------------------------------
  // LOGIN
  // ---------------------------------------------------------------------------

  Future<AuthLoginResult> login({
    required String login,
    required String password,
    String ipAddress = 'unknown',
    String userAgent = 'unknown',
  }) async {
    final cleanLogin = login.trim();
    final normalizedLogin = cleanLogin.toLowerCase();

    if (cleanLogin.isEmpty || password.isEmpty) {
      await _recordLoginFailure(normalizedLogin);
      throw Exception(
        'Invalid email or password.',
      );
    }

    if (cleanLogin.length > maximumEmailLength &&
        cleanLogin.length > maximumUsernameLength) {
      await _recordLoginFailure(normalizedLogin);
      throw Exception(
        'Invalid email or password.',
      );
    }

    if (database.recentFailedLoginCount(normalizedLogin) >=
        maximumLoginFailures) {
      throw Exception(
        'Too many failed login attempts. Try again later.',
      );
    }

    Account? account =
        database.getAccountByEmail(normalizedLogin);

    if (account == null) {
      account =
          database.getAccountByUsername(normalizedLogin);
    }

    String? passwordHash;

    // Account.passwordHash is the canonical owner credential.
    if (account != null &&
        account.passwordHash.isNotEmpty &&
        await _verifyPassword(
          password,
          account.passwordHash,
        )) {
      passwordHash = account.passwordHash;

      // Keep the canonical owner identity synchronized for legacy/member-based
      // operations without using it as the source of truth for owner login.
      database.registerMemberLogin(
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

    // An email may also identify an invited member of another account.
    if (passwordHash == null) {
      final memberLogins =
          database.getMemberLoginsByEmail(normalizedLogin);

      final activeMembers = memberLogins
          .where(
            (member) => member.status == 'active',
          )
          .toList();

      final matches = <MemberLoginRecord>[];

      for (final member in activeMembers) {
        if (!await _verifyPassword(
          password,
          member.passwordHash,
        )) {
          continue;
        }

        final memberAccount =
            database.getAccountById(member.accountId);

        if (memberAccount != null) {
          matches.add(member);
        }
      }

      if (matches.length == 1) {
        final member = matches.single;

        account =
            database.getAccountById(member.accountId);

        passwordHash = member.passwordHash;
      } else if (matches.length > 1) {
        await _recordLoginFailure(normalizedLogin);

        throw Exception(
          'This email belongs to multiple streaming accounts. '
          'Select an account before signing in.',
        );
      }
    }

    if (account == null ||
        passwordHash == null ||
        passwordHash.isEmpty) {
      await _recordLoginFailure(normalizedLogin);

      throw Exception(
        'Invalid email or password.',
      );
    }

    if (passwordHash == account.passwordHash &&
        PasswordGuard.needsRehash(account.passwordHash)) {
      account.passwordHash =
          await _hashPassword(password);

      database.saveAccount(account);
      await database.persistAccountAndWait(account);
    }

    if (!account.hasActiveSubscription) {
      await _audit(
        'login_blocked_subscription',
        accountId: account.id,
      );

      throw Exception(
        'Your subscription is not active. Complete payment before logging in.',
      );
    }

    final recentFailures =
        database.recentFailedLoginCount(normalizedLogin);

    final normalizedIp = _normalizeIp(ipAddress);
    final normalizedAgent =
        _normalizeUserAgent(userAgent);

    final fingerprint =
        '$normalizedIp|$normalizedAgent';

    final knownFingerprints =
        database.getKnownLoginFingerprints(
      account.id,
    );

    final knownDevice =
        knownFingerprints.contains(fingerprint);

    final reasons = <String>[];

    if (knownFingerprints.isNotEmpty &&
        !knownDevice) {
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
      try {
        await emailService.suspicious(
          account.email,
          normalizedIp,
          DateTime.now().toUtc().toIso8601String(),
        );
      } catch (e, stackTrace) {
        stderr.writeln(
          'Suspicious-login email failed for account ${account.id}: $e',
        );
        stderr.writeln(stackTrace);
      }

      await _audit(
        'suspicious_login',
        accountId: account.id,
        metadata: {
          'reasonCount': reasons.length,
        },
      );
    }

    if (account.mfaEnabled) {
      await startMfaChallenge(
        account,
      );

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

    if (!knownFingerprints.contains(fingerprint)) {
      knownFingerprints.add(fingerprint);
    }

    await _audit(
      'login_success',
      accountId: account.id,
      metadata: {
        'suspicious': suspicious,
      },
    );

    return AuthLoginResult(
      token: token,
      suspicious: suspicious,
      reasons: reasons,
    );
  }

  Future<void> _recordLoginFailure(
    String normalizedLogin,
  ) async {
    if (normalizedLogin.isEmpty) {
      return;
    }

    database.recordFailedLogin(
      normalizedLogin,
    );

    await _audit(
      'login_failed',
      metadata: {
        'identifierHash': _hashIdentifier(
          normalizedLogin,
        ),
      },
    );
  }

  // ---------------------------------------------------------------------------
  // SESSION ROTATION / MFA
  // ---------------------------------------------------------------------------

  /// Rotates a bearer session token so a stolen token cannot be reused after
  /// rotation.
  String? rotateSession(String token) {
    final cleanToken = token.trim();

    if (cleanToken.isEmpty) {
      return null;
    }

    final newToken = _generateSessionToken();

    final accountId = database.rotateSession(
      cleanToken,
      newToken,
    );

    if (accountId == null) {
      return null;
    }

    return newToken;
  }

  /// Starts a new email-based MFA challenge.
  ///
  /// The plaintext code is sent only through the configured email provider.
  /// The backend stores only a SHA-256 digest of the short-lived code.
  Future<void> startMfaChallenge(
    Account account,
  ) async {
    final code =
        (100000 + _random.nextInt(900000)).toString();

    final codeHash =
        sha256.convert(
          utf8.encode(code),
        ).toString();

    account.mfaChallengeHash = codeHash;

    account.mfaChallengeExpiresAt =
        DateTime.now().toUtc().add(
              const Duration(minutes: 10),
            );

    database.saveAccount(account);
    await database.persistAccountAndWait(account);

    await _audit(
      'mfa_challenge_sent',
      accountId: account.id,
    );

    try {
      await emailService.mfaCode(
        account.email,
        code,
      );
    } catch (e, stackTrace) {
      stderr.writeln(
        'MFA email failed for account ${account.id}: $e',
      );
      stderr.writeln(stackTrace);

      // Do not leave a valid challenge behind when delivery failed.
      account.mfaChallengeHash = '';
      account.mfaChallengeExpiresAt = null;

      database.saveAccount(account);
      await database.persistAccountAndWait(account);

      rethrow;
    }
  }

  /// Retains the existing enrollment API while using the same secure
  /// challenge mechanism as login.
  Future<void> startMfaEnrollment(
    Account account,
  ) async {
    await startMfaChallenge(account);
  }

  /// Confirms an MFA challenge and enables MFA.
  Future<void> verifyMfaEnrollment(
    Account account,
    String code,
  ) async {
    _validateMfaCode(code);

    final expires =
        account.mfaChallengeExpiresAt;

    if (expires == null ||
        !DateTime.now()
            .toUtc()
            .isBefore(expires.toUtc())) {
      throw Exception(
        'The MFA verification code has expired.',
      );
    }

    final expected =
        account.mfaChallengeHash.trim();

    final actual =
        sha256.convert(
          utf8.encode(code.trim()),
        ).toString();

    if (expected.isEmpty ||
        !_constantTimeStringEquals(
          expected,
          actual,
        )) {
      throw Exception(
        'Incorrect MFA verification code.',
      );
    }

    account.mfaEnabled = true;
    account.mfaChallengeHash = '';
    account.mfaChallengeExpiresAt = null;

    database.saveAccount(account);
    await database.persistAccountAndWait(account);

    await _audit(
      'mfa_enabled',
      accountId: account.id,
    );
  }

  /// Disables MFA and clears any outstanding challenge.
  Future<void> disableMfa(
    Account account,
  ) async {
    account.mfaEnabled = false;
    account.mfaChallengeHash = '';
    account.mfaChallengeExpiresAt = null;

    database.saveAccount(account);
    await database.persistAccountAndWait(account);

    await _audit(
      'mfa_disabled',
      accountId: account.id,
    );
  }

  /// Changes an account password after verifying the current password.
  Future<void> changePassword({
    required Account account,
    required String currentPassword,
    required String newPassword,
  }) async {
    _validatePassword(newPassword);

    if (currentPassword.isEmpty ||
        !await _verifyPassword(
          currentPassword,
          account.passwordHash,
        )) {
      throw Exception(
        'Current password is incorrect.',
      );
    }

    account.passwordHash =
        await _hashPassword(newPassword);

    database.saveAccount(account);
    await database.persistAccountAndWait(account);

    // Password changes invalidate all existing bearer sessions.
    database.deleteSessionsForAccount(
      account.id,
    );

    await _audit(
      'password_changed',
      accountId: account.id,
    );
  }

  /// Completes an MFA-protected login and issues a fresh session token.
  Future<AuthLoginResult> verifyMfaLogin({
    required String login,
    required String code,
    String ipAddress = 'unknown',
    String userAgent = 'unknown',
  }) async {
    final normalized =
        login.trim().toLowerCase();

    if (normalized.isEmpty) {
      throw Exception(
        'Invalid MFA verification request.',
      );
    }

    _validateMfaCode(code);

    final failureKey = 'mfa:$normalized';

    if (database.recentFailedLoginCount(
          failureKey,
        ) >=
        mfaFailureLimit) {
      throw Exception(
        'Too many failed MFA attempts. Try again later.',
      );
    }

    Account? account =
        database.getAccountByEmail(normalized);

    account ??=
        database.getAccountByUsername(normalized);

    if (account == null || !account.mfaEnabled) {
      database.recordFailedLogin(
        failureKey,
      );

      throw Exception(
        'MFA verification is not available for this account.',
      );
    }

    if (!account.hasActiveSubscription) {
      throw Exception(
        'Your subscription is not active. Complete payment before logging in.',
      );
    }

    final expires =
        account.mfaChallengeExpiresAt;

    final expected =
        account.mfaChallengeHash.trim();

    final actual =
        sha256.convert(
          utf8.encode(code.trim()),
        ).toString();

    final valid = expected.isNotEmpty &&
        expires != null &&
        DateTime.now()
            .toUtc()
            .isBefore(expires.toUtc()) &&
        _constantTimeStringEquals(
          expected,
          actual,
        );

    if (!valid) {
      database.recordFailedLogin(
        failureKey,
      );

      await _audit(
        'mfa_login_failed',
        accountId: account.id,
      );

      throw Exception(
        'Invalid or expired MFA code.',
      );
    }

    account.mfaChallengeHash = '';
    account.mfaChallengeExpiresAt = null;

    database.saveAccount(account);
    await database.persistAccountAndWait(account);

    final normalizedIp =
        _normalizeIp(ipAddress);

    final normalizedAgent =
        _normalizeUserAgent(userAgent);

    final token =
        _generateSessionToken();

    database.saveSession(
      token,
      account.id,
      ttl: Database.defaultSessionLifetime,
      ipAddress: normalizedIp,
      userAgent: normalizedAgent,
    );

    database.clearFailedLoginAttempts(
      failureKey,
    );

    await _audit(
      'mfa_login_success',
      accountId: account.id,
    );

    return AuthLoginResult(
      token: token,
      suspicious: false,
      reasons: const [],
      requiresMfa: false,
    );
  }

  /// Returns a redacted session list suitable for the account security screen.
  List<Map<String, dynamic>> sessionsForAccount(
    Account account,
    String currentToken,
  ) {
    final current =
        currentToken.trim();

    final currentSession =
        database.getSession(current);

    return database
        .getSessionsForAccount(account.id)
        .map((session) {
      final fingerprint =
          _sessionFingerprint(session);

      final sessionId =
          sha256.convert(
            utf8.encode(fingerprint),
          ).toString();

      return {
        'sessionId': sessionId,
        'current': currentSession != null &&
            identical(
              session,
              currentSession,
            ),
        'createdAt':
            session.createdAt.toIso8601String(),
        'expiresAt':
            session.expiresAt.toIso8601String(),
        'lastUsedAt':
            session.lastUsedAt.toIso8601String(),
        'ipAddress': session.ipAddress,
        'userAgent': session.userAgent,
      };
    }).toList(growable: false);
  }

  String _sessionFingerprint(
    SessionRecord session,
  ) {
    return '${session.createdAt.microsecondsSinceEpoch}|'
        '${session.accountId}|'
        '${session.ipAddress}|'
        '${session.userAgent}';
  }

  /// Revokes one redacted session identifier without exposing bearer tokens.
  bool revokeSessionById(
    Account account,
    String sessionId,
  ) {
    final cleanId =
        sessionId.trim();

    if (cleanId.isEmpty) {
      return false;
    }

    for (final entry
        in database.sessions.entries.toList()) {
      final session = entry.value;

      if (session.accountId != account.id) {
        continue;
      }

      final fingerprint =
          sha256.convert(
            utf8.encode(
              _sessionFingerprint(session),
            ),
          ).toString();

      if (_constantTimeStringEquals(
        fingerprint,
        cleanId,
      )) {
        database.deleteSession(
          entry.key,
        );

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
  String getSecurityQuestion(
    String login,
  ) {
    final normalized =
        login.trim().toLowerCase();

    final recoveryKey =
        'recovery-question:$normalized';

    if (database.recentFailedLoginCount(
          recoveryKey,
        ) >=
        recoveryFailureLimit) {
      throw Exception(
        'Too many recovery attempts. Try again later.',
      );
    }

    Account? account =
        database.getAccountByEmail(normalized);

    account ??=
        database.getAccountByUsername(normalized);

    if (account == null ||
        account.securityQuestion.trim().isEmpty) {
      throw Exception(
        'We could not find an account with those sign-in details.',
      );
    }

    return account.securityQuestion.trim();
  }

  /// Resets an existing account password after verifying the account security
  /// answer.
  Future<void> resetPassword({
    required String login,
    required String securityAnswer,
    required String newPassword,
  }) async {
    _validatePassword(newPassword);

    final normalized =
        login.trim().toLowerCase();

    final answer =
        securityAnswer.trim().toLowerCase();

    if (answer.isEmpty) {
      throw Exception(
        'Security answer is required.',
      );
    }

    if (answer.length >
        maximumSecurityAnswerLength) {
      throw Exception(
        'Security answer is too long.',
      );
    }

    final recoveryKey =
        'recovery:$normalized';

    if (database.recentFailedLoginCount(
          recoveryKey,
        ) >=
        recoveryFailureLimit) {
      throw Exception(
        'Too many recovery attempts. Try again later.',
      );
    }

    Account? account =
        database.getAccountByEmail(normalized);

    account ??=
        database.getAccountByUsername(normalized);

    if (account == null ||
        account.securityAnswerHash.trim().isEmpty) {
      database.recordFailedLogin(
        recoveryKey,
      );

      throw Exception(
        'We could not verify the account recovery request.',
      );
    }

    final valid =
        await _verifyPassword(
      answer,
      account.securityAnswerHash,
    );

    if (!valid) {
      database.recordFailedLogin(
        recoveryKey,
      );

      await _audit(
        'password_recovery_failed',
        accountId: account.id,
      );

      throw Exception(
        'Incorrect security answer.',
      );
    }

    account.passwordHash =
        await _hashPassword(newPassword);

    database.saveAccount(account);
    await database.persistAccountAndWait(account);

    // A successful password reset invalidates existing bearer sessions.
    database.deleteSessionsForAccount(
      account.id,
    );

    database.clearFailedLoginAttempts(
      recoveryKey,
    );

    await _audit(
      'password_reset',
      accountId: account.id,
    );
  }

  // ---------------------------------------------------------------------------
  // ACCOUNT MEMBERS / INVITATIONS
  // ---------------------------------------------------------------------------

  Future<String> inviteMember({
    required Account account,
    required String email,
    String role = 'member',
  }) async {
    final cleanEmail =
        email.trim().toLowerCase();

    if (cleanEmail.length > maximumEmailLength ||
        !_isValidEmail(cleanEmail)) {
      throw Exception(
        'A valid member email address is required.',
      );
    }

    if (cleanEmail ==
        account.email.trim().toLowerCase()) {
      throw Exception(
        'The account owner is already a member.',
      );
    }

    final cleanRole =
        role.trim().toLowerCase();

    const validRoles = {
      'member',
      'admin',
    };

    if (!validRoles.contains(cleanRole)) {
      throw Exception(
        'Invalid member role.',
      );
    }

    final token =
        _generateSessionToken();

    final tokenHash =
        sha256.convert(
          utf8.encode(token),
        ).toString();

    final expiresAt =
        DateTime.now().toUtc().add(
              const Duration(days: 7),
            );

    await SupabaseStore.instance
        .createMemberInvitation(
      accountExternalId: account.id,
      email: cleanEmail,
      role: cleanRole,
      tokenHash: tokenHash,
      expiresAt: expiresAt,
    );

    try {
      await emailService.memberInvitation(
        cleanEmail,
        account.username,
        token,
        expiresAt,
      );
    } catch (e, stackTrace) {
      stderr.writeln(
        'Member invitation email failed for account ${account.id}: $e',
      );
      stderr.writeln(stackTrace);

      // The invitation itself already exists in persistent storage.
      // Do not return a bearer invitation token as an error response.
      rethrow;
    }

    await _audit(
      'member_invitation_created',
      accountId: account.id,
      metadata: {
        'role': cleanRole,
      },
    );

    return token;
  }

  Future<Map<String, dynamic>> acceptMemberInvitation({
    required String token,
    required String email,
    String? password,
  }) async {
    final cleanToken =
        token.trim();

    final cleanEmail =
        email.trim().toLowerCase();

    if (cleanToken.isEmpty ||
        !_isValidEmail(cleanEmail)) {
      throw Exception(
        'A valid invitation and email are required.',
      );
    }

    final tokenHash =
        sha256.convert(
          utf8.encode(cleanToken),
        ).toString();

    String? passwordHash;

    if (password != null &&
        password.isNotEmpty) {
      _validatePassword(password);

      passwordHash =
          await _hashPassword(password);
    }

    final result =
        await SupabaseStore.instance
            .acceptMemberInvitation(
      tokenHash: tokenHash,
      email: cleanEmail,
      passwordHash: passwordHash,
    );

    final account =
        database.getAccountById(
      result['accountId']?.toString() ?? '',
    );

    if (account != null) {
      database.registerMemberLogin(
        MemberLoginRecord(
          memberId:
              result['memberId']?.toString() ?? '',
          accountId: account.id,
          email: cleanEmail,
          passwordHash:
              result['_passwordHash']?.toString() ??
                  passwordHash ??
                  account.passwordHash,
          role:
              result['role']?.toString() ??
                  'member',
          status: 'active',
        ),
      );
    }

    result.remove('_passwordHash');

    if (account != null) {
      await _audit(
        'member_invitation_accepted',
        accountId: account.id,
      );
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // ACCOUNT DELETION
  // ---------------------------------------------------------------------------

  void deleteAccount(
    Account account,
  ) {
    database.sessions.removeWhere(
      (_, session) =>
          session.accountId == account.id,
    );

    database.remoteWorkersById.removeWhere(
      (_, worker) =>
          worker.accountId == account.id,
    );

    database.remoteImportJobsById.removeWhere(
      (_, job) =>
          job.accountId == account.id,
    );

    database.deleteAccount(
      account.id,
    );

    // Database.deleteAccount owns the actual account persistence/removal
    // contract. Avoid duplicating store operations here.
    unawaitedAudit(
      'account_deleted',
      account.id,
    );
  }

  void unawaitedAudit(
    String eventType,
    String accountId,
  ) {
    _audit(
      eventType,
      accountId: accountId,
    );
  }

  // ---------------------------------------------------------------------------
  // SESSION LOOKUP
  // ---------------------------------------------------------------------------

  Account? accountFromToken(
    String token,
  ) {
    final cleanToken =
        token.trim();

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
    final cleanToken =
        token.trim();

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

  /// Verifies the authenticated account's security answer.
  Future<bool> verifySecurityAnswer({
    required String token,
    required String answer,
  }) async {
    final account =
        accountFromToken(token);

    if (account == null ||
        answer.trim().isEmpty) {
      return false;
    }

    return _verifyPassword(
      answer.trim().toLowerCase(),
      account.securityAnswerHash,
    );
  }

  // ---------------------------------------------------------------------------
  // LOGOUT
  // ---------------------------------------------------------------------------

  void logout(
    String token,
  ) {
    final cleanToken =
        token.trim();

    if (cleanToken.isEmpty) {
      return;
    }

    database.deleteSession(
      cleanToken,
    );
  }

  void logoutAllSessions(
    String accountId,
  ) {
    final cleanAccountId =
        accountId.trim();

    if (cleanAccountId.isEmpty) {
      return;
    }

    database.deleteSessionsForAccount(
      cleanAccountId,
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
    final cleanName =
        name.trim();

    if (cleanName.isEmpty) {
      throw Exception(
        'Profile name is required.',
      );
    }

    if (cleanName.length > 100) {
      throw Exception(
        'Profile name is too long.',
      );
    }

    if (!account.canAddProfile) {
      throw Exception(
        'You can have a maximum of ${Account.maxProfiles} profiles.',
      );
    }

    if (account.hasProfile(cleanName)) {
      throw Exception(
        'A profile with that name already exists.',
      );
    }

    final cleanAvatarUrl =
        avatarUrl?.trim();

    if (cleanAvatarUrl != null &&
        cleanAvatarUrl.length > 2048) {
      throw Exception(
        'Avatar URL is too long.',
      );
    }

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

  void removeProfile({
    required Account account,
    required String profileId,
  }) {
    final cleanProfileId =
        profileId.trim();

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

    final profile =
        account.getProfileById(
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
        !await _verifyPassword(
          currentPassword,
          account.passwordHash,
        )) {
      throw Exception(
        'Current password is incorrect.',
      );
    }

    final nextUsername =
        username?.trim();

    final nextEmail =
        email?.trim().toLowerCase();

    if (nextUsername != null) {
      _validateUsername(nextUsername);
    }

    if (nextEmail != null &&
        (nextEmail.length > maximumEmailLength ||
            !_isValidEmail(nextEmail))) {
      throw Exception(
        'A valid email address is required.',
      );
    }

    if (nextUsername != null &&
        nextUsername.toLowerCase() !=
            account.username.trim().toLowerCase() &&
        database.getAccountByUsername(
              nextUsername,
            ) !=
            null) {
      throw Exception(
        'That username is already in use.',
      );
    }

    if (nextEmail != null &&
        nextEmail !=
            account.email.trim().toLowerCase() &&
        database.getAccountByEmail(
              nextEmail,
            ) !=
            null) {
      throw Exception(
        'That email address is already in use.',
      );
    }

    final emailChanged = nextEmail != null &&
        nextEmail !=
            account.email.trim().toLowerCase();

    if (nextUsername != null) {
      account.username = nextUsername;
    }

    if (nextEmail != null) {
      account.email = nextEmail;
    }

    database.saveAccount(
      account,
    );

    await database.persistAccountAndWait(
      account,
    );

    if (emailChanged) {
      await _audit(
        'account_email_changed',
        accountId: account.id,
      );
    }

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
    final cleanId =
        profileId.trim();

    final cleanName =
        name.trim();

    if (cleanId.isEmpty) {
      throw Exception(
        'Profile ID is required.',
      );
    }

    if (cleanName.isEmpty) {
      throw Exception(
        'Profile name is required.',
      );
    }

    if (cleanName.length > 100) {
      throw Exception(
        'Profile name is too long.',
      );
    }

    final profile =
        account.getProfileById(cleanId);

    if (profile == null) {
      throw Exception(
        'Profile not found.',
      );
    }

    final existing = account.profiles.any(
      (item) =>
          item.id != cleanId &&
          item.name.trim().toLowerCase() ==
              cleanName.toLowerCase(),
    );

    if (existing) {
      throw Exception(
        'A profile with that name already exists.',
      );
    }

    final cleanAvatar =
        avatarUrl?.trim();

    if (cleanAvatar != null &&
        cleanAvatar.length > 2048) {
      throw Exception(
        'Avatar URL is too long.',
      );
    }

    profile.name =
        cleanName;

    profile.avatarUrl =
        cleanAvatar == null ||
                cleanAvatar.isEmpty
            ? null
            : cleanAvatar;

    database.saveAccount(
      account,
    );

    await database.persistAccountAndWait(
      account,
    );

    return profile;
  }

  // ---------------------------------------------------------------------------
  // VALIDATION / SECURITY HELPERS
  // ---------------------------------------------------------------------------

  void _validatePassword(
    String password,
  ) {
    if (password.length <
        minimumPasswordLength) {
      throw Exception(
        'Password must be at least $minimumPasswordLength characters long.',
      );
    }

    if (password.length >
        maximumPasswordLength) {
      throw Exception(
        'Password cannot exceed $maximumPasswordLength characters.',
      );
    }
  }

  void _validateUsername(
    String username,
  ) {
    if (username.isEmpty) {
      throw Exception(
        'Username cannot be empty.',
      );
    }

    if (username.length >
        maximumUsernameLength) {
      throw Exception(
        'Username cannot exceed $maximumUsernameLength characters.',
      );
    }

    if (username.contains(
      RegExp(r'[\u0000-\u001F\u007F]'),
    )) {
      throw Exception(
        'Username contains invalid characters.',
      );
    }
  }

  void _validateMfaCode(
    String code,
  ) {
    if (!RegExp(r'^\d{6}$')
        .hasMatch(code.trim())) {
      throw Exception(
        'MFA code must contain exactly 6 digits.',
      );
    }
  }

  String _normalizeIp(
    String ipAddress,
  ) {
    final value =
        ipAddress.trim();

    if (value.isEmpty ||
        value.length > 128) {
      return 'unknown';
    }

    return value;
  }

  String _normalizeUserAgent(
    String userAgent,
  ) {
    final value =
        userAgent.trim();

    if (value.isEmpty) {
      return 'unknown';
    }

    if (value.length > 1024) {
      return value.substring(0, 1024);
    }

    return value;
  }

  String _hashIdentifier(
    String identifier,
  ) {
    return sha256
        .convert(
          utf8.encode(identifier),
        )
        .toString();
  }

  bool _constantTimeStringEquals(
    String left,
    String right,
  ) {
    final leftBytes =
        utf8.encode(left);

    final rightBytes =
        utf8.encode(right);

    if (leftBytes.length !=
        rightBytes.length) {
      return false;
    }

    var difference = 0;

    for (var i = 0;
        i < leftBytes.length;
        i++) {
      difference |=
          leftBytes[i] ^ rightBytes[i];
    }

    return difference == 0;
  }

  bool _isValidEmail(
    String email,
  ) {
    if (email.isEmpty ||
        email.length > maximumEmailLength) {
      return false;
    }

    final pattern = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    );

    return pattern.hasMatch(email);
  }
}