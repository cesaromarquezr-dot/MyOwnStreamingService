// FILE: `Backend/database/database.dart`.
// Purpose: Implements the database portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import '../models/account.dart';
import '../models/media.dart';
import '../models/group_recommendation.dart';
import '../models/group_watch_session.dart';
import '../models/group_chat_room.dart';
import '../models/profile.dart';
import '../models/remote_worker.dart';
import '../models/review.dart';

class SessionRecord {
  final String token;
  final String accountId;

  final DateTime createdAt;
  final DateTime expiresAt;

  final String ipAddress;
  final String userAgent;

  DateTime lastUsedAt;

  SessionRecord({
    required this.token,
    required this.accountId,
    required this.createdAt,
    required this.expiresAt,
    required this.lastUsedAt,
    this.ipAddress = 'unknown',
    this.userAgent = 'unknown',
  });

  bool get isExpired {
    return !DateTime.now().isBefore(expiresAt);
  }

  /// Performs `toJson` for this feature. Update this documentation when its contract changes.
  Map<String, dynamic> toJson() {
    return {
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'lastUsedAt': lastUsedAt.toIso8601String(),
      'ipAddress': ipAddress,
      'userAgent': userAgent,
    };
  }
}

class Database {
  Database._();

  static final Database instance =
      Database._();

  // ---------------------------------------------------------------------------
  // SESSION CONFIGURATION
  // ---------------------------------------------------------------------------

  // First-pass session lifetime.
  //
  // This is an absolute lifetime. Later we can add:
  // - trusted devices
  // - idle timeout
  // - device revocation
  // - suspicious-login detection
  // - per-device sessions
  // - session rotation
  static const Duration defaultSessionLifetime =
      Duration(days: 30);

  // ---------------------------------------------------------------------------
  // ACCOUNTS
  // ---------------------------------------------------------------------------

  final Map<String, Account> accountsById = {};

  final Map<String, String> accountIdByUsername =
      {};

  final Map<String, String> accountIdByEmail =
      {};

  // ---------------------------------------------------------------------------
  // SESSIONS
  // ---------------------------------------------------------------------------

  final Map<String, SessionRecord> sessions = {};

  // Recent failed login timestamps, keyed by normalized username/email.
  // This is intentionally bounded and in-memory for the current backend.
  final Map<String, List<DateTime>> failedLoginAttempts = {};

  final Map<String, Set<String>> knownLoginFingerprints = {};

  final Map<String, String> oneTimeCodesByAccountId = {};
  final Map<String, DateTime> oneTimeCodeExpiryByAccountId = {};
  final Map<String, RemoteWorker> remoteWorkersById = {};
  final Map<String, RemoteImportJob> remoteImportJobsById = {};

  /// Performs `getKnownLoginFingerprints` for this feature. Update this documentation when its contract changes.
  Set<String> getKnownLoginFingerprints(String accountId) =>
      knownLoginFingerprints.putIfAbsent(accountId, () => <String>{});

  /// Performs `recordFailedLogin` for this feature. Update this documentation when its contract changes.
  void recordFailedLogin(String login) {
    final key = login.trim().toLowerCase();
    if (key.isEmpty) return;

    final now = DateTime.now();
    final attempts = failedLoginAttempts.putIfAbsent(key, () => []);
    attempts.removeWhere((time) => now.difference(time) > const Duration(minutes: 15));
    attempts.add(now);
    if (attempts.length > 10) {
      attempts.removeRange(0, attempts.length - 10);
    }
  }

  /// Performs `recentFailedLoginCount` for this feature. Update this documentation when its contract changes.
  int recentFailedLoginCount(String login) {
    final key = login.trim().toLowerCase();
    final attempts = failedLoginAttempts[key];
    if (attempts == null) return 0;

    final now = DateTime.now();
    attempts.removeWhere((time) => now.difference(time) > const Duration(minutes: 15));
    return attempts.length;
  }

  /// Performs `clearFailedLoginAttempts` for this feature. Update this documentation when its contract changes.
  void clearFailedLoginAttempts(String login) {
    failedLoginAttempts.remove(login.trim().toLowerCase());
  }

  // ---------------------------------------------------------------------------
  // MEDIA
  // ---------------------------------------------------------------------------

  final Map<String, Media> mediaById = {};

