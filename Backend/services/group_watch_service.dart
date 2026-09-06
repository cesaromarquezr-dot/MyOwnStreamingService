import 'dart:math';

import '../database/database.dart';
import '../models/group_watch_session.dart';

class GroupWatchService {
  final Database database;

  GroupWatchService({
    required this.database,
  });

  // ---------------------------------------------------------------------------
  // SESSION CREATION
  // ---------------------------------------------------------------------------

  GroupWatchSession createSession({
    required String accountId,
    required String hostProfileId,
    required String mediaId,
    required String title,
    required String type,
    required Set<String> invitedProfileIds,
    Duration invitationDuration = const Duration(hours: 24),
  }) {
    final String cleanAccountId = accountId.trim();
    final String cleanHostProfileId = hostProfileId.trim();
    final String cleanMediaId = mediaId.trim();
    final String cleanTitle = title.trim();
    final String cleanType = type.trim();

    if (cleanAccountId.isEmpty) {
      throw ArgumentError('Account ID is required.');
    }

    if (cleanHostProfileId.isEmpty) {
      throw ArgumentError('Host profile ID is required.');
    }

    if (cleanMediaId.isEmpty) {
      throw ArgumentError('Media ID is required.');
    }

    if (cleanTitle.isEmpty) {
      throw ArgumentError('Title is required.');
    }

    if (cleanType != 'movie' && cleanType != 'tvShow') {
      throw ArgumentError(
        'Type must be "movie" or "tvShow".',
      );
    }

    if (invitationDuration <= Duration.zero) {
      throw ArgumentError(
        'Invitation duration must be greater than zero.',
      );
    }

    final Set<String> participants =
        invitedProfileIds
            .map((profileId) => profileId.trim())
            .where((profileId) => profileId.isNotEmpty)
            .toSet();

    // The host must always be part of the session.
    participants.add(cleanHostProfileId);

    final DateTime createdAt = DateTime.now();

    final Map<String, GroupWatchParticipant> participantMap =
        <String, GroupWatchParticipant>{
      for (final String profileId in participants)
        profileId: GroupWatchParticipant(
          profileId: profileId,
        ),
    };

    final GroupWatchSession session = GroupWatchSession(
      id: _generateSessionId(),
      accountId: cleanAccountId,
      hostProfileId: cleanHostProfileId,
      mediaId: cleanMediaId,
      title: cleanTitle,
      type: cleanType,
      createdAt: createdAt,
      invitationExpiresAt:
          createdAt.add(invitationDuration),
      participants: participantMap,
    );

    database.saveGroupWatchSession(session);

    return session;
  }

  // ---------------------------------------------------------------------------
  // GET SESSIONS
  // ---------------------------------------------------------------------------

  GroupWatchSession? getSession(
    String sessionId,
  ) {
    final String cleanSessionId = sessionId.trim();

    if (cleanSessionId.isEmpty) {
      return null;
    }

    final GroupWatchSession? session =
        database.getGroupWatchSession(cleanSessionId);

    if (session == null) {
      return null;
    }

    final bool changed =
        _expireInvitationsIfNecessary(session);

    if (changed) {
      database.saveGroupWatchSession(session);
    }

    return session;
  }

  List<GroupWatchSession> getSessionsForAccount(
    String accountId,
  ) {
    final String cleanAccountId = accountId.trim();

    if (cleanAccountId.isEmpty) {
      return <GroupWatchSession>[];
    }

    final List<GroupWatchSession> sessions =
        database.getGroupWatchSessionsForAccount(
      cleanAccountId,
    );

    for (final GroupWatchSession session in sessions) {
      final bool changed =
          _expireInvitationsIfNecessary(session);

      if (changed) {
        database.saveGroupWatchSession(session);
      }
    }

    sessions.sort(
      (a, b) => b.createdAt.compareTo(a.createdAt),
    );

    return sessions;
  }

  List<GroupWatchSession> getSessionsForProfile(
    String profileId,
  ) {
    final String cleanProfileId = profileId.trim();

    if (cleanProfileId.isEmpty) {
      return <GroupWatchSession>[];
    }

    final List<GroupWatchSession> sessions =
        database.getGroupWatchSessionsForProfile(
      cleanProfileId,
    );

    for (final GroupWatchSession session in sessions) {
      final bool changed =
          _expireInvitationsIfNecessary(session);

      if (changed) {
        database.saveGroupWatchSession(session);
      }
    }

    sessions.sort(
      (a, b) => b.createdAt.compareTo(a.createdAt),
    );

    return sessions;
  }

  // ---------------------------------------------------------------------------
  // INVITATIONS
  // ---------------------------------------------------------------------------

