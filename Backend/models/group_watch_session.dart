// FILE: `Backend/models/group_watch_session.dart`.
// Purpose: Implements the group watch session portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.
//
// Group Watch supports profiles from different accounts. The session's
// accountId identifies the host account; each participant independently
// carries the accountId that owns that participant profile.

enum GroupWatchSessionStatus {
  waiting,
  ready,
  playing,
  paused,
  ended,
}

enum GroupWatchInvitationStatus {
  pending,
  accepted,
  declined,
  expired,
}

class GroupWatchParticipant {
  /// The account that owns this profile.
  final String accountId;

  /// The profile participating in the Group Watch.
  final String profileId;

  GroupWatchInvitationStatus invitationStatus;

  String? audioTrackId;
  String? subtitleTrackId;

  DateTime? joinedAt;

  GroupWatchParticipant({
    required this.accountId,
    required this.profileId,
    this.invitationStatus = GroupWatchInvitationStatus.pending,
    this.audioTrackId,
    this.subtitleTrackId,
    this.joinedAt,
  });

  bool get hasAccepted =>
      invitationStatus == GroupWatchInvitationStatus.accepted;

  bool get canJoin => hasAccepted;

  bool get isPending =>
      invitationStatus == GroupWatchInvitationStatus.pending;

  bool get isDeclined =>
      invitationStatus == GroupWatchInvitationStatus.declined;

  bool get isExpired =>
      invitationStatus == GroupWatchInvitationStatus.expired;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'accountId': accountId,
      'profileId': profileId,
      'invitationStatus': invitationStatus.name,
      'audioTrackId': audioTrackId,
      'subtitleTrackId': subtitleTrackId,
      'joinedAt': joinedAt?.toIso8601String(),
    };
  }

  factory GroupWatchParticipant.fromJson(
    Map<String, dynamic> json,
  ) {
    final String invitationStatus =
        json['invitationStatus']?.toString() ??
            GroupWatchInvitationStatus.pending.name;

    final String? joinedAtString =
        json['joinedAt']?.toString();

    return GroupWatchParticipant(
      accountId: json['accountId']?.toString() ?? '',
      profileId: json['profileId']?.toString() ?? '',
      invitationStatus:
          GroupWatchInvitationStatus.values.firstWhere(
        (status) => status.name == invitationStatus,
        orElse: () =>
            GroupWatchInvitationStatus.pending,
      ),
      audioTrackId: _nullableString(json['audioTrackId']),
      subtitleTrackId: _nullableString(
        json['subtitleTrackId'],
      ),
      joinedAt: joinedAtString != null
          ? DateTime.tryParse(joinedAtString)
          : null,
    );
  }

  static String? _nullableString(dynamic value) {
    if (value == null) {
      return null;
    }

    final String valueString = value.toString().trim();

    return valueString.isEmpty ? null : valueString;
  }
}

class GroupWatchSession {
  final String id;

  /// The account that created/owns the Group Watch session.
  ///
  /// This is the host account. Participants do not have to belong
  /// to this account.
  final String accountId;

  /// The profile that created/hosts the Group Watch.
  final String hostProfileId;

  /// The media being watched.
  final String mediaId;
  final String title;
  final String type;

  final DateTime createdAt;

  /// Invitations can only be accepted before the session starts.
  DateTime invitationExpiresAt;

  /// When playback actually begins.
  DateTime? startedAt;

  /// When the session ended.
  DateTime? endedAt;

  GroupWatchSessionStatus status;

  /// Current global playback position.
  ///
  /// This is shared by everyone in the Group Watch.
  Duration playbackPosition;

  /// Whether playback should currently be playing.
  bool isPlaying;

  /// The profile that currently has the session paused.
  String? pausedByProfileId;

  /// The reason selected by the person who paused.
  String? pauseReason;

  /// All invited/accepted participants.
  ///
  /// The key is the profile ID.
  ///
  /// Participants may belong to different accounts.
  final Map<String, GroupWatchParticipant> participants;

  GroupWatchSession({
    required this.id,
    required this.accountId,
    required this.hostProfileId,
    required this.mediaId,
    required this.title,
    required this.type,
    required this.createdAt,
    required this.invitationExpiresAt,
    this.startedAt,
    this.endedAt,
    this.status = GroupWatchSessionStatus.waiting,
    this.playbackPosition = Duration.zero,
    this.isPlaying = false,
    this.pausedByProfileId,
    this.pauseReason,
    Map<String, GroupWatchParticipant>? participants,
  }) : participants =
            participants ??
                <String, GroupWatchParticipant>{};

