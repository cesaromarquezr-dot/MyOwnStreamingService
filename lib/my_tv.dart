import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_core.dart';
import 'music.dart';
import 'music_favorites.dart';
import 'player.dart';
import 'profile_content_safety.dart';

const _channelContentTypes = <String>['Movies', 'Shows', 'Music'];

class _MyTvChannel {
  final String id;
  final String name;
  final List<String> contentTypes;
  final bool shuffle;
  final String filterText;
  final bool favoritesOnly;
  final bool isFavorite;
  final int startTimeMinutes;

  const _MyTvChannel({
    required this.id,
    required this.name,
    this.contentTypes = _channelContentTypes,
    this.shuffle = true,
    this.filterText = '',
    this.favoritesOnly = false,
    this.isFavorite = false,
    this.startTimeMinutes = 420,
  });

  factory _MyTvChannel.fromJson(Map<String, dynamic> json) => _MyTvChannel(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'My Channel',
        contentTypes: json['contentTypes'] is List
            ? (json['contentTypes'] as List)
                .map((value) => value.toString())
                .where(_channelContentTypes.contains)
                .toList()
            : _channelContentTypes,
        shuffle: json['shuffle'] is bool ? json['shuffle'] as bool : true,
        filterText: json['filterText']?.toString() ??
            json['customQuery']?.toString() ??
            json['genre']?.toString() ??
            _legacyFilter(
                json['template']?.toString(), json['mode']?.toString()),
        favoritesOnly: json['favoritesOnly'] == true ||
            json['mode']?.toString() == 'Favorites',
        isFavorite: json['isFavorite'] == true,
        startTimeMinutes: ((json['startTimeMinutes'] as num?)?.toInt() ?? 420)
            .clamp(0, 1439)
            .toInt(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'contentTypes': contentTypes,
        'shuffle': shuffle,
        'filterText': filterText,
        'favoritesOnly': favoritesOnly,
        'isFavorite': isFavorite,
        'startTimeMinutes': startTimeMinutes,
      };
}

String _legacyFilter(String? template, String? mode) {
  if (mode == 'Favorites' ||
      template == null ||
      template.startsWith('Variety')) {
    return '';
  }
  return template;
}

class _ChannelEntry {
  final MediaItem? media;
  final MusicTrack? track;

  const _ChannelEntry.media(this.media) : track = null;
  const _ChannelEntry.track(this.track) : media = null;

