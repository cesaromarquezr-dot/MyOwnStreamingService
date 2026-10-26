import 'package:flutter/material.dart';

import 'app_core.dart';
import 'details.dart';
import 'localization.dart';
import 'franchise_story_graph.dart';

/// A grouping backed only by metadata explicitly attached to catalog works.
/// Missing metadata is intentionally not inferred from actor overlap or title text.
class UniverseFranchiseGroup {
  final String id;
  final String name;
  final String kind;
  final List<MediaItem> works;

  const UniverseFranchiseGroup({
    required this.id,
    required this.name,
    required this.kind,
    required this.works,
  });
}

class PersonAcrossUniverses {
  final String name;
  final List<String> universeNames;
  final List<MediaItem> works;

  const PersonAcrossUniverses({
    required this.name,
    required this.universeNames,
    required this.works,
  });
}

/// Shared grouping helpers used by both the explorer and actor detail pages.
class UniverseFranchiseIndex {
  static String normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  static List<MediaItem> visibleWorks(Iterable<MediaItem> source) {
    final profile = AppController.instance.currentProfile;
    return source.where((item) {
      if (profile == null) {
        // Do not expose records explicitly scoped to a profile after logout.
        return item.accessibleProfileIds.isEmpty;
      }
      return item.isAccessibleTo(profile);
    }).toList(growable: false);
  }

  static List<MediaItem> worksForPerson(
    Iterable<MediaItem> source,
    String personName,
  ) {
    final target = normalize(personName);
    if (target.isEmpty) return const <MediaItem>[];
    return visibleWorks(source
        .where((item) => item.actors.any((name) => normalize(name) == target)));
  }

