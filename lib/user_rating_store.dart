import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_core.dart';
import 'backend_api.dart';

/// Profile-scoped personal ratings and their presentation preferences.
/// Personal scores are intentionally separate from provider/critic ratings.
class UserRatingPalette {
  /// Named choices shown in the rating-color settings screen.
  /// Decimal ARGB values keep the implementation independent from hex-entry UI.
  static const Map<String, int> namedColors = <String, int>{
    'Gold': 4294956800,
    'Silver': 4290822336,
    'Platinum': 4293256418,
    'Red': 4294198070,
    'Light red': 4294747557,
    'Dark red': 4288224027,
    'Grey': 4286611584,
    'Light grey': 4292072403,
    'Black': 4278190080,
    'Yellow': 4294626325,
    'Orange': 4294940672,
    'Green': 4283215696,
    'Dark green': 4279522093,
    'Light green': 4287023498,
    'Maroon': 4286578688,
    'Beige': 4294309340,
    'White': 4294967295,
    'Egg white': 4294965479,
    'Blue': 4280391411,
    'Ocean blue': 4278217108,
    'Sky blue': 4287090411,
    'Navy': 4278190208,
    'Teal': 4278222976,
    'Turquoise': 4282441936,
    'Cyan': 4278238420,
    'Purple': 4288423856,
    'Lavender': 4293322490,
    'Pink': 4293467747,
    'Coral': 4294934352,
    'Brown': 4286141768,
    'Skin color': 4292386939,
    'Olive': 4286611456,
    'Mint': 4288216984,
    'Forest green': 4280453922,
    'Lime': 4291681337,
    'Indigo': 4282339765,
    'Charcoal': 4281746767,
    'Rose gold': 4290211449,
  };

  static const Map<String, int> defaultColors = <String, int>{
    'excellent': 4279522093, // Dark green, 90–100
    'good': 4287023498, // Light green, 75–89
    'moderate': 4294626325, // Yellow, 60–74
    'low': 4294747557, // Light red, 50–59
    'veryLow': 4288224027, // Dark red, 0–49
  };

  final int excellentThreshold;
  final int goodThreshold;
  final int moderateThreshold;
  final int lowThreshold;
  final Map<String, int> colors;

  const UserRatingPalette({
    this.excellentThreshold = 90,
    this.goodThreshold = 75,
    this.moderateThreshold = 60,
    this.lowThreshold = 50,
    this.colors = defaultColors,
  });

  static String nameForColor(int value) {
    final red = (value >> 16) & 255;
    final green = (value >> 8) & 255;
    final blue = value & 255;
    var closestName = namedColors.keys.first;
    var closestDistance = 1 << 30;
    for (final entry in namedColors.entries) {
      final candidate = entry.value;
      final candidateRed = (candidate >> 16) & 255;
      final candidateGreen = (candidate >> 8) & 255;
      final candidateBlue = candidate & 255;
      final redDelta = red - candidateRed;
      final greenDelta = green - candidateGreen;
      final blueDelta = blue - candidateBlue;
      final distance = redDelta * redDelta +
          greenDelta * greenDelta +
          blueDelta * blueDelta;
      if (distance < closestDistance) {
        closestDistance = distance;
        closestName = entry.key;
      }
    }
    return closestName;
  }

  Color colorFor(double percent) {
    if (percent >= excellentThreshold) return Color(colors['excellent']!);
    if (percent >= goodThreshold) return Color(colors['good']!);
    if (percent >= moderateThreshold) return Color(colors['moderate']!);
    if (percent >= lowThreshold) return Color(colors['low']!);
    return Color(colors['veryLow']!);
  }

  String bandFor(double percent) {
    if (percent >= excellentThreshold) return 'Excellent';
    if (percent >= goodThreshold) return 'Good';
    if (percent >= moderateThreshold) return 'Moderate';
    if (percent >= lowThreshold) return 'Low';
    return 'Very low';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'excellentThreshold': excellentThreshold,
        'goodThreshold': goodThreshold,
        'moderateThreshold': moderateThreshold,
        'lowThreshold': lowThreshold,
        // Keep numeric values for older app versions and save the readable names
        // for the current settings UI.
        'colors': colors,
        'colorNames': <String, String>{
          for (final entry in colors.entries)
            entry.key: nameForColor(entry.value),
        },
      };

