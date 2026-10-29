// FILE: lib/streaming_experience.dart
// Playback experience preferences, adaptive-stream URL player, and local QoE diagnostics.
//
// The playback URL must be an authorized/signed media-gateway URL. Never place a
// TrueNAS filesystem path or a Supabase service-role key in a client MediaItem.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'backend_api.dart';
import 'app_core.dart';
import 'localization.dart';
import 'app_accessibility.dart';
import 'privacy_preferences.dart';
import 'playback_interruption_bridge.dart';
import 'core/services/original_language_defaults.dart';
import 'energy_saver.dart';

class StreamingExperiencePreferences {
  static const int automaticResolution = 0;
  static const List<int> supportedResolutionCaps = <int>[
    0,
    480,
    720,
    1080,
    2160
  ];

  bool dataSaver;
  int maxResolution;
  /// Remembers the user's previous cap so Data Saver can be turned off
  /// without permanently overwriting their preferred streaming quality.
  int dataSaverPreviousResolution;
  bool autoplayNext;
  bool subtitlesEnabled;
  bool preferOriginalLanguageTracks;
  double subtitleScale;
  bool audioDescriptions;
  String preferredAudioLanguage;
  String preferredSubtitleLanguage;
  double playbackSpeed;
  bool skipKnownIntros;
  bool skipKnownCredits;
  bool highContrast;
  bool reduceMotion;
  double appTextScale;

  StreamingExperiencePreferences({
    this.dataSaver = false,
    this.maxResolution = automaticResolution,
    this.dataSaverPreviousResolution = automaticResolution,
    this.autoplayNext = true,
    this.subtitlesEnabled = true,
    this.preferOriginalLanguageTracks = true,
    this.subtitleScale = 1.0,
    this.audioDescriptions = false,
    this.preferredAudioLanguage = '',
    this.preferredSubtitleLanguage = '',
    this.playbackSpeed = 1.0,
    this.skipKnownIntros = false,
    this.skipKnownCredits = false,
    this.highContrast = false,
    this.reduceMotion = false,
    this.appTextScale = 1.0,
  });

  String get resolutionLabel => maxResolution == automaticResolution
      ? 'Automatic'
      : '${maxResolution}p maximum';

  /// Select a conservative playback profile while remembering the user's
  /// previous maximum. The backend must honor the requested cap for it to
  /// affect actual bitrate or transcoding.
  void enableDataSaver() {
    if (!dataSaver) dataSaverPreviousResolution = maxResolution;
    dataSaver = true;
    if (maxResolution == automaticResolution || maxResolution > 480) {
      maxResolution = 480;
    }
  }

  /// Restore the prior quality cap where the current cap is still the one
  /// that Data Saver selected. Manual quality choices are left untouched.
  void disableDataSaver() {
    dataSaver = false;
    if (maxResolution == 480) {
      maxResolution = dataSaverPreviousResolution;
    }
  }

  static String _key(String profileId) =>
      'mos_streaming_experience_${profileId.trim().isEmpty ? 'default' : profileId.trim()}';

  static String _supportedLanguage(dynamic value) {
    const supported = <String>{'', 'en', 'es', 'fr', 'de', 'it', 'pt', 'ja', 'ko', 'zh', 'hi', 'ru'};
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    return supported.contains(normalized) ? normalized : '';
  }

  static double _supportedPlaybackSpeed(dynamic value) {
    final speed = value is num ? value.toDouble() : 1.0;
    const allowed = <double>[0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    return allowed.contains(speed) ? speed : 1.0;
  }

  static Future<StreamingExperiencePreferences> load(
      {String? profileId}) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(profileId ?? 'default'));
    if (raw == null || raw.isEmpty) return StreamingExperiencePreferences();
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final resolution = (map['maxResolution'] as num?)?.toInt() ?? 0;
      final savedResolution =
          supportedResolutionCaps.contains(resolution) ? resolution : automaticResolution;
      final dataSaverEnabled = map['dataSaver'] == true;
      final rawPreviousResolution =
          (map['dataSaverPreviousResolution'] as num?)?.toInt();
      final previousResolution = supportedResolutionCaps.contains(rawPreviousResolution)
          ? rawPreviousResolution!
          : (dataSaverEnabled ? savedResolution : automaticResolution);
      final effectiveResolution = dataSaverEnabled &&
              (savedResolution == automaticResolution || savedResolution > 480)
          ? 480
          : savedResolution;
      final scale = (map['subtitleScale'] as num?)?.toDouble() ?? 1.0;
      return StreamingExperiencePreferences(
        dataSaver: dataSaverEnabled,
        maxResolution: effectiveResolution,
        dataSaverPreviousResolution: previousResolution,
        autoplayNext: map['autoplayNext'] != false,
        subtitlesEnabled: map['subtitlesEnabled'] != false,
        preferOriginalLanguageTracks: map['preferOriginalLanguageTracks'] != false,
        subtitleScale: scale.clamp(0.75, 2.0).toDouble(),
        audioDescriptions: map['audioDescriptions'] == true,
        preferredAudioLanguage: _supportedLanguage(map['preferredAudioLanguage']),
        preferredSubtitleLanguage: _supportedLanguage(map['preferredSubtitleLanguage']),
        playbackSpeed: _supportedPlaybackSpeed(map['playbackSpeed']),
        skipKnownIntros: map['skipKnownIntros'] == true,
        skipKnownCredits: map['skipKnownCredits'] == true,
        highContrast: map['highContrast'] == true,
        reduceMotion: map['reduceMotion'] == true,
        appTextScale: ((map['appTextScale'] as num?)?.toDouble() ?? 1.0)
            .clamp(0.85, 1.6)
            .toDouble(),
      );
    } catch (_) {
      return StreamingExperiencePreferences();
    }
  }

  Future<void> save({String? profileId}) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _key(profileId ?? 'default'),
      jsonEncode(<String, dynamic>{
        'dataSaver': dataSaver,
        'maxResolution': maxResolution,
        'dataSaverPreviousResolution': dataSaverPreviousResolution,
        'autoplayNext': autoplayNext,
        'subtitlesEnabled': subtitlesEnabled,
        'preferOriginalLanguageTracks': preferOriginalLanguageTracks,
        'subtitleScale': subtitleScale.clamp(0.75, 2.0),
        'audioDescriptions': audioDescriptions,
        'preferredAudioLanguage': _supportedLanguage(preferredAudioLanguage),
        'preferredSubtitleLanguage': _supportedLanguage(preferredSubtitleLanguage),
        'playbackSpeed': _supportedPlaybackSpeed(playbackSpeed),
        'skipKnownIntros': skipKnownIntros,
        'skipKnownCredits': skipKnownCredits,
        'highContrast': highContrast,
        'reduceMotion': reduceMotion,
        'appTextScale': appTextScale.clamp(0.85, 1.6),
      }),
    );
  }
}