  static List<UniverseFranchiseGroup> groups(
    Iterable<MediaItem> source, {
    String? kind,
    String? personName,
  }) {
    final byKey = <String, Map<String, dynamic>>{};
    final personKey = personName == null ? '' : normalize(personName);
    for (final item in visibleWorks(source)) {
      if (personKey.isNotEmpty &&
          !item.actors.any((name) => normalize(name) == personKey)) {
        continue;
      }
      void add({
        required String groupKind,
        required String id,
        required String name,
      }) {
        final cleanName = name.trim();
        final cleanId = id.trim().isEmpty ? normalize(cleanName) : id.trim();
        if (cleanName.isEmpty || cleanId.isEmpty) return;
        if (kind != null && kind != 'All' && kind != groupKind) return;
        final key = '$groupKind::$cleanId';
        final record = byKey.putIfAbsent(
            key,
            () => <String, dynamic>{
                  'id': cleanId,
                  'name': cleanName,
                  'kind': groupKind,
                  'works': <String, MediaItem>{},
                });
        (record['works'] as Map<String, MediaItem>)[item.id] = item;
      }

      for (final membership in item.universeMemberships) {
        final name = (membership['name'] ??
                membership['universeName'] ??
                membership['title'] ??
                '')
            .toString()
            .trim();
        final id = (membership['id'] ??
                membership['universeId'] ??
                membership['slug'] ??
                '')
            .toString();
        add(groupKind: 'Universe', id: id, name: name);
        final continuityName = (membership['continuityName'] ?? '').toString();
        final continuityId = (membership['continuityId'] ?? '').toString();
        if (continuityName.trim().isNotEmpty) {
          add(
            groupKind: 'Continuity',
            id: continuityId,
            name: continuityName,
          );
        }
      }
      if ((item.continuityName ?? '').trim().isNotEmpty) {
        add(
          groupKind: 'Continuity',
          id: item.continuityId ?? '',
          name: item.continuityName!,
        );
      }
      final legacyFranchiseName = (item.franchiseName ?? '').trim();
      final legacyFranchiseKey = normalize(legacyFranchiseName);
      final franchiseNamesIncludeLegacy = legacyFranchiseKey.isNotEmpty &&
          item.franchiseNames.any(
            (name) => normalize(name) == legacyFranchiseKey,
          );
      for (final franchiseName in item.franchiseNames) {
        final usesLegacyId = normalize(franchiseName) == legacyFranchiseKey;
        add(
          groupKind: 'Franchise',
          id: usesLegacyId ? (item.franchiseId ?? '') : '',
          name: franchiseName,
        );
      }
      if (legacyFranchiseName.isNotEmpty && !franchiseNamesIncludeLegacy) {
        add(
          groupKind: 'Franchise',
          id: item.franchiseId ?? '',
          name: legacyFranchiseName,
        );
      }
    }

    final results = byKey.values.map((record) {
      final works = (record['works'] as Map<String, MediaItem>).values.toList()
        ..sort((a, b) {
          final yearCompare =
              (a.releaseYear ?? 0).compareTo(b.releaseYear ?? 0);
          return yearCompare != 0
              ? yearCompare
              : a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
      return UniverseFranchiseGroup(
        id: record['id'] as String,
        name: record['name'] as String,
        kind: record['kind'] as String,
        works: works,
      );
    }).toList();
    results.sort((a, b) {
      final kindCompare = a.kind.compareTo(b.kind);
      return kindCompare != 0
          ? kindCompare
          : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return results;
  }

  static List<PersonAcrossUniverses> peopleAcrossUniverses(
    Iterable<MediaItem> source,
  ) {
    final people = <String, Map<String, dynamic>>{};
    for (final item in visibleWorks(source)) {
      final memberships = item.universeMemberships;
      if (memberships.isEmpty) continue;
      final universeNames = <String>{};
      for (final membership in memberships) {
        final name = (membership['name'] ??
                membership['universeName'] ??
                membership['title'] ??
                '')
            .toString()
            .trim();
        if (name.isNotEmpty) universeNames.add(name);
      }
      if (universeNames.isEmpty) continue;
      for (final actor in item.actors) {
        final clean = actor.trim();
        final key = normalize(clean);
        if (key.isEmpty) continue;
        final entry = people.putIfAbsent(
            key,
            () => <String, dynamic>{
                  'name': clean,
                  'universes': <String>{},
                  'works': <String, MediaItem>{},
                });
        (entry['universes'] as Set<String>).addAll(universeNames);
        (entry['works'] as Map<String, MediaItem>)[item.id] = item;
      }
    }
    final result = <PersonAcrossUniverses>[];
    for (final entry in people.values) {
      final universes = (entry['universes'] as Set<String>).toList()..sort();
      if (universes.length < 2) continue;
      final works = (entry['works'] as Map<String, MediaItem>).values.toList()
        ..sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      result.add(PersonAcrossUniverses(
        name: entry['name'] as String,
        universeNames: universes,
        works: works,
      ));
    }
    result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }
}

class CinematicUniverseFranchiseExplorerScreen extends StatefulWidget {
  const CinematicUniverseFranchiseExplorerScreen({
    super.key,
    this.initialPerson,
    this.onActorTap,
  });

  final String? initialPerson;
  final ValueChanged<String>? onActorTap;

  @override
  State<CinematicUniverseFranchiseExplorerScreen> createState() =>
      _CinematicUniverseFranchiseExplorerScreenState();
}

class _CinematicUniverseFranchiseExplorerScreenState
    extends State<CinematicUniverseFranchiseExplorerScreen> {
  final TextEditingController _search = TextEditingController();
  String _category = 'All';

  @override
  void initState() {
    super.initState();
    _search.text = widget.initialPerson ?? '';
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final works = UniverseFranchiseIndex.visibleWorks(
      AppController.instance.library,
    );
    final groups = UniverseFranchiseIndex.groups(
      works,
      kind: _category,
    ).where((group) {
      final query = UniverseFranchiseIndex.normalize(_search.text);
      if (query.isEmpty) return true;
      return UniverseFranchiseIndex.normalize(group.name).contains(query) ||
          group.works.any((item) =>
              UniverseFranchiseIndex.normalize(item.title).contains(query));
    }).toList();
    final people = _category == 'People across universes'
        ? UniverseFranchiseIndex.peopleAcrossUniverses(works).where((person) {
            final query = UniverseFranchiseIndex.normalize(_search.text);
            return query.isEmpty ||
                UniverseFranchiseIndex.normalize(person.name).contains(query) ||
                person.universeNames.any((name) =>
                    UniverseFranchiseIndex.normalize(name).contains(query));
          }).toList()
        : const <PersonAcrossUniverses>[];

    return Scaffold(
      appBar: AppBar(title: const UniversalText('Universes & Franchises')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text(
            'Follow the connections between productions without merging separate fictional worlds.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Search universes, franchises, people or titles',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Explore'),
            items: const [
              DropdownMenuItem(value: 'All', child: Text('All connections')),
              DropdownMenuItem(
                  value: 'Universe', child: Text('Cinematic universes')),
              DropdownMenuItem(value: 'Franchise', child: Text('Franchises')),
              DropdownMenuItem(
                  value: 'Continuity', child: Text('Continuities & timelines')),
              DropdownMenuItem(
                  value: 'People across universes',
                  child: Text('People across universes')),
            ],
            onChanged: (value) => setState(() => _category = value ?? 'All'),
          ),
          const SizedBox(height: 16),
          if (_category == 'People across universes') ...[
            if (people.isEmpty)
              const _UniverseEmptyState(
                message:
                    'No cross-universe performers are linked yet. Add explicit universe memberships to credited titles to populate this section.',
              )
            else
              for (final person in people)
                Card(
                  child: ListTile(
                    leading:
                        const CircleAvatar(child: Icon(Icons.person_outline)),
                    title: Text(person.name),
                    subtitle: Text(
                        '${person.universeNames.join(' · ')}\n${person.works.length} linked title${person.works.length == 1 ? '' : 's'}'),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: widget.onActorTap == null
                        ? null
                        : () => widget.onActorTap!(person.name),
                  ),
                ),
          ] else if (groups.isEmpty)
            const _UniverseEmptyState(
              message:
                  'No verified universe, franchise or continuity metadata matches this search yet. The explorer does not guess memberships from title names or shared actors.',
            )
          else
            for (final group in groups)
              Card(
                child: ListTile(
                  leading: Icon(_iconForKind(group.kind)),
                  title: Text(group.name),
                  subtitle: Text(
                      '${group.kind} · ${group.works.length} linked title${group.works.length == 1 ? '' : 's'}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          UniverseFranchiseDetailsScreen(group: group),
                    ),
                  ),
                ),
              ),
          const SizedBox(height: 10),
          const Text(
            'Only metadata-linked titles are shown. A performer appearing in two productions connects their filmographies, but does not make those productions part of the same universe.',
            style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}

/// Presentation modes for titles inside a saga, franchise, or universe.
enum _UniverseCollectionView { list, grid, gallery, table }

class UniverseFranchiseDetailsScreen extends StatefulWidget {
  const UniverseFranchiseDetailsScreen({super.key, required this.group});
  final UniverseFranchiseGroup group;

  @override
  State<UniverseFranchiseDetailsScreen> createState() =>
      _UniverseFranchiseDetailsScreenState();
}

class _UniverseFranchiseDetailsScreenState
    extends State<UniverseFranchiseDetailsScreen> {
  _UniverseCollectionView _view = _UniverseCollectionView.list;

  void _openMedia(MediaItem item) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => MediaDetailsScreen(media: item)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    return Scaffold(
      appBar: AppBar(title: Text(group.name)),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            group.kind,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${group.works.length} connected title${group.works.length == 1 ? '' : 's'}',
            style: const TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => FranchiseStoryGraphScreen(
                      initialGroupName: group.name,
                      initialItems: group.works,
                      initialView: 'Graph',
                    ),
                  ),
                ),
                icon: const Icon(Icons.account_tree_rounded),
                label: const Text('Connections graph'),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => FranchiseStoryGraphScreen(
                      initialGroupName: group.name,
                      initialItems: group.works,
                      initialView: 'Timeline',
                    ),
                  ),
                ),
                icon: const Icon(Icons.timeline_rounded),
                label: const Text('Story / release timeline'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Choose a view',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _viewChip(
                  label: 'List',
                  icon: Icons.view_list_rounded,
                  view: _UniverseCollectionView.list,
                ),
                const SizedBox(width: 8),
                _viewChip(
                  label: 'Poster grid',
                  icon: Icons.grid_view_rounded,
                  view: _UniverseCollectionView.grid,
                ),
                const SizedBox(width: 8),
                _viewChip(
                  label: 'Gallery',
                  icon: Icons.photo_library_outlined,
                  view: _UniverseCollectionView.gallery,
                ),
                const SizedBox(width: 8),
                _viewChip(
                  label: 'Table',
                  icon: Icons.table_chart_outlined,
                  view: _UniverseCollectionView.table,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildCollectionView(context),
        ],
      ),
    );
  }

  Widget _viewChip({
    required String label,
    required IconData icon,
    required _UniverseCollectionView view,
  }) =>
      ChoiceChip(
        selected: _view == view,
        avatar: Icon(icon, size: 18),
        label: Text(label),
        onSelected: (_) => setState(() => _view = view),
      );

  Widget _buildCollectionView(BuildContext context) {
    final works = widget.group.works;
    if (works.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 36),
        child: Text(
          'No linked titles are available for this collection yet.',
          style: TextStyle(color: Colors.white60),
          textAlign: TextAlign.center,
        ),
      );
    }

