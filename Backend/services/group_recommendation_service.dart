// FILE: `Backend/services/group_recommendation_service.dart`.
// Purpose: Implements the group recommendation service portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import '../database/database.dart';
import '../models/account.dart';
import '../models/group_recommendation.dart';

class GroupRecommendationService {
  final Database database;

  GroupRecommendationService(this.database);

  // CREATE RECOMMENDATION
  //
  // Recommendations can refer to any movie or TV show title.
  // The title does NOT have to exist in the media catalog.
  //
  // mediaId is optional and is only used when the recommendation
  // happens to correspond to an existing catalog item.
  //
  // Voting remains open for the entire votingDuration.
  GroupRecommendation createRecommendation({
    required String accountId,
    required String title,
    required String type,
    String? mediaId,
    required String recommendedByProfileId,
    required Set<String> activeParticipants,
    required Duration votingDuration,
  }) {
    if (accountId.trim().isEmpty) {
      throw ArgumentError(
        'Account ID cannot be empty.',
      );
    }

    final Account? account =
        database.getAccountById(accountId);

    if (account == null) {
      throw StateError(
        'Account not found.',
      );
    }

    final String normalizedTitle = title.trim();

    if (normalizedTitle.isEmpty) {
      throw ArgumentError(
        'Recommendation title cannot be empty.',
      );
    }

    final String normalizedType = type.trim();

    if (normalizedType != 'movie' &&
        normalizedType != 'tvShow') {
      throw ArgumentError(
        'Recommendation type must be "movie" or "tvShow".',
      );
    }

    String? normalizedMediaId = mediaId?.trim();

    if (normalizedMediaId != null &&
        normalizedMediaId.isEmpty) {
      normalizedMediaId = null;
    }

    final String normalizedProfileId =
        recommendedByProfileId.trim();

    if (normalizedProfileId.isEmpty) {
      throw ArgumentError(
        'Recommended-by profile ID cannot be empty.',
      );
    }

    // The recommending profile must belong to the account.
    if (account.getProfileById(
          normalizedProfileId,
        ) ==
        null) {
      throw ArgumentError(
        'The recommending profile does not belong to this account.',
      );
    }

    // Every profile on the account can vote on every recommendation.
    // Keep the legacy activeParticipants field populated for clients that
    // still render it, but never use it as an eligibility restriction.
    final Set<String> normalizedParticipants =
        account.profiles.map((profile) => profile.id).toSet();

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

    final DateTime createdAt = DateTime.now();

    final GroupRecommendation recommendation =
        GroupRecommendation(
      id: _generateId(),
      accountId: accountId,
      mediaId: normalizedMediaId,
      title: normalizedTitle,
      type: normalizedType,
      recommendedByProfileId:
          normalizedProfileId,
      createdAt: createdAt,
      votingEndsAt:
          createdAt.add(votingDuration),
      activeParticipants:
          normalizedParticipants,
    );

    database.saveGroupRecommendation(
      recommendation,
    );

    return recommendation;
  }

  // GET ONE RECOMMENDATION
  //
  // If the voting deadline has passed, finalize it before
  // returning it.
  GroupRecommendation? getRecommendation({
    required String accountId,
    required String recommendationId,
  }) {
    final GroupRecommendation? recommendation =
        database.getGroupRecommendationById(
  recommendationId,
);

    if (recommendation == null) {
      return null;
    }

    if (recommendation.accountId != accountId) {
      return null;
    }

    _finalizeIfVotingEnded(
      recommendation,
    );

    return recommendation;
  }

  // GET ALL RECOMMENDATIONS FOR AN ACCOUNT
  /// Performs `getRecommendations` for this feature. Update this documentation when its contract changes.
  List<GroupRecommendation> getRecommendations({
    required String accountId,
  }) {
    final List<GroupRecommendation> recommendations =
    database.getGroupRecommendationsForAccount(
  accountId,
);

    for (final GroupRecommendation recommendation
        in recommendations) {
      _finalizeIfVotingEnded(
        recommendation,
      );
    }

    return recommendations;
  }

