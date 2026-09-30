import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_core.dart';
import 'player.dart';

class _MyTvChannel {
  final String id;
  final String name;
  final String mode;
  final String genre;

  const _MyTvChannel({
    required this.id,
    required this.name,
    required this.mode,
    this.genre = '',
  });

  factory _MyTvChannel.fromJson(Map<String, dynamic> json) => _MyTvChannel(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'My Channel',
        mode: json['mode']?.toString() ?? 'Variety',
        genre: json['genre']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mode': mode,
        'genre': genre,
      };
}

/// Personal, ad-free channel generated only from media accessible to the
/// selected profile. Schedules are local programming plans, not broadcasts.
class MyTvScreen extends StatefulWidget {
  const MyTvScreen({super.key});

  @override
  State<MyTvScreen> createState() => _MyTvScreenState();
}

class _MyTvScreenState extends State<MyTvScreen> {
  List<_MyTvChannel> _channels = const [];
  Map<String, List<String>> _recentlyPlayed = {};
  String? _selectedChannelId;
  bool _loading = true;
  String? _error;
  final Random _random = Random();

  String get _profileId =>
      AppController.instance.currentProfile?.id ?? 'default';
  String get _preferenceKey => 'my_tv_settings_$_profileId';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic>? data;
    final api = AppController.instance.backendApi;
    if (api.isAuthenticated && _profileId != 'default') {
      try {
        final records = await api.getPhase2Records(
          profileId: _profileId,
          recordType: 'my_tv_settings',
        );
        for (final record in records) {
          if (record['recordKey'] == 'settings' && record['data'] is Map) {
            data = Map<String, dynamic>.from(record['data'] as Map);
            break;
          }
        }
      } catch (_) {
        _error = 'Could not sync channel settings. Using this device’s saved settings.';
      }
    }
    data ??= _decode(prefs.getString(_preferenceKey));
    final rawChannels = data?['channels'];
    final channels = rawChannels is List
        ? rawChannels
            .whereType<Map>()
            .map((item) => _MyTvChannel.fromJson(
                  Map<String, dynamic>.from(item),
                ))
            .where((channel) => channel.id.isNotEmpty)
            .toList()
        : <_MyTvChannel>[];
    if (channels.isEmpty) {
      channels.add(const _MyTvChannel(
        id: 'my-channel',
        name: 'My Channel',
        mode: 'Variety',
      ));
    }
    final rawRecent = data?['recentlyPlayed'];
    final recent = <String, List<String>>{};
    if (rawRecent is Map) {
      for (final entry in rawRecent.entries) {
        if (entry.value is List) {
          recent[entry.key.toString()] =
              (entry.value as List).map((id) => id.toString()).toList();
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _channels = channels;
      _recentlyPlayed = recent;
      _selectedChannelId ??= channels.first.id;
      _loading = false;
    });
  }

