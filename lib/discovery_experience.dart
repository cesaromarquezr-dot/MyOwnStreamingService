// FILE: `lib/discovery_experience.dart`.
// Purpose: Provides local recommendation reasoning and seasonal collection UI.
// Physical media remains on the account's home server; this file only works
// with library metadata already available to the Flutter client.

import 'package:flutter/material.dart';

import 'app_core.dart';
import 'details.dart';
import 'localization.dart';
import 'music.dart';

/// Describes why one owned title is a useful recommendation for another title.
class MediaRecommendation {
  final MediaItem media;
  final String reason;
  final int score;

  const MediaRecommendation({
    required this.media,
    required this.reason,
    required this.score,
  });
}

/// Produces explainable recommendations from the user's own library.
///
/// The engine intentionally uses relationships that can be derived from
/// imported metadata: genre, tags, cast, directors, franchise and themes.
///
/// No external recommendation service is required, and candidates are always
/// selected from the supplied library.
class MediaRecommendationEngine {
  static List<MediaRecommendation> forMedia(
    MediaItem source,
    Iterable<MediaItem> library,
  ) {
    final results = <MediaRecommendation>[];

    final sourceGenres = _normalized(source.genres);
    final sourceTags = _normalized(source.tags);
    final sourceActors = _normalized(source.actors);
    final sourceDirectors = _normalized(source.directors);

    for (final candidate in library) {
      if (candidate.id == source.id) {
        continue;
      }

      var score = 0;
      final reasons = <String>[];

      final candidateGenres = _normalized(candidate.genres);
      final sharedGenres = sourceGenres.intersection(candidateGenres);

      if (sharedGenres.isNotEmpty) {
        score += sharedGenres.length * 3;
        reasons.add(
          'same ${sharedGenres.take(2).join(' + ')}',
        );
      }

      final candidateTags = _normalized(candidate.tags);
      final sharedTags = sourceTags.intersection(candidateTags);

      if (sharedTags.isNotEmpty) {
        score += sharedTags.length * 2;
        reasons.add(
          'shared themes: ${sharedTags.take(2).join(', ')}',
        );
      }

      final candidateActors = _normalized(candidate.actors);
      final sharedActors = sourceActors.intersection(candidateActors);

      if (sharedActors.isNotEmpty) {
        score += sharedActors.length * 10;

        final actorNames = sharedActors.take(2).join(', ');
        reasons.add(
          'shared cast: $actorNames',
        );
      }

      final candidateDirectors = _normalized(candidate.directors);
      final sharedDirectors =
          sourceDirectors.intersection(candidateDirectors);

      if (sharedDirectors.isNotEmpty) {
        score += sharedDirectors.length * 5;

        final directorNames = sharedDirectors.take(2).join(', ');
        reasons.add(
          sharedDirectors.length == 1
              ? 'same director: $directorNames'
              : 'shared directors: $directorNames',
        );
      }

      final sourceFranchise = source.franchiseId?.trim();
      final candidateFranchise = candidate.franchiseId?.trim();

      if (sourceFranchise != null &&
          sourceFranchise.isNotEmpty &&
          sourceFranchise == candidateFranchise) {
        score += 12;
        reasons.add('same franchise');
      }

      final semanticReasons = _semanticReasons(
        source,
        candidate,
      );

      if (semanticReasons.isNotEmpty) {
        score += semanticReasons.length * 8;
        reasons.addAll(semanticReasons);
      }

      if (score > 0) {
        results.add(
          MediaRecommendation(
            media: candidate,
            reason: reasons.isEmpty
                ? 'similar library signals'
                : reasons.toSet().join(' • '),
            score: score,
          ),
        );
      }
    }

    // Keep ranking deterministic when two titles have the same score.
    results.sort(
      (a, b) {
        final scoreComparison = b.score.compareTo(a.score);

        if (scoreComparison != 0) {
          return scoreComparison;
        }

        return a.media.title.toLowerCase().compareTo(
              b.media.title.toLowerCase(),
            );
      },
    );

    return results.take(12).toList();
  }

