import 'package:flutter_test/flutter_test.dart';
import 'package:my_own_streaming_service/expanded_platform.dart';

void main() {
  group('Expanded platform catalog', () {
    test('has stable unique capability identifiers', () {
      final ids = ExpandedPlatformCatalog.capabilities.map((item) => item.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(ids, isNotEmpty);
    });

    test('every capability has a description and category', () {
      for (final capability in ExpandedPlatformCatalog.capabilities) {
        expect(capability.title.trim(), isNotEmpty);
        expect(capability.description.trim(), isNotEmpty);
        expect(capability.category.trim(), isNotEmpty);
      }
    });

    test('includes the phase two capability foundations', () {
      final ids = ExpandedPlatformCatalog.capabilities.map((item) => item.id).toSet();
      expect(ids, containsAll([
        'proactive_assistant', 'interactive_entertainment', 'franchise_timeline',
        'custom_media_spaces', 'nas_storage_intelligence', 'accessibility_companion',
        'group_decisions', 'media_provenance', 'marketplace_trust',
        'premieres_live_events', 'developer_integration_hub', 'self_service_recovery',
      ]));
    });

    test('supports category filtering', () {
      final media = ExpandedPlatformCatalog.inCategory('Media');
      expect(media, isNotEmpty);
      expect(media.every((item) => item.category == 'Media'), isTrue);
    });

    test('does not include excluded content formats', () {
      final searchable = ExpandedPlatformCatalog.capabilities
          .map((item) => '${item.id} ${item.title} ${item.description}'.toLowerCase())
          .join(' ');
      expect(searchable, isNot(contains('podcast')));
      expect(searchable, isNot(contains('audiobook')));
    });
  });

  group('MediaSceneBookmark', () {
    test('serializes optional fields only when supplied', () {
      const bookmark = MediaSceneBookmark(
        id: '', mediaKey: 'movie:abc', positionMs: 1200,
      );
      expect(bookmark.toInsertJson(), {
        'media_key': 'movie:abc',
        'position_ms': 1200,
      });
    });

    test('parses a bookmark row', () {
      final bookmark = MediaSceneBookmark.fromJson({
        'id': 'bookmark-1',
        'media_key': 'movie:abc',
        'position_ms': 9000,
        'label': 'Opening scene',
        'note': null,
        'created_at': '2026-10-15T12:00:00Z',
      });
      expect(bookmark.id, 'bookmark-1');
      expect(bookmark.positionMs, 9000);
      expect(bookmark.label, 'Opening scene');
    });
  });


  group('Phase two models', () {
    test('parses a proactive suggestion', () {
      final item = HeyMediaSuggestion.fromJson({
        'id': 'suggestion-1',
        'suggestion_type': 'library_fix',
        'title': 'Review a possible duplicate',
        'body': 'Two files may represent the same edition.',
        'status': 'pending',
        'expires_at': null,
      });
      expect(item.id, 'suggestion-1');
      expect(item.status, 'pending');
    });

    test('trims media space insert fields', () {
      const space = UserMediaSpace(
        id: '', title: '  Horror Night  ', description: '  Friday picks  ',
      );
      expect(space.toInsertJson(), {
        'title': 'Horror Night',
        'description': 'Friday picks',
        'visibility': 'private',
      });
    });

    test('parses metadata provenance confidence', () {
      final item = MediaMetadataProvenance.fromJson({
        'media_key': 'movie:abc',
        'field_name': 'original_title',
        'source_type': 'disc_scan',
        'source_reference': 'import-123',
        'confidence': 0.92,
        'observed_value': {'title': 'Example'},
      });
      expect(item.confidence, 0.92);
      expect(item.observedValue?['title'], 'Example');
    });
  });
}