  factory UserRatingPalette.fromJson(Map<String, dynamic> json) {
    final rawColors = json['colors'];
    final rawColorNames = json['colorNames'];
    final colors = <String, int>{...defaultColors};
    for (final key in defaultColors.keys) {
      final savedName = rawColorNames is Map
          ? rawColorNames[key]?.toString()
          : null;
      final namedValue = savedName == null ? null : namedColors[savedName];
      if (namedValue != null) {
        colors[key] = namedValue;
        continue;
      }
      if (rawColors is Map) {
        final value = rawColors[key];
        if (value is num) colors[key] = value.toInt();
      }
    }
    int threshold(String key, int fallback) {
      final raw = json[key];
      return (raw is num ? raw.toInt() : fallback).clamp(0, 100).toInt();
    }
    final excellent = threshold('excellentThreshold', 90);
    final good = threshold('goodThreshold', 75);
    final moderate = threshold('moderateThreshold', 60);
    final low = threshold('lowThreshold', 50);
    return UserRatingPalette(
      excellentThreshold: excellent,
      goodThreshold: good.clamp(0, excellent).toInt(),
      moderateThreshold: moderate.clamp(0, good).toInt(),
      lowThreshold: low.clamp(0, moderate).toInt(),
      colors: colors,
    );
  }
}

class UserMediaRatingStore {
  UserMediaRatingStore._();

  static final ValueNotifier<int> changes = ValueNotifier<int>(0);
  static final Map<String, Map<String, double>> _ratings =
      <String, Map<String, double>>{};
  static final Map<String, UserRatingPalette> _palettes =
      <String, UserRatingPalette>{};
  static final Set<String> _initializedProfiles = <String>{};

  static String _profileKey(String? profileId) =>
      profileId?.trim().isNotEmpty == true ? profileId!.trim() : 'default';

  static String trackKey(String id) => 'music-track:$id';

  static String artistKey(String artist) => 'music-artist:${_normalize(artist)}';

  static String albumKey(String title, String artist) =>
      'music-album:${_normalize(artist)}:${_normalize(title)}';

  // URI encoding keeps non-Latin artist/album names distinct and safe for
  // storage keys (for example Japanese, Korean, Arabic, and accented names).
  static String _normalize(String value) => Uri.encodeComponent(
        value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' '),
      );

  static Future<void> initializeForProfile(String? profileId) async {
    final profile = _profileKey(profileId);
    if (_initializedProfiles.contains(profile)) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('moss_user_ratings_$profile');
    final local = <String, double>{};
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final value = entry.value;
            final score = value is num
                ? value.toDouble()
                : double.tryParse(value.toString());
            // The profile cache introduced with this store always persists
            // percentage scores. Legacy star values are converted at the API
            // boundary, where the source field is unambiguous.
            if (score != null && score >= 0 && score <= 100) {
              local[entry.key.toString()] = score;
            }
          }
        }
      } catch (_) {
        // Keep an empty local cache and recover from the backend if possible.
      }
    }
    _ratings[profile] = local;

    final paletteRaw = prefs.getString('moss_rating_palette_$profile');
    if (paletteRaw != null) {
      try {
        final decoded = jsonDecode(paletteRaw);
        if (decoded is Map) {
          _palettes[profile] = UserRatingPalette.fromJson(
            Map<String, dynamic>.from(decoded),
          );
        }
      } catch (_) {}
    }
    _palettes.putIfAbsent(profile, () => const UserRatingPalette());
    _initializedProfiles.add(profile);

    // Synchronize all personal ratings in one request, not one request per card.
    try {
      if (profileId == null || profileId.trim().isEmpty) {
        changes.value++;
        return;
      }
      final response = await AppController.instance.backendApi
          .getProfileUserRatings(profileId: profileId.trim());
      final rows = response['ratings'];
      if (rows is List) {
        for (final row in rows.whereType<Map>()) {
          final map = Map<String, dynamic>.from(row);
          final id = map['mediaId']?.toString() ?? '';
          final value = map['score'];
          final score = value is num
              ? value.toDouble()
              : double.tryParse(value?.toString() ?? '');
          final legacy = map['stars'] is num
              ? (map['stars'] as num).toDouble() * 20
              : null;
          final normalized = score ?? legacy;
          if (id.isNotEmpty && normalized != null && normalized >= 0 && normalized <= 100) {
            _ratings[profile]![id] = normalized;
          }
        }
        await _persistRatings(profile);
      }
    } catch (_) {
      // Offline browsing continues with the last locally cached ratings.
    }
    changes.value++;
  }

  static double? scoreFor(String? profileId, String mediaId) =>
      _ratings[_profileKey(profileId)]?[mediaId];

  /// Compatibility accessor for star-based rating controls.
  static double? starsFor(String? profileId, String mediaId) {
    final score = scoreFor(profileId, mediaId);
    return score == null ? null : score / 20;
  }

  static int? scorePercentFor(String? profileId, String mediaId) {
    final score = scoreFor(profileId, mediaId);
    return score?.round().clamp(0, 100).toInt();
  }

  static UserRatingPalette paletteFor(String? profileId) =>
      _palettes[_profileKey(profileId)] ?? const UserRatingPalette();

  static Color? colorFor(String? profileId, String mediaId) {
    final score = scorePercentFor(profileId, mediaId);
    return score == null ? null : paletteFor(profileId).colorFor(score.toDouble());
  }

  static Future<void> rememberScore({
    required String? profileId,
    required String mediaId,
    required double score,
  }) async {
    if (mediaId.trim().isEmpty || !score.isFinite || score < 0 || score > 100) return;
    final profile = _profileKey(profileId);
    _ratings.putIfAbsent(profile, () => <String, double>{})[mediaId] = score;
    _initializedProfiles.add(profile);
    await _persistRatings(profile);
    changes.value++;
  }

  static Future<void> _persistRatings(String profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'moss_user_ratings_$profile',
      jsonEncode(_ratings[profile] ?? <String, double>{}),
    );
  }

  static Future<void> savePalette(
    String? profileId,
    UserRatingPalette palette,
  ) async {
    final profile = _profileKey(profileId);
    _palettes[profile] = palette;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('moss_rating_palette_$profile', jsonEncode(palette.toJson()));
    changes.value++;
  }

  static Future<void> clearLocalCache(String? profileId) async {
    final profile = _profileKey(profileId);
    _ratings.remove(profile);
    _initializedProfiles.remove(profile);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('moss_user_ratings_$profile');
    changes.value++;
  }
}

