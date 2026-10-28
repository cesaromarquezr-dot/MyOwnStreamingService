// FILE: lib/multiverse_hub.dart
// Purpose: Multiverse, alternate-reality, and branched-timeline catalog hub.
// Reality labels include an evidence/canon note so comics numbering, on-screen
// designations, fan-curated umbrella names, and story locations are not conflated.

import 'package:flutter/material.dart';

import 'app_core.dart';
import 'details.dart';
import 'home_arrow_rail.dart';
import 'home_hero_hover_preview.dart';

const Color _multiverseAccent = Color(0xFF8B7CFF);
const Color _multiversePanel = Color(0xFF171722);

class MultiverseTitleReference {
  final String title;
  final String mediaType;
  final List<String> aliases;

  const MultiverseTitleReference({
    required this.title,
    required this.mediaType,
    this.aliases = const <String>[],
  });
}

class MultiverseRealityRecord {
  final String id;
  final String name;
  final String designation;
  final String designationKind;
  final String summary;
  final String evidenceNote;
  final List<String> aliases;
  final List<MultiverseTitleReference> titleReferences;

  const MultiverseRealityRecord({
    required this.id,
    required this.name,
    required this.designation,
    required this.designationKind,
    required this.summary,
    required this.evidenceNote,
    this.aliases = const <String>[],
    this.titleReferences = const <MultiverseTitleReference>[],
  });
}

class MultiverseConceptRecord {
  final String name;
  final String summary;
  final String canonNote;
  final List<MultiverseTitleReference> titleReferences;

  const MultiverseConceptRecord({
    required this.name,
    required this.summary,
    required this.canonNote,
    this.titleReferences = const <MultiverseTitleReference>[],
  });
}

class MultiverseDefinition {
  final String id;
  final String name;
  final String label;
  final String description;
  final String classificationNote;
  final List<String> metadataMembershipAliases;
  final List<MultiverseRealityRecord> realities;
  final List<MultiverseConceptRecord> concepts;

  const MultiverseDefinition({
    required this.id,
    required this.name,
    required this.label,
    required this.description,
    required this.classificationNote,
    required this.metadataMembershipAliases,
    required this.realities,
    required this.concepts,
  });
}

class MultiverseCatalogLogic {
  MultiverseCatalogLogic._();