  // GET ACTIVE VOTING RECOMMENDATIONS
  List<GroupRecommendation>
      getVotingRecommendations({
    required String accountId,
  }) {
    final List<GroupRecommendation> recommendations =
    database.getVotingGroupRecommendationsForAccount(
  accountId,
);

    final List<GroupRecommendation> active =
        <GroupRecommendation>[];

    for (final GroupRecommendation recommendation
        in recommendations) {
      _finalizeIfVotingEnded(
        recommendation,
      );

      if (recommendation.status ==
          GroupRecommendationStatus.voting) {
        active.add(recommendation);
      }
    }

    return active;
  }

  // VOTE
  //
  // Each profile can vote exactly once.
  //
  // Voting NEVER ends early just because everyone has voted.
  // The recommendation remains open until votingEndsAt.
  GroupRecommendation vote({
    required String accountId,
    required String recommendationId,
    required String profileId,
    required GroupRecommendationVote vote,
  }) {
    final GroupRecommendation? recommendation =
    database.getGroupRecommendationById(
  recommendationId,
);

    if (recommendation == null) {
      throw StateError(
        'Recommendation not found.',
      );
    }

    if (recommendation.accountId != accountId) {
      throw StateError(
        'Recommendation does not belong to this account.',
      );
    }

    final String normalizedProfileId =
        profileId.trim();

    if (normalizedProfileId.isEmpty) {
      throw ArgumentError(
        'Profile ID cannot be empty.',
      );
    }

    // Automatically finalize if the deadline has passed.
    if (recommendation.hasVotingEnded) {
      _finalizeIfVotingEnded(
        recommendation,
      );

      throw StateError(
        'Voting has ended for this recommendation.',
      );
    }

    if (recommendation.status !=
        GroupRecommendationStatus.voting) {
      throw StateError(
        'Voting is no longer available for this recommendation.',
      );
    }

    if (recommendation.hasVoted(
      normalizedProfileId,
    )) {
      throw StateError(
        'This profile has already voted on this recommendation.',
      );
    }

    final bool accepted = recommendation.addVote(
      normalizedProfileId,
      vote,
    );

    if (!accepted) {
      throw StateError(
        'Vote could not be submitted.',
      );
    }

    database.saveGroupRecommendation(
      recommendation,
    );

    return recommendation;
  }

  // FINALIZE RECOMMENDATION
  //
  // YES > NO -> APPROVED
  // NO > YES -> REJECTED
  // YES == NO -> REJECTED
  // 0 votes -> REJECTED
  //
  // If approved:
  //
  // - catalog recommendation -> add mediaId to Group Wishlist
  // - arbitrary recommendation -> add recommendation ID to
  //   Group Wishlist
  GroupRecommendation finalizeRecommendation({
    required String accountId,
    required String recommendationId,
  }) {
    final GroupRecommendation? recommendation =
    database.getGroupRecommendationById(
  recommendationId,
);

    if (recommendation == null) {
      throw StateError(
        'Recommendation not found.',
      );
    }

    if (recommendation.accountId != accountId) {
      throw StateError(
        'Recommendation does not belong to this account.',
      );
    }

    if (recommendation.status !=
        GroupRecommendationStatus.voting) {
      return recommendation;
    }

    if (!recommendation.hasVotingEnded) {
      throw StateError(
        'Voting has not ended yet.',
      );
    }

    _finalizeRecommendation(
      recommendation,
    );

    return recommendation;
  }

