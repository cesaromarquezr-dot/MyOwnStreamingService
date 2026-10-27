// FILE: `lib/xray.dart`.
// Purpose: Provides an X-Ray-style cast and production overlay for playback.
// Uses exact title metadata and person portraits where configured; the player
// contract stays independent of provider credentials and scene-level curation.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'backend_api.dart';
import 'app_core.dart';
import 'localization.dart';
import 'media_text_localizer.dart';
import 'core/services/cinematic_person_metadata_service.dart';
import 'core/services/cinematic_title_metadata_service.dart';

/// X-Ray screen showing cast, directors, music and other context for a title.
class XRayScreen extends StatefulWidget {
  final MediaItem media;
  final ValueListenable<Duration> playbackPosition;

  const XRayScreen({
    super.key,
    required this.media,
    required this.playbackPosition,
  });

  @override
  State<XRayScreen> createState() => _XRayScreenState();
}

enum SpoilerProtectionLevel {
  noSpoilers,
  currentScene,
  currentMovie,
  franchise,
  everything
}

class _XRayScreenState extends State<XRayScreen> {
  SpoilerProtectionLevel _spoilerLevel = SpoilerProtectionLevel.currentScene;
  final Set<String> _followedEntities = <String>{};
  final Set<String> _visibleSections = <String>{
    'People',
    'Characters',
    'Music',
    'Locations',
    'Trivia',
    'Production',
    'Connections',
  };
  List<Map<String, dynamic>> _privateNotes = <Map<String, dynamic>>[];
  List<_CastEntry> _providerCast = <_CastEntry>[];
  List<CinematicCrewCredit> _providerCrew = <CinematicCrewCredit>[];
  bool _loadingProviderCast = false;
  bool? _showFullCast;

  MediaItem get media => widget.media;
  ValueListenable<Duration> get playbackPosition => widget.playbackPosition;
  String get _profileKey =>
      AppController.instance.currentProfile?.id ?? 'default';

  String get _followsKey => 'xray_followed_entities_$_profileKey';
  String get _sectionsKey => 'xray_visible_sections_$_profileKey';
  String get _spoilerKey => 'xray_spoiler_level_$_profileKey';
  String get _notesKey =>
      'xray_private_notes_${_profileKey}_${media.id}_${media.mediaVersionId ?? 'unversioned'}';

  @override
  void initState() {
    super.initState();
    _loadPersonalSettings();
    _loadProviderCast();
  }

  Future<void> _loadProviderCast() async {
    if (!CinematicTitleMetadataService.isConfigured ||
        media.title.trim().isEmpty ||
        media.type.toLowerCase().contains('album') ||
        media.type.toLowerCase().contains('music')) {
      return;
    }
    if (mounted) setState(() => _loadingProviderCast = true);
    try {
      final metadata = await CinematicTitleMetadataService.lookupTitle(
        title: media.title,
        isTv: media.isSeries,
        year: media.releaseYear ?? media.seriesStartYear,
      );
      if (!mounted || metadata == null) return;
      final entries = metadata.castCredits
          .map((credit) => _CastEntry(
                actor: credit.name,
                character:
                    credit.character.trim().toLowerCase() == 'featured cast'
                        ? ''
                        : credit.character,
                photoUrl: CinematicPersonMetadataService.imageUrl(
                  credit.profilePath,
                  size: 'w185',
                ),
                personId: credit.personId,
              ))
          .where((entry) => entry.actor.trim().isNotEmpty)
          .toList(growable: false);
      setState(() {
        _providerCast = entries;
        _providerCrew = metadata.crewCredits;
      });
    } catch (_) {
      // The imported catalog remains usable when provider metadata is offline.
    } finally {
      if (mounted) setState(() => _loadingProviderCast = false);
    }
  }

