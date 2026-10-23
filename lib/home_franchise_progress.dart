// FILE: lib/home_franchise_progress.dart
// Purpose: Calculate profile-visible franchise/saga and cinematic-universe
// ownership progress without inventing missing global catalog totals.

import 'dart:math' as math;

import 'app_core.dart';

/// A known title included in a featured franchise/universe example. These
/// are reference examples only; they are never inserted into the user's library.
class HomeFranchiseExampleTitle {
  final String title;
  final String type;
  final List<String> aliases;

  const HomeFranchiseExampleTitle({
    required this.title,
    required this.type,
    this.aliases = const <String>[],
  });
}

/// A group of movie/show titles owned by the active profile, paired with any
/// whole-franchise totals supplied by trusted catalog metadata.
class HomeFranchiseProgressGroup {
  final String id;
  final String name;
  final String type;
  final List<MediaItem> ownedTitles;
  final int? catalogTotalTitles;
  final int? catalogTotalMovies;
  final int? catalogTotalShows;
  final bool isFeaturedExample;
  final String? exampleNote;
  final List<HomeFranchiseExampleTitle> exampleTitles;

  const HomeFranchiseProgressGroup({
    required this.id,
    required this.name,
    required this.type,
    required this.ownedTitles,
    this.catalogTotalTitles,
    this.catalogTotalMovies,
    this.catalogTotalShows,
    this.isFeaturedExample = false,
    this.exampleNote,
    this.exampleTitles = const <HomeFranchiseExampleTitle>[],
  });

  int get ownedMovies =>
      ownedTitles.where(HomeFranchiseProgressLogic._isMovie).length;

  int get ownedShows =>
      ownedTitles.where(HomeFranchiseProgressLogic._isShow).length;

  int get ownedTotalTitles => ownedMovies + ownedShows;

  /// Returns null when neither a global total nor both category totals are
  /// known. It does not substitute the owned count as the catalog denominator.
  int? get totalTitles {
    final declared = catalogTotalTitles ??
        (catalogTotalMovies != null && catalogTotalShows != null
            ? catalogTotalMovies! + catalogTotalShows!
            : null);
    if (declared == null) return null;
    return math.max(declared, ownedTotalTitles).toInt();
  }

  int? get totalMovies => catalogTotalMovies == null
      ? null
      : math.max(catalogTotalMovies!, ownedMovies).toInt();

  int? get totalShows => catalogTotalShows == null
      ? null
      : math.max(catalogTotalShows!, ownedShows).toInt();

  double? get completionFraction {
    final total = totalTitles;
    if (total == null || total <= 0) return null;
    return (ownedTotalTitles / total).clamp(0.0, 1.0).toDouble();
  }

  int? get completionPercent {
    final fraction = completionFraction;
    return fraction == null ? null : (fraction * 100).round();
  }
}

class HomeFranchiseProgressLogic {
  HomeFranchiseProgressLogic._();

