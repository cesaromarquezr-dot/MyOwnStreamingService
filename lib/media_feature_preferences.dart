import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_core.dart';
import 'genre_system.dart';

/// Profile-scoped preferences for the connected entertainment experience.
/// These settings are stored locally; they do not replace account/server privacy
/// controls or claim to sync across devices.
class MediaFeaturePreferences {
  MediaFeaturePreferences._();

  static String get _scope {
    final profile = AppController.instance.currentProfile;
    final id = profile?.id.trim() ?? '';
    if (id.isEmpty) return 'guest';
    return 'profile_${id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}';
  }

  static String _key(String name) => 'moss_media_feature_${_scope}_$name';

  static const String _tasteKeyName = 'taste_tuner';
  static const String _queueKeyName = 'next_up_queue';
  static const String _travelKeyName = 'travel_prep';
  static const String _nightPlanKeyName = 'media_night_plan';
  static const String _spoilerKeyName = 'spoiler_shield';

  static Future<TasteTunerPreferences> loadTaste() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(_tasteKeyName));
    if (raw == null || raw.isEmpty) return const TasteTunerPreferences();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return TasteTunerPreferences.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      // Corrupt optional preferences should not prevent the app from opening.
    }
    return const TasteTunerPreferences();
  }

  static Future<void> saveTaste(TasteTunerPreferences value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(_tasteKeyName), jsonEncode(value.toJson()));
  }

  static Future<bool> loadSpoilerShield() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(_spoilerKeyName)) ?? false;
  }

  static Future<void> saveSpoilerShield(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(_spoilerKeyName), enabled);
  }

  static Future<List<String>> loadNextUpQueue() => _loadStringList(_queueKeyName, typedMediaTokens: true);

  static Future<void> addToNextUpQueue(Iterable<String> ids) async {
    final queue = await loadNextUpQueue();
    final seen = queue.toSet();
    for (final raw in ids) {
      final id = _normalizeMediaToken(raw);
      if (id.isNotEmpty && seen.add(id)) queue.add(id);
    }
    await _saveStringList(_queueKeyName, queue);
  }

  static Future<void> removeFromNextUpQueue(String id) async {
    final queue = await loadNextUpQueue();
    final normalized = _normalizeMediaToken(id);
    queue.removeWhere((value) => value == normalized);
    await _saveStringList(_queueKeyName, queue);
  }

  static Future<void> moveNextUpQueueItem(int from, int to) async {
    final queue = await loadNextUpQueue();
    if (from < 0 || from >= queue.length || to < 0 || to >= queue.length || from == to) {
      return;
    }
    final item = queue.removeAt(from);
    queue.insert(to, item);
    await _saveStringList(_queueKeyName, queue);
  }

  static Future<void> replaceNextUpQueue(Iterable<String> ids) async {
    final queue = <String>[];
    final seen = <String>{};
    for (final raw in ids) {
      final id = _normalizeMediaToken(raw);
      if (id.isNotEmpty && seen.add(id)) queue.add(id);
    }
    await _saveStringList(_queueKeyName, queue);
  }

  static Future<List<String>> loadTravelPrep() => _loadStringList(_travelKeyName, typedMediaTokens: true);

  static Future<void> updateTravelPrep(String id, bool selected) async {
    final values = await loadTravelPrep();
    final normalized = _normalizeMediaToken(id);
    if (selected) {
      if (!values.contains(normalized)) values.add(normalized);
    } else {
      values.removeWhere((value) => value == normalized);
    }
    await _saveStringList(_travelKeyName, values);
  }

  static Future<void> clearTravelPrep() async => _saveStringList(_travelKeyName, <String>[]);

  static Future<Map<String, dynamic>?> loadMediaNightPlan() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(_nightPlanKeyName));
    if (raw == null || raw.isEmpty) return null;
    try {
      final value = jsonDecode(raw);
      if (value is Map) return Map<String, dynamic>.from(value);
    } catch (_) {
      // Treat invalid optional plan data as absent.
    }
    return null;
  }

  static Future<void> saveMediaNightPlan(Map<String, dynamic> plan) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(_nightPlanKeyName), jsonEncode(plan));
  }

  static String _normalizeMediaToken(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    if (value.startsWith('media:') || value.startsWith('music:')) return value;
    return 'media:$value';
  }

  static Future<void> _saveStringList(String name, List<String> values) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(name), jsonEncode(values));
  }

  static Future<List<String>> _loadStringList(String name, {bool typedMediaTokens = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(name));
    if (raw == null || raw.isEmpty) return <String>[];
    try {
      final value = jsonDecode(raw);
      if (value is List) {
        final seen = <String>{};
        return value
            .map((entry) => typedMediaTokens ? _normalizeMediaToken(entry.toString()) : entry.toString().trim())
            .where((entry) => entry.isNotEmpty && seen.add(entry))
            .toList();
      }
    } catch (_) {
      // Ignore damaged local list and let the user rebuild it.
    }
    return <String>[];
  }

  /// Clears only this module's local settings for the currently selected profile.
  /// Watch history, account data, backend records and credentials are untouched.
  static Future<void> clearCurrentProfileLocalSettings() async {
    final prefs = await SharedPreferences.getInstance();
    for (final name in <String>[
      _tasteKeyName,
      _queueKeyName,
      _travelKeyName,
      _nightPlanKeyName,
      _spoilerKeyName,
    ]) {
      await prefs.remove(_key(name));
    }
  }
}

