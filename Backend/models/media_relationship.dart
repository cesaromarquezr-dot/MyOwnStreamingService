// FILE: `Backend/models/media_relationship.dart`.
// Purpose: Describes edges in the global media knowledge graph.

class MediaRelationship {
  final String id;
  final String fromId;
  final String relationshipType;
  final String toId;
  final double confidence;
  final String source;
  final Map<String, dynamic> metadata;

  const MediaRelationship({
    required this.id,
    required this.fromId,
    required this.relationshipType,
    required this.toId,
    this.confidence = 1.0,
    this.source = 'catalog',
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'fromId': fromId,
        'relationshipType': relationshipType,
        'toId': toId,
        'confidence': confidence,
        'source': source,
        'metadata': metadata,
      };
}
