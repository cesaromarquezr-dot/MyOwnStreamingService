import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_core.dart';
import 'details.dart';
import 'collection_details.dart';
import 'localization.dart';
import 'music.dart';
import 'player.dart';
import 'profiles.dart';
import 'smart_search.dart';
import 'jellyfin_plugins_hub.dart';

/// Entry point for the streaming features that are useful across the app.
/// Existing Home customization, playback progress, music details and profiles
/// remain the source of truth for those features; this screen makes them easy
/// to find alongside the new local watchlist and real Jellyfin connection.
class StreamingUpgradeCenterScreen extends StatelessWidget {
  const StreamingUpgradeCenterScreen({super.key});

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppController.instance;
    final unfinished = controller.library
        .where((item) => controller.getPlaybackProgress(item.id) > 0 &&
            controller.getPlaybackProgress(item.id) < .95)
        .length;
    return Scaffold(
      appBar: AppBar(title: const UniversalText('Streaming Upgrade Center')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _UpgradeIntro(),
          const SizedBox(height: 14),
          _UpgradeTile(
            icon: Icons.bookmark_add_outlined,
            title: 'Personal Watchlist',
            subtitle: 'Save titles per profile and track progress when available.',
            onTap: () => _open(context, const PersonalWatchlistScreen()),
          ),
          _UpgradeTile(
            icon: Icons.favorite_border_rounded,
            title: 'Favorites',
            subtitle: 'Browse titles already marked as liked in your profile.',
            onTap: () => _open(context, const _FavoritesScreen()),
          ),
          _UpgradeTile(
            icon: Icons.collections_bookmark_outlined,
            title: 'Collections',
            subtitle: 'Open the collections already available in your library.',
            onTap: () => _open(context, const _CollectionsScreen()),
          ),
          _UpgradeTile(
            icon: Icons.dns_outlined,
            title: 'Connect Jellyfin',
            subtitle: 'Sign in to your own server, browse its library, and play supported items.',
            onTap: () => _open(context, const JellyfinConnectionScreen()),
          ),
          _UpgradeTile(
            icon: Icons.extension_rounded,
            title: 'Jellyfin Plugins',
            subtitle: 'Connect as a Jellyfin administrator to install, enable, disable, uninstall plugins, and manage server repositories.',
            onTap: () => _open(context, const JellyfinPluginsHubScreen()),
          ),
          _UpgradeTile(
            icon: Icons.play_circle_outline,
            title: 'Continue Watching',
            subtitle: '$unfinished unfinished item(s) tracked in playback progress. Open Home to resume.',
            onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
          ),
          _UpgradeTile(
            icon: Icons.search_rounded,
            title: 'Smart Search',
            subtitle: 'Search titles, people and supported catalog metadata.',
            onTap: () => _open(context, const SmartSearchScreen()),
          ),
          _UpgradeTile(
            icon: Icons.movie_filter_outlined,
            title: 'Movie & TV Details',
            subtitle: 'Open a title from your library to see its details, artwork, trailers and related titles.',
            onTap: () {
              final items = controller.library;
              if (items.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Your local catalog is empty. Connect a catalog or Jellyfin server first.')),
                );
                return;
              }
              _open(context, _CatalogPickerScreen(items: items));
            },
          ),
          _UpgradeTile(
            icon: Icons.music_note_rounded,
            title: 'Music & Albums',
            subtitle: 'Open the existing music experience and artist/album pages.',
            onTap: () => _open(context, const MusicScreen()),
          ),
          _UpgradeTile(
            icon: Icons.people_alt_outlined,
            title: 'Profiles',
            subtitle: 'Switch profiles to keep watchlists and preferences separate.',
            onTap: () => _open(context, const ProfileSelectionScreen()),
          ),
          const SizedBox(height: 12),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'Home layout and hero-banner settings are available from the existing Home customization controls. Playback progress is recorded by the player. Jellyfin connection credentials are stored using secure device storage; the password is not saved.',
                style: TextStyle(fontSize: 12, height: 1.45),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpgradeIntro extends StatelessWidget {
  const _UpgradeIntro();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xff292447), Color(0xff10141f)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.auto_awesome_rounded, size: 30),
            SizedBox(height: 10),
            Text('Your entertainment, in one place',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
            SizedBox(height: 6),
            Text('Personalize discovery, organize titles, and connect the media server you control.',
                style: TextStyle(color: Colors.white70, height: 1.4)),
          ],
        ),
      );
}

