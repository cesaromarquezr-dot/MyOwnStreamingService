import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_core.dart';
import 'details.dart';
import 'genre_system.dart';
import 'media_feature_preferences.dart';
import 'music.dart';
import 'social_center.dart';
import 'watch_and_enjoy.dart';
import 'watch_party_lobby.dart';

const Color _toolsBackground = Color(0xFF0B0B10);
const Color _toolsPanel = Color(0xFF171722);
const Color _toolsAccent = Color(0xFF8B7CFF);

class MediaAvailabilityRadarScreen extends StatefulWidget {
  const MediaAvailabilityRadarScreen({super.key});

  @override
  State<MediaAvailabilityRadarScreen> createState() => _MediaAvailabilityRadarScreenState();
}

class _MediaAvailabilityRadarScreenState extends State<MediaAvailabilityRadarScreen> {
  String _query = '';
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final library = AppController.instance.library;
    final tracks = MusicLibraryStore.instance.tracks;
    final visible = library.where((item) {
      final text = '${item.title} ${item.description ?? ''} ${item.genres.join(' ')}'.toLowerCase();
      if (_query.trim().isNotEmpty && !text.contains(_query.trim().toLowerCase())) return false;
      return switch (_filter) {
        'Playable in personal library' => MediaNightFeatureLogic.availability(item) == CatalogAvailabilityKind.personalPlayback,
        'Physical copy recorded' => MediaNightFeatureLogic.hasPhysicalCopy(item),
        'Metadata only' => MediaNightFeatureLogic.availability(item) == CatalogAvailabilityKind.metadataOnly,
        _ => true,
      };
    }).toList(growable: false);
    final visibleTracks = tracks.where((track) {
      final text = '${track.title} ${track.artist} ${track.album} ${track.genreDisplayLabel}'.toLowerCase();
      if (_query.trim().isNotEmpty && !text.contains(_query.trim().toLowerCase())) return false;
      return switch (_filter) {
        'Playable in personal library' => (track.audioUrl ?? '').trim().isNotEmpty,
        'Physical copy recorded' => false,
        'Metadata only' => (track.audioUrl ?? '').trim().isEmpty,
        _ => true,
      };
    }).toList(growable: false);
    final playable = library.where((item) => MediaNightFeatureLogic.availability(item) == CatalogAvailabilityKind.personalPlayback).length + tracks.where((track) => (track.audioUrl ?? '').trim().isNotEmpty).length;
    final physical = library.where(MediaNightFeatureLogic.hasPhysicalCopy).length;
    final metadataOnly = library.where((item) => MediaNightFeatureLogic.availability(item) == CatalogAvailabilityKind.metadataOnly).length + tracks.where((track) => (track.audioUrl ?? '').trim().isEmpty).length;

    return _FeatureScaffold(
      title: 'My Availability Radar',
      children: <Widget>[
        const _FeatureIntro(
          icon: Icons.radar_rounded,
          title: 'Find what has a source recorded',
          description: 'This view checks your movies, shows and connected music library for a personal playback/audio URL or recorded physical-copy metadata. A stored URL does not guarantee the server is reachable. External streaming providers and rental/purchase catalogs are not queried here.',
        ),
        Row(children: <Widget>[
          Expanded(child: _CountCard(label: 'URL recorded', value: '$playable')),
          const SizedBox(width: 8),
          Expanded(child: _CountCard(label: 'Physical copy', value: '$physical')),
          const SizedBox(width: 8),
          Expanded(child: _CountCard(label: 'Metadata only', value: '$metadataOnly')),
        ]),
        TextField(
          onChanged: (value) => setState(() => _query = value),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search your catalog'),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _filter,
          decoration: const InputDecoration(labelText: 'Availability status'),
          items: const <String>['All', 'Playable in personal library', 'Physical copy recorded', 'Metadata only']
              .map((value) => DropdownMenuItem<String>(value: value, child: Text(value))).toList(),
          onChanged: (value) { if (value != null) setState(() => _filter = value); },
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty && visibleTracks.isEmpty) const _EmptyFeatureState(message: 'No catalog titles match this availability filter.'),
        if (visible.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          const Text('Movies & shows', style: TextStyle(fontWeight: FontWeight.w800)),
          ...visible.map((item) => _MediaFeatureTile(
            item: item,
            subtitle: switch (MediaNightFeatureLogic.availability(item)) {
              CatalogAvailabilityKind.personalPlayback => 'Personal playback URL recorded; playback still depends on the connected server.',
              CatalogAvailabilityKind.physicalCopy => 'Physical-copy metadata recorded; playback URL not detected',
              CatalogAvailabilityKind.metadataOnly => 'Metadata only — playback or ownership is not confirmed',
            },
            trailing: MediaNightFeatureLogic.hasPhysicalCopy(item) && MediaNightFeatureLogic.hasAuthorizedPlaybackUrl(item)
                ? const Icon(Icons.check_circle, color: Colors.greenAccent)
                : null,
          )),
        ],
        if (visibleTracks.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          const Text('Music tracks', style: TextStyle(fontWeight: FontWeight.w800)),
          ...visibleTracks.map((track) => Card(
            color: _toolsPanel,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFF30244F), child: Icon(Icons.music_note_rounded, color: _toolsAccent)),
              title: Text(track.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              subtitle: Text('${musicTrackSubtitle(track)} • ${track.genreDisplayLabel} • ${(track.audioUrl ?? '').trim().isNotEmpty ? 'Audio URL recorded; server access is not guaranteed.' : 'Metadata only; no audio URL is recorded.'}', style: const TextStyle(color: Colors.white60)),
              trailing: (track.audioUrl ?? '').trim().isNotEmpty ? IconButton(tooltip: 'Play track', icon: const Icon(Icons.play_arrow_rounded), onPressed: () => MusicPlaybackController.instance.play(track)) : const Icon(Icons.info_outline, color: Colors.white38),
              onTap: (track.audioUrl ?? '').trim().isNotEmpty ? () => MusicPlaybackController.instance.play(track) : null,
            ),
          )),
        ],
      ],
    );
  }
}