  static const List<MultiverseDefinition> featured = <MultiverseDefinition>[
    MultiverseDefinition(
      id: 'marvel-cinematic-multiverse',
      name: 'Marvel Cinematic Multiverse',
      label: 'MCM • fan-curated umbrella',
      description:
          'A discovery index for the MCU’s alternate realities, timelines, and related Marvel film continuities. Use reality-level links to keep separate continuities distinct.',
      classificationNote:
          '“MCM” is not an official Marvel Studios franchise label. Earth numbers can come from on-screen dialogue or from Marvel Comics reference material; this hub records which kind of label is being used. A crossover alone does not make every title part of one single continuity.',
      metadataMembershipAliases: <String>[
        'marvel cinematic multiverse',
        'marvel cinematic universe',
        'mcu',
        'mcm',
      ],
      realities: <MultiverseRealityRecord>[
        MultiverseRealityRecord(
          id: 'marvel-earth-616',
          name: 'Primary MCU Reality',
          designation: 'Earth-616',
          designationKind: 'On-screen designation',
          summary:
              'The primary continuity used for the mainline Marvel Cinematic Universe stories. Doctor Strange in the Multiverse of Madness identifies this reality as Earth-616.',
          evidenceNote:
              'Earth-199999 is a legacy designation found in older Marvel Comics handbook/reference material for the MCU; it is listed here as a historical alias, not as a second owned reality.',
          aliases: <String>['Earth 616', 'Earth-199999', 'Earth 199999'],
          titleReferences: <MultiverseTitleReference>[
            MultiverseTitleReference(title: 'Iron Man', mediaType: 'Movie'),
            MultiverseTitleReference(title: 'The Avengers', mediaType: 'Movie', aliases: <String>['Marvel’s The Avengers']),
            MultiverseTitleReference(title: 'Avengers: Endgame', mediaType: 'Movie'),
            MultiverseTitleReference(title: 'Spider-Man: No Way Home', mediaType: 'Movie'),
            MultiverseTitleReference(title: 'Doctor Strange in the Multiverse of Madness', mediaType: 'Movie', aliases: <String>['Doctor Strange 2', 'Doctor Strange in the Multiverse of Madness']),
          ],
        ),
        MultiverseRealityRecord(
          id: 'marvel-earth-838',
          name: 'Illuminati Reality',
          designation: 'Earth-838',
          designationKind: 'On-screen designation',
          summary:
              'The alternate reality featuring the Illuminati encountered by Doctor Strange during Doctor Strange in the Multiverse of Madness.',
          evidenceNote:
              'Directly identified in the film. The title reference is connected to this reality, but the entire movie is not exclusively set there.',
          aliases: <String>['Earth 838', 'Illuminati universe'],
          titleReferences: <MultiverseTitleReference>[
            MultiverseTitleReference(title: 'Doctor Strange in the Multiverse of Madness', mediaType: 'Movie', aliases: <String>['Doctor Strange 2']),
          ],
        ),
        MultiverseRealityRecord(
          id: 'marvel-earth-828',
          name: 'Fantastic Four: First Steps Reality',
          designation: 'Earth-828',
          designationKind: 'Officially identified reality',
          summary:
              'The retro-futuristic 1960s-inspired reality where the Fantastic Four live in The Fantastic Four: First Steps.',
          evidenceNote:
              'Marvel Studios’ Kevin Feige described the film’s setting as Earth-828 in Marvel’s official coverage. Keep it distinct from Earth-616 in the catalog.',
          aliases: <String>['Earth 828', 'Fantastic Four First Steps universe'],
          titleReferences: <MultiverseTitleReference>[
            MultiverseTitleReference(title: 'The Fantastic Four: First Steps', mediaType: 'Movie', aliases: <String>['Fantastic Four First Steps', 'The Fantastic Four First Steps']),
          ],
        ),
        MultiverseRealityRecord(
          id: 'marvel-earth-10005',
          name: 'X-Men / Deadpool Film Continuity',
          designation: 'Earth-10005',
          designationKind: 'Marvel Comics multiverse reference label',
          summary:
              'The film continuity associated with Fox’s X-Men movies and Deadpool. Deadpool & Wolverine uses cross-reality travel to connect this continuity to other Marvel stories.',
          evidenceNote:
              'Earth-10005 appears in Marvel Comics multiverse reference material as the X-Men movie universe designation. Keep it tagged as a reference label rather than claiming every title says this number onscreen.',
          aliases: <String>['Earth 10005', 'Fox X-Men universe', 'X-Men film universe'],
          titleReferences: <MultiverseTitleReference>[
            MultiverseTitleReference(title: 'X-Men', mediaType: 'Movie'),
            MultiverseTitleReference(title: 'X2', mediaType: 'Movie', aliases: <String>['X2: X-Men United']),
            MultiverseTitleReference(title: 'X-Men: Days of Future Past', mediaType: 'Movie'),
            MultiverseTitleReference(title: 'Logan', mediaType: 'Movie'),
            MultiverseTitleReference(title: 'Deadpool', mediaType: 'Movie'),
            MultiverseTitleReference(title: 'Deadpool 2', mediaType: 'Movie'),
            MultiverseTitleReference(title: 'Deadpool & Wolverine', mediaType: 'Movie', aliases: <String>['Deadpool and Wolverine']),
          ],
        ),
        MultiverseRealityRecord(
          id: 'marvel-earth-96283',
          name: 'Sam Raimi Spider-Man Film Continuity',
          designation: 'Earth-96283',
          designationKind: 'Marvel Comics multiverse reference label',
          summary:
              'The continuity of Sam Raimi’s Spider-Man trilogy, featuring Tobey Maguire as Peter Parker. Spider-Man: No Way Home brings this version of Peter into a crossover story.',
          evidenceNote:
              'Marvel multiverse reference material assigns Earth-96283 to the Raimi Spider-Man movies. This is not the Void from Deadpool & Wolverine.',
          aliases: <String>['Earth 96283', 'Raimi Spider-Man universe', 'Tobey Maguire Spider-Man universe'],
          titleReferences: <MultiverseTitleReference>[
            MultiverseTitleReference(title: 'Spider-Man', mediaType: 'Movie', aliases: <String>['Spider-Man (2002)']),
            MultiverseTitleReference(title: 'Spider-Man 2', mediaType: 'Movie'),
            MultiverseTitleReference(title: 'Spider-Man 3', mediaType: 'Movie'),
            MultiverseTitleReference(title: 'Spider-Man: No Way Home', mediaType: 'Movie'),
          ],
        ),
        MultiverseRealityRecord(
          id: 'marvel-what-if-branches',
          name: 'What If...? Alternate Branches',
          designation: 'Multiple alternate timelines',
          designationKind: 'Branching timeline set • no single Earth number',
          summary:
              'Animated alternate stories that explore choices and events playing out differently. Each episode may focus on a different branch; the set should not be flattened into one single reality.',
          evidenceNote:
              'Catalog by episode or season where metadata supports it. If an Earth number is missing or disputed, leave it unknown instead of guessing.',
          aliases: <String>['What If alternate timeline', 'What If branch', 'alternate MCU timeline'],
          titleReferences: <MultiverseTitleReference>[
            MultiverseTitleReference(title: 'What If...?', mediaType: 'TV Show', aliases: <String>['What If', 'Marvel’s What If']),
          ],
        ),
        MultiverseRealityRecord(
          id: 'marvel-the-void',
          name: 'The Void',
          designation: 'No Earth number assigned here',
          designationKind: 'Story location / TVA dumping ground',
          summary:
              'A place at the end of time associated with TVA-pruned people and timelines in Loki and Deadpool & Wolverine.',
          evidenceNote:
              'The Void is a location, not Earth-96283. Do not assign it the Raimi Spider-Man universe number.',
          aliases: <String>['Void at the end of time', 'TVA Void', 'pruned timeline void'],
          titleReferences: <MultiverseTitleReference>[
            MultiverseTitleReference(title: 'Loki', mediaType: 'TV Show'),
            MultiverseTitleReference(title: 'Deadpool & Wolverine', mediaType: 'Movie', aliases: <String>['Deadpool and Wolverine']),
          ],
        ),
      ],
      concepts: <MultiverseConceptRecord>[
        MultiverseConceptRecord(
          name: 'Sacred Timeline',
          summary:
              'The TVA’s controlled timeline arrangement introduced in Loki. Store this as a timeline concept, not as another Earth number.',
          canonNote: 'TVA / Loki story terminology; do not use as a synonym for every version of Earth-616.',
          titleReferences: <MultiverseTitleReference>[
            MultiverseTitleReference(title: 'Loki', mediaType: 'TV Show'),
          ],
        ),
        MultiverseConceptRecord(
          name: 'Branching timelines and nexus events',
          summary:
              'Divergences can produce alternate branches. The app can model each branch separately when the catalog has enough identifiers.',
          canonNote: 'Story mechanics shown in Loki and Avengers: Endgame; the catalog should retain episode/event source notes when importing a branch.',
          titleReferences: <MultiverseTitleReference>[
            MultiverseTitleReference(title: 'Loki', mediaType: 'TV Show'),
            MultiverseTitleReference(title: 'Avengers: Endgame', mediaType: 'Movie'),
          ],
        ),
        MultiverseConceptRecord(
          name: 'TVA and pruning',
          summary:
              'The Time Variance Authority monitors timeline variations; pruning is shown as its method of removing targeted branches/variants in the story.',
          canonNote: 'Loki-specific narrative rules; do not generalize them as universal rules for every multiverse outside this continuity.',
          titleReferences: <MultiverseTitleReference>[
            MultiverseTitleReference(title: 'Loki', mediaType: 'TV Show'),
            MultiverseTitleReference(title: 'Deadpool & Wolverine', mediaType: 'Movie', aliases: <String>['Deadpool and Wolverine']),
          ],
        ),
        MultiverseConceptRecord(
          name: 'Incursions',
          summary:
              'A collision between realities that can threaten or destroy the affected universes, as described in Doctor Strange in the Multiverse of Madness.',
          canonNote: 'Film-defined multiverse mechanic; keep source and continuity on the imported metadata record.',
          titleReferences: <MultiverseTitleReference>[
            MultiverseTitleReference(title: 'Doctor Strange in the Multiverse of Madness', mediaType: 'Movie', aliases: <String>['Doctor Strange 2']),
            MultiverseTitleReference(title: 'The Marvels', mediaType: 'Movie'),
          ],
        ),
        MultiverseConceptRecord(
          name: 'Anchor beings',
          summary:
              'A concept introduced in Deadpool & Wolverine for a person whose importance is tied to a reality’s continued existence in that story.',
          canonNote: 'Treat as a specific story rule unless further titles explicitly confirm a broader rule.',
          titleReferences: <MultiverseTitleReference>[
            MultiverseTitleReference(title: 'Deadpool & Wolverine', mediaType: 'Movie', aliases: <String>['Deadpool and Wolverine']),
          ],
        ),
      ],
    ),
    MultiverseDefinition(
      id: 'spider-verse-animated-cluster',
      name: 'Spider-Verse • Animated Realities',
      label: 'Animated reality cluster',
      description:
          'An index for the animated Spider-Verse films and their parallel realities. Crossovers are tracked as explicit relationships, not as proof that all Spider-Man movies share one continuity.',
      classificationNote:
          'Reality IDs and aliases should be sourced from the relevant film or trusted catalog entry. Live-action Spider-Man continuities are shown separately where identified.',
      metadataMembershipAliases: <String>[
        'spider verse',
        'spider-verse',
        'spider-man into the spider-verse',
        'spider-man across the spider-verse',
      ],
      realities: <MultiverseRealityRecord>[
        MultiverseRealityRecord(
          id: 'spider-verse-earth-1610b',
          name: 'Miles Morales’ Home Reality',
          designation: 'Earth-1610B',
          designationKind: 'Film continuity designation',
          summary: 'The animated Spider-Verse reality primarily followed in Miles Morales’ story.',
          evidenceNote: 'Use the identifier exactly as supplied by the film/catalog metadata; do not normalize the suffix away.',
          aliases: <String>['Earth 1610B', 'Miles Morales universe', 'Miles Morales home universe'],
          titleReferences: <MultiverseTitleReference>[
            MultiverseTitleReference(title: 'Spider-Man: Into the Spider-Verse', mediaType: 'Movie'),
            MultiverseTitleReference(title: 'Spider-Man: Across the Spider-Verse', mediaType: 'Movie'),
          ],
        ),
        MultiverseRealityRecord(
          id: 'spider-verse-earth-42',
          name: 'Earth-42',
          designation: 'Earth-42',
          designationKind: 'Film continuity designation',
          summary: 'An alternate reality featured in Spider-Man: Across the Spider-Verse.',
          evidenceNote: 'Keep Earth-42 separate from Earth-1610B; do not merge based on similar characters or shared branding.',
          aliases: <String>['Earth 42', 'alternate Miles reality'],
          titleReferences: <MultiverseTitleReference>[
            MultiverseTitleReference(title: 'Spider-Man: Across the Spider-Verse', mediaType: 'Movie'),
          ],
        ),
        MultiverseRealityRecord(
          id: 'spider-verse-earth-65',
          name: 'Gwen Stacy Reality',
          designation: 'Earth-65',
          designationKind: 'Reality identifier used by Spider-Gwen continuity references',
          summary: 'Associated with Gwen Stacy / Spider-Woman. The identifier and title connections should be checked against the active catalog source.',
          evidenceNote: 'Source the designation from imported franchise metadata; do not assume every detail from comics is identical to the animated-film continuity.',
          aliases: <String>['Earth 65', 'Gwen Stacy universe', 'Spider-Gwen universe'],
          titleReferences: <MultiverseTitleReference>[
            MultiverseTitleReference(title: 'Spider-Man: Across the Spider-Verse', mediaType: 'Movie'),
          ],
        ),
      ],
      concepts: <MultiverseConceptRecord>[
        MultiverseConceptRecord(
          name: 'Spider-Society',
          summary: 'A group of spider-powered heroes connected across realities in Across the Spider-Verse.',
          canonNote: 'Use the film’s own terminology and avoid assigning an Earth number to the organization itself.',
          titleReferences: <MultiverseTitleReference>[
            MultiverseTitleReference(title: 'Spider-Man: Across the Spider-Verse', mediaType: 'Movie'),
          ],
        ),
      ],
    ),
    MultiverseDefinition(
      id: 'dc-multiverse-continuity-index',
      name: 'DC Multiverse • Continuity Index',
      label: 'Separate continuity index',
      description:
          'A discovery index for distinct DC live-action continuities, including the DCEU run. It avoids inventing Earth numbers where the selected source does not identify one.',
      classificationNote:
          'The DCEU (2013–2023), The Batman, and Joker films are not automatically one continuity. Add numeric reality designations only when a reliable source explicitly supplies them.',
      metadataMembershipAliases: <String>[
        'dc multiverse',
        'dc extended universe',
        'dceu',
      ],
      realities: <MultiverseRealityRecord>[
        MultiverseRealityRecord(
          id: 'dc-dceu-2013-2023',
          name: 'DC Extended Universe',
          designation: 'DCEU • 2013–2023',
          designationKind: 'Franchise continuity label • no Earth number assigned here',
          summary: 'The live-action film continuity beginning with Man of Steel and ending with Aquaman and the Lost Kingdom, with related films and the Peacemaker series.',
          evidenceNote: 'A curated continuity label, not a numeric Earth designation. Confirm borderline TV or crossover relationships in imported metadata.',
          aliases: <String>['DCEU', 'DC Extended Universe', 'DC Films shared universe'],
          titleReferences: <MultiverseTitleReference>[
            MultiverseTitleReference(title: 'Man of Steel', mediaType: 'Movie'),
            MultiverseTitleReference(title: 'Batman v Superman: Dawn of Justice', mediaType: 'Movie', aliases: <String>['Batman vs Superman']),
            MultiverseTitleReference(title: 'Wonder Woman', mediaType: 'Movie'),
            MultiverseTitleReference(title: 'Justice League', mediaType: 'Movie'),
            MultiverseTitleReference(title: 'Aquaman', mediaType: 'Movie'),
            MultiverseTitleReference(title: 'The Flash', mediaType: 'Movie'),
            MultiverseTitleReference(title: 'Blue Beetle', mediaType: 'Movie'),
            MultiverseTitleReference(title: 'Aquaman and the Lost Kingdom', mediaType: 'Movie'),
            MultiverseTitleReference(title: 'Peacemaker', mediaType: 'TV Show'),
          ],
        ),
        MultiverseRealityRecord(
          id: 'dc-the-batman-continuity',
          name: 'The Batman Continuity',
          designation: 'Standalone continuity label',
          designationKind: 'Continuity label • no Earth number assigned here',
          summary: 'The world of The Batman (2022) and its directly connected stories; not the DCEU continuity by default.',
          evidenceNote: 'Keep this distinct unless a trusted catalog source confirms a crossover or shared continuity.',
          aliases: <String>['The Batman universe', 'Matt Reeves Batman universe'],
          titleReferences: <MultiverseTitleReference>[
            MultiverseTitleReference(title: 'The Batman', mediaType: 'Movie'),
          ],
        ),
        MultiverseRealityRecord(
          id: 'dc-joker-continuity',
          name: 'Joker Continuity',
          designation: 'Standalone continuity label',
          designationKind: 'Continuity label • no Earth number assigned here',
          summary: 'The Joker film continuity, tracked separately from the DCEU and The Batman continuity.',
          evidenceNote: 'Continuity grouping for discovery only; no numeric designation is asserted here.',
          aliases: <String>['Joker universe', 'Todd Phillips Joker universe'],
          titleReferences: <MultiverseTitleReference>[
            MultiverseTitleReference(title: 'Joker', mediaType: 'Movie'),
            MultiverseTitleReference(title: 'Joker: Folie à Deux', mediaType: 'Movie', aliases: <String>['Joker Folie a Deux']),
          ],
        ),
      ],
      concepts: <MultiverseConceptRecord>[
        MultiverseConceptRecord(
          name: 'Continuity is not the same as a franchise brand',
          summary: 'A shared character or publisher does not automatically mean that two films take place in the same continuity.',
          canonNote: 'General catalog data-quality rule. Track crossovers as explicit relationships.',
        ),
      ],
    ),
  ];