class _UpgradeTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _UpgradeTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 9),
        child: ListTile(
          leading: CircleAvatar(child: Icon(icon)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
          isThreeLine: true,
        ),
      );
}

class PersonalWatchlistScreen extends StatefulWidget {
  const PersonalWatchlistScreen({super.key});

  @override
  State<PersonalWatchlistScreen> createState() => _PersonalWatchlistScreenState();
}

class _PersonalWatchlistScreenState extends State<PersonalWatchlistScreen> {
  List<Map<String, dynamic>> _saved = [];
  bool _loading = true;
  String _filter = 'All';

  String get _storageKey {
    final profileId = AppController.instance.currentProfile?.id.trim();
    return 'moss_personal_watchlist_v1_${profileId?.isNotEmpty == true ? profileId : 'guest'}';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    final parsed = <Map<String, dynamic>>[];
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final row in decoded) {
            if (row is Map) parsed.add(Map<String, dynamic>.from(row));
          }
        }
      } catch (_) {
        // A damaged local watchlist should not prevent the rest of the app
        // from opening. The next save replaces the malformed value.
      }
    }
    if (!mounted) return;
    setState(() { _saved = parsed; _loading = false; });
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_saved));
  }

  MediaItem _asMedia(Map<String, dynamic> row) {
    final id = row['id']?.toString() ?? '';
    for (final media in AppController.instance.library) {
      if (media.id == id) return media;
    }
    return MediaItem(
      id: id,
      title: row['title']?.toString() ?? 'Untitled',
      type: row['type']?.toString() ?? 'movie',
      imageUrl: row['imageUrl']?.toString(),
      description: row['description']?.toString(),
      releaseYear: int.tryParse(row['releaseYear']?.toString() ?? ''),
      playbackUrl: row['playbackUrl']?.toString(),
      trailerUrl: row['trailerUrl']?.toString(),
    );
  }

  Map<String, dynamic> _snapshot(MediaItem media) => <String, dynamic>{
        'id': media.id,
        'title': media.title,
        'type': media.type,
        'imageUrl': media.imageUrl,
        'description': media.description,
        'releaseYear': media.releaseYear,
        'playbackUrl': media.playbackUrl,
        'trailerUrl': media.trailerUrl,
      };

  Future<void> _add() async {
    final catalog = AppController.instance.library;
    if (catalog.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No catalog titles are available yet.')));
      return;
    }
    final picked = await showModalBottomSheet<MediaItem>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AddWatchlistSheet(catalog: catalog, existingIds: _saved.map((e) => e['id'].toString()).toSet()),
    );
    if (picked == null || !mounted) return;
    if (_saved.any((row) => row['id'] == picked.id)) return;
    setState(() => _saved.insert(0, _snapshot(picked)));
    await _persist();
  }

  Future<void> _remove(String id) async {
    setState(() => _saved.removeWhere((row) => row['id']?.toString() == id));
    await _persist();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _saved.map(_asMedia).where((media) {
      if (_filter == 'Movies') {
        return media.type.toLowerCase().contains('movie') ||
            media.type.toLowerCase() == 'film';
      }
      if (_filter == 'Shows') {
        return media.type.toLowerCase().contains('tv') ||
            media.type.toLowerCase().contains('series') ||
            media.type.toLowerCase().contains('episode');
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal Watchlist'),
        actions: [
          IconButton(
            tooltip: 'Add title',
            onPressed: _add,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'All', label: Text('All')),
                      ButtonSegment(value: 'Movies', label: Text('Movies')),
                      ButtonSegment(value: 'Shows', label: Text('Shows')),
                    ],
                    selected: {_filter},
                    onSelectionChanged: (value) =>
                        setState(() => _filter = value.first),
                  ),
                ),
                Expanded(
                  child: rows.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.bookmark_border_rounded, size: 48),
                                const SizedBox(height: 12),
                                Text(
                                  _saved.isEmpty
                                      ? 'Your watchlist is empty'
                                      : 'No titles in this filter',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Add titles from your local catalog. This list is saved separately for each profile.',
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 14),
                                FilledButton.icon(
                                  onPressed: _add,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add a title'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: rows.length,
                          itemBuilder: (context, index) {
                            final media = rows[index];
                            final progress = AppController.instance
                                .getPlaybackProgress(media.id)
                                .clamp(0.0, 1.0)
                                .toDouble();
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              child: ListTile(
                                leading: media.imageUrl?.isNotEmpty == true
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Image.network(
                                          media.imageUrl!,
                                          width: 54,
                                          height: 76,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const SizedBox(
                                            width: 54,
                                            child: Icon(Icons.movie_outlined),
                                          ),
                                        ),
                                      )
                                    : const SizedBox(
                                        width: 54,
                                        child: Icon(Icons.movie_outlined),
                                      ),
                                title: Text(
                                  media.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text([
                                      media.releaseYear?.toString(),
                                      media.type,
                                    ].whereType<String>().where((value) =>
                                        value.isNotEmpty).join(' • ')),
                                    if (progress > 0 && progress < .95)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: LinearProgressIndicator(
                                            value: progress),
                                      ),
                                  ],
                                ),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        MediaDetailsScreen(media: media),
                                  ),
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'remove') _remove(media.id);
                                    if (value == 'play' &&
                                        media.playbackUrl?.isNotEmpty == true) {
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              PlayerScreen(media: media),
                                        ),
                                      );
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    if (media.playbackUrl?.isNotEmpty == true)
                                      const PopupMenuItem(
                                        value: 'play',
                                        child: Text('Play / Resume'),
                                      ),
                                    const PopupMenuItem(
                                      value: 'remove',
                                      child: Text('Remove from watchlist'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Add title'),
      ),
    );
  }

}

