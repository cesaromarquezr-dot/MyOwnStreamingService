import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backend_api.dart';
import 'app_core.dart';
import 'core/models/profile_governance.dart';
import 'details.dart';
import 'localization.dart';
import 'music.dart';
import 'playback_interruption_bridge.dart';
import 'profile_content_safety.dart';
import 'privacy_preferences.dart';

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
  final String action;
  final String? contextType;
  final String? contextId;
  final String? contextTitle;
  final List<Map<String, String>> entities;
  final DateTime occurredAt;
  final bool excludedFromWrapped;

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
    this.action = 'completed',
    this.contextType,
    this.contextId,
    this.contextTitle,
    this.entities = const <Map<String, String>>[],
    required this.occurredAt,
    this.excludedFromWrapped = false,
  });

  WrappedActivityRecord copyWith({
    String? contextType,
    String? contextId,
    String? contextTitle,
    List<Map<String, String>>? entities,
    bool? excludedFromWrapped,
    bool clearContext = false,
  }) =>
      WrappedActivityRecord(
        eventId: eventId,
        profileId: profileId,
        mediaId: mediaId,
        canonicalWorkId: canonicalWorkId,
        title: title,
        type: type,
        artist: artist,
        album: album,
        genres: genres,
        action: action,
        contextType: clearContext ? null : (contextType ?? this.contextType),
        contextId: clearContext ? null : (contextId ?? this.contextId),
        contextTitle: clearContext ? null : (contextTitle ?? this.contextTitle),
        entities: entities ?? this.entities,
        occurredAt: occurredAt,
        excludedFromWrapped: excludedFromWrapped ?? this.excludedFromWrapped,
      );

  factory WrappedActivityRecord.fromJson(Map<String, dynamic> json) {
    final rawGenres = json['genres'];
    return WrappedActivityRecord(
      eventId: json['eventId']?.toString() ?? '',
      profileId: json['profileId']?.toString() ?? '',
      mediaId: json['mediaId']?.toString() ?? '',
      canonicalWorkId: json['canonicalWorkId']?.toString() ??
          json['mediaId']?.toString() ??
          '',
      title: json['title']?.toString() ?? 'Unknown title',
      type: json['type']?.toString() ?? 'unknown',
      artist: json['artist']?.toString(),
      album: json['album']?.toString(),
      genres: rawGenres is List
          ? rawGenres.map((value) => value.toString()).toList(growable: false)
          : const <String>[],
      action: json['action']?.toString() ?? 'completed',
      contextType: json['contextType']?.toString(),
      contextId: json['contextId']?.toString(),
      contextTitle: json['contextTitle']?.toString(),
      entities: json['entities'] is List
          ? (json['entities'] as List)
              .whereType<Map>()
              .map((value) => <String, String>{
                    'type': value['type']?.toString() ?? 'other',
                    'id': value['id']?.toString() ?? '',
                    'name': value['name']?.toString() ?? '',
                  })
              .where((value) => value['name']!.trim().isNotEmpty)
              .toList(growable: false)
          : const <Map<String, String>>[],
      occurredAt: DateTime.tryParse(json['occurredAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      excludedFromWrapped: json['excludedFromWrapped'] == true,
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
        'action': action,
        if (contextType?.trim().isNotEmpty == true) 'contextType': contextType,
        if (contextId?.trim().isNotEmpty == true) 'contextId': contextId,
        if (contextTitle?.trim().isNotEmpty == true)
          'contextTitle': contextTitle,
        'entities': entities,
        'occurredAt': occurredAt.toIso8601String(),
        if (excludedFromWrapped) 'excludedFromWrapped': true,
      };
}

/// A profile/title association behind one Wrapped ranking entry.
/// Repeated plays of the same work by the same profile in the same source are
/// grouped so the details stay readable while preserving the exact play count.
class WrappedProfileAttribution {
  final String profileId;
  final String mediaTitle;
  final String mediaType;
  final String? sourceType;
  final String? sourceTitle;
  final int playCount;

  const WrappedProfileAttribution({
    required this.profileId,
    required this.mediaTitle,
    required this.mediaType,
    this.sourceType,
    this.sourceTitle,
    required this.playCount,
  });

  bool get isMusic {
    final normalized =
        mediaType.toLowerCase().replaceAll(RegExp(r'[_\-\s]'), '');
    return normalized.contains('music') ||
        normalized == 'song' ||
        normalized == 'track' ||
        normalized == 'album';
  }

  String get sourceLabel {
    final title = sourceTitle?.trim() ?? '';
    if (title.isEmpty) return 'Direct playback';
    final type = sourceType?.trim().isNotEmpty == true
        ? sourceType!.trim()
        : 'collection';
    return 'From $type · $title';
  }
}

/// Matches a real playback event to the exact dimension used by a Wrapped
/// ranking. This deliberately uses event metadata rather than hardcoded names.
bool wrappedEventMatchesRankingItem(
  WrappedActivityRecord event, {
  required String matchKind,
  required String itemName,
}) {
  if (event.excludedFromWrapped || event.action.toLowerCase() == 'excluded') {
    return false;
  }
  String normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  final target = normalize(itemName);
  if (target.isEmpty) return false;
  final type = event.type.toLowerCase().replaceAll(RegExp(r'[_\-\s]'), '');
  final isMusic = type.contains('music') ||
      type == 'song' ||
      type == 'track' ||
      type == 'album';
  bool hasEntity(Iterable<String> kinds) => event.entities.any((entity) =>
      kinds.contains((entity['type'] ?? '').trim().toLowerCase()) &&
      normalize(entity['name'] ?? '') == target);
  bool sameTitle() => normalize(event.title) == target;

  switch (matchKind) {
    case 'title':
      return sameTitle();
    case 'movie':
      return sameTitle() &&
          (type.contains('movie') ||
              type.contains('film') ||
              type.contains('documentary') ||
              type.contains('special'));
    case 'episode':
      return sameTitle() && type.contains('episode');
    case 'song':
      return sameTitle() &&
          isMusic &&
          (type == 'song' || type == 'track' || type.contains('musictrack'));
    case 'genre':
      return event.genres.any((value) => normalize(value) == target);
    case 'album':
      return hasEntity(const ['album']) ||
          (normalize(event.album ?? '') == target &&
              event.contextType == null &&
              event.action != 'played');
    case 'artist':
      return hasEntity(const ['artist']) ||
          (normalize(event.artist ?? '') == target && event.entities.isEmpty);
    case 'playlist':
      return hasEntity(const ['playlist']) ||
          ((event.contextType ?? '').toLowerCase() == 'playlist' &&
              normalize(event.contextTitle ?? '') == target);
    case 'collection':
      return hasEntity(const ['collection', 'franchise', 'universe']) ||
          (const ['collection', 'franchise', 'universe']
                  .contains((event.contextType ?? '').toLowerCase()) &&
              normalize(event.contextTitle ?? '') == target);
    case 'series':
      return hasEntity(const ['series', 'show']);
    case 'cast':
      return hasEntity(const ['cast', 'actor', 'actress']);
    case 'person':
      return hasEntity(const ['person']);
    case 'character':
      return hasEntity(const ['character']);
    case 'tag':
      return hasEntity(const ['tag']);
    case 'director':
      return hasEntity(const ['director']);
    case 'writer':
      return hasEntity(const ['writer', 'composer']);
    case 'company':
      return hasEntity(const ['company', 'studio', 'network']);
    case 'country':
      return hasEntity(const ['country']);
    case 'context':
      final source = (event.contextTitle?.trim().isNotEmpty ?? false)
          ? '${event.contextType ?? 'source'}: ${event.contextTitle}'
          : 'Direct playback';
      return normalize(source) == target;
    default:
      return false;
  }
}

/// Creates the profile-to-title breakdown for a Top 10/Top 50 item. The caller
/// must pass only events visible in the current Wrapped scope. Account Wrapped
/// already filters this list using each profile's shareActivity preference.
List<WrappedProfileAttribution> buildWrappedProfileAttributions(
  Iterable<WrappedActivityRecord> source, {
  required String itemName,
  required String matchKind,
  required int year,
  int? month,
}) {
  final grouped = <String, WrappedProfileAttribution>{};
  for (final event in source) {
    if (event.occurredAt.year != year ||
        (month != null && event.occurredAt.month != month)) {
      continue;
    }
    if (!wrappedEventMatchesRankingItem(event,
        matchKind: matchKind, itemName: itemName)) {
      continue;
    }
    final key = jsonEncode(<String?>[
      event.profileId,
      event.mediaId,
      event.title,
      event.type,
      event.contextType,
      event.contextTitle,
    ]);
    final existing = grouped[key];
    grouped[key] = WrappedProfileAttribution(
      profileId: event.profileId,
      mediaTitle: event.title,
      mediaType: event.type,
      sourceType: event.contextType,
      sourceTitle: event.contextTitle,
      playCount: (existing?.playCount ?? 0) + 1,
    );
  }
  final result = grouped.values.toList()
    ..sort((a, b) {
      final countOrder = b.playCount.compareTo(a.playCount);
      if (countOrder != 0) return countOrder;
      final profileOrder = a.profileId.compareTo(b.profileId);
      return profileOrder != 0
          ? profileOrder
          : a.mediaTitle.compareTo(b.mediaTitle);
    });
  return result;
}

/// Testable period calculations, shared by profile and account Wrapped views.
class WrappedPeriodStats {
  final int playbackCompletions;
  final int uniqueTitles;
  final List<MapEntry<String, int>> topTitles;
  final List<MapEntry<String, int>> topMovies;
  final List<MapEntry<String, int>> topEpisodes;
  final List<MapEntry<String, int>> topGenres;
  final List<MapEntry<String, int>> topSongs;
  final List<MapEntry<String, int>> topAlbums;
  final List<MapEntry<String, int>> topArtists;
  final List<MapEntry<String, int>> topPlaylists;
  final List<MapEntry<String, int>> topCollections;
  final List<MapEntry<String, int>> topSeries;
  final List<MapEntry<String, int>> topCast;
  final List<MapEntry<String, int>> topPeople;
  final List<MapEntry<String, int>> topCharacters;
  final List<MapEntry<String, int>> topTags;
  final List<MapEntry<String, int>> topDirectors;
  final List<MapEntry<String, int>> topWriters;
  final List<MapEntry<String, int>> topCompanies;
  final List<MapEntry<String, int>> topCountries;
  final int movieCompletions;
  final int showCompletions;
  final int musicCompletions;
  final int activeDays;
  final int busiestDayStarts;
  final DateTime? busiestDay;
  final double averageStartsPerActiveDay;
  final List<MapEntry<String, int>> topContexts;

  const WrappedPeriodStats({
    required this.playbackCompletions,
    required this.uniqueTitles,
    required this.topTitles,
    required this.topMovies,
    required this.topEpisodes,
    required this.topGenres,
    required this.topSongs,
    required this.topAlbums,
    required this.topArtists,
    required this.topPlaylists,
    required this.topCollections,
    required this.topSeries,
    required this.topCast,
    required this.topPeople,
    required this.topCharacters,
    required this.topTags,
    required this.topDirectors,
    required this.topWriters,
    required this.topCompanies,
    required this.topCountries,
    required this.movieCompletions,
    required this.showCompletions,
    required this.musicCompletions,
    required this.activeDays,
    required this.busiestDayStarts,
    required this.busiestDay,
    required this.averageStartsPerActiveDay,
    required this.topContexts,
  });

  factory WrappedPeriodStats.calculate(
    Iterable<WrappedActivityRecord> source, {
    required int year,
    int? month,
    int topLimit = 5,
    int? topTitlesLimit,
  }) {
    // Yearly reports aggregate every eligible playback event from January
    // through December. This is equivalent to summing each month's item
    // counts, but deliberately uses the full event journal rather than monthly
    // Top 10 snapshots so lower-ranked monthly items are not lost.
    final events = source
        .where((event) =>
            !event.excludedFromWrapped &&
            event.action.toLowerCase() != 'excluded' &&
            event.occurredAt.year == year &&
            (month == null || event.occurredAt.month == month))
        .toList();
    final titlePlayCounts = <String, int>{};
    final moviePlayCounts = <String, int>{};
    final episodePlayCounts = <String, int>{};
    final canonicalWorks = <String>{};
    final genres = <String, int>{};
    final songs = <String, int>{};
    final albums = <String, int>{};
    final artists = <String, int>{};
    final playlists = <String, int>{};
    final collections = <String, int>{};
    final series = <String, int>{};
    final cast = <String, int>{};
    final people = <String, int>{};
    final characters = <String, int>{};
    final tags = <String, int>{};
    final directors = <String, int>{};
    final writers = <String, int>{};
    final companies = <String, int>{};
    final countries = <String, int>{};
    final contextStarts = <String, int>{};
    final dayStarts = <DateTime, int>{};
    var movies = 0;
    var shows = 0;
    var music = 0;

    for (final event in events) {
      final readableTitle =
          event.title.trim().isEmpty ? 'Unknown title' : event.title.trim();
      titlePlayCounts[readableTitle] =
          (titlePlayCounts[readableTitle] ?? 0) + 1;
      final localTime = event.occurredAt.toLocal();
      final day = DateTime(localTime.year, localTime.month, localTime.day);
      dayStarts[day] = (dayStarts[day] ?? 0) + 1;
      final sourceLabel = (event.contextTitle?.trim().isNotEmpty ?? false)
          ? '${event.contextType ?? 'source'}: ${event.contextTitle}'
          : 'Direct playback';
      contextStarts[sourceLabel] = (contextStarts[sourceLabel] ?? 0) + 1;
      final canonicalWork = event.canonicalWorkId.trim().isNotEmpty
          ? event.canonicalWorkId.trim()
          : event.mediaId.trim();
      if (canonicalWork.isNotEmpty) canonicalWorks.add(canonicalWork);
      final countedGenres = <String>{};
      for (final rawGenre in event.genres) {
        final genre = rawGenre.trim();
        if (genre.isNotEmpty && countedGenres.add(genre.toLowerCase())) {
          genres[genre] = (genres[genre] ?? 0) + 1;
        }
      }
      final type = event.type.toLowerCase().replaceAll(RegExp(r'[_\- ]'), '');
      final isMusic = type.contains('music') ||
          type == 'song' ||
          type == 'track' ||
          type == 'album';
      if (isMusic) {
        music++;
        final isTrack =
            type == 'song' || type == 'track' || type.contains('musictrack');
        if (isTrack) {
          songs[readableTitle] = (songs[readableTitle] ?? 0) + 1;
        }
        final album = event.album?.trim() ?? '';
        final artist = event.artist?.trim() ?? '';
        // Album plays are attributed only when playback started from that
        // album page. Playlist/queue/track-context plays must not inflate it.
        if (album.isNotEmpty &&
            event.contextType == null &&
            event.action != 'played') {
          albums[album] = (albums[album] ?? 0) + 1;
        }
        if (artist.isNotEmpty && event.entities.isEmpty) {
          artists[artist] = (artists[artist] ?? 0) + 1;
        }
      } else if (type.contains('show') ||
          type.contains('series') ||
          type.contains('episode')) {
        shows++;
        if (type.contains('episode')) {
          episodePlayCounts[readableTitle] =
              (episodePlayCounts[readableTitle] ?? 0) + 1;
        }
      } else if (type.contains('movie') ||
          type.contains('film') ||
          type.contains('documentary') ||
          type.contains('special')) {
        movies++;
        moviePlayCounts[readableTitle] =
            (moviePlayCounts[readableTitle] ?? 0) + 1;
      }

      final countedEntityTargets = <String>{};
      for (final entity in event.entities) {
        final kind = (entity['type'] ?? 'other').trim().toLowerCase();
        final name = (entity['name'] ?? '').trim();
        if (name.isEmpty) continue;
        final target = switch (kind) {
          'playlist' => 'playlist',
          'album' => 'album',
          'collection' || 'franchise' || 'universe' => 'collection',
          'series' || 'show' => 'series',
          'cast' || 'actor' || 'actress' => 'cast',
          'person' => 'person',
          'director' => 'director',
          'writer' || 'composer' => 'writer',
          'company' || 'studio' || 'network' => 'company',
          'country' => 'country',
          'artist' => 'artist',
          'character' => 'character',
          'tag' => 'tag',
          // Genres are counted from event.genres above, exactly once.
          'genre' => '',
          _ => '',
        };
        if (target.isEmpty ||
            !countedEntityTargets.add('$target|${name.toLowerCase()}')) {
          continue;
        }
        switch (target) {
          case 'playlist':
            playlists[name] = (playlists[name] ?? 0) + 1;
            break;
          case 'album':
            albums[name] = (albums[name] ?? 0) + 1;
            break;
          case 'collection':
            collections[name] = (collections[name] ?? 0) + 1;
            break;
          case 'series':
            series[name] = (series[name] ?? 0) + 1;
            break;
          case 'cast':
            cast[name] = (cast[name] ?? 0) + 1;
            break;
          case 'person':
            people[name] = (people[name] ?? 0) + 1;
            break;
          case 'director':
            directors[name] = (directors[name] ?? 0) + 1;
            break;
          case 'writer':
            writers[name] = (writers[name] ?? 0) + 1;
            break;
          case 'company':
            companies[name] = (companies[name] ?? 0) + 1;
            break;
          case 'country':
            countries[name] = (countries[name] ?? 0) + 1;
            break;
          case 'artist':
            artists[name] = (artists[name] ?? 0) + 1;
            break;
          case 'character':
            characters[name] = (characters[name] ?? 0) + 1;
            break;
          case 'tag':
            tags[name] = (tags[name] ?? 0) + 1;
            break;
        }
      }
    }

    List<MapEntry<String, int>> ranked(Map<String, int> values) {
      final list = values.entries.toList()
        ..sort((a, b) {
          final countOrder = b.value.compareTo(a.value);
          return countOrder != 0 ? countOrder : a.key.compareTo(b.key);
        });
      return list.take(topLimit.clamp(1, 1000).toInt()).toList(growable: false);
    }

    final titleRanking = titlePlayCounts.entries.toList()
      ..sort((a, b) {
        final countOrder = b.value.compareTo(a.value);
        return countOrder != 0 ? countOrder : a.key.compareTo(b.key);
      });

    return WrappedPeriodStats(
      playbackCompletions: events.length,
      uniqueTitles: canonicalWorks.length,
      topTitles: titleRanking
          .take((topTitlesLimit ?? topLimit).clamp(1, 1000).toInt())
          .toList(growable: false),
      topMovies: ranked(moviePlayCounts),
      topEpisodes: ranked(episodePlayCounts),
      topGenres: ranked(genres),
      topSongs: ranked(songs),
      topAlbums: ranked(albums),
      topArtists: ranked(artists),
      topPlaylists: ranked(playlists),
      topCollections: ranked(collections),
      topSeries: ranked(series),
      topCast: ranked(cast),
      topPeople: ranked(people),
      topCharacters: ranked(characters),
      topTags: ranked(tags),
      topDirectors: ranked(directors),
      topWriters: ranked(writers),
      topCompanies: ranked(companies),
      topCountries: ranked(countries),
      movieCompletions: movies,
      showCompletions: shows,
      musicCompletions: music,
      activeDays: dayStarts.length,
      busiestDayStarts: dayStarts.values.isEmpty
          ? 0
          : dayStarts.values.reduce((a, b) => a > b ? a : b),
      busiestDay: dayStarts.isEmpty
          ? null
          : dayStarts.entries.reduce((a, b) => a.value >= b.value ? a : b).key,
      averageStartsPerActiveDay:
          dayStarts.isEmpty ? 0 : events.length / dayStarts.length,
      topContexts: ranked(contextStarts),
    );
  }
}

/// Profile-scoped local archive. Closed periods are immutable once saved;
/// the archive is materialized on Wrapped open after a period has ended.
/// A server-backed cross-device archive can be added behind this contract.
class WrappedArchiveStore {
  WrappedArchiveStore._();

  static String eventsKey(String profileId) =>
      'moss_wrapped_activity_$profileId';
  static String snapshotsKey(String scopeId) =>
      'moss_wrapped_snapshots_$scopeId';
  static String auditKey(String profileId) =>
      'moss_wrapped_correction_audit_$profileId';

  static Future<List<Map<String, dynamic>>> loadCorrectionAudit(
      String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(auditKey(profileId));
    if (raw == null) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <Map<String, dynamic>>[];
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  static Future<void> _appendCorrectionAudit({
    required String profileId,
    required String operation,
    required WrappedActivityRecord original,
    WrappedActivityRecord? updated,
    String reason = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await loadCorrectionAudit(profileId);
    entries.add(<String, dynamic>{
      'auditId': '${original.eventId}_${DateTime.now().microsecondsSinceEpoch}',
      'operation': operation,
      'eventId': original.eventId,
      'title': original.title,
      'reason': reason.trim(),
      'before': original.toJson(),
      if (updated != null) 'after': updated.toJson(),
      'changedAt': DateTime.now().toIso8601String(),
    });
    if (entries.length > 1000) entries.removeRange(0, entries.length - 1000);
    await prefs.setString(auditKey(profileId), jsonEncode(entries));
  }

  static Future<bool> replaceEvent({
    required String profileId,
    required WrappedActivityRecord updated,
    String reason = '',
  }) async {
    if (updated.profileId != profileId) return false;
    final events = await loadEvents(profileId);
    final index =
        events.indexWhere((event) => event.eventId == updated.eventId);
    if (index < 0) return false;
    final original = events[index];
    events[index] = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(eventsKey(profileId),
        jsonEncode(events.map((event) => event.toJson()).toList()));
    await _appendCorrectionAudit(
        profileId: profileId,
        operation: 'updated',
        original: original,
        updated: updated,
        reason: reason);
    return true;
  }

  static Future<bool> deleteEvent({
    required String profileId,
    required String eventId,
    String reason = '',
  }) async {
    final events = await loadEvents(profileId);
    final index = events.indexWhere((event) => event.eventId == eventId);
    if (index < 0) return false;
    final original = events.removeAt(index);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(eventsKey(profileId),
        jsonEncode(events.map((event) => event.toJson()).toList()));
    await _appendCorrectionAudit(
        profileId: profileId,
        operation: 'deleted',
        original: original,
        reason: reason);
    return true;
  }

  /// Restores an event removed from Wrapped, using the preserved audit copy.
  /// A restore is itself audited so the correction history remains append-only.
  static Future<bool> restoreDeletedEvent({
    required String profileId,
    required String auditId,
    String reason = 'Restored from correction audit',
  }) async {
    final auditEntries = await loadCorrectionAudit(profileId);
    final auditIndex = auditEntries.indexWhere((entry) =>
        entry['auditId']?.toString() == auditId &&
        entry['operation']?.toString() == 'deleted');
    if (auditIndex < 0) return false;
    final before = auditEntries[auditIndex]['before'];
    if (before is! Map) return false;
    final restored =
        WrappedActivityRecord.fromJson(Map<String, dynamic>.from(before));
    if (restored.profileId != profileId || restored.eventId.isEmpty) {
      return false;
    }
    final events = await loadEvents(profileId);
    if (events.any((event) => event.eventId == restored.eventId)) return false;
    events.add(restored);
    events.sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(eventsKey(profileId),
        jsonEncode(events.map((event) => event.toJson()).toList()));
    await _appendCorrectionAudit(
      profileId: profileId,
      operation: 'restored',
      original: restored,
      updated: restored,
      reason: reason,
    );
    return true;
  }

  static Future<List<WrappedActivityRecord>> loadEvents(
      String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(eventsKey(profileId));
    if (raw == null) return <WrappedActivityRecord>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <WrappedActivityRecord>[];
      return decoded
          .whereType<Map>()
          .map((entry) => WrappedActivityRecord.fromJson(
                Map<String, dynamic>.from(entry),
              ))
          .where(
              (event) => event.profileId.isNotEmpty && event.title.isNotEmpty)
          .toList();
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

  static Future<List<Map<String, dynamic>>> loadSnapshots(
      String scopeId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(snapshotsKey(scopeId));
    if (raw == null) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList();
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
      final id =
          'month_${cursor.year}_${cursor.month.toString().padLeft(2, '0')}';
      final periodEvents = events
          .where((event) =>
              event.occurredAt.year == cursor.year &&
              event.occurredAt.month == cursor.month)
          .toList();
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
      final periodEvents =
          events.where((event) => event.occurredAt.year == year).toList();
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

    snapshots.sort((a, b) => (b['periodKey']?.toString() ?? '')
        .compareTo(a['periodKey']?.toString() ?? ''));
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
    final stats = WrappedPeriodStats.calculate(
      events,
      year: year,
      month: month,
      topLimit: periodType == 'year' ? 50 : 10,
      topTitlesLimit: periodType == 'year' ? 100 : 10,
    );
    return <String, dynamic>{
      'id': id,
      'scopeId': scopeId,
      'periodType': periodType,
      'year': year,
      if (month != null) 'month': month,
      'periodKey':
          month == null ? '$year' : '$year-${month.toString().padLeft(2, '0')}',
      'finalizedAt': finalizedAt.toIso8601String(),
      'playbackCompletions': stats.playbackCompletions,
      'uniqueTitles': stats.uniqueTitles,
      'activeDays': stats.activeDays,
      'busiestDayStarts': stats.busiestDayStarts,
      'busiestDay': stats.busiestDay?.toIso8601String(),
      'averageStartsPerActiveDay': stats.averageStartsPerActiveDay,
      'topTitles': stats.topTitles
          .map((entry) => {'title': entry.key, 'count': entry.value})
          .toList(),
      'topMovies': stats.topMovies
          .map((entry) => {'title': entry.key, 'count': entry.value})
          .toList(),
      'topEpisodes': stats.topEpisodes
          .map((entry) => {'title': entry.key, 'count': entry.value})
          .toList(),
      'topGenres': stats.topGenres
          .map((entry) => {'genre': entry.key, 'count': entry.value})
          .toList(),
      'topSongs': stats.topSongs
          .map((entry) => {'title': entry.key, 'count': entry.value})
          .toList(),
      'topAlbums': stats.topAlbums
          .map((entry) => {'album': entry.key, 'count': entry.value})
          .toList(),
      'topArtists': stats.topArtists
          .map((entry) => {'artist': entry.key, 'count': entry.value})
          .toList(),
      'topPlaylists': stats.topPlaylists
          .map((entry) => {'title': entry.key, 'count': entry.value})
          .toList(),
      'topCollections': stats.topCollections
          .map((entry) => {'title': entry.key, 'count': entry.value})
          .toList(),
      'topSeries': stats.topSeries
          .map((entry) => {'title': entry.key, 'count': entry.value})
          .toList(),
      'topCast': stats.topCast
          .map((entry) => {'title': entry.key, 'count': entry.value})
          .toList(),
      'topPeople': stats.topPeople
          .map((entry) => {'title': entry.key, 'count': entry.value})
          .toList(),
      'topCharacters': stats.topCharacters
          .map((entry) => {'title': entry.key, 'count': entry.value})
          .toList(),
      'topTags': stats.topTags
          .map((entry) => {'title': entry.key, 'count': entry.value})
          .toList(),
      'topDirectors': stats.topDirectors
          .map((entry) => {'title': entry.key, 'count': entry.value})
          .toList(),
      'topWriters': stats.topWriters
          .map((entry) => {'title': entry.key, 'count': entry.value})
          .toList(),
      'topCompanies': stats.topCompanies
          .map((entry) => {'title': entry.key, 'count': entry.value})
          .toList(),
      'topCountries': stats.topCountries
          .map((entry) => {'title': entry.key, 'count': entry.value})
          .toList(),
      'topContexts': stats.topContexts
          .map((entry) => {'title': entry.key, 'count': entry.value})
          .toList(),
      'monthlyArchiveKeys': periodType == 'year'
          ? List<String>.generate(
              12,
              (index) =>
                  'month_${year}_${(index + 1).toString().padLeft(2, '0')}',
            )
          : const <String>[],
    };
  }
}

/// Calendar reveal policy for monthly and yearly Entertainment Wrapped.
/// Monthly Wrapped is visible during the final three days of a month and the
/// first three days of the next month. During days 1-3 it shows the completed
/// previous month. Yearly Wrapped is visible January 1-3 for the completed year.
class EntertainmentWrappedSchedule {
  const EntertainmentWrappedSchedule._();

  static bool isMonthlyRevealDay(DateTime date) {
    final lastDay = DateTime(date.year, date.month + 1, 0).day;
    return date.day <= 3 || date.day >= lastDay - 2;
  }

  static DateTime monthlyPeriodFor(DateTime date) {
    if (date.day <= 3) return DateTime(date.year, date.month - 1, 1);
    return DateTime(date.year, date.month, 1);
  }

  static bool isYearlyRevealDay(DateTime date) =>
      date.month == 1 && date.day <= 3;

  static int yearlyPeriodFor(DateTime date) => date.year - 1;

  static DateTime nextMonthlyReveal(DateTime date) {
    final lastDay = DateTime(date.year, date.month + 1, 0).day;
    if (date.day <= 3) return DateTime(date.year, date.month, 1);
    if (date.day < lastDay - 2) {
      return DateTime(date.year, date.month, lastDay - 2);
    }
    return DateTime(date.year, date.month + 1, 1);
  }
}

class MediaWrappedCollectionsScreen extends StatefulWidget {
  const MediaWrappedCollectionsScreen({super.key});

  @override
  State<MediaWrappedCollectionsScreen> createState() =>
      _MediaWrappedCollectionsScreenState();
}

class _MediaWrappedCollectionsScreenState
    extends State<MediaWrappedCollectionsScreen> {
  bool loading = true;
  bool accountView = false;
  bool _accountSnapshotsPrivacySafe = true;
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
      final activeId = controller.currentProfile?.id ?? '';
      final ids = <String>[];
      var accountSnapshotsPrivacySafe = true;
      for (final profile
          in controller.currentAccount?.profiles ?? <Profile>[]) {
        if (profile.id == activeId) {
          ids.add(profile.id);
          continue;
        }
        final privacy =
            await PrivacyPreferencesStore.load(profileId: profile.id);
        if (privacy.shareActivity) {
          ids.add(profile.id);
        } else {
          accountSnapshotsPrivacySafe = false;
        }
      }
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
        _accountSnapshotsPrivacySafe =
            !accountView || accountSnapshotsPrivacySafe;
        snapshots = accountView && !accountSnapshotsPrivacySafe
            ? <Map<String, dynamic>>[]
            : loadedSnapshots;
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
    final monthlyReveal = EntertainmentWrappedSchedule.isMonthlyRevealDay(now);
    final yearlyReveal = EntertainmentWrappedSchedule.isYearlyRevealDay(now);
    final monthlyPeriod = EntertainmentWrappedSchedule.monthlyPeriodFor(now);
    final monthly = WrappedPeriodStats.calculate(
      events,
      year: monthlyPeriod.year,
      month: monthlyPeriod.month,
      topLimit: 10,
      topTitlesLimit: 10,
    );
    final yearlyPeriod = EntertainmentWrappedSchedule.yearlyPeriodFor(now);
    final yearly = WrappedPeriodStats.calculate(
      events,
      year: yearlyPeriod,
      topLimit: 50,
      topTitlesLimit: 100,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF090909),
      appBar: AppBar(
        title: const UniversalText('My Entertainment Wrapped'),
        backgroundColor: const Color(0xFF090909),
        actions: [
          if (monthlyReveal || yearlyReveal)
            IconButton(
              tooltip: 'Entertainment timeline and corrections',
              onPressed: loading
                  ? null
                  : () async {
                      await Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => const WrappedTimelineAuditScreen()));
                      if (mounted) _load();
                    },
              icon: const Icon(Icons.timeline_rounded),
            ),
          if ((monthlyReveal || yearlyReveal) && _canViewCombinedAccount)
            IconButton(
              tooltip: 'Compare profiles',
              onPressed: loading
                  ? null
                  : () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => const WrappedProfileComparisonScreen())),
              icon: const Icon(Icons.compare_arrows_rounded),
            ),
          if (monthlyReveal || yearlyReveal)
            IconButton(
              tooltip: 'Share Wrapped card',
              onPressed: loading
                  ? null
                  : () => _shareWrappedCard(
                        'Complete Entertainment Wrapped',
                        yearlyReveal ? yearly : monthly,
                        periodLabel: yearlyReveal
                            ? '$yearlyPeriod'
                            : '${_monthName(monthlyPeriod.month)} ${monthlyPeriod.year}',
                      ),
              icon: const Icon(Icons.ios_share_rounded),
            ),
          if (monthlyReveal || yearlyReveal)
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
                  const PopupMenuItem(
                      value: true, child: Text('Combined account')),
              ],
              icon: const Icon(Icons.people_alt_outlined),
            ),
          IconButton(
              onPressed: loading ? null : _load,
              tooltip: 'Refresh archive',
              icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                      accountView
                          ? 'Account Entertainment Wrapped'
                          : 'Entertainment Wrapped',
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text(
                    accountView
                        ? 'A combined recap from profiles belonging to this signed-in account. It remains private until you choose to share it.'
                        : 'Monthly and yearly recaps appear only during their scheduled reveal windows. Playback tracking continues privately between reveals.',
                    style: const TextStyle(color: Colors.white70, height: 1.4),
                  ),
                  if (error != null)
                    Card(
                        child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(error!))),
                  const SizedBox(height: 16),
                  if (monthlyReveal || yearlyReveal) ...[
                    _wrappedToolsRow(
                      monthly,
                      yearly,
                      yearlyReveal: yearlyReveal,
                      periodLabel: yearlyReveal
                          ? '$yearlyPeriod'
                          : '${_monthName(monthlyPeriod.month)} ${monthlyPeriod.year}',
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (monthlyReveal) ...[
                    _wrappedPeriodCard(
                      '${_monthName(monthlyPeriod.month)} Top 10 · ${monthlyPeriod.year}${now.day > 3 ? ' (month to date)' : ''}',
                      monthly,
                      year: monthlyPeriod.year,
                      month: monthlyPeriod.month,
                    ),
                    const SizedBox(height: 12),
                  ] else
                    _wrappedScheduleNotice(
                      title: 'Monthly Wrapped is between reveals',
                      message:
                          'Your next monthly Top 10 opens ${_monthName(EntertainmentWrappedSchedule.nextMonthlyReveal(now).month)} ${EntertainmentWrappedSchedule.nextMonthlyReveal(now).day}. Your listening and viewing history continues to be recorded in the background.',
                    ),
                  if (yearlyReveal) ...[
                    const SizedBox(height: 12),
                    _wrappedPeriodCard(
                      '$yearlyPeriod Yearly Wrapped · Top 100 overall / Top 50 per category',
                      yearly,
                      year: yearlyPeriod,
                    ),
                  ] else if (now.month == 12 && now.day >= 29)
                    _wrappedScheduleNotice(
                      title: 'Yearly Wrapped opens soon',
                      message:
                          'Your completed ${now.year} Yearly Wrapped will open January 1–3, ${now.year + 1}.',
                    ),
                  if (monthlyReveal || yearlyReveal) ...[
                    const SizedBox(height: 22),
                    const Text('Wrapped Collections',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900)),
                    if (accountView && !_accountSnapshotsPrivacySafe)
                      const Card(
                          child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Text(
                                  'Archived account cards are hidden because one or more profiles no longer share activity. This protects older snapshots that do not store per-profile privacy breakdowns.'))),
                    const SizedBox(height: 6),
                    const Text(
                        'Closed months and years are archived the next time this screen opens after their period ends. Existing snapshots are not silently rewritten.',
                        style: TextStyle(color: Colors.white60)),
                    const SizedBox(height: 12),
                    if (snapshots.isEmpty)
                      const Card(
                          child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                  'No closed periods have activity to archive yet.'))),
                    for (final snapshot in snapshots) _snapshotCard(snapshot),
                    const SizedBox(height: 10),
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(14),
                        child: Text(
                            'Data note: play counts are based on playback-start events recorded by this app. Profile history is combined only when that profile shares activity. Watch-time minutes are omitted unless a reliable duration record exists. Local event journals remain device-local.',
                            style:
                                TextStyle(color: Colors.white60, height: 1.4)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _wrappedToolsRow(
    WrappedPeriodStats monthly,
    WrappedPeriodStats yearly, {
    required bool yearlyReveal,
    required String periodLabel,
  }) {
    final activeStats = yearlyReveal ? yearly : monthly;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const WrappedTimelineAuditScreen())),
          icon: const Icon(Icons.timeline_rounded),
          label: const Text('Timeline & audit'),
        ),
        if (_canViewCombinedAccount)
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const WrappedProfileComparisonScreen())),
            icon: const Icon(Icons.compare_arrows_rounded),
            label: const Text('Compare profiles'),
          ),
        OutlinedButton.icon(
          onPressed: () => _shareWrappedCard('Movie Wrapped', activeStats,
              ranking: 'movies', periodLabel: periodLabel),
          icon: const Icon(Icons.movie_outlined),
          label: const Text('Share movie card'),
        ),
        OutlinedButton.icon(
          onPressed: () => _shareWrappedCard('TV Wrapped', activeStats,
              ranking: 'shows', periodLabel: periodLabel),
          icon: const Icon(Icons.tv_rounded),
          label: const Text('Share TV card'),
        ),
        OutlinedButton.icon(
          onPressed: () => _shareWrappedCard('Music Wrapped', activeStats,
              ranking: 'music', periodLabel: periodLabel),
          icon: const Icon(Icons.music_note_rounded),
          label: const Text('Share music card'),
        ),
      ],
    );
  }

  Future<void> _shareWrappedCard(
    String title,
    WrappedPeriodStats stats, {
    String ranking = 'all',
    String? periodLabel,
  }) async {
    final profileName =
        accountView ? 'My Account' : (_activeProfile?.name ?? 'My Profile');
    final selections = switch (ranking) {
      'movies' => stats.topMovies,
      'shows' =>
        stats.topSeries.isNotEmpty ? stats.topSeries : stats.topEpisodes,
      'music' => stats.topSongs,
      _ => stats.topTitles,
    };
    final highlights = selections
        .take(5)
        .map((item) => '${item.key} · ${item.value}')
        .toList();
    final metrics = <String>[
      '${stats.playbackCompletions} playback starts',
      '${stats.uniqueTitles} distinct works',
      '${stats.activeDays} active days',
      '${stats.movieCompletions} movies · ${stats.showCompletions} TV · ${stats.musicCompletions} music',
    ];
    try {
      final bytes = await WrappedShareCardRenderer.render(
        title: title,
        profileName: profileName,
        subtitle: 'Entertainment Wrapped ${periodLabel ?? DateTime.now().year}',
        metrics: metrics,
        highlights: highlights.isEmpty
            ? const ['Your entertainment story is just beginning.']
            : highlights,
      );
      await SharePlus.instance.share(ShareParams(
        title: title,
        text: '$title · $profileName',
        files: <XFile>[
          XFile.fromData(Uint8List.fromList(bytes), mimeType: 'image/png')
        ],
        fileNameOverrides: const <String>['entertainment-wrapped.png'],
      ));
    } catch (exception) {
      try {
        await SharePlus.instance.share(ShareParams(
          title: title,
          text: <String>[
            title,
            profileName,
            ...metrics,
            'Highlights:',
            ...highlights
          ].join('\n'),
        ));
      } catch (fallbackError) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Could not share Wrapped card: $fallbackError')));
      }
    }
  }

  Widget _wrappedPeriodCard(
    String title,
    WrappedPeriodStats stats, {
    required int year,
    int? month,
  }) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 10, children: [
              _wrappedMetric(
                  'Playback starts',
                  stats.playbackCompletions.toString(),
                  Icons.play_circle_outline),
              _wrappedMetric('Distinct works', stats.uniqueTitles.toString(),
                  Icons.movie_outlined),
              _wrappedMetric('Movies', stats.movieCompletions.toString(),
                  Icons.local_movies_outlined),
              _wrappedMetric('TV', stats.showCompletions.toString(),
                  Icons.live_tv_outlined),
              _wrappedMetric('Music', stats.musicCompletions.toString(),
                  Icons.music_note_rounded),
              _wrappedMetric('Active days', stats.activeDays.toString(),
                  Icons.calendar_today_rounded),
              _wrappedMetric(
                  'Avg. starts / active day',
                  stats.averageStartsPerActiveDay.toStringAsFixed(1),
                  Icons.insights_rounded),
              _wrappedMetric(
                  'Busiest day starts',
                  stats.busiestDayStarts.toString(),
                  Icons.local_fire_department_rounded),
            ]),
            if (stats.busiestDay != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Busiest day: ${MaterialLocalizations.of(context).formatMediumDate(stats.busiestDay!)}',
                  style: const TextStyle(color: Colors.white60),
                ),
              ),
            if (stats.topTitles.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Most played works',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              for (var index = 0; index < stats.topTitles.length; index++)
                _wrappedRankTile(
                  item: stats.topTitles[index].key,
                  count: stats.topTitles[index].value,
                  countLabel: _itemCountLabelForPeriod(
                      stats.topTitles[index].key, year, month),
                  matchKind: 'title',
                  rank: index + 1,
                  year: year,
                  month: month,
                ),
            ],
            _wrappedRanking('Top genres', stats.topGenres,
                matchKind: 'genre',
                countLabel: 'plays attributed',
                year: year,
                month: month),
            _wrappedRanking('Top movies', stats.topMovies,
                matchKind: 'movie',
                countLabel: 'times watched',
                year: year,
                month: month),
            _wrappedRanking('Top episodes', stats.topEpisodes,
                matchKind: 'episode',
                countLabel: 'times watched',
                year: year,
                month: month),
            _wrappedRanking('Top songs', stats.topSongs,
                matchKind: 'song',
                countLabel: 'times listened to',
                year: year,
                month: month),
            _wrappedRanking('Top albums', stats.topAlbums,
                matchKind: 'album',
                countLabel: 'times listened to',
                year: year,
                month: month),
            _wrappedRanking('Top artists', stats.topArtists,
                matchKind: 'artist',
                countLabel: 'times listened to',
                year: year,
                month: month),
            _wrappedRanking('Top playlists', stats.topPlaylists,
                matchKind: 'playlist',
                countLabel: 'times listened to',
                year: year,
                month: month),
            _wrappedRanking(
                'Top collections / franchises', stats.topCollections,
                matchKind: 'collection',
                countLabel: 'times watched',
                year: year,
                month: month),
            _wrappedRanking('Top shows / series', stats.topSeries,
                matchKind: 'series',
                countLabel: 'times watched',
                year: year,
                month: month),
            _wrappedRanking('Top actors & actresses', stats.topCast,
                matchKind: 'cast',
                countLabel: 'times watched',
                year: year,
                month: month),
            _wrappedRanking('Top other credited people', stats.topPeople,
                matchKind: 'person',
                countLabel: 'times watched',
                year: year,
                month: month),
            _wrappedRanking('Top characters', stats.topCharacters,
                matchKind: 'character',
                countLabel: 'times watched',
                year: year,
                month: month),
            _wrappedRanking('Top tags / themes', stats.topTags,
                matchKind: 'tag',
                countLabel: 'times watched',
                year: year,
                month: month),
            _wrappedRanking('Top directors', stats.topDirectors,
                matchKind: 'director',
                countLabel: 'times watched',
                year: year,
                month: month),
            _wrappedRanking('Top writers / composers', stats.topWriters,
                matchKind: 'writer',
                countLabel: 'times watched / listened to',
                year: year,
                month: month),
            _wrappedRanking('Top companies / studios', stats.topCompanies,
                matchKind: 'company',
                countLabel: 'times watched',
                year: year,
                month: month),
            _wrappedRanking('Top production countries', stats.topCountries,
                matchKind: 'country',
                countLabel: 'times watched',
                year: year,
                month: month),
            _wrappedRanking('Top playback sources', stats.topContexts,
                matchKind: 'context',
                countLabel: 'play starts',
                year: year,
                month: month),
          ]),
        ),
      );

  Widget _wrappedRanking(
    String title,
    List<MapEntry<String, int>> items, {
    required String matchKind,
    required int year,
    int? month,
    String countLabel = 'plays',
  }) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          for (var index = 0; index < items.length; index++)
            _wrappedRankTile(
              item: items[index].key,
              count: items[index].value,
              countLabel: countLabel,
              matchKind: matchKind,
              rank: index + 1,
              year: year,
              month: month,
            ),
        ],
      ),
    );
  }

  Widget _wrappedRankTile({
    required String item,
    required int count,
    required String countLabel,
    required String matchKind,
    required int rank,
    required int year,
    int? month,
  }) {
    final attributions = buildWrappedProfileAttributions(
      events,
      itemName: item,
      matchKind: matchKind,
      year: year,
      month: month,
    );
    final tooltipLines = attributions.take(8).map(_attributionSummary).toList();
    final remaining = attributions.length - tooltipLines.length;
    final tooltipMessage = attributions.isEmpty
        ? 'No profile-level title detail is available for this entry.'
        : '${tooltipLines.join('\n')}${remaining > 0 ? '\n+$remaining more · tap to view all' : '\nTap to view details'}';

    return Tooltip(
      message: tooltipMessage,
      waitDuration: const Duration(milliseconds: 350),
      showDuration: const Duration(seconds: 8),
      child: ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
            radius: 13,
            child: Text('$rank', style: const TextStyle(fontSize: 11))),
        title: Text(item),
        subtitle: Text(
          attributions.isEmpty
              ? '$countLabel: $count'
              : '$countLabel: $count · ${attributions.length} profile/title detail${attributions.length == 1 ? '' : 's'}',
        ),
        trailing: attributions.isEmpty
            ? null
            : const Icon(Icons.groups_2_outlined,
                size: 19, color: Colors.white70),
        onTap: attributions.isEmpty
            ? null
            : () => _showWrappedAttributions(item, attributions),
      ),
    );
  }

  String _attributionProfileName(String profileId) {
    if (!accountView) return 'You';
    for (final profile
        in AppController.instance.currentAccount?.profiles ?? <Profile>[]) {
      if (profile.id == profileId) {
        return profile.name.trim().isEmpty ? 'Profile' : profile.name;
      }
    }
    // Never expose an internal profile ID in the Wrapped presentation.
    return 'Shared profile';
  }

  String _attributionSummary(WrappedProfileAttribution attribution) {
    final profileName = _attributionProfileName(attribution.profileId);
    final verb = attribution.isMusic ? 'listened to' : 'watched';
    final repeats =
        attribution.playCount > 1 ? ' (${attribution.playCount} plays)' : '';
    final source = attribution.sourceTitle?.trim().isNotEmpty == true
        ? ' · ${attribution.sourceType ?? 'source'}: ${attribution.sourceTitle}'
        : '';
    return '$profileName $verb ${attribution.mediaTitle}$repeats$source';
  }

  void _showWrappedAttributions(
    String rankingItem,
    List<WrappedProfileAttribution> attributions,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$rankingItem · profile activity'),
        content: SizedBox(
          width: 440,
          height: math.min(440.0, 96.0 + attributions.length * 66.0),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: attributions.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final attribution = attributions[index];
              final verb = attribution.isMusic ? 'listened to' : 'watched';
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                    child: Text(_attributionProfileName(attribution.profileId)
                        .characters
                        .first
                        .toUpperCase())),
                title: Text(_attributionProfileName(attribution.profileId)),
                subtitle: Text(
                  '${attribution.mediaTitle} · $verb${attribution.sourceTitle?.trim().isNotEmpty == true ? '\n${attribution.sourceLabel}' : ''}',
                ),
                trailing: attribution.playCount > 1
                    ? Text('×${attribution.playCount}')
                    : null,
              );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'))
        ],
      ),
    );
  }

  String _itemCountLabelForPeriod(String title, int year, int? month) {
    final matching = events.where((event) =>
        !event.excludedFromWrapped &&
        event.action.toLowerCase() != 'excluded' &&
        event.title.trim().toLowerCase() == title.trim().toLowerCase() &&
        event.occurredAt.year == year &&
        (month == null || event.occurredAt.month == month));
    final isMusic = matching.any((event) {
      final type = event.type.toLowerCase().replaceAll(RegExp(r'[_\-\s]'), '');
      return type.contains('music') ||
          type == 'song' ||
          type == 'track' ||
          type == 'album';
    });
    return isMusic ? 'Times listened to' : 'Times watched';
  }

  Widget _wrappedScheduleNotice(
          {required String title, required String message}) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.event_available_rounded, color: Colors.white70),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  Text(message,
                      style:
                          const TextStyle(color: Colors.white60, height: 1.4)),
                ])),
          ]),
        ),
      );

  Widget _wrappedMetric(String label, String value, IconData icon) => Container(
        width: 140,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .05),
            borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: Colors.white70),
          const SizedBox(height: 7),
          Text(value,
              style:
                  const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ]),
      );

  Widget _snapshotCard(Map<String, dynamic> snapshot) {
    final isYear = snapshot['periodType'] == 'year';
    final year = snapshot['year']?.toString() ?? '';
    final month = (snapshot['month'] as num?)?.toInt();
    final label = isYear
        ? '$year Wrapped Collection'
        : '${month == null ? '' : _monthName(month)} $year Wrapped Collection';
    final monthKeys = snapshot['monthlyArchiveKeys'] is List
        ? (snapshot['monthlyArchiveKeys'] as List)
            .map((value) => value.toString())
            .toSet()
        : <String>{};
    final linkedMonths = snapshots
        .where((item) => monthKeys.contains(item['id']?.toString()))
        .toList()
      ..sort((a, b) => ((a['month'] as num?)?.toInt() ?? 0)
          .compareTo((b['month'] as num?)?.toInt() ?? 0));
    return Card(
      child: ExpansionTile(
        leading: Icon(
            isYear ? Icons.auto_graph_rounded : Icons.calendar_month_rounded),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
            '${snapshot['playbackCompletions'] ?? 0} plays · ${snapshot['uniqueTitles'] ?? 0} distinct works'),
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
            (label: 'Top movies', key: 'topMovies'),
            (label: 'Top episodes', key: 'topEpisodes'),
            (label: 'Top songs', key: 'topSongs'),
            (label: 'Top albums played from album pages', key: 'topAlbums'),
            (label: 'Top artists', key: 'topArtists'),
            (label: 'Top playlists', key: 'topPlaylists'),
            (label: 'Top collections / franchises', key: 'topCollections'),
            (label: 'Top shows / series', key: 'topSeries'),
            (label: 'Top actors & actresses', key: 'topCast'),
            (label: 'Top other credited people', key: 'topPeople'),
            (label: 'Top directors', key: 'topDirectors'),
            (label: 'Top writers / composers', key: 'topWriters'),
            (label: 'Top companies / studios', key: 'topCompanies'),
            (label: 'Top production countries', key: 'topCountries'),
            (label: 'Top playback sources', key: 'topContexts'),
            (label: 'Top characters', key: 'topCharacters'),
            (label: 'Top tags / themes', key: 'topTags'),
          ])
            if (snapshot[bucket.key] is List &&
                (snapshot[bucket.key] as List).isNotEmpty) ...[
              Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(bucket.label,
                          style:
                              const TextStyle(fontWeight: FontWeight.w800)))),
              for (final raw in (snapshot[bucket.key] as List).whereType<Map>())
                ListTile(
                    dense: true,
                    title: Text((raw['title'] ??
                            raw['album'] ??
                            raw['artist'] ??
                            'Unknown')
                        .toString()),
                    trailing: Text('${raw['count'] ?? 0}')),
            ],
          if (isYear) ...[
            const Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text('Monthly Wrapped Collections',
                        style: TextStyle(fontWeight: FontWeight.w800)))),
            for (final monthly in linkedMonths)
              ExpansionTile(
                leading: const Icon(Icons.calendar_month_rounded),
                title: Text(
                    '${_monthName((monthly['month'] as num?)?.toInt() ?? 1)} ${monthly['year'] ?? ''}'),
                subtitle: Text(
                    '${monthly['playbackCompletions'] ?? 0} plays · ${monthly['uniqueTitles'] ?? 0} distinct works'),
                children: [
                  if (monthly['topTitles'] is List)
                    for (final raw
                        in (monthly['topTitles'] as List).whereType<Map>())
                      ListTile(
                          dense: true,
                          title:
                              Text(raw['title']?.toString() ?? 'Unknown title'),
                          trailing: Text('${raw['count'] ?? 0}')),
                ],
              ),
          ],
          Text('Finalized ${snapshot['finalizedAt']?.toString() ?? ''}',
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }

  String _monthName(int month) => const <String>[
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ][month - 1];
}

