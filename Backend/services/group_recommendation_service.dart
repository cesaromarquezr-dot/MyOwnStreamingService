import '../database/database.dart';
import '../models/group_recommendation.dart';
import '../models/media.dart';

class GroupRecommendationService {
  final Database database;

  GroupRecommendationService(this.database);

  // CREATE RECOMMENDATION
  GroupRecommendation createRecommendation({
    required String accountId,
    required Media media,
    required String recommendedByProfileId,
    required Set<String> activeParticipants,
  }) {
    if (accountId.trim().isEmpty) {
      throw ArgumentError(
        'Account ID cannot be empty.',
      );
    }

    if (media.id.trim().isEmpty) {
      throw ArgumentError(
        'Media ID cannot be empty.',
      );
    }

    if (media.title.trim().isEmpty) {
      throw ArgumentError(
        'Media title cannot be empty.',
      );
    }

    if (recommendedByProfileId.trim().isEmpty) {
      throw ArgumentError(
        'Recommended-by profile ID cannot be empty.',
      );
    }

    if (activeParticipants.isEmpty) {
      throw ArgumentError(
        'At least one active participant is required.',
      );
    }

    if (!activeParticipants.contains(
      recommendedByProfileId,
    )) {
      throw ArgumentError(
        'The recommending profile must be an active participant.',
      );
    }

    final recommendation = GroupRecommendation(
      id: _generateId(),
      accountId: accountId,
      mediaId: media.id,
      title: media.title,
      type: media.type.name,
      recommendedByProfileId:
          recommendedByProfileId,
      createdAt: DateTime.now(),
      activeParticipants:
          Set<String>.from(activeParticipants),
    );

    database.saveGroupRecommendation(
      recommendation,
    );

    return recommendation;
  }

  // GET ONE RECOMMENDATION
  GroupRecommendation? getRecommendation({
    required String accountId,
    required String recommendationId,
  }) {
    final recommendation =
        database.getGroupRecommendation(
      recommendationId,
    );

    if (recommendation == null) {
      return null;
    }

    if (recommendation.accountId != accountId) {
      return null;
    }

    return recommendation;
  }

  // GET ALL RECOMMENDATIONS FOR AN ACCOUNT
  List<GroupRecommendation> getRecommendations({
    required String accountId,
  }) {
    return database
        .getGroupRecommendations()
        .where(
          (recommendation) =>
              recommendation.accountId == accountId,
        )
        .toList();
  }

  // GET ACTIVE VOTING RECOMMENDATIONS FOR AN ACCOUNT
  List<GroupRecommendation>
      getVotingRecommendations({
    required String accountId,
  }) {
    return database
        .getVotingGroupRecommendations()
        .where(
          (recommendation) =>
              recommendation.accountId == accountId,
        )
        .toList();
  }

  // VOTE
  GroupRecommendation vote({
    required String accountId,
    required String recommendationId,
    required String profileId,
    required GroupRecommendationVote vote,
  }) {
    final recommendation =
        database.getGroupRecommendation(
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

    if (profileId.trim().isEmpty) {
      throw ArgumentError(
        'Profile ID cannot be empty.',
      );
    }

    if (recommendation.status !=
        GroupRecommendationStatus.voting) {
      throw StateError(
        'Voting is no longer available for this recommendation.',
      );
    }

    if (!recommendation.activeParticipants
        .contains(profileId)) {
      throw StateError(
        'This profile was not active when voting started.',
      );
    }

    recommendation.addVote(
      profileId,
      vote,
    );

    _checkMajority(
      recommendation,
    );

    database.saveGroupRecommendation(
      recommendation,
    );

    return recommendation;
  }

  // CHECK WHETHER A MAJORITY HAS BEEN REACHED
  void _checkMajority(
    GroupRecommendation recommendation,
  ) {
    final totalParticipants =
        recommendation.activeParticipants.length;

    final totalVotes =
        recommendation.totalVotes;

    if (totalVotes < totalParticipants) {
      return;
    }

    if (recommendation.hasMajorityYes) {
      recommendation.approve();
    } else {
      recommendation.reject();
    }
  }

  // CLOSE VOTING
  GroupRecommendation closeVoting({
    required String accountId,
    required String recommendationId,
  }) {
    final recommendation =
        database.getGroupRecommendation(
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

    if (recommendation.hasMajorityYes) {
      recommendation.approve();
    } else {
      recommendation.reject();
    }

    database.saveGroupRecommendation(
      recommendation,
    );

    return recommendation;
  }

  // EXPIRE RECOMMENDATION
  GroupRecommendation expireRecommendation({
    required String accountId,
    required String recommendationId,
  }) {
    final recommendation =
        database.getGroupRecommendation(
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

    recommendation.expire();

    database.saveGroupRecommendation(
      recommendation,
    );

    return recommendation;
  }

  // GET RECOMMENDATIONS CREATED BY A PROFILE
  List<GroupRecommendation>
      getRecommendationsByProfile({
    required String accountId,
    required String profileId,
  }) {
    return database
        .getGroupRecommendations()
        .where(
          (recommendation) =>
              recommendation.accountId == accountId &&
              recommendation.recommendedByProfileId ==
                  profileId,
        )
        .toList();
  }

  // GET RECOMMENDATIONS FOR MEDIA
  List<GroupRecommendation>
      getRecommendationsForMedia({
    required String accountId,
    required String mediaId,
  }) {
    return database
        .getGroupRecommendations()
        .where(
          (recommendation) =>
              recommendation.accountId == accountId &&
              recommendation.mediaId == mediaId,
        )
        .toList();
  }

  // CHECK WHETHER A PROFILE HAS VOTED
  bool hasVoted({
    required String accountId,
    required String recommendationId,
    required String profileId,
  }) {
    final recommendation =
        database.getGroupRecommendation(
      recommendationId,
    );

    if (recommendation == null) {
      return false;
    }

    if (recommendation.accountId != accountId) {
      return false;
    }

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
    final recommendation =
        database.getGroupRecommendation(
      recommendationId,
    );

    if (recommendation == null) {
      return null;
    }

    if (recommendation.accountId != accountId) {
      return null;
    }

    return recommendation.voteFor(
      profileId,
    );
  }

  // DELETE RECOMMENDATION
  void deleteRecommendation({
    required String accountId,
    required String recommendationId,
  }) {
    final recommendation =
        database.getGroupRecommendation(
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

    database.deleteGroupRecommendation(
      recommendationId,
    );
  }

  // CLEAR ALL RECOMMENDATIONS
  //
  // Used primarily for testing/resetting the in-memory database.
  void clear() {
    database.clearGroupRecommendations();
  }

  String _generateId() {
    return 'group_rec_${DateTime.now().microsecondsSinceEpoch}';
  }
}