  static List<HomeFranchiseProgressGroup> franchiseSagaGroups(
    Iterable<MediaItem> source, {
    Iterable<MediaCollection> collections = const <MediaCollection>[],
  }) {
    final items = source.where(_isMovieOrShow).toList(growable: false);
    final builders = _ProgressBuilders();
    for (final item in items) {
      final memberships = <({String name, String? id, bool primary})>[];
      final seenNames = <String>{};
      final primaryName = _clean(item.franchiseName);

      void addName(String? rawName, {String? id, bool primary = false}) {
        final name = _clean(rawName);
        if (name.isEmpty || !seenNames.add(_normalize(name))) return;
        memberships.add((name: name, id: id, primary: primary));
      }

      addName(
        primaryName,
        id: item.franchiseId,
        primary: true,
      );
      for (final name in item.franchiseNames) {
        addName(
          name,
          id: primaryName.isEmpty && item.franchiseNames.length == 1
              ? item.franchiseId
              : null,
          primary: primaryName.isEmpty && item.franchiseNames.length == 1,
        );
      }
      // Adaptation groups provide useful franchise-style organization when no
      // dedicated franchise name was imported, or when it is an extra grouping.
      addName(
        item.adaptationGroupName,
        id: item.adaptationGroupId,
        primary: primaryName.isEmpty && item.franchiseNames.isEmpty,
      );

      for (final member in memberships) {
        final group = builders.ensure(
          id: member.id,
          name: member.name,
          type: _franchiseType(item.franchiseType, member.name),
        );
        group.addTitle(item);
        if (member.primary) {
          group.addCatalogTotals(
            titles: item.franchiseTotalTitles,
            movies: item.franchiseTotalMovies,
            shows: item.franchiseTotalShows,
          );
        }
      }
    }

    // Automatic collections also hold known franchise memberships inferred by
    // the app (for example, Harry Potter) when old media records lack explicit
    // franchise fields. The collection is profile-filtered via the source index.
    final byId = <String, MediaItem>{for (final item in items) item.id: item};
    for (final collection in collections) {
      final id = _clean(collection.automaticFranchiseId);
      if (!collection.isAutomatic || id.isEmpty) continue;
      final owned = collection.mediaIds
          .map((mediaId) => byId[mediaId])
          .whereType<MediaItem>()
          .where(_isMovieOrShow)
          .toList(growable: false);
      if (owned.isEmpty) continue;
      final group = builders.ensure(
        id: id,
        name: collection.name,
        type: collection.automaticFranchiseType ?? 'Franchise',
      );
      for (final item in owned) {
        group.addTitle(item);
      }
    }

    return _finish(builders.values);
  }

  static List<HomeFranchiseProgressGroup> cinematicUniverseGroups(
    Iterable<MediaItem> source,
  ) {
    final builders = _ProgressBuilders();
    for (final item in source.where(_isMovieOrShow)) {
      final explicitNames = item.cinematicUniverseNames;
      final seenNames = <String>{};

      void addUniverse({
        required String? rawName,
        String? id,
        Map<String, dynamic>? metadata,
        bool primary = false,
      }) {
        final name = _clean(rawName);
        if (name.isEmpty) return;
        final isNewMembership = seenNames.add(_normalize(name));
        final group = builders.ensure(
          id: id,
          name: name,
          type: 'Cinematic Universe',
        );
        // Adding a duplicate title is idempotent, but still inspect its
        // membership metadata because totals may be present only on that row.
        if (isNewMembership) group.addTitle(item);
        group.addCatalogTotals(
          titles: _metadataInt(metadata, const [
                'totalTitles',
                'total_titles',
                'catalogTotalTitles',
                'catalog_total_titles',
                'cinematicUniverseTotalTitles',
                'cinematic_universe_total_titles',
              ]) ??
              (primary ? item.cinematicUniverseTotalTitles : null),
          movies: _metadataInt(metadata, const [
                'totalMovies',
                'total_movies',
                'catalogTotalMovies',
                'catalog_total_movies',
                'cinematicUniverseTotalMovies',
                'cinematic_universe_total_movies',
              ]) ??
              (primary ? item.cinematicUniverseTotalMovies : null),
          shows: _metadataInt(metadata, const [
                'totalShows',
                'total_shows',
                'catalogTotalShows',
                'catalog_total_shows',
                'cinematicUniverseTotalShows',
                'cinematic_universe_total_shows',
              ]) ??
              (primary ? item.cinematicUniverseTotalShows : null),
        );
      }

      for (var i = 0; i < explicitNames.length; i++) {
        final name = explicitNames[i];
        final id = i < item.cinematicUniverseIds.length
            ? item.cinematicUniverseIds[i]
            : null;
        final isPrimary = _normalize(name) ==
            _normalize(item.cinematicUniverseSaga ?? '');
        addUniverse(
          rawName: name,
          id: id,
          primary: isPrimary || (explicitNames.length == 1),
        );
      }

      final saga = _clean(item.cinematicUniverseSaga);
      if (saga.isNotEmpty) {
        addUniverse(
          rawName: saga,
          id: item.cinematicUniverseIds.isEmpty
              ? null
              : item.cinematicUniverseIds.first,
          primary: true,
        );
      }

      for (final membership in item.universeMemberships) {
        final name = _firstString(membership, const [
          'name',
          'universeName',
          'universe_name',
          'cinematicUniverseName',
          'cinematic_universe_name',
          'title',
        ]);
        final id = _firstString(membership, const [
          'id',
          'universeId',
          'universe_id',
          'cinematicUniverseId',
          'cinematic_universe_id',
        ]);
        addUniverse(
          rawName: name,
          id: id,
          metadata: membership,
          primary: _normalize(name ?? '') == _normalize(saga),
        );
      }
    }
    return _finish(builders.values);
  }

