/// A sourced knowledge claim attached to a canonical work or exact version.
///
/// Facts are editorial knowledge records, not user reviews or graph edges.
/// Every published fact must include at least one source. Uncertain claims
/// carry an explicit claim status instead of being presented as verified.
class KnowledgeFact {
  final String id;
  final String mediaWorkId;
  final String? mediaVersionId;
  final String category;
  final String title;
  final String body;
  final String claimStatus;
  final String spoilerScope;
  final String difficulty;
  final List<KnowledgeFactSource> sources;
  final List<KnowledgeFactEntityRef> relatedEntities;
  final DateTime? reviewedAt;

  const KnowledgeFact({
    required this.id,
    required this.mediaWorkId,
    this.mediaVersionId,
    required this.category,
    required this.title,
    required this.body,
    this.claimStatus = 'established',
    this.spoilerScope = 'none',
    this.difficulty = 'casual',
    this.sources = const [],
    this.relatedEntities = const [],
    this.reviewedAt,
  });

  bool get isValid =>
      id.trim().isNotEmpty &&
      mediaWorkId.trim().isNotEmpty &&
      category.trim().isNotEmpty &&
      title.trim().isNotEmpty &&
      body.trim().isNotEmpty &&
      sources.isNotEmpty &&
      sources.every((source) => source.isValid) &&
      relatedEntities.every((entity) => entity.isValid) &&
      const {'established', 'reported', 'disputed', 'interpretation'}
          .contains(claimStatus) &&
      const {'none', 'current_scene', 'current_work', 'franchise', 'everything'}
          .contains(spoilerScope) &&
      const {'casual', 'fan', 'superfan', 'collector', 'deep_cut'}
          .contains(difficulty);

  factory KnowledgeFact.fromJson(Map<String, dynamic> json) {
    final sourceList = json['sources'];
    final relatedList = json['relatedEntities'];
    final fact = KnowledgeFact(
      id: '${json['id'] ?? ''}',
      mediaWorkId: '${json['mediaWorkId'] ?? ''}',
      mediaVersionId: _optionalString(json['mediaVersionId']),
      category: '${json['category'] ?? ''}',
      title: '${json['title'] ?? ''}',
      body: '${json['body'] ?? ''}',
      claimStatus: '${json['claimStatus'] ?? 'established'}',
      spoilerScope: '${json['spoilerScope'] ?? 'none'}',
      difficulty: '${json['difficulty'] ?? 'casual'}',
      sources: sourceList is List
          ? sourceList
              .whereType<Map>()
              .map((value) => KnowledgeFactSource.fromJson(
                    Map<String, dynamic>.from(value),
                  ))
              .toList(growable: false)
          : const [],
      relatedEntities: relatedList is List
          ? relatedList
              .whereType<Map>()
              .map((value) => KnowledgeFactEntityRef.fromJson(
                    Map<String, dynamic>.from(value),
                  ))
              .toList(growable: false)
          : const [],
      reviewedAt: DateTime.tryParse('${json['reviewedAt'] ?? ''}'),
    );
    if (!fact.isValid) throw const FormatException('Invalid knowledge fact.');
    return fact;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'mediaWorkId': mediaWorkId,
        'mediaVersionId': mediaVersionId,
        'category': category,
        'title': title,
        'body': body,
        'claimStatus': claimStatus,
        'spoilerScope': spoilerScope,
        'difficulty': difficulty,
        'sources': sources.map((source) => source.toJson()).toList(),
        'relatedEntities':
            relatedEntities.map((entity) => entity.toJson()).toList(),
        'reviewedAt': reviewedAt?.toUtc().toIso8601String(),
      };
}

class KnowledgeFactSource {
  final String id;
  final String title;
  final String url;
  final String sourceType;
  final String? publisher;
  final String? publishedAt;
  final String? accessedAt;
  final String evidenceRelation;
  final String? locator;
  final String? supportingNote;

  const KnowledgeFactSource({
    required this.id,
    required this.title,
    required this.url,
    required this.sourceType,
    this.publisher,
    this.publishedAt,
    this.accessedAt,
    this.evidenceRelation = 'direct_support',
    this.locator,
    this.supportingNote,
  });

  bool get isValid =>
      id.trim().isNotEmpty &&
      title.trim().isNotEmpty &&
      const {'http', 'https'}.contains(Uri.tryParse(url)?.scheme) &&
      sourceType.trim().isNotEmpty &&
      const {'direct_support', 'corroboration', 'context', 'contradiction'}
          .contains(evidenceRelation);