class TasteTunerScreen extends StatefulWidget {
  const TasteTunerScreen({super.key});

  @override
  State<TasteTunerScreen> createState() => _TasteTunerScreenState();
}

class _TasteTunerScreenState extends State<TasteTunerScreen> {
  static const List<String> _genres = <String>[
    'Action', 'Adventure', 'Animation', 'Comedy', 'Crime', 'Documentary', 'Drama',
    'Fantasy', 'Horror', 'Mystery', 'Romance', 'Science Fiction', 'Thriller', 'Western',
    'Horror-Comedy', 'Romantic Thriller', 'Action-Comedy', 'Romantic Comedy', 'Sci-Fi Horror',
  ];
  final Set<String> _preferred = <String>{};
  final Set<String> _excluded = <String>{};
  double _minimumRating = 0;
  bool _hideWatched = false;
  bool _loading = true;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final saved = await MediaFeaturePreferences.loadTaste();
    if (!mounted) return;
    setState(() {
      _preferred..clear()..addAll(saved.preferredGenres);
      _excluded..clear()..addAll(saved.excludedGenres);
      _minimumRating = saved.minimumRating;
      _hideWatched = saved.hideWatched;
      _loading = false;
    });
  }

  TasteTunerPreferences get _current => TasteTunerPreferences(
        preferredGenres: _preferred.toList()..sort(),
        excludedGenres: _excluded.toList()..sort(),
        minimumRating: _minimumRating,
        hideWatched: _hideWatched,
      );

  Future<void> _save() async {
    await MediaFeaturePreferences.saveTaste(_current);
    if (!mounted) return;
    setState(() => _saved = true);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Taste preferences saved for this profile.')));
  }

  Widget _genreChips(Set<String> values, {required bool preferred}) => Wrap(
        spacing: 7,
        runSpacing: 7,
        children: _genres.map((genre) {
          final selected = values.contains(genre);
          return FilterChip(
            label: Text(genre),
            selected: selected,
            onSelected: (value) => setState(() {
              (preferred ? _preferred : _excluded).remove(genre);
              if (value) {
                (preferred ? _excluded : _preferred).remove(genre);
                values.add(genre);
              }
              _saved = false;
            }),
          );
        }).toList(growable: false),
      );

  @override
  Widget build(BuildContext context) {
    final controller = AppController.instance;
    final watchedIds = controller.watched.map((item) => item.id).toSet();
    final preview = controller.library
        .where((item) => MediaNightFeatureLogic.matchesTaste(item, _current, watchedIds: watchedIds))
        .toList()
      ..sort((a, b) => MediaNightFeatureLogic.tasteScore(b, _current).compareTo(MediaNightFeatureLogic.tasteScore(a, _current)));
    return _FeatureScaffold(title: 'Taste Tuner', children: <Widget>[
      const _FeatureIntro(
        icon: Icons.tune_rounded,
        title: 'Teach recommendations what you actually like',
        description: 'Choose preferred and excluded genres. These settings are saved per profile and can be used by Taste Tuner and My Media Night. Finishing a title is not treated as an automatic like.',
      ),
      if (_loading) const LinearProgressIndicator(),
      const Text('Prioritize these genres', style: TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      _genreChips(_preferred, preferred: true),
      const SizedBox(height: 16),
      const Text('Avoid these genres', style: TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      _genreChips(_excluded, preferred: false),
      const SizedBox(height: 16),
      Row(children: <Widget>[
        const Expanded(child: Text('Minimum rating preference', style: TextStyle(fontWeight: FontWeight.w700))),
        Text(_minimumRating == 0 ? 'Any' : _minimumRating.toStringAsFixed(1)),
      ]),
      Slider(value: _minimumRating, min: 0, max: 10, divisions: 20, onChanged: (value) => setState(() { _minimumRating = value; _saved = false; })),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: _hideWatched,
        title: const Text('Prefer titles I have not watched'),
        onChanged: (value) => setState(() { _hideWatched = value; _saved = false; }),
      ),
      FilledButton.icon(onPressed: _loading ? null : _save, icon: Icon(_saved ? Icons.check : Icons.save_outlined), label: Text(_saved ? 'Preferences saved' : 'Save taste preferences')),
      const SizedBox(height: 14),
      Text('${preview.length} catalog title${preview.length == 1 ? '' : 's'} match your current settings', style: const TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      if (preview.isEmpty) const _EmptyFeatureState(message: 'No titles match this combination yet. Relax one filter or add richer catalog metadata.'),
      ...preview.take(20).map((item) => _MediaFeatureTile(item: item, subtitle: '${GenreSystem.displayLabel(item.genres)} • taste score ${MediaNightFeatureLogic.tasteScore(item, _current).toStringAsFixed(1)}')),
    ]);
  }
}

class SpoilerShieldScreen extends StatefulWidget {
  const SpoilerShieldScreen({super.key});

  @override
  State<SpoilerShieldScreen> createState() => _SpoilerShieldScreenState();
}

class _SpoilerShieldScreenState extends State<SpoilerShieldScreen> {
  bool _enabled = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    MediaFeaturePreferences.loadSpoilerShield().then((value) {
      if (mounted) setState(() { _enabled = value; _loading = false; });
    });
  }

  Future<void> _update(bool value) async {
    setState(() => _enabled = value);
    await MediaFeaturePreferences.saveSpoilerShield(value);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value ? 'Spoiler Shield enabled for this profile.' : 'Spoiler Shield disabled.')));
  }

  @override
  Widget build(BuildContext context) => _FeatureScaffold(title: 'Spoiler Shield', children: <Widget>[
    const _FeatureIntro(
      icon: Icons.visibility_off_rounded,
      title: 'Protect the story until you are ready',
      description: 'When enabled, the media details screen hides the synopsis and cast section for titles not marked as watched. You can reveal the synopsis on an individual title. Community posts and external provider pages are not automatically scanned or filtered by this local setting.',
    ),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: _enabled,
      onChanged: _loading ? null : _update,
      title: const Text('Hide synopsis and cast for unwatched titles', style: TextStyle(fontWeight: FontWeight.w800)),
      subtitle: const Text('Stored separately for each profile.', style: TextStyle(color: Colors.white60)),
    ),
    const Divider(color: Colors.white12),
    const ListTile(leading: Icon(Icons.check_circle_outline, color: Colors.greenAccent), title: Text('Applies to the in-app media details page'), subtitle: Text('Descriptions and cast are masked until you mark a title watched or reveal its synopsis.'), contentPadding: EdgeInsets.zero),
    const ListTile(leading: Icon(Icons.info_outline, color: _toolsAccent), title: Text('Scope limitation'), subtitle: Text('Spoiler shielding for community replies, X-Ray timelines and provider-owned screens is not universal in this pass.'), contentPadding: EdgeInsets.zero),
  ]);
}

