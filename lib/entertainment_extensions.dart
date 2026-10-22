import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backend_api.dart';
import 'app_core.dart';
import 'core/models/profile_governance.dart';
import 'details.dart';
import 'localization.dart';
import 'music.dart';
import 'playback_interruption_bridge.dart';
import 'profile_content_safety.dart';

/// Small, profile-scoped record used by My Entertainment Wrapped.
/// Media bytes and raw server filesystem paths are intentionally never stored.
class WrappedActivityRecord {
  final String eventId;
  final String profileId;
  final String mediaId;
  final String canonicalWorkId;
  final String title;
  final String type;
  final String? artist;
  final String? album;
  final List<String> genres;
  final DateTime occurredAt;

  const WrappedActivityRecord({
    required this.eventId,
    required this.profileId,
    required this.mediaId,
    required this.canonicalWorkId,
    required this.title,
    required this.type,
    this.artist,
    this.album,
    required this.genres,
    required this.occurredAt,
  });

  factory WrappedActivityRecord.fromJson(Map<String, dynamic> json) {
    final rawGenres = json['genres'];
    return WrappedActivityRecord(
      eventId: json['eventId']?.toString() ?? '',
      profileId: json['profileId']?.toString() ?? '',
      mediaId: json['mediaId']?.toString() ?? '',
      canonicalWorkId:
          json['canonicalWorkId']?.toString() ?? json['mediaId']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Unknown title',
      type: json['type']?.toString() ?? 'unknown',
      artist: json['artist']?.toString(),
      album: json['album']?.toString(),
      genres: rawGenres is List
          ? rawGenres.map((value) => value.toString()).toList(growable: false)
          : const <String>[],
      occurredAt: DateTime.tryParse(json['occurredAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'eventId': eventId,
        'profileId': profileId,
        'mediaId': mediaId,
        'canonicalWorkId': canonicalWorkId,
        'title': title,
        'type': type,
        if (artist != null && artist!.trim().isNotEmpty) 'artist': artist,
        if (album != null && album!.trim().isNotEmpty) 'album': album,
        'genres': genres,
        'occurredAt': occurredAt.toIso8601String(),
      };
}

/// Testable period calculations, shared by profile and account Wrapped views.
class WrappedPeriodStats {
  final int playbackCompletions;
  final int uniqueTitles;
  final List<MapEntry<String, int>> topTitles;
  final List<MapEntry<String, int>> topGenres;
  final List<MapEntry<String, int>> topSongs;
  final List<MapEntry<String, int>> topAlbums;
  final List<MapEntry<String, int>> topArtists;
  final int movieCompletions;
  final int showCompletions;
  final int musicCompletions;

  const WrappedPeriodStats({
    required this.playbackCompletions,
    required this.uniqueTitles,
    required this.topTitles,
    required this.topGenres,
    required this.topSongs,
    required this.topAlbums,
    required this.topArtists,
    required this.movieCompletions,
    required this.showCompletions,
    required this.musicCompletions,
  });

  factory WrappedPeriodStats.calculate(
    Iterable<WrappedActivityRecord> source, {
    required int year,
    int? month,
  }) {
    final events = source.where((event) =>
        event.occurredAt.year == year &&
        (month == null || event.occurredAt.month == month)).toList();
    final titlePlayCounts = <String, int>{};
    final canonicalWorks = <String>{};
    final genres = <String, int>{};
    final songs = <String, int>{};
    final albums = <String, int>{};
    final artists = <String, int>{};
    var movies = 0;
    var shows = 0;
    var music = 0;

    for (final event in events) {
      final readableTitle = event.title.trim().isEmpty ? 'Unknown title' : event.title.trim();
      titlePlayCounts[readableTitle] = (titlePlayCounts[readableTitle] ?? 0) + 1;
      final canonicalWork = event.canonicalWorkId.trim().isNotEmpty
          ? event.canonicalWorkId.trim()
          : event.mediaId.trim();
      if (canonicalWork.isNotEmpty) canonicalWorks.add(canonicalWork);
      for (final rawGenre in event.genres) {
        final genre = rawGenre.trim();
        if (genre.isNotEmpty) genres[genre] = (genres[genre] ?? 0) + 1;
      }
      final type = event.type.toLowerCase().replaceAll(RegExp(r'[_\- ]'), '');
      final isMusic = type.contains('music') || type == 'song' || type == 'track' || type == 'album';
      if (isMusic) {
        music++;
        final isTrack = type == 'song' || type == 'track' || type.contains('musictrack');
        if (isTrack) {
          songs[readableTitle] = (songs[readableTitle] ?? 0) + 1;
        }
        final album = event.album?.trim() ?? '';
        final artist = event.artist?.trim() ?? '';
        if (album.isNotEmpty) albums[album] = (albums[album] ?? 0) + 1;
        if (artist.isNotEmpty) artists[artist] = (artists[artist] ?? 0) + 1;
      } else if (type.contains('show') || type.contains('series') || type.contains('episode')) {
        shows++;
      } else if (type.contains('movie') || type.contains('film') || type.contains('documentary') || type.contains('special')) {
        movies++;
      }
    }

    List<MapEntry<String, int>> ranked(Map<String, int> values) {
      final list = values.entries.toList()
        ..sort((a, b) {
          final countOrder = b.value.compareTo(a.value);
          return countOrder != 0 ? countOrder : a.key.compareTo(b.key);
        });
      return list.take(5).toList(growable: false);
    }

    return WrappedPeriodStats(
      playbackCompletions: events.length,
      uniqueTitles: canonicalWorks.length,
      topTitles: ranked(titlePlayCounts),
      topGenres: ranked(genres),
      topSongs: ranked(songs),
      topAlbums: ranked(albums),
      topArtists: ranked(artists),
      movieCompletions: movies,
      showCompletions: shows,
      musicCompletions: music,
    );
  }
}

/// Profile-scoped local archive. Closed periods are immutable once saved;
/// the archive is materialized on Wrapped open after a period has ended.
/// A server-backed cross-device archive can be added behind this contract.
class WrappedArchiveStore {
  WrappedArchiveStore._();

  static String eventsKey(String profileId) => 'moss_wrapped_activity_$profileId';
  static String snapshotsKey(String scopeId) => 'moss_wrapped_snapshots_$scopeId';

  static Future<List<WrappedActivityRecord>> loadEvents(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(eventsKey(profileId));
    if (raw == null) return <WrappedActivityRecord>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <WrappedActivityRecord>[];
      return decoded.whereType<Map>().map((entry) => WrappedActivityRecord.fromJson(
        Map<String, dynamic>.from(entry),
      )).where((event) => event.profileId.isNotEmpty && event.title.isNotEmpty).toList();
    } catch (_) {
      return <WrappedActivityRecord>[];
    }
  }

  static Future<List<WrappedActivityRecord>> loadScopeEvents({
    required String scopeId,
    required Iterable<String> profileIds,
  }) async {
    if (scopeId.startsWith('account_')) {
      final all = <WrappedActivityRecord>[];
      for (final profileId in profileIds) {
        all.addAll(await loadEvents(profileId));
      }
      all.sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
      return all;
    }
    return loadEvents(scopeId);
  }

  static Future<List<Map<String, dynamic>>> loadSnapshots(String scopeId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(snapshotsKey(scopeId));
    if (raw == null) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<Map>().map((entry) => Map<String, dynamic>.from(entry)).toList();
      }
    } catch (_) {
      // Ignore malformed older local archive records.
    }
    return <Map<String, dynamic>>[];
  }

