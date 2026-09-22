// FILE: `Backend/routes/group_routes.dart`.
// Purpose: Implements the group routes portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.
//
// Supported areas:
// - Cross-account group chat.
// - Cross-account Group Watch sessions.
// - Group Watch invitations and playback controls.
// - Group recommendation voting.
// - Shared group wishlist.
// - Wishlist acquisition.
//
// Security notes:
// - Every non-preflight route requires an authenticated account.
// - Profile IDs are always validated against the authenticated account.
// - Group Watch visibility is restricted to the hosting account or an
//   account represented by a participant profile.
// - Recommendation operations are scoped to the authenticated account.
// - No credentials or bearer tokens are logged by this route layer.

import 'dart:convert';
import 'dart:io';

import '../database/database.dart';
import '../middleware/authentication.dart';
import '../models/group_chat_room.dart';
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

  /// Handles all group-related API routes.
  Future<void> handle(HttpRequest request) async {
    try {
      if (request.method == 'OPTIONS') {
        await _sendJson(
          request,
          HttpStatus.noContent,
          <String, dynamic>{},
        );
        return;
      }

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
      final accountId = account.id.trim();
      final path = request.uri.path;

      if (accountId.isEmpty) {
        await _sendJson(
          request,
          HttpStatus.unauthorized,
          <String, dynamic>{
            'error': 'Authenticated account is invalid.',
          },
        );
        return;
      }

      // ==========================================================
      // CROSS-ACCOUNT GROUP CHAT
      // ==========================================================

      if (request.method == 'POST' &&
          path == '/api/v1/group/chat') {
        await _createChatRoom(
          request,
          account,
          accountId,
        );
        return;
      }

      if (request.method == 'GET' &&
          path == '/api/v1/group/chat') {
        final rooms = database.groupChatRoomsById.values
            .where(
              (room) => room.members.any(
                (member) => member.accountId == accountId,
              ),
            )
            .map((room) => room.toJson())
            .toList();

        await _sendJson(
          request,
          HttpStatus.ok,
          <String, dynamic>{
            'rooms': rooms,
          },
        );
        return;
      }

      final chatMessageMatch = RegExp(
        r'^/api/v1/group/chat/([^/]+)/messages$',
      ).firstMatch(path);

      if (chatMessageMatch != null) {
        final roomId = Uri.decodeComponent(
          chatMessageMatch.group(1)!,
        );

        final room = database.groupChatRoomsById[roomId];

        if (room == null ||
            !_chatRoomVisibleToAccount(
              room,
              accountId,
            )) {
          await _sendJson(
            request,
            HttpStatus.notFound,
            <String, dynamic>{
              'error': 'Group chat room not found.',
            },
          );
          return;
        }

        if (request.method == 'GET') {
          await _sendJson(
            request,
            HttpStatus.ok,
            <String, dynamic>{
              'room': room.toJson(),
            },
          );
          return;
        }

        if (request.method == 'POST') {
          await _sendChatMessage(
            request,
            room,
            accountId,
          );
          return;
        }
      }

      // ==========================================================
      // GROUP WATCH
      // ==========================================================

      if (request.method == 'POST' &&
          path == '/api/v1/group/watch') {
        await _createGroupWatchSession(
          request,
          account,
          accountId,
        );
        return;
      }

      if (request.method == 'GET' &&
          path == '/api/v1/group/watch') {
        final sessions =
            watchService.getSessionsForAccount(accountId);

        for (final session in sessions) {
          database.saveGroupWatchSession(session);
        }

        await _sendJson(
          request,
          HttpStatus.ok,
          <String, dynamic>{
            'sessions': sessions
                .map((session) => session.toJson())
                .toList(),
          },
        );
        return;
      }

      final groupWatchMatch = RegExp(
        r'^/api/v1/group/watch/([^/]+)$',
      ).firstMatch(path);

      if (request.method == 'GET' &&
          groupWatchMatch != null) {
        final sessionId = Uri.decodeComponent(
          groupWatchMatch.group(1)!,
        );

        final session = watchService.getSession(sessionId);

        if (session == null ||
            !_sessionVisibleToAccount(
              session,
              accountId,
            )) {
          await _sendJson(
            request,
            HttpStatus.notFound,
            <String, dynamic>{
              'error': 'Group Watch session not found.',
            },
          );
          return;
        }

        database.saveGroupWatchSession(session);

        await _sendJson(
          request,
          HttpStatus.ok,
          <String, dynamic>{
            'session': session.toJson(),
          },
        );
        return;
      }

      if (request.method == 'DELETE' &&
          groupWatchMatch != null) {
        await _deleteGroupWatchSession(
          request,
          accountId,
          Uri.decodeComponent(
            groupWatchMatch.group(1)!,
          ),
        );
        return;
      }

      final groupWatchAcceptMatch = RegExp(
        r'^/api/v1/group/watch/([^/]+)/accept$',
      ).firstMatch(path);

      if (request.method == 'POST' &&
          groupWatchAcceptMatch != null) {
        await _acceptGroupWatchInvitation(
          request,
          accountId,
          Uri.decodeComponent(
            groupWatchAcceptMatch.group(1)!,
          ),
        );
        return;
      }

      final groupWatchDeclineMatch = RegExp(
        r'^/api/v1/group/watch/([^/]+)/decline$',
      ).firstMatch(path);

      if (request.method == 'POST' &&
          groupWatchDeclineMatch != null) {
        await _declineGroupWatchInvitation(
          request,
          accountId,
          Uri.decodeComponent(
            groupWatchDeclineMatch.group(1)!,
          ),
        );
        return;
      }

      final groupWatchAudioMatch = RegExp(
        r'^/api/v1/group/watch/([^/]+)/audio$',
      ).firstMatch(path);

      if (request.method == 'POST' &&
          groupWatchAudioMatch != null) {
        await _setGroupWatchAudio(
          request,
          accountId,
          Uri.decodeComponent(
            groupWatchAudioMatch.group(1)!,
          ),
        );
        return;
      }

      final groupWatchSubtitleMatch = RegExp(
        r'^/api/v1/group/watch/([^/]+)/subtitles$',
      ).firstMatch(path);

      if (request.method == 'POST' &&
          groupWatchSubtitleMatch != null) {
        await _setGroupWatchSubtitle(
          request,
          accountId,
          Uri.decodeComponent(
            groupWatchSubtitleMatch.group(1)!,
          ),
        );
        return;
      }

      final groupWatchStartMatch = RegExp(
        r'^/api/v1/group/watch/([^/]+)/start$',
      ).firstMatch(path);

      if (request.method == 'POST' &&
          groupWatchStartMatch != null) {
        await _startGroupWatch(
          request,
          accountId,
          Uri.decodeComponent(
            groupWatchStartMatch.group(1)!,
          ),
        );
        return;
      }

      final groupWatchPlayMatch = RegExp(
        r'^/api/v1/group/watch/([^/]+)/play$',
      ).firstMatch(path);

      if (request.method == 'POST' &&
          groupWatchPlayMatch != null) {
        await _playGroupWatch(
          request,
          accountId,
          Uri.decodeComponent(
            groupWatchPlayMatch.group(1)!,
          ),
        );
        return;
      }

      final groupWatchPauseMatch = RegExp(
        r'^/api/v1/group/watch/([^/]+)/pause$',
      ).firstMatch(path);

      if (request.method == 'POST' &&
          groupWatchPauseMatch != null) {
        await _pauseGroupWatch(
          request,
          accountId,
          Uri.decodeComponent(
            groupWatchPauseMatch.group(1)!,
          ),
        );
        return;
      }

      final groupWatchResumeMatch = RegExp(
        r'^/api/v1/group/watch/([^/]+)/resume$',
      ).firstMatch(path);

      if (request.method == 'POST' &&
          groupWatchResumeMatch != null) {
        await _resumeGroupWatch(
          request,
          accountId,
          Uri.decodeComponent(
            groupWatchResumeMatch.group(1)!,
          ),
        );
        return;
      }

      final groupWatchPositionMatch = RegExp(
        r'^/api/v1/group/watch/([^/]+)/position$',
      ).firstMatch(path);

      if (request.method == 'POST' &&
          groupWatchPositionMatch != null) {
        await _updateGroupWatchPosition(
          request,
          accountId,
          Uri.decodeComponent(
            groupWatchPositionMatch.group(1)!,
          ),
        );
        return;
      }

      final groupWatchEndMatch = RegExp(
        r'^/api/v1/group/watch/([^/]+)/end$',
      ).firstMatch(path);

      if (request.method == 'POST' &&
          groupWatchEndMatch != null) {
        await _endGroupWatch(
          request,
          accountId,
          Uri.decodeComponent(
            groupWatchEndMatch.group(1)!,
          ),
        );
        return;
      }

      // ==========================================================
      // GROUP RECOMMENDATIONS
      // ==========================================================

      if (request.method == 'POST' &&
          path == '/api/v1/group/recommendations') {
        await _createRecommendation(
          request,
          account,
          accountId,
        );
        return;
      }

      if (request.method == 'GET' &&
          path == '/api/v1/group/recommendations') {
        final recommendations =
            recommendationService.getRecommendations(
          accountId: accountId,
        );

        await _sendJson(
          request,
          HttpStatus.ok,
          <String, dynamic>{
            'recommendations': recommendations
                .map(
                  (recommendation) => recommendation.toJson(),
                )
                .toList(),
          },
        );
        return;
      }

      if (request.method == 'GET' &&
          path == '/api/v1/group/wishlist') {
        await _getWishlist(
          request,
          account,
          accountId,
        );
        return;
      }

      final recommendationMatch = RegExp(
        r'^/api/v1/group/recommendations/([^/]+)$',
      ).firstMatch(path);

      if (request.method == 'GET' &&
          recommendationMatch != null) {
        final recommendationId = Uri.decodeComponent(
          recommendationMatch.group(1)!,
        );

        final recommendation =
            recommendationService.getRecommendation(
          accountId: accountId,
          recommendationId: recommendationId,
        );

        if (recommendation == null) {
          await _sendJson(
            request,
            HttpStatus.notFound,
            <String, dynamic>{
              'error': 'Recommendation not found.',
            },
          );
          return;
        }

        await _sendJson(
          request,
          HttpStatus.ok,
          <String, dynamic>{
            'recommendation': recommendation.toJson(),
          },
        );
        return;
      }

      final voteMatch = RegExp(
        r'^/api/v1/group/recommendations/([^/]+)/vote$',
      ).firstMatch(path);

      if (request.method == 'POST' &&
          voteMatch != null) {
        await _voteRecommendation(
          request,
          account,
          accountId,
          Uri.decodeComponent(
            voteMatch.group(1)!,
          ),
        );
        return;
      }

      final closeMatch = RegExp(
        r'^/api/v1/group/recommendations/([^/]+)/close$',
      ).firstMatch(path);

      if (request.method == 'POST' &&
          closeMatch != null) {
        await _closeRecommendation(
          request,
          account,
          accountId,
          Uri.decodeComponent(
            closeMatch.group(1)!,
          ),
        );
        return;
      }

      if (request.method == 'DELETE' &&
          recommendationMatch != null) {
        await _deleteRecommendation(
          request,
          account,
          accountId,
          Uri.decodeComponent(
            recommendationMatch.group(1)!,
          ),
        );
        return;
      }

      // ==========================================================
      // GROUP WISHLIST
      // ==========================================================

      final wishlistItemMatch = RegExp(
        r'^/api/v1/group/wishlist/([^/]+)$',
      ).firstMatch(path);

      if (request.method == 'DELETE' &&
          wishlistItemMatch != null) {
        await _removeWishlistItem(
          request,
          account,
          Uri.decodeComponent(
            wishlistItemMatch.group(1)!,
          ),
        );
        return;
      }

      final acquireMatch = RegExp(
        r'^/api/v1/group/wishlist/([^/]+)/acquire$',
      ).firstMatch(path);

      if (request.method == 'POST' &&
          acquireMatch != null) {
        await _acquireWishlistItem(
          request,
          account,
          accountId,
          Uri.decodeComponent(
            acquireMatch.group(1)!,
          ),
        );
        return;
      }

      // ==========================================================
      // ROUTE NOT FOUND
      // ==========================================================

      await _sendJson(
        request,
        HttpStatus.notFound,
        <String, dynamic>{
          'error': 'Group route not found.',
        },
      );
    } on FormatException catch (error) {
      await _sendJson(
        request,
        HttpStatus.badRequest,
        <String, dynamic>{
          'error': error.message,
        },
      );
    } catch (error) {
      await _sendJson(
        request,
        HttpStatus.internalServerError,
        <String, dynamic>{
          'error': _safeErrorMessage(error),
        },
      );
    }
  }

  // ============================================================
  // GROUP CHAT
  // ============================================================

  Future<void> _createChatRoom(
    HttpRequest request,
    dynamic account,
    String accountId,
  ) async {
    final body = await _readJsonBody(request);

    final name = _readString(body['name']);
    final profileId = _readString(body['profileId']);
    final invites = _readStringSet(body['invitedProfiles']);

    if (name.isEmpty || profileId.isEmpty) {
      await _sendJson(
        request,
        HttpStatus.badRequest,
        <String, dynamic>{
          'error': 'name and profileId are required.',
        },
      );
      return;
    }

    final host = account.getProfileById(profileId);

    if (host == null) {
      await _sendJson(
        request,
        HttpStatus.forbidden,
        <String, dynamic>{
          'error': 'This profile does not belong to the account.',
        },
      );
      return;
    }

    final members = <GroupChatMember>[
      GroupChatMember(
        profileId: host.id,
        profileName: host.name,
        username: account.username,
        accountId: accountId,
      ),
    ];

    final existingMemberIds = <String>{host.id};

    for (final identifier in invites) {
      final target =
          database.getAccountByUsername(identifier) ??
          database.getAccountByEmail(identifier);

      if (target == null) {
        continue;
      }

      for (final profile in target.profiles) {
        if (existingMemberIds.contains(profile.id)) {
          continue;
        }

        members.add(
          GroupChatMember(
            profileId: profile.id,
            profileName: profile.name,
            username: target.username,
            accountId: target.id,
          ),
        );

        existingMemberIds.add(profile.id);
        break;
      }
    }

    final now = DateTime.now();

    final room = GroupChatRoom(
      id: 'chat_${now.microsecondsSinceEpoch}',
      name: name,
      ownerAccountId: accountId,
      members: members,
      messages: <GroupChatMessage>[],
      createdAt: now,
    );

    database.groupChatRoomsById[room.id] = room;

    await _sendJson(
      request,
      HttpStatus.created,
      <String, dynamic>{
        'room': room.toJson(),
      },
    );
  }

  Future<void> _sendChatMessage(
    HttpRequest request,
    GroupChatRoom room,
    String accountId,
  ) async {
    final body = await _readJsonBody(request);

    final profileId = _readString(body['profileId']);
    final message = _readString(body['message']);
    final badgeName = _readOptionalString(body['badgeName']);

    if (profileId.isEmpty || message.isEmpty) {
      await _sendJson(
        request,
        HttpStatus.badRequest,
        <String, dynamic>{
          'error':
              'A valid profileId and non-empty message are required.',
        },
      );
      return;
    }

    final member = _findChatMember(
      room,
      profileId,
      accountId,
    );

    if (member == null) {
      await _sendJson(
        request,
        HttpStatus.forbidden,
        <String, dynamic>{
          'error': 'This profile is not a member of the group chat.',
        },
      );
      return;
    }

    final chatMessage = GroupChatMessage(
      id: 'msg_${DateTime.now().microsecondsSinceEpoch}',
      profileId: profileId,
      senderName: member.profileName,
      message: message,
      timestamp: DateTime.now(),
      badgeName: badgeName,
    );

    room.messages.add(chatMessage);

    if (room.messages.length > 500) {
      room.messages.removeRange(
        0,
        room.messages.length - 500,
      );
    }

    await _sendJson(
      request,
      HttpStatus.created,
      <String, dynamic>{
        'message': chatMessage.toJson(),
      },
    );
  }

  // ============================================================
  // GROUP WATCH
  // ============================================================

  Future<void> _createGroupWatchSession(
    HttpRequest request,
    dynamic account,
    String accountId,
  ) async {
    final body = await _readJsonBody(request);

    final mediaId = _readString(body['mediaId']);
    final title = _readString(body['title']);
    final type = _readString(body['type']);
    final profileId = _readString(body['profileId']);

    final invitedProfileIds = _readStringSet(
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
          'error': 'type must be either "movie" or "tvShow".',
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

    final hostProfile = account.getProfileById(profileId);

    if (hostProfile == null) {
      await _sendJson(
        request,
        HttpStatus.forbidden,
        <String, dynamic>{
          'error': 'This profile does not belong to the account.',
        },
      );
      return;
    }

    final media = database.getMediaById(mediaId);

    if (media == null) {
      await _sendJson(
        request,
        HttpStatus.notFound,
        <String, dynamic>{
          'error': 'Selected media was not found.',
        },
      );
      return;
    }

    invitedProfileIds.remove(profileId);

    final invitationDurationHours =
        _readPositiveDurationHours(
      body['invitationDurationHours'],
      defaultHours: 24,
    );

    if (invitationDurationHours == null) {
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

    final invitationDuration = Duration(
      milliseconds:
          (invitationDurationHours *
                  Duration.millisecondsPerHour)
              .round(),
    );

    try {
      final session = watchService.createSession(
        accountId: accountId,
        hostProfileId: profileId,
        mediaId: mediaId,
        title: title,
        type: type,
        invitedProfileIds: invitedProfileIds,
        invitationDuration: invitationDuration,
      );

      database.saveGroupWatchSession(session);

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
          'error': _safeErrorMessage(error),
        },
      );
    }
  }

  Future<void> _acceptGroupWatchInvitation(
    HttpRequest request,
    String accountId,
    String sessionId,
  ) async {
    final body = await _readJsonBody(request);
    final profileId = _readString(body['profileId']);

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

    if (!_profileBelongsToAccount(profileId, accountId)) {
      await _sendJson(
        request,
        HttpStatus.forbidden,
        <String, dynamic>{
          'error': 'This profile does not belong to the account.',
        },
      );
      return;
    }

    if (!_visibleSessionExists(sessionId, accountId)) {
      await _sendJson(
        request,
        HttpStatus.notFound,
        <String, dynamic>{
          'error': 'Group Watch session not found.',
        },
      );
      return;
    }

    try {
      final session = watchService.acceptInvitation(
        sessionId: sessionId,
        profileId: profileId,
      );

      database.saveGroupWatchSession(session);

      await _sendJson(
        request,
        HttpStatus.ok,
        <String, dynamic>{
          'session': session.toJson(),
          'message': 'Group Watch invitation accepted.',
        },
      );
    } catch (error) {
      await _sendGroupWatchMutationError(
        request,
        error,
      );
    }
  }

  Future<void> _declineGroupWatchInvitation(
    HttpRequest request,
    String accountId,
    String sessionId,
  ) async {
    final body = await _readJsonBody(request);
    final profileId = _readString(body['profileId']);

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

    if (!_profileBelongsToAccount(profileId, accountId)) {
      await _sendJson(
        request,
        HttpStatus.forbidden,
        <String, dynamic>{
          'error': 'This profile does not belong to the account.',
        },
      );
      return;
    }

    if (!_visibleSessionExists(sessionId, accountId)) {
      await _sendJson(
        request,
        HttpStatus.notFound,
        <String, dynamic>{
          'error': 'Group Watch session not found.',
        },
      );
      return;
    }

    try {
      final session = watchService.declineInvitation(
        sessionId: sessionId,
        profileId: profileId,
      );

      database.saveGroupWatchSession(session);

      await _sendJson(
        request,
        HttpStatus.ok,
        <String, dynamic>{
          'session': session.toJson(),
          'message': 'Group Watch invitation declined.',
        },
      );
    } catch (error) {
      await _sendGroupWatchMutationError(
        request,
        error,
      );
    }
  }

  Future<void> _setGroupWatchAudio(
    HttpRequest request,
    String accountId,
    String sessionId,
  ) async {
    final body = await _readJsonBody(request);
    final profileId = _readString(body['profileId']);
    final audioTrackId = _readOptionalString(
      body['audioTrackId'],
    );

    if (!await _validateSessionMutationRequest(
      request,
      accountId,
      sessionId,
      profileId,
    )) {
      return;
    }

    try {
      final session = watchService.setAudioTrack(
        sessionId: sessionId,
        profileId: profileId,
        audioTrackId: audioTrackId,
      );

      database.saveGroupWatchSession(session);

      await _sendJson(
        request,
        HttpStatus.ok,
        <String, dynamic>{
          'session': session.toJson(),
        },
      );
    } catch (error) {
      await _sendGroupWatchMutationError(
        request,
        error,
      );
    }
  }

  Future<void> _setGroupWatchSubtitle(
    HttpRequest request,
    String accountId,
    String sessionId,
  ) async {
    final body = await _readJsonBody(request);
    final profileId = _readString(body['profileId']);
    final subtitleTrackId = _readOptionalString(
      body['subtitleTrackId'],
    );

    if (!await _validateSessionMutationRequest(
      request,
      accountId,
      sessionId,
      profileId,
    )) {
      return;
    }

    try {
      final session = watchService.setSubtitleTrack(
        sessionId: sessionId,
        profileId: profileId,
        subtitleTrackId: subtitleTrackId,
      );

      database.saveGroupWatchSession(session);

      await _sendJson(
        request,
        HttpStatus.ok,
        <String, dynamic>{
          'session': session.toJson(),
        },
      );
    } catch (error) {
      await _sendGroupWatchMutationError(
        request,
        error,
      );
    }
  }

  Future<void> _startGroupWatch(
    HttpRequest request,
    String accountId,
    String sessionId,
  ) async {
    final body = await _readJsonBody(request);
    final profileId = _readString(body['profileId']);

    if (!await _validateSessionMutationRequest(
      request,
      accountId,
      sessionId,
      profileId,
    )) {
      return;
    }

    try {
      final session = watchService.startSession(
        sessionId: sessionId,
        profileId: profileId,
      );

      database.saveGroupWatchSession(session);

      await _sendJson(
        request,
        HttpStatus.ok,
        <String, dynamic>{
          'session': session.toJson(),
          'message': 'Group Watch started.',
        },
      );
    } catch (error) {
      await _sendGroupWatchMutationError(
        request,
        error,
      );
    }
  }

  Future<void> _playGroupWatch(
    HttpRequest request,
    String accountId,
    String sessionId,
  ) async {
    final body = await _readJsonBody(request);
    final profileId = _readString(body['profileId']);

    if (!await _validateSessionMutationRequest(
      request,
      accountId,
      sessionId,
      profileId,
    )) {
      return;
    }

    try {
      final session = watchService.play(
        sessionId: sessionId,
        profileId: profileId,
      );

      database.saveGroupWatchSession(session);

      await _sendJson(
        request,
        HttpStatus.ok,
        <String, dynamic>{
          'session': session.toJson(),
        },
      );
    } catch (error) {
      await _sendGroupWatchMutationError(
        request,
        error,
      );
    }
  }

  Future<void> _pauseGroupWatch(
    HttpRequest request,
    String accountId,
    String sessionId,
  ) async {
    final body = await _readJsonBody(request);
    final profileId = _readString(body['profileId']);
    final reason = _readString(body['reason']);

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

    if (reason.isEmpty) {
      await _sendJson(
        request,
        HttpStatus.badRequest,
        <String, dynamic>{
          'error': 'reason is required.',
        },
      );
      return;
    }

    if (!_profileBelongsToAccount(profileId, accountId)) {
      await _sendJson(
        request,
        HttpStatus.forbidden,
        <String, dynamic>{
          'error': 'This profile does not belong to the account.',
        },
      );
      return;
    }

    if (!_visibleSessionExists(sessionId, accountId)) {
      await _sendJson(
        request,
        HttpStatus.notFound,
        <String, dynamic>{
          'error': 'Group Watch session not found.',
        },
      );
      return;
    }

    try {
      final session = watchService.pause(
        sessionId: sessionId,
        profileId: profileId,
        reason: reason,
      );

      database.saveGroupWatchSession(session);

      await _sendJson(
        request,
        HttpStatus.ok,
        <String, dynamic>{
          'session': session.toJson(),
          'message': 'Group Watch paused.',
        },
      );
    } catch (error) {
      await _sendGroupWatchMutationError(
        request,
        error,
      );
    }
  }

  Future<void> _resumeGroupWatch(
    HttpRequest request,
    String accountId,
    String sessionId,
  ) async {
    final body = await _readJsonBody(request);
    final profileId = _readString(body['profileId']);

    if (!await _validateSessionMutationRequest(
      request,
      accountId,
      sessionId,
      profileId,
    )) {
      return;
    }

    try {
      final session = watchService.resume(
        sessionId: sessionId,
        profileId: profileId,
      );

      database.saveGroupWatchSession(session);

      await _sendJson(
        request,
        HttpStatus.ok,
        <String, dynamic>{
          'session': session.toJson(),
          'message': 'Group Watch resumed.',
        },
      );
    } catch (error) {
      await _sendGroupWatchMutationError(
        request,
        error,
      );
    }
  }

  Future<void> _updateGroupWatchPosition(
    HttpRequest request,
    String accountId,
    String sessionId,
  ) async {
    final body = await _readJsonBody(request);
    final profileId = _readString(body['profileId']);

    final millisecondsRaw = body['positionMilliseconds'];
    final secondsRaw = body['positionSeconds'];

    int? positionMilliseconds;

    if (millisecondsRaw != null) {
      positionMilliseconds = _readInt(millisecondsRaw);
    } else if (secondsRaw != null) {
      final seconds = _readDouble(secondsRaw);

      if (seconds != null && seconds.isFinite) {
        positionMilliseconds = (seconds * 1000).round();
      }
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

    if (!_profileBelongsToAccount(profileId, accountId)) {
      await _sendJson(
        request,
        HttpStatus.forbidden,
        <String, dynamic>{
          'error': 'This profile does not belong to the account.',
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

    if (!_visibleSessionExists(sessionId, accountId)) {
      await _sendJson(
        request,
        HttpStatus.notFound,
        <String, dynamic>{
          'error': 'Group Watch session not found.',
        },
      );
      return;
    }

    try {
      final session = watchService.updatePlaybackPosition(
        sessionId: sessionId,
        profileId: profileId,
        position: Duration(
          milliseconds: positionMilliseconds,
        ),
      );

      database.saveGroupWatchSession(session);

      await _sendJson(
        request,
        HttpStatus.ok,
        <String, dynamic>{
          'session': session.toJson(),
          'playbackPositionMilliseconds':
              session.playbackPosition.inMilliseconds,
        },
      );
    } catch (error) {
      await _sendGroupWatchMutationError(
        request,
        error,
      );
    }
  }

  Future<void> _endGroupWatch(
    HttpRequest request,
    String accountId,
    String sessionId,
  ) async {
    final body = await _readJsonBody(request);
    final profileId = _readString(body['profileId']);

    if (!await _validateSessionMutationRequest(
      request,
      accountId,
      sessionId,
      profileId,
    )) {
      return;
    }

    try {
      final session = watchService.endSession(
        sessionId: sessionId,
        profileId: profileId,
      );

      database.saveGroupWatchSession(session);

      await _sendJson(
        request,
        HttpStatus.ok,
        <String, dynamic>{
          'session': session.toJson(),
          'message': 'Group Watch ended.',
        },
      );
    } catch (error) {
      await _sendGroupWatchMutationError(
        request,
        error,
      );
    }
  }

  Future<void> _deleteGroupWatchSession(
    HttpRequest request,
    String accountId,
    String sessionId,
  ) async {
    final body = await _readJsonBody(request);
    final profileId = _readString(body['profileId']);

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

    if (!_profileBelongsToAccount(profileId, accountId)) {
      await _sendJson(
        request,
        HttpStatus.forbidden,
        <String, dynamic>{
          'error': 'This profile does not belong to the account.',
        },
      );
      return;
    }

    final session = watchService.getSession(sessionId);

    if (session == null ||
        !_sessionVisibleToAccount(
          session,
          accountId,
        )) {
      await _sendJson(
        request,
        HttpStatus.notFound,
        <String, dynamic>{
          'error': 'Group Watch session not found.',
        },
      );
      return;
    }

    try {
      watchService.deleteSession(
        sessionId: sessionId,
        profileId: profileId,
      );

      database.deleteGroupWatchSession(sessionId);

      await _sendJson(
        request,
        HttpStatus.ok,
        <String, dynamic>{
          'message': 'Group Watch session deleted.',
        },
      );
    } catch (error) {
      await _sendGroupWatchMutationError(
        request,
        error,
      );
    }
  }

  // ============================================================
  // GROUP RECOMMENDATIONS
  // ============================================================

  Future<void> _createRecommendation(
    HttpRequest request,
    dynamic account,
    String accountId,
  ) async {
    final body = await _readJsonBody(request);

    final title = _readString(body['title']);
    final type = _readString(body['type']);
    final profileId = _readString(body['profileId']);
    final mediaIdRaw = _readString(body['mediaId']);

    final String? mediaId =
        mediaIdRaw.isEmpty ? null : mediaIdRaw;

    final activeParticipants = _readStringSet(
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

    if (type != 'movie' && type != 'tvShow') {
      await _sendJson(
        request,
        HttpStatus.badRequest,
        <String, dynamic>{
          'error': 'type must be either "movie" or "tvShow".',
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

    if (account.getProfileById(profileId) == null) {
      await _sendJson(
        request,
        HttpStatus.forbidden,
        <String, dynamic>{
          'error': 'This profile does not belong to the account.',
        },
      );
      return;
    }

    final votingDurationHours =
        _readPositiveDurationHours(
      body['votingDurationHours'],
      defaultHours: 24,
    );

    if (votingDurationHours == null) {
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

    final votingDuration = Duration(
      milliseconds:
          (votingDurationHours *
                  Duration.millisecondsPerHour)
              .round(),
    );

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
          account.getProfileById(participantId) != null,
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
          recommendationService.createRecommendation(
        accountId: accountId,
        title: title,
        type: type,
        mediaId: mediaId,
        recommendedByProfileId: profileId,
        activeParticipants: activeParticipants,
        votingDuration: votingDuration,
      );

      await _sendJson(
        request,
        HttpStatus.created,
        <String, dynamic>{
          'recommendation': recommendation.toJson(),
        },
      );
    } catch (error) {
      await _sendJson(
        request,
        HttpStatus.badRequest,
        <String, dynamic>{
          'error': _safeErrorMessage(error),
        },
      );
    }
  }

  Future<void> _voteRecommendation(
    HttpRequest request,
    dynamic account,
    String accountId,
    String recommendationId,
  ) async {
    final body = await _readJsonBody(request);

    final profileId = _readString(body['profileId']);
    final voteString =
        _readString(body['vote']).toLowerCase();

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

    if (account.getProfileById(profileId) == null) {
      await _sendJson(
        request,
        HttpStatus.forbidden,
        <String, dynamic>{
          'error': 'This profile does not belong to the account.',
        },
      );
      return;
    }

    final GroupRecommendationVote? vote;

    switch (voteString) {
      case 'yes':
        vote = GroupRecommendationVote.yes;
      case 'no':
        vote = GroupRecommendationVote.no;
      default:
        await _sendJson(
          request,
          HttpStatus.badRequest,
          <String, dynamic>{
            'error': 'vote must be either "yes" or "no".',
          },
        );
        return;
    }

    try {
      final recommendation = recommendationService.vote(
        accountId: accountId,
        recommendationId: recommendationId,
        profileId: profileId,
        vote: vote,
      );

      await _sendRecommendationResponse(
        request,
        account,
        recommendation,
      );
    } catch (error) {
      await _sendJson(
        request,
        HttpStatus.badRequest,
        <String, dynamic>{
          'error': _safeErrorMessage(error),
        },
      );
    }
  }

  Future<void> _closeRecommendation(
    HttpRequest request,
    dynamic account,
    String accountId,
    String recommendationId,
  ) async {
    try {
      final recommendation =
          recommendationService.closeVoting(
        accountId: accountId,
        recommendationId: recommendationId,
      );

      await _sendRecommendationResponse(
        request,
        account,
        recommendation,
      );
    } catch (error) {
      await _sendJson(
        request,
        HttpStatus.badRequest,
        <String, dynamic>{
          'error': _safeErrorMessage(error),
        },
      );
    }
  }

  Future<void> _deleteRecommendation(
    HttpRequest request,
    dynamic account,
    String accountId,
    String recommendationId,
  ) async {
    try {
      recommendationService.deleteRecommendation(
        accountId: accountId,
        recommendationId: recommendationId,
      );

      // The recommendation may also have been placed in the
      // account wishlist. Remove that reference as part of the
      // deletion so the account does not retain a dangling ID.
      account.wishlistRecommendationIds.remove(
        recommendationId,
      );

      await _sendJson(
        request,
        HttpStatus.ok,
        <String, dynamic>{
          'message': 'Recommendation deleted.',
        },
      );
    } catch (error) {
      await _sendJson(
        request,
        HttpStatus.notFound,
        <String, dynamic>{
          'error': _safeErrorMessage(error),
        },
      );
    }
  }

  Future<void> _sendRecommendationResponse(
    HttpRequest request,
    dynamic account,
    GroupRecommendation recommendation,
  ) async {
    final isInWishlist =
        recommendation.mediaId != null
            ? account.wishlistMediaIds.contains(
                recommendation.mediaId!,
              )
            : account.wishlistRecommendationIds.contains(
                recommendation.id,
              );

    await _sendJson(
      request,
      HttpStatus.ok,
      <String, dynamic>{
        'recommendation': recommendation.toJson(),
        'isInWishlist': isInWishlist,
      },
    );
  }

  // ============================================================
  // GROUP WISHLIST
  // ============================================================

  Future<void> _getWishlist(
    HttpRequest request,
    dynamic account,
    String accountId,
  ) async {
    final wishlist = <Map<String, dynamic>>[];

    for (final mediaId in account.wishlistMediaIds) {
      final media = database.getMediaById(mediaId);

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
              media.releaseDate?.toIso8601String(),
          'year': media.year,
          'source': 'media',
          'mediaId': media.id,
        },
      );
    }

    for (final recommendationId
        in account.wishlistRecommendationIds) {
      final recommendation =
          recommendationService.getRecommendation(
        accountId: accountId,
        recommendationId: recommendationId,
      );

      if (recommendation == null ||
          recommendation.status !=
              GroupRecommendationStatus.approved) {
        continue;
      }

      wishlist.add(
        <String, dynamic>{
          'id': recommendation.id,
          'title': recommendation.title,
          'type': recommendation.type,
          'source': 'recommendation',
          'recommendationId': recommendation.id,
          'mediaId': recommendation.mediaId,
          'recommendedByProfileId':
              recommendation.recommendedByProfileId,
          'createdAt':
              recommendation.createdAt.toIso8601String(),
          'votingEndsAt':
              recommendation.votingEndsAt.toIso8601String(),
          'yesVotes': recommendation.yesVotes,
          'noVotes': recommendation.noVotes,
          'yesPercentage':
              recommendation.yesPercentage,
          'noPercentage':
              recommendation.noPercentage,
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
  }

  Future<void> _removeWishlistItem(
    HttpRequest request,
    dynamic account,
    String itemId,
  ) async {
    // IMPORTANT:
    // Check both wishlist namespaces before returning a failure.
    //
    // The previous implementation threw immediately when the item
    // was not found in wishlistMediaIds, which made
    // wishlistRecommendationIds unreachable.

    if (account.wishlistMediaIds.remove(itemId)) {
      await _sendJson(
        request,
        HttpStatus.ok,
        <String, dynamic>{
          'message': 'Media removed from group wishlist.',
          'mediaId': itemId,
          'isInWishlist': false,
        },
      );
      return;
    }

    if (account.wishlistRecommendationIds.remove(itemId)) {
      await _sendJson(
        request,
        HttpStatus.ok,
        <String, dynamic>{
          'message':
              'Recommendation removed from group wishlist.',
          'recommendationId': itemId,
          'isInWishlist': false,
        },
      );
      return;
    }

    await _sendJson(
      request,
      HttpStatus.notFound,
      <String, dynamic>{
        'error': 'Item is not in the group wishlist.',
      },
    );
  }

  Future<void> _acquireWishlistItem(
    HttpRequest request,
    dynamic account,
    String accountId,
    String itemId,
  ) async {
    final body = await _readJsonBody(request);
    final profileId = _readString(body['profileId']);

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

    final profile = account.getProfileById(profileId);

    if (profile == null) {
      await _sendJson(
        request,
        HttpStatus.forbidden,
        <String, dynamic>{
          'error': 'This profile does not belong to the account.',
        },
      );
      return;
    }

    // ----------------------------------------------------------
    // MEDIA WISHLIST ITEM
    // ----------------------------------------------------------

    if (account.wishlistMediaIds.contains(itemId)) {
      final media = database.getMediaById(itemId);

      if (media == null) {
        await _sendJson(
          request,
          HttpStatus.notFound,
          <String, dynamic>{
            'error': 'Media not found.',
          },
        );
        return;
      }

      account.wishlistMediaIds.remove(itemId);

      profile.ownedMediaIds.add(itemId);

      await _sendJson(
        request,
        HttpStatus.ok,
        <String, dynamic>{
          'message':
              'Media acquired and added to the selected profile library.',
          'mediaId': itemId,
          'profileId': profileId,
          'isInWishlist':
              account.wishlistMediaIds.contains(itemId),
          'isOwned': profile.ownsMedia(itemId),
        },
      );
      return;
    }

    // ----------------------------------------------------------
    // RECOMMENDATION WISHLIST ITEM
    // ----------------------------------------------------------

    if (account.wishlistRecommendationIds.contains(itemId)) {
      final recommendation =
          recommendationService.getRecommendation(
        accountId: accountId,
        recommendationId: itemId,
      );

      if (recommendation == null) {
        await _sendJson(
          request,
          HttpStatus.notFound,
          <String, dynamic>{
            'error': 'Recommendation not found.',
          },
        );
        return;
      }

      account.wishlistRecommendationIds.remove(itemId);

      await _sendJson(
        request,
        HttpStatus.ok,
        <String, dynamic>{
          'message':
              'Recommendation acquired and removed from the group wishlist.',
          'recommendationId': recommendation.id,
          'title': recommendation.title,
          'type': recommendation.type,
          'profileId': profileId,
          'isInWishlist':
              account.wishlistRecommendationIds.contains(
            recommendation.id,
          ),
          'isOwned': false,
          'catalogMedia': false,
        },
      );
      return;
    }

    await _sendJson(
      request,
      HttpStatus.notFound,
      <String, dynamic>{
        'error': 'Item is not in the group wishlist.',
      },
    );
  }

  // ============================================================
  // GROUP WATCH AUTHORIZATION
  // ============================================================

  /// Determines whether an account can see/interact with a
  /// Group Watch session.
  ///
  /// An account can access a session when:
  ///
  /// 1. It is the account that created the session, or
  /// 2. One of its profiles is represented by a session participant.
  bool _sessionVisibleToAccount(
    GroupWatchSession session,
    String accountId,
  ) {
    final cleanAccountId = accountId.trim();

    if (cleanAccountId.isEmpty) {
      return false;
    }

    if (session.accountId == cleanAccountId) {
      return true;
    }

    return session.participants.values.any(
      (participant) =>
          participant.accountId == cleanAccountId,
    );
  }

  bool _visibleSessionExists(
    String sessionId,
    String accountId,
  ) {
    final session = watchService.getSession(sessionId);

    return session != null &&
        _sessionVisibleToAccount(
          session,
          accountId,
        );
  }

  /// Verifies that a profile belongs to the authenticated account.
  bool _profileBelongsToAccount(
    String profileId,
    String accountId,
  ) {
    final cleanProfileId = profileId.trim();
    final cleanAccountId = accountId.trim();

    if (cleanProfileId.isEmpty ||
        cleanAccountId.isEmpty) {
      return false;
    }

    final accountForProfile =
        database.getAccountForProfile(cleanProfileId);

    return accountForProfile?.id == cleanAccountId;
  }

  Future<bool> _validateSessionMutationRequest(
    HttpRequest request,
    String accountId,
    String sessionId,
    String profileId,
  ) async {
    if (profileId.isEmpty) {
      await _sendJson(
        request,
        HttpStatus.badRequest,
        <String, dynamic>{
          'error': 'profileId is required.',
        },
      );
      return false;
    }

    if (!_profileBelongsToAccount(profileId, accountId)) {
      await _sendJson(
        request,
        HttpStatus.forbidden,
        <String, dynamic>{
          'error': 'This profile does not belong to the account.',
        },
      );
      return false;
    }

    if (!_visibleSessionExists(sessionId, accountId)) {
      await _sendJson(
        request,
        HttpStatus.notFound,
        <String, dynamic>{
          'error': 'Group Watch session not found.',
        },
      );
      return false;
    }

    return true;
  }

  // ============================================================
  // GROUP CHAT AUTHORIZATION
  // ============================================================

  bool _chatRoomVisibleToAccount(
    GroupChatRoom room,
    String accountId,
  ) {
    return room.ownerAccountId == accountId ||
        room.members.any(
          (member) => member.accountId == accountId,
        );
  }

  GroupChatMember? _findChatMember(
    GroupChatRoom room,
    String profileId,
    String accountId,
  ) {
    for (final member in room.members) {
      if (member.profileId == profileId &&
          member.accountId == accountId) {
        return member;
      }
    }

    return null;
  }

  // ============================================================
  // GROUP WATCH ERRORS
  // ============================================================

  Future<void> _sendGroupWatchMutationError(
    HttpRequest request,
    Object error,
  ) async {
    final message = _safeErrorMessage(error);

    final lower = message.toLowerCase();

    final status =
        lower.contains('invitation') &&
                lower.contains('expired') ||
            lower.contains('invite') &&
                lower.contains('expired')
        ? HttpStatus.gone
        : HttpStatus.badRequest;

    await _sendJson(
      request,
      status,
      <String, dynamic>{
        'error': message,
      },
    );
  }

  // ============================================================
  // JSON BODY
  // ============================================================

  Future<Map<String, dynamic>> _readJsonBody(
    HttpRequest request,
  ) async {
    final body = await utf8.decoder
        .bind(request)
        .join();

    if (body.trim().isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(body);

    if (decoded is! Map) {
      throw const FormatException(
        'Request body must be a JSON object.',
      );
    }

    return Map<String, dynamic>.from(decoded);
  }

  // ============================================================
  // VALUE PARSING
  // ============================================================

  String _readString(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  String? _readOptionalString(dynamic value) {
    final valueString = _readString(value);

    return valueString.isEmpty ? null : valueString;
  }

  Set<String> _readStringSet(dynamic value) {
    if (value is! List) {
      return <String>{};
    }

    return value
        .map(_readString)
        .where((item) => item.isNotEmpty)
        .toSet();
  }

  int? _readInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      if (!value.isFinite) {
        return null;
      }

      return value.toInt();
    }

    return int.tryParse(
      value.toString().trim(),
    );
  }

  double? _readDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      final result = value.toDouble();

      return result.isFinite ? result : null;
    }

    final result = double.tryParse(
      value.toString().trim(),
    );

    if (result == null || !result.isFinite) {
      return null;
    }

    return result;
  }

  double? _readPositiveDurationHours(
    dynamic value, {
    required double defaultHours,
  }) {
    if (value == null) {
      return defaultHours > 0 ? defaultHours : null;
    }

    final hours = _readDouble(value);

    if (hours == null ||
        !hours.isFinite ||
        hours <= 0) {
      return null;
    }

    final milliseconds =
        (hours * Duration.millisecondsPerHour).round();

    if (milliseconds <= 0) {
      return null;
    }

    return hours;
  }

  // ============================================================
  // ERROR HANDLING
  // ============================================================

  String _safeErrorMessage(Object error) {
    final message = error.toString().trim();

    if (message.isEmpty) {
      return 'The requested group operation failed.';
    }

    // Preserve service-level validation messages because the
    // Group Watch and recommendation services use them to explain
    // state conflicts to the Flutter client.
    return message;
  }

  // ============================================================
  // JSON RESPONSE
  // ============================================================

  Future<void> _sendJson(
    HttpRequest request,
    int statusCode,
    Map<String, dynamic> body,
  ) async {
    final response = request.response;

    response.statusCode = statusCode;
    response.headers.contentType = ContentType.json;

    // Group APIs use bearer authentication rather than cookies.
    // These headers allow Flutter Web and other browser clients to
    // perform API calls and preflight requests.
    response.headers.set(
      'Access-Control-Allow-Origin',
      '*',
    );
    response.headers.set(
      'Access-Control-Allow-Methods',
      'GET, POST, PUT, PATCH, DELETE, OPTIONS',
    );
    response.headers.set(
      'Access-Control-Allow-Headers',
      'Authorization, Content-Type, Accept',
    );
    response.headers.set(
      'Access-Control-Expose-Headers',
      'Content-Type',
    );

    // Group responses can contain session state, invitations,
    // recommendations, and account-specific wishlist data.
    // Prevent intermediary/browser caching of those responses.
    response.headers.set(
      'Cache-Control',
      'no-store',
    );
    response.headers.set(
      'Pragma',
      'no-cache',
    );

    if (statusCode != HttpStatus.noContent) {
      response.write(jsonEncode(body));
    }

    await response.close();
  }
}