class TasteTunerPreferences {
  final List<String> preferredGenres;
  final List<String> excludedGenres;
  final double minimumRating;
  final bool hideWatched;

  const TasteTunerPreferences({
    this.preferredGenres = const <String>[],
    this.excludedGenres = const <String>[],
    this.minimumRating = 0,
    this.hideWatched = false,
  });

  factory TasteTunerPreferences.fromJson(Map<String, dynamic> json) {
    List<String> strings(Object? value) => value is List
        ? value.map((entry) => entry.toString()).where((entry) => entry.trim().isNotEmpty).toSet().toList()
        : <String>[];
    final rating = json['minimumRating'];
    return TasteTunerPreferences(
      preferredGenres: strings(json['preferredGenres']),
      excludedGenres: strings(json['excludedGenres']),
      minimumRating: (rating is num ? rating.toDouble() : double.tryParse('$rating') ?? 0).clamp(0.0, 10.0).toDouble(),
      hideWatched: json['hideWatched'] == true,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'preferredGenres': preferredGenres,
        'excludedGenres': excludedGenres,
        'minimumRating': minimumRating,
        'hideWatched': hideWatched,
      };
}

enum CatalogAvailabilityKind { personalPlayback, physicalCopy, metadataOnly }

class MediaCatalogFinding {
  final String code;
  final String severity;
  final String message;
  final List<String> mediaIds;

  const MediaCatalogFinding({
    required this.code,
    required this.severity,
    required this.message,
    this.mediaIds = const <String>[],
  });
}

/// Pure helper logic used by Media Night tools and unit tests.
class MediaNightFeatureLogic {
  MediaNightFeatureLogic._();

  static bool hasPhysicalCopy(MediaItem item) =>
      (item.discType ?? '').trim().isNotEmpty ||
      (item.discTitleId ?? '').trim().isNotEmpty ||
      (item.discCollectionId ?? '').trim().isNotEmpty ||
      (item.discTitle ?? '').trim().isNotEmpty;

  static bool hasAuthorizedPlaybackUrl(MediaItem item) =>
      (item.playbackUrl ?? '').trim().isNotEmpty;

  static CatalogAvailabilityKind availability(MediaItem item) {
    if (hasAuthorizedPlaybackUrl(item)) return CatalogAvailabilityKind.personalPlayback;
    if (hasPhysicalCopy(item)) return CatalogAvailabilityKind.physicalCopy;
    return CatalogAvailabilityKind.metadataOnly;
  }

  static Set<String> genreComponents(MediaItem item) => <String>{
        for (final genre in GenreSystem.normalizeGenres(item.genres))
          ...GenreSystem.componentsFor(genre).map((value) => value.trim().toLowerCase()),
      };

