import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

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
    this.sourceUrl,
    this.note,
    this.dateOnly = false,
    this.isManual = true,
    this.dateConfidence = 'Estimated',
    this.regionCode = 'US',
    this.lastVerifiedAt,
    this.dateHistory = const <Map<String, String>>[],
    this.musicReleaseType,
    this.tracklist = const <String>[],
    this.publicPopularity = 0,
  });

  final String id;
  final String title;
  final String category;
  final String milestone;
  final DateTime scheduledAt;
  final String? parentTitle;
  final String? imageUrl;
  final String source;
  final String? sourceUrl;
  final String? note;
  final bool dateOnly;
  final bool isManual;

  /// One of Confirmed, Estimated or Unconfirmed. This describes date confidence,
  /// not whether a title itself is officially announced.
  final String dateConfidence;
  final String regionCode;
  final DateTime? lastVerifiedAt;
  final List<Map<String, String>> dateHistory;

  /// Album, EP, single, live album, compilation, reissue, deluxe edition, etc.
  final String? musicReleaseType;

  /// Normalized provider popularity signal, when the source supplies one.
  final double publicPopularity;

  /// Populated only when a source actually supplies track names.
  final List<String> tracklist;

  DateTime get localTime => scheduledAt.toLocal();

  ReleaseCalendarEvent copyWith({
    String? id,
    String? title,
    String? category,
    String? milestone,
    DateTime? scheduledAt,
    String? parentTitle,
    String? imageUrl,
    String? source,
    String? sourceUrl,
    String? note,
    bool? dateOnly,
    bool? isManual,
    String? dateConfidence,
    String? regionCode,
    DateTime? lastVerifiedAt,
    List<Map<String, String>>? dateHistory,
    String? musicReleaseType,
    List<String>? tracklist,
    double? publicPopularity,
  }) =>
      ReleaseCalendarEvent(
        id: id ?? this.id,
        title: title ?? this.title,
        category: category ?? this.category,
        milestone: milestone ?? this.milestone,
        scheduledAt: scheduledAt ?? this.scheduledAt,
        parentTitle: parentTitle ?? this.parentTitle,
        imageUrl: imageUrl ?? this.imageUrl,
        source: source ?? this.source,
        sourceUrl: sourceUrl ?? this.sourceUrl,
        note: note ?? this.note,
        dateOnly: dateOnly ?? this.dateOnly,
        isManual: isManual ?? this.isManual,
        dateConfidence: dateConfidence ?? this.dateConfidence,
        regionCode: regionCode ?? this.regionCode,
        lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
        dateHistory: dateHistory ?? this.dateHistory,
        musicReleaseType: musicReleaseType ?? this.musicReleaseType,
        tracklist: tracklist ?? this.tracklist,
        publicPopularity: publicPopularity ?? this.publicPopularity,
      );

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

  Map<String, dynamic> toJson() {
    final local = scheduledAt.toLocal();
    final calendarDate =
        '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
    return <String, dynamic>{
      'id': id,
      'title': title,
      'category': category,
      'milestone': milestone,
      'scheduledAt': scheduledAt.toUtc().toIso8601String(),
      if (dateOnly) 'calendarDate': calendarDate,
      'parentTitle': parentTitle,
      'imageUrl': imageUrl,
      'source': source,
      'sourceUrl': sourceUrl,
      'note': note,
      'dateOnly': dateOnly,
      'isManual': isManual,
      'dateConfidence': dateConfidence,
      'regionCode': regionCode,
      'lastVerifiedAt': lastVerifiedAt?.toUtc().toIso8601String(),
      'dateHistory': dateHistory,
      'musicReleaseType': musicReleaseType,
      'tracklist': tracklist,
      'publicPopularity': publicPopularity,
    };
  }

  factory ReleaseCalendarEvent.fromJson(Map<String, dynamic> json) {
    final parsedDate = DateTime.tryParse(json['scheduledAt']?.toString() ?? '');
    if (parsedDate == null) {
      throw const FormatException(
          'Release event has no valid scheduledAt date.');
    }
    final dateOnly = json['dateOnly'] == true;
    final calendarDate = json['calendarDate']?.toString().trim() ?? '';
    DateTime normalizedDate = parsedDate.toUtc();
    if (dateOnly) {
      // A date-only release is a calendar day, not a UTC instant. Prefer the
      // preserved YYYY-MM-DD key so UTC offsets cannot move it to yesterday.
      final dateText = calendarDate.length >= 10
          ? calendarDate.substring(0, 10)
          : '${parsedDate.toLocal().year.toString().padLeft(4, '0')}-${parsedDate.toLocal().month.toString().padLeft(2, '0')}-${parsedDate.toLocal().day.toString().padLeft(2, '0')}';
      final date = DateTime.tryParse(dateText);
      if (date != null) {
        normalizedDate = DateTime(date.year, date.month, date.day, 12).toUtc();
      }
    }
    String text(String key, [String fallback = '']) =>
        (json[key] ?? fallback).toString().trim();
    final history = <Map<String, String>>[];
    final rawHistory = json['dateHistory'];
    if (rawHistory is List) {
      for (final row in rawHistory.whereType<Map>()) {
        history.add(row
            .map((key, value) => MapEntry(key.toString(), value.toString())));
      }
    }
    final rawTracklist = json['tracklist'];
    final tracks = rawTracklist is List
        ? rawTracklist
            .map((value) => value.toString().trim())
            .where((value) => value.isNotEmpty)
            .toList(growable: false)
        : const <String>[];
    return ReleaseCalendarEvent(
      id: text('id'),
      title: text('title', 'Untitled release'),
      category: text('category', 'Movie'),
      milestone: text('milestone', 'Release'),
      scheduledAt: normalizedDate,
      parentTitle: text('parentTitle').isEmpty ? null : text('parentTitle'),
      imageUrl: text('imageUrl').isEmpty ? null : text('imageUrl'),
      source: text('source', 'Your schedule'),
      sourceUrl: text('sourceUrl').isEmpty ? null : text('sourceUrl'),
      note: text('note').isEmpty ? null : text('note'),
      dateOnly: dateOnly,
      isManual: json['isManual'] != false,
      dateConfidence: text('dateConfidence',
          json['isManual'] == true ? 'Unconfirmed' : 'Estimated'),
      regionCode: text('regionCode', 'US').toUpperCase(),
      lastVerifiedAt: DateTime.tryParse(text('lastVerifiedAt')),
      dateHistory: history,
      musicReleaseType:
          text('musicReleaseType').isEmpty ? null : text('musicReleaseType'),
      tracklist: tracks,
      publicPopularity: json['publicPopularity'] is num
          ? (json['publicPopularity'] as num).toDouble()
          : double.tryParse(text('publicPopularity')) ?? 0,
    );
  }
}

