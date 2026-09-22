// FILE: `Backend/models/review.dart`.
// Purpose: Review domain models used by profile and global media reviews.
//
// A review belongs to both an account and a profile. The profile identity is
// used for account-local/profile-facing views, while globalUsername is used
// when the review is exposed through the global media-review surface.
//
// Review scores are intentionally kept separate from external provider
// ratings and from the user's separate star-rating model.

class MediaReview {
  final String id;
  final String mediaId;

  /// Owning account. This should not normally be exposed in a public review
  /// response.
  final String accountId;

  /// Profile that authored the review.
  final String profileId;

  /// Profile-local display name.
  final String profileName;

  /// Review score. The application may use a 0-5 scale; this model does not
  /// silently convert it to another rating system.
  final double score;

  /// Human-readable score label, for example "Excellent" or "Mixed".
  final String label;

  final String text;

  /// Public/global username associated with the author.
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

  /// Whether the review contains the minimum identity/content required for
  /// persistence.
  bool get isValid =>
      id.trim().isNotEmpty &&
      mediaId.trim().isNotEmpty &&
      accountId.trim().isNotEmpty &&
      profileId.trim().isNotEmpty &&
      profileName.trim().isNotEmpty &&
      text.trim().isNotEmpty &&
      score.isFinite &&
      score >= 0 &&
      score <= 5;

  bool get hasText => text.trim().isNotEmpty;

  bool get hasGlobalUsername => globalUsername.trim().isNotEmpty;

  bool get hasLabel => label.trim().isNotEmpty;

  /// Returns the score normalized to a percentage of the model's 0-5 scale.
  double get normalizedPercent {
    if (!score.isFinite) {
      return 0;
    }

    return (score / 5.0 * 100.0).clamp(0.0, 100.0).toDouble();
  }

  /// Creates a modified copy without changing the original review.
  MediaReview copyWith({
    String? id,
    String? mediaId,
    String? accountId,
    String? profileId,
    String? profileName,
    double? score,
    String? label,
    String? text,
    String? globalUsername,
    DateTime? createdAt,
  }) {
    return MediaReview(
      id: id ?? this.id,
      mediaId: mediaId ?? this.mediaId,
      accountId: accountId ?? this.accountId,
      profileId: profileId ?? this.profileId,
      profileName: profileName ?? this.profileName,
      score: score ?? this.score,
      label: label ?? this.label,
      text: text ?? this.text,
      globalUsername: globalUsername ?? this.globalUsername,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Performs `fromJson` for this feature.
  ///
  /// Both `username` and the more explicit `globalUsername` form are accepted
  /// so older persisted/API representations remain readable.
  factory MediaReview.fromJson(Map<String, dynamic> json) {
    final createdAt = _dateTimeValue(json['createdAt']);

    return MediaReview(
      id: _stringValue(json['id']),
      mediaId: _stringValue(json['mediaId']),
      accountId: _stringValue(json['accountId']),
      profileId: _stringValue(json['profileId']),
      profileName: _stringValue(
        json['profileName'] ?? json['username'],
      ),
      score: _doubleValue(json['score']),
      label: _stringValue(json['label']),
      text: _stringValue(json['text']),
      globalUsername: _stringValue(
        json['globalUsername'] ?? json['username'],
      ),
      createdAt: createdAt,
    );
  }

  /// Serializes the review.
  ///
  /// The existing API contract is preserved:
  /// - `global: false` exposes the profile display name as `username`.
  /// - `global: true` exposes the global username as `username`.
  ///
  /// Internal account/profile identifiers are intentionally omitted from this
  /// public review representation.
  Map<String, dynamic> toJson({bool global = false}) => {
        'id': id,
        'mediaId': mediaId,
        'score': score,
        'label': label,
        'text': text,
        'username': global ? globalUsername : profileName,
        'createdAt': createdAt.toIso8601String(),
      };

  /// Internal/persistence representation containing author identifiers.
  ///
  /// This should only be used by trusted backend storage paths, not directly
  /// as a public API response.
  Map<String, dynamic> toStorageJson() => {
        'id': id,
        'mediaId': mediaId,
        'accountId': accountId,
        'profileId': profileId,
        'profileName': profileName,
        'score': score,
        'label': label,
        'text': text,
        'globalUsername': globalUsername,
        'createdAt': createdAt.toIso8601String(),
      };

  @override
  String toString() {
    return 'MediaReview('
        'id: $id, '
        'mediaId: $mediaId, '
        'accountId: $accountId, '
        'profileId: $profileId, '
        'profileName: $profileName, '
        'score: $score, '
        'label: $label, '
        'text: $text, '
        'globalUsername: $globalUsername, '
        'createdAt: $createdAt'
        ')';
  }
}

String _stringValue(
  dynamic value, {
  String fallback = '',
}) {
  if (value == null) {
    return fallback;
  }

  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

double _doubleValue(
  dynamic value, {
  double fallback = 0,
}) {
  if (value is num) {
    return value.toDouble();
  }

  if (value is String) {
    return double.tryParse(value.trim()) ?? fallback;
  }

  return fallback;
}

DateTime? _dateTimeValue(dynamic value) {
  if (value is DateTime) {
    return value;
  }

  if (value is String) {
    return DateTime.tryParse(value);
  }

  return null;
}