  /// Featured starter groups make the two Home hubs useful before an external
  /// catalog has populated franchise/universe relationships. Counts of owned
  /// titles come only from this profile's actual local catalog. Seeded totals
  /// are clearly labelled and are replaced whenever a matching metadata group
  /// supplies its own authoritative totals.
  static List<HomeFranchiseProgressGroup> franchiseSagaExamples(
    Iterable<MediaItem> source,
    List<HomeFranchiseProgressGroup> catalogGroups,
  ) => _examplesWithCatalogGroups(
        source,
        catalogGroups,
        const <_HomeProgressExampleDefinition>[
          _HomeProgressExampleDefinition(
            id: 'example-fast-and-furious',
            name: 'Fast & Furious Saga',
            type: 'Saga',
            totalMovies: 10,
            totalShows: 0,
            groupAliases: ['fast and furious', 'fast & furious', 'fast saga'],
            titleAliases: [
              'the fast and the furious', '2 fast 2 furious', 'tokyo drift',
              'fast & furious', 'fast five', 'furious 7',
              'the fate of the furious', 'f9', 'fast x'
            ],
            note: 'Starter total is the ten main-saga films. Spin-offs can be tracked as related titles separately.',
            exampleTitles: <HomeFranchiseExampleTitle>[
              HomeFranchiseExampleTitle(title: 'The Fast and the Furious', type: 'Movie', aliases: ['the fast and the furious']),
              HomeFranchiseExampleTitle(title: '2 Fast 2 Furious', type: 'Movie', aliases: ['2 fast 2 furious']),
              HomeFranchiseExampleTitle(title: 'The Fast and the Furious: Tokyo Drift', type: 'Movie', aliases: ['the fast and the furious tokyo drift', 'fast and furious tokyo drift', 'tokyo drift']),
              HomeFranchiseExampleTitle(title: 'Fast & Furious', type: 'Movie', aliases: ['fast furious']),
              HomeFranchiseExampleTitle(title: 'Fast Five', type: 'Movie', aliases: ['fast five']),
              HomeFranchiseExampleTitle(title: 'Fast & Furious 6', type: 'Movie', aliases: ['fast furious 6', 'furious 6']),
              HomeFranchiseExampleTitle(title: 'Furious 7', type: 'Movie', aliases: ['furious 7']),
              HomeFranchiseExampleTitle(title: 'The Fate of the Furious', type: 'Movie', aliases: ['the fate of the furious', 'fate of the furious']),
              HomeFranchiseExampleTitle(title: 'F9', type: 'Movie', aliases: ['f9', 'fast and furious 9']),
              HomeFranchiseExampleTitle(title: 'Fast X', type: 'Movie', aliases: ['fast x']),
            ],
          ),
          _HomeProgressExampleDefinition(
            id: 'example-hunger-games',
            name: 'The Hunger Games Saga',
            type: 'Saga',
            totalMovies: 5,
            totalShows: 0,
            groupAliases: ['the hunger games', 'hunger games saga'],
            titleAliases: ['the hunger games', 'catching fire', 'mockingjay', 'ballad of songbirds and snakes'],
            note: 'Starter total counts released films; provider metadata can add future releases and related shows.',
            exampleTitles: <HomeFranchiseExampleTitle>[
              HomeFranchiseExampleTitle(title: 'The Hunger Games', type: 'Movie', aliases: ['the hunger games']),
              HomeFranchiseExampleTitle(title: 'The Hunger Games: Catching Fire', type: 'Movie', aliases: ['the hunger games catching fire', 'catching fire']),
              HomeFranchiseExampleTitle(title: 'The Hunger Games: Mockingjay — Part 1', type: 'Movie', aliases: ['the hunger games mockingjay part 1', 'the hunger games mockingjay part i', 'mockingjay part 1', 'mockingjay part i']),
              HomeFranchiseExampleTitle(title: 'The Hunger Games: Mockingjay — Part 2', type: 'Movie', aliases: ['the hunger games mockingjay part 2', 'the hunger games mockingjay part ii', 'mockingjay part 2', 'mockingjay part ii']),
              HomeFranchiseExampleTitle(title: 'The Hunger Games: The Ballad of Songbirds & Snakes', type: 'Movie', aliases: ['the hunger games the ballad of songbirds and snakes', 'the hunger games ballad of songbirds and snakes', 'ballad of songbirds and snakes']),
            ],
          ),
          _HomeProgressExampleDefinition(
            id: 'example-harry-potter',
            name: 'Harry Potter — 8-Film Collection',
            type: 'Saga',
            totalMovies: 8,
            totalShows: 0,
            groupAliases: ['harry potter'],
            titleAliases: ['harry potter'],
            note: 'Starter count covers all eight Harry Potter movies, not the separate Fantastic Beasts films.',
            exampleTitles: <HomeFranchiseExampleTitle>[
              HomeFranchiseExampleTitle(title: 'Harry Potter and the Sorcerer’s Stone', type: 'Movie', aliases: ["harry potter and the sorcerer's stone", "harry potter and the philosopher's stone", 'sorcerer stone', 'philosophers stone']),
              HomeFranchiseExampleTitle(title: 'Harry Potter and the Chamber of Secrets', type: 'Movie', aliases: ['harry potter and the chamber of secrets', 'chamber of secrets']),
              HomeFranchiseExampleTitle(title: 'Harry Potter and the Prisoner of Azkaban', type: 'Movie', aliases: ['harry potter and the prisoner of azkaban', 'prisoner of azkaban']),
              HomeFranchiseExampleTitle(title: 'Harry Potter and the Goblet of Fire', type: 'Movie', aliases: ['harry potter and the goblet of fire', 'goblet of fire']),
              HomeFranchiseExampleTitle(title: 'Harry Potter and the Order of the Phoenix', type: 'Movie', aliases: ['harry potter and the order of the phoenix', 'order of the phoenix']),
              HomeFranchiseExampleTitle(title: 'Harry Potter and the Half-Blood Prince', type: 'Movie', aliases: ['harry potter and the half blood prince', 'half blood prince']),
              HomeFranchiseExampleTitle(title: 'Harry Potter and the Deathly Hallows — Part 1', type: 'Movie', aliases: ['harry potter and the deathly hallows part 1', 'harry potter and the deathly hallows part i', 'deathly hallows part 1', 'deathly hallows part i']),
              HomeFranchiseExampleTitle(title: 'Harry Potter and the Deathly Hallows — Part 2', type: 'Movie', aliases: ['harry potter and the deathly hallows part 2', 'harry potter and the deathly hallows part ii', 'deathly hallows part 2', 'deathly hallows part ii']),
            ],
          ),
        ],
        type: 'Franchise',
      );

