// FILE: `Backend/models/group_recommendation.dart`.
// Purpose: Implements the group recommendation portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

enum GroupRecommendationStatus {
  voting,
  approved,
  rejected,
  expired,
}

enum GroupRecommendationVote {
  yes,
  no,
}

class GroupRecommendation {
  final String id;

  /// The account/group this recommendation belongs to.
  final String accountId;

  /// Optional catalog media ID.
  ///
  /// A recommendation does NOT have to exist in the catalog,
  /// so this can be null for manually entered recommendations.
  final String? mediaId;

  /// The movie or TV show title entered by the user.
  final String title;

  /// "movie" or "tvShow".
  final String type;

  /// The profile that originally submitted the recommendation.
  final String recommendedByProfileId;

  /// When the recommendation was created.
  final DateTime createdAt;

  /// When voting closes.
  final DateTime votingEndsAt;

  GroupRecommendationStatus status;

  /// profileId -> vote
  final Map<String, GroupRecommendationVote> votes;

  /// Profiles who were eligible to vote when the recommendation
  /// was created.
  final Set<String> activeParticipants;

  GroupRecommendation({
    required this.id,
    required this.accountId,
    this.mediaId,
    required this.title,
    required this.type,
    required this.recommendedByProfileId,
    required this.createdAt,
    required this.votingEndsAt,
    this.status = GroupRecommendationStatus.voting,
    Map<String, GroupRecommendationVote>? votes,
    Set<String>? activeParticipants,
  })  : votes = votes ?? <String, GroupRecommendationVote>{},
        activeParticipants =
            activeParticipants ?? <String>{};

  /// Number of YES votes.
  int get yesVotes => votes.values
      .where(
        (vote) => vote == GroupRecommendationVote.yes,
      )
      .length;

  /// Number of NO votes.
  int get noVotes => votes.values
      .where(
        (vote) => vote == GroupRecommendationVote.no,
      )
      .length;

  /// Total number of submitted votes.
  int get totalVotes => votes.length;

  /// YES percentage among submitted votes.
  ///
  /// Returns 0 when nobody has voted yet.
  double get yesPercentage {
    if (totalVotes == 0) {
      return 0;
    }

    return (yesVotes / totalVotes) * 100;
  }

  /// NO percentage among submitted votes.
  ///
  /// Returns 0 when nobody has voted yet.
  double get noPercentage {
    if (totalVotes == 0) {
      return 0;
    }

    return (noVotes / totalVotes) * 100;
  }

  /// Whether voting is currently open.
  bool get isVotingOpen {
    return status == GroupRecommendationStatus.voting &&
        DateTime.now().isBefore(votingEndsAt);
  }

  /// Whether the voting deadline has been reached.
  bool get hasVotingEnded {
    return DateTime.now().isAfter(votingEndsAt) ||
        DateTime.now().isAtSameMomentAs(votingEndsAt);
  }

  /// Amount of time remaining before voting closes.
  Duration get timeRemaining {
    final Duration remaining =
        votingEndsAt.difference(DateTime.now());

    if (remaining.isNegative) {
      return Duration.zero;
    }

    return remaining;
  }

  /// Whether this profile has already voted.
  bool hasVoted(String profileId) {
    return votes.containsKey(profileId);
  }

  /// Returns the vote belonging to a profile, if one exists.
  GroupRecommendationVote? voteFor(String profileId) {
    return votes[profileId];
  }

  /// Adds a vote.
  ///
  /// Returns true when the vote was accepted.
  /// Returns false when the profile is not eligible, has already
  /// voted, or voting has closed.
  bool addVote(
    String profileId,
    GroupRecommendationVote vote,
  ) {
    if (!activeParticipants.contains(profileId)) {
      return false;
    }

    if (status != GroupRecommendationStatus.voting) {
      return false;
    }

    if (hasVotingEnded) {
      return false;
    }

    if (votes.containsKey(profileId)) {
      return false;
    }

    votes[profileId] = vote;
    return true;
  }