/// Chronological playback journal with attribution correction and an audit trail.
class WrappedTimelineAuditScreen extends StatefulWidget {
  const WrappedTimelineAuditScreen({super.key});

  @override
  State<WrappedTimelineAuditScreen> createState() =>
      _WrappedTimelineAuditScreenState();
}

class _WrappedTimelineAuditScreenState extends State<WrappedTimelineAuditScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final TextEditingController _search = TextEditingController();
  List<WrappedActivityRecord> _events = const <WrappedActivityRecord>[];
  List<Map<String, dynamic>> _audit = const <Map<String, dynamic>>[];
  bool _loading = true;
  bool _accountView = false;
  String _filter = 'all';
  String _periodFilter = 'all';
  DateTimeRange? _customRange;
  String? _error;

  String get _profileId => AppController.instance.currentProfile?.id ?? '';
  bool get _canViewAccount {
    final profile = AppController.instance.currentProfile;
    if (profile == null || !profile.governance.isOwnerManaged) return false;
    return profile.governance.contentLevel == ProfileContentLevel.mature ||
        profile.governance.contentLevel == ProfileContentLevel.unrestricted;
  }

  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final controller = AppController.instance;
      final ids = <String>[];
      for (final profile
          in controller.currentAccount?.profiles ?? <Profile>[]) {
        if (!_accountView || profile.id == _profileId) {
          ids.add(profile.id);
          continue;
        }
        final privacy =
            await PrivacyPreferencesStore.load(profileId: profile.id);
        if (privacy.shareActivity) ids.add(profile.id);
      }
      final events = _accountView && _canViewAccount
          ? await WrappedArchiveStore.loadScopeEvents(
              scopeId: 'account_${controller.currentAccount?.id ?? ''}',
              profileIds: ids)
          : await WrappedArchiveStore.loadEvents(_profileId);
      final audit = await WrappedArchiveStore.loadCorrectionAudit(_profileId);
      if (!mounted) return;
      setState(() {
        _events = events..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
        _audit = audit.reversed.toList(growable: false);
        _loading = false;
        _error = null;
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        _error = exception.toString();
        _loading = false;
      });
    }
  }

  List<WrappedActivityRecord> get _visibleEvents {
    final query = _search.text.trim().toLowerCase();
    final now = DateTime.now();
    return _events.where((event) {
      final type = event.type.toLowerCase();
      final isMusic = type.contains('song') ||
          type.contains('track') ||
          type.contains('music') ||
          type.contains('album');
      final isVideo = type.contains('movie') ||
          type.contains('film') ||
          type.contains('show') ||
          type.contains('series') ||
          type.contains('episode');
      if (_filter == 'music' && !isMusic) return false;
      if (_filter == 'video' && !isVideo) return false;
      if (_filter == 'excluded' && !event.excludedFromWrapped) return false;
      if (_filter == 'included' && event.excludedFromWrapped) return false;
      final localDate = event.occurredAt.toLocal();
      switch (_periodFilter) {
        case '7days':
          if (localDate.isBefore(now.subtract(const Duration(days: 7)))) {
            return false;
          }
          break;
        case '30days':
          if (localDate.isBefore(now.subtract(const Duration(days: 30)))) {
            return false;
          }
          break;
        case 'month':
          if (localDate.year != now.year || localDate.month != now.month) {
            return false;
          }
          break;
        case 'year':
          if (localDate.year != now.year) return false;
          break;
        case 'custom':
          final range = _customRange;
          if (range == null) return false;
          final start =
              DateTime(range.start.year, range.start.month, range.start.day);
          final endExclusive =
              DateTime(range.end.year, range.end.month, range.end.day)
                  .add(const Duration(days: 1));
          if (localDate.isBefore(start) || !localDate.isBefore(endExclusive)) {
            return false;
          }
          break;
      }
      if (query.isEmpty) return true;
      return <String>[
        event.title,
        event.artist ?? '',
        event.album ?? '',
        event.contextTitle ?? '',
        ...event.genres,
        ...event.entities.map((item) => item['name'] ?? '')
      ].join(' ').toLowerCase().contains(query);
    }).toList(growable: false);
  }

  String _profileName(String id) {
    for (final profile
        in AppController.instance.currentAccount?.profiles ?? <Profile>[]) {
      if (profile.id == id) return profile.name;
    }
    return 'Profile';
  }

  String _sourceLabel(WrappedActivityRecord event) {
    if (event.contextTitle?.trim().isNotEmpty == true) {
      return 'Started from ${event.contextType ?? 'collection'} · ${event.contextTitle}';
    }
    return 'Direct playback';
  }

  Future<void> _chooseCustomRange() async {
    final now = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _customRange ??
          DateTimeRange(
            start: DateTime(now.year, now.month, 1),
            end: DateTime(now.year, now.month, now.day),
          ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _customRange = selected;
      _periodFilter = 'custom';
    });
  }

  Future<void> _exportTimelineCsv() async {
    String cell(Object? value) {
      final text = value?.toString() ?? '';
      final escaped = text.replaceAll('"', '""');
      return '"$escaped"';
    }

    final rows = <String>[
      <String>[
        'occurred_at',
        'profile_id',
        'title',
        'type',
        'artist',
        'album',
        'source_type',
        'source_title',
        'genres',
        'entities',
        'excluded_from_wrapped'
      ].map(cell).join(','),
      for (final event in _visibleEvents)
        <Object?>[
          event.occurredAt.toIso8601String(),
          event.profileId,
          event.title,
          event.type,
          event.artist,
          event.album,
          event.contextType,
          event.contextTitle,
          event.genres.join('; '),
          event.entities
              .map((entity) => '${entity['type']}: ${entity['name']}')
              .join('; '),
          event.excludedFromWrapped,
        ].map(cell).join(','),
    ];
    try {
      await SharePlus.instance.share(ShareParams(
        title: 'Entertainment Timeline',
        text: 'Exported ${_visibleEvents.length} filtered playback events.',
        files: <XFile>[
          XFile.fromData(Uint8List.fromList(utf8.encode(rows.join('\r\n'))),
              mimeType: 'text/csv'),
        ],
        fileNameOverrides: const <String>['entertainment-timeline.csv'],
      ));
    } catch (exception) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export timeline: $exception')));
    }
  }

  Future<void> _restoreDeletedEvent(Map<String, dynamic> entry) async {
    final auditId = entry['auditId']?.toString() ?? '';
    if (auditId.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore deleted playback event?'),
        content: Text(
            'Restore “${entry['title'] ?? 'Playback event'}” from the preserved audit copy?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Restore event')),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await WrappedArchiveStore.restoreDeletedEvent(
      profileId: _profileId,
      auditId: auditId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Playback event restored.'
          : 'This event could not be restored or is already present.'),
    ));
    await _load();
  }

  Future<void> _editAttribution(WrappedActivityRecord event) async {
    if (event.profileId != _profileId) return;
    const options = <String, String>{
      '': 'Direct playback (no container)',
      'album': 'Album',
      'playlist': 'Playlist',
      'collection': 'Collection',
      'franchise': 'Franchise',
      'universe': 'Cinematic universe',
      'series': 'Series',
      'genre': 'Genre',
      'cast': 'Actor / actress',
      'director': 'Director',
      'writer': 'Writer',
      'company': 'Company / studio',
      'country': 'Country',
      'artist': 'Artist',
    };
    var selectedType = options.containsKey(event.contextType ?? '')
        ? (event.contextType ?? '')
        : '';
    final name = TextEditingController(text: event.contextTitle ?? '');
    final reason = TextEditingController();
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
                title: const Text('Correct playback attribution'),
                content: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text(
                      'Change where this play was started. This updates Wrapped counts and records the correction in the audit log.'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    decoration:
                        const InputDecoration(labelText: 'Playback source'),
                    items: options.entries
                        .map((entry) => DropdownMenuItem(
                            value: entry.key, child: Text(entry.value)))
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => selectedType = value ?? ''),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                      controller: name,
                      decoration:
                          const InputDecoration(labelText: 'Source name')),
                  const SizedBox(height: 10),
                  TextField(
                      controller: reason,
                      decoration: const InputDecoration(
                          labelText: 'Why are you correcting this? (optional)'),
                      maxLines: 2),
                ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Save correction')),
                ],
              )),
    );
    if (save != true || !mounted) {
      name.dispose();
      reason.dispose();
      return;
    }
    final sourceName = name.text.trim();
    final nextType =
        selectedType.isEmpty || sourceName.isEmpty ? null : selectedType;
    final nextName = nextType == null ? null : sourceName;
    String normalizeEntityType(String? value) =>
        switch ((value ?? '').toLowerCase()) {
          'show' => 'series',
          'actor' || 'actress' => 'cast',
          'studio' || 'network' => 'company',
          _ => (value ?? '').toLowerCase(),
        };
    final oldKind = normalizeEntityType(event.contextType);
    final retained = event.entities.where((entity) {
      final sameKind = (entity['type'] ?? '').toLowerCase() == oldKind;
      final sameName = (entity['name'] ?? '').toLowerCase() ==
          (event.contextTitle ?? '').toLowerCase();
      return !(oldKind.isNotEmpty && sameKind && sameName);
    }).toList();
    if (nextType != null && nextName != null) {
      retained.add(<String, String>{
        'type': normalizeEntityType(nextType),
        'id': nextName,
        'name': nextName
      });
    }
    final updated = event.copyWith(
      contextType: nextType,
      contextId: nextType == null ? null : nextName,
      contextTitle: nextName,
      entities: retained,
      clearContext: nextType == null,
    );
    final ok = await WrappedArchiveStore.replaceEvent(
        profileId: _profileId, updated: updated, reason: reason.text);
    name.dispose();
    reason.dispose();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? 'Attribution corrected.'
            : 'This playback event could not be found.')));
    await _load();
  }

  Future<void> _toggleExcluded(WrappedActivityRecord event) async {
    if (event.profileId != _profileId) return;
    final updated =
        event.copyWith(excludedFromWrapped: !event.excludedFromWrapped);
    final ok = await WrappedArchiveStore.replaceEvent(
      profileId: _profileId,
      updated: updated,
      reason: updated.excludedFromWrapped
          ? 'Excluded from Wrapped by user'
          : 'Restored to Wrapped by user',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? (updated.excludedFromWrapped
                ? 'Excluded from Wrapped.'
                : 'Restored to Wrapped.')
            : 'Could not update this event.')));
    await _load();
  }

  Future<void> _deleteEvent(WrappedActivityRecord event) async {
    if (event.profileId != _profileId) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete playback event?'),
        content: Text(
            'Remove “${event.title}” from this profile’s local Wrapped history? A correction audit entry will be retained.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete event'))
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await WrappedArchiveStore.deleteEvent(
        profileId: _profileId,
        eventId: event.eventId,
        reason: 'Deleted by profile owner');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? 'Playback event deleted.'
            : 'Could not delete playback event.')));
    await _load();
  }

  Widget _auditCard(Map<String, dynamic> entry) {
    final before = entry['before'] is Map
        ? Map<String, dynamic>.from(entry['before'] as Map)
        : <String, dynamic>{};
    final after = entry['after'] is Map
        ? Map<String, dynamic>.from(entry['after'] as Map)
        : <String, dynamic>{};
    String source(Map<String, dynamic> value) {
      final type = value['contextType']?.toString();
      final title = value['contextTitle']?.toString();
      if (title == null || title.trim().isEmpty) return 'Direct playback';
      return '${type ?? 'source'} · $title';
    }

    final operation = entry['operation']?.toString() ?? 'updated';
    final detail = switch (operation) {
      'deleted' => 'Removed event. Previous source: ${source(before)}',
      'restored' =>
        'Restored the previously deleted playback event. Source: ${source(after)}',
      _ => 'From ${source(before)} → ${source(after)}',
    };
    return Card(
        child: ListTile(
      leading: Icon(operation == 'deleted'
          ? Icons.delete_outline
          : operation == 'restored'
              ? Icons.restore_rounded
              : Icons.edit_outlined),
      title: Text('$operation · ${entry['title'] ?? 'Playback event'}'),
      subtitle: Text(
          '$detail\n${entry['changedAt'] ?? ''}\n${entry['reason'] ?? ''}'),
      isThreeLine: true,
      trailing: operation == 'deleted'
          ? IconButton(
              tooltip: 'Restore this event',
              icon: const Icon(Icons.restore_rounded),
              onPressed: () => _restoreDeletedEvent(entry),
            )
          : null,
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Entertainment Timeline & Audit'),
          actions: [
            if (_canViewAccount)
              PopupMenuButton<bool>(
                initialValue: _accountView,
                onSelected: (value) {
                  setState(() => _accountView = value);
                  _load();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: false, child: Text('This profile')),
                  PopupMenuItem(
                      value: true, child: Text('Shared account activity'))
                ],
                icon: const Icon(Icons.people_alt_outlined),
              ),
            IconButton(
                onPressed: _loading ? null : _exportTimelineCsv,
                tooltip: 'Export filtered timeline as CSV',
                icon: const Icon(Icons.file_download_outlined)),
            IconButton(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh_rounded)),
          ],
          bottom: TabBar(controller: _tabs, tabs: const [
            Tab(text: 'Timeline'),
            Tab(text: 'Correction audit')
          ]),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(controller: _tabs, children: [
                Column(children: [
                  Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(children: [
                        TextField(
                            controller: _search,
                            decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.search),
                                hintText:
                                    'Search titles, people, albums or sources')),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                              child: DropdownButtonFormField<String>(
                            initialValue: _periodFilter,
                            decoration: const InputDecoration(
                                labelText: 'Date range', isDense: true),
                            items: const <DropdownMenuItem<String>>[
                              DropdownMenuItem(
                                  value: 'all', child: Text('All time')),
                              DropdownMenuItem(
                                  value: '7days', child: Text('Last 7 days')),
                              DropdownMenuItem(
                                  value: '30days', child: Text('Last 30 days')),
                              DropdownMenuItem(
                                  value: 'month', child: Text('This month')),
                              DropdownMenuItem(
                                  value: 'year', child: Text('This year')),
                              DropdownMenuItem(
                                  value: 'custom', child: Text('Custom range')),
                            ],
                            onChanged: (value) {
                              if (value == 'custom') {
                                _chooseCustomRange();
                              } else {
                                setState(() => _periodFilter = value ?? 'all');
                              }
                            },
                          )),
                          const SizedBox(width: 8),
                          IconButton(
                              onPressed: _chooseCustomRange,
                              tooltip: 'Choose custom date range',
                              icon: const Icon(Icons.date_range_rounded)),
                        ]),
                        if (_periodFilter == 'custom' && _customRange != null)
                          Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                  '${MaterialLocalizations.of(context).formatMediumDate(_customRange!.start)} – ${MaterialLocalizations.of(context).formatMediumDate(_customRange!.end)}',
                                  style: const TextStyle(
                                      color: Colors.white60, fontSize: 12))),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(children: [
                              for (final entry in const <(String, String)>[
                                ('all', 'All'),
                                ('video', 'Movies & TV'),
                                ('music', 'Music'),
                                ('included', 'Included'),
                                ('excluded', 'Excluded')
                              ])
                                Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: ChoiceChip(
                                        label: Text(entry.$2),
                                        selected: _filter == entry.$1,
                                        onSelected: (_) => setState(
                                            () => _filter = entry.$1))),
                            ])),
                        Align(
                            alignment: Alignment.centerLeft,
                            child: Text(_accountView
                                ? 'Other profiles appear only when they share activity. You can correct or delete only your own events.'
                                : 'Playback starts are shown in newest-first order.')),
                      ])),
                  if (_error != null)
                    Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(_error!)),
                  Expanded(
                      child: _visibleEvents.isEmpty
                          ? const Center(
                              child:
                                  Text('No playback events match this view.'))
                          : ListView.builder(
                              itemCount: _visibleEvents.length,
                              itemBuilder: (context, index) {
                                final event = _visibleEvents[index];
                                final ownEvent = event.profileId == _profileId;
                                final isMusic = event.type
                                        .toLowerCase()
                                        .contains('song') ||
                                    event.type
                                        .toLowerCase()
                                        .contains('track') ||
                                    event.type.toLowerCase().contains('music');
                                return Card(
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 4),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                          child: Icon(isMusic
                                              ? Icons.music_note_rounded
                                              : Icons
                                                  .play_circle_outline_rounded)),
                                      title: Text(event.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                      subtitle: Text(
                                          '${event.type} · ${_sourceLabel(event)}\n${_profileName(event.profileId)} · ${MaterialLocalizations.of(context).formatMediumDate(event.occurredAt.toLocal())} ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(event.occurredAt.toLocal()))}${event.excludedFromWrapped ? ' · Excluded from Wrapped' : ''}'),
                                      isThreeLine: true,
                                      trailing: ownEvent
                                          ? PopupMenuButton<String>(
                                              onSelected: (choice) {
                                                if (choice == 'edit') {
                                                  _editAttribution(event);
                                                }
                                                if (choice == 'exclude') {
                                                  _toggleExcluded(event);
                                                }
                                                if (choice == 'delete') {
                                                  _deleteEvent(event);
                                                }
                                              },
                                              itemBuilder: (_) => [
                                                const PopupMenuItem(
                                                    value: 'edit',
                                                    child: Text(
                                                        'Correct playback source')),
                                                PopupMenuItem(
                                                    value: 'exclude',
                                                    child: Text(event
                                                            .excludedFromWrapped
                                                        ? 'Restore to Wrapped'
                                                        : 'Exclude from Wrapped')),
                                                const PopupMenuItem(
                                                    value: 'delete',
                                                    child: Text(
                                                        'Delete event permanently')),
                                              ],
                                            )
                                          : const Icon(
                                              Icons.lock_outline_rounded),
                                    ));
                              })),
                ]),
                ListView(padding: const EdgeInsets.all(12), children: [
                  const Text(
                      'Corrections and deletions for this profile are recorded locally. Closed monthly/yearly snapshots are immutable and are not recalculated.',
                      style: TextStyle(color: Colors.white70)),
                  if (_audit.isEmpty)
                    const Card(
                        child: ListTile(
                            title: Text('No corrections recorded yet.'))),
                  for (final entry in _audit) _auditCard(entry),
                ]),
              ]),
      );
}

