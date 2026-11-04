import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_core.dart';
import 'backend_api.dart';

/// The independently selectable presentation experiences supported by the app.
enum InterfaceExperienceMode { classic, blockbuster, redbox, theater }

extension InterfaceExperienceModeLabel on InterfaceExperienceMode {
  String get label {
    switch (this) {
      case InterfaceExperienceMode.classic:
        return 'Classic Streaming';
      case InterfaceExperienceMode.blockbuster:
        return 'Virtual Video Store';
      case InterfaceExperienceMode.redbox:
        return 'Redbox Kiosk';
      case InterfaceExperienceMode.theater:
        return 'Movie Theater';
    }
  }

  String get description {
    switch (this) {
      case InterfaceExperienceMode.classic:
        return 'Your familiar, fully customizable streaming interface.';
      case InterfaceExperienceMode.blockbuster:
        return 'A browsable rental store with aisles, shelves and custom cases.';
      case InterfaceExperienceMode.redbox:
        return 'A streamlined kiosk designed for television remotes.';
      case InterfaceExperienceMode.theater:
        return 'A cinematic lobby for choosing a feature and starting a movie night.';
    }
  }

}

InterfaceExperienceMode parseInterfaceExperienceMode(Object? value) {
  return InterfaceExperienceMode.values.firstWhere(
    (mode) => mode.name == value?.toString(),
    orElse: () => InterfaceExperienceMode.classic,
  );
}

String _experienceId(String prefix) =>
    '${prefix}_${DateTime.now().microsecondsSinceEpoch}';

String _stringValue(Object? value, String fallback) {
  final result = value?.toString().trim() ?? '';
  return result.isEmpty ? fallback : result;
}

int _intValue(Object? value, int fallback) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? fallback;

List<Map<String, dynamic>> _mapList(Object? value) => value is List
    ? value.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList()
    : <Map<String, dynamic>>[];

List<String> _stringList(Object? value) => value is List
    ? value.map((entry) => entry.toString()).where((entry) => entry.isNotEmpty).toList()
    : <String>[];

/// A shelf rule can be manually curated or dynamically populated from metadata.
class ExperienceContentRule {
  ExperienceContentRule({
    String? id,
    this.title = 'New shelf',
    this.filterType = 'manual',
    this.filterValue = '',
    List<String>? mediaIds,
  })  : id = id ?? _experienceId('shelf'),
        mediaIds = mediaIds ?? <String>[];

  final String id;
  String title;
  String filterType;
  String filterValue;
  List<String> mediaIds;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'filterType': filterType,
        'filterValue': filterValue,
        'mediaIds': mediaIds,
      };

  factory ExperienceContentRule.fromJson(Map<String, dynamic> json) =>
      ExperienceContentRule(
        id: _stringValue(json['id'], _experienceId('shelf')),
        title: _stringValue(json['title'], 'New shelf'),
        filterType: _stringValue(json['filterType'], 'manual'),
        filterValue: json['filterValue']?.toString() ?? '',
        mediaIds: _stringList(json['mediaIds']),
      );
}

class StoreAisle {
  StoreAisle({
    String? id,
    this.name = 'New aisle',
    this.description = '',
    this.filterType = 'manual',
    this.filterValue = '',
    this.color = 0xFF1565C0,
    List<String>? mediaIds,
    List<String>? subSections,
    List<ExperienceContentRule>? shelves,
  })  : id = id ?? _experienceId('aisle'),
        mediaIds = mediaIds ?? <String>[],
        subSections = subSections ?? <String>[],
        shelves = shelves ?? <ExperienceContentRule>[];

  final String id;
  String name;
  String description;
  String filterType;
  String filterValue;
  int color;
  List<String> mediaIds;
  List<String> subSections;
  List<ExperienceContentRule> shelves;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'filterType': filterType,
        'filterValue': filterValue,
        'color': color,
        'mediaIds': mediaIds,
        'subSections': subSections,
        'shelves': shelves.map((shelf) => shelf.toJson()).toList(),
      };

  factory StoreAisle.fromJson(Map<String, dynamic> json) => StoreAisle(
        id: _stringValue(json['id'], _experienceId('aisle')),
        name: _stringValue(json['name'], 'New aisle'),
        description: json['description']?.toString() ?? '',
        filterType: _stringValue(json['filterType'], 'manual'),
        filterValue: json['filterValue']?.toString() ?? '',
        color: _intValue(json['color'], 0xFF1565C0),
        mediaIds: _stringList(json['mediaIds']),
        subSections: _stringList(json['subSections']),
        shelves: _mapList(json['shelves'])
            .map(ExperienceContentRule.fromJson)
            .toList(),
      );
}

