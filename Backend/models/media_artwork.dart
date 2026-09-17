// FILE: `Backend/models/media_artwork.dart`.
// Purpose: Tracks artwork discovered from discs/files or supplied by users.

class MediaArtwork {
  final String id;
  final String? mediaId;
  final String sourceType;
  final String? sourcePath;
  final String? url;
  final String artworkType;
  final String? title;
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

  Map<String, dynamic> toJson() => {
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
