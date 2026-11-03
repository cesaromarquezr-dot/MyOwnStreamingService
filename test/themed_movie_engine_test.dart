import 'package:flutter_test/flutter_test.dart';

import 'package:my_own_streaming_service/app_core.dart';
import 'package:my_own_streaming_service/themed_movie_engine.dart';

void main() {
  MediaItem movie(
    String title, {
    String type = 'movie',
    List<String> genres = const <String>[],
  }) =>
      MediaItem(id: title, title: title, type: type, genres: genres);

  group('ThemedMovieEngine holiday curveballs', () {
    test('keeps a New Year setting distinct from a movie tone', () {
      final matches = ThemedMovieEngine.curveballMatchesForMovie(
        movie('Y2K', genres: const <String>['Science Fiction', 'Comedy']),
      );

      expect(
        matches.map((match) => match.moodKey),
        contains('new-year-chaos'),
      );
      expect(
        matches.map((match) => match.holidayKey),
        contains('new-year'),
      );
      expect(matches.map((match) => match.moodKey),
          isNot(contains('dark-holiday')));
    });

    test('finds light Halloween movies without tagging them as horror', () {
      final curated = ThemedMovieEngine.curveballMatchesForMovie(
        movie('Hocus Pocus'),
      );
      final metadataMatched = ThemedMovieEngine.curveballMatchesForMovie(
        movie('A Halloween Adventure',
            genres: const <String>['Family', 'Comedy']),
      );

      expect(
          curated.map((match) => match.moodKey), contains('halloween-light'));
      expect(
        metadataMatched.map((match) => match.moodKey),
        contains('halloween-light'),
      );
    });

    test('recognizes holiday thrillers and horror-comedies as curveballs', () {
      final valentines = ThemedMovieEngine.curveballMatchesForMovie(
        movie('Heart Eyes', genres: const <String>['Horror', 'Thriller']),
      );
      final christmas = ThemedMovieEngine.curveballMatchesForMovie(
        movie('Violent Night', genres: const <String>['Action', 'Horror']),
      );

      expect(
        valentines.map((match) => match.moodKey),
        contains('valentines-nonromantic'),
      );
      expect(
          valentines.map((match) => match.holidayKey), contains('valentines'));
      expect(christmas.map((match) => match.moodKey), contains('dark-holiday'));
      expect(christmas.map((match) => match.holidayKey), contains('christmas'));
    });

    test(
        'supports Christmas action, comedy, and fantasy without requiring horror',
        () {
      final redOne = ThemedMovieEngine.curveballMatchesForMovie(
        movie('Red One', genres: const <String>['Action', 'Comedy']),
      );
      final dieHard = ThemedMovieEngine.curveballMatchesForMovie(
        movie('Die Hard', genres: const <String>['Action', 'Thriller']),
      );
      final wonderfulLife = ThemedMovieEngine.curveballMatchesForMovie(
        movie("It's a Wonderful Life"),
      );

      expect(redOne.map((match) => match.holidayKey), contains('christmas'));
      expect(
        redOne.map((match) => match.moodKey),
        containsAll(<String>['holiday-action-adventure', 'holiday-comedy']),
      );
      expect(
        dieHard.map((match) => match.moodKey),
        contains('holiday-action-adventure'),
      );
      expect(dieHard.map((match) => match.moodKey),
          isNot(contains('dark-holiday')));
      expect(
        wonderfulLife.map((match) => match.moodKey),
        contains('holiday-sci-fi-fantasy'),
      );
      expect(
        wonderfulLife.map((match) => match.holidayKey),
        contains('christmas'),
      );
    });

    test('recognizes curveballs across other holiday settings', () {
      const examples = <String, String>{
        'Terror Train': 'new-year',
        'Thankskilling': 'thanksgiving',
        'Critters 2: The Main Course': 'easter',
        'Jaws': 'independence-day',
        'The Blackening': 'juneteenth',
        'Leprechaun': 'st-patricks',
        "April Fool's Day": 'april-fools',
      };

      for (final example in examples.entries) {
        final matches = ThemedMovieEngine.curveballMatchesForMovie(
          movie(example.key, genres: const <String>['Horror']),
        );
        expect(
          matches.map((match) => match.holidayKey),
          contains(example.value),
          reason: example.key,
        );
      }
    });

    test('does not classify a series as a holiday movie', () {
      final matches = ThemedMovieEngine.curveballMatchesForMovie(
        movie('Y2K', type: 'series', genres: const <String>['Science Fiction']),
      );

      expect(matches, isEmpty);
    });
  });
}
