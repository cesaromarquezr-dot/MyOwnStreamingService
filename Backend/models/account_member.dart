// FILE: `Backend/models/account_member.dart`.
// Purpose: Represents a person's membership in a streaming account.
// The login identity is separate from the account so one person can belong
// to multiple accounts while each account keeps its own home server.

class AccountMember {
  final String id;
  final String accountId;
  final String email;
  final String role;
  final String status;
  final String? profileId;
  final String? displayName;

  const AccountMember({
    required this.id,
    required this.accountId,
    required this.email,
    this.role = 'member',
    this.status = 'active',
    this.profileId,
    this.displayName,
  });
}

/// Backend-only login record. The password is always an Argon2id hash.
class MemberLoginRecord {
  final String memberId;
  final String accountId;
  final String email;
  final String passwordHash;
  final String role;
  final String status;

  const MemberLoginRecord({
    required this.memberId,
    required this.accountId,
    required this.email,
    required this.passwordHash,
    required this.role,
    required this.status,
  });
}
