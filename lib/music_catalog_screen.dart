import 'dart:async';

// FILE: `lib/music_catalog_screen.dart`.
// Purpose: Search music metadata from Spotify and MusicBrainz and browse
// community album artwork from the Cover Art Archive. This does not imply
// playback rights; playable audio comes from a separately licensed/local source.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_core.dart';

class MusicCatalogScreen extends StatefulWidget {
  const MusicCatalogScreen({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  State<MusicCatalogScreen> createState() => _MusicCatalogScreenState();
}

class _MusicCatalogScreenState extends State<MusicCatalogScreen> {
  late final TextEditingController _queryController;
  String _type = 'all';
  bool _loading = false;
  Map<String, dynamic>? _result;
  Map<String, dynamic>? _providerStatus;
  String? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.initialQuery);
    if (AppController.instance.isBackendAuthenticated) {
      _loadStatus();
      if (widget.initialQuery.trim().isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _search());
      }
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    try {
      final payload = await AppController.instance.backendApi.getMusicCatalogStatus();
      if (!mounted) return;
      setState(() {
        _providerStatus = payload['providers'] is Map
            ? Map<String, dynamic>.from(payload['providers'] as Map)
            : <String, dynamic>{};
      });
    } catch (_) {
      // Provider status is supplementary. Actual search reports actionable errors.
    }
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _error = 'Enter an artist, album, or song title to search.';
        _result = null;
      });
      return;
    }
    if (!AppController.instance.isBackendAuthenticated) {
      setState(() {
        _error = 'Sign in to your MyOwnStreamingService backend before searching the online music catalog.';
        _result = null;
      });
      return;
    }

    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final payload = await AppController.instance.backendApi.searchMusicCatalog(
        query,
        type: _type,
        limit: 10,
      );
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _result = payload;
        _error = null;
      });
      final providers = payload['providers'];
      if (providers is Map && mounted) {
        setState(() => _providerStatus = Map<String, dynamic>.from(providers));
      }
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _result = null;
        _error = error.toString().replaceFirst('BackendApiException: ', '');
      });
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authenticated = AppController.instance.isBackendAuthenticated;
    final spotify = _providerStatus?['spotify'] is Map
        ? Map<String, dynamic>.from(_providerStatus!['spotify'] as Map)
        : <String, dynamic>{};
    final musicBrainz = _providerStatus?['musicBrainz'] is Map
        ? Map<String, dynamic>.from(_providerStatus!['musicBrainz'] as Map)
        : <String, dynamic>{};
    final coverArt = _providerStatus?['coverArtArchive'] is Map
        ? Map<String, dynamic>.from(_providerStatus!['coverArtArchive'] as Map)
        : <String, dynamic>{};

    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101010),
        title: const Text('Music Catalog', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Clear search',
            onPressed: () => setState(() {
              _queryController.clear();
              _result = null;
              _error = null;
            }),
            icon: const Icon(Icons.clear_all_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          const Text(
            'Search artists, albums, discographies, and recordings from external music catalogs.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _queryController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Artist, album, or song',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: Colors.white.withValues(alpha: .06),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _typeChip('All', 'all'),
              _typeChip('Artists', 'artist'),
              _typeChip('Albums', 'album'),
              _typeChip('Songs', 'track'),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: _loading ? null : _search,
              icon: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.travel_explore_rounded),
              label: Text(_loading ? 'Searching catalogs…' : 'Search Music Catalog'),
            ),
          ),
          const SizedBox(height: 12),
          if (_providerStatus != null)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _providerChip('Spotify', spotify['configured'] == true),
                _providerChip('MusicBrainz', musicBrainz['configured'] == true),
                _providerChip('Cover Art Archive', coverArt['configured'] == true),
              ],
            ),
          if (!authenticated) ...[
            const SizedBox(height: 12),
            _notice('Backend sign-in required', 'The online catalog is routed through your authenticated backend. Sign in first; Spotify credentials stay on the server.'),
          ],
          if (_error != null) ...[
            const SizedBox(height: 14),
            _notice('Could not complete search', _error!),
          ],
          if (_loading) ...[
            const SizedBox(height: 20),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            const Text('MusicBrainz requests are rate-limited to protect the public service.', style: TextStyle(color: Colors.white54, fontSize: 12)),
          ],
          if (_result != null) ..._resultSections(_result!),
          const SizedBox(height: 22),
          const Text(
            'Spotify metadata, artist images, and album art link back to Spotify. Spotify does not provide artist biographies through this API; an exact-match TMDB person biography is shown only when available. These results do not grant music-streaming rights or create playable local tracks.',
            style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _typeChip(String label, String value) => ChoiceChip(
        label: Text(label),
        selected: _type == value,
        onSelected: (selected) {
          if (!selected) return;
          setState(() => _type = value);
          if (_queryController.text.trim().isNotEmpty) _search();
        },
      );

  Widget _providerChip(String label, bool configured) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: configured ? const Color(0xFF173B2A) : const Color(0xFF3B2D18),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          configured
              ? (label == 'Spotify' ? '$label configured' : '$label available')
              : '$label setup needed',
          style: TextStyle(color: configured ? Colors.lightGreenAccent : Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.w700),
        ),
      );

  Widget _notice(String title, String body) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .05), borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(body, style: const TextStyle(color: Colors.white70, height: 1.4)),
        ]),
      );

  List<Widget> _resultSections(Map<String, dynamic> result) {
    final spotify = _asMap(result['spotify']);
    final mb = _asMap(result['musicBrainz']);
    final output = <Widget>[];
    void addGroup(String title, dynamic raw) {
      final items = raw is List
          ? raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
          : <Map<String, dynamic>>[];
      if (items.isEmpty) return;
      output.add(Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 8),
        child: Text('$title (${items.length})', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
      ));
      output.addAll(items.map((item) => _resultTile(item)));
    }

    addGroup('Spotify · Artists', spotify['artists']);
    addGroup('Spotify · Albums', spotify['albums']);
    addGroup('Spotify · Tracks', spotify['tracks']);
    addGroup('MusicBrainz · Artists', mb['artists']);
    addGroup('MusicBrainz · Albums & releases', mb['releaseGroups']);
    addGroup('MusicBrainz · Recordings', mb['recordings']);

    final warnings = result['warnings'];
    if (warnings is List && warnings.isNotEmpty) {
      output.add(const Padding(
        padding: EdgeInsets.only(top: 16, bottom: 6),
        child: Text('Provider notes', style: TextStyle(fontWeight: FontWeight.w800)),
      ));
      output.addAll(warnings.map((warning) => Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Text('• $warning', style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, height: 1.4)),
          )));
    }

    if (output.isEmpty) {
      output.add(const Padding(
        padding: EdgeInsets.only(top: 24),
        child: Text('No results returned. Try a different spelling or select another category.', style: TextStyle(color: Colors.white60)),
      ));
    }
    return output;
  }

  Widget _resultTile(Map<String, dynamic> item) {
    final title = (item['title'] ?? item['name'] ?? 'Untitled').toString();
    final source = (item['source'] ?? 'Catalog').toString();
    final kind = (item['type'] ?? item['entityType'] ?? '').toString();
    final artist = (item['artist'] ?? '').toString();
    final releaseDate = (item['releaseDate'] ?? item['firstReleaseDate'] ?? '').toString();
    final year = releaseDate.length >= 4 ? releaseDate.substring(0, 4) : '';
    final primaryType = (item['primaryType'] ?? item['albumType'] ?? kind).toString();
    final disambiguation = (item['disambiguation'] ?? '').toString();
    final subtitleParts = <String>[
      if (artist.isNotEmpty) artist,
      if (primaryType.isNotEmpty) primaryType,
      if (year.isNotEmpty) year,
      source,
      if (disambiguation.isNotEmpty) disambiguation,
    ];
    final imageUrl = (item['imageUrl'] ?? item['coverArtUrl'] ?? '').toString();
    final id = (item['id'] ?? '').toString();
    final isMbArtist = source == 'MusicBrainz' && kind == 'artist' && id.isNotEmpty;
    final isMbAlbum = source == 'MusicBrainz' && (kind == 'album' || item.containsKey('coverArtApiUrl')) && id.isNotEmpty;
    final isSpotifyArtist = source == 'Spotify' && kind == 'artist' && id.isNotEmpty;
    final isSpotifyAlbum = source == 'Spotify' && kind == 'album' && id.isNotEmpty;
    final externalUrl = (item['spotifyUrl'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .045), borderRadius: BorderRadius.circular(13)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: imageUrl.startsWith('https://')
              ? Image.network(
                  imageUrl,
                  width: 54,
                  height: 54,
                  fit: source == 'Spotify' ? BoxFit.contain : BoxFit.cover,
                  errorBuilder: (_, __, ___) => _placeholderArt(),
                )
              : _placeholderArt(),
        ),
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitleParts.join(' · '), maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 11, height: 1.3)),
        trailing: SizedBox(
          width: (isMbArtist || externalUrl.isNotEmpty || isMbAlbum) ? 100 : 24,
          child: Row(mainAxisAlignment: MainAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
            if (isSpotifyArtist)
              IconButton(
                padding: EdgeInsets.zero,
                tooltip: 'View artist profile, bio, and albums',
                onPressed: () => _openSpotifyArtist(title, id),
                icon: const Icon(Icons.person_search_rounded),
              ),
            if (isSpotifyAlbum)
              IconButton(
                padding: EdgeInsets.zero,
                tooltip: 'View album and track list',
                onPressed: () => _openSpotifyAlbum(title, id),
                icon: const Icon(Icons.queue_music_rounded),
              ),
            if (isMbArtist)
              IconButton(
                padding: EdgeInsets.zero,
                tooltip: 'Browse discography',
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MusicDiscographyScreen(artistName: title, artistMbid: id))),
                icon: const Icon(Icons.album_outlined),
              ),
            if (isMbAlbum)
              IconButton(
                padding: EdgeInsets.zero,
                tooltip: 'View Cover Art Archive images',
                onPressed: () => _showCoverArt(title, id),
                icon: const Icon(Icons.image_search_outlined),
              ),
            if (externalUrl.startsWith('https://'))
              IconButton(
                padding: EdgeInsets.zero,
                tooltip: 'Open in Spotify',
                onPressed: () => _openExternal(externalUrl),
                icon: const Icon(Icons.open_in_new_rounded),
              ),
          ]),
        ),
        onTap: isSpotifyArtist
            ? () => _openSpotifyArtist(title, id)
            : isSpotifyAlbum
                ? () => _openSpotifyAlbum(title, id)
                : isMbArtist
                    ? () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MusicDiscographyScreen(artistName: title, artistMbid: id)))
                    : isMbAlbum
                        ? () => _showCoverArt(title, id)
                        : externalUrl.startsWith('https://') ? () => _openExternal(externalUrl) : null,
      ),
    );
  }

  Widget _placeholderArt() => Container(
        width: 54,
        height: 54,
        color: Colors.white10,
        alignment: Alignment.center,
        child: const Icon(Icons.album_outlined, color: Colors.white54),
      );

  void _openSpotifyArtist(String title, String spotifyId) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => SpotifyArtistDetailsScreen(
        artistName: title,
        spotifyId: spotifyId,
      ),
    ));
  }

  void _openSpotifyAlbum(String title, String spotifyId) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => SpotifyAlbumDetailsScreen(
        albumTitle: title,
        spotifyId: spotifyId,
      ),
    ));
  }

  Future<void> _openExternal(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https') return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _showCoverArt(String albumTitle, String mbid) async {
    try {
      final payload = await AppController.instance.backendApi.getMusicCoverArt(mbid);
      if (!mounted) return;
      final raw = payload['images'];
      final images = raw is List
          ? raw.whereType<Map>().map((image) => Map<String, dynamic>.from(image)).toList()
          : <Map<String, dynamic>>[];
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF1B1B1B),
          title: Text(albumTitle),
          content: SizedBox(
            width: 340,
            child: images.isEmpty
                ? const Text('The Cover Art Archive has no artwork attached to this release group yet.')
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: images.map((image) {
                        final url = (image['thumbnail500'] ?? image['image'] ?? '').toString();
                        final types = image['types'] is List ? (image['types'] as List).join(', ') : 'Artwork';
                        if (!url.startsWith('https://')) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(url, errorBuilder: (_, __, ___) => const SizedBox(height: 70, child: Center(child: Icon(Icons.broken_image_outlined))))),
                            const SizedBox(height: 4),
                            Text(types, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                          ]),
                        );
                      }).toList(),
                    ),
                  ),
          ),
          actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Close'))],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not load Cover Art Archive images.')));
    }
  }
}