  GroupWatchSession acceptInvitation({
    required String sessionId,
    required String profileId,
  }) {
    final GroupWatchSession session =
        _requireSession(sessionId);

    final String cleanProfileId = profileId.trim();

    if (cleanProfileId.isEmpty) {
      throw ArgumentError('Profile ID is required.');
    }

    _expireAndSaveIfNecessary(session);

    if (session.hasStarted) {
      throw StateError(
        'This invite has expired.',
      );
    }

    if (!session.areInvitationsOpen) {
      throw StateError(
        'This invite has expired.',
      );
    }

    final GroupWatchParticipant? participant =
        session.participantFor(cleanProfileId);

    if (participant == null) {
      throw StateError(
        'This profile was not invited to the Group Watch.',
      );
    }

    if (participant.invitationStatus ==
        GroupWatchInvitationStatus.accepted) {
      return session;
    }

    if (participant.invitationStatus ==
        GroupWatchInvitationStatus.declined) {
      throw StateError(
        'This invitation was already declined.',
      );
    }

    if (participant.invitationStatus ==
        GroupWatchInvitationStatus.expired) {
      throw StateError(
        'This invite has expired.',
      );
    }

    final bool accepted =
        session.acceptInvitation(cleanProfileId);

    if (!accepted) {
      throw StateError(
        'Unable to accept this invitation.',
      );
    }

    database.saveGroupWatchSession(session);

    return session;
  }

  GroupWatchSession declineInvitation({
    required String sessionId,
    required String profileId,
  }) {
    final GroupWatchSession session =
        _requireSession(sessionId);

    final String cleanProfileId = profileId.trim();

    if (cleanProfileId.isEmpty) {
      throw ArgumentError('Profile ID is required.');
    }

    _expireAndSaveIfNecessary(session);

    final GroupWatchParticipant? participant =
        session.participantFor(cleanProfileId);

    if (participant == null) {
      throw StateError(
        'This profile was not invited to the Group Watch.',
      );
    }

    if (session.hasStarted) {
      throw StateError(
        'This invite has expired.',
      );
    }

    if (participant.invitationStatus ==
        GroupWatchInvitationStatus.expired) {
      throw StateError(
        'This invite has expired.',
      );
    }

    if (participant.invitationStatus ==
        GroupWatchInvitationStatus.accepted) {
      throw StateError(
        'This invitation was already accepted.',
      );
    }

    if (participant.invitationStatus ==
        GroupWatchInvitationStatus.declined) {
      return session;
    }

    final bool declined =
        session.declineInvitation(cleanProfileId);

    if (!declined) {
      throw StateError(
        'Unable to decline this invitation.',
      );
    }

    database.saveGroupWatchSession(session);

    return session;
  }

  // ---------------------------------------------------------------------------
  // TRACK SELECTION
  // ---------------------------------------------------------------------------

  GroupWatchSession setAudioTrack({
    required String sessionId,
    required String profileId,
    required String? audioTrackId,
  }) {
    final GroupWatchSession session =
        _requireSession(sessionId);

    final String cleanProfileId = profileId.trim();

    if (cleanProfileId.isEmpty) {
      throw ArgumentError('Profile ID is required.');
    }

    if (session.hasStarted) {
      throw StateError(
        'Audio selection is locked after Group Watch starts.',
      );
    }

    if (!session.hasAccepted(cleanProfileId)) {
      throw StateError(
        'Only accepted participants can select audio.',
      );
    }

    final String? cleanTrackId =
        audioTrackId?.trim();

    final bool updated =
        session.setAudioTrack(
      cleanProfileId,
      cleanTrackId?.isEmpty == true
          ? null
          : cleanTrackId,
    );

    if (!updated) {
      throw StateError(
        'Unable to set the audio track.',
      );
    }

    database.saveGroupWatchSession(session);

    return session;
  }

  GroupWatchSession setSubtitleTrack({
    required String sessionId,
    required String profileId,
    required String? subtitleTrackId,
  }) {
    final GroupWatchSession session =
        _requireSession(sessionId);

    final String cleanProfileId = profileId.trim();

    if (cleanProfileId.isEmpty) {
      throw ArgumentError('Profile ID is required.');
    }

    if (session.hasStarted) {
      throw StateError(
        'Subtitle selection is locked after Group Watch starts.',
      );
    }

    if (!session.hasAccepted(cleanProfileId)) {
      throw StateError(
        'Only accepted participants can select subtitles.',
      );
    }

    final String? cleanTrackId =
        subtitleTrackId?.trim();

    final bool updated =
        session.setSubtitleTrack(
      cleanProfileId,
      cleanTrackId?.isEmpty == true
          ? null
          : cleanTrackId,
    );

    if (!updated) {
      throw StateError(
        'Unable to set the subtitle track.',
      );
    }

    database.saveGroupWatchSession(session);

    return session;
  }

