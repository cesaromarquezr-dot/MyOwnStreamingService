// FILE: Backend/services/group_watch_service.dart.
//
// Purpose: Implements the group watch service portion of the streaming
// service.
//
// This service owns Group Watch business rules. It validates account/profile
// ownership, media ownership, invitations, participant state, playback
// control, and session lifecycle.
//
// Group Watch is account-aware but may include profiles belonging to different
// accounts. A participant may join only when that participant's profile still
// has access to the selected media.

import 'dart:math';

import '../database/database.dart';
import '../models/account.dart';
import '../models/group_watch_session.dart';
import '../models/media.dart';

class GroupWatchService {
  final Database database;
  final Random _random = Random.secure();

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
    final cleanAccountId = accountId.trim();
    final cleanHostProfileId = hostProfileId.trim();
    final cleanMediaId = mediaId.trim();
    final cleanTitle = title.trim();
    final cleanType = type.trim();

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

    if (cleanTitle.length > 500) {
      throw ArgumentError(
        'Title cannot exceed 500 characters.',
      );
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

    if (invitationDuration > const Duration(days: 7)) {
      throw ArgumentError(
        'Invitation duration cannot exceed 7 days.',
      );
    }

    final hostAccount = database.getAccountById(
      cleanAccountId,
    );

    if (hostAccount == null) {
      throw StateError(
        'The host account was not found.',
      );
    }

    if (!hostAccount.hasProfile(cleanHostProfileId)) {
      throw StateError(
        'The host profile does not belong to the authenticated account.',
      );
    }

    final media = database.getMediaById(cleanMediaId);

    if (media == null) {
      throw StateError(
        'The selected media was not found.',
      );
    }

    if (!_accountOwnsMedia(
      hostAccount,
      cleanMediaId,
      cleanHostProfileId,
    )) {
      throw StateError(
        'The host profile does not have access to the selected media.',
      );
    }

    final participants = invitedProfileIds
        .map((profileId) => profileId.trim())
        .where((profileId) => profileId.isNotEmpty)
        .toSet();

    participants.add(cleanHostProfileId);

    final participantMap =
        <String, GroupWatchParticipant>{};

    for (final profileId in participants) {
      final participantAccount =
          database.getAccountForProfile(profileId);

      if (participantAccount == null) {
        throw StateError(
          'The profile "$profileId" was not found.',
        );
      }

      if (!_accountOwnsMedia(
        participantAccount,
        cleanMediaId,
        profileId,
      )) {
        throw StateError(
          'The selected profile does not own this media.',
        );
      }

      participantMap[profileId] =
          GroupWatchParticipant(
        accountId: participantAccount.id,
        profileId: profileId,
      );
    }

    // The host is always represented by the authenticated account.
    participantMap[cleanHostProfileId] =
        GroupWatchParticipant(
      accountId: cleanAccountId,
      profileId: cleanHostProfileId,
    );

    final createdAt = DateTime.now();

    final session = GroupWatchSession(
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

  GroupWatchSession? getSession(String sessionId) {
    final cleanSessionId = sessionId.trim();

    if (cleanSessionId.isEmpty) {
      return null;
    }

    final session =
        database.getGroupWatchSessionById(
      cleanSessionId,
    );

    if (session == null) {
      return null;
    }

    _expireAndSaveIfNecessary(session);

    return session;
  }

  List<GroupWatchSession> getSessionsForAccount(
    String accountId,
  ) {
    final cleanAccountId = accountId.trim();

    if (cleanAccountId.isEmpty) {
      return <GroupWatchSession>[];
    }

    final sessions =
        database.getGroupWatchSessionsForAccount(
      cleanAccountId,
    );

    for (final session in sessions) {
      _expireAndSaveIfNecessary(session);
    }

    sessions.sort(
      (a, b) => b.createdAt.compareTo(a.createdAt),
    );

    return sessions;
  }

  List<GroupWatchSession> getSessionsForProfile(
    String profileId,
  ) {
    final cleanProfileId = profileId.trim();

    if (cleanProfileId.isEmpty) {
      return <GroupWatchSession>[];
    }

    final sessions =
        database.getGroupWatchSessionsForProfile(
      cleanProfileId,
    );

    for (final session in sessions) {
      _expireAndSaveIfNecessary(session);
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
    final session = _requireSession(sessionId);
    final cleanProfileId = profileId.trim();

    if (cleanProfileId.isEmpty) {
      throw ArgumentError('Profile ID is required.');
    }

    _expireAndSaveIfNecessary(session);

    if (session.hasStarted) {
      throw StateError(
        'This invitation link is expired.',
      );
    }

    if (!session.areInvitationsOpen) {
      throw StateError(
        'This invitation link is expired.',
      );
    }

    final participant =
        session.participantFor(cleanProfileId);

    if (participant == null) {
      throw StateError(
        'This profile was not invited to the Group Watch.',
      );
    }

    final participantAccount =
        database.getAccountForProfile(cleanProfileId);

    if (participantAccount == null) {
      throw StateError(
        'This profile is no longer available.',
      );
    }

    if (!_accountOwnsMedia(
      participantAccount,
      session.mediaId,
      cleanProfileId,
    )) {
      throw StateError(
        'You no longer own this media, so you cannot join this Group Watch.',
      );
    }

    if (participant.accountId != participantAccount.id) {
      throw StateError(
        'This invitation is no longer valid for this profile.',
      );
    }

    switch (participant.invitationStatus) {
      case GroupWatchInvitationStatus.accepted:
        return session;

      case GroupWatchInvitationStatus.declined:
        throw StateError(
          'This invitation was already declined.',
        );

      case GroupWatchInvitationStatus.expired:
        throw StateError(
          'This invitation link is expired.',
        );

      case GroupWatchInvitationStatus.pending:
        break;
    }

    if (!session.acceptInvitation(cleanProfileId)) {
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
    final session = _requireSession(sessionId);
    final cleanProfileId = profileId.trim();

    if (cleanProfileId.isEmpty) {
      throw ArgumentError('Profile ID is required.');
    }

    _expireAndSaveIfNecessary(session);

    final participant =
        session.participantFor(cleanProfileId);

    if (participant == null) {
      throw StateError(
        'This profile was not invited to the Group Watch.',
      );
    }

    if (session.hasStarted) {
      throw StateError(
        'This invitation link is expired.',
      );
    }

    switch (participant.invitationStatus) {
      case GroupWatchInvitationStatus.expired:
        throw StateError(
          'This invitation link is expired.',
        );

      case GroupWatchInvitationStatus.accepted:
        throw StateError(
          'This invitation was already accepted.',
        );

      case GroupWatchInvitationStatus.declined:
        return session;

      case GroupWatchInvitationStatus.pending:
        break;
    }

    if (!session.declineInvitation(cleanProfileId)) {
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
    final session = _requireSession(sessionId);
    final cleanProfileId = profileId.trim();

    if (cleanProfileId.isEmpty) {
      throw ArgumentError('Profile ID is required.');
    }

    _requireAcceptedParticipant(
      session,
      cleanProfileId,
    );

    if (session.hasStarted) {
      throw StateError(
        'Audio selection is locked after Group Watch starts.',
      );
    }

    final cleanTrackId = audioTrackId?.trim();

    if (!session.setAudioTrack(
      cleanProfileId,
      cleanTrackId == null || cleanTrackId.isEmpty
          ? null
          : cleanTrackId,
    )) {
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
    final session = _requireSession(sessionId);
    final cleanProfileId = profileId.trim();

    if (cleanProfileId.isEmpty) {
      throw ArgumentError('Profile ID is required.');
    }

    _requireAcceptedParticipant(
      session,
      cleanProfileId,
    );

    if (session.hasStarted) {
      throw StateError(
        'Subtitle selection is locked after Group Watch starts.',
      );
    }

    final cleanTrackId = subtitleTrackId?.trim();

    if (!session.setSubtitleTrack(
      cleanProfileId,
      cleanTrackId == null || cleanTrackId.isEmpty
          ? null
          : cleanTrackId,
    )) {
      throw StateError(
        'Unable to set the subtitle track.',
      );
    }

    database.saveGroupWatchSession(session);

    return session;
  }

  // ---------------------------------------------------------------------------
  // START
  // ---------------------------------------------------------------------------

  GroupWatchSession startSession({
    required String sessionId,
    required String profileId,
  }) {
    final session = _requireSession(sessionId);
    final cleanProfileId = profileId.trim();

    if (cleanProfileId.isEmpty) {
      throw ArgumentError('Profile ID is required.');
    }

    if (session.hostProfileId != cleanProfileId) {
      throw StateError(
        'Only the Group Watch host can start playback.',
      );
    }

    final hostAccount =
        database.getAccountById(session.accountId);

    if (hostAccount == null) {
      throw StateError(
        'The Group Watch host account is no longer valid.',
      );
    }

    if (hostAccount.getProfileById(
          session.hostProfileId,
        ) ==
        null) {
      throw StateError(
        'The Group Watch host is no longer valid.',
      );
    }

    if (!_accountOwnsMedia(
      hostAccount,
      session.mediaId,
      session.hostProfileId,
    )) {
      throw StateError(
        'The Group Watch host no longer has access to this media.',
      );
    }

    if (session.hasStarted) {
      return session;
    }

    _expireAndSaveIfNecessary(session);

    if (!session.areInvitationsOpen) {
      throw StateError(
        'This invitation link is expired.',
      );
    }

    if (!session.hasAccepted(session.hostProfileId)) {
      throw StateError(
        'The Group Watch host must accept the session before playback can start.',
      );
    }

    if (!session.canStart) {
      throw StateError(
        'At least one participant must accept before playback can start.',
      );
    }

    if (!session.start()) {
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
    final session = _requireSession(sessionId);
    final cleanProfileId = profileId.trim();

    _requirePlayableParticipant(
      session,
      cleanProfileId,
    );

    if (!session.play()) {
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
    final session = _requireSession(sessionId);
    final cleanProfileId = profileId.trim();
    final cleanReason = reason.trim();

    if (cleanProfileId.isEmpty) {
      throw ArgumentError('Profile ID is required.');
    }

    if (cleanReason.isEmpty) {
      throw ArgumentError('Pause reason is required.');
    }

    if (cleanReason.length > 500) {
      throw ArgumentError(
        'Pause reason cannot exceed 500 characters.',
      );
    }

    _requirePlayableParticipant(
      session,
      cleanProfileId,
    );

    if (!session.pause(
      profileId: cleanProfileId,
      reason: cleanReason,
    )) {
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
    final session = _requireSession(sessionId);
    final cleanProfileId = profileId.trim();

    if (cleanProfileId.isEmpty) {
      throw ArgumentError('Profile ID is required.');
    }

    if (session.status != GroupWatchSessionStatus.paused) {
      throw StateError(
        'The Group Watch is not paused.',
      );
    }

    if (session.pausedByProfileId != cleanProfileId) {
      throw StateError(
        'Only the person who paused the Group Watch can resume it.',
      );
    }

    _requirePlayableParticipant(
      session,
      cleanProfileId,
    );

    if (!session.resume(cleanProfileId)) {
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
    final session = _requireSession(sessionId);
    final cleanProfileId = profileId.trim();

    if (cleanProfileId.isEmpty) {
      throw ArgumentError('Profile ID is required.');
    }

    if (position.isNegative) {
      throw ArgumentError(
        'Playback position cannot be negative.',
      );
    }

    // A position beyond 7 days is almost certainly malformed client input.
    if (position > const Duration(days: 7)) {
      throw ArgumentError(
        'Playback position is outside the supported range.',
      );
    }

    _requirePlayableParticipant(
      session,
      cleanProfileId,
    );

    if (!session.updatePlaybackPosition(
      profileId: cleanProfileId,
      position: position,
    )) {
      throw StateError(
        'Unable to update the playback position.',
      );
    }

    database.saveGroupWatchSession(session);

    return session;
  }

  // ---------------------------------------------------------------------------
  // END
  // ---------------------------------------------------------------------------

  GroupWatchSession endSession({
    required String sessionId,
    required String profileId,
  }) {
    final session = _requireSession(sessionId);
    final cleanProfileId = profileId.trim();

    if (cleanProfileId.isEmpty) {
      throw ArgumentError('Profile ID is required.');
    }

    if (session.hostProfileId != cleanProfileId) {
      throw StateError(
        'Only the Group Watch host can end the session.',
      );
    }

    _requireHostStillValid(session);

    if (session.status == GroupWatchSessionStatus.ended) {
      return session;
    }

    session.end();

    database.saveGroupWatchSession(session);

    return session;
  }

  // ---------------------------------------------------------------------------
  // DELETE
  // ---------------------------------------------------------------------------

  bool deleteSession({
    required String sessionId,
    required String profileId,
  }) {
    final session = _requireSession(sessionId);
    final cleanProfileId = profileId.trim();

    if (cleanProfileId.isEmpty) {
      throw ArgumentError('Profile ID is required.');
    }

    if (session.hostProfileId != cleanProfileId) {
      throw StateError(
        'Only the Group Watch host can delete the session.',
      );
    }

    _requireHostStillValid(session);

    database.deleteGroupWatchSession(session.id);

    return true;
  }

  // ---------------------------------------------------------------------------
  // INVITATION EXPIRATION
  // ---------------------------------------------------------------------------

  void expireInvitations({
    required String sessionId,
  }) {
    final session = _requireSession(sessionId);

    _expireAndSaveIfNecessary(session);
  }

  bool _expireInvitationsIfNecessary(
    GroupWatchSession session,
  ) {
    final hasPendingInvitations =
        session.participants.values.any(
      (participant) =>
          participant.invitationStatus ==
          GroupWatchInvitationStatus.pending,
    );

    if (!hasPendingInvitations) {
      return false;
    }

    // Once playback starts, pending invitations can no longer be accepted.
    if (session.hasStarted) {
      session.expirePendingInvitations();
      return true;
    }

    if (DateTime.now().isBefore(
      session.invitationExpiresAt,
    )) {
      return false;
    }

    session.expirePendingInvitations();

    return true;
  }

  void _expireAndSaveIfNecessary(
    GroupWatchSession session,
  ) {
    if (_expireInvitationsIfNecessary(session)) {
      database.saveGroupWatchSession(session);
    }
  }

  // ---------------------------------------------------------------------------
  // MEDIA OWNERSHIP
  // ---------------------------------------------------------------------------

  bool _accountOwnsMedia(
    Account account,
    String mediaId,
    String profileId,
  ) {
    final cleanMediaId = mediaId.trim();
    final cleanProfileId = profileId.trim();

    if (cleanMediaId.isEmpty || cleanProfileId.isEmpty) {
      return false;
    }

    final media = database.getMediaById(cleanMediaId);

    if (media == null) {
      return false;
    }

    if (!account.hasProfile(cleanProfileId)) {
      return false;
    }

    // Explicit profile access takes precedence over legacy account-wide data.
    if (media.accessibleProfileIds.isNotEmpty &&
        !media.accessibleProfileIds.contains(cleanProfileId)) {
      return false;
    }

    final profile = account.getProfileById(cleanProfileId);

    return profile?.ownedMediaIds.contains(cleanMediaId) == true;
  }

  // ---------------------------------------------------------------------------
  // AUTHORIZATION HELPERS
  // ---------------------------------------------------------------------------

  GroupWatchParticipant _requireParticipant(
    GroupWatchSession session,
    String profileId,
  ) {
    final cleanProfileId = profileId.trim();

    if (cleanProfileId.isEmpty) {
      throw ArgumentError('Profile ID is required.');
    }

    final participant =
        session.participantFor(cleanProfileId);

    if (participant == null) {
      throw StateError(
        'This profile is not a participant in the Group Watch.',
      );
    }

    final account =
        database.getAccountForProfile(cleanProfileId);

    if (account == null) {
      throw StateError(
        'The participant profile is no longer available.',
      );
    }

    if (participant.accountId != account.id) {
      throw StateError(
        'The participant account no longer matches the profile.',
      );
    }

    if (!_accountOwnsMedia(
      account,
      session.mediaId,
      cleanProfileId,
    )) {
      throw StateError(
        'The participant no longer has access to this media.',
      );
    }

    return participant;
  }

  GroupWatchParticipant _requireAcceptedParticipant(
    GroupWatchSession session,
    String profileId,
  ) {
    final participant = _requireParticipant(
      session,
      profileId,
    );

    if (!participant.hasAccepted) {
      throw StateError(
        'Only accepted participants can perform this action.',
      );
    }

    return participant;
  }

  GroupWatchParticipant _requirePlayableParticipant(
    GroupWatchSession session,
    String profileId,
  ) {
    if (!session.hasStarted) {
      throw StateError(
        'The Group Watch has not started.',
      );
    }

    if (session.status == GroupWatchSessionStatus.ended) {
      throw StateError(
        'The Group Watch has ended.',
      );
    }

    return _requireAcceptedParticipant(
      session,
      profileId,
    );
  }

  void _requireHostStillValid(
    GroupWatchSession session,
  ) {
    final hostAccount =
        database.getAccountById(session.accountId);

    if (hostAccount == null) {
      throw StateError(
        'The Group Watch host account is no longer valid.',
      );
    }

    if (hostAccount.getProfileById(
          session.hostProfileId,
        ) ==
        null) {
      throw StateError(
        'The Group Watch host is no longer valid.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // INTERNAL HELPERS
  // ---------------------------------------------------------------------------

  GroupWatchSession _requireSession(
    String sessionId,
  ) {
    final cleanSessionId = sessionId.trim();

    if (cleanSessionId.isEmpty) {
      throw ArgumentError('Session ID is required.');
    }

    final session =
        database.getGroupWatchSessionById(
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
    String id;

    do {
      final timestamp =
          DateTime.now().microsecondsSinceEpoch;
      final randomPart =
          _random.nextInt(0x7fffffff).toRadixString(16);

      id = 'group_watch_${timestamp}_$randomPart';
    } while (
        database.getGroupWatchSessionById(id) != null);

    return id;
  }
}