  // ---------------------------------------------------------------------------
  // SESSION STATE
  // ---------------------------------------------------------------------------

  bool get hasStarted => startedAt != null;

  bool get hasEnded =>
      status == GroupWatchSessionStatus.ended ||
      endedAt != null;

  bool get isWaiting =>
      status == GroupWatchSessionStatus.waiting;

  bool get isReady =>
      status == GroupWatchSessionStatus.ready;

  bool get isPaused =>
      status == GroupWatchSessionStatus.paused;

  bool get isPlayingNow =>
      status == GroupWatchSessionStatus.playing &&
      isPlaying;

  // ---------------------------------------------------------------------------
  // PARTICIPANTS
  // ---------------------------------------------------------------------------

  GroupWatchParticipant? participantFor(
    String profileId,
  ) {
    return participants[profileId];
  }

  bool hasParticipant(
    String profileId,
  ) {
    return participants.containsKey(profileId);
  }

  bool hasAccepted(
    String profileId,
  ) {
    return participants[profileId]?.hasAccepted ?? false;
  }

  /// Returns all accepted profile IDs.
  List<String> get acceptedParticipantIds {
    return participants.values
        .where(
          (participant) => participant.hasAccepted,
        )
        .map(
          (participant) => participant.profileId,
        )
        .toList();
  }

  /// Returns all accepted participants.
  List<GroupWatchParticipant> get acceptedParticipants {
    return participants.values
        .where(
          (participant) => participant.hasAccepted,
        )
        .toList();
  }

  List<GroupWatchParticipant> get pendingParticipants {
    return participants.values
        .where(
          (participant) =>
              participant.invitationStatus ==
              GroupWatchInvitationStatus.pending,
        )
        .toList();
  }

  int get acceptedParticipantCount {
    return acceptedParticipantIds.length;
  }

  int get participantCount => participants.length;

  String? accountIdForProfile(
    String profileId,
  ) {
    return participants[profileId]?.accountId;
  }

  /// Returns whether the supplied profile belongs to
  /// the supplied account within this session.
  bool profileBelongsToAccount({
    required String profileId,
    required String accountId,
  }) {
    return participants[profileId]?.accountId == accountId;
  }

  /// Adds or replaces an invitation.
  ///
  /// A profile ID is the unique participant key within a session.
  /// The account ID is retained separately so cross-account sessions
  /// remain supported.
  bool addParticipant(
    GroupWatchParticipant participant,
  ) {
    final String cleanProfileId =
        participant.profileId.trim();

    final String cleanAccountId =
        participant.accountId.trim();

    if (cleanProfileId.isEmpty ||
        cleanAccountId.isEmpty) {
      return false;
    }

    if (hasStarted || hasEnded) {
      return false;
    }

    participants[cleanProfileId] = participant;

    return true;
  }

  bool removeParticipant(
    String profileId,
  ) {
    final String cleanProfileId = profileId.trim();

    if (cleanProfileId.isEmpty) {
      return false;
    }

    if (hasStarted || hasEnded) {
      return false;
    }

    return participants.remove(cleanProfileId) != null;
  }

  // ---------------------------------------------------------------------------
  // INVITATIONS
  // ---------------------------------------------------------------------------

  bool get areInvitationsOpen {
    if (hasStarted || hasEnded) {
      return false;
    }

    return DateTime.now().isBefore(
      invitationExpiresAt,
    );
  }

  bool get invitationsHaveExpired {
    if (hasStarted || hasEnded) {
      return false;
    }

    return !areInvitationsOpen;
  }

  bool canAcceptInvitation(
    String profileId,
  ) {
    final GroupWatchParticipant? participant =
        participants[profileId];

    if (participant == null) {
      return false;
    }

    if (hasStarted || hasEnded) {
      return false;
    }

    if (!DateTime.now().isBefore(
      invitationExpiresAt,
    )) {
      return false;
    }

    return participant.invitationStatus ==
        GroupWatchInvitationStatus.pending;
  }

  bool acceptInvitation(
    String profileId,
  ) {
    if (!canAcceptInvitation(profileId)) {
      return false;
    }

    final GroupWatchParticipant participant =
        participants[profileId]!;

    participant.invitationStatus =
        GroupWatchInvitationStatus.accepted;

    participant.joinedAt ??= DateTime.now();

    return true;
  }

