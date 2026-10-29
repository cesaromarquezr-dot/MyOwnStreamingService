import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_core.dart';
import 'core/services/cinematic_title_metadata_service.dart';

/// A countdown to one real-world release milestone. Manual events are stored
/// per profile; catalog dates remain sourced from the library or provider APIs.
class ReleaseCalendarEvent {
  const ReleaseCalendarEvent({
    required this.id,
    required this.title,
    required this.category,
    required this.milestone,
    required this.scheduledAt,
    this.parentTitle,
    this.imageUrl,
    this.source = 'Your schedule',
    this.note,
    this.dateOnly = false,
    this.isManual = true,
  });

  final String id;
  final String title;
  final String category;
  final String milestone;
  final DateTime scheduledAt;
  final String? parentTitle;
  final String? imageUrl;
  final String source;
  final String? note;
  final bool dateOnly;
  final bool isManual;

  DateTime get localTime => scheduledAt.toLocal();

  bool get isPhysicalMedia {
    final value = '$milestone $category'.toLowerCase();
    return value.contains('dvd') ||
        value.contains('blu-ray') ||
        value.contains('bluray') ||
        value.contains('4k') ||
        value.contains('ultra hd') ||
        value.contains('physical media') ||
        value.contains('cd release') ||
        value.contains('complete series on') ||
        value.contains('season on');
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'category': category,
        'milestone': milestone,
        'scheduledAt': scheduledAt.toUtc().toIso8601String(),
        'parentTitle': parentTitle,
        'imageUrl': imageUrl,
        'source': source,
        'note': note,
        'dateOnly': dateOnly,
        'isManual': isManual,
      };

  factory ReleaseCalendarEvent.fromJson(Map<String, dynamic> json) {
    final parsedDate = DateTime.tryParse(json['scheduledAt']?.toString() ?? '');
    if (parsedDate == null) {
      throw const FormatException('Release event has no valid scheduledAt date.');
    }
    String text(String key, [String fallback = '']) =>
        (json[key] ?? fallback).toString().trim();
    return ReleaseCalendarEvent(
      id: text('id'),
      title: text('title', 'Untitled release'),
      category: text('category', 'Movie'),
      milestone: text('milestone', 'Release'),
      scheduledAt: parsedDate.toUtc(),
      parentTitle: text('parentTitle').isEmpty ? null : text('parentTitle'),
      imageUrl: text('imageUrl').isEmpty ? null : text('imageUrl'),
      source: text('source', 'Your schedule'),
      note: text('note').isEmpty ? null : text('note'),
      dateOnly: json['dateOnly'] == true,
      isManual: json['isManual'] != false,
    );
  }
}

/// Human-readable countdown formatter kept pure for unit testing.
String formatReleaseCountdown(
  DateTime releaseAt, {
  DateTime? now,
  bool dateOnly = false,
}) {
  final current = now ?? DateTime.now();
  if (dateOnly) {
    final releaseLocal = releaseAt.toLocal();
    final currentLocal = current.toLocal();
    final releaseDay = DateTime(releaseLocal.year, releaseLocal.month, releaseLocal.day);
    final currentDay = DateTime(currentLocal.year, currentLocal.month, currentLocal.day);
    final dayDifference = releaseDay.difference(currentDay).inDays;
    if (dayDifference < 0) return dayDifference == -1 ? 'Released yesterday' : 'Released ${dayDifference.abs()}d ago';
    if (dayDifference == 0) return 'Due today';
    return dayDifference == 1 ? 'In 1 day' : 'In $dayDifference days';
  }
  final difference = releaseAt.toUtc().difference(current.toUtc());
  if (difference.isNegative) {
    final elapsed = difference.abs();
    if (elapsed.inDays >= 1) return 'Released ${elapsed.inDays}d ago';
    if (elapsed.inHours >= 1) return 'Released ${elapsed.inHours}h ago';
    if (elapsed.inMinutes >= 1) return 'Released ${elapsed.inMinutes}m ago';
    return 'Released';
  }
  if (difference.inDays >= 1) {
    final days = difference.inDays;
    final hours = difference.inHours.remainder(24);
    return hours == 0 ? 'In $days days' : 'In $days days ${hours}h';
  }
  if (difference.inHours >= 1) {
    final hours = difference.inHours;
    final minutes = difference.inMinutes.remainder(60);
    return minutes == 0 ? 'In $hours hours' : 'In $hours hours ${minutes}m';
  }
  if (difference.inMinutes >= 1) return 'In ${difference.inMinutes} minutes';
  return 'Releases now';
}

