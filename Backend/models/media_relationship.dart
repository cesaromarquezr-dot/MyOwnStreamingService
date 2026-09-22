// FILE: `Backend/models/media_relationship.dart`.
// Purpose: Describes edges in the global media knowledge graph.
//
// Relationships are intentionally type- and source-extensible. The model
// does not hard-code a finite relationship vocabulary because the global
// catalog may add relationship types over time.
//
// Examples of relationship types include:
//   - alternateEdition
//   - partOfCollection
//   - sequelTo
//   - prequelTo
//   - spinOffOf
//   - adaptationOf
//   - soundtrackFor
//   - contains
//   - performedBy
//   - recordingOf
//
// The persistence layer is responsible for enforcing identity and
// deduplication rules. Confidence describes the strength of the relationship
// evidence; it does not make two media records the same entity.

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

  /// Whether this relationship contains the minimum identifiers required
  /// for persistence.
  bool get isValid =>
      id.trim().isNotEmpty &&
      fromId.trim().isNotEmpty &&
      relationshipType.trim().isNotEmpty &&
      toId.trim().isNotEmpty;

  /// A relationship cannot meaningfully point from an entity to itself.
  bool get isSelfRelationship => fromId.trim() == toId.trim();

  /// Returns a normalized confidence value suitable for display or
  /// persistence. The original value is never mutated.
  double get normalizedConfidence {
    if (confidence.isNaN) {
      return 0.0;
    }

    if (confidence.isInfinite) {
      return confidence.isNegative ? 0.0 : 1.0;
    }

    return confidence.clamp(0.0, 1.0).toDouble();
  }

  /// Creates a modified copy without changing the original relationship.
  MediaRelationship copyWith({
    String? id,
    String? fromId,
    String? relationshipType,
    String? toId,
    double? confidence,
    String? source,
    Map<String, dynamic>? metadata,
  }) {
    return MediaRelationship(
      id: id ?? this.id,
      fromId: fromId ?? this.fromId,
      relationshipType: relationshipType ?? this.relationshipType,
      toId: toId ?? this.toId,
      confidence: confidence ?? this.confidence,
      source: source ?? this.source,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Builds a relationship from persisted catalog data.
  ///
  /// Invalid/missing required string fields are represented as empty strings
  /// rather than causing a JSON parsing crash. Callers that require strict
  /// validation should check [isValid].
  factory MediaRelationship.fromJson(Map<String, dynamic> json) {
    return MediaRelationship(
      id: _stringValue(json['id']),
      fromId: _stringValue(json['fromId']),
      relationshipType: _stringValue(json['relationshipType']),
      toId: _stringValue(json['toId']),
      confidence: _doubleValue(json['confidence'], fallback: 1.0),
      source: _stringValue(
        json['source'],
        fallback: 'catalog',
      ),
      metadata: _mapValue(json['metadata']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fromId': fromId,
        'relationshipType': relationshipType,
        'toId': toId,
        'confidence': confidence,
        'source': source,
        'metadata': metadata,
      };

  @override
  String toString() {
    return 'MediaRelationship('
        'id: $id, '
        'fromId: $fromId, '
        'relationshipType: $relationshipType, '
        'toId: $toId, '
        'confidence: $confidence, '
        'source: $source'
        ')';
  }

  static String _stringValue(
    Object? value, {
    String fallback = '',
  }) {
    if (value == null) {
      return fallback;
    }

    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static double _doubleValue(
    Object? value, {
    double fallback = 1.0,
  }) {
    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value.trim()) ?? fallback;
    }

    return fallback;
  }

  static Map<String, dynamic> _mapValue(Object? value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }

    if (value is Map) {
      return value.map(
        (key, value) => MapEntry(
          key.toString(),
          value,
        ),
      );
    }

    return const {};
  }
}