import 'package:flutter/material.dart';

import 'app_core.dart';
import 'cinematic_universe_franchise_explorer.dart';
import 'details.dart';

/// Two purpose-built entry pages backed by the current profile's catalog.
/// Featured franchise filmographies are curated title lists. Exact catalog
/// title/year matches are shown as found; missing titles are never fabricated.
enum FranchiseUniverseBrowseMode { franchises, universes }

class FranchiseUniverseBrowseHubScreen extends StatelessWidget {
  const FranchiseUniverseBrowseHubScreen({
    super.key,
    required this.mode,
  });

  final FranchiseUniverseBrowseMode mode;

  @override
  Widget build(BuildContext context) {
    final works = UniverseFranchiseIndex.visibleWorks(
      AppController.instance.library,
    );
    final isFranchise = mode == FranchiseUniverseBrowseMode.franchises;
    final metadataGroups = UniverseFranchiseIndex.groups(
      works,
      kind: isFranchise ? 'Franchise' : 'Universe',
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(isFranchise ? 'Franchises' : 'Cinematic Universes'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _BrowseIntroCard(
            title: isFranchise ? 'Explore movie franchises' : 'Explore connected universes',
            description: isFranchise
                ? 'Browse curated film lineups and other franchises recorded in your library. Each title is marked as found or missing from this profile’s catalog.'
                : 'Explore MCU, DCEU, MonsterVerse, and other universe groups backed by explicit catalog relationships. We do not guess a universe from actor overlap or title wording.',
            icon: isFranchise ? Icons.movie_filter_rounded : Icons.hub_rounded,
          ),
          const SizedBox(height: 18),
          if (isFranchise) ...[
            const _SectionHeading('Featured franchises'),
            const SizedBox(height: 8),
            for (final guide in _curatedFranchises) ...[
              _CuratedFranchiseTile(guide: guide, works: works),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 12),
            const _SectionHeading('Other catalog franchises'),
            const SizedBox(height: 8),
            ..._otherGroups(metadataGroups, _curatedFranchises.map((g) => g.name))
                .map((group) => _MetadataGroupTile(group: group)),
            if (_otherGroups(metadataGroups, _curatedFranchises.map((g) => g.name)).isEmpty)
              const _EmptyHint('No additional metadata-linked franchises are available yet.'),
          ] else ...[
            const _SectionHeading('Featured cinematic universes'),
            const SizedBox(height: 8),
            for (final guide in _curatedUniverses) ...[
              _CuratedUniverseTile(guide: guide, metadataGroups: metadataGroups),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 12),
            const _SectionHeading('Other catalog universes'),
            const SizedBox(height: 8),
            ..._otherGroups(metadataGroups, _curatedUniverses.expand((g) => g.aliases))
                .map((group) => _MetadataGroupTile(group: group)),
            if (_otherGroups(metadataGroups, _curatedUniverses.expand((g) => g.aliases)).isEmpty)
              const _EmptyHint('No additional metadata-linked cinematic universes are available yet.'),
          ],
          const SizedBox(height: 18),
          const Text(
            'Counts describe the current profile-accessible catalog, not the number of titles owned by every household member or guaranteed to be playable from an external provider.',
            style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}

List<UniverseFranchiseGroup> _otherGroups(
  List<UniverseFranchiseGroup> groups,
  Iterable<String> excludedNames,
) {
  final excluded = excludedNames.map(UniverseFranchiseIndex.normalize).toSet();
  return groups
      .where((group) => !excluded.contains(UniverseFranchiseIndex.normalize(group.name)))
      .toList(growable: false);
}

class _CuratedMovie {
  const _CuratedMovie({
    required this.title,
    required this.year,
    this.aliases = const <String>[],
  });

  final String title;
  final int year;
  final List<String> aliases;
}

class _CuratedFranchise {
  const _CuratedFranchise({
    required this.name,
    required this.years,
    required this.movies,
    this.description = '',
  });

  final String name;
  final String years;
  final List<_CuratedMovie> movies;
  final String description;
}

const List<_CuratedFranchise> _curatedFranchises = <_CuratedFranchise>[
  _CuratedFranchise(
    name: 'Harry Potter', years: '2001–2011', description: 'The eight-film Harry Potter story',
    movies: <_CuratedMovie>[
      _CuratedMovie(title: "Harry Potter and the Philosopher's Stone", year: 2001, aliases: <String>["Harry Potter and the Sorcerer's Stone"]),
      _CuratedMovie(title: 'Harry Potter and the Chamber of Secrets', year: 2002),
      _CuratedMovie(title: 'Harry Potter and the Prisoner of Azkaban', year: 2004),
      _CuratedMovie(title: 'Harry Potter and the Goblet of Fire', year: 2005),
      _CuratedMovie(title: 'Harry Potter and the Order of the Phoenix', year: 2007),
      _CuratedMovie(title: 'Harry Potter and the Half-Blood Prince', year: 2009),
      _CuratedMovie(title: 'Harry Potter and the Deathly Hallows: Part 1', year: 2010, aliases: <String>['Harry Potter and the Deathly Hallows Part I']),
      _CuratedMovie(title: 'Harry Potter and the Deathly Hallows: Part 2', year: 2011, aliases: <String>['Harry Potter and the Deathly Hallows Part II']),
    ],
  ),
  _CuratedFranchise(
    name: 'The Twilight Saga', years: '2008–2012', description: 'The five-film Twilight Saga',
    movies: <_CuratedMovie>[
      _CuratedMovie(title: 'Twilight', year: 2008),
      _CuratedMovie(title: 'The Twilight Saga: New Moon', year: 2009, aliases: <String>['New Moon']),
      _CuratedMovie(title: 'The Twilight Saga: Eclipse', year: 2010, aliases: <String>['Eclipse']),
      _CuratedMovie(title: 'The Twilight Saga: Breaking Dawn – Part 1', year: 2011, aliases: <String>['The Twilight Saga Breaking Dawn Part 1', 'Breaking Dawn Part 1']),
      _CuratedMovie(title: 'The Twilight Saga: Breaking Dawn – Part 2', year: 2012, aliases: <String>['The Twilight Saga Breaking Dawn Part 2', 'Breaking Dawn Part 2']),
    ],
  ),
  _CuratedFranchise(
    name: 'The Hunger Games', years: '2012–2015', description: 'The original four-film storyline',
    movies: <_CuratedMovie>[
      _CuratedMovie(title: 'The Hunger Games', year: 2012),
      _CuratedMovie(title: 'The Hunger Games: Catching Fire', year: 2013, aliases: <String>['Catching Fire']),
      _CuratedMovie(title: 'The Hunger Games: Mockingjay – Part 1', year: 2014, aliases: <String>['The Hunger Games Mockingjay Part 1', 'Mockingjay Part 1']),
      _CuratedMovie(title: 'The Hunger Games: Mockingjay – Part 2', year: 2015, aliases: <String>['The Hunger Games Mockingjay Part 2', 'Mockingjay Part 2']),
    ],
  ),
  _CuratedFranchise(
    name: 'Indiana Jones', years: '1981–2023', description: 'Five Indiana Jones theatrical films',
    movies: <_CuratedMovie>[
      _CuratedMovie(title: 'Raiders of the Lost Ark', year: 1981, aliases: <String>['Indiana Jones and the Raiders of the Lost Ark']),
      _CuratedMovie(title: 'Indiana Jones and the Temple of Doom', year: 1984),
      _CuratedMovie(title: 'Indiana Jones and the Last Crusade', year: 1989),
      _CuratedMovie(title: 'Indiana Jones and the Kingdom of the Crystal Skull', year: 2008),
      _CuratedMovie(title: 'Indiana Jones and the Dial of Destiny', year: 2023),
    ],
  ),
  _CuratedFranchise(
    name: 'Halloween', years: '1978–2022', description: 'The 13-film Halloween franchise, including its alternate timelines',
    movies: <_CuratedMovie>[
      _CuratedMovie(title: 'Halloween', year: 1978),
      _CuratedMovie(title: 'Halloween II', year: 1981),
      _CuratedMovie(title: 'Halloween III: Season of the Witch', year: 1982, aliases: <String>['Halloween 3 Season of the Witch']),
      _CuratedMovie(title: 'Halloween 4: The Return of Michael Myers', year: 1988, aliases: <String>['Halloween 4 The Return of Michael Myers']),
      _CuratedMovie(title: 'Halloween 5: The Revenge of Michael Myers', year: 1989, aliases: <String>['Halloween 5 The Revenge of Michael Myers']),
      _CuratedMovie(title: 'Halloween: The Curse of Michael Myers', year: 1995, aliases: <String>['Halloween The Curse of Michael Myers', 'Halloween 6']),
      _CuratedMovie(title: 'Halloween H20: 20 Years Later', year: 1998, aliases: <String>['Halloween H20']),
      _CuratedMovie(title: 'Halloween: Resurrection', year: 2002, aliases: <String>['Halloween Resurrection']),
      _CuratedMovie(title: 'Halloween', year: 2007),
      _CuratedMovie(title: 'Halloween II', year: 2009),
      _CuratedMovie(title: 'Halloween', year: 2018),
      _CuratedMovie(title: 'Halloween Kills', year: 2021),
      _CuratedMovie(title: 'Halloween Ends', year: 2022),
    ],
  ),
];

class _CuratedFranchiseTile extends StatelessWidget {
  const _CuratedFranchiseTile({required this.guide, required this.works});

  final _CuratedFranchise guide;
  final List<MediaItem> works;

  @override
  Widget build(BuildContext context) {
    final found = guide.movies.where((movie) => _findMatches(works, movie).isNotEmpty).length;
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.movie_filter_rounded)),
        title: Text(guide.name, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('${guide.years} · $found of ${guide.movies.length} listed films found in this profile library\n${guide.description}'),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.of(context).push<void>(MaterialPageRoute<void>(
          builder: (_) => _CuratedFranchiseDetailsScreen(guide: guide, works: works),
        )),
      ),
    );
  }
}

class _CuratedFranchiseDetailsScreen extends StatelessWidget {
  const _CuratedFranchiseDetailsScreen({required this.guide, required this.works});