  // ---------------------------------------------------------------------------
  // START GROUP WATCH
  // ---------------------------------------------------------------------------

  GroupWatchSession startSession({
    required String sessionId,
    required String profileId,
  }) {
    final GroupWatchSession session =
        _requireSession(sessionId);

    final String cleanProfileId = profileId.trim();

    if (cleanProfileId.isEmpty) {
      throw ArgumentError('Profile ID is required.');
    }

    if (session.hostProfileId != cleanProfileId) {
      throw StateError(
        'Only the Group Watch host can start playback.',
      );
    }

    if (session.hasStarted) {
      return session;
    }

    _expireAndSaveIfNecessary(session);

    if (!session.areInvitationsOpen) {
      throw StateError(
        'This invite has expired.',
      );
    }

    if (!session.canStart) {
      throw StateError(
        'At least one participant must accept before playback can start.',
      );
    }

    // Actual audio/subtitle availability validation will be
    // connected to media metadata.
    for (final GroupWatchParticipant participant
        in session.participants.values) {
      if (!participant.hasAccepted) {
        continue;
      }

      // A null audio track is allowed when the media has
      // no selectable alternative.
      //
      // A null subtitle track is also allowed.
    }

    final bool started = session.start();

    if (!started) {
      throw StateError(
        'Unable to start the Group Watch.',
      );
    }

    database.saveGroupWatchSession(session);

    return session;
  }

  // ---------------------------------------------------------------------------
  // PLAY
  // ---------------------------------------------------------------------------

  GroupWatchSession play({
    required String sessionId,
    required String profileId,
  }) {
    final GroupWatchSession session =
        _requireSession(sessionId);

    final String cleanProfileId = profileId.trim();

    if (cleanProfileId.isEmpty) {
      throw ArgumentError('Profile ID is required.');
    }

    if (!session.hasStarted) {
      throw StateError(
        'The Group Watch has not started.',
      );
    }

    if (!session.hasAccepted(cleanProfileId)) {
      throw StateError(
        'Only accepted participants can control playback.',
      );
    }

    if (session.status ==
        GroupWatchSessionStatus.ended) {
      throw StateError(
        'The Group Watch has ended.',
      );
    }

    final bool played = session.play();

    if (!played) {
      throw StateError(
        'Unable to resume playback.',
      );
    }

    database.saveGroupWatchSession(session);

    return session;
  }

  // ---------------------------------------------------------------------------
  // PAUSE
  // ---------------------------------------------------------------------------

  GroupWatchSession pause({
    required String sessionId,
    required String profileId,
    required String reason,
  }) {
    final GroupWatchSession session =
        _requireSession(sessionId);

    final String cleanProfileId = profileId.trim();
    final String cleanReason = reason.trim();

    if (cleanProfileId.isEmpty) {
      throw ArgumentError('Profile ID is required.');
    }

    if (cleanReason.isEmpty) {
      throw ArgumentError('Pause reason is required.');
    }

    if (!session.hasStarted) {
      throw StateError(
        'The Group Watch has not started.',
      );
    }

    if (!session.hasAccepted(cleanProfileId)) {
      throw StateError(
        'Only accepted participants can pause playback.',
      );
    }

    if (session.status ==
        GroupWatchSessionStatus.ended) {
      throw StateError(
        'The Group Watch has ended.',
      );
    }

    final bool paused = session.pause(
      profileId: cleanProfileId,
      reason: cleanReason,
    );

    if (!paused) {
      throw StateError(
        'Unable to pause the Group Watch.',
      );
    }

    database.saveGroupWatchSession(session);

    return session;
  }

  // ---------------------------------------------------------------------------
  // RESUME
  // ---------------------------------------------------------------------------

  GroupWatchSession resume({
    required String sessionId,
    required String profileId,
  }) {
    final GroupWatchSession session =
        _requireSession(sessionId);

    final String cleanProfileId = profileId.trim();

    if (cleanProfileId.isEmpty) {
      throw ArgumentError('Profile ID is required.');
    }

    if (session.status !=
        GroupWatchSessionStatus.paused) {
      throw StateError(
        'The Group Watch is not paused.',
      );
    }

    if (session.pausedByProfileId !=
        cleanProfileId) {
      throw StateError(
        'Only the person who paused the Group Watch can resume it.',
      );
    }

    final bool resumed =
        session.resume(cleanProfileId);

    if (!resumed) {
      throw StateError(
        'Unable to resume the Group Watch.',
      );
    }

    database.saveGroupWatchSession(session);

    return session;
  }

  // ---------------------------------------------------------------------------
  // PLAYBACK POSITION
  // ---------------------------------------------------------------------------