/// A compact editorial safety-net for high-interest releases that providers may
/// omit, index late, or rank below the first pages of their feeds. Every date
/// below is tied to a published studio, platform, label, or music-store listing.
/// The list is deliberately independent of authentication and catalog APIs.
List<ReleaseCalendarEvent> buildFeaturedReleaseEvents({
  DateTime? now,
  String regionCode = 'US',
}) {
  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  final region = regionCode.trim().toUpperCase();
  final rows = <Map<String, String>>[];

  void add({
    required String id,
    required String title,
    required String category,
    required String milestone,
    required String date,
    required String source,
    required String sourceUrl,
    required String note,
    String? mxDate,
    String? parentTitle,
    String? musicReleaseType,
  }) {
    rows.add(<String, String>{
      'id': id,
      'title': title,
      'category': category,
      'milestone': milestone,
      'date': region == 'MX' && mxDate != null ? mxDate : date,
      'source': source,
      'sourceUrl': sourceUrl,
      'note': note,
      'dateConfidence':
          region == 'MX' && mxDate == null ? 'Estimated' : 'Confirmed',
      if (musicReleaseType != null) 'musicReleaseType': musicReleaseType,
      if (parentTitle != null) 'parentTitle': parentTitle,
    });
  }

  // The highest-profile releases are intentionally declared first so the
  // spotlight strip opens with tent-pole films and current headline series.
  add(
    id: 'featured-release-avengers-doomsday',
    title: 'Avengers: Doomsday',
    category: 'Movie',
    milestone: 'Theatrical release',
    date: '2026-12-18',
    mxDate: '2026-12-17',
    source: 'Disney Movies (official)',
    sourceUrl: 'https://movies.disney.com/avengers-doomsday',
    note: region == 'MX'
        ? 'Official theatrical release listing. This featured date uses the Mexico date; local showtimes may vary.'
        : 'Official U.S. theatrical release date. Local cinema dates may vary by region.',
  );
  add(
    id: 'featured-release-dune-part-three',
    title: 'Dune: Part Three',
    category: 'Movie',
    milestone: 'Theatrical release',
    date: '2026-12-18',
    mxDate: '2026-12-16',
    source: 'Warner Bros. Pictures (official)',
    sourceUrl: 'https://www.youtube.com/watch?v=rGNc8RRggzo',
    note: region == 'MX'
        ? 'Warner Bros. lists international theatrical release beginning Dec 16; local showtimes may vary.'
        : 'Warner Bros. lists North American theatrical release on Dec 18; international dates may differ.',
  );
  add(
    id: 'featured-release-visionquest-show',
    title: 'VisionQuest',
    category: 'Show',
    milestone: 'Upcoming episodes',
    date: '2026-11-04',
    source: 'Disney+ (official)',
    sourceUrl: 'https://www.disneyplus.com/explore/articles/marvel-visionquest',
    note:
        'New episodes continue Wednesdays: Episode 7 on Nov 4 and the 8-episode season finale on Nov 11.',
  );
  add(
    id: 'featured-release-visionquest-s01e07',
    title: 'VisionQuest · S01E07',
    category: 'Episode',
    milestone: 'Episode 7',
    date: '2026-11-04',
    source: 'Disney+ (official)',
    sourceUrl: 'https://www.disneyplus.com/explore/articles/marvel-visionquest',
    note: 'Disney+ schedule: Episode 7 streams November 4, 2026.',
    parentTitle: 'VisionQuest',
  );
  add(
    id: 'featured-release-visionquest-s01e08',
    title: 'VisionQuest · S01E08 (Finale)',
    category: 'Episode',
    milestone: 'Season finale',
    date: '2026-11-11',
    source: 'Disney+ (official)',
    sourceUrl: 'https://www.disneyplus.com/explore/articles/marvel-visionquest',
    note:
        'Final episode of the 8-episode season, scheduled for November 11, 2026.',
    parentTitle: 'VisionQuest',
  );
  add(
    id: 'featured-release-cat-in-the-hat',
    title: 'The Cat in the Hat',
    category: 'Movie',
    milestone: 'Theatrical release',
    date: '2026-11-06',
    mxDate: '2026-11-04',
    source: 'Warner Bros. (official)',
    sourceUrl: 'https://www.catinthehatfilm.com/',
    note: region == 'MX'
        ? 'Warner Bros. lists international theatrical releases beginning Nov 4; confirm local showtimes.'
        : 'Warner Bros. lists a North American theatrical release on Nov 6; regional dates may differ.',
  );
  add(
    id: 'featured-release-godzilla-minus-zero',
    title: 'Godzilla Minus Zero',
    category: 'Movie',
    milestone: 'Theatrical release',
    date: '2026-11-06',
    source: 'TOHO / GKIDS (official)',
    sourceUrl: 'https://godzilla.com/pages/godzilla-minus-zero',
    note:
        'Japan release Nov 3; wide North American release Nov 6. A Mexico-specific date was not confirmed by this source.',
  );
  add(
    id: 'featured-release-hunger-games-sunrise',
    title: 'The Hunger Games: Sunrise on the Reaping',
    category: 'Movie',
    milestone: 'Theatrical release',
    date: '2026-11-20',
    source: 'Lionsgate (official)',
    sourceUrl:
        'https://investors.lionsgate.com/news-events/news/news-details/2024/LIONSGATE-TO-ADAPT-SUZANNE-COLLINSS-NEWLY-ANNOUNCED-HUNGER-GAMES-NOVEL-SUNRISE-ON-THE-REAPING-INTO-MAJOR-MOTION-PICTURE/',
    note:
        'Official North American theatrical date; local release dates may differ.',
  );
  add(
    id: 'featured-release-angry-birds-3',
    title: 'The Angry Birds Movie 3',
    category: 'Movie',
    milestone: 'Theatrical release',
    date: '2026-12-23',
    source: 'Paramount / Angry Birds (official)',
    sourceUrl: 'https://www.angrybirds.com/angry-birds-movie-3/',
    note:
        'Official theatrical release listing. Confirm local showtimes closer to release.',
  );

  // Newly announced albums and EPs. MusicBrainz is not a complete upcoming
  // release calendar, so these label/store listings are included as fallbacks.
  add(
    id: 'featured-release-album-qotsa-perfecth',
    title: 'Perfecth · Queens of the Stone Age',
    category: 'Album',
    milestone: 'Album release',
    date: '2026-10-30',
    source: 'Apple Music · pre-release',
    sourceUrl: 'https://music.apple.com/us/album/perfecth/6797444451',
    note:
        'Apple Music lists Oct 30, 2026. The release date is Oct 30, not Oct 29.',
    parentTitle: 'Perfecth',
  );
  add(
    id: 'featured-release-album-clubsos',
    title: 'CLUBSOS VOL. 1 - EP · 5 Seconds of Summer',
    category: 'Album',
    milestone: 'EP release',
    date: '2026-10-30',
    source: 'Apple Music · pre-release',
    sourceUrl: 'https://music.apple.com/us/album/clubsos-vol-1-ep/6820274859',
    note: 'Apple Music lists this EP for Oct 30, 2026.',
    parentTitle: 'CLUBSOS VOL. 1 - EP',
    musicReleaseType: 'EP',
  );
  add(
    id: 'featured-release-album-nickelback',
    title: 'Everything Under The Sun · Nickelback',
    category: 'Album',
    milestone: 'Album release',
    date: '2026-10-30',
    source: 'Apple Music · pre-release',
    sourceUrl:
        'https://music.apple.com/us/album/everything-under-the-sun/6784018115',
    note: 'Apple Music and Live Nation list the album for Oct 30, 2026.',
    parentTitle: 'Everything Under The Sun',
  );
  add(
    id: 'featured-release-album-kings-of-leon',
    title: 'O My Beloved · Kings of Leon',
    category: 'Album',
    milestone: 'Album release',
    date: '2026-11-06',
    source: 'Apple Music · pre-release',
    sourceUrl: 'https://music.apple.com/us/album/o-my-beloved/6802901441',
    note: 'Apple Music lists the album for Nov 6, 2026.',
    parentTitle: 'O My Beloved',
  );
  add(
    id: 'featured-release-album-la-roux',
    title: 'Old Flames · La Roux',
    category: 'Album',
    milestone: 'Album release',
    date: '2026-11-06',
    source: 'La Roux (official)',
    sourceUrl: 'https://laroux.co.uk/',
    note: 'The artist website lists the new album for Nov 6, 2026.',
    parentTitle: 'Old Flames',
  );
  add(
    id: 'featured-release-album-lil-baby',
    title: 'FRESH · Lil Baby',
    category: 'Album',
    milestone: 'Album release',
    date: '2026-11-06',
    source: 'Universal Music / Apple Music',
    sourceUrl: 'https://music.apple.com/us/album/fresh/6823820064',
    note:
        'Universal Music announced Nov 6, 2026; the album is available to pre-order.',
    parentTitle: 'FRESH',
  );
  add(
    id: 'featured-release-album-snoh-aalegra',
    title: 'Legendary Love · Snoh Aalegra',
    category: 'Album',
    milestone: 'Album release',
    date: '2026-11-13',
    source: 'Apple Music · pre-release',
    sourceUrl: 'https://music.apple.com/us/album/legendary-love/6819862096',
    note: 'Apple Music lists the album for Nov 13, 2026.',
    parentTitle: 'Legendary Love',
  );
  add(
    id: 'featured-release-album-trouble-mountain',
    title: 'Trouble Mountain · Aesop Rock & Blockhead',
    category: 'Album',
    milestone: 'Album release',
    date: '2026-11-13',
    source: 'Apple Music · pre-release',
    sourceUrl: 'https://music.apple.com/us/album/trouble-mountain/6790569121',
    note: 'Current Apple Music listings show Nov 13, 2026 (not Nov 6).',
    parentTitle: 'Trouble Mountain',
  );
  add(
    id: 'featured-release-album-u2-carnaval-de-luz',
    title: 'Carnaval De Luz · U2',
    category: 'Album',
    milestone: 'Album release',
    date: '2026-11-13',
    source: 'U2 (official)',
    sourceUrl: 'https://www.u2.com/products/carnaval-de-luz',
    note: 'U2 and its label list the album for Nov 13, 2026.',
    parentTitle: 'Carnaval De Luz',
  );

  final events = <ReleaseCalendarEvent>[];
  for (final row in rows) {
    final date = DateTime.tryParse(row['date'] ?? '');
    if (date == null) continue;
    final releaseDay = DateTime(date.year, date.month, date.day);
    if (releaseDay.isBefore(today)) continue;
    final atNoon = DateTime(date.year, date.month, date.day, 12);
    events.add(ReleaseCalendarEvent(
      id: row['id']!,
      title: row['title']!,
      category: row['category']!,
      milestone: row['milestone']!,
      scheduledAt: atNoon.toUtc(),
      parentTitle: row['parentTitle'],
      source: row['source']!,
      sourceUrl: row['sourceUrl'],
      note: row['note'],
      dateOnly: true,
      isManual: false,
      dateConfidence: row['dateConfidence'] ?? 'Confirmed',
      regionCode: region,
      // These fallback rows are a checked-in snapshot, not a live verification
      // performed on each screen open. Keep the snapshot date honest.
      lastVerifiedAt: DateTime(2026, 10, 29),
      musicReleaseType: row['musicReleaseType'] ??
          (row['category'] == 'Album' ? 'Studio album' : null),
    ));
  }
  return List<ReleaseCalendarEvent>.unmodifiable(events);
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
    final releaseDay =
        DateTime(releaseLocal.year, releaseLocal.month, releaseLocal.day);
    final currentDay =
        DateTime(currentLocal.year, currentLocal.month, currentLocal.day);
    final dayDifference = releaseDay.difference(currentDay).inDays;
    if (dayDifference < 0) {
      return dayDifference == -1
          ? 'Released yesterday'
          : 'Released ${dayDifference.abs()}d ago';
    }
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
    final hour = (match == null
            ? 12
            : (int.tryParse(match.group(1)!) ?? 12).clamp(0, 23))
        .toInt();
    final minute =
        (match == null ? 0 : (int.tryParse(match.group(2)!) ?? 0).clamp(0, 59))
            .toInt();
    return DateTime(parsed.year, parsed.month, parsed.day, hour, minute)
        .toUtc();
  }
  return parsed.toUtc();
}

/// Predictable, testable ranking heuristic for the Coming Soon discovery feed.
/// It supplements provider popularity with profile follows, release proximity,
/// known franchises and date confidence; it is not presented as an external chart.
int releaseAnticipationScore(
  ReleaseCalendarEvent event, {
  DateTime? now,
  bool isFollowed = false,
}) {
  final current = now ?? DateTime.now();
  final localDate = event.localTime;
  final day = DateTime(localDate.year, localDate.month, localDate.day);
  final today = DateTime(current.year, current.month, current.day);
  final days = day.difference(today).inDays;
  if (days < 0) return -100;
  var score = 0;
  if (isFollowed) score += 50;
  if (days <= 7) {
    score += 18;
  } else if (days <= 30) {
    score += 12;
  } else if (days <= 90) {
    score += 8;
  } else if (days <= 180) {
    score += 4;
  }
  switch (event.dateConfidence.toLowerCase()) {
    case 'confirmed':
      score += 12;
      break;
    case 'estimated':
      score += 6;
      break;
  }
  score += (event.publicPopularity.clamp(0, 100) / 4).round();
  final text = '${event.title} ${event.parentTitle ?? ''} ${event.note ?? ''}'
      .toLowerCase();
  const headlineTerms = <String>[
    'avengers',
    'marvel',
    'visionquest',
    'dune',
    'hunger games',
    'godzilla',
    'queens of the stone age',
    '5 seconds of summer',
    'nickelback',
    'u2',
    'la roux',
    'aesop rock',
    'blockhead',
    'snoh aalegra',
    'lil baby',
  ];
  if (headlineTerms.any(text.contains)) score += 25;
  if (text.contains('franchise') ||
      text.contains('season finale') ||
      text.contains('finale')) {
    score += 8;
  }
  if (event.category.toLowerCase() == 'episode') score += 4;
  if (event.source.toLowerCase().contains('official') ||
      event.source.toLowerCase().contains('apple music')) {
    score += 3;
  }
  return score;
}