  static String normalize(String value) => value
      .toLowerCase()
      .replaceAll('&', ' and ')
      .replaceAll(RegExp(r"[^a-z0-9]+"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static bool _isMovieType(String type) {
    final lower = type.toLowerCase();
    return lower.contains('movie') || lower.contains('film');
  }

  static bool _isShowType(String type) {
    final lower = type.toLowerCase();
    return lower.contains('tv') || lower.contains('show') || lower.contains('series') || lower.contains('episode');
  }

  static bool _typeMatches(String expected, String actual) {
    final e = normalize(expected);
    final a = normalize(actual);
    if (_isMovieType(expected)) return _isMovieType(actual);
    if (_isShowType(expected)) return _isShowType(actual);
    return e == a || e.isEmpty;
  }

  static List<MediaItem> ownedTitlesForReality(
    Iterable<MediaItem> source,
    MultiverseRealityRecord reality,
  ) {
    final references = reality.titleReferences;
    return source.where((item) {
      final actualType = item.type;
      final candidateNames = <String>{
        normalize(item.title),
        normalize(item.originalTitle ?? ''),
        normalize(item.canonicalTitle ?? ''),
      }..remove('');
      for (final reference in references) {
        if (!_typeMatches(reference.mediaType, actualType)) continue;
        final expected = <String>{
          normalize(reference.title),
          ...reference.aliases.map(normalize),
        }..remove('');
        if (candidateNames.any(expected.contains)) return true;
      }
      final membershipNames = <String>{
        normalize(item.continuityName ?? ''),
        normalize(item.continuityId ?? ''),
        normalize(item.cinematicUniverseSaga ?? ''),
        ...item.cinematicUniverseNames.map(normalize),
        ...item.cinematicUniverseIds.map(normalize),
      };
      for (final membership in item.universeMemberships) {
        for (final key in const <String>[
          'name', 'universeName', 'universe_name', 'continuityName',
          'continuity_name', 'realityName', 'reality_name', 'designation',
          'earth', 'earthNumber', 'earth_number', 'realityId', 'reality_id',
          'timelineName', 'timeline_name', 'branchName', 'branch_name',
          'id', 'universeId', 'universe_id',
        ]) {
          final value = membership[key]?.toString();
          if (value != null && value.trim().isNotEmpty) {
            membershipNames.add(normalize(value));
          }
        }
      }
      final realityAliases = <String>{
        normalize(reality.id),
        normalize(reality.name),
        normalize(reality.designation),
        ...reality.aliases.map(normalize),
      }..remove('');
      return membershipNames.any((name) => realityAliases.contains(name));
    }).toList(growable: false);
  }

  static List<MediaItem> ownedTitlesForConcept(
    Iterable<MediaItem> source,
    MultiverseConceptRecord concept,
  ) {
    final all = source.toList(growable: false);
    final result = <String, MediaItem>{};
    for (final reference in concept.titleReferences) {
      final names = <String>{normalize(reference.title), ...reference.aliases.map(normalize)};
      for (final item in all) {
        if (!_typeMatches(reference.mediaType, item.type)) continue;
        final titles = <String>{
          normalize(item.title),
          normalize(item.originalTitle ?? ''),
          normalize(item.canonicalTitle ?? ''),
        }..remove('');
        if (titles.any(names.contains)) result[item.id] = item;
      }
    }
    return result.values.toList(growable: false);
  }

  static List<MediaItem> ownedTitlesForMultiverse(
    Iterable<MediaItem> source,
    MultiverseDefinition definition,
  ) {
    final sourceItems = source.toList(growable: false);
    final result = <String, MediaItem>{};
    final refs = <MultiverseTitleReference>[
      for (final reality in definition.realities) ...reality.titleReferences,
      for (final concept in definition.concepts) ...concept.titleReferences,
    ];
    for (final reference in refs) {
      final names = <String>{normalize(reference.title), ...reference.aliases.map(normalize)};
      for (final item in sourceItems) {
        if (!_typeMatches(reference.mediaType, item.type)) continue;
        final titles = <String>{
          normalize(item.title),
          normalize(item.originalTitle ?? ''),
          normalize(item.canonicalTitle ?? ''),
        }..remove('');
        if (titles.any(names.contains)) result[item.id] = item;
      }
    }
    final membershipAliases = definition.metadataMembershipAliases.map(normalize).toSet();
    for (final item in sourceItems) {
      final memberships = <String>{
        normalize(item.continuityName ?? ''),
        normalize(item.continuityId ?? ''),
        normalize(item.cinematicUniverseSaga ?? ''),
        ...item.cinematicUniverseNames.map(normalize),
        ...item.cinematicUniverseIds.map(normalize),
      }..remove('');
      for (final entry in item.universeMemberships) {
        for (final key in const <String>[
          'name', 'universeName', 'universe_name', 'multiverseName',
          'multiverse_name', 'continuityName', 'continuity_name',
          'timelineName', 'timeline_name', 'branchName', 'branch_name',
        ]) {
          final value = entry[key]?.toString();
          if (value != null && value.trim().isNotEmpty) memberships.add(normalize(value));
        }
      }
      if (memberships.any((membership) => membershipAliases.any((alias) => membership == alias || membership.contains(alias)))) {
        result[item.id] = item;
      }
    }
    return result.values.toList(growable: false);
  }

  static int get exampleTitleCount => featured.fold<int>(0, (sum, definition) {
    final titles = <String>{};
    for (final reality in definition.realities) {
      titles.addAll(reality.titleReferences.map((entry) => '${normalize(entry.mediaType)}:${normalize(entry.title)}'));
    }
    for (final concept in definition.concepts) {
      titles.addAll(concept.titleReferences.map((entry) => '${normalize(entry.mediaType)}:${normalize(entry.title)}'));
    }
    return sum + titles.length;
  });
}

class MultiverseHubHomeShelf extends StatelessWidget {
  final List<MediaItem> library;
  final VoidCallback onViewAll;

  const MultiverseHubHomeShelf({
    super.key,
    required this.library,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final definitions = MultiverseCatalogLogic.featured;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Multiverse & Timelines Hub', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                    SizedBox(height: 3),
                    Text('Alternate realities, branch timelines, and continuity connections', style: TextStyle(fontSize: 11, color: Colors.white54)),
                  ],
                ),
              ),
              TextButton(onPressed: onViewAll, child: const Text('View all')),
            ],
          ),
        ),
        HomeArrowRail(
          height: 177,
          itemCount: definitions.length,
          separatorExtent: 10,
          padding: const EdgeInsets.symmetric(horizontal: 48),
          itemBuilder: (context, index) {
            final definition = definitions[index];
            final linkedTitles = MultiverseCatalogLogic.ownedTitlesForMultiverse(library, definition);
            final previewMedia = MediaItem(
              id: 'home-multiverse-${definition.id}',
              title: definition.name,
              type: 'multiverse and timeline hub',
              imageUrl: linkedTitles.isEmpty ? null : linkedTitles.first.imageUrl,
              description: '${definition.description} • ${definition.label} • ${linkedTitles.length} linked titles in your library',
              genres: <String>['Multiverse', 'Timeline', definition.label],
            );
            return HomeHeroHoverPreviewRegion(
              media: previewMedia,
              child: SizedBox(
              width: 310,
              child: Material(
                color: _multiversePanel,
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    settings: RouteSettings(name: '/app/multiverse/${definition.id}'),
                    builder: (_) => MultiverseDetailScreen(definition: definition, library: library),
                  )),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.hub_rounded, color: _multiverseAccent, size: 19),
                          const SizedBox(width: 7),
                          Expanded(child: Text(definition.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14))),
                          const Icon(Icons.chevron_right_rounded, color: Colors.white54),
                        ]),
                        const SizedBox(height: 5),
                        Text(definition.label.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, letterSpacing: .3, fontWeight: FontWeight.w800, color: Color(0xFFB4A8FF))),
                        const SizedBox(height: 9),
                        Text('${definition.realities.length} realities / continuity records', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text('${definition.concepts.length} timeline concepts', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                        const Spacer(),
                        Text('${linkedTitles.length} linked titles in your library', style: const TextStyle(color: Color(0xFF9DE5B0), fontSize: 11, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
              ),
            ));
          },
        ),
      ],
    );
  }
}