  static List<HomeFranchiseProgressGroup> cinematicUniverseExamples(
    Iterable<MediaItem> source,
    List<HomeFranchiseProgressGroup> catalogGroups,
  ) => _examplesWithCatalogGroups(
        source,
        catalogGroups,
        const <_HomeProgressExampleDefinition>[
          _HomeProgressExampleDefinition(
            id: 'example-mcu',
            name: 'MCU — Marvel Cinematic Universe',
            type: 'Cinematic Universe',
            totalMovies: 38,
            groupAliases: ['mcu', 'marvel cinematic universe'],
            titleAliases: [
              'iron man', 'the incredible hulk', 'iron man 2', 'thor',
              'captain america: the first avenger', 'the avengers',
              'avengers: age of ultron', 'guardians of the galaxy',
              'ant-man', 'doctor strange', 'black panther', 'captain marvel',
              'avengers: infinity war', 'avengers: endgame', 'shang-chi',
              'eternals', 'spider-man: homecoming', 'spider-man: far from home',
              'spider-man: no way home', 'deadpool & wolverine', 'thunderbolts',
              'the fantastic four: first steps', 'spider-man: brand new day',
              'wandavision', 'loki', 'the falcon and the winter soldier',
              'hawkeye', 'moon knight', 'ms marvel', 'she-hulk',
              'secret invasion', 'echo', 'agatha all along', 'daredevil: born again',
              'wonder man', 'visionquest'
            ],
            note: '38-film starter count reflects released feature films through 2026; show totals are left to imported universe metadata. The list below is illustrative, not the complete MCU filmography.',
            exampleTitles: <HomeFranchiseExampleTitle>[
              HomeFranchiseExampleTitle(title: 'Iron Man', type: 'Movie', aliases: ['iron man']),
              HomeFranchiseExampleTitle(title: 'The Avengers', type: 'Movie', aliases: ['the avengers']),
              HomeFranchiseExampleTitle(title: 'Avengers: Age of Ultron', type: 'Movie', aliases: ['avengers age of ultron']),
              HomeFranchiseExampleTitle(title: 'Black Panther', type: 'Movie', aliases: ['black panther']),
              HomeFranchiseExampleTitle(title: 'Avengers: Infinity War', type: 'Movie', aliases: ['avengers infinity war']),
              HomeFranchiseExampleTitle(title: 'Avengers: Endgame', type: 'Movie', aliases: ['avengers endgame']),
              HomeFranchiseExampleTitle(title: 'Spider-Man: No Way Home', type: 'Movie', aliases: ['spider man no way home']),
              HomeFranchiseExampleTitle(title: 'The Fantastic Four: First Steps', type: 'Movie', aliases: ['the fantastic four first steps', 'fantastic four first steps']),
              HomeFranchiseExampleTitle(title: 'WandaVision', type: 'TV Show', aliases: ['wandavision']),
              HomeFranchiseExampleTitle(title: 'Loki', type: 'TV Show', aliases: ['loki']),
            ],
          ),
          _HomeProgressExampleDefinition(
            id: 'example-dceu',
            name: 'DCEU (2013–2023)',
            type: 'Cinematic Universe',
            totalMovies: 15,
            totalShows: 1,
            groupAliases: ['dceu', 'dc extended universe'],
            titleAliases: [
              'man of steel', 'batman v superman', 'suicide squad',
              'wonder woman', 'justice league', 'aquaman', 'shazam',
              'birds of prey', 'the suicide squad', 'black adam', 'blue beetle',
              'the flash', 'aquaman and the lost kingdom', 'peacemaker'
            ],
            note: 'Starter totals cover the 2013–2023 DCEU feature-film run plus one associated show; imported continuity metadata takes priority.',
            exampleTitles: <HomeFranchiseExampleTitle>[
              HomeFranchiseExampleTitle(title: 'Man of Steel', type: 'Movie', aliases: ['man of steel']),
              HomeFranchiseExampleTitle(title: 'Batman v Superman: Dawn of Justice', type: 'Movie', aliases: ['batman v superman dawn of justice', 'batman vs superman dawn of justice', 'batman v superman', 'batman vs superman']),
              HomeFranchiseExampleTitle(title: 'Suicide Squad', type: 'Movie', aliases: ['suicide squad']),
              HomeFranchiseExampleTitle(title: 'Wonder Woman', type: 'Movie', aliases: ['wonder woman']),
              HomeFranchiseExampleTitle(title: 'Justice League', type: 'Movie', aliases: ['justice league']),
              HomeFranchiseExampleTitle(title: 'Aquaman', type: 'Movie', aliases: ['aquaman']),
              HomeFranchiseExampleTitle(title: 'Shazam!', type: 'Movie', aliases: ['shazam']),
              HomeFranchiseExampleTitle(title: 'Birds of Prey', type: 'Movie', aliases: ['birds of prey']),
              HomeFranchiseExampleTitle(title: 'Wonder Woman 1984', type: 'Movie', aliases: ['wonder woman 1984']),
              HomeFranchiseExampleTitle(title: 'The Suicide Squad', type: 'Movie', aliases: ['the suicide squad']),
              HomeFranchiseExampleTitle(title: 'Black Adam', type: 'Movie', aliases: ['black adam']),
              HomeFranchiseExampleTitle(title: 'Shazam! Fury of the Gods', type: 'Movie', aliases: ['shazam fury of the gods']),
              HomeFranchiseExampleTitle(title: 'The Flash', type: 'Movie', aliases: ['the flash']),
              HomeFranchiseExampleTitle(title: 'Blue Beetle', type: 'Movie', aliases: ['blue beetle']),
              HomeFranchiseExampleTitle(title: 'Aquaman and the Lost Kingdom', type: 'Movie', aliases: ['aquaman and the lost kingdom', 'aquaman lost kingdom']),
              HomeFranchiseExampleTitle(title: 'Peacemaker', type: 'TV Show', aliases: ['peacemaker']),
            ],
          ),
          _HomeProgressExampleDefinition(
            id: 'example-monsterverse',
            name: 'Monsterverse',
            type: 'Cinematic Universe',
            totalMovies: 5,
            totalShows: 2,
            groupAliases: ['monsterverse', 'monster verse'],
            titleAliases: [
              'godzilla', 'godzilla: king of the monsters',
              'kong: skull island', 'godzilla vs. kong',
              'godzilla x kong: the new empire', 'skull island',
              'monarch: legacy of monsters'
            ],
            note: 'Starter totals include five released films and two series entries; update via catalog metadata as new titles release.',
            exampleTitles: <HomeFranchiseExampleTitle>[
              HomeFranchiseExampleTitle(title: 'Godzilla (2014)', type: 'Movie', aliases: ['godzilla']),
              HomeFranchiseExampleTitle(title: 'Kong: Skull Island', type: 'Movie', aliases: ['kong skull island']),
              HomeFranchiseExampleTitle(title: 'Godzilla: King of the Monsters', type: 'Movie', aliases: ['godzilla king of the monsters']),
              HomeFranchiseExampleTitle(title: 'Godzilla vs. Kong', type: 'Movie', aliases: ['godzilla vs kong', 'godzilla versus kong']),
              HomeFranchiseExampleTitle(title: 'Godzilla x Kong: The New Empire', type: 'Movie', aliases: ['godzilla x kong', 'new empire']),
              HomeFranchiseExampleTitle(title: 'Skull Island', type: 'TV Show', aliases: ['skull island']),
              HomeFranchiseExampleTitle(title: 'Monarch: Legacy of Monsters', type: 'TV Show', aliases: ['monarch legacy of monsters']),
            ],
          ),
        ],
        type: 'Cinematic Universe',
      );

