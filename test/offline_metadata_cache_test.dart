import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_own_streaming_service/offline_metadata_cache.dart';
import 'package:my_own_streaming_service/privacy_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('offline cache excludes playback urls and pins metadata to profile', () async {
    const profileId = 'profile-a';
    final cache = OfflineMetadataCache(profileId: profileId);
    await cache.save(<Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'movie-a',
        'title': 'Example Movie',
        'type': 'movie',
        'imageUrl': 'https://cdn.example.test/poster.jpg',
        'playbackUrl': 'https://private.example.test/signed.m3u8?token=secret',
        'trailerUrl': 'https://private.example.test/trailer?signature=secret',
        'addedByProfileId': 'another-profile',
        'accessibleProfileIds': <String>['profile-a', 'profile-b'],
      },
    ]);

    final rows = await cache.load();
    expect(rows, hasLength(1));
    expect(rows.single.containsKey('playbackUrl'), isFalse);
    expect(rows.single.containsKey('trailerUrl'), isFalse);
    expect(rows.single.containsKey('addedByProfileId'), isFalse);
    expect(rows.single['accessibleProfileIds'], <String>[profileId]);
    expect(rows.single['imageUrl'], 'https://cdn.example.test/poster.jpg');
  });

  test('disabling offline metadata deletes cached catalog data', () async {
    const profileId = 'profile-b';
    final cache = OfflineMetadataCache(profileId: profileId);
    await cache.save(<Map<String, dynamic>>[
      <String, dynamic>{'id': 'item-b', 'title': 'Private title', 'type': 'movie'},
    ]);
    final privacy = await PrivacyPreferencesStore.load(profileId: profileId);
    privacy.allowOfflineMetadata = false;
    await PrivacyPreferencesStore.save(profileId: profileId, value: privacy);
    expect(await cache.load(), isEmpty);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('mos_offline_metadata_v1_${Uri.encodeComponent(profileId)}'), isNull);
  });

  test('signed or query-string image URLs are not cached', () async {
    final cache = OfflineMetadataCache(profileId: 'profile-c');
    await cache.save(<Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'item-c',
        'title': 'Example',
        'type': 'movie',
        'imageUrl': 'https://cdn.example.test/poster.jpg?token=secret',
      },
    ]);
    final rows = await cache.load();
    expect(rows, hasLength(1));
    expect(rows.single.containsKey('imageUrl'), isFalse);
  });
}
