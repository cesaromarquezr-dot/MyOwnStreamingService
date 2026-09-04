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

  String _generateId(String prefix) {
    final timestamp = DateTime.now().microsecondsSinceEpoch;

    return '${prefix}_$timestamp${_random.nextInt(100000)}';
  }

  String _generateSessionToken() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;

    final randomPart = List.generate(
      32,
      (_) => _random.nextInt(16).toRadixString(16),
    ).join();

    return 'session_${timestamp}_$randomPart';
  }

  Account createAccount({
    required String username,
    required String email,
    required String password,
    required SubscriptionPlan plan,
    required String firstProfileName,
  }) {
    username = username.trim();
    email = email.trim().toLowerCase();
    firstProfileName = firstProfileName.trim();

    if (username.isEmpty) {
      throw Exception('Username is required.');
    }

    if (email.isEmpty) {
      throw Exception('Email is required.');
    }

    if (password.length < 6) {
      throw Exception(
        'Password must be at least 6 characters.',
      );
    }

    if (firstProfileName.isEmpty) {
      throw Exception(
        'First profile name is required.',
      );
    }

    if (database.getAccountByUsername(username) != null) {
      throw Exception(
        'Username is already in use.',
      );
    }

    if (database.getAccountByEmail(email) != null) {
      throw Exception(
        'Email is already in use.',
      );
    }

    final account = Account(
      id: _generateId('account'),
      username: username,
      email: email,
      password: password,
    );

    final firstProfile = Profile(
      id: _generateId('profile'),
      name: firstProfileName,
    );

    account.profiles.add(firstProfile);

    subscriptionService.subscribe(
      account,
      plan,
    );

    database.saveAccount(account);

    return account;
  }

  String login({
    required String login,
    required String password,
  }) {
    login = login.trim();

    Account? account;

    account = database.getAccountByUsername(login);

    account ??= database.getAccountByEmail(login);

    if (account == null) {
      throw Exception(
        'Invalid username/email or password.',
      );
    }

    if (account.password != password) {
      throw Exception(
        'Invalid username/email or password.',
      );
    }

    final token = _generateSessionToken();

    database.sessions[token] = account.id;

    return token;
  }

  Account? accountFromToken(String token) {
    final accountId = database.sessions[token];

    if (accountId == null) {
      return null;
    }

    return database.getAccountById(accountId);
  }

  void logout(String token) {
    database.sessions.remove(token);
  }

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

    final profileName = name.trim();

    if (profileName.isEmpty) {
      throw Exception(
        'Profile name is required.',
      );
    }

    final profile = Profile(
      id: _generateId('profile'),
      name: profileName,
      avatarUrl: avatarUrl,
    );

    account.profiles.add(profile);

    return profile;
  }

  void removeProfile({
    required Account account,
    required String profileId,
  }) {
    if (account.profiles.length <= 1) {
      throw Exception(
        'The final profile cannot be deleted.',
      );
    }

    final index = account.profiles.indexWhere(
      (profile) => profile.id == profileId,
    );

    if (index == -1) {
      throw Exception(
        'Profile not found.',
      );
    }

    account.profiles.removeAt(index);
  }
}