  static List<HomeFranchiseProgressGroup> _examplesWithCatalogGroups(
    Iterable<MediaItem> source,
    List<HomeFranchiseProgressGroup> catalogGroups,
    List<_HomeProgressExampleDefinition> definitions, {
    required String type,
  }) {
    final items = source.where(_isMovieOrShow).toList(growable: false);
    final featured = <HomeFranchiseProgressGroup>[];
    final usedCatalogIds = <String>{};
    for (final definition in definitions) {
      final inferredMatches = items
          .where((item) => _matchesExample(item, definition))
          .toList(growable: false);
      HomeFranchiseProgressGroup? catalogMatch;
      for (final group in catalogGroups) {
        if (usedCatalogIds.contains(group.id)) continue;
        final name = _normalize(group.name);
        final aliases = definition.groupAliases.map(_normalize);
        if (name == _normalize(definition.name) ||
            aliases.any((alias) => name == alias || name.contains(alias) || alias.contains(name))) {
          catalogMatch = group;
          break;
        }
      }
      if (catalogMatch != null) {
        usedCatalogIds.add(catalogMatch.id);
        final seededMovies = catalogMatch.totalMovies ?? definition.totalMovies;
        final seededShows = catalogMatch.totalShows ?? definition.totalShows;
        final seededTotal = catalogMatch.totalTitles ??
            (seededMovies != null && seededShows != null
                ? seededMovies + seededShows
                : null);
        final ownedById = <String, MediaItem>{
          for (final item in catalogMatch.ownedTitles) item.id: item,
        };
        for (final item in inferredMatches) {
          ownedById.putIfAbsent(item.id, () => item);
        }
        featured.add(HomeFranchiseProgressGroup(
          id: catalogMatch.id,
          name: catalogMatch.name,
          type: catalogMatch.type,
          ownedTitles: ownedById.values.toList(growable: false),
          catalogTotalTitles: seededTotal,
          catalogTotalMovies: seededMovies,
          catalogTotalShows: seededShows,
          isFeaturedExample: true,
          exampleNote: catalogMatch.exampleNote ?? definition.note,
          exampleTitles: definition.exampleTitles,
        ));
        continue;
      }

      final matches = inferredMatches;

      final movies = definition.totalMovies;
      final shows = definition.totalShows;
      featured.add(HomeFranchiseProgressGroup(
        id: definition.id,
        name: definition.name,
        type: definition.type.isEmpty ? type : definition.type,
        ownedTitles: matches,
        catalogTotalTitles:
            movies != null && shows != null ? movies + shows : null,
        catalogTotalMovies: movies,
        catalogTotalShows: shows,
        isFeaturedExample: true,
        exampleNote: definition.note,
        exampleTitles: definition.exampleTitles,
      ));
    }
    final featuredIds = featured.map((group) => group.id).toSet();
    final remaining = catalogGroups
        .where((group) => !featuredIds.contains(group.id) && !usedCatalogIds.contains(group.id))
        .toList(growable: false);
    return <HomeFranchiseProgressGroup>[...featured, ...remaining];
  }