class UserScoreBadge extends StatelessWidget {
  const UserScoreBadge({super.key, required this.score, required this.palette});

  final num? score;
  final UserRatingPalette palette;

  @override
  Widget build(BuildContext context) {
    if (score == null) return const SizedBox.shrink();
    final value = score!.toDouble();
    final color = palette.colorFor(value);
    final percentDigits = value == value.truncateToDouble() ? 0 : 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .18),
        border: Border.all(color: color.withValues(alpha: .72)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        '${value.toStringAsFixed(percentDigits)}% · ${(value / 10).toStringAsFixed(1)}/10',
        style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class RatingColorSettingsScreen extends StatefulWidget {
  const RatingColorSettingsScreen({super.key});

  @override
  State<RatingColorSettingsScreen> createState() =>
      _RatingColorSettingsScreenState();
}

class _RatingColorSettingsScreenState extends State<RatingColorSettingsScreen> {
  late UserRatingPalette _palette;
  final Map<String, String> _selectedColorNames = <String, String>{};
  final Map<String, TextEditingController> _thresholdControllers = {};
  bool _ready = false;

  static const _labels = <String, String>{
    'excellent': 'Excellent',
    'good': 'Good',
    'moderate': 'Moderate',
    'low': 'Low',
    'veryLow': 'Very low',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await UserMediaRatingStore.initializeForProfile(
      AppController.instance.currentProfile?.id,
    );
    _palette = UserMediaRatingStore.paletteFor(
      AppController.instance.currentProfile?.id,
    );
    for (final entry in _palette.colors.entries) {
      _selectedColorNames[entry.key] =
          UserRatingPalette.nameForColor(entry.value);
    }
    _thresholdControllers['excellent'] =
        TextEditingController(text: '${_palette.excellentThreshold}');
    _thresholdControllers['good'] =
        TextEditingController(text: '${_palette.goodThreshold}');
    _thresholdControllers['moderate'] =
        TextEditingController(text: '${_palette.moderateThreshold}');
    _thresholdControllers['low'] =
        TextEditingController(text: '${_palette.lowThreshold}');
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    for (final controller in _thresholdControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _selectColor(String band, String colorName) {
    final colorValue = UserRatingPalette.namedColors[colorName];
    if (colorValue == null) return;
    setState(() {
      _selectedColorNames[band] = colorName;
      final colors = <String, int>{..._palette.colors, band: colorValue};
      _palette = UserRatingPalette(
        excellentThreshold: _palette.excellentThreshold,
        goodThreshold: _palette.goodThreshold,
        moderateThreshold: _palette.moderateThreshold,
        lowThreshold: _palette.lowThreshold,
        colors: colors,
      );
    });
  }

  Future<void> _save() async {
    final colors = <String, int>{};
    for (final key in UserRatingPalette.defaultColors.keys) {
      final name = _selectedColorNames[key];
      colors[key] = UserRatingPalette.namedColors[name] ??
          _palette.colors[key]!;
    }
    final excellent = (int.tryParse(_thresholdControllers['excellent']!.text) ?? 90)
        .clamp(0, 100)
        .toInt();
    final good = (int.tryParse(_thresholdControllers['good']!.text) ?? 75)
        .clamp(0, excellent)
        .toInt();
    final moderate = (int.tryParse(_thresholdControllers['moderate']!.text) ?? 60)
        .clamp(0, good)
        .toInt();
    final low = (int.tryParse(_thresholdControllers['low']!.text) ?? 50)
        .clamp(0, moderate)
        .toInt();
    final next = UserRatingPalette(
      excellentThreshold: excellent,
      goodThreshold: good,
      moderateThreshold: moderate,
      lowThreshold: low,
      colors: colors,
    );
    await UserMediaRatingStore.savePalette(
      AppController.instance.currentProfile?.id,
      next,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rating colors saved for this profile.')),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _reset() async {
    const defaults = UserRatingPalette();
    setState(() {
      _palette = defaults;
      for (final entry in defaults.colors.entries) {
        _selectedColorNames[entry.key] =
            UserRatingPalette.nameForColor(entry.value);
      }
      _thresholdControllers['excellent']?.text = '90';
      _thresholdControllers['good']?.text = '75';
      _thresholdControllers['moderate']?.text = '60';
      _thresholdControllers['low']?.text = '50';
    });
  }

  Widget _colorSwatch(int value, {double size = 20}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Color(value),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white54, width: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Personal Rating Colors')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text(
            'Choose a named color for each rating level. These colors represent your own profile rating, not external critic or audience scores. Ratings are shown as percentages and /10 scores.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Preview:', style: TextStyle(color: Colors.white60)),
              for (final score in const <int>[99, 85, 70, 55, 10])
                UserScoreBadge(score: score, palette: _palette),
            ],
          ),
          const SizedBox(height: 16),
          for (final entry in _labels.entries)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.value,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedColorNames[entry.key],
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Choose color',
                      ),
                      items: UserRatingPalette.namedColors.entries
                          .map((option) => DropdownMenuItem<String>(
                                value: option.key,
                                child: Row(
                                  children: [
                                    _colorSwatch(option.value),
                                    const SizedBox(width: 10),
                                    Text(option.key),
                                  ],
                                ),
                              ))
                          .toList(),
                      selectedItemBuilder: (context) =>
                          UserRatingPalette.namedColors.entries
                              .map((option) => Row(
                                    children: [
                                      _colorSwatch(option.value),
                                      const SizedBox(width: 10),
                                      Text(option.key),
                                    ],
                                  ))
                              .toList(),
                      onChanged: (value) {
                        if (value != null) _selectColor(entry.key, value);
                      },
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          const Text(
            'Custom score thresholds (0–100)',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in const <MapEntry<String, String>>[
                MapEntry('excellent', 'Excellent starts at'),
                MapEntry('good', 'Good starts at'),
                MapEntry('moderate', 'Moderate starts at'),
                MapEntry('low', 'Low starts at'),
              ])
                SizedBox(
                  width: 165,
                  child: TextField(
                    controller: _thresholdControllers[entry.key],
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: entry.value,
                      suffixText: '%',
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Thresholds are normalized to descending order when saved: excellent ≥ good ≥ moderate ≥ low.',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_rounded),
            label: const Text('Save colors'),
          ),
          TextButton(
            onPressed: _reset,
            child: const Text('Reset default colors'),
          ),
        ],
      ),
    );
  }
}
