// FILE: `Backend/models/group_chat_room.dart`.
// Purpose: Implements the group chat room portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.
//
// Group chat is account/profile scoped. Messages identify the profile that
// sent them, while the room retains account ownership and membership.
//
// This model contains chat content and therefore should only be serialized
// for members authorized to access the corresponding room.

class GroupChatMessage {
final String id;
final String profileId;
final String senderName;
final String message;
final DateTime timestamp;
final String? badgeName;

GroupChatMessage({
required this.id,
required this.profileId,
required this.senderName,
required this.message,
required this.timestamp,
this.badgeName,
});

factory GroupChatMessage.fromJson(
Map<String, dynamic> json,
) {
final timestampValue = json['timestamp'];

return GroupChatMessage(
  id: _stringValue(json['id']),
  profileId: _stringValue(json['profileId']),
  senderName: _stringOrDefault(
    json['senderName'],
    'Profile',
  ),
  message: _stringValue(json['message']),
  timestamp: timestampValue is DateTime
      ? timestampValue
      : DateTime.tryParse(
            timestampValue?.toString() ?? '',
          ) ??
          DateTime.now(),
  badgeName: _nullableString(
    json['badgeName'],
  ),
);

}

Map<String, dynamic> toJson() {
return {
'id': id,
'profileId': profileId,
'senderName': senderName,
'message': message,
'timestamp': timestamp.toIso8601String(),
'badgeName': badgeName,
};
}

GroupChatMessage copyWith({
String? id,
String? profileId,
String? senderName,
String? message,
DateTime? timestamp,
String? badgeName,
}) {
return GroupChatMessage(
id: id ?? this.id,
profileId: profileId ?? this.profileId,
senderName: senderName ?? this.senderName,
message: message ?? this.message,
timestamp: timestamp ?? this.timestamp,
badgeName: badgeName ?? this.badgeName,
);
}
}

class GroupChatMember {
final String profileId;
final String profileName;
final String username;
final String accountId;
final String status;

GroupChatMember({
required this.profileId,
required this.profileName,
required this.username,
required this.accountId,
this.status = GroupChatMemberStatus.active,
});

bool get isActive =>
status == GroupChatMemberStatus.active;

bool get isPending =>
status == GroupChatMemberStatus.pending;

bool get isBlocked =>
status == GroupChatMemberStatus.blocked;

factory GroupChatMember.fromJson(
Map<String, dynamic> json,
) {
return GroupChatMember(
profileId: _stringValue(json['profileId']),
profileName: _stringValue(json['profileName']),
username: _stringValue(json['username']),
accountId: _stringValue(json['accountId']),
status: _stringOrDefault(
json['status'],
GroupChatMemberStatus.active,
),
);
}

Map<String, dynamic> toJson() {
return {
'profileId': profileId,
'profileName': profileName,
'username': username,
'accountId': accountId,
'status': status,
};
}

GroupChatMember copyWith({
String? profileId,
String? profileName,
String? username,
String? accountId,
String? status,
}) {
return GroupChatMember(
profileId: profileId ?? this.profileId,
profileName: profileName ?? this.profileName,
username: username ?? this.username,
accountId: accountId ?? this.accountId,
status: status ?? this.status,
);
}
}

