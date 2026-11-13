import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_core.dart';
import '../catalog_poster_image.dart';
import '../music.dart';

/// Profile-scoped discovery lists for owned and not-yet-owned media.
/// Items are metadata reminders only; this screen does not claim to acquire
/// unowned titles or create playable sources.
class PersonalDiscoveryListsScreen extends StatefulWidget {
  const PersonalDiscoveryListsScreen({super.key});

  @override
  State<PersonalDiscoveryListsScreen> createState() =>
      _PersonalDiscoveryListsScreenState();
}

class _PersonalDiscoveryListsScreenState
    extends State<PersonalDiscoveryListsScreen> {
  static const _lists = <String>[
    'Watch Later',
    'Listen Later',
    'Want to Own',
    'Recently Discovered'
  ];
  final _app = AppController.instance;
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  bool _loading = true;
  String _filter = 'All';

  String get _profileId => _app.currentProfile?.id.trim().isNotEmpty == true
      ? _app.currentProfile!.id.trim()
      : 'default';
  String get _key =>
      'moss_personal_discovery_lists_v1_${Uri.encodeComponent(_profileId)}';

  @override
  void initState() {
    super.initState();
    _app.addListener(_refresh);
    MusicLibraryStore.instance.addListener(_refresh);
    _load();
    unawaited(MusicLibraryStore.instance
        .initializeForProfile(_app.currentProfile?.id));
  }

  @override
  void dispose() {
    _app.removeListener(_refresh);
    MusicLibraryStore.instance.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    final rows = <Map<String, dynamic>>[];
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final row in decoded.whereType<Map>()) {
            final map = Map<String, dynamic>.from(row);
            if ((map['title']?.toString().trim() ?? '').isNotEmpty) {
              rows.add(map);
            }
          }
        }
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _items = rows;
      _loading = false;
    });
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_items));
  }

  String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  bool _owned(Map<String, dynamic> row) {
    final id = row['id']?.toString() ?? '';
    final title = _normalize(row['title']?.toString() ?? '');
    final type = row['type']?.toString().toLowerCase() ?? '';
    if (id.isNotEmpty &&
        _app.library.any((media) =>
            media.id == id && media.isAccessibleTo(_app.currentProfile))) {
      return true;
    }
    if (type == 'song' || type == 'album' || type == 'music') {
      return MusicLibraryStore.instance.tracks.any((track) =>
          _normalize(track.title) == title ||
          _normalize('${track.title} ${track.artist}') == title ||
          _normalize(track.album) == title);
    }
    return _app.library.any((media) =>
        media.isAccessibleTo(_app.currentProfile) &&
        _normalize(media.title) == title);
  }

  Future<void> _addManual() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _DiscoveryEntryDialog(),
    );
    if (result == null || !mounted) return;
    final title = result['title']?.toString().trim() ?? '';
    if (title.isEmpty) return;
    final type = result['type']?.toString() ?? 'movie';
    final list = result['list']?.toString() ??
        (type == 'song' || type == 'album' ? 'Listen Later' : 'Watch Later');
    final entry = <String, dynamic>{
      'id': 'discovery_${DateTime.now().microsecondsSinceEpoch}',
      'title': title,
      'type': type,
      'releaseYear': result['releaseYear'],
      'notes': result['notes']?.toString() ?? '',
      'list': list,
      'source': 'manual_or_catalog_search',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
    setState(() => _items.insert(0, entry));
    await _persist();
  }

  Future<void> _addFromLibrary() async {
    final choice = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final videos = _app.library
            .where((m) => m.isAccessibleTo(_app.currentProfile))
            .toList();
        final tracks = MusicLibraryStore.instance.tracks;
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * .78,
            child: DefaultTabController(
              length: 2,
              child: Column(children: [
                const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text('Add from your library',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900))),
                const TabBar(
                    tabs: [Tab(text: 'Movies & Shows'), Tab(text: 'Music')]),
                Expanded(
                    child: TabBarView(children: [
                  ListView.builder(
                      itemCount: videos.length,
                      itemBuilder: (_, i) {
                        final media = videos[i];
                        return ListTile(
                          leading: SizedBox(
                              width: 42,
                              child: CatalogPosterImage(
                                  media: media, fit: BoxFit.cover)),
                          title: Text(media.title),
                          subtitle: Text(media.type),
                          onTap: () =>
                              Navigator.pop(sheetContext, <String, dynamic>{
                            'id': media.id,
                            'title': media.title,
                            'type': media.type,
                            'imageUrl': media.imageUrl,
                            'releaseYear': media.releaseYear,
                            'list': 'Watch Later'
                          }),
                        );
                      }),
                  ListView.builder(
                      itemCount: tracks.length,
                      itemBuilder: (_, i) {
                        final track = tracks[i];
                        return ListTile(
                          leading: (track.artworkUrl?.isNotEmpty == true)
                              ? Image.network(track.artworkUrl!,
                                  width: 42,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.album_rounded))
                              : const Icon(Icons.album_rounded),
                          title: Text(track.title),
                          subtitle: Text('${track.artist} · ${track.album}'),
                          onTap: () =>
                              Navigator.pop(sheetContext, <String, dynamic>{
                            'id': track.id,
                            'title': track.title,
                            'type': 'song',
                            'imageUrl': track.artworkUrl,
                            'list': 'Listen Later',
                            'notes':
                                'Artist: ${track.artist} · Album: ${track.album}'
                          }),
                        );
                      }),
                ])),
              ]),
            ),
          ),
        );
      },
    );
    if (choice == null || !mounted) return;
    final id = choice['id']?.toString() ?? '';
    if (_items.any((item) => item['id'] == id && id.isNotEmpty)) return;
    final entry = <String, dynamic>{
      ...choice,
      'notes': choice['notes']?.toString() ?? '',
      'source': 'owned_library',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
    setState(() => _items.insert(0, entry));
    await _persist();
  }

  Future<void> _move(Map<String, dynamic> item, String list) async {
    setState(() => item['list'] = list);
    await _persist();
  }

  Future<void> _remove(Map<String, dynamic> item) async {
    setState(() => _items.remove(item));
    await _persist();
  }

  @override
  Widget build(BuildContext context) {
    final shown = _filter == 'All'
        ? _items
        : _items.where((row) => row['list'] == _filter).toList();
    final ownedCount = _items.where(_owned).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Personal Discovery Lists'), actions: [
        IconButton(
            tooltip: 'Add a title manually',
            onPressed: _addManual,
            icon: const Icon(Icons.add_rounded)),
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                    child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                  'Keep discoveries separate from your owned library.',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 5),
                              Text(
                                  '${_items.length} saved · $ownedCount already owned · ${_items.length - ownedCount} not found in this profile library',
                                  style: Theme.of(context).textTheme.bodySmall),
                              const SizedBox(height: 8),
                              const Text(
                                  'Want to Own is a reminder list only. Adding an entry never marks media as owned or playable.',
                                  style: TextStyle(fontSize: 12)),
                              const SizedBox(height: 10),
                              Wrap(spacing: 8, runSpacing: 8, children: [
                                FilledButton.tonalIcon(
                                    onPressed: _addFromLibrary,
                                    icon: const Icon(
                                        Icons.video_library_outlined),
                                    label: const Text('Add from library')),
                                OutlinedButton.icon(
                                    onPressed: _addManual,
                                    icon: const Icon(Icons.edit_note_rounded),
                                    label: const Text('Add unowned title')),
                              ]),
                            ]))),
                const SizedBox(height: 10),
                SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      for (final filter in ['All', ..._lists])
                        Padding(
                            padding: const EdgeInsets.only(right: 7),
                            child: ChoiceChip(
                                label: Text(filter),
                                selected: _filter == filter,
                                onSelected: (_) =>
                                    setState(() => _filter = filter))),
                    ])),
                const SizedBox(height: 8),
                if (shown.isEmpty)
                  const Padding(
                      padding: EdgeInsets.all(30),
                      child: Center(
                          child: Text(
                              'This list is empty. Add a title from your library or save an unowned discovery.'))),
                for (final item in shown)
                  Card(
                      child: ListTile(
                    leading:
                        SizedBox(width: 48, height: 66, child: _artwork(item)),
                    title: Text(item['title']?.toString() ?? 'Untitled',
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${item['type'] ?? 'media'}${item['releaseYear'] == null ? '' : ' · ${item['releaseYear']}'} · ${item['list'] ?? 'Saved'}'),
                          Text(
                              _owned(item)
                                  ? 'In your library'
                                  : 'Not owned / not found in this profile library',
                              style: TextStyle(
                                  color: _owned(item)
                                      ? Colors.green
                                      : Colors.orange,
                                  fontSize: 11)),
                          if ((item['notes']?.toString() ?? '').isNotEmpty)
                            Text(item['notes'].toString(),
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                        ]),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'remove') {
                            _remove(item);
                          } else {
                            _move(item, value);
                          }
                        },
                        itemBuilder: (_) => [
                              for (final list in _lists)
                                PopupMenuItem(
                                    value: list, child: Text('Move to $list')),
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                  value: 'remove', child: Text('Remove')),
                            ]),
                  )),
              ],
            ),
    );
  }

  Widget _artwork(Map<String, dynamic> item) {
    final image = item['imageUrl']?.toString() ?? '';
    if (image.startsWith('https://')) {
      return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.network(image,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const ColoredBox(
                  color: Colors.black12, child: Icon(Icons.movie_outlined))));
    }
    return const DecoratedBox(
        decoration: BoxDecoration(color: Colors.black12),
        child: Icon(Icons.movie_outlined));
  }
}

