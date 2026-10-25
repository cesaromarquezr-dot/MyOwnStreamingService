import 'package:flutter/material.dart';

import 'app_core.dart';
import 'details.dart';

/// Story-oriented graph and timeline for a franchise, saga, universe or character.
/// Curated paths are labelled as examples; catalog-derived connections are only
/// as complete as the metadata available to the active profile.
class FranchiseStoryGraphScreen extends StatefulWidget {
  const FranchiseStoryGraphScreen({
    super.key,
    this.initialGroupName,
    this.initialItems,
    this.initialQuery,
    this.initialView = 'Graph',
  });

  final String? initialGroupName;
  final List<MediaItem>? initialItems;
  final String? initialQuery;
  final String initialView;

  @override
  State<FranchiseStoryGraphScreen> createState() =>
      _FranchiseStoryGraphScreenState();
}

class _FranchiseStoryGraphScreenState extends State<FranchiseStoryGraphScreen> {
  late final TextEditingController _search;
  late final TextEditingController _actorFrom;
  late final TextEditingController _actorTo;
  List<_ActorConnection> _actorConnectionPath = const <_ActorConnection>[];
  String? _actorConnectionMessage;
  bool _actorConnectionSearched = false;
  late String _view;
  String _continuity = 'All continuities';
  String _timelineOrder = 'Release order';

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(
      text: widget.initialQuery ?? widget.initialGroupName ?? '',
    );
    _actorFrom = TextEditingController();
    _actorTo = TextEditingController();
    _view = widget.initialView == 'Timeline' ? 'Timeline' : 'Graph';
  }

  @override
  void dispose() {
    _search.dispose();
    _actorFrom.dispose();
    _actorTo.dispose();
    super.dispose();
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();

  List<MediaItem> get _visibleItems {
    final profile = AppController.instance.currentProfile;
    return AppController.instance.library.where((item) {
      if (profile == null) return item.accessibleProfileIds.isEmpty;
      return item.isAccessibleTo(profile);
    }).toList(growable: false);
  }

  bool get _isGroupContext =>
      widget.initialItems != null &&
      _normalize(_search.text) == _normalize(widget.initialGroupName ?? '');

  bool get _isSpiderSearch {
    final query = _normalize(_search.text);
    return query.contains('spider man') || query.contains('spiderman');
  }

  bool get _isWandaSearch => _normalize(_search.text).contains('wanda');

  List<_StoryPath> get _matchingCuratedPaths {
    final query = _normalize(_search.text);
    final isMcuSearch = query == 'mcu' || query.contains('marvel cinematic universe');
    if (isMcuSearch) {
      if (_continuity == 'All continuities' || _continuity == 'MCU') {
        return _storyPaths.where((path) => path.continuityKey == 'MCU').toList();
      }
      return const <_StoryPath>[];
    }
    if (_isWandaSearch) {
      if (_continuity == 'All continuities' || _continuity == 'MCU') {
        return _storyPaths.where((path) => path.id == 'wanda-mcu').toList();
      }
      return const <_StoryPath>[];
    }
    if (!_isSpiderSearch) return const <_StoryPath>[];
    return _storyPaths.where((path) {
      switch (_continuity) {
        case 'MCU':
          return path.continuityKey == 'MCU';
        case 'Multiverse':
          return path.continuityKey == 'Multiverse';
        case 'Spider-Verse':
          return path.continuityKey == 'Spider-Verse';
        default:
          return true;
      }
    }).toList();
  }

  List<MediaItem> get _catalogMatches {
    final query = _normalize(_search.text);
    final groupContext = _isGroupContext;
    Iterable<MediaItem> candidates = groupContext
        ? widget.initialItems!
        : _visibleItems;

    if (query.isEmpty && !groupContext) {
      candidates = candidates.where((item) =>
          (item.franchiseName ?? '').trim().isNotEmpty ||
          item.franchiseNames.isNotEmpty ||
          item.cinematicUniverseNames.isNotEmpty ||
          (item.continuityName ?? '').trim().isNotEmpty ||
          item.universeMemberships.isNotEmpty);
    } else if (!groupContext && query.isNotEmpty) {
      final mcuAlias = query == 'mcu' || query.contains('marvel cinematic universe');
      candidates = candidates.where((item) {
        final searchable = <String>[
          item.title,
          ...item.actors,
          ...item.characters,
          ...item.directors,
          ...item.writers,
          ...item.tags,
          ...item.franchiseNames,
          if (item.franchiseName != null) item.franchiseName!,
          if (item.continuityName != null) item.continuityName!,
          ...item.cinematicUniverseNames,
          ...item.universeMemberships.map((membership) =>
              (membership['name'] ?? membership['universeName'] ?? '').toString()),
        ];
        return (mcuAlias && _hasMcuMembership(item)) ||
            searchable.any((value) => _normalize(value).contains(query));
      });
    }

    if (_continuity != 'All continuities') {
      candidates = candidates.where((item) {
        final label = _catalogContinuityLabel(item);
        return label == _continuity;
      });
    }

    final result = candidates.toList();
    result.sort((a, b) {
      final aOrder = _timelineOrder == 'Story chronology'
          ? (a.cinematicUniverseTimelineOrder ?? a.cinematicUniverseReleaseOrder ?? a.franchiseOrder ?? a.releaseYear ?? 9999)
          : (a.cinematicUniverseReleaseOrder ?? a.franchiseOrder ?? a.releaseYear ?? 9999);
      final bOrder = _timelineOrder == 'Story chronology'
          ? (b.cinematicUniverseTimelineOrder ?? b.cinematicUniverseReleaseOrder ?? b.franchiseOrder ?? b.releaseYear ?? 9999)
          : (b.cinematicUniverseReleaseOrder ?? b.franchiseOrder ?? b.releaseYear ?? 9999);
      final orderCompare = aOrder.compareTo(bOrder);
      if (orderCompare != 0) return orderCompare;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return result;
  }

  bool _hasMcuMembership(MediaItem item) {
    final values = <String>[
      ...item.cinematicUniverseNames,
      if (item.continuityName != null) item.continuityName!,
      if (item.franchiseName != null) item.franchiseName!,
      ...item.franchiseNames,
      ...item.universeMemberships.map((membership) =>
          (membership['name'] ?? membership['universeName'] ?? '').toString()),
    ];
    return values.any((value) =>
        _normalize(value).contains('marvel cinematic universe') ||
        _normalize(value) == 'mcu');
  }

  String _catalogContinuityLabel(MediaItem item) {
    final values = <String>[
      ...item.cinematicUniverseNames,
      if (item.continuityName != null) item.continuityName!,
      if (item.franchiseName != null) item.franchiseName!,
      ...item.franchiseNames,
      ...item.tags,
      ...item.universeMemberships.map((membership) =>
          (membership['name'] ?? membership['universeName'] ?? '').toString()),
    ].map(_normalize).toList();
    if (values.any((value) => value.contains('spider verse') || value.contains('spiderverse'))) {
      return 'Spider-Verse';
    }
    if (values.any((value) => value == 'mcu' || value.contains('marvel cinematic universe'))) {
      return 'MCU';
    }
    if (values.any((value) => value.contains('multiverse'))) return 'Multiverse';
    if (values.any((value) => value.contains('spider man') || value.contains('spiderman'))) {
      return 'Multiverse';
    }
    return 'Other';
  }

  MediaItem? _findCatalogItem(_StoryStep step) {
    final aliases = <String>{_normalize(step.title), ...step.aliases.map(_normalize)};
    for (final item in _visibleItems) {
      if (aliases.contains(_normalize(item.title))) return item;
    }
    return null;
  }

  void _findActorConnection() {
    final from = _actorFrom.text.trim();
    final to = _actorTo.text.trim();
    if (from.isEmpty || to.isEmpty) {
      setState(() {
        _actorConnectionSearched = true;
        _actorConnectionPath = const <_ActorConnection>[];
        _actorConnectionMessage = 'Enter both actor names to find a connection.';
      });
      return;
    }
    final fromKey = _normalize(from);
    final toKey = _normalize(to);
    if (fromKey == toKey) {
      setState(() {
        _actorConnectionSearched = true;
        _actorConnectionPath = const <_ActorConnection>[];
        _actorConnectionMessage = 'Choose two different actors.';
      });
      return;
    }

    // Build an actor graph from real cast credits in the active profile's
    // accessible catalog. Each edge is labelled with the title they share.
    final credits = <String, List<MediaItem>>{};
    final displayNames = <String, String>{};
    for (final item in _visibleItems) {
      final uniqueActors = <String>{};
      for (final rawName in item.actors) {
        final name = rawName.trim();
        final key = _normalize(name);
        if (key.isEmpty || !uniqueActors.add(key)) continue;
        displayNames.putIfAbsent(key, () => name);
        (credits[key] ??= <MediaItem>[]).add(item);
      }
    }

    String? resolveActor(String key) {
      if (displayNames.containsKey(key)) return key;
      final matches = displayNames.keys.where((candidate) =>
          candidate.contains(key) || key.contains(candidate)).toList();
      return matches.length == 1 ? matches.single : null;
    }

    final start = resolveActor(fromKey);
    final goal = resolveActor(toKey);
    if (start == null || goal == null) {
      final missing = <String>[];
      if (start == null) missing.add(from);
      if (goal == null) missing.add(to);
      setState(() {
        _actorConnectionSearched = true;
        _actorConnectionPath = const <_ActorConnection>[];
        _actorConnectionMessage = 'Could not uniquely match ${missing.join(' and ')} in the accessible catalog cast credits. Add or import verified cast metadata for those actors and try again.';
      });
      return;
    }

    final queue = <String>[start];
    final visited = <String>{start};
    final parent = <String, ({String actor, MediaItem title})>{};
    var found = false;
    while (queue.isNotEmpty && !found) {
      final current = queue.removeAt(0);
      for (final title in credits[current] ?? const <MediaItem>[]) {
        for (final rawName in title.actors) {
          final next = _normalize(rawName);
          if (next.isEmpty || next == current || !displayNames.containsKey(next)) continue;
          if (visited.add(next)) {
            parent[next] = (actor: current, title: title);
            if (next == goal) {
              found = true;
              break;
            }
            queue.add(next);
          }
        }
        if (found) break;
      }
    }

    if (!found) {
      setState(() {
        _actorConnectionSearched = true;
        _actorConnectionPath = const <_ActorConnection>[];
        _actorConnectionMessage = 'No cast-credit path was found between ${displayNames[start]} and ${displayNames[goal]} in the accessible catalog. This is a catalog-coverage result, not proof that no real-world connection exists.';
      });
      return;
    }

    final reversed = <_ActorConnection>[];
    var cursor = goal;
    while (cursor != start) {
      final step = parent[cursor]!;
      reversed.add(_ActorConnection(
        fromActor: displayNames[step.actor] ?? step.actor,
        title: step.title,
        toActor: displayNames[cursor] ?? cursor,
      ));
      cursor = step.actor;
    }
    setState(() {
      _actorConnectionSearched = true;
      _actorConnectionPath = reversed.reversed.toList(growable: false);
      _actorConnectionMessage = null;
    });
  }

  void _chooseSearch(String value) {
    _search.text = value;
    setState(() => _continuity = 'All continuities');
  }

  @override
  Widget build(BuildContext context) {
    final curatedPaths = _matchingCuratedPaths;
    final catalogItems = _catalogMatches;
    final groupLabel = _isGroupContext ? widget.initialGroupName : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_view == 'Graph' ? 'Connections Graph' : 'Franchise Timeline'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Explore how titles connect, then switch between relationship paths and a timeline. Curated paths are examples; catalog-derived results depend on available metadata.',
            style: TextStyle(color: Colors.white.withValues(alpha: .78), height: 1.4),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.people_alt_outlined),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Actor-to-actor connections', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                  ]),
                  const SizedBox(height: 6),
                  const Text('Find the shortest chain of co-stars. Each arrow names the movie or show where two actors share cast credits.', style: TextStyle(color: Colors.white60, height: 1.35)),
                  const SizedBox(height: 12),
                  TextField(controller: _actorFrom, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Connect actor', hintText: 'Florence Pugh', border: OutlineInputBorder())),
                  const SizedBox(height: 8),
                  TextField(controller: _actorTo, textInputAction: TextInputAction.search, onSubmitted: (_) => _findActorConnection(), decoration: const InputDecoration(labelText: 'To actor', hintText: 'Robin Williams', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _findActorConnection, icon: const Icon(Icons.hub_outlined), label: const Text('Find actor connection'))),
                  if (_actorConnectionSearched) ...[
                    const Divider(height: 24),
                    if (_actorConnectionMessage != null)
                      Text(_actorConnectionMessage!, style: const TextStyle(color: Colors.amberAccent, height: 1.35))
                    else ...[
                      Text('Connection path · ${_actorConnectionPath.length} link(s)', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      for (final link in _actorConnectionPath) _ActorConnectionTile(link: link),
                      const SizedBox(height: 4),
                      const Text('Connections are calculated from cast names in your accessible catalog. Missing or incomplete credits can hide valid real-world paths.', style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.35)),
                    ],
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              labelText: 'Search a character, saga, franchise or title',
              hintText: 'Try Wanda, Spider-Man or MCU',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.person_outline, size: 17),
                label: const Text('Wanda'),
                onPressed: () => _chooseSearch('Wanda'),
              ),
              ActionChip(
                avatar: const Icon(Icons.movie_filter_outlined, size: 17),
                label: const Text('Spider-Man'),
                onPressed: () => _chooseSearch('Spider-Man'),
              ),
              ActionChip(
                avatar: const Icon(Icons.hub_outlined, size: 17),
                label: const Text('MCU'),
                onPressed: () => _chooseSearch('MCU'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _continuity,
            decoration: const InputDecoration(
              labelText: 'Continuity / story world',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'All continuities', child: Text('All continuities')),
              DropdownMenuItem(value: 'MCU', child: Text('MCU')),
              DropdownMenuItem(value: 'Multiverse', child: Text('Multiverse (live-action Spider-Man)')),
              DropdownMenuItem(value: 'Spider-Verse', child: Text('Spider-Verse (animated)')),
            ],
            onChanged: (value) => setState(() => _continuity = value ?? 'All continuities'),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Connections graph'),
                selected: _view == 'Graph',
                avatar: const Icon(Icons.hub_outlined, size: 18),
                onSelected: (_) => setState(() => _view = 'Graph'),
              ),
              ChoiceChip(
                label: const Text('Timeline'),
                selected: _view == 'Timeline',
                avatar: const Icon(Icons.timeline_rounded, size: 18),
                onSelected: (_) => setState(() => _view = 'Timeline'),
              ),
            ],
          ),
          if (_view == 'Timeline') ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _timelineOrder,
              decoration: const InputDecoration(
                labelText: 'Timeline order',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'Release order', child: Text('Release order')),
                DropdownMenuItem(value: 'Story chronology', child: Text('Story chronology (when known)')),
              ],
              onChanged: (value) => setState(() => _timelineOrder = value ?? 'Release order'),
            ),
          ],
          const SizedBox(height: 16),
          if (groupLabel != null) ...[
            Text(groupLabel, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('${catalogItems.length} matching catalog title(s)', style: const TextStyle(color: Colors.white60)),
            const SizedBox(height: 12),
          ],
          if (curatedPaths.isNotEmpty) ...[
            Text(
              _isWandaSearch ? 'Wanda Maximoff — connected story path' : 'Spider-Man — continuity paths',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Text(
              _view == 'Graph'
                  ? 'Arrows show the example viewing/story connections. The two live-action Spider-Man branches converge at No Way Home.'
                  : 'Timeline rows use release dates by default. Story chronology uses an in-universe year where one is supplied, otherwise release year is used.',
              style: const TextStyle(color: Colors.white60, height: 1.35),
            ),
            const SizedBox(height: 12),
            if (_view == 'Graph')
              for (final path in curatedPaths) _buildPathGraph(context, path)
            else
              _buildCuratedTimeline(context, curatedPaths),
            if (catalogItems.isNotEmpty) ...[
              const Divider(height: 30),
              Text(
                groupLabel == null ? 'Also matching the visible catalog' : 'Full catalog group',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 5),
              Text(
                _view == 'Graph'
                    ? 'These extra nodes come from the active profile’s catalog metadata, alongside the curated story paths above.'
                    : 'Catalog titles are included alongside the curated path. Sort uses release year or available story-order metadata.',
                style: const TextStyle(color: Colors.white60, height: 1.35),
              ),
              const SizedBox(height: 10),
              if (_view == 'Graph') _buildCatalogGraph(context, catalogItems, groupLabel)
              else _buildCatalogTimeline(context, catalogItems),
            ],
          ] else if (catalogItems.isNotEmpty) ...[
            Text(
              _view == 'Graph' ? 'Catalog relationship graph' : 'Catalog timeline',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Text(
              _view == 'Graph'
                  ? 'These titles share the selected franchise, universe or continuity metadata. An explicit prerequisite is shown when catalog metadata provides one; the display order alone does not claim a direct plot dependency.'
                  : 'Titles are sorted using verified story-order metadata when available, then release/order metadata as a fallback.',
              style: const TextStyle(color: Colors.white60, height: 1.35),
            ),
            const SizedBox(height: 10),
            if (_view == 'Graph') _buildCatalogGraph(context, catalogItems, groupLabel)
            else _buildCatalogTimeline(context, catalogItems),
          ] else if (_search.text.trim().isEmpty) ...[
            const _ExplorerHintCard(
              icon: Icons.hub_rounded,
              title: 'Choose a character or universe',
              description: 'Search Wanda to follow her MCU story, Spider-Man to split live-action multiverse, Spider-Verse and MCU paths, or enter a saga/franchise name.',
            ),
            const SizedBox(height: 10),
            _buildCatalogBrowseGroups(context),
          ] else ...[
            const _ExplorerHintCard(
              icon: Icons.info_outline_rounded,
              title: 'No matching links found',
              description: 'No accessible catalog titles or curated story path matched this search and continuity. Add verified character, continuity, franchise and prerequisite metadata to expand this graph.',
            ),
          ],
          const SizedBox(height: 20),
          const Text(
            'Catalog coverage note: this screen combines the current profile-accessible catalog with selected curated example paths. A title that is not in the catalog can still appear in an example path, but its detail page opens only after matching metadata/title records exist.',
            style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildPathGraph(BuildContext context, _StoryPath path) {
    final steps = path.steps;
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(path.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            const SizedBox(height: 4),
            Text(path.description, style: const TextStyle(color: Colors.white60, height: 1.35)),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  for (var index = 0; index < steps.length; index++) ...[
                    if (index > 0)
                      _GraphConnector(label: steps[index].relationFromPrevious),
                    _StoryNodeCard(
                      step: steps[index],
                      item: _findCatalogItem(steps[index]),
                      year: _timelineOrder == 'Story chronology'
                          ? (steps[index].storyYear ?? steps[index].releaseYear)
                          : steps[index].releaseYear,
                      onTap: () => _openStep(context, steps[index]),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCuratedTimeline(BuildContext context, List<_StoryPath> paths) {
    final seen = <String>{};
    final entryOrder = <String, int>{};
    final entries = <_StoryStep>[];
    for (final path in paths) {
      for (final step in path.steps) {
        final key = '${_normalize(step.title)}::${step.continuity}';
        if (seen.add(key)) {
          entryOrder[key] = entries.length;
          entries.add(step);
        }
      }
    }
    entries.sort((a, b) {
      final aYear = _timelineOrder == 'Story chronology'
          ? (a.storyYear ?? a.releaseYear ?? 9999)
          : (a.releaseYear ?? 9999);
      final bYear = _timelineOrder == 'Story chronology'
          ? (b.storyYear ?? b.releaseYear ?? 9999)
          : (b.releaseYear ?? 9999);
      final compare = aYear.compareTo(bYear);
      if (compare != 0) return compare;
      final aKey = '${_normalize(a.title)}::${a.continuity}';
      final bKey = '${_normalize(b.title)}::${b.continuity}';
      return entryOrder[aKey]!.compareTo(entryOrder[bKey]!);
    });
    return Column(
      children: [
        for (var index = 0; index < entries.length; index++)
          _TimelineTitleTile(
            step: entries[index],
            year: _timelineOrder == 'Story chronology'
                ? (entries[index].storyYear ?? entries[index].releaseYear)
                : entries[index].releaseYear,
            subtitle: entries[index].continuity,
            isLast: index == entries.length - 1,
            onTap: () => _openStep(context, entries[index]),
          ),
      ],
    );
  }

  Widget _buildCatalogGraph(
    BuildContext context,
    List<MediaItem> items,
    String? groupLabel,
  ) {
    final byId = <String, MediaItem>{for (final item in items) item.id: item};
    final edges = <({MediaItem source, MediaItem target})>[];
    for (final target in items) {
      for (final prerequisiteId in target.narrativePrerequisiteIds) {
        final source = byId[prerequisiteId];
        if (source != null && source.id != target.id &&
            !edges.any((edge) => edge.source.id == source.id && edge.target.id == target.id)) {
          edges.add((source: source, target: target));
        }
      }
    }

    // A second, data-driven relationship type: the same named fictional
    // character appears in two titles. This is distinct from shared cast or
    // franchise membership, and is shown even when no prerequisite was entered.
    String characterKey(String value) => value.trim().toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
    final characterEdges = <({MediaItem source, MediaItem target, List<String> characters})>[];
    for (var i = 0; i < items.length; i++) {
      final left = items[i];
      final leftCharacters = <String, String>{};
      for (final character in left.characters) {
        final key = characterKey(character);
        if (key.isNotEmpty) leftCharacters.putIfAbsent(key, () => character.trim());
      }
      if (leftCharacters.isEmpty) continue;
      for (var j = i + 1; j < items.length; j++) {
        final right = items[j];
        final rightCharacters = <String, String>{};
        for (final character in right.characters) {
          final key = characterKey(character);
          if (key.isNotEmpty) rightCharacters.putIfAbsent(key, () => character.trim());
        }
        final sharedKeys = leftCharacters.keys.where(rightCharacters.containsKey).toList();
        if (sharedKeys.isNotEmpty) {
          characterEdges.add((
            source: left,
            target: right,
            characters: sharedKeys.map((key) => leftCharacters[key]!).toList()..sort(),
          ));
        }
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              const Icon(Icons.hub_rounded, size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(groupLabel ?? _search.text.trim(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                  const Text('Shared universe / franchise hub', style: TextStyle(color: Colors.white60)),
                ]),
              ),
              Text('${items.length} titles', style: const TextStyle(color: Colors.white60, fontSize: 12)),
            ]),
          ),
        ),
        if (edges.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(top: 14, bottom: 8),
            child: Text('Story connections · arrows', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          for (final edge in edges)
            Card(
              child: ListTile(
                leading: const Icon(Icons.arrow_forward_rounded),
                title: Text('${edge.source.title}  →  ${edge.target.title}'),
                subtitle: const Text('Recorded story prerequisite: the source title leads into the target title'),
                onTap: () => Navigator.of(context).push<void>(MaterialPageRoute<void>(
                  builder: (_) => MediaDetailsScreen(media: edge.target),
                )),
              ),
            ),
        ],
        if (characterEdges.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(top: 14, bottom: 8),
            child: Text('Shared characters · title-to-title links', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Each arrow connects two titles whose catalog metadata names the same character. These links show character overlap, not necessarily a direct plot prerequisite.', style: TextStyle(color: Colors.white60, height: 1.35)),
          ),
          for (final edge in characterEdges)
            Card(
              child: ListTile(
                leading: const Icon(Icons.people_alt_rounded),
                title: Text('${edge.source.title}  ⟶  ${edge.target.title}'),
                subtitle: Text('Appears in both: ${edge.characters.join(', ')}'),
                isThreeLine: edge.characters.length > 2,
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  builder: (sheetContext) => SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Shared characters', style: Theme.of(sheetContext).textTheme.titleLarge),
                          const SizedBox(height: 8),
                          Text('${edge.source.title}  →  ${edge.target.title}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          for (final character in edge.characters)
                            ListTile(dense: true, leading: const Icon(Icons.person_outline_rounded), title: Text(character)),
                          const SizedBox(height: 8),
                          Wrap(spacing: 8, children: [
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(sheetContext).pop();
                                Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => MediaDetailsScreen(media: edge.source)));
                              },
                              icon: const Icon(Icons.movie_outlined), label: Text(edge.source.title),
                            ),
                            FilledButton.icon(
                              onPressed: () {
                                Navigator.of(sheetContext).pop();
                                Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => MediaDetailsScreen(media: edge.target)));
                              },
                              icon: const Icon(Icons.movie_outlined), label: Text(edge.target.title),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
        if (edges.isEmpty && characterEdges.isEmpty)
          const Card(child: Padding(
            padding: EdgeInsets.all(14),
            child: Text('No direct title-to-title links can be proven from the current metadata yet. Add shared character names or narrative prerequisite IDs to the titles to draw specific connections. The titles below remain grouped by their verified franchise/universe membership.', style: TextStyle(color: Colors.white70, height: 1.35)),
          )),
        const Padding(
          padding: EdgeInsets.only(top: 14, bottom: 8),
          child: Text('Titles linked to this hub', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in items)
              ActionChip(
                avatar: Icon(_iconForItem(item), size: 16),
                label: Text('${item.title}${item.releaseYear == null ? '' : ' (${item.releaseYear})'}'),
                onPressed: () => Navigator.of(context).push<void>(MaterialPageRoute<void>(
                  builder: (_) => MediaDetailsScreen(media: item),
                )),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildCatalogTimeline(BuildContext context, List<MediaItem> items) {
    return Column(
      children: [
        for (var index = 0; index < items.length; index++)
          _TimelineTitleTile(
            title: items[index].title,
            year: items[index].releaseYear ?? items[index].seriesStartYear,
            yearLabel: _timelineOrder == 'Story chronology'
                ? items[index].cinematicUniverseTimelineLabel
                : null,
            subtitle: '${items[index].type}${items[index].continuityName == null ? '' : ' · ${items[index].continuityName}'}${_timelineOrder == 'Story chronology' && items[index].cinematicUniverseTimelineLabel?.trim().isNotEmpty == true ? ' · Story order: ${items[index].cinematicUniverseTimelineLabel}' : ''}',
            imageUrl: items[index].imageUrl,
            isLast: index == items.length - 1,
            onTap: () => Navigator.of(context).push<void>(MaterialPageRoute<void>(
              builder: (_) => MediaDetailsScreen(media: items[index]),
            )),
          ),
      ],
    );
  }

  Widget _buildCatalogBrowseGroups(BuildContext context) {
    final groups = <String, List<MediaItem>>{};
    for (final item in _visibleItems) {
      final names = <String>{
        if ((item.franchiseName ?? '').trim().isNotEmpty) item.franchiseName!.trim(),
        ...item.franchiseNames.map((name) => name.trim()).where((name) => name.isNotEmpty),
        ...item.cinematicUniverseNames.map((name) => name.trim()).where((name) => name.isNotEmpty),
        if ((item.continuityName ?? '').trim().isNotEmpty) item.continuityName!.trim(),
      };
      for (final name in names) {
        groups.putIfAbsent(name, () => <MediaItem>[]);
        if (!groups[name]!.any((existing) => existing.id == item.id)) {
          groups[name]!.add(item);
        }
      }
    }
    final entries = groups.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
    if (entries.isEmpty) {
      return const _ExplorerHintCard(
        icon: Icons.library_books_outlined,
        title: 'No grouped catalog titles yet',
        description: 'Add verified franchise, universe or continuity metadata to titles to make them appear here.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Browse catalog groups', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        for (final entry in entries.take(40))
          Card(
            child: ListTile(
              leading: const Icon(Icons.account_tree_outlined),
              title: Text(entry.key),
              subtitle: Text('${entry.value.length} connected catalog title(s)'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                _search.text = entry.key;
                setState(() {
                  _continuity = 'All continuities';
                });
              },
            ),
          ),
      ],
    );
  }

  IconData _iconForItem(MediaItem item) {
    final type = item.type.toLowerCase();
    if (type.contains('series') || type.contains('show') || type.contains('episode')) {
      return Icons.tv_rounded;
    }
    return Icons.movie_outlined;
  }

  void _openStep(BuildContext context, _StoryStep step) {
    final item = _findCatalogItem(step);
    if (item != null) {
      Navigator.of(context).push<void>(MaterialPageRoute<void>(
        builder: (_) => MediaDetailsScreen(media: item),
      ));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${step.title} is shown in the example path, but no matching title is in the visible catalog yet.'),
      action: SnackBarAction(
        label: 'Search title',
        onPressed: () {
          _search.text = step.title;
          setState(() {
            _continuity = 'All continuities';
          });
        },
      ),
    ));
  }
}

class _ActorConnection {
  const _ActorConnection({required this.fromActor, required this.title, required this.toActor});
  final String fromActor;
  final MediaItem title;
  final String toActor;
}

class _ActorConnectionTile extends StatelessWidget {
  const _ActorConnectionTile({required this.link});
  final _ActorConnection link;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: _actorPill(link.fromActor)),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 5), child: Icon(Icons.arrow_forward_rounded, size: 20, color: Colors.lightBlueAccent)),
            Expanded(
              child: Column(
                children: [
                  const Icon(Icons.movie_outlined, size: 17, color: Colors.white60),
                  Text(link.title.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, height: 1.2)),
                  if (link.title.releaseYear != null) Text(link.title.releaseYear.toString(), style: const TextStyle(fontSize: 10, color: Colors.white54)),
                ],
              ),
            ),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 5), child: Icon(Icons.arrow_forward_rounded, size: 20, color: Colors.lightBlueAccent)),
            Expanded(child: _actorPill(link.toActor)),
          ],
        ),
      );

  Widget _actorPill(String name) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 9),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .06), borderRadius: BorderRadius.circular(9), border: Border.all(color: Colors.white12)),
        child: Text(name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, height: 1.2)),
      );
}

