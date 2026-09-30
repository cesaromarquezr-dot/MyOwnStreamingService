// FILE: Backend/services/review_publication_service.dart.
// Purpose: Publishes reviews to profile, story, community, or private
// destinations and provides a shared reaction/comment/note interaction layer.

import '../models/review_publication.dart';

class ReviewPublicationService {
  final Map<String, ReviewPublication> publicationsById = <String, ReviewPublication>{};
  final List<ReviewInteraction> interactions = <ReviewInteraction>[];

  ReviewPublication publish({
    required String reviewId,
    required String mediaId,
    required String accountId,
    required String profileId,
    required String destination,
    String? destinationId,
    bool spoiler = false,
  }) {
    const destinations = {'profile', 'story', 'community', 'private'};
    if (!destinations.contains(destination)) throw const FormatException('Unsupported review destination.');
    if (destination == 'community' && (destinationId == null || destinationId.trim().isEmpty)) {
      throw const FormatException('A community ID is required for community publication.');
    }
    final now = DateTime.now().toUtc();
    final publication = ReviewPublication(
      id: '${reviewId}_${destination}_${destinationId ?? profileId}',
      reviewId: reviewId,
      mediaId: mediaId,
      accountId: accountId,
      profileId: profileId,
      destination: destination,
      destinationId: destinationId,
      createdAt: now,
      expiresAt: destination == 'story' ? now.add(const Duration(hours: 24)) : null,
      spoiler: spoiler,
    );
    publicationsById[publication.id] = publication;
    return publication;
  }

  List<ReviewPublication> forReview(String reviewId) => publicationsById.values
      .where((publication) => publication.reviewId == reviewId && !publication.isExpired)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  ReviewInteraction addInteraction({
    required String publicationId,
    required String accountId,
    required String profileId,
    required String type,
    String body = '',
    String? reaction,
  }) {
    const types = {'reaction', 'comment', 'note'};
    if (!types.contains(type)) throw const FormatException('Unsupported review interaction.');
    if (type != 'reaction' && body.trim().isEmpty) throw const FormatException('Interaction text is required.');
    if (type == 'reaction' && (reaction == null || reaction.trim().isEmpty)) throw const FormatException('Reaction is required.');
    if (!publicationsById.containsKey(publicationId)) throw const FormatException('Review publication not found.');
    final interaction = ReviewInteraction(
      id: 'review_interaction_${DateTime.now().microsecondsSinceEpoch}',
      reviewPublicationId: publicationId,
      accountId: accountId,
      profileId: profileId,
      type: type,
      body: body.trim(),
      reaction: reaction?.trim(),
      createdAt: DateTime.now().toUtc(),
    );
    interactions.add(interaction);
    return interaction;
  }

  Map<String, dynamic> interactionsFor(String publicationId) => {
        'reactions': interactions.where((i) => i.reviewPublicationId == publicationId && i.type == 'reaction').map((i) => i.toJson()).toList(),
        'comments': interactions.where((i) => i.reviewPublicationId == publicationId && i.type == 'comment').map((i) => i.toJson()).toList(),
        'notes': interactions.where((i) => i.reviewPublicationId == publicationId && i.type == 'note').map((i) => i.toJson()).toList(),
      };
}
