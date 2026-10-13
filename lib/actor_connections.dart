import 'package:flutter/material.dart';

import 'app_core.dart';

/// Finds a verifiable shortest connection through cast/crew credits already
/// indexed in the active library. Every graph edge names the shared work.
class ActorConnectionScreen extends StatefulWidget {
  const ActorConnectionScreen({super.key, this.initialPerson});
  final String? initialPerson;

  @override
  State<ActorConnectionScreen> createState() => _ActorConnectionScreenState();
}

class _ConnectionEdge {
  const _ConnectionEdge(this.person, this.workTitle, this.workYear);
  final String person;
  final String workTitle;
  final int? workYear;
}

class _ConnectionStep {
  const _ConnectionStep(this.person, {this.viaTitle, this.viaYear});
  final String person;
  final String? viaTitle;
  final int? viaYear;
}

class _ActorConnectionScreenState extends State<ActorConnectionScreen> {
  late final TextEditingController _fromController;
  final TextEditingController _toController = TextEditingController();
  List<_ConnectionStep> _path = const [];
  bool _searched = false;
  String? _error;

  List<MediaItem> get _works => AppController.instance.library;
  String _key(String name) => name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  List<String> _peopleIn(MediaItem item) {
    final seen = <String>{};
    final people = <String>[];
    for (final raw in <String>[...item.actors, ...item.directors, ...item.writers, ...item.music]) {
      final name = raw.trim();
      if (name.isNotEmpty && seen.add(_key(name))) people.add(name);
    }
    return people;
  }

  Map<String, List<_ConnectionEdge>> _graph() {
    final graph = <String, List<_ConnectionEdge>>{};
    for (final work in _works) {
      final people = _peopleIn(work);
      for (final person in people) {
        final edges = graph.putIfAbsent(_key(person), () => <_ConnectionEdge>[]);
        for (final other in people) {
          if (_key(other) == _key(person)) continue;
          edges.add(_ConnectionEdge(other, work.title, work.releaseYear));
        }
      }
    }
    for (final edges in graph.values) {
      edges.sort((a, b) => a.workTitle.toLowerCase().compareTo(b.workTitle.toLowerCase()));
    }
    return graph;
  }

  String _displayName(String key) {
    for (final work in _works) {
      for (final person in _peopleIn(work)) {
        if (_key(person) == key) return person;
      }
    }
    return key;
  }

  void _findPath() {
    final from = _fromController.text.trim();
    final to = _toController.text.trim();
    if (from.isEmpty || to.isEmpty) {
      setState(() { _searched = true; _path = const []; _error = 'Enter both names to find a connection.'; });
      return;
    }
    final graph = _graph();
    final source = _key(from);
    final target = _key(to);
    if (!graph.containsKey(source) || !graph.containsKey(target)) {
      setState(() { _searched = true; _path = const []; _error = 'One or both people are missing from credits in your indexed library.'; });
      return;
    }
    if (source == target) {
      setState(() { _searched = true; _path = [_ConnectionStep(_displayName(source))]; _error = null; });
      return;
    }

    final visited = <String>{source};
    final queue = <String>[source];
    final previous = <String, ({String parent, _ConnectionEdge edge})>{};
    while (queue.isNotEmpty && !visited.contains(target)) {
      final current = queue.removeAt(0);
      for (final edge in graph[current] ?? const <_ConnectionEdge>[]) {
        final next = _key(edge.person);
        if (!visited.add(next)) continue;
        previous[next] = (parent: current, edge: edge);
        queue.add(next);
        if (next == target) break;
      }
    }
    if (!visited.contains(target)) {
      setState(() { _searched = true; _path = const []; _error = 'No connection was found in the media currently indexed on this server.'; });
      return;
    }

    final reverseNames = <String>[target];
    final reverseEdges = <_ConnectionEdge>[];
    var cursor = target;
    while (cursor != source) {
      final entry = previous[cursor]!;
      reverseEdges.add(entry.edge);
      cursor = entry.parent;
      reverseNames.add(cursor);
    }
    final names = reverseNames.reversed.toList();
    final edges = reverseEdges.reversed.toList();
    final path = <_ConnectionStep>[
      for (var i = 0; i < names.length; i++)
        _ConnectionStep(
          _displayName(names[i]),
          viaTitle: i == 0 ? null : edges[i - 1].workTitle,
          viaYear: i == 0 ? null : edges[i - 1].workYear,
        ),
    ];
    setState(() { _searched = true; _path = path; _error = null; });
  }

  @override
  void initState() {
    super.initState();
    _fromController = TextEditingController(text: widget.initialPerson ?? '');
  }

  @override
  void dispose() { _fromController.dispose(); _toController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final allPeople = _works.expand(_peopleIn).toSet().toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return Scaffold(
      appBar: AppBar(title: const Text('People Connections')),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        const Text('Find the shortest connection between actors, singers, directors, writers, and credited music contributors through works in your library.', style: TextStyle(color: Colors.white70, height: 1.35)),
        const SizedBox(height: 16),
        TextField(
          controller: _fromController,
          decoration: InputDecoration(
            labelText: 'Starting person',
            hintText: 'e.g. Zendaya',
            prefixIcon: const Icon(Icons.person_search_rounded),
            helperText: allPeople.isEmpty
                ? 'Import cast and music credits to build the graph.'
                : 'Indexed people: ${allPeople.length}',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _toController,
          decoration: const InputDecoration(
            labelText: 'Destination person',
            hintText: 'e.g. Robin Williams',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(onPressed: _findPath, icon: const Icon(Icons.account_tree_rounded), label: const Text('Find connection')),
        if (_searched && _error != null) ...[
          const SizedBox(height: 16),
          Card(child: Padding(padding: const EdgeInsets.all(14), child: Text(_error!))),
        ],
        if (_path.isNotEmpty) ...[
          const SizedBox(height: 18),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${_path.length - 1} connection${_path.length == 2 ? '' : 's'}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 12),
            for (var i = 0; i < _path.length; i++) ...[
              Row(children: [CircleAvatar(radius: 16, child: Text('${i + 1}')), const SizedBox(width: 10), Expanded(child: Text(_path[i].person, style: const TextStyle(fontWeight: FontWeight.w800)))]),
              if (i < _path.length - 1) Padding(
                padding: const EdgeInsets.only(left: 25, top: 6, bottom: 6),
                child: Row(children: [Container(width: 2, height: 22, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 10), Expanded(child: Text('via ${_path[i + 1].viaTitle ?? 'shared work'}${_path[i + 1].viaYear == null ? '' : ' (${_path[i + 1].viaYear})'}', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12)))]),
              ),
            ],
          ]))),
        ],
        if (allPeople.isEmpty) const Padding(padding: EdgeInsets.only(top: 12), child: Text('Import cast and crew credits to build the connection graph.', style: TextStyle(color: Colors.white54))),
      ]),
    );
  }
}
