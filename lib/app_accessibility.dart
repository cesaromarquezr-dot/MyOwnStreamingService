import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'privacy_preferences.dart';

/// Root-level accessibility preferences backed by the same per-profile storage
/// key as StreamingExperiencePreferences.
class AppAccessibilitySettings extends ChangeNotifier {
  AppAccessibilitySettings._();
  static final AppAccessibilitySettings instance = AppAccessibilitySettings._();

  String? _profileId;
  String? _loadingProfileId;
  bool highContrast = false;
  bool reduceMotion = false;
  double appTextScale = 1.0;

  String _normalize(String? profileId) => profileId == null || profileId.trim().isEmpty ? 'default' : profileId.trim();

  void ensureLoaded({String? profileId}) {
    final id = _normalize(profileId);
    if (_profileId == id || _loadingProfileId == id) return;
    _loadingProfileId = id;
    unawaited(reload(profileId: id));
  }

  Future<void> reload({String? profileId}) async {
    final id = _normalize(profileId);
    _loadingProfileId = id;
    try {
      await PrivacyPreferencesStore.load(profileId: id);
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('mos_streaming_experience_$id');
      Map<String, dynamic> values = <String, dynamic>{};
      if (raw != null && raw.isNotEmpty) {
        try { values = Map<String, dynamic>.from(jsonDecode(raw) as Map); } catch (_) {}
      }
      highContrast = values['highContrast'] == true;
      reduceMotion = values['reduceMotion'] == true;
      appTextScale = ((values['appTextScale'] as num?)?.toDouble() ?? 1.0).clamp(0.85, 1.6).toDouble();
      _profileId = id;
    } catch (_) {
      highContrast = false;
      reduceMotion = false;
      appTextScale = 1.0;
      _profileId = id;
    } finally {
      if (_loadingProfileId == id) _loadingProfileId = null;
      notifyListeners();
    }
  }
}