DateTime? _parseReleaseDate(dynamic raw, {dynamic timeRaw}) {
  final text = raw?.toString().trim() ?? '';
  if (text.isEmpty) return null;
  final parsed = DateTime.tryParse(text);
  if (parsed == null) return null;
  if (text.length <= 10 || !text.contains('T')) {
    final time = (timeRaw ?? '').toString().trim();
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(time);
    final hour = (match == null ? 12 : (int.tryParse(match.group(1)!) ?? 12).clamp(0, 23)).toInt();
    final minute = (match == null ? 0 : (int.tryParse(match.group(2)!) ?? 0).clamp(0, 59)).toInt();
    return DateTime(parsed.year, parsed.month, parsed.day, hour, minute).toUtc();
  }
  return parsed.toUtc();
}

class ComingSoonReleaseScreen extends StatefulWidget {
  const ComingSoonReleaseScreen({super.key});

  @override
  State<ComingSoonReleaseScreen> createState() => _ComingSoonReleaseScreenState();
}

class _ComingSoonReleaseScreenState extends State<ComingSoonReleaseScreen> {
  static const List<String> _filters = <String>[
    'All',
    'Movies',
    'Shows',
    'Episodes',
    'Albums',
    'Physical Media',
  ];

  List<ReleaseCalendarEvent> _manualEvents = <ReleaseCalendarEvent>[];
  List<ReleaseCalendarEvent> _events = <ReleaseCalendarEvent>[];
  String _filter = 'All';
  String _search = '';
  bool _loading = true;
  bool _refreshing = false;
  String? _providerMessage;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    // Do not synchronously call setState from initState while an enclosing
    // route is still inserting this screen. Start I/O after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_refresh());
    });
    // Minute granularity is enough for a human countdown and avoids a hot
    // per-second timer while this screen is open.
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  String get _storageKey {
    final controller = AppController.instance;
    final account = controller.currentAccount?.id.trim();
    final profile = controller.currentProfile?.id.trim();
    final accountKey = account == null || account.isEmpty ? 'local' : account;
    final profileKey = profile == null || profile.isEmpty ? 'default' : profile;
    return 'coming_soon_release_events_v1_${accountKey}_$profileKey';
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    // Capture inherited widget data before any async gap. Do not access the
    // BuildContext after awaiting SharedPreferences or provider requests.
    final regionCode = Localizations.localeOf(context).countryCode;
    setState(() {
      _refreshing = true;
      _loading = _events.isEmpty;
      _providerMessage = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      final manual = <ReleaseCalendarEvent>[];
      if (raw != null && raw.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) {
            for (final item in decoded.whereType<Map>()) {
              try {
                final event = ReleaseCalendarEvent.fromJson(
                  Map<String, dynamic>.from(item),
                );
                if (event.id.isNotEmpty && event.title.isNotEmpty) manual.add(event);
              } catch (_) {
                // One malformed local reminder must not hide the rest.
              }
            }
          }
        } catch (_) {
          _providerMessage = 'Some saved reminders could not be read. You can add them again.';
        }
      }

      final localEvents = _eventsFromLibrary(AppController.instance.library);
      var providerEvents = <ReleaseCalendarEvent>[];
      if (AppController.instance.isBackendAuthenticated) {
        final movieTvFuture = CinematicTitleMetadataService.lookupUpcomingCalendarEvents(
          regionCode: regionCode,
        );
        final albumFuture = AppController.instance.backendApi.getUpcomingMusicAlbums(limit: 60);
        try {
          final payload = await movieTvFuture;
          providerEvents = payload.map(ReleaseCalendarEvent.fromJson).toList(growable: false);
        } catch (_) {
          _providerMessage = 'Live movie and TV dates are temporarily unavailable. Your library dates and saved reminders are still shown.';
        }
        try {
          final albumPayload = await albumFuture;
          final rawAlbums = albumPayload['items'];
          if (rawAlbums is List) {
            for (final rawAlbum in rawAlbums.whereType<Map>()) {
              final album = Map<String, dynamic>.from(rawAlbum);
              final rawDate = (album['releaseDate'] ?? album['firstReleaseDate'] ?? '').toString().trim();
              if (rawDate.length < 10) continue;
              final parsedDate = DateTime.tryParse(rawDate.substring(0, 10));
              if (parsedDate == null) continue;
              final localNoon = DateTime(parsedDate.year, parsedDate.month, parsedDate.day, 12);
              if (localNoon.isBefore(DateTime.now().subtract(const Duration(days: 1))) ||
                  localNoon.isAfter(DateTime.now().add(const Duration(days: 366)))) {
                continue;
              }
              final title = (album['title'] ?? 'Untitled album').toString().trim();
              final artist = (album['artist'] ?? '').toString().trim();
              final albumId = (album['id'] ?? '').toString().trim();
              if (title.isEmpty || albumId.isEmpty) continue;
              providerEvents.add(ReleaseCalendarEvent(
                id: 'musicbrainz-album-$albumId',
                title: artist.isEmpty ? title : '$title · $artist',
                parentTitle: title,
                category: 'Album',
                milestone: 'Album release',
                scheduledAt: localNoon.toUtc(),
                dateOnly: true,
                imageUrl: (album['imageUrl'] ?? album['coverArtUrl'])?.toString(),
                source: 'MusicBrainz',
                isManual: false,
                note: 'Known first-release date from MusicBrainz. Release dates and country-specific availability may change.',
              ));
            }
          }
        } catch (_) {
          _providerMessage ??= 'Upcoming album dates are temporarily unavailable. You can still add album countdowns manually.';
        }
      } else {
        _providerMessage = 'Sign in to your backend to load catalog release dates. You can still add and save your own countdowns.';
      }

      final merged = <String, ReleaseCalendarEvent>{};
      for (final event in <ReleaseCalendarEvent>[...providerEvents, ...localEvents, ...manual]) {
        final key = _dedupeKey(event);
        final existing = merged[key];
        // User-entered dates intentionally win over provider dates for the same
        // title/milestone/date because they can be region- and service-specific.
        if (existing == null || event.isManual) merged[key] = event;
      }
      final sorted = _sortEvents(merged.values.toList());
      if (!mounted) return;
      setState(() {
        _manualEvents = manual;
        _events = sorted;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _providerMessage ??= 'Unable to load release dates. Try refreshing or add one manually.';
        });
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  bool _isPast(ReleaseCalendarEvent event) {
    if (!event.dateOnly) return event.scheduledAt.isBefore(DateTime.now().toUtc());
    final local = event.localTime;
    final today = DateTime.now();
    return DateTime(local.year, local.month, local.day)
        .isBefore(DateTime(today.year, today.month, today.day));
  }

  List<ReleaseCalendarEvent> _sortEvents(List<ReleaseCalendarEvent> events) {
    events.sort((a, b) {
      final aFuture = !_isPast(a);
      final bFuture = !_isPast(b);
      if (aFuture != bFuture) return aFuture ? -1 : 1;
      if (aFuture) return a.scheduledAt.compareTo(b.scheduledAt);
      return b.scheduledAt.compareTo(a.scheduledAt);
    });
    return events;
  }

  String _dedupeKey(ReleaseCalendarEvent event) {
    String normalize(String value) {
      return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
    }

    final date = event.localTime;
    return '${normalize(event.title)}|${normalize(event.milestone)}|${date.year}-${date.month}-${date.day}';
  }

  List<ReleaseCalendarEvent> _eventsFromLibrary(List<MediaItem> library) {
    final now = DateTime.now().toUtc();
    final earliest = now.subtract(const Duration(days: 1));
    final latest = now.add(const Duration(days: 5 * 366));
    final output = <ReleaseCalendarEvent>[];
    final seen = <String>{};

    void add({
      required String id,
      required String title,
      required String category,
      required String milestone,
      required DateTime? date,
      String? parentTitle,
      String? imageUrl,
      String source = 'Your library',
      String? note,
      bool dateOnly = true,
    }) {
      if (date == null || date.isBefore(earliest) || date.isAfter(latest) || title.trim().isEmpty) return;
      final eventId = 'library-$id';
      if (!seen.add(eventId)) return;
      output.add(ReleaseCalendarEvent(
        id: eventId,
        title: title.trim(),
        category: category,
        milestone: milestone,
        scheduledAt: date.toUtc(),
        parentTitle: parentTitle,
        imageUrl: imageUrl,
        source: source,
        note: note,
        dateOnly: dateOnly,
        isManual: false,
      ));
    }

    for (final media in library) {
      final type = media.type.toLowerCase().replaceAll('-', '_');
      final isAlbum = type.contains('album') || type == 'music_album';
      final isEpisode = type.contains('episode');
      final isShow = !isEpisode && (type.contains('tv') || type.contains('show') || type.contains('series'));
      final isMovie = type.contains('movie') || type.contains('film');
      final category = isAlbum ? 'Album' : isEpisode ? 'Episode' : isShow ? 'Show' : 'Movie';
      final primaryDate = isShow ? (media.seriesStartDate ?? media.releaseDate) : media.releaseDate;
      final primaryMilestone = isAlbum
          ? 'Album release'
          : isEpisode
              ? 'Episode release'
              : isShow
                  ? 'Series premiere'
                  : 'Theatrical release';
      if ((isAlbum || isEpisode || isShow || isMovie) && primaryDate != null) {
        add(
          id: '${media.id}-primary',
          title: media.title,
          category: category,
          milestone: primaryMilestone,
          date: _dateOnlyOrTimestamp(primaryDate),
          imageUrl: media.imageUrl,
          note: 'Release date supplied by the imported library metadata.',
          dateOnly: _isDateOnly(primaryDate),
        );
      }

      final editionDate = media.editionReleaseDate;
      if (editionDate != null && (isMovie || isShow || isAlbum)) {
        final edition = '${media.editionName ?? ''} ${media.editionType ?? ''}'.toLowerCase();
        final physical = edition.contains('dvd') || edition.contains('blu-ray') ||
            edition.contains('bluray') || edition.contains('4k') || edition.contains('ultra hd') ||
            edition.contains('physical') || (isAlbum && edition.contains('cd'));
        final milestone = edition.contains('dvd')
            ? (isShow ? 'Season/series DVD release' : 'DVD release')
            : edition.contains('blu-ray') || edition.contains('bluray')
                ? (isShow ? 'Season/series Blu-ray release' : 'Blu-ray release')
                : edition.contains('4k') || edition.contains('ultra hd')
                    ? (isShow ? 'Season/series 4K Ultra HD release' : '4K Ultra HD release')
                    : edition.contains('cd') && isAlbum
                        ? 'CD release'
                        : physical
                            ? 'Physical media release'
                            : 'Edition release';
        add(
          id: '${media.id}-edition',
          title: media.title,
          category: category,
          milestone: milestone,
          date: _dateOnlyOrTimestamp(editionDate),
          imageUrl: media.imageUrl,
          note: 'Edition date supplied by the imported library metadata.',
          dateOnly: _isDateOnly(editionDate),
        );
      }

      for (var seasonIndex = 0; seasonIndex < media.seasons.length; seasonIndex++) {
        final season = media.seasons[seasonIndex];
        final seasonNumber = _number(season['seasonNumber'] ?? season['season_number'] ?? season['number']);
        final seasonLabel = seasonNumber == null ? 'Season' : 'Season $seasonNumber';
        for (final physicalEvent in _knownPhysicalDates(
          map: season,
          idPrefix: '${media.id}-season-$seasonIndex',
          title: '${media.title} · $seasonLabel',
          category: 'Show',
          imageUrl: (season['posterUrl'] ?? season['imageUrl'] ?? media.imageUrl)?.toString(),
          isShow: true,
          earliest: earliest,
          latest: latest,
        )) {
          if (seen.add(physicalEvent.id)) output.add(physicalEvent);
        }
        final episodesRaw = season['episodes'];
        if (episodesRaw is! List) continue;
        for (var episodeIndex = 0; episodeIndex < episodesRaw.length; episodeIndex++) {
          final rawEpisode = episodesRaw[episodeIndex];
          if (rawEpisode is! Map) continue;
          final episode = Map<String, dynamic>.from(rawEpisode);
          final episodeNumber = _number(episode['episodeNumber'] ?? episode['episode_number'] ?? episode['number']);
          final episodeTitle = (episode['title'] ?? episode['name'] ?? 'Episode ${episodeNumber ?? episodeIndex + 1}').toString();
          final code = seasonNumber != null && episodeNumber != null
              ? 'S${seasonNumber.toString().padLeft(2, '0')}E${episodeNumber.toString().padLeft(2, '0')}'
              : null;
          final fullTitle = '${media.title} · ${code == null ? '' : '$code · '}$episodeTitle';
          final episodeImage = (episode['imageUrl'] ?? episode['stillUrl'] ?? media.imageUrl)?.toString();
          final airDate = _parseReleaseDate(
            episode['streamingReleaseDate'] ?? episode['streaming_release_date'] ??
                episode['readyToStreamDate'] ?? episode['ready_to_stream_date'] ??
                episode['airDate'] ?? episode['air_date'] ?? episode['releaseDate'] ?? episode['release_date'],
            timeRaw: episode['airTime'] ?? episode['air_time'] ?? episode['releaseTime'],
          );
          final streamingDate = _parseReleaseDate(
            episode['streamingReleaseDate'] ?? episode['streaming_release_date'] ??
                episode['readyToStreamDate'] ?? episode['ready_to_stream_date'],
            timeRaw: episode['streamingTime'] ?? episode['streaming_time'],
          );
          final isStreaming = streamingDate != null;
          add(
            id: '${media.id}-season-$seasonIndex-episode-$episodeIndex',
            title: fullTitle,
            parentTitle: media.title,
            category: 'Episode',
            milestone: isStreaming ? 'New episode · streaming release' : 'New episode · scheduled air date',
            date: isStreaming ? streamingDate : airDate,
            imageUrl: episodeImage,
            note: (episode['network'] ?? episode['streamingService'] ?? episode['platform'])?.toString() ??
                'Episode date supplied by the imported library metadata; the actual airing time may depend on region.',
            dateOnly: !(episode.containsKey('airTime') || episode.containsKey('air_time') || episode.containsKey('releaseTime')),
          );
          for (final physicalEvent in _knownPhysicalDates(
            map: episode,
            idPrefix: '${media.id}-season-$seasonIndex-episode-$episodeIndex',
            title: fullTitle,
            category: 'Episode',
            imageUrl: episodeImage,
            isShow: false,
            earliest: earliest,
            latest: latest,
          )) {
            if (seen.add(physicalEvent.id)) output.add(physicalEvent);
          }
        }
      }
    }
    return output;
  }

  List<ReleaseCalendarEvent> _knownPhysicalDates({
    required Map<dynamic, dynamic> map,
    required String idPrefix,
    required String title,
    required String category,
    required String? imageUrl,
    required bool isShow,
    required DateTime earliest,
    required DateTime latest,
  }) {
    final candidates = <(List<String>, String)>[
      (<String>['dvdReleaseDate', 'dvd_release_date', 'dvdDate', 'dvd_date'], 'DVD release'),
      (<String>['physicalReleaseDate', 'physical_release_date', 'physicalEditionDate'], 'Physical media release (format unspecified)'),
      (<String>['bluRayReleaseDate', 'blurayReleaseDate', 'blu_ray_release_date', 'bluRayDate', 'blu_ray_date'], 'Blu-ray release'),
      (<String>['uhdReleaseDate', 'fourKReleaseDate', '4kReleaseDate', 'uhd_release_date', 'four_k_release_date'], '4K Ultra HD release'),
      (<String>['cdReleaseDate', 'cd_release_date'], 'CD release'),
      (<String>['seasonDvdReleaseDate', 'season_dvd_release_date'], 'Season on DVD'),
      (<String>['seasonBluRayReleaseDate', 'season_bluray_release_date'], 'Season on Blu-ray'),
      (<String>['seriesDvdReleaseDate', 'completeSeriesDvdReleaseDate'], 'Complete series on DVD'),
      (<String>['seriesBluRayReleaseDate', 'completeSeriesBluRayReleaseDate'], 'Complete series on Blu-ray'),
      (<String>['seriesUhdReleaseDate', 'completeSeries4kReleaseDate'], 'Complete series on 4K Ultra HD'),
    ];
    final output = <ReleaseCalendarEvent>[];
    for (final candidate in candidates) {
      dynamic raw;
      for (final key in candidate.$1) {
        if (map[key] != null) {
          raw = map[key];
          break;
        }
      }
      if (raw == null) continue;
      final date = _parseReleaseDate(raw);
      if (date == null || date.isBefore(earliest) || date.isAfter(latest)) continue;
      final milestone = candidate.$2;
      output.add(ReleaseCalendarEvent(
        id: 'library-$idPrefix-${milestone.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}',
        title: title,
        category: category,
        milestone: milestone,
        scheduledAt: date,
        imageUrl: imageUrl,
        source: 'Your library',
        note: isShow
            ? 'Physical season/series release date supplied by catalog metadata.'
            : 'Physical edition date supplied by catalog metadata.',
        dateOnly: true,
        isManual: false,
      ));
    }
    return output;
  }

  DateTime _dateOnlyOrTimestamp(DateTime value) {
    // Catalog release dates often arrive as date-only midnight values. Keep
    // that as a date milestone at noon local time, avoiding timezone day-shifts.
    if (value.hour == 0 && value.minute == 0 && value.second == 0) {
      return DateTime(value.year, value.month, value.day, 12).toUtc();
    }
    return value.toUtc();
  }

  bool _isDateOnly(DateTime value) => value.hour == 0 && value.minute == 0 && value.second == 0;

  int? _number(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  Future<void> _addEvent() async {
    final event = await showDialog<ReleaseCalendarEvent>(
      context: context,
      builder: (_) => const _AddReleaseEventDialog(),
    );
    if (event == null || !mounted) return;
    final updated = <ReleaseCalendarEvent>[..._manualEvents, event];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(updated.map((item) => item.toJson()).toList()));
    if (!mounted) return;
    setState(() {
      _manualEvents = updated;
      final key = _dedupeKey(event);
      _events = _sortEvents(<ReleaseCalendarEvent>[
        ..._events.where((existing) =>
            existing.id != event.id && _dedupeKey(existing) != key),
        event,
      ]);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Release countdown saved for this profile.')),
    );
  }

  Future<void> _deleteEvent(ReleaseCalendarEvent event) async {
    final updated = _manualEvents.where((item) => item.id != event.id).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(updated.map((item) => item.toJson()).toList()));
    if (!mounted) return;
    setState(() {
      _manualEvents = updated;
      _events.removeWhere((item) => item.id == event.id);
    });
  }

  List<ReleaseCalendarEvent> get _visibleEvents {
    final query = _search.trim().toLowerCase();
    return _events.where((event) {
      final filterMatches = switch (_filter) {
        'Movies' => event.category.toLowerCase() == 'movie',
        'Shows' => event.category.toLowerCase() == 'show',
        'Episodes' => event.category.toLowerCase() == 'episode',
        'Albums' => event.category.toLowerCase() == 'album',
        'Physical Media' => event.isPhysicalMedia,
        _ => true,
      };
      final queryMatches = query.isEmpty ||
          event.title.toLowerCase().contains(query) ||
          event.milestone.toLowerCase().contains(query) ||
          (event.parentTitle ?? '').toLowerCase().contains(query) ||
          (event.note ?? '').toLowerCase().contains(query);
      return filterMatches && queryMatches;
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleEvents;
    final upcomingCount = _events.where((e) => !_isPast(e)).length;
    final todayCount = _events.where((e) {
      final local = e.localTime;
      final current = DateTime.now();
      return local.year == current.year && local.month == current.month && local.day == current.day;
    }).length;
    final physicalCount = _events.where((e) => e.isPhysicalMedia && !_isPast(e)).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coming Soon'),
        actions: [
          IconButton(
            tooltip: 'Refresh release dates',
            onPressed: _refreshing ? null : _refresh,
            icon: _refreshing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addEvent,
        icon: const Icon(Icons.add_alarm_rounded),
        label: const Text('Add release date'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
                children: [
                  _introPanel(context),
                  const SizedBox(height: 14),
                  _summaryRow(upcomingCount: upcomingCount, todayCount: todayCount, physicalCount: physicalCount),
                  if (_providerMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.withValues(alpha: .20)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 19),
                        const SizedBox(width: 9),
                        Expanded(child: Text(_providerMessage!, style: const TextStyle(fontSize: 12, height: 1.35))),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextField(
                    onChanged: (value) => setState(() => _search = value),
                    decoration: InputDecoration(
                      hintText: 'Search titles, milestones, platforms…',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .45),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 42,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _filters.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 7),
                      itemBuilder: (context, index) {
                        final filter = _filters[index];
                        return ChoiceChip(
                          label: Text(filter),
                          selected: _filter == filter,
                          onSelected: (_) => setState(() => _filter = filter),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('${visible.length} release milestone${visible.length == 1 ? '' : 's'}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                  const SizedBox(height: 8),
                  if (visible.isEmpty)
                    _emptyState(context)
                  else
                    ...visible.map((event) => _eventCard(context, event)),
                ],
              ),
            ),
    );
  }

  Widget _introPanel(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF2B224A), Color(0xFF171923)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF8B7CFF).withValues(alpha: .28)),
      ),
      padding: const EdgeInsets.all(17),
      child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(Icons.hourglass_top_rounded, color: Color(0xFFB9ADFF)), SizedBox(width: 9), Text('Every premiere. Every format.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))]),
        SizedBox(height: 8),
        Text('Track theatrical releases, streaming launches, first cable airings, new episodes, albums, DVD, Blu-ray, 4K Ultra HD and CD dates in one place.', style: TextStyle(color: Colors.white70, height: 1.4, fontSize: 13)),
        SizedBox(height: 7),
        Text('Catalog release dates can be regional or date-only. Add a date yourself whenever you know the exact provider, format or airing time.', style: TextStyle(color: Colors.white54, height: 1.35, fontSize: 11)),
      ]),
    );
  }

  Widget _summaryRow({required int upcomingCount, required int todayCount, required int physicalCount}) {
    final items = <(String, String, IconData)>[
      ('Upcoming', '$upcomingCount', Icons.hourglass_bottom_rounded),
      ('Today', '$todayCount', Icons.today_rounded),
      ('Physical', '$physicalCount', Icons.disc_full_rounded),
    ];
    return Row(children: [
      for (var i = 0; i < items.length; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        Expanded(child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .55), borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(items[i].$3, size: 18, color: const Color(0xFFB9ADFF)),
            const SizedBox(height: 7),
            Text(items[i].$2, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            Text(items[i].$1, style: const TextStyle(color: Colors.white60, fontSize: 11)),
          ]),
        )),
      ],
    ]);
  }

  Widget _eventCard(BuildContext context, ReleaseCalendarEvent event) {
    final local = event.localTime;
    final isPast = _isPast(event);
    final date = MaterialLocalizations.of(context).formatMediumDate(local);
    final time = MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(local));
    final image = event.imageUrl?.trim() ?? '';
    final manual = event.isManual;
    final physical = event.isPhysicalMedia;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onLongPress: manual ? () => _confirmDelete(event) : null,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: image.startsWith('http')
                  ? Image.network(image, width: 74, height: 104, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _posterFallback(event))
                  : _posterFallback(event),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 6, runSpacing: 5, crossAxisAlignment: WrapCrossAlignment.center, children: [
                _eventLabel(event.category),
                if (physical) _eventLabel('Physical Media', physical: true),
                if (manual) _eventLabel('Saved'),
              ]),
              const SizedBox(height: 7),
              Text(event.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, height: 1.2)),
              const SizedBox(height: 4),
              Text(event.milestone, style: const TextStyle(color: Color(0xFFB9ADFF), fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 7),
              Text(formatReleaseCountdown(event.scheduledAt, dateOnly: event.dateOnly), style: TextStyle(color: isPast ? Colors.white60 : const Color(0xFF9CE7C5), fontSize: 14, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(event.dateOnly ? '$date · date only' : '$date · $time · device time', style: const TextStyle(color: Colors.white60, fontSize: 11)),
              if (event.note?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(event.note!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 11, height: 1.3)),
              ],
              const SizedBox(height: 5),
              Text('Source: ${event.source}', style: const TextStyle(color: Colors.white38, fontSize: 10)),
            ])),
            if (manual)
              PopupMenuButton<String>(
                tooltip: 'Release reminder options',
                onSelected: (value) {
                  if (value == 'delete') _confirmDelete(event);
                },
                itemBuilder: (_) => const <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(value: 'delete', child: Text('Remove countdown')),
                ],
              ),
          ]),
        ),
      ),
    );
  }

  Widget _posterFallback(ReleaseCalendarEvent event) => Container(
        width: 74,
        height: 104,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Icon(_iconForEvent(event), size: 30, color: const Color(0xFFB9ADFF)),
      );

  IconData _iconForEvent(ReleaseCalendarEvent event) {
    if (event.isPhysicalMedia) return Icons.album_outlined;
    return switch (event.category.toLowerCase()) {
      'movie' => Icons.movie_outlined,
      'show' => Icons.tv_outlined,
      'episode' => Icons.live_tv_outlined,
      'album' => Icons.album_outlined,
      _ => Icons.event_outlined,
    };
  }

  Widget _eventLabel(String label, {bool physical = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: (physical ? const Color(0xFFFFD18C) : const Color(0xFFB9ADFF)).withValues(alpha: .13),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: TextStyle(fontSize: 9, letterSpacing: .2, color: physical ? const Color(0xFFFFD18C) : const Color(0xFFCBC3FF), fontWeight: FontWeight.w800)),
      );

  Widget _emptyState(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 34),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .35), borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          const Icon(Icons.event_available_rounded, size: 38, color: Color(0xFFB9ADFF)),
          const SizedBox(height: 10),
          const Text('No release dates in this view', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('Catalog coverage varies by country and provider. Add a countdown for a theater date, streaming premiere, episode airing, album, DVD, Blu-ray, 4K Ultra HD or CD.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.4)),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: _addEvent, icon: const Icon(Icons.add), label: const Text('Add a release date')),
        ]),
      );

  Future<void> _confirmDelete(ReleaseCalendarEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove countdown?'),
        content: Text('Remove the saved countdown for “${event.title}” (${event.milestone})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed == true) await _deleteEvent(event);
  }
}

