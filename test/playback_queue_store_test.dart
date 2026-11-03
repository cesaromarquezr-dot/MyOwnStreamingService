import 'package:flutter_test/flutter_test.dart';
import 'package:my_own_streaming_service/app_core.dart';
import 'package:my_own_streaming_service/playback_queue_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('keeps media and music IDs distinct and preserves queue order',
      () async {
    const store = PlaybackQueueStore();
    const movie = PlaybackQueueEntry(
      kind: PlaybackQueueKind.media,
      id: 'same-id',
    );
    const song = PlaybackQueueEntry(
      kind: PlaybackQueueKind.music,
      id: 'same-id',
    );

    await store.add(profileId: 'profile/one', entry: movie);
    await store.add(profileId: 'profile/one', entry: song);
    await store.add(profileId: 'profile/one', entry: movie);

    expect(await store.load(profileId: 'profile/one'), <PlaybackQueueEntry>[
      movie,
      song,
    ]);

    await store.replace(profileId: 'profile/one', entries: <PlaybackQueueEntry>[
      song,
      movie,
    ]);
    expect(await store.load(profileId: 'profile/one'), <PlaybackQueueEntry>[
      song,
      movie,
    ]);
    expect(await store.load(profileId: 'profile/two'), isEmpty);

    await store.remove(profileId: 'profile/one', entry: song);
    expect(await store.load(profileId: 'profile/one'), <PlaybackQueueEntry>[
      movie,
    ]);
  });

  test('rejects a malformed persisted queue instead of dropping entries',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'mos_playback_queue_v1_profile': '[{"kind":"unknown","id":"entry"}]',
    });

    await expectLater(
      const PlaybackQueueStore().load(profileId: 'profile'),
      throwsFormatException,
    );
  });

  test('round trips explicit runtime minutes in media metadata', () {
    final media = MediaItem.fromJson(<String, dynamic>{
      'id': 'film-1',
      'title': 'A film',
      'type': 'movie',
      'runtime_minutes': 118,
    });

    expect(media.runtimeMinutes, 118);
    expect(media.toJson()['runtimeMinutes'], 118);
  });
}
