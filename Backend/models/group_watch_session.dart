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
  final String profileId;

  GroupWatchInvitationStatus invitationStatus;

  String? audioTrackId;
  String? subtitleTrackId;

  DateTime? joinedAt;

  GroupWatchParticipant({
    required this.profileId,
    this.invitationStatus = GroupWatchInvitationStatus.pending,
    this.audioTrackId,
    this.subtitleTrackId,
    this.joinedAt,
  });

  bool get hasAccepted =>
      invitationStatus == GroupWatchInvitationStatus.accepted;

  bool get canJoin =>
      invitationStatus == GroupWatchInvitationStatus.accepted;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
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
        json['invitationStatus'] as String? ??
            GroupWatchInvitationStatus.pending.name;

    final String? joinedAtString =
        json['joinedAt'] as String?;

    return GroupWatchParticipant(
      profileId: json['profileId'] as String,
      invitationStatus:
          GroupWatchInvitationStatus.values.firstWhere(
        (status) => status.name == invitationStatus,
        orElse: () =>
            GroupWatchInvitationStatus.pending,
      ),
      audioTrackId: json['audioTrackId'] as String?,
      subtitleTrackId:
          json['subtitleTrackId'] as String?,
      joinedAt: joinedAtString != null
          ? DateTime.parse(joinedAtString)
          : null,
    );
  }
}

class GroupWatchSession {
  final String id;
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
  // PARTICIPANTS
  // ---------------------------------------------------------------------------

  GroupWatchParticipant? participantFor(
    String profileId,
  ) {
    return participants[profileId];
  }

  bool hasParticipant(String profileId) {
    return participants.containsKey(profileId);
  }

  bool hasAccepted(String profileId) {
    return participants[profileId]?.hasAccepted ?? false;
  }

  List<String> get acceptedParticipantIds {
    return participants.values
        .where((participant) => participant.hasAccepted)
        .map((participant) => participant.profileId)
        .toList();
  }

  int get acceptedParticipantCount {
    return acceptedParticipantIds.length;
  }

  bool get hasStarted {
    return startedAt != null;
  }

  // ---------------------------------------------------------------------------
  // INVITATIONS
  // ---------------------------------------------------------------------------

  bool get areInvitationsOpen {
    if (hasStarted) return false;
    if (status == GroupWatchSessionStatus.ended) {
      return false;
    }

    return DateTime.now().isBefore(invitationExpiresAt);
  }

  bool get invitationsHaveExpired {
    return !areInvitationsOpen;
  }

  bool canAcceptInvitation(String profileId) {
    final GroupWatchParticipant? participant =
        participants[profileId];

    if (participant == null) return false;

    if (hasStarted) return false;

    if (status == GroupWatchSessionStatus.ended) {
      return false;
    }

    if (DateTime.now().isAfter(invitationExpiresAt) ||
        DateTime.now().isAtSameMomentAs(
          invitationExpiresAt,
        )) {
      return false;
    }

    return participant.invitationStatus ==
        GroupWatchInvitationStatus.pending;
  }

  bool acceptInvitation(String profileId) {
    if (!canAcceptInvitation(profileId)) {
      return false;
    }

    final GroupWatchParticipant participant =
        participants[profileId]!;

    participant.invitationStatus =
        GroupWatchInvitationStatus.accepted;
    participant.joinedAt = DateTime.now();

    return true;
  }

  bool declineInvitation(String profileId) {
    final GroupWatchParticipant? participant =
        participants[profileId];

    if (participant == null) return false;

    if (hasStarted) return false;

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

    if (participant == null) return false;

    if (!participant.hasAccepted) {
      return false;
    }

    if (hasStarted) {
      return false;
    }

    participant.audioTrackId = audioTrackId;

    return true;
  }

  bool setSubtitleTrack(
    String profileId,
    String? subtitleTrackId,
  ) {
    final GroupWatchParticipant? participant =
        participants[profileId];

    if (participant == null) return false;

    if (!participant.hasAccepted) {
      return false;
    }

    if (hasStarted) {
      return false;
    }

    participant.subtitleTrackId = subtitleTrackId;

    return true;
  }

