import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stable theme identifiers used by each profile's social appearance settings.
/// Human-readable descriptions and sample previews live in
/// `social_theme_gallery.dart` so every theme preference has a visual example.
const List<String> socialThemeStyles = <String>[
  'Light',
  'Dark',
  'Minimalist',
  'Flat',
  'Skeuomorphic',
  'Material',
  'Neumorphism',
  'Glassmorphism',
  'High Contrast',
  'Brand-Centric',
  'Cyberpunk',
  'Retro Futurism',
  'Brutalism',
  'Compact',
  'Casual',
];

const List<String> socialSectionOrderDefaults = <String>[
  'Feed', 'Reels', 'Messages', 'Communities', 'Friends', 'My Page',
];

/// Profile-wide presentation modes shared by every Customize App screen.
const List<String> mediaArtworkDisplayModes = <String>[
  'Poster only',
  'Poster + backdrop',
  'Poster + backdrop or previews',
];

/// Reusable artwork selector shown in all page customization experiences.
class ArtworkDisplayModePicker extends StatelessWidget {
  const ArtworkDisplayModePicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = mediaArtworkDisplayModes.contains(value)
        ? value
        : mediaArtworkDisplayModes.first;
    return Card(
      color: const Color(0xFF141414),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Media artwork display',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            const Text(
              'Shared by all Customize App pages for this profile. Trailer preview thumbnails appear when available; hero banners can override this in their own settings.',
              style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.35),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: selected,
              decoration: const InputDecoration(labelText: 'Show artwork as'),
              items: const [
                DropdownMenuItem(
                  value: 'Poster only',
                  child: Text('Poster only'),
                ),
                DropdownMenuItem(
                  value: 'Poster + backdrop',
                  child: Text('Poster + backdrop'),
                ),
                DropdownMenuItem(
                  value: 'Poster + backdrop or previews',
                  child: Text('Poster + backdrop or previews'),
                ),
              ],
              onChanged: (next) {
                if (next != null) onChanged(next);
              },
            ),
          ],
        ),
      ),
    );
  }
}

String _normalizeSocialTheme(Object? value, {String fallback = 'Casual'}) {
  final candidate = value?.toString() ?? '';
  return socialThemeStyles.contains(candidate) ? candidate : fallback;
}

class AppSectionCustomization {
  String shopCardStyle;
  int shopColumns;
  bool showShopPrices;
  bool showShopInventory;
  String libraryCardStyle;
  String artworkDisplayMode;
  String libraryViewMode;
  int libraryColumns;
  Map<String, String> libraryWidgetSizes;
  String feedStyle;
  String profilePageStyle;
  String communitiesStyle;
  String friendsStyle;
  String messagesStyle;
  String reelsStyle;
  String socialNavPosition;
  List<String> socialNavOrder;
  String profilePageViewMode;
  String profilePostsSortOrder;
  String friendsViewMode;
  String friendsSortOrder;
  String communitiesViewMode;
  String communitiesMembershipFilter;
  String communitiesSortOrder;
  // Legacy property retained so existing call sites and stored preferences migrate safely.
  String friendsDisplayStyle;

  AppSectionCustomization({
    this.shopCardStyle = 'Comfortable',
    this.shopColumns = 2,
    this.showShopPrices = true,
    this.showShopInventory = false,
    this.libraryCardStyle = 'Poster',
    this.artworkDisplayMode = 'Poster only',
    this.libraryViewMode = 'Grid',
    this.libraryColumns = 2,
    Map<String, String>? libraryWidgetSizes,
    this.feedStyle = 'Casual',
    this.profilePageStyle = 'Casual',
    this.communitiesStyle = 'Material',
    this.friendsStyle = 'Compact',
    this.messagesStyle = 'Compact',
    this.reelsStyle = 'Minimalist',
    this.socialNavPosition = 'Top',
    List<String>? socialNavOrder,
    this.profilePageViewMode = 'Timeline',
    this.profilePostsSortOrder = 'Newest to Oldest',
    this.friendsViewMode = 'List',
    this.friendsSortOrder = 'A-Z',
    this.communitiesViewMode = 'Cards',
    this.communitiesMembershipFilter = 'All',
    this.communitiesSortOrder = 'Newest to Oldest',
    this.friendsDisplayStyle = 'Casual',
  }) : libraryWidgetSizes = libraryWidgetSizes ?? <String, String>{},
       socialNavOrder = List<String>.from(socialNavOrder ?? socialSectionOrderDefaults);