class MultiverseHubScreen extends StatelessWidget {
  final List<MediaItem> library;

  const MultiverseHubScreen({super.key, required this.library});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF0B0B10),
        appBar: AppBar(backgroundColor: const Color(0xFF0B0B10), title: const Text('Multiverse & Timelines Hub')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            const _MultiverseNotice(
              icon: Icons.info_outline_rounded,
              text: 'Reality designations can come from on-screen dialogue, official studio material, or comics reference books. The source type is shown on each record. Fan labels and missing Earth numbers are identified instead of being treated as confirmed canon.',
            ),
            const SizedBox(height: 12),
            for (final definition in MultiverseCatalogLogic.featured)
              _MultiverseOverviewCard(definition: definition, library: library),
          ],
        ),
      );
}

class _MultiverseOverviewCard extends StatelessWidget {
  final MultiverseDefinition definition;
  final List<MediaItem> library;
  const _MultiverseOverviewCard({required this.definition, required this.library});

  @override
  Widget build(BuildContext context) {
    final linked = MultiverseCatalogLogic.ownedTitlesForMultiverse(library, definition);
    return Card(
      color: _multiversePanel,
      margin: const EdgeInsets.only(bottom: 11),
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          settings: RouteSettings(name: '/app/multiverse/${definition.id}'),
          builder: (_) => MultiverseDetailScreen(definition: definition, library: library),
        )),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.hub_rounded, color: _multiverseAccent),
              const SizedBox(width: 9),
              Expanded(child: Text(definition.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
              const Icon(Icons.chevron_right_rounded, color: Colors.white54),
            ]),
            const SizedBox(height: 5),
            Text(definition.label, style: const TextStyle(color: Color(0xFFB4A8FF), fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(definition.description, style: const TextStyle(color: Colors.white70, height: 1.35, fontSize: 12)),
            const SizedBox(height: 10),
            Row(children: [
              _MultiverseMetric(label: 'Reality records', value: '${definition.realities.length}'),
              const SizedBox(width: 8),
              _MultiverseMetric(label: 'Timeline concepts', value: '${definition.concepts.length}'),
              const SizedBox(width: 8),
              _MultiverseMetric(label: 'Linked titles', value: '${linked.length}'),
            ]),
          ]),
        ),
      ),
    );
  }
}

