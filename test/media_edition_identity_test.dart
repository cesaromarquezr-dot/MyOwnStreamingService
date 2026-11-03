import 'package:flutter_test/flutter_test.dart';

import 'package:my_own_streaming_service/app_core.dart';
import 'package:my_own_streaming_service/media_edition_identity.dart';

void main() {
  group('media edition identity', () {
    test('disc cuts with the same title and year share a work ID', () {
      expect(
        discImportCanonicalWorkId(title: 'Example Movie', releaseYear: 2020),
        discImportCanonicalWorkId(
            title: ' example   movie ', releaseYear: 2020),
      );
      expect(
        discImportCanonicalWorkId(title: 'Example Movie', releaseYear: 2020),
        isNot(discImportCanonicalWorkId(
          title: 'Example Movie',
          releaseYear: 2021,
        )),
      );
    });

    test('legacy disc movie imports use title and year as their group ID', () {
      final olderImport = MediaItem(
        id: 'legacy-cut-a',
        title: 'Example Movie',
        type: 'movie',
        releaseYear: 2020,
        addedSource: 'disc_ingestion_center',
      );
      final newerImport = MediaItem(
        id: 'legacy-cut-b',
        title: ' example movie ',
        type: 'movie',
        releaseYear: 2020,
        addedSource: 'disc_ingestion_center',
      );
      final unrelatedCatalogItem = MediaItem(
        id: 'catalog-item',
        title: 'Example Movie',
        type: 'movie',
        releaseYear: 2020,
      );

      expect(
          mediaEditionGroupId(olderImport), mediaEditionGroupId(newerImport));
      expect(mediaEditionGroupId(unrelatedCatalogItem), isNull);
    });
  });
}
