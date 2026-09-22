// FILE: `Backend/models/account_member.dart`.
// Purpose: Represents a person's membership in a streaming account.
// The login identity is separate from the account so one person can belong
// to multiple accounts while each account keeps its own home server.
//
// Public AccountMember objects intentionally contain no password material.
// MemberLoginRecord is a backend-only credential record and must never be
// serialized into public account/member responses.

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
this.role = AccountMemberRole.member,
this.status = AccountMemberStatus.active,
this.profileId,
this.displayName,
});

/// Normalized email used for account/member lookups.
String get normalizedEmail => email.trim().toLowerCase();

/// Whether this membership is currently active.
bool get isActive => status == AccountMemberStatus.active;

/// Whether this membership has administrator privileges.
bool get isAdmin => role == AccountMemberRole.admin;

/// Whether this membership has owner privileges.
bool get isOwner => role == AccountMemberRole.owner;

/// Creates a public member object from persisted data.
factory AccountMember.fromJson(
Map<String, dynamic> json,
) {
return AccountMember(
id: _stringValue(json['id']),
accountId: _stringValue(
json['accountId'] ?? json['account_id'],
),
email: _stringValue(json['email']),
role: _stringOrDefault(
json['role'],
AccountMemberRole.member,
),
status: _stringOrDefault(
json['status'],
AccountMemberStatus.active,
),
profileId: _nullableString(
json['profileId'] ?? json['profile_id'],
),
displayName: _nullableString(
json['displayName'] ?? json['display_name'],
),
);
}

/// Serializes only public membership data.
///
/// Password hashes and other authentication secrets are not part of this
/// representation.
Map<String, dynamic> toJson() {
return {
'id': id,
'accountId': accountId,
'email': email,
'role': role,
'status': status,
if (profileId != null) 'profileId': profileId,
if (displayName != null) 'displayName': displayName,
};
}

AccountMember copyWith({
String? id,
String? accountId,
String? email,
String? role,
String? status,
String? profileId,
String? displayName,
}) {
return AccountMember(
id: id ?? this.id,
accountId: accountId ?? this.accountId,
email: email ?? this.email,
role: role ?? this.role,
status: status ?? this.status,
profileId: profileId ?? this.profileId,
displayName: displayName ?? this.displayName,
);
}

@override
String toString() {
return 'AccountMember('
'id: $id, '
'accountId: $accountId, '
'email: $email, '
'role: $role, '
'status: $status, '
'profileId: $profileId, '
'displayName: $displayName'
')';
}
}

/// Backend-only login record.
///
/// `passwordHash` must contain an Argon2id password hash. This class should
/// remain inside authentication/database boundaries and must never be returned
/// directly from an API endpoint.
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

String get normalizedEmail => email.trim().toLowerCase();

bool get isActive => status == AccountMemberStatus.active;

bool get isAdmin => role == AccountMemberRole.admin;

bool get isOwner => role == AccountMemberRole.owner;

/// Creates a credential record from persisted backend data.
factory MemberLoginRecord.fromJson(
Map<String, dynamic> json,
) {
return MemberLoginRecord(
memberId: _stringValue(
json['memberId'] ?? json['member_id'],
),
accountId: _stringValue(
json['accountId'] ?? json['account_id'],
),
email: _stringValue(json['email']),
passwordHash: _stringValue(
json['passwordHash'] ?? json['password_hash'],
),
role: _stringOrDefault(
json['role'],
AccountMemberRole.member,
),
status: _stringOrDefault(
json['status'],
AccountMemberStatus.active,
),
);
}

/// Serializes backend persistence data.
///
/// Callers must ensure this method is never used for public API responses.
Map<String, dynamic> toJson() {
return {
'memberId': memberId,
'accountId': accountId,
'email': email,
'passwordHash': passwordHash,
'role': role,
'status': status,
};
}

/// Produces the safe public representation without the password hash.
AccountMember toAccountMember({
String? profileId,
String? displayName,
}) {
return AccountMember(
id: memberId,
accountId: accountId,
email: email,
role: role,
status: status,
profileId: profileId,
displayName: displayName,
);
}
}

/// Supported account-member roles.
///
/// These are application-level values rather than authentication secrets.
abstract final class AccountMemberRole {
static const String owner = 'owner';
static const String admin = 'admin';
static const String member = 'member';

const AccountMemberRole._();
}

/// Supported account-member lifecycle states.
abstract final class AccountMemberStatus {
static const String active = 'active';
static const String invited = 'invited';
static const String suspended = 'suspended';
static const String disabled = 'disabled';

const AccountMemberStatus._();
}

String _stringValue(
Object? value,
) {
return value?.toString().trim() ?? '';
}

String _stringOrDefault(
Object? value,
String fallback,
) {
final result = value?.toString().trim();

if (result == null || result.isEmpty) {
return fallback;
}

return result;
}

String? _nullableString(
Object? value,
) {
final result = value?.toString().trim();

if (result == null || result.isEmpty) {
return null;
}

return result;
}
