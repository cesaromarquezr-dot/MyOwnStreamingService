// FILE: Backend/services/review_service.dart
//
// Business logic for private-profile and privacy-preserving global reviews.
//
// Privacy rules:
// - Account IDs are never exposed by global review queries.
// - Global reviews intentionally return only the MediaReview model's public
//   fields; callers/routes must not serialize private account data separately.
// - Reviews are scoped to an account/profile for ownership checks at the route
//   layer and service layer.
// - Review text and display labels are bounded to prevent oversized payloads.

import '../database/database.dart';
import '../models/review.dart';

class ReviewService {
  static const double minScore = 0;
  static const double maxScore = 10;

  static const int maxAccountIdLength = 200;
  static const int maxProfileIdLength = 200;
  static const int maxProfileNameLength = 200;
  static const int maxMediaIdLength = 200;
  static const int maxLabelLength = 100;
  static const int maxReviewTextLength = 10 * 1024;
  static const int maxGlobalUsernameLength = 100;

  final Database database;

  ReviewService(this.database);

  /// Creates or replaces a review for the authenticated profile.
  ///
  /// Replacement identity remains compatible with the existing implementation:
  /// one review per account/profile/media combination.
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
    final normalizedAccountId = _requiredId(
      accountId,
      field: 'Account ID',
      maxLength: maxAccountIdLength,
    );
    final normalizedProfileId = _requiredId(
      profileId,
      field: 'Profile ID',
      maxLength: maxProfileIdLength,
    );
    final normalizedMediaId = _requiredId(
      mediaId,
      field: 'Media ID',
      maxLength: maxMediaIdLength,
    );

    final normalizedProfileName = _boundedRequiredText(
      profileName,
      field: 'Profile name',
      maxLength: maxProfileNameLength,
    );

    if (!_isValidScore(score)) {
      throw Exception('Review score must be between 0 and 10.');
    }

    final normalizedText = _boundedRequiredText(
      text,
      field: 'Review text',
      maxLength: maxReviewTextLength,
    );

    final normalizedLabel = _boundedOptionalText(
      label,
      field: 'Review label',
      maxLength: maxLabelLength,
    );

    final normalizedGlobalUsername = _boundedOptionalText(
      globalUsername,
      field: 'Global username',
      maxLength: maxGlobalUsernameLength,
    );

    final review = MediaReview(
      id: '${normalizedAccountId}_${normalizedProfileId}_$normalizedMediaId',
      mediaId: normalizedMediaId,
      accountId: normalizedAccountId,
      profileId: normalizedProfileId,
      profileName: normalizedProfileName,
      score: score,
      label: normalizedLabel.isEmpty
          ? _defaultLabel(score)
          : normalizedLabel,
      text: normalizedText,
      globalUsername: normalizedGlobalUsername.isEmpty
          ? 'AnonymousViewer'
          : normalizedGlobalUsername,
    );

