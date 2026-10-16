// Privacy preferences are profile-scoped on this device. Sensitive presence and
// diagnostics behavior is enforced by the client API wrapper as well as UI.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class PrivacyPreferences {
  bool privateLibrary;
  bool sharePresence;
  bool shareActivity;
  bool personalizedRecommendations;
  bool sharePlaybackDiagnostics;
  bool allowOfflineMetadata;

  PrivacyPreferences({
    this.privateLibrary = true,
    this.sharePresence = true,
    this.shareActivity = true,
    this.personalizedRecommendations = true,
    this.sharePlaybackDiagnostics = false,
    this.allowOfflineMetadata = true,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'privateLibrary': privateLibrary,
        'sharePresence': sharePresence,
        'shareActivity': shareActivity,
        'personalizedRecommendations': personalizedRecommendations,
        'sharePlaybackDiagnostics': sharePlaybackDiagnostics,
        'allowOfflineMetadata': allowOfflineMetadata,
      };

  factory PrivacyPreferences.fromJson(Map<String, dynamic> json) => PrivacyPreferences(
        privateLibrary: json['privateLibrary'] != false,
        sharePresence: json['sharePresence'] != false,
        shareActivity: json['shareActivity'] != false,
        personalizedRecommendations: json['personalizedRecommendations'] != false,
        sharePlaybackDiagnostics: json['sharePlaybackDiagnostics'] == true,
        allowOfflineMetadata: json['allowOfflineMetadata'] != false,
      );
}

abstract final class PrivacyPreferencesStore {
  static final Map<String, PrivacyPreferences> _cache = <String, PrivacyPreferences>{};

  static String _normalizedProfileId(String? profileId) =>
      profileId == null || profileId.trim().isEmpty ? 'default' : profileId.trim();

  static String _key(String profileId) => 'mos_privacy_preferences_v1_$profileId';

  static PrivacyPreferences cached(String? profileId) =>
      _cache[_normalizedProfileId(profileId)] ?? PrivacyPreferences();

  static Future<PrivacyPreferences> load({String? profileId}) async {
    final id = _normalizedProfileId(profileId);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(id));
    PrivacyPreferences value;
    if (raw == null || raw.isEmpty) {
      value = PrivacyPreferences();
    } else {
      try {
        value = PrivacyPreferences.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
      } catch (_) {
        value = PrivacyPreferences();
      }
    }
    _cache[id] = value;
    return value;
  }

  static Future<void> save({required String? profileId, required PrivacyPreferences value}) async {
    final id = _normalizedProfileId(profileId);
    _cache[id] = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(id), jsonEncode(value.toJson()));
  }
}