class MultiverseDetailScreen extends StatelessWidget {
  final MultiverseDefinition definition;
  final List<MediaItem> library;

  const MultiverseDetailScreen({super.key, required this.definition, required this.library});

  @override
  Widget build(BuildContext context) {
    final linked = MultiverseCatalogLogic.ownedTitlesForMultiverse(library, definition);
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B10),
      appBar: AppBar(backgroundColor: const Color(0xFF0B0B10), title: Text(definition.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        children: [
          Container(
            decoration: BoxDecoration(color: _multiversePanel, borderRadius: BorderRadius.circular(18)),
            padding: const EdgeInsets.all(17),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(definition.label.toUpperCase(), style: const TextStyle(color: Color(0xFFB4A8FF), fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: .5)),
              const SizedBox(height: 8),
              Text(definition.description, style: const TextStyle(height: 1.4, color: Colors.white70)),
              const SizedBox(height: 10),
              Text('${definition.realities.length} reality/continuity records · ${definition.concepts.length} timeline concepts · ${linked.length} linked catalog titles', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              const SizedBox(height: 12),
              Text(definition.classificationNote, style: const TextStyle(color: Colors.white54, fontSize: 11, height: 1.4)),
            ]),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(2, 22, 2, 9),
            child: Text('Realities and continuities', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          ),
          for (final reality in definition.realities)
            _MultiverseRealityTile(reality: reality, library: library),
          const Padding(
            padding: EdgeInsets.fromLTRB(2, 24, 2, 9),
            child: Text('Timeline mechanics and concepts', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          ),
          for (final concept in definition.concepts)
            _MultiverseConceptTile(concept: concept, library: library),
          const Padding(
            padding: EdgeInsets.fromLTRB(2, 23, 2, 9),
            child: Text('Titles linked in your library', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          ),
          if (linked.isEmpty)
            const Text('No matching titles are indexed for this profile yet. Import continuity/reality memberships or add matching titles to populate this list.', style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4))
          else
            for (final media in linked)
              _MultiverseOwnedMediaTile(media: media),
        ],
      ),
    );
  }
}

