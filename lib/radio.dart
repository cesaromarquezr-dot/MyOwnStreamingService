// FILE: `lib/radio.dart`.
// Purpose: First-class AM/FM and internet radio discovery, playback, favorites,
// and listening-location controls.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import 'app_core.dart';
import 'localization.dart';

class RadioScreen extends StatefulWidget {
  const RadioScreen({super.key});

  @override
  State<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends State<RadioScreen> {
  final _country = TextEditingController();
  final _state = TextEditingController();
  final _city = TextEditingController();
  final _search = TextEditingController();
  final Set<String> _favorites = <String>{};
  final List<Map<String, dynamic>> _recent = <Map<String, dynamic>>[];

  List<Map<String, dynamic>> _stations = const [];
  Map<String, dynamic>? _selected;
  VideoPlayerController? _player;
  bool _loading = false;
  bool _gettingLocation = false;
  bool _playing = false;
  String _band = 'All';
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLocalState();
  }

  Future<void> _loadLocalState() async {
    final prefs = await SharedPreferences.getInstance();
    final location = prefs.getStringList('radio_listening_location') ?? const [];
    if (location.isNotEmpty) _country.text = location.elementAt(0);
    if (location.length > 1) _state.text = location.elementAt(1);
    if (location.length > 2) _city.text = location.elementAt(2);
    _favorites.addAll(prefs.getStringList('radio_favorites') ?? const []);
    final recentJson = prefs.getStringList('radio_recent') ?? const [];
    _recent.addAll(recentJson.map((value) => {'name': value}));
    if (mounted) {
      setState(() {});
      _discoverNearbyStations();
    }
  }