class GroupChatRoom {
final String id;
final String name;
final String ownerAccountId;
final List<GroupChatMember> members;
final List<GroupChatMessage> messages;
final DateTime createdAt;

GroupChatRoom({
required this.id,
required this.name,
required this.ownerAccountId,
required this.members,
required this.messages,
required this.createdAt,
});

factory GroupChatRoom.fromJson(
Map<String, dynamic> json,
) {
final rawMembers = json['members'];
final rawMessages = json['messages'];
final createdAtValue = json['createdAt'];

return GroupChatRoom(
  id: _stringValue(json['id']),
  name: _stringValue(json['name']),
  ownerAccountId: _stringValue(
    json['ownerAccountId'],
  ),
  members: rawMembers is List
      ? rawMembers
          .whereType<Map>()
          .map(
            (member) => GroupChatMember.fromJson(
              Map<String, dynamic>.from(member),
            ),
          )
          .toList()
      : <GroupChatMember>[],
  messages: rawMessages is List
      ? rawMessages
          .whereType<Map>()
          .map(
            (message) => GroupChatMessage.fromJson(
              Map<String, dynamic>.from(message),
            ),
          )
          .toList()
      : <GroupChatMessage>[],
  createdAt: createdAtValue is DateTime
      ? createdAtValue
      : DateTime.tryParse(
            createdAtValue?.toString() ?? '',
          ) ??
          DateTime.now(),
);

}

Map<String, dynamic> toJson() {
return {
'id': id,
'name': name,
'ownerAccountId': ownerAccountId,
'members': members
.map(
(member) => member.toJson(),
)
.toList(),
'messages': messages
.map(
(message) => message.toJson(),
)
.toList(),
'createdAt': createdAt.toIso8601String(),
};
}

// ---------------------------------------------------------------------------
// MEMBERS
// ---------------------------------------------------------------------------

GroupChatMember? getMember(
String profileId,
) {
for (final member in members) {
if (member.profileId == profileId) {
return member;
}
}

return null;

}

bool hasMember(
String profileId,
) {
return getMember(profileId) != null;
}

bool isActiveMember(
String profileId,
) {
return members.any(
(member) =>
member.profileId == profileId &&
member.isActive,
);
}

void addMember(
GroupChatMember member,
) {
if (member.profileId.trim().isEmpty) {
throw ArgumentError(
'A group chat member requires a profile ID.',
);
}

if (hasMember(member.profileId)) {
  throw StateError(
    'This profile is already a member of the room.',
  );
}

members.add(member);

}

void removeMember(
String profileId,
) {
if (profileId == ownerAccountId) {
throw StateError(
'The room owner cannot be removed as a profile member automatically.',
);
}

members.removeWhere(
  (member) => member.profileId == profileId,
);

}

// ---------------------------------------------------------------------------
// MESSAGES
// ---------------------------------------------------------------------------

void addMessage(
GroupChatMessage message,
) {
if (message.id.trim().isEmpty) {
throw ArgumentError(
'A group chat message requires an ID.',
);
}

if (message.profileId.trim().isEmpty) {
  throw ArgumentError(
    'A group chat message requires a profile ID.',
  );
}

if (message.message.trim().isEmpty) {
  throw ArgumentError(
    'A group chat message cannot be empty.',
  );
}

if (messages.any(
  (existing) => existing.id == message.id,
)) {
  throw StateError(
    'A message with this ID already exists.',
  );
}

messages.add(message);

}

void removeMessage(
String messageId,
) {
messages.removeWhere(
(message) => message.id == messageId,
);
}

/// Returns the most recent [limit] messages.
List<GroupChatMessage> recentMessages([
int limit = 50,
]) {
if (limit <= 0 || messages.isEmpty) {
return <GroupChatMessage>[];
}

final sorted = List<GroupChatMessage>.from(messages)
  ..sort(
    (a, b) => b.timestamp.compareTo(a.timestamp),
  );

return sorted.take(limit).toList();

}

GroupChatRoom copyWith({
String? id,
String? name,
String? ownerAccountId,
List<GroupChatMember>? members,
List<GroupChatMessage>? messages,
DateTime? createdAt,
}) {
return GroupChatRoom(
id: id ?? this.id,
name: name ?? this.name,
ownerAccountId:
ownerAccountId ?? this.ownerAccountId,
members: members ?? this.members,
messages: messages ?? this.messages,
createdAt: createdAt ?? this.createdAt,
);
}
}

/// Lifecycle states for group-chat membership.
abstract final class GroupChatMemberStatus {
static const String active = 'active';
static const String pending = 'pending';
static const String blocked = 'blocked';
static const String removed = 'removed';

const GroupChatMemberStatus._();
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