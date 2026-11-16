import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_core.dart';

const Map<String, List<String>> interfaceFontCatalog = <String, List<String>>{
  'Serif': <String>[
    'Times New Roman',
    'Garamond',
    'Baskerville',
    'Georgia',
    'Albertus',
    'Corporate A URW Font',
    'Caslon',
    'Clarendon',
    'Clarendon Text',
    'Didot',
    'Didot LT',
    'Ferro Rosso',
    'Friz Quadrata',
    'Granjon',
    'ITC Novarese',
    'ITC Serif Gothic',
    'Le Monde Courrier',
    'Minion',
    'Mrs Eaves',
    'Radiant',
    'St Marie',
    'Walbaum Monotype',
    'Trajan',
    'Playfair Display',
  ],
  'Sans Serif': <String>[
    'Adobe Clean',
    'Aktifo',
    'Aller',
    'Alright Sans',
    'Amsi Pro',
    'Audi Type',
    'Frankfurter',
    'Avenir',
    'Avenir Next',
    'Avenir Next®',
    'Baloo 2',
    'Campton',
    'Centra no.2',
    'Cereal',
    'Circular Std Font',
    'Clearface Gothic',
    'Collegiate',
    'Couture',
    'DDT Condensed',
    'DFL Sans',
    'DIN Next',
    'DIN® Next',
    'Eagle',
    'Eina',
    'Eurostile',
    'FF Dax Compact',
    'FF Fago',
    'FF Mark',
    'FF Real Head',
    'Feather',
    'Freight Sans',
    'Frutiger',
    'Futura',
    'Futura-Maxi',
    'Futura-Maxi',
    'GT America',
    'Gill Sans',
    'Gilroy',
    'Gilroy™',
    'Gotham',
    'Handel Gothic',
    'Harry Pro™',
    'Harry Pro',
    'Hellix',
    'Helvetica®',
    'Helvetica',
    'ITC American Typewriter',
    'ITC Avant Garde',
    'ITC Officina® Sans',
    'ITC Officina Sans',
    'ITC Stone Sans II',
    'Ikea Sans',
    'Insaniburger',
    'Kaleko 205',
    'Klavika',
    'Kometa',
    'Lato',
    'Morandi',
    'Motiva Sans',
    'Myriad',
    'Neo® Sans',
    'Neo Sans',
    'Nimbus Sans Novus',
    'Optima',
    'Peignot',
    'Pluto Sans™',
    'Product Sans',
    'Proxima Nova',
    'Radikal',
    'Ricardo',
    'Segoe UI',
    'Segoe Ui',
    'Sharp Grotesk',
    'Sharp Sans',
    'Tepeno Sans',
    'Trade Gothic',
    'Trade Gothic LT Std',
    'UPS Sans',
    'URW Linear',
    'Uber Move',
    'Uni Sans',
    'Univers®',
    'Univers ®',
    'Univers',
    'VAG Rounded',
    'VW Head',
    'Visby CF',
    'Arial',
    'Roboto',
    'Open Sans',
    'Futura',
    'Anton',
    'Titan One',
  ],
  'Script': <String>[
    'Comic Sans',
    'Pacifico',
    'Lobster',
    'Billabong',
    'Coca Cola II',
    'Coca Cola Ii',
    "Engravers' Old English BT",
    'Ford Script',
    'La Macchina',
    'Waltograph',
  ],
  'Monospaced': <String>[
    'Courier New',
    'Consolas',
    'Roboto Mono',
    'Le Monde Courrier',
  ],
  'Display / Decorative': <String>[
    'Bebas Neue',
    'Impact',
    'Playfair Display',
    'Boing',
    'Burbank',
    'Castle',
    'Billabong',
    'Wallpoet',
    'Industria',
    'EA Sans',
    'Lego Thick',
    'Mclawsuit',
    'Noe Display',
    'SF Automaton',
    'Tesla',
    'Yagi Double',
    'Wallpoet',
    'Industria',
    'Bangers',
  ],
  'Movie-inspired (fan-made approximations)': <String>[
    'Star Jedi',
    'Star Wars Aurebesh',
    'Harry P',
    'Lumos',
    'Harry Pro',
    'SF Fedora',
    'Adventure',
    'Avengeance',
    'Homoarakhn',
    'Bangers',
    'Titan One',
    'Mario Pixel',
    'Super Mario Pixel',
    'Trajan',
    'Industria',
    'Wallpoet',
  ],
};

const List<String> interfaceFontRoles = <String>[
  'Application title',
  'Section headings',
  'Movie and show titles',
  'Descriptions',
  'Navigation',
  'Buttons',
  'Metadata and ratings',
];

const List<String> interfaceAppearanceModes = <String>[
  'classic',
  'blockbuster',
  'redbox',
  'theater',
];

String interfaceModeLabel(String mode) => switch (mode) {
      'blockbuster' => 'Virtual Store',
      'redbox' => 'Virtual Kiosk',
      'theater' => 'Virtual Theater',
      _ => 'Classic',
    };

int _appearanceInt(Object? value, int fallback) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? fallback;

double _appearanceDouble(Object? value, double fallback) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? fallback;

class InterfaceAppearancePreset {
  const InterfaceAppearancePreset({
    this.skinPreset = 'Matte Black',
    this.accentColor = 0xFFE50914,
    this.backgroundColor = 0xFF080B12,
    this.backdropPath = '',
    this.logoPath = '',
    this.iconPack = 'Material Rounded',
    this.customIcons = const <String, String>{},
    this.fontAssignments = const <String, String>{},
    this.importedFonts = const <String, String>{},
    this.favoriteFonts = const <String>[],
    this.customCss = '',
    this.glassIntensity = .72,
    this.blurSigma = 18,
    this.transparency = .18,
    this.cardOpacity = .84,
    this.cornerRadius = 18,
    this.reflection = true,
    this.borderHighlights = true,
  });

  final String skinPreset;
  final int accentColor;
  final int backgroundColor;
  final String backdropPath;
  final String logoPath;
  final String iconPack;
  final Map<String, String> customIcons;
  final Map<String, String> fontAssignments;
  final Map<String, String> importedFonts;
  final List<String> favoriteFonts;
  final String customCss;
  final double glassIntensity;
  final double blurSigma;
  final double transparency;
  final double cardOpacity;
  final double cornerRadius;
  final bool reflection;
  final bool borderHighlights;