  static Set<String> _normalized(Iterable<String> values) {
    return values
        .map(_normalize)
        .where((value) => value.isNotEmpty)
        .toSet();
  }

  static String _normalize(String value) {
    return value.trim().toLowerCase();
  }

  /// Finds explainable genre/subgenre and hybrid relationships.
  ///
  /// Metadata can contain either a primary genre (for example `Science
  /// Fiction`) or more specific values/tags (for example `Time Travel`).
  /// The taxonomy is deliberately broad so imported movie and TV metadata
  /// can drive recommendations without requiring a database migration.
  static List<String> _semanticReasons(
    MediaItem source,
    MediaItem candidate,
  ) {
    final sourceText = _mediaText(source);
    final candidateText = _mediaText(candidate);
    final reasons = <String>[];

    final sourceGenres = _genreFamilies(sourceText);
    final candidateGenres = _genreFamilies(candidateText);

    final sharedFamilies =
        sourceGenres.intersection(candidateGenres);

    for (final family in sharedFamilies.take(3)) {
      reasons.add('same $family genre family');
    }

    final sourceSubgenres = _subgenreFamilies(sourceText);
    final candidateSubgenres = _subgenreFamilies(candidateText);

    final sharedSubgenres =
        sourceSubgenres.intersection(candidateSubgenres);

    for (final subgenre in sharedSubgenres.take(3)) {
      reasons.add('same $subgenre subgenre');
    }

    final hybrid = _hybridReason(
      sourceText,
      candidateText,
    );

    if (hybrid != null) {
      reasons.add(hybrid);
    }

    // Existing examples remain explicit while the general taxonomy above
    // handles the same relationships for other titles.
    final sourceTitle = _normalize(source.title);
    final candidateTitle = _normalize(candidate.title);

    if (sourceTitle.contains('friends') &&
        candidateTitle.contains('how i met your mother')) {
      reasons.add(
        'friend-group sitcom with character-driven relationships',
      );
    }

    if (sourceTitle.contains('friends') &&
        candidateTitle.contains('brooklyn nine-nine')) {
      reasons.add(
        'sitcom with a workplace police setting',
      );
    }

    if (sourceTitle.contains('friends') &&
        candidateTitle.contains('modern family')) {
      reasons.add(
        'sitcom centered on family relationships',
      );
    }

    if (sourceTitle.contains('friends') &&
        candidateTitle.contains('abbott elementary')) {
      reasons.add(
        'sitcom centered on a school community',
      );
    }

    if (_isAdultAnimation(source) &&
        _isAdultAnimation(candidate)) {
      reasons.add(
        'similar adult-animation comedy',
      );
    }

    return reasons.toSet().toList();
  }

  static String _mediaText(MediaItem media) {
    return '${media.title} '
            '${media.description ?? ''} '
            '${media.genres.join(' ')} '
            '${media.tags.join(' ')}'
        .toLowerCase();
  }