class NextUpQueueScreen extends StatefulWidget {
  const NextUpQueueScreen({super.key});

  @override
  State<NextUpQueueScreen> createState() => _NextUpQueueScreenState();
}

class _NextUpQueueScreenState extends State<NextUpQueueScreen> {
  List<String> _ids = <String>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final values = await MediaFeaturePreferences.loadNextUpQueue();
    if (mounted) setState(() { _ids = values; _loading = false; });
  }

  Future<void> _addFromCatalog() async {
    final catalog = AppController.instance.library;
    final selected = await showModalBottomSheet<MediaItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _toolsPanel,
      builder: (sheetContext) => SafeArea(child: SizedBox(height: MediaQuery.sizeOf(sheetContext).height * .75, child: Column(children: <Widget>[
        const ListTile(title: Text('Add a title to Next Up', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)), subtitle: Text('Choose from your current catalog.', style: TextStyle(color: Colors.white60))),
        const Divider(color: Colors.white12),
        Expanded(child: ListView.builder(itemCount: catalog.length, itemBuilder: (_, index) {
          final item = catalog[index];
          return ListTile(title: Text(item.title, style: const TextStyle(color: Colors.white)), subtitle: Text(GenreSystem.displayLabel(item.genres), style: const TextStyle(color: Colors.white54)), onTap: () => Navigator.pop(sheetContext, item));
        })),
      ]))),
    );
    if (selected == null) return;
    await MediaFeaturePreferences.addToNextUpQueue(<String>[selected.id]);
    await _reload();
  }

  Future<void> _addSongFromMusic() async {
    final tracks = MusicLibraryStore.instance.tracks;
    final selected = await showModalBottomSheet<MusicTrack>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _toolsPanel,
      builder: (sheetContext) => SafeArea(child: SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * .75,
        child: Column(children: <Widget>[
          const ListTile(title: Text('Add a song to Next Up', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)), subtitle: Text('Choose from your connected music library.', style: TextStyle(color: Colors.white60))),
          const Divider(color: Colors.white12),
          Expanded(child: tracks.isEmpty
              ? const _EmptyFeatureState(message: 'No connected music tracks were found.')
              : ListView.builder(itemCount: tracks.length, itemBuilder: (_, index) {
                  final track = tracks[index];
                  return ListTile(
                    leading: const Icon(Icons.music_note_rounded, color: _toolsAccent),
                    title: Text(track.title, style: const TextStyle(color: Colors.white)),
                    subtitle: Text('${musicTrackSubtitle(track)} • ${track.genreDisplayLabel}', style: const TextStyle(color: Colors.white54)),
                    onTap: () => Navigator.pop(sheetContext, track),
                  );
                })),
        ]))),
    );
    if (selected == null) return;
    await MediaFeaturePreferences.addToNextUpQueue(<String>['music:${selected.id}']);
    await _reload();
  }

  Future<void> _move(int from, int to) async {
    await MediaFeaturePreferences.moveNextUpQueueItem(from, to);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = AppController.instance.library;
    final itemById = <String, MediaItem>{for (final item in catalog) item.id: item};
    final tracksById = <String, MusicTrack>{for (final track in MusicLibraryStore.instance.tracks) track.id: track};
    final queued = _ids.asMap().entries.map((entry) {
      final token = entry.value;
      if (token.startsWith('music:')) {
        final track = tracksById[token.substring('music:'.length)];
        return (index: entry.key, token: token, media: null as MediaItem?, track: track);
      }
      final id = token.startsWith('media:') ? token.substring('media:'.length) : token;
      return (index: entry.key, token: token, media: itemById[id], track: null as MusicTrack?);
    }).where((entry) => entry.media != null || entry.track != null).toList(growable: false);
    return _FeatureScaffold(title: 'My Next Up Queue', children: <Widget>[
      const _FeatureIntro(icon: Icons.queue_play_next_rounded, title: 'Your next watch or listen, without losing your place', description: 'The queue is saved locally for the active profile. It can include titles with metadata only; availability is shown separately so the queue does not imply playback access.'),
      Text('${queued.length} queued item${queued.length == 1 ? '' : 's'}', style: const TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
        OutlinedButton.icon(onPressed: _addFromCatalog, icon: const Icon(Icons.movie_outlined), label: const Text('Add movie/show')),
        OutlinedButton.icon(onPressed: _addSongFromMusic, icon: const Icon(Icons.music_note_rounded), label: const Text('Add song')),
      ]),
      if (_loading) const LinearProgressIndicator(),
      if (!_loading && queued.isEmpty) const _EmptyFeatureState(message: 'Your queue is empty. Add a title or song, or create a My Media Night plan.'),
      ...queued.map((entry) {
        final index = entry.index;
        final item = entry.media;
        final track = entry.track;
        final child = item != null
            ? _MediaFeatureTile(item: item, subtitle: GenreSystem.displayLabel(item.genres), embedded: true)
            : ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                leading: const CircleAvatar(backgroundColor: Color(0xFF30244F), child: Icon(Icons.music_note_rounded, color: _toolsAccent)),
                title: Text(track!.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                subtitle: Text('${musicTrackSubtitle(track)} • ${track.genreDisplayLabel}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60)),
                trailing: IconButton(
                  tooltip: 'Play song',
                  icon: const Icon(Icons.play_circle_outline_rounded, color: _toolsAccent),
                  onPressed: () => MusicPlaybackController.instance.play(track),
                ),
                onTap: () => MusicPlaybackController.instance.play(track),
              );
        return Card(color: _toolsPanel, child: Row(children: <Widget>[
          Padding(padding: const EdgeInsets.only(left: 8), child: Text('${index + 1}', style: const TextStyle(color: _toolsAccent, fontWeight: FontWeight.w900))),
          Expanded(child: child),
          Column(children: <Widget>[
            IconButton(tooltip: 'Move up', onPressed: index == 0 ? null : () => _move(index, index - 1), icon: const Icon(Icons.keyboard_arrow_up)),
            IconButton(tooltip: 'Move down', onPressed: index == _ids.length - 1 ? null : () => _move(index, index + 1), icon: const Icon(Icons.keyboard_arrow_down)),
            IconButton(tooltip: 'Remove from queue', onPressed: () async { await MediaFeaturePreferences.removeFromNextUpQueue(entry.token); await _reload(); }, icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent)),
          ]),
        ]));
      }),
      if (queued.isNotEmpty) OutlinedButton.icon(onPressed: () async { await MediaFeaturePreferences.replaceNextUpQueue(<String>[]); await _reload(); }, icon: const Icon(Icons.clear_all), label: const Text('Clear queue')),
    ]);
  }
}