class MusicDiscographyScreen extends StatefulWidget {
  const MusicDiscographyScreen({super.key, required this.artistName, required this.artistMbid});

  final String artistName;
  final String artistMbid;

  @override
  State<MusicDiscographyScreen> createState() => _MusicDiscographyScreenState();
}

class _MusicDiscographyScreenState extends State<MusicDiscographyScreen> {
  late final Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = AppController.instance.backendApi.getMusicDiscography(widget.artistMbid);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF101010),
        appBar: AppBar(
          backgroundColor: const Color(0xFF101010),
          title: Text('${widget.artistName} · Discography', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Could not load this discography. ${snapshot.error}', textAlign: TextAlign.center)));
            }
            final raw = snapshot.data?['items'];
            final items = raw is List
                ? raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
                : <Map<String, dynamic>>[];
            if (items.isEmpty) {
              return const Center(child: Text('No release groups were returned for this artist.', style: TextStyle(color: Colors.white60)));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(color: Colors.white10),
              itemBuilder: (context, index) {
                final item = items[index];
                final title = (item['title'] ?? 'Untitled release').toString();
                final year = (item['year'] ?? '').toString();
                final primaryType = (item['primaryType'] ?? 'Release').toString();
                final imageUrl = (item['coverArtUrl'] ?? '').toString();
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: imageUrl.startsWith('https://')
                        ? Image.network(imageUrl, width: 58, height: 58, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _smallPlaceholder())
                        : _smallPlaceholder(),
                  ),
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('$primaryType${year.isNotEmpty ? ' · $year' : ''} · MusicBrainz', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  trailing: IconButton(
                    tooltip: 'View cover artwork',
                    icon: const Icon(Icons.image_search_outlined),
                    onPressed: () async {
                      try {
                        final art = await AppController.instance.backendApi.getMusicCoverArt((item['id'] ?? '').toString());
                        if (!context.mounted) return;
                        final imagesRaw = art['images'];
                        final images = imagesRaw is List ? imagesRaw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList() : <Map<String, dynamic>>[];
                        showDialog<void>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            backgroundColor: const Color(0xFF1B1B1B),
                            title: Text(title),
                            content: images.isEmpty
                                ? const Text('No cover art is available for this release group.')
                                : SizedBox(width: 320, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: images.map((image) {
                                    final url = (image['thumbnail500'] ?? image['image'] ?? '').toString();
                                    if (!url.startsWith('https://')) return const SizedBox.shrink();
                                    return Padding(padding: const EdgeInsets.only(bottom: 12), child: Image.network(url, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined)));
                                  }).toList()))),
                            actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Close'))],
                          ),
                        );
                      } catch (_) {
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not load cover art.')));
                      }
                    },
                  ),
                );
              },
            );
          },
        ),
      );

  Widget _smallPlaceholder() => Container(
        width: 58,
        height: 58,
        color: Colors.white10,
        alignment: Alignment.center,
        child: const Icon(Icons.album_outlined, color: Colors.white54),
      );
}

