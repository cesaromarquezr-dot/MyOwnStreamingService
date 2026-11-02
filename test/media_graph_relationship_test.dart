import 'package:flutter_test/flutter_test.dart';

import 'package:my_own_streaming_service/app_core.dart';
import 'package:my_own_streaming_service/media_graph_relationship.dart';

void main() {
  group('MediaGraphRelationship', () {
    test('parses provenance fields and normalizes percentage confidence', () {
      final relationship = MediaGraphRelationship.fromJson(
        <String, dynamic>{
          'relationship_id': 'rel-1',
          'from_id': 'work-1',
          'to_id': 'work-2',
          'relationship_type': 'basedOn',
          'provenance_source': 'Catalog provider',
          'source_url': 'https://example.test/source',
          'evidence': 'Both titles adapt the same novel.',
          'confidence': 82,
          'verification_status': 'verified',
          'verified_at': '2026-10-12T00:00:00Z',
        },
      );

      expect(relationship.id, 'rel-1');
      expect(relationship.sourceWorkId, 'work-1');
      expect(relationship.targetWorkId, 'work-2');
      expect(relationship.relationshipType, 'basedOn');
      expect(relationship.provenanceSource, 'Catalog provider');
      expect(relationship.sourceUrl, 'https://example.test/source');
      expect(relationship.reason, 'Both titles adapt the same novel.');
      expect(relationship.confidence, 0.82);
      expect(relationship.verificationStatus, 'verified');
      expect(relationship.verifiedAt, DateTime.utc(2026, 10, 12));
      expect(relationship.isAdaptationRelationship, isTrue);

      final json = relationship.toJson();
      expect(json['confidence'], 0.82);
      expect(json['sourceWorkId'], 'work-1');
      expect(json['targetWorkId'], 'work-2');
    });

    test('does not classify continuity edges as story adaptations', () {
      final relationship = MediaGraphRelationship.fromJson(
        <String, dynamic>{
          'sourceWorkId': 'work-1',
          'targetWorkId': 'work-2',
          'relationshipType': 'sequel',
          'confidence': 120,
        },
      );

      expect(relationship.isAdaptationRelationship, isFalse);
      expect(relationship.confidence, isNull);
      expect(relationship.verificationStatus, 'unverified');
    });

    test('MediaItem persists graph relationships through JSON', () {
      final media = MediaItem.fromJson(<String, dynamic>{
        'id': 'work-1',
        'title': 'A Retelling',
        'type': 'movie',
        'graph_relationships': <Map<String, dynamic>>[
          <String, dynamic>{
            'source_work_id': 'work-1',
            'target_work_id': 'work-2',
            'relationship_type': 'adaptationOf',
            'reason': 'Both titles adapt the same source story.',
            'provenance_source': 'User verified',
            'confidence': 0.9,
            'verification_status': 'verified',
          },
        ],
      });

      expect(media.graphRelationships, hasLength(1));
      expect(media.graphRelationships.single.targetWorkId, 'work-2');
      expect(
        media.toJson()['graphRelationships'],
        isA<List<Map<String, dynamic>>>(),
      );
      expect(
        (media.toJson()['graphRelationships'] as List).single['reason'],
        'Both titles adapt the same source story.',
      );
    });
  });
}