  Map<String, dynamic>? _decode(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _save() async {
    final data = <String, dynamic>{
      'channels': _channels.map((channel) => channel.toJson()).toList(),
      'recentlyPlayed': _recentlyPlayed,
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferenceKey, jsonEncode(data));
    final api = AppController.instance.backendApi;
    if (api.isAuthenticated && _profileId != 'default') {
      try {
        await api.savePhase2Record(
          profileId: _profileId,
          recordType: 'my_tv_settings',
          recordKey: 'settings',
          data: data,
        );
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Saved on this device. Server sync will retry later.'),
            ),
          );
        }
      }
    }
  }

  _MyTvChannel? get _selected {
    for (final channel in _channels) {
      if (channel.id == _selectedChannelId) return channel;
    }
    return _channels.isEmpty ? null : _channels.first;
  }

  List<MediaItem> _schedule(_MyTvChannel channel) {
    final controller = AppController.instance;
    final profile = controller.currentProfile;
    var eligible = controller.library
        .where((media) =>
            media.isAccessibleTo(profile) &&
            _isPlayable(media) &&
            media.type.toLowerCase() != 'extra')
        .toList();
    if (channel.mode == 'Favorites') {
      eligible = eligible.where((media) => controller.isLiked(media.id)).toList();
    }
    final genre = channel.genre.trim().toLowerCase();
    if (channel.mode == 'Genre' && genre.isNotEmpty) {
      eligible = eligible
          .where((media) => [...media.genres, ...media.tags]
              .any((value) => value.toLowerCase() == genre))
          .toList();
    }
    if (eligible.length < 3) return const [];
    final recent = _recentlyPlayed[channel.id] ?? const <String>[];
    final unseen = eligible.where((media) => !recent.take(8).contains(media.id)).toList();
    if (unseen.length >= 3) eligible = unseen;

    eligible.shuffle(_random);
    if (channel.mode == 'Variety') {
      final groups = <String, List<MediaItem>>{};
      for (final media in eligible) {
        final key = media.genres.isEmpty ? 'Other' : media.genres.first;
        groups.putIfAbsent(key, () => <MediaItem>[]).add(media);
      }
      final keys = groups.keys.toList()..shuffle(_random);
      eligible = <MediaItem>[];
      while (keys.any((key) => groups[key]!.isNotEmpty)) {
        for (final key in keys) {
          if (groups[key]!.isNotEmpty) eligible.add(groups[key]!.removeAt(0));
        }
      }
    }
    return eligible.take(24).toList(growable: false);
  }

  bool _isPlayable(MediaItem media) {
    final type = media.type.toLowerCase();
    return type.contains('movie') || type.contains('film') ||
        type.contains('tv') || type.contains('show') ||
        type.contains('series') || type.contains('episode');
  }

  Future<void> _addChannel() async {
    final name = TextEditingController();
    final genre = TextEditingController();
    var mode = 'Variety';
    final added = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create a channel'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Channel name')),
            DropdownButtonFormField<String>(
              initialValue: mode,
              items: const [
                DropdownMenuItem(value: 'Variety', child: Text('Smart variety')),
                DropdownMenuItem(value: 'Random', child: Text('Random')),
                DropdownMenuItem(value: 'Favorites', child: Text('Liked titles')),
                DropdownMenuItem(value: 'Genre', child: Text('One genre')),
              ],
              onChanged: (value) => setDialogState(() => mode = value ?? mode),
              decoration: const InputDecoration(labelText: 'Programming mode'),
            ),
            if (mode == 'Genre') TextField(controller: genre, decoration: const InputDecoration(labelText: 'Genre')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Create')),
          ],
        ),
      ),
    );
    final channelName = name.text.trim();
    final channelGenre = genre.text.trim();
    name.dispose();
    genre.dispose();
    if (added != true || channelName.isEmpty || (mode == 'Genre' && channelGenre.isEmpty)) return;
    final channel = _MyTvChannel(
      id: 'my_tv_${DateTime.now().microsecondsSinceEpoch}',
      name: channelName,
      mode: mode,
      genre: channelGenre,
    );
    setState(() {
      _channels = [..._channels, channel];
      _selectedChannelId = channel.id;
    });
    await _save();
  }

  Future<void> _play(MediaItem media) async {
    final channel = _selected;
    if (channel != null) {
      final recent = List<String>.from(_recentlyPlayed[channel.id] ?? const []);
      recent.remove(media.id);
      recent.insert(0, media.id);
      _recentlyPlayed[channel.id] = recent.take(40).toList();
      await _save();
    }
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(media: media)));
  }

  @override
  Widget build(BuildContext context) {
    final channel = _selected;
    final schedule = channel == null ? const <MediaItem>[] : _schedule(channel);
    return Scaffold(
      appBar: AppBar(
        title: const Text('My TV'),
        actions: [IconButton(onPressed: _loading ? null : _addChannel, tooltip: 'Create channel', icon: const Icon(Icons.add))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                if (_error != null) Text(_error!, style: const TextStyle(color: Colors.amber)),
                const Text('Your library, programmed as a channel', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                const Text('Personal programming uses media available to this profile. No commercial ads are inserted.', style: TextStyle(color: Colors.white60)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedChannelId,
                  items: _channels.map((item) => DropdownMenuItem(value: item.id, child: Text(item.name))).toList(),
                  onChanged: (value) => setState(() => _selectedChannelId = value),
                  decoration: const InputDecoration(labelText: 'Channel'),
                ),
                if (channel != null) Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('${channel.mode}${channel.genre.isEmpty ? '' : ' · ${channel.genre}'} · profile-specific'),
                ),
                const SizedBox(height: 18),
                if (schedule.isEmpty)
                  const Card(child: ListTile(leading: Icon(Icons.tv_off_outlined), title: Text('Not enough eligible titles yet'), subtitle: Text('A channel needs at least three accessible movies or episodes that match its rules.')))
                else ...[
                  _scheduleCard(context, 'Now Playing', schedule[0], 'Play now'),
                  for (var i = 1; i < schedule.length; i++)
                    _scheduleCard(context, i == 1 ? 'Next' : 'Later', schedule[i], null, index: i),
                  const SizedBox(height: 12),
                  Text('TV Guide · ${schedule.length} titles queued', style: const TextStyle(color: Colors.white54)),
                ],
              ],
            ),
    );
  }

  Widget _scheduleCard(BuildContext context, String slot, MediaItem media, String? action, {int? index}) => Card(
        child: ListTile(
          leading: CircleAvatar(child: Text(index == null ? '▶' : '${index + 1}')),
          title: Text('$slot · ${media.title}', maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${media.type}${media.genres.isEmpty ? '' : ' · ${media.genres.first}'}'),
          trailing: action == null
              ? IconButton(tooltip: 'Play now', onPressed: () => _play(media), icon: const Icon(Icons.play_arrow_rounded))
              : FilledButton(onPressed: () => _play(media), child: Text(action)),
          onTap: () => _play(media),
        ),
      );
}