String explainReleaseRelevance(
  ReleaseCalendarEvent event, {
  bool isFollowed = false,
  DateTime? now,
}) {
  if (isFollowed) {
    return 'Because you follow ${event.parentTitle ?? event.title}.';
  }
  final titleText = '${event.title} ${event.parentTitle ?? ''}'.toLowerCase();
  if (titleText.contains('visionquest') ||
      event.category.toLowerCase() == 'episode') {
    return 'An upcoming show episode or season milestone.';
  }
  if (releaseAnticipationScore(event, now: now) >= 45) {
    return 'Headline release with a near-term or confirmed date.';
  }
  final localDate = event.localTime;
  final current = now ?? DateTime.now();
  final days = DateTime(localDate.year, localDate.month, localDate.day)
      .difference(DateTime(current.year, current.month, current.day))
      .inDays;
  if (days >= 0 && days <= 7) return 'Released soon—within the next week.';
  if (event.dateConfidence.toLowerCase() == 'confirmed') {
    return 'Confirmed release date from ${event.source}.';
  }
  return 'Upcoming catalog release; date confidence is ${event.dateConfidence.toLowerCase()}.';
}

class ComingSoonReleaseScreen extends StatefulWidget {
  const ComingSoonReleaseScreen({super.key});

  @override
  State<ComingSoonReleaseScreen> createState() =>
      _ComingSoonReleaseScreenState();
}

class _ComingSoonReleaseScreenState extends State<ComingSoonReleaseScreen> {
  static const List<String> _filters = <String>[
    'All',
    'Movies',
    'Shows',
    'Episodes',
    'Albums',
    'EPs',
    'Singles',
    'Music Videos',
    'Theatrical',
    'Streaming',
    'Digital',
    'Physical Media',
  ];

  List<ReleaseCalendarEvent> _manualEvents = <ReleaseCalendarEvent>[];
  List<ReleaseCalendarEvent> _events = <ReleaseCalendarEvent>[];
  List<ReleaseCalendarEvent> _featuredEvents = <ReleaseCalendarEvent>[];
  String _filter = 'All';
  String _search = '';
  String _sortMode = 'For you';
  Set<String> _followedTerms = <String>{};
  Map<String, DateTime> _reminders = <String, DateTime>{};
  Set<String> _notifiedReminderIds = <String>{};
  Map<String, String> _providerStatus = <String, String>{
    'TMDB': 'Not checked',
    'MusicBrainz': 'Not checked'
  };
  DateTime? _lastRefreshedAt;
  DateTime? _lastSuccessfulSyncAt;
  bool _onlyFollowed = false;
  int _filteredOutCount = 0;
  int _reportedIssueCount = 0;
  List<String> _lastRefreshChanges = <String>[];
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
      if (!mounted) return;
      setState(() {});
      unawaited(_checkDueReminders());
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  String _profileStorageKey(String suffix) {
    final controller = AppController.instance;
    final account = controller.currentAccount?.id.trim();
    final profile = controller.currentProfile?.id.trim();
    final accountKey = account == null || account.isEmpty ? 'local' : account;
    final profileKey = profile == null || profile.isEmpty ? 'default' : profile;
    return 'coming_soon_${suffix}_${accountKey}_$profileKey';
  }

