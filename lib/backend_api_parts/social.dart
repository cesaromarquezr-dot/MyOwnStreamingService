// Domain API methods extracted from backend_api.dart.
part of '../backend_api.dart';

extension BackendApiSocialMethods on BackendApi {
  Future<Map<String, dynamic>> getSocialHome(
      {required String profileId}) async {
    _requireAuthentication();
    final uri = Uri.parse('$baseUrl/social/home')
        .replace(queryParameters: {'profileId': profileId});
    return _requireSuccess(await _networkClient.get(uri, headers: _headers),
        'Unable to load friends and communities.');
  }

  Future<Map<String, dynamic>> getSocialCenter(
      {required String profileId}) async {
    _requireAuthentication();
    final uri = Uri.parse('$baseUrl/social/center').replace(
      queryParameters: {'profileId': profileId},
    );
    return _requireSuccess(
      await _networkClient.get(uri, headers: _headers),
      'Unable to load social center.',
    );
  }

  Future<Map<String, dynamic>> getSocialCommunityDetail({
    required String profileId,
    required String communityId,
  }) async {
    _requireAuthentication();
    final uri = Uri.parse('$baseUrl/social/communities/${Uri.encodeComponent(communityId)}')
        .replace(queryParameters: {'profileId': profileId});
    return _requireSuccess(
      await _networkClient.get(uri, headers: _headers),
      'Unable to load community details.',
    );
  }

  Future<Map<String, dynamic>> getSocialPostDetail({
    required String profileId,
    required String postId,
  }) async {
    _requireAuthentication();
    final uri = Uri.parse('$baseUrl/social/posts/${Uri.encodeComponent(postId)}')
        .replace(queryParameters: {'profileId': profileId});
    return _requireSuccess(
      await _networkClient.get(uri, headers: _headers),
      'Unable to load post details.',
    );
  }

  Future<Map<String, dynamic>> getSocialProfile({
    required String profileId,
    required String targetAccountId,
    required String targetProfileId,
  }) async {
    _requireAuthentication();
    final uri = Uri.parse('$baseUrl/social/profile').replace(queryParameters: {
      'profileId': profileId,
      'targetAccountId': targetAccountId,
      'targetProfileId': targetProfileId,
    });
    return _requireSuccess(
      await _networkClient.get(uri, headers: _headers),
      'Unable to load this profile.',
    );
  }