Map<String, dynamic> _asMap(dynamic value) => value is Map
    ? Map<String, dynamic>.from(value)
    : <String, dynamic>{};

/// Detailed Spotify artist view with imagery, genres, follower count, optional
/// exact-match TMDB biography, and paginated album/single releases.
class SpotifyArtistDetailsScreen extends StatefulWidget {
  const SpotifyArtistDetailsScreen({
    super.key,
    required this.artistName,
    required this.spotifyId,
  });

  final String artistName;
  final String spotifyId;

  @override
  State<SpotifyArtistDetailsScreen> createState() => _SpotifyArtistDetailsScreenState();
}

class _SpotifyArtistDetailsScreenState extends State<SpotifyArtistDetailsScreen> {
  late final Future<Map<String, dynamic>> _future;
  final List<Map<String, dynamic>> _additionalAlbums = <Map<String, dynamic>>[];
  bool _loadingMore = false;
  String? _loadMoreError;

  @override
  void initState() {
    super.initState();
    _future = _loadInitial();
  }

  Future<Map<String, dynamic>> _loadInitial() async {
    final api = AppController.instance.backendApi;
    final values = await Future.wait(<Future<Map<String, dynamic>>>[
      api.getSpotifyArtist(widget.spotifyId),
      api.getSpotifyArtistAlbums(widget.spotifyId, limit: 10, offset: 0),
    ]);
    return <String, dynamic>{'artist': values[0], 'albums': values[1]};
  }

