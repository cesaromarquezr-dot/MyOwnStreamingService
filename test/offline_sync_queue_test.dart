import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_own_streaming_service/offline_sync_queue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OfflineSyncQueue', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('coalesces playback progress by profile and media', () async {
      final queue = OfflineSyncQueue(scopeId: 'account-a');
      final start = DateTime.utc(2026, 1, 1);
      await queue.enqueuePlaybackProgress(
        profileId: 'profile-a', mediaId: 'movie-a', progress: 0.25, now: start,
      );
      await queue.enqueuePlaybackProgress(
        profileId: 'profile-a', mediaId: 'movie-a', progress: 0.70,
        now: start.add(const Duration(seconds: 12)),
      );
      final queued = await queue.list();
      expect(queued, hasLength(1));
      expect(queued.single.payload['progress'], 0.70);
    });

    test('flush removes acknowledged actions and retains failed actions', () async {
      final queue = OfflineSyncQueue(scopeId: 'account-b');
      await queue.enqueuePlaybackProgress(profileId: 'p', mediaId: 'one', progress: 0.2);
      await queue.enqueuePlaybackProgress(profileId: 'p', mediaId: 'two', progress: 0.4);
      final sent = await queue.flush((action) async => action.resourceId == 'one');
      final remaining = await queue.list();
      expect(sent, 1);
      expect(remaining.map((item) => item.resourceId).toList(), <String>['two']);
    });

    test('queues are isolated by account scope', () async {
      await OfflineSyncQueue(scopeId: 'account-a').enqueuePlaybackProgress(
        profileId: 'p', mediaId: 'm', progress: 0.6,
      );
      expect(await OfflineSyncQueue(scopeId: 'account-b').list(), isEmpty);
    });
  });
}