/// Side-by-side comparison; other profiles must opt into activity sharing.
class WrappedProfileComparisonScreen extends StatefulWidget {
  const WrappedProfileComparisonScreen({super.key});

  @override
  State<WrappedProfileComparisonScreen> createState() =>
      _WrappedProfileComparisonScreenState();
}

class _WrappedProfileComparisonScreenState
    extends State<WrappedProfileComparisonScreen> {
  bool _loading = true;
  String _period = 'year';
  List<({Profile profile, WrappedPeriodStats stats})> _rows = const [];
  int _withheldProfiles = 0;

  bool get _canCompare {
    final profile = AppController.instance.currentProfile;
    return profile != null &&
        profile.governance.isOwnerManaged &&
        (profile.governance.contentLevel == ProfileContentLevel.mature ||
            profile.governance.contentLevel ==
                ProfileContentLevel.unrestricted);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_canCompare) {
      if (mounted) {
        setState(() {
          _rows = const [];
          _withheldProfiles = 0;
          _loading = false;
        });
      }
      return;
    }
    setState(() => _loading = true);
    final controller = AppController.instance;
    final activeId = controller.currentProfile?.id ?? '';
    final now = DateTime.now();
    final rows = <({Profile profile, WrappedPeriodStats stats})>[];
    var withheld = 0;
    for (final profile in controller.currentAccount?.profiles ?? <Profile>[]) {
      if (profile.id != activeId) {
        final privacy =
            await PrivacyPreferencesStore.load(profileId: profile.id);
        if (!privacy.shareActivity) {
          withheld++;
          continue;
        }
      }
      final events = await WrappedArchiveStore.loadEvents(profile.id);
      rows.add((
        profile: profile,
        stats: WrappedPeriodStats.calculate(
          events,
          year: now.year,
          month: _period == 'month' ? now.month : null,
        ),
      ));
    }
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _withheldProfiles = withheld;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar:
            AppBar(title: const Text('Profile Wrapped Comparison'), actions: [
          IconButton(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded))
        ]),
        body: !_canCompare
            ? const Center(
                child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                        'Profile comparison is available to owner-managed adult or unrestricted profiles.')))
            : _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(padding: const EdgeInsets.all(16), children: [
                    DropdownButtonFormField<String>(
                      initialValue: _period,
                      decoration:
                          const InputDecoration(labelText: 'Comparison period'),
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem(
                            value: 'month', child: Text('This month')),
                        DropdownMenuItem(
                            value: 'year', child: Text('This year')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _period = value);
                        _load();
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                        _period == 'month'
                            ? 'This month across profiles that have chosen to share their activity.'
                            : 'This year across profiles that have chosen to share their activity.',
                        style: const TextStyle(color: Colors.white70)),
                    if (_withheldProfiles > 0)
                      Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                              '$_withheldProfiles profile(s) are not included because activity sharing is off.',
                              style: const TextStyle(color: Colors.white54))),
                    const SizedBox(height: 12),
                    for (final row in _rows)
                      Card(
                          child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(row.profile.name,
                                        style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 10),
                                    Wrap(spacing: 8, runSpacing: 8, children: [
                                      _comparisonMetric('Plays',
                                          row.stats.playbackCompletions),
                                      _comparisonMetric(
                                          'Movies', row.stats.movieCompletions),
                                      _comparisonMetric(
                                          'TV', row.stats.showCompletions),
                                      _comparisonMetric(
                                          'Music', row.stats.musicCompletions),
                                      _comparisonMetric(
                                          'Active days', row.stats.activeDays),
                                    ]),
                                    if (row.stats.topTitles.isNotEmpty)
                                      ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          title: const Text('Most played'),
                                          subtitle: Text(
                                              row.stats.topTitles.first.key),
                                          trailing: Text(
                                              '${row.stats.topTitles.first.value} plays')),
                                    if (row.stats.topGenres.isNotEmpty)
                                      Text(
                                          'Favorite genre: ${row.stats.topGenres.first.key}'),
                                  ]))),
                  ]),
      );

  Widget _comparisonMetric(String label, int value) =>
      Chip(label: Text('$label · $value'));
}

