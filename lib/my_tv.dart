import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'backend_api.dart';
import 'app_core.dart';
import 'entertainment_extensions.dart';
import 'food_delivery.dart';
import 'music.dart';
import 'music_favorites.dart';
import 'player.dart';
import 'profile_content_safety.dart';
import 'core/services/tv_programming_service.dart';
import 'core/models/tv_channel.dart';
import 'core/services/tv_channel_engine.dart';
import 'localization.dart';
import 'page_customization_button.dart';
import 'public_live_tv.dart';

const _channelContentTypes = <String>['Movies', 'Shows', 'Music'];

/// Stable across process restarts. Dart's general-purpose hashCode is not a
/// persisted identifier, so schedule randomization must not seed from it.
int _stableChannelSeed(String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
  }
  return hash;
}

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
        songsPerProgram:
            (((json['songsPerProgram'] as num?)?.toInt() ?? 1).clamp(1, 10))
                .toInt(),
        intervalMinutes:
            (((json['intervalMinutes'] as num?)?.toInt() ?? 30).clamp(5, 180))
                .toInt(),
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
                .map((e) =>
                    TvProgrammingRule.fromJson(Map<String, dynamic>.from(e)))
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
        'programmingRules':
            programmingRules.map((rule) => rule.toJson()).toList(),
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

/// One program occupying a real wall-clock interval in a My TV channel.
class _ScheduledProgram {
  final _ChannelEntry entry;
  final DateTime start;
  final DateTime end;

  const _ScheduledProgram({
    required this.entry,
    required this.start,
    required this.end,
  });

  Duration get duration => end.difference(start);

  bool isOnAirAt(DateTime time) =>
      !time.isBefore(start) && time.isBefore(end);

  double progressAt(DateTime time) {
    final total = duration.inMilliseconds;
    if (total <= 0) return 0;
    return (time.difference(start).inMilliseconds / total)
        .clamp(0.0, 0.999)
        .toDouble();
  }

  int elapsedSecondsAt(DateTime time) => time
      .difference(start)
      .inSeconds
      .clamp(0, duration.inSeconds > 0 ? duration.inSeconds - 1 : 0)
      .toInt();

  Duration remainingAt(DateTime time) {
    final remaining = end.difference(time);
    return remaining.isNegative ? Duration.zero : remaining;
  }
}

/// Personal, ad-free channel generated only from media accessible to the
/// selected profile. Schedules are local programming plans, not broadcasts.
class MyTvScreen extends StatefulWidget {
  final bool showAppBar;

  const MyTvScreen({super.key, this.showAppBar = true});

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
  Set<String> _programReminders = <String>{};
  Timer? _clockTimer;

  String get _profileId =>
      AppController.instance.currentProfile?.id ?? 'default';
  String get _accountId => AppController.instance.currentAccount?.id ?? 'local';
  String get _preferenceKey => 'my_tv_settings_account_$_accountId';
  String get _reminderPreferenceKey => 'my_tv_program_reminders_v1_$_profileId';

