
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_core.dart';
import 'food_delivery.dart';
import 'music.dart';
import 'music_favorites.dart';
import 'player.dart';
import 'profile_content_safety.dart';
import 'core/services/tv_programming_service.dart';
import 'core/models/tv_channel.dart';
import 'core/services/tv_channel_engine.dart';

const _channelContentTypes = <String>['Movies', 'Shows', 'Music'];

/// Per-profile music placement rules for My TV. My TV is always commercial-free;
/// these settings only decide when personal music is scheduled around content.
class _TvMusicBreakSettings {
  final String mode; // none, per_program, every_minutes
  final int songsPerProgram;
  final int intervalMinutes;
  final String placement; // before, after, before_after, between, throughout
  final bool naturalBreaksOnly;
  final bool avoidRecentTracks;
  final String source; // all or favorites
  final String musicFilter; // artist, genre, album, title, etc.

  const _TvMusicBreakSettings({
    this.mode = 'none',
    this.songsPerProgram = 1,
    this.intervalMinutes = 30,
    this.placement = 'between',
    this.naturalBreaksOnly = true,
    this.avoidRecentTracks = true,
    this.source = 'all',
    this.musicFilter = '',
  });

  factory _TvMusicBreakSettings.fromJson(Map<String, dynamic> json) =>
      _TvMusicBreakSettings(
        mode: json['mode']?.toString() ?? 'none',
        songsPerProgram: (((json['songsPerProgram'] as num?)?.toInt() ?? 1).clamp(1, 10)).toInt(),
        intervalMinutes: (((json['intervalMinutes'] as num?)?.toInt() ?? 30).clamp(5, 180)).toInt(),
        placement: json['placement']?.toString() ?? 'between',
        naturalBreaksOnly: json['naturalBreaksOnly'] != false,
        avoidRecentTracks: json['avoidRecentTracks'] != false,
        source: json['source']?.toString() == 'favorites' ? 'favorites' : 'all',
        musicFilter: json['musicFilter']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'mode': mode,
        'songsPerProgram': songsPerProgram,
        'intervalMinutes': intervalMinutes,
        'placement': placement,
        'naturalBreaksOnly': naturalBreaksOnly,
        'avoidRecentTracks': avoidRecentTracks,
        'source': source,
        'musicFilter': musicFilter,
      };
}