class _DiscoveryEntryDialog extends StatefulWidget {
  const _DiscoveryEntryDialog();
  @override
  State<_DiscoveryEntryDialog> createState() => _DiscoveryEntryDialogState();
}

class _DiscoveryEntryDialogState extends State<_DiscoveryEntryDialog> {
  final _title = TextEditingController();
  final _year = TextEditingController();
  final _notes = TextEditingController();
  String _type = 'movie';
  String _list = 'Watch Later';

  @override
  void dispose() {
    _title.dispose();
    _year.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Save a discovery'),
        content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: _title,
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: 'Movie, show, album or song title')),
          const SizedBox(height: 9),
          DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Media type'),
              items: const [
                DropdownMenuItem(value: 'movie', child: Text('Movie')),
                DropdownMenuItem(value: 'show', child: Text('TV show')),
                DropdownMenuItem(value: 'album', child: Text('Album')),
                DropdownMenuItem(value: 'song', child: Text('Song'))
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _type = value;
                    _list = (value == 'album' || value == 'song')
                        ? 'Listen Later'
                        : 'Watch Later';
                  });
                }
              }),
          const SizedBox(height: 9),
          DropdownButtonFormField<String>(
              initialValue: _list,
              decoration: const InputDecoration(labelText: 'Save to list'),
              items: [
                'Watch Later',
                'Listen Later',
                'Want to Own',
                'Recently Discovered'
              ]
                  .map((value) =>
                      DropdownMenuItem(value: value, child: Text(value)))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _list = value);
              }),
          const SizedBox(height: 9),
          TextField(
              controller: _year,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Release year (optional)')),
          const SizedBox(height: 9),
          TextField(
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: 'Why did you save it? (optional)')),
        ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () {
                final title = _title.text.trim();
                if (title.isEmpty) return;
                Navigator.pop(context, <String, dynamic>{
                  'title': title,
                  'type': _type,
                  'list': _list,
                  'releaseYear': int.tryParse(_year.text.trim()),
                  'notes': _notes.text.trim()
                });
              },
              child: const Text('Save'))
        ],
      );
}