  static Future<void> archiveClosedPeriods({
    required String scopeId,
    required List<WrappedActivityRecord> events,
    DateTime? now,
  }) async {
    final date = now ?? DateTime.now();
    if (events.isEmpty) return;
    final snapshots = await loadSnapshots(scopeId);
    final knownIds = snapshots.map((item) => item['id']?.toString()).toSet();
    final firstEvent = events.map((event) => event.occurredAt).reduce(
      (a, b) => a.isBefore(b) ? a : b,
    );
    final currentMonthStart = DateTime(date.year, date.month, 1);
    var cursor = DateTime(firstEvent.year, firstEvent.month, 1);
    while (cursor.isBefore(currentMonthStart)) {
      final id = 'month_${cursor.year}_${cursor.month.toString().padLeft(2, '0')}';
      final periodEvents = events.where((event) =>
          event.occurredAt.year == cursor.year && event.occurredAt.month == cursor.month).toList();
      if (!knownIds.contains(id)) {
        snapshots.add(_snapshot(
          id: id,
          scopeId: scopeId,
          periodType: 'month',
          year: cursor.year,
          month: cursor.month,
          events: periodEvents,
          finalizedAt: date,
        ));
        knownIds.add(id);
      }
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }

    final firstYear = firstEvent.year;
    for (var year = firstYear; year < date.year; year++) {
      final id = 'year_$year';
      final periodEvents = events.where((event) => event.occurredAt.year == year).toList();
      if (!knownIds.contains(id)) {
        snapshots.add(_snapshot(
          id: id,
          scopeId: scopeId,
          periodType: 'year',
          year: year,
          events: periodEvents,
          finalizedAt: date,
        ));
        knownIds.add(id);
      }
    }

    snapshots.sort((a, b) => (b['periodKey']?.toString() ?? '').compareTo(a['periodKey']?.toString() ?? ''));
    await (await SharedPreferences.getInstance()).setString(
      snapshotsKey(scopeId),
      jsonEncode(snapshots),
    );
  }

  static Map<String, dynamic> _snapshot({
    required String id,
    required String scopeId,
    required String periodType,
    required int year,
    int? month,
    required List<WrappedActivityRecord> events,
    required DateTime finalizedAt,
  }) {
    final stats = WrappedPeriodStats.calculate(events, year: year, month: month);
    return <String, dynamic>{
      'id': id,
      'scopeId': scopeId,
      'periodType': periodType,
      'year': year,
      if (month != null) 'month': month,
      'periodKey': month == null
          ? '$year'
          : '$year-${month.toString().padLeft(2, '0')}',
      'finalizedAt': finalizedAt.toIso8601String(),
      'playbackCompletions': stats.playbackCompletions,
      'uniqueTitles': stats.uniqueTitles,
      'topTitles': stats.topTitles.map((entry) => {'title': entry.key, 'count': entry.value}).toList(),
      'topGenres': stats.topGenres.map((entry) => {'genre': entry.key, 'count': entry.value}).toList(),
      'topSongs': stats.topSongs.map((entry) => {'title': entry.key, 'count': entry.value}).toList(),
      'topAlbums': stats.topAlbums.map((entry) => {'album': entry.key, 'count': entry.value}).toList(),
      'topArtists': stats.topArtists.map((entry) => {'artist': entry.key, 'count': entry.value}).toList(),
      'monthlyArchiveKeys': periodType == 'year'
          ? List<String>.generate(
              12,
              (index) => 'month_${year}_${(index + 1).toString().padLeft(2, '0')}',
            )
          : const <String>[],
    };
  }
}

