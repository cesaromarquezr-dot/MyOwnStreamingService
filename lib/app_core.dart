import 'package:flutter/foundation.dart';

import 'backend_api.dart';

// ============================================================
// ENUMS
// ============================================================

enum MediaType {
  movie,
  tvShow,
}

enum SubscriptionPlan {
  monthly,
  yearly,
}

enum SubscriptionStatus {
  active,
  expired,
}

enum ActivityType {
  watched,
  finished,
  active,
  listening,
}

enum CollectionType {
  trilogy,
  saga,
  franchise,
  collection,
}

enum MusicType {
  song,
  soundtrack,
  score,
  theme,
}

// ============================================================
// SUBSCRIPTION
// ============================================================

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
        return 8;
      case SubscriptionPlan.yearly:
        return 50;
    }
  }

  String get displayName {
    switch (plan) {
      case SubscriptionPlan.monthly:
        return '\$8/month';
      case SubscriptionPlan.yearly:
        return '\$50/year';
    }
  }
}

// ============================================================
// AUDIO
// ============================================================

class AudioTrack {
  final String language;
  final String format;

  AudioTrack({
    required this.language,
    required this.format,
  });
}

// ============================================================
// SUBTITLES
// ============================================================

class SubtitleTrack {
  final String language;
  final bool sdh;

  SubtitleTrack({
    required this.language,
    this.sdh = false,
  });
}

// ============================================================
// CHAPTERS
// ============================================================

class Chapter {
  final String title;
  final Duration start;

  Chapter({
    required this.title,
    required this.start,
  });
}

// ============================================================
// EXTRAS
// ============================================================

class MediaExtra {
  final String title;
  final String? description;

  MediaExtra({
    required this.title,
    this.description,
  });
}

// ============================================================
// TRAILER
// ============================================================

class Trailer {
  final String youtubeVideoId;
  final String title;

  Trailer({
    required this.youtubeVideoId,
    required this.title,
  });
}

// ============================================================
// CAST
// ============================================================

class CastMember {
  final String actorId;
  final String actorName;
  final String characterName;
  final String? photoUrl;

  CastMember({
    required this.actorId,
    required this.actorName,
    required this.characterName,
    this.photoUrl,
  });
}

// ============================================================
// ACTOR
// ============================================================

class Actor {
  final String id;
  final String name;

  String photoUrl;
  String biography;
  String placeOfBirth;

  DateTime? dateOfBirth;

  String knownFor;
  String relationshipStatus;
  String partnerName;

  Actor({
    required this.id,
    required this.name,
    this.photoUrl = '',
    this.biography = '',
    this.placeOfBirth = '',
    this.dateOfBirth,
    this.knownFor = '',
    this.relationshipStatus = '',
    this.partnerName = '',
  });

  int? get age {
    if (dateOfBirth == null) return null;

    final now = DateTime.now();

    int calculatedAge =
        now.year - dateOfBirth!.year;

    final birthdayThisYear = DateTime(
      now.year,
      dateOfBirth!.month,
      dateOfBirth!.day,
    );

    if (birthdayThisYear.isAfter(now)) {
      calculatedAge--;
    }

    return calculatedAge;
  }
}

// ============================================================
// MUSIC
// ============================================================

class MusicItem {
  final String id;
  final String title;
  final String artistOrComposer;
  final String sourceMediaId;
  final MusicType type;

  DateTime addedAt;

