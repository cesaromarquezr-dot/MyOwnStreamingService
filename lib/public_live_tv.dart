import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_core.dart';

const String _iptvOrgBase = 'https://iptv-org.github.io/iptv';
const String _allChannelsPlaylist = '$_iptvOrgBase/index.m3u';

const Map<String, String> _countryOptions = <String, String>{
  'mx': 'Mexico',
  'us': 'United States',
  'ca': 'Canada',
  'gb': 'United Kingdom',
  'es': 'Spain',
  'fr': 'France',
  'de': 'Germany',
  'br': 'Brazil',
  'ar': 'Argentina',
  'in': 'India',
  'au': 'Australia',
  'jp': 'Japan',
  'kr': 'South Korea',
  'it': 'Italy',
  'pt': 'Portugal',
  'nl': 'Netherlands',
  'ie': 'Ireland',
  'pl': 'Poland',
  'se': 'Sweden',
  'ch': 'Switzerland',
  'gr': 'Greece',
  'tr': 'Turkey',
  'ru': 'Russia',
  'sa': 'Saudi Arabia',
  'eg': 'Egypt',
  'za': 'South Africa',
  'ng': 'Nigeria',
  'ph': 'Philippines',
  'id': 'Indonesia',
  'th': 'Thailand',
  'vn': 'Vietnam',
  'cn': 'China',
  'nz': 'New Zealand',
  'co': 'Colombia',
  'cl': 'Chile',
  'pe': 'Peru',
};

const Map<String, String> _categoryOptions = <String, String>{
  'news': 'News',
  'sports': 'Sports',
  'movies': 'Movies',
  'music': 'Music',
  'documentary': 'Documentary',
  'kids': 'Kids',
  'education': 'Education',
  'weather': 'Weather',
  'entertainment': 'Entertainment',
  'culture': 'Culture',
  'business': 'Business',
  'science': 'Science',
  'travel': 'Travel',
  'general': 'General',
};

class PublicTvChannel {
  final String name;
  final String streamUrl;
  final String? logoUrl;
  final String group;
  final String? language;
  final String? country;

  const PublicTvChannel({
    required this.name,
    required this.streamUrl,
    this.logoUrl,
    this.group = '',
    this.language,
    this.country,
  });

  // Favorites use stable, non-secret metadata rather than the entire stream
  // URL, because some broadcasters put short-lived tokens in query strings.
  String get id {
    final host = Uri.tryParse(streamUrl)?.host.toLowerCase() ?? '';
    return '${name.trim().toLowerCase()}|$host|${group.trim().toLowerCase()}';
  }
}


/// Parses extended M3U channel listings and ignores non-HTTP media schemes.
class PublicTvPlaylistParser {
  static List<PublicTvChannel> parse(String text) {
    final result = <PublicTvChannel>[];
    final seenUrls = <String>{};
    String? pendingName;
    String? pendingLogo;
    String pendingGroup = '';
    String? pendingLanguage;
    String? pendingCountry;
    for (final rawLine in text.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#EXTINF:')) {
        // Metadata values are quoted and the channel display name may itself
        // contain commas, so prefer the comma immediately following the final
        // quoted attribute. Fall back to the first comma for attribute-free rows.
        final quotedDelimiter = line.lastIndexOf('",');
        final comma = quotedDelimiter >= 0 ? quotedDelimiter + 1 : line.indexOf(',');
        final attributePart = comma > 0 ? line.substring(0, comma) : line;
        final namePart = comma > 0 ? line.substring(comma + 1).trim() : '';
        final attrs = <String, String>{};
        final attributePattern = RegExp(r'([\w-]+)="([^"]*)"');
        for (final match in attributePattern.allMatches(attributePart)) {
          final key = match.group(1);
          final value = match.group(2);
          if (key != null && value != null) attrs[key.toLowerCase()] = value.trim();
        }
        pendingName = (attrs['tvg-name']?.isNotEmpty == true
                ? attrs['tvg-name']
                : namePart)
            ?.trim();
        if (pendingName == null || pendingName.isEmpty) pendingName = 'Live channel';
        pendingLogo = attrs['tvg-logo'];
        pendingGroup = attrs['group-title'] ?? '';
        pendingLanguage = attrs['tvg-language'];
        pendingCountry = attrs['tvg-country'];
        continue;
      }
      if (line.startsWith('#') || pendingName == null) continue;
      final uri = Uri.tryParse(line);
      if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http') || uri.host.isEmpty) {
        pendingName = null;
        continue;
      }
      if (seenUrls.add(line)) {
        final logoUri = pendingLogo == null ? null : Uri.tryParse(pendingLogo);
        result.add(PublicTvChannel(
          name: pendingName.isEmpty ? 'Live channel' : pendingName,
          streamUrl: line,
          logoUrl: logoUri != null && (logoUri.scheme == 'https' || logoUri.scheme == 'http')
              ? pendingLogo
              : null,
          group: pendingGroup,
          language: pendingLanguage,
          country: pendingCountry,
        ));
      }
      pendingName = null;
      pendingLogo = null;
      pendingGroup = '';
      pendingLanguage = null;
      pendingCountry = null;
    }
    return result;
  }


}