class MediaWrappedCollectionsScreen extends StatefulWidget {
  const MediaWrappedCollectionsScreen({super.key});

  @override
  State<MediaWrappedCollectionsScreen> createState() => _MediaWrappedCollectionsScreenState();
}

class _MediaWrappedCollectionsScreenState extends State<MediaWrappedCollectionsScreen> {
  bool loading = true;
  bool accountView = false;
  List<WrappedActivityRecord> events = const [];
  List<Map<String, dynamic>> snapshots = const [];
  String? error;

  String get _profileId => AppController.instance.currentProfile?.id ?? '';
  String get _accountId => AppController.instance.currentAccount?.id ?? '';
  String get _scopeId => accountView ? 'account_$_accountId' : _profileId;
  Profile? get _activeProfile => AppController.instance.currentProfile;
  bool get _canViewCombinedAccount {
    final profile = _activeProfile;
    if (profile == null || !profile.governance.isOwnerManaged) return false;
    final level = profile.governance.contentLevel;
    return level == ProfileContentLevel.mature ||
        level == ProfileContentLevel.unrestricted;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (accountView && !_canViewCombinedAccount) {
      accountView = false;
    }
    setState(() => loading = true);
    try {
      final controller = AppController.instance;
      final ids = controller.currentAccount?.profiles.map((profile) => profile.id).toList() ?? <String>[];
      final loadedEvents = await WrappedArchiveStore.loadScopeEvents(
        scopeId: _scopeId,
        profileIds: ids,
      );
      await WrappedArchiveStore.archiveClosedPeriods(
        scopeId: _scopeId,
        events: loadedEvents,
      );
      final loadedSnapshots = await WrappedArchiveStore.loadSnapshots(_scopeId);
      if (!mounted) return;
      setState(() {
        events = loadedEvents;
        snapshots = loadedSnapshots;
        error = null;
        loading = false;
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        error = exception.toString();
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthly = WrappedPeriodStats.calculate(events, year: now.year, month: now.month);
    final yearly = WrappedPeriodStats.calculate(events, year: now.year);

    return Scaffold(
      backgroundColor: const Color(0xFF090909),
      appBar: AppBar(
        title: const UniversalText('My Entertainment Wrapped'),
        backgroundColor: const Color(0xFF090909),
        actions: [
          PopupMenuButton<bool>(
            tooltip: 'Change Wrapped scope',
            initialValue: accountView,
            onSelected: (value) {
              setState(() => accountView = value);
              _load();
            },
            itemBuilder: (_) => <PopupMenuEntry<bool>>[
              const PopupMenuItem(value: false, child: Text('This profile')),
              if (_canViewCombinedAccount)
                const PopupMenuItem(value: true, child: Text('Combined account')),
            ],
            icon: const Icon(Icons.people_alt_outlined),
          ),
          IconButton(onPressed: loading ? null : _load, tooltip: 'Refresh archive', icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(accountView ? 'Account Wrapped' : 'Profile Wrapped', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text(
                    accountView
                        ? 'A combined recap from profiles belonging to this signed-in account. It remains private until you choose to share it.'
                        : 'Your viewing-completion history is grouped by calendar month and year. Archived periods are finalized snapshots.',
                    style: const TextStyle(color: Colors.white70, height: 1.4),
                  ),
                  if (error != null) Card(child: Padding(padding: const EdgeInsets.all(12), child: Text(error!))),
                  const SizedBox(height: 16),
                  _wrappedPeriodCard('This month · ${_monthName(now.month)} ${now.year}', monthly),
                  const SizedBox(height: 12),
                  _wrappedPeriodCard('This year · ${now.year} (in progress)', yearly),
                  const SizedBox(height: 22),
                  const Text('Wrapped Collections', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  const Text('Closed months and years are archived the next time this screen opens after their period ends. Existing snapshots are not silently rewritten.', style: TextStyle(color: Colors.white60)),
                  const SizedBox(height: 12),
                  if (snapshots.isEmpty)
                    const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No closed periods have activity to archive yet.'))),
                  for (final snapshot in snapshots) _snapshotCard(snapshot),
                  const SizedBox(height: 10),
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Text('Data note: play counts are based on completion events recorded by this app on this device. Watch-time minutes are omitted unless a reliable duration record exists. Local archives currently do not sync across devices.', style: TextStyle(color: Colors.white60, height: 1.4)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _wrappedPeriodCard(String title, WrappedPeriodStats stats) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 10, children: [
              _wrappedMetric('Completions', stats.playbackCompletions.toString(), Icons.play_circle_outline),
              _wrappedMetric('Distinct works', stats.uniqueTitles.toString(), Icons.movie_outlined),
              _wrappedMetric('Movies', stats.movieCompletions.toString(), Icons.local_movies_outlined),
              _wrappedMetric('TV', stats.showCompletions.toString(), Icons.live_tv_outlined),
              _wrappedMetric('Music', stats.musicCompletions.toString(), Icons.music_note_rounded),
            ]),
            if (stats.topTitles.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Most revisited works', style: TextStyle(fontWeight: FontWeight.w800)),
              for (var index = 0; index < stats.topTitles.length; index++)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(radius: 14, child: Text('${index + 1}')),
                  title: Text(_displayTitle(stats.topTitles[index].key)),
                  trailing: Text('${stats.topTitles[index].value}'),
                ),
            ],
            if (stats.topGenres.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Top genres', style: TextStyle(fontWeight: FontWeight.w800)),
              Wrap(spacing: 8, runSpacing: 8, children: [for (final item in stats.topGenres) Chip(label: Text('${item.key} · ${item.value}'))]),
            ],
            _wrappedRanking('Top songs', stats.topSongs),
            _wrappedRanking('Top albums', stats.topAlbums),
            _wrappedRanking('Top artists', stats.topArtists),
          ]),
        ),
      );

  Widget _wrappedRanking(String title, List<MapEntry<String, int>> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          for (final item in items.take(5))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(item.key),
              trailing: Text('${item.value}'),
            ),
        ],
      ),
    );
  }

  Widget _wrappedMetric(String label, String value, IconData icon) => Container(
        width: 140,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .05), borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: Colors.white70),
          const SizedBox(height: 7),
          Text(value, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ]),
      );

  Widget _snapshotCard(Map<String, dynamic> snapshot) {
    final isYear = snapshot['periodType'] == 'year';
    final year = snapshot['year']?.toString() ?? '';
    final month = (snapshot['month'] as num?)?.toInt();
    final label = isYear ? '$year Wrapped Collection' : '${month == null ? '' : _monthName(month)} $year Wrapped Collection';
    final monthKeys = snapshot['monthlyArchiveKeys'] is List
        ? (snapshot['monthlyArchiveKeys'] as List).map((value) => value.toString()).toSet()
        : <String>{};
    final linkedMonths = snapshots.where((item) => monthKeys.contains(item['id']?.toString())).toList()
      ..sort((a, b) => ((a['month'] as num?)?.toInt() ?? 0).compareTo((b['month'] as num?)?.toInt() ?? 0));
    return Card(
      child: ExpansionTile(
        leading: Icon(isYear ? Icons.auto_graph_rounded : Icons.calendar_month_rounded),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('${snapshot['playbackCompletions'] ?? 0} completions · ${snapshot['uniqueTitles'] ?? 0} distinct works'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (snapshot['topTitles'] is List)
            for (final raw in (snapshot['topTitles'] as List).whereType<Map>())
              ListTile(
                dense: true,
                title: Text(raw['title']?.toString() ?? 'Unknown title'),
                trailing: Text('${raw['count'] ?? 0}'),
              ),
          for (final bucket in <({String label, String key})>[
            (label: 'Top songs', key: 'topSongs'),
            (label: 'Top albums', key: 'topAlbums'),
            (label: 'Top artists', key: 'topArtists'),
          ])
            if (snapshot[bucket.key] is List && (snapshot[bucket.key] as List).isNotEmpty) ...[
              Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(top: 8), child: Text(bucket.label, style: const TextStyle(fontWeight: FontWeight.w800)))),
              for (final raw in (snapshot[bucket.key] as List).whereType<Map>())
                ListTile(dense: true, title: Text((raw['title'] ?? raw['album'] ?? raw['artist'] ?? 'Unknown').toString()), trailing: Text('${raw['count'] ?? 0}')),
            ],
          if (isYear) ...[
            const Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.only(top: 10), child: Text('Monthly Wrapped Collections', style: TextStyle(fontWeight: FontWeight.w800)))),
            for (final monthly in linkedMonths)
              ExpansionTile(
                leading: const Icon(Icons.calendar_month_rounded),
                title: Text('${_monthName((monthly['month'] as num?)?.toInt() ?? 1)} ${monthly['year'] ?? ''}'),
                subtitle: Text('${monthly['playbackCompletions'] ?? 0} completions · ${monthly['uniqueTitles'] ?? 0} distinct works'),
                children: [
                  if (monthly['topTitles'] is List)
                    for (final raw in (monthly['topTitles'] as List).whereType<Map>())
                      ListTile(dense: true, title: Text(raw['title']?.toString() ?? 'Unknown title'), trailing: Text('${raw['count'] ?? 0}')),
                ],
              ),
          ],
          Text('Finalized ${snapshot['finalizedAt']?.toString() ?? ''}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }

  String _displayTitle(String key) {
    for (final item in AppController.instance.library) {
      if ((item.canonicalWorkId ?? item.id) == key || item.id == key) return item.title;
    }
    return key;
  }

  String _monthName(int month) => const <String>[
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December',
      ][month - 1];
}


