import 'package:flutter/material.dart';

import 'app_core.dart';
import 'details.dart';

/// One person page for acting, music, and all other career credits.
class PeopleCareerTimelineScreen extends StatefulWidget {
  final String personName;
  final List<Map<String, dynamic>> localCredits;

  const PeopleCareerTimelineScreen({
    super.key,
    required this.personName,
    this.localCredits = const [],
  });

  @override
  State<PeopleCareerTimelineScreen> createState() => _PeopleCareerTimelineScreenState();
}

class _PeopleCareerTimelineScreenState extends State<PeopleCareerTimelineScreen> {
  static const _categories = ['All', 'Acting', 'Music', 'Producing', 'Writing', 'Directing', 'Awards'];
  String _selected = 'All';
  String? _personId;
  List<Map<String, dynamic>> _catalogCredits = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    final api = AppController.instance.backendApi;
    if (!api.isAuthenticated) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final matches = await api.searchMediaPeople(query: widget.personName);
      final normalized = widget.personName.trim().toLowerCase();
      final matchingPeople = matches.where((entry) => (entry['name'] ?? '').toString().trim().toLowerCase() == normalized);
      final person = matchingPeople.isEmpty ? null : matchingPeople.first;
      final id = person?['id']?.toString() ?? 'person:${Uri.encodeComponent(normalized)}';
      if (person == null) await api.createMediaPerson(id: id, name: widget.personName.trim());
      final timeline = await api.getPersonCareerTimeline(personId: id);
      final raw = timeline['credits'];
      final credits = raw is List
          ? raw.whereType<Map>().map((entry) => Map<String, dynamic>.from(entry)).toList()
          : <Map<String, dynamic>>[];
      if (mounted) {
        setState(() {
          _personId = id;
          _catalogCredits = credits;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) setState(() { _loading = false; _error = error.toString(); });
    }
  }

  List<Map<String, dynamic>> get _timeline {
    final items = <Map<String, dynamic>>[...widget.localCredits];
    for (final entry in _catalogCredits) {
      final credit = entry['credit'] is Map ? Map<String, dynamic>.from(entry['credit'] as Map) : <String, dynamic>{};
      final work = entry['work'] is Map ? Map<String, dynamic>.from(entry['work'] as Map) : <String, dynamic>{};
      items.add({
        'id': credit['id'] ?? work['id'],
        'mediaId': work['id'],
        'title': work['title'] ?? 'Untitled work',
        'category': credit['category'] ?? 'Other',
        'type': work['type'] ?? credit['category'] ?? 'Media',
        'role': credit['role'],
        'characterName': credit['characterName'],
        'creditGroup': credit['creditGroup'],
        'year': credit['startYear'] ?? work['releaseYear'],
        'endYear': credit['endYear'],
        'source': credit['source'],
      });
    }
    final seen = <String>{};
    final unique = items.where((item) {
      final key = '${item['title']}|${item['category']}|${item['role']}|${item['characterName']}'.toLowerCase();
      return seen.add(key);
    }).where((item) => _selected == 'All' || _normalize(item['category']) == _normalize(_selected)).toList();
    unique.sort((a, b) => (_year(a['year']) ?? 9999).compareTo(_year(b['year']) ?? 9999));
    return unique;
  }

  String _normalize(Object? value) => (value ?? '').toString().trim().toLowerCase();
  int? _year(Object? value) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');

  @override
  Widget build(BuildContext context) {
    final timeline = _timeline;
    final localMatches = AppController.instance.library;
    return Scaffold(
      appBar: AppBar(title: Text(widget.personName)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Career timeline', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                const Text('Acting, music, and creative work connected to one person identity.', style: TextStyle(color: Colors.white60)),
                if (_loading) const Padding(padding: EdgeInsets.only(top: 14), child: LinearProgressIndicator()),
                if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Showing available library credits. Catalog credits could not load.', style: TextStyle(color: Colors.amber.shade200))),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final category in _categories)
              ChoiceChip(label: Text(category), selected: _selected == category, onSelected: (_) => setState(() => _selected = category)),
          ]),
          const SizedBox(height: 12),
          if (timeline.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(22), child: Text('No career credits are available yet. Add sourced person-to-work credits to build this timeline.')))
          else
            for (final item in timeline)
              _CareerCreditTile(
                item: item,
                onTap: () {
                  final title = (item['title'] ?? '').toString().toLowerCase();
                  MediaItem? match;
                  for (final media in localMatches) {
                    if (media.title.toLowerCase() == title) { match = media; break; }
                  }
                  if (match != null) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => MediaDetailsScreen(media: match!)));
                  }
                },
              ),
          if (_personId != null && _catalogCredits.isEmpty && timeline.isNotEmpty)
            const Padding(padding: EdgeInsets.only(top: 12), child: Text('These entries come from this device library. Add catalog credits to include albums and professional roles across devices.', style: TextStyle(color: Colors.white54))),
        ],
      ),
    );
  }
}

class _CareerCreditTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  const _CareerCreditTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final year = item['year']?.toString();
    final endYear = item['endYear']?.toString();
    final role = (item['characterName'] ?? item['role'] ?? '').toString();
    final group = (item['creditGroup'] ?? '').toString();
    final subtitle = <String>[
      (item['category'] ?? item['type'] ?? 'Credit').toString(),
      if (role.isNotEmpty) role,
      if (group.isNotEmpty) group,
      if (year != null && year.isNotEmpty) endYear != null && endYear.isNotEmpty && endYear != year ? '$year–$endYear' : year,
    ].join(' · ');
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: const Icon(Icons.timeline_rounded),
        title: Text((item['title'] ?? 'Untitled work').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white60)),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
