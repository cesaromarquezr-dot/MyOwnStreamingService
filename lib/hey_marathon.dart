// FILE: lib/hey_marathon.dart
// Purpose: Plans personal film/TV marathons, creates a runtime-aware schedule,
// shares invitations, and hands themed food discovery to Hey Eats.
// Plans are saved locally per profile. Group Watch uses the existing backend
// session API; this module does not claim that an entire multi-title schedule
// is synchronized by a single Group Watch session.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_core.dart';
import 'food_delivery.dart';
import 'group_watch.dart';
import 'localization.dart';
import 'page_customization_button.dart';

@immutable
class MarathonTheme {
  final String id;
  final String title;
  final IconData icon;
  final List<String> foodIdeas;
  final String description;

  const MarathonTheme({
    required this.id,
    required this.title,
    required this.icon,
    required this.foodIdeas,
    required this.description,
  });
}

const List<MarathonTheme> heyMarathonThemes = <MarathonTheme>[
  MarathonTheme(
    id: 'wizarding-fantasy',
    title: 'Wizarding Fantasy Night',
    icon: Icons.auto_awesome_rounded,
    description: 'A magical marathon with hearty bites and sweets.',
    foodIdeas: <String>[
      'Pumpkin pasties',
      'Cornish pasties or hand pies',
      'Treacle tart or cauldron cakes',
      'Chocolate frogs and a candy board',
      'Butterbeer-inspired cream soda (offer a non-alcoholic version)',
      'Pretzel-rod broomsticks',
    ],
  ),
  MarathonTheme(
    id: 'superhero',
    title: 'Superhero Movie Night',
    icon: Icons.bolt_rounded,
    description: 'Big-screen comfort food and colorful snacks.',
    foodIdeas: <String>[
      'Shawarma wraps',
      'Cheeseburgers and fries',
      'NYC-style pizza slices',
      'Red, gold, and green fruit skewers',
      'Infinity-stone-inspired gummies',
      'Blue citrus mocktails and green lime punch',
    ],
  ),
  MarathonTheme(
    id: 'anime',
    title: 'Anime Binge',
    icon: Icons.playlist_play_rounded,
    description: 'Comfort food and small bites for episode breaks.',
    foodIdeas: <String>[
      'Onigiri or rice bowls',
      'Ramen or udon',
      'Gyoza or vegetable dumplings',
      'Mochi or fruit jelly',
      'Japanese-style fruit soda',
    ],
  ),
  MarathonTheme(
    id: 'cozy-cinema',
    title: 'Cozy Cinema',
    icon: Icons.weekend_rounded,
    description: 'Easy-to-share comfort food for a relaxed movie night.',
    foodIdeas: <String>[
      'Popcorn with a seasoning bar',
      'Pizza, flatbreads, or sliders',
      'Nachos with toppings on the side',
      'Cookies or brownies',
      'Hot chocolate, tea, or soda',
    ],
  ),
  MarathonTheme(
    id: 'custom',
    title: 'Custom Theme',
    icon: Icons.tune_rounded,
    description: 'Bring your own theme, menu, and traditions.',
    foodIdeas: <String>[
      'Add your favorite snacks',
      'Choose food that suits everyone attending',
      'Check ingredients and allergens directly with the restaurant',
    ],
  ),
];

@immutable
class MarathonEntry {
  final String id;
  final String mediaId;
  final String parentTitle;
  final String title;
  final String mediaType;
  final String? imageUrl;
  final int runtimeMinutes;
  final bool runtimeEstimated;
  final int? releaseYear;
  final String? franchiseId;
  final int? franchiseOrder;
  final int? seasonNumber;
  final int? episodeNumber;
  final bool episodeOrderNeedsReview;

  const MarathonEntry({
    required this.id,
    required this.mediaId,
    required this.parentTitle,
    required this.title,
    required this.mediaType,
    required this.runtimeMinutes,
    this.imageUrl,
    this.runtimeEstimated = true,
    this.releaseYear,
    this.franchiseId,
    this.franchiseOrder,
    this.seasonNumber,
    this.episodeNumber,
    this.episodeOrderNeedsReview = false,
  });