class ThemeEvent {
  final String id;
  final String title;
  final String theme;
  final DateTime startsAt;
  final DateTime endsAt;
  final List<String> keywords;

  const ThemeEvent({
    required this.id,
    required this.title,
    required this.theme,
    required this.startsAt,
    required this.endsAt,
    required this.keywords,
  });
}

/// A seeded year planner: the same year + seed generates the same schedule.
/// Halloween and holiday windows are reserved; the other events are spread
/// through the year and remain editable/rerollable by the viewer.
class ThemeEventScheduler {
  ThemeEventScheduler._();

  static const List<Map<String, dynamic>> _themes = <Map<String, dynamic>>[
    {'title': 'Zombie Week', 'theme': 'zombie', 'keywords': ['zombie', 'undead', 'infected', 'apocalypse']},
    {'title': 'Superhero Week', 'theme': 'superhero', 'keywords': ['superhero', 'super hero', 'marvel', 'dc comics', 'comic book']},
    {'title': 'Horror-Comedy Weekend', 'theme': 'horror comedy', 'keywords': ['horror-comedy', 'horror comedy', 'comedy horror']},
    {'title': 'Sci-Fi Discovery Week', 'theme': 'science fiction', 'keywords': ['science fiction', 'sci-fi', 'space', 'alien', 'futuristic']},
    {'title': 'Animation Celebration', 'theme': 'animation', 'keywords': ['animation', 'animated', 'cartoon', 'family']},
    {'title': 'Mystery & Twist Week', 'theme': 'mystery', 'keywords': ['mystery', 'detective', 'thriller', 'whodunit']},
    {'title': 'Romantic Stories Week', 'theme': 'romance', 'keywords': ['romance', 'romantic', 'love story', 'rom-com']},
    {'title': 'Action & Adventure Week', 'theme': 'action', 'keywords': ['action', 'adventure', 'spy', 'heist']},
    {'title': 'Musical Moments Week', 'theme': 'music', 'keywords': ['musical', 'concert', 'soundtrack', 'music']},
    {'title': 'Fantasy Worlds Week', 'theme': 'fantasy', 'keywords': ['fantasy', 'magic', 'wizard', 'myth']},
    {'title': 'Comfort Rewatch Week', 'theme': 'comfort', 'keywords': ['comfort', 'feel-good', 'feel good', 'favorite']},
    {'title': 'Family Favorites Week', 'theme': 'family', 'keywords': ['family', 'kids', 'children', 'together']},
    {'title': 'Slasher Week', 'theme': 'slasher', 'keywords': ['slasher', 'halloween', 'serial killer', 'masked killer']},
    {'title': 'Holiday Countdown', 'theme': 'holiday', 'keywords': ['christmas', 'holiday', 'winter', 'festive']},
  ];