class TravelModeScreen extends StatefulWidget {
  const TravelModeScreen({super.key});

  @override
  State<TravelModeScreen> createState() => _TravelModeScreenState();
}

class _TravelModeScreenState extends State<TravelModeScreen> {
  Set<String> _selected = <String>{};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    MediaFeaturePreferences.loadTravelPrep().then((values) {
      if (mounted) setState(() { _selected = values.toSet(); _loading = false; });
    });
  }

  Future<void> _toggle(String id, bool value) async {
    await MediaFeaturePreferences.updateTravelPrep(id, value);
    if (mounted) {
      setState(() {
      if (value) {
        _selected.add(id);
      } else {
        _selected.remove(id);
      }
    });
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = AppController.instance.library;
    final queueIds = _selected;
    return _FeatureScaffold(title: 'Travel Mode', children: <Widget>[
      const _FeatureIntro(icon: Icons.luggage_rounded, title: 'Prepare before you disconnect', description: 'Build a profile-specific list of titles to check before a trip. This pass records your travel shortlist only; it does not download media or bypass a provider’s offline restrictions.'),
      Row(children: <Widget>[
        Expanded(child: Text('${_selected.length} title${_selected.length == 1 ? '' : 's'} on the travel list', style: const TextStyle(fontWeight: FontWeight.w800))),
        TextButton(onPressed: () async {
          final queue = await MediaFeaturePreferences.loadNextUpQueue();
          for (final id in queue) { await MediaFeaturePreferences.updateTravelPrep(id, true); }
          final all = await MediaFeaturePreferences.loadTravelPrep();
          if (mounted) setState(() => _selected = all.toSet());
        }, child: const Text('Add Next Up queue')),
      ]),
      if (_loading) const LinearProgressIndicator(),
      if (library.isEmpty) const _EmptyFeatureState(message: 'Import or connect a media catalog to prepare a travel list.'),
      ...library.map((item) => CheckboxListTile(
        value: queueIds.contains('media:${item.id}'),
        onChanged: _loading ? null : (value) => _toggle('media:${item.id}', value == true),
        title: Text(item.title),
        subtitle: Text(MediaNightFeatureLogic.hasAuthorizedPlaybackUrl(item) ? 'Personal playback URL recorded; offline support is not confirmed.' : MediaNightFeatureLogic.hasPhysicalCopy(item) ? 'Physical-copy metadata recorded; verify you have access to the disc.' : 'Metadata only; find a playback source before travel.'),
        secondary: const Icon(Icons.movie_outlined, color: _toolsAccent),
      )),
      const SizedBox(height: 10),
      const Text('Music tracks', style: TextStyle(fontWeight: FontWeight.w800)),
      ...MusicLibraryStore.instance.tracks.map((track) => CheckboxListTile(
        value: queueIds.contains('music:${track.id}'),
        onChanged: _loading ? null : (value) => _toggle('music:${track.id}', value == true),
        secondary: const Icon(Icons.music_note_rounded, color: _toolsAccent),
        title: Text(track.title),
        subtitle: Text('${musicTrackSubtitle(track)} • ${track.genreDisplayLabel} • offline download is not performed here'),
      )),
      OutlinedButton.icon(onPressed: _selected.isEmpty ? null : () async { await MediaFeaturePreferences.clearTravelPrep(); if (mounted) setState(() => _selected.clear()); }, icon: const Icon(Icons.clear_all), label: const Text('Clear travel shortlist'))
    ]);
  }
}