  bool get isEpisode => seasonNumber != null || episodeNumber != null ||
      mediaType.toLowerCase() == 'episode';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'mediaId': mediaId,
        'parentTitle': parentTitle,
        'title': title,
        'mediaType': mediaType,
        'imageUrl': imageUrl,
        'runtimeMinutes': runtimeMinutes,
        'runtimeEstimated': runtimeEstimated,
        'releaseYear': releaseYear,
        'franchiseId': franchiseId,
        'franchiseOrder': franchiseOrder,
        'seasonNumber': seasonNumber,
        'episodeNumber': episodeNumber,
        'episodeOrderNeedsReview': episodeOrderNeedsReview,
      };

  factory MarathonEntry.fromJson(Map<String, dynamic> json) => MarathonEntry(
        id: json['id']?.toString() ?? '',
        mediaId: json['mediaId']?.toString() ?? '',
        parentTitle: json['parentTitle']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        mediaType: json['mediaType']?.toString() ?? 'movie',
        imageUrl: json['imageUrl']?.toString(),
        runtimeMinutes: (_readInt(json['runtimeMinutes']) ?? 120).clamp(1, 1440).toInt(),
        runtimeEstimated: json['runtimeEstimated'] != false,
        releaseYear: _readInt(json['releaseYear']),
        franchiseId: json['franchiseId']?.toString(),
        franchiseOrder: _readInt(json['franchiseOrder']),
        seasonNumber: _readInt(json['seasonNumber']),
        episodeNumber: _readInt(json['episodeNumber']),
        episodeOrderNeedsReview: json['episodeOrderNeedsReview'] == true,
      );

  MarathonEntry withRuntime(int minutes, {bool estimated = false}) => MarathonEntry(
        id: id,
        mediaId: mediaId,
        parentTitle: parentTitle,
        title: title,
        mediaType: mediaType,
        imageUrl: imageUrl,
        runtimeMinutes: minutes.clamp(1, 1440).toInt(),
        runtimeEstimated: estimated,
        releaseYear: releaseYear,
        franchiseId: franchiseId,
        franchiseOrder: franchiseOrder,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
        episodeOrderNeedsReview: episodeOrderNeedsReview,
      );

  static List<MarathonEntry> fromMediaItem(MediaItem media) {
    final seasons = media.seasons
        .map((season) => Map<String, dynamic>.from(season))
        .toList();
    if (seasons.isEmpty) {
      final type = media.type.toLowerCase();
      final looksLikeSeries = type.contains('series') ||
          type.contains('show') ||
          type.contains('tv');
      final code = RegExp(r'\bS(\d{1,2})\s*E(\d{1,3})\b', caseSensitive: false)
          .firstMatch(media.title);
      final seasonNumber = code == null ? null : int.tryParse(code.group(1)!);
      final episodeNumber = code == null ? null : int.tryParse(code.group(2)!);
      final entry = MarathonEntry(
        id: media.id,
        mediaId: media.id,
        parentTitle: media.title,
        title: media.title,
        mediaType: media.type,
        imageUrl: media.imageUrl,
        runtimeMinutes: looksLikeSeries ? 45 : _defaultRuntimeForType(media.type),
        runtimeEstimated: true,
        releaseYear: media.releaseYear,
        franchiseId: media.franchiseId,
        franchiseOrder: media.franchiseOrder,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
        episodeOrderNeedsReview: looksLikeSeries ||
            (type.contains('episode') && (seasonNumber == null || episodeNumber == null)),
      );
      return <MarathonEntry>[entry];
    }

    final orderedSeasons = List<Map<String, dynamic>>.from(seasons)
      ..sort((a, b) {
        final an = _seasonNumber(a);
        final bn = _seasonNumber(b);
        if (an != null && bn != null) return an.compareTo(bn);
        if (an != null) return -1;
        if (bn != null) return 1;
        return _seasonLabel(a).compareTo(_seasonLabel(b));
      });

    final entries = <MarathonEntry>[];
    for (final season in orderedSeasons) {
      final seasonNumber = _seasonNumber(season);
      final rawEpisodes = season['episodes'];
      if (rawEpisodes is! List) continue;
      final episodes = rawEpisodes
          .whereType<Map>()
          .map((episode) => Map<String, dynamic>.from(episode))
          .toList();
      episodes.sort((a, b) {
        final an = _episodeNumber(a);
        final bn = _episodeNumber(b);
        if (an != null && bn != null) return an.compareTo(bn);
        if (an != null) return -1;
        if (bn != null) return 1;
        return _episodeTitle(a).toLowerCase().compareTo(_episodeTitle(b).toLowerCase());
      });
      for (var index = 0; index < episodes.length; index++) {
        final episode = episodes[index];
        final episodeSeason = _readInt(episode['seasonNumber'] ?? episode['season_number']) ??
            seasonNumber ?? _seasonNumberFromEpisodeLabel(episode);
        final episodeNumber = _episodeNumber(episode);
        final needsReview = episodeSeason == null || episodeNumber == null;
        final episodeTitle = _episodeTitle(episode);
        final seasonCode = episodeSeason == null ? 'S??' : 'S${episodeSeason.toString().padLeft(2, '0')}';
        final episodeCode = episodeNumber == null ? 'E??' : 'E${episodeNumber.toString().padLeft(2, '0')}';
        final runtime = _episodeRuntime(episode);
        final stableEpisodeId = episode['id']?.toString() ??
            episode['episodeId']?.toString() ??
            '${episodeSeason ?? 'unknown'}_${episodeNumber ?? episodeTitle.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';
        entries.add(MarathonEntry(
          id: '${media.id}::episode::$stableEpisodeId',
          mediaId: media.id,
          parentTitle: media.title,
          title: '${media.title} · $seasonCode$episodeCode · $episodeTitle',
          mediaType: 'episode',
          imageUrl: episode['imageUrl']?.toString() ?? episode['stillUrl']?.toString() ?? media.imageUrl,
          runtimeMinutes: runtime ?? 45,
          runtimeEstimated: runtime == null,
          releaseYear: media.releaseYear,
          franchiseId: media.franchiseId,
          franchiseOrder: media.franchiseOrder,
          seasonNumber: episodeSeason,
          episodeNumber: episodeNumber,
          episodeOrderNeedsReview: needsReview,
        ));
      }
    }

    if (entries.isEmpty) {
      return <MarathonEntry>[
        MarathonEntry(
          id: '${media.id}::episode-metadata-missing',
          mediaId: media.id,
          parentTitle: media.title,
          title: '${media.title} · Episode metadata unavailable',
          mediaType: 'episode',
          imageUrl: media.imageUrl,
          runtimeMinutes: 45,
          runtimeEstimated: true,
          releaseYear: media.releaseYear,
          franchiseId: media.franchiseId,
          franchiseOrder: media.franchiseOrder,
          episodeOrderNeedsReview: true,
        ),
      ];
    }
    // Sort the final flattened list as well as each season. This matters when
    // an episode's SxxExx code is the only source of season order.
    entries.sort(MarathonPlannerMath.compareCanonical);
    return entries;
  }

  static int _defaultRuntimeForType(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('music') || lower.contains('track') || lower.contains('song')) return 5;
    if (lower.contains('episode')) return 45;
    if (lower.contains('short')) return 20;
    return 120;
  }

  static int? _episodeRuntime(Map<String, dynamic> episode) {
    for (final key in const ['runtimeMinutes', 'durationMinutes', 'runtime_minutes']) {
      final value = _readInt(episode[key]);
      if (value != null && value > 0) return value.clamp(1, 1440).toInt();
    }
    for (final key in const ['durationSeconds', 'runtimeSeconds', 'duration_seconds']) {
      final value = _readInt(episode[key]);
      if (value != null && value > 0) return (value / 60).ceil().clamp(1, 1440).toInt();
    }
    final duration = _readInt(episode['duration'] ?? episode['runtime']);
    if (duration != null && duration > 0) {
      // Existing series metadata uses values such as 42/44/46 for minutes.
      return duration > 600 ? (duration / 60).ceil().clamp(1, 1440).toInt() : duration.clamp(1, 1440).toInt();
    }
    return null;
  }

  static int? _seasonNumber(Map<String, dynamic> season) {
    final explicit = _readInt(
      season['seasonNumber'] ?? season['season_number'] ?? season['season'] ?? season['number'],
    );
    if (explicit != null) return explicit;
    final label = _seasonLabel(season);
    final match = RegExp(r'\b(?:season|series|s)\s*#?0*(\d+)\b', caseSensitive: false).firstMatch(label);
    return match == null ? null : int.tryParse(match.group(1) ?? '');
  }

  static int? _seasonNumberFromEpisodeLabel(Map<String, dynamic> episode) {
    final label = '${episode['episodeCode'] ?? ''} ${episode['filename'] ?? ''} ${episode['title'] ?? episode['name'] ?? ''}';
    final match = RegExp(r'\bS(\d{1,2})\s*E\d{1,3}\b', caseSensitive: false).firstMatch(label);
    return match == null ? null : int.tryParse(match.group(1) ?? '');
  }

  static String _seasonLabel(Map<String, dynamic> season) =>
      (season['title'] ?? season['name'] ?? '').toString().toLowerCase();

  static int? _episodeNumber(Map<String, dynamic> episode) {
    final explicit = _readInt(
      episode['episodeNumber'] ?? episode['episode_number'] ?? episode['episode'] ?? episode['number'],
    );
    if (explicit != null) return explicit;
    final label = '${episode['episodeCode'] ?? ''} ${episode['filename'] ?? ''} ${episode['title'] ?? episode['name'] ?? ''}';
    final patterns = <RegExp>[
      RegExp(r'\bS\d{1,2}\s*E(\d{1,3})\b', caseSensitive: false),
      RegExp(r'\bEpisode\s*#?0*(\d{1,3})\b', caseSensitive: false),
      RegExp(r'\bE(?:p)?\s*0*(\d{1,3})\b', caseSensitive: false),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(label);
      if (match != null) return int.tryParse(match.group(1) ?? '');
    }
    return null;
  }

  static String _episodeTitle(Map<String, dynamic> episode) =>
      (episode['title'] ?? episode['name'] ?? episode['episodeTitle'] ?? 'Untitled episode').toString().trim();
}

