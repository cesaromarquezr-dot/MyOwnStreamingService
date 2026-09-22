// FILE: `Backend/models/media_artwork.dart`.
// Purpose: Tracks artwork discovered from discs/files or supplied by users.
// This file is part of the documented Flutter/home-server architecture.
//
// Artwork is kept separate from the media record so artwork can retain
// provenance and can be replaced, supplemented, or made profile-eligible
// without modifying the underlying media identity.

class MediaArtwork {
  final String id;
  final String? mediaId;

  /// Where the artwork originated.
  ///
  /// Examples include:
  /// - arm
  /// - disc
  /// - file
  /// - metadata_provider
  /// - user
  /// - generated
  final String sourceType;

  /// Local filesystem path when artwork was discovered or stored locally.
  final String? sourcePath;

  /// Remote artwork URL when supplied by a metadata provider or user.
  final String? url;

  /// Artwork role/type.
  ///
  /// The value remains a string so new artwork types can be introduced
  /// without breaking older persisted records.
  final String artworkType;

  /// Optional human-readable artwork title or description.
  final String? title;

  /// Whether this artwork may be selected for profile-specific presentation.
  final bool profileEligible;

  final DateTime createdAt;

  const MediaArtwork({
    required this.id,
    this.mediaId,
    required this.sourceType,
    this.sourcePath,
    this.url,
    required this.artworkType,
    this.title,
    this.profileEligible = false,
    required this.createdAt,
  });

  /// Whether this artwork has a usable local source.
  bool get hasSourcePath {
    return sourcePath != null &&
        sourcePath!.trim().isNotEmpty;
  }

  /// Whether this artwork has a usable remote URL.
  bool get hasUrl {
    return url != null &&
        url!.trim().isNotEmpty;
  }

  /// Whether at least one artwork source is available.
  bool get hasSource => hasSourcePath || hasUrl;

  /// Creates a copy while preserving immutable artwork identity.
  MediaArtwork copyWith({
    String? id,
    String? mediaId,
    String? sourceType,
    String? sourcePath,
    String? url,
    String? artworkType,
    String? title,
    bool? profileEligible,
    DateTime? createdAt,
  }) {
    return MediaArtwork(
      id: id ?? this.id,
      mediaId: mediaId ?? this.mediaId,
      sourceType: sourceType ?? this.sourceType,
      sourcePath: sourcePath ?? this.sourcePath,
      url: url ?? this.url,
      artworkType: artworkType ?? this.artworkType,
      title: title ?? this.title,
      profileEligible:
          profileEligible ?? this.profileEligible,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'mediaId': mediaId,
      'sourceType': sourceType,
      'sourcePath': sourcePath,
      'url': url,
      'artworkType': artworkType,
      'title': title,
      'profileEligible': profileEligible,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory MediaArtwork.fromJson(
    Map<String, dynamic> json,
  ) {
    return MediaArtwork(
      id: json['id']?.toString() ?? '',
      mediaId: _nullableString(json['mediaId']),
      sourceType:
          json['sourceType']?.toString() ?? 'unknown',
      sourcePath:
          _nullableString(json['sourcePath']),
      url:
          _nullableString(json['url']),
      artworkType:
          json['artworkType']?.toString() ?? 'unknown',
      title:
          _nullableString(json['title']),
      profileEligible:
          json['profileEligible'] as bool? ?? false,
      createdAt:
          _parseDateTime(json['createdAt']),
    );
  }

  @override
  String toString() {
    return 'MediaArtwork('
        'id: $id, '
        'mediaId: $mediaId, '
        'sourceType: $sourceType, '
        'artworkType: $artworkType, '
        'profileEligible: $profileEligible'
        ')';
  }

  static String? _nullableString(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    final String valueString =
        value.toString().trim();

    return valueString.isEmpty
        ? null
        : valueString;
  }

  static DateTime _parseDateTime(
    dynamic value,
  ) {
    if (value is DateTime) {
      return value;
    }

    final String? valueString =
        _nullableString(value);

    if (valueString != null) {
      final DateTime? parsed =
          DateTime.tryParse(valueString);

      if (parsed != null) {
        return parsed;
      }
    }

    // Older/imported records without a valid timestamp
    // remain readable rather than failing deserialization.
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}