  static bool _matchesExample(
    MediaItem item,
    _HomeProgressExampleDefinition definition,
  ) {
    final identityText = _normalize(<String>[
      item.franchiseName ?? '',
      ...item.franchiseNames,
      item.adaptationGroupName ?? '',
      item.cinematicUniverseSaga ?? '',
      ...item.cinematicUniverseNames,
      ...item.universeMemberships.map((entry) =>
          (entry['name'] ?? entry['universeName'] ?? entry['title'] ?? '').toString()),
    ].join(' '));
    final titleText = _normalize(<String>[
      item.title,
      item.originalTitle ?? '',
      item.canonicalTitle ?? '',
    ].join(' '));
    if (definition.id == 'example-fast-and-furious' &&
        (titleText.contains('hobbs shaw') || titleText.contains('hobbs and shaw'))) {
      return false;
    }
    if (definition.id == 'example-harry-potter' &&
        titleText.contains('fantastic beasts')) {
      return false;
    }
    final identityMatch = definition.groupAliases
        .map(_normalize)
        .any((alias) => alias.isNotEmpty && identityText.contains(alias));
    final titleMatch = definition.titleAliases
        .map(_normalize)
        .any((alias) => alias.isNotEmpty && titleText.contains(alias));
    if (definition.id == 'example-harry-potter' && !_isMovie(item)) {
      return false;
    }
    if (definition.totalShows == 0 && _isShow(item)) return false;
    return identityMatch || titleMatch;
  }

