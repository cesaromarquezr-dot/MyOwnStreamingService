import 'package:flutter_test/flutter_test.dart';
import 'package:my_own_streaming_service/app_core.dart';
import 'package:my_own_streaming_service/hey_marathon.dart';

void main() {
  group('Hey Marathon planning', () {
    test('episode metadata is expanded in canonical season and episode order', () {
      final show = MediaItem(
        id: 'show-1',
        title: 'Example Show',
        type: 'TV Series',
        seasons: [
          {
            'title': 'Season 2',
            'episodes': [
              {'episodeNumber': 2, 'title': 'Second', 'duration': 44},
              {'episodeNumber': 1, 'title': 'First', 'duration': 42},
            ],
          },
          {
            'seasonNumber': 1,
            'episodes': [
              {'episodeNumber': 2, 'title': 'S1 second', 'duration': 41},
              {'episodeNumber': 1, 'title': 'S1 first', 'duration': 40},
            ],
          },
        ],
      );

      final episodes = MarathonEntry.fromMediaItem(show);
      expect(episodes.map((entry) => entry.title).toList(), [
        'Example Show · S01E01 · S1 first',
        'Example Show · S01E02 · S1 second',
        'Example Show · S02E01 · First',
        'Example Show · S02E02 · Second',
      ]);
      expect(episodes.every((entry) => !entry.episodeOrderNeedsReview), isTrue);
      expect(episodes.map((entry) => entry.runtimeMinutes).toList(), [40, 41, 42, 44]);
    });

    test('an episode without a canonical season or episode number is flagged', () {
      final show = MediaItem(
        id: 'show-2',
        title: 'Unmatched Show',
        type: 'TV Series',
        seasons: [
          {
            'seasonNumber': 1,
            'episodes': [
              {'title': 'Special Feature'},
            ],
          },
        ],
      );

      final entries = MarathonEntry.fromMediaItem(show);
      expect(entries.single.episodeOrderNeedsReview, isTrue);
      expect(entries.single.runtimeEstimated, isTrue);
    });

    test('schedule inserts breaks only between titles and computes finish time', () {
      final start = DateTime(2026, 10, 31, 19);
      final entries = [
        const MarathonEntry(id: 'a', mediaId: 'a', parentTitle: 'A', title: 'A', mediaType: 'movie', runtimeMinutes: 90, runtimeEstimated: false),
        const MarathonEntry(id: 'b', mediaId: 'b', parentTitle: 'B', title: 'B', mediaType: 'movie', runtimeMinutes: 90, runtimeEstimated: false),
        const MarathonEntry(id: 'c', mediaId: 'c', parentTitle: 'C', title: 'C', mediaType: 'movie', runtimeMinutes: 90, runtimeEstimated: false),
      ];
      final plan = MarathonPlan(
        id: 'test', profileId: 'p1', title: 'Night', themeId: 'cozy-cinema',
        startAt: start, entries: entries, breakEvery: 2, breakMinutes: 15,
      );
      final rows = MarathonPlannerMath.schedule(plan);
      expect(rows.map((row) => row.isBreak).toList(), [false, false, true, false]);
      expect(rows[2].startsAt, DateTime(2026, 10, 31, 22));
      expect(rows.last.endsAt, DateTime(2026, 10, 31, 23, 45));
    });

    test('plan JSON roundtrip preserves runtimes, start time and theme', () {
      final start = DateTime(2026, 12, 5, 18, 30);
      final plan = MarathonPlan(
        id: 'plan-1', profileId: 'profile-1', title: 'Wizarding Night',
        themeId: 'wizarding-fantasy', startAt: start,
        entries: const [MarathonEntry(id: 'm1', mediaId: 'm1', parentTitle: 'Film', title: 'Film', mediaType: 'movie', runtimeMinutes: 143, runtimeEstimated: false)],
        breakEvery: 1, breakMinutes: 10, foodNotes: 'No nuts',
      );
      final restored = MarathonPlan.fromJson(plan.toJson());
      expect(restored.title, plan.title);
      expect(restored.themeId, plan.themeId);
      expect(restored.startAt, start);
      expect(restored.entries.single.runtimeMinutes, 143);
      expect(restored.foodNotes, 'No nuts');
    });
  });
}