class _GraphConnector extends StatelessWidget {
  const _GraphConnector({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 98,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_forward_rounded, color: Colors.white70, size: 25),
            if (label.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.white60, height: 1.2)),
              ),
          ],
        ),
      );
}

class _StoryNodeCard extends StatelessWidget {
  const _StoryNodeCard({
    required this.step,
    required this.item,
    required this.year,
    required this.onTap,
  });

  final _StoryStep step;
  final MediaItem? item;
  final int? year;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 190,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    Icon(item == null ? Icons.movie_outlined : Icons.check_circle_outline, size: 17, color: item == null ? Colors.white38 : Colors.greenAccent),
                    const SizedBox(width: 6),
                    Expanded(child: Text(year?.toString() ?? 'Year unknown', style: const TextStyle(color: Colors.white60, fontSize: 12))),
                  ]),
                  const SizedBox(height: 8),
                  Text(step.title, style: const TextStyle(fontWeight: FontWeight.w800, height: 1.2)),
                  const SizedBox(height: 7),
                  Text(step.type, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  if (item == null) ...[
                    const SizedBox(height: 5),
                    const Text('Example node · not in catalog', style: TextStyle(color: Colors.amberAccent, fontSize: 10)),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
}

class _TimelineTitleTile extends StatelessWidget {
  const _TimelineTitleTile({
    this.step,
    this.title,
    required this.year,
    required this.subtitle,
    this.imageUrl,
    this.yearLabel,
    required this.isLast,
    required this.onTap,
  });

  final _StoryStep? step;
  final String? title;
  final int? year;
  final String? yearLabel;
  final String subtitle;
  final String? imageUrl;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final displayTitle = title ?? step!.title;
    final image = imageUrl;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 58,
          child: Column(
            children: [
              CircleAvatar(
                radius: 23,
                child: FittedBox(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text(
                      yearLabel?.trim().isNotEmpty == true
                          ? yearLabel!
                          : (year?.toString() ?? '—'),
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Container(width: 2, height: 62, margin: const EdgeInsets.symmetric(vertical: 3), color: Colors.white24),
            ],
          ),
        ),
        Expanded(
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: image != null && image.isNotEmpty
                  ? SizedBox(width: 46, height: 58, child: Image.network(image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.movie_outlined)))
                  : const SizedBox(width: 42, child: Icon(Icons.movie_outlined)),
              title: Text(displayTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(subtitle, style: const TextStyle(color: Colors.white60)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: onTap,
            ),
          ),
        ),
      ],
    );
  }
}