  InterfaceAppearancePreset copyWith({
    String? skinPreset,
    int? accentColor,
    int? backgroundColor,
    String? backdropPath,
    String? logoPath,
    String? iconPack,
    Map<String, String>? customIcons,
    Map<String, String>? fontAssignments,
    Map<String, String>? importedFonts,
    List<String>? favoriteFonts,
    String? customCss,
    double? glassIntensity,
    double? blurSigma,
    double? transparency,
    double? cardOpacity,
    double? cornerRadius,
    bool? reflection,
    bool? borderHighlights,
  }) =>
      InterfaceAppearancePreset(
        skinPreset: skinPreset ?? this.skinPreset,
        accentColor: accentColor ?? this.accentColor,
        backgroundColor: backgroundColor ?? this.backgroundColor,
        backdropPath: backdropPath ?? this.backdropPath,
        logoPath: logoPath ?? this.logoPath,
        iconPack: iconPack ?? this.iconPack,
        customIcons: customIcons ?? this.customIcons,
        fontAssignments: fontAssignments ?? this.fontAssignments,
        importedFonts: importedFonts ?? this.importedFonts,
        favoriteFonts: favoriteFonts ?? this.favoriteFonts,
        customCss: customCss ?? this.customCss,
        glassIntensity: glassIntensity ?? this.glassIntensity,
        blurSigma: blurSigma ?? this.blurSigma,
        transparency: transparency ?? this.transparency,
        cardOpacity: cardOpacity ?? this.cardOpacity,
        cornerRadius: cornerRadius ?? this.cornerRadius,
        reflection: reflection ?? this.reflection,
        borderHighlights: borderHighlights ?? this.borderHighlights,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'skinPreset': skinPreset,
        'accentColor': accentColor,
        'backgroundColor': backgroundColor,
        'backdropPath': backdropPath,
        'logoPath': logoPath,
        'iconPack': iconPack,
        'customIcons': customIcons,
        'fontAssignments': fontAssignments,
        'importedFonts': importedFonts,
        'favoriteFonts': favoriteFonts,
        'customCss': customCss,
        'glassIntensity': glassIntensity,
        'blurSigma': blurSigma,
        'transparency': transparency,
        'cardOpacity': cardOpacity,
        'cornerRadius': cornerRadius,
        'reflection': reflection,
        'borderHighlights': borderHighlights,
      };

  factory InterfaceAppearancePreset.fromJson(Map<String, dynamic> json) {
    Map<String, String> readStringMap(Object? value) => value is Map
        ? value.map((key, value) => MapEntry(key.toString(), value.toString()))
        : <String, String>{};
    return InterfaceAppearancePreset(
      skinPreset: json['skinPreset']?.toString() ?? 'Matte Black',
      accentColor: _appearanceInt(json['accentColor'], 0xFFE50914),
      backgroundColor: _appearanceInt(json['backgroundColor'], 0xFF080B12),
      backdropPath: json['backdropPath']?.toString() ?? '',
      logoPath: json['logoPath']?.toString() ?? '',
      iconPack: json['iconPack']?.toString() ?? 'Material Rounded',
      customIcons: readStringMap(json['customIcons']),
      fontAssignments: readStringMap(json['fontAssignments']),
      importedFonts: readStringMap(json['importedFonts']),
      favoriteFonts: json['favoriteFonts'] is List
          ? (json['favoriteFonts'] as List)
              .map((value) => value.toString())
              .toList()
          : const <String>[],
      customCss: json['customCss']?.toString() ?? '',
      glassIntensity:
          _appearanceDouble(json['glassIntensity'], .72).clamp(0, 1).toDouble(),
      blurSigma:
          _appearanceDouble(json['blurSigma'], 18).clamp(0, 40).toDouble(),
      transparency:
          _appearanceDouble(json['transparency'], .18).clamp(0, .8).toDouble(),
      cardOpacity:
          _appearanceDouble(json['cardOpacity'], .84).clamp(.1, 1).toDouble(),
      cornerRadius:
          _appearanceDouble(json['cornerRadius'], 18).clamp(0, 40).toDouble(),
      reflection: json['reflection'] != false,
      borderHighlights: json['borderHighlights'] != false,
    );
  }
}

