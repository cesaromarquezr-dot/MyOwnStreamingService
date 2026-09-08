import '../models/account.dart';
import '../models/media.dart';
import '../models/group_recommendation.dart';
import '../models/group_watch_session.dart';
import '../models/profile.dart';

class SessionRecord {
  final String token;
  final String accountId;

  final DateTime createdAt;
  final DateTime expiresAt;

  DateTime lastUsedAt;

  SessionRecord({
    required this.token,
    required this.accountId,
    required this.createdAt,
    required this.expiresAt,
    required this.lastUsedAt,
  });

  bool get isExpired {
    return !DateTime.now().isBefore(expiresAt);
  }

  Map<String, dynamic> toJson() {
    return {
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'lastUsedAt': lastUsedAt.toIso8601String(),
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

  // ---------------------------------------------------------------------------
  // MEDIA
  // ---------------------------------------------------------------------------

  final Map<String, Media> mediaById = {};

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

  bool hasProfile(
    String profileId,
  ) {
    return getProfileById(profileId) != null;
  }

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

  void saveSession(
    String token,
    String accountId, {
    Duration? ttl,
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

  void deleteSession(
    String token,
  ) {
    sessions.remove(token);
  }

  void deleteSessionsForAccount(
    String accountId,
  ) {
    sessions.removeWhere(
      (_, session) =>
          session.accountId == accountId,
    );
  }

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

  List<Media> getMovies() {
    return getAllMedia()
        .where(
          (media) => media.isMovie,
        )
        .toList();
  }

  List<Media> getTvShows() {
    return getAllMedia()
        .where(
          (media) => media.isTvShow,
        )
        .toList();
  }

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

  bool hasMedia(
    String mediaId,
  ) {
    return mediaById.containsKey(mediaId);
  }

  void deleteMedia(
    String mediaId,
  ) {
    mediaById.remove(mediaId);
  }

  // ---------------------------------------------------------------------------
  // GROUP RECOMMENDATIONS
  // ---------------------------------------------------------------------------

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

  void deleteGroupRecommendation(
    String recommendationId,
  ) {
    groupRecommendationsById.remove(
      recommendationId,
    );
  }

  void clearGroupRecommendations() {
    groupRecommendationsById.clear();
  }

  // ---------------------------------------------------------------------------
  // GROUP WATCH
  // ---------------------------------------------------------------------------

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

  void deleteGroupWatchSession(
    String sessionId,
  ) {
    groupWatchSessionsById.remove(
      sessionId,
    );
  }

  void clearGroupWatchSessions() {
    groupWatchSessionsById.clear();
  }

  // ---------------------------------------------------------------------------
  // CLEAR
  // ---------------------------------------------------------------------------

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