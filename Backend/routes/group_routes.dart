import 'dart:convert';
import 'dart:io';

import '../database/database.dart';
import '../middleware/authentication.dart';
import '../models/group_recommendation.dart';
import '../models/group_watch_session.dart';
import '../services/group_recommendation_service.dart';
import '../services/group_watch_service.dart';

class GroupRoutes {
  final Database database;
  final AuthenticationMiddleware authenticationMiddleware;
  final GroupRecommendationService recommendationService;
  final GroupWatchService watchService;

  GroupRoutes({
    required this.database,
    required this.authenticationMiddleware,
    required this.recommendationService,
    required this.watchService,
  });

  Future<void> handle(HttpRequest request) async {
    try {
      final authenticatedAccount =
          authenticationMiddleware.authenticate(request);

      if (authenticatedAccount == null) {
        await _sendJson(
          request,
          HttpStatus.unauthorized,
          <String, dynamic>{
            'error': 'Authentication required.',
          },
        );
        return;
      }

      final account = authenticatedAccount;
      final accountId = account.id;
      final path = request.uri.path;

      // ==========================================================
      // GROUP WATCH
      // ==========================================================

      // ----------------------------------------------------------
      // CREATE GROUP WATCH SESSION
      // ----------------------------------------------------------

      if (request.method == 'POST' &&
          path == '/api/v1/group/watch') {
        final body = await _readJsonBody(request);

        final String mediaId =
            body['mediaId']?.toString().trim() ?? '';

        final String title =
            body['title']?.toString().trim() ?? '';

        final String type =
            body['type']?.toString().trim() ?? '';

        final String profileId =
            body['profileId']?.toString().trim() ?? '';

        final Set<String> invitedProfileIds =
            _readStringSet(
          body['invitedProfileIds'],
        );

        if (mediaId.isEmpty) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error': 'mediaId is required.',
            },
          );
          return;
        }