  static List<HomeFranchiseProgressGroup> _finish(
    Iterable<_HomeProgressBuilder> builders,
  ) {
    final groups = builders
        .map((builder) => builder.build())
        .where((group) => group.ownedTotalTitles > 0)
        .toList(growable: false);
    groups.sort((a, b) {
      final byOwned = b.ownedTotalTitles.compareTo(a.ownedTotalTitles);
      return byOwned != 0
          ? byOwned
          : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return groups;
  }

  static bool _isMovie(MediaItem item) {
    final type = item.type.toLowerCase();
    return type.contains('movie') || type.contains('film');
  }

  static bool _isShow(MediaItem item) {
    final type = item.type.toLowerCase();
    return type.contains('tv') ||
        type.contains('show') ||
        type.contains('series') ||
        type.contains('episode');
  }

  static bool _isMovieOrShow(MediaItem item) =>
      _isMovie(item) || _isShow(item);

  static String _franchiseType(String? value, String name) {
    final type = _clean(value);
    if (type.isNotEmpty) return type;
    return name.toLowerCase().contains('saga') ? 'Saga' : 'Franchise';
  }

  static String _clean(String? value) => value?.trim() ?? '';

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();

  static int? _metadataInt(Map<String, dynamic>? metadata, List<String> keys) {
    if (metadata == null) return null;
    for (final key in keys) {
      final raw = metadata[key];
      if (raw is num) return raw.toInt();
      final parsed = int.tryParse(raw?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }

  static String? _firstString(Map<String, dynamic> metadata, List<String> keys) {
    for (final key in keys) {
      final value = _clean(metadata[key]?.toString());
      if (value.isNotEmpty) return value;
    }
    return null;
  }
}

class _HomeProgressExampleDefinition {
  final String id;
  final String name;
  final String type;
  final int? totalMovies;
  final int? totalShows;
  final List<String> groupAliases;
  final List<String> titleAliases;
  final String note;
  final List<HomeFranchiseExampleTitle> exampleTitles;

  const _HomeProgressExampleDefinition({
    required this.id,
    required this.name,
    required this.type,
    required this.groupAliases,
    required this.titleAliases,
    required this.note,
    this.totalMovies,
    this.totalShows,
    this.exampleTitles = const <HomeFranchiseExampleTitle>[],
  });
}

class _ProgressBuilders {
  final Map<String, _HomeProgressBuilder> _groups =
      <String, _HomeProgressBuilder>{};
  final Map<String, String> _aliases = <String, String>{};

  Iterable<_HomeProgressBuilder> get values => _groups.values;

  _HomeProgressBuilder ensure({
    required String? id,
    required String name,
    required String type,
  }) {
    final cleanId = id?.trim() ?? '';
    final nameKey = 'name:${HomeFranchiseProgressLogic._normalize(name)}';
    final idKey = cleanId.isEmpty
        ? ''
        : 'id:${HomeFranchiseProgressLogic._normalize(cleanId)}';
    final existingKey = (idKey.isNotEmpty ? _aliases[idKey] : null) ??
        _aliases[nameKey] ??
        (idKey.isNotEmpty ? idKey : nameKey);
    final group = _groups.putIfAbsent(
      existingKey,
      () => _HomeProgressBuilder(
        id: cleanId.isNotEmpty ? cleanId : existingKey,
        name: name,
        type: type,
      ),
    );
    _aliases[nameKey] = existingKey;
    if (idKey.isNotEmpty) _aliases[idKey] = existingKey;
    return group;
  }
}

class _HomeProgressBuilder {
  final String id;
  final String name;
  final String type;
  final Map<String, MediaItem> _titles = <String, MediaItem>{};
  int? _totalTitles;
  int? _totalMovies;
  int? _totalShows;

  _HomeProgressBuilder({
    required this.id,
    required this.name,
    required this.type,
  });

  void addTitle(MediaItem item) {
    _titles.putIfAbsent(item.id, () => item);
  }

  void addCatalogTotals({int? titles, int? movies, int? shows}) {
    if (titles != null && titles >= 0) {
      _totalTitles = _totalTitles == null
          ? titles
          : math.max(_totalTitles!, titles).toInt();
    }
    if (movies != null && movies >= 0) {
      _totalMovies = _totalMovies == null
          ? movies
          : math.max(_totalMovies!, movies).toInt();
    }
    if (shows != null && shows >= 0) {
      _totalShows = _totalShows == null
          ? shows
          : math.max(_totalShows!, shows).toInt();
    }
  }

  HomeFranchiseProgressGroup build() {
    final titles = _titles.values.toList(growable: false)
      ..sort((a, b) {
        final dateA = a.editionReleaseDate ?? a.releaseDate ?? a.seriesStartDate;
        final dateB = b.editionReleaseDate ?? b.releaseDate ?? b.seriesStartDate;
        if (dateA != null && dateB != null) {
          final byDate = dateA.compareTo(dateB);
          if (byDate != 0) return byDate;
        } else if (dateA != null) {
          return -1;
        } else if (dateB != null) {
          return 1;
        }
        final byYear = (a.releaseYear ?? a.seriesStartYear ?? 999999)
            .compareTo(b.releaseYear ?? b.seriesStartYear ?? 999999);
        return byYear != 0
            ? byYear
            : a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
    return HomeFranchiseProgressGroup(
      id: id,
      name: name,
      type: type,
      ownedTitles: titles,
      catalogTotalTitles: _totalTitles,
      catalogTotalMovies: _totalMovies,
      catalogTotalShows: _totalShows,
    );
  }
}