/// Public live television directory browser. The directory is a list of
/// externally maintained stream URLs; MyOwnStreamingService does not host or
/// guarantee these streams.
class PublicLiveTvScreen extends StatefulWidget {
  final bool showAppBar;

  const PublicLiveTvScreen({super.key, this.showAppBar = true});

  @override
  State<PublicLiveTvScreen> createState() => _PublicLiveTvScreenState();
}

class _PublicLiveTvScreenState extends State<PublicLiveTvScreen> {
  String _scope = 'country';
  String _countryCode = 'mx';
  String _category = 'news';
  Set<String> _preferredCategories = <String>{'news', 'sports', 'entertainment'};
  String _groupFilter = 'All groups';
  String _search = '';
  bool _favoritesOnly = false;
  bool _loading = false;
  String? _loadError;
  List<PublicTvChannel> _channels = const <PublicTvChannel>[];
  Set<String> _favoriteUrls = <String>{};
  VideoPlayerController? _player;
  PublicTvChannel? _playing;
  bool _playerLoading = false;
  bool _playerMinimized = false;
  String? _playerError;
  int _playerGeneration = 0;
  final TextEditingController _searchController = TextEditingController();

  String get _profileId {
    final id = AppController.instance.currentProfile?.id;
    return id?.trim().isNotEmpty == true ? id!.trim() : 'default';
  }

  String get _favoriteKey => 'public_live_tv_favorites_$_profileId';
  String get _countryPreferenceKey => 'public_live_tv_country_$_profileId';
  String get _categoriesPreferenceKey => 'public_live_tv_categories_$_profileId';

  String get _playlistUrl {
    switch (_scope) {
      case 'category':
        return '$_iptvOrgBase/categories/$_category.m3u';
      case 'worldwide':
        return _allChannelsPlaylist;
      default:
        return '$_iptvOrgBase/countries/$_countryCode.m3u';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _loadTvPreferences();
  }

  Future<void> _loadTvPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final country = prefs.getString(_countryPreferenceKey);
    final savedCategories = prefs.getStringList(_categoriesPreferenceKey);
    setState(() {
      if (country != null && _countryOptions.containsKey(country)) _countryCode = country;
      if (savedCategories != null) {
        _preferredCategories = savedCategories.where(_categoryOptions.containsKey).toSet();
      }
      if (_preferredCategories.isEmpty) _preferredCategories = <String>{'news'};
    });
    await _loadPlaylist();
  }