  factory KnowledgeFactSource.fromJson(Map<String, dynamic> json) =>
      KnowledgeFactSource(
        id: '${json['id'] ?? ''}',
        title: '${json['title'] ?? ''}',
        url: '${json['url'] ?? ''}',
        sourceType: '${json['sourceType'] ?? ''}',
        publisher: _optionalString(json['publisher']),
        publishedAt: _optionalString(json['publishedAt']),
        accessedAt: _optionalString(json['accessedAt']),
        evidenceRelation: '${json['evidenceRelation'] ?? 'direct_support'}',
        locator: _optionalString(json['locator']),
        supportingNote: _optionalString(json['supportingNote']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'url': url,
        'sourceType': sourceType,
        'publisher': publisher,
        'publishedAt': publishedAt,
        'accessedAt': accessedAt,
        'evidenceRelation': evidenceRelation,
        'locator': locator,
        'supportingNote': supportingNote,
      };
}

/// Typed link into the shared media graph; this does not duplicate an entity.
class KnowledgeFactEntityRef {
  final String entityKind;
  final String entityId;
  final String relationship;

  const KnowledgeFactEntityRef({
    required this.entityKind,
    required this.entityId,
    required this.relationship,
  });

  bool get isValid =>
      entityKind.trim().isNotEmpty &&
      entityId.trim().isNotEmpty &&
      relationship.trim().isNotEmpty;

  factory KnowledgeFactEntityRef.fromJson(Map<String, dynamic> json) =>
      KnowledgeFactEntityRef(
        entityKind: '${json['entityKind'] ?? ''}',
        entityId: '${json['entityId'] ?? ''}',
        relationship: '${json['relationship'] ?? ''}',
      );

  Map<String, dynamic> toJson() => {
        'entityKind': entityKind,
        'entityId': entityId,
        'relationship': relationship,
      };
}

/// An ordered, sourced path through connected facts, anchored at one work.
/// Each step points to an independently addressable [KnowledgeFact].
class KnowledgeStory {
  final String id;
  final String anchorMediaWorkId;
  final String title;
  final String? summary;
  final String spoilerScope;
  final List<KnowledgeStoryStep> steps;

  const KnowledgeStory({
    required this.id,
    required this.anchorMediaWorkId,
    required this.title,
    this.summary,
    this.spoilerScope = 'none',
    this.steps = const [],
  });

  bool get isValid =>
      id.trim().isNotEmpty &&
      anchorMediaWorkId.trim().isNotEmpty &&
      title.trim().isNotEmpty &&
      const {'none', 'current_scene', 'current_work', 'franchise', 'everything'}
          .contains(spoilerScope) &&
      steps.isNotEmpty &&
      steps.every((step) => step.isValid) &&
      steps.map((step) => step.stepNumber).toSet().length == steps.length;

  factory KnowledgeStory.fromJson(Map<String, dynamic> json) {
    final rawSteps = json['steps'];
    final story = KnowledgeStory(
      id: '${json['id'] ?? ''}',
      anchorMediaWorkId: '${json['anchorMediaWorkId'] ?? ''}',
      title: '${json['title'] ?? ''}',
      summary: _optionalString(json['summary']),
      spoilerScope: '${json['spoilerScope'] ?? 'none'}',
      steps: rawSteps is List
          ? rawSteps
              .whereType<Map>()
              .map((value) => KnowledgeStoryStep.fromJson(
                    Map<String, dynamic>.from(value),
                  ))
              .toList()
          : const [],
    );
    if (!story.isValid) throw const FormatException('Invalid knowledge story.');
    story.steps.sort((a, b) => a.stepNumber.compareTo(b.stepNumber));
    return story;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'anchorMediaWorkId': anchorMediaWorkId,
        'title': title,
        'summary': summary,
        'spoilerScope': spoilerScope,
        'steps': steps.map((step) => step.toJson()).toList(),
      };
}

class KnowledgeStoryStep {
  final int stepNumber;
  final String factId;
  final String? transitionNote;

  const KnowledgeStoryStep({
    required this.stepNumber,
    required this.factId,
    this.transitionNote,
  });

  bool get isValid => stepNumber > 0 && factId.trim().isNotEmpty;

  factory KnowledgeStoryStep.fromJson(Map<String, dynamic> json) =>
      KnowledgeStoryStep(
        stepNumber: json['stepNumber'] is num
            ? (json['stepNumber'] as num).toInt()
            : int.tryParse('${json['stepNumber']}') ?? 0,
        factId: '${json['factId'] ?? ''}',
        transitionNote: _optionalString(json['transitionNote']),
      );

  Map<String, dynamic> toJson() => {
        'stepNumber': stepNumber,
        'factId': factId,
        'transitionNote': transitionNote,
      };
}

String? _optionalString(Object? value) {
  final result = value?.toString().trim();
  return result == null || result.isEmpty ? null : result;
}