class InterfaceAppearanceStore {
  InterfaceAppearanceStore._();

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);
  static SharedPreferences? _prefs;
  static String _profileId = 'default';
  static InterfaceAppearancePreset _global = const InterfaceAppearancePreset();
  static final Map<String, Map<String, dynamic>> _modeOverrides =
      <String, Map<String, dynamic>>{};
  static final Set<String> _loadedFontFamilies = <String>{};

  static String get profileId => _profileId;
  static InterfaceAppearancePreset get globalPreset => _applySafeCss(_global);

  static Future<void> load({String? profileId}) async {
    _profileId =
        profileId?.trim().isNotEmpty == true ? profileId!.trim() : 'default';
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    final raw = prefs.getString('interface_appearance_$_profileId');
    _modeOverrides.clear();
    if (raw == null || raw.isEmpty) {
      _global = const InterfaceAppearancePreset();
    } else {
      try {
        final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        final global = data['global'];
        _global = global is Map
            ? InterfaceAppearancePreset.fromJson(
                Map<String, dynamic>.from(global))
            : const InterfaceAppearancePreset();
        final overrides = data['modeOverrides'];
        if (overrides is Map) {
          for (final entry in overrides.entries) {
            if (interfaceAppearanceModes.contains(entry.key.toString()) &&
                entry.value is Map) {
              _modeOverrides[entry.key.toString()] =
                  Map<String, dynamic>.from(entry.value as Map);
            }
          }
        }
      } catch (_) {
        _global = const InterfaceAppearancePreset();
        _modeOverrides.clear();
      }
    }
    await _loadFontsForPreset(_global);
    for (final override in _modeOverrides.values) {
      await _loadFontsForPreset(
          InterfaceAppearancePreset.fromJson(<String, dynamic>{
        ..._global.toJson(),
        ...override,
      }));
    }
    revision.value++;
  }

  static InterfaceAppearancePreset forMode(String mode) {
    final normalized =
        interfaceAppearanceModes.contains(mode) ? mode : 'classic';
    final merged = <String, dynamic>{
      ..._global.toJson(),
      ...?_modeOverrides[normalized],
    };
    return _applySafeCss(InterfaceAppearancePreset.fromJson(merged));
  }

  static Future<void> savePreset({
    required String target,
    required InterfaceAppearancePreset preset,
  }) async {
    if (target == 'global') {
      _global = preset;
    } else if (interfaceAppearanceModes.contains(target)) {
      final base = _global.toJson();
      final candidate = preset.toJson();
      final diff = <String, dynamic>{};
      for (final entry in candidate.entries) {
        if (jsonEncode(entry.value) != jsonEncode(base[entry.key])) {
          diff[entry.key] = entry.value;
        }
      }
      _modeOverrides[target] = diff;
    }
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setString(
        'interface_appearance_$_profileId',
        jsonEncode(<String, dynamic>{
          'global': _global.toJson(),
          'modeOverrides': _modeOverrides,
        }));
    await _loadFontsForPreset(preset);
    revision.value++;
  }

  static Future<void> resetMode(String mode) async {
    if (mode == 'global') {
      _global = const InterfaceAppearancePreset();
    } else {
      _modeOverrides.remove(mode);
    }
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setString(
        'interface_appearance_$_profileId',
        jsonEncode(<String, dynamic>{
          'global': _global.toJson(),
          'modeOverrides': _modeOverrides,
        }));
    revision.value++;
  }

  static String get _namedSkinsKey => 'interface_named_skins_$_profileId';

  static Future<Map<String, InterfaceAppearancePreset>> loadNamedSkins() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    final raw = prefs.getString(_namedSkinsKey);
    if (raw == null || raw.isEmpty) {
      return <String, InterfaceAppearancePreset>{};
    }
    try {
      final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return data.map((name, value) => MapEntry(
            name,
            InterfaceAppearancePreset.fromJson(
                Map<String, dynamic>.from(value as Map)),
          ));
    } catch (_) {
      return <String, InterfaceAppearancePreset>{};
    }
  }

  static Future<void> saveNamedSkin(
      String name, InterfaceAppearancePreset preset) async {
    final normalized = name.trim();
    if (normalized.isEmpty) throw ArgumentError('A skin name is required.');
    final profiles = await loadNamedSkins();
    profiles[normalized] = preset;
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setString(
      _namedSkinsKey,
      jsonEncode(profiles.map((key, value) => MapEntry(key, value.toJson()))),
    );
  }

  /// Persists an imported asset and returns the value stored in the appearance
  /// preset. Browsers cannot use dart:io files, so web imports are kept as data
  /// URIs; desktop and mobile continue to use app-local files.
  static Future<String> persistPickedFile(
      PlatformFile picked, String folder) async {
    final bytes = await picked.readAsBytes();
    if (bytes.isEmpty) {
      throw StateError('The selected file could not be read.');
    }

    if (kIsWeb) {
      final extension = picked.name.split('.').last.toLowerCase();
      final mimeType = switch (extension) {
        'svg' => 'image/svg+xml',
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        'webp' => 'image/webp',
        'ttf' => 'font/ttf',
        'otf' => 'font/otf',
        _ => 'application/octet-stream',
      };
      return 'data:$mimeType;base64,${base64Encode(bytes)}';
    }

    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(
      '${documents.path}${Platform.pathSeparator}MyOwnStreamingService${Platform.pathSeparator}$folder',
    );
    await directory.create(recursive: true);
    final safeName = picked.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final destination = File(
      '${directory.path}${Platform.pathSeparator}${DateTime.now().microsecondsSinceEpoch}_$safeName',
    );
    await destination.writeAsBytes(bytes, flush: true);
    return destination.path;
  }

  /// Reads either a web data URI or an app-local file. It deliberately avoids
  /// touching dart:io when the app is running in a browser.
  static Future<Uint8List?> readStoredFileBytes(String path) async {
    if (path.isEmpty) return null;
    if (path.startsWith('data:')) {
      final separator = path.indexOf(',');
      if (separator < 0) return null;
      try {
        return base64Decode(path.substring(separator + 1));
      } catch (_) {
        return null;
      }
    }
    if (kIsWeb) return null;
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  static bool hasStoredFile(String path) {
    if (path.isEmpty) return false;
    if (path.startsWith('data:')) return path.contains(',');
    if (kIsWeb) return false;
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  static bool isSvgAsset(String path) =>
      path.toLowerCase().endsWith('.svg') ||
      path.toLowerCase().startsWith('data:image/svg+xml');

  static Future<void> loadImportedFont(String path, String family) async {
    if (_loadedFontFamilies.contains(family)) return;
    try {
      final bytes = await readStoredFileBytes(path);
      if (bytes == null || bytes.isEmpty) return;
      final loader = FontLoader(family);
      loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
      await loader.load();
      _loadedFontFamilies.add(family);
    } catch (_) {
      // The font remains in the user's catalog, and Flutter uses a fallback
      // until the font can be loaded on this device.
    }
  }

  static Future<void> _loadFontsForPreset(
      InterfaceAppearancePreset preset) async {
    for (final entry in preset.importedFonts.entries) {
      await loadImportedFont(entry.value, entry.key);
    }
  }

  static InterfaceAppearancePreset _applySafeCss(
      InterfaceAppearancePreset preset) {
    var result = preset;
    final allowed = <String, String>{};
    for (final declaration in preset.customCss.split(';')) {
      final separator = declaration.indexOf(':');
      if (separator <= 0) continue;
      final key = declaration.substring(0, separator).trim().toLowerCase();
      final value = declaration.substring(separator + 1).trim();
      if (const <String>{
        '--accent-color',
        '--background-color',
        '--glass-opacity',
        '--glass-blur',
        '--card-radius',
        '--card-opacity',
      }.contains(key)) {
        allowed[key] = value;
      }
    }
    Color? parseColor(String? value) {
      if (value == null) return null;
      var hex = value.trim().replaceFirst('#', '').replaceFirst('0x', '');
      if (hex.length == 6) hex = 'FF$hex';
      if (hex.length != 8) return null;
      final parsed = int.tryParse(hex, radix: 16);
      return parsed == null ? null : Color(parsed);
    }

    final accent = parseColor(allowed['--accent-color']);
    final background = parseColor(allowed['--background-color']);
    final glassOpacity = double.tryParse(allowed['--glass-opacity'] ?? '');
    final blur = double.tryParse(allowed['--glass-blur'] ?? '');
    final radius = double.tryParse(allowed['--card-radius'] ?? '');
    final cardOpacity = double.tryParse(allowed['--card-opacity'] ?? '');
    result = result.copyWith(
      accentColor: accent?.toARGB32() ?? result.accentColor,
      backgroundColor: background?.toARGB32() ?? result.backgroundColor,
      transparency:
          glassOpacity?.clamp(0, .8).toDouble() ?? result.transparency,
      blurSigma: blur?.clamp(0, 40).toDouble() ?? result.blurSigma,
      cornerRadius: radius?.clamp(0, 40).toDouble() ?? result.cornerRadius,
      cardOpacity: cardOpacity?.clamp(.1, 1).toDouble() ?? result.cardOpacity,
    );
    return result;
  }
}

class InterfaceAppearanceStudioPanel extends StatefulWidget {
  const InterfaceAppearanceStudioPanel({
    super.key,
    this.initialMode = 'classic',
    this.scrollable = true,
  });

  final String initialMode;
  final bool scrollable;

  @override
  State<InterfaceAppearanceStudioPanel> createState() =>
      _InterfaceAppearanceStudioPanelState();
}

class _InterfaceAppearanceStudioPanelState
    extends State<InterfaceAppearanceStudioPanel> {
  String _target = 'global';
  String _fontRole = interfaceFontRoles.first;
  String _fontCategory = 'Sans Serif';
  String _fontSearch = '';
  String _iconSemantic = 'home';
  InterfaceAppearancePreset _preset = const InterfaceAppearancePreset();
  final TextEditingController _cssController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _showFavoriteFontsOnly = false;
  Map<String, InterfaceAppearancePreset> _namedSkins =
      <String, InterfaceAppearancePreset>{};
  String? _selectedNamedSkin;

  @override
  void initState() {
    super.initState();
    _target = interfaceAppearanceModes.contains(widget.initialMode)
        ? widget.initialMode
        : 'global';
    _load();
  }

  @override
  void dispose() {
    _cssController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await InterfaceAppearanceStore.load(profileId: _currentProfileId);
    _namedSkins = await InterfaceAppearanceStore.loadNamedSkins();
    _reloadTarget();
    if (mounted) setState(() => _loading = false);
  }

  String? get _currentProfileId {
    try {
      return AppController.instance.currentProfile?.id;
    } catch (_) {
      return null;
    }
  }

  void _reloadTarget() {
    final next = _target == 'global'
        ? InterfaceAppearanceStore.globalPreset
        : InterfaceAppearanceStore.forMode(_target);
    _preset = next;
    _cssController.text = next.customCss;
  }

  Future<void> _save({String? message}) async {
    setState(() => _saving = true);
    try {
      _preset = _preset.copyWith(customCss: _cssController.text);
      await InterfaceAppearanceStore.savePreset(
          target: _target, preset: _preset);
      if (mounted && message != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickBackdrop() async {
    try {
      final picked = await FilePicker.pickFile(type: FileType.image);
      if (picked == null) return;
      final path =
          await InterfaceAppearanceStore.persistPickedFile(picked, 'backdrops');
      setState(() => _preset = _preset.copyWith(backdropPath: path));
      await _save(
          message:
              'Backdrop saved for ${_target == 'global' ? 'all interfaces' : interfaceModeLabel(_target)}.');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not import backdrop: $error')));
      }
    }
  }

  Future<void> _pickLogo() async {
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: <String>['svg', 'png', 'jpg', 'jpeg', 'webp'],
      );
      if (picked == null) return;
      final path =
          await InterfaceAppearanceStore.persistPickedFile(picked, 'branding');
      setState(() => _preset = _preset.copyWith(logoPath: path));
      await _save(message: 'Logo imported.');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not import logo: $error')));
      }
    }
  }

  Future<void> _pickCustomIcon() async {
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: <String>['svg', 'png', 'jpg', 'jpeg', 'webp'],
      );
      if (picked == null) return;
      final path = await InterfaceAppearanceStore.persistPickedFile(
        picked,
        'icons',
      );
      final icons = <String, String>{
        ..._preset.customIcons,
        _iconSemantic: path
      };
      setState(() => _preset = _preset.copyWith(customIcons: icons));
      await _save(message: 'Custom $_iconSemantic icon imported.');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not import icon: $error')),
        );
      }
    }
  }

  Future<void> _pickFont() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: <String>['ttf', 'otf'],
      );
      if (file == null) return;
      final path =
          await InterfaceAppearanceStore.persistPickedFile(file, 'fonts');
      final family = file.name
          .replaceFirst(RegExp(r'\.(ttf|otf)$', caseSensitive: false), '')
          .replaceAll(RegExp(r'[^A-Za-z0-9 ]'), ' ')
          .trim()
          .replaceAll(RegExp(r'\s+'), ' ');
      if (family.isEmpty) {
        throw StateError(
            'The font filename does not contain a usable family name.');
      }
      await InterfaceAppearanceStore.loadImportedFont(path, family);
      final imported = <String, String>{..._preset.importedFonts, family: path};
      final assignments = <String, String>{
        ..._preset.fontAssignments,
        _fontRole: family
      };
      setState(() => _preset = _preset.copyWith(
          importedFonts: imported, fontAssignments: assignments));
      await _save(message: '$family imported and assigned to $_fontRole.');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not import font: $error')));
      }
    }
  }

  Future<void> _saveNamedSkin({bool duplicate = false}) async {
    final controller = TextEditingController(
      text: duplicate ? 'Copy of ${_preset.skinPreset}' : _preset.skinPreset,
    );
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(duplicate ? 'Duplicate skin' : 'Save custom skin'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Skin name'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || name == null || name.trim().isEmpty) return;
    try {
      final saved = _preset.copyWith(customCss: _cssController.text);
      await InterfaceAppearanceStore.saveNamedSkin(name, saved);
      if (mounted) {
        setState(() {
          _namedSkins[name] = saved;
          _selectedNamedSkin = name;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Skin "$name" saved.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save skin: $error')),
        );
      }
    }
  }

  void _applyNamedSkin(String name) {
    final saved = _namedSkins[name];
    if (saved == null) return;
    setState(() {
      _selectedNamedSkin = name;
      _preset = saved;
      _cssController.text = saved.customCss;
    });
  }

  Future<void> _importSkin() async {
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: <String>['json'],
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) {
        throw const FormatException('The selected skin file is empty.');
      }
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map) {
        throw const FormatException('Skin file must contain a JSON object.');
      }
      final preset = InterfaceAppearancePreset.fromJson(
          Map<String, dynamic>.from(decoded));
      setState(() {
        _preset = preset;
        _cssController.text = preset.customCss;
      });
      await _save(
          message:
              'Skin imported and applied to ${_target == 'global' ? 'all interfaces' : interfaceModeLabel(_target)}.');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not import skin: $error')));
      }
    }
  }

  Future<void> _exportSkin() async {
    try {
      final payload = <String, dynamic>{
        'format': 'myownstreamingservice-skin',
        'version': 1,
        ..._preset.copyWith(customCss: _cssController.text).toJson(),
      };
      final fileName =
          '${_preset.skinPreset.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}.json';
      final output = await FilePicker.saveFile(
        dialogTitle: 'Export MyOwnStreamingService skin',
        fileName: fileName,
        bytes: Uint8List.fromList(
          utf8.encode(const JsonEncoder.withIndent('  ').convert(payload)),
        ),
      );
      if (output == null) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Skin exported to ${output.path}')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not export skin: $error')));
      }
    }
  }

  List<String> get _availableFonts {
    final fromCategory =
        interfaceFontCatalog[_fontCategory] ?? const <String>[];
    final all = <String>{...fromCategory, ..._preset.importedFonts.keys};
    final search = _fontSearch.trim().toLowerCase();
    return all
        .where((font) =>
            (!_showFavoriteFontsOnly || _preset.favoriteFonts.contains(font)) &&
            (search.isEmpty || font.toLowerCase().contains(search)))
        .toList()
      ..sort();
  }

  void _selectSkinPreset(String name) {
    final selected = switch (name) {
      'Ultra Glass' => _preset.copyWith(
          skinPreset: name,
          accentColor: 0xFFE7F4FF,
          backgroundColor: 0xFF101923,
          glassIntensity: .94,
          blurSigma: 28,
          transparency: .22,
          cardOpacity: .76,
          cornerRadius: 22,
          reflection: true,
          borderHighlights: true),
      'Ultra-Chromatic Glass' => _preset.copyWith(
          skinPreset: name,
          accentColor: 0xFF9D8CFF,
          backgroundColor: 0xFF101025,
          glassIntensity: 1,
          blurSigma: 32,
          transparency: .24,
          cardOpacity: .72,
          cornerRadius: 24,
          reflection: true,
          borderHighlights: true),
      'Blue Glass' => _preset.copyWith(
          skinPreset: name,
          accentColor: 0xFF59C7FF,
          backgroundColor: 0xFF071A2B,
          glassIntensity: .9,
          blurSigma: 24,
          transparency: .2,
          cardOpacity: .78,
          cornerRadius: 20,
          reflection: true,
          borderHighlights: true),
      'Neon Glass' => _preset.copyWith(
          skinPreset: name,
          accentColor: 0xFFFF4FC8,
          backgroundColor: 0xFF160A22,
          glassIntensity: .88,
          blurSigma: 26,
          transparency: .2,
          cardOpacity: .74,
          cornerRadius: 20,
          reflection: true,
          borderHighlights: true),
      'Frosted Crystal' => _preset.copyWith(
          skinPreset: name,
          accentColor: 0xFFE5F2FF,
          backgroundColor: 0xFF1B2733,
          glassIntensity: 1,
          blurSigma: 36,
          transparency: .3,
          cardOpacity: .68,
          cornerRadius: 26,
          reflection: true,
          borderHighlights: true),
      'Matte Black' => _preset.copyWith(
          skinPreset: name,
          accentColor: 0xFFE50914,
          backgroundColor: 0xFF080B12,
          glassIntensity: .12,
          blurSigma: 0,
          transparency: .08,
          cardOpacity: 1,
          cornerRadius: 12,
          reflection: false,
          borderHighlights: false),
      'Cinema Gold' => _preset.copyWith(
          skinPreset: name,
          accentColor: 0xFFD7B36A,
          backgroundColor: 0xFF100D08,
          glassIntensity: .18,
          blurSigma: 2,
          transparency: .1,
          cardOpacity: .94,
          cornerRadius: 12,
          reflection: false,
          borderHighlights: true),
      'Retro Rental' => _preset.copyWith(
          skinPreset: name,
          accentColor: 0xFF3F8CFF,
          backgroundColor: 0xFF081A30,
          glassIntensity: .28,
          blurSigma: 5,
          transparency: .12,
          cardOpacity: .96,
          cornerRadius: 8,
          reflection: false,
          borderHighlights: true),
      'Minimal' => _preset.copyWith(
          skinPreset: name,
          accentColor: 0xFFE2E5E9,
          backgroundColor: 0xFF121416,
          glassIntensity: .08,
          blurSigma: 0,
          transparency: .06,
          cardOpacity: .98,
          cornerRadius: 8,
          reflection: false,
          borderHighlights: false),
      'High Contrast' => _preset.copyWith(
          skinPreset: name,
          accentColor: 0xFFFFFF00,
          backgroundColor: 0xFF000000,
          glassIntensity: 0,
          blurSigma: 0,
          transparency: 0,
          cardOpacity: 1,
          cornerRadius: 4,
          reflection: false,
          borderHighlights: true),
      _ => _preset.copyWith(skinPreset: name),
    };
    setState(() => _preset = selected);
  }

  Widget _sectionCard(
      {required String title,
      required String subtitle,
      required Widget child,
      IconData icon = Icons.tune_rounded}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(children: <Widget>[
                Icon(icon, color: Color(_preset.accentColor)),
                const SizedBox(width: 9),
                Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w900))),
              ]),
              const SizedBox(height: 3),
              Text(subtitle,
                  style: const TextStyle(
                      color: Colors.white60, fontSize: 12, height: 1.35)),
              const SizedBox(height: 12),
              child,
            ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final bodyFont = _preset.fontAssignments['Descriptions'] ?? 'Roboto';
    final titleFont =
        _preset.fontAssignments['Application title'] ?? 'Bebas Neue';
    final hasBackdrop =
        InterfaceAppearanceStore.hasStoredFile(_preset.backdropPath);
    final hasLogo = InterfaceAppearanceStore.hasStoredFile(_preset.logoPath);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _sectionCard(
          title: 'Advanced Appearance & Skin Manager',
          subtitle:
              'One shared design system with global styling and independent overrides for Classic, Virtual Store, Virtual Kiosk and Virtual Theater.',
          icon: Icons.auto_awesome_rounded,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                DropdownButtonFormField<String>(
                  initialValue: _target,
                  decoration:
                      const InputDecoration(labelText: 'Apply settings to'),
                  items: <DropdownMenuItem<String>>[
                    const DropdownMenuItem(
                        value: 'global',
                        child: Text('Global – all interfaces')),
                    for (final mode in interfaceAppearanceModes)
                      DropdownMenuItem(
                          value: mode,
                          child: Text('${interfaceModeLabel(mode)} only')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _target = value;
                      _reloadTarget();
                    });
                  },
                ),
                if (_namedSkins.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _namedSkins.containsKey(_selectedNamedSkin)
                        ? _selectedNamedSkin
                        : null,
                    decoration:
                        const InputDecoration(labelText: 'Saved skin profiles'),
                    hint: const Text('Choose a saved skin'),
                    items: (_namedSkins.keys.toList()..sort())
                        .map((name) => DropdownMenuItem<String>(
                            value: name, child: Text(name)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) _applyNamedSkin(value);
                    },
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _preset.skinPreset,
                  decoration: const InputDecoration(labelText: 'Skin preset'),
                  items: const <String>[
                    'Ultra Glass',
                    'Ultra-Chromatic Glass',
                    'Blue Glass',
                    'Neon Glass',
                    'Frosted Crystal',
                    'Matte Black',
                    'Cinema Gold',
                    'Retro Rental',
                    'Minimal',
                    'High Contrast',
                  ]
                      .map((value) =>
                          DropdownMenuItem(value: value, child: Text(value)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) _selectSkinPreset(value);
                  },
                ),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
                  for (final color in <int>[
                    0xFFE50914,
                    0xFF00B7FF,
                    0xFF7C4DFF,
                    0xFF00C853,
                    0xFFFFC107,
                    0xFFFFFFFF
                  ])
                    InkWell(
                      onTap: () => setState(
                          () => _preset = _preset.copyWith(accentColor: color)),
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                              color: Color(color),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: _preset.accentColor == color
                                      ? Colors.white
                                      : Colors.white24,
                                  width:
                                      _preset.accentColor == color ? 3 : 1))),
                    ),
                ]),
                const SizedBox(height: 10),
                const Text('Background color',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
                  for (final color in <int>[
                    0xFF080B12,
                    0xFF111827,
                    0xFF071A2B,
                    0xFF160A22,
                    0xFF100D08,
                    0xFF202020,
                    0xFFFFFFFF
                  ])
                    InkWell(
                      onTap: () => setState(() =>
                          _preset = _preset.copyWith(backgroundColor: color)),
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                              color: Color(color),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: _preset.backgroundColor == color
                                      ? Colors.white
                                      : Colors.white24,
                                  width: _preset.backgroundColor == color
                                      ? 3
                                      : 1))),
                    ),
                ]),
                const SizedBox(height: 10),
                _slider(
                    'Glass intensity',
                    _preset.glassIntensity,
                    0,
                    1,
                    (value) => setState(() =>
                        _preset = _preset.copyWith(glassIntensity: value)),
                    label: '${(_preset.glassIntensity * 100).round()}%'),
                _slider(
                    'Blur strength',
                    _preset.blurSigma,
                    0,
                    40,
                    (value) => setState(
                        () => _preset = _preset.copyWith(blurSigma: value)),
                    label: '${_preset.blurSigma.round()} px'),
                _slider(
                    'Transparency',
                    _preset.transparency,
                    0,
                    .8,
                    (value) => setState(
                        () => _preset = _preset.copyWith(transparency: value)),
                    label: '${(_preset.transparency * 100).round()}%'),
                _slider(
                    'Card opacity',
                    _preset.cardOpacity,
                    .1,
                    1,
                    (value) => setState(
                        () => _preset = _preset.copyWith(cardOpacity: value)),
                    label: '${(_preset.cardOpacity * 100).round()}%'),
                _slider(
                    'Corner radius',
                    _preset.cornerRadius,
                    0,
                    40,
                    (value) => setState(
                        () => _preset = _preset.copyWith(cornerRadius: value)),
                    label: '${_preset.cornerRadius.round()} px'),
                SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Glass reflections'),
                    value: _preset.reflection,
                    onChanged: (value) => setState(
                        () => _preset = _preset.copyWith(reflection: value))),
                SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Highlighted glass borders'),
                    value: _preset.borderHighlights,
                    onChanged: (value) => setState(() =>
                        _preset = _preset.copyWith(borderHighlights: value))),
              ]),
        ),
        _sectionCard(
          title: 'Custom Backdrops',
          subtitle:
              'Import wallpapers and keep separate backgrounds for each experience. Use SVG for logos and icon artwork, not as a font format.',
          icon: Icons.wallpaper_rounded,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (hasBackdrop)
                  ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: InterfaceAppearanceAsset(
                          path: _preset.backdropPath,
                          height: 130,
                          width: double.infinity,
                          fit: BoxFit.cover)),
                Wrap(spacing: 8, children: <Widget>[
                  OutlinedButton.icon(
                      onPressed: _pickBackdrop,
                      icon: const Icon(Icons.upload_rounded),
                      label: const Text('Import backdrop')),
                  if (_preset.backdropPath.isNotEmpty)
                    TextButton(
                        onPressed: () async {
                          setState(() =>
                              _preset = _preset.copyWith(backdropPath: ''));
                          await _save(message: 'Backdrop removed.');
                        },
                        child: const Text('Remove')),
                ]),
              ]),
        ),
        _sectionCard(
          title: 'Font Manager',
          subtitle:
              'Browse Serif, Sans Serif, Script, Monospaced, Display and movie-inspired categories. Uninstalled commercial and fan-made typefaces use a device fallback until you import a licensed font file.',
          icon: Icons.text_fields_rounded,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                DropdownButtonFormField<String>(
                    initialValue: _fontRole,
                    decoration:
                        const InputDecoration(labelText: 'Typography role'),
                    items: interfaceFontRoles
                        .map((role) =>
                            DropdownMenuItem(value: role, child: Text(role)))
                        .toList(),
                    onChanged: (value) => setState(
                        () => _fontRole = value ?? interfaceFontRoles.first)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                    initialValue: _fontCategory,
                    decoration:
                        const InputDecoration(labelText: 'Font category'),
                    items: interfaceFontCatalog.keys
                        .map((category) => DropdownMenuItem(
                            value: category, child: Text(category)))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _fontCategory = value ?? 'Sans Serif')),
                const SizedBox(height: 8),
                TextField(
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        labelText: 'Search fonts'),
                    onChanged: (value) => setState(() => _fontSearch = value)),
                FilterChip(
                  avatar: const Icon(Icons.star_rounded, size: 16),
                  label: const Text('Favorites only'),
                  selected: _showFavoriteFontsOnly,
                  onSelected: (value) =>
                      setState(() => _showFavoriteFontsOnly = value),
                ),
                const SizedBox(height: 8),
                Builder(builder: (context) {
                  final fonts = _availableFonts;
                  final assigned = _preset.fontAssignments[_fontRole];
                  final selectedFont = fonts.contains(assigned)
                      ? assigned!
                      : (fonts.isNotEmpty ? fonts.first : 'Roboto');
                  final isFavorite =
                      _preset.favoriteFonts.contains(selectedFont);
                  return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                            child: DropdownButtonFormField<String>(
                          initialValue: selectedFont,
                          decoration:
                              const InputDecoration(labelText: 'Select font'),
                          items: fonts.isEmpty
                              ? <DropdownMenuItem<String>>[
                                  DropdownMenuItem(
                                      value: 'Roboto',
                                      child: const Text('Roboto'))
                                ]
                              : fonts
                                  .map((font) => DropdownMenuItem(
                                      value: font,
                                      child: Text(font,
                                          overflow: TextOverflow.ellipsis)))
                                  .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _preset = _preset.copyWith(
                                      fontAssignments: <String, String>{
                                        ..._preset.fontAssignments,
                                        _fontRole: value
                                      }));
                            }
                          },
                        )),
                        IconButton(
                          tooltip: isFavorite
                              ? 'Remove font from favorites'
                              : 'Add font to favorites',
                          onPressed: () {
                            final favorites = <String>{
                              ..._preset.favoriteFonts
                            };
                            if (isFavorite) {
                              favorites.remove(selectedFont);
                            } else {
                              favorites.add(selectedFont);
                            }
                            setState(() => _preset = _preset.copyWith(
                                favoriteFonts: favorites.toList()..sort()));
                          },
                          icon: Icon(
                              isFavorite
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: isFavorite ? Colors.amber : null),
                        ),
                      ]);
                }),
                const SizedBox(height: 8),
                Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .06),
                        borderRadius: BorderRadius.circular(12)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('The quick brown fox jumps over the lazy dog',
                              style: TextStyle(
                                  fontFamily:
                                      _preset.fontAssignments[_fontRole],
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700)),
                          Text(
                              '0123456789  •  $_fontRole  •  ${_preset.fontAssignments[_fontRole] ?? 'Default'}',
                              style: const TextStyle(
                                  color: Colors.white60, fontSize: 11)),
                        ])),
                OutlinedButton.icon(
                    onPressed: _pickFont,
                    icon: const Icon(Icons.file_upload_outlined),
                    label: const Text('Import TTF / OTF font')),
                if (_preset.importedFonts.isNotEmpty)
                  Text(
                      'Imported fonts: ${_preset.importedFonts.keys.join(', ')}',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 11)),
              ]),
        ),
        _sectionCard(
          title: 'Icon Packs & Branding',
          subtitle:
              'Choose a built-in icon family or import custom SVG/PNG artwork for specific actions. Upload your application logo separately.',
          icon: Icons.interests_rounded,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                DropdownButtonFormField<String>(
                  initialValue: _preset.iconPack,
                  decoration: const InputDecoration(labelText: 'Icon pack'),
                  items: const <String>[
                    'Material Rounded',
                    'Material Outlined',
                    'Cupertino',
                    'Minimal Line',
                    'Retro Arcade',
                    'Cinema Neon'
                  ]
                      .map((value) =>
                          DropdownMenuItem(value: value, child: Text(value)))
                      .toList(),
                  onChanged: (value) => setState(
                      () => _preset = _preset.copyWith(iconPack: value)),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _iconSemantic,
                  decoration:
                      const InputDecoration(labelText: 'Custom icon purpose'),
                  items: const <String>[
                    'home',
                    'movie',
                    'tv',
                    'music',
                    'search',
                    'settings',
                    'collections',
                    'favorites',
                    'play',
                    'store',
                    'kiosk',
                    'theater',
                    'profile',
                    'more',
                    'previous',
                    'next'
                  ]
                      .map((value) => DropdownMenuItem(
                          value: value,
                          child: Text(
                              value[0].toUpperCase() + value.substring(1))))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _iconSemantic = value ?? 'home'),
                ),
                const SizedBox(height: 8),
                Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      OutlinedButton.icon(
                          onPressed: _pickCustomIcon,
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: const Text('Import SVG / PNG icon')),
                      if (_preset.customIcons.containsKey(_iconSemantic))
                        TextButton(
                            onPressed: () async {
                              final icons = <String, String>{
                                ..._preset.customIcons
                              }..remove(_iconSemantic);
                              setState(() => _preset =
                                  _preset.copyWith(customIcons: icons));
                              await _save(
                                  message:
                                      'Custom $_iconSemantic icon removed.');
                            },
                            child: const Text('Remove selected icon')),
                    ]),
                if (_preset.customIcons.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                        'Custom icons: ${_preset.customIcons.keys.join(', ')}',
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 11)),
                  ),
                const SizedBox(height: 10),
                Wrap(spacing: 14, runSpacing: 10, children: <Widget>[
                  for (final semantic in <String>[
                    'home',
                    'movie',
                    'tv',
                    'music',
                    'search',
                    'settings'
                  ])
                    Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                      InterfacePackIcon(
                          mode: _target == 'global'
                              ? widget.initialMode
                              : _target,
                          preset: _preset,
                          semantic: semantic,
                          size: 26,
                          color: Color(_preset.accentColor)),
                      const SizedBox(height: 3),
                      Text(semantic,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 10)),
                    ]),
                ]),
                const SizedBox(height: 12),
                if (hasLogo)
                  SizedBox(height: 56, child: _logoPreview(_preset.logoPath)),
                Wrap(spacing: 8, children: <Widget>[
                  OutlinedButton.icon(
                      onPressed: _pickLogo,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('Import custom logo')),
                  if (_preset.logoPath.isNotEmpty)
                    TextButton(
                        onPressed: () async {
                          setState(
                              () => _preset = _preset.copyWith(logoPath: ''));
                          await _save(message: 'Custom logo removed.');
                        },
                        child: const Text('Remove logo')),
                ]),
              ]),
        ),
        _sectionCard(
          title: 'CSS-inspired Advanced Styling',
          subtitle:
              'Only supported design tokens are applied; arbitrary CSS and executable code are never run in the Flutter widget tree.',
          icon: Icons.code_rounded,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextField(
                    controller: _cssController,
                    minLines: 4,
                    maxLines: 8,
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    decoration: const InputDecoration(
                        hintText:
                            '--accent-color: #E50914;\n--glass-opacity: 0.18;\n--glass-blur: 18;\n--card-radius: 18;\n--card-opacity: 0.84;',
                        alignLabelWithHint: true)),
                const SizedBox(height: 4),
                const Text(
                    'Supported tokens: --accent-color, --background-color, --glass-opacity, --glass-blur, --card-radius and --card-opacity.',
                    style: TextStyle(color: Colors.white54, fontSize: 11)),
                OutlinedButton.icon(
                    onPressed: () async {
                      setState(() => _preset =
                          _preset.copyWith(customCss: _cssController.text));
                      await _save(
                          message: 'Supported style tokens applied and saved.');
                    },
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Apply style tokens')),
              ]),
        ),
        _sectionCard(
          title: 'Live Preview',
          subtitle:
              'Preview the same global skin translated for the selected interface.',
          icon: Icons.preview_rounded,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_preset.cornerRadius),
            child: Stack(children: <Widget>[
              if (hasBackdrop)
                Positioned.fill(
                    child: InterfaceAppearanceAsset(
                        path: _preset.backdropPath, fit: BoxFit.cover)),
              BackdropFilter(
                filter: ui.ImageFilter.blur(
                  sigmaX: _preset.blurSigma * _preset.glassIntensity,
                  sigmaY: _preset.blurSigma * _preset.glassIntensity,
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Color(_preset.backgroundColor).withValues(
                      alpha:
                          (_preset.transparency + _preset.glassIntensity * .62)
                              .clamp(.08, .96)
                              .toDouble(),
                    ),
                    border: _preset.borderHighlights
                        ? Border.all(color: Colors.white.withValues(alpha: .34))
                        : null,
                    borderRadius: BorderRadius.circular(_preset.cornerRadius),
                    boxShadow: _preset.reflection
                        ? <BoxShadow>[
                            BoxShadow(
                                color: Colors.white.withValues(alpha: .08),
                                blurRadius: 24,
                                spreadRadius: -8,
                                offset: const Offset(0, -5))
                          ]
                        : const <BoxShadow>[],
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(children: <Widget>[
                          if (hasLogo)
                            SizedBox(
                                width: 42,
                                height: 42,
                                child: _logoPreview(_preset.logoPath))
                          else
                            Icon(Icons.movie_filter_rounded,
                                color: Color(_preset.accentColor), size: 30),
                          const SizedBox(width: 9),
                          Expanded(
                              child: Text(
                                  '${interfaceModeLabel(_target == 'global' ? widget.initialMode : _target)} Experience',
                                  style: TextStyle(
                                      fontFamily: titleFont,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 22))),
                          Icon(Icons.favorite_rounded,
                              color: Color(_preset.accentColor)),
                        ]),
                        const SizedBox(height: 14),
                        Container(
                            height: 78,
                            decoration: BoxDecoration(
                                color: Colors.white.withValues(
                                    alpha: _preset.transparency + .05),
                                borderRadius:
                                    BorderRadius.circular(_preset.cornerRadius),
                                border: Border.all(
                                    color: Colors.white.withValues(
                                        alpha: _preset.borderHighlights
                                            ? .3
                                            : .08))),
                            child: Center(
                                child: Text('Featured entertainment',
                                    style: TextStyle(
                                        fontFamily: bodyFont,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700)))),
                        const SizedBox(height: 10),
                        Text(
                            'Continue Watching  •  Recommended  •  Collections',
                            style: TextStyle(
                                fontFamily: bodyFont,
                                color: Colors.white70,
                                fontSize: 12)),
                        const SizedBox(height: 12),
                        Row(children: <Widget>[
                          for (var index = 0; index < 4; index++)
                            Expanded(
                                child: Container(
                                    height: 56,
                                    margin: EdgeInsets.only(
                                        right: index == 3 ? 0 : 7),
                                    decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                            alpha: _preset.cardOpacity * .25),
                                        borderRadius: BorderRadius.circular(
                                            _preset.cornerRadius * .55),
                                        border: Border.all(
                                            color: Colors.white.withValues(
                                                alpha: _preset.borderHighlights
                                                    ? .22
                                                    : .06))))),
                        ]),
                      ]),
                ),
              ),
            ]),
          ),
        ),
        Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
          OutlinedButton.icon(
              onPressed: () => _saveNamedSkin(),
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('Save as custom skin')),
          OutlinedButton.icon(
              onPressed: () => _saveNamedSkin(duplicate: true),
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Duplicate skin')),
          OutlinedButton.icon(
              onPressed: _importSkin,
              icon: const Icon(Icons.file_open_outlined),
              label: const Text('Import skin')),
          OutlinedButton.icon(
              onPressed: _exportSkin,
              icon: const Icon(Icons.ios_share_rounded),
              label: const Text('Export skin')),
        ]),
        const Padding(
          padding: EdgeInsets.only(top: 4, bottom: 8),
          child: Text(
            'Skin JSON exports settings and local asset paths. Re-import custom fonts, backdrops, icons and logos when moving the skin to another device.',
            style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.35),
          ),
        ),
        Row(children: <Widget>[
          Expanded(
            child: OutlinedButton(
              onPressed: () async {
                await InterfaceAppearanceStore.resetMode(_target);
                _reloadTarget();
                if (mounted) setState(() {});
              },
              child: Text(_target == 'global'
                  ? 'Reset global skin'
                  : 'Reset ${interfaceModeLabel(_target)} override'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: _saving
                  ? null
                  : () => _save(message: 'Appearance settings saved.'),
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: const Text('Save appearance'),
            ),
          ),
        ]),
      ],
    );
    return widget.scrollable
        ? SingleChildScrollView(
            padding: const EdgeInsets.all(16), child: content)
        : content;
  }

  Widget _slider(String title, double value, double min, double max,
          ValueChanged<double> onChanged,
          {required String label}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Column(children: <Widget>[
          Row(children: <Widget>[
            Expanded(child: Text(title)),
            Text(label,
                style: const TextStyle(color: Colors.white60, fontSize: 11))
          ]),
          Slider(
              value: value.clamp(min, max).toDouble(),
              min: min,
              max: max,
              onChanged: onChanged),
        ]),
      );

  Widget _logoPreview(String path) => InterfaceAppearanceAsset(
        path: path,
        fit: BoxFit.contain,
        placeholder: const Icon(Icons.image_not_supported_outlined),
      );
}