  Future<void> _saveTvPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_countryPreferenceKey, _countryCode);
    await prefs.setStringList(_categoriesPreferenceKey, _preferredCategories.toList()..sort());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Your Live TV preferences were saved for this profile.')),
    );
  }

  void _togglePreferredCategory(String category, bool selected) {
    setState(() {
      if (selected) {
        _preferredCategories.add(category);
      } else if (_preferredCategories.length > 1) {
        _preferredCategories.remove(category);
      }
    });
  }

  void _browseCategory(String category) {
    setState(() {
      _category = category;
      _scope = 'category';
    });
    _loadPlaylist();
  }

  @override
  void dispose() {
    _searchController.dispose();
    final oldPlayer = _player;
    _player = null;
    if (oldPlayer != null) unawaited(oldPlayer.dispose());
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _favoriteUrls = (prefs.getStringList(_favoriteKey) ?? const <String>[]).toSet();
    });
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoriteKey, _favoriteUrls.toList()..sort());
  }

  Future<void> _toggleFavorite(PublicTvChannel channel) async {
    setState(() {
      if (!_favoriteUrls.add(channel.id)) _favoriteUrls.remove(channel.id);
    });
    await _saveFavorites();
  }

  Future<void> _loadPlaylist() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final response = await http.get(
        Uri.parse(_playlistUrl),
        headers: const <String, String>{'Accept': 'audio/x-mpegurl, application/vnd.apple.mpegurl, */*'},
      ).timeout(const Duration(seconds: 25));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Playlist server returned HTTP ${response.statusCode}.');
      }
      final parsed = PublicTvPlaylistParser.parse(response.body);
      if (parsed.isEmpty) {
        throw Exception('No channels were found in this playlist. Try another country or category.');
      }
      if (!mounted) return;
      setState(() {
        _channels = parsed;
        _loading = false;
        _groupFilter = 'All groups';
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'The public playlist timed out. Check your connection and refresh.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Could not load the public playlist. ${_friendlyError(error)}';
      });
    }
  }

  String _friendlyError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    if (message.length > 180) return '${message.substring(0, 177)}…';
    return message;
  }

  List<String> get _groups {
    final result = _channels
        .map((channel) => channel.group.trim())
        .where((group) => group.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return <String>['All groups', ...result];
  }

  List<PublicTvChannel> get _visibleChannels {
    final query = _search.trim().toLowerCase();
    return _channels.where((channel) {
      if (_favoritesOnly && !_favoriteUrls.contains(channel.id)) return false;
      if (_groupFilter != 'All groups' && channel.group != _groupFilter) return false;
      if (query.isNotEmpty &&
          !<String>[
            channel.name,
            channel.group,
            channel.language ?? '',
            channel.country ?? '',
          ].join(' ').toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList(growable: false);
  }

  Future<void> _playChannel(PublicTvChannel channel) async {
    final generation = ++_playerGeneration;
    final previous = _player;
    _player = null;
    if (previous != null) unawaited(previous.dispose());
    setState(() {
      _playing = channel;
      _playerMinimized = false;
      _playerLoading = true;
      _playerError = null;
    });
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(channel.streamUrl));
      _player = controller;
      await controller.initialize().timeout(const Duration(seconds: 30));
      if (!mounted || generation != _playerGeneration) {
        await controller.dispose();
        return;
      }
      controller.addListener(_onPlayerChanged);
      await controller.play();
      if (!mounted || generation != _playerGeneration) return;
      setState(() => _playerLoading = false);
    } on TimeoutException {
      if (!mounted || generation != _playerGeneration) return;
      setState(() {
        _playerLoading = false;
        _playerError = 'This stream did not start in 30 seconds. Try another channel or open it in an external player.';
      });
    } catch (error) {
      if (!mounted || generation != _playerGeneration) return;
      setState(() {
        _playerLoading = false;
        _playerError = 'This stream may be offline, region-restricted, or unsupported by this device. ${_friendlyError(error)}';
      });
    }
  }

  void _onPlayerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _stopPlayer() async {
    ++_playerGeneration;
    final oldPlayer = _player;
    _player = null;
    if (oldPlayer != null) await oldPlayer.dispose();
    if (!mounted) return;
    setState(() {
      _playing = null;
      _playerMinimized = false;
      _playerLoading = false;
      _playerError = null;
    });
  }

  Future<void> _openStreamExternally(PublicTvChannel channel) async {
    final uri = Uri.tryParse(channel.streamUrl);
    if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) return;
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No external app was able to open this stream. Copy its URL for VLC instead.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open an external player. Copy the stream URL for VLC.')),
      );
    }
  }

  Future<void> _copyPlaylistUrl() async {
    await Clipboard.setData(ClipboardData(text: _playlistUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Playlist URL copied. In VLC, choose Media → Open Network Stream and paste it.')),
    );
  }

  Future<void> _openVlcWebsite() async {
    final uri = Uri.parse('https://www.videolan.org/vlc/');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final channels = _visibleChannels;
    final player = _player;
    final playing = _playing;
    final wide = MediaQuery.sizeOf(context).width >= 920;
    return Scaffold(
      appBar: widget.showAppBar ? AppBar(
        title: const Text('Public Live TV'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh playlist',
            onPressed: _loading ? null : _loadPlaylist,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Copy playlist URL for VLC',
            onPressed: _copyPlaylistUrl,
            icon: const Icon(Icons.copy_rounded),
          ),
        ],
      ) : null,
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: <Widget>[
          if (!widget.showAppBar)
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
                OutlinedButton.icon(
                  onPressed: _loading ? null : _loadPlaylist,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh channels'),
                ),
                OutlinedButton.icon(
                  onPressed: _copyPlaylistUrl,
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy playlist'),
                ),
              ]),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Theme.of(context).colorScheme.primary.withValues(alpha: .26),
                  Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .35),
                ],
              ),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Row(
                  children: <Widget>[
                    Icon(Icons.live_tv_rounded, size: 27),
                    SizedBox(width: 10),
                    Expanded(child: Text('Your personal TV and public TV are separate', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18))),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('My TV programs media from your own library. Public Live TV browses independent public stream listings, with no subscription required by this directory. Streams can go offline, buffer, or be region-restricted.'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: _copyPlaylistUrl,
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Copy playlist for VLC'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _openVlcWebsite,
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('Get VLC'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(children: <Widget>[
                    const Icon(Icons.tune_rounded),
                    const SizedBox(width: 9),
                    Expanded(child: Text('Personalize your Live TV', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
                  ]),
                  const SizedBox(height: 6),
                  const Text('Each profile can choose its own country, favorite TV genres and channels. These settings stay separate from other profiles on this device.'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _countryCode,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Your country', helperText: 'Used as your default country playlist', border: OutlineInputBorder()),
                    items: _countryOptions.entries.map((entry) => DropdownMenuItem<String>(value: entry.key, child: Text(entry.value))).toList(),
                    onChanged: (value) => setState(() { if (value != null) _countryCode = value; }),
                  ),
                  const SizedBox(height: 12),
                  Text('Your preferred genres', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, runSpacing: 4, children: _categoryOptions.entries.map((entry) => FilterChip(
                    label: Text(entry.value),
                    selected: _preferredCategories.contains(entry.key),
                    onSelected: (selected) => _togglePreferredCategory(entry.key, selected),
                  )).toList()),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
                    FilledButton.icon(onPressed: _saveTvPreferences, icon: const Icon(Icons.save_rounded), label: const Text('Save my preferences')),
                    OutlinedButton.icon(onPressed: () { setState(() => _scope = 'country'); _loadPlaylist(); }, icon: const Icon(Icons.public_rounded), label: const Text('Browse my country')),
                  ]),
                  const SizedBox(height: 8),
                  Text('Quick browse your genres', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, runSpacing: 8, children: _preferredCategories.map((category) => ActionChip(
                    avatar: const Icon(Icons.live_tv_rounded, size: 16),
                    label: Text(_categoryOptions[category] ?? category),
                    onPressed: () => _browseCategory(category),
                  )).toList()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          _buildPlayerPanel(player, playing),
          const SizedBox(height: 18),
          Text('Find channels', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: <Widget>[
              SizedBox(
                width: wide ? 220 : 250,
                child: DropdownButtonFormField<String>(
                  initialValue: _scope,
                  decoration: const InputDecoration(labelText: 'Playlist scope', border: OutlineInputBorder()),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(value: 'country', child: Text('By country')),
                    DropdownMenuItem(value: 'category', child: Text('By category')),
                    DropdownMenuItem(value: 'worldwide', child: Text('Worldwide directory')),
                  ],
                  onChanged: _loading ? null : (value) {
                    if (value == null) return;
                    setState(() => _scope = value);
                    _loadPlaylist();
                  },
                ),
              ),
              if (_scope == 'country')
                SizedBox(
                  width: wide ? 220 : 250,
                  child: DropdownButtonFormField<String>(
                    initialValue: _countryCode,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Country', border: OutlineInputBorder()),
                    items: _countryOptions.entries.map((entry) => DropdownMenuItem<String>(value: entry.key, child: Text(entry.value, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: _loading ? null : (value) {
                      if (value == null) return;
                      setState(() => _countryCode = value);
                      _saveTvPreferences();
                      _loadPlaylist();
                    },
                  ),
                ),
              if (_scope == 'category')
                SizedBox(
                  width: wide ? 220 : 250,
                  child: DropdownButtonFormField<String>(
                    initialValue: _category,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                    items: _categoryOptions.entries.map((entry) => DropdownMenuItem<String>(value: entry.key, child: Text(entry.value))).toList(),
                    onChanged: _loading ? null : (value) {
                      if (value == null) return;
                      setState(() => _category = value);
                      _loadPlaylist();
                    },
                  ),
                ),
              SizedBox(
                width: wide ? 260 : 250,
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _search = value),
                  decoration: InputDecoration(
                    labelText: 'Search channels',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _search.isEmpty ? null : IconButton(icon: const Icon(Icons.clear_rounded), onPressed: () { _searchController.clear(); setState(() => _search = ''); }),
                  ),
                ),
              ),
              if (_channels.isNotEmpty)
                SizedBox(
                  width: wide ? 220 : 250,
                  child: DropdownButtonFormField<String>(
                    initialValue: _groups.contains(_groupFilter) ? _groupFilter : 'All groups',
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Channel group', border: OutlineInputBorder()),
                    items: _groups.map((group) => DropdownMenuItem<String>(value: group, child: Text(group, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (value) => setState(() => _groupFilter = value ?? 'All groups'),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              FilterChip(
                avatar: const Icon(Icons.star_rounded, size: 17),
                label: const Text('Favorites only'),
                selected: _favoritesOnly,
                onSelected: (value) => setState(() => _favoritesOnly = value),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(_loading ? 'Loading public channel list…' : '${channels.length} channel${channels.length == 1 ? '' : 's'} shown', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))),
            ],
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_loadError != null) ...<Widget>[
            const SizedBox(height: 10),
            _MessagePanel(message: _loadError!, actionLabel: 'Retry', onAction: _loadPlaylist),
          ],
          const SizedBox(height: 8),
          if (!_loading && channels.isEmpty && _loadError == null)
            const _MessagePanel(message: 'No channels match these filters. Try another group, search, playlist scope, or country.'),
          ...channels.take(500).map((channel) => _channelTile(channel)),
          if (channels.length > 500)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Showing the first 500 matching channels. Narrow your search to see more.', textAlign: TextAlign.center),
            ),
          const SizedBox(height: 18),
          ExpansionTile(
            leading: const Icon(Icons.tune_rounded),
            title: const Text('Playback and buffering tips'),
            subtitle: const Text('VLC and in-app playback use different settings'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: const <Widget>[
              ListTile(
                dense: true,
                leading: Icon(Icons.speed_rounded),
                title: Text('VLC network cache'),
                subtitle: Text('In VLC: Tools → Preferences → Show settings: All → Input / Codecs → Network caching. Try 3000–4000 ms if a stream stutters. This changes VLC only; it does not change the in-app player.'),
              ),
              ListTile(
                dense: true,
                leading: Icon(Icons.info_outline_rounded),
                title: Text('If a channel fails'),
                subtitle: Text('Public directories cannot guarantee the broadcaster is online. Try another channel, refresh the playlist, or open the stream externally. Browser playback support and regional rights vary.'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text('Source directory: iptv-org/iptv. The directory lists stream addresses; it does not operate the broadcasters. Availability and viewing rights vary by channel and region. Prefer broadcaster-owned public streams and do not use this feature to bypass paywalls or access controls.', style: TextStyle(fontSize: 12, color: Colors.white60)),
        ],
      ),
    );
  }

  Future<void> _openFullscreenPlayer(VideoPlayerController player, PublicTvChannel channel) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/app/page/public-live-tv/fullscreen'),
        builder: (fullscreenContext) => _PublicTvFullscreenPlayer(
          player: player,
          channel: channel,
          onMinimize: () {
            if (mounted) setState(() => _playerMinimized = true);
            Navigator.of(fullscreenContext).pop();
          },
        ),
      ),
    );
  }

  Widget _buildPlayerPanel(VideoPlayerController? player, PublicTvChannel? playing) {
    final theme = Theme.of(context);
    if (_playerMinimized && player != null && playing != null && player.value.isInitialized) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: <Widget>[
              const Icon(Icons.picture_in_picture_alt_rounded),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Mini player · ${playing.name}', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              IconButton(
                tooltip: player.value.isPlaying ? 'Pause' : 'Play',
                onPressed: () async {
                  if (player.value.isPlaying) { await player.pause(); } else { await player.play(); }
                  if (mounted) setState(() {});
                },
                icon: Icon(player.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
              ),
              IconButton(
                tooltip: 'Restore player',
                onPressed: () => setState(() => _playerMinimized = false),
                icon: const Icon(Icons.open_in_full_rounded),
              ),
              IconButton(
                tooltip: 'Fullscreen',
                onPressed: () => _openFullscreenPlayer(player, playing),
                icon: const Icon(Icons.fullscreen_rounded),
              ),
              IconButton(tooltip: 'Stop playback', onPressed: _stopPlayer,
                icon: const Icon(Icons.stop_circle_outlined)),
            ],
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: .4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
            child: Row(
              children: <Widget>[
                const Icon(Icons.play_circle_outline_rounded),
                const SizedBox(width: 8),
                Expanded(child: Text(playing?.name ?? 'Choose a channel to start watching', style: const TextStyle(fontWeight: FontWeight.w800))),
                if (playing != null && player != null && player.value.isInitialized) ...<Widget>[
                  IconButton(
                    tooltip: 'Minimize player',
                    onPressed: () => setState(() => _playerMinimized = true),
                    icon: const Icon(Icons.picture_in_picture_alt_rounded),
                  ),
                  IconButton(
                    tooltip: 'Fullscreen',
                    onPressed: () => _openFullscreenPlayer(player, playing),
                    icon: const Icon(Icons.fullscreen_rounded),
                  ),
                  IconButton(tooltip: 'Stop playback', onPressed: _stopPlayer, icon: const Icon(Icons.stop_circle_outlined)),
                ] else if (playing != null)
                  IconButton(tooltip: 'Stop playback', onPressed: _stopPlayer, icon: const Icon(Icons.stop_circle_outlined)),
              ],
            ),
          ),
          if (_playerLoading)
            const AspectRatio(aspectRatio: 16 / 9, child: Center(child: CircularProgressIndicator()))
          else if (_playerError != null && playing != null)
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: <Widget>[
                  const Icon(Icons.signal_wifi_connected_no_internet_4_rounded, size: 34),
                  const SizedBox(height: 8),
                  Text(_playerError!, textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, children: <Widget>[
                    FilledButton.icon(onPressed: () => _playChannel(playing), icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
                    OutlinedButton.icon(onPressed: () => _openStreamExternally(playing), icon: const Icon(Icons.open_in_new_rounded), label: const Text('Open externally')),
                  ]),
                ],
              ),
            )
          else if (player != null && player.value.isInitialized)
            Column(
              children: <Widget>[
                AspectRatio(
                  aspectRatio: player.value.aspectRatio > 0 ? player.value.aspectRatio : 16 / 9,
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      VideoPlayer(player),
                      if (player.value.isBuffering)
                        const CircularProgressIndicator(),
                      DecoratedBox(
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: .12)),
                        child: Center(
                          child: IconButton.filledTonal(
                            tooltip: player.value.isPlaying ? 'Pause' : 'Play',
                            onPressed: () async {
                              if (player.value.isPlaying) {
                                await player.pause();
                              } else {
                                await player.play();
                              }
                              if (mounted) setState(() {});
                            },
                            iconSize: 30,
                            icon: Icon(player.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                VideoProgressIndicator(player, allowScrubbing: false, colors: VideoProgressColors(playedColor: theme.colorScheme.primary)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        tooltip: player.value.volume > 0 ? 'Mute' : 'Unmute',
                        onPressed: () async {
                          await player.setVolume(player.value.volume > 0 ? 0 : 1);
                          if (mounted) setState(() {});
                        },
                        icon: Icon(player.value.volume > 0 ? Icons.volume_up_rounded : Icons.volume_off_rounded),
                      ),
                      const Spacer(),
                      TextButton.icon(onPressed: () => _openStreamExternally(playing!), icon: const Icon(Icons.open_in_new_rounded), label: const Text('Open externally')),
                    ],
                  ),
                ),
              ],
            )
          else
            const AspectRatio(
              aspectRatio: 16 / 9,
              child: Center(child: Icon(Icons.live_tv_rounded, size: 54, color: Colors.white38)),
            ),
        ],
      ),
    );
  }

  Widget _channelTile(PublicTvChannel channel) {
    final theme = Theme.of(context);
    final isPlaying = _playing?.id == channel.id;
    final favorite = _favoriteUrls.contains(channel.id);
    final metadata = <String>[
      channel.group,
      channel.language ?? '',
      channel.country ?? '',
    ].where((value) => value.isNotEmpty).join(' · ');
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: _ChannelLogo(url: channel.logoUrl),
        title: Text(channel.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: isPlaying ? FontWeight.w900 : FontWeight.w600)),
        subtitle: Text(metadata.isEmpty ? 'Public stream listing' : metadata, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: SizedBox(
          width: 96,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              IconButton(
                tooltip: favorite ? 'Remove from favorites' : 'Add to favorites',
                onPressed: () => _toggleFavorite(channel),
                icon: Icon(favorite ? Icons.star_rounded : Icons.star_outline_rounded, color: favorite ? Colors.amber : null),
              ),
              IconButton(
                tooltip: isPlaying ? 'Currently selected' : 'Watch channel',
                onPressed: isPlaying ? null : () => _playChannel(channel),
                icon: Icon(isPlaying ? Icons.equalizer_rounded : Icons.play_circle_outline_rounded, color: isPlaying ? theme.colorScheme.primary : null),
              ),
            ],
          ),
        ),
        onTap: () => _playChannel(channel),
      ),
    );
  }
}

