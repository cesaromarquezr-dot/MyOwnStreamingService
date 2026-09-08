import 'package:flutter/foundation.dart';

import 'backend_api.dart';

enum SubscriptionPlan {
  monthly,
  yearly,
}

enum SubscriptionStatus {
  active,
  expired,
}

class Subscription {
  final SubscriptionPlan plan;
  SubscriptionStatus status;

  Subscription({
    required this.plan,
    this.status = SubscriptionStatus.active,
  });

  double get price {
    switch (plan) {
      case SubscriptionPlan.monthly:
        return 9.99;
      case SubscriptionPlan.yearly:
        return 99.99;
    }
  }

  String get displayName {
    switch (plan) {
      case SubscriptionPlan.monthly:
        return '\$9.99/month';
      case SubscriptionPlan.yearly:
        return '\$99.99/year';
    }
  }
}

class MediaItem {
  final String id;
  final String title;
  final String type;
  final String? imageUrl;
  final String? description;
  final int? releaseYear;
  final double? rating;
  final String? trailerUrl;

  MediaItem({
    this.trailerUrl,
    required this.id,
    required this.title,
    required this.type,
    this.imageUrl,
    this.description,
    this.releaseYear,
    this.rating,
  });

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      type: json['type']?.toString() ?? 'movie',
      imageUrl: json['imageUrl']?.toString(),
      description: json['description']?.toString(),
      releaseYear: json['releaseYear'] is int
          ? json['releaseYear'] as int
          : int.tryParse(
              json['releaseYear']?.toString() ?? '',
            ),
      rating: json['rating'] is num
          ? (json['rating'] as num).toDouble()
          : double.tryParse(
              json['rating']?.toString() ?? '',
            ),
      trailerUrl: json['trailerUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'type': type,
      'imageUrl': imageUrl,
      'description': description,
      'releaseYear': releaseYear,
      'rating': rating,
      'trailerUrl': trailerUrl,
    };
  }
}

class Profile {
  final String id;
  String name;
  String? avatarUrl;

  Profile({
    required this.id,
    required this.name,
    this.avatarUrl,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Profile',
      avatarUrl: json['avatarUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatarUrl': avatarUrl,
    };
  }
}

class UserAccount {
  final String username;
  final String email;
  Subscription subscription;
  final List<Profile> profiles;

  UserAccount({
    required this.username,
    required this.email,
    required this.subscription,
    List<Profile>? profiles,
  }) : profiles = profiles ?? [];

  bool get hasActiveSubscription =>
      subscription.status == SubscriptionStatus.active;

  Profile? get firstProfile =>
      profiles.isEmpty ? null : profiles.first;

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'email': email,
      'subscription': {
        'plan': subscription.plan.name,
        'status': subscription.status.name,
      },
      'profiles': profiles.map((profile) => profile.toJson()).toList(),
    };
  }
}

class ActivityItem {
  final String id;
  final String title;
  final String action;
  final DateTime timestamp;

  ActivityItem({
    required this.id,
    required this.title,
    required this.action,
    required this.timestamp,
  });
}

class ChatMessage {
  final String id;
  final String sender;
  final String message;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.sender,
    required this.message,
    required this.timestamp,
  });
}

class WishlistItem {
  final String id;
  final String title;
  final String type;

  WishlistItem({
    required this.id,
    required this.title,
    required this.type,
  });
}

/// Frontend representation of one participant in a Group Watch session.
///
/// Audio and subtitle selections are stored independently for every
/// participant. Playback position and play/pause state are shared by the
/// entire Group Watch session.
class GroupWatchParticipant {
  final String profileId;
  String profileName;
  String invitationStatus;
  String? audioTrackId;
  String? subtitleTrackId;
  DateTime? joinedAt;

  GroupWatchParticipant({
    required this.profileId,
    required this.profileName,
    this.invitationStatus = 'pending',
    this.audioTrackId,
    this.subtitleTrackId,
    this.joinedAt,
  });

  bool get isAccepted =>
      invitationStatus.toLowerCase() == 'accepted';

  bool get isPending =>
      invitationStatus.toLowerCase() == 'pending';

  bool get isDeclined =>
      invitationStatus.toLowerCase() == 'declined';

  bool get isExpired =>
      invitationStatus.toLowerCase() == 'expired';