    switch (_view) {
      case _UniverseCollectionView.list:
        return Column(
          children: [
            for (final item in works)
              Card(
                child: ListTile(
                  leading: _CollectionPoster(item: item, width: 52, height: 72),
                  title: Text(item.title),
                  subtitle: Text(
                    '${item.type}${item.releaseYear == null ? '' : ' · ${item.releaseYear}'}'
                    '${item.franchiseName == null ? '' : '\nFranchise: ${item.franchiseName}'}'
                    '${item.continuityName == null ? '' : '\nContinuity: ${item.continuityName}'}',
                  ),
                  isThreeLine:
                      item.franchiseName != null || item.continuityName != null,
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => _openMedia(item),
                ),
              ),
          ],
        );
      case _UniverseCollectionView.grid:
        return LayoutBuilder(
          builder: (context, constraints) {
            final columns =
                (constraints.maxWidth / 155).floor().clamp(2, 5).toInt();
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: works.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: .62,
              ),
              itemBuilder: (context, index) => _CollectionPosterCard(
                item: works[index],
                onTap: () => _openMedia(works[index]),
                showType: false,
              ),
            );
          },
        );
      case _UniverseCollectionView.gallery:
        return SizedBox(
          height: 285,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: works.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) => SizedBox(
              width: 190,
              child: _CollectionPosterCard(
                item: works[index],
                onTap: () => _openMedia(works[index]),
                showType: true,
              ),
            ),
          ),
        );
      case _UniverseCollectionView.table:
        return Card(
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Title')),
                DataColumn(label: Text('Type')),
                DataColumn(label: Text('Year')),
                DataColumn(label: Text('Franchise')),
                DataColumn(label: Text('Continuity')),
              ],
              rows: [
                for (final item in works)
                  DataRow(
                    cells: [
                      DataCell(Text(item.title), onTap: () => _openMedia(item)),
                      DataCell(Text(item.type)),
                      DataCell(Text(item.releaseYear?.toString() ?? '—')),
                      DataCell(Text((item.franchiseName ?? '').trim().isEmpty
                          ? '—'
                          : item.franchiseName!)),
                      DataCell(Text((item.continuityName ?? '').trim().isEmpty
                          ? '—'
                          : item.continuityName!)),
                    ],
                  ),
              ],
            ),
          ),
        );
    }
  }
}