class _ChannelLogo extends StatelessWidget {
  final String? url;
  const _ChannelLogo({this.url});

  @override
  Widget build(BuildContext context) {
    final uri = url == null ? null : Uri.tryParse(url!);
    if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) {
      return const CircleAvatar(child: Icon(Icons.live_tv_rounded));
    }
    return CircleAvatar(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ClipOval(
        child: Image.network(
          url!,
          width: 42,
          height: 42,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(Icons.live_tv_rounded),
        ),
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _MessagePanel({required this.message, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(message),
          if (actionLabel != null && onAction != null) ...<Widget>[
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerLeft, child: OutlinedButton(onPressed: onAction, child: Text(actionLabel!))),
          ],
        ],
      ),
    );
  }
}


/// Fullscreen shell for the currently selected public stream. The parent keeps
/// ownership of the video controller, so exiting fullscreen never restarts it.
class _PublicTvFullscreenPlayer extends StatefulWidget {
  final VideoPlayerController player;
  final PublicTvChannel channel;
  final VoidCallback onMinimize;

  const _PublicTvFullscreenPlayer({
    required this.player,
    required this.channel,
    required this.onMinimize,
  });

  @override
  State<_PublicTvFullscreenPlayer> createState() => _PublicTvFullscreenPlayerState();
}

