import 'package:flutter_test/flutter_test.dart';

import '../Backend/arm/arm_models.dart';
import '../Backend/arm/episode_order_resolver.dart';
import '../Backend/arm/metadata_service.dart';

void main() {
  const resolver = ArmEpisodeOrderResolver();

  group('ArmEpisodeOrderResolver', () {
    test('parses SxxExx codes and does not use physical disc number', () {
      final discThree = resolver.resolve(
        ArmDiscTitle(
          id: 'disc-3-episode-3',
          title: 'North Shore S01E03 The Storm',
          mediaType: 'tv',
          discNumber: 3,
        ),
      );
      final discOne = resolver.resolve(
        ArmDiscTitle(
          id: 'disc-1-episode-1',
          title: 'North Shore S01E01 Pilot',
          mediaType: 'tv',
          discNumber: 1,
        ),
      );
      final discTwo = resolver.resolve(
        ArmDiscTitle(
          id: 'disc-2-episode-2',
          title: 'North Shore S01E02 The Visit',
          mediaType: 'tv',
          discNumber: 2,
        ),
      );

      final sorted = resolver.sortForWatchOrder(
        [discThree, discOne, discTwo],
      );

      expect(sorted.map((title) => title.id), [
        'disc-1-episode-1',
        'disc-2-episode-2',
        'disc-3-episode-3',
      ]);
      expect(discThree.episodeIdentity?.seasonNumber, 1);
      expect(discThree.episodeIdentity?.episodeNumber, 3);
      // A filename/title pattern can order an episode, but requires a
      // confirmation from a provider or the import-review screen.
      expect(discThree.needsEpisodeOrderReview, isTrue);
    });

    test('supports the 1x02 numbering pattern and season-zero specials', () {
      final episode = resolver.resolve(
        ArmDiscTitle(
          id: 'episode-2',
          title: 'Harbor Stories 2x02 The Signal',
          mediaType: 'television',
        ),
      );
      final special = ArmDiscTitle.fromJson({
        'id': 'special-1',
        'title': 'Holiday Special',
        'mediaType': 'tv',
        'classification': 'episode',
        'episodeIdentity': {
          'seriesTitle': 'Harbor Stories',
          'seasonNumber': 0,
          'episodeNumber': 1,
          'episodeTitle': 'Holiday Special',
          'confidence': 0.98,
          'matchSource': 'metadata_provider',
        },
      });

      expect(episode.episodeIdentity?.seasonNumber, 2);
      expect(episode.episodeIdentity?.episodeNumber, 2);
      expect(special.episodeIdentity?.seasonNumber, 0);
      expect(special.needsEpisodeOrderReview, isFalse);
    });


    test('recognizes explicit episode numbering even when ARM says movie', () {
      final detected = resolver.resolve(
        ArmDiscTitle(
          id: 'generic-title-2',
          title: 'North Shore S02E04 The Crossing',
          mediaType: 'movie',
          classification: 'feature',
        ),
      );

      expect(detected.isEpisode, isTrue);
      expect(detected.episodeIdentity?.seriesTitle, 'North Shore');
      expect(detected.episodeIdentity?.seasonNumber, 2);
      expect(detected.episodeIdentity?.episodeNumber, 4);
      expect(detected.needsEpisodeOrderReview, isTrue);
    });

    test('does not infer season or episode from disc number', () {
      final title = resolver.resolve(
        ArmDiscTitle(
          id: 'ambiguous-disc-4',
          title: 'Pilot',
          mediaType: 'tv',
          discNumber: 4,
        ),
      );

      expect(title.episodeIdentity, isNull);
      expect(title.needsEpisodeOrderReview, isTrue);
    });

    test('keeps bonus extras separate from primary TV episode classification', () {
      final extra = ArmDiscTitle(
        id: 'deleted-scene',
        title: 'Deleted Scene',
        mediaType: 'tv',
        classification: 'deleted_scene',
      );

      expect(
        extra.toDiscContent(discId: 'disc-1').contentType,
        ArmDiscContentType.deletedScene,
      );
      expect(extra.toDiscContent(discId: 'disc-1').primary, isFalse);
    });


    test('confirmed episode metadata locks canonical series and order', () {
      final detected = resolver.resolve(
        ArmDiscTitle(
          id: 'episode-2',
          title: 'S01E02 The Visit',
          mediaType: 'tv',
        ),
      );
      final candidate = MetadataCandidate(
        id: 'provider-episode-2',
        provider: MetadataProvider.tmdb,
        entityType: MetadataEntityType.episode,
        title: 'The Visit',
        confidence: 0.99,
        metadata: const {
          'seriesId': 'show-123',
          'seriesTitle': 'North Shore',
          'seasonNumber': 1,
          'episodeNumber': 2,
          'orderScheme': 'aired',
        },
      );

      final confirmed = resolver.applyConfirmedMetadataMatch(
        detected,
        candidate,
      );

      expect(confirmed.isEpisode, isTrue);
      expect(confirmed.episodeIdentity?.seriesId, 'show-123');
      expect(confirmed.episodeIdentity?.watchOrderKey, 'show-123|01|002');
      expect(confirmed.canonicalTitle, 'The Visit');
      expect(confirmed.needsEpisodeOrderReview, isFalse);
    });

    test('album classification is not downgraded to a song', () {
      final album = ArmDiscTitle(
        id: 'album-1',
        title: 'Night Album',
        mediaType: 'music',
        classification: 'album',
      );
      expect(
        album.toDiscContent(discId: 'disc-a').contentType,
        ArmDiscContentType.album,
      );
    });

    test('round-trips language tracks and chapter markers on verification', () {
      final verification = ArmVerificationResult(
        passed: true,
        score: 100,
        audioTracks: const [
          {
            'index': 1,
            'language': 'spa',
            'title': 'Spanish Commentary',
            'isCommentary': true,
          },
        ],
        subtitleTracks: const [
          {'index': 2, 'language': 'eng', 'isForced': true},
        ],
        chapterMarkers: const [
          {'index': 1, 'title': 'Opening', 'startSeconds': 0.0},
        ],
      );

      final decoded = ArmVerificationResult.fromJson(verification.toJson());
      expect(decoded.audioTracks.single['language'], 'spa');
      expect(decoded.audioTracks.single['isCommentary'], isTrue);
      expect(decoded.subtitleTracks.single['isForced'], isTrue);
      expect(decoded.chapterMarkers.single['title'], 'Opening');
    });
  });
}
