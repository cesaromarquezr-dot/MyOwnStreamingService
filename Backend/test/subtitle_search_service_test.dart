import 'dart:io';

import 'package:test/test.dart';

import '../services/subtitle_search_service.dart';

void main() {
  group('SubtitleSearchService', () {
    late Directory mediaRoot;
    late SubtitleSearchService service;

    setUp(() async {
      mediaRoot = await Directory.systemTemp.createTemp('subtitle-search-');
      service = SubtitleSearchService();
    });

    tearDown(() async {
      if (await mediaRoot.exists()) {
        await mediaRoot.delete(recursive: true);
      }
    });

    test('parses SRT and WebVTT timestamps and removes markup', () {
      final cues = SubtitleSearchService.parse(
        'WEBVTT\n\n00:01.250 --> 00:03.000\n<b>Hello &amp; welcome</b>\n\n'
        '2\n00:00:04,500 --> 00:00:06,000\n{\\an8}Next line',
        mediaId: 'film.mkv',
      );

      expect(cues, hasLength(2));
      expect(cues[0].startMs, 1250);
      expect(cues[0].text, 'Hello & welcome');
      expect(cues[1].startMs, 4500);
      expect(cues[1].text, 'Next line');
    });

    test('indexes matching sidecars and searches cues by all query terms',
        () async {
      await File('${mediaRoot.path}${Platform.pathSeparator}Film.mkv')
          .writeAsBytes(<int>[0]);
      await File('${mediaRoot.path}${Platform.pathSeparator}Film.en.srt')
          .writeAsString(
        '1\n00:00:10,000 --> 00:00:12,000\nI am Iron Man.\n\n'
        '2\n00:00:20,000 --> 00:00:22,000\nHello there.',
      );
      await File('${mediaRoot.path}${Platform.pathSeparator}Other.srt')
          .writeAsString('1\n00:00:00,000 --> 00:00:01,000\nNot a sidecar.');
      await File('${mediaRoot.path}${Platform.pathSeparator}Film.txt')
          .writeAsString('not a subtitle');

      final summary = await service.index(
        accountId: 'account-a',
        mediaRoot: mediaRoot,
      );
      final matches = service.search(
        accountId: 'account-a',
        query: 'iron man',
      );

      expect(summary.indexedFiles, 1);
      expect(summary.indexedCues, 2);
      expect(summary.skippedFiles, 1);
      expect(matches.matches, hasLength(1));
      expect(matches.matches.single.mediaId, 'Film.mkv');
      expect(matches.matches.single.startMs, 10000);
      expect(matches.matches.single.text, 'I am Iron Man.');
      expect(matches.hasMore, isFalse);
    });

    test('keeps indexed captions isolated to the authenticated account',
        () async {
      await File('${mediaRoot.path}${Platform.pathSeparator}Film.mp4')
          .writeAsBytes(<int>[0]);
      await File('${mediaRoot.path}${Platform.pathSeparator}Film.vtt')
          .writeAsString('WEBVTT\n\n00:01.000 --> 00:02.000\nPrivate dialogue');

      await service.index(accountId: 'account-a', mediaRoot: mediaRoot);

      expect(
        () => service.search(accountId: 'account-b', query: 'private'),
        throwsStateError,
      );
      expect(
        service.search(accountId: 'account-a', query: 'private').matches,
        hasLength(1),
      );
    });

    test('marks search results when the response limit is reached', () async {
      await File('${mediaRoot.path}${Platform.pathSeparator}Film.mkv')
          .writeAsBytes(<int>[0]);
      final captions = StringBuffer();
      for (var index = 0; index < 101; index++) {
        captions
          ..writeln(index + 1)
          ..writeln('00:00:00,000 --> 00:00:01,000')
          ..writeln('repeated dialogue')
          ..writeln();
      }
      await File('${mediaRoot.path}${Platform.pathSeparator}Film.srt')
          .writeAsString(captions.toString());

      await service.index(accountId: 'account-a', mediaRoot: mediaRoot);
      final result =
          service.search(accountId: 'account-a', query: 'repeated dialogue');

      expect(result.matches, hasLength(100));
      expect(result.hasMore, isTrue);
    });
  });
}