class VirtualStoreDesign {
  VirtualStoreDesign({
    String? id,
    this.name = "Cesar's Video World",
    this.logoUrl = '',
    this.greeting = 'Welcome. Your next movie night starts here.',
    this.wallColor = 0xFF1B1B1B,
    this.floorColor = 0xFF292522,
    this.shelfColor = 0xFF4E342E,
    this.accentColor = 0xFFFFC107,
    this.floorPlan = 'Classic wide aisles',
    List<StoreAisle>? aisles,
    List<Map<String, dynamic>>? layoutElements,
    List<Map<String, dynamic>>? seasonalRules,
    List<Map<String, dynamic>>? revisions,
  })  : id = id ?? _experienceId('store'),
        aisles = aisles ?? <StoreAisle>[],
        layoutElements = layoutElements ?? <Map<String, dynamic>>[],
        seasonalRules = seasonalRules ?? <Map<String, dynamic>>[],
        revisions = revisions ?? <Map<String, dynamic>>[];

  final String id;
  String name;
  String logoUrl;
  String greeting;
  int wallColor;
  int floorColor;
  int shelfColor;
  int accentColor;
  String floorPlan;
  List<StoreAisle> aisles;
  List<Map<String, dynamic>> layoutElements;
  List<Map<String, dynamic>> seasonalRules;
  List<Map<String, dynamic>> revisions;

  Map<String, dynamic> toJson({bool includeRevisions = true}) => {
        'id': id,
        'name': name,
        'logoUrl': logoUrl,
        'greeting': greeting,
        'wallColor': wallColor,
        'floorColor': floorColor,
        'shelfColor': shelfColor,
        'accentColor': accentColor,
        'floorPlan': floorPlan,
        'aisles': aisles.map((aisle) => aisle.toJson()).toList(),
        'layoutElements': layoutElements,
        'seasonalRules': seasonalRules,
        if (includeRevisions) 'revisions': revisions,
      };

  void checkpoint(String label) {
    revisions.add({
      'id': _experienceId('revision'),
      'label': label,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'snapshot': toJson(includeRevisions: false),
    });
    if (revisions.length > 20) {
      revisions.removeAt(0);
    }
  }

  factory VirtualStoreDesign.fromJson(Map<String, dynamic> json) =>
      VirtualStoreDesign(
        id: _stringValue(json['id'], _experienceId('store')),
        name: _stringValue(json['name'], 'My Video Store'),
        logoUrl: json['logoUrl']?.toString() ?? '',
        greeting: json['greeting']?.toString() ?? '',
        wallColor: _intValue(json['wallColor'], 0xFF1B1B1B),
        floorColor: _intValue(json['floorColor'], 0xFF292522),
        shelfColor: _intValue(json['shelfColor'], 0xFF4E342E),
        accentColor: _intValue(json['accentColor'], 0xFFFFC107),
        floorPlan: _stringValue(json['floorPlan'], 'Classic wide aisles'),
        aisles: _mapList(json['aisles']).map(StoreAisle.fromJson).toList(),
        layoutElements: _mapList(json['layoutElements']),
        seasonalRules: _mapList(json['seasonalRules']),
        revisions: _mapList(json['revisions']),
      );
}

class KioskCategoryDesign {
  KioskCategoryDesign({
    String? id,
    this.title = 'New category',
    this.description = '',
    this.filterType = 'manual',
    this.filterValue = '',
    List<String>? mediaIds,
    this.visible = true,
    this.featured = false,
  })  : id = id ?? _experienceId('category'),
        mediaIds = mediaIds ?? <String>[];

