// FILE: Backend/models/franchise_graph.dart
// Purpose: Universal franchise/saga/multiverse graph primitives.
//
// A franchise is an organizational identity. A relationship is an explicit
// edge between catalog entities. Continuity is only one kind of relationship;
// references, cameos, influences, adaptations, and multiverse appearances
// remain relevant without implying shared continuity.

enum FranchiseRelationshipKind {
  sameContinuity,
  sequel,
  prequel,
  spinOff,
  crossover,
  cameo,
  alternateUniverse,
  variant,
  reference,
  metaReference,
  adaptation,
  remake,
  reboot,
  visualInfluence,
  characterConnection,
  creatorConnection,
  sharedActor,
  sharedLocation,
  soundtrackConnection,
  leadsInto,
  related,
}

class FranchiseNode {
  final String id;
  final String title;
  final String nodeType;
  final String? franchiseId;
  final int? releaseYear;
  final int? storyYear;
  final int? order;

  const FranchiseNode({
    required this.id,
    required this.title,
    required this.nodeType,
    this.franchiseId,
    this.releaseYear,
    this.storyYear,
    this.order,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'nodeType': nodeType,
        'franchiseId': franchiseId,
        'releaseYear': releaseYear,
        'storyYear': storyYear,
        'order': order,
      };
}

class FranchiseRelationship {
  final String id;
  final String fromId;
  final String toId;
  final FranchiseRelationshipKind kind;
  final double confidence;
  final String source;
  final bool affectsContinuity;
  final Map<String, dynamic> metadata;

  const FranchiseRelationship({
    required this.id,
    required this.fromId,
    required this.toId,
    required this.kind,
    this.confidence = 1.0,
    this.source = 'catalog',
    this.affectsContinuity = false,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'fromId': fromId,
        'toId': toId,
        'kind': kind.name,
        'confidence': confidence.clamp(0.0, 1.0),
        'source': source,
        'affectsContinuity': affectsContinuity,
        'metadata': metadata,
      };
}
