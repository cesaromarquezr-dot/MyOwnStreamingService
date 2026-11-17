import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_core.dart';
import 'genre_catalog.dart';
import 'profiles_permissions_hub.dart';

/// Profile-scoped presentation and organization preferences for the shared
/// media catalog. These settings never duplicate or move media files.
class LibraryOrganizationSettings {
  LibraryOrganizationSettings({
    required this.libraryOrder,
    required this.customNames,
    required this.artworkUrls,
    required this.tagsByMediaId,
  });

  List<String> libraryOrder;
  Map<String, String> customNames;
  Map<String, String> artworkUrls;
  Map<String, List<String>> tagsByMediaId;

  factory LibraryOrganizationSettings.empty() => LibraryOrganizationSettings(
        libraryOrder: const ['Action', 'Comedy', 'Drama', 'Horror', 'Animation', 'Science Fiction'],
        customNames: {}, artworkUrls: {}, tagsByMediaId: {},
      );

  Map<String, dynamic> toJson() => {
    'libraryOrder': libraryOrder,
    'customNames': customNames,
    'artworkUrls': artworkUrls,
    'tagsByMediaId': tagsByMediaId,
  };

  factory LibraryOrganizationSettings.fromJson(Map<String, dynamic> json) =>
      LibraryOrganizationSettings(
        libraryOrder: (json['libraryOrder'] as List?)?.whereType<String>().toList() ?? LibraryOrganizationSettings.empty().libraryOrder,
        customNames: Map<String, String>.from(json['customNames'] as Map? ?? {}),
        artworkUrls: Map<String, String>.from(json['artworkUrls'] as Map? ?? {}),
        tagsByMediaId: (json['tagsByMediaId'] as Map? ?? {}).map((k, v) => MapEntry(k.toString(), (v as List? ?? []).whereType<String>().toList())),
      );
}

class LibraryOrganizationStore {
  LibraryOrganizationStore._();
  static final instance = LibraryOrganizationStore._();
  LibraryOrganizationSettings settings = LibraryOrganizationSettings.empty();
  String _scope = '';

  String get _key {
    final c = AppController.instance;
    final account = c.currentAccount?.id ?? 'local';
    final profile = c.currentProfile?.id ?? 'guest';
    return 'library_organization_v1_${account}_$profile';
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _scope = _key;
    final raw = prefs.getString(_scope);
    if (raw == null) { settings = LibraryOrganizationSettings.empty(); return; }
    try { settings = LibraryOrganizationSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>); }
    catch (_) { settings = LibraryOrganizationSettings.empty(); }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    _scope = _key;
    await prefs.setString(_scope, jsonEncode(settings.toJson()));
  }
}

class LibraryOrganizationStudioScreen extends StatefulWidget {
  const LibraryOrganizationStudioScreen({super.key});
  @override
  State<LibraryOrganizationStudioScreen> createState() => _LibraryOrganizationStudioScreenState();
}

class _LibraryOrganizationStudioScreenState extends State<LibraryOrganizationStudioScreen> {
  final store = LibraryOrganizationStore.instance;
  bool loading = true;
  String query = '';
  String? selectedGenre;
  final queryController = TextEditingController();
  final nameController = TextEditingController();
  final artworkController = TextEditingController();
  final tagController = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async { await store.load(); if (mounted) setState(() => loading = false); }
  @override
  void dispose() { queryController.dispose(); nameController.dispose(); artworkController.dispose(); tagController.dispose(); super.dispose(); }