  static List<ThemeEvent> buildYear(int year, {required int seed}) {
    final random = math.Random(seed ^ year);
    final themes = List<Map<String, dynamic>>.from(_themes);
    final fixedSlasher = themes.firstWhere((item) => item['theme'] == 'slasher');
    final fixedHoliday = themes.firstWhere((item) => item['theme'] == 'holiday');
    final fixedRomance = themes.firstWhere((item) => item['theme'] == 'romance');
    final fixedAnimation = themes.firstWhere((item) => item['theme'] == 'animation');
    final fixedZombie = themes.firstWhere((item) => item['theme'] == 'zombie');
    final fixedSuperhero = themes.firstWhere((item) => item['theme'] == 'superhero');
    final used = <String>{
      'slasher', 'holiday', 'romance', 'animation', 'zombie', 'superhero',
    };
    final events = <ThemeEvent>[
      _event(fixedRomance, DateTime(year, 2, 7), 7),
      _event(fixedZombie, DateTime(year, 3, 8), 7),
      _event(fixedAnimation, DateTime(year, 6, 8), 7),
      _event(fixedSuperhero, DateTime(year, 8, 7), 7),
      _event(fixedSlasher, DateTime(year, 10, 25), 7),
      _event(fixedHoliday, DateTime(year, 12, 18), 8),
    ];

    final months = <int>[1, 4, 5, 7, 9, 11]..shuffle(random);
    final remaining = themes.where((item) => !used.contains(item['theme'])).toList()..shuffle(random);
    for (var i = 0; i < months.length && i < remaining.length; i++) {
      final month = months[i];
      final lastDay = DateTime(year, month + 1, 0).day;
      final safeDayMax = math.max(1, lastDay - 7).toInt();
      final day = 4 + random.nextInt(math.max(1, safeDayMax - 3).toInt());
      final duration = 3 + random.nextInt(5);
      events.add(_event(remaining[i], DateTime(year, month, day), duration));
    }
    events.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return events;
  }

  static ThemeEvent _event(Map<String, dynamic> raw, DateTime start, int days) => ThemeEvent(
        id: '${raw['theme']}_${start.year}_${start.month}_${start.day}',
        title: raw['title']?.toString() ?? 'Special Event',
        theme: raw['theme']?.toString() ?? 'mixed',
        startsAt: start,
        endsAt: start.add(Duration(days: days - 1)),
        keywords: (raw['keywords'] as List? ?? const []).map((value) => value.toString()).toList(growable: false),
      );

  static bool _matchesFields(Iterable<String> fields, List<String> keywords) {
    final searchable = fields.join(' ').toLowerCase();
    return keywords.any((keyword) => searchable.contains(keyword));
  }

  static List<MediaItem> matchingMedia(ThemeEvent event, Iterable<MediaItem> library) =>
      library.where((item) => _matchesFields(<String>[
        item.title, item.type, item.description ?? '', ...item.genres, ...item.tags,
      ], event.keywords)).toList(growable: false);

  static List<MusicTrack> matchingMusic(ThemeEvent event, Iterable<MusicTrack> tracks) =>
      tracks.where((item) => _matchesFields(<String>[
        item.title, item.artist, item.album, ...item.genres, ...item.subgenres,
      ], event.keywords)).toList(growable: false);
}

class MyTvSpecialEventsScreen extends StatefulWidget {
  const MyTvSpecialEventsScreen({super.key});