  static bool matchesTaste(
    MediaItem item,
    TasteTunerPreferences preferences, {
    Set<String> watchedIds = const <String>{},
  }) {
    final components = genreComponents(item);
    final excluded = <String>{
      for (final genre in preferences.excludedGenres)
        ...GenreSystem.componentsFor(genre).map((value) => value.trim().toLowerCase()),
    };
    if (components.intersection(excluded).isNotEmpty) return false;

    final preferred = preferences.preferredGenres;
    if (preferred.isNotEmpty &&
        !GenreSystem.matchesGenres(item.genres, preferred, matchAll: false)) {
      return false;
    }
    if (preferences.minimumRating > 0 &&
        item.rating != null &&
        item.rating! < preferences.minimumRating) {
      return false;
    }
    if (preferences.hideWatched && watchedIds.contains(item.id)) return false;
    return true;
  }

  static double tasteScore(MediaItem item, TasteTunerPreferences preferences) {
    var score = item.rating ?? 0;
    final components = genreComponents(item);
    for (final genre in preferences.preferredGenres) {
      final requested = GenreSystem.componentsFor(genre).map((v) => v.toLowerCase());
      if (requested.any(components.contains)) score += 2.5;
    }
    if (item.imageUrl?.trim().isNotEmpty == true) score += .2;
    return score;
  }

  static List<MediaItem> rankForMood(Iterable<MediaItem> items, String mood) {
    final terms = switch (mood.toLowerCase()) {
      'funny & spooky' => <String>{'comedy', 'horror'},
      'romantic' => <String>{'romance'},
      'adventurous' => <String>{'adventure', 'action', 'fantasy'},
      'relaxed' => <String>{'comedy', 'family', 'animation', 'music'},
      'surprising' => <String>{'mystery', 'thriller', 'science fiction'},
      _ => <String>{'horror', 'thriller', 'mystery'},
    };
    final scored = <({MediaItem item, double score})>[];
    for (final item in items) {
      final genres = genreComponents(item);
      var score = genres.intersection(terms).length * 3.0;
      if (item.rating != null) score += item.rating! / 10;
      if (genres.isEmpty) score -= 1;
      scored.add((item: item, score: score));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.map((entry) => entry.item).toList(growable: false);
  }

  static List<MediaCatalogFinding> auditCatalog(Iterable<MediaItem> items) {
    final list = items.toList(growable: false);
    final findings = <MediaCatalogFinding>[];
    final titleKeys = <String, List<MediaItem>>{};
    for (final item in list) {
      final title = item.title.trim();
      if (title.isEmpty) {
        findings.add(MediaCatalogFinding(code: 'missing_title', severity: 'High', message: 'A catalog item has no title.', mediaIds: <String>[item.id]));
      } else {
        final normalized = title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
        final key = '$normalized|${item.releaseYear ?? 'unknown'}';
        titleKeys.putIfAbsent(key, () => <MediaItem>[]).add(item);
      }
      if (item.releaseYear == null) {
        findings.add(MediaCatalogFinding(code: 'missing_year', severity: 'Low', message: 'Release year is missing for “${title.isEmpty ? item.id : title}”.', mediaIds: <String>[item.id]));
      }
      if (item.genres.isEmpty) {
        findings.add(MediaCatalogFinding(code: 'missing_genres', severity: 'Medium', message: 'Genre metadata is missing for “${title.isEmpty ? item.id : title}”.', mediaIds: <String>[item.id]));
      }
      if ((item.imageUrl ?? '').trim().isEmpty) {
        findings.add(MediaCatalogFinding(code: 'missing_artwork', severity: 'Low', message: 'Artwork URL is missing for “${title.isEmpty ? item.id : title}”.', mediaIds: <String>[item.id]));
      }
      if (!hasAuthorizedPlaybackUrl(item) && !hasPhysicalCopy(item)) {
        findings.add(MediaCatalogFinding(code: 'no_playback_or_copy', severity: 'Medium', message: 'No personal playback URL or physical-copy metadata is recorded for “${title.isEmpty ? item.id : title}”.', mediaIds: <String>[item.id]));
      }
    }
    for (final group in titleKeys.values.where((group) => group.length > 1)) {
      final ids = group.map((item) => item.id).toList(growable: false);
      findings.add(MediaCatalogFinding(
        code: 'possible_duplicate',
        severity: 'Medium',
        message: 'Possible duplicate: ${group.first.title} (${group.first.releaseYear ?? 'year unknown'}) appears ${group.length} times.',
        mediaIds: ids,
      ));
    }
    return findings;
  }
}