int? _readInt(Object? value) {
  if (value is int) return value;
  if (value is num && value.isFinite) return value.toInt();
  if (value == null) return null;
  final match = RegExp(r'-?\d+').firstMatch(value.toString());
  return match == null ? null : int.tryParse(match.group(0)!);
}

@immutable
class MarathonPlan {
  final String id;
  final String profileId;
  final String title;
  final String themeId;
  final DateTime startAt;
  final List<MarathonEntry> entries;
  final int breakEvery;
  final int breakMinutes;
  final String foodNotes;
  final DateTime createdAt;

  MarathonPlan({
    required this.id,
    required this.profileId,
    required this.title,
    required this.themeId,
    required this.startAt,
    required List<MarathonEntry> entries,
    required this.breakEvery,
    required this.breakMinutes,
    this.foodNotes = '',
    DateTime? createdAt,
  })  : entries = List<MarathonEntry>.unmodifiable(entries),
        createdAt = createdAt ?? DateTime.now();

  MarathonTheme get theme => heyMarathonThemes.firstWhere(
        (candidate) => candidate.id == themeId,
        orElse: () => heyMarathonThemes.last,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'profileId': profileId,
        'title': title,
        'themeId': themeId,
        'startAt': startAt.toIso8601String(),
        'entries': entries.map((entry) => entry.toJson()).toList(),
        'breakEvery': breakEvery,
        'breakMinutes': breakMinutes,
        'foodNotes': foodNotes,
        'createdAt': createdAt.toIso8601String(),
      };

  factory MarathonPlan.fromJson(Map<String, dynamic> json) => MarathonPlan(
        id: json['id']?.toString() ?? '',
        profileId: json['profileId']?.toString() ?? '',
        title: json['title']?.toString() ?? 'Movie Marathon',
        themeId: json['themeId']?.toString() ?? 'cozy-cinema',
        startAt: DateTime.tryParse(json['startAt']?.toString() ?? '') ?? DateTime.now(),
        entries: (json['entries'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => MarathonEntry.fromJson(Map<String, dynamic>.from(item)))
            .toList(),
        breakEvery: (_readInt(json['breakEvery']) ?? 2).clamp(1, 10).toInt(),
        breakMinutes: (_readInt(json['breakMinutes']) ?? 15).clamp(0, 120).toInt(),
        foodNotes: json['foodNotes']?.toString() ?? '',
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      );
}

@immutable
class MarathonScheduleRow {
  final MarathonEntry? entry;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool isBreak;

