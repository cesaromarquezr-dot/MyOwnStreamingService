// FILE: `Backend/models/group_recommendation.dart`.
// Purpose: Implements the group recommendation portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.
//
// A recommendation belongs to an account/group and can optionally reference
// catalog media. Voting eligibility is captured at creation time through
// activeParticipants so later profile changes do not silently alter the
// original voting population.

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
/// A recommendation does not have to exist in the catalog, so this can be
/// null for manually entered recommendations.
final String? mediaId;

/// The movie or TV show title entered by the user.
final String title;

/// Expected values include "movie" and "tvShow".
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

/// Profiles who were eligible to vote when the recommendation was created.
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

// ---------------------------------------------------------------------------
// VOTE COUNTS
// ---------------------------------------------------------------------------

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

double get yesPercentage {
if (totalVotes == 0) {
return 0;
}

return (yesVotes / totalVotes) * 100;

}

double get noPercentage {
if (totalVotes == 0) {
return 0;
}

return (noVotes / totalVotes) * 100;

}

// ---------------------------------------------------------------------------
// VOTING STATE
// ---------------------------------------------------------------------------

bool get isVotingOpen {
return status == GroupRecommendationStatus.voting &&
DateTime.now().isBefore(votingEndsAt);
}

bool get hasVotingEnded {
return !DateTime.now().isBefore(votingEndsAt);
}

Duration get timeRemaining {
final remaining =
votingEndsAt.difference(DateTime.now());

if (remaining.isNegative) {
  return Duration.zero;
}

return remaining;

}

bool hasVoted(
String profileId,
) {
final cleanProfileId = profileId.trim();

if (cleanProfileId.isEmpty) {
  return false;
}

return votes.containsKey(cleanProfileId);

}

GroupRecommendationVote? voteFor(
String profileId,
) {
final cleanProfileId = profileId.trim();

if (cleanProfileId.isEmpty) {
  return null;
}

return votes[cleanProfileId];

}

/// Adds a vote.
///
/// Returns true when the vote was accepted.
/// Returns false when the profile is not eligible, has already voted,
/// or voting has closed.
bool addVote(
String profileId,
GroupRecommendationVote vote,
) {
final cleanProfileId = profileId.trim();

if (cleanProfileId.isEmpty) {
  return false;
}

if (!activeParticipants.contains(cleanProfileId)) {
  return false;
}

if (status != GroupRecommendationStatus.voting) {
  return false;
}

if (hasVotingEnded) {
  return false;
}

if (votes.containsKey(cleanProfileId)) {
  return false;
}

votes[cleanProfileId] = vote;

return true;

}

/// Whether YES currently has more submitted votes than NO.
bool get hasMajorityYes {
if (votes.isEmpty) {
return false;
}

return yesVotes > noVotes;

}

/// Whether NO currently has more submitted votes than YES.
bool get hasMajorityNo {
if (votes.isEmpty) {
return false;
}

return noVotes > yesVotes;

}

/// Whether the submitted vote count is currently tied.
bool get isTie {
return totalVotes > 0 &&
yesVotes == noVotes;
}

// ---------------------------------------------------------------------------
// STATUS
// ---------------------------------------------------------------------------

void approve() {
status = GroupRecommendationStatus.approved;
}

void reject() {
status = GroupRecommendationStatus.rejected;
}

void expire() {
status = GroupRecommendationStatus.expired;
}

/// Expires an open recommendation when its deadline has passed.
///
/// Returns true when the status changed.
bool expireIfNeeded() {
if (status != GroupRecommendationStatus.voting) {
return false;
}

if (!hasVotingEnded) {
  return false;
}

expire();
return true;

}

// ---------------------------------------------------------------------------
// JSON
// ---------------------------------------------------------------------------

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
final createdAt =
_parseDateTime(
json['createdAt'],
) ??
DateTime.now();

final votingEndsAt =
    _parseDateTime(
      json['votingEndsAt'],
    ) ??
    createdAt.add(
      const Duration(hours: 24),
    );

final rawVotes = json['votes'];

final votesJson = <String, dynamic>{};

if (rawVotes is Map) {
  for (final entry in rawVotes.entries) {
    final profileId =
        entry.key.toString().trim();

    if (profileId.isEmpty) {
      continue;
    }

    votesJson[profileId] = entry.value;
  }
}

final parsedVotes =
    <String, GroupRecommendationVote>{};

for (final entry in votesJson.entries) {
  final vote =
      _parseVote(entry.value);

  if (vote == null) {
    continue;
  }

  parsedVotes[entry.key] = vote;
}

final rawParticipants =
    json['activeParticipants'];

final participants =
    <String>{};

if (rawParticipants is List) {
  for (final item in rawParticipants) {
    final profileId =
        item.toString().trim();

    if (profileId.isNotEmpty) {
      participants.add(profileId);
    }
  }
}

// Preserve compatibility with old records that may not contain the
// active participant snapshot.
if (participants.isEmpty &&
    parsedVotes.isNotEmpty) {
  participants.addAll(parsedVotes.keys);
}

return GroupRecommendation(
  id: _stringValue(json['id']),
  accountId: _stringValue(
    json['accountId'],
  ),
  mediaId: _nullableString(
    json['mediaId'],
  ),
  title: _stringValue(
    json['title'],
  ),
  type: _stringOrDefault(
    json['type'],
    'movie',
  ),
  recommendedByProfileId:
      _stringValue(
    json['recommendedByProfileId'],
  ),
  createdAt: createdAt,
  votingEndsAt: votingEndsAt,
  status: _parseStatus(
    json['status'],
  ),
  votes: parsedVotes,
  activeParticipants: participants,
);

}
}

// -----------------------------------------------------------------------------
// PARSING HELPERS
// -----------------------------------------------------------------------------

GroupRecommendationStatus _parseStatus(
Object? value,
) {
final name = value?.toString().trim();

if (name == null || name.isEmpty) {
return GroupRecommendationStatus.voting;
}

for (final status
in GroupRecommendationStatus.values) {
if (status.name == name) {
return status;
}
}

return GroupRecommendationStatus.voting;
}

GroupRecommendationVote? _parseVote(
Object? value,
) {
final name = value?.toString().trim();

if (name == null || name.isEmpty) {
return null;
}

for (final vote
in GroupRecommendationVote.values) {
if (vote.name == name) {
return vote;
}
}

return null;
}

DateTime? _parseDateTime(
Object? value,
) {
if (value is DateTime) {
return value;
}

final text = value?.toString().trim();

if (text == null || text.isEmpty) {
return null;
}

return DateTime.tryParse(text);
}

String _stringValue(
Object? value,
) {
return value?.toString().trim() ?? '';
}

String _stringOrDefault(
Object? value,
String fallback,
) {
final valueString =
value?.toString().trim();

if (valueString == null ||
valueString.isEmpty) {
return fallback;
}

return valueString;
}

String? _nullableString(
Object? value,
) {
final valueString =
value?.toString().trim();

if (valueString == null ||
valueString.isEmpty) {
return null;
}

return valueString;
}