class MediaDataQualityCenterScreen extends StatelessWidget {
  const MediaDataQualityCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final findings = MediaNightFeatureLogic.auditCatalog(AppController.instance.library);
    final high = findings.where((item) => item.severity == 'High').length;
    final medium = findings.where((item) => item.severity == 'Medium').length;
    final low = findings.where((item) => item.severity == 'Low').length;
    return _FeatureScaffold(title: 'Media Data Quality Center', children: <Widget>[
      const _FeatureIntro(icon: Icons.fact_check_rounded, title: 'Trust your catalog metadata', description: 'Find possible duplicates, missing fields, absent artwork and titles without a recorded personal playback URL or physical-copy metadata. Findings are suggestions; this screen does not auto-edit or delete catalog records.'),
      Row(children: <Widget>[
        Expanded(child: _CountCard(label: 'High', value: '$high')),
        const SizedBox(width: 8),
        Expanded(child: _CountCard(label: 'Medium', value: '$medium')),
        const SizedBox(width: 8),
        Expanded(child: _CountCard(label: 'Low', value: '$low')),
      ]),
      const SizedBox(height: 12),
      if (findings.isEmpty) const _EmptyFeatureState(message: 'No basic metadata quality findings were detected in this catalog.'),
      ...findings.map((finding) => Card(color: _toolsPanel, child: ListTile(
        leading: Icon(finding.severity == 'High' ? Icons.error_outline : finding.severity == 'Medium' ? Icons.warning_amber_rounded : Icons.info_outline, color: finding.severity == 'High' ? Colors.redAccent : finding.severity == 'Medium' ? Colors.orangeAccent : Colors.blueGrey),
        title: Text(finding.message, style: const TextStyle(color: Colors.white)),
        subtitle: Text('${finding.severity} • ${finding.code} • ${finding.mediaIds.length} item reference(s)', style: const TextStyle(color: Colors.white54)),
      ))),
    ]);
  }
}