  final _CuratedFranchise guide;
  final List<MediaItem> works;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(guide.name)),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text('${guide.years} · ${guide.movies.length} films in this curated guide', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text('A title is marked as found only when its name/alias and release year match a catalog entry. Missing items are shown so you can identify gaps; no media is added by this guide.', style: TextStyle(color: Colors.white60, height: 1.4)),
        const SizedBox(height: 14),
        for (final movie in guide.movies) ...[
          _CuratedMovieRow(movie: movie, works: works),
          const SizedBox(height: 6),
        ],
      ],
    ),
  );
}

class _CuratedMovieRow extends StatelessWidget {
  const _CuratedMovieRow({required this.movie, required this.works});
  final _CuratedMovie movie;
  final List<MediaItem> works;

  @override
  Widget build(BuildContext context) {
    final matches = _findMatches(works, movie);
    if (matches.isEmpty) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.inventory_2_outlined, color: Colors.white38),
          title: Text(movie.title),
          subtitle: Text('${movie.year} · Not found in this profile’s catalog'),
        ),
      );
    }
    if (matches.length == 1) {
      final item = matches.single;
      return Card(
        child: ListTile(
          leading: _Poster(item: item),
          title: Text(item.title),
          subtitle: Text('${item.releaseYear ?? movie.year} · In your catalog'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => _openMedia(context, item),
        ),
      );
    }
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.movie_outlined),
        title: Text(movie.title),
        subtitle: Text('${movie.year} · ${matches.length} matching catalog items/editions'),
        children: [
          for (final item in matches)
            ListTile(
              leading: _Poster(item: item),
              title: Text(item.title),
              subtitle: Text('${item.type}${item.releaseYear == null ? '' : ' · ${item.releaseYear}'}'),
              onTap: () => _openMedia(context, item),
            ),
        ],
      ),
    );
  }
}