  static Set<String> _genreFamilies(String text) {
    const families = <String, List<String>>{
      'action': [
        'action',
        'adventure',
        'martial arts',
        'spy',
        'disaster',
      ],
      'comedy': [
        'comedy',
        'sitcom',
        'romantic comedy',
        'rom-com',
        'slapstick',
        'mockumentary',
        'satire',
      ],
      'crime': [
        'crime',
        'gangster',
        'heist',
        'film noir',
        'neo-noir',
      ],
      'drama': [
        'drama',
        'biopic',
        'historical drama',
        'legal drama',
        'courtroom',
        'melodrama',
        'medical drama',
        'teen drama',
        'dramedy',
      ],
      'fantasy': [
        'fantasy',
        'high fantasy',
        'epic fantasy',
        'urban fantasy',
        'dark fantasy',
      ],
      'horror': [
        'horror',
        'slasher',
        'supernatural horror',
        'psychological horror',
        'zombie',
        'found footage',
      ],
      'mystery': [
        'mystery',
        'whodunit',
      ],
      'romance': [
        'romance',
        'romantic comedy',
        'rom-com',
        'romantic drama',
      ],
      'science fiction': [
        'science fiction',
        'sci-fi',
        'space opera',
        'dystopian',
        'cyberpunk',
        'time travel',
        'space western',
      ],
      'sports': [
        'sports',
        'sports drama',
        'sports comedy',
      ],
      'thriller': [
        'thriller',
        'psychological thriller',
        'crime thriller',
        'political thriller',
        'techno-thriller',
      ],
      'war': [
        'war',
        'military drama',
        'anti-war',
        'war biographical',
      ],
      'western': [
        'western',
        'spaghetti western',
        'revisionist western',
        'epic western',
      ],
      'animation': [
        'animation',
        'animated',
        'anime',
        'adult animation',
        'cgi animation',
        'stop motion',
      ],
      'documentary': [
        'documentary',
        'docuseries',
        'non-fiction',
        'nonfiction',
      ],
    };

    return {
      for (final entry in families.entries)
        if (_containsAny(text, entry.value)) entry.key,
    };
  }

  static Set<String> _subgenreFamilies(String text) {
    const subgenres = <String>[
      'adventure',
      'disaster',
      'martial arts',
      'spy',
      'romantic comedy',
      'rom-com',
      'slapstick',
      'dark comedy',
      'black comedy',
      'mockumentary',
      'satire',
      'biopic',
      'historical drama',
      'legal drama',
      'courtroom',
      'melodrama',
      'medical drama',
      'police procedural',
      'crime drama',
      'teen drama',
      'dramedy',
      'slasher',
      'supernatural horror',
      'psychological horror',
      'zombie',
      'found footage',
      'space opera',
      'dystopian',
      'cyberpunk',
      'time travel',
      'psychological thriller',
      'crime thriller',
      'political thriller',
      'techno-thriller',
      'historical romance',
      'romantic drama',
      'high fantasy',
      'epic fantasy',
      'urban fantasy',
      'dark fantasy',
      'film noir',
      'gangster',
      'heist',
      'neo-noir',
      'spaghetti western',
      'revisionist western',
      'epic western',
      'space western',
      'military drama',
      'anti-war',
      'war biographical',
      'cgi animation',
      'stop motion',
      'anime',
      'adult animation',
      'competition show',
      'self-improvement',
      'reality',
      'talk show',
      'interview',
      'game show',
      'variety show',
      'award show',
      'news',
      'cooking',
      'home and garden',
      'educational',
      'court show',
      'religious programming',
      'music television',
    ];

    return {
      for (final value in subgenres)
        if (text.contains(value)) value,
    };
  }

  static String? _hybridReason(
    String sourceText,
    String candidateText,
  ) {
    const pairs = <List<String>>[
      ['action', 'comedy'],
      ['science fiction', 'horror'],
      ['crime', 'thriller'],
      ['romance', 'comedy'],
      ['romance', 'drama'],
      ['comedy', 'drama'],
      ['fantasy', 'adventure'],
      ['science fiction', 'western'],
    ];

    for (final pair in pairs) {
      final sourceHas = _containsAny(
        sourceText,
        pair,
      );

      final candidateHas = _containsAny(
        candidateText,
        pair,
      );

      if (sourceHas && candidateHas) {
        return '${pair[0]} + ${pair[1]} hybrid';
      }
    }

    return null;
  }

