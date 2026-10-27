// Bounded profile-scoped offline catalog metadata. Playback URLs, signed URLs,
// account/profile membership, user-specific activity, and filesystem paths are
// intentionally not persisted in this cache. This is not an offline media store.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'privacy_preferences.dart';

class OfflineMetadataCache {
  OfflineMetadataCache({required this.profileId});

  final String profileId;
  static const String _keyPrefix = 'mos_offline_metadata_v1_';
  static const int maxItems = 500;
  static const int maxBytes = 2 * 1024 * 1024;

  String get _key => '$_keyPrefix${Uri.encodeComponent(profileId.trim().isEmpty ? 'default' : profileId.trim())}';

  static const Set<String> _allowedFields = <String>{
    'id', 'title', 'type', 'imageUrl', 'description', 'releaseYear', 'accessibleProfileIds',
    'rating', 'ratingReason', 'audienceRating', 'audienceReviewCount',
    'addedAt', 'addedSource', 'originalTitle', 'originalLanguage',
    'countryOfOrigin', 'canonicalTitle', 'language', 'franchiseName',
    'franchiseType', 'franchiseOrder', 'actors', 'characters', 'directors', 'writers',
    'music', 'genres', 'tags', 'studios', 'companies', 'seasons',
    // Physical-disc and edition metadata is catalog data, not a local path.
    'releaseDate', 'editionReleaseYear', 'editionReleaseDate', 'editionName',
    'editionType', 'canonicalWorkId', 'editionFeatures', 'discType',
    'discRegion', 'discCollectionId', 'discCollectionTitle', 'discNumber',
    'discTitleId', 'discTitle', 'discMarketCountry', 'parentMediaId',
  };

  Future<void> save(Iterable<Map<String, dynamic>> media) async {
    final preferences = await PrivacyPreferencesStore.load(profileId: profileId);
    final prefs = await SharedPreferences.getInstance();
    if (!preferences.allowOfflineMetadata) {
      await prefs.remove(_key);
      return;
    }

    final sanitized = <Map<String, dynamic>>[];
    for (final item in media.take(maxItems)) {
      final safe = _sanitizeItem(item);
      if (safe != null) sanitized.add(safe);
    }
    // Bound serialized storage even when descriptions or episode metadata are large.
    while (sanitized.isNotEmpty) {
      final encoded = jsonEncode(sanitized);
      if (utf8.encode(encoded).length <= maxBytes) {
        await prefs.setString(_key, encoded);
        return;
      }
      sanitized.removeLast();
    }
    await prefs.setString(_key, '[]');
  }

  Future<List<Map<String, dynamic>>> load() async {
    final preferences = await PrivacyPreferencesStore.load(profileId: profileId);
    final prefs = await SharedPreferences.getInstance();
    if (!preferences.allowOfflineMetadata) {
      await prefs.remove(_key);
      return <Map<String, dynamic>>[];
    }
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty || utf8.encode(raw).length > maxBytes) {
      return <Map<String, dynamic>>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <Map<String, dynamic>>[];
      return decoded
          .whereType<Map>()
          .take(maxItems)
          .map((item) => _sanitizeItem(Map<String, dynamic>.from(item)))
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  Map<String, dynamic>? _sanitizeItem(Map<String, dynamic> item) {
    final id = item['id']?.toString().trim() ?? '';
    final title = item['title']?.toString().trim() ?? '';
    if (id.isEmpty || title.isEmpty) return null;
    final safe = <String, dynamic>{};
    for (final field in _allowedFields) {
      if (!item.containsKey(field)) continue;
      final value = item[field];
      if (field == 'imageUrl') {
        final url = _safeArtworkUrl(value);
        if (url != null) safe[field] = url;
      } else if (field == 'seasons') {
        safe[field] = _sanitizeSeasons(value);
      } else if (const {'actors', 'characters', 'directors', 'writers', 'music', 'genres', 'tags', 'studios', 'companies', 'editionFeatures'}.contains(field)) {
        if (value is List) safe[field] = value.take(100).map((e) => e.toString()).toList();
      } else if (field == 'description' || field == 'ratingReason') {
        if (value is String) safe[field] = value.length > 4000 ? value.substring(0, 4000) : value;
      } else if (value is String || value is num || value is bool || value == null) {
        safe[field] = value;
      }
    }
    // Restrict restored metadata to the profile whose cache key holds it.
    // This matters because MediaItem.isAccessibleTo uses this allow-list.
    safe['accessibleProfileIds'] = <String>[profileId.trim().isEmpty ? 'default' : profileId.trim()];
    safe['id'] = id;
    safe['title'] = title.length > 300 ? title.substring(0, 300) : title;
    safe['type'] = item['type']?.toString() ?? 'movie';
    // Never allow playback URLs, trailer URLs, raw server paths, membership IDs,
    // or opaque user-specific fields into the offline cache.
    return safe;
  }

  String? _safeArtworkUrl(dynamic value) {
    if (value is! String || value.trim().isEmpty) return null;
    final raw = value.trim();
    if (raw.startsWith('assets/')) return raw;
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment) return null;
    return uri.toString();
  }

  List<Map<String, dynamic>> _sanitizeSeasons(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];
    final seasons = <Map<String, dynamic>>[];
    for (final rawSeason in value.whereType<Map>().take(50)) {
      final season = Map<String, dynamic>.from(rawSeason);
      final safeSeason = <String, dynamic>{};
      for (final key in const {'seasonNumber', 'title', 'description', 'releaseYear'}) {
        final v = season[key];
        if (v is String || v is num) safeSeason[key] = v is String && v.length > 1000 ? v.substring(0, 1000) : v;
      }
      final rawEpisodes = season['episodes'];
      if (rawEpisodes is List) {
        safeSeason['episodes'] = rawEpisodes.whereType<Map>().take(200).map((rawEpisode) {
          final episode = Map<String, dynamic>.from(rawEpisode);
          final safeEpisode = <String, dynamic>{};
          for (final key in const {'episodeNumber', 'title', 'description', 'duration', 'releaseYear'}) {
            final v = episode[key];
            if (v is String || v is num) safeEpisode[key] = v is String && v.length > 1000 ? v.substring(0, 1000) : v;
          }
          return safeEpisode;
        }).toList();
      }
      seasons.add(safeSeason);
    }
    return seasons;
  }
}