/// Remembers exact audio/subtitle track labels per profile and media item.
/// A saved label is used only if that item still exposes the same track.
class PlaybackTrackSelectionStore {
  static String _key(String profileId, String mediaId) {
    String encoded(String value) => base64Url.encode(utf8.encode(value)).replaceAll('=', '');
    final profile = profileId.trim().isEmpty ? 'default' : profileId.trim();
    return 'mos_playback_track_selection_v1_${encoded(profile)}_${encoded(mediaId.trim())}';
  }

  static Future<Map<String, String>> load({required String profileId, required String mediaId}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(profileId, mediaId));
    if (raw == null || raw.isEmpty) return <String, String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, String>{};
      return <String, String>{
        for (final entry in decoded.entries)
          if (entry.value is String) entry.key.toString(): entry.value as String,
      };
    } catch (_) {
      return <String, String>{};
    }
  }

  static Future<void> save({required String profileId, required String mediaId, required String kind, required String value}) async {
    if (mediaId.trim().isEmpty || (kind != 'audio' && kind != 'subtitle')) return;
    final selections = await load(profileId: profileId, mediaId: mediaId);
    selections[kind] = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(profileId, mediaId), jsonEncode(selections));
  }
}

/// Device-local playback quality-of-experience events.
///
/// This intentionally avoids saving stream URLs, authorization tokens, IP
/// addresses, or free-text exception messages. The bounded local event log is
/// available for diagnostics before an authenticated server-side ingestion API
/// is enabled for cross-device reporting.
class PlaybackQoeTelemetry {
  static const String _storageKey = 'mos_playback_qoe_events_v1';
  static const int _maxEvents = 500;

  static Future<void> record({
    required String event,
    required String mediaId,
    required String sessionId,
    String? profileId,
    int? valueMs,
  }) async {
    try {
      final privacy = await PrivacyPreferencesStore.load(profileId: profileId);
      if (!privacy.sharePlaybackDiagnostics) return;
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      final events = <Map<String, dynamic>>[];
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded.whereType<Map>()) {
            events.add(Map<String, dynamic>.from(item));
          }
        }
      }
      events.add(<String, dynamic>{
        'event': event,
        'mediaId': mediaId,
        'sessionId': sessionId,
        if (profileId != null && profileId.isNotEmpty) 'profileId': profileId,
        if (valueMs != null) 'valueMs': valueMs < 0 ? 0 : valueMs,
        'occurredAt': DateTime.now().toUtc().toIso8601String(),
      });
      if (events.length > _maxEvents) {
        events.removeRange(0, events.length - _maxEvents);
      }
      await prefs.setString(_storageKey, jsonEncode(events));
    } catch (_) {
      // Diagnostics must never interrupt media playback.
    }
  }

  static Future<List<Map<String, dynamic>>> loadEvents(
      {String? profileId}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <Map<String, dynamic>>[];
      final all = decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
      if (profileId == null || profileId.isEmpty) return all;
      return all
          .where((item) => item['profileId'] == profileId)
          .toList(growable: false);
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  static Map<String, num> summarize(Iterable<Map<String, dynamic>> events) {
    var readyTotalMs = 0;
    var readyCount = 0;
    var bufferedTotalMs = 0;
    var failures = 0;
    var completed = 0;
    var watchTimeMs = 0;
    final sessions = <String>{};
    for (final item in events) {
      final sessionId = item['sessionId']?.toString();
      if (sessionId != null && sessionId.isNotEmpty) sessions.add(sessionId);
      final event = item['event']?.toString();
      final value = (item['valueMs'] as num?)?.toInt() ?? 0;
      if (event == 'player_ready') {
        readyTotalMs += value;
        readyCount++;
      } else if (event == 'buffer_end') {
        bufferedTotalMs += value;
      } else if (event == 'playback_error') {
        failures++;
      } else if (event == 'completed') {
        completed++;
      } else if (event == 'watch_time') {
        watchTimeMs += value < 0 ? 0 : value;
      }
    }
    return <String, num>{
      'sessions': sessions.length,
      'events': events.length,
      'averageReadyMs':
          readyCount == 0 ? 0 : (readyTotalMs / readyCount).round(),
      'bufferedMs': bufferedTotalMs,
      'failures': failures,
      'completed': completed,
      'watchTimeMs': watchTimeMs,
    };
  }

  static Future<void> clearEvents({String? profileId}) async {
    final prefs = await SharedPreferences.getInstance();
    if (profileId == null || profileId.isEmpty) {
      await prefs.remove(_storageKey);
      return;
    }
    final remaining = (await loadEvents())
        .where((item) => item['profileId'] != profileId)
        .toList();
    await prefs.setString(_storageKey, jsonEncode(remaining));
  }
}

