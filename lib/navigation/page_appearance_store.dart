// Profile-scoped appearance preferences for individually customizable pages.
// Kept outside main.dart so the page-customization UI does not own persistence.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_core.dart';
import 'app_route_state.dart';

@immutable
class PageAppearance {
  final int accentColor;
  final int backgroundColor;
  final String density;

  const PageAppearance({
    this.accentColor = 0xFFE53935,
    this.backgroundColor = 0xFF090909,
    this.density = 'Comfortable',
  });

  PageAppearance copyWith({
    int? accentColor,
    int? backgroundColor,
    String? density,
  }) =>
      PageAppearance(
        accentColor: accentColor ?? this.accentColor,
        backgroundColor: backgroundColor ?? this.backgroundColor,
        density: density ?? this.density,
      );
}

class PageAppearanceStore {
  PageAppearanceStore._();

  static SharedPreferences? _prefs;
  static final Map<String, PageAppearance> _cache =
      <String, PageAppearance>{};

  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static String get _profileKey =>
      AppController.instance.currentProfile?.id ?? 'default';

  static String _key(String pageId) => 'page_appearance_${_profileKey}_$pageId';

  static PageAppearance forPage(String pageId) {
    final cacheKey = '${_profileKey}_$pageId';
    return _cache.putIfAbsent(cacheKey, () {
      final raw = _prefs?.getString(_key(pageId));
      if (raw == null) return const PageAppearance();
      try {
        final json = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        return PageAppearance(
          accentColor: (json['accentColor'] as num?)?.toInt() ?? 0xFFE53935,
          backgroundColor:
              (json['backgroundColor'] as num?)?.toInt() ?? 0xFF090909,
          density: json['density']?.toString() ?? 'Comfortable',
        );
      } catch (_) {
        return const PageAppearance();
      }
    });
  }

  static Future<void> save(String pageId, PageAppearance appearance) async {
    _cache['${_profileKey}_$pageId'] = appearance;
    await _prefs?.setString(
      _key(pageId),
      jsonEncode(<String, dynamic>{
        'accentColor': appearance.accentColor,
        'backgroundColor': appearance.backgroundColor,
        'density': appearance.density,
      }),
    );
    appPageState.refresh();
  }

  @visibleForTesting
  static void clearCacheForTesting() => _cache.clear();
}
