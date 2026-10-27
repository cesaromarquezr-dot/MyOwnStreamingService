import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Profile-scoped choices for a media item's poster, Home hero backdrop and
/// trailer selection. Image files continue to be served by their providers;
/// the app persists stable provider paths rather than duplicating copyrighted
/// artwork in its own storage.
class ArtworkSelectionStore {
  ArtworkSelectionStore._();

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static String _token(String value) =>
      base64Url.encode(utf8.encode(value)).replaceAll('=', '');

  static String _key(String slot, String profileId, String mediaId) =>
      'moss_art_${slot}_${_token(profileId.isEmpty ? 'guest' : profileId)}_${_token(mediaId)}';

  static Future<String?> readPosterPath({
    required String profileId,
    required String mediaId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key('poster', profileId, mediaId))?.trim();
    if (value != null && value.isNotEmpty) return value;
    // Artwork chosen from the profile-selection screen may be saved before a
    // profile is active. Treat that choice as the shared fallback while still
    // preferring a profile-specific override whenever one exists.
    if (profileId != 'guest') {
      final shared = prefs.getString(_key('poster', 'guest', mediaId))?.trim();
      if (shared != null && shared.isNotEmpty) return shared;
    }
    return null;
  }

  static Future<String?> readBackdropPath({
    required String profileId,
    required String mediaId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key('backdrop', profileId, mediaId))?.trim();
    if (value != null && value.isNotEmpty) return value;
    // Shared selection-picker artwork is the default for profiles that have
    // not set their own backdrop.
    if (profileId != 'guest') {
      final shared = prefs.getString(_key('backdrop', 'guest', mediaId))?.trim();
      if (shared != null && shared.isNotEmpty) return shared;
    }
    return null;
  }

  static Future<void> setPosterPath({
    required String profileId,
    required String mediaId,
    required String path,
  }) async {
    final clean = path.trim();
    if (clean.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key('poster', profileId, mediaId), clean);
    revision.value++;
  }

  static Future<void> setBackdropPath({
    required String profileId,
    required String mediaId,
    required String path,
  }) async {
    final clean = path.trim();
    if (clean.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key('backdrop', profileId, mediaId), clean);
    revision.value++;
  }
}