  // CLOSE VOTING
  //
  // Kept for compatibility with the existing route/API.
  //
  // The voting period cannot be closed before its deadline.
  GroupRecommendation closeVoting({
    required String accountId,
    required String recommendationId,
  }) {
    final GroupRecommendation? recommendation =
    database.getGroupRecommendationById(
  recommendationId,
);

    if (recommendation == null) {
      throw StateError(
        'Recommendation not found.',
      );
    }

    if (recommendation.accountId != accountId) {
      throw StateError(
        'Recommendation does not belong to this account.',
      );
    }

    if (recommendation.status !=
        GroupRecommendationStatus.voting) {
      return recommendation;
    }

    if (!recommendation.hasVotingEnded) {
      throw StateError(
        'Voting cannot be closed before the voting deadline.',
      );
    }

    _finalizeRecommendation(
      recommendation,
    );

    return recommendation;
  }

  // EXPIRE RECOMMENDATION
  //
  // Kept for compatibility with the existing API.
  //
  // A recommendation whose deadline has passed is resolved using
  // the actual vote result rather than simply being discarded.
  GroupRecommendation expireRecommendation({
    required String accountId,
    required String recommendationId,
  }) {
    final GroupRecommendation? recommendation =
    database.getGroupRecommendationById(
  recommendationId,
);

    if (recommendation == null) {
      throw StateError(
        'Recommendation not found.',
      );
    }

    if (recommendation.accountId != accountId) {
      throw StateError(
        'Recommendation does not belong to this account.',
      );
    }

    if (recommendation.status !=
        GroupRecommendationStatus.voting) {
      return recommendation;
    }

    if (!recommendation.hasVotingEnded) {
      throw StateError(
        'Voting has not ended yet.',
      );
    }

    _finalizeRecommendation(
      recommendation,
    );

    return recommendation;
  }

  // AUTOMATICALLY FINALIZE WHEN THE DEADLINE PASSES
  /// Performs `_finalizeIfVotingEnded` for this feature. Update this documentation when its contract changes.
  void _finalizeIfVotingEnded(
    GroupRecommendation recommendation,
  ) {
    if (recommendation.status !=
        GroupRecommendationStatus.voting) {
      return;
    }

    if (!recommendation.hasVotingEnded) {
      return;
    }

    _finalizeRecommendation(
      recommendation,
    );
  }

  // DETERMINE FINAL RESULT
  //
  // YES majority:
  //   -> approve
  //   -> add to Group Wishlist
  //
  // NO majority:
  //   -> reject
  //
  // Tie:
  //   -> reject
  //
  // No votes:
  //   -> reject
  /// Performs `_finalizeRecommendation` for this feature. Update this documentation when its contract changes.
  void _finalizeRecommendation(
    GroupRecommendation recommendation,
  ) {
    if (recommendation.status !=
        GroupRecommendationStatus.voting) {
      return;
    }

    if (recommendation.hasMajorityYes) {
      recommendation.approve();

      _addApprovedRecommendationToWishlist(
        recommendation,
      );
    } else {
      recommendation.reject();
    }

    database.saveGroupRecommendation(
      recommendation,
    );
  }

  // ADD APPROVED RECOMMENDATION TO GROUP WISHLIST
  //
  // If the recommendation points to catalog media, preserve the
  // existing wishlistMediaIds behavior.
  //
  // If it is an arbitrary title that is not in the catalog, save
  // the recommendation ID instead.
  /// Performs `_addApprovedRecommendationToWishlist` for this feature. Update this documentation when its contract changes.
  void _addApprovedRecommendationToWishlist(
    GroupRecommendation recommendation,
  ) {
    final Account? account =
        database.getAccountById(
      recommendation.accountId,
    );

    if (account == null) {
      return;
    }

    if (recommendation.mediaId != null &&
        recommendation.mediaId!.trim().isNotEmpty) {
      final String mediaId =
          recommendation.mediaId!.trim();

      if (!account.wishlistMediaIds.contains(
        mediaId,
      )) {
        account.wishlistMediaIds.add(
          mediaId,
        );
      }

      return;
    }

    if (!account.wishlistRecommendationIds.contains(
      recommendation.id,
    )) {
      account.wishlistRecommendationIds.add(
        recommendation.id,
      );
    }
  }