        if (title.isEmpty) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error': 'title is required.',
            },
          );
          return;
        }

        if (type != 'movie' && type != 'tvShow') {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error':
                  'type must be either "movie" or "tvShow".',
            },
          );
          return;
        }

        if (profileId.isEmpty) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error': 'profileId is required.',
            },
          );
          return;
        }

        final hostProfile =
            account.getProfileById(profileId);

        if (hostProfile == null) {
          await _sendJson(
            request,
            HttpStatus.forbidden,
            <String, dynamic>{
              'error':
                  'This profile does not belong to the account.',
            },
          );
          return;
        }

        final media =
            database.getMediaById(mediaId);

        if (media == null) {
          await _sendJson(
            request,
            HttpStatus.notFound,
            <String, dynamic>{
              'error':
                  'Selected media was not found.',
            },
          );
          return;
        }

        invitedProfileIds.remove(profileId);

        // IMPORTANT:
        // Invited profiles may belong to OTHER accounts.
        //
        // The GroupWatchService performs the actual validation
        // that each invited profile exists and that its account
        // owns the selected media.
        //
        // We intentionally do NOT require:
        //
        // account.getProfileById(invitedProfileId) != null
        //
        // because Group Watch supports cross-account invitations.

        final dynamic durationRaw =
            body['invitationDurationHours'];

        double invitationDurationHours;

        if (durationRaw == null) {
          invitationDurationHours = 24;
        } else if (durationRaw is num) {
          invitationDurationHours =
              durationRaw.toDouble();
        } else {
          invitationDurationHours =
              double.tryParse(
                    durationRaw.toString(),
                  ) ??
                  0;
        }

        if (invitationDurationHours <= 0) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error':
                  'invitationDurationHours must be greater than zero.',
            },
          );
          return;
        }

        final Duration invitationDuration =
            Duration(
          milliseconds:
              (invitationDurationHours *
                      Duration.millisecondsPerHour)
                  .round(),
        );

        if (invitationDuration <= Duration.zero) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error':
                  'Invitation duration is invalid.',
            },
          );
          return;
        }

        try {
          final GroupWatchSession session =
              watchService.createSession(
            accountId: accountId,
            hostProfileId: profileId,
            mediaId: mediaId,
            title: title,
            type: type,
            invitedProfileIds:
                invitedProfileIds,
            invitationDuration:
                invitationDuration,
          );

          database.saveGroupWatchSession(
            session,
          );

          await _sendJson(
            request,
            HttpStatus.created,
            <String, dynamic>{
              'session': session.toJson(),
            },
          );
        } catch (error) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error': error.toString(),
            },
          );
        }

        return;
      }

      // ----------------------------------------------------------
      // GET GROUP WATCH SESSIONS FOR ACCOUNT
      // ----------------------------------------------------------

      if (request.method == 'GET' &&
          path == '/api/v1/group/watch') {
        final List<GroupWatchSession> sessions =
            watchService.getSessionsForAccount(
          accountId,
        );

        for (final GroupWatchSession session
            in sessions) {
          database.saveGroupWatchSession(
            session,
          );
        }

        await _sendJson(
          request,
          HttpStatus.ok,
          <String, dynamic>{
            'sessions': sessions
                .map(
                  (session) => session.toJson(),
                )
                .toList(),
          },
        );

        return;
      }

      // ----------------------------------------------------------
      // GROUP WATCH SESSION PATH
      // ----------------------------------------------------------

      final groupWatchPath =
          RegExp(
        r'^/api/v1/group/watch/([^/]+)$',
      );

      final groupWatchMatch =
          groupWatchPath.firstMatch(path);

      // ----------------------------------------------------------
      // GET SINGLE GROUP WATCH SESSION
      // ----------------------------------------------------------

      if (request.method == 'GET' &&
          groupWatchMatch != null) {
        final String sessionId =
            groupWatchMatch.group(1)!;

        final GroupWatchSession? session =
            watchService.getSession(
          sessionId,
        );

        if (session == null ||
            !_sessionVisibleToAccount(
              session,
              accountId,
            )) {
          await _sendJson(
            request,
            HttpStatus.notFound,
            <String, dynamic>{
              'error':
                  'Group Watch session not found.',
            },
          );
          return;
        }

        database.saveGroupWatchSession(
          session,
        );

        await _sendJson(
          request,
          HttpStatus.ok,
          <String, dynamic>{
            'session': session.toJson(),
          },
        );

        return;
      }

      // ----------------------------------------------------------
      // ACCEPT GROUP WATCH INVITATION
      // ----------------------------------------------------------

      final groupWatchAcceptPath =
          RegExp(
        r'^/api/v1/group/watch/([^/]+)/accept$',
      );

      final groupWatchAcceptMatch =
          groupWatchAcceptPath.firstMatch(path);

      if (request.method == 'POST' &&
          groupWatchAcceptMatch != null) {
        final String sessionId =
            groupWatchAcceptMatch.group(1)!;

        final body =
            await _readJsonBody(request);

        final String profileId =
            body['profileId']
                    ?.toString()
                    .trim() ??
                '';

        if (profileId.isEmpty) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error':
                  'profileId is required.',
            },
          );
          return;
        }

        if (!_profileBelongsToAccount(
          profileId,
          accountId,
        )) {
          await _sendJson(
            request,
            HttpStatus.forbidden,
            <String, dynamic>{
              'error':
                  'This profile does not belong to the account.',
            },
          );
          return;
        }

        final existingSession =
            watchService.getSession(
          sessionId,
        );

        if (existingSession == null ||
            !_sessionVisibleToAccount(
              existingSession,
              accountId,
            )) {
          await _sendJson(
            request,
            HttpStatus.notFound,
            <String, dynamic>{
              'error':
                  'Group Watch session not found.',
            },
          );
          return;
        }

        try {
          final GroupWatchSession session =
              watchService.acceptInvitation(
            sessionId: sessionId,
            profileId: profileId,
          );

          database.saveGroupWatchSession(
            session,
          );

          await _sendJson(
            request,
            HttpStatus.ok,
            <String, dynamic>{
              'session': session.toJson(),
              'message':
                  'Group Watch invitation accepted.',
            },
          );
        } catch (error) {
          final String errorMessage =
              error.toString();

          final int status =
              errorMessage.contains(
                        'This invitation link is expired.',
                      ) ||
                      errorMessage.contains(
                        'This invite has expired.',
                      )
                  ? HttpStatus.gone
                  : HttpStatus.badRequest;

          await _sendJson(
            request,
            status,
            <String, dynamic>{
              'error': errorMessage,
            },
          );
        }

        return;
      }

      // ----------------------------------------------------------
      // DECLINE GROUP WATCH INVITATION
      // ----------------------------------------------------------

      final groupWatchDeclinePath =
          RegExp(
        r'^/api/v1/group/watch/([^/]+)/decline$',
      );

      final groupWatchDeclineMatch =
          groupWatchDeclinePath.firstMatch(
        path,
      );

      if (request.method == 'POST' &&
          groupWatchDeclineMatch != null) {
        final String sessionId =
            groupWatchDeclineMatch.group(1)!;

        final body =
            await _readJsonBody(request);

        final String profileId =
            body['profileId']
                    ?.toString()
                    .trim() ??
                '';

        if (profileId.isEmpty) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error':
                  'profileId is required.',
            },
          );
          return;
        }

        if (!_profileBelongsToAccount(
          profileId,
          accountId,
        )) {
          await _sendJson(
            request,
            HttpStatus.forbidden,
            <String, dynamic>{
              'error':
                  'This profile does not belong to the account.',
            },
          );
          return;
        }

        final existingSession =
            watchService.getSession(
          sessionId,
        );

        if (existingSession == null ||
            !_sessionVisibleToAccount(
              existingSession,
              accountId,
            )) {
          await _sendJson(
            request,
            HttpStatus.notFound,
            <String, dynamic>{
              'error':
                  'Group Watch session not found.',
            },
          );
          return;
        }

        try {
          final GroupWatchSession session =
              watchService.declineInvitation(
            sessionId: sessionId,
            profileId: profileId,
          );

          database.saveGroupWatchSession(
            session,
          );

          await _sendJson(
            request,
            HttpStatus.ok,
            <String, dynamic>{
              'session': session.toJson(),
              'message':
                  'Group Watch invitation declined.',
            },
          );
        } catch (error) {
          final String errorMessage =
              error.toString();

          final int status =
              errorMessage.contains(
                        'This invitation link is expired.',
                      ) ||
                      errorMessage.contains(
                        'This invite has expired.',
                      )
                  ? HttpStatus.gone
                  : HttpStatus.badRequest;

          await _sendJson(
            request,
            status,
            <String, dynamic>{
              'error': errorMessage,
            },
          );
        }

        return;
      }

      // ----------------------------------------------------------
      // SET AUDIO TRACK
      // ----------------------------------------------------------

      final groupWatchAudioPath =
          RegExp(
        r'^/api/v1/group/watch/([^/]+)/audio$',
      );

      final groupWatchAudioMatch =
          groupWatchAudioPath.firstMatch(
        path,
      );

      if (request.method == 'POST' &&
          groupWatchAudioMatch != null) {
        final String sessionId =
            groupWatchAudioMatch.group(1)!;

        final body =
            await _readJsonBody(request);

        final String profileId =
            body['profileId']
                    ?.toString()
                    .trim() ??
                '';

        final String? audioTrackId =
            body['audioTrackId']
                ?.toString()
                .trim();

        if (profileId.isEmpty) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error':
                  'profileId is required.',
            },
          );
          return;
        }

        if (!_profileBelongsToAccount(
          profileId,
          accountId,
        )) {
          await _sendJson(
            request,
            HttpStatus.forbidden,
            <String, dynamic>{
              'error':
                  'This profile does not belong to the account.',
            },
          );
          return;
        }

        final existingSession =
            watchService.getSession(
          sessionId,
        );

        if (existingSession == null ||
            !_sessionVisibleToAccount(
              existingSession,
              accountId,
            )) {
          await _sendJson(
            request,
            HttpStatus.notFound,
            <String, dynamic>{
              'error':
                  'Group Watch session not found.',
            },
          );
          return;
        }

        try {
          final GroupWatchSession session =
              watchService.setAudioTrack(
            sessionId: sessionId,
            profileId: profileId,
            audioTrackId:
                audioTrackId,
          );

          database.saveGroupWatchSession(
            session,
          );

          await _sendJson(
            request,
            HttpStatus.ok,
            <String, dynamic>{
              'session': session.toJson(),
            },
          );
        } catch (error) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error': error.toString(),
            },
          );
        }

        return;
      }

      // ----------------------------------------------------------
      // SET SUBTITLE TRACK
      // ----------------------------------------------------------

      final groupWatchSubtitlePath =
          RegExp(
        r'^/api/v1/group/watch/([^/]+)/subtitles$',
      );

      final groupWatchSubtitleMatch =
          groupWatchSubtitlePath.firstMatch(
        path,
      );

      if (request.method == 'POST' &&
          groupWatchSubtitleMatch != null) {
        final String sessionId =
            groupWatchSubtitleMatch.group(1)!;

        final body =
            await _readJsonBody(request);

        final String profileId =
            body['profileId']
                    ?.toString()
                    .trim() ??
                '';

        final String? subtitleTrackId =
            body['subtitleTrackId']
                ?.toString()
                .trim();

        if (profileId.isEmpty) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error':
                  'profileId is required.',
            },
          );
          return;
        }

        if (!_profileBelongsToAccount(
          profileId,
          accountId,
        )) {
          await _sendJson(
            request,
            HttpStatus.forbidden,
            <String, dynamic>{
              'error':
                  'This profile does not belong to the account.',
            },
          );
          return;
        }

        final existingSession =
            watchService.getSession(
          sessionId,
        );

        if (existingSession == null ||
            !_sessionVisibleToAccount(
              existingSession,
              accountId,
            )) {
          await _sendJson(
            request,
            HttpStatus.notFound,
            <String, dynamic>{
              'error':
                  'Group Watch session not found.',
            },
          );
          return;
        }

        try {
          final GroupWatchSession session =
              watchService.setSubtitleTrack(
            sessionId: sessionId,
            profileId: profileId,
            subtitleTrackId:
                subtitleTrackId,
          );

          database.saveGroupWatchSession(
            session,
          );

          await _sendJson(
            request,
            HttpStatus.ok,
            <String, dynamic>{
              'session': session.toJson(),
            },
          );
        } catch (error) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error': error.toString(),
            },
          );
        }

        return;
      }

      // ----------------------------------------------------------
      // START GROUP WATCH
      // ----------------------------------------------------------

      final groupWatchStartPath =
          RegExp(
        r'^/api/v1/group/watch/([^/]+)/start$',
      );

      final groupWatchStartMatch =
          groupWatchStartPath.firstMatch(
        path,
      );

      if (request.method == 'POST' &&
          groupWatchStartMatch != null) {
        final String sessionId =
            groupWatchStartMatch.group(1)!;

        final body =
            await _readJsonBody(request);

        final String profileId =
            body['profileId']
                    ?.toString()
                    .trim() ??
                '';

        if (profileId.isEmpty) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error':
                  'profileId is required.',
            },
          );
          return;
        }

        if (!_profileBelongsToAccount(
          profileId,
          accountId,
        )) {
          await _sendJson(
            request,
            HttpStatus.forbidden,
            <String, dynamic>{
              'error':
                  'This profile does not belong to the account.',
            },
          );
          return;
        }

        final existingSession =
            watchService.getSession(
          sessionId,
        );

        if (existingSession == null ||
            !_sessionVisibleToAccount(
              existingSession,
              accountId,
            )) {
          await _sendJson(
            request,
            HttpStatus.notFound,
            <String, dynamic>{
              'error':
                  'Group Watch session not found.',
            },
          );
          return;
        }

        try {
          final GroupWatchSession session =
              watchService.startSession(
            sessionId: sessionId,
            profileId: profileId,
          );

          database.saveGroupWatchSession(
            session,
          );

          await _sendJson(
            request,
            HttpStatus.ok,
            <String, dynamic>{
              'session': session.toJson(),
              'message':
                  'Group Watch started.',
            },
          );
        } catch (error) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error': error.toString(),
            },
          );
        }

        return;
      }

      // ----------------------------------------------------------
      // PLAY
      // ----------------------------------------------------------

      final groupWatchPlayPath =
          RegExp(
        r'^/api/v1/group/watch/([^/]+)/play$',
      );

      final groupWatchPlayMatch =
          groupWatchPlayPath.firstMatch(
        path,
      );

      if (request.method == 'POST' &&
          groupWatchPlayMatch != null) {
        final String sessionId =
            groupWatchPlayMatch.group(1)!;

        final body =
            await _readJsonBody(request);

        final String profileId =
            body['profileId']
                    ?.toString()
                    .trim() ??
                '';

        if (profileId.isEmpty) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error':
                  'profileId is required.',
            },
          );
          return;
        }

        if (!_profileBelongsToAccount(
          profileId,
          accountId,
        )) {
          await _sendJson(
            request,
            HttpStatus.forbidden,
            <String, dynamic>{
              'error':
                  'This profile does not belong to the account.',
            },
          );
          return;
        }

        final existingSession =
            watchService.getSession(
          sessionId,
        );

        if (existingSession == null ||
            !_sessionVisibleToAccount(
              existingSession,
              accountId,
            )) {
          await _sendJson(
            request,
            HttpStatus.notFound,
            <String, dynamic>{
              'error':
                  'Group Watch session not found.',
            },
          );
          return;
        }

        try {
          final GroupWatchSession session =
              watchService.play(
            sessionId: sessionId,
            profileId: profileId,
          );

          database.saveGroupWatchSession(
            session,
          );

          await _sendJson(
            request,
            HttpStatus.ok,
            <String, dynamic>{
              'session': session.toJson(),
            },
          );
        } catch (error) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error': error.toString(),
            },
          );
        }

        return;
      }

      // ----------------------------------------------------------
      // PAUSE
      // ----------------------------------------------------------

      final groupWatchPausePath =
          RegExp(
        r'^/api/v1/group/watch/([^/]+)/pause$',
      );

      final groupWatchPauseMatch =
          groupWatchPausePath.firstMatch(
        path,
      );

      if (request.method == 'POST' &&
          groupWatchPauseMatch != null) {
        final String sessionId =
            groupWatchPauseMatch.group(1)!;

        final body =
            await _readJsonBody(request);

        final String profileId =
            body['profileId']
                    ?.toString()
                    .trim() ??
                '';

        final String reason =
            body['reason']
                    ?.toString()
                    .trim() ??
                '';

        if (profileId.isEmpty) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error':
                  'profileId is required.',
            },
          );
          return;
        }

        if (reason.isEmpty) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error':
                  'reason is required.',
            },
          );
          return;
        }

        if (!_profileBelongsToAccount(
          profileId,
          accountId,
        )) {
          await _sendJson(
            request,
            HttpStatus.forbidden,
            <String, dynamic>{
              'error':
                  'This profile does not belong to the account.',
            },
          );
          return;
        }

        final existingSession =
            watchService.getSession(
          sessionId,
        );

        if (existingSession == null ||
            !_sessionVisibleToAccount(
              existingSession,
              accountId,
            )) {
          await _sendJson(
            request,
            HttpStatus.notFound,
            <String, dynamic>{
              'error':
                  'Group Watch session not found.',
            },
          );
          return;
        }

        try {
          final GroupWatchSession session =
              watchService.pause(
            sessionId: sessionId,
            profileId: profileId,
            reason: reason,
          );

          database.saveGroupWatchSession(
            session,
          );

          await _sendJson(
            request,
            HttpStatus.ok,
            <String, dynamic>{
              'session': session.toJson(),
              'message':
                  'Group Watch paused.',
            },
          );
        } catch (error) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error': error.toString(),
            },
          );
        }

        return;
      }

      // ----------------------------------------------------------
      // RESUME
      // ----------------------------------------------------------

      final groupWatchResumePath =
          RegExp(
        r'^/api/v1/group/watch/([^/]+)/resume$',
      );

      final groupWatchResumeMatch =
          groupWatchResumePath.firstMatch(
        path,
      );

      if (request.method == 'POST' &&
          groupWatchResumeMatch != null) {
        final String sessionId =
            groupWatchResumeMatch.group(1)!;

        final body =
            await _readJsonBody(request);

        final String profileId =
            body['profileId']
                    ?.toString()
                    .trim() ??
                '';

        if (profileId.isEmpty) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error':
                  'profileId is required.',
            },
          );
          return;
        }

        if (!_profileBelongsToAccount(
          profileId,
          accountId,
        )) {
          await _sendJson(
            request,
            HttpStatus.forbidden,
            <String, dynamic>{
              'error':
                  'This profile does not belong to the account.',
            },
          );
          return;
        }

        final existingSession =
            watchService.getSession(
          sessionId,
        );

        if (existingSession == null ||
            !_sessionVisibleToAccount(
              existingSession,
              accountId,
            )) {
          await _sendJson(
            request,
            HttpStatus.notFound,
            <String, dynamic>{
              'error':
                  'Group Watch session not found.',
            },
          );
          return;
        }

        try {
          final GroupWatchSession session =
              watchService.resume(
            sessionId: sessionId,
            profileId: profileId,
          );

          database.saveGroupWatchSession(
            session,
          );

          await _sendJson(
            request,
            HttpStatus.ok,
            <String, dynamic>{
              'session': session.toJson(),
              'message':
                  'Group Watch resumed.',
            },
          );
        } catch (error) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error': error.toString(),
            },
          );
        }

        return;
      }

      // ----------------------------------------------------------
      // UPDATE SHARED PLAYBACK POSITION
      // ----------------------------------------------------------

      final groupWatchPositionPath =
          RegExp(
        r'^/api/v1/group/watch/([^/]+)/position$',
      );

      final groupWatchPositionMatch =
          groupWatchPositionPath.firstMatch(
        path,
      );

      if (request.method == 'POST' &&
          groupWatchPositionMatch != null) {
        final String sessionId =
            groupWatchPositionMatch.group(1)!;

        final body =
            await _readJsonBody(request);

        final String profileId =
            body['profileId']
                    ?.toString()
                    .trim() ??
                '';

        // The current Flutter client sends positionSeconds.
        //
        // The backend historically expected
        // positionMilliseconds.
        //
        // Accept both so the API remains compatible.
        final dynamic millisecondsRaw =
            body['positionMilliseconds'];

        final dynamic secondsRaw =
            body['positionSeconds'];

        int? positionMilliseconds;

        if (millisecondsRaw != null) {
          positionMilliseconds =
              _readInt(millisecondsRaw);
        } else if (secondsRaw != null) {
          final double? seconds =
              _readDouble(secondsRaw);

          if (seconds != null) {
            positionMilliseconds =
                (seconds * 1000).round();
          }
        }

        if (profileId.isEmpty) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error':
                  'profileId is required.',
            },
          );
          return;
        }

        if (!_profileBelongsToAccount(
          profileId,
          accountId,
        )) {
          await _sendJson(
            request,
            HttpStatus.forbidden,
            <String, dynamic>{
              'error':
                  'This profile does not belong to the account.',
            },
          );
          return;
        }

        if (positionMilliseconds == null ||
            positionMilliseconds < 0) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error':
                  'positionMilliseconds or positionSeconds must be a non-negative number.',
            },
          );
          return;
        }

        final existingSession =
            watchService.getSession(
          sessionId,
        );

        if (existingSession == null ||
            !_sessionVisibleToAccount(
              existingSession,
              accountId,
            )) {
          await _sendJson(
            request,
            HttpStatus.notFound,
            <String, dynamic>{
              'error':
                  'Group Watch session not found.',
            },
          );
          return;
        }

        try {
          final GroupWatchSession session =
              watchService.updatePlaybackPosition(
            sessionId: sessionId,
            profileId: profileId,
            position: Duration(
              milliseconds:
                  positionMilliseconds,
            ),
          );

          database.saveGroupWatchSession(
            session,
          );

          await _sendJson(
            request,
            HttpStatus.ok,
            <String, dynamic>{
              'session': session.toJson(),
              'playbackPositionMilliseconds':
                  session.playbackPosition
                      .inMilliseconds,
            },
          );
        } catch (error) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error': error.toString(),
            },
          );
        }

        return;
      }

      // ----------------------------------------------------------
      // END GROUP WATCH
      // ----------------------------------------------------------

      final groupWatchEndPath =
          RegExp(
        r'^/api/v1/group/watch/([^/]+)/end$',
      );

      final groupWatchEndMatch =
          groupWatchEndPath.firstMatch(path);

      if (request.method == 'POST' &&
          groupWatchEndMatch != null) {
        final String sessionId =
            groupWatchEndMatch.group(1)!;

        final body =
            await _readJsonBody(request);

        final String profileId =
            body['profileId']
                    ?.toString()
                    .trim() ??
                '';

        if (profileId.isEmpty) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error':
                  'profileId is required.',
            },
          );
          return;
        }

        if (!_profileBelongsToAccount(
          profileId,
          accountId,
        )) {
          await _sendJson(
            request,
            HttpStatus.forbidden,
            <String, dynamic>{
              'error':
                  'This profile does not belong to the account.',
            },
          );
          return;
        }

        final existingSession =
            watchService.getSession(
          sessionId,
        );

        if (existingSession == null ||
            !_sessionVisibleToAccount(
              existingSession,
              accountId,
            )) {
          await _sendJson(
            request,
            HttpStatus.notFound,
            <String, dynamic>{
              'error':
                  'Group Watch session not found.',
            },
          );
          return;
        }

        try {
          final GroupWatchSession session =
              watchService.endSession(
            sessionId: sessionId,
            profileId: profileId,
          );

          database.saveGroupWatchSession(
            session,
          );

          await _sendJson(
            request,
            HttpStatus.ok,
            <String, dynamic>{
              'session': session.toJson(),
              'message':
                  'Group Watch ended.',
            },
          );
        } catch (error) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error': error.toString(),
            },
          );
        }

        return;
      }

      // ----------------------------------------------------------
      // DELETE GROUP WATCH SESSION
      // ----------------------------------------------------------

      if (request.method == 'DELETE' &&
          groupWatchMatch != null) {
        final String sessionId =
            groupWatchMatch.group(1)!;

        final body =
            await _readJsonBody(request);

        final String profileId =
            body['profileId']
                    ?.toString()
                    .trim() ??
                '';

        if (profileId.isEmpty) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error':
                  'profileId is required.',
            },
          );
          return;
        }

        if (!_profileBelongsToAccount(
          profileId,
          accountId,
        )) {
          await _sendJson(
            request,
            HttpStatus.forbidden,
            <String, dynamic>{
              'error':
                  'This profile does not belong to the account.',
            },
          );
          return;
        }

        try {
          final GroupWatchSession? session =
              watchService.getSession(
            sessionId,
          );

          if (session == null ||
              !_sessionVisibleToAccount(
                session,
                accountId,
              )) {
            await _sendJson(
              request,
              HttpStatus.notFound,
              <String, dynamic>{
                'error':
                    'Group Watch session not found.',
              },
            );
            return;
          }

          watchService.deleteSession(
            sessionId: sessionId,
            profileId: profileId,
          );

          database.deleteGroupWatchSession(
            sessionId,
          );

          await _sendJson(
            request,
            HttpStatus.ok,
            <String, dynamic>{
              'message':
                  'Group Watch session deleted.',
            },
          );
        } catch (error) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error': error.toString(),
            },
          );
        }

        return;
      }

      // ==========================================================
      // GROUP RECOMMENDATIONS
      // ==========================================================

      // ----------------------------------------------------------
      // CREATE RECOMMENDATION
      // ----------------------------------------------------------

      if (request.method == 'POST' &&
          path == '/api/v1/group/recommendations') {
        final body = await _readJsonBody(request);

        final title =
            body['title']?.toString().trim() ?? '';

        final type =
            body['type']?.toString().trim() ?? '';

        final profileId =
            body['profileId']?.toString().trim() ?? '';

        final mediaIdRaw =
            body['mediaId']?.toString().trim() ?? '';

        final String? mediaId =
            mediaIdRaw.isEmpty
                ? null
                : mediaIdRaw;

        final activeParticipants =
            _readStringSet(
          body['activeParticipants'],
        );

        if (title.isEmpty) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error': 'title is required.',
            },
          );
          return;
        }

        if (type.isEmpty) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error': 'type is required.',
            },
          );
          return;
        }

        if (type != 'movie' &&
            type != 'tvShow') {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error':
                  'type must be either "movie" or "tvShow".',
            },
          );
          return;
        }

        if (profileId.isEmpty) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error':
                  'profileId is required.',
            },
          );
          return;
        }

        final profileExists =
            account.profiles.any(
          (profile) =>
              profile.id == profileId,
        );

        if (!profileExists) {
          await _sendJson(
            request,
            HttpStatus.forbidden,
            <String, dynamic>{
              'error':
                  'This profile does not belong to the account.',
            },
          );
          return;
        }

        final dynamic durationRaw =
            body['votingDurationHours'];

        double votingDurationHours;

        if (durationRaw == null) {
          votingDurationHours = 24;
        } else if (durationRaw is num) {
          votingDurationHours =
              durationRaw.toDouble();
        } else {
          votingDurationHours =
              double.tryParse(
                    durationRaw.toString(),
                  ) ??
                  0;
        }

        if (votingDurationHours <= 0) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error':
                  'votingDurationHours must be greater than zero.',
            },
          );
          return;
        }

        final Duration votingDuration =
            Duration(
          milliseconds:
              (votingDurationHours *
                      Duration.millisecondsPerHour)
                  .round(),
        );

        if (votingDuration <=
            Duration.zero) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error':
                  'Voting duration is invalid.',
            },
          );
          return;
        }

        if (activeParticipants.isEmpty) {
          activeParticipants.addAll(
            account.profiles.map(
              (profile) => profile.id,
            ),
          );
        }

        if (activeParticipants.isEmpty) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error':
                  'At least one profile is required to vote.',
            },
          );
          return;
        }

        final allParticipantsBelongToAccount =
            activeParticipants.every(
          (participantId) =>
              account.profiles.any(
            (profile) =>
                profile.id == participantId,
          ),
        );

        if (!allParticipantsBelongToAccount) {
          await _sendJson(
            request,
            HttpStatus.forbidden,
            <String, dynamic>{
              'error':
                  'One or more active participants do not belong to the account.',
            },
          );
          return;
        }

        try {
          final recommendation =
              recommendationService
                  .createRecommendation(
            accountId: accountId,
            title: title,
            type: type,
            mediaId: mediaId,
            recommendedByProfileId:
                profileId,
            activeParticipants:
                activeParticipants,
            votingDuration:
                votingDuration,
          );

          await _sendJson(
            request,
            HttpStatus.created,
            <String, dynamic>{
              'recommendation':
                  recommendation.toJson(),
            },
          );
        } catch (error) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error':
                  error.toString(),
            },
          );
        }

        return;
      }

      // ----------------------------------------------------------
      // GET ALL RECOMMENDATIONS
      // ----------------------------------------------------------

      if (request.method == 'GET' &&
          path ==
              '/api/v1/group/recommendations') {
        final recommendations =
            recommendationService
                .getRecommendations(
          accountId: accountId,
        );

        await _sendJson(
          request,
          HttpStatus.ok,
          <String, dynamic>{
            'recommendations':
                recommendations
                    .map(
                      (recommendation) =>
                          recommendation
                              .toJson(),
                    )
                    .toList(),
          },
        );

        return;
      }

      // ----------------------------------------------------------
      // GET SHARED GROUP WISHLIST
      // ----------------------------------------------------------

      if (request.method == 'GET' &&
          path ==
              '/api/v1/group/wishlist') {
        final List<Map<String, dynamic>>
            wishlist =
            <Map<String, dynamic>>[];

        for (final mediaId
            in account.wishlistMediaIds) {
          final media =
              database.getMediaById(
            mediaId,
          );

          if (media == null) {
            wishlist.add(
              <String, dynamic>{
                'id': mediaId,
                'title': mediaId,
                'type': 'unknown',
                'source': 'media',
              },
            );
            continue;
          }

          wishlist.add(
            <String, dynamic>{
              'id': media.id,
              'title': media.title,
              'type': media.type.name,
              'releaseDate':
                  media.releaseDate
                      ?.toIso8601String(),
              'year': media.year,
              'source': 'media',
              'mediaId': media.id,
            },
          );
        }

        for (final recommendationId
            in account
                .wishlistRecommendationIds) {
          final recommendation =
              recommendationService
                  .getRecommendation(
            accountId: accountId,
            recommendationId:
                recommendationId,
          );

          if (recommendation == null) {
            continue;
          }

          if (recommendation.status !=
              GroupRecommendationStatus
                  .approved) {
            continue;
          }

          wishlist.add(
            <String, dynamic>{
              'id': recommendation.id,
              'title': recommendation.title,
              'type': recommendation.type,
              'source':
                  'recommendation',
              'recommendationId':
                  recommendation.id,
              'mediaId':
                  recommendation.mediaId,
              'recommendedByProfileId':
                  recommendation
                      .recommendedByProfileId,
              'createdAt':
                  recommendation.createdAt
                      .toIso8601String(),
              'votingEndsAt':
                  recommendation.votingEndsAt
                      .toIso8601String(),
              'yesVotes':
                  recommendation.yesVotes,
              'noVotes':
                  recommendation.noVotes,
              'yesPercentage':
                  recommendation
                      .yesPercentage,
              'noPercentage':
                  recommendation
                      .noPercentage,
            },
          );
        }

        await _sendJson(
          request,
          HttpStatus.ok,
          <String, dynamic>{
            'wishlist': wishlist,
            'count': wishlist.length,
          },
        );

        return;
      }

      // ----------------------------------------------------------
      // GET SINGLE RECOMMENDATION
      // ----------------------------------------------------------

      final recommendationPath =
          RegExp(
        r'^/api/v1/group/recommendations/([^/]+)$',
      );

      final recommendationMatch =
          recommendationPath.firstMatch(
        path,
      );

      if (request.method == 'GET' &&
          recommendationMatch != null) {
        final recommendationId =
            recommendationMatch.group(1)!;

        final recommendation =
            recommendationService
                .getRecommendation(
          accountId: accountId,
          recommendationId:
              recommendationId,
        );

        if (recommendation == null) {
          await _sendJson(
            request,
            HttpStatus.notFound,
            <String, dynamic>{
              'error':
                  'Recommendation not found.',
            },
          );
          return;
        }

        await _sendJson(
          request,
          HttpStatus.ok,
          <String, dynamic>{
            'recommendation':
                recommendation.toJson(),
          },
        );

        return;
      }

      // ----------------------------------------------------------
      // VOTE
      // ----------------------------------------------------------

      final votePath =
          RegExp(
        r'^/api/v1/group/recommendations/([^/]+)/vote$',
      );

      final voteMatch =
          votePath.firstMatch(path);

      if (request.method == 'POST' &&
          voteMatch != null) {
        final recommendationId =
            voteMatch.group(1)!;

        final body =
            await _readJsonBody(request);

        final profileId =
            body['profileId']
                    ?.toString()
                    .trim() ??
                '';

        final voteString =
            body['vote']
                    ?.toString()
                    .trim()
                    .toLowerCase() ??
                '';

        if (profileId.isEmpty) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error':
                  'profileId is required.',
            },
          );
          return;
        }

        final profileExists =
            account.profiles.any(
          (profile) =>
              profile.id == profileId,
        );

        if (!profileExists) {
          await _sendJson(
            request,
            HttpStatus.forbidden,
            <String, dynamic>{
              'error':
                  'This profile does not belong to the account.',
            },
          );
          return;
        }

        GroupRecommendationVote? vote;

        if (voteString == 'yes') {
          vote =
              GroupRecommendationVote.yes;
        } else if (voteString == 'no') {
          vote =
              GroupRecommendationVote.no;
        }

        if (vote == null) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error':
                  'vote must be either "yes" or "no".',
            },
          );
          return;
        }

        try {
          final recommendation =
              recommendationService.vote(
            accountId: accountId,
            recommendationId:
                recommendationId,
            profileId: profileId,
            vote: vote,
          );

          final bool isInWishlist =
              recommendation.mediaId != null
                  ? account.isInWishlist(
                      recommendation.mediaId!,
                    )
                  : account
                      .isRecommendationInWishlist(
                      recommendation.id,
                    );

          await _sendJson(
            request,
            HttpStatus.ok,
            <String, dynamic>{
              'recommendation':
                  recommendation.toJson(),
              'isInWishlist':
                  isInWishlist,
            },
          );
        } catch (error) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error':
                  error.toString(),
            },
          );
        }

        return;
      }

      // ----------------------------------------------------------
      // CLOSE VOTING
      // ----------------------------------------------------------

      final closePath =
          RegExp(
        r'^/api/v1/group/recommendations/([^/]+)/close$',
      );

      final closeMatch =
          closePath.firstMatch(path);

      if (request.method == 'POST' &&
          closeMatch != null) {
        final recommendationId =
            closeMatch.group(1)!;

        try {
          final recommendation =
              recommendationService
                  .closeVoting(
            accountId: accountId,
            recommendationId:
                recommendationId,
          );

          final bool isInWishlist =
              recommendation.mediaId != null
                  ? account.isInWishlist(
                      recommendation.mediaId!,
                    )
                  : account
                      .isRecommendationInWishlist(
                      recommendation.id,
                    );

          await _sendJson(
            request,
            HttpStatus.ok,
            <String, dynamic>{
              'recommendation':
                  recommendation.toJson(),
              'isInWishlist':
                  isInWishlist,
            },
          );
        } catch (error) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error':
                  error.toString(),
            },
          );
        }

        return;
      }

      // ----------------------------------------------------------
      // REMOVE ITEM FROM GROUP WISHLIST
      // ----------------------------------------------------------

      final wishlistMediaPath =
          RegExp(
        r'^/api/v1/group/wishlist/([^/]+)$',
      );

      final wishlistMediaMatch =
          wishlistMediaPath.firstMatch(path);

      if (request.method == 'DELETE' &&
          wishlistMediaMatch != null) {
        final itemId =
            wishlistMediaMatch.group(1)!;

        final removedMedia =
            account.removeFromWishlist(
          itemId,
        );

        if (removedMedia) {
          await _sendJson(
            request,
            HttpStatus.ok,
            <String, dynamic>{
              'message':
                  'Media removed from group wishlist.',
              'mediaId': itemId,
              'isInWishlist': false,
            },
          );

          return;
        }

        final removedRecommendation =
            account
                .removeRecommendationFromWishlist(
          itemId,
        );

        if (removedRecommendation) {
          await _sendJson(
            request,
            HttpStatus.ok,
            <String, dynamic>{
              'message':
                  'Recommendation removed from group wishlist.',
              'recommendationId':
                  itemId,
              'isInWishlist': false,
            },
          );

          return;
        }

        await _sendJson(
          request,
          HttpStatus.notFound,
          <String, dynamic>{
            'error':
                'Item is not in the group wishlist.',
          },
        );

        return;
      }

      // ----------------------------------------------------------
      // MARK WISHLIST ITEM AS ACQUIRED
      // ----------------------------------------------------------

      final acquirePath =
          RegExp(
        r'^/api/v1/group/wishlist/([^/]+)/acquire$',
      );

      final acquireMatch =
          acquirePath.firstMatch(path);

      if (request.method == 'POST' &&
          acquireMatch != null) {
        final itemId =
            acquireMatch.group(1)!;

        final body =
            await _readJsonBody(request);

        final profileId =
            body['profileId']
                    ?.toString()
                    .trim() ??
                '';

        if (profileId.isEmpty) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error':
                  'profileId is required.',
            },
          );
          return;
        }

        final profile =
            account.getProfileById(
          profileId,
        );

        if (profile == null) {
          await _sendJson(
            request,
            HttpStatus.forbidden,
            <String, dynamic>{
              'error':
                  'This profile does not belong to the account.',
            },
          );
          return;
        }

        if (account.isInWishlist(
          itemId,
        )) {
          final media =
              database.getMediaById(
            itemId,
          );

          if (media == null) {
            await _sendJson(
              request,
              HttpStatus.notFound,
              <String, dynamic>{
                'error':
                    'Media not found.',
              },
            );
            return;
          }

          final acquired =
              account.markWishlistItemAcquired(
            itemId,
            profileId: profileId,
          );

          if (!acquired) {
            await _sendJson(
              request,
              HttpStatus.badRequest,
              <String, dynamic>{
                'error':
                    'Unable to acquire wishlist item.',
              },
            );
            return;
          }

          await _sendJson(
            request,
            HttpStatus.ok,
            <String, dynamic>{
              'message':
                  'Media acquired and added to the selected profile library.',
              'mediaId': itemId,
              'profileId': profileId,
              'isInWishlist':
                  account.isInWishlist(
                itemId,
              ),
              'isOwned':
                  profile.ownsMedia(
                itemId,
              ),
            },
          );

          return;
        }

        if (account
            .isRecommendationInWishlist(
          itemId,
        )) {
          final recommendation =
              recommendationService
                  .getRecommendation(
            accountId: accountId,
            recommendationId: itemId,
          );

          if (recommendation == null) {
            await _sendJson(
              request,
              HttpStatus.notFound,
              <String, dynamic>{
                'error':
                    'Recommendation not found.',
              },
            );
            return;
          }

          final removed = account
              .removeRecommendationFromWishlist(
            itemId,
          );

          if (!removed) {
            await _sendJson(
              request,
              HttpStatus.badRequest,
              <String, dynamic>{
                'error':
                    'Unable to acquire recommendation.',
              },
            );
            return;
          }

          await _sendJson(
            request,
            HttpStatus.ok,
            <String, dynamic>{
              'message':
                  'Recommendation acquired and removed from the group wishlist.',
              'recommendationId':
                  recommendation.id,
              'title':
                  recommendation.title,
              'type':
                  recommendation.type,
              'profileId':
                  profileId,
              'isInWishlist':
                  account
                      .isRecommendationInWishlist(
                recommendation.id,
              ),
              'isOwned':
                  false,
              'catalogMedia':
                  false,
            },
          );

          return;
        }

        await _sendJson(
          request,
          HttpStatus.notFound,
          <String, dynamic>{
            'error':
                'Item is not in the group wishlist.',
          },
        );

        return;
      }

      // ----------------------------------------------------------
      // DELETE RECOMMENDATION
      // ----------------------------------------------------------

      if (request.method == 'DELETE' &&
          recommendationMatch != null) {
        final recommendationId =
            recommendationMatch.group(1)!;

        try {
          recommendationService
              .deleteRecommendation(
            accountId: accountId,
            recommendationId:
                recommendationId,
          );

          account
              .removeRecommendationFromWishlist(
            recommendationId,
          );

          await _sendJson(
            request,
            HttpStatus.ok,
            <String, dynamic>{
              'message':
                  'Recommendation deleted.',
            },
          );
        } catch (error) {
          await _sendJson(
            request,
            HttpStatus.notFound,
            <String, dynamic>{
              'error':
                  error.toString(),
            },
          );
        }

        return;
      }

      // ----------------------------------------------------------
      // ROUTE NOT FOUND
      // ----------------------------------------------------------

      await _sendJson(
        request,
        HttpStatus.notFound,
        <String, dynamic>{
          'error':
              'Group route not found.',
        },
      );
    } catch (error) {
      await _sendJson(
        request,
        HttpStatus.internalServerError,
        <String, dynamic>{
          'error': error.toString(),
        },
      );
    }
  }

  // ============================================================
  // GROUP WATCH AUTHORIZATION HELPERS
  // ============================================================

  /// Determines whether an account can see/interact with a
  /// Group Watch session.
  ///
  /// The account is allowed when:
  ///
  /// 1. It is the account that created the session, OR
  /// 2. One of its profiles is a participant in the session.
  ///
  /// This is what allows:
  ///
  /// Account A
  ///   Cesar
  ///   Alex
  ///
  /// to host a session and invite:
  ///
  /// Account B
  ///   John
  ///
  /// without giving Account B access to unrelated sessions.
  bool _sessionVisibleToAccount(
    GroupWatchSession session,
    String accountId,
  ) {
    final cleanAccountId =
        accountId.trim();

    if (cleanAccountId.isEmpty) {
      return false;
    }

    if (session.accountId ==
        cleanAccountId) {
      return true;
    }

    return session.participants.values.any(
      (participant) =>
          participant.accountId ==
          cleanAccountId,
    );
  }

  /// Verifies that the profile being used by the request belongs
  /// to the authenticated account.
  bool _profileBelongsToAccount(
    String profileId,
    String accountId,
  ) {
    return database.profileBelongsToAccount(
      profileId,
      accountId,
    );
  }

  // ============================================================
  // JSON BODY
  // ============================================================

  Future<Map<String, dynamic>> _readJsonBody(
    HttpRequest request,
  ) async {
    final body =
        await utf8.decoder
            .bind(request)
            .join();

    if (body.trim().isEmpty) {
      return <String, dynamic>{};
    }

    final decoded =
        jsonDecode(body);

    if (decoded is! Map) {
      throw FormatException(
        'Request body must be a JSON object.',
      );
    }

    return Map<String, dynamic>.from(
      decoded,
    );
  }

  // ============================================================
  // STRING SET
  // ============================================================

  Set<String> _readStringSet(
    dynamic value,
  ) {
    if (value is! List) {
      return <String>{};
    }

    return value
        .map(
          (item) =>
              item.toString().trim(),
        )
        .where(
          (item) => item.isNotEmpty,
        )
        .toSet();
  }

  // ============================================================
  // INTEGER
  // ============================================================

  int? _readInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value.toString(),
    );
  }

  // ============================================================
  // DOUBLE
  // ============================================================

  double? _readDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString(),
    );
  }

  // ============================================================
  // JSON RESPONSE
  // ============================================================

  Future<void> _sendJson(
    HttpRequest request,
    int statusCode,
    Map<String, dynamic> body,
  ) async {
    request.response.statusCode =
        statusCode;

    request.response.headers.contentType =
        ContentType.json;

    request.response.write(
      jsonEncode(body),
    );

    await request.response.close();
  }
}