import 'package:flutter_test/flutter_test.dart';
import 'package:my_own_streaming_service/app_core.dart';
import 'package:my_own_streaming_service/smart_search.dart';
import 'package:my_own_streaming_service/streaming_experience.dart';

void main() {
  group('Streaming experience', () {
    test('smart search tolerates a one-character title typo', () {
      final batman = MediaItem(id: 'batman', title: 'Batman', type: 'movie');
      final results = SmartSearch.search('batmn', <MediaItem>[batman]);
      expect(results.map((media) => media.id), contains('batman'));
    });

    test('smart search can match actor and genre metadata', () {
      final movie = MediaItem(
        id: 'film-1',
        title: 'A Quiet Place',
        type: 'movie',
        actors: <String>['Emily Blunt'],
        genres: <String>['Horror', 'Thriller'],
      );
      expect(SmartSearch.search('Emily Blunt', <MediaItem>[movie]), contains(movie));
      expect(SmartSearch.search('Emly Blunt', <MediaItem>[movie]), contains(movie));
      expect(SmartSearch.search('Thriller', <MediaItem>[movie]), contains(movie));
    });

    test('local recommendations use likes and exclude disliked/completed titles', () {
      final app = AppController.instance;
      final savedLiked = List<MediaItem>.from(app.liked);
      final savedWatched = List<MediaItem>.from(app.watched);
      final savedDisliked = List<MediaItem>.from(app.disliked);
      final savedRecommendations = List<MediaItem>.from(app.recommendations);
      try {
        app.liked.clear();
        app.watched.clear();
        app.disliked.clear();
        app.recommendations.clear();
        final likedSeed = MediaItem(
          id: 'liked-seed',
          title: 'Space Journey',
          type: 'movie',
          genres: <String>['Science Fiction', 'Adventure'],
          actors: <String>['Alex Example'],
        );
        final closeMatch = MediaItem(
          id: 'close-match',
          title: 'Beyond the Stars',
          type: 'movie',
          genres: <String>['Science Fiction'],
          actors: <String>['Alex Example'],
        );
        final unrelated = MediaItem(
          id: 'unrelated',
          title: 'Garden Cooking',
          type: 'movie',
          genres: <String>['Cooking'],
        );
        final disliked = MediaItem(
          id: 'disliked',
          title: 'Space Disliked',
          type: 'movie',
          genres: <String>['Science Fiction'],
        );
        app.liked.add(likedSeed);
        app.disliked.add(disliked);
        app.watched.add(unrelated);
        final ranked = SmartSearch.recommendations(
          <MediaItem>[closeMatch, unrelated, disliked],
        );
        expect(ranked.map((media) => media.id), <String>['close-match']);
      } finally {
        app.liked
          ..clear()
          ..addAll(savedLiked);
        app.watched
          ..clear()
          ..addAll(savedWatched);
        app.disliked
          ..clear()
          ..addAll(savedDisliked);
        app.recommendations
          ..clear()
          ..addAll(savedRecommendations);
      }
    });

    test('QoE summary calculates average ready time and total buffering', () {
      final summary = PlaybackQoeTelemetry.summarize(<Map<String, dynamic>>[
        <String, dynamic>{'event': 'play_requested', 'sessionId': 'one'},
        <String, dynamic>{'event': 'player_ready', 'sessionId': 'one', 'valueMs': 1000},
        <String, dynamic>{'event': 'buffer_end', 'sessionId': 'one', 'valueMs': 700},
        <String, dynamic>{'event': 'playback_error', 'sessionId': 'two'},
        <String, dynamic>{'event': 'player_ready', 'sessionId': 'two', 'valueMs': 3000},
        <String, dynamic>{'event': 'buffer_end', 'sessionId': 'two', 'valueMs': 300},
        <String, dynamic>{'event': 'completed', 'sessionId': 'two'},
      ]);
      expect(summary['sessions'], 2);
      expect(summary['averageReadyMs'], 2000);
      expect(summary['bufferedMs'], 1000);
      expect(summary['failures'], 1);
      expect(summary['completed'], 1);
    });

    test('preferences expose automatic and capped quality labels', () {
      expect(StreamingExperiencePreferences().resolutionLabel, 'Automatic');
      expect(
        StreamingExperiencePreferences(maxResolution: 720).resolutionLabel,
        '720p maximum',
      );
    });

    test('signed playback URL is accepted from metadata but not reserialized', () {
      final media = MediaItem.fromJson(<String, dynamic>{
        'id': 'm1',
        'title': 'Example Film',
        'type': 'movie',
        'playbackUrl': 'https://media.example.test/signed/master.m3u8?token=ephemeral',
      });
      expect(media.playbackUrl, startsWith('https://'));
      expect(media.toJson().containsKey('playbackUrl'), isFalse);
    });
  });
}