class WrappedShareCardRenderer {
  static Future<List<int>> render({
    required String title,
    required String profileName,
    required String subtitle,
    required List<String> metrics,
    required List<String> highlights,
  }) async {
    const width = 1080.0;
    const height = 1350.0;
    final recorder = ui.PictureRecorder();
    final canvas =
        ui.Canvas(recorder, const ui.Rect.fromLTWH(0, 0, width, height));
    final background = ui.Paint()
      ..shader = ui.Gradient.linear(
        const ui.Offset(0, 0),
        const ui.Offset(width, height),
        const [
          ui.Color(0xFF081A36),
          ui.Color(0xFF321B4B),
          ui.Color(0xFF101018)
        ],
      );
    canvas.drawRect(const ui.Rect.fromLTWH(0, 0, width, height), background);
    canvas.drawRRect(
        ui.RRect.fromRectAndRadius(const ui.Rect.fromLTWH(52, 52, 976, 1246),
            const ui.Radius.circular(44)),
        ui.Paint()..color = const ui.Color(0x22FFFFFF));
    void drawText(String value, double x, double y, double maxWidth,
        double fontSize, ui.Color color,
        {bool bold = false}) {
      final painter = TextPainter(
        text: TextSpan(
            text: value,
            style: TextStyle(
                color: color,
                fontSize: fontSize,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                height: 1.18)),
        textDirection: TextDirection.ltr,
        maxLines: 3,
        ellipsis: '…',
      )..layout(maxWidth: maxWidth);
      painter.paint(canvas, Offset(x, y));
    }

    drawText('MY OWN STREAMING SERVICE', 110, 112, 860, 26,
        const ui.Color(0xFFB8C8FF),
        bold: true);
    drawText(title.toUpperCase(), 110, 190, 860, 72, const ui.Color(0xFFFFFFFF),
        bold: true);
    drawText(profileName, 110, 300, 860, 38, const ui.Color(0xFFE4D5FF),
        bold: true);
    drawText(subtitle, 110, 354, 860, 30, const ui.Color(0xFFCBD5E1));
    var y = 450.0;
    for (final metric in metrics.take(4)) {
      canvas.drawRRect(
          ui.RRect.fromRectAndRadius(
              ui.Rect.fromLTWH(110, y, 860, 86), const ui.Radius.circular(22)),
          ui.Paint()..color = const ui.Color(0x22FFFFFF));
      drawText(metric, 145, y + 24, 790, 30, const ui.Color(0xFFFFFFFF),
          bold: true);
      y += 98;
    }
    y += 14;
    drawText('YOUR HIGHLIGHTS', 110, y, 860, 30, const ui.Color(0xFFB8C8FF),
        bold: true);
    y += 58;
    for (var index = 0; index < highlights.take(5).length; index++) {
      drawText('${index + 1}. ${highlights[index]}', 120, y, 840, 30,
          const ui.Color(0xFFFFFFFF));
      y += 48;
    }
    drawText('A personal recap · Shared by choice', 110, 1240, 860, 22,
        const ui.Color(0xFFCBD5E1));
    final image =
        await recorder.endRecording().toImage(width.toInt(), height.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }
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
    {
      'title': 'Zombie Week',
      'theme': 'zombie',
      'keywords': ['zombie', 'undead', 'infected', 'apocalypse']
    },
    {
      'title': 'Superhero Week',
      'theme': 'superhero',
      'keywords': [
        'superhero',
        'super hero',
        'marvel',
        'dc comics',
        'comic book'
      ]
    },
    {
      'title': 'Horror-Comedy Weekend',
      'theme': 'horror comedy',
      'keywords': ['horror-comedy', 'horror comedy', 'comedy horror']
    },
    {
      'title': 'Sci-Fi Discovery Week',
      'theme': 'science fiction',
      'keywords': ['science fiction', 'sci-fi', 'space', 'alien', 'futuristic']
    },
    {
      'title': 'Animation Celebration',
      'theme': 'animation',
      'keywords': ['animation', 'animated', 'cartoon', 'family']
    },
    {
      'title': 'Mystery & Twist Week',
      'theme': 'mystery',
      'keywords': ['mystery', 'detective', 'thriller', 'whodunit']
    },
    {
      'title': 'Romantic Stories Week',
      'theme': 'romance',
      'keywords': ['romance', 'romantic', 'love story', 'rom-com']
    },
    {
      'title': 'Action & Adventure Week',
      'theme': 'action',
      'keywords': ['action', 'adventure', 'spy', 'heist']
    },
    {
      'title': 'Musical Moments Week',
      'theme': 'music',
      'keywords': ['musical', 'concert', 'soundtrack', 'music']
    },
    {
      'title': 'Fantasy Worlds Week',
      'theme': 'fantasy',
      'keywords': ['fantasy', 'magic', 'wizard', 'myth']
    },
    {
      'title': 'Comfort Rewatch Week',
      'theme': 'comfort',
      'keywords': ['comfort', 'feel-good', 'feel good', 'favorite']
    },
    {
      'title': 'Family Favorites Week',
      'theme': 'family',
      'keywords': ['family', 'kids', 'children', 'together']
    },
    {
      'title': 'Slasher Week',
      'theme': 'slasher',
      'keywords': ['slasher', 'halloween', 'serial killer', 'masked killer']
    },
    {
      'title': 'Holiday Countdown',
      'theme': 'holiday',
      'keywords': ['christmas', 'holiday', 'winter', 'festive']
    },
  ];

