// FILE: Backend/models/review_publication.dart.
// Purpose: Distribution and conversation metadata for a media review.

class ReviewPublication {
  final String id;
  final String reviewId;
  final String mediaId;
  final String accountId;
  final String profileId;
  final String destination;
  final String? destinationId;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final bool spoiler;

  ReviewPublication({
    required this.id,
    required this.reviewId,
    required this.mediaId,
    required this.accountId,
    required this.profileId,
    required this.destination,
    this.destinationId,
    required this.createdAt,
    this.expiresAt,
    this.spoiler = false,
  });

  bool get isExpired => expiresAt != null && !DateTime.now().isBefore(expiresAt!);

  Map<String, dynamic> toJson() => {
        'id': id,
        'reviewId': reviewId,
        'mediaId': mediaId,
        'destination': destination,
        'destinationId': destinationId,
        'createdAt': createdAt.toIso8601String(),
        'expiresAt': expiresAt?.toIso8601String(),
        'spoiler': spoiler,
      };
}

class ReviewInteraction {
  final String id;
  final String reviewPublicationId;
  final String accountId;
  final String profileId;
  final String type;
  final String body;
  final String? reaction;
  final DateTime createdAt;

  ReviewInteraction({
    required this.id,
    required this.reviewPublicationId,
    required this.accountId,
    required this.profileId,
    required this.type,
    required this.body,
    this.reaction,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'reviewPublicationId': reviewPublicationId,
        'profileId': profileId,
        'type': type,
        'body': body,
        'reaction': reaction,
        'createdAt': createdAt.toIso8601String(),
      };
}