  bool declineInvitation(
    String profileId,
  ) {
    final GroupWatchParticipant? participant =
        participants[profileId];

    if (participant == null) {
      return false;
    }

    if (hasStarted || hasEnded) {
      return false;
    }

    if (participant.invitationStatus !=
        GroupWatchInvitationStatus.pending) {
      return false;
    }

    participant.invitationStatus =
        GroupWatchInvitationStatus.declined;

    return true;
  }

  void expirePendingInvitations() {
    for (final GroupWatchParticipant participant
        in participants.values) {
      if (participant.invitationStatus ==
          GroupWatchInvitationStatus.pending) {
        participant.invitationStatus =
            GroupWatchInvitationStatus.expired;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // AUDIO / SUBTITLES
  // ---------------------------------------------------------------------------

  bool setAudioTrack(
    String profileId,
    String? audioTrackId,
  ) {
    final GroupWatchParticipant? participant =
        participants[profileId];

    if (participant == null ||
        !participant.hasAccepted ||
        hasStarted ||
        hasEnded) {
      return false;
    }

    participant.audioTrackId =
        _cleanNullableId(audioTrackId);

    return true;
  }

  bool setSubtitleTrack(
    String profileId,
    String? subtitleTrackId,
  ) {
    final GroupWatchParticipant? participant =
        participants[profileId];

    if (participant == null ||
        !participant.hasAccepted ||
        hasStarted ||
        hasEnded) {
      return false;
    }

    participant.subtitleTrackId =
        _cleanNullableId(subtitleTrackId);

    return true;
  }

  // ---------------------------------------------------------------------------
  // START
  // ---------------------------------------------------------------------------

  bool get canStart {
    if (hasEnded || hasStarted) {
      return false;
    }

    return acceptedParticipantCount > 0;
  }

  bool start() {
    if (!canStart) {
      return false;
    }

    final DateTime now = DateTime.now();

    startedAt = now;
    status = GroupWatchSessionStatus.playing;
    isPlaying = true;
    playbackPosition = Duration.zero;

    // Once playback starts, nobody who had not accepted
    // can join this Group Watch.
    expirePendingInvitations();

    return true;
  }

  // ---------------------------------------------------------------------------
  // PLAYBACK
  // ---------------------------------------------------------------------------

  bool play() {
    if (hasEnded || !hasStarted) {
      return false;
    }

    status = GroupWatchSessionStatus.playing;
    isPlaying = true;

    pausedByProfileId = null;
    pauseReason = null;

    return true;
  }

  /// Pauses the Group Watch for everyone.
  ///
  /// Only the profile that performs the pause becomes responsible
  /// for pressing Resume.
  bool pause({
    required String profileId,
    required String reason,
  }) {
    if (hasEnded ||
        !hasStarted ||
        !hasAccepted(profileId) ||
        !isPlaying) {
      return false;
    }

    final String cleanReason = reason.trim();

    if (cleanReason.isEmpty) {
      return false;
    }

    status = GroupWatchSessionStatus.paused;
    isPlaying = false;

    pausedByProfileId = profileId;
    pauseReason = cleanReason;

    return true;
  }

  /// Only the person who paused the Group Watch
  /// can resume it.
  bool resume(
    String profileId,
  ) {
    if (hasEnded ||
        status != GroupWatchSessionStatus.paused) {
      return false;
    }

    if (pausedByProfileId != profileId) {
      return false;
    }

    if (!hasAccepted(profileId)) {
      return false;
    }

    status = GroupWatchSessionStatus.playing;
    isPlaying = true;

    pausedByProfileId = null;
    pauseReason = null;

    return true;
  }

  /// Updates the global playback position.
  ///
  /// The backend can use this when a participant reports
  /// the current playback position.
  bool updatePlaybackPosition({
    required String profileId,
    required Duration position,
  }) {
    if (hasEnded ||
        !hasStarted ||
        !hasAccepted(profileId)) {
      return false;
    }

    if (position.isNegative) {
      return false;
    }

    playbackPosition = position;

    return true;
  }

  // ---------------------------------------------------------------------------
  // END
  // ---------------------------------------------------------------------------

  void end() {
    if (hasEnded) {
      return;
    }

    status = GroupWatchSessionStatus.ended;
    isPlaying = false;
    endedAt = DateTime.now();

    pausedByProfileId = null;
    pauseReason = null;
  }

  // ---------------------------------------------------------------------------
  // JSON
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,

      // Host account. Participant account IDs are stored inside
      // the participant records.
      'accountId': accountId,

      'hostProfileId': hostProfileId,
      'mediaId': mediaId,
      'title': title,
      'type': type,

      'createdAt': createdAt.toIso8601String(),

      'invitationExpiresAt':
          invitationExpiresAt.toIso8601String(),

      'startedAt':
          startedAt?.toIso8601String(),

      'endedAt':
          endedAt?.toIso8601String(),

      'status': status.name,

      'playbackPositionMs':
          playbackPosition.inMilliseconds,

      'isPlaying': isPlaying,

      'pausedByProfileId':
          pausedByProfileId,

      'pauseReason':
          pauseReason,

      'participants': participants.map(
        (
          profileId,
          participant,
        ) =>
            MapEntry(
          profileId,
          participant.toJson(),
        ),
      ),
    };
  }

  factory GroupWatchSession.fromJson(
    Map<String, dynamic> json,
  ) {
    final dynamic rawParticipants =
        json['participants'];

    final Map<String, dynamic> participantsJson =
        rawParticipants is Map
            ? rawParticipants.map(
                (
                  key,
                  value,
                ) =>
                    MapEntry(
                  key.toString(),
                  value,
                ),
              )
            : <String, dynamic>{};

    final String statusString =
        json['status']?.toString() ??
            GroupWatchSessionStatus.waiting.name;

    final String sessionAccountId =
        json['accountId']?.toString() ?? '';

    final DateTime createdAt =
        _parseDateTime(
      json['createdAt'],
      fallback: DateTime.now(),
    );

    final DateTime invitationExpiresAt =
        _parseDateTime(
      json['invitationExpiresAt'],
      fallback: createdAt,
    );

    final dynamic rawPlaybackPositionMs =
        json['playbackPositionMs'];

    final int playbackPositionMs =
        _parseInt(rawPlaybackPositionMs);

    return GroupWatchSession(
      id: json['id']?.toString() ?? '',
      accountId: sessionAccountId,
      hostProfileId:
          json['hostProfileId']?.toString() ?? '',
      mediaId:
          json['mediaId']?.toString() ?? '',
      title:
          json['title']?.toString() ?? '',
      type:
          json['type']?.toString() ?? '',
      createdAt: createdAt,
      invitationExpiresAt:
          invitationExpiresAt,
      startedAt:
          _parseNullableDateTime(
        json['startedAt'],
      ),
      endedAt:
          _parseNullableDateTime(
        json['endedAt'],
      ),
      status:
          GroupWatchSessionStatus.values.firstWhere(
        (status) => status.name == statusString,
        orElse: () =>
            GroupWatchSessionStatus.waiting,
      ),
      playbackPosition:
          Duration(
        milliseconds: playbackPositionMs,
      ),
      isPlaying:
          json['isPlaying'] as bool? ?? false,
      pausedByProfileId:
          _nullableString(
        json['pausedByProfileId'],
      ),
      pauseReason:
          _nullableString(
        json['pauseReason'],
      ),
      participants:
          participantsJson.map(
        (
          profileId,
          value,
        ) {
          final Map<String, dynamic>
              participantJson =
              value is Map
                  ? Map<String, dynamic>.from(
                      value,
                    )
                  : <String, dynamic>{
                      'profileId':
                          profileId,
                    };

          participantJson['profileId'] ??=
              profileId;

          // Older sessions did not store the participant's
          // account ID. Keep those sessions readable rather
          // than crashing. This fallback is the host account
          // because that is the only account identity older
          // session records are guaranteed to contain.
          participantJson['accountId'] ??=
              sessionAccountId;

          return MapEntry(
            profileId,
            GroupWatchParticipant.fromJson(
              participantJson,
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PARSING HELPERS
  // ---------------------------------------------------------------------------

  static DateTime _parseDateTime(
    dynamic value, {
    required DateTime fallback,
  }) {
    if (value is DateTime) {
      return value;
    }

    final String? valueString =
        _nullableString(value);

    if (valueString == null) {
      return fallback;
    }

    return DateTime.tryParse(valueString) ??
        fallback;
  }

  static DateTime? _parseNullableDateTime(
    dynamic value,
  ) {
    if (value is DateTime) {
      return value;
    }

    final String? valueString =
        _nullableString(value);

    if (valueString == null) {
      return null;
    }

    return DateTime.tryParse(valueString);
  }

  static int _parseInt(
    dynamic value,
  ) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  static String? _nullableString(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    final String valueString =
        value.toString().trim();

    return valueString.isEmpty
        ? null
        : valueString;
  }

  static String? _cleanNullableId(
    String? value,
  ) {
    if (value == null) {
      return null;
    }

    final String cleanValue = value.trim();

    return cleanValue.isEmpty
        ? null
        : cleanValue;
  }
}