  static bool _isAdultAnimation(MediaItem media) {
    final text = _mediaText(media);

    const adultSignals = [
      'adult animation',
      'adult animated',
      'adult cartoon',
      'adult animated comedy',
    ];

    if (_containsAny(text, adultSignals)) {
      return true;
    }

    final isAnimation = _containsAny(
      text,
      const [
        'animation',
        'animated',
        'cartoon',
      ],
    );

    final isAdult = _containsAny(
      text,
      const [
        'adult',
        'mature',
        'satire',
        'adult comedy',
      ],
    );

    // These well-known adult-animation titles are classification hints only.
    // Recommendations still come exclusively from the user's library.
    final knownAdultAnimation = _containsAny(
      _normalize(media.title),
      const [
        'south park',
        'rick and morty',
        'family guy',
        'american dad',
        'the simpsons',
        'futurama',
        'bojack horseman',
        'archer',
      ],
    );

    return (isAnimation && isAdult) || knownAdultAnimation;
  }

  static bool _containsAny(
    String value,
    List<String> terms,
  ) {
    return terms.any(value.contains);
  }
}

/// Determines the seasonal collection that fits the current calendar month.
class SeasonalCollectionEngine {
  static String titleFor(DateTime date) {
    switch (date.month) {
      case 1:
        return 'New Year & Winter';
      case 2:
        return 'Valentine’s Day';
      case 3:
      case 4:
        return 'Spring Stories';
      case 5:
        return 'Family & Friendship';
      case 6:
      case 7:
        return 'Summer Nights';
      case 8:
        return 'Back to School';
      case 9:
        return 'Fall Favorites';
      case 10:
        return 'Halloween';
      case 11:
        return 'Thanksgiving & Gratitude';
      case 12:
        return 'Christmas & Holiday';
      default:
        return 'Seasonal Favorites';
    }
  }

  static List<String> _termsForMonth(int month) => switch (month) {
        1 => const [
            'winter',
            'new year',
            'snow',
            'holiday',
          ],
        2 => const [
            'valentine',
            'love',
            'romance',
            'romantic',
          ],
        3 || 4 => const [
            'spring',
            'family',
            'friendship',
          ],
        5 => const [
            'family',
            'friendship',
          ],
        6 || 7 => const [
            'summer',
            'vacation',
            'beach',
            'night',
          ],
        8 => const [
            'school',
            'teacher',
            'college',
          ],
        9 => const [
            'fall',
            'autumn',
          ],
        10 => const [
            'halloween',
            'horror',
            'spooky',
            'ghost',
            'monster',
          ],
        11 => const [
            'thanksgiving',
            'family',
            'gratitude',
            'fall',
          ],
        12 => const [
            'christmas',
            'holiday',
            'winter',
            'santa',
          ],
        _ => const <String>[],
      };

  static List<MediaItem> matching(
    Iterable<MediaItem> library, {
    DateTime? date,
  }) {
    final terms = _termsForMonth(
      (date ?? DateTime.now()).month,
    );

    if (terms.isEmpty) {
      return <MediaItem>[];
    }

    final matches = library.where((media) {
      final text = _mediaSeasonalText(media);
      return terms.any(text.contains);
    }).toList();

    // Newest imported metadata is surfaced first.
    matches.sort(
      (a, b) => b.addedAt.compareTo(a.addedAt),
    );

    return matches;
  }

  /// Finds seasonal songs already imported into the account music library.
  ///
  /// Songs are dynamically included in the current seasonal collection
  /// without copying or moving the underlying audio file.
  static List<MusicTrack> matchingSongs(
    Iterable<MusicTrack> tracks, {
    DateTime? date,
  }) {
    final terms = _termsForMonth(
      (date ?? DateTime.now()).month,
    );

    if (terms.isEmpty) {
      return <MusicTrack>[];
    }

    final matches = tracks.where((track) {
      final text =
          '${track.title} '
          '${track.artist} '
          '${track.album} '
          '${track.genres.join(' ')} '
          '${track.subgenres.join(' ')}'
              .toLowerCase();

      return terms.any(text.contains);
    }).toList();

    return matches;
  }

  static String _mediaSeasonalText(MediaItem media) {
    return '${media.title} '
            '${media.description ?? ''} '
            '${media.genres.join(' ')} '
            '${media.tags.join(' ')} '
            '${media.franchiseName ?? ''}'
        .toLowerCase();
  }
}

