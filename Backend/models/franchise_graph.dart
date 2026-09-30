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

/// A named branch of story continuity inside a franchise. A franchise may
/// contain several branches, and membership does not merge work identities.
class FranchiseContinuity {
  final String id;
  final String franchiseId;
  final String name;
  final String? description;

  const FranchiseContinuity({
    required this.id,
    required this.franchiseId,
    required this.name,
    this.description,
  });

  bool get isValid => id.trim().isNotEmpty && franchiseId.trim().isNotEmpty && name.trim().isNotEmpty;

  factory FranchiseContinuity.fromJson(Map<String, dynamic> json) => FranchiseContinuity(
        id: (json['id'] ?? '').toString(),
        franchiseId: (json['franchiseId'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        description: json['description']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'franchiseId': franchiseId,
        'name': name,
        'description': description,
      };
}

/// Places a production or film in a continuity branch with independent
/// release and story ordering.
class FranchiseContinuityMember {
  final String continuityId;
  final String mediaId;
  final String role;
  final int? releaseOrder;
  final int? storyOrder;

  const FranchiseContinuityMember({
    required this.continuityId,
    required this.mediaId,
    this.role = 'production',
    this.releaseOrder,
    this.storyOrder,
  });

  bool get isValid => continuityId.trim().isNotEmpty && mediaId.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'continuityId': continuityId,
        'mediaId': mediaId,
        'role': role,
        'releaseOrder': releaseOrder,
        'storyOrder': storyOrder,
      };
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
