/// Review domain model used by profile and global media reviews.
class MediaReview {
  final String id;
  final String mediaId;
  final String accountId;
  final String profileId;
  final String profileName;
  final double score;
  final String label;
  final String text;
  final String globalUsername;
  final DateTime createdAt;

  MediaReview({
    required this.id,
    required this.mediaId,
    required this.accountId,
    required this.profileId,
    required this.profileName,
    required this.score,
    required this.label,
    required this.text,
    required this.globalUsername,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson({bool global = false}) => {
    'id': id,
    'mediaId': mediaId,
    'score': score,
    'label': label,
    'text': text,
    'username': global ? globalUsername : profileName,
    'createdAt': createdAt.toIso8601String(),
  };
}
