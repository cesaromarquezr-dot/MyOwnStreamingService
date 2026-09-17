// FILE: `Backend/models/media_session.dart`.
// Purpose: Models devices and independent playback/activity sessions.

class MediaDevice {
  final String id;
  final String profileId;
  final String name;
  final String type;
  final DateTime lastSeenAt;
  final bool online;

  const MediaDevice({
    required this.id,
    required this.profileId,
    required this.name,
    required this.type,
    required this.lastSeenAt,
    this.online = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'profileId': profileId,
        'name': name,
        'type': type,
        'lastSeenAt': lastSeenAt.toIso8601String(),
        'online': online,
      };
}

class PlaybackSession {
  final String id;
  final String profileId;
  final String deviceId;
  final String? mediaId;
  final String state;
  final double positionSeconds;
  final DateTime startedAt;
  final DateTime lastActivityAt;

  const PlaybackSession({
    required this.id,
    required this.profileId,
    required this.deviceId,
    this.mediaId,
    this.state = 'idle',
    this.positionSeconds = 0,
    required this.startedAt,
    required this.lastActivityAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'profileId': profileId,
        'deviceId': deviceId,
        'mediaId': mediaId,
        'state': state,
        'positionSeconds': positionSeconds,
        'startedAt': startedAt.toIso8601String(),
        'lastActivityAt': lastActivityAt.toIso8601String(),
      };
}