  const MarathonScheduleRow({
    required this.entry,
    required this.startsAt,
    required this.endsAt,
    required this.isBreak,
  });
}

class MarathonPlannerMath {
  static List<MarathonScheduleRow> schedule(MarathonPlan plan) {
    final rows = <MarathonScheduleRow>[];
    var current = plan.startAt;
    for (var index = 0; index < plan.entries.length; index++) {
      final entry = plan.entries[index];
      final end = current.add(Duration(minutes: entry.runtimeMinutes.clamp(1, 1440).toInt()));
      rows.add(MarathonScheduleRow(entry: entry, startsAt: current, endsAt: end, isBreak: false));
      current = end;
      final afterCount = index + 1;
      if (afterCount < plan.entries.length && afterCount % plan.breakEvery == 0 && plan.breakMinutes > 0) {
        final breakEnd = current.add(Duration(minutes: plan.breakMinutes.clamp(0, 120).toInt()));
        rows.add(MarathonScheduleRow(entry: null, startsAt: current, endsAt: breakEnd, isBreak: true));
        current = breakEnd;
      }
    }
    return rows;
  }

  static int compareCanonical(MarathonEntry a, MarathonEntry b) {
    if (a.mediaId == b.mediaId && a.isEpisode && b.isEpisode) {
      final seasonA = a.seasonNumber;
      final seasonB = b.seasonNumber;
      if (seasonA != null && seasonB != null && seasonA != seasonB) return seasonA.compareTo(seasonB);
      if (seasonA == null && seasonB != null) return 1;
      if (seasonB == null && seasonA != null) return -1;
      final epA = a.episodeNumber;
      final epB = b.episodeNumber;
      if (epA != null && epB != null && epA != epB) return epA.compareTo(epB);
      if (epA == null && epB != null) return 1;
      if (epB == null && epA != null) return -1;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    }
    if (a.franchiseId != null && a.franchiseId == b.franchiseId) {
      if (a.franchiseOrder != null && b.franchiseOrder != null && a.franchiseOrder != b.franchiseOrder) {
        return a.franchiseOrder!.compareTo(b.franchiseOrder!);
      }
    }
    if (a.releaseYear != null && b.releaseYear != null && a.releaseYear != b.releaseYear) {
      return a.releaseYear!.compareTo(b.releaseYear!);
    }
    final parent = a.parentTitle.toLowerCase().compareTo(b.parentTitle.toLowerCase());
    if (parent != 0) return parent;
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  }
}

class HeyMarathonStore {
  static String _key(String profileId) => 'hey_marathon_plans_v1_${profileId.isEmpty ? 'guest' : profileId}';

  static Future<List<MarathonPlan>> load(String profileId) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(profileId));
    if (raw == null || raw.isEmpty) return <MarathonPlan>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <MarathonPlan>[];
      return decoded
          .whereType<Map>()
          .map((item) => MarathonPlan.fromJson(Map<String, dynamic>.from(item)))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {
      return <MarathonPlan>[];
    }
  }

  static Future<void> save(String profileId, List<MarathonPlan> plans) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _key(profileId),
      jsonEncode(plans.map((plan) => plan.toJson()).toList()),
    );
  }
}

class HeyMarathonScreen extends StatefulWidget {
  const HeyMarathonScreen({super.key});

  @override
  State<HeyMarathonScreen> createState() => _HeyMarathonScreenState();
}

class _HeyMarathonScreenState extends State<HeyMarathonScreen> {
  final TextEditingController _titleController = TextEditingController(text: 'Movie Marathon');
  final TextEditingController _foodNotesController = TextEditingController();
  final AppController _app = AppController.instance;
  List<MarathonPlan> _plans = <MarathonPlan>[];
  List<MarathonEntry> _draftEntries = <MarathonEntry>[];
  String _themeId = 'cozy-cinema';
  DateTime _startAt = DateTime.now().add(const Duration(hours: 1));
  int _breakEvery = 2;
  int _breakMinutes = 15;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  String get _profileId => _app.currentProfile?.id ?? 'guest';
  MarathonTheme get _theme => heyMarathonThemes.firstWhere(
        (item) => item.id == _themeId,
        orElse: () => heyMarathonThemes.last,
      );

  @override
  void initState() {
    super.initState();
    unawaited(_setProfileActivity('Planning a Hey Marathon'));
    _loadPlans();
  }

  Future<void> _setProfileActivity(String? activity) async {
    final profile = _app.currentProfile;
    final api = _app.backendApi;
    if (profile == null || !api.isAuthenticated) return;
    try {
      if (activity == null) {
        await api.setSocialProfilePresence(
          profileId: profile.id,
          availability: 'active',
          clearActivity: true,
        );
      } else {
        await api.setSocialProfilePresence(
          profileId: profile.id,
          availability: 'active',
          activityType: 'planning_marathon',
          activityText: activity,
        );
      }
    } catch (_) {
      // Presence is optional and must not interrupt marathon planning.
    }
  }