  Future<void> _loadMore(int offset) async {
    if (_loadingMore) return;
    setState(() {
      _loadingMore = true;
      _loadMoreError = null;
    });
    try {
      final payload = await AppController.instance.backendApi.getSpotifyArtistAlbums(
        widget.spotifyId,
        limit: 10,
        offset: offset,
      );
      final raw = payload['items'];
      if (!mounted) return;
      setState(() {
        if (raw is List) {
          _additionalAlbums.addAll(raw.whereType<Map>().map((v) => Map<String, dynamic>.from(v)));
        }
      });
    } catch (_) {
      if (mounted) setState(() => _loadMoreError = 'Could not load more Spotify releases.');
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF101010),
        appBar: AppBar(
          backgroundColor: const Color(0xFF101010),
          title: Text(widget.artistName, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || snapshot.data == null) {
              return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Could not load the Spotify artist profile. ${snapshot.error ?? ''}', textAlign: TextAlign.center)));
            }
            final artist = _asMap(snapshot.data!['artist']);
            final albumPayload = _asMap(snapshot.data!['albums']);
            final firstAlbums = _maps(albumPayload['items']);
            final albums = <Map<String, dynamic>>[...firstAlbums, ..._additionalAlbums];
            final total = int.tryParse(albumPayload['total']?.toString() ?? '') ?? albums.length;
            final images = _maps(artist['images']);
            final imageUrl = (artist['imageUrl'] ?? (images.isNotEmpty ? images.first['url'] : '') ?? '').toString();
            final genres = artist['genres'] is List ? (artist['genres'] as List).map((v) => v.toString()).where((v) => v.isNotEmpty).toList() : <String>[];
            final biography = artist['biography']?.toString().trim() ?? '';
            final followers = int.tryParse(artist['followers']?.toString() ?? '');
            final spotifyUrl = artist['spotifyUrl']?.toString() ?? '';

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                Center(
                  child: Container(
                    width: 190,
                    height: 190,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .04), borderRadius: BorderRadius.circular(14)),
                    child: imageUrl.startsWith('https://')
                        ? Image.network(imageUrl, width: 190, height: 190, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.person_outline_rounded, size: 60))
                        : const Icon(Icons.person_outline_rounded, size: 60),
                  ),
                ),
                const SizedBox(height: 14),
                Text(artist['name']?.toString() ?? widget.artistName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
                if (followers != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${_formatCount(followers)} Spotify followers', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60))),
                if (genres.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 5, children: genres.map((genre) => Chip(label: Text(genre, style: const TextStyle(fontSize: 11)), visualDensity: VisualDensity.compact)).toList()),
                ],
                if (spotifyUrl.startsWith('https://')) ...[
                  const SizedBox(height: 8),
                  Center(child: OutlinedButton.icon(onPressed: () => _openSpotifyUrl(spotifyUrl), icon: const Icon(Icons.open_in_new_rounded), label: const Text('Open artist in Spotify'))),
                ],
                const SizedBox(height: 12),
                const Text('Artist images, genre tags, and profile metadata provided by Spotify.', style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.4)),
                const SizedBox(height: 20),
                const Text('Biography', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                if (biography.isNotEmpty) ...[
                  Text(biography, style: const TextStyle(color: Colors.white70, height: 1.5)),
                  Text('Biography source: ${artist['biographySource'] ?? 'TMDB'}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ] else
                  Text(artist['biographyNote']?.toString() ?? 'Spotify does not supply biographies through its Web API. A matching TMDB biography is not available for this artist.', style: const TextStyle(color: Colors.white60, height: 1.4)),
                const SizedBox(height: 24),
                Text('Albums, singles & appearances${total > 0 ? ' ($total)' : ''}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                if (albums.isEmpty) const Text('No releases were returned for this artist.', style: TextStyle(color: Colors.white60)),
                for (final album in albums) _albumTile(context, album),
                if (_loadMoreError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_loadMoreError!, style: const TextStyle(color: Colors.orangeAccent))),
                if (albums.length < total) Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton.icon(
                    onPressed: _loadingMore ? null : () => _loadMore(albums.length),
                    icon: _loadingMore ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.expand_more_rounded),
                    label: Text(_loadingMore ? 'Loading releases…' : 'Load more releases'),
                  ),
                ),
              ],
            );
          },
        ),
      );

  Widget _albumTile(BuildContext context, Map<String, dynamic> album) {
    final title = album['title']?.toString() ?? 'Untitled album';
    final id = album['id']?.toString() ?? '';
    final imageUrl = album['imageUrl']?.toString() ?? '';
    final artist = album['artist']?.toString() ?? '';
    final date = album['releaseDate']?.toString() ?? '';
    final type = album['albumType']?.toString() ?? 'album';
    return Card(
      color: Colors.white.withValues(alpha: .04),
      child: ListTile(
        onTap: id.isEmpty ? null : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SpotifyAlbumDetailsScreen(albumTitle: title, spotifyId: id))),
        leading: Container(
          width: 56,
          height: 56,
          color: Colors.white.withValues(alpha: .04),
          alignment: Alignment.center,
          child: imageUrl.startsWith('https://')
              ? Image.network(imageUrl, width: 56, height: 56, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.album_outlined))
              : const Icon(Icons.album_outlined),
        ),
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('$type${date.isEmpty ? '' : ' · $date'}${artist.isEmpty ? '' : ' · $artist'}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }

  static List<Map<String, dynamic>> _maps(dynamic raw) => raw is List
      ? raw.whereType<Map>().map((v) => Map<String, dynamic>.from(v)).toList()
      : <Map<String, dynamic>>[];

  static String _formatCount(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return '$value';
  }
}

