import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSectionCustomization {
  String shopCardStyle;
  int shopColumns;
  bool showShopPrices;
  bool showShopInventory;
  String libraryCardStyle;
  int libraryColumns;
  String friendsDisplayStyle;

  AppSectionCustomization({
    this.shopCardStyle = 'Comfortable',
    this.shopColumns = 2,
    this.showShopPrices = true,
    this.showShopInventory = false,
    this.libraryCardStyle = 'Poster',
    this.libraryColumns = 2,
    this.friendsDisplayStyle = 'Cards',
  });

  Map<String, dynamic> toJson() => {
        'shopCardStyle': shopCardStyle,
        'shopColumns': shopColumns,
        'showShopPrices': showShopPrices,
        'showShopInventory': showShopInventory,
        'libraryCardStyle': libraryCardStyle,
        'libraryColumns': libraryColumns,
        'friendsDisplayStyle': friendsDisplayStyle,
      };

  factory AppSectionCustomization.fromJson(Map<String, dynamic> json) =>
      AppSectionCustomization(
        shopCardStyle: json['shopCardStyle']?.toString() ?? 'Comfortable',
        shopColumns: ((json['shopColumns'] as num?)?.toInt() ?? 2).clamp(1, 4).toInt(),
        showShopPrices: json['showShopPrices'] != false,
        showShopInventory: json['showShopInventory'] == true,
        libraryCardStyle: json['libraryCardStyle']?.toString() ?? 'Poster',
        libraryColumns: ((json['libraryColumns'] as num?)?.toInt() ?? 2).clamp(1, 6).toInt(),
        friendsDisplayStyle: json['friendsDisplayStyle']?.toString() ?? 'Cards',
      );
}

class AppSectionCustomizationStore {
  static final Map<String, AppSectionCustomization> _cache = {};
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);
  static SharedPreferences? _prefs;

  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    for (final key in _prefs!.getKeys()) {
      if (!key.startsWith('app_section_customization_')) continue;
      final raw = _prefs!.getString(key);
      if (raw == null) continue;
      try {
        _cache[key.substring('app_section_customization_'.length)] =
            AppSectionCustomization.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
      } catch (_) {}
    }
  }

  static AppSectionCustomization settingsFor(dynamic profile) {
    final id = profile?.id?.toString();
    if (id == null || id.isEmpty) return AppSectionCustomization();
    return _cache[id] ??= AppSectionCustomization();
  }

  static Future<void> save(dynamic profile, AppSectionCustomization value) async {
    final id = profile?.id?.toString();
    if (id == null || id.isEmpty) return;
    _cache[id] = value;
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setString('app_section_customization_$id', jsonEncode(value.toJson()));
    revision.value++;
  }
}