class _AddWatchlistSheet extends StatefulWidget {
  final List<MediaItem> catalog;
  final Set<String> existingIds;
  const _AddWatchlistSheet({required this.catalog, required this.existingIds});
  @override
  State<_AddWatchlistSheet> createState() => _AddWatchlistSheetState();
}

class _AddWatchlistSheetState extends State<_AddWatchlistSheet> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final matches = widget.catalog.where((m) => !widget.existingIds.contains(m.id) && ('${m.title} ${m.originalTitle ?? ''} ${m.type}').toLowerCase().contains(_query.toLowerCase())).take(100).toList();
    return SafeArea(child: Padding(padding: EdgeInsets.only(left: 12, right: 12, top: 16, bottom: MediaQuery.viewInsetsOf(context).bottom + 12), child: SizedBox(height: MediaQuery.sizeOf(context).height * .78, child: Column(children: [const Text('Add from your catalog', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 12), TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search titles'), onChanged: (v) => setState(() => _query = v)), const SizedBox(height: 8), Expanded(child: ListView.builder(itemCount: matches.length, itemBuilder: (_, i) { final m = matches[i]; return ListTile(leading: const Icon(Icons.movie_outlined), title: Text(m.title), subtitle: Text(m.type), onTap: () => Navigator.of(context).pop(m)); }))]))));
  }
}

class _CatalogPickerScreen extends StatelessWidget {
  final List<MediaItem> items;
  const _CatalogPickerScreen({required this.items});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Choose a title')), body: ListView.builder(itemCount: items.length, itemBuilder: (_, i) { final media = items[i]; return ListTile(leading: const Icon(Icons.movie_outlined), title: Text(media.title), subtitle: Text(media.type), onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MediaDetailsScreen(media: media)))); }));
}

class _FavoritesScreen extends StatelessWidget {
  const _FavoritesScreen();

  @override
  Widget build(BuildContext context) {
    final favorites = AppController.instance.liked;
    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: favorites.isEmpty
          ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No favorites yet. Open a movie or show and use its like/favorite control to save it here.', textAlign: TextAlign.center)))
          : ListView.builder(
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final media = favorites[index];
                return ListTile(
                  leading: const Icon(Icons.favorite_rounded),
                  title: Text(media.title),
                  subtitle: Text(media.type),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MediaDetailsScreen(media: media))),
                );
              },
            ),
    );
  }
}

