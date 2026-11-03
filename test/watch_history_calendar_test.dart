import 'package:flutter_test/flutter_test.dart';

import 'package:my_own_streaming_service/entertainment_extensions.dart';
import 'package:my_own_streaming_service/watch_history_calendar.dart';

WrappedActivityRecord _event(String type, DateTime date) =>
    WrappedActivityRecord(
      eventId: '$type-${date.toIso8601String()}',
      profileId: 'profile-1',
      mediaId: 'media-$type',
      canonicalWorkId: 'work-$type',
      title: 'Sample $type',
      type: type,
      genres: const <String>[],
      occurredAt: date,
    );

void main() {
  group('WatchHistoryCalendarData', () {
    test('filters completed activity by media category', () {
      final movie = _event('movie', DateTime(2026, 1, 1));
      final episode = _event('episode', DateTime(2026, 1, 2));
      final song = _event('song', DateTime(2026, 1, 3));

      expect(WatchHistoryCalendarData.matches(movie, HistoryMediaFilter.movies),
          isTrue);
      expect(
          WatchHistoryCalendarData.matches(episode, HistoryMediaFilter.shows),
          isTrue);
      expect(WatchHistoryCalendarData.matches(song, HistoryMediaFilter.music),
          isTrue);
      expect(WatchHistoryCalendarData.matches(song, HistoryMediaFilter.movies),
          isFalse);
    });

    test('calculates current and longest streak from distinct active days', () {
      final events = <WrappedActivityRecord>[
        _event('movie', DateTime(2026, 1, 1, 9)),
        _event('movie', DateTime(2026, 1, 2, 9)),
        _event('song', DateTime(2026, 1, 3, 9)),
        _event('episode', DateTime(2026, 1, 5, 9)),
        _event('episode', DateTime(2026, 1, 5, 20)),
      ];

      final summary = WatchHistoryCalendarData.streaks(
        events,
        filter: HistoryMediaFilter.all,
        today: DateTime(2026, 1, 5, 12),
      );

      expect(summary.currentDays, 1);
      expect(summary.longestDays, 3);
    });

    test('current streak can include yesterday when today has no activity', () {
      final events = <WrappedActivityRecord>[
        _event('song', DateTime(2026, 1, 4, 9)),
        _event('song', DateTime(2026, 1, 5, 9)),
      ];

      final summary = WatchHistoryCalendarData.streaks(
        events,
        filter: HistoryMediaFilter.music,
        today: DateTime(2026, 1, 6, 12),
      );

      expect(summary.currentDays, 2);
      expect(summary.longestDays, 2);
    });
  });
}