class MyDataPrivacyCenterScreen extends StatefulWidget {
  const MyDataPrivacyCenterScreen({super.key});

  @override
  State<MyDataPrivacyCenterScreen> createState() => _MyDataPrivacyCenterScreenState();
}

class _MyDataPrivacyCenterScreenState extends State<MyDataPrivacyCenterScreen> {
  bool _busy = false;

  Future<void> _copyExport() async {
    setState(() => _busy = true);
    final controller = AppController.instance;
    final taste = await MediaFeaturePreferences.loadTaste();
    final queue = await MediaFeaturePreferences.loadNextUpQueue();
    final travel = await MediaFeaturePreferences.loadTravelPrep();
    final shield = await MediaFeaturePreferences.loadSpoilerShield();
    final payload = <String, dynamic>{
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'scope': 'local profile summary; no credentials or playback URLs included',
      'profileName': controller.currentProfile?.name ?? 'Guest',
      'catalogCount': controller.library.length,
      'watchedTitles': controller.watched.map((item) => <String, dynamic>{'id': item.id, 'title': item.title, 'year': item.releaseYear}).toList(),
      'likedTitles': controller.liked.map((item) => <String, dynamic>{'id': item.id, 'title': item.title, 'year': item.releaseYear}).toList(),
      'tasteTuner': taste.toJson(),
      'spoilerShieldEnabled': shield,
      'nextUpIds': queue,
      'travelPrepIds': travel,
    };
    await Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert(payload)));
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile summary copied to clipboard.')));
  }

  Future<void> _clearSettings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear local Media Night settings?'),
        content: const Text('This clears this module’s taste preferences, spoiler setting, Next Up queue, travel shortlist and saved Media Night plan for the active profile. It does not delete watch history, account data or server records.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Clear local settings')),
        ],
      ),
    );
    if (confirmed != true) return;
    await MediaFeaturePreferences.clearCurrentProfileLocalSettings();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Local Media Night settings cleared.')));
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppController.instance;
    return _FeatureScaffold(title: 'My Data & Privacy Center', children: <Widget>[
      const _FeatureIntro(icon: Icons.privacy_tip_outlined, title: 'Know what this feature stores', description: 'Media Night preferences are stored locally under a key scoped to the active profile. Export here includes title names and local preferences only; it deliberately excludes authentication tokens, private backend values and playback URLs.'),
      _CountCard(label: 'Catalog titles', value: '${controller.library.length}'),
      const SizedBox(height: 8),
      _CountCard(label: 'Watched titles', value: '${controller.watched.length}'),
      const SizedBox(height: 8),
      _CountCard(label: 'Liked titles', value: '${controller.liked.length}'),
      const SizedBox(height: 16),
      FilledButton.icon(onPressed: _busy ? null : _copyExport, icon: const Icon(Icons.copy_all_rounded), label: Text(_busy ? 'Preparing export…' : 'Copy profile summary as JSON')),
      const SizedBox(height: 10),
      OutlinedButton.icon(onPressed: _clearSettings, icon: const Icon(Icons.delete_sweep_outlined), label: const Text('Clear local Media Night settings')),
      const SizedBox(height: 14),
      const Text('Account deletion, server-side history, Supabase records and provider data must be managed through the app’s authenticated account controls. This local utility does not claim to erase those systems.', style: TextStyle(color: Colors.white60, height: 1.4)),
    ]);
  }
}

class MyMediaNightScreen extends StatefulWidget {
  const MyMediaNightScreen({super.key});