  String get _storageKey => _profileStorageKey('release_events_v1');
  String get _followsKey => _profileStorageKey('followed_terms_v1');
  String get _remindersKey => _profileStorageKey('reminders_v1');
  String get _notifiedKey => _profileStorageKey('notified_reminders_v1');
  String get _lastDatesKey => _profileStorageKey('last_seen_dates_v1');
  String get _dateHistoryKey => _profileStorageKey('date_history_v1');
  String get _reportsKey => _profileStorageKey('discovery_reports_v1');
  String get _lastRefreshKey => _profileStorageKey('last_refresh_v1');
  String get _lastSuccessfulSyncKey =>
      _profileStorageKey('last_successful_sync_v1');
  String get _trailerStateKey =>
      _profileStorageKey('trailer_snapshot_state_v1');

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
      final followRaw = prefs.getStringList(_followsKey) ?? const <String>[];
      final remindersRaw = prefs.getString(_remindersKey);
      final reminderMap = <String, DateTime>{};
      if (remindersRaw != null) {
        try {
          final parsed = jsonDecode(remindersRaw);
          if (parsed is Map) {
            for (final entry in parsed.entries) {
              final value = DateTime.tryParse(entry.value?.toString() ?? '');
              if (value != null) reminderMap[entry.key.toString()] = value;
            }
          }
        } catch (_) {}
      }
      final notifiedIds = prefs.getStringList(_notifiedKey) ?? const <String>[];
      final lastRefreshText = prefs.getString(_lastRefreshKey);
      final successfulSyncText = prefs.getString(_lastSuccessfulSyncKey);
      final reportedRaw = prefs.getString(_reportsKey);
      var reportsCount = 0;
      if (reportedRaw != null) {
        try {
          final decoded = jsonDecode(reportedRaw);
          if (decoded is List) reportsCount = decoded.length;
        } catch (_) {}
      }
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
                if (event.id.isNotEmpty && event.title.isNotEmpty) {
                  manual.add(event);
                }
              } catch (_) {
                // One malformed local reminder must not hide the rest.
              }
            }
          }
        } catch (_) {
          _providerMessage =
              'Some saved reminders could not be read. You can add them again.';
        }
      }

      final localEvents = _eventsFromLibrary(AppController.instance.library,
          regionCode: (regionCode ?? 'US').toUpperCase());
      final featuredEvents = buildFeaturedReleaseEvents(
        regionCode: regionCode ?? 'US',
      );
      var providerEvents = <ReleaseCalendarEvent>[];
      var tmdbStatus = 'Skipped: signed out';
      var musicStatus = 'Skipped: signed out';
      if (AppController.instance.isBackendAuthenticated) {
        final movieTvFuture =
            CinematicTitleMetadataService.lookupUpcomingCalendarEvents(
          regionCode: regionCode,
          movieLimit: 60,
          tvLimit: 48,
        );
        final albumFuture =
            AppController.instance.backendApi.getUpcomingMusicAlbums(limit: 60);
        try {
          final payload = await movieTvFuture;
          providerEvents.addAll(payload.map(
              (rawEvent) => ReleaseCalendarEvent.fromJson(rawEvent).copyWith(
                    regionCode: (regionCode ?? 'US').toUpperCase(),
                    lastVerifiedAt: DateTime.now(),
                    dateConfidence: 'Estimated',
                  )));
          tmdbStatus =
              'Success · ${providerEvents.length} movie/TV candidates · multi-page feed with configured result caps';
        } catch (error) {
          tmdbStatus = 'Failed · ${error.runtimeType}';
          _providerMessage =
              'Live movie and TV dates are temporarily unavailable. Your library dates and saved reminders are still shown.';
        }
        try {
          final albumPayload = await albumFuture;
          final rawAlbums = albumPayload['items'];
          if (rawAlbums is List) {
            final totalCatalogMatches = albumPayload['count'] is num
                ? (albumPayload['count'] as num).toInt()
                : rawAlbums.length;
            musicStatus =
                'Success · ${rawAlbums.length} displayed / $totalCatalogMatches catalog matches${totalCatalogMatches >= 300 ? ' · 300-row scan cap reached' : ''}';
            if (rawAlbums.isEmpty) {
              _providerMessage ??=
                  'MusicBrainz returned no upcoming album dates. Verified headline album releases and saved reminders are still included; refresh later for wider catalog coverage.';
            }
            for (final rawAlbum in rawAlbums.whereType<Map>()) {
              final album = Map<String, dynamic>.from(rawAlbum);
              final rawDate =
                  (album['releaseDate'] ?? album['firstReleaseDate'] ?? '')
                      .toString()
                      .trim();
              if (rawDate.length < 10) continue;
              final parsedDate = DateTime.tryParse(rawDate.substring(0, 10));
              if (parsedDate == null) continue;
              final localNoon = DateTime(
                  parsedDate.year, parsedDate.month, parsedDate.day, 12);
              if (localNoon.isBefore(
                      DateTime.now().subtract(const Duration(days: 1))) ||
                  localNoon
                      .isAfter(DateTime.now().add(const Duration(days: 366)))) {
                continue;
              }
              final title =
                  (album['title'] ?? 'Untitled album').toString().trim();
              final artist = (album['artist'] ?? '').toString().trim();
              final albumId = (album['id'] ?? '').toString().trim();
              if (title.isEmpty || albumId.isEmpty) continue;
              final releaseKind = _classifyMusicRelease(
                primaryType: album['primaryType']?.toString() ??
                    album['type']?.toString() ??
                    'Album',
                secondaryTypes: album['secondaryTypes'] is List
                    ? (album['secondaryTypes'] as List)
                        .map((value) => value.toString())
                        .toList()
                    : const <String>[],
                title: title,
              );
              providerEvents.add(ReleaseCalendarEvent(
                id: 'musicbrainz-album-$albumId',
                title: artist.isEmpty ? title : '$title · $artist',
                parentTitle: title,
                category: releaseKind == 'Single' ? 'Single' : 'Album',
                milestone: releaseKind == 'Single'
                    ? 'Single release'
                    : releaseKind == 'EP'
                        ? 'EP release'
                        : 'Album release',
                scheduledAt: localNoon.toUtc(),
                dateOnly: true,
                imageUrl:
                    (album['imageUrl'] ?? album['coverArtUrl'])?.toString(),
                sourceUrl:
                    (album['releaseUrl']?.toString().trim().isNotEmpty ?? false)
                        ? album['releaseUrl'].toString().trim()
                        : null,
                source: 'MusicBrainz',
                isManual: false,
                note:
                    'Global/first-release date from MusicBrainz, not a country-specific availability date. Announcements and local release dates may change.',
                dateConfidence: 'Estimated',
                regionCode: 'GLOBAL',
                lastVerifiedAt: DateTime.now(),
                musicReleaseType: releaseKind,
                tracklist: album['tracklist'] is List
                    ? (album['tracklist'] as List)
                        .map((value) => value.toString())
                        .toList(growable: false)
                    : const <String>[],
              ));
            }
          }
        } catch (error) {
          musicStatus = 'Failed · ${error.runtimeType}';
          _providerMessage ??=
              'Upcoming album dates are temporarily unavailable. You can still add album countdowns manually.';
        }
      } else {
        _providerMessage =
            'Showing verified headline releases, imported-library dates, and saved reminders. Sign in to load the wider TMDB and MusicBrainz catalog.';
      }

      final merged = <String, ReleaseCalendarEvent>{};
      for (final event in <ReleaseCalendarEvent>[
        ...providerEvents,
        ...localEvents,
        ...featuredEvents,
        ...manual
      ]) {
        final key = _dedupeKey(event);
        final existing = merged[key];
        // User-entered dates intentionally win over provider dates for the same
        // title/milestone/date because they can be region- and service-specific.
        if (existing == null || event.isManual) {
          merged[key] = event;
        } else if ((existing.sourceUrl?.trim().isNotEmpty ?? false) == false &&
            (event.sourceUrl?.trim().isNotEmpty ?? false)) {
          // Keep the provider poster/source, but attach the verified official
          // listing URL so the filtered list remains traceable too.
          merged[key] = ReleaseCalendarEvent(
            id: existing.id,
            title: existing.title,
            category: existing.category,
            milestone: existing.milestone,
            scheduledAt: existing.scheduledAt,
            parentTitle: existing.parentTitle ?? event.parentTitle,
            imageUrl: existing.imageUrl ?? event.imageUrl,
            source: existing.source,
            sourceUrl: event.sourceUrl,
            note: existing.note ?? event.note,
            dateOnly: existing.dateOnly,
            isManual: existing.isManual,
            dateConfidence: existing.dateConfidence,
            regionCode: existing.regionCode,
            lastVerifiedAt: existing.lastVerifiedAt,
            dateHistory: existing.dateHistory,
            musicReleaseType: existing.musicReleaseType,
            tracklist: existing.tracklist,
            publicPopularity: existing.publicPopularity,
          );
        }
      }
      final previousDates = <String, String>{};
      final previousHistory = <String, List<Map<String, String>>>{};
      try {
        final decodedDates = jsonDecode(prefs.getString(_lastDatesKey) ?? '{}');
        if (decodedDates is Map) {
          for (final entry in decodedDates.entries) {
            previousDates[entry.key.toString()] = entry.value.toString();
          }
        }
      } catch (_) {}
      try {
        final decodedHistory =
            jsonDecode(prefs.getString(_dateHistoryKey) ?? '{}');
        if (decodedHistory is Map) {
          for (final entry in decodedHistory.entries) {
            final rows = entry.value;
            if (rows is List) {
              previousHistory[entry.key.toString()] = rows
                  .whereType<Map>()
                  .map((row) => row.map((key, value) =>
                      MapEntry(key.toString(), value.toString())))
                  .toList();
            }
          }
        }
      } catch (_) {}
      // Keep the last observed date for releases missing from a temporary provider
      // response. If they reappear later, changes can still be detected.
      final newLastDates = <String, String>{...previousDates};
      final changes = <String>[];
      final previousTrailerIds = <String, List<String>>{};
      try {
        final decodedTrailers =
            jsonDecode(prefs.getString(_trailerStateKey) ?? '{}');
        if (decodedTrailers is Map) {
          for (final entry in decodedTrailers.entries) {
            if (entry.value is List) {
              previousTrailerIds[entry.key.toString()] = (entry.value as List)
                  .map((value) => value.toString())
                  .toList(growable: false);
            }
          }
        }
      } catch (_) {}
      final currentTrailerIds = <String, List<String>>{...previousTrailerIds};
      final trailerChanges = <String>[];
      final followedForRefresh = followRaw
          .map(_normalizeFollowTerm)
          .where((term) => term.isNotEmpty)
          .toSet();
      final checkedTrailerProviders = <String>{};
      if (AppController.instance.isBackendAuthenticated &&
          followedForRefresh.isNotEmpty) {
        final followedTitles = providerEvents.where((event) =>
            <String>{'movie', 'show', 'episode'}
                .contains(event.category.toLowerCase()) &&
            !_isPast(event) &&
            _termsForEvent(event).any(followedForRefresh.contains));
        for (final event in followedTitles) {
          final match = RegExp(r'^tmdb-(movie|tv)-(\d+)').firstMatch(event.id);
          if (match == null) continue;
          final mediaType = match.group(1)!;
          final providerId = int.tryParse(match.group(2)!);
          if (providerId == null) continue;
          final trailerKey = '$mediaType:$providerId';
          if (!checkedTrailerProviders.add(trailerKey)) continue;
          if (checkedTrailerProviders.length > 6) break;
          try {
            final snapshot =
                await CinematicTitleMetadataService.lookupTrailerSnapshot(
              providerId: providerId,
              isTv: mediaType == 'tv',
            );
            if (snapshot['success'] != true) continue;
            final rawVideos = snapshot['videos'];
            final videos = rawVideos is List
                ? rawVideos
                    .whereType<Map>()
                    .map((video) => Map<String, dynamic>.from(video))
                    .toList(growable: false)
                : const <Map<String, dynamic>>[];
            final videoIds = videos
                .map((video) => (video['id'] ?? video['key'] ?? '').toString())
                .where((id) => id.isNotEmpty)
                .toList(growable: false);
            if (previousTrailerIds.containsKey(trailerKey)) {
              final oldIds = previousTrailerIds[trailerKey]!.toSet();
              final fresh = videos
                  .where((video) => !oldIds
                      .contains((video['id'] ?? video['key'] ?? '').toString()))
                  .toList(growable: false);
              if (fresh.isNotEmpty) {
                final newest = fresh.first;
                trailerChanges.add(
                    'New ${newest['type'] ?? 'trailer'} for ${event.parentTitle ?? event.title}: ${newest['name'] ?? 'new official video'}');
              }
            }
            currentTrailerIds[trailerKey] = videoIds;
          } catch (_) {
            // A trailer check must never block the release calendar.
          }
        }
      }
      if (currentTrailerIds.length > 300) {
        final keys = currentTrailerIds.keys
            .take(currentTrailerIds.length - 300)
            .toList();
        currentTrailerIds.removeWhere((key, _) => keys.contains(key));
      }
      await prefs.setString(_trailerStateKey, jsonEncode(currentTrailerIds));
      changes.addAll(trailerChanges);
      final tracked = <ReleaseCalendarEvent>[];
      for (final original in merged.values) {
        final stableKey =
            original.id.isNotEmpty ? original.id : _dedupeKey(original);
        final dateText = original.localTime.toIso8601String().substring(0, 10);
        final oldDate = previousDates[stableKey];
        final history = <Map<String, String>>[
          ...(previousHistory[stableKey] ?? const <Map<String, String>>[]),
          ...original.dateHistory
        ];
        if (oldDate != null && oldDate != dateText && !original.isManual) {
          history.add(<String, String>{
            'previousDate': oldDate,
            'newDate': dateText,
            'detectedAt': DateTime.now().toIso8601String(),
            'source': original.source,
          });
          final oldParsed = DateTime.tryParse(oldDate);
          final newParsed = DateTime.tryParse(dateText);
          final changeLabel = oldParsed != null &&
                  newParsed != null &&
                  newParsed.isAfter(oldParsed)
              ? 'Delayed/rescheduled'
              : 'Date updated';
          changes.add('$changeLabel: ${original.title}: $oldDate → $dateText');
        } else if (oldDate == null &&
            lastRefreshText != null &&
            !original.isManual &&
            !_isPast(original)) {
          final titleTerms = <String>{
            _normalizeFollowTerm(original.title),
            _normalizeFollowTerm(original.parentTitle ?? ''),
            ...original.title.split(' · ').map(_normalizeFollowTerm),
          };
          if (titleTerms
              .any(followRaw.map(_normalizeFollowTerm).toSet().contains)) {
            changes.add('New followed release: ${original.title} · $dateText');
          }
        }
        newLastDates[stableKey] = dateText;
        tracked.add(original.copyWith(
          dateHistory: history,
          lastVerifiedAt: original.lastVerifiedAt ?? DateTime.now(),
        ));
      }
      await prefs.setString(_lastDatesKey, jsonEncode(newLastDates));
      final allHistory = <String, dynamic>{
        for (final entry in previousHistory.entries)
          if (entry.value.isNotEmpty) entry.key: entry.value,
      };
      for (final event in tracked) {
        final key = event.id.isNotEmpty ? event.id : _dedupeKey(event);
        if (event.dateHistory.isNotEmpty) allHistory[key] = event.dateHistory;
      }
      await prefs.setString(_dateHistoryKey, jsonEncode(allHistory));
      final refreshedAt = DateTime.now();
      await prefs.setString(_lastRefreshKey, refreshedAt.toIso8601String());
      final successfulSync =
          tmdbStatus.startsWith('Success') || musicStatus.startsWith('Success');
      if (successfulSync) {
        await prefs.setString(
            _lastSuccessfulSyncKey, refreshedAt.toIso8601String());
      }
      final sorted = _sortEvents(tracked);
      if (!mounted) return;
      setState(() {
        _followedTerms = followRaw
            .map(_normalizeFollowTerm)
            .where((term) => term.isNotEmpty)
            .toSet();
        _reminders = reminderMap;
        _notifiedReminderIds = notifiedIds.toSet();
        _lastRefreshedAt = refreshedAt;
        _lastSuccessfulSyncAt = successfulSync
            ? refreshedAt
            : DateTime.tryParse(successfulSyncText ?? '');
        _reportedIssueCount = reportsCount;
        _providerStatus = <String, String>{
          'TMDB': tmdbStatus,
          'MusicBrainz': musicStatus
        };
        _lastRefreshChanges = changes;
        _filteredOutCount = (providerEvents.length +
                localEvents.length +
                featuredEvents.length +
                manual.length) -
            tracked.length;
        _manualEvents = manual;
        _events = sorted;
        _featuredEvents = featuredEvents.map((featured) {
          final featuredKey = _dedupeKey(featured);
          ReleaseCalendarEvent? catalogMatch;
          for (final candidate in providerEvents) {
            if (_dedupeKey(candidate) == featuredKey &&
                (candidate.imageUrl?.trim().isNotEmpty ?? false)) {
              catalogMatch = candidate;
              break;
            }
          }
          if (catalogMatch == null) return featured;
          return ReleaseCalendarEvent(
            id: featured.id,
            title: featured.title,
            category: featured.category,
            milestone: featured.milestone,
            scheduledAt: featured.scheduledAt,
            parentTitle: featured.parentTitle,
            imageUrl: catalogMatch.imageUrl,
            source: featured.source,
            sourceUrl: featured.sourceUrl,
            note: featured.note,
            dateOnly: featured.dateOnly,
            isManual: false,
            dateConfidence: featured.dateConfidence,
            regionCode: featured.regionCode,
            lastVerifiedAt: featured.lastVerifiedAt,
            dateHistory: featured.dateHistory,
            musicReleaseType: featured.musicReleaseType,
            tracklist: featured.tracklist,
            publicPopularity: catalogMatch.publicPopularity,
          );
        }).toList(growable: false);
        _loading = false;
      });
      if (changes.isNotEmpty && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Coming Soon alert: ${changes.first}'),
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
                label: 'Review', onPressed: _showHealthDashboard),
          ));
        });
      }
      unawaited(_checkDueReminders());
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _providerMessage ??=
              'Unable to load release dates. Try refreshing or add one manually.';
        });
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  String _normalizeFollowTerm(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  List<String> _termsForEvent(ReleaseCalendarEvent event) {
    final terms = <String>{};
    void add(String? value) {
      final normalized = _normalizeFollowTerm(value ?? '');
      if (normalized.length >= 2) terms.add(normalized);
    }

    add(event.title);
    add(event.parentTitle);
    // For title · artist music rows, support following either the release or artist.
    final split = event.title.split(' · ');
    if (split.length > 1) add(split.last);
    final searchText =
        _normalizeFollowTerm('${event.title} ${event.parentTitle ?? ''}');
    const franchiseTerms = <String, List<String>>{
      'avengers': <String>['marvel', 'avengers'],
      'visionquest': <String>['marvel', 'visionquest'],
      'marvel': <String>['marvel'],
      'dune': <String>['dune'],
      'hunger games': <String>['hunger games'],
      'godzilla': <String>['godzilla'],
      'angry birds': <String>['angry birds'],
      'star wars': <String>['star wars'],
      'spider man': <String>['spider man'],
    };
    for (final entry in franchiseTerms.entries) {
      if (searchText.contains(entry.key)) terms.addAll(entry.value);
    }
    return terms.toList(growable: false);
  }

  bool _isFollowed(ReleaseCalendarEvent event) =>
      _termsForEvent(event).any(_followedTerms.contains);

  int _score(ReleaseCalendarEvent event) => releaseAnticipationScore(
        event,
        isFollowed: _isFollowed(event),
      );

  String _whySeeing(ReleaseCalendarEvent event) => explainReleaseRelevance(
        event,
        isFollowed: _isFollowed(event),
      );

  String _classifyMusicRelease(
      {required String primaryType,
      required List<String> secondaryTypes,
      required String title}) {
    final type = primaryType.toLowerCase();
    final secondary =
        secondaryTypes.map((value) => value.toLowerCase()).join(' ');
    final lowerTitle = title.toLowerCase();
    if (type.contains('single') ||
        lowerTitle.contains(' - single') ||
        lowerTitle.endsWith('(single)')) {
      return 'Single';
    }
    if (type == 'ep' ||
        type.contains('extended play') ||
        lowerTitle.contains(' ep') ||
        lowerTitle.endsWith('(ep)')) {
      return 'EP';
    }
    if (secondary.contains('live')) return 'Live album';
    if (secondary.contains('compilation')) return 'Compilation';
    if (secondary.contains('soundtrack')) return 'Soundtrack';
    if (secondary.contains('remix')) return 'Remix album';
    if (RegExp(r'\b(deluxe|expanded|anniversary)\b').hasMatch(lowerTitle)) {
      return 'Deluxe / expanded edition';
    }
    if (RegExp(r'\b(remaster|remastered|reissue|re-issue)\b')
        .hasMatch(lowerTitle)) {
      return 'Remaster / reissue';
    }
    return 'Studio album';
  }

  Future<void> _toggleFollow(ReleaseCalendarEvent event) async {
    final terms = _termsForEvent(event);
    final shouldRemove = _isFollowed(event);
    final next = <String>{..._followedTerms};
    if (shouldRemove) {
      next.removeAll(terms);
    } else {
      next.addAll(terms);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_followsKey, next.toList()..sort());
    if (!mounted) return;
    setState(() => _followedTerms = next);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(shouldRemove
            ? 'Removed from followed releases and artists.'
            : 'Following this release and related artist/title terms.')));
  }

  Future<void> _toggleReminder(ReleaseCalendarEvent event) async {
    final next = <String, DateTime>{..._reminders};
    final alreadySet = next.containsKey(event.id);
    if (alreadySet) {
      next.remove(event.id);
      _notifiedReminderIds.remove(event.id);
    } else {
      final due = event.scheduledAt.subtract(const Duration(days: 1));
      next[event.id] =
          due.isAfter(DateTime.now().toUtc()) ? due : DateTime.now().toUtc();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _remindersKey,
        jsonEncode(<String, String>{
          for (final entry in next.entries)
            entry.key: entry.value.toIso8601String()
        }));
    await prefs.setStringList(_notifiedKey, _notifiedReminderIds.toList());
    if (!mounted) return;
    setState(() => _reminders = next);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(alreadySet
            ? 'Reminder removed.'
            : 'In-app reminder saved for ${event.title}. It alerts while the app is open; OS push notifications are not configured here.')));
  }

  Future<void> _checkDueReminders() async {
    if (!mounted || _reminders.isEmpty) return;
    final now = DateTime.now().toUtc();
    final due = _reminders.entries
        .where((entry) =>
            !entry.value.isAfter(now) &&
            !_notifiedReminderIds.contains(entry.key))
        .toList(growable: false);
    if (due.isEmpty) return;
    ReleaseCalendarEvent? dueEvent;
    for (final event in _events) {
      if (event.id == due.first.key) {
        dueEvent = event;
        break;
      }
    }
    _notifiedReminderIds.add(due.first.key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_notifiedKey, _notifiedReminderIds.toList());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(dueEvent == null
            ? 'A saved release reminder is due.'
            : 'Release reminder: ${dueEvent.title} is coming up.')));
  }

  Future<void> _showEventDetails(ReleaseCalendarEvent event) async {
    final date =
        MaterialLocalizations.of(context).formatMediumDate(event.localTime);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(event.title),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${event.category} · ${event.milestone}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Release date: $date'),
              Text('Date confidence: ${event.dateConfidence}'),
              Text('Region: ${event.regionCode}'),
              Text('Source: ${event.source}'),
              if (event.lastVerifiedAt != null)
                Text(
                    'Last verified: ${MaterialLocalizations.of(dialogContext).formatMediumDate(event.lastVerifiedAt!.toLocal())}'),
              if (event.musicReleaseType != null)
                Text('Music format: ${event.musicReleaseType}'),
              const SizedBox(height: 9),
              Text('Why you are seeing this: ${_whySeeing(event)}'),
              if (event.note?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text(event.note!)
              ],
              if (event.tracklist.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Announced tracklist',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                ...event.tracklist.take(30).map((track) => Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text('• $track'))),
              ] else if (event.category.toLowerCase() == 'album' ||
                  event.category.toLowerCase() == 'single') ...[
                const SizedBox(height: 8),
                const Text(
                    'Tracklist is not supplied by the current release-calendar source.',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
              ],
              if (event.dateHistory.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Date change history',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                ...event.dateHistory.reversed.take(8).map((change) => Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                        '${change['previousDate'] ?? '?'} → ${change['newDate'] ?? '?'} (detected ${change['detectedAt'] ?? 'date unknown'})',
                        style: const TextStyle(fontSize: 12)))),
              ],
              if (event.sourceUrl?.isNotEmpty == true) ...[
                const SizedBox(height: 9),
                TextButton.icon(
                    onPressed: () => _openSource(dialogContext, event),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Open source listing')),
              ],
            ],
          )),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'))
        ],
      ),
    );
  }

  Future<void> _reportIssue(ReleaseCalendarEvent? event,
      {bool missingRelease = false}) async {
    // Read inherited locale data before the first await. This value is used
    // when persisting a report after the dialog and preferences operations.
    final localeRegion = Localizations.localeOf(context).countryCode ?? 'US';
    final titleController = TextEditingController(text: event?.title ?? '');
    final descriptionController = TextEditingController();
    final kindController = TextEditingController(
        text:
            missingRelease ? 'Missing release' : 'Incorrect date or metadata');
    final submit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(missingRelease
            ? 'Report a missing release'
            : 'Report a release problem'),
        content: SizedBox(
            width: 440,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: titleController,
                  decoration:
                      const InputDecoration(labelText: 'Title or artist')),
              TextField(
                  controller: kindController,
                  decoration: const InputDecoration(labelText: 'Issue type')),
              TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'Details / source URL (optional)')),
            ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Save report'))
        ],
      ),
    );
    if (submit != true) {
      titleController.dispose();
      descriptionController.dispose();
      kindController.dispose();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final rows = <Map<String, String>>[];
    try {
      final decoded = jsonDecode(prefs.getString(_reportsKey) ?? '[]');
      if (decoded is List) {
        for (final item in decoded.whereType<Map>()) {
          rows.add(item
              .map((key, value) => MapEntry(key.toString(), value.toString())));
        }
      }
    } catch (_) {}
    rows.add(<String, String>{
      'title': titleController.text.trim(),
      'issueType': kindController.text.trim(),
      'details': descriptionController.text.trim(),
      'eventId': event?.id ?? '',
      'createdAt': DateTime.now().toIso8601String(),
      'region': event?.regionCode ?? localeRegion,
    });
    await prefs.setString(_reportsKey, jsonEncode(rows));
    titleController.dispose();
    descriptionController.dispose();
    kindController.dispose();
    if (!mounted) return;
    setState(() => _reportedIssueCount = rows.length);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Report saved locally for review. It has not been sent to a provider.')));
  }

  Future<void> _showHealthDashboard() async {
    // Capture locale-derived values before opening an asynchronous dialog. The
    // dialog uses its own BuildContext for MaterialLocalizations so it remains
    // valid even while the route is being presented or dismissed.
    final regionCode = Localizations.localeOf(context).countryCode ?? 'US';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Coming Soon Discovery Health'),
        content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                  Text('Region: $regionCode'),
                  Text(
                      'Last refresh attempt: ${_lastRefreshedAt == null ? 'Not recorded yet' : MaterialLocalizations.of(dialogContext).formatMediumDate(_lastRefreshedAt!.toLocal())}'),
                  Text(
                      'Last successful provider sync: ${_lastSuccessfulSyncAt == null ? 'None recorded' : MaterialLocalizations.of(dialogContext).formatMediumDate(_lastSuccessfulSyncAt!.toLocal())}'),
                  const SizedBox(height: 10),
                  for (final entry in _providerStatus.entries)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.circle,
                                  size: 9, color: Color(0xFFB9ADFF)),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text('${entry.key}: ${entry.value}'))
                            ])),
                  const Divider(),
                  Text('Current catalogue events: ${_events.length}'),
                  Text(
                      'Possible duplicates / filtered merge rows: $_filteredOutCount'),
                  Text(
                      'Unconfirmed dates: ${_events.where((event) => event.dateConfidence.toLowerCase() == 'unconfirmed').length}'),
                  Text(
                      'Estimated dates: ${_events.where((event) => event.dateConfidence.toLowerCase() == 'estimated').length}'),
                  Text(
                      'Date changes / followed-trailer alerts this refresh: ${_lastRefreshChanges.length}'),
                  Text(
                      'Followed terms: ${_followedTerms.length} · reminders: ${_reminders.length} · reports: $_reportedIssueCount'),
                  if (_lastRefreshChanges.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('Recent date changes',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    ..._lastRefreshChanges.take(8).map((change) => Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(change,
                            style: const TextStyle(fontSize: 12)))),
                  ],
                  const SizedBox(height: 8),
                  const Text(
                      'Pagination / coverage: TMDB discovery reads multiple pages per feed and caps the combined calendar; MusicBrainz scans up to 300 album, EP and single release groups, while this screen requests up to 60 rows. A capped feed can still omit announcements.',
                      style: TextStyle(
                          color: Colors.white54, fontSize: 12, height: 1.35)),
                  const SizedBox(height: 6),
                  const Text(
                      'Provider catalog coverage is not exhaustive. Saved reports stay on this device and are not automatically submitted to TMDB, MusicBrainz, or your server.',
                      style: TextStyle(
                          color: Colors.white54, fontSize: 12, height: 1.35)),
                ]))),
        actions: [
          TextButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                unawaited(_reportIssue(null, missingRelease: true));
              },
              icon: const Icon(Icons.report_gmailerrorred_outlined),
              label: const Text('Report missing release')),
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close')),
          FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                unawaited(_refresh());
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry providers')),
        ],
      ),
    );
  }

  bool _isPast(ReleaseCalendarEvent event) {
    if (!event.dateOnly) {
      return event.scheduledAt.isBefore(DateTime.now().toUtc());
    }
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
      final withoutEdition = value
          .toLowerCase()
          .replaceAll(
              RegExp(
                  r'\b(deluxe edition|expanded edition|anniversary edition|remastered|remaster|reissue|re-issue|bonus tracks)\b'),
              ' ')
          .replaceAll(RegExp(r'\s*[-–—:]\s*$'), ' ');
      return withoutEdition.replaceAll(RegExp(r'[^a-z0-9]+'), '');
    }

    final date = event.localTime;
    final canonicalTitle = event.parentTitle?.trim().isNotEmpty == true &&
            event.category.toLowerCase() == 'album'
        ? '${event.parentTitle} ${event.title.split(' · ').skip(1).join(' ')}'
        : event.title;
    return '${normalize(canonicalTitle)}|${normalize(event.milestone)}|${date.year}-${date.month}-${date.day}';
  }

  List<ReleaseCalendarEvent> _eventsFromLibrary(List<MediaItem> library,
      {String regionCode = 'US'}) {
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
      if (date == null ||
          date.isBefore(earliest) ||
          date.isAfter(latest) ||
          title.trim().isEmpty) {
        return;
      }
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
        dateConfidence: 'Estimated',
        regionCode: regionCode,
        lastVerifiedAt: DateTime.now(),
      ));
    }

    for (final media in library) {
      final type = media.type.toLowerCase().replaceAll('-', '_');
      final isAlbum = type.contains('album') || type == 'music_album';
      final isEpisode = type.contains('episode');
      final isShow = !isEpisode &&
          (type.contains('tv') ||
              type.contains('show') ||
              type.contains('series'));
      final isMovie = type.contains('movie') || type.contains('film');
      final category = isAlbum
          ? 'Album'
          : isEpisode
              ? 'Episode'
              : isShow
                  ? 'Show'
                  : 'Movie';
      final primaryDate = isShow
          ? (media.seriesStartDate ?? media.releaseDate)
          : media.releaseDate;
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
        final edition = '${media.editionName ?? ''} ${media.editionType ?? ''}'
            .toLowerCase();
        final physical = edition.contains('dvd') ||
            edition.contains('blu-ray') ||
            edition.contains('bluray') ||
            edition.contains('4k') ||
            edition.contains('ultra hd') ||
            edition.contains('physical') ||
            (isAlbum && edition.contains('cd'));
        final milestone = edition.contains('dvd')
            ? (isShow ? 'Season/series DVD release' : 'DVD release')
            : edition.contains('blu-ray') || edition.contains('bluray')
                ? (isShow ? 'Season/series Blu-ray release' : 'Blu-ray release')
                : edition.contains('4k') || edition.contains('ultra hd')
                    ? (isShow
                        ? 'Season/series 4K Ultra HD release'
                        : '4K Ultra HD release')
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

      for (var seasonIndex = 0;
          seasonIndex < media.seasons.length;
          seasonIndex++) {
        final season = media.seasons[seasonIndex];
        final seasonNumber = _number(season['seasonNumber'] ??
            season['season_number'] ??
            season['number']);
        final seasonLabel =
            seasonNumber == null ? 'Season' : 'Season $seasonNumber';
        for (final physicalEvent in _knownPhysicalDates(
          map: season,
          idPrefix: '${media.id}-season-$seasonIndex',
          title: '${media.title} · $seasonLabel',
          category: 'Show',
          imageUrl:
              (season['posterUrl'] ?? season['imageUrl'] ?? media.imageUrl)
                  ?.toString(),
          isShow: true,
          earliest: earliest,
          latest: latest,
        )) {
          if (seen.add(physicalEvent.id)) output.add(physicalEvent);
        }
        final episodesRaw = season['episodes'];
        if (episodesRaw is! List) continue;
        for (var episodeIndex = 0;
            episodeIndex < episodesRaw.length;
            episodeIndex++) {
          final rawEpisode = episodesRaw[episodeIndex];
          if (rawEpisode is! Map) continue;
          final episode = Map<String, dynamic>.from(rawEpisode);
          final episodeNumber = _number(episode['episodeNumber'] ??
              episode['episode_number'] ??
              episode['number']);
          final episodeTitle = (episode['title'] ??
                  episode['name'] ??
                  'Episode ${episodeNumber ?? episodeIndex + 1}')
              .toString();
          final code = seasonNumber != null && episodeNumber != null
              ? 'S${seasonNumber.toString().padLeft(2, '0')}E${episodeNumber.toString().padLeft(2, '0')}'
              : null;
          final fullTitle =
              '${media.title} · ${code == null ? '' : '$code · '}$episodeTitle';
          final episodeImage =
              (episode['imageUrl'] ?? episode['stillUrl'] ?? media.imageUrl)
                  ?.toString();
          final airDate = _parseReleaseDate(
            episode['streamingReleaseDate'] ??
                episode['streaming_release_date'] ??
                episode['readyToStreamDate'] ??
                episode['ready_to_stream_date'] ??
                episode['airDate'] ??
                episode['air_date'] ??
                episode['releaseDate'] ??
                episode['release_date'],
            timeRaw: episode['airTime'] ??
                episode['air_time'] ??
                episode['releaseTime'],
          );
          final streamingDate = _parseReleaseDate(
            episode['streamingReleaseDate'] ??
                episode['streaming_release_date'] ??
                episode['readyToStreamDate'] ??
                episode['ready_to_stream_date'],
            timeRaw: episode['streamingTime'] ?? episode['streaming_time'],
          );
          final isStreaming = streamingDate != null;
          add(
            id: '${media.id}-season-$seasonIndex-episode-$episodeIndex',
            title: fullTitle,
            parentTitle: media.title,
            category: 'Episode',
            milestone: isStreaming
                ? 'New episode · streaming release'
                : 'New episode · scheduled air date',
            date: isStreaming ? streamingDate : airDate,
            imageUrl: episodeImage,
            note: (episode['network'] ??
                        episode['streamingService'] ??
                        episode['platform'])
                    ?.toString() ??
                'Episode date supplied by the imported library metadata; the actual airing time may depend on region.',
            dateOnly: !(episode.containsKey('airTime') ||
                episode.containsKey('air_time') ||
                episode.containsKey('releaseTime')),
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
      (
        <String>['dvdReleaseDate', 'dvd_release_date', 'dvdDate', 'dvd_date'],
        'DVD release'
      ),
      (
        <String>[
          'physicalReleaseDate',
          'physical_release_date',
          'physicalEditionDate'
        ],
        'Physical media release (format unspecified)'
      ),
      (
        <String>[
          'bluRayReleaseDate',
          'blurayReleaseDate',
          'blu_ray_release_date',
          'bluRayDate',
          'blu_ray_date'
        ],
        'Blu-ray release'
      ),
      (
        <String>[
          'uhdReleaseDate',
          'fourKReleaseDate',
          '4kReleaseDate',
          'uhd_release_date',
          'four_k_release_date'
        ],
        '4K Ultra HD release'
      ),
      (<String>['cdReleaseDate', 'cd_release_date'], 'CD release'),
      (
        <String>['seasonDvdReleaseDate', 'season_dvd_release_date'],
        'Season on DVD'
      ),
      (
        <String>['seasonBluRayReleaseDate', 'season_bluray_release_date'],
        'Season on Blu-ray'
      ),
      (
        <String>['seriesDvdReleaseDate', 'completeSeriesDvdReleaseDate'],
        'Complete series on DVD'
      ),
      (
        <String>['seriesBluRayReleaseDate', 'completeSeriesBluRayReleaseDate'],
        'Complete series on Blu-ray'
      ),
      (
        <String>['seriesUhdReleaseDate', 'completeSeries4kReleaseDate'],
        'Complete series on 4K Ultra HD'
      ),
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
      if (date == null || date.isBefore(earliest) || date.isAfter(latest)) {
        continue;
      }
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

  bool _isDateOnly(DateTime value) =>
      value.hour == 0 && value.minute == 0 && value.second == 0;

  int? _number(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  Future<void> _addEvent() async {
    // Capture the messenger before awaiting so this method never looks up a
    // BuildContext after an async gap.
    final messenger = ScaffoldMessenger.of(context);
    final event = await showDialog<ReleaseCalendarEvent>(
      context: context,
      builder: (_) => const _AddReleaseEventDialog(),
    );
    if (event == null || !mounted) return;
    final updated = <ReleaseCalendarEvent>[..._manualEvents, event];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _storageKey, jsonEncode(updated.map((item) => item.toJson()).toList()));
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
    messenger.showSnackBar(
      const SnackBar(
          content: Text('Release countdown saved for this profile.')),
    );
  }

  Future<void> _deleteEvent(ReleaseCalendarEvent event) async {
    final updated = _manualEvents.where((item) => item.id != event.id).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _storageKey, jsonEncode(updated.map((item) => item.toJson()).toList()));
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
        'Albums' => event.category.toLowerCase() == 'album' &&
            (event.musicReleaseType ?? '').toLowerCase() != 'ep',
        'EPs' => (event.musicReleaseType ?? '').toLowerCase() == 'ep',
        'Singles' => event.category.toLowerCase() == 'single' ||
            (event.musicReleaseType ?? '').toLowerCase() == 'single',
        'Music Videos' => event.category.toLowerCase() == 'music video',
        'Theatrical' => event.milestone.toLowerCase().contains('theatrical') ||
            event.milestone.toLowerCase().contains('cinema'),
        'Streaming' => event.milestone.toLowerCase().contains('streaming') ||
            event.milestone.toLowerCase().contains('stream'),
        'Digital' => event.milestone.toLowerCase().contains('digital') ||
            event.milestone.toLowerCase().contains('rental') ||
            event.milestone.toLowerCase().contains('purchase'),
        'Physical Media' => event.isPhysicalMedia,
        _ => true,
      };
      final isFeatured = _featuredEvents.any((featured) =>
          _dedupeKey(featured) == _dedupeKey(event) && !_isPast(featured));
      final spotlightShownSeparately =
          !_onlyFollowed && _filter == 'All' && query.isEmpty && isFeatured;
      final queryMatches = query.isEmpty ||
          event.title.toLowerCase().contains(query) ||
          event.milestone.toLowerCase().contains(query) ||
          (event.parentTitle ?? '').toLowerCase().contains(query) ||
          (event.note ?? '').toLowerCase().contains(query) ||
          event.source.toLowerCase().contains(query) ||
          (event.musicReleaseType ?? '').toLowerCase().contains(query) ||
          event.regionCode.toLowerCase().contains(query);
      final followedMatches = !_onlyFollowed || _isFollowed(event);
      return filterMatches &&
          queryMatches &&
          !spotlightShownSeparately &&
          followedMatches;
    }).toList()
      ..sort((a, b) {
        final aFuture = !_isPast(a);
        final bFuture = !_isPast(b);
        if (aFuture != bFuture) return aFuture ? -1 : 1;
        if (_sortMode == 'For you') {
          final scoreCompare = _score(b).compareTo(_score(a));
          if (scoreCompare != 0) return scoreCompare;
        }
        return a.scheduledAt.compareTo(b.scheduledAt);
      });
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleEvents;
    final upcomingCount = _events.where((e) => !_isPast(e)).length;
    final todayCount = _events.where((e) {
      final local = e.localTime;
      final current = DateTime.now();
      return local.year == current.year &&
          local.month == current.month &&
          local.day == current.day;
    }).length;
    final physicalCount =
        _events.where((e) => e.isPhysicalMedia && !_isPast(e)).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coming Soon'),
        actions: [
          IconButton(
            tooltip: 'Discovery health and provider status',
            onPressed: _showHealthDashboard,
            icon: const Icon(Icons.monitor_heart_outlined),
          ),
          IconButton(
            tooltip: 'Refresh release dates',
            onPressed: _refreshing ? null : _refresh,
            icon: _refreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
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
                  _summaryRow(
                      upcomingCount: upcomingCount,
                      todayCount: todayCount,
                      physicalCount: physicalCount),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    InputChip(
                      avatar: const Icon(Icons.star_rounded, size: 17),
                      label: Text(_onlyFollowed
                          ? 'Showing followed (${_followedTerms.length})'
                          : 'Following ${_followedTerms.length}'),
                      selected: _onlyFollowed,
                      onPressed: () => setState(() {
                        _onlyFollowed = !_onlyFollowed;
                        _filter = 'All';
                        _search = '';
                      }),
                    ),
                    InputChip(
                        avatar: const Icon(Icons.alarm_rounded, size: 17),
                        label: Text('${_reminders.length} reminders'),
                        onPressed: () => _showHealthDashboard()),
                    ActionChip(
                        avatar:
                            const Icon(Icons.monitor_heart_outlined, size: 17),
                        label: const Text('Provider health'),
                        onPressed: _showHealthDashboard),
                    ActionChip(
                        avatar: const Icon(Icons.report_outlined, size: 17),
                        label: const Text('Report missing'),
                        onPressed: () =>
                            _reportIssue(null, missingRelease: true)),
                  ]),
                  if (_lastRefreshChanges.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: Colors.deepPurple.withValues(alpha: .10),
                            borderRadius: BorderRadius.circular(10)),
                        child: Text(
                            '${_lastRefreshChanges.length} release date change(s) detected. Open Provider health to review.',
                            style: const TextStyle(fontSize: 12))),
                  ],
                  if (_providerMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.amber.withValues(alpha: .20)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.info_outline_rounded,
                            color: Colors.amber, size: 19),
                        const SizedBox(width: 9),
                        Expanded(
                            child: Text(_providerMessage!,
                                style: const TextStyle(
                                    fontSize: 12, height: 1.35))),
                      ]),
                    ),
                  ],
                  if (!_onlyFollowed &&
                      _filter == 'All' &&
                      _search.trim().isEmpty &&
                      _featuredEvents.any((event) => !_isPast(event))) ...[
                    _spotlightStrip(
                        context,
                        _featuredEvents
                            .where((event) => !_isPast(event))
                            .toList()
                          ..sort((a, b) => _score(b).compareTo(_score(a)))),
                    const SizedBox(height: 18),
                    Text('All catalog releases',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Theme.of(context).colorScheme.onSurface)),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 14),
                  TextField(
                    onChanged: (value) => setState(() => _search = value),
                    decoration: InputDecoration(
                      hintText: 'Search titles, milestones, platforms…',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: .45),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none),
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
                  const SizedBox(height: 9),
                  Row(children: [
                    Text('Sort',
                        style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    ChoiceChip(
                        label: const Text('For you'),
                        selected: _sortMode == 'For you',
                        onSelected: (_) =>
                            setState(() => _sortMode = 'For you')),
                    const SizedBox(width: 6),
                    ChoiceChip(
                        label: const Text('Soonest'),
                        selected: _sortMode == 'Soonest',
                        onSelected: (_) =>
                            setState(() => _sortMode = 'Soonest')),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                      '${visible.length} release milestone${visible.length == 1 ? '' : 's'} · ranked by interest, followed terms, date confidence, and release proximity',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 11)),
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

  Widget _spotlightStrip(
    BuildContext context,
    List<ReleaseCalendarEvent> events,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.local_fire_department_rounded,
              color: Color(0xFFFFC86A), size: 20),
          const SizedBox(width: 7),
          const Expanded(
              child: Text('Spotlight releases',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
          Text('${events.length} tracked',
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ]),
        const SizedBox(height: 9),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: events.length,
            separatorBuilder: (_, __) => const SizedBox(width: 9),
            itemBuilder: (context, index) {
              final event = events[index];
              final local = event.localTime;
              final date =
                  MaterialLocalizations.of(context).formatMediumDate(local);
              final image = event.imageUrl?.trim() ?? '';
              return SizedBox(
                width: 228,
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  margin: EdgeInsets.zero,
                  child: InkWell(
                    onTap: () => setState(() {
                      _filter = switch (event.category.toLowerCase()) {
                        'movie' => 'Movies',
                        'show' => 'Shows',
                        'episode' => 'Episodes',
                        'album' => 'Albums',
                        _ => 'All',
                      };
                      _search = '';
                    }),
                    child: Stack(fit: StackFit.expand, children: [
                      if (image.startsWith('http'))
                        Image.network(image,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink()),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(
                                  alpha: image.startsWith('http') ? .32 : .04),
                              Colors.black.withValues(alpha: .88)
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(11),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Row(children: [
                              Icon(_iconForEvent(event),
                                  color: const Color(0xFFB9ADFF), size: 15),
                              const SizedBox(width: 5),
                              Expanded(
                                  child: Text(event.category.toUpperCase(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: Color(0xFFB9ADFF),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: .7))),
                              if (event.sourceUrl?.isNotEmpty == true)
                                InkWell(
                                  onTap: () => _openSource(context, event),
                                  child: const Icon(Icons.open_in_new_rounded,
                                      color: Colors.white70, size: 15),
                                ),
                            ]),
                            const SizedBox(height: 5),
                            Text(event.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.15,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white)),
                            const SizedBox(height: 4),
                            Text(
                                '$date · ${formatReleaseCountdown(event.scheduledAt, dateOnly: true)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _openSource(
      BuildContext context, ReleaseCalendarEvent event) async {
    final source = event.sourceUrl?.trim() ?? '';
    final uri = Uri.tryParse(source);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) return;
    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Unable to open the release source.')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Unable to open the release source.')));
      }
    }
  }

  Widget _introPanel(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF2B224A), Color(0xFF171923)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: const Color(0xFF8B7CFF).withValues(alpha: .28)),
      ),
      padding: const EdgeInsets.all(17),
      child:
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.hourglass_top_rounded, color: Color(0xFFB9ADFF)),
          SizedBox(width: 9),
          Text('Every premiere. Every format.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))
        ]),
        SizedBox(height: 8),
        Text(
            'Track movies, shows, episodes, albums, EPs, singles, music videos, digital premieres and physical formats in separate views—with For You ranking, follows, reminders and date-change history.',
            style: TextStyle(color: Colors.white70, height: 1.4, fontSize: 13)),
        SizedBox(height: 7),
        Text(
            'Every date shows its confidence, region, source and last verification when available. Catalogs can lag or omit announcements, so use Provider Health to review sync status and report missing entries.',
            style:
                TextStyle(color: Colors.white54, height: 1.35, fontSize: 11)),
      ]),
    );
  }

  Widget _summaryRow(
      {required int upcomingCount,
      required int todayCount,
      required int physicalCount}) {
    final items = <(String, String, IconData)>[
      ('Upcoming', '$upcomingCount', Icons.hourglass_bottom_rounded),
      ('Today', '$todayCount', Icons.today_rounded),
      ('Physical', '$physicalCount', Icons.disc_full_rounded),
    ];
    return Row(children: [
      for (var i = 0; i < items.length; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        Expanded(
            child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: .55),
              borderRadius: BorderRadius.circular(14)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(items[i].$3, size: 18, color: const Color(0xFFB9ADFF)),
            const SizedBox(height: 7),
            Text(items[i].$2,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            Text(items[i].$1,
                style: const TextStyle(color: Colors.white60, fontSize: 11)),
          ]),
        )),
      ],
    ]);
  }

  Widget _eventCard(BuildContext context, ReleaseCalendarEvent event) {
    final local = event.localTime;
    final isPast = _isPast(event);
    final date = MaterialLocalizations.of(context).formatMediumDate(local);
    final time = MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(local));
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
                  ? Image.network(image,
                      width: 74,
                      height: 104,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _posterFallback(event))
                  : _posterFallback(event),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _eventLabel(event.category),
                        if (physical)
                          _eventLabel('Physical Media', physical: true),
                        if (manual) _eventLabel('Saved'),
                        _confidenceLabel(event.dateConfidence),
                        if (event.dateHistory.isNotEmpty)
                          _eventLabel(
                              'Date changed ${event.dateHistory.length}×'),
                        if (event.musicReleaseType != null)
                          _eventLabel(event.musicReleaseType!),
                      ]),
                  const SizedBox(height: 7),
                  Text(event.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          height: 1.2)),
                  const SizedBox(height: 4),
                  Text(event.milestone,
                      style: const TextStyle(
                          color: Color(0xFFB9ADFF),
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(_whySeeing(event),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 10, height: 1.25)),
                  const SizedBox(height: 7),
                  Text(
                      formatReleaseCountdown(event.scheduledAt,
                          dateOnly: event.dateOnly),
                      style: TextStyle(
                          color:
                              isPast ? Colors.white60 : const Color(0xFF9CE7C5),
                          fontSize: 14,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(
                      event.dateOnly
                          ? '$date · date only'
                          : '$date · $time · device time',
                      style:
                          const TextStyle(color: Colors.white60, fontSize: 11)),
                  if (event.note?.isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Text(event.note!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11, height: 1.3)),
                  ],
                  const SizedBox(height: 5),
                  Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        Text('Source: ${event.source}',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 10)),
                        if (event.lastVerifiedAt != null)
                          Text(
                              'Verified ${MaterialLocalizations.of(context).formatShortDate(event.lastVerifiedAt!.toLocal())}',
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 10)),
                        if (event.sourceUrl?.trim().isNotEmpty == true)
                          InkWell(
                            onTap: () => _openSource(context, event),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 2),
                              child: Text('Official listing ↗',
                                  style: TextStyle(
                                      color: Color(0xFFB9ADFF),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                      ]),
                ])),
            Column(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                tooltip: _isFollowed(event)
                    ? 'Unfollow title / artist'
                    : 'Follow title / artist',
                visualDensity: VisualDensity.compact,
                onPressed: () => _toggleFollow(event),
                icon: Icon(
                    _isFollowed(event)
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: _isFollowed(event) ? const Color(0xFFFFC86A) : null),
              ),
              IconButton(
                tooltip: _reminders.containsKey(event.id)
                    ? 'Remove reminder'
                    : 'Remind me',
                visualDensity: VisualDensity.compact,
                onPressed: () => _toggleReminder(event),
                icon: Icon(_reminders.containsKey(event.id)
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded),
              ),
              IconButton(
                tooltip: 'Release details, source and date history',
                visualDensity: VisualDensity.compact,
                onPressed: () => _showEventDetails(event),
                icon: const Icon(Icons.info_outline_rounded),
              ),
              PopupMenuButton<String>(
                tooltip: 'More release options',
                onSelected: (value) {
                  if (value == 'delete' && manual) _confirmDelete(event);
                  if (value == 'report') _reportIssue(event);
                  if (value == 'details') _showEventDetails(event);
                },
                itemBuilder: (_) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                      value: 'details',
                      child: Text('View details / date history')),
                  const PopupMenuItem<String>(
                      value: 'report',
                      child: Text('Report incorrect metadata')),
                  if (manual)
                    const PopupMenuItem<String>(
                        value: 'delete', child: Text('Remove countdown')),
                ],
              ),
            ]),
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
        child: Icon(_iconForEvent(event),
            size: 30, color: const Color(0xFFB9ADFF)),
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

  Widget _confidenceLabel(String confidence) {
    final normalized = confidence.toLowerCase();
    final color = normalized == 'confirmed'
        ? const Color(0xFF86DDB2)
        : normalized == 'estimated'
            ? const Color(0xFFFFD18C)
            : Colors.redAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .13),
          borderRadius: BorderRadius.circular(20)),
      child: Text('$confidence date',
          style: TextStyle(
              color: color, fontSize: 9, fontWeight: FontWeight.w800)),
    );
  }

  Widget _eventLabel(String label, {bool physical = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: (physical ? const Color(0xFFFFD18C) : const Color(0xFFB9ADFF))
              .withValues(alpha: .13),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 9,
                letterSpacing: .2,
                color: physical
                    ? const Color(0xFFFFD18C)
                    : const Color(0xFFCBC3FF),
                fontWeight: FontWeight.w800)),
      );

  Widget _emptyState(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 34),
        decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: .35),
            borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          const Icon(Icons.event_available_rounded,
              size: 38, color: Color(0xFFB9ADFF)),
          const SizedBox(height: 10),
          const Text('No release dates in this view',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text(
              'Catalog coverage varies by country and provider. Add a countdown for a theater date, streaming premiere, episode airing, album, DVD, Blu-ray, 4K Ultra HD or CD.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: Colors.white60, fontSize: 12, height: 1.4)),
          const SizedBox(height: 12),
          FilledButton.icon(
              onPressed: _addEvent,
              icon: const Icon(Icons.add),
              label: const Text('Add a release date')),
        ]),
      );

  Future<void> _confirmDelete(ReleaseCalendarEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove countdown?'),
        content: Text(
            'Remove the saved countdown for “${event.title}” (${event.milestone})?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Remove')),
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
    'Movie': <String>[
      'Theatrical release',
      'Streaming release',
      'Digital rental/purchase',
      'DVD release',
      'Blu-ray release',
      '4K Ultra HD release'
    ],
    'Show': <String>[
      'Series premiere',
      'New episode · streaming release',
      'New episode · first cable airing',
      'Season release · streaming',
      'Season on DVD',
      'Season on Blu-ray',
      'Season on 4K Ultra HD',
      'Complete series on DVD',
      'Complete series on Blu-ray',
      'Complete series on 4K Ultra HD'
    ],
    'Episode': <String>[
      'New episode · streaming release',
      'New episode · first cable airing',
      'Episode becomes available to stream',
      'Episode first broadcast'
    ],
    'Album': <String>['Album release', 'Album streaming release', 'CD release'],
    'EP': <String>['EP release', 'EP streaming release'],
    'Single': <String>['Single release', 'Single streaming release'],
    'Music Video': <String>[
      'Music video premiere',
      'Official music video release'
    ],
  };

  final TextEditingController _title = TextEditingController();
  final TextEditingController _provider = TextEditingController();
  String _category = 'Movie';
  String _milestone = 'Theatrical release';
  String _dateConfidence = 'Unconfirmed';
  String _regionCode = 'US';
  bool _didSetRegion = false;
  DateTime _date = DateTime.now().add(const Duration(days: 30));
  TimeOfDay _time = const TimeOfDay(hour: 12, minute: 0);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didSetRegion) return;
    final localeRegion =
        (Localizations.localeOf(context).countryCode ?? 'US').toUpperCase();
    const supportedRegions = <String>{
      'US',
      'MX',
      'GB',
      'CA',
      'AU',
      'JP',
      'GLOBAL'
    };
    _regionCode = supportedRegions.contains(localeRegion) ? localeRegion : 'US';
    _didSetRegion = true;
  }

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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enter a movie, show, episode or album title.')));
      return;
    }
    final localDate =
        DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    final provider = _provider.text.trim();
    final event = ReleaseCalendarEvent(
      id: 'manual-${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      category: _category,
      milestone: _milestone,
      scheduledAt: localDate.toUtc(),
      source: 'Your schedule',
      note: provider.isEmpty
          ? 'Manual date · device local time'
          : 'Provider/channel: $provider · device local time',
      dateOnly: false,
      isManual: true,
      dateConfidence: _dateConfidence,
      regionCode: _regionCode,
      lastVerifiedAt: null,
      musicReleaseType: _category == 'EP'
          ? 'EP'
          : _category == 'Single'
              ? 'Single'
              : null,
    );
    Navigator.of(context).pop(event);
  }

  @override
  Widget build(BuildContext context) {
    final milestones = _milestones[_category] ?? const <String>[];
    // Derive a safe current value instead of mutating State during build.
    final selectedMilestone =
        milestones.contains(_milestone) ? _milestone : milestones.first;
    return AlertDialog(
      scrollable: true,
      title: const Text('Add a release countdown'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 470,
          maxHeight: MediaQuery.sizeOf(context).height * .58,
        ),
        child: SingleChildScrollView(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'Set the exact date and local time for a premiere, airing, album or physical edition.',
                    style: TextStyle(
                        color: Colors.white60, fontSize: 12, height: 1.35)),
                const SizedBox(height: 14),
                TextField(
                    controller: _title,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                        labelText: 'Title',
                        hintText: 'Movie, show, episode or album')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration:
                      const InputDecoration(labelText: 'Media category'),
                  items: _milestones.keys
                      .map((item) => DropdownMenuItem<String>(
                          value: item, child: Text(item)))
                      .toList(),
                  onChanged: (value) => setState(() {
                    _category = value ?? 'Movie';
                    _milestone = _milestones[_category]!.first;
                  }),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedMilestone,
                  decoration:
                      const InputDecoration(labelText: 'Release milestone'),
                  items: milestones
                      .map((item) => DropdownMenuItem<String>(
                          value: item, child: Text(item)))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _milestone = value ?? milestones.first),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _dateConfidence,
                  decoration:
                      const InputDecoration(labelText: 'Date confidence'),
                  items: const <String>['Confirmed', 'Estimated', 'Unconfirmed']
                      .map((item) => DropdownMenuItem<String>(
                          value: item, child: Text(item)))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _dateConfidence = value ?? 'Unconfirmed'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _regionCode,
                  decoration:
                      const InputDecoration(labelText: 'Release region'),
                  items: const <String>[
                    'MX',
                    'US',
                    'GB',
                    'CA',
                    'AU',
                    'JP',
                    'GLOBAL'
                  ]
                      .map((item) => DropdownMenuItem<String>(
                          value: item, child: Text(item)))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _regionCode = value ?? 'US'),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: const Text('Release date'),
                  subtitle: Text(MaterialLocalizations.of(context)
                      .formatMediumDate(_date)),
                  onTap: _chooseDate,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule_rounded),
                  title: const Text('Release time'),
                  subtitle: Text(_time.format(context)),
                  onTap: _chooseTime,
                ),
                TextField(
                    controller: _provider,
                    decoration: const InputDecoration(
                        labelText:
                            'Streaming service / cable network (optional)',
                        hintText: 'Netflix, HBO, ABC…')),
                const SizedBox(height: 8),
                const Text(
                    'Manually entered dates are marked Unconfirmed until verified. In-app reminders can be saved from each release card; operating-system push notifications require additional platform notification setup.',
                    style: TextStyle(
                        color: Colors.white54, fontSize: 11, height: 1.35)),
              ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save countdown')),
      ],
    );
  }
}
