import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_core.dart';
import 'backend_api.dart';
import 'disc_ingestion_center.dart';
import 'music_catalog_screen.dart';
import 'song_identification_screen.dart';

/// Profile-aware home for music listening memory, TV episode notes, disc
/// mapping, media preservation records, and a unified entertainment timeline.
class PersonalMediaIntelligenceCenterScreen extends StatefulWidget {
  const PersonalMediaIntelligenceCenterScreen({
    super.key,
    this.initialTab = 0,
    this.initialDiscLabel,
    this.initialDiscFingerprint,
    this.detectedTitleSummaries = const <Map<String, dynamic>>[],
  });

  final int initialTab;
  final String? initialDiscLabel;
  final String? initialDiscFingerprint;
  final List<Map<String, dynamic>> detectedTitleSummaries;

  @override
  State<PersonalMediaIntelligenceCenterScreen> createState() =>
      _PersonalMediaIntelligenceCenterScreenState();
}

class _PersonalMediaIntelligenceCenterScreenState
    extends State<PersonalMediaIntelligenceCenterScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  Map<String, dynamic> _musicStats = <String, dynamic>{};
  String _chartScope = 'profile';
  int _selectedMusicYear = DateTime.now().year;
  String? _chartScopeError;
  List<Map<String, dynamic>> _upcomingAlbums = <Map<String, dynamic>>[];
  bool _loadingReleaseRadar = false;
  String? _releaseRadarError;
  List<Map<String, dynamic>> _musicHistory = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _episodeNotes = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _discMappings = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _preservationRecords = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _concerts = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _timeline = <Map<String, dynamic>>[];
  Map<String, dynamic>? _armStatus;
  List<dynamic> _armDrives = <dynamic>[];

  AppController get _app => AppController.instance;
  String get _profileId => _app.currentProfile?.id.trim() ?? '';
  bool get _authenticated =>
      _app.isBackendAuthenticated && _profileId.isNotEmpty;
  Map<String, dynamic>? get _matchedDiscMapping {
    final fingerprint = widget.initialDiscFingerprint?.trim() ?? '';
    if (fingerprint.isEmpty) return null;
    for (final mapping in _discMappings) {
      if (mapping['discFingerprint']?.toString() == fingerprint) return mapping;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 3).toInt(),
    );
    unawaited(_refresh());
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!_authenticated) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error =
              'Sign in and select a profile to sync Personal Media Intelligence.';
        });
      }
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final payload =
          await _app.backendApi.getPersonalExperience(profileId: _profileId);
      final exp = payload['experience'] is Map
          ? Map<String, dynamic>.from(payload['experience'] as Map)
          : <String, dynamic>{};
      final stats = payload['musicStats'] is Map
          ? Map<String, dynamic>.from(payload['musicStats'] as Map)
          : <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _musicStats = stats;
        _musicHistory = _rows(exp['musicHistory']);
        _episodeNotes = _rows(exp['episodeNotes'])..sort(_episodeSort);
        _discMappings = _rows(exp['discMappings']);
        _preservationRecords = _rows(exp['preservationRecords']);
        _concerts = _rows(exp['concerts'])
          ..sort((a, b) => (a['eventDate'] ?? '')
              .toString()
              .compareTo((b['eventDate'] ?? '').toString()));
        _timeline = _rows(payload['timeline']);
      });
      await _loadArmStatus();
      if (_chartScope != 'global') await _loadScopedMusicStats();
    } catch (error) {
      if (mounted) {
        setState(() => _error =
            error.toString().replaceFirst('BackendApiException: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadScopedMusicStats() async {
    if (!_authenticated || _chartScope == 'global') return;
    try {
      final payload = await _app.backendApi.getMusicExperienceStats(
        profileId: _profileId,
        scope: _chartScope,
        year: _selectedMusicYear,
      );
      if (!mounted) return;
      setState(() => _musicStats = payload['stats'] is Map
          ? Map<String, dynamic>.from(payload['stats'] as Map)
          : <String, dynamic>{});
    } catch (error) {
      if (mounted) setState(() => _chartScopeError = error.toString());
    }
  }

  Future<void> _changeMusicYear(int? year) async {
    if (year == null || year == _selectedMusicYear) return;
    setState(() => _selectedMusicYear = year);
    await _loadScopedMusicStats();
  }

  Future<void> _loadReleaseRadar() async {
    if (_loadingReleaseRadar) return;
    setState(() {
      _loadingReleaseRadar = true;
      _releaseRadarError = null;
    });
    try {
      final payload = await _app.backendApi.getUpcomingMusicAlbums(limit: 60);
      if (!mounted) return;
      setState(() => _upcomingAlbums = _rows(payload['items']));
      if (_upcomingAlbums.isEmpty) {
        setState(() => _releaseRadarError =
            'No upcoming release dates were returned by MusicBrainz.');
      }
    } catch (error) {
      if (mounted) setState(() => _releaseRadarError = error.toString());
    } finally {
      if (mounted) setState(() => _loadingReleaseRadar = false);
    }
  }

  Future<void> _changeChartScope(String? scope) async {
    if (scope == null || scope == _chartScope) return;
    setState(() {
      _chartScope = scope;
      _chartScopeError = null;
    });
    try {
      if (scope == 'global') {
        final payload = await _app.backendApi.getGlobalMusicCharts();
        final artists = _rows(payload['artists'])
            .map((row) => <String, dynamic>{
                  'name': row['title'] ?? '',
                  'plays': row['listenCount'] ?? 0,
                })
            .toList();
        final albums = _rows(payload['releaseGroups'])
            .map((row) => <String, dynamic>{
                  'name': row['title'] ?? '',
                  'plays': row['listenCount'] ?? 0,
                })
            .toList();
        final songs = _rows(payload['recordings'])
            .map((row) => <String, dynamic>{
                  'name': row['title'] ?? '',
                  'plays': row['listenCount'] ?? 0,
                })
            .toList();
        if (!mounted) return;
        setState(() => _musicStats = {
              'topArtists': artists,
              'topAlbums': albums,
              'topSongs': songs,
              'topGenres': <Map<String, dynamic>>[],
              'playCount': 0,
              'identifiedCount': 0,
              'listeningMinutes': 0,
              'uniqueArtists': 0,
            });
      } else {
        final payload = await _app.backendApi.getMusicExperienceStats(
          profileId: _profileId,
          scope: scope,
          year: _selectedMusicYear,
        );
        if (!mounted) return;
        setState(() => _musicStats = payload['stats'] is Map
            ? Map<String, dynamic>.from(payload['stats'] as Map)
            : <String, dynamic>{});
      }
    } catch (error) {
      if (mounted) setState(() => _chartScopeError = error.toString());
    }
  }

  Future<void> _loadArmStatus() async {
    if (!_authenticated) return;
    try {
      final results = await Future.wait<dynamic>([
        _app.backendApi.getArmStatus(),
        _app.backendApi.getArmDrives(),
      ]);
      if (!mounted) return;
      setState(() {
        _armStatus = Map<String, dynamic>.from(results[0] as Map);
        _armDrives = results[1] as List<dynamic>;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _armStatus = <String, dynamic>{'connected': false};
          _armDrives = <dynamic>[];
        });
      }
    }
  }

  List<Map<String, dynamic>> _rows(dynamic raw) => raw is List
      ? raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList()
      : <Map<String, dynamic>>[];

  int _episodeSort(Map<String, dynamic> a, Map<String, dynamic> b) {
    final show = (a['seriesTitle'] ?? '')
        .toString()
        .compareTo((b['seriesTitle'] ?? '').toString());
    if (show != 0) return show;
    final season = ((a['seasonNumber'] as num?)?.toInt() ?? 0)
        .compareTo((b['seasonNumber'] as num?)?.toInt() ?? 0);
    if (season != 0) return season;
    return ((a['episodeNumber'] as num?)?.toInt() ?? 0)
        .compareTo((b['episodeNumber'] as num?)?.toInt() ?? 0);
  }

  void _message(String value, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(value),
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
    ));
  }

  Future<void> _importSeasonGuide() async {
    final show = TextEditingController();
    final season = TextEditingController(text: '1');
    try {
      final input = await showDialog<(String, int)?>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Import episode guide from TMDB'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: show,
                decoration: const InputDecoration(labelText: 'TV show title')),
            TextField(
                controller: season,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Season number')),
            const SizedBox(height: 8),
            const Text(
                'Official titles and descriptions are imported. You add your own opening-scene clues afterward.',
                style: TextStyle(color: Colors.white60, fontSize: 12)),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () {
                  final number = int.tryParse(season.text.trim());
                  if (show.text.trim().isEmpty ||
                      number == null ||
                      number < 0) {
                    _message('Enter a show title and a valid season number.',
                        error: true);
                    return;
                  }
                  Navigator.pop(dialogContext, (show.text.trim(), number));
                },
                child: const Text('Find show')),
          ],
        ),
      );
      if (input == null) return;
      final search = await _app.backendApi
          .getTmdbMetadata('/search/tv', {'query': input.$1});
      final results = _rows(search['results']);
      if (!mounted) return;
      if (results.isEmpty) {
        _message('TMDB did not find that show.', error: true);
        return;
      }
      if (!mounted) return;
      final selected = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Choose the correct TV series'),
          content: SizedBox(
              width: 460,
              child: ListView(
                  shrinkWrap: true,
                  children: results
                      .take(12)
                      .map((row) => ListTile(
                            title: Text(
                                (row['name'] ?? 'Untitled series').toString()),
                            subtitle: Text(
                                '${row['first_air_date'] ?? 'Release date unknown'} · ${row['origin_country'] is List ? (row['origin_country'] as List).join(', ') : ''}'),
                            onTap: () => Navigator.pop(dialogContext, row),
                          ))
                      .toList())),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'))
          ],
        ),
      );
      if (!mounted || selected == null) return;
      final tmdbId = (selected['id'] as num?)?.toInt();
      if (tmdbId == null) {
        _message('The selected TMDB result has no series ID.', error: true);
        return;
      }
      final guide = await _app.backendApi
          .getTmdbMetadata('/tv/$tmdbId/season/${input.$2}');
      if (!mounted) return;
      final episodes = _rows(guide['episodes']);
      if (episodes.isEmpty) {
        _message('TMDB has no episode rows for that season.', error: true);
        return;
      }
      var savedCount = 0;
      for (final episode in episodes) {
        final episodeNumber = (episode['episode_number'] as num?)?.toInt();
        if (episodeNumber == null) continue;
        final runtime = (episode['runtime'] as num?)?.toInt() ?? 0;
        await _app.backendApi.saveEpisodeIdentificationNote(
          profileId: _profileId,
          seriesTitle: (selected['name'] ?? input.$1).toString(),
          seriesId: 'tmdb:$tmdbId',
          seasonNumber: input.$2,
          episodeNumber: episodeNumber,
          episodeTitle: episode['name']?.toString(),
          officialOverview: episode['overview']?.toString(),
          durationSeconds: runtime * 60,
        );
        savedCount++;
      }
      await _refresh();
      _message(
          'Imported $savedCount episode guide entries. Add opening-scene notes to identify the physical disc titles.');
    } catch (error) {
      _message('Episode guide import failed: $error', error: true);
    } finally {
      show.dispose();
      season.dispose();
    }
  }

  Future<void> _openNoteEditor({Map<String, dynamic>? existing}) async {
    final show =
        TextEditingController(text: existing?['seriesTitle']?.toString() ?? '');
    final seriesId =
        TextEditingController(text: existing?['seriesId']?.toString() ?? '');
    final season = TextEditingController(
        text: (existing?['seasonNumber'] ?? '').toString());
    final episode = TextEditingController(
        text: (existing?['episodeNumber'] ?? '').toString());
    final title = TextEditingController(
        text: existing?['episodeTitle']?.toString() ?? '');
    final overview = TextEditingController(
        text: existing?['officialOverview']?.toString() ?? '');
    final notes = TextEditingController(
        text: (existing?['openingNotes'] is List
            ? (existing!['openingNotes'] as List).join('\n')
            : ''));
    final tags = TextEditingController(
        text: (existing?['tags'] is List
            ? (existing!['tags'] as List).join(', ')
            : ''));
    final disc = TextEditingController(
        text: existing?['discLabel']?.toString() ??
            widget.initialDiscLabel ??
            '');
    final armTitle =
        TextEditingController(text: existing?['armTitleId']?.toString() ?? '');
    final duration = TextEditingController(
        text: existing?['durationSeconds']?.toString() ?? '');
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(existing == null
              ? 'Add episode identification note'
              : 'Edit episode note'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: show,
                    decoration:
                        const InputDecoration(labelText: 'TV show title *')),
                TextField(
                    controller: seriesId,
                    decoration: const InputDecoration(
                        labelText: 'Series metadata ID (optional)')),
                Row(children: [
                  Expanded(
                      child: TextField(
                          controller: season,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Season *'))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: TextField(
                          controller: episode,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Episode *'))),
                ]),
                TextField(
                    controller: title,
                    decoration: const InputDecoration(
                        labelText: 'Episode title (optional)')),
                TextField(
                    controller: overview,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                        labelText: 'Official episode description (optional)')),
                TextField(
                    controller: notes,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                        labelText: 'Opening-scene notes',
                        hintText:
                            'Starts with a fire\nTwo characters in the woods\nA body is discovered')),
                TextField(
                    controller: tags,
                    decoration: const InputDecoration(
                        labelText: 'Search tags (comma separated)',
                        hintText: 'fire, woods, dead body')),
                TextField(
                    controller: disc,
                    decoration: const InputDecoration(
                        labelText: 'Disc label (optional)')),
                TextField(
                    controller: armTitle,
                    decoration: const InputDecoration(
                        labelText: 'ARM / MakeMKV title ID (optional)')),
                TextField(
                    controller: duration,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Duration in seconds (optional)')),
                const SizedBox(height: 8),
                const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                        'Notes are personal identification hints, not official episode synopses.',
                        style: TextStyle(color: Colors.white60, fontSize: 12))),
              ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: _saving
                    ? null
                    : () async {
                        final seasonNumber = int.tryParse(season.text.trim());
                        final episodeNumber = int.tryParse(episode.text.trim());
                        if (show.text.trim().isEmpty ||
                            seasonNumber == null ||
                            seasonNumber < 0 ||
                            episodeNumber == null ||
                            episodeNumber < 0) {
                          _message(
                              'Enter a show title and valid season/episode numbers.',
                              error: true);
                          return;
                        }
                        setState(() => _saving = true);
                        try {
                          await _app.backendApi.saveEpisodeIdentificationNote(
                            profileId: _profileId,
                            seriesTitle: show.text.trim(),
                            seriesId: seriesId.text.trim().isEmpty
                                ? null
                                : seriesId.text.trim(),
                            seasonNumber: seasonNumber,
                            episodeNumber: episodeNumber,
                            episodeTitle: title.text.trim().isEmpty
                                ? null
                                : title.text.trim(),
                            officialOverview: overview.text.trim().isEmpty
                                ? null
                                : overview.text.trim(),
                            openingNotes: notes.text
                                .split('\n')
                                .map((v) => v.trim())
                                .where((v) => v.isNotEmpty)
                                .toList(),
                            tags: tags.text
                                .split(',')
                                .map((v) => v.trim())
                                .where((v) => v.isNotEmpty)
                                .toList(),
                            durationSeconds:
                                int.tryParse(duration.text.trim()) ?? 0,
                            discLabel: disc.text.trim().isEmpty
                                ? null
                                : disc.text.trim(),
                            armTitleId: armTitle.text.trim().isEmpty
                                ? null
                                : armTitle.text.trim(),
                          );
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          await _refresh();
                          _message('Episode identification note saved.');
                        } catch (error) {
                          _message('Could not save episode note: $error',
                              error: true);
                        } finally {
                          if (mounted) setState(() => _saving = false);
                        }
                      },
                child: Text(_saving ? 'Saving…' : 'Save episode note')),
          ],
        ),
      );
    } finally {
      for (final controller in [
        show,
        seriesId,
        season,
        episode,
        title,
        overview,
        notes,
        tags,
        disc,
        armTitle,
        duration
      ]) {
        controller.dispose();
      }
    }
  }

  Future<void> _openDiscMappingEditor() async {
    final existingMapping = _matchedDiscMapping;
    final fingerprint = TextEditingController(
        text: widget.initialDiscFingerprint ??
            existingMapping?['discFingerprint']?.toString() ??
            '');
    final label = TextEditingController(
        text: widget.initialDiscLabel ??
            existingMapping?['discLabel']?.toString() ??
            '');
    final show = TextEditingController(
        text: existingMapping?['seriesTitle']?.toString() ?? '');
    final season = TextEditingController(
        text: existingMapping?['seasonNumber']?.toString() ?? '');
    final savedTitles = _rows(existingMapping?['titleMappings']);
    final mappings = TextEditingController(
        text: widget.detectedTitleSummaries.isNotEmpty
            ? widget.detectedTitleSummaries.map((summary) {
                final titleNumber =
                    ((summary['titleIndex'] as num?)?.toInt() ?? 0) + 1;
                Map<String, dynamic>? saved;
                for (final row in savedTitles) {
                  if ((row['titleNumber'] as num?)?.toInt() == titleNumber) {
                    saved = row;
                    break;
                  }
                }
                final episodeNumber = saved?['episodeNumber']?.toString() ?? '';
                final episodeTitle = saved?['episodeTitle']?.toString() ?? '';
                final openingRaw = saved?['openingNotes'];
                final opening = openingRaw is List ? openingRaw.join('; ') : '';
                return '$titleNumber | $episodeNumber | $episodeTitle | $opening';
              }).join('\n')
            : savedTitles
                .map((row) =>
                    '${row['titleNumber'] ?? (((row['titleIndex'] as num?)?.toInt() ?? 0) + 1)} | ${row['episodeNumber'] ?? ''} | ${row['episodeTitle'] ?? ''} | ${row['openingNotes'] is List ? (row['openingNotes'] as List).join('; ') : ''}')
                .join('\n'));
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Remember this disc'),
          content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: label,
                    decoration: const InputDecoration(labelText: 'Disc label')),
                TextField(
                    controller: fingerprint,
                    decoration: const InputDecoration(
                        labelText: 'Disc fingerprint *',
                        helperText:
                            'Auto-generated from the MakeMKV title manifest. Use a custom stable ID only for manual mappings.')),
                TextField(
                    controller: show,
                    decoration:
                        const InputDecoration(labelText: 'TV show title *')),
                TextField(
                    controller: season,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Season number *')),
                TextField(
                    controller: mappings,
                    minLines: 4,
                    maxLines: 10,
                    decoration: const InputDecoration(
                        labelText: 'Detected title-to-episode notes',
                        helperText:
                            'One row per detected title: title number | episode number | episode title | opening-scene clue. Example: 1 | 3 | The Fire | Opens with a burning house.')),
              ]))),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () async {
                  final seasonNumber = int.tryParse(season.text.trim());
                  if (fingerprint.text.trim().isEmpty ||
                      show.text.trim().isEmpty ||
                      seasonNumber == null ||
                      seasonNumber < 0) {
                    _message(
                        'A disc fingerprint, show title, and valid season are required.',
                        error: true);
                    return;
                  }
                  final titleMappings = <Map<String, dynamic>>[];
                  for (final line in mappings.text
                      .split('\n')
                      .where((line) => line.trim().isNotEmpty)) {
                    final parts =
                        line.split('|').map((part) => part.trim()).toList();
                    final displayTitleNumber =
                        parts.isNotEmpty ? int.tryParse(parts[0]) : null;
                    if (displayTitleNumber == null || displayTitleNumber < 1) {
                      continue;
                    }
                    titleMappings.add({
                      'titleNumber': displayTitleNumber,
                      'titleIndex': displayTitleNumber - 1,
                      'episodeNumber':
                          parts.length > 1 ? int.tryParse(parts[1]) : null,
                      'episodeTitle': parts.length > 2 ? parts[2] : '',
                      'openingNotes': parts.length > 3 && parts[3].isNotEmpty
                          ? [parts.sublist(3).join(' | ')]
                          : <String>[],
                    });
                  }
                  try {
                    await _app.backendApi.saveDiscEpisodeMapping(
                      profileId: _profileId,
                      discFingerprint: fingerprint.text.trim(),
                      discLabel:
                          label.text.trim().isEmpty ? null : label.text.trim(),
                      seriesTitle: show.text.trim(),
                      seasonNumber: seasonNumber,
                      titleMappings: titleMappings,
                    );
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                    await _refresh();
                    _message(
                        'Disc mapping saved. The Disc Ingestion Center can suggest it when the same title manifest is scanned again.');
                  } catch (error) {
                    _message('Could not save disc mapping: $error',
                        error: true);
                  }
                },
                child: const Text('Save disc mapping')),
          ],
        ),
      );
    } finally {
      fingerprint.dispose();
      label.dispose();
      show.dispose();
      season.dispose();
      mappings.dispose();
    }
  }

  Future<void> _openPreservationRecordEditor() async {
    final title = TextEditingController();
    final disc = TextEditingController(text: widget.initialDiscLabel ?? '');
    String type = 'tv';
    String status = 'queued';
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
                  title: const Text('Add preservation record'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(
                        controller: title,
                        decoration:
                            const InputDecoration(labelText: 'Media title *')),
                    TextField(
                        controller: disc,
                        decoration: const InputDecoration(
                            labelText: 'Disc / source label')),
                    DropdownButtonFormField<String>(
                        initialValue: type,
                        decoration:
                            const InputDecoration(labelText: 'Media type'),
                        items: const [
                          DropdownMenuItem(
                              value: 'movie', child: Text('Movie')),
                          DropdownMenuItem(
                              value: 'tv', child: Text('TV episode / season')),
                          DropdownMenuItem(
                              value: 'music', child: Text('Music')),
                        ],
                        onChanged: (value) {
                          if (value != null) setDialogState(() => type = value);
                        }),
                    DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: const [
                          DropdownMenuItem(
                              value: 'queued', child: Text('Queued')),
                          DropdownMenuItem(
                              value: 'ripping', child: Text('Ripping')),
                          DropdownMenuItem(
                              value: 'completed', child: Text('Completed')),
                          DropdownMenuItem(
                              value: 'needs-review',
                              child: Text('Needs review')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => status = value);
                          }
                        }),
                  ]),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () async {
                          if (title.text.trim().isEmpty) {
                            _message('Enter a media title.', error: true);
                            return;
                          }
                          try {
                            await _app.backendApi.savePreservationRecord(
                              profileId: _profileId,
                              title: title.text.trim(),
                              mediaType: type,
                              source: 'disc',
                              status: status,
                              verificationStatus: status == 'completed'
                                  ? 'pending'
                                  : 'not-ready',
                              discLabel: disc.text.trim().isEmpty
                                  ? null
                                  : disc.text.trim(),
                            );
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            await _refresh();
                            _message('Preservation record saved.');
                          } catch (error) {
                            _message(
                                'Unable to save preservation record: $error',
                                error: true);
                          }
                        },
                        child: const Text('Save record')),
                  ],
                )),
      );
    } finally {
      title.dispose();
      disc.dispose();
    }
  }

  Future<void> _openTicketUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      _message('Only secure HTTPS ticket links can be opened.', error: true);
      return;
    }
    // Use the app's existing external-link handling on the ticket source.
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _message('Unable to open the ticket link.', error: true);
    }
  }

  Future<void> _openConcertEditor() async {
    final artist = TextEditingController();
    final city = TextEditingController();
    final venue = TextEditingController();
    final ticket = TextEditingController();
    DateTime eventDate = DateTime.now().add(const Duration(days: 30));
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
                  title: const Text('Track a concert or tour date'),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(
                        controller: artist,
                        decoration: const InputDecoration(
                            labelText: 'Artist / band *')),
                    TextField(
                        controller: city,
                        decoration: const InputDecoration(labelText: 'City')),
                    TextField(
                        controller: venue,
                        decoration: const InputDecoration(labelText: 'Venue')),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_month_rounded),
                      title: const Text('Event date'),
                      subtitle: Text(
                          '${eventDate.year}-${eventDate.month.toString().padLeft(2, '0')}-${eventDate.day.toString().padLeft(2, '0')}'),
                      onTap: () async {
                        final picked = await showDatePicker(
                            context: dialogContext,
                            initialDate: eventDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100));
                        if (picked != null) {
                          setDialogState(() => eventDate = picked);
                        }
                      },
                    ),
                    TextField(
                        controller: ticket,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                            labelText:
                                'Official ticket link (HTTPS, optional)')),
                  ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () async {
                          if (artist.text.trim().isEmpty) {
                            _message('Enter the artist or band.', error: true);
                            return;
                          }
                          try {
                            await _app.backendApi.saveConcertTrackingEntry(
                              profileId: _profileId,
                              artist: artist.text.trim(),
                              eventDate: DateTime(eventDate.year,
                                      eventDate.month, eventDate.day)
                                  .toIso8601String(),
                              city: city.text.trim(),
                              venue: venue.text.trim(),
                              ticketUrl: ticket.text.trim().isEmpty
                                  ? null
                                  : ticket.text.trim(),
                            );
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            await _refresh();
                            _message('Concert date saved to your profile.');
                          } catch (error) {
                            _message('Unable to save concert: $error',
                                error: true);
                          }
                        },
                        child: const Text('Save date')),
                  ],
                )),
      );
    } finally {
      artist.dispose();
      city.dispose();
      venue.dispose();
      ticket.dispose();
    }
  }

  Future<void> _artistRadio() async {
    final artist = TextEditingController();
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Start Artist Radio'),
          content: TextField(
              controller: artist,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Artist or band')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () async {
                  if (artist.text.trim().isEmpty) return;
                  try {
                    final result = await _app.backendApi
                        .getRelatedMusicArtists(artist.text.trim());
                    final related = _rows(result['items']);
                    if (!dialogContext.mounted || !mounted) return;
                    Navigator.pop(dialogContext);
                    await showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                              title: Text(
                                  '${artist.text.trim()} Radio · ListenBrainz'),
                              content: SizedBox(
                                  width: 420,
                                  child: related.isEmpty
                                      ? const Text(
                                          'No related artist results were returned by the configured metadata sources.')
                                      : ListView(
                                          shrinkWrap: true,
                                          children: related
                                              .map((row) => ListTile(
                                                    leading: const Icon(Icons
                                                        .person_outline_rounded),
                                                    title: Text((row['name'] ??
                                                            row['artist'] ??
                                                            'Artist')
                                                        .toString()),
                                                    subtitle: Text(
                                                        '${row['similarityReason'] ?? row['relation'] ?? 'Related artist'} · ${(row['recordingCount'] ?? 0)} candidate recordings'),
                                                  ))
                                              .toList())),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Close'))
                              ],
                            ));
                  } catch (error) {
                    _message('Artist Radio could not load: $error',
                        error: true);
                  }
                },
                child: const Text('Find related artists')),
          ],
        ),
      );
    } finally {
      artist.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal Media Intelligence'),
        actions: [
          IconButton(
              tooltip: 'Refresh',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded)),
          PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'identify') {
                  Navigator.of(context)
                      .push(MaterialPageRoute<void>(
                          builder: (_) => const SongIdentificationScreen()))
                      .then((_) => _refresh());
                }
                if (value == 'catalog') {
                  Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => const MusicCatalogScreen()));
                }
                if (value == 'ripping') {
                  Navigator.of(context)
                      .push(MaterialPageRoute<void>(
                          builder: (_) => const DiscIngestionCenterScreen()))
                      .then((_) => _refresh());
                }
              },
              itemBuilder: (_) => const [
                    PopupMenuItem(
                        value: 'identify', child: Text('Identify a song')),
                    PopupMenuItem(
                        value: 'catalog', child: Text('Explore music catalog')),
                    PopupMenuItem(
                        value: 'ripping',
                        child: Text('Open Disc Ingestion Center')),
                  ]),
        ],
        bottom: TabBar(controller: _tabs, isScrollable: true, tabs: const [
          Tab(icon: Icon(Icons.music_note_rounded), text: 'Music'),
          Tab(icon: Icon(Icons.tv_rounded), text: 'Episode Notebook'),
          Tab(icon: Icon(Icons.archive_outlined), text: 'Preservation'),
          Tab(icon: Icon(Icons.timeline_rounded), text: 'Timeline'),
        ]),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_authenticated
              ? _emptyState(
                  'Profile sign-in required',
                  _error ??
                      'Sign in and choose a profile to sync your personal media data.',
                  Icons.person_outline_rounded)
              : Column(children: [
                  if (_error != null)
                    MaterialBanner(
                      content: Text(_error!),
                      actions: [
                        TextButton(
                            onPressed: _refresh, child: const Text('Retry'))
                      ],
                    ),
                  Expanded(
                      child: TabBarView(controller: _tabs, children: [
                    _musicTab(theme),
                    _episodeTab(theme),
                    _preservationTab(theme),
                    _timelineTab(theme),
                  ])),
                ]),
    );
  }

  Widget _musicTab(ThemeData theme) {
    final topArtists = _rows(_musicStats['topArtists']);
    final topSongs = _rows(_musicStats['topSongs']);
    return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          _heroCard(
              'Your Music Memory',
              'Identified songs and playback events build your own statistics. Recognition is tracked separately from actual listening time.',
              Icons.graphic_eq_rounded,
              const Color(0xFFB69AFF)),
          const SizedBox(height: 10),
          Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                const Text('Top 10 chart scope',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                DropdownButton<String>(
                    value: _chartScope,
                    items: const [
                      DropdownMenuItem(
                          value: 'profile', child: Text('Profile')),
                      DropdownMenuItem(
                          value: 'account', child: Text('Account')),
                      DropdownMenuItem(value: 'global', child: Text('Global')),
                    ],
                    onChanged: _changeChartScope),
                if (_chartScope != 'global')
                  DropdownButton<int>(
                    value: _selectedMusicYear,
                    items: List<int>.generate(
                            7, (index) => DateTime.now().year - index)
                        .map((year) =>
                            DropdownMenuItem(value: year, child: Text('$year')))
                        .toList(),
                    onChanged: _changeMusicYear,
                  ),
              ]),
          if (_chartScopeError != null)
            Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_chartScopeError!,
                    style: const TextStyle(color: Colors.orangeAccent))),
          if (_chartScope == 'global')
            const Text(
                'Global charts are ListenBrainz sitewide listening statistics, not a measure of every listener worldwide.',
                style: TextStyle(color: Colors.white60, fontSize: 12)),
          if (_chartScope == 'account')
            const Text(
                'Account charts include this profile and only other profiles that opted into sharing their history.',
                style: TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 12),
          if (_chartScope != 'global')
            Wrap(spacing: 8, runSpacing: 8, children: [
              _metric('Played', '${_musicStats['playCount'] ?? 0}',
                  Icons.play_circle_outline_rounded),
              _metric('Identified', '${_musicStats['identifiedCount'] ?? 0}',
                  Icons.graphic_eq_rounded),
              _metric(
                  'Completed minutes',
                  '${_musicStats['listeningMinutes'] ?? 0}',
                  Icons.timer_outlined),
              _metric('Artists', '${_musicStats['uniqueArtists'] ?? 0}',
                  Icons.person_outline_rounded),
            ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute<void>(
                        builder: (_) => const SongIdentificationScreen()))
                    .then((_) => _refresh()),
                icon: const Icon(Icons.mic_rounded),
                label: const Text('Identify Song')),
            OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const MusicCatalogScreen())),
                icon: const Icon(Icons.library_music_rounded),
                label: const Text('Music Catalog')),
            OutlinedButton.icon(
                onPressed: _artistRadio,
                icon: const Icon(Icons.radio_rounded),
                label: const Text('Artist Radio')),
          ]),
          const SizedBox(height: 16),
          _sectionTitle(_chartScope == 'global'
              ? 'Global Top 10'
              : 'Your Music Wrapped · $_selectedMusicYear'),
          if (_chartScope != 'global')
            _monthlyPlaysSection(_musicStats['monthlyPlays']),
          _topList('Top 10 Artists', topArtists),
          _topList('Top 10 Songs', topSongs),
          _topList('Top 10 Albums', _rows(_musicStats['topAlbums'])),
          _topList('Top Genres', _rows(_musicStats['topGenres'])),
          if (_chartScope != 'global') _musicDnaCard(),
          if (_chartScope != 'global') _smartPlaylistsSection(),
          _sectionTitle('Recently identified and played'),
          if (_musicHistory.isEmpty)
            _emptyInline(
                'No music events yet. Identify a song or record playback events from your music player.')
          else
            ..._musicHistory.reversed
                .take(30)
                .toList()
                .reversed
                .map((row) => _musicEventTile(row)),
          const SizedBox(height: 12),
          _sectionTitle('Release Radar'),
          const Text(
              'Known upcoming album releases from MusicBrainz. Availability and dates depend on provider metadata.',
              style: TextStyle(color: Colors.white60, fontSize: 12)),
          Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _loadingReleaseRadar ? null : _loadReleaseRadar,
                icon: _loadingReleaseRadar
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.event_available_rounded),
                label: Text(_loadingReleaseRadar
                    ? 'Loading releases…'
                    : 'Load upcoming releases'),
              )),
          if (_releaseRadarError != null)
            Text(_releaseRadarError!,
                style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ..._upcomingAlbums.take(12).map((row) => ListTile(
                dense: true,
                leading: const Icon(Icons.album_outlined),
                title: Text((row['title'] ?? 'Untitled release').toString()),
                subtitle: Text(
                    '${row['artist'] ?? 'Unknown artist'} · ${row['releaseDate'] ?? 'Date not announced'}'),
                trailing: Text((row['primaryType'] ?? '').toString(),
                    style:
                        const TextStyle(fontSize: 10, color: Colors.white54)),
              )),
          const SizedBox(height: 12),
          _sectionTitle('Concert & Tour Tracker'),
          const Text(
              'Save tour dates you know about. Automatic concert discovery still needs an event-data provider; this tracker does not invent events.',
              style: TextStyle(color: Colors.white60, fontSize: 12)),
          Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                  onPressed: _openConcertEditor,
                  icon: const Icon(Icons.add_location_alt_rounded),
                  label: const Text('Add concert date'))),
          if (_concerts.isEmpty)
            _emptyInline('No concert dates saved yet.')
          else
            ..._concerts.map((event) => Card(
                    child: ListTile(
                  leading: const Icon(Icons.event_rounded),
                  title: Text((event['artist'] ?? 'Artist').toString()),
                  subtitle: Text(
                      '${event['eventDate'] ?? ''} · ${event['venue'] ?? 'Venue unknown'} · ${event['city'] ?? ''}'),
                  trailing: (event['ticketUrl'] ?? '').toString().isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.open_in_new_rounded),
                          onPressed: () =>
                              _openTicketUrl(event['ticketUrl'].toString())),
                ))),
          const SizedBox(height: 20),
        ]));
  }

  Widget _musicDnaCard() {
    final genreRows = _rows(_musicStats['topGenres']);
    final artistCount = _musicStats['uniqueArtists'] ??
        _musicHistory
            .where((row) => row['eventType'] == 'played')
            .map((row) => row['artist']?.toString().toLowerCase())
            .whereType<String>()
            .toSet()
            .length;
    final monthRows = _musicStats['monthlyPlays'] is Map
        ? Map<String, dynamic>.from(_musicStats['monthlyPlays'] as Map)
        : <String, dynamic>{};
    final mostActive = monthRows.entries.toList()
      ..sort((a, b) => (b.value as num).compareTo(a.value as num));
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Your Music DNA',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 6),
              Text(
                  '$artistCount distinct artists in the selected listening period.',
                  style: const TextStyle(color: Colors.white70)),
              if (genreRows.isNotEmpty)
                Text(
                    'Leading genres: ${genreRows.take(5).map((row) => row['name']).join(' · ')}',
                    style: const TextStyle(color: Colors.white70)),
              if (mostActive.isNotEmpty)
                Text(
                    'Most active month: ${mostActive.first.key} (${mostActive.first.value} plays)',
                    style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 4),
              const Text(
                  'This is an early listening-history snapshot; decade preferences and influence graphs need richer track metadata.',
                  style: TextStyle(fontSize: 11, color: Colors.white54)),
            ])));
  }

  List<Map<String, dynamic>> _smartPlaylist(String kind) {
    final played =
        _musicHistory.where((row) => row['eventType'] == 'played').toList();
    final identified =
        _musicHistory.where((row) => row['eventType'] == 'identified').toList();
    if (kind == 'discoveries') {
      final seen = <String>{};
      return identified.reversed
          .where((row) {
            final key = '${row['title']}|${row['artist']}'.toLowerCase();
            return seen.add(key);
          })
          .take(10)
          .toList();
    }
    if (kind == 'recent') return identified.reversed.take(10).toList();
    final counts = <String, int>{};
    final latest = <String, DateTime>{};
    final rowsByKey = <String, Map<String, dynamic>>{};
    for (final row in played) {
      final key = '${row['title']}|${row['artist']}'.toLowerCase();
      counts[key] = (counts[key] ?? 0) + 1;
      rowsByKey[key] = row;
      final date = DateTime.tryParse(row['recordedAt']?.toString() ?? '');
      if (date != null && (latest[key] == null || date.isAfter(latest[key]!))) {
        latest[key] = date;
      }
    }
    final keys = counts.keys.toList();
    if (kind == 'forgotten') {
      keys.removeWhere((key) =>
          counts[key]! < 2 ||
          latest[key] == null ||
          DateTime.now().difference(latest[key]!) < const Duration(days: 45));
      keys.sort((a, b) => latest[a]!.compareTo(latest[b]!));
    } else {
      keys.sort((a, b) => counts[b]!.compareTo(counts[a]!));
    }
    return keys
        .take(kind == 'top100' ? 100 : 10)
        .map((key) => rowsByKey[key]!)
        .toList();
  }

  Widget _smartPlaylistsSection() {
    final playlists = <(String, String, String)>[
      (
        'My Discoveries',
        'Tracks you identified with Identify Song',
        'discoveries'
      ),
      (
        'Forgotten Favorites',
        'Repeatedly played songs not heard recently',
        'forgotten'
      ),
      ('Recently Identified', 'Your latest song recognition matches', 'recent'),
      (
        'All-Time Top 100',
        'Most-played songs retained in your listening history',
        'top100'
      ),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('Smart Playlist Suggestions'),
      ...playlists.map((playlist) {
        final tracks = _smartPlaylist(playlist.$3);
        return Card(
            child: ExpansionTile(
          leading: const Icon(Icons.queue_music_rounded),
          title: Text(playlist.$1),
          subtitle: Text('${tracks.length} track(s) · ${playlist.$2}'),
          children: tracks.isEmpty
              ? [
                  const ListTile(
                      title: Text('No matching tracks yet',
                          style: TextStyle(color: Colors.white54)))
                ]
              : tracks
                  .take(8)
                  .map((track) => ListTile(
                        dense: true,
                        title:
                            Text((track['title'] ?? 'Unknown song').toString()),
                        subtitle: Text(
                            (track['artist'] ?? 'Unknown artist').toString()),
                      ))
                  .toList(),
        ));
      }),
      const Text(
          'These are live playlist suggestions derived from saved history. They do not modify or duplicate your existing music playlists.',
          style: TextStyle(fontSize: 11, color: Colors.white54)),
    ]);
  }

  Widget _monthlyPlaysSection(dynamic raw) {
    final values =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final entries = values.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    if (entries.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('Monthly listening activity'),
      ...entries.map((entry) => ListTile(
            dense: true,
            leading: const Icon(Icons.calendar_month_rounded),
            title: Text(entry.key),
            trailing: Text('${entry.value} plays',
                style: const TextStyle(fontWeight: FontWeight.w700)),
          )),
    ]);
  }

  Widget _episodeTab(ThemeData theme) => RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        _heroCard(
            'Episode Identification Notebook',
            'Remember opening scenes, distinctive moments, episode order and disc-title matches so you can identify what each rip contains.',
            Icons.video_library_rounded,
            const Color(0xFFFFC278)),
        if (_matchedDiscMapping != null)
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(children: [
                          Icon(Icons.history_rounded,
                              color: Colors.greenAccent),
                          SizedBox(width: 8),
                          Text('Previously identified disc',
                              style: TextStyle(fontWeight: FontWeight.w800))
                        ]),
                        const SizedBox(height: 6),
                        Text(
                            '${_matchedDiscMapping!['seriesTitle']} · Season ${_matchedDiscMapping!['seasonNumber']}'),
                        ..._rows(_matchedDiscMapping!['titleMappings']).map(
                            (row) => Text(
                                'Title ${row['titleNumber'] ?? (((row['titleIndex'] as num?)?.toInt() ?? 0) + 1)} → ${row['episodeNumber'] == null ? 'Episode not assigned' : 'Episode ${row['episodeNumber']}'}${(row['episodeTitle'] ?? '').toString().isEmpty ? '' : ' · ${row['episodeTitle']}'}',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.white70))),
                        TextButton.icon(
                            onPressed: _openDiscMappingEditor,
                            icon: const Icon(Icons.edit_rounded),
                            label: const Text(
                                'Review or update remembered mapping')),
                      ]))),
        if (widget.detectedTitleSummaries.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                            'Detected disc titles from the ripping workflow',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        ...widget.detectedTitleSummaries.map((row) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.movie_outlined),
                            title: Text(
                                (row['title'] ?? 'Detected title').toString()),
                            subtitle:
                                Text((row['duration'] ?? '').toString()))),
                        OutlinedButton.icon(
                            onPressed: _openDiscMappingEditor,
                            icon: const Icon(Icons.save_as_rounded),
                            label:
                                const Text('Remember disc-to-episode mapping')),
                      ]))),
        ],
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(
              onPressed: _importSeasonGuide,
              icon: const Icon(Icons.cloud_download_rounded),
              label: const Text('Import episode guide')),
          OutlinedButton.icon(
              onPressed: () => _openNoteEditor(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add episode note')),
          OutlinedButton.icon(
              onPressed: _openDiscMappingEditor,
              icon: const Icon(Icons.disc_full_rounded),
              label: const Text('Save disc mapping')),
        ]),
        const SizedBox(height: 14),
        _sectionTitle('Saved episode identification notes'),
        if (_episodeNotes.isEmpty)
          _emptyInline(
              'No episode notes yet. Add a show, season, episode number and opening-scene clues.')
        else
          ..._episodeNotes.map((note) => Card(
                  child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.tv_rounded)),
                title: Text(
                    '${note['seriesTitle'] ?? 'TV Show'} · S${((note['seasonNumber'] as num?)?.toInt() ?? 0).toString().padLeft(2, '0')}E${((note['episodeNumber'] as num?)?.toInt() ?? 0).toString().padLeft(2, '0')}'),
                subtitle: Text([
                  if ((note['episodeTitle'] ?? '').toString().isNotEmpty)
                    note['episodeTitle'].toString(),
                  if ((note['officialOverview'] ?? '').toString().isNotEmpty)
                    note['officialOverview'].toString(),
                  if (note['openingNotes'] is List)
                    (note['openingNotes'] as List).join(' · '),
                  if ((note['discLabel'] ?? '').toString().isNotEmpty)
                    'Disc: ${note['discLabel']}',
                ].join('\n')),
                isThreeLine: true,
                trailing: IconButton(
                    tooltip: 'Edit note',
                    onPressed: () => _openNoteEditor(existing: note),
                    icon: const Icon(Icons.edit_outlined)),
              ))),
        const SizedBox(height: 14),
        _sectionTitle('Remembered discs'),
        if (_discMappings.isEmpty)
          _emptyInline('No disc-to-episode mappings have been saved.')
        else
          ..._discMappings.map((mapping) => Card(
                  child: ListTile(
                leading: const Icon(Icons.album_outlined),
                title: Text((mapping['discLabel'] ??
                        mapping['discFingerprint'] ??
                        'Disc')
                    .toString()),
                subtitle: Text(
                    '${mapping['seriesTitle'] ?? 'TV show'} · Season ${mapping['seasonNumber'] ?? '?'} · ${_rows(mapping['titleMappings']).length} title mapping(s)'),
              ))),
      ]));

  Widget _preservationTab(ThemeData theme) => RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        _heroCard(
            'Media Preservation Center',
            'Track physical sources, ripping status, verification, metadata review and the items still waiting for identification.',
            Icons.inventory_2_rounded,
            const Color(0xFF8FD4C2)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _metric('Records', '${_preservationRecords.length}',
              Icons.inventory_2_outlined),
          _metric(
              'Needs review',
              '${_preservationRecords.where((r) => r['status'] == 'needs-review').length}',
              Icons.rule_rounded),
          _metric(
              'Completed',
              '${_preservationRecords.where((r) => r['status'] == 'completed').length}',
              Icons.verified_outlined),
          _metric(
              'ARM drives', '${_armDrives.length}', Icons.disc_full_rounded),
        ]),
        const SizedBox(height: 12),
        Card(
            child: ListTile(
          leading: Icon(_armStatus?['connected'] == true
              ? Icons.cloud_done_rounded
              : Icons.cloud_off_rounded),
          title: Text(_armStatus?['connected'] == true
              ? 'ARM service connected'
              : 'ARM service not connected'),
          subtitle: Text(_armDrives.isEmpty
              ? 'No ARM drives reported. The local MakeMKV workflow can still be opened on the desktop.'
              : '${_armDrives.length} drive(s) visible to ARM.'),
          trailing: IconButton(
              tooltip: 'Refresh ARM status',
              onPressed: _loadArmStatus,
              icon: const Icon(Icons.refresh_rounded)),
        )),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute<void>(
                      builder: (_) => const DiscIngestionCenterScreen()))
                  .then((_) => _refresh()),
              icon: const Icon(Icons.album_rounded),
              label: const Text('Open Disc Ingestion Center')),
          OutlinedButton.icon(
              onPressed: _openPreservationRecordEditor,
              icon: const Icon(Icons.add_box_outlined),
              label: const Text('Add preservation record')),
        ]),
        const SizedBox(height: 14),
        _sectionTitle('Preservation inventory'),
        if (_preservationRecords.isEmpty)
          _emptyInline(
              'No preservation records yet. Add a record or use the disc-ripping workflow.')
        else
          ..._preservationRecords.reversed.map((record) => Card(
                  child: ListTile(
                leading: const Icon(Icons.archive_outlined),
                title: Text((record['title'] ?? 'Untitled media').toString()),
                subtitle: Text(
                    '${record['mediaType'] ?? 'Media'} · ${record['source'] ?? 'source'}\n${record['status'] ?? 'queued'} · verification: ${record['verificationStatus'] ?? 'pending'}'),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right_rounded),
              ))),
        const SizedBox(height: 14),
        _sectionTitle('Unidentified media queue'),
        if (_preservationRecords
            .where((r) =>
                r['status'] == 'needs-review' ||
                r['verificationStatus'] == 'pending')
            .isEmpty)
          _emptyInline('Nothing is waiting for identification or verification.')
        else
          ..._preservationRecords
              .where((r) =>
                  r['status'] == 'needs-review' ||
                  r['verificationStatus'] == 'pending')
              .map((record) => ListTile(
                  leading: const Icon(Icons.help_outline_rounded),
                  title: Text((record['title'] ?? 'Unknown media').toString()),
                  subtitle: Text(
                      'Status: ${record['status']} · ${record['verificationStatus']}'))),
      ]));

  Widget _timelineTab(ThemeData theme) => RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        _heroCard(
            'My Entertainment Memory',
            'A unified record of your music discoveries, listening sessions, episode-identification work and physical-media preservation.',
            Icons.auto_awesome_rounded,
            const Color(0xFF9CC8FF)),
        const SizedBox(height: 12),
        if (_timeline.isEmpty)
          _emptyInline(
              'Your timeline will grow as you identify songs, listen to music, save episode notes and preserve media.')
        else
          ..._timeline.map((event) => Card(
                  child: ListTile(
                leading: Icon(_timelineIcon(event['type']?.toString() ?? '')),
                title: Text(
                    (event['title'] ?? 'Entertainment activity').toString()),
                subtitle: Text([
                  if ((event['subtitle'] ?? '').toString().isNotEmpty)
                    event['subtitle'].toString(),
                  if ((event['timestamp'] ?? '').toString().isNotEmpty)
                    _dateLabel(event['timestamp'].toString()),
                ].join('\n')),
                isThreeLine: true,
              ))),
      ]));

  IconData _timelineIcon(String type) {
    if (type.contains('song') || type.contains('music')) {
      return Icons.music_note_rounded;
    }
    if (type.contains('episode')) return Icons.tv_rounded;
    if (type.contains('preservation')) return Icons.archive_rounded;
    return Icons.history_rounded;
  }

  String _dateLabel(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return value;
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _musicEventTile(Map<String, dynamic> row) {
    final identified = row['eventType'] == 'identified';
    return ListTile(
      leading: CircleAvatar(
          child: Icon(identified
              ? Icons.graphic_eq_rounded
              : Icons.play_arrow_rounded)),
      title: Text((row['title'] ?? 'Unknown song').toString()),
      subtitle: Text(
          '${row['artist'] ?? 'Unknown artist'}${(row['album'] ?? '').toString().isEmpty ? '' : ' · ${row['album']}'}\n${identified ? 'Identified' : 'Played'} · ${_dateLabel((row['recordedAt'] ?? '').toString())}'),
      isThreeLine: true,
    );
  }

  Widget _topList(String title, List<Map<String, dynamic>> rows) => Card(
          child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          if (rows.isEmpty)
            const Text('Not enough listening history yet.',
                style: TextStyle(color: Colors.white60))
          else
            ...rows.take(10).toList().asMap().entries.map((entry) => ListTile(
                  dense: true,
                  leading: CircleAvatar(
                      radius: 14,
                      child: Text('${entry.key + 1}',
                          style: const TextStyle(fontSize: 12))),
                  title: Text((entry.value['name'] ?? 'Unknown').toString()),
                  trailing: Text('${entry.value['plays'] ?? 0} plays',
                      style:
                          const TextStyle(color: Colors.white60, fontSize: 12)),
                )),
        ]),
      ));

  Widget _heroCard(
          String title, String subtitle, IconData icon, Color accent) =>
      Card(
        clipBehavior: Clip.antiAlias,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
            accent.withValues(alpha: .24),
            Theme.of(context).colorScheme.surfaceContainerHighest
          ], begin: Alignment.topLeft, end: Alignment.bottomRight)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 32, color: accent),
            const SizedBox(height: 8),
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(color: Colors.white70, height: 1.4)),
          ]),
        ),
      );

  Widget _metric(String label, String value, IconData icon) => SizedBox(
        width: 150,
        child: Card(
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon,
                          size: 20,
                          color: Theme.of(context).colorScheme.secondary),
                      const SizedBox(height: 8),
                      Text(value,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900)),
                      Text(label,
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 12)),
                    ]))),
      );

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
        child: Text(title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w900)),
      );

  Widget _emptyInline(String message) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(message,
              style: const TextStyle(color: Colors.white60, height: 1.4))));

  Widget _emptyState(String title, String message, IconData icon) => Center(
      child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 48, color: Colors.white38),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60)),
          ])));
}