  @override
  void dispose() {
    unawaited(_setProfileActivity(null));
    _titleController.dispose();
    _foodNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadPlans() async {
    try {
      final plans = await HeyMarathonStore.load(_profileId);
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Saved plans could not be loaded: $error';
        _loading = false;
      });
    }
  }

  Future<void> _chooseStartTime() async {
    final now = DateTime.now();
    final chosenDate = await showDatePicker(
      context: context,
      initialDate: _startAt.isBefore(now) ? now : _startAt,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 3),
    );
    if (!mounted || chosenDate == null) return;
    final chosenTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startAt),
    );
    if (!mounted || chosenTime == null) return;
    setState(() {
      _startAt = DateTime(chosenDate.year, chosenDate.month, chosenDate.day, chosenTime.hour, chosenTime.minute);
    });
  }

  Future<void> _addFromLibrary() async {
    if (_app.library.isEmpty) {
      _toast('Your library is empty. Import movies or TV episodes first.');
      return;
    }
    final selected = await showDialog<List<MarathonEntry>>(
      context: context,
      builder: (_) => _MarathonLibraryPicker(
        mediaItems: _app.library,
        alreadySelectedIds: _draftEntries.map((entry) => entry.id).toSet(),
      ),
    );
    if (!mounted || selected == null || selected.isEmpty) return;
    final byId = <String, MarathonEntry>{for (final entry in _draftEntries) entry.id: entry};
    for (final entry in selected) {
      byId.putIfAbsent(entry.id, () => entry);
    }
    setState(() {
      _draftEntries = byId.values.toList();
      _draftEntries.sort(MarathonPlannerMath.compareCanonical);
    });
  }

  Future<void> _editRuntime(int index) async {
    final entry = _draftEntries[index];
    final controller = TextEditingController(text: '${entry.runtimeMinutes}');
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const UniversalText('Set runtime'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Minutes', helperText: 'Use the title’s actual runtime when known.'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const UniversalText('Cancel')),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              if (parsed == null || parsed < 1 || parsed > 1440) return;
              Navigator.pop(dialogContext, parsed);
            },
            child: const UniversalText('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || result == null) return;
    setState(() => _draftEntries[index] = entry.withRuntime(result, estimated: false));
  }

  void _moveEntry(int index, int offset) {
    final target = index + offset;
    if (target < 0 || target >= _draftEntries.length) return;
    setState(() {
      final item = _draftEntries.removeAt(index);
      _draftEntries.insert(target, item);
    });
  }

  Future<void> _savePlan() async {
    if (_draftEntries.isEmpty) {
      _toast('Add at least one movie or episode first.');
      return;
    }
    final unresolved = _draftEntries.where((entry) => entry.episodeOrderNeedsReview).toList();
    if (unresolved.isNotEmpty) {
      _toast('Fix missing season/episode numbers before saving. ${unresolved.length} item(s) need review.');
      return;
    }
    setState(() => _saving = true);
    final cleanTitle = _titleController.text.trim();
    final plan = MarathonPlan(
      id: 'marathon_${DateTime.now().microsecondsSinceEpoch}',
      profileId: _profileId,
      title: cleanTitle.isEmpty ? 'Movie Marathon' : cleanTitle,
      themeId: _themeId,
      startAt: _startAt,
      entries: _draftEntries,
      breakEvery: _breakEvery,
      breakMinutes: _breakMinutes,
      foodNotes: _foodNotesController.text.trim(),
    );
    try {
      final next = <MarathonPlan>[plan, ..._plans];
      await HeyMarathonStore.save(_profileId, next);
      if (!mounted) return;
      setState(() {
        _plans = next;
        _draftEntries = <MarathonEntry>[];
        _titleController.text = 'Movie Marathon';
        _foodNotesController.clear();
        _saving = false;
      });
      _toast('Marathon plan saved on this device for the current profile.');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Unable to save this plan: $error';
      });
    }
  }

  void _loadDraft(MarathonPlan plan) {
    setState(() {
      _titleController.text = plan.title;
      _themeId = plan.themeId;
      _startAt = plan.startAt;
      _breakEvery = plan.breakEvery;
      _breakMinutes = plan.breakMinutes;
      _foodNotesController.text = plan.foodNotes;
      _draftEntries = List<MarathonEntry>.from(plan.entries);
    });
    _toast('Plan loaded into the editor. Saving it creates a new copy.');
  }

  Future<void> _deletePlan(MarathonPlan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const UniversalText('Delete marathon plan?'),
        content: Text('Delete “${plan.title}” from this profile on this device?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const UniversalText('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const UniversalText('Delete')),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    final next = _plans.where((item) => item.id != plan.id).toList();
    await HeyMarathonStore.save(_profileId, next);
    if (mounted) setState(() => _plans = next);
  }

  Future<void> _sharePlan(MarathonPlan plan) async {
    final rows = MarathonPlannerMath.schedule(plan);
    final end = rows.isEmpty ? plan.startAt : rows.last.endsAt;
    final schedule = plan.entries.asMap().entries.map((indexed) {
      final entry = indexed.value;
      final number = (indexed.key + 1).toString();
      return '$number. ${entry.title} (${entry.runtimeMinutes} min${entry.runtimeEstimated ? ', estimate' : ''})';
    }).join('\n');
    final text = <String>[
      '🎬 ${plan.title}',
      'Theme: ${plan.theme.title}',
      'Start: ${_formatDateTime(plan.startAt)}',
      'Estimated finish: ${_formatDateTime(end)}',
      'Food inspiration: ${plan.theme.foodIdeas.take(3).join(', ')}',
      '',
      schedule,
      if (plan.foodNotes.trim().isNotEmpty) ...['', 'Food notes: ${plan.foodNotes.trim()}'],
      '',
      'Made with MyOwnStreamingService · Timings are estimates where marked.',
    ].join('\n');
    try {
      await SharePlus.instance.share(ShareParams(title: plan.title, text: text));
    } catch (error) {
      if (mounted) _toast('Could not open sharing: $error');
    }
  }

  Future<void> _openFood(MarathonPlan plan) async {
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/app/page/hey-marathon/food'),
      builder: (_) => FoodOrderingScreen(
        viewingContext: 'Hey Marathon · ${plan.title} · ${plan.theme.title} · themed food ideas: ${plan.theme.foodIdeas.take(3).join(', ')}${plan.foodNotes.isEmpty ? '' : ' · ${plan.foodNotes}'}',
      ),
    ));
  }

  Future<void> _startGroupWatch(MarathonPlan plan) async {
    if (!_app.backendApi.isAuthenticated) {
      _toast('Sign in to create a synchronized Group Watch session. You can still share the marathon plan.');
      return;
    }
    if (plan.entries.isEmpty) return;
    final first = plan.entries.first;
    MediaItem? media;
    for (final item in _app.library) {
      if (item.id == first.mediaId) {
        media = item;
        break;
      }
    }
    if (media == null) {
      _toast('The first title is no longer in the current library.');
      return;
    }
    final profileId = _app.currentProfile?.id;
    if (profileId == null || profileId.isEmpty) {
      _toast('Select a profile before starting a watch party.');
      return;
    }
    try {
      final session = await _app.createBackendGroupWatchSession(media, profileId: profileId);
      if (!mounted) return;
      await Navigator.of(context).push<void>(MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/app/page/hey-marathon/group-watch'),
        builder: (_) => GroupWatchScreen(media: media!, sessionId: session.id),
      ));
    } catch (error) {
      if (mounted) _toast('Could not start Group Watch: ${error.toString().replaceFirst('Exception: ', '')}');
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDateTime(DateTime value) {
    final date = MaterialLocalizations.of(context).formatMediumDate(value);
    final time = MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(value));
    return '$date · $time';
  }

  String _formatTime(DateTime value) => MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(value));

  @override
  Widget build(BuildContext context) {
    final unresolvedCount = _draftEntries.where((entry) => entry.episodeOrderNeedsReview).length;
    final draftPlan = MarathonPlan(
      id: 'draft',
      profileId: _profileId,
      title: _titleController.text.trim().isEmpty ? 'Movie Marathon' : _titleController.text.trim(),
      themeId: _themeId,
      startAt: _startAt,
      entries: _draftEntries,
      breakEvery: _breakEvery,
      breakMinutes: _breakMinutes,
      foodNotes: _foodNotesController.text,
    );
    final schedule = MarathonPlannerMath.schedule(draftPlan);
    final finish = schedule.isEmpty ? _startAt : schedule.last.endsAt;
    final plannedMinutes = _draftEntries.fold<int>(0, (sum, entry) => sum + entry.runtimeMinutes) +
        ((_draftEntries.length <= 1 || _breakMinutes == 0) ? 0 : ((_draftEntries.length - 1) ~/ _breakEvery) * _breakMinutes);

    return Scaffold(
      appBar: AppBar(
        title: const UniversalText('Hey Marathon'),
        actions: [
          const PageCustomizeButton(pageId: 'hey-marathon'),
          IconButton(
            tooltip: 'Share current draft',
            onPressed: _draftEntries.isEmpty ? null : () => _sharePlan(draftPlan),
            icon: const Icon(Icons.ios_share_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[Color(0xFF29204D), Color(0xFF121C2E), Color(0xFF101010)],
                    ),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.movie_filter_rounded, size: 34, color: Color(0xFFFFD36E)),
                    const SizedBox(height: 10),
                    const UniversalText('Your whole movie night, planned.', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    const UniversalText('Build a watch order from your library, schedule breaks, invite friends, and find themed food.', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      _featureChip(Icons.schedule_rounded, 'Runtime-aware schedule'),
                      _featureChip(Icons.people_alt_rounded, 'Share invitations'),
                      _featureChip(Icons.restaurant_rounded, 'Food handoff'),
                    ]),
                  ]),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Card(color: Theme.of(context).colorScheme.errorContainer, child: Padding(padding: const EdgeInsets.all(12), child: Text(_error!))),
                ],
                const SizedBox(height: 18),
                _sectionTitle('Plan a marathon', 'Create a local plan for the selected profile.'),
                const SizedBox(height: 10),
                TextField(
                  controller: _titleController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Marathon name', hintText: 'Harry Potter · Saturday night', prefixIcon: Icon(Icons.edit_rounded)),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _themeId,
                  decoration: const InputDecoration(labelText: 'Theme', prefixIcon: Icon(Icons.auto_awesome_rounded)),
                  items: heyMarathonThemes.map((item) => DropdownMenuItem<String>(value: item.id, child: Text(item.title))).toList(),
                  onChanged: (value) { if (value != null) setState(() => _themeId = value); },
                ),
                const SizedBox(height: 8),
                Text(_theme.description, style: const TextStyle(color: Colors.white60)),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _chooseStartTime,
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: Text('Start: ${_formatDateTime(_startAt)}'),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: DropdownButtonFormField<int>(
                    initialValue: _breakEvery,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Break after'),
                    items: <int>[1, 2, 3, 4, 5].map((value) => DropdownMenuItem<int>(value: value, child: Text('$value title(s)'))).toList(),
                    onChanged: (value) { if (value != null) setState(() => _breakEvery = value); },
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: DropdownButtonFormField<int>(
                    initialValue: _breakMinutes,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Break length'),
                    items: <int>[0, 5, 10, 15, 20, 30, 45].map((value) => DropdownMenuItem<int>(value: value, child: Text(value == 0 ? 'No break' : '$value min'))).toList(),
                    onChanged: (value) { if (value != null) setState(() => _breakMinutes = value); },
                  )),
                ]),
                const SizedBox(height: 12),
                TextField(
                  controller: _foodNotesController,
                  onChanged: (_) => setState(() {}),
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Food notes (optional)', hintText: 'Vegetarian options, no nuts, pickup before the first film…', prefixIcon: Icon(Icons.restaurant_menu_rounded)),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: Text('Watch order (${_draftEntries.length})', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
                  TextButton.icon(onPressed: _addFromLibrary, icon: const Icon(Icons.add_rounded), label: const UniversalText('Add from library')),
                ]),
                if (_draftEntries.isEmpty)
                  _emptyCard(Icons.video_library_outlined, 'No titles added yet', 'Add movies or individual TV episodes from your imported library.')
                else ...[
                  if (unresolvedCount > 0)
                    Card(color: const Color(0xFF4B3212), child: const ListTile(
                      leading: Icon(Icons.warning_amber_rounded, color: Color(0xFFFFD36E)),
                      title: UniversalText('Episode order needs review'),
                      subtitle: UniversalText('One or more episodes are missing canonical season/episode numbers. Update media metadata before saving to protect the watch order.'),
                    )),
                  for (var index = 0; index < _draftEntries.length; index++)
                    _draftEntryCard(index),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _draftEntries.length < 2 ? null : () => setState(() => _draftEntries.sort(MarathonPlannerMath.compareCanonical)),
                      icon: const Icon(Icons.sort_by_alpha_rounded),
                      label: const UniversalText('Restore canonical order'),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                _sectionTitle('Schedule preview', 'Includes title runtimes and planned breaks.'),
                const SizedBox(height: 8),
                Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [const Icon(Icons.timelapse_rounded), const SizedBox(width: 8), Expanded(child: Text('Estimated total: ${_formatDuration(plannedMinutes)}', style: const TextStyle(fontWeight: FontWeight.w800))),]),
                  const SizedBox(height: 4),
                  Text('Expected finish: ${_formatDateTime(finish)}', style: const TextStyle(color: Colors.white60)),
                  if (_draftEntries.any((entry) => entry.runtimeEstimated))
                    const Padding(padding: EdgeInsets.only(top: 8), child: UniversalText('Some runtimes are estimates. Edit a title’s runtime for a more accurate finish time.', style: TextStyle(color: Colors.amberAccent, fontSize: 12))),
                  const Divider(height: 22),
                  if (schedule.isEmpty) const UniversalText('Your timed schedule will appear here after you add titles.'),
                  for (var index = 0; index < schedule.length; index++) _scheduleRow(schedule[index], index),
                ]))),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _saving || _draftEntries.isEmpty || unresolvedCount > 0 ? null : _savePlan,
                  icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_rounded),
                  label: UniversalText(_saving ? 'Saving…' : 'Save marathon plan'),
                ),
                const SizedBox(height: 24),
                _sectionTitle('Themed food ideas', 'Ideas to discuss with your guests or find through participating restaurants.'),
                const SizedBox(height: 8),
                Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [Icon(_theme.icon), const SizedBox(width: 8), Expanded(child: Text(_theme.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)))]),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: _theme.foodIdeas.map((idea) => Chip(label: Text(idea))).toList()),
                  const SizedBox(height: 6),
                  const UniversalText('Fan-inspired suggestions only; not official or licensed menu items. Confirm ingredients and allergy/cross-contact information with the restaurant.', style: TextStyle(color: Colors.white60, fontSize: 12)),
                ]))),
                const SizedBox(height: 24),
                _sectionTitle('Saved plans (${_plans.length})', 'Stored locally for this profile on this device.'),
                const SizedBox(height: 8),
                if (_plans.isEmpty)
                  _emptyCard(Icons.event_note_rounded, 'No saved marathons yet', 'Save a plan above and it will appear here.')
                else
                  for (final plan in _plans) _savedPlanCard(plan),
              ],
            ),
    );
  }

  Widget _featureChip(IconData icon, String label) => Chip(
        avatar: Icon(icon, size: 16, color: const Color(0xFFFFD36E)),
        label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white.withValues(alpha: .08),
        side: BorderSide.none,
      );

  Widget _sectionTitle(String title, String subtitle) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 13)),
        ],
      );

  Widget _emptyCard(IconData icon, String title, String subtitle) => Card(
        child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [
          Icon(icon, size: 30, color: Colors.white38),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Colors.white60)),
          ])),
        ])),
      );

  Widget _draftEntryCard(int index) {
    final entry = _draftEntries[index];
    return Card(
      key: ValueKey(entry.id),
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), child: Row(children: [
        if (entry.imageUrl != null && entry.imageUrl!.startsWith('http'))
          ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(entry.imageUrl!, width: 48, height: 68, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(width: 48, height: 68, child: Icon(Icons.movie_outlined))))
        else
          Container(width: 48, height: 68, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)), child: Icon(entry.isEpisode ? Icons.tv_rounded : Icons.movie_rounded)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${index + 1}. ${entry.title}', maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('${entry.runtimeMinutes} min${entry.runtimeEstimated ? ' · estimated' : ''}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
          if (entry.episodeOrderNeedsReview) const Text('Episode order unverified', style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
        ])),
        Column(mainAxisSize: MainAxisSize.min, children: [
          IconButton(tooltip: 'Move up', visualDensity: VisualDensity.compact, onPressed: index == 0 ? null : () => _moveEntry(index, -1), icon: const Icon(Icons.keyboard_arrow_up_rounded)),
          IconButton(tooltip: 'Move down', visualDensity: VisualDensity.compact, onPressed: index == _draftEntries.length - 1 ? null : () => _moveEntry(index, 1), icon: const Icon(Icons.keyboard_arrow_down_rounded)),
        ]),
        PopupMenuButton<String>(
          tooltip: 'Title options',
          onSelected: (value) {
            if (value == 'runtime') _editRuntime(index);
            if (value == 'remove') setState(() => _draftEntries.removeAt(index));
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'runtime', child: Text('Edit runtime')),
            PopupMenuItem(value: 'remove', child: Text('Remove')),
          ],
        ),
      ])),
    );
  }

  Widget _scheduleRow(MarathonScheduleRow row, int index) {
    final duration = row.endsAt.difference(row.startsAt).inMinutes;
    return Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 102, child: Text('${_formatTime(row.startsAt)}\n${_formatTime(row.endsAt)}', style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.45))),
      Container(width: 3, height: 38, margin: const EdgeInsets.only(right: 10), decoration: BoxDecoration(color: row.isBreak ? Colors.amber : Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(2))),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(row.isBreak ? 'Break · $duration min' : row.entry!.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
        if (!row.isBreak && row.entry!.runtimeEstimated) const UniversalText('Estimated runtime', style: TextStyle(color: Colors.white54, fontSize: 11)),
      ])),
    ]));
  }

  Widget _savedPlanCard(MarathonPlan plan) {
    final rows = MarathonPlannerMath.schedule(plan);
    final finish = rows.isEmpty ? plan.startAt : rows.last.endsAt;
    return Card(
      child: ExpansionTile(
        leading: CircleAvatar(child: Icon(plan.theme.icon)),
        title: Text(plan.title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text('${plan.theme.title} · ${plan.entries.length} title(s) · ${_formatDateTime(plan.startAt)}', maxLines: 2),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [
          Align(alignment: Alignment.centerLeft, child: Text('Estimated finish: ${_formatDateTime(finish)}', style: const TextStyle(color: Colors.white60))),
          for (var index = 0; index < plan.entries.length; index++)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(radius: 13, child: Text('${index + 1}', style: const TextStyle(fontSize: 11))),
              title: Text(plan.entries[index].title, maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: Text('${plan.entries[index].runtimeMinutes}m${plan.entries[index].runtimeEstimated ? '*' : ''}'),
            ),
          if (plan.foodNotes.trim().isNotEmpty) Align(alignment: Alignment.centerLeft, child: Text('Food notes: ${plan.foodNotes}', style: const TextStyle(color: Colors.white60))),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(onPressed: () => _loadDraft(plan), icon: const Icon(Icons.edit_rounded), label: const UniversalText('Load to editor')),
            OutlinedButton.icon(onPressed: () => _sharePlan(plan), icon: const Icon(Icons.ios_share_rounded), label: const UniversalText('Invite / share')),
            OutlinedButton.icon(onPressed: () => _openFood(plan), icon: const Icon(Icons.restaurant_rounded), label: const UniversalText('Find themed food')),
            FilledButton.tonalIcon(onPressed: () => _startGroupWatch(plan), icon: const Icon(Icons.play_circle_outline_rounded), label: const UniversalText('Start Group Watch')),
            TextButton.icon(onPressed: () => _deletePlan(plan), icon: const Icon(Icons.delete_outline_rounded), label: const UniversalText('Delete')),
          ]),
          const Padding(padding: EdgeInsets.only(top: 6), child: UniversalText('Group Watch synchronizes one selected library title at a time. The complete marathon schedule is shared separately.', style: TextStyle(color: Colors.white54, fontSize: 12))),
        ],
      ),
    );
  }
}