  Future<List<Map<String, dynamic>>> getSocialFollowing({
    required String profileId,
  }) async {
    _requireAuthentication();
    final uri = Uri.parse('$baseUrl/social/following').replace(
      queryParameters: {'profileId': profileId},
    );
    final data = await _requireSuccess(
      await _networkClient.get(uri, headers: _headers),
      'Unable to load followed stores.',
    );
    return (data['following'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<Map<String, dynamic>> followSocialStore({
    required String profileId,
    required String targetType,
    required String targetId,
    String? targetAccountExternalId,
  }) => _socialPost(
        'following',
        {
          'profileId': profileId,
          'targetType': targetType,
          'targetId': targetId,
          if (targetAccountExternalId != null && targetAccountExternalId.isNotEmpty)
            'targetAccountExternalId': targetAccountExternalId,
        },
        'Unable to follow this store.',
      );

  Future<void> unfollowSocialTarget({
    required String profileId,
    required String targetType,
    required String targetKey,
  }) async {
    _requireAuthentication();
    await _requireSuccess(
      await _networkClient.delete(
        Uri.parse('$baseUrl/social/following'),
        headers: _headers,
        body: jsonEncode({
          'profileId': profileId,
          'targetType': targetType,
          'targetKey': targetKey,
        }),
      ),
      'Unable to unfollow this store.',
    );
  }

  Future<Map<String, dynamic>> getSocialAccountProfiles({
    required String profileId,
  }) async {
    _requireAuthentication();
    final uri = Uri.parse('$baseUrl/social/account-profiles').replace(
      queryParameters: {'profileId': profileId},
    );
    return _requireSuccess(
      await _networkClient.get(uri, headers: _headers),
      'Unable to load profile activity.',
    );
  }

  Future<Map<String, dynamic>> createSocialAccountConversation({
    required String profileId,
    required String targetProfileId,
  }) =>
      _socialPost(
        'conversations',
        {'profileId': profileId, 'targetProfileId': targetProfileId},
        'Unable to start an account profile conversation.',
      );

  Future<Map<String, dynamic>> createSocialAccountGroupConversation({
    required String profileId,
    required String title,
    required List<String> profileIds,
  }) =>
      _socialPost(
        'conversations',
        {
          'profileId': profileId,
          'title': title,
          'profileIds': profileIds,
        },
        'Unable to create an account group chat.',
      );

  Future<Map<String, dynamic>> createSocialConversation({
    required String profileId,
    required String username,
  }) =>
      _socialPost(
        'conversations',
        {'profileId': profileId, 'username': username.replaceFirst('@', '')},
        'Unable to start conversation.',
      );

  Future<Map<String, dynamic>> createSocialGroupConversation({
    required String profileId,
    required String title,
    required List<String> usernames,
  }) =>
      _socialPost(
        'conversations',
        {
          'profileId': profileId,
          'title': title,
          'usernames': usernames,
        },
        'Unable to create group chat.',
      );

  Future<Map<String, dynamic>> createSocialConversationInvite({
    required String profileId,
    required String conversationId,
  }) =>
      _socialPost(
        'conversations/${Uri.encodeComponent(conversationId)}/invites',
        {'profileId': profileId},
        'Unable to create a group chat invite link.',
      );

  Future<Map<String, dynamic>> acceptSocialConversationInvite({
    required String profileId,
    required String token,
  }) =>
      _socialPost(
        'conversation-invites/${Uri.encodeComponent(token)}/accept',
        {'profileId': profileId},
        'Unable to accept this group chat invite.',
      );

  Future<Map<String, dynamic>> getSocialConversation({
    required String profileId,
    required String conversationId,
    String? after,
  }) async {
    _requireAuthentication();
    final uri = Uri.parse(
      '$baseUrl/social/conversations/${Uri.encodeComponent(conversationId)}',
    ).replace(queryParameters: {
      'profileId': profileId,
      if (after != null) 'after': after,
    });
    return _requireSuccess(
      await _networkClient.get(uri, headers: _headers),
      'Unable to load conversation.',
    );
  }

  Future<Map<String, dynamic>> sendSocialMessage({
    required String profileId,
    required String conversationId,
    required String body,
    String? replyToMessageId,
    String messageType = 'text',
    Map<String, dynamic>? mediaReference,
    Map<String, dynamic>? textFormat,
    bool viewOnce = false,
  }) =>
      _socialPost(
        'conversations/${Uri.encodeComponent(conversationId)}/messages',
        {
          'profileId': profileId,
          'body': body,
          if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
          'messageType': messageType,
          if (mediaReference != null) 'mediaReference': mediaReference,
          if (textFormat != null) 'textFormat': textFormat,
          if (viewOnce) 'viewOnce': true,
        },
        'Unable to send message.',
      );

  Future<Map<String, dynamic>> forwardSocialMessage({
    required String profileId,
    required String sourceMessageId,
    required String conversationId,
  }) =>
      _socialPost(
        'messages/${Uri.encodeComponent(sourceMessageId)}/forward',
        {'profileId': profileId, 'conversationId': conversationId},
        'Unable to forward video.',
      );

  Future<Map<String, dynamic>> forwardSocialPost({
    required String profileId,
    required String sourcePostId,
    required String conversationId,
  }) =>
      _socialPost(
        'posts/${Uri.encodeComponent(sourcePostId)}/share',
        {'profileId': profileId, 'conversationId': conversationId},
        'Unable to share video.',
      );

  Future<Map<String, dynamic>> setSocialConversationAppearance({
    required String profileId,
    required String conversationId,
    String? backgroundColor,
    String? backgroundImagePath,
    bool clearBackgroundColor = false,
    bool clearBackgroundImage = false,
  }) =>
      _socialPost(
        'conversations/${Uri.encodeComponent(conversationId)}/appearance',
        {
          'profileId': profileId,
          if (backgroundColor != null) 'backgroundColor': backgroundColor,
          if (clearBackgroundColor) 'clearBackgroundColor': true,
          if (backgroundImagePath != null)
            'backgroundImagePath': backgroundImagePath,
          if (clearBackgroundImage) 'clearBackgroundImage': true,
        },
        'Unable to save chat appearance.',
      );

  Future<Map<String, dynamic>> setSocialConversationTyping({
    required String profileId,
    required String conversationId,
    required bool isTyping,
  }) =>
      _socialPost(
        'conversations/${Uri.encodeComponent(conversationId)}/typing',
        {'profileId': profileId, 'isTyping': isTyping},
        'Unable to update typing status.',
      );

  Future<Map<String, dynamic>> setSocialProfilePresence({
    required String profileId,
    String? availability,
    String? activityType,
    String? activityText,
    String? nickname,
    bool clearActivity = false,
    bool clearNickname = false,
  }) async {
    final privacy = await PrivacyPreferencesStore.load(profileId: profileId);
    // Suppress all presence network writes when the profile disabled presence.
    // When disabling it, the settings screen first sends one final 'away' update.
    if (!privacy.sharePresence) {
      return <String, dynamic>{'success': true, 'suppressedByPrivacy': true};
    }
    final allowActivity = privacy.shareActivity;
    return _socialPost(
      'presence',
      {
        'profileId': profileId,
        if (availability != null) 'availability': availability,
        if (allowActivity && activityType != null) 'activityType': activityType,
        if (allowActivity && activityText != null) 'activityText': activityText,
        if (nickname != null) 'nickname': nickname,
        if (clearActivity || !allowActivity) 'clearActivity': true,
        if (clearNickname) 'clearNickname': true,
      },
      'Unable to update profile presence.',
    );
  }

  Future<Map<String, dynamic>> setSocialMessageNickname({
    required String profileId,
    required String nickname,
  }) =>
      setSocialProfilePresence(
        profileId: profileId,
        nickname: nickname,
        clearNickname: nickname.isEmpty,
      );

  Future<Map<String, dynamic>> setSocialGroupSendPolicy({
    required String profileId,
    required String conversationId,
    required String sendPolicy,
  }) =>
      _socialPatch(
        'conversations/${Uri.encodeComponent(conversationId)}',
        {'profileId': profileId, 'sendPolicy': sendPolicy},
        'Unable to update group chat settings.',
      );

  Future<Map<String, dynamic>> createSocialChatPoll({
    required String profileId,
    required String conversationId,
    required String question,
    required List<String> options,
  }) =>
      _socialPost(
        'conversations/${Uri.encodeComponent(conversationId)}/polls',
        {
          'profileId': profileId,
          'question': question,
          'options': options,
        },
        'Unable to create poll.',
      );

  Future<Map<String, dynamic>> voteSocialChatPoll({
    required String profileId,
    required String conversationId,
    required String pollId,
    required int optionIndex,
  }) =>
      _socialPost(
        'conversations/${Uri.encodeComponent(conversationId)}/polls/${Uri.encodeComponent(pollId)}/vote',
        {'profileId': profileId, 'optionIndex': optionIndex},
        'Unable to submit poll vote.',
      );

  Future<Map<String, dynamic>> viewSocialOnceMessage({
    required String profileId,
    required String messageId,
  }) =>
      _socialPost(
        'messages/${Uri.encodeComponent(messageId)}/view',
        {'profileId': profileId},
        'Unable to open view-once attachment.',
      );

  Future<Map<String, dynamic>> reactToSocialMessage({
    required String profileId,
    required String messageId,
    required String reaction,
  }) =>
      _socialPost(
        'messages/${Uri.encodeComponent(messageId)}',
        {'profileId': profileId, 'reaction': reaction},
        'Unable to react to message.',
      );

  Future<Map<String, dynamic>> reactToSocialPost({
    required String profileId,
    required String postId,
    required String reaction,
  }) =>
      _socialPost(
        'posts/react',
        {'profileId': profileId, 'postId': postId, 'reaction': reaction},
        'Unable to react to post.',
      );
  Future<Map<String, dynamic>> commentOnSocialPost({
    required String profileId,
    required String postId,
    required String body,
  }) =>
      _socialPost(
        'posts/comment',
        {'profileId': profileId, 'postId': postId, 'body': body},
        'Unable to comment on post.',
      );

  Future<Map<String, dynamic>> recordSocialStoryView({
    required String profileId,
    required String storyId,
  }) =>
      _socialPost(
        'stories/${Uri.encodeComponent(storyId)}/view',
        {'profileId': profileId},
        'Unable to record Story view.',
      );

  Future<Map<String, dynamic>> getSocialStoryInsights({
    required String profileId,
    required String storyId,
  }) async {
    _requireAuthentication();
    final uri = Uri.parse('$baseUrl/social/stories/${Uri.encodeComponent(storyId)}/insights')
        .replace(queryParameters: {'profileId': profileId});
    return _requireSuccess(
      await _networkClient.get(uri, headers: _headers),
      'Unable to load Story views.',
    );
  }

  Future<Map<String, dynamic>> reactToSocialStory({
    required String profileId,
    required String storyId,
    required String reaction,
  }) =>
      _socialPost(
        'stories/${Uri.encodeComponent(storyId)}/react',
        {'profileId': profileId, 'reaction': reaction},
        'Unable to react to Story.',
      );

  Future<Map<String, dynamic>> voteSocialStoryPoll({
    required String profileId,
    required String storyId,
    required int optionIndex,
  }) =>
      _socialPost(
        'stories/${Uri.encodeComponent(storyId)}/poll/vote',
        {'profileId': profileId, 'optionIndex': optionIndex},
        'Unable to vote on Story poll.',
      );

  Future<Map<String, dynamic>> reshareSocialStory({
    required String profileId,
    required String storyId,
    int expiresInHours = 24,
  }) =>
      _socialPost(
        'stories/${Uri.encodeComponent(storyId)}/reshare',
        {'profileId': profileId, 'expiresInHours': expiresInHours},
        'Unable to reshare Story.',
      );

  Future<Map<String, dynamic>> createSocialStory({
    required String profileId,
    required String body,
    String? communityId,
    int expiresInHours = 24,
    Map<String, dynamic>? mediaReference,
  }) =>
      _socialPost(
        'stories',
        {
          'profileId': profileId,
          'body': body,
          if (communityId != null) 'communityId': communityId,
          'expiresInHours': expiresInHours,
          if (mediaReference != null) 'mediaReference': mediaReference,
        },
        'Unable to publish story.',
      );

  Future<String> uploadSocialAttachment({
    required String profileId,
    required List<int> bytes,
    required String contentType,
  }) async {
    _requireAuthentication();
    final uri = Uri.parse('$baseUrl/social/attachments').replace(
      queryParameters: {'profileId': profileId},
    );
    final result = await _requireSuccess(
      await _networkClient.post(
        uri,
        headers: {
          ..._headers,
          'Content-Type': contentType,
        },
        body: bytes,
      ),
      'Unable to upload attachment.',
    );
    final path = result['attachmentPath']?.toString();
    if (path == null || path.isEmpty) {
      throw BackendApiException(
          'The server did not return an attachment reference.');
    }
    return path;
  }

  Future<Map<String, dynamic>> _socialPatch(
    String path,
    Map<String, dynamic> body,
    String error,
  ) async {
    _requireAuthentication();
    return _requireSuccess(
      await _networkClient.patch(
        Uri.parse('$baseUrl/social/$path'),
        headers: _headers,
        body: jsonEncode(body),
      ),
      error,
    );
  }

  Future<Map<String, dynamic>> getSocialMediaNotes({
    required String profileId,
    required String mediaId,
    String? mediaVersionId,
  }) async {
    _requireAuthentication();
    final uri = Uri.parse('$baseUrl/social/notes').replace(
      queryParameters: {
        'profileId': profileId,
        'mediaId': mediaId,
        if (mediaVersionId != null) 'mediaVersionId': mediaVersionId,
      },
    );
    return _requireSuccess(
      await _networkClient.get(uri, headers: _headers),
      'Unable to load media notes.',
    );
  }

  Future<Map<String, dynamic>> createSocialMediaNote({
    required String profileId,
    required String mediaId,
    required String mediaVersionId,
    required int positionMilliseconds,
    required String text,
  }) =>
      _socialPost(
        'notes',
        {
          'profileId': profileId,
          'mediaId': mediaId,
          'mediaVersionId': mediaVersionId,
          'positionMilliseconds': positionMilliseconds,
          'text': text,
        },
        'Unable to save media note.',
      );

  Future<Map<String, dynamic>> _socialPost(
      String path, Map<String, dynamic> body, String error) async {
    _requireAuthentication();
    return _requireSuccess(
        await _networkClient.post(Uri.parse('$baseUrl/social/$path'),
            headers: _headers, body: jsonEncode(body)),
        error);
  }

  Future<Map<String, dynamic>> sendFriendRequest({
    required String profileId,
    required String username,
    String? targetProfileId,
  }) => _socialPost(
    'friend-request',
    {
      'profileId': profileId,
      'username': username,
      if (targetProfileId != null && targetProfileId.trim().isNotEmpty)
        'targetProfileId': targetProfileId.trim(),
    },
    'Unable to send friend request.',
  );

  Future<Map<String, dynamic>> respondFriendRequest(
      {required String profileId,
      required String friendshipId,
      required String action}) async {
    _requireAuthentication();
    return _requireSuccess(
        await _networkClient.patch(
            Uri.parse(
                '$baseUrl/social/friend-request/${Uri.encodeComponent(friendshipId)}'),
            headers: _headers,
            body: jsonEncode({'profileId': profileId, 'action': action})),
        'Unable to update friend request.');
  }

  Future<Map<String, dynamic>> respondGuardianFriendRequest({
    required String profileId,
    required String friendshipId,
    required String action,
  }) async {
    _requireAuthentication();
    if (!{'approve', 'block'}.contains(action)) {
      throw ArgumentError('Unsupported guardian review action.');
    }
    return _requireSuccess(
      await _networkClient.patch(
        Uri.parse('$baseUrl/social/guardian-friend-request/${Uri.encodeComponent(friendshipId)}'),
        headers: _headers,
        body: jsonEncode({'profileId': profileId, 'action': action}),
      ),
      'Unable to update guardian friend-request review.',
    );
  }

  Future<Map<String, dynamic>> createSocialPost({
    required String profileId,
    required String body,
    String? communityId,
    List<String> communityIds = const <String>[],
    Map<String, dynamic>? mediaReference,
  }) =>
      _socialPost(
        'posts',
        {
          'profileId': profileId,
          'body': body,
          if (communityId != null) 'communityId': communityId,
          if (communityIds.isNotEmpty) 'communityIds': communityIds,
          if (mediaReference != null) 'mediaReference': mediaReference,
        },
        'Unable to publish post.',
      );

  Future<Map<String, dynamic>> createSocialCommunity({
    required String profileId,
    required String name,
    required String description,
    String category = 'general',
  }) =>
      _socialPost(
        'communities',
        {'profileId': profileId, 'name': name, 'description': description, 'category': category},
        'Unable to create community.');

  Future<Map<String, dynamic>> joinSocialCommunity(
          {required String profileId, required String communityId}) =>
      _socialPost(
          'communities/join',
          {'profileId': profileId, 'communityId': communityId},
          'Unable to join community.');

  Future<Map<String, dynamic>> leaveSocialCommunity({
    required String profileId,
    required String communityId,
  }) =>
      _socialPost(
        'communities/leave',
        {'profileId': profileId, 'communityId': communityId},
        'Unable to leave community.',
      );

  Future<Map<String, dynamic>> saveAppRecord({
    String? profileId,
    required String recordType,
    required String recordKey,
    Map<String, dynamic> data = const <String, dynamic>{},
  }) async {
    _requireAuthentication();
    return _requireSuccess(
      await _networkClient.post(
        Uri.parse('$baseUrl/records'),
        headers: _headers,
        body: jsonEncode({
          'profileId': profileId,
          'recordType': recordType,
          'recordKey': recordKey,
          'data': data,
        }),
      ),
      'Unable to save the application record.',
    );
  }

  /// Records a completed action against a canonical media identity.
  /// Domain state remains owned by its existing likes, playlist, and
  /// collection services; this record provides an authenticated shared event.
  Future<Map<String, dynamic>> recordUniversalMediaAction({
    required String profileId,
    required String action,
    required String contentType,
    required String contentId,
    required String idempotencyKey,
    String? mediaVersionId,
    String? targetId,
  }) async {
    _requireAuthentication();
    return _requireSuccess(
      await _networkClient.post(
        Uri.parse('$baseUrl/media-action'),
        headers: _headers,
        body: jsonEncode({
          'profileId': profileId,
          'action': action,
          'contentType': contentType,
          'contentId': contentId,
          'idempotencyKey': idempotencyKey,
          'mediaVersionId': mediaVersionId,
          'targetId': targetId,
        }),
      ),
      'Unable to record the media action.',
    );
  }

  Future<List<Map<String, dynamic>>> getMediaActivity({
    required String profileId,
    int limit = 50,
  }) async {
    _requireAuthentication();
    final uri = Uri.parse('$baseUrl/activity').replace(
      queryParameters: {
        'profileId': profileId,
        'limit': limit.toString(),
      },
    );
    final data = await _requireSuccess(
      await _networkClient.get(uri, headers: _headers),
      'Unable to load profile activity.',
    );
    return data['activities'] is List
        ? (data['activities'] as List)
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList(growable: false)
        : <Map<String, dynamic>>[];
  }


}
