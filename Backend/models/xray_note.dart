/// A private annotation anchored to an exact media version and playback offset.
///
/// Notes are profile data and must never be included in shared X-Ray metadata.
class XRayNote {
  final String id;
  final String profileId;
  final String mediaId;
  final String mediaVersionId;
  final int positionMilliseconds;
  final String text;
  final DateTime createdAt;

  const XRayNote({
    required this.id,
    required this.profileId,
    required this.mediaId,
    required this.mediaVersionId,
    required this.positionMilliseconds,
    required this.text,
    required this.createdAt,
  });

  bool get isValid =>
      id.trim().isNotEmpty &&
      profileId.trim().isNotEmpty &&
      mediaId.trim().isNotEmpty &&
      mediaVersionId.trim().isNotEmpty &&
      positionMilliseconds >= 0 &&
      text.trim().isNotEmpty &&
      text.length <= 1000;

  factory XRayNote.fromJson(Map<String, dynamic> json) {
    final note = XRayNote(
      id: '${json['id'] ?? ''}',
      profileId: '${json['profileId'] ?? ''}',
      mediaId: '${json['mediaId'] ?? ''}',
      mediaVersionId: '${json['mediaVersionId'] ?? ''}',
      positionMilliseconds: json['positionMilliseconds'] is num
          ? (json['positionMilliseconds'] as num).toInt()
          : int.tryParse('${json['positionMilliseconds']}') ?? -1,
      text: '${json['text'] ?? ''}',
      createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
    if (!note.isValid) throw const FormatException('Invalid X-Ray note.');
    return note;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'profileId': profileId,
        'mediaId': mediaId,
        'mediaVersionId': mediaVersionId,
        'positionMilliseconds': positionMilliseconds,
        'text': text,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };
}