  @override
  State<MyTvSpecialEventsScreen> createState() => _MyTvSpecialEventsScreenState();
}

class _MyTvSpecialEventsScreenState extends State<MyTvSpecialEventsScreen> {
  bool loading = true;
  int year = DateTime.now().year;
  int seed = 20261021;
  List<ThemeEvent> events = const [];

  String get _seedKey => 'moss_theme_event_seed_${AppController.instance.currentProfile?.id ?? 'default'}_$year';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_seedKey);
    if (!mounted) return;
    setState(() {
      seed = saved ?? (year * 1009 + 27);
      events = ThemeEventScheduler.buildYear(year, seed: seed);
      loading = false;
    });
  }

  Future<void> _reroll() async {
    final prefs = await SharedPreferences.getInstance();
    final nextSeed = seed + 1;
    await prefs.setInt(_seedKey, nextSeed);
    if (!mounted) return;
    setState(() {
      seed = nextSeed;
      events = ThemeEventScheduler.buildYear(year, seed: seed);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF090909),
        appBar: AppBar(
          title: const UniversalText('My TV · Special Events'),
          backgroundColor: const Color(0xFF090909),
          actions: [
            IconButton(tooltip: 'Previous year', onPressed: year <= 2020 ? null : () { setState(() { year--; loading = true; }); _load(); }, icon: const Icon(Icons.chevron_left_rounded)),
            Center(child: Text('$year')),
            IconButton(tooltip: 'Next year', onPressed: () { setState(() { year++; loading = true; }); _load(); }, icon: const Icon(Icons.chevron_right_rounded)),
            IconButton(tooltip: 'Reroll randomized schedule', onPressed: _reroll, icon: const Icon(Icons.shuffle_rounded)),
          ],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text('A year of themed viewing', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  const Text('The schedule is seeded and stable until you reroll it. Halloween and holiday windows are reserved; other themes are spread throughout the year. Only media found in your local library is shown as available.', style: TextStyle(color: Colors.white70, height: 1.4)),
                  const SizedBox(height: 16),
                  for (final event in events) _eventCard(event),
                ],
              ),
      );

  Widget _eventCard(ThemeEvent event) {
    final profile = AppController.instance.currentProfile;
    final visibleLibrary = AppController.instance.library
        .where((item) => item.isAccessibleTo(profile))
        .toList(growable: false);
    final visibleTracks = MusicLibraryStore.instance.tracks.where((track) {
      if (profileBlocksExplicitMusic(profile) && track.explicit) return false;
      if (profileBlocksMatureMusic(profile) && track.matureTheme) return false;
      return true;
    }).toList(growable: false);
    final media = ThemeEventScheduler.matchingMedia(event, visibleLibrary);
    final tracks = ThemeEventScheduler.matchingMusic(event, visibleTracks);
    final now = DateTime.now();
    final status = now.isBefore(event.startsAt)
        ? 'Upcoming'
        : now.isAfter(event.endsAt.add(const Duration(days: 1)))
            ? 'Completed'
            : 'Happening now';
    return Card(
      child: ExpansionTile(
        leading: const CircleAvatar(child: Icon(Icons.event_available_rounded)),
        title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('${event.startsAt.month}/${event.startsAt.day} – ${event.endsAt.month}/${event.endsAt.day}, ${event.endsAt.year} · $status · ${media.length} titles · ${tracks.length} tracks'),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          if (media.isEmpty && tracks.isEmpty)
            const Padding(padding: EdgeInsets.all(12), child: Text('No matching local titles yet. This event is scheduled, but the app will not invent content or claim provider availability.')),
          for (final item in media)
            ListTile(
              leading: const Icon(Icons.movie_outlined),
              title: Text(item.title),
              subtitle: Text(item.type),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MediaDetailsScreen(media: item))),
            ),
          for (final track in tracks)
            ListTile(leading: const Icon(Icons.music_note_rounded), title: Text(track.title), subtitle: Text(track.artist)),
        ],
      ),
    );
  }
}

class RealLifeInterruptionModeScreen extends StatefulWidget {
  const RealLifeInterruptionModeScreen({super.key});

  @override
  State<RealLifeInterruptionModeScreen> createState() => _RealLifeInterruptionModeScreenState();
}

class _RealLifeInterruptionModeScreenState extends State<RealLifeInterruptionModeScreen> {
  bool enabled = true;
  bool bedtimePrompt = false;
  bool pauseMusic = true;
  bool doNotInterrupt = false;
  bool loading = true;