  @override
  State<MyMediaNightScreen> createState() => _MyMediaNightScreenState();
}

class _MyMediaNightScreenState extends State<MyMediaNightScreen> {
  static const List<String> _moods = <String>['Funny & Spooky', 'Romantic', 'Adventurous', 'Relaxed', 'Surprising', 'Suspenseful'];
  String _mood = 'Funny & Spooky';
  DateTime _plannedFor = DateTime.now().add(const Duration(days: 1));
  final Set<String> _selectedIds = <String>{};
  TasteTunerPreferences _taste = const TasteTunerPreferences();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final taste = await MediaFeaturePreferences.loadTaste();
    final plan = await MediaFeaturePreferences.loadMediaNightPlan();
    if (!mounted) return;
    setState(() {
      _taste = taste;
      if (plan != null) {
        final mood = plan['mood']?.toString();
        if (_moods.contains(mood)) _mood = mood!;
        final date = DateTime.tryParse(plan['plannedFor']?.toString() ?? '');
        if (date != null) _plannedFor = date;
        final ids = plan['mediaIds'];
        if (ids is List) _selectedIds.addAll(ids.map((value) => value.toString()));
      }
      _loading = false;
    });
  }

  Future<void> _chooseDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _plannedFor.isBefore(now) ? now : _plannedFor,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) setState(() => _plannedFor = DateTime(picked.year, picked.month, picked.day, 19));
  }

  String get _snackSuggestion => switch (_mood) {
        'Funny & Spooky' => 'Popcorn, candy and a shareable snack tray',
        'Romantic' => 'Dessert bites and a cozy snack board',
        'Adventurous' => 'Pizza slices or a build-your-own snack spread',
        'Relaxed' => 'Comfort snacks, tea or a favorite warm drink',
        'Surprising' => 'A tasting flight of small snacks',
        _ => 'Popcorn and something savory',
      };

  String get _musicSuggestion => switch (_mood) {
        'Funny & Spooky' => 'Playful Halloween, surf-rock and spooky soundtrack cues',
        'Romantic' => 'Soul, soft pop and romantic film soundtracks',
        'Adventurous' => 'High-energy rock, orchestral scores and upbeat pop',
        'Relaxed' => 'Lo-fi, acoustic, jazz and ambient music',
        'Surprising' => 'Genre-blending tracks and unexpected soundtrack cuts',
        _ => 'Suspense scores, dark ambient and tension-building instrumentals',
      };

  List<MediaItem> get _suggestions {
    final controller = AppController.instance;
    final ranked = MediaNightFeatureLogic.rankForMood(controller.library, _mood);
    final watchedIds = controller.watched.map((item) => item.id).toSet();
    final matched = ranked.where((item) => MediaNightFeatureLogic.matchesTaste(item, _taste, watchedIds: watchedIds)).toList();
    return matched.take(30).toList(growable: false);
  }

  Future<void> _saveAndQueue() async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose at least one title for your media night.')));
      return;
    }
    setState(() => _saving = true);
    final ids = _selectedIds.toList(growable: false);
    await MediaFeaturePreferences.saveMediaNightPlan(<String, dynamic>{
      'mood': _mood,
      'plannedFor': _plannedFor.toIso8601String(),
      'mediaIds': ids,
      'snackSuggestion': _snackSuggestion,
      'musicSuggestion': _musicSuggestion,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
    await MediaFeaturePreferences.addToNextUpQueue(ids);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Media night saved and selected titles added to Next Up.')));
  }

  void _open(Widget screen) => Navigator.push<void>(context, MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final suggestions = _suggestions;
    return _FeatureScaffold(title: 'My Media Night', children: <Widget>[
      const _FeatureIntro(icon: Icons.nightlight_round, title: 'Build the whole night in one place', description: 'Choose a mood, select titles from your local catalog, and connect your existing music, food/merch and watch-party experiences. Snack and playlist ideas are suggestions, not placed orders or generated playlists.'),
      DropdownButtonFormField<String>(
        initialValue: _mood,
        decoration: const InputDecoration(labelText: 'Tonight’s mood'),
        items: _moods.map((value) => DropdownMenuItem<String>(value: value, child: Text(value))).toList(),
        onChanged: (value) => setState(() { if (value != null) _mood = value; }),
      ),
      const SizedBox(height: 8),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.calendar_month_outlined, color: _toolsAccent),
        title: const Text('Plan date'),
        subtitle: Text('${_plannedFor.year}-${_plannedFor.month.toString().padLeft(2, '0')}-${_plannedFor.day.toString().padLeft(2, '0')} • local reminder only'),
        trailing: const Icon(Icons.edit_calendar_outlined),
        onTap: _chooseDate,
      ),
      Card(color: _toolsPanel, child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        const Text('Food idea', style: TextStyle(color: _toolsAccent, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4), Text(_snackSuggestion),
        const SizedBox(height: 12),
        const Text('Playlist direction', style: TextStyle(color: _toolsAccent, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4), Text(_musicSuggestion),
      ]))),
      const SizedBox(height: 12),
      Text('${suggestions.length} local-catalog suggestions • choose up to 3 titles', style: const TextStyle(fontWeight: FontWeight.w800)),
      if (_loading) const LinearProgressIndicator(),
      if (suggestions.isEmpty) const _EmptyFeatureState(message: 'No titles match this mood and your Taste Tuner settings. Adjust the mood or relax the genre preferences.'),
      ...suggestions.map((item) => CheckboxListTile(
        value: _selectedIds.contains(item.id),
        onChanged: (value) => setState(() {
          if (value == true && (_selectedIds.length < 3 || _selectedIds.contains(item.id))) _selectedIds.add(item.id);
          if (value != true) _selectedIds.remove(item.id);
        }),
        secondary: item.imageUrl?.trim().isNotEmpty == true
            ? ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(item.imageUrl!, width: 48, height: 64, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.movie_outlined)))
            : const Icon(Icons.movie_outlined, color: _toolsAccent),
        title: Text(item.title),
        subtitle: Text('${item.releaseYear ?? 'Year unknown'} • ${GenreSystem.displayLabel(item.genres)}${item.rating == null ? '' : ' • ${item.rating!.toStringAsFixed(1)}'}'),
      )),
      FilledButton.icon(onPressed: _saving ? null : _saveAndQueue, icon: const Icon(Icons.save_outlined), label: Text(_saving ? 'Saving plan…' : 'Save night & add titles to Next Up')),
      const SizedBox(height: 10),
      OutlinedButton.icon(onPressed: () => _open(const MusicScreen()), icon: const Icon(Icons.music_note_rounded), label: const Text('Open Music for the playlist')),
      OutlinedButton.icon(onPressed: () => _open(const WatchAndEnjoyScreen()), icon: const Icon(Icons.local_dining_outlined), label: const Text('Open Food & Entertainment Marketplace')),
      OutlinedButton.icon(onPressed: () => _open(const WatchPartyLobbyScreen()), icon: const Icon(Icons.groups_outlined), label: const Text('Open Watch Party')),
      OutlinedButton.icon(onPressed: () => _open(const SocialCenterScreen()), icon: const Icon(Icons.forum_outlined), label: const Text('Open friends & communities')),
      const SizedBox(height: 8),
      const Text('Reminder: a date is stored locally; no notification is scheduled by this module. Provider-wide availability, delivery ordering, and synchronized party playback depend on their connected flows.', style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4)),
    ]);
  }
}