  final String id;
  String title;
  String description;
  String filterType;
  String filterValue;
  List<String> mediaIds;
  bool visible;
  bool featured;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'filterType': filterType,
        'filterValue': filterValue,
        'mediaIds': mediaIds,
        'visible': visible,
        'featured': featured,
      };

  factory KioskCategoryDesign.fromJson(Map<String, dynamic> json) =>
      KioskCategoryDesign(
        id: _stringValue(json['id'], _experienceId('category')),
        title: _stringValue(json['title'], 'New category'),
        description: json['description']?.toString() ?? '',
        filterType: _stringValue(json['filterType'], 'manual'),
        filterValue: json['filterValue']?.toString() ?? '',
        mediaIds: _stringList(json['mediaIds']),
        visible: json['visible'] != false,
        featured: json['featured'] == true,
      );
}

class KioskDesign {
  KioskDesign({
    String? id,
    this.name = 'My Movie Kiosk',
    this.logoUrl = '',
    this.greeting = 'Choose something great to watch.',
    this.backgroundColor = 0xFF101820,
    this.accentColor = 0xFFE53935,
    this.layoutStyle = 'Featured banner + grid',
    this.screensaver = 'Rotating posters',
    this.fullScreen = true,
    this.autoplayPreviews = false,
    List<KioskCategoryDesign>? categories,
    List<Map<String, dynamic>>? decorations,
    List<Map<String, dynamic>>? seasonalRules,
    List<Map<String, dynamic>>? revisions,
  })  : id = id ?? _experienceId('kiosk'),
        categories = categories ?? <KioskCategoryDesign>[],
        decorations = decorations ?? <Map<String, dynamic>>[],
        seasonalRules = seasonalRules ?? <Map<String, dynamic>>[],
        revisions = revisions ?? <Map<String, dynamic>>[];

  final String id;
  String name;
  String logoUrl;
  String greeting;
  int backgroundColor;
  int accentColor;
  String layoutStyle;
  String screensaver;
  bool fullScreen;
  bool autoplayPreviews;
  List<KioskCategoryDesign> categories;
  List<Map<String, dynamic>> decorations;
  List<Map<String, dynamic>> seasonalRules;
  List<Map<String, dynamic>> revisions;

  Map<String, dynamic> toJson({bool includeRevisions = true}) => {
        'id': id,
        'name': name,
        'logoUrl': logoUrl,
        'greeting': greeting,
        'backgroundColor': backgroundColor,
        'accentColor': accentColor,
        'layoutStyle': layoutStyle,
        'screensaver': screensaver,
        'fullScreen': fullScreen,
        'autoplayPreviews': autoplayPreviews,
        'categories': categories.map((category) => category.toJson()).toList(),
        'decorations': decorations,
        'seasonalRules': seasonalRules,
        if (includeRevisions) 'revisions': revisions,
      };

  void checkpoint(String label) {
    revisions.add({
      'id': _experienceId('revision'),
      'label': label,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'snapshot': toJson(includeRevisions: false),
    });
    if (revisions.length > 20) {
      revisions.removeAt(0);
    }
  }

  factory KioskDesign.fromJson(Map<String, dynamic> json) => KioskDesign(
        id: _stringValue(json['id'], _experienceId('kiosk')),
        name: _stringValue(json['name'], 'My Movie Kiosk'),
        logoUrl: json['logoUrl']?.toString() ?? '',
        greeting: json['greeting']?.toString() ?? '',
        backgroundColor: _intValue(json['backgroundColor'], 0xFF101820),
        accentColor: _intValue(json['accentColor'], 0xFFE53935),
        layoutStyle: _stringValue(json['layoutStyle'], 'Featured banner + grid'),
        screensaver: _stringValue(json['screensaver'], 'Rotating posters'),
        fullScreen: json['fullScreen'] != false,
        autoplayPreviews: json['autoplayPreviews'] == true,
        categories: _mapList(json['categories'])
            .map(KioskCategoryDesign.fromJson)
            .toList(),
        decorations: _mapList(json['decorations']),
        seasonalRules: _mapList(json['seasonalRules']),
        revisions: _mapList(json['revisions']),
      );
}