  String get _key => 'moss_interruption_settings_${AppController.instance.currentProfile?.id ?? 'default'}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (!mounted) return;
    if (raw != null) {
      try {
        final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        enabled = data['enabled'] != false;
        bedtimePrompt = data['bedtimePrompt'] == true;
        pauseMusic = data['pauseMusic'] != false;
        doNotInterrupt = data['doNotInterrupt'] == true;
      } catch (_) {}
    }
    setState(() => loading = false);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(<String, dynamic>{
      'enabled': enabled,
      'bedtimePrompt': bedtimePrompt,
      'pauseMusic': pauseMusic,
      'doNotInterrupt': doNotInterrupt,
    }));
  }

  void _control(String action) {
    bool performed = false;
    switch (action) {
      case 'pause': performed = PlaybackInterruptionBridge.pauseNow(); break;
      case 'resume': performed = PlaybackInterruptionBridge.resumeNow(); break;
      case 'save': performed = PlaybackInterruptionBridge.savePosition(); break;
    }
    if (!mounted) return;
    final message = performed
        ? (action == 'pause' ? 'Playback paused.' : action == 'resume' ? 'Playback resumed.' : 'Current playback position saved.')
        : 'No compatible in-app player is connected right now. Open playback and use its controls.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const UniversalText('Real-Life Interruption Mode')),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(16), children: [
                Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Pause real life less intrusively', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  const Text('Use explicit controls to pause, save progress and resume. Always-on room listening is not enabled by this feature.', style: TextStyle(color: Colors.white70, height: 1.4)),
                  const SizedBox(height: 12),
                  Text(PlaybackInterruptionBridge.currentTitle == null ? 'Player status: no compatible player attached' : 'Now playing: ${PlaybackInterruptionBridge.currentTitle}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    FilledButton.tonalIcon(onPressed: enabled ? () => _control('pause') : null, icon: const Icon(Icons.pause_rounded), label: const Text('I need a break')),
                    FilledButton.tonalIcon(onPressed: enabled ? () => _control('save') : null, icon: const Icon(Icons.bookmark_added_outlined), label: const Text('Save position')),
                    FilledButton.icon(onPressed: enabled ? () => _control('resume') : null, icon: const Icon(Icons.play_arrow_rounded), label: const Text("I'm back")),
                  ]),
                ]))),
                Card(child: Column(children: [
                  SwitchListTile(title: const Text('Interruption controls enabled'), subtitle: const Text('Enable explicit pause, resume and save-position controls.'), value: enabled, onChanged: (value) { setState(() => enabled = value); _save(); }),
                  SwitchListTile(title: const Text('Bedtime prompt'), subtitle: const Text('Show bedtime settings here; system notifications require a platform notification integration.'), value: bedtimePrompt, onChanged: (value) { setState(() => bedtimePrompt = value); _save(); }),
                  SwitchListTile(title: const Text('Prefer pausing music during a video interruption'), subtitle: const Text('Saved as a preference; automatic music pausing needs a shared music-player integration.'), value: pauseMusic, onChanged: (value) { setState(() => pauseMusic = value); _save(); }),
                  SwitchListTile(title: const Text('Do Not Interrupt'), subtitle: const Text('A preference flag for compatible future notification/automation integrations.'), value: doNotInterrupt, onChanged: (value) { setState(() => doNotInterrupt = value); _save(); }),
                ])),
                const Card(child: Padding(padding: EdgeInsets.all(14), child: Text('Microphone privacy: no background wake-word service is started. Any future voice activation must be separately opted into, visibly active, and supported by the operating system/device.', style: TextStyle(color: Colors.white60, height: 1.4)))),
              ]),
      );
}

class SecurityBotCenterScreen extends StatefulWidget {
  const SecurityBotCenterScreen({super.key});

  @override
  State<SecurityBotCenterScreen> createState() => _SecurityBotCenterScreenState();
}

class _SecurityBotCenterScreenState extends State<SecurityBotCenterScreen> {
  bool loading = false;
  String? error;
  Map<String, dynamic>? backendReport;
  List<_LocalBotCheck> localChecks = const [];
  final Map<String, String> modes = <String, String>{};

  @override
  void initState() {
    super.initState();
    _loadModes();
    _runChecks();
  }

  Future<void> _loadModes() async {
    final prefs = await SharedPreferences.getInstance();
    final profile = AppController.instance.currentProfile?.id ?? 'default';
    for (final id in const ['account_guardian', 'catalog_quality', 'connection_review', 'backup_watch']) {
      modes[id] = prefs.getString('moss_bot_mode_${profile}_$id') ?? 'Human approval required';
    }
    if (mounted) setState(() {});
  }

  List<_LocalBotCheck> _inspectLocalData() {
    final controller = AppController.instance;
    final library = controller.library;
    final profiles = controller.currentAccount?.profiles ?? const [];
    final duplicateMediaIds = library.length - library.map((item) => item.id).toSet().length;
    final usernames = profiles.map((item) => item.username.trim().toLowerCase()).where((value) => value.isNotEmpty).toList();
    final duplicateUsernames = usernames.length - usernames.toSet().length;
    final missingUsernames = profiles.where((item) => item.username.trim().isEmpty).length;
    final missingArtwork = library.where((item) => item.imageUrl?.trim().isNotEmpty != true).length;
    final insecureUrls = library.where((item) {
      final value = item.playbackUrl?.trim() ?? '';
      final uri = Uri.tryParse(value);
      return value.isNotEmpty && uri != null && uri.scheme == 'http' && uri.host != 'localhost' && uri.host != '127.0.0.1';
    }).length;
    return <_LocalBotCheck>[
      _LocalBotCheck('catalog_quality', 'Catalog Quality Bot', duplicateMediaIds == 0 ? 'passed' : 'warning', '$duplicateMediaIds duplicate media IDs in the loaded library.'),
      _LocalBotCheck('account_guardian', 'Account & Profile Guardian', duplicateUsernames == 0 && missingUsernames == 0 ? 'passed' : 'warning', '$duplicateUsernames repeated usernames; $missingUsernames profiles without a username.'),
      _LocalBotCheck('metadata_health', 'Media Library Health Bot', missingArtwork == 0 ? 'passed' : 'info', '$missingArtwork loaded media items are missing artwork.'),
      _LocalBotCheck('connection_review', 'Playback URL Review', insecureUrls == 0 ? 'passed' : 'warning', '$insecureUrls external playback URLs use HTTP. Development localhost URLs are excluded.'),
      const _LocalBotCheck('backup_watch', 'Backup & Recovery Watch', 'not_connected', 'Backup encryption, restore drills and server storage cannot be verified from the client-only scan.'),
    ];
  }