class _FeatureScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _FeatureScaffold({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _toolsBackground,
        appBar: AppBar(title: Text(title), backgroundColor: _toolsBackground),
        body: SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: <Widget>[...children, const SizedBox(height: 22)])),
      );
}

class _FeatureIntro extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  const _FeatureIntro({required this.icon, required this.title, required this.description});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(colors: <Color>[Color(0xFF30244F), _toolsPanel]),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Icon(icon, size: 30, color: _toolsAccent),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 7),
          Text(description, style: const TextStyle(color: Colors.white70, height: 1.45)),
        ]),
      );
}

class _CountCard extends StatelessWidget {
  final String label;
  final String value;
  const _CountCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: _toolsPanel, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text(value, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white60)),
        ]),
      );
}

class _EmptyFeatureState extends StatelessWidget {
  final String message;
  const _EmptyFeatureState({required this.message});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          const Icon(Icons.auto_awesome_mosaic_rounded, size: 38, color: Colors.white30),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, height: 1.4)),
        ]),
      );
}

class _MediaFeatureTile extends StatelessWidget {
  final MediaItem item;
  final String subtitle;
  final Widget? trailing;
  final bool embedded;
  const _MediaFeatureTile({required this.item, required this.subtitle, this.trailing, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final tile = ListTile(
      contentPadding: embedded ? const EdgeInsets.symmetric(horizontal: 8, vertical: 2) : null,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 46,
          height: 62,
          child: (item.imageUrl ?? '').trim().isEmpty
              ? const ColoredBox(color: Colors.black26, child: Icon(Icons.movie_outlined, color: Colors.white54))
              : Image.network(item.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black26, child: Icon(Icons.movie_outlined, color: Colors.white54))),
        ),
      ),
      title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 12)),
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded, color: Colors.white54),
      onTap: () => Navigator.push<void>(context, MaterialPageRoute<void>(builder: (_) => MediaDetailsScreen(media: item))),
    );
    return embedded ? tile : Card(color: _toolsPanel, margin: const EdgeInsets.only(bottom: 8), child: tile);
  }
}