class _ExplorerHintCard extends StatelessWidget {
  const _ExplorerHintCard({required this.icon, required this.title, required this.description});
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 30, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              Text(description, style: const TextStyle(color: Colors.white60, height: 1.4)),
            ])),
          ]),
        ),
      );
}

class _StoryPath {
  const _StoryPath({
    required this.id,
    required this.name,
    required this.description,
    required this.continuityKey,
    required this.steps,
  });
  final String id;
  final String name;
  final String description;
  final String continuityKey;
  final List<_StoryStep> steps;
}

class _StoryStep {
  const _StoryStep({
    required this.title,
    required this.continuity,
    required this.type,
    this.releaseYear,
    this.storyYear,
    this.relationFromPrevious = '',
    this.aliases = const <String>[],
  });
  final String title;
  final String continuity;
  final String type;
  final int? releaseYear;
  final int? storyYear;
  final String relationFromPrevious;
  final List<String> aliases;
}

const List<_StoryPath> _storyPaths = <_StoryPath>[
  _StoryPath(
    id: 'wanda-mcu',
    name: 'MCU · Wanda Maximoff',
    description: 'A character-focused path from the Winter Soldier post-credit scene through WandaVision and Doctor Strange in the Multiverse of Madness.',
    continuityKey: 'MCU',
    steps: <_StoryStep>[
      _StoryStep(title: 'Captain America: The Winter Soldier', continuity: 'MCU', type: 'Movie · post-credit setup', releaseYear: 2014, storyYear: 2014, aliases: <String>['The Winter Soldier']),
      _StoryStep(title: 'Avengers: Age of Ultron', continuity: 'MCU', type: 'Movie', releaseYear: 2015, storyYear: 2015, relationFromPrevious: 'Hydra post-credit setup leads into Wanda and Pietro', aliases: <String>['Age of Ultron']),
      _StoryStep(title: 'Captain America: Civil War', continuity: 'MCU', type: 'Movie', releaseYear: 2016, storyYear: 2016, relationFromPrevious: 'Sokovia fallout and the Avengers split'),
      _StoryStep(title: 'Avengers: Endgame', continuity: 'MCU', type: 'Movie', releaseYear: 2019, storyYear: 2023, relationFromPrevious: 'The Blip and final battle change Wanda’s circumstances'),
      _StoryStep(title: 'WandaVision', continuity: 'MCU', type: 'TV series', releaseYear: 2021, storyYear: 2023, relationFromPrevious: 'Wanda processes the aftermath of Endgame'),
      _StoryStep(title: 'Doctor Strange in the Multiverse of Madness', continuity: 'MCU', type: 'Movie', releaseYear: 2022, storyYear: 2023, relationFromPrevious: 'Wanda’s story expands into the multiverse', aliases: <String>['Doctor Strange 2']),
    ],
  ),
  _StoryPath(
    id: 'spider-raimi',
    name: 'Multiverse · Tobey Maguire / Raimi films',
    description: 'The original live-action film branch that converges with No Way Home.',
    continuityKey: 'Multiverse',
    steps: <_StoryStep>[
      _StoryStep(title: 'Spider-Man', continuity: 'Multiverse', type: 'Movie', releaseYear: 2002, storyYear: 2002),
      _StoryStep(title: 'Spider-Man 2', continuity: 'Multiverse', type: 'Movie', releaseYear: 2004, storyYear: 2004),
      _StoryStep(title: 'Spider-Man 3', continuity: 'Multiverse', type: 'Movie', releaseYear: 2007, storyYear: 2007),
      _StoryStep(title: 'Spider-Man: No Way Home', continuity: 'Multiverse crossover', type: 'Movie · crossover', releaseYear: 2021, storyYear: 2024, relationFromPrevious: 'Raimi universe crosses into the MCU multiverse', aliases: <String>['No Way Home']),
    ],
  ),
  _StoryPath(
    id: 'spider-amazing',
    name: 'Multiverse · The Amazing Spider-Man films',
    description: 'A second live-action branch that also converges with No Way Home.',
    continuityKey: 'Multiverse',
    steps: <_StoryStep>[
      _StoryStep(title: 'The Amazing Spider-Man', continuity: 'Multiverse', type: 'Movie', releaseYear: 2012, storyYear: 2012, aliases: <String>['Amazing Spider-Man']),
      _StoryStep(title: 'The Amazing Spider-Man 2', continuity: 'Multiverse', type: 'Movie', releaseYear: 2014, storyYear: 2014, aliases: <String>['Amazing Spider-Man 2']),
      _StoryStep(title: 'Spider-Man: No Way Home', continuity: 'Multiverse crossover', type: 'Movie · crossover', releaseYear: 2021, storyYear: 2024, relationFromPrevious: 'Amazing Spider-Man universe crosses into the MCU multiverse', aliases: <String>['No Way Home']),
    ],
  ),
  _StoryPath(
    id: 'spider-verse',
    name: 'Spider-Verse · Miles Morales animated films',
    description: 'Keep the animated Spider-Verse as its own continuity lane.',
    continuityKey: 'Spider-Verse',
    steps: <_StoryStep>[
      _StoryStep(title: 'Spider-Man: Into the Spider-Verse', continuity: 'Spider-Verse', type: 'Animated movie', releaseYear: 2018, storyYear: 2018, aliases: <String>['Into the Spider-Verse']),
      _StoryStep(title: 'Spider-Man: Across the Spider-Verse', continuity: 'Spider-Verse', type: 'Animated movie', releaseYear: 2023, storyYear: 2023, relationFromPrevious: 'Direct continuation', aliases: <String>['Across the Spider-Verse']),
      _StoryStep(title: 'Spider-Man: Beyond the Spider-Verse', continuity: 'Spider-Verse', type: 'Upcoming animated movie', releaseYear: 2027, storyYear: 2027, relationFromPrevious: 'Planned next chapter', aliases: <String>['Beyond the Spider-Verse']),
    ],
  ),
  _StoryPath(
    id: 'spider-mcu',
    name: 'MCU · Peter Parker',
    description: 'The example MCU path requested. Iron Man 2 is shown as shared MCU context, not as a Spider-Man appearance.',
    continuityKey: 'MCU',
    steps: <_StoryStep>[
      _StoryStep(title: 'Iron Man 2', continuity: 'MCU', type: 'Movie · MCU context', releaseYear: 2010, storyYear: 2010),
      _StoryStep(title: 'Captain America: Civil War', continuity: 'MCU', type: 'Movie · Peter Parker introduced', releaseYear: 2016, storyYear: 2016, relationFromPrevious: 'Shared MCU continuity; Peter Parker enters the story'),
      _StoryStep(title: 'Spider-Man: Homecoming', continuity: 'MCU', type: 'Movie', releaseYear: 2017, storyYear: 2016, relationFromPrevious: 'Peter’s first solo MCU film'),
      _StoryStep(title: 'Avengers: Infinity War', continuity: 'MCU', type: 'Movie', releaseYear: 2018, storyYear: 2018, relationFromPrevious: 'Spider-Man joins the wider Avengers conflict'),
      _StoryStep(title: 'Avengers: Endgame', continuity: 'MCU', type: 'Movie', releaseYear: 2019, storyYear: 2023, relationFromPrevious: 'The aftermath reshapes Peter’s world'),
      _StoryStep(title: 'Spider-Man: Far From Home', continuity: 'MCU', type: 'Movie', releaseYear: 2019, storyYear: 2024, relationFromPrevious: 'Peter travels after the events of Endgame'),
      _StoryStep(title: 'Spider-Man: Brand New Day', continuity: 'MCU', type: 'Movie', releaseYear: 2026, storyYear: 2026, relationFromPrevious: 'Next MCU Spider-Man chapter', aliases: <String>['Brand New Day']),
    ],
  ),
];
