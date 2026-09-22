// FILE: `Backend/models/media_session.dart`.
// Purpose: Models devices and independent playback/activity sessions.
//
// A MediaDevice represents a physical/client playback endpoint.
// A PlaybackSession represents one independent playback/activity context.
//
// Device identity and playback-session identity are intentionally separate:
// the same device can host multiple sessions over time, and a profile can
// use multiple devices simultaneously.

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

  /// Whether this device has the minimum identity information required for
  /// persistence.
  bool get isValid =>
      id.trim().isNotEmpty &&
      profileId.trim().isNotEmpty &&
      name.trim().isNotEmpty &&
      type.trim().isNotEmpty;

  /// Creates a modified copy without changing the original device.
  MediaDevice copyWith({
    String? id,
    String? profileId,
    String? name,
    String? type,
    DateTime? lastSeenAt,
    bool? online,
  }) {
    return MediaDevice(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      name: name ?? this.name,
      type: type ?? this.type,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      online: online ?? this.online,
    );
  }

  factory MediaDevice.fromJson(Map<String, dynamic> json) {
    return MediaDevice(
      id: _stringValue(json['id']),
      profileId: _stringValue(json['profileId']),
      name: _stringValue(json['name']),
      type: _stringValue(json['type']),
      lastSeenAt: _dateTimeValue(
        json['lastSeenAt'],
        fallback: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      ),
      online: _boolValue(json['online'], fallback: true),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'profileId': profileId,
        'name': name,
        'type': type,
        'lastSeenAt': lastSeenAt.toIso8601String(),
        'online': online,
      };

  @override
  String toString() {
    return 'MediaDevice('
        'id: $id, '
        'profileId: $profileId, '
        'name: $name, '
        'type: $type, '
        'online: $online'
        ')';
  }
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

  /// Whether this session has enough identity information to be persisted.
  bool get isValid =>
      id.trim().isNotEmpty &&
      profileId.trim().isNotEmpty &&
      deviceId.trim().isNotEmpty;

  /// Normalized playback position. Negative positions are never meaningful.
  double get normalizedPositionSeconds {
    if (positionSeconds.isNaN || positionSeconds.isNegative) {
      return 0;
    }

    if (positionSeconds.isInfinite) {
      return 0;
    }

    return positionSeconds;
  }

  /// True when the session currently represents active playback.
  bool get isPlaying => state.toLowerCase().trim() == 'playing';

  /// True when the session is paused.
  bool get isPaused => state.toLowerCase().trim() == 'paused';

  /// True when the session is stopped.
  bool get isStopped => state.toLowerCase().trim() == 'stopped';

  /// True when the session is idle.
  bool get isIdle => state.toLowerCase().trim() == 'idle';

  /// True when a media item is currently associated with the session.
  bool get hasMedia => mediaId?.trim().isNotEmpty == true;

  /// Creates a modified copy without changing the original session.
  PlaybackSession copyWith({
    String? id,
    String? profileId,
    String? deviceId,
    String? mediaId,
    String? state,
    double? positionSeconds,
    DateTime? startedAt,
    DateTime? lastActivityAt,
    bool clearMediaId = false,
  }) {
    return PlaybackSession(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      deviceId: deviceId ?? this.deviceId,
      mediaId: clearMediaId ? null : (mediaId ?? this.mediaId),
      state: state ?? this.state,
      positionSeconds: positionSeconds ?? this.positionSeconds,
      startedAt: startedAt ?? this.startedAt,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
    );
  }

  factory PlaybackSession.fromJson(Map<String, dynamic> json) {
    return PlaybackSession(
      id: _stringValue(json['id']),
      profileId: _stringValue(json['profileId']),
      deviceId: _stringValue(json['deviceId']),
      mediaId: _nullableString(json['mediaId']),
      state: _stringValue(
        json['state'],
        fallback: 'idle',
      ),
      positionSeconds: _doubleValue(
        json['positionSeconds'],
        fallback: 0,
      ),
      startedAt: _dateTimeValue(
        json['startedAt'],
        fallback: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      ),
      lastActivityAt: _dateTimeValue(
        json['lastActivityAt'],
        fallback: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      ),
    );
  }

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

  @override
  String toString() {
    return 'PlaybackSession('
        'id: $id, '
        'profileId: $profileId, '
        'deviceId: $deviceId, '
        'mediaId: $mediaId, '
        'state: $state, '
        'positionSeconds: $positionSeconds'
        ')';
  }
}

String _stringValue(
  Object? value, {
  String fallback = '',
}) {
  if (value == null) {
    return fallback;
  }

  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

String? _nullableString(Object? value) {
  if (value == null) {
    return null;
  }

  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

bool _boolValue(
  Object? value, {
  bool fallback = false,
}) {
  if (value is bool) {
    return value;
  }

  if (value is num) {
    return value != 0;
  }

  if (value is String) {
    switch (value.trim().toLowerCase()) {
      case 'true':
      case '1':
      case 'yes':
      case 'on':
        return true;
      case 'false':
      case '0':
      case 'no':
      case 'off':
        return false;
    }
  }

  return fallback;
}

double _doubleValue(
  Object? value, {
  double fallback = 0,
}) {
  if (value is num) {
    return value.toDouble();
  }

  if (value is String) {
    return double.tryParse(value.trim()) ?? fallback;
  }

  return fallback;
}

DateTime _dateTimeValue(
  Object? value, {
  required DateTime fallback,
}) {
  if (value is DateTime) {
    return value;
  }

  if (value is String) {
    return DateTime.tryParse(value.trim()) ?? fallback;
  }

  if (value is num) {
    final milliseconds = value.toInt();

    // Persisted timestamps in this project are normally ISO-8601 strings.
    // Numeric timestamps are accepted as milliseconds for interoperability.
    try {
      return DateTime.fromMillisecondsSinceEpoch(
        milliseconds,
        isUtc: true,
      );
    } catch (_) {
      return fallback;
    }
  }

  return fallback;
}