class _PublicTvFullscreenPlayerState extends State<_PublicTvFullscreenPlayer> {
  @override
  void initState() {
    super.initState();
    widget.player.addListener(_refresh);
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky).catchError((Object _) {}));
  }

  @override
  void dispose() {
    widget.player.removeListener(_refresh);
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge).catchError((Object _) {}));
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    final value = player.value;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (value.isInitialized)
              Center(
                child: AspectRatio(
                  aspectRatio: value.aspectRatio > 0 ? value.aspectRatio : 16 / 9,
                  child: VideoPlayer(player),
                ),
              )
            else
              const Center(child: CircularProgressIndicator()),
            if (value.isBuffering)
              const Center(child: CircularProgressIndicator()),
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Row(
                children: <Widget>[
                  IconButton.filledTonal(
                    tooltip: 'Exit fullscreen',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.fullscreen_exit_rounded),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(widget.channel.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Minimize player',
                    onPressed: widget.onMinimize,
                    icon: const Icon(Icons.picture_in_picture_alt_rounded),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 18,
              child: Row(
                children: <Widget>[
                  IconButton.filledTonal(
                    tooltip: value.isPlaying ? 'Pause' : 'Play',
                    onPressed: () async {
                      if (value.isPlaying) { await player.pause(); } else { await player.play(); }
                    },
                    icon: Icon(value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: value.volume > 0 ? 'Mute' : 'Unmute',
                    onPressed: () async => player.setVolume(value.volume > 0 ? 0 : 1),
                    icon: Icon(value.volume > 0 ? Icons.volume_up_rounded : Icons.volume_off_rounded),
                  ),
                  const Spacer(),
                  const Text('Live stream', style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
