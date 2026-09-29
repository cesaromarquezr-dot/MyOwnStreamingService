import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_own_streaming_service/app_core.dart';
import 'package:my_own_streaming_service/xray.dart';

void main() {
  test('MediaItem preserves timestamped X-Ray events in JSON', () {
    final media = MediaItem(
      id: 'disc-version-1',
      title: 'Example Feature',
      type: 'movie',
      xrayEvents: [
        {
          'startSeconds': 0,
          'endSeconds': 30,
          'title': 'Opening scene',
          'people': [
            {'actor': 'Actor A', 'character': 'Character A'},
          ],
        },
      ],
    );

    final restored = MediaItem.fromJson(media.toJson());

    expect(restored.xrayEvents, media.xrayEvents);
  });

  testWidgets('X-Ray switches to the event at the current playback time', (
    tester,
  ) async {
    final position = ValueNotifier<Duration>(Duration.zero);
    final media = MediaItem(
      id: 'disc-version-1',
      title: 'Example Feature',
      type: 'movie',
      xrayEvents: [
        {
          'startSeconds': 0,
          'endSeconds': 10,
          'title': 'Atrium scene',
          'people': [
            {'actor': 'Actor A', 'character': 'Character A'},
          ],
        },
        {
          'startSeconds': 10,
          'endSeconds': 20,
          'title': 'Rooftop scene',
          'people': [
            {'actor': 'Actor B', 'character': 'Character B'},
          ],
        },
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: XRayScreen(media: media, playbackPosition: position),
      ),
    );

    expect(find.text('Atrium scene'), findsOneWidget);
    expect(find.text('Actor A'), findsOneWidget);

    position.value = const Duration(seconds: 12);
    await tester.pump();

    expect(find.text('Rooftop scene'), findsOneWidget);
    expect(find.text('Actor B'), findsOneWidget);
    expect(find.text('Atrium scene'), findsNothing);

    position.dispose();
  });
}
