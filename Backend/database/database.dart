import '../models/account.dart';

class Database {
  Database._();

  static final Database instance = Database._();

  final Map<String, Account> accountsById = {};

  final Map<String, String> accountIdByUsername = {};

  final Map<String, String> accountIdByEmail = {};

  final Map<String, String> sessions = {};

  void clear() {
    accountsById.clear();
    accountIdByUsername.clear();
    accountIdByEmail.clear();
    sessions.clear();
  }

  Account? getAccountById(String id) {
    return accountsById[id];
  }

  Account? getAccountByUsername(String username) {
    final accountId = accountIdByUsername[username.toLowerCase()];

    if (accountId == null) {
      return null;
    }

    return accountsById[accountId];
  }

  Account? getAccountByEmail(String email) {
    final accountId = accountIdByEmail[email.toLowerCase()];

    if (accountId == null) {
      return null;
    }

    return accountsById[accountId];
  }

  void saveAccount(Account account) {
    accountsById[account.id] = account;

    accountIdByUsername[account.username.toLowerCase()] =
        account.id;

    accountIdByEmail[account.email.toLowerCase()] =
        account.id;
  }

  void deleteAccount(String accountId) {
    final account = accountsById[accountId];

    if (account == null) {
      return;
    }

    accountsByUsernameRemove(account.username);
    accountsByEmailRemove(account.email);

    accountsById.remove(accountId);

    sessions.removeWhere(
      (_, storedAccountId) => storedAccountId == accountId,
    );
  }

  void accountsByUsernameRemove(String username) {
    accountIdByUsername.remove(username.toLowerCase());
  }

  void accountsByEmailRemove(String email) {
    accountIdByEmail.remove(email.toLowerCase());
  }
}