  Map<String, dynamic> toJson() => {
    'shopCardStyle': shopCardStyle,
    'shopColumns': shopColumns,
    'showShopPrices': showShopPrices,
    'showShopInventory': showShopInventory,
    'libraryCardStyle': libraryCardStyle,
    'artworkDisplayMode': artworkDisplayMode,
    'libraryViewMode': libraryViewMode,
    'libraryColumns': libraryColumns,
    'libraryWidgetSizes': libraryWidgetSizes,
    'feedStyle': feedStyle,
    'profilePageStyle': profilePageStyle,
    'communitiesStyle': communitiesStyle,
    'friendsStyle': friendsStyle,
    'messagesStyle': messagesStyle,
    'reelsStyle': reelsStyle,
    'socialNavPosition': socialNavPosition,
    'socialNavOrder': socialNavOrder,
    'profilePageViewMode': profilePageViewMode,
    'profilePostsSortOrder': profilePostsSortOrder,
    'friendsViewMode': friendsViewMode,
    'friendsSortOrder': friendsSortOrder,
    'communitiesViewMode': communitiesViewMode,
    'communitiesMembershipFilter': communitiesMembershipFilter,
    'communitiesSortOrder': communitiesSortOrder,
    'friendsDisplayStyle': friendsStyle,
  };

  factory AppSectionCustomization.fromJson(Map<String, dynamic> json) {
    final legacyTheme = _normalizeSocialTheme(json['friendsDisplayStyle']);
    final rawOrder = (json['socialNavOrder'] as List? ?? const <dynamic>[])
        .map((item) => item.toString())
        .where(socialSectionOrderDefaults.contains).toSet();
    final normalizedOrder = <String>[
      ...rawOrder,
      ...socialSectionOrderDefaults.where((item) => !rawOrder.contains(item)),
    ];
    final rawPosition = json['socialNavPosition']?.toString() ?? 'Top';
    final rawArtworkDisplayMode =
        json['artworkDisplayMode']?.toString() ?? 'Poster only';
    final rawFriendsSort = json['friendsSortOrder']?.toString() ?? 'A-Z';
    final rawCommunityFilter = json['communitiesMembershipFilter']?.toString() ?? 'All';
    final rawCommunitySort = json['communitiesSortOrder']?.toString() ?? 'Newest to Oldest';
    return AppSectionCustomization(
      shopCardStyle: json['shopCardStyle']?.toString() ?? 'Comfortable',
      shopColumns: ((json['shopColumns'] as num?)?.toInt() ?? 2).clamp(1, 4).toInt(),
      showShopPrices: json['showShopPrices'] != false,
      showShopInventory: json['showShopInventory'] == true,
      libraryCardStyle: json['libraryCardStyle']?.toString() ?? 'Poster',
      artworkDisplayMode: mediaArtworkDisplayModes.contains(rawArtworkDisplayMode)
          ? rawArtworkDisplayMode
          : 'Poster only',
      libraryViewMode: json['libraryViewMode']?.toString() == 'List' ? 'List' : 'Grid',
      libraryColumns: ((json['libraryColumns'] as num?)?.toInt() ?? 2).clamp(1, 6).toInt(),
      libraryWidgetSizes: json['libraryWidgetSizes'] is Map
          ? (json['libraryWidgetSizes'] as Map).map((key, value) => MapEntry(key.toString(), value.toString()))
          : <String, String>{},
      feedStyle: _normalizeSocialTheme(json['feedStyle'], fallback: legacyTheme),
      profilePageStyle: _normalizeSocialTheme(json['profilePageStyle'], fallback: legacyTheme),
      communitiesStyle: _normalizeSocialTheme(json['communitiesStyle'], fallback: 'Material'),
      friendsStyle: _normalizeSocialTheme(json['friendsStyle'], fallback: legacyTheme),
      messagesStyle: _normalizeSocialTheme(json['messagesStyle'], fallback: 'Compact'),
      reelsStyle: _normalizeSocialTheme(json['reelsStyle'], fallback: 'Minimalist'),
      socialNavPosition: const ['Top', 'Left', 'Right'].contains(rawPosition) ? rawPosition : 'Top',
      socialNavOrder: normalizedOrder,
      profilePageViewMode: json['profilePageViewMode']?.toString() == 'Post cards' ? 'Post cards' : 'Timeline',
      profilePostsSortOrder: json['profilePostsSortOrder']?.toString() == 'Oldest to Newest' ? 'Oldest to Newest' : 'Newest to Oldest',
      friendsViewMode: json['friendsViewMode']?.toString() == 'Cards' ? 'Cards' : 'List',
      friendsSortOrder: const ['Newest to Oldest', 'Oldest to Newest', 'A-Z', 'Z-A'].contains(rawFriendsSort) ? rawFriendsSort : 'A-Z',
      communitiesViewMode: json['communitiesViewMode']?.toString() == 'List' ? 'List' : 'Cards',
      communitiesMembershipFilter: const ['All', 'Joined', 'Created'].contains(rawCommunityFilter) ? rawCommunityFilter : 'All',
      communitiesSortOrder: const ['Newest to Oldest', 'Oldest to Newest', 'Movies', 'Shows', 'Music', 'Joined', 'Created'].contains(rawCommunitySort) ? rawCommunitySort : 'Newest to Oldest',
      friendsDisplayStyle: legacyTheme,
    );
  }
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
