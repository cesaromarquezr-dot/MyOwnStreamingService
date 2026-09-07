import '../models/account.dart';
import '../models/media.dart';
import '../models/group_recommendation.dart';
import '../models/group_watch_session.dart';
import '../models/profile.dart';

class Database {
  Database._();

  static final Database instance = Database._();

  // ------------------------------------------------------------
  // ACCOUNTS
  // ------------------------------------------------------------

  final Map<String, Account> accountsById = {};

  final Map<String, String> accountIdByUsername = {};

  final Map<String, String> accountIdByEmail = {};

  // ------------------------------------------------------------
  // SESSIONS
  // ------------------------------------------------------------

  final Map<String, String> sessions = {};

  // ------------------------------------------------------------
  // MEDIA CATALOG
  // ------------------------------------------------------------

  final Map<String, Media> mediaById = {};

  // ------------------------------------------------------------
  // GROUP RECOMMENDATIONS
  // ------------------------------------------------------------

  final Map<String, GroupRecommendation>
      groupRecommendationsById =
      <String, GroupRecommendation>{};

  void saveGroupRecommendation(
    GroupRecommendation recommendation,
  ) {
    groupRecommendationsById[recommendation.id] =
        recommendation;
  }

  GroupRecommendation? getGroupRecommendation(
    String recommendationId,
  ) {
    return groupRecommendationsById[recommendationId];
  }

  List<GroupRecommendation> getGroupRecommendations() {
    return groupRecommendationsById.values.toList();
  }

  List<GroupRecommendation>
      getVotingGroupRecommendations() {
    return groupRecommendationsById.values
        .where(
          (recommendation) =>
              recommendation.status ==
              GroupRecommendationStatus.voting,
        )
        .toList();
  }

  void deleteGroupRecommendation(
    String recommendationId,
  ) {
    groupRecommendationsById.remove(recommendationId);
  }

  void clearGroupRecommendations() {
    groupRecommendationsById.clear();
  }

  // ------------------------------------------------------------
  // GROUP WATCH
  // ------------------------------------------------------------

  final Map<String, GroupWatchSession>
      groupWatchSessionsById =
      <String, GroupWatchSession>{};

  void saveGroupWatchSession(
    GroupWatchSession session,
  ) {
    groupWatchSessionsById[session.id] = session;
  }

  GroupWatchSession? getGroupWatchSession(
    String sessionId,
  ) {
    return groupWatchSessionsById[sessionId];
  }

  List<GroupWatchSession> getGroupWatchSessions() {
    return groupWatchSessionsById.values.toList();
  }

  /// Returns every Group Watch session visible to an account.
  ///
  /// An account can see a session when:
  ///
  /// 1. It owns/hosts the session, OR
  /// 2. One of its profiles is participating in the session.
  ///
  /// This allows Group Watch to work across different accounts.
  List<GroupWatchSession> getGroupWatchSessionsForAccount(
    String accountId,
  ) {
    final String cleanAccountId =
        accountId.trim();

    if (cleanAccountId.isEmpty) {
      return <GroupWatchSession>[];
    }

    return groupWatchSessionsById.values
        .where(
          (session) {
            // The account is the host.
            if (session.accountId ==
                cleanAccountId) {
              return true;
            }

            // The account has a profile participating
            // in this Group Watch session.
            return session.participants.values.any(
              (participant) =>
                  participant.accountId ==
                  cleanAccountId,
            );
          },
        )
        .toList();
  }

  /// Returns every Group Watch session involving
  /// the specified profile.
  ///
  /// Profile IDs are globally searchable, which allows
  /// participants from different accounts to use the
  /// same Group Watch session.
  List<GroupWatchSession>
      getGroupWatchSessionsForProfile(
    String profileId,
  ) {
    final String cleanProfileId =
        profileId.trim();

    if (cleanProfileId.isEmpty) {
      return <GroupWatchSession>[];
    }

    return groupWatchSessionsById.values
        .where(
          (session) =>
              session.hasParticipant(
            cleanProfileId,
          ),
        )
        .toList();
  }

  /// Returns all currently playing or paused sessions.
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