  Future<void> _runChecks() async {
    setState(() => loading = true);
    final checks = _inspectLocalData();
    Map<String, dynamic>? report;
    String? problem;
    final api = AppController.instance.backendApi;
    if (api.isAuthenticated) {
      try {
        report = await api.runOperationsBotScan();
      } catch (exception) {
        problem = 'Backend scan unavailable: ${exception.toString().replaceFirst('Exception: ', '')}';
      }
    } else {
      problem = 'Sign in as the account/server owner to run server-side scans. Local checks below are still available.';
    }
    if (!mounted) return;
    setState(() {
      localChecks = checks;
      backendReport = report;
      error = problem;
      loading = false;
    });
  }

  Future<void> _setMode(String id, String value) async {
    final profile = AppController.instance.currentProfile?.id ?? 'default';
    modes[id] = value;
    await (await SharedPreferences.getInstance()).setString('moss_bot_mode_${profile}_$id', value);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const UniversalText('Security & Database Bot Center'), actions: [IconButton(tooltip: 'Run checks', onPressed: loading ? null : _runChecks, icon: const Icon(Icons.refresh_rounded))]),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(onRefresh: _runChecks, child: ListView(padding: const EdgeInsets.all(16), children: [
                const Text('Permission-controlled diagnostics', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                const Text('Local checks inspect only metadata currently loaded by this client. Server checks are owner-only and never return secret values. Bot modes here configure policy intent; this screen does not permit destructive autonomous remediation.', style: TextStyle(color: Colors.white70, height: 1.4)),
                if (error != null) Card(child: Padding(padding: const EdgeInsets.all(12), child: Text(error!))),
                if (backendReport != null) _backendReportCard(backendReport!),
                const SizedBox(height: 10),
                const Text('Local checks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                for (final check in localChecks) Card(child: ListTile(
                  leading: Icon(_statusIcon(check.status), color: _statusColor(check.status)),
                  title: Text(check.title),
                  subtitle: Text(check.details),
                  trailing: const Text('LOCAL', style: TextStyle(fontSize: 10, color: Colors.white54)),
                )),
                const SizedBox(height: 16),
                const Text('Bot permission policies', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                for (final bot in const [
                  ('account_guardian', 'Account & Profile Protection Bot'),
                  ('catalog_quality', 'Catalog Quality Bot'),
                  ('connection_review', 'Vulnerability / Connection Review Bot'),
                  ('backup_watch', 'Backup & Recovery Bot'),
                ]) Card(child: ListTile(
                  title: Text(bot.$2),
                  subtitle: const Text('Default is approval required for changes. This selection is a policy preference, not proof a background worker is running.'),
                  trailing: DropdownButton<String>(value: modes[bot.$1] ?? 'Human approval required', items: const [
                    DropdownMenuItem(value: 'Observe only', child: Text('Observe')),
                    DropdownMenuItem(value: 'Recommend only', child: Text('Recommend')),
                    DropdownMenuItem(value: 'Limited automatic response', child: Text('Limited auto')),
                    DropdownMenuItem(value: 'Human approval required', child: Text('Approval')),
                  ], onChanged: (value) { if (value != null) _setMode(bot.$1, value); }),
                )),
              ])),
      );

  Widget _backendReportCard(Map<String, dynamic> report) {
    final checks = report['checks'] is List ? (report['checks'] as List).whereType<Map>().toList() : const <Map>[];
    final summary = report['summary'] is Map ? Map<String, dynamic>.from(report['summary'] as Map) : <String, dynamic>{};
    return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Server-side owner scan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      Text('Run at ${report['generatedAt'] ?? 'unknown time'}'),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: [
        Chip(label: Text('${summary['passed'] ?? 0} passed')),
        Chip(label: Text('${summary['warning'] ?? 0} warnings')),
        Chip(label: Text('${summary['failed'] ?? 0} failed')),
      ]),
      for (final check in checks) ListTile(
        dense: true,
        leading: Icon(_statusIcon(check['status']?.toString() ?? 'info'), color: _statusColor(check['status']?.toString() ?? 'info')),
        title: Text(check['title']?.toString() ?? check['id']?.toString() ?? 'Check'),
        subtitle: Text(check['details']?.toString() ?? ''),
      ),
    ])));
  }

  IconData _statusIcon(String status) => switch (status) {
        'passed' => Icons.check_circle_outline_rounded,
        'warning' => Icons.warning_amber_rounded,
        'failed' => Icons.error_outline_rounded,
        'not_connected' => Icons.cloud_off_rounded,
        _ => Icons.info_outline_rounded,
      };

  Color _statusColor(String status) => switch (status) {
        'passed' => Colors.greenAccent,
        'warning' => Colors.orangeAccent,
        'failed' => Colors.redAccent,
        _ => Colors.white54,
      };
}

class _LocalBotCheck {
  final String id;
  final String title;
  final String status;
  final String details;
  const _LocalBotCheck(this.id, this.title, this.status, this.details);
}