  factory GroupWatchParticipant.fromJson(
    Map<String, dynamic> json, {
    String? fallbackProfileName,
  }) {
    final profileId =
        json['profileId']?.toString() ?? '';

    return GroupWatchParticipant(
      profileId: profileId,
      profileName:
          json['profileName']?.toString() ??
          fallbackProfileName ??
          'Profile',
      invitationStatus:
          json['invitationStatus']?.toString() ??
          'pending',
      audioTrackId:
          json['audioTrackId']?.toString(),
      subtitleTrackId:
          json['subtitleTrackId']?.toString(),
      joinedAt: _dateTimeFromJson(
        json['joinedAt'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'profileId': profileId,
      'profileName': profileName,
      'invitationStatus': invitationStatus,
      'audioTrackId': audioTrackId,
      'subtitleTrackId': subtitleTrackId,
      'joinedAt': joinedAt?.toIso8601String(),
    };
  }
}

/// Backend-connected Group Watch session.
///
/// Playback state is global to the session while audio and subtitle
/// selections remain participant-specific.
class GroupWatchSession {
  final String id;
  final String title;
  final String mediaId;
  final String type;
  final String hostProfileId;

  final List<String> participants;

  final Map<String, GroupWatchParticipant>
      participantStates;

  String status;
  DateTime createdAt;
  DateTime? invitationExpiresAt;
  DateTime? startedAt;
  DateTime? endedAt;

  Duration playbackPosition;
  bool isPlaying;

  String? pausedByProfileId;
  String? pauseReason;

  /// Compatibility property retained for older UI code.
  ///
  /// Actual synchronization is controlled by the backend.
  bool synchronized;

  GroupWatchSession({
    required this.id,
    required this.title,
    this.mediaId = '',
    this.type = 'movie',
    this.hostProfileId = '',
    required this.participants,
    Map<String, GroupWatchParticipant>?
        participantStates,
    this.status = 'waiting',
    DateTime? createdAt,
    this.invitationExpiresAt,
    this.startedAt,
    this.endedAt,
    this.playbackPosition = Duration.zero,
    this.isPlaying = false,
    this.pausedByProfileId,
    this.pauseReason,
    this.synchronized = true,
  }) : participantStates =
            participantStates ??
            <String, GroupWatchParticipant>{},
       createdAt =
            createdAt ?? DateTime.now();

  bool get isWaiting =>
      status.toLowerCase() == 'waiting';

  bool get isReady =>
      status.toLowerCase() == 'ready';

  bool get isPlayingStatus =>
      status.toLowerCase() == 'playing';

  bool get isPaused =>
      status.toLowerCase() == 'paused';

  bool get isEnded =>
      status.toLowerCase() == 'ended';

  bool get invitationsExpired {
    final currentStatus = status.toLowerCase();

    if (currentStatus != 'waiting' &&
        currentStatus != 'ready') {
      return true;
    }

    final expiry = invitationExpiresAt;

    if (expiry == null) {
      return false;
    }

    return DateTime.now().isAfter(expiry);
  }

  bool canResume(String profileId) {
    return pausedByProfileId == profileId;
  }

  GroupWatchParticipant? participantForProfile(
    String profileId,
  ) {
    return participantStates[profileId];
  }

  factory GroupWatchSession.fromJson(
    Map<String, dynamic> json, {
    List<Profile> knownProfiles =
        const <Profile>[],
  }) {
    final participantStates =
        <String, GroupWatchParticipant>{};

    final participantData =
        json['participants'];

    if (participantData is Map) {
      participantData.forEach(
        (key, value) {
          if (value is! Map) {
            return;
          }

          final participantMap =
              Map<String, dynamic>.from(
            value,
          );

          final profileId =
              participantMap['profileId']
                      ?.toString() ??
                  key.toString();

          if (profileId.isEmpty) {
            return;
          }

          final knownProfile =
              _profileFromList(
            knownProfiles,
            profileId,
          );

          participantStates[profileId] =
              GroupWatchParticipant.fromJson(
            participantMap,
            fallbackProfileName:
                knownProfile?.name,
          );
        },
      );
    } else if (participantData is List) {
      for (final item in participantData) {
        if (item is! Map) {
          continue;
        }

        final participantMap =
            Map<String, dynamic>.from(
          item,
        );

        final profileId =
            participantMap['profileId']
                    ?.toString() ??
                '';

        if (profileId.isEmpty) {
          continue;
        }

        final knownProfile =
            _profileFromList(
          knownProfiles,
          profileId,
        );

        participantStates[profileId] =
            GroupWatchParticipant.fromJson(
          participantMap,
          fallbackProfileName:
              knownProfile?.name,
        );
      }
    }

    final participantNames =
        <String>[];

    for (final participant
        in participantStates.values) {
      participantNames.add(
        participant.profileName,
      );
    }

    final positionSeconds =
        _doubleFromJson(
      json['playbackPosition'],
    );

    return GroupWatchSession(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      mediaId: json['mediaId']?.toString() ?? '',
      type:
          json['type']?.toString() ??
          'movie',
      hostProfileId:
          json['hostProfileId']?.toString() ??
          '',
      participants:
          participantNames,
      participantStates:
          participantStates,
      status:
          json['status']?.toString() ??
          'waiting',
      createdAt:
          _dateTimeFromJson(
            json['createdAt'],
          ) ??
          DateTime.now(),
      invitationExpiresAt:
          _dateTimeFromJson(
        json['invitationExpiresAt'],
      ),
      startedAt:
          _dateTimeFromJson(
        json['startedAt'],
      ),
      endedAt:
          _dateTimeFromJson(
        json['endedAt'],
      ),
      playbackPosition:
          Duration(
        milliseconds:
            (positionSeconds * 1000)
                .round(),
      ),
      isPlaying:
          json['isPlaying'] == true,
      pausedByProfileId:
          json['pausedByProfileId']
              ?.toString(),
      pauseReason:
          json['pauseReason']
              ?.toString(),
      synchronized: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'mediaId': mediaId,
      'type': type,
      'hostProfileId':
          hostProfileId,
      'participants':
          participantStates.map(
        (key, value) => MapEntry(
          key,
          value.toJson(),
        ),
      ),
      'status': status,
      'createdAt':
          createdAt.toIso8601String(),
      'invitationExpiresAt':
          invitationExpiresAt
              ?.toIso8601String(),
      'startedAt':
          startedAt?.toIso8601String(),
      'endedAt':
          endedAt?.toIso8601String(),
      'playbackPosition':
          playbackPosition.inMilliseconds /
              1000.0,
      'isPlaying': isPlaying,
      'pausedByProfileId':
          pausedByProfileId,
      'pauseReason': pauseReason,
    };
  }
}

class AppController extends ChangeNotifier {
  AppController._();

  static final AppController instance =
      AppController._();

  final BackendApi backendApi = BackendApi();

  bool get isBackendAuthenticated =>
      backendApi.isAuthenticated;

  String? get backendToken =>
      backendApi.token;

  UserAccount? currentAccount;
  Profile? currentProfile;

  final List<MediaItem> library =
      <MediaItem>[];

  final List<MediaItem> watched =
      <MediaItem>[];

  final List<MediaItem> liked =
      <MediaItem>[];

  final List<MediaItem> disliked =
      <MediaItem>[];

  final List<ActivityItem> activity =
      <ActivityItem>[];

  final List<ChatMessage> groupMessages =
      <ChatMessage>[];

  final List<WishlistItem> wishlist =
      <WishlistItem>[];

  final List<GroupWatchSession>
      groupWatchSessions =
      <GroupWatchSession>[];

  final Map<String, double>
      playbackProgress =
      <String, double>{};

  final Map<String, String>
      nextEpisodes =
      <String, String>{};

  final Set<String>
      activeProfileIds =
      <String>{};

  List<MediaItem> recommendations =
      <MediaItem>[];

  bool recommendationsLoading = false;

  String? recommendationsError;

  // ---------------------------------------------------------------------------
  // GROUP RECOMMENDATIONS
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>>
      groupRecommendations =
      <Map<String, dynamic>>[];

  bool groupRecommendationsLoading =
      false;

  String? groupRecommendationsError;

  // ---------------------------------------------------------------------------
  // GROUP WISHLIST
  // ---------------------------------------------------------------------------

  bool groupWishlistLoading = false;

  String? groupWishlistError;

  // ---------------------------------------------------------------------------
  // GROUP WATCH STATE
  // ---------------------------------------------------------------------------

  bool groupWatchLoading = false;

  String? groupWatchError;

  String? activeGroupWatchSessionId;

  GroupWatchSession?
      get activeGroupWatchSession {
    final id = activeGroupWatchSessionId;

    if (id == null || id.isEmpty) {
      return null;
    }

    return getGroupWatchSession(id);
  }

  // ---------------------------------------------------------------------------
  // LOCAL ACCOUNT CREATION
  // ---------------------------------------------------------------------------

  UserAccount createAccount({
    required String username,
    required String email,
    required String password,
    required SubscriptionPlan plan,
    required String firstProfileName,
  }) {
    final profile = Profile(
      id: _generateId('profile'),
      name: firstProfileName.trim().isEmpty
          ? username
          : firstProfileName.trim(),
    );

    final account = UserAccount(
      username: username.trim(),
      email: email.trim(),
      subscription: Subscription(
        plan: plan,
        status: SubscriptionStatus.active,
      ),
      profiles: <Profile>[profile],
    );

    currentAccount = account;
    currentProfile = profile;

    activeProfileIds
      ..clear()
      ..add(profile.id);

    groupWatchSessions.clear();
    activeGroupWatchSessionId = null;
    groupWatchError = null;
    groupWatchLoading = false;

    notifyListeners();

    return account;
  }

  // ---------------------------------------------------------------------------
  // BACKEND SIGNUP
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>>
      createAccountWithBackend({
    required String username,
    required String email,
    required String password,
    required SubscriptionPlan plan,
    required String firstProfileName,
  }) async {
    final planValue =
        plan == SubscriptionPlan.yearly
            ? 'yearly'
            : 'monthly';

    final response =
        await backendApi.signup(
      username: username.trim(),
      email: email.trim(),
      password: password,
      firstProfileName:
          firstProfileName.trim().isEmpty
              ? username.trim()
              : firstProfileName.trim(),
      plan: planValue,
    );

    final accountData =
        response['account'];

    final subscriptionData =
        response['subscription'];

    String accountUsername =
        username.trim();

    String accountEmail =
        email.trim();

    if (accountData is Map) {
      final backendUsername =
          accountData['username']
              ?.toString();

      final backendEmail =
          accountData['email']
              ?.toString();

      if (backendUsername != null &&
          backendUsername.isNotEmpty) {
        accountUsername =
            backendUsername;
      }

      if (backendEmail != null &&
          backendEmail.isNotEmpty) {
        accountEmail =
            backendEmail;
      }
    }

    SubscriptionStatus
        subscriptionStatus =
        SubscriptionStatus.expired;

    if (subscriptionData is Map) {
      final statusValue =
          subscriptionData['status']
              ?.toString()
              .toLowerCase();

      if (statusValue == 'active') {
        subscriptionStatus =
            SubscriptionStatus.active;
      }
    }

    final localSubscription =
        Subscription(
      plan: plan,
      status: subscriptionStatus,
    );

    final List<Profile> profiles =
        <Profile>[];

    if (accountData is Map) {
      final profilesData =
          accountData['profiles'];

      if (profilesData is List) {
        for (final item in profilesData) {
          if (item is Map) {
            profiles.add(
              Profile.fromJson(
                Map<String, dynamic>.from(
                  item,
                ),
              ),
            );
          }
        }
      }
    }

    if (profiles.isEmpty) {
      profiles.add(
        Profile(
          id: _generateId('profile'),
          name:
              firstProfileName
                      .trim()
                      .isEmpty
                  ? accountUsername
                  : firstProfileName
                      .trim(),
        ),
      );
    }

    final account =
        UserAccount(
      username: accountUsername,
      email: accountEmail,
      subscription:
          localSubscription,
      profiles: profiles,
    );

    currentAccount = account;
    currentProfile =
        profiles.first;

    activeProfileIds
      ..clear()
      ..add(profiles.first.id);

    backendApi.clearToken();

    recommendations.clear();
    groupRecommendations.clear();
    wishlist.clear();
    groupWatchSessions.clear();

    activeGroupWatchSessionId = null;

    recommendationsError = null;
    recommendationsLoading = false;

    groupRecommendationsError =
        null;
    groupRecommendationsLoading =
        false;

    groupWishlistError = null;
    groupWishlistLoading = false;

    groupWatchError = null;
    groupWatchLoading = false;

    notifyListeners();

    return response;
  }

  // ---------------------------------------------------------------------------
  // BACKEND LOGIN
  // ---------------------------------------------------------------------------

  Future<void> loginWithBackend({
    required String usernameOrEmail,
    required String password,
  }) async {
    final response =
        await backendApi.login(
      usernameOrEmail:
          usernameOrEmail.trim(),
      password: password,
    );

    final accountData =
        response['account'];

    if (accountData is! Map) {
      throw BackendApiException(
        'The server returned an invalid account response.',
      );
    }

    final accountMap =
        Map<String, dynamic>.from(
      accountData,
    );

    final username =
        accountMap['username']
                ?.toString() ??
            '';

    final email =
        accountMap['email']
                ?.toString() ??
            '';

    if (username.isEmpty ||
        email.isEmpty) {
      throw BackendApiException(
        'The server returned incomplete account information.',
      );
    }

    final subscriptionData =
        accountMap['subscription'];

    SubscriptionPlan plan =
        SubscriptionPlan.monthly;

    if (subscriptionData is Map) {
      final planValue =
          subscriptionData['plan']
              ?.toString()
              .toLowerCase();

      if (planValue == 'yearly') {
        plan =
            SubscriptionPlan.yearly;
      }
    }

    SubscriptionStatus
        subscriptionStatus =
        SubscriptionStatus.expired;

    if (subscriptionData is Map) {
      final statusValue =
          subscriptionData['status']
              ?.toString()
              .toLowerCase();

      if (statusValue == 'active') {
        subscriptionStatus =
            SubscriptionStatus.active;
      }
    }

    final List<Profile> profiles =
        <Profile>[];

    final profilesData =
        accountMap['profiles'];

    if (profilesData is List) {
      for (final item in profilesData) {
        if (item is Map) {
          profiles.add(
            Profile.fromJson(
              Map<String, dynamic>.from(
                item,
              ),
            ),
          );
        }
      }
    }

    if (profiles.isEmpty) {
      profiles.add(
        Profile(
          id: _generateId('profile'),
          name: username,
        ),
      );
    }

    currentAccount =
        UserAccount(
      username: username,
      email: email,
      subscription:
          Subscription(
        plan: plan,
        status:
            subscriptionStatus,
      ),
      profiles: profiles,
    );

    currentProfile =
        profiles.first;

    activeProfileIds
      ..clear()
      ..add(profiles.first.id);

    recommendations.clear();
    groupRecommendations.clear();
    wishlist.clear();
    groupWatchSessions.clear();

    activeGroupWatchSessionId = null;

    recommendationsError = null;
    recommendationsLoading = false;

    groupRecommendationsError =
        null;
    groupRecommendationsLoading =
        false;

    groupWishlistError = null;
    groupWishlistLoading = false;

    groupWatchError = null;
    groupWatchLoading = false;

    notifyListeners();

    await loadRecommendations();
    await loadGroupWishlist();
    await loadGroupRecommendations();
    await loadGroupWatchSessions();
  }

  // ---------------------------------------------------------------------------
  // BACKEND ACCOUNT REFRESH
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>>
      refreshBackendAccount() async {
    if (!backendApi.isAuthenticated) {
      throw BackendApiException(
        'You are not logged in.',
      );
    }

    if (currentAccount == null) {
      throw BackendApiException(
        'No account is currently loaded.',
      );
    }

    return currentAccount!.toJson();
  }

  // ---------------------------------------------------------------------------
  // BACKEND LOGOUT
  // ---------------------------------------------------------------------------

  Future<void> logoutFromBackend() async {
    try {
      if (backendApi.isAuthenticated) {
        await backendApi.logout();
      }
    } finally {
      backendApi.clearToken();

      currentAccount = null;
      currentProfile = null;

      activeProfileIds.clear();

      recommendations.clear();
      recommendationsError = null;
      recommendationsLoading = false;

      groupRecommendations.clear();
      groupRecommendationsError = null;
      groupRecommendationsLoading = false;

      wishlist.clear();
      groupWishlistError = null;
      groupWishlistLoading = false;

      groupWatchSessions.clear();
      groupWatchError = null;
      groupWatchLoading = false;
      activeGroupWatchSessionId = null;

      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // LOCAL LOGIN
  // ---------------------------------------------------------------------------

  bool login(
    String usernameOrEmail,
    String password,
  ) {
    if (currentAccount == null) {
      return false;
    }

    final matchesUsername =
        currentAccount!.username
                .toLowerCase() ==
            usernameOrEmail
                .trim()
                .toLowerCase();

    final matchesEmail =
        currentAccount!.email
                .toLowerCase() ==
            usernameOrEmail
                .trim()
                .toLowerCase();

    if (!matchesUsername &&
        !matchesEmail) {
      return false;
    }

    if (!currentAccount!
        .hasActiveSubscription) {
      return false;
    }

    if (currentAccount!
        .profiles
        .isNotEmpty) {
      currentProfile =
          currentAccount!
              .profiles
              .first;

      activeProfileIds
        ..clear()
        ..add(currentProfile!.id);
    }

    notifyListeners();

    return true;
  }

  // ---------------------------------------------------------------------------
  // LOGOUT
  // ---------------------------------------------------------------------------

  void logout() {
    backendApi.clearToken();

    currentAccount = null;
    currentProfile = null;

    activeProfileIds.clear();

    recommendations.clear();
    recommendationsError = null;
    recommendationsLoading = false;

    groupRecommendations.clear();
    groupRecommendationsError = null;
    groupRecommendationsLoading = false;

    wishlist.clear();
    groupWishlistError = null;
    groupWishlistLoading = false;

    groupWatchSessions.clear();
    groupWatchError = null;
    groupWatchLoading = false;
    activeGroupWatchSessionId = null;

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // SUBSCRIPTION
  // ---------------------------------------------------------------------------

  Subscription? get subscription =>
      currentAccount?.subscription;

  bool get hasActiveSubscription =>
      currentAccount
          ?.hasActiveSubscription ??
      false;

  SubscriptionPlan? get subscriptionPlan =>
      currentAccount
          ?.subscription.plan;

  void subscribe(
    SubscriptionPlan plan,
  ) {
    if (currentAccount == null) {
      return;
    }

    currentAccount!.subscription =
        Subscription(
      plan: plan,
      status:
          SubscriptionStatus.active,
    );

    notifyListeners();
  }

  void expireSubscription() {
    if (currentAccount == null) {
      return;
    }

    currentAccount!
        .subscription
        .status =
        SubscriptionStatus.expired;

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // PROFILES
  // ---------------------------------------------------------------------------

  Profile addProfile(
    String name, {
    String? avatarUrl,
  }) {
    if (currentAccount == null) {
      throw StateError(
        'No account is currently signed in.',
      );
    }

    if (currentAccount!
            .profiles
            .length >=
        7) {
      throw StateError(
        'You can have a maximum of 7 profiles.',
      );
    }

    final cleanedName = name.trim();

    final profile =
        Profile(
      id: _generateId('profile'),
      name: cleanedName.isEmpty
          ? 'Profile ${currentAccount!.profiles.length + 1}'
          : cleanedName,
      avatarUrl: avatarUrl,
    );

    currentAccount!
        .profiles
        .add(profile);

    notifyListeners();

    return profile;
  }

  void removeProfile(
    String profileId,
  ) {
    if (currentAccount == null) {
      return;
    }

    if (currentAccount!
            .profiles
            .length <=
        1) {
      return;
    }

    currentAccount!.profiles
        .removeWhere(
      (profile) =>
          profile.id == profileId,
    );

    activeProfileIds
        .remove(profileId);

    if (currentProfile?.id ==
        profileId) {
      currentProfile =
          currentAccount!
              .profiles
              .first;

      activeProfileIds.add(
        currentProfile!.id,
      );
    }

    notifyListeners();
  }

  void switchProfile(
    String profileId,
  ) {
    if (currentAccount == null) {
      return;
    }

    Profile? profile;

    for (final item
        in currentAccount!.profiles) {
      if (item.id == profileId) {
        profile = item;
        break;
      }
    }

    if (profile == null) {
      return;
    }

    currentProfile = profile;

    activeProfileIds
      ..clear()
      ..add(profile.id);

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // ARM DRIVES
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>>
      getArmDrives() async {
    final drives =
        await backendApi.getArmDrives();

    return drives
        .whereType<Map>()
        .map(
          (drive) =>
              Map<String, dynamic>.from(
            drive,
          ),
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // LIBRARY
  // ---------------------------------------------------------------------------

  bool isOwned(String mediaId) {
    return library.any(
      (item) => item.id == mediaId,
    );
  }

  void addToLibrary(
    MediaItem media,
  ) {
    if (isOwned(media.id)) {
      return;
    }

    library.add(media);

    _addActivity(
      title: media.title,
      action: 'Added to library',
    );

    notifyListeners();
  }

  void removeFromLibrary(
    String mediaId,
  ) {
    library.removeWhere(
      (item) => item.id == mediaId,
    );

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // WATCHED / PLAYBACK
  // ---------------------------------------------------------------------------

  bool isWatched(String mediaId) {
    return watched.any(
      (item) => item.id == mediaId,
    );
  }

  double getPlaybackProgress(
    String mediaId,
  ) {
    return playbackProgress[mediaId] ?? 0;
  }

  void updatePlaybackProgress(
    String mediaId,
    double progress,
  ) {
    final clamped =
        progress.clamp(0.0, 1.0);

    playbackProgress[mediaId] =
        clamped.toDouble();

    notifyListeners();
  }

  void markWatched(
    MediaItem media,
  ) {
    if (!isWatched(media.id)) {
      watched.add(media);

      _addActivity(
        title: media.title,
        action: 'Watched',
      );
    }

    playbackProgress[media.id] = 1.0;

    notifyListeners();
  }

  void finishWatching(
    MediaItem media,
  ) {
    markWatched(media);
  }

  // ---------------------------------------------------------------------------
  // LIKES / DISLIKES
  // ---------------------------------------------------------------------------

  bool isLiked(String mediaId) {
    return liked.any(
      (item) => item.id == mediaId,
    );
  }

  bool isDisliked(String mediaId) {
    return disliked.any(
      (item) => item.id == mediaId,
    );
  }

  void likeMedia(
    MediaItem media,
  ) {
    disliked.removeWhere(
      (item) => item.id == media.id,
    );

    if (!isLiked(media.id)) {
      liked.add(media);
    }

    notifyListeners();
  }

  void dislikeMedia(
    MediaItem media,
  ) {
    liked.removeWhere(
      (item) => item.id == media.id,
    );

    if (!isDisliked(media.id)) {
      disliked.add(media);
    }

    notifyListeners();
  }

  void clearReaction(
    String mediaId,
  ) {
    liked.removeWhere(
      (item) => item.id == mediaId,
    );

    disliked.removeWhere(
      (item) => item.id == mediaId,
    );

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // RECOMMENDATIONS
  // ---------------------------------------------------------------------------

  Future<void>
      loadRecommendations() async {
    if (!backendApi.isAuthenticated) {
      recommendations.clear();
      recommendationsError = null;
      recommendationsLoading = false;
      notifyListeners();
      return;
    }

    recommendationsLoading = true;
    recommendationsError = null;

    notifyListeners();

    try {
      final response =
          await backendApi
              .getRecommendations();

      final List<MediaItem> loaded =
          <MediaItem>[];

      final data =
          response['recommendations'];

      if (data is List) {
        for (final item in data) {
          if (item is Map) {
            loaded.add(
              MediaItem.fromJson(
                Map<String, dynamic>.from(
                  item,
                ),
              ),
            );
          }
        }
      }

      recommendations = loaded;
    } catch (error) {
      recommendationsError =
          error.toString();
    } finally {
      recommendationsLoading =
          false;

      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // ACTIVITY
  // ---------------------------------------------------------------------------

  void _addActivity({
    required String title,
    required String action,
  }) {
    activity.insert(
      0,
      ActivityItem(
        id: _generateId('activity'),
        title: title,
        action: action,
        timestamp: DateTime.now(),
      ),
    );

    if (activity.length > 100) {
      activity.removeLast();
    }
  }

  // ---------------------------------------------------------------------------
  // GROUP CHAT
  // ---------------------------------------------------------------------------

  void sendGroupMessage({
    required String message,
  }) {
    final cleanedMessage =
        message.trim();

    if (cleanedMessage.isEmpty) {
      return;
    }

    groupMessages.add(
      ChatMessage(
        id: _generateId('message'),
        sender:
            currentProfile?.name ??
                currentAccount?.username ??
                'You',
        message: cleanedMessage,
        timestamp: DateTime.now(),
      ),
    );

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // GROUP RECOMMENDATIONS
  // ---------------------------------------------------------------------------

  Future<void>
      loadGroupRecommendations() async {
    if (!backendApi.isAuthenticated) {
      groupRecommendations.clear();
      groupRecommendationsError = null;
      groupRecommendationsLoading =
          false;

      notifyListeners();
      return;
    }

    groupRecommendationsLoading =
        true;

    groupRecommendationsError =
        null;

    notifyListeners();

    try {
      final response =
          await backendApi
              .getGroupRecommendations();

      final data =
          response['recommendations'];

      final loaded =
          <Map<String, dynamic>>[];

      if (data is List) {
        for (final item in data) {
          if (item is Map) {
            loaded.add(
              Map<String, dynamic>.from(
                item,
              ),
            );
          }
        }
      }

      groupRecommendations =
          loaded;
    } catch (error) {
      groupRecommendationsError =
          error.toString();
    } finally {
      groupRecommendationsLoading =
          false;

      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?>
      createGroupRecommendation({
    required String title,
    required String type,
    required String profileId,
    String? mediaId,
    Set<String>? activeParticipants,
    int? votingDurationHours,
  }) async {
    if (!backendApi.isAuthenticated) {
      throw BackendApiException(
        'You must be logged in before creating a group recommendation.',
      );
    }

    final String cleanedTitle =
        title.trim();

    final String cleanedType =
        type.trim();

    final String cleanedProfileId =
        profileId.trim();

    if (cleanedTitle.isEmpty) {
      throw ArgumentError(
        'Recommendation title cannot be empty.',
      );
    }

    if (cleanedType != 'movie' &&
        cleanedType != 'tvShow') {
      throw ArgumentError(
        'Recommendation type must be "movie" or "tvShow".',
      );
    }

    if (cleanedProfileId.isEmpty) {
      throw ArgumentError(
        'Profile ID cannot be empty.',
      );
    }

    if (votingDurationHours != null &&
        votingDurationHours <= 0) {
      throw ArgumentError(
        'Voting duration must be greater than zero.',
      );
    }

    String? cleanedMediaId =
        mediaId?.trim();

    if (cleanedMediaId != null &&
        cleanedMediaId.isEmpty) {
      cleanedMediaId = null;
    }

    final Set<String> participants =
        activeParticipants == null
            ? <String>{}
            : Set<String>.from(
                activeParticipants,
              );

    participants.removeWhere(
      (id) => id.trim().isEmpty,
    );

    participants.add(
      cleanedProfileId,
    );

    final response =
        await backendApi
            .createGroupRecommendation(
      title: cleanedTitle,
      type: cleanedType,
      profileId: cleanedProfileId,
      mediaId: cleanedMediaId,
      activeParticipants: participants,
      votingDurationHours:
          votingDurationHours,
    );

    final recommendation =
        response['recommendation'];

    if (recommendation is Map) {
      final recommendationMap =
          Map<String, dynamic>.from(
        recommendation,
      );

      groupRecommendations
          .removeWhere(
        (item) =>
            item['id']?.toString() ==
            recommendationMap['id']
                ?.toString(),
      );

      groupRecommendations.insert(
        0,
        recommendationMap,
      );

      final String titleForMessage =
          recommendationMap['title']
                  ?.toString() ??
              cleanedTitle;

      final String icon =
          cleanedType == 'tvShow'
              ? '📺'
              : '🎬';

      final String typeLabel =
          cleanedType == 'tvShow'
              ? 'TV show'
              : 'movie';

      sendGroupMessage(
        message:
            '$icon ${currentProfile?.name ?? 'You'} recommended the $typeLabel "$titleForMessage"',
      );

      notifyListeners();

      return recommendationMap;
    }

    await loadGroupRecommendations();

    return null;
  }

  Future<Map<String, dynamic>?>
      getGroupRecommendation(
    String recommendationId,
  ) async {
    if (!backendApi.isAuthenticated) {
      throw BackendApiException(
        'You must be logged in.',
      );
    }

    final cleanedId =
        recommendationId.trim();

    if (cleanedId.isEmpty) {
      throw ArgumentError(
        'Recommendation ID cannot be empty.',
      );
    }

    final response =
        await backendApi
            .getGroupRecommendation(
      recommendationId:
          cleanedId,
    );

    final recommendation =
        response['recommendation'];

    if (recommendation is! Map) {
      return null;
    }

    final recommendationMap =
        Map<String, dynamic>.from(
      recommendation,
    );

    groupRecommendations
        .removeWhere(
      (item) =>
          item['id']?.toString() ==
          cleanedId,
    );

    groupRecommendations.insert(
      0,
      recommendationMap,
    );

    notifyListeners();

    return recommendationMap;
  }

  Future<Map<String, dynamic>?>
      voteOnGroupRecommendation({
    required String recommendationId,
    required String profileId,
    required String vote,
  }) async {
    if (!backendApi.isAuthenticated) {
      throw BackendApiException(
        'You must be logged in.',
      );
    }

    final cleanedRecommendationId =
        recommendationId.trim();

    final cleanedProfileId =
        profileId.trim();

    final cleanedVote =
        vote.trim().toLowerCase();

    if (cleanedRecommendationId
        .isEmpty) {
      throw ArgumentError(
        'Recommendation ID cannot be empty.',
      );
    }

    if (cleanedProfileId.isEmpty) {
      throw ArgumentError(
        'Profile ID cannot be empty.',
      );
    }

    if (cleanedVote != 'yes' &&
        cleanedVote != 'no') {
      throw ArgumentError(
        'Vote must be either "yes" or "no".',
      );
    }

    final response =
        await backendApi
            .voteOnGroupRecommendation(
      recommendationId:
          cleanedRecommendationId,
      profileId:
          cleanedProfileId,
      vote: cleanedVote,
    );

    final recommendation =
        response['recommendation'];

    if (recommendation is Map) {
      final recommendationMap =
          Map<String, dynamic>.from(
        recommendation,
      );

      groupRecommendations
          .removeWhere(
        (item) =>
            item['id']?.toString() ==
            cleanedRecommendationId,
      );

      groupRecommendations.insert(
        0,
        recommendationMap,
      );

      final String title =
          recommendationMap['title']
                  ?.toString() ??
              'this recommendation';

      final String voterName =
          _profileNameForId(
        cleanedProfileId,
      );

      final int yesVotes =
          _intFromValue(
        recommendationMap['yesVotes'],
      );

      final int noVotes =
          _intFromValue(
        recommendationMap['noVotes'],
      );

      final double yesPercentage =
          _doubleFromValue(
        recommendationMap['yesPercentage'],
        fallback:
            _percentage(
          yesVotes,
          yesVotes + noVotes,
        ),
      );

      final double noPercentage =
          _doubleFromValue(
        recommendationMap['noPercentage'],
        fallback:
            _percentage(
          noVotes,
          yesVotes + noVotes,
        ),
      );

      sendGroupMessage(
        message:
            '$voterName voted ${cleanedVote.toUpperCase()} on "$title" — '
            'YES ${_formatPercentage(yesPercentage)}% '
            'NO ${_formatPercentage(noPercentage)}%',
      );

      final status =
          recommendationMap['status']
              ?.toString()
              .toLowerCase();

      if (status == 'approved') {
        await loadGroupWishlist();
      }

      notifyListeners();

      return recommendationMap;
    }

    await loadGroupRecommendations();

    return null;
  }

  Future<Map<String, dynamic>?>
      closeGroupRecommendationVoting({
    required String recommendationId,
  }) async {
    if (!backendApi.isAuthenticated) {
      throw BackendApiException(
        'You must be logged in.',
      );
    }

    final cleanedId =
        recommendationId.trim();

    if (cleanedId.isEmpty) {
      throw ArgumentError(
        'Recommendation ID cannot be empty.',
      );
    }

    final response =
        await backendApi
            .closeGroupRecommendationVoting(
      recommendationId:
          cleanedId,
    );

    final recommendation =
        response['recommendation'];

    if (recommendation is Map) {
      final recommendationMap =
          Map<String, dynamic>.from(
        recommendation,
      );

      groupRecommendations
          .removeWhere(
        (item) =>
            item['id']?.toString() ==
            cleanedId,
      );

      groupRecommendations.insert(
        0,
        recommendationMap,
      );

      final status =
          recommendationMap['status']
              ?.toString()
              .toLowerCase();

      if (status == 'approved') {
        await loadGroupWishlist();
      }

      notifyListeners();

      return recommendationMap;
    }

    await loadGroupRecommendations();

    return null;
  }

  Future<void>
      deleteGroupRecommendation(
    String recommendationId,
  ) async {
    if (!backendApi.isAuthenticated) {
      throw BackendApiException(
        'You must be logged in.',
      );
    }

    final cleanedId =
        recommendationId.trim();

    if (cleanedId.isEmpty) {
      throw ArgumentError(
        'Recommendation ID cannot be empty.',
      );
    }

    await backendApi
        .deleteGroupRecommendation(
      recommendationId:
          cleanedId,
    );

    groupRecommendations
        .removeWhere(
      (item) =>
          item['id']?.toString() ==
          cleanedId,
    );

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // GROUP WISHLIST
  // ---------------------------------------------------------------------------

  Future<void>
      loadGroupWishlist() async {
    if (!backendApi.isAuthenticated) {
      wishlist.clear();
      groupWishlistError = null;
      groupWishlistLoading = false;

      notifyListeners();
      return;
    }

    groupWishlistLoading = true;
    groupWishlistError = null;

    notifyListeners();

    try {
      final response =
          await backendApi
              .getGroupWishlist();

      final data =
          response['wishlist'];

      final loaded =
          <WishlistItem>[];

      if (data is List) {
        for (final item in data) {
          if (item is! Map) {
            continue;
          }

          final map =
              Map<String, dynamic>.from(
            item,
          );

          final id =
              map['id']?.toString() ??
                  '';

          if (id.isEmpty) {
            continue;
          }

          loaded.add(
            WishlistItem(
              id: id,
              title:
                  map['title']
                          ?.toString() ??
                      id,
              type:
                  map['type']
                          ?.toString() ??
                      'unknown',
            ),
          );
        }
      }

      wishlist
        ..clear()
        ..addAll(loaded);
    } catch (error) {
      groupWishlistError =
          error.toString();
    } finally {
      groupWishlistLoading =
          false;

      notifyListeners();
    }
  }

  bool isInGroupWishlist(
    String mediaId,
  ) {
    return wishlist.any(
      (item) => item.id == mediaId,
    );
  }

  Future<void>
      removeFromGroupWishlist(
    String mediaId,
  ) async {
    if (!backendApi.isAuthenticated) {
      throw BackendApiException(
        'You must be logged in.',
      );
    }

    final cleanedId =
        mediaId.trim();

    if (cleanedId.isEmpty) {
      throw ArgumentError(
        'Media ID cannot be empty.',
      );
    }

    await backendApi
        .removeFromGroupWishlist(
      mediaId: cleanedId,
    );

    wishlist.removeWhere(
      (item) => item.id == cleanedId,
    );

    notifyListeners();
  }

  Future<void>
      acquireGroupWishlistItem({
    required String mediaId,
    required String profileId,
  }) async {
    if (!backendApi.isAuthenticated) {
      throw BackendApiException(
        'You must be logged in.',
      );
    }

    final cleanedMediaId =
        mediaId.trim();

    final cleanedProfileId =
        profileId.trim();

    if (cleanedMediaId.isEmpty) {
      throw ArgumentError(
        'Media ID cannot be empty.',
      );
    }

    if (cleanedProfileId.isEmpty) {
      throw ArgumentError(
        'Profile ID cannot be empty.',
      );
    }

    final response =
        await backendApi
            .acquireGroupWishlistItem(
      mediaId:
          cleanedMediaId,
      profileId:
          cleanedProfileId,
    );

    wishlist.removeWhere(
      (item) =>
          item.id ==
          cleanedMediaId,
    );

    final mediaData =
        response['media'];

    if (mediaData is Map) {
      final media =
          MediaItem.fromJson(
        Map<String, dynamic>.from(
          mediaData,
        ),
      );

      if (media.id.isNotEmpty &&
          !isOwned(media.id)) {
        library.add(media);

        _addActivity(
          title: media.title,
          action:
              'Added from group wishlist',
        );
      }
    }

    notifyListeners();

    await loadGroupWishlist();
  }

  // ---------------------------------------------------------------------------
  // BACKWARD-COMPATIBLE LOCAL WISHLIST API
  // ---------------------------------------------------------------------------

  bool isInWishlist(
    String mediaId,
  ) {
    return wishlist.any(
      (item) => item.id == mediaId,
    );
  }

  void addToWishlist(
    MediaItem media,
  ) {
    if (isInWishlist(media.id)) {
      return;
    }

    wishlist.add(
      WishlistItem(
        id: media.id,
        title: media.title,
        type: media.type,
      ),
    );

    notifyListeners();
  }

  void removeFromWishlist(
    String mediaId,
  ) {
    wishlist.removeWhere(
      (item) => item.id == mediaId,
    );

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // GROUP WATCH
  // ---------------------------------------------------------------------------

  /// Loads every Group Watch session belonging to the authenticated account.
  Future<void>
      loadGroupWatchSessions() async {
    if (!backendApi.isAuthenticated) {
      groupWatchSessions.clear();
      activeGroupWatchSessionId = null;
      groupWatchError = null;
      groupWatchLoading = false;

      notifyListeners();
      return;
    }

    groupWatchLoading = true;
    groupWatchError = null;

    notifyListeners();

    try {
      final response =
          await backendApi
              .getGroupWatchSessions();

      final data =
          response['sessions'];

      final loaded =
          <GroupWatchSession>[];

      if (data is List) {
        for (final item in data) {
          if (item is! Map) {
            continue;
          }

          final session =
              GroupWatchSession.fromJson(
            Map<String, dynamic>.from(
              item,
            ),
            knownProfiles:
                currentAccount?.profiles ??
                const <Profile>[],
          );

          if (session.id.isNotEmpty) {
            loaded.add(session);
          }
        }
      }

      groupWatchSessions
        ..clear()
        ..addAll(loaded);

      final activeId =
          activeGroupWatchSessionId;

      if (activeId != null &&
          !groupWatchSessions.any(
            (session) =>
                session.id == activeId,
          )) {
        activeGroupWatchSessionId = null;
      }
    } catch (error) {
      groupWatchError =
          error.toString();

      debugPrint(
        'Failed to load Group Watch sessions: $error',
      );
    } finally {
      groupWatchLoading = false;

      notifyListeners();
    }
  }

  /// Returns a locally cached Group Watch session by ID.
  GroupWatchSession?
      getGroupWatchSession(
    String sessionId,
  ) {
    final cleanedId =
        sessionId.trim();

    if (cleanedId.isEmpty) {
      return null;
    }

    for (final session
        in groupWatchSessions) {
      if (session.id == cleanedId) {
        return session;
      }
    }

    return null;
  }

  /// Marks a Group Watch session as the session currently being watched.
  void setActiveGroupWatchSession(
    String? sessionId,
  ) {
    final cleanedId =
        sessionId?.trim();

    if (cleanedId == null ||
        cleanedId.isEmpty) {
      activeGroupWatchSessionId = null;
    } else {
      activeGroupWatchSessionId =
          cleanedId;
    }

    notifyListeners();
  }

  /// Refreshes one Group Watch session from the backend.
  Future<GroupWatchSession?>
      refreshGroupWatchSession(
    String sessionId,
  ) async {
    if (!backendApi.isAuthenticated) {
      throw BackendApiException(
        'You must be logged in.',
      );
    }

    final cleanedId =
        sessionId.trim();

    if (cleanedId.isEmpty) {
      throw ArgumentError(
        'Group Watch session ID cannot be empty.',
      );
    }

    final response =
        await backendApi
            .getGroupWatchSession(
      sessionId: cleanedId,
    );

    final sessionData =
        response['session'];

    if (sessionData is! Map) {
      return null;
    }

    final session =
        GroupWatchSession.fromJson(
      Map<String, dynamic>.from(
        sessionData,
      ),
      knownProfiles:
          currentAccount?.profiles ??
          const <Profile>[],
    );

    _upsertGroupWatchSession(
      session,
    );

    notifyListeners();

    return session;
  }

  /// Creates a local Group Watch session for backwards compatibility with
  /// older UI code.
  ///
  /// The real backend-connected implementation is
  /// [createBackendGroupWatchSession].
  ///
  /// This compatibility method does not claim that the backend session was
  /// created. The player will be migrated to the backend method in the next
  /// implementation step.
  GroupWatchSession createGroupWatchSession(
    MediaItem media, {
    String? profileId,
    Set<String>? invitedProfileIds,
    int? invitationDurationHours,
  }) {
    final selectedProfileId =
        (profileId ??
                currentProfile?.id ??
                '')
            .trim();

    final invited =
        invitedProfileIds == null
            ? <String>{}
            : Set<String>.from(
                invitedProfileIds,
              );

    invited.removeWhere(
      (id) => id.trim().isEmpty,
    );

    invited.remove(selectedProfileId);

    final sessionId =
        _generateId('group-watch');

    final participantStates =
        <String, GroupWatchParticipant>{};

    if (selectedProfileId.isNotEmpty) {
      participantStates[
          selectedProfileId] =
          GroupWatchParticipant(
        profileId:
            selectedProfileId,
        profileName:
            _profileNameForId(
          selectedProfileId,
        ),
        invitationStatus:
            'accepted',
        joinedAt:
            DateTime.now(),
      );
    }

    for (final invitedId
        in invited) {
      final cleanId =
          invitedId.trim();

      participantStates[cleanId] =
          GroupWatchParticipant(
        profileId: cleanId,
        profileName:
            _profileNameForId(
          cleanId,
        ),
        invitationStatus:
            'pending',
      );
    }

    DateTime? invitationExpiresAt;

    if (invitationDurationHours != null &&
        invitationDurationHours > 0) {
      invitationExpiresAt =
          DateTime.now().add(
        Duration(
          hours:
              invitationDurationHours,
        ),
      );
    } else if (invited.isNotEmpty) {
      invitationExpiresAt =
          DateTime.now().add(
        const Duration(
          hours: 24,
        ),
      );
    }

    final session =
        GroupWatchSession(
      id: sessionId,
      title: media.title,
      mediaId: media.id,
      type: _backendMediaType(
        media.type,
      ),
      hostProfileId:
          selectedProfileId,
      participants:
          participantStates.values
              .map(
                (participant) =>
                    participant.profileName,
              )
              .toList(),
      participantStates:
          participantStates,
      status: 'waiting',
      invitationExpiresAt:
          invitationExpiresAt,
    );

    _upsertGroupWatchSession(
      session,
    );

    activeGroupWatchSessionId =
        session.id;

    notifyListeners();

    return session;
  }

  /// Creates a real backend Group Watch session.
  ///
  /// The selected profile becomes the host. Invited profiles are individual
  /// profiles from the same account.
  Future<GroupWatchSession>
      createBackendGroupWatchSession(
    MediaItem media, {
    String? profileId,
    Set<String>? invitedProfileIds,
    int? invitationDurationHours,
  }) async {
    if (!backendApi.isAuthenticated) {
      throw BackendApiException(
        'You must be logged in before creating a Group Watch.',
      );
    }

    final selectedProfileId =
        (profileId ??
                currentProfile?.id ??
                '')
            .trim();

    if (selectedProfileId.isEmpty) {
      throw ArgumentError(
        'A host profile is required.',
      );
    }

    if (!_accountHasProfile(
      selectedProfileId,
    )) {
      throw ArgumentError(
        'The selected host profile does not belong to the current account.',
      );
    }

    final cleanedMediaId =
        media.id.trim();

    if (cleanedMediaId.isEmpty) {
      throw ArgumentError(
        'Media ID cannot be empty.',
      );
    }

    final cleanedTitle =
        media.title.trim();

    if (cleanedTitle.isEmpty) {
      throw ArgumentError(
        'Media title cannot be empty.',
      );
    }

    if (invitationDurationHours != null &&
        invitationDurationHours <= 0) {
      throw ArgumentError(
        'Invitation duration must be greater than zero.',
      );
    }

    final invited =
        invitedProfileIds == null
            ? <String>{}
            : Set<String>.from(
                invitedProfileIds,
              );

    invited.removeWhere(
      (id) => id.trim().isEmpty,
    );

    invited.remove(selectedProfileId);

    for (final invitedId
        in invited) {
      if (!_accountHasProfile(
        invitedId.trim(),
      )) {
        throw ArgumentError(
          'One or more invited profiles do not belong to the current account.',
        );
      }
    }

    groupWatchLoading = true;
    groupWatchError = null;

    notifyListeners();

    try {
      final response =
          await backendApi
              .createGroupWatchSession(
        mediaId: cleanedMediaId,
        title: cleanedTitle,
        type: _backendMediaType(
          media.type,
        ),
        profileId: selectedProfileId,
        invitedProfileIds: invited,
        invitationDurationHours:
            invitationDurationHours,
      );

      final sessionData =
          response['session'];

      if (sessionData is! Map) {
        throw BackendApiException(
          'The server returned an invalid Group Watch session.',
        );
      }

      final session =
          GroupWatchSession.fromJson(
        Map<String, dynamic>.from(
          sessionData,
        ),
        knownProfiles:
            currentAccount?.profiles ??
            const <Profile>[],
      );

      _upsertGroupWatchSession(
        session,
      );

      activeGroupWatchSessionId =
          session.id;

      groupWatchError = null;

      return session;
    } catch (error) {
      groupWatchError =
          error.toString();
      rethrow;
    } finally {
      groupWatchLoading = false;

      notifyListeners();
    }
  }

  /// Accepts an invitation for a profile.
  ///
  /// If the invitation has expired or the session has already started, the
  /// backend rejects the request. The UI can surface the backend's exact
  /// "This invite has expired" message.
  Future<GroupWatchSession>
      acceptGroupWatchInvitation({
    required String sessionId,
    String? profileId,
  }) async {
    final selectedProfileId =
        (profileId ??
                currentProfile?.id ??
                '')
            .trim();

    if (selectedProfileId.isEmpty) {
      throw ArgumentError(
        'A profile ID is required.',
      );
    }

    if (!_accountHasProfile(
      selectedProfileId,
    )) {
      throw ArgumentError(
        'The selected profile does not belong to the current account.',
      );
    }

    final cleanedSessionId =
        sessionId.trim();

    if (cleanedSessionId.isEmpty) {
      throw ArgumentError(
        'Group Watch session ID cannot be empty.',
      );
    }

    final response =
        await backendApi
            .acceptGroupWatchInvitation(
      sessionId:
          cleanedSessionId,
      profileId:
          selectedProfileId,
    );

    final session =
        _sessionFromResponse(
      response,
    );

    _upsertGroupWatchSession(
      session,
    );

    sendGroupMessage(
      message:
          '${_profileNameForId(selectedProfileId)} joined the Group Watch — "${session.title}"',
    );

    notifyListeners();

    return session;
  }

  /// Declines an invitation for a profile.
  Future<GroupWatchSession>
      declineGroupWatchInvitation({
    required String sessionId,
    String? profileId,
  }) async {
    final selectedProfileId =
        (profileId ??
                currentProfile?.id ??
                '')
            .trim();

    if (selectedProfileId.isEmpty) {
      throw ArgumentError(
        'A profile ID is required.',
      );
    }

    if (!_accountHasProfile(
      selectedProfileId,
    )) {
      throw ArgumentError(
        'The selected profile does not belong to the current account.',
      );
    }

    final cleanedSessionId =
        sessionId.trim();

    if (cleanedSessionId.isEmpty) {
      throw ArgumentError(
        'Group Watch session ID cannot be empty.',
      );
    }

    final response =
        await backendApi
            .declineGroupWatchInvitation(
      sessionId:
          cleanedSessionId,
      profileId:
          selectedProfileId,
    );

    final session =
        _sessionFromResponse(
      response,
    );

    _upsertGroupWatchSession(
      session,
    );

    notifyListeners();

    return session;
  }

  /// Sets the current participant's audio track.
  ///
  /// This changes audio only for the specified participant.
  Future<GroupWatchSession>
      setGroupWatchAudioTrack({
    required String sessionId,
    String? profileId,
    String? audioTrackId,
  }) async {
    final selectedProfileId =
        (profileId ??
                currentProfile?.id ??
                '')
            .trim();

    if (selectedProfileId.isEmpty) {
      throw ArgumentError(
        'A profile ID is required.',
      );
    }

    final cleanedSessionId =
        sessionId.trim();

    if (cleanedSessionId.isEmpty) {
      throw ArgumentError(
        'Group Watch session ID cannot be empty.',
      );
    }

    final cleanedTrackId =
        audioTrackId?.trim();

    final response =
        await backendApi
            .setGroupWatchAudioTrack(
      sessionId:
          cleanedSessionId,
      profileId:
          selectedProfileId,
      audioTrackId:
          cleanedTrackId?.isEmpty == true
              ? null
              : cleanedTrackId,
    );

    final session =
        _sessionFromResponse(
      response,
    );

    _upsertGroupWatchSession(
      session,
    );

    notifyListeners();

    return session;
  }

  /// Sets the current participant's subtitle track.
  ///
  /// This changes subtitles only for the specified participant.
  Future<GroupWatchSession>
      setGroupWatchSubtitleTrack({
    required String sessionId,
    String? profileId,
    String? subtitleTrackId,
  }) async {
    final selectedProfileId =
        (profileId ??
                currentProfile?.id ??
                '')
            .trim();

    if (selectedProfileId.isEmpty) {
      throw ArgumentError(
        'A profile ID is required.',
      );
    }

    final cleanedSessionId =
        sessionId.trim();

    if (cleanedSessionId.isEmpty) {
      throw ArgumentError(
        'Group Watch session ID cannot be empty.',
      );
    }

    final cleanedTrackId =
        subtitleTrackId?.trim();

    final response =
        await backendApi
            .setGroupWatchSubtitleTrack(
      sessionId:
          cleanedSessionId,
      profileId:
          selectedProfileId,
      subtitleTrackId:
          cleanedTrackId?.isEmpty == true
              ? null
              : cleanedTrackId,
    );

    final session =
        _sessionFromResponse(
      response,
    );

    _upsertGroupWatchSession(
      session,
    );

    notifyListeners();

    return session;
  }

  /// Starts Group Watch playback for everyone.
  Future<GroupWatchSession>
      startGroupWatchSession({
    required String sessionId,
    String? profileId,
  }) async {
    final selectedProfileId =
        (profileId ??
                currentProfile?.id ??
                '')
            .trim();

    if (selectedProfileId.isEmpty) {
      throw ArgumentError(
        'A profile ID is required.',
      );
    }

    final cleanedSessionId =
        sessionId.trim();

    if (cleanedSessionId.isEmpty) {
      throw ArgumentError(
        'Group Watch session ID cannot be empty.',
      );
    }

    final response =
        await backendApi
            .startGroupWatchSession(
      sessionId:
          cleanedSessionId,
      profileId:
          selectedProfileId,
    );

    final session =
        _sessionFromResponse(
      response,
    );

    _upsertGroupWatchSession(
      session,
    );

    activeGroupWatchSessionId =
        session.id;

    notifyListeners();

    return session;
  }

  /// Starts global playback.
  Future<GroupWatchSession>
      playGroupWatchSession({
    required String sessionId,
    String? profileId,
  }) async {
    final selectedProfileId =
        (profileId ??
                currentProfile?.id ??
                '')
            .trim();

    if (selectedProfileId.isEmpty) {
      throw ArgumentError(
        'A profile ID is required.',
      );
    }

    final cleanedSessionId =
        sessionId.trim();

    if (cleanedSessionId.isEmpty) {
      throw ArgumentError(
        'Group Watch session ID cannot be empty.',
      );
    }

    final response =
        await backendApi
            .playGroupWatchSession(
      sessionId:
          cleanedSessionId,
      profileId:
          selectedProfileId,
    );

    final session =
        _sessionFromResponse(
      response,
    );

    _upsertGroupWatchSession(
      session,
    );

    activeGroupWatchSessionId =
        session.id;

    notifyListeners();

    return session;
  }

  /// Pauses playback for EVERYONE.
  ///
  /// The backend stores the pausing profile and reason. The same reason is
  /// posted to the local group chat.
  Future<GroupWatchSession>
      pauseGroupWatchSession({
    required String sessionId,
    required String reason,
    String? profileId,
  }) async {
    final selectedProfileId =
        (profileId ??
                currentProfile?.id ??
                '')
            .trim();

    final cleanedReason =
        reason.trim();

    if (selectedProfileId.isEmpty) {
      throw ArgumentError(
        'A profile ID is required.',
      );
    }

    if (cleanedReason.isEmpty) {
      throw ArgumentError(
        'A pause reason is required.',
      );
    }

    final cleanedSessionId =
        sessionId.trim();

    if (cleanedSessionId.isEmpty) {
      throw ArgumentError(
        'Group Watch session ID cannot be empty.',
      );
    }

    final response =
        await backendApi
            .pauseGroupWatchSession(
      sessionId:
          cleanedSessionId,
      profileId:
          selectedProfileId,
      reason:
          cleanedReason,
    );

    final session =
        _sessionFromResponse(
      response,
    );

    _upsertGroupWatchSession(
      session,
    );

    final profileName =
        _profileNameForId(
      selectedProfileId,
    );

    sendGroupMessage(
      message:
          '$profileName paused the Group Watch — ${_pauseReasonDisplay(cleanedReason)}',
    );

    notifyListeners();

    return session;
  }

  /// Resumes global playback.
  ///
  /// Only the profile that paused the session is permitted to resume.
  Future<GroupWatchSession>
      resumeGroupWatchSession({
    required String sessionId,
    String? profileId,
  }) async {
    final selectedProfileId =
        (profileId ??
                currentProfile?.id ??
                '')
            .trim();

    if (selectedProfileId.isEmpty) {
      throw ArgumentError(
        'A profile ID is required.',
      );
    }

    final cleanedSessionId =
        sessionId.trim();

    if (cleanedSessionId.isEmpty) {
      throw ArgumentError(
        'Group Watch session ID cannot be empty.',
      );
    }

    final localSession =
        getGroupWatchSession(
      cleanedSessionId,
    );

    if (localSession != null &&
        localSession.pausedByProfileId !=
            null &&
        localSession.pausedByProfileId !=
            selectedProfileId) {
      throw BackendApiException(
        'Only the person who paused the Group Watch can resume it.',
      );
    }

    final response =
        await backendApi
            .resumeGroupWatchSession(
      sessionId:
          cleanedSessionId,
      profileId:
          selectedProfileId,
    );

    final session =
        _sessionFromResponse(
      response,
    );

    _upsertGroupWatchSession(
      session,
    );

    notifyListeners();

    return session;
  }

  /// Updates the shared playback position.
  Future<GroupWatchSession>
      updateGroupWatchPosition({
    required String sessionId,
    required Duration position,
    String? profileId,
  }) async {
    final selectedProfileId =
        (profileId ??
                currentProfile?.id ??
                '')
            .trim();

    if (selectedProfileId.isEmpty) {
      throw ArgumentError(
        'A profile ID is required.',
      );
    }

    if (position.isNegative) {
      throw ArgumentError(
        'Playback position cannot be negative.',
      );
    }

    final cleanedSessionId =
        sessionId.trim();

    if (cleanedSessionId.isEmpty) {
      throw ArgumentError(
        'Group Watch session ID cannot be empty.',
      );
    }

    final response =
        await backendApi
            .updateGroupWatchPosition(
      sessionId:
          cleanedSessionId,
      profileId:
          selectedProfileId,
      position:
          position,
    );

    final session =
        _sessionFromResponse(
      response,
    );

    _upsertGroupWatchSession(
      session,
    );

    notifyListeners();

    return session;
  }

  /// Ends Group Watch for everyone.
  Future<GroupWatchSession>
      endGroupWatchSession({
    required String sessionId,
    String? profileId,
  }) async {
    final selectedProfileId =
        (profileId ??
                currentProfile?.id ??
                '')
            .trim();

    if (selectedProfileId.isEmpty) {
      throw ArgumentError(
        'A profile ID is required.',
      );
    }

    final cleanedSessionId =
        sessionId.trim();

    if (cleanedSessionId.isEmpty) {
      throw ArgumentError(
        'Group Watch session ID cannot be empty.',
      );
    }

    final response =
        await backendApi
            .endGroupWatchSession(
      sessionId:
          cleanedSessionId,
      profileId:
          selectedProfileId,
    );

    final session =
        _sessionFromResponse(
      response,
    );

    _upsertGroupWatchSession(
      session,
    );

    if (activeGroupWatchSessionId ==
        session.id) {
      activeGroupWatchSessionId = null;
    }

    notifyListeners();

    return session;
  }

  /// Deletes a Group Watch session.
  Future<void>
      deleteGroupWatchSession(
    String sessionId, {
    String? profileId,
  }) async {
    final selectedProfileId =
        (profileId ??
                currentProfile?.id ??
                '')
            .trim();

    if (selectedProfileId.isEmpty) {
      throw ArgumentError(
        'A profile ID is required.',
      );
    }

    final cleanedSessionId =
        sessionId.trim();

    if (cleanedSessionId.isEmpty) {
      throw ArgumentError(
        'Group Watch session ID cannot be empty.',
      );
    }

    await backendApi
        .deleteGroupWatchSession(
      sessionId:
          cleanedSessionId,
      profileId:
          selectedProfileId,
    );

    groupWatchSessions
        .removeWhere(
      (session) =>
          session.id ==
          cleanedSessionId,
    );

    if (activeGroupWatchSessionId ==
        cleanedSessionId) {
      activeGroupWatchSessionId = null;
    }

    notifyListeners();
  }

  /// Returns whether the specified profile can resume the session.
  bool canResumeGroupWatchSession(
    String sessionId, {
    String? profileId,
  }) {
    final selectedProfileId =
        (profileId ??
                currentProfile?.id ??
                '')
            .trim();

    final session =
        getGroupWatchSession(
      sessionId,
    );

    if (session == null) {
      return false;
    }

    return session.canResume(
      selectedProfileId,
    );
  }

  /// Returns the participant state for a profile.
  GroupWatchParticipant?
      getGroupWatchParticipant({
    required String sessionId,
    String? profileId,
  }) {
    final selectedProfileId =
        (profileId ??
                currentProfile?.id ??
                '')
            .trim();

    final session =
        getGroupWatchSession(
      sessionId,
    );

    if (session == null) {
      return null;
    }

    return session.participantForProfile(
      selectedProfileId,
    );
  }

  String? getGroupWatchAudioTrack({
    required String sessionId,
    String? profileId,
  }) {
    return getGroupWatchParticipant(
      sessionId: sessionId,
      profileId: profileId,
    )?.audioTrackId;
  }

  String? getGroupWatchSubtitleTrack({
    required String sessionId,
    String? profileId,
  }) {
    return getGroupWatchParticipant(
      sessionId: sessionId,
      profileId: profileId,
    )?.subtitleTrackId;
  }

  Duration getGroupWatchPosition(
    String sessionId,
  ) {
    return getGroupWatchSession(
          sessionId,
        )?.playbackPosition ??
        Duration.zero;
  }

  bool isGroupWatchPlaying(
    String sessionId,
  ) {
    return getGroupWatchSession(
          sessionId,
        )?.isPlaying ??
        false;
  }

  /// Returns whether a Group Watch invitation is no longer joinable.
  bool isGroupWatchInvitationExpired(
    String sessionId,
  ) {
    final session =
        getGroupWatchSession(
      sessionId,
    );

    return session?.invitationsExpired ??
        true;
  }

  /// Returns the exact UI message used when an invitation is no longer
  /// joinable.
  String groupWatchInvitationExpiredMessage(
    String sessionId,
  ) {
    if (isGroupWatchInvitationExpired(
      sessionId,
    )) {
      return 'This invite has expired';
    }

    return '';
  }

  /// Compatibility method retained for older UI code.
  ///
  /// Real Group Watch synchronization is always controlled by the backend.
  void toggleGroupWatchSync(
    String sessionId,
  ) {
    final session =
        getGroupWatchSession(
      sessionId,
    );

    if (session == null) {
      return;
    }

    session.synchronized =
        !session.synchronized;

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // MUSIC ACTIVITY
  // ---------------------------------------------------------------------------

  void recordMusicActivity(
    String title,
  ) {
    _addActivity(
      title: title,
      action: 'Played music',
    );

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // NEXT EPISODE
  // ---------------------------------------------------------------------------

  String? getNextEpisode(
    String mediaId,
  ) {
    return nextEpisodes[mediaId];
  }

  void setNextEpisode(
    String mediaId,
    String episodeTitle,
  ) {
    nextEpisodes[mediaId] =
        episodeTitle;

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // RESET
  // ---------------------------------------------------------------------------

  void reset() {
    backendApi.clearToken();

    currentAccount = null;
    currentProfile = null;

    library.clear();
    watched.clear();
    liked.clear();
    disliked.clear();

    activity.clear();
    groupMessages.clear();
    wishlist.clear();
    groupWatchSessions.clear();

    playbackProgress.clear();
    nextEpisodes.clear();
    activeProfileIds.clear();

    recommendations.clear();
    recommendationsLoading = false;
    recommendationsError = null;

    groupRecommendations.clear();
    groupRecommendationsLoading =
        false;
    groupRecommendationsError = null;

    wishlist.clear();
    groupWishlistLoading = false;
    groupWishlistError = null;

    groupWatchLoading = false;
    groupWatchError = null;
    activeGroupWatchSessionId = null;

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // GROUP RECOMMENDATION HELPERS
  // ---------------------------------------------------------------------------

  String _profileNameForId(
    String profileId,
  ) {
    final account = currentAccount;

    if (account != null) {
      for (final profile
          in account.profiles) {
        if (profile.id == profileId) {
          return profile.name;
        }
      }
    }

    if (currentProfile?.id ==
        profileId) {
      return currentProfile!.name;
    }

    return 'Profile';
  }

  bool _accountHasProfile(
    String profileId,
  ) {
    final account = currentAccount;

    if (account == null) {
      return false;
    }

    return account.profiles.any(
      (profile) =>
          profile.id == profileId,
    );
  }

  int _intFromValue(
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

  double _doubleFromValue(
    dynamic value, {
    required double fallback,
  }) {
    if (value is num) {
      return value.toDouble();
    }

    final parsed =
        double.tryParse(
      value?.toString() ?? '',
    );

    return parsed ?? fallback;
  }

  double _percentage(
    int votes,
    int total,
  ) {
    if (total <= 0) {
      return 0;
    }

    return (votes / total) * 100;
  }

  String _formatPercentage(
    double value,
  ) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(1);
  }

  // ---------------------------------------------------------------------------
  // GROUP WATCH HELPERS
  // ---------------------------------------------------------------------------

  GroupWatchSession
      _sessionFromResponse(
    Map<String, dynamic> response,
  ) {
    final sessionData =
        response['session'];

    if (sessionData is! Map) {
      throw BackendApiException(
        'The server returned an invalid Group Watch session.',
      );
    }

    return GroupWatchSession.fromJson(
      Map<String, dynamic>.from(
        sessionData,
      ),
      knownProfiles:
          currentAccount?.profiles ??
          const <Profile>[],
    );
  }

  void _upsertGroupWatchSession(
    GroupWatchSession session,
  ) {
    if (session.id.isEmpty) {
      return;
    }

    final index =
        groupWatchSessions.indexWhere(
      (item) => item.id == session.id,
    );

    if (index == -1) {
      groupWatchSessions.insert(
        0,
        session,
      );
      return;
    }

    groupWatchSessions[index] =
        session;
  }

  String _backendMediaType(
    String type,
  ) {
    final cleaned =
        type.trim().toLowerCase();

    if (cleaned == 'tvshow' ||
        cleaned == 'tv_show' ||
        cleaned == 'tv show' ||
        cleaned == 'series' ||
        cleaned == 'episode') {
      return 'tvShow';
    }

    return 'movie';
  }

  String _pauseReasonDisplay(
    String reason,
  ) {
    final cleaned =
        reason.trim();

    switch (cleaned.toLowerCase()) {
      case 'voy a cargar':
        return '🔋 Voy a cargar';

      case 'voy por un snack':
        return '🍿 Voy por un snack';

      case 'otro':
        return '💬 Otro';

      default:
        return '💬 $cleaned';
    }
  }

  // ---------------------------------------------------------------------------
  // ID GENERATION
  // ---------------------------------------------------------------------------

  String _generateId(
    String prefix,
  ) {
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}';
  }
}

// -----------------------------------------------------------------------------
// GROUP WATCH / JSON HELPERS
// -----------------------------------------------------------------------------

DateTime? _dateTimeFromJson(
  dynamic value,
) {
  if (value is DateTime) {
    return value;
  }

  if (value == null) {
    return null;
  }

  return DateTime.tryParse(
    value.toString(),
  );
}

double _doubleFromJson(
  dynamic value,
) {
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(
        value?.toString() ?? '',
      ) ??
      0;
}

Profile? _profileFromList(
  List<Profile> profiles,
  String profileId,
) {
  for (final profile in profiles) {
    if (profile.id == profileId) {
      return profile;
    }
  }

  return null;
}
// -----------------------------------------------------------------------------
// DETAILS CUSTOMIZATION
// -----------------------------------------------------------------------------

class DetailsCustomization {
  bool showPoster;
  bool showTitle;
  bool showMetadata;
  bool showOwnership;
  bool showDescription;
  bool showSeasons;
  bool showPlay;
  bool showTrailer;
  bool showGroupWatch;
  bool showAudioSubtitles;
  bool showReactions;
  bool showInformation;
  bool showLibrary;

  bool showReleaseYear;
  bool showRating;
  bool showContentRating;
  bool showRuntime;

  String posterStyle;
  String titleAlignment;
  String seasonPlacement;
  String seasonOrder;

  List<String> sectionOrder;

  DetailsCustomization({
    this.showPoster = true,
    this.showTitle = true,
    this.showMetadata = true,
    this.showOwnership = true,
    this.showDescription = true,
    this.showSeasons = true,
    this.showPlay = true,
    this.showTrailer = true,
    this.showGroupWatch = true,
    this.showAudioSubtitles = true,
    this.showReactions = true,
    this.showInformation = true,
    this.showLibrary = true,
    this.showReleaseYear = true,
    this.showRating = true,
    this.showContentRating = true,
    this.showRuntime = true,
    this.posterStyle = 'Standard',
    this.titleAlignment = 'Left',
    this.seasonPlacement = 'Center',
    this.seasonOrder = 'Top to Bottom',
    List<String>? sectionOrder,
  }) : sectionOrder = sectionOrder ??
            [
              'Poster',
              'Title',
              'Metadata',
              'Ownership',
              'Description',
              'Seasons',
              'Play',
              'Trailer',
              'Group Watch',
              'Audio & Subtitles',
              'Reactions',
              'Information',
              'Library',
            ];

  DetailsCustomization copy() {
    return DetailsCustomization(
      showPoster: showPoster,
      showTitle: showTitle,
      showMetadata: showMetadata,
      showOwnership: showOwnership,
      showDescription: showDescription,
      showSeasons: showSeasons,
      showPlay: showPlay,
      showTrailer: showTrailer,
      showGroupWatch: showGroupWatch,
      showAudioSubtitles: showAudioSubtitles,
      showReactions: showReactions,
      showInformation: showInformation,
      showLibrary: showLibrary,
      showReleaseYear: showReleaseYear,
      showRating: showRating,
      showContentRating: showContentRating,
      showRuntime: showRuntime,
      posterStyle: posterStyle,
      titleAlignment: titleAlignment,
      seasonPlacement: seasonPlacement,
      seasonOrder: seasonOrder,
      sectionOrder: List<String>.from(sectionOrder),
    );
  }
}

class DetailsCustomizationStore {
  DetailsCustomizationStore._();

  static final Map<String, DetailsCustomization> _settings =
      <String, DetailsCustomization>{};

  static DetailsCustomization settingsFor(Profile? profile) {
    final key = profile?.id ?? 'default';

    return _settings
        .putIfAbsent(
          key,
          () => DetailsCustomization(),
        )
        .copy();
  }

  static void apply(
    Profile? profile,
    DetailsCustomization value,
  ) {
    final key = profile?.id ?? 'default';
    _settings[key] = value.copy();
  }

  static void removeProfile(Profile profile) {
    _settings.remove(profile.id);
  }

  static void clear() {
    _settings.clear();
  }
}