class _CollectionPosterCard extends StatelessWidget {
  const _CollectionPosterCard({
    required this.item,
    required this.onTap,
    required this.showType,
  });

  final MediaItem item;
  final VoidCallback onTap;
  final bool showType;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                  child: _CollectionPoster(
                      item: item,
                      width: double.infinity,
                      height: double.infinity)),
              Padding(
                padding: const EdgeInsets.fromLTRB(9, 8, 9, 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${item.releaseYear ?? 'Year unknown'}${showType ? ' · ${item.type}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _CollectionPoster extends StatelessWidget {
  const _CollectionPoster({
    required this.item,
    required this.width,
    required this.height,
  });

  final MediaItem item;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final url = item.imageUrl?.trim() ?? '';
    final targetWidth = width.isFinite ? width : null;
    final targetHeight = height.isFinite ? height : null;
    if (url.isEmpty) {
      return SizedBox(
        width: targetWidth,
        height: targetHeight,
        child: const ColoredBox(
          color: Color(0xFF222222),
          child: Center(
              child:
                  Icon(Icons.movie_outlined, color: Colors.white54, size: 28)),
        ),
      );
    }
    return Image.network(
      url,
      width: targetWidth,
      height: targetHeight,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => SizedBox(
        width: targetWidth,
        height: targetHeight,
        child: const ColoredBox(
          color: Color(0xFF222222),
          child: Center(
              child: Icon(Icons.broken_image_outlined,
                  color: Colors.white54, size: 28)),
        ),
      ),
    );
  }
}

/// Reusable section embedded in each actor detail page.
class ActorUniverseFranchiseSection extends StatelessWidget {
  const ActorUniverseFranchiseSection({super.key, required this.actorName});
  final String actorName;

  @override
  Widget build(BuildContext context) {
    final works = UniverseFranchiseIndex.worksForPerson(
      AppController.instance.library,
      actorName,
    );
    if (works.isEmpty) return const SizedBox.shrink();
    final groups = UniverseFranchiseIndex.groups(
      works,
      personName: actorName,
    );
    final linkedWorkIds = <String>{
      for (final group in groups) ...group.works.map((item) => item.id)
    };
    final otherWorks =
        works.where((item) => !linkedWorkIds.contains(item.id)).toList();

    return _ActorUniverseSectionCard(
      actorName: actorName,
      groups: groups,
      otherWorks: otherWorks,
    );
  }
}

class _ActorUniverseSectionCard extends StatelessWidget {
  const _ActorUniverseSectionCard({
    required this.actorName,
    required this.groups,
    required this.otherWorks,
  });
  final String actorName;
  final List<UniverseFranchiseGroup> groups;
  final List<MediaItem> otherWorks;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: .06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.hub_outlined),
              SizedBox(width: 9),
              Text('Universes & Franchises',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 4),
            Text(
                'Projects connected to $actorName, grouped by recorded universe, continuity and franchise.',
                style: const TextStyle(color: Colors.white60, height: 1.4)),
            const SizedBox(height: 10),
            if (groups.isEmpty)
              const Text(
                  'No universe or franchise memberships are recorded for these titles yet.',
                  style: TextStyle(color: Colors.white54))
            else
              for (final group in groups)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  leading: Icon(_iconForKind(group.kind)),
                  title: Text(group.name),
                  subtitle: Text(
                      '${group.kind} · ${group.works.length} title${group.works.length == 1 ? '' : 's'}'),
                  children: [
                    for (final item in group.works)
                      ListTile(
                        contentPadding: const EdgeInsets.only(left: 8),
                        title: Text(item.title),
                        subtitle: Text(
                            '${item.releaseYear ?? 'Year unknown'} · ${item.type}'),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () => Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                                builder: (_) =>
                                    MediaDetailsScreen(media: item))),
                      ),
                  ],
                ),
            if (otherWorks.isNotEmpty) ...[
              const Divider(height: 22),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                leading: const Icon(Icons.movie_filter_outlined),
                title: const Text('Other productions'),
                subtitle: Text(
                    '${otherWorks.length} title${otherWorks.length == 1 ? '' : 's'} without linked universe/franchise metadata'),
                children: [
                  for (final item in otherWorks)
                    ListTile(
                      contentPadding: const EdgeInsets.only(left: 8),
                      title: Text(item.title),
                      subtitle: Text(
                          '${item.releaseYear ?? 'Year unknown'} · ${item.type}'),
                      trailing: const Icon(Icons.chevron_right, size: 18),
                      onTap: () => Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                              builder: (_) => MediaDetailsScreen(media: item))),
                    ),
                ],
              ),
            ],
          ],
        ),
      );
}

IconData _iconForKind(String kind) => switch (kind) {
      'Universe' => Icons.public,
      'Franchise' => Icons.movie_filter_outlined,
      'Continuity' => Icons.account_tree_outlined,
      _ => Icons.hub_outlined,
    };

class _UniverseEmptyState extends StatelessWidget {
  const _UniverseEmptyState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 18),
        child: Column(children: [
          const Icon(Icons.hub_outlined, size: 44, color: Colors.white38),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, height: 1.4)),
        ]),
      );
}