List<MediaItem> _findMatches(Iterable<MediaItem> works, _CuratedMovie movie) {
  final aliases = <String>{
    movie.title,
    ...movie.aliases,
  }.map(UniverseFranchiseIndex.normalize).toSet();
  final ambiguousAliases = <String>{};
  for (final other in _curatedFranchises.expand((g) => g.movies)) {
    if (identical(other, movie) || (other.title == movie.title && other.year == movie.year)) continue;
    final otherAliases = <String>{other.title, ...other.aliases}.map(UniverseFranchiseIndex.normalize).toSet();
    if (aliases.intersection(otherAliases).isNotEmpty) ambiguousAliases.addAll(aliases.intersection(otherAliases));
  }

  final result = works.where((item) {
    var normalizedTitle = UniverseFranchiseIndex.normalize(item.title);
    normalizedTitle = normalizedTitle.replaceFirst(RegExp(r'\s+(19|20)\d{2}$'), '').trim();
    final matchingAlias = aliases.firstWhere(
      (alias) => normalizedTitle == alias || (alias.length >= 12 && normalizedTitle.startsWith('$alias ')),
      orElse: () => '',
    );
    if (matchingAlias.isEmpty) return false;
    if (ambiguousAliases.contains(matchingAlias)) {
      final yearFromTitle = RegExp(r'\b(19|20)\d{2}\b').firstMatch(item.title)?.group(0);
      final knownYear = item.releaseYear ?? int.tryParse(yearFromTitle ?? '');
      if (knownYear != movie.year) return false;
    }
    return true;
  }).toList(growable: false);
  return result;
}

class _UniverseGuide {
  const _UniverseGuide({required this.name, required this.period, required this.aliases});
  final String name;
  final String period;
  final List<String> aliases;
}

