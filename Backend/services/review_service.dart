// Business logic for private-profile and privacy-preserving global reviews.
import '../database/database.dart';
import '../models/review.dart';

class ReviewService {
  final Database database;
  ReviewService(this.database);

  /// Creates or replaces a review for the authenticated profile.
  MediaReview create({
    required String accountId,
    required String profileId,
    required String profileName,
    required String mediaId,
    required double score,
    required String label,
    required String text,
    required String globalUsername,
  }) {
    if (score < 0 || score > 10) throw Exception('Review score must be between 0 and 10.');
    if (text.trim().isEmpty) throw Exception('Review text is required.');
    final review = MediaReview(
      id: '${accountId}_${profileId}_$mediaId',
      mediaId: mediaId,
      accountId: accountId,
      profileId: profileId,
      profileName: profileName,
      score: score,
      label: label.trim().isEmpty ? _defaultLabel(score) : label.trim(),
      text: text.trim(),
      globalUsername: globalUsername.trim().isEmpty ? 'AnonymousViewer' : globalUsername.trim(),
    );
    database.reviewsById[review.id] = review;
    return review;
  }

  /// Returns reviews visible to profiles inside the same account.
  List<MediaReview> accountReviews(String accountId, String mediaId) => database.reviewsById.values
      .where((r) => r.accountId == accountId && r.mediaId == mediaId)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Returns privacy-safe public reviews; email/account identity is never exposed.
  List<MediaReview> globalReviews(String mediaId) => database.reviewsById.values
      .where((r) => r.mediaId == mediaId)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  String _defaultLabel(double score) {
    if (score >= 9) return 'Excellent';
    if (score >= 7) return 'Great';
    if (score >= 5) return 'Mediocre';
    if (score >= 3) return 'Weak';
    return 'Terrible';
  }
}