  /// Returns all sessions that have not ended.
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
    groupWatchSessionsById.remove(sessionId);
  }

  void clearGroupWatchSessions() {
    groupWatchSessionsById.clear();
  }

  // ------------------------------------------------------------
  // CLEAR DATABASE
  // ------------------------------------------------------------

  void clear() {
    accountsById.clear();
    accountIdByUsername.clear();
    accountIdByEmail.clear();
    sessions.clear();
    mediaById.clear();
    groupRecommendationsById.clear();
    groupWatchSessionsById.clear();
  }

  // ------------------------------------------------------------
  // ACCOUNT LOOKUPS
  // ------------------------------------------------------------

  Account? getAccountById(String id) {
    final cleanId = id.trim();

    if (cleanId.isEmpty) {
      return null;
    }

    return accountsById[cleanId];
  }

  Account? getAccountByUsername(
    String username,
  ) {
    final normalizedUsername =
        username.trim().toLowerCase();

    if (normalizedUsername.isEmpty) {
      return null;
    }

    final accountId =
        accountIdByUsername[normalizedUsername];

    if (accountId == null) {
      return null;
    }

    return accountsById[accountId];
  }

  Account? getAccountByEmail(
    String email,
  ) {
    final normalizedEmail =
        email.trim().toLowerCase();

    if (normalizedEmail.isEmpty) {
      return null;
    }

    final accountId =
        accountIdByEmail[normalizedEmail];

    if (accountId == null) {
      return null;
    }

    return accountsById[accountId];
  }

  // ------------------------------------------------------------
  // PROFILE LOOKUPS
  // ------------------------------------------------------------

  /// Finds the account containing the specified profile.
  ///
  /// Profile IDs are globally searchable because Group Watch
  /// supports participants from different accounts.
  Account? getAccountForProfile(
    String profileId,
  ) {
    final cleanProfileId =
        profileId.trim();

    if (cleanProfileId.isEmpty) {
      return null;
    }

    for (final account in accountsById.values) {
      if (account.hasProfile(cleanProfileId)) {
        return account;
      }
    }

    return null;
  }

  /// Finds a profile by ID regardless of which account
  /// owns the profile.
  Profile? getProfileById(
    String profileId,
  ) {
    final cleanProfileId =
        profileId.trim();

    if (cleanProfileId.isEmpty) {
      return null;
    }

    for (final account in accountsById.values) {
      final profile =
          account.getProfileById(
        cleanProfileId,
      );

      if (profile != null) {
        return profile;
      }
    }

    return null;
  }

  /// Returns the account ID associated with a profile.
  String? getAccountIdForProfile(
    String profileId,
  ) {
    return getAccountForProfile(
      profileId,
    )?.id;
  }

  /// Returns true when the profile exists.
  bool hasProfile(
    String profileId,
  ) {
    return getProfileById(
      profileId,
    ) != null;
  }

  /// Returns true when a profile belongs to
  /// the specified account.
  bool profileBelongsToAccount(
    String profileId,
    String accountId,
  ) {
    final cleanProfileId =
        profileId.trim();

    final cleanAccountId =
        accountId.trim();

    if (cleanProfileId.isEmpty ||
        cleanAccountId.isEmpty) {
      return false;
    }

    final account =
        getAccountForProfile(
      cleanProfileId,
    );

    return account?.id ==
        cleanAccountId;
  }

  // ------------------------------------------------------------
  // ACCOUNT STORAGE
  // ------------------------------------------------------------

  void saveAccount(
    Account account,
  ) {
    final username =
        account.username.trim().toLowerCase();

    final email =
        account.email.trim().toLowerCase();

    accountsById[account.id] =
        account;

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

    accountsByUsernameRemove(
      account.username,
    );

    accountsByEmailRemove(
      account.email,
    );

    accountsById.remove(
      accountId,
    );

    sessions.removeWhere(
      (_, storedAccountId) =>
          storedAccountId ==
          accountId,
    );

    // Only delete Group Watch sessions hosted
    // by the deleted account.
    //
    // If another account is participating in a
    // session hosted elsewhere, that session must
    // remain available to the other participants.
    groupWatchSessionsById.removeWhere(
      (_, session) =>
          session.accountId ==
          accountId,
    );
  }

  void accountsByUsernameRemove(
    String username,
  ) {
    accountIdByUsername.remove(
      username.trim().toLowerCase(),
    );
  }

  void accountsByEmailRemove(
    String email,
  ) {
    accountIdByEmail.remove(
      email.trim().toLowerCase(),
    );
  }

  // ------------------------------------------------------------
  // SESSION STORAGE
  // ------------------------------------------------------------

  void saveSession(
    String token,
    String accountId,
  ) {
    if (token.trim().isEmpty ||
        accountId.trim().isEmpty) {
      return;
    }

    sessions[token] =
        accountId;
  }

  String? getAccountIdForSession(
    String token,
  ) {
    if (token.trim().isEmpty) {
      return null;
    }

    return sessions[token];
  }

  Account? getAccountForSession(
    String token,
  ) {
    final accountId =
        getAccountIdForSession(
      token,
    );

    if (accountId == null) {
      return null;
    }

    return getAccountById(
      accountId,
    );
  }

  void deleteSession(
    String token,
  ) {
    sessions.remove(token);
  }

  // ------------------------------------------------------------
  // MEDIA STORAGE
  // ------------------------------------------------------------

  void saveMedia(
    Media media,
  ) {
    if (media.id.trim().isEmpty) {
      return;
    }

    mediaById[media.id] =
        media;
  }

  Media? getMediaById(
    String id,
  ) {
    final cleanId =
        id.trim();

    if (cleanId.isEmpty) {
      return null;
    }

    return mediaById[cleanId];
  }

  List<Media> getAllMedia() {
    final media =
        mediaById.values.toList();

    media.sort(
      (a, b) {
        final aDate =
            a.releaseDate;

        final bDate =
            b.releaseDate;

        if (aDate != null &&
            bDate != null) {
          final dateComparison =
              bDate.compareTo(
            aDate,
          );

          if (dateComparison != 0) {
            return dateComparison;
          }
        } else if (aDate != null) {
          return -1;
        } else if (bDate != null) {
          return 1;
        }

        final aYear =
            a.year ?? 0;

        final bYear =
            b.year ?? 0;

        final yearComparison =
            bYear.compareTo(
          aYear,
        );

        if (yearComparison != 0) {
          return yearComparison;
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
          (media) =>
              media.type ==
              MediaType.movie,
        )
        .toList();
  }

  List<Media> getTvShows() {
    return getAllMedia()
        .where(
          (media) =>
              media.type ==
              MediaType.tvShow,
        )
        .toList();
  }

  List<Media> getMediaBySeriesId(
    String seriesId,
  ) {
    return getAllMedia()
        .where(
          (media) =>
              media.seriesId ==
              seriesId,
        )
        .toList();
  }

  void deleteMedia(
    String mediaId,
  ) {
    mediaById.remove(
      mediaId,
    );
  }

  bool hasMedia(
    String mediaId,
  ) {
    return mediaById.containsKey(
      mediaId,
    );
  }
}