  String get id => media != null ? 'video:${media!.id}' : 'music:${track!.id}';
  String get title => media?.title ?? track!.title;
  String get subtitle => media != null
      ? '${media!.type}${media!.genres.isEmpty ? '' : ' · ${media!.genres.first}'}'
      : '${track!.artist} · ${track!.album}';
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
  bool _showGuide = false;
  String? _error;

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
        final records = await api.getAppRecords(
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
        _error =
            'Could not sync channel settings. Using this device’s saved settings.';
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
      channels.add(const _MyTvChannel(id: 'variety-channel', name: 'Variety'));
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
        await api.saveAppRecord(
          profileId: _profileId,
          recordType: 'my_tv_settings',
          recordKey: 'settings',
          data: data,
        );
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Saved on this device. Server sync will retry later.'),
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleFavorite(_MyTvChannel channel) async {
    setState(() {
      _channels = _channels
          .map((item) => item.id == channel.id
              ? _MyTvChannel(
                  id: item.id,
                  name: item.name,
                  contentTypes: item.contentTypes,
                  shuffle: item.shuffle,
                  filterText: item.filterText,
                  favoritesOnly: item.favoritesOnly,
                  isFavorite: !item.isFavorite,
                  startTimeMinutes: item.startTimeMinutes,
                )
              : item)
          .toList();
    });
    await _save();
  }

  _MyTvChannel? get _selected {
    for (final channel in _channels) {
      if (channel.id == _selectedChannelId) return channel;
    }
    return _channels.isEmpty ? null : _channels.first;
  }

  List<_ChannelEntry> _schedule(_MyTvChannel channel) {
    final controller = AppController.instance;
    final profile = controller.currentProfile;
    final terms = channel.filterText
        .split(RegExp(r'[,;\n]'))
        .map((term) => term.trim().toLowerCase())
        .where((term) => term.isNotEmpty)
        .toList();
    bool matches(List<String> fields) {
      if (terms.isEmpty) return true;
      final text = fields.join(' ').toLowerCase();
      return terms.any(text.contains);
    }

    final matchingMedia = controller.library
        .where((media) =>
            media.isAccessibleTo(profile) &&
            _isPlayable(media) &&
            media.type.toLowerCase() != 'extra' &&
            matches([
              media.title,
              media.type,
              media.description ?? '',
              media.franchiseName ?? '',
              ...media.actors,
              ...media.directors,
              ...media.writers,
              ...media.music,
              ...media.genres,
              ...media.tags,
            ]) &&
            (!channel.favoritesOnly || controller.isLiked(media.id)))
        .toList();
    var eligible = matchingMedia
        .where((media) => _channelAcceptsVideoType(channel, media.type))
        .map(_ChannelEntry.media)
        .toList();
    final tracks = MusicLibraryStore.instance.tracks.where((track) {
      if (!channel.contentTypes.contains('Music') ||
          track.audioUrl?.trim().isNotEmpty != true ||
          (profileBlocksExplicitMusic(profile) && track.explicit) ||
          (profileBlocksMatureMusic(profile) && track.matureTheme) ||
          (channel.favoritesOnly &&
              !MusicFavoritesBridge.likedTracks().contains(track.id))) {
        return false;
      }
      final trackMatches = matches([
        track.title,
        track.artist,
        track.album,
        ...track.featuredArtists,
        ...track.genres,
        ...track.subgenres,
      ]);
      final trackTitle = track.title.trim().toLowerCase();
      final soundtrackMatches = terms.isNotEmpty &&
          trackTitle.isNotEmpty &&
          matchingMedia.any((media) => media.music.any(
                (song) => song.toLowerCase().contains(trackTitle),
              ));
      return terms.isEmpty || trackMatches || soundtrackMatches;
    });
    eligible.addAll(tracks.map(_ChannelEntry.track));
    if (eligible.isEmpty) return const [];
    final recent = _recentlyPlayed[channel.id] ?? const <String>[];
    final unseen =
        eligible.where((entry) => !recent.take(8).contains(entry.id)).toList();
    if (unseen.isNotEmpty) eligible = unseen;

    if (channel.shuffle) {
      // Keep the same guide ordering while rebuilding the screen.
      eligible.shuffle(Random(channel.id.hashCode));
    }
    return eligible.take(24).toList(growable: false);
  }

  bool _channelAcceptsVideoType(_MyTvChannel channel, String type) {
    final normalized = type.toLowerCase();
    final isShow = normalized.contains('tv') ||
        normalized.contains('show') ||
        normalized.contains('series') ||
        normalized.contains('episode');
    return channel.contentTypes.contains(isShow ? 'Shows' : 'Movies');
  }

  bool _isPlayable(MediaItem media) {
    final type = media.type.toLowerCase();
    return type.contains('movie') ||
        type.contains('film') ||
        type.contains('tv') ||
        type.contains('show') ||
        type.contains('series') ||
        type.contains('episode');
  }

  int _durationMinutes(_ChannelEntry entry) {
    if (entry.track != null) {
      final durationSeconds = entry.track!.duration.inSeconds;
      return durationSeconds > 0 ? (durationSeconds + 59) ~/ 60 : 4;
    }
    final type = entry.media?.type.toLowerCase() ?? '';
    final isEpisode = type.contains('tv') ||
        type.contains('show') ||
        type.contains('series') ||
        type.contains('episode');
    return isEpisode ? 30 : 120;
  }

  String _scheduleTime(
    BuildContext context,
    _MyTvChannel channel,
    List<_ChannelEntry> entries,
    int index,
  ) {
    final elapsed = entries
        .take(index)
        .fold<int>(0, (total, entry) => total + _durationMinutes(entry));
    final minutes = (channel.startTimeMinutes + elapsed) % (24 * 60);
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60).format(context);
  }