class _MyTvChannel {
  final String id;
  final String name;
  final List<String> contentTypes;
  final bool shuffle;
  final String filterText;
  final List<String> metadataFilters;
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
    this.metadataFilters = const [],
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
        metadataFilters: json['metadataFilters'] is List
            ? (json['metadataFilters'] as List)
                .map((value) => value.toString().trim())
                .where((value) => value.isNotEmpty)
                .toList(growable: false)
            : const [],
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
        'metadataFilters': metadataFilters,
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
  _TvMusicBreakSettings _musicBreaks = const _TvMusicBreakSettings();
  Map<String, dynamic> _musicBreakSettingsByProfile = <String, dynamic>{};

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
    final rawMusicBreakProfiles = data?['musicBreakSettingsByProfile'];
    final musicBreakProfiles = <String, dynamic>{};
    if (rawMusicBreakProfiles is Map) {
      for (final entry in rawMusicBreakProfiles.entries) {
        if (entry.value is Map) {
          musicBreakProfiles[entry.key.toString()] =
              Map<String, dynamic>.from(entry.value as Map);
        }
      }
    }
    final profileMusicJson = musicBreakProfiles[_profileId];
    final legacyMusicJson = data?['musicBreakSettings'];
    final selectedMusicJson = profileMusicJson is Map
        ? profileMusicJson
        : legacyMusicJson is Map
            ? legacyMusicJson
            : null;
    final musicBreaks = selectedMusicJson != null
        ? _TvMusicBreakSettings.fromJson(
            Map<String, dynamic>.from(selectedMusicJson),
          )
        : const _TvMusicBreakSettings();
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
      _musicBreaks = musicBreaks;
      _musicBreakSettingsByProfile = musicBreakProfiles;
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
    final profileSettings = <String, dynamic>{
      ..._musicBreakSettingsByProfile,
    };
    profileSettings[_profileId] = _musicBreaks.toJson();
    _musicBreakSettingsByProfile = profileSettings;
    final data = <String, dynamic>{
      'channels': _channels.map((channel) => channel.toJson()).toList(),
      'channelsInitialized': true,
      'recentlyPlayed': _recentlyPlayed,
      'musicBreakSettingsByProfile': profileSettings,
      // Keep this legacy field synchronized for older clients.
      'musicBreakSettings': _musicBreaks.toJson(),
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
                  metadataFilters: item.metadataFilters,
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
    final terms = <String>[
      ...channel.filterText
          .split(RegExp(r'[,;\n]'))
          .map((term) => term.trim().toLowerCase())
          .where((term) => term.isNotEmpty),
      ...channel.metadataFilters
          .map((term) => term.trim().toLowerCase())
          .where((term) => term.isNotEmpty),
    ];
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
    var videos = sortedMedia
        .where((media) => _channelAcceptsVideoType(channel, media.type))
        .map(_ChannelEntry.media)
        .toList();

    final likedTracks = MusicFavoritesBridge.likedTracks();
    final musicTerms = _musicBreaks.musicFilter
        .split(RegExp(r'[,;\n]'))
        .map((term) => term.trim().toLowerCase())
        .where((term) => term.isNotEmpty)
        .toList();
    var music = MusicLibraryStore.instance.tracks.where((track) {
      if (!channel.contentTypes.contains('Music') ||
          track.audioUrl?.trim().isNotEmpty != true ||
          (profileBlocksExplicitMusic(profile) && track.explicit) ||
          (profileBlocksMatureMusic(profile) && track.matureTheme) ||
          (_musicBreaks.source == 'favorites' && !likedTracks.contains(track.id)) ||
          (channel.favoritesOnly && !likedTracks.contains(track.id))) {
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
      final musicPreferenceMatches = musicTerms.isEmpty ||
          musicTerms.any((term) => [
                track.title,
                track.artist,
                track.album,
                ...track.featuredArtists,
                ...track.genres,
                ...track.subgenres,
              ].join(' ').toLowerCase().contains(term));
      final soundtrackMatches = terms.isNotEmpty &&
          trackTitle.isNotEmpty &&
          matchingMedia.any((media) => media.music.any(
                (song) => song.toLowerCase().contains(trackTitle),
              ));
      return musicPreferenceMatches && (terms.isEmpty || trackMatches || soundtrackMatches);
    }).toList();

    final recent = _recentlyPlayed[channel.id] ?? const <String>[];
    if (_musicBreaks.avoidRecentTracks) {
      final unseen = music.where((track) =>
          !recent.take(8).contains('music:${track.id}')).toList();
      if (unseen.isNotEmpty) music = unseen;
    }

    if (videos.isEmpty && music.isEmpty) return const [];

    if (channel.shuffle && TvProgrammingService.activeSeason() == null) {
      videos.shuffle(Random(channel.id.hashCode));
      music.shuffle(Random('${channel.id}:music'.hashCode));
    }

    // With music breaks disabled, retain the original My TV behavior: music is
    // simply another channel entry. Once enabled, music becomes intentional
    // programming around the movies/episodes instead of a commercial block.
    if (_musicBreaks.mode == 'none') {
      final entries = <_ChannelEntry>[...videos, ...music.map(_ChannelEntry.track)];
      return entries.take(24).toList(growable: false);
    }

    final musicEntries = music.map(_ChannelEntry.track).toList();
    return _insertMusicBreaks(videos, musicEntries).take(24).toList(growable: false);
  }

  List<_ChannelEntry> _insertMusicBreaks(
    List<_ChannelEntry> videos,
    List<_ChannelEntry> music,
  ) {
    if (music.isEmpty) return List<_ChannelEntry>.from(videos);
    if (videos.isEmpty) return music.take(24).toList();

    var musicIndex = 0;
    _ChannelEntry nextMusic() {
      final entry = music[musicIndex % music.length];
      musicIndex++;
      return entry;
    }

    final result = <_ChannelEntry>[];
    final songs = _musicBreaks.songsPerProgram.clamp(1, 10).toInt();

    void addSongs(int count) {
      for (var i = 0; i < count; i++) {
        result.add(nextMusic());
      }
    }

    if (_musicBreaks.mode == 'per_program') {
      switch (_musicBreaks.placement) {
        case 'before':
          for (final video in videos) {
            addSongs(songs);
            result.add(video);
          }
          break;
        case 'after':
          for (final video in videos) {
            result.add(video);
            addSongs(songs);
          }
          break;
        case 'before_after':
          for (final video in videos) {
            addSongs((songs + 1) ~/ 2);
            result.add(video);
            addSongs(songs ~/ 2);
          }
          break;
        case 'between':
        case 'throughout':
          for (var i = 0; i < videos.length; i++) {
            result.add(videos[i]);
            if (i < videos.length - 1) addSongs(songs);
          }
          break;
        default:
          result.addAll(videos);
      }
      return result;
    }

    // every_minutes / throughout: use the same estimated runtimes as the guide,
    // but only place songs between completed programs. This keeps music from
    // interrupting a movie or episode in the middle of playback.
    var elapsed = 0;
    if (_musicBreaks.placement == 'before' ||
        _musicBreaks.placement == 'before_after') {
      addSongs(songs);
    }
    for (var i = 0; i < videos.length; i++) {
      final video = videos[i];
      result.add(video);
      elapsed += _durationMinutes(video);
      if (elapsed >= _musicBreaks.intervalMinutes && i < videos.length - 1) {
        addSongs(songs);
        elapsed = 0;
      }
    }
    if (_musicBreaks.placement == 'after' ||
        _musicBreaks.placement == 'before_after') {
      addSongs(songs);
    }
    return result;
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

  Map<String, List<String>> _availableMetadataChoices() {
    final values = <String, Set<String>>{
      'Genres': <String>{},
      'Tags': <String>{},
      'Studios': <String>{},
      'Franchises': <String>{},
      'People': <String>{},
    };
    for (final media in AppController.instance.library) {
      values['Genres']!.addAll(media.genres);
      values['Tags']!.addAll(media.tags);
      values['Studios']!.addAll(media.studios);
      if ((media.franchiseName ?? '').trim().isNotEmpty) {
        values['Franchises']!.add(media.franchiseName!.trim());
      }
      values['People']!..addAll(media.actors)..addAll(media.directors)..addAll(media.writers);
    }
    return values.map(
      (key, set) => MapEntry(
        key,
        set
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())),
      ),
    );
  }