  Future<void> _saveLocalState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('radio_listening_location', [
      _country.text.trim().toUpperCase(),
      _state.text.trim(),
      _city.text.trim(),
    ]);
    await prefs.setStringList('radio_favorites', _favorites.toList());
    await prefs.setStringList(
      'radio_recent',
      _recent.take(20).map((value) => value['name']?.toString() ?? '').where((v) => v.isNotEmpty).toList(),
    );
  }

  Future<void> _loadStations() async {
    if (!AppController.instance.backendApi.isAuthenticated) {
      setState(() => _error = 'Sign in to discover radio stations.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stations = await AppController.instance.backendApi.getRadioStations(
        countryCode: _country.text.trim(),
        state: _state.text.trim(),
        city: _city.text.trim(),
        query: _search.text.trim(),
        band: _band == 'All' ? null : _band,
        limit: 60,
      );
      if (!mounted) return;
      setState(() => _stations = stations);
      await _saveLocalState();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _discoverNearbyStations() async {
    if (_gettingLocation) return;
    setState(() {
      _gettingLocation = true;
      _error = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError('Turn on device location to find nearby radio stations.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw StateError('Allow location access to discover local radio stations.');
      }
      if (permission == LocationPermission.deniedForever) {
        throw StateError('Location access is disabled for this app. Enable it in device settings.');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final location = await AppController.instance.backendApi.reverseGeocode(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      final countryCode = location['countryCode']?.toString().trim() ?? '';
      final city = location['city']?.toString().trim() ?? '';
      if (countryCode.isEmpty || city.isEmpty) {
        throw StateError('A nearby city could not be determined from your location.');
      }
      if (!mounted) return;
      setState(() {
        _country.text = countryCode;
        _state.text = location['state']?.toString().trim() ?? '';
        _city.text = city;
      });
      await _saveLocalState();
      await _loadStations();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error
              .toString()
              .replaceFirst('Bad state: ', '')
              .replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  Future<void> _play(Map<String, dynamic> station) async {
    final url = station['streamUrl']?.toString() ?? '';
    if (url.isEmpty) {
      await _openStream(station);
      return;
    }
    await _player?.dispose();
    VideoPlayerController? controller;
    try {
      controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize().timeout(const Duration(seconds: 15));
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _player = controller;
        _selected = station;
        _playing = true;
      });
      await controller.play();
      _recent.removeWhere((row) => row['id'] == station['id']);
      _recent.insert(0, {'id': station['id'], 'name': station['name']});
      await _saveLocalState();
    } catch (_) {
      await controller?.dispose();
      if (mounted) {
        setState(() {
          _player = null;
          _playing = false;
          _selected = station;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: UniversalText('This stream could not be played in-app. You can open the broadcaster stream instead.')),
        );
      }
    }
  }

  Future<void> _openStream(Map<String, dynamic> station) async {
    final raw = (station['listenUrl'] ?? station['homepage'] ?? station['streamUrl'])?.toString() ?? '';
    final url = Uri.tryParse(raw);
    if (url != null && (url.scheme == 'http' || url.scheme == 'https')) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _toggleFavorite(Map<String, dynamic> station) async {
    final id = station['id']?.toString() ?? '';
    if (id.isEmpty) return;
    setState(() {
      if (!_favorites.add(id)) _favorites.remove(id);
    });
    await _saveLocalState();
  }

  @override
  Widget build(BuildContext context) {
    final active = _selected;
    return Scaffold(
      appBar: AppBar(
        title: const UniversalText('Radio'),
        actions: [
          IconButton(
            tooltip: tr('Listening location'),
            onPressed: _gettingLocation ? null : _discoverNearbyStations,
            icon: const Icon(Icons.location_on_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _discoverNearbyStations,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
          children: [
            _LocationCard(
              country: _country.text,
              state: _state.text,
              city: _city.text,
              locating: _gettingLocation,
              onDiscover: _discoverNearbyStations,
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  TextField(
                    controller: _search,
                    onSubmitted: (_) => _loadStations(),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintText: tr('Search station, city, or call sign'),
                      suffixIcon: IconButton(onPressed: _loadStations, icon: const Icon(Icons.arrow_forward_rounded)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      for (final value in const ['All', 'AM', 'FM'])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(value),
                            selected: _band == value,
                            onSelected: (_) {
                              setState(() => _band = value);
                              _loadStations();
                            },
                          ),
                        ),
                      for (final value in const ['music', 'news', 'sports', 'talk', 'public'])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(label: Text(value), onPressed: () => _loadTag(value)),
                        ),
                    ]),
                  ),
                ]),
              ),
            ),
            if (_loading || _gettingLocation)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(),
              ),
            if (_error != null)
              Card(child: Padding(padding: const EdgeInsets.all(14), child: Text(_error!, style: const TextStyle(color: Colors.amber)))),
            if (active != null) ...[
              const SizedBox(height: 8),
              _NowPlayingCard(
                station: active,
                playing: _playing,
                onPlayPause: () async {
                  final player = _player;
                  if (player == null) return;
                  if (player.value.isPlaying) {
                    await player.pause();
                  } else {
                    await player.play();
                  }
                  if (mounted) setState(() => _playing = player.value.isPlaying);
                },
                onStop: () async {
                  await _player?.pause();
                  if (mounted) setState(() => _playing = false);
                },
                onOpen: () => _openStream(active),
              ),
              const SizedBox(height: 12),
            ],
            if (_recent.isNotEmpty) ...[
              const _SectionHeader('Recently Heard', Icons.history_rounded),
              const SizedBox(height: 8),
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _recent.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, index) => Chip(
                    avatar: const Icon(Icons.radio_rounded, size: 18),
                    label: Text(_recent[index]['name']?.toString() ?? 'Station'),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            const _SectionHeader('Stations', Icons.radio_rounded),
            const SizedBox(height: 8),
            if (_stations.isEmpty && !_loading)
              const Card(child: Padding(padding: EdgeInsets.all(18), child: UniversalText('Choose a listening location and discover local stations.')))
            else
              for (final station in _stations) _stationCard(station),
          ],
        ),
      ),
    );
  }

  Future<void> _loadTag(String tag) async {
    if (!AppController.instance.backendApi.isAuthenticated) return;
    setState(() => _loading = true);
    try {
      final stations = await AppController.instance.backendApi.getRadioStations(
        countryCode: _country.text.trim(), state: _state.text.trim(), city: _city.text.trim(), tag: tag, limit: 60,
      );
      if (mounted) setState(() => _stations = stations);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _stationCard(Map<String, dynamic> station) {
    final id = station['id']?.toString() ?? '';
    final favorite = _favorites.contains(id);
    final tags = station['tags']?.toString() ?? '';
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Icon((station['band']?.toString() == 'AM') ? Icons.graphic_eq_rounded : Icons.radio_rounded)),
        title: Text(station['name']?.toString() ?? 'Station', style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
          [station['band'], station['frequency'], station['city'], station['state'], if (tags.isNotEmpty) tags]
              .where((value) => value != null && value.toString().trim().isNotEmpty)
              .map((value) => value.toString())
              .join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Wrap(spacing: 2, children: [
          IconButton(onPressed: () => _toggleFavorite(station), icon: Icon(favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded)),
          IconButton(
            onPressed: () => _play(station),
            tooltip: station['streamAvailable'] == true ? 'Play station' : 'Open broadcaster',
            icon: Icon(station['streamAvailable'] == true ? Icons.play_arrow_rounded : Icons.open_in_new_rounded),
          ),
        ]),
        onTap: () => _play(station),
      ),
    );
  }

  @override
  void dispose() {
    _player?.dispose();
    _country.dispose();
    _state.dispose();
    _city.dispose();
    _search.dispose();
    super.dispose();
  }
}

