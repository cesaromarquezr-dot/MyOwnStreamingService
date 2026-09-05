import 'dart:math';

import '../database/database.dart';
import '../models/account.dart';
import '../models/profile.dart';
import '../models/subscription.dart';
import 'subscription_service.dart';

class AuthService {
  final Database database;
  final SubscriptionService subscriptionService;

  final Random _random = Random();

  AuthService({
    required this.database,
    required this.subscriptionService,
  });

  // ------------------------------------------------------------
  // ID / SESSION GENERATION
  // ------------------------------------------------------------

  String _generateId(String prefix) {
    final timestamp =
        DateTime.now().microsecondsSinceEpoch;

    return '${prefix}_$timestamp'
        '${_random.nextInt(100000)}';
  }

  String _generateSessionToken() {
    final timestamp =
        DateTime.now().microsecondsSinceEpoch;

    final randomPart = List.generate(
      32,
      (_) => _random.nextInt(16)
          .toRadixString(16),
    ).join();

    return 'session_${timestamp}_$randomPart';
  }

  // ------------------------------------------------------------
  // ACCOUNT CREATION
  // ------------------------------------------------------------

  Account createAccount({
    required String username,
    required String email,
    required String password,
    required SubscriptionPlan plan,
    required String firstProfileName,
  }) {
    final cleanUsername =
        username.trim();

    final cleanEmail =
        email.trim().toLowerCase();

    final cleanProfileName =
        firstProfileName.trim();

    if (cleanUsername.isEmpty) {
      throw Exception(
        'Username is required.',
      );
    }

    if (cleanEmail.isEmpty) {
      throw Exception(
        'Email is required.',
      );
    }

    if (!_isValidEmail(cleanEmail)) {
      throw Exception(
        'Please enter a valid email address.',
      );
    }

    if (password.length < 6) {
      throw Exception(
        'Password must be at least 6 characters.',
      );
    }

    if (cleanProfileName.isEmpty) {
      throw Exception(
        'First profile name is required.',
      );
    }

    // ----------------------------------------------------------
    // DUPLICATE ACCOUNT CHECKS
    // ----------------------------------------------------------

    if (database.getAccountByUsername(
          cleanUsername,
        ) !=
        null) {
      throw Exception(
        'Username is already in use.',
      );
    }

    if (database.getAccountByEmail(
          cleanEmail,
        ) !=
        null) {
      throw Exception(
        'Email is already in use.',
      );
    }

    // ----------------------------------------------------------
    // CREATE ACCOUNT
    // ----------------------------------------------------------

    final account = Account(
      id: _generateId('account'),
      username: cleanUsername,
      email: cleanEmail,
      password: password,
    );

    // ----------------------------------------------------------
    // CREATE FIRST PROFILE
    // ----------------------------------------------------------

    final firstProfile = Profile(
      id: _generateId('profile'),
      name: cleanProfileName,
    );

    account.profiles.add(
      firstProfile,
    );

    // ----------------------------------------------------------
    // CREATE PENDING SUBSCRIPTION
    // ----------------------------------------------------------
    //
    // SubscriptionService.subscribe() now creates the
    // subscription as inactive.
    //
    // Payment verification must happen before the subscription
    // becomes active.
    //

    subscriptionService.subscribe(
      account,
      plan,
    );

    // ----------------------------------------------------------
    // SAVE ACCOUNT
    // ----------------------------------------------------------
    //
    // The account exists now, but it cannot log in because the
    // subscription is inactive.
    //

    database.saveAccount(account);

    return account;
  }

  // ------------------------------------------------------------
  // SUBSCRIPTION / PAYMENT STATE
  // ------------------------------------------------------------

  bool canLogin(Account account) {
    return account.hasActiveSubscription;
  }

  bool requiresPayment(Account account) {
    final subscription =
        account.subscription;

    if (subscription == null) {
      return true;
    }

    return !subscription.active;
  }

  // ------------------------------------------------------------
  // LOGIN
  // ------------------------------------------------------------