class _CollectionsScreen extends StatelessWidget {
  const _CollectionsScreen();

  @override
  Widget build(BuildContext context) {
    final collections = AppController.instance.collections;
    return Scaffold(
      appBar: AppBar(title: const Text('Collections')),
      body: collections.isEmpty
          ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No collections are available for this profile yet.', textAlign: TextAlign.center)))
          : ListView.builder(
              itemCount: collections.length,
              itemBuilder: (context, index) {
                final collection = collections[index];
                return ListTile(
                  leading: const Icon(Icons.collections_bookmark_outlined),
                  title: Text(collection.name),
                  subtitle: Text('${collection.mediaIds.length} title(s)${collection.description.isEmpty ? '' : ' • ${collection.description}'}', maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CollectionDetailsScreen(collection: collection))),
                );
              },
            ),
    );
  }
}

class JellyfinConnectionScreen extends StatefulWidget {
  const JellyfinConnectionScreen({super.key});
  @override
  State<JellyfinConnectionScreen> createState() => _JellyfinConnectionScreenState();
}

class _JellyfinConnectionScreenState extends State<JellyfinConnectionScreen> {
  static const _secure = FlutterSecureStorage();
  final _serverController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _searchController = TextEditingController();
  String? _token;
  String? _userId;
  String? _username;
  List<MediaItem> _items = [];
  bool _busy = false;
  bool _connected = false;
  String? _error;
  String _query = '';
  String _type = 'All';

  String get _profileToken {
    final profileId = AppController.instance.currentProfile?.id.trim();
    return profileId != null && profileId.isNotEmpty ? profileId : 'guest';
  }
  String get _tokenKey => 'moss_jellyfin_token_$_profileToken';
  String get _userKey => 'moss_jellyfin_user_$_profileToken';
  String get _urlKey => 'moss_jellyfin_url_$_profileToken';
  String get _idKey => 'moss_jellyfin_user_id_$_profileToken';

  String get _baseUrl {
    var value = _serverController.text.trim();
    while (value.endsWith('/')) { value = value.substring(0, value.length - 1); }
    return value;
  }