class _AddReleaseEventDialog extends StatefulWidget {
  const _AddReleaseEventDialog();

  @override
  State<_AddReleaseEventDialog> createState() => _AddReleaseEventDialogState();
}

class _AddReleaseEventDialogState extends State<_AddReleaseEventDialog> {
  static const Map<String, List<String>> _milestones = <String, List<String>>{
    'Movie': <String>['Theatrical release', 'Streaming release', 'Digital rental/purchase', 'DVD release', 'Blu-ray release', '4K Ultra HD release'],
    'Show': <String>['Series premiere', 'New episode · streaming release', 'New episode · first cable airing', 'Season release · streaming', 'Season on DVD', 'Season on Blu-ray', 'Season on 4K Ultra HD', 'Complete series on DVD', 'Complete series on Blu-ray', 'Complete series on 4K Ultra HD'],
    'Episode': <String>['New episode · streaming release', 'New episode · first cable airing', 'Episode becomes available to stream', 'Episode first broadcast'],
    'Album': <String>['Album release', 'Album streaming release', 'CD release'],
  };

  final TextEditingController _title = TextEditingController();
  final TextEditingController _provider = TextEditingController();
  String _category = 'Movie';
  String _milestone = 'Theatrical release';
  DateTime _date = DateTime.now().add(const Duration(days: 30));
  TimeOfDay _time = const TimeOfDay(hour: 12, minute: 0);