class StreamingExperienceSettingsScreen extends StatefulWidget {
  const StreamingExperienceSettingsScreen({super.key});

  @override
  State<StreamingExperienceSettingsScreen> createState() =>
      _StreamingExperienceSettingsScreenState();
}

class _StreamingExperienceSettingsScreenState
    extends State<StreamingExperienceSettingsScreen> {
  StreamingExperiencePreferences settings = StreamingExperiencePreferences();
  List<Map<String, dynamic>> events = <Map<String, dynamic>>[];
  bool loading = true;
  bool saving = false;

  String? get _profileId => AppController.instance.currentProfile?.id;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final loaded =
        await StreamingExperiencePreferences.load(profileId: _profileId);
    final loadedEvents =
        await PlaybackQoeTelemetry.loadEvents(profileId: _profileId);
    if (!mounted) return;
    setState(() {
      settings = loaded;
      events = loadedEvents;
      loading = false;
    });
  }

  Future<void> _update(void Function() change) async {
    setState(() {
      change();
      saving = true;
    });
    await settings.save(profileId: _profileId);
    await AppAccessibilitySettings.instance.reload(profileId: _profileId);
    if (mounted) setState(() => saving = false);
  }

  Future<void> _setDataSaver(bool enabled) async {
    await _update(() {
      if (enabled) {
        // A local preference alone cannot re-encode media. Request a modest
        // 480p ceiling and let the authorized playback gateway enforce it
        // where the selected playback path supports resolution negotiation.
        settings.enableDataSaver();
      } else {
        settings.disableDataSaver();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final summary = PlaybackQoeTelemetry.summarize(events);
    final background =
        settings.highContrast ? Colors.black : const Color(0xFF09090D);
    final panel = settings.highContrast
        ? const Color(0xFF151515)
        : const Color(0xFF171720);
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const UniversalText('Streaming Experience'),
        backgroundColor: background,
        actions: [
          if (saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Center(
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionCard(
                  context,
                  panel,
                  title: 'Playback quality',
                  subtitle:
                      'Preferences are stored separately for the selected profile.',
                  children: [
                    SwitchListTile(
                      value: settings.dataSaver,
                      title: const UniversalText('Data saver'),
                      subtitle: const UniversalText(
                          'Requests a 480p ceiling and lower-bandwidth negotiation; the playback service must honor the cap.'),
                      onChanged: _setDataSaver,
                    ),
                    ListTile(
                      title:
                          const UniversalText('Maximum streaming resolution'),
                      subtitle: Text(settings.resolutionLabel),
                      trailing: DropdownButton<int>(
                        value: settings.maxResolution,
                        items: const <DropdownMenuItem<int>>[
                          DropdownMenuItem(value: 0, child: Text('Automatic')),
                          DropdownMenuItem(value: 480, child: Text('480p')),
                          DropdownMenuItem(value: 720, child: Text('720p')),
                          DropdownMenuItem(value: 1080, child: Text('1080p')),
                          DropdownMenuItem(value: 2160, child: Text('4K')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            _update(() {
                              settings.maxResolution = value;
                              if (settings.dataSaver && value != 480) {
                                settings.dataSaver = false;
                              }
                            });
                          }
                        },
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: UniversalText(
                          'Automatic uses the supplied adaptive HLS master playlist. A resolution cap or data-saver selection only changes the actual stream when the authorized playback service applies that preference to the manifest or transcode profile.'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  context,
                  panel,
                  title: 'Comfort and accessibility',
                  subtitle: 'Remembered for this profile on this device.',
                  children: [
                    SwitchListTile(
                      value: settings.autoplayNext,
                      title: const UniversalText('Autoplay next episode'),
                      subtitle: const UniversalText(
                          'Show the next-episode countdown when episode metadata is available.'),
                      onChanged: (value) =>
                          _update(() => settings.autoplayNext = value),
                    ),
                    SwitchListTile(
                      value: settings.subtitlesEnabled,
                      title: const UniversalText('Enable subtitles by default'),
                      onChanged: (value) =>
                          _update(() => settings.subtitlesEnabled = value),
                    ),
                    SwitchListTile(
                      value: settings.preferOriginalLanguageTracks,
                      title: const UniversalText(
                          'Prefer original-language audio and subtitles'),
                      subtitle: const UniversalText(
                          'Defaults to a track matching the title’s original language when that track is available. Examples: Korean for Parasite and Squid Game, Spanish for the listed Mexican animated films, and English for James Bond and Marvel titles. You can still choose another track.'),
                      onChanged: (value) => _update(
                          () => settings.preferOriginalLanguageTracks = value),
                    ),
                    ListTile(
                      title: const UniversalText('Subtitle text size'),
                      subtitle:
                          Text('${(settings.subtitleScale * 100).round()}%'),
                    ),
                    ListTile(
                      title: const UniversalText('App text size'),
                      subtitle:
                          Text('${(settings.appTextScale * 100).round()}%'),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Slider(
                        min: 0.85,
                        max: 1.6,
                        divisions: 15,
                        value:
                            settings.appTextScale.clamp(0.85, 1.6).toDouble(),
                        label: '${(settings.appTextScale * 100).round()}%',
                        onChanged: (value) =>
                            _update(() => settings.appTextScale = value),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Slider(
                        min: 0.75,
                        max: 2,
                        divisions: 5,
                        value:
                            settings.subtitleScale.clamp(0.75, 2.0).toDouble(),
                        label: '${(settings.subtitleScale * 100).round()}%',
                        onChanged: (value) =>
                            setState(() => settings.subtitleScale = value),
                        onChangeEnd: (_) =>
                            settings.save(profileId: _profileId),
                      ),
                    ),
                    SwitchListTile(
                      value: settings.audioDescriptions,
                      title: const UniversalText(
                          'Prefer audio description tracks'),
                      subtitle: const UniversalText(
                          'Used when the selected stream exposes an audio-description track.'),
                      onChanged: (value) =>
                          _update(() => settings.audioDescriptions = value),
                    ),
                    ListTile(
                      title: const UniversalText('Preferred audio language'),
                      subtitle: const UniversalText('Used when the chosen media exposes a matching audio track.'),
                      trailing: DropdownButton<String>(
                        value: settings.preferredAudioLanguage,
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(value: '', child: Text('Auto / original')),
                          DropdownMenuItem(value: 'en', child: Text('English')),
                          DropdownMenuItem(value: 'es', child: Text('Spanish')),
                          DropdownMenuItem(value: 'fr', child: Text('French')),
                          DropdownMenuItem(value: 'de', child: Text('German')),
                          DropdownMenuItem(value: 'it', child: Text('Italian')),
                          DropdownMenuItem(value: 'pt', child: Text('Portuguese')),
                          DropdownMenuItem(value: 'ja', child: Text('Japanese')),
                          DropdownMenuItem(value: 'ko', child: Text('Korean')),
                          DropdownMenuItem(value: 'zh', child: Text('Chinese')),
                          DropdownMenuItem(value: 'hi', child: Text('Hindi')),
                          DropdownMenuItem(value: 'ru', child: Text('Russian')),
                        ],
                        onChanged: (value) { if (value != null) _update(() => settings.preferredAudioLanguage = value); },
                      ),
                    ),
                    ListTile(
                      title: const UniversalText('Preferred subtitle language'),
                      subtitle: const UniversalText('Exact per-title subtitle choice is remembered when available; this language is the fallback.'),
                      trailing: DropdownButton<String>(
                        value: settings.preferredSubtitleLanguage,
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(value: '', child: Text('Auto / original')),
                          DropdownMenuItem(value: 'en', child: Text('English')),
                          DropdownMenuItem(value: 'es', child: Text('Spanish')),
                          DropdownMenuItem(value: 'fr', child: Text('French')),
                          DropdownMenuItem(value: 'de', child: Text('German')),
                          DropdownMenuItem(value: 'it', child: Text('Italian')),
                          DropdownMenuItem(value: 'pt', child: Text('Portuguese')),
                          DropdownMenuItem(value: 'ja', child: Text('Japanese')),
                          DropdownMenuItem(value: 'ko', child: Text('Korean')),
                          DropdownMenuItem(value: 'zh', child: Text('Chinese')),
                          DropdownMenuItem(value: 'hi', child: Text('Hindi')),
                          DropdownMenuItem(value: 'ru', child: Text('Russian')),
                        ],
                        onChanged: (value) { if (value != null) _update(() => settings.preferredSubtitleLanguage = value); },
                      ),
                    ),
                    ListTile(
                      title: const UniversalText('Playback speed'),
                      subtitle: const UniversalText('Applied to supported media-server streams.'),
                      trailing: DropdownButton<double>(
                        value: settings.playbackSpeed,
                        items: const <DropdownMenuItem<double>>[
                          DropdownMenuItem(value: 0.75, child: Text('0.75×')),
                          DropdownMenuItem(value: 1.0, child: Text('1.0×')),
                          DropdownMenuItem(value: 1.25, child: Text('1.25×')),
                          DropdownMenuItem(value: 1.5, child: Text('1.5×')),
                          DropdownMenuItem(value: 1.75, child: Text('1.75×')),
                          DropdownMenuItem(value: 2.0, child: Text('2.0×')),
                        ],
                        onChanged: (value) { if (value != null) _update(() => settings.playbackSpeed = value); },
                      ),
                    ),
                    SwitchListTile(
                      value: settings.skipKnownIntros,
                      title: const UniversalText('Skip known intros automatically'),
                      subtitle: const UniversalText('Only skips when the imported media has valid start and end markers.'),
                      onChanged: (value) => _update(() => settings.skipKnownIntros = value),
                    ),
                    SwitchListTile(
                      value: settings.skipKnownCredits,
                      title: const UniversalText('Skip known end credits automatically'),
                      subtitle: const UniversalText('Only skips near a recognized credit marker in the media metadata.'),
                      onChanged: (value) => _update(() => settings.skipKnownCredits = value),
                    ),
                    SwitchListTile(
                      value: settings.highContrast,
                      title: const UniversalText('High-contrast controls'),
                      onChanged: (value) =>
                          _update(() => settings.highContrast = value),
                    ),
                    SwitchListTile(
                      value: settings.reduceMotion,
                      title: const UniversalText('Reduce motion'),
                      onChanged: (value) =>
                          _update(() => settings.reduceMotion = value),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  context,
                  panel,
                  title: 'Playback diagnostics',
                  subtitle:
                      'Recent diagnostics from this device and profile only.',
                  children: [
                    _metricRow('Playback sessions', '${summary['sessions']}'),
                    _metricRow('Average time to player ready',
                        _formatMs(summary['averageReadyMs'] ?? 0)),
                    _metricRow('Time spent buffering',
                        _formatMs(summary['bufferedMs'] ?? 0)),
                    _metricRow('Playback errors', '${summary['failures']}'),
                    _metricRow('Completed sessions', '${summary['completed']}'),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                              child: Text(
                                  '${summary['events']} diagnostic events kept locally (maximum 500).',
                                  style:
                                      const TextStyle(color: Colors.white60))),
                          TextButton.icon(
                            onPressed: events.isEmpty
                                ? null
                                : () async {
                                    await PlaybackQoeTelemetry.clearEvents(
                                        profileId: _profileId);
                                    await _load();
                                  },
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: const UniversalText('Clear'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const UniversalText(
                    'Playback diagnostics currently remain on this device. Cross-device QoE reporting requires deploying the trusted-backend ingestion described in docs/STREAMING_EXPERIENCE_IMPLEMENTATION.md.',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
    );
  }

  Widget _sectionCard(BuildContext context, Color panel,
      {required String title,
      required String subtitle,
      required List<Widget> children}) {
    return Card(
      color: panel,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
            color: settings.highContrast ? Colors.white54 : Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: const TextStyle(color: Colors.white60, fontSize: 12)),
            ]),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _metricRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          Expanded(child: Text(label)),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontFeatures: <FontFeature>[FontFeature.tabularFigures()]))
        ]),
      );

  static String _formatMs(num value) {
    final seconds = (value / 1000).round();
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (minutes < 60) return '${minutes}m ${remainingSeconds}s';
    return '${minutes ~/ 60}h ${minutes % 60}m';
  }
}

class AdaptiveStreamingPlayer extends StatefulWidget {
  final MediaItem media;
  final String? activityLabel;
  final int? initialPositionSeconds;

  const AdaptiveStreamingPlayer({
    super.key,
    required this.media,
    this.activityLabel,
    this.initialPositionSeconds,
  });

  @override
  State<AdaptiveStreamingPlayer> createState() =>
      _AdaptiveStreamingPlayerState();
}

class _AdaptiveStreamingPlayerState extends State<AdaptiveStreamingPlayer> {
  VideoPlayerController? _controller;
  Timer? _syncTimer;
  DateTime? _bufferStartedAt;
  DateTime? _lastProgressSync;
  DateTime? _lastUiUpdate;
  DateTime? _lastSegmentScanAt;
  late final String _sessionId;
  DateTime? _startedAt;
  bool _readyLogged = false;
  bool _errorLogged = false;
  bool _completedLogged = false;
  bool _wasBuffering = false;
  DateTime? _lastPlaybackWallSample;
  int _unreportedWatchMs = 0;
  bool _skipCheckRunning = false;
  final Set<String> _autoSkippedMarkers = <String>{};
  double? _sliderPreviewSeconds;
  bool _loading = true;
  String? _error;
  String? _backendSessionId;
  StreamingExperiencePreferences _preferences =
      StreamingExperiencePreferences();
  String? get _profileId => AppController.instance.currentProfile?.id;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _sessionId = '${widget.media.id}_${DateTime.now().microsecondsSinceEpoch}';
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    await EnergySaverController.instance.ensureLoaded(profileId: _profileId);
    _preferences =
        await StreamingExperiencePreferences.load(profileId: _profileId);
    if (!mounted) return;
    final rawUrl = widget.media.playbackUrl?.trim() ?? '';
    final uri = Uri.tryParse(rawUrl);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        !(uri.scheme == 'https' || uri.scheme == 'http')) {
      setState(() {
        _loading = false;
        _error =
            'The media gateway did not provide a valid HTTP(S) playback URL.';
      });
      await _record('playback_error');
      return;
    }

    await _record('play_requested');
    try {
      final api = AppController.instance.backendApi;
      final apiUri = api.baseUri;
      final apiPathPrefix = apiUri.path.endsWith('/')
          ? apiUri.path
          : '${apiUri.path}/';
      final isAuthenticatedBackendUrl = uri.scheme == apiUri.scheme &&
          uri.host == apiUri.host &&
          uri.port == apiUri.port &&
          (uri.path == apiUri.path || uri.path.startsWith(apiPathPrefix));
      final token = isAuthenticatedBackendUrl ? api.token : null;
      final player = VideoPlayerController.networkUrl(
        uri,
        httpHeaders: token == null || token.isEmpty
            ? const <String, String>{}
            : <String, String>{'Authorization': 'Bearer $token'},
      );
      _controller = player;
      player.addListener(_onPlayerChanged);
      await player.initialize();
      await player.setPlaybackSpeed(_preferences.playbackSpeed);
      if (!mounted) return;
      PlaybackInterruptionBridge.attach(
        owner: this,
        title: widget.media.title,
        pause: () {
          unawaited(player.pause());
          unawaited(_syncBackendSession(state: 'paused'));
        },
        resume: () {
          unawaited(player.play());
          unawaited(_syncBackendSession(state: 'playing'));
        },
        savePosition: () {
          final duration = player.value.duration;
          if (duration > Duration.zero) {
            final normalized = (player.value.position.inMilliseconds /
                    duration.inMilliseconds)
                .clamp(0.0, 1.0)
                .toDouble();
            AppController.instance
                .updatePlaybackProgress(widget.media.id, normalized);
          }
          unawaited(_syncBackendSession());
        },
      );
      if (widget.initialPositionSeconds != null &&
          player.value.duration > Duration.zero) {
        final seconds = widget.initialPositionSeconds!
            .clamp(0, player.value.duration.inSeconds)
            .toInt();
        final offset = Duration(seconds: seconds);
        if (offset < player.value.duration) await player.seekTo(offset);
      } else {
        final resume = AppController.instance.getPlaybackProgress(widget.media.id);
        if (resume > 0 && player.value.duration > Duration.zero) {
          final offset = Duration(
              milliseconds:
                  (player.value.duration.inMilliseconds * resume).round());
          if (offset < player.value.duration) await player.seekTo(offset);
        }
      }
      setState(() => _loading = false);
      unawaited(player.play());
      await _createBackendSession();
      if (!mounted) return;
      final energy = EnergySaverController.instance;
      _syncTimer = Timer.periodic(energy.playbackSessionSyncInterval, (_) {
        // Playback controls still send immediate state changes. Periodic
        // heartbeats are unnecessary while paused, buffering, or hidden.
        final activePlayer = _controller;
        if (activePlayer == null ||
            !activePlayer.value.isPlaying ||
            activePlayer.value.isBuffering) {
          return;
        }
        if (energy.pauseWhenAppHidden && !energy.appIsForeground) {
          energy.recordBackgroundTaskSkipped();
          return;
        }
        unawaited(_syncBackendSession());
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'Unable to start this stream. Check the playback gateway, network access, and device protocol support.';
      });
      if (!_errorLogged) {
        _errorLogged = true;
        await _record('playback_error');
      }
    }
  }

  num? _markerSeconds(Map<String, dynamic> marker, List<String> aliases) {
    for (final key in aliases) {
      final value = marker[key];
      if (value is num) {
        final n = value.toDouble();
        if (key.toLowerCase().contains('ms') || key.toLowerCase().contains('millisecond')) return n / 1000;
        return n;
      }
      final text = value?.toString().trim() ?? '';
      if (text.isEmpty) continue;
      final number = double.tryParse(text);
      if (number != null) {
        if (key.toLowerCase().contains('ms') || key.toLowerCase().contains('millisecond')) return number / 1000;
        return number;
      }
      final parts = text.split(':');
      if (parts.length == 2 || parts.length == 3) {
        final parsed = parts.map((part) => double.tryParse(part)).toList();
        if (parsed.every((part) => part != null)) {
          if (parts.length == 2) return parsed[0]! * 60 + parsed[1]!;
          return parsed[0]! * 3600 + parsed[1]! * 60 + parsed[2]!;
        }
      }
    }
    return null;
  }

  Future<void> _maybeSkipKnownSegments(VideoPlayerController player) async {
    if (_skipCheckRunning || !player.value.isInitialized || !player.value.isPlaying || player.value.isBuffering) return;
    final position = player.value.position.inMilliseconds / 1000.0;
    final duration = player.value.duration.inSeconds.toDouble();
    if (duration <= 0) return;
    double? target;
    String? markerId;
    if (_preferences.skipKnownIntros) {
      for (var i = 0; i < widget.media.tvIntros.length; i++) {
        final marker = widget.media.tvIntros[i];
        final start = _markerSeconds(marker, const ['startSeconds', 'start_seconds', 'introStartSeconds', 'startTimeSeconds', 'start', 'startMs', 'startMilliseconds', 'start_ms']);
        final end = _markerSeconds(marker, const ['endSeconds', 'end_seconds', 'introEndSeconds', 'endTimeSeconds', 'end', 'endMs', 'endMilliseconds', 'end_ms']);
        final id = 'intro:$i:${end ?? -1}';
        if (start == null || end == null || end <= start || _autoSkippedMarkers.contains(id)) continue;
        if (position >= start && position < end && end < duration - 1) {
          target = (end + 0.2).toDouble();
          markerId = id;
          break;
        }
      }
    }
    if (target == null && _preferences.skipKnownCredits) {
      for (var i = 0; i < widget.media.xrayEvents.length; i++) {
        final marker = widget.media.xrayEvents[i];
        final label = <String>[marker['type'], marker['title'], marker['label'], marker['name'], marker['event']]
            .whereType<Object>()
            .map((value) => value.toString().toLowerCase())
            .join(' ');
        if (!label.contains('credit')) continue;
        final start = _markerSeconds(marker, const ['startSeconds', 'start_seconds', 'timeSeconds', 'timestampSeconds', 'time', 'start', 'startMs', 'startMilliseconds']);
        final id = 'credits:$i:${start ?? -1}';
        if (start == null || _autoSkippedMarkers.contains(id)) continue;
        if (position >= start - 1 && position <= start + 2 && start < duration - 10) {
          target = duration - 1;
          markerId = id;
          break;
        }
      }
    }
    if (target == null || markerId == null) return;
    _skipCheckRunning = true;
    _autoSkippedMarkers.add(markerId);
    try {
      await player.seekTo(Duration(milliseconds: (target * 1000).round()));
      await _record(markerId.startsWith('intro:') ? 'intro_skipped' : 'credits_skipped');
    } catch (_) {
      _autoSkippedMarkers.remove(markerId);
    } finally {
      _skipCheckRunning = false;
    }
  }

  void _trackWatchTime(VideoPlayerValue value) {
    final now = DateTime.now();
    if (!value.isPlaying || value.isBuffering) {
      _lastPlaybackWallSample = null;
      return;
    }
    final last = _lastPlaybackWallSample;
    _lastPlaybackWallSample = now;
    if (last == null) return;
    final elapsed = now.difference(last).inMilliseconds;
    // Avoid counting long UI stalls as real viewing time.
    if (elapsed > 0 && elapsed <= 2500) _unreportedWatchMs += elapsed;
    if (_unreportedWatchMs >=
        EnergySaverController.instance.watchTimeBatchInterval.inMilliseconds) {
      final report = _unreportedWatchMs;
      _unreportedWatchMs = 0;
      unawaited(_record('watch_time', valueMs: report));
    }
  }

  void _flushWatchTime() {
    if (_unreportedWatchMs <= 0) return;
    final report = _unreportedWatchMs;
    _unreportedWatchMs = 0;
    unawaited(_record('watch_time', valueMs: report));
  }

  void _onPlayerChanged() {
    final player = _controller;
    if (player == null || !player.value.isInitialized) return;
    final value = player.value;
    _trackWatchTime(value);
    if (value.isPlaying && !value.isBuffering) {
      final now = DateTime.now();
      if (_lastSegmentScanAt == null ||
          now.difference(_lastSegmentScanAt!) >=
              EnergySaverController.instance.playbackMarkerScanInterval) {
        _lastSegmentScanAt = now;
        unawaited(_maybeSkipKnownSegments(player));
      }
    }
    if (!_readyLogged) {
      _readyLogged = true;
      final elapsed = DateTime.now()
          .difference(_startedAt ?? DateTime.now())
          .inMilliseconds;
      unawaited(_record('player_ready', valueMs: elapsed));
    }
    if (value.isBuffering && !_wasBuffering) {
      _wasBuffering = true;
      _bufferStartedAt = DateTime.now();
      unawaited(_record('buffer_start'));
    } else if (!value.isBuffering && _wasBuffering) {
      _wasBuffering = false;
      final started = _bufferStartedAt;
      _bufferStartedAt = null;
      unawaited(_record('buffer_end',
          valueMs: started == null
              ? 0
              : DateTime.now().difference(started).inMilliseconds));
    }
    if (value.hasError && !_errorLogged) {
      _errorLogged = true;
      unawaited(_record('playback_error'));
    }
    if (value.duration > Duration.zero &&
        value.position >= value.duration - const Duration(milliseconds: 500) &&
        !_completedLogged) {
      _completedLogged = true;
      unawaited(_record('completed'));
      AppController.instance.updatePlaybackProgress(widget.media.id, 1.0);
      AppController.instance.markWatched(widget.media);
      unawaited(_syncBackendSession(state: 'completed'));
    } else if (value.duration > Duration.zero) {
      final normalized =
          (value.position.inMilliseconds / value.duration.inMilliseconds)
              .clamp(0.0, 1.0)
              .toDouble();
      final now = DateTime.now();
      if (_lastProgressSync == null ||
          now.difference(_lastProgressSync!) >=
              EnergySaverController.instance.playbackProgressSaveInterval) {
        _lastProgressSync = now;
        // Keep Continue Watching progress locally, while the separate heartbeat
        // sends backend updates at the selected Eco/Balanced/Cinema cadence.
        AppController.instance
            .updatePlaybackProgress(widget.media.id, normalized);
      }
    }
    final now = DateTime.now();
    if (mounted &&
        (_lastUiUpdate == null ||
            now.difference(_lastUiUpdate!) >=
                EnergySaverController.instance.playbackUiRefreshInterval)) {
      _lastUiUpdate = now;
      setState(() {});
    }
  }

  Future<void> _createBackendSession() async {
    final profile = AppController.instance.currentProfile;
    final api = AppController.instance.backendApi;
    if (profile == null || !api.isAuthenticated) return;
    try {
      final deviceId = await AppController.instance.ensureDeviceId();
      final result = await api.createPlaybackSession(
        profileId: profile.id,
        deviceId: deviceId,
        mediaId: widget.media.id,
        state: 'playing',
        positionSeconds: _controller?.value.position.inSeconds.toDouble() ?? 0,
      );
      final session = result['session'];
      if (session is Map) _backendSessionId = session['id']?.toString();
    } catch (_) {
      // Local playback is allowed when optional analytics is offline.
    }
  }

  Future<void> _syncBackendSession({String? state}) async {
    final id = _backendSessionId;
    if (id == null || id.isEmpty) return;
    final player = _controller;
    if (player == null || !player.value.isInitialized) return;
    try {
      await AppController.instance.backendApi.updatePlaybackSession(
        sessionId: id,
        mediaId: widget.media.id,
        state: state ?? (player.value.isPlaying ? 'playing' : 'paused'),
        positionSeconds: player.value.position.inSeconds.toDouble(),
      );
    } catch (_) {}
  }

  Future<void> _record(String event, {int? valueMs}) =>
      PlaybackQoeTelemetry.record(
        event: event,
        mediaId: widget.media.id,
        sessionId: _sessionId,
        profileId: _profileId,
        valueMs: valueMs,
      );

  Future<void> _seekTo(double seconds) async {
    final player = _controller;
    if (player == null || !player.value.isInitialized) return;
    final target = Duration(milliseconds: (seconds * 1000).round());
    await player.seekTo(target);
    unawaited(_record('seek', valueMs: target.inMilliseconds));
    unawaited(_syncBackendSession());
  }

  @override
  void dispose() {
    PlaybackInterruptionBridge.detach(this);
    _syncTimer?.cancel();
    _flushWatchTime();
    final player = _controller;
    if (_wasBuffering && _bufferStartedAt != null) {
      unawaited(_record('buffer_end',
          valueMs:
              DateTime.now().difference(_bufferStartedAt!).inMilliseconds));
    }
    if (player != null) {
      if (player.value.isInitialized && player.value.duration > Duration.zero) {
        AppController.instance.updatePlaybackProgress(
          widget.media.id,
          (player.value.position.inMilliseconds /
                  player.value.duration.inMilliseconds)
              .clamp(0.0, 1.0)
              .toDouble(),
        );
      }
      unawaited(_syncBackendSession(state: 'stopped'));
      player.removeListener(_onPlayerChanged);
      unawaited(player.dispose());
    }
    super.dispose();
  }

  String _time(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0
        ? '$hours:$minutes:$seconds'
        : '${duration.inMinutes}:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final player = _controller;
    final highContrast = _preferences.highContrast;
    final accent = highContrast ? Colors.white : const Color(0xFF8D6BFF);
    final value = player?.value;
    final duration = value?.duration ?? Duration.zero;
    final position = value?.position ?? Duration.zero;
    final preferredOriginalLanguage = _preferences.preferOriginalLanguageTracks
        ? OriginalLanguageDefaults.resolveForMedia(widget.media)
        : null;
    final maxSeconds =
        duration.inSeconds > 0 ? duration.inSeconds.toDouble() : 1.0;
    final currentSeconds = _sliderPreviewSeconds ??
        position.inSeconds.clamp(0, maxSeconds.toInt()).toDouble();
    return Scaffold(
      backgroundColor: highContrast ? Colors.black : const Color(0xFF08080C),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.media.title,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
                child: Text(
                    _preferences.maxResolution == 0
                        ? 'Adaptive'
                        : 'Up to ${_preferences.maxResolution}p',
                    style:
                        const TextStyle(color: Colors.white60, fontSize: 12))),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AspectRatio(
                aspectRatio: value?.isInitialized == true &&
                        (value?.aspectRatio ?? 0) > 0
                    ? value!.aspectRatio
                    : 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ColoredBox(
                    color: Colors.black,
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _error != null ||
                                player == null ||
                                value?.isInitialized != true
                            ? Center(
                                child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Text(
                                        _error ??
                                            value?.errorDescription ??
                                            'Stream not ready.',
                                        textAlign: TextAlign.center)))
                            : Stack(
                                alignment: Alignment.center,
                                children: [
                                  VideoPlayer(player),
                                  if (value?.isBuffering == true)
                                    const CircularProgressIndicator(),
                                  IconButton.filledTonal(
                                    iconSize: 52,
                                    onPressed: () async {
                                      if (player.value.isPlaying) {
                                        await player.pause();
                                        unawaited(_record('paused'));
                                        unawaited(_syncBackendSession(
                                            state: 'paused'));
                                      } else {
                                        await player.play();
                                        unawaited(_record('resumed'));
                                        unawaited(_syncBackendSession(
                                            state: 'playing'));
                                      }
                                    },
                                    icon: Icon(value?.isPlaying == true
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded),
                                  ),
                                ],
                              ),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    final navigator = Navigator.of(context);
                    navigator.pop();
                  },
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const UniversalText('Back to details'),
                ),
              ],
              if (player != null && value?.isInitialized == true) ...[
                const SizedBox(height: 14),
                SliderTheme(
                  data: SliderTheme.of(context)
                      .copyWith(activeTrackColor: accent, thumbColor: accent),
                  child: Slider(
                    min: 0,
                    max: maxSeconds,
                    value: currentSeconds.clamp(0, maxSeconds).toDouble(),
                    onChanged: (seconds) =>
                        setState(() => _sliderPreviewSeconds = seconds),
                    onChangeEnd: (seconds) {
                      setState(() => _sliderPreviewSeconds = null);
                      unawaited(_seekTo(seconds));
                    },
                  ),
                ),
                Row(
                  children: [
                    Text(_time(position),
                        style: const TextStyle(color: Colors.white70)),
                    const Spacer(),
                    Text(_time(duration),
                        style: const TextStyle(color: Colors.white70))
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.speed_rounded,
                        size: 18, color: Colors.white70),
                    const SizedBox(width: 8),
                    const UniversalText('Playback speed'),
                    const Spacer(),
                    DropdownButton<double>(
                      value: const <double>[0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
                              .contains(value?.playbackSpeed ?? 1.0)
                          ? value?.playbackSpeed ?? 1.0
                          : 1.0,
                      dropdownColor: const Color(0xFF1B1B1B),
                      items: const <DropdownMenuItem<double>>[
                        DropdownMenuItem(value: 0.75, child: Text('0.75×')),
                        DropdownMenuItem(value: 1.0, child: Text('1×')),
                        DropdownMenuItem(value: 1.25, child: Text('1.25×')),
                        DropdownMenuItem(value: 1.5, child: Text('1.5×')),
                        DropdownMenuItem(value: 1.75, child: Text('1.75×')),
                        DropdownMenuItem(value: 2.0, child: Text('2×')),
                      ],
                      onChanged: (speed) {
                        if (speed == null) return;
                        unawaited(player.setPlaybackSpeed(speed));
                        _preferences.playbackSpeed = speed;
                        unawaited(_preferences.save(profileId: _profileId));
                        unawaited(_record('speed_change',
                            valueMs: (speed * 1000).round()));
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(widget.activityLabel ?? 'Playing ${widget.media.title}',
                    style: const TextStyle(color: Colors.white60)),
                if (preferredOriginalLanguage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.translate_rounded,
                            size: 17, color: Colors.white60),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Preferred original language: ${OriginalLanguageDefaults.displayName(preferredOriginalLanguage)}. The playback source must support track selection to apply it to an adaptive stream.',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_preferences.dataSaver)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: UniversalText(
                        'Data saver is selected. The stream gateway must honor this preference for bitrate to be reduced.',
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