  @override
  void initState() { super.initState(); _restore(); }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_urlKey) ?? '';
    final token = await _secure.read(key: _tokenKey);
    final user = await _secure.read(key: _userKey);
    final id = await _secure.read(key: _idKey);
    if (!mounted) return;
    _serverController.text = url;
    _token = token;
    _username = user;
    _userId = id;
    if (token != null && id != null && url.isNotEmpty) {
      _usernameController.text = user ?? '';
      await _loadLibrary();
    } else {
      setState(() {});
    }
  }

  Map<String, String> _headers({bool json = false}) => <String, String>{
        'X-Emby-Token': _token ?? '',
        'Accept': 'application/json',
        if (json) 'Content-Type': 'application/json',
        'Authorization': 'MediaBrowser Client="MyOwnStreamingService", Device="Mobile", DeviceId="moss-mobile-client", Version="1.0.0"',
      };

  Future<void> _connect() async {
    final uri = Uri.tryParse(_baseUrl);
    if (uri == null || !uri.hasAuthority || !{'http', 'https'}.contains(uri.scheme)) {
      setState(() => _error = 'Enter a valid server URL, such as http://192.168.1.20:8096.');
      return;
    }
    if (_usernameController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      setState(() => _error = 'Enter your Jellyfin username and password.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/Users/AuthenticateByName'),
        headers: _headers(json: true),
        body: jsonEncode(<String, String>{'Username': _usernameController.text.trim(), 'Pw': _passwordController.text}),
      ).timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(response.statusCode == 401 ? 'Jellyfin rejected the username or password.' : 'Jellyfin returned HTTP ${response.statusCode}. Check the URL and server logs.');
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final token = body['AccessToken']?.toString();
      final user = body['User'] is Map ? Map<String, dynamic>.from(body['User'] as Map) : <String, dynamic>{};
      final userId = user['Id']?.toString();
      if (token == null || token.isEmpty || userId == null || userId.isEmpty) throw Exception('The server response did not include a usable user token.');
      _token = token; _userId = userId; _username = _usernameController.text.trim();
      await _secure.write(key: _tokenKey, value: token);
      await _secure.write(key: _userKey, value: _username);
      await _secure.write(key: _idKey, value: userId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_urlKey, _baseUrl);
      _passwordController.clear();
      await _loadLibrary();
    } catch (error) {
      if (!mounted) return;
      setState(() { _busy = false; _error = 'Could not connect: ${error.toString().replaceFirst('Exception: ', '')}'; });
    }
  }

  Future<void> _loadLibrary() async {
    if (_token == null || _userId == null || _baseUrl.isEmpty) return;
    setState(() { _busy = true; _error = null; });
    try {
      final uri = Uri.parse('$_baseUrl/Users/$_userId/Items').replace(queryParameters: <String, String>{
        'Recursive': 'true', 'IncludeItemTypes': 'Movie,Series,Episode', 'Fields': 'Overview,ProductionYear,Genres,RunTimeTicks,CommunityRating', 'SortBy': 'SortName', 'SortOrder': 'Ascending', 'Limit': '500',
      });
      final response = await http.get(uri, headers: _headers()).timeout(const Duration(seconds: 25));
      if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('Library request failed with HTTP ${response.statusCode}.');
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final rows = json['Items'] is List ? json['Items'] as List : const [];
      final mapped = <MediaItem>[];
      for (final raw in rows) {
        if (raw is! Map) continue;
        final row = Map<String, dynamic>.from(raw);
        final id = row['Id']?.toString();
        if (id == null || id.isEmpty) continue;
        final kind = row['Type']?.toString() ?? 'Movie';
        final isPlayable = kind == 'Movie' || kind == 'Episode';
        final imageUri = Uri.parse('$_baseUrl/Items/$id/Images/Primary').replace(queryParameters: {'maxWidth': '500', 'api_key': _token!});
        final streamUri = Uri.parse('$_baseUrl/Videos/$id/stream').replace(queryParameters: {'static': 'true', 'api_key': _token!});
        mapped.add(MediaItem(
          id: 'jellyfin_$id',
          title: row['Name']?.toString() ?? 'Untitled',
          type: kind == 'Series' ? 'tv' : kind == 'Episode' ? 'episode' : 'movie',
          imageUrl: imageUri.toString(),
          description: row['Overview']?.toString(),
          releaseYear: int.tryParse(row['ProductionYear']?.toString() ?? ''),
          rating: double.tryParse(row['CommunityRating']?.toString() ?? ''),
          playbackUrl: isPlayable ? streamUri.toString() : null,
          addedSource: 'jellyfin',
        ));
      }
      if (!mounted) return;
      setState(() { _items = mapped; _busy = false; _connected = true; _error = null; });
    } catch (error) {
      if (!mounted) return;
      setState(() { _busy = false; _connected = false; _error = 'Could not load the library: ${error.toString().replaceFirst('Exception: ', '')}'; });
    }
  }

  Future<void> _disconnect() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_urlKey);
    await _secure.delete(key: _tokenKey);
    await _secure.delete(key: _userKey);
    await _secure.delete(key: _idKey);
    if (!mounted) return;
    setState(() { _token = null; _userId = null; _username = null; _items = []; _connected = false; _serverController.clear(); _usernameController.clear(); _passwordController.clear(); _error = null; });
  }

  @override
  void dispose() { _serverController.dispose(); _usernameController.dispose(); _passwordController.dispose(); _searchController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final visible = _items.where((m) {
      final matchesQuery = '${m.title} ${m.description ?? ''}'.toLowerCase().contains(_query.toLowerCase());
      final matchesType = _type == 'All' || (_type == 'Movies' && m.type == 'movie') || (_type == 'Shows' && (m.type == 'tv' || m.type == 'episode'));
      return matchesQuery && matchesType;
    }).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jellyfin Library'),
        actions: [
          IconButton(
            tooltip: 'Browse Jellyfin plugins',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => JellyfinPluginsHubScreen(
                serverUrl: _serverController.text.trim().isEmpty ? null : _baseUrl,
                accessToken: _token,
                username: _username,
              ),
            )),
            icon: const Icon(Icons.extension_rounded),
          ),
          if (_connected) IconButton(tooltip: 'Refresh library', onPressed: _loadLibrary, icon: const Icon(Icons.refresh_rounded)),
          if (_connected) IconButton(tooltip: 'Disconnect', onPressed: _disconnect, icon: const Icon(Icons.link_off_rounded)),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (!_connected) ...[
          const Card(child: Padding(padding: EdgeInsets.all(14), child: Text('Connect to a Jellyfin server you own or are authorized to use. For a home server, use its LAN URL first, for example http://192.168.1.20:8096. Use HTTPS for remote access; avoid exposing the server directly to the public internet.', style: TextStyle(height: 1.4)))),
          TextField(controller: _serverController, keyboardType: TextInputType.url, autocorrect: false, decoration: const InputDecoration(labelText: 'Server URL', hintText: 'http://192.168.1.20:8096', prefixIcon: Icon(Icons.dns_outlined))),
          const SizedBox(height: 10),
          TextField(controller: _usernameController, autocorrect: false, decoration: const InputDecoration(labelText: 'Jellyfin username', prefixIcon: Icon(Icons.person_outline))),
          const SizedBox(height: 10),
          TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline))),
          const SizedBox(height: 14),
          FilledButton.icon(onPressed: _busy ? null : _connect, icon: const Icon(Icons.link_rounded), label: Text(_busy ? 'Connecting…' : 'Connect and load library')),
        ] else ...[
          Card(child: ListTile(leading: const Icon(Icons.check_circle, color: Colors.green), title: Text('Connected to ${_serverController.text}'), subtitle: Text('Signed in as ${_username ?? 'Jellyfin user'} • ${_items.length} items loaded'), trailing: IconButton(onPressed: _loadLibrary, icon: const Icon(Icons.refresh_rounded)))),
          TextField(controller: _searchController, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search your Jellyfin library'), onChanged: (v) => setState(() => _query = v)),
          const SizedBox(height: 8),
          SegmentedButton<String>(segments: const [ButtonSegment(value: 'All', label: Text('All')), ButtonSegment(value: 'Movies', label: Text('Movies')), ButtonSegment(value: 'Shows', label: Text('Shows'))], selected: {_type}, onSelectionChanged: (v) => setState(() => _type = v.first)),
          const SizedBox(height: 8),
          if (_busy) const LinearProgressIndicator(),
          if (!_busy && visible.isEmpty) const Padding(padding: EdgeInsets.all(28), child: Text('No matching items were returned by Jellyfin.', textAlign: TextAlign.center)),
          ...visible.map((media) => Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
            leading: ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(media.imageUrl!, width: 54, height: 78, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(width: 54, child: Icon(Icons.movie_outlined)))),
            title: Text(media.title, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text('${media.type.toUpperCase()}${media.releaseYear == null ? '' : ' • ${media.releaseYear}'}${media.rating == null ? '' : ' • ${media.rating!.toStringAsFixed(1)}'}'),
            trailing: media.playbackUrl != null ? IconButton(tooltip: 'Play', icon: const Icon(Icons.play_circle_fill_rounded), onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PlayerScreen(media: media)))) : const Icon(Icons.tv_rounded),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MediaDetailsScreen(media: media))),
          ))),
        ],
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        if (_busy && !_connected) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
      ]),
    );
  }
}