  // Media reviews are kept here by the current backend persistence abstraction.
  final Map<String, MediaReview> reviewsById = <String, MediaReview>{};

  // ---------------------------------------------------------------------------
  // GROUP RECOMMENDATIONS
  // ---------------------------------------------------------------------------

  final Map<String, GroupRecommendation>
      groupRecommendationsById =
      <String, GroupRecommendation>{};

  // ---------------------------------------------------------------------------
  // GROUP WATCH
  // ---------------------------------------------------------------------------

  final Map<String, GroupWatchSession>
      groupWatchSessionsById =
      <String, GroupWatchSession>{};

  final Map<String, GroupChatRoom> groupChatRoomsById = <String, GroupChatRoom>{};

  // ---------------------------------------------------------------------------
  // ACCOUNTS
  // ---------------------------------------------------------------------------

  Account? getAccountById(
    String accountId,
  ) {
    return accountsById[accountId];
  }

  Account? getAccountByUsername(
    String username,
  ) {
    final normalized =
        username.trim().toLowerCase();

    final accountId =
        accountIdByUsername[normalized];

    if (accountId == null) {
      return null;
    }

    return accountsById[accountId];
  }

  Account? getAccountByEmail(
    String email,
  ) {
    final normalized =
        email.trim().toLowerCase();

    final accountId =
        accountIdByEmail[normalized];

    if (accountId == null) {
      return null;
    }

    return accountsById[accountId];
  }

  Account? getAccountForProfile(
    String profileId,
  ) {
    for (final account in accountsById.values) {
      if (account.getProfileById(profileId) !=
          null) {
        return account;
      }
    }

    return null;
  }

  Profile? getProfileById(
    String profileId,
  ) {
    for (final account in accountsById.values) {
      final profile =
          account.getProfileById(profileId);

      if (profile != null) {
        return profile;
      }
    }

    return null;
  }

  String? getAccountIdForProfile(
    String profileId,
  ) {
    for (final account in accountsById.values) {
      if (account.getProfileById(profileId) !=
          null) {
        return account.id;
      }
    }

    return null;
  }

  /// Performs `hasProfile` for this feature. Update this documentation when its contract changes.
  bool hasProfile(
    String profileId,
  ) {
    return getProfileById(profileId) != null;
  }

  /// Performs `profileBelongsToAccount` for this feature. Update this documentation when its contract changes.
  bool profileBelongsToAccount({
    required String accountId,
    required String profileId,
  }) {
    final account =
        getAccountById(accountId);

    if (account == null) {
      return false;
    }

    return account.getProfileById(profileId) !=
        null;
  }

  /// Performs `saveAccount` for this feature. Update this documentation when its contract changes.
  void saveAccount(
    Account account,
  ) {
    final username =
        account.username.trim().toLowerCase();

    final email =
        account.email.trim().toLowerCase();

    accountsById[account.id] = account;

    accountIdByUsername[username] =
        account.id;

    accountIdByEmail[email] =
        account.id;
  }

  /// Performs `deleteAccount` for this feature. Update this documentation when its contract changes.
  void deleteAccount(
    String accountId,
  ) {
    final account =
        accountsById[accountId];

    if (account == null) {
      return;
    }

    final username =
        account.username.trim().toLowerCase();

    final email =
        account.email.trim().toLowerCase();

    accountIdByUsername.remove(username);
    accountIdByEmail.remove(email);

    accountsById.remove(accountId);

    deleteSessionsForAccount(
      accountId,
    );

    // Remove Group Watch sessions hosted by
    // this account.
    groupWatchSessionsById
        .removeWhere(
      (_, session) =>
          session.accountId == accountId,
    );
  }

  // ---------------------------------------------------------------------------
  // SESSIONS
  // ---------------------------------------------------------------------------

  /// Performs `saveSession` for this feature. Update this documentation when its contract changes.
  void saveSession(
    String token,
    String accountId, {
    Duration? ttl,
    String ipAddress = 'unknown',
    String userAgent = 'unknown',
  }) {
    final now = DateTime.now();

    final lifetime =
        ttl ?? defaultSessionLifetime;

    sessions[token] = SessionRecord(
      token: token,
      accountId: accountId,
      createdAt: now,
      expiresAt: now.add(lifetime),
      lastUsedAt: now,
      ipAddress: ipAddress,
      userAgent: userAgent,
    );
  }