const List<_UniverseGuide> _curatedUniverses = <_UniverseGuide>[
  _UniverseGuide(name: 'Marvel Cinematic Universe (MCU)', period: '2008–present', aliases: <String>['Marvel Cinematic Universe (MCU)', 'Marvel Cinematic Universe', 'MCU']),
  _UniverseGuide(name: 'DC Extended Universe (DCEU)', period: '2013–2023', aliases: <String>['DC Extended Universe (DCEU)', 'DC Extended Universe', 'DCEU']),
  _UniverseGuide(name: 'MonsterVerse', period: '2014–present', aliases: <String>['MonsterVerse', 'Legendary MonsterVerse', 'Legendary Monsterverse']),
];

class _CuratedUniverseTile extends StatelessWidget {
  const _CuratedUniverseTile({required this.guide, required this.metadataGroups});
  final _UniverseGuide guide;
  final List<UniverseFranchiseGroup> metadataGroups;

  @override
  Widget build(BuildContext context) {
    final names = guide.aliases.map(UniverseFranchiseIndex.normalize).toSet();
    final matches = metadataGroups.where((group) =>
      names.contains(UniverseFranchiseIndex.normalize(group.name)) || names.contains(UniverseFranchiseIndex.normalize(group.id))
    ).toList(growable: false);
    final linked = <String, MediaItem>{};
    for (final group in matches) {
      for (final item in group.works) {
        linked[item.id] = item;
      }
    }
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.hub_rounded)),
        title: Text(guide.name, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('${guide.period} · ${linked.length} catalog title(s) explicitly linked'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.of(context).push<void>(MaterialPageRoute<void>(
          builder: (_) => _CuratedUniverseDetailsScreen(guide: guide, works: linked.values.toList(growable: false)),
        )),
      ),
    );
  }
}

class _CuratedUniverseDetailsScreen extends StatelessWidget {
  const _CuratedUniverseDetailsScreen({required this.guide, required this.works});
  final _UniverseGuide guide;
  final List<MediaItem> works;

  @override
  Widget build(BuildContext context) {
    final sorted = works.toList()..sort((a, b) {
      final yearOrder = (a.releaseYear ?? 0).compareTo(b.releaseYear ?? 0);
      return yearOrder == 0 ? a.title.toLowerCase().compareTo(b.title.toLowerCase()) : yearOrder;
    });
    return Scaffold(
      appBar: AppBar(title: Text(guide.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(guide.period, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(works.isEmpty
              ? 'No titles are explicitly linked to this universe in the current profile catalog yet. Add verified universe membership metadata to populate this page. No titles are inferred or fabricated.'
              : '${works.length} catalog title(s) are explicitly linked to this universe.',
            style: const TextStyle(color: Colors.white60, height: 1.4)),
          const SizedBox(height: 12),
          for (final item in sorted)
            Card(child: ListTile(
              leading: _Poster(item: item),
              title: Text(item.title),
              subtitle: Text('${item.type}${item.releaseYear == null ? '' : ' · ${item.releaseYear}'}'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _openMedia(context, item),
            )),
        ],
      ),
    );
  }
}

class _MetadataGroupTile extends StatelessWidget {
  const _MetadataGroupTile({required this.group});
  final UniverseFranchiseGroup group;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(group.kind == 'Universe' ? Icons.hub_rounded : Icons.movie_filter_rounded),
      title: Text(group.name, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text('${group.works.length} catalog-linked title(s)'),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => Navigator.of(context).push<void>(MaterialPageRoute<void>(
        builder: (_) => UniverseFranchiseDetailsScreen(group: group),
      )),
    ),
  );
}

class _BrowseIntroCard extends StatelessWidget {
  const _BrowseIntroCard({required this.title, required this.description, required this.icon});
  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 34, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(description, style: const TextStyle(color: Colors.white70, height: 1.4)),
        ])),
      ]),
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900));
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Text(message, style: const TextStyle(color: Colors.white54)),
  );
}

class _Poster extends StatelessWidget {
  const _Poster({required this.item});
  final MediaItem item;
  @override
  Widget build(BuildContext context) {
    final url = item.imageUrl?.trim() ?? '';
    if (url.isEmpty) return const SizedBox(width: 46, height: 64, child: Icon(Icons.movie_outlined));
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: Image.network(url, width: 46, height: 64, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox(width: 46, height: 64, child: Icon(Icons.movie_outlined)),
      ),
    );
  }
}

void _openMedia(BuildContext context, MediaItem item) {
  Navigator.of(context).push<void>(MaterialPageRoute<void>(
    builder: (_) => MediaDetailsScreen(media: item),
  ));
}
