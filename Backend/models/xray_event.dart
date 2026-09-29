/// A curated X-Ray event positioned on one specific playable media version.
///
/// Offsets are relative to that version's playback timeline. [metadata] holds
/// extensible graph references and scene context while the core interval and
/// spoiler fields remain validated and queryable.
class XRayEvent {
  final String id;
  final String mediaVersionId;
  final double startSeconds;
  final double? endSeconds;
  final String eventType;
  final String title;
  final String? description;
  final String spoilerScope;
  final String source;
  final Map<String, dynamic> metadata;

  const XRayEvent({
    required this.id,
    required this.mediaVersionId,
    required this.startSeconds,
    this.endSeconds,
    required this.eventType,
    required this.title,
    this.description,
    this.spoilerScope = 'current_scene',
    this.source = 'curated',
    this.metadata = const {},
  });

  bool get isValid =>
      id.trim().isNotEmpty &&
      mediaVersionId.trim().isNotEmpty &&
      startSeconds >= 0 &&
      (endSeconds == null || endSeconds! > startSeconds) &&
      eventType.trim().isNotEmpty &&
      title.trim().isNotEmpty &&
      const {'none', 'current_scene', 'current_movie', 'franchise', 'everything'}
          .contains(spoilerScope);

  factory XRayEvent.fromJson(Map<String, dynamic> json) {
    double? number(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value');
    final start = number(json['startSeconds'] ?? json['start']);
    if (start == null) {
      throw const FormatException('X-Ray event requires a numeric startSeconds.');
    }
    final rawMetadata = json['metadata'];
    final metadata = rawMetadata is Map
        ? Map<String, dynamic>.from(rawMetadata)
        : Map<String, dynamic>.from(json);
    if (rawMetadata is! Map) {
      metadata.removeWhere((key, _) => const {
            'id',
            'mediaVersionId',
            'startSeconds',
            'start',
            'endSeconds',
            'end',
            'eventType',
            'title',
            'description',
            'spoilerScope',
            'source',
          }.contains(key));
    }
    final event = XRayEvent(
      id: '${json['id'] ?? ''}',
      mediaVersionId: '${json['mediaVersionId'] ?? ''}',
      startSeconds: start,
      endSeconds: number(json['endSeconds'] ?? json['end']),
      eventType: '${json['eventType'] ?? 'scene'}',
      title: '${json['title'] ?? ''}',
      description: json['description']?.toString(),
      spoilerScope: '${json['spoilerScope'] ?? 'current_scene'}',
      source: '${json['source'] ?? 'curated'}',
      metadata: metadata,
    );
    if (!event.isValid) throw const FormatException('Invalid X-Ray event.');
    return event;
  }

  Map<String, dynamic> toJson() => {
        ...metadata,
        'id': id,
        'mediaVersionId': mediaVersionId,
        'startSeconds': startSeconds,
        'endSeconds': endSeconds,
        'eventType': eventType,
        'title': title,
        'description': description,
        'spoilerScope': spoilerScope,
        'source': source,
        'metadata': metadata,
      };
}