  GroupWatchSession updatePlaybackPosition({
    required String sessionId,
    required String profileId,
    required Duration position,
  }) {
    final GroupWatchSession session =
        _requireSession(sessionId);

    final String cleanProfileId = profileId.trim();

    if (cleanProfileId.isEmpty) {
      throw ArgumentError('Profile ID is required.');
    }

    if (position.isNegative) {
      throw ArgumentError(
        'Playback position cannot be negative.',
      );
    }

    if (!session.hasStarted) {
      throw StateError(
        'The Group Watch has not started.',
      );
    }

    if (!session.hasAccepted(cleanProfileId)) {
      throw StateError(
        'Only accepted participants can update playback.',
      );
    }

    if (session.status ==
        GroupWatchSessionStatus.ended) {
      throw StateError(
        'The Group Watch has ended.',
      );
    }

    final bool updated =
        session.updatePlaybackPosition(
      profileId: cleanProfileId,
      position: position,
    );

    if (!updated) {
      throw StateError(
        'Unable to update the playback position.',
      );
    }

    database.saveGroupWatchSession(session);

    return session;
  }

  // ---------------------------------------------------------------------------
  // END SESSION
  // ---------------------------------------------------------------------------

  GroupWatchSession endSession({
    required String sessionId,
    required String profileId,
  }) {
    final GroupWatchSession session =
        _requireSession(sessionId);

    final String cleanProfileId = profileId.trim();

    if (cleanProfileId.isEmpty) {
      throw ArgumentError('Profile ID is required.');
    }

    if (session.hostProfileId != cleanProfileId) {
      throw StateError(
        'Only the Group Watch host can end the session.',
      );
    }

    if (session.status ==
        GroupWatchSessionStatus.ended) {
      return session;
    }

    session.end();

    database.saveGroupWatchSession(session);

    return session;
  }

  // ---------------------------------------------------------------------------
  // DELETE SESSION
  // ---------------------------------------------------------------------------

  bool deleteSession({
    required String sessionId,
    required String profileId,
  }) {
    final GroupWatchSession session =
        _requireSession(sessionId);

    final String cleanProfileId = profileId.trim();

    if (cleanProfileId.isEmpty) {
      throw ArgumentError('Profile ID is required.');
    }

    if (session.hostProfileId != cleanProfileId) {
      throw StateError(
        'Only the Group Watch host can delete the session.',
      );
    }

    database.deleteGroupWatchSession(
  session.id,
);

return true;
  }

  // ---------------------------------------------------------------------------
  // INVITATION EXPIRATION
  // ---------------------------------------------------------------------------

  void expireInvitations({
    required String sessionId,
  }) {
    final GroupWatchSession session =
        _requireSession(sessionId);

    final bool changed =
        _expireInvitationsIfNecessary(session);

    if (changed) {
      database.saveGroupWatchSession(session);
    }
  }

  bool _expireInvitationsIfNecessary(
    GroupWatchSession session,
  ) {
    if (session.hasStarted) {
      final bool hadPendingInvitations =
          session.participants.values.any(
        (participant) =>
            participant.invitationStatus ==
            GroupWatchInvitationStatus.pending,
      );

      if (!hadPendingInvitations) {
        return false;
      }

      session.expirePendingInvitations();
      return true;
    }

    final DateTime now = DateTime.now();

    if (now.isBefore(session.invitationExpiresAt)) {
      return false;
    }

    final bool hadPendingInvitations =
        session.participants.values.any(
      (participant) =>
          participant.invitationStatus ==
          GroupWatchInvitationStatus.pending,
    );

    if (!hadPendingInvitations) {
      return false;
    }

    session.expirePendingInvitations();
    return true;
  }

  void _expireAndSaveIfNecessary(
    GroupWatchSession session,
  ) {
    final bool changed =
        _expireInvitationsIfNecessary(session);

    if (changed) {
      database.saveGroupWatchSession(session);
    }
  }

  // ---------------------------------------------------------------------------
  // INTERNAL HELPERS
  // ---------------------------------------------------------------------------

  GroupWatchSession _requireSession(
    String sessionId,
  ) {
    final String cleanSessionId = sessionId.trim();

    if (cleanSessionId.isEmpty) {
      throw ArgumentError(
        'Session ID is required.',
      );
    }

    final GroupWatchSession? session =
        database.getGroupWatchSession(
      cleanSessionId,
    );

    if (session == null) {
      throw StateError(
        'Group Watch session not found.',
      );
    }

    return session;
  }

  String _generateSessionId() {
    final Random random = Random();

    String id;

    do {
      id =
          '${DateTime.now().microsecondsSinceEpoch}'
          '-${random.nextInt(1000000)}';
    } while (database.getGroupWatchSession(id) != null);

    return id;
  }
}