  // GET RECOMMENDATIONS CREATED BY A PROFILE
  List<GroupRecommendation>
      getRecommendationsByProfile({
    required String accountId,
    required String profileId,
  }) {
    final List<GroupRecommendation> recommendations =
    database
        .getGroupRecommendationsForAccount(
      accountId,
    )
        .where(
          (recommendation) =>
              recommendation.recommendedByProfileId ==
              profileId,
        )
        .toList();

for (final GroupRecommendation recommendation
    in recommendations) {
  _finalizeIfVotingEnded(
    recommendation,
  );
}
    return recommendations;
  }

  // GET RECOMMENDATIONS FOR CATALOG MEDIA
  //
  // Arbitrary recommendations have mediaId == null, so they
  // naturally do not appear in this query.
  List<GroupRecommendation>
      getRecommendationsForMedia({
    required String accountId,
    required String mediaId,
  }) {
    final List<GroupRecommendation> recommendations =
    database
        .getGroupRecommendationsForAccount(
      accountId,
    )
        .where(
          (recommendation) =>
              recommendation.mediaId == mediaId,
        )
        .toList();

    for (final GroupRecommendation recommendation
        in recommendations) {
      _finalizeIfVotingEnded(
        recommendation,
      );
    }

    return recommendations;
  }

  // CHECK WHETHER A PROFILE HAS VOTED
  /// Performs `hasVoted` for this feature. Update this documentation when its contract changes.
  bool hasVoted({
    required String accountId,
    required String recommendationId,
    required String profileId,
  }) {
    final GroupRecommendation? recommendation =
    database.getGroupRecommendationById(
  recommendationId,
);

    if (recommendation == null) {
      return false;
    }

    if (recommendation.accountId != accountId) {
      return false;
    }

    _finalizeIfVotingEnded(
      recommendation,
    );

    return recommendation.hasVoted(
      profileId,
    );
  }

  // GET A PROFILE'S VOTE
  GroupRecommendationVote? getVote({
    required String accountId,
    required String recommendationId,
    required String profileId,
  }) {
    final GroupRecommendation? recommendation =
    database.getGroupRecommendationById(
  recommendationId,
);

    if (recommendation == null) {
      return null;
    }

    if (recommendation.accountId != accountId) {
      return null;
    }

    _finalizeIfVotingEnded(
      recommendation,
    );

    return recommendation.voteFor(
      profileId,
    );
  }

  // DELETE RECOMMENDATION
  //
  // Also removes it from the Group Wishlist if it had previously
  // been approved.
  /// Performs `deleteRecommendation` for this feature. Update this documentation when its contract changes.
  void deleteRecommendation({
    required String accountId,
    required String recommendationId,
  }) {
    final GroupRecommendation? recommendation =
    database.getGroupRecommendationById(
  recommendationId,
);

    if (recommendation == null) {
      throw StateError(
        'Recommendation not found.',
      );
    }

    if (recommendation.accountId != accountId) {
      throw StateError(
        'Recommendation does not belong to this account.',
      );
    }

    final Account? account =
        database.getAccountById(accountId);

    if (account != null) {
      if (recommendation.mediaId != null &&
          recommendation.mediaId!.trim().isNotEmpty) {
        account.wishlistMediaIds.remove(
          recommendation.mediaId!.trim(),
        );
      }

      account.wishlistRecommendationIds.remove(
        recommendation.id,
      );
    }

    database.deleteGroupRecommendation(
      recommendationId,
    );
  }

  // CLEAR ALL RECOMMENDATIONS
  //
  // Used primarily for testing/resetting the in-memory database.
  /// Performs `clear` for this feature. Update this documentation when its contract changes.
  void clear() {
    database.clearGroupRecommendations();
  }

  /// Performs `_generateId` for this feature. Update this documentation when its contract changes.
  String _generateId() {
    return 'group_rec_${DateTime.now().microsecondsSinceEpoch}';
  }
}