  String login({
    required String login,
    required String password,
  }) {
    final cleanLogin =
        login.trim();

    if (cleanLogin.isEmpty ||
        password.isEmpty) {
      throw Exception(
        'Invalid username/email or password.',
      );
    }

    Account? account;

    // ----------------------------------------------------------
    // USERNAME LOOKUP
    // ----------------------------------------------------------

    account =
        database.getAccountByUsername(
      cleanLogin,
    );

    // ----------------------------------------------------------
    // EMAIL LOOKUP
    // ----------------------------------------------------------

    account ??=
        database.getAccountByEmail(
      cleanLogin,
    );

    if (account == null) {
      throw Exception(
        'Invalid username/email or password.',
      );
    }

    // ----------------------------------------------------------
    // PASSWORD CHECK
    // ----------------------------------------------------------
    //
    // Prototype authentication only.
    //
    // This will eventually be replaced with secure password
    // hashing such as Argon2id/bcrypt/scrypt.
    //

    if (account.password != password) {
      throw Exception(
        'Invalid username/email or password.',
      );
    }

    // ----------------------------------------------------------
    // SUBSCRIPTION CHECK
    // ----------------------------------------------------------

    if (!account.hasActiveSubscription) {
      throw Exception(
        'Your subscription is not active. Please complete payment before logging in.',
      );
    }

    // ----------------------------------------------------------
    // CREATE SESSION
    // ----------------------------------------------------------

    final token =
        _generateSessionToken();

    database.saveSession(
      token,
      account.id,
    );

    return token;
  }

  // ------------------------------------------------------------
  // SESSION LOOKUP
  // ------------------------------------------------------------

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

  // ------------------------------------------------------------
  // LOGOUT
  // ------------------------------------------------------------

  void logout(String token) {
    final cleanToken =
        token.trim();

    if (cleanToken.isEmpty) {
      return;
    }

    database.deleteSession(
      cleanToken,
    );
  }

  // ------------------------------------------------------------
  // ADD PROFILE
  // ------------------------------------------------------------

  Profile addProfile({
    required Account account,
    required String name,
    String? avatarUrl,
  }) {
    if (!account.canAddProfile) {
      throw Exception(
        'You can have a maximum of 7 profiles.',
      );
    }

    final profileName =
        name.trim();

    if (profileName.isEmpty) {
      throw Exception(
        'Profile name is required.',
      );
    }

    // Don't allow duplicate profile names
    // within the same account.
    if (account.getProfileByName(
          profileName,
        ) !=
        null) {
      throw Exception(
        'A profile with that name already exists.',
      );
    }

    String? cleanAvatarUrl;

    if (avatarUrl != null) {
      final value =
          avatarUrl.trim();

      if (value.isNotEmpty) {
        cleanAvatarUrl = value;
      }
    }

    final profile = Profile(
      id: _generateId('profile'),
      name: profileName,
      avatarUrl: cleanAvatarUrl,
    );

    final added =
        account.addExistingProfile(
      profile,
    );

    if (!added) {
      throw Exception(
        'Unable to create profile.',
      );
    }

    database.saveAccount(account);

    return profile;
  }

  // ------------------------------------------------------------
  // REMOVE PROFILE
  // ------------------------------------------------------------

  void removeProfile({
    required Account account,
    required String profileId,
  }) {
    if (account.profiles.length <= 1) {
      throw Exception(
        'The final profile cannot be deleted.',
      );
    }

    final cleanProfileId =
        profileId.trim();

    if (cleanProfileId.isEmpty) {
      throw Exception(
        'Profile ID is required.',
      );
    }

    final removed =
        account.removeProfile(
      cleanProfileId,
    );

    if (!removed) {
      throw Exception(
        'Profile not found.',
      );
    }

    database.saveAccount(account);
  }

  // ------------------------------------------------------------
  // VALIDATION
  // ------------------------------------------------------------

  bool _isValidEmail(
    String email,
  ) {
    return RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(email);
  }
}