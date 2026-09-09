import 'dart:convert';
import 'dart:math';

import 'package:password_guard/password_guard.dart';

import '../database/database.dart';
import '../models/account.dart';
import '../models/profile.dart';
import '../models/subscription.dart';
import 'subscription_service.dart';

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

  final Random _random = Random.secure();

  AuthService({
    required this.database,
    required this.subscriptionService,
  });

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

  Future<String> _hashPassword(
    String password,
  ) async {
    final result = await PasswordGuard.hash(
      password: password,
      algorithm: PasswordAlgorithm.argon2id,
    );

    return result.hash;
  }

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

  Future<Account> createAccount({
    required String username,
    required String email,
    required String password,
    required SubscriptionPlan plan,
    required String firstProfileName,
  }) async {
    final cleanUsername = username.trim();
    final cleanEmail = email.trim().toLowerCase();
    final cleanProfileName = firstProfileName.trim();

    if (cleanUsername.isEmpty) {
      throw Exception(
        'Username is required.',
      );
    }

    if (!_isValidEmail(cleanEmail)) {
      throw Exception(
        'A valid email address is required.',
      );
    }

    if (password.length < 6) {
      throw Exception(
        'Password must be at least 6 characters long.',
      );
    }

    if (cleanProfileName.isEmpty) {
      throw Exception(
        'The first profile name is required.',
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

    // Passwords are never stored in plaintext.
    final passwordHash = await _hashPassword(password);

    final account = Account(
      id: _generateId('account'),
      username: cleanUsername,
      email: cleanEmail,
      passwordHash: passwordHash,
    );

    final firstProfile = Profile(
      id: _generateId('profile'),
      name: cleanProfileName,
    );

    account.profiles.add(firstProfile);

    // Signup intentionally creates an inactive subscription.
    //
    // Payment must be completed before login is allowed.
    subscriptionService.subscribe(
      account,
      plan,
    );

    database.saveAccount(account);

    return account;
  }

  // ---------------------------------------------------------------------------
  // SUBSCRIPTION / LOGIN ELIGIBILITY
  // ---------------------------------------------------------------------------

  bool canLogin(
    Account account,
  ) {
    return account.hasActiveSubscription;
  }

  bool requiresPayment(
    Account account,
  ) {
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

    if (cleanLogin.isEmpty || password.isEmpty) {
      database.recordFailedLogin(cleanLogin);
      throw Exception('Invalid username/email or password.');
    }

    Account? account;
    account = database.getAccountByUsername(cleanLogin);
    account ??= database.getAccountByEmail(cleanLogin);

    if (account == null) {
      database.recordFailedLogin(cleanLogin);
      throw Exception('Invalid username/email or password.');
    }

    final passwordValid = await _verifyPassword(
      password,
      account.passwordHash,
    );

    if (!passwordValid) {
      database.recordFailedLogin(cleanLogin);
      throw Exception('Invalid username/email or password.');
    }

    if (PasswordGuard.needsRehash(account.passwordHash)) {
      account.passwordHash = await _hashPassword(password);
      database.saveAccount(account);
    }

    if (!account.hasActiveSubscription) {
      throw Exception(
        'Your subscription is not active. Complete payment before logging in.',
      );
    }

    final recentFailures = database.recentFailedLoginCount(cleanLogin);
    final priorSessions = database.getSessionsForAccount(account.id);

    final normalizedIp = ipAddress.trim().isEmpty ? 'unknown' : ipAddress.trim();
    final normalizedAgent = userAgent.trim().isEmpty ? 'unknown' : userAgent.trim();

    final fingerprint = '$normalizedIp|$normalizedAgent';
    final knownFingerprints = database.getKnownLoginFingerprints(account.id);
    final knownDevice = knownFingerprints.contains(fingerprint);

    final reasons = <String>[];
    if (knownFingerprints.isNotEmpty && !knownDevice) {
      reasons.add('new browser or device or network');
    }
    if (recentFailures >= 2) {
      reasons.add('$recentFailures recent failed login attempts');
    }

    final suspicious = reasons.isNotEmpty;
    final token = _generateSessionToken();

    database.saveSession(
      token,
      account.id,
      ttl: Database.defaultSessionLifetime,
      ipAddress: normalizedIp,
      userAgent: normalizedAgent,
    );
    database.clearFailedLoginAttempts(cleanLogin);
    knownFingerprints.add(fingerprint);

    return AuthLoginResult(
      token: token,
      suspicious: suspicious,
      reasons: reasons,
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
  // LOGOUT
  // ---------------------------------------------------------------------------

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

    database.saveAccount(account);

    return profile;
  }

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

    database.saveAccount(account);
  }

  // ---------------------------------------------------------------------------
  // VALIDATION
  // ---------------------------------------------------------------------------

  bool _isValidEmail(
    String email,
  ) {
    final pattern = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    );

    return pattern.hasMatch(email);
  }
}