  MusicItem({
    required this.id,
    required this.title,
    required this.artistOrComposer,
    required this.sourceMediaId,
    required this.type,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();
}

// ============================================================
// MEDIA
// ============================================================

class MediaItem {
  final String id;
  final String title;
  final MediaType type;

  final int? year;
  final String? posterUrl;

  String description;

  final List<String> genre;
  final List<String> tags;
  final List<String> themes;

  final List<CastMember> cast;
  final List<MusicItem> music;

  final Trailer? trailer;

  final List<AudioTrack> audioTracks;
  final List<SubtitleTrack> subtitleTracks;
  final List<Chapter> chapters;
  final List<MediaExtra> extras;

  bool liked;
  bool disliked;

  double progress;

  DateTime addedAt;
  DateTime? lastWatchedAt;

  // TV information
  final String? seriesId;
  final int? seasonNumber;
  final int? episodeNumber;
  final int? totalEpisodesInSeason;

  MediaItem({
    required this.id,
    required this.title,
    required this.type,
    this.year,
    this.posterUrl,
    this.description = '',
    this.genre = const [],
    this.tags = const [],
    this.themes = const [],
    this.cast = const [],
    this.music = const [],
    this.trailer,
    this.audioTracks = const [],
    this.subtitleTracks = const [],
    this.chapters = const [],
    this.extras = const [],
    this.liked = false,
    this.disliked = false,
    this.progress = 0,
    DateTime? addedAt,
    this.lastWatchedAt,
    this.seriesId,
    this.seasonNumber,
    this.episodeNumber,
    this.totalEpisodesInSeason,
  }) : addedAt = addedAt ?? DateTime.now();

  bool get isEpisode =>
      type == MediaType.tvShow &&
      seriesId != null &&
      seasonNumber != null &&
      episodeNumber != null;

  bool get isFinished =>
      progress >= 1;

  String get mediaTypeName {
    return type == MediaType.movie
        ? 'Movie'
        : 'TV Show';
  }
}

// ============================================================
// USER LIBRARY
// ============================================================

class UserLibrary {
  final List<MediaItem> media = [];

  List<MediaItem> get movies {
    return media
        .where(
          (item) => item.type == MediaType.movie,
        )
        .toList();
  }

  List<MediaItem> get tvShows {
    return media
        .where(
          (item) => item.type == MediaType.tvShow,
        )
        .toList();
  }

  List<MediaItem> get recentlyWatched {
    final result = media
        .where(
          (item) => item.lastWatchedAt != null,
        )
        .toList();

    result.sort(
      (a, b) => b.lastWatchedAt!
          .compareTo(a.lastWatchedAt!),
    );

    return result;
  }

  List<MediaItem> get continueWatching {
    return media
        .where(
          (item) =>
              item.progress > 0 &&
              item.progress < 1,
        )
        .toList();
  }

  List<MediaItem> get finished {
    return media
        .where(
          (item) => item.progress >= 1,
        )
        .toList();
  }

  void addMedia(MediaItem item) {
    final existingIndex = media.indexWhere(
      (existing) => existing.id == item.id,
    );

    if (existingIndex >= 0) {
      media[existingIndex] = item;
    } else {
      media.add(item);
    }
  }

  void removeMedia(String mediaId) {
    media.removeWhere(
      (item) => item.id == mediaId,
    );
  }

  MediaItem? findById(String id) {
    for (final item in media) {
      if (item.id == id) {
        return item;
      }
    }

    return null;
  }

  MediaItem? findNextEpisode(
    MediaItem currentEpisode,
  ) {
    if (!currentEpisode.isEpisode) {
      return null;
    }

    final nextEpisodeNumber =
        currentEpisode.episodeNumber! + 1;

    for (final mediaItem in media) {
      if (!mediaItem.isEpisode) {
        continue;
      }

      if (mediaItem.seriesId ==
              currentEpisode.seriesId &&
          mediaItem.seasonNumber ==
              currentEpisode.seasonNumber &&
          mediaItem.episodeNumber ==
              nextEpisodeNumber) {
        return mediaItem;
      }
    }

    return null;
  }
}

// ============================================================
// PROFILE
// ============================================================

class UserProfile {
  final String id;

  String name;
  String? avatarUrl;

  final UserLibrary library;

  UserProfile({
    required this.id,
    required this.name,
    this.avatarUrl,
  }) : library = UserLibrary();
}

// ============================================================
// ACCOUNT
// ============================================================

class UserAccount {
  final String username;
  final String email;
  final String password;

  Subscription? subscription;

  final List<UserProfile> profiles = [];

  UserAccount({
    required this.username,
    required this.email,
    required this.password,
    this.subscription,
  });
}

// ============================================================
// COLLECTION
// ============================================================

class MediaCollection {
  final String id;
  final String name;
  final CollectionType type;
  final List<String> mediaIds;

  MediaCollection({
    required this.id,
    required this.name,
    required this.type,
    required this.mediaIds,
  });
}

// ============================================================
// ACTIVITY
// ============================================================

class ActivityEvent {
  final String profileId;
  final String profileName;
  final ActivityType type;
  final String message;
  final DateTime timestamp;

  ActivityEvent({
    required this.profileId,
    required this.profileName,
    required this.type,
    required this.message,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

// ============================================================
// GROUP CHAT
// ============================================================

class GroupChatMessage {
  final String id;
  final String profileId;
  final String text;
  final DateTime sentAt;

  GroupChatMessage({
    required this.id,
    required this.profileId,
    required this.text,
    DateTime? sentAt,
  }) : sentAt = sentAt ?? DateTime.now();
}

// ============================================================
// WISHLIST
// ============================================================

class WishlistItem {
  final String id;
  final String title;
  final MediaType type;

  final Map<String, bool?> votesByProfileId;

  WishlistItem({
    required this.id,
    required this.title,
    required this.type,
    Map<String, bool?>? votesByProfileId,
  }) : votesByProfileId =
            votesByProfileId ?? {};

  int get yesVotes {
    return votesByProfileId.values
        .where((vote) => vote == true)
        .length;
  }

  int get noVotes {
    return votesByProfileId.values
        .where((vote) => vote == false)
        .length;
  }

  int get totalVotes {
    return votesByProfileId.values
        .where((vote) => vote != null)
        .length;
  }

  bool get majorityYes {
    return yesVotes >
        votesByProfileId.length / 2;
  }
}

// ============================================================
// GROUP WATCH
// ============================================================

class GroupWatchPreferences {
  final String profileId;

  String audioLanguage;
  bool subtitlesEnabled;
  String? subtitleLanguage;

  GroupWatchPreferences({
    required this.profileId,
    this.audioLanguage = 'Original',
    this.subtitlesEnabled = false,
    this.subtitleLanguage,
  });
}

class GroupWatchInvite {
  final String id;
  final String hostProfileId;
  final String mediaId;

  final Set<String> invitedProfileIds;

  final Map<String, bool?> responses;

  final Map<String, GroupWatchPreferences>
      preferences;

  GroupWatchInvite({
    required this.id,
    required this.hostProfileId,
    required this.mediaId,
    required this.invitedProfileIds,
    Map<String, bool?>? responses,
    Map<String, GroupWatchPreferences>?
        preferences,
  })  : responses = responses ?? {},
        preferences = preferences ?? {};
}

// ============================================================
// SEARCH RESULT
// ============================================================

class SearchResult {
  final MediaItem media;
  final String matchedBy;

  SearchResult({
    required this.media,
    required this.matchedBy,
  });
}

// ============================================================
// ARM
// ============================================================

class ArmRipStatus {
  final String jobId;
  final String status;
  final double progress;
  final String? detectedTitle;
  final String? mediaType;
  final String? message;

  ArmRipStatus({
    required this.jobId,
    required this.status,
    required this.progress,
    this.detectedTitle,
    this.mediaType,
    this.message,
  });
}

class ArmImportService {
  final String armServerUrl;

  ArmImportService({
    required this.armServerUrl,
  });

  Future<ArmRipStatus> startRip() async {
    throw UnimplementedError(
      'Connect this adapter to your backend.',
    );
  }

  Future<ArmRipStatus> getStatus(
    String jobId,
  ) async {
    throw UnimplementedError(
      'Connect this adapter to your backend.',
    );
  }
}

// ============================================================
// APP CONTROLLER
// ============================================================

class AppController extends ChangeNotifier {
  AppController._();

  static final AppController instance =
      AppController._();

  // ==========================================================
  // BACKEND
  // ==========================================================

  /// Main connection to the Dart backend.
  final BackendApi backendApi = BackendApi();

  /// Whether the Flutter app currently has a backend
  /// authentication token.
  bool get isBackendAuthenticated =>
      backendApi.isAuthenticated;

  /// The current backend authentication token.
  String? get backendToken =>
      backendApi.token;

  // ==========================================================
  // GENERAL
  // ==========================================================

  static const int maxProfiles = 7;

  UserAccount? account;

  UserProfile? currentProfile;

  final List<ActivityEvent> activityFeed = [];

  final Set<String> activeProfileIds = {};

  final List<GroupChatMessage> groupMessages = [];

  final List<WishlistItem> wishlist = [];

  final List<GroupWatchInvite> groupWatchInvites = [];

  // ==========================================================
  // LIKES
  // ==========================================================

  void toggleLike(MediaItem media) {
    if (currentProfile == null) return;

    media.liked = !media.liked;

    if (media.liked) {
      media.disliked = false;
    }

    notifyListeners();
  }

  void toggleDislike(MediaItem media) {
    if (currentProfile == null) return;

    media.disliked = !media.disliked;

    if (media.disliked) {
      media.liked = false;
    }

    notifyListeners();
  }

  // ==========================================================
  // ACCOUNT
  // ==========================================================

  /// Existing local account creation.
  ///
  /// This is kept so existing UI code continues to work.
  /// New signup screens should use createAccountWithBackend().
  void createAccount({
    required String username,
    required String email,
    required String password,
    required SubscriptionPlan plan,
    required String firstProfileName,
  }) {
    final newAccount = UserAccount(
      username: username,
      email: email,
      password: password,
      subscription: Subscription(
        plan: plan,
        status: SubscriptionStatus.active,
      ),
    );

    final firstProfile = UserProfile(
      id: _newId(),
      name: firstProfileName,
    );

    newAccount.profiles.add(
      firstProfile,
    );

    account = newAccount;

    currentProfile = firstProfile;

    activeProfileIds.clear();
    activeProfileIds.add(
      firstProfile.id,
    );

    notifyListeners();
  }

  /// Creates the account through the real backend.
  ///
  /// The backend is now responsible for:
  /// - username uniqueness
  /// - email uniqueness
  /// - password validation
  /// - first profile creation
  /// - subscription creation
  /// - authentication token creation
  Future<void> createAccountWithBackend({
    required String username,
    required String email,
    required String password,
    required SubscriptionPlan plan,
    required String firstProfileName,
  }) async {
    final data = await backendApi.signup(
      username: username.trim(),
      email: email.trim(),
      password: password,
      firstProfileName: firstProfileName.trim(),
    );

    final accountData = data['account'];

    String? backendUsername;
    String? backendEmail;

    if (accountData is Map) {
      backendUsername =
          accountData['username']?.toString();

      backendEmail =
          accountData['email']?.toString();
    }

    final usernameToUse =
        backendUsername?.isNotEmpty == true
            ? backendUsername!
            : username.trim();

    final emailToUse =
        backendEmail?.isNotEmpty == true
            ? backendEmail!
            : email.trim();

    // The backend currently creates the subscription.
    // We mirror the selected plan locally so the existing
    // frontend can continue using the same models.
    final newAccount = UserAccount(
      username: usernameToUse,
      email: emailToUse,
      password: password,
      subscription: Subscription(
        plan: plan,
        status: SubscriptionStatus.active,
      ),
    );

    final profileData =
        accountData is Map
            ? accountData['profiles']
            : null;

    if (profileData is List &&
        profileData.isNotEmpty) {
      for (final rawProfile in profileData) {
        if (rawProfile is! Map) {
          continue;
        }

        final profileId =
            rawProfile['id']?.toString();

        final profileName =
            rawProfile['name']?.toString();

        if (profileId == null ||
            profileId.isEmpty ||
            profileName == null ||
            profileName.isEmpty) {
          continue;
        }

        newAccount.profiles.add(
          UserProfile(
            id: profileId,
            name: profileName,
            avatarUrl:
                rawProfile['avatarUrl']
                    ?.toString(),
          ),
        );
      }
    }

    // Fallback in case the backend response does not
    // contain the profiles array.
    if (newAccount.profiles.isEmpty) {
      newAccount.profiles.add(
        UserProfile(
          id: _newId(),
          name: firstProfileName.trim(),
        ),
      );
    }

    account = newAccount;

    currentProfile =
        newAccount.profiles.first;

    activeProfileIds.clear();
    activeProfileIds.add(
      currentProfile!.id,
    );

    notifyListeners();
  }

  /// Existing local login.
  ///
  /// Kept for compatibility with existing screens.
  /// New login screens should use loginWithBackend().
  bool login(
    String usernameOrEmail,
    String password,
  ) {
    if (account == null) {
      return false;
    }

    final usernameMatches =
        account!.username.toLowerCase() ==
            usernameOrEmail.toLowerCase();

    final emailMatches =
        account!.email.toLowerCase() ==
            usernameOrEmail.toLowerCase();

    final passwordMatches =
        account!.password == password;

    if ((usernameMatches || emailMatches) &&
        passwordMatches) {
      currentProfile =
          account!.profiles.isNotEmpty
              ? account!.profiles.first
              : null;

      if (currentProfile != null) {
        activeProfileIds.add(
          currentProfile!.id,
        );
      }

      notifyListeners();

      return true;
    }

    return false;
  }

  /// Logs in through the backend.
  Future<void> loginWithBackend({
    required String usernameOrEmail,
    required String password,
  }) async {
    final data = await backendApi.login(
      usernameOrEmail:
          usernameOrEmail.trim(),
      password: password,
    );

    final accountData = data['account'];

    if (accountData is! Map) {
      throw Exception(
        'Backend login succeeded but no account information was returned.',
      );
    }

    final username =
        accountData['username']?.toString() ??
            usernameOrEmail.trim();

    final email =
        accountData['email']?.toString() ??
            '';

    SubscriptionPlan plan =
        SubscriptionPlan.monthly;

    final subscriptionData =
        accountData['subscription'];

    if (subscriptionData is Map) {
      final planValue =
          subscriptionData['plan']
              ?.toString()
              .toLowerCase();

      if (planValue == 'yearly') {
        plan = SubscriptionPlan.yearly;
      }
    }

    SubscriptionStatus
        subscriptionStatus =
        SubscriptionStatus.active;

    if (subscriptionData is Map) {
      final statusValue =
          subscriptionData['status']
              ?.toString()
              .toLowerCase();

      if (statusValue == 'expired') {
        subscriptionStatus =
            SubscriptionStatus.expired;
      }
    }

    final newAccount = UserAccount(
      username: username,
      email: email,
      password: password,
      subscription: Subscription(
        plan: plan,
        status: subscriptionStatus,
      ),
    );

    final profileData =
        accountData['profiles'];

    if (profileData is List) {
      for (final rawProfile in profileData) {
        if (rawProfile is! Map) {
          continue;
        }

        final profileId =
            rawProfile['id']?.toString();

        final profileName =
            rawProfile['name']?.toString();

        if (profileId == null ||
            profileId.isEmpty ||
            profileName == null ||
            profileName.isEmpty) {
          continue;
        }

        newAccount.profiles.add(
          UserProfile(
            id: profileId,
            name: profileName,
            avatarUrl:
                rawProfile['avatarUrl']
                    ?.toString(),
          ),
        );
      }
    }

    account = newAccount;

    currentProfile =
        newAccount.profiles.isNotEmpty
            ? newAccount.profiles.first
            : null;

    activeProfileIds.clear();

    if (currentProfile != null) {
      activeProfileIds.add(
        currentProfile!.id,
      );
    }

    notifyListeners();
  }

  /// Gets the authenticated account from the backend.
  Future<Map<String, dynamic>>
      refreshBackendAccount() async {
    final data =
        await backendApi.me();

    return data;
  }

  /// Logs out of both the backend session and
  /// the local frontend session.
  Future<void> logoutFromBackend() async {
    try {
      await backendApi.logout();
    } finally {
      currentProfile = null;
      activeProfileIds.clear();

      notifyListeners();
    }
  }

  /// Local logout kept for compatibility.
  void logout() {
    currentProfile = null;
    activeProfileIds.clear();

    backendApi.clearToken();

    notifyListeners();
  }

  // ==========================================================
  // SUBSCRIPTION
  // ==========================================================

  bool get hasActiveSubscription {
    return account?.subscription?.status ==
        SubscriptionStatus.active;
  }

  void subscribe(
    SubscriptionPlan plan,
  ) {
    if (account == null) return;

    account!.subscription = Subscription(
      plan: plan,
      status: SubscriptionStatus.active,
    );

    notifyListeners();
  }

  void expireSubscription() {
    if (account?.subscription == null) {
      return;
    }

    account!.subscription!.status =
        SubscriptionStatus.expired;

    notifyListeners();
  }

  // ==========================================================
  // PROFILES
  // ==========================================================

  bool addProfile(
    String name, {
    String? avatarUrl,
  }) {
    if (account == null) {
      return false;
    }

    if (account!.profiles.length >=
        maxProfiles) {
      return false;
    }

    final profile = UserProfile(
      id: _newId(),
      name: name,
      avatarUrl: avatarUrl,
    );

    account!.profiles.add(profile);

    notifyListeners();

    return true;
  }

  bool removeProfile(
    String profileId,
  ) {
    if (account == null) {
      return false;
    }

    if (account!.profiles.length <= 1) {
      return false;
    }

    account!.profiles.removeWhere(
      (profile) => profile.id == profileId,
    );

    activeProfileIds.remove(profileId);

    if (currentProfile?.id == profileId) {
      currentProfile =
          account!.profiles.first;
    }

    notifyListeners();

    return true;
  }

  bool switchProfile(
    String profileId,
  ) {
    if (account == null) {
      return false;
    }

    UserProfile? profile;

    for (final item in account!.profiles) {
      if (item.id == profileId) {
        profile = item;
        break;
      }
    }

    if (profile == null) {
      return false;
    }

    currentProfile = profile;

    activeProfileIds.add(
      profile.id,
    );

    addActivity(
      ActivityEvent(
        profileId: profile.id,
        profileName: profile.name,
        type: ActivityType.active,
        message:
            '${profile.name} is active',
      ),
    );

    notifyListeners();

    return true;
  }

  // ==========================================================
  // ARM / BACKEND
  // ==========================================================

  /// Returns the ARM drives through the authenticated
  /// backend.
  ///
  /// This does NOT directly contact the ARM server.
  /// The request goes:
  ///
  /// Flutter
  ///    ↓
  /// Dart backend
  ///    ↓
  /// ARM server
  ///
  Future<List<dynamic>> getArmDrives() async {
    if (!backendApi.isAuthenticated) {
      throw Exception(
        'You must be logged in before accessing ARM drives.',
      );
    }

    return backendApi.getArmDrives();
  }

  // ==========================================================
  // LIBRARY
  // ==========================================================

  void addMedia(
    MediaItem media,
  ) {
    if (currentProfile == null) {
      return;
    }

    currentProfile!.library.addMedia(
      media,
    );

    // If this title was on the group wishlist,
    // remove it after importing it.
    wishlist.removeWhere(
      (item) =>
          item.title.toLowerCase() ==
          media.title.toLowerCase(),
    );

    notifyListeners();
  }

  void removeMedia(
    String mediaId,
  ) {
    currentProfile?.library.removeMedia(
      mediaId,
    );

    notifyListeners();
  }

  // ==========================================================
  // PLAYBACK
  // ==========================================================

  void updateProgress(
    MediaItem media,
    double newProgress,
  ) {
    if (currentProfile == null) {
      return;
    }

    final storedMedia =
        currentProfile!.library.findById(
      media.id,
    );

    if (storedMedia == null) {
      return;
    }

    storedMedia.progress =
        newProgress.clamp(0, 1);

    storedMedia.lastWatchedAt =
        DateTime.now();

    addActivity(
      ActivityEvent(
        profileId: currentProfile!.id,
        profileName: currentProfile!.name,
        type: ActivityType.watched,
        message:
            '${currentProfile!.name} watched "${media.title}"',
      ),
    );

    notifyListeners();
  }

  void markFinished(
    MediaItem media,
  ) {
    if (currentProfile == null) {
      return;
    }

    final storedMedia =
        currentProfile!.library.findById(
      media.id,
    );

    if (storedMedia == null) {
      return;
    }

    storedMedia.progress = 1;
    storedMedia.lastWatchedAt =
        DateTime.now();

    addActivity(
      ActivityEvent(
        profileId: currentProfile!.id,
        profileName: currentProfile!.name,
        type: ActivityType.finished,
        message:
            '${currentProfile!.name} finished "${media.title}"',
      ),
    );

    notifyListeners();
  }

  MediaItem? getNextEpisode(
    MediaItem currentEpisode,
  ) {
    return currentProfile?.library
        .findNextEpisode(currentEpisode);
  }

  // ==========================================================
  // LIKES
  // ==========================================================

  void likeMedia(
    MediaItem media,
  ) {
    media.liked = true;
    media.disliked = false;

    notifyListeners();
  }

  void dislikeMedia(
    MediaItem media,
  ) {
    media.liked = false;
    media.disliked = true;

    notifyListeners();
  }

  // ==========================================================
  // ACTIVITY
  // ==========================================================

  void addActivity(
    ActivityEvent event,
  ) {
    activityFeed.insert(
      0,
      event,
    );

    if (activityFeed.length > 100) {
      activityFeed.removeLast();
    }

    notifyListeners();
  }

  void setProfileActive(
    String profileId,
    bool active,
  ) {
    if (active) {
      activeProfileIds.add(
        profileId,
      );
    } else {
      activeProfileIds.remove(
        profileId,
      );
    }

    UserProfile? profile;

    for (final item in account?.profiles ?? []) {
      if (item.id == profileId) {
        profile = item;
        break;
      }
    }

    if (profile != null) {
      addActivity(
        ActivityEvent(
          profileId: profile.id,
          profileName: profile.name,
          type: ActivityType.active,
          message: active
              ? '${profile.name} is active'
              : '${profile.name} is no longer active',
        ),
      );
    }

    notifyListeners();
  }

  // ==========================================================
  // GROUP CHAT
  // ==========================================================

  void sendGroupMessage(
    String text,
  ) {
    if (currentProfile == null) {
      return;
    }

    groupMessages.add(
      GroupChatMessage(
        id: _newId(),
        profileId: currentProfile!.id,
        text: text,
      ),
    );

    notifyListeners();
  }

  // ==========================================================
  // WISHLIST
  // ==========================================================

  void addWishlistItem(
    String title,
    MediaType type,
  ) {
    if (account == null) {
      return;
    }

    final item = WishlistItem(
      id: _newId(),
      title: title,
      type: type,
    );

    for (final profile in account!.profiles) {
      item.votesByProfileId[
          profile.id] = null;
    }

    wishlist.add(item);

    notifyListeners();
  }

  void voteWishlist(
    String wishlistId,
    bool yes,
  ) {
    if (currentProfile == null) {
      return;
    }

    WishlistItem? item;

    for (final wishlistItem in wishlist) {
      if (wishlistItem.id ==
          wishlistId) {
        item = wishlistItem;
        break;
      }
    }

    if (item == null) {
      return;
    }

    item.votesByProfileId[
        currentProfile!.id] = yes;

    // Majority yes means the title wins.
    if (item.majorityYes) {
      addGroupMessage(
        '${item.title} won the group vote and was added to the wishlist.',
      );
    }

    notifyListeners();
  }

  int wishlistYesVotes(
    WishlistItem item,
  ) {
    return item.yesVotes;
  }

  int wishlistNoVotes(
    WishlistItem item,
  ) {
    return item.noVotes;
  }

  // ==========================================================
  // GROUP MESSAGES
  // ==========================================================

  void addGroupMessage(
    String text,
  ) {
    groupMessages.add(
      GroupChatMessage(
        id: _newId(),
        profileId:
            currentProfile?.id ?? 'system',
        text: text,
      ),
    );

    notifyListeners();
  }

  // ==========================================================
  // GROUP WATCH
  // ==========================================================

  GroupWatchInvite? createGroupWatchInvite(
    MediaItem media,
  ) {
    if (account == null ||
        currentProfile == null) {
      return null;
    }

    final invited = account!.profiles
        .where(
          (profile) =>
              profile.id !=
              currentProfile!.id,
        )
        .map((profile) => profile.id)
        .toSet();

    final invite = GroupWatchInvite(
      id: _newId(),
      hostProfileId:
          currentProfile!.id,
      mediaId: media.id,
      invitedProfileIds: invited,
    );

    for (final profileId in invited) {
      invite.responses[profileId] = null;
    }

    groupWatchInvites.add(invite);

    addActivity(
      ActivityEvent(
        profileId: currentProfile!.id,
        profileName:
            currentProfile!.name,
        type: ActivityType.active,
        message:
            '${currentProfile!.name} wants to watch "${media.title}" with the group',
      ),
    );

    notifyListeners();

    return invite;
  }

  void respondToGroupWatch(
    String inviteId,
    String profileId,
    bool accepted,
  ) {
    for (final invite in groupWatchInvites) {
      if (invite.id == inviteId) {
        invite.responses[profileId] =
            accepted;
        break;
      }
    }

    notifyListeners();
  }

  bool groupWatchReady(
    GroupWatchInvite invite,
  ) {
    if (invite.invitedProfileIds.isEmpty) {
      return true;
    }

    for (final profileId
        in invite.invitedProfileIds) {
      if (invite.responses[profileId] !=
          true) {
        return false;
      }
    }

    return true;
  }

  // ==========================================================
  // MUSIC ACTIVITY
  // ==========================================================

  void reportListening(
    MusicItem music,
  ) {
    if (currentProfile == null) {
      return;
    }

    final source =
        currentProfile!.library.findById(
      music.sourceMediaId,
    );

    addActivity(
      ActivityEvent(
        profileId: currentProfile!.id,
        profileName:
            currentProfile!.name,
        type: ActivityType.listening,
        message:
            '${currentProfile!.name} is listening to ${music.title}${source == null ? '' : ' from ${source.title}'}',
      ),
    );

    notifyListeners();
  }

  // ==========================================================
  // HELPERS
  // ==========================================================

  String _newId() {
    return DateTime.now()
        .microsecondsSinceEpoch
        .toString();
  }

  // ==========================================================
  // DEBUG / DEVELOPMENT
  // ==========================================================

  void resetEverything() {
    account = null;
    currentProfile = null;

    backendApi.clearToken();

    activityFeed.clear();
    activeProfileIds.clear();
    groupMessages.clear();
    wishlist.clear();
    groupWatchInvites.clear();

    notifyListeners();
  }
}
