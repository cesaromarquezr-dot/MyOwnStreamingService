import 'package:material_ui/material_ui.dart';

import 'app_core.dart';
import 'music.dart';
import 'people_relationship_graph.dart';

/// Finds a verifiable shortest path through the active profile's explicit
/// film/TV cast-and-crew credits and music artist/featured-artist credits.
///
/// Catalog-only recordings can help explain a music collaboration, but they
/// are kept as catalog context and never become owned library media here.
class ActorConnectionScreen extends StatefulWidget {
  const ActorConnectionScreen({super.key, this.initialPerson});
  final String? initialPerson;

  @override
  State<ActorConnectionScreen> createState() => _ActorConnectionScreenState();
}

class _ActorConnectionScreenState extends State<ActorConnectionScreen> {
  late final TextEditingController _fromController;
  final TextEditingController _toController = TextEditingController();
  List<PersonRelationshipStep> _path = const <PersonRelationshipStep>[];
  bool _searched = false;
  String? _error;

  List<MediaItem> get _visibleMedia => AppController.instance.library
      .where((item) => item.isAccessibleTo(AppController.instance.currentProfile))
      .toList(growable: false);

  PeopleRelationshipGraph _buildGraph() {
    final works = <PersonCreditWork>[];
    for (final item in _visibleMedia) {
      works.add(PersonCreditWork(
        title: item.title,
        year: item.releaseYear,
        kind: item.type,
        people: <String>[
          ...item.actors,
          ...item.directors,
          ...item.writers,
          ...item.music,
        ],
      ));
    }

    final musicStore = MusicLibraryStore.instance;
    final tracksById = <String, MusicTrack>{};
    for (final track in musicStore.tracks) {
      if (!track.catalogOnly) tracksById[track.id] = track;
    }
    for (final track in musicStore.catalogTracks.values) {
      tracksById.putIfAbsent(track.id, () => track);
    }
    for (final track in tracksById.values) {
      final title = track.album.trim().isEmpty
          ? track.title
          : '${track.title} — ${track.album}';
      works.add(PersonCreditWork(
        title: title,
        kind: track.catalogOnly ? 'Music catalog recording' : 'Song',
        people: <String>[track.artist, ...track.featuredArtists],
      ));
    }
    return PeopleRelationshipGraph.fromWorks(works);
  }

  void _findPath() {
    final from = _fromController.text.trim();
    final to = _toController.text.trim();
    if (from.isEmpty || to.isEmpty) {
      setState(() {
        _searched = true;
        _path = const <PersonRelationshipStep>[];
        _error = 'Enter both names to find a connection.';
      });
      return;
    }

    final graph = _buildGraph();
    if (!graph.containsPerson(from) || !graph.containsPerson(to)) {
      setState(() {
        _searched = true;
        _path = const <PersonRelationshipStep>[];
        _error =
            'One or both people are missing from the active profile’s indexed credits. Add verified cast, crew, artist or featured-artist credits first.';
      });
      return;
    }

    final path = graph.shortestPath(from, to);
    setState(() {
      _searched = true;
      _path = path ?? const <PersonRelationshipStep>[];
      _error = path == null
          ? 'No connection was found in the active profile’s indexed media and music credits.'
          : null;
    });
  }

  @override
  void initState() {
    super.initState();
    _fromController = TextEditingController(text: widget.initialPerson ?? '');
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final graph = _buildGraph();
    final allPeople = graph.people;
    return Scaffold(
      appBar: AppBar(title: const Text('People Connections')),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        const Text(
          'Find a shortest, explainable path between actors, directors, writers, composers, singers and bands. Every connection is backed by a shared indexed title or an explicit music collaboration; the connecting work is shown at each step.',
          style: TextStyle(color: Colors.white70, height: 1.35),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _fromController,
          decoration: InputDecoration(
            labelText: 'Starting person',
            hintText: 'e.g. Florence Pugh',
            prefixIcon: const Icon(Icons.person_search_rounded),
            helperText: allPeople.isEmpty
                ? 'Import cast, soundtrack, artist and collaboration credits to build the graph.'
                : 'Indexed people: ${allPeople.length}',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _toController,
          decoration: const InputDecoration(
            labelText: 'Destination person',
            hintText: 'e.g. Bruno Mars',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
          onSubmitted: (_) => _findPath(),
        ),
        if (allPeople.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: allPeople.take(12).map((person) {
              return ActionChip(
                label: Text(person),
                onPressed: () => setState(() {
                  if (_fromController.text.trim().isEmpty) {
                    _fromController.text = person;
                  } else {
                    _toController.text = person;
                  }
                }),
              );
            }).toList(growable: false),
          ),
        ],
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _findPath,
          icon: const Icon(Icons.account_tree_rounded),
          label: const Text('Find cross-media connection'),
        ),
        if (_searched && _error != null) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(_error!),
            ),
          ),
        ],
        if (_path.isNotEmpty) ...[
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_path.length - 1} connection${_path.length == 2 ? '' : 's'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < _path.length; i++) ...[
                    Row(children: [
                      CircleAvatar(radius: 16, child: Text('${i + 1}')),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _path[i].person,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ]),
                    if (i < _path.length - 1)
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 25,
                          top: 6,
                          bottom: 6,
                        ),
                        child: Row(children: [
                          Container(
                            width: 2,
                            height: 28,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'via ${_path[i + 1].viaWorkTitle ?? 'shared work'}'
                              '${_path[i + 1].viaWorkYear == null ? '' : ' (${_path[i + 1].viaWorkYear})'}'
                              '${_path[i + 1].viaWorkKind?.trim().isNotEmpty == true ? ' · ${_path[i + 1].viaWorkKind}' : ''}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ]),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        const Text(
          'Source note: relationships are generated from explicit credits in the selected profile’s accessible media and music catalog. Catalog-only music can explain a collaboration, but it is not counted as owned or playable library media.',
          style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.4),
        ),
        if (allPeople.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'Import cast, soundtrack, artist, group-membership and collaboration metadata to build richer cross-media paths.',
              style: TextStyle(color: Colors.white54),
            ),
          ),
      ]),
    );
  }
}