    database.reviewsById[review.id] = review;
    return review;
  }

  /// Returns reviews visible to profiles inside the same account.
  ///
  /// The route/service caller must establish that [accountId] belongs to the
  /// authenticated session. This method does not expose reviews from other
  /// accounts.
  List<MediaReview> accountReviews(
    String accountId,
    String mediaId,
  ) {
    final normalizedAccountId = _requiredId(
      accountId,
      field: 'Account ID',
      maxLength: maxAccountIdLength,
    );
    final normalizedMediaId = _requiredId(
      mediaId,
      field: 'Media ID',
      maxLength: maxMediaIdLength,
    );

    final reviews = database.reviewsById.values
        .where(
          (review) =>
              review.accountId == normalizedAccountId &&
              review.mediaId == normalizedMediaId,
        )
        .toList();

    reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List<MediaReview>.unmodifiable(reviews);
  }

  /// Returns privacy-safe public reviews for a media item.
  ///
  /// Account identity is intentionally not used as a public identifier.
  /// The MediaReview model's [globalUsername] is the only display identity
  /// intended for global review presentation.
  List<MediaReview> globalReviews(String mediaId) {
    final normalizedMediaId = _requiredId(
      mediaId,
      field: 'Media ID',
      maxLength: maxMediaIdLength,
    );

    final reviews = database.reviewsById.values
        .where((review) => review.mediaId == normalizedMediaId)
        .map(_publicReviewCopy)
        .toList();

    reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List<MediaReview>.unmodifiable(reviews);
  }

  /// Returns reviews written by one profile for one media item.
  List<MediaReview> reviewsForProfile({
    required String accountId,
    required String profileId,
    String? mediaId,
  }) {
    final normalizedAccountId = _requiredId(
      accountId,
      field: 'Account ID',
      maxLength: maxAccountIdLength,
    );
    final normalizedProfileId = _requiredId(
      profileId,
      field: 'Profile ID',
      maxLength: maxProfileIdLength,
    );

    final normalizedMediaId = mediaId == null || mediaId.trim().isEmpty
        ? null
        : _requiredId(
            mediaId,
            field: 'Media ID',
            maxLength: maxMediaIdLength,
          );

    final reviews = database.reviewsById.values
        .where(
          (review) =>
              review.accountId == normalizedAccountId &&
              review.profileId == normalizedProfileId &&
              (normalizedMediaId == null ||
                  review.mediaId == normalizedMediaId),
        )
        .toList();

    reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List<MediaReview>.unmodifiable(reviews);
  }

  /// Finds the current profile's review for a media item.
  MediaReview? reviewForProfile({
    required String accountId,
    required String profileId,
    required String mediaId,
  }) {
    final normalizedAccountId = _requiredId(
      accountId,
      field: 'Account ID',
      maxLength: maxAccountIdLength,
    );
    final normalizedProfileId = _requiredId(
      profileId,
      field: 'Profile ID',
      maxLength: maxProfileIdLength,
    );
    final normalizedMediaId = _requiredId(
      mediaId,
      field: 'Media ID',
      maxLength: maxMediaIdLength,
    );

    for (final review in database.reviewsById.values) {
      if (review.accountId == normalizedAccountId &&
          review.profileId == normalizedProfileId &&
          review.mediaId == normalizedMediaId) {
        return review;
      }
    }

    return null;
  }

  /// Deletes the current profile's review for one media item.
  ///
  /// Returns true when a review existed and was removed.
  bool delete({
    required String accountId,
    required String profileId,
    required String mediaId,
  }) {
    final normalizedAccountId = _requiredId(
      accountId,
      field: 'Account ID',
      maxLength: maxAccountIdLength,
    );
    final normalizedProfileId = _requiredId(
      profileId,
      field: 'Profile ID',
      maxLength: maxProfileIdLength,
    );
    final normalizedMediaId = _requiredId(
      mediaId,
      field: 'Media ID',
      maxLength: maxMediaIdLength,
    );

    final id =
        '${normalizedAccountId}_${normalizedProfileId}_$normalizedMediaId';

    return database.reviewsById.remove(id) != null;
  }

  /// Returns the number of reviews for a media item.
  int countForMedia(String mediaId) {
    final normalizedMediaId = _requiredId(
      mediaId,
      field: 'Media ID',
      maxLength: maxMediaIdLength,
    );

    return database.reviewsById.values
        .where((review) => review.mediaId == normalizedMediaId)
        .length;
  }

  bool _isValidScore(double score) {
    return score.isFinite && score >= minScore && score <= maxScore;
  }

  String _requiredId(
    String value, {
    required String field,
    required int maxLength,
  }) {
    final normalized = value.trim();

    if (normalized.isEmpty) {
      throw Exception('$field is required.');
    }

    if (normalized.length > maxLength) {
      throw Exception('$field is too long.');
    }

    if (_containsControlCharacter(normalized)) {
      throw Exception('$field contains invalid characters.');
    }

    return normalized;
  }

  String _boundedRequiredText(
    String value, {
    required String field,
    required int maxLength,
  }) {
    final normalized = value.trim();

    if (normalized.isEmpty) {
      throw Exception('$field is required.');
    }

    if (normalized.length > maxLength) {
      throw Exception('$field is too long.');
    }

    if (_containsNullByte(normalized)) {
      throw Exception('$field contains invalid characters.');
    }

    return normalized;
  }

  String _boundedOptionalText(
    String value, {
    required String field,
    required int maxLength,
  }) {
    final normalized = value.trim();

    if (normalized.length > maxLength) {
      throw Exception('$field is too long.');
    }

    if (_containsNullByte(normalized)) {
      throw Exception('$field contains invalid characters.');
    }

    return normalized;
  }

  bool _containsNullByte(String value) => value.contains('\u0000');

  bool _containsControlCharacter(String value) {
    for (final codeUnit in value.codeUnits) {
      if (codeUnit == 0 ||
          (codeUnit < 32 && codeUnit != 9 && codeUnit != 10 && codeUnit != 13)) {
        return true;
      }
    }
    return false;
  }

  /// Creates a public-facing detached copy so a future mutation of the
  /// database-held review cannot accidentally alter a global response.
  MediaReview _publicReviewCopy(MediaReview review) {
    return MediaReview(
      id: review.id,
      mediaId: review.mediaId,
      accountId: '',
      profileId: '',
      profileName: review.profileName,
      score: review.score,
      label: review.label,
      text: review.text,
      globalUsername: review.globalUsername,
      createdAt: review.createdAt,
    );
  }

  String _defaultLabel(double score) {
    if (score >= 9) return 'Excellent';
    if (score >= 7) return 'Great';
    if (score >= 5) return 'Mediocre';
    if (score >= 3) return 'Weak';
    return 'Terrible';
  }
}