  @override
  void initState() {
    super.initState();
    _load();
    // Keep the ON AIR progress bar, countdown, and red EPG marker in sync.
    _clockTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
      unawaited(_checkProgramReminders());
    });
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
          if (record['recordKey'] == 'account_settings' &&
              record['data'] is Map) {
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
    final reminders = (prefs.getStringList(_reminderPreferenceKey) ?? const <String>[])
        .where((value) => value.trim().isNotEmpty)
        .toSet();
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
      _programReminders = reminders;
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
              content: UniversalText(
                  'Saved on this device. Server sync will retry later.'),
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

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  DateTime _channelDayStart(_MyTvChannel channel, DateTime now) => DateTime(
        now.year,
        now.month,
        now.day,
        channel.startTimeMinutes ~/ 60,
        channel.startTimeMinutes % 60,
      );

  /// Builds the channel's rolling EPG from its daily start time. Programs keep
  /// their actual scheduled positions; when the viewer tunes in late, the
  /// current program is found by wall-clock time instead of list index.
  List<_ScheduledProgram> _scheduledTimeline(
    _MyTvChannel channel,
    List<_ChannelEntry> entries,
    DateTime now, {
    int futureHours = 8,
  }) {
    if (entries.isEmpty) return const <_ScheduledProgram>[];
    final todayStart = _channelDayStart(channel, now);
    final anchor = now.isBefore(todayStart)
        ? todayStart.subtract(const Duration(days: 1))
        : todayStart;
    final durations = entries
        .map((entry) => Duration(minutes: _durationMinutes(entry) > 0 ? _durationMinutes(entry) : 1))
        .toList(growable: false);
    final cycleSeconds = durations.fold<int>(
        0, (total, duration) => total + duration.inSeconds);
    if (cycleSeconds <= 0) return const <_ScheduledProgram>[];

    // Resolve the exact slot containing the wall-clock time without iterating
    // through every program since the channel opened. The cycle restarts at
    // the channel's configured daily start time.
    var offset = now.difference(anchor).inSeconds % cycleSeconds;
    var currentIndex = 0;
    while (currentIndex < durations.length - 1 &&
        offset >= durations[currentIndex].inSeconds) {
      offset -= durations[currentIndex].inSeconds;
      currentIndex++;
    }
    final currentStart = now.subtract(Duration(seconds: offset));
    final horizon = now.add(Duration(hours: futureHours));
    final result = <_ScheduledProgram>[];

    // Keep enough preceding slots to show what was already in progress when
    // the guide's left edge begins 30 minutes before the current time.
    var pastCursor = currentStart;
    var pastIndex = (currentIndex - 1 + entries.length) % entries.length;
    final historyStart = now.subtract(const Duration(minutes: 120));
    var pastGuard = 0;
    while (pastCursor.isAfter(historyStart) && pastGuard < 200) {
      final previousStart = pastCursor.subtract(durations[pastIndex]);
      result.insert(0, _ScheduledProgram(
        entry: entries[pastIndex],
        start: previousStart,
        end: pastCursor,
      ));
      pastCursor = previousStart;
      pastIndex = (pastIndex - 1 + entries.length) % entries.length;
      pastGuard++;
    }

    var cursor = currentStart;
    var index = currentIndex;
    var futureGuard = 0;
    while (cursor.isBefore(horizon) && futureGuard < 1000) {
      final end = cursor.add(durations[index]);
      result.add(_ScheduledProgram(entry: entries[index], start: cursor, end: end));
      cursor = end;
      index = (index + 1) % entries.length;
      futureGuard++;
    }
    return result;
  }

  String _clockTime(BuildContext context, DateTime value) =>
      TimeOfDay.fromDateTime(value).format(context);

  String _remainingText(Duration duration) {
    if (duration.inSeconds > 0 && duration.inSeconds < 60) {
      return 'Under 1 min left';
    }
    final minutes = duration.inMinutes < 0 ? 0 : duration.inMinutes;
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (hours == 0) return '$remainingMinutes min left';
    if (remainingMinutes == 0) return '$hours h left';
    return '$hours h $remainingMinutes min left';
  }

  int? _durationFromMetadata(dynamic node) {
    if (node is Map) {
      for (final entry in node.entries) {
        final key = entry.key.toString().toLowerCase().replaceAll('_', '');
        if (key.contains('runtime') || key.contains('duration')) {
          final raw = entry.value;
          final value = raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '');
          if (value != null && value > 0) {
            // Catalog episode durations are usually minutes; large values for
            // duration fields are interpreted as seconds.
            final minutes = key.contains('millis') || key.endsWith('ms')
                ? (value / 60000).ceil()
                : (key.contains('seconds') ||
                        key.contains('secs') ||
                        (key.contains('duration') && value > 300))
                    ? (value / 60).ceil()
                    : value.ceil();
            if (minutes > 0 && minutes <= 600) return minutes;
          }
        }
      }
      for (final value in node.values) {
        final found = _durationFromMetadata(value);
        if (found != null) return found;
      }
    } else if (node is Iterable) {
      for (final value in node) {
        final found = _durationFromMetadata(value);
        if (found != null) return found;
      }
    }
    return null;
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
        final aScore = TvProgrammingService.scoreMedia(a,
                channelFilter: channel.filterText, profile: profile) +
            _engineScore(a, channel) +
            _ruleScore(a, channel, DateTime.now());
        final bScore = TvProgrammingService.scoreMedia(b,
                channelFilter: channel.filterText, profile: profile) +
            _engineScore(b, channel) +
            _ruleScore(b, channel, DateTime.now());
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
          (_musicBreaks.source == 'favorites' &&
              !likedTracks.contains(track.id)) ||
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
      return musicPreferenceMatches &&
          (terms.isEmpty || trackMatches || soundtrackMatches);
    }).toList();

    final recent = _recentlyPlayed[channel.id] ?? const <String>[];
    if (_musicBreaks.avoidRecentTracks) {
      final unseen = music
          .where((track) => !recent.take(8).contains('music:${track.id}'))
          .toList();
      if (unseen.isNotEmpty) music = unseen;
    }

    if (videos.isEmpty && music.isEmpty) return const [];

    if (channel.shuffle && TvProgrammingService.activeSeason() == null) {
      videos.shuffle(Random(_stableChannelSeed(channel.id)));
      music.shuffle(Random(_stableChannelSeed('${channel.id}:music')));
    }

    // With music breaks disabled, retain the original My TV behavior: music is
    // simply another channel entry. Once enabled, music becomes intentional
    // programming around the movies/episodes instead of a commercial block.
    if (_musicBreaks.mode == 'none') {
      final entries = <_ChannelEntry>[
        ...videos,
        ...music.map(_ChannelEntry.track)
      ];
      return entries.take(24).toList(growable: false);
    }

    final musicEntries = music.map(_ChannelEntry.track).toList();
    return _insertMusicBreaks(videos, musicEntries)
        .take(24)
        .toList(growable: false);
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
        ['littleKids', 'kids', 'olderKids'].contains(AppController
            .instance.currentProfile!.governance.contentLevel.name)) {
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
    final media = entry.media;
    if (media != null) {
      final metadataDuration = _durationFromMetadata(media.seasons);
      if (metadataDuration != null) return metadataDuration;
    }
    final type = entry.media?.type.toLowerCase() ?? '';
    final isEpisode = type.contains('tv') ||
        type.contains('show') ||
        type.contains('series') ||
        type.contains('episode');
    // Used only when the catalog has no runtime metadata.
    return isEpisode ? 30 : 120;
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
      values['People']!
        ..addAll(media.actors)
        ..addAll(media.directors)
        ..addAll(media.writers);
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

  Future<void> _addChannelPreset({
    required String name,
    required List<String> contentTypes,
    String filterText = '',
    bool favoritesOnly = false,
  }) async {
    final existing = _channels
        .where((channel) => channel.name.toLowerCase() == name.toLowerCase())
        .toList();
    if (existing.isNotEmpty) {
      setState(() => _selectedChannelId = existing.first.id);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opened your "$name" channel.')));
      return;
    }
    final channel = _MyTvChannel(
      id: 'my_tv_preset_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      contentTypes: contentTypes,
      filterText: filterText,
      favoritesOnly: favoritesOnly,
      startTimeMinutes: 7 * 60,
      shuffle: name != 'Seasonal Spotlight',
    );
    setState(() {
      _channels = [..._channels, channel];
      _selectedChannelId = channel.id;
      _showGuide = false;
    });
    await _save();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text('Created "$name" from your profile-accessible library.')));
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
          title: const UniversalText('Create a channel'),
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
                    child: UniversalText('Include in channel'),
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
                child: UniversalText(
                  'Channel metadata',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 4),
              const Align(
                alignment: Alignment.centerLeft,
                child: UniversalText(
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
                title: const UniversalText('Only include liked items'),
                value: favoritesOnly,
                onChanged: (value) =>
                    setDialogState(() => favoritesOnly = value ?? false),
              ),
              const UniversalText(
                  'Channels use media available to this profile. Music can also match soundtrack titles linked to matching movies or shows in your library.'),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const UniversalText('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const UniversalText('Create')),
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
        content: const UniversalText(
          'This removes the channel from your account. Your library and media are not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const UniversalText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const UniversalText('Delete channel'),
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
      if (rule.daysOfWeek.isNotEmpty && !rule.daysOfWeek.contains(now.weekday)) {
        continue;
      }
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
    final musicFilterController =
        TextEditingController(text: _musicBreaks.musicFilter);
    var musicFilter = _musicBreaks.musicFilter;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const UniversalText('My TV Music'),
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
                    decoration:
                        const InputDecoration(labelText: 'Music schedule'),
                    items: const [
                      DropdownMenuItem(
                          value: 'none',
                          child: UniversalText('No music breaks')),
                      DropdownMenuItem(
                          value: 'per_program',
                          child: UniversalText('X songs per movie / episode')),
                      DropdownMenuItem(
                          value: 'every_minutes',
                          child: UniversalText('X songs every Y minutes')),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => mode = value ?? 'none'),
                  ),
                  if (mode != 'none') ...[
                    const SizedBox(height: 12),
                    if (mode == 'per_program')
                      DropdownButtonFormField<int>(
                        initialValue: songs,
                        decoration: const InputDecoration(
                            labelText: 'Songs per movie / episode'),
                        items: [
                          for (var value = 1; value <= 10; value++)
                            DropdownMenuItem(
                                value: value,
                                child: Text(
                                    '$value ${value == 1 ? 'song' : 'songs'}')),
                        ],
                        onChanged: (value) =>
                            setDialogState(() => songs = value ?? 1),
                      ),
                    if (mode == 'every_minutes') ...[
                      DropdownButtonFormField<int>(
                        initialValue: songs,
                        decoration:
                            const InputDecoration(labelText: 'Songs each time'),
                        items: [
                          for (var value = 1; value <= 10; value++)
                            DropdownMenuItem(
                                value: value,
                                child: Text(
                                    '$value ${value == 1 ? 'song' : 'songs'}')),
                        ],
                        onChanged: (value) =>
                            setDialogState(() => songs = value ?? 1),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: interval,
                        decoration: const InputDecoration(labelText: 'Every'),
                        items: [
                          for (final value in [
                            5,
                            10,
                            15,
                            20,
                            30,
                            45,
                            60,
                            90,
                            120
                          ])
                            DropdownMenuItem(
                                value: value, child: Text('$value minutes')),
                        ],
                        onChanged: (value) =>
                            setDialogState(() => interval = value ?? 30),
                      ),
                    ],
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: source,
                      decoration:
                          const InputDecoration(labelText: 'Music source'),
                      items: const [
                        DropdownMenuItem(
                            value: 'all',
                            child: UniversalText(
                                'All music available to this profile')),
                        DropdownMenuItem(
                            value: 'favorites',
                            child: UniversalText('Favorite songs')),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => source = value ?? 'all'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: musicFilterController,
                      onChanged: (value) => musicFilter = value,
                      decoration: const InputDecoration(
                        labelText: 'Music preference',
                        hintText: 'Artist, genre, album, title, or subgenre',
                        helperText:
                            'Separate multiple preferences with commas or new lines.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: placement,
                      decoration:
                          const InputDecoration(labelText: 'Place music'),
                      items: const [
                        DropdownMenuItem(
                            value: 'before',
                            child: UniversalText('Before the episode / movie')),
                        DropdownMenuItem(
                            value: 'after',
                            child: UniversalText('After the episode / movie')),
                        DropdownMenuItem(
                            value: 'before_after',
                            child: UniversalText('Before and after')),
                        DropdownMenuItem(
                            value: 'between',
                            child: UniversalText('Between episodes / movies')),
                        DropdownMenuItem(
                            value: 'throughout',
                            child: UniversalText(
                                'Throughout the scheduled programming')),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => placement = value ?? 'between'),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const UniversalText('Prefer natural break points'),
                      subtitle: const UniversalText(
                          'Keep music between programs instead of pretending there are commercial breaks.'),
                      value: natural,
                      onChanged: (value) =>
                          setDialogState(() => natural = value),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const UniversalText('Avoid recently played songs'),
                      value: avoidRecent,
                      onChanged: (value) =>
                          setDialogState(() => avoidRecent = value),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const UniversalText('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const UniversalText('Save music settings')),
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
          title: const UniversalText('Add programming rule'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: name,
                    decoration: const InputDecoration(
                        labelText: 'Rule name',
                        hintText: 'October Horror Nights')),
                TextField(
                  controller: terms,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Match your library metadata',
                    hintText: 'horror, slasher, halloween',
                    helperText:
                        'Matches title, themes, tags, franchise, studio, company, genre, actors, directors and writers.',
                  ),
                ),
                const SizedBox(height: 8),
                const Align(
                    alignment: Alignment.centerLeft,
                    child: UniversalText('Active months')),
                Wrap(
                  spacing: 4,
                  children: List.generate(12, (index) {
                    final month = index + 1;
                    return FilterChip(
                      label: Text(month.toString()),
                      selected: months.contains(month),
                      onSelected: (value) => setDialogState(() =>
                          value ? months.add(month) : months.remove(month)),
                    );
                  }),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title:
                      const UniversalText('Program this as a nightly priority'),
                  subtitle: const UniversalText(
                      'For example, every night in October.'),
                  value: nightly,
                  onChanged: (value) =>
                      setDialogState(() => nightly = value ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const UniversalText('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const UniversalText('Add rule')),
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
                  isFavorite: item.isFavorite,
                  startTimeMinutes: item.startTimeMinutes,
                  programmingRules: [...item.programmingRules, rule],
                )
              : item)
          .toList();
    });
    await _save();
  }

  Future<void> _play(
    _ChannelEntry entry, {
    String? channelId,
    int? initialPositionSeconds,
  }) async {
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
      final matchedChannels = _channels.where((item) => item.id == targetChannelId);
      final selectedChannelName = matchedChannels.isEmpty ? 'TV' : matchedChannels.first.name;
      Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: '/app/player'),
          builder: (_) => PlayerScreen(
            media: entry.media!,
            initialPositionSeconds: initialPositionSeconds,
            activityLabel:
                "Watching TV channel $selectedChannelName: ${entry.media!.title}",
          ),
        ),
      );
    }
  }

  Future<void> _tuneChannel(_MyTvChannel channel) async {
    setState(() => _selectedChannelId = channel.id);
    final now = DateTime.now();
    final entries = _schedule(channel);
    final timeline = _scheduledTimeline(channel, entries, now, futureHours: 8);
    for (final program in timeline) {
      if (program.isOnAirAt(now)) {
        await _playScheduledProgram(program, channel, now);
        return;
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No current program is available on ${channel.name}.')),
      );
    }
  }

  Future<void> _playScheduledProgram(
    _ScheduledProgram program,
    _MyTvChannel channel,
    DateTime now,
  ) async {
    if (now.isBefore(program.start)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          '${program.entry.title} is scheduled for ${_clockTime(context, program.start)}. Tune in when it starts.',
        ),
      ));
      return;
    }
    if (!program.isOnAirAt(now)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          '${program.entry.title} finished at ${_clockTime(context, program.end)}. It is not being recorded by this channel.',
        ),
      ));
      return;
    }
    if (_selectedChannelId != channel.id) {
      setState(() => _selectedChannelId = channel.id);
    }
    await _play(
      program.entry,
      channelId: channel.id,
      initialPositionSeconds: program.elapsedSecondsAt(now),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final channel = _selected;
    final schedule =
        channel == null ? const <_ChannelEntry>[] : _schedule(channel);
    final timeline = channel == null
        ? const <_ScheduledProgram>[]
        : _scheduledTimeline(channel, schedule, now, futureHours: 12);
    var liveIndex = -1;
    for (var i = 0; i < timeline.length; i++) {
      if (timeline[i].isOnAirAt(now)) {
        liveIndex = i;
        break;
      }
    }
    final liveProgram = liveIndex >= 0 ? timeline[liveIndex] : null;
    final upcoming = liveIndex >= 0
        ? timeline.skip(liveIndex + 1).toList()
        : timeline.where((item) => !item.start.isBefore(now)).toList();

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const UniversalText('My TV'),
              actions: [
                const PageCustomizeButton(pageId: 'my-tv'),
                IconButton(
                  onPressed: _loading
                      ? null
                      : () => Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const MyTvSpecialEventsScreen(),
                            ),
                          ),
                  tooltip: 'Special events',
                  icon: const Icon(Icons.celebration_outlined),
                ),
                IconButton(
                  onPressed: _loading
                      ? null
                      : () => setState(() => _showGuide = !_showGuide),
                  tooltip: 'TV Guide',
                  icon: Icon(
                    _showGuide
                        ? Icons.live_tv_rounded
                        : Icons.calendar_view_week_rounded,
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
                                viewingContext:
                                    channel?.name ?? 'My TV viewing',
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
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                if (!widget.showAppBar) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        alignment: WrapAlignment.spaceBetween,
                        children: <Widget>[
                          TextButton.icon(
                            onPressed: _loading
                                ? null
                                : () =>
                                    setState(() => _showGuide = !_showGuide),
                            icon: Icon(_showGuide
                                ? Icons.live_tv_rounded
                                : Icons.calendar_view_week_rounded),
                            label:
                                Text(_showGuide ? 'Channel view' : 'TV Guide'),
                          ),
                          TextButton.icon(
                            onPressed:
                                _loading ? null : _openMusicBreakSettings,
                            icon: const Icon(Icons.music_note_rounded),
                            label: const Text('Music breaks'),
                          ),
                          TextButton.icon(
                            onPressed: _loading
                                ? null
                                : () => Navigator.push<void>(
                                      context,
                                      MaterialPageRoute<void>(
                                          builder: (_) => FoodOrderingScreen(
                                                viewingContext: channel?.name ??
                                                    'My TV viewing',
                                              )),
                                    ),
                            icon: const Icon(Icons.delivery_dining_rounded),
                            label: const Text('Order food'),
                          ),
                          TextButton.icon(
                            onPressed: _loading ? null : _addChannel,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Create channel'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: Colors.amber)),
                Text(
                  _showGuide
                      ? 'TV Guide'
                      : 'Your library, programmed as a channel',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  _showGuide
                      ? 'Today’s channel schedules · no commercial ads · reminders alert while My TV is open'
                      : 'Personal programming uses media available to this profile. No commercial ads are inserted. Program reminders show in-app alerts while My TV is open.',
                  style: const TextStyle(color: Colors.white60),
                ),
                if (!_showGuide && _musicBreaks.mode != 'none')
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _musicBreakSummary(),
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
                if (_showGuide)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: UniversalText(
                      'Unavailable runtimes are estimated at 30 minutes for episodes and 2 hours for movies.',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 14),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.satellite_alt_rounded),
                    title: const Text('Looking for real broadcast channels?'),
                    subtitle: const Text(
                        'Open Public Live TV to browse external public streams, filter by country or genre, and save favorites.'),
                    trailing: const Icon(Icons.arrow_forward_rounded),
                    onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        settings: const RouteSettings(
                            name: '/app/page/public-live-tv'),
                        builder: (_) => const PublicLiveTvScreen(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const UniversalText('Quick channel presets',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  ActionChip(
                      avatar: const Icon(Icons.movie_rounded, size: 17),
                      label: const Text('Movie Mix'),
                      onPressed: _loading
                          ? null
                          : () => _addChannelPreset(
                              name: 'Movie Mix',
                              contentTypes: const ['Movies'])),
                  ActionChip(
                      avatar: const Icon(Icons.tv_rounded, size: 17),
                      label: const Text('Series Mix'),
                      onPressed: _loading
                          ? null
                          : () => _addChannelPreset(
                              name: 'Series Mix',
                              contentTypes: const ['Shows'])),
                  ActionChip(
                      avatar: const Icon(Icons.favorite_rounded, size: 17),
                      label: const Text('Favorites'),
                      onPressed: _loading
                          ? null
                          : () => _addChannelPreset(
                              name: 'Favorites',
                              contentTypes: _channelContentTypes,
                              favoritesOnly: true)),
                  ActionChip(
                      avatar: const Icon(Icons.music_note_rounded, size: 17),
                      label: const Text('Movies + Music'),
                      onPressed: _loading
                          ? null
                          : () => _addChannelPreset(
                              name: 'Movies + Music',
                              contentTypes: const ['Movies', 'Music'])),
                  ActionChip(
                      avatar: const Icon(Icons.auto_awesome_rounded, size: 17),
                      label: const Text('Seasonal Spotlight'),
                      onPressed: _loading
                          ? null
                          : () => _addChannelPreset(
                              name: 'Seasonal Spotlight',
                              contentTypes: _channelContentTypes)),
                ]),
                const SizedBox(height: 16),
                if (_showGuide) ..._guideCards(context),
                if (!_showGuide && channel != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          key: ValueKey<String?>(_selectedChannelId),
                          initialValue: _selectedChannelId,
                          items: _channels
                              .map(
                                (item) => DropdownMenuItem<String>(
                                  value: item.id,
                                  child: Text(item.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            final matches = _channels.where((item) => item.id == value);
                            if (matches.isNotEmpty) unawaited(_tuneChannel(matches.first));
                          },
                          decoration:
                              const InputDecoration(labelText: 'Channel'),
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
                                avatar:
                                    const Icon(Icons.sell_outlined, size: 15),
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
                        title: UniversalText('No programs in this channel yet'),
                        subtitle: UniversalText(
                          'Add playable movies, episodes, or music to this channel to build its daily lineup.',
                        ),
                      ),
                    )
                  else if (liveProgram != null) ...[
                    _onAirCard(context, channel, liveProgram, upcoming, now),
                    const SizedBox(height: 12),
                    const Text(
                      'COMING UP',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: Colors.white60),
                    ),
                    const SizedBox(height: 6),
                    for (final program in upcoming.take(6))
                      _upcomingProgramCard(context, channel, program, now),
                    const SizedBox(height: 12),
                    Text(
                      '${channel.name} · ${schedule.length} items in rotation · daily start ${TimeOfDay(hour: channel.startTimeMinutes ~/ 60, minute: channel.startTimeMinutes % 60).format(context)}',
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ],
                ] else if (!_showGuide && _channels.isEmpty)
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.tv_off_outlined),
                      title: UniversalText('No channels'),
                      subtitle: UniversalText(
                          'Create a channel to build your TV Guide.'),
                    ),
                  ),
              ],
            ),
    );
  }

  String _programReminderId(_MyTvChannel channel, _ScheduledProgram program) =>
      '${channel.id}|${program.entry.id}|${program.start.toUtc().toIso8601String()}';

  Future<void> _toggleProgramReminder(
    _MyTvChannel channel,
    _ScheduledProgram program,
  ) async {
    final id = _programReminderId(channel, program);
    final shouldAdd = !_programReminders.contains(id);
    setState(() {
      if (shouldAdd) {
        _programReminders.add(id);
      } else {
        _programReminders.remove(id);
      }
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = _programReminders.toList()..sort();
      final persisted = await prefs.setStringList(_reminderPreferenceKey, saved);
      if (!persisted) throw StateError('The reminder could not be written to local storage.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(shouldAdd
              ? 'Reminder set for ${program.entry.title}. My TV must remain open to show the in-app alert.'
              : 'Reminder removed for ${program.entry.title}.'),
        ));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not save the program reminder: $error'),
        ));
      }
    }
  }

  Future<void> _checkProgramReminders() async {
    if (_loading || _programReminders.isEmpty || !mounted) return;
    final now = DateTime.now();
    final dueIds = <String>{};
    final expiredIds = <String>{};
    for (final id in _programReminders) {
      final parts = id.split('|');
      final startsUtc = parts.length < 3 ? null : DateTime.tryParse(parts.last);
      if (startsUtc == null) {
        expiredIds.add(id);
        continue;
      }
      final secondsAfterStart = now.difference(startsUtc.toLocal()).inSeconds;
      if (secondsAfterStart >= 0 && secondsAfterStart <= 30) {
        dueIds.add(id);
      } else if (secondsAfterStart > 30) {
        expiredIds.add(id);
      }
    }
    if (expiredIds.isNotEmpty) {
      _programReminders.removeAll(expiredIds);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(
          _reminderPreferenceKey,
          _programReminders.toList()..sort(),
        );
      } catch (_) {}
    }
    // Avoid rebuilding every channel schedule every 15 seconds when the
    // nearest reminder is hours away; only evaluate a channel when a reminder
    // has reached its start window.
    if (dueIds.isEmpty) return;
    for (final channel in _channels) {
      final channelPrefix = '${channel.id}|';
      if (!dueIds.any((id) => id.startsWith(channelPrefix))) continue;
      final entries = _schedule(channel);
      if (entries.isEmpty) continue;
      final timeline = _scheduledTimeline(channel, entries, now, futureHours: 1);
      for (final program in timeline) {
        final id = _programReminderId(channel, program);
        if (!dueIds.contains(id)) continue;
        _programReminders.remove(id);
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setStringList(
            _reminderPreferenceKey,
            _programReminders.toList()..sort(),
          );
        } catch (_) {
          // A reminder is one-shot in memory even if preference storage fails.
        }
        if (!mounted) return;
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          duration: const Duration(seconds: 8),
          content: Text('Now on ${channel.name}: ${program.entry.title}'),
          action: SnackBarAction(
            label: 'Watch',
            onPressed: () => _playScheduledProgram(program, channel, DateTime.now()),
          ),
        ));
        return;
      }
    }
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

  Widget _onAirCard(
    BuildContext context,
    _MyTvChannel channel,
    _ScheduledProgram program,
    List<_ScheduledProgram> upcoming,
    DateTime now,
  ) {
    final progress = program.progressAt(now);
    final remaining = program.remainingAt(now);
    final endTime = _clockTime(context, program.end);
    final next = upcoming.isEmpty ? null : upcoming.first;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('ON AIR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 9),
              Text('Started ${_clockTime(context, program.start)}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
              const Spacer(),
              Text('${(progress * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 10),
            Text(program.entry.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(program.entry.subtitle, style: const TextStyle(color: Colors.white60)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.white12,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.schedule_rounded, size: 17, color: Colors.white60),
              const SizedBox(width: 6),
              Text('Ends $endTime · ${_remainingText(remaining)}', style: const TextStyle(color: Colors.white70)),
            ]),
            if (next != null) ...[
              const SizedBox(height: 8),
              Text('UP NEXT · ${_clockTime(context, next.start)} · ${next.entry.title}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: () => _playScheduledProgram(program, channel, DateTime.now()),
                icon: const Icon(Icons.live_tv_rounded),
                label: const Text('Watch live'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _upcomingProgramCard(
    BuildContext context,
    _MyTvChannel channel,
    _ScheduledProgram program,
    DateTime now,
  ) {
    final untilStart = program.start.difference(now);
    final startsIn = untilStart.inMinutes <= 0
        ? 'Starting now'
        : untilStart.inMinutes < 60
            ? 'Starts in ${untilStart.inMinutes} min'
            : 'Starts in ${untilStart.inHours} h ${untilStart.inMinutes.remainder(60)} min';
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.queue_play_next_rounded)),
        title: Text(program.entry.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${_clockTime(context, program.start)}–${_clockTime(context, program.end)} · $startsIn · ${program.entry.subtitle}', maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: IconButton(
          tooltip: _programReminders.contains(_programReminderId(channel, program))
              ? 'Remove reminder'
              : 'Remind me when this program starts',
          icon: Icon(
            _programReminders.contains(_programReminderId(channel, program))
                ? Icons.notifications_active_rounded
                : Icons.notifications_none_rounded,
          ),
          onPressed: () => _toggleProgramReminder(channel, program),
        ),
        onTap: () => _playScheduledProgram(program, channel, DateTime.now()),
      ),
    );
  }

  List<Widget> _guideCards(BuildContext context) {
    final channels = _channels.toList()
      ..sort((a, b) => (b.isFavorite ? 1 : 0).compareTo(a.isFavorite ? 1 : 0));
    const slotWidth = 170.0; // width of a 30-minute EPG slot
    const channelWidth = 155.0;
    const headerHeight = 48.0;
    const halfHourMinutes = 30;
    const visibleHours = 4;
    final now = DateTime.now();
    final gridStart = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      (now.minute ~/ halfHourMinutes) * halfHourMinutes,
    );
    final gridEnd = gridStart.add(const Duration(hours: visibleHours));
    final nowX = channelWidth +
        (now.difference(gridStart).inSeconds / (halfHourMinutes * 60)) * slotWidth;
    final timelineWidth = channelWidth + slotWidth * visibleHours * 2;

    return [
      Card(
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final rows = <Widget>[];
            for (final channel in channels) {
              final entries = _schedule(channel);
              final timeline = _scheduledTimeline(
                channel,
                entries,
                now,
                futureHours: visibleHours + 2,
              ).where((program) =>
                  program.end.isAfter(gridStart) && program.start.isBefore(gridEnd)).toList();
              final rowChildren = <Widget>[];
              if (timeline.isEmpty) {
                rowChildren.add(const Expanded(child: Center(child: UniversalText('No scheduled programs', style: TextStyle(color: Colors.white54)))));
              } else {
                for (final program in timeline) {
                  final visibleStart = program.start.isBefore(gridStart) ? gridStart : program.start;
                  final visibleEnd = program.end.isAfter(gridEnd) ? gridEnd : program.end;
                  final visibleMinutes = visibleEnd.difference(visibleStart).inSeconds / 60;
                  if (visibleMinutes <= 0) continue;
                  final width = max(24.0, slotWidth * visibleMinutes / halfHourMinutes).toDouble();
                  final isCurrent = program.isOnAirAt(now);
                  rowChildren.add(SizedBox(
                    width: width,
                    child: InkWell(
                      onTap: () => _playScheduledProgram(program, channel, DateTime.now()),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9),
                          color: isCurrent
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Colors.white.withValues(alpha: .055),
                          border: Border.all(color: isCurrent ? Colors.redAccent : Colors.white12, width: isCurrent ? 1.5 : 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${isCurrent ? '● NOW · ' : ''}${_clockTime(context, program.start)}',
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: isCurrent ? Colors.redAccent : Colors.white60),
                            ),
                            const SizedBox(height: 5),
                            Text(program.entry.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(
                              isCurrent
                                  ? '${_remainingText(program.remainingAt(now))} · ends ${_clockTime(context, program.end)}'
                                  : 'Ends ${_clockTime(context, program.end)}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10, color: Colors.white60),
                            ),
                            if (isCurrent) ...[
                              const SizedBox(height: 5),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(value: program.progressAt(now), minHeight: 4, backgroundColor: Colors.white12, color: Colors.redAccent),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ));
                }
              }
              rows.add(SizedBox(
                height: 104,
                child: Row(children: [
                  Container(
                    width: channelWidth,
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(children: [
                          Expanded(child: Text(channel.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900))),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: channel.isFavorite ? 'Remove favorite channel' : 'Favorite channel',
                            onPressed: () => _toggleFavorite(channel),
                            icon: Icon(channel.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded),
                            color: channel.isFavorite ? Colors.amber : null,
                          ),
                        ]),
                        Text(channel.contentTypes.join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.white54)),
                      ],
                    ),
                  ),
                  SizedBox(width: slotWidth * visibleHours * 2, child: Row(children: rowChildren)),
                ]),
              ));
            }
            final availableTimelineWidth = max(timelineWidth, constraints.maxWidth).toDouble();
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: availableTimelineWidth,
                child: Stack(
                  children: [
                    Column(children: [
                      SizedBox(
                        height: headerHeight,
                        child: Row(children: [
                          Container(width: channelWidth, padding: const EdgeInsets.all(12), alignment: Alignment.centerLeft, child: const UniversalText('CHANNELS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2))),
                          for (var i = 0; i < visibleHours * 2; i++)
                            SizedBox(
                              width: slotWidth,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 15),
                                child: Text(_clockTime(context, gridStart.add(Duration(minutes: i * halfHourMinutes))), style: const TextStyle(fontSize: 11, color: Colors.white54)),
                              ),
                            ),
                        ]),
                      ),
                      ...rows,
                    ]),
                    if (channels.isNotEmpty && !now.isBefore(gridStart) && now.isBefore(gridEnd))
                      Positioned(
                        left: nowX,
                        top: headerHeight,
                        bottom: 0,
                        child: IgnorePointer(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(4)),
                              child: const Text('NOW', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
                            ),
                            Expanded(child: Container(width: 2, color: Colors.redAccent)),
                          ]),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ];
  }

}