/// Spotify album details and actual track listing. Artwork is displayed at its
/// source aspect ratio (contain) and is linked to the Spotify source.
class SpotifyAlbumDetailsScreen extends StatefulWidget {
  const SpotifyAlbumDetailsScreen({
    super.key,
    required this.albumTitle,
    required this.spotifyId,
  });

  final String albumTitle;
  final String spotifyId;

  @override
  State<SpotifyAlbumDetailsScreen> createState() => _SpotifyAlbumDetailsScreenState();
}

class _SpotifyAlbumDetailsScreenState extends State<SpotifyAlbumDetailsScreen> {
  late final Future<Map<String, dynamic>> _future;

  static List<Map<String, dynamic>> _maps(dynamic raw) => raw is List
      ? raw.whereType<Map>().map((value) => Map<String, dynamic>.from(value)).toList()
      : <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _future = AppController.instance.backendApi.getSpotifyAlbum(widget.spotifyId);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF101010),
        appBar: AppBar(backgroundColor: const Color(0xFF101010), title: Text(widget.albumTitle, maxLines: 1, overflow: TextOverflow.ellipsis)),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError || snapshot.data == null) {
              return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Could not load this album. ${snapshot.error ?? ''}', textAlign: TextAlign.center)));
            }
            final album = snapshot.data!;
            final imageUrl = album['imageUrl']?.toString() ?? '';
            final title = album['title']?.toString() ?? widget.albumTitle;
            final artist = album['artist']?.toString() ?? '';
            final date = album['releaseDate']?.toString() ?? '';
            final type = album['albumType']?.toString() ?? 'Album';
            final totalTracks = album['totalTracks']?.toString() ?? '0';
            final tracks = album['tracks'] is List
                ? (album['tracks'] as List).whereType<Map>().map((v) => Map<String, dynamic>.from(v)).toList()
                : <Map<String, dynamic>>[];
            final spotifyUrl = album['spotifyUrl']?.toString() ?? '';
            final label = album['label']?.toString().trim() ?? '';
            final producers = album['producers'] is List
                ? (album['producers'] as List).map((v) => v.toString()).where((v) => v.trim().isNotEmpty).toList()
                : <String>[];
            final composers = album['composers'] is List
                ? (album['composers'] as List).map((v) => v.toString()).where((v) => v.trim().isNotEmpty).toList()
                : <String>[];
            final albumArtists = _maps(album['artists']);
            final copyrights = _maps(album['copyrights']);
            final hasOwnedCopy = _hasOwnedAlbum(title, artist);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                Center(child: Container(
                  width: 240,
                  height: 240,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .04), borderRadius: BorderRadius.circular(10)),
                  child: imageUrl.startsWith('https://')
                      ? Image.network(imageUrl, width: 240, height: 240, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.album_outlined, size: 70))
                      : const Icon(Icons.album_outlined, size: 70),
                )),
                const SizedBox(height: 16),
                Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                if (albumArtists.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    runSpacing: 6,
                    children: albumArtists.map((row) {
                      final artistId = row['id']?.toString() ?? '';
                      final artistName = row['name']?.toString() ?? '';
                      return ActionChip(
                        avatar: const Icon(Icons.person_outline_rounded, size: 16),
                        label: Text(artistName),
                        onPressed: artistId.isEmpty ? null : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SpotifyArtistDetailsScreen(artistName: artistName, spotifyId: artistId))),
                      );
                    }).toList(),
                  ),
                ] else if (artist.isNotEmpty)
                  Padding(padding: const EdgeInsets.only(top: 5), child: Text(artist, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70))),
                Padding(padding: const EdgeInsets.only(top: 5), child: Text('$type${date.isEmpty ? '' : ' · $date'} · $totalTracks tracks', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54))),
                if (spotifyUrl.startsWith('https://')) Padding(padding: const EdgeInsets.only(top: 12), child: Center(child: OutlinedButton.icon(onPressed: () => _openSpotifyUrl(spotifyUrl), icon: const Icon(Icons.open_in_new_rounded), label: const Text('Open album in Spotify')))),
                if (hasOwnedCopy)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Center(child: Chip(avatar: Icon(Icons.library_music_rounded, size: 16), label: Text('In your library'))),
                  )
                else
                  _whereToBuySection(title, artist),
                if (label.isNotEmpty || producers.isNotEmpty || composers.isNotEmpty || copyrights.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text('Album credits', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  if (label.isNotEmpty) _creditRow('Record label / music company', label),
                  if (producers.isNotEmpty) _creditRow('Producer(s)', producers.join(', ')),
                  if (composers.isNotEmpty) _creditRow('Composer(s) / writers', composers.join(', ')),
                  if (copyrights.isNotEmpty) _creditRow('Copyright', copyrights.map((v) => '${v['type'] ?? 'Copyright'}: ${v['text'] ?? ''}'.trim()).where((v) => v.isNotEmpty).join(' · ')),
                  if ((album['musicBrainzReleaseUrl']?.toString() ?? '').startsWith('https://'))
                    Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => _openSpotifyUrl(album['musicBrainzReleaseUrl'].toString()), icon: const Icon(Icons.open_in_new_rounded, size: 15), label: const Text('View credits source on MusicBrainz'))),
                  if ((album['creditNote']?.toString() ?? '').trim().isNotEmpty)
                    Text(album['creditNote'].toString(), style: const TextStyle(color: Colors.white38, fontSize: 11, height: 1.4)),
                ],
                const SizedBox(height: 18),
                const Text('Track list', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                if (album['trackWarning']?.toString().isNotEmpty == true) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(album['trackWarning'].toString(), style: const TextStyle(color: Colors.orangeAccent, fontSize: 12))),
                if (tracks.isEmpty) const Text('Spotify did not return track rows for this album.', style: TextStyle(color: Colors.white60)),
                for (var index = 0; index < tracks.length; index++) _trackTile(index, tracks[index]),
                const SizedBox(height: 14),
                const Text('Album cover and track metadata provided by Spotify. Artwork is displayed without cropping; use the Spotify link for the source.', style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.4)),
              ],
            );
          },
        ),
      );

  bool _hasOwnedAlbum(String albumTitle, String artistNames) {
    String normalize(String value) => value.toLowerCase().trim().replaceAll(
      RegExp(r"[\s\-_.,:;!?()\[\]{}\\/]+"),
      '',
    );
    final wantedTitle = normalize(albumTitle);
    if (wantedTitle.isEmpty) return false;
    final wantedArtists = artistNames.split(',').map(normalize).where((value) => value.isNotEmpty).toSet();
    for (final item in AppController.instance.library) {
      if (!item.type.toLowerCase().contains('album') || normalize(item.title) != wantedTitle) continue;
      if (!AppController.instance.isOwned(item.id)) continue;
      final localArtists = item.music.map(normalize).where((value) => value.isNotEmpty).toSet();
      if (wantedArtists.isEmpty || localArtists.isEmpty || wantedArtists.intersection(localArtists).isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  Widget _whereToBuySection(String albumTitle, String artistNames) {
    final query = '$albumTitle $artistNames album'.trim();
    final encoded = Uri.encodeQueryComponent(query);
    final retailers = <({String name, IconData icon, String url})>[
      (name: 'Amazon México', icon: Icons.shopping_bag_outlined, url: 'https://www.amazon.com.mx/s?k=$encoded'),
      (name: 'Mercado Libre', icon: Icons.store_mall_directory_outlined, url: 'https://listado.mercadolibre.com.mx/${Uri.encodeComponent(query)}'),
      (name: 'Apple Music', icon: Icons.music_note_rounded, url: 'https://music.apple.com/us/search?term=$encoded'),
      (name: 'Amazon Music', icon: Icons.headphones_rounded, url: 'https://music.amazon.com/search/${Uri.encodeComponent(query)}'),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Card(
        color: const Color(0xFF191919),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Where to buy or listen', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            const Text('This album is not marked as owned in your library. Choose a retailer or music service to check availability.', style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.4)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: retailers.map((retailer) => OutlinedButton.icon(
              onPressed: () async {
                final uri = Uri.tryParse(retailer.url);
                if (uri == null || uri.scheme != 'https') return;
                final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
                if (!opened && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open ${retailer.name}.')));
                }
              },
              icon: Icon(retailer.icon, size: 16),
              label: Text(retailer.name),
            )).toList()),
          ]),
        ),
      ),
    );
  }

  Widget _creditRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 155, child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4))),
        ]),
      );

  Widget _trackTile(int index, Map<String, dynamic> track) {
    final title = track['title']?.toString() ?? 'Track';
    final artist = track['artist']?.toString() ?? '';
    final durationMs = int.tryParse(track['durationMs']?.toString() ?? '') ?? 0;
    final mins = durationMs ~/ 60000;
    final secs = (durationMs ~/ 1000) % 60;
    final trackNo = track['trackNumber']?.toString() ?? '${index + 1}';
    final discNo = int.tryParse(track['discNumber']?.toString() ?? '1') ?? 1;
    final spotifyUrl = track['spotifyUrl']?.toString() ?? '';
    final previewUrl = track['previewUrl']?.toString() ?? '';
    final composers = track['composers'] is List ? (track['composers'] as List).map((v) => v.toString()).where((v) => v.isNotEmpty).join(', ') : '';
    final producers = track['producers'] is List ? (track['producers'] as List).map((v) => v.toString()).where((v) => v.isNotEmpty).join(', ') : '';
    final subtitle = <String>[
      if (artist.isNotEmpty) artist,
      if (discNo > 1) 'Disc $discNo',
      if (track['explicit'] == true) 'Explicit',
      if (durationMs > 0) '$mins:${secs.toString().padLeft(2, '0')}',
      if (composers.isNotEmpty) 'Composer: $composers',
      if (producers.isNotEmpty) 'Producer: $producers',
    ].join(' · ');
    final playUrl = previewUrl.startsWith('https://') ? previewUrl : spotifyUrl;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: SizedBox(width: 28, child: Center(child: Text(trackNo, style: const TextStyle(color: Colors.white54, fontSize: 11)))),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      trailing: IconButton(
        tooltip: previewUrl.startsWith('https://') ? 'Open preview' : 'Play in Spotify',
        icon: const Icon(Icons.play_arrow_rounded),
        onPressed: playUrl.startsWith('https://') ? () => _openSpotifyUrl(playUrl) : null,
      ),
    );
  }
}

