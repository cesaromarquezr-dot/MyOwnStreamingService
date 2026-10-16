import 'package:flutter_test/flutter_test.dart';
import 'package:my_own_streaming_service/entertainment_studio.dart';
import 'package:my_own_streaming_service/app_core.dart';

void main() {
  group('StudioSceneTimestamp', () {
    test('parses a valid timestamp to milliseconds', () {
      expect(StudioSceneTimestamp.parse('00:01:05 a favorite moment'), 65000);
      expect(StudioSceneTimestamp.parse('1:02:03'), 3723000);
    });

    test('rejects invalid timestamp components', () {
      expect(StudioSceneTimestamp.parse('00:61:00'), isNull);
      expect(StudioSceneTimestamp.parse('not a timestamp'), isNull);
    });
  });

  group('StudioLibraryAudit', () {
    test('flags missing metadata and possible duplicates without mutating media', () {
      final library = <MediaItem>[
        MediaItem(id: 'm1', title: 'Example Film', type: 'movie'),
        MediaItem(id: 'm2', title: 'Example   Film', type: 'movie', imageUrl: 'https://example.invalid/poster.jpg', description: 'Known description', releaseYear: 2000),
      ];
      final findings = StudioLibraryAudit.findings(library);
      expect(findings.any((f) => f.kind == 'missing artwork'), isTrue);
      expect(findings.any((f) => f.kind == 'missing description'), isTrue);
      expect(findings.any((f) => f.kind == 'missing year'), isTrue);
      expect(findings.any((f) => f.kind == 'possible duplicate'), isTrue);
      expect(library.length, 2);
    });
  });
}