  List<String> get genres => MediaGenreCatalog.movieGroups.expand((g) => g.genres).toSet().toList()..sort();
  String _mediaKey(MediaItem item) => item.id;
  Future<void> _persist() async { await store.save(); if (mounted) setState(() {}); }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final library = AppController.instance.library;
    final visible = library.where((m) => query.isEmpty || m.title.toLowerCase().contains(query.toLowerCase())).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Library Organization Studio'), actions: [IconButton(tooltip: 'Profile access', icon: const Icon(Icons.admin_panel_settings_outlined), onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ProfilesAndPermissionsHubScreen()))) ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Organize your streaming library', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6), const Text('Create genre views, curate tags and artwork, and control how library sections appear. All views use the same underlying media catalog.'),
          const SizedBox(height: 12), Text('${library.length} catalog items · settings saved per profile', style: const TextStyle(color: Colors.white70)),
        ]))),
        const SizedBox(height: 12),
        _section('Genre libraries', Icons.category_outlined, [
          const Text('Choose a genre to preview its library. A title may appear in multiple genre views without being duplicated.'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final g in [
                'Action',
                'Comedy',
                'Drama',
                'Horror',
                'Animation',
                'Science Fiction',
                'Romance',
                'Documentary',
                'Family',
              ])
                ChoiceChip(
                  label: Text(g),
                  selected: selectedGenre == g,
                  onSelected: (_) => setState(
                    () => selectedGenre = selectedGenre == g ? null : g,
                  ),
                ),
            ],
          ),
          if (selectedGenre != null) ...[const SizedBox(height: 8), Text('${library.where((m) => m.genres.any((g) => g.toLowerCase() == selectedGenre!.toLowerCase())).length} matching titles in $selectedGenre (based on catalog genre metadata).')],
        ]),
        _section('Library order & display names', Icons.sort, [
          const Text('Reorder the default genre sections. Display names are presentation-only; original metadata remains unchanged.'),
          const SizedBox(height: 8),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final g in store.settings.libraryOrder)
                ListTile(
                  key: ValueKey(g),
                  leading: const Icon(Icons.drag_handle),
                  title: Text(
                    store.settings.customNames[g]?.isNotEmpty == true
                        ? store.settings.customNames[g]!
                        : g,
                  ),
                  subtitle: Text(g),
                ),
            ],
            // onReorderItem supplies the adjusted insertion index, so do not
            // decrement newIndex when an item moves down the list.
            onReorderItem: (oldIndex, newIndex) async {
              final list = store.settings.libraryOrder;
              final item = list.removeAt(oldIndex);
              list.insert(newIndex, item);
              await _persist();
            },
          ),
          TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Custom display name for selected genre')),
          const SizedBox(height: 8), FilledButton(onPressed: selectedGenre == null ? null : () async { store.settings.customNames[selectedGenre!] = nameController.text.trim().isEmpty ? selectedGenre! : nameController.text.trim(); await _persist(); }, child: const Text('Save display name')),
        ]),
        _section('Artwork & collection branding', Icons.palette_outlined, [
          const Text('Assign a custom cover URL to a genre section. Use a trusted HTTPS image URL; this changes presentation, not ownership.'),
          TextField(controller: artworkController, decoration: const InputDecoration(labelText: 'Artwork HTTPS URL')),
          const SizedBox(height: 8), FilledButton(onPressed: selectedGenre == null ? null : () async { final value = artworkController.text.trim(); if (value.startsWith('https://')) store.settings.artworkUrls[selectedGenre!] = value; await _persist(); }, child: const Text('Save artwork for selected genre')),
        ]),
        _section('Tags & metadata', Icons.sell_outlined, [
          TextField(controller: queryController, decoration: const InputDecoration(labelText: 'Find a title', prefixIcon: Icon(Icons.search)), onChanged: (v) => setState(() => query = v)),
          TextField(controller: tagController, decoration: const InputDecoration(labelText: 'Add a custom tag to the first matching title')),
          const SizedBox(height: 8), ...visible.take(12).map((m) => ListTile(dense: true, leading: const Icon(Icons.movie_outlined), title: Text(m.title), subtitle: Text('${m.type} · ${(store.settings.tagsByMediaId[_mediaKey(m)] ?? const []).join(', ')}'), trailing: IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () async { final tag = tagController.text.trim(); if (tag.isEmpty) return; final tags = store.settings.tagsByMediaId.putIfAbsent(_mediaKey(m), () => []); if (!tags.contains(tag)) tags.add(tag); await _persist(); }))),
          const SizedBox(height: 4), const Text('For imported files, use the Import Center and server-side metadata tools to rename or move physical files. This studio does not modify files or provider metadata.'),
        ]),
        _section('Profile access & safety', Icons.family_restroom_outlined, [
          const Text('Manage profile restrictions and parental controls in the existing permissions center. UI visibility is not a substitute for backend authorization.'),
          FilledButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ProfilesAndPermissionsHubScreen())), icon: const Icon(Icons.shield_outlined), label: const Text('Open Profiles & Permissions')),
        ]),
        const SizedBox(height: 16), OutlinedButton.icon(onPressed: () async { store.settings = LibraryOrganizationSettings.empty(); await _persist(); }, icon: const Icon(Icons.restart_alt), label: const Text('Reset organization preferences')),
      ]),
    );
  }

  Widget _section(String title, IconData icon, List<Widget> children) => Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon), const SizedBox(width: 8), Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)))]), const SizedBox(height: 10), ...children])));
}

/// Strictly validates a conventional `Title (Year)` movie folder name.
bool isStandardMovieFolderName(String value) => RegExp(r'^.+\s\((18|19|20)\d{2}\)$').hasMatch(value.trim());