Future<void> _openSpotifyUrl(String value) async {
  final uri = Uri.tryParse(value);
  if (uri == null || uri.scheme != 'https') return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Album artwork rail for Home. It prefers Spotify's regional new releases and
/// falls back to recent-year album search when the endpoint is unavailable.
class SpotifyHomeAlbumsShelf extends StatefulWidget {
  const SpotifyHomeAlbumsShelf({super.key});

  @override
  State<SpotifyHomeAlbumsShelf> createState() => _SpotifyHomeAlbumsShelfState();
}

class _SpotifyHomeAlbumsShelfState extends State<SpotifyHomeAlbumsShelf> {
  List<Map<String, dynamic>> _albums = <Map<String, dynamic>>[];
  final ScrollController _albumsScrollController = ScrollController();
  bool _loading = false;
  bool _attempted = false;
  bool _canScrollAlbumsLeft = false;
  bool _canScrollAlbumsRight = false;

  @override
  void initState() {
    super.initState();
    _albumsScrollController.addListener(_updateAlbumArrowState);
    AppController.instance.addListener(_onAppControllerChanged);
    if (AppController.instance.isBackendAuthenticated) {
      unawaited(_loadAlbums());
    }
  }

  void _onAppControllerChanged() {
    if (!mounted || _attempted || _loading ||
        !AppController.instance.isBackendAuthenticated) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_attempted) unawaited(_loadAlbums());
    });
  }

  @override
  void dispose() {
    AppController.instance.removeListener(_onAppControllerChanged);
    _albumsScrollController.removeListener(_updateAlbumArrowState);
    _albumsScrollController.dispose();
    super.dispose();
  }

  void _updateAlbumArrowState() {
    if (!_albumsScrollController.hasClients) return;
    final position = _albumsScrollController.position;
    final canLeft = position.pixels > position.minScrollExtent + 2;
    final canRight = position.pixels < position.maxScrollExtent - 2;
    if (!mounted ||
        (canLeft == _canScrollAlbumsLeft && canRight == _canScrollAlbumsRight)) {
      return;
    }
    setState(() {
      _canScrollAlbumsLeft = canLeft;
      _canScrollAlbumsRight = canRight;
    });
  }

  void _scheduleAlbumArrowStateUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateAlbumArrowState();
    });
  }

  Future<void> _scrollAlbumsByPage(int direction) async {
    if (!_albumsScrollController.hasClients) return;
    final position = _albumsScrollController.position;
    final target = (position.pixels + direction * position.viewportDimension * .72)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    await _albumsScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _loadAlbums() async {
    if (_loading || _attempted || !AppController.instance.isBackendAuthenticated) return;
    setState(() { _loading = true; _attempted = true; });
    try {
      Map<String, dynamic> payload;
      try {
        payload = await AppController.instance.backendApi.getSpotifyFeaturedAlbums(limit: 12);
      } catch (_) {
        payload = <String, dynamic>{};
      }
      var albums = _albumRows(payload['items']);
      if (albums.isEmpty) {
        final year = DateTime.now().year;
        for (final query in <String>['year:$year', 'year:${year - 1}']) {
          try {
            final search = await AppController.instance.backendApi.searchMusicCatalog(query, type: 'album', limit: 10);
            final spotify = _asMap(search['spotify']);
            albums = _albumRows(spotify['albums']);
            if (albums.isNotEmpty) break;
          } catch (_) {
            // Continue to the prior year before hiding the shelf.
          }
        }
      }
      if (!mounted) return;
      setState(() => _albums = albums.where((album) =>
          (album['id']?.toString() ?? '').isNotEmpty &&
          (album['imageUrl']?.toString() ?? '').startsWith('https://')).toList(growable: false));
      _scheduleAlbumArrowStateUpdate();
    } catch (_) {
      if (mounted) setState(() => _albums = <Map<String, dynamic>>[]);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _albumRows(dynamic value) => value is List
      ? value.whereType<Map>().map((v) => Map<String, dynamic>.from(v)).toList()
      : <Map<String, dynamic>>[];

  @override
  Widget build(BuildContext context) {
    if (!_attempted && AppController.instance.isBackendAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_loadAlbums());
      });
    }
    if (_albums.isEmpty && !_loading) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'New Albums',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Album covers and track listings from Spotify',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Scroll albums left',
                onPressed: _canScrollAlbumsLeft ? () => _scrollAlbumsByPage(-1) : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              IconButton(
                tooltip: 'Scroll albums right',
                onPressed: _canScrollAlbumsRight ? () => _scrollAlbumsByPage(1) : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MusicCatalogScreen(
                      initialQuery: 'year:${DateTime.now().year}',
                    ),
                  ),
                ),
                child: const Text('Explore music'),
              ),
            ],
          ),
        ),
        if (_loading && _albums.isEmpty) const Padding(padding: EdgeInsets.fromLTRB(20, 12, 20, 8), child: LinearProgressIndicator(minHeight: 2)),
        if (_albums.isNotEmpty) SizedBox(
          height: 218,
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (_) {
              _scheduleAlbumArrowStateUpdate();
              return false;
            },
            child: ListView.separated(
            controller: _albumsScrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            scrollDirection: Axis.horizontal,
            itemCount: _albums.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final album = _albums[index];
              final id = album['id']?.toString() ?? '';
              final title = album['title']?.toString() ?? 'Album';
              final artist = album['artist']?.toString() ?? '';
              final image = album['imageUrl']?.toString() ?? '';
              final date = album['releaseDate']?.toString() ?? '';
              return SizedBox(width: 142, child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: id.isEmpty ? null : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SpotifyAlbumDetailsScreen(albumTitle: title, spotifyId: id))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(
                    width: 142, height: 142,
                    child: Image.network(image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.white10, child: const Icon(Icons.album_outlined, size: 36))),
                  )),
                  const SizedBox(height: 7),
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                  Text([if (artist.isNotEmpty) artist, if (date.length >= 4) date.substring(0, 4)].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.white54)),
                ]),
              ));
            },
          ),
          ),
        ),
      ]),
    );
  }
}