class InterfaceExperienceConfig {
  InterfaceExperienceConfig({
    this.activeExperience = 'classic',
    List<VirtualStoreDesign>? stores,
    String? activeStoreId,
    String? baseStoreId,
    List<KioskDesign>? kiosks,
    String? activeKioskId,
    String? baseKioskId,
    List<Map<String, dynamic>>? caseDesigns,
    this.activeCaseDesignId,
    List<String>? rentalBasket,
    List<String>? currentRentals,
    List<Map<String, dynamic>>? rentalHistory,
    this.membershipName = 'My Video Club',
    this.membershipNumber = 'MV-0001',
    this.autoOrganizationMode = 'suggest',
    this.autoSuggestArtwork = true,
    this.autoSuggestAislePlacement = true,
    this.requireApproval = true,
    this.remoteNavigationEnabled = true,
    this.theaterCountdown = true,
    this.theaterTrailers = false,
    this.theaterAmbience = false,
    this.seasonalAutomationEnabled = false,
    List<Map<String, dynamic>>? seasonalSchedules,
    List<Map<String, dynamic>>? savedTemplates,
  })  : stores = stores ?? <VirtualStoreDesign>[],
        activeStoreId = activeStoreId,
        baseStoreId = baseStoreId ?? activeStoreId,
        kiosks = kiosks ?? <KioskDesign>[],
        activeKioskId = activeKioskId,
        baseKioskId = baseKioskId ?? activeKioskId,
        caseDesigns = caseDesigns ?? <Map<String, dynamic>>[],
        rentalBasket = rentalBasket ?? <String>[],
        currentRentals = currentRentals ?? <String>[],
        rentalHistory = rentalHistory ?? <Map<String, dynamic>>[],
        seasonalSchedules = seasonalSchedules ?? <Map<String, dynamic>>[],
        savedTemplates = savedTemplates ?? <Map<String, dynamic>>[];

  String activeExperience;
  List<VirtualStoreDesign> stores;
  String? activeStoreId;
  String? baseStoreId;
  List<KioskDesign> kiosks;
  String? activeKioskId;
  String? baseKioskId;
  List<Map<String, dynamic>> caseDesigns;
  String? activeCaseDesignId;
  List<String> rentalBasket;
  List<String> currentRentals;
  List<Map<String, dynamic>> rentalHistory;
  String membershipName;
  String membershipNumber;
  String autoOrganizationMode;
  bool autoSuggestArtwork;
  bool autoSuggestAislePlacement;
  bool requireApproval;
  bool remoteNavigationEnabled;
  bool theaterCountdown;
  bool theaterTrailers;
  bool theaterAmbience;
  bool seasonalAutomationEnabled;
  List<Map<String, dynamic>> seasonalSchedules;
  List<Map<String, dynamic>> savedTemplates;

  VirtualStoreDesign? get activeStore {
    for (final store in stores) {
      if (store.id == activeStoreId) {
        return store;
      }
    }
    return stores.isEmpty ? null : stores.first;
  }

  KioskDesign? get activeKiosk {
    for (final kiosk in kiosks) {
      if (kiosk.id == activeKioskId) {
        return kiosk;
      }
    }
    return kiosks.isEmpty ? null : kiosks.first;
  }

  Map<String, dynamic>? get activeCaseDesign {
    for (final design in caseDesigns) {
      if (design['id']?.toString() == activeCaseDesignId) {
        return design;
      }
    }
    return caseDesigns.isEmpty ? null : caseDesigns.first;
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': 1,
        'activeExperience': activeExperience,
        'stores': stores.map((store) => store.toJson()).toList(),
        'activeStoreId': activeStoreId,
        'baseStoreId': baseStoreId,
        'kiosks': kiosks.map((kiosk) => kiosk.toJson()).toList(),
        'activeKioskId': activeKioskId,
        'baseKioskId': baseKioskId,
        'caseDesigns': caseDesigns,
        'activeCaseDesignId': activeCaseDesignId,
        'rentalBasket': rentalBasket,
        'currentRentals': currentRentals,
        'rentalHistory': rentalHistory,
        'membershipName': membershipName,
        'membershipNumber': membershipNumber,
        'autoOrganizationMode': autoOrganizationMode,
        'autoSuggestArtwork': autoSuggestArtwork,
        'autoSuggestAislePlacement': autoSuggestAislePlacement,
        'requireApproval': requireApproval,
        'remoteNavigationEnabled': remoteNavigationEnabled,
        'theaterCountdown': theaterCountdown,
        'theaterTrailers': theaterTrailers,
        'theaterAmbience': theaterAmbience,
        'seasonalAutomationEnabled': seasonalAutomationEnabled,
        'seasonalSchedules': seasonalSchedules,
        'savedTemplates': savedTemplates,
      };