class _MultiverseRealityTile extends StatelessWidget {
  final MultiverseRealityRecord reality;
  final List<MediaItem> library;
  const _MultiverseRealityTile({required this.reality, required this.library});

  @override
  Widget build(BuildContext context) {
    final owned = MultiverseCatalogLogic.ownedTitlesForReality(library, reality);
    return Card(
      color: _multiversePanel,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          settings: RouteSettings(name: '/app/multiverse/reality/${reality.id}'),
          builder: (_) => MultiverseRealityDetailScreen(reality: reality, library: library),
        )),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.public_rounded, color: _multiverseAccent, size: 21),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(reality.name, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(reality.designation, style: const TextStyle(color: Color(0xFFB4A8FF), fontSize: 11, fontWeight: FontWeight.w700)),
              const SizedBox(height: 5),
              Text(reality.summary, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 11, height: 1.35)),
              const SizedBox(height: 6),
              Text('${owned.length} matched title${owned.length == 1 ? '' : 's'} in your library', style: const TextStyle(color: Color(0xFF9DE5B0), fontSize: 10, fontWeight: FontWeight.w800)),
            ])),
            const Icon(Icons.chevron_right_rounded, color: Colors.white54),
          ]),
        ),
      ),
    );
  }
}

class MultiverseRealityDetailScreen extends StatelessWidget {
  final MultiverseRealityRecord reality;
  final List<MediaItem> library;
  const MultiverseRealityDetailScreen({super.key, required this.reality, required this.library});

