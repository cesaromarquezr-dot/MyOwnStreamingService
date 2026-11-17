/// A source work that explicitly credits a set of people.
///
/// The graph does not infer relationships from names or titles: two people are
/// connected only when they are both present in the supplied credit record.
class PersonCreditWork {
  const PersonCreditWork({
    required this.title,
    required this.people,
    this.year,
    this.kind = 'Media',
  });

  final String title;
  final List<String> people;
  final int? year;
  final String kind;
}

/// One step in a shortest, explainable people-to-people relationship path.
class PersonRelationshipStep {
  const PersonRelationshipStep(
    this.person, {
    this.viaWorkTitle,
    this.viaWorkYear,
    this.viaWorkKind,
  });

  final String person;
  final String? viaWorkTitle;
  final int? viaWorkYear;
  final String? viaWorkKind;
}

class _PersonRelationshipEdge {
  const _PersonRelationshipEdge({
    required this.targetKey,
    required this.work,
  });

  final String targetKey;
  final PersonCreditWork work;
}

/// Deterministic, explainable graph over explicit cast, crew, and music credits.
///
/// It is intentionally an in-memory projection. It does not persist a second
/// people catalog or claim that an external catalog item is owned media.
class PeopleRelationshipGraph {
  PeopleRelationshipGraph._(this._displayNames, this._adjacency);

  final Map<String, String> _displayNames;
  final Map<String, List<_PersonRelationshipEdge>> _adjacency;

  factory PeopleRelationshipGraph.fromWorks(Iterable<PersonCreditWork> works) {
    final displayNames = <String, String>{};
    final adjacency = <String, List<_PersonRelationshipEdge>>{};

    for (final work in works) {
      final people = <String>[];
      final seen = <String>{};
      for (final rawName in work.people) {
        final name = rawName.trim();
        final key = normalizeName(name);
        if (key.isEmpty || !seen.add(key)) continue;
        displayNames.putIfAbsent(key, () => name);
        adjacency.putIfAbsent(key, () => <_PersonRelationshipEdge>[]);
        people.add(key);
      }

      for (final source in people) {
        final edges = adjacency[source]!;
        for (final target in people) {
          if (source == target) continue;
          edges.add(_PersonRelationshipEdge(targetKey: target, work: work));
        }
      }
    }

    for (final edges in adjacency.values) {
      edges.sort((a, b) {
        final titleOrder = a.work.title.toLowerCase().compareTo(
              b.work.title.toLowerCase(),
            );
        if (titleOrder != 0) return titleOrder;
        return displayNames[a.targetKey]!.toLowerCase().compareTo(
              displayNames[b.targetKey]!.toLowerCase(),
            );
      });
    }

    return PeopleRelationshipGraph._(
      Map<String, String>.unmodifiable(displayNames),
      Map<String, List<_PersonRelationshipEdge>>.unmodifiable({
        for (final entry in adjacency.entries)
          entry.key: List<_PersonRelationshipEdge>.unmodifiable(entry.value),
      }),
    );
  }

  List<String> get people => _displayNames.values.toList(growable: false)
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  bool containsPerson(String name) => _displayNames.containsKey(
        normalizeName(name),
      );

  /// Returns the shortest verifiable connection, or null when no path exists.
  List<PersonRelationshipStep>? shortestPath(String from, String to) {
    final source = normalizeName(from);
    final target = normalizeName(to);
    if (!_adjacency.containsKey(source) || !_adjacency.containsKey(target)) {
      return null;
    }
    if (source == target) {
      return <PersonRelationshipStep>[
        PersonRelationshipStep(_displayNames[source]!),
      ];
    }

    final visited = <String>{source};
    final queue = <String>[source];
    final previous =
        <String, ({String parent, _PersonRelationshipEdge edge})>{};
    var queueIndex = 0;

    while (queueIndex < queue.length && !visited.contains(target)) {
      final current = queue[queueIndex++];
      for (final edge in _adjacency[current] ?? const <_PersonRelationshipEdge>[]) {
        if (!visited.add(edge.targetKey)) continue;
        previous[edge.targetKey] = (parent: current, edge: edge);
        queue.add(edge.targetKey);
        if (edge.targetKey == target) break;
      }
    }
    if (!visited.contains(target)) return null;

    final reverseKeys = <String>[target];
    final reverseEdges = <_PersonRelationshipEdge>[];
    var cursor = target;
    while (cursor != source) {
      final entry = previous[cursor]!;
      reverseEdges.add(entry.edge);
      cursor = entry.parent;
      reverseKeys.add(cursor);
    }

    final keys = reverseKeys.reversed.toList(growable: false);
    final edges = reverseEdges.reversed.toList(growable: false);
    return List<PersonRelationshipStep>.unmodifiable([
      for (var index = 0; index < keys.length; index++)
        PersonRelationshipStep(
          _displayNames[keys[index]]!,
          viaWorkTitle: index == 0 ? null : edges[index - 1].work.title,
          viaWorkYear: index == 0 ? null : edges[index - 1].work.year,
          viaWorkKind: index == 0 ? null : edges[index - 1].work.kind,
        ),
    ]);
  }

  static String normalizeName(String value) => value
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r"[^a-z0-9À-ÖØ-öø-ÿ\u0100-\u024F]+"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
