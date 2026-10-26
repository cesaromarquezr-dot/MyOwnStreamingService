import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Per-profile hero-banner choice for the Movies and TV Shows browse pages.
/// When enabled, the hero automatically advances every five seconds.
class BrowsePageHeroPreference {
  final bool showHero;

  const BrowsePageHeroPreference({this.showHero = true});

  static const int autoSlideIntervalSeconds = 5;

  BrowsePageHeroPreference copyWith({bool? showHero}) =>
      BrowsePageHeroPreference(showHero: showHero ?? this.showHero);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'showHero': showHero,
        'mode': showHero ? 'auto-slider' : 'off',
        'intervalSeconds': autoSlideIntervalSeconds,
      };

  factory BrowsePageHeroPreference.fromJson(Map<String, dynamic> json) =>
      BrowsePageHeroPreference(showHero: json['showHero'] != false);
}

/// Saves separate Movies and TV Shows hero-banner choices per active profile.
class BrowsePageHeroPreferenceStore {
  BrowsePageHeroPreferenceStore._();

  static const String _prefix = 'browse_page_hero_v1_';
  static SharedPreferences? _preferences;
  static final Map<String, BrowsePageHeroPreference> _cache =
      <String, BrowsePageHeroPreference>{};
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
    _cache.clear();
    for (final key in _preferences!.getKeys()) {
      if (!key.startsWith(_prefix)) continue;
      final raw = _preferences!.getString(key);
      if (raw == null || raw.isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          _cache[key] = BrowsePageHeroPreference.fromJson(
            Map<String, dynamic>.from(decoded),
          );
        }
      } catch (_) {
        // Ignore a malformed preference and use the default visible slider.
      }
    }
  }

  static String _key(String pageId, String? profileId) =>
      '$_prefix${Uri.encodeComponent((profileId == null || profileId.isEmpty) ? 'default' : profileId)}_$pageId';

  static BrowsePageHeroPreference settingsFor({
    required String pageId,
    String? profileId,
  }) =>
      _cache[_key(pageId, profileId)] ?? const BrowsePageHeroPreference();

  static Future<void> apply({
    required String pageId,
    required BrowsePageHeroPreference preference,
    String? profileId,
  }) async {
    final key = _key(pageId, profileId);
    _cache[key] = preference;
    await _preferences?.setString(key, jsonEncode(preference.toJson()));
    revision.value++;
  }
}