  Future<void> _addChannel() async {
    final name = TextEditingController();
    final filterText = TextEditingController();
    final selectedTypes = _channelContentTypes.toSet();
    var favoritesOnly = false;
    var startTime = const TimeOfDay(hour: 7, minute: 0);
    final added = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create a channel'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Channel name')),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    final selected = await showTimePicker(
                      context: context,
                      initialTime: startTime,
                    );
                    if (selected != null) {
                      setDialogState(() => startTime = selected);
                    }
                  },
                  icon: const Icon(Icons.schedule_rounded),
                  label: Text(
                      'Daily guide starts at ${startTime.format(context)}'),
                ),
              ),
              const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text('Include in channel'),
                  )),
              Wrap(
                spacing: 8,
                children: _channelContentTypes
                    .map((type) => FilterChip(
                          label: Text(type),
                          selected: selectedTypes.contains(type),
                          onSelected: (selected) => setDialogState(() {
                            if (selected) {
                              selectedTypes.add(type);
                            } else {
                              selectedTypes.remove(type);
                            }
                          }),
                        ))
                    .toList(),
              ),
              TextField(
                controller: filterText,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'What belongs in this channel?',
                  hintText:
                      'Add your own genres, series, artists, people, or keywords',
                  helperText:
                      'Separate themes, titles, artists, actors, or genres with commas or new lines.',
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Only include liked items'),
                value: favoritesOnly,
                onChanged: (value) =>
                    setDialogState(() => favoritesOnly = value ?? false),
              ),
              const Text(
                  'Channels use media available to this profile. Music can also match soundtrack titles linked to matching movies or shows in your library.'),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Create')),
          ],
        ),
      ),
    );
    final channelName = name.text.trim();
    final channelFilter = filterText.text.trim();
    name.dispose();
    filterText.dispose();
    if (added != true || channelName.isEmpty || selectedTypes.isEmpty) return;
    final channel = _MyTvChannel(
      id: 'my_tv_${DateTime.now().microsecondsSinceEpoch}',
      name: channelName,
      contentTypes: _channelContentTypes.where(selectedTypes.contains).toList(),
      filterText: channelFilter,
      favoritesOnly: favoritesOnly,
      startTimeMinutes: startTime.hour * 60 + startTime.minute,
    );
    setState(() {
      _channels = [..._channels, channel];
      _selectedChannelId = channel.id;
    });
    await _save();
  }

  Future<void> _play(_ChannelEntry entry, {String? channelId}) async {
    final targetChannelId = channelId ?? _selected?.id;
    if (targetChannelId != null) {
      final recent =
          List<String>.from(_recentlyPlayed[targetChannelId] ?? const []);
      recent.remove(entry.id);
      recent.insert(0, entry.id);
      _recentlyPlayed[targetChannelId] = recent.take(40).toList();
      await _save();
    }
    if (!mounted) return;
    if (entry.track != null) {
      await MusicPlaybackController.instance.play(entry.track!);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: '/app/player'),
          builder: (_) => PlayerScreen(media: entry.media!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final channel = _selected;
    final schedule =
        channel == null ? const <_ChannelEntry>[] : _schedule(channel);
    return Scaffold(
      appBar: AppBar(
        title: const Text('My TV'),
        actions: [
          IconButton(
              onPressed: _loading
                  ? null
                  : () => setState(() => _showGuide = !_showGuide),
              tooltip: 'TV Guide',
              icon: Icon(_showGuide
                  ? Icons.live_tv_rounded
                  : Icons.calendar_view_week_rounded)),
          IconButton(
              onPressed: _loading ? null : _addChannel,
              tooltip: 'Create channel',
              icon: const Icon(Icons.add)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: Colors.amber)),
                Text(
                    _showGuide
                        ? 'TV Guide'
                        : 'Your library, programmed as a channel',
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(
                    _showGuide
                        ? 'Today’s channel schedules · no commercial ads'
                        : 'Personal programming uses media available to this profile. No commercial ads are inserted.',
                    style: const TextStyle(color: Colors.white60)),
                if (_showGuide)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Unavailable runtimes are estimated at 30 minutes for episodes and 2 hours for movies.',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 16),
                if (_showGuide) ..._guideCards(context),
                if (!_showGuide) ...[
                  Row(children: [
                    Expanded(
                        child: DropdownButtonFormField<String>(
                      initialValue: _selectedChannelId,
                      items: _channels
                          .map((item) => DropdownMenuItem(
                              value: item.id, child: Text(item.name)))
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedChannelId = value),
                      decoration: const InputDecoration(labelText: 'Channel'),
                    )),
                    if (channel != null)
                      IconButton(
                        tooltip: channel.isFavorite
                            ? 'Remove favorite channel'
                            : 'Favorite channel',
                        onPressed: () => _toggleFavorite(channel),
                        icon: Icon(channel.isFavorite
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded),
                        color: channel.isFavorite ? Colors.amber : null,
                      ),
                  ]),
                  const SizedBox(height: 18),
                  if (channel != null) ...[
                    Text(
                      [
                        channel.contentTypes.join(' · '),
                        if (channel.filterText.trim().isNotEmpty)
                          channel.filterText.trim().replaceAll(
                                RegExp(r'[,;\n]+'),
                                ' · ',
                              ),
                      ].join('  |  '),
                      style: const TextStyle(color: Colors.white54),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (schedule.isEmpty)
                    const Card(
                        child: ListTile(
                            leading: Icon(Icons.tv_off_outlined),
                            title: Text('No matching library items yet'),
                            subtitle: Text(
                                'Add matching movies, shows, episodes, or music to this profile library.')))
                  else ...[
                    _scheduleCard(
                      context,
                      '${_scheduleTime(context, channel!, schedule, 0)} · Now',
                      schedule[0],
                      'Play now',
                      channelId: channel.id,
                    ),
                    for (var i = 1; i < schedule.length; i++)
                      _scheduleCard(
                        context,
                        _scheduleTime(context, channel, schedule, i),
                        schedule[i],
                        null,
                        channelId: channel.id,
                      ),
                    const SizedBox(height: 12),
                    Text('${channel.name} · ${schedule.length} items queued',
                        style: const TextStyle(color: Colors.white54)),
                  ],
                ],
              ],
            ),
    );
  }

  List<Widget> _guideCards(BuildContext context) => (_channels.toList()
            ..sort((a, b) =>
                (b.isFavorite ? 1 : 0).compareTo(a.isFavorite ? 1 : 0)))
          .map((channel) {
        final entries = _schedule(channel);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                      child: Text(channel.name,
                          style: Theme.of(context).textTheme.titleLarge)),
                  IconButton(
                    tooltip: channel.isFavorite
                        ? 'Remove favorite channel'
                        : 'Favorite channel',
                    onPressed: () => _toggleFavorite(channel),
                    icon: Icon(channel.isFavorite
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded),
                    color: channel.isFavorite ? Colors.amber : null,
                  ),
                ]),
                if (entries.isEmpty)
                  const ListTile(
                      title: Text('No matching items'),
                      subtitle:
                          Text('Add matching items to this profile library.'))
                else
                  for (var i = 0; i < min(entries.length, 12); i++)
                    _scheduleCard(
                      context,
                      _scheduleTime(context, channel, entries, i),
                      entries[i],
                      null,
                      channelId: channel.id,
                    ),
              ],
            ),
          ),
        );
      }).toList();

  Widget _scheduleCard(BuildContext context, String slot, _ChannelEntry entry,
          String? action,
          {String? channelId}) =>
      Card(
        child: ListTile(
          leading: CircleAvatar(
              child: Icon(entry.track == null
                  ? Icons.movie_outlined
                  : Icons.music_note_rounded)),
          title: Text('$slot · ${entry.title}',
              maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(entry.subtitle),
          trailing: action == null
              ? IconButton(
                  tooltip: 'Play now',
                  onPressed: () => _play(entry, channelId: channelId),
                  icon: const Icon(Icons.play_arrow_rounded))
              : FilledButton(
                  onPressed: () => _play(entry, channelId: channelId),
                  child: Text(action)),
          onTap: () => _play(entry, channelId: channelId),
        ),
      );
}