  /// Whether YES currently has more votes than NO.
  bool get hasMajorityYes {
    if (votes.isEmpty) {
      return false;
    }

    return yesVotes > noVotes;
  }

  /// Whether NO currently has more votes than YES.
  bool get hasMajorityNo {
    if (votes.isEmpty) {
      return false;
    }

    return noVotes > yesVotes;
  }

  /// Whether the vote is currently tied.
  bool get isTie {
    return totalVotes > 0 &&
        yesVotes == noVotes;
  }

  /// Approves the recommendation.
  void approve() {
    status = GroupRecommendationStatus.approved;
  }

  /// Rejects the recommendation.
  void reject() {
    status = GroupRecommendationStatus.rejected;
  }

  /// Marks the recommendation as expired.
  void expire() {
    status = GroupRecommendationStatus.expired;
  }

  /// Performs `toJson` for this feature. Update this documentation when its contract changes.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'accountId': accountId,

      /// Nullable because recommendations do not have
      /// to exist in the catalog.
      'mediaId': mediaId,

      'title': title,
      'type': type,

      'recommendedByProfileId':
          recommendedByProfileId,

      'createdAt':
          createdAt.toIso8601String(),

      'votingEndsAt':
          votingEndsAt.toIso8601String(),

      'status': status.name,

      'votes': votes.map(
        (profileId, vote) => MapEntry(
          profileId,
          vote.name,
        ),
      ),

      'activeParticipants':
          activeParticipants.toList(),

      'yesVotes': yesVotes,
      'noVotes': noVotes,
      'totalVotes': totalVotes,

      'yesPercentage': yesPercentage,
      'noPercentage': noPercentage,
    };
  }

  factory GroupRecommendation.fromJson(
    Map<String, dynamic> json,
  ) {
    final dynamic rawVotes =
        json['votes'];

    final Map<String, dynamic> votesJson =
        rawVotes is Map
            ? rawVotes.map(
                (key, value) => MapEntry(
                  key.toString(),
                  value,
                ),
              )
            : <String, dynamic>{};

    final dynamic rawParticipants =
        json['activeParticipants'];

    final List<dynamic> activeParticipantsJson =
        rawParticipants is List
            ? rawParticipants
            : <dynamic>[];

    final String statusString =
        json['status'] as String? ??
            GroupRecommendationStatus.voting.name;

    final String createdAtString =
        json['createdAt'] as String;

    final String? votingEndsAtString =
        json['votingEndsAt'] as String?;

    return GroupRecommendation(
      id: json['id'] as String,

      accountId:
          json['accountId'] as String? ?? '',

      /// Older recommendations may still contain
      /// a mediaId. New recommendations may not.
      mediaId:
          json['mediaId'] as String?,

      title:
          json['title'] as String,

      type:
          json['type'] as String,

      recommendedByProfileId:
          json['recommendedByProfileId']
              as String,

      createdAt:
          DateTime.parse(createdAtString),

      /// For old records that do not have a deadline,
      /// give them a 24-hour voting window from creation.
      votingEndsAt:
          votingEndsAtString != null
              ? DateTime.parse(
                  votingEndsAtString,
                )
              : DateTime.parse(
                  createdAtString,
                ).add(
                  const Duration(
                    hours: 24,
                  ),
                ),

      status:
          GroupRecommendationStatus.values
              .firstWhere(
        (status) =>
            status.name == statusString,
        orElse: () =>
            GroupRecommendationStatus.voting,
      ),

      votes: votesJson.map(
        (profileId, vote) {
          return MapEntry(
            profileId,
            GroupRecommendationVote.values
                .firstWhere(
              (value) =>
                  value.name == vote.toString(),
              orElse: () =>
                  GroupRecommendationVote.no,
            ),
          );
        },
      ),

      activeParticipants:
          activeParticipantsJson
              .map(
                (item) => item.toString(),
              )
              .toSet(),
    );
  }
}
