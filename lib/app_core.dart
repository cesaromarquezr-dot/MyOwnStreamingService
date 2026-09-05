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

  MediaItem({
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
      'profiles':
          profiles.map((profile) => profile.toJson()).toList(),
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

class GroupWatchSession {
  final String id;
  final String title;
  final List<String> participants;
  bool synchronized;

  GroupWatchSession({
    required this.id,
    required this.title,
    required this.participants,
    this.synchronized = true,
  });
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

    recommendationsError = null;
    recommendationsLoading = false;

    groupRecommendationsError =
        null;

    groupRecommendationsLoading =
        false;

    groupWishlistError = null;
    groupWishlistLoading = false;

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

    recommendationsError = null;
    recommendationsLoading = false;

    groupRecommendationsError =
        null;

    groupRecommendationsLoading =
        false;

    groupWishlistError = null;
    groupWishlistLoading = false;

    notifyListeners();

    await loadRecommendations();
    await loadGroupWishlist();
    await loadGroupRecommendations();
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
    String name,
  ) {
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

    final profile =
        Profile(
      id: _generateId('profile'),
      name: name.trim().isEmpty
          ? 'Profile ${currentAccount!.profiles.length + 1}'
          : name.trim(),
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

  /// Creates a group recommendation.
  ///
  /// The recommendation does NOT have to exist in the catalog.
  ///
  /// title:
  ///   The movie or TV show name entered by the user.
  ///
  /// type:
  ///   "movie" or "tvShow".
  ///
  /// mediaId:
  ///   Optional catalog media ID. Leave null for manually entered
  ///   recommendations.
  ///
  /// activeParticipants:
  ///   Profiles eligible to vote.
  ///
  /// votingDurationHours:
  ///   How long voting remains open. The backend defaults to 24 hours
  ///   when this is null.
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

      // Keep the requested notification behavior in the current group chat.
      //
      // The recommendation vote itself is persisted by the backend.
      // The actual group-message persistence will be wired when the backend
      // group-chat endpoint is added.
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

  GroupWatchSession
      createGroupWatchSession(
    MediaItem media,
  ) {
    final session =
        GroupWatchSession(
      id: _generateId(
        'group-watch',
      ),
      title: media.title,
      participants: <String>[
        currentProfile?.name ??
            currentAccount?.username ??
            'You',
      ],
    );

    groupWatchSessions.add(
      session,
    );

    notifyListeners();

    return session;
  }

  void toggleGroupWatchSync(
    String sessionId,
  ) {
    for (final session
        in groupWatchSessions) {
      if (session.id ==
          sessionId) {
        session.synchronized =
            !session.synchronized;
        break;
      }
    }

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
  // ID GENERATION
  // ---------------------------------------------------------------------------

  String _generateId(
    String prefix,
  ) {
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}';
  }
}