  factory InterfaceExperienceConfig.fromJson(Map<String, dynamic> json) {
    final stores = _mapList(json['stores'])
        .map(VirtualStoreDesign.fromJson)
        .toList();
    final kiosks = _mapList(json['kiosks'])
        .map(KioskDesign.fromJson)
        .toList();
    return InterfaceExperienceConfig(
      activeExperience: parseInterfaceExperienceMode(json['activeExperience']).name,
      stores: stores,
      activeStoreId: json['activeStoreId']?.toString(),
      baseStoreId: json['baseStoreId']?.toString(),
      kiosks: kiosks,
      activeKioskId: json['activeKioskId']?.toString(),
      baseKioskId: json['baseKioskId']?.toString(),
      caseDesigns: _mapList(json['caseDesigns']),
      activeCaseDesignId: json['activeCaseDesignId']?.toString(),
      rentalBasket: _stringList(json['rentalBasket']),
      currentRentals: _stringList(json['currentRentals']),
      rentalHistory: _mapList(json['rentalHistory']),
      membershipName: _stringValue(json['membershipName'], 'My Video Club'),
      membershipNumber: _stringValue(json['membershipNumber'], 'MV-0001'),
      autoOrganizationMode: _stringValue(json['autoOrganizationMode'], 'suggest'),
      autoSuggestArtwork: json['autoSuggestArtwork'] != false,
      autoSuggestAislePlacement: json['autoSuggestAislePlacement'] != false,
      requireApproval: json['requireApproval'] != false,
      remoteNavigationEnabled: json['remoteNavigationEnabled'] != false,
      theaterCountdown: json['theaterCountdown'] != false,
      theaterTrailers: json['theaterTrailers'] == true,
      theaterAmbience: json['theaterAmbience'] == true,
      seasonalAutomationEnabled: json['seasonalAutomationEnabled'] == true,
      seasonalSchedules: _mapList(json['seasonalSchedules']),
      savedTemplates: _mapList(json['savedTemplates']),
    );
  }

  factory InterfaceExperienceConfig.starter() {
    final store = VirtualStoreDesign(
      aisles: [
        StoreAisle(
          name: 'Marvel Universe',
          description: 'MCU, animated Marvel, X-Men and Spider-Man',
          filterType: 'franchise',
          filterValue: 'Marvel',
          color: 0xFFB71C1C,
          shelves: [
            ExperienceContentRule(title: 'Marvel Cinematic Universe', filterType: 'franchise', filterValue: 'Marvel Cinematic Universe'),
          ],
        ),
        StoreAisle(
          name: 'Mexican Cinema',
          description: 'Movies and series from Mexico',
          filterType: 'country',
          filterValue: 'Mexico',
          color: 0xFF2E7D32,
        ),
        StoreAisle(
          name: 'Horror',
          description: 'Your frightening favorites',
          filterType: 'genre',
          filterValue: 'Horror',
          color: 0xFF512DA8,
        ),
      ],
      layoutElements: [
        {'id': 'entrance', 'type': 'entrance', 'label': 'Welcome entrance'},
        {'id': 'feature', 'type': 'featured', 'label': 'Featured wall'},
        {'id': 'shelves', 'type': 'shelves', 'label': 'Main shelves'},
        {'id': 'decor', 'type': 'decoration', 'label': 'Decorations'},
      ],
    );
    final kiosk = KioskDesign(
      categories: [
        KioskCategoryDesign(title: 'Marvel Universe', description: 'Superhero adventures', filterType: 'franchise', filterValue: 'Marvel', featured: true),
        KioskCategoryDesign(title: 'Mexican Cinema', description: 'Stories from Mexico', filterType: 'country', filterValue: 'Mexico'),
        KioskCategoryDesign(title: 'Recently Added', description: 'Your newest additions', filterType: 'recent'),
        KioskCategoryDesign(title: 'Horror', description: 'Thrillers and horror', filterType: 'genre', filterValue: 'Horror'),
      ],
    );
    return InterfaceExperienceConfig(
      stores: [store],
      activeStoreId: store.id,
      baseStoreId: store.id,
      kiosks: [kiosk],
      activeKioskId: kiosk.id,
      baseKioskId: kiosk.id,
      activeCaseDesignId: 'default-case',
      caseDesigns: [
        {
          'id': 'default-case',
          'name': 'Classic Blu-ray',
          'format': 'Blu-ray',
          'frontTitle': 'Movie Title',
          'spineText': 'Movie Title',
          'backText': 'Synopsis and credits',
          'discLabel': 'Disc 1',
          'frontArtUrl': '',
          'spineArtUrl': '',
          'backArtUrl': '',
          'discArtUrl': '',
          'primaryColor': 0xFF123D74,
          'secondaryColor': 0xFF101820,
        },
      ],
    );
  }
}