  SessionRecord? getSession(
    String token,
  ) {
    final session = sessions[token];

    if (session == null) {
      return null;
    }

    if (session.isExpired) {
      sessions.remove(token);
      return null;
    }

    return session;
  }

  String? getAccountIdForSession(
    String token,
  ) {
    final session = getSession(token);

    if (session == null) {
      return null;
    }

    session.lastUsedAt = DateTime.now();

    return session.accountId;
  }

  Account? getAccountForSession(
    String token,
  ) {
    final accountId =
        getAccountIdForSession(token);

    if (accountId == null) {
      return null;
    }

    return getAccountById(accountId);
  }

  /// Performs `deleteSession` for this feature. Update this documentation when its contract changes.
  void deleteSession(
    String token,
  ) {
    sessions.remove(token);
  }

  /// Performs `deleteSessionsForAccount` for this feature. Update this documentation when its contract changes.
  void deleteSessionsForAccount(
    String accountId,
  ) {
    sessions.removeWhere(
      (_, session) =>
          session.accountId == accountId,
    );
  }

  /// Performs `getSessionsForAccount` for this feature. Update this documentation when its contract changes.
  List<SessionRecord> getSessionsForAccount(
    String accountId,
  ) {
    final result =
        <SessionRecord>[];

    final expiredTokens =
        <String>[];

    for (final entry in sessions.entries) {
      final session = entry.value;

      if (session.isExpired) {
        expiredTokens.add(entry.key);
        continue;
      }

      if (session.accountId == accountId) {
        result.add(session);
      }
    }

    for (final token in expiredTokens) {
      sessions.remove(token);
    }

    result.sort(
      (a, b) =>
          b.lastUsedAt.compareTo(
        a.lastUsedAt,
      ),
    );

    return result;
  }

  // ---------------------------------------------------------------------------
  // MEDIA
  // ---------------------------------------------------------------------------

  /// Performs `saveMedia` for this feature. Update this documentation when its contract changes.
  void saveMedia(
    Media media,
  ) {
    mediaById[media.id] = media;
  }

  Media? getMediaById(
    String mediaId,
  ) {
    return mediaById[mediaId];
  }

  /// Performs `getAllMedia` for this feature. Update this documentation when its contract changes.
  List<Media> getAllMedia() {
    final media =
        mediaById.values.toList();

    media.sort(
      (a, b) {
        final aDate = a.releaseDate;
        final bDate = b.releaseDate;

        if (aDate != null && bDate != null) {
          final dateCompare =
              bDate.compareTo(aDate);

          if (dateCompare != 0) {
            return dateCompare;
          }
        }

        if (aDate != null) {
          return -1;
        }

        if (bDate != null) {
          return 1;
        }

        final aYear = a.year;
        final bYear = b.year;

        if (aYear != null &&
            bYear != null &&
            aYear != bYear) {
          return bYear.compareTo(aYear);
        }

        if (aYear != null) {
          return -1;
        }

        if (bYear != null) {
          return 1;
        }

        return a.title
            .toLowerCase()
            .compareTo(
              b.title.toLowerCase(),
            );
      },
    );

    return media;
  }

  /// Performs `getMovies` for this feature. Update this documentation when its contract changes.
  List<Media> getMovies() {
    return getAllMedia()
        .where(
          (media) => media.isMovie,
        )
        .toList();
  }

  /// Performs `getTvShows` for this feature. Update this documentation when its contract changes.
  List<Media> getTvShows() {
    return getAllMedia()
        .where(
          (media) => media.isTvShow,
        )
        .toList();
  }

  /// Performs `getSeries` for this feature. Update this documentation when its contract changes.
  List<Media> getSeries(
    String seriesId,
  ) {
    return getAllMedia()
        .where(
          (media) =>
              media.seriesId == seriesId,
        )
        .toList();
  }

  /// Performs `hasMedia` for this feature. Update this documentation when its contract changes.
  bool hasMedia(
    String mediaId,
  ) {
    return mediaById.containsKey(mediaId);
  }

  /// Performs `deleteMedia` for this feature. Update this documentation when its contract changes.
  void deleteMedia(
    String mediaId,
  ) {
    mediaById.remove(mediaId);
  }

