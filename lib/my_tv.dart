import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_core.dart';
import 'music.dart';
import 'music_favorites.dart';
import 'player.dart';
import 'profile_content_safety.dart';
import 'core/services/tv_programming_service.dart';
import 'core/models/tv_channel.dart';
import 'core/services/tv_channel_engine.dart';

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
  final List<TvProgrammingRule> programmingRules;

  const _MyTvChannel({
    required this.id,
    required this.name,
    this.contentTypes = _channelContentTypes,
    this.shuffle = true,
    this.filterText = '',
    this.favoritesOnly = false,
    this.isFavorite = false,
    this.startTimeMinutes = 420,
    this.programmingRules = const [],
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
        programmingRules: json['programmingRules'] is List
            ? (json['programmingRules'] as List)
                .whereType<Map>()
                .map((e) => TvProgrammingRule.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : const [],
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
        'programmingRules': programmingRules.map((rule) => rule.toJson()).toList(),
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
  String get _accountId => AppController.instance.currentAccount?.id ?? 'local';
  String get _preferenceKey => 'my_tv_settings_account_$_accountId';

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
          recordType: 'my_tv_settings',
        );
        for (final record in records) {
          if (record['recordKey'] == 'account_settings' && record['data'] is Map) {
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
    final channelsInitialized = data?['channelsInitialized'] == true;
    if (channels.isEmpty && !channelsInitialized) {
      channels.add(const _MyTvChannel(
        id: 'variety-channel',
        name: 'Variety',
        startTimeMinutes: 0,
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
      'channelsInitialized': true,
      'recentlyPlayed': _recentlyPlayed,
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferenceKey, jsonEncode(data));
    final api = AppController.instance.backendApi;
    if (api.isAuthenticated && _profileId != 'default') {
      try {
        await api.saveAppRecord(
          recordType: 'my_tv_settings',
          recordKey: 'account_settings',
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
                  programmingRules: item.programmingRules,
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
            TvProgrammingService.eligibleForProfile(media, profile) &&
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
              ...media.studios,
              ...media.companies,
            ]) &&
            (!channel.favoritesOnly || controller.isLiked(media.id)))
        .toList();
    final sortedMedia = matchingMedia.toList()
      ..sort((a, b) {
        final aScore = TvProgrammingService.scoreMedia(a, channelFilter: channel.filterText, profile: profile) +
            _engineScore(a, channel) + _ruleScore(a, channel, DateTime.now());
        final bScore = TvProgrammingService.scoreMedia(b, channelFilter: channel.filterText, profile: profile) +
            _engineScore(b, channel) + _ruleScore(b, channel, DateTime.now());
        return bScore.compareTo(aScore);
      });
    var eligible = sortedMedia
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

    if (channel.shuffle && TvProgrammingService.activeSeason() == null) {
      // Outside seasonal windows, user shuffle remains the dominant ordering.
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

  int _engineScore(MediaItem media, _MyTvChannel channel) {
    // Channels are user-owned. The intelligence layer only helps order the
    // content that is actually inside this channel; it never creates a
    // channel or assigns media to another channel.
    final intelligence = TvChannelEngine.instance.classify(media);
    var score = 0;
    final season = TvProgrammingService.activeSeason();
    if (season != null && intelligence.holidays.contains(season)) score += 60;
    if (intelligence.audiences.contains('family') &&
        AppController.instance.currentProfile != null &&
        ['littleKids', 'kids', 'olderKids'].contains(AppController.instance.currentProfile!.governance.contentLevel.name)) {
      score += 35;
    }
    return score;
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
              const SizedBox(height: 8),
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

  Future<void> _deleteChannel(_MyTvChannel channel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${channel.name}?'),
        content: const Text(
          'This removes the channel from your account. Your library and media are not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete channel'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _channels = _channels.where((item) => item.id != channel.id).toList();
      if (_selectedChannelId == channel.id) {
        _selectedChannelId = _channels.isEmpty ? null : _channels.first.id;
      }
    });
    await _save();
  }

  int _ruleScore(MediaItem media, _MyTvChannel channel, DateTime now) {
    if (channel.programmingRules.isEmpty) return 0;
    final fields = <String>[
      media.title,
      media.description ?? '',
      media.franchiseName ?? '',
      media.franchiseType ?? '',
      ...media.genres,
      ...media.tags,
      ...media.studios,
      ...media.companies,
      ...media.relationshipTypes,
      ...media.actors,
      ...media.directors,
      ...media.writers,
    ].join(' ').toLowerCase();
    var best = 0;
    for (final rule in channel.programmingRules) {
      if (rule.months.isNotEmpty && !rule.months.contains(now.month)) continue;
      if (rule.daysOfWeek.isNotEmpty && !rule.daysOfWeek.contains(now.weekday)) continue;
      final matches = rule.terms.where(fields.contains).length;
      if (matches == 0) continue;
      best = max(best, rule.priority * matches * (rule.nightly ? 2 : 1));
    }
    return best;
  }

  Future<void> _addProgrammingRule(_MyTvChannel channel) async {
    final name = TextEditingController();
    final terms = TextEditingController();
    var nightly = false;
    final months = <int>{};
    final selected = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add programming rule'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Rule name', hintText: 'October Horror Nights')),
                TextField(
                  controller: terms,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Match your library metadata',
                    hintText: 'horror, slasher, halloween',
                    helperText: 'Matches title, themes, tags, franchise, studio, company, genre, actors, directors and writers.',
                  ),
                ),
                const SizedBox(height: 8),
                const Align(alignment: Alignment.centerLeft, child: Text('Active months')),
                Wrap(
                  spacing: 4,
                  children: List.generate(12, (index) {
                    final month = index + 1;
                    return FilterChip(
                      label: Text(month.toString()),
                      selected: months.contains(month),
                      onSelected: (value) => setDialogState(() => value ? months.add(month) : months.remove(month)),
                    );
                  }),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Program this as a nightly priority'),
                  subtitle: const Text('For example, every night in October.'),
                  value: nightly,
                  onChanged: (value) => setDialogState(() => nightly = value ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Add rule')),
          ],
        ),
      ),
    );
    final ruleName = name.text.trim();
    final ruleTerms = terms.text
        .split(RegExp(r'[,;\n]'))
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();
    name.dispose();
    terms.dispose();
    if (selected != true || ruleName.isEmpty || ruleTerms.isEmpty) return;
    final rule = TvProgrammingRule(
      id: 'tv-rule-${DateTime.now().microsecondsSinceEpoch}',
      name: ruleName,
      terms: ruleTerms,
      months: months.toList()..sort(),
      nightly: nightly,
    );
    setState(() {
      _channels = _channels.map((item) => item.id == channel.id
          ? _MyTvChannel(
              id: item.id,
              name: item.name,
              contentTypes: item.contentTypes,
              shuffle: item.shuffle,
              filterText: item.filterText,
              favoritesOnly: item.favoritesOnly,
              isFavorite: item.isFavorite,
              startTimeMinutes: item.startTimeMinutes,
              programmingRules: [...item.programmingRules, rule],
            )
          : item).toList();
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
                    if (channel != null) ...[
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
                      IconButton(
                        tooltip: 'Delete channel',
                        onPressed: () => _deleteChannel(channel),
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 18),
                  if (channel != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
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
                        ),
                        IconButton(
                          tooltip: 'Programming rules',
                          onPressed: () => _addProgrammingRule(channel),
                          icon: const Icon(Icons.auto_awesome_rounded),
                        ),
                      ],
                    ),
                    if (channel.programmingRules.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: channel.programmingRules
                            .map((rule) => Chip(
                                  avatar: Icon(rule.nightly ? Icons.nightlight_round : Icons.tune_rounded, size: 16),
                                  label: Text(rule.name),
                                ))
                            .toList(),
                      ),
                    const SizedBox(height: 10),
                  ],
                  if (schedule.isEmpty)
                    const Card(
                        child: ListTile(
                            leading: Icon(Icons.tv_off_outlined),
                            title: Text('No programs in this channel yet'),
                            subtitle: Text(
                                'Add content to this channel, or create another channel. The TV Guide is generated from this channel’s contents.')))
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

  List<Widget> _guideCards(BuildContext context) {
    final channels = _channels.toList()
      ..sort((a, b) => (b.isFavorite ? 1 : 0).compareTo(a.isFavorite ? 1 : 0));
    const slotWidth = 170.0;
    const channelWidth = 150.0;
    const headerHeight = 48.0;
    return [
      Card(
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final rows = <Widget>[];
            for (final channel in channels) {
              final entries = _schedule(channel).take(12).toList();
              rows.add(SizedBox(
                height: 94,
                child: Row(
                  children: [
                    Container(
                      width: channelWidth,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(children: [Expanded(child: Text(channel.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900))), IconButton(visualDensity: VisualDensity.compact, tooltip: channel.isFavorite ? 'Remove favorite channel' : 'Favorite channel', onPressed: () => _toggleFavorite(channel), icon: Icon(channel.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded), color: channel.isFavorite ? Colors.amber : null)]),
                          Text(channel.contentTypes.join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.white54)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: entries.isEmpty
                          ? const Center(child: Text('No matching programs', style: TextStyle(color: Colors.white54)))
                          : ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: entries.length,
                              itemBuilder: (context, index) {
                                final entry = entries[index];
                                final minutes = _durationMinutes(entry);
                                final width = (slotWidth * (minutes / 30)).clamp(slotWidth, slotWidth * 4);
                                final start = _scheduleTime(context, channel, entries, index);
                                return SizedBox(
                                  width: width,
                                  child: InkWell(
                                    onTap: () => _play(entry),
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(vertical: 7, horizontal: 3),
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        color: index == 0 ? Theme.of(context).colorScheme.primaryContainer : Colors.white.withValues(alpha: .055),
                                        border: Border.all(color: Colors.white10),
                                      ),
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text(start, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white60)),
                                        const SizedBox(height: 5),
                                        Text(entry.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                                        const SizedBox(height: 3),
                                        Text(entry.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.white54)),
                                      ]),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ));
            }
            final timelineWidth = max(constraints.maxWidth, channelWidth + slotWidth * 12);
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: timelineWidth,
                child: Column(children: [
                  SizedBox(
                    height: headerHeight,
                    child: Row(children: [
                      Container(width: channelWidth, padding: const EdgeInsets.all(12), alignment: Alignment.centerLeft, child: const Text('CHANNELS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2))),
                      for (var i = 0; i < 12; i++)
                        SizedBox(width: slotWidth, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 15), child: Text(TimeOfDay(hour: ((DateTime.now().hour * 60 + DateTime.now().minute + i * 30) ~/ 60) % 24, minute: (DateTime.now().minute + i * 30) % 60).format(context), style: const TextStyle(fontSize: 11, color: Colors.white54)))),
                    ]),
                  ),
                  ...rows,
                ]),
              ),
            );
          },
        ),
      ),
    ];
  }

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
