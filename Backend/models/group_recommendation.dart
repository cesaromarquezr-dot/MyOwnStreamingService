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

  final String mediaId;
  final String title;
  final String type;
  final String recommendedByProfileId;
  final DateTime createdAt;

  GroupRecommendationStatus status;

  /// profileId -> vote
  final Map<String, GroupRecommendationVote> votes;

  /// Profiles who were active when the recommendation was created.
  final Set<String> activeParticipants;

  GroupRecommendation({
    required this.id,
    required this.accountId,
    required this.mediaId,
    required this.title,
    required this.type,
    required this.recommendedByProfileId,
    required this.createdAt,
    this.status = GroupRecommendationStatus.voting,
    Map<String, GroupRecommendationVote>? votes,
    Set<String>? activeParticipants,
  })  : votes = votes ?? <String, GroupRecommendationVote>{},
        activeParticipants = activeParticipants ?? <String>{};

  int get yesVotes => votes.values
      .where(
        (vote) => vote == GroupRecommendationVote.yes,
      )
      .length;

  int get noVotes => votes.values
      .where(
        (vote) => vote == GroupRecommendationVote.no,
      )
      .length;

  int get totalVotes => votes.length;

  bool hasVoted(String profileId) {
    return votes.containsKey(profileId);
  }

  GroupRecommendationVote? voteFor(String profileId) {
    return votes[profileId];
  }

  void addVote(
    String profileId,
    GroupRecommendationVote vote,
  ) {
    if (!activeParticipants.contains(profileId)) {
      return;
    }

    if (status != GroupRecommendationStatus.voting) {
      return;
    }

    votes[profileId] = vote;
  }

  bool get hasMajorityYes {
    if (votes.isEmpty) {
      return false;
    }

    return yesVotes > noVotes;
  }

  bool get hasMajorityNo {
    if (votes.isEmpty) {
      return false;
    }

    return noVotes > yesVotes;
  }

  void approve() {
    status = GroupRecommendationStatus.approved;
  }

  void reject() {
    status = GroupRecommendationStatus.rejected;
  }

  void expire() {
    status = GroupRecommendationStatus.expired;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'accountId': accountId,
      'mediaId': mediaId,
      'title': title,
      'type': type,
      'recommendedByProfileId':
          recommendedByProfileId,
      'createdAt': createdAt.toIso8601String(),
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
    };
  }

  factory GroupRecommendation.fromJson(
    Map<String, dynamic> json,
  ) {
    final votesJson =
        json['votes'] as Map<String, dynamic>? ??
            <String, dynamic>{};

    final activeParticipantsJson =
        json['activeParticipants'] as List<dynamic>? ??
            <dynamic>[];

    final statusString =
        json['status'] as String? ??
            GroupRecommendationStatus.voting.name;

    return GroupRecommendation(
      id: json['id'] as String,

      accountId:
          json['accountId'] as String? ?? '',

      mediaId: json['mediaId'] as String,
      title: json['title'] as String,
      type: json['type'] as String,

      recommendedByProfileId:
          json['recommendedByProfileId'] as String,

      createdAt: DateTime.parse(
        json['createdAt'] as String,
      ),

      status:
          GroupRecommendationStatus.values.firstWhere(
        (status) => status.name == statusString,
        orElse: () =>
            GroupRecommendationStatus.voting,
      ),

      votes: votesJson.map(
        (profileId, vote) {
          return MapEntry(
            profileId,
            GroupRecommendationVote.values
                .firstWhere(
              (value) => value.name == vote,
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