class _MarathonLibraryPicker extends StatefulWidget {
  final List<MediaItem> mediaItems;
  final Set<String> alreadySelectedIds;

  const _MarathonLibraryPicker({required this.mediaItems, required this.alreadySelectedIds});

  @override
  State<_MarathonLibraryPicker> createState() => _MarathonLibraryPickerState();
}

class _MarathonLibraryPickerState extends State<_MarathonLibraryPicker> {
  final TextEditingController _searchController = TextEditingController();
  late final List<MarathonEntry> _allEntries;
  late final Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _allEntries = widget.mediaItems
        .expand(MarathonEntry.fromMediaItem)
        .toList()
      ..sort(MarathonPlannerMath.compareCanonical);
    _selectedIds = <String>{};
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _allEntries.where((entry) =>
      query.isEmpty || entry.title.toLowerCase().contains(query) || entry.parentTitle.toLowerCase().contains(query));
    return AlertDialog(
      title: const UniversalText('Add from your library'),
      content: SizedBox(
        width: 600,
        height: MediaQuery.sizeOf(context).height * .62,
        child: Column(children: [
          TextField(controller: _searchController, decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search movies or episodes')),
          const SizedBox(height: 8),
          Expanded(child: filtered.isEmpty
            ? const Center(child: UniversalText('No matching titles.'))
            : ListView(children: [for (final entry in filtered) CheckboxListTile(
                value: _selectedIds.contains(entry.id),
                onChanged: widget.alreadySelectedIds.contains(entry.id) ? null : (selected) => setState(() {
                  if (selected == true) { _selectedIds.add(entry.id); } else { _selectedIds.remove(entry.id); }
                }),
                title: Text(entry.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text('${entry.runtimeMinutes} min${entry.runtimeEstimated ? ' · estimate' : ''}${entry.episodeOrderNeedsReview ? ' · episode order needs review' : ''}'),
                secondary: Icon(entry.isEpisode ? Icons.tv_rounded : Icons.movie_rounded),
                controlAffinity: ListTileControlAffinity.leading,
              )]),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const UniversalText('Cancel')),
        FilledButton(onPressed: _selectedIds.isEmpty ? null : () => Navigator.pop(context, _allEntries.where((entry) => _selectedIds.contains(entry.id)).toList()), child: Text('Add ${_selectedIds.length}')),
      ],
    );
  }
}

String _formatDuration(int minutes) {
  final hours = minutes ~/ 60;
  final remaining = minutes % 60;
  if (hours == 0) return '$remaining min';
  if (remaining == 0) return '${hours}h';
  return '${hours}h ${remaining}m';
}