  static List<ThemeEvent> buildYear(int year, {required int seed}) {
    final random = math.Random(seed ^ year);
    final themes = List<Map<String, dynamic>>.from(_themes);
    final fixedSlasher =
        themes.firstWhere((item) => item['theme'] == 'slasher');
    final fixedHoliday =
        themes.firstWhere((item) => item['theme'] == 'holiday');
    final fixedRomance =
        themes.firstWhere((item) => item['theme'] == 'romance');
    final fixedAnimation =
        themes.firstWhere((item) => item['theme'] == 'animation');
    final fixedZombie = themes.firstWhere((item) => item['theme'] == 'zombie');
    final fixedSuperhero =
        themes.firstWhere((item) => item['theme'] == 'superhero');
    final used = <String>{
      'slasher',
      'holiday',
      'romance',
      'animation',
      'zombie',
      'superhero',
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
    final remaining = themes
        .where((item) => !used.contains(item['theme']))
        .toList()
      ..shuffle(random);
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

  static ThemeEvent _event(
          Map<String, dynamic> raw, DateTime start, int days) =>
      ThemeEvent(
        id: '${raw['theme']}_${start.year}_${start.month}_${start.day}',
        title: raw['title']?.toString() ?? 'Special Event',
        theme: raw['theme']?.toString() ?? 'mixed',
        startsAt: start,
        endsAt: start.add(Duration(days: days - 1)),
        keywords: (raw['keywords'] as List? ?? const [])
            .map((value) => value.toString())
            .toList(growable: false),
      );

  static bool _matchesFields(Iterable<String> fields, List<String> keywords) {
    final searchable = fields.join(' ').toLowerCase();
    return keywords.any((keyword) => searchable.contains(keyword));
  }

  static List<MediaItem> matchingMedia(
          ThemeEvent event, Iterable<MediaItem> library) =>
      library
          .where((item) => _matchesFields(<String>[
                item.title,
                item.type,
                item.description ?? '',
                ...item.genres,
                ...item.tags,
              ], event.keywords))
          .toList(growable: false);

  static List<MusicTrack> matchingMusic(
          ThemeEvent event, Iterable<MusicTrack> tracks) =>
      tracks
          .where((item) => _matchesFields(<String>[
                item.title,
                item.artist,
                item.album,
                ...item.genres,
                ...item.subgenres,
              ], event.keywords))
          .toList(growable: false);
}

class MyTvSpecialEventsScreen extends StatefulWidget {
  const MyTvSpecialEventsScreen({super.key});

  @override
  State<MyTvSpecialEventsScreen> createState() =>
      _MyTvSpecialEventsScreenState();
}

class _MyTvSpecialEventsScreenState extends State<MyTvSpecialEventsScreen> {
  bool loading = true;
  int year = DateTime.now().year;
  int seed = 20261021;
  List<ThemeEvent> events = const [];

  String get _seedKey =>
      'moss_theme_event_seed_${AppController.instance.currentProfile?.id ?? 'default'}_$year';

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
            IconButton(
                tooltip: 'Previous year',
                onPressed: year <= 2020
                    ? null
                    : () {
                        setState(() {
                          year--;
                          loading = true;
                        });
                        _load();
                      },
                icon: const Icon(Icons.chevron_left_rounded)),
            Center(child: Text('$year')),
            IconButton(
                tooltip: 'Next year',
                onPressed: () {
                  setState(() {
                    year++;
                    loading = true;
                  });
                  _load();
                },
                icon: const Icon(Icons.chevron_right_rounded)),
            IconButton(
                tooltip: 'Reroll randomized schedule',
                onPressed: _reroll,
                icon: const Icon(Icons.shuffle_rounded)),
          ],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text('A year of themed viewing',
                      style:
                          TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  const Text(
                      'The schedule is seeded and stable until you reroll it. Halloween and holiday windows are reserved; other themes are spread throughout the year. Only media found in your local library is shown as available.',
                      style: TextStyle(color: Colors.white70, height: 1.4)),
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
        title: Text(event.title,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
            '${event.startsAt.month}/${event.startsAt.day} – ${event.endsAt.month}/${event.endsAt.day}, ${event.endsAt.year} · $status · ${media.length} titles · ${tracks.length} tracks'),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          if (media.isEmpty && tracks.isEmpty)
            const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                    'No matching local titles yet. This event is scheduled, but the app will not invent content or claim provider availability.')),
          for (final item in media)
            ListTile(
              leading: const Icon(Icons.movie_outlined),
              title: Text(item.title),
              subtitle: Text(item.type),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => MediaDetailsScreen(media: item))),
            ),
          for (final track in tracks)
            ListTile(
                leading: const Icon(Icons.music_note_rounded),
                title: Text(track.title),
                subtitle: Text(musicTrackSubtitle(track),
                    maxLines: 2, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

class RealLifeInterruptionModeScreen extends StatefulWidget {
  const RealLifeInterruptionModeScreen({super.key});

  @override
  State<RealLifeInterruptionModeScreen> createState() =>
      _RealLifeInterruptionModeScreenState();
}

class _RealLifeInterruptionModeScreenState
    extends State<RealLifeInterruptionModeScreen> {
  bool enabled = true;
  bool bedtimePrompt = false;
  bool pauseMusic = true;
  bool doNotInterrupt = false;
  bool loading = true;

  String get _key =>
      'moss_interruption_settings_${AppController.instance.currentProfile?.id ?? 'default'}';

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
    await prefs.setString(
        _key,
        jsonEncode(<String, dynamic>{
          'enabled': enabled,
          'bedtimePrompt': bedtimePrompt,
          'pauseMusic': pauseMusic,
          'doNotInterrupt': doNotInterrupt,
        }));
  }

  void _control(String action) {
    bool performed = false;
    switch (action) {
      case 'pause':
        performed = PlaybackInterruptionBridge.pauseNow();
        break;
      case 'resume':
        performed = PlaybackInterruptionBridge.resumeNow();
        break;
      case 'save':
        performed = PlaybackInterruptionBridge.savePosition();
        break;
    }
    if (!mounted) return;
    final message = performed
        ? (action == 'pause'
            ? 'Playback paused.'
            : action == 'resume'
                ? 'Playback resumed.'
                : 'Current playback position saved.')
        : 'No compatible in-app player is connected right now. Open playback and use its controls.';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar:
            AppBar(title: const UniversalText('Real-Life Interruption Mode')),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(16), children: [
                Card(
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Pause real life less intrusively',
                                  style: TextStyle(
                                      fontSize: 23,
                                      fontWeight: FontWeight.w900)),
                              const SizedBox(height: 8),
                              const Text(
                                  'Use explicit controls to pause, save progress and resume. Always-on room listening is not enabled by this feature.',
                                  style: TextStyle(
                                      color: Colors.white70, height: 1.4)),
                              const SizedBox(height: 12),
                              Text(
                                  PlaybackInterruptionBridge.currentTitle ==
                                          null
                                      ? 'Player status: no compatible player attached'
                                      : 'Now playing: ${PlaybackInterruptionBridge.currentTitle}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 12),
                              Wrap(spacing: 8, runSpacing: 8, children: [
                                FilledButton.tonalIcon(
                                    onPressed: enabled
                                        ? () => _control('pause')
                                        : null,
                                    icon: const Icon(Icons.pause_rounded),
                                    label: const Text('I need a break')),
                                FilledButton.tonalIcon(
                                    onPressed:
                                        enabled ? () => _control('save') : null,
                                    icon: const Icon(
                                        Icons.bookmark_added_outlined),
                                    label: const Text('Save position')),
                                FilledButton.icon(
                                    onPressed: enabled
                                        ? () => _control('resume')
                                        : null,
                                    icon: const Icon(Icons.play_arrow_rounded),
                                    label: const Text("I'm back")),
                              ]),
                            ]))),
                Card(
                    child: Column(children: [
                  SwitchListTile(
                      title: const Text('Interruption controls enabled'),
                      subtitle: const Text(
                          'Enable explicit pause, resume and save-position controls.'),
                      value: enabled,
                      onChanged: (value) {
                        setState(() => enabled = value);
                        _save();
                      }),
                  SwitchListTile(
                      title: const Text('Bedtime prompt'),
                      subtitle: const Text(
                          'Show bedtime settings here; system notifications require a platform notification integration.'),
                      value: bedtimePrompt,
                      onChanged: (value) {
                        setState(() => bedtimePrompt = value);
                        _save();
                      }),
                  SwitchListTile(
                      title: const Text(
                          'Prefer pausing music during a video interruption'),
                      subtitle: const Text(
                          'Saved as a preference; automatic music pausing needs a shared music-player integration.'),
                      value: pauseMusic,
                      onChanged: (value) {
                        setState(() => pauseMusic = value);
                        _save();
                      }),
                  SwitchListTile(
                      title: const Text('Do Not Interrupt'),
                      subtitle: const Text(
                          'A preference flag for compatible future notification/automation integrations.'),
                      value: doNotInterrupt,
                      onChanged: (value) {
                        setState(() => doNotInterrupt = value);
                        _save();
                      }),
                ])),
                const Card(
                    child: Padding(
                        padding: EdgeInsets.all(14),
                        child: Text(
                            'Microphone privacy: no background wake-word service is started. Any future voice activation must be separately opted into, visibly active, and supported by the operating system/device.',
                            style: TextStyle(
                                color: Colors.white60, height: 1.4)))),
              ]),
      );
}

