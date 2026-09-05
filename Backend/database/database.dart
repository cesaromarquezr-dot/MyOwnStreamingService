import '../models/account.dart';
import '../models/media.dart';
import '../models/group_recommendation.dart';

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
  // CLEAR DATABASE
  // ------------------------------------------------------------

  void clear() {
    accountsById.clear();
    accountIdByUsername.clear();
    accountIdByEmail.clear();
    sessions.clear();
    mediaById.clear();
    groupRecommendationsById.clear();
  }

  // ------------------------------------------------------------
  // ACCOUNT LOOKUPS
  // ------------------------------------------------------------

  Account? getAccountById(String id) {
    return accountsById[id];
  }

  Account? getAccountByUsername(String username) {
    final normalizedUsername =
        username.trim().toLowerCase();

    final accountId =
        accountIdByUsername[normalizedUsername];

    if (accountId == null) {
      return null;
    }

    return accountsById[accountId];
  }

  Account? getAccountByEmail(String email) {
    final normalizedEmail =
        email.trim().toLowerCase();

    final accountId =
        accountIdByEmail[normalizedEmail];

    if (accountId == null) {
      return null;
    }

    return accountsById[accountId];
  }

  // ------------------------------------------------------------
  // ACCOUNT STORAGE
  // ------------------------------------------------------------

  void saveAccount(Account account) {
    final username =
        account.username.trim().toLowerCase();

    final email =
        account.email.trim().toLowerCase();

    accountsById[account.id] = account;

    accountIdByUsername[username] = account.id;

    accountIdByEmail[email] = account.id;
  }

  void deleteAccount(String accountId) {
    final account = accountsById[accountId];

    if (account == null) {
      return;
    }

    accountsByUsernameRemove(account.username);
    accountsByEmailRemove(account.email);

    accountsById.remove(accountId);

    sessions.removeWhere(
      (_, storedAccountId) =>
          storedAccountId == accountId,
    );
  }

  void accountsByUsernameRemove(String username) {
    accountIdByUsername.remove(
      username.trim().toLowerCase(),
    );
  }

  void accountsByEmailRemove(String email) {
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

    sessions[token] = accountId;
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
        getAccountIdForSession(token);

    if (accountId == null) {
      return null;
    }

    return getAccountById(accountId);
  }

  void deleteSession(String token) {
    sessions.remove(token);
  }

  // ------------------------------------------------------------
  // MEDIA STORAGE
  // ------------------------------------------------------------

  void saveMedia(Media media) {
    if (media.id.trim().isEmpty) {
      return;
    }

    mediaById[media.id] = media;
  }

  Media? getMediaById(String id) {
    return mediaById[id];
  }

  List<Media> getAllMedia() {
    final media = mediaById.values.toList();

    media.sort(
      (a, b) {
        final aDate = a.releaseDate;
        final bDate = b.releaseDate;

        if (aDate != null && bDate != null) {
          final dateComparison =
              bDate.compareTo(aDate);

          if (dateComparison != 0) {
            return dateComparison;
          }
        } else if (aDate != null) {
          return -1;
        } else if (bDate != null) {
          return 1;
        }

        final aYear = a.year ?? 0;
        final bYear = b.year ?? 0;

        final yearComparison =
            bYear.compareTo(aYear);

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
              media.type == MediaType.movie,
        )
        .toList();
  }

  List<Media> getTvShows() {
    return getAllMedia()
        .where(
          (media) =>
              media.type == MediaType.tvShow,
        )
        .toList();
  }

  List<Media> getMediaBySeriesId(
    String seriesId,
  ) {
    return getAllMedia()
        .where(
          (media) =>
              media.seriesId == seriesId,
        )
        .toList();
  }

  void deleteMedia(String mediaId) {
    mediaById.remove(mediaId);
  }

  bool hasMedia(String mediaId) {
    return mediaById.containsKey(mediaId);
  }
}