class _LocationCard extends StatelessWidget {
  final String country;
  final String state;
  final String city;
  final bool locating;
  final VoidCallback onDiscover;

  const _LocationCard({
    required this.country,
    required this.state,
    required this.city,
    required this.locating,
    required this.onDiscover,
  });

  @override
  Widget build(BuildContext context) {
    final location = [city, state, country].where((v) => v.trim().isNotEmpty).join(', ');
    return Card(
      child: ListTile(
        leading: const Icon(Icons.location_searching_rounded),
        title: UniversalText(location.isEmpty ? 'Finding your current location…' : location),
        subtitle: const UniversalText(
          'Device location resolves your city with OpenStreetMap. Only your country, region, and city are saved on this device.',
        ),
        trailing: IconButton(
          tooltip: 'Update my location',
          onPressed: locating ? null : onDiscover,
          icon: locating
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.my_location_rounded),
        ),
      ),
    );
  }
}

class _NowPlayingCard extends StatelessWidget {
  final Map<String, dynamic> station;
  final bool playing;
  final VoidCallback onPlayPause;
  final VoidCallback onStop;
  final VoidCallback onOpen;

  const _NowPlayingCard({required this.station, required this.playing, required this.onPlayPause, required this.onStop, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const UniversalText('Now Playing', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(station['name']?.toString() ?? 'Radio station', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(station['nowPlaying']?.toString() ?? 'Live station stream', style: const TextStyle(color: Colors.white60)),
          const SizedBox(height: 12),
          Row(children: [
            if (station['streamAvailable'] == true) ...[
              IconButton.filledTonal(onPressed: onPlayPause, icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded)),
              IconButton(onPressed: onStop, icon: const Icon(Icons.stop_rounded)),
            ],
            const Spacer(),
            OutlinedButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text(station['streamAvailable'] == true ? 'Open broadcaster' : 'Listen at broadcaster'),
            ),
          ]),
          const SizedBox(height: 8),
          UniversalText(
            station['streamAvailable'] == true
                ? 'Song identification appears when the broadcaster supplies track metadata. Identified songs can then connect to your wishlist, playlists, albums, editions, and library.'
                : 'This broadcaster does not publish a raw stream to the station directory. The official listening page is provided so the station still appears in your local market.',
          ),
        ]),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader(this.title, this.icon);
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
      ]);
}