  // ---------------------------------------------------------------------------
  // GROUP RECOMMENDATIONS
  // ---------------------------------------------------------------------------

  /// Performs `saveGroupRecommendation` for this feature. Update this documentation when its contract changes.
  void saveGroupRecommendation(
    GroupRecommendation recommendation,
  ) {
    groupRecommendationsById[
            recommendation.id] =
        recommendation;
  }

  GroupRecommendation?
      getGroupRecommendationById(
    String recommendationId,
  ) {
    return groupRecommendationsById[
        recommendationId];
  }

  List<GroupRecommendation>
      getGroupRecommendationsForAccount(
    String accountId,
  ) {
    return groupRecommendationsById
        .values
        .where(
          (recommendation) =>
              recommendation.accountId ==
              accountId,
        )
        .toList();
  }

  List<GroupRecommendation>
      getVotingGroupRecommendationsForAccount(
    String accountId,
  ) {
    return getGroupRecommendationsForAccount(
      accountId,
    ).where(
      (recommendation) =>
          recommendation.isVotingOpen,
    ).toList();
  }

  /// Performs `deleteGroupRecommendation` for this feature. Update this documentation when its contract changes.
  void deleteGroupRecommendation(
    String recommendationId,
  ) {
    groupRecommendationsById.remove(
      recommendationId,
    );
  }

  /// Performs `clearGroupRecommendations` for this feature. Update this documentation when its contract changes.
  void clearGroupRecommendations() {
    groupRecommendationsById.clear();
  }

  // ---------------------------------------------------------------------------
  // GROUP WATCH
  // ---------------------------------------------------------------------------

  /// Performs `saveGroupWatchSession` for this feature. Update this documentation when its contract changes.
  void saveGroupWatchSession(
    GroupWatchSession session,
  ) {
    groupWatchSessionsById[
            session.id] =
        session;
  }

  GroupWatchSession?
      getGroupWatchSessionById(
    String sessionId,
  ) {
    return groupWatchSessionsById[
        sessionId];
  }

  List<GroupWatchSession>
      getGroupWatchSessionsForAccount(
    String accountId,
  ) {
    return groupWatchSessionsById.values
        .where(
          (session) {
            if (session.accountId ==
                accountId) {
              return true;
            }

            for (final participant
                in session.participants.values) {
              if (participant.accountId ==
                  accountId) {
                return true;
              }
            }

            return false;
          },
        )
        .toList();
  }

  /// Performs `getGroupWatchSessionsForProfile` for this feature. Update this documentation when its contract changes.
  List<GroupWatchSession> getGroupWatchSessionsForProfile(
  String profileId,
) {
  return groupWatchSessionsById.values
      .where(
        (session) =>
            session.hostProfileId == profileId ||
            session.participants.containsKey(profileId),
      )
      .toList();
}

  List<GroupWatchSession>
      getActiveGroupWatchSessions() {
    return groupWatchSessionsById.values
        .where(
          (session) =>
              session.status ==
                  GroupWatchSessionStatus.playing ||
              session.status ==
                  GroupWatchSessionStatus.paused,
        )
        .toList();
  }

  List<GroupWatchSession>
      getWaitingGroupWatchSessions() {
    return groupWatchSessionsById.values
        .where(
          (session) =>
              session.status ==
                  GroupWatchSessionStatus.waiting ||
              session.status ==
                  GroupWatchSessionStatus.ready,
        )
        .toList();
  }

  /// Performs `deleteGroupWatchSession` for this feature. Update this documentation when its contract changes.
  void deleteGroupWatchSession(
    String sessionId,
  ) {
    groupWatchSessionsById.remove(
      sessionId,
    );
  }

  /// Performs `clearGroupWatchSessions` for this feature. Update this documentation when its contract changes.
  void clearGroupWatchSessions() {
    groupWatchSessionsById.clear();
  }

  // ---------------------------------------------------------------------------
  // CLEAR
  // ---------------------------------------------------------------------------

  /// Performs `clear` for this feature. Update this documentation when its contract changes.
  void clear() {
    accountsById.clear();
    accountIdByUsername.clear();
    accountIdByEmail.clear();

    sessions.clear();

    mediaById.clear();

    groupRecommendationsById.clear();

    groupWatchSessionsById.clear();
  }
}