  @override
  Widget build(BuildContext context) {
    final owned = MultiverseCatalogLogic.ownedTitlesForReality(library, reality);
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B10),
      appBar: AppBar(backgroundColor: const Color(0xFF0B0B10), title: Text(reality.designation)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 28), children: [
        Container(
          decoration: BoxDecoration(color: _multiversePanel, borderRadius: BorderRadius.circular(18)),
          padding: const EdgeInsets.all(17),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(reality.name, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(reality.designationKind.toUpperCase(), style: const TextStyle(color: Color(0xFFB4A8FF), fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: .4)),
            const SizedBox(height: 10),
            Text(reality.summary, style: const TextStyle(height: 1.4, color: Colors.white70)),
            const SizedBox(height: 10),
            Text(reality.evidenceNote, style: const TextStyle(color: Colors.white54, fontSize: 11, height: 1.4)),
            const SizedBox(height: 10),
            Text('${owned.length} matching title${owned.length == 1 ? '' : 's'} in your library', style: const TextStyle(color: Color(0xFF9DE5B0), fontWeight: FontWeight.w800)),
          ]),
        ),
        const Padding(padding: EdgeInsets.fromLTRB(2, 22, 2, 8), child: Text('Titles you own', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900))),
        if (owned.isEmpty)
          const Text('No exact title matches or imported reality memberships were found for this profile. Reference examples below are not counted as owned.', style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4))
        else
          for (final media in owned) _MultiverseOwnedMediaTile(media: media),
        const Padding(padding: EdgeInsets.fromLTRB(2, 22, 2, 8), child: Text('Reference titles', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900))),
        const Padding(padding: EdgeInsets.only(bottom: 7), child: Text('Illustrative catalog links. These examples are not inserted into your library; a checked title means an existing library item matched.', style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.35))),
        for (final reference in reality.titleReferences)
          Builder(builder: (context) {
            final matches = owned.where((media) {
              final candidateNames = <String>{
                MultiverseCatalogLogic.normalize(media.title),
                MultiverseCatalogLogic.normalize(media.originalTitle ?? ''),
                MultiverseCatalogLogic.normalize(media.canonicalTitle ?? ''),
              }..remove('');
              final expected = <String>{
                MultiverseCatalogLogic.normalize(reference.title),
                ...reference.aliases.map(MultiverseCatalogLogic.normalize),
              }..remove('');
              return candidateNames.any(expected.contains);
            }).toList(growable: false);
            final found = matches.isNotEmpty;
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(found ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: found ? const Color(0xFF9DE5B0) : Colors.white38),
              title: Text(reference.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              subtitle: Text(reference.mediaType, style: const TextStyle(color: Colors.white54, fontSize: 10)),
              trailing: found ? const Icon(Icons.chevron_right_rounded, color: Colors.white54) : null,
              onTap: found ? () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MediaDetailsScreen(media: matches.first))) : null,
            );
          }),
      ]),
    );
  }
}