/// Renders imported SVG/PNG/JPEG/WebP assets on every Flutter target.
/// SVGs are decoded from bytes instead of SvgPicture.file, whose File type is
/// not available in Flutter Web.
class InterfaceAppearanceAsset extends StatefulWidget {
  const InterfaceAppearanceAsset({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.color,
    this.colorFilter,
    this.placeholder,
  });

  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Color? color;
  final ColorFilter? colorFilter;
  final Widget? placeholder;

  @override
  State<InterfaceAppearanceAsset> createState() =>
      _InterfaceAppearanceAssetState();
}

class _InterfaceAppearanceAssetState extends State<InterfaceAppearanceAsset> {
  late Future<Uint8List?> _bytesFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant InterfaceAppearanceAsset oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _load();
  }

  void _load() {
    _bytesFuture = InterfaceAppearanceStore.readStoredFileBytes(widget.path);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _bytesFuture,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (snapshot.hasError || bytes == null || bytes.isEmpty) {
          return widget.placeholder ?? const SizedBox.shrink();
        }
        if (InterfaceAppearanceStore.isSvgAsset(widget.path)) {
          return SvgPicture.memory(
            bytes,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            colorFilter: widget.colorFilter,
            placeholderBuilder: (_) =>
                widget.placeholder ?? const SizedBox.shrink(),
          );
        }
        return Image.memory(
          bytes,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          color: widget.color,
          errorBuilder: (_, __, ___) =>
              widget.placeholder ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

/// Resolves built-in icon packs and per-action imported SVG/PNG artwork.
class InterfacePackIcon extends StatelessWidget {
  const InterfacePackIcon({
    super.key,
    required this.semantic,
    this.mode = 'classic',
    this.size = 24,
    this.color,
    this.selected = false,
    this.preset,
  });

  final String semantic;
  final String mode;
  final double size;
  final Color? color;
  final bool selected;
  final InterfaceAppearancePreset? preset;

  IconData _glyph(String pack) {
    final key = semantic.toLowerCase();
    if (pack == 'Retro Arcade') {
      return switch (key) {
        'home' => Icons.videogame_asset_rounded,
        'movie' => Icons.local_movies_rounded,
        'tv' => Icons.live_tv_rounded,
        'music' => Icons.album_rounded,
        'search' => Icons.search_rounded,
        'settings' => Icons.gamepad_rounded,
        'collections' => Icons.inventory_2_rounded,
        'favorites' => Icons.favorite_rounded,
        'play' => Icons.play_arrow_rounded,
        'profile' => Icons.person_rounded,
        'more' => Icons.more_horiz_rounded,
        'store' => Icons.storefront_rounded,
        'kiosk' => Icons.point_of_sale_rounded,
        'theater' => Icons.theaters_rounded,
        'previous' => Icons.keyboard_arrow_up_rounded,
        'next' => Icons.keyboard_arrow_down_rounded,
        _ => Icons.videogame_asset_rounded,
      };
    }
    if (pack == 'Cinema Neon') {
      return switch (key) {
        'home' => Icons.home_filled,
        'movie' => Icons.movie_filter_rounded,
        'tv' => Icons.tv_rounded,
        'music' => Icons.graphic_eq_rounded,
        'search' => Icons.search_rounded,
        'settings' => Icons.tune_rounded,
        'collections' => Icons.auto_awesome_motion_rounded,
        'favorites' => Icons.favorite_rounded,
        'play' => Icons.play_circle_fill_rounded,
        'profile' => Icons.account_circle_rounded,
        'more' => Icons.more_horiz_rounded,
        'store' => Icons.storefront_rounded,
        'kiosk' => Icons.touch_app_rounded,
        'theater' => Icons.theaters_rounded,
        'previous' => Icons.keyboard_arrow_up_rounded,
        'next' => Icons.keyboard_arrow_down_rounded,
        _ => Icons.auto_awesome_rounded,
      };
    }
    final outlined = pack == 'Material Outlined' ||
        pack == 'Minimal Line' ||
        pack == 'Cupertino';
    return switch (key) {
      'home' => selected
          ? Icons.home_rounded
          : (outlined ? Icons.home_outlined : Icons.home_rounded),
      'movie' => outlined ? Icons.movie_outlined : Icons.movie_rounded,
      'tv' => outlined ? Icons.tv_outlined : Icons.tv_rounded,
      'music' =>
        outlined ? Icons.music_note_outlined : Icons.music_note_rounded,
      'search' => outlined ? Icons.search_outlined : Icons.search_rounded,
      'settings' => outlined ? Icons.settings_outlined : Icons.settings_rounded,
      'collections' => outlined
          ? Icons.collections_bookmark_outlined
          : Icons.collections_bookmark_rounded,
      'favorites' =>
        outlined ? Icons.favorite_border_rounded : Icons.favorite_rounded,
      'play' => outlined ? Icons.play_arrow_outlined : Icons.play_arrow_rounded,
      'profile' =>
        outlined ? Icons.person_outline_rounded : Icons.person_rounded,
      'more' => Icons.more_horiz_rounded,
      'store' =>
        outlined ? Icons.storefront_outlined : Icons.storefront_rounded,
      'kiosk' =>
        outlined ? Icons.point_of_sale_outlined : Icons.point_of_sale_rounded,
      'theater' => outlined ? Icons.theaters_outlined : Icons.theaters_rounded,
      'previous' => Icons.keyboard_arrow_up_rounded,
      'next' => Icons.keyboard_arrow_down_rounded,
      _ => Icons.circle_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: InterfaceAppearanceStore.revision,
      builder: (context, _, __) {
        final appearance = preset ?? InterfaceAppearanceStore.forMode(mode);
        final customPath = appearance.customIcons[semantic.toLowerCase()];
        if (customPath != null &&
            InterfaceAppearanceStore.hasStoredFile(customPath)) {
          return InterfaceAppearanceAsset(
            path: customPath,
            width: size,
            height: size,
            fit: BoxFit.contain,
            color: color,
            colorFilter: color == null
                ? null
                : ColorFilter.mode(color!, BlendMode.srcIn),
            placeholder: Icon(
              _glyph(appearance.iconPack),
              size: size,
              color: color,
            ),
          );
        }
        return Icon(_glyph(appearance.iconPack), size: size, color: color);
      },
    );
  }
}

/// Shared logo widget for the four interface modes.
class InterfaceBrandingLogo extends StatelessWidget {
  const InterfaceBrandingLogo(
      {super.key, this.mode = 'classic', this.width = 120, this.height = 36});

  final String mode;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: InterfaceAppearanceStore.revision,
      builder: (context, revision, _) {
        final path = InterfaceAppearanceStore.forMode(mode).logoPath;
        if (!InterfaceAppearanceStore.hasStoredFile(path)) {
          return const SizedBox.shrink();
        }
        return SizedBox(
          width: width,
          height: height,
          child: InterfaceAppearanceAsset(
            path: path,
            fit: BoxFit.contain,
          ),
        );
      },
    );
  }
}