  Future<void> _addChannel() async {
    final name = TextEditingController();
    final filterText = TextEditingController();
    final selectedTypes = _channelContentTypes.toSet();
    final selectedMetadata = <String>{};
    var favoritesOnly = false;
    final metadataChoices = _availableMetadataChoices();
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
              const SizedBox(height: 14),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Channel metadata',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 4),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Choose genres, tags, studios, franchises, or people from this profile's library.",
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ),
              const SizedBox(height: 10),
              for (final metadataEntry in metadataChoices.entries) ...[
                if (metadataEntry.value.isNotEmpty) ...[
                  Text(
                    metadataEntry.key,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: metadataEntry.value.take(36).map((value) {
                      return FilterChip(
                        label: Text(value),
                        selected: selectedMetadata.contains(value),
                        onSelected: (selected) => setDialogState(() {
                          if (selected) {
                            selectedMetadata.add(value);
                          } else {
                            selectedMetadata.remove(value);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
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
      metadataFilters: selectedMetadata.toList(growable: false),
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

  Future<void> _openMusicBreakSettings() async {
    var mode = _musicBreaks.mode;
    var songs = _musicBreaks.songsPerProgram;
    var interval = _musicBreaks.intervalMinutes;
    var placement = _musicBreaks.placement;
    var natural = _musicBreaks.naturalBreaksOnly;
    var avoidRecent = _musicBreaks.avoidRecentTracks;
    var source = _musicBreaks.source;
    final musicFilterController = TextEditingController(text: _musicBreaks.musicFilter);
    var musicFilter = _musicBreaks.musicFilter;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('My TV Music'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My TV never inserts commercial breaks. These settings belong to ${AppController.instance.currentProfile?.name ?? 'this profile'} and add your music as intentional programming around your movies and episodes.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: mode,
                    decoration: const InputDecoration(labelText: 'Music schedule'),
                    items: const [
                      DropdownMenuItem(value: 'none', child: Text('No music breaks')),
                      DropdownMenuItem(value: 'per_program', child: Text('X songs per movie / episode')),
                      DropdownMenuItem(value: 'every_minutes', child: Text('X songs every Y minutes')),
                    ],
                    onChanged: (value) => setDialogState(() => mode = value ?? 'none'),
                  ),
                  if (mode != 'none') ...[
                    const SizedBox(height: 12),
                    if (mode == 'per_program')
                      DropdownButtonFormField<int>(
                        initialValue: songs,
                        decoration: const InputDecoration(labelText: 'Songs per movie / episode'),
                        items: [
                          for (var value = 1; value <= 10; value++)
                            DropdownMenuItem(value: value, child: Text('$value ${value == 1 ? 'song' : 'songs'}')),
                        ],
                        onChanged: (value) => setDialogState(() => songs = value ?? 1),
                      ),
                    if (mode == 'every_minutes') ...[
                      DropdownButtonFormField<int>(
                        initialValue: songs,
                        decoration: const InputDecoration(labelText: 'Songs each time'),
                        items: [
                          for (var value = 1; value <= 10; value++)
                            DropdownMenuItem(value: value, child: Text('$value ${value == 1 ? 'song' : 'songs'}')),
                        ],
                        onChanged: (value) => setDialogState(() => songs = value ?? 1),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: interval,
                        decoration: const InputDecoration(labelText: 'Every'),
                        items: [
                          for (final value in [5, 10, 15, 20, 30, 45, 60, 90, 120])
                            DropdownMenuItem(value: value, child: Text('$value minutes')),
                        ],
                        onChanged: (value) => setDialogState(() => interval = value ?? 30),
                      ),
                    ],
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: source,
                      decoration: const InputDecoration(labelText: 'Music source'),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All music available to this profile')),
                        DropdownMenuItem(value: 'favorites', child: Text('Favorite songs')),
                      ],
                      onChanged: (value) => setDialogState(() => source = value ?? 'all'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: musicFilterController,
                      onChanged: (value) => musicFilter = value,
                      decoration: const InputDecoration(
                        labelText: 'Music preference',
                        hintText: 'Artist, genre, album, title, or subgenre',
                        helperText: 'Separate multiple preferences with commas or new lines.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: placement,
                      decoration: const InputDecoration(labelText: 'Place music'),
                      items: const [
                        DropdownMenuItem(value: 'before', child: Text('Before the episode / movie')),
                        DropdownMenuItem(value: 'after', child: Text('After the episode / movie')),
                        DropdownMenuItem(value: 'before_after', child: Text('Before and after')),
                        DropdownMenuItem(value: 'between', child: Text('Between episodes / movies')),
                        DropdownMenuItem(value: 'throughout', child: Text('Throughout the scheduled programming')),
                      ],
                      onChanged: (value) => setDialogState(() => placement = value ?? 'between'),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Prefer natural break points'),
                      subtitle: const Text('Keep music between programs instead of pretending there are commercial breaks.'),
                      value: natural,
                      onChanged: (value) => setDialogState(() => natural = value),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Avoid recently played songs'),
                      value: avoidRecent,
                      onChanged: (value) => setDialogState(() => avoidRecent = value),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save music settings')),
          ],
        ),
      ),
    );
    if (saved != true) {
      musicFilterController.dispose();
      return;
    }
    musicFilterController.dispose();
    setState(() {
      _musicBreaks = _TvMusicBreakSettings(
        mode: mode,
        songsPerProgram: songs,
        intervalMinutes: interval,
        placement: placement,
        naturalBreaksOnly: natural,
        avoidRecentTracks: avoidRecent,
        source: source,
        musicFilter: musicFilter.trim(),
      );
    });
    await _save();
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
              metadataFilters: item.metadataFilters,
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
    final schedule = channel == null ? const <_ChannelEntry>[] : _schedule(channel);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My TV'),
        actions: [
          IconButton(
            onPressed: _loading ? null : () => setState(() => _showGuide = !_showGuide),
            tooltip: 'TV Guide',
            icon: Icon(
              _showGuide ? Icons.live_tv_rounded : Icons.calendar_view_week_rounded,
            ),
          ),
          IconButton(
            onPressed: _loading ? null : _openMusicBreakSettings,
            tooltip: 'Music breaks',
            icon: const Icon(Icons.music_note_rounded),
          ),
          IconButton(
            onPressed: _loading
                ? null
                : () => Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => FoodOrderingScreen(
                          viewingContext: channel?.name ?? 'My TV viewing',
                        ),
                      ),
                    ),
            tooltip: 'Order food',
            icon: const Icon(Icons.delivery_dining_rounded),
          ),
          IconButton(
            onPressed: _loading ? null : _addChannel,
            tooltip: 'Create channel',
            icon: const Icon(Icons.add),
          ),
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
                  _showGuide ? 'TV Guide' : 'Your library, programmed as a channel',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  _showGuide
                      ? 'Today’s channel schedules · no commercial ads'
                      : 'Personal programming uses media available to this profile. No commercial ads are inserted.',
                  style: const TextStyle(color: Colors.white60),
                ),
                if (!_showGuide && _musicBreaks.mode != 'none')
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _musicBreakSummary(),
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
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
                if (!_showGuide && channel != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedChannelId,
                          items: _channels
                              .map(
                                (item) => DropdownMenuItem<String>(
                                  value: item.id,
                                  child: Text(item.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setState(() => _selectedChannelId = value),
                          decoration: const InputDecoration(labelText: 'Channel'),
                        ),
                      ),
                      IconButton(
                        tooltip: channel.isFavorite
                            ? 'Remove favorite channel'
                            : 'Favorite channel',
                        onPressed: () => _toggleFavorite(channel),
                        icon: Icon(
                          channel.isFavorite
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                        ),
                        color: channel.isFavorite ? Colors.amber : null,
                      ),
                      IconButton(
                        tooltip: 'Delete channel',
                        onPressed: () => _deleteChannel(channel),
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
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
                  if (channel.metadataFilters.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: channel.metadataFilters
                          .map((value) => Chip(
                                avatar: const Icon(Icons.sell_outlined, size: 15),
                                label: Text(value),
                              ))
                          .toList(),
                    ),
                  ],
                  if (channel.programmingRules.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: channel.programmingRules
                          .map(
                            (rule) => Chip(
                              avatar: Icon(
                                rule.nightly
                                    ? Icons.nightlight_round
                                    : Icons.tune_rounded,
                                size: 16,
                              ),
                              label: Text(rule.name),
                            ),
                          )
                          .toList(),
                    ),
                  const SizedBox(height: 10),
                  if (schedule.isEmpty)
                    const Card(
                      child: ListTile(
                        leading: Icon(Icons.tv_off_outlined),
                        title: Text('No programs in this channel yet'),
                        subtitle: Text(
                          'Add content to this channel, or create another channel. The TV Guide is generated from this channel’s contents.',
                        ),
                      ),
                    )
                  else ...[
                    _scheduleCard(
                      context,
                      '${_scheduleTime(context, channel, schedule, 0)} · Now',
                      schedule.first,
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
                    Text(
                      '${channel.name} · ${schedule.length} items queued',
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ],
                ] else if (!_showGuide && _channels.isEmpty)
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.tv_off_outlined),
                      title: Text('No channels'),
                      subtitle: Text('Create a channel to build your TV Guide.'),
                    ),
                  ),
              ],
            ),
    );
  }

  String _musicBreakSummary() {
    if (_musicBreaks.mode == 'per_program') {
      final placement = switch (_musicBreaks.placement) {
        'before' => 'before each program',
        'after' => 'after each program',
        'before_after' => 'before and after each program',
        'throughout' => 'throughout each program',
        _ => 'between programs',
      };
      return 'Music: ${_musicBreaks.songsPerProgram} ${_musicBreaks.songsPerProgram == 1 ? 'song' : 'songs'} $placement · no commercials.';
    }
    if (_musicBreaks.mode == 'every_minutes') {
      return 'Music: ${_musicBreaks.songsPerProgram} ${_musicBreaks.songsPerProgram == 1 ? 'song' : 'songs'} every ${_musicBreaks.intervalMinutes} minutes · no commercials.';
    }
    return 'Music breaks are off · no commercials.';
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