class SecurityBotCenterScreen extends StatefulWidget {
  const SecurityBotCenterScreen({super.key});

  @override
  State<SecurityBotCenterScreen> createState() =>
      _SecurityBotCenterScreenState();
}

class _SecurityBotCenterScreenState extends State<SecurityBotCenterScreen> {
  bool loading = false;
  String? error;
  Map<String, dynamic>? backendReport;
  List<_LocalDiagnosticCheck> localChecks = const [];

  @override
  void initState() {
    super.initState();
    _runChecks();
  }

  List<_LocalDiagnosticCheck> _inspectLocalData() {
    final controller = AppController.instance;
    final library = controller.library;
    final profiles = controller.currentAccount?.profiles ?? const [];
    final duplicateMediaIds =
        library.length - library.map((item) => item.id).toSet().length;
    final usernames = profiles
        .map((item) => item.username.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toList();
    final duplicateUsernames = usernames.length - usernames.toSet().length;
    final missingUsernames =
        profiles.where((item) => item.username.trim().isEmpty).length;
    final missingArtwork = library
        .where((item) => item.imageUrl?.trim().isNotEmpty != true)
        .length;
    final insecureUrls = library.where((item) {
      final value = item.playbackUrl?.trim() ?? '';
      final uri = Uri.tryParse(value);
      return value.isNotEmpty &&
          uri != null &&
          uri.scheme == 'http' &&
          uri.host != 'localhost' &&
          uri.host != '127.0.0.1';
    }).length;
    return <_LocalDiagnosticCheck>[
      _LocalDiagnosticCheck(
          'catalog_quality',
          'Catalog Quality',
          duplicateMediaIds == 0 ? 'passed' : 'warning',
          '$duplicateMediaIds duplicate media IDs in the loaded library.'),
      _LocalDiagnosticCheck(
          'account_guardian',
          'Account & Profile Integrity',
          duplicateUsernames == 0 && missingUsernames == 0
              ? 'passed'
              : 'warning',
          '$duplicateUsernames repeated usernames; $missingUsernames profiles without a username.'),
      _LocalDiagnosticCheck(
          'metadata_health',
          'Media Library Health',
          missingArtwork == 0 ? 'passed' : 'info',
          '$missingArtwork loaded media items are missing artwork.'),
      _LocalDiagnosticCheck(
          'connection_review',
          'Playback URL Review',
          insecureUrls == 0 ? 'passed' : 'warning',
          '$insecureUrls external playback URLs use HTTP. Development localhost URLs are excluded.'),
      const _LocalDiagnosticCheck(
          'backup_watch',
          'Backup & Recovery',
          'not_connected',
          'Backup encryption, restore drills and server storage cannot be verified from the client-only scan.'),
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
        problem =
            'Backend scan unavailable: ${exception.toString().replaceFirst('Exception: ', '')}';
      }
    } else {
      problem =
          'Sign in as the account/server owner to run server-side scans. Local checks below are still available.';
    }
    if (!mounted) return;
    setState(() {
      localChecks = checks;
      backendReport = report;
      error = problem;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: const UniversalText('Security & Database Checks'),
            actions: [
              IconButton(
                  tooltip: 'Run checks',
                  onPressed: loading ? null : _runChecks,
                  icon: const Icon(Icons.refresh_rounded))
            ]),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _runChecks,
                child: ListView(padding: const EdgeInsets.all(16), children: [
                  const Text('Permission-controlled diagnostics',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  const Text(
                      'Local checks inspect only metadata currently loaded by this client. Server checks are owner-only and never return secret values. This screen reports findings without performing automatic changes.',
                      style: TextStyle(color: Colors.white70, height: 1.4)),
                  if (error != null)
                    Card(
                        child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(error!))),
                  if (backendReport != null) _backendReportCard(backendReport!),
                  const SizedBox(height: 10),
                  const Text('Local checks',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  for (final check in localChecks)
                    Card(
                        child: ListTile(
                      leading: Icon(_statusIcon(check.status),
                          color: _statusColor(check.status)),
                      title: Text(check.title),
                      subtitle: Text(check.details),
                      trailing: const Text('LOCAL',
                          style:
                              TextStyle(fontSize: 10, color: Colors.white54)),
                    )),
                ])),
      );

  Widget _backendReportCard(Map<String, dynamic> report) {
    final checks = report['checks'] is List
        ? (report['checks'] as List).whereType<Map>().toList()
        : const <Map>[];
    final summary = report['summary'] is Map
        ? Map<String, dynamic>.from(report['summary'] as Map)
        : <String, dynamic>{};
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Server-side owner scan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              Text('Run at ${report['generatedAt'] ?? 'unknown time'}'),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                Chip(label: Text('${summary['passed'] ?? 0} passed')),
                Chip(label: Text('${summary['warning'] ?? 0} warnings')),
                Chip(label: Text('${summary['failed'] ?? 0} failed')),
              ]),
              for (final check in checks)
                ListTile(
                  dense: true,
                  leading: Icon(
                      _statusIcon(check['status']?.toString() ?? 'info'),
                      color:
                          _statusColor(check['status']?.toString() ?? 'info')),
                  title: Text(check['title']?.toString() ??
                      check['id']?.toString() ??
                      'Check'),
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

class _LocalDiagnosticCheck {
  final String id;
  final String title;
  final String status;
  final String details;
  const _LocalDiagnosticCheck(this.id, this.title, this.status, this.details);
}
