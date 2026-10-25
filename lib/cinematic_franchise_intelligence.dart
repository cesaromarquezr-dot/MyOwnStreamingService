import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'core/config/app_env.dart';

import 'cinematic_seed_examples.dart';
import 'core/services/cinematic_title_metadata_service.dart';

/// Live metadata discovery. No per-movie filmography is maintained in code:
/// upcoming titles are discovered from TMDB production-company metadata.
/// Configure TMDB_API_KEY in the project-root .env file (or use --dart-define).
class CinematicFranchiseIntelligenceScreen extends StatefulWidget {
  const CinematicFranchiseIntelligenceScreen({super.key});

  @override
  State<CinematicFranchiseIntelligenceScreen> createState() =>
      _CinematicFranchiseIntelligenceScreenState();
}

class _CinematicFranchiseIntelligenceScreenState
    extends State<CinematicFranchiseIntelligenceScreen> {
  static String get _apiKey => AppEnv.tmdbApiKey;
  static const String _base = 'https://api.themoviedb.org/3';
  // Company identifiers are discovery rules, not movie/show title lists.
  static const Map<String, int> _studios = <String, int>{
    'Marvel Studios': 420,
    'DC Studios / DC Films': 128064,
    'Lucasfilm': 1,
    'Legendary Pictures': 923,
    'Sony Pictures': 34,
    'Universal Pictures': 33,
    'Warner Bros.': 174,
    'Paramount Pictures': 4,
    '20th Century Studios': 25,
  };

  bool _loading = false;
  String? _error;
  DateTime? _lastRefresh;
  final List<_DiscoveredTitle> _titles = <_DiscoveredTitle>[];
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    if (_apiKey.isNotEmpty) {
      _refresh();
      // Refresh periodically while this screen is open; reopening also refreshes.
      _autoRefreshTimer = Timer.periodic(const Duration(hours: 12), (_) => _refresh());
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<Map<String, dynamic>> _get(String path, [Map<String, String>? query]) async {
    final params = <String, String>{'api_key': _apiKey, 'language': 'en-US', ...?query};
    final response = await http.get(Uri.parse('$_base$path').replace(queryParameters: params))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('TMDB returned HTTP ${response.statusCode}. Check the API key and provider access.');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> _refresh() async {
    if (_apiKey.isEmpty) {
      setState(() => _error = 'TMDB_API_KEY is not configured. Add it to the project-root .env file and restart the app.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final found = <String, _DiscoveredTitle>{};
      final today = DateTime.now();
      final date = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      // Query by studio rules. This discovers future titles without enumerating titles in source code.
      for (final studio in _studios.entries) {
        final movies = await _get('/discover/movie', <String, String>{
          'with_companies': '${studio.value}',
          'primary_release_date.gte': date,
          'sort_by': 'primary_release_date.asc',
          'include_adult': 'false',
          'page': '1',
        });
        _collect(found, movies['results'], studio.key, false);
        final shows = await _get('/discover/tv', <String, String>{
          'with_companies': '${studio.value}',
          'first_air_date.gte': date,
          'sort_by': 'first_air_date.asc',
          'page': '1',
        });
        _collect(found, shows['results'], studio.key, true);
      }
      final sorted = found.values.toList()
        ..sort((a, b) => (a.releaseDate ?? '9999').compareTo(b.releaseDate ?? '9999'));
      if (!mounted) return;
      setState(() { _titles..clear()..addAll(sorted); _lastRefresh = DateTime.now(); });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _collect(Map<String, _DiscoveredTitle> target, dynamic raw, String studio, bool isTv) {
    if (raw is! List) return;
    for (final value in raw) {
      if (value is! Map) continue;
      final map = Map<String, dynamic>.from(value);
      final id = map['id'];
      final name = (isTv ? map['name'] : map['title'])?.toString().trim() ?? '';
      if (id == null || name.isEmpty) continue;
      final key = '${isTv ? 'tv' : 'movie'}:$id';
      final existing = target[key];
      if (existing != null) {
        if (!existing.studios.contains(studio)) existing.studios.add(studio);
      } else {
        target[key] = _DiscoveredTitle(
          id: id as int,
          title: name,
          type: isTv ? 'TV' : 'Movie',
          releaseDate: (isTv ? map['first_air_date'] : map['release_date'])?.toString(),
          overview: map['overview']?.toString() ?? '',
          posterPath: map['poster_path']?.toString(),
          studios: <String>[studio],
        );
      }
    }
  }

  void _showSeedExample(CinematicSeedExample example) {
    final lookup = CinematicTitleMetadataService.lookupTitle(
      title: example.title,
      isTv: example.isTv,
      year: example.year,
    );
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(example.title),
        content: SizedBox(
          width: 520,
          child: !CinematicTitleMetadataService.isConfigured
              ? const Text(
                  'This title is also seeded into the local catalog as a non-playable example with sample cast/crew credits. Configure TMDB_API_KEY to enrich the record with provider-sourced metadata and artwork.',
                )
              : FutureBuilder<CinematicTitleMetadata?>(
                  future: lookup,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const SizedBox(
                        height: 130,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      return Text(
                        'TMDB lookup failed: ${snapshot.error}',
                        style: const TextStyle(color: Colors.redAccent),
                      );
                    }
                    final metadata = snapshot.data;
                    if (metadata == null) {
                      return const Text(
                        'No exact title match was found. Try refreshing provider data or check the title spelling. The system avoids attaching credits from a possible different title.',
                      );
                    }
                    final sections = <Widget>[
                      Text('${metadata.isTv ? 'TV show' : 'Movie'} • ${example.universe}'),
                      if (metadata.releaseDate?.isNotEmpty == true)
                        Text('Release / first air: ${metadata.releaseDate}'),
                      if (metadata.overview.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(metadata.overview),
                      ],
                      for (final section in <({String label, List<String> names})>[
                        (label: 'Cast', names: metadata.cast),
                        (label: 'Characters', names: metadata.characters),
                        (label: 'Directors', names: metadata.directors),
                        (label: 'Writers', names: metadata.writers),
                        (label: 'Music', names: metadata.music),
                      ])
                        if (section.names.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(section.label,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(section.names.take(12).join(', ')),
                        ],
                      const SizedBox(height: 10),
                      const Text(
                        'This is a local catalog example without a playable media file. Provider lookup can enrich credits, but does not prove continuity membership automatically.',
                        style: TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ];
                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: sections,
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSeedExampleGroup({
    required String title,
    required String subtitle,
    required List<CinematicSeedExample> examples,
  }) {
    return Card(
      child: ExpansionTile(
        title: Text(title),
        subtitle: Text(subtitle),
        children: [
          for (final example in examples)
            ListTile(
              leading: Icon(example.isTv ? Icons.tv_outlined : Icons.movie_outlined),
              title: Text(example.title),
              subtitle: Text(
                '${example.universe}${example.year == null ? '' : ' • ${example.year}'}${example.notes == null ? '' : '\n${example.notes}'}',
              ),
              isThreeLine: example.notes != null,
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => _showSeedExample(example),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cinematic Universe Intelligence'),
        actions: [IconButton(tooltip: 'Refresh metadata', onPressed: _loading ? null : _refresh, icon: const Icon(Icons.sync))],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Self-updating franchise discovery', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Find upcoming movies and shows from live provider metadata, group overlapping studio results, and avoid maintaining a hard-coded filmography. It refreshes when opened and every 12 hours while this screen remains open, after the provider publishes release and studio metadata.'),
          const SizedBox(height: 8),
          Text(_lastRefresh == null ? 'Last refresh: not yet refreshed' : 'Last refresh: ${_lastRefresh!.toLocal()}'),
          if (_apiKey.isEmpty) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Setup required: set TMDB_API_KEY in the local .env file. Use a backend proxy for credentials that must remain secret.', style: TextStyle(color: Colors.orangeAccent))),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
          const SizedBox(height: 8),
          FilledButton.icon(onPressed: _loading ? null : _refresh, icon: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.sync), label: Text(_loading ? 'Refreshing provider data…' : 'Refresh now')),
        ]))),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 18, 4, 6),
          child: Text('Starter examples — validate metadata and cast/crew', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text('These are examples only, not a hard-coded universe limit. Tap a title to look up sourced provider metadata. New titles continue to be discovered separately from live metadata.', style: TextStyle(color: Colors.white60)),
        ),
        _buildSeedExampleGroup(
          title: 'Marvel Cinematic Universe — Movies (${CinematicSeedExamples.movies.length})',
          subtitle: 'Starter examples, not the complete catalog',
          examples: CinematicSeedExamples.movies,
        ),
        _buildSeedExampleGroup(
          title: 'Marvel-related — Shows (${CinematicSeedExamples.shows.length})',
          subtitle: 'Includes one title marked as a separate continuity',
          examples: CinematicSeedExamples.shows,
        ),
        _buildSeedExampleGroup(
          title: 'Additional Movie Examples (${CinematicSeedExamples.additionalMovies.length})',
          subtitle: 'Harry Potter, How to Train Your Dragon, The Incredibles, and Finding Nemo',
          examples: CinematicSeedExamples.additionalMovies,
        ),
        _buildSeedExampleGroup(
          title: 'Additional TV Examples (${CinematicSeedExamples.additionalShows.length})',
          subtitle: 'Disney Channel sitcoms and animated series',
          examples: CinematicSeedExamples.additionalShows,
        ),
        if (_loading && _titles.isEmpty) const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
        if (!_loading && _apiKey.isNotEmpty && _titles.isEmpty && _error == null) const Padding(padding: EdgeInsets.all(20), child: Text('No upcoming titles found for the configured studio rules.')),
        for (final title in _titles) Card(child: ListTile(
          leading: title.posterPath == null ? const Icon(Icons.movie_outlined, size: 38) : Image.network('https://image.tmdb.org/t/p/w185${title.posterPath}', width: 54, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.movie_outlined)),
          title: Text(title.title),
          subtitle: Text('${title.type} • ${title.releaseDate?.isEmpty == false ? title.releaseDate : 'Release date unknown'}\n${title.studios.join(', ')}${title.overview.isEmpty ? '' : '\n${title.overview}'}'),
          isThreeLine: true,
        )),
        const Padding(padding: EdgeInsets.all(12), child: Text('Limitations: studio affiliation is a discovery signal, not proof of shared continuity. The same studio can produce unrelated titles; verify universe/franchise relationships before automatically merging them. TV data may be incomplete when providers have not published company metadata.', style: TextStyle(color: Colors.white60, fontSize: 12))),
      ]),
    );
  }
}

class _DiscoveredTitle {
  _DiscoveredTitle({required this.id, required this.title, required this.type, required this.releaseDate, required this.overview, required this.posterPath, required this.studios});
  final int id;
  final String title;
  final String type;
  final String? releaseDate;
  final String overview;
  final String? posterPath;
  final List<String> studios;
}