/// Reusable recommendation section for a media Details page.
class DetailsRecommendationsSection extends StatelessWidget {
  final MediaItem source;
  final ValueChanged<MediaItem>? onOpen;

  const DetailsRecommendationsSection({
    super.key,
    required this.source,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final results = MediaRecommendationEngine.forMedia(
      source,
      AppController.instance.library,
    );

    if (results.isEmpty) {
      return _emptyCard(
        icon: Icons.auto_awesome_outlined,
        title: tr('Recommendations'),
        message: tr(
          'Recommendations will become more specific as your server imports '
          'genres, cast, tags and other metadata.',
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const UniversalText(
          'RECOMMENDED FOR YOU',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.3,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 10),
        for (final item in results)
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 4,
              ),
              leading: _poster(item.media),
              title: Text(
                item.media.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                item.reason,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
              ),
              onTap: onOpen == null
                  ? null
                  : () => onOpen!(item.media),
            ),
          ),
      ],
    );
  }

  Widget _poster(MediaItem media) {
    final url = media.imageUrl?.trim();

    if (url == null || url.isEmpty) {
      return Container(
        width: 48,
        height: 68,
        decoration: BoxDecoration(
          color: const Color(0xFF171717),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: Colors.white12,
          ),
        ),
        child: const Icon(
          Icons.movie_outlined,
          color: Colors.white38,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: Image.network(
        url,
        width: 48,
        height: 68,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox(
          width: 48,
          height: 68,
          child: Icon(
            Icons.movie_outlined,
          ),
        ),
      ),
    );
  }

  Widget _emptyCard({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 30,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen seasonal collection browser.
class SeasonalCollectionsScreen extends StatelessWidget {
  const SeasonalCollectionsScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    final title = SeasonalCollectionEngine.titleFor(now);

    final matches = SeasonalCollectionEngine.matching(
      AppController.instance.library,
      date: now,
    );

    final songs = SeasonalCollectionEngine.matchingSongs(
      MusicLibraryStore.instance.tracks,
      date: now,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    size: 34,
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: UniversalText(
                      'This is a dynamic seasonal collection. Matching '
                      'movies, TV episodes/shows and songs are automatically '
                      'included when they exist in your account library.',
                      style: TextStyle(
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (matches.isEmpty && songs.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.auto_awesome_outlined,
                      size: 42,
                      color: Colors.white38,
                    ),
                    SizedBox(height: 10),
                    UniversalText(
                      'No matching media yet',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 5),
                    UniversalText(
                      'Matching movies, TV episodes/shows and songs will '
                      'appear automatically when they are imported into '
                      'your library.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (matches.isNotEmpty) ...[
            const UniversalText(
              'MOVIES & TV',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.3,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 8),
            for (final media in matches)
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.movie_filter_outlined,
                  ),
                  title: Text(media.title),
                  subtitle: Text(
                    [
                      media.type,
                      if (media.releaseYear != null)
                        '${media.releaseYear}',
                      ...media.genres.take(2),
                    ].join(' • '),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MediaDetailsScreen(
                          media: media,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],

          if (songs.isNotEmpty) ...[
            const SizedBox(height: 14),
            const UniversalText(
              'SONGS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.3,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 8),
            for (final track in songs)
              Card(
                child: ListTile(
                  leading: track.artworkUrl == null
                      ? const Icon(
                          Icons.music_note_rounded,
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: Image.network(
                            track.artworkUrl!,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(
                              Icons.music_note_rounded,
                            ),
                          ),
                        ),
                  title: Text(track.title),
                  subtitle: Text(
                    '${track.artist} • ${track.album}',
                  ),
                  trailing: const Icon(
                    Icons.play_arrow_rounded,
                  ),
                  onTap: () {
                    MusicPlaybackController.instance.play(track);
                  },
                ),
              ),
          ],
        ],
      ),
    );
  }
}