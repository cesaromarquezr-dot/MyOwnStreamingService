class GroupChatMessage {
  final String id;
  final String profileId;
  final String senderName;
  final String message;
  final DateTime timestamp;

  GroupChatMessage({
    required this.id,
    required this.profileId,
    required this.senderName,
    required this.message,
    required this.timestamp,
  });

  factory GroupChatMessage.fromJson(Map<String, dynamic> json) => GroupChatMessage(
        id: json['id']?.toString() ?? '',
        profileId: json['profileId']?.toString() ?? '',
        senderName: json['senderName']?.toString() ?? 'Profile',
        message: json['message']?.toString() ?? '',
        timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'profileId': profileId,
        'senderName': senderName,
        'message': message,
        'timestamp': timestamp.toIso8601String(),
      };
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
    this.status = 'active',
  });

  Map<String, dynamic> toJson() => {
        'profileId': profileId,
        'profileName': profileName,
        'username': username,
        'accountId': accountId,
        'status': status,
      };
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ownerAccountId': ownerAccountId,
        'members': members.map((m) => m.toJson()).toList(),
        'messages': messages.map((m) => m.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };
}