  Future<void> _loadPersonalSettings() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _followedEntities
          ..clear()
          ..addAll(preferences.getStringList(_followsKey) ?? const []);
        final savedSpoilerLevel = preferences.getString(_spoilerKey);
        _spoilerLevel = SpoilerProtectionLevel.values.firstWhere(
          (level) => level.name == savedSpoilerLevel,
          orElse: () => SpoilerProtectionLevel.currentScene,
        );
        final savedSections = preferences.getStringList(_sectionsKey);
        if (savedSections != null) {
          _visibleSections
            ..clear()
            ..addAll(savedSections);
        }
        final notesJson = preferences.getString(_notesKey);
        if (notesJson != null) {
          final decoded = jsonDecode(notesJson);
          if (decoded is List) {
            _privateNotes = decoded
                .whereType<Map>()
                .map((note) => Map<String, dynamic>.from(note))
                .toList();
          }
        }
      });
    } catch (_) {
      // X-Ray personalization is optional; metadata remains usable offline.
    }
    await _loadRemoteProfileData();
  }

  Future<void> _loadRemoteProfileData() async {
    final app = AppController.instance;
    final profileId = app.currentProfile?.id;
    if (!app.backendApi.isAuthenticated || profileId == null) return;
    try {
      final records = await app.backendApi.getAppRecords(
        profileId: profileId,
        recordType: 'xray_profile_settings',
      );
      final savedRecords = records
          .where((record) => record['recordKey'] == 'settings')
          .map((record) => record['data'])
          .whereType<Map>()
          .map((value) => Map<String, dynamic>.from(value))
          .toList();
      final saved = savedRecords.isEmpty ? null : savedRecords.first;
      if (saved != null && mounted) {
        setState(() {
          final spoiler = saved['spoilerLevel']?.toString();
          _spoilerLevel = SpoilerProtectionLevel.values.firstWhere(
            (level) => level.name == spoiler,
            orElse: () => _spoilerLevel,
          );
          if (saved['visibleSections'] is List) {
            _visibleSections
              ..clear()
              ..addAll((saved['visibleSections'] as List)
                  .map((value) => value.toString()));
          }
          if (saved['followedEntities'] is List) {
            _followedEntities
              ..clear()
              ..addAll((saved['followedEntities'] as List)
                  .map((value) => value.toString()));
          }
        });
      }
      final noteRecords = await app.backendApi.getAppRecords(
        profileId: profileId,
        recordType: 'xray_private_note',
      );
      final remoteNotes = noteRecords
          .map((record) => record['data'])
          .whereType<Map>()
          .map((value) => Map<String, dynamic>.from(value))
          .where((note) =>
              note['mediaId'] == media.id &&
              note['mediaVersionId'] == media.mediaVersionId)
          .toList();
      if (remoteNotes.isNotEmpty && mounted) {
        final merged = <String, Map<String, dynamic>>{
          for (final note in _privateNotes) note['id'].toString(): note,
          for (final note in remoteNotes) note['id'].toString(): note,
        };
        setState(() => _privateNotes = merged.values.toList()
          ..sort((a, b) => '${b['createdAt']}'.compareTo('${a['createdAt']}')));
      }
    } catch (_) {
      // Device preferences remain the offline source of truth until sync works.
    }
  }

  Future<void> _saveRemoteSettings() async {
    final app = AppController.instance;
    final profileId = app.currentProfile?.id;
    if (!app.backendApi.isAuthenticated || profileId == null) return;
    try {
      await app.backendApi.saveAppRecord(
        profileId: profileId,
        recordType: 'xray_profile_settings',
        recordKey: 'settings',
        data: {
          'spoilerLevel': _spoilerLevel.name,
          'visibleSections': _visibleSections.toList()..sort(),
          'followedEntities': _followedEntities.toList()..sort(),
        },
      );
    } catch (_) {}
  }

  Future<void> _setSpoilerLevel(SpoilerProtectionLevel level) async {
    setState(() => _spoilerLevel = level);
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_spoilerKey, level.name);
    } catch (_) {}
    await _saveRemoteSettings();
  }

  Future<void> _addPrivateNote(Duration position) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const UniversalText('Private X-Ray note'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 5,
          maxLength: 1000,
          decoration: const InputDecoration(
            hintText: 'Add a note about this moment…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const UniversalText('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const UniversalText('Save')),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.trim().isEmpty || !mounted) return;
    final note = <String, dynamic>{
      'id': 'xray-note-${DateTime.now().microsecondsSinceEpoch}',
      'profileId': _profileKey,
      'text': value.trim(),
      'mediaId': media.id,
      'mediaVersionId': media.mediaVersionId,
      'positionMilliseconds': position.inMilliseconds,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
    setState(() => _privateNotes.insert(0, note));
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_notesKey, jsonEncode(_privateNotes));
    } catch (_) {}
    final app = AppController.instance;
    final profileId = app.currentProfile?.id;
    if (app.backendApi.isAuthenticated && profileId != null) {
      try {
        await app.backendApi.saveAppRecord(
          profileId: profileId,
          recordType: 'xray_private_note',
          recordKey: note['id']! as String,
          data: note,
        );
      } catch (_) {
        // Keep the private note locally if the server is temporarily offline.
      }
    }
  }

  Future<void> _copyXRayShareLink(Map<String, dynamic> note) async {
    final versionId = media.mediaVersionId;
    final seconds =
        ((note['positionMilliseconds'] as num?)?.toInt() ?? 0) ~/ 1000;
    if (versionId == null || versionId.trim().isEmpty) return;
    final reference = 'X-Ray reference\n'
        'Media: ${media.title} (${media.id})\n'
        'Version: $versionId\n'
        'Position: ${_formatPosition(Duration(seconds: seconds))}\n'
        'Position milliseconds: ${note['positionMilliseconds']}';
    await Clipboard.setData(ClipboardData(text: reference));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: UniversalText('Version-aware X-Ray reference copied.')));
  }

  Future<void> _toggleFollow(String type, String name) async {
    final key = '$type:${name.trim().toLowerCase()}';
    setState(() {
      if (!_followedEntities.add(key)) _followedEntities.remove(key);
    });
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setStringList(
          _followsKey, _followedEntities.toList()..sort());
    } catch (_) {}
    await _saveRemoteSettings();
  }

  Future<void> _chooseSections() async {
    const options = <String>[
      'People',
      'Characters',
      'Music',
      'Locations',
      'Trivia',
      'Props',
      'Behind the Scenes',
      'Production',
      'Connections',
    ];
    final selected = Set<String>.from(_visibleSections);
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateDialog) => AlertDialog(
          title: const UniversalText('X-Ray sections'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final section in options)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(section),
                    value: selected.contains(section),
                    onChanged: (enabled) => updateDialog(() {
                      if (enabled == true) {
                        selected.add(section);
                      } else {
                        selected.remove(section);
                      }
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const UniversalText('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, selected),
                child: const UniversalText('Save')),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _visibleSections
        ..clear()
        ..addAll(result);
    });
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setStringList(
          _sectionsKey, _visibleSections.toList()..sort());
    } catch (_) {}
    await _saveRemoteSettings();
  }

  @override
  Widget build(BuildContext context) {
    final actors = media.actors.where((e) => e.trim().isNotEmpty).toList();
    final providerDirectors = _providerCrew
        .where((credit) => credit.job.toLowerCase().contains('director'))
        .map((credit) => credit.name);
    final providerWriters = _providerCrew.where((credit) {
      final job = credit.job.toLowerCase();
      return job.contains('writer') || job.contains('screenplay') ||
          job.contains('teleplay') || job == 'story';
    }).map((credit) => credit.name);
    final directors = <String>{...media.directors, ...providerDirectors}
        .where((name) => name.trim().isNotEmpty).toList(growable: false);
    final writers = <String>{...media.writers, ...providerWriters}
        .where((name) => name.trim().isNotEmpty).toList(growable: false);
    final producers = _providerCrew
        .where((credit) => credit.job.toLowerCase().contains('producer'))
        .toList(growable: false);

    final castEntries = _fullCastEntries(actors);

    return Scaffold(
      appBar: AppBar(
        title: const UniversalText('X-Ray'),
        actions: [
          IconButton(
            tooltip: 'Choose X-Ray sections',
            onPressed: _chooseSections,
            icon: const Icon(Icons.tune_rounded),
          ),
          PopupMenuButton<SpoilerProtectionLevel>(
            tooltip: 'Spoiler protection',
            initialValue: _spoilerLevel,
            onSelected: _setSpoilerLevel,
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: SpoilerProtectionLevel.noSpoilers,
                  child: UniversalText('No spoilers')),
              PopupMenuItem(
                  value: SpoilerProtectionLevel.currentScene,
                  child: UniversalText('Current scene')),
              PopupMenuItem(
                  value: SpoilerProtectionLevel.currentMovie,
                  child: UniversalText('Current movie')),
              PopupMenuItem(
                  value: SpoilerProtectionLevel.franchise,
                  child: UniversalText('Franchise')),
              PopupMenuItem(
                  value: SpoilerProtectionLevel.everything,
                  child: UniversalText('Everything')),
            ],
            icon: const Icon(Icons.visibility_outlined),
          ),
          if (media.trailerUrl?.trim().isNotEmpty == true)
            const Padding(
              padding: EdgeInsets.only(right: 14),
              child: Icon(Icons.verified_outlined),
            ),
        ],
      ),
      body: ValueListenableBuilder<Duration>(
        valueListenable: playbackPosition,
        builder: (context, currentPosition, _) {
          final event = _activeEvent(currentPosition);
          final scenePeople = event == null
              ? const <_CastEntry>[]
              : _eventPeople(event);
          final useFullCast = _showFullCast ?? (event == null);
          final people = _spoilerLevel == SpoilerProtectionLevel.noSpoilers
              ? const <_CastEntry>[]
              : useFullCast
                  ? castEntries
                  : scenePeople;
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 36),
            children: [
              _heroCard(),
              const SizedBox(height: 18),
              if (event != null &&
                  _spoilerLevel != SpoilerProtectionLevel.noSpoilers) ...[
                _sceneCard(event, currentPosition),
                const SizedBox(height: 18),
              ],
              _notesSection(currentPosition),
              if (_spoilerLevel != SpoilerProtectionLevel.noSpoilers &&
                  (_visibleSections.contains('People') ||
                      _visibleSections.contains('Characters'))) ...[
                SegmentedButton<bool>(
                  segments: const <ButtonSegment<bool>>[
                    ButtonSegment<bool>(
                      value: false,
                      icon: Icon(Icons.movie_filter_outlined),
                      label: Text('In this scene'),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      icon: Icon(Icons.groups_2_outlined),
                      label: Text('Full cast'),
                    ),
                  ],
                  selected: <bool>{useFullCast},
                  onSelectionChanged: (selection) => setState(
                    () => _showFullCast = selection.first,
                  ),
                ),
                const SizedBox(height: 14),
              ],
              if (people.isNotEmpty &&
                  (_visibleSections.contains('People') ||
                      _visibleSections.contains('Characters'))) ...[
                _heading(
                    event == null || useFullCast ? 'FULL CAST' : 'IN THIS SCENE',
                    Icons.people_alt_outlined),
                const SizedBox(height: 10),
                _castPortraitRail(
                  context,
                  people,
                  showActor: _visibleSections.contains('People'),
                  showCharacter: _visibleSections.contains('Characters'),
                ),
              ] else if (!useFullCast &&
                  _spoilerLevel != SpoilerProtectionLevel.noSpoilers &&
                  (_visibleSections.contains('People') ||
                      _visibleSections.contains('Characters'))) ...[
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No scene-specific cast is available at this timestamp yet. Choose Full cast to browse the verified title credits.',
                      style: TextStyle(color: Colors.white60, height: 1.4),
                    ),
                  ),
                ),
              ] else if (_loadingProviderCast &&
                  (_visibleSections.contains('People') ||
                      _visibleSections.contains('Characters'))) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
              if (event != null &&
                  _spoilerLevel != SpoilerProtectionLevel.noSpoilers) ...[
                if (_visibleSections.contains('Music'))
                  _contextSection(
                      event, 'music', 'MUSIC', Icons.music_note_rounded),
                if (_visibleSections.contains('Trivia'))
                  _contextSection(event, 'trivia', 'TRIVIA',
                      Icons.lightbulb_outline_rounded),
                if (_visibleSections.contains('Locations')) ...[
                  _contextSection(
                      event, 'location', 'LOCATION', Icons.place_outlined),
                  _contextSection(event, 'filmingLocation', 'FILMING LOCATION',
                      Icons.location_on_outlined),
                ],
                if (_visibleSections.contains('Production')) ...[
                  _contextSection(
                      event, 'composer', 'MUSIC BY', Icons.music_note_rounded),
                  _contextSection(event, 'cinematographer', 'CINEMATOGRAPHY',
                      Icons.camera_alt_outlined),
                ],
                if (_visibleSections.contains('Props'))
                  _contextSection(
                      event, 'objects', 'OBJECTS', Icons.category_outlined),
                if (_visibleSections.contains('Behind the Scenes'))
                  _contextSection(event, 'behindTheScenes', 'BEHIND THE SCENES',
                      Icons.movie_filter_outlined),
                if (_visibleSections.contains('Connections')) ...[
                  _contextSection(
                      event, 'references', 'REFERENCES', Icons.link_rounded),
                  _contextSection(
                      event, 'relatedMedia', 'RELATED', Icons.movie_outlined),
                ],
              ] else if (_spoilerLevel != SpoilerProtectionLevel.noSpoilers &&
                  media.music.isNotEmpty) ...[
                const SizedBox(height: 18),
                _heading('MUSIC', Icons.music_note_rounded),
                const SizedBox(height: 10),
                _contextItems(media.music),
              ],
              if (_visibleSections.contains('Production') &&
                  directors.isNotEmpty) ...[
                const SizedBox(height: 18),
                _heading('DIRECTORS', Icons.movie_creation_outlined),
                const SizedBox(height: 10),
                _crewPortraitRail(names: directors, role: 'Director', followType: 'director'),
              ],
              if (_visibleSections.contains('Production') &&
                  writers.isNotEmpty) ...[
                const SizedBox(height: 18),
                _heading('WRITERS', Icons.edit_note_rounded),
                const SizedBox(height: 10),
                _crewPortraitRail(names: writers, role: 'Writer / Screenplay', followType: 'writer'),
              ],
              if (_visibleSections.contains('Production') && producers.isNotEmpty) ...[
                const SizedBox(height: 18),
                _heading('PRODUCERS', Icons.movie_filter_outlined),
                const SizedBox(height: 10),
                _crewPortraitRail(
                  names: producers.map((credit) => credit.name).toSet().toList(),
                  role: 'Producer',
                  followType: 'producer',
                ),
              ],
              if (event == null && people.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: UniversalText(
                    'No cast or scene-specific X-Ray metadata is available for this title yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white60),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _notesSection(Duration position) => Card(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.note_alt_outlined),
              title: const UniversalText('My X-Ray notes'),
              subtitle: Text(
                  'Private to this profile · ${media.mediaVersionId ?? 'Unversioned media'}'),
              trailing: IconButton(
                tooltip: 'Add a note at ${_formatPosition(position)}',
                onPressed: media.mediaVersionId == null ||
                        media.mediaVersionId!.trim().isEmpty
                    ? null
                    : () => _addPrivateNote(position),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ),
            for (final note in _privateNotes)
              ListTile(
                dense: true,
                title: Text(note['text']?.toString() ?? ''),
                subtitle: Text(
                    '${_formatPosition(Duration(milliseconds: (note['positionMilliseconds'] as num?)?.toInt() ?? 0))} · ${note['mediaVersionId'] ?? 'unversioned'}'),
                trailing: IconButton(
                  tooltip: note['mediaVersionId'] == null
                      ? 'A version ID is required for an exact reference'
                      : 'Copy X-Ray reference',
                  onPressed: note['mediaVersionId'] == null
                      ? null
                      : () => _copyXRayShareLink(note),
                  icon: const Icon(Icons.share_outlined),
                ),
              ),
          ],
        ),
      );

  Map<String, dynamic>? _activeEvent(Duration position) {
    final events = media.xrayEvents
        .where((event) {
          final eventVersionId = (event['mediaVersionId'] ?? event['versionId'])
              ?.toString()
              .trim();
          // Legacy events without a version remain available. Version-bound
          // events are hidden unless playback identifies that exact version.
          return eventVersionId == null ||
              eventVersionId.isEmpty ||
              eventVersionId == media.mediaVersionId;
        })
        .where((event) =>
            _timeSeconds(_eventValue(
                event, const ['startSeconds', 'startTime', 'start'])) !=
            null)
        .toList()
      ..sort((first, second) => _timeSeconds(
              _eventValue(first, const ['startSeconds', 'startTime', 'start']))!
          .compareTo(_timeSeconds(_eventValue(
              second, const ['startSeconds', 'startTime', 'start']))!));

    final seconds = position.inMilliseconds / 1000;
    for (var index = 0; index < events.length; index++) {
      final event = events[index];
      final start = _timeSeconds(
        _eventValue(event, const ['startSeconds', 'startTime', 'start']),
      )!;
      final explicitEnd = _timeSeconds(
        _eventValue(event, const ['endSeconds', 'endTime', 'end']),
      );
      final nextStart = index + 1 < events.length
          ? _timeSeconds(
              _eventValue(events[index + 1],
                  const ['startSeconds', 'startTime', 'start']),
            )
          : null;
      final end = explicitEnd ?? nextStart;
      if (seconds >= start && (end == null || seconds < end)) {
        return _isAllowedBySpoilerLevel(event) ? event : null;
      }
    }
    return null;
  }

  bool _isAllowedBySpoilerLevel(Map<String, dynamic> event) {
    final scope = (event['spoilerScope'] ?? 'current_scene')
        .toString()
        .trim()
        .toLowerCase();
    const order = {
      'none': 0,
      'current_scene': 1,
      'current_movie': 2,
      'franchise': 3,
      'everything': 4,
    };
    final eventLevel = order[scope] ?? order['current_scene']!;
    final allowedLevel = switch (_spoilerLevel) {
      SpoilerProtectionLevel.noSpoilers => 0,
      SpoilerProtectionLevel.currentScene => 1,
      SpoilerProtectionLevel.currentMovie => 2,
      SpoilerProtectionLevel.franchise => 3,
      SpoilerProtectionLevel.everything => 4,
    };
    return eventLevel <= allowedLevel;
  }

  List<_CastEntry> _eventPeople(Map<String, dynamic> event) {
    final rawPeople = event['people'] ?? event['cast'];
    if (rawPeople is! List) return const <_CastEntry>[];
    return rawPeople
        .map((person) {
          if (person is! Map) {
            return _enrichCastEntry(_parseCastEntry(person.toString()));
          }
          final data = Map<String, dynamic>.from(person);
          final actor = (data['actor'] ??
                  data['actorName'] ??
                  data['name'] ??
                  'Unknown')
              .toString()
              .trim();
          final rawRole = (data['character'] ??
                  data['characterName'] ??
                  data['role'] ??
                  '')
              .toString()
              .trim();
          final role = rawRole.toLowerCase() == 'featured cast' ? '' : rawRole;
          final explicitPhoto = (data['photoUrl'] ??
                  data['imageUrl'] ??
                  data['profileImageUrl'] ??
                  data['profileImage'] ??
                  data['portraitUrl'] ??
                  data['profile_path'] ??
                  data['profilePath'])
              ?.toString()
              .trim();
          return _enrichCastEntry(_CastEntry(
            actor: actor,
            character: role,
            photoUrl: explicitPhoto == null || explicitPhoto.isEmpty
                ? null
                : explicitPhoto.startsWith('http')
                    ? explicitPhoto
                    : CinematicPersonMetadataService.imageUrl(explicitPhoto,
                        size: 'w185'),
            biography: (data['biography'] ?? data['bio'])?.toString(),
            characterBiography:
                (data['characterBiography'] ?? data['characterBio'])
                    ?.toString(),
            filmography: _eventStrings(data['filmography']),
            relatedCharacters: _eventStrings(data['relatedCharacters']),
          ));
        })
        .where((entry) => entry.actor.trim().isNotEmpty)
        .toList();
  }

  Object? _eventValue(Map<String, dynamic> event, List<String> keys) {
    for (final key in keys) {
      if (event[key] != null) return event[key];
    }
    return null;
  }

  double? _timeSeconds(Object? value) {
    if (value is num) return value.toDouble();
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    final numeric = double.tryParse(text);
    if (numeric != null) return numeric;
    final parts = text.split(':');
    if (parts.length < 2 || parts.length > 3) return null;
    final parsed = parts.map(double.tryParse).toList();
    if (parsed.any((part) => part == null)) return null;
    if (parts.length == 2) return parsed[0]! * 60 + parsed[1]!;
    return parsed[0]! * 3600 + parsed[1]! * 60 + parsed[2]!;
  }

  List<String> _eventStrings(Object? value) {
    if (value is String) {
      return value.trim().isEmpty ? const [] : [value.trim()];
    }
    if (value is! List) return const [];
    return value
        .map((entry) {
          if (entry is Map) {
            return (entry['title'] ?? entry['name'] ?? entry['label'] ?? '')
                .toString()
                .trim();
          }
          return entry.toString().trim();
        })
        .where((entry) => entry.isNotEmpty)
        .toList();
  }

  Widget _sceneCard(Map<String, dynamic> event, Duration position) {
    final title =
        (event['title'] ?? event['scene'] ?? 'Current scene').toString();
    final description = (event['description'] ?? event['summary'])?.toString();
    final location = event['location']?.toString();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bolt_rounded, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                    child: UniversalText('CURRENT SCENE',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, letterSpacing: 1))),
                Text(_formatPosition(position),
                    style: const TextStyle(color: Colors.white54)),
              ],
            ),
            const SizedBox(height: 10),
            Text(title,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            if (description?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(description!,
                  style: const TextStyle(color: Colors.white70, height: 1.45)),
            ],
            if (location?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.place_outlined,
                      size: 16, color: Colors.white60),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text(location!,
                          style: const TextStyle(color: Colors.white60))),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _contextSection(
      Map<String, dynamic> event, String key, String title, IconData icon) {
    final values = _eventStrings(event[key]);
    if (values.isEmpty) return const SizedBox.shrink();
    final followType = const {
      'composer': 'composer',
      'cinematographer': 'cinematographer',
      'franchise': 'franchise',
    }[key];
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading(title, icon),
          const SizedBox(height: 10),
          _contextItems(values, followType: followType),
        ],
      ),
    );
  }

  Widget _contextItems(List<String> values, {String? followType}) {
    return Card(
      child: Column(
        children: [
          for (var index = 0; index < values.length; index++) ...[
            ListTile(
              dense: true,
              title: Text(values[index]),
              trailing: followType == null
                  ? null
                  : IconButton(
                      tooltip: 'Follow $followType',
                      onPressed: () => _toggleFollow(followType, values[index]),
                      icon: Icon(_followedEntities.contains(
                              '$followType:${values[index].trim().toLowerCase()}')
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_none_outlined),
                    ),
            ),
            if (index < values.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }

  String _formatPosition(Duration position) {
    final hours = position.inHours;
    final minutes = hours > 0
        ? position.inMinutes.remainder(60).toString().padLeft(2, '0')
        : position.inMinutes.toString();
    final seconds = position.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0
        ? '${hours.toString().padLeft(2, '0')}:$minutes:$seconds'
        : '$minutes:$seconds';
  }

  List<_CastEntry> _fullCastEntries(List<String> actorNames) {
    if (_providerCast.isNotEmpty) return _providerCast;
    final characters = media.characters;
    final canPairByPosition = characters.length == actorNames.length;
    return actorNames.asMap().entries.map((entry) {
      final parsed = _parseCastEntry(entry.value);
      if (parsed.character.isNotEmpty || !canPairByPosition) {
        return _enrichCastEntry(parsed);
      }
      final role = characters[entry.key].trim();
      return _enrichCastEntry(_CastEntry(
        actor: parsed.actor,
        character: role,
        photoUrl: parsed.photoUrl,
      ));
    }).toList(growable: false);
  }

  _CastEntry _enrichCastEntry(_CastEntry entry) {
    final actorKey = _normalizePersonName(entry.actor);
    if (actorKey.isEmpty) return entry;
    _CastEntry? providerMatch;
    for (final candidate in _providerCast) {
      if (_normalizePersonName(candidate.actor) == actorKey) {
        providerMatch = candidate;
        break;
      }
    }
    if (providerMatch == null) return entry;
    final entryRole = entry.character.trim();
    final role = entryRole.isNotEmpty &&
            entryRole.toLowerCase() != 'featured cast'
        ? entryRole
        : providerMatch.character;
    return _CastEntry(
      actor: entry.actor,
      character: role,
      photoUrl: (entry.photoUrl?.trim().isNotEmpty ?? false)
          ? entry.photoUrl
          : providerMatch.photoUrl,
      personId: entry.personId ?? providerMatch.personId,
      biography: entry.biography,
      characterBiography: entry.characterBiography,
      filmography: entry.filmography,
      relatedCharacters: entry.relatedCharacters,
    );
  }

  String _normalizePersonName(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\s\-_,.:;!?()\[\]{}\\/]+'), '');

  _CastEntry _parseCastEntry(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) {
      return const _CastEntry(actor: 'Unknown', character: '');
    }

    final patterns = [
      RegExp(r'^(.*?)(?:\s+as\s+|\s+-\s+|\s+\|\s+|\s*/\s*)(.+)$',
          caseSensitive: false),
      RegExp(r'^(.*?)(?:\s+\((.+)\))$', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(normalized);
      if (match != null) {
        final actor = match.group(1)?.trim();
        final character = match.group(2)?.trim();
        if (actor != null &&
            actor.isNotEmpty &&
            character != null &&
            character.isNotEmpty) {
          return _CastEntry(
            actor: actor,
            character: character.toLowerCase() == 'featured cast'
                ? ''
                : character,
          );
        }
      }
    }

    return _CastEntry(actor: normalized, character: '');
  }

  Widget _castPortraitRail(
    BuildContext context,
    List<_CastEntry> entries, {
    required bool showActor,
    required bool showCharacter,
  }) {
    final visible = entries.where((entry) =>
      (showActor && entry.actor.trim().isNotEmpty) ||
      (showCharacter && entry.character.trim().isNotEmpty)
    ).toList(growable: false);
    if (visible.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 286,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: visible.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final cast = visible[index];
          final actorKey = 'actor:${cast.actor.trim().toLowerCase()}';
          final characterKey = 'character:${cast.character.trim().toLowerCase()}';
          return SizedBox(
            width: 154,
            child: Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              color: const Color(0xFF151515),
              child: InkWell(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ActorBiographyScreen(
                    actorName: cast.actor, actorPhotoUrl: cast.photoUrl,
                    characterName: cast.character, biography: cast.biography,
                    characterBiography: cast.characterBiography, filmography: cast.filmography,
                    relatedCharacters: cast.relatedCharacters, media: media,
                  ),
                )),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _XRayPersonPortrait(name: cast.actor, photoUrl: cast.photoUrl),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 9, 8, 0),
                      child: Text(
                        showActor ? cast.actor : cast.character,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                      ),
                    ),
                    if (showCharacter && cast.character.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 3, 8, 0),
                        child: Text('as ${cast.character}', maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: Colors.white70)),
                      ),
                    SizedBox(
                      height: 38,
                      child: Row(
                        children: [
                          if (showActor) IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: _followedEntities.contains(actorKey) ? 'Unfollow actor' : 'Follow actor',
                            onPressed: () => _toggleFollow('actor', cast.actor),
                            icon: Icon(_followedEntities.contains(actorKey) ? Icons.person_remove_alt_1 : Icons.person_add_alt_1, size: 18),
                          ),
                          if (showCharacter && cast.character.trim().isNotEmpty) IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: _followedEntities.contains(characterKey) ? 'Unfollow character' : 'Follow character',
                            onPressed: () => _toggleFollow('character', cast.character),
                            icon: Icon(_followedEntities.contains(characterKey) ? Icons.bookmark_remove_outlined : Icons.bookmark_add_outlined, size: 18),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _crewPortraitRail({
    required List<String> names,
    required String role,
    required String followType,
  }) {
    final uniqueNames = names.map((name) => name.trim()).where((name) => name.isNotEmpty).toSet().toList(growable: false);
    if (uniqueNames.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 252,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: uniqueNames.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final name = uniqueNames[index];
          CinematicCrewCredit? credit;
          for (final candidate in _providerCrew) {
            if (candidate.name == name) {
              credit = candidate;
              break;
            }
          }
          final photoUrl = CinematicPersonMetadataService.imageUrl(credit?.profilePath, size: 'w185');
          final followedKey = '$followType:${name.toLowerCase()}';
          return SizedBox(
            width: 145,
            child: Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              color: const Color(0xFF151515),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _XRayPersonPortrait(name: name, photoUrl: photoUrl)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 9, 10, 2),
                    child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(role, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Colors.white60)),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: _followedEntities.contains(followedKey) ? 'Unfollow $followType' : 'Follow $followType',
                      onPressed: () => _toggleFollow(followType, name),
                      icon: Icon(_followedEntities.contains(followedKey) ? Icons.notifications_active_outlined : Icons.notifications_none_outlined, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF1B1B1B), Color(0xFF0D0D0D)],
        ),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 72,
              height: 104,
              child: _poster(),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const UniversalText(
                  'X-RAY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  media.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    if (media.releaseYear != null) '${media.releaseYear}',
                    if (media.genres.isNotEmpty)
                      media.genres.take(2).join(' • '),
                  ].join(' • '),
                  style: const TextStyle(color: Colors.white54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _poster() {
    final url = media.imageUrl?.trim();
    if (url == null || url.isEmpty) {
      return Container(
        color: const Color(0xFF181818),
        child: const Icon(Icons.movie_outlined, color: Colors.white38),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: const Color(0xFF181818),
        child: const Icon(Icons.movie_outlined, color: Colors.white38),
      ),
    );
  }

  Widget _heading(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 7),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }


}

/// Displays a person-focused X-Ray card for an actor.
class ActorBiographyScreen extends StatelessWidget {
  final String actorName;
  final String? actorPhotoUrl;
  final String? characterName;
  final String? biography;
  final String? characterBiography;
  final List<String> filmography;
  final List<String> relatedCharacters;
  final MediaItem media;

  const ActorBiographyScreen({
    super.key,
    required this.actorName,
    this.actorPhotoUrl,
    this.characterName,
    this.biography,
    this.characterBiography,
    this.filmography = const <String>[],
    this.relatedCharacters = const <String>[],
    required this.media,
  });

  @override
  Widget build(BuildContext context) {
    final rawCharacter = (characterName ?? '').trim();
    final character = rawCharacter.toLowerCase() == 'featured cast'
        ? ''
        : rawCharacter;
    final activeProfile = AppController.instance.currentProfile;
    final libraryAppearances = AppController.instance.library.where((item) {
      if (!item.isAccessibleTo(activeProfile)) return false;
      return item.actors.any((credit) {
        final normalized = credit.trim().toLowerCase();
        final actor = actorName.trim().toLowerCase();
        return normalized == actor ||
            normalized.startsWith('$actor as ') ||
            normalized.startsWith('$actor - ');
      });
    }).toList();

    return Scaffold(
      appBar: AppBar(title: Text(actorName)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                _XRayPersonAvatar(
                  name: actorName,
                  photoUrl: actorPhotoUrl,
                  radius: 64,
                ),
                const SizedBox(height: 12),
                Text(
                  actorName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                UniversalText(
                  character.isNotEmpty ? 'AS $character' : 'ACTOR PROFILE',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (biography?.trim().isNotEmpty == true)
            _profileSection('BIOGRAPHY', [biography!.trim()]),
          if (characterBiography?.trim().isNotEmpty == true)
            _profileSection('CHARACTER', [characterBiography!.trim()]),
          if (filmography.isNotEmpty)
            _profileSection('FILMOGRAPHY', filmography),
          if (relatedCharacters.isNotEmpty)
            _profileSection('RELATED CHARACTERS', relatedCharacters),
          _profileSection(
            'WHERE HAVE I SEEN $actorName?',
            libraryAppearances
                .where((item) => item.id != media.id)
                .map((item) => '${item.title} ✓')
                .toList(),
            emptyMessage: 'No other matching titles in your library yet.',
          ),
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              leading: const Icon(Icons.movie_outlined),
              title: const UniversalText('Featured in'),
              subtitle: LocalizedMediaText(media.title, preserveOriginal: true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileSection(String title, List<String> values,
      {String? emptyMessage}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                    color: Colors.white54)),
            const SizedBox(height: 9),
            if (values.isEmpty && emptyMessage != null)
              Text(emptyMessage,
                  style: const TextStyle(color: Colors.white54, height: 1.5)),
            for (final value in values)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(value,
                    style: const TextStyle(color: Colors.white70, height: 1.5)),
              ),
          ],
        ),
      ),
    );
  }
}

class _XRayPersonPortrait extends StatelessWidget {
  const _XRayPersonPortrait({required this.name, this.photoUrl});

  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final direct = photoUrl?.trim() ?? '';
    final future = direct.isNotEmpty ? null : CinematicPersonMetadataService.lookupPersonSummary(name);
    return FutureBuilder<CinematicPersonSummary?>(
      future: future,
      builder: (context, snapshot) {
        final url = direct.isNotEmpty
            ? direct
            : CinematicPersonMetadataService.imageUrl(snapshot.data?.profilePath, size: 'w185');
        if (url == null || url.isEmpty) {
          return Container(
            color: const Color(0xFF242424),
            alignment: Alignment.center,
            child: const Icon(Icons.person_outline_rounded, size: 54, color: Colors.white38),
          );
        }
        return Image.network(
          url, fit: BoxFit.cover, width: double.infinity, height: double.infinity,
          errorBuilder: (_, __, ___) => Container(
            color: const Color(0xFF242424), alignment: Alignment.center,
            child: const Icon(Icons.person_outline_rounded, size: 54, color: Colors.white38),
          ),
        );
      },
    );
  }
}

class _XRayPersonAvatar extends StatelessWidget {
  const _XRayPersonAvatar({
    required this.name,
    required this.radius,
    this.photoUrl,
  });

  final String name;
  final double radius;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final directUrl = photoUrl?.trim() ?? '';
    final Future<CinematicPersonSummary?>? lookup = directUrl.isNotEmpty
        ? null
        : CinematicPersonMetadataService.lookupPersonSummary(name);
    return FutureBuilder<CinematicPersonSummary?>(
      future: lookup,
      builder: (context, snapshot) {
        final url = directUrl.isNotEmpty
            ? directUrl
            : CinematicPersonMetadataService.imageUrl(
                snapshot.data?.profilePath,
                size: 'w185',
              );
        final size = radius * 2;
        return ClipOval(
          child: SizedBox(
            width: size,
            height: size,
            child: url == null || url.isEmpty
                ? Container(
                    color: Colors.white.withValues(alpha: .08),
                    alignment: Alignment.center,
                    child: Icon(Icons.person_outline_rounded,
                        size: radius * .95, color: Colors.white60),
                  )
                : Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.white.withValues(alpha: .08),
                      alignment: Alignment.center,
                      child: Icon(Icons.person_outline_rounded,
                          size: radius * .95, color: Colors.white60),
                    ),
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: Colors.white.withValues(alpha: .08),
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: radius * .55,
                          height: radius * .55,
                          child: const CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    },
                  ),
          ),
        );
      },
    );
  }
}

class _CastEntry {
  final String actor;
  final String character;
  final String? photoUrl;
  final int? personId;
  final String? biography;
  final String? characterBiography;
  final List<String> filmography;
  final List<String> relatedCharacters;

  const _CastEntry({
    required this.actor,
    required this.character,
    this.photoUrl,
    this.personId,
    this.biography,
    this.characterBiography,
    this.filmography = const <String>[],
    this.relatedCharacters = const <String>[],
  });
}
