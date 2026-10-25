import 'package:flutter/material.dart';
import 'app_core.dart';
import 'actor_connections.dart';

const _phaseAccent = Color(0xFF8B7CFF);

/// Entry point for the three agreed phases: better cast discovery, a unified
/// connections experience, and practical library personalization/health.
class ThreePhaseDiscoveryHubScreen extends StatefulWidget {
  const ThreePhaseDiscoveryHubScreen({super.key});
  @override
  State<ThreePhaseDiscoveryHubScreen> createState() => _ThreePhaseDiscoveryHubScreenState();
}

class _ThreePhaseDiscoveryHubScreenState extends State<ThreePhaseDiscoveryHubScreen> {
  final Set<String> _selectedIds = <String>{};
  bool _includeCrew = false;

  String _key(String value) => value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  List<String> _people(MediaItem item) => <String>[
    ...item.actors,
    if (_includeCrew) ...item.directors,
    if (_includeCrew) ...item.writers,
    if (_includeCrew) ...item.music,
  ].where((name) => name.trim().isNotEmpty).toSet().toList();

  @override
  Widget build(BuildContext context) {
    final controller = AppController.instance;
    final library = controller.library;
    final selected = library.where((item) => _selectedIds.contains(item.id)).toList();
    final appearances = <String, Map<String, String>>{};
    final displayNames = <String, String>{};
    for (final item in selected) {
      for (final person in _people(item)) {
        final key = _key(person);
        displayNames.putIfAbsent(key, () => person.trim());
        appearances.putIfAbsent(key, () => <String, String>{})[item.id] = item.title;
      }
    }
    final common = appearances.entries.where((entry) => entry.value.length == selected.length && selected.length >= 2).toList()
      ..sort((a, b) => displayNames[a.key]!.toLowerCase().compareTo(displayNames[b.key]!.toLowerCase()));

    final watched = controller.watched;
    final watchedGenres = <String>{for (final item in watched) ...item.genres.map(_key)};
    final watchedPeople = <String>{for (final item in watched) ...item.actors.map(_key)};
    final recommendations = library.where((item) =>
      !watched.any((w) => w.id == item.id) &&
      (item.genres.any((g) => watchedGenres.contains(_key(g))) || item.actors.any((a) => watchedPeople.contains(_key(a))))
    ).toList()..sort((a, b) {
      int score(MediaItem item) => item.genres.where((g) => watchedGenres.contains(_key(g))).length * 2 + item.actors.where((a) => watchedPeople.contains(_key(a))).length;
      return score(b).compareTo(score(a));
    });

    final missingArt = library.where((item) => (item.imageUrl ?? '').trim().isEmpty).length;
    final missingDescription = library.where((item) => (item.description ?? '').trim().isEmpty).length;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B10),
      appBar: AppBar(title: const Text('Three-Phase Discovery'), backgroundColor: const Color(0xFF11111A)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Phase 1 · Where Have I Seen Them?', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        const Text('Select two or more titles from your indexed library. Compare cast members, or include directors, writers and music credits. Names are matched after whitespace/case normalization; this does not fetch missing online credits.', style: TextStyle(color: Colors.white60, height: 1.35)),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: _includeCrew, title: const Text('Include directors, writers and music credits', style: TextStyle(color: Colors.white)), onChanged: (value) => setState(() => _includeCrew = value)),
        if (library.isEmpty) const Text('Add/import titles with cast metadata to begin.', style: TextStyle(color: Colors.white60)),
        ...library.map((item) => CheckboxListTile(
          dense: true, contentPadding: EdgeInsets.zero, activeColor: _phaseAccent,
          value: _selectedIds.contains(item.id),
          title: Text(item.title, style: const TextStyle(color: Colors.white)),
          subtitle: Text('${item.type}${item.releaseYear == null ? '' : ' · ${item.releaseYear}'}', style: const TextStyle(color: Colors.white54)),
          onChanged: (value) => setState(() { if (value == true) { _selectedIds.add(item.id); } else { _selectedIds.remove(item.id); } }),
        )),
        if (selected.length >= 2) ...[
          const Divider(color: Colors.white24),
          Text('Shared credits · ${common.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          if (common.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('No common names found in the selected titles’ currently indexed metadata.', style: TextStyle(color: Colors.white60))),
          ...common.map((entry) => Card(color: const Color(0xFF171722), child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person_search)),
            title: Text(displayNames[entry.key]!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            subtitle: Text(entry.value.values.join(' · '), style: const TextStyle(color: Colors.white60)),
            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ActorConnectionScreen(initialPerson: displayNames[entry.key]))),
          ))),
        ] else const Text('Choose at least two titles to see shared cast/crew.', style: TextStyle(color: Colors.white54)),
        const SizedBox(height: 24),
        const Divider(color: Colors.white24),
        const Text('Phase 2 · Universal Connections Explorer', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('Explore person-to-person paths already supported by indexed cast, director, writer and music credits. Broader song, album, band membership and collaboration paths appear only when that metadata exists; every displayed path is limited to indexed evidence.', style: TextStyle(color: Colors.white60, height: 1.35)),
        const SizedBox(height: 10),
        FilledButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ActorConnectionScreen())), icon: const Icon(Icons.account_tree_rounded), label: const Text('Open People Connections')),
        const SizedBox(height: 24),
        const Divider(color: Colors.white24),
        const Text('Phase 3 · Personalization & Library Health', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('Recommendations are inferred locally from genres and actors in your watched history. They are suggestions, not guarantees of availability or streaming rights.', style: TextStyle(color: Colors.white60, height: 1.35)),
        const SizedBox(height: 8),
        Text('Recommended from your history · ${recommendations.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        if (recommendations.isEmpty) const Text('Watch or import more titles with genre/cast metadata to improve recommendations.', style: TextStyle(color: Colors.white54)),
        ...recommendations.take(8).map((item) => Card(color: const Color(0xFF171722), child: ListTile(
          leading: const Icon(Icons.auto_awesome, color: _phaseAccent),
          title: Text(item.title, style: const TextStyle(color: Colors.white)),
          subtitle: Text(item.genres.where((g) => watchedGenres.contains(_key(g))).take(3).join(' · ').isNotEmpty ? 'Because you watched similar genres: ${item.genres.where((g) => watchedGenres.contains(_key(g))).take(3).join(' · ')}' : 'Shares cast with something you watched', style: const TextStyle(color: Colors.white60)),
        ))),
        const SizedBox(height: 12),
        Card(color: const Color(0xFF171722), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Library health snapshot', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _healthRow('Catalog titles', library.length),
          _healthRow('Missing artwork', missingArt),
          _healthRow('Missing descriptions', missingDescription),
          const SizedBox(height: 6),
          const Text('This is a metadata check only. It does not delete files, test remote playback, or verify that a provider grants access.', style: TextStyle(color: Colors.white54, fontSize: 12)),
        ]))),
      ]),
    );
  }

  Widget _healthRow(String label, int count) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [Expanded(child: Text(label, style: const TextStyle(color: Colors.white70))), Text('$count', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]));
}
