// FILE: Backend/services/group_recommendation_service.dart.
//
// Purpose: Implements group recommendation creation, voting, finalization,
// and wishlist integration for the streaming service.
//
// Recommendations may reference existing catalog media or arbitrary movie /
// TV titles that are not yet present in the catalog.
//
// Voting remains open until votingEndsAt. Voting does not end early merely
// because every eligible profile has voted.

import 'dart:math';

import '../database/database.dart';
import '../models/account.dart';
import '../models/group_recommendation.dart';

class GroupRecommendationService {
  final Database database;
  final Random _random = Random.secure();

  GroupRecommendationService(this.database);

  // ---------------------------------------------------------------------------
  // CREATE
  // ---------------------------------------------------------------------------

  GroupRecommendation createRecommendation({
    required String accountId,
    required String title,
    required String type,
    String? mediaId,
    required String recommendedByProfileId,
    required Set<String> activeParticipants,
    required Duration votingDuration,
  }) {
    final normalizedAccountId = accountId.trim();

    if (normalizedAccountId.isEmpty) {
      throw ArgumentError('Account ID cannot be empty.');
    }

    final Account? account =
        database.getAccountById(normalizedAccountId);

    if (account == null) {
      throw StateError('Account not found.');
    }

    final normalizedTitle = title.trim();

    if (normalizedTitle.isEmpty) {
      throw ArgumentError('Recommendation title cannot be empty.');
    }

    if (normalizedTitle.length > 500) {
      throw ArgumentError(
        'Recommendation title cannot exceed 500 characters.',
      );
    }

    final normalizedType = type.trim();

    if (normalizedType != 'movie' && normalizedType != 'tvShow') {
      throw ArgumentError(
        'Recommendation type must be "movie" or "tvShow".',
      );
    }

    final normalizedMediaId = _normalizeOptionalId(mediaId);

    final normalizedProfileId = recommendedByProfileId.trim();

    if (normalizedProfileId.isEmpty) {
      throw ArgumentError(
        'Recommended-by profile ID cannot be empty.',
      );
    }

    if (account.getProfileById(normalizedProfileId) == null) {
      throw ArgumentError(
        'The recommending profile does not belong to this account.',
      );
    }

    // Every profile belonging to the account is eligible to vote.
    //
    // activeParticipants remains in the method signature for compatibility
    // with existing callers, but eligibility is intentionally account-wide.
    final normalizedParticipants = account.profiles
        .map((profile) => profile.id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    if (normalizedParticipants.isEmpty) {
      throw ArgumentError(
        'At least one profile is required before creating a recommendation.',
      );
    }

    if (votingDuration <= Duration.zero) {
      throw ArgumentError(
        'Voting duration must be greater than zero.',
      );
    }

    // Prevent accidental extremely long-lived recommendations.
    if (votingDuration > const Duration(days: 365)) {
      throw ArgumentError(
        'Voting duration cannot exceed 365 days.',
      );
    }

    final now = DateTime.now();

    final recommendation = GroupRecommendation(
      id: _generateId(),
      accountId: normalizedAccountId,
      mediaId: normalizedMediaId,
      title: normalizedTitle,
      type: normalizedType,
      recommendedByProfileId: normalizedProfileId,
      createdAt: now,
      votingEndsAt: now.add(votingDuration),
      activeParticipants: normalizedParticipants,
    );

    database.saveGroupRecommendation(recommendation);

    return recommendation;
  }

  // ---------------------------------------------------------------------------
  // GET
  // ---------------------------------------------------------------------------

  GroupRecommendation? getRecommendation({
    required String accountId,
    required String recommendationId,
  }) {
    final recommendation = _getAccountRecommendation(
      accountId: accountId,
      recommendationId: recommendationId,
    );

    if (recommendation == null) {
      return null;
    }

    _finalizeIfVotingEnded(recommendation);

    return recommendation;
  }

  List<GroupRecommendation> getRecommendations({
    required String accountId,
  }) {
    final normalizedAccountId = accountId.trim();

    if (normalizedAccountId.isEmpty) {
      return <GroupRecommendation>[];
    }

    final recommendations =
        database.getGroupRecommendationsForAccount(
      normalizedAccountId,
    );

    for (final recommendation in recommendations) {
      _finalizeIfVotingEnded(recommendation);
    }

    return recommendations;
  }

  List<GroupRecommendation> getVotingRecommendations({
    required String accountId,
  }) {
    final recommendations = getRecommendations(accountId: accountId);

    return recommendations
        .where(
          (recommendation) =>
              recommendation.status == GroupRecommendationStatus.voting,
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // VOTE
  // ---------------------------------------------------------------------------

  GroupRecommendation vote({
    required String accountId,
    required String recommendationId,
    required String profileId,
    required GroupRecommendationVote vote,
  }) {
    final recommendation = _requireAccountRecommendation(
      accountId: accountId,
      recommendationId: recommendationId,
    );

    final normalizedProfileId = profileId.trim();

    if (normalizedProfileId.isEmpty) {
      throw ArgumentError('Profile ID cannot be empty.');
    }

    final account = database.getAccountById(accountId.trim());

    if (account == null) {
      throw StateError('Account not found.');
    }

    // Do not allow a profile from another account to vote.
    if (account.getProfileById(normalizedProfileId) == null) {
      throw StateError(
        'The voting profile does not belong to this account.',
      );
    }

    if (recommendation.hasVotingEnded) {
      _finalizeIfVotingEnded(recommendation);

      throw StateError(
        'Voting has ended for this recommendation.',
      );
    }

    if (recommendation.status != GroupRecommendationStatus.voting) {
      throw StateError(
        'Voting is no longer available for this recommendation.',
      );
    }

    if (recommendation.hasVoted(normalizedProfileId)) {
      throw StateError(
        'This profile has already voted on this recommendation.',
      );
    }

    final accepted = recommendation.addVote(
      normalizedProfileId,
      vote,
    );

    if (!accepted) {
      throw StateError('Vote could not be submitted.');
    }

    database.saveGroupRecommendation(recommendation);

    return recommendation;
  }

  // ---------------------------------------------------------------------------
  // FINALIZATION
  // ---------------------------------------------------------------------------

  GroupRecommendation finalizeRecommendation({
    required String accountId,
    required String recommendationId,
  }) {
    final recommendation = _requireAccountRecommendation(
      accountId: accountId,
      recommendationId: recommendationId,
    );

    if (recommendation.status != GroupRecommendationStatus.voting) {
      return recommendation;
    }

    if (!recommendation.hasVotingEnded) {
      throw StateError('Voting has not ended yet.');
    }

    _finalizeRecommendation(recommendation);

    return recommendation;
  }

  /// Compatibility method retained for existing routes/API consumers.
  ///
  /// Voting cannot be closed before its configured deadline.
  GroupRecommendation closeVoting({
    required String accountId,
    required String recommendationId,
  }) {
    final recommendation = _requireAccountRecommendation(
      accountId: accountId,
      recommendationId: recommendationId,
    );

    if (recommendation.status != GroupRecommendationStatus.voting) {
      return recommendation;
    }

    if (!recommendation.hasVotingEnded) {
      throw StateError(
        'Voting cannot be closed before the voting deadline.',
      );
    }

    _finalizeRecommendation(recommendation);

    return recommendation;
  }

  /// Compatibility method retained for existing API consumers.
  ///
  /// Expiration resolves the recommendation using its actual vote result.
  /// It does not silently discard a recommendation.
  GroupRecommendation expireRecommendation({
    required String accountId,
    required String recommendationId,
  }) {
    final recommendation = _requireAccountRecommendation(
      accountId: accountId,
      recommendationId: recommendationId,
    );

    if (recommendation.status != GroupRecommendationStatus.voting) {
      return recommendation;
    }

    if (!recommendation.hasVotingEnded) {
      throw StateError('Voting has not ended yet.');
    }

    _finalizeRecommendation(recommendation);

    return recommendation;
  }

  void _finalizeIfVotingEnded(
    GroupRecommendation recommendation,
  ) {
    if (recommendation.status != GroupRecommendationStatus.voting) {
      return;
    }

    if (!recommendation.hasVotingEnded) {
      return;
    }

    _finalizeRecommendation(recommendation);
  }

  void _finalizeRecommendation(
    GroupRecommendation recommendation,
  ) {
    if (recommendation.status != GroupRecommendationStatus.voting) {
      return;
    }

    if (recommendation.hasMajorityYes) {
      recommendation.approve();
      _addApprovedRecommendationToWishlist(recommendation);
    } else {
      // This intentionally covers:
      // - NO > YES
      // - YES == NO
      // - zero votes
      recommendation.reject();
    }

    database.saveGroupRecommendation(recommendation);
  }

  // ---------------------------------------------------------------------------
  // WISHLIST
  // ---------------------------------------------------------------------------

  void _addApprovedRecommendationToWishlist(
    GroupRecommendation recommendation,
  ) {
    final account = database.getAccountById(
      recommendation.accountId,
    );

    if (account == null) {
      return;
    }

    final mediaId = _normalizeOptionalId(recommendation.mediaId);

    if (mediaId != null) {
      if (!account.wishlistMediaIds.contains(mediaId)) {
        account.wishlistMediaIds.add(mediaId);
      }

      // An approved catalog recommendation should not also appear as an
      // arbitrary recommendation in the wishlist.
      account.wishlistRecommendationIds.remove(
        recommendation.id,
      );
    } else {
      if (!account.wishlistRecommendationIds.contains(
        recommendation.id,
      )) {
        account.wishlistRecommendationIds.add(
          recommendation.id,
        );
      }
    }

    // The Account object is mutable in the current in-memory database, but
    // explicitly saving it keeps this mutation visible to database
    // implementations that replace the object or add persistence hooks.
    database.saveAccount(account);
  }

  // ---------------------------------------------------------------------------
  // FILTERED QUERIES
  // ---------------------------------------------------------------------------

  List<GroupRecommendation> getRecommendationsByProfile({
    required String accountId,
    required String profileId,
  }) {
    final normalizedAccountId = accountId.trim();
    final normalizedProfileId = profileId.trim();

    if (normalizedAccountId.isEmpty || normalizedProfileId.isEmpty) {
      return <GroupRecommendation>[];
    }

    final account = database.getAccountById(normalizedAccountId);

    if (account == null ||
        account.getProfileById(normalizedProfileId) == null) {
      return <GroupRecommendation>[];
    }

    final recommendations = database
        .getGroupRecommendationsForAccount(normalizedAccountId)
        .where(
          (recommendation) =>
              recommendation.recommendedByProfileId ==
              normalizedProfileId,
        )
        .toList();

    for (final recommendation in recommendations) {
      _finalizeIfVotingEnded(recommendation);
    }

    return recommendations;
  }

  List<GroupRecommendation> getRecommendationsForMedia({
    required String accountId,
    required String mediaId,
  }) {
    final normalizedAccountId = accountId.trim();
    final normalizedMediaId = mediaId.trim();

    if (normalizedAccountId.isEmpty || normalizedMediaId.isEmpty) {
      return <GroupRecommendation>[];
    }

    final recommendations = database
        .getGroupRecommendationsForAccount(normalizedAccountId)
        .where(
          (recommendation) =>
              recommendation.mediaId == normalizedMediaId,
        )
        .toList();

    for (final recommendation in recommendations) {
      _finalizeIfVotingEnded(recommendation);
    }

    return recommendations;
  }

  // ---------------------------------------------------------------------------
  // VOTE LOOKUPS
  // ---------------------------------------------------------------------------

  bool hasVoted({
    required String accountId,
    required String recommendationId,
    required String profileId,
  }) {
    final normalizedProfileId = profileId.trim();

    if (normalizedProfileId.isEmpty) {
      return false;
    }

    final recommendation = _getAccountRecommendation(
      accountId: accountId,
      recommendationId: recommendationId,
    );

    if (recommendation == null) {
      return false;
    }

    final account = database.getAccountById(accountId.trim());

    if (account == null ||
        account.getProfileById(normalizedProfileId) == null) {
      return false;
    }

    _finalizeIfVotingEnded(recommendation);

    return recommendation.hasVoted(normalizedProfileId);
  }

  GroupRecommendationVote? getVote({
    required String accountId,
    required String recommendationId,
    required String profileId,
  }) {
    final normalizedProfileId = profileId.trim();

    if (normalizedProfileId.isEmpty) {
      return null;
    }

    final recommendation = _getAccountRecommendation(
      accountId: accountId,
      recommendationId: recommendationId,
    );

    if (recommendation == null) {
      return null;
    }

    final account = database.getAccountById(accountId.trim());

    if (account == null ||
        account.getProfileById(normalizedProfileId) == null) {
      return null;
    }

    _finalizeIfVotingEnded(recommendation);

    return recommendation.voteFor(normalizedProfileId);
  }

  // ---------------------------------------------------------------------------
  // DELETE / CLEAR
  // ---------------------------------------------------------------------------

  void deleteRecommendation({
    required String accountId,
    required String recommendationId,
  }) {
    final recommendation = _requireAccountRecommendation(
      accountId: accountId,
      recommendationId: recommendationId,
    );

    final account = database.getAccountById(accountId.trim());

    if (account != null) {
      final mediaId = _normalizeOptionalId(recommendation.mediaId);

      if (mediaId != null) {
        account.wishlistMediaIds.remove(mediaId);
      }

      account.wishlistRecommendationIds.remove(
        recommendation.id,
      );

      database.saveAccount(account);
    }

    database.deleteGroupRecommendation(
      recommendation.id,
    );
  }

  /// Clears all group recommendations.
  ///
  /// This remains intentionally database-wide because the existing method is
  /// used for in-memory testing/reset operations.
  void clear() {
    database.clearGroupRecommendations();
  }

  // ---------------------------------------------------------------------------
  // INTERNAL HELPERS
  // ---------------------------------------------------------------------------

  GroupRecommendation? _getAccountRecommendation({
    required String accountId,
    required String recommendationId,
  }) {
    final normalizedAccountId = accountId.trim();
    final normalizedRecommendationId = recommendationId.trim();

    if (normalizedAccountId.isEmpty ||
        normalizedRecommendationId.isEmpty) {
      return null;
    }

    final recommendation =
        database.getGroupRecommendationById(
      normalizedRecommendationId,
    );

    if (recommendation == null ||
        recommendation.accountId != normalizedAccountId) {
      return null;
    }

    return recommendation;
  }

  GroupRecommendation _requireAccountRecommendation({
    required String accountId,
    required String recommendationId,
  }) {
    final normalizedAccountId = accountId.trim();
    final normalizedRecommendationId = recommendationId.trim();

    if (normalizedAccountId.isEmpty) {
      throw ArgumentError('Account ID cannot be empty.');
    }

    if (normalizedRecommendationId.isEmpty) {
      throw ArgumentError('Recommendation ID cannot be empty.');
    }

    final recommendation =
        database.getGroupRecommendationById(
      normalizedRecommendationId,
    );

    if (recommendation == null) {
      throw StateError('Recommendation not found.');
    }

    if (recommendation.accountId != normalizedAccountId) {
      throw StateError(
        'Recommendation does not belong to this account.',
      );
    }

    return recommendation;
  }

  String? _normalizeOptionalId(String? value) {
    final normalized = value?.trim();

    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  String _generateId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final randomPart = _random.nextInt(0x7fffffff).toRadixString(16);

    return 'group_rec_${timestamp}_$randomPart';
  }
}