  @override
  void dispose() {
    _title.dispose();
    _provider.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final now = DateTime.now();
    final result = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 15),
    );
    if (result != null && mounted) setState(() => _date = result);
  }

  Future<void> _chooseTime() async {
    final result = await showTimePicker(context: context, initialTime: _time);
    if (result != null && mounted) setState(() => _time = result);
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a movie, show, episode or album title.')));
      return;
    }
    final localDate = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    final provider = _provider.text.trim();
    final event = ReleaseCalendarEvent(
      id: 'manual-${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      category: _category,
      milestone: _milestone,
      scheduledAt: localDate.toUtc(),
      source: 'Your schedule',
      note: provider.isEmpty ? 'Manual date · device local time' : 'Provider/channel: $provider · device local time',
      dateOnly: false,
      isManual: true,
    );
    Navigator.of(context).pop(event);
  }

  @override
  Widget build(BuildContext context) {
    final milestones = _milestones[_category] ?? const <String>[];
    // Derive a safe current value instead of mutating State during build.
    final selectedMilestone = milestones.contains(_milestone)
        ? _milestone
        : milestones.first;
    return AlertDialog(
      scrollable: true,
      title: const Text('Add a release countdown'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 470,
          maxHeight: MediaQuery.sizeOf(context).height * .58,
        ),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Set the exact date and local time for a premiere, airing, album or physical edition.', style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.35)),
            const SizedBox(height: 14),
            TextField(controller: _title, autofocus: true, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Title', hintText: 'Movie, show, episode or album')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Media category'),
              items: _milestones.keys.map((item) => DropdownMenuItem<String>(value: item, child: Text(item))).toList(),
              onChanged: (value) => setState(() { _category = value ?? 'Movie'; _milestone = _milestones[_category]!.first; }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selectedMilestone,
              decoration: const InputDecoration(labelText: 'Release milestone'),
              items: milestones.map((item) => DropdownMenuItem<String>(value: item, child: Text(item))).toList(),
              onChanged: (value) => setState(() => _milestone = value ?? milestones.first),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_month_outlined),
              title: const Text('Release date'),
              subtitle: Text(MaterialLocalizations.of(context).formatMediumDate(_date)),
              onTap: _chooseDate,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule_rounded),
              title: const Text('Release time'),
              subtitle: Text(_time.format(context)),
              onTap: _chooseTime,
            ),
            TextField(controller: _provider, decoration: const InputDecoration(labelText: 'Streaming service / cable network (optional)', hintText: 'Netflix, HBO, ABC…')),
            const SizedBox(height: 8),
            const Text('The time is saved as a moment and displayed in your device time zone. Notifications outside the app are not sent by this screen.', style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.35)),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_outlined), label: const Text('Save countdown')),
      ],
    );
  }
}
