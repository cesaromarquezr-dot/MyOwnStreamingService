import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_own_streaming_service/music.dart';
import 'package:my_own_streaming_service/music_favorites.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var run = 0;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    run++;
    final profileId = 'smart-playlist-test-$run';
    await MusicFavoritesBridge.initializeForProfile(profileId);
    final store = MusicLibraryStore.instance;
    await store.initializeForProfile(profileId);
    store.tracks.clear();
    store.listenCounts.clear();
    store.playlists.clear();
    store.tracks.addAll(const <MusicTrack>[
      MusicTrack(
        id: 'track-a',
        title: 'Night Drive',
        artist: 'Example Artist',
        album: 'After Hours',
        genres: <String>['Electronic'],
      ),
      MusicTrack(
        id: 'track-b',
        title: 'Soft Morning',
        artist: 'Another Artist',
        album: 'Daybreak',
        genres: <String>['Acoustic'],
      ),
    ]);
  });

  test('Liked Songs updates dynamically without changing custom playlists', () async {
    final store = MusicLibraryStore.instance;
    store.playlists['Manual Mix'] = <String>['track-a', 'track-b'];

    expect(store.smartPlaylists['Liked Songs'], isEmpty);
    MusicFavoritesBridge.toggleTrack('track-a');
    expect(store.smartPlaylists['Liked Songs'], <String>['track-a']);
    expect(store.playlists['Manual Mix'], <String>['track-a', 'track-b']);

    MusicFavoritesBridge.toggleTrack('track-a');
    expect(store.smartPlaylists['Liked Songs'], isEmpty);
    expect(store.playlists['Manual Mix'], <String>['track-a', 'track-b']);
  });

  test('genre mixes are generated from current track metadata', () {
    final mixes = MusicLibraryStore.instance.smartPlaylists;
    expect(mixes['Electronic Mix'], <String>['track-a']);
    expect(mixes['Acoustic Mix'], <String>['track-b']);
  });
  test('On Repeat and Top 100 are ranked by per-profile play counts', () {
    final store = MusicLibraryStore.instance;
    store.recordListen('track-a');
    store.recordListen('track-a');
    store.recordListen('track-a');
    store.recordListen('track-b');

    expect(store.smartPlaylists['On Repeat'], <String>['track-a']);
    expect(store.smartPlaylists['Top 100 Most Played'], <String>['track-a', 'track-b']);
  });

  test('queue can be reordered and removed without changing playlists', () {
    final store = MusicLibraryStore.instance;
    store.setQueue(store.tracks.where((track) => track.id == 'track-a' || track.id == 'track-b'));
    store.reorderQueue(0, 2);
    expect(store.queue, <String>['track-b', 'track-a']);
    store.removeFromQueue('track-b');
    expect(store.queue, <String>['track-a']);
    expect(store.playlists, isEmpty);
  });

  test('listening counts persist when the same profile music store reloads', () async {
    final store = MusicLibraryStore.instance;
    final profileId = 'smart-playlist-test-$run';
    store.recordListen('track-a');
    await Future<void>.delayed(const Duration(milliseconds: 30));
    await store.initializeForProfile(profileId);
    expect(store.listenCounts['track-a'], 1);
  });

}
