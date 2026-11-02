/// A directed, provenance-aware edge between two media works.
class MediaGraphRelationship {
  const MediaGraphRelationship({
    this.id,
    required this.sourceWorkId,
    required this.targetWorkId,
    required this.relationshipType,
    this.provenanceSource,
    this.sourceUrl,
    this.reason,
    this.confidence,
    this.verificationStatus = 'unverified',
    this.verifiedAt,
  }) : assert(confidence == null || (confidence >= 0 && confidence <= 1));

  final String? id;
  final String sourceWorkId;
  final String targetWorkId;
  final String relationshipType;
  final String? provenanceSource;
  final String? sourceUrl;
  final String? reason;
  final double? confidence;
  final String verificationStatus;
  final DateTime? verifiedAt;

  bool get isAdaptationRelationship {
    final type = relationshipType.toLowerCase().replaceAll(
          RegExp(r'[^a-z0-9]'),
          '',
        );
    return type.contains('adapt') ||
        type.contains('basedon') ||
        type.contains('retelling') ||
        type.contains('samestory') ||
        type.contains('remakeof');
  }

  factory MediaGraphRelationship.fromJson(Map<String, dynamic> json) {
    final rawConfidence = json['confidence'];
    final parsedConfidence = rawConfidence is num
        ? rawConfidence.toDouble()
        : double.tryParse(rawConfidence?.toString() ?? '');
    final confidence = parsedConfidence == null
        ? null
        : parsedConfidence > 1 && parsedConfidence <= 100
            ? parsedConfidence / 100
            : parsedConfidence >= 0 && parsedConfidence <= 1
                ? parsedConfidence
                : null;
    final verificationStatus =
        (json['verificationStatus'] ?? json['verification_status'])
                ?.toString()
                .trim() ??
            '';

    return MediaGraphRelationship(
      id: (json['id'] ?? json['relationshipId'] ?? json['relationship_id'])
          ?.toString(),
      sourceWorkId: (json['sourceWorkId'] ??
                  json['source_work_id'] ??
                  json['fromId'] ??
                  json['from_id'])
              ?.toString() ??
          '',
      targetWorkId: (json['targetWorkId'] ??
                  json['target_work_id'] ??
                  json['toId'] ??
                  json['to_id'])
              ?.toString() ??
          '',
      relationshipType: (json['relationshipType'] ??
                  json['relationship_type'] ??
                  json['type'])
              ?.toString() ??
          '',
      provenanceSource: (json['provenanceSource'] ??
              json['provenance_source'] ??
              json['source'])
          ?.toString(),
      sourceUrl: (json['sourceUrl'] ?? json['source_url'])?.toString(),
      reason: (json['reason'] ?? json['evidence'])?.toString(),
      confidence: confidence,
      verificationStatus:
          verificationStatus.isEmpty ? 'unverified' : verificationStatus,
      verifiedAt: DateTime.tryParse(
        (json['verifiedAt'] ?? json['verified_at'])?.toString() ?? '',
      ),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'sourceWorkId': sourceWorkId,
        'targetWorkId': targetWorkId,
        'relationshipType': relationshipType,
        'provenanceSource': provenanceSource,
        'sourceUrl': sourceUrl,
        'reason': reason,
        'confidence': confidence,
        'verificationStatus': verificationStatus,
        'verifiedAt': verifiedAt?.toIso8601String(),
      };
}
