// FILE: lib/media_metadata_catalog_screen.dart
// Purpose: Browse TMDB movie, television and people metadata through the
// authenticated backend, without shipping provider credentials in Flutter.

import 'package:flutter/material.dart';
import 'app_core.dart';
import 'details.dart';
import 'recommendation_ownership.dart';
import 'package:url_launcher/url_launcher.dart';

class MediaMetadataCatalogScreen extends StatefulWidget {
  const MediaMetadataCatalogScreen({
    super.key,
    this.initialType = 'movie',
    this.initialQuery = '',
    this.searchByKeyword = false,
  });

  final String initialType;
  final String initialQuery;
  final bool searchByKeyword;

  @override
  State<MediaMetadataCatalogScreen> createState() =>
      _MediaMetadataCatalogScreenState();
}

class _MediaMetadataCatalogScreenState extends State<MediaMetadataCatalogScreen> {
  late final TextEditingController _queryController;
  late String _type;
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.initialQuery);
    _type = const <String>{'movie', 'tv', 'person', 'all'}.contains(widget.initialType)
        ? widget.initialType
        : 'movie';
    if (widget.initialQuery.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _search();
      });
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _error = widget.searchByKeyword
            ? 'Enter a keyword to find matching movies and shows.'
            : 'Enter a movie, show, actor, actress, director, or person name.';
        _items = <Map<String, dynamic>>[];
      });
      return;
    }
    if (widget.searchByKeyword) {
      await _searchByKeyword(query);
      return;
    }
    if (!AppController.instance.isBackendAuthenticated) {
      setState(() {
        _error = 'Sign in to the MyOwnStreamingService backend to search live TMDB metadata.';
        _items = <Map<String, dynamic>>[];
      });
      return;
    }

    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final types = _type == 'all' ? <String>['movie', 'tv', 'person'] : <String>[_type];
      final payloads = await Future.wait(types.map((type) =>
          AppController.instance.backendApi.getTmdbMetadata(
            '/search/$type',
            <String, String>{
              'query': query,
              'page': '1',
              'include_adult': 'false',
              'language': 'en-US',
            },
          )));
      final combined = <Map<String, dynamic>>[];
      for (var i = 0; i < payloads.length; i++) {
        final raw = payloads[i]['results'];
        if (raw is! List) continue;
        for (final value in raw.whereType<Map>()) {
          final item = Map<String, dynamic>.from(value);
          final mediaType = types[i];
          final id = int.tryParse(item['id']?.toString() ?? '');
          final name = _titleFor(item, mediaType);
          if (id == null || name.isEmpty) continue;
          item['metadataType'] = mediaType;
          item['displayTitle'] = name;
          combined.add(item);
        }
      }
      combined.sort((a, b) {
        final ap = (a['popularity'] is num) ? (a['popularity'] as num).toDouble() : 0.0;
        final bp = (b['popularity'] is num) ? (b['popularity'] as num).toDouble() : 0.0;
        return bp.compareTo(ap);
      });
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _items = combined;
        _error = null;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _items = <Map<String, dynamic>>[];
        _error = error.toString().replaceFirst('BackendApiException: ', '');
      });
    } finally {
      if (mounted && requestId == _requestId) setState(() => _loading = false);
    }
  }


  Future<void> _searchByKeyword(String query) async {
    if (!AppController.instance.isBackendAuthenticated) {
      setState(() {
        _error = 'Sign in to search TMDB keywords.';
        _items = <Map<String, dynamic>>[];
      });
      return;
    }
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final keywordPayload = await AppController.instance.backendApi.getTmdbMetadata(
        '/search/keyword',
        <String, String>{'query': query, 'page': '1'},
      );
      final keywordRows = keywordPayload['results'] is List
          ? (keywordPayload['results'] as List)
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList(growable: false)
          : <Map<String, dynamic>>[];
      String normalize(String value) => value
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[-_]+'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ');
      final wanted = normalize(query);
      Map<String, dynamic>? matchedKeyword;
      for (final row in keywordRows) {
        final name = row['name']?.toString() ?? '';
        if (normalize(name) == wanted) {
          matchedKeyword = row;
          break;
        }
      }
      if (matchedKeyword == null && keywordRows.isNotEmpty) {
        final fallback = keywordRows.firstWhere(
          (row) => (row['name']?.toString() ?? '').toLowerCase().contains(query.toLowerCase()),
          orElse: () => <String, dynamic>{},
        );
        if (fallback.isNotEmpty) matchedKeyword = fallback;
      }
      final selectedKeyword = matchedKeyword;
      final keywordId = int.tryParse(selectedKeyword?['id']?.toString() ?? '');
      if (keywordId == null || keywordId <= 0) {
        if (!mounted || requestId != _requestId) return;
        setState(() {
          _items = <Map<String, dynamic>>[];
          _error = 'TMDB did not find a matching keyword for “$query”. Try another spelling.';
        });
        return;
      }

      final types = _type == 'all'
          ? <String>['movie', 'tv']
          : <String>[_type == 'tv' ? 'tv' : 'movie'];
      final payloads = await Future.wait(types.map((type) =>
          AppController.instance.backendApi.getTmdbMetadata(
            '/discover/$type',
            <String, String>{
              'with_keywords': '$keywordId',
              'sort_by': 'popularity.desc',
              'page': '1',
              'include_adult': 'false',
            },
          )));
      final combined = <Map<String, dynamic>>[];
      for (var i = 0; i < payloads.length; i++) {
        final rows = payloads[i]['results'];
        if (rows is! List) continue;
        for (final value in rows.whereType<Map>()) {
          final item = Map<String, dynamic>.from(value);
          final type = types[i];
          final id = int.tryParse(item['id']?.toString() ?? '');
          final title = _titleFor(item, type);
          if (id == null || title.isEmpty) continue;
          item['metadataType'] = type;
          item['displayTitle'] = title;
          item['matchedKeyword'] = selectedKeyword?['name']?.toString() ?? query;
          combined.add(item);
        }
      }
      combined.sort((a, b) {
        final ap = a['popularity'] is num ? (a['popularity'] as num).toDouble() : 0.0;
        final bp = b['popularity'] is num ? (b['popularity'] as num).toDouble() : 0.0;
        return bp.compareTo(ap);
      });
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _items = combined;
        _error = combined.isEmpty
            ? 'TMDB found the keyword, but no matching titles were returned.'
            : null;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _items = <Map<String, dynamic>>[];
        _error = error.toString().replaceFirst('BackendApiException: ', '');
      });
    } finally {
      if (mounted && requestId == _requestId) setState(() => _loading = false);
    }
  }

  static String _titleFor(Map<String, dynamic> item, String type) {
    final raw = type == 'movie'
        ? (item['original_title'] ?? item['title'])
        : type == 'tv'
            ? (item['original_name'] ?? item['name'])
            : item['name'];
    return raw?.toString().trim() ?? '';
  }

  static String _imageUrl(dynamic path, {String size = 'w342'}) {
    final value = path?.toString().trim() ?? '';
    if (value.isEmpty) return '';
    if (value.startsWith('https://')) return value;
    return value.startsWith('/')
        ? 'https://image.tmdb.org/t/p/$size$value'
        : '';
  }

  void _openItem(Map<String, dynamic> item) {
    final id = int.tryParse(item['id']?.toString() ?? '');
    final type = item['metadataType']?.toString() ?? _type;
    final title = item['displayTitle']?.toString() ?? 'Details';
    if (id == null) return;
    if (type == 'movie' || type == 'tv') {
      final rawDate = (type == 'tv' ? item['first_air_date'] : item['release_date'])?.toString() ?? '';
      final year = rawDate.length >= 4 ? int.tryParse(rawDate.substring(0, 4)) : null;
      final localMatch = RecommendationOwnershipMatcher.findMediaForTitle(
        title: title,
        alternateTitles: <String>[
          item['title']?.toString() ?? '',
          item['original_title']?.toString() ?? '',
          item['name']?.toString() ?? '',
          item['original_name']?.toString() ?? '',
        ],
        isTv: type == 'tv',
        year: year,
        controller: AppController.instance,
      );
      if (localMatch != null) {
        Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => MediaDetailsScreen(media: localMatch),
        ));
        return;
      }
    }
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => TmdbMetadataDetailsScreen(
        id: id,
        type: type,
        initialTitle: title,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      appBar: AppBar(
        title: Text(widget.searchByKeyword ? 'Titles by keyword' : 'TMDB Media Catalog', style: const TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: const Color(0xFF101010),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            widget.searchByKeyword
                ? 'Browse movies and TV shows tagged with this TMDB keyword. Select any result to open its in-app details page.'
                : 'Find movies, TV shows, actors, actresses, directors, and other people. Original-language titles are preferred for display.',
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _queryController,
            onSubmitted: (_) => _search(),
            textInputAction: TextInputAction.search,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: widget.searchByKeyword ? 'TMDB keyword' : 'Movie, show, or person',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: Colors.white.withValues(alpha: .06),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              _chip('Movies', 'movie'),
              _chip('TV Shows', 'tv'),
              if (!widget.searchByKeyword) _chip('People', 'person'),
              _chip(widget.searchByKeyword ? 'Movies + TV' : 'All', 'all'),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 46,
            child: FilledButton.icon(
              onPressed: _loading ? null : _search,
              icon: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.travel_explore_rounded),
              label: Text(_loading
                  ? (widget.searchByKeyword ? 'Finding matching titles…' : 'Searching TMDB…')
                  : (widget.searchByKeyword ? 'Find titles by keyword' : 'Search TMDB')),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.orangeAccent)),
          ],
          if (_loading) const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: LinearProgressIndicator(),
          ),
          if (!_loading && _items.isEmpty && _error == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 26),
              child: Text(
                widget.searchByKeyword
                    ? 'Matching titles will appear here when TMDB has movies or shows tagged with this keyword.'
                    : 'Search TMDB to find provider-sourced posters, backdrops, descriptions, cast, and people profiles.',
                style: const TextStyle(color: Colors.white54, height: 1.4),
              ),
            ),
          for (final item in _items) _resultCard(item),
          const SizedBox(height: 20),
          const Text(
            'This product uses the TMDB API but is not endorsed or certified by TMDB. Metadata and image availability depend on provider records.',
            style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String type) => ChoiceChip(
        label: Text(label),
        selected: _type == type,
        onSelected: (selected) {
          if (!selected) return;
          setState(() => _type = type);
          if (_queryController.text.trim().isNotEmpty) _search();
        },
      );

  Widget _resultCard(Map<String, dynamic> item) {
    final type = item['metadataType']?.toString() ?? 'movie';
    final title = item['displayTitle']?.toString() ?? 'Untitled';
    final imagePath = type == 'person' ? item['profile_path'] : item['poster_path'];
    final imageUrl = _imageUrl(imagePath);
    final originalLanguage = item['original_language']?.toString() ?? '';
    final date = (type == 'movie' ? item['release_date'] : item['first_air_date'])?.toString() ?? '';
    final overview = item['overview']?.toString() ?? '';
    final department = item['known_for_department']?.toString() ?? '';
    final kind = type == 'movie'
        ? 'Movie'
        : type == 'tv'
            ? 'TV Show'
            : department.isNotEmpty
                ? 'Person · $department'
                : 'Person';
    return Card(
      color: Colors.white.withValues(alpha: .045),
      margin: const EdgeInsets.only(bottom: 9),
      child: ListTile(
        onTap: () => _openItem(item),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: imageUrl.isEmpty
              ? Container(width: 58, height: 82, color: Colors.white10, child: const Icon(Icons.perm_media_outlined))
              : Image.network(imageUrl, width: 58, height: 82, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(width: 58, height: 82, color: Colors.white10, child: const Icon(Icons.broken_image_outlined))),
        ),
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text([
          kind,
          if (date.isNotEmpty) date.length >= 4 ? date.substring(0, 4) : date,
          if (originalLanguage.isNotEmpty) originalLanguage.toUpperCase(),
          if (overview.isNotEmpty) overview,
        ].join(' · '), maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 11, height: 1.3)),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class TmdbMetadataDetailsScreen extends StatefulWidget {
  const TmdbMetadataDetailsScreen({
    super.key,
    required this.id,
    required this.type,
    required this.initialTitle,
  });

  final int id;
  final String type;
  final String initialTitle;

  @override
  State<TmdbMetadataDetailsScreen> createState() => _TmdbMetadataDetailsScreenState();
}

class _TmdbMetadataDetailsScreenState extends State<TmdbMetadataDetailsScreen> {
  late final Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadDetails();
  }

  Future<Map<String, dynamic>> _loadDetails() async {
    final api = AppController.instance.backendApi;
    if (widget.type == 'person') {
      final values = await Future.wait(<Future<Map<String, dynamic>>>[
        api.getTmdbMetadata('/person/${widget.id}', const <String, String>{'language': 'en-US'}),
        api.getTmdbMetadata('/person/${widget.id}/combined_credits', const <String, String>{'language': 'en-US'}),
      ]);
      return <String, dynamic>{'details': values[0], 'credits': values[1], 'type': 'person'};
    }
    final cleanType = widget.type == 'tv' ? 'tv' : 'movie';
    final details = await api.getTmdbMetadata('/$cleanType/${widget.id}', <String, String>{
      'language': 'en-US',
      'append_to_response': 'credits,images,videos,keywords,reviews',
      'include_image_language': 'en,null',
    });
    return <String, dynamic>{'details': details, 'credits': details['credits'], 'type': cleanType};
  }

  static String _imageUrl(dynamic path, {String size = 'w500'}) {
    final value = path?.toString().trim() ?? '';
    if (value.isEmpty) return '';
    if (value.startsWith('https://')) return value;
    return value.startsWith('/') ? 'https://image.tmdb.org/t/p/$size$value' : '';
  }

  static List<Map<String, dynamic>> _maps(dynamic raw) => raw is List
      ? raw.whereType<Map>().map((value) => Map<String, dynamic>.from(value)).toList()
      : <Map<String, dynamic>>[];

  static String _title(Map<String, dynamic> item, String type) {
    if (type == 'tv' || item['media_type'] == 'tv') {
      return (item['original_name'] ?? item['name'] ?? item['original_title'] ?? item['title'] ?? '').toString();
    }
    return (item['original_title'] ?? item['title'] ?? item['original_name'] ?? item['name'] ?? '').toString();
  }

  void _openRelated(int id, String type, String title) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => TmdbMetadataDetailsScreen(id: id, type: type, initialTitle: title),
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF101010),
        appBar: AppBar(backgroundColor: const Color(0xFF101010), title: Text(widget.initialTitle, maxLines: 1, overflow: TextOverflow.ellipsis)),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || snapshot.data == null) {
              return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Could not load metadata. ${snapshot.error ?? ''}', textAlign: TextAlign.center)));
            }
            final data = snapshot.data!;
            final details = data['details'] is Map ? Map<String, dynamic>.from(data['details'] as Map) : <String, dynamic>{};
            final type = data['type']?.toString() ?? widget.type;
            if (type == 'person') return _buildPerson(details, _asMap(data['credits']));
            return _buildTitle(details, type);
          },
        ),
      );

  Widget _buildTitle(Map<String, dynamic> details, String type) {
    final title = _title(details, type);
    final localizedTitle = (type == 'tv' ? details['name'] : details['title'])?.toString() ?? '';
    final overview = details['overview']?.toString() ?? '';
    final backdrop = _imageUrl(details['backdrop_path'], size: 'w1280');
    final poster = _imageUrl(details['poster_path']);
    final genres = _maps(details['genres']).map((value) => value['name']?.toString() ?? '').where((value) => value.isNotEmpty).toList();
    final keywordPayload = details['keywords'];
    final keywordMap = _asMap(keywordPayload);
    final keywords = _maps(
      keywordPayload is List
          ? keywordPayload
          : (keywordMap['keywords'] ?? keywordMap['results']),
    ).map((value) => value['name']?.toString().trim() ?? '')
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList(growable: false);
    final credits = _asMap(details['credits']);
    final cast = _maps(credits['cast']);
    final images = _asMap(details['images']);
    final posters = _maps(images['posters']).take(12).toList();
    final backdrops = _maps(images['backdrops']).take(12).toList();
    final releaseDate = (type == 'tv' ? details['first_air_date'] : details['release_date'])?.toString() ?? '';

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        if (backdrop.isNotEmpty)
          Image.network(backdrop, height: 230, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(height: 30)),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (poster.isNotEmpty) ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(poster, width: 112, height: 168, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(width: 112, height: 168))),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title.isEmpty ? widget.initialTitle : title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                if (localizedTitle.isNotEmpty && localizedTitle != title) ...[
                  const SizedBox(height: 5),
                  Text('Also listed as: $localizedTitle', style: const TextStyle(color: Colors.white60)),
                ],
                const SizedBox(height: 8),
                Text('${type == 'tv' ? 'TV Show' : 'Movie'}${releaseDate.isEmpty ? '' : ' · $releaseDate'}', style: const TextStyle(color: Colors.white60)),
                if (details['vote_average'] is num) Text('TMDB rating · ${(details['vote_average'] as num).toStringAsFixed(1)}/10', style: const TextStyle(color: Colors.amberAccent)),
                const SizedBox(height: 8),
                Wrap(spacing: 5, runSpacing: 5, children: genres.map((genre) => Chip(label: Text(genre, style: const TextStyle(fontSize: 11)), visualDensity: VisualDensity.compact)).toList()),
              ])),
            ]),
            if (overview.isNotEmpty) ...[
              const SizedBox(height: 18),
              const Text('Overview', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              Text(overview, style: const TextStyle(color: Colors.white70, height: 1.5)),
            ],
            if (keywords.isNotEmpty) _keywordSection(keywords),
            _whereToBuySection(title, type, releaseDate),
            if (cast.isNotEmpty) ...[
              const SizedBox(height: 22),
              const Text('Cast', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 9),
              SizedBox(height: 158, child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: cast.take(20).length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final person = cast[index];
                  final personName = person['name']?.toString() ?? 'Unknown person';
                  final profile = _imageUrl(person['profile_path'], size: 'w185');
                  final id = int.tryParse(person['id']?.toString() ?? '');
                  return SizedBox(width: 94, child: InkWell(
                    onTap: id == null ? null : () => _openRelated(id, 'person', personName),
                    child: Column(children: [
                      ClipRRect(borderRadius: BorderRadius.circular(8), child: profile.isEmpty ? Container(width: 84, height: 104, color: Colors.white10, child: const Icon(Icons.person_outline_rounded)) : Image.network(profile, width: 84, height: 104, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 84, height: 104, color: Colors.white10, child: const Icon(Icons.person_outline_rounded)))),
                      const SizedBox(height: 5),
                      Text(personName, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      Text(person['character']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 10)),
                    ]),
                  ));
                },
              )),
            ],
            _imageGallery('Posters', posters),
            _imageGallery('Backdrops', backdrops, size: 'w780'),
            const SizedBox(height: 20),
            const Text('This product uses the TMDB API but is not endorsed or certified by TMDB.', style: TextStyle(color: Colors.white38, fontSize: 11)),
          ]),
        ),
      ],
    );
  }

  Widget _keywordSection(List<String> keywords) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Keywords', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 7),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: keywords.take(40).map((word) => ActionChip(
              tooltip: 'Search movies and shows with "$word"',
              avatar: const Icon(Icons.search_rounded, size: 14),
              label: Text(word, style: const TextStyle(fontSize: 11)),
              visualDensity: VisualDensity.compact,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => MediaMetadataCatalogScreen(
                  initialType: 'all',
                  initialQuery: word,
                  searchByKeyword: true,
                ),
              )),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _whereToBuySection(String title, String type, String releaseDate) {
    final year = releaseDate.length >= 4 ? releaseDate.substring(0, 4) : '';
    final query = '$title $year ${type == 'tv' ? 'TV series' : 'movie'}'.trim();
    final encoded = Uri.encodeQueryComponent(query);
    final retailers = <({String name, IconData icon, String url})>[
      (name: 'Amazon México', icon: Icons.shopping_bag_outlined, url: 'https://www.amazon.com.mx/s?k=$encoded'),
      (name: 'Mercado Libre', icon: Icons.store_mall_directory_outlined, url: 'https://listado.mercadolibre.com.mx/${Uri.encodeComponent(query)}'),
      (name: 'Walmart', icon: Icons.storefront_outlined, url: 'https://www.walmart.com/search?q=$encoded'),
      (name: 'eBay', icon: Icons.sell_outlined, url: 'https://www.ebay.com/sch/i.html?_nkw=$encoded'),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Card(
        color: const Color(0xFF191919),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Where to buy or rent', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            const Text('This title is not in your local library. Search retailers for streaming, digital purchase, DVD, Blu-ray, or used copies. Availability and price are confirmed by each retailer.', style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.4)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: retailers.map((retailer) => OutlinedButton.icon(
              onPressed: () async {
                final uri = Uri.tryParse(retailer.url);
                if (uri == null) return;
                final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
                if (!opened && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open ${retailer.name}.')));
                }
              },
              icon: Icon(retailer.icon, size: 17),
              label: Text(retailer.name),
            )).toList()),
          ]),
        ),
      ),
    );
  }

  Widget _imageGallery(String title, List<Map<String, dynamic>> images, {String size = 'w342'}) {
    if (images.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        SizedBox(height: title == 'Backdrops' ? 100 : 148, child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: images.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final url = _imageUrl(images[index]['file_path'], size: size);
            if (url.isEmpty) return const SizedBox.shrink();
            return ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(width: 80, child: Icon(Icons.broken_image_outlined))));
          },
        )),
      ]),
    );
  }

  Widget _buildPerson(Map<String, dynamic> person, Map<String, dynamic> credits) {
    final name = person['name']?.toString() ?? widget.initialTitle;
    final profile = _imageUrl(person['profile_path'], size: 'h632');
    final biography = person['biography']?.toString().trim() ?? '';
    final combined = <Map<String, dynamic>>[
      ..._maps(credits['cast']),
      ..._maps(credits['crew']),
    ];
    final byKey = <String, Map<String, dynamic>>{};
    for (final item in combined) {
      final id = item['id']?.toString() ?? '';
      final mediaType = item['media_type']?.toString() ?? '';
      if (id.isEmpty || (mediaType != 'movie' && mediaType != 'tv')) continue;
      byKey.putIfAbsent('$mediaType:$id', () => item);
    }
    final filmography = byKey.values.toList()
      ..sort((a, b) {
        final ap = a['popularity'] is num ? (a['popularity'] as num).toDouble() : 0.0;
        final bp = b['popularity'] is num ? (b['popularity'] as num).toDouble() : 0.0;
        return bp.compareTo(ap);
      });
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (profile.isNotEmpty) ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(profile, width: 112, height: 154, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(width: 112, height: 154)))
        else Container(width: 112, height: 154, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.person_outline_rounded, size: 42)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          if ((person['known_for_department']?.toString() ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(person['known_for_department'].toString(), style: const TextStyle(color: Colors.white60))),
          if ((person['birthday']?.toString() ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Born ${person['birthday']}', style: const TextStyle(color: Colors.white60))),
          if ((person['place_of_birth']?.toString() ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(person['place_of_birth'].toString(), style: const TextStyle(color: Colors.white60))),
          if ((person['deathday']?.toString() ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Died ${person['deathday']}', style: const TextStyle(color: Colors.white60))),
        ])),
      ]),
      if (biography.isNotEmpty) ...[
        const SizedBox(height: 20),
        const Text('Biography', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(biography, style: const TextStyle(color: Colors.white70, height: 1.5)),
      ],
      if (filmography.isNotEmpty) ...[
        const SizedBox(height: 24),
        const Text('Filmography', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        for (final item in filmography.take(80)) _creditTile(item),
      ],
      const SizedBox(height: 16),
      const Text('Person metadata, biographies, and filmography provided by TMDB.', style: TextStyle(color: Colors.white38, fontSize: 11)),
    ]);
  }

  Widget _creditTile(Map<String, dynamic> item) {
    final type = item['media_type']?.toString() ?? 'movie';
    final title = _title(item, type);
    final image = _imageUrl(item['poster_path'], size: 'w185');
    final date = (type == 'tv' ? item['first_air_date'] : item['release_date'])?.toString() ?? '';
    final role = (item['character'] ?? item['job'] ?? '').toString();
    final id = int.tryParse(item['id']?.toString() ?? '');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: id == null ? null : () => _openRelated(id, type, title),
      leading: image.isEmpty ? const SizedBox(width: 48, height: 68, child: Icon(Icons.movie_outlined)) : ClipRRect(borderRadius: BorderRadius.circular(5), child: Image.network(image, width: 48, height: 68, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(width: 48, height: 68, child: Icon(Icons.movie_outlined)))),
      title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text('${type == 'tv' ? 'TV' : 'Movie'}${date.isEmpty ? '' : ' · $date'}${role.isEmpty ? '' : ' · $role'}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 11)),
    );
  }

  static Map<String, dynamic> _asMap(dynamic value) => value is Map
      ? Map<String, dynamic>.from(value)
      : <String, dynamic>{};
}