class _MultiverseConceptTile extends StatelessWidget {
  final MultiverseConceptRecord concept;
  final List<MediaItem> library;
  const _MultiverseConceptTile({required this.concept, required this.library});

  @override
  Widget build(BuildContext context) {
    final owned = MultiverseCatalogLogic.ownedTitlesForConcept(library, concept);
    return Card(
      color: _multiversePanel,
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: const Icon(Icons.timeline_rounded, color: _multiverseAccent),
        title: Text(concept.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        subtitle: Text('${owned.length} matched title${owned.length == 1 ? '' : 's'}', style: const TextStyle(color: Colors.white54, fontSize: 10)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [
          Align(alignment: Alignment.centerLeft, child: Text(concept.summary, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4))),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerLeft, child: Text(concept.canonNote, style: const TextStyle(color: Colors.white54, fontSize: 11, height: 1.4))),
          if (owned.isNotEmpty) ...[
            const Divider(height: 20, color: Colors.white12),
            for (final media in owned) _MultiverseOwnedMediaTile(media: media),
          ],
        ],
      ),
    );
  }
}

class _MultiverseOwnedMediaTile extends StatelessWidget {
  final MediaItem media;
  const _MultiverseOwnedMediaTile({required this.media});

  @override
  Widget build(BuildContext context) => ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: 39,
            height: 54,
            child: media.imageUrl?.trim().isNotEmpty == true
                ? Image.network(media.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF252532), child: Icon(Icons.movie_outlined)))
                : const ColoredBox(color: Color(0xFF252532), child: Icon(Icons.movie_outlined)),
          ),
        ),
        title: Text(media.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
        subtitle: Text('${media.type} · ${media.displayYearLabel ?? 'Year unknown'}', style: const TextStyle(color: Colors.white54, fontSize: 10)),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/app/details'),
          builder: (_) => MediaDetailsScreen(media: media),
        )),
      );
}

class _MultiverseMetric extends StatelessWidget {
  final String label;
  final String value;
  const _MultiverseMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
          decoration: BoxDecoration(color: const Color(0xFF222231), borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, color: Colors.white54)),
          ]),
        ),
      );
}

class _MultiverseNotice extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MultiverseNotice({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: const Color(0xFF201C38), borderRadius: BorderRadius.circular(13), border: Border.all(color: _multiverseAccent.withValues(alpha: .3))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: _multiverseAccent, size: 19),
          const SizedBox(width: 9),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.4))),
        ]),
      );
}