  // ---------------------------------------------------------------------------
  // START
  // ---------------------------------------------------------------------------

  bool get canStart {
    if (status == GroupWatchSessionStatus.ended) {
      return false;
    }

    if (hasStarted) return false;

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
    if (status == GroupWatchSessionStatus.ended) {
      return false;
    }

    if (!hasStarted) {
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
    if (status == GroupWatchSessionStatus.ended) {
      return false;
    }

    if (!hasStarted) {
      return false;
    }

    if (!hasAccepted(profileId)) {
      return false;
    }

    if (!isPlaying) {
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

  /// Only the person who paused the Group Watch can resume it.
  bool resume(String profileId) {
    if (status == GroupWatchSessionStatus.ended) {
      return false;
    }

    if (status != GroupWatchSessionStatus.paused) {
      return false;
    }

    if (pausedByProfileId != profileId) {
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
  /// The backend can use this when a participant reports the
  /// current playback position.
  bool updatePlaybackPosition({
    required String profileId,
    required Duration position,
  }) {
    if (status == GroupWatchSessionStatus.ended) {
      return false;
    }

    if (!hasStarted) {
      return false;
    }

    if (!hasAccepted(profileId)) {
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
      'accountId': accountId,
      'hostProfileId': hostProfileId,
      'mediaId': mediaId,
      'title': title,
      'type': type,
      'createdAt': createdAt.toIso8601String(),
      'invitationExpiresAt':
          invitationExpiresAt.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'status': status.name,
      'playbackPositionMs':
          playbackPosition.inMilliseconds,
      'isPlaying': isPlaying,
      'pausedByProfileId': pausedByProfileId,
      'pauseReason': pauseReason,
      'participants': participants.map(
        (profileId, participant) =>
            MapEntry(profileId, participant.toJson()),
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
                (key, value) =>
                    MapEntry(key.toString(), value),
              )
            : <String, dynamic>{};

    final String statusString =
        json['status'] as String? ??
            GroupWatchSessionStatus.waiting.name;

    final String createdAtString =
        json['createdAt'] as String;

    final String invitationExpiresAtString =
        json['invitationExpiresAt'] as String;

    final dynamic rawPlaybackPositionMs =
        json['playbackPositionMs'];

    final int playbackPositionMs =
        rawPlaybackPositionMs is int
            ? rawPlaybackPositionMs
            : int.tryParse(
                    rawPlaybackPositionMs?.toString() ??
                        '',
                  ) ??
                0;

    return GroupWatchSession(
      id: json['id'] as String,
      accountId: json['accountId'] as String,
      hostProfileId:
          json['hostProfileId'] as String,
      mediaId: json['mediaId'] as String,
      title: json['title'] as String,
      type: json['type'] as String,
      createdAt: DateTime.parse(createdAtString),
      invitationExpiresAt:
          DateTime.parse(invitationExpiresAtString),
      startedAt: json['startedAt'] != null
          ? DateTime.parse(
              json['startedAt'] as String,
            )
          : null,
      endedAt: json['endedAt'] != null
          ? DateTime.parse(
              json['endedAt'] as String,
            )
          : null,
      status:
          GroupWatchSessionStatus.values.firstWhere(
        (status) => status.name == statusString,
        orElse: () =>
            GroupWatchSessionStatus.waiting,
      ),
      playbackPosition:
          Duration(milliseconds: playbackPositionMs),
      isPlaying:
          json['isPlaying'] as bool? ?? false,
      pausedByProfileId:
          json['pausedByProfileId'] as String?,
      pauseReason:
          json['pauseReason'] as String?,
      participants:
          participantsJson.map((profileId, value) {
        final Map<String, dynamic> participantJson =
            value is Map
                ? Map<String, dynamic>.from(value)
                : <String, dynamic>{
                    'profileId': profileId,
                  };

        participantJson['profileId'] ??= profileId;

        return MapEntry(
          profileId,
          GroupWatchParticipant.fromJson(
            participantJson,
          ),
        );
      }),
    );
  }
}