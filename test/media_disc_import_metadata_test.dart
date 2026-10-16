import 'package:flutter_test/flutter_test.dart';

import '../Backend/models/media.dart';

void main() {
  group('Media disc-import metadata', () {
    test('round-trips canonical episode order and track/chapter details', () {
      final original = Media(
        id: 'north-shore-s01e02',
        title: 'The Visit',
        type: MediaType.tvShow,
        seriesId: 'show-123',
        seriesTitle: 'North Shore',
        seasonNumber: 1,
        episodeNumber: 2,
        episodeEndNumber: 2,
        episodeOrderScheme: 'aired',
        episodeOrderNeedsReview: false,
        episodeMatchSource: 'user_confirmed:tmdb',
        episodeMatchConfidence: 1.0,
        audioTracks: const ['spa — Español — E-AC-3, 6 ch'],
        languages: const ['spa', 'eng'],
        subtitles: const ['eng — English SDH'],
        chapters: const ['Opening (0s)'],
        videoTrackDetails: const [
          {'index': 0, 'codec': 'h264', 'width': 1920, 'height': 1080},
        ],
        audioTrackDetails: const [
          {
            'index': 1,
            'language': 'spa',
            'title': 'Español',
            'codec': 'eac3',
            'channels': 6,
            'isCommentary': false,
          },
          {
            'index': 2,
            'language': 'eng',
            'title': 'Director Commentary',
            'isCommentary': true,
          },
        ],
        subtitleTrackDetails: const [
          {'index': 3, 'language': 'eng', 'isHearingImpaired': true},
        ],
        chapterMarkers: const [
          {'index': 1, 'title': 'Opening', 'startSeconds': 0.0},
        ],
        sourceFormatInfo: const {'formatName': 'matroska', 'durationSeconds': 2580.0},
      );

      final restored = Media.fromJson(original.toJson());

      expect(restored.seriesId, 'show-123');
      expect(restored.seasonNumber, 1);
      expect(restored.episodeNumber, 2);
      expect(restored.episodeOrderNeedsReview, isFalse);
      expect(restored.audioTrackDetails, hasLength(2));
      expect(restored.audioTrackDetails[1]['isCommentary'], isTrue);
      expect(restored.subtitleTrackDetails.single['isHearingImpaired'], isTrue);
      expect(restored.chapterMarkers.single['title'], 'Opening');
      expect(restored.sourceFormatInfo['formatName'], 'matroska');
    });

    test('copyWith preserves technical tracks unless explicitly replaced', () {
      final media = Media(
        id: 'movie-1',
        title: 'Example Movie',
        type: MediaType.movie,
        audioTrackDetails: const [
          {'index': 1, 'language': 'eng', 'isCommentary': true},
        ],
        chapterMarkers: const [
          {'index': 1, 'title': 'Chapter 1', 'startSeconds': 0.0},
        ],
      );

      final copied = media.copyWith(title: 'Example Movie Remastered');

      expect(copied.title, 'Example Movie Remastered');
      expect(copied.audioTrackDetails.single['isCommentary'], isTrue);
      expect(copied.chapterMarkers.single['title'], 'Chapter 1');
    });
  });
}
