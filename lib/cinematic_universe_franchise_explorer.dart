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
  static String normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();

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
    return visibleWorks(source.where((item) =>
        item.actors.any((name) => normalize(name) == target)));
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
        final record = byKey.putIfAbsent(key, () => <String, dynamic>{
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
        final entry = people.putIfAbsent(key, () => <String, dynamic>{
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
        ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
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
              DropdownMenuItem(value: 'Universe', child: Text('Cinematic universes')),
              DropdownMenuItem(value: 'Franchise', child: Text('Franchises')),
              DropdownMenuItem(value: 'Continuity', child: Text('Continuities & timelines')),
              DropdownMenuItem(value: 'People across universes', child: Text('People across universes')),
            ],
            onChanged: (value) => setState(() => _category = value ?? 'All'),
          ),
          const SizedBox(height: 16),
          if (_category == 'People across universes') ...[
            if (people.isEmpty)
              const _UniverseEmptyState(
                message: 'No cross-universe performers are linked yet. Add explicit universe memberships to credited titles to populate this section.',
              )
            else
              for (final person in people)
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                    title: Text(person.name),
                    subtitle: Text('${person.universeNames.join(' · ')}\n${person.works.length} linked title${person.works.length == 1 ? '' : 's'}'),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: widget.onActorTap == null
                        ? null
                        : () => widget.onActorTap!(person.name),
                  ),
                ),
          ] else if (groups.isEmpty)
            const _UniverseEmptyState(
              message: 'No verified universe, franchise or continuity metadata matches this search yet. The explorer does not guess memberships from title names or shared actors.',
            )
          else
            for (final group in groups)
              Card(
                child: ListTile(
                  leading: Icon(_iconForKind(group.kind)),
                  title: Text(group.name),
                  subtitle: Text('${group.kind} · ${group.works.length} linked title${group.works.length == 1 ? '' : 's'}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => UniverseFranchiseDetailsScreen(group: group),
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

class UniverseFranchiseDetailsScreen extends StatelessWidget {
  const UniverseFranchiseDetailsScreen({super.key, required this.group});
  final UniverseFranchiseGroup group;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(group.name)),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Text(group.kind, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('${group.works.length} connected title${group.works.length == 1 ? '' : 's'}', style: const TextStyle(color: Colors.white60)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push<void>(MaterialPageRoute<void>(
                    builder: (_) => FranchiseStoryGraphScreen(
                      initialGroupName: group.name,
                      initialItems: group.works,
                      initialView: 'Graph',
                    ),
                  )),
                  icon: const Icon(Icons.account_tree_rounded),
                  label: const Text('Full connections graph'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push<void>(MaterialPageRoute<void>(
                    builder: (_) => FranchiseStoryGraphScreen(
                      initialGroupName: group.name,
                      initialItems: group.works,
                      initialView: 'Timeline',
                    ),
                  )),
                  icon: const Icon(Icons.timeline_rounded),
                  label: const Text('Timeline'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final item in group.works)
              Card(
                child: ListTile(
                  leading: item.imageUrl == null || item.imageUrl!.isEmpty
                      ? const SizedBox(width: 52, height: 72, child: Icon(Icons.movie_outlined))
                      : SizedBox(width: 52, height: 72, child: Image.network(item.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.movie_outlined))),
                  title: Text(item.title),
                  subtitle: Text('${item.type}${item.releaseYear == null ? '' : ' · ${item.releaseYear}'}${item.franchiseName == null ? '' : '\nFranchise: ${item.franchiseName}'}${item.continuityName == null ? '' : '\nContinuity: ${item.continuityName}'}'),
                  isThreeLine: item.franchiseName != null || item.continuityName != null,
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => Navigator.push<void>(context, MaterialPageRoute<void>(builder: (_) => MediaDetailsScreen(media: item))),
                ),
              ),
          ],
        ),
      );
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
    final linkedWorkIds = <String>{for (final group in groups) ...group.works.map((item) => item.id)};
    final otherWorks = works.where((item) => !linkedWorkIds.contains(item.id)).toList();

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
              Text('Universes & Franchises', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 4),
            Text('Projects connected to $actorName, grouped by recorded universe, continuity and franchise.', style: const TextStyle(color: Colors.white60, height: 1.4)),
            const SizedBox(height: 10),
            if (groups.isEmpty)
              const Text('No universe or franchise memberships are recorded for these titles yet.', style: TextStyle(color: Colors.white54))
            else
              for (final group in groups)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  leading: Icon(_iconForKind(group.kind)),
                  title: Text(group.name),
                  subtitle: Text('${group.kind} · ${group.works.length} title${group.works.length == 1 ? '' : 's'}'),
                  children: [
                    for (final item in group.works)
                      ListTile(
                        contentPadding: const EdgeInsets.only(left: 8),
                        title: Text(item.title),
                        subtitle: Text('${item.releaseYear ?? 'Year unknown'} · ${item.type}'),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () => Navigator.push<void>(context, MaterialPageRoute<void>(builder: (_) => MediaDetailsScreen(media: item))),
                      ),
                  ],
                ),
            if (otherWorks.isNotEmpty) ...[
              const Divider(height: 22),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                leading: const Icon(Icons.movie_filter_outlined),
                title: const Text('Other productions'),
                subtitle: Text('${otherWorks.length} title${otherWorks.length == 1 ? '' : 's'} without linked universe/franchise metadata'),
                children: [
                  for (final item in otherWorks)
                    ListTile(
                      contentPadding: const EdgeInsets.only(left: 8),
                      title: Text(item.title),
                      subtitle: Text('${item.releaseYear ?? 'Year unknown'} · ${item.type}'),
                      trailing: const Icon(Icons.chevron_right, size: 18),
                      onTap: () => Navigator.push<void>(context, MaterialPageRoute<void>(builder: (_) => MediaDetailsScreen(media: item))),
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
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, height: 1.4)),
        ]),
      );
}