/// Profile-scoped local cache with best-effort authenticated backend sync.
/// The UI remains usable offline; the server is the durable cross-device copy.
class InterfaceExperienceRepository {
  InterfaceExperienceRepository._();
  static final InterfaceExperienceRepository instance =
      InterfaceExperienceRepository._();

  final ValueNotifier<InterfaceExperienceConfig?> notifier =
      ValueNotifier<InterfaceExperienceConfig?>(null);

  String get _profileId =>
      AppController.instance.currentProfile?.id.trim().isNotEmpty == true
          ? AppController.instance.currentProfile!.id
          : 'default';

  String get _key => 'interface_experience_$_profileId';

  Future<InterfaceExperienceConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    InterfaceExperienceConfig config;
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      config = InterfaceExperienceConfig.starter();
    } else {
      try {
        config = InterfaceExperienceConfig.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
      } catch (_) {
        config = InterfaceExperienceConfig.starter();
      }
    }
    try {
      final response = await AppController.instance.backendApi
          .getInterfaceExperienceConfig(profileId: _profileId);
      final remote = response['config'];
      if (remote is Map && remote.isNotEmpty) {
        config = InterfaceExperienceConfig.fromJson(
          Map<String, dynamic>.from(remote),
        );
      }
    } catch (_) {
      // Offline or older servers fall back to the profile-scoped local cache.
    }
    _applySeasonalDesign(config, DateTime.now());
    await prefs.setString(_key, jsonEncode(config.toJson()));
    notifier.value = config;
    return config;
  }

  void _applySeasonalDesign(InterfaceExperienceConfig config, DateTime now) {
    config.activeStoreId = config.baseStoreId ?? config.activeStoreId;
    config.activeKioskId = config.baseKioskId ?? config.activeKioskId;
    if (!config.seasonalAutomationEnabled) {
      return;
    }
    bool matches(String rawStart, String rawEnd) {
      DateTime? parse(String raw) {
        final parts = raw.split('-');
        if (parts.length != 2) {
          return null;
        }
        final month = int.tryParse(parts[0]);
        final day = int.tryParse(parts[1]);
        if (month == null || day == null) {
          return null;
        }
        try {
        return DateTime(2000, month, day);
      } catch (_) {
        return null;
      }
      }
      final start = parse(rawStart);
      final end = parse(rawEnd);
      if (start == null || end == null) {
        return false;
      }
      final today = DateTime(2000, now.month, now.day);
      if (start.isAfter(end)) {
        return !today.isBefore(start) || !today.isAfter(end);
      }
      return !today.isBefore(start) && !today.isAfter(end);
    }

    for (final schedule in config.seasonalSchedules) {
      if (!matches(schedule['start']?.toString() ?? '', schedule['end']?.toString() ?? '')) {
        continue;
      }
      final id = schedule['designId']?.toString();
      if (schedule['kind'] == 'store' && config.stores.any((store) => store.id == id)) {
        config.activeStoreId = id;
      } else if (schedule['kind'] == 'kiosk' && config.kiosks.any((kiosk) => kiosk.id == id)) {
        config.activeKioskId = id;
      }
    }
  }

  Future<void> save(InterfaceExperienceConfig config) async {
    final payload = jsonEncode(config.toJson());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, payload);
    notifier.value = config;
    try {
      await AppController.instance.backendApi.saveInterfaceExperienceConfig(
        profileId: _profileId,
        config: config.toJson(),
      );
    } catch (_) {
      // Local persistence remains valid while backend sync is unavailable.
    }
  }
}
